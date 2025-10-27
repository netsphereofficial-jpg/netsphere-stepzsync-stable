import 'package:flutter/material.dart';

class AppColors {
  // Premium Sporty Color Palette
  static const Color primary = Color(0xFF1A1A2E);
  static const Color secondary = Color(0xFF16213E);
  static const Color accent = Color(0xFF0F3460);
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color neonYellow = Color(0xFFCDFF49);
  static const Color orangeYellow = Color(0xFFFFA726); // Orangish-yellow for leaderboard
  static const Color electricBlue = Color(0xFF00BFFF);
  static const Color sportOrange = Color(0xFFFF6B35);
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color darkBackground = Color(0xFF0A0A0A);
  
  // Legacy colors for compatibility
  static const Color  appColor = Color(0xFF2759FF);
  static const Color appColorDark = Color(0xFF16213E);
  static const Color greenColor = Color(0xFF4CAF50); // Better, softer green
  static const Color darkListTileColor = Color(0xff021F29);
  static const Color darkListTileColor1 = Color(0xFF000202);
  static const Color lightGray = Color(0xFFB3B3B3);
  static const Color blueLight = Color(0xFFE4F0FF);
  static const Color buttonBlack = Color(0xFF0A0A0A);
  static const Color iconGrey = Color(0xFF464646);
  static const Color boxColor = Color(0xFFF8F9FA);
  static const Color greyColor2 = Color(0xFF7D7D7D);
  static const Color mediumGrey = Color(0xFF595959);
  static const Color white = Color(0xFFffffff);

  static const lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF2759FF),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Colors.white,
    onPrimaryContainer: Colors.white,
    secondary: Colors.black,
    onSecondary: Colors.white,
    error: Color.fromARGB(255, 236, 3, 3),
    onError: Color.fromARGB(255, 153, 2, 2),
    surface: Colors.white,
    onSurface: Colors.black87,
  );

  static const darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF2759FF),
    onPrimary: Colors.black,
    primaryContainer: Colors.black,
    onPrimaryContainer: Colors.black,
    secondary: Colors.white,
    onSecondary: Colors.black,
    error: Color.fromARGB(255, 236, 3, 3),
    onError: Color.fromARGB(255, 153, 2, 2),
    surface: Colors.black,
    onSurface: Colors.white,
  );
  static const authGradientColors = [Color(0xFF000202), Color(0xFF021F29)];
  // Premium gradients for sporty design
  static const premiumGradient = [
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
    Color(0xFF0F3460),
  ];
  
  static const neonGradient = [
    Color(0xFF39FF14),
    Color(0xFF32CD32),
  ];
  
  static const electricGradient = [
    Color(0xFF00BFFF),
    Color(0xFF1E90FF),
  ];
  
  static const sportGradient = [
    Color(0xFFFF6B35),
    Color(0xFFFF4500),
  ];
  
  // Card gradients
  static const statsCardGradient = [
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
  ];
  
  static const heroGradient = [
    Color(0xFF0A0A0A),
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
  ];
  
  // Legacy gradients updated
  static const overallStatsGradient = [Color(0xFF1A1A2E), Color(0xFF16213E)];
  static const homeGradientColors = [Color(0xFFF8F9FA), Color(0xFFE8E8E8)];
  static const statisticsCardColor = Color(0xFFF8F9FA);
  
  // Action button colors - premium versions
  static const actionButtonColors = [
    Color(0xFF1A1A2E), // Premium dark
    Color(0xFF16213E), // Secondary dark
    Color(0xFF0F3460), // Accent
  ];
  
  static const btnGradient = premiumGradient;
  static const disableButtonColor = [Color(0xFF7D7D7D), Color(0xFF595959)];
  static const activeButtonColor = neonGradient;
}
//#016405, #005b32, #004f47, #00424c, #0b3441