import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthenticatedUser } from '../auth/domain/auth.types';
import { Public } from '../auth/guards/jwt-auth.guard';
import { ADMIN_ROLES, Role } from '../auth/domain/roles';
import { Roles } from '../auth/guards/roles.guard';
import { ReviewsService } from './reviews.service';
import { ModerationDecisionDto, SubmitReviewDto } from './dto/reviews.dto';

/**
 * Customer reviews.
 *
 * Submitting is customer-only; moderation is admin-only. Published reviews are
 * readable by any signed-in user on the vehicle they belong to — the payload
 * carries a first name only, never contact details or chauffeur identity.
 */
@ApiTags('reviews')
@ApiBearerAuth()
@Controller('reviews')
export class ReviewsController {
  constructor(private readonly reviewsService: ReviewsService) {}

  @Post()
  @Roles(Role.Customer)
  @ApiOperation({
    summary: 'Review ONE vehicle of your own COMPLETED booking (enters moderation)',
  })
  submit(@CurrentUser() user: AuthenticatedUser, @Body() dto: SubmitReviewDto) {
    return this.reviewsService.submit(dto, user);
  }

  @Get('mine')
  @Roles(Role.Customer)
  @ApiOperation({ summary: 'Your own reviews, with their moderation state' })
  mine(
    @CurrentUser() user: AuthenticatedUser,
    @Query('page') page = '1',
    @Query('limit') limit = '20',
  ) {
    return this.reviewsService.listMine(
      user,
      Math.max(1, Number(page) || 1),
      Math.min(50, Math.max(1, Number(limit) || 20)),
    );
  }

  @Get('pending')
  @Roles(Role.Customer)
  @ApiOperation({
    summary: 'Completed vehicles you have not reviewed yet (drives the rating screen)',
  })
  pending(@CurrentUser() user: AuthenticatedUser) {
    return this.reviewsService.pendingForMe(user.userId);
  }

  @Get('vehicle/:vehicleId')
  @Public()
  @ApiOperation({ summary: 'Published reviews for a vehicle (public aggregates only)' })
  forVehicle(
    @Param('vehicleId', ParseUUIDPipe) vehicleId: string,
    @Query('page') page = '1',
    @Query('limit') limit = '10',
  ) {
    return this.reviewsService.listForVehicle(
      vehicleId,
      Math.max(1, Number(page) || 1),
      Math.min(50, Math.max(1, Number(limit) || 20)),
    );
  }

  // ------------------------------------------------------------ moderation

  @Get('moderation/queue')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Submitted reviews awaiting moderation (oldest first)' })
  moderationQueue() {
    return this.reviewsService.moderationQueue();
  }

  @Post(':id/moderation')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({
    summary: 'PUBLISH | HIDE (reason required) | REOPEN a review — audited',
  })
  moderate(
    @CurrentUser() admin: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ModerationDecisionDto,
  ) {
    return this.reviewsService.moderate(id, dto.action, admin, dto.reason);
  }
}
