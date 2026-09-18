import { config } from '../config.js';
import { AppError, HttpStatus } from '../errors.js';
import { store } from '../store/memory-store.js';
import { generateStartOtp, newId } from '../utils/crypto.js';
import { cityToCode, haversineMeters, hoursBetween, rangesOverlap, roundPaise } from '../utils/geo.js';
import { maskName, maskPhone } from '../utils/phone.js';
import { pick } from '../utils/body.js';
import { isAdminRole, ROLES } from '../domain/roles.js';
import {
  ACTIONS,
  BOOKING_STATUS,
  CANCELLABLE_STATUSES,
  CEREMONY_TO_CATEGORY,
  normalizeActionAlias,
  resolveTransition,
  tripStageFromStatus,
} from '../domain/booking-status.js';
import { driverEarnings, quote } from './pricing.service.js';
import { notify } from './notifications.service.js';

function nextReference() {
  store.bookingRefSeq += 1;
  return `SD-${new Date().getFullYear()}-${String(store.bookingRefSeq).padStart(4, '0')}`;
}

function nextGroupReference() {
  store.groupRefSeq += 1;
  return `SD-GRP-${new Date().getFullYear()}-${String(store.groupRefSeq).padStart(4, '0')}`;
}

function nowIso() {
  return new Date().toISOString();
}

function vehicleName(vehicle) {
  return `${vehicle.make} ${vehicle.model}`.trim();
}

function chauffeurName(driverId) {
  return store.users.get(driverId)?.fullName || '';
}

function loadBooking(id) {
  const booking = store.bookings.get(id);
  if (!booking) throw new AppError('BOOKING_NOT_FOUND', 'Booking ID does not exist.', HttpStatus.NOT_FOUND);
  return booking;
}

function assertCustomer(user) {
  if (user.role !== ROLES.CUSTOMER && user.role !== ROLES.SUPER_ADMIN) {
    throw new AppError('ROLE_FORBIDDEN', 'Only customers can perform this action.', HttpStatus.FORBIDDEN);
  }
}

function assertDriver(user) {
  if (![ROLES.DRIVER, ROLES.FLEET_OWNER, ROLES.SUPER_ADMIN].includes(user.role)) {
    throw new AppError('ROLE_FORBIDDEN', 'Only chauffeurs can perform this action.', HttpStatus.FORBIDDEN);
  }
}

function assertCanRead(user, booking) {
  if (isAdminRole(user.role)) return;
  if (booking.customerId === user.id || booking.driverId === user.id) return;
  throw new AppError('ROLE_FORBIDDEN', 'You cannot access this booking.', HttpStatus.FORBIDDEN);
}

function assertDriverFree(driverId, start, end, exceptBookingId) {
  const clash = store.availabilities.find(
    (a) =>
      a.driverId === driverId &&
      ['BOOKED', 'BLOCKED'].includes(a.status) &&
      a.bookingId !== exceptBookingId &&
      rangesOverlap(a.startTime, a.endTime, start, end),
  );
  if (clash) {
    throw new AppError(
      'SLOT_DOUBLE_BOOKED',
      'Chauffeur or vehicle already committed to another booking.',
      HttpStatus.CONFLICT,
      { conflictingBookingId: clash.bookingId },
    );
  }
}

function appendEvent(bookingId, from, to, userId, role, reason, metadata) {
  store.bookingEvents.push({
    id: newId(),
    bookingId,
    fromStatus: from,
    toStatus: to,
    triggeredByUserId: userId,
    triggerRole: role,
    eventReason: reason,
    eventMetadata: metadata || {},
    createdAt: nowIso(),
  });
}

function atomicTransition(booking, nextStatus, expectedVersion, extras = {}) {
  if (booking.version !== expectedVersion) {
    throw new AppError('VERSION_CONFLICT', 'Booking was modified concurrently. Refresh and retry.', HttpStatus.CONFLICT);
  }
  Object.assign(booking, extras, {
    status: nextStatus,
    version: booking.version + 1,
    updatedAt: nowIso(),
  });
  return booking;
}

