import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stepzsync/controllers/race/completed_races_controller.dart';
import 'package:stepzsync/controllers/race/races_list_controller.dart';
import 'package:stepzsync/widgets/race/race_card_widget.dart';

import '../../config/app_colors.dart';
import '../../config/assets/icons.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/common/custom_app_bar.dart';

class CompletedRacesScreen extends StatefulWidget {
  const CompletedRacesScreen({super.key});

  @override
  State<CompletedRacesScreen> createState() => _CompletedRacesScreenState();
}

class _CompletedRacesScreenState extends State<CompletedRacesScreen>
    with SingleTickerProviderStateMixin {
  final CompletedRacesController controller = Get.put(CompletedRacesController());
  late AnimationController _cardAnimationController;

  // RaceCardWidget requires RacesListController, so ensure it's available
  final RacesListController _racesController = Get.put(RacesListController());

  @override
  void initState() {
    super.initState();

    _cardAnimationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    // Start animations with delay
    Future.delayed(Duration(milliseconds: 400), () {
      if (mounted) {
        _cardAnimationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffE8E8F8),
      appBar: CustomAppBar(
        title: "Completed Races",
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
      body: Container(
        child: Stack(
          children: [
            // Main content
            Positioned.fill(
              child: RefreshIndicator(
                onRefresh: controller.refreshCompletedRaces,
                color: AppColors.neonYellow,
                child: Obx(() {
                  if (controller.isLoading.value && controller.completedRaces.isEmpty) {
                    return _buildLoadingState();
                  }

                  if (controller.completedRaces.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    physics: BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: AppConstants.defaultPadding,
                      bottom: AppConstants.defaultPadding,
                    ),
                    itemCount: controller.completedRaces.length,
                    itemBuilder: (context, index) {
                      final race = controller.completedRaces[index];
                      return _buildAnimatedRaceCard(race, index);
                    },
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildStatItem({
    required String icon,
    required String title,
    required String value,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.elasticOut,
      builder: (context, animationValue, child) {
        return Transform.scale(
          scale: animationValue.clamp(0.1, 1.0),
          child: Opacity(
            opacity: animationValue.clamp(0.0, 1.0),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.neonYellow.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SvgPicture.asset(
                    icon,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      AppColors.neonYellow,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neonYellow,
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: 5,
            padding: EdgeInsets.symmetric(
              horizontal: AppConstants.defaultPadding,
            ),
            itemBuilder: (context, index) => _buildShimmerCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 100,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Spacer(),
              Container(
                width: 60,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 150,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Spacer(),
              Container(
                width: 80,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.blueLight.withValues(alpha: 1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events_outlined,
              size: 50,
              color: AppColors.buttonBlack,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Completed Races Yet',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Complete your first race to see your achievements here!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonYellow,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(
              'Browse Races',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600,color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedRaceCard(race, int index) {
    return AnimatedBuilder(
      animation: _cardAnimationController,
      builder: (context, child) {
        final animationDelay = (index * 0.05).clamp(0.0, 0.8);
        final totalAnimationValue = _cardAnimationController.value;

        double rawAnimationValue;
        if (totalAnimationValue <= animationDelay) {
          rawAnimationValue = 0.0;
        } else {
          rawAnimationValue =
              ((totalAnimationValue - animationDelay) / (1.0 - animationDelay))
                  .clamp(0.0, 1.0);
        }

        final animationValue = Curves.easeOutBack
            .transform(rawAnimationValue)
            .clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, 30 * (1 - animationValue)),
          child: Opacity(
            opacity: animationValue.clamp(0.3, 1.0),
            child: Transform.scale(
              scale: (0.95 + (0.05 * animationValue)).clamp(0.95, 1.0),
              child: RaceCardWidget(race: race),
            ),
          ),
        );
      },
    );
  }
}