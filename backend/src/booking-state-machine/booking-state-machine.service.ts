import { ConflictException, Injectable } from '@nestjs/common';
import {
  ACTION_TO_STATUS,
  ActorRole,
  BookingStatus,
  isTransitionAllowed,
} from './booking-status';
import { ErrorCode } from '../common/errors/error-codes';

/**
 * Pure domain policy: decides whether a requested action on a booking in a
 * given state by a given actor is legal. Unit-tested exhaustively; the
 * persistence layer (Phase 5) calls this inside its serializable transaction
 * before writing status + booking_events.
 */
@Injectable()
export class BookingStateMachineService {
  /** Resolves the target status for a client action, or throws INVALID_TRANSITION. */
  resolveTarget(action: string): BookingStatus {
    const target = ACTION_TO_STATUS[action];
    if (!target) {
      throw new ConflictException({
        code: ErrorCode.INVALID_TRANSITION,
        message: `Unknown booking action '${action}'.`,
      });
    }
    return target;
  }

  assertTransitionAllowed(
    from: BookingStatus,
    action: string,
    actor: ActorRole,
  ): BookingStatus {
    const to = this.resolveTarget(action);
    if (!isTransitionAllowed(from, to, actor)) {
      throw new ConflictException({
        code: ErrorCode.INVALID_TRANSITION,
        message: `Transition ${action} (${from} → ${to}) is not permitted for role '${actor}'.`,
        details: { from, to, actor },
      });
    }
    return to;
  }

  isTerminal(status: BookingStatus): boolean {
    return status === BookingStatus.COMPLETED || status === BookingStatus.CANCELLED;
  }

  /** Guard helper: optimistic-concurrency mismatch becomes VERSION_CONFLICT. */
  assertVersionMatches(expected: number, clientObserved: number): void {
    if (expected !== clientObserved) {
      throw new ConflictException({
        code: ErrorCode.VERSION_CONFLICT,
        message: 'The booking was modified concurrently. Refresh and retry.',
        details: { server_version: expected, client_version: clientObserved },
      });
    }
  }
}

// Re-export for the Nest exception filter mapping (HttpException with plain
// object bodies is rendered by the global filter with default status codes).
export { ConflictException as StateMachineConflict };
