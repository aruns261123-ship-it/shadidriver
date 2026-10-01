import { Inject, Injectable, Logger } from '@nestjs/common';
import { createPublicKey, randomInt } from 'crypto';
import * as jwt from 'jsonwebtoken';
import { PrismaService } from '../../database/prisma.service';
import { CONFIG_TOKEN, AppConfig } from '../../config/configuration';
import { TokenService } from './token.service';
import { Role } from '../domain/roles';
import { AuthResult } from '../auth.service';
import {
  BadRequestAppException,
  UnauthorizedException,
} from '../errors/auth.exceptions';
import { ErrorCode } from '../../common/errors/error-codes';
import { SmsProvider } from '../../notifications/sms/sms-provider.interface';
import { SMS_PROVIDER } from '../../notifications/sms/sms.factory';

/**
 * REAL Google customer sign-in, inside the EXISTING auth architecture.
 *
 * The client obtains a Google ID token (google_sign_in on Android/iOS).
 * This service is the ONLY authority: it fetches Google's published JWKS,
 * verifies the RS256 signature, issuer, audience (our OAuth client ID) and
 * expiry, then maps/creates the customer on the SAME users table the OTP
 * flow uses and issues the SAME TokenService session (JWT + rotating
 * refresh token).
 *
 * NO client secrets exist server-side. The audience check pins tokens to
 * OUR OAuth client IDs — tokens minted for anyone else's app are rejected.
 * When GOOGLE_ANDROID_CLIENT_ID / GOOGLE_IOS_CLIENT_ID / GOOGLE_WEB_CLIENT_ID
 * are unset the endpoint is disabled (501-style NOT_CONFIGURED) — Google
 * success is NEVER faked.
 */
@Injectable()
export class GoogleAuthService {
  private static readonly GOOGLE_ISSUERS = ['https://accounts.google.com', 'accounts.google.com'];
  private static readonly JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs';

