import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:obsession_tracker/core/config/bff_config.dart';
import 'package:obsession_tracker/core/models/quadrangle_manifest.dart';
import 'package:obsession_tracker/core/services/device_registration_service.dart';
import 'package:obsession_tracker/core/services/nhp_download_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of a quadrangle download operation
sealed class QuadrangleDownloadResult {
  const QuadrangleDownloadResult();
}

/// Successful download
class QuadrangleDownloadSuccess extends QuadrangleDownloadResult {
  const QuadrangleDownloadSuccess({
    required this.stateCode,
    required this.eraId,
    required this.quadId,
    required this.filePath,
    required this.sizeBytes,
  });

  final String stateCode;
  final String eraId;
  final String quadId;
  final String filePath;
  final int sizeBytes;
}

/// Download error
class QuadrangleDownloadError extends QuadrangleDownloadResult {
  const QuadrangleDownloadError({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;
}

/// Information about a downloaded quadrangle
class DownloadedQuadrangle {
  const DownloadedQuadrangle({
    required this.stateCode,
    required this.eraId,
    required this.quadId,
    required this.name,
    required this.filePath,
    required this.sizeBytes,
    required this.bounds,
    required this.year,
    required this.downloadedAt,
  });

  final String stateCode;
  final String eraId;
  final String quadId;
  final String name;
  final String filePath;
  final int sizeBytes;
  final QuadrangleBounds bounds;
  final int year;
  final DateTime downloadedAt;

  String get key => '${stateCode}_${eraId}_$quadId';

  Map<String, dynamic> toJson() => {
        'stateCode': stateCode,
        'eraId': eraId,
        'quadId': quadId,
        'name': name,
        'filePath': filePath,
        'sizeBytes': sizeBytes,
        'bounds': bounds.toJson(),
        'year': year,
        'downloadedAt': downloadedAt.toIso8601String(),
      };

  factory DownloadedQuadrangle.fromJson(Map<String, dynamic> json) {
    return DownloadedQuadrangle(
      stateCode: json['stateCode'] as String,
      eraId: json['eraId'] as String,
      quadId: json['quadId'] as String,
      name: json['name'] as String,
      filePath: json['filePath'] as String,
      sizeBytes: json['sizeBytes'] as int,
      bounds: QuadrangleBounds.fromJson(json['bounds'] as Map<String, dynamic>),
      year: json['year'] as int,
      downloadedAt: DateTime.parse(json['downloadedAt'] as String),
    );
  }
}

/// Service for downloading and managing individual historical map quadrangles.
///
/// This service provides granular control over which map areas are downloaded,
/// as opposed to the HistoricalMapsService which downloads entire state layers.
class QuadrangleDownloadService {
  QuadrangleDownloadService._();
  static final QuadrangleDownloadService instance = QuadrangleDownloadService._();

  static const String _downloadedQuadsKey = 'downloaded_quadrangles';
  static const Duration _manifestCacheDuration = Duration(hours: 1);

  bool _initialized = false;
  final Map<String, DownloadedQuadrangle> _downloadedQuads = {};
  final Map<String, StateQuadrangleManifest> _manifestCache = {};
  final Map<String, DateTime> _manifestCacheTime = {};

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('📍 QuadrangleDownloadService already initialized with ${_downloadedQuads.length} quads');
      return;
    }

    debugPrint('📍 QuadrangleDownloadService initializing...');
    await _loadDownloadedQuads();
    _initialized = true;
    debugPrint('📍 QuadrangleDownloadService initialized with ${_downloadedQuads.length} quads');
  }

