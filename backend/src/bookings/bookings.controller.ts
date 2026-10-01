import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query, Req } from '@nestjs/common';
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
  IsUUID,
  Length,
  Max,
  Min,
} from 'class-validator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthenticatedUser } from '../auth/domain/auth.types';
import { Roles } from '../auth/guards/roles.guard';
import { Role } from '../auth/domain/roles';
import { BadRequestAppException } from '../auth/errors/auth.exceptions';
import { ErrorCode } from '../common/errors/error-codes';
import { BookingsService, SubmitBookingInput } from './bookings.service';
import { TRIP_TYPE_VALUES } from '../common/domain/trip-type';

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
  /** ONE_WAY or ROUND_TRIP; submission re-quotes with the server-side ×2 rule. */
  @IsOptional() @IsIn(TRIP_TYPE_VALUES) tripType?: string;
  @IsString() @Length(2, 120) primaryContactName!: string;
  @IsString() @Length(8, 20) primaryContactPhone!: string;
  @IsInt() @Min(1) @Max(60) passengerCount!: number;
  @IsOptional() @IsArray() @IsString({ each: true }) selectedAddonIds?: string[];
}

export class AssignChauffeurDto {
  @IsUUID() driverId!: string;
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
      // A header cannot be validated by the DTO pipe, so it is validated here.
      // Use the app exception type (not a bare Error with a status property) so
      // the global filter renders the documented 400 VALIDATION_FAILED envelope
      // instead of falling through to a 500 INTERNAL_ERROR.
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        'Idempotency-Key header (>=8 chars) is required.',
      );
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
      tripType: dto.tripType as SubmitBookingInput['tripType'],
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
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Booking detail — role-scoped private view (customer/driver/admin)' })
  getById(
    @CurrentUser() user: AuthenticatedUser,
    // Malformed ids are a 400, never a Prisma P2023 → 500.
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.bookingsService.getBookingById(id, { userId: user.userId, role: user.role });
  }

  @Post(':id/transition')
  @ApiOperation({ summary: 'Server-validated lifecycle transition (OTP required to start trip)' })
  transition(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
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
  @ApiOperation({
    summary: 'Chauffeur: OWN assigned duties only (no marketplace — operations allocates all work)',
  })
  driverBookings(@CurrentUser() user: AuthenticatedUser) {
    return this.bookingsService.listDriverBookings(user.userId);
  }

  @Post(':id/assign-chauffeur')
  @Roles(Role.OperationsAdmin, Role.SuperAdmin)
  @ApiOperation({
    summary: 'Operations allocates a chauffeur to a booking (customers never pick drivers; drivers never claim bookings)',
  })
  allocateChauffeur(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AssignChauffeurDto,
  ) {
    return this.bookingsService.assignChauffeur(id, dto.driverId, {
      userId: user.userId,
      role: user.role,
    });
  }

  @Post(':id/assignment-conflict')
  @Roles(Role.Driver)
  @ApiOperation({
    summary: 'Assigned chauffeur reports a conflict; the duty returns to the operations queue (no marketplace decline)',
  })
  reportConflict(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: { reason: string; notes?: string },
  ) {
    return this.bookingsService.reportAssignmentConflict(id, user.userId, dto.reason, dto.notes);
  }

  @Post(':id/trip-otp/resend')
  @ApiOperation({ summary: 'Customer: resend the trip start OTP to the host phone' })
  resendOtp(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.bookingsService.resendTripOtp(id, { userId: user.userId, role: user.role });
  } }
