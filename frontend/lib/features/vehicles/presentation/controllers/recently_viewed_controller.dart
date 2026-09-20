import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks vehicle IDs the customer opened during this session.
/// Most-recent-first, capped, de-duplicated.
class RecentlyViewedController extends Notifier<List<String>> {
  static const int maxEntries = 5;

  @override
  List<String> build() => const [];

  /// Records a vehicle view; moves an already-tracked id to the front.
  void track(String vehicleId) {
    if (vehicleId.isEmpty) return;
    final updated = List<String>.from(state)..remove(vehicleId);
    updated.insert(0, vehicleId);
    state = updated.take(maxEntries).toList();
  }

  void clear() => state = const [];
}

final recentlyViewedProvider =
    NotifierProvider<RecentlyViewedController, List<String>>(
      RecentlyViewedController.new,
    );
