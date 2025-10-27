import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/dashboard_metrics.dart';
import '../../../../services/admin/admin_analytics_service.dart';

/// Revenue Trend Chart Widget
/// Displays revenue trends over time using Syncfusion Area Chart

class RevenueChart extends StatefulWidget {
  final int months;

  const RevenueChart({
    Key? key,
    this.months = 12,
  }) : super(key: key);

  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart> {
  bool _isLoading = true;
  RevenueHistoryData? _data;
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
      final data = await AdminAnalyticsService.getRevenueHistory(
        months: widget.months,
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
                    Icons.attach_money_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Revenue Trend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1a1a1a),
                  ),
                ),
                const Spacer(),
                if (_data != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.paid_rounded,
                          size: 14,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '\$${_data!.totalRevenue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadData,
                  tooltip: 'Refresh',
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Stats Row
            if (_data != null)
              Row(
                children: [
                  _buildStatItem(
                    'Total Revenue',
                    '\$${_data!.totalRevenue.toStringAsFixed(2)}',
                  ),
                  const SizedBox(width: 24),
                  _buildStatItem(
                    'Avg. Monthly',
                    '\$${_data!.averageRevenue.toStringAsFixed(2)}',
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Chart Content
            SizedBox(
              height: 260,
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1a1a1a),
          ),
        ),
      ],
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
              Icons.monetization_on_outlined,
              color: Colors.grey[300],
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No revenue data available',
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
        intervalType: DateTimeIntervalType.months,
        dateFormat: widget.months > 6 ? null : null,
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
        labelFormat: '\${value}',
        minimum: 0,
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        color: const Color(0xFF1a1a1a),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
        format: 'point.x: \$point.y',
      ),
      series: <CartesianSeries<ChartDataPoint, DateTime>>[
        SplineAreaSeries<ChartDataPoint, DateTime>(
          dataSource: _data!.dataPoints,
          xValueMapper: (ChartDataPoint data, _) => data.date,
          yValueMapper: (ChartDataPoint data, _) => data.value,
          name: 'Revenue',
          color: const Color(0xFF10B981).withOpacity(0.3),
          borderColor: const Color(0xFF10B981),
          borderWidth: 3,
          gradient: LinearGradient(
            colors: [
              const Color(0xFF10B981).withOpacity(0.4),
              const Color(0xFF10B981).withOpacity(0.05),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          markerSettings: const MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            width: 6,
            height: 6,
            borderWidth: 2,
            borderColor: Color(0xFF10B981),
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
