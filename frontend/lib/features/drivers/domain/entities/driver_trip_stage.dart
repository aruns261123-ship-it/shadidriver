/// Lifecycle stages for an active ceremonial chauffeur trip.
enum DriverTripStage {
  assigned('Assigned • Preparing Vehicle'),
  enRouteToPickup('En Route to Pickup'),
  arrivedAtPickup('Arrived at Venue / Pickup'),
  ceremonyInProgress('Ceremonial Service in Progress'),
  completed('Ceremonial Service Completed');

  final String displayLabel;
  const DriverTripStage(this.displayLabel);

  bool get isBeforeStart =>
      this == DriverTripStage.assigned ||
      this == DriverTripStage.enRouteToPickup ||
      this == DriverTripStage.arrivedAtPickup;

  bool get isActive => this == DriverTripStage.ceremonyInProgress;

  bool get isFinished => this == DriverTripStage.completed;
}
