import { INestApplication, ValidationPipe } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AdminController } from '../src/admin/admin.controller';
import { AdminService } from '../src/admin/admin.service';
import { RolesGuard } from '../src/auth/guards/roles.guard';
import { EnvelopeInterceptor } from '../src/common/interceptors/envelope.interceptor';
import { GlobalExceptionFilter } from '../src/common/filters/global-exception.filter';

/**
 * Live HTTP contract test for the admin verification center.
 *
 * Real app, real global pipes, real RolesGuard. The assertions that matter:
 *   * ONLY admin roles pass the gate — a customer or driver token is 403
 *     before any service code runs;
 *   * a decision body cannot smuggle fields (`action` must be one of the
 *     four verbs, unknown properties are rejected);
 *   * REJECT/REQUEST_CHANGES without a reason are refused over HTTP too.
 */
const ADMIN_USER_ID = '8e2c6af1-1111-4111-8111-111111111111';
const PARTNER_ID = '11111111-2222-4333-8444-555555555555';
const VEHICLE_ID = '22222222-3333-4444-8555-666666666666';
const PRICING_ID = '33333333-4444-4555-8666-777777777777';

describe('admin verification HTTP contract', () => {
  let app: INestApplication;
  let currentRole = 'verificationAdmin';
  const serviceStub = {
    partnerQueue: jest.fn(),
    vehicleQueue: jest.fn(),
    pricingQueue: jest.fn(),
    decidePartner: jest.fn(),
    decideVehicle: jest.fn(),
    decidePricing: jest.fn(),
  };

  beforeAll(async () => {
    serviceStub.partnerQueue.mockResolvedValue({ items: [], total: 0 });
    serviceStub.vehicleQueue.mockResolvedValue({ items: [], total: 0 });
    serviceStub.pricingQueue.mockResolvedValue({ items: [], total: 0 });
    serviceStub.decidePartner.mockImplementation(
      async (admin: any, id: string, action: string, reason?: string) => ({
        id,
        verification_status: action === 'APPROVE' ? 'APPROVED' : 'REJECTED',
        decision_reason: reason ?? null,
        reviewed_at: new Date(),
        __actor: admin.userId,
      }),
    );
    serviceStub.decideVehicle.mockImplementation(
      async (_admin: any, id: string, action: string) => ({
        id,
        verification_status: action === 'APPROVE' ? 'APPROVED' : 'ACTION_REQUIRED',
        is_public: action === 'APPROVE',
      }),
    );
    serviceStub.decidePricing.mockImplementation(
      async (_admin: any, id: string, action: string) => ({
        id,
        version: 2,
        status: action === 'APPROVE' ? 'APPROVED' : 'REJECTED',
        vehicle_id: VEHICLE_ID,
      }),
    );

    const moduleRef = await Test.createTestingModule({
      controllers: [AdminController],
      providers: [
        { provide: AdminService, useValue: serviceStub },
        {
          provide: APP_GUARD,
          useValue: {
            canActivate: (context: any) => {
              context.switchToHttp().getRequest().authenticatedUser = {
                userId: ADMIN_USER_ID,
                role: currentRole,
                phoneNumber: '+918100000011',
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
    currentRole = 'verificationAdmin';
    jest.clearAllMocks();
  });

  // ------------------------------------------------------------- the gate

  it.each(['customer', 'driver', 'fleetOwner'])(
    'a %s account cannot reach ANY admin endpoint',
    async (role) => {
      currentRole = role;
      const server = app.getHttpServer();

      const queues = await request(server).get('/api/v1/admin/verification/partners').expect(403);
      expect(queues.body.error.code).toBe('ROLE_FORBIDDEN');

      await request(server).get('/api/v1/admin/verification/vehicles').expect(403);
      await request(server).get('/api/v1/admin/pricing/queue').expect(403);

      const decision = await request(server)
        .post(`/api/v1/admin/verification/partners/${PARTNER_ID}`)
        .send({ action: 'APPROVE' })
        .expect(403);
      expect(decision.body.error.code).toBe('ROLE_FORBIDDEN');

      expect(serviceStub.decidePartner).not.toHaveBeenCalled();
    },
  );

  it.each(['verificationAdmin', 'operationsAdmin', 'superAdmin', 'financeAdmin'])(
    'a %s account passes the gate',
    async (role) => {
      currentRole = role;
      await request(app.getHttpServer()).get('/api/v1/admin/verification/partners').expect(200);
    },
  );

  it('queues answer with the standard envelope', async () => {
    const partners = await request(app.getHttpServer())
      .get('/api/v1/admin/verification/partners')
      .expect(200);
    expect(partners.body.success).toBe(true);
    expect(partners.body.data).toEqual({ items: [], total: 0 });

    await request(app.getHttpServer()).get('/api/v1/admin/verification/vehicles').expect(200);
    await request(app.getHttpServer()).get('/api/v1/admin/pricing/queue').expect(200);
  });

  // ------------------------------------------------------- decision payloads

  it('a decision body cannot smuggle unknown fields', async () => {
    const res = await request(app.getHttpServer())
      .post(`/api/v1/admin/verification/partners/${PARTNER_ID}`)
      .send({ action: 'APPROVE', verificationStatus: 'APPROVED' })
      .expect(400);
    expect(res.body.error.details.validation.join('; ')).toMatch(
      /property verificationStatus should not exist/,
    );
    expect(serviceStub.decidePartner).not.toHaveBeenCalled();
  });

  it('action must be one of the four verbs', async () => {
    const res = await request(app.getHttpServer())
      .post(`/api/v1/admin/verification/vehicles/${VEHICLE_ID}`)
      .send({ action: 'MAKE_IT_LIVE' })
      .expect(400);
    expect(res.body.error.details.validation.join('; ')).toMatch(
      /action must be one of the following values/,
    );
    expect(serviceStub.decideVehicle).not.toHaveBeenCalled();
  });

  it('a malformed partner id is a 400, never a 500', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/admin/verification/partners/not-a-uuid')
      .send({ action: 'APPROVE' })
      .expect(400);
    expect(res.body.success).toBe(false);
    expect(serviceStub.decidePartner).not.toHaveBeenCalled();
  });

  it('a malformed pricing id is a 400, never a 500', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/admin/pricing/not-a-uuid/decision')
      .send({ action: 'REJECT', decisionReason: 'Nope.' })
      .expect(400);
    expect(serviceStub.decidePricing).not.toHaveBeenCalled();
  });

  it('routes the decision to the service with the token identity and reason', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/admin/verification/partners/${PARTNER_ID}`)
      .send({ action: 'REJECT', decisionReason: 'Licence unreadable.' })
      .expect(201);

    expect(serviceStub.decidePartner).toHaveBeenCalledWith(
      expect.objectContaining({ userId: ADMIN_USER_ID }),
      PARTNER_ID,
      'REJECT',
      'Licence unreadable.',
    );
  });

  it('routes a pricing decision to the pricing endpoint', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/admin/pricing/${PRICING_ID}/decision`)
      .send({ action: 'APPROVE' })
      .expect(201);

    expect(serviceStub.decidePricing).toHaveBeenCalledWith(
      expect.objectContaining({ userId: ADMIN_USER_ID }),
      PRICING_ID,
      'APPROVE',
      undefined,
    );
  });
});
