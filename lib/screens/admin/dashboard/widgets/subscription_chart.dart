import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/dashboard_metrics.dart';
import '../../../../services/admin/admin_analytics_service.dart';

/// Subscription Distribution Chart Widget
/// Displays subscription tier distribution using Syncfusion Doughnut Chart

class SubscriptionChart extends StatefulWidget {
  const SubscriptionChart({Key? key}) : super(key: key);

  @override
  State<SubscriptionChart> createState() => _SubscriptionChartState();
}

class _SubscriptionChartState extends State<SubscriptionChart> {
  bool _isLoading = true;
  SubscriptionDistribution? _data;
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
      final data = await AdminAnalyticsService.getSubscriptionDistribution();

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
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.pie_chart_rounded,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Subscription Distribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1a1a1a),
                  ),
                ),
                const Spacer(),
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
              height: 320,
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
          color: Color(0xFFF59E0B),
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

    if (_data == null || _data!.totalUsers == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.subscriptions_outlined,
              color: Colors.grey[300],
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No subscription data available',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final chartData = [
      _SubscriptionData(
        tier: 'Free',
        users: _data!.freeUsers,
        color: const Color(0xFF94A3B8),
      ),
      _SubscriptionData(
        tier: 'Premium 1',
        users: _data!.premium1Users,
        color: const Color(0xFF2759FF),
      ),
      _SubscriptionData(
        tier: 'Premium 2',
        users: _data!.premium2Users,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    return Row(
      children: [
        // Chart
        Expanded(
          flex: 3,
          child: SfCircularChart(
            legend: const Legend(
              isVisible: false,
            ),
            tooltipBehavior: TooltipBehavior(
              enable: true,
              color: const Color(0xFF1a1a1a),
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              format: 'point.x: point.y users (point.percentage%)',
            ),
            series: <CircularSeries>[
              DoughnutSeries<_SubscriptionData, String>(
                dataSource: chartData,
                xValueMapper: (_SubscriptionData data, _) => data.tier,
                yValueMapper: (_SubscriptionData data, _) => data.users,
                pointColorMapper: (_SubscriptionData data, _) => data.color,
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  labelPosition: ChartDataLabelPosition.outside,
                  textStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  connectorLineSettings: ConnectorLineSettings(
                    type: ConnectorType.curve,
                    length: '15%',
                  ),
                ),
                dataLabelMapper: (_SubscriptionData data, _) =>
                    '${data.percentage.toStringAsFixed(1)}%',
                innerRadius: '70%',
                radius: '90%',
                explode: true,
                explodeIndex: 1,
                explodeOffset: '5%',
              ),
            ],
          ),
        ),

        // Legend with Stats
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendItem(
                'Free',
                _data!.freeUsers,
                _data!.freePercentage,
                const Color(0xFF94A3B8),
              ),
              const SizedBox(height: 16),
              _buildLegendItem(
                'Premium 1',
                _data!.premium1Users,
                _data!.premium1Percentage,
                const Color(0xFF2759FF),
              ),
              const SizedBox(height: 16),
              _buildLegendItem(
                'Premium 2',
                _data!.premium2Users,
                _data!.premium2Percentage,
                const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Users',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    _data!.totalUsers.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1a1a1a),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, int count, double percentage, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count users',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1a1a1a),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubscriptionData {
  final String tier;
  final int users;
  final Color color;

  _SubscriptionData({
    required this.tier,
    required this.users,
    required this.color,
  });

  double get percentage {
    // This will be calculated by the chart
    return 0.0;
  }
}
