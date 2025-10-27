import 'package:firebase_auth/firebase_auth.dart';

/// Utility class for guest user management
class GuestUtils {
  /// Check if the current user is a guest (anonymous)
  static bool isGuest() {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && user.isAnonymous;
  }

  /// Get the current user
  static User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }

  /// Check if user is authenticated (guest or regular)
  static bool isAuthenticated() {
    return FirebaseAuth.instance.currentUser != null;
  }

  /// Check if user is a regular (non-guest) user
  static bool isRegularUser() {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && !user.isAnonymous;
  }

  /// Get user ID (works for both guest and regular users)
  static String? getUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  /// Check if a specific feature is available to guest users
  /// Customize this based on your feature gating requirements
  static bool isFeatureAvailableToGuest(String featureName) {
    switch (featureName) {
      // ✅ ALLOWED for Guests (Free Trial Experience)
      case 'home_screen':
        return true;
      case 'profile':
        return true; // Guests can view their profile
      case 'quick_race':
        return true;
      case 'active_races_view':
        return true;
      case 'race_map':
        return true;
      case 'step_tracking':
        return true;
      case 'statistics_view':
        return true;

      // 🔒 RESTRICTED for Guests (Requires Account)
      // Social Features
      case 'leaderboard':
        return false;
      case 'chat':
        return false;
      case 'create_race':
        return false;

      // Advanced Features
      case 'profile_edit':
        return false;
      case 'race_invites':
        return false;
      case 'notifications':
        return false;
      case 'marathon':
        return false;
      case 'hall_of_fame':
        return false;
      case 'send_invites':
        return false;

      default:
        return false; // Default: restrict unknown features
    }
  }

  /// Show upgrade prompt to convert guest to regular user
  /// Returns true if user should be shown upgrade dialog
  static bool shouldShowUpgradePrompt(String attemptedFeature) {
    return isGuest() && !isFeatureAvailableToGuest(attemptedFeature);
  }

  /// Generate a guest display name from user ID
  static String generateGuestName(String userId) {
    final randomId = userId.substring(0, 6).toUpperCase();
    return 'Guest_$randomId';
  }
}
