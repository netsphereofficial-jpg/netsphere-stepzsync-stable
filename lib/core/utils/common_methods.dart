import 'package:intl/intl.dart';
import './snackbar_utils.dart';

// Extension for number formatting
extension DoubleExtensions on double {
  String toFixed2OrDash() {
    if (isNaN || isInfinite) return '--';
    return toStringAsFixed(2);
  }
}

// Date formatting utilities
String getFormattedDate(String dateTimeString) {
  try {
    // First try to parse as ISO format
    final dateTime = DateTime.parse(dateTimeString);
    return DateFormat('dd/MM/yyyy').format(dateTime);
  } catch (e) {
    try {
      // Try to parse the format "dd/MM/yyyy at hh:mm a"
      if (dateTimeString.contains(' at ')) {
        final datePart = dateTimeString.split(' at ')[0];
        final DateTime dateTime = DateFormat('dd/MM/yyyy').parse(datePart);
        return DateFormat('dd/MM/yyyy').format(dateTime);
      }
      return dateTimeString.split(' ').first;
    } catch (e2) {
      // Fallback - return just the date part if possible
      return dateTimeString.split(' ').first;
    }
  }
}

String getFormattedTime(String dateTimeString) {
  try {
    // First try to parse as ISO format
    final dateTime = DateTime.parse(dateTimeString);
    return DateFormat('HH:mm').format(dateTime);
  } catch (e) {
    try {
      // Try to parse the format "dd/MM/yyyy at hh:mm a"
      if (dateTimeString.contains(' at ')) {
        final parts = dateTimeString.split(' at ');
        if (parts.length >= 2) {
          final datePart = parts[0];
          final timePart = parts[1];

          // Parse both date and time to get full DateTime
          final dateTime = DateFormat('dd/MM/yyyy').parse(datePart);
          final timeFormat = DateFormat('hh:mm a');
          final timeOnly = timeFormat.parse(timePart);

          // Combine date and time
          final fullDateTime = DateTime(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            timeOnly.hour,
            timeOnly.minute,
          );

          return DateFormat('HH:mm').format(fullDateTime);
        }
      }

      // Fallback: try to extract just the time part
      final timePartsWithColon = dateTimeString
          .split(' ')
          .where((part) => part.contains(':'))
          .toList();
      final timePart = timePartsWithColon.isNotEmpty ? timePartsWithColon.first : null;

      if (timePart != null) {
        try {
          final timeOnly = DateFormat('HH:mm').parse(timePart);
          return DateFormat('HH:mm').format(timeOnly);
        } catch (e3) {
          try {
            final timeOnly = DateFormat('hh:mm a').parse(timePart);
            return DateFormat('HH:mm').format(timeOnly);
          } catch (e4) {
            return timePart;
          }
        }
      }

      return '--:--';
    } catch (e2) {
      return '--:--';
    }
  }
}

// Network utility placeholder
Future<bool> isNetworkAvailable() async {
  // Implement your network check logic here
  return true;
}

// String capitalization utilities
extension StringCapitalization on String {
  /// Capitalizes the first letter of each word in a string
  /// Example: "john doe" -> "John Doe"
  String capitalizeWords() {
    if (isEmpty) return this;

    return split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  /// Capitalizes only the first letter of the string
  /// Example: "hello world" -> "Hello world"
  String capitalizeFirst() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

// Snackbar utility - removed functionality
void showSnackbar(String title, String message) {
  // Snackbar functionality removed - no UI feedback
}