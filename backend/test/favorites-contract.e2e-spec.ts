import { INestApplication, ValidationPipe } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { FavoritesController } from '../src/favorites/favorites.controller';
import { FavoritesService } from '../src/favorites/favorites.service';
import { RolesGuard } from '../src/auth/guards/roles.guard';
import { EnvelopeInterceptor } from '../src/common/interceptors/envelope.interceptor';
import { GlobalExceptionFilter } from '../src/common/filters/global-exception.filter';

/**
 * Live HTTP contract test for persistent favourites.
 *
 * Boots a real Nest app with the production global configuration and the REAL
 * RolesGuard, so the authorization behaviour under test is the one that ships.
 * Only the JWT decoding is replaced (a stub guard injects the identity the real
 * JwtAuthGuard would have put on the request) and the data layer is stubbed.
 */
const TOKEN_USER_ID = '4458faf1-6f5a-425f-86eb-ce842ec77f1e';
const V1 = '11111111-1111-4111-8111-111111111111';

const PUBLIC_ITEM = {
  id: V1,
  vehicle_type_id: 'VT_THAR',
  fleet_code: 'SD-VH-0001',
  make: 'Mahindra',
  model: 'Thar',
  display_name: 'Mahindra Thar',
  year: 2023,
  vehicle_class: 'PREMIUM_SUV',
  seating_capacity: 5,
  city: 'Delhi NCR',
  image_url: null,
  amenities: ['AC'],
  verification_status: 'APPROVED',
  is_available: true,
  has_verified_chauffeur: true,
  rating: null,
  review_count: 0,
  price_indicator_paise: '300000',
};

const PUBLIC_ITEM_KEYS = Object.keys(PUBLIC_ITEM).sort();

describe('favourites HTTP contract', () => {
  let app: INestApplication;
  let currentRole = 'customer';
  const serviceStub = {
    list: jest.fn(),
    add: jest.fn(),
    remove: jest.fn(),
    merge: jest.fn(),
  };

  beforeAll(async () => {
    serviceStub.list.mockImplementation(async (userId: string) => ({
      items: [PUBLIC_ITEM],
      // Echo the server-derived identity so the test can prove the route used
      // the token's user, not anything from the client.
      vehicle_ids: [V1],
      total: 1,
      unavailable_count: 0,
      __actor: userId,
    }));
    serviceStub.add.mockImplementation(async (userId: string) => ({
      items: [PUBLIC_ITEM],
      vehicle_ids: [V1],
      total: 1,
      unavailable_count: 0,
      __actor: userId,
    }));
    serviceStub.remove.mockImplementation(async (userId: string) => ({
      items: [],
      vehicle_ids: [],
      total: 0,
      unavailable_count: 0,
      __actor: userId,
    }));
    serviceStub.merge.mockImplementation(async (userId: string) => ({
      items: [PUBLIC_ITEM],
      vehicle_ids: [V1],
      total: 1,
      unavailable_count: 0,
      ignored_vehicle_ids: ['not-a-uuid'],
      __actor: userId,
    }));

    const moduleRef = await Test.createTestingModule({
      controllers: [FavoritesController],
      providers: [
        { provide: FavoritesService, useValue: serviceStub },
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
    currentRole = 'customer';
    jest.clearAllMocks();
  });

  it('lists saved vehicles using the public projection only', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/favorites')
      .expect(200);

    expect(res.body.success).toBe(true);
    expect(Object.keys(res.body.data.items[0]).sort()).toEqual(PUBLIC_ITEM_KEYS);
    for (const forbidden of [
      'chauffeur',
      'chauffeur_id',
      'chauffeur_name',
      'driver',
      'owner',
      'registration_number',
      'documents',
    ]) {
      expect(res.body.data.items[0]).not.toHaveProperty(forbidden);
    }
  });

  it('scopes the request to the token identity, never a client-supplied id', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/favorites')
      .expect(200);
    expect(res.body.data.__actor).toBe(TOKEN_USER_ID);
  });

  it('refuses to let a client inject an identity through the merge body', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/favorites/merge')
      .send({ vehicleIds: [V1], customerId: 'someone-else' })
      .expect(400);

    expect(res.body.error.details.validation.join('; ')).toMatch(
      /property customerId should not exist/,
    );
    expect(serviceStub.merge).not.toHaveBeenCalled();
  });

  it('routes POST /favorites/merge to merge, not to a vehicle id', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/favorites/merge')
      .send({ vehicleIds: [V1] })
      .expect(200);

    expect(serviceStub.merge).toHaveBeenCalledWith(TOKEN_USER_ID, [V1]);
    expect(serviceStub.add).not.toHaveBeenCalled();
  });

  it('reports guest shortlist entries it could not import', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/favorites/merge')
      .send({ vehicleIds: [V1, 'not-a-uuid'] })
      .expect(200);

    expect(res.body.data.ignored_vehicle_ids).toEqual(['not-a-uuid']);
  });

  it('rejects a merge payload larger than the saved-vehicle cap', async () => {
    const tooMany = Array.from(
      { length: 101 },
      (_, i) => `00000000-0000-4000-8000-${String(i).padStart(12, '0')}`,
    );
    const res = await request(app.getHttpServer())
      .post('/api/v1/favorites/merge')
      .send({ vehicleIds: tooMany })
      .expect(400);

    expect(res.body.error.details.validation.join('; ')).toMatch(
      /vehicleIds must contain no more than 100 elements/,
    );
  });

  it('saving a vehicle is idempotent over HTTP', async () => {
    const first = await request(app.getHttpServer())
      .post(`/api/v1/favorites/${V1}`)
      .expect(200);
    const second = await request(app.getHttpServer())
      .post(`/api/v1/favorites/${V1}`)
      .expect(200);

    expect(first.body.data.vehicle_ids).toEqual([V1]);
    expect(second.body.data.vehicle_ids).toEqual([V1]);
    expect(serviceStub.add).toHaveBeenCalledTimes(2);
  });

  it('removing a vehicle is idempotent over HTTP', async () => {
    await request(app.getHttpServer())
      .delete(`/api/v1/favorites/${V1}`)
      .expect(200);
    await request(app.getHttpServer())
      .delete(`/api/v1/favorites/${V1}`)
      .expect(200);
    expect(serviceStub.remove).toHaveBeenCalledTimes(2);
  });

  it('a chauffeur account cannot use the customer favourites API', async () => {
    currentRole = 'driver';
    const res = await request(app.getHttpServer())
      .get('/api/v1/favorites')
      .expect(403);

    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('ROLE_FORBIDDEN');
    expect(serviceStub.list).not.toHaveBeenCalled();
  });
});
