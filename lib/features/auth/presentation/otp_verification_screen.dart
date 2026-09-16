import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../domain/entities/auth_state.dart';
import 'controllers/auth_controller.dart';

/// Ceremonial OTP verification screen.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String maskedPhone;
  final String otpSessionId;
  final String? initialPhone;
  final VoidCallback? onChangeNumber;

  const OtpVerificationScreen({
    super.key,
    required this.maskedPhone,
    required this.otpSessionId,
    this.initialPhone,
    this.onChangeNumber,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  int _resendCooldown = 30;
  Timer? _countdownTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 30);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _onVerify() {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a complete 6-digit code.';
      });
      return;
    }
    setState(() => _errorMessage = null);
    ref.read(authControllerProvider.notifier).verifyOtp(
          otpSessionId: widget.otpSessionId,
          otpCode: code,
        );
  }

  void _onResend() {
    if (_resendCooldown > 0) return;
    _startCooldown();
    setState(() => _errorMessage = null);
    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      ref.read(authControllerProvider.notifier).requestOtp(
            phoneNumber: widget.initialPhone!,
          );
    }
  }

  void _onChangeNumber() {
    if (widget.onChangeNumber != null) {
      widget.onChangeNumber!();
    } else {
      ref.read(authControllerProvider.notifier).resetToPhoneInput();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthLoading;

    if (authState is AuthError && _errorMessage == null) {
      _errorMessage = authState.failure.message;
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildBrandHeader(),
                  const SizedBox(height: 28),
                  ShadiCard(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verify your number',
                          style: AppTypography.titleLarge.copyWith(
                            color: AppColors.primaryBurgundy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Enter the 6-digit code sent to ${widget.maskedPhone}',
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
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.borderLight),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.borderLight),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.primaryBurgundy,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _onVerify(),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
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
                        ShadiPrimaryButton(
                          text: 'Verify & Continue',
                          isLoading: isLoading,
                          onPressed: isLoading ? null : _onVerify,
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: _resendCooldown > 0
                              ? Text(
                                  'Resend code in ${_resendCooldown}s',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.textSecondaryLight,
                                  ),
                                )
                              : TextButton(
                                  onPressed: isLoading ? null : _onResend,
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
                            onPressed: isLoading ? null : _onChangeNumber,
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
                    ),
                  ),
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
          'Royal Chauffeur Service',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondaryLight,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
