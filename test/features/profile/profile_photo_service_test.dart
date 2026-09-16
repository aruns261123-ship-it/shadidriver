import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/profile/data/mock_profile_photo_service.dart';

void main() {
  group('MockProfilePhotoService Tests', () {
    late MockProfilePhotoService photoService;

    setUp(() {
      photoService = MockProfilePhotoService();
    });

    test('pickFromGallery returns valid image URL', () async {
      final res = await photoService.pickFromGallery();
      expect(res.isSuccess, isTrue);
      final url = res.dataOrNull!;
      expect(url, startsWith('https://'));
    });

    test('captureFromCamera returns valid image URL', () async {
      final res = await photoService.captureFromCamera();
      expect(res.isSuccess, isTrue);
      final url = res.dataOrNull!;
      expect(url, startsWith('https://'));
    });

    test('savePhoto and removePhoto updates in-memory map', () async {
      final saveRes = await photoService.savePhoto(
        userId: 'test_user_1',
        imageRef: 'https://images.unsplash.com/sample.jpg',
      );
      expect(saveRes.isSuccess, isTrue);
      expect(
        photoService.getPhotoForUser('test_user_1'),
        equals('https://images.unsplash.com/sample.jpg'),
      );

      final removeRes = await photoService.removePhoto('test_user_1');
      expect(removeRes.isSuccess, isTrue);
      expect(photoService.getPhotoForUser('test_user_1'), isNull);
    });
  });
}
