import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Max,
  Min,
} from 'class-validator';

/**
 * Actions OPERATIONS may take on a booking request. This list is deliberately
 * explicit and narrow: the shared booking state machine decides legality, but
 * the HTTP surface only accepts the actions an operations desk actually
 * performs, so an admin token cannot be used to jam the pipeline with states
 * that belong to the trip or payment phases.
 */
export const OPERATIONS_ACTIONS = [
  'BEGIN_REVIEW',
  'PREPARE_VEHICLE_OPTIONS',
  'REQUEST_CUSTOMER_CONFIRMATION',
  'REVISE_OPTIONS',
  'CONFIRM_BOOKING',
  'EXPIRE',
  'CANCEL',
] as const;
export type OperationsAction = (typeof OPERATIONS_ACTIONS)[number];

export class OperationsTransitionDto {
  @ApiProperty({ enum: OPERATIONS_ACTIONS, example: 'BEGIN_REVIEW' })
  @IsIn(OPERATIONS_ACTIONS as unknown as string[])
  action!: OperationsAction;

  @ApiPropertyOptional({ example: 'Customer asked for a white Thar for the groom entry.' })
  @IsOptional()
  @IsString()
  @Length(2, 500)
  reason?: string;
}

export class AddOperationsNoteDto {
  @ApiProperty({ example: 'Need white Thar for groom entry. Call customer after 5 PM.' })
  @IsString()
  @Length(2, 2000)
  body!: string;
}

export const CONTACT_CHANNELS = ['PHONE', 'WHATSAPP', 'EMAIL', 'IN_PERSON'] as const;
export const CONTACT_OUTCOMES = [
  'REACHED',
  'NO_ANSWER',
  'CALLBACK_REQUESTED',
  'WRONG_NUMBER',
] as const;

/**
 * Records that operations contacted the customer — the step the managed
 * booking model revolves around. Storing it as a note + audit row keeps the
 * "who spoke to the customer, when, with what result" question answerable.
 */
export class LogCustomerContactDto {
  @ApiProperty({ enum: CONTACT_CHANNELS })
  @IsIn(CONTACT_CHANNELS as unknown as string[])
  channel!: string;

  @ApiProperty({ enum: CONTACT_OUTCOMES })
  @IsIn(CONTACT_OUTCOMES as unknown as string[])
  outcome!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(2, 1000)
  note?: string;

  /** Move VEHICLE_OPTIONS_PREPARED → CUSTOMER_CONFIRMATION_PENDING. */
  @ApiPropertyOptional({
    description: 'Advance the booking to CUSTOMER_CONFIRMATION_PENDING in the same step.',
  })
  @IsOptional()
  @IsIn([true, false])
  advanceToConfirmation?: boolean;
}

/**
 * Move a reservation onto a different concrete vehicle. Operations does this
 * when the vehicle originally reserved is withdrawn, damaged or needed
 * elsewhere. The customer is NEVER silently swapped — this endpoint requires an
 * explicit reason, which lands in the audit trail.
 */
export class ReallocateVehicleDto {
  @ApiProperty({ description: 'Replacement vehicle id (already verified + active).' })
  @IsUUID()
  vehicleId!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(2, 500)
  reason?: string;
}

export class RequoteDto {
  @ApiPropertyOptional({
    description: 'Declared route distance; per-km beyond the tariff package is charged.',
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(5000)
  routeDistanceKm?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(2, 500)
  reason?: string;
}

export class OperationsQueueQueryDto {
  @ApiPropertyOptional({
    description: 'Filter by booking status; defaults to everything still in the pipeline.',
  })
  @IsOptional()
  @IsString()
  @Length(2, 40)
  status?: string;

  @ApiPropertyOptional({ description: 'Only bookings awaiting the customer’s confirmation.' })
  @IsOptional()
  @IsIn(['true', 'false'])
  awaitingConfirmation?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(1, 60)
  city?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(12)
  @IsString({ each: true })
  statuses?: string[];
}
