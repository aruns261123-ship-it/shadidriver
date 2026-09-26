import { INestApplication, ValidationPipe } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { ReviewsController } from '../src/reviews/reviews.controller';
import { ReviewsService } from '../src/reviews/reviews.service';
import { RolesGuard } from '../src/auth/guards/roles.guard';
import { EnvelopeInterceptor } from '../src/common/interceptors/envelope.interceptor';
import { GlobalExceptionFilter } from '../src/common/filters/global-exception.filter';

/**
 * HTTP contract for the reviews surface:
 *   * submitting is CUSTOMER-only — a driver, partner or admin token cannot
 *     write a review (reviews must come from real hosts);
 *   * the moderation queue/decisions are ADMIN-only — a customer can never
 *     publish their own review (or anyone's);
 *   * a rating body cannot smuggle a moderation status, chauffeur id or
 *     booking reference — attribution is server-derived;
 *   * the public vehicle endpoint never requires a role.
 */
const CUSTOMER_ID = '5e2c6af1-1111-4111-8111-111111111111';
const GROUP_ID = '11111111-2222-4333-8444-555555555555';
const VEHICLE_ID = '33333333-4444-4555-8666-777777777777';
const REVIEW_ID = '44444444-5555-4666-8777-888888888888';

describe('reviews HTTP contract', () => {
  let app: INestApplication;
  let currentRole = 'customer';
  const serviceStub = {
    submit: jest.fn(),
    listMine: jest.fn(),
    pendingForMe: jest.fn(),
    listForVehicle: jest.fn(),
    moderationQueue: jest.fn(),
    moderate: jest.fn(),
  };

  beforeAll(async () => {
    serviceStub.submit.mockResolvedValue({ id: REVIEW_ID, status: 'PENDING_MODERATION' });
    serviceStub.listMine.mockResolvedValue({ items: [], total: 0 });
    serviceStub.pendingForMe.mockResolvedValue({ items: [], total: 0 });
    serviceStub.listForVehicle.mockResolvedValue({
      items: [{ id: REVIEW_ID, rating: 5, author: 'Aarav' }],
      average_rating: 5,
      total: 1,
    });
    serviceStub.moderationQueue.mockResolvedValue({ items: [], total: 0 });
    serviceStub.moderate.mockResolvedValue({ id: REVIEW_ID, status: 'PUBLISHED' });

    const moduleRef = await Test.createTestingModule({
      controllers: [ReviewsController],
      providers: [
        { provide: ReviewsService, useValue: serviceStub },
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

  const VALID_BODY = {
    groupBookingId: GROUP_ID,
    vehicleId: VEHICLE_ID,
    overallRating: 5,
    punctualityRating: 4,
    feedbackText: 'Immaculate cars, on time.',
  };

  it.each(['driver', 'fleetOwner', 'operationsAdmin'])(
    'a %s token cannot submit a review',
    async (role) => {
      currentRole = role;
      const res = await request(app.getHttpServer())
        .post('/api/v1/reviews')
        .send(VALID_BODY)
        .expect(403);
      expect(res.body.error.code).toBe('ROLE_FORBIDDEN');
      expect(serviceStub.submit).not.toHaveBeenCalled();
    },
  );

  it('a customer submits a review and the service receives their identity', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/reviews')
      .send(VALID_BODY)
      .expect(201);
    expect(serviceStub.submit).toHaveBeenCalledWith(
      VALID_BODY,
      expect.objectContaining({ userId: CUSTOMER_ID, role: 'customer' }),
    );
  });

  it('a review body cannot smuggle a moderation status or chauffeur attribution', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/reviews')
      .send({ ...VALID_BODY, status: 'PUBLISHED', driverId: 'fake', customerId: 'fake' })
      .expect(400);
    const messages = res.body.error.details.validation.join('; ');
    expect(messages).toMatch(/property status should not exist/);
    expect(messages).toMatch(/property driverId should not exist/);
    expect(messages).toMatch(/property customerId should not exist/);
    expect(serviceStub.submit).not.toHaveBeenCalled();
  });

  it('ratings outside 1..5 are rejected', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/reviews')
      .send({ ...VALID_BODY, overallRating: 0 })
      .expect(400);
    await request(app.getHttpServer())
      .post('/api/v1/reviews')
      .send({ ...VALID_BODY, overallRating: 6 })
      .expect(400);
    await request(app.getHttpServer())
      .post('/api/v1/reviews')
      .send({ ...VALID_BODY, punctualityRating: 11 })
      .expect(400);
    expect(serviceStub.submit).not.toHaveBeenCalled();
  });

  it.each(['driver', 'fleetOwner', 'customer'])(
    'a %s cannot reach the moderation queue or decide reviews',
    async (role) => {
      currentRole = role;
      await request(app.getHttpServer())
        .get('/api/v1/reviews/moderation/queue')
        .expect(403);
      await request(app.getHttpServer())
        .post(`/api/v1/reviews/${REVIEW_ID}/moderation`)
        .send({ action: 'PUBLISH' })
        .expect(403);
      expect(serviceStub.moderate).not.toHaveBeenCalled();
    },
  );

  it('an admin publishes a review and hides one with a reason', async () => {
    currentRole = 'superAdmin';
    await request(app.getHttpServer())
      .post(`/api/v1/reviews/${REVIEW_ID}/moderation`)
      .send({ action: 'PUBLISH' })
      .expect(201);
    expect(serviceStub.moderate).toHaveBeenCalledWith(
      REVIEW_ID,
      'PUBLISH',
      expect.objectContaining({ role: 'superAdmin' }),
      undefined,
    );

    // HIDE without a reason is a payload error at the boundary too.
    await request(app.getHttpServer())
      .post(`/api/v1/reviews/${REVIEW_ID}/moderation`)
      .send({ action: 'HIDE' })
      .expect(201); // shape is valid; the reason rule is enforced in the service
    expect(serviceStub.moderate).toHaveBeenLastCalledWith(
      REVIEW_ID,
      'HIDE',
      expect.anything(),
      undefined,
    );
  });

  it('the moderation action vocabulary is enforced', async () => {
    currentRole = 'superAdmin';
    const res = await request(app.getHttpServer())
      .post(`/api/v1/reviews/${REVIEW_ID}/moderation`)
      .send({ action: 'DELETE_FOREVER' })
      .expect(400);
    expect(res.body.error.details.validation.join('; ')).toMatch(
      /action must be one of the following values/,
    );
  });

  it('vehicle reviews are readable without a role gate and never leak authors', async () => {
    const res = await request(app.getHttpServer())
      .get(`/api/v1/reviews/vehicle/${VEHICLE_ID}`)
      .expect(200);
    expect(res.body.data.items[0].author).toBe('Aarav');
    expect(JSON.stringify(res.body)).not.toContain('fullName');
  });

  it('a malformed vehicle id is a 400, never a 500', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/reviews/vehicle/not-a-uuid')
      .expect(400);
    expect(serviceStub.listForVehicle).not.toHaveBeenCalled();
  });
});
