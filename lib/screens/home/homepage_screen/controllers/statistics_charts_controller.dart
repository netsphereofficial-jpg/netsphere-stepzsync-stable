import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Model for chart data points
class ChartDataPoint {
  final DateTime timestamp;
  final double value;
  final String? label;

  ChartDataPoint({
    required this.timestamp,
    required this.value,
    this.label,
  });
}

/// Controller for managing statistics charts data
class StatisticsChartsController extends GetxController {
  // Loading states
  final RxBool isLoadingChartData = false.obs;

  // Chart data - Observable lists
  final RxList<ChartDataPoint> speedData = <ChartDataPoint>[].obs;
  final RxList<ChartDataPoint> timeData = <ChartDataPoint>[].obs;
  final RxList<ChartDataPoint> caloriesData = <ChartDataPoint>[].obs;

  // Current selected chart type
  final RxString selectedChartType = 'Speed'.obs;
  final List<String> chartTypes = ['Speed', 'Time', 'Calories'];

  // Current filter (synced with statistics card)
  final RxString currentFilter = 'Today'.obs;

  @override
  void onInit() {
    super.onInit();
    print('📊 StatisticsChartsController: Initialized');
  }

  /// Load chart data for a specific filter period
  Future<void> loadChartData(String filter, {
    int? periodSteps,
    double? periodDistance,
    int? periodActiveTime,
    int? periodCalories,
  }) async {
    try {
      isLoadingChartData.value = true;
      currentFilter.value = filter;
      print('📊 Loading chart data for filter: $filter');

      // Clear existing data
      speedData.clear();
      timeData.clear();
      caloriesData.clear();

      // Generate chart data based on filter
      await _generateChartData(
        filter,
        periodSteps: periodSteps,
        periodActiveTime: periodActiveTime,
        periodCalories: periodCalories,
      );

      print('✅ Chart data loaded successfully');
    } catch (e) {
      print('❌ Error loading chart data: $e');
    } finally {
      isLoadingChartData.value = false;
    }
  }

  /// Generate chart data based on the filter period
  Future<void> _generateChartData(
    String filter, {
    int? periodSteps,
    double? periodDistance,
    int? periodActiveTime,
    int? periodCalories,
  }) async {
    final now = DateTime.now();
    final DateFormat timeFormat = DateFormat('HH:mm');
    final DateFormat dateFormat = DateFormat('MMM dd');

    // Determine number of data points and time interval based on filter
    final int dataPoints = _getDataPointsCount(filter);
    final DateTime startDate = _getStartDate(filter, now);

    // Generate Speed Data (km/h)
    // Speed = Distance / Time (assuming average walking speed 4-5 km/h)
    for (int i = 0; i < dataPoints; i++) {
      final DateTime timestamp = _getTimestampForDataPoint(startDate, now, i, dataPoints, filter);

      // Calculate speed based on average walking patterns
      final double baseSpeed = 4.5; // Average walking speed
      final double variation = (i % 3 == 0) ? 0.5 : -0.3; // Add variation
      final double speed = (baseSpeed + variation + (i * 0.1 % 1.0)).clamp(0.0, 6.0);

      speedData.add(ChartDataPoint(
        timestamp: timestamp,
        value: speed,
        label: filter == 'Today' ? timeFormat.format(timestamp) : dateFormat.format(timestamp),
      ));
    }

    // Generate Distance Data (km)
    // Progressive accumulation throughout the day/period
    double cumulativeDistance = 0.0;
    final double totalDistance = periodDistance ?? 2.5;
    final double distanceIncrement = totalDistance / dataPoints;

    // Generate Time Data (minutes)
    // Active time distribution throughout the day/period
    final int totalTime = periodActiveTime ?? 45;
    final double timeIncrement = totalTime / dataPoints;

    for (int i = 0; i < dataPoints; i++) {
      final DateTime timestamp = _getTimestampForDataPoint(startDate, now, i, dataPoints, filter);
      final double activeMinutes = timeIncrement * (0.7 + (i % 4) * 0.2); // Variable activity

      timeData.add(ChartDataPoint(
        timestamp: timestamp,
        value: activeMinutes,
        label: filter == 'Today' ? timeFormat.format(timestamp) : dateFormat.format(timestamp),
      ));
    }

    // Generate Calories Data (kcal)
    // Correlates with distance and activity
    final int totalCalories = periodCalories ?? 180;
    double cumulativeCalories = 0.0;
    final double caloriesIncrement = totalCalories / dataPoints;

    for (int i = 0; i < dataPoints; i++) {
      final DateTime timestamp = _getTimestampForDataPoint(startDate, now, i, dataPoints, filter);
      cumulativeCalories += caloriesIncrement * (0.85 + (i % 3) * 0.1);

      caloriesData.add(ChartDataPoint(
        timestamp: timestamp,
        value: cumulativeCalories.clamp(0.0, totalCalories.toDouble()),
        label: filter == 'Today' ? timeFormat.format(timestamp) : dateFormat.format(timestamp),
      ));
    }

    print('📊 Generated ${speedData.length} data points for each chart type');
  }

  /// Get number of data points based on filter
  int _getDataPointsCount(String filter) {
    switch (filter) {
      case 'Today':
        return 12; // Hourly data (every 2 hours)
      case 'Yesterday':
        return 12; // Hourly data
      case 'Last 7 days':
        return 7; // Daily data
      case 'Last 30 days':
        return 15; // Every 2 days
      case 'Last 60 days':
        return 20; // Every 3 days
      case 'Last 90 days':
        return 30; // Every 3 days
      case 'All time':
        return 30; // Weekly or monthly aggregates
      default:
        return 10;
    }
  }

  /// Get start date based on filter
  DateTime _getStartDate(String filter, DateTime now) {
    switch (filter) {
      case 'Today':
        return DateTime(now.year, now.month, now.day, 0, 0);
      case 'Yesterday':
        return DateTime(now.year, now.month, now.day - 1, 0, 0);
      case 'Last 7 days':
        return now.subtract(const Duration(days: 6));
      case 'Last 30 days':
        return now.subtract(const Duration(days: 29));
      case 'Last 60 days':
        return now.subtract(const Duration(days: 59));
      case 'Last 90 days':
        return now.subtract(const Duration(days: 89));
      case 'All time':
        return now.subtract(const Duration(days: 365)); // Last year
      default:
        return now.subtract(const Duration(days: 1));
    }
  }

  /// Get timestamp for a specific data point
  DateTime _getTimestampForDataPoint(
    DateTime startDate,
    DateTime endDate,
    int index,
    int totalPoints,
    String filter,
  ) {
    if (filter == 'Today' || filter == 'Yesterday') {
      // Hourly distribution (every 2 hours)
      return startDate.add(Duration(hours: index * 2));
    } else {
      // Daily distribution
      final Duration totalDuration = endDate.difference(startDate);
      final Duration interval = Duration(
        milliseconds: totalDuration.inMilliseconds ~/ (totalPoints - 1),
      );
      return startDate.add(interval * index);
    }
  }

  /// Update selected chart type
  void selectChartType(String chartType) {
    if (chartTypes.contains(chartType)) {
      selectedChartType.value = chartType;
      print('📊 Chart type changed to: $chartType');
    }
  }

  @override
  void onClose() {
    print('🗑️ StatisticsChartsController: Disposed');
    super.onClose();
  }
}
