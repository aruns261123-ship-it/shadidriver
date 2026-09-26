import { INestApplication, ValidationPipe } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { GroupBookingsController } from '../src/bookings/group-bookings.controller';
import { GroupBookingsService } from '../src/bookings/group-bookings.service';
import { RolesGuard } from '../src/auth/guards/roles.guard';
import { EnvelopeInterceptor } from '../src/common/interceptors/envelope.interceptor';
import { GlobalExceptionFilter } from '../src/common/filters/global-exception.filter';

/**
 * HTTP contract for the customer booking request endpoint.
 *
 * This test exists because a live run proved the DTO rejected EVERY real
 * submission: each `fleet` element was validated against the whole availability
 * DTO (which itself contains a `fleet` array), so a perfectly valid request
 * came back with "vehicleTypeId should not exist". The shape accepted here is
 * the one the app actually sends.
 */
const CUSTOMER_ID = '5e2c6af1-1111-4111-8111-111111111111';

const VALID_BODY = {
  serviceCategoryId: 'SVC_BARAAT',
  ceremonyType: 'Baraat',
  city: 'Delhi NCR',
  pickupAddress: 'Sector 15, Gurugram',
  destinationAddress: 'The Leela Palace, New Delhi',
  serviceStartTime: '2026-12-05T04:00:00Z',
  serviceEndTime: '2026-12-05T16:00:00Z',
  primaryContactName: 'Aarav Sharma',
  primaryContactPhone: '+919810000001',
  passengerCount: 7,
  fleet: [
    { vehicleTypeId: 'VT_THAR', quantity: 2 },
    { vehicleTypeId: 'VT_INNOVA_CRYSTA', quantity: 3 },
  ],
  idempotencyKey: 'idem-key-1234567890',
  requirements: ['Wedding decoration', 'Child seat'],
  communicationPreference: 'WHATSAPP',
};

