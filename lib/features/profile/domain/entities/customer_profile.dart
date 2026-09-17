import 'package:flutter/foundation.dart';

/// Immutable domain model representing a customer profile in ShadiDriver.
@immutable
class CustomerProfile {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String city;
  final String? preferredLanguage;
  final String? profilePhotoUrl;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? weddingPreferences;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CustomerProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    required this.city,
    this.preferredLanguage,
    this.profilePhotoUrl,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.weddingPreferences,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isNameValid => fullName.trim().length >= 2;

  bool get isPhoneValid {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10 ||
        (digits.length == 12 && digits.startsWith('91'));
  }

  bool get isEmailValid {
    if (email == null || email!.trim().isEmpty) return true;
    return RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(email!.trim());
  }

  bool get isCityValid => city.trim().isNotEmpty;

  bool get isValid =>
      isNameValid && isPhoneValid && isEmailValid && isCityValid;

  CustomerProfile copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? email,
    String? city,
    String? preferredLanguage,
    String? profilePhotoUrl,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? weddingPreferences,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      city: city ?? this.city,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      weddingPreferences: weddingPreferences ?? this.weddingPreferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomerProfile &&
          other.id == id &&
          other.fullName == fullName &&
          other.phone == phone &&
          other.email == email &&
          other.city == city &&
          other.preferredLanguage == preferredLanguage &&
          other.profilePhotoUrl == profilePhotoUrl &&
          other.emergencyContactName == emergencyContactName &&
          other.emergencyContactPhone == emergencyContactPhone &&
          other.weddingPreferences == weddingPreferences);

  @override
  int get hashCode => Object.hash(
        id,
        fullName,
        phone,
        email,
        city,
        preferredLanguage,
        profilePhotoUrl,
        emergencyContactName,
        emergencyContactPhone,
        weddingPreferences,
      );
}
