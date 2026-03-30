import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/custom_marker.dart';
import 'package:obsession_tracker/core/models/imported_route.dart';
import 'package:obsession_tracker/core/models/marker_attachment.dart';
import 'package:obsession_tracker/core/models/session_statistics.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/treasure_hunt.dart';
import 'package:obsession_tracker/core/models/voice_note.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/models/waypoint_metadata.dart';
import 'package:obsession_tracker/core/models/waypoint_template.dart';
import 'package:obsession_tracker/core/services/encryption_key_service.dart';
import 'package:obsession_tracker/features/journal/data/models/journal_entry.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Local SQLite database service for storing tracking sessions and breadcrumbs.
///
/// Provides privacy-first local storage with AES-256 encryption via SQLCipher.
/// Database encryption keys are securely stored in iOS Keychain / Android KeyStore.
///
/// Security Features:
/// - AES-256 encryption at rest for all database contents
/// - Encryption keys stored in hardware-backed secure storage when available
/// - Automatic key generation on first access
/// - Protection for treasure hunting location data
///
/// Provides privacy-first local storage without any cloud synchronization
/// for the Obsession Tracker app.
class DatabaseService {
  factory DatabaseService() => _instance ??= DatabaseService._();
  DatabaseService._();
  static DatabaseService? _instance;

  /// Reset the singleton instance so the next call creates a fresh one.
  /// Call this after resetDatabase() when restarting the app in-process.
  static void resetInstance() {
    _instance = null;
  }

  Database? _database;
  Future<Database>? _initializationFuture;  // Prevents concurrent initialization
  bool _isInitializing = false;
  static const String _databaseName = 'obsession_tracker.db';
  static const int _databaseVersion = 15;

  /// Tables
  static const String _sessionsTable = 'sessions';
  static const String _breadcrumbsTable = 'breadcrumbs';
  static const String _waypointsTable = 'waypoints';
  static const String _statisticsTable = 'session_statistics';
  static const String _photoWaypointsTable = 'photo_waypoints';
  static const String _photoMetadataTable = 'photo_metadata';
  static const String _voiceNotesTable = 'voice_notes';
  static const String _enhancedWaypointsTable = 'enhanced_waypoints';
  static const String _importedRoutesTable = 'imported_routes';
  static const String _routePointsTable = 'route_points';
  static const String _routeWaypointsTable = 'route_waypoints';
  static const String _landOwnershipTable = 'land_ownership';
  static const String _waypointTemplatesTable = 'waypoint_templates';
  static const String _waypointMetadataTable = 'waypoint_metadata';
  static const String _waypointRelationshipsTable = 'waypoint_relationships';
  static const String _waypointClustersTable = 'waypoint_clusters';
  static const String _waypointHistoryTable = 'waypoint_history';
  static const String _waypointSnapshotsTable = 'waypoint_snapshots';
  static const String _plannedRoutesTable = 'planned_routes';
  static const String _treasureHuntsTable = 'treasure_hunts';
  static const String _huntDocumentsTable = 'hunt_documents';
  static const String _huntSessionLinksTable = 'hunt_session_links';
  static const String _huntLocationsTable = 'hunt_locations';
  static const String _customMarkersTable = 'custom_markers';
  static const String _markerAttachmentsTable = 'marker_attachments';
  // Achievement & Statistics tables (v14)
  static const String _achievementsTable = 'achievements';
  static const String _userAchievementsTable = 'user_achievements';
  static const String _exploredStatesTable = 'explored_states';
  static const String _lifetimeStatisticsTable = 'lifetime_statistics';
  static const String _sessionStreaksTable = 'session_streaks';
  // Journal table (v15)
  static const String _journalEntriesTable = 'journal_entries';

  /// Get the database instance, creating it if necessary
  ///
  /// Uses _initializationFuture to prevent race conditions when multiple
  /// callers request the database simultaneously (e.g., after subscription
  /// status changes trigger multiple provider rebuilds).
  Future<Database> get database async {
    // Already initialized - fast path
    if (_database != null) {
      return _database!;
    }

    // If initialization is already in progress, wait for it
    if (_initializationFuture != null) {
      return _initializationFuture!;
    }

    // Start initialization and store the future so concurrent callers can await it
    final future = _initDatabase();
    _initializationFuture = future;
    try {
      _database = await future;
      return _database!;
    } finally {
      _initializationFuture = null;
    }
  }

  /// Initialize the database with AES-256 encryption
  Future<Database> _initDatabase() async {
    try {
      final Directory documentsDirectory =
          await getApplicationDocumentsDirectory();
      final String path = join(documentsDirectory.path, _databaseName);

      if (!_isInitializing) {
        _isInitializing = true;
        debugPrint('Initializing encrypted database at: $path');
      }

      // Check if database file exists
      final dbFile = File(path);
      final dbExists = await dbFile.exists();

      // Check if this is first-time encryption (no key exists yet)
      final hasExistingKey = await EncryptionKeyService.hasDatabaseKey();

      // Get encryption key (generates new one if doesn't exist)
      final String encryptionKey = await EncryptionKeyService.getDatabaseKey();
      debugPrint('Encryption key retrieved from secure storage');

      // If database exists but we just generated a new key, check whether the
      // existing database is truly unencrypted or if we lost the key (e.g.
      // after an App Store app transfer which changes the Keychain prefix).
      if (dbExists && !hasExistingKey) {
        final isEncrypted = await _isDatabaseEncrypted(path);
        if (isEncrypted) {
          // Database is encrypted but we lost access to the key — likely an
          // app transfer changed the Keychain team prefix. Do NOT attempt
          // migration as that would fail and could corrupt the backup.
          debugPrint('Database is encrypted but encryption key was lost '
              '(possible app transfer). Cannot decrypt.');
          throw DatabaseRecoveryException(
            'Your data is encrypted but the encryption key is no longer '
            'accessible. This can happen after an App Store app transfer. '
            'You can restore from a backup (.obk file) or reset the app '
            'to start fresh.',
            originalError: Exception('Encryption key lost after app transfer'),
          );
        }
        debugPrint('Detected unencrypted database - migrating to encrypted format...');
        return await _migrateToEncrypted(path, encryptionKey);
      }

      // Normal encrypted database open
      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        password: encryptionKey, // ← DATABASE NOW ENCRYPTED WITH AES-256
      );
    } catch (e) {
      if (e is DatabaseRecoveryException) rethrow;

      debugPrint('Error initializing encrypted database: $e');

      // Check if this is a recoverable error (key mismatch, corruption, etc.)
      // Note: SQLCipher reports "out of memory" when the wrong decryption key
      // is used — this is the most common symptom after an app transfer changes
      // the Keychain team prefix, leaving the app with a new key that doesn't
      // match the existing encrypted database.
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('open_failed') ||
          errorString.contains('file is not a database') ||
          errorString.contains('unable to open database') ||
          errorString.contains('disk i/o error') ||
          errorString.contains('out of memory')) {
        throw DatabaseRecoveryException(
          'Database cannot be opened. This may happen after an App Store '
          'app transfer or if the encryption key was lost. You can reset '
          'the app to start fresh.',
          originalError: e,
        );
      }

