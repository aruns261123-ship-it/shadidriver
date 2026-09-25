import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthenticatedUser } from '../auth/domain/auth.types';
import { ADMIN_ROLES } from '../auth/domain/roles';
import { Roles } from '../auth/guards/roles.guard';
import { AdminService } from './admin.service';
import { ReviewDecisionDto } from './dto/admin.dto';

/**
 * Admin verification center — the consumer of every queue partners feed.
 *
 * A pending partner submission, a new vehicle, a re-uploaded document or a
 * freshly submitted tariff all surface here. Every decision is audit-logged.
 * Chauffeur/partner identity visible on these endpoints is exactly what the
 * customer-facing payloads must never contain.
 */
@ApiTags('admin')
@ApiBearerAuth()
@Roles(...ADMIN_ROLES)
@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  // ------------------------------------------------------------------ queues

  @Get('verification/partners')
  @ApiOperation({ summary: 'Partners awaiting verification (oldest first)' })
  partnerQueue() {
    return this.adminService.partnerQueue();
  }

  @Get('verification/vehicles')
  @ApiOperation({ summary: 'Vehicles awaiting verification, with paperwork state' })
  vehicleQueue() {
    return this.adminService.vehicleQueue();
  }

  @Get('pricing/queue')
  @ApiOperation({
    summary: 'Tariffs awaiting commercial review, side-by-side with the live tariff',
  })
  pricingQueue() {
    return this.adminService.pricingQueue();
  }

  // --------------------------------------------------------------- decisions

  @Post('verification/partners/:partnerId')
  @ApiOperation({ summary: 'Approve / reject / request changes / suspend a PARTNER' })
  decidePartner(
    @CurrentUser() admin: AuthenticatedUser,
    @Param('partnerId', ParseUUIDPipe) partnerId: string,
    @Body() dto: ReviewDecisionDto,
  ) {
    return this.adminService.decidePartner(admin, partnerId, dto.action, dto.decisionReason);
  }

  @Post('verification/vehicles/:vehicleId')
  @ApiOperation({ summary: 'Approve / reject / request changes / suspend a VEHICLE' })
  decideVehicle(
    @CurrentUser() admin: AuthenticatedUser,
    @Param('vehicleId', ParseUUIDPipe) vehicleId: string,
    @Body() dto: ReviewDecisionDto,
  ) {
    return this.adminService.decideVehicle(admin, vehicleId, dto.action, dto.decisionReason);
  }

  @Post('pricing/:pricingId/decision')
  @ApiOperation({
    summary: 'Approve / reject / request changes a TARIFF (approve supersedes the live version atomically)',
  })
  decidePricing(
    @CurrentUser() admin: AuthenticatedUser,
    @Param('pricingId', ParseUUIDPipe) pricingId: string,
    @Body() dto: ReviewDecisionDto,
  ) {
    return this.adminService.decidePricing(admin, pricingId, dto.action, dto.decisionReason);
  }
}
