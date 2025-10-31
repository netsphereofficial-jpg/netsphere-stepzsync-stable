import 'dart:async';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../database/step_database.dart';
import '../models/daily_step_data.dart';
import '../models/step_summary.dart';
import '../utils/step_constants.dart';
import '../utils/step_date_utils.dart';

/// Repository for managing step data across local SQLite and Firebase
/// Implements offline-first strategy with automatic sync
class StepDataRepository {
  final StepDatabase _localDb = StepDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for frequently accessed data
  final Map<String, DailyStepData> _cache = {};
  StepSummary? _cachedSummary;
  DateTime? _lastSummaryFetch;

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  /// Save daily step data (local + Firebase)
  Future<void> saveDailyData(DailyStepData data, {bool syncToFirebase = true}) async {
    try {
      // Save to local database first (offline-first)
      await _localDb.upsertDailyData(data);
      _cache[data.date] = data;

      dev.log('💾 Saved daily data locally: ${data.date} - ${data.steps} steps');

      // Sync to Firebase if requested and user is authenticated
      if (syncToFirebase && _userId != null) {
        await _syncDailyDataToFirebase(data);
      }
    } catch (e) {
      dev.log('❌ Error saving daily data: $e');
      rethrow;
    }
  }

  /// Get daily data for a specific date
  Future<DailyStepData?> getDailyData(String date) async {
    try {
      // Check cache first
      if (_cache.containsKey(date)) {
        return _cache[date];
      }

      // Try local database
      final localData = await _localDb.getDailyData(date);
      if (localData != null) {
        _cache[date] = localData;
        return localData;
      }

      // Try Firebase as fallback
      if (_userId != null) {
        final firebaseData = await _fetchDailyDataFromFirebase(date);
        if (firebaseData != null) {
          // Save to local database for future
          await _localDb.upsertDailyData(firebaseData);
          _cache[date] = firebaseData;
          return firebaseData;
        }
      }

      return null;
    } catch (e) {
      dev.log('❌ Error getting daily data for $date: $e');
      return null;
    }
  }

  /// Get daily data for a date range
  Future<List<DailyStepData>> getDailyDataRange(String startDate, String endDate) async {
    try {
      // Try local database first
      final localData = await _localDb.getDailyDataRange(startDate, endDate);

      if (localData.isNotEmpty) {
        // Cache the data
        for (final data in localData) {
          _cache[data.date] = data;
        }
        return localData;
      }

      // Fallback to Firebase
      if (_userId != null) {
        final firebaseData = await _fetchDailyDataRangeFromFirebase(startDate, endDate);
        if (firebaseData.isNotEmpty) {
          // Save to local database
          await _localDb.batchUpsert(firebaseData);
          // Cache the data
          for (final data in firebaseData) {
            _cache[data.date] = data;
          }
          return firebaseData;
        }
      }

      return [];
    } catch (e) {
      dev.log('❌ Error getting daily data range: $e');
      return [];
    }
  }

  /// Get step summary
  Future<StepSummary> getStepSummary({bool forceRefresh = false}) async {
    try {
      // Return cached summary if available and recent
      if (!forceRefresh &&
          _cachedSummary != null &&
          _lastSummaryFetch != null &&
          DateTime.now().difference(_lastSummaryFetch!).inMinutes < 5) {
        return _cachedSummary!;
      }

      // Fetch from Firebase
      if (_userId != null) {
        final summary = await _fetchSummaryFromFirebase();
        _cachedSummary = summary;
        _lastSummaryFetch = DateTime.now();
        return summary;
      }

      // Fallback to calculating from local data
      return await _calculateSummaryFromLocal();
    } catch (e) {
      dev.log('❌ Error getting step summary: $e');
      return StepSummary.empty();
    }
  }

  /// Update step summary
  Future<void> updateStepSummary(StepSummary summary) async {
    try {
      if (_userId == null) return;

      await _firestore
          .collection(StepConstants.usersCollection)
          .doc(_userId)
          .collection('step_data')
          .doc(StepConstants.stepSummaryDocument)
          .set(summary.toMap(), SetOptions(merge: true));

      _cachedSummary = summary;
      _lastSummaryFetch = DateTime.now();

      dev.log('✅ Updated step summary in Firebase');
    } catch (e) {
      dev.log('❌ Error updating step summary: $e');
      rethrow;
    }
  }

  /// Sync unsynced data to Firebase
  Future<int> syncUnsyncedData() async {
    try {
      if (_userId == null) return 0;

      final unsyncedData = await _localDb.getUnsyncedData();
      if (unsyncedData.isEmpty) {
        dev.log('✅ No unsynced data found');
        return 0;
      }

      dev.log('🔄 Syncing ${unsyncedData.length} unsynced records...');

      int syncedCount = 0;
      for (final data in unsyncedData) {
        try {
          await _syncDailyDataToFirebase(data);
          await _localDb.markAsSynced(data.date);
          syncedCount++;
        } catch (e) {
          dev.log('❌ Failed to sync ${data.date}: $e');
        }
      }

      dev.log('✅ Synced $syncedCount/${unsyncedData.length} records');
      return syncedCount;
    } catch (e) {
      dev.log('❌ Error syncing unsynced data: $e');
      return 0;
    }
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
    _cachedSummary = null;
    _lastSummaryFetch = null;
    dev.log('🧹 Cleared step data cache');
  }


