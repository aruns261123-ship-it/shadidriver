import 'package:flutter/foundation.dart';

/// Categories of saved addresses in ShadiDriver.
enum AddressType {
  home,
  work,
  weddingVenue,
  family,
  other;

  String get displayLabel => switch (this) {
    AddressType.home => 'Home',
    AddressType.work => 'Work',
    AddressType.weddingVenue => 'Wedding Venue',
    AddressType.family => 'Family / Relatives',
    AddressType.other => 'Other',
  };
}

/// Immutable domain model representing a customer's saved address.
@immutable
class SavedAddress {
  final String id;
  final String customerId;
  final String label;
  final String address;
  final String? landmark;
  final AddressType type;
  final bool isDefault;

  const SavedAddress({
    required this.id,
    required this.customerId,
    required this.label,
    required this.address,
    this.landmark,
    this.type = AddressType.other,
    this.isDefault = false,
  });

  bool get isValid =>
      label.trim().isNotEmpty &&
      address.trim().isNotEmpty &&
      customerId.trim().isNotEmpty;

  SavedAddress copyWith({
    String? id,
    String? customerId,
    String? label,
    String? address,
    String? landmark,
    AddressType? type,
    bool? isDefault,
  }) {
    return SavedAddress(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      label: label ?? this.label,
      address: address ?? this.address,
      landmark: landmark ?? this.landmark,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedAddress &&
          other.id == id &&
          other.customerId == customerId &&
          other.label == label &&
          other.address == address &&
          other.landmark == landmark &&
          other.type == type &&
          other.isDefault == isDefault);

  @override
  int get hashCode =>
      Object.hash(id, customerId, label, address, landmark, type, isDefault);
}
