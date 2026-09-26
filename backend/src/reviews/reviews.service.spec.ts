import { ReviewsService } from './reviews.service';
import { ReviewStatus } from '@prisma/client';
import { BookingStatus } from '../booking-state-machine/booking-status';
import { Role } from '../auth/domain/roles';
import { AuthenticatedUser } from '../auth/domain/auth.types';

const CUSTOMER: AuthenticatedUser = {
  userId: 'customer-1',
  role: Role.Customer,
  phoneNumber: '+919810000001',
  accountStatus: 'ACTIVE',
} as AuthenticatedUser;
const OTHER: AuthenticatedUser = { ...CUSTOMER, userId: 'customer-2' };
const ADMIN: AuthenticatedUser = { ...CUSTOMER, userId: 'admin-1', role: Role.SuperAdmin };

const GROUP_ID = '11111111-2222-4333-8444-555555555555';
const VEHICLE_ID = '33333333-4444-4555-8666-777777777777';
const ASSIGNMENT_ID = '22222222-3333-4444-8555-666666666666';

const dto = {
  groupBookingId: GROUP_ID,
  vehicleId: VEHICLE_ID,
  overallRating: 5,
  punctualityRating: 5,
  cleanlinessRating: 4,
  feedbackText: 'Immaculate cars, on time, courteous driver.',
};

function completedGroup(overrides: Record<string, unknown> = {}) {
  return {
    id: GROUP_ID,
    referenceCode: 'SD-GRP-2026-000777',
    customerFk: CUSTOMER.userId,
    status: BookingStatus.COMPLETED,
    serviceEndTime: new Date('2026-12-06T16:00:00Z'),
    ceremonyType: 'Baraat',
    assignments: [
      {
        id: ASSIGNMENT_ID,
        vehicleId: VEHICLE_ID,
        driverId: 'driver-9',
        assignmentStatus: 'COMPLETED',
      },
    ],
    reviews: [],
    ...overrides,
  };
}

