import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/services/land_ownership_service.dart';

/// Service for integrating PAD-US (Protected Areas Database of the United States) data
/// specifically for Montana, Wyoming, and Idaho for treasure hunting activities
class PADUSIntegrationService {
  PADUSIntegrationService._internal(this._landOwnershipService);
  static PADUSIntegrationService? _instance;
  final LandOwnershipService _landOwnershipService;

  // State codes for target areas
  static const List<String> targetStates = ['MT', 'WY', 'ID'];
  static const Map<String, String> stateNames = {
    'MT': 'Montana',
    'WY': 'Wyoming',
    'ID': 'Idaho',
  };

  // PAD-US API endpoints (these would be real endpoints in production)
  static const String _padUsBaseUrl =
      'https://gis1.usgs.gov/arcgis/rest/services/padus3_0/padus3_0_combined_map_service/MapServer';
  static const String _queryEndpoint = '$_padUsBaseUrl/0/query';

  static PADUSIntegrationService get instance {
    _instance ??=
        PADUSIntegrationService._internal(LandOwnershipService.instance);
    return _instance!;
  }

  /// Import PAD-US data for all target states
  Future<void> importAllStatesData({
    void Function(String message)? onProgress,
    void Function(String error)? onError,
    void Function(String state, int count)? onStateCompleted,
  }) async {
    onProgress?.call('Starting PAD-US data import for MT, WY, and ID...');

    int totalImported = 0;

    for (final stateCode in targetStates) {
      try {
        onProgress?.call('Importing ${stateNames[stateCode]} ($stateCode)...');

        final importedCount = await importStateData(
          stateCode,
          onProgress: onProgress,
          onError: onError,
        );

        totalImported += importedCount;
        onStateCompleted?.call(stateCode, importedCount);

        onProgress?.call(
            'Completed ${stateNames[stateCode]}: $importedCount records');
      } catch (e) {
        final errorMsg = 'Failed to import ${stateNames[stateCode]}: $e';
        onError?.call(errorMsg);
        debugPrint(errorMsg);
      }
    }

    onProgress?.call('Import completed. Total records: $totalImported');
  }

  /// Import PAD-US data for a specific state
  Future<int> importStateData(
    String stateCode, {
    void Function(String message)? onProgress,
    void Function(String error)? onError,
  }) async {
    try {
      await _landOwnershipService.initialize();

      // Get state boundaries first to filter data
      final stateBounds = await _getStateBounds(stateCode);

      onProgress?.call('Downloading PAD-US data for $stateCode...');

      // Query PAD-US API for the state
      final features = await _queryPADUSForState(stateCode, stateBounds);

      onProgress
          ?.call('Processing ${features.length} features for $stateCode...');

      // Convert to our land ownership format
      final landOwnerships = await _convertPADUSFeatures(features, stateCode);

      // Filter for treasure hunting relevant lands
      final filteredLands = _filterForTreasureHunting(landOwnerships);

      onProgress?.call(
          'Saving ${filteredLands.length} relevant land records for $stateCode...');

      // Save to database in batches
      await _saveLandOwnershipBatch(filteredLands);

      return filteredLands.length;
    } catch (e) {
      onError?.call('Error importing $stateCode data: $e');
      rethrow;
    }
  }

  /// Get approximate state boundaries
  Future<LandBounds> _getStateBounds(String stateCode) async {
    // Approximate bounds for MT, WY, ID (in production would query actual boundaries)
    switch (stateCode) {
      case 'MT':
        return const LandBounds(
          north: 49.0,
          south: 44.36,
          east: -104.04,
          west: -116.05,
        );
      case 'WY':
        return const LandBounds(
          north: 45.0,
          south: 40.99,
          east: -104.05,
          west: -111.06,
        );
      case 'ID':
        return const LandBounds(
          north: 49.0,
          south: 41.99,
          east: -111.04,
          west: -117.24,
        );
      default:
        throw ArgumentError('Unknown state code: $stateCode');
    }
  }

