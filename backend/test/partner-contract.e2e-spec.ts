import { INestApplication, ValidationPipe } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PartnerController } from '../src/partner/partner.controller';
import { PartnerService } from '../src/partner/partner.service';
import { PricingService } from '../src/partner/pricing.service';
import { RolesGuard } from '../src/auth/guards/roles.guard';
import { EnvelopeInterceptor } from '../src/common/interceptors/envelope.interceptor';
import { GlobalExceptionFilter } from '../src/common/filters/global-exception.filter';

/**
 * Live HTTP contract test for partner onboarding and fleet management.
 *
 * Boots a real Nest app with the production global configuration, DTO
 * validation and the REAL RolesGuard, so the authorization and request-shape
 * behaviour under test is the one that ships. Only JWT decoding is replaced.
 *
 * The assertions that matter most here are the ones that stop a partner from
 * granting itself a privilege: no request body may carry a verification state,
 * an activation flag, a fleet reference or a price.
 */
const TOKEN_USER_ID = '4458faf1-6f5a-425f-86eb-ce842ec77f1e';
const VEHICLE_ID = '11111111-1111-4111-8111-111111111111';

const VEHICLE_VIEW = {
  id: VEHICLE_ID,
  fleet_code: 'SD-DEL-00042',
  vehicle_type_id: 'VT_THAR',
  display_name: 'Mahindra Thar',
  seating_capacity: 5,
  vehicle_class: 'PREMIUM_SUV',
  year: 2023,
  registration_number: 'DL01AB1234',
  color: 'Pearl White',
  fuel_type: 'DIESEL',
  transmission: 'AUTOMATIC',
  city: 'Delhi NCR',
  service_areas: ['Delhi NCR'],
  amenities: ['AC'],
  photo_urls: [],
  verification_status: 'PENDING_SUBMISSION',
  is_active: true,
  is_available: true,
  is_bookable: false,
  documents: [],
};

const VALID_VEHICLE = {
  vehicleTypeId: 'VT_THAR',
  yearOfManufacture: 2023,
  registrationNumber: 'DL01AB1234',
  color: 'Pearl White',
  fuelType: 'DIESEL',
  transmission: 'AUTOMATIC',
  city: 'Delhi NCR',
};

