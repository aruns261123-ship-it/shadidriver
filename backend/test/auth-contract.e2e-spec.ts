import { INestApplication, ValidationPipe } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AuthController } from '../src/auth/auth.controller';
import { AuthService } from '../src/auth/auth.service';
import { JwtAuthGuard } from '../src/auth/guards/jwt-auth.guard';
import { EnvelopeInterceptor } from '../src/common/interceptors/envelope.interceptor';
import { GlobalExceptionFilter } from '../src/common/filters/global-exception.filter';

/**
 * Live HTTP contract test for registration.
 *
 * Boots a real Nest application with the EXACT global configuration from
 * `main.ts` (ValidationPipe whitelist+forbidNonWhitelisted, GlobalExceptionFilter,
 * EnvelopeInterceptor, `api/v1` prefix). Only AuthService is stubbed so the test
 * runs without Postgres/SMS while still exercising the real HTTP boundary.
 */
describe('POST /api/v1/auth/signup (e2e contract)', () => {
  let app: INestApplication;

  const authServiceStub = {
    signUp: jest.fn().mockResolvedValue({ sessionId: 'sess-abc', expiresInSeconds: 300, debugCode: undefined }),
    requestOtp: jest.fn().mockResolvedValue({
      sessionId: 'sess-abc',
      expiresInSeconds: 300,
      resendAvailableInSeconds: 30,
    }),
    verifyOtp: jest.fn(),
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [
        { provide: AuthService, useValue: authServiceStub },
        { provide: APP_INTERCEPTOR, useClass: EnvelopeInterceptor },
      ],
    })
      // Registration routes are public; the bearer guard is irrelevant here.
      .overrideGuard(JwtAuthGuard)
      .useValue({ canActivate: () => true })
      .compile();

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
    await app.init();
  });

  afterAll(async () => {
    if (app) await app.close();
  });

  it('accepts the camelCase payload and returns only safe session data', async () => {
    authServiceStub.signUp.mockClear();
    const res = await request(app.getHttpServer())
      .post('/api/v1/auth/signup')
      .send({ phoneNumber: '+919876543210', displayName: 'Aarav Sharma', role: 'customer' })
      .expect(200);

    expect(res.body.success).toBe(true);
    expect(res.body.data).toEqual({
      session_id: 'sess-abc',
      expires_in_seconds: 300,
      next_step: 'VERIFY_OTP',
    });
    expect(JSON.stringify(res.body)).not.toContain('debug_code');
    expect(authServiceStub.signUp).toHaveBeenCalledWith(
      '+919876543210',
      'Aarav Sharma',
      'customer',
    );
  });

  it('reproduces the REAL snake_case rejection errors', async () => {
    authServiceStub.signUp.mockClear();
    const res = await request(app.getHttpServer())
      .post('/api/v1/auth/signup')
      .send({ phone_number: '+919876543210', display_name: 'Aarav Sharma' })
      .expect(400);

    expect(res.body.success).toBe(false);
    const validation: string[] = res.body.error.details.validation;
    const joined = validation.join('; ');
    expect(joined).toMatch(/property phone_number should not exist/);
    expect(joined).toMatch(/property display_name should not exist/);
    expect(joined).toMatch(/phoneNumber must be a string/);
    expect(joined).toMatch(/phoneNumber must be an E\.164 string/);
    expect(joined).toMatch(/displayName must be a string/);
    // Validation short-circuits before the service is ever reached.
    expect(authServiceStub.signUp).not.toHaveBeenCalled();
  });

  it('rejects an invalid phone number', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/auth/signup')
      .send({ phoneNumber: '+91 98765 43210', displayName: 'Aarav Sharma', role: 'customer' })
      .expect(400);

    expect(res.body.error.details.validation.join('; ')).toMatch(
      /phoneNumber must be an E\.164 string/,
    );
  });

  it('rejects a display name shorter than 2 characters', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/auth/signup')
      .send({ phoneNumber: '+919876543210', displayName: 'A', role: 'customer' })
      .expect(400);

    expect(res.body.error.details.validation.join('; ')).toMatch(
      /displayName must be longer than or equal to 2/,
    );
  });

  it('rejects unknown properties', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/auth/signup')
      .send({
        phoneNumber: '+919876543210',
        displayName: 'Aarav Sharma',
        role: 'customer',
        isAdmin: true,
      })
      .expect(400);

    expect(res.body.error.details.validation.join('; ')).toMatch(
      /property isAdmin should not exist/,
    );
  });
});
