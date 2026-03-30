import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/services/land_ownership_service.dart';
import 'package:obsession_tracker/core/services/pad_us_data_service.dart';

/// Diagnostic service to examine and verify PAD-US data quality
class PadUsDiagnosticService {
  factory PadUsDiagnosticService() => _instance;
  PadUsDiagnosticService._internal();
  static final PadUsDiagnosticService _instance =
      PadUsDiagnosticService._internal();

  final LandOwnershipService _landService = LandOwnershipService.instance;

  /// Diagnostic download that logs everything we receive from PAD-US
  Future<Map<String, dynamic>> diagnosticDownloadAndAnalyze() async {
    await _landService.initialize();

    debugPrint('🔍 Starting diagnostic PAD-US download...');

    // Query PAD-US API directly with detailed logging
    const baseUrl =
        'https://services.arcgis.com/v01gqwM5QqNysAAi/arcgis/rest/services/Manager_Name/FeatureServer/0/query';

    final queryParams = {
      'where': "State_Nm = 'South Dakota'",
      'geometry': '-104.5,43.0,-103.0,44.5',
      'geometryType': 'esriGeometryEnvelope',
      'spatialRel': 'esriSpatialRelIntersects',
      'outFields': '*',
      'returnGeometry': 'true',
      'f': 'geojson',
    };

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
    debugPrint('🌐 Querying: ${uri.toString()}');

    try {
      final response = await http.get(uri);
      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📦 Response size: ${response.body.length} bytes');

      if (response.statusCode != 200) {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}',
        };
      }

      final geoJson = json.decode(response.body) as Map<String, dynamic>;
      debugPrint('📋 Response type: ${geoJson['type']}');

      if (geoJson['type'] != 'FeatureCollection') {
        return {
          'success': false,
          'error': 'Invalid GeoJSON type: ${geoJson['type']}',
          'rawResponse': response.body.substring(0, 1000), // First 1000 chars
        };
      }

      final features = geoJson['features'] as List<dynamic>;
      debugPrint('🏞️  Features received: ${features.length}');

