import { Body, Controller, Get, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthenticatedUser } from '../auth/domain/auth.types';
import { Role } from '../auth/domain/roles';
import { Roles } from '../auth/guards/roles.guard';
import { UsersService } from './users.service';
import { UpdateCustomerProfileDto, UpdateDriverProfileDto } from './dto/users.dto';

@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('profile')
  @ApiOperation({ summary: "Fetch the caller's profile (customer or driver shape)" })
  getProfile(@CurrentUser() user: AuthenticatedUser) {
    if (user.role === Role.Driver) return this.usersService.getDriverProfile(user.userId);
    return this.usersService.getCustomerProfile(user.userId);
  }

  @Patch('profile')
  @ApiOperation({ summary: "Update the caller's editable profile fields" })
  updateProfile(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UpdateCustomerProfileDto & UpdateDriverProfileDto,
  ) {
    if (user.role === Role.Driver) {
      return this.usersService.updateDriverProfile(user.userId, {
        bio: dto.bio,
        experienceYears: dto.experienceYears,
        languagesSpoken: dto.languagesSpoken,
      });
    }
    return this.usersService.updateCustomerProfile(user.userId, {
      fullName: dto.fullName,
      email: dto.email,
      emergencyContactName: dto.emergencyContactName,
      emergencyContactPhone: dto.emergencyContactPhone,
      gstin: dto.gstin,
      preferredLanguage: dto.preferredLanguage,
    });
  }

  @Get('driver/me')
  @Roles(Role.Driver)
  @ApiOperation({ summary: 'Driver-only profile endpoint' })
  getDriverMe(@CurrentUser() user: AuthenticatedUser) {
    return this.usersService.getDriverProfile(user.userId);
  }
}
