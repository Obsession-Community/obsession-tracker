import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:obsession_tracker/core/config/bff_config.dart';
import 'package:obsession_tracker/core/services/device_registration_service.dart';
import 'package:obsession_tracker/core/services/layer_manifest_service.dart';
import 'package:obsession_tracker/core/services/nhp_download_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Bounds for a historical map overlay (WGS84 coordinates)
class HistoricalMapBounds {
  const HistoricalMapBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
    this.centerLng,
    this.centerLat,
    this.defaultZoom,
  });

  /// Western longitude (min X)
  final double west;

  /// Southern latitude (min Y)
  final double south;

  /// Eastern longitude (max X)
  final double east;

  /// Northern latitude (max Y)
  final double north;

  /// Optional center longitude from MBTiles metadata
  final double? centerLng;

  /// Optional center latitude from MBTiles metadata
  final double? centerLat;

  /// Optional default zoom from MBTiles metadata
  final double? defaultZoom;

  /// Get center longitude (from metadata or calculated)
  double get centerLongitude => centerLng ?? (west + east) / 2;

  /// Get center latitude (from metadata or calculated)
  double get centerLatitude => centerLat ?? (south + north) / 2;

  /// Parse bounds from MBTiles metadata string (format: "west,south,east,north")
  static HistoricalMapBounds? fromBoundsString(
    String? boundsStr, {
    String? centerStr,
  }) {
    if (boundsStr == null || boundsStr.isEmpty) return null;

    try {
      final parts = boundsStr.split(',').map((s) => double.parse(s.trim())).toList();
      if (parts.length != 4) return null;

      double? centerLng;
      double? centerLat;
      double? defaultZoom;

      // Parse center string if provided (format: "lng,lat,zoom")
      if (centerStr != null && centerStr.isNotEmpty) {
        final centerParts = centerStr.split(',').map((s) => double.parse(s.trim())).toList();
        if (centerParts.length >= 2) {
          centerLng = centerParts[0];
          centerLat = centerParts[1];
          if (centerParts.length >= 3) {
            defaultZoom = centerParts[2];
          }
        }
      }

      return HistoricalMapBounds(
        west: parts[0],
        south: parts[1],
        east: parts[2],
        north: parts[3],
        centerLng: centerLng,
        centerLat: centerLat,
        defaultZoom: defaultZoom,
      );
    } catch (e) {
      debugPrint('🗺️ Error parsing bounds string "$boundsStr": $e');
      return null;
    }
  }

  @override
  String toString() =>
      'HistoricalMapBounds(west: $west, south: $south, east: $east, north: $north, center: ($centerLongitude, $centerLatitude), zoom: $defaultZoom)';
}

/// Result of a historical map download operation
sealed class HistoricalMapDownloadResult {
  const HistoricalMapDownloadResult();
}

/// Successful download
class HistoricalMapDownloadSuccess extends HistoricalMapDownloadResult {
  const HistoricalMapDownloadSuccess({
    required this.stateCode,
    required this.layerId,
    required this.filePath,
    required this.sizeBytes,
  });

  final String stateCode;
  final String layerId;
  final String filePath;
  final int sizeBytes;
}