describe('partner HTTP contract', () => {
  let app: INestApplication;
  let currentRole = 'driver';
  const serviceStub = {
    register: jest.fn(),
    getProfile: jest.fn(),
    updateProfile: jest.fn(),
    submitForReview: jest.fn(),
    listVehicles: jest.fn(),
    addVehicle: jest.fn(),
    updateVehicle: jest.fn(),
    removeVehicle: jest.fn(),
    addVehicleDocument: jest.fn(),
    addPartnerDocument: jest.fn(),
  };

  beforeAll(async () => {
    serviceStub.register.mockImplementation(async (userId: string) => ({
      id: 'partner-1',
      company_name: 'Fleur Chauffeurs Pvt Ltd',
      verification_status: 'PENDING_SUBMISSION',
      is_verified: false,
      can_receive_bookings: false,
      __actor: userId,
    }));
    serviceStub.getProfile.mockImplementation(async (userId: string) => ({
      id: 'partner-1',
      is_verified: false,
      __actor: userId,
    }));
    serviceStub.updateProfile.mockImplementation(async (userId: string) => ({
      id: 'partner-1',
      __actor: userId,
    }));
    serviceStub.submitForReview.mockImplementation(async () => ({
      verification_status: 'SUBMITTED',
      can_receive_bookings: false,
    }));
    serviceStub.listVehicles.mockImplementation(async (userId: string) => ({
      items: [VEHICLE_VIEW],
      total: 1,
      // Echo the server-derived identity so the test can prove the route used
      // the token's user and not anything from the client.
      __actor: userId,
    }));
    serviceStub.addVehicle.mockImplementation(
      async (userId: string, dto: any) => ({
        ...VEHICLE_VIEW,
        registration_number: dto.registrationNumber,
        __actor: userId,
      }),
    );
    serviceStub.updateVehicle.mockImplementation(
      async (_userId: string, vehicleId: string) => ({
        ...VEHICLE_VIEW,
        id: vehicleId,
      }),
    );
    serviceStub.removeVehicle.mockImplementation(async () => ({
      ...VEHICLE_VIEW,
      is_active: false,
      is_available: false,
      is_bookable: false,
    }));
    serviceStub.addVehicleDocument.mockImplementation(async () => ({
      id: 'doc-1',
      vehicle_id: VEHICLE_ID,
      document_type: 'COMMERCIAL_INSURANCE',
      verification_status: 'PENDING_REVIEW',
      expires_at: null,
    }));

    const moduleRef = await Test.createTestingModule({
      controllers: [PartnerController],
      providers: [
        { provide: PartnerService, useValue: serviceStub },
        // The controller also exposes tariff endpoints; the pricing service is
        // stubbed here — its behaviour is covered by pricing.service.spec.ts.
        { provide: PricingService, useValue: { submitPricing: jest.fn(), listPricing: jest.fn() } },
        // 1) replaces JWT decoding with a fixed identity
        {
          provide: APP_GUARD,
          useValue: {
            canActivate: (context: any) => {
              context.switchToHttp().getRequest().authenticatedUser = {
                userId: TOKEN_USER_ID,
                role: currentRole,
                phoneNumber: '+919810000001',
                accountStatus: 'ACTIVE',
              };
              return true;
            },
          },
        },
        // 2) the REAL role guard runs against that identity
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

  // ------------------------------------------------------------- authorization

  it('a customer account cannot reach partner onboarding or the fleet', async () => {
    currentRole = 'customer';
    const server = app.getHttpServer();

    const profile = await request(server).get('/api/v1/partner/profile').expect(403);
    expect(profile.body.error.code).toBe('ROLE_FORBIDDEN');

    const fleet = await request(server).get('/api/v1/partner/vehicles').expect(403);
    expect(fleet.body.error.code).toBe('ROLE_FORBIDDEN');

    const add = await request(server)
      .post('/api/v1/partner/vehicles')
      .send(VALID_VEHICLE)
      .expect(403);
    expect(add.body.error.code).toBe('ROLE_FORBIDDEN');

    const register = await request(server)
      .post('/api/v1/partner/registration')
      .send({ companyName: 'X Fleet', baseCity: 'Delhi NCR' })
      .expect(403);
    expect(register.body.error.code).toBe('ROLE_FORBIDDEN');

    // The guard must reject before the service is ever consulted.
    expect(serviceStub.addVehicle).not.toHaveBeenCalled();
    expect(serviceStub.register).not.toHaveBeenCalled();
    expect(serviceStub.listVehicles).not.toHaveBeenCalled();
  });

  it('a fleetOwner account is accepted', async () => {
    currentRole = 'fleetOwner';
    await request(app.getHttpServer()).get('/api/v1/partner/vehicles').expect(200);
    expect(serviceStub.listVehicles).toHaveBeenCalledWith(TOKEN_USER_ID);
  });

  it('a driver account is accepted — a partner may be a single-car chauffeur', async () => {
    currentRole = 'driver';
    await request(app.getHttpServer()).get('/api/v1/partner/vehicles').expect(200);
  });

  // ------------------------------------------------------------- identity

  it('scopes the fleet to the token identity, never a client-supplied id', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/partner/vehicles')
      .expect(200);
    expect(res.body.data.__actor).toBe(TOKEN_USER_ID);
  });

  // ------------------------------------------- privilege-escalation attempts

  describe('privilege escalation through the request body', () => {
    const injections: [string, Record<string, unknown>][] = [
      ['verificationStatus', { verificationStatus: 'APPROVED' }],
      ['isAvailable', { isAvailable: true }],
      ['isActive', { isActive: true }],
      ['isBookable', { isBookable: true }],
      ['fleetOwnerId', { fleetOwnerId: 'partner-someone-else' }],
      ['fleetCode', { fleetCode: 'SD-DEL-00001' }],
      ['basePricePaise', { basePricePaise: 1 }],
      ['price', { price: 3000 }],
      ['chauffeurId', { chauffeurId: 'someone' }],
    ];

    it.each(injections)(
      'rejects an add-vehicle body carrying %s',
      async (field, payload) => {
        const res = await request(app.getHttpServer())
          .post('/api/v1/partner/vehicles')
          .send({ ...VALID_VEHICLE, ...payload })
          .expect(400);

        expect(res.body.error.details.validation.join('; ')).toMatch(
          new RegExp(`property ${field} should not exist`),
        );
        expect(serviceStub.addVehicle).not.toHaveBeenCalled();
      },
    );

    it('rejects an add-vehicle body carrying an unknown field', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/partner/vehicles')
        .send({ ...VALID_VEHICLE, somethingElse: true })
        .expect(400);
      expect(res.body.error.details.validation.join('; ')).toMatch(
        /property somethingElse should not exist/,
      );
    });

    it('rejects a registration body trying to set its own verification', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/partner/registration')
        .send({
          companyName: 'Fleur Chauffeurs Pvt Ltd',
          baseCity: 'Delhi NCR',
          verificationStatus: 'APPROVED',
        })
        .expect(400);
      expect(res.body.error.details.validation.join('; ')).toMatch(
        /property verificationStatus should not exist/,
      );
      expect(serviceStub.register).not.toHaveBeenCalled();
    });

    it('a partner cannot set its own price through the profile endpoint', async () => {
      const res = await request(app.getHttpServer())
        .patch('/api/v1/partner/profile')
        .send({ companyName: 'Fleur Chauffeurs Pvt Ltd', price: 3000 })
        .expect(400);
      expect(res.body.error.details.validation.join('; ')).toMatch(
        /property price should not exist/,
      );
      expect(serviceStub.updateProfile).not.toHaveBeenCalled();
    });
  });

  // ------------------------------------------------------------- validation

  describe('vehicle validation', () => {
    it('rejects a plate that is not an Indian registration number', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/partner/vehicles')
        .send({ ...VALID_VEHICLE, registrationNumber: 'not-a-plate' })
        .expect(400);
      expect(res.body.error.details.validation.join('; ')).toMatch(
        /must look like an Indian plate/,
      );
    });

    it('rejects an unknown fuel type, transmission or vehicle type id', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/partner/vehicles')
        .send({ ...VALID_VEHICLE, fuelType: 'STEAM' })
        .expect(400);
      await request(app.getHttpServer())
        .post('/api/v1/partner/vehicles')
        .send({ ...VALID_VEHICLE, transmission: 'CVT' })
        .expect(400);
      await request(app.getHttpServer())
        .post('/api/v1/partner/vehicles')
        .send({ ...VALID_VEHICLE, vehicleTypeId: '' })
        .expect(400);
      expect(serviceStub.addVehicle).not.toHaveBeenCalled();
    });

    it('rejects an implausible year of manufacture', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/partner/vehicles')
        .send({ ...VALID_VEHICLE, yearOfManufacture: 1500 })
        .expect(400);
      expect(serviceStub.addVehicle).not.toHaveBeenCalled();
    });

    it('accepts a well-formed vehicle and returns an unbookable one', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/partner/vehicles')
        .send(VALID_VEHICLE)
        .expect(201);

      expect(res.body.data.is_bookable).toBe(false);
      expect(res.body.data.verification_status).toBe('PENDING_SUBMISSION');
      expect(serviceStub.addVehicle).toHaveBeenCalledWith(TOKEN_USER_ID, {
        vehicleTypeId: 'VT_THAR',
        yearOfManufacture: 2023,
        registrationNumber: 'DL01AB1234',
        color: 'Pearl White',
        fuelType: 'DIESEL',
        transmission: 'AUTOMATIC',
        city: 'Delhi NCR',
      });
    });

    it('rejects a malformed vehicle id before it can reach the database', async () => {
      const res = await request(app.getHttpServer())
        .patch('/api/v1/partner/vehicles/not-a-uuid')
        .send({ color: 'Black' })
        .expect(400);

      expect(res.status).not.toBe(500);
      expect(serviceStub.updateVehicle).not.toHaveBeenCalled();
      expect(res.body.success).toBe(false);
    });

    it('accepts an uppercase vehicle id, since UUIDs are case-insensitive', async () => {
      const res = await request(app.getHttpServer())
        .delete(`/api/v1/partner/vehicles/${VEHICLE_ID.toUpperCase()}`)
        .expect(200);
      expect(res.body.data.is_bookable).toBe(false);
      expect(res.body.data.is_active).toBe(false);
    });
  });

  // ------------------------------------------------------------- documents

  describe('document validation', () => {
    it('rejects an unknown document type', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/v1/partner/vehicles/${VEHICLE_ID}/documents`)
        .send({
          documentType: 'SELFIE',
          storagePath: 'x/y.pdf',
          mimeType: 'application/pdf',
        })
        .expect(400);
      expect(res.body.error.details.validation.length).toBeGreaterThan(0);
      expect(serviceStub.addVehicleDocument).not.toHaveBeenCalled();
    });

    it('rejects a document with an unparseable expiry date', async () => {
      await request(app.getHttpServer())
        .post(`/api/v1/partner/vehicles/${VEHICLE_ID}/documents`)
        .send({
          documentType: 'COMMERCIAL_INSURANCE',
          storagePath: 'x/y.pdf',
          mimeType: 'application/pdf',
          expiryDate: 'next Tuesday',
        })
        .expect(400);
      expect(serviceStub.addVehicleDocument).not.toHaveBeenCalled();
    });

    it('accepts valid vehicle paperwork and returns it unreviewed', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/v1/partner/vehicles/${VEHICLE_ID}/documents`)
        .send({
          documentType: 'COMMERCIAL_INSURANCE',
          storagePath: 'partners/veh-1/insurance.pdf',
          mimeType: 'application/pdf',
          expiryDate: '2027-01-01',
        })
        .expect(201);

      expect(res.body.data.verification_status).toBe('PENDING_REVIEW');
    });

    it('rejects a malformed PAN or GSTIN on partner documents', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/partner/registration')
        .send({
          companyName: 'Fleur Chauffeurs Pvt Ltd',
          baseCity: 'Delhi NCR',
          panNumber: 'NOPE123',
        })
        .expect(400);
      await request(app.getHttpServer())
        .post('/api/v1/partner/registration')
        .send({
          companyName: 'Fleur Chauffeurs Pvt Ltd',
          baseCity: 'Delhi NCR',
          gstin: '12345',
        })
        .expect(400);
      expect(serviceStub.register).not.toHaveBeenCalled();
    });

    it('rejects a non-E.164 emergency contact number', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/partner/registration')
        .send({
          companyName: 'Fleur Chauffeurs Pvt Ltd',
          baseCity: 'Delhi NCR',
          emergencyContactPhone: '9876543210',
        })
        .expect(400);
      expect(res.body.error.details.validation.join('; ')).toMatch(
        /emergencyContactPhone must be an E.164 string/,
      );
    });
  });
});
