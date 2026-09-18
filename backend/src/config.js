import './load-env.js';

const settings = {
  gstRate: 0.05,
  platformCommissionRate: 0.2,
  tdsRate: 0.01,
  acceptanceTimeoutMinutes: 30,
  paymentWindowMinutes: 15,
  paymentRetryWindowMinutes: 60,
  geofenceRadiusMeters: 200,
  otpTtlSeconds: 120,
  otpResendSeconds: 30,
  otpMaxPerWindow: 3,
  accessTokenTtlSeconds: 900,
  refreshTokenTtlDays: 30,
  timestampDriftSeconds: 300,
};

export const config = {
  env: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 3000),
  jwtAccessSecret: process.env.JWT_ACCESS_SECRET || 'super_secret_ceremonial_jwt_key_32bytes',
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET || 'super_secret_refresh_jwt_key_32bytes',
  paymentGateway: process.env.PAYMENT_GATEWAY || 'mock',
  paymentWebhookSecret: process.env.PAYMENT_WEBHOOK_SECRET || 'shadi_webhook_secret',
  smsProvider: process.env.SMS_PROVIDER || 'console',
  corsOrigin: process.env.CORS_ORIGIN || '*',
  settings,
};
