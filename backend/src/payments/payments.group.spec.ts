import { PaymentsService } from './payments.service';
import { BookingStateMachineService } from '../booking-state-machine/booking-state-machine.service';

/**
 * Managed (group) booking payment rules. Amounts are ALWAYS derived from the
 * booking row (25% advance of the quoted total / remainder as balance) — a
 * client-declared amount is structurally unreachable. Capturing the advance on
 * a confirmation-pending booking is what CONFIRMS it; the balance gates trip
 * completion.
 */

const GROUP_ID = '11111111-2222-4333-8444-555555555555';
const CUSTOMER_ID = 'customer-1';
const TOTAL_PAISE = 11_250_000n; // ₹1,12,500 quoted
const ADVANCE_PAISE = 2_812_500n; // 25%
const BALANCE_PAISE = 8_437_500n; // 75%

function groupRow(overrides: Record<string, unknown> = {}) {
  return {
    id: GROUP_ID,
    referenceCode: 'SD-GRP-2026-000555',
    customerFk: CUSTOMER_ID,
    status: 'CUSTOMER_CONFIRMATION_PENDING',
    estimatedTotalPaise: TOTAL_PAISE,
    advancePaidAt: null as Date | null,
    balancePaidAt: null as Date | null,
    ...overrides,
  };
}

