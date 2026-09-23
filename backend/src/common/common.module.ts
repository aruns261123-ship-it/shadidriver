import { Module } from '@nestjs/common';
import { APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { EnvelopeInterceptor } from './interceptors/envelope.interceptor';

/**
 * Cross-cutting infrastructure shared by every feature module:
 * response envelope, global rate limiting, validation pipe config.
 */
@Module({
  imports: [
    ThrottlerModule.forRoot([
      {
        ttl: Number(process.env.THROTTLE_TTL_SECONDS ?? 60) * 1000,
        limit: Number(process.env.THROTTLE_LIMIT ?? 100),
      },
    ]),
  ],
  providers: [{ provide: APP_INTERCEPTOR, useClass: EnvelopeInterceptor }, { provide: APP_GUARD, useClass: ThrottlerGuard }],
  exports: [ThrottlerModule],
})
export class CommonModule {}
