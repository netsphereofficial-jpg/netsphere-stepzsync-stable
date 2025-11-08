import 'dart:async';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:stepzsync/screens/profile/profile_screen.dart';

import '../../screens/home_screen/home_screen.dart';
import '../../services/profile/profile_service.dart';
import '../../services/auth_wrapper.dart';
import '../../config/design_system.dart';
import '../profile/profile_controller.dart';
import '../../core/utils/common_methods.dart';

/// UNIFIED LOGIN CONTROLLER
/// Consolidates AuthController and LoginController into one clean implementation
/// Implements smart auto-switching between signin/signup
/// No email verification blocking, simplified flows
class LoginController extends GetxController {
  // Controllers for user input fields
  final mobileCtr = TextEditingController();
  final emailCtr = TextEditingController();
  final passwordCtr = TextEditingController();
  final confirmPasswordCtr = TextEditingController();
  var deviceToken = "".obs;

  // Boolean observable to toggle between mobile and email login
  var isMobile = false.obs;

  // Password visibility toggle
  final _obscurePassword = true.obs;
  final _obscureConfirmPassword = true.obs;

  // Selected country (defaults to India)
  var selectedCountry = CountryCode.fromCountryCode('IN').obs;

  // Loading states
  var isLoading = false.obs;
  var isGoogleLoading = false.obs;
  var isAppleLoading = false.obs;

  // Prevent duplicate sign-in attempts (race condition protection)
  bool _isGoogleSignInInProgress = false;
  bool _isAppleSignInInProgress = false;

  // Authentication mode
  var authMode = AuthMode.login.obs;

  // Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Updates the selected country when the user chooses a new one
  void updateCountry(CountryCode country) {
    selectedCountry.value = country;
  }

  /// Toggles between mobile and email login mode
  void toggleLoginMode() {
    isMobile.toggle();
  }

  /// Toggles the password visibility (show/hide password)
  void togglePasswordVisibility() {
    _obscurePassword.toggle();
  }

  /// Returns the current password visibility state
  bool isPasswordObscured() {
    return _obscurePassword.value;
  }

  /// Toggles the confirm password visibility (show/hide password)
  void toggleConfirmPasswordVisibility() {
    _obscureConfirmPassword.toggle();
  }

  /// Returns the current confirm password visibility state
  bool isConfirmPasswordObscured() {
    return _obscureConfirmPassword.value;
  }

  /// Switch between authentication modes
  void switchToLogin() {
    authMode.value = AuthMode.login;
  }

  void switchToSignup() {
    authMode.value = AuthMode.signup;
  }

  void switchToForgotPassword() {
    authMode.value = AuthMode.forgotPassword;
  }

  /// Get dynamic text based on auth mode
  String get headerTitle {
    switch (authMode.value) {
      case AuthMode.login:
        return 'Welcome';
      case AuthMode.signup:
        return 'Create Account';
      case AuthMode.forgotPassword:
        return 'Reset Password';
    }
  }

  String get headerSubtitle {
    switch (authMode.value) {
      case AuthMode.login:
        return 'Sign in to continue your fitness journey';
      case AuthMode.signup:
        return 'Join StepzSync and start tracking your fitness';
      case AuthMode.forgotPassword:
        return 'Enter your email to reset your password';
    }
  }

  String get welcomeTitle {
    switch (authMode.value) {
      case AuthMode.login:
        return isMobile.value ? "Sign In with Phone" : "Sign In with Email";
      case AuthMode.signup:
        return isMobile.value ? "Sign Up with Phone" : "Sign Up with Email";
      case AuthMode.forgotPassword:
        return "Reset Password";
    }
  }

  String get welcomeSubtitle {
    switch (authMode.value) {
      case AuthMode.login:
        return 'Enter your credentials to access your account';
      case AuthMode.signup:
        return 'Create your new StepzSync account';
      case AuthMode.forgotPassword:
        return 'We\'ll send you a reset link';
    }
  }

