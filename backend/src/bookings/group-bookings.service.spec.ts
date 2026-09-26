import { createHash } from 'crypto';
import { AssignmentStatus } from '@prisma/client';
import { GroupBookingsService } from './group-bookings.service';
import { BookingStateMachineService } from '../booking-state-machine/booking-state-machine.service';
import { BookingStatus } from '../booking-state-machine/booking-status';
import { Role } from '../auth/domain/roles';
import { AuthenticatedUser } from '../auth/domain/auth.types';

const CUSTOMER: AuthenticatedUser = {
  userId: 'customer-1',
  role: Role.Customer,
  phoneNumber: '+919810000001',
  accountStatus: 'ACTIVE',
} as AuthenticatedUser;
const OTHER_CUSTOMER: AuthenticatedUser = { ...CUSTOMER, userId: 'customer-2' };
const ADMIN: AuthenticatedUser = { ...CUSTOMER, userId: 'admin-1', role: Role.SuperAdmin };

const GROUP_ID = '11111111-2222-4333-8444-555555555555';

function group(overrides: Record<string, unknown> = {}) {
  return {
    id: GROUP_ID,
    referenceCode: 'SD-GRP-2026-000123',
    customerFk: CUSTOMER.userId,
    ceremonyType: 'Baraat',
    city: 'Delhi NCR',
    pickupAddress: 'Sector 15, Gurugram',
    destinationAddress: 'The Leela Palace',
    serviceStartTime: new Date('2026-11-20T10:00:00Z'),
    serviceEndTime: new Date('2026-11-20T22:00:00Z'),
    passengerCount: 7,
    status: BookingStatus.REQUESTED,
    version: 1,
    estimatedTotalPaise: 3_000_000n,
    advanceTokenPaise: 750_000n,
    requirements: [],
    communicationPreference: 'PHONE',
    requestedFleetItems: [],
    assignments: [],
    ...overrides,
  };
}

