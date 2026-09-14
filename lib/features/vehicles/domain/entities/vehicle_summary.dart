/// Vehicle summary domain entity.
class VehicleSummary {
  final String id;
  final String make;
  final String model;
  final int year;
  final String vehicleClass;
  final String registrationNumber;
  final int seatingCapacity;
  final String verificationStatus;

  const VehicleSummary({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.vehicleClass,
    required this.registrationNumber,
    required this.seatingCapacity,
    required this.verificationStatus,
  });
}
