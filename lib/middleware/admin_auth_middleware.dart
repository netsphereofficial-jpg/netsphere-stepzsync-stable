import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/admin/admin_auth_service.dart';
import '../routes/app_routes.dart';

/// Middleware to protect admin routes
/// Ensures only authenticated admin users can access admin pages
class AdminAuthMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    // Only apply middleware to admin routes
    if (route == null || !_isAdminRoute(route)) {
      return null;
    }

    // Check if running on web platform
    if (!kIsWeb) {
      print('⚠️ Admin panel is web-only. Redirecting to home.');
      // Admin panel is web-only, redirect mobile users
      return const RouteSettings(name: '/');
    }

    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('⚠️ User not authenticated. Redirecting to admin login.');
      return RouteSettings(name: AppRoutes.adminLogin);
    }

    // For login route, allow access if not authenticated
    if (route == AppRoutes.adminLogin) {
      return null;
    }

    // For other admin routes, we'll verify admin role in the page itself
    // This prevents blocking the navigation and allows async role check
    return null;
  }

  /// Check if the route is an admin route
  bool _isAdminRoute(String route) {
    return route.startsWith('/admin');
  }
}

/// Guard function to verify admin access on page load
/// Call this in initState or build method of admin pages
Future<bool> verifyAdminAccess(BuildContext context) async {
  try {
    // Check platform
    if (!kIsWeb) {
      print('⚠️ Admin panel is web-only.');
      Get.offAllNamed('/');
      return false;
    }

    // Check authentication
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('⚠️ User not authenticated.');
      Get.offAllNamed(AppRoutes.adminLogin);
      return false;
    }

    // Check admin role
    final isAdmin = await AdminAuthService.isAdmin();
    if (!isAdmin) {
      print('⚠️ User is not an admin.');
      _showAccessDeniedAndRedirect();
      return false;
    }

    print('✅ Admin access verified for: ${user.email}');
    return true;
  } catch (e) {
    print('❌ Error verifying admin access: $e');
    _showAccessDeniedAndRedirect();
    return false;
  }
}

/// Show access denied message and redirect
void _showAccessDeniedAndRedirect() {
  Get.snackbar(
    'Access Denied',
    'You do not have permission to access the admin panel',
    snackPosition: SnackPosition.TOP,
    backgroundColor: Colors.red,
    colorText: Colors.white,
    duration: const Duration(seconds: 3),
  );

  // Sign out and redirect to admin login
  Future.delayed(const Duration(seconds: 2), () {
    AdminAuthService.signOut();
    Get.offAllNamed(AppRoutes.adminLogin);
  });
}
