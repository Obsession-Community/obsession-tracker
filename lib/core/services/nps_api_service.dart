import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:path_provider/path_provider.dart';

/// Cache response class
class CachedResponse {
  final List<Map<String, dynamic>> data;
  final DateTime timestamp;

  CachedResponse({required this.data, required this.timestamp});
}

/// Service to integrate with National Park Service API
class NpsApiService {
  static final NpsApiService _instance = NpsApiService._internal();
  factory NpsApiService() => _instance;
  NpsApiService._internal();

  // NPS API endpoint and key
  static const String _baseUrl = 'https://developer.nps.gov/api/v1/parks';
  // Provide via --dart-define=NPS_API_KEY=your_key
  // Get your free key at: https://developer.nps.gov/signup/
  static const String _apiKey = String.fromEnvironment('NPS_API_KEY', defaultValue: '');

  // Cache settings
  static const Duration _cacheDuration = Duration(hours: 24);
  final Map<String, CachedResponse> _memoryCache = {};

  /// Get cache file for a state
  Future<File> _getCacheFile(String stateCode) async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${directory.path}/nps_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return File('${cacheDir.path}/nps_${stateCode.toUpperCase()}.json');
  }

  /// Create cached South Dakota data for testing (bypasses rate limits)
  Future<void> createSouthDakotaTestCache() async {
    final testData = [
      {
        'name': 'Badlands National Park',
        'parkCode': 'badl',
        'designation': 'National Park',
        'description':
            'The rugged beauty of the Badlands draws visitors from around the world.',
        'latLong': '43.75, -102.5',
        'url': 'https://www.nps.gov/badl/index.htm',
      },
      {
        'name': 'Wind Cave National Park',
        'parkCode': 'wica',
        'designation': 'National Park',
        'description':
            'Wind Cave is one of the longest and most complex caves in the world.',
        'latLong': '43.57, -103.48',
        'url': 'https://www.nps.gov/wica/index.htm',
      },
      {
        'name': 'Jewel Cave National Monument',
        'parkCode': 'jeca',
        'designation': 'National Monument',
        'description':
            'With over 200 miles of surveyed passageways, Jewel Cave is the third longest cave in the world.',
        'latLong': '43.73, -103.83',
        'url': 'https://www.nps.gov/jeca/index.htm',
      },
      {
        'name': 'Mount Rushmore National Memorial',
        'parkCode': 'moru',
        'designation': 'National Memorial',
        'description':
            'Majestic figures of Washington, Jefferson, Roosevelt and Lincoln, surrounded by the beauty of the Black Hills.',
        'latLong': '43.88, -103.45',
        'url': 'https://www.nps.gov/moru/index.htm',
      },
    ];

    await createTestCache('SD', testData);
  }

  /// Manually create cache file with known good data (for testing)
  Future<void> createTestCache(
      String stateCode, List<Map<String, dynamic>> testData) async {
    try {
      final cacheFile = await _getCacheFile(stateCode);
      final cacheData = {
        'timestamp': DateTime.now().toIso8601String(),
        'stateCode': stateCode.toUpperCase(),
        'data': testData,
      };
      await cacheFile.writeAsString(jsonEncode(cacheData));
      debugPrint(
          '🧪 Created test cache for $stateCode with ${testData.length} parks');
    } catch (e) {
      debugPrint('❌ Failed to create test cache: $e');
    }
  }

  /// Get all parks for a specific state (with caching)
  Future<List<Map<String, dynamic>>> getParksForState(String stateCode) async {
    final upperStateCode = stateCode.toUpperCase();

    // Check memory cache first
    if (_memoryCache.containsKey(upperStateCode)) {
      final cached = _memoryCache[upperStateCode]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheDuration) {
        debugPrint('📦 Using memory cache for $upperStateCode parks');
        return cached.data;
      }
    }

    // Check file cache
    try {
      final cacheFile = await _getCacheFile(upperStateCode);
      if (await cacheFile.exists()) {
        final cacheContent = await cacheFile.readAsString();
        final cacheData = jsonDecode(cacheContent) as Map<String, dynamic>;
        final cachedTime = DateTime.parse(cacheData['timestamp'] as String);

        if (DateTime.now().difference(cachedTime) < _cacheDuration) {
          final parks =
              (cacheData['data'] as List).cast<Map<String, dynamic>>();
          final age = DateTime.now().difference(cachedTime);
          debugPrint(
              '💾 Using file cache for $upperStateCode parks (${age.inMinutes} minutes old)');

          // Update memory cache
          _memoryCache[upperStateCode] = CachedResponse(
            data: parks,
            timestamp: cachedTime,
          );

          return parks;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Cache read error: $e');
    }
    final queryParams = {
      'stateCode': upperStateCode,
      'api_key': _apiKey,
      'limit': '50',
    };

    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

    debugPrint('🏞️ Querying NPS API: $uri');

    try {
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint(
            '❌ NPS API query failed: ${response.statusCode} - ${response.body}');
        return []; // Return empty list on failure, don't throw
      }

      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      final parks = jsonData['data'] as List<dynamic>?;

      if (parks == null) {
        debugPrint('❌ No parks data in NPS API response');
        return [];
      }

      debugPrint('✅ Successfully retrieved ${parks.length} parks from NPS API');
      final parksList = parks.map((p) => p as Map<String, dynamic>).toList();

      // Save to cache
      try {
        final cacheFile = await _getCacheFile(upperStateCode);
        final cacheData = {
          'timestamp': DateTime.now().toIso8601String(),
          'stateCode': upperStateCode,
          'data': parksList,
        };
        await cacheFile.writeAsString(jsonEncode(cacheData));
        debugPrint('💾 Saved $upperStateCode parks to cache');

        // Update memory cache
        _memoryCache[upperStateCode] = CachedResponse(
          data: parksList,
          timestamp: DateTime.now(),
        );
      } catch (e) {
        debugPrint('⚠️ Failed to save cache: $e');
      }

      return parksList;
    } catch (e) {
      debugPrint('❌ Error querying NPS API: $e');
      return []; // Return empty list on error, don't fail the entire download
    }
  }

  /// Convert NPS park data to LandOwnership objects
  List<LandOwnership> convertParksToLandOwnership(
      List<Map<String, dynamic>> parks, String stateCode) {
    final landOwnerships = <LandOwnership>[];

    for (final parkData in parks) {
      final landOwnership = _convertNpsToLandOwnership(parkData, stateCode);
      if (landOwnership != null) {
        landOwnerships.add(landOwnership);
      }
    }

    return landOwnerships;
  }

  /// Convert NPS park data to our LandOwnership model
  LandOwnership? _convertNpsToLandOwnership(
      Map<String, dynamic> parkData, String stateCode) {
    try {
      final parkName = parkData['name'] as String?;
      final parkCode = parkData['parkCode'] as String?;
      final designation = parkData['designation'] as String?;
      final description = parkData['description'] as String?;
      final url = parkData['url'] as String?;
      final latLong = parkData['latLong'] as String?;

      if (parkName == null || parkCode == null) {
        debugPrint('⚠️ Skipping NPS park with missing name/code');
        return null;
      }

      debugPrint('🏞️ Processing NPS park: $parkName ($parkCode)');

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
              debugPrint('📍 Parsed coordinates: $lat, $lng');

              // Create reasonable bounds around the point (NPS API only provides points)
              const offset = 0.02; // ~2km buffer for park boundaries
              bounds = LandBounds(
                north: lat + offset,
                south: lat - offset,
                east: lng + offset,
                west: lng - offset,
              );
            } else {
              debugPrint('⚠️ Failed to parse lat/lng: $latLong');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing NPS coordinates: $e');
        }
      } else {
        debugPrint('⚠️ No coordinates provided for $parkName');
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
        dataSource:
            'PAD-US_${stateCode}_data', // Use standard format for state tracking
        dataSourceDate: now,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error converting NPS park: $e');
      debugPrint('Park data: $parkData');
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

  /// Get South Dakota parks with expected landmarks
  Future<List<LandOwnership>> getSouthDakotaParks() async {
    debugPrint('🔍 Getting South Dakota parks from NPS API...');

    final parksData = await getParksForState('SD');
    final landOwnerships = convertParksToLandOwnership(parksData, 'SD');

    // Log what we found
    debugPrint(
        '📊 NPS API returned ${landOwnerships.length} South Dakota parks');
    for (final park in landOwnerships) {
      debugPrint('  - ${park.ownerName} (${park.designation})');
    }

    // Verify expected landmarks
    const expectedLandmarks = [
      'Wind Cave',
      'Badlands',
      'Jewel Cave',
      'Mount Rushmore'
    ];
    final foundLandmarks = <String>[];

    for (final landmark in expectedLandmarks) {
      final found = landOwnerships.any((park) =>
          park.ownerName.toLowerCase().contains(landmark.toLowerCase()));
      if (found) {
        foundLandmarks.add(landmark);
      }
    }

    debugPrint('✅ Expected landmarks found: $foundLandmarks');
    debugPrint(
        '❌ Missing landmarks: ${expectedLandmarks.where((l) => !foundLandmarks.contains(l)).toList()}');

    return landOwnerships;
  }
}
