import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../domain/entities/customer_profile.dart';
import '../domain/repositories/customer_profile_repository.dart';

/// In-memory development mock for [CustomerProfileRepository].
class MockCustomerProfileRepository implements CustomerProfileRepository {
  final Map<String, CustomerProfile> _profiles = {};

  MockCustomerProfileRepository() {
    _seedDefaultProfile();
  }

  void _seedDefaultProfile() {
    final now = DateTime.now();
    _profiles['cust_101'] = CustomerProfile(
      id: 'cust_101',
      fullName: 'Aditya Singhal',
      phone: '+91 98765 43210',
      email: 'aditya.singhal@example.com',
      city: 'Delhi NCR',
      preferredLanguage: 'English',
      emergencyContactName: 'Vikram Malhotra',
      emergencyContactPhone: '+91 98100 12345',
      weddingPreferences: 'Royal Bandhgala Chauffeur, Mercedes or BMW',
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now,
    );
  }

  @override
  Future<Result<CustomerProfile>> getProfile(String customerId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final profile = _profiles[customerId];
    if (profile != null) {
      return Result.success(profile);
    }
    // Fallback creates a default initial profile if none exists
    final created = CustomerProfile(
      id: customerId,
      fullName: 'Customer $customerId',
      phone: '+91 98765 00000',
      city: 'Delhi NCR',
      createdAt: DateTime.now(),
    );
    _profiles[customerId] = created;
    return Result.success(created);
  }

  @override
  Future<Result<CustomerProfile>> updateProfile(CustomerProfile profile) async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (!profile.isValid) {
      return const Result.failure(
        ValidationFailure('Please provide a valid full name, phone, and city.'),
      );
    }
    final updated = profile.copyWith(updatedAt: DateTime.now());
    _profiles[profile.id] = updated;
    return Result.success(updated);
  }

  @override
  Future<Result<String>> updateProfilePhoto({
    required String customerId,
    required String photoUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final existing = _profiles[customerId];
    if (existing == null) {
      return const Result.failure(
        NotFoundFailure('Customer profile not found.'),
      );
    }
    final updated = existing.copyWith(
      profilePhotoUrl: photoUrl,
      updatedAt: DateTime.now(),
    );
    _profiles[customerId] = updated;
    return Result.success(photoUrl);
  }
}
