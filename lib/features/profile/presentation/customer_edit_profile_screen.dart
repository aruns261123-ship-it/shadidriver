import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/widgets/shadi_secondary_button.dart';
import '../../../core/widgets/shadi_text_field.dart';
import '../domain/entities/customer_profile.dart';
import 'controllers/customer_profile_controller.dart';

/// Screen allowing customers to edit their ceremonial profile details.
class CustomerEditProfileScreen extends ConsumerStatefulWidget {
  const CustomerEditProfileScreen({super.key});

  @override
  ConsumerState<CustomerEditProfileScreen> createState() =>
      _CustomerEditProfileScreenState();
}

class _CustomerEditProfileScreenState
    extends ConsumerState<CustomerEditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _emergencyNameController;
  late final TextEditingController _emergencyPhoneController;
  late final TextEditingController _preferencesController;

  String _selectedCity = 'Delhi NCR';
  String _selectedLanguage = 'English';
  bool _initialized = false;
  String? _validationError;

  final List<String> _cities = ['Delhi NCR', 'Jaipur', 'Udaipur', 'Mumbai'];
  final List<String> _languages = ['English', 'Hindi', 'Punjabi', 'Gujarati'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _emergencyNameController = TextEditingController();
    _emergencyPhoneController = TextEditingController();
    _preferencesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _preferencesController.dispose();
    super.dispose();
  }

  void _initFromProfile(CustomerProfile profile) {
    if (!_initialized) {
      _initialized = true;
      _nameController.text = profile.fullName;
      _phoneController.text = profile.phone;
      _emailController.text = profile.email ?? '';
      _emergencyNameController.text = profile.emergencyContactName ?? '';
      _emergencyPhoneController.text = profile.emergencyContactPhone ?? '';
      _preferencesController.text = profile.weddingPreferences ?? '';
      if (_cities.contains(profile.city)) {
        _selectedCity = profile.city;
      }
      if (profile.preferredLanguage != null &&
          _languages.contains(profile.preferredLanguage)) {
        _selectedLanguage = profile.preferredLanguage!;
      }
    }
  }

  Future<void> _save(
    CustomerProfile profile,
    CustomerProfileController controller,
  ) async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (name.length < 2) {
      setState(
        () => _validationError = 'Full name must be at least 2 characters.',
      );
      return;
    }

    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      setState(
        () => _validationError = 'Please enter a valid 10-digit mobile number.',
      );
      return;
    }

    if (email.isNotEmpty &&
        !RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(email)) {
      setState(() => _validationError = 'Please enter a valid email address.');
      return;
    }

    setState(() => _validationError = null);

    final updated = profile.copyWith(
      fullName: name,
      phone: phone,
      email: email.isNotEmpty ? email : null,
      city: _selectedCity,
      preferredLanguage: _selectedLanguage,
      emergencyContactName: _emergencyNameController.text.trim().isNotEmpty
          ? _emergencyNameController.text.trim()
          : null,
      emergencyContactPhone: _emergencyPhoneController.text.trim().isNotEmpty
          ? _emergencyPhoneController.text.trim()
          : null,
      weddingPreferences: _preferencesController.text.trim().isNotEmpty
          ? _preferencesController.text.trim()
          : null,
    );

    final ok = await controller.updateProfile(updated);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    final state = ref.watch(customerProfileControllerProvider(session.userId));
    final controller = ref.read(
      customerProfileControllerProvider(session.userId).notifier,
    );

    if (state.profile != null) {
      _initFromProfile(state.profile!);
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.primaryBurgundy,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Edit Profile',
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: state.isLoading || state.profile == null
          ? const Center(child: ShadiLoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_validationError != null || state.errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.errorRed),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.errorRed,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _validationError ?? state.errorMessage!,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.errorRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ShadiCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Information',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.primaryBurgundy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ShadiTextField(
                          label: 'Full Name *',
                          hint: 'e.g., Aditya Singhal',
                          controller: _nameController,
                          prefixIcon: const Icon(
                            Icons.person_rounded,
                            color: AppColors.warmGold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ShadiTextField(
                          label: 'Mobile Number *',
                          hint: 'e.g., +91 98765 43210',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          prefixIcon: const Icon(
                            Icons.phone_rounded,
                            color: AppColors.warmGold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ShadiTextField(
                          label: 'Email Address (Optional)',
                          hint: 'e.g., aditya@example.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(
                            Icons.email_rounded,
                            color: AppColors.warmGold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Primary Event City *',
                          style: AppTypography.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCity,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.borderLight,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.location_city_rounded,
                              color: AppColors.warmGold,
                            ),
                          ),
                          items: _cities
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedCity = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Preferred Language',
                          style: AppTypography.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedLanguage,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.borderLight,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.language_rounded,
                              color: AppColors.warmGold,
                            ),
                          ),
                          items: _languages
                              .map(
                                (l) =>
                                    DropdownMenuItem(value: l, child: Text(l)),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedLanguage = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ShadiCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ceremonial & Emergency Preferences',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.primaryBurgundy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ShadiTextField(
                          label: 'Emergency Contact Name',
                          hint: 'e.g., Vikram Malhotra (Brother)',
                          controller: _emergencyNameController,
                          prefixIcon: const Icon(
                            Icons.contact_phone_rounded,
                            color: AppColors.warmGold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ShadiTextField(
                          label: 'Emergency Mobile Number',
                          hint: 'e.g., +91 98100 12345',
                          controller: _emergencyPhoneController,
                          keyboardType: TextInputType.phone,
                          prefixIcon: const Icon(
                            Icons.phone_in_talk_rounded,
                            color: AppColors.warmGold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ShadiTextField(
                          label: 'Wedding Chauffeur Preferences (Optional)',
                          hint:
                              'e.g., Royal Safa attire, strict punctuality, classical music',
                          controller: _preferencesController,
                          maxLines: 2,
                          prefixIcon: const Icon(
                            Icons.celebration_rounded,
                            color: AppColors.warmGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ShadiSecondaryButton(
                          text: 'Cancel',
                          onPressed: () => context.pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ShadiPrimaryButton(
                          text: state.isSaving ? 'Saving...' : 'Save Changes',
                          onPressed: state.isSaving
                              ? null
                              : () => _save(state.profile!, controller),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
