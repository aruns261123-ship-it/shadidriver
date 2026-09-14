import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Production-quality interactive vehicle image gallery.
/// Supports multiple images, page indicator, and graceful fallback for missing assets.
class VehicleGallery extends StatefulWidget {
  final List<String> imageUrls;
  final double height;

  const VehicleGallery({super.key, required this.imageUrls, this.height = 260});

  @override
  State<VehicleGallery> createState() => _VehicleGalleryState();
}

class _VehicleGalleryState extends State<VehicleGallery> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return _buildFallback(
        icon: Icons.directions_car_rounded,
        label: 'Photographs in Preparation',
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return _buildImageItem(widget.imageUrls[index]);
            },
          ),
          // Position Indicator Pill
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.darkBurgundy.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.champagneGold.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                '${_currentIndex + 1} / ${widget.imageUrls.length}',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.ivory,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          // Page Dots (if multiple)
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.imageUrls.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentIndex == index ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentIndex == index
                          ? AppColors.champagneGold
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageItem(String url) {
    // If it's a network URL, load with Image.network; if asset, load with Image.asset.
    // Handles graceful error fallback.
    final isNetwork = url.startsWith('http://') || url.startsWith('https://');

    return Container(
      color: AppColors.secondarySurface,
      child: isNetwork
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallback(
                icon: Icons.broken_image_rounded,
                label: 'Preview Unavailable',
              ),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.champagneGold,
                    ),
                  ),
                );
              },
            )
          : Image.asset(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallback(
                icon: Icons.directions_car_rounded,
                label: 'Ceremonial Luxury Asset',
              ),
            ),
    );
  }

  Widget _buildFallback({required IconData icon, required String label}) {
    return Container(
      height: widget.height,
      width: double.infinity,
      color: AppColors.secondarySurface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Icon(icon, size: 40, color: AppColors.warmGold),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
