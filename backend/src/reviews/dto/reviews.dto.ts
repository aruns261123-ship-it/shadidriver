import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Max,
  Min,
} from 'class-validator';

/** A customer review of ONE vehicle from a COMPLETED booking. */
export class SubmitReviewDto {
  @ApiProperty({ description: 'The group booking the review is about.' })
  @IsUUID()
  groupBookingId!: string;

  @ApiProperty({ description: 'The vehicle being rated (must be part of the booking).' })
  @IsUUID()
  vehicleId!: string;

  @ApiProperty({ minimum: 1, maximum: 5 })
  @IsInt()
  @Min(1)
  @Max(5)
  overallRating!: number;

  @ApiPropertyOptional({ minimum: 1, maximum: 5 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  punctualityRating?: number;

  @ApiPropertyOptional({ minimum: 1, maximum: 5 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  groomingRating?: number;

  @ApiPropertyOptional({ minimum: 1, maximum: 5 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  cleanlinessRating?: number;

  @ApiPropertyOptional({ minimum: 1, maximum: 5 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  drivingRating?: number;

  @ApiPropertyOptional({ minimum: 1, maximum: 5 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  vehicleQualityRating?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(4, 2000)
  feedbackText?: string;
}

export const MODERATION_ACTIONS = ['PUBLISH', 'HIDE', 'REOPEN'] as const;
export type ModerationAction = (typeof MODERATION_ACTIONS)[number];

/** A moderation decision on a submitted review. */
export class ModerationDecisionDto {
  @ApiProperty({ enum: MODERATION_ACTIONS })
  @IsIn(MODERATION_ACTIONS as unknown as string[])
  action!: ModerationAction;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(4, 500)
  reason?: string;
}
