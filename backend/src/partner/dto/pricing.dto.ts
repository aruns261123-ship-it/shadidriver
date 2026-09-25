import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsDateString,
  IsInt,
  IsOptional,
  Max,
  Min,
} from 'class-validator';

/**
 * One submitted tariff version for a vehicle.
 *
 * Every amount is in PAISE (integer). There is deliberately no "base price"
 * field here: the commercial model is the structured tariff (local package,
 * distance, time, day, overnight, outstation) described in
 * docs/PLATFORM_REDESIGN.md §4.4 — never a single number.
 *
 * `verificationStatus`-style fields are absent on purpose: review state is
 * server-owned and starts at PENDING_REVIEW on every submission.
 */
export class SubmitVehiclePricingDto {
  @ApiProperty({ example: 45, description: 'Kilometres included in the local package' })
  @IsInt()
  @Min(5)
  @Max(500)
  localIncludedKm!: number;

  @ApiProperty({
    example: 300000,
    description: 'Local package amount in paise (Rs 3,000 up to localIncludedKm)',
  })
  @IsInt()
  @Min(10000)
  @Max(100000000)
  localAmountPaise!: number;

  @ApiProperty({ example: 2200, description: 'Each additional km beyond the package, in paise' })
  @IsInt()
  @Min(500)
  @Max(100000)
  perKmPaise!: number;

  @ApiPropertyOptional({ example: 125000, description: 'Hourly rate in paise' })
  @IsOptional()
  @IsInt()
  @Min(5000)
  @Max(10000000)
  hourlyPaise?: number;

  @ApiPropertyOptional({ example: 95000, description: 'Each extra hour beyond the booking, in paise' })
  @IsOptional()
  @IsInt()
  @Min(5000)
  @Max(10000000)
  extraHourPaise?: number;

  @ApiPropertyOptional({ example: 900000, description: 'Full-day (8h/80km) rate in paise' })
  @IsOptional()
  @IsInt()
  @Min(100000)
  @Max(100000000)
  fullDayPaise?: number;

  @ApiPropertyOptional({ example: 1200000, description: 'Overnight rate in paise' })
  @IsOptional()
  @IsInt()
  @Min(100000)
  @Max(100000000)
  overnightPaise?: number;

  @ApiPropertyOptional({ example: 600000, description: 'Outstation per-day rate in paise' })
  @IsOptional()
  @IsInt()
  @Min(100000)
  @Max(100000000)
  outstationPerDayPaise?: number;

  @ApiPropertyOptional({ example: 2600, description: 'Outstation per-km rate in paise' })
  @IsOptional()
  @IsInt()
  @Min(500)
  @Max(100000)
  outstationPerKmPaise?: number;

  /** When the partner asks for the tariff to start applying (admin still decides). */
  @ApiPropertyOptional({ example: '2026-10-01' })
  @IsOptional()
  @IsDateString()
  effectiveFrom?: string;
}
