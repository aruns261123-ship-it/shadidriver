import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  Min,
} from 'class-validator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthenticatedUser } from '../auth/domain/auth.types';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { QuotesService, QuoteRequestInput } from './quotes.service';
import { TRIP_TYPE_VALUES } from '../common/domain/trip-type';

export class CreateQuoteDto {
  @ApiPropertyOptional({ example: 'SVC_BARAAT' })
  @IsString()
  @Length(2, 50)
  serviceCategoryId!: string;

  @ApiPropertyOptional({ example: 'VT_INNOVA_CRYSTA' })
  @IsString()
  @Length(2, 50)
  vehicleTypeId!: string;

  @ApiPropertyOptional({ example: 'Delhi NCR' })
  @IsOptional()
  @IsString()
  city?: string;

  @ApiPropertyOptional({ example: '2026-11-20T16:00:00+05:30' })
  @IsDateString()
  serviceStartTime!: string;

  @ApiPropertyOptional({ example: '2026-11-21T01:00:00+05:30' })
  @IsDateString()
  serviceEndTime!: string;

  @ApiPropertyOptional({ example: 24.5 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  routeDistanceKm?: number;

  /** ONE_WAY (pickup → destination) or ROUND_TRIP (distance × 2). */
  @ApiPropertyOptional({ enum: TRIP_TYPE_VALUES, example: 'ONE_WAY' })
  @IsOptional()
  @IsIn(TRIP_TYPE_VALUES)
  tripType?: string;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  selectedAddonIds?: string[];

  @ApiPropertyOptional({ example: false })
  @IsOptional()
  @IsBoolean()
  isUrgent?: boolean;
}

@ApiTags('quotes')
@ApiBearerAuth()
@Controller('quotes')
export class QuotesController {
  constructor(private readonly quotesService: QuotesService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Server-authoritative price quote (client totals are never trusted)' })
  createQuote(@CurrentUser() _user: AuthenticatedUser, @Body() dto: CreateQuoteDto) {
    const input: QuoteRequestInput = {
      serviceCategoryId: dto.serviceCategoryId,
      vehicleTypeId: dto.vehicleTypeId,
      city: dto.city,
      serviceStartTime: new Date(dto.serviceStartTime),
      serviceEndTime: new Date(dto.serviceEndTime),
      routeDistanceKm: dto.routeDistanceKm,
      tripType: dto.tripType as QuoteRequestInput['tripType'],
      selectedAddonIds: dto.selectedAddonIds,
      isUrgent: dto.isUrgent,
    };
    return this.quotesService.createQuote(input);
  }
}
