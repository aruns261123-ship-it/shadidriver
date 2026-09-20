import 'package:flutter/foundation.dart';
import 'package:shadidriver/core/errors/failures.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_summary.dart';
import 'search_query.dart';
import 'search_sort.dart';

enum SearchStatus { initial, loading, loaded, error, empty }

/// Domain model representing an active search session.
@immutable
class SearchSession {
  final VehicleSearchQuery query;
  final SearchSort sort;
  final List<VehicleSummary> results;
  final SearchStatus status;
  final AppFailure? error;
  final DateTime lastUpdated;

  const SearchSession({
    required this.query,
    this.sort = SearchSort.recommended,
    this.results = const [],
    this.status = SearchStatus.initial,
    this.error,
    required this.lastUpdated,
  });

  factory SearchSession.initial() => SearchSession(
    query: const VehicleSearchQuery(),
    lastUpdated: DateTime.now(),
  );

  SearchSession copyWith({
    VehicleSearchQuery? query,
    SearchSort? sort,
    List<VehicleSummary>? results,
    SearchStatus? status,
    AppFailure? error,
    DateTime? lastUpdated,
  }) {
    return SearchSession(
      query: query ?? this.query,
      sort: sort ?? this.sort,
      results: results ?? this.results,
      status: status ?? this.status,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
