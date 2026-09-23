/**
 * Actor roles — mirrors the frontend UserRole enum and the SQL CHECK
 * constraint in infra/migrations/0001_init.sql (camelCase wire values).
 */
export enum Role {
  Customer = 'customer',
  Driver = 'driver',
  FleetOwner = 'fleetOwner',
  OperationsAdmin = 'operationsAdmin',
  VerificationAdmin = 'verificationAdmin',
  FinanceAdmin = 'financeAdmin',
  SuperAdmin = 'superAdmin',
}

export const ADMIN_ROLES: readonly Role[] = [
  Role.OperationsAdmin,
  Role.VerificationAdmin,
  Role.FinanceAdmin,
  Role.SuperAdmin,
];

export function isAdminRole(role: Role): boolean {
  return ADMIN_ROLES.includes(role);
}

/**
 * Roles that may never be created through public signup — admin identities
 * are provisioned internally by the platform only.
 */
export function isPublicSignupRole(role: Role): boolean {
  return role === Role.Customer || role === Role.Driver;
}