/// Download error
class HistoricalMapDownloadError extends HistoricalMapDownloadResult {
  const HistoricalMapDownloadError({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;
}

/// Information about a downloaded historical map layer
class DownloadedHistoricalMap {
  const DownloadedHistoricalMap({
    required this.stateCode,
    required this.layerId,
    required this.name,
    required this.era,
    required this.filePath,
    required this.sizeBytes,
    required this.downloadedAt,
  });

  final String stateCode;
  final String layerId;
  final String name;
  final String? era;
  final String filePath;
  final int sizeBytes;
  final DateTime downloadedAt;

  Map<String, dynamic> toJson() => {
        'stateCode': stateCode,
        'layerId': layerId,
        'name': name,
        'era': era,
        'filePath': filePath,
        'sizeBytes': sizeBytes,
        'downloadedAt': downloadedAt.toIso8601String(),
      };

  factory DownloadedHistoricalMap.fromJson(Map<String, dynamic> json) {
    return DownloadedHistoricalMap(
      stateCode: json['stateCode'] as String,
      layerId: json['layerId'] as String,
      name: json['name'] as String,
      era: json['era'] as String?,
      filePath: json['filePath'] as String,
      sizeBytes: json['sizeBytes'] as int,
      downloadedAt: DateTime.parse(json['downloadedAt'] as String),
    );
  }
}

/// Service for downloading and managing historical map overlays (MBTiles).
///
/// Unlike vector data (land, trails, historical places) which is stored in SQLite,
/// historical maps are stored as MBTiles files in the app's documents directory
/// and referenced directly by Mapbox for rendering.
class HistoricalMapsService {
  HistoricalMapsService._();
  static final HistoricalMapsService instance = HistoricalMapsService._();

  static const String _downloadedMapsKey = 'downloaded_historical_maps';

  bool _initialized = false;
  final Map<String, DownloadedHistoricalMap> _downloadedMaps = {};

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;

    await _loadDownloadedMaps();
    _initialized = true;
    debugPrint('🗺️ HistoricalMapsService initialized with ${_downloadedMaps.length} maps');
  }

  /// Get directory for storing MBTiles files
  Future<Directory> _getMBTilesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mbtDir = Directory('${appDir.path}/historical_maps');
    if (!await mbtDir.exists()) {
      await mbtDir.create(recursive: true);
    }
    return mbtDir;
  }

  /// Get path for a specific MBTiles file
  Future<String> _getMBTilesPath(String stateCode, String layerId) async {
    final dir = await _getMBTilesDirectory();
    return '${dir.path}/${stateCode.toLowerCase()}_$layerId.mbtiles';
  }

  /// Check if a historical map layer is downloaded
  Future<bool> isLayerDownloaded(String stateCode, String layerId) async {
    await initialize();
    final key = '${stateCode.toUpperCase()}_$layerId';
    final info = _downloadedMaps[key];
    if (info == null) return false;

    // Verify file still exists
    final file = File(info.filePath);
    return file.existsSync();
  }

  /// Get info about a downloaded layer
  Future<DownloadedHistoricalMap?> getDownloadedLayer(
    String stateCode,
    String layerId,
  ) async {
    await initialize();
    final key = '${stateCode.toUpperCase()}_$layerId';
    return _downloadedMaps[key];
  }

  /// Get all downloaded historical maps
  /// Filters out entries where the file no longer exists (e.g., after app reinstall)
  Future<List<DownloadedHistoricalMap>> getDownloadedMaps() async {
    await initialize();

    // Verify files still exist and clean up stale entries
    final validMaps = <DownloadedHistoricalMap>[];
    final staleKeys = <String>[];

    for (final entry in _downloadedMaps.entries) {
      final file = File(entry.value.filePath);
      if (file.existsSync()) {
        validMaps.add(entry.value);
      } else {
        staleKeys.add(entry.key);
        debugPrint('🗺️ Removing stale historical map entry: ${entry.key} (file not found)');
      }
    }

    // Remove stale entries from tracking
    if (staleKeys.isNotEmpty) {
      staleKeys.forEach(_downloadedMaps.remove);
      await _saveDownloadedMaps();
    }

    return validMaps;
  }

  /// Get downloaded maps for a specific state
  /// Uses getDownloadedMaps() to ensure stale entries are cleaned up
  Future<List<DownloadedHistoricalMap>> getDownloadedMapsForState(
    String stateCode,
  ) async {
    final allMaps = await getDownloadedMaps();
    return allMaps
        .where((m) => m.stateCode == stateCode.toUpperCase())
        .toList();
  }

  /// Get total storage used by historical maps
  Future<int> getTotalStorageUsed() async {
    await initialize();
    int total = 0;
    for (final map in _downloadedMaps.values) {
      total += map.sizeBytes;
    }
    return total;
  }

