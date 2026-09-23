import { SmsProvider, SmsSendResult } from './sms-provider.interface';

/**
 * Development-only provider: prints the OTP to the SERVER console with an
 * unmistakable prefix. It NEVER returns accepted:true silently in production
 * — the factory refuses to construct it when NODE_ENV=production.
 * This is not a fake-success path: developers see exactly where the OTP is.
 */
export class ConsoleSmsProvider implements SmsProvider {
  readonly name = 'console-dev';

  async sendOtp(phoneNumber: string, code: string): Promise<SmsSendResult> {
    if (process.env.NODE_ENV === 'production') {
      // Fail loudly rather than deliver codes via logs in production.
      throw new Error(
        'ConsoleSmsProvider is forbidden in production. Configure SMS_PROVIDER=msg91 with real credentials.',
      );
    }
    console.warn(
      `\n====================================================================\n` +
        `  [DEV SMS → ${phoneNumber}]\n` +
        `  Your ShadiDriver verification code is: ${code}\n` +
        `====================================================================\n`,
    );
    return { accepted: true, messageId: `dev-${Date.now()}` };
  }
}