  String get submitButtonText {
    switch (authMode.value) {
      case AuthMode.login:
        return 'Sign In';
      case AuthMode.signup:
        return 'Create Account';
      case AuthMode.forgotPassword:
        return 'Send Reset Link';
    }
  }

  String get bottomText {
    switch (authMode.value) {
      case AuthMode.login:
        return "Don't have an account? ";
      case AuthMode.signup:
        return "Already have an account? ";
      case AuthMode.forgotPassword:
        return "Remember your password? ";
    }
  }

  String get bottomActionText {
    switch (authMode.value) {
      case AuthMode.login:
        return 'Sign Up';
      case AuthMode.signup:
        return 'Sign In';
      case AuthMode.forgotPassword:
        return 'Sign In';
    }
  }

  bool get showPasswordField {
    return authMode.value != AuthMode.forgotPassword;
  }

  bool get showForgotPassword {
    return authMode.value == AuthMode.login;
  }

  /// Validate email format
  bool _isEmailValid(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate password strength
  bool _isPasswordValid(String password) {
    return password.length >= 6;
  }

  /// Show error snackbar
  void _showError(String title, String message) {
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 8,
      duration: Duration(seconds: 3),
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
    );
  }

  /// Show success snackbar
  void _showSuccess(String title, String message) {
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 8,
      duration: Duration(seconds: 2),
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
    );
  }

  /// UNIFIED SIGN IN/SIGN UP WITH EMAIL
  /// Smart auto-switching: Try sign in first, if fails create account
  Future<void> signInWithEmail() async {
    if (isLoading.value) return;

    final email = emailCtr.text.trim();
    final password = passwordCtr.text;
    final confirmPassword = confirmPasswordCtr.text;

    // Validation
    if (email.isEmpty) {
      _showError('Error', 'Please enter your email address');
      return;
    }

    if (!_isEmailValid(email)) {
      _showError('Error', 'Please enter a valid email address');
      return;
    }

    if (password.isEmpty) {
      _showError('Error', 'Please enter your password');
      return;
    }

    if (!_isPasswordValid(password)) {
      _showError('Error', 'Password must be at least 6 characters');
      return;
    }

    // For signup mode, validate confirm password
    if (authMode.value == AuthMode.signup) {
      if (confirmPassword.isEmpty) {
        _showError('Error', 'Please confirm your password');
        return;
      }

      if (password != confirmPassword) {
        _showError('Error', 'Passwords do not match');
        return;
      }
    }

    try {
      isLoading.value = true;
      HapticFeedback.lightImpact();

      UserCredential userCredential;

      if (authMode.value == AuthMode.login) {
        // LOGIN MODE: Try to sign in
        print('🔵 Attempting sign in with email: $email');
        try {
          userCredential = await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          print('✅ Sign in successful');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
            // User doesn't exist - show confirmation dialog
            print('ℹ️ User not found - showing account creation dialog');

            // Stop loading temporarily
            isLoading.value = false;

            // Show confirmation dialog
            final shouldCreate = await _showAccountCreationDialog(email);

            if (!shouldCreate) {
              // User cancelled
              print('❌ User cancelled account creation');
              return;
            }

            // Resume loading
            isLoading.value = true;

            // Create account
            print('✅ User confirmed - creating account');
            _showSuccess('Creating Account', 'Setting up your account...');

            userCredential = await _auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
            print('✅ Account created and signed in automatically');
          } else {
            rethrow; // Re-throw other errors
          }
        }
      } else {
        // SIGNUP MODE: Create account
        print('🔵 Creating new account with email: $email');

        // Check if current user is a guest/anonymous user
        final currentUser = _auth.currentUser;
        final isGuest = currentUser != null && currentUser.isAnonymous;

        if (isGuest) {
          try {
            // Try to link anonymous account with Email/Password credential
            print('🔗 Linking guest account with email/password...');
            final emailCredential = EmailAuthProvider.credential(
              email: email,
              password: password,
            );
            userCredential = await currentUser.linkWithCredential(emailCredential);
            _showSuccess('Account Upgraded!', 'Your guest progress has been saved!');
            print('✅ Guest account linked successfully');
          } on FirebaseAuthException catch (e) {
            if (e.code == 'credential-already-in-use' ||
                e.code == 'email-already-in-use' ||
                e.code == 'provider-already-linked') {
              // Account already exists - sign in instead
              print('ℹ️ Account already exists - signing in instead');
              await _auth.signOut();
              userCredential = await _auth.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
            } else {
              rethrow;
            }
          }
        } else {
          // Normal account creation
          try {
            userCredential = await _auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
            print('✅ New account created successfully');
          } on FirebaseAuthException catch (e) {
            if (e.code == 'email-already-in-use') {
              // Email already in use - try to sign in instead
              print('ℹ️ Email already in use - attempting sign in');
              _showSuccess('Signing In', 'Account already exists, signing you in...');

              userCredential = await _auth.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
              print('✅ Signed in with existing account');
            } else {
              rethrow;
            }
          }
        }
      }

      if (userCredential.user != null) {
        final user = userCredential.user!;
        print('✅ Authentication successful - User: ${user.email} (UID: ${user.uid})');

        // Clear auth cache to ensure fresh profile check
        print('🗑️ Clearing auth cache for fresh profile check...');
        AuthWrapper.clearCache();

        // Check if user has completed profile
        final isProfileCompleted = await ProfileService.isProfileCompleted();
        print('📋 Profile completion status: $isProfileCompleted');

        if (isProfileCompleted) {
          // Profile completed - go to home
          Get.offAll(() => HomeScreen());
        } else {
          // Profile incomplete - go to profile setup
          print('📝 Navigating to ProfileScreen for setup');

          // Initialize controller before navigating
          if (!Get.isRegistered<ProfileController>()) {
            Get.put(ProfileController(), permanent: true);
          }

          // Pass user information to profile screen
          Get.offAll(
            () => ProfileScreen(),
            arguments: {
              'name': user.displayName?.capitalizeWords(),
              'email': user.email,
              'provider': 'email',
            },
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = authMode.value == AuthMode.login
          ? 'Login failed'
          : 'Account creation failed';

      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email address';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid email or password';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak. Use at least 6 characters';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email registration is currently disabled';
          break;
        default:
          errorMessage = e.message ?? errorMessage;
      }

      _showError(
        authMode.value == AuthMode.login ? 'Login Failed' : 'Sign Up Failed',
        errorMessage,
      );
      HapticFeedback.heavyImpact();
    } catch (e) {
      print('❌ Unexpected error during email auth: $e');
      _showError('Error', 'An unexpected error occurred');
      HapticFeedback.heavyImpact();
    } finally {
      isLoading.value = false;
    }
  }

  /// Alias for backward compatibility
  Future<void> createAccountWithEmail() async {
    await signInWithEmail();
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    // Prevent duplicate sign-in attempts
    if (isGoogleLoading.value || _isGoogleSignInInProgress) {
      print('⏸️ Google sign-in already in progress, ignoring duplicate request');
      return;
    }

    try {
      _isGoogleSignInInProgress = true;
      isGoogleLoading.value = true;
      HapticFeedback.lightImpact();

      print('🔵 Starting Google sign-in flow...');

      // Create a GoogleAuthProvider instance
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      googleProvider.setCustomParameters({
        'prompt': 'select_account', // Always show account picker
      });

      // Check if current user is a guest/anonymous user
      final currentUser = _auth.currentUser;
      final isGuest = currentUser != null && currentUser.isAnonymous;
      print('👤 Current user status: ${isGuest ? "Guest" : "Regular"}');

      UserCredential userCredential;
      bool accountLinked = false;

      if (isGuest) {
        try {
          print('🔗 Attempting to link guest account with Google...');
          userCredential = await currentUser.linkWithProvider(googleProvider);
          accountLinked = true;
          print('✅ Guest account successfully linked with Google!');

          // Update profile with Google information
          final linkedUser = userCredential.user!;
          final googleName = linkedUser.displayName ?? '';

          if (googleName.isNotEmpty) {
            await linkedUser.updateDisplayName(googleName);
          }

          await ProfileService.updateProfileAfterLinking(
            fullName: googleName.capitalizeWords(),
            email: linkedUser.email ?? '',
            photoUrl: linkedUser.photoURL,
          );

          _showSuccess('Account Upgraded!', 'Your guest progress has been saved!');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use' ||
              e.code == 'provider-already-linked') {
            print('🔄 Google account already exists, switching to existing account...');

            // Delete anonymous profile before signing out
            try {
              await ProfileService.deleteProfile();
            } catch (deleteError) {
              print('⚠️ Failed to delete anonymous profile: $deleteError');
            }

            AuthWrapper.clearCache();
            await _auth.signOut();
            userCredential = await _auth.signInWithProvider(googleProvider);
          } else {
            rethrow;
          }
        }
      } else {
        // Normal Google sign in
        print('🔵 Normal Google sign-in (not a guest)');
        userCredential = await _auth.signInWithProvider(googleProvider);
      }

      if (userCredential.user != null) {
        final user = userCredential.user!;
        print('✅ Google sign-in successful - User: ${user.email}');

        // Clear auth cache
        AuthWrapper.clearCache();

        // Check profile completion
        final isProfileCompleted = await ProfileService.isProfileCompleted();
        print('📋 Profile completion status: $isProfileCompleted');

        if (isProfileCompleted) {
          Get.offAll(() => HomeScreen());
        } else {
          print('📝 Navigating to ProfileScreen for setup');

          if (!Get.isRegistered<ProfileController>()) {
            Get.put(ProfileController(), permanent: true);
          }

          Get.offAll(
            () => ProfileScreen(),
            arguments: {
              'name': user.displayName?.capitalizeWords(),
              'email': user.email,
              'photoUrl': user.photoURL,
              'provider': 'google',
              'isUpgrade': accountLinked,
            },
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Google sign in failed';

      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = 'An account already exists with the same email but different sign-in method';
          break;
        case 'invalid-credential':
          errorMessage = 'The credential received is malformed or has expired';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Google sign-in is not enabled for this project';
          break;
        case 'user-disabled':
          errorMessage = 'The user account has been disabled';
          break;
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          // User cancelled, not an error
          return;
        default:
          errorMessage = e.message ?? 'Google sign in failed';
      }

      print('❌ Google sign-in error: $errorMessage');
      _showError('Sign In Failed', errorMessage);
      HapticFeedback.heavyImpact();
    } catch (e) {
      print('❌ Unexpected Google sign-in error: $e');
      _showError('Error', 'An unexpected error occurred during Google sign in');
      HapticFeedback.heavyImpact();
    } finally {
      isGoogleLoading.value = false;
      _isGoogleSignInInProgress = false;
    }
  }

  /// Sign in with Apple
  Future<void> signInWithApple() async {
    // Prevent duplicate sign-in attempts
    if (isAppleLoading.value || _isAppleSignInInProgress) {
      print('⏸️ Apple sign-in already in progress, ignoring duplicate request');
      return;
    }

    try {
      _isAppleSignInInProgress = true;
      isAppleLoading.value = true;
      HapticFeedback.lightImpact();

      print('🍎 Starting Apple sign-in flow...');

      // Check if Apple Sign In is available
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        _showError('Not Available', 'Apple Sign In is not available on this device');
        return;
      }

      // Request credential from Apple
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create OAuth credential for Firebase
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      // Check if current user is a guest
      final currentUser = _auth.currentUser;
      final isGuest = currentUser != null && currentUser.isAnonymous;
      print('👤 Current user status: ${isGuest ? "Guest" : "Regular"}');

      UserCredential userCredential;
      bool accountLinked = false;

      if (isGuest) {
        try {
          print('🔗 Attempting to link guest account with Apple...');
          userCredential = await currentUser.linkWithCredential(oauthCredential);
          accountLinked = true;
          print('✅ Guest account successfully linked with Apple!');

          // Update profile with Apple information
          final linkedUser = userCredential.user!;
          final appleName = credential.givenName != null || credential.familyName != null
              ? '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim()
              : linkedUser.displayName ?? '';

          if (appleName.isNotEmpty) {
            await linkedUser.updateDisplayName(appleName);
          }

          await ProfileService.updateProfileAfterLinking(
            fullName: appleName.capitalizeWords(),
            email: linkedUser.email ?? '',
            photoUrl: null,
          );

          _showSuccess('Account Upgraded!', 'Your guest progress has been saved!');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use' ||
              e.code == 'provider-already-linked') {
            print('🔄 Apple account already exists, switching to existing account...');

            try {
              await ProfileService.deleteProfile();
            } catch (deleteError) {
              print('⚠️ Failed to delete anonymous profile: $deleteError');
            }

            AuthWrapper.clearCache();
            await _auth.signOut();
            userCredential = await _auth.signInWithCredential(oauthCredential);
          } else {
            rethrow;
          }
        }
      } else {
        // Normal Apple sign in
        print('🍎 Normal Apple sign-in (not a guest)');
        userCredential = await _auth.signInWithCredential(oauthCredential);
      }

      if (userCredential.user != null) {
        final user = userCredential.user!;
        print('✅ Apple sign-in successful - User: ${user.email}');

        // Update display name if new user
        if (userCredential.additionalUserInfo?.isNewUser == true) {
          if (credential.givenName != null || credential.familyName != null) {
            final displayName = '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();
            if (displayName.isNotEmpty) {
              await user.updateDisplayName(displayName);
            }
          }
        }

        // Clear auth cache
        AuthWrapper.clearCache();

        // Check profile completion
        final isProfileCompleted = await ProfileService.isProfileCompleted();
        print('📋 Profile completion status: $isProfileCompleted');

        if (isProfileCompleted) {
          Get.offAll(() => HomeScreen());
        } else {
          print('📝 Navigating to ProfileScreen for setup');

          final fullName = credential.givenName != null || credential.familyName != null
              ? '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim()
              : user.displayName;

          if (!Get.isRegistered<ProfileController>()) {
            Get.put(ProfileController(), permanent: true);
          }

          Get.offAll(
            () => ProfileScreen(),
            arguments: {
              'name': fullName?.capitalizeWords(),
              'email': user.email,
              'provider': 'apple',
              'isUpgrade': accountLinked,
            },
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Apple sign in failed';

      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = 'An account already exists with the same email but different sign-in method';
          break;
        case 'invalid-credential':
          errorMessage = 'The credential received is malformed or has expired';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Apple sign-in is not enabled for this project';
          break;
        case 'user-disabled':
          errorMessage = 'The user account has been disabled';
          break;
        default:
          errorMessage = e.message ?? 'Apple sign in failed';
      }

      _showError('Sign In Failed', errorMessage);
      HapticFeedback.heavyImpact();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        // User canceled, not an error
        return;
      }

      _showError('Sign In Failed', 'Apple sign in failed');
      HapticFeedback.heavyImpact();
    } catch (e) {
      print('❌ Unexpected Apple sign-in error: $e');
      _showError('Error', 'An unexpected error occurred during Apple sign in');
      HapticFeedback.heavyImpact();
    } finally {
      isAppleLoading.value = false;
      _isAppleSignInInProgress = false;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail() async {
    if (isLoading.value) return;

    final email = emailCtr.text.trim();

    // Validation
    if (email.isEmpty) {
      _showError('Error', 'Please enter your email address');
      return;
    }

    if (!_isEmailValid(email)) {
      _showError('Error', 'Please enter a valid email address');
      return;
    }

    try {
      isLoading.value = true;
      HapticFeedback.lightImpact();

      await _auth.sendPasswordResetEmail(email: email);

      _showSuccess('Email Sent!', 'Check your email for reset instructions');
      await Future.delayed(Duration(milliseconds: 2000));
      switchToLogin();
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to send reset email';

      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email address';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many requests. Please try again later';
          break;
        default:
          errorMessage = e.message ?? 'Failed to send reset email';
      }

      _showError('Reset Failed', errorMessage);
      HapticFeedback.heavyImpact();
    } catch (e) {
      _showError('Error', 'An unexpected error occurred');
      HapticFeedback.heavyImpact();
    } finally {
      isLoading.value = false;
    }
  }

  /// Handle bottom action tap (switches between modes)
  void handleBottomAction() {
    HapticFeedback.lightImpact();
    switch (authMode.value) {
      case AuthMode.login:
        switchToSignup();
        break;
      case AuthMode.signup:
        switchToLogin();
        break;
      case AuthMode.forgotPassword:
        switchToLogin();
        break;
    }
  }

  /// Main authentication action (called by UI)
  Future<void> handleAuthAction() async {
    switch (authMode.value) {
      case AuthMode.login:
      case AuthMode.signup:
        if (isMobile.value) {
          _showError('Coming Soon', 'Mobile authentication will be available soon');
        } else {
          await signInWithEmail();
        }
        break;
      case AuthMode.forgotPassword:
        await sendPasswordResetEmail();
        break;
    }
  }

  /// Main sign in method (called by UI) - kept for backward compatibility
  Future<void> signInClick() async {
    await handleAuthAction();
  }

  /// Sign in as guest (anonymous authentication)
  Future<void> signInAsGuest() async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;
      HapticFeedback.lightImpact();

      print('🎭 Starting guest sign-in...');

      // Simple anonymous login
      UserCredential userCredential = await _auth.signInAnonymously();

      if (userCredential.user != null) {
        print('✅ Guest sign-in successful - User ID: ${userCredential.user!.uid}');

        // Clear auth cache
        AuthWrapper.clearCache();

        // Navigate to AuthWrapper which will handle profile creation
        Get.offAll(() => const AuthWrapper());
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to continue as guest';

      if (e.code == 'operation-not-allowed') {
        errorMessage = 'Anonymous authentication is currently disabled';
      } else {
        errorMessage = e.message ?? 'Failed to continue as guest';
      }

      _showError('Guest Sign-in Failed', errorMessage);
      HapticFeedback.heavyImpact();
    } catch (e) {
      print('❌ Unexpected guest sign-in error: $e');
      _showError('Error', 'An unexpected error occurred');
      HapticFeedback.heavyImpact();
    } finally {
      isLoading.value = false;
    }
  }

  /// Show account creation confirmation dialog
  Future<bool> _showAccountCreationDialog(String email) async {
    final result = await Get.dialog<bool>(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppDesignColors.fieldBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_add_outlined,
                  color: AppDesignColors.primary,
                  size: 30,
                ),
              ),
              SizedBox(height: 20),

              // Title
              Text(
                'Account Not Found',
                style: GoogleFonts.roboto(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppDesignColors.primary,
                ),
              ),
              SizedBox(height: 12),

              // Message
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppDesignColors.label,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: 'No account found with ',
                    ),
                    TextSpan(
                      text: email,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppDesignColors.primary,
                      ),
                    ),
                    TextSpan(
                      text: '.\n\nWould you like to create a new account with this email?',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(result: false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppDesignColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppDesignColors.primary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Get.back(result: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignColors.primary,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Create Account',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    return result ?? false;
  }

  @override
  void onClose() {
    // Dispose controllers to prevent memory leaks
    mobileCtr.clear();
    emailCtr.clear();
    passwordCtr.clear();
    confirmPasswordCtr.clear();

    super.onClose();
  }
}

enum AuthMode { login, signup, forgotPassword }
