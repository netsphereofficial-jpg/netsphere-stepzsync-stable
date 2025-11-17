import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_colors.dart';
import '../../../controllers/race/create_race_controller.dart';
import '../../../widgets/common/custom_app_bar.dart';
import '../../../widgets/auth/auth_button.dart';

/// Race Summary Screen
///
/// Displays a full-screen summary of race details before creation.
/// Replaces the previous dialog-based approach for better UX and consistency.
class RaceSummaryScreen extends StatelessWidget {
  final CreateRaceController controller;
  final VoidCallback onConfirm;

  const RaceSummaryScreen({
    super.key,
    required this.controller,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Race Summary',
        isBack: true,
        circularBackButton: true,
        backButtonCircleColor: AppColors.neonYellow,
        backButtonIconColor: Colors.black,
        backgroundColor: Colors.white,
        titleColor: AppColors.appColor,
        showGradient: false,
        titleStyle: GoogleFonts.roboto(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.appColor,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Race Details Section
                    _buildSectionHeader(
                      'Basic Information',
                      Icons.info_outline,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailCard([
                      _buildDetailRow(
                        'Race Title',
                        controller.titleController.text.trim(),
                        Icons.title,
                      ),
                      _buildDetailRow(
                        'Race Type',
                        controller.raceType.value,
                        Icons.category,
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Route Section
                    _buildSectionHeader('Route Details', Icons.map_outlined),
                    const SizedBox(height: 12),
                    _buildDetailCard([
                      _buildDetailRow(
                        'Starting Point',
                        controller.startAddress.value,
                        Icons.location_on,
                      ),
                      _buildDetailRow(
                        'Ending Point',
                        controller.endAddress.value,
                        Icons.flag,
                      ),
                      if (controller.routeDistance.value.isNotEmpty)
                        _buildDetailRow(
                          'Distance',
                          '${controller.routeDistance.value} km',
                          Icons.straighten,
                        ),
                    ]),

                    // Participants & Schedule Section (Only for non-Solo races)
                    if (controller.raceType.value != 'Solo') ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'Race Configuration',
                        Icons.settings_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailCard([
                        _buildDetailRow(
                          'Max Participants',
                          '${controller.totalParticipants.value}',
                          Icons.people,
                        ),
                        _buildDetailRow(
                          'Min. Participants',
                          '${controller.participantLimit.value}',
                          Icons.groups,
                        ),
                        _buildDetailRowWithInfo(
                          'Time to Finish',
                          controller.raceStoppingTime.value,
                          Icons.timer,
                          onInfoTap: () => _showTimeToFinishInfo(context),
                        ),
                        _buildDetailRow(
                          'Scheduled Time',
                          controller.scheduleTimeController.text,
                          Icons.schedule,
                        ),
                        _buildDetailRow(
                          'Gender Preference',
                          controller.genderPref.value,
                          Icons.people_alt,
                        ),
                      ]),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom Action Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Obx(
                () => AuthButton(
                  text: "Create Race",
                  onPressed: onConfirm,
                  isLoading: controller.isLoading.value,
                  icon: Icons.flag_rounded,
                  backgroundColor: AppColors.appColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildDetailCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: children
            .expand((widget) => [widget, const SizedBox(height: 10)])
            .toList()
          ..removeLast(), // Remove last SizedBox
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Build detail row with info icon
  Widget _buildDetailRowWithInfo(
    String label,
    String value,
    IconData icon, {
    required VoidCallback onInfoTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Row(
            children: [
              Text(
                '$label:',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(width: 4),
              GestureDetector(
                onTap: onInfoTap,
                child: Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppColors.appColor,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Show Time to Finish info dialog
  void _showTimeToFinishInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: AppColors.appColor,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Time to Finish',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Here\'s how it works:',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12),
            _buildInfoStep('1️⃣', 'Race starts'),
            _buildInfoStep('2️⃣', 'First person finishes'),
            _buildInfoStep('3️⃣', 'Timer starts counting'),
            _buildInfoStep('4️⃣', 'Others must finish before time runs out'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.appColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.appColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                '💡 Example: If set to 1 hour, everyone has 1 hour after the first finisher.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.appColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Got it!',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build info step row
  Widget _buildInfoStep(String emoji, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            emoji,
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
