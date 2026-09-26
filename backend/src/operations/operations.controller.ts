import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthenticatedUser } from '../auth/domain/auth.types';
import { ADMIN_ROLES, Role } from '../auth/domain/roles';
import { Roles } from '../auth/guards/roles.guard';
import { OperationsService } from './operations.service';
import {
  AddOperationsNoteDto,
  LogCustomerContactDto,
  OperationsQueueQueryDto,
  OperationsTransitionDto,
  ReallocateVehicleDto,
  RequoteDto,
} from './dto/operations.dto';

/**
 * Operations desk surface: the queue of customer booking requests and the
 * workspace where each one is executed.
 *
 * Reads are open to every admin role (a verification admin needs to see that a
 * booking is waiting on paperwork); MUTATIONS are restricted to the roles the
 * booking state machine actually authorises for the managed-booking path
 * (operationsAdmin / superAdmin). Role enforcement is re-checked inside the
 * state machine, so this decorator is a first gate, not the only one.
 */
@ApiTags('operations')
@ApiBearerAuth()
@Roles(...ADMIN_ROLES)
@Controller('operations')
export class OperationsController {
  constructor(private readonly operationsService: OperationsService) {}

  @Get('booking-requests')
  @ApiOperation({
    summary: 'Operational queue of customer booking requests (oldest first)',
  })
  bookingRequests(@Query() query: OperationsQueueQueryDto) {
    return this.operationsService.bookingRequestQueue({
      status: query.status,
      statuses: query.statuses,
      awaitingConfirmation: query.awaitingConfirmation === 'true',
      city: query.city,
    });
  }

  @Get('booking-requests/:id')
  @ApiOperation({
    summary: 'Full operational workspace: customer, allocation, chauffeurs, quote, notes, history',
  })
  bookingWorkspace(@Param('id', ParseUUIDPipe) id: string) {
    return this.operationsService.bookingWorkspace(id);
  }

  @Post('booking-requests/:id/transition')
  @Roles(Role.OperationsAdmin, Role.SuperAdmin)
  @ApiOperation({
    summary:
      'Advance the request: BEGIN_REVIEW | PREPARE_VEHICLE_OPTIONS | REQUEST_CUSTOMER_CONFIRMATION | REVISE_OPTIONS | CONFIRM_BOOKING | EXPIRE | CANCEL',
  })
  transition(
    @CurrentUser() admin: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: OperationsTransitionDto,
  ) {
    return this.operationsService.transition(id, dto, admin);
  }

  @Post('booking-requests/:id/contact')
  @Roles(Role.OperationsAdmin, Role.SuperAdmin)
  @ApiOperation({
    summary: 'Log the customer contact attempt; optionally move to CUSTOMER_CONFIRMATION_PENDING',
  })
  contact(
    @CurrentUser() admin: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: LogCustomerContactDto,
  ) {
    return this.operationsService.logCustomerContact(id, dto, admin);
  }

  @Post('booking-requests/:id/requote')
  @Roles(Role.OperationsAdmin, Role.SuperAdmin)
  @ApiOperation({
    summary: 'Re-price from the vehicles actually allocated (approved tariffs; snapshot retained)',
  })
  requote(
    @CurrentUser() admin: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RequoteDto,
  ) {
    return this.operationsService.requote(id, dto, admin);
  }

  @Post('booking-requests/:id/notes')
  @Roles(Role.OperationsAdmin, Role.SuperAdmin)
  @ApiOperation({ summary: 'Add an internal operations note (never returned to a customer)' })
  addNote(
    @CurrentUser() admin: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AddOperationsNoteDto,
  ) {
    return this.operationsService.addNote(id, dto.body, admin);
  }

  @Get('assignments/:assignmentId/chauffeurs')
  @ApiOperation({
    summary: 'Chauffeurs eligible for this window (verified, not double-committed)',
  })
  availableChauffeurs(@Param('assignmentId', ParseUUIDPipe) assignmentId: string) {
    return this.operationsService.availableChauffeurs(assignmentId);
  }

  @Post('assignments/:assignmentId/vehicle')
  @Roles(Role.OperationsAdmin, Role.SuperAdmin)
  @ApiOperation({
    summary: 'Re-allocate the reserved vehicle (verified + free in this window, or 409)',
  })
  reallocate(
    @CurrentUser() admin: AuthenticatedUser,
    @Param('assignmentId', ParseUUIDPipe) assignmentId: string,
    @Body() dto: ReallocateVehicleDto,
  ) {
    return this.operationsService.reallocateVehicle(
      assignmentId,
      dto.vehicleId,
      admin,
      dto.reason,
    );
  }

  @Post('assignments/:assignmentId/chauffeur/unassign')
  @Roles(Role.OperationsAdmin, Role.SuperAdmin)
  @ApiOperation({ summary: 'Release the chauffeur so operations can re-assign the duty' })
  unassignChauffeur(
    @CurrentUser() admin: AuthenticatedUser,
    @Param('assignmentId', ParseUUIDPipe) assignmentId: string,
  ) {
    return this.operationsService.unassignChauffeur(assignmentId, admin);
  }
}
