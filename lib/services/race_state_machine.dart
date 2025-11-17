import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Race Status State Machine
///
/// State Transitions:
/// - 0 (Created)    → 1 (Scheduled)  : When schedule time is set
/// - 1 (Scheduled)  → 3 (Active)     : When organizer starts race OR schedule time arrives
/// - 3 (Active)     → 6 (Ending)     : When first participant finishes
/// - 6 (Ending)     → 4 (Completed)  : When deadline timer expires
/// - Any            → 7 (Cancelled)  : When race is cancelled
///
/// Solo Race Flow:
/// - 0 (Created) → 3 (Active) → 4 (Completed)
class RaceStateMachine {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Status ID Constants
  static const int STATUS_CREATED = 0;
  static const int STATUS_SCHEDULED = 1;
  static const int STATUS_ACTIVE = 3;
  static const int STATUS_ENDING = 6;
  static const int STATUS_COMPLETED = 4;
  static const int STATUS_CANCELLED = 7;

  /// Status String Constants
  static const String STATUS_STR_CREATED = 'created';
  static const String STATUS_STR_SCHEDULED = 'scheduled';
  static const String STATUS_STR_ACTIVE = 'active';
  static const String STATUS_STR_ENDING = 'ending';
  static const String STATUS_STR_COMPLETED = 'completed';
  static const String STATUS_STR_CANCELLED = 'cancelled';

