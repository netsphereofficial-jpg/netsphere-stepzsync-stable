class AppConstants {
  // App Info
  static const String appName = 'StepzSync';
  static const String appVersion = '1.0.0';
  static const String GOOGLE_MAP_API_KEY =
      "AIzaSyDc5bTP6J3cEJ35z22w4wCXYT-6kqwQBFc";
  // Animation Durations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultMargin = 16.0;
  static const double defaultBorderRadius = 16.0;
  static const double buttonHeight = 56.0;
  static const double textFieldHeight = 56.0;
  
  // Validation
  static const int minPasswordLength = 6;
  static const int minMobileLength = 10;
  
  // Error Messages
  static const String emailRequiredError = 'Please enter your email address';
  static const String emailInvalidError = 'Please enter a valid email address';
  static const String passwordRequiredError = 'Please enter your password';
  static const String passwordLengthError = 'Password must be at least 6 characters';
  static const String mobileRequiredError = 'Please enter your mobile number';
  static const String mobileLengthError = 'Mobile number must be at least 10 digits';
  
  // Success Messages
  static const String loginSuccessMessage = 'Login successful';
  static const String signupSuccessMessage = 'Account created successfully';
  static const String passwordResetSentMessage = 'Password reset email sent';
}