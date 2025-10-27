import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

class ProfileImageWidget extends StatelessWidget {
  final String? imageUrl;
  final File? imageFile;
  final double size;
  final VoidCallback? onTap;
  final bool showEditIcon;
  final Color borderColor;
  final double borderWidth;

  const ProfileImageWidget({
    Key? key,
    this.imageUrl,
    this.imageFile,
    this.size = 120,
    this.onTap,
    this.showEditIcon = false,
    this.borderColor = Colors.transparent,
    this.borderWidth = 3,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor.opacity > 0
                    ? borderColor
                    : AppColors.appColor.withOpacity(0.3),
                width: borderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: _buildImageContent(),
            ),
          ),
          if (showEditIcon)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: AppColors.appColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: size * 0.15,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageContent() {
    // Show local file first (for editing)
    if (imageFile != null) {
      return Image.file(
        imageFile!,
        fit: BoxFit.cover,
        width: size,
        height: size,
      );
    }

    // Show network image
    if (imageUrl?.isNotEmpty ?? false) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderAvatar();
        },
      );
    }

    // Show placeholder
    return _buildPlaceholderAvatar();
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade200,
      ),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.appColor),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.appColor.withOpacity(0.1),
            AppColors.appColor.withOpacity(0.05),
          ],
        ),
      ),
      child: Icon(
        Icons.person,
        size: size * 0.4,
        color: AppColors.appColor.withOpacity(0.6),
      ),
    );
  }
}

/// A specialized profile image widget for small avatars in lists
class ProfileAvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String? userName;
  final double size;
  final VoidCallback? onTap;

  const ProfileAvatarWidget({
    Key? key,
    this.imageUrl,
    this.userName,
    this.size = 40,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.appColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ClipOval(
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (imageUrl?.isNotEmpty ?? false) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) {
          return _buildInitialsAvatar();
        },
      );
    }

    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    final initials = _getInitials(userName ?? 'U');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.appColor.withOpacity(0.8),
            AppColors.appColor.withOpacity(0.6),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';

    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }

    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
  }
}