import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../../auth/domain/entities/user_role.dart';
import '../domain/entities/admin_profile.dart';
import '../domain/repositories/admin_profile_repository.dart';

/// In-memory development mock for [AdminProfileRepository].
class MockAdminProfileRepository implements AdminProfileRepository {
  final Map<String, AdminProfile> _profiles = {};

  MockAdminProfileRepository() {
    _seedDefaultAdmin();
  }

  void _seedDefaultAdmin() {
    final now = DateTime.now();
    _profiles['admin_ops'] = AdminProfile(
      id: 'admin_ops',
      fullName: 'Vikram Malhotra',
      email: 'ops.admin@shadidriver.com',
      phone: '+91 98111 22233',
      role: UserRole.operationsAdmin,
      department: 'Fleet Operations & Verification Command',
      authorizationLevel: 'Tier 3 - Operational Command Access',
      createdAt: now.subtract(const Duration(days: 90)),
      updatedAt: now,
    );
  }

  @override
  Future<Result<AdminProfile>> getProfile(String adminId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final profile = _profiles[adminId];
    if (profile != null) {
      return Result.success(profile);
    }
    // Fallback creates standard operations admin profile
    final created = AdminProfile(
      id: adminId,
      fullName: 'Administrator $adminId',
      email: '$adminId@shadidriver.com',
      phone: '+91 98000 00000',
      role: UserRole.operationsAdmin,
      department: 'Platform Administration',
      authorizationLevel: 'Standard Operational Access',
      createdAt: DateTime.now(),
    );
    _profiles[adminId] = created;
    return Result.success(created);
  }

  @override
  Future<Result<AdminProfile>> updateContactInfo({
    required String adminId,
    required String fullName,
    required String phone,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final existing = _profiles[adminId];
    if (existing == null) {
      return const Result.failure(NotFoundFailure('Admin profile not found.'));
    }

    if (fullName.trim().length < 2) {
      return const Result.failure(
        ValidationFailure('Administrator name must be at least 2 characters.'),
      );
    }

    final updated = existing.copyWithContactInfo(
      fullName: fullName,
      phone: phone,
    );
    _profiles[adminId] = updated;
    return Result.success(updated);
  }

  @override
  Future<Result<String>> updateProfilePhoto({
    required String adminId,
    required String photoUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final existing = _profiles[adminId];
    if (existing == null) {
      return const Result.failure(NotFoundFailure('Admin profile not found.'));
    }
    final updated = existing.copyWithContactInfo(photoUrl: photoUrl);
    _profiles[adminId] = updated;
    return Result.success(photoUrl);
  }
}
