/**
 * SMS provider abstraction. Concrete providers (MSG91, Twilio, Gupshup…)
 * implement this interface; business code never touches provider SDKs.
 * Missing production credentials must FAIL LOUDLY — never fake success.
 */
export interface SmsSendResult {
  /** Provider-accepted message id (for audit/logs). */
  messageId?: string;
  /** true only when the provider ACCEPTED the message for delivery. */
  accepted: boolean;
}

export interface SmsProvider {
  readonly name: string;
  /**
   * Sends a transactional OTP message to an E.164 phone number.
   * Throws SmsProviderError when credentials are missing, the provider
   * rejects the request, or the network fails — callers must surface that
   * instead of pretending the OTP was sent.
   */
  sendOtp(phoneNumber: string, code: string): Promise<SmsSendResult>;
}

/** Raised for any SMS delivery failure; never swallows into fake success. */
export class SmsProviderError extends Error {
  readonly provider: string;
  readonly retriable: boolean;

  constructor(provider: string, message: string, retriable = false) {
    super(`[${provider}] ${message}`);
    this.name = 'SmsProviderError';
    this.provider = provider;
    this.retriable = retriable;
  }
}
