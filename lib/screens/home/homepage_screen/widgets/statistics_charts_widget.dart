import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/text_styles.dart';
import '../controllers/statistics_charts_controller.dart';

class StatisticsChartsWidget extends StatefulWidget {
  final String selectedFilter;
  final List<String> filters;
  final RxBool isDropdownOpen;
  final Function(String) onFilterChanged;
  final VoidCallback? onDropdownToggle;
  final RxBool isLoadingChartData;
  final VoidCallback onFlipBack;

  const StatisticsChartsWidget({
    super.key,
    required this.selectedFilter,
    required this.filters,
    required this.isDropdownOpen,
    required this.onFilterChanged,
    this.onDropdownToggle,
    required this.isLoadingChartData,
    required this.onFlipBack,
  });

  @override
  State<StatisticsChartsWidget> createState() => _StatisticsChartsWidgetState();
}

class _StatisticsChartsWidgetState extends State<StatisticsChartsWidget>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isDisposed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _isDisposed = false;

    // Pulse animation for flip back button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final controller = Get.find<StatisticsChartsController>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
          // Header with dropdown and flip back button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Animated Flip back icon button with pulse
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            widget.onFlipBack();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFCDFF49).withValues(alpha: 0.2),
                                  const Color(0xFFCDFF49).withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFCDFF49).withValues(alpha: 0.3),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFCDFF49).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.flip_to_front,
                              size: 18,
                              color: Color(0xFFCDFF49),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Detailed Charts',
                    style: AppTextStyles.sectionHeading.copyWith(fontSize: 20),
                  ),
                ],
              ),
              _buildCustomDropdown(),
            ],
          ),
          const SizedBox(height: 12),

          // Chart Type Selector (Horizontal Pills) with animations
          _buildChartTypeSelector(controller),
          const SizedBox(height: 12),

          // Chart Display Area with transitions
          Expanded(
            child: Obx(() {
              // Prevent rendering if widget is being disposed
              if (_isDisposed || !mounted) {
                return const SizedBox.shrink();
              }

              if (widget.isLoadingChartData.value) {
                return _buildLoadingSkeleton();
              }

              // Display selected chart with fade transition
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.1, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _buildSelectedChart(controller),
              );
            }),
          ),

          // Subtle hint at bottom with fade in animation
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 4),
                Text(
                  'Tap icon to flip back',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
              .fadeIn(duration: 1500.ms)
              .fadeOut(duration: 1500.ms, delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildChartTypeSelector(StatisticsChartsController controller) {
    return Obx(() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: controller.chartTypes.asMap().entries.map((entry) {
          final index = entry.key;
          final type = entry.value;
          final isSelected = controller.selectedChartType.value == type;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                controller.selectChartType(type);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                    colors: [
                      const Color(0xFFCDFF49),
                      const Color(0xFFCDFF49).withValues(alpha: 0.8),
                    ],
                  )
                      : null,
                  color: isSelected ? null : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFCDFF49)
                        : Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: const Color(0xFFCDFF49).withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ] : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      _getChartIcon(type),
                      size: 16,
                      color: isSelected ? Colors.black87 : Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      type,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.black87 : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ).animate(delay: Duration(milliseconds: 100 * index))
                  .fadeIn(duration: 300.ms)
                  .slideX(begin: 0.2, end: 0, duration: 300.ms),
            ),
          );
        }).toList(),
      ),
    ));
  }

  IconData _getChartIcon(String chartType) {
    switch (chartType) {
      case 'Speed':
        return Icons.speed;

      case 'Time':
        return Icons.access_time;
      case 'Calories':
        return Icons.local_fire_department;
      default:
        return Icons.bar_chart;
    }
  }

  Widget _buildSelectedChart(StatisticsChartsController controller) {
    return Obx(() {
      // Prevent rendering if widget is being disposed
      if (_isDisposed || !mounted) {
        return const SizedBox.shrink();
      }

      final chartType = controller.selectedChartType.value;

      // Use chartType as key to trigger AnimatedSwitcher
      Widget chart;
      switch (chartType) {
        case 'Speed':
          chart = _buildSpeedChart(controller);
          break;

        case 'Time':
          chart = _buildTimeChart(controller);
          break;
        case 'Calories':
          chart = _buildCaloriesChart(controller);
          break;
        default:
          chart = _buildSpeedChart(controller);
      }

      return Container(
        key: ValueKey(chartType),
        child: chart,
      );
    });
  }

  Widget _buildSpeedChart(StatisticsChartsController controller) {
    return Obx(() {
      // Prevent rendering if widget is being disposed
      if (_isDisposed || !mounted) {
        return const SizedBox.shrink();
      }

      if (controller.speedData.isEmpty) {
        return _buildNoDataPlaceholder('No speed data available', Icons.speed);
      }

      return RepaintBoundary(
        child: SfCartesianChart(
        plotAreaBorderWidth: 0,
        margin: const EdgeInsets.all(8),
        primaryXAxis: CategoryAxis(
          majorGridLines: const MajorGridLines(width: 0),
          axisLine: const AxisLine(width: 0),
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
        primaryYAxis: NumericAxis(
          majorGridLines: MajorGridLines(
            width: 0.5,
            color: Colors.white.withValues(alpha: 0.1),
            dashArray: const [5, 5],
          ),
          axisLine: const AxisLine(width: 0),
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
          ),
          title: AxisTitle(
            text: 'Speed (km/h)',
            textStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        tooltipBehavior: TooltipBehavior(
          enable: true,
          color: const Color(0xFF1a4ae6),
          textStyle: const TextStyle(color: Colors.white, fontSize: 11),
          borderColor: const Color(0xFFCDFF49),
          borderWidth: 1,
          elevation: 4,
        ),
        series: <CartesianSeries>[
          SplineAreaSeries<ChartDataPoint, String>(
            dataSource: controller.speedData,
            xValueMapper: (ChartDataPoint data, _) => data.label ?? '',
            yValueMapper: (ChartDataPoint data, _) => data.value,
            gradient: LinearGradient(
              colors: [
                const Color(0xFFCDFF49).withValues(alpha: 0.7),
                const Color(0xFFCDFF49).withValues(alpha: 0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderColor: const Color(0xFFCDFF49),
            borderWidth: 3,
            animationDuration: 0, // Disable animation to prevent disposal errors
            markerSettings: const MarkerSettings(
              isVisible: true,
              height: 6,
              width: 6,
              color: Color(0xFFCDFF49),
              borderColor: Color(0xFF2759FF),
              borderWidth: 2,
            ),
          ),
        ],
        ),
      );
    });
  }


  Widget _buildTimeChart(StatisticsChartsController controller) {
    return Obx(() {
      // Prevent rendering if widget is being disposed
      if (_isDisposed || !mounted) {
        return const SizedBox.shrink();
      }

      if (controller.timeData.isEmpty) {
        return _buildNoDataPlaceholder('No time data available', Icons.access_time);
      }

      return RepaintBoundary(
        child: SfCartesianChart(
        plotAreaBorderWidth: 0,
        margin: const EdgeInsets.all(8),
        primaryXAxis: CategoryAxis(
          majorGridLines: const MajorGridLines(width: 0),
          axisLine: const AxisLine(width: 0),
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
        primaryYAxis: NumericAxis(
          majorGridLines: MajorGridLines(
            width: 0.5,
            color: Colors.white.withValues(alpha: 0.1),
            dashArray: const [5, 5],
          ),
          axisLine: const AxisLine(width: 0),
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
          ),
          title: AxisTitle(
            text: 'Active Time (min)',
            textStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        tooltipBehavior: TooltipBehavior(
          enable: true,
          color: const Color(0xFF1a4ae6),
          textStyle: const TextStyle(color: Colors.white, fontSize: 11),
          borderColor: const Color(0xFFCDFF49),
          borderWidth: 1,
          elevation: 4,
        ),
        series: <CartesianSeries>[
          BarSeries<ChartDataPoint, String>(
            dataSource: controller.timeData,
            xValueMapper: (ChartDataPoint data, _) => data.label ?? '',
            yValueMapper: (ChartDataPoint data, _) => data.value,
            gradient: LinearGradient(
              colors: [
                const Color(0xFFCDFF49).withValues(alpha: 0.9),
                const Color(0xFFCDFF49).withValues(alpha: 0.6),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(6),
              bottomRight: Radius.circular(6),
            ),
            spacing: 0.3,
            animationDuration: 0, // Disable animation to prevent disposal errors
          ),
        ],
        ),
      );
    });
  }

  Widget _buildCaloriesChart(StatisticsChartsController controller) {
    return Obx(() {
      // Prevent rendering if widget is being disposed
      if (_isDisposed || !mounted) {
        return const SizedBox.shrink();
      }

      if (controller.caloriesData.isEmpty) {
        return _buildNoDataPlaceholder('No calories data available', Icons.local_fire_department);
      }

      return RepaintBoundary(
        child: SfCartesianChart(
        plotAreaBorderWidth: 0,
        margin: const EdgeInsets.all(8),
        primaryXAxis: CategoryAxis(
          majorGridLines: const MajorGridLines(width: 0),
          axisLine: const AxisLine(width: 0),
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
        primaryYAxis: NumericAxis(
          majorGridLines: MajorGridLines(
            width: 0.5,
            color: Colors.white.withValues(alpha: 0.1),
            dashArray: const [5, 5],
          ),
          axisLine: const AxisLine(width: 0),
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
          ),
          title: AxisTitle(
            text: 'Calories (kcal)',
            textStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        tooltipBehavior: TooltipBehavior(
          enable: true,
          color: const Color(0xFF1a4ae6),
          textStyle: const TextStyle(color: Colors.white, fontSize: 11),
          borderColor: const Color(0xFFCDFF49),
          borderWidth: 1,
          elevation: 4,
        ),
        series: <CartesianSeries>[
          LineSeries<ChartDataPoint, String>(
            dataSource: controller.caloriesData,
            xValueMapper: (ChartDataPoint data, _) => data.label ?? '',
            yValueMapper: (ChartDataPoint data, _) => data.value,
            color: const Color(0xFFCDFF49),
            width: 3,
            markerSettings: const MarkerSettings(
              isVisible: true,
              color: Color(0xFFCDFF49),
              borderColor: Color(0xFF2759FF),
              borderWidth: 2,
              height: 8,
              width: 8,
            ),
            animationDuration: 0, // Disable animation to prevent disposal errors
          ),
        ],
        ),
      );
    });
  }

  Widget _buildNoDataPlaceholder(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: Colors.white.withValues(alpha: 0.3),
          ).animate(onPlay: (controller) => controller.repeat())
              .fadeIn(duration: 800.ms)
              .fadeOut(duration: 800.ms, delay: 400.ms),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ).animate()
              .fadeIn(duration: 600.ms, delay: 200.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Shimmer effect on loading
          Shimmer.fromColors(
            baseColor: const Color(0xFFCDFF49).withValues(alpha: 0.3),
            highlightColor: const Color(0xFFCDFF49).withValues(alpha: 0.7),
            period: const Duration(milliseconds: 1500),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFCDFF49),
                  width: 4,
                ),
              ),
              child: const Icon(
                Icons.bar_chart,
                size: 40,
                color: Color(0xFFCDFF49),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Animated loading bars
          Column(
            children: List.generate(3, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Shimmer.fromColors(
                  baseColor: Colors.white.withValues(alpha: 0.1),
                  highlightColor: Colors.white.withValues(alpha: 0.3),
                  period: const Duration(milliseconds: 1500),
                  child: Container(
                    width: 200 - (index * 30.0),
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ).animate(delay: Duration(milliseconds: 100 * index))
                  .fadeIn(duration: 400.ms)
                  .slideX(begin: -0.2, end: 0, duration: 400.ms);
            }),
          ),

          const SizedBox(height: 16),
          Text(
            'Loading chart data...',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ).animate()
              .fadeIn(duration: 600.ms)
              .then(delay: 800.ms)
              .shimmer(duration: 1500.ms, color: const Color(0xFFCDFF49).withValues(alpha: 0.3)),
        ],
      ),
    );
  }

  Widget _buildCustomDropdown() {
    return Obx(() => GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onDropdownToggle?.call();
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
              widget.selectedFilter,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: widget.isDropdownOpen.value ? 0.5 : 0,
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
}
