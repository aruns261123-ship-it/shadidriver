import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../core/widgets/shadi_primary_button.dart';
import '../../../../core/widgets/shadi_text_field.dart';
import 'controllers/partner_onboarding_controller.dart';
import '../domain/entities/partner_profile.dart';
import '../domain/repositories/partner_repository.dart';

/// Steps 1–3 of onboarding: professional + legal details.
///
/// Flutter validates for UX only (lengths, formats); the backend DTO remains
/// the authority — server errors surface verbatim in [PartnerOnboardingState].
class PartnerProfileFormScreen extends ConsumerStatefulWidget {
  final PartnerProfile? initial;

  const PartnerProfileFormScreen({super.key, this.initial});

  @override
  ConsumerState<PartnerProfileFormScreen> createState() =>
      _PartnerProfileFormScreenState();
}

class _PartnerProfileFormScreenState
    extends ConsumerState<PartnerProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _company =
      TextEditingController(text: widget.initial?.companyName ?? '');
  late final TextEditingController _contact =
      TextEditingController(text: widget.initial?.contactName ?? '');
  late final TextEditingController _city =
      TextEditingController(text: widget.initial?.baseCity ?? '');
  late final TextEditingController _experience = TextEditingController(
      text: widget.initial == null ? '' : '${widget.initial!.experienceYears}');
  late final TextEditingController _license =
      TextEditingController(text: '');
  late final TextEditingController _emergencyName = TextEditingController();
  late final TextEditingController _emergencyPhone = TextEditingController();
  late final TextEditingController _tradeLicense = TextEditingController();
  late final TextEditingController _pan = TextEditingController();
  late final TextEditingController _gstin = TextEditingController();
  String _languages = 'Hindi, English';

  @override
  void dispose() {
    _company.dispose();
    _contact.dispose();
    _city.dispose();
    _experience.dispose();
    _license.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    _tradeLicense.dispose();
    _pan.dispose();
    _gstin.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(partnerOnboardingProvider.notifier);
    unawaited(controller.saveProfile(PartnerRegistrationDraft(
      companyName: _company.text.trim(),
      contactName: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
      baseCity: _city.text.trim(),
      serviceCities: [_city.text.trim()],
      languagesSpoken: _languages
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      experienceYears: int.tryParse(_experience.text.trim()),
      licenseNumber: _license.text.trim().isEmpty ? null : _license.text.trim(),
      emergencyContactName: _emergencyName.text.trim().isEmpty
          ? null
          : _emergencyName.text.trim(),
      emergencyContactPhone: _emergencyPhone.text.trim().isEmpty
          ? null
          : _emergencyPhone.text.trim(),
      tradeLicenseNumber: _tradeLicense.text.trim().isEmpty
          ? null
          : _tradeLicense.text.trim(),
      panNumber: _pan.text.trim().isEmpty ? null : _pan.text.trim(),
      gstin: _gstin.text.trim().isEmpty ? null : _gstin.text.trim(),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(partnerOnboardingProvider);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Tell us about your business',
              style: AppTypography.titleMedium),
          const SizedBox(height: 4),
          Text(
            'These details go to ShadiDriver operations for verification. '
            'Customers never see them.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 20),
          ShadiTextField(
            label: 'Company / Business Name *',
            controller: _company,
            validator: (v) =>
                (v == null || v.trim().length < 2 || v.trim().length > 200)
                    ? '2–200 characters'
                    : null,
          ),
          const SizedBox(height: 12),
          ShadiTextField(
            label: 'Contact Person',
            controller: _contact,
            validator: (v) =>
                v != null && v.trim().isNotEmpty && v.trim().length < 2
                    ? 'At least 2 characters'
                    : null,
          ),
          const SizedBox(height: 12),
          ShadiTextField(
            label: 'Base City *',
            controller: _city,
            validator: (v) =>
                (v == null || v.trim().length < 2 || v.trim().length > 50)
                    ? '2–50 characters'
                    : null,
          ),
          const SizedBox(height: 12),
          ShadiTextField(
            label: 'Languages Spoken (comma separated)',
            controller: TextEditingController(text: _languages),
            onChanged: (v) => _languages = v,
          ),
          const SizedBox(height: 12),
          ShadiTextField(
            label: 'Years of Experience',
            controller: _experience,
            keyboardType: TextInputType.number,
            validator: (v) {
              final n = int.tryParse(v?.trim() ?? '');
              if (v!.trim().isEmpty) return null;
              if (n == null || n < 0 || n > 60) return '0–60';
              return null;
            },
          ),
          const SizedBox(height: 12),
          ShadiTextField(
            label: 'Driving Licence Number',
            controller: _license,
            validator: (v) =>
                v != null && v.trim().isNotEmpty && (v.trim().length < 5 || v.trim().length > 50)
                    ? '5–50 characters'
                    : null,
          ),
          const SizedBox(height: 20),
          Text('Emergency contact', style: AppTypography.titleSmall),
          const SizedBox(height: 8),
          ShadiTextField(
            label: 'Emergency Contact Name',
            controller: _emergencyName,
          ),
          const SizedBox(height: 12),
          ShadiTextField(
            label: 'Emergency Contact Phone (+91…)',
            controller: _emergencyPhone,
            keyboardType: TextInputType.phone,
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return null;
              return PhoneNumber.isValidIndian(t)
                  ? null
                  : 'Use a valid Indian mobile number';
            },
          ),
          const SizedBox(height: 20),
          Text('Legal & tax (optional, speeds up verification)',
              style: AppTypography.titleSmall),
          const SizedBox(height: 8),
          ShadiTextField(
            label: 'Trade Licence Number',
            controller: _tradeLicense,
          ),
          const SizedBox(height: 12),
          ShadiTextField(
            label: 'PAN',
            controller: _pan,
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return null;
              return RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(t)
                  ? null
                  : 'Format: AABCU9603R';
            },
          ),
          const SizedBox(height: 12),
          ShadiTextField(
            label: 'GSTIN',
            controller: _gstin,
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return null;
              return RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]{3}$')
                      .hasMatch(t)
                  ? null
                  : '15-character GSTIN';
            },
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.urgentSaffron),
            ),
          ],
          const SizedBox(height: 24),
          ShadiPrimaryButton(
            text: widget.initial == null
                ? 'Create Partner Profile'
                : 'Save Changes',
            onPressed: state.isSaving ? null : _save,
            isLoading: state.isSaving,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
