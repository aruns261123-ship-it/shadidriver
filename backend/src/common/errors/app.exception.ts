import { HttpException, HttpStatus } from '@nestjs/common';
import { ErrorCode } from './error-codes';

export interface AppErrorBody {
  code: ErrorCode;
  message: string;
  details?: Record<string, unknown>;
}

/**
 * Domain exception carrying a machine-readable code per the documented
 * error taxonomy. Rendered by the global exception filter into the
 * { success: false, error: { code, message, details } } envelope.
 */
export class AppException extends HttpException {
  readonly code: ErrorCode;
  readonly details?: Record<string, unknown>;

  constructor(body: AppErrorBody, status: HttpStatus) {
    super({ code: body.code, message: body.message, details: body.details }, status);
    this.code = body.code;
    this.details = body.details;
  }
}

export class BadRequestException extends AppException {
  constructor(code: ErrorCode, message: string, details?: Record<string, unknown>) {
    super({ code, message, details }, HttpStatus.BAD_REQUEST);
  }
}

export class UnauthorizedException extends AppException {
  constructor(code: ErrorCode, message: string, details?: Record<string, unknown>) {
    super({ code, message, details }, HttpStatus.UNAUTHORIZED);
  }
}

export class ForbiddenException extends AppException {
  constructor(code: ErrorCode, message: string, details?: Record<string, unknown>) {
    super({ code, message, details }, HttpStatus.FORBIDDEN);
  }
}

export class NotFoundException extends AppException {
  constructor(code: ErrorCode, message: string, details?: Record<string, unknown>) {
    super({ code, message, details }, HttpStatus.NOT_FOUND);
  }
}

export class ConflictException extends AppException {
  constructor(code: ErrorCode, message: string, details?: Record<string, unknown>) {
    super({ code, message, details }, HttpStatus.CONFLICT);
  }
}

export class TooManyRequestsException extends AppException {
  constructor(code: ErrorCode, message: string, details?: Record<string, unknown>) {
    super({ code, message, details }, HttpStatus.TOO_MANY_REQUESTS);
  }
}

export class InternalException extends AppException {
  constructor(message = 'An unexpected internal error occurred.') {
    super({ code: ErrorCode.INTERNAL_ERROR, message }, HttpStatus.INTERNAL_SERVER_ERROR);
  }
}