describe('PaymentsService — managed (group) bookings', () => {
  let service: PaymentsService;

  const group: any = {
    findUnique: jest.fn(),
    update: jest.fn(),
  };
  const groupBookingEvent: any = { create: jest.fn() };
  const payment: any = {
    findUnique: jest.fn(),
    findFirst: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(async ({ data }: any) => ({ id: 'pay-1', status: 'INITIATED', ...data })),
    update: jest.fn(async ({ data }: any) => data),
  };
  const prisma: any = {
    groupBooking: group,
    groupBookingEvent,
    payment,
    $transaction: jest.fn(async (fn: any) => fn(prisma)),
  };
  const gateway: any = {
    createOrder: jest.fn(async (input: any) => ({
      gateway: 'MOCK',
      gatewayOrderId: 'order_mock_1',
      amountPaise: input.amountPaise,
      currency: 'INR',
    })),
    verifyPayment: jest.fn(async (_input: any) => ({ verified: true, amountPaise: 0 })),
    devSignPayment: (orderId: string, paymentId: string) => `sig(${orderId},${paymentId})`,
  };
  const groupBookings: any = {};

  beforeEach(() => {
    jest.clearAllMocks();
    group.findUnique.mockResolvedValue(groupRow());
    group.update.mockResolvedValue({});
    groupBookingEvent.create.mockResolvedValue({});
    payment.findUnique.mockImplementation(async ({ where }: any) => ({
      id: where.id,
      groupBookingId: GROUP_ID,
      customerFk: CUSTOMER_ID,
      paymentType: 'ADVANCE_TOKEN',
      amountPaise: ADVANCE_PAISE,
      status: 'INITIATED',
      gatewayOrderId: 'order_mock_1',
    }));
    payment.findFirst.mockResolvedValue(null);
    // verifyPayment echoes the order amount so capture passes by default.
    gateway.verifyPayment.mockImplementation(async () => ({
      verified: true,
      amountPaise: Number(ADVANCE_PAISE),
    }));
    service = new PaymentsService(
      prisma,
      new BookingStateMachineService(),
      groupBookings,
      gateway,
    );
  });

  // ---------------------------------------------------------------- orders

  describe('order creation', () => {
    it('the advance order amount is 25% of the DB quote — never client input', async () => {
      const result = await service.createGroupAdvanceOrder(GROUP_ID, CUSTOMER_ID, 'idem-1');
      expect(result.amount_paise).toBe(Number(ADVANCE_PAISE));
      expect(gateway.createOrder).toHaveBeenCalledWith(
        expect.objectContaining({ amountPaise: Number(ADVANCE_PAISE) }),
      );
    });

    it('the balance order amount is the remainder after the advance', async () => {
      group.findUnique.mockResolvedValue(
        groupRow({ status: 'CONFIRMED', advancePaidAt: new Date() }),
      );
      const result = await service.createGroupBalanceOrder(GROUP_ID, CUSTOMER_ID, 'idem-2');
      expect(result.amount_paise).toBe(Number(BALANCE_PAISE));
    });

    it('refuses an advance order on a booking with no complete quote', async () => {
      group.findUnique.mockResolvedValue(groupRow({ estimatedTotalPaise: null }));
      await expect(
        service.createGroupAdvanceOrder(GROUP_ID, CUSTOMER_ID, 'idem-3'),
      ).rejects.toThrow(/no complete price yet/i);
    });

    it('refuses an advance order before operations opens the confirmation window', async () => {
      group.findUnique.mockResolvedValue(groupRow({ status: 'UNDER_REVIEW' }));
      await expect(
        service.createGroupAdvanceOrder(GROUP_ID, CUSTOMER_ID, 'idem-4'),
      ).rejects.toMatchObject({ code: 'INVALID_TRANSITION' });
    });

    it('refuses a duplicate advance order once the advance is settled', async () => {
      group.findUnique.mockResolvedValue(
        groupRow({ status: 'CONFIRMED', advancePaidAt: new Date() }),
      );
      await expect(
        service.createGroupAdvanceOrder(GROUP_ID, CUSTOMER_ID, 'idem-5'),
      ).rejects.toMatchObject({ code: 'PAYMENT_ALREADY_FINALIZED' });
    });

    it('refuses a balance order while the advance is outstanding', async () => {
      await expect(
        service.createGroupBalanceOrder(GROUP_ID, CUSTOMER_ID, 'idem-6'),
      ).rejects.toThrow(/advance token must be settled/i);
    });

    it('another customer gets 404, not 403 — no probing oracle', async () => {
      await expect(
        service.createGroupAdvanceOrder(GROUP_ID, 'someone-else', 'idem-7'),
      ).rejects.toMatchObject({ code: 'GROUP_BOOKING_NOT_FOUND' });
    });
  });

  // --------------------------------------------------------------- capture

  describe('captureGroupPayment', () => {
    it('capturing the advance CONFIRMS a confirmation-pending booking', async () => {
      const result = await service.captureGroupPayment({
        paymentDbId: 'pay-1',
        customerId: CUSTOMER_ID,
        gatewayOrderId: 'order_mock_1',
        gatewayPaymentId: 'pay_gw_1',
        signature: 'sig',
      });

      expect(result.captured).toBe(true);
      expect(result.booking_status).toBe('CONFIRMED');
      expect(group.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ status: 'CONFIRMED', advancePaidAt: expect.any(Date) }),
        }),
      );
      expect(groupBookingEvent.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ action: 'ADVANCE_PAID', triggerRole: 'customer' }),
        }),
      );
    });

    it('capturing the advance on an already-CONFIRMED booking does not rewind status', async () => {
      group.findUnique.mockResolvedValue(groupRow({ status: 'CONFIRMED' }));
      const result = await service.captureGroupPayment({
        paymentDbId: 'pay-1',
        customerId: CUSTOMER_ID,
        gatewayOrderId: 'order_mock_1',
        gatewayPaymentId: 'pay_gw_2',
        signature: 'sig',
      });
      expect(result.booking_status).toBeUndefined();
      const data = group.update.mock.calls[0][0].data;
      expect(data.status).toBeUndefined();
      expect(data.advancePaidAt).toBeTruthy();
    });

    it('settling the balance only stamps balancePaidAt', async () => {
      group.findUnique.mockResolvedValue(
        groupRow({ status: 'IN_PROGRESS', advancePaidAt: new Date() }),
      );
      payment.findUnique.mockImplementation(async ({ where }: any) => ({
        id: where.id,
        groupBookingId: GROUP_ID,
        customerFk: CUSTOMER_ID,
        paymentType: 'BALANCE_SETTLEMENT',
        amountPaise: BALANCE_PAISE,
        status: 'INITIATED',
        gatewayOrderId: 'order_mock_1',
      }));
      gateway.verifyPayment.mockImplementation(async () => ({
        verified: true,
        amountPaise: Number(BALANCE_PAISE),
      }));

      await service.captureGroupPayment({
        paymentDbId: 'pay-1',
        customerId: CUSTOMER_ID,
        gatewayOrderId: 'order_mock_1',
        gatewayPaymentId: 'pay_gw_3',
        signature: 'sig',
      });
      const data = group.update.mock.calls[0][0].data;
      expect(data.balancePaidAt).toBeTruthy();
      expect(data.status).toBeUndefined();
      expect(groupBookingEvent.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ action: 'BALANCE_PAID' }),
        }),
      );
    });

    it('refuses capture when the quote moved after the order was created', async () => {
      group.findUnique.mockResolvedValue(groupRow({ estimatedTotalPaise: 99_000_000n }));
      await expect(
        service.captureGroupPayment({
          paymentDbId: 'pay-1',
          customerId: CUSTOMER_ID,
          gatewayOrderId: 'order_mock_1',
          gatewayPaymentId: 'pay_gw_4',
          signature: 'sig',
        }),
      ).rejects.toMatchObject({ code: 'PAYMENT_SIGNATURE_MISMATCH' });
    });

    it('a failed signature verification captures nothing', async () => {
      gateway.verifyPayment.mockImplementation(async () => ({ verified: false, amountPaise: 0 }));
      await expect(
        service.captureGroupPayment({
          paymentDbId: 'pay-1',
          customerId: CUSTOMER_ID,
          gatewayOrderId: 'order_mock_1',
          gatewayPaymentId: 'pay_gw_5',
          signature: 'forged',
        }),
      ).rejects.toMatchObject({ code: 'PAYMENT_SIGNATURE_MISMATCH' });
      expect(payment.update).not.toHaveBeenCalled();
      expect(group.update).not.toHaveBeenCalled();
    });

    it('another customer cannot capture my payment', async () => {
      await expect(
        service.captureGroupPayment({
          paymentDbId: 'pay-1',
          customerId: 'someone-else',
          gatewayOrderId: 'order_mock_1',
          gatewayPaymentId: 'pay_gw_6',
          signature: 'sig',
        }),
      ).rejects.toMatchObject({ code: 'ROLE_FORBIDDEN' });
    });
  });

  // ----------------------------------------------------------- dev checkout

  describe('devGroupCheckout', () => {
    it('routes through the REAL verification path (server-signed)', async () => {
      const result = await service.devGroupCheckout({
        paymentDbId: 'pay-1',
        customerId: CUSTOMER_ID,
        gatewayOrderId: 'order_mock_1',
      });
      expect(result.captured).toBe(true);
      expect(gateway.verifyPayment).toHaveBeenCalled();
      expect(result.booking_status).toBe('CONFIRMED');
    });

    it('is forbidden in production', async () => {
      process.env.NODE_ENV = 'production';
      await expect(
        service.devGroupCheckout({
          paymentDbId: 'pay-1',
          customerId: CUSTOMER_ID,
          gatewayOrderId: 'order_mock_1',
        }),
      ).rejects.toThrow(/not available in production/i);
    });
  });

  // ----------------------------------------------------------------- history

  describe('listGroupPayments', () => {
    it('exposes settlement state to the owner with paise-safe strings', async () => {
      group.findUnique.mockResolvedValue({
        customerFk: CUSTOMER_ID,
        estimatedTotalPaise: TOTAL_PAISE,
        advancePaidAt: new Date(),
        balancePaidAt: null,
      });
      payment.findMany.mockResolvedValue([
        { id: 'p1', paymentType: 'ADVANCE_TOKEN', status: 'SUCCESS', amountPaise: ADVANCE_PAISE, gateway: 'MOCK', paidAt: new Date(), createdAt: new Date() },
      ]);

      const result = await service.listGroupPayments(GROUP_ID, { userId: CUSTOMER_ID, isAdmin: false });
      expect(result.settlement.advance_paise).toBe(ADVANCE_PAISE.toString());
      expect(result.settlement.fully_settled).toBe(false);
    });

    it('hides another customer’s payment history behind a 404', async () => {
      group.findUnique.mockResolvedValue({
        customerFk: CUSTOMER_ID,
        estimatedTotalPaise: TOTAL_PAISE,
        advancePaidAt: null,
        balancePaidAt: null,
      });
      await expect(
        service.listGroupPayments(GROUP_ID, { userId: 'intruder', isAdmin: false }),
      ).rejects.toMatchObject({ code: 'GROUP_BOOKING_NOT_FOUND' });
    });
  });
});
