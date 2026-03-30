import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/services/land_ownership_service.dart';

/// Debug service to analyze the mysterious 77 South Dakota records
class DebugLandDataService {
  final LandOwnershipService _landService = LandOwnershipService.instance;

  /// Comprehensive analysis of current land ownership data
  Future<Map<String, dynamic>> analyzeLandOwnershipData() async {
    await _landService.initialize();

    debugPrint('🔍 Starting comprehensive land ownership data analysis...');

    // Get basic counts
    final totalCount = await _landService.getLandOwnershipCount();
    final countByType = await _landService.getLandOwnershipCountByType();

    debugPrint('📊 Total records: $totalCount');
    debugPrint('📊 Count by type: $countByType');

    // Get all data to analyze
    const southDakotaBounds = LandBounds(
      north: 45.9454, // SD northern border
      south: 42.4795, // SD southern border
      east: -96.4365, // SD eastern border
      west: -104.0572, // SD western border
    );

    final allData = await _landService.getFilteredLandOwnership(
      const LandOwnershipFilter(),
      southDakotaBounds,
    );

    debugPrint('🗺️ Records within SD bounds: ${allData.length}');

    // Analyze what we actually have
    final analysis = _analyzeRecords(allData);

    // Look for expected landmarks specifically
    final landmarkAnalysis = _analyzeLandmarks(allData);

    // Check coordinate validity
    final coordinateAnalysis = _analyzeCoordinates(allData);

    // Check data sources
    final sourceAnalysis = _analyzeDataSources(allData);

    final result = {
      'totalCount': totalCount,
      'countByType': countByType.map((k, v) => MapEntry(k.name, v)),
      'recordsInSDBounds': allData.length,
      'recordAnalysis': analysis,
      'landmarkAnalysis': landmarkAnalysis,
      'coordinateAnalysis': coordinateAnalysis,
      'sourceAnalysis': sourceAnalysis,
      'sampleRecords': _getSampleRecords(allData),
    };

    debugPrint('✅ Analysis complete. Key findings:');
    debugPrint(
        '   - Expected landmarks found: ${landmarkAnalysis['expectedLandmarksFound']}');
    debugPrint(
        '   - Valid SD coordinates: ${coordinateAnalysis['validSDCoordinates']}');
    debugPrint('   - Primary data sources: ${sourceAnalysis['dataSources']}');

    return result;
  }

  /// Analyze the content and patterns in records
  Map<String, dynamic> _analyzeRecords(List<LandOwnership> records) {
    if (records.isEmpty) return {'error': 'No records to analyze'};

    final ownerNames = <String, int>{};
    final agencyNames = <String, int>{};
    final designations = <String, int>{};
    final accessTypes = <String, int>{};

    for (final record in records) {
      // Count owner names
      final ownerName = record.ownerName.toLowerCase();
      ownerNames[ownerName] = (ownerNames[ownerName] ?? 0) + 1;

      // Count agency names
      if (record.agencyName != null) {
        final agencyName = record.agencyName!.toLowerCase();
        agencyNames[agencyName] = (agencyNames[agencyName] ?? 0) + 1;
      }

      // Count designations
      if (record.designation != null) {
        final designation = record.designation!.toLowerCase();
        designations[designation] = (designations[designation] ?? 0) + 1;
      }

      // Count access types
      final accessType = record.accessType.name;
      accessTypes[accessType] = (accessTypes[accessType] ?? 0) + 1;
    }

    return {
      'topOwnerNames': _getTopEntries(ownerNames, 10),
      'topAgencyNames': _getTopEntries(agencyNames, 10),
      'topDesignations': _getTopEntries(designations, 10),
      'accessTypeDistribution': accessTypes,
      'averageArea': _calculateAverageArea(records),
    };
  }

  /// Look specifically for expected South Dakota landmarks
  Map<String, dynamic> _analyzeLandmarks(List<LandOwnership> records) {
    const expectedLandmarks = [
      'wind cave',
      'badlands',
      'jewel cave',
      'mount rushmore',
      'black hills',
      'custer state park',
      'crazy horse',
    ];

    final foundLandmarks = <String, List<String>>{};
    final allMatches = <String>[];

    for (final landmark in expectedLandmarks) {
      final matches = records
          .where((record) {
            final searchText =
                '${record.ownerName} ${record.agencyName ?? ''} ${record.unitName ?? ''}'
                    .toLowerCase();
            return searchText.contains(landmark);
          })
          .map((r) => r.ownerName)
          .toList();

      if (matches.isNotEmpty) {
        foundLandmarks[landmark] = matches;
        allMatches.addAll(matches);
      }
    }

    return {
      'expectedLandmarksFound': foundLandmarks.length,
      'foundLandmarks': foundLandmarks,
      'allLandmarkMatches': allMatches,
      'totalExpected': expectedLandmarks.length,
    };
  }

