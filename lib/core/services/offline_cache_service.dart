import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/comprehensive_land_ownership.dart';
import 'package:obsession_tracker/core/models/trail.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline caching service for trails (SharedPreferences)
///
/// ARCHITECTURE NOTE (v1.4.0):
/// - LAND DATA: Now uses OfflineLandRightsService (encrypted SQLite) for state downloads
/// - TRAILS: Still uses this service (SharedPreferences) for trail caching
///
/// The land caching methods below are DEPRECATED and only serve legacy cached data.
/// New land data is stored in SQLite via OfflineLandRightsService.
///
/// NOTE: This service does NOT depend on BFFMappingService to avoid circular dependencies.
class OfflineCacheService {
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  SharedPreferences? _prefs;

  static const String _cachePrefix = 'offline_land_data_';
  static const String _trailCachePrefix = 'offline_trails_data_';
  static const String _cacheMetadataKey = 'offline_cache_metadata';
  static const String _trailCacheMetadataKey = 'offline_trail_cache_metadata';
  static const Duration _cacheExpiry = Duration(days: 7); // Cache for 1 week

  /// Initialize the cache service
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Cache land data for offline usage around a specific area
  ///
  /// @deprecated Use OfflineLandRightsService for new state-based downloads.
  /// This method only serves legacy area-based caching.
  Future<OfflineCacheResult> cacheAreaForOfflineUse({
    required String areaName,
    required double centerLatitude,
    required double centerLongitude,
    required double radiusKm,
    required List<ComprehensiveLandOwnership> landData,
    void Function(String message)? onProgress,
    void Function(double progress)? onProgressPercent,
  }) async {
    await initialize();

    try {
      onProgress?.call('Processing ${landData.length} land ownership records...');
      onProgressPercent?.call(0.1);

      if (landData.isEmpty) {
        return const OfflineCacheResult(
          success: false,
          message: 'No land data found in this area',
          cachedProperties: 0,
          cacheSize: 0,
        );
      }

      // Warn about large datasets - SharedPreferences has limits
      if (landData.length > 10000) {
        debugPrint('⚠️ LARGE DATASET: Caching ${landData.length} properties may take a while...');
        onProgress?.call('Large dataset (${landData.length} records) - this may take a minute...');
      }

      // Create cache metadata
      final cacheInfo = OfflineCacheInfo(
        areaName: areaName,
        centerLatitude: centerLatitude,
        centerLongitude: centerLongitude,
        radiusKm: radiusKm,
        cachedAt: DateTime.now(),
        propertyCount: landData.length,
        dataSize: 0, // Will be calculated
      );

      // Serialize the processed data (much smaller than raw geodatabase)
      onProgress?.call('Serializing ${landData.length} records...');
      onProgressPercent?.call(0.3);
      debugPrint('📦 Starting serialization of ${landData.length} records for $areaName...');
      final serializeStart = DateTime.now();

      final serializedData = _serializeLandData(landData);
      final serializeTime = DateTime.now().difference(serializeStart);
      debugPrint('📦 Serialization complete in ${serializeTime.inMilliseconds}ms (${(serializedData.length / 1024 / 1024).toStringAsFixed(1)}MB JSON)');

      onProgress?.call('Compressing ${(serializedData.length / 1024 / 1024).toStringAsFixed(1)}MB of data...');
      onProgressPercent?.call(0.6);

      final compressStart = DateTime.now();
      final compressedData = gzip.encode(utf8.encode(serializedData));
      final compressTime = DateTime.now().difference(compressStart);
      debugPrint('📦 Compression complete in ${compressTime.inMilliseconds}ms (${(compressedData.length / 1024 / 1024).toStringAsFixed(1)}MB compressed)');
      
      // Check for SharedPreferences size limits (practical limit ~2-5MB per key)
      // Base64 encoding increases size by ~33%
      final base64Size = ((compressedData.length + 2) ~/ 3) * 4;
      if (base64Size > 5 * 1024 * 1024) {
        debugPrint('⚠️ Data too large for SharedPreferences: ${(base64Size / 1024 / 1024).toStringAsFixed(1)}MB');
        onProgress?.call('Warning: Large data size may cause storage issues');
      }

      // Store in SharedPreferences (or could use SQLite for larger datasets)
      final cacheKey = '$_cachePrefix${_sanitizeAreaName(areaName)}';
      onProgress?.call('Saving to storage...');
      onProgressPercent?.call(0.8);

      debugPrint('📦 Saving ${(base64Size / 1024 / 1024).toStringAsFixed(1)}MB to SharedPreferences...');
      final saveStart = DateTime.now();

      final saveSuccess = await _prefs!.setString(cacheKey, base64Encode(compressedData));
      final saveTime = DateTime.now().difference(saveStart);
      debugPrint('📦 Save ${saveSuccess ? "complete" : "FAILED"} in ${saveTime.inMilliseconds}ms');

      if (!saveSuccess) {
        return const OfflineCacheResult(
          success: false,
          message: 'Failed to save to storage - data may be too large',
          cachedProperties: 0,
          cacheSize: 0,
        );
      }

      // Update cache info with actual size
      cacheInfo.dataSize = compressedData.length;
      await _storeCacheInfo(areaName, cacheInfo);

      onProgressPercent?.call(1.0);
      onProgress?.call('Offline cache created successfully');

      final totalTime = serializeTime + compressTime + saveTime;
      debugPrint('✅ Cached ${landData.length} properties (${(compressedData.length / 1024).toStringAsFixed(1)}KB) in ${totalTime.inSeconds}s');

      return OfflineCacheResult(
        success: true,
        message: 'Cached ${landData.length} properties for offline use',
        cachedProperties: landData.length,
        cacheSize: compressedData.length,
      );
      
    } catch (e) {
      onProgress?.call('Failed to cache area: $e');
      return OfflineCacheResult(
        success: false,
        message: 'Failed to cache area: $e',
        cachedProperties: 0,
        cacheSize: 0,
      );
    }
  }

