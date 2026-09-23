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
    @Inject(PAYMENT_GATEWAY) private readonly gateway: PaymentGateway,
  ) {}

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
    if (
      ![BookingStatus.DRIVER_ACCEPTED, BookingStatus.REQUESTED].includes(
        booking.status as BookingStatus,
      )
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
      payment.bookingId,
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
    return this.capturePayment(
      payment.id,
      payment.bookingId,
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
      if (booking.status === BookingStatus.DRIVER_ACCEPTED) {
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
      } else if (booking.status === BookingStatus.REQUESTED) {
        // Pay-to-confirm path: booking advances to CONFIRMED once the
        // chauffeur accepts (assignment flows stay intact).
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