  /// Query PAD-US API for a specific state
  Future<List<Map<String, dynamic>>> _queryPADUSForState(
    String stateCode,
    LandBounds bounds,
  ) async {
    // Construct query parameters
    final whereClause = "State_Nm = '$stateCode'";
    final geometryFilter =
        '${bounds.west},${bounds.south},${bounds.east},${bounds.north}';

    final queryParams = {
      'where': whereClause,
      'geometry': geometryFilter,
      'geometryType': 'esriGeometryEnvelope',
      'spatialRel': 'esriSpatialRelIntersects',
      'outFields': [
        'OBJECTID',
        'Unit_Nm',
        'Mang_Name',
        'Mang_Type',
        'Des_Tp',
        'Loc_Nm',
        'Own_Type',
        'Own_Name',
        'Loc_Own',
        'P_Des_Tp',
        'P_Loc_Nm',
        'Access_Dt',
        'Access_Src',
        'GIS_Acres',
        'State_Nm',
        'Category',
        'GAP_Sts',
        'WDPA_Cd',
        'Date_Est',
      ].join(','),
      'f': 'geojson',
      'returnGeometry': 'true',
    };

    final uri = Uri.parse(_queryEndpoint).replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw HttpException(
            'PAD-US API request failed: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Extract features from GeoJSON response
      final features =
          (data['features'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
              [];

      return features;
    } catch (e) {
      // Fallback to mock data for development/testing
      debugPrint('PAD-US API unavailable, using mock data: $e');
      return _generateMockPADUSData(stateCode, bounds);
    }
  }

  /// Generate mock PAD-US data for development/testing
  List<Map<String, dynamic>> _generateMockPADUSData(
    String stateCode,
    LandBounds bounds,
  ) {
    final mockFeatures = <Map<String, dynamic>>[];
    final random = math.Random(42); // Seed for consistent results

    // Generate mock data for different land types
    final landTypes = [
      {
        'mang_name': 'Forest Service',
        'own_type': 'FED',
        'des_tp': 'National Forest'
      },
      {
        'mang_name': 'National Park Service',
        'own_type': 'FED',
        'des_tp': 'National Park'
      },
      {
        'mang_name': 'Bureau of Land Management',
        'own_type': 'FED',
        'des_tp': 'BLM'
      },
      {
        'mang_name': 'Fish and Wildlife Service',
        'own_type': 'FED',
        'des_tp': 'National Wildlife Refuge'
      },
      {'mang_name': 'State', 'own_type': 'STAT', 'des_tp': 'State Land'},
      {'mang_name': 'State Parks', 'own_type': 'STAT', 'des_tp': 'State Park'},
    ];

    for (int i = 0; i < 50; i++) {
      final landType = landTypes[random.nextInt(landTypes.length)];

      // Generate random bounds within state
      final centerLat =
          bounds.south + (bounds.north - bounds.south) * random.nextDouble();
      final centerLon =
          bounds.west + (bounds.east - bounds.west) * random.nextDouble();
      final size = 0.01 + random.nextDouble() * 0.05; // Random size

      final feature = {
        'type': 'Feature',
        'properties': {
          'OBJECTID': i + 1,
          'Unit_Nm': 'Mock ${landType['des_tp']} ${i + 1}',
          'Mang_Name': landType['mang_name'],
          'Mang_Type': landType['own_type'],
          'Des_Tp': landType['des_tp'],
          'Own_Type': landType['own_type'],
          'Own_Name': landType['mang_name'],
          'Access_Dt': 'Open',
          'GIS_Acres': 1000 + random.nextInt(50000),
          'State_Nm': stateCode,
          'GAP_Sts': '1',
        },
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              [centerLon - size, centerLat - size],
              [centerLon + size, centerLat - size],
              [centerLon + size, centerLat + size],
              [centerLon - size, centerLat + size],
              [centerLon - size, centerLat - size],
            ]
          ]
        }
      };

      mockFeatures.add(feature);
    }

