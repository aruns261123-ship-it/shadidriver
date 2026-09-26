import { OperationsService } from './operations.service';
import { BookingStateMachineService } from '../booking-state-machine/booking-state-machine.service';
import { BookingStatus } from '../booking-state-machine/booking-status';
import { AuthenticatedUser } from '../auth/domain/auth.types';
import { Role } from '../auth/domain/roles';

const OPS: AuthenticatedUser = {
  userId: 'aaaaaaaa-1111-4111-8111-111111111111',
  role: Role.OperationsAdmin,
  phoneNumber: '+918100000011',
  accountStatus: 'ACTIVE',
} as AuthenticatedUser;

const VERIFIER: AuthenticatedUser = { ...OPS, role: Role.VerificationAdmin };

const GROUP_ID = '11111111-2222-4333-8444-555555555555';
const ASSIGNMENT_ID = '22222222-3333-4444-8555-666666666666';
const VEHICLE_ID = '33333333-4444-4555-8666-777777777777';
const OTHER_VEHICLE_ID = '44444444-5555-4666-8777-888888888888';

function group(overrides: Record<string, unknown> = {}) {
  return {
    id: GROUP_ID,
    referenceCode: 'SD-GRP-2026-000123',
    status: BookingStatus.REQUESTED,
    version: 1,
    city: 'Delhi NCR',
    ceremonyType: 'Baraat',
    serviceStartTime: new Date('2026-11-20T10:00:00Z'),
    serviceEndTime: new Date('2026-11-20T22:00:00Z'),
    estimatedTotalPaise: 3_000_000n,
    advanceTokenPaise: 750_000n,
    pricingSnapshot: null,
    ...overrides,
  };
}

