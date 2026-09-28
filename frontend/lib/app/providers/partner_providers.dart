import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_providers.dart';
import '../../features/partner/data/partner_api_repository.dart';
import '../../features/partner/domain/repositories/partner_repository.dart';

/// Partner repository — REAL API by default (same no-mock rule as every other
/// feature). The repository interface has no mock implementation yet; mock
/// mode is intentionally not supported for the partner flow because the
/// onboarding must exercise the real backend contract end to end.
final partnerRepositoryProvider = Provider<PartnerRepository>((ref) {
  return PartnerApiRepository(ref.watch(apiClientProvider));
});
