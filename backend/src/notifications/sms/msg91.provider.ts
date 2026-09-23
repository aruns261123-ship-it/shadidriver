import { SmsProvider, SmsSendResult, SmsProviderError } from './sms-provider.interface';

/**
 * MSG91 integration — widely used Indian transactional OTP provider
 * (DLT-registered templates required by TRAI regulation).
 *
 * Required environment variables:
 *   SMS_PROVIDER=msg91
 *   SMS_AUTH_KEY=<msg91 auth key>            (MSG91 console -> Settings -> Auth Key)
 *   SMS_OTP_TEMPLATE_ID=<dlt template id>    (DLT-approved OTP template)
 *   SMS_SENDER_ID=<6-char DLT sender>        (e.g. SHADRV, approved header)
 *
 * Optional:
 *   SMS_MSG91_BASE_URL (default https://control.msg91.com/api/v5/otp)
 *
 * Indian numbers: accepts +91XXXXXXXXXX / 91XXXXXXXXXX / XXXXXXXXXX and
 * normalizes to 91XXXXXXXXXX (no leading zero, 10 digits) which is what
 * MSG91 mobiles parameter expects.
 */
export class Msg91SmsProvider implements SmsProvider {
  readonly name = 'msg91';

  private readonly authKey: string;
  private readonly templateId: string;
  private readonly senderId: string;
  private readonly baseUrl: string;

  constructor(env: Record<string, string | undefined> = process.env) {
    this.authKey = env.SMS_AUTH_KEY ?? '';
    this.templateId = env.SMS_OTP_TEMPLATE_ID ?? '';
    this.senderId = env.SMS_SENDER_ID ?? '';
    this.baseUrl = env.SMS_MSG91_BASE_URL ?? 'https://control.msg91.com/api/v5/otp';

    if (!this.authKey || !this.templateId || !this.senderId) {
      throw new SmsProviderError(
        this.name,
        'Missing SMS credentials. Required: SMS_AUTH_KEY, SMS_OTP_TEMPLATE_ID, SMS_SENDER_ID. ' +
          'The platform will NOT pretend an OTP was sent. Configure MSG91 (DLT-approved) credentials in the environment.',
      );
    }
  }

  async sendOtp(phoneNumber: string, code: string): Promise<SmsSendResult> {
    const mobile = Msg91SmsProvider.normalizeIndianMobile(phoneNumber);
    const url = new URL(this.baseUrl);
    url.searchParams.set('template_id', this.templateId);
    url.searchParams.set('mobile', mobile);
    url.searchParams.set('otp', code);
    url.searchParams.set('sender', this.senderId);

    let response: Response;
    try {
      response = await fetch(url.toString(), {
        method: 'POST',
        headers: { authkey: this.authKey, 'Content-Type': 'application/json' },
        body: JSON.stringify({ OTP: code }),
      });
    } catch (err) {
      throw new SmsProviderError(
        this.name,
        `Network failure contacting MSG91: ${err instanceof Error ? err.message : String(err)}`,
        true,
      );
    }

    if (!response.ok) {
      throw new SmsProviderError(
        this.name,
        `MSG91 rejected OTP send (HTTP ${response.status}). Check DLT template/sender approval.`,
        response.status >= 500,
      );
    }

    const body = (await response.json().catch(() => ({}))) as { type?: string; message?: string; request_id?: string };
    // MSG91 returns { type: 'success' | 'error', ... } — treat error type as failure.
    if (body.type && body.type !== 'success') {
      throw new SmsProviderError(this.name, `MSG91 error: ${body.message ?? 'unknown'}`, false);
    }
    return { accepted: true, messageId: body.request_id };
  }

  /** Normalizes Indian mobile numbers to 91XXXXXXXXXX. */
  static normalizeIndianMobile(e164: string): string {
    const digits = e164.replace(/\D/g, '');
    if (digits.length === 10 && /^[6-9]/.test(digits)) return `91${digits}`;
    if (digits.length === 12 && digits.startsWith('91')) return digits;
    if (digits.length === 11 && digits.startsWith('0')) return digits.slice(1);
    throw new SmsProviderError('sms', `Invalid Indian mobile number: ${e164}`);
  }
}
