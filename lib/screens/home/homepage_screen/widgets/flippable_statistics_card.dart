import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/homepage_data_service.dart';
import '../controllers/statistics_charts_controller.dart';
import 'statistics_card_widget.dart';
import 'statistics_charts_widget.dart';
import '../../../../controllers/subscription_controller.dart';

class FlippableStatisticsCard extends StatefulWidget {
  // All props from StatisticsCardWidget
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
  final AnimationController syncProgressController; // For manual sync animation
  final Animation<double> gradientAnimation;
  final Animation<double> ballAnimation;
  final Animation<double> pulseAnimation;
  final Function(bool)? onFlipStateChanged; // New callback for flip state

  const FlippableStatisticsCard({
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
    this.onFlipStateChanged,
  });

  @override
  State<FlippableStatisticsCard> createState() => _FlippableStatisticsCardState();
}

class _FlippableStatisticsCardState extends State<FlippableStatisticsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false;
  bool _showChartContent = false; // NEW: Controls when to actually render charts
  late StatisticsChartsController _chartsController;
  // Unique key to force complete widget tree rebuild when flipping
  int _backCardKey = 0;

  @override
  void initState() {
    super.initState();

    // Initialize charts controller
    if (Get.isRegistered<StatisticsChartsController>()) {
      _chartsController = Get.find<StatisticsChartsController>();
    } else {
      _chartsController = Get.put(StatisticsChartsController());
    }

    // Initialize flip animation
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _flipController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  /// Check if user has access to advanced statistics charts
  bool _checkAdvancedStatsAccess() {
    try {
      if (Get.isRegistered<SubscriptionController>()) {
        final subscriptionController = Get.find<SubscriptionController>();
        return subscriptionController.hasAdvancedStats;
      }
      // Default to false if controller not registered
      return false;
    } catch (e) {
      debugPrint('Error checking subscription access: $e');
      return false;
    }
  }

  /// Show premium required dialog
  void _showPremiumDialog() {
    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  const Color(0xFF2759FF).withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Premium Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2759FF),
                        const Color(0xFF2759FF).withValues(alpha: 0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2759FF).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: Color(0xFFCDFF49),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Advanced Statistics',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2759FF),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Premium Feature',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  'Unlock detailed charts and analytics to track your progress over time with Premium 1 or Premium 2!',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Features list
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2759FF).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2759FF).withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFeatureItem('Advanced statistics with filters'),
                      const SizedBox(height: 8),
                      _buildFeatureItem('Visual charts for steps & distance'),
                      const SizedBox(height: 8),
                      _buildFeatureItem('Track progress over time'),
                      const SizedBox(height: 8),
                      _buildFeatureItem('Heart-rate zones & more'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Maybe Later',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Get.toNamed('/subscription');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2759FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 4,
                          shadowColor: const Color(0xFF2759FF).withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Upgrade Now',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Color(0xFF2759FF),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check,
            color: Color(0xFFCDFF49),
            size: 14,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _toggleFlip() {
    if (!mounted) return;

    // Check if user has advanced stats access (premium feature)
    if (!_isFlipped && !_checkAdvancedStatsAccess()) {
      _showPremiumDialog();
      return;
    }

    HapticFeedback.mediumImpact();

    if (_isFlipped) {
      // Flipping back to front
      // FIRST: Hide chart content immediately to trigger disposal
      setState(() {
        _showChartContent = false;
      });

      // THEN: Start reverse animation after a frame
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!mounted) return;
        _flipController.reverse();

        // Update flip state after animation starts
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          setState(() {
            _isFlipped = false;
            widget.onFlipStateChanged?.call(false);
          });

          // Increment key after flip completes to ensure cleanup
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            setState(() {
              _backCardKey++;
            });
          });
        });
      });
    } else {
      // Flipping to back (charts)
      // Load chart data
      final dataService = Get.find<HomepageDataService>();
      final periodData = dataService.getChartPeriodData();

      _chartsController.loadChartData(
        widget.selectedFilter,
        periodSteps: periodData['steps'] as int?,
        periodDistance: periodData['distance'] as double?,
        periodActiveTime: periodData['activeTime'] as int?,
        periodCalories: periodData['calories'] as int?,
      );

      if (!mounted) return;
      setState(() {
        _isFlipped = true;
        widget.onFlipStateChanged?.call(true);
      });

      // Start flip animation
      _flipController.forward();

      // CRITICAL: Only create chart widgets AFTER flip animation completes
      Future.delayed(const Duration(milliseconds: 650), () {
        if (!mounted || !_isFlipped) return;
        setState(() {
          _showChartContent = true;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        // Calculate rotation angle (0 to π radians)
        final angle = _flipAnimation.value * math.pi;

        // Determine which side to show
        final isFrontVisible = angle <= math.pi / 2;

        // Only show charts AFTER flip animation crosses halfway point
        // This prevents chart disposal errors during flip animation
        final showBackContent = angle > math.pi / 2;

        // Calculate transform for 3D rotation
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.001) // Perspective
          ..rotateY(angle);

        return Transform(
          transform: transform,
          alignment: Alignment.center,
          child: isFrontVisible
              ? _buildFrontCard()
              : Transform(
            // Flip the back card so text is readable
            transform: Matrix4.identity()..rotateY(math.pi),
            alignment: Alignment.center,
            child: showBackContent ? _buildBackCard() : _buildPlaceholderCard(),
          ),
        );
      },
    );
  }

  Widget _buildFrontCard() {
    return Stack(
      children: [
        // Tap detector layer beneath everything (for flip on tap)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // Don't flip if dropdown is open
              if (!widget.isDropdownOpen.value) {
                _toggleFlip();
              }
            },
            child: Container(color: Colors.transparent),
          ),
        ),

        // Original Statistics Card on top (its interactive elements will work normally)
        IgnorePointer(
          ignoring: false, // Allow child interactions
          child: StatisticsCardWidget(
            selectedFilter: widget.selectedFilter,
            filters: widget.filters,
            isDropdownOpen: widget.isDropdownOpen,
            onFilterChanged: widget.onFilterChanged,
            onDropdownToggle: widget.onDropdownToggle,
            isLoadingPeriodData: widget.isLoadingPeriodData,
            periodDistance: widget.periodDistance,
            periodActiveTime: widget.periodActiveTime,
            periodCalories: widget.periodCalories,
            isWalking: widget.isWalking,
            animatedStepCount: widget.animatedStepCount,
            currentHeartRate: widget.currentHeartRate,
            isHeartRateAvailable: widget.isHeartRateAvailable,
            currentBloodOxygen: widget.currentBloodOxygen,
            isBloodOxygenAvailable: widget.isBloodOxygenAvailable,
            currentRespiratoryRate: widget.currentRespiratoryRate,
            isRespiratoryRateAvailable: widget.isRespiratoryRateAvailable,
            gradientController: widget.gradientController,
            ballController: widget.ballController,
            middleProgressController: widget.middleProgressController,
            pulseController: widget.pulseController,
            syncProgressController: widget.syncProgressController,
            gradientAnimation: widget.gradientAnimation,
            ballAnimation: widget.ballAnimation,
            pulseAnimation: widget.pulseAnimation,
          ),
        ),

        // Flip indicator badge (top-right, next to filter) - compact icon only
        Positioned(
          top: 12,
          left: 135,
          child: GestureDetector(
            onTap: () {
              if (!widget.isDropdownOpen.value) {
                _toggleFlip();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFCDFF49).withValues(alpha: 1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFCDFF49).withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.bar_chart_rounded,
                size: 20,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderCard() {
    // Empty placeholder shown during flip animation
    // Prevents chart widgets from being created/destroyed mid-animation
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2759FF),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildBackCard() {
    // CRITICAL: Only render chart widget AFTER flip animation completes
    // This prevents disposal errors during animation
    if (!_isFlipped || !_showChartContent) {
      // Show placeholder during animation or when charts shouldn't be visible
      return Container(
        key: ValueKey('empty_chart_card_$_backCardKey'),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2759FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: const Color(0xFFCDFF49),
            strokeWidth: 2,
          ),
        ),
      );
    }

    // Only create chart widgets when fully flipped and animation complete
    return RepaintBoundary(
      key: ValueKey('chart_card_$_backCardKey'),
      child: StatisticsChartsWidget(
        key: ValueKey('charts_widget_$_backCardKey'),
        selectedFilter: widget.selectedFilter,
        filters: widget.filters,
        isDropdownOpen: widget.isDropdownOpen,
        onFilterChanged: (filter) {
          // Update filter and reload chart data
          widget.onFilterChanged(filter);

          // Reload chart data with new filter
          final dataService = Get.find<HomepageDataService>();
          final periodData = dataService.getChartPeriodData();

          _chartsController.loadChartData(
            filter,
            periodSteps: periodData['steps'] as int?,
            periodActiveTime: periodData['activeTime'] as int?,
            periodCalories: periodData['calories'] as int?,
          );
        },
        onDropdownToggle: widget.onDropdownToggle,
        isLoadingChartData: _chartsController.isLoadingChartData,
        onFlipBack: _toggleFlip,
      ),
    );
  }
}
