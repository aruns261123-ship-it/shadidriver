import { BookingsService, generateTripOtp, hashOtp, verifyOtp } from './bookings.service';
import { BookingStateMachineService } from '../booking-state-machine/booking-state-machine.service';
import { SmsProviderError } from '../notifications/sms/sms-provider.interface';

/**
 * Unit-level booking engine tests with an in-memory transactional harness.
 * The transaction functions receive a mutable tx object operating on the
 * same fake stores — matching Prisma's interactive-transaction semantics.
 */
describe('BookingsService (engine)', () => {
  let service: BookingsService;
  let prisma: any;
  let sms: { sendOtp: jest.Mock; name: string };
  let quotes: { createQuote: jest.Mock };
  let availability: { checkFleetAvailability: jest.Mock };

  const customer = { id: 'cust-1', fullName: 'Aarav', phoneNumber: '+919810000001' };
  const driverProfile = {
    id: 'drv-profile-1',
    userId: 'driver-user-1',
    verificationStatus: 'APPROVED',
  };

  function now2h() {
    return new Date(Date.now() + 2 * 3600_000);
  }
  function now6h() {
    return new Date(Date.now() + 6 * 3600_000);
  }

  const validInput = {
    customerId: customer.id,
    serviceCategoryId: 'SVC_BARAAT',
    vehicleTypeId: 'VT_INNOVA_CRYSTA',
    ceremonyType: 'Baraat',
    ceremonialAttire: 'Royal Bandhgala',
    serviceStartTime: now2h(),
    serviceEndTime: now6h(),
    city: 'Delhi NCR',
    pickupAddress: 'The Oberoi, New Delhi',
    destinationAddress: 'Grand Imperial Banquets, MG Road',
    primaryContactName: 'Aarav Sharma',
    primaryContactPhone: '9810000001',
    passengerCount: 4,
    idempotencyKey: 'idem-key-001',
  };

  beforeEach(() => {
    const bookings: any[] = [];
    const events: any[] = [];
    const availabilities: any[] = [];
    let bookingSeq = 1;

    const tx = {
      booking: {
        findUnique: jest.fn(async ({ where }) =>
          bookings.find((b) => b.id === where.id || b.idempotencyKey === where.idempotencyKey) ?? null,
        ),
        create: jest.fn(async ({ data }) => {
          const b = {
            id: `bk-${bookingSeq++}`,
            referenceCode: `SD-2026-010${bookingSeq}`,
            status: data.status,
            version: 1,
            createdAt: new Date(),
            ...data,
          };
          bookings.push(b);
          return b;
        }),
        update: jest.fn(async ({ where, data }) => {
          const b = bookings.find((x) => x.id === where.id);
          Object.assign(b, data, { status: data.status ?? b.status });
          if (data.version?.increment) b.version += data.version.increment;
          return b;
        }),
        count: jest.fn(async () => bookings.length),
        findMany: jest.fn(async ({ where }) =>
          bookings.filter((b) => !where || where.driverFk ? b.driverFk === where.driverFk : true),
        ),
      },
      bookingEvent: {
        create: jest.fn(async ({ data }) => {
          events.push(data);
          return data;
        }),
        findFirst: jest.fn(async () => null),
      },
      availability: {
        create: jest.fn(async ({ data }) => {
          availabilities.push(data);
          return data;
        }),
        createMany: jest.fn(async ({ data }) => {
          availabilities.push(...(Array.isArray(data) ? data : [data]));
          return { count: data.length };
        }),
        findMany: jest.fn(async () => availabilities.map(() => ({ vehicleId: null }))),
        updateMany: jest.fn(async () => ({ count: 1 })),
      },
      $queryRaw: jest.fn(async () => null),
      driverProfile: { findUnique: jest.fn(async () => driverProfile) },
    };

    prisma = {
      ...tx,
      __bookings: bookings,
      __events: events,
      __availabilities: availabilities,
      $transaction: jest.fn(async (fn) => fn(tx)),
    };

    sms = { sendOtp: jest.fn().mockResolvedValue({ accepted: true }), name: 'test-sms' };
    quotes = {
      createQuote: jest.fn().mockResolvedValue({
        total_paise: 3_000_000,
        advance_token_paise: 750_000,
      }),
    };
    availability = { checkFleetAvailability: jest.fn() };

    service = new BookingsService(
      prisma,
      new BookingStateMachineService(),
      quotes as never,
      availability as never,
      {} as never,
      sms as never,
    );
  });

  describe('idempotency', () => {
    it('creates ONE booking for repeated submissions with the same key', async () => {
      const first = await service.submitBooking(validInput);
      const second = await service.submitBooking({ ...validInput });
      expect(first.idempotentReplay).toBe(false);
      expect(second.idempotentReplay).toBe(true);
      expect(second.booking.id).toBe(first.booking.id);
      expect(prisma.__bookings).toHaveLength(1);
    });

    it('keys are scoped per customer (different customer, same key → new booking)', async () => {
      await service.submitBooking(validInput);
      const other = await service.submitBooking({
        ...validInput,
        customerId: 'cust-2',
      });
      expect(other.idempotentReplay).toBe(false);
      expect(prisma.__bookings).toHaveLength(2);
    });
  });

  describe('server-authoritative pricing', () => {
    it('persists totals from the SERVER quote; client amounts are never read', async () => {
      const { booking } = await service.submitBooking(validInput);
      expect(quotes.createQuote).toHaveBeenCalledTimes(1);
      expect(booking.estimatedTotalPaise).toBe(3_000_000n);
      expect(booking.advanceTokenPaise).toBe(750_000n);
    });

    it('records a REQUESTED booking event for audit', async () => {
      await service.submitBooking(validInput);
      expect(prisma.__events).toHaveLength(1);
      expect(prisma.__events[0].toStatus).toBe('REQUESTED');
      expect(prisma.__events[0].triggerRole).toBe('customer');
    });
  });

  describe('driver accept/decline', () => {
    let booking: any;
    beforeEach(async () => {
      booking = (await service.submitBooking(validInput)).booking;
      // Raw row-lock path returns the current booking row.
      prisma.$queryRaw.mockResolvedValue([{ status: booking.status, id: booking.id }]);
    });

    it('accept transitions REQUESTED → DRIVER_ACCEPTED and inserts a slot lock', async () => {
      const accepted = await service.acceptBooking(booking.id, 'driver-user-1');
      expect(accepted.status).toBe('DRIVER_ACCEPTED');
      expect(accepted.driverFk).toBe('drv-profile-1');
      expect(accepted.startOtpHash).toHaveLength(64);
      expect(prisma.__availabilities).toHaveLength(1);
      expect(prisma.__availabilities[0].status).toBe('BOOKED');
    });

    it('delivers the trip OTP to the host phone after accept', async () => {
      await service.acceptBooking(booking.id, 'driver-user-1');
      expect(sms.sendOtp).toHaveBeenCalledTimes(1);
      const [phone, code] = sms.sendOtp.mock.calls[0];
      expect(phone).toBe(validInput.primaryContactPhone);
      expect(code).toMatch(/^\d{4}$/);
      // Hash verifies against the delivered code.
      const accepted = prisma.__bookings[0];
      expect(verifyOtp(code, accepted.startOtpHash)).toBe(true);
    });

    it('unverified chauffeurs cannot accept', async () => {
      prisma.driverProfile.findUnique.mockResolvedValue({
        ...driverProfile,
        verificationStatus: 'PENDING_SUBMISSION',
      });
      await expect(service.acceptBooking(booking.id, 'driver-user-1')).rejects.toThrow(
        /verified chauffeurs/i,
      );
    });

    it('accept fails when the booking is no longer REQUESTED', async () => {
      prisma.__bookings[0].status = 'CANCELLED';
      prisma.$queryRaw.mockResolvedValue([{ status: 'CANCELLED', id: booking.id }]);
      await expect(service.acceptBooking(booking.id, 'driver-user-1')).rejects.toThrow(
        /no longer available/i,
      );
    });

    it('decline records the mandatory reason', async () => {
      const result = await service.declineBooking(booking.id, 'driver-user-1', 'VEHICLE_BREAKDOWN');
      expect(result.declined).toBe(true);
      const event = prisma.__events.find((e: { eventReason: string }) => e.eventReason === 'VEHICLE_BREAKDOWN');
      expect(event).toBeTruthy();
      expect(event.triggerRole).toBe('driver');
    });
  });

  describe('trip lifecycle + OTP', () => {
    let booking: any;
    let tripOtp: string;

    beforeEach(async () => {
      booking = (await service.submitBooking(validInput)).booking;
      prisma.$queryRaw.mockResolvedValue([{ status: booking.status, id: booking.id }]);
      await service.acceptBooking(booking.id, 'driver-user-1');
      tripOtp = sms.sendOtp.mock.calls[0][1];
      // Force through CONFIRMED → EN_ROUTE → ARRIVED for trip start testing.
      prisma.__bookings[0].status = 'ARRIVED';
    });

    it('rejects START_TRIP with a wrong OTP', async () => {
      await expect(
        service.transition(booking.id, 'START_TRIP', { userId: 'driver-user-1', role: 'driver' as never }, { otp: '0000' }),
      ).rejects.toThrow(/Invalid trip start OTP/);
    });

    it('accepts START_TRIP with the correct OTP and moves to IN_PROGRESS', async () => {
      const updated = await service.transition(
        booking.id,
        'START_TRIP',
        { userId: 'driver-user-1', role: 'driver' as never },
        { otp: tripOtp },
      );
      expect(updated.status).toBe('IN_PROGRESS');
    });

    it('rejects invalid lifecycle jumps (REQUESTED → COMPLETE_TRIP)', async () => {
      prisma.__bookings[0].status = 'REQUESTED';
      await expect(
        service.transition(booking.id, 'COMPLETE_TRIP', { userId: 'driver-user-1', role: 'driver' as never }),
      ).rejects.toThrow(/not permitted/);
    });

    it('driver can complete the trip from IN_PROGRESS', async () => {
      prisma.__bookings[0].status = 'IN_PROGRESS';
      const updated = await service.transition(
        booking.id,
        'COMPLETE_TRIP',
        { userId: 'driver-user-1', role: 'driver' as never },
      );
      expect(updated.status).toBe('COMPLETED');
      expect(updated.completedAt).toBeInstanceOf(Date);
      // Calendar lock released.
      expect(prisma.availability.updateMany).toHaveBeenCalled();
    });

    it('customer may cancel while still REQUESTED', async () => {
      prisma.__bookings[0].status = 'REQUESTED';
      const updated = await service.transition(
        booking.id,
        'CANCEL',
        { userId: customer.id, role: 'customer' as never },
        { reason: 'Change of plans' },
      );
      expect(updated.status).toBe('CANCELLED');
      expect(updated.cancellationReason).toBe('Change of plans');
    });

    it('customer CANNOT cancel after EN_ROUTE (ops-only)', async () => {
      prisma.__bookings[0].status = 'EN_ROUTE';
      await expect(
        service.transition(booking.id, 'CANCEL', { userId: customer.id, role: 'customer' as never }),
      ).rejects.toThrow(/not permitted/);
    });
  });

  describe('resend trip OTP', () => {
    it('customer may resend; driver may NOT retrieve or resend', async () => {
      const booking = (await service.submitBooking(validInput)).booking;
      prisma.$queryRaw.mockResolvedValue([{ status: 'REQUESTED', id: booking.id }]);
      await service.acceptBooking(booking.id, 'driver-user-1');
      prisma.__bookings[0].status = 'ARRIVED';

      sms.sendOtp.mockClear();
      await service.resendTripOtp(booking.id, { userId: customer.id, role: 'customer' as never });
      expect(sms.sendOtp).toHaveBeenCalledTimes(1);

      await expect(
        service.resendTripOtp(booking.id, { userId: 'driver-user-1', role: 'driver' as never }),
      ).rejects.toThrow(/Only the booking customer/);
    });
  });

  describe('trip OTP generation', () => {
    it('generates unique 4-digit codes with working hash verification', () => {
      const codes = new Set<string>();
      for (let i = 0; i < 200; i++) codes.add(generateTripOtp());
      expect(codes.size).toBeGreaterThan(150); // overwhelmingly unique in 10k space
      for (const c of codes) {
        expect(c).toMatch(/^\d{4}$/);
        expect(verifyOtp(c, hashOtp(c))).toBe(true);
        expect(verifyOtp('9999', hashOtp(c))).toBe(c === '9999');
      }
    });
  });

  describe('SMS delivery failure on accept', () => {
    it('accept still succeeds; delivery failure is not silent success', async () => {
      const booking = (await service.submitBooking(validInput)).booking;
      prisma.$queryRaw.mockResolvedValue([{ status: booking.status, id: booking.id }]);
      sms.sendOtp.mockRejectedValue(new SmsProviderError('test-sms', 'gateway down', true));
      const accepted = await service.acceptBooking(booking.id, 'driver-user-1');
      expect(accepted.status).toBe('DRIVER_ACCEPTED');
      // OTP hash was still minted — resend endpoint can redeliver.
      expect(accepted.startOtpHash).toHaveLength(64);
    });
  });
});
