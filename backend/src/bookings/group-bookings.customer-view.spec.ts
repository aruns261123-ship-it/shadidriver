import {
  CUSTOMER_FORBIDDEN_ASSIGNMENT_KEYS,
  serializeCustomerGroupBooking,
} from './group-bookings.service';
import { BookingStateMachineService } from '../booking-state-machine/booking-state-machine.service';
import { BookingStatus } from '../booking-state-machine/booking-status';

function source(overrides: Partial<Parameters<typeof serializeCustomerGroupBooking>[0]> = {}) {
  return {
    id: 'grp-1',
    referenceCode: 'SD-GRP-2026-000123',
    ceremonyType: 'Baraat',
    city: 'Delhi NCR',
    pickupAddress: 'Sector 15, Gurugram',
    destinationAddress: 'The Leela Palace, New Delhi',
    serviceStartTime: new Date('2026-11-20T10:00:00Z'),
    serviceEndTime: new Date('2026-11-20T22:00:00Z'),
    passengerCount: 7,
    status: BookingStatus.REQUESTED,
    estimatedTotalPaise: 3_000_000n,
    advanceTokenPaise: 750_000n,
    requirements: ['Wedding decoration'],
    communicationPreference: 'WHATSAPP',
    requestedFleetItems: [{ vehicleTypeId: 'VT_THAR', quantity: 2 }],
    assignments: [
      {
        id: 'asg-1',
        sequenceNumber: 1,
        assignmentStatus: 'CHAUFFEUR_ASSIGNED',
        requestedModel: 'Mahindra Thar',
        estimatedTotalPaise: 3_000_000n,
        advanceTokenPaise: 750_000n,
        vehicle: {
          id: 'veh-1',
          fleetCode: 'SD-VH-0001',
          // Registration plate is internal: the customer must never receive it.
          registrationNumber: 'DL01AB1234',
          vehicleType: { displayName: 'Mahindra Thar' },
        },
      },
    ],
    ...overrides,
  };
}

describe('customer-facing group booking payload', () => {
  it('carries every field the booking screens need', () => {
    const view = serializeCustomerGroupBooking(source());

    expect(view.reference_code).toBe('SD-GRP-2026-000123');
    expect(view.pickup_address).toBe('Sector 15, Gurugram');
    expect(view.destination_address).toBe('The Leela Palace, New Delhi');
    expect(view.passenger_count).toBe(7);
    expect(view.requirements).toEqual(['Wedding decoration']);
    expect(view.communication_preference).toBe('WHATSAPP');
    expect(view.requested_fleet).toEqual([{ vehicleTypeId: 'VT_THAR', quantity: 2 }]);
    expect(view.estimated_total_paise).toBe('3000000');
    expect(view.assignments).toHaveLength(1);
  });

  it('never exposes chauffeur or partner identity', () => {
    const view = serializeCustomerGroupBooking(source());
    const payload = JSON.stringify(view);

    for (const key of CUSTOMER_FORBIDDEN_ASSIGNMENT_KEYS) {
      expect(collectKeys(view)).not.toContain(key);
    }
    expect(payload).not.toContain('DL01AB1234');
  });

  it('never exposes the internal tariff derivation behind the price', () => {
    const withSnapshot = source({
      assignments: [
        {
          ...source().assignments[0],
          // The service does not load this, but the serializer must be safe even
          // if a future include accidentally brings it along.
          pricingSnapshot: {
            tariff_id: 'pricing-9',
            tariff_version: 4,
            billable_hours: 12,
            basis: 'OVERNIGHT',
          },
        } as never,
      ],
    });
    const view = serializeCustomerGroupBooking(withSnapshot);
    const keys = collectKeys(view);

    for (const key of ['pricing_snapshot', 'tariff_id', 'tariff_version', 'billable_hours']) {
      expect(keys).not.toContain(key);
    }
  });

  it('reports an unquoted booking honestly as quote_pending, never ₹0', () => {
    const view = serializeCustomerGroupBooking(
      source({ estimatedTotalPaise: null, advanceTokenPaise: null }),
    );
    expect(view.estimated_total_paise).toBeNull();
    expect(view.advance_token_paise).toBeNull();
    expect(view.quote_pending).toBe(true);
  });

  it('reports a priced booking as not pending', () => {
    const view = serializeCustomerGroupBooking(source());
    expect(view.quote_pending).toBe(false);
  });

  it('carries the version so the customer can be told their view is stale', () => {
    const view = serializeCustomerGroupBooking(source({ version: 7 }));
    expect(view.version).toBe(7);
  });

  it('reduces internal assignment progress to a neutral service state', () => {
    const states = [
      ['PROPOSED', 'BEING_PREPARED'],
      ['VEHICLE_CONFIRMED', 'BEING_PREPARED'],
      ['CHAUFFEUR_ASSIGNED', 'BEING_PREPARED'],
      ['CHAUFFEUR_ACCEPTED', 'BEING_PREPARED'],
      ['EN_ROUTE', 'ON_THE_WAY'],
      ['ARRIVED', 'ARRIVED'],
      ['IN_PROGRESS', 'IN_SERVICE'],
      ['COMPLETED', 'COMPLETED'],
      ['CANCELLED', 'CANCELLED'],
    ] as const;

    for (const [internal, visible] of states) {
      const view = serializeCustomerGroupBooking(
        source({
          assignments: [{ ...source().assignments[0], assignmentStatus: internal }],
        }),
      );
      expect(view.assignments[0].service_state).toBe(visible);
    }
  });

  it('a chauffeur decline is invisible as churn to the customer', () => {
    const declined = serializeCustomerGroupBooking(
      source({
        assignments: [{ ...source().assignments[0], assignmentStatus: 'CHAUFFEUR_DECLINED' }],
      }),
    );
    // The customer sees no failure — operations is simply still preparing it.
    expect(declined.assignments[0].service_state).toBe('BEING_PREPARED');
    expect(declined.assignments[0].chauffeur_assigned).toBe(false);
  });

  it('reports chauffeur_assigned as a boolean flag, never an identity', () => {
    const view = serializeCustomerGroupBooking(source());
    expect(view.assignments[0].chauffeur_assigned).toBe(true);
    expect(typeof view.assignments[0].chauffeur_assigned).toBe('boolean');
  });
});

