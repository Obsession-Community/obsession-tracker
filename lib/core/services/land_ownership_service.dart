import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Service for managing land ownership data
class LandOwnershipService {
  LandOwnershipService._internal(this._databaseService);
  static LandOwnershipService? _instance;
  Database? _database;
  final DatabaseService _databaseService;

  static LandOwnershipService get instance {
    _instance ??= LandOwnershipService._internal(DatabaseService());
    return _instance!;
  }

  /// Initialize the service and create tables if needed
  Future<void> initialize() async {
    _database = await _databaseService.database;
    await _createTables();
  }

  /// Create land ownership tables
  Future<void> _createTables() async {
    if (_database == null) return;

    await _database!.execute('''
      CREATE TABLE IF NOT EXISTS land_ownership (
        id TEXT PRIMARY KEY,
        ownership_type TEXT NOT NULL,
        owner_name TEXT NOT NULL,
        agency_name TEXT,
        unit_name TEXT,
        designation TEXT,
        access_type TEXT NOT NULL,
        allowed_uses TEXT, -- JSON array
        restrictions TEXT, -- JSON array
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
        polygon_coordinates TEXT, -- GeoJSON polygon coordinates
        properties TEXT, -- JSON object
        data_source TEXT NOT NULL,
        data_source_date INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Migration: Add polygon_coordinates column if it doesn't exist (for existing databases)
    try {
      await _database!.execute('''
        ALTER TABLE land_ownership ADD COLUMN polygon_coordinates TEXT
      ''');
    } catch (e) {
      // Column already exists, ignore
    }

    // Create spatial index for efficient queries
    await _database!.execute('''
      CREATE INDEX IF NOT EXISTS idx_land_ownership_bounds
      ON land_ownership (north_bound, south_bound, east_bound, west_bound)
    ''');

    await _database!.execute('''
      CREATE INDEX IF NOT EXISTS idx_land_ownership_type
      ON land_ownership (ownership_type)
    ''');

    await _database!.execute('''
      CREATE INDEX IF NOT EXISTS idx_land_ownership_centroid
      ON land_ownership (centroid_latitude, centroid_longitude)
    ''');
  }

  /// Save land ownership data to database
  Future<void> saveLandOwnership(LandOwnership landOwnership) async {
    if (_database == null) await initialize();

    await _database!.insert(
      'land_ownership',
      landOwnership.toDatabaseRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Save multiple land ownership records in a batch
  Future<void> saveLandOwnershipBatch(
      List<LandOwnership> landOwnerships) async {
    if (_database == null) await initialize();
    if (landOwnerships.isEmpty) return;

    final batch = _database!.batch();
    for (final land in landOwnerships) {
      batch.insert(
        'land_ownership',
        land.toDatabaseRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Get land ownership by ID
  Future<LandOwnership?> getLandOwnershipById(String id) async {
    if (_database == null) await initialize();

    final result = await _database!.query(
      'land_ownership',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return result.isNotEmpty ? LandOwnership.fromDatabase(result.first) : null;
  }

  /// Get land ownership data within specified bounds
  Future<List<LandOwnership>> getLandOwnershipInBounds(
      LandBounds bounds) async {
    if (_database == null) await initialize();

    // Query for overlapping bounds
    final result = await _database!.query(
      'land_ownership',
      where: '''
        north_bound >= ? AND south_bound <= ? AND
        east_bound >= ? AND west_bound <= ?
      ''',
      whereArgs: [bounds.south, bounds.north, bounds.west, bounds.east],
    );

    return result.map(LandOwnership.fromDatabase).toList();
  }

  /// Get land ownership data near a point with radius (in degrees)
  Future<List<LandOwnership>> getLandOwnershipNearPoint(
    LandPoint point,
    double radiusDegrees,
  ) async {
    if (_database == null) await initialize();

    final bounds = LandBounds(
      north: point.latitude + radiusDegrees,
      south: point.latitude - radiusDegrees,
      east: point.longitude + radiusDegrees,
      west: point.longitude - radiusDegrees,
    );

    return getLandOwnershipInBounds(bounds);
  }

  /// Get land ownership data by type
  Future<List<LandOwnership>> getLandOwnershipByType(
    LandOwnershipType type,
  ) async {
    if (_database == null) await initialize();

    final result = await _database!.query(
      'land_ownership',
      where: 'ownership_type = ?',
      whereArgs: [type.name],
    );

    return result.map(LandOwnership.fromDatabase).toList();
  }

  /// Get land ownership data by multiple types
  Future<List<LandOwnership>> getLandOwnershipByTypes(
    List<LandOwnershipType> types,
  ) async {
    if (_database == null) await initialize();
    if (types.isEmpty) return [];

    final placeholders = List.generate(types.length, (_) => '?').join(',');
    final result = await _database!.query(
      'land_ownership',
      where: 'ownership_type IN ($placeholders)',
      whereArgs: types.map((t) => t.name).toList(),
    );

    return result.map(LandOwnership.fromDatabase).toList();
  }

  /// Search land ownership by name, agency, or designation
  Future<List<LandOwnership>> searchLandOwnership(String query) async {
    if (_database == null) await initialize();
    if (query.isEmpty) return [];

    final searchTerm = '%${query.toLowerCase()}%';
    final result = await _database!.query(
      'land_ownership',
      where: '''
        LOWER(owner_name) LIKE ? OR
        LOWER(agency_name) LIKE ? OR
        LOWER(unit_name) LIKE ? OR
        LOWER(designation) LIKE ?
      ''',
      whereArgs: [searchTerm, searchTerm, searchTerm, searchTerm],
    );

    return result.map(LandOwnership.fromDatabase).toList();
  }

  /// Get filtered land ownership data
  Future<List<LandOwnership>> getFilteredLandOwnership(
    LandOwnershipFilter filter,
    LandBounds? bounds,
  ) async {
    if (_database == null) await initialize();

    String whereClause = '';
    final List<dynamic> whereArgs = [];

    // Add bounds filter if provided
    if (bounds != null) {
      whereClause += '''
        north_bound >= ? AND south_bound <= ? AND
        east_bound >= ? AND west_bound <= ?
      ''';
      whereArgs.addAll([bounds.south, bounds.north, bounds.west, bounds.east]);
    }

    // Add type filter
    final Set<String> allowedTypes = {};

    // If specific types are enabled, use those
    if (filter.enabledTypes.isNotEmpty) {
      allowedTypes.addAll(filter.enabledTypes.map((t) => t.name));
    }

    // Add types from boolean filters (these can expand the allowedTypes set)
    if (filter.showPublicLandOnly) {
      allowedTypes.addAll(LandOwnershipType.values
          .where((t) => t.isPublicLand)
          .map((t) => t.name));
    }

    if (filter.showPrivateLandOnly) {
      allowedTypes.addAll(LandOwnershipType.values
          .where((t) => !t.isPublicLand)
          .map((t) => t.name));
    }

    if (filter.showFederalLandOnly) {
      allowedTypes.addAll([
        LandOwnershipType.nationalForest.name,
        LandOwnershipType.nationalPark.name,
        LandOwnershipType.bureauOfLandManagement.name,
        LandOwnershipType.nationalWildlifeRefuge.name,
        LandOwnershipType.nationalMonument.name,
        LandOwnershipType.nationalRecreationArea.name,
        LandOwnershipType.wilderness.name,
      ]);
    }

    if (filter.showStateLandOnly) {
      allowedTypes.addAll([
        LandOwnershipType.stateForest.name,
        LandOwnershipType.statePark.name,
        LandOwnershipType.stateWildlifeArea.name,
        LandOwnershipType.stateLand.name,
      ]);
    }

    // If no types are allowed, return empty result
    if (allowedTypes.isEmpty) {
      return [];
    }

    // Apply the type filter
    final placeholders =
        List.generate(allowedTypes.length, (_) => '?').join(',');
    if (whereClause.isNotEmpty) whereClause += ' AND ';
    whereClause += 'ownership_type IN ($placeholders)';
    whereArgs.addAll(allowedTypes);

    // Add search query filter
    if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
      final searchTerm = '%${filter.searchQuery!.toLowerCase()}%';

      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += '''
        (LOWER(owner_name) LIKE ? OR
         LOWER(agency_name) LIKE ? OR
         LOWER(unit_name) LIKE ? OR
         LOWER(designation) LIKE ?)
      ''';
      whereArgs.addAll([searchTerm, searchTerm, searchTerm, searchTerm]);
    }

    final result = await _database!.query(
      'land_ownership',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );

    final lands = result.map(LandOwnership.fromDatabase).toList();

    // Apply additional filters that can't be done in SQL
    return lands.where((land) => filter.passes(land)).toList();
  }

  /// Get count of land ownership records
  Future<int> getLandOwnershipCount() async {
    if (_database == null) await initialize();

    final result = await _database!
        .rawQuery('SELECT COUNT(*) as count FROM land_ownership');
    return (result.first['count'] as int?) ?? 0;
  }

  /// Get count by ownership type
  Future<Map<LandOwnershipType, int>> getLandOwnershipCountByType() async {
    if (_database == null) await initialize();

    final result = await _database!.rawQuery('''
      SELECT ownership_type, COUNT(*) as count
      FROM land_ownership
      GROUP BY ownership_type
    ''');

    final counts = <LandOwnershipType, int>{};
    for (final row in result) {
      final typeName = row['ownership_type']! as String;
      final count = row['count']! as int;
      final type = LandOwnershipType.values.firstWhere(
          (t) => t.name == typeName,
          orElse: () => LandOwnershipType.unknown);
      counts[type] = count;
    }

    return counts;
  }

  /// Delete land ownership record
  Future<void> deleteLandOwnership(String id) async {
    if (_database == null) await initialize();

    await _database!.delete(
      'land_ownership',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clear all land ownership data
  Future<void> clearAllLandOwnership() async {
    if (_database == null) await initialize();

    await _database!.delete('land_ownership');
  }

  /// Import PAD-US data for specific states
  Future<void> importPADUSData(
    List<String> stateCodes, {
    void Function(String)? onProgress,
    void Function(String)? onError,
  }) async {
    for (final stateCode in stateCodes) {
      try {
        onProgress?.call('Downloading PAD-US data for $stateCode...');

        // Example URL - would need to be replaced with actual PAD-US data endpoints
        final url =
            'https://gis1.usgs.gov/arcgis/rest/services/padus/pad_us_map_service/MapServer/0/query'
            "?where=STATE_NM='${stateCode.toUpperCase()}'"
            '&outFields=*&f=geojson&returnGeometry=true';

        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          await _processPADUSGeoJSON(data, stateCode);
          onProgress?.call('Completed importing PAD-US data for $stateCode');
        } else {
          onError?.call(
              'Failed to download data for $stateCode: ${response.statusCode}');
        }
      } catch (e) {
        onError?.call('Error importing data for $stateCode: $e');
      }
    }
  }

  /// Process PAD-US GeoJSON data
  Future<void> _processPADUSGeoJSON(
      Map<String, dynamic> geoJson, String stateCode) async {
    final features = geoJson['features'] as List<dynamic>? ?? [];
    final landOwnerships = <LandOwnership>[];

    for (final feature in features) {
      try {
        final properties = feature['properties'] as Map<String, dynamic>? ?? {};
        final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};

        // Extract bounds from geometry
        final bounds = _extractBoundsFromGeometry(geometry);
        if (bounds == null) continue;

        // Map PAD-US fields to our model
        final ownershipType = _mapPADUSOwnershipType(properties);
        final ownerName = properties['Mang_Name'] as String? ?? 'Unknown';
        final agencyName = properties['Mang_Agency'] as String?;
        final unitName = properties['Unit_Nm'] as String?;
        final designation = properties['Des_Tp'] as String?;

        final landOwnership = LandOwnership(
          id: '${stateCode}_${properties['OBJECTID'] ?? DateTime.now().millisecondsSinceEpoch}',
          ownershipType: ownershipType,
          ownerName: ownerName,
          agencyName: agencyName,
          unitName: unitName,
          designation: designation,
          accessType: _mapPADUSAccessType(properties),
          allowedUses: _mapPADUSAllowedUses(properties),
          bounds: bounds,
          centroid: bounds.center,
          properties: properties,
          dataSource: 'PAD-US',
          dataSourceDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        landOwnerships.add(landOwnership);
      } catch (e) {
        debugPrint('Error processing PAD-US feature: $e');
      }
    }

    if (landOwnerships.isNotEmpty) {
      await saveLandOwnershipBatch(landOwnerships);
      debugPrint(
          'Imported ${landOwnerships.length} land ownership records for $stateCode');
    }
  }

  /// Extract bounds from GeoJSON geometry
  LandBounds? _extractBoundsFromGeometry(Map<String, dynamic> geometry) {
    // final type = geometry['type'] as String?; // Currently unused
    final coordinates = geometry['coordinates'];

    if (coordinates == null) return null;

    // Simplified bounds extraction - would need more robust implementation for complex geometries
    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLon = double.infinity;
    double maxLon = double.negativeInfinity;

    void processCoordinate(List<dynamic> coord) {
      if (coord.length >= 2) {
        final lon = (coord[0] as num).toDouble();
        final lat = (coord[1] as num).toDouble();
        minLat = math.min(minLat, lat);
        maxLat = math.max(maxLat, lat);
        minLon = math.min(minLon, lon);
        maxLon = math.max(maxLon, lon);
      }
    }

    void processCoordinates(Object? coords) {
      if (coords is List) {
        for (final item in coords) {
          if (item is List) {
            if (item.isNotEmpty && item[0] is num) {
              processCoordinate(item);
            } else {
              processCoordinates(item);
            }
          }
        }
      }
    }

    processCoordinates(coordinates);

    if (minLat == double.infinity) return null;

    return LandBounds(
      north: maxLat,
      south: minLat,
      east: maxLon,
      west: minLon,
    );
  }

  /// Map PAD-US ownership data to our enum
  LandOwnershipType _mapPADUSOwnershipType(Map<String, dynamic> properties) {
    final ownerType = properties['Own_Type'] as String? ?? '';
    final designation = properties['Des_Tp'] as String? ?? '';
    final agency = properties['Mang_Agency'] as String? ?? '';

    // Federal lands
    if (agency.contains('FS') || designation.contains('National Forest')) {
      return LandOwnershipType.nationalForest;
    }
    if (agency.contains('NPS') || designation.contains('National Park')) {
      return LandOwnershipType.nationalPark;
    }
    if (agency.contains('FWS') ||
        designation.contains('National Wildlife Refuge')) {
      return LandOwnershipType.nationalWildlifeRefuge;
    }
    if (agency.contains('BLM')) {
      return LandOwnershipType.bureauOfLandManagement;
    }
    if (designation.contains('Wilderness')) {
      return LandOwnershipType.wilderness;
    }

    // State lands
    if (ownerType.contains('State') || agency.contains('State')) {
      if (designation.contains('Forest')) return LandOwnershipType.stateForest;
      if (designation.contains('Park')) return LandOwnershipType.statePark;
      if (designation.contains('Wildlife'))
        return LandOwnershipType.stateWildlifeArea;
      return LandOwnershipType.stateLand;
    }

    // Local government
    if (ownerType.contains('County')) return LandOwnershipType.countyLand;
    if (ownerType.contains('City') || ownerType.contains('Municipal')) {
      return LandOwnershipType.cityLand;
    }

    // Tribal
    if (ownerType.contains('Tribal') || agency.contains('Tribal')) {
      return LandOwnershipType.tribalLand;
    }

    // Private
    if (ownerType.contains('Private')) {
      return LandOwnershipType.privateLand;
    }

    return LandOwnershipType.unknown;
  }

  /// Map PAD-US access data to our enum
  AccessType _mapPADUSAccessType(Map<String, dynamic> properties) {
    final access = properties['Access'] as String? ?? '';
    final publicAccess = properties['Pub_Access'] as String? ?? '';

    if (access.toLowerCase().contains('open') ||
        publicAccess.toLowerCase().contains('open')) {
      return AccessType.publicOpen;
    }
    if (access.toLowerCase().contains('permit') ||
        publicAccess.toLowerCase().contains('permit')) {
      return AccessType.permitRequired;
    }
    if (access.toLowerCase().contains('fee') ||
        publicAccess.toLowerCase().contains('fee')) {
      return AccessType.feeRequired;
    }
    if (access.toLowerCase().contains('restricted') ||
        publicAccess.toLowerCase().contains('restricted')) {
      return AccessType.restrictedAccess;
    }
    if (access.toLowerCase().contains('no') ||
        publicAccess.toLowerCase().contains('no')) {
      return AccessType.noPublicAccess;
    }

    return AccessType.publicOpen; // Default for public lands
  }

  /// Map PAD-US data to allowed uses
  List<LandUseType> _mapPADUSAllowedUses(Map<String, dynamic> properties) {
    final uses = <LandUseType>[];

    // Default uses for public lands
    uses.addAll([
      LandUseType.hiking,
      LandUseType.photography,
      LandUseType.birdWatching,
    ]);

    // Add camping if camping is mentioned
    final designation = properties['Des_Tp'] as String? ?? '';
    if (designation.toLowerCase().contains('recreation') ||
        designation.toLowerCase().contains('forest')) {
      uses.add(LandUseType.camping);
    }

    // Add hunting/fishing for wildlife areas
    if (designation.toLowerCase().contains('wildlife') ||
        designation.toLowerCase().contains('refuge')) {
      uses.addAll(
          [LandUseType.hunting, LandUseType.fishing, LandUseType.birdWatching]);
    }

    return uses;
  }

  /// Check if land ownership data exists for a region
  Future<bool> hasDataForRegion(LandBounds bounds) async {
    if (_database == null) await initialize();

    final result = await _database!.query(
      'land_ownership',
      where: '''
        north_bound >= ? AND south_bound <= ? AND
        east_bound >= ? AND west_bound <= ?
      ''',
      whereArgs: [bounds.south, bounds.north, bounds.west, bounds.east],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  /// Get data source information
  Future<Map<String, DateTime?>> getDataSources() async {
    if (_database == null) await initialize();

    final result = await _database!.rawQuery('''
      SELECT data_source, MAX(data_source_date) as latest_date
      FROM land_ownership
      GROUP BY data_source
    ''');

    final sources = <String, DateTime?>{};
    for (final row in result) {
      final source = row['data_source']! as String;
      final dateMs = row['latest_date'] as int?;
      sources[source] =
          dateMs != null ? DateTime.fromMillisecondsSinceEpoch(dateMs) : null;
    }

    return sources;
  }

  /// Delete land ownership data by data source
  Future<int> deleteByDataSource(String dataSource) async {
    if (_database == null) await initialize();

    // Get count before deletion for return value using rawQuery
    final countResult = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM land_ownership WHERE data_source = ?',
      [dataSource],
    );
    final deletedCount = (countResult.first['count'] as int?) ?? 0;

    // Delete the records
    await _database!.delete(
      'land_ownership',
      where: 'data_source = ?',
      whereArgs: [dataSource],
    );

    return deletedCount;
  }

  /// Get count of records by data source
  Future<Map<String, int>> getCountByDataSource() async {
    if (_database == null) await initialize();

    final result = await _database!.rawQuery('''
      SELECT data_source, COUNT(*) as count
      FROM land_ownership
      GROUP BY data_source
      ORDER BY data_source
    ''');

    final counts = <String, int>{};
    for (final row in result) {
      final source = row['data_source'] as String?;
      final count = row['count'] as int?;
      if (source != null && count != null) {
        counts[source] = count;
        // Track data source counts for debugging
      }
    }

    return counts;
  }

  /// Debug method to see all data sources in database
  Future<List<String>> getAllDataSources() async {
    if (_database == null) await initialize();

    final result = await _database!.rawQuery('''
      SELECT DISTINCT data_source
      FROM land_ownership
      ORDER BY data_source
    ''');

    return result.map((row) => row['data_source']! as String).toList();
  }

  /// Dispose of resources
  void dispose() {
    // Database is managed by DatabaseService, no need to close here
  }
}
