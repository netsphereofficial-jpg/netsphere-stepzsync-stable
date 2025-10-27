import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/auth_models.dart';

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload profile image to Firebase Storage
  static Future<AuthResult> uploadProfileImage(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure(error: 'User not authenticated');
      }

      // Create a unique file name
      final String fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Reference to the storage location
      final Reference ref = _storage
          .ref()
          .child('profile_images')
          .child(user.uid)
          .child(fileName);

      // Upload the file
      final UploadTask uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': user.uid,
            'uploadTime': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return AuthResult.success(
        message: 'Profile image uploaded successfully',
        data: downloadUrl,
      );
    } on FirebaseException catch (e) {
      return AuthResult.failure(
        error: 'Failed to upload image: ${e.message}',
      );
    } catch (e) {
      return AuthResult.failure(
        error: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  /// Delete profile image from Firebase Storage
  static Future<AuthResult> deleteProfileImage(String imageUrl) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure(error: 'User not authenticated');
      }

      // Get reference from URL
      final Reference ref = _storage.refFromURL(imageUrl);

      // Delete the file
      await ref.delete();

      return AuthResult.success(
        message: 'Profile image deleted successfully',
      );
    } on FirebaseException catch (e) {
      return AuthResult.failure(
        error: 'Failed to delete image: ${e.message}',
      );
    } catch (e) {
      return AuthResult.failure(
        error: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  /// Update profile image (delete old and upload new)
  static Future<AuthResult> updateProfileImage(File newImageFile, String? oldImageUrl) async {
    try {
      // Delete old image if exists
      if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
        await deleteProfileImage(oldImageUrl);
      }

      // Upload new image
      final uploadResult = await uploadProfileImage(newImageFile);
      return uploadResult;
    } catch (e) {
      return AuthResult.failure(
        error: 'Failed to update profile image: ${e.toString()}',
      );
    }
  }

  /// Get current user's profile images folder reference
  static Reference? getUserProfileImagesRef() {
    final user = _auth.currentUser;
    if (user == null) return null;

    return _storage
        .ref()
        .child('profile_images')
        .child(user.uid);
  }

  /// Clean up old profile images for current user
  static Future<AuthResult> cleanupOldProfileImages() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure(error: 'User not authenticated');
      }

      final Reference userImagesRef = _storage
          .ref()
          .child('profile_images')
          .child(user.uid);

      final ListResult result = await userImagesRef.listAll();

      // Sort by creation time and keep only the latest 3 images
      final List<Reference> items = result.items;
      if (items.length > 3) {
        // Get metadata for each item to sort by creation time
        final List<MapEntry<Reference, DateTime>> itemsWithTime = [];

        for (final item in items) {
          try {
            final metadata = await item.getMetadata();
            final uploadTime = metadata.customMetadata?['uploadTime'];
            if (uploadTime != null) {
              itemsWithTime.add(MapEntry(item, DateTime.parse(uploadTime)));
            }
          } catch (e) {
            // If we can't get metadata, use a very old date
            itemsWithTime.add(MapEntry(item, DateTime(2000)));
          }
        }

        // Sort by time (newest first)
        itemsWithTime.sort((a, b) => b.value.compareTo(a.value));

        // Delete items beyond the first 3
        for (int i = 3; i < itemsWithTime.length; i++) {
          try {
            await itemsWithTime[i].key.delete();
          } catch (e) {
            print('Failed to delete old profile image: $e');
          }
        }
      }

      return AuthResult.success(
        message: 'Cleanup completed successfully',
      );
    } on FirebaseException catch (e) {
      return AuthResult.failure(
        error: 'Failed to cleanup images: ${e.message}',
      );
    } catch (e) {
      return AuthResult.failure(
        error: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }
}