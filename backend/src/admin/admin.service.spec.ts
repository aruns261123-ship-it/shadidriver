import { AdminService } from './admin.service';
import { VerificationStatus } from '@prisma/client';
import { Role } from '../auth/domain/roles';

const ADMIN = {
  userId: 'admin-1',
  role: Role.VerificationAdmin,
  phoneNumber: '+918100000011',
  accountStatus: 'ACTIVE',
};

describe('AdminService (verification center)', () => {
  let service: AdminService;
  let prisma: any;
  let partners: Record<string, unknown>[];
  let vehicles: Record<string, unknown>[];
  let pricing: Record<string, unknown>[];
  let audits: Record<string, unknown>[];

  beforeEach(() => {
    partners = [];
    vehicles = [];
    pricing = [];
    audits = [];

    prisma = {
      partnerProfile: {
        findMany: jest.fn(async () => partners),
        findUnique: jest.fn(async ({ where }: any) => partners.find((p) => p.id === where.id) ?? null),
        update: jest.fn(async ({ where, data }: any) => {
          // Replace (not mutate): the service snapshots the pre-decision state
          // for its audit row, exactly as a real Prisma read would.
          const idx = partners.findIndex((p) => p.id === where.id);
          const row: any = { ...partners[idx], ...data };
          partners[idx] = row;
          return row;
        }),
      },
      vehicle: {
        findMany: jest.fn(async () => vehicles),
        findUnique: jest.fn(async ({ where }: any) => vehicles.find((v) => v.id === where.id) ?? null),
        update: jest.fn(async ({ where, data }: any) => {
          const idx = vehicles.findIndex((v) => v.id === where.id);
          const row: any = { ...vehicles[idx], ...data };
          vehicles[idx] = row;
          return row;
        }),
      },
      vehiclePricing: {
        findMany: jest.fn(async ({ where }: any) =>
          // pricingQueue: first call fetches PENDING, second fetches live APPROVED rows
          where.status === 'PENDING_REVIEW'
            ? pricing.filter((p) => p.status === 'PENDING_REVIEW')
            : pricing.filter((p) => p.status === 'APPROVED' && where.vehicleId?.in?.includes(p.vehicleId)),
        ),
        findUnique: jest.fn(async ({ where }: any) => pricing.find((p) => p.id === where.id) ?? null),
        update: jest.fn(async ({ where, data }: any) => {
          const row: any = pricing.find((p) => p.id === where.id);
          Object.assign(row, data);
          return row;
        }),
        updateMany: jest.fn(async ({ where, data }: any) => {
          for (const row of pricing) {
            if (row.vehicleId === where.vehicleId && row.status === where.status) {
              Object.assign(row, data);
            }
          }
          return { count: 1 };
        }),
      },
      auditLog: {
        create: jest.fn(async ({ data }: any) => {
          audits.push(data);
          return data;
        }),
      },
      $transaction: jest.fn(async (fn: any) => fn(prisma)),
    };

    service = new AdminService(prisma);
  });

  // ------------------------------------------------------------------ queues

  describe('queues', () => {
    it('lists SUBMITTED partners oldest-first with fleet readiness counts', async () => {
      partners.push(
        {
          id: 'p-old', companyName: 'Old Fleet', contactName: 'A', baseCity: 'Delhi NCR',
          serviceCities: [], experienceYears: 5, licenseNumber: 'L1',
          verificationStatus: 'SUBMITTED', submittedAt: new Date('2026-01-01'),
          user: { phoneNumber: '+919810000001', fullName: 'A' },
          vehicles: [{ id: 'v1', verificationStatus: 'APPROVED' }, { id: 'v2', verificationStatus: 'PENDING_SUBMISSION' }],
        },
        {
          id: 'p-new', companyName: 'New Fleet', contactName: 'B', baseCity: 'Jaipur',
          serviceCities: [], experienceYears: 2, licenseNumber: 'L2',
          verificationStatus: 'SUBMITTED', submittedAt: new Date('2026-02-01'),
          user: { phoneNumber: '+919810000002', fullName: 'B' },
          vehicles: [],
        },
      );
      const queue = await service.partnerQueue();
      expect(queue.items.map((p: any) => p.id)).toEqual(['p-old', 'p-new']);
      expect(queue.items[0].fleet_size).toBe(2);
      expect(queue.items[0].fleet_pending).toBe(1);
    });

    it('the pricing queue shows submitted and currently-live tariffs side by side', async () => {
      pricing.push(
        { id: 'live', vehicleId: 'veh-1', version: 1, status: 'APPROVED', localAmountPaise: 300000n },
        { id: 'prop', vehicleId: 'veh-1', version: 2, status: 'PENDING_REVIEW', localAmountPaise: 350000n },
      );
      vehicles.push({ id: 'veh-1', fleetCode: 'SD-DEL-00001' });
      const queue = await service.pricingQueue();
      expect(queue.items).toHaveLength(1);
      expect(queue.items[0].submitted.local_amount_paise).toBe('350000');
      expect(queue.items[0].currently_live?.local_amount_paise).toBe('300000');
    });
  });

  // ------------------------------------------------------- partner decisions

  describe('partner decisions', () => {
    function pendingPartner() {
      partners.push({ id: 'p1', verificationStatus: VerificationStatus.SUBMITTED, decisionReason: null });
      return 'p1';
    }

    it('APPROVE marks the partner verified', async () => {
      const id = pendingPartner();
      const view = await service.decidePartner(ADMIN, id, 'APPROVE');
      expect(view.verification_status).toBe(VerificationStatus.APPROVED);
      expect(audits[0].action).toBe('PARTNER_VERIFICATION_DECIDED');
      expect(audits[0].actorId).toBe(ADMIN.userId);
      expect((audits[0].changes as any).from).toBe('SUBMITTED');
    });

    it('REJECT requires a reason and stores it verbatim', async () => {
      const id = pendingPartner();
      const view = await service.decidePartner(ADMIN, id, 'REJECT', 'License expired.');
      expect(view.verification_status).toBe(VerificationStatus.REJECTED);
      expect(view.decision_reason).toBe('License expired.');
    });

    it('REJECT without a reason is refused before anything is written', async () => {
      const id = pendingPartner();
      await expect(service.decidePartner(ADMIN, id, 'REJECT')).rejects.toThrow(
        /decisionReason is required/i,
      );
      expect(prisma.partnerProfile.update).not.toHaveBeenCalled();
      expect(audits).toHaveLength(0);
    });

    it('REQUEST_CHANGES requires a reason and maps to ACTION_REQUIRED', async () => {
      const id = pendingPartner();
      const view = await service.decidePartner(ADMIN, id, 'REQUEST_CHANGES', 'Add trade licence.');
      expect(view.verification_status).toBe(VerificationStatus.ACTION_REQUIRED);
    });

    it('an unknown partner id is NOT_FOUND', async () => {
      await expect(service.decidePartner(ADMIN, 'nope', 'APPROVE')).rejects.toThrow(
        /not found/i,
      );
    });
  });

  // ------------------------------------------------------- vehicle decisions

  describe('vehicle decisions', () => {
    it('APPROVE publishes the vehicle and reports is_public', async () => {
      vehicles.push({ id: 'v1', verificationStatus: VerificationStatus.PENDING_SUBMISSION });
      const view = await service.decideVehicle(ADMIN, 'v1', 'APPROVE');
      expect(view.verification_status).toBe(VerificationStatus.APPROVED);
      expect(view.is_public).toBe(true);
      expect(audits[0].action).toBe('VEHICLE_VERIFICATION_DECIDED');
    });

    it('REQUEST_CHANGES without a reason is refused', async () => {
      vehicles.push({ id: 'v1', verificationStatus: VerificationStatus.PENDING_SUBMISSION });
      await expect(service.decideVehicle(ADMIN, 'v1', 'REQUEST_CHANGES')).rejects.toThrow(
        /decisionReason is required/i,
      );
      expect(prisma.vehicle.update).not.toHaveBeenCalled();
    });

    it('an unknown vehicle id is NOT_FOUND', async () => {
      await expect(service.decideVehicle(ADMIN, 'nope', 'APPROVE')).rejects.toThrow(/not found/i);
    });
  });

  // ------------------------------------------------------- pricing decisions

  describe('pricing decisions', () => {
    it('APPROVE supersedes the live version and activates the submitted one atomically', async () => {
      pricing.push(
        { id: 'live', vehicleId: 'veh-1', version: 1, status: 'APPROVED', effectiveTo: null },
        { id: 'prop', vehicleId: 'veh-1', version: 2, status: 'PENDING_REVIEW', effectiveFrom: null },
      );
      const view = await service.decidePricing(ADMIN, 'prop', 'APPROVE');

      expect(view.status).toBe('APPROVED');
      const live = pricing.find((p) => p.id === 'live') as any;
      expect(live.status).toBe('SUPERSEDED');
      expect(live.effectiveTo).toBeInstanceOf(Date);
      const prop = pricing.find((p) => p.id === 'prop') as any;
      expect(prop.reviewedByUserId).toBe(ADMIN.userId);
      expect(audits.some((a) => (a as any).action === 'PRICING_APPROVED')).toBe(true);
    });

    it('cannot approve a version that is not PENDING_REVIEW', async () => {
      pricing.push({ id: 'old', vehicleId: 'veh-1', version: 1, status: 'SUPERSEDED' });
      await expect(service.decidePricing(ADMIN, 'old', 'APPROVE')).rejects.toThrow(
        /only a PENDING_REVIEW submission can be approved/i,
      );
    });

    it('REJECT keeps the previously live tariff untouched', async () => {
      pricing.push(
        { id: 'live', vehicleId: 'veh-1', version: 1, status: 'APPROVED' },
        { id: 'prop', vehicleId: 'veh-1', version: 2, status: 'PENDING_REVIEW' },
      );
      const view = await service.decidePricing(ADMIN, 'prop', 'REJECT', 'Too low.');
      expect(view.status).toBe('REJECTED');
      const live = pricing.find((p) => p.id === 'live') as any;
      expect(live.status).toBe('APPROVED');
    });

    it('REQUEST_CHANGES keeps the tariff pending but records the reason', async () => {
      pricing.push({ id: 'prop', vehicleId: 'veh-1', version: 2, status: 'PENDING_REVIEW' });
      const view = await service.decidePricing(ADMIN, 'prop', 'REQUEST_CHANGES', 'Day rate unclear.');
      expect(view.status).toBe('PENDING_REVIEW');
      expect(view.decision_reason).toBe('Day rate unclear.');
    });

    it('REQUEST_CHANGES without a reason is refused', async () => {
      pricing.push({ id: 'prop', vehicleId: 'veh-1', version: 2, status: 'PENDING_REVIEW' });
      await expect(service.decidePricing(ADMIN, 'prop', 'REQUEST_CHANGES')).rejects.toThrow(
        /decisionReason is required/i,
      );
    });
  });
});
