import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// StepzSync Design System v2.0 - Clean Minimalist
/// All design constants and reusable components for auth screens

class AppDesignColors {
  // Primary colors
  static const Color primary = Color(0xFF2759FF); // Main headings, buttons, links
  static const Color secondary = Color(0xFF7788B3); // Subtitles, secondary text
  static const Color label = Color(0xFF3F4E75); // Field labels, hints
  static const Color fieldBackground = Color(0xFFEFF2F8); // Text field backgrounds
  static const Color background = Color(0xFFFFFFFF); // Screen background

  // Additional colors
  static const Color error = Color(0xFFE74C3C);
  static const Color success = Color(0xFF27AE60);
  static const Color textDark = Color(0xFF2C3E50);
  static const Color divider = Color(0xFFE0E0E0);
}

class AppTextStyles {
  // Headings
  static TextStyle heading = GoogleFonts.roboto(
    fontSize: 34,
    fontWeight: FontWeight.bold,
    color: AppDesignColors.primary,
    height: 1.2,
  );

  static TextStyle subtitle = GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppDesignColors.secondary,
    height: 1.4,
  );

  // Field labels
  static TextStyle fieldLabel = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppDesignColors.label,
    height: 1.5,
  );

  // Button text
  static TextStyle buttonText = GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    height: 1.2,
  );

  // Body text
  static TextStyle bodyText = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppDesignColors.textDark,
    height: 1.5,
  );

  // Link text
  static TextStyle linkText = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppDesignColors.primary,
    height: 1.5,
  );

  // Field input text
  static TextStyle fieldInput = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppDesignColors.textDark,
    height: 1.5,
  );

  // Field hint text
  static TextStyle fieldHint = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppDesignColors.secondary.withOpacity(0.6),
    height: 1.5,
  );
}

class AppSpacing {
  // Screen padding
  static const double screenHorizontal = 24.0;
  static const double screenVertical = 32.0;

  // Section spacing
  static const double sectionSpacing = 40.0;

  // Field spacing
  static const double fieldSpacing = 16.0;
  static const double labelFieldGap = 8.0;

  // Button
  static const double buttonHeight = 56.0;
  static const double buttonSpacing = 24.0;

  // Small spacing
  static const double small = 8.0;
  static const double medium = 16.0;
  static const double large = 24.0;
  static const double xlarge = 32.0;
}

class AppRadius {
  static const double textField = 12.0;
  static const double button = 12.0;
  static const double card = 16.0;
  static const double small = 8.0;
}

/// Reusable Text Field Component
class AuthTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  const AuthTextField({
    Key? key,
    required this.label,
    required this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.inputFormatters,
    this.maxLength,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.fieldLabel,
        ),
        SizedBox(height: AppSpacing.labelFieldGap),
        Container(
          decoration: BoxDecoration(
            color: AppDesignColors.fieldBackground,
            borderRadius: BorderRadius.circular(AppRadius.textField),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            style: AppTextStyles.fieldInput,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.fieldHint,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon: suffixIcon,
              counterText: '', // Hide character counter
            ),
          ),
        ),
      ],
    );
  }
}

/// Reusable Button Component
class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const AuthButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppDesignColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          disabledBackgroundColor: AppDesignColors.primary.withOpacity(0.6),
        ),
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: AppTextStyles.buttonText,
              ),
      ),
    );
  }
}

/// Guest Mode Button (Outlined style)
class GuestButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const GuestButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppDesignColors.primary,
          side: BorderSide(
            color: AppDesignColors.primary,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          backgroundColor: Colors.transparent,
        ),
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppDesignColors.primary,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 20,
                    color: AppDesignColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    text,
                    style: AppTextStyles.buttonText.copyWith(
                      color: AppDesignColors.primary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Reusable Divider with "or" text
class AuthDivider extends StatelessWidget {
  final String text;

  const AuthDivider({
    Key? key,
    this.text = 'or',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AppDesignColors.divider,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: AppTextStyles.fieldLabel.copyWith(
              color: AppDesignColors.secondary,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: AppDesignColors.divider,
          ),
        ),
      ],
    );
  }
}

/// Social Login Button (Circular logo)
class SocialLoginButton extends StatelessWidget {
  final Widget logo;
  final VoidCallback? onTap;
  final bool isLoading;

  const SocialLoginButton({
    Key? key,
    required this.logo,
    this.onTap,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppDesignColors.fieldBackground,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppDesignColors.primary,
                    ),
                  ),
                )
              : logo,
        ),
      ),
    );
  }
}

/// Bottom text with action link
class BottomActionText extends StatelessWidget {
  final String normalText;
  final String actionText;
  final VoidCallback onActionTap;

  const BottomActionText({
    Key? key,
    required this.normalText,
    required this.actionText,
    required this.onActionTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onActionTap,
      child: RichText(
        text: TextSpan(
          text: normalText,
          style: AppTextStyles.bodyText.copyWith(
            color: AppDesignColors.secondary,
            fontSize: 14,
          ),
          children: [
            TextSpan(
              text: actionText,
              style: AppTextStyles.linkText.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
