import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/models/race_data_model.dart';
import '../widgets/dialogs/friend_selector_dialog.dart';

/// Service to handle race sharing functionality
class RaceShareService {
  /// Show friend selector dialog to share a race
  static void showShareDialog(BuildContext context, RaceData race) {
    showDialog(
      context: context,
      builder: (context) => FriendSelectorDialog(race: race),
    );
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

  /// Get share message for a race
  static String getShareMessage(RaceData race) {
    final distance = (race.totalDistance ?? 0.0).toStringAsFixed(1);
    final location = race.startAddress ?? 'Unknown Location';
    final time = race.raceScheduleTime ?? 'TBD';

    return 'Join me in "${race.title ?? 'this race'}"! '
           '$distance km starting at $location on $time. '
           'Let\'s race together!';
  }
}
