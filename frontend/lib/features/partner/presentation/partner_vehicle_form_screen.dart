import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_primary_button.dart';
import '../../../../core/widgets/shadi_text_field.dart';
import 'controllers/partner_onboarding_controller.dart';
import '../domain/entities/partner_vehicle.dart';
import '../domain/repositories/partner_repository.dart';

/// Steps 4–5: vehicle facts + photos. Mirrors `AddVehicleDto` exactly; when
/// editing, identity fields (registration, type) are disabled because the
/// backend forbids silent identity edits.
class PartnerVehicleFormScreen extends ConsumerStatefulWidget {
  final PartnerVehicle? editing;

  const PartnerVehicleFormScreen({super.key, this.editing});

  @override
  ConsumerState<PartnerVehicleFormScreen> createState() =>
      _PartnerVehicleFormScreenState();
}

class _PartnerVehicleFormScreenState
    extends ConsumerState<PartnerVehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reg =
      TextEditingController(text: widget.editing?.registrationNumber ?? '');
  late final TextEditingController _year = TextEditingController(
      text: widget.editing == null ? '2023' : '${widget.editing!.year}');
  late final TextEditingController _color =
      TextEditingController(text: widget.editing?.color ?? '');
  late final TextEditingController _city =
      TextEditingController(text: widget.editing?.city ?? '');
  late final TextEditingController _serviceAreas =
      TextEditingController(text: widget.editing?.serviceAreas.join(', ') ?? '');
  late final TextEditingController _amenities =
      TextEditingController(text: widget.editing?.amenities.join(', ') ?? '');
  late final TextEditingController _photoUrl = TextEditingController();
  String _fuel = PartnerDocumentTypes.fuelTypes.first;
  String _transmission = PartnerDocumentTypes.transmissions.first;
  String? _vehicleTypeId;
  List<Map<String, String>> _vehicleTypes = const [];
  bool _loadingTypes = true;
  String? _typesError;
  final List<String> _photos = <String>[];

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      _photos.addAll(widget.editing!.photoUrls);
      _fuel = widget.editing!.fuelType;
      _transmission = widget.editing!.transmission;
      _vehicleTypeId = widget.editing!.vehicleTypeId;
    }
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    // Vehicle types come from the PUBLIC catalog endpoint — the same source
    // customers browse. No new backend surface is invented here.
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get<Map<String, dynamic>>(
        '/api/v1/vehicles/types',
      );
      final data = response.data?['data'] as List? ?? const [];
      setState(() {
        _vehicleTypes = data
            .whereType<Map<String, dynamic>>()
            .map((t) => {
                  'id': (t['id'] as String?) ?? '',
                  'name': (t['display_name'] as String?) ??
                      (t['displayName'] as String?) ??
                      '',
                  'seats': '${(t['seating_cap'] as num?)?.toInt() ?? (t['seatingCap'] as num?)?.toInt() ?? 4}',
                })
            .toList();
        _loadingTypes = false;
        if (_vehicleTypeId == null && _vehicleTypes.isNotEmpty) {
          _vehicleTypeId = _vehicleTypes.first['id'];
        }
      });
    } catch (_) {
      setState(() {
        _loadingTypes = false;
        _typesError = 'Could not load vehicle types. Retry by reopening.';
      });
    }
  }

  @override
  void dispose() {
    _reg.dispose();
    _year.dispose();
    _color.dispose();
    _city.dispose();
    _serviceAreas.dispose();
    _amenities.dispose();
    _photoUrl.dispose();
    super.dispose();
  }

  void _addPhoto() {
    final url = _photoUrl.text.trim();
    if (url.length < 8) return;
    setState(() {
      _photos.add(url);
      _photoUrl.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(partnerOnboardingProvider.notifier);
    if (widget.editing == null) {
      await controller.saveVehicle(
        newVehicle: PartnerVehicleDraft(
          vehicleTypeId: _vehicleTypeId ?? '',
          yearOfManufacture: int.tryParse(_year.text.trim()) ?? 2023,
          registrationNumber: _reg.text.trim().replaceAll(' ', '').toUpperCase(),
          color: _color.text.trim(),
          fuelType: _fuel,
          transmission: _transmission,
          city: _city.text.trim(),
          serviceAreas: _split(_serviceAreas.text),
          amenities: _split(_amenities.text),
          photoUrls: List<String>.from(_photos),
        ),
      );
    } else {
      await controller.saveVehicle(
        edits: PartnerVehicleEditDraft(
          yearOfManufacture: int.tryParse(_year.text.trim()),
          color: _color.text.trim(),
          fuelType: _fuel,
          transmission: _transmission,
          city: _city.text.trim(),
          serviceAreas: _split(_serviceAreas.text),
          amenities: _split(_amenities.text),
          photoUrls: List<String>.from(_photos),
        ),
      );
    }
  }

  static List<String> _split(String raw) => raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(partnerOnboardingProvider);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loadingTypes)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (_typesError != null)
              Text(_typesError!, style: AppTypography.bodySmall.copyWith(
                color: AppColors.urgentSaffron,
              )),
            DropdownButtonFormField<String>(
              initialValue: _vehicleTypeId,
              decoration: const InputDecoration(
                labelText: 'Vehicle Type * (make & model class)',
                border: OutlineInputBorder(),
              ),
              items: _vehicleTypes
                  .map((t) => DropdownMenuItem(
                        value: t['id'],
                        child: Text(
                          '${t['name']} · ${t['seats']} seats',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: widget.editing == null
                  ? (v) => setState(() => _vehicleTypeId = v)
                  : null, // identity is not editable
            ),
            const SizedBox(height: 12),
            ShadiTextField(
              label: 'Registration Number * (e.g. DL01AB1234)',
              controller: _reg,
              enabled: widget.editing == null, // identity locked on edit
              validator: (v) {
                final t = (v ?? '').replaceAll(' ', '').toUpperCase();
                if (t.isEmpty) return 'Required';
                if (!RegExp(r'^[A-Z]{2}\d{1,2}[A-Z]{1,3}\d{4}$').hasMatch(t)) {
                  return 'Indian plate format, e.g. DL01AB1234';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            ShadiTextField(
              label: 'Year of Manufacture *',
              controller: _year,
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n < 1980 || n > 2100) return '1980–2100';
                return null;
              },
            ),
            const SizedBox(height: 12),
            ShadiTextField(
              label: 'Color *',
              controller: _color,
              validator: (v) => (v == null || v.trim().length < 2 || v.trim().length > 30)
                  ? '2–30 characters'
                  : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _fuel,
                  decoration: const InputDecoration(
                      labelText: 'Fuel Type *', border: OutlineInputBorder()),
                  items: PartnerDocumentTypes.fuelTypes
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (v) => setState(() => _fuel = v ?? _fuel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _transmission,
                  decoration: const InputDecoration(
                      labelText: 'Transmission *', border: OutlineInputBorder()),
                  items: PartnerDocumentTypes.transmissions
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _transmission = v ?? _transmission),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            ShadiTextField(
              label: 'Home City *',
              controller: _city,
              validator: (v) => (v == null || v.trim().length < 2 || v.trim().length > 50)
                  ? '2–50 characters'
                  : null,
            ),
            const SizedBox(height: 12),
            ShadiTextField(
              label: 'Service Areas (comma separated)',
              controller: _serviceAreas,
            ),
            const SizedBox(height: 12),
            ShadiTextField(
              label: 'Amenities (comma separated)',
              controller: _amenities,
            ),
            const SizedBox(height: 20),

            // ---------------------------------------------------- photos
            Text('Vehicle Photos', style: AppTypography.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Add exterior and interior photo URLs (up to 12). Storage '
              'integration keeps the same backend path — the URL list is the '
              'backend contract.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: ShadiTextField(
                  label: 'Photo URL (https://…)',
                  controller: _photoUrl,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addPhoto,
                icon: const Icon(Icons.add_photo_alternate_rounded,
                    color: AppColors.primaryBurgundy),
              ),
            ]),
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in _photos)
                    InputChip(
                      label: Text(
                        Uri.tryParse(p)?.pathSegments.isEmpty ?? true
                            ? p
                            : Uri.parse(p).pathSegments.last,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted: () => setState(() => _photos.remove(p)),
                    ),
                ],
              ),
            ],
            if (state.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(state.errorMessage!,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.urgentSaffron)),
            ],
            const SizedBox(height: 24),
            ShadiPrimaryButton(
              text: widget.editing == null
                  ? 'Save Vehicle → Set Pricing'
                  : 'Save Changes → Pricing',
              onPressed: state.isSaving ? null : _save,
              isLoading: state.isSaving,
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
