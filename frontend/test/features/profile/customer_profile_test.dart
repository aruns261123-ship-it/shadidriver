import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/profile/domain/entities/customer_profile.dart';
import 'package:shadidriver/features/profile/data/mock_customer_profile_repository.dart';
import 'package:shadidriver/features/profile/data/mock_profile_photo_service.dart';
import 'package:shadidriver/features/profile/presentation/controllers/customer_profile_controller.dart';

void main() {
  group('CustomerProfile Entity Tests', () {
    test('creates valid CustomerProfile and verifies copyWith', () {
      final now = DateTime.now();
      final profile = CustomerProfile(
        id: 'cust_101',
        fullName: 'Aarav Sharma',
        email: 'aarav.sharma@example.com',
        phone: '+91 98765 43210',
        city: 'Delhi NCR',
        preferredLanguage: 'English',
        profilePhotoUrl: 'https://example.com/aarav.jpg',
        createdAt: now,
      );

      expect(profile.id, equals('cust_101'));
      expect(profile.fullName, equals('Aarav Sharma'));
      expect(profile.email, equals('aarav.sharma@example.com'));
      expect(profile.phone, equals('+91 98765 43210'));
      expect(profile.profilePhotoUrl, equals('https://example.com/aarav.jpg'));
      expect(profile.city, equals('Delhi NCR'));
      expect(profile.preferredLanguage, equals('English'));
      expect(profile.isValid, isTrue);

      final updated = profile.copyWith(
        fullName: 'Aarav K. Sharma',
        city: 'Jaipur',
      );

      expect(updated.fullName, equals('Aarav K. Sharma'));
      expect(updated.city, equals('Jaipur'));
      expect(updated.id, equals('cust_101'));
    });
  });

  group('MockCustomerProfileRepository Tests', () {
    late MockCustomerProfileRepository repository;

    setUp(() {
      repository = MockCustomerProfileRepository();
    });

    test('getProfile returns seeded profile for cust_101', () async {
      final result = await repository.getProfile('cust_101');
      expect(result.isSuccess, isTrue);
      final profile = result.dataOrNull!;
      expect(profile.id, equals('cust_101'));
      expect(profile.fullName, equals('Aditya Singhal'));
      expect(profile.city, equals('Delhi NCR'));
    });

    test('getProfile returns default profile for unknown user', () async {
      final result = await repository.getProfile('unknown_user');
      expect(result.isSuccess, isTrue);
      final profile = result.dataOrNull!;
      expect(profile.id, equals('unknown_user'));
      expect(profile.fullName, equals('Customer unknown_user'));
    });

    test('updateProfile persists and updates in memory', () async {
      final initial = await repository.getProfile('cust_101');
      final currentProfile = initial.dataOrNull!;

      final modified = currentProfile.copyWith(
        fullName: 'Aarav V. Sharma',
        city: 'Udaipur',
      );

      final updateResult = await repository.updateProfile(modified);
      expect(updateResult.isSuccess, isTrue);

      final fetchResult = await repository.getProfile('cust_101');
      final profile = fetchResult.dataOrNull!;
      expect(profile.fullName, equals('Aarav V. Sharma'));
      expect(profile.city, equals('Udaipur'));
      expect(profile.updatedAt, isNotNull);
    });
  });

  group('CustomerProfileController Tests', () {
    late MockCustomerProfileRepository repository;
    late MockProfilePhotoService photoService;
    late CustomerProfileController controller;

    setUp(() {
      repository = MockCustomerProfileRepository();
      photoService = MockProfilePhotoService();
      controller = CustomerProfileController(
        repository: repository,
        photoService: photoService,
        customerId: 'cust_101',
      );
    });

    test('initializes and loads profile for cust_101', () async {
      await controller.loadProfile();
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.profile, isNotNull);
      expect(controller.state.profile!.id, equals('cust_101'));
      expect(controller.state.profile!.fullName, equals('Aditya Singhal'));
    });

    test('updateProfile successfully saves new details', () async {
      await controller.loadProfile();
      final current = controller.state.profile!;

      final updated = current.copyWith(fullName: 'Aarav Kumar');
      final success = await controller.updateProfile(updated);

      expect(success, isTrue);
      expect(controller.state.profile!.fullName, equals('Aarav Kumar'));
      expect(controller.state.successMessage, contains('successfully updated'));
    });

    test(
      'pickAndSavePhotoFromGallery and removePhoto update photo state',
      () async {
        await controller.loadProfile();

        final pickSuccess = await controller.pickAndSavePhotoFromGallery();
        expect(pickSuccess, isTrue);
        expect(controller.state.profile!.profilePhotoUrl, isNotNull);

        final removeSuccess = await controller.removePhoto();
        expect(removeSuccess, isTrue);
        expect(controller.state.profile!.profilePhotoUrl, isNull);
      },
    );
  });
}
