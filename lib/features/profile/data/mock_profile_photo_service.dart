import '../../../../core/result/result.dart';
import '../domain/services/profile_photo_service.dart';

/// In-memory development mock for [ProfilePhotoService].
///
/// Simulates gallery selection, camera capture, and photo removal with
/// curated, royalty-free sample portrait references.
class MockProfilePhotoService implements ProfilePhotoService {
  final Map<String, String> _userPhotos = {};
  int _sampleIndex = 0;

  static const List<String> _sampleAvatars = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
  ];

  @override
  Future<Result<String>> pickFromGallery() async {
    await Future.delayed(const Duration(milliseconds: 150));
    final avatar = _sampleAvatars[_sampleIndex % _sampleAvatars.length];
    _sampleIndex++;
    return Result.success(avatar);
  }

  @override
  Future<Result<String>> captureFromCamera() async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Simulate camera capture returning a distinct sample reference
    return const Result.success(
      'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=400',
    );
  }

  @override
  Future<Result<void>> removePhoto(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _userPhotos.remove(userId);
    return const Result.success(null);
  }

  @override
  Future<Result<String>> savePhoto({
    required String userId,
    required String imageRef,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _userPhotos[userId] = imageRef;
    return Result.success(imageRef);
  }

  /// Helper to inspect stored photo reference in tests
  String? getPhotoForUser(String userId) => _userPhotos[userId];
}