describe('operations-managed lifecycle', () => {
  const sm = new BookingStateMachineService();

  it('a chauffeur can never move a customer request out of REQUESTED', () => {
    for (const action of ['BEGIN_REVIEW', 'PREPARE_VEHICLE_OPTIONS', 'CONFIRM_BOOKING']) {
      expect(() =>
        sm.assertTransitionAllowed(BookingStatus.REQUESTED, action, 'driver'),
      ).toThrow(/not permitted/i);
    }
  });

  it('walks the full operations path: REQUESTED → … → CONFIRMED', () => {
    let status: BookingStatus = BookingStatus.REQUESTED;
    const path: Array<[string, Parameters<typeof sm.assertTransitionAllowed>[2]]> = [
      ['BEGIN_REVIEW', 'operationsAdmin'],
      ['PREPARE_VEHICLE_OPTIONS', 'operationsAdmin'],
      ['REQUEST_CUSTOMER_CONFIRMATION', 'operationsAdmin'],
      ['CONFIRM_BOOKING', 'customer'],
    ];
    for (const [action, actor] of path) {
      status = sm.assertTransitionAllowed(status, action, actor);
    }
    expect(status).toBe(BookingStatus.CONFIRMED);
  });

  it('the customer can send a proposal back for revision instead of accepting', () => {
    expect(
      sm.assertTransitionAllowed(
        BookingStatus.CUSTOMER_CONFIRMATION_PENDING,
        'REVISE_OPTIONS',
        'customer',
      ),
    ).toBe(BookingStatus.UNDER_REVIEW);
  });

  it('payment settles a PAYMENT_PENDING booking into CONFIRMED', () => {
    expect(
      sm.assertTransitionAllowed(BookingStatus.PAYMENT_PENDING, 'CONFIRM_PAYMENT', 'SYSTEM'),
    ).toBe(BookingStatus.CONFIRMED);
  });

  it('an unpaid request can expire without ever being confirmed', () => {
    expect(
      sm.assertTransitionAllowed(BookingStatus.REQUESTED, 'EXPIRE', 'SYSTEM'),
    ).toBe(BookingStatus.EXPIRED);
    expect(sm.isTerminal(BookingStatus.EXPIRED)).toBe(true);
  });

  it('a failed payment is not terminal — the customer may retry', () => {
    expect(sm.isTerminal(BookingStatus.PAYMENT_FAILED)).toBe(false);
    expect(
      sm.assertTransitionAllowed(BookingStatus.PAYMENT_FAILED, 'RETRY_PAYMENT', 'customer'),
    ).toBe(BookingStatus.PAYMENT_PENDING);
  });
});

function collectKeys(value: unknown): string[] {
  if (Array.isArray(value)) return value.flatMap(collectKeys);
  if (value && typeof value === 'object') {
    return Object.entries(value as Record<string, unknown>).flatMap(([k, v]) => [
      k,
      ...collectKeys(v),
    ]);
  }
  return [];
}