function nextStep(status) {
  switch (status) {
    case BOOKING_STATUS.REQUESTED:
      return 'Awaiting chauffeur confirmation and schedule lock.';
    case BOOKING_STATUS.DRIVER_ACCEPTED:
      return 'Chauffeur accepted. Create the advance token payment order.';
    case BOOKING_STATUS.PAYMENT_PENDING:
      return 'Complete advance token checkout to lock the reservation.';
    case BOOKING_STATUS.PAYMENT_FAILED:
      return 'Payment failed. Retry within the grace window.';
    case BOOKING_STATUS.CONFIRMED:
      return 'Ceremony reservation officially secured.';
    case BOOKING_STATUS.DRIVER_ASSIGNED:
      return 'Chauffeur is briefed and assigned.';
    case BOOKING_STATUS.DRIVER_ARRIVING:
    case BOOKING_STATUS.EN_ROUTE:
      return 'Chauffeur is en route to the venue.';
    case BOOKING_STATUS.ARRIVED:
      return 'Chauffeur is on standby at the venue gate.';
    case BOOKING_STATUS.TRIP_STARTED:
      return 'Ceremony is in progress.';
    case BOOKING_STATUS.COMPLETED:
      return 'Ceremony concluded. Balance invoice will follow.';
    default:
      return '';
  }
}

function toSubmission(booking, replay = false) {
  const vehicle = store.vehicles.get(booking.vehicleId) || {};
  return {
    bookingId: booking.id,
    bookingReference: booking.referenceCode,
    status: booking.status,
    submittedAt: booking.submittedAt || booking.createdAt,
    vehicleId: booking.vehicleId,
    vehicleName: vehicleName(vehicle),
    vehicleClass: vehicle.vehicleClass || booking.vehicleClass,
    chauffeurId: booking.driverId || '',
    ceremonyType: booking.ceremonyType,
    ceremonialAttire: booking.ceremonialAttire,
    serviceStartDateTime: booking.serviceStartTime,
    serviceEndDateTime: booking.serviceEndTime,
    routeDistanceKm: booking.routeDistanceKm,
    pickupAddress: booking.pickupAddress,
    destinationAddress: booking.destinationAddress,
    primaryContactName: booking.primaryContactName,
    primaryContactPhone: booking.primaryContactPhone,
    estimatedTotalPaise: booking.estimatedTotalPaise,
    advanceTokenPaise: booking.advanceTokenPaise,
    advanceTokenLabel: booking.advanceTokenLabel,
    version: booking.version,
    startOtp: booking.startOtp,
    nextStepMessage: nextStep(booking.status),
    isIdempotentReplay: replay,
  };
}

function toSummary(booking) {
  const vehicle = store.vehicles.get(booking.vehicleId) || {};
  return {
    id: booking.id,
    reference: booking.referenceCode,
    serviceCategory: booking.serviceCategoryId || booking.ceremonyType,
    status: booking.status,
    eventStartTime: booking.serviceStartTime,
    eventEndTime: booking.serviceEndTime,
    pickupAddress: booking.pickupAddress,
    destinationAddress: booking.destinationAddress,
    routeDistanceKm: booking.routeDistanceKm,
    vehicleName: vehicleName(vehicle),
    chauffeurName: chauffeurName(booking.driverId),
    totalAmountCents: booking.estimatedTotalPaise,
    advanceTokenCents: booking.advanceTokenPaise,
    version: booking.version,
  };
}

function toOffer(booking) {
  const vehicle = store.vehicles.get(booking.vehicleId) || {};
  return {
    bookingId: booking.id,
    bookingReference: booking.referenceCode,
    status: booking.status,
    ceremonyType: booking.ceremonyType,
    ceremonialAttire: booking.ceremonialAttire,
    eventDate: booking.serviceStartTime,
    durationHours: hoursBetween(booking.serviceStartTime, booking.serviceEndTime),
    pickupAddress: booking.pickupAddress,
    destinationAddress: booking.destinationAddress,
    vehicleName: vehicleName(vehicle),
    vehicleClass: vehicle.vehicleClass || booking.vehicleClass,
    passengerCount: booking.passengerCount,
    specialInstructions: booking.specialInstructions,
    maskedContactName: maskName(booking.primaryContactName || 'Host'),
    maskedContactPhone: maskPhone(booking.primaryContactPhone || ''),
    estimatedTotalPaise: booking.estimatedTotalPaise,
    estimatedDriverEarningsPaise: driverEarnings(booking.estimatedTotalPaise),
  };
}

function refundPercent(booking) {
  const policy = store.policies.get(booking.bookingPolicyId) || [...store.policies.values()][0];
  const hours = (new Date(booking.serviceStartTime).getTime() - Date.now()) / 3_600_000;
  const tiers = [...(policy?.cancellationTiers || [])].sort((a, b) => b.hours_before - a.hours_before);
  const match = tiers.find((t) => hours >= t.hours_before) || tiers[tiers.length - 1];
  if (!booking.isAdvancePaid) return 100;
  return match?.refund_percent ?? 0;
}

