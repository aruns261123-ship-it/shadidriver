/// Platform user roles for ShadiDriver.
///
/// All role checks in the Flutter client are advisory for UX routing only.
/// The backend enforces authoritative RBAC on every API request.
enum UserRole {
  customer,
  driver,
  fleetOwner,
  operationsAdmin,
  verificationAdmin,
  financeAdmin,
  superAdmin;

  /// Whether this role belongs to the admin/operations staff group.
  bool get isAdmin => switch (this) {
    UserRole.operationsAdmin => true,
    UserRole.verificationAdmin => true,
    UserRole.financeAdmin => true,
    UserRole.superAdmin => true,
    _ => false,
  };

  /// Whether this role is a platform staff member (including fleet owners).
  bool get isStaff => isAdmin || this == UserRole.fleetOwner;

  /// Human-readable display label.
  String get displayLabel => switch (this) {
    UserRole.customer => 'Customer',
    UserRole.driver => 'Driver',
    UserRole.fleetOwner => 'Fleet Owner',
    UserRole.operationsAdmin => 'Operations Admin',
    UserRole.verificationAdmin => 'Verification Admin',
    UserRole.financeAdmin => 'Finance Admin',
    UserRole.superAdmin => 'Super Admin',
  };

  /// The default GoRouter path for this role after successful authentication.
  String get defaultRoute => switch (this) {
    UserRole.customer => '/customer',
    UserRole.driver => '/driver',
    UserRole.fleetOwner => '/fleet-owner',
    UserRole.operationsAdmin => '/ops-admin',
    UserRole.verificationAdmin => '/verification-admin',
    UserRole.financeAdmin => '/finance-admin',
    UserRole.superAdmin => '/super-admin',
  };

  /// Serialize to a stable string stored in secure storage.
  String get storageKey => switch (this) {
    UserRole.customer => 'customer',
    UserRole.driver => 'driver',
    UserRole.fleetOwner => 'fleet_owner',
    UserRole.operationsAdmin => 'operations_admin',
    UserRole.verificationAdmin => 'verification_admin',
    UserRole.financeAdmin => 'finance_admin',
    UserRole.superAdmin => 'super_admin',
  };

  /// Deserialize from a storage key string.
  static UserRole? fromStorageKey(String? key) => switch (key) {
    'customer' => UserRole.customer,
    'driver' => UserRole.driver,
    'fleet_owner' => UserRole.fleetOwner,
    'operations_admin' => UserRole.operationsAdmin,
    'verification_admin' => UserRole.verificationAdmin,
    'finance_admin' => UserRole.financeAdmin,
    'super_admin' => UserRole.superAdmin,
    _ => null,
  };
}