  /// Get cached land data for offline usage
  /// @deprecated Use OfflineLandRightsService.queryPropertiesForBounds() instead.
  Future<List<ComprehensiveLandOwnership>?> getCachedLandData(String areaName) async {
    await initialize();
    
    final cacheKey = '$_cachePrefix${_sanitizeAreaName(areaName)}';
    final cachedData = _prefs!.getString(cacheKey);
    
    if (cachedData == null) {
      return null;
    }
    
    try {
      // Check if cache is still valid
      final cacheInfo = await _getCacheInfo(areaName);
      if (cacheInfo != null && _isCacheExpired(cacheInfo.cachedAt)) {
        debugPrint('🗑️ Cache expired for $areaName, removing...');
        await deleteCachedArea(areaName);
        return null;
      }
      
      // Decompress and deserialize
      final compressedBytes = base64Decode(cachedData);
      final decompressedData = gzip.decode(compressedBytes);
      final jsonString = utf8.decode(decompressedData);
      
      return _deserializeLandData(jsonString);
    } catch (e) {
      debugPrint('❌ Failed to load cached data for $areaName: $e');
      // Remove corrupted cache
      await deleteCachedArea(areaName);
      return null;
    }
  }

  /// Get list of cached areas available for offline use
  /// @deprecated Use OfflineLandRightsService.getDownloadedStates() instead.
  Future<List<OfflineCacheInfo>> getCachedAreas() async {
    await initialize();
    
    final metadataJson = _prefs!.getString(_cacheMetadataKey);
    if (metadataJson == null) {
      return [];
    }
    
    try {
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
      final areas = <OfflineCacheInfo>[];
      
      for (final entry in metadata.entries) {
        try {
          final info = OfflineCacheInfo.fromJson(entry.value as Map<String, dynamic>);
          
          // Check if cache file still exists
          final cacheKey = '$_cachePrefix${_sanitizeAreaName(entry.key)}';
          if (_prefs!.containsKey(cacheKey)) {
            areas.add(info);
          } else {
            // Metadata exists but cache file doesn't, clean it up
            debugPrint('🧹 Cleaning up orphaned metadata for ${entry.key}');
          }
        } catch (e) {
          debugPrint('❌ Failed to parse cache info for ${entry.key}: $e');
        }
      }
      
      return areas;
    } catch (e) {
      debugPrint('❌ Failed to load cache metadata: $e');
      return [];
    }
  }

  /// Delete cached area data
  Future<bool> deleteCachedArea(String areaName) async {
    await initialize();
    
    try {
      final cacheKey = '$_cachePrefix${_sanitizeAreaName(areaName)}';
      await _prefs!.remove(cacheKey);
      await _removeCacheInfo(areaName);
      
      debugPrint('🗑️ Deleted cached area: $areaName');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete cached area $areaName: $e');
      return false;
    }
  }

