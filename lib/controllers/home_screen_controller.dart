import 'dart:async';
import 'dart:developer';
import 'package:get/get.dart';
import '../models/step_models.dart';

/// Home screen controller with Firebase streams and comprehensive step tracking
/// Provides reactive UI data for home screen with real-time updates
class HomeScreenController extends GetxController {
  static HomeScreenController get instance => Get.find<HomeScreenController>();



  // Current step data (reactive)
  final RxInt todaySteps = 0.obs;
  final RxInt weekSteps = 0.obs;
  final RxInt monthSteps = 0.obs;
  final RxInt bestDaySteps = 0.obs;
  final RxDouble todayDistance = 0.0.obs;
  final RxInt todayCalories = 0.obs;
  final RxInt activeMinutes = 0.obs;
  final RxDouble averageSpeed = 0.0.obs;

  // Race-specific data
  final RxInt preRaceSteps = 0.obs;
  final RxInt raceSteps = 0.obs;
  final RxBool hasActiveRaces = false.obs;
  final RxInt activeRaceCount = 0.obs;

  // UI state management
  final RxString selectedPeriod = 'today'.obs;
  final RxBool isLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final RxString loadingStatus = 'Initializing...'.obs;
  final RxString lastError = ''.obs;

  // Sync and connection status
  final RxBool isOnline = false.obs;
  final RxBool isSyncing = false.obs;
  final RxString syncStatus = 'Unknown'.obs;
  final RxBool backgroundActive = false.obs;

  // Statistics for different periods
  final Rx<StepStatistics?> todayStats = Rx<StepStatistics?>(null);
  final Rx<StepStatistics?> weekStats = Rx<StepStatistics?>(null);
  final Rx<StepStatistics?> monthStats = Rx<StepStatistics?>(null);

  // Stream subscriptions for cleanup
  final List<StreamSubscription> _subscriptions = [];

  // Period calculations
  DateTime get todayStart => DateTime.now().startOfDay;
  DateTime get weekStart => DateTime.now().startOfWeek;
  DateTime get monthStart => DateTime.now().startOfMonth;

  @override
  void onClose() {
    _cleanup();
    super.onClose();
  }







  /// Update current period data based on selected period
  void _updateCurrentPeriodData() {
    switch (selectedPeriod.value) {
      case 'today':
        // Today data is already updated via step tracker listeners
        break;
      case 'week':
        // Week data is updated via statistics
        break;
      case 'month':
        // Month data is updated via statistics
        break;
    }
  }


  /// Change selected period (today/week/month)
  void changePeriod(String period) {
    if (['today', 'week', 'month'].contains(period)) {
      selectedPeriod.value = period;
      _updateCurrentPeriodData();
      log('📊 [HOME_CONTROLLER] Period changed to: $period');
    }
  }



  /// Get current period statistics
  StepStatistics? getCurrentPeriodStatistics() {
    switch (selectedPeriod.value) {
      case 'today':
        return todayStats.value;
      case 'week':
        return weekStats.value;
      case 'month':
        return monthStats.value;
      default:
        return todayStats.value;
    }
  }

  /// Get current period steps
  int getCurrentPeriodSteps() {
    switch (selectedPeriod.value) {
      case 'today':
        return todaySteps.value;
      case 'week':
        return weekSteps.value;
      case 'month':
        return monthSteps.value;
      default:
        return todaySteps.value;
    }
  }

  /// Get formatted current period steps
  String getFormattedCurrentPeriodSteps() {
    return getCurrentPeriodSteps().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  /// Get current period goal progress (0.0 to 1.0)
  double getCurrentPeriodGoalProgress() {
    final steps = getCurrentPeriodSteps();
    const dailyGoal = 10000;

    switch (selectedPeriod.value) {
      case 'today':
        return (steps / dailyGoal).clamp(0.0, 1.0);
      case 'week':
        return (steps / (dailyGoal * 7)).clamp(0.0, 1.0);
      case 'month':
        final daysInMonth = DateTime.now().daysInMonth;
        return (steps / (dailyGoal * daysInMonth)).clamp(0.0, 1.0);
      default:
        return (steps / dailyGoal).clamp(0.0, 1.0);
    }
  }

  /// Get status summary for UI
  Map<String, dynamic> getStatusSummary() {
    return {
      'isInitialized': !isLoading.value,
      'loadingStatus': loadingStatus.value,
      'selectedPeriod': selectedPeriod.value,
      'isOnline': isOnline.value,
      'isSyncing': isSyncing.value,
      'syncStatus': syncStatus.value,
      'backgroundActive': backgroundActive.value,
      'hasActiveRaces': hasActiveRaces.value,
      'activeRaceCount': activeRaceCount.value,
      'isRefreshing': isRefreshing.value,
      'lastError': lastError.value,
      'currentSteps': getCurrentPeriodSteps(),
      'goalProgress': getCurrentPeriodGoalProgress(),
    };
  }

  /// Get health summary for UI
  Map<String, dynamic> getHealthSummary() {
    return {
      'todaySteps': todaySteps.value,
      'todayDistance': todayDistance.value,
      'todayCalories': todayCalories.value,
      'activeMinutes': activeMinutes.value,
      'averageSpeed': averageSpeed.value,
      'formattedSteps': getFormattedCurrentPeriodSteps(),
      'formattedDistance': '${todayDistance.value.toStringAsFixed(2)} km',
      'formattedCalories': '${todayCalories.value} cal',
      'formattedActiveTime': _formatActiveTime(activeMinutes.value),
      'formattedSpeed': '${averageSpeed.value.toStringAsFixed(1)} km/h',
    };
  }

  /// Get race summary for UI
  Map<String, dynamic> getRaceSummary() {
    return {
      'hasActiveRaces': hasActiveRaces.value,
      'activeRaceCount': activeRaceCount.value,
      'preRaceSteps': preRaceSteps.value,
      'raceSteps': raceSteps.value,
      'formattedPreRaceSteps': preRaceSteps.value.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      ),
      'formattedRaceSteps': raceSteps.value.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      ),
    };
  }

  /// Format active time
  String _formatActiveTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
  }

  /// Cleanup resources
  void _cleanup() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    log('🗑️ [HOME_CONTROLLER] Home screen controller cleanup completed');
  }
}

/// DateTime extensions for period calculations
extension DateTimeExtensions on DateTime {
  DateTime get startOfDay => DateTime(year, month, day);

  DateTime get startOfWeek {
    final daysFromMonday = weekday - 1;
    return subtract(Duration(days: daysFromMonday)).startOfDay;
  }

  DateTime get startOfMonth => DateTime(year, month, 1);

  int get daysInMonth {
    final firstDayNextMonth = DateTime(year, month + 1, 1);
    final lastDayThisMonth = firstDayNextMonth.subtract(Duration(days: 1));
    return lastDayThisMonth.day;
  }
}