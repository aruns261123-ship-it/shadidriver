import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { Prisma } from '@prisma/client';
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
 *
 * Prisma known errors are intercepted and mapped to appropriate HTTP codes:
 *   P2000 - value too long for column  → 400 VALIDATION_FAILED
 *   P2002 - unique constraint violation → 409 CONFLICT
 *   P2003 - FK constraint violation     → 400 VALIDATION_FAILED
 *   P2025 - record not found            → 404 NOT_FOUND
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
    } else if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      // Map Prisma known errors to proper HTTP status codes so DB-level
      // constraint violations don't appear as generic 500s.
      switch (exception.code) {
        case 'P2000':
          // "The provided value for the column is too long"
          status = HttpStatus.BAD_REQUEST;
          code = ErrorCode.VALIDATION_FAILED;
          message = `Value too long for field: ${exception.meta?.['column_name'] ?? 'unknown'}.`;
          break;
        case 'P2002':
          // "Unique constraint failed"
          status = HttpStatus.CONFLICT;
          code = ErrorCode.CONFLICT;
          message = 'A record with the same unique key already exists.';
          break;
        case 'P2003':
          // "Foreign key constraint failed"
          status = HttpStatus.BAD_REQUEST;
          code = ErrorCode.VALIDATION_FAILED;
          message = `Referenced record not found: ${exception.meta?.['field_name'] ?? 'unknown'}.`;
          break;
        case 'P2025':
          // "Record to update/delete not found"
          status = HttpStatus.NOT_FOUND;
          code = ErrorCode.NOT_FOUND;
          message = 'The requested record was not found.';
          break;
        default:
          this.logger.error(
            `Prisma error ${exception.code} on ${request.method} ${request.url}`,
            exception.message,
          );
      }
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
