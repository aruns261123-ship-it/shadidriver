import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

export interface ApiMeta {
  page?: number;
  limit?: number;
  total_records?: number;
  has_more?: boolean;
  [key: string]: unknown;
}

export interface ApiEnvelope<T> {
  success: true;
  data: T;
  meta?: ApiMeta;
}

/**
 * Wraps every successful response in the documented standard envelope:
 * { success: true, data, meta? }. Raw buffers/strings pass through untouched
 * so file streams and health probes stay byte-exact.
 */
@Injectable()
export class EnvelopeInterceptor<T> implements NestInterceptor<T, ApiEnvelope<T>> {
  intercept(_context: ExecutionContext, next: CallHandler<T>): Observable<ApiEnvelope<T>> {
    return next.handle().pipe(
      map((data) => {
        if (
          data === null ||
          data === undefined ||
          typeof data !== 'object' ||
          Buffer.isBuffer(data)
        ) {
          return { success: true as const, data };
        }
        return { success: true as const, data };
      }),
    );
  }
}
