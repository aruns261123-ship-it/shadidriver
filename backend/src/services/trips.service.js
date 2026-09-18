import { AppError, HttpStatus } from '../errors.js';
import { pick } from '../utils/body.js';
import { ACTIONS, BOOKING_STATUS } from '../domain/booking-status.js';
import { bookingsService } from './bookings.service.js';

export const tripsService = {
  arrived(user, bookingId, body = {}) {
    return bookingsService.transition(user, bookingId, {
      action: ACTIONS.ARRIVE,
      currentVersion: Number(pick(body, 'currentVersion') ?? bookingsService.loadBooking(bookingId).version),
      location: pick(body, 'location'),
      notes: pick(body, 'notes'),
    });
  },

  start(user, bookingId, body = {}) {
    const booking = bookingsService.loadBooking(bookingId);
    return bookingsService.transition(user, bookingId, {
      action: ACTIONS.START_TRIP,
      currentVersion: Number(pick(body, 'currentVersion') ?? booking.version),
      otp: pick(body, 'otp', 'otpCode'),
      notes: pick(body, 'notes'),
    });
  },

  complete(user, bookingId, body = {}) {
    const booking = bookingsService.loadBooking(bookingId);
    return bookingsService.transition(user, bookingId, {
      action: ACTIONS.COMPLETE,
      currentVersion: Number(pick(body, 'currentVersion') ?? booking.version),
      notes: pick(body, 'notes'),
    });
  },

  startRoute(user, bookingId, body = {}) {
    const booking = bookingsService.loadBooking(bookingId);
    if (booking.status === BOOKING_STATUS.CONFIRMED) {
      bookingsService.transition(user, bookingId, {
        action: ACTIONS.ASSIGN_DRIVER,
        currentVersion: booking.version,
      });
    }
    const latest = bookingsService.loadBooking(bookingId);
    return bookingsService.transition(user, bookingId, {
      action: ACTIONS.START_ROUTE,
      currentVersion: Number(pick(body, 'currentVersion') ?? latest.version),
      notes: pick(body, 'notes'),
    });
  },
};

export function requireOtp(otp) {
  if (!otp) throw new AppError('INVALID_START_OTP', 'Host family OTP is required.', HttpStatus.CONFLICT);
}