  /// Delete state trails cache by state code
  /// State trails are cached with area name 'state_{stateCode}_trails'
  Future<bool> deleteStateTrails(String stateCode) async {
    await initialize();

    final areaName = 'state_${stateCode}_trails';
    try {
      final cacheKey = '$_trailCachePrefix${_sanitizeAreaName(areaName)}';
      await _prefs!.remove(cacheKey);
      await _removeTrailCacheInfo(areaName);

      debugPrint('🗑️ Deleted state trails cache: $areaName');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete state trails $areaName: $e');
      return false;
    }
  }

  /// Get total cache size across all areas
  Future<int> getTotalCacheSize() async {
    final areas = await getCachedAreas();
    return areas.fold<int>(0, (total, area) => total + area.dataSize);
  }

  /// Clear all cached offline data (both land ownership and trails)
  Future<void> clearAllCache() async {
    await initialize();

    // Clear land ownership cache
    final areas = await getCachedAreas();
    for (final area in areas) {
      await deleteCachedArea(area.areaName);
    }
    await _prefs!.remove(_cacheMetadataKey);

    // Clear trail cache
    final trailAreas = await _getTrailCachedAreas();
    for (final area in trailAreas) {
      final areaName = area['areaName'] as String;
      final cacheKey = '$_trailCachePrefix${_sanitizeAreaName(areaName)}';
      await _prefs!.remove(cacheKey);
      debugPrint('🗑️ Deleted cached trail area: $areaName');
    }
    await _prefs!.remove(_trailCacheMetadataKey);

    debugPrint('🧹 Cleared all offline cache (land + trails)');
  }

  /// Clear only auto-generated map view caches (keeps manually downloaded areas)
  Future<int> clearAutoMapCache() async {
    await initialize();

    int cleared = 0;

    // Clear auto-generated land ownership caches
    final areas = await getCachedAreas();
    for (final area in areas) {
      if (area.areaName.startsWith('auto_map_')) {
        await deleteCachedArea(area.areaName);
        cleared++;
      }
    }

    // Clear auto-generated trail caches
    final trailAreas = await _getTrailCachedAreas();
    for (final area in trailAreas) {
      final areaName = area['areaName'] as String;
      if (areaName.startsWith('auto_trails_')) {
        final cacheKey = '$_trailCachePrefix${_sanitizeAreaName(areaName)}';
        await _prefs!.remove(cacheKey);

        // Remove from trail metadata
        final metadataJson = _prefs!.getString(_trailCacheMetadataKey);
        if (metadataJson != null) {
          final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
          metadata.remove(areaName);
          await _prefs!.setString(_trailCacheMetadataKey, jsonEncode(metadata));
        }

        cleared++;
      }
    }

    debugPrint('🧹 Cleared $cleared auto-generated map caches (land + trails)');
    return cleared;
  }

  /// Check if we have offline data for a specific location
  Future<String?> findCachedAreaForLocation(double latitude, double longitude) async {
    final areas = await getCachedAreas();

    for (final area in areas) {
      final distance = _calculateDistance(
        latitude, longitude,
        area.centerLatitude, area.centerLongitude,
      );

      if (distance <= area.radiusKm) {
        return area.areaName;
      }
    }

    return null;
  }

  /// Get cached land data for a bounding box (for offline map queries)
  /// @deprecated Use OfflineLandRightsService.queryPropertiesForBounds() instead.
  Future<List<ComprehensiveLandOwnership>> getCachedLandDataForBounds({
    required double northBound,
    required double southBound,
    required double eastBound,
    required double westBound,
  }) async {
    await initialize();

    // Find all cached areas that might contain this bounds
    final areas = await getCachedAreas();
    final Set<String> seenIds = {}; // Deduplicate properties
    final List<ComprehensiveLandOwnership> matchingProperties = [];
    int overlappingAreas = 0;

    for (final area in areas) {
      // Check if cached area bounding box intersects with requested bounds
      final areaCenterLat = area.centerLatitude;
      final areaCenterLon = area.centerLongitude;
      final areaRadiusDegrees = area.radiusKm / 111.0; // Rough km to degrees

      final areaNorth = areaCenterLat + areaRadiusDegrees;
      final areaSouth = areaCenterLat - areaRadiusDegrees;
      final areaEast = areaCenterLon + areaRadiusDegrees;
      final areaWest = areaCenterLon - areaRadiusDegrees;

      // Check if bounding boxes overlap
      final overlaps = !(areaNorth < southBound ||
                        areaSouth > northBound ||
                        areaEast < westBound ||
                        areaWest > eastBound);

      if (overlaps) {
        overlappingAreas++;
        final data = await getCachedLandData(area.areaName);
        if (data != null) {
          // Add all properties from overlapping cached areas, deduplicating by ID
          for (final property in data) {
            if (!seenIds.contains(property.id)) {
              matchingProperties.add(property);
              seenIds.add(property.id);
            }
          }
        }
      }
    }

    debugPrint('📦 Retrieved ${matchingProperties.length} cached properties for bounds ($overlappingAreas overlapping areas from ${areas.length} total cached areas)');
    return matchingProperties;
  }

