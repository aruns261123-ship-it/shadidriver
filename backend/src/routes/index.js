import { Router } from 'express';
import { authenticate, requireAdmin, requireRoles } from '../middleware/auth.js';
import { ok, wrap } from '../middleware/envelope.js';
import { idempotencyMiddleware } from '../middleware/idempotency.js';
import { ROLES } from '../domain/roles.js';
import { pick } from '../utils/body.js';
import { authService } from '../services/auth.service.js';
import { catalogService } from '../services/catalog.service.js';
import { vehiclesService } from '../services/vehicles.service.js';
import { bookingsService } from '../services/bookings.service.js';
import { paymentsService } from '../services/payments.service.js';
import { driversService } from '../services/drivers.service.js';
import { tripsService } from '../services/trips.service.js';
import { profilesService } from '../services/profiles.service.js';
import { notificationsService } from '../services/notifications.service.js';
import { adminService } from '../services/admin.service.js';
import { supportService } from '../services/support.service.js';

const publicRouter = Router();
const protectedRouter = Router();

publicRouter.get('/health', (_req, res) => ok(res, { status: 'ok', storage: 'memory' }));

publicRouter.post(
  '/auth/otp/request',
  wrap((req, res) => {
    const ip = (req.headers['x-forwarded-for'] || '').toString().split(',')[0].trim() || req.ip || '127.0.0.1';
    return ok(res, authService.requestOtp(req.body, ip));
  }),
);

publicRouter.post(
  '/auth/otp/verify',
  wrap((req, res) => ok(res, authService.verifyOtp(req.body))),
);

publicRouter.post(
  '/auth/session/refresh',
  wrap((req, res) => ok(res, authService.refresh(req.body))),
);

publicRouter.get('/catalog/categories', (_req, res) => ok(res, catalogService.categories()));
publicRouter.get('/catalog/addons', (_req, res) => ok(res, catalogService.addons()));
publicRouter.post(
  '/catalog/estimate',
  wrap((req, res) => ok(res, catalogService.estimate(req.body))),
);

publicRouter.get('/vehicles/featured', (_req, res) => ok(res, vehiclesService.featured()));
publicRouter.get('/vehicles/search', (req, res) => ok(res, vehiclesService.searchFromRequest(req)));
publicRouter.post('/vehicles/search', (req, res) => ok(res, vehiclesService.searchFromRequest(req)));
publicRouter.get('/vehicles/:id/details', wrap((req, res) => ok(res, vehiclesService.byId(req.params.id))));
publicRouter.get('/vehicles/:id', wrap((req, res) => ok(res, vehiclesService.byId(req.params.id))));

publicRouter.post(
  '/payments/webhook',
  wrap((req, res) => ok(res, paymentsService.webhook(req.headers, req.body))),
);

protectedRouter.use(authenticate(true));
protectedRouter.use(idempotencyMiddleware);

protectedRouter.post(
  '/auth/signout',
  wrap((req, res) => ok(res, authService.signOut(req.user.id, pick(req.body, 'refreshToken', 'refresh_token')))),
);