  // Private helper methods

  /// Sync daily data to Firebase
  Future<void> _syncDailyDataToFirebase(DailyStepData data) async {
    if (_userId == null) return;

    try {
      // Use our planned structure: users/{userId}/daily_steps/{YYYY-MM-DD}
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('daily_steps')
          .doc(data.date)
          .set(data.toJson(), SetOptions(merge: true));

      dev.log('☁️ Synced ${data.date} to Firebase: ${data.steps} steps');
    } catch (e) {
      dev.log('❌ Error syncing to Firebase: $e');
      rethrow;
    }
  }

  /// Fetch daily data directly from Firebase (bypasses local cache)
  /// Used to check if today's data exists in Firebase for overall stats calculation
  Future<DailyStepData?> getDailyDataFromFirebaseDirectly(String date) async {
    if (_userId == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('daily_steps')
          .doc(date)
          .get();

      if (!doc.exists) return null;

      return DailyStepData.fromFirestore(doc);
    } catch (e) {
      dev.log('❌ Error fetching from Firebase: $e');
      return null;
    }
  }

  /// Fetch daily data from Firebase (private wrapper for internal use)
  Future<DailyStepData?> _fetchDailyDataFromFirebase(String date) async {
    return getDailyDataFromFirebaseDirectly(date);
  }

