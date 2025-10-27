import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFFFF6B6B);
  static const Color primaryDark = Color(0xFFE55555);
  static const Color primaryLight = Color(0xFFFF8888);
  
  // Neutral Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF1F3F4);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF212529);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textTertiary = Color(0xFF9CA3AF);
  
  // Status Colors
  static const Color success = Color(0xFF28A745);
  static const Color error = Color(0xFFDC3545);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF17A2B8);
  
  // Network Status Colors
  static const Color networkOffline = Color(0xFFFF9800);
  static const Color networkOnline = Color(0xFF4CAF50);
  
  // Shadow Colors
  static const Color shadow = Color(0x1A000000);
  static const Color shadowLight = Color(0x0D000000);
  
  // Border Colors
  static const Color border = Color(0xFFE9ECEF);
  static const Color borderLight = Color(0xFFF8F9FA);
  
  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.black, Color(0xFF424242), Colors.black87],
    stops: [0.0, 0.5, 1.0],
  );
  
  // Legacy compatibility
  static const Color appColor = primary;
}