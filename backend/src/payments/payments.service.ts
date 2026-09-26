import { Inject, Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
/** Result of a customer-facing capture attempt (verifyAndCapture). */
export interface CaptureResult {
  captured: boolean;
  booking_status?: string;
  already_captured?: boolean;
}

/** Result of webhook ingestion (ingestWebhook) — shape varies by outcome path. */
export interface WebhookResult {
  /** Set on the duplicate-replay path. */
  processed?: boolean;
  duplicate?: boolean;
  /** Set when the webhook actually captured the payment. */
  captured?: boolean;
  booking_status?: string;
}
import { BookingStateMachineService } from '../booking-state-machine/booking-state-machine.service';
import { BookingStatus, ActorRole } from '../booking-state-machine/booking-status';
import { GroupBookingsService } from '../bookings/group-bookings.service';
import {
  PaymentGateway,
  CreateOrderInput,
  VerifyPaymentInput,
  WebhookEvent,
} from './payment-gateway.interface';
import {
  BadRequestAppException,
  ConflictAppException,
  NotFoundAppException,
  UnauthorizedException,
} from '../auth/errors/auth.exceptions';
import { ErrorCode } from '../common/errors/error-codes';

export const PAYMENT_GATEWAY = 'PAYMENT_GATEWAY';

/** Advance fraction of the quoted total on the managed path (25%, as quoted). */
const ADVANCE_PERCENT = 25n;

/**
 * Managed (group) booking payment rules:
 *   * ADVANCE_TOKEN is payable once operations has moved the request to
 *     CUSTOMER_CONFIRMATION_PENDING (a real fleet + price exists) or the
 *     booking is CONFIRMED but the advance is still outstanding;
 *   * capturing the advance on a confirmation-pending booking CONFIRMS it —
 *     money settles the deal, nothing else;
 *   * BALANCE_SETTLEMENT is payable only on a CONFIRMED/IN_PROGRESS booking
 *     whose advance is already settled, and must be paid before the trip can
 *     be marked COMPLETED (the milestone ladder checks this).
 */

/**
 * Payment state machine owner. Amounts ALWAYS come from the booking row
 * (server-set at submission) — never from the request. A payment is marked
 * SUCCESS only through gateway signature verification (client callback) or
 * a verified webhook. Client input alone can never finalize a payment.
 */
@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly stateMachine: BookingStateMachineService,
    private readonly groupBookings: GroupBookingsService,
    @Inject(PAYMENT_GATEWAY) private readonly gateway: PaymentGateway,
  ) {}

  // ============================================================ managed path

  /**
   * Creates the ADVANCE_TOKEN order for a MANAGED booking. The amount is
   * 25% of the booking's quoted total, computed from the DATABASE row — a
   * client-supplied amount is never read. Idempotent per key.
   */
  async createGroupAdvanceOrder(groupId: string, customerId: string, idempotencyKey: string) {
    return this.createGroupOrder(groupId, customerId, idempotencyKey, 'ADVANCE_TOKEN');
  }

  /** Creates the BALANCE_SETTLEMENT order for a managed booking. */
  async createGroupBalanceOrder(groupId: string, customerId: string, idempotencyKey: string) {
    return this.createGroupOrder(groupId, customerId, idempotencyKey, 'BALANCE_SETTLEMENT');
  }

  private async createGroupOrder(
    groupId: string,
    customerId: string,
    idempotencyKey: string,
    type: 'ADVANCE_TOKEN' | 'BALANCE_SETTLEMENT',
  ) {
    const group = await this.prisma.groupBooking.findUnique({ where: { id: groupId } });
    if (!group) {
      throw new NotFoundAppException(ErrorCode.GROUP_BOOKING_NOT_FOUND, 'Group booking not found.');
    }
    if (group.customerFk !== customerId) {
      // Not yours — same 404 as a missing booking, no probing oracle.
      throw new NotFoundAppException(ErrorCode.GROUP_BOOKING_NOT_FOUND, 'Group booking not found.');
    }
    if (group.estimatedTotalPaise == null) {
      throw new ConflictAppException(
        ErrorCode.CONFLICT,
        'This booking has no complete price yet — payments open once the quote is complete.',
      );
    }

    const advanceOutstanding = group.advancePaidAt == null;
    if (type === 'ADVANCE_TOKEN') {
      if (!advanceOutstanding) {
        throw new ConflictAppException(
          ErrorCode.PAYMENT_ALREADY_FINALIZED,
          'Advance token already paid for this booking.',
        );
      }
      if (
        group.status !== 'CUSTOMER_CONFIRMATION_PENDING' &&
        group.status !== 'CONFIRMED' &&
        group.status !== 'PAYMENT_PENDING' &&
        group.status !== 'PAYMENT_FAILED'
      ) {
        throw new ConflictAppException(
          ErrorCode.INVALID_TRANSITION,
          `Booking in status ${group.status} cannot accept an advance payment yet.`,
        );
      }
    } else {
      if (advanceOutstanding) {
        throw new ConflictAppException(
          ErrorCode.INVALID_TRANSITION,
          'The advance token must be settled before the balance can be paid.',
        );
      }
      if (group.balancePaidAt != null) {
        throw new ConflictAppException(
          ErrorCode.PAYMENT_ALREADY_FINALIZED,
          'Balance already settled for this booking.',
        );
      }
      if (group.status !== 'CONFIRMED' && group.status !== 'IN_PROGRESS') {
        throw new ConflictAppException(
          ErrorCode.INVALID_TRANSITION,
          `Booking in status ${group.status} cannot accept a balance payment.`,
        );
      }
    }

    const total = group.estimatedTotalPaise;
    const amountPaise =
      type === 'ADVANCE_TOKEN'
        ? (total * ADVANCE_PERCENT) / 100n
        : total - (total * ADVANCE_PERCENT) / 100n;
    if (amountPaise <= 0n) {
      throw new ConflictAppException(ErrorCode.CONFLICT, 'Nothing to pay for this booking.');
    }

    const order = await this.gateway.createOrder({
      bookingId: groupId,
      amountPaise: Number(amountPaise),
      idempotencyKey: `${customerId}:gpay:${type}:${idempotencyKey}`,
      description:
        type === 'ADVANCE_TOKEN'
          ? `ShadiDriver advance token for ${group.referenceCode}`
          : `ShadiDriver balance settlement for ${group.referenceCode}`,
    });

    const payment = await this.upsertGroupPayment(groupId, customerId, type, amountPaise, order);

    return {
      payment_id: payment.id,
      payment_type: type,
      gateway: order.gateway,
      gateway_order_id: order.gatewayOrderId,
      amount_paise: order.amountPaise,
      currency: order.currency,
    };
  }

  private async upsertGroupPayment(
    groupId: string,
    customerId: string,
    type: 'ADVANCE_TOKEN' | 'BALANCE_SETTLEMENT',
    amountPaise: bigint,
    order: { gateway: string; gatewayOrderId: string },
  ) {
    const existing = await this.prisma.payment.findFirst({
      where: { groupBookingId: groupId, gatewayOrderId: order.gatewayOrderId, status: 'INITIATED' },
    });
    if (existing) return existing;
    return this.prisma.payment.create({
      data: {
        groupBookingId: groupId,
        customerFk: customerId,
        paymentType: type,
        amountPaise,
        gateway: order.gateway,
        gatewayOrderId: order.gatewayOrderId,
        status: 'INITIATED',
      },
    });
  }

  /**
   * Gateway-verified capture for a MANAGED booking payment. The amount is
   * re-checked against the booking row inside the transaction; capturing the
   * advance on a confirmation-pending booking is what CONFIRMS it.
   */
  async captureGroupPayment(input: {
    paymentDbId: string;
    customerId: string;
    gatewayOrderId: string;
    gatewayPaymentId: string;
    signature: string;
  }): Promise<CaptureResult> {
    const payment = await this.prisma.payment.findUnique({ where: { id: input.paymentDbId } });
    if (!payment?.groupBookingId) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Payment not found.');
    }
    if (payment.customerFk !== input.customerId) {
      throw new UnauthorizedException(ErrorCode.ROLE_FORBIDDEN, 'Not your payment.');
    }
    if (payment.status === 'SUCCESS') {
      return { captured: false, already_captured: true };
    }
    if (!input.gatewayOrderId || !input.gatewayPaymentId || !input.signature) {
      throw new BadRequestAppException(
        ErrorCode.PAYMENT_SIGNATURE_MISMATCH,
        'Gateway order id, payment id, and signature are required.',
      );
    }

    const verification = await this.gateway.verifyPayment({
      gatewayOrderId: input.gatewayOrderId,
      gatewayPaymentId: input.gatewayPaymentId,
      signature: input.signature,
    });
    if (!verification.verified) {
      throw new UnauthorizedException(
        ErrorCode.PAYMENT_SIGNATURE_MISMATCH,
        'Payment signature verification failed.',
      );
    }
    if (verification.amountPaise !== Number(payment.amountPaise)) {
      throw new ConflictAppException(
        ErrorCode.PAYMENT_SIGNATURE_MISMATCH,
        'Captured amount does not match the order amount.',
      );
    }

    return this.captureGroupTx(
      payment.id,
      payment.groupBookingId,
      payment.customerFk,
      payment.paymentType as 'ADVANCE_TOKEN' | 'BALANCE_SETTLEMENT',
      input.gatewayOrderId,
      input.gatewayPaymentId,
      Number(payment.amountPaise),
    );
  }

  /**
   * DEV-ONLY simulated hosted checkout for managed bookings — the server signs
   * and pushes the capture through the REAL verification path.
   */
  async devGroupCheckout(input: { paymentDbId: string; customerId: string; gatewayOrderId: string }): Promise<CaptureResult> {
    if (process.env.NODE_ENV === 'production') {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        'Simulated checkout is not available in production.',
      );
    }
    const payment = await this.prisma.payment.findUnique({ where: { id: input.paymentDbId } });
    if (!payment?.groupBookingId) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Payment not found.');
    }
    if (payment.customerFk !== input.customerId) {
      throw new UnauthorizedException(ErrorCode.ROLE_FORBIDDEN, 'Not your payment.');
    }
    if (payment.status === 'SUCCESS') {
      return { captured: false, already_captured: true };
    }
    if (payment.gatewayOrderId !== input.gatewayOrderId) {
      throw new ConflictAppException(
        ErrorCode.PAYMENT_SIGNATURE_MISMATCH,
        'Order does not belong to this payment.',
      );
    }
    const gateway = this.gateway as PaymentGateway & {
      devSignPayment?: (orderId: string, paymentId: string) => string;
    };
    if (typeof gateway.devSignPayment !== 'function') {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        'Configured gateway does not support simulated checkout.',
      );
    }
    const gatewayPaymentId = `pay_dev_${Date.now().toString(36)}`;
    const signature = gateway.devSignPayment(payment.gatewayOrderId!, gatewayPaymentId);
    return this.captureGroupPayment({
      paymentDbId: payment.id,
      customerId: input.customerId,
      gatewayOrderId: payment.gatewayOrderId!,
      gatewayPaymentId,
      signature,
    });
  }

  /** Marks a group payment SUCCESS and settles the corresponding stage. */
  private async captureGroupTx(
    paymentId: string,
    groupId: string,
    customerId: string,
    type: 'ADVANCE_TOKEN' | 'BALANCE_SETTLEMENT',
    gatewayOrderId: string,
    gatewayPaymentId: string,
    paymentAmountPaise: number,
  ): Promise<CaptureResult> {
    const { booking_status } = await this.prisma.$transaction(async (tx) => {
      const group = await tx.groupBooking.findUnique({ where: { id: groupId } });
      if (!group) {
        throw new NotFoundAppException(ErrorCode.GROUP_BOOKING_NOT_FOUND, 'Group booking not found.');
      }
      const total = group.estimatedTotalPaise;
      if (total == null) {
        throw new ConflictAppException(ErrorCode.CONFLICT, 'This booking was never priced.');
      }
      const expected =
        type === 'ADVANCE_TOKEN'
          ? (total * ADVANCE_PERCENT) / 100n
          : total - (total * ADVANCE_PERCENT) / 100n;
      if (expected !== BigInt(paymentAmountPaise)) {
        // The quote moved after the order was created — refuse, never capture.
        throw new ConflictAppException(
          ErrorCode.PAYMENT_SIGNATURE_MISMATCH,
          'Captured amount does not match the current booking quote.',
        );
      }
      if (type === 'ADVANCE_TOKEN' && group.advancePaidAt != null) {
        throw new ConflictAppException(
          ErrorCode.PAYMENT_ALREADY_FINALIZED,
          'Advance token already paid for this booking.',
        );
      }
      if (type === 'BALANCE_SETTLEMENT' && group.balancePaidAt != null) {
        throw new ConflictAppException(
          ErrorCode.PAYMENT_ALREADY_FINALIZED,
          'Balance already settled for this booking.',
        );
      }

      await tx.payment.update({
        where: { id: paymentId },
        data: {
          status: 'SUCCESS',
          gatewayOrderId,
          gatewayPaymentId,
          paidAt: new Date(),
        },
      });

      let bookingStatus: string | undefined;
      if (type === 'ADVANCE_TOKEN') {
        const data: Record<string, unknown> = {
          advancePaidAt: new Date(),
          version: { increment: 1 },
        };
        // Money settles the deal: capturing the advance on a
        // confirmation-pending booking is what CONFIRMS it.
        if (group.status === 'CUSTOMER_CONFIRMATION_PENDING' || group.status === 'PAYMENT_PENDING') {
          data.status = 'CONFIRMED';
          bookingStatus = 'CONFIRMED';
        }
        await tx.groupBooking.update({ where: { id: groupId }, data });
      } else {
        await tx.groupBooking.update({
          where: { id: groupId },
          data: { balancePaidAt: new Date(), version: { increment: 1 } },
        });
        bookingStatus = group.status;
      }

      await tx.groupBookingEvent.create({
        data: {
          groupBookingId: groupId,
          fromStatus: group.status,
          toStatus: bookingStatus ?? group.status,
          action: type === 'ADVANCE_TOKEN' ? 'ADVANCE_PAID' : 'BALANCE_PAID',
          triggeredByUserId: customerId,
          triggerRole: 'customer',
          eventReason: 'PAYMENT_CAPTURED',
        },
      });

      return { booking_status: bookingStatus };
    });
    return { captured: true, booking_status };
  }

  /** Payment history for a managed booking (customer or admin view). */
  async listGroupPayments(groupId: string, viewer: { userId: string; isAdmin: boolean }) {
    const group = await this.prisma.groupBooking.findUnique({
      where: { id: groupId },
      select: { customerFk: true, estimatedTotalPaise: true, advancePaidAt: true, balancePaidAt: true },
    });
    if (!group) {
      throw new NotFoundAppException(ErrorCode.GROUP_BOOKING_NOT_FOUND, 'Group booking not found.');
    }
    if (group.customerFk !== viewer.userId && !viewer.isAdmin) {
      throw new NotFoundAppException(ErrorCode.GROUP_BOOKING_NOT_FOUND, 'Group booking not found.');
    }
    const payments = await this.prisma.payment.findMany({
      where: { groupBookingId: groupId },
      orderBy: { createdAt: 'desc' },
    });
    const total = group.estimatedTotalPaise ?? 0n;
    const advance = (total * ADVANCE_PERCENT) / 100n;
    return {
      payments: payments.map((p) => ({
        id: p.id,
        type: p.paymentType,
        status: p.status,
        amount_paise: p.amountPaise.toString(),
        gateway: p.gateway,
        paid_at: p.paidAt,
        created_at: p.createdAt,
      })),
      settlement: {
        total_paise: total.toString(),
        advance_paise: advance.toString(),
        balance_paise: (total - advance).toString(),
        advance_paid_at: group.advancePaidAt,
        balance_paid_at: group.balancePaidAt,
        fully_settled: group.advancePaidAt != null && group.balancePaidAt != null,
      },
    };
  }

  // ============================================================ legacy path

  /** Creates the advance-token order for a booking from DB amounts. */
  async createAdvanceTokenOrder(bookingId: string, customerId: string, idempotencyKey: string) {
    const booking = await this.prisma.booking.findUnique({ where: { id: bookingId } });
    if (!booking) {
      throw new NotFoundAppException(ErrorCode.BOOKING_NOT_FOUND, 'Booking not found.');
    }
    if (booking.customerFk !== customerId) {
      throw new UnauthorizedException(ErrorCode.ROLE_FORBIDDEN, 'Not your booking.');
    }
    if (booking.isAdvancePaid) {
      throw new ConflictAppException(
        ErrorCode.PAYMENT_ALREADY_FINALIZED,
        'Advance token already paid for this booking.',
      );
    }
    // An advance token is payable on an operations-managed request (the
    // customer paid ahead of ops), once ops has requested it, or on a booking
    // that is already confirmed and still owes the advance.
    if (
      ![
        BookingStatus.REQUESTED,
        BookingStatus.PAYMENT_PENDING,
        BookingStatus.PAYMENT_FAILED,
        BookingStatus.CONFIRMED,
      ].includes(booking.status as BookingStatus)
    ) {
      throw new ConflictAppException(
        ErrorCode.INVALID_TRANSITION,
        `Booking in status ${booking.status} cannot accept an advance payment.`,
      );
    }

    const input: CreateOrderInput = {
      bookingId,
      amountPaise: Number(booking.advanceTokenPaise),
      idempotencyKey: `${customerId}:pay:${idempotencyKey}`,
      description: `ShadiDriver advance token for ${booking.referenceCode}`,
    };
    const order = await this.gateway.createOrder(input);

    const payment = await this.upsertPayment(bookingId, customerId, booking.advanceTokenPaise, order);

    return {
      payment_id: payment.id,
      gateway: order.gateway,
      gateway_order_id: order.gatewayOrderId,
      amount_paise: order.amountPaise,
      currency: order.currency,
    };
  }

  /**
   * Client-claimed payment success. The gateway signature is MANDATORY —
   * a missing/invalid signature throws and no state changes.
   */
  async verifyAndCapture(
    input: VerifyPaymentInput & { paymentDbId: string; customerId: string },
  ): Promise<CaptureResult> {
    const payment = await this.prisma.payment.findUnique({ where: { id: input.paymentDbId } });
    if (!payment) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Payment not found.');
    }
    if (payment.customerFk !== input.customerId) {
      throw new UnauthorizedException(ErrorCode.ROLE_FORBIDDEN, 'Not your payment.');
    }
    if (payment.status === 'SUCCESS') {
      const result: CaptureResult = { captured: false, already_captured: true, booking_status: undefined };
      return result;
    }
    if (!input.gatewayOrderId || !input.gatewayPaymentId || !input.signature) {
      throw new BadRequestAppException(
        ErrorCode.PAYMENT_SIGNATURE_MISMATCH,
        'Gateway order id, payment id, and signature are required.',
      );
    }

    const verification = await this.gateway.verifyPayment({
      gatewayOrderId: input.gatewayOrderId,
      gatewayPaymentId: input.gatewayPaymentId,
      signature: input.signature,
    });
    if (!verification.verified) {
      throw new UnauthorizedException(
        ErrorCode.PAYMENT_SIGNATURE_MISMATCH,
        'Payment signature verification failed.',
      );
    }
    if (verification.amountPaise !== Number(payment.amountPaise)) {
      throw new ConflictAppException(
        ErrorCode.PAYMENT_SIGNATURE_MISMATCH,
        'Captured amount does not match the booking advance token.',
      );
    }

    return this.capturePayment(
      payment.id,
      payment.bookingId!,
      payment.customerFk,
      input.gatewayOrderId,
      input.gatewayPaymentId,
      Number(payment.amountPaise),
    );
  }

  /**
   * DEV-ONLY simulated hosted checkout. The SERVER signs the payment and
   * captures it through the exact same verification path a real gateway
   * callback would take. Never wired in production (the controller must not
   * expose it when NODE_ENV=production).
   */
  async devHostedCheckout(input: {
    paymentDbId: string;
    customerId: string;
    gatewayOrderId: string;
  }): Promise<CaptureResult> {
    if (process.env.NODE_ENV === 'production') {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        'Simulated checkout is not available in production.',
      );
    }
    const payment = await this.prisma.payment.findUnique({
      where: { id: input.paymentDbId },
    });
    if (!payment) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Payment not found.');
    }
    if (payment.customerFk !== input.customerId) {
      throw new UnauthorizedException(ErrorCode.ROLE_FORBIDDEN, 'Not your payment.');
    }
    if (payment.status === 'SUCCESS') {
      const result: CaptureResult = { captured: false, already_captured: true, booking_status: undefined };
      return result;
    }
    // Guard against a fake gateway_order_id that does not belong to this payment.
    if (payment.gatewayOrderId !== input.gatewayOrderId) {
      throw new ConflictAppException(
        ErrorCode.PAYMENT_SIGNATURE_MISMATCH,
        'Order does not belong to this payment.',
      );
    }
    const gateway = this.gateway as PaymentGateway & {
      devSignPayment?: (orderId: string, paymentId: string) => string;
    };
    if (typeof gateway.devSignPayment !== 'function') {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        'Configured gateway does not support simulated checkout.',
      );
    }
    const gatewayPaymentId = `pay_dev_${Date.now().toString(36)}`;
    const signature = gateway.devSignPayment(payment.gatewayOrderId, gatewayPaymentId);
    // Route through the REAL verification path so the dev flow exercises
    // exactly what a production gateway callback would.
    return this.verifyAndCapture({
      paymentDbId: payment.id,
      customerId: input.customerId,
      gatewayOrderId: payment.gatewayOrderId,
      gatewayPaymentId,
      signature,
    });
  }

  /** Webhook ingestion: HMAC-verified, idempotent, transitions booking → CONFIRMED. */
  async ingestWebhook(event: WebhookEvent): Promise<WebhookResult> {
    const verification = this.gateway.verifyWebhook(event);
    if (!verification.verified) {
      throw new UnauthorizedException(
        ErrorCode.PAYMENT_SIGNATURE_MISMATCH,
        'Webhook signature verification failed.',
      );
    }
    if (!verification.order_id) {
      throw new BadRequestAppException(ErrorCode.VALIDATION_FAILED, 'Webhook missing order id.');
    }
    // A webhook can settle EITHER path: a legacy booking payment or a managed
    // (group) booking payment. Route to the matching capture transaction.
    const payment = await this.prisma.payment.findFirst({
      where: { gatewayOrderId: verification.order_id },
    });
    if (!payment) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Payment for webhook order not found.');
    }
    if (payment.status === 'SUCCESS') {
      const result: WebhookResult = { processed: true, duplicate: true };
      return result;
    }
    if (payment.groupBookingId) {
      const groupResult = await this.captureGroupTx(
        payment.id,
        payment.groupBookingId,
        payment.customerFk,
        payment.paymentType as 'ADVANCE_TOKEN' | 'BALANCE_SETTLEMENT',
        verification.order_id,
        `wh_${Date.now()}`,
        Number(payment.amountPaise),
      );
      return { processed: true, captured: groupResult.captured, booking_status: groupResult.booking_status };
    }
    return this.capturePayment(
      payment.id,
      payment.bookingId!,
      payment.customerFk,
      verification.order_id,
      `wh_${Date.now()}`,
      Number(payment.amountPaise),
    );
  }

  private async upsertPayment(
    bookingId: string,
    customerId: string,
    amountPaise: bigint,
    order: { gateway: string; gatewayOrderId: string },
  ) {
    const existing = await this.prisma.payment.findFirst({
      where: { bookingId, gatewayOrderId: order.gatewayOrderId, status: 'INITIATED' },
    });
    if (existing) return existing;
    return this.prisma.payment.create({
      data: {
        bookingId,
        customerFk: customerId,
        paymentType: 'ADVANCE_TOKEN',
        amountPaise,
        gateway: order.gateway,
        gatewayOrderId: order.gatewayOrderId,
        status: 'INITIATED',
      },
    });
  }

  /** Marks payment SUCCESS + transitions booking DRIVER_ACCEPTED → CONFIRMED. */
  private async capturePayment(
    paymentId: string,
    bookingId: string,
    customerId: string,
    gatewayOrderId: string,
    gatewayPaymentId: string,
    paymentAmountPaise: number,
  ) {
    const result = await this.prisma.$transaction(async (tx) => {
      const booking = await tx.booking.findUnique({ where: { id: bookingId } });
      if (!booking) {
        throw new NotFoundAppException(ErrorCode.BOOKING_NOT_FOUND, 'Booking not found.');
      }
      // Amount authority lives on the booking row: if the booking advance changed
      // after the order was created, refuse to capture a mismatched payment.
      if (booking.advanceTokenPaise !== BigInt(paymentAmountPaise)) {
        throw new ConflictAppException(
          ErrorCode.PAYMENT_SIGNATURE_MISMATCH,
          'Captured amount does not match the booking advance token.',
        );
      }
      await tx.payment.update({
        where: { id: paymentId },
        data: {
          status: 'SUCCESS',
          gatewayOrderId,
          gatewayPaymentId,
          paidAt: new Date(),
        },
      });

      let bookingStatus: string | undefined;
      if (booking.status === BookingStatus.PAYMENT_PENDING) {
        // Operations-managed path: the customer has agreed to the proposal,
        // operations requested the advance, and a gateway-verified capture
        // completes the booking. Nothing here depends on a driver accepting.
        this.stateMachine.assertTransitionAllowed(
          booking.status as BookingStatus,
          'CONFIRM_PAYMENT',
          'SYSTEM' as ActorRole,
        );
        const updated = await tx.booking.update({
          where: { id: bookingId },
          data: { status: BookingStatus.CONFIRMED, isAdvancePaid: true, version: { increment: 1 } },
        });
        bookingStatus = updated.status;
      } else if (booking.status === BookingStatus.CONFIRMED) {
        // Advance settlement on an already-confirmed booking: record the
        // payment without mutating lifecycle state.
        await tx.booking.update({
          where: { id: bookingId },
          data: { isAdvancePaid: true, version: { increment: 1 } },
        });
      } else if (booking.status === BookingStatus.REQUESTED) {
        // The customer paid before operations finished sourcing vehicles.
        // Record the money, leave the request in the operations queue.
        await tx.booking.update({
          where: { id: bookingId },
          data: { isAdvancePaid: true, version: { increment: 1 } },
        });
      }

      await tx.bookingEvent.create({
        data: {
          bookingId,
          fromStatus: booking.status,
          toStatus: bookingStatus ?? booking.status,
          triggeredByUserId: customerId,
          triggerRole: 'SYSTEM',
          eventReason: 'PAYMENT_TOKEN_CAPTURED',
          eventMetadata: { gateway_order_id: gatewayOrderId, gateway_payment_id: gatewayPaymentId },
        },
      });

      return { booking_status: bookingStatus };
    });
    return { captured: true, ...result };
  }
}