  /// Analyze coordinate validity for South Dakota
  Map<String, dynamic> _analyzeCoordinates(List<LandOwnership> records) {
    int validSDCoordinates = 0;
    int invalidCoordinates = 0;
    final coordinateDistribution = <String, int>{};

    // South Dakota approximate bounds
    const sdNorth = 45.95;
    const sdSouth = 42.48;
    const sdEast = -96.44;
    const sdWest = -104.06;

    for (final record in records) {
      final lat = record.centroid.latitude;
      final lng = record.centroid.longitude;

      // Check if coordinates are within South Dakota
      if (lat >= sdSouth && lat <= sdNorth && lng >= sdWest && lng <= sdEast) {
        validSDCoordinates++;

        // Categorize by region
        if (lng < -103.0) {
          coordinateDistribution['Western SD (Black Hills)'] =
              (coordinateDistribution['Western SD (Black Hills)'] ?? 0) + 1;
        } else if (lng > -100.0) {
          coordinateDistribution['Eastern SD'] =
              (coordinateDistribution['Eastern SD'] ?? 0) + 1;
        } else {
          coordinateDistribution['Central SD'] =
              (coordinateDistribution['Central SD'] ?? 0) + 1;
        }
      } else {
        invalidCoordinates++;

        // Categorize invalid coordinates
        if (lat < 30 || lat > 50) {
          coordinateDistribution['Invalid Latitude'] =
              (coordinateDistribution['Invalid Latitude'] ?? 0) + 1;
        } else if (lng > -90 || lng < -125) {
          coordinateDistribution['Invalid Longitude'] =
              (coordinateDistribution['Invalid Longitude'] ?? 0) + 1;
        } else {
          coordinateDistribution['Outside SD'] =
              (coordinateDistribution['Outside SD'] ?? 0) + 1;
        }
      }
    }

    return {
      'validSDCoordinates': validSDCoordinates,
      'invalidCoordinates': invalidCoordinates,
      'coordinateDistribution': coordinateDistribution,
      'percentageValid': records.isNotEmpty
          ? (validSDCoordinates / records.length * 100).round()
          : 0,
    };
  }

  /// Analyze data sources
  Map<String, dynamic> _analyzeDataSources(List<LandOwnership> records) {
    final dataSources = <String, int>{};
    final sourceDetails = <String, List<String>>{};

    for (final record in records) {
      final source = record.dataSource;
      dataSources[source] = (dataSources[source] ?? 0) + 1;

      // Store sample record names for each source
      sourceDetails[source] ??= [];
      if ((sourceDetails[source]?.length ?? 0) < 5) {
        sourceDetails[source]?.add(record.ownerName);
      }
    }

    return {
      'dataSources': dataSources,
      'sourceDetails': sourceDetails,
      'primarySource':
          dataSources.entries.reduce((a, b) => a.value > b.value ? a : b).key,
    };
  }

  /// Get sample records for inspection
  List<Map<String, dynamic>> _getSampleRecords(List<LandOwnership> records) {
    final samples = records
        .take(10)
        .map((record) => {
              'id': record.id,
              'ownerName': record.ownerName,
              'agencyName': record.agencyName,
              'unitName': record.unitName,
              'designation': record.designation,
              'ownershipType': record.ownershipType.name,
              'accessType': record.accessType.name,
              'dataSource': record.dataSource,
              'coordinates':
                  '${record.centroid.latitude}, ${record.centroid.longitude}',
              'bounds':
                  '${record.bounds.north}, ${record.bounds.south}, ${record.bounds.east}, ${record.bounds.west}',
            })
        .toList();

    return samples;
  }

  /// Helper to get top entries from a map
  Map<String, int> _getTopEntries(Map<String, int> source, int limit) {
    final entries = source.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final result = <String, int>{};
    for (int i = 0; i < math.min(limit, entries.length); i++) {
      result[entries[i].key] = entries[i].value;
    }

    return result;
  }

