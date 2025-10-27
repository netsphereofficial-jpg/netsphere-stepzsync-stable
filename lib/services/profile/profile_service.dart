import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../models/profile_models.dart';
import '../../models/auth_models.dart';
import '../firebase_service.dart';
import '../xp_service.dart';
import '../../core/utils/common_methods.dart';

class ProfileService {
  static const String _collection = 'user_profiles';

  static FirebaseService get _firebaseService => Get.find<FirebaseService>();
  static FirebaseFirestore get _firestore => _firebaseService.firestore;
  static FirebaseAuth get _auth => _firebaseService.auth;

  /// Save or update user profile
  static Future<AuthResult> saveProfile(UserProfile profile) async {
    try {
      await _firebaseService.ensureInitialized();
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure(error: 'User not authenticated');
      }

      // Mark profile as completed when saving
      final completedProfile = profile.copyWith(profileCompleted: true);
      final profileData = completedProfile.toJson();

      await _firestore
          .collection(_collection)
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true));

      // 🎁 Award profile completion XP (30 XP one-time)
      try {
        final xpService = XPService();
        await xpService.awardProfileCompletionXP(userId: user.uid);
        print('✅ Awarded profile completion XP to ${user.uid}');
      } catch (e) {
        print('⚠️ Failed to award profile completion XP: $e');
        // Don't block profile save if XP fails
      }

      return AuthResult.success(
        message: 'Profile saved successfully',
        data: completedProfile.copyWith(id: user.uid),
      );
    } catch (e) {
      return AuthResult.failure(
        error: 'Failed to save profile: ${e.toString()}',
      );
    }
  }

  /// Get user profile
  static Future<AuthResult> getProfile() async {
    try {
      await _firebaseService.ensureInitialized();
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure(error: 'User not authenticated');
      }

      final doc = await _firestore
          .collection(_collection)
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final profile = UserProfile.fromFirestore(doc);
        return AuthResult.success(
          message: 'Profile retrieved successfully',
          data: profile,
        );
      } else {
        return AuthResult.failure(error: 'Profile not found');
      }
    } catch (e) {
      return AuthResult.failure(
        error: 'Failed to retrieve profile: ${e.toString()}',
      );
    }
  }

  /// Update specific profile field
  static Future<AuthResult> updateProfileField(
    String field,
    dynamic value,
  ) async {
    try {
      await _firebaseService.ensureInitialized();
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure(error: 'User not authenticated');
      }

      await _firestore
          .collection(_collection)
          .doc(user.uid)
          .update({
        field: value,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      return AuthResult.success(message: 'Profile updated successfully');
    } catch (e) {
      return AuthResult.failure(
        error: 'Failed to update profile: ${e.toString()}',
      );
    }
  }

  /// Delete user profile
  static Future<AuthResult> deleteProfile() async {
    try {
      await _firebaseService.ensureInitialized();
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure(error: 'User not authenticated');
      }

      await _firestore
          .collection(_collection)
          .doc(user.uid)
          .delete();

      return AuthResult.success(message: 'Profile deleted successfully');
    } catch (e) {
      return AuthResult.failure(
        error: 'Failed to delete profile: ${e.toString()}',
      );
    }
  }

  /// Check if profile exists and is completed
  static Future<bool> profileExists() async {
    try {
      await _firebaseService.ensureInitialized();
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore
          .collection(_collection)
          .doc(user.uid)
          .get();

      if (!doc.exists) return false;
      
      final data = doc.data() as Map<String, dynamic>;
      return data['profileCompleted'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if profile document exists (regardless of completion status)
  static Future<bool> profileDocumentExists() async {
    try {
      await _firebaseService.ensureInitialized();
      final user = _auth.currentUser;
      if (user == null) {
        print('🚫 ProfileService: No authenticated user found');
        return false;
      }

      print('🔍 ProfileService: Checking document existence for user: ${user.uid}');
      print('📂 Collection: $_collection');
      
      final doc = await _firestore
          .collection(_collection)
          .doc(user.uid)
          .get();

      print('📄 Document exists: ${doc.exists}');
      return doc.exists;
    } catch (e) {
      print('❌ ProfileService: Error checking document existence: $e');
      return false;
    }
  }

  /// Check if profile is completed
  static Future<bool> isProfileCompleted() async {
    try {
      await _firebaseService.ensureInitialized();
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore
          .collection(_collection)
          .doc(user.uid)
          .get();

      if (!doc.exists) return false;
      
      final data = doc.data() as Map<String, dynamic>;
      return data['profileCompleted'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Update profile after account linking (guest → Google/Apple)
  /// Sets profileCompleted to false and updates with social provider info
  static Future<AuthResult> updateProfileAfterLinking({
    required String fullName,
    required String email,
    String? photoUrl,
  }) async {
    try {
      print('🔄 ProfileService: Updating profile after account linking...');
      await _firebaseService.ensureInitialized();
      final user = _auth.currentUser;
      if (user == null) {
        print('🚫 ProfileService: User not authenticated');
        return AuthResult.failure(error: 'User not authenticated');
      }

      print('👤 ProfileService: Updating for user: ${user.uid}');
      print('📧 New email: $email');
      print('👨 New name: $fullName');

      // Update profile with new information and mark as incomplete
      final updateData = {
        'fullName': fullName.capitalizeWords(),
        'email': email,
        if (photoUrl != null) 'profilePicture': photoUrl,
        'profileCompleted': false, // ← CRITICAL: Force profile completion
        'updatedAt': DateTime.now().toIso8601String(),
      };

      print('📝 Update data: $updateData');
      print('🔥 Updating Firestore...');

      await _firestore
          .collection(_collection)
          .doc(user.uid)
          .update(updateData);

      print('✅ ProfileService: Profile updated successfully');
      return AuthResult.success(message: 'Profile updated after linking');
    } catch (e) {
      print('❌ ProfileService: Failed to update profile: $e');
      return AuthResult.failure(
        error: 'Failed to update profile: ${e.toString()}',
      );
    }
  }

  /// Save initial profile (without marking as completed)
  static Future<AuthResult> saveInitialProfile(UserProfile profile) async {
    try {
      print('💾 ProfileService: Starting saveInitialProfile...');
      await _firebaseService.ensureInitialized();
      final user = _auth.currentUser;
      if (user == null) {
        print('🚫 ProfileService: User not authenticated');
        return AuthResult.failure(error: 'User not authenticated');
      }

      print('👤 ProfileService: Saving for user: ${user.uid}');
      print('📂 Collection: $_collection');

      // Check if profile already exists to prevent duplicate creation
      final existingDoc = await _firestore.collection(_collection).doc(user.uid).get();
      if (existingDoc.exists) {
        print('ℹ️ ProfileService: Profile already exists, skipping creation');
        return AuthResult.success(
          message: 'Profile already exists',
          data: UserProfile.fromJson(existingDoc.data()!),
        );
      }

      // Don't mark as completed - keep original profileCompleted value
      final profileData = profile.toJson();
      print('📝 Profile data: $profileData');

      print('🔥 Writing to Firestore...');
      await _firestore
          .collection(_collection)
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true));

      print('✅ ProfileService: Initial profile saved successfully');
      return AuthResult.success(
        message: 'Initial profile created successfully',
        data: profile.copyWith(id: user.uid),
      );
    } catch (e) {
      print('❌ ProfileService: Failed to save initial profile: $e');
      print('📍 Stack trace: ${StackTrace.current}');
      return AuthResult.failure(
        error: 'Failed to create initial profile: ${e.toString()}',
      );
    }
  }

  /// Get current user ID
  static String? getCurrentUserId() {
    try {
      return _auth.currentUser?.uid;
    } catch (e) {
      return null;
    }
  }

  /// Update FCM token for the current user
  /// This should be called whenever a new FCM token is generated
  static Future<AuthResult> updateFCMToken(String fcmToken) async {
    try {
      print('🔥 ProfileService: Updating FCM token...');
      await _firebaseService.ensureInitialized();
      final user = _auth.currentUser;
      if (user == null) {
        print('🚫 ProfileService: User not authenticated, cannot save FCM token');
        return AuthResult.failure(error: 'User not authenticated');
      }

      print('👤 ProfileService: Updating FCM token for user: ${user.uid}');
      print('🔑 FCM Token: ${fcmToken.substring(0, 20)}...');

      // Update FCM token in user profile
      final updateData = {
        'fcmToken': fcmToken,
        'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _firestore
          .collection(_collection)
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));

      print('✅ ProfileService: FCM token updated successfully');
      return AuthResult.success(message: 'FCM token updated successfully');
    } catch (e) {
      print('❌ ProfileService: Failed to update FCM token: $e');
      return AuthResult.failure(
        error: 'Failed to update FCM token: ${e.toString()}',
      );
    }
  }

  /// Get FCM token for the current user
  static Future<String?> getFCMToken() async {
    try {
      await _firebaseService.ensureInitialized();
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection(_collection)
          .doc(user.uid)
          .get();

      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      return data['fcmToken'] as String?;
    } catch (e) {
      print('❌ ProfileService: Error getting FCM token: $e');
      return null;
    }
  }
}