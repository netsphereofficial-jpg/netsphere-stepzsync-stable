import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_colors.dart';
import '../../../controllers/race/quick_race_controller.dart';
import '../../../widgets/common/custom_app_bar.dart';
import '../../../widgets/quick_race/distance_selector_widget.dart';
import '../../../widgets/quick_race/participant_selector_widget.dart';

class QuickRaceSelectionScreen extends StatelessWidget {
  const QuickRaceSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(QuickRaceController());

    return Scaffold(
      backgroundColor: Color(0xffE8E8F8),
      appBar: CustomAppBar(
        title: "Quick Race",
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [


                  // Location + Key Info Card
                  Obx(() => _buildInfoCard(controller)),
                  SizedBox(height: 16),

                  // Participant selector
                  Obx(() => ParticipantSelectorWidget(
                        selectedCount: controller.selectedParticipants.value,
                        onChanged: (count) {
                          controller.selectedParticipants.value = count;
                        },
                      )),
                  SizedBox(height: 16),

                  // Distance selector
                  Obx(() => DistanceSelectorWidget(
                        selectedDistance: controller.selectedDistance.value,
                        onChanged: (distance) {
                          controller.selectedDistance.value = distance;
                        },
                      )),
                ],
              ),
            ),
          ),

          // Create button fixed at bottom
          SafeArea(
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Obx(() => _buildCreateButton(controller)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.neonYellow,
            AppColors.neonYellow.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.flash_on, color: Colors.white, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Race',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Instant race • Starts immediately',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(QuickRaceController controller) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.neonYellow.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.neonYellow.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          // Location
          Row(
            children: [
              Icon(Icons.my_location, color: Color(0xff2759FF), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Location',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    controller.isLoadingLocation.value
                        ? Row(
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.neonYellow,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Getting location...',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            controller.currentAddress.value,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ],
                ),
              ),
            ],
          ),

          Divider(height: 20),

          // Quick Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStat(Icons.timer, '12 Hours', 'Duration'),
              Container(width: 1, height: 30, color: Colors.grey[300]),
              _buildQuickStat(Icons.public, 'Public', 'Visibility'),
              Container(width: 1, height: 30, color: Colors.grey[300]),
              _buildQuickStat(Icons.location_on, 'Auto', 'Route'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Color(0xff2759FF)),
        SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton(QuickRaceController controller) {
    final canCreate = controller.currentLat.value != null &&
        controller.currentLng.value != null &&
        !controller.isLoadingLocation.value;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      height: 54,
      decoration: BoxDecoration(
        gradient: canCreate
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.neonYellow,
                  AppColors.neonYellow.withValues(alpha: 0.8),
                ],
              )
            : null,
        color: canCreate ? null : Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
        boxShadow: canCreate
            ? [
                BoxShadow(
                  color: AppColors.neonYellow.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Color(0xff2759FF),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: canCreate && !controller.isLoading.value
              ? () => controller.createAndStartQuickRace()
              : null,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: controller.isLoading.value
                ? Center(
                    child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      Text(
                        'Find Race',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: canCreate ? Colors.white : Colors.grey[600],
                        ),
                      ),

                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
