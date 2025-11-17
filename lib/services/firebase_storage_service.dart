import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/auth_models.dart';

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Compress image before upload
  static Future<File?> _compressImage(File imageFile) async {
    try {
      // Get file size
      final fileSizeInBytes = await imageFile.length();
      final fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      // If file is larger than 5MB, reject it
      if (fileSizeInMB > 5) {
        throw Exception('Image size must be less than 5MB. Current size: ${fileSizeInMB.toStringAsFixed(2)}MB');
      }

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Compress image
      final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 75,
        minWidth: 512,
        minHeight: 512,
        format: CompressFormat.jpeg,
      );

      if (compressedFile == null) {
        return null;
      }

      return File(compressedFile.path);
    } catch (e) {
      print('Image compression error: $e');
      rethrow;
    }
  }

  /// Upload profile image to Firebase Storage with progress callback
  static Future<AuthResult> uploadProfileImage(
    File imageFile, {
    Function(double)? onProgress,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure(error: 'User not authenticated');
      }

      // Report compression progress
      onProgress?.call(0.1); // 10% - Starting compression

      // Compress image before upload
      final File? compressedImage = await _compressImage(imageFile);
      if (compressedImage == null) {
        return AuthResult.failure(error: 'Failed to compress image');
      }

      onProgress?.call(0.2); // 20% - Compression complete

      // Add timestamp to URL for cache-busting
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final String fileName = 'profile_${user.uid}_$timestamp.jpg';

      // Reference to the storage location
      final Reference ref = _storage
          .ref()
          .child('profile_images')
          .child(user.uid)
          .child(fileName);

      // Upload the compressed file
      final UploadTask uploadTask = ref.putFile(
        compressedImage,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=3600',
          customMetadata: {
            'userId': user.uid,
            'uploadTime': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        // Map 20%-90% to upload progress
        final mappedProgress = 0.2 + (progress * 0.7);
        onProgress?.call(mappedProgress);
      });

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;

      onProgress?.call(0.95); // 95% - Upload complete, getting URL

      // Get download URL with cache-busting timestamp
      String downloadUrl = await snapshot.ref.getDownloadURL();
      downloadUrl = '$downloadUrl?t=$timestamp';

      onProgress?.call(1.0); // 100% - Complete

      // Clean up compressed file
      try {
        await compressedImage.delete();
      } catch (e) {
        print('Failed to delete temporary file: $e');
      }

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

  /// Update profile image (upload new, skip deletion for speed)
  static Future<AuthResult> updateProfileImage(
    File newImageFile,
    String? oldImageUrl, {
    Function(double)? onProgress,
  }) async {
    try {
      // Upload new image with progress tracking
      // Skip deletion for speed - cleanup will happen later
      final uploadResult = await uploadProfileImage(
        newImageFile,
        onProgress: onProgress,
      );

      // Schedule old image deletion in background (non-blocking)
      if (uploadResult.success && oldImageUrl != null && oldImageUrl.isNotEmpty) {
        // Delete old image asynchronously without waiting
        deleteProfileImage(oldImageUrl).catchError((e) {
          print('Background deletion failed: $e');
          return AuthResult.failure(error: e.toString());
        });
      }

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