  /// Fetch daily data range from Firebase
  Future<List<DailyStepData>> _fetchDailyDataRangeFromFirebase(
    String startDate,
    String endDate,
  ) async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('daily_steps')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .orderBy('date', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => DailyStepData.fromFirestore(doc))
          .toList();
    } catch (e) {
      dev.log('❌ Error fetching range from Firebase: $e');
      return [];
    }
  }

  /// Fetch summary from Firebase
  Future<StepSummary> _fetchSummaryFromFirebase() async {
    if (_userId == null) return StepSummary.empty();

    try {
      final doc = await _firestore
          .collection(StepConstants.usersCollection)
          .doc(_userId)
          .collection('step_data')
          .doc(StepConstants.stepSummaryDocument)
          .get();

      if (!doc.exists) return StepSummary.empty();

      return StepSummary.fromFirestore(doc);
    } catch (e) {
      dev.log('❌ Error fetching summary from Firebase: $e');
      return StepSummary.empty();
    }
  }

  /// Calculate summary from local database
  Future<StepSummary> _calculateSummaryFromLocal() async {
    try {
      final allData = await _localDb.getAllDailyData();

      if (allData.isEmpty) return StepSummary.empty();

      int totalSteps = 0;
      double totalDistance = 0.0;
      int totalCalories = 0;
      int totalActiveTime = 0;
      DateTime? firstDate;
      DateTime? lastDate;

      for (final data in allData) {
        totalSteps += data.steps;
        totalDistance += data.distance;
        totalCalories += data.calories;
        totalActiveTime += data.activeMinutes;

        final date = StepDateUtils.parseDate(data.date);
        if (firstDate == null || date.isBefore(firstDate)) {
          firstDate = date;
        }
        if (lastDate == null || date.isAfter(lastDate)) {
          lastDate = date;
        }
      }

      return StepSummary(
        totalDays: allData.length,
        totalSteps: totalSteps,
        totalDistanceKm: totalDistance,
        totalCalories: totalCalories,
        totalActiveTimeMinutes: totalActiveTime,
        firstTrackingDate: firstDate,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      dev.log('❌ Error calculating summary from local: $e');
      return StepSummary.empty();
    }
  }

  /// Stream daily data changes from Firebase
  Stream<DailyStepData?> streamDailyData(String date) {
    if (_userId == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('daily_steps')
        .doc(date)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return DailyStepData.fromFirestore(doc);
    });
  }

  /// Stream step summary changes from Firebase
  Stream<StepSummary> streamStepSummary() {
    if (_userId == null) return Stream.value(StepSummary.empty());

    return _firestore
        .collection(StepConstants.usersCollection)
        .doc(_userId)
        .collection('step_data')
        .doc(StepConstants.stepSummaryDocument)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return StepSummary.empty();
      return StepSummary.fromFirestore(doc);
    });
  }

  /// Check if user has any step data
  Future<bool> hasAnyData() async {
    final count = await _localDb.getRecordCount();
    return count > 0;
  }

  /// Get today's data (convenience method)
  Future<DailyStepData?> getTodayData() async {
    return await getDailyData(StepDateUtils.getTodayDate());
  }

  /// Get yesterday's data (convenience method)
  Future<DailyStepData?> getYesterdayData() async {
    return await getDailyData(StepDateUtils.getYesterdayDate());
  }

  /// Get overall statistics by aggregating all daily_steps from Firebase
  /// Returns aggregated totals: steps, distance, days (based on profile creation), calories, active time
  Future<Map<String, dynamic>> getOverallStatisticsFromFirebase({DateTime? profileCreatedAt}) async {
    try {
      if (_userId == null) {
        dev.log('⚠️ No user logged in, returning empty stats');
        return {
          'totalSteps': 0,
          'totalDistance': 0.0,
          'totalDays': 0,
          'totalCalories': 0,
          'totalActiveTime': 0,
        };
      }

      dev.log('📊 Querying Firebase for overall statistics...');

      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('daily_steps')
          .get();

      if (snapshot.docs.isEmpty) {
        dev.log('📊 No data found in Firebase');
        return {
          'totalSteps': 0,
          'totalDistance': 0.0,
          'totalDays': 0,
          'totalCalories': 0,
          'totalActiveTime': 0,
        };
      }

      int totalSteps = 0;
      double totalDistance = 0.0;
      int totalCalories = 0;
      int totalActiveTime = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalSteps += (data['steps'] as int? ?? 0);
        totalDistance += (data['distance'] as num? ?? 0).toDouble();
        totalCalories += (data['calories'] as int? ?? 0);
        totalActiveTime += (data['activeMinutes'] as int? ?? 0);
      }

      // ✅ NEW: Calculate days based on profile creation date, not document count
      int totalDays;
      if (profileCreatedAt != null) {
        final now = DateTime.now();
        totalDays = now.difference(profileCreatedAt).inDays + 1; // +1 to include first day
        dev.log('✅ Calculated days from profile creation: $totalDays days (created: ${profileCreatedAt.toString().substring(0, 10)})');
      } else {
        // Fallback: Use document count if profile creation date not provided
        totalDays = snapshot.docs.length;
        dev.log('⚠️ Using document count as days (no profile creation date provided): $totalDays days');
      }

      dev.log('✅ Firebase aggregation complete: $totalDays days, $totalSteps steps, ${totalDistance.toStringAsFixed(2)} km');

      return {
        'totalSteps': totalSteps,
        'totalDistance': totalDistance,
        'totalDays': totalDays,
        'totalCalories': totalCalories,
        'totalActiveTime': totalActiveTime,
      };
    } catch (e) {
      dev.log('❌ Error aggregating Firebase statistics: $e');
      return {
        'totalSteps': 0,
        'totalDistance': 0.0,
        'totalDays': 0,
        'totalCalories': 0,
        'totalActiveTime': 0,
      };
    }
  }

  /// Get statistics for a specific date range from Firebase
  /// Returns aggregated totals for the specified period
  Future<Map<String, dynamic>> getStatisticsForPeriod(
    String startDate,
    String endDate,
  ) async {
    try {
      if (_userId == null) {
        dev.log('⚠️ No user logged in, returning empty stats');
        return {
          'totalSteps': 0,
          'totalDistance': 0.0,
          'totalDays': 0,
          'totalCalories': 0,
          'totalActiveTime': 0,
        };
      }

      dev.log('📊 Querying Firebase for period: $startDate to $endDate');

      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('daily_steps')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .get();

      if (snapshot.docs.isEmpty) {
        dev.log('📊 No data found for period $startDate to $endDate');
        return {
          'totalSteps': 0,
          'totalDistance': 0.0,
          'totalDays': 0,
          'totalCalories': 0,
          'totalActiveTime': 0,
        };
      }

      int totalSteps = 0;
      double totalDistance = 0.0;
      int totalCalories = 0;
      int totalActiveTime = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalSteps += (data['steps'] as int? ?? 0);
        totalDistance += (data['distance'] as num? ?? 0).toDouble();
        totalCalories += (data['calories'] as int? ?? 0);
        totalActiveTime += (data['activeMinutes'] as int? ?? 0);
      }

      dev.log('✅ Period aggregation complete: ${snapshot.docs.length} days, $totalSteps steps');

      return {
        'totalSteps': totalSteps,
        'totalDistance': totalDistance,
        'totalDays': snapshot.docs.length,
        'totalCalories': totalCalories,
        'totalActiveTime': totalActiveTime,
      };
    } catch (e) {
      dev.log('❌ Error aggregating period statistics: $e');
      return {
        'totalSteps': 0,
        'totalDistance': 0.0,
        'totalDays': 0,
        'totalCalories': 0,
        'totalActiveTime': 0,
      };
    }
  }

  /// Get statistics for a filter period (convenience method)
  /// Uses StepDateUtils to calculate date range from filter name
  Future<Map<String, dynamic>> getStatisticsForFilter(String filter) async {
    try {
      final dateRange = StepDateUtils.getDateRangeForFilter(filter);
      final startDate = StepDateUtils.formatDate(dateRange.start);
      final endDate = StepDateUtils.formatDate(dateRange.end);

      dev.log('📊 Getting statistics for filter: $filter ($startDate to $endDate)');

      return await getStatisticsForPeriod(startDate, endDate);
    } catch (e) {
      dev.log('❌ Error getting filter statistics: $e');
      return {
        'totalSteps': 0,
        'totalDistance': 0.0,
        'totalDays': 0,
        'totalCalories': 0,
        'totalActiveTime': 0,
      };
    }
  }
}
