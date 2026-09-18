import { config } from '../config.js';
import { AppError, HttpStatus } from '../errors.js';
import { store } from '../store/memory-store.js';
import { hmacSha256, newId, timingSafeEqualHex } from '../utils/crypto.js';
import { pick } from '../utils/body.js';
import { ROLES } from '../domain/roles.js';
import { ACTIONS, BOOKING_STATUS } from '../domain/booking-status.js';
import { bookingsService } from './bookings.service.js';
import { notify } from './notifications.service.js';

function loadOwnedBooking(user, bookingId) {
  const booking = bookingsService.loadBooking(bookingId);
  bookingsService.assertCanRead(user, booking);
  return booking;
}

function createOrderRecord(booking, paymentType) {
  const orderId = `order_${newId().replace(/-/g, '').slice(0, 14)}`;
  const payment = {
    id: newId(),
    orderId,
    bookingId: booking.id,
    paymentType,
    amountCents: booking.advanceTokenPaise,
    currency: 'INR',
    status: 'INITIATED',
    gateway: 'mock',
    keyId: 'rzp_test_shadidriver',
    createdAt: new Date().toISOString(),
  };
  store.payments.set(orderId, payment);
  booking.gatewayOrderId = orderId;
  return payment;
}

function capture(booking, payment, actorRole = ROLES.SYSTEM) {
  const from = booking.status;
  if (![BOOKING_STATUS.PAYMENT_PENDING, BOOKING_STATUS.DRIVER_ACCEPTED, BOOKING_STATUS.PAYMENT_FAILED].includes(booking.status)) {
    if (booking.status === BOOKING_STATUS.CONFIRMED) return { alreadyConfirmed: true, booking };
  }
  payment.status = 'CAPTURED';
  payment.capturedAt = new Date().toISOString();
  booking.isAdvancePaid = true;
  booking.status = BOOKING_STATUS.CONFIRMED;
  booking.version += 1;
  booking.updatedAt = new Date().toISOString();
  bookingsService.appendEvent(booking.id, from, BOOKING_STATUS.CONFIRMED, booking.customerId, actorRole, 'PAYMENT_TOKEN_CAPTURED', {
    orderId: payment.orderId,
  });
  notify(booking.customerId, 'Booking confirmed', `Advance token captured. Reference ${booking.referenceCode} is secured.`, {
    bookingId: booking.id,
  });
  return payment;
}