protectedRouter.post(
  '/bookings/drafts',
  requireRoles(ROLES.CUSTOMER),
  wrap((req, res) => ok(res, bookingsService.createDraft(req.user, req.body), 201)),
);
protectedRouter.get(
  '/bookings/drafts/:id',
  wrap((req, res) => ok(res, bookingsService.getDraft(req.user, req.params.id))),
);
protectedRouter.put(
  '/bookings/drafts/:id',
  wrap((req, res) => ok(res, bookingsService.saveDraft(req.user, { ...req.body, id: req.params.id }))),
);
protectedRouter.post(
  '/bookings/submit',
  requireRoles(ROLES.CUSTOMER),
  wrap((req, res) => {
    const key = req.header('idempotency-key') || req.header('x-idempotency-key');
    return ok(res, bookingsService.submit(req.user, req.body, key), 201);
  }),
);
protectedRouter.post(
  '/bookings',
  requireRoles(ROLES.CUSTOMER),
  wrap((req, res) => {
    const key = req.header('idempotency-key') || req.header('x-idempotency-key');
    return ok(res, bookingsService.submit(req.user, req.body, key), 201);
  }),
);
protectedRouter.get(
  '/bookings/my',
  wrap((req, res) => {
    const page = Number(req.query.page || 1);
    const limit = Number(req.query.limit || 20);
    const result = bookingsService.getMy(req.user, page, limit, req.query.status);
    return ok(res, result.data, 200, result.meta);
  }),
);
protectedRouter.post(
  '/bookings/fleet/availability',
  wrap((req, res) => ok(res, bookingsService.checkFleetAvailability(req.body))),
);
protectedRouter.post(
  '/bookings/group',
  requireRoles(ROLES.CUSTOMER),
  wrap((req, res) => {
    const key = req.header('idempotency-key') || req.header('x-idempotency-key');
    return ok(res, bookingsService.submitGroupBooking(req.user, req.body, key), 201);
  }),
);
protectedRouter.get(
  '/bookings/group/:id',
  wrap((req, res) => ok(res, bookingsService.getGroupBooking(req.user, req.params.id))),
);
protectedRouter.get(
  '/bookings/:id/submission',
  wrap((req, res) => ok(res, bookingsService.getSubmission(req.user, req.params.id))),
);
protectedRouter.get(
  '/bookings/:id',
  wrap((req, res) => ok(res, bookingsService.getById(req.user, req.params.id))),
);
protectedRouter.post(
  '/bookings/:id/transition',
  wrap((req, res) => ok(res, bookingsService.transition(req.user, req.params.id, req.body))),
);
protectedRouter.post(
  '/bookings/:id/accept',
  requireRoles(ROLES.DRIVER, ROLES.FLEET_OWNER),
  wrap((req, res) => ok(res, bookingsService.accept(req.user, req.params.id, req.body?.currentVersion))),
);
protectedRouter.post(
  '/bookings/:id/decline',
  requireRoles(ROLES.DRIVER, ROLES.FLEET_OWNER),
  wrap((req, res) => ok(res, bookingsService.decline(req.user, req.params.id, req.body))),
);
protectedRouter.post(
  '/bookings/:id/cancel',
  wrap((req, res) => ok(res, bookingsService.cancel(req.user, req.params.id, req.body))),
);

protectedRouter.get(
  '/driver/duty-status',
  requireRoles(ROLES.DRIVER, ROLES.FLEET_OWNER),
  wrap((req, res) => ok(res, driversService.getDutyStatus(req.user))),
);
protectedRouter.put(
  '/driver/duty-status',
  requireRoles(ROLES.DRIVER, ROLES.FLEET_OWNER),
  wrap((req, res) => ok(res, driversService.updateDutyStatus(req.user, req.body))),
);
protectedRouter.get(
  '/driver/offers',
  requireRoles(ROLES.DRIVER, ROLES.FLEET_OWNER),
  wrap((req, res) => ok(res, bookingsService.driverOffers(req.user))),
);
protectedRouter.get(
  '/driver/offers/:id',
  requireRoles(ROLES.DRIVER, ROLES.FLEET_OWNER),
  wrap((req, res) => ok(res, bookingsService.driverDetails(req.user, req.params.id))),
);
protectedRouter.post(
  '/driver/offers/:id/accept',
  requireRoles(ROLES.DRIVER, ROLES.FLEET_OWNER),
  wrap((req, res) => ok(res, bookingsService.accept(req.user, req.params.id))),
);
protectedRouter.post(
  '/driver/offers/:id/decline',
  requireRoles(ROLES.DRIVER, ROLES.FLEET_OWNER),
  wrap((req, res) => ok(res, bookingsService.decline(req.user, req.params.id, req.body))),
);
protectedRouter.get(
  '/driver/active-trip',
  requireRoles(ROLES.DRIVER, ROLES.FLEET_OWNER),
  wrap((req, res) => ok(res, driversService.activeTrip(req.user))),
);
protectedRouter.post(
  '/driver/telemetry',
  requireRoles(ROLES.DRIVER, ROLES.FLEET_OWNER),
  wrap((req, res) => ok(res, driversService.ingestTelemetry(req.user, req.body))),
);
protectedRouter.post(
  '/drivers/register',
  requireRoles(ROLES.DRIVER, ROLES.FLEET_OWNER),
  wrap((req, res) => ok(res, driversService.register(req.user, req.body), 201)),
);
protectedRouter.post(
  '/drivers/documents',
  requireRoles(ROLES.DRIVER, ROLES.FLEET_OWNER),
  wrap((req, res) => ok(res, driversService.submitDocument(req.user, req.body, req.file), 201)),
);
protectedRouter.get(
  '/drivers/profile',
  requireRoles(ROLES.DRIVER, ROLES.FLEET_OWNER),
  wrap((req, res) => ok(res, driversService.getProfile(req.user))),
);
protectedRouter.put(
  '/drivers/profile',
  requireRoles(ROLES.DRIVER, ROLES.FLEET_OWNER),
  wrap((req, res) => ok(res, driversService.updateProfile(req.user, req.body))),
);
protectedRouter.get(
  '/drivers/:id',
  wrap((req, res) => ok(res, driversService.getProfile(req.user, req.params.id))),
);
protectedRouter.post(
  '/drivers/pre-trip-checklist/:bookingId',
  requireRoles(ROLES.DRIVER, ROLES.FLEET_OWNER),
  wrap((req, res) => ok(res, driversService.submitChecklist(req.user, req.params.bookingId, req.body))),
);

