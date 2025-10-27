import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../firebase_service.dart';

/// Admin Authentication Service
/// Handles admin role verification and authentication
class AdminAuthService {
  static const String _userCollection = 'user_profiles';
  static const String _adminRoleField = 'role';
  static const String _adminRoleValue = 'admin';

  static FirebaseService get _firebaseService => Get.find<FirebaseService>();
  static FirebaseAuth get _auth => _firebaseService.auth;
  static FirebaseFirestore get _firestore => _firebaseService.firestore;

  /// Check if current user is an admin
  static Future<bool> isAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      return await isAdminByUid(user.uid);
    } catch (e) {
      print('❌ Error checking admin status: $e');
      return false;
    }
  }

  /// Check if a specific user ID has admin role
  static Future<bool> isAdminByUid(String uid) async {
    try {
      await _firebaseService.ensureInitialized();

      final doc = await _firestore
          .collection(_userCollection)
          .doc(uid)
          .get();

      if (!doc.exists) {
        print('⚠️ User document not found for UID: $uid');
        return false;
      }

      final data = doc.data();
      final role = data?[_adminRoleField] as String?;

      return role == _adminRoleValue;
    } catch (e) {
      print('❌ Error checking admin status for UID $uid: $e');
      return false;
    }
  }

  /// Verify admin access and return admin user info
  static Future<AdminUser?> verifyAdminAccess() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final isUserAdmin = await isAdminByUid(user.uid);
      if (!isUserAdmin) return null;

      // Get admin user data
      final doc = await _firestore
          .collection(_userCollection)
          .doc(user.uid)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      return AdminUser(
        uid: user.uid,
        email: user.email ?? data['email'] ?? '',
        name: data['fullName'] ?? 'Admin',
        role: data[_adminRoleField] ?? '',
      );
    } catch (e) {
      print('❌ Error verifying admin access: $e');
      return null;
    }
  }

  /// Get current admin user
  static Future<AdminUser?> getCurrentAdminUser() async {
    return await verifyAdminAccess();
  }

  /// Set user as admin (use this to create admin accounts)
  /// WARNING: This should only be called from secure environment
  /// In production, use Firebase Admin SDK from backend
  static Future<bool> setAdminRole(String uid) async {
    try {
      await _firebaseService.ensureInitialized();

      await _firestore
          .collection(_userCollection)
          .doc(uid)
          .set({
        _adminRoleField: _adminRoleValue,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Admin role set for user: $uid');
      return true;
    } catch (e) {
      print('❌ Error setting admin role: $e');
      return false;
    }
  }

  /// Remove admin role from user
  static Future<bool> removeAdminRole(String uid) async {
    try {
      await _firebaseService.ensureInitialized();

      await _firestore
          .collection(_userCollection)
          .doc(uid)
          .update({
        _adminRoleField: FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Admin role removed for user: $uid');
      return true;
    } catch (e) {
      print('❌ Error removing admin role: $e');
      return false;
    }
  }

  /// Sign out admin
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('✅ Admin signed out successfully');
    } catch (e) {
      print('❌ Error signing out admin: $e');
      rethrow;
    }
  }
}

/// Admin User model
class AdminUser {
  final String uid;
  final String email;
  final String name;
  final String role;

  AdminUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
    };
  }

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? 'Admin',
      role: json['role'] ?? '',
    );
  }
}
