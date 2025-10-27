import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// One-time admin setup helper
/// Run this ONCE to create admin user profile in Firestore
class AdminSetupHelper {
  static Future<void> createAdminProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      print('❌ No user logged in. Please sign in first.');
      return;
    }

    print('🔧 Creating admin profile for UID: ${user.uid}');
    print('📧 Email: ${user.email}');

    try {
      // Check if profile already exists
      final docRef = FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(user.uid);

      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        print('⚠️ Profile already exists. Updating role to admin...');
        await docRef.update({
          'role': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Profile updated with admin role!');
      } else {
        print('📝 Creating new admin profile...');
        await docRef.set({
          'email': user.email ?? '',
          'fullName': 'Admin User',
          'role': 'admin',
          'profileCompleted': true,
          'phoneNumber': '',
          'countryCode': '+91',
          'gender': '',
          'location': '',
          'height': 0,
          'heightUnit': 'cms',
          'weight': 0,
          'weightUnit': 'Kgs',
          'healthKitEnabled': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Admin profile created successfully!');
      }

      print('');
      print('🎉 Setup complete! Please:');
      print('   1. Refresh the page (Cmd+R or Ctrl+R)');
      print('   2. You should now have admin access');

    } catch (e) {
      print('❌ Error creating admin profile: $e');
    }
  }
}
