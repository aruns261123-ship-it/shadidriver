import { Inject, Injectable } from '@nestjs/common';
import { createHash, randomInt, randomUUID } from 'crypto';
import { PrismaService } from '../../database/prisma.service';
import { CONFIG_TOKEN, AppConfig } from '../../config/configuration';
import {
  ConflictAppException,
  UnauthorizedException,
} from '../errors/auth.exceptions';
import { ErrorCode } from '../../common/errors/error-codes';
import { SMS_PROVIDER } from '../../notifications/sms/sms.factory';
import { SmsProvider, SmsProviderError } from '../../notifications/sms/sms-provider.interface';

export interface OtpSession {
  sessionId: string;
  expiresInSeconds: number;
  resendAvailableInSeconds: number;
}

const OTP_PURPOSE_LOGIN = 'LOGIN';
const OTP_PURPOSE_SIGNUP = 'SIGNUP';

/** Max OTP generations per phone per rolling window (abuse protection). */
const MAX_GENERATIONS_PER_HOUR = 5;
const GENERATION_WINDOW_MINUTES = 60;

/**
 * Issues and verifies OTP codes with production security semantics:
 *  - codes are generated server-side (crypto-secure), stored HASHED
 *  - every new issue invalidates all previous unconsumed codes for the phone
 *  - expiry, resend cooldown, max verification attempts, hourly generation cap
 *  - delivery goes through the configured SmsProvider; delivery failure
 *    FAILS the request loudly (the API never claims an OTP was sent when
 *    the SMS was not accepted)
 */
@Injectable()
export class OtpService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(CONFIG_TOKEN) private readonly config: AppConfig,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider,
  ) {}

  async requestOtp(phoneNumber: string, purpose: 'LOGIN' | 'SIGNUP'): Promise<OtpSession> {
    // 1. Resend cooldown (anti-abuse).
    const recent = await this.prisma.otpCode.findFirst({
      where: {
        phoneNumber,
        purpose,
        createdAt: { gt: new Date(Date.now() - this.config.otp.resendCooldownSeconds * 1000) },
      },
      orderBy: { createdAt: 'desc' },
    });
    if (recent) {
      throw new ConflictAppException(
        ErrorCode.RATE_LIMITED,
        `Please wait ${this.config.otp.resendCooldownSeconds}s before requesting another code.`,
      );
    }

    // 2. Hourly generation cap per phone (abuse protection).
    const windowStart = new Date(Date.now() - GENERATION_WINDOW_MINUTES * 60_000);
    const generated = await this.prisma.otpCode.count({
      where: { phoneNumber, purpose, createdAt: { gt: windowStart } },
    });
    if (generated >= MAX_GENERATIONS_PER_HOUR) {
      throw new ConflictAppException(
        ErrorCode.RATE_LIMITED,
        'Too many OTP requests. Try again later.',
      );
    }

    // 3. Generate a cryptographically secure code (never predictable).
    const code = this.generateCode();
    const codeHash = this.hashCode(code, phoneNumber);
    const sessionId = randomUUID().replace(/-/g, '');

    // 4. Deliver FIRST — if the SMS provider fails, nothing is persisted and
    //    the error propagates. A code that cannot be sent must not verify.
    try {
      await this.sms.sendOtp(phoneNumber, code);
    } catch (err) {
      if (err instanceof SmsProviderError) throw err;
      throw new SmsProviderError(this.sms.name, `Unexpected delivery failure: ${String(err)}`);
    }

    // 5. Invalidate all previous unconsumed codes for this phone+purpose,
    //    then persist the new one.
    await this.prisma.$transaction([
      this.prisma.otpCode.updateMany({
        where: { phoneNumber, purpose, consumedAt: null },
        data: { consumedAt: new Date() },
      }),
      this.prisma.otpCode.create({
        data: {
          sessionId,
          phoneNumber,
          codeHash,
          purpose,
          expiresAt: new Date(Date.now() + this.config.otp.ttlSeconds * 1000),
        },
      }),
    ]);

    // 6. Housekeeping: drop codes stale beyond 1h.
    await this.prisma.otpCode.deleteMany({
      where: { expiresAt: { lt: new Date(Date.now() - 3600_000) } },
    });

    return {
      sessionId,
      expiresInSeconds: this.config.otp.ttlSeconds,
      resendAvailableInSeconds: this.config.otp.resendCooldownSeconds,
    };
  }

  async verifyOtp(
    sessionId: string,
    otpCode: string,
    purpose: 'LOGIN' | 'SIGNUP',
  ): Promise<{ phoneNumber: string }> {
    const record = await this.prisma.otpCode.findUnique({ where: { sessionId } });
    if (!record || record.purpose !== purpose) {
      throw new UnauthorizedException(
        ErrorCode.OTP_SESSION_NOT_FOUND,
        'OTP session not found. Request a new code.',
      );
    }
    if (record.consumedAt) {
      throw new UnauthorizedException(ErrorCode.OTP_SESSION_NOT_FOUND, 'OTP already used.');
    }
    if (record.expiresAt.getTime() < Date.now()) {
      throw new UnauthorizedException(ErrorCode.OTP_EXPIRED, 'This code has expired. Request a new one.');
    }
    if (record.attempts >= this.config.otp.maxAttempts) {
      throw new UnauthorizedException(
        ErrorCode.OTP_MAX_ATTEMPTS,
        'Too many incorrect attempts. Request a new code.',
      );
    }

    const matches = this.hashCode(otpCode, record.phoneNumber) === record.codeHash;
    if (!matches) {
      await this.prisma.otpCode.update({
        where: { id: record.id },
        data: { attempts: { increment: 1 } },
      });
      throw new UnauthorizedException(ErrorCode.INVALID_OTP, 'Incorrect code.', {
        attemptsRemaining: Math.max(0, this.config.otp.maxAttempts - record.attempts - 1),
      });
    }

    await this.prisma.otpCode.update({
      where: { id: record.id },
      data: { consumedAt: new Date() },
    });

    // Housekeeping: drop codes stale beyond 1h.
    await this.prisma.otpCode.deleteMany({
      where: { expiresAt: { lt: new Date(Date.now() - 3600_000) } },
    });

    return { phoneNumber: record.phoneNumber };
  }

  private generateCode(): string {
    const min = 10 ** (this.config.otp.codeLength - 1);
    return String(randomInt(min, min * 10));
  }

  private hashCode(code: string, phone: string): string {
    return createHash('sha256').update(`${phone}:${code}`).digest('hex');
  }
}

export { OTP_PURPOSE_LOGIN, OTP_PURPOSE_SIGNUP };
