import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_storage_service.dart';
import '../profile/profile_service.dart';

/// Service to handle profile image upload queue with retry logic and network recovery
class ProfileImageUploadQueue {
  static final ProfileImageUploadQueue _instance = ProfileImageUploadQueue._internal();
  factory ProfileImageUploadQueue() => _instance;
  ProfileImageUploadQueue._internal();

  // Upload state management
  final _uploadStateController = StreamController<UploadState>.broadcast();
  Stream<UploadState> get uploadStateStream => _uploadStateController.stream;

  UploadState? _currentUploadState;
  UploadState? get currentUploadState => _currentUploadState;

  Timer? _retryTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isProcessing = false;

  // Constants
  static const int maxRetries = 3;
  static const int retryDelaySeconds = 3;
  static const String _pendingUploadKey = 'pending_profile_image_upload';
  static const String _pendingImagePathKey = 'pending_profile_image_path';
  static const String _oldImageUrlKey = 'old_profile_image_url';

  /// Initialize the upload queue and check for pending uploads
  Future<void> initialize() async {
    // Listen to network connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      _onConnectivityChanged(results);
    });

    // Check for pending uploads on startup
    await _resumePendingUpload();
  }

  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
    _connectivitySubscription?.cancel();
    _uploadStateController.close();
  }

  /// Queue a new upload (replaces any pending upload)
  Future<void> queueUpload({
    required File imageFile,
    String? oldImageUrl,
    required Function(double) onProgress,
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      // Save upload state to preferences for recovery
      await _savePendingUpload(imageFile.path, oldImageUrl);

      // Create upload state
      _currentUploadState = UploadState(
        imageFile: imageFile,
        oldImageUrl: oldImageUrl,
        onProgress: onProgress,
        onSuccess: onSuccess,
        onError: onError,
        retryCount: 0,
        status: UploadStatus.uploading,
      );

      _uploadStateController.add(_currentUploadState!);

      // Start upload
      await _processUpload();
    } catch (e) {
      onError('Failed to queue upload: ${e.toString()}');
    }
  }

  /// Process the upload with retry logic
  Future<void> _processUpload() async {
    if (_isProcessing || _currentUploadState == null) return;

    _isProcessing = true;
    final state = _currentUploadState!;

    try {
      // Check network connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (!_hasNetworkConnectivity(connectivityResult)) {
        _handleNetworkError();
        return;
      }

      // Check authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _handleError('User not authenticated', isRecoverable: false);
        return;
      }

      // Attempt upload
      final result = await FirebaseStorageService.updateProfileImage(
        state.imageFile,
        state.oldImageUrl,
        onProgress: (progress) {
          state.onProgress(progress);
          _currentUploadState = state.copyWith(progress: progress);
          _uploadStateController.add(_currentUploadState!);
        },
      );

      if (result.success) {
        final downloadUrl = result.data as String;

        // Update profile picture in Firestore
        final updateResult = await ProfileService.updateProfileField(
          'profilePicture',
          downloadUrl,
        );

        if (updateResult.success) {
          // Update Firebase Auth profile
          await user.updatePhotoURL(downloadUrl);

          // Success! Clear pending upload
          await _clearPendingUpload();
          state.onSuccess(downloadUrl);

          _currentUploadState = state.copyWith(
            status: UploadStatus.success,
            downloadUrl: downloadUrl,
          );
          _uploadStateController.add(_currentUploadState!);

          // Clear state after success
          _currentUploadState = null;
        } else {
          throw Exception(updateResult.error ?? 'Failed to update profile');
        }
      } else {
        throw Exception(result.error ?? 'Upload failed');
      }
    } catch (e) {
      // Check if error is network-related
      if (_isNetworkError(e)) {
        _handleNetworkError();
      } else {
        // Check if we should retry
        if (state.retryCount < maxRetries) {
          _scheduleRetry();
        } else {
          _handleError('Upload failed after $maxRetries attempts: ${e.toString()}');
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Handle network connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (_currentUploadState?.status == UploadStatus.networkError) {
      if (_hasNetworkConnectivity(results)) {
        // Network restored, retry upload
        _retryUpload();
      }
    }
  }

  /// Check if we have network connectivity
  bool _hasNetworkConnectivity(List<ConnectivityResult> results) {
    return results.any((result) =>
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet
    );
  }

  /// Check if error is network-related
  bool _isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
           errorString.contains('connection') ||
           errorString.contains('timeout') ||
           errorString.contains('socket') ||
           errorString.contains('failed host lookup');
  }

  /// Handle network error
  void _handleNetworkError() {
    if (_currentUploadState == null) return;

    _currentUploadState = _currentUploadState!.copyWith(
      status: UploadStatus.networkError,
      errorMessage: 'No network connection. Will retry when network is available.',
    );
    _uploadStateController.add(_currentUploadState!);

    // Show user-friendly message
    _currentUploadState!.onError('No network connection. Upload will resume automatically when connected.');
  }

  /// Schedule a retry attempt
  void _scheduleRetry() {
    if (_currentUploadState == null) return;

    final state = _currentUploadState!;
    final newRetryCount = state.retryCount + 1;
    final delaySeconds = retryDelaySeconds * newRetryCount; // Exponential backoff

    _currentUploadState = state.copyWith(
      status: UploadStatus.retrying,
      retryCount: newRetryCount,
      errorMessage: 'Upload failed. Retrying in $delaySeconds seconds... (Attempt $newRetryCount/$maxRetries)',
    );
    _uploadStateController.add(_currentUploadState!);

    // Cancel any existing retry timer
    _retryTimer?.cancel();

    // Schedule retry
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      _retryUpload();
    });
  }

  /// Retry the upload
  Future<void> _retryUpload() async {
    if (_currentUploadState == null) return;

    _currentUploadState = _currentUploadState!.copyWith(
      status: UploadStatus.uploading,
      errorMessage: null,
    );
    _uploadStateController.add(_currentUploadState!);

    await _processUpload();
  }

  /// Handle unrecoverable error
  void _handleError(String message, {bool isRecoverable = true}) {
    if (_currentUploadState == null) return;

    _currentUploadState = _currentUploadState!.copyWith(
      status: UploadStatus.failed,
      errorMessage: message,
    );
    _uploadStateController.add(_currentUploadState!);

    _currentUploadState!.onError(message);

    // Clear state and pending upload on unrecoverable errors
    if (!isRecoverable) {
      _clearPendingUpload();
      _currentUploadState = null;
    }
  }

  /// Save pending upload to SharedPreferences for recovery
  Future<void> _savePendingUpload(String imagePath, String? oldImageUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingImagePathKey, imagePath);
      if (oldImageUrl != null) {
        await prefs.setString(_oldImageUrlKey, oldImageUrl);
      }
      await prefs.setBool(_pendingUploadKey, true);
    } catch (e) {
      print('Failed to save pending upload: $e');
    }
  }

  /// Clear pending upload from SharedPreferences
  Future<void> _clearPendingUpload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingImagePathKey);
      await prefs.remove(_oldImageUrlKey);
      await prefs.remove(_pendingUploadKey);
    } catch (e) {
      print('Failed to clear pending upload: $e');
    }
  }

  /// Resume pending upload from SharedPreferences (app restart recovery)
  Future<void> _resumePendingUpload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPendingUpload = prefs.getBool(_pendingUploadKey) ?? false;

      if (!hasPendingUpload) return;

      final imagePath = prefs.getString(_pendingImagePathKey);
      final oldImageUrl = prefs.getString(_oldImageUrlKey);

      if (imagePath == null) {
        await _clearPendingUpload();
        return;
      }

      // Check if file still exists
      final file = File(imagePath);
      if (!await file.exists()) {
        await _clearPendingUpload();
        return;
      }

      // Resume upload with default callbacks (no UI updates during background recovery)
      await queueUpload(
        imageFile: file,
        oldImageUrl: oldImageUrl,
        onProgress: (_) {}, // Silent progress during recovery
        onSuccess: (_) {
          print('Background upload completed successfully');
        },
        onError: (error) {
          print('Background upload failed: $error');
        },
      );
    } catch (e) {
      print('Failed to resume pending upload: $e');
      await _clearPendingUpload();
    }
  }

  /// Cancel current upload
  Future<void> cancelUpload() async {
    _retryTimer?.cancel();
    await _clearPendingUpload();

    if (_currentUploadState != null) {
      _currentUploadState = _currentUploadState!.copyWith(
        status: UploadStatus.cancelled,
        errorMessage: 'Upload cancelled by user',
      );
      _uploadStateController.add(_currentUploadState!);
      _currentUploadState = null;
    }
  }
}

