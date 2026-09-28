import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_card.dart';
import '../../../../core/widgets/shadi_primary_button.dart';
import '../../../../core/widgets/shadi_status_badge.dart';
import 'controllers/partner_onboarding_controller.dart';
import '../domain/entities/partner_vehicle.dart';
import '../domain/repositories/partner_repository.dart';

/// Step 5: per-vehicle tariff. The form mirrors `SubmitVehiclePricingDto`
/// (amounts entered in RUPEES, converted to PAISE at the edge — paise is the
/// wire contract). Server owns review state: every submission starts
/// PENDING_REVIEW and an approved version stays live until superseded.
class PartnerVehiclePricingScreen extends ConsumerStatefulWidget {
  final PartnerVehicle? vehicle;
  final List<VehicleTariff> existing;

  const PartnerVehiclePricingScreen({
    super.key,
    required this.vehicle,
    required this.existing,
  });

  @override
  ConsumerState<PartnerVehiclePricingScreen> createState() =>
      _PartnerVehiclePricingScreenState();
}

class _PartnerVehiclePricingScreenState
    extends ConsumerState<PartnerVehiclePricingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _km = TextEditingController(text: '45');
  final _local = TextEditingController();
  final _perKm = TextEditingController();
  final _hourly = TextEditingController();
  final _extraHour = TextEditingController();
  final _fullDay = TextEditingController();
  final _overnight = TextEditingController();
  final _outstationDay = TextEditingController();
  final _outstationKm = TextEditingController();

  /// Set when a submitted tariff contradicts itself; cleared on the next edit.
  String? _consistencyMessage;

  @override
  void dispose() {
    _km.dispose();
    _local.dispose();
    _perKm.dispose();
    _hourly.dispose();
    _extraHour.dispose();
    _fullDay.dispose();
    _overnight.dispose();
    _outstationDay.dispose();
    _outstationKm.dispose();
    super.dispose();
  }

  int? _rupeesToPaise(String raw) {
    final v = raw.trim().replaceAll(',', '');
    if (v.isEmpty) return null;
    final n = int.tryParse(v);
    return n == null ? null : n * 100;
  }

  /// Cross-field arithmetic the server enforces in `assertSaneTariff`.
  ///
  /// Per-field minimums cannot catch a tariff whose components contradict one
  /// another (a ₹500/day car with a ₹4,500 local package), so the server
  /// rejects it. Mirroring the rules here turns a failed round-trip into
  /// immediate guidance — the wording matches the backend deliberately.
  String? _consistencyError() {
    final local = _rupeesToPaise(_local.text);
    final perKm = _rupeesToPaise(_perKm.text);
    final hourly = _rupeesToPaise(_hourly.text);
    final fullDay = _rupeesToPaise(_fullDay.text);
    final overnight = _rupeesToPaise(_overnight.text);
    final outstationKm = _rupeesToPaise(_outstationKm.text);

    if (fullDay != null && local != null && fullDay < local) {
      return 'Full day (₹${fullDay ~/ 100}) cannot be lower than the local '
          'package (₹${local ~/ 100}).';
    }
    if (fullDay != null && hourly != null && fullDay < hourly * 4) {
      return 'Full day (₹${fullDay ~/ 100}) cannot be lower than 4 hourly '
          'rates (₹${hourly * 4 ~/ 100}).';
    }
    if (overnight != null && fullDay != null && overnight < fullDay) {
      return 'Overnight (₹${overnight ~/ 100}) cannot be lower than the '
          'full-day rate (₹${fullDay ~/ 100}).';
    }
    if (outstationKm != null && perKm != null && outstationKm < perKm) {
      return 'Outstation per-km (₹${outstationKm ~/ 100}) cannot be lower than '
          'the local per-km rate (₹${perKm ~/ 100}).';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Contradictory components are refused before the round-trip; the server
    // re-checks the same rules authoritatively.
    final inconsistent = _consistencyError();
    if (inconsistent != null) {
      setState(() => _consistencyMessage = inconsistent);
      return;
    }
    setState(() => _consistencyMessage = null);
    final controller = ref.read(partnerOnboardingProvider.notifier);
    unawaited(controller.submitTariff(VehicleTariffDraft(
      localIncludedKm: int.parse(_km.text.trim()),
      localAmountPaise: _rupeesToPaise(_local.text)!,
      perKmPaise: _rupeesToPaise(_perKm.text)!,
      hourlyPaise: _rupeesToPaise(_hourly.text),
      extraHourPaise: _rupeesToPaise(_extraHour.text),
      fullDayPaise: _rupeesToPaise(_fullDay.text),
      overnightPaise: _rupeesToPaise(_overnight.text),
      outstationPerDayPaise: _rupeesToPaise(_outstationDay.text),
      outstationPerKmPaise: _rupeesToPaise(_outstationKm.text),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(partnerOnboardingProvider);
    final vehicle = widget.vehicle;
    if (vehicle == null) {
      return const Center(child: Text('Save a vehicle first.'));
    }
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            vehicle.displayName ?? vehicle.fleetCode,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.primaryBurgundy,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            vehicle.maskedRegistration,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 16),

          // ------------------------------------------------ existing versions
          if (widget.existing.isNotEmpty) ...[
            Text('Submitted tariffs', style: AppTypography.titleSmall),
            const SizedBox(height: 8),
            for (final t in widget.existing)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ShadiCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Version ${t.version} · ${t.summary}',
                                style: AppTypography.bodyMedium),
                            if (t.decisionReason != null)
                              Text(t.decisionReason!,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondaryLight,
                                  )),
                          ],
                        ),
                      ),
                      ShadiStatusBadge(status: t.status.wire),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text('Submit a new version', style: AppTypography.titleSmall),
            const SizedBox(height: 4),
            Text(
              'An approved tariff keeps serving customers until a NEW version '
              'is approved. Editing never re-prices an existing booking.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 12),
          ],

          Text('Local package', style: AppTypography.titleSmall),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _km,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Included km *',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _clearConsistency(),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  return (n == null || n < 5 || n > 500) ? '5–500 km' : null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _local,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Up to X km (₹) *',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _clearConsistency(),
                validator: (v) {
                  final p = _rupeesToPaise(v ?? '');
                  return (p == null || p < 10000) ? 'Min ₹100' : null;
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _perKm,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Additional km (₹/km) *',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _clearConsistency(),
            validator: (v) {
              final p = _rupeesToPaise(v ?? '');
              return (p == null || p < 5) ? 'Min ₹5/km' : null;
            },
          ),
          const SizedBox(height: 16),
          Text('Time & day (optional)', style: AppTypography.titleSmall),
          const SizedBox(height: 8),
          _rupeesField('Hourly (₹/hr)', _hourly, minRs: 50),
          const SizedBox(height: 12),
          _rupeesField('Extra hour (₹/hr)', _extraHour, minRs: 50),
          const SizedBox(height: 12),
          _rupeesField('Full Day (₹, 8h/80km)', _fullDay, minRs: 1000),
          const SizedBox(height: 12),
          _rupeesField('Overnight (₹)', _overnight, minRs: 1000),
          const SizedBox(height: 16),
          Text('Outstation (optional)', style: AppTypography.titleSmall),
          const SizedBox(height: 8),
          _rupeesField('Outstation / Day (₹)', _outstationDay, minRs: 1000),
          const SizedBox(height: 12),
          _rupeesField('Outstation (₹/km)', _outstationKm, minRs: 5),
          if (_consistencyMessage != null) ...[
            const SizedBox(height: 16),
            Text(_consistencyMessage!,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.urgentSaffron)),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(state.errorMessage!,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.urgentSaffron)),
          ],
          const SizedBox(height: 24),
          ShadiPrimaryButton(
            text: 'Submit Tariff for Review',
            onPressed: state.isSaving ? null : _submit,
            isLoading: state.isSaving,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Any edit invalidates a previous contradiction warning.
  void _clearConsistency() {
    if (_consistencyMessage != null) {
      setState(() => _consistencyMessage = null);
    }
  }

  Widget _rupeesField(String label, TextEditingController controller,
      {required int minRs}) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      onChanged: (_) => _clearConsistency(),
      validator: (v) {
        final p = _rupeesToPaise(v ?? '');
        if (p == null) return null; // optional
        return p >= minRs * 100 ? null : 'Min ₹$minRs';
      },
    );
  }
}
