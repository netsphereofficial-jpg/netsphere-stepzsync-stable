// import 'dart:async';
// import 'dart:developer';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../models/leaderboard_data.dart';
//
// typedef FirebaseRaceCallback = void Function(dynamic data);
//
// /// Firebase-based replacement for SignalR race functionality
// /// Provides exact same API as SignalR service but uses Firebase real-time streams
// class RaceSignalRService {
//   final String userId; // Changed to String to match Firebase Auth UIDs
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   // Callback functions - exact same structure as SignalR reference
//   final FirebaseRaceCallback? onAllLeaderboardCompletedData;
//   final FirebaseRaceCallback? onLeaderboardUpdate;
//   final FirebaseRaceCallback? onParticipantUpdated;
//   final FirebaseRaceCallback? onRaceClosed;
//   final FirebaseRaceCallback? onYourRank;
//   final FirebaseRaceCallback? onCountdownStarted;
//   final FirebaseRaceCallback? onCountdownUpdate;
//   final FirebaseRaceCallback? onCountdownEnded;
//   final FirebaseRaceCallback? allParticipantData;
//   final FirebaseRaceCallback? onRaceStatusUpdate;
//   final FirebaseRaceCallback? onParticipantListUpdated;
//
//   // Stream subscriptions for cleanup
//   StreamSubscription<QuerySnapshot>? _participantsSubscription;
//   StreamSubscription<DocumentSnapshot>? _raceStatusSubscription;
//   StreamSubscription<DocumentSnapshot>? _countdownSubscription;
//
//   // Connection state
//   bool _isConnected = false;
//   String? _currentRaceId;
//   Timer? _connectionHealthTimer;
//
//   RaceSignalRService({
//     required this.userId,
//     this.onAllLeaderboardCompletedData,
//     this.onLeaderboardUpdate,
//     this.onParticipantUpdated,
//     this.onRaceClosed,
//     this.onYourRank,
//     this.onCountdownStarted,
//     this.onCountdownUpdate,
//     this.onCountdownEnded,
//     this.allParticipantData,
//     this.onRaceStatusUpdate,
//     this.onParticipantListUpdated,
//   });
//
//   /// Connect to Firebase (equivalent to SignalR connect)
//   Future<void> connect() async {
//     try {
//       log('🔗 Connecting Firebase race service for user: $userId');
//       _isConnected = true;
//       _startConnectionHealthMonitoring();
//       log('✅ Firebase race service connected successfully');
//     } catch (e) {
//       log('❌ Failed to connect Firebase race service: $e');
//       _isConnected = false;
//       rethrow;
//     }
//   }
//
//   /// Disconnect from Firebase (cleanup all streams)
//   Future<void> disconnect() async {
//     try {
//       log('🔌 Disconnecting Firebase race service');
//       _isConnected = false;
//       _currentRaceId = null;
//
//       // Cancel all subscriptions
//       await _participantsSubscription?.cancel();
//       await _raceStatusSubscription?.cancel();
//       await _countdownSubscription?.cancel();
//
//       _participantsSubscription = null;
//       _raceStatusSubscription = null;
//       _countdownSubscription = null;
//
//       _connectionHealthTimer?.cancel();
//
//       log('✅ Firebase race service disconnected');
//     } catch (e) {
//       log('❌ Error disconnecting Firebase race service: $e');
//     }
//   }
//
//   /// Join race group (equivalent to SignalR JoinRaceGroup)
//   Future<void> joinRaceGroup(String raceId) async {
//     if (!_isConnected) {
//       throw Exception('Firebase race service not connected');
//     }
//
//     try {
//       log('🏁 Joining race group: $raceId');
//       _currentRaceId = raceId;
//
//       // Start listening to race data streams using correct collections
//       await _startRaceDataStreams(raceId);
//
//       log('✅ Successfully joined race group: $raceId');
//     } catch (e) {
//       log('❌ Failed to join race group $raceId: $e');
//       rethrow;
//     }
//   }
//
//   /// Broadcast leaderboard request (triggers initial data load)
//   Future<void> broadcastLeaderboard(String raceId) async {
//     if (!_isConnected) {
//       throw Exception('Firebase race service not connected');
//     }
//
//     try {
//       log('📊 Broadcasting leaderboard request for race: $raceId');
//
//       // Load initial leaderboard data from correct collection
//       await _loadInitialLeaderboardData(raceId);
//
//       log('✅ Leaderboard broadcast completed for race: $raceId');
//     } catch (e) {
//       log('❌ Failed to broadcast leaderboard for race $raceId: $e');
//     }
//   }
//
//   /// Ensure connection is active (equivalent to SignalR ensureConnected)
//   Future<void> ensureConnected() async {
//     if (!_isConnected) {
//       await connect();
//     }
//   }
//
//   /// Start monitoring all race data streams
//   Future<void> _startRaceDataStreams(String raceId) async {
//     // Cancel existing streams
//     await _participantsSubscription?.cancel();
//     await _raceStatusSubscription?.cancel();
//     await _countdownSubscription?.cancel();
//
//     // Start main race document stream - this contains the participants array and race status
//     _raceStatusSubscription = _firestore
//         .collection('races')
//         .doc(raceId)
//         .snapshots()
//         .listen(
//       (DocumentSnapshot snapshot) {
//         _handleMainRaceStreamUpdate(snapshot, raceId);
//       },
//       onError: (error) {
//         log('❌ Error in main race stream: $error');
//         _handleStreamError('mainRace');
//       },
//     );
//
//     // Start participants subcollection stream for detailed updates
//     _participantsSubscription = _firestore
//         .collection('races')
//         .doc(raceId)
//         .collection('participants')
//         .snapshots()
//         .listen(
//       (QuerySnapshot snapshot) {
//         _handleParticipantsSubcollectionUpdate(snapshot, raceId);
//       },
//       onError: (error) {
//         log('❌ Error in participants subcollection stream: $error');
//         _handleStreamError('participantsSubcollection');
//       },
//     );
//
//     log('🔄 Started all race data streams for race: $raceId');
//   }
//
//   /// Handle main race document updates (participants array, status, countdown)
//   void _handleMainRaceStreamUpdate(DocumentSnapshot snapshot, String raceId) {
//     try {
//       if (!snapshot.exists) return;
//
//       final data = snapshot.data() as Map<String, dynamic>;
//       final statusId = data['statusId'] ?? 0;
//       final countdownSeconds = data['countdownSeconds'];
//       final raceDeadline = data['raceDeadline'];
//       final actualEndTime = data['actualEndTime'];
//       final participantsArray = data['participants'] as List? ?? [];
//       final joinedParticipants = data['joinedParticipants'] ?? 0;
//
//       // Process participants array from main race document
//       final participants = <Participant>[];
//       final participantData = <Map<String, dynamic>>[];
//
//       // Sort participants by distance (descending) for ranking
//       final sortedParticipants = List<Map<String, dynamic>>.from(
//         participantsArray.map((p) => Map<String, dynamic>.from(p))
//       );
//       sortedParticipants.sort((a, b) => ((b['distance'] ?? 0.0) as double).compareTo((a['distance'] ?? 0.0) as double));
//
//       for (int i = 0; i < sortedParticipants.length; i++) {
//         final participantMap = sortedParticipants[i];
//         final rank = i + 1;
//         participantMap['rank'] = rank;
//
//         final participant = Participant.fromMap(participantMap);
//         participants.add(participant);
//         participantData.add({'participantData': participant.toMap()});
//
//         // Check if this is current user and trigger rank update
//         if (participant.userId.toString() == userId) {
//           onYourRank?.call({'rank': rank, 'userId': participant.userId});
//         }
//
//         // Trigger individual participant update
//         onParticipantUpdated?.call([{'participantData': participant.toMap()}]);
//       }
//
//       // Trigger leaderboard update with race status (exact SignalR format)
//       final leaderboardUpdate = {
//         'leaderboard': participants.map((p) => p.toMap()).toList(),
//         'raceStatus': statusId,
//         'deadline': raceDeadline?.toString(),
//       };
//       onLeaderboardUpdate?.call(leaderboardUpdate);
//
//       // Trigger all participant data update
//       allParticipantData?.call(participantData);
//
//       // Trigger participant list updated
//       onParticipantListUpdated?.call([{
//         'race': {
//           'joinedParticipants': joinedParticipants,
//           'participants': participants.map((p) => p.toMap()).toList(),
//         }
//       }]);
//
//       // Handle race status updates
//       onRaceStatusUpdate?.call({
//         'raceStatus': statusId,
//         'raceId': raceId,
//         'countdownSeconds': countdownSeconds,
//         'deadline': raceDeadline?.toString(),
//         'actualEndTime': actualEndTime?.toString(),
//       });
//
//       // Handle countdown updates
//       if (statusId == 2 && countdownSeconds != null) {
//         if (countdownSeconds > 0) {
//           onCountdownUpdate?.call({
//             'seconds': countdownSeconds,
//             'raceId': raceId,
//           });
//         } else {
//           onCountdownEnded?.call({'raceId': raceId});
//         }
//       }
//
//       // Handle race state changes
//       switch (statusId) {
//         case 2:
//           onCountdownStarted?.call({
//             'raceId': raceId,
//             'seconds': countdownSeconds ?? 10,
//           });
//           break;
//         case 4:
//           onRaceClosed?.call({
//             'raceId': raceId,
//             'reason': 'completed',
//           });
//           break;
//       }
//
//       log('📊 Processed main race update: ${participants.length} participants, Status=$statusId');
//     } catch (e) {
//       log('❌ Error processing main race stream update: $e');
//     }
//   }
//
//   /// Handle participants subcollection updates (detailed participant data)
//   void _handleParticipantsSubcollectionUpdate(QuerySnapshot snapshot, String raceId) {
//     try {
//       // Process individual participant documents for detailed updates
//       for (final docChange in snapshot.docChanges) {
//         if (docChange.type == DocumentChangeType.modified) {
//           final data = docChange.doc.data() as Map<String, dynamic>;
//           final participant = Participant.fromMap(data);
//
//           // Trigger individual participant update
//           onParticipantUpdated?.call([{'participantData': participant.toMap()}]);
//
//           log('📈 Individual participant updated: ${participant.userName} (${participant.userId})');
//         }
//       }
//     } catch (e) {
//       log('❌ Error processing participants subcollection update: $e');
//     }
//   }
//
//   /// Load initial leaderboard data from correct race document structure
//   Future<void> _loadInitialLeaderboardData(String raceId) async {
//     try {
//       // Load main race document which contains participants array
//       final raceSnapshot = await _firestore
//           .collection('races')
//           .doc(raceId)
//           .get();
//
//       if (!raceSnapshot.exists) return;
//
//       final raceData = raceSnapshot.data()!;
//       final participantsArray = raceData['participants'] as List? ?? [];
//       final participants = <Participant>[];
//
//       // Sort participants by distance (descending) for ranking
//       final sortedParticipants = List<Map<String, dynamic>>.from(
//         participantsArray.map((p) => Map<String, dynamic>.from(p))
//       );
//       sortedParticipants.sort((a, b) => ((b['distance'] ?? 0.0) as double).compareTo((a['distance'] ?? 0.0) as double));
//
//       for (int i = 0; i < sortedParticipants.length; i++) {
//         final participantMap = sortedParticipants[i];
//         final rank = i + 1;
//         participantMap['rank'] = rank;
//
//         final participant = Participant.fromMap(participantMap);
//         participants.add(participant);
//       }
//
//       // Trigger all leaderboard completed data (exact SignalR format)
//       final raceDataResponse = Race(
//         leaderboard: participants,
//         raceStatus: raceData['statusId'] ?? 0,
//         deadline: raceData['raceDeadline']?.toString(),
//         lastUpdated: DateTime.now(),
//       );
//
//       onAllLeaderboardCompletedData?.call(raceDataResponse.toJson());
//
//       log('📊 Loaded initial leaderboard data: ${participants.length} participants');
//     } catch (e) {
//       log('❌ Error loading initial leaderboard data: $e');
//     }
//   }
//
//   /// Handle stream errors with auto-retry
//   void _handleStreamError(String streamType) {
//     if (_currentRaceId != null) {
//       log('🔄 Retrying $streamType stream in 3 seconds...');
//       Timer(Duration(seconds: 3), () {
//         if (_isConnected && _currentRaceId != null) {
//           _startRaceDataStreams(_currentRaceId!);
//         }
//       });
//     }
//   }
//
//   /// Start connection health monitoring
//   void _startConnectionHealthMonitoring() {
//     _connectionHealthTimer?.cancel();
//     _connectionHealthTimer = Timer.periodic(Duration(seconds: 30), (timer) {
//       if (_isConnected) {
//         log('💓 Firebase race service connection healthy');
//       } else {
//         timer.cancel();
//       }
//     });
//   }
//
//   /// Get connection status
//   bool get isConnected => _isConnected;
//
//   /// Get current race ID
//   String? get currentRaceId => _currentRaceId;
// }
