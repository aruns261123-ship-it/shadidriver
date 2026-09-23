import { Body, Controller, Get, HttpCode, Param, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsArray, IsDateString, IsInt, IsOptional, IsString, Length, Max, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthenticatedUser } from '../auth/domain/auth.types';
import { Roles } from '../auth/guards/roles.guard';
import { Role } from '../auth/domain/roles';
import { CheckFleetAvailabilityDto } from '../availability/availability.controller';
import { GroupBookingsService, SubmitGroupBookingInput } from './group-bookings.service';

class SubmitGroupBookingDto {
  @IsString() @Length(2, 50) serviceCategoryId!: string;
  @IsString() @Length(2, 60) ceremonyType!: string;
  @IsString() @Length(2, 50) city!: string;
  @IsString() @Length(5, 500) pickupAddress!: string;
  @IsString() @Length(5, 500) destinationAddress!: string;
  @IsDateString() serviceStartTime!: string;
  @IsDateString() serviceEndTime!: string;
  @IsString() @Length(2, 120) primaryContactName!: string;
  @IsString() @Length(8, 20) primaryContactPhone!: string;
  @IsInt() @Min(1) @Max(200) passengerCount!: number;
  @ValidateNested({ each: true }) @Type(() => CheckFleetAvailabilityDto)
  @IsArray()
  fleet!: Array<{ vehicleTypeId: string; quantity: number }>;
  @IsString() @Length(8, 100) idempotencyKey!: string;
  @IsOptional() @IsString() notes?: string;
}

@ApiTags('group-bookings')
@ApiBearerAuth()
@Controller('group-bookings')
export class GroupBookingsController {
  constructor(private readonly groupBookingsService: GroupBookingsService) {}

  @Post('availability')
  @HttpCode(200)
  @ApiOperation({ summary: 'Real fleet availability for the requested composition' })
  availability(@Body() dto: CheckFleetAvailabilityDto) {
    return this.groupBookingsService.checkAvailability({
      fleet: dto.fleet,
      serviceStartTime: new Date(dto.serviceStartTime),
      serviceEndTime: new Date(dto.serviceEndTime),
      city: dto.city,
    });
  }

  @Post()
  @HttpCode(201)
  @ApiOperation({ summary: 'Create a group booking with vehicle assignments (transactional)' })
  submit(@CurrentUser() user: AuthenticatedUser, @Body() dto: SubmitGroupBookingDto) {
    const input: SubmitGroupBookingInput = {
      customerId: user.userId,
      serviceCategoryId: dto.serviceCategoryId,
      ceremonyType: dto.ceremonyType,
      city: dto.city,
      pickupAddress: dto.pickupAddress,
      destinationAddress: dto.destinationAddress,
      serviceStartTime: new Date(dto.serviceStartTime),
      serviceEndTime: new Date(dto.serviceEndTime),
      primaryContactName: dto.primaryContactName,
      primaryContactPhone: dto.primaryContactPhone,
      passengerCount: dto.passengerCount,
      fleet: dto.fleet,
      idempotencyKey: dto.idempotencyKey,
    };
    return this.groupBookingsService.submitGroupBooking(input);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Group booking detail with full assignment breakdown' })
  getById(@Param('id') id: string) {
    return this.groupBookingsService.getGroupBooking(id);
  }

  @Get(':id/assignments')
  @ApiOperation({ summary: 'Vehicle assignments under this group booking' })
  assignments(@Param('id') id: string) {
    return this.groupBookingsService.getGroupBooking(id);
  }

  // ------------------------------------------------------------ driver
  @Get('driver/assignments')
  @Roles(Role.Driver)
  @ApiOperation({ summary: 'Driver: own assignments ONLY (never other chauffeurs)' })
  myAssignments(@CurrentUser() user: AuthenticatedUser) {
    return this.groupBookingsService.listDriverAssignments(user.userId);
  }

  @Post('assignments/:id/accept')
  @Roles(Role.Driver)
  @ApiOperation({ summary: 'Driver accepts a group assignment (transactional)' })
  acceptAssignment(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.groupBookingsService.acceptAssignment(id, user.userId);
  }
}
