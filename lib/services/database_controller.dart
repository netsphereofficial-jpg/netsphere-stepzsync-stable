import 'dart:developer';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:get/get.dart';
import '../models/credentials_model.dart';
import '../models/step_metrics.dart';
import '../models/user_overall_stats.dart';
import '../models/step_history.dart';
import 'step_tracking_service.dart';

class DatabaseController {
  static const String _dbName = 'stepzsync_local.db';
  static const int _dbVersion = 3; // Version 3: Added unique constraint to step_history

  // Table names
  static const String _dailyStepMetricsTable = 'daily_step_metrics';
  static const String _userOverallStatsTable = 'user_overall_stats';
  static const String _stepHistoryTable = 'step_history';

  Database? _database;
  bool _isInitialized = false;

  /// Lazy getter for database instance
  Future<Database> get database async {
    if (!_isInitialized) {
      await _initializeDatabase();
    }
    return _database!;
  }

  /// Initialize database with error handling
  Future<void> _initializeDatabase() async {
    try {
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, _dbName);

      log("🗄️ Initializing SQLite database at: $path");

      _database = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      );

      _isInitialized = true;
      log("✅ SQLite database initialized successfully");
    } catch (e) {
      log("❌ Database initialization failed: $e");
      rethrow;
    }
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    log("🏗️ Creating database tables (version $version)");
    await _createDailyStepMetricsTable(db);
    await _createUserOverallStatsTable(db);
    await _createStepHistoryTable(db);
  }

  /// Create daily step metrics table
  Future<void> _createDailyStepMetricsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_dailyStepMetricsTable (
        userId INTEGER NOT NULL,
        date TEXT NOT NULL,
        steps INTEGER NOT NULL DEFAULT 0,
        calories REAL NOT NULL DEFAULT 0.0,
        distance REAL NOT NULL DEFAULT 0.0,
        avgSpeed REAL NOT NULL DEFAULT 0.0,
        activeTime INTEGER NOT NULL DEFAULT 0,
        duration TEXT NOT NULL DEFAULT '00:00',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        PRIMARY KEY (userId, date)
      )
    ''');
    log("✅ Created daily step metrics table");
  }

  /// Create user overall stats table
  Future<void> _createUserOverallStatsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_userOverallStatsTable (
        userId INTEGER PRIMARY KEY,
        firstInstallDate TEXT NOT NULL,
        totalDays INTEGER NOT NULL DEFAULT 0,
        totalSteps INTEGER NOT NULL DEFAULT 0,
        totalDistance REAL NOT NULL DEFAULT 0.0,
        totalCalories REAL NOT NULL DEFAULT 0.0,
        avgSpeed REAL NOT NULL DEFAULT 0.0,
        lastUpdated TEXT NOT NULL
      )
    ''');
    log("✅ Created user overall stats table");
  }

  /// Create step history table
  Future<void> _createStepHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_stepHistoryTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        date TEXT NOT NULL,
        steps INTEGER NOT NULL DEFAULT 0,
        distance REAL NOT NULL DEFAULT 0.0,
        calories INTEGER NOT NULL DEFAULT 0,
        activeTime INTEGER NOT NULL DEFAULT 0,
        avgSpeed REAL NOT NULL DEFAULT 0.0,
        createdAt TEXT NOT NULL,
        UNIQUE(userId, date)
      )
    ''');

    // Create index for better query performance
    await db.execute('''
      CREATE INDEX idx_step_history_user_date ON $_stepHistoryTable (userId, date)
    ''');

    log("✅ Created step history table with unique constraint and index");
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    log("🔄 Upgrading database from version $oldVersion to $newVersion");

    if (oldVersion < 3) {
      // Version 3: Fix duplicate step_history entries by recreating table with unique constraint
      await _migrateToVersion3(db);
    }
  }

  /// Migrate to version 3: Fix step_history duplicates
  Future<void> _migrateToVersion3(Database db) async {
    log("🔄 Migrating to version 3: Fixing step_history duplicates");

    try {
      // Step 1: Create new table with unique constraint
      await db.execute('''
        CREATE TABLE step_history_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId INTEGER NOT NULL,
          date TEXT NOT NULL,
          steps INTEGER NOT NULL DEFAULT 0,
          distance REAL NOT NULL DEFAULT 0.0,
          calories INTEGER NOT NULL DEFAULT 0,
          activeTime INTEGER NOT NULL DEFAULT 0,
          avgSpeed REAL NOT NULL DEFAULT 0.0,
          createdAt TEXT NOT NULL,
          UNIQUE(userId, date)
        )
      ''');

      // Step 2: Migrate unique data (keep latest record for each date)
      await db.execute('''
        INSERT INTO step_history_new (userId, date, steps, distance, calories, activeTime, avgSpeed, createdAt)
        SELECT userId, date, MAX(steps) as steps, MAX(distance) as distance,
               MAX(calories) as calories, MAX(activeTime) as activeTime,
               MAX(avgSpeed) as avgSpeed, MAX(createdAt) as createdAt
        FROM step_history
        GROUP BY userId, date
      ''');

      // Step 3: Drop old table and rename new one
      await db.execute('DROP TABLE step_history');
      await db.execute('ALTER TABLE step_history_new RENAME TO step_history');

      // Step 4: Recreate index
      await db.execute('''
        CREATE INDEX idx_step_history_user_date ON step_history (userId, date)
      ''');

      log("✅ Migration to version 3 completed - removed duplicate step_history entries");
    } catch (e) {
      log("❌ Error migrating to version 3: $e");
      rethrow;
    }
  }

  /// Called when database is opened
  Future<void> _onOpen(Database db) async {
    log("📂 Database opened successfully");
    // Enable foreign keys if needed
    // await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Check if database is initialized
  bool get isInitialized => _isInitialized;

  /// Ensure database is initialized before operations
  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await _initializeDatabase();
    }
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
      _isInitialized = false;
      log("🔒 Database connection closed");
    }
  }

  /// Execute raw SQL query
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  /// Execute raw SQL (non-query operations like INSERT, UPDATE, DELETE)
  Future<int> rawInsert(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawInsert(sql, arguments);
  }

  /// Execute raw SQL update
  Future<int> rawUpdate(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawUpdate(sql, arguments);
  }

  /// Execute raw SQL delete
  Future<int> rawDelete(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawDelete(sql, arguments);
  }

  /// Execute a batch of SQL operations
  Future<List<dynamic>> batch(Function(Batch batch) operations) async {
    final db = await database;
    final batch = db.batch();
    operations(batch);
    return await batch.commit();
  }

  /// Get database path for debugging
  Future<String> getDatabasePath() async {
    final databasePath = await getDatabasesPath();
    return join(databasePath, _dbName);
  }

  /// Delete database file (for development/testing)
  Future<void> deleteDatabase() async {
    try {
      final path = await getDatabasePath();
      await databaseFactory.deleteDatabase(path);
      _database = null;
      _isInitialized = false;
      log("🗑️ Database deleted successfully");
    } catch (e) {
      log("❌ Failed to delete database: $e");
      rethrow;
    }
  }

  /// Generate test data for filter testing
  Future<void> generateTestData(String userIdString) async {
    try {
      final userId = userIdString.hashCode.abs(); // Convert Firebase UID to integer
      final now = DateTime.now();

      log("🧪 Generating test data for userId: $userId");

      // Generate last 90 days of data
      for (int i = 89; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));

        // Vary data to make it realistic
        final dayOfWeek = date.weekday;
        final isWeekend = dayOfWeek == 6 || dayOfWeek == 7;

        // Base steps with variation
        int steps = 3000 + (i * 50) + (dayOfWeek * 500);
        if (isWeekend) steps = (steps * 0.7).round(); // Less steps on weekends
        if (i < 7) steps += 1000; // More recent days have more steps

        // Calculate other metrics
        final distance = (steps * 0.78) / 1000; // km
        final calories = (steps * 0.04).round();
        final activeTime = (steps / 100).round(); // minutes
        final avgSpeed = distance > 0 ? distance / (activeTime / 60.0) : 0.0;
        final duration = "${activeTime ~/ 60}:${(activeTime % 60).toString().padLeft(2, '0')}";

        // Create step metrics
        final stepMetrics = StepMetrics(
          userId: userId,
          date: date,
          steps: steps,
          calories: calories.toDouble(),
          distance: distance,
          avgSpeed: avgSpeed,
          activeTime: activeTime,
          duration: duration,
        );

        // Insert data
        await insertOrUpdateDailyStepMetrics(stepMetrics);

        // Add to step history
        final stepHistory = StepHistory.fromStepMetrics(stepMetrics);
        await insertStepHistory(stepHistory);
      }

      // Update overall stats
      final totalSteps = 90 * 4000; // Rough total
      final totalDistance = (totalSteps * 0.78) / 1000;
      final totalCalories = totalSteps * 0.04;

      final overallStats = UserOverallStats(
        userId: userId,
        firstInstallDate: now.subtract(const Duration(days: 90)),
        totalDays: 90,
        totalSteps: totalSteps,
        totalDistance: totalDistance,
        totalCalories: totalCalories,
        avgSpeed: 4.5, // km/h
        lastUpdated: now,
      );

      await insertOrUpdateUserOverallStats(overallStats);

      log("✅ Generated test data: 90 days, total steps: $totalSteps");
    } catch (e) {
      log("❌ Error generating test data: $e");
      rethrow;
    }
  }

  // === STEP METRICS CRUD OPERATIONS ===

  /// Insert or update daily step metrics
  Future<void> insertOrUpdateDailyStepMetrics(StepMetrics stepMetrics) async {
    try {
      final db = await database;
      final data = stepMetrics.toMap();

      await db.insert(
        _dailyStepMetricsTable,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      log("✅ Step metrics saved: ${stepMetrics.steps} steps for ${stepMetrics.formattedDate}");
    } catch (e) {
      log("❌ Error inserting/updating step metrics: $e");
      rethrow;
    }
  }

  /// Get step metrics for a specific date
  Future<StepMetrics?> getDailyStepMetrics(int userId, DateTime date) async {
    try {
      final db = await database;
      final dateStr = date.toIso8601String().split('T')[0]; // yyyy-MM-dd format

      final result = await db.query(
        _dailyStepMetricsTable,
        where: 'userId = ? AND date = ?',
        whereArgs: [userId, dateStr],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return StepMetrics.fromMap(result.first);
      }
      return null;
    } catch (e) {
      log("❌ Error getting daily step metrics: $e");
      return null;
    }
  }

  /// Get today's step metrics
  Future<StepMetrics?> getTodayStepMetrics(int userId) async {
    final today = DateTime.now();
    return await getDailyStepMetrics(userId, today);
  }

  // === USER OVERALL STATS CRUD OPERATIONS ===

  /// Insert or update user overall stats
  Future<void> insertOrUpdateUserOverallStats(UserOverallStats stats) async {
    try {
      final db = await database;
      final data = stats.toMap();

      await db.insert(
        _userOverallStatsTable,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      log("✅ Overall stats updated for user ${stats.userId}");
    } catch (e) {
      log("❌ Error inserting/updating overall stats: $e");
      rethrow;
    }
  }

  /// Get user overall stats
  Future<UserOverallStats?> getUserOverallStats(int userId) async {
    try {
      final db = await database;

      final result = await db.query(
        _userOverallStatsTable,
        where: 'userId = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return UserOverallStats.fromMap(result.first);
      }
      return null;
    } catch (e) {
      log("❌ Error getting overall stats: $e");
      return null;
    }
  }

  /// Initialize user overall stats if doesn't exist
  Future<UserOverallStats> initializeUserOverallStats(int userId) async {
    try {
      final existing = await getUserOverallStats(userId);
      if (existing != null) return existing;

      final initialStats = UserOverallStats.initial(userId: userId);
      await insertOrUpdateUserOverallStats(initialStats);

      log("✅ Initialized overall stats for user $userId");
      return initialStats;
    } catch (e) {
      log("❌ Error initializing overall stats: $e");
      rethrow;
    }
  }

  /// Reset overall stats to correct values (fix accumulated bug)
  Future<void> resetOverallStatsToCorrectValues(int userId) async {
    try {
      // Get today's actual step data
      final todayMetrics = await getTodayStepMetrics(userId);

      if (todayMetrics != null) {
        // Create corrected overall stats with just today's data
        final correctedStats = UserOverallStats(
          userId: userId,
          firstInstallDate: DateTime.now(),
          totalDays: 1,
          totalSteps: todayMetrics.steps, // Use actual today steps, not accumulated
          totalDistance: todayMetrics.distance,
          totalCalories: todayMetrics.calories,
          avgSpeed: todayMetrics.avgSpeed,
        );

        await insertOrUpdateUserOverallStats(correctedStats);
        log("✅ Reset overall stats to correct values: ${todayMetrics.steps} steps");
      }
    } catch (e) {
      log("❌ Error resetting overall stats: $e");
      rethrow;
    }
  }

  // === STEP HISTORY CRUD OPERATIONS ===

  /// Insert step history record
  Future<int> insertStepHistory(StepHistory stepHistory) async {
    try {
      final db = await database;
      final data = stepHistory.toMap();

      final id = await db.insert(
        _stepHistoryTable,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      log("✅ Step history inserted with ID: $id");
      return id;
    } catch (e) {
      log("❌ Error inserting step history: $e");
      rethrow;
    }
  }

  /// Get step history by date range
  Future<List<StepHistory>> getStepHistoryByDateRange({
    required int userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final db = await database;
      final startDateStr = startDate.toIso8601String().split('T')[0];
      final endDateStr = endDate.toIso8601String().split('T')[0];

      final result = await db.query(
        _stepHistoryTable,
        where: 'userId = ? AND date >= ? AND date <= ?',
        whereArgs: [userId, startDateStr, endDateStr],
        orderBy: 'date ASC',
      );

      return result.map((map) => StepHistory.fromMap(map)).toList();
    } catch (e) {
      log("❌ Error getting step history: $e");
      return [];
    }
  }

  /// Get all step history for user
  Future<List<StepHistory>> getAllStepHistory(int userId) async {
    try {
      final db = await database;

      final result = await db.query(
        _stepHistoryTable,
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'date DESC',
      );

      return result.map((map) => StepHistory.fromMap(map)).toList();
    } catch (e) {
      log("❌ Error getting all step history: $e");
      return [];
    }
  }

  /// Delete old step history (keep only last 365 days)
  Future<void> cleanupOldStepHistory(int userId) async {
    try {
      final db = await database;
      final cutoffDate = DateTime.now().subtract(const Duration(days: 365));
      final cutoffDateStr = cutoffDate.toIso8601String().split('T')[0];

      final deletedCount = await db.delete(
        _stepHistoryTable,
        where: 'userId = ? AND date < ?',
        whereArgs: [userId, cutoffDateStr],
      );

      log("🧹 Cleaned up $deletedCount old step history records");
    } catch (e) {
      log("❌ Error cleaning up step history: $e");
    }
  }

  // === HOMEPAGE FILTERING METHODS ===

  /// Get today's step stats
  Future<StepMetrics?> getTodayStats(int userId) async {
    final today = DateTime.now();
    return await getDailyStepMetrics(userId, today);
  }

  /// Get last 7 days step history with aggregation
  /// INCLUDES today's real-time steps from StepTrackingService
  Future<Map<String, dynamic>> getLast7DaysStats(int userId) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 6)); // 7 days including today

      // Get historical data (excluding today from database to avoid stale data)
      final yesterday = endDate.subtract(const Duration(days: 1));
      final history = await getStepHistoryByDateRange(
        userId: userId,
        startDate: startDate,
        endDate: yesterday,
      );

      // Get today's real-time data from StepTrackingService
      int todaySteps = 0;
      double todayDistance = 0.0;
      int todayCalories = 0;
      int todayActiveTime = 0;

      try {
        if (Get.isRegistered<StepTrackingService>()) {
          final stepTrackingService = Get.find<StepTrackingService>();
          todaySteps = stepTrackingService.todaySteps.value;
          todayDistance = stepTrackingService.todayDistance.value;
          todayCalories = stepTrackingService.todayCalories.value;
          todayActiveTime = stepTrackingService.todayActiveTime.value;
        }
      } catch (e) {
        log("⚠️ Could not get today's steps from StepTrackingService: $e");
      }

      // Calculate totals including today's real-time data
      final totalSteps = history.fold<int>(0, (sum, h) => sum + h.steps) + todaySteps;
      final totalDistance = history.fold<double>(0.0, (sum, h) => sum + h.distance) + todayDistance;
      final totalCalories = history.fold<int>(0, (sum, h) => sum + h.calories) + todayCalories;
      final totalActiveTime = history.fold<int>(0, (sum, h) => sum + h.activeTime) + todayActiveTime;

      final activeDays = history.where((h) => h.steps > 0).length + (todaySteps > 0 ? 1 : 0);
      final avgStepsPerDay = activeDays > 0 ? totalSteps / activeDays : 0.0;

      // Calculate average speed
      double avgSpeed = 0.0;
      if (totalActiveTime > 0) {
        final hours = totalActiveTime / 60.0;
        avgSpeed = totalDistance / hours;
      }

      return {
        'period': 'Last 7 days',
        'totalSteps': totalSteps,
        'totalDistance': totalDistance,
        'totalCalories': totalCalories,
        'totalActiveTime': totalActiveTime,
        'avgSpeed': avgSpeed,
        'avgStepsPerDay': avgStepsPerDay,
        'activeDays': activeDays,
        'dailyHistory': history,
      };
    } catch (e) {
      log("❌ Error getting last 7 days stats: $e");
      return _emptyStatsMap('Last 7 days');
    }
  }

  /// Get last 30 days step history with aggregation
  /// INCLUDES today's real-time steps from StepTrackingService
  Future<Map<String, dynamic>> getLast30DaysStats(int userId) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 29)); // 30 days including today

      // Get historical data (excluding today from database to avoid stale data)
      final yesterday = endDate.subtract(const Duration(days: 1));
      final history = await getStepHistoryByDateRange(
        userId: userId,
        startDate: startDate,
        endDate: yesterday,
      );

      // Get today's real-time data from StepTrackingService
      int todaySteps = 0;
      double todayDistance = 0.0;
      int todayCalories = 0;
      int todayActiveTime = 0;

      try {
        if (Get.isRegistered<StepTrackingService>()) {
          final stepTrackingService = Get.find<StepTrackingService>();
          todaySteps = stepTrackingService.todaySteps.value;
          todayDistance = stepTrackingService.todayDistance.value;
          todayCalories = stepTrackingService.todayCalories.value;
          todayActiveTime = stepTrackingService.todayActiveTime.value;
        }
      } catch (e) {
        log("⚠️ Could not get today's steps from StepTrackingService: $e");
      }

      // Calculate totals including today's real-time data
      final totalSteps = history.fold<int>(0, (sum, h) => sum + h.steps) + todaySteps;
      final totalDistance = history.fold<double>(0.0, (sum, h) => sum + h.distance) + todayDistance;
      final totalCalories = history.fold<int>(0, (sum, h) => sum + h.calories) + todayCalories;
      final totalActiveTime = history.fold<int>(0, (sum, h) => sum + h.activeTime) + todayActiveTime;

      final activeDays = history.where((h) => h.steps > 0).length + (todaySteps > 0 ? 1 : 0);
      final avgStepsPerDay = activeDays > 0 ? totalSteps / activeDays : 0.0;

      // Calculate average speed
      double avgSpeed = 0.0;
      if (totalActiveTime > 0) {
        final hours = totalActiveTime / 60.0;
        avgSpeed = totalDistance / hours;
      }

      return {
        'period': 'Last 30 days',
        'totalSteps': totalSteps,
        'totalDistance': totalDistance,
        'totalCalories': totalCalories,
        'totalActiveTime': totalActiveTime,
        'avgSpeed': avgSpeed,
        'avgStepsPerDay': avgStepsPerDay,
        'activeDays': activeDays,
        'dailyHistory': history,
      };
    } catch (e) {
      log("❌ Error getting last 30 days stats: $e");
      return _emptyStatsMap('Last 30 days');
    }
  }

  /// Get last 90 days step history with aggregation
  /// INCLUDES today's real-time steps from StepTrackingService
  Future<Map<String, dynamic>> getLast90DaysStats(int userId) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 89)); // 90 days including today

      // Get historical data (excluding today from database to avoid stale data)
      final yesterday = endDate.subtract(const Duration(days: 1));
      final history = await getStepHistoryByDateRange(
        userId: userId,
        startDate: startDate,
        endDate: yesterday,
      );

      // Get today's real-time data from StepTrackingService
      int todaySteps = 0;
      double todayDistance = 0.0;
      int todayCalories = 0;
      int todayActiveTime = 0;

      try {
        if (Get.isRegistered<StepTrackingService>()) {
          final stepTrackingService = Get.find<StepTrackingService>();
          todaySteps = stepTrackingService.todaySteps.value;
          todayDistance = stepTrackingService.todayDistance.value;
          todayCalories = stepTrackingService.todayCalories.value;
          todayActiveTime = stepTrackingService.todayActiveTime.value;
        }
      } catch (e) {
        log("⚠️ Could not get today's steps from StepTrackingService: $e");
      }

      // Calculate totals including today's real-time data
      final totalSteps = history.fold<int>(0, (sum, h) => sum + h.steps) + todaySteps;
      final totalDistance = history.fold<double>(0.0, (sum, h) => sum + h.distance) + todayDistance;
      final totalCalories = history.fold<int>(0, (sum, h) => sum + h.calories) + todayCalories;
      final totalActiveTime = history.fold<int>(0, (sum, h) => sum + h.activeTime) + todayActiveTime;

      final activeDays = history.where((h) => h.steps > 0).length + (todaySteps > 0 ? 1 : 0);
      final avgStepsPerDay = activeDays > 0 ? totalSteps / activeDays : 0.0;

      // Calculate average speed
      double avgSpeed = 0.0;
      if (totalActiveTime > 0) {
        final hours = totalActiveTime / 60.0;
        avgSpeed = totalDistance / hours;
      }

      return {
        'period': 'Last 90 days',
        'totalSteps': totalSteps,
        'totalDistance': totalDistance,
        'totalCalories': totalCalories,
        'totalActiveTime': totalActiveTime,
        'avgSpeed': avgSpeed,
        'avgStepsPerDay': avgStepsPerDay,
        'activeDays': activeDays,
        'dailyHistory': history,
      };
    } catch (e) {
      log("❌ Error getting last 90 days stats: $e");
      return _emptyStatsMap('Last 90 days');
    }
  }

  /// Get yesterday's step history
  Future<Map<String, dynamic>> getYesterdayStats(int userId) async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStart = DateTime(yesterday.year, yesterday.month, yesterday.day);
      final yesterdayEnd = yesterdayStart.add(const Duration(days: 1));

      final history = await getStepHistoryByDateRange(
        userId: userId,
        startDate: yesterdayStart,
        endDate: yesterdayEnd,
      );

      if (history.isEmpty) {
        return _emptyStatsMap('Yesterday');
      }

      final yesterdayData = history.first;

      return {
        'period': 'Yesterday',
        'totalSteps': yesterdayData.steps,
        'totalDistance': yesterdayData.distance,
        'totalCalories': yesterdayData.calories,
        'totalActiveTime': yesterdayData.activeTime,
        'avgSpeed': yesterdayData.avgSpeed,
        'avgStepsPerDay': yesterdayData.steps.toDouble(),
        'activeDays': yesterdayData.steps > 0 ? 1 : 0,
        'dailyHistory': history,
      };
    } catch (e) {
      log("❌ Error getting yesterday stats: $e");
      return _emptyStatsMap('Yesterday');
    }
  }

  /// Get last 60 days step history with aggregation
  /// INCLUDES today's real-time steps from StepTrackingService
  Future<Map<String, dynamic>> getLast60DaysStats(int userId) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 59)); // 60 days including today

      // Get historical data (excluding today from database to avoid stale data)
      final yesterday = endDate.subtract(const Duration(days: 1));
      final history = await getStepHistoryByDateRange(
        userId: userId,
        startDate: startDate,
        endDate: yesterday,
      );

      // Get today's real-time data from StepTrackingService
      int todaySteps = 0;
      double todayDistance = 0.0;
      int todayCalories = 0;
      int todayActiveTime = 0;

      try {
        if (Get.isRegistered<StepTrackingService>()) {
          final stepTrackingService = Get.find<StepTrackingService>();
          todaySteps = stepTrackingService.todaySteps.value;
          todayDistance = stepTrackingService.todayDistance.value;
          todayCalories = stepTrackingService.todayCalories.value;
          todayActiveTime = stepTrackingService.todayActiveTime.value;
        }
      } catch (e) {
        log("⚠️ Could not get today's steps from StepTrackingService: $e");
      }

      // Calculate totals including today's real-time data
      final totalSteps = history.fold<int>(0, (sum, h) => sum + h.steps) + todaySteps;
      final totalDistance = history.fold<double>(0.0, (sum, h) => sum + h.distance) + todayDistance;
      final totalCalories = history.fold<int>(0, (sum, h) => sum + h.calories) + todayCalories;
      final totalActiveTime = history.fold<int>(0, (sum, h) => sum + h.activeTime) + todayActiveTime;

      final activeDays = history.where((h) => h.steps > 0).length + (todaySteps > 0 ? 1 : 0);
      final avgStepsPerDay = activeDays > 0 ? totalSteps / activeDays : 0.0;

      // Calculate average speed
      double avgSpeed = 0.0;
      if (totalActiveTime > 0) {
        final hours = totalActiveTime / 60.0;
        avgSpeed = totalDistance / hours;
      }

      return {
        'period': 'Last 60 days',
        'totalSteps': totalSteps,
        'totalDistance': totalDistance,
        'totalCalories': totalCalories,
        'totalActiveTime': totalActiveTime,
        'avgSpeed': avgSpeed,
        'avgStepsPerDay': avgStepsPerDay,
        'activeDays': activeDays,
        'dailyHistory': history,
      };
    } catch (e) {
      log("❌ Error getting last 60 days stats: $e");
      return _emptyStatsMap('Last 60 days');
    }
  }

  /// Get all-time step history with aggregation
  /// INCLUDES today's real-time steps from StepTrackingService
  Future<Map<String, dynamic>> getAllTimeStats(int userId) async {
    try {
      // Get all historical data (excluding today from database to avoid stale data)
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final history = await getStepHistoryByDateRange(
        userId: userId,
        startDate: DateTime(2000, 1, 1), // Far past date to get all history
        endDate: yesterday,
      );

      // Get today's real-time data from StepTrackingService
      int todaySteps = 0;
      double todayDistance = 0.0;
      int todayCalories = 0;
      int todayActiveTime = 0;

      try {
        if (Get.isRegistered<StepTrackingService>()) {
          final stepTrackingService = Get.find<StepTrackingService>();
          todaySteps = stepTrackingService.todaySteps.value;
          todayDistance = stepTrackingService.todayDistance.value;
          todayCalories = stepTrackingService.todayCalories.value;
          todayActiveTime = stepTrackingService.todayActiveTime.value;
        }
      } catch (e) {
        log("⚠️ Could not get today's steps from StepTrackingService: $e");
      }

      // Calculate totals including today's real-time data
      final totalSteps = history.fold<int>(0, (sum, h) => sum + h.steps) + todaySteps;
      final totalDistance = history.fold<double>(0.0, (sum, h) => sum + h.distance) + todayDistance;
      final totalCalories = history.fold<int>(0, (sum, h) => sum + h.calories) + todayCalories;
      final totalActiveTime = history.fold<int>(0, (sum, h) => sum + h.activeTime) + todayActiveTime;

      final activeDays = history.where((h) => h.steps > 0).length + (todaySteps > 0 ? 1 : 0);
      final avgStepsPerDay = activeDays > 0 ? totalSteps / activeDays : 0.0;

      // Calculate average speed
      double avgSpeed = 0.0;
      if (totalActiveTime > 0) {
        final hours = totalActiveTime / 60.0;
        avgSpeed = totalDistance / hours;
      }

      return {
        'period': 'All time',
        'totalSteps': totalSteps,
        'totalDistance': totalDistance,
        'totalCalories': totalCalories,
        'totalActiveTime': totalActiveTime,
        'avgSpeed': avgSpeed,
        'avgStepsPerDay': avgStepsPerDay,
        'activeDays': activeDays,
        'dailyHistory': history,
      };
    } catch (e) {
      log("❌ Error getting all time stats: $e");
      return _emptyStatsMap('All time');
    }
  }

  /// Get stats by period filter
  Future<Map<String, dynamic>> getStatsByPeriod(int userId, String period) async {
    switch (period.toLowerCase()) {
      case 'today':
        final todayStats = await getTodayStats(userId);
        if (todayStats != null) {
          return {
            'period': 'Today',
            'totalSteps': todayStats.steps,
            'totalDistance': todayStats.distance,
            'totalCalories': todayStats.calories.round(),
            'totalActiveTime': todayStats.activeTime,
            'avgSpeed': todayStats.avgSpeed,
            'avgStepsPerDay': todayStats.steps.toDouble(),
            'activeDays': todayStats.steps > 0 ? 1 : 0,
            'dailyHistory': [StepHistory.fromStepMetrics(todayStats)],
          };
        }
        return _emptyStatsMap('Today');

      case 'yesterday':
        return await getYesterdayStats(userId);

      case 'last 7 days':
        return await getLast7DaysStats(userId);

      case 'last 30 days':
        return await getLast30DaysStats(userId);

      case 'last 60 days':
        return await getLast60DaysStats(userId);

      case 'last 90 days':
        return await getLast90DaysStats(userId);

      case 'all time':
        return await getAllTimeStats(userId);

      default:
        log("❌ Unknown period filter: $period");
        return _emptyStatsMap(period);
    }
  }

  /// Helper method to create empty stats map
  Map<String, dynamic> _emptyStatsMap(String period) {
    return {
      'period': period,
      'totalSteps': 0,
      'totalDistance': 0.0,
      'totalCalories': 0,
      'totalActiveTime': 0,
      'avgSpeed': 0.0,
      'avgStepsPerDay': 0.0,
      'activeDays': 0,
      'dailyHistory': <StepHistory>[],
    };
  }

  /// Update daily step data and sync with overall stats
  Future<void> updateDailyStepDataAndSync({
    required int userId,
    required DateTime date,
    required int steps,
    required double distance,
    required double calories,
    required int activeTime,
    required double avgSpeed,
    String duration = "00:00",
    bool updateOverallStats = false, // Only update overall stats when explicitly requested
  }) async {
    try {
      // Update daily step metrics
      final stepMetrics = StepMetrics(
        userId: userId,
        date: date,
        steps: steps,
        calories: calories,
        distance: distance,
        avgSpeed: avgSpeed,
        activeTime: activeTime,
        duration: duration,
      );

      await insertOrUpdateDailyStepMetrics(stepMetrics);

      // Add to step history
      final stepHistory = StepHistory.fromStepMetrics(stepMetrics);
      await insertStepHistory(stepHistory);

      // Only update overall stats when explicitly requested (not every 15 seconds)
      if (updateOverallStats) {
        log("📊 Updating overall stats (not frequent save)");
        final currentOverallStats = await getUserOverallStats(userId) ??
            UserOverallStats.initial(userId: userId);

        final updatedOverallStats = currentOverallStats.updateWithDailyStats(
          dailySteps: steps,
          dailyDistance: distance,
          dailyCalories: calories,
          dailyAvgSpeed: avgSpeed,
        );

        await insertOrUpdateUserOverallStats(updatedOverallStats);
        log("✅ Overall stats updated for user $userId");
      } else {
        log("⏭️ Skipping overall stats update (frequent save)");
      }

      log("✅ Daily step data updated and synced for user $userId");
    } catch (e) {
      log("❌ Error updating daily step data and sync: $e");
      rethrow;
    }
  }

  /// Get comprehensive user stats for homepage
  Future<Map<String, dynamic>> getHomepageStats(int userId, {String period = 'Today'}) async {
    try {
      final overallStats = await getUserOverallStats(userId);
      final periodStats = await getStatsByPeriod(userId, period);

      return {
        'overallStats': overallStats?.toMap(),
        'periodStats': periodStats,
        'availablePeriods': ['Today', 'Last 7 days', 'Last 30 days', 'Last 90 days'],
      };
    } catch (e) {
      log("❌ Error getting homepage stats: $e");
      return {
        'overallStats': null,
        'periodStats': _emptyStatsMap(period),
        'availablePeriods': ['Today', 'Last 7 days', 'Last 30 days', 'Last 90 days'],
      };
    }
  }
}