  /// Download a historical map layer
  Future<HistoricalMapDownloadResult> downloadLayer({
    required String stateCode,
    required String layerId,
    void Function(int bytesReceived, int totalBytes)? onProgress,
  }) async {
    await initialize();

    final upperStateCode = stateCode.toUpperCase();
    debugPrint('🗺️ Downloading historical map: $layerId for $upperStateCode');

    try {
      // Get manifest to find layer info
      final manifest = await LayerManifestService.instance.getStateManifest(upperStateCode);
      if (manifest == null) {
        return const HistoricalMapDownloadError(
          code: 'MANIFEST_NOT_FOUND',
          message: 'Could not find manifest for state',
        );
      }

      final layer = manifest.getLayer(layerId);
      if (layer == null) {
        return HistoricalMapDownloadError(
          code: 'LAYER_NOT_FOUND',
          message: 'Layer $layerId not found in manifest',
        );
      }

      if (!layer.isRasterTile) {
        return HistoricalMapDownloadError(
          code: 'INVALID_LAYER_TYPE',
          message: 'Layer $layerId is not a raster tile layer',
        );
      }

      // Get API credentials
      final apiKey = await DeviceRegistrationService.instance.getApiKey();
      final deviceId = await DeviceRegistrationService.instance.getDeviceId();

      if (apiKey == null || deviceId == null) {
        return const HistoricalMapDownloadError(
          code: 'NOT_REGISTERED',
          message: 'Device not registered',
        );
      }

      // Knock NHP server for access
      final nhpService = NhpDownloadService.instance;
      if (nhpService.isNhpDownloadsEnabled) {
        final knockResult = await nhpService.knockForDownloads(
          deviceId: deviceId,
          apiKey: apiKey,
        );

        if (!knockResult.success) {
          return HistoricalMapDownloadError(
            code: 'NHP_KNOCK_FAILED',
            message: knockResult.errorMessage ?? 'Premium subscription required',
          );
        }
      }

      // Build download URL - use NHP downloads server, not API server
      // MBTiles files are served from downloads.obsessiontracker.com
      final downloadUrl = nhpService.isNhpDownloadsEnabled
          ? 'https://downloads.obsessiontracker.com/states/$upperStateCode/${layer.file}'
          : '${BFFConfig.productionEndpoint}/api/v1/downloads/states/$upperStateCode/${layer.file}';

      // Create temp file for download
      final filePath = await _getMBTilesPath(upperStateCode, layerId);
      final tempPath = '$filePath.tmp';
      final tempFile = File(tempPath);

      // Download with progress
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['X-API-Key'] = apiKey;

      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        return HistoricalMapDownloadError(
          code: 'DOWNLOAD_FAILED',
          message: 'Server returned ${response.statusCode}',
        );
      }

      final totalBytes = response.contentLength ?? layer.size;
      int receivedBytes = 0;

      final sink = tempFile.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress?.call(receivedBytes, totalBytes);
      }
      await sink.close();

