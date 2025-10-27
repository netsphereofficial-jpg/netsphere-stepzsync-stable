import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../core/constants/app_constants.dart';

class CustomDropDown extends StatelessWidget {
  final List<String> itemValues;
  final List<String> itemLabels;
  final String selectedValue;
  final String hint;
  final ValueChanged<String> onChanged;
  final Color? borderColor;

  const CustomDropDown({
    super.key,
    required this.itemValues,
    required this.itemLabels,
    required this.selectedValue,
    required this.hint,
    required this.onChanged,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 10, bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        color: Colors.white,
        border: Border.all(
          color: borderColor ?? AppColors.appColor.withOpacity(0.1),
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
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppConstants.defaultPadding,
          vertical: 4,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedValue.isEmpty ? null : selectedValue,
            hint: Text(
              hint,
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            isExpanded: true,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.appColor,
            ),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            items: itemValues.asMap().entries.map((entry) {
              final index = entry.key;
              final value = entry.value;
              final label = index < itemLabels.length ? itemLabels[index] : value;
              
              if (value.isEmpty) return null; // Skip empty values
              
              return DropdownMenuItem<String>(
                value: value,
                child: Text(label),
              );
            }).where((item) => item != null).cast<DropdownMenuItem<String>>().toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                onChanged(newValue);
              }
            },
          ),
        ),
      ),
    );
  }
}