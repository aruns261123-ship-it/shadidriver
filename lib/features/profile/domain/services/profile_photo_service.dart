import '../../../../core/result/result.dart';

/// Abstract contract for profile photo selection, capture, and removal.
///
/// Decouples client presentation from image storage vendors (S3, Cloudinary, etc.)
/// and device hardware APIs.
abstract interface class ProfilePhotoService {
  /// Selects an image from device gallery, returning an opaque reference/URI.
  Future<Result<String>> pickFromGallery();

  /// Captures an image with device camera, returning an opaque reference/URI.
  Future<Result<String>> captureFromCamera();

  /// Removes the existing profile photo for [userId].
  Future<Result<void>> removePhoto(String userId);

  /// Uploads or persists a selected [imageRef] for [userId], returning the canonical photo URL.
  Future<Result<String>> savePhoto({
    required String userId,
    required String imageRef,
  });
}
