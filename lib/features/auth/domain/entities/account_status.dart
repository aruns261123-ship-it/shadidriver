/// Account lifecycle status for a ShadiDriver user.
///
/// The backend is the sole authority for setting these statuses.
/// The client reads the status from the JWT claims / session and adjusts routing.
enum AccountStatus {
  /// Account is active and fully usable.
  active,

  /// Account exists but the profile is not yet complete (e.g., missing name/photo).
  /// User can still authenticate but is routed to the profile completion flow.
  profileIncomplete,

  /// Account is pending initial KYC or operator verification.
  /// Applicable to new drivers and fleet owners.
  pendingVerification,

  /// Account has been suspended by an admin.
  /// User can authenticate but all feature screens are blocked.
  suspended;

  /// Whether the user should be routed to a feature screen (not a gating screen).
  bool get canAccessFeatures => this == AccountStatus.active;

  /// Stable storage key used when persisting account status.
  String get storageKey => switch (this) {
    AccountStatus.active => 'active',
    AccountStatus.profileIncomplete => 'profile_incomplete',
    AccountStatus.pendingVerification => 'pending_verification',
    AccountStatus.suspended => 'suspended',
  };

  /// Deserialize from a storage key string.
  static AccountStatus fromStorageKey(String? key) => switch (key) {
    'profile_incomplete' => AccountStatus.profileIncomplete,
    'pending_verification' => AccountStatus.pendingVerification,
    'suspended' => AccountStatus.suspended,
    _ => AccountStatus.active, // Safe default
  };
}