  private readonly logger = new Logger(GoogleAuthService.name);
  /** kid → PEM + algorithm, cached with expiry. */
  private jwksCache: {
    keys: Map<string, { pem: string; alg?: string }>;
    expiresAt: number;
  } | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly tokenService: TokenService,
    @Inject(CONFIG_TOKEN) private readonly config: AppConfig,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider,
  ) {}

  /** Configured OAuth client IDs (audience allow-list). Empty = not configured. */
  private get configuredClientIds(): string[] {
    return [
      process.env.GOOGLE_ANDROID_CLIENT_ID,
      process.env.GOOGLE_IOS_CLIENT_ID,
      process.env.GOOGLE_WEB_CLIENT_ID,
    ]
      .filter((v): v is string => !!v && v.trim().length > 0)
      .map((v) => v.trim());
  }

  get isConfigured(): boolean {
    return this.configuredClientIds.length > 0;
  }

  private assertConfigured(): void {
    if (!this.isConfigured) {
      throw new UnauthorizedException(
        ErrorCode.AUTH_INVALID_TOKEN,
        'Google sign-in is not configured on this deployment: set GOOGLE_ANDROID_CLIENT_ID / GOOGLE_IOS_CLIENT_ID / GOOGLE_WEB_CLIENT_ID (the OAuth client IDs that issue the app’s ID tokens). No credentials are stored in the repository.',
      );
    }
  }

  async signInWithIdToken(idToken: string, deviceId?: string): Promise<AuthResult> {
    this.assertConfigured();

    const payload = await this.verifyIdToken(idToken);
    const googleId = payload.sub;
    const email = payload.email?.toLowerCase() ?? null;
    if (!googleId) {
      throw new UnauthorizedException(ErrorCode.AUTH_INVALID_TOKEN, 'Google token has no subject.');
    }
    // `email_verified` is what makes an email a safe linking key. Absent or
    // false → never link, never trust.
    const emailVerified = payload.email_verified === true || payload.email_verified === 'true';

    // ---- link or create on the SAME identity table as the OTP flow --------
    let user = await this.prisma.user.findUnique({ where: { googleId } });

    if (!user && email && emailVerified) {
      const byEmail = await this.prisma.user.findFirst({
        where: { email },
        orderBy: { createdAt: 'asc' },
      });
      if (byEmail) {
        // Existing customer converging identity channels (Google ↔ OTP).
        // The Google `sub` is immutable and becomes the second credential.
        user = await this.prisma.user.update({
          where: { id: byEmail.id },
          data: {
            googleId,
            authProvider: 'GOOGLE',
            avatarUrl: payload.picture ?? byEmail.avatarUrl,
            fullName: byEmail.fullName ?? payload.name ?? null,
          },
        });
      }
    }

    if (!user) {
      // Brand-new Google customer. phoneNumber is NOT NULL UNIQUE (15 chars):
      // a Google-only account reserves a synthetic, clearly-non-routable
      // placeholder that can never collide with a real Indian mobile number.
      let placeholder: string;
      do {
        placeholder = `+9100000${String(randomInt(0, 1_000_000)).padStart(6, '0')}`;
      } while (await this.prisma.user.findUnique({ where: { phoneNumber: placeholder } }));
      user = await this.prisma.user.create({
        data: {
          phoneNumber: placeholder,
          email: emailVerified ? email : null,
          fullName: payload.name ?? null,
          avatarUrl: payload.picture ?? null,
          googleId,
          authProvider: 'GOOGLE',
          primaryRole: Role.Customer,
          isPhoneVerified: false,
        },
      });
    }

    if (user.accountStatus === 'SUSPENDED' || !user.isActive) {
      throw new UnauthorizedException(ErrorCode.ACCOUNT_SUSPENDED, 'This account is suspended.');
    }

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
        isNewUser: false,
      },
    };
  }

  /** Fetch + cache Google's public JWKS (5-minute TTL). */
  private async getGoogleSigningKeys(): Promise<Map<string, { pem: string; alg?: string }>> {
    if (this.jwksCache && this.jwksCache.expiresAt > Date.now()) {
      return this.jwksCache.keys;
    }
    const res = await fetch(GoogleAuthService.JWKS_URL, { signal: AbortSignal.timeout(5_000) });
    if (!res.ok) {
      throw new UnauthorizedException(
        ErrorCode.AUTH_INVALID_TOKEN,
        'Unable to reach Google key service to verify the sign-in.',
      );
    }
    const jwks = (await res.json()) as {
      keys: Array<{ kid: string; kty: string; alg?: string; n: string; e: string }>;
    };
    const keys = new Map<string, { pem: string; alg?: string }>();
    for (const jwk of jwks.keys ?? []) {
      if (jwk.kty !== 'RSA') continue;
      try {
        const pem = createPublicKey({ key: jwk as never, format: 'jwk' }).export({
          type: 'spki',
          format: 'pem',
        }) as string;
        keys.set(jwk.kid, { pem, alg: jwk.alg });
      } catch {
        // Unparseable key — skip it; signature verification will reject.
      }
    }
    this.jwksCache = { keys, expiresAt: Date.now() + 5 * 60_000 };
    return keys;
  }

  /**
   * Verifies signature (Google JWKS), issuer, audience (OUR client IDs) and
   * expiry. Returns the verified payload; throws Unauthorized on any failure.
   */
  private async verifyIdToken(
    idToken: string,
  ): Promise<{
    sub: string;
    email?: string;
    email_verified?: boolean | 'true' | 'false';
    name?: string;
    picture?: string;
  }> {
    const clientIds = this.configuredClientIds;
    const decodeResult = jwt.decode(idToken, { complete: true });
    if (!decodeResult || typeof decodeResult === 'string') {
      throw new UnauthorizedException(ErrorCode.AUTH_INVALID_TOKEN, 'Malformed Google token.');
    }
    const kid = decodeResult.header.kid;
    const keys = await this.getGoogleSigningKeys();
    const key = kid ? keys.get(kid) : undefined;
    if (!key) {
      throw new UnauthorizedException(
        ErrorCode.AUTH_INVALID_TOKEN,
        'Google signing key not recognised (kid unknown).',
      );
    }

    let payload: unknown;
    const audiences: [string, ...string[]] =
      clientIds.length === 1 ? [clientIds[0]] : [clientIds[0], ...clientIds.slice(1)];
    try {
      payload = jwt.verify(idToken, key.pem, {
        algorithms: ['RS256'],
        audience: audiences,
        issuer: [...GoogleAuthService.GOOGLE_ISSUERS] as [string, ...string[]],
        clockTolerance: 60,
      });
    } catch {
      throw new UnauthorizedException(
        ErrorCode.AUTH_INVALID_TOKEN,
        'Google sign-in could not be verified (signature, audience, or expiry).',
      );
    }
    const p = payload as {
      sub: string;
      email?: string;
      email_verified?: boolean | 'true' | 'false';
      name?: string;
      picture?: string;
    };
    if (!p.sub) {
      throw new UnauthorizedException(ErrorCode.AUTH_INVALID_TOKEN, 'Google token has no subject.');
    }
    return p;
  }

  /**
   * Links a Google identity to the CURRENTLY AUTHENTICATED user (account
   * settings). Idempotent; refuses to move a googleId already owned by
   * another account.
   */
  async linkToUser(userId: string, idToken: string): Promise<{ linked: true }> {
    this.assertConfigured();
    const payload = await this.verifyIdToken(idToken);
    const clash = await this.prisma.user.findUnique({ where: { googleId: payload.sub } });
    if (clash && clash.id !== userId) {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        'This Google account is already linked to another ShadiDriver account.',
      );
    }
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        googleId: payload.sub,
        authProvider: 'GOOGLE',
        avatarUrl: payload.picture ?? undefined,
      },
    });
    return { linked: true };
  }

  /** Reserved for a future SMS-binding step; keeps the SMS dependency wired. */
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  private noopSmsReference(): void {
    void this.sms;
  }
}
