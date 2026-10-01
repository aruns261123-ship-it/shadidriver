import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsDateString,
  IsInt,
  IsNumber,
  IsOptional,
  Max,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

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

  /**
   * DERIVED — do not send. The customer per-km rate is a server computation
   * from the ShadiDriver distance formula (fuel price ÷ mileage + ₹10) using
   * the `fuelPricePerLitre` and `mileageKmPerLitre` inputs below. A partner
   * never sets the customer rate; any value supplied here is ignored.
   */
  @IsOptional()
  @IsInt()
  perKmPaise?: number;

  @ApiProperty({
    example: 95,
    description: 'Current fuel price in ₹ per litre (drives the distance-rate formula)',
  })
  @Type(() => Number)
  @IsNumber(
    { maxDecimalPlaces: 2 },
    { message: 'fuelPricePerLitre must be a number (₹/litre, up to 2 decimals)' },
  )
  @Min(30)
  @Max(500)
  fuelPricePerLitre!: number;

  @ApiProperty({
    example: 8,
    description: 'Vehicle mileage in km per litre (drives the distance-rate formula)',
  })
  @Type(() => Number)
  @IsNumber(
    { maxDecimalPlaces: 1 },
    { message: 'mileageKmPerLitre must be a number (km/litre, up to 1 decimal)' },
  )
  @Min(2)
  @Max(60)
  mileageKmPerLitre!: number;

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