function releaseAvailability(bookingId) {
  for (const a of store.availabilities) {
    if (a.bookingId === bookingId) {
      a.status = 'AVAILABLE';
      a.bookingId = null;
    }
  }
}

function lockAvailability(driverId, vehicleId, start, end, bookingId, status) {
  const existing = store.availabilities.find((a) => a.bookingId === bookingId);
  if (existing) {
    existing.driverId = driverId;
    existing.vehicleId = vehicleId;
    existing.status = status;
    return existing;
  }
  const row = {
    id: newId(),
    driverId,
    vehicleId,
    startTime: start,
    endTime: end,
    status,
    bookingId,
  };
  store.availabilities.push(row);
  return row;
}

export const bookingsService = {
  toSubmission,
  toSummary,
  toOffer,
  loadBooking,
  nextStep,
  atomicTransition,
  appendEvent,
  assertCanRead,
  assertDriverFree,
  releaseAvailability,
  lockAvailability,

  createDraft(user, body) {
    assertCustomer(user);
    const id = body.id || newId();
    const payload = { ...body, id, status: 'saved', createdAt: body.createdAt || nowIso() };
    store.drafts.set(id, { id, customerId: user.id, payload, status: 'saved', updatedAt: nowIso() });
    return payload;
  },

  getDraft(user, draftId) {
    const row = store.drafts.get(draftId);
    if (!row || row.customerId !== user.id) return null;
    return row.payload;
  },

  saveDraft(user, body) {
    if (!body.id) return this.createDraft(user, body);
    const row = store.drafts.get(body.id);
    if (!row || row.customerId !== user.id) {
      return this.createDraft(user, body);
    }
    row.payload = { ...row.payload, ...body, status: 'saved' };
    row.status = 'saved';
    row.updatedAt = nowIso();
    return { saved: true };
  },

  submit(user, body, idempotencyKey) {
    assertCustomer(user);
    const start = new Date(pick(body, 'serviceStartDateTime', 'eventStartTime', 'event_start_time'));
    const end = new Date(pick(body, 'serviceEndDateTime', 'eventEndTime', 'event_end_time'));
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      throw new AppError('INVALID_BOOKING_DRAFT', 'Event start and end times are required.', HttpStatus.BAD_REQUEST);
    }
    if (start.getTime() <= Date.now()) {
      throw new AppError('INVALID_BOOKING_DRAFT', 'Event start time must be in the future.', HttpStatus.BAD_REQUEST);
    }
    if (end.getTime() - start.getTime() < 60 * 60 * 1000) {
      throw new AppError('INVALID_BOOKING_DRAFT', 'Ceremony duration must be at least 60 minutes.', HttpStatus.BAD_REQUEST);
    }

    const key = idempotencyKey || pick(body, 'idempotencyKey', 'idempotency_key');
    if (key) {
      for (const booking of store.bookings.values()) {
        if (booking.idempotencyKey === key) return toSubmission(booking, true);
      }
    }

    const vehicleId = pick(body, 'vehicleId', 'vehicle_id');
    const vehicle = store.vehicles.get(vehicleId);
    if (!vehicle || vehicle.verificationStatus !== 'APPROVED' || !vehicle.isAvailable) {
      throw new AppError('CHAUFFEUR_UNAVAILABLE', 'Selected vehicle is not available.', HttpStatus.CONFLICT);
    }

    const ceremonyType = pick(body, 'ceremonyType', 'ceremony_type') || 'Baraat';
    const categoryId =
      pick(body, 'serviceCategoryId', 'service_category_id') ||
      CEREMONY_TO_CATEGORY[String(ceremonyType).trim().toLowerCase()] ||
      'SVC_BARAAT';

    const priceQuote = quote({
      serviceCategoryId: categoryId,
      vehicleClass: pick(body, 'vehicleClass', 'vehicle_class') || vehicle.vehicleClass,
      city: pick(body, 'city') || vehicle.city,
      eventStartTime: start,
      eventEndTime: end,
      selectedAddonIds: pick(body, 'selectedAddonIds', 'selected_addon_ids') || [],
      routeDistanceKm: pick(body, 'routeDistanceKm', 'route_distance_km'),
    });

    const chauffeurId = pick(body, 'chauffeurId', 'chauffeur_id') || vehicle.independentDriverId || null;
    if (chauffeurId) {
      const driver = store.drivers.get(chauffeurId);
      if (driver && driver.verificationStatus !== 'APPROVED') {
        throw new AppError('DOC_NOT_VERIFIED', 'Selected chauffeur is not verified.', HttpStatus.FORBIDDEN);
      }
      assertDriverFree(chauffeurId, start, end);
    }

    const pickupCoordinates = pick(body, 'pickupCoordinates', 'pickup_coordinates') || {};
    const booking = {
      id: newId(),
      referenceCode: nextReference(),
      customerId: user.id,
      driverId: chauffeurId,
      vehicleId: vehicle.id,
      serviceCategoryId: categoryId,
      pricingRuleId: priceQuote.pricingRuleId,
      bookingPolicyId: priceQuote.bookingPolicyId,
      ceremonyType,
      ceremonialAttire: pick(body, 'ceremonialAttire', 'ceremonial_attire', 'selectedAttire') || 'ROYAL_BANDHGALA_SAFA',
      specialInstructions: pick(body, 'specialInstructions', 'special_instructions') || '',
      serviceStartTime: start.toISOString(),
      serviceEndTime: end.toISOString(),
      city: pick(body, 'city') || vehicle.city,
      cityCode: priceQuote.cityCode || cityToCode(pick(body, 'city') || vehicle.city),
      pickupAddress: pick(body, 'pickupAddress', 'pickup_address'),
      pickupLat: pickupCoordinates.latitude ?? pickupCoordinates.lat ?? null,
      pickupLng: pickupCoordinates.longitude ?? pickupCoordinates.lng ?? null,
      destinationAddress: pick(body, 'destinationAddress', 'destination_address') || '',
      venueName: pick(body, 'venueName', 'ceremonyVenueName', 'ceremony_venue_name') || '',
      landmark: pick(body, 'landmark', 'landmarkInstructions') || '',
      routeDistanceKm: pick(body, 'routeDistanceKm', 'route_distance_km') ?? null,
      primaryContactName: pick(body, 'primaryContactName', 'primary_contact_name'),
      primaryContactPhone: pick(body, 'primaryContactPhone', 'primary_contact_phone'),
      passengerCount: Number(pick(body, 'passengerCount', 'passenger_count') || 2),
      estimatedTotalPaise: priceQuote.totalPaise,
      advanceTokenPaise: priceQuote.advanceTokenPaise,
      advanceTokenLabel: priceQuote.advanceTokenLabel,
      selectedAddonIds: pick(body, 'selectedAddonIds', 'selected_addon_ids') || [],
      status: BOOKING_STATUS.REQUESTED,
      startOtp: generateStartOtp(),
      version: 1,
      idempotencyKey: key || newId(),
      isAdvancePaid: false,
      declineReason: null,
      cancellationReason: null,
      emergencyReason: null,
      startedAt: null,
      completedAt: null,
      submittedAt: nowIso(),
      createdAt: nowIso(),
      updatedAt: nowIso(),
    };

    store.bookings.set(booking.id, booking);
    if (chauffeurId) {
      lockAvailability(chauffeurId, vehicle.id, booking.serviceStartTime, booking.serviceEndTime, booking.id, 'BLOCKED');
    }
    appendEvent(booking.id, 'DRAFT', BOOKING_STATUS.REQUESTED, user.id, user.role, 'BOOKING_SUBMITTED', { quote: priceQuote });
    notify(user.id, 'Booking request sent', `Your ceremony booking ${booking.referenceCode} is awaiting chauffeur confirmation.`, {
      bookingId: booking.id,
      reference: booking.referenceCode,
    });
    if (chauffeurId) {
      notify(chauffeurId, 'New ceremonial offer', `New ${booking.ceremonyType} request ${booking.referenceCode} is waiting for your response.`, {
        bookingId: booking.id,
      });
    }
    return toSubmission(booking, false);
  },

  getById(user, bookingId) {
    const booking = loadBooking(bookingId);
    assertCanRead(user, booking);
    return toSummary(booking);
  },

  getSubmission(user, bookingId) {
    const booking = loadBooking(bookingId);
    assertCanRead(user, booking);
    return toSubmission(booking, false);
  },

  getMy(user, page = 1, limit = 20, statusFilter) {
    let rows = [...store.bookings.values()].filter((b) => b.customerId === user.id);
    if (statusFilter) rows = rows.filter((b) => b.status === String(statusFilter).toUpperCase());
    rows.sort((a, b) => new Date(b.serviceStartTime) - new Date(a.serviceStartTime));
    const total = rows.length;
    const slice = rows.slice((page - 1) * limit, page * limit);
    return {
      data: slice.map(toSummary),
      meta: { page, limit, totalRecords: total, hasMore: page * limit < total },
    };
  },

  driverOffers(user) {
    assertDriver(user);
    return [...store.bookings.values()]
      .filter((b) => b.status === BOOKING_STATUS.REQUESTED && (b.driverId === user.id || !b.driverId))
      .filter((b) => {
        try {
          assertDriverFree(user.id, b.serviceStartTime, b.serviceEndTime, b.id);
          return true;
        } catch {
          return false;
        }
      })
      .sort((a, b) => new Date(a.serviceStartTime) - new Date(b.serviceStartTime))
      .map(toOffer);
  },

  driverDetails(user, bookingId) {
    assertDriver(user);
    return toSubmission(loadBooking(bookingId), false);
  },

  accept(user, bookingId, currentVersion) {
    assertDriver(user);
    const booking = loadBooking(bookingId);
    const driver = store.drivers.get(user.id);
    if (!driver || driver.verificationStatus !== 'APPROVED') {
      throw new AppError('DOC_NOT_VERIFIED', 'Chauffeur KYC must be approved before accepting offers.', HttpStatus.FORBIDDEN);
    }
    resolveTransition(booking.status, ACTIONS.ACCEPT, user.role);
    assertDriverFree(user.id, booking.serviceStartTime, booking.serviceEndTime, bookingId);
    const from = booking.status;
    atomicTransition(booking, BOOKING_STATUS.DRIVER_ACCEPTED, currentVersion ?? booking.version, {
      driverId: user.id,
    });
    lockAvailability(user.id, booking.vehicleId, booking.serviceStartTime, booking.serviceEndTime, bookingId, 'BOOKED');
    driver.dutyStatus = 'BUSY';
    appendEvent(bookingId, from, BOOKING_STATUS.DRIVER_ACCEPTED, user.id, user.role, 'DRIVER_ACCEPTED_OFFER', {});
    notify(booking.customerId, 'Chauffeur accepted', 'Your chauffeur accepted. Please complete the advance token.', {
      bookingId,
    });
    return toSubmission(booking, false);
  },

  decline(user, bookingId, dto) {
    assertDriver(user);
    const booking = loadBooking(bookingId);
    resolveTransition(booking.status, ACTIONS.DECLINE, user.role);
    const from = booking.status;
    atomicTransition(booking, BOOKING_STATUS.REJECTED, booking.version, {
      declineReason: dto.reason,
      declineNotes: dto.notes || null,
    });
    releaseAvailability(bookingId);
    appendEvent(bookingId, from, BOOKING_STATUS.REJECTED, user.id, user.role, 'DRIVER_REJECTED_OFFER', dto);
    notify(booking.customerId, 'Booking declined', 'The chauffeur declined this ceremonial request.', { bookingId });
    return toSubmission(booking, false);
  },

  cancel(user, bookingId, dto) {
    const booking = loadBooking(bookingId);
    if (!CANCELLABLE_STATUSES.includes(booking.status)) {
      throw new AppError('NON_CANCELLABLE_STATE', 'This booking can no longer be cancelled.', HttpStatus.CONFLICT);
    }
    assertCanRead(user, booking);
    const refund = refundPercent(booking);
    const from = booking.status;
    atomicTransition(booking, BOOKING_STATUS.CANCELLED, booking.version, {
      cancellationReason: dto.reason,
      cancelledAt: nowIso(),
    });
    releaseAvailability(bookingId);
    if (booking.driverId) {
      const driver = store.drivers.get(booking.driverId);
      if (driver && driver.dutyStatus === 'BUSY') driver.dutyStatus = 'AVAILABLE';
    }
    appendEvent(bookingId, from, BOOKING_STATUS.CANCELLED, user.id, user.role, 'BOOKING_USER_CANCELLED', {
      reason: dto.reason,
      refundPercent: refund,
    });
    return { cancelled: true, refundPercent: refund, booking: toSummary(booking) };
  },

  transition(user, bookingId, dto) {
    const booking = loadBooking(bookingId);
    const action = normalizeActionAlias(dto.action);
    if (action === ACTIONS.ACCEPT) return this.accept(user, bookingId, dto.currentVersion);
    if (action === ACTIONS.DECLINE) {
      return this.decline(user, bookingId, { reason: dto.reason || 'OTHER', notes: dto.notes });
    }
    if (action === ACTIONS.CANCEL || action === ACTIONS.ABANDON) {
      return this.cancel(user, bookingId, { reason: dto.reason || dto.notes || 'Cancelled' });
    }

    let rule;
    try {
      rule = resolveTransition(booking.status, action, user.role);
    } catch (error) {
      const code = error.code || 'INVALID_TRANSITION';
      throw new AppError(
        code,
        code === 'ROLE_FORBIDDEN'
          ? 'Your role cannot perform this transition.'
          : 'Attempted illegal state machine transition.',
        code === 'ROLE_FORBIDDEN' ? HttpStatus.FORBIDDEN : HttpStatus.CONFLICT,
      );
    }
    this.enforcePreconditions(booking, action, user, dto);
    const from = booking.status;
    const extras = {};
    if (action === ACTIONS.START_TRIP) extras.startedAt = nowIso();
    if (action === ACTIONS.COMPLETE) extras.completedAt = nowIso();
    if (action === ACTIONS.TRIGGER_EMERGENCY) extras.emergencyReason = dto.reason || dto.notes;
    atomicTransition(booking, rule.to, dto.currentVersion ?? booking.version, extras);
    appendEvent(bookingId, from, rule.to, user.id, user.role, rule.auditEvent, {
      notes: dto.notes,
      location: dto.location,
    });
    return { id: booking.id, status: booking.status, version: booking.version, nextStepMessage: nextStep(booking.status) };
  },

  enforcePreconditions(booking, action, user, dto) {
    if (action === ACTIONS.START_ROUTE) {
      const check = store.checklists.get(booking.id);
      if (!check?.isFuelChecked || !check.isDualAcChecked || !check.isGroomingChecked) {
        throw new AppError(
          'PRE_TRIP_CHECKLIST_INCOMPLETE',
          'Complete the pre-trip checklist before departing.',
          HttpStatus.CONFLICT,
        );
      }
    }
    if (action === ACTIONS.ARRIVE && dto.location && booking.pickupLat != null) {
      const meters = haversineMeters(
        dto.location.latitude,
        dto.location.longitude,
        Number(booking.pickupLat),
        Number(booking.pickupLng),
      );
      if (meters > config.settings.geofenceRadiusMeters) {
        throw new AppError('GEOFENCE_PROXIMITY_FAILED', 'Chauffeur is outside the venue geofence.', HttpStatus.CONFLICT, {
          distanceMeters: Math.round(meters),
        });
      }
    }
    if (action === ACTIONS.START_TRIP) {
      if (!dto.otp || dto.otp !== booking.startOtp) {
        throw new AppError('INVALID_START_OTP', 'Host family OTP is invalid.', HttpStatus.CONFLICT);
      }
    }
    if (action === ACTIONS.ASSIGN_DRIVER) {
      const driverId = booking.driverId || user.id;
      const driver = store.drivers.get(driverId);
      if (!driver || driver.verificationStatus !== 'APPROVED') {
        throw new AppError('DRIVER_KYC_SUSPENDED_OR_EXPIRED', 'Assigned chauffeur is not approved.', HttpStatus.CONFLICT);
      }
    }
  },

  checkFleetAvailability(intent) {
    const requested =
      intent.requestedUnits && Object.keys(intent.requestedUnits).length
        ? intent.requestedUnits
        : intent.preferredModel
          ? { [intent.preferredModel]: 1 }
          : {};
    const entries = Object.entries(requested);
    const availableVehicles = [...store.vehicles.values()].filter(
      (v) => v.isActive && v.isAvailable && v.verificationStatus === 'APPROVED',
    );
    if (!entries.length) {
      const count = availableVehicles.filter((v) => !intent.city || v.city.toLowerCase() === String(intent.city).toLowerCase()).length;
      const needed = Math.max(1, Math.ceil((intent.passengerCount || 1) / 4));
      return {
        isFullyAvailable: count >= needed,
        requestedCount: needed,
        availableCount: Math.min(count, needed),
        shortfall: Math.max(0, needed - count),
        alternativeSuggestions: [],
        message:
          count >= needed
            ? `All ${needed} requested units are available for the ceremony.`
            : `Only ${count} of ${needed} units available.`,
      };
    }

    const suggestions = [];
    let availableCount = 0;
    let requestedCount = 0;
    for (const [model, qty] of entries) {
      requestedCount += qty;
      const matches = availableVehicles.filter((v) => v.model.toLowerCase() === String(model).toLowerCase());
      const have = matches.length;
      availableCount += Math.min(have, qty);
      if (have < qty) {
        const alt = availableVehicles.find((v) => v.model.toLowerCase() !== String(model).toLowerCase());
        if (alt) {
          suggestions.push({
            modelName: alt.model,
            suggestedCount: qty - have,
            capacityPerUnit: alt.seatingCapacity,
            rationale: `Shortage of ${model}; ${alt.model} can cover remaining guests.`,
          });
        }
      }
    }
    const shortfall = requestedCount - availableCount;
    return {
      isFullyAvailable: shortfall <= 0,
      requestedModel: intent.preferredModel,
      requestedCount,
      availableCount,
      shortfall: Math.max(0, shortfall),
      alternativeSuggestions: suggestions,
      message:
        shortfall <= 0
          ? `All ${requestedCount} requested units are available for the ceremony.`
          : `Only ${availableCount} of ${requestedCount} ${intent.preferredModel || 'requested'} units available. ${shortfall} additional unit(s) required.`,
    };
  },

  submitGroupBooking(user, body, idempotencyKey) {
    assertCustomer(user);
    const key = idempotencyKey || pick(body, 'idempotencyKey', 'idempotency_key') || newId();
    for (const g of store.groupBookings.values()) {
      if (g.idempotencyKey === key) return this.toGroup(g);
    }
    const intent = pick(body, 'customerIntent', 'fleetIntent') || body;
    const start = new Date(pick(body, 'serviceStartDateTime'));
    const end = new Date(pick(body, 'serviceEndDateTime'));
    const units = intent.requestedUnits || {};
    const assignments = [];
    let totalPaise = 0;
    const used = new Set();
    for (const [model, qty] of Object.entries(units)) {
      const matches = [...store.vehicles.values()].filter(
        (v) => v.isActive && v.isAvailable && v.verificationStatus === 'APPROVED' && v.model.toLowerCase() === model.toLowerCase() && !used.has(v.id),
      );
      for (let i = 0; i < qty; i += 1) {
        const vehicle = matches[i];
        if (!vehicle) continue;
        used.add(vehicle.id);
        const priceQuote = quote({
          serviceCategoryId:
            CEREMONY_TO_CATEGORY[String(pick(body, 'ceremonyType') || 'baraat').toLowerCase()] || 'SVC_BARAAT',
          vehicleClass: vehicle.vehicleClass,
          city: pick(body, 'city') || vehicle.city,
          eventStartTime: start,
          eventEndTime: end,
        });
        totalPaise += priceQuote.totalPaise;
        assignments.push({
          assignmentId: newId(),
          parentBookingId: null,
          vehicleId: vehicle.id,
          vehicleName: `${vehicleName(vehicle)} #${i + 1}`,
          vehicleModel: vehicle.model,
          capacity: vehicle.seatingCapacity,
          ownerName: vehicle.ownerName,
          chauffeurId: vehicle.independentDriverId,
          chauffeurName: chauffeurName(vehicle.independentDriverId),
          pricePaise: priceQuote.totalPaise,
          status: 'ASSIGNED',
        });
      }
    }
    const token = roundPaise(totalPaise * 0.25);
    const group = {
      id: newId(),
      bookingReference: nextGroupReference(),
      customerId: user.id,
      status: BOOKING_STATUS.REQUESTED,
      ceremonyType: pick(body, 'ceremonyType') || 'Baraat',
      serviceStartTime: start.toISOString(),
      serviceEndTime: end.toISOString(),
      city: pick(body, 'city') || 'Delhi',
      pickupAddress: pick(body, 'pickupAddress') || '',
      destinationAddress: pick(body, 'destinationAddress') || '',
      primaryContactName: pick(body, 'primaryContactName') || '',
      primaryContactPhone: pick(body, 'primaryContactPhone') || '',
      passengerCount: intent.passengerCount || pick(body, 'passengerCount') || 2,
      intent,
      estimatedTotalPaise: totalPaise,
      advanceTokenPaise: token,
      advanceTokenLabel: '25% Advance Token',
      idempotencyKey: key,
      createdAt: nowIso(),
    };
    for (const a of assignments) a.parentBookingId = group.id;
    store.groupBookings.set(group.id, group);
    store.assignments.push(...assignments);
    return this.toGroup(group);
  },

  getGroupBooking(user, id) {
    const group = store.groupBookings.get(id);
    if (!group) throw new AppError('BOOKING_NOT_FOUND', 'Group booking not found.', HttpStatus.NOT_FOUND);
    if (group.customerId !== user.id && !isAdminRole(user.role)) {
      throw new AppError('ROLE_FORBIDDEN', 'Not allowed.', HttpStatus.FORBIDDEN);
    }
    return this.toGroup(group);
  },

  toGroup(group) {
    const assignments = store.assignments.filter((a) => a.parentBookingId === group.id);
    return {
      parentBookingId: group.id,
      bookingReference: group.bookingReference,
      status: group.status,
      customerIntent: group.intent,
      totalPassengers: group.passengerCount,
      totalVehicles: assignments.length,
      assignments,
      ceremonyType: group.ceremonyType,
      serviceStartDateTime: group.serviceStartTime,
      serviceEndDateTime: group.serviceEndTime,
      city: group.city,
      pickupAddress: group.pickupAddress,
      destinationAddress: group.destinationAddress,
      primaryContactName: group.primaryContactName,
      primaryContactPhone: group.primaryContactPhone,
      estimatedTotalPaise: group.estimatedTotalPaise,
      advanceTokenPaise: group.advanceTokenPaise,
      advanceTokenLabel: group.advanceTokenLabel,
      createdAt: group.createdAt,
    };
  },

  markExpiredRequested() {
    const cutoff = Date.now() - config.settings.acceptanceTimeoutMinutes * 60_000;
    let count = 0;
    for (const booking of store.bookings.values()) {
      if (booking.status !== BOOKING_STATUS.REQUESTED) continue;
      if (new Date(booking.createdAt).getTime() >= cutoff) continue;
      const from = booking.status;
      booking.status = BOOKING_STATUS.EXPIRED;
      booking.version += 1;
      booking.updatedAt = nowIso();
      releaseAvailability(booking.id);
      appendEvent(booking.id, from, BOOKING_STATUS.EXPIRED, booking.customerId, ROLES.SYSTEM, 'BOOKING_TIMEOUT_EXPIRED', {});
      count += 1;
    }
    return count;
  },

  markExpiredPayments() {
    const cutoff = Date.now() - config.settings.paymentWindowMinutes * 60_000;
    let count = 0;
    for (const booking of store.bookings.values()) {
      if (booking.status !== BOOKING_STATUS.PAYMENT_PENDING) continue;
      if (new Date(booking.updatedAt).getTime() >= cutoff) continue;
      const from = booking.status;
      booking.status = BOOKING_STATUS.EXPIRED;
      booking.version += 1;
      booking.updatedAt = nowIso();
      for (const payment of store.payments.values()) {
        if (payment.bookingId === booking.id && payment.status === 'INITIATED') {
          payment.status = 'FAILED';
          payment.failureCode = 'WINDOW_EXPIRED';
        }
      }
      releaseAvailability(booking.id);
      appendEvent(booking.id, from, BOOKING_STATUS.EXPIRED, booking.customerId, ROLES.SYSTEM, 'PAYMENT_WINDOW_EXPIRED', {});
      count += 1;
    }
    return count;
  },

  toActiveTrip(booking) {
    const vehicle = store.vehicles.get(booking.vehicleId) || {};
    return {
      bookingId: booking.id,
      bookingReference: booking.referenceCode,
      ceremonyType: booking.ceremonyType,
      ceremonialAttire: booking.ceremonialAttire,
      stage: tripStageFromStatus(booking.status),
      pickupAddress: booking.pickupAddress,
      destinationAddress: booking.destinationAddress,
      venueName: booking.venueName,
      landmark: booking.landmark,
      primaryContactName: booking.primaryContactName,
      primaryContactPhone: booking.primaryContactPhone,
      serviceStartDateTime: booking.serviceStartTime,
      serviceEndDateTime: booking.serviceEndTime,
      routeDistanceKm: booking.routeDistanceKm,
      vehicleName: vehicleName(vehicle),
      startOtp: booking.startOtp,
      tripStartedAt: booking.startedAt,
      tripCompletedAt: booking.completedAt,
      ceremonialAttireConfirmed: Boolean(store.checklists.get(booking.id)?.isGroomingChecked),
    };
  },
};
