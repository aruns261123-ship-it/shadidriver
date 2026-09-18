export const ROLES = {
  CUSTOMER: 'customer',
  DRIVER: 'driver',
  FLEET_OWNER: 'fleetOwner',
  OPERATIONS_ADMIN: 'operationsAdmin',
  VERIFICATION_ADMIN: 'verificationAdmin',
  FINANCE_ADMIN: 'financeAdmin',
  SUPER_ADMIN: 'superAdmin',
  SYSTEM: 'SYSTEM',
};

export const ADMIN_ROLES = [
  ROLES.OPERATIONS_ADMIN,
  ROLES.VERIFICATION_ADMIN,
  ROLES.FINANCE_ADMIN,
  ROLES.SUPER_ADMIN,
];

export function isAdminRole(role) {
  return ADMIN_ROLES.includes(role);
}

export function normalizeRole(role) {
  const raw = String(role || '').trim();
  const map = {
    customer: ROLES.CUSTOMER,
    driver: ROLES.DRIVER,
    fleetowner: ROLES.FLEET_OWNER,
    fleet_owner: ROLES.FLEET_OWNER,
    operationsadmin: ROLES.OPERATIONS_ADMIN,
    operations_admin: ROLES.OPERATIONS_ADMIN,
    verificationadmin: ROLES.VERIFICATION_ADMIN,
    verification_admin: ROLES.VERIFICATION_ADMIN,
    financeadmin: ROLES.FINANCE_ADMIN,
    finance_admin: ROLES.FINANCE_ADMIN,
    superadmin: ROLES.SUPER_ADMIN,
    super_admin: ROLES.SUPER_ADMIN,
    CUSTOMER: ROLES.CUSTOMER,
    DRIVER: ROLES.DRIVER,
    FLEET_OWNER: ROLES.FLEET_OWNER,
    OPERATIONS_ADMIN: ROLES.OPERATIONS_ADMIN,
    VERIFICATION_ADMIN: ROLES.VERIFICATION_ADMIN,
    FINANCE_ADMIN: ROLES.FINANCE_ADMIN,
    SUPER_ADMIN: ROLES.SUPER_ADMIN,
  };
  return map[raw] || map[raw.toLowerCase()] || ROLES.CUSTOMER;
}

export function toAccountStatus(status) {
  const map = {
    ACTIVE: 'active',
    active: 'active',
    PROFILE_INCOMPLETE: 'profileIncomplete',
    profileIncomplete: 'profileIncomplete',
    PENDING_VERIFICATION: 'pendingVerification',
    pendingVerification: 'pendingVerification',
    SUSPENDED: 'suspended',
    suspended: 'suspended',
  };
  return map[status] || 'active';
}
