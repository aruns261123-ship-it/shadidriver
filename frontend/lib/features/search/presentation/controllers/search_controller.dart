import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import '../../domain/entities/search_query.dart';
import '../../domain/entities/search_session.dart';
import '../../domain/entities/search_sort.dart';

/// Managed state for a ride discovery search session.
class SearchController extends Notifier<SearchSession> {
  /// Monotonic token guarding against out-of-order search responses: with the
  /// mocked 600 ms latency, a slow earlier query can otherwise resolve AFTER
  /// a newer one and overwrite the fresher results.
  int _searchSeq = 0;

  @override
  SearchSession build() {
    return SearchSession.initial();
  }

  void performInitialSearch() {
    if (state.status == SearchStatus.initial) {
      _performSearch();
    }
  }

  void updateQuery(VehicleSearchQuery newQuery) {
    state = state.copyWith(
      query: newQuery,
      status: SearchStatus.loading,
      lastUpdated: DateTime.now(),
    );
    _performSearch();
  }

  void updateSort(SearchSort newSort) {
    state = state.copyWith(
      sort: newSort,
      status: SearchStatus.loading,
      lastUpdated: DateTime.now(),
    );
    _performSearch();
  }

  void resetSearch() {
    _searchSeq++; // invalidate any in-flight search
    state = SearchSession.initial();
  }

  Future<void> _performSearch() async {
    final token = ++_searchSeq;
    final vehicleRepo = ref.read(vehicleRepositoryProvider);

    // Snapshot the query being searched so late state writes can't desync
    // the request from its results.
    final query = state.query;
    final sort = state.sort;

    final result = await vehicleRepo.searchVehicles(
      query: query,
      sort: sort,
    );

    // A newer search/reset superseded this one — discard the stale response.
    if (token != _searchSeq) return;

    state = result.fold(
      (failure) => state.copyWith(
        status: SearchStatus.error,
        error: failure,
        lastUpdated: DateTime.now(),
      ),
      (vehicles) => state.copyWith(
        results: vehicles,
        status: vehicles.isEmpty ? SearchStatus.empty : SearchStatus.loaded,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  void clearFilters() {
    updateQuery(
      VehicleSearchQuery(
        pickupLocation: state.query.pickupLocation,
        destination: state.query.destination,
        eventDate: state.query.eventDate,
        eventTime: state.query.eventTime,
        occasionId: state.query.occasionId,
        passengerCount: state.query.passengerCount,
      ),
    );
  }
}

final searchControllerProvider =
    NotifierProvider<SearchController, SearchSession>(SearchController.new);
