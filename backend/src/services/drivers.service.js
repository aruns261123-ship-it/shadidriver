import { AppError, HttpStatus } from '../errors.js';
import { store } from '../store/memory-store.js';
import { newId } from '../utils/crypto.js';
import { pick } from '../utils/body.js';
import { ROLES } from '../domain/roles.js';
import { BOOKING_STATUS } from '../domain/booking-status.js';
import { bookingsService } from './bookings.service.js';
import { notify } from './notifications.service.js';
import { config } from '../config.js';

function requireDriver(user) {
  if (![ROLES.DRIVER, ROLES.FLEET_OWNER, ROLES.SUPER_ADMIN].includes(user.role)) {
    throw new AppError('ROLE_FORBIDDEN', 'Driver role required.', HttpStatus.FORBIDDEN);
  }
}

function toProfile(user, driver) {
  return {
    id: user.id,
    fullName: user.fullName,
    phone: user.phoneNumber,
    email: user.email,
    verificationStatus: driver.verificationStatus,
    documentStatus: driver.documentStatus,
    vehicleStatus: driver.vehicleStatus,
    isOnline: driver.isOnline,
    experienceYears: driver.experienceYears,
    rating: driver.averageRating,
    totalTrips: driver.totalTripsCompleted,
    bio: driver.bio,
    languages: driver.languagesSpoken,
    weddingExperienceYears: driver.weddingExperienceYears,
    operatingArea: driver.operatingArea,
    identityVerified: driver.identityVerified,
    profileImageUrl: driver.profileImageUrl,
    ceremonialAttireSizes: driver.ceremonialAttireSizes,
    dutyStatus: driver.dutyStatus,
    recentReviews: store.reviews
      .filter((r) => r.driverId === user.id)
      .slice(0, 5)
      .map(({ id, reviewerName, rating, comment, createdAt }) => ({
        id,
        reviewerName,
        rating,
        comment,
        createdAt,
      })),
  };
}

