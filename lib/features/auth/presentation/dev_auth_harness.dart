import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/user_role.dart';
import 'controllers/auth_controller.dart';

/// Isolated developer authentication harness for testing and local development.
///
/// MUST NEVER be exposed in production UI.
///
/// Designated test phone numbers:
/// - Customer (Active): 9876543210 or 9810000001
/// - Chauffeur/Driver (Active): 9810000002 or 9876500002
/// - Admin (Active): 9810000003 or 9876500003
/// - Incomplete Customer Profile: 9810000004
/// - Incomplete Chauffeur Profile: 9810000005
/// - Suspended Account: 9810000006
///
/// Universal OTP code: 000000
abstract final class DevAuthHarness {
  static const String customerPhone = '9876543210';
  static const String alternateCustomerPhone = '9810000001';
  static const String driverPhone = '9810000002';
  static const String adminPhone = '9810000003';
  static const String incompleteCustomerPhone = '9810000004';
  static const String incompleteDriverPhone = '9810000005';
  static const String suspendedPhone = '9810000006';

  static const String universalOtp = '000000';

  /// Authenticate directly into a role via the controller (test/dev only)
  static Future<void> authenticateAsRole(
    ProviderContainer container,
    UserRole role,
  ) async {
    await container.read(authControllerProvider.notifier).devLoginAsRole(role);
  }

  /// Authenticate via the full phone + OTP cycle (test/dev only)
  static Future<void> authenticateWithPhone(
    ProviderContainer container,
    String phone, {
    String otp = universalOtp,
  }) async {
    final controller = container.read(authControllerProvider.notifier);
    final req = await controller.requestOtp(phoneNumber: phone);
    if (req.isSuccess) {
      await controller.verifyOtp(
        otpSessionId: req.dataOrNull!,
        otpCode: otp,
      );
    }
  }
}
