import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsBoolean,
  IsDateString,
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
      selectedAddonIds: dto.selectedAddonIds,
      isUrgent: dto.isUrgent,
    };
    return this.quotesService.createQuote(input);
  }
}
