import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/profile_models.dart';

class UserProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get currentUserId => _auth.currentUser?.uid;

  /// Get user profile by user ID
  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      print('🔍 UserProfileService: Fetching profile for user: $userId');

      final doc = await _firestore
          .collection('user_profiles')
          .doc(userId)
          .get();

      if (!doc.exists) {
        print('❌ UserProfileService: Profile not found for user: $userId');
        return null;
      }

      print('✅ UserProfileService: Profile found for user: $userId');
      final profile = UserProfile.fromFirestore(doc);

      // Log some basic info (avoid logging sensitive data)
      print('📋 Profile info: ${profile.fullName}, Location: ${profile.location}');

      return profile;
    } catch (e) {
      print('❌ UserProfileService: Error fetching profile: $e');
      return null;
    }
  }

  /// Get multiple user profiles by IDs
  static Future<List<UserProfile>> getUserProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      print('🔍 UserProfileService: Fetching ${userIds.length} profiles');

      final profiles = <UserProfile>[];

      // Firestore 'in' queries are limited to 10 items, so we batch them
      const batchSize = 10;
      for (int i = 0; i < userIds.length; i += batchSize) {
        final batch = userIds.skip(i).take(batchSize).toList();

        final querySnapshot = await _firestore
            .collection('user_profiles')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (var doc in querySnapshot.docs) {
          profiles.add(UserProfile.fromFirestore(doc));
        }
      }

      print('✅ UserProfileService: Fetched ${profiles.length} profiles');
      return profiles;
    } catch (e) {
      print('❌ UserProfileService: Error fetching profiles: $e');
      return [];
    }
  }

  /// Check if user exists
  static Future<bool> userExists(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_profiles')
          .doc(userId)
          .get();

      return doc.exists;
    } catch (e) {
      print('❌ UserProfileService: Error checking user existence: $e');
      return false;
    }
  }

  /// Get basic user info for friend requests (name, username, profile picture)
  static Future<Map<String, String?>> getUserBasicInfo(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_profiles')
          .doc(userId)
          .get();

      if (!doc.exists) {
        return {
          'fullName': 'Unknown User',
          'username': null,
          'profilePicture': null,
        };
      }

      final data = doc.data() as Map<String, dynamic>;
      return {
        'fullName': data['fullName'] ?? 'Unknown User',
        'username': data['username'],
        'profilePicture': data['profilePicture'],
      };
    } catch (e) {
      print('❌ UserProfileService: Error fetching basic info: $e');
      return {
        'fullName': 'Unknown User',
        'username': null,
        'profilePicture': null,
      };
    }
  }

  /// Get user's activity stats (placeholder - would connect to actual stats collection)
  static Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      // TODO: Connect to actual stats collection when available
      // For now, return placeholder data
      await Future.delayed(const Duration(milliseconds: 500));

      return {
        'totalSteps': 12345,
        'totalDistance': 8.2, // in km
        'totalCalories': 1250,
        'activeDays': 15,
        'averageSteps': 8230,
        'bestDay': 15678,
      };
    } catch (e) {
      print('❌ UserProfileService: Error fetching stats: $e');
      return {
        'totalSteps': 0,
        'totalDistance': 0.0,
        'totalCalories': 0,
        'activeDays': 0,
        'averageSteps': 0,
        'bestDay': 0,
      };
    }
  }

  /// Stream user profile for real-time updates
  static Stream<UserProfile?> streamUserProfile(String userId) {
    return _firestore
        .collection('user_profiles')
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return UserProfile.fromFirestore(doc);
        });
  }
}