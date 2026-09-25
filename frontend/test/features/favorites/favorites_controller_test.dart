import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/core/errors/failures.dart';
import 'package:shadidriver/core/result/result.dart';
import 'package:shadidriver/features/auth/domain/entities/account_status.dart';
import 'package:shadidriver/features/auth/domain/entities/auth_session.dart';
import 'package:shadidriver/features/auth/domain/entities/user_role.dart';
import 'package:shadidriver/features/favorites/domain/entities/favorites_view.dart';
import 'package:shadidriver/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:shadidriver/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:shadidriver/features/vehicles/domain/entities/pricing_summary.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_summary.dart';

const _v1 = '11111111-1111-4111-8111-111111111111';
const _v2 = '22222222-2222-4222-8222-222222222222';

VehicleSummary _vehicle(String id) => VehicleSummary(
  id: id,
  make: 'Mahindra',
  model: 'Thar',
  year: 2023,
  vehicleClass: 'Premium SUV',
  registrationNumber: 'SD-VH-0001',
  seatingCapacity: 5,
  verificationStatus: 'APPROVED',
  pricing: const PricingSummary(basePriceCents: 300000, billingUnit: 'DAY'),
);

AuthSession _signedIn() => AuthSession(
  userId: 'customer-1',
  phone: '+91 98100 XXXXX',
  role: UserRole.customer,
  accountStatus: AccountStatus.active,
  issuedAt: DateTime(2026, 9, 25),
);

class _FakeFavoritesRepository implements FavoritesRepository {
  final List<String> calls = <String>[];
  FavoritesView view = FavoritesView.empty;
  List<String> lastMerged = const [];
  bool failEverything = false;

  Result<FavoritesView> _fail() =>
      Result.failure(const ServerFailure('Sync failed.'));

  @override
  Future<Result<FavoritesView>> list() async {
    calls.add('list');
    return failEverything ? _fail() : Result.success(view);
  }

  @override
  Future<Result<FavoritesView>> add(String vehicleId) async {
    calls.add('add:$vehicleId');
    if (failEverything) return _fail();
    view = FavoritesView(
      vehicles: [...view.vehicles, _vehicle(vehicleId)],
      vehicleIds: {...view.vehicleIds, vehicleId},
      total: view.vehicleIds.length + 1,
      unavailableCount: view.unavailableCount,
    );
    return Result.success(view);
  }

  @override
  Future<Result<FavoritesView>> remove(String vehicleId) async {
    calls.add('remove:$vehicleId');
    if (failEverything) return _fail();
    final ids = {...view.vehicleIds}..remove(vehicleId);
    view = FavoritesView(
      vehicles: view.vehicles.where((v) => v.id != vehicleId).toList(),
      vehicleIds: ids,
      total: ids.length,
      unavailableCount: 0,
    );
    return Result.success(view);
  }

  @override
  Future<Result<FavoritesView>> merge(List<String> vehicleIds) async {
    calls.add('merge:${vehicleIds.join(",")}');
    lastMerged = vehicleIds;
    if (failEverything) return _fail();
    view = FavoritesView(
      vehicles: vehicleIds.map(_vehicle).toList(),
      vehicleIds: vehicleIds.toSet(),
      total: vehicleIds.length,
      unavailableCount: 0,
      ignoredVehicleIds: const ['stale-id'],
    );
    return Result.success(view);
  }
}

