import 'package:flutter/material.dart';
import '../services/notification_test_service.dart';

/// Test screen for notification deep linking
/// Add this to your app for easy testing
class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({Key? key}) : super(key: key);

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    // Print all notification types to console
    NotificationTestService.printAllNotificationTypes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Notification Deep Link Test'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade50, Colors.white],
          ),
        ),
        child: _isTesting
            ? _buildTestingView()
            : _buildTestSelectionView(),
      ),
    );
  }

  Widget _buildTestingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          const Text(
            'Sending Test Notifications...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Check your notification tray!',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isTesting = false;
              });
            },
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  Widget _buildTestSelectionView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Card(
            color: Colors.deepPurple.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📱 Notification Deep Link Tester',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Test all 24 notification types and their deep linking functionality.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📋 Coverage:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text('• 16 Race notifications'),
                        Text('• 4 Social/Friend notifications'),
                        Text('• 2 Chat notifications'),
                        Text('• 2 Special notifications'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quick Tests Section
          const Text(
            '🚀 Quick Tests',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTestButton(
            icon: '⚡',
            title: 'Quick Test',
            subtitle: 'One from each category (3 notifications)',
            color: Colors.green,
            onPressed: () => _runTest(() => NotificationTestService.quickTest()),
          ),
          const SizedBox(height: 8),
          _buildTestButton(
            icon: '🏁',
            title: 'Race Notifications Only',
            subtitle: '16 race-related notifications',
            color: Colors.blue,
            onPressed: () => _runTest(() => NotificationTestService.testRaceNotificationsOnly()),
          ),
          const SizedBox(height: 8),
          _buildTestButton(
            icon: '👥',
            title: 'Social Notifications Only',
            subtitle: '4 friend-related notifications',
            color: Colors.purple,
            onPressed: () => _runTest(() => NotificationTestService.testSocialNotificationsOnly()),
          ),
          const SizedBox(height: 24),

          // Comprehensive Test Section
          const Text(
            '🔬 Comprehensive Test',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTestButton(
            icon: '🧪',
            title: 'Test All 24 Notification Types',
            subtitle: 'Full test with 3-second delay between each',
            color: Colors.deepOrange,
            onPressed: () => _runTest(() => NotificationTestService.testAllNotifications()),
          ),
          const SizedBox(height: 24),

          // Individual Tests Section
          const Text(
            '🎯 Individual Tests',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildIndividualTestsGrid(),
          const SizedBox(height: 24),

          // Instructions
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      const Text(
                        'How to Test',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. Choose a test above to send notifications\n'
                    '2. Check your notification tray\n'
                    '3. TAP each notification to test deep linking\n'
                    '4. Verify that it navigates to the correct screen\n'
                    '5. Test in different app states:\n'
                    '   • Foreground (app open)\n'
                    '   • Background (app minimized)\n'
                    '   • Terminated (app closed)',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTestButton({
    required String icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: color, width: 4),
            ),
          ),
          child: Row(
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndividualTestsGrid() {
    final tests = [
      {'icon': '🏃‍♂️', 'name': 'Race Invite', 'type': 'InviteRace'},
      {'icon': '🚀', 'name': 'Race Start', 'type': 'RaceBegin'},
      {'icon': '👥', 'name': 'Friend Request', 'type': 'FriendRequest'},
      {'icon': '🏆', 'name': 'Race Won', 'type': 'RaceWon'},
      {'icon': '💬', 'name': 'Chat Message', 'type': 'ChatMessage'},
      {'icon': '🌟', 'name': 'Hall of Fame', 'type': 'HallOfFame'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemCount: tests.length,
      itemBuilder: (context, index) {
        final test = tests[index];
        return Card(
          child: InkWell(
            onTap: () => _runTest(
              () => NotificationTestService.testNotificationType(
                test['type'] as String,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    test['icon'] as String,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    test['name'] as String,
                    style: const TextStyle(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _runTest(Future<void> Function() testFunction) async {
    setState(() {
      _isTesting = true;
    });

    try {
      await testFunction();
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      print('❌ Test failed: $e');
    }

    if (mounted) {
      setState(() {
        _isTesting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Test notifications sent! Check your notification tray.'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
