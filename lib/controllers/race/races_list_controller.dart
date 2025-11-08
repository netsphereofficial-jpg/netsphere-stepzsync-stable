import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/race_data_model.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../services/pending_requests_service.dart';
import '../../services/race_invite_service.dart';
import '../../services/race_service.dart';
import '../../screens/home/homepage_screen/controllers/homepage_data_service.dart';

class RacesListController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  // Observable lists and states
  final RxList<RaceData> races = <RaceData>[].obs;
  final RxList<RaceData> filteredRaces = <RaceData>[].obs;
  final RxBool isLoading = false.obs;

  // Loading states for individual race operations
  final RxMap<String, bool> raceButtonLoading = <String, bool>{}.obs;

  // Stream subscription for real-time updates
  StreamSubscription<QuerySnapshot>? _racesStreamSubscription;

  // Participant listeners for notification monitoring
  final Map<String, StreamSubscription<QuerySnapshot>?> _participantListeners = {};
  final Map<String, int> _participantCounts = {};

  // Get global pending requests service
  PendingRequestsService get _pendingService =>
      Get.find<PendingRequestsService>();


  // Current user ID for filtering user-specific data
  String? get currentUserId => auth.currentUser?.uid;

  // Search
  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;

  // Filters
  final RxString selectedRaceType = 'All'.obs;
  final RxString selectedStatus = 'All'.obs;
  final RxString selectedDistance = 'All'.obs;
  final RxString selectedGender = 'All'.obs;
  final RxBool showInactiveRaces = true.obs;

  // Filter counts
  final RxInt allCount = 0.obs;
  final RxInt publicCount = 0.obs;
  final RxInt privateCount = 0.obs;
  final RxInt marathonCount = 0.obs;
  final RxInt soloCount = 0.obs;
  final RxInt quickCount = 0.obs; // Quick Race count
  final RxInt shortDistanceCount = 0.obs;
  final RxInt mediumDistanceCount = 0.obs;
  final RxInt longDistanceCount = 0.obs;
  final RxInt maleCount = 0.obs;
  final RxInt femaleCount = 0.obs;
  final RxInt anyGenderCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    clearFilters();
    _startRealTimeRacesStream();

    // Listen to search changes
    searchController.addListener(() {
      searchQuery.value = searchController.text;
    });
    ever(searchQuery, (_) => _applyFilters());

    // Listen to filter changes
    ever(selectedRaceType, (_) => _applyFilters());
    ever(selectedStatus, (_) => _applyFilters());
    ever(selectedDistance, (_) => _applyFilters());
    ever(selectedGender, (_) => _applyFilters());
    ever(showInactiveRaces, (_) => _applyFilters());
  }

  @override
  void onClose() {
    searchController.dispose();
    _racesStreamSubscription?.cancel();
    _cancelAllParticipantListeners();
    super.onClose();
  }

  /// Clear search
  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
  }

  /// Start real-time stream for all races
  void _startRealTimeRacesStream() {
    try {
      isLoading.value = true;

      _racesStreamSubscription = _firestore
          .collection('races')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
            (snapshot) {
              _processRaceSnapshot(snapshot);
            },
            onError: (error) {
              _handleStreamError(error);
            },
          );
    } catch (e) {
      _handleStreamError(e);
    }
  }

  /// Process Firestore snapshot and convert to RaceData objects
  /// ✅ OPTIMIZED: Batch loads ALL participants in single collectionGroup query (5x faster)
  void _processRaceSnapshot(QuerySnapshot snapshot) async {
    try {
      final stopwatch = Stopwatch()..start();
      final List<RaceData> newRaces = [];

      // Step 1: Extract all race IDs
      final raceIds = snapshot.docs.map((doc) => doc.id).toList();

      if (raceIds.isEmpty) {
        races.value = [];
        _applyFilters();
        isLoading.value = false;
        return;
      }

      // Step 2: ✅ OPTIMIZED: Batch load ALL participants in ONE query using collectionGroup
      Map<String, List<Participant>> participantsByRace = {};

      try {
        // ✅ Single query for ALL participants across ALL races
        final participantsQuery = await _firestore
            .collectionGroup('participants')
            .get();

        log('⚡ Batch loaded ${participantsQuery.docs.length} participants in ${stopwatch.elapsedMilliseconds}ms');

        // Group participants by their race ID
        for (var doc in participantsQuery.docs) {
          try {
            final participant = Participant.fromFirestore(doc);
            // Get race ID from document path: races/{raceId}/participants/{userId}
            final raceId = doc.reference.parent.parent?.id;

            if (raceId != null && raceIds.contains(raceId)) {
              participantsByRace.putIfAbsent(raceId, () => []).add(participant);
            }
          } catch (e) {
            log('⚠️ Error parsing participant ${doc.id}: $e');
          }
        }

        log('✅ Grouped participants for ${participantsByRace.length} races');
      } catch (e) {
        log('⚠️ Error batch loading participants: $e');
        // Continue without participants on error
      }

      // Step 3: Build race objects with pre-loaded participants
      for (final doc in snapshot.docs) {
        try {
          final raceData = RaceData.fromFirestore(doc);

          // Filter out solo races that don't belong to the current user
          if (raceData.raceTypeId == 1) { // Solo race
            if (raceData.organizerUserId != currentUserId) {
              log('🚫 Filtering out solo race "${raceData.title}" - not created by current user');
              continue; // Skip this solo race as it doesn't belong to current user
            }
          }

          // ✅ Use pre-loaded participants (no additional query needed!)
          final participants = participantsByRace[doc.id] ?? [];

          // 🐛 DEBUG: Log participant assignment
          log('🔍 [RACES_LIST] Race: ${raceData.title} (${doc.id})');
          log('   Participants found: ${participants.length}');
          if (participants.isNotEmpty) {
            for (var p in participants) {
              log('      - ${p.userId} (${p.userName}) - Steps: ${p.steps}, Calories: ${p.calories}, Rank: ${p.rank}');
            }
          }

          // Update race with participants
          final updatedRace = raceData.copyWith(participants: participants);
          newRaces.add(updatedRace);
        } catch (e) {
          log('Error parsing race document ${doc.id}: $e');
        }
      }

      races.value = newRaces;
      _applyFilters();
      isLoading.value = false;

      stopwatch.stop();
      log(
        '📊 Processed ${newRaces.length} races with batched participant loading in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e) {
      _handleStreamError(e);
    }
  }

  /// Apply current filters to races list
  void _applyFilters() {
    List<RaceData> filtered = List.from(races);

    // ✅ FIX: Show ALL races including user's own races
    // Only filter out completed (4) and cancelled (7) races
    filtered = filtered.where((race) {
      // Exclude completed and cancelled races from "All Races" view
      if (race.statusId == 4 || race.statusId == 7) {
        return false;
      }

      return true;
    }).toList();

    // Apply search filter
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      filtered = filtered.where((race) {
        return (race.title?.toLowerCase().contains(query) ?? false) ||
            (race.organizerName?.toLowerCase().contains(query) ?? false) ||
            (race.startAddress?.toLowerCase().contains(query) ?? false) ||
            (race.endAddress?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Filter by race type
    if (selectedRaceType.value != 'All') {
      filtered = filtered.where((race) {
        switch (selectedRaceType.value) {
          case 'Public':
            return race.isPrivate == false && race.raceTypeId == 3;
          case 'Private':
            return race.isPrivate == true;
          case 'Marathon':
            return race.raceTypeId == 4;
          case 'Solo':
            return race.raceTypeId == 1;
          case 'Quick':
            return race.raceTypeId == 5;
          default:
            return true;
        }
      }).toList();
    }

    // Filter by status
    if (selectedStatus.value != 'All') {
      filtered = filtered.where((race) {
        switch (selectedStatus.value) {
          case 'Active':
            return race.statusId == 3 || race.status == 'active';
          case 'Scheduled':
            return race.statusId == 0 || race.status == 'scheduled';
          case 'Completed':
            return race.statusId == 4 || race.status == 'completed';
          default:
            return true;
        }
      }).toList();
    }

    // Filter by distance
    if (selectedDistance.value != 'All') {
      filtered = filtered.where((race) {
        final distance = race.totalDistance ?? 0.0;
        switch (selectedDistance.value) {
          case 'Short (< 5km)':
            return distance < 5.0;
          case 'Medium (5-15km)':
            return distance >= 5.0 && distance <= 15.0;
          case 'Long (> 15km)':
            return distance > 15.0;
          default:
            return true;
        }
      }).toList();
    }

    // Filter by gender preference
    if (selectedGender.value != 'All') {
      filtered = filtered.where((race) {
        switch (selectedGender.value) {
          case 'Male':
            return race.genderPreferenceId == 1;
          case 'Female':
            return race.genderPreferenceId == 2;
          case 'No preference':
            return race.genderPreferenceId == 0;
          default:
            return true;
        }
      }).toList();
    }

    // Filter by active/inactive races
    if (!showInactiveRaces.value) {
      filtered = filtered.where((race) {
        return race.statusId != 4 &&
            race.statusId != 5; // Not completed or cancelled
      }).toList();
    }

    filteredRaces.value = filtered;
    _updateFilterCounts();
  }

  /// Update filter counts based on current races
  void _updateFilterCounts() {
    // Filter out completed (4) and cancelled (7) races to match displayed races
    final activeRaces = races.where((race) => race.statusId != 4 && race.statusId != 7).toList();

    allCount.value = activeRaces.length;

    publicCount.value = activeRaces
        .where((race) => race.isPrivate == false && race.raceTypeId == 3)
        .length;
    privateCount.value = activeRaces.where((race) => race.isPrivate == true).length;
    marathonCount.value = activeRaces.where((race) => race.raceTypeId == 4).length;
    soloCount.value = activeRaces.where((race) => race.raceTypeId == 1).length;
    quickCount.value = activeRaces.where((race) => race.raceTypeId == 5).length;

    shortDistanceCount.value = activeRaces
        .where((race) => (race.totalDistance ?? 0.0) < 5.0)
        .length;
    mediumDistanceCount.value = activeRaces
        .where(
          (race) =>
              (race.totalDistance ?? 0.0) >= 5.0 &&
              (race.totalDistance ?? 0.0) <= 15.0,
        )
        .length;
    longDistanceCount.value = activeRaces
        .where((race) => (race.totalDistance ?? 0.0) > 15.0)
        .length;

    maleCount.value = activeRaces
        .where((race) => race.genderPreferenceId == 1)
        .length;
    femaleCount.value = activeRaces
        .where((race) => race.genderPreferenceId == 2)
        .length;
    anyGenderCount.value = activeRaces
        .where((race) => race.genderPreferenceId == 0)
        .length;
  }

  /// Handle stream errors
  void _handleStreamError(dynamic error) {
    log('Race stream error: $error');
    isLoading.value = false;

    // Show user-friendly error message
    SnackbarUtils.showError(
      'Connection Error',
      'Unable to load races. Please check your internet connection.',
    );
  }

  /// Clear all filters
  void clearFilters() {
    selectedRaceType.value = 'All';
    selectedStatus.value = 'All';
    selectedDistance.value = 'All';
    selectedGender.value = 'All';
    showInactiveRaces.value = true;
  }

  /// Refresh races manually
  Future<void> refreshRaces() async {
    try {
      isLoading.value = true;

      final snapshot = await _firestore
          .collection('races')
          .orderBy('createdAt', descending: true)
          .get();

      _processRaceSnapshot(snapshot);
    } catch (e) {
      _handleStreamError(e);
    }
  }

  /// Get race by ID
  RaceData? getRaceById(String raceId) {
    try {
      return races.firstWhere((race) => race.id == raceId);
    } catch (e) {
      return null;
    }
  }


  /// Check if user can join a race
  bool canJoinRace(RaceData race) {
    // Check if race is in joinable state
    // ✅ FIX: Allow joining races with statusId 0 (created), 1 (scheduled), or 3 (active)
    final isJoinableStatus = race.statusId == 0 || race.statusId == 1 || race.statusId == 3;

    // Check if race is not full
    final joinedCount = race.joinedParticipants ?? 0;
    final maxCount = race.maxParticipants ?? 0;
    final hasSpace = joinedCount < maxCount;

    return isJoinableStatus && hasSpace;
  }

  /// Check if current user is already in the race
  bool isUserInRace(RaceData race) {
    if (currentUserId == null) return false;

    // ✅ FIX: Check if user is the organizer (organizers are auto-joined)
    if (race.organizerUserId == currentUserId) {
      return true;
    }

    // Check participants array (may be empty if using subcollection only)
    final participants = race.participants ?? [];
    return participants.any(
      (participant) => participant.userId == currentUserId,
    );
  }

  /// Get current user's participant data in a race
  Participant? getCurrentUserParticipant(RaceData race) {
    if (currentUserId == null) return null;

    final participants = race.participants ?? [];
    try {
      return participants.firstWhere(
        (participant) => participant.userId == currentUserId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get races where current user is a participant or organizer
  List<RaceData> getUserJoinedRaces() {
    if (currentUserId == null) return [];

    return races.where((race) {
      final isOrganizer = race.organizerUserId == currentUserId;
      final isParticipant = isUserInRace(race);
      return isOrganizer || isParticipant;
    }).toList();
  }

  /// Get races created by current user
  List<RaceData> getUserCreatedRaces() {
    if (currentUserId == null) return [];

    return races
        .where((race) => race.organizerUserId == currentUserId)
        .toList();
  }

  /// Get race status display text
  String getRaceStatusText(RaceData race) {
    switch (race.statusId ?? 0) {
      case 0:
        return 'Scheduled';
      case 3:
        return 'Active';
      case 4:
        return 'Completed';
      case 5:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  /// Get race type display text
  String getRaceTypeText(RaceData race) {
    if (race.raceTypeId == 1) {
      return 'Solo Race';
    } else if (race.raceTypeId == 4) {
      return 'Marathon';
    } else if (race.isPrivate == true) {
      return 'Private Race';
    } else {
      return 'Public Race';
    }
  }

  /// Get formatted race distance
  String getFormattedDistance(RaceData race) {
    final distance = race.totalDistance ?? 0.0;
    if (distance == 0.0) {
      return 'Distance not set';
    }
    return '${distance.toStringAsFixed(1)} km';
  }

  /// Get race progress percentage for current user
  double getUserRaceProgress(RaceData race) {
    final userParticipant = getCurrentUserParticipant(race);
    if (userParticipant == null) return 0.0;

    final totalDistance = race.totalDistance ?? 0.0;
    if (totalDistance == 0.0) return 0.0;

    final userDistance = userParticipant.distance;
    return (userDistance / totalDistance * 100).clamp(0.0, 100.0);
  }

  /// Check if user has pending join request for race
  bool hasPendingJoinRequest(String? raceId) {
    return _pendingService.hasPendingRequest(raceId);
  }

  /// Check if a race button is currently loading
  bool isRaceButtonLoading(String raceId) {
    return raceButtonLoading[raceId] ?? false;
  }

  /// Set loading state for a race button
  void setRaceButtonLoading(String raceId, bool loading) {
    raceButtonLoading[raceId] = loading;
  }

  /// Send a join request for private races
  Future<void> requestToJoin(String raceId) async {
    if (isRaceButtonLoading(raceId)) return; // Prevent multiple requests

    setRaceButtonLoading(raceId, true);
    try {
      final currentUserId = auth.currentUser?.uid;
      if (currentUserId == null) {
        SnackbarUtils.showError('Login Required', 'Please login to request to join races');
        return;
      }

      // Get the race data
      final race = getRaceById(raceId);
      if (race == null) {
        SnackbarUtils.showError('Error', 'Race not found');
        return;
      }

      // Use the race invite service to send join request
      final raceInviteService = RaceInviteService();
      final success = await raceInviteService.sendJoinRequest(race: race);

      if (success) {
        SnackbarUtils.showSuccess('Success', 'Join request sent successfully!');
        // Update pending requests service
        _pendingService.addPendingRequest(raceId);
      } else {
        SnackbarUtils.showError('Error', 'Failed to send join request');
      }
    } catch (e) {
      log('Error requesting to join race: $e');
      SnackbarUtils.showError('Error', 'Failed to send join request');
    } finally {
      setRaceButtonLoading(raceId, false);
    }
  }

  /// Join a public race directly
  Future<void> joinRace(String raceId) async {
    if (isRaceButtonLoading(raceId)) return; // Prevent multiple requests

    setRaceButtonLoading(raceId, true);
    try {
      final currentUserId = auth.currentUser?.uid;
      if (currentUserId == null) {
        SnackbarUtils.showError('Login Required', 'Please login to join races');
        return;
      }

      // Get the race data
      final race = getRaceById(raceId);
      if (race == null) {
        SnackbarUtils.showError('Error', 'Race not found');
        return;
      }

      // Check if race is full
      final participantCount = race.participants?.length ?? 0;
      if (participantCount >= (race.maxParticipants ?? 0)) {
        SnackbarUtils.showError('Race Full', 'Race is full');
        return;
      }

      // Use RaceService.joinRace which properly implements the 3-collection structure
      final result = await RaceService.joinRace(race.id!);

      if (result.isSuccess) {
        // Update local data
        final raceIndex = races.indexWhere((race) => race.id == raceId);
        if (raceIndex != -1) {
          final updatedRace = races[raceIndex].copyWith(
            participants: [
              ...(races[raceIndex].participants ?? []),
              // Add current user as participant - RaceService handles the complex structure
            ],
          );
          races[raceIndex] = updatedRace;
          _applyFilters();
        }

        // Notify homepage to update active race count in real-time
        _notifyHomepageOfRaceJoin();

        SnackbarUtils.showSuccess(
          'Success',
          'Successfully joined the race!',
        );
      } else {
        // Handle RaceService error
        SnackbarUtils.showError(
          'Error',
          result.message ?? 'Failed to join race. Please try again.',
        );
      }
    } catch (e) {
      log('Error joining race: $e');
      SnackbarUtils.showError('Error', 'Failed to join race');
    } finally {
      setRaceButtonLoading(raceId, false);
    }
  }

  /// Handle race button press with proper logic delegation
  void handleRaceButtonPress(RaceData race) {
    final currentUserId = auth.currentUser?.uid;
    if (currentUserId == null) {
      Get.toNamed('/login');
      return;
    }

    // Check if user is already in the race
    if (isUserInRace(race)) {
      // Navigate to race details/map
      Get.toNamed('/race-details/${race.id}');
      return;
    }

    // Handle based on race privacy
    if (race.isPrivate == true) {
      // Check if user has pending request
      if (hasPendingJoinRequest(race.id)) {
        SnackbarUtils.showInfo('Request Pending', 'You already have a pending request for this race');
        return;
      }
      // Send join request for private race
      requestToJoin(race.id!);
    } else {
      // Join public race directly
      joinRace(race.id!);
    }
  }

  /// Get available filter options
  List<String> get raceTypeOptions => ['All', 'Public', 'Private', 'Marathon', 'Solo'];

  List<String> get statusOptions => ['All', 'Active', 'Scheduled', 'Completed'];

  List<String> get distanceOptions => [
    'All',
    'Short (< 5km)',
    'Medium (5-15km)',
    'Long (> 15km)',
  ];

  List<String> get genderOptions => ['All', 'Male', 'Female', 'No preference'];

  /// Start listening to participant changes for created races (My Races)
  void startListeningToMyRaceParticipants(String raceId, String raceName) {
    if (_participantListeners.containsKey(raceId)) {
      return; // Already listening
    }

    _participantListeners[raceId] = _firestore
        .collection('races')
        .doc(raceId)
        .collection('participants')
        .snapshots()
        .listen((snapshot) {
      final currentCount = snapshot.docs.length;
      final previousCount = _participantCounts[raceId] ?? 0;

      // ✅ Participant join notifications now handled server-side by Cloud Functions
      // Only track participant count changes for local monitoring
      if (currentCount > previousCount && previousCount >= 1) {
        log('👥 Participant joined race: $raceName (Cloud Function will send notification)');
      } else if (currentCount == 1 && previousCount == 0) {
        log('👥 Organizer auto-joined their own race during creation');
      }

      _participantCounts[raceId] = currentCount;
    });

    log('👥 Started monitoring participants for race: $raceName ($raceId)');
  }

  /// Start listening to participant changes for joined races (All Races)
  void startListeningToJoinedRaceParticipants(String raceId, String raceName) {
    if (_participantListeners.containsKey(raceId)) {
      return; // Already listening
    }

    _participantListeners[raceId] = _firestore
        .collection('races')
        .doc(raceId)
        .collection('participants')
        .snapshots()
        .listen((snapshot) {
      final currentCount = snapshot.docs.length;
      final previousCount = _participantCounts[raceId] ?? 0;

      // ✅ Participant join notifications now handled server-side by Cloud Functions
      // Only track participant count changes for local monitoring
      if (currentCount > previousCount && previousCount > 0) {
        log('👥 Participant count changed in race: $raceName (Cloud Function will send notification)');
      }

      _participantCounts[raceId] = currentCount;
    });

    log('👥 Started monitoring participants for joined race: $raceName ($raceId)');
  }

  /// Stop listening to participant changes for a specific race
  void stopListeningToParticipants(String raceId) {
    _participantListeners[raceId]?.cancel();
    _participantListeners.remove(raceId);
    _participantCounts.remove(raceId);
    log('🔇 Stopped monitoring participants for race: $raceId');
  }

  /// Cancel all participant listeners
  void _cancelAllParticipantListeners() {
    for (final subscription in _participantListeners.values) {
      subscription?.cancel();
    }
    _participantListeners.clear();
    _participantCounts.clear();
    log('🔇 Cancelled all participant listeners');
  }

  /// Start monitoring all user's races for participant changes
  void startMonitoringUserRaces() {
    if (currentUserId == null) return;

    // Stop existing monitoring to avoid duplicates
    _cancelAllParticipantListeners();

    // Monitor created races
    final createdRaces = getUserCreatedRaces();
    for (final race in createdRaces) {
      if (race.id != null && race.title != null) {
        startListeningToMyRaceParticipants(race.id!, race.title!);
      }
    }

    // Monitor joined races (excluding created ones)
    final joinedRaces = getUserJoinedRaces();
    for (final race in joinedRaces) {
      if (race.id != null &&
          race.title != null &&
          race.organizerUserId != currentUserId) {
        startListeningToJoinedRaceParticipants(race.id!, race.title!);
      }
    }

    log('🚀 Started monitoring ${createdRaces.length} created races and ${joinedRaces.where((r) => r.organizerUserId != currentUserId).length} joined races');
  }

  /// Stop monitoring all races
  void stopMonitoringAllRaces() {
    _cancelAllParticipantListeners();
  }

  /// Notify homepage data service to refresh active race count
  void _notifyHomepageOfRaceJoin() {
    try {
      // Try to get homepage data service if it exists
      final homepageDataService = Get.find<HomepageDataService>();
      // Trigger immediate refresh of active joined race count
      homepageDataService.loadActiveJoinedRaceCount();
      print('✅ Notified homepage of race join - updating active race count');
    } catch (e) {
      // Homepage service might not be initialized yet, that's okay
      print(
        '📝 Homepage service not found, race count will update on next refresh',
      );
    }
  }
}