      rethrow;
    }
  }

  /// Check if a database file is encrypted (SQLCipher) vs plain SQLite.
  ///
  /// Plain SQLite databases start with the string "SQLite format 3\000".
  /// Encrypted databases will have random-looking bytes instead.
  Future<bool> _isDatabaseEncrypted(String path) async {
    try {
      final file = File(path);
      final bytes = await file.openRead(0, 16).fold<List<int>>(
        <int>[],
        (prev, chunk) => prev..addAll(chunk),
      );
      // SQLite magic header: "SQLite format 3\0"
      const sqliteHeader = [
        0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
        0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
      ];
      if (bytes.length < 16) return true; // Too small to be valid SQLite
      for (int i = 0; i < 16; i++) {
        if (bytes[i] != sqliteHeader[i]) return true; // Not plain SQLite = encrypted
      }
      return false; // Matches SQLite header = unencrypted
    } catch (e) {
      debugPrint('Error checking database encryption: $e');
      return true; // Assume encrypted on error to avoid data loss
    }
  }

  /// Reset the database completely - USE WITH CAUTION
  ///
  /// This will:
  /// 1. Delete the database file
  /// 2. Reset the encryption key
  /// 3. Clear the in-memory database reference
  ///
  /// All data will be permanently lost. Only call this when the user
  /// explicitly confirms they want to reset.
  Future<void> resetDatabase() async {
    debugPrint('⚠️ DATABASE RESET REQUESTED - All data will be lost');

    try {
      // Close existing database if open
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      _initializationFuture = null;
      _isInitializing = false;

      // Delete database file
      final Directory documentsDirectory =
          await getApplicationDocumentsDirectory();
      final String path = join(documentsDirectory.path, _databaseName);
      final dbFile = File(path);

      if (await dbFile.exists()) {
        await dbFile.delete();
        debugPrint('✅ Database file deleted');
      }

      // Also delete any backup files
      final backupFile = File('$path.backup');
      if (await backupFile.exists()) {
        await backupFile.delete();
        debugPrint('✅ Backup file deleted');
      }

      // Reset the encryption key so a fresh one is generated
      await EncryptionKeyService.resetDatabaseKey();
      debugPrint('✅ Encryption key reset');

      debugPrint('✅ Database reset complete - app will create fresh database on next access');
    } catch (e) {
      debugPrint('❌ Error during database reset: $e');
      rethrow;
    }
  }

  /// Check if the database can be opened successfully
  ///
  /// Returns true if database is accessible, false if it needs recovery.
  /// This is useful for checking database health on app startup.
  Future<bool> isDatabaseAccessible() async {
    try {
      await database;
      return true;
    } on DatabaseRecoveryException {
      return false;
    } catch (e) {
      debugPrint('Database accessibility check failed: $e');
      return false;
    }
  }

  /// Migrate existing unencrypted database to encrypted format
  Future<Database> _migrateToEncrypted(String path, String encryptionKey) async {
    final backupPath = '$path.backup';

    try {
      // Step 1: Rename old database to backup
      final dbFile = File(path);
      await dbFile.copy(backupPath);
      debugPrint('✅ Created backup at: $backupPath');

      // Step 2: Delete original (we'll recreate it encrypted)
      await dbFile.delete();
      debugPrint('✅ Deleted original unencrypted database');

      // Step 3: Create new encrypted database
      final encryptedDb = await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        password: encryptionKey,
      );
      debugPrint('✅ Created new encrypted database');

      // Step 4: Open backup (unencrypted) and copy data
      final backupDb = await openDatabase(backupPath, readOnly: true);
      debugPrint('✅ Opened backup database for migration');

      // Step 5: Migrate all data
      await _migrateAllData(backupDb, encryptedDb);
      debugPrint('✅ Migrated all data to encrypted database');

      // Step 6: Close and delete backup
      await backupDb.close();
      await File(backupPath).delete();
      debugPrint('✅ Migration complete - backup deleted');

      return encryptedDb;
    } catch (e) {
      debugPrint('❌ Migration failed: $e');

      // Try to restore from backup if migration failed
      if (await File(backupPath).exists()) {
        debugPrint('🔄 Attempting to restore from backup...');
        await File(backupPath).copy(path);
        await File(backupPath).delete();
        debugPrint('✅ Restored from backup');
      }

      rethrow;
    }
  }

  /// Copy all data from old database to new encrypted database
  Future<void> _migrateAllData(Database oldDb, Database newDb) async {
    // Get list of all tables
    final tables = [
      _sessionsTable,
      _breadcrumbsTable,
      _waypointsTable,
      _photoWaypointsTable,
      _photoMetadataTable,
      _voiceNotesTable,
      _enhancedWaypointsTable,
      _importedRoutesTable,
      _routePointsTable,
      _routeWaypointsTable,
      _waypointTemplatesTable,
    ];

    for (final table in tables) {
      try {
        // Check if table exists in old database
        final tableCheck = await oldDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$table'",
        );

        if (tableCheck.isEmpty) {
          debugPrint("⏭️  Skipping $table (doesn't exist in old database)");
          continue;
        }

        // Copy all rows from old table to new table
        final rows = await oldDb.query(table);
        if (rows.isNotEmpty) {
          for (final row in rows) {
            await newDb.insert(table, row);
          }
          debugPrint('✅ Migrated ${rows.length} rows from $table');
        } else {
          debugPrint('⏭️  Table $table is empty');
        }
      } catch (e) {
        debugPrint('⚠️  Error migrating table $table: $e');
        // Continue with other tables even if one fails
      }
    }
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    try {
      // Create sessions table
      await db.execute('''
        CREATE TABLE $_sessionsTable (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          status TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          started_at INTEGER,
          completed_at INTEGER,
          total_distance REAL NOT NULL DEFAULT 0.0,
          total_duration INTEGER NOT NULL DEFAULT 0,
          breadcrumb_count INTEGER NOT NULL DEFAULT 0,
          accuracy_threshold REAL NOT NULL DEFAULT 10.0,
          recording_interval INTEGER NOT NULL DEFAULT 5,
          start_latitude REAL,
          start_longitude REAL,
          end_latitude REAL,
          end_longitude REAL,
          minimum_speed REAL NOT NULL DEFAULT 0.0,
          record_altitude INTEGER NOT NULL DEFAULT 1,
          record_speed INTEGER NOT NULL DEFAULT 1,
          record_heading INTEGER NOT NULL DEFAULT 1,
          planned_route_id TEXT,
          planned_route_snapshot TEXT,
          elevation_gain REAL NOT NULL DEFAULT 0.0,
          elevation_loss REAL NOT NULL DEFAULT 0.0,
          max_altitude REAL,
          min_altitude REAL,
          max_speed REAL,
          hunt_id TEXT
        )
      ''');

      // Create index for hunt-based session queries
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sessions_hunt_id ON $_sessionsTable (hunt_id)'
      );

      // Create breadcrumbs table
      await db.execute('''
        CREATE TABLE $_breadcrumbsTable (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          altitude REAL,
          accuracy REAL NOT NULL,
          speed REAL,
          heading REAL,
          timestamp INTEGER NOT NULL,
          FOREIGN KEY (session_id) REFERENCES $_sessionsTable (id) ON DELETE CASCADE
        )
      ''');

      // Create waypoints table
      // session_id is nullable to support standalone waypoints (not part of a session)
      await db.execute('''
        CREATE TABLE $_waypointsTable (
          id TEXT PRIMARY KEY,
          session_id TEXT,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          type TEXT NOT NULL,
          category TEXT,
          timestamp INTEGER NOT NULL,
          name TEXT,
          notes TEXT,
          altitude REAL,
          accuracy REAL,
          speed REAL,
          heading REAL,
          FOREIGN KEY (session_id) REFERENCES $_sessionsTable (id) ON DELETE CASCADE
        )
      ''');

      // Create enhanced waypoints table
      await db.execute('''
        CREATE TABLE $_enhancedWaypointsTable (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          type TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          custom_name TEXT,
          notes TEXT,
          custom_color INTEGER,
          altitude REAL,
          accuracy REAL,
          speed REAL,
          heading REAL,
          FOREIGN KEY (session_id) REFERENCES $_sessionsTable (id) ON DELETE CASCADE
        )
      ''');

      // Create session statistics table
      await db.execute('''
        CREATE TABLE $_statisticsTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          total_distance REAL NOT NULL DEFAULT 0.0,
          segment_distance REAL NOT NULL DEFAULT 0.0,
          total_duration INTEGER NOT NULL DEFAULT 0,
          moving_duration INTEGER NOT NULL DEFAULT 0,
          stationary_duration INTEGER NOT NULL DEFAULT 0,
          current_speed REAL NOT NULL DEFAULT 0.0,
          average_speed REAL NOT NULL DEFAULT 0.0,
          moving_average_speed REAL NOT NULL DEFAULT 0.0,
          max_speed REAL NOT NULL DEFAULT 0.0,
          current_altitude REAL,
          min_altitude REAL,
          max_altitude REAL,
          total_elevation_gain REAL NOT NULL DEFAULT 0.0,
          total_elevation_loss REAL NOT NULL DEFAULT 0.0,
          current_heading REAL,
          waypoint_count INTEGER NOT NULL DEFAULT 0,
          waypoints_by_type TEXT NOT NULL DEFAULT '{}',
          waypoint_density REAL NOT NULL DEFAULT 0.0,
          last_location_accuracy REAL,
          average_accuracy REAL,
          good_accuracy_percentage REAL NOT NULL DEFAULT 0.0,
          FOREIGN KEY (session_id) REFERENCES $_sessionsTable (id) ON DELETE CASCADE
        )
      ''');

      // Create photo waypoints table
      await db.execute('''
        CREATE TABLE $_photoWaypointsTable (
          id TEXT PRIMARY KEY,
          waypoint_id TEXT NOT NULL,
          file_path TEXT NOT NULL,
          thumbnail_path TEXT,
          created_at INTEGER NOT NULL,
          file_size INTEGER NOT NULL DEFAULT 0,
          width INTEGER,
          height INTEGER,
          device_pitch REAL,
          device_roll REAL,
          device_yaw REAL,
          photo_orientation TEXT,
          camera_tilt_angle REAL,
          source TEXT,
          FOREIGN KEY (waypoint_id) REFERENCES $_waypointsTable (id) ON DELETE CASCADE
        )
      ''');

      // Create photo metadata table
      await db.execute('''
        CREATE TABLE $_photoMetadataTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          photo_waypoint_id TEXT NOT NULL,
          key TEXT NOT NULL,
          value TEXT,
          type TEXT NOT NULL DEFAULT 'string',
          FOREIGN KEY (photo_waypoint_id) REFERENCES $_photoWaypointsTable (id) ON DELETE CASCADE
        )
      ''');

      // Create voice notes table
      await db.execute('''
        CREATE TABLE $_voiceNotesTable (
          id TEXT PRIMARY KEY,
          waypoint_id TEXT NOT NULL,
          file_path TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          file_size INTEGER NOT NULL DEFAULT 0,
          duration INTEGER NOT NULL DEFAULT 0,
          transcription TEXT,
          FOREIGN KEY (waypoint_id) REFERENCES $_waypointsTable (id) ON DELETE CASCADE
        )
      ''');

      // Create indexes for better performance
      await db.execute('''
        CREATE INDEX idx_breadcrumbs_session_id ON $_breadcrumbsTable (session_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_breadcrumbs_timestamp ON $_breadcrumbsTable (timestamp)
      ''');

      await db.execute('''
        CREATE INDEX idx_sessions_created_at ON $_sessionsTable (created_at)
      ''');

      await db.execute('''
        CREATE INDEX idx_waypoints_session_id ON $_waypointsTable (session_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_waypoints_timestamp ON $_waypointsTable (timestamp)
      ''');

      await db.execute('''
        CREATE INDEX idx_waypoints_type ON $_waypointsTable (type)
      ''');

      await db.execute('''
        CREATE INDEX idx_waypoints_standalone ON $_waypointsTable (session_id) WHERE session_id IS NULL
      ''');

      await db.execute('''
        CREATE INDEX idx_waypoints_category ON $_waypointsTable (category)
      ''');

      await db.execute('''
        CREATE INDEX idx_statistics_session_id ON $_statisticsTable (session_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_statistics_timestamp ON $_statisticsTable (timestamp)
      ''');

      await db.execute('''
        CREATE INDEX idx_photo_waypoints_waypoint_id ON $_photoWaypointsTable (waypoint_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_photo_waypoints_created_at ON $_photoWaypointsTable (created_at)
      ''');

      await db.execute('''
        CREATE INDEX idx_photo_metadata_photo_waypoint_id ON $_photoMetadataTable (photo_waypoint_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_photo_metadata_key ON $_photoMetadataTable (key)
      ''');

      await db.execute('''
        CREATE INDEX idx_voice_notes_waypoint_id ON $_voiceNotesTable (waypoint_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_voice_notes_created_at ON $_voiceNotesTable (created_at)
      ''');

      // Create imported routes table
      await db.execute('''
        CREATE TABLE $_importedRoutesTable (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          total_distance REAL NOT NULL,
          estimated_duration REAL,
          imported_at INTEGER NOT NULL,
          source_format TEXT NOT NULL,
          metadata TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      // Create route points table
      await db.execute('''
        CREATE TABLE $_routePointsTable (
          id TEXT PRIMARY KEY,
          route_id TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          elevation REAL,
          sequence_number INTEGER NOT NULL,
          timestamp INTEGER,
          FOREIGN KEY (route_id) REFERENCES $_importedRoutesTable (id) ON DELETE CASCADE
        )
      ''');

      // Create route waypoints table
      await db.execute('''
        CREATE TABLE $_routeWaypointsTable (
          id TEXT PRIMARY KEY,
          route_id TEXT NOT NULL,
          name TEXT NOT NULL,
          description TEXT,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          elevation REAL,
          type TEXT,
          properties TEXT,
          FOREIGN KEY (route_id) REFERENCES $_importedRoutesTable (id) ON DELETE CASCADE
        )
      ''');

      // Create indexes for route tables
      await db.execute('''
        CREATE INDEX idx_route_points_route_id ON $_routePointsTable (route_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_route_points_sequence ON $_routePointsTable (route_id, sequence_number)
      ''');

      await db.execute('''
        CREATE INDEX idx_route_waypoints_route_id ON $_routeWaypointsTable (route_id)
      ''');

      // Add imported_route_id to sessions table for route following
      await db.execute('''
        ALTER TABLE $_sessionsTable ADD COLUMN imported_route_id TEXT REFERENCES $_importedRoutesTable(id)
      ''');

      // Create land ownership table
      await db.execute('''
        CREATE TABLE $_landOwnershipTable (
          id TEXT PRIMARY KEY,
          ownership_type TEXT NOT NULL,
          owner_name TEXT NOT NULL,
          agency_name TEXT,
          unit_name TEXT,
          designation TEXT,
          access_type TEXT NOT NULL,
          allowed_uses TEXT,
          restrictions TEXT,
          contact_info TEXT,
          website TEXT,
          fees TEXT,
          seasonal_info TEXT,
          north_bound REAL NOT NULL,
          south_bound REAL NOT NULL,
          east_bound REAL NOT NULL,
          west_bound REAL NOT NULL,
          centroid_latitude REAL NOT NULL,
          centroid_longitude REAL NOT NULL,
          properties TEXT,
          data_source TEXT NOT NULL,
          data_source_date INTEGER,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      // Create spatial indexes for land ownership
      await db.execute('''
        CREATE INDEX idx_land_ownership_bounds
        ON $_landOwnershipTable (north_bound, south_bound, east_bound, west_bound)
      ''');

      await db.execute('''
        CREATE INDEX idx_land_ownership_type
        ON $_landOwnershipTable (ownership_type)
      ''');

      await db.execute('''
        CREATE INDEX idx_land_ownership_centroid
        ON $_landOwnershipTable (centroid_latitude, centroid_longitude)
      ''');

      await db.execute('''
        CREATE INDEX idx_land_ownership_source
        ON $_landOwnershipTable (data_source)
      ''');

      // Create waypoint templates table
      await db.execute('''
        CREATE TABLE $_waypointTemplatesTable (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT NOT NULL,
          waypoint_type TEXT,
          custom_waypoint_type_id TEXT,
          created_at INTEGER NOT NULL,
          user_id TEXT NOT NULL,
          default_name TEXT,
          default_notes TEXT,
          default_color INTEGER,
          custom_fields TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          sort_order INTEGER NOT NULL DEFAULT 0,
          icon_code_point INTEGER,
          icon_font_family TEXT,
          icon_font_package TEXT,
          is_quick_access INTEGER NOT NULL DEFAULT 0,
          tags TEXT
        )
      ''');

      // Create waypoint metadata table  
      await db.execute('''
        CREATE TABLE $_waypointMetadataTable (
          waypoint_id TEXT PRIMARY KEY,
          custom_fields TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          tags TEXT,
          priority TEXT NOT NULL DEFAULT 'normal',
          visibility TEXT NOT NULL DEFAULT 'private',
          weather_conditions TEXT,
          elevation REAL,
          difficulty TEXT,
          estimated_duration INTEGER,
          accessibility_info TEXT,
          safety_notes TEXT,
          best_time_to_visit TEXT,
          equipment TEXT,
          permits TEXT,
          fees TEXT,
          contacts TEXT,
          urls TEXT,
          FOREIGN KEY (waypoint_id) REFERENCES $_enhancedWaypointsTable (id) ON DELETE CASCADE
        )
      ''');

      // Create waypoint relationships table
      await db.execute('''
        CREATE TABLE $_waypointRelationshipsTable (
          id TEXT PRIMARY KEY,
          parent_waypoint_id TEXT NOT NULL,
          child_waypoint_id TEXT NOT NULL,
          relationship_type TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          notes TEXT,
          FOREIGN KEY (parent_waypoint_id) REFERENCES $_enhancedWaypointsTable (id) ON DELETE CASCADE,
          FOREIGN KEY (child_waypoint_id) REFERENCES $_enhancedWaypointsTable (id) ON DELETE CASCADE
        )
      ''');

      // Create waypoint clusters table
      await db.execute('''
        CREATE TABLE $_waypointClustersTable (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          center_latitude REAL NOT NULL,
          center_longitude REAL NOT NULL,
          radius REAL NOT NULL,
          color INTEGER,
          waypoint_ids TEXT NOT NULL
        )
      ''');

      // Create waypoint history table
      await db.execute('''
        CREATE TABLE $_waypointHistoryTable (
          id TEXT PRIMARY KEY,
          waypoint_id TEXT NOT NULL,
          action TEXT NOT NULL,
          changes TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          user_id TEXT,
          FOREIGN KEY (waypoint_id) REFERENCES $_enhancedWaypointsTable (id) ON DELETE CASCADE
        )
      ''');

      // Create waypoint snapshots table
      await db.execute('''
        CREATE TABLE $_waypointSnapshotsTable (
          id TEXT PRIMARY KEY,
          waypoint_id TEXT NOT NULL,
          snapshot_data TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          notes TEXT,
          FOREIGN KEY (waypoint_id) REFERENCES $_enhancedWaypointsTable (id) ON DELETE CASCADE
        )
      ''');

      // Create indexes for waypoint templates
      await db.execute('''
        CREATE INDEX idx_waypoint_templates_user_id ON $_waypointTemplatesTable (user_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_waypoint_templates_active ON $_waypointTemplatesTable (is_active)
      ''');

      await db.execute('''
        CREATE INDEX idx_waypoint_templates_sort_order ON $_waypointTemplatesTable (sort_order)
      ''');

      // Create indexes for waypoint metadata
      await db.execute('''
        CREATE INDEX idx_waypoint_metadata_priority ON $_waypointMetadataTable (priority)
      ''');

      await db.execute('''
        CREATE INDEX idx_waypoint_metadata_visibility ON $_waypointMetadataTable (visibility)
      ''');

      // Create indexes for waypoint relationships
      await db.execute('''
        CREATE INDEX idx_waypoint_relationships_parent ON $_waypointRelationshipsTable (parent_waypoint_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_waypoint_relationships_child ON $_waypointRelationshipsTable (child_waypoint_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_waypoint_relationships_type ON $_waypointRelationshipsTable (relationship_type)
      ''');

      // Create indexes for waypoint clusters
      await db.execute('''
        CREATE INDEX idx_waypoint_clusters_center ON $_waypointClustersTable (center_latitude, center_longitude)
      ''');

      // Create indexes for waypoint history
      await db.execute('''
        CREATE INDEX idx_waypoint_history_waypoint_id ON $_waypointHistoryTable (waypoint_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_waypoint_history_created_at ON $_waypointHistoryTable (created_at)
      ''');

      // Create indexes for waypoint snapshots
      await db.execute('''
        CREATE INDEX idx_waypoint_snapshots_waypoint_id ON $_waypointSnapshotsTable (waypoint_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_waypoint_snapshots_created_at ON $_waypointSnapshotsTable (created_at)
      ''');

      // Create planned routes table
      await db.execute('''
        CREATE TABLE $_plannedRoutesTable (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          created_at INTEGER NOT NULL,
          total_distance REAL NOT NULL DEFAULT 0.0,
          total_duration INTEGER NOT NULL DEFAULT 0,
          total_elevation_gain REAL NOT NULL DEFAULT 0.0,
          difficulty INTEGER NOT NULL DEFAULT 1,
          algorithm TEXT NOT NULL,
          route_data TEXT NOT NULL,
          waypoint_ids TEXT NOT NULL
        )
      ''');

      // Create indexes for planned routes
      await db.execute('''
        CREATE INDEX idx_planned_routes_created_at ON $_plannedRoutesTable (created_at)
      ''');

      await db.execute('''
        CREATE INDEX idx_planned_routes_difficulty ON $_plannedRoutesTable (difficulty)
      ''');

      // Create treasure hunts table
      await db.execute('''
        CREATE TABLE $_treasureHuntsTable (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          author TEXT,
          description TEXT,
          status TEXT NOT NULL DEFAULT 'active',
          cover_image_path TEXT,
          tags TEXT,
          created_at TEXT NOT NULL,
          started_at TEXT,
          completed_at TEXT,
          sort_order INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Create hunt documents table
      await db.execute('''
        CREATE TABLE $_huntDocumentsTable (
          id TEXT PRIMARY KEY,
          hunt_id TEXT NOT NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          file_path TEXT,
          url TEXT,
          content TEXT,
          thumbnail_path TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          sort_order INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (hunt_id) REFERENCES $_treasureHuntsTable (id) ON DELETE CASCADE
        )
      ''');

      // Create hunt session links table
      await db.execute('''
        CREATE TABLE $_huntSessionLinksTable (
          id TEXT PRIMARY KEY,
          hunt_id TEXT NOT NULL,
          session_id TEXT NOT NULL,
          notes TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (hunt_id) REFERENCES $_treasureHuntsTable (id) ON DELETE CASCADE,
          FOREIGN KEY (session_id) REFERENCES $_sessionsTable (id) ON DELETE CASCADE
        )
      ''');

      // Create hunt locations table
      await db.execute('''
        CREATE TABLE $_huntLocationsTable (
          id TEXT PRIMARY KEY,
          hunt_id TEXT NOT NULL,
          name TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          notes TEXT,
          status TEXT NOT NULL DEFAULT 'potential',
          created_at TEXT NOT NULL,
          searched_at TEXT,
          sort_order INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (hunt_id) REFERENCES $_treasureHuntsTable (id) ON DELETE CASCADE
        )
      ''');

      // Create indexes for treasure hunts
      await db.execute('''
        CREATE INDEX idx_treasure_hunts_status ON $_treasureHuntsTable (status)
      ''');

      await db.execute('''
        CREATE INDEX idx_treasure_hunts_created_at ON $_treasureHuntsTable (created_at)
      ''');

      await db.execute('''
        CREATE INDEX idx_hunt_documents_hunt_id ON $_huntDocumentsTable (hunt_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_hunt_documents_type ON $_huntDocumentsTable (type)
      ''');

      await db.execute('''
        CREATE INDEX idx_hunt_session_links_hunt_id ON $_huntSessionLinksTable (hunt_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_hunt_session_links_session_id ON $_huntSessionLinksTable (session_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_hunt_locations_hunt_id ON $_huntLocationsTable (hunt_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_hunt_locations_status ON $_huntLocationsTable (status)
      ''');

      // Create custom markers table
      await db.execute('''
        CREATE TABLE $_customMarkersTable (
          id TEXT PRIMARY KEY,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          name TEXT NOT NULL,
          notes TEXT,
          category TEXT NOT NULL,
          color_argb INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          session_id TEXT,
          hunt_id TEXT,
          share_status TEXT NOT NULL DEFAULT 'private',
          community_id TEXT,
          shared_at INTEGER,
          metadata TEXT,
          FOREIGN KEY (session_id) REFERENCES $_sessionsTable (id) ON DELETE SET NULL,
          FOREIGN KEY (hunt_id) REFERENCES $_treasureHuntsTable (id) ON DELETE SET NULL
        )
      ''');

      // Create marker attachments table
      await db.execute('''
        CREATE TABLE $_markerAttachmentsTable (
          id TEXT PRIMARY KEY,
          marker_id TEXT NOT NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          file_path TEXT,
          url TEXT,
          content TEXT,
          thumbnail_path TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER,
          sort_order INTEGER DEFAULT 0,
          file_size INTEGER,
          user_rotation INTEGER,
          width INTEGER,
          height INTEGER,
          device_pitch REAL,
          device_roll REAL,
          device_yaw REAL,
          photo_orientation TEXT,
          camera_tilt_angle REAL,
          source TEXT,
          FOREIGN KEY (marker_id) REFERENCES $_customMarkersTable (id) ON DELETE CASCADE
        )
      ''');

      // Create indexes for custom markers
      await db.execute('''
        CREATE INDEX idx_custom_markers_category ON $_customMarkersTable (category)
      ''');

      await db.execute('''
        CREATE INDEX idx_custom_markers_coords ON $_customMarkersTable (latitude, longitude)
      ''');

      await db.execute('''
        CREATE INDEX idx_custom_markers_hunt_id ON $_customMarkersTable (hunt_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_custom_markers_created_at ON $_customMarkersTable (created_at)
      ''');

      await db.execute('''
        CREATE INDEX idx_custom_markers_session_id ON $_customMarkersTable (session_id)
      ''');

      // Create indexes for marker attachments
      await db.execute('''
        CREATE INDEX idx_marker_attachments_marker_id ON $_markerAttachmentsTable (marker_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_marker_attachments_type ON $_markerAttachmentsTable (type)
      ''');

      // ============ Achievement & Statistics Tables (v14) ============

      // Create achievements table (stores achievement definitions)
      await db.execute('''
        CREATE TABLE $_achievementsTable (
          id TEXT PRIMARY KEY,
          category TEXT NOT NULL,
          difficulty TEXT NOT NULL,
          name TEXT NOT NULL,
          description TEXT NOT NULL,
          icon_name TEXT NOT NULL,
          requirement_type TEXT NOT NULL,
          requirement_value REAL NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      ''');

      // Create user achievements table (tracks user progress)
      await db.execute('''
        CREATE TABLE $_userAchievementsTable (
          id TEXT PRIMARY KEY,
          achievement_id TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'locked',
          current_progress REAL NOT NULL DEFAULT 0,
          unlocked_at INTEGER,
          completed_at INTEGER,
          FOREIGN KEY (achievement_id) REFERENCES $_achievementsTable (id) ON DELETE CASCADE
        )
      ''');

      // Create explored states table (tracks states visited from GPS)
      await db.execute('''
        CREATE TABLE $_exploredStatesTable (
          id TEXT PRIMARY KEY,
          state_code TEXT NOT NULL UNIQUE,
          state_name TEXT NOT NULL,
          first_visited_at INTEGER NOT NULL,
          last_visited_at INTEGER NOT NULL,
          session_count INTEGER NOT NULL DEFAULT 1,
          total_distance REAL NOT NULL DEFAULT 0,
          total_duration INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Create lifetime statistics table (single row for aggregate stats)
      await db.execute('''
        CREATE TABLE $_lifetimeStatisticsTable (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          total_distance REAL NOT NULL DEFAULT 0,
          total_duration INTEGER NOT NULL DEFAULT 0,
          total_sessions INTEGER NOT NULL DEFAULT 0,
          total_waypoints INTEGER NOT NULL DEFAULT 0,
          total_photos INTEGER NOT NULL DEFAULT 0,
          total_voice_notes INTEGER NOT NULL DEFAULT 0,
          total_hunts_created INTEGER NOT NULL DEFAULT 0,
          total_hunts_solved INTEGER NOT NULL DEFAULT 0,
          total_elevation_gain REAL NOT NULL DEFAULT 0,
          states_explored INTEGER NOT NULL DEFAULT 0,
          current_streak INTEGER NOT NULL DEFAULT 0,
          longest_streak INTEGER NOT NULL DEFAULT 0,
          last_activity_date TEXT,
          pr_longest_session_distance REAL,
          pr_longest_session_duration INTEGER,
          pr_most_elevation_gain REAL,
          pr_longest_session_id TEXT,
          pr_elevation_session_id TEXT,
          updated_at INTEGER NOT NULL
        )
      ''');

      // Create session streaks table (tracks daily activity for streaks)
      await db.execute('''
        CREATE TABLE $_sessionStreaksTable (
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL UNIQUE,
          session_count INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL
        )
      ''');

      // Create indexes for achievement tables
      await db.execute('''
        CREATE INDEX idx_achievements_category ON $_achievementsTable (category)
      ''');

      await db.execute('''
        CREATE INDEX idx_user_achievements_status ON $_userAchievementsTable (status)
      ''');

      await db.execute('''
        CREATE INDEX idx_user_achievements_achievement_id ON $_userAchievementsTable (achievement_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_explored_states_code ON $_exploredStatesTable (state_code)
      ''');

      await db.execute('''
        CREATE INDEX idx_session_streaks_date ON $_sessionStreaksTable (date)
      ''');

      // Create journal entries table (v15)
      await db.execute('''
        CREATE TABLE $_journalEntriesTable (
          id TEXT PRIMARY KEY,
          title TEXT,
          content TEXT NOT NULL,
          entry_type TEXT NOT NULL DEFAULT 'note',
          session_id TEXT,
          hunt_id TEXT,
          latitude REAL,
          longitude REAL,
          location_name TEXT,
          timestamp INTEGER NOT NULL,
          mood TEXT,
          weather_notes TEXT,
          tags TEXT,
          is_pinned INTEGER NOT NULL DEFAULT 0,
          is_highlight INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER,
          FOREIGN KEY (session_id) REFERENCES $_sessionsTable (id) ON DELETE SET NULL,
          FOREIGN KEY (hunt_id) REFERENCES $_treasureHuntsTable (id) ON DELETE SET NULL
        )
      ''');

      // Create indexes for journal entries
      await db.execute('''
        CREATE INDEX idx_journal_entries_session ON $_journalEntriesTable (session_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_journal_entries_hunt ON $_journalEntriesTable (hunt_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_journal_entries_timestamp ON $_journalEntriesTable (timestamp DESC)
      ''');

      await db.execute('''
        CREATE INDEX idx_journal_entries_type ON $_journalEntriesTable (entry_type)
      ''');

      debugPrint('Database tables created successfully');
    } catch (e) {
      debugPrint('Error creating database tables: $e');
      rethrow;
    }
  }

  /// Check if a column exists in a table
  Future<bool> _columnExists(Database db, String table, String column) async {
    final result = await db.rawQuery('PRAGMA table_info($table)');
    return result.any((row) => row['name'] == column);
  }

  /// Safely add a column to a table (only if it doesn't already exist)
  Future<void> _addColumnIfNotExists(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    if (!await _columnExists(db, table, column)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  /// Upgrade database schema from old version to new version
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 Upgrading database from version $oldVersion to $newVersion');

    try {
      // Version 1 -> 2: Add orientation metadata to photo_waypoints table
      if (oldVersion < 2) {
        debugPrint('📸 Adding orientation metadata columns to photo_waypoints table...');

        // Add new columns for device orientation (safely)
        await _addColumnIfNotExists(db, _photoWaypointsTable, 'device_pitch', 'REAL');
        await _addColumnIfNotExists(db, _photoWaypointsTable, 'device_roll', 'REAL');
        await _addColumnIfNotExists(db, _photoWaypointsTable, 'device_yaw', 'REAL');
        await _addColumnIfNotExists(db, _photoWaypointsTable, 'photo_orientation', 'TEXT');
        await _addColumnIfNotExists(db, _photoWaypointsTable, 'camera_tilt_angle', 'REAL');

        debugPrint('✅ Successfully added orientation metadata columns');
      }

      // Version 2 -> 3: Add treasure hunts tables
      if (oldVersion < 3) {
        debugPrint('📦 Adding treasure hunts tables...');

        // Create treasure hunts table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_treasureHuntsTable (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            author TEXT,
            description TEXT,
            status TEXT NOT NULL DEFAULT 'active',
            cover_image_path TEXT,
            tags TEXT,
            created_at TEXT NOT NULL,
            started_at TEXT,
            completed_at TEXT,
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // Create hunt documents table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_huntDocumentsTable (
            id TEXT PRIMARY KEY,
            hunt_id TEXT NOT NULL,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            file_path TEXT,
            url TEXT,
            content TEXT,
            thumbnail_path TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT,
            sort_order INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (hunt_id) REFERENCES $_treasureHuntsTable (id) ON DELETE CASCADE
          )
        ''');

        // Create hunt session links table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_huntSessionLinksTable (
            id TEXT PRIMARY KEY,
            hunt_id TEXT NOT NULL,
            session_id TEXT NOT NULL,
            notes TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (hunt_id) REFERENCES $_treasureHuntsTable (id) ON DELETE CASCADE,
            FOREIGN KEY (session_id) REFERENCES $_sessionsTable (id) ON DELETE CASCADE
          )
        ''');

        // Create hunt locations table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_huntLocationsTable (
            id TEXT PRIMARY KEY,
            hunt_id TEXT NOT NULL,
            name TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            notes TEXT,
            status TEXT NOT NULL DEFAULT 'potential',
            created_at TEXT NOT NULL,
            searched_at TEXT,
            sort_order INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (hunt_id) REFERENCES $_treasureHuntsTable (id) ON DELETE CASCADE
          )
        ''');

        // Create indexes
        await db.execute('CREATE INDEX IF NOT EXISTS idx_treasure_hunts_status ON $_treasureHuntsTable (status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_treasure_hunts_created_at ON $_treasureHuntsTable (created_at)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_hunt_documents_hunt_id ON $_huntDocumentsTable (hunt_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_hunt_documents_type ON $_huntDocumentsTable (type)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_hunt_session_links_hunt_id ON $_huntSessionLinksTable (hunt_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_hunt_session_links_session_id ON $_huntSessionLinksTable (session_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_hunt_locations_hunt_id ON $_huntLocationsTable (hunt_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_hunt_locations_status ON $_huntLocationsTable (status)');

        debugPrint('✅ Successfully added treasure hunts tables');
      }

      // Version 3 -> 4: Add real-time tracking stats columns to sessions table
      if (oldVersion < 4) {
        debugPrint('📊 Adding real-time tracking stats columns to sessions table...');

        // Add elevation tracking columns (safely)
        await _addColumnIfNotExists(db, _sessionsTable, 'elevation_gain', 'REAL NOT NULL DEFAULT 0.0');
        await _addColumnIfNotExists(db, _sessionsTable, 'elevation_loss', 'REAL NOT NULL DEFAULT 0.0');
        await _addColumnIfNotExists(db, _sessionsTable, 'max_altitude', 'REAL');
        await _addColumnIfNotExists(db, _sessionsTable, 'min_altitude', 'REAL');

        // Add speed tracking column (safely)
        await _addColumnIfNotExists(db, _sessionsTable, 'max_speed', 'REAL');

        debugPrint('✅ Successfully added real-time tracking stats columns');
      }

      // Version 4 -> 5: Add hunt_id column to sessions table for hunt association
      if (oldVersion < 5) {
        debugPrint('🎯 Adding hunt_id column to sessions table...');

        await _addColumnIfNotExists(db, _sessionsTable, 'hunt_id', 'TEXT');

        // Create index for faster hunt-based queries
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sessions_hunt_id ON $_sessionsTable (hunt_id)'
        );

        debugPrint('✅ Successfully added hunt_id column to sessions table');
      }

      // Version 5 -> 6: Add source column to photo_waypoints table for Meta glasses support
      if (oldVersion < 6) {
        debugPrint('📸 Adding source column to photo_waypoints table...');

        await _addColumnIfNotExists(db, _photoWaypointsTable, 'source', 'TEXT');

        debugPrint('✅ Successfully added source column to photo_waypoints table');
      }

      // Version 6 -> 7: Add custom markers and marker attachments tables
      if (oldVersion < 7) {
        debugPrint('📍 Adding custom markers tables...');

        // Create custom markers table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_customMarkersTable (
            id TEXT PRIMARY KEY,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            name TEXT NOT NULL,
            notes TEXT,
            category TEXT NOT NULL,
            color_argb INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hunt_id TEXT,
            share_status TEXT NOT NULL DEFAULT 'private',
            community_id TEXT,
            shared_at INTEGER,
            metadata TEXT,
            FOREIGN KEY (hunt_id) REFERENCES $_treasureHuntsTable (id) ON DELETE SET NULL
          )
        ''');

        // Create marker attachments table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_markerAttachmentsTable (
            id TEXT PRIMARY KEY,
            marker_id TEXT NOT NULL,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            file_path TEXT,
            url TEXT,
            content TEXT,
            thumbnail_path TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER,
            sort_order INTEGER DEFAULT 0,
            file_size INTEGER,
            user_rotation INTEGER,
            width INTEGER,
            height INTEGER,
            device_pitch REAL,
            device_roll REAL,
            device_yaw REAL,
            photo_orientation TEXT,
            camera_tilt_angle REAL,
            source TEXT,
            FOREIGN KEY (marker_id) REFERENCES $_customMarkersTable (id) ON DELETE CASCADE
          )
        ''');

        // Create indexes for custom markers
        await db.execute('CREATE INDEX IF NOT EXISTS idx_custom_markers_category ON $_customMarkersTable (category)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_custom_markers_coords ON $_customMarkersTable (latitude, longitude)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_custom_markers_hunt_id ON $_customMarkersTable (hunt_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_custom_markers_created_at ON $_customMarkersTable (created_at)');

        // Create indexes for marker attachments
        await db.execute('CREATE INDEX IF NOT EXISTS idx_marker_attachments_marker_id ON $_markerAttachmentsTable (marker_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_marker_attachments_type ON $_markerAttachmentsTable (type)');

        debugPrint('✅ Successfully added custom markers tables');
      }

      // Version 7 -> 8: Make session_id nullable for standalone waypoints
      // and add category column
      if (oldVersion < 8) {
        debugPrint('📍 Migrating waypoints table for standalone waypoint support...');

        // SQLite doesn't support ALTER COLUMN to remove NOT NULL constraint,
        // so we need to recreate the table. However, since existing data already
        // has session_id values, we can simply add the new category column.
        // New standalone waypoints will insert NULL for session_id.
        // The NOT NULL constraint only affects INSERTs, not existing rows.

        // For a proper migration, we'll recreate the waypoints table.
        // First, create a new table with nullable session_id
        await db.execute('''
          CREATE TABLE waypoints_new (
            id TEXT PRIMARY KEY,
            session_id TEXT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            type TEXT NOT NULL,
            category TEXT,
            timestamp INTEGER NOT NULL,
            name TEXT,
            notes TEXT,
            altitude REAL,
            accuracy REAL,
            speed REAL,
            heading REAL,
            FOREIGN KEY (session_id) REFERENCES $_sessionsTable (id) ON DELETE CASCADE
          )
        ''');

        // Copy existing data
        await db.execute('''
          INSERT INTO waypoints_new (id, session_id, latitude, longitude, type, timestamp, name, notes, altitude, accuracy, speed, heading)
          SELECT id, session_id, latitude, longitude, type, timestamp, name, notes, altitude, accuracy, speed, heading
          FROM $_waypointsTable
        ''');

        // Drop old table
        await db.execute('DROP TABLE $_waypointsTable');

        // Rename new table
        await db.execute('ALTER TABLE waypoints_new RENAME TO $_waypointsTable');

        // Recreate indexes
        await db.execute('CREATE INDEX idx_waypoints_session_id ON $_waypointsTable (session_id)');
        await db.execute('CREATE INDEX idx_waypoints_timestamp ON $_waypointsTable (timestamp)');
        await db.execute('CREATE INDEX idx_waypoints_type ON $_waypointsTable (type)');

        // Add index for standalone waypoints (where session_id is NULL)
        await db.execute('CREATE INDEX idx_waypoints_standalone ON $_waypointsTable (session_id) WHERE session_id IS NULL');

        // Add index for category
        await db.execute('CREATE INDEX idx_waypoints_category ON $_waypointsTable (category)');

        debugPrint('✅ Successfully migrated waypoints table for standalone support');
      }

      // Version 8 -> 9: Add session_id column to custom_markers table
      if (oldVersion < 9) {
        debugPrint('📍 Adding session_id column to custom_markers table...');

        await _addColumnIfNotExists(db, _customMarkersTable, 'session_id', 'TEXT');

        // Create index for session-based queries
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_custom_markers_session_id ON $_customMarkersTable (session_id)'
        );

        debugPrint('✅ Successfully added session_id column to custom_markers table');
      }

      // Version 9 -> 10: Migrate photo_waypoints to custom_markers + marker_attachments
      if (oldVersion < 10) {
        debugPrint('📸 Migrating photo_waypoints to custom_markers system...');

        // Query all photo_waypoints with their waypoint data (for location and session)
        final List<Map<String, dynamic>> photoWaypoints = await db.rawQuery('''
          SELECT
            pw.id as photo_id,
            pw.waypoint_id,
            pw.file_path,
            pw.thumbnail_path,
            pw.created_at,
            pw.file_size,
            pw.width,
            pw.height,
            pw.device_pitch,
            pw.device_roll,
            pw.device_yaw,
            pw.photo_orientation,
            pw.camera_tilt_angle,
            pw.source,
            w.latitude,
            w.longitude,
            w.session_id,
            w.name as waypoint_name,
            w.notes as waypoint_notes
          FROM $_photoWaypointsTable pw
          INNER JOIN $_waypointsTable w ON pw.waypoint_id = w.id
        ''');

        debugPrint('📸 Found ${photoWaypoints.length} photo waypoints to migrate');

        int migratedCount = 0;
        for (final photoData in photoWaypoints) {
          try {
            final String markerId = photoData['photo_id'] as String;
            final double latitude = photoData['latitude'] as double;
            final double longitude = photoData['longitude'] as double;
            final String? sessionId = photoData['session_id'] as String?;
            final int createdAt = photoData['created_at'] as int;
            final String? waypointName = photoData['waypoint_name'] as String?;
            final String? waypointNotes = photoData['waypoint_notes'] as String?;

            // Create custom marker with 'photo' category
            // Use the photo's ID as the marker ID to maintain uniqueness
            await db.insert(
              _customMarkersTable,
              {
                'id': markerId,
                'latitude': latitude,
                'longitude': longitude,
                'name': waypointName ?? 'Photo',
                'notes': waypointNotes,
                'category': 'photo',
                'color_argb': 0xFF2196F3, // Blue color for photos
                'created_at': createdAt,
                'updated_at': createdAt,
                'session_id': sessionId,
                'share_status': 'private',
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );

            // Create marker attachment for the photo
            final String attachmentId = '${markerId}_img';
            await db.insert(
              _markerAttachmentsTable,
              {
                'id': attachmentId,
                'marker_id': markerId,
                'name': waypointName ?? 'Photo',
                'type': 'image',
                'file_path': photoData['file_path'],
                'thumbnail_path': photoData['thumbnail_path'],
                'created_at': createdAt,
                'file_size': photoData['file_size'],
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );

            migratedCount++;
          } catch (e) {
            debugPrint('⚠️ Failed to migrate photo waypoint ${photoData['photo_id']}: $e');
            // Continue with other photos
          }
        }

        debugPrint('✅ Successfully migrated $migratedCount photo waypoints to custom markers');
      }

      // Version 10 -> 11: Add user_rotation column to marker_attachments table
      if (oldVersion < 11) {
        debugPrint('🔄 Adding user_rotation column to marker_attachments table...');
        await _addColumnIfNotExists(db, _markerAttachmentsTable, 'user_rotation', 'INTEGER');
        debugPrint('✅ Successfully added user_rotation column to marker_attachments table');
      }

      // Version 11 -> 12: Add device orientation columns to marker_attachments
      // AND ensure all photo_waypoints are migrated to custom_markers (in case v10 was skipped)
      if (oldVersion < 12) {
        debugPrint('📸 V12 Migration: Adding device orientation columns and ensuring photo_waypoints are migrated...');

        // Add new columns for device orientation data (safely, in case they already exist)
        await _addColumnIfNotExists(db, _markerAttachmentsTable, 'width', 'INTEGER');
        await _addColumnIfNotExists(db, _markerAttachmentsTable, 'height', 'INTEGER');
        await _addColumnIfNotExists(db, _markerAttachmentsTable, 'device_pitch', 'REAL');
        await _addColumnIfNotExists(db, _markerAttachmentsTable, 'device_roll', 'REAL');
        await _addColumnIfNotExists(db, _markerAttachmentsTable, 'device_yaw', 'REAL');
        await _addColumnIfNotExists(db, _markerAttachmentsTable, 'photo_orientation', 'TEXT');
        await _addColumnIfNotExists(db, _markerAttachmentsTable, 'camera_tilt_angle', 'REAL');
        await _addColumnIfNotExists(db, _markerAttachmentsTable, 'source', 'TEXT');

        // CRITICAL: Check for unmigrated photo_waypoints (v10 migration may have been skipped)
        // Query all photo_waypoints that DON'T have a corresponding custom_marker
        debugPrint('📸 Checking for unmigrated photo_waypoints...');

        final List<Map<String, dynamic>> unmigratedPhotos = await db.rawQuery('''
          SELECT
            pw.id as photo_id,
            pw.waypoint_id,
            pw.file_path,
            pw.thumbnail_path,
            pw.created_at,
            pw.file_size,
            pw.width,
            pw.height,
            pw.device_pitch,
            pw.device_roll,
            pw.device_yaw,
            pw.photo_orientation,
            pw.camera_tilt_angle,
            pw.source,
            w.latitude,
            w.longitude,
            w.session_id,
            w.name as waypoint_name,
            w.notes as waypoint_notes
          FROM $_photoWaypointsTable pw
          INNER JOIN $_waypointsTable w ON pw.waypoint_id = w.id
          WHERE NOT EXISTS (
            SELECT 1 FROM $_customMarkersTable cm WHERE cm.id = pw.id
          )
        ''');

        debugPrint('📸 Found ${unmigratedPhotos.length} unmigrated photo_waypoints');

        int migratedCount = 0;
        for (final photoData in unmigratedPhotos) {
          try {
            final String markerId = photoData['photo_id'] as String;
            final double latitude = photoData['latitude'] as double;
            final double longitude = photoData['longitude'] as double;
            final String? sessionId = photoData['session_id'] as String?;
            final int createdAt = photoData['created_at'] as int;
            final String? waypointName = photoData['waypoint_name'] as String?;
            final String? waypointNotes = photoData['waypoint_notes'] as String?;

            // Create custom marker with 'photo' category
            await db.insert(
              _customMarkersTable,
              {
                'id': markerId,
                'latitude': latitude,
                'longitude': longitude,
                'name': waypointName ?? 'Photo',
                'notes': waypointNotes,
                'category': 'photo',
                'color_argb': 0xFF9C27B0, // Purple color for photos
                'created_at': createdAt,
                'updated_at': createdAt,
                'session_id': sessionId,
                'share_status': 'private',
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );

            // Create marker attachment with ALL device orientation data
            final String attachmentId = '${markerId}_img';
            await db.insert(
              _markerAttachmentsTable,
              {
                'id': attachmentId,
                'marker_id': markerId,
                'name': waypointName ?? 'Photo',
                'type': 'image',
                'file_path': photoData['file_path'],
                'thumbnail_path': photoData['thumbnail_path'],
                'created_at': createdAt,
                'file_size': photoData['file_size'],
                'width': photoData['width'],
                'height': photoData['height'],
                'device_pitch': photoData['device_pitch'],
                'device_roll': photoData['device_roll'],
                'device_yaw': photoData['device_yaw'],
                'photo_orientation': photoData['photo_orientation'],
                'camera_tilt_angle': photoData['camera_tilt_angle'],
                'source': photoData['source'],
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );

            migratedCount++;
          } catch (e) {
            debugPrint('⚠️ Failed to migrate photo waypoint ${photoData['photo_id']}: $e');
          }
        }

        if (migratedCount > 0) {
          debugPrint('✅ Successfully migrated $migratedCount previously unmigrated photo_waypoints');
        }

        // Also backfill device orientation data for any photos that were migrated by v10
        // but didn't get the new orientation columns
        debugPrint('📸 Backfilling device orientation data for previously migrated photos...');

        final List<Map<String, dynamic>> allPhotoWaypoints = await db.rawQuery('''
          SELECT
            id,
            width,
            height,
            device_pitch,
            device_roll,
            device_yaw,
            photo_orientation,
            camera_tilt_angle,
            source
          FROM $_photoWaypointsTable
        ''');

        int backfilledCount = 0;
        for (final pw in allPhotoWaypoints) {
          try {
            final String attachmentId = '${pw['id']}_img';
            final int count = await db.update(
              _markerAttachmentsTable,
              {
                'width': pw['width'],
                'height': pw['height'],
                'device_pitch': pw['device_pitch'],
                'device_roll': pw['device_roll'],
                'device_yaw': pw['device_yaw'],
                'photo_orientation': pw['photo_orientation'],
                'camera_tilt_angle': pw['camera_tilt_angle'],
                'source': pw['source'],
              },
              where: 'id = ?',
              whereArgs: [attachmentId],
            );
            if (count > 0) backfilledCount++;
          } catch (e) {
            debugPrint('⚠️ Failed to backfill orientation for ${pw['id']}: $e');
          }
        }

        debugPrint('✅ V12 Migration complete: $migratedCount new migrations, $backfilledCount backfills');
      }

      // Version 12 -> 13: Ensure ALL photo_waypoints are migrated (for users who were already at v12)
      if (oldVersion == 12) {
        debugPrint('📸 V13 Migration: Ensuring all photo_waypoints are migrated...');

        // Query all photo_waypoints that DON'T have a corresponding custom_marker
        final List<Map<String, dynamic>> unmigratedPhotos = await db.rawQuery('''
          SELECT
            pw.id as photo_id,
            pw.waypoint_id,
            pw.file_path,
            pw.thumbnail_path,
            pw.created_at,
            pw.file_size,
            pw.width,
            pw.height,
            pw.device_pitch,
            pw.device_roll,
            pw.device_yaw,
            pw.photo_orientation,
            pw.camera_tilt_angle,
            pw.source,
            w.latitude,
            w.longitude,
            w.session_id,
            w.name as waypoint_name,
            w.notes as waypoint_notes
          FROM $_photoWaypointsTable pw
          INNER JOIN $_waypointsTable w ON pw.waypoint_id = w.id
          WHERE NOT EXISTS (
            SELECT 1 FROM $_customMarkersTable cm WHERE cm.id = pw.id
          )
        ''');

        debugPrint('📸 Found ${unmigratedPhotos.length} unmigrated photo_waypoints');

        int migratedCount = 0;
        for (final photoData in unmigratedPhotos) {
          try {
            final String markerId = photoData['photo_id'] as String;
            final double latitude = photoData['latitude'] as double;
            final double longitude = photoData['longitude'] as double;
            final String? sessionId = photoData['session_id'] as String?;
            final int createdAt = photoData['created_at'] as int;
            final String? waypointName = photoData['waypoint_name'] as String?;
            final String? waypointNotes = photoData['waypoint_notes'] as String?;

            // Create custom marker with 'photo' category
            await db.insert(
              _customMarkersTable,
              {
                'id': markerId,
                'latitude': latitude,
                'longitude': longitude,
                'name': waypointName ?? 'Photo',
                'notes': waypointNotes,
                'category': 'photo',
                'color_argb': 0xFF9C27B0, // Purple color for photos
                'created_at': createdAt,
                'updated_at': createdAt,
                'session_id': sessionId,
                'share_status': 'private',
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );

            // Create marker attachment with ALL device orientation data
            final String attachmentId = '${markerId}_img';
            await db.insert(
              _markerAttachmentsTable,
              {
                'id': attachmentId,
                'marker_id': markerId,
                'name': waypointName ?? 'Photo',
                'type': 'image',
                'file_path': photoData['file_path'],
                'thumbnail_path': photoData['thumbnail_path'],
                'created_at': createdAt,
                'file_size': photoData['file_size'],
                'width': photoData['width'],
                'height': photoData['height'],
                'device_pitch': photoData['device_pitch'],
                'device_roll': photoData['device_roll'],
                'device_yaw': photoData['device_yaw'],
                'photo_orientation': photoData['photo_orientation'],
                'camera_tilt_angle': photoData['camera_tilt_angle'],
                'source': photoData['source'],
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );

            migratedCount++;
          } catch (e) {
            debugPrint('⚠️ Failed to migrate photo waypoint ${photoData['photo_id']}: $e');
          }
        }

        debugPrint('✅ V13 Migration complete: migrated $migratedCount photo_waypoints');
      }

      // Version 13 -> 14: Add achievement and statistics tables
      if (oldVersion < 14) {
        debugPrint('🏆 V14 Migration: Adding achievement and statistics tables...');

        // Create achievements table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_achievementsTable (
            id TEXT PRIMARY KEY,
            category TEXT NOT NULL,
            difficulty TEXT NOT NULL,
            name TEXT NOT NULL,
            description TEXT NOT NULL,
            icon_name TEXT NOT NULL,
            requirement_type TEXT NOT NULL,
            requirement_value REAL NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');

        // Create user achievements table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_userAchievementsTable (
            id TEXT PRIMARY KEY,
            achievement_id TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'locked',
            current_progress REAL NOT NULL DEFAULT 0,
            unlocked_at INTEGER,
            completed_at INTEGER,
            FOREIGN KEY (achievement_id) REFERENCES $_achievementsTable (id) ON DELETE CASCADE
          )
        ''');

        // Create explored states table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_exploredStatesTable (
            id TEXT PRIMARY KEY,
            state_code TEXT NOT NULL UNIQUE,
            state_name TEXT NOT NULL,
            first_visited_at INTEGER NOT NULL,
            last_visited_at INTEGER NOT NULL,
            session_count INTEGER NOT NULL DEFAULT 1,
            total_distance REAL NOT NULL DEFAULT 0,
            total_duration INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // Create lifetime statistics table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_lifetimeStatisticsTable (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            total_distance REAL NOT NULL DEFAULT 0,
            total_duration INTEGER NOT NULL DEFAULT 0,
            total_sessions INTEGER NOT NULL DEFAULT 0,
            total_waypoints INTEGER NOT NULL DEFAULT 0,
            total_photos INTEGER NOT NULL DEFAULT 0,
            total_voice_notes INTEGER NOT NULL DEFAULT 0,
            total_hunts_created INTEGER NOT NULL DEFAULT 0,
            total_hunts_solved INTEGER NOT NULL DEFAULT 0,
            total_elevation_gain REAL NOT NULL DEFAULT 0,
            states_explored INTEGER NOT NULL DEFAULT 0,
            current_streak INTEGER NOT NULL DEFAULT 0,
            longest_streak INTEGER NOT NULL DEFAULT 0,
            last_activity_date TEXT,
            pr_longest_session_distance REAL,
            pr_longest_session_duration INTEGER,
            pr_most_elevation_gain REAL,
            pr_longest_session_id TEXT,
            pr_elevation_session_id TEXT,
            updated_at INTEGER NOT NULL
          )
        ''');

        // Create session streaks table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_sessionStreaksTable (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL UNIQUE,
            session_count INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL
          )
        ''');

        // Create indexes
        await db.execute('CREATE INDEX IF NOT EXISTS idx_achievements_category ON $_achievementsTable (category)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_user_achievements_status ON $_userAchievementsTable (status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_user_achievements_achievement_id ON $_userAchievementsTable (achievement_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_explored_states_code ON $_exploredStatesTable (state_code)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_session_streaks_date ON $_sessionStreaksTable (date)');

        // Initialize lifetime statistics with a single row (will be populated by service)
        await db.execute('''
          INSERT OR IGNORE INTO $_lifetimeStatisticsTable (id, updated_at)
          VALUES (1, ${DateTime.now().millisecondsSinceEpoch})
        ''');

        debugPrint('✅ V14 Migration complete: achievement and statistics tables created');
      }

      // Version 14 -> 15: Add journal entries table
      if (oldVersion < 15) {
        debugPrint('📓 V15 Migration: Adding journal entries table...');

        // Create journal entries table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_journalEntriesTable (
            id TEXT PRIMARY KEY,
            title TEXT,
            content TEXT NOT NULL,
            entry_type TEXT NOT NULL DEFAULT 'note',
            session_id TEXT,
            hunt_id TEXT,
            latitude REAL,
            longitude REAL,
            location_name TEXT,
            timestamp INTEGER NOT NULL,
            mood TEXT,
            weather_notes TEXT,
            tags TEXT,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            is_highlight INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER,
            FOREIGN KEY (session_id) REFERENCES $_sessionsTable (id) ON DELETE SET NULL,
            FOREIGN KEY (hunt_id) REFERENCES $_treasureHuntsTable (id) ON DELETE SET NULL
          )
        ''');

        // Create indexes
        await db.execute('CREATE INDEX IF NOT EXISTS idx_journal_entries_session ON $_journalEntriesTable (session_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_journal_entries_hunt ON $_journalEntriesTable (hunt_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_journal_entries_timestamp ON $_journalEntriesTable (timestamp DESC)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_journal_entries_type ON $_journalEntriesTable (entry_type)');

        debugPrint('✅ V15 Migration complete: journal entries table created');
      }

      debugPrint('✅ Database upgrade completed successfully');
    } catch (e) {
      debugPrint('❌ Error upgrading database: $e');
      rethrow;
    }
  }

  /// Session Operations

  /// Insert a new tracking session
  Future<void> insertSession(TrackingSession session) async {
    try {
      final Database db = await database;
      await db.insert(
        _sessionsTable,
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted session: ${session.id}');
    } catch (e) {
      debugPrint('Error inserting session: $e');
      rethrow;
    }
  }

  /// Update an existing tracking session
  Future<void> updateSession(TrackingSession session) async {
    try {
      final Database db = await database;
      final int count = await db.update(
        _sessionsTable,
        session.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[session.id],
      );
      if (count == 0) {
        throw Exception('Session not found: ${session.id}');
      }
      debugPrint('Updated session: ${session.id}');
    } catch (e) {
      debugPrint('Error updating session: $e');
      rethrow;
    }
  }

  /// Get a session by ID
  Future<TrackingSession?> getSession(String sessionId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _sessionsTable,
        where: 'id = ?',
        whereArgs: <Object?>[sessionId],
      );

      if (maps.isNotEmpty) {
        return TrackingSession.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting session: $e');
      rethrow;
    }
  }

  /// Get all sessions, ordered by creation date (newest first)
  /// Dynamically calculates breadcrumb count from breadcrumbs table (single source of truth)
  Future<List<TrackingSession>> getAllSessions({
    int? limit,
    int? offset,
  }) async {
    try {
      final Database db = await database;

      // Use LEFT JOIN to get actual breadcrumb count from breadcrumbs table
      // This avoids sync issues with cached counts
      final String limitClause = limit != null ? 'LIMIT $limit' : '';
      final String offsetClause = offset != null ? 'OFFSET $offset' : '';

      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT s.*,
               COALESCE(COUNT(b.id), 0) as breadcrumb_count
        FROM $_sessionsTable s
        LEFT JOIN $_breadcrumbsTable b ON s.id = b.session_id
        GROUP BY s.id
        ORDER BY s.created_at DESC
        $limitClause $offsetClause
      ''');

      return maps.map(TrackingSession.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting all sessions: $e');
      rethrow;
    }
  }

  /// Get sessions by status
  Future<List<TrackingSession>> getSessionsByStatus(
      SessionStatus status) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _sessionsTable,
        where: 'status = ?',
        whereArgs: <Object?>[status.name],
        orderBy: 'created_at DESC',
      );

      return maps.map(TrackingSession.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting sessions by status: $e');
      rethrow;
    }
  }

  /// Delete a session and all its breadcrumbs
  Future<void> deleteSession(String sessionId) async {
    try {
      final Database db = await database;

      // Delete breadcrumbs first (foreign key constraint)
      await db.delete(
        _breadcrumbsTable,
        where: 'session_id = ?',
        whereArgs: <Object?>[sessionId],
      );

      // Delete session
      final int count = await db.delete(
        _sessionsTable,
        where: 'id = ?',
        whereArgs: <Object?>[sessionId],
      );

      if (count == 0) {
        throw Exception('Session not found: $sessionId');
      }

      debugPrint('Deleted session: $sessionId');
    } catch (e) {
      debugPrint('Error deleting session: $e');
      rethrow;
    }
  }

  /// Breadcrumb Operations

  /// Insert a new breadcrumb
  /// Note: Breadcrumb count is calculated dynamically in getAllSessions()
  Future<void> insertBreadcrumb(Breadcrumb breadcrumb) async {
    try {
      final Database db = await database;
      await db.insert(
        _breadcrumbsTable,
        breadcrumb.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted breadcrumb: ${breadcrumb.id}');
    } catch (e) {
      debugPrint('Error inserting breadcrumb: $e');
      rethrow;
    }
  }

  /// Insert multiple breadcrumbs in a batch
  /// Note: Breadcrumb count is calculated dynamically in getAllSessions()
  Future<void> insertBreadcrumbs(List<Breadcrumb> breadcrumbs) async {
    try {
      final Database db = await database;
      final Batch batch = db.batch();

      for (final Breadcrumb breadcrumb in breadcrumbs) {
        batch.insert(
          _breadcrumbsTable,
          breadcrumb.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      debugPrint('Inserted ${breadcrumbs.length} breadcrumbs');
    } catch (e) {
      debugPrint('Error inserting breadcrumbs: $e');
      rethrow;
    }
  }

  /// Get all breadcrumbs for a session, ordered by timestamp
  Future<List<Breadcrumb>> getBreadcrumbsForSession(String sessionId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _breadcrumbsTable,
        where: 'session_id = ?',
        whereArgs: <Object?>[sessionId],
        orderBy: 'timestamp ASC',
      );

      return maps.map(Breadcrumb.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting breadcrumbs for session: $e');
      rethrow;
    }
  }

  /// Get breadcrumbs for a session within a time range
  Future<List<Breadcrumb>> getBreadcrumbsInTimeRange({
    required String sessionId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _breadcrumbsTable,
        where: 'session_id = ? AND timestamp >= ? AND timestamp <= ?',
        whereArgs: <Object?>[
          sessionId,
          startTime.millisecondsSinceEpoch,
          endTime.millisecondsSinceEpoch,
        ],
        orderBy: 'timestamp ASC',
      );

      return maps.map(Breadcrumb.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting breadcrumbs in time range: $e');
      rethrow;
    }
  }

  /// Delete all breadcrumbs for a session
  Future<void> deleteBreadcrumbsForSession(String sessionId) async {
    try {
      final Database db = await database;
      await db.delete(
        _breadcrumbsTable,
        where: 'session_id = ?',
        whereArgs: <Object?>[sessionId],
      );
      debugPrint('Deleted breadcrumbs for session: $sessionId');
    } catch (e) {
      debugPrint('Error deleting breadcrumbs for session: $e');
      rethrow;
    }
  }

  /// Waypoint Operations

  /// Insert a new waypoint
  Future<void> insertWaypoint(Waypoint waypoint) async {
    try {
      final Database db = await database;
      await db.insert(
        _waypointsTable,
        waypoint.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted waypoint: ${waypoint.id}');
    } catch (e) {
      debugPrint('Error inserting waypoint: $e');
      rethrow;
    }
  }

  /// Update an existing waypoint
  Future<void> updateWaypoint(Waypoint waypoint) async {
    try {
      final Database db = await database;
      final int count = await db.update(
        _waypointsTable,
        waypoint.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[waypoint.id],
      );
      if (count == 0) {
        throw Exception('Waypoint not found: ${waypoint.id}');
      }
      debugPrint('Updated waypoint: ${waypoint.id}');
    } catch (e) {
      debugPrint('Error updating waypoint: $e');
      rethrow;
    }
  }

  /// Get a waypoint by ID
  Future<Waypoint?> getWaypoint(String waypointId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _waypointsTable,
        where: 'id = ?',
        whereArgs: <Object?>[waypointId],
      );

      if (maps.isNotEmpty) {
        return Waypoint.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting waypoint: $e');
      rethrow;
    }
  }

  /// Get all waypoints for a session, ordered by timestamp
  Future<List<Waypoint>> getWaypointsForSession(String sessionId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _waypointsTable,
        where: 'session_id = ?',
        whereArgs: <Object?>[sessionId],
        orderBy: 'timestamp ASC',
      );

      return maps.map(Waypoint.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting waypoints for session: $e');
      rethrow;
    }
  }

  /// Get waypoints by type for a session
  Future<List<Waypoint>> getWaypointsByType({
    required String sessionId,
    required WaypointType type,
  }) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _waypointsTable,
        where: 'session_id = ? AND type = ?',
        whereArgs: <Object?>[sessionId, type.name],
        orderBy: 'timestamp ASC',
      );

      return maps.map(Waypoint.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting waypoints by type: $e');
      rethrow;
    }
  }

  /// Get waypoints within a geographic area (bounding box)
  Future<List<Waypoint>> getWaypointsInArea({
    required String sessionId,
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
  }) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _waypointsTable,
        where: '''
          session_id = ? AND
          latitude >= ? AND latitude <= ? AND
          longitude >= ? AND longitude <= ?
        ''',
        whereArgs: <Object?>[
          sessionId,
          minLatitude,
          maxLatitude,
          minLongitude,
          maxLongitude,
        ],
        orderBy: 'timestamp ASC',
      );

      return maps.map(Waypoint.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting waypoints in area: $e');
      rethrow;
    }
  }

  /// Delete a waypoint
  Future<void> deleteWaypoint(String waypointId) async {
    try {
      final Database db = await database;
      final int count = await db.delete(
        _waypointsTable,
        where: 'id = ?',
        whereArgs: <Object?>[waypointId],
      );

      if (count == 0) {
        throw Exception('Waypoint not found: $waypointId');
      }
    } catch (e) {
      throw Exception('Failed to delete waypoint: $e');
    }
  }

  /// Delete all waypoints for a session
  Future<void> deleteWaypointsForSession(String sessionId) async {
    try {
      final Database db = await database;
      await db.delete(
        _waypointsTable,
        where: 'session_id = ?',
        whereArgs: <Object?>[sessionId],
      );
      debugPrint('Deleted waypoints for session: $sessionId');
    } catch (e) {
      debugPrint('Error deleting waypoints for session: $e');
      rethrow;
    }
  }

  /// Session Statistics Operations

  /// Insert or update session statistics
  Future<void> saveSessionStatistics(SessionStatistics statistics) async {
    try {
      final Database db = await database;

      // Convert waypoints by type map to JSON string
      final Map<String, dynamic> statisticsMap = statistics.toMap();
      statisticsMap['waypoints_by_type'] =
          statisticsMap['waypoints_by_type'].toString();

      await db.insert(
        _statisticsTable,
        statisticsMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('Saved statistics for session: ${statistics.sessionId}');
    } catch (e) {
      debugPrint('Error saving session statistics: $e');
      rethrow;
    }
  }

  /// Get latest statistics for a session
  Future<SessionStatistics?> getLatestSessionStatistics(
      String sessionId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _statisticsTable,
        where: 'session_id = ?',
        whereArgs: <Object?>[sessionId],
        orderBy: 'timestamp DESC',
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final Map<String, dynamic> map = maps.first;
        // Parse waypoints by type JSON string back to map
        if (map['waypoints_by_type'] is String) {
          try {
            // Simple parsing for basic map format
            final String jsonStr = map['waypoints_by_type'] as String;
            final Map<String, int> waypointsByType = <String, int>{};
            if (jsonStr != '{}') {
              // Basic parsing - in production, use proper JSON parsing
              final RegExp exp = RegExp(r'(\w+): (\d+)');
              final Iterable<RegExpMatch> matches = exp.allMatches(jsonStr);
              for (final RegExpMatch match in matches) {
                waypointsByType[match.group(1)!] = int.parse(match.group(2)!);
              }
            }
            map['waypoints_by_type'] = waypointsByType;
          } on Exception {
            map['waypoints_by_type'] = <String, int>{};
          }
        }
        return SessionStatistics.fromMap(map);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting latest session statistics: $e');
      rethrow;
    }
  }

  /// Get all statistics for a session, ordered by timestamp
  Future<List<SessionStatistics>> getSessionStatistics(String sessionId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _statisticsTable,
        where: 'session_id = ?',
        whereArgs: <Object?>[sessionId],
        orderBy: 'timestamp ASC',
      );

      return maps.map((Map<String, dynamic> map) {
        // Parse waypoints by type JSON string back to map
        if (map['waypoints_by_type'] is String) {
          try {
            final String jsonStr = map['waypoints_by_type'] as String;
            final Map<String, int> waypointsByType = <String, int>{};
            if (jsonStr != '{}') {
              final RegExp exp = RegExp(r'(\w+): (\d+)');
              final Iterable<RegExpMatch> matches = exp.allMatches(jsonStr);
              for (final RegExpMatch match in matches) {
                waypointsByType[match.group(1)!] = int.parse(match.group(2)!);
              }
            }
            map['waypoints_by_type'] = waypointsByType;
          } on Exception {
            map['waypoints_by_type'] = <String, int>{};
          }
        }
        return SessionStatistics.fromMap(map);
      }).toList();
    } catch (e) {
      debugPrint('Error getting session statistics: $e');
      rethrow;
    }
  }

  /// Delete all statistics for a session
  Future<void> deleteSessionStatistics(String sessionId) async {
    try {
      final Database db = await database;
      await db.delete(
        _statisticsTable,
        where: 'session_id = ?',
        whereArgs: <Object?>[sessionId],
      );
      debugPrint('Deleted statistics for session: $sessionId');
    } catch (e) {
      debugPrint('Error deleting session statistics: $e');
      rethrow;
    }
  }

  /// Clean up old statistics (keep only latest N entries per session)
  Future<void> cleanupOldStatistics({int keepCount = 100}) async {
    try {
      final Database db = await database;

      // Get all session IDs
      final List<Map<String, dynamic>> sessions = await db.query(
        _statisticsTable,
        columns: <String>['DISTINCT session_id'],
      );

      for (final Map<String, dynamic> session in sessions) {
        final String sessionId = session['session_id'] as String;

        // Get statistics for this session, ordered by timestamp DESC
        final List<Map<String, dynamic>> stats = await db.query(
          _statisticsTable,
          where: 'session_id = ?',
          whereArgs: <Object?>[sessionId],
          orderBy: 'timestamp DESC',
        );

        // Delete old entries if we have more than keepCount
        if (stats.length > keepCount) {
          final List<int> idsToDelete = stats
              .skip(keepCount)
              .map((Map<String, dynamic> stat) => stat['id'] as int)
              .toList();

          for (final int id in idsToDelete) {
            await db.delete(
              _statisticsTable,
              where: 'id = ?',
              whereArgs: <Object?>[id],
            );
          }
        }
      }

      debugPrint('Cleaned up old statistics, keeping $keepCount per session');
    } catch (e) {
      debugPrint('Error cleaning up old statistics: $e');
      rethrow;
    }
  }

  /// Voice Note Operations

  /// Insert a new voice note
  Future<void> insertVoiceNote(VoiceNote voiceNote) async {
    try {
      final Database db = await database;
      await db.insert(
        _voiceNotesTable,
        voiceNote.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted voice note: ${voiceNote.id}');
    } catch (e) {
      debugPrint('Error inserting voice note: $e');
      rethrow;
    }
  }

  /// Update an existing voice note
  Future<void> updateVoiceNote(VoiceNote voiceNote) async {
    try {
      final Database db = await database;
      final int count = await db.update(
        _voiceNotesTable,
        voiceNote.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[voiceNote.id],
      );
      if (count == 0) {
        throw Exception('Voice note not found: ${voiceNote.id}');
      }
      debugPrint('Updated voice note: ${voiceNote.id}');
    } catch (e) {
      debugPrint('Error updating voice note: $e');
      rethrow;
    }
  }

  /// Get a voice note by ID
  Future<VoiceNote?> getVoiceNote(String voiceNoteId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _voiceNotesTable,
        where: 'id = ?',
        whereArgs: <Object?>[voiceNoteId],
      );

      if (maps.isNotEmpty) {
        return VoiceNote.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting voice note: $e');
      rethrow;
    }
  }

  /// Get all voice notes for a waypoint, ordered by creation date
  Future<List<VoiceNote>> getVoiceNotesForWaypoint(String waypointId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _voiceNotesTable,
        where: 'waypoint_id = ?',
        whereArgs: <Object?>[waypointId],
        orderBy: 'created_at ASC',
      );

      return maps.map(VoiceNote.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting voice notes for waypoint: $e');
      rethrow;
    }
  }

  /// Get all voice notes for a session (via waypoints)
  Future<List<VoiceNote>> getVoiceNotesForSession(String sessionId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT vn.* FROM $_voiceNotesTable vn
        INNER JOIN $_waypointsTable w ON vn.waypoint_id = w.id
        WHERE w.session_id = ?
        ORDER BY vn.created_at ASC
      ''', <Object?>[sessionId]);

      return maps.map(VoiceNote.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting voice notes for session: $e');
      rethrow;
    }
  }

  /// Count voice notes for a session (for achievement tracking)
  Future<int> countVoiceNotesForSession(String sessionId) async {
    try {
      final Database db = await database;
      final result = Sqflite.firstIntValue(
        await db.rawQuery('''
          SELECT COUNT(*) FROM $_voiceNotesTable vn
          INNER JOIN $_waypointsTable w ON vn.waypoint_id = w.id
          WHERE w.session_id = ?
        ''', <Object?>[sessionId]),
      );
      return result ?? 0;
    } catch (e) {
      debugPrint('Error counting voice notes for session: $e');
      return 0;
    }
  }

  /// Count photo attachments for a session (for achievement tracking)
  ///
  /// Photos are stored as MarkerAttachments on CustomMarkers linked to sessions.
  Future<int> countPhotosForSession(String sessionId) async {
    try {
      final Database db = await database;
      final result = Sqflite.firstIntValue(
        await db.rawQuery('''
          SELECT COUNT(*) FROM $_markerAttachmentsTable ma
          INNER JOIN $_customMarkersTable cm ON ma.marker_id = cm.id
          WHERE cm.session_id = ? AND ma.type = 'image'
        ''', <Object?>[sessionId]),
      );
      return result ?? 0;
    } catch (e) {
      debugPrint('Error counting photos for session: $e');
      return 0;
    }
  }

  /// Delete a voice note
  Future<void> deleteVoiceNote(String voiceNoteId) async {
    try {
      final Database db = await database;
      final int count = await db.delete(
        _voiceNotesTable,
        where: 'id = ?',
        whereArgs: <Object?>[voiceNoteId],
      );

      if (count == 0) {
        throw Exception('Voice note not found: $voiceNoteId');
      }

      debugPrint('Deleted voice note: $voiceNoteId');
    } catch (e) {
      debugPrint('Error deleting voice note: $e');
      rethrow;
    }
  }

  /// Delete all voice notes for a waypoint
  Future<void> deleteVoiceNotesForWaypoint(String waypointId) async {
    try {
      final Database db = await database;
      await db.delete(
        _voiceNotesTable,
        where: 'waypoint_id = ?',
        whereArgs: <Object?>[waypointId],
      );
      debugPrint('Deleted voice notes for waypoint: $waypointId');
    } catch (e) {
      debugPrint('Error deleting voice notes for waypoint: $e');
      rethrow;
    }
  }

  /// Delete all voice notes for a session (via waypoints)
  Future<void> deleteVoiceNotesForSession(String sessionId) async {
    try {
      final Database db = await database;
      await db.rawDelete('''
        DELETE FROM $_voiceNotesTable
        WHERE waypoint_id IN (
          SELECT id FROM $_waypointsTable WHERE session_id = ?
        )
      ''', <Object?>[sessionId]);
      debugPrint('Deleted voice notes for session: $sessionId');
    } catch (e) {
      debugPrint('Error deleting voice notes for session: $e');
      rethrow;
    }
  }

  /// Imported Route Operations

  /// Insert an imported route with all its points and waypoints
  Future<void> insertImportedRoute(ImportedRoute route) async {
    try {
      final Database db = await database;

      await db.transaction((txn) async {
        // Insert the route
        await txn.insert(_importedRoutesTable, route.toDatabaseRow());

        // Insert route points
        for (final point in route.points) {
          await txn.insert(_routePointsTable, point.toDatabaseRow());
        }

        // Insert route waypoints
        for (final waypoint in route.waypoints) {
          await txn.insert(_routeWaypointsTable, waypoint.toDatabaseRow());
        }
      });

      debugPrint('Inserted imported route: ${route.id} (${route.name})');
    } catch (e) {
      debugPrint('Error inserting imported route: $e');
      rethrow;
    }
  }

  /// Get all imported routes (without points and waypoints for performance)
  Future<List<ImportedRoute>> getImportedRoutes() async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        _importedRoutesTable,
        orderBy: 'imported_at DESC',
      );

      return results.map(ImportedRoute.fromDatabase).toList();
    } catch (e) {
      debugPrint('Error getting imported routes: $e');
      rethrow;
    }
  }

  /// Get a specific imported route with all its points and waypoints
  Future<ImportedRoute?> getImportedRouteById(String routeId) async {
    try {
      final Database db = await database;

      // Get the route
      final List<Map<String, dynamic>> routeResults = await db.query(
        _importedRoutesTable,
        where: 'id = ?',
        whereArgs: [routeId],
      );

      if (routeResults.isEmpty) {
        return null;
      }

      final route = ImportedRoute.fromDatabase(routeResults.first);

      // Get route points
      final List<Map<String, dynamic>> pointResults = await db.query(
        _routePointsTable,
        where: 'route_id = ?',
        whereArgs: [routeId],
        orderBy: 'sequence_number ASC',
      );

      final points =
          pointResults.map(RoutePoint.fromDatabase).toList();

      // Get route waypoints
      final List<Map<String, dynamic>> waypointResults = await db.query(
        _routeWaypointsTable,
        where: 'route_id = ?',
        whereArgs: [routeId],
      );

      final waypoints = waypointResults
          .map(RouteWaypoint.fromDatabase)
          .toList();

      return route.copyWith(
        points: points,
        waypoints: waypoints,
      );
    } catch (e) {
      debugPrint('Error getting imported route: $e');
      rethrow;
    }
  }

  /// Get route points for a specific route
  Future<List<RoutePoint>> getRoutePoints(String routeId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        _routePointsTable,
        where: 'route_id = ?',
        whereArgs: [routeId],
        orderBy: 'sequence_number ASC',
      );

      return results.map(RoutePoint.fromDatabase).toList();
    } catch (e) {
      debugPrint('Error getting route points: $e');
      rethrow;
    }
  }

  /// Get route waypoints for a specific route
  Future<List<RouteWaypoint>> getRouteWaypoints(String routeId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        _routeWaypointsTable,
        where: 'route_id = ?',
        whereArgs: [routeId],
      );

      return results.map(RouteWaypoint.fromDatabase).toList();
    } catch (e) {
      debugPrint('Error getting route waypoints: $e');
      rethrow;
    }
  }

  /// Update imported route metadata
  Future<void> updateImportedRoute(ImportedRoute route) async {
    try {
      final Database db = await database;
      await db.update(
        _importedRoutesTable,
        route.toDatabaseRow(),
        where: 'id = ?',
        whereArgs: [route.id],
      );
      debugPrint('Updated imported route: ${route.id}');
    } catch (e) {
      debugPrint('Error updating imported route: $e');
      rethrow;
    }
  }

  /// Delete an imported route and all its data
  Future<void> deleteImportedRoute(String routeId) async {
    try {
      final Database db = await database;

      await db.transaction((txn) async {
        // Delete route waypoints
        await txn.delete(
          _routeWaypointsTable,
          where: 'route_id = ?',
          whereArgs: [routeId],
        );

        // Delete route points
        await txn.delete(
          _routePointsTable,
          where: 'route_id = ?',
          whereArgs: [routeId],
        );

        // Delete the route
        await txn.delete(
          _importedRoutesTable,
          where: 'id = ?',
          whereArgs: [routeId],
        );
      });

      debugPrint('Deleted imported route: $routeId');
    } catch (e) {
      debugPrint('Error deleting imported route: $e');
      rethrow;
    }
  }

  /// Check if a session is following an imported route
  Future<String?> getSessionImportedRouteId(String sessionId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        _sessionsTable,
        columns: ['imported_route_id'],
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      if (results.isNotEmpty) {
        return results.first['imported_route_id'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting session route ID: $e');
      rethrow;
    }
  }

  /// Update the imported route ID for a session
  Future<void> updateSessionImportedRouteId(
      String sessionId, String? routeId) async {
    try {
      final Database db = await database;
      await db.update(
        _sessionsTable,
        {'imported_route_id': routeId},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      debugPrint('Updated session $sessionId route ID to: $routeId');
    } catch (e) {
      debugPrint('Error updating session route ID: $e');
      rethrow;
    }
  }

  /// Utility Operations

  /// Get the database file path
  Future<String> getDatabasePath() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, _databaseName);
  }

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    try {
      final Database db = await database;

      final int sessionCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $_sessionsTable'),
          ) ??
          0;

      final int breadcrumbCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $_breadcrumbsTable'),
          ) ??
          0;

      final int waypointCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $_waypointsTable'),
          ) ??
          0;

      return <String, int>{
        'sessions': sessionCount,
        'breadcrumbs': breadcrumbCount,
        'waypoints': waypointCount,
      };
    } catch (e) {
      debugPrint('Error getting database stats: $e');
      rethrow;
    }
  }

    /// Waypoint Template Operations

  /// Insert a waypoint template
  Future<void> insertWaypointTemplate(WaypointTemplate template) async {
    try {
      final Database db = await database;
      await db.insert(
        _waypointTemplatesTable,
        template.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted waypoint template: ${template.id}');
    } catch (e) {
      debugPrint('Error inserting waypoint template: $e');
      rethrow;
    }
  }

  /// Get a waypoint template by ID
  Future<WaypointTemplate?> getWaypointTemplate(String templateId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        _waypointTemplatesTable,
        where: 'id = ?',
        whereArgs: [templateId],
      );

      if (results.isNotEmpty) {
        return WaypointTemplate.fromMap(results.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting waypoint template: $e');
      rethrow;
    }
  }

  /// Get all waypoint templates for a user
  Future<List<WaypointTemplate>> getWaypointTemplates({String? userId}) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results;
      
      if (userId != null) {
        results = await db.query(
          _waypointTemplatesTable,
          where: 'user_id = ? AND is_active = 1',
          whereArgs: [userId],
          orderBy: 'sort_order ASC, name ASC',
        );
      } else {
        results = await db.query(
          _waypointTemplatesTable,
          where: 'is_active = 1',
          orderBy: 'sort_order ASC, name ASC',
        );
      }

      return results.map(WaypointTemplate.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting waypoint templates: $e');
      rethrow;
    }
  }

  /// Waypoint Metadata Operations

  /// Insert waypoint metadata
  Future<void> insertWaypointMetadata(WaypointMetadata metadata) async {
    try {
      final Database db = await database;
      await db.insert(
        _waypointMetadataTable,
        metadata.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted waypoint metadata for: ${metadata.waypointId}');
    } catch (e) {
      debugPrint('Error inserting waypoint metadata: $e');
      rethrow;
    }
  }

  /// Get waypoint metadata by waypoint ID
  Future<WaypointMetadata?> getWaypointMetadata(String waypointId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        _waypointMetadataTable,
        where: 'waypoint_id = ?',
        whereArgs: [waypointId],
      );

      if (results.isNotEmpty) {
        return WaypointMetadata.fromMap(results.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting waypoint metadata: $e');
      rethrow;
    }
  }

  /// Waypoint Relationship Operations

  /// Insert waypoint relationship
  Future<void> insertWaypointRelationship({
    required String parentWaypointId,
    required String childWaypointId,
    required String relationshipType,
    String? notes,
  }) async {
    try {
      final Database db = await database;
      final String relationshipId = DateTime.now().millisecondsSinceEpoch.toString();
      
      await db.insert(
        _waypointRelationshipsTable,
        {
          'id': relationshipId,
          'parent_waypoint_id': parentWaypointId,
          'child_waypoint_id': childWaypointId,
          'relationship_type': relationshipType,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'notes': notes,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted waypoint relationship: $relationshipId');
    } catch (e) {
      debugPrint('Error inserting waypoint relationship: $e');
      rethrow;
    }
  }

  /// Get waypoint relationships
  Future<List<Map<String, dynamic>>> getWaypointRelationships(String waypointId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        _waypointRelationshipsTable,
        where: 'parent_waypoint_id = ? OR child_waypoint_id = ?',
        whereArgs: [waypointId, waypointId],
        orderBy: 'created_at ASC',
      );

      return results;
    } catch (e) {
      debugPrint('Error getting waypoint relationships: $e');
      rethrow;
    }
  }

  /// Waypoint Cluster Operations

  /// Insert waypoint cluster
  Future<void> insertWaypointCluster({
    required String name,
    required String description,
    required double centerLatitude,
    required double centerLongitude,
    required double radius,
    required List<String> waypointIds,
    int? color,
  }) async {
    try {
      final Database db = await database;
      final String clusterId = DateTime.now().millisecondsSinceEpoch.toString();
      
      await db.insert(
        _waypointClustersTable,
        {
          'id': clusterId,
          'name': name,
          'description': description,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'center_latitude': centerLatitude,
          'center_longitude': centerLongitude,
          'radius': radius,
          'color': color,
          'waypoint_ids': waypointIds.join(','),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted waypoint cluster: $clusterId');
    } catch (e) {
      debugPrint('Error inserting waypoint cluster: $e');
      rethrow;
    }
  }

  /// Waypoint History Operations

  /// Insert waypoint history entry
  Future<void> insertWaypointHistoryEntry({
    required String waypointId,
    required String action,
    required Map<String, dynamic> changes,
    String? userId,
  }) async {
    try {
      final Database db = await database;
      final String historyId = DateTime.now().millisecondsSinceEpoch.toString();
      
      await db.insert(
        _waypointHistoryTable,
        {
          'id': historyId,
          'waypoint_id': waypointId,
          'action': action,
          'changes': changes.toString(),
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'user_id': userId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted waypoint history entry: $historyId');
    } catch (e) {
      debugPrint('Error inserting waypoint history entry: $e');
      rethrow;
    }
  }

  /// Waypoint Snapshot Operations

  /// Insert waypoint snapshot
  Future<void> insertWaypointSnapshot({
    required String waypointId,
    required Map<String, dynamic> snapshotData,
    String? notes,
  }) async {
    try {
      final Database db = await database;
      final String snapshotId = DateTime.now().millisecondsSinceEpoch.toString();
      
      await db.insert(
        _waypointSnapshotsTable,
        {
          'id': snapshotId,
          'waypoint_id': waypointId,
          'snapshot_data': snapshotData.toString(),
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'notes': notes,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted waypoint snapshot: $snapshotId');
    } catch (e) {
      debugPrint('Error inserting waypoint snapshot: $e');
      rethrow;
    }
  }

/// Clear all data (for testing or factory reset)
  Future<void> clearAllData() async {
    try {
      final Database db = await database;
      await db.delete(_waypointsTable);
      await db.delete(_breadcrumbsTable);
      await db.delete(_sessionsTable);
      debugPrint('Cleared all database data');
    } catch (e) {
      debugPrint('Error clearing database data: $e');
      rethrow;
    }
  }

  /// Planned Route Operations

  /// Insert a planned route
  Future<void> insertPlannedRoute(Map<String, dynamic> routeData) async {
    try {
      final Database db = await database;
      await db.insert(
        _plannedRoutesTable,
        routeData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted planned route: ${routeData['name']}');
    } catch (e) {
      debugPrint('Error inserting planned route: $e');
      rethrow;
    }
  }

  /// Get all planned routes
  Future<List<Map<String, dynamic>>> getPlannedRoutes() async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        _plannedRoutesTable,
        orderBy: 'created_at DESC',
      );
      return results;
    } catch (e) {
      debugPrint('Error getting planned routes: $e');
      rethrow;
    }
  }

  /// Get a specific planned route by ID
  Future<Map<String, dynamic>?> getPlannedRoute(String id) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        _plannedRoutesTable,
        where: 'id = ?',
        whereArgs: [id],
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint('Error getting planned route: $e');
      rethrow;
    }
  }

  /// Update a planned route
  Future<void> updatePlannedRoute(Map<String, dynamic> routeData) async {
    try {
      final Database db = await database;
      await db.update(
        _plannedRoutesTable,
        routeData,
        where: 'id = ?',
        whereArgs: [routeData['id']],
      );
      debugPrint('Updated planned route: ${routeData['name']}');
    } catch (e) {
      debugPrint('Error updating planned route: $e');
      rethrow;
    }
  }

  /// Delete a planned route
  Future<void> deletePlannedRoute(String id) async {
    try {
      final Database db = await database;
      await db.delete(
        _plannedRoutesTable,
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('Deleted planned route: $id');
    } catch (e) {
      debugPrint('Error deleting planned route: $e');
      rethrow;
    }
  }

  /// Link a planned route to a session
  Future<void> linkRouteToSession(String routeId, String sessionId) async {
    try {
      final Database db = await database;
      await db.update(
        _sessionsTable,
        {'planned_route_id': routeId},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      debugPrint('Linked route $routeId to session $sessionId');
    } catch (e) {
      debugPrint('Error linking route to session: $e');
      rethrow;
    }
  }

  /// Get sessions using a specific planned route
  Future<List<TrackingSession>> getSessionsByRoute(String routeId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        _sessionsTable,
        where: 'planned_route_id = ?',
        whereArgs: [routeId],
        orderBy: 'created_at DESC',
      );
      return results.map(TrackingSession.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting sessions by route: $e');
      rethrow;
    }
  }

  // ============================================================
  // TREASURE HUNT OPERATIONS
  // ============================================================

  /// Insert a new treasure hunt
  Future<void> insertTreasureHunt(TreasureHunt hunt) async {
    try {
      final Database db = await database;
      await db.insert(
        _treasureHuntsTable,
        hunt.toDatabaseMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted treasure hunt: ${hunt.id} (${hunt.name})');
    } catch (e) {
      debugPrint('Error inserting treasure hunt: $e');
      rethrow;
    }
  }

  /// Update an existing treasure hunt
  Future<void> updateTreasureHunt(TreasureHunt hunt) async {
    try {
      final Database db = await database;
      final map = hunt.toDatabaseMap();
      debugPrint('DB updateTreasureHunt: "${hunt.name}" coverImagePath=${map['cover_image_path']}');
      final int count = await db.update(
        _treasureHuntsTable,
        map,
        where: 'id = ?',
        whereArgs: [hunt.id],
      );
      if (count == 0) {
        throw Exception('Treasure hunt not found: ${hunt.id}');
      }
      debugPrint('DB updateTreasureHunt: Updated ${hunt.id}');
    } catch (e) {
      debugPrint('Error updating treasure hunt: $e');
      rethrow;
    }
  }

  /// Get a treasure hunt by ID
  Future<TreasureHunt?> getTreasureHunt(String huntId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        _treasureHuntsTable,
        where: 'id = ?',
        whereArgs: [huntId],
      );

      if (results.isNotEmpty) {
        return TreasureHunt.fromDatabaseMap(results.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting treasure hunt: $e');
      rethrow;
    }
  }

  /// Get all treasure hunts, ordered by sort_order then created_at
  Future<List<TreasureHunt>> getAllTreasureHunts({HuntStatus? status}) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results;

      if (status != null) {
        results = await db.query(
          _treasureHuntsTable,
          where: 'status = ?',
          whereArgs: [status.name],
          orderBy: 'sort_order ASC, created_at DESC',
        );
      } else {
        results = await db.query(
          _treasureHuntsTable,
          orderBy: 'sort_order ASC, created_at DESC',
        );
      }

      final hunts = results.map(TreasureHunt.fromDatabaseMap).toList();
      // Debug: Log what we're returning from DB
      for (final hunt in hunts) {
        debugPrint('DB getAllTreasureHunts: "${hunt.name}" coverImagePath=${hunt.coverImagePath}');
      }
      return hunts;
    } catch (e) {
      debugPrint('Error getting all treasure hunts: $e');
      rethrow;
    }
  }

  /// Delete a treasure hunt and all its associated data
  Future<void> deleteTreasureHunt(String huntId) async {
    try {
      final Database db = await database;

      await db.transaction((txn) async {
        // Delete hunt locations
        await txn.delete(
          _huntLocationsTable,
          where: 'hunt_id = ?',
          whereArgs: [huntId],
        );

        // Delete hunt session links
        await txn.delete(
          _huntSessionLinksTable,
          where: 'hunt_id = ?',
          whereArgs: [huntId],
        );

        // Delete hunt documents
        await txn.delete(
          _huntDocumentsTable,
          where: 'hunt_id = ?',
          whereArgs: [huntId],
        );

        // Delete the hunt itself
        await txn.delete(
          _treasureHuntsTable,
          where: 'id = ?',
          whereArgs: [huntId],
        );
      });

      debugPrint('Deleted treasure hunt: $huntId');
    } catch (e) {
      debugPrint('Error deleting treasure hunt: $e');
      rethrow;
    }
  }

  // ============================================================
  // HUNT DOCUMENT OPERATIONS
  // ============================================================

  /// Insert a new hunt document
  Future<void> insertHuntDocument(HuntDocument document) async {
    try {
      final Database db = await database;
      await db.insert(
        _huntDocumentsTable,
        document.toDatabaseMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted hunt document: ${document.id} (${document.name})');
    } catch (e) {
      debugPrint('Error inserting hunt document: $e');
      rethrow;
    }
  }

  /// Update an existing hunt document
  Future<void> updateHuntDocument(HuntDocument document) async {
    try {
      final Database db = await database;
      final int count = await db.update(
        _huntDocumentsTable,
        document.toDatabaseMap(),
        where: 'id = ?',
        whereArgs: [document.id],
      );
      if (count == 0) {
        throw Exception('Hunt document not found: ${document.id}');
      }
      debugPrint('Updated hunt document: ${document.id}');
    } catch (e) {
      debugPrint('Error updating hunt document: $e');
      rethrow;
    }
  }

  /// Get all documents for a hunt
  Future<List<HuntDocument>> getHuntDocuments(String huntId, {HuntDocumentType? type}) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results;

      if (type != null) {
        results = await db.query(
          _huntDocumentsTable,
          where: 'hunt_id = ? AND type = ?',
          whereArgs: [huntId, type.name],
          orderBy: 'sort_order ASC, created_at DESC',
        );
      } else {
        results = await db.query(
          _huntDocumentsTable,
          where: 'hunt_id = ?',
          whereArgs: [huntId],
          orderBy: 'sort_order ASC, created_at DESC',
        );
      }

      return results.map(HuntDocument.fromDatabaseMap).toList();
    } catch (e) {
      debugPrint('Error getting hunt documents: $e');
      rethrow;
    }
  }

  /// Delete a hunt document
  Future<void> deleteHuntDocument(String documentId) async {
    try {
      final Database db = await database;
      await db.delete(
        _huntDocumentsTable,
        where: 'id = ?',
        whereArgs: [documentId],
      );
      debugPrint('Deleted hunt document: $documentId');
    } catch (e) {
      debugPrint('Error deleting hunt document: $e');
      rethrow;
    }
  }

  // ============================================================
  // HUNT SESSION LINK OPERATIONS
  // ============================================================

  /// Link a session to a hunt
  Future<void> insertHuntSessionLink(HuntSessionLink link) async {
    try {
      final Database db = await database;
      await db.insert(
        _huntSessionLinksTable,
        link.toDatabaseMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Linked session ${link.sessionId} to hunt ${link.huntId}');
    } catch (e) {
      debugPrint('Error inserting hunt session link: $e');
      rethrow;
    }
  }

  /// Get all session links for a hunt
  Future<List<HuntSessionLink>> getHuntSessionLinks(String huntId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        _huntSessionLinksTable,
        where: 'hunt_id = ?',
        whereArgs: [huntId],
        orderBy: 'created_at DESC',
      );

      return results.map(HuntSessionLink.fromDatabaseMap).toList();
    } catch (e) {
      debugPrint('Error getting hunt session links: $e');
      rethrow;
    }
  }

  /// Get hunts linked to a session
  Future<List<String>> getHuntsForSession(String sessionId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        _huntSessionLinksTable,
        columns: ['hunt_id'],
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      return results.map((r) => r['hunt_id'] as String).toList();
    } catch (e) {
      debugPrint('Error getting hunts for session: $e');
      rethrow;
    }
  }

  /// Remove a session link from a hunt
  Future<void> deleteHuntSessionLink(String linkId) async {
    try {
      final Database db = await database;
      await db.delete(
        _huntSessionLinksTable,
        where: 'id = ?',
        whereArgs: [linkId],
      );
      debugPrint('Deleted hunt session link: $linkId');
    } catch (e) {
      debugPrint('Error deleting hunt session link: $e');
      rethrow;
    }
  }

  // ============================================================
  // HUNT LOCATION OPERATIONS
  // ============================================================

  /// Insert a new hunt location
  Future<void> insertHuntLocation(HuntLocation location) async {
    try {
      final Database db = await database;
      await db.insert(
        _huntLocationsTable,
        location.toDatabaseMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted hunt location: ${location.id} (${location.name})');
    } catch (e) {
      debugPrint('Error inserting hunt location: $e');
      rethrow;
    }
  }

  /// Update an existing hunt location
  Future<void> updateHuntLocation(HuntLocation location) async {
    try {
      final Database db = await database;
      final int count = await db.update(
        _huntLocationsTable,
        location.toDatabaseMap(),
        where: 'id = ?',
        whereArgs: [location.id],
      );
      if (count == 0) {
        throw Exception('Hunt location not found: ${location.id}');
      }
      debugPrint('Updated hunt location: ${location.id}');
    } catch (e) {
      debugPrint('Error updating hunt location: $e');
      rethrow;
    }
  }

  /// Get all locations for a hunt
  Future<List<HuntLocation>> getHuntLocations(String huntId, {HuntLocationStatus? status}) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results;

      if (status != null) {
        results = await db.query(
          _huntLocationsTable,
          where: 'hunt_id = ? AND status = ?',
          whereArgs: [huntId, status.name],
          orderBy: 'sort_order ASC, created_at DESC',
        );
      } else {
        results = await db.query(
          _huntLocationsTable,
          where: 'hunt_id = ?',
          whereArgs: [huntId],
          orderBy: 'sort_order ASC, created_at DESC',
        );
      }

      return results.map(HuntLocation.fromDatabaseMap).toList();
    } catch (e) {
      debugPrint('Error getting hunt locations: $e');
      rethrow;
    }
  }

  /// Delete a hunt location
  Future<void> deleteHuntLocation(String locationId) async {
    try {
      final Database db = await database;
      await db.delete(
        _huntLocationsTable,
        where: 'id = ?',
        whereArgs: [locationId],
      );
      debugPrint('Deleted hunt location: $locationId');
    } catch (e) {
      debugPrint('Error deleting hunt location: $e');
      rethrow;
    }
  }

  /// Get hunt summary statistics
  Future<Map<String, int>> getHuntSummary(String huntId) async {
    try {
      final Database db = await database;

      // Count only actual documents (images, PDFs, documents) - not notes or links
      final documentCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM $_huntDocumentsTable WHERE hunt_id = ? AND type IN (?, ?, ?)',
          [huntId, HuntDocumentType.image.name, HuntDocumentType.pdf.name, HuntDocumentType.document.name],
        ),
      ) ?? 0;

      final noteCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM $_huntDocumentsTable WHERE hunt_id = ? AND type = ?',
          [huntId, HuntDocumentType.note.name],
        ),
      ) ?? 0;

      final linkCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM $_huntDocumentsTable WHERE hunt_id = ? AND type = ?',
          [huntId, HuntDocumentType.link.name],
        ),
      ) ?? 0;

      // Count sessions directly associated with this hunt (via session.huntId)
      final sessionCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM $_sessionsTable WHERE hunt_id = ?',
          [huntId],
        ),
      ) ?? 0;

      final locationCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM $_huntLocationsTable WHERE hunt_id = ?',
          [huntId],
        ),
      ) ?? 0;

      return {
        'documents': documentCount,
        'notes': noteCount,
        'links': linkCount,
        'sessions': sessionCount,
        'locations': locationCount,
      };
    } catch (e) {
      debugPrint('Error getting hunt summary: $e');
      rethrow;
    }
  }

  // ============================================================================
  // Journal Entry Operations
  // ============================================================================

  /// Insert a new journal entry
  Future<void> insertJournalEntry(JournalEntry entry) async {
    try {
      final Database db = await database;
      await db.insert(
        _journalEntriesTable,
        entry.toDatabaseMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted journal entry: ${entry.id}');
    } catch (e) {
      debugPrint('Error inserting journal entry: $e');
      rethrow;
    }
  }

  /// Update an existing journal entry
  Future<void> updateJournalEntry(JournalEntry entry) async {
    try {
      final Database db = await database;
      final int count = await db.update(
        _journalEntriesTable,
        entry.toDatabaseMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );
      if (count == 0) {
        throw Exception('Journal entry not found: ${entry.id}');
      }
      debugPrint('Updated journal entry: ${entry.id}');
    } catch (e) {
      debugPrint('Error updating journal entry: $e');
      rethrow;
    }
  }

  /// Get a single journal entry by ID
  Future<JournalEntry?> getJournalEntry(String entryId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        _journalEntriesTable,
        where: 'id = ?',
        whereArgs: [entryId],
      );

      if (results.isNotEmpty) {
        return JournalEntry.fromDatabaseMap(results.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting journal entry: $e');
      rethrow;
    }
  }

  /// Get all journal entries with optional filters
  Future<List<JournalEntry>> getJournalEntries({
    String? entryType,
    String? sessionId,
    String? huntId,
    bool? hasLocation,
    bool? isPinned,
    bool? isHighlight,
    int? limit,
    int? offset,
  }) async {
    try {
      final Database db = await database;

      final whereClauses = <String>[];
      final whereArgs = <Object?>[];

      if (entryType != null) {
        whereClauses.add('entry_type = ?');
        whereArgs.add(entryType);
      }

      if (sessionId != null) {
        whereClauses.add('session_id = ?');
        whereArgs.add(sessionId);
      }

      if (huntId != null) {
        whereClauses.add('hunt_id = ?');
        whereArgs.add(huntId);
      }

      if (hasLocation == true) {
        whereClauses.add('latitude IS NOT NULL AND longitude IS NOT NULL');
      } else if (hasLocation == false) {
        whereClauses.add('latitude IS NULL OR longitude IS NULL');
      }

      if (isPinned == true) {
        whereClauses.add('is_pinned = 1');
      }

      if (isHighlight == true) {
        whereClauses.add('is_highlight = 1');
      }

      final List<Map<String, dynamic>> results = await db.query(
        _journalEntriesTable,
        where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'is_pinned DESC, timestamp DESC',
        limit: limit,
        offset: offset,
      );

      return results.map(JournalEntry.fromDatabaseMap).toList();
    } catch (e) {
      debugPrint('Error getting journal entries: $e');
      rethrow;
    }
  }

  /// Get journal entries for a specific session
  Future<List<JournalEntry>> getJournalEntriesForSession(String sessionId) async {
    return getJournalEntries(sessionId: sessionId);
  }

  /// Get journal entries for a specific hunt
  Future<List<JournalEntry>> getJournalEntriesForHunt(String huntId) async {
    return getJournalEntries(huntId: huntId);
  }

  /// Delete a journal entry
  Future<void> deleteJournalEntry(String entryId) async {
    try {
      final Database db = await database;
      final int count = await db.delete(
        _journalEntriesTable,
        where: 'id = ?',
        whereArgs: [entryId],
      );
      if (count == 0) {
        debugPrint('Journal entry not found for deletion: $entryId');
      } else {
        debugPrint('Deleted journal entry: $entryId');
      }
    } catch (e) {
      debugPrint('Error deleting journal entry: $e');
      rethrow;
    }
  }

  /// Get count of journal entries with optional filters
  Future<int> getJournalEntryCount({String? sessionId, String? huntId}) async {
    try {
      final Database db = await database;

      String sql = 'SELECT COUNT(*) FROM $_journalEntriesTable';
      final whereArgs = <Object?>[];

      if (sessionId != null || huntId != null) {
        final whereClauses = <String>[];
        if (sessionId != null) {
          whereClauses.add('session_id = ?');
          whereArgs.add(sessionId);
        }
        if (huntId != null) {
          whereClauses.add('hunt_id = ?');
          whereArgs.add(huntId);
        }
        sql += ' WHERE ${whereClauses.join(' AND ')}';
      }

      return Sqflite.firstIntValue(await db.rawQuery(sql, whereArgs)) ?? 0;
    } catch (e) {
      debugPrint('Error getting journal entry count: $e');
      rethrow;
    }
  }

  // ============================================================================
  // Custom Marker Operations
  // ============================================================================

  /// Insert a new custom marker
  Future<void> insertCustomMarker(CustomMarker marker) async {
    try {
      final Database db = await database;
      final data = marker.toDatabaseMap();
      debugPrint('📌 Inserting custom marker: ${marker.id}');
      debugPrint('   session_id in data: ${data['session_id']}');
      await db.insert(
        _customMarkersTable,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted custom marker: ${marker.id}');
    } catch (e) {
      debugPrint('Error inserting custom marker: $e');
      rethrow;
    }
  }

  /// Update an existing custom marker
  Future<void> updateCustomMarker(CustomMarker marker) async {
    try {
      final Database db = await database;
      await db.update(
        _customMarkersTable,
        marker.toDatabaseMap(),
        where: 'id = ?',
        whereArgs: [marker.id],
      );
      debugPrint('Updated custom marker: ${marker.id}');
    } catch (e) {
      debugPrint('Error updating custom marker: $e');
      rethrow;
    }
  }

  /// Delete a custom marker (cascade deletes attachments)
  Future<void> deleteCustomMarker(String markerId) async {
    try {
      final Database db = await database;
      await db.delete(
        _customMarkersTable,
        where: 'id = ?',
        whereArgs: [markerId],
      );
      debugPrint('Deleted custom marker: $markerId');
    } catch (e) {
      debugPrint('Error deleting custom marker: $e');
      rethrow;
    }
  }

  /// Get a custom marker by ID
  Future<CustomMarker?> getCustomMarker(String markerId) async {
    try {
      final Database db = await database;
      final results = await db.query(
        _customMarkersTable,
        where: 'id = ?',
        whereArgs: [markerId],
        limit: 1,
      );
      if (results.isEmpty) return null;
      return CustomMarker.fromDatabaseMap(results.first);
    } catch (e) {
      debugPrint('Error getting custom marker: $e');
      rethrow;
    }
  }

  /// Get all custom markers
  Future<List<CustomMarker>> getAllCustomMarkers() async {
    try {
      final Database db = await database;
      final results = await db.query(
        _customMarkersTable,
        orderBy: 'created_at DESC',
      );
      return results.map(CustomMarker.fromDatabaseMap).toList();
    } catch (e) {
      debugPrint('Error getting all custom markers: $e');
      rethrow;
    }
  }

  /// Get custom markers within geographic bounds
  Future<List<CustomMarker>> getCustomMarkersForBounds({
    required double north,
    required double south,
    required double east,
    required double west,
    Set<CustomMarkerCategory>? categoryFilter,
  }) async {
    try {
      final Database db = await database;

      var whereClause = 'latitude <= ? AND latitude >= ? AND longitude <= ? AND longitude >= ?';
      final whereArgs = <dynamic>[north, south, east, west];

      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        final categoryNames = categoryFilter.map((c) => c.name).toList();
        final placeholders = List.filled(categoryNames.length, '?').join(', ');
        whereClause += ' AND category IN ($placeholders)';
        whereArgs.addAll(categoryNames);
      }

      final results = await db.query(
        _customMarkersTable,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'created_at DESC',
      );
      return results.map(CustomMarker.fromDatabaseMap).toList();
    } catch (e) {
      debugPrint('Error getting custom markers for bounds: $e');
      rethrow;
    }
  }

  /// Get custom markers linked to a specific hunt
  Future<List<CustomMarker>> getCustomMarkersForHunt(String huntId) async {
    try {
      final Database db = await database;
      final results = await db.query(
        _customMarkersTable,
        where: 'hunt_id = ?',
        whereArgs: [huntId],
        orderBy: 'created_at DESC',
      );
      return results.map(CustomMarker.fromDatabaseMap).toList();
    } catch (e) {
      debugPrint('Error getting custom markers for hunt: $e');
      rethrow;
    }
  }

  /// Get custom markers linked to a specific tracking session
  Future<List<CustomMarker>> getCustomMarkersForSession(String sessionId) async {
    try {
      final Database db = await database;
      debugPrint('🔍 Querying custom markers for session: $sessionId');
      final results = await db.query(
        _customMarkersTable,
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'created_at ASC',
      );
      debugPrint('🔍 Found ${results.length} custom markers for session $sessionId');
      for (final r in results) {
        debugPrint('   📌 Marker: ${r['id']} - ${r['name']} (session_id: ${r['session_id']})');
      }
      return results.map(CustomMarker.fromDatabaseMap).toList();
    } catch (e) {
      debugPrint('Error getting custom markers for session: $e');
      rethrow;
    }
  }

  /// Search custom markers by name or notes
  Future<List<CustomMarker>> searchCustomMarkers(String query) async {
    try {
      final Database db = await database;
      final searchQuery = '%$query%';
      final results = await db.query(
        _customMarkersTable,
        where: 'name LIKE ? OR notes LIKE ?',
        whereArgs: [searchQuery, searchQuery],
        orderBy: 'created_at DESC',
      );
      return results.map(CustomMarker.fromDatabaseMap).toList();
    } catch (e) {
      debugPrint('Error searching custom markers: $e');
      rethrow;
    }
  }

  /// Get count of custom markers
  Future<int> getCustomMarkerCount() async {
    try {
      final Database db = await database;
      final result = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_customMarkersTable'),
      );
      return result ?? 0;
    } catch (e) {
      debugPrint('Error getting custom marker count: $e');
      rethrow;
    }
  }

  // ============================================================================
  // Marker Attachment Operations
  // ============================================================================

  /// Insert a new marker attachment
  Future<void> insertMarkerAttachment(MarkerAttachment attachment) async {
    try {
      final Database db = await database;
      await db.insert(
        _markerAttachmentsTable,
        attachment.toDatabaseMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted marker attachment: ${attachment.id}');
    } catch (e) {
      debugPrint('Error inserting marker attachment: $e');
      rethrow;
    }
  }

  /// Update an existing marker attachment
  Future<void> updateMarkerAttachment(MarkerAttachment attachment) async {
    try {
      final Database db = await database;
      await db.update(
        _markerAttachmentsTable,
        attachment.toDatabaseMap(),
        where: 'id = ?',
        whereArgs: [attachment.id],
      );
      debugPrint('Updated marker attachment: ${attachment.id}');
    } catch (e) {
      debugPrint('Error updating marker attachment: $e');
      rethrow;
    }
  }

  /// Delete a marker attachment
  Future<void> deleteMarkerAttachment(String attachmentId) async {
    try {
      final Database db = await database;
      await db.delete(
        _markerAttachmentsTable,
        where: 'id = ?',
        whereArgs: [attachmentId],
      );
      debugPrint('Deleted marker attachment: $attachmentId');
    } catch (e) {
      debugPrint('Error deleting marker attachment: $e');
      rethrow;
    }
  }

  /// Get a marker attachment by ID
  Future<MarkerAttachment?> getMarkerAttachment(String attachmentId) async {
    try {
      final Database db = await database;
      final results = await db.query(
        _markerAttachmentsTable,
        where: 'id = ?',
        whereArgs: [attachmentId],
        limit: 1,
      );
      if (results.isEmpty) return null;
      return MarkerAttachment.fromDatabaseMap(results.first);
    } catch (e) {
      debugPrint('Error getting marker attachment: $e');
      rethrow;
    }
  }

  /// Get all attachments for a custom marker
  Future<List<MarkerAttachment>> getAttachmentsForMarker(String markerId) async {
    try {
      final Database db = await database;
      debugPrint('📎 Querying attachments for marker_id: $markerId');
      final results = await db.query(
        _markerAttachmentsTable,
        where: 'marker_id = ?',
        whereArgs: [markerId],
        orderBy: 'sort_order ASC, created_at DESC',
      );
      debugPrint('📎 Found ${results.length} attachments for marker $markerId');
      for (final r in results) {
        debugPrint('📎   Attachment: ${r['id']} type=${r['type']} file_path=${r['file_path']}');
      }
      return results.map(MarkerAttachment.fromDatabaseMap).toList();
    } catch (e) {
      debugPrint('Error getting attachments for marker: $e');
      rethrow;
    }
  }

  /// Get attachments for a marker filtered by type
  Future<List<MarkerAttachment>> getAttachmentsForMarkerByType(
    String markerId,
    MarkerAttachmentType type,
  ) async {
    try {
      final Database db = await database;
      final results = await db.query(
        _markerAttachmentsTable,
        where: 'marker_id = ? AND type = ?',
        whereArgs: [markerId, type.name],
        orderBy: 'sort_order ASC, created_at DESC',
      );
      return results.map(MarkerAttachment.fromDatabaseMap).toList();
    } catch (e) {
      debugPrint('Error getting attachments for marker by type: $e');
      rethrow;
    }
  }

  /// Get count of attachments for a marker
  Future<int> getMarkerAttachmentCount(String markerId) async {
    try {
      final Database db = await database;
      final result = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM $_markerAttachmentsTable WHERE marker_id = ?',
          [markerId],
        ),
      );
      return result ?? 0;
    } catch (e) {
      debugPrint('Error getting marker attachment count: $e');
      rethrow;
    }
  }

  /// Check if a marker has any attachments
  Future<bool> markerHasAttachments(String markerId) async {
    final count = await getMarkerAttachmentCount(markerId);
    return count > 0;
  }

  /// Close the database connection
  // ============ Achievement & Statistics Operations (v14) ============

  /// Get lifetime statistics (single row)
  Future<Map<String, dynamic>?> getLifetimeStatistics() async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        _lifetimeStatisticsTable,
        where: 'id = ?',
        whereArgs: [1],
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      debugPrint('Error getting lifetime statistics: $e');
      rethrow;
    }
  }

  /// Update lifetime statistics
  Future<void> updateLifetimeStatistics(Map<String, dynamic> stats) async {
    try {
      final Database db = await database;
      stats['updated_at'] = DateTime.now().millisecondsSinceEpoch;

      // Ensure the row exists first
      await db.execute('''
        INSERT OR IGNORE INTO $_lifetimeStatisticsTable (id, updated_at)
        VALUES (1, ${stats['updated_at']})
      ''');

      await db.update(
        _lifetimeStatisticsTable,
        stats,
        where: 'id = ?',
        whereArgs: [1],
      );
    } catch (e) {
      debugPrint('Error updating lifetime statistics: $e');
      rethrow;
    }
  }

  /// Get all explored states
  Future<List<Map<String, dynamic>>> getExploredStates() async {
    try {
      final Database db = await database;
      return await db.query(
        _exploredStatesTable,
        orderBy: 'first_visited_at DESC',
      );
    } catch (e) {
      debugPrint('Error getting explored states: $e');
      rethrow;
    }
  }

  /// Get explored state by code
  Future<Map<String, dynamic>?> getExploredState(String stateCode) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        _exploredStatesTable,
        where: 'state_code = ?',
        whereArgs: [stateCode],
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      debugPrint('Error getting explored state: $e');
      rethrow;
    }
  }

  /// Insert or update explored state
  Future<void> upsertExploredState(Map<String, dynamic> state) async {
    try {
      final Database db = await database;
      await db.insert(
        _exploredStatesTable,
        state,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error upserting explored state: $e');
      rethrow;
    }
  }

  /// Record a session day for streak tracking
  Future<void> recordSessionDay(String date) async {
    try {
      final Database db = await database;
      final existing = await db.query(
        _sessionStreaksTable,
        where: 'date = ?',
        whereArgs: [date],
      );

      if (existing.isNotEmpty) {
        // Increment session count for this day
        await db.execute('''
          UPDATE $_sessionStreaksTable
          SET session_count = session_count + 1
          WHERE date = ?
        ''', [date]);
      } else {
        // Insert new day
        await db.insert(
          _sessionStreaksTable,
          {
            'id': 'streak_$date',
            'date': date,
            'session_count': 1,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          },
        );
      }
    } catch (e) {
      debugPrint('Error recording session day: $e');
      rethrow;
    }
  }

  /// Get session streak days (ordered by date descending)
  Future<List<Map<String, dynamic>>> getSessionStreakDays({int? limit}) async {
    try {
      final Database db = await database;
      return await db.query(
        _sessionStreaksTable,
        orderBy: 'date DESC',
        limit: limit,
      );
    } catch (e) {
      debugPrint('Error getting session streak days: $e');
      rethrow;
    }
  }

  /// Get all achievement definitions
  Future<List<Map<String, dynamic>>> getAchievements() async {
    try {
      final Database db = await database;
      return await db.query(
        _achievementsTable,
        orderBy: 'sort_order ASC',
      );
    } catch (e) {
      debugPrint('Error getting achievements: $e');
      rethrow;
    }
  }

  /// Insert achievement definition
  Future<void> insertAchievement(Map<String, dynamic> achievement) async {
    try {
      final Database db = await database;
      await db.insert(
        _achievementsTable,
        achievement,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error inserting achievement: $e');
      rethrow;
    }
  }

  /// Get user achievements (progress for all achievements)
  Future<List<Map<String, dynamic>>> getUserAchievements() async {
    try {
      final Database db = await database;
      return await db.rawQuery('''
        SELECT ua.*, a.name, a.description, a.category, a.difficulty,
               a.icon_name, a.requirement_type, a.requirement_value
        FROM $_userAchievementsTable ua
        INNER JOIN $_achievementsTable a ON ua.achievement_id = a.id
        ORDER BY a.sort_order ASC
      ''');
    } catch (e) {
      debugPrint('Error getting user achievements: $e');
      rethrow;
    }
  }

  /// Get user achievement by achievement ID
  Future<Map<String, dynamic>?> getUserAchievement(String achievementId) async {
    try {
      final Database db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        _userAchievementsTable,
        where: 'achievement_id = ?',
        whereArgs: [achievementId],
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      debugPrint('Error getting user achievement: $e');
      rethrow;
    }
  }

  /// Insert or update user achievement progress
  Future<void> upsertUserAchievement(Map<String, dynamic> userAchievement) async {
    try {
      final Database db = await database;
      await db.insert(
        _userAchievementsTable,
        userAchievement,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error upserting user achievement: $e');
      rethrow;
    }
  }

  /// Get count of completed achievements
  Future<int> getCompletedAchievementCount() async {
    try {
      final Database db = await database;
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count FROM $_userAchievementsTable
        WHERE status = 'completed'
      ''');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('Error getting completed achievement count: $e');
      rethrow;
    }
  }

  /// Get explored states count
  Future<int> getExploredStatesCount() async {
    try {
      final Database db = await database;
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count FROM $_exploredStatesTable
      ''');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('Error getting explored states count: $e');
      rethrow;
    }
  }

  Future<void> close() async {
    final Database? db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      debugPrint('Database connection closed');
    }
  }

  /// Dispose of the service
  void dispose() {
    close();
    _instance = null;
  }
}

/// Exception thrown when the database cannot be opened and may need recovery.
///
/// This typically happens when:
/// - The encryption key was lost (Android KeyStore reset, backup/restore)
/// - The database file is corrupted
/// - Storage permissions were revoked
///
/// The UI should catch this exception and offer the user a choice to reset
/// the database and start fresh.
class DatabaseRecoveryException implements Exception {
  DatabaseRecoveryException(this.message, {this.originalError});

  final String message;
  final Object? originalError;

  @override
  String toString() => 'DatabaseRecoveryException: $message';
}
