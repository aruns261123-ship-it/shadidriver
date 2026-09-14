import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';

/// App Startup & Splash screen displaying ceremonial branding and routing into target shell.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    // Simulated splash delay for initialization verification
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      context.go(RoutePaths.customer);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBurgundy,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryBurgundy,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.champagneGold, width: 2),
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  size: 40,
                  color: AppColors.champagneGold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppConstants.appName,
                style: AppTypography.displayMedium.copyWith(
                  color: AppColors.champagneGold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppConstants.appTagline,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.softChampagne,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              const ShadiLoadingIndicator(size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
