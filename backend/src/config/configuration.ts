export interface AppConfig {
  env: string;
  port: number;
  apiPrefix: string;
  corsOrigins: string[];
  databaseUrl: string;
  redisUrl?: string;
  jwt: {
    accessSecret: string;
    refreshSecret: string;
    accessTtlSeconds: number;
    refreshTtlSeconds: number;
    issuer: string;
  };
  otp: {
    codeLength: number;
    ttlSeconds: number;
    maxAttempts: number;
    resendCooldownSeconds: number;
    debugLog: boolean;
  };
  enableSwagger: boolean;
  enableRequestLogging: boolean;
}

/**
 * Loads and validates configuration exclusively from environment variables.
 * Fails fast on missing production-critical secrets rather than falling back
 * to insecure defaults (rule 18: fail clearly, no hidden workarounds).
 */
export function loadConfig(): AppConfig {
  const env = process.env.NODE_ENV ?? 'development';
  const isProd = env === 'production';

  const accessSecret = requireEnv('JWT_ACCESS_SECRET', isProd);
  const refreshSecret = requireEnv('JWT_REFRESH_SECRET', isProd);

  return {
    env,
    port: Number(process.env.PORT ?? 3000),
    apiPrefix: process.env.API_PREFIX ?? 'api/v1',
    corsOrigins: (process.env.CORS_ORIGINS ?? 'http://localhost:3000')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
    databaseUrl: requireEnv('DATABASE_URL', isProd),
    redisUrl: process.env.REDIS_URL,
    jwt: {
      accessSecret,
      refreshSecret,
      accessTtlSeconds: Number(process.env.JWT_ACCESS_TTL_SECONDS ?? 900),
      refreshTtlSeconds: Number(process.env.JWT_REFRESH_TTL_SECONDS ?? 1209600),
      issuer: process.env.JWT_ISSUER ?? 'shadidriver.api',
    },
    otp: {
      codeLength: Number(process.env.OTP_CODE_LENGTH ?? 6),
      ttlSeconds: Number(process.env.OTP_TTL_SECONDS ?? 300),
      maxAttempts: Number(process.env.OTP_MAX_ATTEMPTS ?? 3),
      resendCooldownSeconds: Number(process.env.OTP_RESEND_COOLDOWN_SECONDS ?? 30),
      // OTP debug logging is hard-disabled outside development.
      debugLog: (process.env.OTP_DEBUG_LOG ?? 'false') === 'true' && !isProd,
    },
    enableSwagger: (process.env.ENABLE_SWAGGER ?? 'true') === 'true',
    enableRequestLogging: (process.env.ENABLE_REQUEST_LOGGING ?? 'true') === 'true',
  };
}

function requireEnv(name: string, isProd: boolean): string {
  const value = process.env[name];
  if (value && value.length > 0) return value;
  if (isProd) {
    throw new Error(
      `Missing required environment variable ${name}. Refusing to start with insecure defaults in production.`,
    );
  }
  // Development convenience defaults — clearly development-only values.
  const devDefaults: Record<string, string> = {
    JWT_ACCESS_SECRET: 'dev-only-access-secret-change-me-min-32-chars',
    JWT_REFRESH_SECRET: 'dev-only-refresh-secret-change-me-min-32-chars',
    DATABASE_URL:
      'postgresql://shadidriver_admin:shadidriver_secret@localhost:5432/shadidriver?schema=public',
  };
  const fallback = devDefaults[name];
  if (fallback) return fallback;
  throw new Error(`Missing required environment variable ${name}.`);
}

export const CONFIG_TOKEN = 'APP_CONFIG';
