import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers/app_providers.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_logo_mark.dart';
import '../../auth/domain/entities/account_status.dart';
import '../../auth/domain/entities/user_role.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

/// App Startup & Ceremonial Splash Screen featuring branded fade-scale animation
/// and session restoration.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _textFadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _textFadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initializeApp();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Restore session asynchronously without artificial delay
    try {
      await ref
          .read(authControllerProvider.notifier)
          .restoreSession()
          .catchError((_) {});
    } catch (_) {
      // Ignored for graceful splash fallback
    }

    if (!mounted) return;

    final session = ref.read(activeSessionProvider);

    // GUEST-FIRST ENTRY: a signed-out visitor is NOT an error state. No
    // session simply means "continue as guest" — browsing the catalog is
    // open, and authentication is requested only when a protected action
    // (booking, favourites, profile…) needs a real account.
    if (!session.isAuthenticated) {
      context.go(RoutePaths.customer);
      return;
    }

    // 2. Suspended accounts go to the suspension notice screen
    if (session.accountStatus == AccountStatus.suspended) {
      context.go(RoutePaths.accountSuspended);
      return;
    }

    // 3. Incomplete profiles go to appropriate profile onboarding/edit screen
    if (session.accountStatus == AccountStatus.profileIncomplete) {
      if (session.role == UserRole.driver ||
          session.role == UserRole.fleetOwner) {
        context.go(RoutePaths.driverProfileEdit);
      } else {
        context.go(RoutePaths.customerProfileEdit);
      }
      return;
    }

    // 4. Active authenticated sessions route directly to their role portal
    switch (session.role) {
      case UserRole.driver:
      case UserRole.fleetOwner:
        context.go(RoutePaths.driver);
        break;
      case UserRole.operationsAdmin:
      case UserRole.verificationAdmin:
      case UserRole.financeAdmin:
      case UserRole.superAdmin:
        context.go(RoutePaths.admin);
        break;
      default:
        context.go(RoutePaths.customer);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBurgundy,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2C0A15), Color(0xFF19060D), Color(0xFF0F0307)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Crest Emblem
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          AppColors.primaryBurgundy,
                          AppColors.darkBurgundy,
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.champagneGold,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.champagneGold.withValues(alpha: 0.3),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: ShadiLogoMark(size: 56, light: true),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Animated App Title & Tagline
                FadeTransition(
                  opacity: _textFadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontFamily: AppTypography.ceremonialFontFamily,
                          fontFamilyFallback: AppTypography.ceremonialFontFallbacks,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: AppColors.champagneGold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppConstants.appTagline,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.softChampagne,
                          letterSpacing: 0.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      const ShadiLoadingIndicator(size: 28),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
