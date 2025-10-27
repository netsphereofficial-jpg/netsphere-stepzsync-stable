import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../../core/models/race_data_model.dart';

class CompletedRacesController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  // Observable lists and states
  final RxList<RaceData> completedRaces = <RaceData>[].obs;
  final RxBool isLoading = false.obs;

  // Stream subscription for real-time updates
  StreamSubscription<QuerySnapshot>? _completedRacesSubscription;

  // Current user ID
  String? get currentUserId => auth.currentUser?.uid;

  @override
  void onInit() {
    super.onInit();
    _listenToCompletedRaces();
  }

  @override
  void onClose() {
    // Properly dispose of stream subscription to prevent memory leaks
    _completedRacesSubscription?.cancel();
    _completedRacesSubscription = null;
    super.onClose();
  }

  /// Listen to completed races in real-time
  /// This replaces the one-time fetch with a continuous stream
  ///
  /// ✅ OPTIMIZED: Now includes races where:
  /// - statusId is 4 (completed) or 6 (deadline ended)
  /// - statusId is 3 (active) but user has isCompleted=true (just finished their portion)
  void _listenToCompletedRaces() {
    if (currentUserId == null) {
      log('❌ No current user ID for listening to completed races');
      return;
    }

    // Cancel any existing subscription
    _completedRacesSubscription?.cancel();

    isLoading.value = true;

    // Set up real-time listener for completed races
    // Include status 3 (active), 6 (ending), and 4 (completed) to catch races
    // where user finished but race is still ongoing for others
    _completedRacesSubscription = _firestore
        .collection('races')
        .where('statusId', whereIn: [3, 4, 6])
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen(
      (querySnapshot) {
        _processCompletedRacesSnapshot(querySnapshot);
      },
      onError: (error) {
        log('❌ Error listening to completed races: $error');
        isLoading.value = false;
      },
    );

    log('✅ Started listening to completed races in real-time (including active races where user finished)');
  }

  /// Process snapshot from Firestore listener
  /// ✅ OPTIMIZED: Now checks participants subcollection for user completion status
  void _processCompletedRacesSnapshot(QuerySnapshot querySnapshot) async {
    try {
      if (currentUserId == null) return;

      final List<RaceData> races = [];

      for (final doc in querySnapshot.docs) {
        try {
          final raceData = RaceData.fromFirestore(doc);

          // Find current user's participant data
          final userParticipant = raceData.participants?.firstWhere(
            (p) => p.userId == currentUserId,
            orElse: () => Participant(
              userId: '', userName: '', distance: 0, remainingDistance: 0,
              rank: 0, steps: 0, calories: 0, avgSpeed: 0.0, isCompleted: false
            ),
          );

          // Also check if user was the organizer
          final wasOrganizer = raceData.organizerUserId == currentUserId;

          // ✅ CRITICAL FIX: For active races (status 3), check participants subcollection
          // to get the most up-to-date completion status
          bool userCompleted = userParticipant?.isCompleted ?? false;

          if (raceData.statusId == 3 && userParticipant?.userId == currentUserId) {
            // For active races, fetch fresh data from participants subcollection
            try {
              final participantDoc = await _firestore
                  .collection('races')
                  .doc(doc.id)
                  .collection('participants')
                  .doc(currentUserId)
                  .get();

              if (participantDoc.exists) {
                userCompleted = participantDoc.data()?['isCompleted'] ?? false;
              }
            } catch (e) {
              log('⚠️ Error fetching participant data from subcollection: $e');
              // Fall back to the participant data from the main document
            }
          }

          // Include race if:
          // - Status 4 (race fully completed) AND user participated/organized OR
          // - Status 6 (deadline ended) AND user has completed their portion OR
          // - Status 3 (active) AND user has completed their portion (just finished!)
          final shouldInclude = (raceData.statusId == 4 && (userParticipant?.userId == currentUserId || wasOrganizer)) ||
                               (raceData.statusId == 6 && userCompleted) ||
                               (raceData.statusId == 3 && userCompleted);

          if (shouldInclude) {
            races.add(raceData);
          }
        } catch (e) {
          log('Error parsing completed race document ${doc.id}: $e');
        }
      }

      completedRaces.value = races;
      isLoading.value = false;

      log('✅ Updated completed races list with ${races.length} races (real-time)');
    } catch (e) {
      log('❌ Error processing completed races snapshot: $e');
      isLoading.value = false;
    }
  }

  /// Fetch all completed races where user participated (one-time fetch)
  /// This is now deprecated in favor of real-time listener but kept for manual refresh
  /// ✅ OPTIMIZED: Now includes active races where user has completed their portion
  Future<void> fetchCompletedRaces() async {
    try {
      isLoading.value = true;

      if (currentUserId == null) {
        log('❌ No current user ID');
        isLoading.value = false;
        return;
      }

      // Query races where statusId is 3 (active), 6 (ending), or 4 (completed)
      final querySnapshot = await _firestore
          .collection('races')
          .where('statusId', whereIn: [3, 4, 6])
          .orderBy('updatedAt', descending: true)
          .get();

      final List<RaceData> races = [];

      for (final doc in querySnapshot.docs) {
        try {
          final raceData = RaceData.fromFirestore(doc);

          // Find current user's participant data
          final userParticipant = raceData.participants?.firstWhere(
            (p) => p.userId == currentUserId,
            orElse: () => Participant(
              userId: '', userName: '', distance: 0, remainingDistance: 0,
              rank: 0, steps: 0, calories: 0, avgSpeed: 0.0, isCompleted: false
            ),
          );

          // Also check if user was the organizer
          final wasOrganizer = raceData.organizerUserId == currentUserId;

          // ✅ CRITICAL FIX: For active races, check participants subcollection
          bool userCompleted = userParticipant?.isCompleted ?? false;

          if (raceData.statusId == 3 && userParticipant?.userId == currentUserId) {
            // For active races, fetch fresh data from participants subcollection
            try {
              final participantDoc = await _firestore
                  .collection('races')
                  .doc(doc.id)
                  .collection('participants')
                  .doc(currentUserId)
                  .get();

              if (participantDoc.exists) {
                userCompleted = participantDoc.data()?['isCompleted'] ?? false;
              }
            } catch (e) {
              log('⚠️ Error fetching participant data from subcollection: $e');
            }
          }

          // Include race if:
          // - Status 4 (race fully completed) AND user participated/organized OR
          // - Status 6 (deadline ended) AND user has completed their portion OR
          // - Status 3 (active) AND user has completed their portion (just finished!)
          final shouldInclude = (raceData.statusId == 4 && (userParticipant?.userId == currentUserId || wasOrganizer)) ||
                               (raceData.statusId == 6 && userCompleted) ||
                               (raceData.statusId == 3 && userCompleted);

          if (shouldInclude) {
            races.add(raceData);
          }
        } catch (e) {
          log('Error parsing completed race document ${doc.id}: $e');
        }
      }

      completedRaces.value = races;
      isLoading.value = false;

      log('✅ Fetched ${races.length} completed races for user (manual refresh)');
    } catch (e) {
      log('❌ Error fetching completed races: $e');
      isLoading.value = false;
    }
  }

  /// Refresh completed races
  Future<void> refreshCompletedRaces() async {
    await fetchCompletedRaces();
  }

  /// Get user's participant data for a specific race
  Participant? getUserParticipantData(RaceData race) {
    if (currentUserId == null) return null;

    return race.participants?.firstWhere(
      (p) => p.userId == currentUserId,
      orElse: () => Participant(
        userId: '',
        userName: '',
        distance: 0,
        remainingDistance: 0,
        rank: 0,
        steps: 0,
        calories: 0,
        avgSpeed: 0.0,
      ),
    );
  }

  /// Get total number of completed races
  int get totalCompletedRaces => completedRaces.length;

  /// Get number of podium finishes (top 3)
  int get podiumFinishes {
    return completedRaces.where((race) {
      final participant = getUserParticipantData(race);
      final rank = participant?.rank ?? 0;
      final finishOrder = participant?.finishOrder ?? 0;
      return rank <= 3 || finishOrder <= 3;
    }).length;
  }

  /// Get total distance covered in completed races
  double get totalDistanceCovered {
    double total = 0.0;
    for (final race in completedRaces) {
      final participant = getUserParticipantData(race);
      total += participant?.distance ?? 0.0;
    }
    return total;
  }

  /// Get total calories burned in completed races
  int get totalCaloriesBurned {
    int total = 0;
    for (final race in completedRaces) {
      final participant = getUserParticipantData(race);
      total += participant?.calories ?? 0;
    }
    return total;
  }
}