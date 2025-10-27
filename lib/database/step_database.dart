import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/daily_step_data.dart';
import '../utils/step_constants.dart';

/// SQLite database for local step data storage
/// Provides offline persistence and fast local queries
class StepDatabase {
  static StepDatabase? _instance;
  static Database? _database;

  StepDatabase._();

  /// Singleton instance
  static StepDatabase get instance {
    _instance ??= StepDatabase._();
    return _instance!;
  }

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, StepConstants.sqliteDatabaseName);

    return await openDatabase(
      path,
      version: StepConstants.sqliteDatabaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${StepConstants.dailyStepsTableName} (
        date TEXT PRIMARY KEY,
        steps INTEGER NOT NULL DEFAULT 0,
        distance REAL NOT NULL DEFAULT 0.0,
        activeMinutes INTEGER NOT NULL DEFAULT 0,
        calories INTEGER NOT NULL DEFAULT 0,
        hourlyBreakdown TEXT,
        pedometerSteps INTEGER,
        healthKitSteps INTEGER,
        source TEXT NOT NULL DEFAULT 'pedometer',
        isSynced INTEGER NOT NULL DEFAULT 0,
        syncedAt INTEGER NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    // Create index on date for faster queries
    await db.execute('''
      CREATE INDEX idx_date ON ${StepConstants.dailyStepsTableName}(date)
    ''');

    // Create index on isSynced for finding unsynced records
    await db.execute('''
      CREATE INDEX idx_synced ON ${StepConstants.dailyStepsTableName}(isSynced)
    ''');

    print('✅ Step tracking database created successfully');
  }

  /// Upgrade database schema
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Upgrading database from version $oldVersion to $newVersion');

    // Always recreate table for any version upgrade to ensure clean schema
    try {
      print('🔄 Recreating table with new schema...');

      // Step 1: Rename old table to backup
      await db.execute(
        'ALTER TABLE ${StepConstants.dailyStepsTableName} RENAME TO ${StepConstants.dailyStepsTableName}_old'
      );
      print('✅ Backed up old table');

      // Step 2: Create new table with correct schema
      await db.execute('''
        CREATE TABLE ${StepConstants.dailyStepsTableName} (
          date TEXT PRIMARY KEY,
          steps INTEGER NOT NULL DEFAULT 0,
          distance REAL NOT NULL DEFAULT 0.0,
          activeMinutes INTEGER NOT NULL DEFAULT 0,
          calories INTEGER NOT NULL DEFAULT 0,
          hourlyBreakdown TEXT,
          pedometerSteps INTEGER,
          healthKitSteps INTEGER,
          source TEXT NOT NULL DEFAULT 'pedometer',
          isSynced INTEGER NOT NULL DEFAULT 0,
          syncedAt INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL DEFAULT 0
        )
      ''');
      print('✅ Created new table');

      // Step 3: Copy data from old table to new table (with proper column mapping)
      await db.execute('''
        INSERT OR IGNORE INTO ${StepConstants.dailyStepsTableName}
        (date, steps, distance, activeMinutes, calories, hourlyBreakdown,
         pedometerSteps, healthKitSteps, source, isSynced, syncedAt, createdAt)
        SELECT
          date,
          COALESCE(steps, 0),
          COALESCE(distance, 0.0),
          COALESCE(activeTimeMinutes, activeMinutes, 0),
          COALESCE(calories, 0),
          COALESCE(hourlyBreakdown, '{}'),
          pedometerSteps,
          healthKitSteps,
          COALESCE(source, 'pedometer'),
          COALESCE(synced, isSynced, 0),
          COALESCE(syncedAt, lastUpdated, createdAt, strftime('%s','now') * 1000),
          COALESCE(createdAt, strftime('%s','now') * 1000)
        FROM ${StepConstants.dailyStepsTableName}_old
      ''');
      print('✅ Migrated data from old table');

      // Step 4: Drop old table
      await db.execute('DROP TABLE ${StepConstants.dailyStepsTableName}_old');
      print('✅ Dropped old table');

      // Step 5: Recreate indexes
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_date ON ${StepConstants.dailyStepsTableName}(date)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_synced ON ${StepConstants.dailyStepsTableName}(isSynced)
      ''');
      print('✅ Recreated indexes');

      print('✅ Database upgrade completed successfully');
    } catch (e) {
      print('❌ Error during database upgrade: $e');
      // If upgrade fails, drop everything and recreate fresh
      print('🔄 Attempting complete recreation...');
      await db.execute('DROP TABLE IF EXISTS ${StepConstants.dailyStepsTableName}');
      await db.execute('DROP TABLE IF EXISTS ${StepConstants.dailyStepsTableName}_old');
      await _onCreate(db, newVersion);
    }
  }

  /// Insert or update daily step data
  Future<void> upsertDailyData(DailyStepData data) async {
    final db = await database;
    await db.insert(
      StepConstants.dailyStepsTableName,
      data.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get daily data by date
  Future<DailyStepData?> getDailyData(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      StepConstants.dailyStepsTableName,
      where: 'date = ?',
      whereArgs: [date],
    );

    if (maps.isEmpty) return null;
    return DailyStepData.fromSqliteMap(maps.first);
  }

  /// Get daily data for a date range
  Future<List<DailyStepData>> getDailyDataRange(String startDate, String endDate) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      StepConstants.dailyStepsTableName,
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC',
    );

    return maps.map((map) => DailyStepData.fromSqliteMap(map)).toList();
  }

  /// Get all daily data (for full sync)
  Future<List<DailyStepData>> getAllDailyData() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      StepConstants.dailyStepsTableName,
      orderBy: 'date DESC',
    );

    return maps.map((map) => DailyStepData.fromSqliteMap(map)).toList();
  }

  /// Get unsynced data
  Future<List<DailyStepData>> getUnsyncedData() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      StepConstants.dailyStepsTableName,
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'date DESC',
    );

    return maps.map((map) => DailyStepData.fromSqliteMap(map)).toList();
  }

  /// Mark data as synced
  Future<void> markAsSynced(String date) async {
    final db = await database;
    await db.update(
      StepConstants.dailyStepsTableName,
      {'isSynced': 1},
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  /// Delete old data (keep only recent data)
  Future<void> deleteOldData(String beforeDate) async {
    final db = await database;
    final count = await db.delete(
      StepConstants.dailyStepsTableName,
      where: 'date < ?',
      whereArgs: [beforeDate],
    );
    print('🗑️ Deleted $count old step records before $beforeDate');
  }

  /// Get total count of records
  Future<int> getRecordCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${StepConstants.dailyStepsTableName}'
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get total steps across all records
  Future<int> getTotalSteps() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(steps) as total FROM ${StepConstants.dailyStepsTableName}'
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get total distance across all records
  Future<double> getTotalDistance() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(distance) as total FROM ${StepConstants.dailyStepsTableName}'
    );
    final value = result.first['total'];
    if (value == null) return 0.0;
    return (value as num).toDouble();
  }

  /// Delete all data (for testing/reset)
  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete(StepConstants.dailyStepsTableName);
    print('🗑️ Deleted all step data from local database');
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
    print('🔒 Step database closed');
  }

  /// Get recent data (last N days)
  Future<List<DailyStepData>> getRecentData(int days) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      StepConstants.dailyStepsTableName,
      orderBy: 'date DESC',
      limit: days,
    );

    return maps.map((map) => DailyStepData.fromSqliteMap(map)).toList();
  }

  /// Check if data exists for a date
  Future<bool> hasDataForDate(String date) async {
    final db = await database;
    final result = await db.query(
      StepConstants.dailyStepsTableName,
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Batch insert/update multiple records
  Future<void> batchUpsert(List<DailyStepData> dataList) async {
    final db = await database;
    final batch = db.batch();

    for (final data in dataList) {
      batch.insert(
        StepConstants.dailyStepsTableName,
        data.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('✅ Batch upserted ${dataList.length} records');
  }
}