  /// Check if the given bounds are fully covered by cached areas
  ///
  /// Returns coverage percentage (0.0 = no coverage, 1.0 = full coverage)
  ///
  /// @deprecated Use OfflineLandRightsService.hasCoverageForBounds() instead.
  Future<double> getCacheCoverage({
    required double northBound,
    required double southBound,
    required double eastBound,
    required double westBound,
  }) async {
    await initialize();

    final areas = await getCachedAreas();
    if (areas.isEmpty) return 0.0;

    // Calculate center point and size of requested bounds
    final centerLat = (northBound + southBound) / 2;
    final centerLon = (eastBound + westBound) / 2;
    final boundsRadiusDegrees = ((northBound - southBound).abs() + (eastBound - westBound).abs()) / 4;

    // First, always get actual cached data for the bounds
    // This ensures we don't claim coverage without data
    final cachedData = await getCachedLandDataForBounds(
      northBound: northBound,
      southBound: southBound,
      eastBound: eastBound,
      westBound: westBound,
    );

    // No cached data = no coverage, regardless of geographic proximity
    if (cachedData.isEmpty) {
      debugPrint('📦 Land cache: 0% coverage (no cached data for bounds)');
      return 0.0;
    }

    // Check if center point is well within any cached area
    for (final area in areas) {
      final distance = _calculateDistance(
        centerLat, centerLon,
        area.centerLatitude, area.centerLongitude,
      );
      final areaRadiusKm = area.radiusKm;
      final boundsRadiusKm = boundsRadiusDegrees * 111.0;

      // If the entire bounds fits comfortably inside a cached area
      if (distance + boundsRadiusKm <= areaRadiusKm * 0.9) {
        debugPrint('📦 Land cache: 100% coverage (${cachedData.length} properties within cached area)');
        return 1.0; // Full coverage - verified we have actual data
      }
    }

    // Partial coverage - we have some data but not full geographic coverage
    debugPrint('📦 Land cache: 50% coverage (${cachedData.length} properties, partial area)');
    return 0.5;
  }

  /// Check if we have any cached data available (offline mode indicator)
  Future<bool> hasAnyCachedData() async {
    try {
      final areas = await getCachedAreas();
      return areas.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking cached data: $e');
      return false;
    }
  }

  /// Automatically cache map view query results for 24 hours
  /// This creates an automatic cache based on the map bounds being viewed
  ///
  /// @deprecated No longer used - land data is stored in SQLite via state downloads.
  Future<void> cacheMapViewQuery({
    required double northBound,
    required double southBound,
    required double eastBound,
    required double westBound,
    required List<ComprehensiveLandOwnership> landData,
  }) async {
    if (landData.isEmpty) return;

    await initialize();

    // Create a cache key based on the bounds (rounded to reduce cache fragmentation)
    // Round to 1 decimal place (~11km resolution) to create larger cache tiles
    final centerLat = ((northBound + southBound) / 2 * 10).round() / 10;
    final centerLon = ((eastBound + westBound) / 2 * 10).round() / 10;
    final areaName = 'auto_map_${centerLat}_$centerLon';

    // Calculate radius of the bounds
    final latDiff = (northBound - southBound).abs();
    final lonDiff = (eastBound - westBound).abs();
    final radiusKm = (latDiff + lonDiff) / 2 * 111.0; // Rough conversion

    try {
      // Store with automatic naming
      await cacheAreaForOfflineUse(
        areaName: areaName,
        centerLatitude: centerLat,
        centerLongitude: centerLon,
        radiusKm: radiusKm,
        landData: landData,
      );
      debugPrint('📦 Auto-cached map view: $areaName (${landData.length} properties)');
    } catch (e) {
      debugPrint('⚠️ Failed to auto-cache map view: $e');
    }
  }

