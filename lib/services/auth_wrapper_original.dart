// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import '../screens/home_screen/home_screen.dart';
// import '../screens/splash_screen.dart';
// import '../screens/login_screen.dart';
// import '../screens/profile/profile_screen.dart';
// import '../widgets/custom_progress_indicator.dart';
// import '../services/profile/profile_service.dart';
// import '../models/profile_models.dart';
// import 'preferences_service.dart';
// import 'firebase_service.dart';
//
// class AuthWrapper extends StatelessWidget {
//   const AuthWrapper({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final firebaseService = Get.find<FirebaseService>();
//
//     return StreamBuilder<User?>(
//       stream: firebaseService.getAuthStateChanges(),
//       builder: (context, authSnapshot) {
//         if (authSnapshot.connectionState == ConnectionState.waiting) {
//           return _buildLoadingScreen();
//         }
//
//         return _buildAppFlow(authSnapshot.data);
//       },
//     );
//   }
//
//   Widget _buildLoadingScreen() {
//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [Colors.black, Colors.grey[900]!, Colors.black87],
//             stops: [0.0, 0.5, 1.0],
//           ),
//         ),
//         child: const Center(
//           child: CustomProgressIndicator(),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildAppFlow(User? user) {
//     return FutureBuilder<OnboardingStatus>(
//       future: Get.find<PreferencesService>().getOnboardingStatus(),
//       builder: (context, onboardingSnapshot) {
//         if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
//           return _buildLoadingScreen();
//         }
//
//         final onboardingStatus = onboardingSnapshot.data ?? OnboardingStatus.firstTime;
//
//         // User is authenticated - check profile completion regardless of onboarding status
//         if (user != null) {
//           // If still in onboarding flow but authenticated, handle appropriately
//           switch (onboardingStatus) {
//             case OnboardingStatus.firstTime:
//               return SplashScreen();
//             case OnboardingStatus.permissionsPending:
//               return PermissionPage();
//             case OnboardingStatus.completed:
//               // Check if user profile is completed
//               return FutureBuilder<bool>(
//                 future: _checkAndCreateProfile(user!),
//                 builder: (context, profileSnapshot) {
//
//                   if (profileSnapshot.connectionState == ConnectionState.waiting) {
//                     return _buildLoadingScreen();
//                   }
//
//                   // If profile doesn't exist or is incomplete, go to profile screen
//                   if (!profileSnapshot.hasData || !profileSnapshot.data!) {
//                     return ProfileScreen();
//                   }
//
//                   // Profile exists and is completed, go to home screen
//                   return HomeScreen();
//                 },
//               );
//           }
//         }
//
//         // User is not authenticated - follow normal onboarding flow
//         switch (onboardingStatus) {
//           case OnboardingStatus.firstTime:
//             return SplashScreen();
//           case OnboardingStatus.permissionsPending:
//             return PermissionPage();
//           case OnboardingStatus.completed:
//             return LoginScreen();
//         }
//       },
//     );
//   }
//
//   /// Check if profile exists and create initial one if needed
//   Future<bool> _checkAndCreateProfile(User user) async {
//     try {
//       print('🔍 AuthWrapper: Checking profile for user: ${user.uid}');
//       print('📧 User email: ${user.email}');
//
//       // First check if profile document exists
//       bool documentExists = await ProfileService.profileDocumentExists();
//       print('📄 Profile document exists: $documentExists');
//
//       if (!documentExists) {
//         print('🔧 Creating initial profile document...');
//         // Create initial profile document
//         await _createInitialProfile(user);
//         print('✅ Initial profile creation attempted');
//       }
//
//       // Now check if profile is completed
//       bool isCompleted = await ProfileService.isProfileCompleted();
//       print('✅ Profile completed status: $isCompleted');
//
//       return isCompleted;
//     } catch (e) {
//       print('❌ Error checking/creating profile: $e');
//       print('📍 Stack trace: ${StackTrace.current}');
//       return false; // Default to profile screen if there's an error
//     }
//   }
//
//   /// Create initial incomplete profile
//   Future<void> _createInitialProfile(User user) async {
//     try {
//       print('🏗️ Creating profile object...');
//       final initialProfile = UserProfile(
//         email: user.email ?? '',
//         fullName: '',
//         phoneNumber: '',
//         countryCode: '+91',
//         gender: '',
//         location: '',
//         height: 0,
//         heightUnit: 'cms',
//         weight: 0,
//         weightUnit: 'Kgs',
//         profileCompleted: false,
//         healthKitEnabled: false,
//         createdAt: DateTime.now(),
//         updatedAt: DateTime.now(),
//       );
//
//       print('📝 Profile object created, calling saveInitialProfile...');
//       final result = await ProfileService.saveInitialProfile(initialProfile);
//
//       if (result.success) {
//         print('✅ Profile saved successfully in Firestore');
//       } else {
//         print('❌ Profile save failed: ${result.error}');
//       }
//     } catch (e) {
//       print('❌ Failed to create initial profile in AuthWrapper: $e');
//       print('📍 Stack trace: ${StackTrace.current}');
//     }
//   }
// }