import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../core/models/race_data_model.dart';
import '../widgets/dialogs/share_options_dialog.dart';

/// Service to handle race sharing functionality
class RaceShareService {
  /// Show share options dialog (in-app friends or external)
  static void showShareDialog(BuildContext context, RaceData race) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => ShareOptionsDialog(race: race),
    );
  }

  /// Share race externally via system share sheet
  /// Opens native share dialog (WhatsApp, SMS, Email, etc.)
  static Future<void> shareExternally(RaceData race, {Rect? sharePositionOrigin}) async {
    try {
      final message = _getExternalShareMessage(race);

      await Share.share(
        message,
        subject: 'Join my race on StepzSync!',
        sharePositionOrigin: sharePositionOrigin,
      );

      debugPrint('✅ Race share dialog opened');
    } catch (e) {
      debugPrint('❌ Error sharing race: $e');
      Get.snackbar(
        'Error',
        'Failed to share race. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Check if a race can be shared
  /// Cannot share completed races (statusId == 4)
  static bool canShareRace(RaceData race) {
    // Don't show share button for completed races
    if (race.statusId == 4) {
      return false;
    }

    // All other races can be shared
    return race.id != null && race.id!.isNotEmpty;
  }

  /// Get formatted message for external sharing
  static String _getExternalShareMessage(RaceData race) {
    final title = race.title ?? 'this race';
    final distance = (race.totalDistance ?? 0.0).toStringAsFixed(1);
    final location = race.startAddress ?? 'Unknown Location';
    final time = _formatScheduleTime(race.raceScheduleTime);
    final raceId = race.id ?? '';

    return '''Join me in "$title"!

📏 Distance: $distance km
📍 Location: $location
📅 Schedule: $time

Download StepzSync and search for race ID: $raceId

Let's race together!''';
  }

  /// Format schedule time for external sharing
  static String _formatScheduleTime(String? scheduleTime) {
    if (scheduleTime == null || scheduleTime.isEmpty) {
      return 'TBD';
    }

    try {
      // Try to parse as ISO format (2025-11-09T02:59:02.645963)
      final DateTime dateTime = DateTime.parse(scheduleTime);
      return DateFormat('MMM dd, yyyy at h:mm a').format(dateTime);
    } catch (e) {
      try {
        // Try to parse the format "dd/MM/yyyy at hh:mm a"
        if (scheduleTime.contains(' at ')) {
          final parts = scheduleTime.split(' at ');
          if (parts.length >= 2) {
            final datePart = parts[0];
            final timePart = parts[1];
            final DateTime date = DateFormat('dd/MM/yyyy').parse(datePart);
            final formattedDate = DateFormat('MMM dd, yyyy').format(date);
            return '$formattedDate at $timePart';
          }
        }
        // If no " at " separator, try standard format
        final DateTime dateTime = DateFormat('dd-MM-yyyy hh:mm a').parse(scheduleTime);
        return DateFormat('MMM dd, yyyy at h:mm a').format(dateTime);
      } catch (e2) {
        debugPrint('⚠️ Could not parse schedule time: $scheduleTime');
        return scheduleTime; // Return as-is if parsing fails
      }
    }
  }

  /// Get share message for a race (legacy method for in-app use)
  static String getShareMessage(RaceData race) {
    final distance = (race.totalDistance ?? 0.0).toStringAsFixed(1);
    final location = race.startAddress ?? 'Unknown Location';
    final time = race.raceScheduleTime ?? 'TBD';

    return 'Join me in "${race.title ?? 'this race'}"! '
           '$distance km starting at $location on $time. '
           'Let\'s race together!';
  }
}
