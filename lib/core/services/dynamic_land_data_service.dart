import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:obsession_tracker/core/config/bff_config.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/services/bff_mapping_service.dart';
import 'package:obsession_tracker/core/services/device_registration_service.dart';
import 'package:obsession_tracker/core/services/offline_land_rights_service.dart';

/// Service for dynamic land data management across all US states
/// Downloads state data from the BFF (Backend-for-Frontend) which has
/// pre-processed PAD-US and trail data already transformed for our app.
///
/// STORAGE: Uses encrypted SQLite database via OfflineLandRightsService
/// for secure, high-performance storage of large state datasets (20,000+ records).
/// The database is encrypted with AES-256 using keys stored in iOS Keychain /
/// Android KeyStore.
class DynamicLandDataService {
  DynamicLandDataService._internal();
  static DynamicLandDataService? _instance;

  /// Cached metadata from BFF with state sizes
  Map<String, int>? _stateSizesCache;
  DateTime? _sizeCacheTime;
  static const Duration _sizeCacheMaxAge = Duration(hours: 24);

  // All US states and territories
  static const Map<String, StateInfo> availableStates = {
    'AL': StateInfo('Alabama',
        LandBounds(north: 35.01, south: 30.18, east: -84.89, west: -88.47)),
    'AK': StateInfo('Alaska',
        LandBounds(north: 71.37, south: 51.21, east: -129.99, west: -179.78)),
    'AZ': StateInfo('Arizona',
        LandBounds(north: 37.00, south: 31.33, east: -109.05, west: -114.82)),
    'AR': StateInfo('Arkansas',
        LandBounds(north: 36.50, south: 33.00, east: -89.65, west: -94.62)),
    'CA': StateInfo('California',
        LandBounds(north: 42.01, south: 32.53, east: -114.13, west: -124.48)),
    'CO': StateInfo('Colorado',
        LandBounds(north: 41.00, south: 36.99, east: -102.04, west: -109.06)),
    'CT': StateInfo('Connecticut',
        LandBounds(north: 42.05, south: 40.98, east: -71.79, west: -73.73)),
    'DE': StateInfo('Delaware',
        LandBounds(north: 39.84, south: 38.45, east: -75.05, west: -75.79)),
    'FL': StateInfo('Florida',
        LandBounds(north: 31.00, south: 24.40, east: -79.97, west: -87.63)),
    'GA': StateInfo('Georgia',
        LandBounds(north: 35.00, south: 30.36, east: -80.89, west: -85.61)),
    // Note: Hawaii excluded - no OSM trail data available
    'ID': StateInfo('Idaho',
        LandBounds(north: 49.00, south: 41.99, east: -111.04, west: -117.24)),
    'IL': StateInfo('Illinois',
        LandBounds(north: 42.51, south: 36.97, east: -87.02, west: -91.51)),
    'IN': StateInfo('Indiana',
        LandBounds(north: 41.76, south: 37.77, east: -84.78, west: -88.10)),
    'IA': StateInfo('Iowa',
        LandBounds(north: 43.50, south: 40.38, east: -90.14, west: -96.64)),
    'KS': StateInfo('Kansas',
        LandBounds(north: 40.00, south: 36.99, east: -94.59, west: -102.05)),
    'KY': StateInfo('Kentucky',
        LandBounds(north: 39.15, south: 36.50, east: -81.96, west: -89.57)),
    'LA': StateInfo('Louisiana',
        LandBounds(north: 33.02, south: 28.93, east: -88.82, west: -94.04)),
    'ME': StateInfo('Maine',
        LandBounds(north: 47.46, south: 43.07, east: -66.95, west: -71.08)),
    'MD': StateInfo('Maryland',
        LandBounds(north: 39.72, south: 37.89, east: -75.05, west: -79.49)),
    'MA': StateInfo('Massachusetts',
        LandBounds(north: 42.89, south: 41.24, east: -69.93, west: -73.51)),
    'MI': StateInfo('Michigan',
        LandBounds(north: 48.32, south: 41.70, east: -82.12, west: -90.42)),
    'MN': StateInfo('Minnesota',
        LandBounds(north: 49.38, south: 43.50, east: -89.53, west: -97.23)),
    'MS': StateInfo('Mississippi',
        LandBounds(north: 35.01, south: 30.17, east: -88.10, west: -91.65)),
    'MO': StateInfo('Missouri',
        LandBounds(north: 40.61, south: 35.99, east: -89.10, west: -95.77)),
    'MT': StateInfo('Montana',
        LandBounds(north: 49.00, south: 44.36, east: -104.04, west: -116.05)),
    'NE': StateInfo('Nebraska',
        LandBounds(north: 43.00, south: 39.99, east: -95.31, west: -104.05)),
    'NV': StateInfo('Nevada',
        LandBounds(north: 42.00, south: 35.00, east: -114.04, west: -120.01)),
    'NH': StateInfo('New Hampshire',
        LandBounds(north: 45.31, south: 42.70, east: -70.61, west: -72.56)),
    'NJ': StateInfo('New Jersey',
        LandBounds(north: 41.36, south: 38.93, east: -73.89, west: -75.56)),
    'NM': StateInfo('New Mexico',
        LandBounds(north: 37.00, south: 31.33, east: -103.00, west: -109.05)),
    'NY': StateInfo('New York',
        LandBounds(north: 45.02, south: 40.48, east: -71.86, west: -79.76)),
    'NC': StateInfo('North Carolina',
        LandBounds(north: 36.59, south: 33.84, east: -75.46, west: -84.32)),
    'ND': StateInfo('North Dakota',
        LandBounds(north: 49.00, south: 45.94, east: -96.55, west: -104.05)),
    'OH': StateInfo('Ohio',
        LandBounds(north: 41.98, south: 38.40, east: -80.52, west: -84.82)),
    'OK': StateInfo('Oklahoma',
        LandBounds(north: 37.00, south: 33.62, east: -94.43, west: -103.00)),
    'OR': StateInfo('Oregon',
        LandBounds(north: 46.29, south: 41.99, east: -116.46, west: -124.56)),
    'PA': StateInfo('Pennsylvania',
        LandBounds(north: 42.27, south: 39.72, east: -74.69, west: -80.52)),
    'RI': StateInfo('Rhode Island',
        LandBounds(north: 42.02, south: 41.15, east: -71.12, west: -71.86)),
    'SC': StateInfo('South Carolina',
        LandBounds(north: 35.22, south: 32.05, east: -78.54, west: -83.35)),
    'SD': StateInfo('South Dakota',
        LandBounds(north: 45.94, south: 42.48, east: -96.44, west: -104.06)),
    'TN': StateInfo('Tennessee',
        LandBounds(north: 36.68, south: 34.98, east: -81.65, west: -90.31)),
    'TX': StateInfo('Texas',
        LandBounds(north: 36.50, south: 25.84, east: -93.51, west: -106.65)),
    'UT': StateInfo('Utah',
        LandBounds(north: 42.00, south: 36.99, east: -109.04, west: -114.05)),
    'VT': StateInfo('Vermont',
        LandBounds(north: 45.02, south: 42.73, east: -71.46, west: -73.44)),
    'VA': StateInfo('Virginia',
        LandBounds(north: 39.46, south: 36.54, east: -75.24, west: -83.68)),
    'WA': StateInfo('Washington',
        LandBounds(north: 49.00, south: 45.54, east: -116.92, west: -124.85)),
    'WV': StateInfo('West Virginia',
        LandBounds(north: 40.64, south: 37.20, east: -77.72, west: -82.64)),
    'WI': StateInfo('Wisconsin',
        LandBounds(north: 47.31, south: 42.49, east: -86.25, west: -92.89)),
    'WY': StateInfo('Wyoming',
        LandBounds(north: 45.00, south: 40.99, east: -104.05, west: -111.06)),
  };

