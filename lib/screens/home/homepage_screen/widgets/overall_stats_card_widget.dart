import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../../core/constants/text_styles.dart';

class OverallStatsCardWidget extends StatelessWidget {
  final RxInt overallDays;
  final RxInt overallSteps;
  final RxDouble overallDistance;
  final RxBool? isLoading;

  const OverallStatsCardWidget({
    super.key,
    required this.overallDays,
    required this.overallSteps,
    required this.overallDistance,
    this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xff2759FF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2759FF).withValues(alpha: 0.25),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Overall Stats',
            style: AppTextStyles.sectionHeading,
          ),
          const SizedBox(height: 8),
          Obx(() {
            // Check explicit isLoading flag first
            if (isLoading?.value ?? false) {
              return _buildLoadingStats();
            }

            // If user has no steps yet, show the actual values (not loading)
            // This handles the case where overallDays might be set but steps are 0
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('${overallDays.value.toString().padLeft(2, '0')}', 'Days', null, svgPath: 'assets/icons/calender.svg'),
                _buildStatColumn(_formatStepCount(overallSteps.value), 'Steps', null, svgPath: 'assets/icons/shoe-run.svg'),
                _buildStatColumn('${overallDistance.value.round()}', 'Distance (Kms)', null, svgPath: 'assets/icons/walking-solid.svg'),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLoadingStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildLoadingStatColumn('Days', 'assets/icons/timer_icon.svg'),
        _buildLoadingStatColumn('Steps', 'assets/icons/shoe_icon.svg'),
        _buildLoadingStatColumn('Distance', 'assets/icons/distance_icon.svg'),
      ],
    );
  }

  Widget _buildLoadingStatColumn(String label, String svgPath) {
    return Column(
      children: [
        _buildShimmerContainer(width: 60, height: 20),
        const SizedBox(height: 8),
        Row(
          children: [
            SvgPicture.asset(
              svgPath,
              width: 26,
              height: 26,
              colorFilter: ColorFilter.mode(
                Color(0xFFCDFF49).withValues(alpha: 0.5),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShimmerContainer({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          colors: [
            Colors.grey.withValues(alpha: 0.2),
            Colors.grey.withValues(alpha: 0.4),
            Colors.grey.withValues(alpha: 0.2),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment(-1.0, 0.0),
          end: Alignment(1.0, 0.0),
        ),
      ),
    ).animate(onPlay: (controller) => controller.repeat())
        .shimmer(
      duration: 1500.ms,
      colors: [
        Colors.grey.withValues(alpha: 0.2),
        Colors.white.withValues(alpha: 0.4),
        Colors.grey.withValues(alpha: 0.2),
      ],
    );
  }

  Widget _buildStatColumn(String value, String label, IconData? icon, {String? svgPath}) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.statValue,
        ),
        Row(children: [
          if (svgPath != null)
            SvgPicture.asset(
              svgPath,
              width: 26,
              height: 26,
              colorFilter: const ColorFilter.mode(
                Color(0xFFCDFF49),
                BlendMode.srcIn,
              ),
            )
          else if (icon != null)
            Icon(icon, color: const Color(0xFFCDFF49), size: 26),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],)
      ],
    );
  }

  String _formatStepCount(int stepCount) {
    return stepCount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

class OverallStatsCardSkeletonWidget extends StatelessWidget {
  const OverallStatsCardSkeletonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xff2759FF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2759FF).withValues(alpha: 0.25),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Overall Stats',
            style: AppTextStyles.sectionHeading,
          ),
          const SizedBox(height: 8),
          _buildLoadingStats(),
        ],
      ),
    );
  }

  Widget _buildLoadingStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildLoadingStatColumn('Days', 'assets/icons/timer_icon.svg'),
        _buildLoadingStatColumn('Steps', 'assets/icons/shoe_icon.svg'),
        _buildLoadingStatColumn('Distance', 'assets/icons/distance_icon.svg'),
      ],
    );
  }

  Widget _buildLoadingStatColumn(String label, String svgPath) {
    return Column(
      children: [
        _buildShimmerContainer(width: 60, height: 20),
        const SizedBox(height: 8),
        Row(
          children: [
            SvgPicture.asset(
              svgPath,
              width: 26,
              height: 26,
              colorFilter: ColorFilter.mode(
                Color(0xFFCDFF49).withValues(alpha: 0.5),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShimmerContainer({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          colors: [
            Colors.grey.withValues(alpha: 0.2),
            Colors.grey.withValues(alpha: 0.4),
            Colors.grey.withValues(alpha: 0.2),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment(-1.0, 0.0),
          end: Alignment(1.0, 0.0),
        ),
      ),
    ).animate(onPlay: (controller) => controller.repeat())
        .shimmer(
      duration: 1500.ms,
      colors: [
        Colors.grey.withValues(alpha: 0.2),
        Colors.white.withValues(alpha: 0.4),
        Colors.grey.withValues(alpha: 0.2),
      ],
    );
  }
}