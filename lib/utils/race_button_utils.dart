import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../core/models/race_data_model.dart';
import '../services/pending_requests_service.dart';
import '../services/race_invite_service.dart';

class RaceButtonUtils {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Convert raceTypeId to string for compatibility
  static String getRaceTypeString(int? raceTypeId) {
    switch (raceTypeId) {
      case 1:
        return 'solo';
      case 2:
        return 'private';
      case 3:
        return 'public';
      default:
        return 'public';
    }
  }

  /// Get the appropriate button text for a race
  static String getButtonText(RaceData race) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return 'Login to Join';

    // Check if user is already a participant (includes accepted invites)
    if (race.participants?.any((p) => p.userId == currentUserId) == true) {
      return 'Joined';
    }

    // Special case for solo races created by user - automatically joined
    final raceTypeString = getRaceTypeString(race.raceTypeId);
    if (raceTypeString == 'solo' && race.organizerUserId == currentUserId) {
      return 'Joined';
    }

    // Check if race is full
    final participantCount = race.participants?.length ?? 0;
    if (participantCount >= (race.maxParticipants ?? 0)) {
      return 'Race Full';
    }

    // Check if user has already sent a join request for private races
    try {
      final pendingService = Get.find<PendingRequestsService>();
      if ((raceTypeString == 'private') &&
          pendingService.hasPendingRequest(race.id)) {
        return 'Requested';
      }
    } catch (e) {
      // Service not available, continue with default logic
    }

    // Return appropriate action based on race type
    switch (raceTypeString) {
      case 'public':
        return 'Join';
      case 'private':
        return 'Request to Join';
      case 'solo':
        return 'Joined'; // Solo races are automatically joined
      default:
        return 'Join';
    }
  }

  /// Check if the race button should be enabled
  static bool isButtonEnabled(RaceData race) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    // Always clickable to view details if already joined
    if (race.participants?.any((p) => p.userId == currentUserId) == true) {
      return true;
    }

    // Solo races created by user are always clickable (auto-joined)
    final raceTypeString = getRaceTypeString(race.raceTypeId);
    if (raceTypeString == 'solo' && race.organizerUserId == currentUserId) {
      return true;
    }

    // Disabled if race is full
    final participantCount = race.participants?.length ?? 0;
    if (participantCount >= (race.maxParticipants ?? 0)) return false;

    // Disabled if race is completed
    if (race.status == 'completed') return false;

    // Disabled if user has already sent a join request (except for viewing details)
    try {
      final pendingService = Get.find<PendingRequestsService>();
      if (raceTypeString == 'private' &&
          pendingService.hasPendingRequest(race.id)) {
        return false; // Disable button to prevent duplicate requests
      }
    } catch (e) {
      // Service not available, continue with default logic
    }

    return true;
  }

  /// Handle race button press with consistent logic
  static void handleRaceButtonPress(
    RaceData race, {
    Function(RaceData)? onJoinRace,
    Function(RaceData)? onRequestToJoin,
    Function(RaceData)? onNavigateToDetails,
  }) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      Get.toNamed('/login');
      return;
    }

    final raceTypeString = getRaceTypeString(race.raceTypeId);

    // If already joined or solo race created by user, navigate to race details
    if (race.participants?.any((p) => p.userId == currentUserId) == true ||
        (raceTypeString == 'solo' && race.organizerUserId == currentUserId)) {
      if (onNavigateToDetails != null) {
        onNavigateToDetails(race);
      } else {
        Get.toNamed('/race-details/${race.id}');
      }
      return;
    }

    // Handle joining based on race type
    switch (raceTypeString) {
      case 'public':
        if (onJoinRace != null) {
          onJoinRace(race);
        }
        break;
      case 'private':
        if (onRequestToJoin != null) {
          onRequestToJoin(race);
        }
        break;
      case 'solo':
        // Other solo races, navigate to details
        if (onNavigateToDetails != null) {
          onNavigateToDetails(race);
        } else {
          Get.toNamed('/race-details/${race.id}');
        }
        break;
      default:
        if (onJoinRace != null) {
          onJoinRace(race);
        }
    }
  }

  /// Send join request for private race
  static Future<bool> sendJoinRequest(RaceData race, {String? message}) async {
    try {
      final raceInviteService = RaceInviteService();
      return await raceInviteService.sendJoinRequest(
        race: race,
        message: message,
      );
    } catch (e) {
      print('Error sending join request: $e');
      return false;
    }
  }

  /// Check if user can join race (public races)
  static bool canJoinRace(RaceData race) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    // Can't join if already a participant
    if (race.participants?.any((p) => p.userId == currentUserId) == true) {
      return false;
    }

    // Can't join if race is full
    final participantCount = race.participants?.length ?? 0;
    if (participantCount >= (race.maxParticipants ?? 0)) {
      return false;
    }

    // Can't join if race is completed
    if (race.status == 'completed') return false;

    return true;
  }
}