import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../models/auth_models.dart';
import '../../models/profile_models.dart';
import '../../core/constants/app_constants.dart';
import '../firebase_service.dart';

class FirebaseAuthService {
  static const String _profileCollection = 'user_profiles';

  static FirebaseService get _firebaseService => Get.find<FirebaseService>();
  static FirebaseAuth get _auth => _firebaseService.auth;
  static FirebaseFirestore get _firestore => _firebaseService.firestore;
  
  // Stream to listen for auth state changes
  static Stream<User?> get authStateChanges => _firebaseService.getAuthStateChanges();

  // Get current user
  static Future<User?> get currentUser async {
    await _firebaseService.ensureInitialized();
    return _auth.currentUser;
  }

  // Check if user is authenticated
  static Future<bool> get isAuthenticated async {
    final user = await currentUser;
    return user != null;
  }
  
  // Sign in with email and password
  static Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _firebaseService.ensureInitialized();
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (userCredential.user != null) {
        return AuthResult.success(
          message: AppConstants.loginSuccessMessage,
          data: userCredential.user,
        );
      } else {
        return AuthResult.failure(error: 'Login failed. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(error: _getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure(error: 'An unexpected error occurred');
    }
  }
  
  // Create account with email and password
  static Future<AuthResult> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _firebaseService.ensureInitialized();
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (userCredential.user != null) {
        try {
          // EMAIL VERIFICATION REMOVED - Users can use the app immediately
          // No need to send verification email anymore

          // Create initial incomplete profile in Firestore
          await _createInitialProfile(userCredential.user!, email.trim());

          return AuthResult.success(
            message: AppConstants.signupSuccessMessage,
            data: userCredential.user,
          );
        } catch (profileError) {
          print('Profile creation failed during signup: $profileError');
          // Still return success since the user account was created
          // The profile will be created when they first access the profile screen
          return AuthResult.success(
            message: AppConstants.signupSuccessMessage,
            data: userCredential.user,
          );
        }
      } else {
        return AuthResult.failure(error: 'Account creation failed. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(error: _getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure(error: 'An unexpected error occurred');
    }
  }

  // Create initial profile with incomplete status
  static Future<void> _createInitialProfile(User user, String email) async {
    try {
      final initialProfile = UserProfile(
        email: email,
        fullName: '',
        phoneNumber: '',
        countryCode: '+91',
        gender: '',
        location: '',
        height: 0,
        heightUnit: 'cms',
        weight: 0,
        weightUnit: 'Kgs',
        profileCompleted: false, // This is the key field
        healthKitEnabled: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(_profileCollection)
          .doc(user.uid)
          .set(initialProfile.toJson());
      
      print('Initial profile created successfully for user: ${user.uid}');
    } catch (e) {
      // Log error but don't fail the signup process
      print('Failed to create initial profile: $e');
      // Re-throw the error so we can handle it properly
      rethrow;
    }
  }
  
  // Send password reset email
  static Future<AuthResult> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      
      return AuthResult.success(
        message: AppConstants.passwordResetSentMessage,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(error: _getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure(error: 'An unexpected error occurred');
    }
  }
  
  // Sign out
  static Future<AuthResult> signOut() async {
    try {
      await _firebaseService.ensureInitialized();
      await _auth.signOut();
      return AuthResult.success(message: 'Signed out successfully');
    } catch (e) {
      return AuthResult.failure(error: 'Failed to sign out');
    }
  }
  
  // Validate email format
  static bool isEmailValid(String email) {
    return RegExp(r'^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$').hasMatch(email);
  }
  
  // Validate password strength
  static bool isPasswordValid(String password) {
    return password.length >= AppConstants.minPasswordLength;
  }
  
  // Validate mobile number
  static bool isMobileValid(String mobile) {
    return mobile.length >= AppConstants.minMobileLength;
  }
  
  // Get user-friendly error messages
  static String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address';
      case 'wrong-password':
        return 'Incorrect password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later';
      case 'invalid-email':
        return AppConstants.emailInvalidError;
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'operation-not-allowed':
        return 'Email registration is currently disabled';
      default:
        return e.message ?? 'Authentication failed';
    }
  }
}