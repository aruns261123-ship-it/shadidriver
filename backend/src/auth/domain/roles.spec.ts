import { Role, isAdminRole, isPublicSignupRole, ADMIN_ROLES } from './roles';

describe('Roles', () => {
  it('recognizes all four admin roles', () => {
    expect(isAdminRole(Role.OperationsAdmin)).toBe(true);
    expect(isAdminRole(Role.VerificationAdmin)).toBe(true);
    expect(isAdminRole(Role.FinanceAdmin)).toBe(true);
    expect(isAdminRole(Role.SuperAdmin)).toBe(true);
    expect(ADMIN_ROLES).toHaveLength(4);
  });

  it('does not treat customer, driver, or fleet owner as admin', () => {
    expect(isAdminRole(Role.Customer)).toBe(false);
    expect(isAdminRole(Role.Driver)).toBe(false);
    expect(isAdminRole(Role.FleetOwner)).toBe(false);
  });

  it('public signup is limited to customer and driver (rule: no public admin creation)', () => {
    expect(isPublicSignupRole(Role.Customer)).toBe(true);
    expect(isPublicSignupRole(Role.Driver)).toBe(true);
    for (const role of ADMIN_ROLES) {
      expect(isPublicSignupRole(role)).toBe(false);
    }
    expect(isPublicSignupRole(Role.FleetOwner)).toBe(false);
  });
});