  /// Get directory for storing quadrangle MBTiles
  Future<Directory> _getQuadranglesDirectory(
    String stateCode,
    String eraId,
  ) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/historical_maps/$stateCode/$eraId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Fetch quadrangle manifest for a state
  Future<StateQuadrangleManifest?> getQuadrangleManifest(
    String stateCode, {
    bool forceRefresh = false,
  }) async {
    await initialize();

    final upperState = stateCode.toUpperCase();

    // Check cache
    if (!forceRefresh && _manifestCache.containsKey(upperState)) {
      final cacheTime = _manifestCacheTime[upperState];
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime) < _manifestCacheDuration) {
        return _manifestCache[upperState];
      }
    }

    try {
      const baseUrl = BFFConfig.productionEndpoint;
      final uri = Uri.parse('$baseUrl/api/v1/downloads/states/$upperState/maps/manifest');

      final apiKey = await DeviceRegistrationService.instance.getApiKey();
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (apiKey != null) 'X-API-Key': apiKey,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final manifest = StateQuadrangleManifest.fromJson(json);
        _manifestCache[upperState] = manifest;
        _manifestCacheTime[upperState] = DateTime.now();
        debugPrint('📍 Fetched quadrangle manifest for $upperState: ${manifest.totalQuadrangleCount} quads');
        return manifest;
      } else if (response.statusCode == 404) {
        debugPrint('📍 No quadrangles available for $upperState');
        return null;
      } else {
        debugPrint('📍 Error fetching manifest: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('📍 Error fetching quadrangle manifest: $e');
      return null;
    }
  }

  /// Check if a specific quadrangle is downloaded
  bool isQuadrangleDownloaded(String stateCode, String eraId, String quadId) {
    final key = '${stateCode.toUpperCase()}_${eraId}_$quadId';
    final downloaded = _downloadedQuads[key];

    if (downloaded == null) {
      return false;
    }

    // Verify file still exists
    if (!File(downloaded.filePath).existsSync()) {
      _downloadedQuads.remove(key);
      _saveDownloadedQuads();
      return false;
    }

    return true;
  }

  /// Get all downloaded quadrangles
  List<DownloadedQuadrangle> getDownloadedQuadrangles() {
    // Verify files still exist
    final validQuads = <DownloadedQuadrangle>[];
    final staleKeys = <String>[];

    for (final entry in _downloadedQuads.entries) {
      if (File(entry.value.filePath).existsSync()) {
        validQuads.add(entry.value);
      } else {
        staleKeys.add(entry.key);
      }
    }

    if (staleKeys.isNotEmpty) {
      staleKeys.forEach(_downloadedQuads.remove);
      _saveDownloadedQuads();
    }

    return validQuads;
  }

  /// Get downloaded quadrangles for a specific state
  List<DownloadedQuadrangle> getDownloadedQuadranglesForState(String stateCode) {
    return getDownloadedQuadrangles()
        .where((q) => q.stateCode == stateCode.toUpperCase())
        .toList();
  }

  /// Get downloaded quadrangles for a specific state and era
  List<DownloadedQuadrangle> getDownloadedQuadranglesForEra(
    String stateCode,
    String eraId,
  ) {
    return getDownloadedQuadrangles()
        .where((q) =>
            q.stateCode == stateCode.toUpperCase() && q.eraId == eraId)
        .toList();
  }

  /// Find downloaded quadrangles that cover a specific point
  List<DownloadedQuadrangle> findQuadranglesAtLocation(double lat, double lng) {
    return getDownloadedQuadrangles()
        .where((q) => q.bounds.containsPoint(lat, lng))
        .toList();
  }

  /// Find downloaded quadrangles that intersect a bounding box
  List<DownloadedQuadrangle> findQuadranglesInBounds(QuadrangleBounds bounds) {
    return getDownloadedQuadrangles()
        .where((q) => q.bounds.intersects(bounds))
        .toList();
  }

  /// Get total storage used by downloaded quadrangles
  int getTotalStorageUsed() {
    return getDownloadedQuadrangles().fold(0, (sum, q) => sum + q.sizeBytes);
  }

  /// Get storage used by quadrangles for a specific state
  int getStorageUsedForState(String stateCode) {
    return getDownloadedQuadranglesForState(stateCode)
        .fold(0, (sum, q) => sum + q.sizeBytes);
  }

  /// Download a single quadrangle
  Future<QuadrangleDownloadResult> downloadQuadrangle({
    required String stateCode,
    required String eraId,
    required QuadrangleManifest quad,
    void Function(int bytesReceived, int totalBytes)? onProgress,
  }) async {
    await initialize();

    final upperState = stateCode.toUpperCase();
    debugPrint('📍 Downloading quadrangle: ${quad.name} ($eraId) for $upperState');

    try {
      // Get API credentials
      final apiKey = await DeviceRegistrationService.instance.getApiKey();
      final deviceId = await DeviceRegistrationService.instance.getDeviceId();

      if (apiKey == null || deviceId == null) {
        return const QuadrangleDownloadError(
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
          return QuadrangleDownloadError(
            code: 'NHP_KNOCK_FAILED',
            message: knockResult.errorMessage ?? 'Premium subscription required',
          );
        }
      }

      // Build download URL
      final downloadUrl = nhpService.isNhpDownloadsEnabled
          ? 'https://downloads.obsessiontracker.com/states/$upperState/${quad.file}'
          : '${BFFConfig.productionEndpoint}/api/v1/downloads/states/$upperState/${quad.file}';

      // Create output path
      final dir = await _getQuadranglesDirectory(upperState, eraId);
      final filePath = '${dir.path}/${quad.id}.mbtiles';
      final tempPath = '$filePath.tmp';
      final tempFile = File(tempPath);

      // Download with progress
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['X-API-Key'] = apiKey;

      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        return QuadrangleDownloadError(
          code: 'DOWNLOAD_FAILED',
          message: 'Server returned ${response.statusCode}',
        );
      }

      final totalBytes = response.contentLength ?? quad.size;
      int receivedBytes = 0;

      final sink = tempFile.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress?.call(receivedBytes, totalBytes);
      }
      await sink.close();

      // Move to final location
      final finalFile = File(filePath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(filePath);

      // Record download
      final downloaded = DownloadedQuadrangle(
        stateCode: upperState,
        eraId: eraId,
        quadId: quad.id,
        name: quad.name,
        filePath: filePath,
        sizeBytes: receivedBytes,
        bounds: quad.bounds,
        year: quad.year,
        downloadedAt: DateTime.now(),
      );

      debugPrint('📍 Recording download with key: ${downloaded.key}');
      _downloadedQuads[downloaded.key] = downloaded;
      debugPrint('📍 _downloadedQuads now has ${_downloadedQuads.length} entries');
      await _saveDownloadedQuads();

      debugPrint('📍 Downloaded ${quad.name}: ${receivedBytes ~/ 1024}KB to $filePath');

      return QuadrangleDownloadSuccess(
        stateCode: upperState,
        eraId: eraId,
        quadId: quad.id,
        filePath: filePath,
        sizeBytes: receivedBytes,
      );
    } catch (e) {
      debugPrint('📍 Download error: $e');
      return QuadrangleDownloadError(
        code: 'DOWNLOAD_ERROR',
        message: e.toString(),
      );
    }
  }

  /// Download multiple quadrangles with batch progress
  Future<List<QuadrangleDownloadResult>> downloadQuadrangles({
    required String stateCode,
    required String eraId,
    required List<QuadrangleManifest> quads,
    void Function(int completed, int total, String currentQuadName)? onBatchProgress,
    void Function(int bytesReceived, int totalBytes)? onQuadProgress,
  }) async {
    final results = <QuadrangleDownloadResult>[];

    for (int i = 0; i < quads.length; i++) {
      final quad = quads[i];
      onBatchProgress?.call(i, quads.length, quad.name);

      final result = await downloadQuadrangle(
        stateCode: stateCode,
        eraId: eraId,
        quad: quad,
        onProgress: onQuadProgress,
      );

      results.add(result);
    }

    onBatchProgress?.call(quads.length, quads.length, 'Complete');
    return results;
  }

  /// Delete a downloaded quadrangle
  Future<void> deleteQuadrangle(
    String stateCode,
    String eraId,
    String quadId,
  ) async {
    await initialize();

    final key = '${stateCode.toUpperCase()}_${eraId}_$quadId';
    final quad = _downloadedQuads[key];

    if (quad != null) {
      final file = File(quad.filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('📍 Deleted quadrangle: ${quad.name}');
      }
      _downloadedQuads.remove(key);
      await _saveDownloadedQuads();
    }
  }

  /// Delete all quadrangles for a state and era
  Future<void> deleteEraQuadrangles(String stateCode, String eraId) async {
    await initialize();

    final upperState = stateCode.toUpperCase();
    final quadsToDelete = _downloadedQuads.entries
        .where((e) => e.value.stateCode == upperState && e.value.eraId == eraId)
        .toList();

    for (final entry in quadsToDelete) {
      final file = File(entry.value.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      _downloadedQuads.remove(entry.key);
    }

    await _saveDownloadedQuads();
    debugPrint('📍 Deleted ${quadsToDelete.length} quadrangles for $upperState/$eraId');
  }

  /// Delete all quadrangles for a state
  Future<void> deleteStateQuadrangles(String stateCode) async {
    await initialize();

    final upperState = stateCode.toUpperCase();
    final quadsToDelete = _downloadedQuads.entries
        .where((e) => e.value.stateCode == upperState)
        .toList();

    for (final entry in quadsToDelete) {
      final file = File(entry.value.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      _downloadedQuads.remove(entry.key);
    }

    await _saveDownloadedQuads();
    debugPrint('📍 Deleted ${quadsToDelete.length} quadrangles for $upperState');
  }

  /// Get file path for a downloaded quadrangle (for tile server registration)
  String? getQuadrangleFilePath(String stateCode, String eraId, String quadId) {
    final key = '${stateCode.toUpperCase()}_${eraId}_$quadId';
    final quad = _downloadedQuads[key];

    if (quad != null && File(quad.filePath).existsSync()) {
      return quad.filePath;
    }
    return null;
  }

  /// Clear the manifest cache to force fresh fetches from server
  ///
  /// Call this when the user manually refreshes or when server-side
  /// manifest regeneration is expected.
  void clearManifestCache() {
    _manifestCache.clear();
    _manifestCacheTime.clear();
    debugPrint('📍 Cleared quadrangle manifest cache');
  }

  /// Clear manifest cache for a specific state
  void clearManifestCacheForState(String stateCode) {
    final upperState = stateCode.toUpperCase();
    _manifestCache.remove(upperState);
    _manifestCacheTime.remove(upperState);
    debugPrint('📍 Cleared manifest cache for $upperState');
  }

  /// Get download status summary for a state
  Future<QuadrangleDownloadSummary> getDownloadSummary(String stateCode) async {
    await initialize();

    final manifest = await getQuadrangleManifest(stateCode);
    final downloaded = getDownloadedQuadranglesForState(stateCode);

    if (manifest == null) {
      return QuadrangleDownloadSummary(
        stateCode: stateCode.toUpperCase(),
        totalAvailableQuads: 0,
        downloadedQuads: downloaded.length,
        totalAvailableSize: 0,
        downloadedSize: downloaded.fold(0, (sum, q) => sum + q.sizeBytes),
        eras: [],
      );
    }

    final eraSummaries = <EraDownloadSummary>[];
    for (final era in manifest.eras) {
      final downloadedForEra = downloaded.where((q) => q.eraId == era.id).toList();
      eraSummaries.add(EraDownloadSummary(
        eraId: era.id,
        eraName: era.name,
        totalQuads: era.quadrangleCount,
        downloadedQuads: downloadedForEra.length,
        totalSize: era.totalSize,
        downloadedSize: downloadedForEra.fold(0, (sum, q) => sum + q.sizeBytes),
      ));
    }

    return QuadrangleDownloadSummary(
      stateCode: stateCode.toUpperCase(),
      totalAvailableQuads: manifest.totalQuadrangleCount,
      downloadedQuads: downloaded.length,
      totalAvailableSize: manifest.totalSize,
      downloadedSize: downloaded.fold(0, (sum, q) => sum + q.sizeBytes),
      eras: eraSummaries,
    );
  }

  /// Register a test quadrangle (for integration tests with fixture data)
  /// This allows tests to register MBTiles files from fixtures as if they were downloaded
  Future<void> registerTestQuadrangle({
    required String stateCode,
    required String eraId,
    required String quadId,
    required String name,
    required String filePath,
    required int sizeBytes,
    required QuadrangleBounds bounds,
    required int year,
  }) async {
    await initialize();

    final downloaded = DownloadedQuadrangle(
      stateCode: stateCode.toUpperCase(),
      eraId: eraId,
      quadId: quadId,
      name: name,
      filePath: filePath,
      sizeBytes: sizeBytes,
      bounds: bounds,
      year: year,
      downloadedAt: DateTime.now(),
    );

    _downloadedQuads[downloaded.key] = downloaded;
    await _saveDownloadedQuads();
    debugPrint('📍 Registered test quadrangle: ${downloaded.key} at $filePath');
  }

  // Persistence methods

  Future<void> _loadDownloadedQuads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_downloadedQuadsKey) ?? [];
      debugPrint('📍 _loadDownloadedQuads: Found ${jsonList.length} entries in SharedPreferences');

      _downloadedQuads.clear();
      for (final jsonStr in jsonList) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final quad = DownloadedQuadrangle.fromJson(json);
          _downloadedQuads[quad.key] = quad;
          debugPrint('📍 _loadDownloadedQuads: Loaded ${quad.key} -> ${quad.filePath}');
        } catch (e) {
          debugPrint('📍 Error parsing quad entry: $e');
          debugPrint('📍   JSON was: $jsonStr');
        }
      }
      debugPrint('📍 _loadDownloadedQuads: Total loaded: ${_downloadedQuads.length}');
    } catch (e) {
      debugPrint('📍 Error loading downloaded quads: $e');
    }
  }

  Future<void> _saveDownloadedQuads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _downloadedQuads.values
          .map((q) => jsonEncode(q.toJson()))
          .toList();
      debugPrint('📍 _saveDownloadedQuads: Saving ${jsonList.length} quads to SharedPreferences');
      for (final q in _downloadedQuads.values) {
        debugPrint('📍   Saving: ${q.key} -> ${q.filePath}');
      }
      await prefs.setStringList(_downloadedQuadsKey, jsonList);
      debugPrint('📍 _saveDownloadedQuads: Save complete');
    } catch (e) {
      debugPrint('📍 Error saving downloaded quads: $e');
    }
  }
}

