import { clone } from '../utils/crypto.js';
import { buildSeed } from './seed.js';

function indexById(items) {
  const map = new Map();
  for (const item of items) map.set(item.id, item);
  return map;
}

export function createStore() {
  const seed = buildSeed();

  const store = {
    users: indexById(seed.users),
    customers: new Map(Object.entries(seed.customers)),
    drivers: new Map(Object.entries(seed.drivers)),
    admins: new Map(Object.entries(seed.admins)),
    categories: indexById(seed.categories),
    addons: indexById(seed.addons),
    policies: indexById(seed.policies),
    pricingRules: indexById(seed.pricingRules),
    vehicles: indexById(seed.vehicles),
    reviews: seed.reviews,
    addresses: indexById(seed.addresses),
    drafts: new Map(),
    bookings: new Map(),
    bookingEvents: [],
    availabilities: [],
    payments: new Map(),
    notifications: [],
    documents: new Map(),
    checklists: new Map(),
    groupBookings: new Map(),
    assignments: [],
    supportTickets: [],
    otpSessions: new Map(),
    otpRate: new Map(),
    otpCooldown: new Map(),
    refreshTokens: new Map(),
    idempotency: new Map(),
    tracking: new Map(),
    bookingRefSeq: 42,
    groupRefSeq: 12,
  };

  return {
    ...store,
    snapshot() {
      return clone(store);
    },
  };
}

export const store = createStore();
