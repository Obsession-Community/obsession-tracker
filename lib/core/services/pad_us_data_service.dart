import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/services/land_ownership_service.dart';
import 'package:obsession_tracker/core/services/nps_api_service.dart';

/// Service to import real PAD-US protected areas data
/// Updated with hybrid approach using NPS API + PAD-US data
class PadUsDataService {
  factory PadUsDataService() => _instance;
  PadUsDataService._internal();
  static final PadUsDataService _instance = PadUsDataService._internal();

  final LandOwnershipService _landService = LandOwnershipService.instance;

  // PAD-US ArcGIS REST Feature Service endpoint (known issues with SD data)
  static const String _baseUrl =
      'https://services.arcgis.com/v01gqwM5QqNysAAi/arcgis/rest/services/Manager_Name/FeatureServer/0/query';

  // National Park Service API endpoint (reliable for federal parks)
  // Kept for future direct NPS integration
  // ignore: unused_field
  static const String _npsBaseUrl = 'https://developer.nps.gov/api/v1/parks';
  // ignore: unused_field
  static const String _npsApiKey = String.fromEnvironment('NPS_API_KEY', defaultValue: '');

  /// Download PAD-US data for the Black Hills region using hybrid approach
  /// Uses NPS API for federal parks + PAD-US for other protected areas
  Future<void> downloadBlackHillsData() async {
    await _landService.initialize();

    debugPrint('Starting PAD-US data download for Black Hills region...');

    // Black Hills/Wind Cave area bounds (South Dakota)
    const bounds = LandBounds(
      north: 44.5, // Northern Black Hills
      south: 43.0, // Southern Black Hills including Wind Cave
      east: -103.0, // Eastern boundary
      west: -104.5, // Western boundary
    );

    try {
      // First, get NPS parks for South Dakota (reliable data source)
      final npsParks = await _queryNpsParks('SD');
      debugPrint('Downloaded ${npsParks.length} NPS parks from official API');

      // Then try PAD-US data (may return empty due to known API issues)
      final protectedAreas = await _queryPadUsData(bounds);
      debugPrint(
          'Downloaded ${protectedAreas.length} protected areas from PAD-US');

      // Clear existing data first
      await _landService.clearAllLandOwnership();

      // Convert and save NPS data first (priority data)
      int savedCount = 0;
      for (final landOwnership in npsParks) {
        await _landService.saveLandOwnership(landOwnership);
        savedCount++;
      }

      // Convert and save PAD-US data (supplementary)
      for (final areaData in protectedAreas) {
        final landOwnership = _convertPadUsToLandOwnership(areaData);
        if (landOwnership != null) {
          await _landService.saveLandOwnership(landOwnership);
          savedCount++;
        }
      }

      debugPrint(
          'Successfully imported $savedCount total records (NPS + PAD-US) into database');

      // Verify we got expected South Dakota landmarks
      final verification = await _verifyExpectedLandmarks();
      debugPrint('Landmark verification: $verification');
    } catch (e, stackTrace) {
      debugPrint('Error downloading PAD-US data: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Query National Park Service API using dedicated service
  Future<List<LandOwnership>> _queryNpsParks(String stateCode) async {
    final npsService = NpsApiService();
    final parks = await npsService.getSouthDakotaParks();
    debugPrint('NPS Service returned ${parks.length} parks');
    return parks;
  }

  /// Convert NPS park data to our LandOwnership model
  // Kept for future use when direct NPS data conversion is needed
  // ignore: unused_element
  LandOwnership? _convertNpsToLandOwnership(Map<String, dynamic> parkData) {
    try {
      final parkName = parkData['name'] as String?;
      final parkCode = parkData['parkCode'] as String?;
      final designation = parkData['designation'] as String?;
      final description = parkData['description'] as String?;
      final url = parkData['url'] as String?;
      final latLong = parkData['latLong'] as String?;

      if (parkName == null || parkCode == null) {
        debugPrint('Skipping NPS park with missing name/code');
        return null;
      }

      // Parse coordinates if available
      LandPoint? centroid;
      LandBounds? bounds;

      if (latLong != null && latLong.contains(',')) {
        try {
          final parts = latLong.split(',');
          if (parts.length >= 2) {
            final lat = double.tryParse(parts[0].replaceAll('lat:', '').trim());
            final lng =
                double.tryParse(parts[1].replaceAll('long:', '').trim());

            if (lat != null && lng != null) {
              centroid = LandPoint(latitude: lat, longitude: lng);
              // Create small bounds around the point (NPS API only provides points)
              const offset = 0.01; // ~1km buffer
              bounds = LandBounds(
                north: lat + offset,
                south: lat - offset,
                east: lng + offset,
                west: lng - offset,
              );
            }
          }
        } catch (e) {
          debugPrint('Error parsing NPS coordinates: $e');
        }
      }

      // Fallback bounds for South Dakota if no coordinates
      bounds ??= const LandBounds(
        north: 44.5,
        south: 43.0,
        east: -103.0,
        west: -104.5,
      );
      centroid ??= bounds.center;

      // Determine ownership type based on designation
      final ownershipType = _mapNpsDesignationToOwnershipType(designation);

      final now = DateTime.now();
      return LandOwnership(
        id: 'nps_${parkCode.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
        ownershipType: ownershipType,
        ownerName: parkName,
        agencyName: 'National Park Service',
        unitName: parkName,
        designation: designation,
        accessType: AccessType.feeRequired, // Most NPS units require fees
        allowedUses: _getAllowedUsesForNpsType(ownershipType),
        restrictions: _getRestrictionsForNpsType(ownershipType),
        contactInfo: url,
        website: url,
        fees: 'Check park website for current fees',
        seasonalInfo: 'Hours and access may vary by season',
        bounds: bounds,
        centroid: centroid,
        properties: {
          'nps_park_code': parkCode,
          'nps_designation': designation ?? '',
          'nps_description': description ?? '',
          'nps_coordinates': latLong ?? '',
        },
        dataSource: 'NPS_API_v1',
        dataSourceDate: now,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e, stackTrace) {
      debugPrint('Error converting NPS park: $e');
      debugPrint('Park data: $parkData');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Query PAD-US REST service for protected areas within bounds
  Future<List<Map<String, dynamic>>> _queryPadUsData(LandBounds bounds) async {
    // Create spatial query for the bounding box
    const whereClause =
        "State_Nm = 'SD'"; // Use state code (corrected from research)

    final queryParams = {
      'where': whereClause,
      'geometry':
          '${bounds.west},${bounds.south},${bounds.east},${bounds.north}',
      'geometryType': 'esriGeometryEnvelope',
      'spatialRel': 'esriSpatialRelIntersects',
      'outFields': '*', // Get all fields
      'returnGeometry': 'true',
      'f': 'geojson', // Request GeoJSON format
    };

    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

    debugPrint('Querying PAD-US: ${uri.toString()}');

    try {
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint(
            'PAD-US query failed: ${response.statusCode} - ${response.body}');
        return []; // Return empty list on failure (known API issues)
      }

      final geoJson = json.decode(response.body) as Map<String, dynamic>;

      // Check for ArcGIS error response
      if (geoJson.containsKey('error')) {
        debugPrint('PAD-US API error: ${geoJson['error']}');
        return [];
      }

      if (geoJson['type'] != 'FeatureCollection') {
        debugPrint('Invalid GeoJSON response from PAD-US: ${geoJson['type']}');
        return [];
      }

      final features = geoJson['features'] as List<dynamic>;
      debugPrint('PAD-US returned ${features.length} features');
      return features.map((f) => f as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error querying PAD-US API: $e');
      return []; // Don't throw, just return empty list
    }
  }

  /// Convert PAD-US feature data to our LandOwnership model
  LandOwnership? _convertPadUsToLandOwnership(Map<String, dynamic> feature) {
    try {
      final properties = feature['properties'] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>?;

      // Extract key properties from PAD-US data
      final unitName = properties['Unit_Nm'] as String?;
      final managerName = properties['Mang_Name'] as String?;
      final managerType = properties['Mang_Type'] as String?;
      final localName = properties['Loc_Nm'] as String?;
      final stateName = properties['State_Nm'] as String?;
      final gapStatus = properties['GAP_Sts'] as String?;
      final access = properties['Access_Sts'] as String?;

      if (unitName == null || managerName == null) {
        debugPrint('Skipping PAD-US record with missing unit/manager name');
        return null;
      }

      // Determine ownership type based on manager type
      final ownershipType = _mapPadUsToOwnershipType(managerType, managerName);

      // Calculate bounds from geometry if available
      LandBounds? bounds;
      LandPoint? centroid;

      if (geometry != null) {
        bounds = _calculateBoundsFromGeometry(geometry);
        centroid = bounds?.center;
      }

      // Use fallback bounds for Black Hills area if no geometry
      bounds ??= const LandBounds(
        north: 43.8,
        south: 43.2,
        east: -103.2,
        west: -103.8,
      );
      centroid ??= bounds.center;

      // Map access status
      final accessType = _mapPadUsAccessType(access, gapStatus);

      // Determine allowed uses based on ownership type and access
      final allowedUses =
          _getAllowedUsesForPadUsType(ownershipType, accessType);

      final now = DateTime.now();
      return LandOwnership(
        id: 'padus_${unitName.replaceAll(' ', '_').toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
        ownershipType: ownershipType,
        ownerName: unitName,
        agencyName: managerName,
        unitName: localName ?? unitName,
        designation: gapStatus,
        accessType: accessType,
        allowedUses: allowedUses,
        restrictions: _getRestrictionsForType(ownershipType),
        fees: accessType == AccessType.feeRequired ? 'Varies by area' : null,
        bounds: bounds,
        centroid: centroid,
        properties: {
          'padus_manager_type': managerType ?? '',
          'padus_state': stateName ?? '',
          'padus_gap_status': gapStatus ?? '',
          'padus_access_status': access ?? '',
        },
        dataSource: 'PAD-US_v3.0',
        dataSourceDate: now,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e, stackTrace) {
      debugPrint('Error converting PAD-US feature: $e');
      debugPrint('Feature data: $feature');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Map NPS designation to our ownership type enum
  LandOwnershipType _mapNpsDesignationToOwnershipType(String? designation) {
    if (designation == null) return LandOwnershipType.nationalPark;

    final designationLower = designation.toLowerCase();

    if (designationLower.contains('national park'))
      return LandOwnershipType.nationalPark;
    if (designationLower.contains('national monument'))
      return LandOwnershipType.nationalMonument;
    if (designationLower.contains('national memorial'))
      return LandOwnershipType.nationalMonument;
    if (designationLower.contains('national historic'))
      return LandOwnershipType.nationalMonument;
    if (designationLower.contains('national recreational'))
      return LandOwnershipType.nationalForest;

    return LandOwnershipType.nationalPark; // Default for NPS units
  }

  /// Get allowed uses for NPS park types
  List<LandUseType> _getAllowedUsesForNpsType(LandOwnershipType type) {
    switch (type) {
      case LandOwnershipType.nationalPark:
        return [
          LandUseType.hiking,
          LandUseType.camping,
          LandUseType.photography,
          LandUseType.birdWatching,
        ];
      case LandOwnershipType.nationalMonument:
        return [
          LandUseType.hiking,
          LandUseType.photography,
          LandUseType.birdWatching,
        ];
      default:
        return [
          LandUseType.hiking,
          LandUseType.photography,
        ];
    }
  }

  /// Get restrictions for NPS park types
  List<String> _getRestrictionsForNpsType(LandOwnershipType type) {
    switch (type) {
      case LandOwnershipType.nationalPark:
        return [
          'No metal detecting or treasure hunting',
          'No collecting of natural or cultural artifacts',
          'Stay on marked trails',
          'No pets on most trails',
        ];
      case LandOwnershipType.nationalMonument:
        return [
          'No metal detecting or treasure hunting',
          'No collecting of artifacts',
          'Cultural and historical preservation required',
        ];
      default:
        return [
          'Follow National Park Service regulations',
          'No collecting without permits',
        ];
    }
  }

  /// Map PAD-US manager type to our ownership type enum
  LandOwnershipType _mapPadUsToOwnershipType(
      String? managerType, String managerName) {
    if (managerType == null) return LandOwnershipType.unknown;

    final type = managerType.toLowerCase();
    final name = managerName.toLowerCase();

    if (name.contains('national park')) return LandOwnershipType.nationalPark;
    if (name.contains('national forest'))
      return LandOwnershipType.nationalForest;
    if (name.contains('state park')) return LandOwnershipType.statePark;
    if (name.contains('state forest')) return LandOwnershipType.stateForest;
    if (name.contains('wildlife refuge'))
      return LandOwnershipType.nationalWildlifeRefuge;
    if (name.contains('wilderness')) return LandOwnershipType.wilderness;
    if (name.contains('blm') || name.contains('bureau of land'))
      return LandOwnershipType.bureauOfLandManagement;

    if (type.contains('federal')) return LandOwnershipType.nationalForest;
    if (type.contains('state')) return LandOwnershipType.statePark;
    if (type.contains('local')) return LandOwnershipType.countyLand;
    if (type.contains('private')) return LandOwnershipType.privateLand;
    if (type.contains('tribal')) return LandOwnershipType.tribalLand;

    return LandOwnershipType.unknown;
  }

  /// Map PAD-US access status to our access type enum
  AccessType _mapPadUsAccessType(String? access, String? gapStatus) {
    if (access == null) return AccessType.restrictedAccess;

    final accessLower = access.toLowerCase();

    if (accessLower.contains('open')) return AccessType.publicOpen;
    if (accessLower.contains('restricted')) return AccessType.permitRequired;
    if (accessLower.contains('closed')) return AccessType.noPublicAccess;
    if (accessLower.contains('fee')) return AccessType.feeRequired;

    // Use GAP status as fallback
    if (gapStatus != null) {
      final gapLower = gapStatus.toLowerCase();
      if (gapLower.contains('1') || gapLower.contains('2')) {
        return AccessType.feeRequired; // Protected areas often require fees
      }
    }

    return AccessType.restrictedAccess;
  }

  /// Get allowed uses based on ownership type
  List<LandUseType> _getAllowedUsesForPadUsType(
      LandOwnershipType type, AccessType access) {
    if (access == AccessType.noPublicAccess) return [];

    switch (type) {
      case LandOwnershipType.nationalPark:
        return [
          LandUseType.hiking,
          LandUseType.camping,
          LandUseType.photography,
          LandUseType.birdWatching,
        ];
      case LandOwnershipType.nationalForest:
        return [
          LandUseType.hiking,
          LandUseType.camping,
          LandUseType.hunting,
          LandUseType.fishing,
          LandUseType.ohvUse,
        ];
      case LandOwnershipType.statePark:
        return [
          LandUseType.hiking,
          LandUseType.camping,
          LandUseType.fishing,
          LandUseType.photography,
        ];
      case LandOwnershipType.wilderness:
        return [
          LandUseType.hiking,
          LandUseType.camping,
        ];
      case LandOwnershipType.nationalWildlifeRefuge:
        return [
          LandUseType.birdWatching,
          LandUseType.photography,
          LandUseType.fishing,
        ];
      default:
        return [LandUseType.hiking];
    }
  }

  /// Get restrictions based on ownership type
  List<String> _getRestrictionsForType(LandOwnershipType type) {
    switch (type) {
      case LandOwnershipType.nationalPark:
        return ['No pets on trails', 'Stay on marked trails', 'No collecting'];
      case LandOwnershipType.wilderness:
        return ['No motorized vehicles', 'No bicycles', 'Leave no trace'];
      case LandOwnershipType.nationalWildlifeRefuge:
        return ['Seasonal closures possible', 'Wildlife protection areas'];
      default:
        return [];
    }
  }

  /// Calculate bounds from GeoJSON geometry
  LandBounds? _calculateBoundsFromGeometry(Map<String, dynamic> geometry) {
    try {
      final coordinates = geometry['coordinates'];
      if (coordinates == null) return null;

      // Handle different geometry types
      List<List<double>> points = [];

      final geometryType = geometry['type'] as String?;
      switch (geometryType) {
        case 'Polygon':
          final rings = coordinates as List<dynamic>;
          if (rings.isNotEmpty) {
            final exteriorRing = rings[0] as List<dynamic>;
            points = exteriorRing.map((coord) {
              final c = coord as List<dynamic>;
              return [c[0] as double, c[1] as double];
            }).toList();
          }
          break;
        case 'MultiPolygon':
          final polygons = coordinates as List<dynamic>;
          for (final polygon in polygons) {
            final rings = polygon as List<dynamic>;
            if (rings.isNotEmpty) {
              final exteriorRing = rings[0] as List<dynamic>;
              points.addAll(exteriorRing.map((coord) {
                final c = coord as List<dynamic>;
                return [c[0] as double, c[1] as double];
              }));
            }
          }
          break;
        default:
          return null;
      }

      if (points.isEmpty) return null;

      double minLng = points[0][0];
      double maxLng = points[0][0];
      double minLat = points[0][1];
      double maxLat = points[0][1];

      for (final point in points) {
        minLng = math.min(minLng, point[0]);
        maxLng = math.max(maxLng, point[0]);
        minLat = math.min(minLat, point[1]);
        maxLat = math.max(maxLat, point[1]);
      }

      return LandBounds(
        north: maxLat,
        south: minLat,
        east: maxLng,
        west: minLng,
      );
    } catch (e) {
      debugPrint('Error calculating bounds from geometry: $e');
      return null;
    }
  }

  /// Verify imported PAD-US data
  Future<Map<String, dynamic>> verifyPadUsData() async {
    await _landService.initialize();

    final totalCount = await _landService.getLandOwnershipCount();
    final countByType = await _landService.getLandOwnershipCountByType();

    // Look for Wind Cave specifically by querying all data
    final allData = await _landService.getFilteredLandOwnership(
      const LandOwnershipFilter(),
      const LandBounds(
        north: 44.5,
        south: 43.0,
        east: -103.0,
        west: -104.5,
      ),
    );

    final windCave = allData
        .where((land) =>
            land.ownerName.toLowerCase().contains('wind cave') ||
            land.unitName?.toLowerCase().contains('wind cave') == true)
        .toList();

    return {
      'totalCount': totalCount,
      'countByType': countByType,
      'windCaveFound': windCave.isNotEmpty,
      'windCaveData': windCave
          .map<Map<String, dynamic>>((wc) => {
                'id': wc.id,
                'name': wc.ownerName,
                'type': wc.ownershipType.name,
                'agency': wc.agencyName,
                'dataSource': wc.dataSource,
              })
          .toList(),
      'sampleData': allData
          .take(5)
          .map((l) => {
                'id': l.id,
                'name': l.ownerName,
                'type': l.ownershipType.name,
                'agency': l.agencyName,
                'dataSource': l.dataSource,
              })
          .toList(),
    };
  }

  /// Verify that expected South Dakota landmarks were successfully imported
  Future<Map<String, dynamic>> _verifyExpectedLandmarks() async {
    const expectedLandmarks = [
      'Wind Cave',
      'Badlands',
      'Jewel Cave',
      'Mount Rushmore',
      'Black Hills',
    ];

    final allData = await _landService.getFilteredLandOwnership(
      const LandOwnershipFilter(),
      const LandBounds(
        north: 45.0,
        south: 42.5,
        east: -102.0,
        west: -105.0,
      ),
    );

    final foundLandmarks = <String, List<String>>{};

    for (final landmark in expectedLandmarks) {
      final matches = allData
          .where((land) =>
              land.ownerName.toLowerCase().contains(landmark.toLowerCase()) ||
              (land.unitName?.toLowerCase().contains(landmark.toLowerCase()) ??
                  false))
          .map((l) => l.ownerName)
          .toList();

      if (matches.isNotEmpty) {
        foundLandmarks[landmark] = matches;
      }
    }

    return {
      'expectedCount': expectedLandmarks.length,
      'foundCount': foundLandmarks.length,
      'foundLandmarks': foundLandmarks,
      'missingLandmarks': expectedLandmarks
          .where((l) => !foundLandmarks.containsKey(l))
          .toList(),
      'success': foundLandmarks.length >=
          3, // Consider success if we find at least 3/5
    };
  }
}
