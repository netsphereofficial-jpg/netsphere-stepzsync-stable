import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screens/home_screen/home_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../widgets/custom_progress_indicator.dart';
import '../services/profile/profile_service.dart';
import '../models/profile_models.dart';
import '../controllers/profile/profile_controller.dart';
import 'preferences_service.dart';
import 'firebase_service.dart';
import 'firebase_push_notification_service.dart';

/// Simplified AuthWrapper - Market Standard
/// Based on research: Firebase best practices, TikTok/Instagram pattern
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();

  /// Static method to clear auth cache from outside
  static void clearCache() {
    _AuthWrapperState.clearCache();
  }
}

class _AuthWrapperState extends State<AuthWrapper> {
  // Minimal caching - only profile completion status
  static bool? _cachedProfileCompleted;
  static String? _cachedUserId;

  // Lock to prevent duplicate profile creation attempts
  static Future<AuthFlowState>? _pendingAuthFlow;
  static String? _pendingUserId;

  @override
  Widget build(BuildContext context) {
    final firebaseService = Get.find<FirebaseService>();

    return StreamBuilder<User?>(
      stream: firebaseService.getAuthStateChanges(),
      builder: (context, authSnapshot) {
        debugPrint('🔍 [AUTH_DEBUG] ========== AUTH STATE CHECK ==========');
        debugPrint('🔍 [AUTH_DEBUG] StreamBuilder triggered');
        debugPrint('🔍 [AUTH_DEBUG] Connection state: ${authSnapshot.connectionState}');
        debugPrint('🔍 [AUTH_DEBUG] Has data: ${authSnapshot.hasData}');
        debugPrint('🔍 [AUTH_DEBUG] Has error: ${authSnapshot.hasError}');
        if (authSnapshot.hasError) {
          debugPrint('🔍 [AUTH_DEBUG] Error: ${authSnapshot.error}');
        }
        debugPrint('🔍 [AUTH_DEBUG] User UID: ${authSnapshot.data?.uid}');
        debugPrint('🔍 [AUTH_DEBUG] User email: ${authSnapshot.data?.email}');
        debugPrint('🔍 [AUTH_DEBUG] User is anonymous: ${authSnapshot.data?.isAnonymous}');
        debugPrint('🔍 [AUTH_DEBUG] =====================================');

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          debugPrint('🔍 [AUTH_DEBUG] ⏳ Waiting for auth state...');
          return _buildLoadingScreen();
        }

        return _buildAppFlowOptimized(authSnapshot.data);
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.black, Colors.grey[900]!, Colors.black87],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: const Center(
          child: CustomProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildAppFlowOptimized(User? user) {
    return FutureBuilder<AuthFlowState>(
      future: _getAuthFlowState(user),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        if (snapshot.hasError) {
          debugPrint('❌ AuthWrapper error: ${snapshot.error}');
          // Fallback to safe state
          if (user != null) {
            if (!Get.isRegistered<ProfileController>()) {
              Get.put(ProfileController(), permanent: true);
            }
            return ProfileScreen();
          }
          return SplashScreen();
        }

        final state = snapshot.data;
        if (state == null) {
          if (user != null) {
            if (!Get.isRegistered<ProfileController>()) {
              Get.put(ProfileController(), permanent: true);
            }
            return ProfileScreen();
          }
          return SplashScreen();
        }

        switch (state.destination) {
          case AuthDestination.splash:
            return SplashScreen();
          case AuthDestination.login:
            return LoginScreen();
          case AuthDestination.profile:
            if (!Get.isRegistered<ProfileController>()) {
              Get.put(ProfileController(), permanent: true);
            }
            return ProfileScreen();
          case AuthDestination.home:
            return HomeScreen();
        }
      },
    );
  }

  /// Simplified auth flow - Market standard (TikTok/Instagram pattern)
  Future<AuthFlowState> _getAuthFlowState(User? user) async {
    try {
      // Prevent duplicate concurrent calls for same user
      if (_pendingAuthFlow != null && _pendingUserId == user?.uid) {
        debugPrint('⏳ Auth flow already in progress, waiting...');
        return await _pendingAuthFlow!;
      }

      // Start new auth flow
      _pendingUserId = user?.uid;
      _pendingAuthFlow = _performAuthFlow(user);

      try {
        final result = await _pendingAuthFlow!;
        return result;
      } finally {
        // Clear pending flow after completion
        _pendingAuthFlow = null;
        _pendingUserId = null;
      }
    } catch (e) {
      debugPrint('❌ Error in getAuthFlowState: $e');
      _pendingAuthFlow = null;
      _pendingUserId = null;
      // Fallback to safe state
      return user != null
          ? AuthFlowState(AuthDestination.profile)
          : AuthFlowState(AuthDestination.login);
    }
  }

  /// Perform actual auth flow logic
  Future<AuthFlowState> _performAuthFlow(User? user) async {
    // No user → Login
    if (user == null) {
      debugPrint('🔍 [AUTH_DEBUG] No user logged in → Login screen');
      return AuthFlowState(AuthDestination.login);
    }

    debugPrint('🔍 [AUTH_DEBUG] User logged in: ${user.uid} (isAnonymous: ${user.isAnonymous})');

    // Guest users → Check/create profile, then home
    if (user.isAnonymous) {
      debugPrint('👤 Guest user detected - checking profile...');

      // Check if profile exists
      final profileExists = await ProfileService.profileDocumentExists();

      if (!profileExists) {
        debugPrint('🔧 Creating guest profile...');
        await _createInitialProfileOptimized(user);
      }

      // Save FCM token to Firestore now that user is authenticated (non-blocking)
      FirebasePushNotificationService.saveCurrentTokenToFirestore().catchError((e) {
        debugPrint('⚠️ Failed to save FCM token for guest: $e');
      });

      debugPrint('✅ Guest profile ready - allowing access to home');
      return AuthFlowState(AuthDestination.home);
    }

    // EMAIL VERIFICATION REMOVED
    // Users can now use the app without email verification
    // Email verification is no longer required for a better user experience

    // Check profile completion with minimal caching
    final profileState = await _getProfileState(user);
    debugPrint('🔍 [AUTH_DEBUG] Profile state destination: ${profileState.destination}');
    return profileState;
  }

  /// Simplified profile checking with minimal caching and race condition fixes
  Future<AuthFlowState> _getProfileState(User user) async {
    try {
      // CACHE FIX: Always clear cache for fresh check to avoid stale data
      // This prevents navigation loops and ensures accurate profile status
      if (_cachedUserId != user.uid) {
        _clearCache();
      }

      // Check if profile exists
      final profileExists = await ProfileService.profileDocumentExists();

      // Create profile if it doesn't exist
      if (!profileExists) {
        debugPrint('🔧 Creating initial profile...');
        await _createInitialProfileOptimized(user);

        // Update cache
        _cachedUserId = user.uid;
        _cachedProfileCompleted = false; // New profiles are incomplete

        return AuthFlowState(AuthDestination.profile);
      }

      // Check if profile is completed
      final isProfileCompleted = await ProfileService.isProfileCompleted();
      debugPrint('📋 Profile completion status (fresh check): $isProfileCompleted');

      // Save FCM token to Firestore now that user is authenticated (non-blocking)
      FirebasePushNotificationService.saveCurrentTokenToFirestore().catchError((e) {
        debugPrint('⚠️ Failed to save FCM token: $e');
      });

      // Update cache
      _cachedUserId = user.uid;
      _cachedProfileCompleted = isProfileCompleted;

      final destination = isProfileCompleted ? AuthDestination.home : AuthDestination.profile;
      debugPrint('🔍 [AUTH_DEBUG] Navigating to: $destination (profileCompleted: $isProfileCompleted)');

      return AuthFlowState(destination);
    } catch (e) {
      debugPrint('❌ Error checking profile state: $e');
      _clearCache();
      return AuthFlowState(AuthDestination.profile);
    }
  }

  /// Optimized profile creation with minimal Firebase calls
  Future<void> _createInitialProfileOptimized(User user) async {
    try {
      // Check if this is a guest (anonymous) user
      final isGuest = user.isAnonymous;

      // Generate a random guest name if anonymous user
      String guestName = '';
      if (isGuest) {
        final randomId = user.uid.substring(0, 6).toUpperCase();
        guestName = 'Guest_$randomId';
        debugPrint('🎭 Creating guest profile: $guestName');
      }

      final initialProfile = UserProfile(
        email: user.email ?? '',
        fullName: isGuest ? guestName : (user.displayName ?? ''),
        phoneNumber: user.phoneNumber ?? '',
        countryCode: '+91',
        gender: '',
        location: '',
        height: 0,
        heightUnit: 'cms',
        weight: 0,
        weightUnit: 'Kgs',
        // Guest users: mark profile as completed so they can access home screen
        // Regular users: keep as incomplete to force profile setup
        profileCompleted: isGuest,
        healthKitEnabled: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await ProfileService.saveInitialProfile(initialProfile);

      if (result.success) {
        debugPrint('✅ Initial profile created successfully ${isGuest ? "(Guest)" : ""}');
      } else {
        debugPrint('❌ Profile creation failed: ${result.error}');
      }
    } catch (e) {
      debugPrint('❌ Failed to create initial profile: $e');
      rethrow;
    }
  }

  /// Clear cache when needed (make public for external access)
  static void clearCache() {
    _cachedProfileCompleted = null;
    _cachedUserId = null;
    _pendingAuthFlow = null;
    _pendingUserId = null;
    debugPrint('🗑️ Auth cache cleared');
  }

  /// Private method for internal use
  static void _clearCache() {
    clearCache();
  }

}

/// Enum for different auth destinations
enum AuthDestination {
  splash,
  login,
  profile,
  home,
}

/// State class for auth flow
class AuthFlowState {
  final AuthDestination destination;

  AuthFlowState(this.destination);
}