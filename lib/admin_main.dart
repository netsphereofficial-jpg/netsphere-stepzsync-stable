import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'screens/admin/simple_admin_login.dart';
import 'screens/admin/enhanced_admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase Service for admin panel
  final firebaseService = FirebaseService();
  await firebaseService.ensureInitialized();
  Get.put(firebaseService, permanent: true);

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StepzSync Admin Panel',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2759FF),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1a1a1a),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.grey[200]!,
              width: 1,
            ),
          ),
        ),
      ),
      initialRoute: '/admin-login',
      getPages: [
        GetPage(
          name: '/admin-login',
          page: () => const AdminLoginScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/admin-dashboard',
          page: () => const EnhancedAdminDashboardScreen(),
          transition: Transition.fadeIn,
        ),
      ],
    );
  }
}