  /// ==================================================================
  /// TRAIL CACHING METHODS (following same pattern as land ownership)
  /// ==================================================================

  /// Automatically cache trail map view query results
  Future<void> cacheTrailsMapViewQuery({
    required double northBound,
    required double southBound,
    required double eastBound,
    required double westBound,
    required List<Trail> trailsData,
  }) async {
    if (trailsData.isEmpty) return;

    await initialize();

    // Create cache key based on bounds (rounded to reduce fragmentation)
    final centerLat = ((northBound + southBound) / 2 * 10).round() / 10;
    final centerLon = ((eastBound + westBound) / 2 * 10).round() / 10;
    final areaName = 'auto_trails_${centerLat}_$centerLon';

    // Calculate radius of the bounds
    final latDiff = (northBound - southBound).abs();
    final lonDiff = (eastBound - westBound).abs();
    final radiusKm = (latDiff + lonDiff) / 2 * 111.0;

    try {
      // Serialize and compress trails data
      final serializedData = _serializeTrailsData(trailsData);
      final compressedData = gzip.encode(utf8.encode(serializedData));

      // Store in SharedPreferences
      final cacheKey = '$_trailCachePrefix${_sanitizeAreaName(areaName)}';
      await _prefs!.setString(cacheKey, base64Encode(compressedData));

      // Store metadata
      await _storeTrailCacheInfo(areaName, {
        'areaName': areaName,
        'centerLatitude': centerLat,
        'centerLongitude': centerLon,
        'radiusKm': radiusKm,
        'cachedAt': DateTime.now().toIso8601String(),
        'trailCount': trailsData.length,
        'dataSize': compressedData.length,
      });

      debugPrint('🥾 Auto-cached trails: $areaName (${trailsData.length} trails, ${(compressedData.length / 1024).toStringAsFixed(1)}KB)');
    } catch (e) {
      debugPrint('⚠️ Failed to auto-cache trails: $e');
    }
  }

  /// Cache trails for a state download (with explicit area name)
  /// Used by DynamicLandDataService when downloading entire states
  Future<OfflineCacheResult> cacheStateTrails({
    required String areaName,
    required double centerLatitude,
    required double centerLongitude,
    required double radiusKm,
    required List<Trail> trailsData,
    void Function(String message)? onProgress,
  }) async {
    await initialize();

    try {
      onProgress?.call('Processing ${trailsData.length} trails...');

      if (trailsData.isEmpty) {
        return const OfflineCacheResult(
          success: true,
          message: 'No trails found in this area',
          cachedProperties: 0,
          cacheSize: 0,
        );
      }

      // Serialize and compress trails data
      final serializedData = _serializeTrailsData(trailsData);
      final compressedData = gzip.encode(utf8.encode(serializedData));

      // Store in SharedPreferences
      final cacheKey = '$_trailCachePrefix${_sanitizeAreaName(areaName)}';
      await _prefs!.setString(cacheKey, base64Encode(compressedData));

      // Store metadata
      await _storeTrailCacheInfo(areaName, {
        'areaName': areaName,
        'centerLatitude': centerLatitude,
        'centerLongitude': centerLongitude,
        'radiusKm': radiusKm,
        'cachedAt': DateTime.now().toIso8601String(),
        'trailCount': trailsData.length,
        'dataSize': compressedData.length,
      });

      final result = OfflineCacheResult(
        success: true,
        message: 'Cached ${trailsData.length} trails',
        cachedProperties: trailsData.length,
        cacheSize: compressedData.length,
      );

      debugPrint('🥾 Cached state trails: $areaName (${trailsData.length} trails, ${result.cacheSizeFormatted})');

      return result;
    } catch (e) {
      debugPrint('❌ Failed to cache state trails: $e');
      return OfflineCacheResult(
        success: false,
        message: 'Failed to cache trails: $e',
        cachedProperties: 0,
        cacheSize: 0,
      );
    }
  }

