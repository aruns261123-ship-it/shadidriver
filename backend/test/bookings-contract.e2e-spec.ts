import { INestApplication, ValidationPipe } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import {
  BookingsController,
  SubmitBookingDto,
} from '../src/bookings/bookings.controller';
import { BookingsService } from '../src/bookings/bookings.service';
import { EnvelopeInterceptor } from '../src/common/interceptors/envelope.interceptor';
import { GlobalExceptionFilter } from '../src/common/filters/global-exception.filter';

/**
 * Live HTTP contract test for booking submission.
 *
 * Boots a real Nest application with the EXACT global configuration from
 * `main.ts` (ValidationPipe `whitelist + forbidNonWhitelisted`, the global
 * exception filter, the envelope interceptor, `api/v1` prefix). Only
 * `BookingsService` is stubbed, so the real HTTP boundary — routing, the DTO,
 * class-validator, the error envelope — is exercised without Postgres.
 *
 * The client's canonical payload is defined in
 * `frontend/lib/features/bookings/data/dto/submit_booking_dto.dart`; both sides
 * are asserted against the same field set here so drift fails loudly.
 */
const CANONICAL_REQUEST = {
  serviceCategoryId: 'SVC_BARAAT',
  vehicleTypeId: '661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e',
  ceremonyType: 'Baraat',
  ceremonialAttire: 'Safa & Bandhgala',
  specialInstructions: 'Royal entrance',
  serviceStartTime: '2026-11-20T10:30:00.000Z',
  serviceEndTime: '2026-11-20T18:30:00.000Z',
  city: 'Delhi NCR',
  pickupAddress: 'Sector 15, Gurugram',
  destinationAddress: 'The Leela Palace, Chanakyapuri, New Delhi',
  venueName: 'The Leela Palace',
  routeDistanceKm: 42,
  primaryContactName: 'Aarav Sharma',
  primaryContactPhone: '+919810000001',
  passengerCount: 4,
  selectedAddonIds: [],
};

const IDEMPOTENCY_KEY = 'bk-contract-e2e-0001';

/** Field set the Flutter DTO serializes. Kept in sync by test, not by hand. */
const CLIENT_CONTRACT_FIELDS = [
  'serviceCategoryId',
  'vehicleTypeId',
  'ceremonyType',
  'ceremonialAttire',
  'specialInstructions',
  'serviceStartTime',
  'serviceEndTime',
  'city',
  'pickupAddress',
  'destinationAddress',
  'venueName',
  'routeDistanceKm',
  'primaryContactName',
  'primaryContactPhone',
  'passengerCount',
  'selectedAddonIds',
];