  static DynamicLandDataService get instance {
    _instance ??= DynamicLandDataService._internal();
    return _instance!;
  }

  /// Get list of available states for download
  List<String> getAvailableStates() => availableStates.keys.toList()..sort();

  /// Get downloaded states from encrypted SQLite database
  Future<List<String>> getDownloadedStates() async {
    final offlineLandRights = OfflineLandRightsService();
    await offlineLandRights.initialize();

    final downloadedStateInfos = await offlineLandRights.getDownloadedStates();
    final downloadedStates = downloadedStateInfos
        .map((info) => info.stateCode)
        .where((state) => availableStates.containsKey(state))
        .toList();

    debugPrint(
        '📍 Downloaded states: $downloadedStates (${downloadedStates.length}/50)');
    return downloadedStates;
  }

  /// Check if a state is downloaded
  Future<bool> isStateDownloaded(String stateCode) async {
    final offlineLandRights = OfflineLandRightsService();
    await offlineLandRights.initialize();
    return offlineLandRights.isStateDownloaded(stateCode.toUpperCase());
  }

  /// Get download size estimate for a state (total of land + trails + historical ZIPs)
  /// Fetches from BFF /api/v1/downloads/metadata endpoint
  Future<int> getStateDataSize(String stateCode) async {
    // Use cached sizes if available and fresh
    if (_stateSizesCache != null && _sizeCacheTime != null) {
      if (DateTime.now().difference(_sizeCacheTime!) < _sizeCacheMaxAge) {
        final size = _stateSizesCache![stateCode.toUpperCase()];
        if (size != null) return size;
      }
    }

    // Fetch fresh metadata from API
    await _fetchStateSizesMetadata();

    // Return size from cache or default
    return _stateSizesCache?[stateCode.toUpperCase()] ?? 20 * 1024 * 1024;
  }

