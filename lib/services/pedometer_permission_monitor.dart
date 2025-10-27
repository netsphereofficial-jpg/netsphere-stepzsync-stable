import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/dialogs/pedometer_permission_dialog.dart';

/// Monitors pedometer/activity recognition permission continuously
/// Shows blocking dialog when permission is not granted
/// Follows market standards for iOS and Android
class PedometerPermissionMonitor extends GetxService {
  static PedometerPermissionMonitor get instance => Get.find();

  // Observable permission status
  final hasPermission = false.obs;
  final isPermanentlyDenied = false.obs;

  // Timer for periodic checks (fallback if lifecycle events don't fire)
  Timer? _periodicCheckTimer;

  // Prevent multiple simultaneous checks
  bool _isChecking = false;

  // Track if we're currently showing dialog
  bool get isDialogShowing => _dialogShowing;
  bool _dialogShowing = false;

  @override
  void onInit() {
    super.onInit();
    print('🔒 PedometerPermissionMonitor: Initializing...');

    // Initial permission check
    checkPermission();

    // Set up app lifecycle listener
    WidgetsBinding.instance.addObserver(_AppLifecycleListener(this));

    // Periodic check every 2 seconds as fallback
    // This ensures permission is checked even if lifecycle events miss
    _periodicCheckTimer = Timer.periodic(Duration(seconds: 2), (_) {
      checkPermission();
    });

    print('✅ PedometerPermissionMonitor: Initialized');
  }

  @override
  void onClose() {
    _periodicCheckTimer?.cancel();
    print('🔒 PedometerPermissionMonitor: Disposed');
    super.onClose();
  }

  /// Check current permission status and show dialog if needed
  Future<void> checkPermission() async {
    // Prevent concurrent checks
    if (_isChecking) return;

    try {
      _isChecking = true;

      // Android requires activity recognition permission
      // iOS doesn't require explicit permission for pedometer
      if (Platform.isAndroid) {
        final status = await Permission.activityRecognition.status;

        final wasGranted = hasPermission.value;
        hasPermission.value = status.isGranted;
        isPermanentlyDenied.value = status.isPermanentlyDenied;

        // Permission state changed
        if (status.isGranted && !wasGranted) {
          print('✅ Activity recognition permission granted');
          _hideDialogIfShowing();
        } else if (!status.isGranted) {
          print('⚠️ Activity recognition permission not granted (permanently denied: ${status.isPermanentlyDenied})');
          _showDialogIfNeeded();
        }
      } else {
        // iOS always has permission for pedometer
        hasPermission.value = true;
        isPermanentlyDenied.value = false;
        _hideDialogIfShowing();
      }
    } catch (e) {
      print('❌ Error checking pedometer permission: $e');
      hasPermission.value = false;
    } finally {
      _isChecking = false;
    }
  }

  /// Show dialog if permission not granted and dialog not already showing
  void _showDialogIfNeeded() {
    if (!_dialogShowing && !hasPermission.value) {
      _dialogShowing = true;
      PedometerPermissionDialog.show(
        isPermanentlyDenied: isPermanentlyDenied.value,
      );
    }
  }

  /// Hide dialog if currently showing
  void _hideDialogIfShowing() {
    if (_dialogShowing) {
      _dialogShowing = false;
      PedometerPermissionDialog.dismiss();
    }
  }

  /// Request permission (used by dialog buttons)
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.request();
      hasPermission.value = status.isGranted;
      isPermanentlyDenied.value = status.isPermanentlyDenied;

      if (status.isGranted) {
        print('✅ Activity recognition permission granted');
        _hideDialogIfShowing();
        return true;
      } else {
        print('❌ Activity recognition permission denied');
        if (status.isPermanentlyDenied) {
          print('⚠️ Permission permanently denied - user must enable in settings');
        }
        return false;
      }
    } else {
      // iOS doesn't need explicit permission
      hasPermission.value = true;
      return true;
    }
  }
}

/// App lifecycle observer to trigger permission checks
class _AppLifecycleListener extends WidgetsBindingObserver {
  final PedometerPermissionMonitor monitor;

  _AppLifecycleListener(this.monitor);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('📱 App lifecycle changed: $state');

    // Check permission when app resumes from background
    if (state == AppLifecycleState.resumed) {
      print('▶️ App resumed - checking pedometer permission...');
      monitor.checkPermission();
    }
  }
}
