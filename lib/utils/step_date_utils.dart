import 'package:intl/intl.dart';

/// Utility class for date operations in step tracking
class StepDateUtils {
  /// Get current date in YYYY-MM-DD format
  static String getTodayDate() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  /// Get yesterday's date in YYYY-MM-DD format
  static String getYesterdayDate() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return DateFormat('yyyy-MM-dd').format(yesterday);
  }

  /// Format DateTime to YYYY-MM-DD
  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Parse YYYY-MM-DD string to DateTime
  static DateTime parseDate(String dateString) {
    return DateFormat('yyyy-MM-dd').parse(dateString);
  }

  /// Get date range for a filter period
  static DateRange getDateRangeForFilter(String filter) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    switch (filter) {
      case 'Today':
        return DateRange(start: todayDate, end: todayDate);

      case 'Yesterday':
        final yesterday = todayDate.subtract(const Duration(days: 1));
        return DateRange(start: yesterday, end: yesterday);

      case 'Last 7 days':
        final start = todayDate.subtract(const Duration(days: 6));
        return DateRange(start: start, end: todayDate);

      case 'Last 30 days':
        final start = todayDate.subtract(const Duration(days: 29));
        return DateRange(start: start, end: todayDate);

      case 'Last 60 days':
        final start = todayDate.subtract(const Duration(days: 59));
        return DateRange(start: start, end: todayDate);

      case 'Last 90 days':
        final start = todayDate.subtract(const Duration(days: 89));
        return DateRange(start: start, end: todayDate);

      case 'All time':
        // Start from a very old date
        final start = DateTime(2020, 1, 1);
        return DateRange(start: start, end: todayDate);

      default:
        return DateRange(start: todayDate, end: todayDate);
    }
  }

  /// Get list of date strings between start and end (inclusive)
  static List<String> getDateStringsBetween(DateTime start, DateTime end) {
    final List<String> dates = [];
    DateTime current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      dates.add(formatDate(current));
      current = current.add(const Duration(days: 1));
    }

    return dates;
  }

  /// Check if date is today
  static bool isToday(String dateString) {
    final date = parseDate(dateString);
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  /// Check if date is yesterday
  static bool isYesterday(String dateString) {
    final date = parseDate(dateString);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// Get time until midnight (for rollover timer)
  static Duration timeUntilMidnight() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return tomorrow.difference(now);
  }

  /// Get current hour (0-23)
  static int getCurrentHour() {
    return DateTime.now().hour;
  }

  /// Format duration to human-readable string
  static String formatDuration(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }

  /// Get day of week name
  static String getDayOfWeek(String dateString) {
    final date = parseDate(dateString);
    return DateFormat('EEEE').format(date);
  }

  /// Get formatted display date (e.g., "Oct 18, 2025")
  static String getDisplayDate(String dateString) {
    final date = parseDate(dateString);
    return DateFormat('MMM dd, yyyy').format(date);
  }

  /// Calculate number of days between two dates
  static int daysBetween(DateTime start, DateTime end) {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    return endDate.difference(startDate).inDays;
  }
}

/// Date range model
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});

  /// Get number of days in range
  int get days {
    return StepDateUtils.daysBetween(start, end) + 1;
  }

  /// Get list of date strings in range
  List<String> get dateStrings {
    return StepDateUtils.getDateStringsBetween(start, end);
  }

  @override
  String toString() {
    return 'DateRange(${StepDateUtils.formatDate(start)} to ${StepDateUtils.formatDate(end)})';
  }
}