export const paymentsService = {
  createOrder(user, body, idempotencyKey) {
    const bookingId = pick(body, 'bookingId', 'booking_id');
    const paymentType = pick(body, 'paymentType', 'payment_type') || 'ADVANCE_TOKEN';
    const booking = loadOwnedBooking(user, bookingId);
    if (user.role !== 'customer' && user.role !== 'superAdmin') {
      throw new AppError('ROLE_FORBIDDEN', 'Only the customer can create a payment order.', HttpStatus.FORBIDDEN);
    }
    if (idempotencyKey) {
      for (const payment of store.payments.values()) {
        if (payment.idempotencyKey === idempotencyKey) {
          return {
            orderId: payment.orderId,
            bookingId: payment.bookingId,
            amountCents: payment.amountCents,
            currency: payment.currency,
            status: payment.status,
            keyId: payment.keyId,
            gateway: payment.gateway,
          };
        }
      }
    }
    if (![BOOKING_STATUS.DRIVER_ACCEPTED, BOOKING_STATUS.PAYMENT_FAILED, BOOKING_STATUS.PAYMENT_PENDING].includes(booking.status)) {
      if (booking.status === BOOKING_STATUS.REQUESTED) {
        throw new AppError('INVALID_TRANSITION', 'Chauffeur must accept before payment.', HttpStatus.CONFLICT);
      }
    }
    if (booking.status === BOOKING_STATUS.DRIVER_ACCEPTED || booking.status === BOOKING_STATUS.PAYMENT_FAILED) {
      const from = booking.status;
      booking.status = BOOKING_STATUS.PAYMENT_PENDING;
      booking.version += 1;
      booking.updatedAt = new Date().toISOString();
      bookingsService.appendEvent(
        booking.id,
        from,
        BOOKING_STATUS.PAYMENT_PENDING,
        user.id,
        user.role,
        from === BOOKING_STATUS.PAYMENT_FAILED ? 'PAYMENT_RETRY_INITIATED' : 'PAYMENT_PENDING_ORDER_CREATED',
        {},
      );
    }
    const payment = createOrderRecord(booking, paymentType);
    payment.idempotencyKey = idempotencyKey || newId();
    return {
      orderId: payment.orderId,
      bookingId: payment.bookingId,
      amountCents: payment.amountCents,
      currency: payment.currency,
      status: payment.status,
      keyId: payment.keyId,
      gateway: payment.gateway,
    };
  },

  verify(user, body) {
    const orderId = pick(body, 'orderId', 'order_id');
    const paymentId = pick(body, 'paymentId', 'payment_id') || `pay_${newId().slice(0, 8)}`;
    const signature = pick(body, 'signature');
    const payment = store.payments.get(orderId);
    if (!payment) throw new AppError('NOT_FOUND', 'Payment order not found.', HttpStatus.NOT_FOUND);
    const booking = bookingsService.loadBooking(payment.bookingId);
    bookingsService.assertCanRead(user, booking);

    const expected = hmacSha256(config.paymentWebhookSecret, `${orderId}|${paymentId}`);
    if (signature && !timingSafeEqualHex(expected, signature) && signature !== 'mock_ok') {
      booking.status = BOOKING_STATUS.PAYMENT_FAILED;
      booking.version += 1;
      payment.status = 'FAILED';
      throw new AppError('PAYMENT_SIGNATURE_MISMATCH', 'Payment signature could not be verified.', HttpStatus.CONFLICT);
    }
    payment.paymentId = paymentId;
    capture(booking, payment, ROLES.SYSTEM);
    return true;
  },

  webhook(headers, body) {
    const payload = JSON.stringify(body);
    const signature = headers['x-gateway-signature'] || headers['x-razorpay-signature'];
    const expected = hmacSha256(config.paymentWebhookSecret, payload);
    if (signature && !timingSafeEqualHex(expected, signature) && signature !== 'mock_ok') {
      throw new AppError('PAYMENT_SIGNATURE_MISMATCH', 'Webhook signature verification failed.', HttpStatus.UNAUTHORIZED);
    }
    const event = body.event || body.status;
    const orderId = pick(body, 'orderId', 'order_id') || body.payload?.payment?.entity?.order_id;
    const paymentId = pick(body, 'paymentId', 'payment_id') || body.payload?.payment?.entity?.id;
    const payment = store.payments.get(orderId);
    if (!payment) throw new AppError('NOT_FOUND', 'Payment order not found.', HttpStatus.NOT_FOUND);
    if (payment.status === 'CAPTURED') return { ok: true, replay: true };
    const booking = bookingsService.loadBooking(payment.bookingId);
    const failed = String(event || '').toLowerCase().includes('fail') || body.success === false;
    if (failed) {
      payment.status = 'FAILED';
      booking.status = BOOKING_STATUS.PAYMENT_FAILED;
      booking.version += 1;
      bookingsService.appendEvent(
        booking.id,
        BOOKING_STATUS.PAYMENT_PENDING,
        BOOKING_STATUS.PAYMENT_FAILED,
        booking.customerId,
        ROLES.SYSTEM,
        'PAYMENT_TOKEN_FAILED',
        { event },
      );
      return { ok: true, status: booking.status };
    }
    payment.paymentId = paymentId;
    capture(booking, payment);
    return { ok: true, status: booking.status };
  },

  fail(user, bookingId) {
    const booking = loadOwnedBooking(user, bookingId);
    const payment = [...store.payments.values()].find((p) => p.bookingId === bookingId && p.status === 'INITIATED');
    if (payment) payment.status = 'FAILED';
    const from = booking.status;
    booking.status = BOOKING_STATUS.PAYMENT_FAILED;
    booking.version += 1;
    bookingsService.appendEvent(booking.id, from, BOOKING_STATUS.PAYMENT_FAILED, user.id, ROLES.SYSTEM, 'PAYMENT_TOKEN_FAILED', {});
    return { status: booking.status };
  },
};

void ACTIONS;