      // Move temp file to final location
      final finalFile = File(filePath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(filePath);

      // Record download
      final downloadedMap = DownloadedHistoricalMap(
        stateCode: upperStateCode,
        layerId: layerId,
        name: layer.name,
        era: layer.era,
        filePath: filePath,
        sizeBytes: receivedBytes,
        downloadedAt: DateTime.now(),
      );

      final key = '${upperStateCode}_$layerId';
      _downloadedMaps[key] = downloadedMap;
      await _saveDownloadedMaps();

      debugPrint('🗺️ Downloaded $layerId for $upperStateCode: ${receivedBytes ~/ 1024}KB');

      return HistoricalMapDownloadSuccess(
        stateCode: upperStateCode,
        layerId: layerId,
        filePath: filePath,
        sizeBytes: receivedBytes,
      );
    } catch (e) {
      debugPrint('🗺️ Download error: $e');
      return HistoricalMapDownloadError(
        code: 'DOWNLOAD_ERROR',
        message: e.toString(),
      );
    }
  }

  /// Delete a downloaded historical map layer
  Future<void> deleteLayer(String stateCode, String layerId) async {
    await initialize();

    final key = '${stateCode.toUpperCase()}_$layerId';
    final info = _downloadedMaps[key];

    if (info != null) {
      // Delete file
      final file = File(info.filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗺️ Deleted ${info.filePath}');
      }

      // Remove from tracking
      _downloadedMaps.remove(key);
      await _saveDownloadedMaps();
    }
  }

  /// Delete all historical maps for a state
  Future<void> deleteStateData(String stateCode) async {
    await initialize();

    final upperStateCode = stateCode.toUpperCase();
    final keysToDelete = _downloadedMaps.keys
        .where((k) => k.startsWith('${upperStateCode}_'))
        .toList();

    for (final key in keysToDelete) {
      final info = _downloadedMaps[key];
      if (info != null) {
        final file = File(info.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _downloadedMaps.remove(key);
    }

    await _saveDownloadedMaps();
    debugPrint('🗺️ Deleted all historical maps for $upperStateCode');
  }

  /// Get the file path for a downloaded layer (for Mapbox rendering)
  Future<String?> getLayerFilePath(String stateCode, String layerId) async {
    await initialize();

    final key = '${stateCode.toUpperCase()}_$layerId';
    final info = _downloadedMaps[key];

    if (info != null && File(info.filePath).existsSync()) {
      return info.filePath;
    }
    return null;
  }

  /// Read bounds from an MBTiles file's metadata table
  /// Returns null if bounds cannot be read
  Future<HistoricalMapBounds?> getBoundsForLayer(
    String stateCode,
    String layerId,
  ) async {
    debugPrint('🗺️ getBoundsForLayer: stateCode=$stateCode, layerId=$layerId');
    final filePath = await getLayerFilePath(stateCode, layerId);
    debugPrint('🗺️ getBoundsForLayer: filePath=$filePath');
    if (filePath == null) {
      debugPrint('🗺️ getBoundsForLayer: filePath is null, returning null');
      return null;
    }

    return getBoundsFromMBTiles(filePath);
  }

  /// Read bounds from an MBTiles file path
  Future<HistoricalMapBounds?> getBoundsFromMBTiles(String filePath) async {
    try {
      // Use singleInstance: false to create a separate connection that doesn't
      // interfere with the tile server's database connection
      final db = await openDatabase(
        filePath,
        readOnly: true,
        singleInstance: false,
      );

      try {
        // Read metadata table for bounds and center
        final result = await db.query('metadata');

        String? boundsStr;
        String? centerStr;

        for (final row in result) {
          final name = row['name'] as String?;
          final value = row['value'] as String?;
          if (name == 'bounds') boundsStr = value;
          if (name == 'center') centerStr = value;
        }

        final bounds = HistoricalMapBounds.fromBoundsString(
          boundsStr,
          centerStr: centerStr,
        );

        if (bounds != null) {
          debugPrint('🗺️ Read bounds from MBTiles: $bounds');
        }

        return bounds;
      } finally {
        await db.close();
      }
    } catch (e) {
      debugPrint('🗺️ Error reading bounds from MBTiles: $e');
      return null;
    }
  }

  /// Load downloaded maps from SharedPreferences
  Future<void> _loadDownloadedMaps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_downloadedMapsKey) ?? [];

      _downloadedMaps.clear();
      for (final jsonStr in jsonList) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final map = DownloadedHistoricalMap.fromJson(json);
          final key = '${map.stateCode}_${map.layerId}';
          _downloadedMaps[key] = map;
        } catch (e) {
          debugPrint('🗺️ Error parsing map entry: $e');
        }
      }
    } catch (e) {
      debugPrint('🗺️ Error loading downloaded maps: $e');
    }
  }

  /// Save downloaded maps to SharedPreferences
  Future<void> _saveDownloadedMaps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _downloadedMaps.values
          .map((m) => jsonEncode(m.toJson()))
          .toList();
      await prefs.setStringList(_downloadedMapsKey, jsonList);
    } catch (e) {
      debugPrint('🗺️ Error saving downloaded maps: $e');
    }
  }
}