describe('POST /api/v1/bookings (e2e contract)', () => {
  let app: INestApplication;

  const bookingsServiceStub = {
    submitBooking: jest.fn().mockResolvedValue({
      booking: {
        id: 'b-1',
        referenceCode: 'SD-2026-0101',
        status: 'REQUESTED',
        pickupAddress: CANONICAL_REQUEST.pickupAddress,
        destinationAddress: CANONICAL_REQUEST.destinationAddress,
      },
      idempotentReplay: false,
    }),
    listMyBookings: jest.fn().mockResolvedValue({ items: [], meta: {} }),
    getBookingById: jest.fn(),
    transition: jest.fn(),
    listDriverBookings: jest.fn(),
    acceptBooking: jest.fn(),
    declineBooking: jest.fn(),
    resendTripOtp: jest.fn(),
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [BookingsController],
      providers: [
        { provide: BookingsService, useValue: bookingsServiceStub },
        // In the real app JwtAuthGuard is a global APP_GUARD (AuthModule); the
        // controller reads the identity it injects via @CurrentUser(). Replace
        // it with a stub that behaves the same way without needing a token.
        {
          provide: APP_GUARD,
          useValue: {
            canActivate: (context: any) => {
              context.switchToHttp().getRequest().authenticatedUser = {
                userId: '4458faf1-6f5a-425f-86eb-ce842ec77f1e',
                role: 'customer',
                phoneNumber: '+919810000001',
                accountStatus: 'ACTIVE',
              };
              return true;
            },
          },
        },
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
    bookingsServiceStub.submitBooking.mockClear();
  });

  it('accepts the canonical client payload (pickupAddress/destinationAddress included)', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/bookings')
      .set('Idempotency-Key', IDEMPOTENCY_KEY)
      .send(CANONICAL_REQUEST)
      .expect(201);

    expect(res.body.success).toBe(true);
    expect(bookingsServiceStub.submitBooking).toHaveBeenCalledTimes(1);
    const input = bookingsServiceStub.submitBooking.mock.calls[0][0];
    expect(input.pickupAddress).toBe(CANONICAL_REQUEST.pickupAddress);
    expect(input.destinationAddress).toBe(CANONICAL_REQUEST.destinationAddress);
    expect(input.routeDistanceKm).toBe(42);
    expect(input.idempotencyKey).toBe(IDEMPOTENCY_KEY);
  });

  it('declares exactly the field set the Flutter DTO serializes', () => {
    const dto = new SubmitBookingDto();
    dto.serviceCategoryId = 'SVC_BARAAT';
    const declared = Object.keys(dto);
    expect(declared.sort()).toEqual([...CLIENT_CONTRACT_FIELDS].sort());
  });

  it('rejects addresses shorter than the documented 5-character minimum', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/bookings')
      .set('Idempotency-Key', IDEMPOTENCY_KEY)
      .send({
        ...CANONICAL_REQUEST,
        pickupAddress: 'Home',
        destinationAddress: '',
      })
      .expect(400);

    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('VALIDATION_FAILED');
    const validation: string[] = res.body.error.details.validation;
    expect(validation.join('; ')).toMatch(
      /pickupAddress must be longer than or equal to 5 characters/,
    );
    expect(validation.join('; ')).toMatch(
      /destinationAddress must be longer than or equal to 5 characters/,
    );
    // These are VALUE rejections on supported fields — not unknown properties.
    expect(validation.join('; ')).not.toMatch(/should not exist/);
    expect(bookingsServiceStub.submitBooking).not.toHaveBeenCalled();
  });

  it('rejects a field the DTO does not declare (contract drift)', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/bookings')
      .set('Idempotency-Key', IDEMPOTENCY_KEY)
      .send({ ...CANONICAL_REQUEST, pickup_address: 'legacy snake case' })
      .expect(400);

    expect(res.body.error.details.validation.join('; ')).toMatch(
      /property pickup_address should not exist/,
    );
    expect(bookingsServiceStub.submitBooking).not.toHaveBeenCalled();
  });

  it('rejects an idempotency token smuggled into the body', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/bookings')
      .set('Idempotency-Key', IDEMPOTENCY_KEY)
      .send({ ...CANONICAL_REQUEST, idempotencyKey: IDEMPOTENCY_KEY })
      .expect(400);

    expect(res.body.error.details.validation.join('; ')).toMatch(
      /property idempotencyKey should not exist/,
    );
  });

  it('requires the Idempotency-Key header', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/bookings')
      .send(CANONICAL_REQUEST)
      .expect(400);

    expect(res.body.error.code).toBe('VALIDATION_FAILED');
    expect(res.body.error.message).toMatch(/Idempotency-Key header/);
    expect(bookingsServiceStub.submitBooking).not.toHaveBeenCalled();
  });

  it('enforces the documented passenger and distance bounds', async () => {
    const tooMany = await request(app.getHttpServer())
      .post('/api/v1/bookings')
      .set('Idempotency-Key', IDEMPOTENCY_KEY)
      .send({ ...CANONICAL_REQUEST, passengerCount: 99 })
      .expect(400);
    expect(tooMany.body.error.details.validation.join('; ')).toMatch(
      /passengerCount must not be greater than 60/,
    );

    const negative = await request(app.getHttpServer())
      .post('/api/v1/bookings')
      .set('Idempotency-Key', IDEMPOTENCY_KEY)
      .send({ ...CANONICAL_REQUEST, routeDistanceKm: -5 })
      .expect(400);
    expect(negative.body.error.details.validation.join('; ')).toMatch(
      /routeDistanceKm must not be less than 0/,
    );
  });
});
