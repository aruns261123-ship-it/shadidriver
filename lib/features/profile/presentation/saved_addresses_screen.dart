import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_empty_state.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/widgets/shadi_text_field.dart';
import '../domain/entities/saved_address.dart';
import 'controllers/saved_addresses_controller.dart';

/// Screen managing customer's saved ceremonial addresses (Home, Wedding Venues, Relatives).
class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  IconData _iconForType(AddressType type) {
    return switch (type) {
      AddressType.home => Icons.home_rounded,
      AddressType.work => Icons.business_rounded,
      AddressType.weddingVenue => Icons.celebration_rounded,
      AddressType.family => Icons.family_restroom_rounded,
      AddressType.other => Icons.place_rounded,
    };
  }

  void _showAddressDialog(
    BuildContext context,
    SavedAddressesController controller,
    String customerId, {
    SavedAddress? existing,
  }) {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final landmarkCtrl = TextEditingController(text: existing?.landmark ?? '');
    var selectedType = existing?.type ?? AddressType.weddingVenue;
    var isDefault = existing?.isDefault ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existing == null
                              ? 'Add Saved Address'
                              : 'Edit Saved Address',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.primaryBurgundy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    ShadiTextField(
                      label: 'Address Label *',
                      hint: 'e.g., Delhi Residence or Imperial Ballroom',
                      controller: labelCtrl,
                    ),
                    const SizedBox(height: 12),

                    ShadiTextField(
                      label: 'Full Address *',
                      hint:
                          'e.g., The Oberoi, Dr Zakir Hussain Marg, New Delhi',
                      controller: addressCtrl,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),

                    ShadiTextField(
                      label: 'Landmark or Gate Instructions',
                      hint: 'e.g., Near VIP Porch Gate 2',
                      controller: landmarkCtrl,
                    ),
                    const SizedBox(height: 12),

                    Text('Address Category', style: AppTypography.labelMedium),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<AddressType>(
                      initialValue: selectedType,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.borderLight,
                          ),
                        ),
                      ),
                      items: AddressType.values
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.displayLabel),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isDefault,
                      onChanged: (val) => setModalState(() => isDefault = val),
                      activeTrackColor: AppColors.warmGold,
                      activeThumbColor: Colors.white,
                      title: const Text('Set as default pickup point'),
                    ),
                    const SizedBox(height: 16),

                    ShadiPrimaryButton(
                      text: existing == null
                          ? 'Save Address'
                          : 'Update Address',
                      onPressed: () async {
                        final label = labelCtrl.text.trim();
                        final address = addressCtrl.text.trim();
                        if (label.isEmpty || address.isEmpty) return;

                        if (existing == null) {
                          await controller.addAddress(
                            SavedAddress(
                              id: '',
                              customerId: customerId,
                              label: label,
                              address: address,
                              landmark: landmarkCtrl.text.trim().isNotEmpty
                                  ? landmarkCtrl.text.trim()
                                  : null,
                              type: selectedType,
                              isDefault: isDefault,
                            ),
                          );
                        } else {
                          await controller.updateAddress(
                            existing.copyWith(
                              label: label,
                              address: address,
                              landmark: landmarkCtrl.text.trim().isNotEmpty
                                  ? landmarkCtrl.text.trim()
                                  : null,
                              type: selectedType,
                              isDefault: isDefault,
                            ),
                          );
                        }
                        if (context.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final state = ref.watch(savedAddressesControllerProvider(session.userId));
    final controller = ref.read(
      savedAddressesControllerProvider(session.userId).notifier,
    );

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
          'Saved Addresses',
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: state.isLoading
          ? const Center(child: ShadiLoadingIndicator())
          : state.addresses.isEmpty
          ? ShadiEmptyState(
              icon: Icons.location_off_rounded,
              title: 'No Saved Addresses',
              description:
                  'Save wedding venues and residences for 1-tap bookings.',
              actionLabel: 'Add Address',
              onAction: () =>
                  _showAddressDialog(context, controller, session.userId),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.addresses.length,
              itemBuilder: (context, index) {
                final item = state.addresses[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ShadiCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.champagneGold.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _iconForType(item.type),
                                color: AppColors.primaryBurgundy,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        item.label,
                                        style: AppTypography.titleSmall
                                            .copyWith(
                                              color: AppColors.textPrimaryLight,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      if (item.isDefault) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.warmGold,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'DEFAULT',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    item.type.displayLabel,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                color: AppColors.textSecondaryLight,
                              ),
                              onSelected: (action) {
                                if (action == 'edit') {
                                  _showAddressDialog(
                                    context,
                                    controller,
                                    session.userId,
                                    existing: item,
                                  );
                                } else if (action == 'delete') {
                                  controller.deleteAddress(item.id);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Delete',
                                    style: TextStyle(color: AppColors.errorRed),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.address,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimaryLight,
                            height: 1.4,
                          ),
                        ),
                        if (item.landmark != null &&
                            item.landmark!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.flag_rounded,
                                size: 14,
                                color: AppColors.warmGold,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item.landmark!,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.textSecondaryLight,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ShadiPrimaryButton(
            text: 'Add New Saved Address',
            onPressed: () =>
                _showAddressDialog(context, controller, session.userId),
          ),
        ),
      ),
    );
  }
}
