import 'package:flutter/material.dart';
import 'booking_entry_screen.dart';

/// Legacy placeholder retained for backward compatibility.
/// Delegates directly to [BookingEntryScreen].
class BookingEntryPlaceholderScreen extends StatelessWidget {
  final String vehicleId;
  final String? draftId;

  const BookingEntryPlaceholderScreen({
    super.key,
    required this.vehicleId,
    this.draftId,
  });

  @override
  Widget build(BuildContext context) {
    return BookingEntryScreen(vehicleId: vehicleId, draftId: draftId);
  }
}
