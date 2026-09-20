import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/auth/domain/entities/user_role.dart';
import 'package:shadidriver/features/profile/domain/entities/admin_profile.dart';
import 'package:shadidriver/features/profile/data/mock_admin_profile_repository.dart';
import 'package:shadidriver/features/profile/data/mock_profile_photo_service.dart';
import 'package:shadidriver/features/profile/presentation/controllers/admin_profile_controller.dart';

void main() {
  group('AdminProfile Entity & Authorization Invariants Tests', () {
    test('role and authorizationLevel are read-only and immutable', () {
      final now = DateTime.now();
      final admin = AdminProfile(
        id: 'admin_ops',
        fullName: 'Vikram Malhotra',
        email: 'vikram.malhotra@shadidriver.com',
        phone: '+91 98100 55443',
        photoUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e',
        role: UserRole.operationsAdmin,
        department: 'Operations & Chauffeur Fleet Control',
        authorizationLevel: 'LEVEL 3 — OPERATIONS & DISPATCH CONTROLLER',
        createdAt: now,
      );

      expect(admin.role, equals(UserRole.operationsAdmin));
      expect(admin.authorizationLevel, contains('LEVEL 3'));

      // copyWithContactInfo allows non-privileged modifications
      final modified = admin.copyWithContactInfo(
        fullName: 'Vikram S. Malhotra',
        phone: '+91 98100 99999',
      );

      expect(modified.fullName, equals('Vikram S. Malhotra'));
      expect(modified.phone, equals('+91 98100 99999'));
      // Invariants remain intact
      expect(modified.role, equals(UserRole.operationsAdmin));
      expect(modified.authorizationLevel, equals(admin.authorizationLevel));
    });
  });

  group('MockAdminProfileRepository & AdminProfileController Tests', () {
    late MockAdminProfileRepository repository;
    late MockProfilePhotoService photoService;
    late AdminProfileController controller;

    setUp(() {
      repository = MockAdminProfileRepository();
      photoService = MockProfilePhotoService();
      controller = AdminProfileController(
        repository: repository,
        photoService: photoService,
        adminId: 'admin_ops',
      );
    });

    test('getProfile returns seeded admin_ops', () async {
      final res = await repository.getProfile('admin_ops');
      expect(res.isSuccess, isTrue);
      final profile = res.dataOrNull!;
      expect(profile.fullName, equals('Vikram Malhotra'));
      expect(profile.role, equals(UserRole.operationsAdmin));
      expect(profile.authorizationLevel, contains('Tier 3'));
    });

    test('initializes and loads admin info', () async {
      await controller.loadProfile();
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.profile, isNotNull);
      expect(controller.state.profile!.fullName, equals('Vikram Malhotra'));
    });

    test('updateContactInfo updates name and phone', () async {
      await controller.loadProfile();

      final ok = await controller.updateContactInfo(
        fullName: 'Vikram S. Malhotra',
        phone: '+91 98100 11111',
      );
      expect(ok, isTrue);
      expect(controller.state.profile!.fullName, equals('Vikram S. Malhotra'));
      expect(controller.state.profile!.phone, equals('+91 98100 11111'));
    });

    test('pickAndSavePhotoFromGallery updates admin avatar', () async {
      await controller.loadProfile();

      final updateOk = await controller.pickAndSavePhotoFromGallery();
      expect(updateOk, isTrue);
      expect(controller.state.profile!.photoUrl, isNotNull);
    });
  });
}
