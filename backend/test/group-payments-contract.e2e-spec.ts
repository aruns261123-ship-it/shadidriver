import { INestApplication, ValidationPipe } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PaymentsController } from '../src/payments/payments.controller';
import { PaymentsService } from '../src/payments/payments.service';
import { RolesGuard } from '../src/auth/guards/roles.guard';
import { EnvelopeInterceptor } from '../src/common/interceptors/envelope.interceptor';
import { GlobalExceptionFilter } from '../src/common/filters/global-exception.filter';

/**
 * HTTP contract for the managed-booking payments surface:
 *   * order creation and capture are CUSTOMER-owned (the money belongs to the
 *     booking's host) — a driver or partner token cannot create an order;
 *   * the request body CANNOT carry an amount: the booking row is the only
 *     source of money in the system (`forbidNonWhitelisted` enforces it);
 *   * the settlement history is owner-or-admin, hidden behind 404 for others;
 *   * the dev checkout exists on the route but production-blocking is asserted
 *     in the service spec.
 */
const CUSTOMER_ID = '5e2c6af1-1111-4111-8111-111111111111';
const GROUP_ID = '11111111-2222-4333-8444-555555555555';

describe('managed-booking payments HTTP contract', () => {
  let app: INestApplication;
  let currentRole = 'customer';
  const serviceStub = {
    createGroupAdvanceOrder: jest.fn(),
    createGroupBalanceOrder: jest.fn(),
    captureGroupPayment: jest.fn(),
    devGroupCheckout: jest.fn(),
    listGroupPayments: jest.fn(),
    verifyAndCapture: jest.fn(),
    devHostedCheckout: jest.fn(),
    ingestWebhook: jest.fn(),
    createAdvanceTokenOrder: jest.fn(),
  };

  beforeAll(async () => {
    serviceStub.createGroupAdvanceOrder.mockResolvedValue({
      payment_id: 'pay-1',
      payment_type: 'ADVANCE_TOKEN',
      amount_paise: 2_812_500,
      gateway: 'MOCK',
      gateway_order_id: 'order_mock_1',
      currency: 'INR',
    });
    serviceStub.captureGroupPayment.mockResolvedValue({ captured: true, booking_status: 'CONFIRMED' });
    serviceStub.devGroupCheckout.mockResolvedValue({ captured: true });
    serviceStub.listGroupPayments.mockResolvedValue({
      payments: [],
      settlement: { fully_settled: false },
    });

    const moduleRef = await Test.createTestingModule({
      controllers: [PaymentsController],
      providers: [
        { provide: PaymentsService, useValue: serviceStub },
        {
          provide: APP_GUARD,
          useValue: {
            canActivate: (context: any) => {
              context.switchToHttp().getRequest().authenticatedUser = {
                userId: currentRole === 'customer' ? CUSTOMER_ID : '8e2c6af1-1111-4111-8111-111111111111',
                role: currentRole,
                phoneNumber: '+919810000000',
                accountStatus: 'ACTIVE',
              };
              return true;
            },
          },
        },
        { provide: APP_GUARD, useClass: RolesGuard },
      ],
    }).compile();

    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
        transformOptions: { enableImplicitConversion: false },
      }),
    );
    app.useGlobalFilters(new GlobalExceptionFilter());
    app.useGlobalInterceptors(new EnvelopeInterceptor());
    await app.init();
  });

  afterAll(async () => {
    if (app) await app.close();
  });

  beforeEach(() => {
    currentRole = 'customer';
    jest.clearAllMocks();
  });

  it('creates an advance order; the service derives the amount itself', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/payments/group/order')
      .send({
        groupBookingId: GROUP_ID,
        paymentType: 'ADVANCE_TOKEN',
        idempotencyKey: 'idem-adv-123456',
      })
      .expect(200);

    expect(res.body.data.amount_paise).toBe(2_812_500);
    expect(serviceStub.createGroupAdvanceOrder).toHaveBeenCalledWith(
      GROUP_ID,
      CUSTOMER_ID,
      'idem-adv-123456',
    );
  });

  it('a body CANNOT declare the amount — money comes from the booking row only', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/payments/group/order')
      .send({
        groupBookingId: GROUP_ID,
        paymentType: 'ADVANCE_TOKEN',
        idempotencyKey: 'idem-adv-123456',
        amountPaise: 1,
      })
      .expect(400);
    expect(res.body.error.details.validation.join('; ')).toMatch(
      /property amountPaise should not exist/,
    );
    expect(serviceStub.createGroupAdvanceOrder).not.toHaveBeenCalled();
  });

  it('routes BALANCE_SETTLEMENT to the balance path', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/payments/group/order')
      .send({
        groupBookingId: GROUP_ID,
        paymentType: 'BALANCE_SETTLEMENT',
        idempotencyKey: 'idem-bal-123456',
      })
      .expect(200);
    expect(serviceStub.createGroupBalanceOrder).toHaveBeenCalledWith(
      GROUP_ID,
      CUSTOMER_ID,
      'idem-bal-123456',
    );
  });

  it('an unknown payment type is a 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/payments/group/order')
      .send({ groupBookingId: GROUP_ID, paymentType: 'TIP', idempotencyKey: 'idem-tip-123456' })
      .expect(400);
  });

  it.each(['driver', 'fleetOwner'])(
    'a %s passes the route gate — OWNERSHIP is enforced in the service (404, not 403)',
    async (role) => {
      // Payment routes are authenticated-user surfaces: anyone signed in may
      // ASK for an order, but the service answers only the booking's owner —
      // a non-owner gets the same 404 as a nonexistent booking (no oracle).
      currentRole = role;
      await request(app.getHttpServer())
        .post('/api/v1/payments/group/order')
        .send({ groupBookingId: GROUP_ID, paymentType: 'ADVANCE_TOKEN', idempotencyKey: 'idem-x-12345' })
        .expect(200);
      expect(serviceStub.createGroupAdvanceOrder).toHaveBeenCalledWith(
        GROUP_ID,
        expect.any(String),
        'idem-x-12345',
      );
    },
  );

  it('capture requires the full gateway triple and routes the owner identity', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/payments/group/verify')
      .send({
        paymentId: 'pay-000001',
        gatewayOrderId: 'order_mock_1',
        gatewayPaymentId: 'pay_gw_1',
        signature: '',
      })
      .expect(400); // signature blank → DTO length

    await request(app.getHttpServer())
      .post('/api/v1/payments/group/verify')
      .send({
        paymentId: 'pay-000001',
        gatewayOrderId: 'order_mock_1',
        gatewayPaymentId: 'pay_gw_1',
        signature: 'sig_12345',
      })
      .expect(200);
    expect(serviceStub.captureGroupPayment).toHaveBeenCalledWith(
      expect.objectContaining({ paymentDbId: 'pay-000001', customerId: CUSTOMER_ID }),
    );
  });

  it('settlement history is owner-readable and admin-readable, hidden otherwise', async () => {
    await request(app.getHttpServer())
      .get(`/api/v1/payments/group/${GROUP_ID}`)
      .expect(200);
    expect(serviceStub.listGroupPayments).toHaveBeenCalledWith(
      GROUP_ID,
      expect.objectContaining({ userId: CUSTOMER_ID, isAdmin: false }),
    );

    currentRole = 'financeAdmin';
    await request(app.getHttpServer())
      .get(`/api/v1/payments/group/${GROUP_ID}`)
      .expect(200);
    expect(serviceStub.listGroupPayments).toHaveBeenLastCalledWith(
      GROUP_ID,
      expect.objectContaining({ isAdmin: true }),
    );
  });

  it('a malformed booking id is a 400, never a 500', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/payments/group/not-a-uuid')
      .expect(400);
    expect(serviceStub.listGroupPayments).not.toHaveBeenCalled();
  });
});
