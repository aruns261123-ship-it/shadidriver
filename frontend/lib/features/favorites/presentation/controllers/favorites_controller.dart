import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../domain/entities/favorites_view.dart';

/// Favourites state as the UI needs it.
///
/// A signed-out visitor gets a working heart and a session-local shortlist; the
/// moment they authenticate, that shortlist is imported into their account and
/// every later change is persisted server-side.
class FavoritesState {
  final FavoritesView view;

  /// TRUE once the state is backed by the customer's account.
  final bool isAccountBacked;

  /// TRUE while a server call is in flight.
  final bool isSyncing;

  /// Non-null when the last server call failed; the optimistic change was undone.
  final String? errorMessage;

  const FavoritesState({
    this.view = FavoritesView.empty,
    this.isAccountBacked = false,
    this.isSyncing = false,
    this.errorMessage,
  });

  /// Saved ids, including ones whose vehicle is no longer bookable.
  Set<String> get vehicleIds => view.vehicleIds;

  List<String> get orderedIds {
    final ids = view.vehicles.map((v) => v.id).toList();
    for (final id in view.vehicleIds) {
      if (!ids.contains(id)) ids.add(id);
    }
    return ids;
  }

  bool contains(String vehicleId) => view.contains(vehicleId);

  int get savedCount => view.vehicleIds.length;
  int get unavailableCount => view.unavailableCount;

  FavoritesState copyWith({
    FavoritesView? view,
    bool? isAccountBacked,
    bool? isSyncing,
    Object? errorMessage = _unset,
  }) => FavoritesState(
    view: view ?? this.view,
    isAccountBacked: isAccountBacked ?? this.isAccountBacked,
    isSyncing: isSyncing ?? this.isSyncing,
    errorMessage: errorMessage == _unset
        ? this.errorMessage
        : errorMessage as String?,
  );

  static const Object _unset = Object();
}

/// Account-aware favourites.
///
/// Rules:
///   * a guest's shortlist stays local until they have an account;
///   * on sign-in the local shortlist is MERGED, never discarded, so a visitor
///     who saved five cars while browsing keeps all five;
///   * on sign-out the state is cleared, so one account's saved vehicles are
///     never shown to the next person on a shared device.
class FavoritesController extends Notifier<FavoritesState> {
  bool _busy = false;

  @override
  FavoritesState build() {
    ref.listen<AuthSession>(activeSessionProvider, (prev, next) {
      final wasAuthenticated = prev?.isAuthenticated ?? false;
      if (next.isAuthenticated && !wasAuthenticated) {
        unawaited(_onSignedIn());
      } else if (!next.isAuthenticated && wasAuthenticated) {
        state = const FavoritesState();
      }
    });

    // Cold start with a restored session.
    if (ref.read(activeSessionProvider).isAuthenticated) {
      unawaited(_onSignedIn());
    }
    return const FavoritesState();
  }

  bool get isAuthenticated => ref.read(activeSessionProvider).isAuthenticated;

  /// Hands any guest shortlist to the server, then adopts the server state.
  Future<void> _onSignedIn() async {
    if (_busy) return;
    _busy = true;
    final guestIds = state.view.vehicleIds.toList();
    state = state.copyWith(isSyncing: true, errorMessage: null);

    final repo = ref.read(favoritesRepositoryProvider);
    final result = guestIds.isEmpty
        ? await repo.list()
        : await repo.merge(guestIds);

    result.when(
      success: (view) => state = FavoritesState(
        view: view,
        isAccountBacked: true,
        isSyncing: false,
      ),
      failure: (failure) => state = state.copyWith(
        isSyncing: false,
        errorMessage: failure.message,
      ),
    );
    _busy = false;
  }

  /// Reloads from the server (screen entry, pull-to-refresh).
  Future<void> refresh() async {
    if (!isAuthenticated || _busy) return;
    _busy = true;
    state = state.copyWith(isSyncing: true, errorMessage: null);
    final result = await ref.read(favoritesRepositoryProvider).list();
    result.when(
      success: (view) => state = FavoritesState(
        view: view,
        isAccountBacked: true,
        isSyncing: false,
      ),
      failure: (failure) => state = state.copyWith(
        isSyncing: false,
        errorMessage: failure.message,
      ),
    );
    _busy = false;
  }

  /// Saves or unsaves a vehicle. Optimistic for responsiveness, and reverted
  /// with a message if the server rejects the change.
  Future<void> toggle(String vehicleId) async {
    if (vehicleId.isEmpty) return;
    final wasSaved = state.contains(vehicleId);

    _applyLocal(vehicleId, saved: !wasSaved, clearError: true);

    if (!isAuthenticated) {
      // Guest shortlist: intentionally session-local, merged on sign-in.
      return;
    }

    final repo = ref.read(favoritesRepositoryProvider);
    final result = wasSaved
        ? await repo.remove(vehicleId)
        : await repo.add(vehicleId);

    result.when(
      success: (view) => state = FavoritesState(
        view: view,
        isAccountBacked: true,
        isSyncing: false,
      ),
      failure: (failure) {
        // Undo the optimistic change so the UI never claims a save the server
        // did not accept.
        _applyLocal(vehicleId, saved: wasSaved, clearError: false);
        state = state.copyWith(errorMessage: failure.message);
      },
    );
  }

  Future<void> add(String vehicleId) async {
    if (state.contains(vehicleId)) return;
    await toggle(vehicleId);
  }

  Future<void> remove(String vehicleId) async {
    if (!state.contains(vehicleId)) return;
    await toggle(vehicleId);
  }

  bool isSaved(String vehicleId) => state.contains(vehicleId);

  void _applyLocal(
    String vehicleId, {
    required bool saved,
    required bool clearError,
  }) {
    final ids = Set<String>.from(state.vehicleIds);
    var vehicles = state.view.vehicles;
    if (saved) {
      ids.add(vehicleId);
    } else {
      ids.remove(vehicleId);
      vehicles = vehicles.where((v) => v.id != vehicleId).toList();
    }
    state = state.copyWith(
      view: FavoritesView(
        vehicles: vehicles,
        vehicleIds: ids,
        total: ids.length,
        unavailableCount: state.view.unavailableCount,
      ),
      errorMessage: clearError ? null : state.errorMessage,
    );
  }
}

final favoritesProvider = NotifierProvider<FavoritesController, FavoritesState>(
  FavoritesController.new,
);