  /// Transition: Created → Scheduled
  /// Called when schedule time is set for a race
  static Future<bool> transitionToScheduled(String raceId, DateTime scheduleTime) async {
    try {
      final raceRef = _firestore.collection('races').doc(raceId);
      final raceDoc = await raceRef.get();

      if (!raceDoc.exists) {
        print('❌ Race not found: $raceId');
        return false;
      }

      final currentStatus = raceDoc.data()?['statusId'] ?? 0;

      // Validate transition
      if (currentStatus != STATUS_CREATED) {
        print('⚠️ Invalid transition: Cannot move from status $currentStatus to SCHEDULED');
        return false;
      }

      // Update to scheduled status
      await raceRef.update({
        'statusId': STATUS_SCHEDULED,
        'status': STATUS_STR_SCHEDULED,
        'raceScheduleTime': Timestamp.fromDate(scheduleTime),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Race $raceId transitioned to SCHEDULED');
      return true;
    } catch (e) {
      print('❌ Error transitioning to scheduled: $e');
      return false;
    }
  }

  /// Transition: Scheduled/Created → Active
  /// Called when organizer clicks "Start Race" button
  static Future<bool> transitionToActive(String raceId) async {
    try {
      final raceRef = _firestore.collection('races').doc(raceId);
      final raceDoc = await raceRef.get();

      if (!raceDoc.exists) {
        print('❌ Race not found: $raceId');
        return false;
      }

      final raceData = raceDoc.data()!;
      final currentStatus = raceData['statusId'] ?? 0;
      final organizerUserId = raceData['organizerUserId'];
      final currentUserId = _auth.currentUser?.uid;

      // Validate organizer
      if (organizerUserId != currentUserId) {
        print('⚠️ Only organizer can start the race');
        return false;
      }

      // Validate transition
      if (currentStatus != STATUS_CREATED && currentStatus != STATUS_SCHEDULED) {
        print('⚠️ Invalid transition: Cannot start race from status $currentStatus');
        return false;
      }

      // Update to active status
      await raceRef.update({
        'statusId': STATUS_ACTIVE,
        'status': STATUS_STR_ACTIVE,
        'actualStartTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Race $raceId transitioned to ACTIVE');

      // ✅ Notifications handled by Cloud Functions (onRaceStatusChanged)
      // See: functions/notifications/triggers/raceTriggers.js:112-149

      return true;
    } catch (e) {
      print('❌ Error transitioning to active: $e');
      return false;
    }
  }

  /// Transition: Active → Ending
  /// Called when first participant finishes the race
  /// ✅ IMPROVED: Uses Firebase transaction for atomic status changes
  static Future<bool> transitionToEnding(
    String raceId,
    String firstFinisherUserId,
    int durationMinutes,
  ) async {
    try {
      final raceRef = _firestore.collection('races').doc(raceId);

      // ✅ FIX: Use transaction to ensure atomic status transition
      final success = await _firestore.runTransaction((transaction) async {
        final raceDoc = await transaction.get(raceRef);

        if (!raceDoc.exists) {
          print('❌ Race not found: $raceId');
          return false;
        }

        final raceData = raceDoc.data()!;
        final currentStatus = raceData['statusId'] ?? 0;

        // Validate transition - only allow Active (3) → Ending (6)
        if (currentStatus != STATUS_ACTIVE) {
          print('⚠️ Invalid transition: Cannot move to ENDING from status $currentStatus');
          return false;
        }

        // Calculate deadline (current time + duration in minutes)
        final deadline = DateTime.now().add(Duration(minutes: durationMinutes));

        // ✅ CRITICAL: Atomic update within transaction
        transaction.update(raceRef, {
          'statusId': STATUS_ENDING,
          'status': STATUS_STR_ENDING,
          'firstFinisherUserId': firstFinisherUserId,
          'firstFinishedAt': FieldValue.serverTimestamp(),
          'raceDeadline': Timestamp.fromDate(deadline),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Race $raceId transitioned to ENDING via transaction (deadline: $deadline)');
        return true;
      });

      if (success) {
        // ✅ Notifications handled by Cloud Functions
        // TODO: Add Cloud Function trigger for race ending notifications
        // When first participant finishes, notify others about deadline
      }

      return success;
    } catch (e) {
      print('❌ Error transitioning to ending: $e');
      return false;
    }
  }

  /// Transition: Ending → Completed
  /// Called when deadline timer expires OR all participants finish
  /// ✅ IMPROVED: Uses Firebase transaction for atomic status changes
  static Future<bool> transitionToCompleted(String raceId) async {
    try {
      final raceRef = _firestore.collection('races').doc(raceId);

      // ✅ FIX: Use transaction to ensure atomic status transition
      final success = await _firestore.runTransaction((transaction) async {
        final raceDoc = await transaction.get(raceRef);

        if (!raceDoc.exists) {
          print('❌ Race not found: $raceId');
          return false;
        }

        final currentStatus = raceDoc.data()?['statusId'] ?? 0;

        // Validate transition - allow both Ending (6) and Active (3) → Completed (4)
        if (currentStatus != STATUS_ENDING && currentStatus != STATUS_ACTIVE) {
          print('⚠️ Invalid transition: Cannot complete from status $currentStatus');
          return false;
        }

        // ✅ CRITICAL: Atomic update within transaction
        transaction.update(raceRef, {
          'statusId': STATUS_COMPLETED,
          'status': STATUS_STR_COMPLETED,
          'actualEndTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          // ✅ FIX: Stop all scheduled notifications for this race
          'notificationsActive': false,
          'countdownNotificationSent': true,
        });

        print('✅ Race $raceId transitioned to COMPLETED via transaction');
        return true;
      });

      if (success) {
        // TODO: Award XP to all participants
        // ✅ Notifications handled by Cloud Functions (onRaceStatusChanged)
        // See: functions/notifications/triggers/raceTriggers.js:112-149
      }

      return success;
    } catch (e) {
      print('❌ Error transitioning to completed: $e');
      return false;
    }
  }

  /// Transition: Any → Cancelled
  /// Called when race is cancelled (no participants, organizer cancels, etc.)
  static Future<bool> transitionToCancelled(String raceId, String reason) async {
    try {
      final raceRef = _firestore.collection('races').doc(raceId);

      await raceRef.update({
        'statusId': STATUS_CANCELLED,
        'status': STATUS_STR_CANCELLED,
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // ✅ FIX: Stop all scheduled notifications for this race
        'notificationsActive': false,
        'countdownNotificationSent': true,
      });

      print('✅ Race $raceId transitioned to CANCELLED: $reason');

      // TODO: Add Cloud Function trigger for race cancellation notifications

      return true;
    } catch (e) {
      print('❌ Error transitioning to cancelled: $e');
      return false;
    }
  }

  /// Check if all participants have finished
  static Future<bool> areAllParticipantsFinished(String raceId) async {
    try {
      final participantsSnapshot = await _firestore
          .collection('races')
          .doc(raceId)
          .collection('participants')
          .get();

      if (participantsSnapshot.docs.isEmpty) return false;

      // Check if all participants have isCompleted = true
      for (final doc in participantsSnapshot.docs) {
        final isCompleted = doc.data()['isCompleted'] ?? false;
        if (!isCompleted) {
          return false; // Found at least one unfinished participant
        }
      }

      return true; // All participants finished
    } catch (e) {
      print('❌ Error checking participants completion: $e');
      return false;
    }
  }

  /// Get current race status
  static Future<int?> getCurrentStatus(String raceId) async {
    try {
      final raceDoc = await _firestore.collection('races').doc(raceId).get();
      if (!raceDoc.exists) return null;
      return raceDoc.data()?['statusId'];
    } catch (e) {
      print('❌ Error getting race status: $e');
      return null;
    }
  }

  // ================= NOTIFICATION HELPERS =================
  // ✅ All race status notifications are now handled by Cloud Functions!
  // See: functions/notifications/triggers/raceTriggers.js
  //
  // Automatic triggers:
  // - onRaceStatusChanged: Sends notifications when race status changes (started, completed)
  // - Race ending notifications: Handled by Cloud Function when first participant finishes

  // ============ AUTOMATIC RACE START MONITORING ============

  static Timer? _raceMonitoringTimer;

  /// Start monitoring scheduled races for automatic start
  /// Call this on app initialization to enable automatic race starts
  static void startScheduledRaceMonitoring() {
    if (_raceMonitoringTimer != null && _raceMonitoringTimer!.isActive) {
      print('⚠️ Race monitoring already active');
      return;
    }

    print('🚀 Starting scheduled race monitoring...');

    // Check immediately on start
    _checkAndStartScheduledRaces();

    // Then check every minute
    _raceMonitoringTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      _checkAndStartScheduledRaces();
    });

    print('✅ Scheduled race monitoring started');
  }

  /// Stop monitoring scheduled races
  static void stopScheduledRaceMonitoring() {
    _raceMonitoringTimer?.cancel();
    _raceMonitoringTimer = null;
    print('🛑 Stopped scheduled race monitoring');
  }

  /// Check for races that should auto-start based on schedule time
  static Future<void> _checkAndStartScheduledRaces() async {
    try {
      final now = DateTime.now();

      // Query for scheduled races (statusId == 1) with schedule time in the past or now
      final querySnapshot = await _firestore
          .collection('races')
          .where('statusId', isEqualTo: STATUS_SCHEDULED)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return;
      }

      print('🔍 Checking ${querySnapshot.docs.length} scheduled races for auto-start');

      for (final doc in querySnapshot.docs) {
        try {
          final raceData = doc.data();
          final raceId = doc.id;
          final scheduleTimeField = raceData['raceScheduleTime'];

          if (scheduleTimeField == null) {
            continue; // No schedule time set
          }

          DateTime? scheduleTime;

          // Parse schedule time (handle Timestamp, ISO String, and custom format)
          if (scheduleTimeField is Timestamp) {
            scheduleTime = scheduleTimeField.toDate();
          } else if (scheduleTimeField is String) {
            try {
              // Try ISO 8601 format first
              scheduleTime = DateTime.parse(scheduleTimeField);
            } catch (e1) {
              // Try custom format: "09-10-2025 11:52 PM"
              try {
                final formatter = DateFormat('MM-dd-yyyy hh:mm a');
                scheduleTime = formatter.parse(scheduleTimeField);
              } catch (e2) {
                print('⚠️ Could not parse schedule time for race $raceId: $scheduleTimeField');
                print('   Tried ISO format and custom format (MM-dd-yyyy hh:mm a)');
                continue;
              }
            }
          }

          // Check if schedule time has arrived or passed
          if (scheduleTime != null && !now.isBefore(scheduleTime)) {
            print('⏰ Race $raceId schedule time reached (${scheduleTime}), starting automatically...');

            // Transition to active WITHOUT requiring organizer
            // We bypass the organizer check by updating directly
            await _firestore.runTransaction((transaction) async {
              final freshDoc = await transaction.get(doc.reference);

              if (!freshDoc.exists) {
                return;
              }

              final freshData = freshDoc.data() as Map<String, dynamic>;
              final currentStatus = freshData['statusId'] ?? 0;

              // Only start if still scheduled
              if (currentStatus == STATUS_SCHEDULED) {
                transaction.update(doc.reference, {
                  'statusId': STATUS_ACTIVE,
                  'status': STATUS_STR_ACTIVE,
                  'actualStartTime': FieldValue.serverTimestamp(),
                  'autoStarted': true, // Mark as auto-started
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                print('✅ Automatically started race $raceId');

                // Update all participants status from 'joined' to 'active'
                final participantsSnapshot = await doc.reference
                    .collection('participants')
                    .get();

                for (var participantDoc in participantsSnapshot.docs) {
                  transaction.update(participantDoc.reference, {
                    'status': 'active',
                    'lastUpdated': FieldValue.serverTimestamp(),
                  });
                }
              }
            });

            // ✅ Notification handled by Cloud Functions (onRaceStatusChanged)
            // The Cloud Function detects statusId change to ACTIVE and sends notifications
          }
        } catch (e) {
          print('❌ Error auto-starting race ${doc.id}: $e');
          // Continue with other races even if one fails
        }
      }
    } catch (e) {
      print('❌ Error checking scheduled races: $e');
    }
  }
}
