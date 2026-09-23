import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { AuthenticatedUser } from '../domain/auth.types';
import { REQUEST_USER_KEY } from '../guards/jwt-auth.guard';

/** Injects the authenticated user (from the JWT guard) into a handler. */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AuthenticatedUser => {
    const request = ctx.switchToHttp().getRequest();
    return request[REQUEST_USER_KEY] as AuthenticatedUser;
  },
);
