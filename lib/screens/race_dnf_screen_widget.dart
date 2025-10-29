import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../config/assets/icons.dart';
import '../controllers/race/race_map_controller.dart';
import '../core/models/race_data_model.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_widgets.dart';
import '../widgets/common/vertical_dash_divider.dart';

class DNFWidget extends StatelessWidget {
  const DNFWidget({
    super.key,
    required this.size,
    required this.raceModel,
    required this.mapController,
  });

  final Size size;
  final RaceData? raceModel;
  final MapController mapController;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size.height,
      width: size.width,
      color: Colors.white,
      child: Column(
        children: [
          // Custom App Bar
          CustomAppBar(
            title: "Race Completed",
            isBack: false,
            circularBackButton: false,
            backgroundColor: Colors.white,
            titleColor: AppColors.appColor,
            showGradient: false,
            titleStyle: GoogleFonts.roboto(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.appColor,
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    SizedBox(height: 20),

                    // Clock/Flag Icon with Neutral Gradient
                    Container(
                      padding: EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blue.shade100.withValues(alpha: 0.3),
                            Colors.grey.shade200.withValues(alpha: 0.3),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.timer_off_outlined,
                        size: 100,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    SizedBox(height: 24),

                    // DNF Text
                    Text(
                      "DNF",
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.buttonBlack,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      "Race is Over",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      "You did not complete the race",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.iconGrey,
                      ),
                    ),

                    SizedBox(height: 32),

                    // Race Route Card
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                IconPaths.radioIcon,
                                colorFilter: ColorFilter.mode(AppColors.appColor, BlendMode.srcIn),
                                width: 20,
                                height: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: VerticalDashedDivider(
                                  isHorizontal: true,
                                  dashHeight: 5,
                                  dashSpacing: 2,
                                  color: AppColors.iconGrey,
                                  width: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              SvgPicture.asset(
                                IconPaths.locationIcon,
                                colorFilter: ColorFilter.mode(AppColors.neonYellow, BlendMode.srcIn),
                                width: 20,
                                height: 20,
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  "${raceModel?.startAddress}",
                                  style: GoogleFonts.poppins(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.left,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  "${raceModel?.endAddress}",
                                  style: GoogleFonts.poppins(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32),

                    // Map Snapshot
                    Obx(() {
                      if (mapController.mapSnapshot.value != null) {
                        return Column(
                          children: [
                            GestureDetector(
                              onTap: () => _showFullScreenMap(context),
                              child: Container(
                                height: 250,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.appColor.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.memory(
                                        mapController.mapSnapshot.value!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 250,
                                      ),
                                    ),
                                    // Tap to expand hint
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.zoom_in,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Tap to expand',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 32),
                          ],
                        );
                      }
                      // If snapshot not available, return empty widget
                      return SizedBox.shrink();
                    }),

                    // Encouraging Message
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.emoji_events_outlined,
                            color: Colors.blue.shade700,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Good effort! Try again next time!",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Back to Home Button
                    CustomButton(
                      btnTitle: "Back to Home",
                      onPress: () {
                        // Clean up map controller
                        if (Get.isRegistered<MapController>()) {
                          Get.delete<MapController>();
                        }
                        // Navigate back - this will go back through the navigation stack
                        // If this doesn't work, you may need to navigate to a specific screen
                        // using Get.offAll(() => YourHomeScreen()) instead
                        Get.back();
                      },
                    ),

                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show full-screen map snapshot
  void _showFullScreenMap(BuildContext context) {
    if (mapController.mapSnapshot.value == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(10),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(
                  mapController.mapSnapshot.value!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
