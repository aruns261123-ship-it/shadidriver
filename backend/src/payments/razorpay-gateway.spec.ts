import { RazorpayGateway } from './razorpay-gateway.provider';
import { createHmac } from 'crypto';

/**
 * The Razorpay adapter's verification math must be exactly Razorpay's:
 * HMAC_SHA256(order_id|payment_id, KEY_SECRET) for payments and
 * HMAC_SHA256(rawBody, WEBHOOK_SECRET) for webhooks. No fake success.
 */
describe('RazorpayGateway (real adapter contract)', () => {
  const ENV = {
    PAYMENT_KEY_ID: 'rzp_test_key',
    PAYMENT_KEY_SECRET: 'keysecret',
    PAYMENT_WEBHOOK_SECRET: 'whsec',
  };

  it('refuses to construct without merchant credentials (loud failure)', () => {
    expect(() => new RazorpayGateway({})).toThrow(/PAYMENT_KEY_ID/);
  });

  it('verifies a payment signature exactly as Razorpay computes it', async () => {
    const gateway = new RazorpayGateway(ENV);
    const signature = createHmac('sha256', 'keysecret')
      .update('order_abc|pay_xyz')
      .digest('hex');

    const ok = await gateway.verifyPayment({
      gatewayOrderId: 'order_abc',
      gatewayPaymentId: 'pay_xyz',
      signature,
    });
    expect(ok.verified).toBe(true);

    const bad = await gateway.verifyPayment({
      gatewayOrderId: 'order_abc',
      gatewayPaymentId: 'pay_xyz',
      signature: 'deadbeef',
    });
    expect(bad.verified).toBe(false);
  });

  it('verifies webhook authenticity over the raw body and parses the event', () => {
    const gateway = new RazorpayGateway(ENV);
    const rawBody = JSON.stringify({
      event: 'payment.captured',
      payload: { payment: { entity: { order_id: 'order_abc' } } },
    });
    const signature = createHmac('sha256', 'whsec').update(rawBody).digest('hex');

    const ok = gateway.verifyWebhook({ rawBody, signature });
    expect(ok).toEqual({ verified: true, event_type: 'payment.captured', order_id: 'order_abc' });

    const forged = gateway.verifyWebhook({ rawBody, signature: 'forged' });
    expect(forged.verified).toBe(false);
  });
});
