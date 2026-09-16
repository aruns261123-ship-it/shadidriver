import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/widgets/shadi_secondary_button.dart';
import '../../../core/widgets/shadi_text_field.dart';
import '../domain/entities/driver_profile.dart';
import 'controllers/driver_profile_controller.dart';

/// Screen allowing chauffeurs to edit their professional bio, languages, and areas.
///
/// Invariant: Verification status and vehicle assignment are strictly read-only.
class DriverEditProfileScreen extends ConsumerStatefulWidget {
  final String driverId;

  const DriverEditProfileScreen({super.key, this.driverId = 'd1'});

  @override
  ConsumerState<DriverEditProfileScreen> createState() =>
      _DriverEditProfileScreenState();
}

class _DriverEditProfileScreenState
    extends ConsumerState<DriverEditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _bioController;
  late final TextEditingController _operatingAreaController;
  late final TextEditingController _expYearsController;
  late final TextEditingController _weddingExpController;

  final Set<String> _selectedLanguages = {};
  final List<String> _availableLanguages = [
    'Hindi',
    'English',
    'Punjabi',
    'Gujarati',
    'Rajasthani',
    'Urdu',
  ];

  bool _initialized = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _bioController = TextEditingController();
    _operatingAreaController = TextEditingController();
    _expYearsController = TextEditingController();
    _weddingExpController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _operatingAreaController.dispose();
    _expYearsController.dispose();
    _weddingExpController.dispose();
    super.dispose();
  }

  void _initFromProfile(DriverProfile profile) {
    if (!_initialized) {
      _initialized = true;
      _nameController.text = profile.fullName;
      _phoneController.text = profile.phone;
      _emailController.text = profile.email ?? '';
      _bioController.text = profile.bio;
      _operatingAreaController.text = profile.operatingArea;
      _expYearsController.text = profile.experienceYears.toString();
      _weddingExpController.text = profile.weddingExperienceYears.toString();
      _selectedLanguages.addAll(profile.languages);
    }
  }

  Future<void> _save(
    DriverProfile profile,
    DriverProfileController controller,
  ) async {
    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    final area = _operatingAreaController.text.trim();
    final exp =
        int.tryParse(_expYearsController.text.trim()) ??
        profile.experienceYears;
    final weddingExp =
        int.tryParse(_weddingExpController.text.trim()) ??
        profile.weddingExperienceYears;

    if (name.length < 2) {
      setState(() => _validationError = 'Name must be at least 2 characters.');
      return;
    }

    if (bio.length < 10) {
      setState(
        () => _validationError =
            'Please write a brief professional bio (at least 10 chars).',
      );
      return;
    }

    setState(() => _validationError = null);

    final updated = profile.copyWithEditableFields(
      fullName: name,
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null,
      bio: bio,
      languages: _selectedLanguages.toList(),
      experienceYears: exp,
      weddingExperienceYears: weddingExp,
      operatingArea: area,
    );

    final ok = await controller.updateProfile(updated);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chauffeur profile updated successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverProfileControllerProvider(widget.driverId));
    final controller = ref.read(
      driverProfileControllerProvider(widget.driverId).notifier,
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
          'Edit Chauffeur Details',
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
                      child: Text(
                        _validationError ?? state.errorMessage!,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.errorRed,
                        ),
                      ),
                    ),

                  // Read-only compliance notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.champagneGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.champagneGold),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          size: 20,
                          color: AppColors.warmGold,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Verification status (${state.profile!.verificationStatus}) and Assigned Fleet (${state.profile!.vehicleStatus}) are managed by Compliance and cannot be self-modified.',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
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
                          'Professional Credentials',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.primaryBurgundy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),

                        ShadiTextField(
                          label: 'Full Name *',
                          controller: _nameController,
                          prefixIcon: const Icon(
                            Icons.person_rounded,
                            color: AppColors.warmGold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        ShadiTextField(
                          label: 'Chauffeur Bio *',
                          hint:
                              'Describe your ceremonial driving background and hospitality experience',
                          controller: _bioController,
                          maxLines: 3,
                          prefixIcon: const Icon(
                            Icons.description_rounded,
                            color: AppColors.warmGold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        ShadiTextField(
                          label: 'Primary Operating Area / Route',
                          hint: 'e.g., Delhi NCR & Jaipur Highway',
                          controller: _operatingAreaController,
                          prefixIcon: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.warmGold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: ShadiTextField(
                                label: 'Total Experience (Yrs)',
                                controller: _expYearsController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ShadiTextField(
                                label: 'Wedding Exp (Yrs)',
                                controller: _weddingExpController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'Spoken Languages',
                          style: AppTypography.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableLanguages.map((lang) {
                            final selected = _selectedLanguages.contains(lang);
                            return FilterChip(
                              label: Text(lang),
                              selected: selected,
                              selectedColor: AppColors.champagneGold.withValues(
                                alpha: 0.3,
                              ),
                              checkmarkColor: AppColors.primaryBurgundy,
                              onSelected: (checked) {
                                setState(() {
                                  if (checked) {
                                    _selectedLanguages.add(lang);
                                  } else {
                                    _selectedLanguages.remove(lang);
                                  }
                                });
                              },
                            );
                          }).toList(),
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
                          text: state.isSaving ? 'Saving...' : 'Save Profile',
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
