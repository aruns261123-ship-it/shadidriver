import { BookingStateMachineService } from './booking-state-machine.service';
import { BookingStatus, TRANSITIONS, TERMINAL_STATUSES } from './booking-status';

describe('BookingStateMachineService', () => {
  let service: BookingStateMachineService;

  beforeEach(() => {
    service = new BookingStateMachineService();
  });

  describe('happy-path lifecycle', () => {
    it('driver accepts a requested booking', () => {
      expect(
        service.assertTransitionAllowed(BookingStatus.REQUESTED, 'ACCEPT', 'driver'),
      ).toBe(BookingStatus.DRIVER_ACCEPTED);
    });

    it('payment confirmation moves DRIVER_ACCEPTED → CONFIRMED', () => {
      expect(
        service.assertTransitionAllowed(BookingStatus.DRIVER_ACCEPTED, 'CONFIRM_PAYMENT', 'SYSTEM'),
      ).toBe(BookingStatus.CONFIRMED);
    });

    it('driver proceeds CONFIRMED → EN_ROUTE → ARRIVED → IN_PROGRESS → COMPLETED', () => {
      expect(
        service.assertTransitionAllowed(BookingStatus.CONFIRMED, 'START_ROUTE', 'driver'),
      ).toBe(BookingStatus.EN_ROUTE);
      expect(
        service.assertTransitionAllowed(BookingStatus.EN_ROUTE, 'ARRIVE', 'driver'),
      ).toBe(BookingStatus.ARRIVED);
      expect(
        service.assertTransitionAllowed(BookingStatus.ARRIVED, 'START_TRIP', 'driver'),
      ).toBe(BookingStatus.IN_PROGRESS);
      expect(
        service.assertTransitionAllowed(BookingStatus.IN_PROGRESS, 'COMPLETE_TRIP', 'driver'),
      ).toBe(BookingStatus.COMPLETED);
    });

    it('customer may cancel while REQUESTED', () => {
      expect(
        service.assertTransitionAllowed(BookingStatus.REQUESTED, 'CANCEL', 'customer'),
      ).toBe(BookingStatus.CANCELLED);
    });
  });

  describe('invalid transitions are rejected (server-side)', () => {
    it('cannot jump REQUESTED → CONFIRMED (payment before acceptance)', () => {
      expect(() =>
        service.assertTransitionAllowed(BookingStatus.REQUESTED, 'CONFIRM_PAYMENT', 'SYSTEM'),
      ).toThrow(/not permitted/);
    });

    it('CONFIRMED → IN_PROGRESS is now the MANAGED trip edge (per-vehicle ladder carries progress)', () => {
      // On the operations-managed path the chauffeur's per-vehicle milestones
      // (AssignmentStatus) own the progress; the parent booking flips to
      // IN_PROGRESS when service begins. The legacy EN_ROUTE staging lives only
      // on old single-booking rows.
      expect(
        service.assertTransitionAllowed(BookingStatus.CONFIRMED, 'START_TRIP', 'driver'),
      ).toBe(BookingStatus.IN_PROGRESS);
      expect(() =>
        service.assertTransitionAllowed(BookingStatus.CUSTOMER_CONFIRMATION_PENDING, 'START_TRIP', 'driver'),
      ).toThrow(/not permitted/);
      expect(() =>
        service.assertTransitionAllowed(BookingStatus.UNDER_REVIEW, 'START_TRIP', 'driver'),
      ).toThrow(/not permitted/);
    });

    it('client cannot force COMPLETED directly from REQUESTED', () => {
      expect(() =>
        service.assertTransitionAllowed(BookingStatus.REQUESTED, 'COMPLETE_TRIP', 'driver'),
      ).toThrow(/not permitted/);
    });

    it('terminal bookings reject every action', () => {
      for (const terminal of TERMINAL_STATUSES) {
        expect(() =>
          service.assertTransitionAllowed(terminal, 'ACCEPT', 'driver'),
        ).toThrow(/not permitted/);
        expect(() =>
          service.assertTransitionAllowed(terminal, 'CANCEL', 'operationsAdmin'),
        ).toThrow(/not permitted/);
      }
    });

    it('unknown actions are rejected', () => {
      expect(() => service.resolveTarget('MAGIC_JUMP')).toThrow(/Unknown booking action/);
    });
  });

  describe('actor enforcement', () => {
    it('customer cannot ACCEPT their own booking', () => {
      expect(() =>
        service.assertTransitionAllowed(BookingStatus.REQUESTED, 'ACCEPT', 'customer'),
      ).toThrow(/not permitted/);
    });

    it('driver cannot CANCEL a customer booking pre-assignment', () => {
      expect(() =>
        service.assertTransitionAllowed(BookingStatus.REQUESTED, 'CANCEL', 'driver'),
      ).toThrow(/not permitted/);
    });

    it('only driver may START_ROUTE on a confirmed booking', () => {
      expect(() =>
        service.assertTransitionAllowed(BookingStatus.CONFIRMED, 'START_ROUTE', 'customer'),
      ).toThrow(/not permitted/);
      expect(
        service.assertTransitionAllowed(BookingStatus.CONFIRMED, 'START_ROUTE', 'driver'),
      ).toBe(BookingStatus.EN_ROUTE);
    });

    it('customers may not cancel once EN_ROUTE (ops-only)', () => {
      expect(() =>
        service.assertTransitionAllowed(BookingStatus.EN_ROUTE, 'CANCEL', 'customer'),
      ).toThrow(/not permitted/);
      expect(
        service.assertTransitionAllowed(BookingStatus.EN_ROUTE, 'CANCEL', 'operationsAdmin'),
      ).toBe(BookingStatus.CANCELLED);
    });
  });

  describe('optimistic locking', () => {
    it('version mismatch raises VERSION_CONFLICT', () => {
      expect(() => service.assertVersionMatches(4, 3)).toThrow(/modified concurrently/);
    });

    it('matching versions pass', () => {
      expect(() => service.assertVersionMatches(4, 4)).not.toThrow();
    });
  });

  describe('transition table integrity', () => {
    it('every transition has at least one authorized actor', () => {
      for (const t of TRANSITIONS) {
        expect(t.actors.length).toBeGreaterThan(0);
      }
    });

    it('every status reachable as `to` has a defined `from` state; DRAFT is a local-only state', () => {
      const froms = new Set(TRANSITIONS.map((t) => t.from));
      for (const t of TRANSITIONS) {
        // DRAFT has no outgoing transitions yet (draft flows land in Phase 5);
        // every other referenced status must exist in the enum.
        expect(Object.values(BookingStatus)).toContain(t.to);
        expect(Object.values(BookingStatus)).toContain(t.from);
        expect(froms.has(t.from)).toBe(true);
      }
    });
  });
});
