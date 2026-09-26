import { INestApplication, ValidationPipe } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { OperationsController } from '../src/operations/operations.controller';
import { OperationsService } from '../src/operations/operations.service';
import { RolesGuard } from '../src/auth/guards/roles.guard';
import { EnvelopeInterceptor } from '../src/common/interceptors/envelope.interceptor';
import { GlobalExceptionFilter } from '../src/common/filters/global-exception.filter';

/**
 * Live HTTP contract for the operations desk.
 *
 * What must hold at the boundary:
 *   * the queue/workspace is admin-only — a customer or a partner gets 403
 *     before any service code runs, so booking data cannot be scraped;
 *   * MUTATIONS are narrower than reads: a verification or finance admin may
 *     LOOK at a booking but cannot drive its lifecycle;
 *   * no request body can smuggle a status or an id: `action` is an enum, ids
 *     are UUIDs (400, never a 500 from the database).
 */
const ADMIN_USER_ID = '8e2c6af1-1111-4111-8111-111111111111';
const GROUP_ID = '11111111-2222-4333-8444-555555555555';
const ASSIGNMENT_ID = '22222222-3333-4444-8555-666666666666';
const VEHICLE_ID = '33333333-4444-4555-8666-777777777777';

describe('operations workspace HTTP contract', () => {
  let app: INestApplication;
  let currentRole = 'operationsAdmin';
  const serviceStub = {
    bookingRequestQueue: jest.fn(),
    bookingWorkspace: jest.fn(),
    transition: jest.fn(),
    logCustomerContact: jest.fn(),
    addNote: jest.fn(),
    availableChauffeurs: jest.fn(),
    reallocateVehicle: jest.fn(),
    unassignChauffeur: jest.fn(),
    requote: jest.fn(),
  };

  beforeAll(async () => {
    serviceStub.bookingRequestQueue.mockResolvedValue({ items: [], total: 0 });
    serviceStub.bookingWorkspace.mockResolvedValue({ id: GROUP_ID, assignments: [] });
    serviceStub.transition.mockImplementation(async (id: string, dto: any) => ({
      id,
      status: 'UNDER_REVIEW',
      action: dto.action,
    }));
    serviceStub.logCustomerContact.mockResolvedValue({ note_id: 'note-1' });
    serviceStub.addNote.mockResolvedValue({ id: 'note-1' });
    serviceStub.availableChauffeurs.mockResolvedValue({ items: [], total: 0 });
    serviceStub.reallocateVehicle.mockResolvedValue({ assignment_id: ASSIGNMENT_ID });
    serviceStub.unassignChauffeur.mockResolvedValue({ assignment_id: ASSIGNMENT_ID });
    serviceStub.requote.mockResolvedValue({ id: GROUP_ID, quote_pending: false });

    const moduleRef = await Test.createTestingModule({
      controllers: [OperationsController],
      providers: [
        { provide: OperationsService, useValue: serviceStub },
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
    currentRole = 'operationsAdmin';
    jest.clearAllMocks();
  });

  // ------------------------------------------------------------- the gate

  it.each(['customer', 'driver', 'fleetOwner'])(
    'a %s account cannot reach the operations desk at all',
    async (role) => {
      currentRole = role;
      const server = app.getHttpServer();

      const queue = await request(server).get('/api/v1/operations/booking-requests').expect(403);
      expect(queue.body.error.code).toBe('ROLE_FORBIDDEN');

      await request(server)
        .get(`/api/v1/operations/booking-requests/${GROUP_ID}`)
        .expect(403);
      await request(server)
        .post(`/api/v1/operations/booking-requests/${GROUP_ID}/transition`)
        .send({ action: 'BEGIN_REVIEW' })
        .expect(403);

      expect(serviceStub.bookingRequestQueue).not.toHaveBeenCalled();
      expect(serviceStub.transition).not.toHaveBeenCalled();
    },
  );

  it.each(['operationsAdmin', 'verificationAdmin', 'financeAdmin', 'superAdmin'])(
    'a %s may READ the queue and workspace',
    async (role) => {
      currentRole = role;
      await request(app.getHttpServer())
        .get('/api/v1/operations/booking-requests')
        .expect(200);
      await request(app.getHttpServer())
        .get(`/api/v1/operations/booking-requests/${GROUP_ID}`)
        .expect(200);
    },
  );

  it.each(['verificationAdmin', 'financeAdmin'])(
    'a %s may NOT drive the booking lifecycle',
    async (role) => {
      currentRole = role;
      const res = await request(app.getHttpServer())
        .post(`/api/v1/operations/booking-requests/${GROUP_ID}/transition`)
        .send({ action: 'CONFIRM_BOOKING' })
        .expect(403);
      expect(res.body.error.code).toBe('ROLE_FORBIDDEN');
      expect(serviceStub.transition).not.toHaveBeenCalled();
    },
  );

  it('operationsAdmin and superAdmin can drive the lifecycle', async () => {
    for (const role of ['operationsAdmin', 'superAdmin']) {
      currentRole = role;
      await request(app.getHttpServer())
        .post(`/api/v1/operations/booking-requests/${GROUP_ID}/transition`)
        .send({ action: 'BEGIN_REVIEW' })
        .expect(201);
    }
    expect(serviceStub.transition).toHaveBeenCalledTimes(2);
  });

  // --------------------------------------------------------- payload hygiene

  it('rejects an action outside the operational vocabulary', async () => {
    const res = await request(app.getHttpServer())
      .post(`/api/v1/operations/booking-requests/${GROUP_ID}/transition`)
      .send({ action: 'START_TRIP' })
      .expect(400);
    expect(res.body.error.details.validation.join('; ')).toMatch(
      /action must be one of the following values/,
    );
    expect(serviceStub.transition).not.toHaveBeenCalled();
  });

  it('rejects a body that tries to set the booking status directly', async () => {
    const res = await request(app.getHttpServer())
      .post(`/api/v1/operations/booking-requests/${GROUP_ID}/transition`)
      .send({ action: 'BEGIN_REVIEW', status: 'CONFIRMED' })
      .expect(400);
    expect(res.body.error.details.validation.join('; ')).toMatch(
      /property status should not exist/,
    );
  });

  it('rejects a malformed booking id with a 400, never a 500', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/operations/booking-requests/not-a-uuid')
      .expect(400);
    expect(serviceStub.bookingWorkspace).not.toHaveBeenCalled();
  });

  it('rejects a malformed assignment id on the allocation routes', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/operations/assignments/not-a-uuid/chauffeurs')
      .expect(400);
    await request(app.getHttpServer())
      .post('/api/v1/operations/assignments/not-a-uuid/chauffeur/unassign')
      .expect(400);
    expect(serviceStub.availableChauffeurs).not.toHaveBeenCalled();
  });

  it('passes the authenticated admin through to the transition service', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/operations/booking-requests/${GROUP_ID}/transition`)
      .send({ action: 'PREPARE_VEHICLE_OPTIONS' })
      .expect(201);
    expect(serviceStub.transition).toHaveBeenCalledWith(
      GROUP_ID,
      expect.objectContaining({ action: 'PREPARE_VEHICLE_OPTIONS' }),
      expect.objectContaining({ userId: ADMIN_USER_ID, role: 'operationsAdmin' }),
    );
  });

  // -------------------------------------------------------------- contact

  it('validates the contact channel and outcome vocabularies', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/operations/booking-requests/${GROUP_ID}/contact`)
      .send({ channel: 'CARRIER_PIGEON', outcome: 'REACHED' })
      .expect(400);
    await request(app.getHttpServer())
      .post(`/api/v1/operations/booking-requests/${GROUP_ID}/contact`)
      .send({ channel: 'PHONE', outcome: 'LIKED_IT' })
      .expect(400);
    expect(serviceStub.logCustomerContact).not.toHaveBeenCalled();
  });

  it('records a real contact attempt', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/operations/booking-requests/${GROUP_ID}/contact`)
      .send({ channel: 'WHATSAPP', outcome: 'REACHED', advanceToConfirmation: true })
      .expect(201);
    expect(serviceStub.logCustomerContact).toHaveBeenCalledWith(
      GROUP_ID,
      expect.objectContaining({ channel: 'WHATSAPP', advanceToConfirmation: true }),
      expect.objectContaining({ userId: ADMIN_USER_ID }),
    );
  });

  // ---------------------------------------------------------------- notes

  it('refuses an empty internal note', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/operations/booking-requests/${GROUP_ID}/notes`)
      .send({ body: '' })
      .expect(400);
    expect(serviceStub.addNote).not.toHaveBeenCalled();
  });

  it('stores an internal note against the booking', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/operations/booking-requests/${GROUP_ID}/notes`)
      .send({ body: 'Need white Thar for groom entry.' })
      .expect(201);
    expect(serviceStub.addNote).toHaveBeenCalledWith(
      GROUP_ID,
      'Need white Thar for groom entry.',
      expect.objectContaining({ userId: ADMIN_USER_ID }),
    );
  });

  // ----------------------------------------------------------- allocation

  it('rejects a reallocation body without a vehicle id', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/operations/assignments/${ASSIGNMENT_ID}/vehicle`)
      .send({ reason: 'Original withdrawn.' })
      .expect(400);
    expect(serviceStub.reallocateVehicle).not.toHaveBeenCalled();
  });

  it('routes a reallocation with vehicle, actor and reason', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/operations/assignments/${ASSIGNMENT_ID}/vehicle`)
      .send({ vehicleId: VEHICLE_ID, reason: 'Original withdrawn.' })
      .expect(201);
    expect(serviceStub.reallocateVehicle).toHaveBeenCalledWith(
      ASSIGNMENT_ID,
      VEHICLE_ID,
      expect.objectContaining({ userId: ADMIN_USER_ID }),
      'Original withdrawn.',
    );
  });

  it('requotes with an optional declared distance', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/operations/booking-requests/${GROUP_ID}/requote`)
      .send({ routeDistanceKm: 60 })
      .expect(201);
    expect(serviceStub.requote).toHaveBeenCalledWith(
      GROUP_ID,
      expect.objectContaining({ routeDistanceKm: 60 }),
      expect.objectContaining({ userId: ADMIN_USER_ID }),
    );
  });
});
