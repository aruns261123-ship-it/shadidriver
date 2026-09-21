import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Luxury circular avatar picker displaying user photo or ceremonial monogram initials,
/// with camera badge and bottom-sheet options for gallery, camera, and removal.
class ShadiAvatarPicker extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double size;
  final bool isSaving;
  final VoidCallback? onPickFromGallery;
  final VoidCallback? onCaptureFromCamera;
  final VoidCallback? onRemovePhoto;

  const ShadiAvatarPicker({
    super.key,
    required this.photoUrl,
    required this.name,
    this.size = 96.0,
    this.isSaving = false,
    this.onPickFromGallery,
    this.onCaptureFromCamera,
    this.onRemovePhoto,
  });

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'SD';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Profile Photo',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.primaryBurgundy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.champagneGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: AppColors.warmGold,
                    ),
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onPickFromGallery?.call();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.champagneGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.warmGold,
                    ),
                  ),
                  title: const Text('Capture with Camera'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onCaptureFromCamera?.call();
                  },
                ),
                if (photoUrl != null && photoUrl!.trim().isNotEmpty) ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.errorRed,
                      ),
                    ),
                    title: Text(
                      'Remove Photo',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.errorRed,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onRemovePhoto?.call();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: isSaving ? null : () => _showOptions(context),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryBurgundy,
                border: Border.all(color: AppColors.champagneGold, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBurgundy.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: isSaving
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.champagneGold,
                            ),
                          ),
                        ),
                      )
                    : (hasPhoto
                          ? Image.network(
                              photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _buildInitials(),
                            )
                          : _buildInitials()),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: isSaving ? null : () => _showOptions(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.champagneGold,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 16,
                  color: AppColors.primaryBurgundy,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitials() {
    return Center(
      child: Text(
        _initials,
        style: TextStyle(
          fontFamily: AppTypography.ceremonialFontFamily,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: AppColors.champagneGold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
