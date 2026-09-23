import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { AppException } from '../errors/app.exception';
import { ErrorCode } from '../errors/error-codes';

interface ErrorResponseBody {
  success: false;
  error: {
    code: ErrorCode;
    message: string;
    details?: Record<string, unknown>;
  };
  meta: {
    request_id?: string;
    timestamp: string;
  };
}

/**
 * Renders every error (domain, HTTP, validation, unknown) into the
 * standardized error envelope. Never leaks stack traces or secrets;
 * unexpected errors are logged server-side with the correlation ID.
 */
@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request & { id?: string; correlationId?: string }>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let code: ErrorCode = ErrorCode.INTERNAL_ERROR;
    let message = 'An unexpected internal error occurred.';
    let details: Record<string, unknown> | undefined;

    if (exception instanceof AppException) {
      status = exception.getStatus();
      const body = exception.getResponse() as { code: ErrorCode; message: string; details?: Record<string, unknown> };
      code = body.code;
      message = body.message;
      details = body.details;
    } else if (exception instanceof HttpException) {
      status = exception.getStatus();
      const res = exception.getResponse();
      if (typeof res === 'string') {
        message = res;
        code = defaultCodeForStatus(status);
      } else if (typeof res === 'object' && res !== null) {
        const r = res as Record<string, unknown>;
        message = typeof r.message === 'string' ? r.message : Array.isArray(r.message) ? r.message.join('; ') : message;
        code = typeof r.code === 'string' ? (r.code as ErrorCode) : defaultCodeForStatus(status);
        if (r.details !== undefined) details = r.details as Record<string, unknown>;
        // class-validator arrays
        if (Array.isArray(r.message)) details = { validation: r.message };
      }
    } else {
      this.logger.error(
        `Unhandled exception on ${request.method} ${request.url}`,
        exception instanceof Error ? exception.stack : String(exception),
      );
    }

    const body: ErrorResponseBody = {
      success: false,
      error: { code, message, ...(details ? { details } : {}) },
      meta: {
        request_id: request.id ?? request.correlationId,
        timestamp: new Date().toISOString(),
      },
    };

    response.status(status).json(body);
  }
}

function defaultCodeForStatus(status: HttpStatus): ErrorCode {
  switch (status) {
    case HttpStatus.BAD_REQUEST:
      return ErrorCode.VALIDATION_FAILED;
    case HttpStatus.UNAUTHORIZED:
      return ErrorCode.AUTH_INVALID_TOKEN;
    case HttpStatus.FORBIDDEN:
      return ErrorCode.ROLE_FORBIDDEN;
    case HttpStatus.NOT_FOUND:
      return ErrorCode.NOT_FOUND;
    case HttpStatus.CONFLICT:
      return ErrorCode.CONFLICT;
    case HttpStatus.TOO_MANY_REQUESTS:
      return ErrorCode.RATE_LIMITED;
    default:
      return ErrorCode.INTERNAL_ERROR;
  }
}