  /// Get cached trails data for bounding box
  Future<List<Trail>> getCachedTrailsForBounds({
    required double northBound,
    required double southBound,
    required double eastBound,
    required double westBound,
  }) async {
    await initialize();

    final cachedAreas = await _getTrailCachedAreas();
    final Set<String> seenIds = {};
    final List<Trail> matchingTrails = [];
    int overlappingAreas = 0;

    for (final area in cachedAreas) {
      final centerLat = area['centerLatitude'] as double;
      final centerLon = area['centerLongitude'] as double;
      final radiusKm = area['radiusKm'] as double;
      final areaRadiusDegrees = radiusKm / 111.0;

      final areaNorth = centerLat + areaRadiusDegrees;
      final areaSouth = centerLat - areaRadiusDegrees;
      final areaEast = centerLon + areaRadiusDegrees;
      final areaWest = centerLon - areaRadiusDegrees;

      // Check if bounding boxes overlap
      final overlaps = !(areaNorth < southBound ||
                        areaSouth > northBound ||
                        areaEast < westBound ||
                        areaWest > eastBound);

      if (overlaps) {
        overlappingAreas++;
        final areaName = area['areaName'] as String;
        final trails = await _getCachedTrailsData(areaName);
        if (trails != null) {
          for (final trail in trails) {
            if (!seenIds.contains(trail.id)) {
              // Filter trails by actual viewport intersection to avoid memory issues
              final geometry = trail.simplifiedGeometry ?? trail.geometry;
              if (geometry.intersectsBounds(
                northBound: northBound,
                southBound: southBound,
                eastBound: eastBound,
                westBound: westBound,
              )) {
                matchingTrails.add(trail);
                seenIds.add(trail.id);
              }
            }
          }
        }
      }
    }

    debugPrint('🥾 Retrieved ${matchingTrails.length} cached trails for bounds ($overlappingAreas overlapping areas, viewport filtered)');
    return matchingTrails;
  }

  /// Search cached trails by name within visible map bounds
  /// Returns trails whose names contain the query string (case-insensitive)
  Future<List<Trail>> searchCachedTrailsByName({
    required String query,
    required double northBound,
    required double southBound,
    required double eastBound,
    required double westBound,
    int limit = 10,
  }) async {
    if (query.trim().isEmpty) return [];

    // Get all cached trails within bounds
    final cachedTrails = await getCachedTrailsForBounds(
      northBound: northBound,
      southBound: southBound,
      eastBound: eastBound,
      westBound: westBound,
    );

    if (cachedTrails.isEmpty) {
      debugPrint('🔍 Local trail search: No cached trails in bounds');
      return [];
    }

    // Search by name (case-insensitive)
    final lowerQuery = query.toLowerCase().trim();
    final matches = cachedTrails.where((trail) {
      final name = trail.trailName.toLowerCase();
      // Skip generic "unnamed trail" entries
      if (name == 'unnamed trail' || name == 'unnamed' || name.isEmpty) {
        return false;
      }
      return name.contains(lowerQuery);
    }).take(limit).toList();

    debugPrint('🔍 Local trail search: Found ${matches.length} trails matching "$query" (from ${cachedTrails.length} cached)');
    return matches;
  }

  /// Check trail cache coverage for given bounds
  ///
  /// Returns coverage as a value between 0.0 and 1.0:
  /// - 1.0: Full coverage with actual cached data
  /// - 0.5: Partial coverage with some cached data
  /// - 0.0: No cached data for this area
  ///
  /// IMPORTANT: Geographic proximity alone is not sufficient - we must verify
  /// that actual trail data exists for the bounds before claiming coverage.
  Future<double> getTrailCacheCoverage({
    required double northBound,
    required double southBound,
    required double eastBound,
    required double westBound,
  }) async {
    await initialize();

    final cachedAreas = await _getTrailCachedAreas();
    if (cachedAreas.isEmpty) return 0.0;

    final centerLat = (northBound + southBound) / 2;
    final centerLon = (eastBound + westBound) / 2;
    final boundsRadiusDegrees = ((northBound - southBound).abs() + (eastBound - westBound).abs()) / 4;

    // First, always get actual cached trails for the bounds
    // This ensures we don't claim coverage without data
    final cachedTrails = await getCachedTrailsForBounds(
      northBound: northBound,
      southBound: southBound,
      eastBound: eastBound,
      westBound: westBound,
    );

    // No cached trails = no coverage, regardless of geographic proximity
    if (cachedTrails.isEmpty) {
      debugPrint('🥾 Trail cache: 0% coverage (no cached trails for bounds)');
      return 0.0;
    }

    // Check if center point is well within any cached area
    for (final area in cachedAreas) {
      final areaLat = area['centerLatitude'] as double;
      final areaLon = area['centerLongitude'] as double;
      final areaRadiusKm = area['radiusKm'] as double;

      final distance = _calculateDistance(centerLat, centerLon, areaLat, areaLon);
      final boundsRadiusKm = boundsRadiusDegrees * 111.0;

      if (distance + boundsRadiusKm <= areaRadiusKm * 0.9) {
        debugPrint('🥾 Trail cache: 100% coverage (${cachedTrails.length} trails within cached area)');
        return 1.0; // Full coverage - verified we have actual data
      }
    }

    // Partial coverage - we have some trails but not full geographic coverage
    debugPrint('🥾 Trail cache: 50% coverage (${cachedTrails.length} trails, partial area)');
    return 0.5;
  }

