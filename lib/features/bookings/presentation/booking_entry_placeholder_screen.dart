import 'package:flutter/material.dart';
import 'booking_entry_screen.dart';

/// Legacy placeholder retained for backward compatibility.
/// Delegates directly to [BookingEntryScreen].
class BookingEntryPlaceholderScreen extends StatelessWidget {
  final String vehicleId;

  const BookingEntryPlaceholderScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context) {
    return BookingEntryScreen(vehicleId: vehicleId);
  }
}
