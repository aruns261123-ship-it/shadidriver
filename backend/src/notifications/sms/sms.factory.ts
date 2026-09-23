import { SmsProvider } from './sms-provider.interface';
import { Msg91SmsProvider } from './msg91.provider';
import { ConsoleSmsProvider } from './console-sms.provider';
import { SmsProviderError } from './sms-provider.interface';

export const SMS_PROVIDER = 'SMS_PROVIDER';

/**
 * Builds the configured SmsProvider from environment:
 *   SMS_PROVIDER=msg91      → real MSG91 integration (production)
 *   SMS_PROVIDER=console    → development console output (never in production)
 *
 * Missing/unknown configuration fails loudly at startup — the platform
 * refuses to run an OTP flow that cannot actually deliver.
 */
export function createSmsProvider(env: Record<string, string | undefined> = process.env): SmsProvider {
  const provider = (env.SMS_PROVIDER ?? 'console').toLowerCase();
  const isProd = env.NODE_ENV === 'production';

  switch (provider) {
    case 'msg91':
      return new Msg91SmsProvider(env);
    case 'console':
      if (isProd) {
        throw new SmsProviderError(
          'sms',
          'SMS_PROVIDER=console is forbidden in production. Set SMS_PROVIDER=msg91 with real credentials.',
        );
      }
      return new ConsoleSmsProvider();
    default:
      throw new SmsProviderError(
        'sms',
        `Unknown SMS_PROVIDER '${provider}'. Supported: msg91, console (dev only).`,
      );
  }
}