describe('OperationsService', () => {
  let service: OperationsService;
  const prisma: any = {
    groupBooking: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
    },
    groupBookingEvent: { create: jest.fn() },
    vehicleAssignment: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
    },
    vehicle: { findUnique: jest.fn() },
    vehiclePricing: { findFirst: jest.fn() },
    availability: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      deleteMany: jest.fn(),
    },
    driverProfile: { findMany: jest.fn() },
    operationsNote: { create: jest.fn() },
    auditLog: { create: jest.fn() },
    $transaction: jest.fn(async (fn: any) => (typeof fn === 'function' ? fn(prisma) : fn)),
  };
  const groupBookings: any = {
    applyTransition: jest.fn(),
    assertConfirmable: jest.fn(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.availability.findMany.mockResolvedValue([]);
    prisma.availability.findFirst.mockResolvedValue(null);
    prisma.availability.create.mockResolvedValue({});
    prisma.availability.deleteMany.mockResolvedValue({ count: 1 });
    prisma.auditLog.create.mockResolvedValue({});
    prisma.operationsNote.create.mockResolvedValue({
      id: 'note-1',
      body: 'x',
      createdAt: new Date(),
      author: { id: OPS.userId, fullName: 'Ops Control', primaryRole: 'operationsAdmin' },
    });
    groupBookings.assertConfirmable.mockResolvedValue(undefined);
    groupBookings.applyTransition.mockResolvedValue({
      id: GROUP_ID,
      reference_code: 'SD-GRP-2026-000123',
      status: BookingStatus.UNDER_REVIEW,
      version: 2,
    });
    service = new OperationsService(prisma, new BookingStateMachineService(), groupBookings);
  });

  // ------------------------------------------------------------------- queue

  describe('bookingRequestQueue', () => {
    it('reports what is still missing on each request, oldest first', async () => {
      prisma.groupBooking.findMany.mockResolvedValue([
        {
          ...group(),
          createdAt: new Date('2026-09-20T10:00:00Z'),
          customer: { id: 'c1', fullName: 'Aarav', phoneNumber: '+919810000001', accountStatus: 'ACTIVE' },
          requestedFleetItems: [{ vehicleTypeId: 'vt-1', quantity: 3 }],
          communicationPreference: 'WHATSAPP',
          passengerCount: 9,
          requirements: ['Flower decoration'],
          assignments: [
            { id: 'a1', vehicleId: 'v1', driverId: 'd1', assignmentStatus: 'CHAUFFEUR_ASSIGNED' },
            { id: 'a2', vehicleId: 'v2', driverId: null, assignmentStatus: 'PROPOSED' },
            { id: 'a3', vehicleId: 'v3', driverId: null, assignmentStatus: 'PROPOSED' },
          ],
        },
      ]);

      const result = await service.bookingRequestQueue({});

      expect(prisma.groupBooking.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ orderBy: { createdAt: 'asc' } }),
      );
      const item = result.items[0];
      expect(item.fleet_requested).toBe(3);
      expect(item.fleet_assigned).toBe(3);
      expect(item.chauffeurs_assigned).toBe(1);
      expect(item.chauffeurs_missing).toBe(2);
      expect(item.awaiting).toBe('OPERATIONS_CHAUFFEUR');
      expect(item.quote_pending).toBe(false);
      expect(item.estimated_total_paise).toBe('3000000');
      expect(item.age_minutes).toBeGreaterThan(0);
    });

    it('marks a booking as waiting on the CUSTOMER once it is confirmation-pending', async () => {
      prisma.groupBooking.findMany.mockResolvedValue([
        {
          ...group({ status: BookingStatus.CUSTOMER_CONFIRMATION_PENDING }),
          createdAt: new Date(),
          customer: { id: 'c1', fullName: 'Aarav', phoneNumber: '+919810000001', accountStatus: 'ACTIVE' },
          requestedFleetItems: [],
          assignments: [
            { id: 'a1', vehicleId: 'v1', driverId: 'd1', assignmentStatus: 'CHAUFFEUR_ASSIGNED' },
          ],
        },
      ]);
      const result = await service.bookingRequestQueue({});
      expect(result.items[0].awaiting).toBe('CUSTOMER');
      expect(result.items[0].quote_pending).toBe(false);
    });

    it('reports an unpriced booking as quote_pending with a null total (never ₹0)', async () => {
      prisma.groupBooking.findMany.mockResolvedValue([
        {
          ...group({ estimatedTotalPaise: null, advanceTokenPaise: null }),
          createdAt: new Date(),
          customer: { id: 'c1', fullName: 'Aarav', phoneNumber: '+919810000001', accountStatus: 'ACTIVE' },
          requestedFleetItems: [],
          assignments: [],
        },
      ]);
      const result = await service.bookingRequestQueue({});
      expect(result.items[0].quote_pending).toBe(true);
      expect(result.items[0].estimated_total_paise).toBeNull();
    });

    it('defaults to the open pipeline, excluding terminal statuses', async () => {
      prisma.groupBooking.findMany.mockResolvedValue([]);
      await service.bookingRequestQueue({});
      const where = prisma.groupBooking.findMany.mock.calls[0][0].where;
      const statuses = where.status.in as BookingStatus[];
      expect(statuses).toContain(BookingStatus.REQUESTED);
      expect(statuses).toContain(BookingStatus.CUSTOMER_CONFIRMATION_PENDING);
      expect(statuses).not.toContain(BookingStatus.CONFIRMED);
      expect(statuses).not.toContain(BookingStatus.CANCELLED);
      expect(statuses).not.toContain(BookingStatus.COMPLETED);
    });

    it('filters to the awaiting-confirmation queue on demand', async () => {
      prisma.groupBooking.findMany.mockResolvedValue([]);
      await service.bookingRequestQueue({ awaitingConfirmation: true });
      expect(prisma.groupBooking.findMany.mock.calls[0][0].where.status).toBe(
        BookingStatus.CUSTOMER_CONFIRMATION_PENDING,
      );
    });
  });

  // --------------------------------------------------------------- lifecycle

  describe('transition', () => {
    beforeEach(() => {
      prisma.groupBooking.findUnique.mockResolvedValue(group());
    });

    it('404s an unknown booking', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(null);
      await expect(
        service.transition(GROUP_ID, { action: 'BEGIN_REVIEW' }, OPS),
      ).rejects.toMatchObject({ code: 'GROUP_BOOKING_NOT_FOUND' });
    });

    it('refuses an action the actor role is not allowed to perform', async () => {
      await expect(
        service.transition(GROUP_ID, { action: 'BEGIN_REVIEW' }, VERIFIER),
      ).rejects.toThrow(/not permitted/i);
      expect(groupBookings.applyTransition).not.toHaveBeenCalled();
    });

    it('refuses a lifecycle action that does not exist', async () => {
      await expect(
        // @ts-expect-error deliberately invalid action name
        service.transition(GROUP_ID, { action: 'TELEPORT' }, OPS),
      ).rejects.toThrow(/Unknown booking action/i);
    });

    it('requires a reason to cancel, so the customer can be told why', async () => {
      await expect(
        service.transition(GROUP_ID, { action: 'CANCEL' }, OPS),
      ).rejects.toMatchObject({ code: 'VALIDATION_FAILED' });
      expect(groupBookings.applyTransition).not.toHaveBeenCalled();
    });

    it('drives the operations path with the admin identity', async () => {
      await service.transition(GROUP_ID, { action: 'BEGIN_REVIEW' }, OPS);
      expect(groupBookings.applyTransition).toHaveBeenCalledWith(
        expect.objectContaining({
          target: BookingStatus.UNDER_REVIEW,
          action: 'BEGIN_REVIEW',
          actorUserId: OPS.userId,
          actorRole: Role.OperationsAdmin,
        }),
      );
    });

    it('binds CONFIRM_BOOKING to the SHARED fleet-readiness guard', async () => {
      // The guard is not duplicated here: the same check the customer's own
      // confirm tap runs is the one operations must satisfy.
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({ status: BookingStatus.CUSTOMER_CONFIRMATION_PENDING }),
      );
      await service.transition(GROUP_ID, { action: 'CONFIRM_BOOKING' }, OPS);
      expect(groupBookings.assertConfirmable).toHaveBeenCalledWith(GROUP_ID);
    });

    it('surfaces a not-ready fleet instead of confirming it', async () => {
      groupBookings.assertConfirmable.mockRejectedValueOnce(
        Object.assign(new Error('2 vehicle(s) have no chauffeur assigned yet.'), {
          code: 'INVALID_TRANSITION',
        }),
      );
      await expect(
        service.transition(GROUP_ID, { action: 'CONFIRM_BOOKING' }, OPS),
      ).rejects.toThrow(/no chauffeur/i);
      expect(groupBookings.applyTransition).not.toHaveBeenCalled();
    });

    it('does not run the readiness guard for any other action', async () => {
      await service.transition(GROUP_ID, { action: 'BEGIN_REVIEW' }, OPS);
      expect(groupBookings.assertConfirmable).not.toHaveBeenCalled();
    });
  });

  // ------------------------------------------------------------ contact log

  describe('logCustomerContact', () => {
    beforeEach(() => {
      prisma.groupBooking.findUnique.mockResolvedValue(group());
    });

    it('records the attempt as an internal note and an audit row', async () => {
      await service.logCustomerContact(
        GROUP_ID,
        { channel: 'WHATSAPP', outcome: 'NO_ANSWER', note: 'Will try after 5 PM.' },
        OPS,
      );
      expect(prisma.operationsNote.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            groupBookingId: GROUP_ID,
            authorUserId: OPS.userId,
            body: expect.stringContaining('WHATSAPP'),
          }),
        }),
      );
      expect(prisma.auditLog.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ action: 'CUSTOMER_CONTACT_LOGGED' }),
        }),
      );
    });

    it('does NOT move the booking when the customer was not reached', async () => {
      const result = await service.logCustomerContact(
        GROUP_ID,
        { channel: 'PHONE', outcome: 'NO_ANSWER' },
        OPS,
      );
      expect(result.booking_status).toBe(BookingStatus.REQUESTED);
      expect(groupBookings.applyTransition).not.toHaveBeenCalled();
    });

    it('advances to CUSTOMER_CONFIRMATION_PENDING when the customer was reached', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({ status: BookingStatus.VEHICLE_OPTIONS_PREPARED }),
      );
      // First call resolves the booking for the contact log, second for the
      // transition's own lookup.
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({ status: BookingStatus.VEHICLE_OPTIONS_PREPARED }),
      );
      await service.logCustomerContact(
        GROUP_ID,
        { channel: 'PHONE', outcome: 'REACHED', advanceToConfirmation: true },
        OPS,
      );
      expect(groupBookings.applyTransition).toHaveBeenCalledWith(
        expect.objectContaining({ target: BookingStatus.CUSTOMER_CONFIRMATION_PENDING }),
      );
    });
  });

  // ------------------------------------------------------------------ notes

  describe('addNote', () => {
    it('stores an internal note with its author and audits it', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(group());
      const note = await service.addNote(GROUP_ID, 'Need white Thar for groom entry.', OPS);
      expect(note.author.name).toBe('Ops Control');
      expect(prisma.auditLog.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ action: 'OPERATIONS_NOTE_ADDED' }),
        }),
      );
    });
  });

  // ------------------------------------------------------------ reallocation

  describe('reallocateVehicle', () => {
    beforeEach(() => {
      prisma.vehicleAssignment.findUnique.mockResolvedValue({
        id: ASSIGNMENT_ID,
        vehicleId: VEHICLE_ID,
        groupBookingId: GROUP_ID,
        groupBooking: group(),
      });
      prisma.vehicle.findUnique.mockResolvedValue({
        id: OTHER_VEHICLE_ID,
        verificationStatus: 'APPROVED',
        isActive: true,
      });
      prisma.vehicleAssignment.update.mockResolvedValue({
        id: ASSIGNMENT_ID,
        vehicleId: OTHER_VEHICLE_ID,
        assignmentStatus: 'VEHICLE_CONFIRMED',
      });
    });

    it('refuses a vehicle that is not verified and active', async () => {
      prisma.vehicle.findUnique.mockResolvedValue({
        id: OTHER_VEHICLE_ID,
        verificationStatus: 'UNDER_REVIEW',
        isActive: true,
      });
      await expect(
        service.reallocateVehicle(ASSIGNMENT_ID, OTHER_VEHICLE_ID, OPS, 'Original withdrawn.'),
      ).rejects.toThrow(/verified, active vehicle/i);
      expect(prisma.vehicleAssignment.update).not.toHaveBeenCalled();
    });

    it('refuses to double-book a vehicle committed to an overlapping window', async () => {
      prisma.availability.findFirst.mockResolvedValue({ id: 'lock-1' });
      await expect(
        service.reallocateVehicle(ASSIGNMENT_ID, OTHER_VEHICLE_ID, OPS, 'Original withdrawn.'),
      ).rejects.toMatchObject({ code: 'SLOT_DOUBLE_BOOKED' });
    });

    it('swaps the calendar lock and re-confirms the vehicle in one transaction', async () => {
      const result = await service.reallocateVehicle(
        ASSIGNMENT_ID,
        OTHER_VEHICLE_ID,
        OPS,
        'Original withdrawn.',
      );
      expect(prisma.availability.deleteMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: expect.objectContaining({ vehicleId: VEHICLE_ID }) }),
      );
      expect(prisma.availability.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ vehicleId: OTHER_VEHICLE_ID }) }),
      );
      expect(result.assignment_status).toBe('VEHICLE_CONFIRMED');
      expect(prisma.auditLog.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ action: 'VEHICLE_REALLOCATED' }),
        }),
      );
    });

    it('rejects a no-op swap', async () => {
      await expect(
        service.reallocateVehicle(ASSIGNMENT_ID, VEHICLE_ID, OPS),
      ).rejects.toThrow(/already allocated/i);
    });
  });

  // ---------------------------------------------------------- unassignment

  describe('unassignChauffeur', () => {
    it('refuses when nothing is assigned', async () => {
      prisma.vehicleAssignment.findUnique.mockResolvedValue({
        id: ASSIGNMENT_ID,
        vehicleId: VEHICLE_ID,
        driverId: null,
        groupBooking: group(),
      });
      await expect(service.unassignChauffeur(ASSIGNMENT_ID, OPS)).rejects.toThrow(
        /No chauffeur is assigned/i,
      );
    });

    it('releases the chauffeur lock and returns the assignment to vehicle-confirmed', async () => {
      prisma.vehicleAssignment.findUnique.mockResolvedValue({
        id: ASSIGNMENT_ID,
        vehicleId: VEHICLE_ID,
        driverId: 'driver-1',
        groupBooking: group(),
      });
      prisma.vehicleAssignment.update.mockResolvedValue({
        id: ASSIGNMENT_ID,
        driverId: null,
        assignmentStatus: 'VEHICLE_CONFIRMED',
      });
      const result = await service.unassignChauffeur(ASSIGNMENT_ID, OPS);
      expect(prisma.availability.deleteMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: expect.objectContaining({ driverId: 'driver-1' }) }),
      );
      expect(result.driver_id).toBeNull();
    });
  });

  // ------------------------------------------------------- chauffeur picker

  describe('availableChauffeurs', () => {
    it('excludes chauffeurs already committed in an overlapping window', async () => {
      prisma.vehicleAssignment.findUnique.mockResolvedValue({
        id: ASSIGNMENT_ID,
        vehicle: { fleetOwnerId: 'partner-1' },
        groupBooking: group(),
      });
      prisma.availability.findMany.mockResolvedValue([{ driverId: 'busy-driver' }]);
      prisma.driverProfile.findMany.mockResolvedValue([
        {
          id: 'busy-driver',
          licenseNumber: 'DL-1',
          experienceYears: 9,
          languagesSpoken: ['Hindi'],
          averageRating: 4.8,
          totalTripsCompleted: 40,
          dutyStatus: 'OFFLINE',
          fleetOwnerId: 'partner-1',
          user: { fullName: 'Busy', phoneNumber: '+919000000001', accountStatus: 'ACTIVE' },
          fleetOwner: { id: 'partner-1', companyName: 'Fleur Chauffeurs' },
        },
        {
          id: 'free-driver',
          licenseNumber: 'DL-2',
          experienceYears: 4,
          languagesSpoken: ['Hindi', 'English'],
          averageRating: 4.9,
          totalTripsCompleted: 12,
          dutyStatus: 'ONLINE',
          fleetOwnerId: 'partner-1',
          user: { fullName: 'Free', phoneNumber: '+919000000002', accountStatus: 'ACTIVE' },
          fleetOwner: { id: 'partner-1', companyName: 'Fleur Chauffeurs' },
        },
      ]);

      const result = await service.availableChauffeurs(ASSIGNMENT_ID);
      expect(result.items.map((c) => c.id)).toEqual(['free-driver']);
      expect(result.items[0].same_partner_as_vehicle).toBe(true);
      expect(prisma.driverProfile.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { verificationStatus: 'APPROVED' } }),
      );
    });
  });

  // ----------------------------------------------------------------- quote

  describe('requote', () => {
    const approvedTariff = {
      id: 'pricing-1',
      version: 2,
      localIncludedKm: 45,
      localAmountPaise: 300_000n,
      perKmPaise: 2_300n,
      hourlyPaise: 80_000n,
      extraHourPaise: 70_000n,
      fullDayPaise: 1_200_000n,
      overnightPaise: 1_500_000n,
      outstationPerDayPaise: null,
      outstationPerKmPaise: null,
    };

    beforeEach(() => {
      prisma.groupBooking.update.mockResolvedValue({
        id: GROUP_ID,
        estimatedTotalPaise: 2_400_000n,
        advanceTokenPaise: 600_000n,
      });
      prisma.vehicleAssignment.update.mockResolvedValue({});
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({
          assignments: [
            { id: 'a1', vehicleId: VEHICLE_ID, vehicle: { fleetCode: 'SD-VH-0001' } },
            { id: 'a2', vehicleId: OTHER_VEHICLE_ID, vehicle: { fleetCode: 'SD-VH-0002' } },
          ],
        }),
      );
    });

    it('re-prices from the vehicles actually allocated at their approved tariffs', async () => {
      prisma.vehiclePricing.findFirst.mockResolvedValue(approvedTariff);
      const result = await service.requote(GROUP_ID, { reason: 'Final quote.' }, OPS);

      // 12h window → overnight rate on each of two vehicles.
      expect(result.estimated_total_paise).toBe('3000000');
      expect(result.advance_token_paise).toBe('750000');
      expect(result.quote_pending).toBe(false);
      expect(prisma.vehiclePricing.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({ where: { vehicleId: VEHICLE_ID, status: 'APPROVED' } }),
      );
    });

    it('adds a per-km surcharge only beyond the tariff’s included distance', async () => {
      prisma.vehiclePricing.findFirst.mockResolvedValue(approvedTariff);
      // 60 km declared − 45 km included = 15 billable km × ₹23 = ₹345 per car.
      await service.requote(GROUP_ID, { routeDistanceKm: 60 }, OPS);

      const line = prisma.vehicleAssignment.update.mock.calls[0][0].data;
      expect(line.pricingSnapshot.billable_km).toBe(15);
      expect(line.pricingSnapshot.surcharge_paise).toBe('34500');
    });

    it('keeps the price PENDING when an allocated vehicle has no approved tariff', async () => {
      prisma.vehiclePricing.findFirst
        .mockResolvedValueOnce(approvedTariff)
        .mockResolvedValueOnce(null);
      prisma.groupBooking.update.mockResolvedValue({
        id: GROUP_ID,
        estimatedTotalPaise: null,
        advanceTokenPaise: null,
      });
      const result = await service.requote(GROUP_ID, {}, OPS);
      expect(result.quote_pending).toBe(true);
      expect(result.estimated_total_paise).toBeNull();
      expect(result.unpriced_vehicle_ids).toEqual([OTHER_VEHICLE_ID]);
    });

    it('retains the superseded snapshot so an agreed price stays reconstructable', async () => {
      prisma.vehiclePricing.findFirst.mockResolvedValue(approvedTariff);
      prisma.groupBooking.findUnique.mockResolvedValue(
        group({
          pricingSnapshot: { source: 'TARIFF_AUTO', total_paise: '2000000' },
          assignments: [{ id: 'a1', vehicleId: VEHICLE_ID, vehicle: { fleetCode: 'SD-VH-0001' } }],
        }),
      );
      await service.requote(GROUP_ID, {}, OPS);

      const data = prisma.groupBooking.update.mock.calls[0][0].data;
      expect(data.pricingSnapshot.supersedes).toEqual({
        source: 'TARIFF_AUTO',
        total_paise: '2000000',
      });
      expect(prisma.auditLog.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ action: 'BOOKING_REQUOTED' }),
        }),
      );
    });

    it('refuses to quote a booking with nothing allocated', async () => {
      prisma.groupBooking.findUnique.mockResolvedValue(group({ assignments: [] }));
      await expect(service.requote(GROUP_ID, {}, OPS)).rejects.toThrow(
        /no vehicles are allocated/i,
      );
    });
  });
});
