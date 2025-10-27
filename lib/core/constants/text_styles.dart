import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';

/// Premium text styles constants for the application
/// Using high-quality fonts that are popular in modern fitness apps
class AppTextStyles {
  // Premium font families
  static String get _primaryFont => 'Inter'; // Clean, modern sans-serif
  static String get _headingFont => 'Poppins'; // Bold, friendly headings
  static String get _accentFont => 'Nunito'; // Rounded, approachable
  
  // HEADING STYLES
  static TextStyle get heroHeading => GoogleFonts.roboto(
    fontSize: 24,
    fontWeight: FontWeight.w600, // semibold
    color: const Color(0xFF112565),
  );
  
  static TextStyle get sectionHeading => GoogleFonts.getFont(
    _headingFont,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: const Color(0xFFCDFF49),
    letterSpacing: -0.3,
  );
  
  static TextStyle get cardHeading => GoogleFonts.getFont(
    _headingFont,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  
  // BODY TEXT STYLES
  static TextStyle get bodyLarge => GoogleFonts.getFont(
    _primaryFont,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
    letterSpacing: 0.1,
  );
  
  static TextStyle get bodyMedium => GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w400, // regular
    color: Colors.black54,
  );
  
  static TextStyle get bodySmall => GoogleFonts.getFont(
    _primaryFont,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Colors.white70,
  );
  
  // ACCENT & DISPLAY STYLES
  static TextStyle get statValue => GoogleFonts.getFont(
    _accentFont,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.2,
  );
  
  static TextStyle get statLargeValue => GoogleFonts.getFont(
    _accentFont,
    fontWeight: FontWeight.w700,
    color: AppColors.darkBackground,
  );
  
  static TextStyle get statLabel => GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w500, // medium
    color: Colors.white,
  );
  
  static TextStyle get statSmallLabel => GoogleFonts.getFont(
    _primaryFont,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.mediumGrey,
  );
  
  // BUTTON STYLES
  static TextStyle get buttonText => GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w400, // regular
    color: Colors.black,
  );
  
  static TextStyle get dropdownText => GoogleFonts.getFont(
    _primaryFont,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.darkBackground,
  );
  
  // SPECIALIZED STYLES
  static TextStyle get cornerStatValue => GoogleFonts.roboto(
    fontSize: 20,
    fontWeight: FontWeight.bold, // bold
    color: Colors.white,
  );
  
  static TextStyle get cornerStatUnit => GoogleFonts.getFont(
    _primaryFont,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.lightGray,
  );
  
  // METHOD TO GET CUSTOM VARIATIONS
  static TextStyle getCustomStyle({
    required String fontFamily,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double letterSpacing = 0.0,
  }) {
    return GoogleFonts.getFont(
      fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}