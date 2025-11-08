import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../config/app_colors.dart';
import '../../../controllers/race/create_race_controller.dart';
import '../../../controllers/home/home_controller.dart';
import '../../../widgets/auth/auth_button.dart';
import '../../../widgets/common/custom_app_bar.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../../place_picker/place_picker_screen.dart';

class CreateRaceScreen extends StatelessWidget {
  CreateRaceScreen({super.key});

  final CreateRaceController controller = Get.put(CreateRaceController());
  final List<String> stoppingTimes = ['5 mins', '1 hours', '12 hours', '24 hours'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Create a race",
        isBack: true,
        circularBackButton: true,
        backButtonCircleColor: AppColors.neonYellow,
        backButtonIconColor: Colors.black,
        backgroundColor: Colors.white,
        titleColor: AppColors.appColor,
        showGradient: false,
        onBackClick: () {
          // Navigate back to home screen and set index to 0
          if (Get.isRegistered<HomeController>()) {
            Get.find<HomeController>().changeIndex(0);
          }
          Get.back();
        },
        titleStyle: GoogleFonts.roboto(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.appColor,
        ),
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16,vertical: 8),
        child: Obx(() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [


              _buildSectionTitle('Race Title'),
              RoundedTextField(
                controller: controller.titleController,
                hintText: 'Enter race title',
                keyboardType: TextInputType.text,
                maxLength: 50,
              ),

              SizedBox(height: 8),
              _buildSectionTitle('Race Details'),

              // Start location
              RoundedTextField(
                controller: controller.startController,
                hintText: controller.isLoadingCurrentLocation.value
                    ? 'Getting current location...'
                    : (controller.startAddress.value.isNotEmpty
                          ? 'Tap to change starting point'
                          : 'Add starting point'),
                isReadOnly: true,
                onClick: () => _showLocationPicker(true),
                suffixIcon: Padding(
                  padding: EdgeInsets.all(16),
                  child: controller.isLoadingCurrentLocation.value
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.appColor,
                            ),
                          ),
                        )
                      : Icon(
                          controller.startAddress.value.isNotEmpty
                              ? Icons.edit_location
                              : Icons.radio_button_checked,
                          color: AppColors.appColor,
                          size: 20,
                        ),
                ),
              ),

              // Dotted divider between start and end locations
              _buildDottedDivider(),

              if (controller.routeDistance.value.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.appColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.appColor.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.straighten_rounded,
                          color: AppColors.appColor,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Distance: ${controller.routeDistance.value} km",
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Obx(
                                () => Text(
                                  controller.getDistanceEncouragement(),
                                  style: GoogleFonts.poppins(
                                    color: AppColors.appColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // End location
              RoundedTextField(
                controller: controller.endController,
                hintText: 'Add ending point',
                isReadOnly: true,
                onClick: () => _showLocationPicker(false),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // GPS button to use current location
                    Obx(() => controller.isLoading.value
                        ? Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.appColor,
                                ),
                              ),
                            ),
                          )
                        : IconButton(
                            icon: Icon(
                              Icons.my_location,
                              color: AppColors.neonYellow,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            onPressed: () {
                              controller.setEndLocationToCurrent();
                            },
                            tooltip: 'Use current location',
                          ),
                    ),
                    SizedBox(width: 8),
                    // Location icon
                    Icon(
                      Icons.location_on,
                      color: AppColors.appColor,
                      size: 20,
                    ),
                    SizedBox(width: 16),
                  ],
                ),
              ),

              SizedBox(height: 12),
              _buildSectionTitle('Race Type'),
              SizedBox(height: 8),
              _buildRaceTypeSelector(),

              SizedBox(height: 20),
              // Hide Total Participants section for Solo races
              Obx(
                () => controller.raceType.value == 'Solo'
                    ? SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Total Participants'),
                          _buildParticipantCounter(),
                        ],
                      ),
              ),

              // Hide Min Participants section for Solo races
              Obx(
                () => controller.raceType.value == 'Solo'
                    ? SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 8),
                          _buildSectionTitle('Min. Participants'),
                          _buildParticipantLimitCounter(),
                        ],
                      ),
              ),

              // Hide Race Stopping Time section for Solo and Marathon races
              Obx(
                () => controller.raceType.value == 'Solo' ||
                      controller.raceType.value == 'Marathon'
                    ? SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 8),
                          _buildSectionTitle('Race Duration'),
                          _buildStoppingTimeDropdown(),
                        ],
                      ),
              ),

              // Hide Schedule the Race section for Solo and Marathon races
              Obx(
                () => controller.raceType.value == 'Solo' ||
                      controller.raceType.value == 'Marathon'
                    ? SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 8),
                          _buildSectionTitle('Schedule'),
                          RoundedTextField(
                            controller: controller.scheduleTimeController,
                            hintText: 'Add date and time',
                            isReadOnly: true,
                            onClick: () => _showScheduleBottomSheet(context),
                            suffixIcon: Padding(
                              padding: EdgeInsets.all(16),
                              child: Icon(
                                Icons.calendar_today,
                                color: AppColors.appColor,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

              // Hide Gender Preferences section for Solo races
              Obx(
                () => controller.raceType.value == 'Solo'
                    ? SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 8),
                          _buildSectionTitle('Gender'),
                          _buildGenderSelector(),
                        ],
                      ),
              ),

              SizedBox(height: 20),

              // Progress indicator
              Obx(
                () => Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Progress: ${(controller.getCompletionProgress() * 100).toInt()}%',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: controller.getCompletionProgress(),
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.appColor,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Create Race Button
              Obx(
                () => AuthButton(
                  text: "Proceed",
                  onPressed: controller.showRaceSummaryDialog,
                  isLoading: controller.isLoading.value,
                  icon: Icons.flag_rounded,
                  backgroundColor: AppColors.appColor,
                ),
              ),

              SizedBox(height: 20),
            ],
          );
        }),
      ),
    );
  }



  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4, top: 12),
      child: RichText(
        text: TextSpan(
          text: title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          children: [
            TextSpan(
              text: ' *',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.appColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDottedDivider() {
    return Padding(
      padding: EdgeInsets.only(left: 30, top: 0, bottom: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CustomPaint(
            painter: VerticalDottedLinePainter(color: AppColors.appColor),
            child: Container(width: 2, height: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildRaceTypeSelector() {
    return Obx(
      () => Column(
        children: [
          Row(
            children: ['Public', 'Private'].map((type) {
              final isSelected = controller.raceType.value == type;

              return Expanded(
                child: GestureDetector(
                  onTap: () => controller.raceType.value = type,
                  child: Container(
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.appColor : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      type,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 8),
          Row(
            children: ['Solo'].map((type) {
              final isSelected = controller.raceType.value == type;

              return Expanded(
                child: GestureDetector(
                  onTap: () => controller.raceType.value = type,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.appColor : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      type,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  bool _isRecommendedRaceType(String type) {
    final participants = controller.totalParticipants.value;
    final distance = double.tryParse(controller.routeDistance.value) ?? 0.0;

    if (participants == 1 && type == 'Solo') return true;
    if (participants > 1 && participants <= 5 && type == 'Private') return true;
    if (participants > 5 && type == 'Public') return true;
    return false;
  }

  bool _isRaceTypeDisabled(String type) {
    return false;
  }

  String _getRaceTypeDescription(String type) {
    switch (type) {
      case 'Solo':
        return 'Personal challenge, perfect for self-improvement';
      case 'Private':
        return 'Invite-only race with friends and family';
      case 'Public':
        return 'Open to everyone, great for community building';
      default:
        return '';
    }
  }

  Widget _buildParticipantCounter() {
    return Obx(
      () => Row(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: controller.decrementParticipants,
                  icon: Icon(Icons.remove, color: AppColors.appColor, size: 20),
                  constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${controller.totalParticipants.value}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: controller.incrementParticipants,
                  icon: Icon(Icons.add, color: AppColors.appColor, size: 20),
                  constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Text(
            'participants',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantLimitCounter() {
    return Obx(
      () => Row(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: controller.decrementLimitParticipants,
                  icon: Icon(Icons.remove, color: AppColors.appColor, size: 20),
                  constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${controller.participantLimit.value}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: controller.incrementLimitParticipants,
                  icon: Icon(Icons.add, color: AppColors.appColor, size: 20),
                  constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Text(
            'minimum',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildStoppingTimeDropdown() {
    return Obx(
      () => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: DropdownButtonFormField<String>(
          initialValue: controller.raceStoppingTime.value,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: InputBorder.none,
          ),
          items: stoppingTimes.map((time) {
            return DropdownMenuItem(
              value: time,
              child: Text(time, style: GoogleFonts.poppins(fontSize: 14)),
            );
          }).toList(),
          onChanged: (val) => controller.raceStoppingTime.value = val!,
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Obx(
      () => Row(
        children: ['Male', 'Female', 'Any'].map((type) {
          final isSelected =
              controller.genderPref.value == type ||
              (controller.genderPref.value == 'No preference' && type == 'Any');

          return Expanded(
            child: GestureDetector(
              onTap: () => controller.genderPref.value = type == 'Any'
                  ? 'No preference'
                  : type,
              child: Container(
                margin: EdgeInsets.only(right: type != 'Any' ? 8 : 0),
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.appColor : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  type,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showLocationPicker(bool isStart) {
    Get.to(() => PlacePickerScreen(isStart: isStart));
  }

  void _showScheduleBottomSheet(BuildContext context) {
    Get.bottomSheet(
      SafeArea(
        bottom: true,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Obx(() {
            final dateTime = controller.selectedDateTime.value;
            final formattedDate = DateFormat('dd MMM yyyy').format(dateTime);
            final formattedTime = DateFormat('hh:mm a').format(dateTime);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'Schedule a race',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Center(
                  child: Text(
                    '$formattedDate, $formattedTime',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ),
                SizedBox(height: 24),
                GestureDetector(
                  onTap: () => controller.pickDate(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: Colors.grey[700],
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Date, $formattedDate',
                          style: GoogleFonts.poppins(),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                GestureDetector(
                  onTap: () => controller.pickTime(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 20,
                          color: Colors.grey[700],
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Time, $formattedTime',
                          style: GoogleFonts.poppins(),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text('Cancel', style: GoogleFonts.poppins()),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (controller.validateDateTime(
                            controller.selectedDateTime.value,
                          )) {
                            Get.back();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.appColor,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Done'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
      isScrollControlled: true,
    );
  }
}

// Custom painter for vertical dotted line
class VerticalDottedLinePainter extends CustomPainter {
  final Color color;
  final double dashHeight;
  final double dashSpace;

  VerticalDottedLinePainter({
    required this.color,
    this.dashHeight = 4.0,
    this.dashSpace = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
