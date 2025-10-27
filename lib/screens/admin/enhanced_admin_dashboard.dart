import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../services/admin/admin_auth_service.dart';
import '../../services/admin/admin_dashboard_service.dart';
import 'dashboard/models/dashboard_metrics.dart';
import 'dashboard/widgets/metric_card.dart';
import 'dashboard/widgets/user_growth_chart.dart';
import 'dashboard/widgets/race_activity_chart.dart';
import 'dashboard/widgets/subscription_chart.dart';
import 'dashboard/widgets/revenue_chart.dart';
import 'dashboard/widgets/activity_feed.dart';
import 'races/create_race_screen.dart';

/// Enhanced Admin Dashboard Screen
/// Complete dashboard with analytics, charts, and real-time data

class EnhancedAdminDashboardScreen extends StatefulWidget {
  const EnhancedAdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedAdminDashboardScreen> createState() =>
      _EnhancedAdminDashboardScreenState();
}

class _EnhancedAdminDashboardScreenState
    extends State<EnhancedAdminDashboardScreen> {
  String _selectedPage = 'dashboard';
  bool _isLoading = true;
  bool _isAdmin = false;
  User? _currentUser;
  DashboardMetrics? _metrics;
  bool _loadingMetrics = true;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        Get.offAllNamed('/admin-login');
      }
      return;
    }

    final isAdmin = await AdminAuthService.isAdminByUid(user.uid);

    if (!mounted) return;

    if (!isAdmin) {
      _showAccessDenied();
      return;
    }

    if (mounted) {
      setState(() {
        _currentUser = user;
        _isAdmin = true;
        _isLoading = false;
      });
      _loadMetrics();
    }
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _loadingMetrics = true;
    });

    try {
      final metrics = await AdminDashboardService.getDashboardMetrics();
      if (mounted) {
        setState(() {
          _metrics = metrics;
          _loadingMetrics = false;
        });
      }
    } catch (e) {
      print('Error loading metrics: $e');
      if (mounted) {
        setState(() {
          _loadingMetrics = false;
        });
      }
    }
  }

  void _showAccessDenied() {
    Get.snackbar(
      'Access Denied',
      'You do not have admin privileges',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );

    Future.delayed(const Duration(seconds: 2), () {
      FirebaseAuth.instance.signOut();
      Get.offAllNamed('/admin-login');
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text(
          'Confirm Logout',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      Get.offAllNamed('/admin-login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(
                color: Color(0xFF2759FF),
              ),
              SizedBox(height: 16),
              Text('Verifying admin access...'),
            ],
          ),
        ),
      );
    }

    if (!_isAdmin) {
      return const Scaffold(
        body: Center(
          child: Text('Access Denied'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2759FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Color(0xFF2759FF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'StepzSync',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1a1a1a),
                        ),
                      ),
                      Text(
                        'Admin Panel',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: [
                _buildMenuItem(
                  id: 'dashboard',
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  label: 'Dashboard',
                ),
                const SizedBox(height: 8),
                _buildMenuActionItem(
                  icon: Icons.add_circle_outline,
                  selectedIcon: Icons.add_circle,
                  label: 'Create Race',
                  color: const Color(0xFF10B981),
                  onTap: () {
                    Get.to(() => const AdminCreateRaceScreen());
                  },
                ),
                const SizedBox(height: 8),
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 8),
                _buildMenuItem(
                  id: 'users',
                  icon: Icons.people_outline,
                  selectedIcon: Icons.people,
                  label: 'Users',
                  badge: 'Soon',
                ),
                _buildMenuItem(
                  id: 'races',
                  icon: Icons.directions_run_outlined,
                  selectedIcon: Icons.directions_run,
                  label: 'Races',
                  badge: 'Soon',
                ),
                _buildMenuItem(
                  id: 'analytics',
                  icon: Icons.analytics_outlined,
                  selectedIcon: Icons.analytics,
                  label: 'Analytics',
                  badge: 'Soon',
                ),
                const SizedBox(height: 8),
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 8),
                _buildMenuItem(
                  id: 'settings',
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: 'Settings',
                  badge: 'Soon',
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, size: 18, color: Colors.red),
                label: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required String id,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    String? badge,
  }) {
    final isSelected = _selectedPage == id;
    final isDisabled = badge != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled
              ? null
              : () {
                  setState(() {
                    _selectedPage = id;
                  });
                },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF2759FF).withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected
                      ? const Color(0xFF2759FF)
                      : isDisabled
                          ? Colors.grey[400]
                          : Colors.grey[700],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? const Color(0xFF2759FF)
                          : isDisabled
                              ? Colors.grey[400]
                              : const Color(0xFF1a1a1a),
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuActionItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: color,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1a1a1a),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadMetrics,
            tooltip: 'Refresh Data',
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF2759FF),
                  child: Text(
                    _currentUser?.email?.substring(0, 1).toUpperCase() ?? 'A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Admin',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1a1a1a),
                      ),
                    ),
                    Text(
                      _currentUser?.email ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_loadingMetrics) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2759FF),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Metrics Cards
          if (_metrics != null) ...[
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'Total Users',
                    value: _metrics!.userMetrics.totalUsers.toString(),
                    icon: Icons.people_rounded,
                    iconColor: const Color(0xFF2759FF),
                    trend: _metrics!.userMetrics.growthRate,
                    trendLabel: 'vs last month',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: MetricCard(
                    label: 'Active Races',
                    value: _metrics!.raceMetrics.activeRaces.toString(),
                    icon: Icons.directions_run_rounded,
                    iconColor: const Color(0xFF10B981),
                    subtitle: '${_metrics!.raceMetrics.totalRaces} total races',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: MetricCard(
                    label: 'Monthly Revenue',
                    value: '\$${_metrics!.revenueMetrics.monthlyRevenue.toStringAsFixed(2)}',
                    icon: Icons.attach_money_rounded,
                    iconColor: const Color(0xFF10B981),
                    trend: _metrics!.revenueMetrics.growthRate,
                    trendLabel: 'vs last month',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: MetricCard(
                    label: 'DAU/MAU Ratio',
                    value: '${_metrics!.engagementMetrics.dau.toStringAsFixed(1)}%',
                    icon: Icons.analytics_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    subtitle: '${_metrics!.engagementMetrics.dailyActiveUsers} daily active',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Charts Row 1
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(
                flex: 2,
                child: UserGrowthChart(days: 30),
              ),
              SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: RaceActivityChart(days: 30),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Charts Row 2
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(
                flex: 2,
                child: SubscriptionChart(),
              ),
              SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: RevenueChart(months: 6),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Activity Feed
          const ActivityFeed(limit: 10),
        ],
      ),
    );
  }
}