      // Analyze the features we received
      return await _analyzeFeatures(
          features.map((f) => f as Map<String, dynamic>).toList());
    } catch (e, stackTrace) {
      debugPrint('❌ Error during diagnostic download: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
      };
    }
  }

  /// Analyze the features we received from PAD-US
  Future<Map<String, dynamic>> _analyzeFeatures(
      List<Map<String, dynamic>> features) async {
    debugPrint('🔍 Analyzing ${features.length} PAD-US features...');

    // Clear existing data
    await _landService.clearAllLandOwnership();

    // Categorize features by type
    final featureAnalysis = <String, List<Map<String, dynamic>>>{};
    final expectedLandmarks = <String, Map<String, dynamic>?>{
      'Wind Cave National Park': null,
      'Badlands National Park': null,
      'Jewel Cave National Monument': null,
      'Custer State Park': null,
      'Black Hills National Forest': null,
    };

    for (final feature in features) {
      final properties = feature['properties'] as Map<String, dynamic>?;
      if (properties == null) continue;

      final unitName = properties['Unit_Nm'] as String?;
      final managerName = properties['Mang_Name'] as String?;
      final managerType = properties['Mang_Type'] as String?;
      final geometryType =
          (feature['geometry'] as Map<String, dynamic>?)?['type'] as String?;

      // Log every feature we receive
      debugPrint('📍 Feature: $unitName');
      debugPrint('   Manager: $managerName');
      debugPrint('   Type: $managerType');
      debugPrint('   Geometry: $geometryType');
      debugPrint('   Properties: ${properties.keys.join(', ')}');

      // Categorize by manager type
      final category = managerType ?? 'Unknown';
      featureAnalysis.putIfAbsent(category, () => []).add(feature);

      // Check for expected landmarks
      if (unitName != null) {
        for (final landmark in expectedLandmarks.keys) {
          if (unitName.toLowerCase().contains(landmark.toLowerCase()) ||
              (landmark.contains('Cave') &&
                  unitName.toLowerCase().contains('cave')) ||
              (landmark.contains('Badlands') &&
                  unitName.toLowerCase().contains('badlands')) ||
              (landmark.contains('Black Hills') &&
                  unitName.toLowerCase().contains('black hills')) ||
              (landmark.contains('Custer') &&
                  unitName.toLowerCase().contains('custer'))) {
            expectedLandmarks[landmark] = feature;
            debugPrint('✅ Found expected landmark: $landmark -> $unitName');
          }
        }
      }
    }

    debugPrint('\n📊 Feature Analysis Summary:');
    featureAnalysis.forEach((type, typeFeatures) {
      debugPrint('  $type: ${typeFeatures.length} features');
      for (final feature in typeFeatures.take(3)) {
        final unitName =
            (feature['properties'] as Map<String, dynamic>?)?['Unit_Nm'];
        debugPrint('    - $unitName');
      }
      if (typeFeatures.length > 3) {
        debugPrint('    ... and ${typeFeatures.length - 3} more');
      }
    });

    debugPrint('\n🎯 Expected Landmarks Check:');
    expectedLandmarks.forEach((landmark, feature) {
      if (feature != null) {
        final unitName =
            (feature['properties'] as Map<String, dynamic>?)?['Unit_Nm'];
        debugPrint('  ✅ $landmark: Found as "$unitName"');
      } else {
        debugPrint('  ❌ $landmark: NOT FOUND');
      }
    });

    // Test parsing and save a few key features
    final padUsService = PadUsDataService();
    var parsedCount = 0;
    final parsedLandmarks = <String, LandOwnership>{};

    for (final entry in expectedLandmarks.entries) {
      if (entry.value != null) {
        try {
          // Use reflection to access private method - for diagnostic purposes
          final landOwnership =
              await _convertFeatureForDiagnostic(entry.value!, padUsService);
          if (landOwnership != null) {
            await _landService.saveLandOwnership(landOwnership);
            parsedLandmarks[entry.key] = landOwnership;
            parsedCount++;

            debugPrint('✅ Parsed ${entry.key}:');
            debugPrint('   Type: ${landOwnership.ownershipType.name}');
            debugPrint('   Bounds: ${landOwnership.bounds}');
            debugPrint(
                '   Centroid: ${landOwnership.centroid.latitude}, ${landOwnership.centroid.longitude}');
            debugPrint('   Access: ${landOwnership.accessType.name}');
          }
        } catch (e) {
          debugPrint('❌ Failed to parse ${entry.key}: $e');
        }
      }
    }

    // Test filtering
    final filteringResults = await _testFiltering();

    return {
      'success': true,
      'totalFeatures': features.length,
      'featuresByType': featureAnalysis.map((k, v) => MapEntry(k, v.length)),
      'expectedLandmarks':
          expectedLandmarks.map((k, v) => MapEntry(k, v != null)),
      'foundLandmarkNames': expectedLandmarks.entries
          .where((e) => e.value != null)
          .map((e) => {
                'expected': e.key,
                'actual': (e.value!['properties']
                    as Map<String, dynamic>?)?['Unit_Nm']
              })
          .toList(),
      'parsedCount': parsedCount,
      'parsedLandmarks': parsedLandmarks.map((k, v) => MapEntry(k, {
            'type': v.ownershipType.name,
            'bounds': {
              'north': v.bounds.north,
              'south': v.bounds.south,
              'east': v.bounds.east,
              'west': v.bounds.west,
            },
            'centroid': {
              'lat': v.centroid.latitude,
              'lng': v.centroid.longitude,
            }
          })),
      'filteringResults': filteringResults,
    };
  }

  /// Test filtering with the parsed data
  Future<Map<String, dynamic>> _testFiltering() async {
    const bounds = LandBounds(
      north: 44.5,
      south: 43.0,
      east: -103.0,
      west: -104.5,
    );

    // Test different filters
    final allData = await _landService.getFilteredLandOwnership(
      const LandOwnershipFilter(),
      bounds,
    );

    final nationalParks = await _landService.getFilteredLandOwnership(
      const LandOwnershipFilter(enabledTypes: {LandOwnershipType.nationalPark}),
      bounds,
    );

    final nationalForests = await _landService.getFilteredLandOwnership(
      const LandOwnershipFilter(
          enabledTypes: {LandOwnershipType.nationalForest}),
      bounds,
    );

    final stateParks = await _landService.getFilteredLandOwnership(
      const LandOwnershipFilter(enabledTypes: {LandOwnershipType.statePark}),
      bounds,
    );

    final federalLands = await _landService.getFilteredLandOwnership(
      const LandOwnershipFilter(showFederalLandOnly: true),
      bounds,
    );

    debugPrint('\n🔍 Filtering Test Results:');
    debugPrint('  All data: ${allData.length} records');
    debugPrint('  National Parks: ${nationalParks.length} records');
    debugPrint('  National Forests: ${nationalForests.length} records');
    debugPrint('  State Parks: ${stateParks.length} records');
    debugPrint('  Federal Lands: ${federalLands.length} records');

    for (final park in nationalParks) {
      debugPrint(
          '    Park: ${park.ownerName} at ${park.centroid.latitude}, ${park.centroid.longitude}');
    }

    return {
      'allData': allData.length,
      'nationalParks': nationalParks.length,
      'nationalForests': nationalForests.length,
      'stateParks': stateParks.length,
      'federalLands': federalLands.length,
      'parkDetails': nationalParks
          .map((p) => {
                'name': p.ownerName,
                'type': p.ownershipType.name,
                'lat': p.centroid.latitude,
                'lng': p.centroid.longitude,
                'bounds': {
                  'north': p.bounds.north,
                  'south': p.bounds.south,
                  'east': p.bounds.east,
                  'west': p.bounds.west,
                }
              })
          .toList(),
    };
  }

  /// Convert a PAD-US feature for diagnostic purposes
  /// This replicates the private method logic for testing
  Future<LandOwnership?> _convertFeatureForDiagnostic(
    Map<String, dynamic> feature,
    PadUsDataService padUsService,
  ) async {
    try {
      final properties = feature['properties'] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>?;

      final unitName = properties['Unit_Nm'] as String?;
      final managerName = properties['Mang_Name'] as String?;
      final managerType = properties['Mang_Type'] as String?;
      final localName = properties['Loc_Nm'] as String?;
      final stateName = properties['State_Nm'] as String?;
      final gapStatus = properties['GAP_Sts'] as String?;
      final access = properties['Access_Sts'] as String?;

      if (unitName == null || managerName == null) return null;

      // Map ownership type
      final LandOwnershipType ownershipType =
          _mapOwnershipType(managerType, managerName, unitName);

      // Map access type
      final AccessType accessType = _mapAccessType(access, gapStatus);

      // Calculate bounds
      LandBounds bounds = const LandBounds(
          north: 43.6, south: 43.5, east: -103.4, west: -103.5);
      if (geometry != null) {
        final calculatedBounds = _calculateBounds(geometry);
        if (calculatedBounds != null) {
          bounds = calculatedBounds;
        }
      }

      final allowedUses = _getAllowedUses(ownershipType, accessType);

      final now = DateTime.now();
      return LandOwnership(
        id: 'diagnostic_${unitName.replaceAll(' ', '_').toLowerCase()}_${now.millisecondsSinceEpoch}',
        ownershipType: ownershipType,
        ownerName: unitName,
        agencyName: managerName,
        unitName: localName ?? unitName,
        designation: gapStatus,
        accessType: accessType,
        allowedUses: allowedUses,
        fees: accessType == AccessType.feeRequired ? 'Varies by area' : null,
        bounds: bounds,
        centroid: bounds.center,
        properties: {
          'padus_manager_type': managerType ?? '',
          'padus_state': stateName ?? '',
          'padus_gap_status': gapStatus ?? '',
          'padus_access_status': access ?? '',
        },
        dataSource: 'PAD-US_v3.0_DIAGNOSTIC',
        dataSourceDate: now,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e) {
      debugPrint('Error converting feature: $e');
      return null;
    }
  }

  LandOwnershipType _mapOwnershipType(
      String? managerType, String managerName, String unitName) {
    final name = managerName.toLowerCase();
    final unit = unitName.toLowerCase();

    if (unit.contains('national park') || name.contains('park service'))
      return LandOwnershipType.nationalPark;
    if (unit.contains('national monument'))
      return LandOwnershipType.nationalMonument;
    if (unit.contains('national forest') || name.contains('forest service'))
      return LandOwnershipType.nationalForest;
    if (unit.contains('state park') || name.contains('state park'))
      return LandOwnershipType.statePark;
    if (unit.contains('state forest')) return LandOwnershipType.stateForest;
    if (name.contains('wildlife refuge'))
      return LandOwnershipType.nationalWildlifeRefuge;
    if (unit.contains('wilderness')) return LandOwnershipType.wilderness;
    if (name.contains('blm') || name.contains('bureau of land'))
      return LandOwnershipType.bureauOfLandManagement;
    if (managerType?.toLowerCase() == 'private')
      return LandOwnershipType.privateLand;
    if (name.contains('tribal')) return LandOwnershipType.tribalLand;

    return LandOwnershipType.unknown;
  }

  AccessType _mapAccessType(String? access, String? gapStatus) {
    if (access == null) return AccessType.restrictedAccess;

    final accessLower = access.toLowerCase();
    if (accessLower.contains('open') && accessLower.contains('fee'))
      return AccessType.feeRequired;
    if (accessLower.contains('open')) return AccessType.publicOpen;
    if (accessLower.contains('restricted')) return AccessType.permitRequired;
    if (accessLower.contains('closed')) return AccessType.noPublicAccess;

    return AccessType.restrictedAccess;
  }

  LandBounds? _calculateBounds(Map<String, dynamic> geometry) {
    try {
      final coordinates = geometry['coordinates'];
      if (coordinates == null) return null;

      double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

      void processCoords(Object? coordList) {
        if (coordList is List) {
          for (final coord in coordList) {
            if (coord is List &&
                coord.length >= 2 &&
                coord[0] is num &&
                coord[1] is num) {
              final lng = (coord[0] as num).toDouble();
              final lat = (coord[1] as num).toDouble();
              minLat = minLat < lat ? minLat : lat;
              maxLat = maxLat > lat ? maxLat : lat;
              minLng = minLng < lng ? minLng : lng;
              maxLng = maxLng > lng ? maxLng : lng;
            } else if (coord is List) {
              processCoords(coord);
            }
          }
        }
      }

      processCoords(coordinates);

      if (minLat < 90 && maxLat > -90 && minLng < 180 && maxLng > -180) {
        return LandBounds(
            north: maxLat, south: minLat, east: maxLng, west: minLng);
      }

      return null;
    } catch (e) {
      debugPrint('Error calculating bounds: $e');
      return null;
    }
  }

  List<LandUseType> _getAllowedUses(LandOwnershipType type, AccessType access) {
    if (access == AccessType.noPublicAccess) return [];

    switch (type) {
      case LandOwnershipType.nationalPark:
      case LandOwnershipType.nationalMonument:
        return [
          LandUseType.hiking,
          LandUseType.camping,
          LandUseType.photography,
          LandUseType.birdWatching
        ];
      case LandOwnershipType.nationalForest:
        return [
          LandUseType.hiking,
          LandUseType.camping,
          LandUseType.hunting,
          LandUseType.fishing,
          LandUseType.ohvUse
        ];
      case LandOwnershipType.statePark:
        return [
          LandUseType.hiking,
          LandUseType.camping,
          LandUseType.fishing,
          LandUseType.photography
        ];
      case LandOwnershipType.wilderness:
        return [LandUseType.hiking, LandUseType.camping];
      case LandOwnershipType.nationalWildlifeRefuge:
        return [
          LandUseType.birdWatching,
          LandUseType.photography,
          LandUseType.fishing
        ];
      default:
        return [LandUseType.hiking];
    }
  }
}
