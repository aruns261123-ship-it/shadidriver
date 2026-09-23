import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { ErrorCode } from '../common/errors/error-codes';
import { BadRequestAppException, NotFoundAppException } from '../auth/errors/auth.exceptions';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  /** Customer profile with user identity (server-side join). */
  async getCustomerProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { customerProfile: true },
    });
    if (!user) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'User not found.');
    }
    return {
      id: user.id,
      phone_number: user.phoneNumber,
      full_name: user.fullName,
      email: user.email,
      avatar_url: user.avatarUrl,
      role: user.primaryRole,
      account_status: user.accountStatus,
      is_phone_verified: user.isPhoneVerified,
      customer_profile: user.customerProfile
        ? {
            emergency_contact_name: user.customerProfile.emergencyContactName,
            emergency_contact_phone: user.customerProfile.emergencyContactPhone,
            billing_address: user.customerProfile.billingAddress,
            gstin: user.customerProfile.gstin,
            preferred_language: user.customerProfile.preferredLanguage,
          }
        : null,
    };
  }

  /**
   * Updates editable customer profile fields. Role, account status, and
   * phone verification are NEVER editable through this path.
   */
  async updateCustomerProfile(
    userId: string,
    dto: {
      fullName?: string;
      email?: string;
      emergencyContactName?: string;
      emergencyContactPhone?: string;
      gstin?: string;
      preferredLanguage?: string;
    },
  ) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { customerProfile: true },
    });
    if (!user) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'User not found.');
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: {
          ...(dto.fullName !== undefined ? { fullName: dto.fullName } : {}),
          ...(dto.email !== undefined ? { email: dto.email } : {}),
        },
      });
      const profileData = {
        ...(dto.emergencyContactName !== undefined
          ? { emergencyContactName: dto.emergencyContactName }
          : {}),
        ...(dto.emergencyContactPhone !== undefined
          ? { emergencyContactPhone: dto.emergencyContactPhone }
          : {}),
        ...(dto.gstin !== undefined ? { gstin: dto.gstin } : {}),
        ...(dto.preferredLanguage !== undefined
          ? { preferredLanguage: dto.preferredLanguage }
          : {}),
      };
      if (Object.keys(profileData).length > 0) {
        if (user.customerProfile) {
          await tx.customerProfile.update({ where: { userId }, data: profileData });
        } else {
          await tx.customerProfile.create({ data: { userId, ...profileData } });
        }
      }
    });

    return this.getCustomerProfile(userId);
  }

  /** Driver's own profile (identity + chauffeur details). */
  async getDriverProfile(userId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId },
      include: { user: true, vehicles: { select: { id: true, fleetCode: true } } },
    });
    if (!driver) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Driver profile not found.');
    }
    return {
      id: driver.id,
      user_id: driver.userId,
      phone_number: driver.user.phoneNumber,
      full_name: driver.user.fullName,
      bio: driver.bio,
      experience_years: driver.experienceYears,
      languages_spoken: driver.languagesSpoken,
      // Protected operational fields — read-only for the driver:
      verification_status: driver.verificationStatus,
      duty_status: driver.dutyStatus,
      police_clearance_status: driver.policeClearanceStatus,
      ceremonial_attire_status: driver.ceremonialAttireStatus,
      average_rating: driver.averageRating,
      total_trips_completed: driver.totalTripsCompleted,
      vehicles: driver.vehicles,
    };
  }

  /**
   * Driver self-service profile edit. Bio/experience/languages are editable;
   * verification status, duty status, clearance and ratings are protected
   * operational fields that only platform workflows may change.
   */
  async updateDriverProfile(
    userId: string,
    dto: { bio?: string; experienceYears?: number; languagesSpoken?: string[] },
  ) {
    const driver = await this.prisma.driverProfile.findUnique({ where: { userId } });
    if (!driver) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Driver profile not found.');
    }
    if (dto.experienceYears !== undefined && (dto.experienceYears < 0 || dto.experienceYears > 60)) {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        'Experience years must be between 0 and 60.',
      );
    }
    await this.prisma.driverProfile.update({
      where: { userId },
      data: {
        ...(dto.bio !== undefined ? { bio: dto.bio } : {}),
        ...(dto.experienceYears !== undefined ? { experienceYears: dto.experienceYears } : {}),
        ...(dto.languagesSpoken !== undefined ? { languagesSpoken: dto.languagesSpoken } : {}),
      },
    });
    return this.getDriverProfile(userId);
  }
}
