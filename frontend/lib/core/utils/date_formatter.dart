/// Utility for formatting dates and ceremony times in ShadiDriver.
abstract final class DateFormatter {
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Formats DateTime into a wedding ceremony date string (e.g., "24 Nov 2026").
  static String formatCeremonyDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = _months[local.month - 1];
    final year = local.year;
    return '$day $month $year';
  }

  /// Formats DateTime into a ceremony time string (e.g., "04:30 PM").
  static String formatCeremonyTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour24 = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final isPm = hour24 >= 12;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final period = isPm ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:$minute $period';
  }

  /// Formats DateTime into date and time (e.g., "24 Nov 2026, 04:30 PM").
  static String formatCeremonyDateTime(DateTime dateTime) {
    return '${formatCeremonyDate(dateTime)}, ${formatCeremonyTime(dateTime)}';
  }
}
