import {
  CanActivate,
  ExecutionContext,
  Injectable,
  SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../database/prisma.service';
import { UnauthorizedException as AppUnauthorized } from '../errors/auth.exceptions';
import { ErrorCode } from '../../common/errors/error-codes';
import { AccessTokenPayload, AuthenticatedUser } from '../domain/auth.types';
import { Role } from '../domain/roles';

export const IS_PUBLIC_KEY = 'isPublic';

/** Marks a route as publicly accessible (no bearer token required). */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);

export const REQUEST_USER_KEY = 'authenticatedUser';

/**
 * Self-contained JWT bearer guard (no passport): verifies the access token,
 * re-resolves the authoritative user record on EVERY request, and rejects
 * suspended/deactivated accounts immediately — a suspension takes effect
 * even while previously issued access tokens are still unexpired.
 * Role claims come exclusively from the signed token, never the request.
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic =
      this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
        context.getHandler(),
        context.getClass(),
      ]) ?? false;
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest();
    const header: string | undefined = request.headers?.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      throw new AppUnauthorized(ErrorCode.AUTH_INVALID_TOKEN, 'Missing bearer token.');
    }
    const token = header.slice('Bearer '.length).trim();

    let payload: AccessTokenPayload;
    try {
      payload = await this.jwtService.verifyAsync<AccessTokenPayload>(token);
    } catch {
      throw new AppUnauthorized(
        ErrorCode.AUTH_TOKEN_EXPIRED,
        'Access token is invalid or expired.',
      );
    }
    if (!payload?.sub || !payload?.role) {
      throw new AppUnauthorized(ErrorCode.AUTH_INVALID_TOKEN, 'Malformed token.');
    }

    // Server-authoritative identity: the DB record — not the token claims —
    // decides whether this account may act right now.
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: { accountStatus: true, isActive: true, phoneNumber: true, primaryRole: true },
    });
    if (!user) {
      throw new AppUnauthorized(ErrorCode.AUTH_INVALID_TOKEN, 'Account no longer exists.');
    }
    if (user.accountStatus === 'SUSPENDED' || !user.isActive) {
      throw new AppUnauthorized(ErrorCode.ACCOUNT_SUSPENDED, 'This account is suspended.');
    }

    const authenticated: AuthenticatedUser = {
      userId: payload.sub,
      // Prefer the CURRENT stored role over the token snapshot when both
      // exist; fall back to the token claim for freshly-minted users.
      role: (user.primaryRole as Role) ?? payload.role,
      phoneNumber: user.phoneNumber ?? payload.phone,
      accountStatus: user.accountStatus,
    };
    request[REQUEST_USER_KEY] = authenticated;
    return true;
  }
}
