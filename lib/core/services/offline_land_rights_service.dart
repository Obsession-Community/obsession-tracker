import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/access_rights.dart';
import 'package:obsession_tracker/core/models/activity_permissions.dart';
import 'package:obsession_tracker/core/models/cell_tower.dart';
import 'package:obsession_tracker/core/models/comprehensive_land_ownership.dart';
import 'package:obsession_tracker/core/models/historical_place.dart';
import 'package:obsession_tracker/core/models/owner_contact.dart';
import 'package:obsession_tracker/core/models/trail.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

// =============================================================================
// ISOLATE FUNCTIONS (must be top-level for compute())
// =============================================================================

/// Parse multiple JSON coordinate strings in an isolate
/// This moves heavy JSON parsing off the main thread for smoother map panning
List<List<List<List<double>>>?> _parseCoordinatesInIsolate(List<String?> jsonStrings) {
  final results = <List<List<List<double>>>?>[];

  for (final jsonStr in jsonStrings) {
    if (jsonStr == null || jsonStr.isEmpty) {
      results.add(null);
      continue;
    }

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        final parsed = decoded.map((ring) {
          if (ring is List) {
            return ring.map((point) {
              if (point is List && point.length >= 2) {
                return [
                  (point[0] as num).toDouble(),
                  (point[1] as num).toDouble(),
                ];
              }
              return <double>[0.0, 0.0];
            }).toList();
          }
          return <List<double>>[];
        }).toList();
        results.add(parsed);
      } else {
        results.add(null);
      }
    } catch (e) {
      results.add(null);
    }
  }

  return results;
}

// =============================================================================

/// Offline land rights service for local caching and GPS-based queries
/// Enables treasure hunting in remote areas without connectivity
class OfflineLandRightsService {
  static final OfflineLandRightsService _instance = OfflineLandRightsService._internal();
  factory OfflineLandRightsService() => _instance;
  OfflineLandRightsService._internal();

  Database? _database;

  /// SQLite database configuration
  /// NOTE: Changed from 'land_rights_cache.db' (encrypted) to 'land_cache.db' (unencrypted)
  /// for better performance. Public government data doesn't need encryption.
  static const String _databaseName = 'land_cache.db';
  static const String _legacyEncryptedDbName = 'land_rights_cache.db'; // Old encrypted DB for migration
  static const int _databaseVersion = 10; // v10: Add cell towers table

  /// Table names
  static const String _tableProperties = 'cached_properties';
  static const String _tableBoundaries = 'cached_boundaries';
  static const String _tableDownloads = 'offline_downloads';
  static const String _tableStateDownloads = 'state_downloads';
  static const String _tableTrails = 'cached_trails'; // v3: Trails from state ZIP downloads
  static const String _tableHistoricalPlaces = 'cached_historical_places'; // v5: GNIS data
  static const String _tableHistoricalPlacesDownloads = 'historical_places_downloads'; // v5
  static const String _tableCellTowers = 'cached_cell_towers'; // v10: Cell coverage from OpenCelliD
  
  /// Cache configuration
  static const Duration _cacheExpiration = Duration(days: 30);
  // Default download radius for future use
  // ignore: unused_field
  static const double _defaultRadiusKm = 10.0;
  
  /// Initialize the offline database (UNENCRYPTED for performance)
  ///
  /// This database contains only PUBLIC government data (PAD-US, OSM trails, GNIS).
  /// No encryption needed - improves query performance by 10-20%.
  /// User data remains encrypted in obsession_tracker.db.
  Future<void> initialize() async {
    if (_database != null) return;

    final String dbPath = await getDatabasesPath();
    final String path = join(dbPath, _databaseName);
    final String legacyPath = join(dbPath, _legacyEncryptedDbName);

    // Migrate from old encrypted database if it exists
    await _migrateFromEncryptedDatabase(legacyPath, path);

    try {
      // Open unencrypted database (no password parameter)
      _database = await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        // NO password = unencrypted for better performance
      );
    } catch (e) {
      // Database is corrupted - since this is a cache, we can safely recreate it
      debugPrint('⚠️ Land cache database corrupted: $e');
      debugPrint('🔄 Deleting corrupted database and creating fresh cache...');

      try {
        final dbFile = File(path);
        if (await dbFile.exists()) {
          await dbFile.delete();
          debugPrint('🗑️ Deleted corrupted database file');
        }

        // Try to create a fresh database
        _database = await openDatabase(
          path,
          version: _databaseVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );
        debugPrint('✅ Created fresh land cache database');
      } catch (retryError) {
        debugPrint('❌ Failed to recreate database: $retryError');
        rethrow;
      }
    }

    debugPrint('📍 Land cache database initialized (unencrypted for performance) at: $path');
    await _cleanExpiredCache();

    // Migrate: Clear legacy SharedPreferences-based caches from pre-ZIP era
    await _migrateLegacySharedPreferencesCache();

    // Backfill unique_trail_count for any existing downloads that have it as 0
    await _backfillUniqueTrailCounts();

    // Fix state names that were saved as abbreviations instead of full names
    await _backfillStateNames();

