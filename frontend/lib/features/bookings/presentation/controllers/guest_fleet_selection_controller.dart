import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../domain/entities/guest_fleet_selection.dart';

/// Application-level guest booking selection.
///
/// The signed-out visitor's temporary fleet selection (vehicle types +
/// quantities + trip details). Deliberately NOT `autoDispose`: the selection
/// must outlive the screens that produced it — including the detour through
/// login — so a guest who picked "Thar × 2, Scorpio × 1" never has to pick
/// them again after authenticating.
///
/// Lifecycle:
///   * grows while the guest browses (add from vehicle cards / details);
///   * handed to the group-booking flow at "Continue to Booking";
///   * SURVIVES authentication — the whole point: after the login detour the
///     authenticated customer resumes with exactly the cars they picked;
///   * CLEARED when a booking is submitted from it ([consume]);
///   * cleared on sign-out (a shared device must not leak selections).
class GuestFleetSelectionController
    extends StateNotifier<GuestFleetSelection> {
  GuestFleetSelectionController(Ref ref) : super(const GuestFleetSelection()) {
    // Sign-OUT wipes the selection: one account's (or one guest's) intended
    // booking must never leak into the next person's session on a shared
    // device. Sign-IN deliberately keeps it — the selection IS the booking
    // intent the guest was resuming.
    ref.listen<AuthSession>(activeSessionProvider, (prev, next) {
      final wasAuthed = prev?.isAuthenticated ?? false;
      if (wasAuthed && !next.isAuthenticated) {
        state = const GuestFleetSelection();
      }
    });
  }

  void addType({
    required String vehicleTypeId,
    required String displayName,
    required String vehicleClass,
    required int seatingCapacity,
  }) =>
      state = state.upsertType(
        vehicleTypeId: vehicleTypeId,
        displayName: displayName,
        vehicleClass: vehicleClass,
        seatingCapacity: seatingCapacity,
        quantityDelta: 1,
      );

  /// Sets the quantity of an ALREADY SELECTED vehicle type; a value of 0 or
  /// less removes the line.
  ///
  /// Deliberately does NOT create a line: this model has no metadata (display
  /// name, class, seating) of its own to invent, so a caller that wants to
  /// introduce a type must go through [addType]. Every in-app caller either
  /// comes from the stepper (the line exists) or from [replaceLines].
  void setQuantity(String vehicleTypeId, int quantity) =>
      state = state.withQuantity(vehicleTypeId, quantity);

  /// ONE action for the card / details affordance: not selected → add,
  /// already selected → remove. This is what makes a selected vehicle
  /// deselectable from the very surface it was added on, so a visitor never
  /// has to hunt for a separate "review" screen to take a car out.
  void toggleType({
    required String vehicleTypeId,
    required String displayName,
    required String vehicleClass,
    required int seatingCapacity,
  }) {
    if (state.containsType(vehicleTypeId)) {
      removeType(vehicleTypeId);
    } else {
      addType(
        vehicleTypeId: vehicleTypeId,
        displayName: displayName,
        vehicleClass: vehicleClass,
        seatingCapacity: seatingCapacity,
      );
    }
  }

  void removeType(String vehicleTypeId) =>
      state = state.withQuantity(vehicleTypeId, 0);

  /// Replaces the whole composition with [lines] in place (used by the review
  /// screen so a removal there is reflected everywhere immediately), keeping
  /// the trip details that were captured alongside it.
  void replaceLines(List<GuestFleetLine> lines) => state = GuestFleetSelection(
        lines: lines.where((l) => l.quantity > 0).toList(growable: false),
        trip: state.trip,
      );

  void updateTrip(GuestTripDetails trip) =>
      state = state.withTrip(trip);

  /// The booking was created from the selection — it served its purpose.
  void consume() => state = const GuestFleetSelection();

  /// Selection affordance for one vehicle type, derived from the CURRENT
  /// state of this controller. Callers must `watch` the provider so the widget
  /// rebuilds when the selection changes; they must never cache this across
  /// a state change.
  ///
  /// Returns a null-handled affordance when the vehicle type is unknown
  /// (an empty `vehicleTypeId` on a payload that did not carry one) so a
  /// surface renders no selection control at all rather than a broken one.
  GuestVehicleSelection affordanceFor({
    required String vehicleTypeId,
    required String displayName,
    required String vehicleClass,
    required int seatingCapacity,
  }) {
    if (vehicleTypeId.isEmpty) {
      return const GuestVehicleSelection(isSelected: false, quantity: 0);
    }
    final quantity = state.quantityOf(vehicleTypeId);
    return GuestVehicleSelection(
      isSelected: quantity > 0,
      quantity: quantity,
      onAdd: () => toggleType(
        vehicleTypeId: vehicleTypeId,
        displayName: displayName,
        vehicleClass: vehicleClass,
        seatingCapacity: seatingCapacity,
      ),
      onQuantityChanged: (next) => setQuantity(vehicleTypeId, next),
      onRemove: () => removeType(vehicleTypeId),
    );
  }
}

/// The complete selection affordance for ONE vehicle type, built from the
/// shared controller.
///
/// WHY A FACTORY: the previous implementation wired "Add to Selection" by hand
/// on every surface (home feed, search results, vehicle details) and each one
/// called `addType` unconditionally — so tapping an already-selected vehicle
/// INCREMENTED its quantity instead of removing it, and no surface in the app
/// could deselect. Building the affordance in one place means every surface
/// adds on the first tap and removes on the next, identically.
class GuestVehicleSelection {
  /// Whether this type is part of the selection right now.
  final bool isSelected;

  /// Selected units (0 when not selected).
  final int quantity;

  /// First tap: add one unit.
  final VoidCallback? onAdd;

  /// Quantity stepper; 0 removes the line.
  final ValueChanged<int>? onQuantityChanged;

  /// Explicit removal.
  final VoidCallback? onRemove;

  const GuestVehicleSelection({
    required this.isSelected,
    required this.quantity,
    this.onAdd,
    this.onQuantityChanged,
    this.onRemove,
  });
}

/// True while a screen that already IS the selection (the review screen) owns
/// the bottom of the frame, so the persistent selection bar steps aside
/// instead of offering to open the page the visitor is already looking at.
///
/// A provider rather than a route check, deliberately: pushes inside the
/// customer shell's own `Navigator` do NOT update the shell's
/// `GoRouterState.matchedLocation`, so a location-based test silently failed
/// and the bar stayed on top of the review screen (where a tap would stack a
/// second copy of it).
final selectionBarSuppressedProvider = StateProvider<bool>((ref) => false);

/// KeepAlive: see [GuestFleetSelectionController] for why this must survive
/// screen disposal and the login detour.
final guestFleetSelectionProvider =
    StateNotifierProvider<GuestFleetSelectionController, GuestFleetSelection>(
  (ref) => GuestFleetSelectionController(ref),
);