protectedRouter.post(
  '/trips/:id/milestones/arrived',
  wrap((req, res) => ok(res, tripsService.arrived(req.user, req.params.id, req.body))),
);
protectedRouter.post(
  '/trips/:id/start',
  wrap((req, res) => ok(res, tripsService.start(req.user, req.params.id, req.body))),
);
protectedRouter.post(
  '/trips/:id/complete',
  wrap((req, res) => ok(res, tripsService.complete(req.user, req.params.id, req.body))),
);
protectedRouter.post(
  '/trips/:id/start-route',
  wrap((req, res) => ok(res, tripsService.startRoute(req.user, req.params.id, req.body))),
);

protectedRouter.post(
  '/payments/create-order',
  requireRoles(ROLES.CUSTOMER),
  wrap((req, res) => {
    const key = req.header('idempotency-key') || req.header('x-idempotency-key');
    return ok(res, paymentsService.createOrder(req.user, req.body, key));
  }),
);
protectedRouter.post(
  '/payments/advance-token/order',
  requireRoles(ROLES.CUSTOMER),
  wrap((req, res) => {
    const key = req.header('idempotency-key') || req.header('x-idempotency-key');
    return ok(res, paymentsService.createOrder(req.user, { ...req.body, paymentType: 'ADVANCE_TOKEN' }, key));
  }),
);
protectedRouter.post(
  '/payments/verify',
  requireRoles(ROLES.CUSTOMER),
  wrap((req, res) => ok(res, paymentsService.verify(req.user, req.body))),
);

protectedRouter.get('/users/profile', wrap((req, res) => ok(res, profilesService.getCustomer(req.user))));
protectedRouter.put('/users/profile', wrap((req, res) => ok(res, profilesService.updateCustomer(req.user, req.body))));
protectedRouter.get('/users/addresses', wrap((req, res) => ok(res, profilesService.listAddresses(req.user))));
protectedRouter.post(
  '/users/addresses',
  wrap((req, res) => ok(res, profilesService.createAddress(req.user, req.body), 201)),
);
protectedRouter.delete(
  '/users/addresses/:id',
  wrap((req, res) => ok(res, profilesService.deleteAddress(req.user, req.params.id))),
);

protectedRouter.get('/admin/profile', requireAdmin, wrap((req, res) => ok(res, profilesService.getAdmin(req.user))));
protectedRouter.put(
  '/admin/profile',
  requireAdmin,
  wrap((req, res) => ok(res, profilesService.updateAdmin(req.user, req.body))),
);
protectedRouter.get('/admin/dashboard', requireAdmin, (_req, res) => ok(res, adminService.dashboard()));
protectedRouter.get(
  '/admin/bookings',
  requireAdmin,
  wrap((req, res) => ok(res, adminService.listBookings(req.query.status))),
);
protectedRouter.get('/admin/verifications', requireAdmin, (_req, res) => ok(res, adminService.listPendingDocuments()));
protectedRouter.post(
  '/admin/verifications/:documentId/decision',
  requireAdmin,
  wrap((req, res) => ok(res, adminService.decideDocument(req.user, req.params.documentId, req.body))),
);
protectedRouter.post(
  '/admin/bookings/:bookingId/emergency-reassign',
  requireAdmin,
  wrap((req, res) => ok(res, adminService.emergencyReassign(req.user, req.params.bookingId, req.body))),
);

protectedRouter.get('/notifications', wrap((req, res) => ok(res, notificationsService.list(req.user))));
protectedRouter.put(
  '/notifications/:id/read',
  wrap((req, res) => ok(res, notificationsService.markRead(req.user, req.params.id))),
);

protectedRouter.post(
  '/support/tickets',
  wrap((req, res) => ok(res, supportService.createTicket(req.user, req.body), 201)),
);
protectedRouter.post(
  '/reviews',
  wrap((req, res) => ok(res, supportService.submitReview(req.user, req.body), 201)),
);
protectedRouter.post(
  '/dispatch/urgent',
  wrap((req, res) => ok(res, supportService.urgentDispatch(req.user, req.body), 201)),
);

export function mountRoutes(app) {
  app.use('/api/v1', publicRouter);
  app.use('/api/v1', protectedRouter);
  app.get('/health', (_req, res) => ok(res, { status: 'ok', storage: 'memory' }));
}
