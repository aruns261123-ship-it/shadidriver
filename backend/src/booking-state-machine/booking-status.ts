/**
 * Server-authoritative booking lifecycle.
 * Terminology matches the frontend BookingStatus enum and
 * infra/migrations/0001_init.sql — the documented spec states are folded
 * into these canonical values (e.g. DRIVER_EN_ROUTE → EN_ROUTE,
 * TRIP_STARTED → IN_PROGRESS) to preserve client compatibility.
 */
export enum BookingStatus {
  DRAFT = 'DRAFT',
  REQUESTED = 'REQUESTED',
  DRIVER_ACCEPTED = 'DRIVER_ACCEPTED',
  CONFIRMED = 'CONFIRMED',
  EN_ROUTE = 'EN_ROUTE',
  ARRIVED = 'ARRIVED',
  IN_PROGRESS = 'IN_PROGRESS',
  COMPLETED = 'COMPLETED',
  CANCELLED = 'CANCELLED',
}

/** Actor categories permitted to trigger transitions. */
export type ActorRole =
  | 'SYSTEM'
  | 'customer'
  | 'driver'
  | 'fleetOwner'
  | 'operationsAdmin'
  | 'verificationAdmin'
  | 'financeAdmin'
  | 'superAdmin';

interface TransitionRule {
  from: BookingStatus;
  to: BookingStatus;
  action: string;
  actors: readonly ActorRole[];
}

/**
 * Canonical transition table derived from docs/BOOKING_STATE_MACHINE.md.
 * Any state change not listed here is rejected server-side; clients are
 * read-only requestors of transitions.
 */
export const TRANSITIONS: readonly TransitionRule[] = [
  { from: BookingStatus.REQUESTED, to: BookingStatus.DRIVER_ACCEPTED, action: 'ACCEPT', actors: ['driver', 'fleetOwner', 'operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.REQUESTED, to: BookingStatus.CANCELLED, action: 'CANCEL', actors: ['customer', 'operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.DRIVER_ACCEPTED, to: BookingStatus.CONFIRMED, action: 'CONFIRM_PAYMENT', actors: ['SYSTEM', 'financeAdmin', 'superAdmin'] },
  { from: BookingStatus.DRIVER_ACCEPTED, to: BookingStatus.CANCELLED, action: 'CANCEL', actors: ['customer', 'operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.CONFIRMED, to: BookingStatus.EN_ROUTE, action: 'START_ROUTE', actors: ['driver'] },
  { from: BookingStatus.CONFIRMED, to: BookingStatus.CANCELLED, action: 'CANCEL', actors: ['customer', 'operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.EN_ROUTE, to: BookingStatus.ARRIVED, action: 'ARRIVE', actors: ['driver'] },
  { from: BookingStatus.EN_ROUTE, to: BookingStatus.CANCELLED, action: 'CANCEL', actors: ['operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.ARRIVED, to: BookingStatus.IN_PROGRESS, action: 'START_TRIP', actors: ['driver'] },
  { from: BookingStatus.IN_PROGRESS, to: BookingStatus.COMPLETED, action: 'COMPLETE_TRIP', actors: ['driver', 'customer', 'operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.ARRIVED, to: BookingStatus.CANCELLED, action: 'CANCEL', actors: ['operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.IN_PROGRESS, to: BookingStatus.CANCELLED, action: 'CANCEL', actors: ['operationsAdmin', 'superAdmin'] },
];

/** Resolves the rule for a from→to pair, or null when illegal. */
export function findTransition(from: BookingStatus, to: BookingStatus): TransitionRule | null {
  return TRANSITIONS.find((t) => t.from === from && t.to === to) ?? null;
}

export function isTransitionAllowed(from: BookingStatus, to: BookingStatus, actor: ActorRole): boolean {
  const rule = findTransition(from, to);
  if (!rule) return false;
  return rule.actors.includes(actor);
}

/** Maps a client-facing action name to its target status. */
export const ACTION_TO_STATUS: Readonly<Record<string, BookingStatus>> = {
  ACCEPT: BookingStatus.DRIVER_ACCEPTED,
  CANCEL: BookingStatus.CANCELLED,
  CONFIRM_PAYMENT: BookingStatus.CONFIRMED,
  START_ROUTE: BookingStatus.EN_ROUTE,
  ARRIVE: BookingStatus.ARRIVED,
  START_TRIP: BookingStatus.IN_PROGRESS,
  COMPLETE_TRIP: BookingStatus.COMPLETED,
};

/** Terminal states — no outgoing transitions. */
export const TERMINAL_STATUSES: readonly BookingStatus[] = [
  BookingStatus.COMPLETED,
  BookingStatus.CANCELLED,
];