  /// Calculate average area from bounds
  double _calculateAverageArea(List<LandOwnership> records) {
    if (records.isEmpty) return 0.0;

    double totalArea = 0.0;
    for (final record in records) {
      final bounds = record.bounds;
      // Rough area calculation in square degrees
      final area = (bounds.north - bounds.south).abs() *
          (bounds.east - bounds.west).abs();
      totalArea += area;
    }

    return totalArea / records.length;
  }

  /// Export detailed analysis to console
  Future<void> printDetailedAnalysis() async {
    final analysis = await analyzeLandOwnershipData();

    debugPrint('\n${'=' * 80}');
    debugPrint('🔍 DETAILED LAND OWNERSHIP DATA ANALYSIS');
    debugPrint('=' * 80);

    debugPrint('\n📊 BASIC STATISTICS:');
    debugPrint('Total Records: ${analysis['totalCount']}');
    debugPrint('Records in SD Bounds: ${analysis['recordsInSDBounds']}');

    final countByType = analysis['countByType'] as Map<String, dynamic>;
    debugPrint('\n📊 COUNT BY OWNERSHIP TYPE:');
    countByType.forEach((type, count) {
      debugPrint('  $type: $count');
    });

    final coordinateAnalysis =
        analysis['coordinateAnalysis'] as Map<String, dynamic>;
    debugPrint('\n🗺️ COORDINATE ANALYSIS:');
    debugPrint(
        'Valid SD Coordinates: ${coordinateAnalysis['validSDCoordinates']}');
    debugPrint(
        'Invalid Coordinates: ${coordinateAnalysis['invalidCoordinates']}');
    debugPrint('Percentage Valid: ${coordinateAnalysis['percentageValid']}%');

    final distribution =
        coordinateAnalysis['coordinateDistribution'] as Map<String, dynamic>;
    debugPrint('\n📍 COORDINATE DISTRIBUTION:');
    distribution.forEach((region, count) {
      debugPrint('  $region: $count');
    });

    final landmarkAnalysis =
        analysis['landmarkAnalysis'] as Map<String, dynamic>;
    debugPrint('\n🏞️ LANDMARK ANALYSIS:');
    debugPrint(
        'Expected Landmarks Found: ${landmarkAnalysis['expectedLandmarksFound']}/${landmarkAnalysis['totalExpected']}');

    final foundLandmarks =
        landmarkAnalysis['foundLandmarks'] as Map<String, dynamic>;
    if (foundLandmarks.isNotEmpty) {
      debugPrint('\n✅ FOUND LANDMARKS:');
      foundLandmarks.forEach((landmark, matches) {
        debugPrint('  $landmark: ${(matches as List).join(', ')}');
      });
    } else {
      debugPrint('\n❌ NO EXPECTED LANDMARKS FOUND');
    }

    final sourceAnalysis = analysis['sourceAnalysis'] as Map<String, dynamic>;
    debugPrint('\n📡 DATA SOURCE ANALYSIS:');
    debugPrint('Primary Source: ${sourceAnalysis['primarySource']}');

    final dataSources = sourceAnalysis['dataSources'] as Map<String, dynamic>;
    debugPrint('\n📡 ALL DATA SOURCES:');
    dataSources.forEach((source, count) {
      debugPrint('  $source: $count records');
    });

    final recordAnalysis = analysis['recordAnalysis'] as Map<String, dynamic>;
    final topOwners = recordAnalysis['topOwnerNames'] as Map<String, dynamic>;
    debugPrint('\n🏢 TOP OWNER NAMES:');
    topOwners.forEach((owner, count) {
      debugPrint('  $owner: $count');
    });

    final sampleRecords = analysis['sampleRecords'] as List<dynamic>;
    debugPrint('\n📋 SAMPLE RECORDS:');
    for (int i = 0; i < math.min(5, sampleRecords.length); i++) {
      final record = sampleRecords[i] as Map<String, dynamic>;
      debugPrint('  ${i + 1}. ${record['ownerName']}');
      debugPrint('     Type: ${record['ownershipType']}');
      debugPrint('     Agency: ${record['agencyName']}');
      debugPrint('     Source: ${record['dataSource']}');
      debugPrint('     Location: ${record['coordinates']}');
      debugPrint('');
    }

    debugPrint('=' * 80);
    debugPrint('🔍 ANALYSIS COMPLETE');
    debugPrint('=' * 80);
  }
}