describe('ReviewsService', () => {
  const prisma: any = {
    groupBooking: { findUnique: jest.fn(), findMany: jest.fn() },
    review: {
      findFirst: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      count: jest.fn(),
      aggregate: jest.fn(),
      update: jest.fn(),
    },
    auditLog: { create: jest.fn() },
    $transaction: jest.fn(async (arg: any) =>
      typeof arg === 'function' ? arg(prisma) : Promise.all(arg),
    ),
  };
  let service: ReviewsService;

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.review.create.mockImplementation(async ({ data }: any) => ({ id: 'rev-1', ...data }));
    prisma.auditLog.create.mockResolvedValue({});
    prisma.review.count.mockResolvedValue(0);
    prisma.review.aggregate.mockResolvedValue({ _avg: { overallRating: null } });
    service = new ReviewsService(prisma);
  });

  // ------------------------------------------------------------ eligibility

  describe('submit', () => {
    it('accepts a completed booking reviewed by its own customer', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(completedGroup());
      prisma.review.findFirst.mockResolvedValue(null);

      const view = await service.submit(dto, CUSTOMER);

      expect(view.ratings.overall).toBe(5);
      expect(view.status).toBe(ReviewStatus.PENDING_MODERATION);
      // Chauffeur attribution derived internally, never submitted.
      const data = prisma.review.create.mock.calls[0][0].data;
      expect(data.driverFk).toBe('driver-9');
      expect(data.assignmentId).toBe(ASSIGNMENT_ID);
      expect(data.groupBookingId).toBe(GROUP_ID);
    });

    it('hides another customer’s booking behind a 404 — no probing oracle', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(completedGroup());
      await expect(service.submit(dto, OTHER)).rejects.toMatchObject({
        code: 'GROUP_BOOKING_NOT_FOUND',
      });
      expect(prisma.review.create).not.toHaveBeenCalled();
    });

    it('refuses to review a booking that is not COMPLETED', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(
        completedGroup({ status: BookingStatus.CONFIRMED }),
      );
      await expect(service.submit(dto, CUSTOMER)).rejects.toThrow(
        /Only a completed booking can be reviewed/i,
      );
    });

    it('refuses a vehicle that was not part of the booking', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(completedGroup({ assignments: [] }));
      await expect(service.submit(dto, CUSTOMER)).rejects.toMatchObject({ code: 'NOT_FOUND' });
    });

    it('blocks a duplicate review of the same vehicle in the same booking', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(completedGroup());
      prisma.review.findFirst.mockResolvedValue({ id: 'already' });
      await expect(service.submit(dto, CUSTOMER)).rejects.toThrow(
        /already reviewed this vehicle/i,
      );
    });

    it('does NOT trust a client-supplied chauffeur or assignment id', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(completedGroup());
      prisma.review.findFirst.mockResolvedValue(null);
      await service.submit({ ...dto, driverId: 'fake' } as any, CUSTOMER);
      const data = prisma.review.create.mock.calls[0][0].data;
      expect(data.driverFk).toBe('driver-9'); // from the assignment, not the body
    });
  });

  // ------------------------------------------------------------- reading

  describe('pendingForMe', () => {
    it('lists un-reviewed vehicles of completed bookings only', async () => {
      prisma.groupBooking.findMany.mockResolvedValue([
        completedGroup({
          assignments: [
            {
              id: ASSIGNMENT_ID,
              vehicleId: VEHICLE_ID,
              vehicle: { fleetCode: 'SD-VH-0001', vehicleType: { displayName: 'Innova' } },
            },
            {
              id: 'asg-2',
              vehicleId: 'veh-2',
              vehicle: { fleetCode: 'SD-VH-0002', vehicleType: { displayName: 'Thar' } },
            },
          ],
          reviews: [{ vehicleFk: VEHICLE_ID }],
        }),
      ]);

      const result = await service.pendingForMe(CUSTOMER.userId);

      expect(prisma.groupBooking.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { customerFk: CUSTOMER.userId, status: BookingStatus.COMPLETED },
        }),
      );
      expect(result.items).toHaveLength(1);
      expect((result.items[0] as any).vehicle.id).toBe('veh-2');
    });
  });

  describe('listForVehicle', () => {
    it('exposes only PUBLISHED reviews with a first-name author', async () => {
      prisma.review.findMany.mockResolvedValue([
        {
          id: 'rev-1',
          overallRating: 5,
          punctualityRating: 5,
          groomingRating: null,
          cleanlinessRating: 4,
          drivingRating: 5,
          vehicleQualityRating: 5,
          feedbackText: 'Flawless.',
          createdAt: new Date(),
          customer: { fullName: 'Aarav Sharma' },
        },
      ]);
      prisma.review.count.mockResolvedValue(1);
      prisma.review.aggregate.mockResolvedValue({ _avg: { overallRating: 4.667 } });

      const result = await service.listForVehicle(VEHICLE_ID);

      expect(prisma.review.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { vehicleFk: VEHICLE_ID, status: ReviewStatus.PUBLISHED },
        }),
      );
      expect(result.items[0].author).toBe('Aarav'); // first name only
      expect(result.items[0]).not.toHaveProperty('customer');
      expect(result.average_rating).toBe(4.67);
    });
  });

  // ------------------------------------------------------------ moderation

  describe('moderate', () => {
    it('publishes a pending review and audits the decision', async () => {
      prisma.review.findUnique.mockResolvedValue({
        id: 'rev-1',
        status: ReviewStatus.PENDING_MODERATION,
      });
      prisma.review.update.mockResolvedValue({
        id: 'rev-1',
        status: ReviewStatus.PUBLISHED,
        moderatedAt: new Date(),
      });

      const result = await service.moderate('rev-1', 'PUBLISH', ADMIN);
      expect(result.status).toBe(ReviewStatus.PUBLISHED);
      expect(prisma.auditLog.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ action: 'REVIEW_PUBLISH' }),
        }),
      );
    });

    it('requires a reason to hide a review', async () => {
      prisma.review.findUnique.mockResolvedValue({
        id: 'rev-1',
        status: ReviewStatus.PUBLISHED,
      });
      await expect(service.moderate('rev-1', 'HIDE', ADMIN)).rejects.toMatchObject({
        code: 'VALIDATION_FAILED',
      });
      await expect(
        service.moderate('rev-1', 'HIDE', ADMIN, 'Defamatory content.'),
      ).resolves.toBeTruthy();
    });

    it('refuses a no-op moderation', async () => {
      prisma.review.findUnique.mockResolvedValue({
        id: 'rev-1',
        status: ReviewStatus.PUBLISHED,
      });
      await expect(service.moderate('rev-1', 'PUBLISH', ADMIN)).rejects.toThrow(
        /already PUBLISHED/i,
      );
    });
  });
});
