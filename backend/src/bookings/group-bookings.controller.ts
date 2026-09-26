import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthenticatedUser } from '../auth/domain/auth.types';
import { Roles } from '../auth/guards/roles.guard';
import { Role } from '../auth/domain/roles';
import {
  CheckFleetAvailabilityDto,
  FleetRequestLineDto,
} from '../availability/availability.controller';
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
  // Each element is ONE requested vehicle line. Validating these against the
  // whole availability DTO (which itself contains a `fleet` array) rejected
  // every real submission with "vehicleTypeId should not exist".
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => FleetRequestLineDto)
  fleet!: FleetRequestLineDto[];
  @IsString() @Length(8, 100) idempotencyKey!: string;
  @IsOptional() @IsString() notes?: string;

  /** Optional customer requirements, e.g. "Wedding decoration", "Child seat". */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @Length(1, 120, { each: true })
  requirements?: string[];

  /** Preferred confirmation channel. */
  @IsOptional()
  @IsIn(['PHONE', 'WHATSAPP', 'EMAIL', 'PHONE_WHATSAPP'])
  communicationPreference?: string;
}

/**
 * The ONLY actions a customer may take on their own booking request. Operations
 * owns everything else — a customer cannot mark a booking confirmed from
 * UNDER_REVIEW, nor drive it into a state operations has not opened.
 */
class CustomerTransitionDto {
  @IsIn(['CONFIRM_BOOKING', 'REVISE_OPTIONS', 'CANCEL'])
  action!: string;

  @IsOptional()
  @IsString()
  @Length(2, 500)
  reason?: string;
}

/**
 * A chauffeur duty milestone. START_SERVICE carries the customer's trip OTP;
 * the other milestones carry nothing (their authority is the chauffeur's own
 * assignment, re-verified server-side).
 */
class MilestoneDto {
  @IsIn(['EN_ROUTE', 'ARRIVED', 'START_SERVICE', 'COMPLETE'])
  milestone!: 'EN_ROUTE' | 'ARRIVED' | 'START_SERVICE' | 'COMPLETE';

  /** Required only for START_SERVICE: the code the customer received by SMS. */
  @IsOptional()
  @IsString()
  @Length(4, 8)
  otp?: string;
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
      requirements: dto.requirements,
      communicationPreference: dto.communicationPreference,
    };
    return this.groupBookingsService.submitGroupBooking(input);
  }

  @Get('my')
  @ApiOperation({ summary: "The caller's own group bookings, newest first" })
  myGroupBookings(
    @CurrentUser() user: AuthenticatedUser,
    @Query('page') page = '1',
    @Query('limit') limit = '20',
  ) {
    return this.groupBookingsService.listMyGroupBookings(
      user.userId,
      Math.max(1, Number(page) || 1),
      Math.min(50, Math.max(1, Number(limit) || 20)),
    );
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Group booking detail — owner or admin only (404 for anyone else)',
  })
  getById(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.groupBookingsService.getGroupBooking(id, user);
  }

  @Get(':id/assignments')
  @ApiOperation({ summary: 'Vehicle assignments under this group booking (customer-safe)' })
  assignments(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.groupBookingsService.getGroupBooking(id, user);
  }

  @Post(':id/transition')
  @ApiOperation({
    summary:
      'Customer lifecycle action on their own request: CONFIRM_BOOKING | REVISE_OPTIONS | CANCEL',
  })
  customerTransition(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: CustomerTransitionDto,
  ) {
    return this.groupBookingsService.customerTransition(id, dto.action, user, dto.reason);
  }

  // ------------------------------------------------------------ driver
  // Chauffeurs see only duties operations already assigned to them. There is
  // no offer/accept loop: ops decides, the chauffeur acknowledges — and then
  // EXECUTES the duty through the milestone ladder below.
  @Get('driver/assignments')
  @Roles(Role.Driver)
  @ApiOperation({ summary: 'Chauffeur: own assigned duties ONLY (never other chauffeurs)' })
  myAssignments(@CurrentUser() user: AuthenticatedUser) {
    return this.groupBookingsService.listDriverAssignments(user.userId);
  }

  /**
   * The per-vehicle execution ladder: EN_ROUTE → ARRIVED → START_SERVICE →
   * COMPLETE. Assignment to this chauffeur is re-verified inside the service
   * (row-locked), the booking must be CONFIRMED, and START_SERVICE consumes
   * the customer's trip OTP.
   */
  @Post('assignments/:id/milestones')
  @Roles(Role.Driver)
  @ApiOperation({
    summary:
      'Chauffeur records a duty milestone: EN_ROUTE | ARRIVED | START_SERVICE (customer OTP required) | COMPLETE',
  })
  recordMilestone(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: MilestoneDto,
  ) {
    return this.groupBookingsService.recordMilestone(
      id,
      dto.milestone,
      user.userId,
      dto.otp,
    );
  }

  @Post(':id/trip-otp/resend')
  @Roles(Role.Customer)
  @ApiOperation({ summary: 'Customer: resend the trip start OTP to their own phone' })
  resendTripOtp(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.groupBookingsService.resendTripOtp(id, user);
  }

  @Post('assignments/:id/acknowledge')
  @Roles(Role.Driver)
  @ApiOperation({ summary: 'Chauffeur acknowledges an operations-assigned duty' })
  acknowledgeAssignment(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.groupBookingsService.acknowledgeAssignment(id, user.userId);
  }

  @Post('assignments/:id/decline')
  @Roles(Role.Driver)
  @ApiOperation({
    summary: 'Chauffeur reports a conflict; the vehicle stays reserved and returns to the ops queue',
  })
  declineAssignment(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: { reason?: string },
  ) {
    return this.groupBookingsService.declineAssignment(
      id,
      user.userId,
      body?.reason?.trim() || 'Unavailable for this window',
    );
  }

  // ------------------------------------------------------- operations
  @Post('assignments/:id/confirm-vehicle')
  @Roles(Role.OperationsAdmin)
  @ApiOperation({ summary: 'Operations: confirm the reserved vehicle for an assignment' })
  confirmVehicle(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.groupBookingsService.confirmVehicleAllocation(id, user.userId);
  }

  @Post('assignments/:id/assign-chauffeur')
  @Roles(Role.OperationsAdmin)
  @ApiOperation({ summary: 'Operations: assign the chauffeur internally (no customer-visible offer)' })
  assignChauffeur(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: { driverId: string },
  ) {
    return this.groupBookingsService.assignChauffeur(id, body.driverId, user.userId);
  }
}
