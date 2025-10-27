import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../core/constants/app_constants.dart';

class RoundedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool isReadOnly;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatter;
  final Widget? suffixIcon;
  final VoidCallback? onClick;
  final ValueChanged<String>? onChanged;

  const RoundedTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.isReadOnly = false,
    this.maxLength,
    this.inputFormatter,
    this.suffixIcon,
    this.onClick,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 10, bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        color: Colors.white,
        border: Border.all(
          color: AppColors.appColor.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        // Disable spell check to prevent double yellow underlines
        spellCheckConfiguration: SpellCheckConfiguration(spellCheckService: null),
        enableSuggestions: false,
        autocorrect: false,
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        readOnly: isReadOnly,
        maxLength: maxLength,
        inputFormatters: inputFormatter,
        onTap: onClick,
        onChanged: onChanged,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppConstants.defaultPadding,
            vertical: AppConstants.defaultPadding,
          ),
          suffixIcon: suffixIcon,
          counterText: '', // Hide character counter
        ),
      ),
    );
  }
}