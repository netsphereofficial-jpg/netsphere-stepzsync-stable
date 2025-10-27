import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/text_styles.dart';
import '../painters/gradient_ring_painter.dart';
import 'rotating_health_metric_widget.dart';
import 'flippable_sync_circle_widget.dart';

class StatisticsCardWidget extends StatelessWidget {
  final String selectedFilter;
  final List<String> filters;
  final RxBool isDropdownOpen;
  final Function(String) onFilterChanged;
  final VoidCallback? onDropdownToggle;
  final RxBool isLoadingPeriodData;
  final RxDouble periodDistance;
  final RxInt periodActiveTime;
  final RxInt periodCalories;
  final RxBool isWalking;
  final RxInt animatedStepCount;
  final RxInt currentHeartRate;
  final RxBool isHeartRateAvailable;
  final RxInt currentBloodOxygen;
  final RxBool isBloodOxygenAvailable;
  final RxInt currentRespiratoryRate;
  final RxBool isRespiratoryRateAvailable;
  final AnimationController gradientController;
  final AnimationController ballController;
  final AnimationController middleProgressController;
  final AnimationController pulseController;
  final AnimationController syncProgressController; // New controller for sync animation
  final Animation<double> gradientAnimation;
  final Animation<double> ballAnimation;
  final Animation<double> pulseAnimation;

