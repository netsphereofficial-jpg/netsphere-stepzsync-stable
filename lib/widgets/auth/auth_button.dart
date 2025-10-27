import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../core/constants/app_constants.dart';

class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isSecondary;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;

  const AuthButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? 
        (isSecondary ? Colors.white : AppColors.appColor);
    final tColor = textColor ?? 
        (isSecondary ? AppColors.appColor : Colors.white);

    return GestureDetector(
      onTap: isLoading ? null : () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: AnimatedContainer(
        duration: AppConstants.defaultAnimationDuration,
        width: double.infinity,
        height: AppConstants.buttonHeight,
        decoration: BoxDecoration(
          gradient: isSecondary ? null : LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              bgColor,
              bgColor.withOpacity(0.8),
            ],
          ),
          color: isSecondary ? bgColor : null,
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          border: isSecondary ? Border.all(
            color: AppColors.appColor.withOpacity(0.3),
            width: 1.5,
          ) : null,
          boxShadow: isSecondary ? null : [
            BoxShadow(
              color: AppColors.appColor.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 2,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(tColor),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        color: tColor,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                    ],
                    Text(
                      text,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tColor,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}