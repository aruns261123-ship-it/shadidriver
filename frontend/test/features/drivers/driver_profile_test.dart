import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_profile.dart';
import 'package:shadidriver/features/drivers/data/mock_driver_profile_repository.dart';
import 'package:shadidriver/features/profile/data/mock_profile_photo_service.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/driver_profile_controller.dart';

void main() {
  group('DriverProfile Entity & Verification Decoupling Tests', () {
    test(
      'completionPercentage calculates correctly based on profile attributes',
      () {
        // 1. Minimal profile with only basic fields:
        // fullName >= 2 (+15), phone >= 10 (+15) = 30%
        const minimal = DriverProfile(
          id: 'd_min',
          fullName: 'Test Driver',
          phone: '+91 99999 88888',
          verificationStatus: 'UNDER_REVIEW',
          isOnline: false,
          experienceYears: 0,
          rating: 5.0,
          totalTrips: 0,
          bio: '',
          languages: [],
          weddingExperienceYears: 0,
          operatingArea: '',
        );
        expect(minimal.completionPercentage, equals(30));

        // 2. Profile with bio (+15), experienceYears (+10), operatingArea (+10), languages (+10), weddingExperience (+10):
        // 30 + 15 + 10 + 10 + 10 + 10 = 85% (no photo)
        final withoutPhoto = minimal.copyWith(
          bio: 'Experienced royal wedding chauffeur.',
          experienceYears: 8,
          operatingArea: 'Delhi NCR',
          languages: const ['Hindi', 'English'],
          weddingExperienceYears: 5,
        );
        expect(withoutPhoto.completionPercentage, equals(85));

        // 3. Fully completed profile (including photo +15): 100%
        final complete = withoutPhoto.copyWith(
          profileImageUrl:
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
        );
        expect(complete.completionPercentage, equals(100));
      },
    );

    test(
      'completion percentage is strictly decoupled from verificationStatus',
      () {
        // 100% completed profile still has verificationStatus as UNDER_REVIEW
        final profile = const DriverProfile(
          id: 'd_review',
          fullName: 'Rajesh Kumar',
          phone: '+91 98111 22334',
          profileImageUrl: 'https://example.com/photo.jpg',
          verificationStatus: 'UNDER_REVIEW',
          isOnline: true,
          experienceYears: 12,
          rating: 4.95,
          totalTrips: 140,
          bio:
              'Over 12 years of specialized baraat and royal wedding experience.',
          languages: ['Hindi', 'English', 'Punjabi'],
          weddingExperienceYears: 10,
          operatingArea: 'Delhi NCR, Jaipur & Agra',
          identityVerified: false,
        );

        expect(profile.completionPercentage, equals(100));
        expect(profile.verificationStatus, equals('UNDER_REVIEW'));
        expect(profile.identityVerified, isFalse);
      },
    );

    test(
      'copyWithEditableFields only allows modifying editable fields and protects invariants',
      () {
        const original = DriverProfile(
          id: 'd1',
          fullName: 'Rajesh Kumar',
          phone: '+91 98111 22334',
          verificationStatus: 'UNDER_REVIEW',
          isOnline: false,
          experienceYears: 12,
          rating: 4.95,
          totalTrips: 140,
          bio: 'Initial bio',
          languages: ['Hindi', 'English'],
          weddingExperienceYears: 8,
          operatingArea: 'Delhi NCR',
        );

        final edited = original.copyWithEditableFields(
          bio: 'Updated luxury chauffeur bio.',
          languages: const ['Hindi', 'English', 'French'],
          operatingArea: 'Jaipur & Udaipur',
          profileImageUrl: 'https://example.com/new.jpg',
        );

        // Editable fields changed:
        expect(edited.bio, equals('Updated luxury chauffeur bio.'));
        expect(edited.languages, equals(const ['Hindi', 'English', 'French']));
        expect(edited.operatingArea, equals('Jaipur & Udaipur'));
        expect(edited.profileImageUrl, equals('https://example.com/new.jpg'));

        // Invariants preserved:
        expect(edited.id, equals('d1'));
        expect(edited.fullName, equals('Rajesh Kumar'));
        expect(edited.phone, equals('+91 98111 22334'));
        expect(edited.verificationStatus, equals('UNDER_REVIEW'));
        expect(edited.rating, equals(4.95));
        expect(edited.totalTrips, equals(140));
      },
    );
  });

  group('MockDriverProfileRepository & DriverProfileController Tests', () {
    late MockDriverProfileRepository repository;
    late MockProfilePhotoService photoService;
    late DriverProfileController controller;

    setUp(() {
      repository = MockDriverProfileRepository();
      photoService = MockProfilePhotoService();
      controller = DriverProfileController(
        repository: repository,
        photoService: photoService,
        driverId: 'd1',
      );
    });

    test('initializes and loads driver d1 correctly', () async {
      await controller.loadProfile();
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.profile, isNotNull);
      expect(controller.state.profile!.id, equals('d1'));
      expect(controller.state.profile!.fullName, equals('Rajesh Kumar'));
      expect(
        controller.state.profile!.verificationStatus,
        equals('UNDER_REVIEW'),
      );
    });

    test('updateProfile updates editable fields', () async {
      await controller.loadProfile();
      final current = controller.state.profile!;

      final updated = current.copyWithEditableFields(
        bio: 'New updated Chauffeur Bio with baraat expertise.',
      );

      final ok = await controller.updateProfile(updated);
      expect(ok, isTrue);
      expect(
        controller.state.profile!.bio,
        equals('New updated Chauffeur Bio with baraat expertise.'),
      );
      expect(controller.state.successMessage, contains('updated successfully'));
    });

    test(
      'pickAndSavePhotoFromGallery and removePhoto update Chauffeur portrait',
      () async {
        await controller.loadProfile();

        final updateOk = await controller.pickAndSavePhotoFromGallery();
        expect(updateOk, isTrue);
        expect(controller.state.profile!.profileImageUrl, isNotNull);

        final removeOk = await controller.removePhoto();
        expect(removeOk, isTrue);
        expect(controller.state.profile!.profileImageUrl, isNull);
      },
    );
  });
}
