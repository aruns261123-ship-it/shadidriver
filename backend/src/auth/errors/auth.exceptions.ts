import { AppException } from '../../common/errors/app.exception';
import { ErrorCode } from '../../common/errors/error-codes';

export class UnauthorizedException extends AppException {
  constructor(code: ErrorCode, message: string, details?: Record<string, unknown>) {
    super({ code, message, details }, 401);
  }
}

export class ForbiddenAppException extends AppException {
  constructor(code: ErrorCode, message: string, details?: Record<string, unknown>) {
    super({ code, message, details }, 403);
  }
}

export class BadRequestAppException extends AppException {
  constructor(code: ErrorCode, message: string, details?: Record<string, unknown>) {
    super({ code, message, details }, 400);
  }
}

export class ConflictAppException extends AppException {
  constructor(code: ErrorCode, message: string, details?: Record<string, unknown>) {
    super({ code, message, details }, 409);
  }
}

export class NotFoundAppException extends AppException {
  constructor(code: ErrorCode, message: string, details?: Record<string, unknown>) {
    super({ code, message, details }, 404);
  }
}