  /// Fetch state sizes metadata from BFF
  Future<void> _fetchStateSizesMetadata() async {
    try {
      final baseUrl = BFFConfig.getBaseUrl();
      final apiKey = await DeviceRegistrationService.instance.getApiKey();
      final useDevData = BFFConfig.useDevData;

      debugPrint('📊 Fetching metadata from: $baseUrl/api/v1/downloads/metadata (dev: $useDevData)');

      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/downloads/metadata'),
        headers: {
          'Accept': 'application/json',
          if (apiKey != null) 'X-API-Key': apiKey,
          if (useDevData) 'X-Environment': 'dev',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final versions = json['versions'] as Map<String, dynamic>?;
        final states = json['states'] as List<dynamic>?;

        debugPrint('📊 Metadata versions: $versions');

        if (states != null) {
          _stateSizesCache = {};
          for (final state in states) {
            final stateCode = state['state_code'] as String?;
            final totalSize = state['total_size'] as int?;
            if (stateCode != null && totalSize != null) {
              _stateSizesCache![stateCode] = totalSize;
            }
          }
          _sizeCacheTime = DateTime.now();
          debugPrint('📊 Fetched state sizes for ${_stateSizesCache!.length} states (dev: $useDevData)');
        }
      } else {
        debugPrint('📊 Failed to fetch state sizes: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('📊 Network error fetching state sizes: $e');
    } on http.ClientException catch (e) {
      debugPrint('📊 HTTP error fetching state sizes: $e');
    } catch (e) {
      debugPrint('📊 Error fetching state sizes: $e');
    }
  }

  /// Get all state sizes at once (more efficient than calling getStateDataSize 49 times)
  /// Returns a map of state code -> total size in bytes
  Future<Map<String, int>> getAllStateSizes() async {
    // Ensure cache is populated and fresh
    if (_stateSizesCache == null ||
        _sizeCacheTime == null ||
        DateTime.now().difference(_sizeCacheTime!) >= _sizeCacheMaxAge) {
      await _fetchStateSizesMetadata();
    }
    return Map.unmodifiable(_stateSizesCache ?? {});
  }

  /// Download land data for specific states
  Future<void> downloadStatesData(
    List<String> stateCodes, {
    void Function(String state, String message)? onProgress,
    void Function(String state, String error)? onError,
    void Function(String state, int imported)? onStateCompleted,
    void Function(double overallProgress)? onOverallProgress,
    bool forceRedownload = false,
  }) async {
    onProgress?.call(
        'ALL', 'Starting download for ${stateCodes.length} states...');

    int completedStates = 0;
    int totalImported = 0;

    for (final stateCode in stateCodes) {
      try {
        final upperStateCode = stateCode.toUpperCase();
        final stateInfo = availableStates[upperStateCode];

        if (stateInfo == null) {
          onError?.call(upperStateCode, 'Unknown state code: $upperStateCode');
          continue;
        }

        onProgress?.call(upperStateCode, 'Downloading ${stateInfo.name}...');

        final imported = await _downloadSingleStateData(
          upperStateCode,
          stateInfo,
          onProgress: (message) => onProgress?.call(upperStateCode, message),
          onError: (error) => onError?.call(upperStateCode, error),
          forceRedownload: forceRedownload,
        );

        totalImported += imported;
        completedStates++;

        onStateCompleted?.call(upperStateCode, imported);
        onOverallProgress?.call(completedStates / stateCodes.length);
      } catch (e) {
        onError?.call(stateCode, 'Failed to download: $e');
      }
    }

    onProgress?.call(
        'ALL', 'Download completed. Total records: $totalImported');
  }

  /// Download data for a single state from the BFF using bulk download API
  /// The BFF has pre-processed PAD-US data already transformed for our app
  /// Uses rate-limited bulk download endpoint (24-hour cooldown per state)
  Future<int> _downloadSingleStateData(
    String stateCode,
    StateInfo stateInfo, {
    void Function(String message)? onProgress,
    void Function(String error)? onError,
    bool forceRedownload = false,
  }) async {
    try {
      // Check if already downloaded (skip check if forcing re-download for updates)
      if (!forceRedownload && await isStateDownloaded(stateCode)) {
        onProgress?.call('Already downloaded, skipping...');
        return 0;
      }

      // If forcing re-download, delete existing data first
      if (forceRedownload && await isStateDownloaded(stateCode)) {
        onProgress?.call('Removing old data for update...');
        debugPrint('🔄 Force re-download: Deleting existing data for $stateCode');
        final offlineLandRights = OfflineLandRightsService();
        await offlineLandRights.initialize();
        await offlineLandRights.deleteStateData(stateCode);
      }

      onProgress?.call('📡 Downloading ${stateInfo.name} data...');
      debugPrint('🗂️ Downloading state data for $stateCode from BFF (bulk API - streaming to SQLite)');

      // Initialize offline service for streaming database writes
      final offlineLandRights = OfflineLandRightsService();
      await offlineLandRights.initialize();

      // Use the STREAMING bulk download API that saves directly to SQLite
      // This avoids OOM crashes on large states like Alaska (119MB ZIP, 403MB JSON)
      final result = await BFFMappingService.instance.downloadStateDataToDatabase(
        stateCode: stateCode,
        offlineService: offlineLandRights,
        onDownloadProgress: (bytesReceived, totalBytes) {
          final receivedMB = (bytesReceived / 1024 / 1024).toStringAsFixed(1);
          if (totalBytes > 0) {
            final totalMB = (totalBytes / 1024 / 1024).toStringAsFixed(1);
            final percent = ((bytesReceived / totalBytes) * 100).toInt();
            onProgress?.call('📥 Downloading: $receivedMB / $totalMB MB ($percent%)');
          } else {
            onProgress?.call('📥 Downloading: $receivedMB MB...');
          }
        },
        onProcessProgress: (recordsProcessed, totalRecords) {
          final percent = ((recordsProcessed / totalRecords) * 100).toInt();
          onProgress?.call('💾 Processing: $recordsProcessed / $totalRecords records ($percent%)');
        },
      );

      // Handle the different response types
      switch (result) {
        case StateDownloadSuccess():
          // Data is already saved to SQLite by downloadStateDataToDatabase
          // landOwnerships list is empty but recordCount has the total
          if (result.recordCount == 0) {
            onProgress?.call('⚠️ No land data available for $stateCode');
            debugPrint('⚠️ No data returned from BFF for $stateCode');
            return 0;
          }

          onProgress?.call('✅ Saved ${result.recordCount} records to encrypted database (${result.dataVersion})');
          debugPrint('📦 BFF streaming download complete: ${result.recordCount} properties for $stateCode (v${result.dataVersion})');

          // NOTE: Trails are now included in the ZIP file (trails.json) and imported
          // by downloadStateDataToDatabase(). No separate BFF API call needed.
          // The old secondary download was causing duplicate/corrupted trail data.
          onProgress?.call('✅ Complete: ${result.recordCount} properties (trails included in ZIP)');

          debugPrint('✅ State download complete: ${result.recordCount} land records for $stateCode');
          return result.recordCount;

        case StateDownloadRateLimited():
          final hours = (result.cooldownRemainingSeconds / 3600).ceil();
          final message = 'Rate limited: Please wait ~$hours hours before downloading $stateCode again';
          onError?.call(message);
          debugPrint('🚦 Rate limited for $stateCode: ${result.reason}');
          return 0;

        case StateDownloadError():
          onError?.call('Download failed: ${result.message}');
          debugPrint('❌ BFF bulk download error for $stateCode: ${result.code} - ${result.message}');
          return 0;
      }
    } catch (e) {
      onError?.call('Download failed: $e');
      debugPrint('❌ Exception during bulk download for $stateCode: $e');
      rethrow;
    }
  }
  /// Delete data for specific states (removes from encrypted SQLite database)
  Future<int> deleteStatesData(List<String> stateCodes) async {
    final offlineLandRights = OfflineLandRightsService();
    await offlineLandRights.initialize();

    // First, filter to only states that actually have data
    final downloadedStates = await getDownloadedStates();
    final statesToDelete = stateCodes
        .map((s) => s.toUpperCase())
        .where(downloadedStates.contains)
        .toList();

    if (statesToDelete.isEmpty) {
      return 0; // No states to delete
    }

    int totalDeleted = 0;
    for (final stateCode in statesToDelete) {
      await offlineLandRights.deleteStateData(stateCode);
      // Clear the in-memory trails cache for this state
      BFFMappingService.instance.clearTrailsCache(stateCode);
      totalDeleted++;
      debugPrint('🗑️ Deleted cached state: $stateCode');
    }

    return totalDeleted;
  }

  /// Get record counts by state (from encrypted SQLite database)
  Future<Map<String, int>> getStorageUsageByState() async {
    final offlineLandRights = OfflineLandRightsService();
    await offlineLandRights.initialize();

    final downloadedStateInfos = await offlineLandRights.getDownloadedStates();

    final stateCounts = <String, int>{};
    for (final info in downloadedStateInfos) {
      if (availableStates.containsKey(info.stateCode)) {
        // Return property count, not byte size (UI displays "X land records stored")
        stateCounts[info.stateCode] = info.propertyCount;
      }
    }

    return stateCounts;
  }

  /// Clear all land ownership data (debug/cleanup method)
  /// Clears state downloads from encrypted database
  Future<void> clearAllLandData() async {
    final offlineLandRights = OfflineLandRightsService();
    await offlineLandRights.initialize();
    await offlineLandRights.clearAllCache();
    // Clear the entire in-memory trails cache
    BFFMappingService.instance.clearTrailsCache();
    debugPrint('🧹 Cleared all cached land data from encrypted database');
  }

  /// Get recommended states based on user location
  Future<List<String>> getRecommendedStates(
      double latitude, double longitude) async {
    final recommendations = <String>[];

    // Find states that contain the point
    for (final entry in availableStates.entries) {
      if (entry.value.bounds
          .contains(LandPoint(latitude: latitude, longitude: longitude))) {
        recommendations.add(entry.key);
      }
    }

    // Add neighboring states
    // This would be more sophisticated in production

    return recommendations;
  }

}

/// Information about a state
class StateInfo {
  const StateInfo(this.name, this.bounds);

  final String name;
  final LandBounds bounds;
}
