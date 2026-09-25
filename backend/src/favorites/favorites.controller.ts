import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ArrayMaxSize, IsArray, IsString } from 'class-validator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthenticatedUser } from '../auth/domain/auth.types';
import { Role } from '../auth/domain/roles';
import { Roles } from '../auth/guards/roles.guard';
import { FavoritesService, MAX_FAVORITES } from './favorites.service';

class MergeFavoritesDto {
  /**
   * The signed-out visitor's local shortlist. Unknown/unlisted ids are ignored
   * and echoed back in `ignored_vehicle_ids`.
   */
  @IsArray()
  @ArrayMaxSize(MAX_FAVORITES)
  @IsString({ each: true })
  vehicleIds!: string[];
}

/**
 * Persistent favourites, scoped to the authenticated customer. Guests may keep
 * a local shortlist only — nothing is persisted until they have an account.
 */
@ApiTags('favorites')
@ApiBearerAuth()
@Roles(Role.Customer)
@Controller('favorites')
export class FavoritesController {
  constructor(private readonly favoritesService: FavoritesService) {}

  @Get()
  @ApiOperation({ summary: 'List the caller’s saved vehicles (public projection)' })
  list(@CurrentUser() user: AuthenticatedUser) {
    return this.favoritesService.list(user.userId);
  }

  // Declared before ':vehicleId' so POST /favorites/merge is not captured as a
  // vehicle id.
  @Post('merge')
  @HttpCode(200)
  @ApiOperation({ summary: 'Merge a guest shortlist into the account (idempotent)' })
  merge(@CurrentUser() user: AuthenticatedUser, @Body() dto: MergeFavoritesDto) {
    return this.favoritesService.merge(user.userId, dto.vehicleIds);
  }

  @Post(':vehicleId')
  @HttpCode(200)
  @ApiOperation({ summary: 'Save a vehicle (idempotent)' })
  add(
    @CurrentUser() user: AuthenticatedUser,
    @Param('vehicleId') vehicleId: string,
  ) {
    return this.favoritesService.add(user.userId, vehicleId);
  }

  @Delete(':vehicleId')
  @HttpCode(200)
  @ApiOperation({ summary: 'Remove a saved vehicle (idempotent)' })
  remove(
    @CurrentUser() user: AuthenticatedUser,
    @Param('vehicleId') vehicleId: string,
  ) {
    return this.favoritesService.remove(user.userId, vehicleId);
  }
}
