import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';

class CustomButton extends StatelessWidget {
  final String btnTitle;
  final VoidCallback? onPress;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final double? height;
  final double? width;
  final EdgeInsets? padding;
  final bool isLoading;
  final Widget? icon;

  const CustomButton({
    Key? key,
    required this.btnTitle,
    this.onPress,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.height,
    this.width,
    this.padding,
    this.isLoading = false,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? 48,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPress,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.appColor,
          foregroundColor: textColor ?? Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    textColor ?? Colors.white,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    btnTitle,
                    style: GoogleFonts.poppins(
                      fontSize: fontSize ?? 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// Snackbar utility
void showSnackbar(String title, String message, {Color? backgroundColor}) {
  // This is a placeholder - you may need to implement based on your app's snackbar system
  debugPrint('Snackbar: $title - $message');
}