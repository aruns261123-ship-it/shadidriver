import { createHmac } from 'crypto';
import { PaymentsService } from './payments.service';
import { MockPaymentGateway } from './mock-gateway.provider';
import { BookingStateMachineService } from '../booking-state-machine/booking-state-machine.service';

describe('PaymentsService (gateway-verified capture)', () => {
  let service: PaymentsService;
  let gateway: MockPaymentGateway;
  let prisma: any;

  const customer = { id: 'cust-1' };

  function bookingRow(overrides: Record<string, unknown> = {}) {
    return {
      id: 'bk-1',
      customerFk: customer.id,
      status: 'PAYMENT_PENDING',
      isAdvancePaid: false,
      advanceTokenPaise: 750_000n,
      estimatedTotalPaise: 3_000_000n,
      version: 1,
      ...overrides,
    };
  }

  beforeEach(() => {
    process.env.NODE_ENV = 'development';
    gateway = new MockPaymentGateway({ PAYMENT_WEBHOOK_SECRET: 'test-secret' });

    const payments: any[] = [];
    let paymentSeq = 1;
    prisma = {
      booking: {
        findUnique: jest.fn(async ({ where }) =>
          where.id === 'bk-1' ? prisma.__booking : null,
        ),
        update: jest.fn(async ({ data }) => {
          Object.assign(prisma.__booking, data);
          if (data.version?.increment) prisma.__booking.version += data.version.increment;
          return prisma.__booking;
        }),
      },
      bookingEvent: { create: jest.fn().mockResolvedValue({}) },
      payment: {
        findUnique: jest.fn(async ({ where }) =>
          payments.find((p) => p.id === where.id) ?? null,
        ),
        findFirst: jest.fn(async ({ where }) =>
          payments.find((p) => p.gatewayOrderId === where.gatewayOrderId) ??
          payments.find((p) => p.bookingId === where.bookingId && p.status === 'INITIATED') ??
          null,
        ),
        create: jest.fn(async ({ data }) => {
          const p = { id: `pay-${paymentSeq++}`, ...data };
          payments.push(p);
          return p;
        }),
        update: jest.fn(async ({ where, data }) => {
          const p = payments.find((x) => x.id === where.id);
          Object.assign(p, data);
          return p;
        }),
      },
      $transaction: jest.fn(async (fn) => fn(prisma)),
      __booking: bookingRow(),
      __payments: payments,
    };

    service = new PaymentsService(
      prisma,
      new BookingStateMachineService(),
      gateway as never,
    );
  });

  afterEach(() => {
    delete process.env.NODE_ENV;
  });

  it('order amount comes from the booking row, never from the client', async () => {
    const result = await service.createAdvanceTokenOrder('bk-1', customer.id, 'idem-1');
    expect(result.amount_paise).toBe(750_000); // booking.advanceTokenPaise
    expect(result.gateway_order_id).toBeTruthy();
  });

  it('same idempotency key returns the SAME gateway order', async () => {
    const a = await service.createAdvanceTokenOrder('bk-1', customer.id, 'idem-1');
    const b = await service.createAdvanceTokenOrder('bk-1', customer.id, 'idem-1');
    expect(b.gateway_order_id).toBe(a.gateway_order_id);
  });

  it('rejects capture when the signature is missing or wrong (client cannot fake success)', async () => {
    const order = await service.createAdvanceTokenOrder('bk-1', customer.id, 'idem-1');
    const payment = prisma.__payments[0];

    await expect(
      service.verifyAndCapture({
        paymentDbId: payment.id,
        customerId: customer.id,
        gatewayOrderId: order.gateway_order_id,
        gatewayPaymentId: 'pay_x',
        signature: 'deadbeef',
      }),
    ).rejects.toThrow(/signature/i);
    expect(prisma.__payments[0].status).toBe('INITIATED');
    expect(prisma.__booking.status).toBe('PAYMENT_PENDING');

    await expect(
      service.verifyAndCapture({
        paymentDbId: payment.id,
        customerId: customer.id,
        gatewayOrderId: order.gateway_order_id,
        gatewayPaymentId: 'pay_x',
        signature: '',
      }),
    ).rejects.toThrow(/signature/i);
  });

  it('capture succeeds with a valid signature and transitions booking → CONFIRMED', async () => {
    const order = await service.createAdvanceTokenOrder('bk-1', customer.id, 'idem-1');
    const payment = prisma.__payments[0];
    const sig = gateway.devSignPayment(order.gateway_order_id, 'pay_x');

    const result = await service.verifyAndCapture({
      paymentDbId: payment.id,
      customerId: customer.id,
      gatewayOrderId: order.gateway_order_id,
      gatewayPaymentId: 'pay_x',
      signature: sig,
    });
    expect(result.captured).toBe(true);
    expect(result.booking_status).toBe('CONFIRMED');
    expect(prisma.__payments[0].status).toBe('SUCCESS');
    expect(prisma.__booking.status).toBe('CONFIRMED');
    expect(prisma.__booking.isAdvancePaid).toBe(true);
  });

  it('rejects a captured amount differing from the booking advance', async () => {
    // Tamper the booking's advance AFTER order creation.
    const order = await service.createAdvanceTokenOrder('bk-1', customer.id, 'idem-1');
    const payment = prisma.__payments[0];
    prisma.__booking.advanceTokenPaise = 999n;
    const sig = gateway.devSignPayment(order.gateway_order_id, 'pay_x');
    await expect(
      service.verifyAndCapture({
        paymentDbId: payment.id,
        customerId: customer.id,
        gatewayOrderId: order.gateway_order_id,
        gatewayPaymentId: 'pay_x',
        signature: sig,
      }),
    ).rejects.toThrow(/does not match/i);
  });

  it('another customer cannot capture someone else’s payment', async () => {
    const order = await service.createAdvanceTokenOrder('bk-1', customer.id, 'idem-1');
    const payment = prisma.__payments[0];
    const sig = gateway.devSignPayment(order.gateway_order_id, 'pay_x');
    await expect(
      service.verifyAndCapture({
        paymentDbId: payment.id,
        customerId: 'attacker',
        gatewayOrderId: order.gateway_order_id,
        gatewayPaymentId: 'pay_x',
        signature: sig,
      }),
    ).rejects.toThrow(/Not your payment/);
  });

  it('webhook with a valid signature captures idempotently', async () => {
    const order = await service.createAdvanceTokenOrder('bk-1', customer.id, 'idem-1');
    const rawBody = JSON.stringify({ event: 'payment.captured', order_id: order.gateway_order_id });
    const sig = createHmac('sha256', 'test-secret').update(rawBody).digest('hex');

    const first = await service.ingestWebhook({ rawBody, signature: sig });
    expect(first.captured).toBe(true);

    // Replayed webhook is a no-op duplicate.
    const second = await service.ingestWebhook({ rawBody, signature: sig });
    expect(second.duplicate).toBe(true);
  });

  it('webhook with a bad signature is rejected', async () => {
    const order = await service.createAdvanceTokenOrder('bk-1', customer.id, 'idem-1');
    const rawBody = JSON.stringify({ event: 'payment.captured', order_id: order.gateway_order_id });
    await expect(
      service.ingestWebhook({ rawBody, signature: 'forged' }),
    ).rejects.toThrow(/signature/i);
  });

  it('double capture is refused after success', async () => {
    const order = await service.createAdvanceTokenOrder('bk-1', customer.id, 'idem-1');
    const payment = prisma.__payments[0];
    const sig = gateway.devSignPayment(order.gateway_order_id, 'pay_x');
    await service.verifyAndCapture({
      paymentDbId: payment.id,
      customerId: customer.id,
      gatewayOrderId: order.gateway_order_id,
      gatewayPaymentId: 'pay_x',
      signature: sig,
    });
    prisma.__booking.status = 'CONFIRMED';
    await expect(
      service.createAdvanceTokenOrder('bk-1', customer.id, 'idem-2'),
    ).rejects.toThrow(/already paid/i);
  });
});
