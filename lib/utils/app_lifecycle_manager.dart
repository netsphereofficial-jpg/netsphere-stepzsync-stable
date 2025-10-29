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
    print('🔄 [LIFECYCLE] App lifecycle manager initialized');
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
        print('🔄 [LIFECYCLE] Cold start detected (app was killed)');
      } else {
        // App was properly closed
        isColdStart.value = true;
        print('🔄 [LIFECYCLE] Cold start detected (normal launch)');
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

      print('🔄 [LIFECYCLE] First launch today: ${isFirstLaunchToday.value}');
    } catch (e) {
      print('🔄 [LIFECYCLE] Error checking cold start: $e');
      isColdStart.value = true; // Default to cold start on error
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previousState = currentState.value;
    currentState.value = state;

    print('🔄 [LIFECYCLE] State changed: $previousState → $state');

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
      print('🔄 [LIFECYCLE] App resumed from cold start');
      _triggerColdStartCallbacks();
      isColdStart.value = false; // Reset after first resume
    } else {
      print('🔄 [LIFECYCLE] App resumed from background');

      // Check if app was paused for more than 30 minutes
      if (_lastPauseTime != null) {
        final pauseDuration = _lastResumeTime!.difference(_lastPauseTime!);
        if (pauseDuration.inMinutes > 30) {
          print('🔄 [LIFECYCLE] App was paused for ${pauseDuration.inMinutes} minutes (treat as cold start)');
          _triggerColdStartCallbacks();
        } else {
          print('🔄 [LIFECYCLE] App was paused for ${pauseDuration.inSeconds} seconds');
        }
      }

      _triggerResumeCallbacks();
    }
  }

  void _handleInactive() {
    print('🔄 [LIFECYCLE] App became inactive');
  }

  void _handlePause() {
    _lastPauseTime = DateTime.now();
    print('🔄 [LIFECYCLE] App paused at ${_lastPauseTime}');
    _triggerPauseCallbacks();
  }

  void _handleDetached() async {
    print('🔄 [LIFECYCLE] App detached (closing)');

    // Mark session as inactive
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAppSessionActiveKey, false);
    } catch (e) {
      print('🔄 [LIFECYCLE] Error marking session inactive: $e');
    }
  }

  /// Register callback for cold start events
  void registerColdStartCallback(VoidCallback callback) {
    _onColdStartCallbacks.add(callback);
    print('🔄 [LIFECYCLE] Registered cold start callback (${_onColdStartCallbacks.length} total)');

    // If this is a cold start and app is already resumed, trigger callback immediately
    // but DON'T reset isColdStart flag here, let other callbacks register too
    if (isColdStart.value && currentState.value == AppLifecycleState.resumed) {
      print('🔄 [LIFECYCLE] App already resumed - will trigger callback immediately');
      try {
        callback();
      } catch (e) {
        print('🔄 [LIFECYCLE] Error in immediate cold start callback: $e');
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
    print('🔄 [LIFECYCLE] Triggering ${_onColdStartCallbacks.length} cold start callbacks');
    for (final callback in _onColdStartCallbacks) {
      try {
        callback();
      } catch (e) {
        print('🔄 [LIFECYCLE] Error in cold start callback: $e');
      }
    }
  }

  void _triggerResumeCallbacks() {
    for (final callback in _onResumeCallbacks) {
      try {
        callback();
      } catch (e) {
        print('🔄 [LIFECYCLE] Error in resume callback: $e');
      }
    }
  }

  void _triggerPauseCallbacks() {
    for (final callback in _onPauseCallbacks) {
      try {
        callback();
      } catch (e) {
        print('🔄 [LIFECYCLE] Error in pause callback: $e');
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
    print('🔄 [LIFECYCLE] App lifecycle manager disposed');
  }
}
