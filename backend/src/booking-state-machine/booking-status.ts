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
  /** Operations is sourcing vehicles for the request. */
  UNDER_REVIEW = 'UNDER_REVIEW',
  /** Vehicles reserved and chauffeurs committed internally. */
  VEHICLE_OPTIONS_PREPARED = 'VEHICLE_OPTIONS_PREPARED',
  /** Operations has contacted the customer and awaits their agreement. */
  CUSTOMER_CONFIRMATION_PENDING = 'CUSTOMER_CONFIRMATION_PENDING',
  CONFIRMED = 'CONFIRMED',
  IN_PROGRESS = 'IN_PROGRESS',
  COMPLETED = 'COMPLETED',
  CANCELLED = 'CANCELLED',
  EXPIRED = 'EXPIRED',
  PAYMENT_PENDING = 'PAYMENT_PENDING',
  PAYMENT_FAILED = 'PAYMENT_FAILED',

  // --- retained only while trip progress migrates to AssignmentStatus ---
  /** @deprecated marketplace offer loop — superseded by UNDER_REVIEW. */
  DRIVER_ACCEPTED = 'DRIVER_ACCEPTED',
  /** @deprecated trip progress — migrating to AssignmentStatus.EN_ROUTE. */
  EN_ROUTE = 'EN_ROUTE',
  /** @deprecated trip progress — migrating to AssignmentStatus.ARRIVED. */
  ARRIVED = 'ARRIVED',
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
  // ------------------------------------------------ operations-managed path
  // The customer's request flows through operations. Nothing here is a
  // driver-facing offer: `driver` appears on no transition out of REQUESTED.
  { from: BookingStatus.DRAFT, to: BookingStatus.REQUESTED, action: 'SUBMIT_REQUEST', actors: ['customer', 'operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.REQUESTED, to: BookingStatus.UNDER_REVIEW, action: 'BEGIN_REVIEW', actors: ['operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.UNDER_REVIEW, to: BookingStatus.VEHICLE_OPTIONS_PREPARED, action: 'PREPARE_VEHICLE_OPTIONS', actors: ['operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.VEHICLE_OPTIONS_PREPARED, to: BookingStatus.CUSTOMER_CONFIRMATION_PENDING, action: 'REQUEST_CUSTOMER_CONFIRMATION', actors: ['operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.CUSTOMER_CONFIRMATION_PENDING, to: BookingStatus.CONFIRMED, action: 'CONFIRM_BOOKING', actors: ['customer', 'operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.CUSTOMER_CONFIRMATION_PENDING, to: BookingStatus.UNDER_REVIEW, action: 'REVISE_OPTIONS', actors: ['customer', 'operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.REQUESTED, to: BookingStatus.EXPIRED, action: 'EXPIRE', actors: ['SYSTEM', 'operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.UNDER_REVIEW, to: BookingStatus.EXPIRED, action: 'EXPIRE', actors: ['SYSTEM', 'operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.VEHICLE_OPTIONS_PREPARED, to: BookingStatus.EXPIRED, action: 'EXPIRE', actors: ['SYSTEM', 'operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.CUSTOMER_CONFIRMATION_PENDING, to: BookingStatus.EXPIRED, action: 'EXPIRE', actors: ['SYSTEM', 'operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.PAYMENT_PENDING, to: BookingStatus.CONFIRMED, action: 'CONFIRM_PAYMENT', actors: ['SYSTEM', 'financeAdmin', 'superAdmin'] },
  { from: BookingStatus.PAYMENT_FAILED, to: BookingStatus.PAYMENT_PENDING, action: 'RETRY_PAYMENT', actors: ['customer', 'financeAdmin', 'superAdmin'] },
  { from: BookingStatus.PAYMENT_PENDING, to: BookingStatus.PAYMENT_FAILED, action: 'FAIL_PAYMENT', actors: ['SYSTEM', 'financeAdmin', 'superAdmin'] },
  { from: BookingStatus.CONFIRMED, to: BookingStatus.PAYMENT_PENDING, action: 'REQUEST_PAYMENT', actors: ['SYSTEM', 'financeAdmin', 'superAdmin'] },
  { from: BookingStatus.UNDER_REVIEW, to: BookingStatus.CANCELLED, action: 'CANCEL', actors: ['customer', 'operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.VEHICLE_OPTIONS_PREPARED, to: BookingStatus.CANCELLED, action: 'CANCEL', actors: ['customer', 'operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.CUSTOMER_CONFIRMATION_PENDING, to: BookingStatus.CANCELLED, action: 'CANCEL', actors: ['customer', 'operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.PAYMENT_PENDING, to: BookingStatus.CANCELLED, action: 'CANCEL', actors: ['customer', 'operationsAdmin', 'superAdmin'] },
  { from: BookingStatus.PAYMENT_FAILED, to: BookingStatus.CANCELLED, action: 'CANCEL', actors: ['customer', 'operationsAdmin', 'superAdmin'] },

  // ------------------------------------------------- managed trip execution
  // On the operations-managed path a CONFIRMED booking goes straight into
  // service when the chauffeur starts the duty (the per-vehicle progress lives
  // on AssignmentStatus; the parent reflects that service has begun). The
  // legacy CONFIRMED → EN_ROUTE edge above is kept only for old rows.
  { from: BookingStatus.CONFIRMED, to: BookingStatus.IN_PROGRESS, action: 'START_TRIP', actors: ['driver', 'operationsAdmin', 'superAdmin'] },

  // ------------------------------------------------------- legacy (see enum)
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
  // operations-managed
  SUBMIT_REQUEST: BookingStatus.REQUESTED,
  BEGIN_REVIEW: BookingStatus.UNDER_REVIEW,
  PREPARE_VEHICLE_OPTIONS: BookingStatus.VEHICLE_OPTIONS_PREPARED,
  REQUEST_CUSTOMER_CONFIRMATION: BookingStatus.CUSTOMER_CONFIRMATION_PENDING,
  CONFIRM_BOOKING: BookingStatus.CONFIRMED,
  REVISE_OPTIONS: BookingStatus.UNDER_REVIEW,
  EXPIRE: BookingStatus.EXPIRED,
  REQUEST_PAYMENT: BookingStatus.PAYMENT_PENDING,
  FAIL_PAYMENT: BookingStatus.PAYMENT_FAILED,
  RETRY_PAYMENT: BookingStatus.PAYMENT_PENDING,
  // shared
  CANCEL: BookingStatus.CANCELLED,
  CONFIRM_PAYMENT: BookingStatus.CONFIRMED,
  START_TRIP: BookingStatus.IN_PROGRESS,
  COMPLETE_TRIP: BookingStatus.COMPLETED,
  // legacy (see enum)
  ACCEPT: BookingStatus.DRIVER_ACCEPTED,
  START_ROUTE: BookingStatus.EN_ROUTE,
  ARRIVE: BookingStatus.ARRIVED,
};

/** Terminal states — no outgoing transitions. */
export const TERMINAL_STATUSES: readonly BookingStatus[] = [
  BookingStatus.COMPLETED,
  BookingStatus.CANCELLED,
  BookingStatus.EXPIRED,
];
