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
                        _buildDetailRow(
                          'Duration',
                          controller.raceStoppingTime.value,
                          Icons.timer,
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
}
