import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import '../../domain/entities/search_query.dart';
import '../../domain/entities/search_session.dart';
import '../../domain/entities/search_sort.dart';

/// Managed state for a ride discovery search session.
class SearchController extends Notifier<SearchSession> {
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
    state = SearchSession.initial();
  }

  Future<void> _performSearch() async {
    final vehicleRepo = ref.read(vehicleRepositoryProvider);

    final result = await vehicleRepo.searchVehicles(
      query: state.query,
      sort: state.sort,
    );

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
