import { Inject, Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { CONFIG_TOKEN, AppConfig } from '../config/configuration';
import { OtpService } from './services/otp.service';
import { TokenService } from './services/token.service';
import { Role } from './domain/roles';
import { TokenPair } from './domain/auth.types';
import {
  BadRequestAppException,
  ConflictAppException,
  UnauthorizedException,
} from './errors/auth.exceptions';
import { ErrorCode } from '../common/errors/error-codes';

export interface AuthResult extends TokenPair {
  user: {
    id: string;
    phoneNumber: string;
    fullName: string | null;
    role: Role;
    accountStatus: string;
    isNewUser: boolean;
  };
}

/**
 * Phone-OTP authentication with server-authoritative role resolution.
 * Roles always come from the stored user record — the client can never
 * assert a role. Admin accounts cannot be created through this flow.
 */
@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly otpService: OtpService,
    private readonly tokenService: TokenService,
    @Inject(CONFIG_TOKEN) private readonly config: AppConfig,
  ) {}

  async requestOtp(phoneNumber: string, purpose: 'LOGIN' | 'SIGNUP') {
    return this.otpService.requestOtp(phoneNumber, purpose);
  }

  async signUp(phoneNumber: string, displayName: string, role: 'customer' | 'driver') {
    const existing = await this.prisma.user.findUnique({ where: { phoneNumber } });
    if (existing) {
      throw new ConflictAppException(
        ErrorCode.PHONE_ALREADY_REGISTERED,
        'This phone number is already registered. Please sign in.',
      );
    }
    if (role === ('operationsAdmin' as never)) {
      // Unreachable by DTO validation; defense-in-depth per rule 8.
      throw new BadRequestAppException(
        ErrorCode.ADMIN_REGISTRATION_PROHIBITED,
        'Admin accounts are provisioned internally.',
      );
    }

    // Create a minimal unverified user so OTP verification can attach to it.
    await this.prisma.user.create({
      data: {
        phoneNumber,
        fullName: displayName,
        primaryRole: role === 'driver' ? Role.Driver : Role.Customer,
        isPhoneVerified: false,
        accountStatus: 'ACTIVE',
      },
    });

    const session = await this.otpService.requestOtp(phoneNumber, 'SIGNUP');
    return { sessionId: session.sessionId, expiresInSeconds: session.expiresInSeconds };
  }

  async verifyOtp(sessionId: string, otpCode: string, deviceId?: string): Promise<AuthResult> {
    // Determine purpose from the stored session.
    const pending = await this.prisma.otpCode.findUnique({ where: { sessionId } });
    const purpose = (pending?.purpose as 'LOGIN' | 'SIGNUP' | undefined) ?? 'LOGIN';

    const { phoneNumber } = await this.otpService.verifyOtp(sessionId, otpCode, purpose);

    let user = await this.prisma.user.findUnique({
      where: { phoneNumber },
      include: { driverProfile: true },
    });

    if (!user) {
      // First login on an unregistered number: provision a customer account.
      user = await this.prisma.user.create({
        data: {
          phoneNumber,
          primaryRole: Role.Customer,
          isPhoneVerified: true,
        },
        include: { driverProfile: true },
      });
    } else {
      if (user.accountStatus === 'SUSPENDED' || !user.isActive) {
        throw new UnauthorizedException(ErrorCode.ACCOUNT_SUSPENDED, 'This account is suspended.');
      }
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: { isPhoneVerified: true },
        include: { driverProfile: true },
      });
    }

    const isNewUser = purpose === 'SIGNUP';
    const tokens = await this.tokenService.issueTokenPair(
      { id: user.id, phoneNumber: user.phoneNumber, primaryRole: user.primaryRole as Role },
      deviceId,
    );

    return {
      ...tokens,
      user: {
        id: user.id,
        phoneNumber: user.phoneNumber,
        fullName: user.fullName,
        role: user.primaryRole as Role,
        accountStatus: user.accountStatus,
        isNewUser,
      },
    };
  }

  async refreshSession(refreshToken: string, deviceId?: string): Promise<AuthResult> {
    const rotated = await this.tokenService.rotateRefreshToken(refreshToken, deviceId);
    const user = await this.prisma.user.findUnique({ where: { id: rotated.userId } });
    if (!user) {
      throw new UnauthorizedException(ErrorCode.AUTH_INVALID_TOKEN, 'Session user no longer exists.');
    }
    return {
      ...rotated.tokens,
      user: {
        id: user.id,
        phoneNumber: user.phoneNumber,
        fullName: user.fullName,
        role: user.primaryRole as Role,
        accountStatus: user.accountStatus,
        isNewUser: false,
      },
    };
  }

  async logout(refreshToken: string | undefined, userId?: string): Promise<void> {
    if (userId) {
      await this.tokenService.revokeAllForUser(userId);
      return;
    }
    // Unauthenticated logout: revoke the presented refresh token only,
    // by computing its hash through the same TokenService path.
    if (refreshToken) {
      await this.tokenService.revokeByRawToken(refreshToken);
    }
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        phoneNumber: true,
        fullName: true,
        avatarUrl: true,
        primaryRole: true,
        accountStatus: true,
        isPhoneVerified: true,
      },
    });
    if (!user) {
      throw new UnauthorizedException(ErrorCode.AUTH_INVALID_TOKEN, 'User no longer exists.');
    }
    return { ...user, role: user.primaryRole };
  }
}


