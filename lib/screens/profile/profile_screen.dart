import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../config/design_system.dart';
import '../../controllers/profile/profile_controller.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../screens/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String? userId;
  final String? name;

  ProfileScreen({super.key, this.userId, this.name});

  @override
  Widget build(BuildContext context) {
    // Ensure controller exists before trying to find it
    if (!Get.isRegistered<ProfileController>()) {
      Get.put(ProfileController(), permanent: true);
    }
    final controller = Get.find<ProfileController>();
    controller.initializeName(name);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onBackDialog(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppDesignColors.background,
        body: SafeArea(
          child: Obx(() {
            return Column(
              children: [
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                        vertical: AppSpacing.screenVertical,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main Heading
                          Text(
                            'Add Your Details',
                            style: AppTextStyles.heading,
                          ),
                          SizedBox(height: 8),

                          // Subtitle
                          Text(
                            '* = Mandatory',
                            style: AppTextStyles.subtitle,
                          ),
                          SizedBox(height: AppSpacing.sectionSpacing),

                          // Full Name
                          AuthTextField(
                            label: 'Full Name *',
                            hint: 'Enter your full name',
                            controller: controller.nameCtr,
                            keyboardType: TextInputType.name,
                            maxLength: 30,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                              _CapitalizeWordsFormatter(),
                            ],
                          ),
                          SizedBox(height: AppSpacing.fieldSpacing),

                          // Username
                          _buildUsernameField(controller),
                          SizedBox(height: AppSpacing.fieldSpacing),

                          // Gender
                          _buildGenderField(controller),
                          SizedBox(height: AppSpacing.fieldSpacing),

                          // Date of Birth
                          _buildDateOfBirthField(controller),
                          SizedBox(height: AppSpacing.fieldSpacing),

                          // Location
                          _buildLocationField(controller),
                          SizedBox(height: AppSpacing.fieldSpacing),

                          // Height
                          _buildHeightField(controller),
                          SizedBox(height: AppSpacing.fieldSpacing),

                          // Weight
                          _buildWeightField(controller),
                        ],
                      ),
                    ),
                  ),
                ),

                // Sticky Submit Button at bottom
                Container(
                  padding: EdgeInsets.only(
                    left: AppSpacing.screenHorizontal,
                    right: AppSpacing.screenHorizontal,
                    bottom: AppSpacing.buttonSpacing,
                    top: AppSpacing.medium,
                  ),
                  decoration: BoxDecoration(
                    color: AppDesignColors.background,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: AuthButton(
                    text: "Submit",
                    onPressed: controller.addDetailsClick,
                    isLoading: controller.isLoading.value,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }


  Widget _buildGenderField(ProfileController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender *',
          style: AppTextStyles.fieldLabel,
        ),
        SizedBox(height: AppSpacing.labelFieldGap),
        Obx(() {
          return Row(
            children: [
              // Male Option
              Expanded(
                child: _buildGenderOption(
                  label: 'Male',
                  icon: Icons.male_rounded,
                  value: '1',
                  isSelected: controller.gender.value == '1',
                  onTap: () {
                    controller.gender.value = '1';
                    controller.gender.refresh();
                  },
                ),
              ),
              SizedBox(width: 12),
              // Female Option
              Expanded(
                child: _buildGenderOption(
                  label: 'Female',
                  icon: Icons.female_rounded,
                  value: '2',
                  isSelected: controller.gender.value == '2',
                  onTap: () {
                    controller.gender.value = '2';
                    controller.gender.refresh();
                  },
                ),
              ),
              SizedBox(width: 12),
              // No Preference Option
              Expanded(
                child: _buildGenderOption(
                  label: 'Other',
                  icon: Icons.transgender_rounded,
                  value: '3',
                  isSelected: controller.gender.value == '3',
                  onTap: () {
                    controller.gender.value = '3';
                    controller.gender.refresh();
                  },
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildGenderOption({
    required String label,
    required IconData icon,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
            ? AppDesignColors.primary
            : AppDesignColors.fieldBackground,
          borderRadius: BorderRadius.circular(AppRadius.textField),
          border: Border.all(
            color: isSelected
              ? AppDesignColors.primary
              : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                ? Colors.white
                : AppDesignColors.label,
              size: 28,
            ),
            SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.fieldLabel.copyWith(
                color: isSelected
                  ? Colors.white
                  : AppDesignColors.label,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateOfBirthField(ProfileController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date of Birth *',
          style: AppTextStyles.fieldLabel,
        ),
        SizedBox(height: AppSpacing.labelFieldGap),
        Container(
          decoration: BoxDecoration(
            color: AppDesignColors.fieldBackground,
            borderRadius: BorderRadius.circular(AppRadius.textField),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.dobController,
                  style: AppTextStyles.fieldInput,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    hintText: 'DD/MM/YYYY',
                    hintStyle: AppTextStyles.fieldHint,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                    _DateInputFormatter(),
                  ],
                  onChanged: (value) {
                    // Parse manual date entry
                    if (value.length == 10) {
                      final parts = value.split('/');
                      if (parts.length == 3) {
                        try {
                          final day = int.parse(parts[0]);
                          final month = int.parse(parts[1]);
                          final year = int.parse(parts[2]);
                          final date = DateTime(year, month, day);
                          controller.selectedDate.value = date;
                        } catch (e) {
                          // Invalid date, ignore
                        }
                      }
                    }
                  },
                ),
              ),
              GestureDetector(
                onTap: () => _showCustomDatePicker(controller),
                child: Icon(
                  Icons.calendar_today_rounded,
                  color: AppDesignColors.label,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showCustomDatePicker(ProfileController controller) async {
    final DateTime? picked = await showDatePicker(
      context: Get.context!,
      initialDate: controller.selectedDate.value ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppDesignColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppDesignColors.textDark,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppDesignColors.primary,
                textStyle: AppTextStyles.bodyText.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              headerBackgroundColor: AppDesignColors.primary,
              headerForegroundColor: Colors.white,
              dayStyle: AppTextStyles.bodyText,
              yearStyle: AppTextStyles.bodyText,
              weekdayStyle: AppTextStyles.fieldLabel.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                if (states.contains(WidgetState.disabled)) {
                  return AppDesignColors.secondary.withOpacity(0.4);
                }
                return AppDesignColors.textDark;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppDesignColors.primary;
                }
                return Colors.transparent;
              }),
              todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppDesignColors.primary;
                }
                return Colors.transparent;
              }),
              todayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return AppDesignColors.primary;
              }),
              todayBorder: BorderSide(
                color: AppDesignColors.primary,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.selectedDate.value = picked;
      controller.dobController.text = _formatDate(picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Widget _buildLocationField(ProfileController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location *',
          style: AppTextStyles.fieldLabel,
        ),
        SizedBox(height: AppSpacing.labelFieldGap),
        GestureDetector(
          onTap: controller.getCurrentLocation,
          child: Container(
            decoration: BoxDecoration(
              color: AppDesignColors.fieldBackground,
              borderRadius: BorderRadius.circular(AppRadius.textField),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.locationCtr,
                    enabled: false,
                    style: AppTextStyles.fieldInput,
                    decoration: InputDecoration(
                      hintText: 'Tap to get current location',
                      hintStyle: AppTextStyles.fieldHint,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Icon(
                  Icons.my_location_rounded,
                  color: AppDesignColors.label,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeightField(ProfileController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Height *',
          style: AppTextStyles.fieldLabel,
        ),
        SizedBox(height: AppSpacing.labelFieldGap),
        GestureDetector(
          onTap: () => _showHeightPicker(Get.context!, controller),
          child: Container(
            decoration: BoxDecoration(
              color: AppDesignColors.fieldBackground,
              borderRadius: BorderRadius.circular(AppRadius.textField),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.heightCtr,
                    enabled: false,
                    style: AppTextStyles.fieldInput,
                    decoration: InputDecoration(
                      hintText: 'Select your height',
                      hintStyle: AppTextStyles.fieldHint,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                _buildUnitButton('cm', false, controller),
                SizedBox(width: 4),
                _buildUnitButton('in', false, controller),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeightField(ProfileController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weight *',
          style: AppTextStyles.fieldLabel,
        ),
        SizedBox(height: AppSpacing.labelFieldGap),
        GestureDetector(
          onTap: () => _showWeightPicker(Get.context!, controller),
          child: Container(
            decoration: BoxDecoration(
              color: AppDesignColors.fieldBackground,
              borderRadius: BorderRadius.circular(AppRadius.textField),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.weightCtr,
                    enabled: false,
                    style: AppTextStyles.fieldInput,
                    decoration: InputDecoration(
                      hintText: 'Select your weight',
                      hintStyle: AppTextStyles.fieldHint,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                _buildUnitButton('Kg', true, controller),
                SizedBox(width: 4),
                _buildUnitButton('Lb', true, controller),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitButton(String unit, bool isWeight, ProfileController controller) {
    return Obx(() {
      String fullUnit = unit;
      if (isWeight) {
        if (unit == 'Kg') fullUnit = 'Kgs';
        if (unit == 'Lb') fullUnit = 'Lbs';
      } else {
        if (unit == 'cm') fullUnit = 'cms';
        if (unit == 'in') fullUnit = 'inches';
      }

      final isSelected = isWeight
          ? controller.selectedUnit.value == fullUnit
          : controller.selectedMetric.value == fullUnit;

      return GestureDetector(
        onTap: () => controller.setUnit(fullUnit, isWeight),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppDesignColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppDesignColors.primary : AppDesignColors.label.withOpacity(0.3),
            ),
          ),
          child: Text(
            unit,
            style: AppTextStyles.fieldLabel.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppDesignColors.label,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildUsernameField(ProfileController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Username *',
          style: AppTextStyles.fieldLabel,
        ),
        SizedBox(height: AppSpacing.labelFieldGap),
        Container(
          decoration: BoxDecoration(
            color: AppDesignColors.fieldBackground,
            borderRadius: BorderRadius.circular(AppRadius.textField),
          ),
          child: Row(
            children: [
              // @ Prefix
              Padding(
                padding: EdgeInsets.only(left: 16),
                child: Text(
                  '@',
                  style: AppTextStyles.fieldInput.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppDesignColors.primary,
                  ),
                ),
              ),
              // Username TextField
              Expanded(
                child: TextField(
                  controller: controller.usernameCtr,
                  keyboardType: TextInputType.text,
                  maxLength: 20,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                  ],
                  style: AppTextStyles.fieldInput,
                  decoration: InputDecoration(
                    hintText: 'Choose a unique username',
                    hintStyle: AppTextStyles.fieldHint,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 16,
                    ),
                    counterText: '',
                  ),
                ),
              ),
              // Status Icon
              Obx(() {
                if (controller.isCheckingUsername.value) {
                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppDesignColors.primary),
                      ),
                    ),
                  );
                } else if (controller.usernameStatus.value == UsernameStatus.available) {
                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: Icon(
                      Icons.check_circle,
                      color: AppDesignColors.success,
                      size: 20,
                    ),
                  );
                } else if (controller.usernameStatus.value == UsernameStatus.taken) {
                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: Icon(
                      Icons.cancel,
                      color: AppDesignColors.error,
                      size: 20,
                    ),
                  );
                }
                return SizedBox(width: 16);
              }),
            ],
          ),
        ),
      ],
    );
  }

  void _onBackDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppDesignColors.primary),
              SizedBox(width: 8),
              Text(
                'Incomplete Profile',
                style: AppTextStyles.bodyText.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Text(
            'Your profile is incomplete. If you go back, you\'ll need to sign in again. Are you sure?',
            style: AppTextStyles.bodyText,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyText.copyWith(
                  color: AppDesignColors.secondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuthService.signOut();
                Get.offAll(() => LoginScreen());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Sign Out',
                style: AppTextStyles.bodyText.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showHeightPicker(BuildContext context, ProfileController controller) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => _buildHeightPickerModal(context, controller),
    );
  }

  void _showWeightPicker(BuildContext context, ProfileController controller) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => _buildWeightPickerModal(context, controller),
    );
  }

  Widget _buildHeightPickerModal(BuildContext context, ProfileController controller) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: true,
        child: Container(
          height: 400,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: constraints.maxWidth,
                    child: _buildPickerHeader('Select Height', false, controller),
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: constraints.maxWidth,
                      child: _buildHeightPicker(controller),
                    ),
                  ),
                  Container(
                    width: constraints.maxWidth,
                    child: _buildPickerDoneButton(context, controller),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWeightPickerModal(BuildContext context, ProfileController controller) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: true,
        child: Container(
          height: 400,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: constraints.maxWidth,
                    child: _buildPickerHeader('Select Weight', true, controller),
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: constraints.maxWidth,
                      child: _buildWeightPicker(controller),
                    ),
                  ),
                  Container(
                    width: constraints.maxWidth,
                    child: _buildPickerDoneButton(context, controller),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPickerHeader(String title, bool isWeight, ProfileController controller) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppDesignColors.fieldBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: IntrinsicHeight(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              child: Text(
                title,
                style: AppTextStyles.bodyText.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              child: _buildCustomUnitSelector(isWeight, controller),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomUnitSelector(bool isWeight, ProfileController controller) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppDesignColors.label.withOpacity(0.2)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Obx(() {
                final isSelected = isWeight ? controller.useKg.value : controller.useCm.value;
                return GestureDetector(
                  onTap: () {
                    if (isWeight) {
                      controller.useKg.value = true;
                      controller.selectedUnit.value = 'Kgs';
                      controller.updateWeightDisplay();
                    } else {
                      controller.useCm.value = true;
                      controller.selectedMetric.value = 'cms';
                      controller.updateHeightDisplay();
                    }
                  },
                  child: Container(
                    constraints: BoxConstraints(minHeight: 40),
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? AppDesignColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isWeight ? 'Kgs' : 'Cms',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : AppDesignColors.textDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }),
            ),
            Expanded(
              child: Obx(() {
                final isSelected = isWeight ? !controller.useKg.value : !controller.useCm.value;
                return GestureDetector(
                  onTap: () {
                    if (isWeight) {
                      controller.useKg.value = false;
                      controller.selectedUnit.value = 'Lbs';
                      controller.updateWeightDisplay();
                    } else {
                      controller.useCm.value = false;
                      controller.selectedMetric.value = 'inches';
                      controller.updateHeightDisplay();
                    }
                  },
                  child: Container(
                    constraints: BoxConstraints(minHeight: 40),
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? AppDesignColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isWeight ? 'Lbs' : 'Inches',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : AppDesignColors.textDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeightPicker(ProfileController controller) {
    return Obx(() {
      return controller.useCm.value ? _buildCmPicker(controller) : _buildFeetInchesPicker(controller);
    });
  }

  Widget _buildWeightPicker(ProfileController controller) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Obx(() {
        return Container(
          constraints: BoxConstraints(maxHeight: 200),
          child: CupertinoPicker(
            itemExtent: 40,
            scrollController: FixedExtentScrollController(
              initialItem: controller.useKg.value
                  ? controller.selectedKg.value - 20
                  : controller.selectedLbs.value - 44,
            ),
            onSelectedItemChanged: (index) {
              if (controller.useKg.value) {
                controller.selectedKg.value = index + 20;
              } else {
                controller.selectedLbs.value = index + 44;
              }
              controller.updateWeightDisplay();
            },
            children: List.generate(
              controller.useKg.value ? 181 : 457,
              (index) => Container(
                height: 40,
                alignment: Alignment.center,
                child: Text(
                  controller.useKg.value
                      ? '${index + 20} Kgs'
                      : '${index + 44} Lbs',
                  style: AppTextStyles.bodyText.copyWith(fontSize: 18),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCmPicker(ProfileController controller) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Container(
                constraints: BoxConstraints(maxHeight: 200),
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(
                    initialItem: controller.selectedCmInt.value - 100,
                  ),
                  onSelectedItemChanged: (index) {
                    controller.selectedCmInt.value = index + 100;
                    controller.updateHeightDisplay();
                  },
                  children: List.generate(
                    121,
                    (index) => Container(
                      height: 40,
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 100}',
                        style: AppTextStyles.bodyText.copyWith(fontSize: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: 20,
              height: 40,
              alignment: Alignment.center,
              child: Text(
                '.',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Container(
                constraints: BoxConstraints(maxHeight: 200),
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(
                    initialItem: controller.selectedCmDecimal.value,
                  ),
                  onSelectedItemChanged: (index) {
                    controller.selectedCmDecimal.value = index;
                    controller.updateHeightDisplay();
                  },
                  children: List.generate(
                    10,
                    (index) => Container(
                      height: 40,
                      alignment: Alignment.center,
                      child: Text(
                        '$index cm',
                        style: AppTextStyles.bodyText.copyWith(fontSize: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeetInchesPicker(ProfileController controller) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Container(
                constraints: BoxConstraints(maxHeight: 200),
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(
                    initialItem: controller.selectedFeet.value - 1,
                  ),
                  onSelectedItemChanged: (index) {
                    controller.selectedFeet.value = index + 1;
                    controller.updateHeightDisplay();
                  },
                  children: List.generate(
                    8,
                    (index) => Container(
                      height: 40,
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1} ft',
                        style: AppTextStyles.bodyText.copyWith(fontSize: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                constraints: BoxConstraints(maxHeight: 200),
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(
                    initialItem: controller.selectedInches.value,
                  ),
                  onSelectedItemChanged: (index) {
                    controller.selectedInches.value = index;
                    controller.updateHeightDisplay();
                  },
                  children: List.generate(
                    12,
                    (index) => Container(
                      height: 40,
                      alignment: Alignment.center,
                      child: Text(
                        '$index in',
                        style: AppTextStyles.bodyText.copyWith(fontSize: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerDoneButton(BuildContext context, ProfileController controller) {
    return Container(
      padding: EdgeInsets.all(16),
      width: double.infinity,
      child: AuthButton(
        text: 'Done',
        onPressed: () {
          controller.updateHeightDisplay();
          controller.updateWeightDisplay();
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// Custom TextInputFormatter to capitalize the first letter of each word
/// Example: typing "nikhil sahu" will automatically format to "Nikhil Sahu"
class _CapitalizeWordsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Get the new text
    final text = newValue.text;

    if (text.isEmpty) {
      return newValue;
    }

    // Capitalize first letter of each word
    final words = text.split(' ');
    final capitalizedWords = words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).toList();

    final newText = capitalizedWords.join(' ');

    return TextEditingValue(
      text: newText,
      selection: newValue.selection,
    );
  }
}

/// Custom TextInputFormatter to format date input as DD/MM/YYYY
/// Automatically adds slashes as user types
class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Remove all slashes to work with raw digits
    final digitsOnly = text.replaceAll('/', '');

    // Limit to 8 digits (DDMMYYYY)
    if (digitsOnly.length > 8) {
      return oldValue;
    }

    // Build formatted string
    String formatted = '';
    for (int i = 0; i < digitsOnly.length; i++) {
      formatted += digitsOnly[i];
      // Add slash after DD and MM
      if (i == 1 || i == 3) {
        formatted += '/';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}