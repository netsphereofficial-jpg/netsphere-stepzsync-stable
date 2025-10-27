import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class PendingRequestsService extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Track pending join requests globally
  final RxMap<String, bool> pendingJoinRequests = <String, bool>{}.obs;

  String? get _currentUserId => _auth.currentUser?.uid;

  @override
  void onInit() {
    super.onInit();
    _loadPendingJoinRequests();
  }

  /// Load existing pending join requests from Firebase
  Future<void> _loadPendingJoinRequests() async {
    try {
      if (_currentUserId == null) return;

      final pendingRequests = await _firestore
          .collection('race_invites')
          .where('fromUserId', isEqualTo: _currentUserId)
          .where('isJoinRequest', isEqualTo: true)
          .where('status', isEqualTo: 'pending')
          .get();

      // Clear existing cache and populate with current pending requests
      pendingJoinRequests.clear();
      for (final doc in pendingRequests.docs) {
        final data = doc.data();
        final raceId = data['raceId'];
        if (raceId != null) {
          pendingJoinRequests[raceId] = true;
        }
      }

      print('✅ PendingRequestsService: Loaded ${pendingJoinRequests.length} pending join requests');
    } catch (e) {
      print('Error loading pending join requests in service: $e');
    }
  }

  /// Add a race to pending requests (when new request is sent)
  void addPendingRequest(String raceId) {
    pendingJoinRequests[raceId] = true;
    print('✅ PendingRequestsService: Added pending request for race $raceId');
  }

  /// Remove a race from pending requests (when accepted/declined)
  void removePendingRequest(String raceId) {
    pendingJoinRequests.remove(raceId);
    print('✅ PendingRequestsService: Removed pending request for race $raceId');
  }

  /// Check if a race has a pending join request
  bool hasPendingRequest(String? raceId) {
    if (raceId == null) return false;
    return pendingJoinRequests[raceId] == true;
  }

  /// Refresh pending requests from Firebase
  Future<void> refreshPendingRequests() async {
    await _loadPendingJoinRequests();
  }
}