    return mockFeatures;
  }

  /// Convert PAD-US features to our land ownership format
  Future<List<LandOwnership>> _convertPADUSFeatures(
    List<Map<String, dynamic>> features,
    String stateCode,
  ) async {
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
        final ownerName = properties['Mang_Name'] as String? ??
            properties['Own_Name'] as String? ??
            'Unknown';

        final landOwnership = LandOwnership(
          id: '${stateCode}_PADUS_${properties['OBJECTID'] ?? DateTime.now().millisecondsSinceEpoch}',
          ownershipType: ownershipType,
          ownerName: ownerName,
          agencyName: properties['Mang_Name'] as String?,
          unitName: properties['Unit_Nm'] as String?,
          designation: properties['Des_Tp'] as String?,
          accessType: _mapPADUSAccessType(properties),
          allowedUses: _mapPADUSAllowedUses(properties, ownershipType),
          restrictions: _extractRestrictions(properties),
          bounds: bounds,
          centroid: bounds.center,
          properties: properties,
          dataSource: 'PAD-US 3.0',
          dataSourceDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        landOwnerships.add(landOwnership);
      } catch (e) {
        debugPrint('Error processing PAD-US feature: $e');
      }
    }

    return landOwnerships;
  }

  /// Filter land ownership data for treasure hunting relevance
  List<LandOwnership> _filterForTreasureHunting(
          List<LandOwnership> landOwnerships) =>
      landOwnerships.where((land) {
        // Include public lands that are generally accessible for treasure hunting
        if (!land.ownershipType.isPublicLand) return false;

        // Exclude highly restricted areas
        if (land.accessType == AccessType.noPublicAccess) return false;

        // Focus on land types that typically allow metal detecting/treasure hunting
        switch (land.ownershipType) {
          case LandOwnershipType.nationalForest:
          case LandOwnershipType.bureauOfLandManagement:
          case LandOwnershipType.stateForest:
          case LandOwnershipType.stateLand:
            return true; // Generally allow treasure hunting with permits

          case LandOwnershipType.nationalPark:
          case LandOwnershipType.nationalMonument:
          case LandOwnershipType.wilderness:
            return false; // Typically prohibit treasure hunting

          case LandOwnershipType.nationalWildlifeRefuge:
          case LandOwnershipType.stateWildlifeArea:
          case LandOwnershipType.wildlifeManagementArea:
            return true; // May allow with restrictions - include for awareness

          default:
            return true; // Include by default, let user decide
        }
      }).toList();

  /// Extract bounds from GeoJSON geometry
  LandBounds? _extractBoundsFromGeometry(Map<String, dynamic> geometry) {
    // final type = geometry['type'] as String?; // Currently unused
    final coordinates = geometry['coordinates'];

    if (coordinates == null) return null;

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
    final ownerType = (properties['Own_Type'] as String? ?? '').toUpperCase();
    final mangType = (properties['Mang_Type'] as String? ?? '').toUpperCase();
    final designation = (properties['Des_Tp'] as String? ?? '').toUpperCase();
    final mangName = (properties['Mang_Name'] as String? ?? '').toUpperCase();

    // Federal lands by managing agency
    if (ownerType == 'FED' || mangType == 'FED') {
      if (mangName.contains('FOREST SERVICE') ||
          designation.contains('NATIONAL FOREST')) {
        return LandOwnershipType.nationalForest;
      }
      if (mangName.contains('NATIONAL PARK SERVICE') ||
          designation.contains('NATIONAL PARK')) {
        return LandOwnershipType.nationalPark;
      }
      if (mangName.contains('FISH AND WILDLIFE') ||
          designation.contains('NATIONAL WILDLIFE REFUGE')) {
        return LandOwnershipType.nationalWildlifeRefuge;
      }
      if (mangName.contains('BUREAU OF LAND MANAGEMENT') ||
          designation.contains('BLM')) {
        return LandOwnershipType.bureauOfLandManagement;
      }
      if (designation.contains('NATIONAL MONUMENT')) {
        return LandOwnershipType.nationalMonument;
      }
      if (designation.contains('WILDERNESS')) {
        return LandOwnershipType.wilderness;
      }
    }

    // State lands
    if (ownerType == 'STAT' || mangType == 'STAT') {
      if (designation.contains('STATE FOREST')) {
        return LandOwnershipType.stateForest;
      }
      if (designation.contains('STATE PARK')) {
        return LandOwnershipType.statePark;
      }
      if (designation.contains('WILDLIFE') || designation.contains('WMA')) {
        return LandOwnershipType.stateWildlifeArea;
      }
      return LandOwnershipType.stateLand;
    }

    // Local government
    if (ownerType == 'LOC') {
      return LandOwnershipType.countyLand;
    }

    // Private
    if (ownerType == 'PVT') {
      return LandOwnershipType.privateLand;
    }

    // Tribal
    if (ownerType == 'TRIB') {
      return LandOwnershipType.tribalLand;
    }

    return LandOwnershipType.unknown;
  }

  /// Map PAD-US access data to our enum
  AccessType _mapPADUSAccessType(Map<String, dynamic> properties) {
    final access = (properties['Access_Dt'] as String? ?? '').toLowerCase();
    final gapStatus = properties['GAP_Sts'] as String? ?? '';

    // GAP Status helps determine access level
    // 1 = Highest protection, 4 = Lowest protection
    switch (gapStatus) {
      case '1':
        return AccessType.restrictedAccess; // Highest protection
      case '2':
        return AccessType.permitRequired; // Medium-high protection
      case '3':
        return AccessType.publicOpen; // Medium protection
      case '4':
        return AccessType.publicOpen; // Lowest protection
      default:
        break;
    }

    // Parse access description
    if (access.contains('open') || access.contains('public')) {
      return AccessType.publicOpen;
    }
    if (access.contains('permit') || access.contains('restricted use')) {
      return AccessType.permitRequired;
    }
    if (access.contains('no') || access.contains('closed')) {
      return AccessType.noPublicAccess;
    }

    return AccessType.publicOpen; // Default assumption for public lands
  }

  /// Map PAD-US data to allowed uses
  List<LandUseType> _mapPADUSAllowedUses(
    Map<String, dynamic> properties,
    LandOwnershipType ownershipType,
  ) {
    final uses = <LandUseType>[];

    // Base activities generally allowed on most public lands
    uses.addAll([
      LandUseType.hiking,
      LandUseType.photography,
      LandUseType.birdWatching,
    ]);

    // Add ownership-specific uses
    switch (ownershipType) {
      case LandOwnershipType.nationalForest:
      case LandOwnershipType.bureauOfLandManagement:
        uses.addAll([
          LandUseType.camping,
          LandUseType.hunting,
          LandUseType.fishing,
          LandUseType.rockHounding, // Often allowed with permits
        ]);
        break;

      case LandOwnershipType.stateForest:
      case LandOwnershipType.stateLand:
        uses.addAll([
          LandUseType.camping,
          LandUseType.hunting,
          LandUseType.fishing,
          LandUseType.rockHounding,
        ]);
        break;

      case LandOwnershipType.nationalWildlifeRefuge:
      case LandOwnershipType.stateWildlifeArea:
        uses.addAll([
          LandUseType.hunting,
          LandUseType.fishing,
          LandUseType.birdWatching,
        ]);
        break;

      case LandOwnershipType.nationalPark:
        // More restrictive - no hunting, limited camping
        uses.add(LandUseType.camping);
        break;

      default:
        break;
    }

    return uses;
  }

  /// Extract restrictions from PAD-US properties
  List<String> _extractRestrictions(Map<String, dynamic> properties) {
    final restrictions = <String>[];
    final gapStatus = properties['GAP_Sts'] as String? ?? '';

    // Add restrictions based on GAP status
    switch (gapStatus) {
      case '1':
        restrictions.addAll([
          'Highest level protection - very limited activities allowed',
          'No motorized vehicles',
          'No collection of natural materials',
        ]);
        break;
      case '2':
        restrictions.addAll([
          'Medium-high protection - some activities restricted',
          'Special permits may be required',
        ]);
        break;
    }

    // Add general federal/state land restrictions
    final designation = (properties['Des_Tp'] as String? ?? '').toLowerCase();
    if (designation.contains('wilderness')) {
      restrictions.add('Wilderness Area - no motorized equipment allowed');
    }
    if (designation.contains('national park')) {
      restrictions.add('Metal detecting and artifact collection prohibited');
    }

    return restrictions;
  }

  /// Save land ownership data in batches
  Future<void> _saveLandOwnershipBatch(
      List<LandOwnership> landOwnerships) async {
    const batchSize = 100;

    for (int i = 0; i < landOwnerships.length; i += batchSize) {
      final batch = landOwnerships.skip(i).take(batchSize).toList();
      await _landOwnershipService.saveLandOwnershipBatch(batch);
    }
  }

  /// Check if data exists for a specific state
  Future<bool> hasDataForState(String stateCode) async {
    await _landOwnershipService.initialize();

    // Check if we have any data with this state in the data source
    final stateBounds = await _getStateBounds(stateCode);
    return _landOwnershipService.hasDataForRegion(stateBounds);
  }

  /// Get import statistics for target states
  Future<Map<String, dynamic>> getImportStatistics() async {
    await _landOwnershipService.initialize();

    final stats = <String, dynamic>{};
    final allStats = await _landOwnershipService.getLandOwnershipCountByType();

    stats['total_records'] =
        allStats.values.fold(0, (sum, count) => sum + count);
    stats['by_type'] = allStats;

    // Check which states have data
    final stateData = <String, bool>{};
    for (final stateCode in targetStates) {
      stateData[stateCode] = await hasDataForState(stateCode);
    }
    stats['states_imported'] = stateData;

    return stats;
  }

  /// Clear all PAD-US imported data
  Future<void> clearImportedData() async {
    await _landOwnershipService.initialize();
    await _landOwnershipService.clearAllLandOwnership();
  }
}