describe('GroupBookingsService', () => {
  const prisma: any = {
    groupBooking: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    groupBookingEvent: { create: jest.fn() },
    vehicleType: { findMany: jest.fn(), findUnique: jest.fn() },
    vehicle: { findMany: jest.fn() },
    vehiclePricing: { findFirst: jest.fn() },
    vehicleAssignment: { createMany: jest.fn(), findMany: jest.fn(), update: jest.fn() },
    driverProfile: { findUnique: jest.fn() },
    availability: {
      findMany: jest.fn(),
      findFirst: jest.fn(),
      createMany: jest.fn(),
      create: jest.fn(),
      deleteMany: jest.fn(),
    },
    // Mirrors Prisma: interactive callback, or an array of operations resolved
    // together (the list endpoint uses the array form for page + count).
    $transaction: jest.fn(async (arg: any) =>
      typeof arg === 'function' ? arg(prisma) : Promise.all(arg),
    ),
  };
  const availability: any = {
    checkFleetAvailability: jest.fn(),
  };
  const sms: any = { sendOtp: jest.fn().mockResolvedValue({ accepted: true }) };

  let service: GroupBookingsService;

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.availability.findMany.mockResolvedValue([]);
    prisma.availability.findFirst.mockResolvedValue(null);
    prisma.availability.create.mockResolvedValue({});
    prisma.availability.createMany.mockResolvedValue({ count: 1 });
    prisma.availability.deleteMany.mockResolvedValue({ count: 1 });
    prisma.groupBookingEvent.create.mockResolvedValue({});
    prisma.vehicleAssignment.createMany.mockResolvedValue({ count: 1 });
    service = new GroupBookingsService(
      prisma,
      availability,
      new BookingStateMachineService(),
      sms,
    );
  });

  // ---------------------------------------------------------------- scoping

  describe('getGroupBooking', () => {
    it('serves the owner', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(group());
      const view = await service.getGroupBooking(GROUP_ID, CUSTOMER);
      expect(view.reference_code).toBe('SD-GRP-2026-000123');
    });

    it('hides another customer’s booking behind a 404 — not a 403 oracle', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(group());
      await expect(service.getGroupBooking(GROUP_ID, OTHER_CUSTOMER)).rejects.toMatchObject({
        code: 'GROUP_BOOKING_NOT_FOUND',
      });
    });

    it('lets an admin read any booking (they must be able to work it)', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(group());
      await expect(service.getGroupBooking(GROUP_ID, ADMIN)).resolves.toBeTruthy();
    });

    it('404s an unknown id', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(null);
      await expect(service.getGroupBooking(GROUP_ID, CUSTOMER)).rejects.toMatchObject({
        code: 'GROUP_BOOKING_NOT_FOUND',
      });
    });
  });

  describe('listMyGroupBookings', () => {
    it('scopes the query to the caller', async () => {
      prisma.groupBooking.findMany.mockResolvedValue([group()]);
      prisma.groupBooking.count.mockResolvedValue(1);
      const result = await service.listMyGroupBookings(CUSTOMER.userId);
      expect(prisma.groupBooking.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { customerFk: CUSTOMER.userId } }),
      );
      expect(result.total).toBe(1);
      expect(result.items).toHaveLength(1);
    });
  });

  // ------------------------------------------------------------- transition

  describe('customerTransition', () => {
    it('refuses to touch someone else’s booking', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(group());
      await expect(
        service.customerTransition(GROUP_ID, 'CANCEL', OTHER_CUSTOMER),
      ).rejects.toMatchObject({ code: 'GROUP_BOOKING_NOT_FOUND' });
    });

    it('a customer cannot confirm a booking operations has not opened up', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(group());
      await expect(
        service.customerTransition(GROUP_ID, 'CONFIRM_BOOKING', CUSTOMER),
      ).rejects.toThrow(/not permitted/i);
      expect(prisma.groupBooking.update).not.toHaveBeenCalled();
    });

    it('a customer cannot drive their own request into operations-only states', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(group());
      for (const action of ['BEGIN_REVIEW', 'PREPARE_VEHICLE_OPTIONS', 'EXPIRE']) {
        await expect(
          service.customerTransition(GROUP_ID, action, CUSTOMER),
        ).rejects.toThrow(/not permitted/i);
      }
    });

    it('confirms from CUSTOMER_CONFIRMATION_PENDING and writes history', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({
          status: BookingStatus.CUSTOMER_CONFIRMATION_PENDING,
          assignments: [
            { id: 'a1', driverId: 'd1', assignmentStatus: 'CHAUFFEUR_ASSIGNED' },
          ],
        }),
      );
      prisma.groupBooking.update.mockResolvedValue({
        id: GROUP_ID,
        referenceCode: 'SD-GRP-2026-000123',
        status: BookingStatus.CONFIRMED,
        version: 2,
      });
      const result = await service.customerTransition(GROUP_ID, 'CONFIRM_BOOKING', CUSTOMER);
      expect(result.status).toBe(BookingStatus.CONFIRMED);
      expect(prisma.groupBookingEvent.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            fromStatus: BookingStatus.CUSTOMER_CONFIRMATION_PENDING,
            toStatus: BookingStatus.CONFIRMED,
            triggerRole: Role.Customer,
            triggeredByUserId: CUSTOMER.userId,
          }),
        }),
      );
    });

    it('requiring a reason when the customer sends options back for revision', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({ status: BookingStatus.CUSTOMER_CONFIRMATION_PENDING }),
      );
      await expect(
        service.customerTransition(GROUP_ID, 'REVISE_OPTIONS', CUSTOMER),
      ).rejects.toMatchObject({ code: 'VALIDATION_FAILED' });
    });

    it('releases the calendar when the customer cancels', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(group({ status: BookingStatus.REQUESTED }));
      // The cancel path must not demand a ready fleet.
      prisma.vehicleAssignment.findMany.mockResolvedValue([{ vehicleId: 'veh-1' }]);
      prisma.groupBooking.update.mockResolvedValue({
        id: GROUP_ID,
        referenceCode: 'x',
        status: BookingStatus.CANCELLED,
        version: 2,
      });
      await service.customerTransition(GROUP_ID, 'CANCEL', CUSTOMER, 'Plans changed.');
      expect(prisma.availability.deleteMany).toHaveBeenCalled();
    });
  });

  // ------------------------------------------------------- chauffeur assign

  describe('assignChauffeur', () => {
    beforeEach(() => {
      prisma.$queryRaw = jest
        .fn()
        .mockResolvedValue([
          { id: 'asg-1', assignment_status: 'VEHICLE_CONFIRMED', group_booking_id: GROUP_ID },
        ]);
      prisma.driverProfile.findUnique.mockResolvedValue({
        id: 'driver-1',
        verificationStatus: 'APPROVED',
      });
      prisma.vehicleAssignment.update.mockResolvedValue({
        id: 'asg-1',
        driverId: 'driver-1',
        assignmentStatus: 'CHAUFFEUR_ASSIGNED',
      });
      prisma.vehicleAssignment.findMany.mockResolvedValue([
        { assignmentStatus: 'CHAUFFEUR_ASSIGNED' },
      ]);
      prisma.groupBooking.update.mockResolvedValue({});
    });

    it('refuses an unverified chauffeur', async () => {
      prisma.driverProfile.findUnique.mockResolvedValue({
        id: 'driver-1',
        verificationStatus: 'PENDING_SUBMISSION',
      });
      await expect(service.assignChauffeur('asg-1', 'driver-1', 'ops-1')).rejects.toThrow(
        /Only verified chauffeurs/i,
      );
    });

    it('refuses to staff a vehicle operations has not confirmed', async () => {
      prisma.$queryRaw.mockResolvedValue([
        { id: 'asg-1', assignment_status: 'PROPOSED', group_booking_id: GROUP_ID },
      ]);
      await expect(service.assignChauffeur('asg-1', 'driver-1', 'ops-1')).rejects.toThrow(
        /confirmed vehicle/i,
      );
    });

    it('advances a REQUESTED booking once every vehicle is staffed', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(group({ status: BookingStatus.REQUESTED }));
      await service.assignChauffeur('asg-1', 'driver-1', 'ops-1');
      expect(prisma.groupBooking.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ status: BookingStatus.VEHICLE_OPTIONS_PREPARED }),
        }),
      );
    });

    it('never rewinds a booking that is already awaiting the customer', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({ status: BookingStatus.CUSTOMER_CONFIRMATION_PENDING }),
      );
      await service.assignChauffeur('asg-1', 'driver-1', 'ops-1');
      expect(prisma.groupBooking.update).not.toHaveBeenCalled();
    });

    it('refuses a chauffeur already committed to an overlapping window', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(group({ status: BookingStatus.REQUESTED }));
      prisma.availability.findFirst.mockResolvedValue({ id: 'lock-1' });
      await expect(service.assignChauffeur('asg-1', 'driver-1', 'ops-1')).rejects.toMatchObject({
        code: 'SLOT_DOUBLE_BOOKED',
      });
    });
  });

  // ------------------------------------------------------- trip execution

  describe('recordMilestone', () => {
    const assignmentRow = (overrides: Record<string, unknown> = {}) => ({
      id: 'asg-1',
      driver_id: 'driver-1',
      assignment_status: AssignmentStatus.CHAUFFEUR_ASSIGNED,
      group_booking_id: GROUP_ID,
      ...overrides,
    });

    beforeEach(() => {
      prisma.$queryRaw = jest.fn().mockResolvedValue([assignmentRow()]);
      prisma.driverProfile.findUnique.mockResolvedValue({
        id: 'driver-1',
        userId: CUSTOMER.userId,
        verificationStatus: 'APPROVED',
      });
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({
          status: BookingStatus.CONFIRMED,
          startOtpHash: null,
          assignments: [],
        }),
      );
      prisma.vehicleAssignment.update.mockResolvedValue({});
      prisma.vehicleAssignment.findMany.mockResolvedValue([
        { vehicleId: 'v1', assignmentStatus: AssignmentStatus.EN_ROUTE },
      ]);
      prisma.groupBooking.update.mockResolvedValue({});
      prisma.groupBookingEvent.create.mockResolvedValue({});
    });

    it('moves an assigned duty to EN_ROUTE and records the event', async () => {
      const result = await service.recordMilestone(
        'asg-1',
        'EN_ROUTE',
        CUSTOMER.userId,
      );
      expect(result.assignment_status).toBe(AssignmentStatus.EN_ROUTE);
      expect(prisma.vehicleAssignment.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ assignmentStatus: AssignmentStatus.EN_ROUTE }),
        }),
      );
      expect(prisma.groupBookingEvent.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ action: 'CHAUFFEUR_EN_ROUTE', triggerRole: Role.Driver }),
        }),
      );
    });

    it('404s (never 403) a duty that belongs to another chauffeur', async () => {
      prisma.$queryRaw.mockResolvedValue([
        assignmentRow({ driver_id: 'someone-else' }),
      ]);
      await expect(
        service.recordMilestone('asg-1', 'EN_ROUTE', CUSTOMER.userId),
      ).rejects.toMatchObject({ code: 'NOT_FOUND' });
    });

    it('enforces the forward ladder — no skipping from assigned to completed', async () => {
      prisma.$queryRaw.mockResolvedValue([assignmentRow()]);
      await expect(
        service.recordMilestone('asg-1', 'COMPLETE', CUSTOMER.userId),
      ).rejects.toThrow(/Cannot record COMPLETE/i);
      await expect(
        service.recordMilestone('asg-1', 'START_SERVICE', CUSTOMER.userId, '123456'),
      ).rejects.toThrow(/Cannot record START_SERVICE/i);
    });

    it('refuses to execute service on an unconfirmed booking', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({ status: BookingStatus.VEHICLE_OPTIONS_PREPARED }),
      );
      await expect(
        service.recordMilestone('asg-1', 'EN_ROUTE', CUSTOMER.userId),
      ).rejects.toThrow(/only be executed on a CONFIRMED booking/i);
    });

    it('START_SERVICE requires the customer OTP and rejects a wrong one', async () => {
      prisma.$queryRaw.mockResolvedValue([
        assignmentRow({ assignment_status: AssignmentStatus.ARRIVED }),
      ]);
      prisma.vehicleAssignment.findMany.mockResolvedValue([]);

      await expect(
        service.recordMilestone('asg-1', 'START_SERVICE', CUSTOMER.userId, '000000'),
      ).rejects.toMatchObject({ code: 'INVALID_OTP' });
      await expect(
        service.recordMilestone('asg-1', 'START_SERVICE', CUSTOMER.userId),
      ).rejects.toMatchObject({ code: 'INVALID_OTP' });
    });

    it('START_SERVICE accepts the correct OTP and flips the booking to IN_PROGRESS', async () => {
      prisma.$queryRaw.mockResolvedValue([
        assignmentRow({ assignment_status: AssignmentStatus.ARRIVED }),
      ]);
      const hash = createHash('sha256').update('482913').digest('hex');
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({ status: BookingStatus.CONFIRMED, startOtpHash: hash, assignments: [] }),
      );
      prisma.vehicleAssignment.findMany.mockResolvedValue([
        { vehicleId: 'v1', assignmentStatus: AssignmentStatus.IN_PROGRESS },
      ]);

      const result = await service.recordMilestone(
        'asg-1',
        'START_SERVICE',
        CUSTOMER.userId,
        '482913',
      );
      expect(result.assignment_status).toBe(AssignmentStatus.IN_PROGRESS);
      expect(prisma.groupBooking.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ status: BookingStatus.IN_PROGRESS }),
        }),
      );
      expect(prisma.groupBookingEvent.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ action: 'START_TRIP' }),
        }),
      );
    });

    it('the booking completes only when the WHOLE fleet completes, and locks are released', async () => {
      prisma.$queryRaw.mockResolvedValue([
        assignmentRow({ assignment_status: AssignmentStatus.IN_PROGRESS }),
      ]);
      prisma.vehicleAssignment.findMany.mockResolvedValue([
        { vehicleId: 'v1', assignmentStatus: AssignmentStatus.COMPLETED },
        { vehicleId: 'v2', assignmentStatus: AssignmentStatus.COMPLETED },
      ]);
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({ status: BookingStatus.IN_PROGRESS, balancePaidAt: new Date() }),
      );

      const result = await service.recordMilestone('asg-1', 'COMPLETE', CUSTOMER.userId);
      expect(result.assignment_status).toBe(AssignmentStatus.COMPLETED);
      expect(prisma.groupBooking.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ status: BookingStatus.COMPLETED }),
        }),
      );
      expect(prisma.availability.deleteMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ vehicleId: { in: ['v1', 'v2'] } }),
        }),
      );
    });

    it('one car still working keeps the booking IN_PROGRESS — no premature completion', async () => {
      prisma.$queryRaw.mockResolvedValue([
        assignmentRow({ assignment_status: AssignmentStatus.IN_PROGRESS }),
      ]);
      prisma.vehicleAssignment.findMany.mockResolvedValue([
        { vehicleId: 'v1', assignmentStatus: AssignmentStatus.COMPLETED },
        { vehicleId: 'v2', assignmentStatus: AssignmentStatus.IN_PROGRESS },
      ]);

      await service.recordMilestone('asg-1', 'COMPLETE', CUSTOMER.userId);
      const completed = prisma.groupBooking.update.mock.calls.some(
        (c: any[]) => c[0].data.status === BookingStatus.COMPLETED,
      );
      expect(completed).toBe(false);
    });

    it('a fleet whose balance is still outstanding cannot complete the trip', async () => {
      prisma.$queryRaw.mockResolvedValue([
        assignmentRow({ assignment_status: AssignmentStatus.IN_PROGRESS }),
      ]);
      prisma.vehicleAssignment.findMany.mockResolvedValue([
        { vehicleId: 'v1', assignmentStatus: AssignmentStatus.COMPLETED },
      ]);
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({ status: BookingStatus.IN_PROGRESS, balancePaidAt: null }),
      );

      await expect(
        service.recordMilestone('asg-1', 'COMPLETE', CUSTOMER.userId),
      ).rejects.toMatchObject({ code: 'PAYMENT_REQUIRED' });
      expect(prisma.groupBooking.update).not.toHaveBeenCalled();
    });

    it('a fully settled booking completes normally', async () => {
      prisma.$queryRaw.mockResolvedValue([
        assignmentRow({ assignment_status: AssignmentStatus.IN_PROGRESS }),
      ]);
      prisma.vehicleAssignment.findMany.mockResolvedValue([
        { vehicleId: 'v1', assignmentStatus: AssignmentStatus.COMPLETED },
      ]);
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({ status: BookingStatus.IN_PROGRESS, balancePaidAt: new Date() }),
      );

      await service.recordMilestone('asg-1', 'COMPLETE', CUSTOMER.userId);
      expect(prisma.groupBooking.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ status: BookingStatus.COMPLETED }),
        }),
      );
    });
  });

  // The SMS mock is shared across describe blocks; always look at the LAST
  // call this test itself made, never calls[0].
  const lastSmsCall = () => sms.sendOtp.mock.calls[sms.sendOtp.mock.calls.length - 1];

  describe('resendTripOtp', () => {
    it('is customer-only', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(group({ status: BookingStatus.CONFIRMED }));
      await expect(
        service.resendTripOtp(GROUP_ID, { ...CUSTOMER, userId: 'someone-else' } as any),
      ).rejects.toMatchObject({ code: 'ROLE_FORBIDDEN' });
    });

    it('is only active on a CONFIRMED booking', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(group({ status: BookingStatus.UNDER_REVIEW }));
      await expect(service.resendTripOtp(GROUP_ID, CUSTOMER)).rejects.toMatchObject({
        code: 'INVALID_TRANSITION',
      });
    });

    it('mints a NEW code, stores only its hash, and texts the customer', async () => {
      const withCustomer = {
        ...group({ status: BookingStatus.CONFIRMED }),
        customer: { phoneNumber: '+919810000001' },
      };
      prisma.groupBooking.findUnique.mockResolvedValue(withCustomer);
      prisma.groupBooking.update.mockResolvedValue({});

      const result = await service.resendTripOtp(GROUP_ID, CUSTOMER);
      expect(result.resent).toBe(true);
      const data = prisma.groupBooking.update.mock.calls[0][0].data;
      expect(data.startOtpHash).toMatch(/^[0-9a-f]{64}$/);
      const [to, code] = lastSmsCall();
      expect(to).toBe('+919810000001');
      expect(String(code)).toMatch(/^\d{4}$/);
    });
  });

  describe('confirming mints the trip OTP', () => {
    it('CONFIRM_BOOKING stores a hash and texts the customer the plaintext', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue({
        ...group({
          status: BookingStatus.CUSTOMER_CONFIRMATION_PENDING,
          // The readiness guard demands a fully allocated, priced fleet.
          estimatedTotalPaise: 3_000_000n,
          assignments: [
            { id: 'a1', driverId: 'd1', assignmentStatus: 'CHAUFFEUR_ASSIGNED' },
          ],
        }),
        customer: { phoneNumber: '+919810000001' },
      });
      prisma.groupBooking.update.mockResolvedValue({
        id: GROUP_ID,
        referenceCode: 'SD-GRP-2026-000123',
        status: BookingStatus.CONFIRMED,
        version: 2,
      });
      prisma.vehicleAssignment.findMany.mockResolvedValue([]);

      const result = await service.customerTransition(GROUP_ID, 'CONFIRM_BOOKING', CUSTOMER);
      expect(result.status).toBe(BookingStatus.CONFIRMED);

      const data = prisma.groupBooking.update.mock.calls[0][0].data;
      expect(data.startOtpHash).toMatch(/^[0-9a-f]{64}$/);
      const [to, code] = lastSmsCall();
      expect(to).toBe('+919810000001');
      expect(String(code)).toMatch(/^\d{4}$/); // 4-digit trip OTP (10k space)
      // The plaintext OTP never appears in the transition response.
      expect(JSON.stringify(result)).not.toMatch(/start_?otp/);
    });

    it('other transitions mint nothing', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(group({ status: BookingStatus.REQUESTED }));
      prisma.groupBooking.update.mockResolvedValue({
        id: GROUP_ID,
        referenceCode: 'x',
        status: BookingStatus.UNDER_REVIEW,
        version: 2,
      });
      prisma.vehicleAssignment.findMany.mockResolvedValue([]);

      await service.customerTransition(GROUP_ID, 'CANCEL', CUSTOMER, 'Plans changed.');
      const data = prisma.groupBooking.update.mock.calls[0][0].data;
      expect(data.startOtpHash).toBeUndefined();
      expect(sms.sendOtp).not.toHaveBeenCalled();
    });
  });

  // -------------------------------------------------- confirmability guard

  describe('assertConfirmable', () => {
    it('refuses a booking with no vehicles allocated', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(group({ assignments: [] }));
      await expect(service.assertConfirmable(GROUP_ID)).rejects.toThrow(
        /no vehicles are allocated/i,
      );
    });

    it('refuses a fleet with a vehicle operations has not confirmed', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({
          assignments: [{ id: 'a1', driverId: 'd1', assignmentStatus: 'PROPOSED' }],
        }),
      );
      await expect(service.assertConfirmable(GROUP_ID)).rejects.toThrow(
        /vehicle confirmation/i,
      );
    });

    it('refuses a fleet with a vehicle that has no chauffeur', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({
          assignments: [{ id: 'a1', driverId: null, assignmentStatus: 'VEHICLE_CONFIRMED' }],
        }),
      );
      await expect(service.assertConfirmable(GROUP_ID)).rejects.toThrow(/no chauffeur/i);
    });

    it('refuses an unquoted booking', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({
          estimatedTotalPaise: null,
          assignments: [{ id: 'a1', driverId: 'd1', assignmentStatus: 'CHAUFFEUR_ASSIGNED' }],
        }),
      );
      await expect(service.assertConfirmable(GROUP_ID)).rejects.toThrow(/no complete price/i);
    });

    it('accepts a fully allocated, staffed and priced fleet', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({
          assignments: [{ id: 'a1', driverId: 'd1', assignmentStatus: 'CHAUFFEUR_ASSIGNED' }],
        }),
      );
      await expect(service.assertConfirmable(GROUP_ID)).resolves.toBeUndefined();
    });

    it('is enforced on the CUSTOMER confirm path too — no loophole', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({
          status: BookingStatus.CUSTOMER_CONFIRMATION_PENDING,
          assignments: [{ id: 'a1', driverId: null, assignmentStatus: 'VEHICLE_CONFIRMED' }],
        }),
      );
      await expect(
        service.customerTransition(GROUP_ID, 'CONFIRM_BOOKING', CUSTOMER),
      ).rejects.toThrow(/no chauffeur/i);
      expect(prisma.groupBooking.update).not.toHaveBeenCalled();
    });
  });

  // ------------------------------------------------------------------ quote

  describe('submitGroupBooking quoting', () => {
    const approvedTariff = {
      id: 'pricing-9',
      version: 4,
      localIncludedKm: 45,
      localAmountPaise: 300_000n,
      perKmPaise: 2_300n,
      hourlyPaise: null,
      extraHourPaise: null,
      fullDayPaise: 1_200_000n,
      overnightPaise: 1_500_000n,
      outstationPerDayPaise: null,
      outstationPerKmPaise: null,
    };

    const input = {
      customerId: CUSTOMER.userId,
      serviceCategoryId: 'cat-1',
      ceremonyType: 'Baraat',
      city: 'Delhi NCR',
      pickupAddress: 'Sector 15',
      destinationAddress: 'The Leela Palace',
      serviceStartTime: new Date('2026-11-20T10:00:00Z'),
      serviceEndTime: new Date('2026-11-20T22:00:00Z'),
      primaryContactName: 'Aarav',
      primaryContactPhone: '+919810000001',
      passengerCount: 6,
      fleet: [{ vehicleTypeId: 'vt-thar', quantity: 2 }],
      idempotencyKey: 'idem-key-12345678',
    };

    beforeEach(() => {
      prisma.groupBooking.findUnique.mockResolvedValue(null);
      availability.checkFleetAvailability.mockResolvedValue({
        fully_available: true,
        lines: [],
        total_requested: 2,
        total_available: 2,
        total_shortfall: 0,
      });
      prisma.vehicleType.findMany.mockResolvedValue([
        { id: 'vt-thar', displayName: 'Mahindra Thar' },
      ]);
      prisma.vehicle.findMany.mockResolvedValue([
        { id: 'veh-1', basePricePaise: 0n },
        { id: 'veh-2', basePricePaise: 0n },
      ]);
      prisma.groupBooking.create.mockImplementation(async ({ data }: any) => ({
        id: GROUP_ID,
        ...data,
      }));
    });

    it('prices from the APPROVED tariff, never the legacy (often zero) base price', async () => {
      prisma.vehiclePricing.findFirst.mockResolvedValue(approvedTariff);
      await service.submitGroupBooking(input);

      const created = prisma.groupBooking.create.mock.calls[0][0].data;
      // 12h window → overnight ₹15,000 for each of 2 vehicles.
      expect(created.estimatedTotalPaise).toBe(3_000_000n);
      expect(created.advanceTokenPaise).toBe(750_000n);
      expect(created.pricingSnapshot.complete).toBe(true);
      expect(created.pricingSnapshot.lines).toHaveLength(2);
      expect(prisma.vehiclePricing.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { vehicleId: 'veh-1', status: 'APPROVED' },
          orderBy: { version: 'desc' },
        }),
      );
    });

    it('freezes a snapshot on every assignment so a later tariff edit cannot rewrite the price', async () => {
      prisma.vehiclePricing.findFirst.mockResolvedValue(approvedTariff);
      await service.submitGroupBooking(input);

      const rows = prisma.vehicleAssignment.createMany.mock.calls[0][0].data;
      expect(rows).toHaveLength(2);
      for (const row of rows) {
        expect(row.estimatedTotalPaise).toBe(1_500_000n);
        expect(row.pricingSnapshot.tariff_version).toBe(4);
        expect(row.pricingSnapshot.amount_paise).toBe('1500000');
      }
    });

    it('leaves the booking UNPRICED (null, not ₹0) when a vehicle has no approved tariff', async () => {
      prisma.vehiclePricing.findFirst
        .mockResolvedValueOnce(approvedTariff)
        .mockResolvedValueOnce(null);
      await service.submitGroupBooking(input);

      const created = prisma.groupBooking.create.mock.calls[0][0].data;
      expect(created.estimatedTotalPaise).toBeNull();
      expect(created.advanceTokenPaise).toBeNull();
      expect(created.pricingSnapshot.complete).toBe(false);
      expect(created.pricingSnapshot.unpriced_vehicle_ids).toEqual(['veh-2']);
    });

    it('records the submission in the booking’s lifecycle history', async () => {
      prisma.vehiclePricing.findFirst.mockResolvedValue(approvedTariff);
      await service.submitGroupBooking(input);
      expect(prisma.groupBookingEvent.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            toStatus: BookingStatus.REQUESTED,
            action: 'SUBMIT_REQUEST',
            triggerRole: Role.Customer,
          }),
        }),
      );
    });

    it('refuses to submit if availability dropped — never a silent substitution', async () => {
      availability.checkFleetAvailability.mockResolvedValue({
        fully_available: false,
        lines: [
          {
            vehicle_type_id: 'vt-thar',
            requested: 4,
            available: 2,
            shortfall: 2,
            satisfied: false,
          },
        ],
      });
      await expect(service.submitGroupBooking(input)).rejects.toMatchObject({
        code: 'FLEET_INSUFFICIENT_AVAILABILITY',
      });
      expect(prisma.groupBooking.create).not.toHaveBeenCalled();
    });

    it('requires a non-empty fleet', async () => {
      await expect(
        service.submitGroupBooking({ ...input, fleet: [] }),
      ).rejects.toMatchObject({ code: 'VALIDATION_FAILED' });
    });

    it('replays the same request instead of creating a duplicate', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue({
        id: GROUP_ID,
        referenceCode: 'SD-GRP-2026-000123',
        assignments: [],
      });
      const result = await service.submitGroupBooking(input);
      expect(result.idempotentReplay).toBe(true);
      expect(prisma.groupBooking.create).not.toHaveBeenCalled();
      expect(prisma.vehiclePricing.findFirst).not.toHaveBeenCalled();
    });
  });
});
