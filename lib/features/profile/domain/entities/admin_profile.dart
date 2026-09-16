import 'package:flutter/foundation.dart';
import '../../../auth/domain/entities/user_role.dart';

/// Immutable domain model representing an operational administrator profile.
///
/// Invariant: [role] and [authorizationLevel] are authoritative and cannot be
/// altered through ordinary client profile editing.
@immutable
class AdminProfile {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String? photoUrl;
  final UserRole role;
  final String department;
  final String authorizationLevel;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AdminProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.photoUrl,
    required this.role,
    required this.department,
    required this.authorizationLevel,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isNameValid => fullName.trim().length >= 2;
  bool get isEmailValid =>
      RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(email.trim());

  /// Only non-authorization fields can be updated by client profile edits.
  AdminProfile copyWithContactInfo({
    String? fullName,
    String? phone,
    String? photoUrl,
    DateTime? updatedAt,
  }) {
    return AdminProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email, // immutable from client profile
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role, // strictly immutable from client profile
      department: department, // strictly immutable from client profile
      authorizationLevel: authorizationLevel, // strictly immutable
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AdminProfile &&
          other.id == id &&
          other.fullName == fullName &&
          other.email == email &&
          other.phone == phone &&
          other.photoUrl == photoUrl &&
          other.role == role &&
          other.department == department &&
          other.authorizationLevel == authorizationLevel);

  @override
  int get hashCode => Object.hash(
    id,
    fullName,
    email,
    phone,
    photoUrl,
    role,
    department,
    authorizationLevel,
  );
}
