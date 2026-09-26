import {
  CreateOrderInput,
  GatewayOrder,
  PaymentGateway,
  VerifyPaymentInput,
  WebhookEvent,
} from './payment-gateway.interface';
import { createHmac, timingSafeEqual, randomBytes } from 'crypto';

/**
 * DEVELOPMENT-ONLY gateway. Simulates order creation and payment
 * verification locally with an HMAC signature scheme so that the webhook
 * verification path is exercised for real. REFUSES to run in production —
 * configure PAYMENT_GATEWAY=razorpay with real credentials there.
 */
export class MockPaymentGateway implements PaymentGateway {
  readonly name = 'MOCK';
  private readonly secret: string;

  constructor(env: Record<string, string | undefined> = process.env) {
    this.secret = env.PAYMENT_WEBHOOK_SECRET ?? 'dev-only-webhook-secret-change-me';
    if (env.NODE_ENV === 'production' && !env.PAYMENT_GATEWAY?.startsWith('razorpay')) {
      throw new Error(
        'MockPaymentGateway is forbidden in production. Set PAYMENT_GATEWAY=razorpay plus gateway credentials.',
      );
    }
  }

  private readonly orders = new Map<string, GatewayOrder>();

  async createOrder(input: CreateOrderInput): Promise<GatewayOrder> {
    // Idempotent: the same key maps to the same order.
    const existing = this.orders.get(input.idempotencyKey);
    if (existing) return existing;
    const order: GatewayOrder = {
      gateway: this.name,
      gatewayOrderId: `order_${randomBytes(8).toString('hex')}`,
      amountPaise: input.amountPaise,
      currency: 'INR',
    };
    this.orders.set(input.idempotencyKey, order);
    return order;
  }

  async verifyPayment(input: VerifyPaymentInput): Promise<{ verified: boolean; amountPaise: number }> {
    // Client must present HMAC(order_id|payment_id, secret) — the same
    // construction Razorpay uses — so the verification code path is real.
    const expected = createHmac('sha256', this.secret)
      .update(`${input.gatewayOrderId}|${input.gatewayPaymentId}`)
      .digest('hex');
    const ok = this.safeEqual(expected, input.signature);
    if (!ok) {
      // Contract: report failure via the boolean, never by throwing — a raw
      // Error here escapes AppException mapping and surfaces as a 500.
      return { verified: false, amountPaise: 0 };
    }
    const order = [...this.orders.values()].find((o) => o.gatewayOrderId === input.gatewayOrderId);
    return { verified: true, amountPaise: order?.amountPaise ?? 0 };
  }

  verifyWebhook(event: WebhookEvent): { verified: boolean; event_type?: string; order_id?: string } {
    const expected = createHmac('sha256', this.secret).update(event.rawBody).digest('hex');
    if (!this.safeEqual(expected, event.signature)) {
      return { verified: false };
    }
    try {
      const parsed = JSON.parse(event.rawBody) as { event?: string; order_id?: string };
      return { verified: true, event_type: parsed.event, order_id: parsed.order_id };
    } catch {
      return { verified: false };
    }
  }

  /** Signs a payment confirmation — exposed ONLY for the dev harness. */
  devSignPayment(orderId: string, paymentId: string): string {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('devSignPayment is forbidden in production.');
    }
    return createHmac('sha256', this.secret).update(`${orderId}|${paymentId}`).digest('hex');
  }

  private safeEqual(a: string, b: string): boolean {
    const ab = Buffer.from(a);
    const bb = Buffer.from(b);
    return ab.length === bb.length && timingSafeEqual(ab, bb);
  }
}
