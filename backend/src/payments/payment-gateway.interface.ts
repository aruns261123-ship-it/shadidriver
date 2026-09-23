/**
 * Payment gateway abstraction (ADR-013): Razorpay/Cashfree implement this
 * interface behind an isolated adapter. Business code never touches
 * gateway SDKs, and no production credentials may be hard-coded.
 *
 * No gateway is activated in this build: `MOCK_GATEWAY` is for local
 * development only and REFUSES to run in production (fail clearly rather
 * than fake success).
 */
export interface CreateOrderInput {
  bookingId: string;
  amountPaise: number;
  /** Idempotency scope: same key returns the SAME order, never a new one. */
  idempotencyKey: string;
  description?: string;
}

export interface GatewayOrder {
  gateway: string;
  gatewayOrderId: string;
  amountPaise: number;
  currency: string;
}

export interface VerifyPaymentInput {
  gatewayOrderId: string;
  gatewayPaymentId: string;
  /** Provider-signed payload; verified against gateway credentials. */
  signature: string;
}

export interface WebhookEvent {
  /** Raw request body — signature is computed over the exact bytes. */
  rawBody: string;
  signature: string;
}

export interface PaymentGateway {
  readonly name: string;
  createOrder(input: CreateOrderInput): Promise<GatewayOrder>;
  /** Verifies a client-claimed successful payment. Throws on any mismatch. */
  verifyPayment(input: VerifyPaymentInput): Promise<{ verified: boolean; amountPaise: number }>;
  /** Verifies an inbound webhook (HMAC over raw body). */
  verifyWebhook(event: WebhookEvent): { verified: boolean; event_type?: string; order_id?: string };
}
