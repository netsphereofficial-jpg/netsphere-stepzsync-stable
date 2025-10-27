import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_colors.dart';
import '../../controllers/race/create_race_controller.dart';

class RaceSummaryDialog extends StatelessWidget {
  final CreateRaceController controller;
  final VoidCallback onConfirm;

  const RaceSummaryDialog({
    super.key,
    required this.controller,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, AppColors.appColor.withOpacity(0.05)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.appColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.flag_rounded,
                color: AppColors.appColor,
                size: 32,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Race Summary',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please review your race details before creating',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryRow(
                    'Race Title',
                    controller.titleController.text.trim(),
                  ),
                  _buildSummaryRow('Type', controller.raceType.value),
                  _buildSummaryRow(
                    'Starting Point',
                    controller.startAddress.value,
                  ),
                  _buildSummaryRow('Ending Point', controller.endAddress.value),
                  if (controller.routeDistance.value.isNotEmpty)
                    _buildSummaryRow(
                      'Distance',
                      '${controller.routeDistance.value} km',
                    ),
                  if (controller.raceType.value != 'Solo') ...[
                    _buildSummaryRow(
                      'Participants',
                      '${controller.totalParticipants.value}',
                    ),
                    _buildSummaryRow(
                      'Min. Participants',
                      '${controller.participantLimit.value}',
                    ),
                    _buildSummaryRow(
                      'Duration',
                      controller.raceStoppingTime.value,
                    ),
                    _buildSummaryRow(
                      'Schedule',
                      controller.scheduleTimeController.text,
                    ),
                    _buildSummaryRow(
                      'Gender Preference',
                      controller.genderPref.value,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey[400]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back(); // Close dialog first
                      onConfirm(); // Directly create race - no additional confirmation
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.appColor,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Create',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
              maxLines: 3,
              style: GoogleFonts.poppins(
                fontSize: 11,

                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
