import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'local_notification_service.dart';
import 'firebase_push_notification_service.dart';

class PermissionManager {
  static bool _isRequestingPermissions = false;
  static final List<Function> _pendingRequests = [];

  /// Request ONLY critical Motion & Fitness permission for step tracking
  /// This is the minimum permission needed for the app to function
  /// Returns true if permission is granted, false otherwise
  static Future<bool> requestCriticalMotionPermission() async {
    if (_isRequestingPermissions) {
      print('⏳ Permission request already in progress, waiting...');
      return false;
    }

    _isRequestingPermissions = true;
    print('🏃 Requesting critical Motion & Fitness permission...');

    bool isGranted = false;

    try {
      if (Platform.isIOS) {
        // iOS: Request Motion & Fitness (Activity Recognition)
        final status = await Permission.activityRecognition.status;
        if (!status.isGranted) {
          print('📱 Requesting iOS Motion & Fitness permission...');
          final result = await Permission.activityRecognition.request();
          isGranted = result.isGranted;
          print('✅ Motion & Fitness permission: ${result.isGranted ? "Granted" : "Denied"}');
        } else {
          isGranted = true;
          print('✅ Motion & Fitness permission already granted');
        }
      } else {
        // Android: Request Activity Recognition
        final status = await Permission.activityRecognition.status;
        if (!status.isGranted) {
          print('📱 Requesting Android Activity Recognition permission...');
          final result = await Permission.activityRecognition.request();
          isGranted = result.isGranted;
          print('✅ Activity Recognition permission: ${result.isGranted ? "Granted" : "Denied"}');
        } else {
          isGranted = true;
          print('✅ Activity Recognition permission already granted');
        }
      }

      print('✅ Critical permission request completed: $isGranted');
      return isGranted;
    } catch (e) {
      print('❌ Error requesting critical permission: $e');
      return false;
    } finally {
      _isRequestingPermissions = false;
    }
  }

  /// Legacy method - kept for backward compatibility but not used at startup
  /// Sequential permission request to prevent "Can request only one set of permissions at a time" error
  @Deprecated('Use requestCriticalMotionPermission() at startup and request other permissions contextually')
  static Future<void> requestAllPermissions() async {
    if (_isRequestingPermissions) {
      print('⏳ Permission request already in progress, waiting...');
      return;
    }

    _isRequestingPermissions = true;
    print('🔐 Starting sequential permission requests...');

    try {
      // 1. First request notification permissions through LocalNotificationService
      print('📱 Step 1: Requesting local notification permissions...');
      await LocalNotificationService.createNotificationChannels();
      final localPermissions = await LocalNotificationService.requestPermissions();
      print('📱 Local notification permissions: $localPermissions');

      // Small delay to ensure the first request completes
      await Future.delayed(Duration(milliseconds: 500));

      // 2. Skip Firebase push notification initialization to prevent blocking
      // Initialize FCM in background later
      print('🔥 Step 2: Skipping Firebase initialization to prevent blocking...');
      _initializeFirebaseInBackground();

      print('✅ All permissions requested successfully');
    } catch (e) {
      print('❌ Error during permission requests: $e');
    } finally {
      _isRequestingPermissions = false;

      // Process any pending requests
      if (_pendingRequests.isNotEmpty) {
        print('📋 Processing ${_pendingRequests.length} pending permission requests...');
        final List<Function> requests = List.from(_pendingRequests);
        _pendingRequests.clear();

        for (final request in requests) {
          try {
            await request();
          } catch (e) {
            print('❌ Error in pending request: $e');
          }
        }
      }
    }
  }

  /// Queue a permission request if one is already in progress
  static Future<T> queuePermissionRequest<T>(Future<T> Function() request) async {
    if (!_isRequestingPermissions) {
      return await request();
    }

    // Add to pending queue
    final Completer<T> completer = Completer<T>();
    _pendingRequests.add(() async {
      try {
        final result = await request();
        completer.complete(result);
      } catch (e) {
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  /// Check if permissions are currently being requested
  static bool get isRequestingPermissions => _isRequestingPermissions;

  /// Initialize Firebase in background without blocking app startup
  static void _initializeFirebaseInBackground() {
    Future.delayed(Duration(seconds: 2), () async {
      try {
        print('🔥 Background: Initializing Firebase Push Notification Service...');
        await FirebasePushNotificationService.initialize().timeout(
          Duration(seconds: 30),
          onTimeout: () {
            print('⏰ Background Firebase initialization timed out');
          },
        );
        print('✅ Background Firebase initialization completed');
      } catch (e) {
        print('❌ Background Firebase initialization failed: $e');
      }
    });
  }

  /// Initialize all notification services in sequence
  static Future<void> initializeNotificationServices() async {
    print('🚀 Initializing notification services...');

    try {
      // Initialize Local Notifications first
      print('📱 Initializing LocalNotificationService...');
      await LocalNotificationService.initialize();

      // Small delay between initializations
      await Future.delayed(Duration(milliseconds: 300));

      print('✅ Notification services initialized successfully');
    } catch (e) {
      print('❌ Error initializing notification services: $e');
      rethrow;
    }
  }
}