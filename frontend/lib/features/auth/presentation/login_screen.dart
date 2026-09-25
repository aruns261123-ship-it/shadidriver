import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/phone_number.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../domain/entities/account_status.dart';
import '../domain/entities/auth_session.dart';
import '../domain/entities/auth_state.dart';
import '../domain/entities/user_role.dart';
import 'controllers/auth_controller.dart';

/// Ceremonial Authentication screen for ShadiDriver.
///
/// Features a login-first flow with an explicit "Create Account" (sign-up) mode:
/// name + phone + role selection for new users, phone + OTP for returning users,
/// and authoritative server/account role determination after verification.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.redirectTo});

  /// Internal location the guest was heading to when authentication became
  /// mandatory (e.g. `/customer/bookings/create/<vehicleId>`). Honoured after
  /// a successful sign-in so a pre-login vehicle selection is never lost.
  final String? redirectTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();

  /// Whether the screen is in "Create account" mode instead of "Sign in".
  bool _isSignUpMode = false;

  /// Role chosen during sign-up: customer (host) or chauffeur (driver).
  UserRole _signUpRole = UserRole.customer;

  String? _errorMessage;
  int _resendCountdown = 30;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
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

  void _routeAuthenticatedSession(AuthSession session) {
    if (!mounted) return;

    if (session.accountStatus == AccountStatus.suspended) {
      context.go(RoutePaths.accountSuspended);
      return;
    }

    if (session.accountStatus == AccountStatus.profileIncomplete) {
      if (session.role == UserRole.driver ||
          session.role == UserRole.fleetOwner) {
        context.go(RoutePaths.driverProfileEdit);
      } else {
        context.go(RoutePaths.customerProfileEdit);
      }
      return;
    }

    // Return the guest to the transaction that sent them here. Restricted to
    // internal customer paths so the parameter can never redirect a freshly
    // authenticated user off-site.
    final resume = _safeInternalRedirect(widget.redirectTo);
    if (resume != null) {
      context.go(resume);
      return;
    }

    switch (session.role) {
      case UserRole.customer:
        context.go(RoutePaths.customer);
        break;
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
    }
  }

  /// Only accepts absolute in-app customer paths; anything else is ignored.
  static String? _safeInternalRedirect(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final decoded = Uri.decodeComponent(raw);
    if (!decoded.startsWith('/customer/')) return null;
    if (decoded.startsWith('/customer/profile/edit')) return null;
    if (decoded.contains('//')) return null;
    return decoded;
  }

  void _onRequestOtp() {
    final phone = _phoneController.text.trim();
    if (!PhoneNumber.isValidIndian(phone)) {
      setState(() {
        _errorMessage = 'Enter a valid mobile number.';
      });
      _phoneFocusNode.requestFocus();
      return;
    }
    setState(() => _errorMessage = null);
    ref.read(authControllerProvider.notifier).requestOtp(phoneNumber: phone);
  }

  void _onSignUp() {
    // Client-side validation mirrors the backend DTO (authoritative): name at
    // least 2 characters and a valid Indian mobile number.
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() {
        _errorMessage = 'Name must be at least 2 characters.';
      });
      _nameFocusNode.requestFocus();
      return;
    }
    final phone = _phoneController.text.trim();
    if (!PhoneNumber.isValidIndian(phone)) {
      setState(() {
        _errorMessage = 'Enter a valid mobile number.';
      });
      _phoneFocusNode.requestFocus();
      return;
    }
    setState(() => _errorMessage = null);
    ref
        .read(authControllerProvider.notifier)
        .signUp(phoneNumber: phone, displayName: name, role: _signUpRole);
  }

  void _onVerifyOtp(String otpSessionId) {
    HapticFeedback.mediumImpact();
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a complete 6-digit code.';
      });
      return;
    }
    setState(() => _errorMessage = null);
    ref
        .read(authControllerProvider.notifier)
        .verifyOtp(otpSessionId: otpSessionId, otpCode: code);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthLoading;

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next is Authenticated) {
        _routeAuthenticatedSession(next.session);
      } else if (next is AuthError) {
        setState(() {
          _errorMessage = next.failure.message;
        });
      } else if (next is OtpSent) {
        _startResendTimer();
        setState(() {
          _errorMessage = null;
          _otpController.clear();
        });
      }
    });

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
                  _buildBrandHeader(),
                  const SizedBox(height: 28),
                  ShadiCard(
                    padding: const EdgeInsets.all(28),
                    child: authState is OtpSent
                        ? _buildOtpStep(authState, isLoading)
                        : _isSignUpMode
                        ? _buildSignUpStep(isLoading)
                        : _buildPhoneStep(isLoading),
                  ),
                  const SizedBox(height: 24),
                  _buildTermsNotice(),
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
          width: 76,
          height: 76,
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
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: AppColors.champagneGold, width: 2),
          ),
          child: const Center(
            child: Icon(
              Icons.directions_car_filled_rounded,
              color: AppColors.champagneGold,
              size: 38,
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
          'Royal Chauffeur Service',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondaryLight,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.borderLight.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildModeToggleSegment('Sign In', !_isSignUpMode)),
          Expanded(
            child: _buildModeToggleSegment('Create Account', _isSignUpMode),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggleSegment(String label, bool selected) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (selected) return;
        setState(() {
          _isSignUpMode = !_isSignUpMode;
          _errorMessage = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: selected
                  ? AppColors.primaryBurgundy
                  : AppColors.textSecondaryLight,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: _phoneController,
      focusNode: _phoneFocusNode,
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
        hintText: 'Enter your mobile number',
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondaryLight.withValues(alpha: 0.7),
        ),
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.primaryBurgundy,
            width: 1.5,
          ),
        ),
      ),
      onSubmitted: (_) => _isSignUpMode ? _onSignUp() : _onRequestOtp(),
    );
  }

  Widget _buildErrorSection() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _buildErrorAlert(_errorMessage!),
    );
  }

  Widget _buildPhoneStep(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to ShadiDriver',
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sign in or create your account',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondaryLight,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 20),
        _buildModeToggle(),
        const SizedBox(height: 20),
        Text(
          'Mobile number',
          style: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        _buildPhoneField(),
        _buildErrorSection(),
        const SizedBox(height: 24),
        ShadiPrimaryButton(
          text: 'Continue',
          isLoading: isLoading,
          onPressed: isLoading ? null : _onRequestOtp,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            "We'll send a secure verification code to verify your number.",
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpStep(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create your account',
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Join ShadiDriver in under a minute',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondaryLight,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 20),
        _buildModeToggle(),
        const SizedBox(height: 20),
        Text(
          'Full name',
          style: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.person_outline_rounded,
              size: 20,
              color: AppColors.textSecondaryLight,
            ),
            hintText: 'Enter your full name',
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondaryLight.withValues(alpha: 0.7),
            ),
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primaryBurgundy,
                width: 1.5,
              ),
            ),
          ),
          onSubmitted: (_) => _phoneFocusNode.requestFocus(),
        ),
        const SizedBox(height: 16),
        Text(
          'Mobile number',
          style: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        _buildPhoneField(),
        const SizedBox(height: 16),
        Text(
          'I am joining as',
          style: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildRoleOption(
                icon: Icons.celebration_outlined,
                label: 'Customer',
                subtitle: 'Book luxury rides',
                selected: _signUpRole == UserRole.customer,
                onTap: () => setState(() => _signUpRole = UserRole.customer),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildRoleOption(
                icon: Icons.directions_car_filled_outlined,
                label: 'Chauffeur',
                subtitle: 'Drive & earn',
                selected: _signUpRole == UserRole.driver,
                onTap: () => setState(() => _signUpRole = UserRole.driver),
              ),
            ),
          ],
        ),
        _buildErrorSection(),
        const SizedBox(height: 24),
        ShadiPrimaryButton(
          text: 'Create Account',
          isLoading: isLoading,
          onPressed: isLoading ? null : _onSignUp,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            "We'll send a secure verification code to verify your number.",
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryBurgundy.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primaryBurgundy : AppColors.borderLight,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected
                  ? AppColors.primaryBurgundy
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelMedium.copyWith(
                      color: selected
                          ? AppColors.primaryBurgundy
                          : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondaryLight,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
              'Verify your number',
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
              tooltip: 'Change mobile number',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Enter the 6-digit code sent to ${otpState.maskedPhone}',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondaryLight,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Verification Code',
          style: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: AppTypography.titleLarge.copyWith(
            letterSpacing: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryBurgundy,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '• • • • • •',
            hintStyle: AppTypography.titleLarge.copyWith(
              letterSpacing: 8,
              color: AppColors.borderLight,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primaryBurgundy,
                width: 1.5,
              ),
            ),
          ),
          onChanged: (val) {
            if (val.isNotEmpty) {
              HapticFeedback.selectionClick();
            }
            if (val.length == 6) {
              _onVerifyOtp(otpState.otpSessionId);
            }
          },
          onSubmitted: (_) => _onVerifyOtp(otpState.otpSessionId),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          _buildErrorAlert(_errorMessage!),
        ],
        const SizedBox(height: 24),
        ShadiPrimaryButton(
          text: 'Verify & Continue',
          isLoading: isLoading,
          onPressed: isLoading
              ? null
              : () => _onVerifyOtp(otpState.otpSessionId),
        ),
        const SizedBox(height: 16),
        Center(
          child: _resendCountdown > 0
              ? Text(
                  'Resend code in ${_resendCountdown}s',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                )
              : TextButton(
                  onPressed: isLoading ? null : _onRequestOtp,
                  child: Text(
                    'Resend code',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.primaryBurgundy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: () {
              ref.read(authControllerProvider.notifier).resetToPhoneInput();
            },
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 16,
              color: AppColors.textSecondaryLight,
            ),
            label: Text(
              'Change mobile number',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorAlert(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade700,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.labelSmall.copyWith(
                color: Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsNotice() {
    return Text(
      'By continuing, you agree to ShadiDriver\'s Terms of Service & Privacy Policy.',
      style: AppTypography.bodySmall.copyWith(
        color: AppColors.textSecondaryLight.withValues(alpha: 0.8),
        fontSize: 11,
      ),
      textAlign: TextAlign.center,
    );
  }
}
