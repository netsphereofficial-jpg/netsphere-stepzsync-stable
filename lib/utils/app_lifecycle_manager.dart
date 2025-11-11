import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App lifecycle manager to detect cold starts and app state changes
///
/// Helps distinguish between:
/// - Cold start: App was completely killed and reopened
/// - Hot resume: App was in background and brought to foreground
class AppLifecycleManager with WidgetsBindingObserver {
  static final AppLifecycleManager _instance = AppLifecycleManager._internal();
  factory AppLifecycleManager() => _instance;
  AppLifecycleManager._internal();

  // Observable app lifecycle state
  final Rx<AppLifecycleState> currentState = AppLifecycleState.resumed.obs;
  final RxBool isColdStart = true.obs;
  final RxBool isFirstLaunchToday = false.obs;

  // Callbacks for lifecycle events
  final List<VoidCallback> _onColdStartCallbacks = [];
  final List<VoidCallback> _onResumeCallbacks = [];
  final List<VoidCallback> _onPauseCallbacks = [];

  DateTime? _lastResumeTime;
  DateTime? _lastPauseTime;
  bool _isInitialized = false;

  static const String _kLastLaunchDateKey = 'last_launch_date';
  static const String _kAppSessionActiveKey = 'app_session_active';

  /// Initialize the lifecycle manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Register as observer
    WidgetsBinding.instance.addObserver(this);

    // Check if this is a cold start
    await _checkColdStart();

    _isInitialized = true;
  }

  /// Check if this is a cold start (app was killed and reopened)
  Future<void> _checkColdStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if app session was properly closed
      final wasSessionActive = prefs.getBool(_kAppSessionActiveKey) ?? false;

      if (wasSessionActive) {
        // App was killed while running (cold start)
        isColdStart.value = true;
      } else {
        // App was properly closed
        isColdStart.value = true;
      }

      // Check if first launch today
      final lastLaunchDateStr = prefs.getString(_kLastLaunchDateKey);
      if (lastLaunchDateStr != null) {
        final lastLaunchDate = DateTime.parse(lastLaunchDateStr);
        final today = DateTime.now();

        final isToday = lastLaunchDate.year == today.year &&
            lastLaunchDate.month == today.month &&
            lastLaunchDate.day == today.day;

        isFirstLaunchToday.value = !isToday;
      } else {
        isFirstLaunchToday.value = true;
      }

      // Mark session as active
      await prefs.setBool(_kAppSessionActiveKey, true);
      await prefs.setString(_kLastLaunchDateKey, DateTime.now().toIso8601String());

    } catch (e) {
      isColdStart.value = true; // Default to cold start on error
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previousState = currentState.value;
    currentState.value = state;


    switch (state) {
      case AppLifecycleState.resumed:
        _handleResume(previousState);
        break;
      case AppLifecycleState.inactive:
        _handleInactive();
        break;
      case AppLifecycleState.paused:
        _handlePause();
        break;
      case AppLifecycleState.detached:
        _handleDetached();
        break;
      case AppLifecycleState.hidden:
        // New state in Flutter 3.13+
        break;
    }
  }

  void _handleResume(AppLifecycleState previousState) {
    _lastResumeTime = DateTime.now();

    // Determine if this is a cold start or hot resume
    if (isColdStart.value) {
      _triggerColdStartCallbacks();
      isColdStart.value = false; // Reset after first resume
    } else {

      // Check if app was paused for more than 30 minutes
      if (_lastPauseTime != null) {
        final pauseDuration = _lastResumeTime!.difference(_lastPauseTime!);
        if (pauseDuration.inMinutes > 30) {
          _triggerColdStartCallbacks();
        } else {
        }
      }

      _triggerResumeCallbacks();
    }
  }

  void _handleInactive() {
  }

  void _handlePause() {
    _lastPauseTime = DateTime.now();
    _triggerPauseCallbacks();
  }

  void _handleDetached() async {

    // Mark session as inactive
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAppSessionActiveKey, false);
    } catch (e) {
    }
  }

  /// Register callback for cold start events
  void registerColdStartCallback(VoidCallback callback) {
    _onColdStartCallbacks.add(callback);

    // If this is a cold start and app is already resumed, trigger callback immediately
    // but DON'T reset isColdStart flag here, let other callbacks register too
    if (isColdStart.value && currentState.value == AppLifecycleState.resumed) {
      try {
        callback();
      } catch (e) {
      }
    }
  }

  /// Register callback for resume events
  void registerResumeCallback(VoidCallback callback) {
    _onResumeCallbacks.add(callback);
  }

  /// Register callback for pause events
  void registerPauseCallback(VoidCallback callback) {
    _onPauseCallbacks.add(callback);
  }

  /// Unregister callbacks
  void unregisterColdStartCallback(VoidCallback callback) {
    _onColdStartCallbacks.remove(callback);
  }

  void unregisterResumeCallback(VoidCallback callback) {
    _onResumeCallbacks.remove(callback);
  }

  void unregisterPauseCallback(VoidCallback callback) {
    _onPauseCallbacks.remove(callback);
  }

  void _triggerColdStartCallbacks() {
    for (final callback in _onColdStartCallbacks) {
      try {
        callback();
      } catch (e) {
      }
    }
  }

  void _triggerResumeCallbacks() {
    for (final callback in _onResumeCallbacks) {
      try {
        callback();
      } catch (e) {
      }
    }
  }

  void _triggerPauseCallbacks() {
    for (final callback in _onPauseCallbacks) {
      try {
        callback();
      } catch (e) {
      }
    }
  }

  /// Check if enough time has passed since last resume to warrant a sync
  bool shouldTriggerSync({Duration minInterval = const Duration(hours: 6)}) {
    if (_lastResumeTime == null) return true;

    final now = DateTime.now();
    final timeSinceResume = now.difference(_lastResumeTime!);

    return timeSinceResume >= minInterval;
  }

  /// Manually mark that a cold start event was handled
  void markColdStartHandled() {
    isColdStart.value = false;
  }

  /// Dispose the manager
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onColdStartCallbacks.clear();
    _onResumeCallbacks.clear();
    _onPauseCallbacks.clear();
    _isInitialized = false;
  }
}
