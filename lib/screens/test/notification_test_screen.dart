import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../services/firebase_push_notification_service.dart';

/// Test screen for Cloud Functions push notifications
///
/// This screen allows you to test server-side notifications by calling
/// the deployed Cloud Functions.
///
/// Features:
/// - Test notification to current user (testNotificationToMe)
/// - Test notification with custom parameters (testNotification)
/// - Display FCM token for manual testing
class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isLoading = false;
  String? _fcmToken;
  String? _userId;
  String _lastResult = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _userId = user.uid;
        });
      }

      // Get FCM token
      final token = await FirebasePushNotificationService.getCurrentToken();
      setState(() {
        _fcmToken = token;
      });
    } catch (e) {
      print('❌ Error loading user info: $e');
    }
  }

  Future<void> _testNotificationToMe() async {
    setState(() {
      _isLoading = true;
      _lastResult = '';
    });

    try {
      print('🧪 Testing notification to authenticated user...');

      final callable = FirebaseFunctions.instance.httpsCallable('testNotificationToMe');
      final result = await callable.call();

      setState(() {
        _lastResult = '✅ Success: ${result.data['message']}\nMessage ID: ${result.data['messageId']}';
      });

      Get.snackbar(
        '✅ Success',
        'Notification sent! Check your device.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      print('✅ Test notification sent successfully: ${result.data}');
    } catch (e) {
      setState(() {
        _lastResult = '❌ Error: $e';
      });

      Get.snackbar(
        '❌ Error',
        'Failed to send notification: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      print('❌ Error sending test notification: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testCustomNotification() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      Get.snackbar(
        '⚠️ Missing Fields',
        'Please enter both title and body',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _lastResult = '';
    });

    try {
      print('🧪 Testing custom notification...');

      final callable = FirebaseFunctions.instance.httpsCallable('testNotification');
      final result = await callable.call({
        'userId': _userId,
        'title': _titleController.text,
        'body': _bodyController.text,
        'notificationType': 'CustomTest',
      });

      setState(() {
        _lastResult = '✅ Success: ${result.data['message']}\nMessage ID: ${result.data['messageId']}';
      });

      Get.snackbar(
        '✅ Success',
        'Custom notification sent!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      print('✅ Custom notification sent successfully: ${result.data}');
    } catch (e) {
      setState(() {
        _lastResult = '❌ Error: $e';
      });

      Get.snackbar(
        '❌ Error',
        'Failed to send notification: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      print('❌ Error sending custom notification: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyTokenToClipboard() {
    if (_fcmToken != null) {
      Clipboard.setData(ClipboardData(text: _fcmToken!));
      Get.snackbar(
        '📋 Copied',
        'FCM token copied to clipboard',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Cloud Functions Notifications'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Info',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('User ID: ${_userId ?? "Not logged in"}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'FCM Token: ${_fcmToken != null ? "${_fcmToken!.substring(0, 30)}..." : "Not available"}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        if (_fcmToken != null)
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: _copyTokenToClipboard,
                            tooltip: 'Copy full token',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quick Test Section
            const Text(
              'Quick Test',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Test Cloud Functions notification to your device:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testNotificationToMe,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.notifications_active),
              label: Text(_isLoading ? 'Sending...' : 'Send Test Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 32),

            // Custom Notification Section
            const Text(
              'Custom Notification',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create and send a custom notification:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Notification Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              decoration: InputDecoration(
                labelText: 'Notification Body',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.message),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testCustomNotification,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_isLoading ? 'Sending...' : 'Send Custom Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 32),

            // Result Section
            if (_lastResult.isNotEmpty) ...[
              const Text(
                'Last Result',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _lastResult.startsWith('✅')
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _lastResult.startsWith('✅')
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                child: Text(
                  _lastResult,
                  style: TextStyle(
                    color: _lastResult.startsWith('✅')
                        ? Colors.green.shade900
                        : Colors.red.shade900,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Instructions
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Testing Instructions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('1. Make sure you are logged in'),
                    const SizedBox(height: 8),
                    const Text('2. Verify FCM token is displayed above'),
                    const SizedBox(height: 8),
                    const Text('3. Click "Send Test Notification" for quick test'),
                    const SizedBox(height: 8),
                    const Text('4. Or enter custom title/body and send'),
                    const SizedBox(height: 8),
                    const Text('5. Check your device for the notification'),
                    const SizedBox(height: 8),
                    const Text('6. Notification should appear even in foreground'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
}
