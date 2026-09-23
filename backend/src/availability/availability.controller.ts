import { Body, Controller, Post } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { Public } from '../auth/guards/jwt-auth.guard';
import { AvailabilityService, FleetRequestLine } from './availability.service';

class FleetRequestLineDto {
  @IsString()
  @Length(2, 50)
  vehicleTypeId!: string;

  @IsInt()
  @Min(1)
  @Max(50)
  quantity!: number;
}

export class CheckFleetAvailabilityDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => FleetRequestLineDto)
  fleet!: FleetRequestLineDto[];

  @IsDateString()
  serviceStartTime!: string;

  @IsDateString()
  serviceEndTime!: string;

  @IsOptional()
  @IsString()
  city?: string;
}

@ApiTags('availability')
@Controller('availability')
export class AvailabilityController {
  constructor(private readonly availabilityService: AvailabilityService) {}

  @Public()
  @Post('fleet')
  @ApiOperation({
    summary:
      'Real fleet availability: requested vs available per type with explicit shortfall and alternatives',
  })
  checkFleet(@Body() dto: CheckFleetAvailabilityDto) {
    const lines: FleetRequestLine[] = dto.fleet.map((f) => ({
      vehicleTypeId: f.vehicleTypeId,
      quantity: f.quantity,
    }));
    return this.availabilityService.checkFleetAvailability(
      lines,
      new Date(dto.serviceStartTime),
      new Date(dto.serviceEndTime),
      dto.city,
    );
  }
}
