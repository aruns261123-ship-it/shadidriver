import { Body, Controller, Get, HttpCode, Param, Post, Query, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Request } from 'express';
import {
  IsArray,
  IsDateString,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  Max,
  Min,
} from 'class-validator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthenticatedUser } from '../auth/domain/auth.types';
import { Roles } from '../auth/guards/roles.guard';
import { Role } from '../auth/domain/roles';
import { BookingsService, SubmitBookingInput } from './bookings.service';

export class SubmitBookingDto {
  @IsString() @Length(2, 50) serviceCategoryId!: string;
  @IsString() @Length(2, 50) vehicleTypeId!: string;
  @IsString() @Length(2, 60) ceremonyType!: string;
  @IsString() @Length(2, 100) ceremonialAttire!: string;
  @IsOptional() @IsString() specialInstructions?: string;
  @IsDateString() serviceStartTime!: string;
  @IsDateString() serviceEndTime!: string;
  @IsString() @Length(2, 50) city!: string;
  @IsString() @Length(5, 500) pickupAddress!: string;
  @IsString() @Length(5, 500) destinationAddress!: string;
  @IsOptional() @IsString() venueName?: string;
  @IsOptional() @IsNumber() @Min(0) routeDistanceKm?: number;
  @IsString() @Length(2, 120) primaryContactName!: string;
  @IsString() @Length(8, 20) primaryContactPhone!: string;
  @IsInt() @Min(1) @Max(60) passengerCount!: number;
  @IsOptional() @IsArray() @IsString({ each: true }) selectedAddonIds?: string[];
}

export class TransitionDto {
  @IsIn(['ACCEPT', 'CANCEL', 'CONFIRM_PAYMENT', 'START_ROUTE', 'ARRIVE', 'START_TRIP', 'COMPLETE_TRIP'])
  action!: string;

  @IsOptional() @IsString() otp?: string;
  @IsOptional() @IsString() reason?: string;
  @IsOptional() @IsString({ each: true }) notes?: unknown;
}

@ApiTags('bookings')
@ApiBearerAuth()
@Controller('bookings')
export class BookingsController {
  constructor(private readonly bookingsService: BookingsService) {}

  @Post()
  @HttpCode(201)
  @ApiOperation({ summary: 'Submit a booking (idempotent via Idempotency-Key header)' })
  async submit(
    @CurrentUser() user: AuthenticatedUser,
    @Req() request: Request,
    @Body() dto: SubmitBookingDto,
  ) {
    const idempotencyKey =
      (request.headers['idempotency-key'] as string | undefined) ?? '';
    if (!idempotencyKey || idempotencyKey.length < 8) {
      // Validated here so the error contract stays uniform.
      throw Object.assign(new Error('Idempotency-Key header (>=8 chars) is required.'), {
        status: 400,
        response: {
          code: 'VALIDATION_FAILED',
          message: 'Idempotency-Key header (>=8 chars) is required.',
        },
      });
    }
    const input: SubmitBookingInput = {
      customerId: user.userId,
      serviceCategoryId: dto.serviceCategoryId,
      vehicleTypeId: dto.vehicleTypeId,
      ceremonyType: dto.ceremonyType,
      ceremonialAttire: dto.ceremonialAttire,
      specialInstructions: dto.specialInstructions,
      serviceStartTime: new Date(dto.serviceStartTime),
      serviceEndTime: new Date(dto.serviceEndTime),
      city: dto.city,
      pickupAddress: dto.pickupAddress,
      destinationAddress: dto.destinationAddress,
      venueName: dto.venueName,
      routeDistanceKm: dto.routeDistanceKm,
      primaryContactName: dto.primaryContactName,
      primaryContactPhone: dto.primaryContactPhone,
      passengerCount: dto.passengerCount,
      selectedAddonIds: dto.selectedAddonIds,
      idempotencyKey,
    };
    const { booking, idempotentReplay } = await this.bookingsService.submitBooking(input);
    return { booking, idempotent_replay: idempotentReplay };
  }

  @Get('my')
  @ApiOperation({ summary: "List the caller's bookings" })
  myBookings(
    @CurrentUser() user: AuthenticatedUser,
    @Query('page') page = '1',
    @Query('limit') limit = '20',
  ) {
    return this.bookingsService.listMyBookings(
      user.userId,
      Math.max(1, Number(page) || 1),
      Math.min(50, Math.max(1, Number(limit) || 20)),
    );
  }

  @Get(':id')
  @ApiOperation({ summary: 'Booking detail with status history' })
  getById(@Param('id') id: string) {
    return this.bookingsService.getBookingById(id);
  }

  @Post(':id/transition')
  @ApiOperation({ summary: 'Server-validated lifecycle transition (OTP required to start trip)' })
  transition(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: TransitionDto,
  ) {
    return this.bookingsService.transition(
      id,
      dto.action,
      { userId: user.userId, role: user.role },
      { otp: dto.otp, reason: dto.reason, notes: dto.notes },
    );
  }

  // ------------------------------------------------------------ driver
  @Get('driver/offers')
  @Roles(Role.Driver)
  @ApiOperation({ summary: 'Driver: open offers, active assignments, completed history' })
  driverBookings(@CurrentUser() user: AuthenticatedUser) {
    return this.bookingsService.listDriverBookings(user.userId);
  }

  @Post(':id/accept')
  @Roles(Role.Driver)
  @ApiOperation({ summary: 'Driver accepts a requested booking (transactional, generates trip OTP)' })
  accept(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.bookingsService.acceptBooking(id, user.userId);
  }

  @Post(':id/decline')
  @Roles(Role.Driver)
  @ApiOperation({ summary: 'Driver declines with mandatory reason' })
  decline(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: { reason: string; notes?: string },
  ) {
    return this.bookingsService.declineBooking(id, user.userId, dto.reason, dto.notes);
  }

  @Post(':id/trip-otp/resend')
  @ApiOperation({ summary: 'Customer: resend the trip start OTP to the host phone' })
  resendOtp(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.bookingsService.resendTripOtp(id, { userId: user.userId, role: user.role });
  } }
