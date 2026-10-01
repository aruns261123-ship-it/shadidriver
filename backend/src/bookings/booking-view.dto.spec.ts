import { AdminBookingDto, CustomerBookingDto, DriverAssignmentDto } from './booking-view.dto';

const baseBooking = {
  id: 'bk-1',
  referenceCode: 'SD-2026-0101',
  ceremonyType: 'Baraat',
  city: 'Delhi NCR',
  serviceStartTime: new Date('2026-10-05T10:00:00Z'),
  serviceEndTime: new Date('2026-10-05T14:00:00Z'),
  pickupAddress: 'The Oberoi, New Delhi',
  destinationAddress: 'Grand Banquets, MG Road',
  passengerCount: 4,
  estimatedTotalPaise: 3_000_000n,
  advanceTokenPaise: 750_000n,
  isAdvancePaid: false,
  status: 'CONFIRMED',
  tripType: 'ROUND_TRIP',
  customer: { id: 'cust-1', fullName: 'Aarav Sharma', phoneNumber: '+919810000001' },
  driver: {
    id: 'drv-1',
    user: { fullName: 'Rajesh Kumar', phoneNumber: '+919810000002' },
  },
  events: [
    {
      fromStatus: 'REQUESTED',
      toStatus: 'DRIVER_ACCEPTED',
      eventReason: 'Operations allocated a chauffeur',
      createdAt: new Date(),
      eventMetadata: { driverId: 'drv-1' },
    },
  ],
} as never;

describe('role-scoped booking views (privacy)', () => {
  it('customer view NEVER exposes driver identity or internal events', () => {
    const view = CustomerBookingDto.from(baseBooking);
    const json = JSON.stringify(view);
    expect(json).not.toContain('Rajesh Kumar');
    expect(json).not.toContain('+919810000002');
    expect(json).not.toContain('drv-1');
    expect(json).not.toContain('events');
    // The platform stands behind the service instead:
    expect(view.chauffeur_verification).toMatch(/verified by ShadiDriver/i);
    expect(view.driver).toBeNull();
  });

  it('customer view carries the booking facts the customer owns', () => {
    const view = CustomerBookingDto.from(baseBooking);
    expect(view.reference_code).toBe('SD-2026-0101');
    expect(view.trip_type).toBe('ROUND_TRIP');
    expect(view.estimated_total_paise).toBe('3000000');
    expect(view.status).toBe('CONFIRMED');
  });

  it('customer view of an unallocated booking explains operations is arranging', () => {
    const view = CustomerBookingDto.from({
      ...(baseBooking as unknown as Record<string, unknown>),
      driver: null,
    } as never);
    expect(view.chauffeur_verification).toMatch(/operations is arranging/i);
  });

  it('driver view exposes the operational minimum for an authorized duty', () => {
    const view = DriverAssignmentDto.from(baseBooking);
    expect(view.host_name).toBe('Aarav Sharma');
    expect(view.host_phone).toBe('+919810000001');
    expect(view.pickup_address).toBe('The Oberoi, New Delhi');
    // No pricing, no audit trail.
    const json = JSON.stringify(view);
    expect(json).not.toContain('estimated_total_paise');
    expect(json).not.toContain('events');
  });

  it('admin view is the full operational picture', () => {
    const view = AdminBookingDto.from(baseBooking);
    expect(view.customer.phone).toBe('+919810000001');
    expect(view.assigned_chauffeur?.name).toBe('Rajesh Kumar');
    expect(view.assigned_chauffeur?.phone).toBe('+919810000002');
    expect(view.events).toHaveLength(1);
  });
});
