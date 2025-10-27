import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../../core/themes/app_colors.dart';
import '../../core/constants/app_constants.dart';

class MobileInputField extends StatelessWidget {
  final TextEditingController controller;
  final CountryCode selectedCountry;
  final void Function(CountryCode) onCountryChanged;

  const MobileInputField({
    super.key,
    required this.controller,
    required this.selectedCountry,
    required this.onCountryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        color: AppColors.surface,
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            spreadRadius: 1,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            margin: EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: CountryCodePicker(
              onChanged: onCountryChanged,
              initialSelection: selectedCountry.code,
              showFlag: true,
              showCountryOnly: true,
              padding: EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.defaultPadding,
                vertical: 4,
              ),
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter your Number',
                  hintStyle: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  suffixIcon: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: Icon(
                      Icons.phone_android_rounded,
                      color: AppColors.primary.withOpacity(0.6),
                      size: 20,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultPadding,
                    vertical: AppConstants.defaultPadding,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}