export const driversService = {
  register(user, body) {
    requireDriver(user);
    let driver = store.drivers.get(user.id);
    if (!driver) {
      driver = {
        id: user.id,
        dateOfBirth: pick(body, 'dateOfBirth'),
        experienceYears: 0,
        licenseNumber: '',
        languagesSpoken: [],
        ceremonialAttireSizes: {},
        dutyStatus: 'OFFLINE',
        verificationStatus: 'PENDING_SUBMISSION',
        isOnline: false,
        averageRating: 5,
        totalTripsCompleted: 0,
        bio: '',
        operatingArea: '',
        weddingExperienceYears: 0,
        documentStatus: 'PENDING_SUBMISSION',
        vehicleStatus: '',
        policeClearanceStatus: 'PENDING',
        ceremonialAttireStatus: 'PENDING',
        identityVerified: false,
        profileImageUrl: null,
      };
      store.drivers.set(user.id, driver);
    }
    driver.experienceYears = Number(pick(body, 'experienceYears', 'experience_years') || driver.experienceYears);
    driver.languagesSpoken = pick(body, 'languagesSpoken', 'languages_spoken') || driver.languagesSpoken;
    driver.ceremonialAttireSizes = pick(body, 'ceremonialAttireSizes', 'ceremonial_attire_sizes') || driver.ceremonialAttireSizes;
    driver.bio = pick(body, 'bio') || driver.bio;
    driver.operatingArea = pick(body, 'operatingArea', 'operating_area') || driver.operatingArea;
    if (user.accountStatus === 'profileIncomplete') user.accountStatus = 'pendingVerification';
    return toProfile(store.users.get(user.id), driver);
  },

  getProfile(user, driverId) {
    const id = driverId || user.id;
    const account = store.users.get(id);
    const driver = store.drivers.get(id);
    if (!account || !driver) throw new AppError('NOT_FOUND', 'Driver profile not found.', HttpStatus.NOT_FOUND);
    return toProfile(account, driver);
  },

  updateProfile(user, body) {
    requireDriver(user);
    const account = store.users.get(user.id);
    const driver = store.drivers.get(user.id);
    if (!account || !driver) throw new AppError('NOT_FOUND', 'Driver profile not found.', HttpStatus.NOT_FOUND);
    if (body.fullName) account.fullName = body.fullName;
    if (body.phone) account.phoneNumber = body.phone;
    if (body.email) account.email = body.email;
    driver.bio = pick(body, 'bio') ?? driver.bio;
    driver.languagesSpoken = pick(body, 'languages', 'languagesSpoken') || driver.languagesSpoken;
    driver.experienceYears = Number(pick(body, 'experienceYears') ?? driver.experienceYears);
    driver.weddingExperienceYears = Number(pick(body, 'weddingExperienceYears') ?? driver.weddingExperienceYears);
    driver.operatingArea = pick(body, 'operatingArea') ?? driver.operatingArea;
    if (body.profileImageUrl !== undefined) driver.profileImageUrl = body.profileImageUrl;
    return toProfile(account, driver);
  },

  getDutyStatus(user) {
    requireDriver(user);
    const driver = store.drivers.get(user.id);
    if (!driver) throw new AppError('NOT_FOUND', 'Driver profile not found.', HttpStatus.NOT_FOUND);
    return { status: driver.dutyStatus, isOnline: driver.isOnline };
  },

  updateDutyStatus(user, body) {
    requireDriver(user);
    const driver = store.drivers.get(user.id);
    if (!driver) throw new AppError('NOT_FOUND', 'Driver profile not found.', HttpStatus.NOT_FOUND);
    const status = String(pick(body, 'status', 'dutyStatus') || '').toUpperCase();
    const allowed = ['AVAILABLE', 'BUSY', 'OFFLINE', 'AVAILABLE_NOW'];
    if (!allowed.includes(status)) {
      throw new AppError('VALIDATION_ERROR', 'Invalid duty status.', HttpStatus.BAD_REQUEST);
    }
    driver.dutyStatus = status;
    driver.isOnline = status !== 'OFFLINE';
    return { status: driver.dutyStatus, isOnline: driver.isOnline };
  },

  updateOnlineStatus(user, isOnline) {
    requireDriver(user);
    const driver = store.drivers.get(user.id);
    driver.isOnline = Boolean(isOnline);
    if (!driver.isOnline) driver.dutyStatus = 'OFFLINE';
    else if (driver.dutyStatus === 'OFFLINE') driver.dutyStatus = 'AVAILABLE';
    return { isOnline: driver.isOnline, status: driver.dutyStatus };
  },

  submitDocument(user, body, file) {
    requireDriver(user);
    const doc = {
      id: newId(),
      driverId: user.id,
      type: pick(body, 'type', 'documentType') || 'LICENSE',
      fileName: file?.originalname || pick(body, 'fileName') || 'document.pdf',
      mimeType: file?.mimetype || 'application/octet-stream',
      size: file?.size || 0,
      status: 'SUBMITTED',
      issuedOn: pick(body, 'issuedOn'),
      expiresOn: pick(body, 'expiresOn'),
      createdAt: new Date().toISOString(),
      decisionReason: null,
    };
    store.documents.set(doc.id, doc);
    const driver = store.drivers.get(user.id);
    if (driver) {
      driver.documentStatus = 'DOCUMENTS_SUBMITTED';
      if (driver.verificationStatus === 'PENDING_SUBMISSION') driver.verificationStatus = 'UNDER_REVIEW';
    }
    return doc;
  },

  submitChecklist(user, bookingId, body) {
    requireDriver(user);
    const booking = bookingsService.loadBooking(bookingId);
    if (booking.driverId !== user.id && user.role !== ROLES.SUPER_ADMIN) {
      throw new AppError('ROLE_FORBIDDEN', 'Only the assigned chauffeur can submit the checklist.', HttpStatus.FORBIDDEN);
    }
    const check = {
      bookingId,
      isFuelChecked: Boolean(pick(body, 'isFuelChecked', 'fuelChecked')),
      isDualAcChecked: Boolean(pick(body, 'isDualAcChecked', 'dualAcChecked')),
      isGroomingChecked: Boolean(pick(body, 'isGroomingChecked', 'groomingChecked')),
      submittedAt: new Date().toISOString(),
    };
    store.checklists.set(bookingId, check);
    return check;
  },

  ingestTelemetry(user, body) {
    requireDriver(user);
    const ts = new Date(pick(body, 'timestamp') || Date.now()).getTime();
    if (Math.abs(Date.now() - ts) > config.settings.timestampDriftSeconds * 1000) {
      throw new AppError('VALIDATION_ERROR', 'Telemetry timestamp drift exceeds 5 minutes.', HttpStatus.BAD_REQUEST);
    }
    const bookingId = pick(body, 'bookingId', 'booking_id');
    const point = {
      driverId: user.id,
      bookingId,
      lat: pick(body, 'latitude') ?? body.coordinates?.lat ?? body.coordinates?.latitude,
      lng: pick(body, 'longitude') ?? body.coordinates?.lng ?? body.coordinates?.longitude,
      speed: pick(body, 'speedKmh') ?? body.coordinates?.speed ?? 0,
      bearing: pick(body, 'bearing') ?? body.coordinates?.bearing ?? 0,
      timestamp: new Date(ts).toISOString(),
    };
    store.tracking.set(bookingId || user.id, point);
    return point;
  },

  activeTrip(user) {
    requireDriver(user);
    const booking = [...store.bookings.values()].find(
      (b) =>
        b.driverId === user.id &&
        [
          BOOKING_STATUS.DRIVER_ASSIGNED,
          BOOKING_STATUS.DRIVER_ARRIVING,
          BOOKING_STATUS.EN_ROUTE,
          BOOKING_STATUS.ARRIVED,
          BOOKING_STATUS.TRIP_STARTED,
          BOOKING_STATUS.IN_PROGRESS,
          BOOKING_STATUS.EMERGENCY_REPLACEMENT,
        ].includes(b.status),
    );
    if (!booking) return null;
    return bookingsService.toActiveTrip(booking);
  },
};

void notify;