/// Summary of download status for a state
class QuadrangleDownloadSummary {
  const QuadrangleDownloadSummary({
    required this.stateCode,
    required this.totalAvailableQuads,
    required this.downloadedQuads,
    required this.totalAvailableSize,
    required this.downloadedSize,
    required this.eras,
  });

  final String stateCode;
  final int totalAvailableQuads;
  final int downloadedQuads;
  final int totalAvailableSize;
  final int downloadedSize;
  final List<EraDownloadSummary> eras;

  double get downloadProgress {
    if (totalAvailableQuads == 0) return 0.0;
    return downloadedQuads / totalAvailableQuads;
  }

  bool get hasDownloads => downloadedQuads > 0;
  bool get isComplete => downloadedQuads >= totalAvailableQuads;
}

/// Summary of download status for an era
class EraDownloadSummary {
  const EraDownloadSummary({
    required this.eraId,
    required this.eraName,
    required this.totalQuads,
    required this.downloadedQuads,
    required this.totalSize,
    required this.downloadedSize,
  });

  final String eraId;
  final String eraName;
  final int totalQuads;
  final int downloadedQuads;
  final int totalSize;
  final int downloadedSize;

  double get downloadProgress {
    if (totalQuads == 0) return 0.0;
    return downloadedQuads / totalQuads;
  }

  bool get hasDownloads => downloadedQuads > 0;
  bool get isComplete => downloadedQuads >= totalQuads;
}
