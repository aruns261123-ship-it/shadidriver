import { Global, Module, Provider } from '@nestjs/common';
import Redis from 'ioredis';
import { CONFIG_TOKEN, AppConfig } from '../config/configuration';

export const REDIS_CLIENT = 'REDIS_CLIENT';

/**
 * Redis is optional infrastructure: the API runs without it (graceful
 * degradation) and uses it when present for rate limiting and ephemeral
 * auth state. Connection failures never crash the process.
 */
const redisProvider: Provider = {
  provide: REDIS_CLIENT,
  inject: [CONFIG_TOKEN],
  useFactory: (config: AppConfig) => {
    if (!config.redisUrl) return undefined;
    const client = new Redis(config.redisUrl, {
      maxRetriesPerRequest: 1,
      retryStrategy: (times) => (times > 3 ? null : Math.min(times * 500, 3000)),
      lazyConnect: true,
      enableOfflineQueue: false,
    });
    client.on('error', () => {
      // Logged by the global logger; swallowed to keep the API alive.
    });
    void client.connect().catch(() => undefined);
    return client;
  },
};

@Global()
@Module({
  providers: [redisProvider],
  exports: [REDIS_CLIENT],
})
export class RedisModule {}
