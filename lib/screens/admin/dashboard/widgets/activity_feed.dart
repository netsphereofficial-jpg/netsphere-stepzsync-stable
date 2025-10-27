import 'package:flutter/material.dart';
import '../models/dashboard_metrics.dart';
import '../../../../services/admin/admin_dashboard_service.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Activity Feed Widget
/// Displays real-time activity feed with Firestore stream

class ActivityFeed extends StatefulWidget {
  final int limit;

  const ActivityFeed({
    Key? key,
    this.limit = 20,
  }) : super(key: key);

  @override
  State<ActivityFeed> createState() => _ActivityFeedState();
}

class _ActivityFeedState extends State<ActivityFeed> {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_activity_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1a1a1a),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Activity List
          StreamBuilder<List<ActivityFeedItem>>(
            stream: AdminDashboardService.getActivityFeedStream(
              limit: widget.limit,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[300],
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load activity feed',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final activities = snapshot.data ?? [];

              if (activities.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          color: Colors.grey[300],
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No recent activity',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activities.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Colors.grey[200],
                ),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return _ActivityItem(activity: activity);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final ActivityFeedItem activity;

  const _ActivityItem({
    Key? key,
    required this.activity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final activityConfig = _getActivityConfig(activity.type);

    return InkWell(
      onTap: () {
        // TODO: Navigate to details
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 16.0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: activityConfig.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                activityConfig.icon,
                color: activityConfig.color,
                size: 20,
              ),
            ),

            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1a1a1a),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeago.format(activity.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                      if (activity.userName != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.person_outline,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            activity.userName!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: activityConfig.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                activity.type.displayName,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: activityConfig.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ActivityConfig _getActivityConfig(ActivityType type) {
    switch (type) {
      case ActivityType.newUser:
        return _ActivityConfig(
          icon: Icons.person_add_rounded,
          color: const Color(0xFF2759FF),
        );
      case ActivityType.raceCreated:
        return _ActivityConfig(
          icon: Icons.add_circle_rounded,
          color: const Color(0xFF10B981),
        );
      case ActivityType.raceStarted:
        return _ActivityConfig(
          icon: Icons.play_circle_rounded,
          color: const Color(0xFFF59E0B),
        );
      case ActivityType.raceCompleted:
        return _ActivityConfig(
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF10B981),
        );
      case ActivityType.subscriptionPurchased:
        return _ActivityConfig(
          icon: Icons.shopping_cart_rounded,
          color: const Color(0xFF8B5CF6),
        );
      case ActivityType.subscriptionCancelled:
        return _ActivityConfig(
          icon: Icons.cancel_rounded,
          color: const Color(0xFFEF4444),
        );
      case ActivityType.reportSubmitted:
        return _ActivityConfig(
          icon: Icons.flag_rounded,
          color: const Color(0xFFEF4444),
        );
      case ActivityType.other:
        return _ActivityConfig(
          icon: Icons.info_rounded,
          color: const Color(0xFF94A3B8),
        );
    }
  }
}

class _ActivityConfig {
  final IconData icon;
  final Color color;

  _ActivityConfig({
    required this.icon,
    required this.color,
  });
}