    // Remove data for excluded states (e.g., Hawaii - no OSM trail data)
    await _removeExcludedStates();
  }

  /// Clean up old encrypted database - no migration needed
  ///
  /// The old database (land_rights_cache.db) was encrypted with SQLCipher.
  /// Since this contains only public government data that can be re-downloaded
  /// from state ZIPs, we simply delete it rather than migrate ~300K records.
  Future<void> _migrateFromEncryptedDatabase(String legacyPath, String newPath) async {
    final legacyFile = File(legacyPath);

    // Check if legacy encrypted database exists
    if (!await legacyFile.exists()) {
      return; // Nothing to clean up
    }

    // Delete the old encrypted database
    // Users will re-download their state data from the ZIPs
    try {
      final legacySize = await legacyFile.length();
      final legacySizeMB = (legacySize / 1024 / 1024).toStringAsFixed(1);

      debugPrint('🗑️ Removing legacy encrypted land cache ($legacySizeMB MB)');
      debugPrint('📝 Re-download states from Settings → Offline Data for offline access');

      await legacyFile.delete();

      debugPrint('✅ Legacy database removed - starting fresh with faster unencrypted cache');
    } catch (e) {
      debugPrint('⚠️ Could not delete legacy database: $e');
    }
  }

  /// Remove data for states that are no longer supported
  ///
  /// Hawaii was excluded because OSM has no trail data for it.
  /// This cleans up any existing Hawaii data from earlier downloads.
  Future<void> _removeExcludedStates() async {
    const excludedStates = ['HI']; // Hawaii excluded - no OSM trail data

    try {
      final db = await _getDatabase();

      for (final stateCode in excludedStates) {
        // Check if state exists in downloads
        final existing = await db.query(
          _tableStateDownloads,
          where: 'state_code = ?',
          whereArgs: [stateCode],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          debugPrint('🧹 Removing excluded state: $stateCode');

          // Delete all data for this state
          await db.transaction((txn) async {
            await txn.delete(_tableProperties, where: 'state_code = ?', whereArgs: [stateCode]);
            await txn.delete(_tableTrails, where: 'state_code = ?', whereArgs: [stateCode]);
            await txn.delete(_tableHistoricalPlaces, where: 'state_code = ?', whereArgs: [stateCode]);
            await txn.delete(_tableStateDownloads, where: 'state_code = ?', whereArgs: [stateCode]);
          });

          debugPrint('🧹 Removed all data for excluded state: $stateCode');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error removing excluded states: $e');
    }
  }

  /// Fix state names that were incorrectly saved as abbreviations
  ///
  /// Earlier versions had an incomplete state name map, causing some states
  /// to be saved with their abbreviation (e.g., "CT") instead of full name.
  Future<void> _backfillStateNames() async {
    try {
      final db = await _getDatabase();

      // All 49 state names (Hawaii excluded - no OSM trail data)
      const stateNames = {
        'AL': 'Alabama', 'AK': 'Alaska', 'AZ': 'Arizona', 'AR': 'Arkansas',
        'CA': 'California', 'CO': 'Colorado', 'CT': 'Connecticut', 'DE': 'Delaware',
        'FL': 'Florida', 'GA': 'Georgia', 'ID': 'Idaho',
        'IL': 'Illinois', 'IN': 'Indiana', 'IA': 'Iowa', 'KS': 'Kansas',
        'KY': 'Kentucky', 'LA': 'Louisiana', 'ME': 'Maine', 'MD': 'Maryland',
        'MA': 'Massachusetts', 'MI': 'Michigan', 'MN': 'Minnesota', 'MS': 'Mississippi',
        'MO': 'Missouri', 'MT': 'Montana', 'NE': 'Nebraska', 'NV': 'Nevada',
        'NH': 'New Hampshire', 'NJ': 'New Jersey', 'NM': 'New Mexico', 'NY': 'New York',
        'NC': 'North Carolina', 'ND': 'North Dakota', 'OH': 'Ohio', 'OK': 'Oklahoma',
        'OR': 'Oregon', 'PA': 'Pennsylvania', 'RI': 'Rhode Island', 'SC': 'South Carolina',
        'SD': 'South Dakota', 'TN': 'Tennessee', 'TX': 'Texas', 'UT': 'Utah',
        'VT': 'Vermont', 'VA': 'Virginia', 'WA': 'Washington', 'WV': 'West Virginia',
        'WI': 'Wisconsin', 'WY': 'Wyoming',
      };

      // Find states where state_name equals state_code (i.e., abbreviation was used)
      final statesNeedingFix = await db.rawQuery('''
        SELECT state_code, state_name
        FROM $_tableStateDownloads
        WHERE state_name = state_code
      ''');

      if (statesNeedingFix.isEmpty) return;

      int fixedCount = 0;
      for (final row in statesNeedingFix) {
        final stateCode = row['state_code'] as String?;
        if (stateCode == null) continue;

        final correctName = stateNames[stateCode];
        if (correctName != null) {
          await db.update(
            _tableStateDownloads,
            {'state_name': correctName},
            where: 'state_code = ?',
            whereArgs: [stateCode],
          );
          fixedCount++;
          debugPrint('📝 Fixed state name: $stateCode → $correctName');
        }
      }

      if (fixedCount > 0) {
        debugPrint('✅ Fixed $fixedCount state names');
      }
    } catch (e) {
      debugPrint('⚠️ Backfill state names failed (non-critical): $e');
    }
  }

  /// Backfill unique_trail_count for existing downloads that predate v4
  ///
  /// If a state download has unique_trail_count = 0 but has trails in the database,
  /// calculate and store the correct count. This is a one-time fix for existing data.
  Future<void> _backfillUniqueTrailCounts() async {
    try {
      final db = await _getDatabase();

      // Find states with unique_trail_count = 0 but trails exist
      final statesNeedingBackfill = await db.rawQuery('''
        SELECT sd.state_code
        FROM $_tableStateDownloads sd
        WHERE sd.unique_trail_count = 0 OR sd.unique_trail_count IS NULL
      ''');

      if (statesNeedingBackfill.isEmpty) return;

      int backfilledCount = 0;
      for (final row in statesNeedingBackfill) {
        final stateCode = row['state_code'] as String?;
        if (stateCode == null) continue;

        // Calculate unique trail count
        final result = await db.rawQuery('''
          SELECT COUNT(DISTINCT trail_name) as unique_trails
          FROM $_tableTrails
          WHERE state_code = ?
        ''', [stateCode]);
        final uniqueCount = (result.first['unique_trails'] as int?) ?? 0;

        // Only update if there are actually trails
        if (uniqueCount > 0) {
          await db.update(
            _tableStateDownloads,
            {'unique_trail_count': uniqueCount},
            where: 'state_code = ?',
            whereArgs: [stateCode],
          );
          backfilledCount++;
          debugPrint('📊 Backfilled unique_trail_count for $stateCode: $uniqueCount trails');
        }
      }

      if (backfilledCount > 0) {
        debugPrint('✅ Backfilled unique_trail_count for $backfilledCount states');
      }
    } catch (e) {
      debugPrint('⚠️ Backfill unique_trail_count failed (non-critical): $e');
      // Don't block initialization if backfill fails
    }
  }

  /// One-time migration to clear legacy SharedPreferences caches
  ///
  /// Prior to v1.4.0, land and trail data was cached in SharedPreferences.
  /// Now all data comes from state ZIP downloads stored in SQLite.
  /// This clears any orphaned legacy data to free up storage.
  Future<void> _migrateLegacySharedPreferencesCache() async {
    const migrationKey = 'legacy_cache_migration_complete_v1';

    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if migration already completed
      if (prefs.getBool(migrationKey) == true) {
        return;
      }

      debugPrint('🔄 Migrating legacy SharedPreferences cache...');

      int clearedCount = 0;
      final keysToRemove = <String>[];

      // Find all legacy cache keys
      for (final key in prefs.getKeys()) {
        if (key.startsWith('offline_land_data_') ||
            key.startsWith('offline_trails_data_') ||
            key == 'offline_cache_metadata' ||
            key == 'offline_trail_cache_metadata' ||
            key.startsWith('auto_map_') ||
            key.startsWith('auto_trails_')) {
          keysToRemove.add(key);
        }
      }

      // Remove legacy keys
      for (final key in keysToRemove) {
        await prefs.remove(key);
        clearedCount++;
      }

      // Mark migration as complete
      await prefs.setBool(migrationKey, true);

      if (clearedCount > 0) {
        debugPrint('✅ Cleared $clearedCount legacy SharedPreferences cache entries');
      } else {
        debugPrint('✅ No legacy cache entries to clear');
      }
    } catch (e) {
      debugPrint('⚠️ Legacy cache migration failed (non-critical): $e');
      // Don't block initialization if migration fails
    }
  }
  
  /// Create database tables for offline caching
  Future<void> _onCreate(Database db, int version) async {
    // Main properties table with comprehensive land rights data
    await db.execute('''
      CREATE TABLE $_tableProperties (
        id TEXT PRIMARY KEY,
        owner_name TEXT NOT NULL,
        ownership_type TEXT NOT NULL,
        legal_description TEXT,
        acreage REAL,
        data_source TEXT NOT NULL,
        last_updated TEXT,
        
        -- Activity permissions (stored as JSON)
        activity_permissions TEXT NOT NULL,
        
        -- Access rights (stored as JSON)
        access_rights TEXT NOT NULL,
        
        -- Owner contact (stored as JSON)
        owner_contact TEXT,
        
        -- Legacy fields
        agency_name TEXT,
        unit_name TEXT,
        designation TEXT,
        access_type TEXT,
        allowed_uses TEXT,
        restrictions TEXT,
        contact_info TEXT,
        website TEXT,
        fees TEXT,
        seasonal_info TEXT,
        
        -- Cache metadata
        cached_at INTEGER NOT NULL,
        cache_expires INTEGER NOT NULL,
        state_code TEXT, -- State this property belongs to (e.g., 'SD', 'CA')
        data_version TEXT, -- Version of data (e.g., 'PAD-US-4.1')

        -- Spatial indexing
        center_lat REAL NOT NULL,
        center_lon REAL NOT NULL,
        bbox_north REAL NOT NULL,
        bbox_south REAL NOT NULL,
        bbox_east REAL NOT NULL,
        bbox_west REAL NOT NULL
      )
    ''');
    
    // Boundaries table for polygon data (separate for performance)
    await db.execute('''
      CREATE TABLE $_tableBoundaries (
        property_id TEXT NOT NULL,
        boundary_type TEXT NOT NULL, -- 'full' or 'simplified'
        coordinates TEXT NOT NULL, -- JSON array of coordinates
        FOREIGN KEY (property_id) REFERENCES $_tableProperties(id) ON DELETE CASCADE,
        PRIMARY KEY (property_id, boundary_type)
      )
    ''');
    
    // Offline download areas tracking (legacy radius-based)
    await db.execute('''
      CREATE TABLE $_tableDownloads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        center_lat REAL NOT NULL,
        center_lon REAL NOT NULL,
        radius_km REAL NOT NULL,
        downloaded_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        property_count INTEGER NOT NULL,
        total_size_bytes INTEGER
      )
    ''');

    // State-based bulk downloads with version tracking
    await db.execute('''
      CREATE TABLE $_tableStateDownloads (
        state_code TEXT PRIMARY KEY,
        state_name TEXT NOT NULL,
        data_version TEXT NOT NULL,
        property_count INTEGER NOT NULL,
        trail_count INTEGER DEFAULT 0,
        unique_trail_count INTEGER DEFAULT 0,
        total_size_bytes INTEGER,
        downloaded_at INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'complete',
        land_version TEXT,
        trails_version TEXT,
        historical_version TEXT,
        historical_places_count INTEGER DEFAULT 0,
        cell_version TEXT,
        cell_tower_count INTEGER DEFAULT 0
      )
    ''');

    // v3: Trails table for ZIP-only architecture
    await db.execute('''
      CREATE TABLE $_tableTrails (
        id TEXT PRIMARY KEY,
        external_id TEXT NOT NULL,
        trail_name TEXT NOT NULL,
        trail_number TEXT,
        trail_type TEXT NOT NULL,
        trail_class INTEGER,
        difficulty TEXT,
        surface_type TEXT,
        allowed_uses TEXT NOT NULL,
        managing_agency TEXT,
        length_miles REAL NOT NULL,
        geometry_geojson TEXT NOT NULL,
        data_source TEXT NOT NULL,
        osm_relation_id INTEGER,
        osm_relation_name TEXT,
        state_code TEXT NOT NULL,
        bbox_north REAL,
        bbox_south REAL,
        bbox_east REAL,
        bbox_west REAL
      )
    ''');

    // v5: Historical places table (USGS GNIS data - mines, ghost towns, etc.)
    // v9: Added category column
    await db.execute('''
      CREATE TABLE $_tableHistoricalPlaces (
        id TEXT PRIMARY KEY,
        feature_name TEXT NOT NULL,
        place_type TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'unknown',
        state_code TEXT NOT NULL,
        county_name TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        elevation_meters INTEGER,
        elevation_feet INTEGER,
        map_name TEXT,
        date_created INTEGER,
        date_edited INTEGER,
        cached_at INTEGER NOT NULL
      )
    ''');

    // v5: Historical places download tracking (separate from land/trail downloads)
    await db.execute('''
      CREATE TABLE $_tableHistoricalPlacesDownloads (
        state_code TEXT PRIMARY KEY,
        state_name TEXT NOT NULL,
        data_version TEXT NOT NULL,
        place_count INTEGER NOT NULL,
        downloaded_at INTEGER NOT NULL
      )
    ''');

    // v10: Cell towers table (OpenCelliD data for cell coverage overlay)
    await db.execute('''
      CREATE TABLE $_tableCellTowers (
        id TEXT PRIMARY KEY,
        radio_type TEXT NOT NULL,
        mcc INTEGER NOT NULL,
        mnc INTEGER NOT NULL,
        carrier TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        range_meters INTEGER NOT NULL,
        samples INTEGER DEFAULT 0,
        last_updated INTEGER,
        state_code TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');

    // Create spatial indexes for efficient GPS queries
    await db.execute('CREATE INDEX idx_properties_bbox ON $_tableProperties (bbox_north, bbox_south, bbox_east, bbox_west)');
    await db.execute('CREATE INDEX idx_properties_center ON $_tableProperties (center_lat, center_lon)');
    await db.execute('CREATE INDEX idx_properties_expires ON $_tableProperties (cache_expires)');
    await db.execute('CREATE INDEX idx_properties_state ON $_tableProperties (state_code)');
    await db.execute('CREATE INDEX idx_downloads_location ON $_tableDownloads (center_lat, center_lon)');
    await db.execute('CREATE INDEX idx_trails_bbox ON $_tableTrails (bbox_north, bbox_south, bbox_east, bbox_west)');
    await db.execute('CREATE INDEX idx_trails_state ON $_tableTrails (state_code)');

    // v5: Historical places indexes
    await db.execute('CREATE INDEX idx_hist_places_state ON $_tableHistoricalPlaces (state_code)');
    await db.execute('CREATE INDEX idx_hist_places_type ON $_tableHistoricalPlaces (place_type)');
    await db.execute('CREATE INDEX idx_hist_places_location ON $_tableHistoricalPlaces (latitude, longitude)');
    await db.execute('CREATE INDEX idx_hist_places_name ON $_tableHistoricalPlaces (feature_name COLLATE NOCASE)');
    // v9: Category index for filtering
    await db.execute('CREATE INDEX idx_hist_places_category ON $_tableHistoricalPlaces (category)');

    // v10: Cell tower indexes
    await db.execute('CREATE INDEX idx_cell_towers_state ON $_tableCellTowers (state_code)');
    await db.execute('CREATE INDEX idx_cell_towers_radio ON $_tableCellTowers (radio_type)');
    await db.execute('CREATE INDEX idx_cell_towers_location ON $_tableCellTowers (latitude, longitude)');

    debugPrint('Offline land rights database tables created');
  }

  /// Upgrade database schema if needed
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading offline database from v$oldVersion to v$newVersion');

    if (oldVersion < 2) {
      // v2: Add state downloads with version tracking
      debugPrint('Migrating to v2: Adding state download support...');

      // Add new columns to properties table
      await db.execute('ALTER TABLE $_tableProperties ADD COLUMN state_code TEXT');
      await db.execute('ALTER TABLE $_tableProperties ADD COLUMN data_version TEXT');

      // Create state downloads table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableStateDownloads (
          state_code TEXT PRIMARY KEY,
          state_name TEXT NOT NULL,
          data_version TEXT NOT NULL,
          property_count INTEGER NOT NULL,
          total_size_bytes INTEGER,
          downloaded_at INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'complete'
        )
      ''');

      // Add index for state-based queries
      await db.execute('CREATE INDEX IF NOT EXISTS idx_properties_state ON $_tableProperties (state_code)');

      debugPrint('v2 migration complete');
    }

    if (oldVersion < 3) {
      // v3: Add trails table for ZIP-only architecture
      debugPrint('Migrating to v3: Adding trails support...');

      // Add trail_count to state_downloads
      try {
        await db.execute('ALTER TABLE $_tableStateDownloads ADD COLUMN trail_count INTEGER DEFAULT 0');
      } catch (_) {
        // Column may already exist
      }

      // Create trails table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableTrails (
          id TEXT PRIMARY KEY,
          external_id TEXT NOT NULL,
          trail_name TEXT NOT NULL,
          trail_number TEXT,
          trail_type TEXT NOT NULL,
          trail_class INTEGER,
          difficulty TEXT,
          surface_type TEXT,
          allowed_uses TEXT NOT NULL,
          managing_agency TEXT,
          length_miles REAL NOT NULL,
          geometry_geojson TEXT NOT NULL,
          data_source TEXT NOT NULL,
          osm_relation_id INTEGER,
          osm_relation_name TEXT,
          state_code TEXT NOT NULL,
          bbox_north REAL,
          bbox_south REAL,
          bbox_east REAL,
          bbox_west REAL
        )
      ''');

      // Add indexes for trails
      await db.execute('CREATE INDEX IF NOT EXISTS idx_trails_bbox ON $_tableTrails (bbox_north, bbox_south, bbox_east, bbox_west)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_trails_state ON $_tableTrails (state_code)');

      debugPrint('v3 migration complete');
    }

    if (oldVersion < 4) {
      // v4: Add unique_trail_count to state_downloads (pre-calculated for performance)
      debugPrint('Migrating to v4: Adding unique_trail_count...');

      try {
        await db.execute('ALTER TABLE $_tableStateDownloads ADD COLUMN unique_trail_count INTEGER DEFAULT 0');
      } catch (_) {
        // Column may already exist
      }

      // Calculate unique_trail_count for existing downloaded states
      final states = await db.query(_tableStateDownloads, columns: ['state_code']);
      for (final state in states) {
        final stateCode = state['state_code'] as String?;
        if (stateCode == null) continue;
        final result = await db.rawQuery('''
          SELECT COUNT(DISTINCT trail_name) as unique_trails
          FROM $_tableTrails
          WHERE state_code = ?
        ''', [stateCode]);
        final uniqueCount = (result.first['unique_trails'] as int?) ?? 0;
        await db.update(
          _tableStateDownloads,
          {'unique_trail_count': uniqueCount},
          where: 'state_code = ?',
          whereArgs: [stateCode],
        );
      }

      debugPrint('v4 migration complete');
    }

    if (oldVersion < 5) {
      // v5: Add historical places tables (USGS GNIS data)
      debugPrint('Migrating to v5: Adding historical places support...');

      // Create historical places table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableHistoricalPlaces (
          id TEXT PRIMARY KEY,
          feature_name TEXT NOT NULL,
          place_type TEXT NOT NULL,
          state_code TEXT NOT NULL,
          county_name TEXT,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          elevation_meters INTEGER,
          elevation_feet INTEGER,
          map_name TEXT,
          date_created INTEGER,
          date_edited INTEGER,
          cached_at INTEGER NOT NULL
        )
      ''');

      // Create historical places download tracking table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableHistoricalPlacesDownloads (
          state_code TEXT PRIMARY KEY,
          state_name TEXT NOT NULL,
          data_version TEXT NOT NULL,
          place_count INTEGER NOT NULL,
          downloaded_at INTEGER NOT NULL
        )
      ''');

      // Add indexes for historical places
      await db.execute('CREATE INDEX IF NOT EXISTS idx_hist_places_state ON $_tableHistoricalPlaces (state_code)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_hist_places_type ON $_tableHistoricalPlaces (place_type)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_hist_places_location ON $_tableHistoricalPlaces (latitude, longitude)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_hist_places_name ON $_tableHistoricalPlaces (feature_name COLLATE NOCASE)');

      debugPrint('v5 migration complete');
    }

    if (oldVersion < 6) {
      // v6: Add per-type version tracking for selective updates
      // This enables downloading only land, trails, or historical data that changed
      debugPrint('Migrating to v6: Adding per-type version tracking...');

      // Add per-type version columns to state_downloads
      try {
        await db.execute('ALTER TABLE $_tableStateDownloads ADD COLUMN land_version TEXT');
      } catch (_) {
        // Column may already exist
      }
      try {
        await db.execute('ALTER TABLE $_tableStateDownloads ADD COLUMN trails_version TEXT');
      } catch (_) {
        // Column may already exist
      }
      try {
        await db.execute('ALTER TABLE $_tableStateDownloads ADD COLUMN historical_version TEXT');
      } catch (_) {
        // Column may already exist
      }

      // Migrate existing data_version to land_version (legacy combined ZIPs were mainly land data)
      await db.execute('''
        UPDATE $_tableStateDownloads
        SET land_version = data_version
        WHERE land_version IS NULL AND data_version IS NOT NULL
      ''');

      // Migrate historical_places_downloads version to state_downloads.historical_version
      await db.execute('''
        UPDATE $_tableStateDownloads
        SET historical_version = (
          SELECT data_version FROM $_tableHistoricalPlacesDownloads
          WHERE $_tableHistoricalPlacesDownloads.state_code = $_tableStateDownloads.state_code
        )
        WHERE EXISTS (
          SELECT 1 FROM $_tableHistoricalPlacesDownloads
          WHERE $_tableHistoricalPlacesDownloads.state_code = $_tableStateDownloads.state_code
        )
      ''');

      debugPrint('v6 migration complete');
    }

    if (oldVersion < 8) {
      // v8: Ensure per-type version columns exist (fix for fresh v7 databases)
      // These columns may be missing if the database was created fresh at v7
      debugPrint('Migrating to v8: Ensuring per-type version columns exist...');

      try {
        await db.execute('ALTER TABLE $_tableStateDownloads ADD COLUMN land_version TEXT');
      } catch (e) {
        // Column already exists
      }

      try {
        await db.execute('ALTER TABLE $_tableStateDownloads ADD COLUMN trails_version TEXT');
      } catch (e) {
        // Column already exists
      }

      try {
        await db.execute('ALTER TABLE $_tableStateDownloads ADD COLUMN historical_version TEXT');
      } catch (e) {
        // Column already exists
      }

      try {
        await db.execute('ALTER TABLE $_tableStateDownloads ADD COLUMN historical_places_count INTEGER DEFAULT 0');
      } catch (e) {
        // Column already exists
      }

      debugPrint('v8 migration complete');
    }

    if (oldVersion < 9) {
      // v9: Add category column to historical places for category-based filtering
      debugPrint('Migrating to v9: Adding category column to historical places...');

      try {
        await db.execute("ALTER TABLE $_tableHistoricalPlaces ADD COLUMN category TEXT NOT NULL DEFAULT 'unknown'");
      } catch (e) {
        // Column already exists
      }

      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_hist_places_category ON $_tableHistoricalPlaces (category)');
      } catch (e) {
        // Index already exists
      }

      debugPrint('v9 migration complete');
    }

    if (oldVersion < 10) {
      // v10: Add cell towers table for cell coverage overlay (OpenCelliD data)
      debugPrint('Migrating to v10: Adding cell towers support...');

      // Create cell towers table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableCellTowers (
          id TEXT PRIMARY KEY,
          radio_type TEXT NOT NULL,
          mcc INTEGER NOT NULL,
          mnc INTEGER NOT NULL,
          carrier TEXT,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          range_meters INTEGER NOT NULL,
          samples INTEGER DEFAULT 0,
          last_updated INTEGER,
          state_code TEXT NOT NULL,
          cached_at INTEGER NOT NULL
        )
      ''');

      // Add indexes for cell towers
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cell_towers_state ON $_tableCellTowers (state_code)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cell_towers_radio ON $_tableCellTowers (radio_type)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cell_towers_location ON $_tableCellTowers (latitude, longitude)');

      // Add cell_version and cell_tower_count to state_downloads
      try {
        await db.execute('ALTER TABLE $_tableStateDownloads ADD COLUMN cell_version TEXT');
      } catch (e) {
        // Column already exists
      }
      try {
        await db.execute('ALTER TABLE $_tableStateDownloads ADD COLUMN cell_tower_count INTEGER DEFAULT 0');
      } catch (e) {
        // Column already exists
      }

      debugPrint('v10 migration complete');
    }
  }

  /// Cache land rights data for offline use
  Future<void> cacheProperties(List<ComprehensiveLandOwnership> properties) async {
    final db = await _getDatabase();
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    final expires = now + _cacheExpiration.inMilliseconds;
    
    for (final property in properties) {
      // Calculate bounding box for spatial queries
      final bbox = _calculateBoundingBox(property.bestBoundaries);
      
      // Insert or replace property data
      batch.insert(
        _tableProperties,
        {
          'id': property.id,
          'owner_name': property.ownerName,
          'ownership_type': property.ownershipType,
          'legal_description': property.legalDescription,
          'acreage': property.acreage,
          'data_source': property.dataSource,
          'last_updated': property.lastUpdated?.toIso8601String(),
          'activity_permissions': jsonEncode(property.activityPermissions.toJson()),
          'access_rights': jsonEncode(property.accessRights.toJson()),
          'owner_contact': property.ownerContact != null 
              ? jsonEncode(property.ownerContact!.toJson()) 
              : null,
          'agency_name': property.agencyName,
          'unit_name': property.unitName,
          'designation': property.designation,
          'access_type': property.accessType,
          'allowed_uses': jsonEncode(property.allowedUses),
          'restrictions': jsonEncode(property.restrictions),
          'contact_info': property.contactInfo,
          'website': property.website,
          'fees': property.fees,
          'seasonal_info': property.seasonalInfo,
          'cached_at': now,
          'cache_expires': expires,
          'center_lat': bbox.centerLat,
          'center_lon': bbox.centerLon,
          'bbox_north': bbox.north,
          'bbox_south': bbox.south,
          'bbox_east': bbox.east,
          'bbox_west': bbox.west,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // Cache all 5-level LOD boundaries separately
      if (property.boundaries != null) {
        batch.insert(
          _tableBoundaries,
          {
            'property_id': property.id,
            'boundary_type': 'full',
            'coordinates': jsonEncode(property.boundaries),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (property.highBoundaries != null) {
        batch.insert(
          _tableBoundaries,
          {
            'property_id': property.id,
            'boundary_type': 'high',
            'coordinates': jsonEncode(property.highBoundaries),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (property.mediumBoundaries != null) {
        batch.insert(
          _tableBoundaries,
          {
            'property_id': property.id,
            'boundary_type': 'medium',
            'coordinates': jsonEncode(property.mediumBoundaries),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (property.lowBoundaries != null) {
        batch.insert(
          _tableBoundaries,
          {
            'property_id': property.id,
            'boundary_type': 'low',
            'coordinates': jsonEncode(property.lowBoundaries),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (property.overviewBoundaries != null) {
        batch.insert(
          _tableBoundaries,
          {
            'property_id': property.id,
            'boundary_type': 'overview',
            'coordinates': jsonEncode(property.overviewBoundaries),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    
    await batch.commit();
    debugPrint('Cached ${properties.length} properties for offline use');
  }
  
  /// Query cached properties by GPS location
  Future<List<ComprehensiveLandOwnership>> queryOfflineProperties({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
    int limit = 50,
  }) async {
    final db = await _getDatabase();
    
    // Convert radius to approximate degrees (rough approximation)
    final latDegrees = radiusKm / 111.0;
    final lonDegrees = radiusKm / (111.0 * math.cos(latitude * math.pi / 180));
    
    // Query properties within bounding box
    final results = await db.query(
      _tableProperties,
      where: '''
        bbox_north >= ? AND bbox_south <= ? AND
        bbox_east >= ? AND bbox_west <= ? AND
        cache_expires > ?
      ''',
      whereArgs: [
        latitude - latDegrees,
        latitude + latDegrees,
        longitude - lonDegrees,
        longitude + lonDegrees,
        DateTime.now().millisecondsSinceEpoch,
      ],
      limit: limit,
      orderBy: '''
        ((center_lat - ?)*(center_lat - ?) + 
         (center_lon - ?)*(center_lon - ?)) ASC
      ''',
    );
    
    // Convert results to domain models
    final properties = <ComprehensiveLandOwnership>[];
    for (final row in results) {
      final property = await _rowToProperty(row);
      if (property != null) {
        properties.add(property);
      }
    }
    
    debugPrint('Found ${properties.length} cached properties near ($latitude, $longitude)');
    return properties;
  }

  /// Query cached properties by bounding box (for map viewport)
  /// This is the primary method for map land data lookups
  /// If [stateCode] is provided, only returns properties from that state
  /// (prevents data from "bleeding" into neighboring states when zoomed out)
  Future<List<ComprehensiveLandOwnership>> queryPropertiesForBounds({
    required double northBound,
    required double southBound,
    required double eastBound,
    required double westBound,
    int limit = 1000,
    double? zoomLevel,
    String? stateCode,
  }) async {
    final db = await _getDatabase();

    // Calculate viewport size for context
    final viewportHeight = northBound - southBound;
    final viewportWidth = (eastBound - westBound).abs();
    final viewportAreaSqDeg = viewportHeight * viewportWidth;

    // Debug: Log query bounds with size context
    debugPrint('🔍 SQLite Query:');
    debugPrint('   Viewport: N=${northBound.toStringAsFixed(4)}, S=${southBound.toStringAsFixed(4)}, E=${eastBound.toStringAsFixed(4)}, W=${westBound.toStringAsFixed(4)}');
    debugPrint('   Viewport size: ${viewportHeight.toStringAsFixed(4)}° × ${viewportWidth.toStringAsFixed(4)}° = ${viewportAreaSqDeg.toStringAsFixed(6)} sq°');
    if (stateCode != null) {
      debugPrint('   State filter: $stateCode');
    }

    // Query properties that intersect with the viewport bounds
    // A property intersects if its bbox overlaps with the viewport
    // Filter by state_code to prevent properties from appearing in neighboring states
    final whereClause = stateCode != null
        ? '''
          bbox_north >= ? AND bbox_south <= ? AND
          bbox_east >= ? AND bbox_west <= ? AND
          cache_expires > ? AND
          state_code = ?
        '''
        : '''
          bbox_north >= ? AND bbox_south <= ? AND
          bbox_east >= ? AND bbox_west <= ? AND
          cache_expires > ?
        ''';

    final whereArgs = [
      southBound, // Property's north must be >= viewport's south
      northBound, // Property's south must be <= viewport's north
      westBound,  // Property's east must be >= viewport's west
      eastBound,  // Property's west must be <= viewport's east
      DateTime.now().millisecondsSinceEpoch,
      if (stateCode != null) stateCode,
    ];

    final results = await db.query(
      _tableProperties,
      where: whereClause,
      whereArgs: whereArgs,
      limit: limit,
    );

    // Debug: If no results, check what NPS properties exist near this area
    if (results.isEmpty) {
      final npsResults = await db.query(
        _tableProperties,
        columns: ['id', 'owner_name', 'unit_name', 'bbox_north', 'bbox_south', 'bbox_east', 'bbox_west'],
        where: 'owner_name = ?',
        whereArgs: ['NPS'],
        limit: 5,
      );
      if (npsResults.isNotEmpty) {
        debugPrint('🔍 SQLite Debug: Found ${npsResults.length} NPS properties in DB. Sample:');
        for (final nps in npsResults) {
          debugPrint('   - ${nps['unit_name'] ?? nps['id']}: N=${nps['bbox_north']}, S=${nps['bbox_south']}, E=${nps['bbox_east']}, W=${nps['bbox_west']}');
        }
      } else {
        final totalCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $_tableProperties'));
        debugPrint('🔍 SQLite Debug: No NPS properties in DB. Total properties: $totalCount');
      }
    }

    // Convert results to domain models
    // MEMORY SAFETY: Filter out oversized parcels and enforce coordinate budget
    final properties = <ComprehensiveLandOwnership>[];
    int totalCoordinates = 0;
    final parcelStats = <String>[]; // Track individual parcel sizes
    final oversizedParcels = <String>[]; // Track parcels much larger than viewport
    final skippedParcels = <String>[]; // Track parcels we skipped for safety

    // Memory safety thresholds for Alaska-scale parcels
    // Alaska Maritime NWR: 20,000,000x viewport, 1.1M coords - MUST skip
    // USFS Chugach NF: 37,276x viewport, 309K coords - should show (within budget)
    const int maxCoordinateBudget = 500000; // 500K coords max (~15MB) - total across all parcels
    const double maxBboxRatio = 100000.0; // Skip parcels 100,000x larger than viewport (if viewport not inside)
    const int largeParcelThreshold = 10000; // For logging only

    // Calculate viewport center for "inside parcel" check
    final viewportCenterLat = (northBound + southBound) / 2;
    final viewportCenterLon = (eastBound + westBound) / 2;

    // PASS 1: Filter rows by bbox size and collect property IDs for batch boundary fetch
    final filteredRows = <Map<String, dynamic>>[];
    final propertyIds = <String>[];

    for (final row in results) {
      final parcelN = row['bbox_north'] as double? ?? 0;
      final parcelS = row['bbox_south'] as double? ?? 0;
      final parcelE = row['bbox_east'] as double? ?? 0;
      final parcelW = row['bbox_west'] as double? ?? 0;
      final parcelHeight = parcelN - parcelS;
      final parcelWidth = (parcelE - parcelW).abs();
      final parcelAreaSqDeg = parcelHeight * parcelWidth;
      final bboxRatio = viewportAreaSqDeg > 0 ? parcelAreaSqDeg / viewportAreaSqDeg : 0;

      // Check if viewport center is INSIDE this parcel's bbox
      final viewportInsideParcel = viewportCenterLat >= parcelS &&
          viewportCenterLat <= parcelN &&
          viewportCenterLon >= parcelW &&
          viewportCenterLon <= parcelE;

      // SKIP CHECK: Don't load geometry for massively oversized parcels
      if (bboxRatio > maxBboxRatio && !viewportInsideParcel) {
        final ownerName = row['owner_name'] as String? ?? 'Unknown';
        final unitName = row['unit_name'] as String? ?? '';
        skippedParcels.add(
          '$ownerName $unitName: bbox=${parcelHeight.toStringAsFixed(1)}°×${parcelWidth.toStringAsFixed(1)}° '
          '(${bboxRatio.toStringAsFixed(0)}x viewport) - SKIPPED'
        );
        continue;
      }

      filteredRows.add(row);
      propertyIds.add(row['id']! as String);
    }

    // BATCH FETCH: Get all boundaries in ONE query instead of N queries
    // This is a MAJOR performance optimization (O(1) vs O(N) database calls)
    final boundariesMap = await _batchFetchBoundaries(propertyIds);

    // ISOLATE PARSING: Parse all coordinate JSON strings off the main thread
    // This prevents jank during map panning by moving heavy JSON parsing to isolate
    final allCoordJsonStrings = <String?>[];
    final coordJsonIndex = <String, Map<String, int>>{}; // propertyId -> {boundaryType -> index}

    for (final propertyId in propertyIds) {
      final boundaryRows = boundariesMap[propertyId];
      coordJsonIndex[propertyId] = {};
      if (boundaryRows != null) {
        for (final row in boundaryRows) {
          final boundaryType = row['boundary_type'] as String?;
          final coords = row['coordinates'] as String?;
          if (boundaryType != null) {
            coordJsonIndex[propertyId]![boundaryType] = allCoordJsonStrings.length;
            allCoordJsonStrings.add(coords);
          }
        }
      }
    }

    // Parse all coordinates in isolate (off main thread)
    List<List<List<List<double>>>?> parsedCoords;
    if (allCoordJsonStrings.length > 10) {
      // Only use isolate for significant workloads (isolate spawn has overhead)
      parsedCoords = await compute(_parseCoordinatesInIsolate, allCoordJsonStrings);
    } else {
      // For small workloads, parse inline (faster than isolate overhead)
      parsedCoords = _parseCoordinatesInIsolate(allCoordJsonStrings);
    }

    // PASS 2: Convert to properties using pre-parsed coordinates
    for (final row in filteredRows) {
      final propertyId = row['id'] as String;
      final propCoordIndex = coordJsonIndex[propertyId] ?? {};

      // Try preferred LOD first, then fall back to simpler LODs if budget exceeded
      ComprehensiveLandOwnership? property;
      int parcelCoords = 0;
      String? usedLod;

      // LOD fallback chain: full -> simplified -> overview
      final lodChain = <double?>[zoomLevel, 10.0, 5.0]; // zoom >= 12 = full, >= 9 = simplified, < 9 = overview

      for (final lodZoom in lodChain) {
        property = _rowToPropertyWithParsedCoords(
          row,
          propCoordIndex,
          parsedCoords,
          lodZoom,
          viewportNorth: northBound,
          viewportSouth: southBound,
          viewportEast: eastBound,
          viewportWest: westBound,
        );

        if (property == null) continue;

        // Count coordinates for this LOD
        parcelCoords = 0;
        final coords = property.bestBoundaries;
        if (coords != null) {
          for (final ring in coords) {
            parcelCoords += ring.length;
          }
        }

        // If fits in budget, use this LOD
        if (totalCoordinates + parcelCoords <= maxCoordinateBudget) {
          usedLod = _getLodTypeForZoom(lodZoom);
          break;
        }

        // Didn't fit - try next simpler LOD
        property = null;
      }

      if (property != null) {
        // Log if we had to fall back to a simpler LOD
        final preferredLod = _getLodTypeForZoom(zoomLevel);
        if (usedLod != null && usedLod != preferredLod) {
          debugPrint('📉 LOD fallback for ${property.ownerName} ${property.unitName ?? ''}: $preferredLod -> $usedLod ($parcelCoords coords)');
        }

        totalCoordinates += parcelCoords;

        // Calculate parcel size for logging
        final parcelN = row['bbox_north'] as double? ?? 0;
        final parcelS = row['bbox_south'] as double? ?? 0;
        final parcelE = row['bbox_east'] as double? ?? 0;
        final parcelW = row['bbox_west'] as double? ?? 0;
        final parcelHeight = parcelN - parcelS;
        final parcelWidth = (parcelE - parcelW).abs();
        final parcelAreaSqDeg = parcelHeight * parcelWidth;
        final bboxRatio = viewportAreaSqDeg > 0 ? parcelAreaSqDeg / viewportAreaSqDeg : 0;

        // Track parcels that are MUCH larger than the viewport (10x+)
        if (parcelAreaSqDeg > viewportAreaSqDeg * 10 && parcelCoords > 5000) {
          oversizedParcels.add(
            '${property.ownerName} ${property.unitName ?? ''}: '
            'bbox=${parcelHeight.toStringAsFixed(2)}°×${parcelWidth.toStringAsFixed(2)}° '
            '(${bboxRatio.toStringAsFixed(0)}x viewport), '
            '$parcelCoords coords'
          );
        }

        // Track large parcels for debugging
        if (parcelCoords > largeParcelThreshold) {
          parcelStats.add('${property.ownerName} ${property.unitName ?? property.id}: $parcelCoords coords');
        }

        properties.add(property);
      } else {
        // All LODs exceeded budget - skip this parcel
        final ownerName = row['owner_name'] as String? ?? 'Unknown';
        final unitName = row['unit_name'] as String? ?? '';
        skippedParcels.add(
          '$ownerName $unitName: ALL LODs exceeded budget - SKIPPED'
        );
      }
    }

    // Detailed diagnostic logging
    final viewportArea = (northBound - southBound) * (eastBound - westBound).abs();
    final estimatedMemoryMB = (totalCoordinates * 32) / (1024 * 1024);

    debugPrint('📦 SQLite Query Results:');
    debugPrint('   Viewport: ${viewportArea.toStringAsFixed(4)} sq° (N:${northBound.toStringAsFixed(4)}, S:${southBound.toStringAsFixed(4)}, E:${eastBound.toStringAsFixed(4)}, W:${westBound.toStringAsFixed(4)})');
    debugPrint('   Parcels returned: ${properties.length}');
    debugPrint('   Total coordinates: $totalCoordinates');
    debugPrint('   Estimated memory: ${estimatedMemoryMB.toStringAsFixed(1)} MB');

    if (parcelStats.isNotEmpty) {
      debugPrint('   ⚠️ Large parcels (>10k coords):');
      for (final stat in parcelStats.take(10)) {
        debugPrint('      - $stat');
      }
      if (parcelStats.length > 10) {
        debugPrint('      ... and ${parcelStats.length - 10} more large parcels');
      }
    }

    // Show oversized parcels that were still included
    if (oversizedParcels.isNotEmpty) {
      debugPrint('   🎯 OVERSIZED PARCELS (bbox >> viewport, still included):');
      for (final stat in oversizedParcels.take(5)) {
        debugPrint('      - $stat');
      }
      if (oversizedParcels.length > 5) {
        debugPrint('      ... and ${oversizedParcels.length - 5} more oversized parcels');
      }
    }

    // Show skipped parcels (MEMORY SAFETY)
    if (skippedParcels.isNotEmpty) {
      debugPrint('   🛡️ SKIPPED FOR MEMORY SAFETY (${skippedParcels.length} parcels):');
      for (final stat in skippedParcels.take(5)) {
        debugPrint('      - $stat');
      }
      if (skippedParcels.length > 5) {
        debugPrint('      ... and ${skippedParcels.length - 5} more skipped');
      }
      debugPrint('   ✅ Skipping prevents OOM crash from massive Alaska parcels');
    }

    // MEMORY WARNING (should be rare now with filtering)
    if (estimatedMemoryMB > 50) {
      debugPrint('🚨 MEMORY WARNING: ${estimatedMemoryMB.toStringAsFixed(1)} MB of polygon data - consider lowering thresholds');
    }

    return properties;
  }

  /// Check if viewport center is in a downloaded state
  /// Simple approach: if center is in a downloaded state, use local data
  Future<String?> getDownloadedStateForLocation(double latitude, double longitude) async {
    final stateCode = _getStateForLocation(latitude, longitude);
    if (stateCode == null) return null;

    final isDownloaded = await isStateDownloaded(stateCode);
    if (isDownloaded) {
      debugPrint('📦 SQLite: Location is in downloaded state $stateCode');
      return stateCode;
    }
    return null;
  }

  /// Determine which US state a lat/lon is in (simplified bounding box check)
  String? _getStateForLocation(double latitude, double longitude) {
    // State bounding boxes - matches DynamicLandDataService.availableStates
    const stateBounds = {
      'CA': {'north': 42.01, 'south': 32.53, 'east': -114.13, 'west': -124.48},
      'NV': {'north': 42.00, 'south': 35.00, 'east': -114.04, 'west': -120.00},
      'AZ': {'north': 37.00, 'south': 31.33, 'east': -109.05, 'west': -114.82},
      'OR': {'north': 46.29, 'south': 41.99, 'east': -116.46, 'west': -124.57},
      'WA': {'north': 49.00, 'south': 45.54, 'east': -116.92, 'west': -124.73},
      'CO': {'north': 41.00, 'south': 36.99, 'east': -102.04, 'west': -109.06},
      'UT': {'north': 42.00, 'south': 36.99, 'east': -109.05, 'west': -114.05},
      'ID': {'north': 49.00, 'south': 41.99, 'east': -111.04, 'west': -117.24},
      'MT': {'north': 49.00, 'south': 44.36, 'east': -104.04, 'west': -116.05},
      'WY': {'north': 45.01, 'south': 40.99, 'east': -104.05, 'west': -111.05},
      'NM': {'north': 37.00, 'south': 31.33, 'east': -103.00, 'west': -109.05},
      'SD': {'north': 45.95, 'south': 42.48, 'east': -96.44, 'west': -104.06},
      'TX': {'north': 36.50, 'south': 25.84, 'east': -93.51, 'west': -106.65},
      'AK': {'north': 71.50, 'south': 51.21, 'east': -129.99, 'west': -179.15},
      // Note: Hawaii excluded - no OSM trail data available
    };

    for (final entry in stateBounds.entries) {
      final bounds = entry.value;
      if (latitude <= bounds['north']! &&
          latitude >= bounds['south']! &&
          longitude <= bounds['east']! &&
          longitude >= bounds['west']!) {
        return entry.key;
      }
    }
    return null;
  }

  /// Download and cache properties for an area
  Future<OfflineDownloadResult> downloadAreaForOffline({
    required double centerLat,
    required double centerLon,
    double radiusKm = 10.0,
    required Future<List<ComprehensiveLandOwnership>> Function(double, double, double, double) fetchFunction,
  }) async {
    try {
      // Calculate bounding box for download area
      final latDegrees = radiusKm / 111.0;
      final lonDegrees = radiusKm / (111.0 * math.cos(centerLat * math.pi / 180));
      
      final north = centerLat + latDegrees;
      final south = centerLat - latDegrees;
      final east = centerLon + lonDegrees;
      final west = centerLon - lonDegrees;
      
      // Fetch properties from server
      final properties = await fetchFunction(north, south, east, west);
      
      // Cache properties
      await cacheProperties(properties);
      
      // Record download area
      final db = await _getDatabase();
      await db.insert(_tableDownloads, {
        'center_lat': centerLat,
        'center_lon': centerLon,
        'radius_km': radiusKm,
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
        'expires_at': DateTime.now().add(_cacheExpiration).millisecondsSinceEpoch,
        'property_count': properties.length,
        'total_size_bytes': _estimateDataSize(properties),
      });
      
      return OfflineDownloadResult(
        success: true,
        propertyCount: properties.length,
        areaSizeKm2: math.pi * radiusKm * radiusKm,
        expiresAt: DateTime.now().add(_cacheExpiration),
      );
      
    } catch (e) {
      debugPrint('Failed to download area for offline: $e');
      return OfflineDownloadResult(
        success: false,
        error: e.toString(),
      );
    }
  }
  
  /// Get offline download statistics
  Future<OfflineStatistics> getOfflineStatistics() async {
    final db = await _getDatabase();
    
    // Count cached properties
    final propertyCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableProperties WHERE cache_expires > ?', 
        [DateTime.now().millisecondsSinceEpoch]),
    ) ?? 0;
    
    // Count download areas
    final downloadCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableDownloads WHERE expires_at > ?',
        [DateTime.now().millisecondsSinceEpoch]),
    ) ?? 0;
    
    // Calculate total cache size
    final totalSize = Sqflite.firstIntValue(
      await db.rawQuery('SELECT SUM(total_size_bytes) FROM $_tableDownloads WHERE expires_at > ?',
        [DateTime.now().millisecondsSinceEpoch]),
    ) ?? 0;
    
    return OfflineStatistics(
      cachedProperties: propertyCount,
      downloadedAreas: downloadCount,
      totalCacheSizeBytes: totalSize,
      oldestCache: await _getOldestCacheDate(),
      newestCache: await _getNewestCacheDate(),
    );
  }
  
  /// Check if a location has offline data available
  Future<bool> hasOfflineData(double latitude, double longitude) async {
    final properties = await queryOfflineProperties(
      latitude: latitude,
      longitude: longitude,
      radiusKm: 0.5, // Check within 500m
      limit: 1,
    );
    return properties.isNotEmpty;
  }
  
  /// Clear expired cache entries
  Future<void> _cleanExpiredCache() async {
    final db = await _getDatabase();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Delete expired properties
    final deletedProperties = await db.delete(
      _tableProperties,
      where: 'cache_expires < ?',
      whereArgs: [now],
    );
    
    // Delete expired downloads
    final deletedDownloads = await db.delete(
      _tableDownloads,
      where: 'expires_at < ?',
      whereArgs: [now],
    );
    
    if (deletedProperties > 0 || deletedDownloads > 0) {
      debugPrint('Cleaned expired cache: $deletedProperties properties, $deletedDownloads downloads');
    }
  }
  
  /// Clear all offline cache
  Future<void> clearAllCache() async {
    final db = await _getDatabase();
    await db.delete(_tableProperties);
    await db.delete(_tableBoundaries);
    await db.delete(_tableDownloads);
    await db.delete(_tableStateDownloads);
    await db.delete(_tableTrails);
    debugPrint('Cleared all offline land rights cache');
  }

  // ============================================================================
  // STATE-BASED BULK DOWNLOAD METHODS (v1.4.0)
  // ============================================================================

  /// Cache bulk state data from BFF download
  ///
  /// Efficiently handles 20,000+ properties using batch inserts.
  /// Uses transactions for atomicity and performance.
  Future<void> cacheStateData({
    required String stateCode,
    required String stateName,
    required String dataVersion,
    required List<ComprehensiveLandOwnership> properties,
    void Function(double progress, String message)? onProgress,
  }) async {
    final db = await _getDatabase();
    final now = DateTime.now().millisecondsSinceEpoch;
    // Version-based expiry: effectively never expires (100 years)
    // Data is invalidated by version check, not time
    final expires = now + const Duration(days: 36500).inMilliseconds;

    final totalProperties = properties.length;
    debugPrint('📦 Caching $totalProperties properties for $stateCode ($dataVersion)...');
    onProgress?.call(0.0, 'Preparing to cache $totalProperties properties...');

    // Log owner name distribution for incoming properties
    final ownerCounts = <String, int>{};
    var nullBoundaryCount = 0;
    for (final p in properties) {
      ownerCounts[p.ownerName] = (ownerCounts[p.ownerName] ?? 0) + 1;
      if (p.bestBoundaries == null || p.bestBoundaries!.isEmpty) {
        nullBoundaryCount++;
      }
    }
    debugPrint('📊 SQLite Import - Owner distribution:');
    final sorted = ownerCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted.take(10)) {
      debugPrint('   ${e.key}: ${e.value}');
    }
    debugPrint('📊 SQLite Import - Properties with null/empty boundaries: $nullBoundaryCount');

    try {
      // Use transaction for atomicity and performance
      await db.transaction((txn) async {
        // First, delete any existing data for this state
        onProgress?.call(0.05, 'Clearing old $stateCode data...');
        await txn.delete(
          _tableProperties,
          where: 'state_code = ?',
          whereArgs: [stateCode],
        );

        // Delete old boundaries for this state's properties
        await txn.rawDelete('''
          DELETE FROM $_tableBoundaries
          WHERE property_id IN (
            SELECT id FROM $_tableProperties WHERE state_code = ?
          )
        ''', [stateCode]);

        // Insert properties in batches of 500 for optimal performance
        const batchSize = 500;
        var processed = 0;

        // Track NPS properties and Craters coverage
        var npsCount = 0;
        var npsValidBboxCount = 0;
        final cratersAreaProperties = <String>[];
        const cratersLat = 43.17;
        const cratersLon = -113.48;
        const cratersSearchRadius = 0.5; // ~50km radius in degrees

        for (var i = 0; i < properties.length; i += batchSize) {
          final batch = txn.batch();
          final end = math.min(i + batchSize, properties.length);

          for (var j = i; j < end; j++) {
            final property = properties[j];
            // Pass debug name for NPS properties to trace bbox calculation issues
            final debugName = property.ownerName == 'NPS' ? '${property.ownerName} ${property.unitName ?? property.id}' : null;
            final bbox = _calculateBoundingBox(property.bestBoundaries, debugName: debugName);

            // Debug: Track properties with zero bounding boxes
            if (bbox.north == 0 && bbox.south == 0 && bbox.east == 0 && bbox.west == 0) {
              if (j < 5 || property.ownerName == 'NPS') {
                debugPrint('⚠️ SQLite Import: Property ${property.id} (${property.ownerName}) has zero bbox - bestBoundaries is ${property.bestBoundaries == null ? "null" : "non-null with ${property.bestBoundaries!.length} rings"}');
              }
            }

            // Debug: Log bbox for NPS properties to verify storage
            if (property.ownerName == 'NPS') {
              npsCount++;
              final isValidBbox = bbox.north != bbox.south && bbox.east != bbox.west && bbox.north != 0;
              if (isValidBbox) npsValidBboxCount++;
              debugPrint('📍 SQLite Import: NPS ${property.unitName ?? property.id} bbox: N=${bbox.north.toStringAsFixed(4)}, S=${bbox.south.toStringAsFixed(4)}, E=${bbox.east.toStringAsFixed(4)}, W=${bbox.west.toStringAsFixed(4)} ${isValidBbox ? "✓" : "⚠️ DEGENERATE"}');
            }

            // Check if this property covers the Craters of the Moon area
            if (bbox.north >= cratersLat - cratersSearchRadius &&
                bbox.south <= cratersLat + cratersSearchRadius &&
                bbox.east >= cratersLon - cratersSearchRadius &&
                bbox.west <= cratersLon + cratersSearchRadius) {
              cratersAreaProperties.add('${property.ownerName}: ${property.unitName ?? property.id}');
            }

            batch.insert(
              _tableProperties,
              {
                'id': property.id,
                'owner_name': property.ownerName,
                'ownership_type': property.ownershipType,
                'legal_description': property.legalDescription,
                'acreage': property.acreage,
                'data_source': property.dataSource,
                'last_updated': property.lastUpdated?.toIso8601String(),
                'activity_permissions': jsonEncode(property.activityPermissions.toJson()),
                'access_rights': jsonEncode(property.accessRights.toJson()),
                'owner_contact': property.ownerContact != null
                    ? jsonEncode(property.ownerContact!.toJson())
                    : null,
                'agency_name': property.agencyName,
                'unit_name': property.unitName,
                'designation': property.designation,
                'access_type': property.accessType,
                'allowed_uses': jsonEncode(property.allowedUses),
                'restrictions': jsonEncode(property.restrictions),
                'contact_info': property.contactInfo,
                'website': property.website,
                'fees': property.fees,
                'seasonal_info': property.seasonalInfo,
                'cached_at': now,
                'cache_expires': expires,
                'state_code': stateCode,
                'data_version': dataVersion,
                'center_lat': bbox.centerLat,
                'center_lon': bbox.centerLon,
                'bbox_north': bbox.north,
                'bbox_south': bbox.south,
                'bbox_east': bbox.east,
                'bbox_west': bbox.west,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            // Cache all 5-level LOD boundaries
            if (property.boundaries != null) {
              batch.insert(
                _tableBoundaries,
                {
                  'property_id': property.id,
                  'boundary_type': 'full',
                  'coordinates': jsonEncode(property.boundaries),
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }

            if (property.highBoundaries != null) {
              batch.insert(
                _tableBoundaries,
                {
                  'property_id': property.id,
                  'boundary_type': 'high',
                  'coordinates': jsonEncode(property.highBoundaries),
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }

            if (property.mediumBoundaries != null) {
              batch.insert(
                _tableBoundaries,
                {
                  'property_id': property.id,
                  'boundary_type': 'medium',
                  'coordinates': jsonEncode(property.mediumBoundaries),
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }

            if (property.lowBoundaries != null) {
              batch.insert(
                _tableBoundaries,
                {
                  'property_id': property.id,
                  'boundary_type': 'low',
                  'coordinates': jsonEncode(property.lowBoundaries),
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }

            if (property.overviewBoundaries != null) {
              batch.insert(
                _tableBoundaries,
                {
                  'property_id': property.id,
                  'boundary_type': 'overview',
                  'coordinates': jsonEncode(property.overviewBoundaries),
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }

          await batch.commit(noResult: true);
          processed = end;

          final progress = 0.1 + (0.85 * processed / totalProperties);
          onProgress?.call(progress, 'Cached $processed of $totalProperties properties...');
        }

        // Log NPS and Craters summary
        debugPrint('📊 NPS Summary: $npsCount total, $npsValidBboxCount with valid bbox');
        if (cratersAreaProperties.isNotEmpty) {
          debugPrint('🌋 Craters of the Moon area properties (${cratersAreaProperties.length}):');
          for (final prop in cratersAreaProperties.take(10)) {
            debugPrint('   - $prop');
          }
        } else {
          debugPrint('🌋 Craters of the Moon area: NO PROPERTIES FOUND covering lat=$cratersLat, lon=$cratersLon');
        }

        // Record the state download
        onProgress?.call(0.95, 'Finalizing download record...');
        await txn.insert(
          _tableStateDownloads,
          {
            'state_code': stateCode,
            'state_name': stateName,
            'data_version': dataVersion,
            'property_count': totalProperties,
            'total_size_bytes': _estimateDataSize(properties),
            'downloaded_at': now,
            'status': 'complete',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });

      onProgress?.call(1.0, 'Complete! Cached $totalProperties properties.');
      debugPrint('✅ Cached $totalProperties properties for $stateCode ($dataVersion)');

    } catch (e) {
      debugPrint('❌ Failed to cache state data for $stateCode: $e');
      rethrow;
    }
  }

  // ============================================================================
  // STREAMING STATE DOWNLOAD METHODS (v1.4.1 - Memory-efficient for large states)
  // ============================================================================

  /// Prepare for streaming state download by clearing old data
  ///
  /// Call this BEFORE starting to insert batches.
  /// Returns the database instance for use in batch inserts.
  Future<void> prepareStateStreamingDownload({
    required String stateCode,
  }) async {
    final db = await _getDatabase();

    debugPrint('📦 Preparing streaming download for $stateCode...');

    // Delete any existing data for this state
    await db.delete(
      _tableProperties,
      where: 'state_code = ?',
      whereArgs: [stateCode],
    );

    // Delete old state download record
    await db.delete(
      _tableStateDownloads,
      where: 'state_code = ?',
      whereArgs: [stateCode],
    );

    debugPrint('📦 Cleared old data for $stateCode, ready for streaming insert');
  }

  /// Insert a batch of properties during streaming download
  ///
  /// This method is memory-efficient - call it repeatedly with small batches
  /// (e.g., 20-50 records) to avoid accumulating all records in memory.
  Future<void> insertPropertyBatchStreaming({
    required String stateCode,
    required String dataVersion,
    required List<ComprehensiveLandOwnership> batch,
  }) async {
    if (batch.isEmpty) return;

    final db = await _getDatabase();
    final now = DateTime.now().millisecondsSinceEpoch;
    // Version-based expiry: effectively never expires (100 years)
    final expires = now + const Duration(days: 36500).inMilliseconds;

    final dbBatch = db.batch();

    for (final property in batch) {
      final bbox = _calculateBoundingBox(property.bestBoundaries);

      dbBatch.insert(
        _tableProperties,
        {
          'id': property.id,
          'owner_name': property.ownerName,
          'ownership_type': property.ownershipType,
          'legal_description': property.legalDescription,
          'acreage': property.acreage,
          'data_source': property.dataSource,
          'last_updated': property.lastUpdated?.toIso8601String(),
          'activity_permissions': jsonEncode(property.activityPermissions.toJson()),
          'access_rights': jsonEncode(property.accessRights.toJson()),
          'owner_contact': property.ownerContact != null
              ? jsonEncode(property.ownerContact!.toJson())
              : null,
          'agency_name': property.agencyName,
          'unit_name': property.unitName,
          'designation': property.designation,
          'access_type': property.accessType,
          'allowed_uses': jsonEncode(property.allowedUses),
          'restrictions': jsonEncode(property.restrictions),
          'contact_info': property.contactInfo,
          'website': property.website,
          'fees': property.fees,
          'seasonal_info': property.seasonalInfo,
          'cached_at': now,
          'cache_expires': expires,
          'state_code': stateCode,
          'data_version': dataVersion,
          'center_lat': bbox.centerLat,
          'center_lon': bbox.centerLon,
          'bbox_north': bbox.north,
          'bbox_south': bbox.south,
          'bbox_east': bbox.east,
          'bbox_west': bbox.west,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Cache all 5-level LOD boundaries
      if (property.boundaries != null) {
        dbBatch.insert(
          _tableBoundaries,
          {
            'property_id': property.id,
            'boundary_type': 'full',
            'coordinates': jsonEncode(property.boundaries),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (property.highBoundaries != null) {
        dbBatch.insert(
          _tableBoundaries,
          {
            'property_id': property.id,
            'boundary_type': 'high',
            'coordinates': jsonEncode(property.highBoundaries),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (property.mediumBoundaries != null) {
        dbBatch.insert(
          _tableBoundaries,
          {
            'property_id': property.id,
            'boundary_type': 'medium',
            'coordinates': jsonEncode(property.mediumBoundaries),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (property.lowBoundaries != null) {
        dbBatch.insert(
          _tableBoundaries,
          {
            'property_id': property.id,
            'boundary_type': 'low',
            'coordinates': jsonEncode(property.lowBoundaries),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (property.overviewBoundaries != null) {
        dbBatch.insert(
          _tableBoundaries,
          {
            'property_id': property.id,
            'boundary_type': 'overview',
            'coordinates': jsonEncode(property.overviewBoundaries),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    await dbBatch.commit(noResult: true);
  }

  /// Finalize streaming state download by recording the download metadata
  ///
  /// Call this AFTER all batches have been inserted.
  /// Per-type versions (landVersion, trailsVersion) enable selective updates.
  Future<void> finalizeStateStreamingDownload({
    required String stateCode,
    required String stateName,
    required String dataVersion,
    required int totalPropertyCount,
    int totalTrailCount = 0,
    required int estimatedSizeBytes,
    String? landVersion,
    String? trailsVersion,
  }) async {
    final db = await _getDatabase();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Calculate unique trail count (distinct trail names) for display
    // This is done once at download time to avoid expensive queries on page load
    final uniqueResult = await db.rawQuery('''
      SELECT COUNT(DISTINCT trail_name) as unique_trails
      FROM $_tableTrails
      WHERE state_code = ?
    ''', [stateCode]);
    final uniqueTrailCount = (uniqueResult.first['unique_trails'] as int?) ?? 0;

    await db.insert(
      _tableStateDownloads,
      {
        'state_code': stateCode,
        'state_name': stateName,
        'data_version': dataVersion,
        'property_count': totalPropertyCount,
        'trail_count': totalTrailCount,
        'unique_trail_count': uniqueTrailCount,
        'total_size_bytes': estimatedSizeBytes,
        'downloaded_at': now,
        'status': 'complete',
        // Per-type versions (v6+)
        'land_version': landVersion ?? dataVersion, // Fallback to combined version
        'trails_version': trailsVersion,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('✅ Finalized streaming download for $stateCode: $totalPropertyCount properties, $totalTrailCount trail segments, $uniqueTrailCount unique trails');
  }

  /// Insert mock land records for screenshot testing.
  ///
  /// This method inserts pre-built land ownership records directly into SQLite
  /// for screenshot generation, bypassing the normal download flow.
  Future<void> insertMockLandRecords(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;

    final db = await _getDatabase();
    final batch = db.batch();

    for (final record in records) {
      // Extract boundary before inserting property
      final boundary = record.remove('boundary');

      // Insert property record
      batch.insert(
        _tableProperties,
        record,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Insert boundary if provided
      if (boundary != null) {
        batch.insert(
          _tableBoundaries,
          {
            'property_id': record['id'],
            'boundary_type': 'full',
            'coordinates': jsonEncode(boundary),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        // Also insert as medium for lower zoom levels
        batch.insert(
          _tableBoundaries,
          {
            'property_id': record['id'],
            'boundary_type': 'medium',
            'coordinates': jsonEncode(boundary),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    await batch.commit(noResult: true);
    debugPrint('📦 Inserted ${records.length} mock land records');
  }

  /// Update a specific data type version for a state
  ///
  /// Used for selective updates when only one data type changed.
  /// Creates the state_downloads record if it doesn't exist.
  Future<void> updateStateDataTypeVersion({
    required String stateCode,
    required DataTypeLocal dataType,
    required String version,
  }) async {
    final db = await _getDatabase();
    final columnName = switch (dataType) {
      DataTypeLocal.land => 'land_version',
      DataTypeLocal.trails => 'trails_version',
      DataTypeLocal.historical => 'historical_version',
      DataTypeLocal.cell => 'cell_version',
    };

    // Check if record exists
    final existing = await db.query(
      _tableStateDownloads,
      columns: ['state_code'],
      where: 'state_code = ?',
      whereArgs: [stateCode],
      limit: 1,
    );

    if (existing.isEmpty) {
      // Create new record with this version
      // Note: Only use columns that exist in all schema versions
      final stateName = _getStateName(stateCode);
      await db.insert(
        _tableStateDownloads,
        {
          'state_code': stateCode,
          'state_name': stateName,
          'data_version': version,  // Use this version as the overall version
          'downloaded_at': DateTime.now().millisecondsSinceEpoch,
          'property_count': 0,
          'trail_count': 0,
          'unique_trail_count': 0,
          columnName: version,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('✅ Created state download record for $stateCode with $dataType: $version');
    } else {
      // Update existing record
      await db.update(
        _tableStateDownloads,
        {columnName: version},
        where: 'state_code = ?',
        whereArgs: [stateCode],
      );
      debugPrint('✅ Updated $dataType version for $stateCode: $version');
    }
  }

  /// Get state name from code
  String _getStateName(String stateCode) {
    const stateNames = {
      'AL': 'Alabama', 'AK': 'Alaska', 'AZ': 'Arizona', 'AR': 'Arkansas',
      'CA': 'California', 'CO': 'Colorado', 'CT': 'Connecticut', 'DE': 'Delaware',
      'FL': 'Florida', 'GA': 'Georgia', 'ID': 'Idaho',
      'IL': 'Illinois', 'IN': 'Indiana', 'IA': 'Iowa', 'KS': 'Kansas',
      'KY': 'Kentucky', 'LA': 'Louisiana', 'ME': 'Maine', 'MD': 'Maryland',
      'MA': 'Massachusetts', 'MI': 'Michigan', 'MN': 'Minnesota', 'MS': 'Mississippi',
      'MO': 'Missouri', 'MT': 'Montana', 'NE': 'Nebraska', 'NV': 'Nevada',
      'NH': 'New Hampshire', 'NJ': 'New Jersey', 'NM': 'New Mexico', 'NY': 'New York',
      'NC': 'North Carolina', 'ND': 'North Dakota', 'OH': 'Ohio', 'OK': 'Oklahoma',
      'OR': 'Oregon', 'PA': 'Pennsylvania', 'RI': 'Rhode Island', 'SC': 'South Carolina',
      'SD': 'South Dakota', 'TN': 'Tennessee', 'TX': 'Texas', 'UT': 'Utah',
      'VT': 'Vermont', 'VA': 'Virginia', 'WA': 'Washington', 'WV': 'West Virginia',
      'WI': 'Wisconsin', 'WY': 'Wyoming',
    };
    return stateNames[stateCode.toUpperCase()] ?? stateCode;
  }

  /// Update state download record counts from actual data
  ///
  /// Call this after per-type downloads complete to update property/trail counts.
  Future<void> updateStateRecordCounts(String stateCode) async {
    final db = await _getDatabase();

    // Count properties
    final propertyResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM $_tableProperties WHERE state_code = ?
    ''', [stateCode]);
    final propertyCount = (propertyResult.first['count'] as int?) ?? 0;

    // Count trails
    final trailResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM $_tableTrails WHERE state_code = ?
    ''', [stateCode]);
    final trailCount = (trailResult.first['count'] as int?) ?? 0;

    // Count unique trails
    final uniqueResult = await db.rawQuery('''
      SELECT COUNT(DISTINCT trail_name) as count FROM $_tableTrails WHERE state_code = ?
    ''', [stateCode]);
    final uniqueTrailCount = (uniqueResult.first['count'] as int?) ?? 0;

    // Count historical places
    final histResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM $_tableHistoricalPlaces WHERE state_code = ?
    ''', [stateCode]);
    final historicalCount = (histResult.first['count'] as int?) ?? 0;

    // Count cell towers
    final cellResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM $_tableCellTowers WHERE state_code = ?
    ''', [stateCode]);
    final cellCount = (cellResult.first['count'] as int?) ?? 0;

    // Update the state_downloads record
    await db.update(
      _tableStateDownloads,
      {
        'property_count': propertyCount,
        'trail_count': trailCount,
        'unique_trail_count': uniqueTrailCount,
        'historical_places_count': historicalCount,
        'cell_tower_count': cellCount,
      },
      where: 'state_code = ?',
      whereArgs: [stateCode],
    );

    debugPrint('✅ Updated counts for $stateCode: $propertyCount properties, $trailCount trails ($uniqueTrailCount unique), $historicalCount historical places, $cellCount cell towers');
  }

  /// Get per-type versions for a state
  Future<Map<DataTypeLocal, String?>> getStateDataTypeVersions(String stateCode) async {
    final db = await _getDatabase();

    final result = await db.query(
      _tableStateDownloads,
      columns: ['land_version', 'trails_version', 'historical_version', 'cell_version'],
      where: 'state_code = ?',
      whereArgs: [stateCode],
      limit: 1,
    );

    if (result.isEmpty) {
      return {
        DataTypeLocal.land: null,
        DataTypeLocal.trails: null,
        DataTypeLocal.historical: null,
        DataTypeLocal.cell: null,
      };
    }

    final row = result.first;
    return {
      DataTypeLocal.land: row['land_version'] as String?,
      DataTypeLocal.trails: row['trails_version'] as String?,
      DataTypeLocal.historical: row['historical_version'] as String?,
      DataTypeLocal.cell: row['cell_version'] as String?,
    };
  }

  /// Insert a batch of trails from ZIP import
  ///
  /// v3: ZIP-only architecture - trails come from state ZIP downloads
  Future<void> insertTrailBatch({
    required String stateCode,
    required List<Map<String, dynamic>> trails,
  }) async {
    if (trails.isEmpty) return;

    final db = await _getDatabase();
    final batch = db.batch();

    for (final trail in trails) {
      try {
        // Parse geometry to calculate bounding box
        final geometryJson = trail['geometry_geojson'] as String?;
        double? bboxNorth, bboxSouth, bboxEast, bboxWest;

        if (geometryJson != null) {
          try {
            final geometry = jsonDecode(geometryJson) as Map<String, dynamic>;
            final coords = geometry['coordinates'];
            if (coords != null) {
              final bbox = _calculateTrailBoundingBox(coords);
              bboxNorth = bbox['north'];
              bboxSouth = bbox['south'];
              bboxEast = bbox['east'];
              bboxWest = bbox['west'];
            }
          } catch (_) {
            // Geometry parsing failed, continue without bbox
          }
        }

        // Parse allowed_uses from array to JSON string
        final allowedUses = trail['allowed_uses'];
        String allowedUsesJson;
        if (allowedUses is List) {
          allowedUsesJson = jsonEncode(allowedUses);
        } else if (allowedUses is String) {
          allowedUsesJson = allowedUses;
        } else {
          allowedUsesJson = '[]';
        }

        batch.insert(
          _tableTrails,
          {
            'id': trail['id']?.toString() ?? trail['external_id']?.toString(),
            'external_id': trail['external_id']?.toString() ?? '',
            'trail_name': trail['trail_name'] ?? 'Unknown Trail',
            'trail_number': trail['trail_number'],
            'trail_type': trail['trail_type'] ?? 'TERRA',
            'trail_class': trail['trail_class'],
            'difficulty': trail['difficulty'],
            'surface_type': trail['surface_type'],
            'allowed_uses': allowedUsesJson,
            'managing_agency': trail['managing_agency'],
            'length_miles': (trail['length_miles'] as num?)?.toDouble() ?? 0.0,
            'geometry_geojson': geometryJson ?? '',
            'data_source': trail['data_source'] ?? 'PAD-US',
            'osm_relation_id': trail['osm_relation_id'],
            'osm_relation_name': trail['osm_relation_name'],
            'state_code': stateCode,
            'bbox_north': bboxNorth,
            'bbox_south': bboxSouth,
            'bbox_east': bboxEast,
            'bbox_west': bboxWest,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) {
        debugPrint('⚠️ Failed to insert trail: $e');
      }
    }

    await batch.commit(noResult: true);
  }

  /// Calculate bounding box from trail coordinates
  Map<String, double> _calculateTrailBoundingBox(Object? coords) {
    double minLat = 90.0, maxLat = -90.0;
    double minLon = 180.0, maxLon = -180.0;

    void processCoord(List<dynamic> coord) {
      if (coord.length >= 2) {
        final lon = (coord[0] as num).toDouble();
        final lat = (coord[1] as num).toDouble();
        minLat = math.min(minLat, lat);
        maxLat = math.max(maxLat, lat);
        minLon = math.min(minLon, lon);
        maxLon = math.max(maxLon, lon);
      }
    }

    void processCoords(Object? c) {
      if (c is List) {
        if (c.isNotEmpty && c[0] is num) {
          // This is a single coordinate [lon, lat]
          processCoord(c);
        } else {
          // This is an array of coordinates or nested arrays
          c.forEach(processCoords);
        }
      }
    }

    processCoords(coords);

    return {
      'north': maxLat,
      'south': minLat,
      'east': maxLon,
      'west': minLon,
    };
  }

  /// Query trails from SQLite for a given bounding box
  ///
  /// v3: ZIP-only architecture - returns trails from downloaded state data
  /// If [stateCode] is provided, only returns trails from that state
  /// (prevents data from "bleeding" into neighboring states when zoomed out)
  Future<List<Trail>> queryTrailsForBounds({
    required double northBound,
    required double southBound,
    required double eastBound,
    required double westBound,
    int limit = 100,
    String? stateCode,
  }) async {
    final db = await _getDatabase();

    // Query trails that intersect with the viewport
    // Filter by state_code to prevent trails from appearing in neighboring states
    final whereClause = stateCode != null
        ? '''
          bbox_north >= ? AND bbox_south <= ? AND
          bbox_east >= ? AND bbox_west <= ? AND
          state_code = ?
        '''
        : '''
          bbox_north >= ? AND bbox_south <= ? AND
          bbox_east >= ? AND bbox_west <= ?
        ''';

    final whereArgs = [
      southBound,
      northBound,
      westBound,
      eastBound,
      if (stateCode != null) stateCode,
    ];

    final results = await db.query(
      _tableTrails,
      where: whereClause,
      whereArgs: whereArgs,
      limit: limit,
    );

    if (results.isEmpty) {
      return [];
    }

    debugPrint('💾 SQLite: Found ${results.length} trails in viewport');

    return results.map((row) {
      // Parse geometry from JSON - preserve original type and structure
      TrailGeometry trailGeometry = const TrailGeometry(
        type: 'LineString',
        rawCoordinates: <dynamic>[],
      );
      final geometryJson = row['geometry_geojson'] as String?;
      if (geometryJson != null && geometryJson.isNotEmpty) {
        try {
          final geometry = jsonDecode(geometryJson) as Map<String, dynamic>;
          // Use fromJson to preserve MultiLineString structure
          trailGeometry = TrailGeometry.fromJson(geometry);
        } catch (_) {
          // Geometry parsing failed
        }
      }

      // Parse allowed uses
      List<String> allowedUses = [];
      final allowedUsesJson = row['allowed_uses'] as String?;
      if (allowedUsesJson != null && allowedUsesJson.isNotEmpty) {
        try {
          allowedUses = (jsonDecode(allowedUsesJson) as List<dynamic>)
              .map((e) => e.toString())
              .toList();
        } catch (_) {
          // Parsing failed
        }
      }

      return Trail(
        id: row['id'] as String? ?? '',
        trailName: row['trail_name'] as String? ?? 'Unknown Trail',
        trailNumber: row['trail_number'] as String?,
        trailType: row['trail_type'] as String? ?? 'TERRA',
        trailClass: row['trail_class']?.toString(), // Store as int, convert to String
        difficulty: row['difficulty'] as String?,
        surfaceType: row['surface_type'] as String?,
        allowedUses: allowedUses,
        managingAgency: row['managing_agency'] as String?,
        lengthMiles: (row['length_miles'] as num?)?.toDouble() ?? 0.0,
        geometry: trailGeometry,
        simplifiedGeometry: trailGeometry, // Use same geometry for now
        dataSource: row['data_source'] as String? ?? 'USFS',
        osmRelationId: row['osm_relation_id']?.toString(),
        osmRelationName: row['osm_relation_name'] as String?,
      );
    }).toList();
  }

  /// Query ALL trails for a given state
  ///
  /// v3: ZIP-only architecture - loads entire state's trail data at once
  /// This prevents long trails that span the state from being cut off
  /// when only loading by viewport bounding box.
  Future<List<Trail>> queryAllTrailsForState(String stateCode) async {
    final db = await _getDatabase();

    // Query all trails for this state (no limit - trails are lightweight)
    final results = await db.query(
      _tableTrails,
      where: 'state_code = ?',
      whereArgs: [stateCode],
    );

    if (results.isEmpty) {
      return [];
    }

    debugPrint('💾 SQLite: Loading all ${results.length} trails for state $stateCode');

    // Debug: Log sample trail data to diagnose length/difficulty issues
    if (results.isNotEmpty) {
      final sampleSize = results.length < 5 ? results.length : 5;
      debugPrint('📊 Sample trail data (first $sampleSize):');
      for (int i = 0; i < sampleSize; i++) {
        final row = results[i];
        debugPrint('   ${row['trail_name']}: length_miles=${row['length_miles']}, difficulty=${row['difficulty']}');
      }
    }

    return results.map((row) {
      // Parse geometry from JSON - preserve original type and structure
      TrailGeometry trailGeometry = const TrailGeometry(
        type: 'LineString',
        rawCoordinates: <dynamic>[],
      );
      final geometryJson = row['geometry_geojson'] as String?;
      if (geometryJson != null && geometryJson.isNotEmpty) {
        try {
          final geometry = jsonDecode(geometryJson) as Map<String, dynamic>;
          // Use fromJson to preserve MultiLineString structure
          trailGeometry = TrailGeometry.fromJson(geometry);
        } catch (_) {
          // Geometry parsing failed
        }
      }

      // Parse allowed uses
      List<String> allowedUses = [];
      final allowedUsesJson = row['allowed_uses'] as String?;
      if (allowedUsesJson != null && allowedUsesJson.isNotEmpty) {
        try {
          allowedUses = (jsonDecode(allowedUsesJson) as List<dynamic>)
              .map((e) => e.toString())
              .toList();
        } catch (_) {
          // Parsing failed
        }
      }

      return Trail(
        id: row['id'] as String? ?? '',
        trailName: row['trail_name'] as String? ?? 'Unknown Trail',
        trailNumber: row['trail_number'] as String?,
        trailType: row['trail_type'] as String? ?? 'TERRA',
        trailClass: row['trail_class']?.toString(),
        difficulty: row['difficulty'] as String?,
        surfaceType: row['surface_type'] as String?,
        allowedUses: allowedUses,
        managingAgency: row['managing_agency'] as String?,
        stateCode: row['state_code'] as String?,
        lengthMiles: (row['length_miles'] as num?)?.toDouble() ?? 0.0,
        geometry: trailGeometry,
        simplifiedGeometry: trailGeometry,
        dataSource: row['data_source'] as String? ?? 'OSM',
        osmRelationId: row['osm_relation_id']?.toString(),
        osmRelationName: row['osm_relation_name'] as String?,
      );
    }).toList();
  }

  /// Get all states that have downloaded trails
  Future<List<String>> getStatesWithTrails() async {
    final db = await _getDatabase();

    final results = await db.rawQuery(
      'SELECT DISTINCT state_code FROM $_tableTrails WHERE state_code IS NOT NULL',
    );

    return results
        .map((row) => row['state_code'] as String?)
        .where((code) => code != null)
        .cast<String>()
        .toList();
  }

  /// Search trails by name from SQLite cache
  ///
  /// ZIP-ONLY MODE: Searches downloaded trail data
  Future<List<Trail>> searchTrailsByName(String searchQuery, {int limit = 10}) async {
    if (searchQuery.trim().isEmpty) {
      return [];
    }

    final db = await _getDatabase();

    // Use LIKE for case-insensitive partial matching
    final results = await db.query(
      _tableTrails,
      where: 'trail_name LIKE ?',
      whereArgs: ['%${searchQuery.trim()}%'],
      limit: limit,
    );

    if (results.isEmpty) {
      return [];
    }

    debugPrint('💾 SQLite: Found ${results.length} trails matching "$searchQuery"');

    return results.map((row) {
      // Parse geometry from JSON - preserve original type and structure
      TrailGeometry trailGeometry = const TrailGeometry(
        type: 'LineString',
        rawCoordinates: <dynamic>[],
      );
      final geometryJson = row['geometry_geojson'] as String?;
      if (geometryJson != null && geometryJson.isNotEmpty) {
        try {
          final geometry = jsonDecode(geometryJson) as Map<String, dynamic>;
          // Use fromJson to preserve MultiLineString structure
          trailGeometry = TrailGeometry.fromJson(geometry);
        } catch (_) {
          // Geometry parsing failed
        }
      }

      // Parse allowed uses
      List<String> allowedUses = [];
      final allowedUsesJson = row['allowed_uses'] as String?;
      if (allowedUsesJson != null && allowedUsesJson.isNotEmpty) {
        try {
          allowedUses = (jsonDecode(allowedUsesJson) as List<dynamic>)
              .map((e) => e.toString())
              .toList();
        } catch (_) {
          // Parsing failed
        }
      }

      return Trail(
        id: row['id'] as String? ?? '',
        trailName: row['trail_name'] as String? ?? 'Unknown Trail',
        trailNumber: row['trail_number'] as String?,
        trailType: row['trail_type'] as String? ?? 'TERRA',
        trailClass: row['trail_class']?.toString(),
        difficulty: row['difficulty'] as String?,
        surfaceType: row['surface_type'] as String?,
        allowedUses: allowedUses,
        managingAgency: row['managing_agency'] as String?,
        stateCode: row['state_code'] as String?,
        lengthMiles: (row['length_miles'] as num?)?.toDouble() ?? 0.0,
        geometry: trailGeometry,
        simplifiedGeometry: trailGeometry,
        dataSource: row['data_source'] as String? ?? 'USFS',
        osmRelationId: row['osm_relation_id']?.toString(),
        osmRelationName: row['osm_relation_name'] as String?,
      );
    }).toList();
  }

  // ============================================================================
  // END STREAMING STATE DOWNLOAD METHODS
  // ============================================================================

  /// Get all downloaded states
  Future<List<StateDownloadInfo>> getDownloadedStates() async {
    final db = await _getDatabase();

    // Use LEFT JOIN to include historical places count from GNIS data
    final results = await db.rawQuery('''
      SELECT
        sd.*,
        COALESCE(hpd.place_count, 0) as historical_places_count
      FROM $_tableStateDownloads sd
      LEFT JOIN $_tableHistoricalPlacesDownloads hpd
        ON sd.state_code = hpd.state_code
      ORDER BY sd.state_name ASC
    ''');

    return results.map((row) => StateDownloadInfo(
      stateCode: row['state_code']! as String,
      stateName: row['state_name']! as String,
      dataVersion: row['data_version']! as String,
      propertyCount: row['property_count']! as int,
      trailCount: (row['trail_count'] as int?) ?? 0,
      uniqueTrailCount: (row['unique_trail_count'] as int?) ?? 0,
      historicalPlacesCount: (row['historical_places_count'] as int?) ?? 0,
      totalSizeBytes: (row['total_size_bytes'] as int?) ?? 0,
      downloadedAt: DateTime.fromMillisecondsSinceEpoch(row['downloaded_at']! as int),
      status: row['status']! as String,
      // Per-type versions (v6+)
      landVersion: row['land_version'] as String?,
      trailsVersion: row['trails_version'] as String?,
      historicalVersion: row['historical_version'] as String?,
      // Cell coverage (v10+)
      cellVersion: row['cell_version'] as String?,
      cellTowerCount: (row['cell_tower_count'] as int?) ?? 0,
    )).toList();
  }

  /// Check if a state is downloaded
  Future<bool> isStateDownloaded(String stateCode) async {
    final db = await _getDatabase();

    final result = await db.query(
      _tableStateDownloads,
      where: 'state_code = ?',
      whereArgs: [stateCode],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  /// Insert a mock state download record for testing/screenshots
  ///
  /// This makes the app think the state is already downloaded, hiding
  /// the download banner without actually having the land data.
  ///
  /// Uses current server versions to avoid showing "Update" badge.
  /// Update these when server versions change:
  /// - Check: curl -s https://api.obsessiontracker.com/config | jq '.data.versions'
  Future<void> insertMockStateDownload(String stateCode, String stateName) async {
    final db = await _getDatabase();
    final now = DateTime.now();

    // Match current server versions to avoid "Update" badge in screenshots
    // Server versions as of 2026-01: land=PAD-US-4.1, trails=OSM-2024.12, historical=GNIS-2024.2
    const landVersion = 'PAD-US-4.1';
    const trailsVersion = 'OSM-2024.12';
    const historicalVersion = 'GNIS-2024.2';

    await db.insert(
      _tableStateDownloads,
      {
        'state_code': stateCode,
        'state_name': stateName,
        'data_version': 'PAD-US-4.1-GNIS', // Combined version for legacy compatibility
        'property_count': 1000, // Non-zero to pass hasData check
        'trail_count': 500,
        'unique_trail_count': 50,
        'historical_places_count': 25,
        'total_size_bytes': 0,
        'downloaded_at': now.millisecondsSinceEpoch,
        'status': 'completed',
        'land_version': landVersion,
        'trails_version': trailsVersion,
        'historical_version': historicalVersion,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('📦 Inserted mock state download record for $stateCode');
  }

  /// Get the data version for a downloaded state
  Future<String?> getStateDataVersion(String stateCode) async {
    final db = await _getDatabase();

    final result = await db.query(
      _tableStateDownloads,
      columns: ['data_version'],
      where: 'state_code = ?',
      whereArgs: [stateCode],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return result.first['data_version'] as String?;
  }

  /// Get trail segment counts for all downloaded states (raw segment count)
  /// Returns a map of state codes to trail segment counts (e.g., {'CA': 7360, 'NV': 1200})
  Future<Map<String, int>> getTrailCountsByState() async {
    final db = await _getDatabase();

    final results = await db.query(
      _tableStateDownloads,
      columns: ['state_code', 'trail_count'],
    );

    return {
      for (final row in results)
        row['state_code']! as String: (row['trail_count'] as int?) ?? 0,
    };
  }

  /// Get unique trail counts for all downloaded states (grouped by trail_name)
  /// Returns a map of state codes to unique trail counts
  /// This counts distinct trail names, not individual segments
  Future<Map<String, int>> getUniqueTrailCountsByState() async {
    final db = await _getDatabase();

    final results = await db.rawQuery('''
      SELECT state_code, COUNT(DISTINCT trail_name) as unique_trails
      FROM $_tableTrails
      WHERE state_code IS NOT NULL
      GROUP BY state_code
    ''');

    return {
      for (final row in results)
        row['state_code']! as String: (row['unique_trails'] as int?) ?? 0,
    };
  }

  /// Delete a downloaded state
  Future<void> deleteStateData(String stateCode) async {
    final db = await _getDatabase();

    await db.transaction((txn) async {
      // Delete properties for this state
      await txn.delete(
        _tableProperties,
        where: 'state_code = ?',
        whereArgs: [stateCode],
      );

      // Delete trails for this state
      await txn.delete(
        _tableTrails,
        where: 'state_code = ?',
        whereArgs: [stateCode],
      );

      // Delete historical places for this state
      await txn.delete(
        _tableHistoricalPlaces,
        where: 'state_code = ?',
        whereArgs: [stateCode],
      );

      // Delete historical places download record
      await txn.delete(
        _tableHistoricalPlacesDownloads,
        where: 'state_code = ?',
        whereArgs: [stateCode],
      );

      // Delete state download record
      await txn.delete(
        _tableStateDownloads,
        where: 'state_code = ?',
        whereArgs: [stateCode],
      );
    });

    debugPrint('Deleted cached data for state: $stateCode');
  }

  /// Query properties by state code
  Future<List<ComprehensiveLandOwnership>> queryPropertiesByState({
    required String stateCode,
    int limit = 1000,
    int offset = 0,
  }) async {
    final db = await _getDatabase();

    final results = await db.query(
      _tableProperties,
      where: 'state_code = ?',
      whereArgs: [stateCode],
      limit: limit,
      offset: offset,
    );

    final properties = <ComprehensiveLandOwnership>[];
    for (final row in results) {
      final property = await _rowToProperty(row);
      if (property != null) {
        properties.add(property);
      }
    }

    return properties;
  }

  /// Get total storage used by state downloads
  Future<int> getStateDownloadStorageBytes() async {
    final db = await _getDatabase();

    final result = await db.rawQuery(
      'SELECT SUM(total_size_bytes) as total FROM $_tableStateDownloads',
    );

    return (result.first['total'] as int?) ?? 0;
  }

  // ============================================================================
  // END STATE-BASED BULK DOWNLOAD METHODS
  // ============================================================================

  /// Download an area for offline use
  Future<void> downloadAreaForOfflineUse({
    required String name,
    required double centerLatitude,
    required double centerLongitude,
    required double radiusKm,
    void Function(double)? onProgress,
  }) async {
    await _getDatabase();

    // Create download area record
    final downloadArea = DownloadArea(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
      radiusKm: radiusKm,
      status: DownloadStatus.downloading,
      downloadedAt: DateTime.now(),
    );

    await _insertDownloadArea(downloadArea);
    onProgress?.call(0.0);

    try {
      // Simulate download progress (in real implementation, this would fetch from BFF)
      for (int i = 1; i <= 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        onProgress?.call(i / 10.0);
      }

      // Update status to completed
      final completedArea = downloadArea.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
      );
      await _updateDownloadArea(completedArea);
      
    } catch (e) {
      // Update status to failed
      final failedArea = downloadArea.copyWith(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      );
      await _updateDownloadArea(failedArea);
      rethrow;
    }
  }

  /// Get all download areas
  Future<List<DownloadArea>> getDownloadAreas() async {
    final db = await _getDatabase();

    final List<Map<String, dynamic>> maps = await db.query(
      _tableDownloads,
      orderBy: 'downloaded_at DESC',
    );

    return maps.map(DownloadArea.fromMap).toList();
  }

  /// Delete a download area
  Future<void> deleteDownloadArea(String areaId) async {
    final db = await _getDatabase();

    await db.delete(
      _tableDownloads,
      where: 'id = ?',
      whereArgs: [areaId],
    );

    // Also delete associated cached properties
    await db.delete(
      _tableProperties,
      where: 'download_area_id = ?',
      whereArgs: [areaId],
    );
  }

  /// Optimize the database
  Future<void> optimizeDatabase() async {
    final db = await _getDatabase();

    await db.execute('VACUUM');
    await db.execute('ANALYZE');
    debugPrint('Database optimized');
  }

  /// Get cached property count
  Future<int> getCachedPropertyCount() async {
    final db = await _getDatabase();

    final result = await db.rawQuery('SELECT COUNT(*) FROM $_tableProperties');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get cache size as string
  Future<String> getCacheSizeString() async {
    await _getDatabase();

    // Get database file size (simplified)
    final count = await getCachedPropertyCount();
    final estimatedSizeKB = count * 2; // ~2KB per property estimate
    
    if (estimatedSizeKB < 1024) {
      return '$estimatedSizeKB KB';
    } else {
      final sizeMB = estimatedSizeKB / 1024;
      return '${sizeMB.toStringAsFixed(1)} MB';
    }
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    final db = await _getDatabase();

    final result = await db.rawQuery(
      'SELECT MAX(cached_at) as last_sync FROM $_tableProperties'
    );
    
    final lastSync = result.first['last_sync'] as int?;
    return lastSync != null ? DateTime.fromMillisecondsSinceEpoch(lastSync) : null;
  }

  /// Insert download area
  Future<void> _insertDownloadArea(DownloadArea area) async {
    final db = await _getDatabase();

    await db.insert(
      _tableDownloads,
      area.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update download area
  Future<void> _updateDownloadArea(DownloadArea area) async {
    final db = await _getDatabase();

    await db.update(
      _tableDownloads,
      area.toMap(),
      where: 'id = ?',
      whereArgs: [area.id],
    );
  }

  /// Batch fetch all boundaries for a list of property IDs
  /// Returns a map of property_id -> list of boundary rows
  /// This is MUCH faster than individual queries (O(1) vs O(N))
  Future<Map<String, List<Map<String, dynamic>>>> _batchFetchBoundaries(
    List<String> propertyIds,
  ) async {
    if (propertyIds.isEmpty) return {};

    final db = await _getDatabase();
    final result = <String, List<Map<String, dynamic>>>{};

    // SQLite has a limit on variables in IN clause (~999), so batch if needed
    const batchSize = 500;
    for (var i = 0; i < propertyIds.length; i += batchSize) {
      final batchIds = propertyIds.skip(i).take(batchSize).toList();
      final placeholders = List.filled(batchIds.length, '?').join(',');

      final rows = await db.rawQuery(
        'SELECT property_id, boundary_type, coordinates FROM $_tableBoundaries '
        'WHERE property_id IN ($placeholders)',
        batchIds,
      );

      for (final row in rows) {
        final propId = row['property_id']! as String;
        result.putIfAbsent(propId, () => []).add(row);
      }
    }

    return result;
  }

  /// Get the preferred LOD type for a zoom level (5-level Progressive LOD)
  ///
  /// Based on cartographic science: tolerance <= 2 x meters-per-pixel is imperceptible
  /// - zoom 15+: full (survey-accurate, 0m tolerance)
  /// - zoom 12-14: high (~5.5m tolerance)
  /// - zoom 10-11: medium (~22m tolerance)
  /// - zoom 8-9: low (~111m tolerance)
  /// - zoom 5-7: overview (~555m tolerance)
  /// - zoom <5: no data loaded (handled by core_map_view)
  String _getLodTypeForZoom(double? zoomLevel) {
    if (zoomLevel == null) return 'overview';

    if (zoomLevel >= 15) {
      return 'full';
    } else if (zoomLevel >= 12) {
      return 'high';
    } else if (zoomLevel >= 10) {
      return 'medium';
    } else if (zoomLevel >= 8) {
      return 'low';
    } else {
      return 'overview';
    }
  }

  /// Get fallback types for a preferred LOD type (5-level system)
  /// Returns a list of fallback types to try in order if preferred is not available
  List<String> _getFallbackTypes(String preferredType) {
    switch (preferredType) {
      case 'full':
        return ['high', 'medium', 'simplified', 'low', 'overview'];
      case 'high':
        return ['full', 'medium', 'simplified', 'low', 'overview'];
      case 'medium':
        return ['simplified', 'low', 'high', 'overview', 'full'];
      case 'low':
        return ['overview', 'medium', 'simplified', 'high', 'full'];
      case 'overview':
        return ['low', 'medium', 'simplified', 'high', 'full'];
      default:
        return ['medium', 'simplified', 'low', 'high', 'full', 'overview'];
    }
  }

  /// Convert database row to property model using PRE-PARSED coordinates
  /// This is the fastest path - coordinates were parsed in an isolate
  ///
  /// If viewport bounds are provided, filters polygons to only include those
  /// that intersect the viewport. This dramatically reduces coordinate count
  /// for large MultiPolygon parcels like Montana State Trust Lands.
  ComprehensiveLandOwnership? _rowToPropertyWithParsedCoords(
    Map<String, dynamic> row,
    Map<String, int> coordIndex, // boundaryType -> index in parsedCoords
    List<List<List<List<double>>>?> parsedCoords,
    double? zoomLevel, {
    double? viewportNorth,
    double? viewportSouth,
    double? viewportEast,
    double? viewportWest,
  }) {
    try {
      final preferredType = _getLodTypeForZoom(zoomLevel);

      // 5-level LOD boundary storage
      List<List<List<double>>>? boundaries;
      List<List<List<double>>>? highBoundaries;
      List<List<List<double>>>? mediumBoundaries;
      List<List<List<double>>>? lowBoundaries;
      List<List<List<double>>>? overviewBoundaries;

      // Get pre-parsed coordinates with LOD fallback
      int? selectedIndex;

      // Try preferred type first
      selectedIndex = coordIndex[preferredType];

      // 5-level fallback chain
      if (selectedIndex == null) {
        if (preferredType == 'full') {
          selectedIndex = coordIndex['high'] ?? coordIndex['medium'] ?? coordIndex['low'] ?? coordIndex['overview'];
        } else if (preferredType == 'high') {
          selectedIndex = coordIndex['full'] ?? coordIndex['medium'] ?? coordIndex['low'] ?? coordIndex['overview'];
        } else if (preferredType == 'medium') {
          selectedIndex = coordIndex['low'] ?? coordIndex['high'] ?? coordIndex['overview'] ?? coordIndex['full'];
        } else if (preferredType == 'low') {
          selectedIndex = coordIndex['overview'] ?? coordIndex['medium'] ?? coordIndex['high'] ?? coordIndex['full'];
        } else if (preferredType == 'overview') {
          selectedIndex = coordIndex['low'] ?? coordIndex['medium'] ?? coordIndex['high'] ?? coordIndex['full'];
        }
        // Legacy fallback: try 'simplified' if new types not found
        selectedIndex ??= coordIndex['simplified'];
      }

      // Final fallback - any available
      selectedIndex ??= coordIndex.values.firstOrNull;

      if (selectedIndex != null && selectedIndex < parsedCoords.length) {
        var coords = parsedCoords[selectedIndex];
        if (coords != null) {
          // VIEWPORT FILTERING: Only keep polygons that intersect the viewport
          // This dramatically reduces coordinate count for large MultiPolygon parcels
          if (viewportNorth != null && viewportSouth != null &&
              viewportEast != null && viewportWest != null &&
              coords.length > 1) { // Only filter if multiple rings
            final filteredCoords = _filterPolygonsByViewport(
              coords,
              viewportNorth,
              viewportSouth,
              viewportEast,
              viewportWest,
            );
            if (filteredCoords.isNotEmpty) {
              coords = filteredCoords;
            }
            // If all filtered out, keep original (parcel bbox intersected viewport)
          }

          // Determine which field to populate based on what was selected
          final selectedType = coordIndex.entries
              .firstWhere((e) => e.value == selectedIndex, orElse: () => MapEntry(preferredType, -1))
              .key;

          if (selectedType == 'full') {
            boundaries = coords;
          } else if (selectedType == 'high') {
            highBoundaries = coords;
          } else if (selectedType == 'medium' || selectedType == 'simplified') {
            mediumBoundaries = coords; // 'simplified' maps to 'medium' for legacy data
          } else if (selectedType == 'low') {
            lowBoundaries = coords;
          } else if (selectedType == 'overview') {
            overviewBoundaries = coords;
          }
        }
      }

      return ComprehensiveLandOwnership(
        id: row['id'] as String,
        ownerName: row['owner_name'] as String,
        ownershipType: row['ownership_type'] as String,
        legalDescription: row['legal_description'] as String?,
        acreage: row['acreage'] as double?,
        dataSource: row['data_source'] as String,
        lastUpdated: row['last_updated'] != null
            ? DateTime.tryParse(row['last_updated'] as String)
            : null,
        boundaries: boundaries,
        highBoundaries: highBoundaries,
        mediumBoundaries: mediumBoundaries,
        lowBoundaries: lowBoundaries,
        overviewBoundaries: overviewBoundaries,
        activityPermissions: ActivityPermissions.fromJson(
          jsonDecode(row['activity_permissions'] as String) as Map<String, dynamic>,
        ),
        accessRights: AccessRights.fromJson(
          jsonDecode(row['access_rights'] as String) as Map<String, dynamic>,
        ),
        ownerContact: row['owner_contact'] != null
            ? OwnerContact.fromJson(jsonDecode(row['owner_contact'] as String) as Map<String, dynamic>)
            : null,
        agencyName: row['agency_name'] as String?,
        unitName: row['unit_name'] as String?,
        designation: row['designation'] as String?,
        accessType: row['access_type'] as String? ?? 'unknown',
        allowedUses: row['allowed_uses'] != null
            ? List<String>.from(jsonDecode(row['allowed_uses'] as String) as Iterable)
            : [],
        restrictions: row['restrictions'] != null
            ? List<String>.from(jsonDecode(row['restrictions'] as String) as Iterable)
            : [],
        contactInfo: row['contact_info'] as String?,
        website: row['website'] as String?,
        fees: row['fees'] as String?,
        seasonalInfo: row['seasonal_info'] as String?,
      );
    } catch (e) {
      debugPrint('Error converting row to property with parsed coords: $e');
      return null;
    }
  }

  /// Filter polygon rings to only include those that intersect the viewport
  ///
  /// For large MultiPolygon parcels (like Montana State Trust with 8,595 polygons),
  /// this reduces coordinate count from 500K+ to just the few polygons visible.
  /// Each ring is checked by computing its bounding box and testing intersection.
  List<List<List<double>>> _filterPolygonsByViewport(
    List<List<List<double>>> rings,
    double viewportNorth,
    double viewportSouth,
    double viewportEast,
    double viewportWest,
  ) {
    final filtered = <List<List<double>>>[];

    for (final ring in rings) {
      if (ring.isEmpty) continue;

      // Compute bounding box of this ring
      // Coordinates are [longitude, latitude]
      double minLat = double.infinity;
      double maxLat = double.negativeInfinity;
      double minLon = double.infinity;
      double maxLon = double.negativeInfinity;

      for (final point in ring) {
        if (point.length >= 2) {
          final lon = point[0];
          final lat = point[1];
          if (lat < minLat) minLat = lat;
          if (lat > maxLat) maxLat = lat;
          if (lon < minLon) minLon = lon;
          if (lon > maxLon) maxLon = lon;
        }
      }

      // Check if ring bbox intersects viewport bbox
      // Intersection: NOT (ring is completely outside viewport)
      final intersects = !(maxLat < viewportSouth ||  // ring completely below viewport
                           minLat > viewportNorth ||  // ring completely above viewport
                           maxLon < viewportWest ||   // ring completely left of viewport
                           minLon > viewportEast);    // ring completely right of viewport

      if (intersects) {
        filtered.add(ring);
      }
    }

    return filtered;
  }

  /// Convert database row to property model using pre-fetched boundaries
  /// This avoids N+1 queries by using boundary data that was batch-fetched
  // ignore: unused_element
  ComprehensiveLandOwnership? _rowToPropertyWithBoundaries(
    Map<String, dynamic> row,
    List<Map<String, dynamic>>? boundaryRows,
    double? zoomLevel,
  ) {
    try {
      final preferredType = _getLodTypeForZoom(zoomLevel);

      // 5-level LOD boundary storage
      List<List<List<double>>>? boundaries;
      List<List<List<double>>>? highBoundaries;
      List<List<List<double>>>? mediumBoundaries;
      List<List<List<double>>>? lowBoundaries;
      List<List<List<double>>>? overviewBoundaries;

      if (boundaryRows != null && boundaryRows.isNotEmpty) {
        // Find the preferred boundary type with 5-level fallback
        Map<String, dynamic>? selectedRow;

        // Try preferred type first
        selectedRow = boundaryRows.where((r) => r['boundary_type'] == preferredType).firstOrNull;

        // 5-level fallback chain
        if (selectedRow == null) {
          if (preferredType == 'full') {
            selectedRow = boundaryRows.where((r) => r['boundary_type'] == 'high').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'medium').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'simplified').firstOrNull // Legacy
                ?? boundaryRows.where((r) => r['boundary_type'] == 'low').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'overview').firstOrNull;
          } else if (preferredType == 'high') {
            selectedRow = boundaryRows.where((r) => r['boundary_type'] == 'full').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'medium').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'simplified').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'low').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'overview').firstOrNull;
          } else if (preferredType == 'medium') {
            selectedRow = boundaryRows.where((r) => r['boundary_type'] == 'simplified').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'low').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'high').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'overview').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'full').firstOrNull;
          } else if (preferredType == 'low') {
            selectedRow = boundaryRows.where((r) => r['boundary_type'] == 'overview').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'medium').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'simplified').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'high').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'full').firstOrNull;
          } else if (preferredType == 'overview') {
            selectedRow = boundaryRows.where((r) => r['boundary_type'] == 'low').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'medium').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'simplified').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'high').firstOrNull
                ?? boundaryRows.where((r) => r['boundary_type'] == 'full').firstOrNull;
          }
        }

        // Final fallback - any type
        selectedRow ??= boundaryRows.firstOrNull;

        if (selectedRow != null) {
          final coords = jsonDecode(selectedRow['coordinates']! as String);
          final boundaryType = selectedRow['boundary_type'] as String?;
          if (boundaryType == 'full') {
            boundaries = _parseCoordinates(coords);
          } else if (boundaryType == 'high') {
            highBoundaries = _parseCoordinates(coords);
          } else if (boundaryType == 'medium' || boundaryType == 'simplified') {
            mediumBoundaries = _parseCoordinates(coords); // 'simplified' maps to 'medium'
          } else if (boundaryType == 'low') {
            lowBoundaries = _parseCoordinates(coords);
          } else if (boundaryType == 'overview') {
            overviewBoundaries = _parseCoordinates(coords);
          }
        }
      }

      return ComprehensiveLandOwnership(
        id: row['id'] as String,
        ownerName: row['owner_name'] as String,
        ownershipType: row['ownership_type'] as String,
        legalDescription: row['legal_description'] as String?,
        acreage: row['acreage'] as double?,
        dataSource: row['data_source'] as String,
        lastUpdated: row['last_updated'] != null
            ? DateTime.tryParse(row['last_updated'] as String)
            : null,
        boundaries: boundaries,
        highBoundaries: highBoundaries,
        mediumBoundaries: mediumBoundaries,
        lowBoundaries: lowBoundaries,
        overviewBoundaries: overviewBoundaries,
        activityPermissions: ActivityPermissions.fromJson(
          jsonDecode(row['activity_permissions'] as String) as Map<String, dynamic>,
        ),
        accessRights: AccessRights.fromJson(
          jsonDecode(row['access_rights'] as String) as Map<String, dynamic>,
        ),
        ownerContact: row['owner_contact'] != null
            ? OwnerContact.fromJson(jsonDecode(row['owner_contact'] as String) as Map<String, dynamic>)
            : null,
        agencyName: row['agency_name'] as String?,
        unitName: row['unit_name'] as String?,
        designation: row['designation'] as String?,
        accessType: row['access_type'] as String? ?? 'unknown',
        allowedUses: row['allowed_uses'] != null
            ? List<String>.from(jsonDecode(row['allowed_uses'] as String) as Iterable)
            : [],
        restrictions: row['restrictions'] != null
            ? List<String>.from(jsonDecode(row['restrictions'] as String) as Iterable)
            : [],
        contactInfo: row['contact_info'] as String?,
        website: row['website'] as String?,
        fees: row['fees'] as String?,
        seasonalInfo: row['seasonal_info'] as String?,
      );
    } catch (e) {
      debugPrint('Error converting row to property: $e');
      return null;
    }
  }

  /// Convert database row to property model (legacy - makes individual queries)
  /// Prefer using _rowToPropertyWithBoundaries for batch operations
  Future<ComprehensiveLandOwnership?> _rowToProperty(
    Map<String, dynamic> row, {
    double? zoomLevel,
  }) async {
    try {
      final db = await _getDatabase();

      // 5-level Progressive LOD based on zoom level
      // Based on cartographic science: tolerance <= 2 x meters-per-pixel is imperceptible
      final preferredType = _getLodTypeForZoom(zoomLevel);

      // Fetch boundaries with 5-level fallback chain
      var boundaryRows = await db.query(
        _tableBoundaries,
        where: 'property_id = ? AND boundary_type = ?',
        whereArgs: [row['id'], preferredType],
      );

      // 5-level fallback chain
      if (boundaryRows.isEmpty) {
        final fallbackTypes = _getFallbackTypes(preferredType);
        for (final fallbackType in fallbackTypes) {
          boundaryRows = await db.query(
            _tableBoundaries,
            where: 'property_id = ? AND boundary_type = ?',
            whereArgs: [row['id'], fallbackType],
          );
          if (boundaryRows.isNotEmpty) break;
        }
      }
      // Final fallback - try any available type
      if (boundaryRows.isEmpty) {
        boundaryRows = await db.query(
          _tableBoundaries,
          where: 'property_id = ?',
          whereArgs: [row['id']],
          limit: 1,
        );
      }
      final effectiveBoundaryRows = boundaryRows;

      // 5-level LOD boundary storage
      List<List<List<double>>>? boundaries;
      List<List<List<double>>>? highBoundaries;
      List<List<List<double>>>? mediumBoundaries;
      List<List<List<double>>>? lowBoundaries;
      List<List<List<double>>>? overviewBoundaries;

      for (final boundaryRow in effectiveBoundaryRows) {
        final coords = jsonDecode(boundaryRow['coordinates']! as String);
        final boundaryType = boundaryRow['boundary_type'] as String?;
        if (boundaryType == 'full') {
          boundaries = _parseCoordinates(coords);
        } else if (boundaryType == 'high') {
          highBoundaries = _parseCoordinates(coords);
        } else if (boundaryType == 'medium' || boundaryType == 'simplified') {
          mediumBoundaries = _parseCoordinates(coords); // 'simplified' maps to 'medium'
        } else if (boundaryType == 'low') {
          lowBoundaries = _parseCoordinates(coords);
        } else if (boundaryType == 'overview') {
          overviewBoundaries = _parseCoordinates(coords);
        }
      }

      return ComprehensiveLandOwnership(
        id: row['id'] as String,
        ownerName: row['owner_name'] as String,
        ownershipType: row['ownership_type'] as String,
        legalDescription: row['legal_description'] as String?,
        acreage: row['acreage'] as double?,
        dataSource: row['data_source'] as String,
        lastUpdated: row['last_updated'] != null
            ? DateTime.tryParse(row['last_updated'] as String)
            : null,
        boundaries: boundaries,
        highBoundaries: highBoundaries,
        mediumBoundaries: mediumBoundaries,
        lowBoundaries: lowBoundaries,
        overviewBoundaries: overviewBoundaries,
        activityPermissions: ActivityPermissions.fromJson(
          jsonDecode(row['activity_permissions'] as String) as Map<String, dynamic>,
        ),
        accessRights: AccessRights.fromJson(
          jsonDecode(row['access_rights'] as String) as Map<String, dynamic>,
        ),
        ownerContact: row['owner_contact'] != null
            ? OwnerContact.fromJson(jsonDecode(row['owner_contact'] as String) as Map<String, dynamic>)
            : null,
        agencyName: row['agency_name'] as String?,
        unitName: row['unit_name'] as String?,
        designation: row['designation'] as String?,
        accessType: row['access_type'] as String? ?? 'unknown',
        allowedUses: row['allowed_uses'] != null
            ? List<String>.from(jsonDecode(row['allowed_uses'] as String) as Iterable)
            : [],
        restrictions: row['restrictions'] != null
            ? List<String>.from(jsonDecode(row['restrictions'] as String) as Iterable)
            : [],
        contactInfo: row['contact_info'] as String?,
        website: row['website'] as String?,
        fees: row['fees'] as String?,
        seasonalInfo: row['seasonal_info'] as String?,
      );
    } catch (e) {
      debugPrint('Error converting row to property: $e');
      return null;
    }
  }
  
  /// Parse coordinate JSON to typed list
  List<List<List<double>>>? _parseCoordinates(Object? coords) {
    if (coords == null) return null;
    try {
      if (coords is List) {
        return coords.map((ring) {
          if (ring is List) {
            return ring.map((point) {
              if (point is List && point.length >= 2) {
                return [
                  (point[0] as num).toDouble(),
                  (point[1] as num).toDouble(),
                ];
              }
              return <double>[];
            }).where((p) => p.isNotEmpty).toList();
          }
          return <List<double>>[];
        }).where((r) => r.isNotEmpty).toList();
      }
    } catch (e) {
      debugPrint('Error parsing coordinates: $e');
    }
    return null;
  }
  
  /// Calculate bounding box from coordinates
  _BoundingBox _calculateBoundingBox(List<List<List<double>>>? coordinates, {String? debugName}) {
    if (coordinates == null || coordinates.isEmpty) {
      return _BoundingBox(0, 0, 0, 0, 0, 0);
    }

    double minLat = 90, maxLat = -90;
    double minLon = 180, maxLon = -180;
    var totalPoints = 0;

    for (final ring in coordinates) {
      for (final point in ring) {
        if (point.length >= 2) {
          final lon = point[0];
          final lat = point[1];
          minLat = math.min(minLat, lat);
          maxLat = math.max(maxLat, lat);
          minLon = math.min(minLon, lon);
          maxLon = math.max(maxLon, lon);
          totalPoints++;
        }
      }
    }

    // Debug: Log if bbox looks suspicious (N=S or E=W)
    if (debugName != null && (maxLat == minLat || maxLon == minLon)) {
      debugPrint('⚠️ BBox Debug: $debugName has degenerate bbox! ${coordinates.length} rings, $totalPoints points');
      debugPrint('   lat range: $minLat to $maxLat (diff: ${maxLat - minLat})');
      debugPrint('   lon range: $minLon to $maxLon (diff: ${maxLon - minLon})');
      // Log sample points from each ring to understand the data structure
      for (var i = 0; i < math.min(3, coordinates.length); i++) {
        final ring = coordinates[i];
        debugPrint('   Ring $i (${ring.length} points): first=[${ring.first[0].toStringAsFixed(6)}, ${ring.first[1].toStringAsFixed(6)}], last=[${ring.last[0].toStringAsFixed(6)}, ${ring.last[1].toStringAsFixed(6)}]');
      }
    }

    // For NPS, always log bbox even if valid to help debugging
    if (debugName != null && debugName.contains('NPS') && maxLat != minLat && maxLon != minLon) {
      debugPrint('✓ BBox Debug: $debugName valid bbox - lat: $minLat to $maxLat, lon: $minLon to $maxLon');
    }

    return _BoundingBox(
      maxLat, // north
      minLat, // south
      maxLon, // east
      minLon, // west
      (minLat + maxLat) / 2, // center lat
      (minLon + maxLon) / 2, // center lon
    );
  }
  
  /// Estimate data size for statistics
  int _estimateDataSize(List<ComprehensiveLandOwnership> properties) {
    // Rough estimate: 2KB per property + boundaries
    return properties.length * 2048;
  }
  
  /// Get database instance
  Future<Database> _getDatabase() async {
    if (_database == null) {
      await initialize();
    }
    return _database!;
  }
  
  /// Get oldest cache date
  Future<DateTime?> _getOldestCacheDate() async {
    final db = await _getDatabase();
    final result = await db.rawQuery(
      'SELECT MIN(cached_at) as oldest FROM $_tableProperties WHERE cache_expires > ?',
      [DateTime.now().millisecondsSinceEpoch],
    );
    final oldest = result.first['oldest'] as int?;
    return oldest != null 
        ? DateTime.fromMillisecondsSinceEpoch(oldest)
        : null;
  }
  
  /// Get newest cache date
  Future<DateTime?> _getNewestCacheDate() async {
    final db = await _getDatabase();
    final result = await db.rawQuery(
      'SELECT MAX(cached_at) as newest FROM $_tableProperties WHERE cache_expires > ?',
      [DateTime.now().millisecondsSinceEpoch],
    );
    final newest = result.first['newest'] as int?;
    return newest != null
        ? DateTime.fromMillisecondsSinceEpoch(newest)
        : null;
  }

  // ============================================================================
  // HISTORICAL PLACES (GNIS) METHODS (v5)
  // ============================================================================

  /// Clear existing historical places data for a state before streaming insert
  ///
  /// Call this before starting a new streaming download for a state.
  /// Clear trails for a specific state (used for per-type updates)
  Future<void> clearTrailsForState(String stateCode) async {
    final db = await _getDatabase();

    await db.delete(
      _tableTrails,
      where: 'state_code = ?',
      whereArgs: [stateCode],
    );

    debugPrint('🥾 Cleared trails for $stateCode');
  }

  Future<void> clearHistoricalPlacesForState(String stateCode) async {
    final db = await _getDatabase();

    await db.delete(
      _tableHistoricalPlaces,
      where: 'state_code = ?',
      whereArgs: [stateCode],
    );

    await db.delete(
      _tableHistoricalPlacesDownloads,
      where: 'state_code = ?',
      whereArgs: [stateCode],
    );

    debugPrint('📦 Cleared historical places for $stateCode');
  }

  /// Insert a batch of historical places during streaming download
  ///
  /// Memory-efficient: call repeatedly with small batches (20-50 records).
  Future<void> insertHistoricalPlacesBatch({
    required String stateCode,
    required List<HistoricalPlace> batch,
  }) async {
    if (batch.isEmpty) return;

    final db = await _getDatabase();
    final dbBatch = db.batch();

    for (final place in batch) {
      dbBatch.insert(
        _tableHistoricalPlaces,
        place.toDatabaseRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await dbBatch.commit(noResult: true);
  }

  /// Finalize historical places streaming download
  ///
  /// Call after all batches have been inserted.
  Future<void> finalizeHistoricalPlacesDownload({
    required String stateCode,
    required String stateName,
    required String dataVersion,
    required int placeCount,
  }) async {
    final db = await _getDatabase();

    await db.insert(
      _tableHistoricalPlacesDownloads,
      {
        'state_code': stateCode,
        'state_name': stateName,
        'data_version': dataVersion,
        'place_count': placeCount,
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('✅ Finalized historical places for $stateCode: $placeCount places');
  }

  /// Query historical places within a bounding box
  ///
  /// Used for map overlay display with clustering.
  /// Filter by categories (water, terrain, historic, etc.) or specific type codes.
  /// High limit (10K) is fine since Mapbox clustering efficiently handles large point datasets.
  Future<List<HistoricalPlace>> queryHistoricalPlacesForBounds({
    required double north,
    required double south,
    required double east,
    required double west,
    Set<String>? categoryFilter,
    Set<String>? typeCodeFilter,
    int limit = 10000,
  }) async {
    final db = await _getDatabase();

    var whereClause = 'latitude <= ? AND latitude >= ? AND longitude <= ? AND longitude >= ?';
    final whereArgs = <Object?>[north, south, east, west];

    // Add type code filter if provided (takes precedence over category)
    if (typeCodeFilter != null && typeCodeFilter.isNotEmpty) {
      final placeholders = List.filled(typeCodeFilter.length, '?').join(', ');
      whereClause += ' AND place_type IN ($placeholders)';
      whereArgs.addAll(typeCodeFilter);
    } else if (categoryFilter != null && categoryFilter.isNotEmpty) {
      // Filter by category
      final placeholders = List.filled(categoryFilter.length, '?').join(', ');
      whereClause += ' AND category IN ($placeholders)';
      whereArgs.addAll(categoryFilter);
    }

    final results = await db.query(
      _tableHistoricalPlaces,
      where: whereClause,
      whereArgs: whereArgs,
      limit: limit,
    );

    return results.map(HistoricalPlace.fromDatabase).toList();
  }

  /// Search historical places by name
  Future<List<HistoricalPlace>> searchHistoricalPlaces({
    required String query,
    String? stateCode,
    Set<String>? categoryFilter,
    Set<String>? typeCodeFilter,
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) return [];

    final db = await _getDatabase();

    var whereClause = 'feature_name LIKE ?';
    final whereArgs = <Object?>['%${query.trim()}%'];

    if (stateCode != null) {
      whereClause += ' AND state_code = ?';
      whereArgs.add(stateCode);
    }

    // Add type code filter if provided (takes precedence over category)
    if (typeCodeFilter != null && typeCodeFilter.isNotEmpty) {
      final placeholders = List.filled(typeCodeFilter.length, '?').join(', ');
      whereClause += ' AND place_type IN ($placeholders)';
      whereArgs.addAll(typeCodeFilter);
    } else if (categoryFilter != null && categoryFilter.isNotEmpty) {
      final placeholders = List.filled(categoryFilter.length, '?').join(', ');
      whereClause += ' AND category IN ($placeholders)';
      whereArgs.addAll(categoryFilter);
    }

    final results = await db.query(
      _tableHistoricalPlaces,
      where: whereClause,
      whereArgs: whereArgs,
      limit: limit,
      orderBy: 'feature_name COLLATE NOCASE',
    );

    return results.map(HistoricalPlace.fromDatabase).toList();
  }

  /// Get all downloaded historical places states
  Future<List<HistoricalPlacesDownloadInfo>> getHistoricalPlacesDownloads() async {
    final db = await _getDatabase();

    final results = await db.query(
      _tableHistoricalPlacesDownloads,
      orderBy: 'state_name ASC',
    );

    return results.map(HistoricalPlacesDownloadInfo.fromDatabase).toList();
  }

  /// Check if historical places data is downloaded for a state
  Future<bool> hasHistoricalPlacesForState(String stateCode) async {
    final db = await _getDatabase();

    final result = await db.query(
      _tableHistoricalPlacesDownloads,
      where: 'state_code = ?',
      whereArgs: [stateCode],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  /// Delete historical places data for a state
  Future<void> deleteHistoricalPlacesForState(String stateCode) async {
    final db = await _getDatabase();

    await db.transaction((txn) async {
      await txn.delete(
        _tableHistoricalPlaces,
        where: 'state_code = ?',
        whereArgs: [stateCode],
      );

      await txn.delete(
        _tableHistoricalPlacesDownloads,
        where: 'state_code = ?',
        whereArgs: [stateCode],
      );
    });

    debugPrint('Deleted historical places for state: $stateCode');
  }

  /// Get historical place counts by type code for a state
  Future<Map<String, int>> getHistoricalPlaceCountsByTypeCode(String stateCode) async {
    final db = await _getDatabase();

    final results = await db.rawQuery('''
      SELECT place_type, COUNT(*) as count
      FROM $_tableHistoricalPlaces
      WHERE state_code = ?
      GROUP BY place_type
    ''', [stateCode]);

    final counts = <String, int>{};
    for (final row in results) {
      final typeCode = row['place_type'] as String?;
      final count = row['count'] as int?;
      if (typeCode != null && count != null) {
        counts[typeCode] = count;
      }
    }

    return counts;
  }

  /// Get historical place counts by category for a state
  Future<Map<String, int>> getHistoricalPlaceCountsByCategory(String stateCode) async {
    final db = await _getDatabase();

    final results = await db.rawQuery('''
      SELECT category, COUNT(*) as count
      FROM $_tableHistoricalPlaces
      WHERE state_code = ?
      GROUP BY category
    ''', [stateCode]);

    final counts = <String, int>{};
    for (final row in results) {
      final category = row['category'] as String?;
      final count = row['count'] as int?;
      if (category != null && count != null) {
        counts[category] = count;
      }
    }

    return counts;
  }

  /// Get total historical places count across all states
  Future<int> getTotalHistoricalPlacesCount() async {
    final db = await _getDatabase();

    final result = await db.rawQuery(
      'SELECT SUM(place_count) as total FROM $_tableHistoricalPlacesDownloads',
    );

    return (result.first['total'] as int?) ?? 0;
  }

  /// Get all states that have downloaded historical places
  Future<List<String>> getStatesWithHistoricalPlaces() async {
    final db = await _getDatabase();

    final results = await db.query(
      _tableHistoricalPlacesDownloads,
      columns: ['state_code'],
    );

    return results
        .map((row) => row['state_code'] as String?)
        .where((code) => code != null)
        .cast<String>()
        .toList();
  }

  // =========================================================================
  // Cell Tower Methods (v10+)
  // =========================================================================

  /// Query cell towers within a bounding box
  ///
  /// Returns towers matching the viewport bounds, optionally filtered by radio type.
  /// High limit (10K) is fine since Mapbox clustering efficiently handles large point datasets.
  Future<List<CellTower>> queryCellTowersForBounds({
    required double north,
    required double south,
    required double east,
    required double west,
    Set<RadioType>? radioTypeFilter,
    int limit = 10000,
  }) async {
    final db = await _getDatabase();

    var whereClause = 'latitude <= ? AND latitude >= ? AND longitude <= ? AND longitude >= ?';
    final whereArgs = <Object?>[north, south, east, west];

    // Add radio type filter if provided
    if (radioTypeFilter != null && radioTypeFilter.isNotEmpty) {
      final codes = radioTypeFilter.map((t) => t.code).toList();
      final placeholders = List.filled(codes.length, '?').join(', ');
      whereClause += ' AND radio_type IN ($placeholders)';
      whereArgs.addAll(codes);
    }

    final results = await db.query(
      _tableCellTowers,
      where: whereClause,
      whereArgs: whereArgs,
      limit: limit,
    );

    return results.map(CellTower.fromDatabase).toList();
  }

  /// Insert cell towers for a state (replaces existing towers for that state)
  Future<int> insertCellTowers(String stateCode, List<CellTower> towers) async {
    if (towers.isEmpty) return 0;

    final db = await _getDatabase();

    // Delete existing towers for this state
    await db.delete(
      _tableCellTowers,
      where: 'state_code = ?',
      whereArgs: [stateCode],
    );

    // Insert new towers in batches
    int insertedCount = 0;
    const batchSize = 500;

    for (var i = 0; i < towers.length; i += batchSize) {
      final batch = db.batch();
      final end = (i + batchSize > towers.length) ? towers.length : i + batchSize;

      for (var j = i; j < end; j++) {
        batch.insert(
          _tableCellTowers,
          towers[j].toDatabaseRow(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      insertedCount += end - i;
    }

    debugPrint('Inserted $insertedCount cell towers for $stateCode');
    return insertedCount;
  }

  /// Delete cell towers for a state
  Future<void> deleteCellTowersForState(String stateCode) async {
    final db = await _getDatabase();

    final deletedCount = await db.delete(
      _tableCellTowers,
      where: 'state_code = ?',
      whereArgs: [stateCode],
    );

    debugPrint('Deleted $deletedCount cell towers for $stateCode');
  }

  /// Check if cell tower data exists for a state
  Future<bool> hasCellTowersForState(String stateCode) async {
    final db = await _getDatabase();

    final result = await db.query(
      _tableCellTowers,
      where: 'state_code = ?',
      whereArgs: [stateCode],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  /// Get cell tower count for a state
  Future<int> getCellTowerCountForState(String stateCode) async {
    final db = await _getDatabase();

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableCellTowers WHERE state_code = ?',
      [stateCode],
    );

    return (result.first['count'] as int?) ?? 0;
  }

  /// Get cell tower counts by radio type for a state
  Future<Map<RadioType, int>> getCellTowerCountsByRadioType(String stateCode) async {
    final db = await _getDatabase();

    final results = await db.rawQuery('''
      SELECT radio_type, COUNT(*) as count
      FROM $_tableCellTowers
      WHERE state_code = ?
      GROUP BY radio_type
    ''', [stateCode]);

    final counts = <RadioType, int>{};
    for (final row in results) {
      final radioCode = row['radio_type'] as String?;
      final count = row['count'] as int?;
      if (radioCode != null && count != null) {
        counts[RadioType.fromCode(radioCode)] = count;
      }
    }

    return counts;
  }

  /// Get total cell tower count across all states
  Future<int> getTotalCellTowerCount() async {
    final db = await _getDatabase();

    final result = await db.rawQuery(
      'SELECT COUNT(*) as total FROM $_tableCellTowers',
    );

    return (result.first['total'] as int?) ?? 0;
  }

  /// Get all states that have downloaded cell tower data
  Future<List<String>> getStatesWithCellTowers() async {
    final db = await _getDatabase();

    final results = await db.rawQuery(
      'SELECT DISTINCT state_code FROM $_tableCellTowers',
    );

    return results
        .map((row) => row['state_code'] as String?)
        .where((code) => code != null)
        .cast<String>()
        .toList();
  }

  /// Update cell version for a state download
  Future<void> updateCellVersion(String stateCode, String version, int towerCount) async {
    final db = await _getDatabase();

    await db.update(
      _tableStateDownloads,
      {
        'cell_version': version,
        'cell_tower_count': towerCount,
      },
      where: 'state_code = ?',
      whereArgs: [stateCode],
    );
  }
}

/// Bounding box for spatial calculations
class _BoundingBox {
  final double north;
  final double south;
  final double east;
  final double west;
  final double centerLat;
  final double centerLon;
  
  _BoundingBox(this.north, this.south, this.east, this.west, this.centerLat, this.centerLon);
}

/// Result of offline download operation
class OfflineDownloadResult {
  final bool success;
  final int propertyCount;
  final double areaSizeKm2;
  final DateTime? expiresAt;
  final String? error;
  
  OfflineDownloadResult({
    required this.success,
    this.propertyCount = 0,
    this.areaSizeKm2 = 0,
    this.expiresAt,
    this.error,
  });
}

/// Offline cache statistics
class OfflineStatistics {
  final int cachedProperties;
  final int downloadedAreas;
  final int totalCacheSizeBytes;
  final DateTime? oldestCache;
  final DateTime? newestCache;
  
  OfflineStatistics({
    required this.cachedProperties,
    required this.downloadedAreas,
    required this.totalCacheSizeBytes,
    this.oldestCache,
    this.newestCache,
  });
  
  String get formattedSize {
    if (totalCacheSizeBytes < 1024) return '$totalCacheSizeBytes B';
    if (totalCacheSizeBytes < 1024 * 1024) return '${(totalCacheSizeBytes / 1024).toStringAsFixed(1)} KB';
    if (totalCacheSizeBytes < 1024 * 1024 * 1024) return '${(totalCacheSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(totalCacheSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Information about a downloaded state's data
class StateDownloadInfo {
  final String stateCode;
  final String stateName;
  final String dataVersion; // Legacy combined version (for backwards compatibility)
  final int propertyCount;
  final int trailCount; // Raw segment count
  final int uniqueTrailCount; // Distinct trail names (for display)
  final int historicalPlacesCount; // GNIS historical places (mines, ghost towns, etc.)
  final int totalSizeBytes;
  final DateTime downloadedAt;
  final String status;

  // Per-type version tracking (v6+)
  final String? landVersion;
  final String? trailsVersion;
  final String? historicalVersion;
  final String? cellVersion;

  // Cell tower count (v10+)
  final int cellTowerCount;

  const StateDownloadInfo({
    required this.stateCode,
    required this.stateName,
    required this.dataVersion,
    required this.propertyCount,
    required this.trailCount,
    required this.uniqueTrailCount,
    this.historicalPlacesCount = 0,
    required this.totalSizeBytes,
    required this.downloadedAt,
    required this.status,
    this.landVersion,
    this.trailsVersion,
    this.historicalVersion,
    this.cellVersion,
    this.cellTowerCount = 0,
  });

  /// Formatted size string (e.g., "15.2 MB")
  String get formattedSize {
    if (totalSizeBytes < 1024) return '$totalSizeBytes B';
    if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (totalSizeBytes < 1024 * 1024 * 1024) {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Whether this download is complete and usable
  bool get isComplete => status == 'complete';

  /// Check if a specific data type has data
  bool hasDataType(DataTypeLocal dataType) {
    switch (dataType) {
      case DataTypeLocal.land:
        return propertyCount > 0;
      case DataTypeLocal.trails:
        return trailCount > 0;
      case DataTypeLocal.historical:
        return historicalPlacesCount > 0;
      case DataTypeLocal.cell:
        return cellTowerCount > 0;
    }
  }

  /// Get version for a specific data type
  String? getVersion(DataTypeLocal dataType) {
    switch (dataType) {
      case DataTypeLocal.land:
        return landVersion ?? dataVersion; // Fallback to legacy version
      case DataTypeLocal.trails:
        return trailsVersion;
      case DataTypeLocal.historical:
        return historicalVersion;
      case DataTypeLocal.cell:
        return cellVersion;
    }
  }
}

/// Data types for per-type version tracking
enum DataTypeLocal {
  land,
  trails,
  historical,
  cell,
}

/// Download area status
enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
}

/// Download area model
class DownloadArea {
  final String id;
  final String name;
  final double centerLatitude;
  final double centerLongitude;
  final double radiusKm;
  final DownloadStatus status;
  final DateTime downloadedAt;
  final DateTime? lastAccessedAt;
  final double progress;
  final int? propertyCount;
  final int? estimatedSizeBytes;
  final String? errorMessage;

  const DownloadArea({
    required this.id,
    required this.name,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusKm,
    required this.status,
    required this.downloadedAt,
    this.lastAccessedAt,
    this.progress = 0.0,
    this.propertyCount,
    this.estimatedSizeBytes,
    this.errorMessage,
  });

  /// Check if cache is expired
  bool get isExpired {
    return DateTime.now().difference(downloadedAt) > const Duration(days: 30);
  }

  factory DownloadArea.fromMap(Map<String, dynamic> map) {
    return DownloadArea(
      id: map['id'] as String,
      name: map['name'] as String,
      centerLatitude: (map['center_latitude'] as num).toDouble(),
      centerLongitude: (map['center_longitude'] as num).toDouble(),
      radiusKm: (map['radius_km'] as num).toDouble(),
      status: DownloadStatus.values[map['status'] as int],
      downloadedAt: DateTime.parse(map['downloaded_at'] as String),
      lastAccessedAt: map['last_accessed_at'] != null
          ? DateTime.parse(map['last_accessed_at'] as String)
          : null,
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      propertyCount: map['property_count'] as int?,
      estimatedSizeBytes: map['estimated_size_bytes'] as int?,
      errorMessage: map['error_message'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'center_latitude': centerLatitude,
      'center_longitude': centerLongitude,
      'radius_km': radiusKm,
      'status': status.index,
      'downloaded_at': downloadedAt.toIso8601String(),
      'last_accessed_at': lastAccessedAt?.toIso8601String(),
      'progress': progress,
      'property_count': propertyCount,
      'estimated_size_bytes': estimatedSizeBytes,
      'error_message': errorMessage,
    };
  }

  DownloadArea copyWith({
    String? id,
    String? name,
    double? centerLatitude,
    double? centerLongitude,
    double? radiusKm,
    DownloadStatus? status,
    DateTime? downloadedAt,
    DateTime? lastAccessedAt,
    double? progress,
    int? propertyCount,
    int? estimatedSizeBytes,
    String? errorMessage,
  }) {
    return DownloadArea(
      id: id ?? this.id,
      name: name ?? this.name,
      centerLatitude: centerLatitude ?? this.centerLatitude,
      centerLongitude: centerLongitude ?? this.centerLongitude,
      radiusKm: radiusKm ?? this.radiusKm,
      status: status ?? this.status,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      progress: progress ?? this.progress,
      propertyCount: propertyCount ?? this.propertyCount,
      estimatedSizeBytes: estimatedSizeBytes ?? this.estimatedSizeBytes,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}