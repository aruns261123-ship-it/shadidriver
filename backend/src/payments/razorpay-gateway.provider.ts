import {
  CreateOrderInput,
  GatewayOrder,
  PaymentGateway,
  VerifyPaymentInput,
  WebhookEvent,
} from './payment-gateway.interface';
import { createHmac, timingSafeEqual } from 'crypto';

/**
 * REAL Razorpay integration (ADR-013).
 *
 * - createOrder  → POST https://api.razorpay.com/v1/orders (Basic auth with
 *   PAYMENT_KEY_ID / PAYMENT_KEY_SECRET). The returned order id is what the
 *   Flutter client completes against Razorpay Checkout.
 * - verifyPayment → Razorpay's standard HMAC-SHA256 over
 *   `order_id|payment_id` with the KEY SECRET, compared timing-safe.
 * - verifyWebhook → HMAC-SHA256 of the RAW request body with
 *   PAYMENT_WEBHOOK_SECRET, header `x-razorpay-signature`.
 *
 * Missing credentials fail LOUDLY at construction — production never boots a
 * gateway that cannot actually collect money. No fake success path exists.
 */
export class RazorpayGateway implements PaymentGateway {
  readonly name = 'RAZORPAY';
  private readonly keyId: string;
  private readonly keySecret: string;
  private readonly webhookSecret: string;
  private readonly baseUrl: string;

  constructor(env: Record<string, string | undefined> = process.env) {
    this.keyId = env.PAYMENT_KEY_ID ?? '';
    this.keySecret = env.PAYMENT_KEY_SECRET ?? '';
    this.webhookSecret = env.PAYMENT_WEBHOOK_SECRET ?? '';
    this.baseUrl = env.PAYMENT_API_BASE_URL ?? 'https://api.razorpay.com/v1';

    const missing = [
      !this.keyId && 'PAYMENT_KEY_ID',
      !this.keySecret && 'PAYMENT_KEY_SECRET',
      !this.webhookSecret && 'PAYMENT_WEBHOOK_SECRET',
    ].filter(Boolean);
    if (missing.length > 0) {
      throw new Error(
        `RazorpayGateway requires ${missing.join(', ')} in the environment. ` +
          'No payment gateway is activated without real merchant credentials.',
      );
    }
  }

  async createOrder(input: CreateOrderInput): Promise<GatewayOrder> {
    const auth = Buffer.from(`${this.keyId}:${this.keySecret}`).toString('base64');
    let response: Response;
    try {
      response = await fetch(`${this.baseUrl}/orders`, {
        method: 'POST',
        headers: {
          Authorization: `Basic ${auth}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          amount: input.amountPaise, // Razorpay amounts are in paise.
          currency: 'INR',
          receipt: input.idempotencyKey,
          notes: input.description ? { description: input.description } : undefined,
        }),
      });
    } catch (err) {
      throw new Error(`[RAZORPAY] order creation network failure: ${String(err)}`);
    }
    if (!response.ok) {
      const body = await response.text().catch(() => '');
      throw new Error(`[RAZORPAY] order creation failed (${response.status}): ${body.slice(0, 300)}`);
    }
    const data = (await response.json()) as { id: string; amount: number; currency: string };
    return {
      gateway: this.name,
      gatewayOrderId: data.id,
      amountPaise: data.amount,
      currency: data.currency,
    };
  }

  async verifyPayment(input: VerifyPaymentInput): Promise<{ verified: boolean; amountPaise: number }> {
    // Razorpay Checkout hands the client `razorpay_signature` =
    // HMAC_SHA256(order_id + "|" + payment_id, key_secret). Recompute and
    // compare timing-safely; a mismatch reports unverified — never throws
    // into a 500 and never fakes success.
    const expected = createHmac('sha256', this.keySecret)
      .update(`${input.gatewayOrderId}|${input.gatewayPaymentId}`)
      .digest('hex');
    const ok = this.safeEqual(expected, input.signature);
    if (!ok) return { verified: false, amountPaise: 0 };

    const amount = await this.fetchOrderAmount(input.gatewayOrderId);
    return { verified: true, amountPaise: amount };
  }

  verifyWebhook(event: WebhookEvent): { verified: boolean; event_type?: string; order_id?: string } {
    const expected = createHmac('sha256', this.webhookSecret).update(event.rawBody).digest('hex');
    if (!this.safeEqual(expected, event.signature)) {
      return { verified: false };
    }
    try {
      const parsed = JSON.parse(event.rawBody) as {
        event?: string;
        payload?: { payment?: { entity?: { order_id?: string } } };
      };
      return {
        verified: true,
        event_type: parsed.event,
        order_id: parsed.payload?.payment?.entity?.order_id,
      };
    } catch {
      return { verified: false };
    }
  }

  /** Server-side amount confirmation from the order row (authoritative). */
  private async fetchOrderAmount(orderId: string): Promise<number> {
    const auth = Buffer.from(`${this.keyId}:${this.keySecret}`).toString('base64');
    try {
      const response = await fetch(`${this.baseUrl}/orders/${orderId}`, {
        headers: { Authorization: `Basic ${auth}` },
      });
      if (!response.ok) return 0;
      const data = (await response.json()) as { amount?: number };
      return data.amount ?? 0;
    } catch {
      return 0;
    }
  }

  private safeEqual(a: string, b: string): boolean {
    const ab = Buffer.from(a, 'utf8');
    const bb = Buffer.from(b, 'utf8');
    if (ab.length !== bb.length) return false;
    return timingSafeEqual(ab, bb);
  }
}
