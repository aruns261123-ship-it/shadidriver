import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, Length } from 'class-validator';

export const DECISION_ACTIONS = ['APPROVE', 'REJECT', 'REQUEST_CHANGES', 'SUSPEND'] as const;
export type DecisionAction = (typeof DECISION_ACTIONS)[number];

/**
 * A verification decision.
 *
 * `decisionReason` is REQUIRED for REJECT and REQUEST_CHANGES (the partner
 * must be told what to fix) and optional for APPROVE/SUSPEND. That conditional
 * rule is enforced in the service; the DTO only checks shape.
 */
export class ReviewDecisionDto {
  @ApiProperty({ enum: DECISION_ACTIONS, example: 'APPROVE' })
  @IsIn(DECISION_ACTIONS as unknown as string[])
  action!: DecisionAction;

  @ApiPropertyOptional({
    example: 'Insurance document is unreadable. Re-upload a clear scan.',
  })
  @IsOptional()
  @IsString()
  @Length(5, 1000)
  decisionReason?: string;
}
