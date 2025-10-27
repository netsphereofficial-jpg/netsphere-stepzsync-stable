import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../../core/constants/text_styles.dart';

/// Widget that rotates between Heart Rate, Blood Oxygen, and Respiratory Rate
/// Changes metric every 2 seconds with smooth fade transition
class RotatingHealthMetricWidget extends StatefulWidget {
  final RxInt currentHeartRate;
  final RxBool isHeartRateAvailable;
  final RxInt currentBloodOxygen;
  final RxBool isBloodOxygenAvailable;
  final RxInt currentRespiratoryRate;
  final RxBool isRespiratoryRateAvailable;
  final bool isLoading;

  const RotatingHealthMetricWidget({
    super.key,
    required this.currentHeartRate,
    required this.isHeartRateAvailable,
    required this.currentBloodOxygen,
    required this.isBloodOxygenAvailable,
    required this.currentRespiratoryRate,
    required this.isRespiratoryRateAvailable,
    this.isLoading = false,
  });

  @override
  State<RotatingHealthMetricWidget> createState() => _RotatingHealthMetricWidgetState();
}

class _RotatingHealthMetricWidgetState extends State<RotatingHealthMetricWidget> {
  Timer? _rotationTimer;
  int _currentMetricIndex = 0;

  // Define metric rotation order
  final List<_HealthMetric> _metrics = [];

  @override
  void initState() {
    super.initState();
    _initializeMetrics();
    _startRotationTimer();
  }

  void _initializeMetrics() {
    // Always include all three metrics in rotation
    _metrics.addAll([
      _HealthMetric(
        label: 'Heart Rate',
        svgPath: 'assets/icons/heart_rate.svg',
        unit: 'BPM',
        getValue: () => widget.currentHeartRate.value.toString(),
        isAvailable: () => widget.isHeartRateAvailable.value,
      ),
      _HealthMetric(
        label: 'Blood O₂',
        svgPath: 'assets/icons/oxygen_icon.svg', // We'll create this
        unit: '%',
        getValue: () => widget.currentBloodOxygen.value.toString(),
        isAvailable: () => widget.isBloodOxygenAvailable.value,
      ),
      _HealthMetric(
        label: 'Respiratory',
        svgPath: 'assets/icons/respiratory_icon.svg', // We'll create this
        unit: 'RPM',
        getValue: () => widget.currentRespiratoryRate.value.toString(),
        isAvailable: () => widget.isRespiratoryRateAvailable.value,
      ),
    ]);
  }

  void _startRotationTimer() {
    // Rotate every 2 seconds
    _rotationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _currentMetricIndex = (_currentMetricIndex + 1) % _metrics.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildLoadingState();
    }

    return Obx(() => AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: _buildMetricDisplay(
        _metrics[_currentMetricIndex],
        key: ValueKey<int>(_currentMetricIndex),
      ),
    ));
  }

  Widget _buildMetricDisplay(_HealthMetric metric, {Key? key}) {
    final isAvailable = metric.isAvailable();
    final value = isAvailable && metric.getValue() != '0' ? metric.getValue() : '--';

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              metric.svgPath,
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
            ]),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                metric.label,
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
                text: ' ${metric.unit}',
                style: AppTextStyles.cornerStatUnit,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SvgPicture.asset(
              'assets/icons/heart_rate.svg',
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
                'Heart Rate',
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
}

/// Internal class to hold metric information
class _HealthMetric {
  final String label;
  final String svgPath;
  final String unit;
  final String Function() getValue;
  final bool Function() isAvailable;

  _HealthMetric({
    required this.label,
    required this.svgPath,
    required this.unit,
    required this.getValue,
    required this.isAvailable,
  });
}