/// Upload status enum
enum UploadStatus {
  uploading,
  retrying,
  networkError,
  success,
  failed,
  cancelled,
}

/// Upload state class
class UploadState {
  final File imageFile;
  final String? oldImageUrl;
  final Function(double) onProgress;
  final Function(String) onSuccess;
  final Function(String) onError;
  final int retryCount;
  final UploadStatus status;
  final double progress;
  final String? errorMessage;
  final String? downloadUrl;

  UploadState({
    required this.imageFile,
    this.oldImageUrl,
    required this.onProgress,
    required this.onSuccess,
    required this.onError,
    required this.retryCount,
    required this.status,
    this.progress = 0.0,
    this.errorMessage,
    this.downloadUrl,
  });

  UploadState copyWith({
    File? imageFile,
    String? oldImageUrl,
    Function(double)? onProgress,
    Function(String)? onSuccess,
    Function(String)? onError,
    int? retryCount,
    UploadStatus? status,
    double? progress,
    String? errorMessage,
    String? downloadUrl,
  }) {
    return UploadState(
      imageFile: imageFile ?? this.imageFile,
      oldImageUrl: oldImageUrl ?? this.oldImageUrl,
      onProgress: onProgress ?? this.onProgress,
      onSuccess: onSuccess ?? this.onSuccess,
      onError: onError ?? this.onError,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }

  String get statusMessage {
    switch (status) {
      case UploadStatus.uploading:
        return 'Uploading... ${(progress * 100).toInt()}%';
      case UploadStatus.retrying:
        return errorMessage ?? 'Retrying...';
      case UploadStatus.networkError:
        return 'Waiting for network...';
      case UploadStatus.success:
        return 'Upload complete!';
      case UploadStatus.failed:
        return errorMessage ?? 'Upload failed';
      case UploadStatus.cancelled:
        return 'Upload cancelled';
    }
  }

  bool get canRetry => status == UploadStatus.failed && retryCount < ProfileImageUploadQueue.maxRetries;
}