  const StatisticsCardWidget({
    super.key,
    required this.selectedFilter,
    required this.filters,
    required this.isDropdownOpen,
    required this.onFilterChanged,
    this.onDropdownToggle,
    required this.isLoadingPeriodData,
    required this.periodDistance,
    required this.periodActiveTime,
    required this.periodCalories,
    required this.isWalking,
    required this.animatedStepCount,
    required this.currentHeartRate,
    required this.isHeartRateAvailable,
    required this.currentBloodOxygen,
    required this.isBloodOxygenAvailable,
    required this.currentRespiratoryRate,
    required this.isRespiratoryRateAvailable,
    required this.gradientController,
    required this.ballController,
    required this.middleProgressController,
    required this.pulseController,
    required this.syncProgressController,
    required this.gradientAnimation,
    required this.ballAnimation,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive sizing
    final size = MediaQuery.of(context).size;
    final isSmallDevice = size.height < 700;
    final cardPadding = isSmallDevice ? 10.0 : 12.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(cardPadding),
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: const Color(0xFF2759FF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2759FF).withValues(alpha: 0.25),
            spreadRadius: 2,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Statistics',
                style: AppTextStyles.sectionHeading,
              ),
              _buildCustomDropdown(),
            ],
          ),

          const SizedBox(height: 8),

          // Circular Progress with stats around - Flexible to fill available space
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Column Stats
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Distance stat
                      Obx(() => isLoadingPeriodData.value
                          ? _buildLoadingCornerStat('Distance', 'assets/icons/distance_icon.svg')
                          : _buildCornerStat(
                        'Distance',
                        periodDistance.value.toStringAsFixed(2),
                        'km',
                        null,
                        svgPath: 'assets/new_icons/Vector-8.svg',
                      )
                      ),
                      // Rotating Health Metric (Heart Rate, Blood Oxygen, Respiratory Rate)
                      RotatingHealthMetricWidget(
                        currentHeartRate: currentHeartRate,
                        isHeartRateAvailable: isHeartRateAvailable,
                        currentBloodOxygen: currentBloodOxygen,
                        isBloodOxygenAvailable: isBloodOxygenAvailable,
                        currentRespiratoryRate: currentRespiratoryRate,
                        isRespiratoryRateAvailable: isRespiratoryRateAvailable,
                        isLoading: isLoadingPeriodData.value,
                      ),
                    ],
                  ),
                ),

                // Center Progress Circle (Flippable for manual sync)
                Expanded(
                  flex: 2,
                  child: FlippableSyncCircleWidget(
                    frontWidget: _buildCenterProgressIndicator(isSmallDevice),
                    syncProgressAnimationController: syncProgressController,
                  ),
                ),

                // Right Column Stats
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Time stat
                      Obx(() => isLoadingPeriodData.value
                          ? _buildLoadingCornerStat('Time', 'assets/icons/timer_icon.svg')
                          : _buildCornerStat(
                        'Time',
                        periodActiveTime.value.toString(),
                        'min',
                        null,
                        svgPath: 'assets/icons/timer_icon.svg',
                      )
                      ),
                      // Calories stat
                      Obx(() => isLoadingPeriodData.value
                          ? _buildLoadingCornerStat('Calories', 'assets/icons/winner_cup.svg')
                          : _buildCornerStat(
                        'Calories',
                        periodCalories.value.toString(),
                        'Cal',
                        null,
                        svgPath: 'assets/new_icons/Vector-10.svg',
                      )
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterProgressIndicator(bool isSmallDevice) {
    final circleSize = isSmallDevice ? 150.0 : 170.0;
    final innerCircleSize = isSmallDevice ? 120.0 : 135.0;
    final middleRingSize = isSmallDevice ? 140.0 : 155.0;

    return SizedBox(
      width: circleSize,
      height: circleSize,
      // ✅ Add error boundary with Builder to catch animation errors
      child: Builder(
        builder: (context) {
          try {
            return AnimatedBuilder(
              animation: Listenable.merge([gradientController, ballController, middleProgressController]),
              builder: (context, child) => Obx(() {
                try {
                  return Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Middle Progress Ring - Distance Goal (5km) - Background layer
                Transform.rotate(
                  angle: isWalking.value ? -middleProgressController.value * 2 * 3.14159 : 0,
                  child: SizedBox(
                    width: middleRingSize,
                    height: middleRingSize,
                    child: CircularProgressIndicator(
                      value: (periodDistance.value / 5.0).clamp(0.0, 1.0),
                      strokeWidth: 4,
                      backgroundColor: Colors.grey.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isWalking.value
                            ? const Color(0xFF3665F9).withValues(alpha: 0.3)
                            : const Color(0xFF3665F9).withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),

                // Custom Gradient Progress Ring with Ball - Top layer
                CustomPaint(
                  size: Size(circleSize, circleSize),
                  painter: GradientRingPainter(
                    progress: animatedStepCount.value / 10000,
                    gradientRotation: isWalking.value ? gradientAnimation.value : 0,
                    ballPosition: isWalking.value ? ballAnimation.value : 0,
                    isAnimating: isWalking.value,
                  ),
                ),

                // Inner Core Circle
                Container(
                  width: innerCircleSize,
                  height: innerCircleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFF2759FF),
                        Color(0xFF1a4ae6),
                        Color(0xFF0d3bd3),
                      ],
                      stops: [0.0, 0.7, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2759FF).withValues(alpha: 0.4),
                        blurRadius: 25,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: const Color(0xFFCDFF49).withValues(alpha: 0.3),
                        blurRadius: 40,
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFCDFF49).withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Bigger Animated Running Shoe Icon with Multiple Effects
                        _buildAnimatedShoeIcon(isSmallDevice),
                        // Steps Counter - Bigger, Bold, White
                        Text(
                          _formatStepCount(animatedStepCount.value),
                          style: GoogleFonts.roboto(
                            fontSize: isSmallDevice ? 24 : 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Total Steps',
                          style: TextStyle(
                            fontSize: isSmallDevice ? 9 : 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Pulsing Effect Overlay - Only when walking
                isWalking.value
                    ? Transform.scale(
                  scale: 1.0 + (pulseController.value * 0.15),
                  child: Container(
                    width: innerCircleSize - 10,
                    height: innerCircleSize - 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Color(0xFFCDFF49).withValues(
                            alpha: 0.3 * (1 - pulseController.value)
                        ),
                        width: 1,
                      ),
                    ),
                  ),
                )
                    : const SizedBox(),
              ],
            ),
          );
                } catch (e) {
                  // ✅ If Obx fails, show fallback
                  print('⚠️ Animation rendering error: $e');
                  return _buildFallbackProgressIndicator(isSmallDevice);
                }
              }),
            );
          } catch (e, stackTrace) {
            // ✅ If AnimatedBuilder fails, show fallback and log to Sentry
            print('❌ Critical animation error: $e');
            try {
              // Sentry.captureException(e, stackTrace: stackTrace);
            } catch (_) {}
            return _buildFallbackProgressIndicator(isSmallDevice);
          }
        },
      ),
    );
  }

  /// ✅ Fallback UI when animations crash
  Widget _buildFallbackProgressIndicator(bool isSmallDevice) {
    final circleSize = isSmallDevice ? 150.0 : 170.0;

    return Obx(() => Container(
      width: circleSize,
      height: circleSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF2759FF),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2759FF).withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_run,
              color: Colors.white,
              size: isSmallDevice ? 28 : 32,
            ),
            SizedBox(height: isSmallDevice ? 6 : 8),
            Text(
              _formatStepCount(animatedStepCount.value),
              style: GoogleFonts.roboto(
                fontSize: isSmallDevice ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Total Steps',
              style: TextStyle(
                fontSize: isSmallDevice ? 9 : 10,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildAnimatedShoeIcon(bool isSmallDevice) {
    final iconSize = isSmallDevice ? 32.0 : 36.0;

    return AnimatedBuilder(
      animation: Listenable.merge([pulseController, ballController, gradientController]),
      builder: (context, child) {
        return Obx(() {
          if (isWalking.value) {
            // Multiple layered animations when walking
            return Transform.scale(
              scale: 0.9 + (pulseAnimation.value * 0.3), // Scale between 0.9 and 1.2
              child: Transform.rotate(
                angle: (ballAnimation.value * 0.1) - 0.05, // Slight rotation (-0.05 to 0.05 radians)
                child: Transform.translate(
                  offset: Offset(
                    (gradientAnimation.value * 4) - 2, // Horizontal shake (-2 to 2)
                    (pulseAnimation.value * 3) - 1.5, // Vertical bounce (-1.5 to 1.5)
                  ),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 100),
                    child: SvgPicture.asset(
                      'assets/icons/shoe-run.svg',
                      width: iconSize,
                      height: iconSize,
                      colorFilter: ColorFilter.mode(
                        Color.lerp(
                          Colors.white,
                          const Color(0xFFCDFF49),
                          (pulseAnimation.value * 0.3),
                        )!,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            );
          } else {
            // Static state with gentle idle animation
            return Transform.scale(
              scale: 1.0 + (pulseAnimation.value * 0.05), // Very subtle pulse when idle
              child: SvgPicture.asset(
                'assets/icons/shoe-run.svg',
                width: iconSize,
                height: iconSize,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            );
          }
        });
      },
    );
  }

  Widget _buildCustomDropdown() {
    return Obx(() => GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onDropdownToggle?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFCDFF49),
              const Color(0xFFCDFF49).withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFCDFF49).withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedFilter,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: isDropdownOpen.value ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildCornerStat(
      String label,
      String value,
      String unit,
      IconData? icon, {
        String? svgPath,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (svgPath != null)
              SvgPicture.asset(
                svgPath,
                width: 22,
                height: 22,
                colorFilter: const ColorFilter.mode(
                  Color(0xFFCDFF49),
                  BlendMode.srcIn,
                ),
              ).animate(onPlay: (controller) => controller.repeat())
                  .shimmer(duration: 2000.ms, colors: [
                const Color(0xFFCDFF49),
                const Color(0xFFCDFF49).withValues(alpha: 0.6),
                const Color(0xFFCDFF49),
              ])
            else if (icon != null)
              Icon(icon, color: const Color(0xFFCDFF49), size: 22),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.statLabel,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        RichText(
          textAlign: TextAlign.center,
          overflow: TextOverflow.visible,
          text: TextSpan(
            text: value,
            style: AppTextStyles.cornerStatValue,
            children: [
              TextSpan(
                text: ' $unit',
                style: AppTextStyles.cornerStatUnit,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCornerStat(String label, String svgPath) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SvgPicture.asset(
              svgPath,
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(
                const Color(0xFFCDFF49).withValues(alpha: 0.5),
                BlendMode.srcIn,
              ),
            ).animate(onPlay: (controller) => controller.repeat())
                .shimmer(duration: 1500.ms, colors: [
              const Color(0xFFCDFF49).withValues(alpha: 0.3),
              const Color(0xFFCDFF49).withValues(alpha: 0.7),
              const Color(0xFFCDFF49).withValues(alpha: 0.3),
            ]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.statLabel.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        _buildShimmerContainer(width: 50, height: 20),
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

  String _formatStepCount(int stepCount) {
    return stepCount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatActiveTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    // Format as HH:MM with leading zeros
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  /// Get heart rate display text based on availability and current value
  String _getHeartRateDisplayText() {
    if (!isHeartRateAvailable.value) return '--';
    if (currentHeartRate.value == 0) return '--';
    return currentHeartRate.value.toString();
  }
}
