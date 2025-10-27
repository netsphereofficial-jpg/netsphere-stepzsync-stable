import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/dashboard_metrics.dart';
import '../../../../services/admin/admin_analytics_service.dart';

/// Race Activity Chart Widget
/// Displays race activity over time using Syncfusion Column Chart

class RaceActivityChart extends StatefulWidget {
  final int days;

  const RaceActivityChart({
    Key? key,
    this.days = 30,
  }) : super(key: key);

  @override
  State<RaceActivityChart> createState() => _RaceActivityChartState();
}

class _RaceActivityChartState extends State<RaceActivityChart> {
  bool _isLoading = true;
  RaceActivityData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await AdminAnalyticsService.getRaceActivityData(
        days: widget.days,
      );

      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.directions_run_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Race Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1a1a1a),
                  ),
                ),
                const Spacer(),
                if (_data != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.event_rounded,
                          size: 14,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_data!.totalRaces} races',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1a1a1a),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadData,
                  tooltip: 'Refresh',
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Chart Content
            SizedBox(
              height: 300,
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF10B981),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[300],
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load data',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_data == null || _data!.dataPoints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_run_outlined,
              color: Colors.grey[300],
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No race data available',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: DateTimeAxis(
        majorGridLines: const MajorGridLines(width: 0),
        minorGridLines: const MinorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: TextStyle(
          fontSize: 11,
          color: Colors.grey[600],
        ),
        intervalType: DateTimeIntervalType.days,
      ),
      primaryYAxis: NumericAxis(
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.grey[200]!,
          dashArray: const [5, 5],
        ),
        minorGridLines: const MinorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: TextStyle(
          fontSize: 11,
          color: Colors.grey[600],
        ),
        minimum: 0,
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        color: const Color(0xFF1a1a1a),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
        format: 'point.x: point.y races',
      ),
      series: <CartesianSeries<ChartDataPoint, DateTime>>[
        ColumnSeries<ChartDataPoint, DateTime>(
          dataSource: _data!.dataPoints,
          xValueMapper: (ChartDataPoint data, _) => data.date,
          yValueMapper: (ChartDataPoint data, _) => data.value,
          name: 'Races',
          color: const Color(0xFF10B981),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(4),
          ),
          width: 0.7,
          gradient: LinearGradient(
            colors: [
              const Color(0xFF10B981),
              const Color(0xFF10B981).withOpacity(0.7),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ],
    );
  }
}
