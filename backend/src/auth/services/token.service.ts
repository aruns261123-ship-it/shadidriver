import { Inject, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { createHash, randomBytes } from 'crypto';
import { PrismaService } from '../../database/prisma.service';
import { CONFIG_TOKEN, AppConfig } from '../../config/configuration';
import { AccessTokenPayload, TokenPair } from '../domain/auth.types';
import { Role } from '../domain/roles';
import { UnauthorizedException } from '../errors/auth.exceptions';
import { ErrorCode } from '../../common/errors/error-codes';

/**
 * Issues short-lived signed access tokens and rotating opaque refresh tokens.
 * Refresh tokens are stored hashed; rotation invalidates the used token so a
 * stolen refresh token cannot be replayed indefinitely.
 */
@Injectable()
export class TokenService {
  constructor(
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
    @Inject(CONFIG_TOKEN) private readonly config: AppConfig,
  ) {}

  async issueTokenPair(
    user: { id: string; phoneNumber: string; primaryRole: Role },
    deviceId?: string,
  ): Promise<TokenPair> {
    const accessToken = await this.signAccessToken(user.id, user.primaryRole, user.phoneNumber);
    const refreshToken = await this.createRefreshToken(user.id, deviceId);
    return {
      accessToken,
      refreshToken,
      accessTokenExpiresIn: this.config.jwt.accessTtlSeconds,
    };
  }

  async signAccessToken(userId: string, role: Role, phone: string): Promise<string> {
    // The `iss` claim is injected by jsonwebtoken via the sign options below —
    // setting it in the payload as well makes jsonwebtoken throw
    // `Bad "options.issuer" option. The payload already has an "iss" property.`
    const payload = {
      sub: userId,
      role,
      phone,
    } satisfies Omit<AccessTokenPayload, 'iss'>;
    return this.jwtService.signAsync(payload, {
      secret: this.config.jwt.accessSecret,
      expiresIn: this.config.jwt.accessTtlSeconds,
      issuer: this.config.jwt.issuer,
    });
  }

  async createRefreshToken(userId: string, deviceId?: string): Promise<string> {
    const raw = randomBytes(48).toString('base64url');
    const tokenHash = this.hashToken(raw);
    await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash,
        deviceId,
        expiresAt: new Date(Date.now() + this.config.jwt.refreshTtlSeconds * 1000),
      },
    });
    return raw;
  }

  /**
   * Validates and rotates a refresh token. The supplied token is revoked and
   * replaced atomically; reuse of a rotated token is rejected. Exactly one
   * new refresh token is minted per rotation.
   */
  async rotateRefreshToken(rawToken: string, deviceId?: string): Promise<{
    userId: string;
    role: Role;
    phoneNumber: string;
    tokens: TokenPair;
  }> {
    const tokenHash = this.hashToken(rawToken);
    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: { user: true },
    });
    if (!stored || stored.revokedAt || stored.expiresAt.getTime() < Date.now()) {
      throw new UnauthorizedException(
        ErrorCode.AUTH_INVALID_TOKEN,
        'Refresh token is invalid or expired. Please sign in again.',
      );
    }
    if (stored.user.accountStatus === 'SUSPENDED' || !stored.user.isActive) {
      throw new UnauthorizedException(ErrorCode.ACCOUNT_SUSPENDED, 'This account is suspended.');
    }

    const newRaw = randomBytes(48).toString('base64url');
    await this.prisma.$transaction(async (tx) => {
      const created = await tx.refreshToken.create({
        data: {
          userId: stored.userId,
          tokenHash: this.hashToken(newRaw),
          deviceId,
          expiresAt: new Date(Date.now() + this.config.jwt.refreshTtlSeconds * 1000),
        },
      });
      await tx.refreshToken.update({
        where: { id: stored.id },
        data: { revokedAt: new Date(), replacedById: created.id },
      });
    });

    const accessToken = await this.signAccessToken(
      stored.user.id,
      stored.user.primaryRole as Role,
      stored.user.phoneNumber,
    );
    return {
      userId: stored.user.id,
      role: stored.user.primaryRole as Role,
      phoneNumber: stored.user.phoneNumber,
      tokens: {
        accessToken,
        refreshToken: newRaw,
        accessTokenExpiresIn: this.config.jwt.accessTtlSeconds,
      },
    };
  }

  async revokeAllForUser(userId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  /** Revokes a single session by the raw (unhashed) refresh token. */
  async revokeByRawToken(rawToken: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash: this.hashToken(rawToken), revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private hashToken(raw: string): string {
    return createHash('sha256').update(raw).digest('hex');
  }
}