  /// Get trail counts for each downloaded state
  /// Returns a map of state codes to trail counts (e.g., {'CA': 7360, 'NV': 1200})
  Future<Map<String, int>> getStateTrailCounts() async {
    await initialize();

    final trailAreas = await _getTrailCachedAreas();
    final stateCounts = <String, int>{};

    for (final area in trailAreas) {
      final areaName = area['areaName'] as String?;
      final trailCount = area['trailCount'] as int?;

      // State trail caches are named "state_XX_trails" (e.g., "state_CA_trails")
      if (areaName != null && areaName.startsWith('state_') && areaName.endsWith('_trails')) {
        // Extract state code: "state_CA_trails" -> "CA"
        final stateCode = areaName.substring(6, areaName.length - 7);
        if (stateCode.length == 2 && trailCount != null) {
          stateCounts[stateCode] = trailCount;
        }
      }
    }

    return stateCounts;
  }

  // Trail cache helper methods

  Future<List<Map<String, dynamic>>> _getTrailCachedAreas() async {
    final metadataJson = _prefs!.getString(_trailCacheMetadataKey);
    if (metadataJson == null) return [];

    try {
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
      return metadata.values.map((v) => v as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Failed to load trail cache metadata: $e');
      return [];
    }
  }

  Future<List<Trail>?> _getCachedTrailsData(String areaName) async {
    final cacheKey = '$_trailCachePrefix${_sanitizeAreaName(areaName)}';
    final cachedData = _prefs!.getString(cacheKey);

    if (cachedData == null) return null;

    try {
      final compressedBytes = base64Decode(cachedData);
      final decompressedData = gzip.decode(compressedBytes);
      final jsonString = utf8.decode(decompressedData);
      return _deserializeTrailsData(jsonString);
    } catch (e) {
      debugPrint('❌ Failed to load cached trails for $areaName: $e');
      return null;
    }
  }

  Future<void> _storeTrailCacheInfo(String areaName, Map<String, dynamic> info) async {
    final metadataJson = _prefs!.getString(_trailCacheMetadataKey);
    final metadata = metadataJson != null
        ? jsonDecode(metadataJson) as Map<String, dynamic>
        : <String, dynamic>{};

    metadata[areaName] = info;
    await _prefs!.setString(_trailCacheMetadataKey, jsonEncode(metadata));
  }

  String _serializeTrailsData(List<Trail> trails) {
    final List<Map<String, dynamic>> jsonList = trails.map((trail) => trail.toJson()).toList();
    return jsonEncode(jsonList);
  }

  List<Trail> _deserializeTrailsData(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList.map((json) => Trail.fromJson(json as Map<String, dynamic>)).toList();
  }

  // Helper methods

  String _sanitizeAreaName(String areaName) {
    return areaName.replaceAll(RegExp('[^a-zA-Z0-9_]'), '_').toLowerCase();
  }

  bool _isCacheExpired(DateTime cachedAt) {
    return DateTime.now().difference(cachedAt) > _cacheExpiry;
  }

  String _serializeLandData(List<ComprehensiveLandOwnership> data) {
    // Serialize to JSON, including simplified boundaries for map display
    // Since we're using cache-first strategy even when online, we need coordinates
    final serializable = data.map((land) => {
      'id': land.id,
      'ownerName': land.ownerName,
      'ownershipType': land.ownershipType,
      'displayName': land.displayName,
      'ownershipColor': land.ownershipColor,
      'permissionSummary': land.permissionSummary,
      'requiresAttention': land.requiresAttention,
      'sizeSummary': land.sizeSummary,
      'dataSource': land.dataSource,
      'lastUpdated': land.lastUpdated?.toIso8601String(),
      'activityPermissions': land.activityPermissions.toJson(),
      'accessRights': land.accessRights.toJson(),
      'ownerContact': land.ownerContact?.toJson(),
      // Include essential legacy fields
      'agencyName': land.agencyName,
      'unitName': land.unitName,
      'designation': land.designation,
      'accessType': land.accessType,
      'allowedUses': land.allowedUses,
      'restrictions': land.restrictions,
      'contactInfo': land.contactInfo,
      'website': land.website,
      'fees': land.fees,
      'seasonalInfo': land.seasonalInfo,
      'acreage': land.acreage,
      'legalDescription': land.legalDescription,
      // Include boundaries for map display (prefer medium LOD for cache size)
      'mediumBoundaries': land.mediumBoundaries != null
          ? {'coordinates': land.mediumBoundaries}
          : null,
      'boundaries': land.boundaries != null && land.mediumBoundaries == null
          ? {'coordinates': land.boundaries}
          : null,
    }).toList();

    return jsonEncode(serializable);
  }

  List<ComprehensiveLandOwnership> _deserializeLandData(String jsonString) {
    final List<dynamic> dataList = jsonDecode(jsonString) as List<dynamic>;
    
    return dataList.map((item) {
      final map = item as Map<String, dynamic>;
      return ComprehensiveLandOwnership.fromJson(map);
    }).toList();
  }

  Future<void> _storeCacheInfo(String areaName, OfflineCacheInfo info) async {
    final metadataJson = _prefs!.getString(_cacheMetadataKey) ?? '{}';
    final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
    
    metadata[areaName] = info.toJson();
    
    await _prefs!.setString(_cacheMetadataKey, jsonEncode(metadata));
  }

  Future<OfflineCacheInfo?> _getCacheInfo(String areaName) async {
    final metadataJson = _prefs!.getString(_cacheMetadataKey);
    if (metadataJson == null) return null;
    
    final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
    final infoData = metadata[areaName];
    if (infoData == null) return null;
    
    return OfflineCacheInfo.fromJson(infoData as Map<String, dynamic>);
  }

  Future<void> _removeCacheInfo(String areaName) async {
    final metadataJson = _prefs!.getString(_cacheMetadataKey) ?? '{}';
    final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;

    metadata.remove(areaName);

    await _prefs!.setString(_cacheMetadataKey, jsonEncode(metadata));
  }

  Future<void> _removeTrailCacheInfo(String areaName) async {
    final metadataJson = _prefs!.getString(_trailCacheMetadataKey) ?? '{}';
    final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;

    metadata.remove(areaName);

    await _prefs!.setString(_trailCacheMetadataKey, jsonEncode(metadata));
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}

/// Result of offline cache operation
class OfflineCacheResult {
  final bool success;
  final String message;
  final int cachedProperties;
  final int cacheSize; // in bytes

  const OfflineCacheResult({
    required this.success,
    required this.message,
    required this.cachedProperties,
    required this.cacheSize,
  });

  String get cacheSizeFormatted {
    if (cacheSize < 1024) {
      return '$cacheSize B';
    } else if (cacheSize < 1024 * 1024) {
      return '${(cacheSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(cacheSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

/// Information about a cached offline area
class OfflineCacheInfo {
  final String areaName;
  final double centerLatitude;
  final double centerLongitude;
  final double radiusKm;
  final DateTime cachedAt;
  final int propertyCount;
  int dataSize; // in bytes

  OfflineCacheInfo({
    required this.areaName,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusKm,
    required this.cachedAt,
    required this.propertyCount,
    required this.dataSize,
  });

  factory OfflineCacheInfo.fromJson(Map<String, dynamic> json) {
    return OfflineCacheInfo(
      areaName: json['areaName'] as String,
      centerLatitude: (json['centerLatitude'] as num).toDouble(),
      centerLongitude: (json['centerLongitude'] as num).toDouble(),
      radiusKm: (json['radiusKm'] as num).toDouble(),
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      propertyCount: json['propertyCount'] as int,
      dataSize: json['dataSize'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'areaName': areaName,
      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,
      'radiusKm': radiusKm,
      'cachedAt': cachedAt.toIso8601String(),
      'propertyCount': propertyCount,
      'dataSize': dataSize,
    };
  }

  String get cacheSizeFormatted {
    if (dataSize < 1024) {
      return '$dataSize B';
    } else if (dataSize < 1024 * 1024) {
      return '${(dataSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(dataSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  bool get isExpired {
    const cacheExpiry = Duration(days: 7);
    return DateTime.now().difference(cachedAt) > cacheExpiry;
  }
}