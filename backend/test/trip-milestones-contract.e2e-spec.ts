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
 * HTTP contract for the chauffeur execution surface and the customer's
 * trip-OTP resend. Guards that must hold at the boundary:
 *   * milestones are DRIVER-only — an operations admin cannot masquerade as a
 *     chauffeur, and a customer cannot drive the duty ladder;
 *   * a milestone body cannot smuggle an assignment status — the ladder is
 *     server-owned via the `milestone` enum;
 *   * the trip OTP is validated server-side; the response never echoes it.
 */
const DRIVER_ID = '9e2c6af1-1111-4111-8111-111111111111';
const CUSTOMER_ID = '5e2c6af1-1111-4111-8111-111111111111';
const ASSIGNMENT_ID = '22222222-3333-4444-8555-666666666666';
const GROUP_ID = '11111111-2222-4333-8444-555555555555';

describe('chauffeur duty milestones HTTP contract', () => {
  let app: INestApplication;
  let currentRole = 'driver';
  const serviceStub = {
    recordMilestone: jest.fn(),
    resendTripOtp: jest.fn(),
    listDriverAssignments: jest.fn(),
    acknowledgeAssignment: jest.fn(),
    declineAssignment: jest.fn(),
    getGroupBooking: jest.fn(),
    listMyGroupBookings: jest.fn(),
    customerTransition: jest.fn(),
    submitGroupBooking: jest.fn(),
    checkAvailability: jest.fn(),
    confirmVehicleAllocation: jest.fn(),
    assignChauffeur: jest.fn(),
  };

  beforeAll(async () => {
    serviceStub.recordMilestone.mockImplementation(
      async (assignmentId: string, milestone: string, userId: string) => ({
        assignment_id: assignmentId,
        assignment_status: milestone === 'START_SERVICE' ? 'IN_PROGRESS' : milestone,
        executed_by: userId,
      }),
    );
    serviceStub.resendTripOtp.mockResolvedValue({ resent: true });
    serviceStub.listDriverAssignments.mockResolvedValue([]);

    const moduleRef = await Test.createTestingModule({
      controllers: [GroupBookingsController],
      providers: [
        { provide: GroupBookingsService, useValue: serviceStub },
        {
          provide: APP_GUARD,
          useValue: {
            canActivate: (context: any) => {
              context.switchToHttp().getRequest().authenticatedUser = {
                userId: currentRole === 'driver' ? DRIVER_ID : CUSTOMER_ID,
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
    currentRole = 'driver';
    jest.clearAllMocks();
  });

  it('a driver records EN_ROUTE and the service receives the driver identity', async () => {
    const res = await request(app.getHttpServer())
      .post(`/api/v1/group-bookings/assignments/${ASSIGNMENT_ID}/milestones`)
      .send({ milestone: 'EN_ROUTE' })
      .expect(201);

    expect(res.body.data.assignment_status).toBe('EN_ROUTE');
    expect(serviceStub.recordMilestone).toHaveBeenCalledWith(
      ASSIGNMENT_ID,
      'EN_ROUTE',
      DRIVER_ID,
      undefined,
    );
  });

  it('START_SERVICE passes the OTP to the service, and the response never echoes it', async () => {
    const res = await request(app.getHttpServer())
      .post(`/api/v1/group-bookings/assignments/${ASSIGNMENT_ID}/milestones`)
      .send({ milestone: 'START_SERVICE', otp: '4829' })
      .expect(201);

    expect(serviceStub.recordMilestone).toHaveBeenCalledWith(
      ASSIGNMENT_ID,
      'START_SERVICE',
      DRIVER_ID,
      '4829',
    );
    expect(JSON.stringify(res.body)).not.toContain('4829');
  });

  it.each(['customer', 'operationsAdmin', 'fleetOwner'])(
    'a %s cannot record chauffeur milestones',
    async (role) => {
      currentRole = role;
      const res = await request(app.getHttpServer())
        .post(`/api/v1/group-bookings/assignments/${ASSIGNMENT_ID}/milestones`)
        .send({ milestone: 'ARRIVED' })
        .expect(403);
      expect(res.body.error.code).toBe('ROLE_FORBIDDEN');
      expect(serviceStub.recordMilestone).not.toHaveBeenCalled();
    },
  );

  it('a milestone outside the ladder is a 400, never a state write', async () => {
    const res = await request(app.getHttpServer())
      .post(`/api/v1/group-bookings/assignments/${ASSIGNMENT_ID}/milestones`)
      .send({ milestone: 'TELEPORTED' })
      .expect(400);
    expect(res.body.error.details.validation.join('; ')).toMatch(
      /milestone must be one of the following values/,
    );
  });

  it('a body cannot smuggle an assignment status', async () => {
    const res = await request(app.getHttpServer())
      .post(`/api/v1/group-bookings/assignments/${ASSIGNMENT_ID}/milestones`)
      .send({ milestone: 'EN_ROUTE', assignmentStatus: 'COMPLETED' })
      .expect(400);
    expect(res.body.error.details.validation.join('; ')).toMatch(
      /property assignmentStatus should not exist/,
    );
  });

  it('a malformed assignment id is a 400, never a 500', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/group-bookings/assignments/not-a-uuid/milestones')
      .send({ milestone: 'EN_ROUTE' })
      .expect(400);
    expect(serviceStub.recordMilestone).not.toHaveBeenCalled();
  });

  it('only the booking customer may resend the trip OTP', async () => {
    currentRole = 'driver';
    await request(app.getHttpServer())
      .post(`/api/v1/group-bookings/${GROUP_ID}/trip-otp/resend`)
      .expect(403);
    expect(serviceStub.resendTripOtp).not.toHaveBeenCalled();

    currentRole = 'customer';
    await request(app.getHttpServer())
      .post(`/api/v1/group-bookings/${GROUP_ID}/trip-otp/resend`)
      .expect(201);
    expect(serviceStub.resendTripOtp).toHaveBeenCalledWith(
      GROUP_ID,
      expect.objectContaining({ userId: CUSTOMER_ID, role: 'customer' }),
    );
  });
});
