import { bookingsService } from '../services/bookings.service.js';

export function startExpiryJobs() {
  const tick = () => {
    bookingsService.markExpiredRequested();
    bookingsService.markExpiredPayments();
  };
  tick();
  return setInterval(tick, 30_000);
}
