import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../domain/entities/auth_state.dart';
import '../domain/entities/user_role.dart';
import 'controllers/auth_controller.dart';

/// Ceremonial Authentication & Onboarding screen supporting Customer, Chauffeur, and Admin portals.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  UserRole _selectedRole = UserRole.customer;
  String? _errorMessage;
  int _resendCountdown = 30;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _phoneController.text = '9876543210';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 30);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _navigateForRole(UserRole role) {
    if (!mounted) return;
    switch (role) {
      case UserRole.customer:
        context.go(RoutePaths.customer);
        break;
      case UserRole.driver:
        context.go(RoutePaths.driver);
        break;
      case UserRole.operationsAdmin:
      case UserRole.verificationAdmin:
      case UserRole.financeAdmin:
      case UserRole.superAdmin:
        context.go(RoutePaths.admin);
        break;
      case UserRole.fleetOwner:
        context.go(RoutePaths.driver);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    // Listen for authentication completion to route to appropriate home
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next is Authenticated) {
        _navigateForRole(next.session.role);
      } else if (next is AuthError) {
        setState(() {
          _errorMessage = next.failure.message;
        });
      } else if (next is OtpSent) {
        _startResendTimer();
        setState(() {
          _errorMessage = null;
        });
      }
    });

    final isLoading = authState is AuthLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Brand Logo & Header
                  _buildBrandHeader(),
                  const SizedBox(height: 24),

                  // Main Card: Phone input or OTP input
                  ShadiCard(
                    padding: const EdgeInsets.all(24),
                    child: authState is OtpSent
                        ? _buildOtpStep(authState, isLoading)
                        : _buildPhoneStep(isLoading),
                  ),
                  const SizedBox(height: 20),

                  // Dev Quick Access Bypass
                  _buildDevQuickAccess(isLoading),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primaryBurgundy, AppColors.darkBurgundy],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBurgundy.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: AppColors.champagneGold, width: 2),
          ),
          child: const Center(
            child: Icon(
              Icons.directions_car_filled_rounded,
              color: AppColors.champagneGold,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AppConstants.appName,
          style: AppTypography.displayMedium.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Royal Ceremonial Chauffeur Service',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondaryLight,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneStep(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sign In / Register',
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose your role and enter your mobile number for OTP verification.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 18),

        // Role Selector
        Text('Select Portal Role', style: AppTypography.labelMedium),
        const SizedBox(height: 8),
        _buildRoleSelector(),
        const SizedBox(height: 20),

        // Phone input
        Text('Mobile Number', style: AppTypography.labelMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              width: 76,
              child: Text(
                '🇮🇳 +91',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBurgundy,
                ),
              ),
            ),
            hintText: '10-digit mobile number',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),

        // Submit button
        ShadiPrimaryButton(
          text: 'Send Access Code (OTP)',
          isLoading: isLoading,
          onPressed: isLoading
              ? null
              : () {
                  final phone = _phoneController.text.trim();
                  if (phone.length < 10) {
                    setState(() {
                      _errorMessage = 'Please enter a 10-digit mobile number.';
                    });
                    return;
                  }
                  setState(() => _errorMessage = null);
                  ref
                      .read(authControllerProvider.notifier)
                      .requestOtp(phoneNumber: phone, role: _selectedRole);
                },
        ),
      ],
    );
  }

  Widget _buildRoleSelector() {
    final roles = [
      (UserRole.customer, 'Host / Guest', Icons.person_rounded),
      (UserRole.driver, 'Chauffeur', Icons.directions_car_rounded),
      (
        UserRole.operationsAdmin,
        'Operations',
        Icons.admin_panel_settings_rounded,
      ),
    ];

    return Row(
      children: roles.map((entry) {
        final isSelected = _selectedRole == entry.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedRole = entry.$1;
                  _errorMessage = null;
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryBurgundy : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryBurgundy
                        : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      entry.$3,
                      size: 20,
                      color: isSelected
                          ? AppColors.champagneGold
                          : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.$2,
                      style: AppTypography.labelSmall.copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimaryLight,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOtpStep(OtpSent otpState, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Verify Access Code',
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.primaryBurgundy,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () {
                ref.read(authControllerProvider.notifier).resetToPhoneInput();
              },
              tooltip: 'Change number',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Enter the 6-digit code sent to ${otpState.maskedPhone}',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.champagneGold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '💡 Dev hint: Universal code is 000000',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.primaryBurgundy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 18),

        Text('6-Digit OTP', style: AppTypography.labelMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: AppTypography.titleMedium.copyWith(
            letterSpacing: 8,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '••••••',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),

        // Verify button
        ShadiPrimaryButton(
          text: 'Verify & Enter Portal',
          isLoading: isLoading,
          onPressed: isLoading
              ? null
              : () {
                  final code = _otpController.text.trim();
                  if (code.length != 6) {
                    setState(() {
                      _errorMessage = 'Please enter a complete 6-digit code.';
                    });
                    return;
                  }
                  ref
                      .read(authControllerProvider.notifier)
                      .verifyOtp(
                        otpSessionId: otpState.otpSessionId,
                        otpCode: code,
                      );
                },
        ),
        const SizedBox(height: 12),

        // Resend countdown
        Center(
          child: _resendCountdown > 0
              ? Text(
                  'Resend code in ${_resendCountdown}s',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                )
              : TextButton(
                  onPressed: () {
                    final phone = _phoneController.text.trim();
                    ref
                        .read(authControllerProvider.notifier)
                        .requestOtp(phoneNumber: phone, role: _selectedRole);
                  },
                  child: Text(
                    'Resend Code',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.primaryBurgundy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDevQuickAccess(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bug_report_rounded,
                size: 16,
                color: AppColors.warmGold,
              ),
              const SizedBox(width: 6),
              Text(
                'Developer Quick Bypass (1-Tap)',
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('🚗 Host (Customer)'),
                backgroundColor: AppColors.secondarySurface,
                onPressed: isLoading
                    ? null
                    : () => ref
                          .read(authControllerProvider.notifier)
                          .devLoginAsRole(UserRole.customer),
              ),
              ActionChip(
                label: const Text('🎩 Chauffeur (Driver)'),
                backgroundColor: AppColors.secondarySurface,
                onPressed: isLoading
                    ? null
                    : () => ref
                          .read(authControllerProvider.notifier)
                          .devLoginAsRole(UserRole.driver),
              ),
              ActionChip(
                label: const Text('🏢 Operations Admin'),
                backgroundColor: AppColors.secondarySurface,
                onPressed: isLoading
                    ? null
                    : () => ref
                          .read(authControllerProvider.notifier)
                          .devLoginAsRole(UserRole.operationsAdmin),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
