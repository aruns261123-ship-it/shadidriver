import { AppError, HttpStatus } from '../errors.js';
import { store } from '../store/memory-store.js';
import { newId } from '../utils/crypto.js';
import { pick } from '../utils/body.js';
import { IDS } from '../store/seed.js';
import { BOOKING_STATUS } from '../domain/booking-status.js';
import { bookingsService } from './bookings.service.js';
import { notify } from './notifications.service.js';

export const supportService = {
  createTicket(user, body) {
    const ticket = {
      id: newId(),
      bookingId: pick(body, 'bookingId'),
      category: pick(body, 'category') || 'GENERAL',
      message: pick(body, 'message'),
      userId: user.id,
      status: 'OPEN',
      createdAt: new Date().toISOString(),
    };
    if (!ticket.message) throw new AppError('VALIDATION_ERROR', 'Message is required.', HttpStatus.BAD_REQUEST);
    store.supportTickets.push(ticket);
    return { ticketId: ticket.id, ...ticket };
  },

  submitReview(user, body) {
    const bookingId = pick(body, 'bookingId');
    const booking = bookingsService.loadBooking(bookingId);
    if (booking.customerId !== user.id) {
      throw new AppError('ROLE_FORBIDDEN', 'Only the host can review this ceremony.', HttpStatus.FORBIDDEN);
    }
    if (booking.status !== BOOKING_STATUS.COMPLETED) {
      throw new AppError('INVALID_TRANSITION', 'Reviews are accepted after ceremony completion.', HttpStatus.CONFLICT);
    }
    const review = {
      id: newId(),
      bookingId,
      driverId: booking.driverId,
      reviewerName: store.users.get(user.id)?.fullName || 'Host',
      rating: Number(pick(body, 'rating') || 5),
      comment: pick(body, 'feedback', 'comment') || '',
      punctualityRating: pick(body, 'punctualityRating'),
      groomingRating: pick(body, 'groomingRating'),
      createdAt: new Date().toISOString(),
    };
    store.reviews.push(review);
    return { submitted: true, reviewId: review.id };
  },

  urgentDispatch(user, body) {
    const standby = store.drivers.get(IDS.driverStandby);
    if (!standby || !['AVAILABLE', 'AVAILABLE_NOW'].includes(standby.dutyStatus)) {
      throw new AppError('CHAUFFEUR_UNAVAILABLE', 'No urgent chauffeur is currently available.', HttpStatus.CONFLICT);
    }
    const dispatchId = newId();
    notify(user.id, 'Urgent dispatch accepted', 'A standby chauffeur is being assigned.', { dispatchId });
    notify(IDS.driverStandby, 'Urgent dispatch', 'An emergency ceremonial dispatch is waiting.', {
      dispatchId,
      address: pick(body, 'address'),
    });
    return {
      dispatchId,
      driverId: IDS.driverStandby,
      status: 'DISPATCHED',
      serviceCategory: pick(body, 'serviceCategory'),
      address: pick(body, 'address'),
    };
  },
};