void main() {
  late _FakeFavoritesRepository repo;
  late ProviderContainer container;

  ProviderContainer build() {
    repo = _FakeFavoritesRepository();
    final c = ProviderContainer(
      overrides: [favoritesRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    container = build();
    // Instantiate the notifier, as the UI does.
    container.read(favoritesProvider);
  });

  group('signed-out visitor', () {
    test('saving a vehicle is local — no server call at all', () async {
      await container.read(favoritesProvider.notifier).toggle(_v1);

      expect(container.read(favoritesProvider).contains(_v1), isTrue);
      expect(container.read(favoritesProvider).isAccountBacked, isFalse);
      expect(repo.calls, isEmpty);
    });

    test('the shortlist survives browsing but is not persisted', () async {
      final notifier = container.read(favoritesProvider.notifier);
      await notifier.toggle(_v1);
      await notifier.toggle(_v2);
      await notifier.toggle(_v1); // unsave

      expect(container.read(favoritesProvider).vehicleIds, {_v2});
    });
  });

  group('sign-in hands the guest shortlist to the account', () {
    test('a guest shortlist is merged, not discarded', () async {
      final notifier = container.read(favoritesProvider.notifier);
      await notifier.toggle(_v1);
      await notifier.toggle(_v2);

      container.read(activeSessionProvider.notifier).state = _signedIn();
      await settle();
      await settle();

      expect(repo.calls, contains('merge:$_v1,$_v2'));
      final state = container.read(favoritesProvider);
      expect(state.isAccountBacked, isTrue);
      expect(state.vehicleIds, {_v1, _v2});
    });

    test('stale shortlist entries are reported, not fatal', () async {
      await container.read(favoritesProvider.notifier).toggle(_v1);
      container.read(activeSessionProvider.notifier).state = _signedIn();
      await settle();
      await settle();

      expect(
        container.read(favoritesProvider).view.ignoredVehicleIds,
        ['stale-id'],
      );
    });

    test('signing in with an empty shortlist simply loads the account list',
        () async {
      container.read(activeSessionProvider.notifier).state = _signedIn();
      await settle();
      await settle();

      expect(repo.calls, contains('list'));
      expect(repo.calls.any((c) => c.startsWith('merge')), isFalse);
    });
  });

  group('signed-in customer', () {
    setUp(() async {
      repo.view = FavoritesView(
        vehicles: [_vehicle(_v1)],
        vehicleIds: {_v1},
        total: 1,
      );
      container.read(activeSessionProvider.notifier).state = _signedIn();
      await settle();
      await settle();
    });

    test('saves are persisted server-side', () async {
      await container.read(favoritesProvider.notifier).toggle(_v2);
      expect(repo.calls, contains('add:$_v2'));
      expect(container.read(favoritesProvider).vehicleIds, {_v1, _v2});
    });

    test('unsaving is persisted server-side', () async {
      await container.read(favoritesProvider.notifier).toggle(_v1);
      expect(repo.calls, contains('remove:$_v1'));
      expect(container.read(favoritesProvider).contains(_v1), isFalse);
    });

    test('a rejected save is reverted so the UI never lies', () async {
      repo.failEverything = true;
      await container.read(favoritesProvider.notifier).toggle(_v2);

      final state = container.read(favoritesProvider);
      expect(state.contains(_v2), isFalse, reason: 'optimistic flip must undo');
      expect(state.errorMessage, 'Sync failed.');
    });

    test('a rejected unsave keeps the vehicle saved', () async {
      repo.failEverything = true;
      await container.read(favoritesProvider.notifier).toggle(_v1);

      expect(container.read(favoritesProvider).contains(_v1), isTrue);
      expect(container.read(favoritesProvider).errorMessage, isNotNull);
    });
  });

  group('sign-out', () {
    test('clears state so one account never leaks to the next person',
        () async {
      repo.view = FavoritesView(
        vehicles: [_vehicle(_v1)],
        vehicleIds: {_v1},
        total: 1,
      );
      container.read(activeSessionProvider.notifier).state = _signedIn();
      await settle();
      await settle();
      expect(container.read(favoritesProvider).savedCount, 1);

      container.read(activeSessionProvider.notifier).state =
          AuthSession.unauthenticated();
      await settle();

      final state = container.read(favoritesProvider);
      expect(state.savedCount, 0);
      expect(state.isAccountBacked, isFalse);
    });
  });
}
