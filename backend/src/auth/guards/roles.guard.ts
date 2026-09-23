import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ErrorCode } from '../../common/errors/error-codes';
import { Role } from '../domain/roles';
import { REQUEST_USER_KEY } from './jwt-auth.guard';

export const ROLES_KEY = 'shadiRoles';

/** Restricts a route to the given roles (empty = any authenticated user). */
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);

/**
 * Enforces role-based authorization server-side. The client's role claim is
 * the signed JWT role — never a client-supplied field. Every admin endpoint
 * must be protected with this guard; hiding UI buttons is not security.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<Role[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!required || required.length === 0) return true;

    const request = context.switchToHttp().getRequest();
    const user = request[REQUEST_USER_KEY];
    if (!user) return false;

    if (!required.includes(user.role)) {
      throw new ForbiddenException({
        code: ErrorCode.ROLE_FORBIDDEN,
        message: 'Your role does not have permission to perform this action.',
        details: { required_roles: required, your_role: user.role },
      });
    }
    return true;
  }
}
