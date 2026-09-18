import { AppError, HttpStatus } from '../errors.js';
import { store } from '../store/memory-store.js';
import { newId } from '../utils/crypto.js';
import { pick } from '../utils/body.js';
import { isAdminRole, ROLES } from '../domain/roles.js';
import { ACTIONS, BOOKING_STATUS, EMERGENCY_SOURCE_STATUSES } from '../domain/booking-status.js';
import { bookingsService } from './bookings.service.js';
import { notify } from './notifications.service.js';

export const adminService = {
  decideDocument(user, documentId, body) {
    if (![ROLES.VERIFICATION_ADMIN, ROLES.SUPER_ADMIN].includes(user.role)) {
      throw new AppError('ROLE_FORBIDDEN', 'Verification admin required.', HttpStatus.FORBIDDEN);
    }
    const doc = store.documents.get(documentId);
    if (!doc) throw new AppError('NOT_FOUND', 'Document not found.', HttpStatus.NOT_FOUND);
    const decision = String(pick(body, 'decision') || '').toUpperCase();
    if (!['APPROVED', 'REJECTED', 'ACTION_REQUIRED'].includes(decision)) {
      throw new AppError('VALIDATION_ERROR', 'Decision must be APPROVED, REJECTED, or ACTION_REQUIRED.', HttpStatus.BAD_REQUEST);
    }
    doc.status = decision;
    doc.decisionReason = pick(body, 'reason') || '';
    doc.reviewedBy = user.id;
    doc.reviewedAt = new Date().toISOString();
    const driver = store.drivers.get(doc.driverId);
    const account = store.users.get(doc.driverId);
    if (driver) {
      if (decision === 'APPROVED') {
        driver.verificationStatus = 'APPROVED';
        driver.documentStatus = 'VERIFIED';
        driver.identityVerified = true;
        if (account && account.accountStatus !== 'active') account.accountStatus = 'active';
      } else if (decision === 'REJECTED') {
        driver.verificationStatus = 'REJECTED';
        driver.documentStatus = 'REJECTED';
      } else {
        driver.verificationStatus = 'ACTION_REQUIRED';
        driver.documentStatus = 'ACTION_REQUIRED';
      }
    }
    notify(doc.driverId, 'Verification update', `Document ${doc.type} marked ${decision}.`, { documentId });
    return doc;
  },

  emergencyReassign(user, bookingId, body) {
    if (![ROLES.OPERATIONS_ADMIN, ROLES.SUPER_ADMIN].includes(user.role)) {
      throw new AppError('ROLE_FORBIDDEN', 'Operations admin required.', HttpStatus.FORBIDDEN);
    }
    const booking = bookingsService.loadBooking(bookingId);
    const replacementDriverId = pick(body, 'replacementDriverId', 'replacement_driver_id');
    const replacementVehicleId = pick(body, 'replacementVehicleId', 'replacement_vehicle_id');
    const reason = pick(body, 'reason') || 'VEHICLE_BREAKDOWN';

    if (!EMERGENCY_SOURCE_STATUSES.includes(booking.status) && booking.status !== BOOKING_STATUS.EMERGENCY_REPLACEMENT) {
      if (booking.status !== BOOKING_STATUS.EMERGENCY_REPLACEMENT) {
        bookingsService.transition(user, bookingId, {
          action: ACTIONS.TRIGGER_EMERGENCY,
          currentVersion: booking.version,
          reason,
        });
      }
    } else if (booking.status !== BOOKING_STATUS.EMERGENCY_REPLACEMENT) {
      bookingsService.transition(user, bookingId, {
        action: ACTIONS.TRIGGER_EMERGENCY,
        currentVersion: booking.version,
        reason,
      });
    }

    const latest = bookingsService.loadBooking(bookingId);
    const driver = store.drivers.get(replacementDriverId);
    if (!driver || driver.verificationStatus !== 'APPROVED') {
      throw new AppError('STANDBY_CHAUFFEUR_UNAVAILABLE', 'Qualified standby chauffeur is not available.', HttpStatus.CONFLICT);
    }
    bookingsService.assertDriverFree(replacementDriverId, latest.serviceStartTime, latest.serviceEndTime, bookingId);
    const previousDriver = latest.driverId;
    bookingsService.releaseAvailability(bookingId);
    latest.driverId = replacementDriverId;
    if (replacementVehicleId) latest.vehicleId = replacementVehicleId;
    latest.emergencyReason = reason;
    bookingsService.transition(user, bookingId, {
      action: ACTIONS.REASSIGN,
      currentVersion: latest.version,
      notes: `Reassigned from ${previousDriver} to ${replacementDriverId}`,
    });
    bookingsService.lockAvailability(
      replacementDriverId,
      latest.vehicleId,
      latest.serviceStartTime,
      latest.serviceEndTime,
      bookingId,
      'BOOKED',
    );
    if (previousDriver) {
      const prev = store.drivers.get(previousDriver);
      if (prev) prev.dutyStatus = 'OFFLINE';
    }
    driver.dutyStatus = 'BUSY';
    notify(latest.customerId, 'Standby chauffeur assigned', 'A replacement chauffeur is on the way.', { bookingId });
    return bookingsService.toSummary(latest);
  },

  listBookings(status) {
    let rows = [...store.bookings.values()];
    if (status) rows = rows.filter((b) => b.status === String(status).toUpperCase());
    return rows.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt)).map(bookingsService.toSummary);
  },

  listPendingDocuments() {
    return [...store.documents.values()].filter((d) => d.status === 'SUBMITTED' || d.status === 'UNDER_REVIEW');
  },

  dashboard() {
    const bookings = [...store.bookings.values()];
    return {
      totals: {
        users: store.users.size,
        vehicles: store.vehicles.size,
        bookings: bookings.length,
        requested: bookings.filter((b) => b.status === BOOKING_STATUS.REQUESTED).length,
        live: bookings.filter((b) =>
          [BOOKING_STATUS.DRIVER_ARRIVING, BOOKING_STATUS.ARRIVED, BOOKING_STATUS.TRIP_STARTED].includes(b.status),
        ).length,
        completed: bookings.filter((b) => b.status === BOOKING_STATUS.COMPLETED).length,
      },
    };
  },
};

void isAdminRole;