describe('group booking request HTTP contract', () => {
  let app: INestApplication;
  let currentRole = 'customer';
  const serviceStub = {
    checkAvailability: jest.fn(),
    submitGroupBooking: jest.fn(),
    getGroupBooking: jest.fn(),
    listMyGroupBookings: jest.fn(),
    customerTransition: jest.fn(),
    confirmVehicleAllocation: jest.fn(),
    assignChauffeur: jest.fn(),
    listDriverAssignments: jest.fn(),
    acknowledgeAssignment: jest.fn(),
    declineAssignment: jest.fn(),
  };

  beforeAll(async () => {
    serviceStub.submitGroupBooking.mockImplementation(async (input: any) => ({
      groupBooking: { id: 'grp-1', status: 'REQUESTED', fleet: input.fleet },
      idempotentReplay: false,
    }));
    serviceStub.customerTransition.mockResolvedValue({ id: 'grp-1', status: 'CONFIRMED' });
    serviceStub.getGroupBooking.mockResolvedValue({ id: 'grp-1' });
    serviceStub.listMyGroupBookings.mockResolvedValue({ items: [], total: 0 });

    const moduleRef = await Test.createTestingModule({
      controllers: [GroupBookingsController],
      providers: [
        { provide: GroupBookingsService, useValue: serviceStub },
        {
          provide: APP_GUARD,
          useValue: {
            canActivate: (context: any) => {
              context.switchToHttp().getRequest().authenticatedUser = {
                userId: CUSTOMER_ID,
                role: currentRole,
                phoneNumber: '+919810000001',
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
    serviceStub.submitGroupBooking.mockImplementation(async (input: any) => ({
      groupBooking: { id: 'grp-1', status: 'REQUESTED', fleet: input.fleet },
      idempotentReplay: false,
    }));
  });

  it('accepts the multi-vehicle request the app actually sends', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/group-bookings')
      .send(VALID_BODY)
      .expect(201);

    expect(res.body.success).toBe(true);
    expect(serviceStub.submitGroupBooking).toHaveBeenCalledWith(
      expect.objectContaining({
        customerId: CUSTOMER_ID,
        fleet: [
          { vehicleTypeId: 'VT_THAR', quantity: 2 },
          { vehicleTypeId: 'VT_INNOVA_CRYSTA', quantity: 3 },
        ],
        requirements: ['Wedding decoration', 'Child seat'],
        communicationPreference: 'WHATSAPP',
      }),
    );
  });

  it('keeps the customer requirements optional and uncluttered', async () => {
    const minimal: Record<string, unknown> = { ...VALID_BODY };
    delete minimal.requirements;
    delete minimal.communicationPreference;

    await request(app.getHttpServer())
      .post('/api/v1/group-bookings')
      .send(minimal)
      .expect(201);
  });

  it('rejects a fleet line with no quantity', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/group-bookings')
      .send({ ...VALID_BODY, fleet: [{ vehicleTypeId: 'VT_THAR' }] })
      .expect(400);
    expect(res.body.error.code).toBe('VALIDATION_FAILED');
    expect(res.body.error.details.validation.join('; ')).toMatch(/quantity/);
    expect(serviceStub.submitGroupBooking).not.toHaveBeenCalled();
  });

  it('rejects unknown fields inside a fleet line', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/group-bookings')
      .send({
        ...VALID_BODY,
        fleet: [{ vehicleTypeId: 'VT_THAR', quantity: 2, pricePaise: 1 }],
      })
      .expect(400);
    expect(res.body.error.details.validation.join('; ')).toMatch(
      /property pricePaise should not exist/,
    );
  });

  it('rejects a quantity outside the sane range', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/group-bookings')
      .send({ ...VALID_BODY, fleet: [{ vehicleTypeId: 'VT_THAR', quantity: 0 }] })
      .expect(400);
    await request(app.getHttpServer())
      .post('/api/v1/group-bookings')
      .send({ ...VALID_BODY, fleet: [{ vehicleTypeId: 'VT_THAR', quantity: 51 }] })
      .expect(400);
  });

  it('rejects an empty fleet or an unreasonable number of lines', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/group-bookings')
      .send({ ...VALID_BODY, fleet: [] })
      .expect(400);
    await request(app.getHttpServer())
      .post('/api/v1/group-bookings')
      .send({
        ...VALID_BODY,
        fleet: Array.from({ length: 21 }, () => ({ vehicleTypeId: 'VT_THAR', quantity: 1 })),
      })
      .expect(400);
  });

  it('rejects an unsupported communication preference', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/group-bookings')
      .send({ ...VALID_BODY, communicationPreference: 'CARRIER_PIGEON' })
      .expect(400);
  });

  it('a customer may only take the three lifecycle actions open to them', async () => {
    for (const action of ['CONFIRM_BOOKING', 'REVISE_OPTIONS', 'CANCEL']) {
      await request(app.getHttpServer())
        .post('/api/v1/group-bookings/grp-1/transition')
        .send({ action })
        .expect(201);
    }
    await request(app.getHttpServer())
      .post('/api/v1/group-bookings/grp-1/transition')
      .send({ action: 'BEGIN_REVIEW' })
      .expect(400);
    expect(serviceStub.customerTransition).toHaveBeenCalledTimes(3);
  });

  it('passes the authenticated identity through, never a body-supplied one', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/group-bookings/grp-1/transition')
      .send({ action: 'CANCEL', reason: 'Plans changed.' })
      .expect(201);
    expect(serviceStub.customerTransition).toHaveBeenCalledWith(
      'grp-1',
      'CANCEL',
      expect.objectContaining({ userId: CUSTOMER_ID }),
      'Plans changed.',
    );
  });

  it('lists only the caller’s own group bookings', async () => {
    await request(app.getHttpServer()).get('/api/v1/group-bookings/my').expect(200);
    expect(serviceStub.listMyGroupBookings).toHaveBeenCalledWith(CUSTOMER_ID, 1, 20);
  });
});
