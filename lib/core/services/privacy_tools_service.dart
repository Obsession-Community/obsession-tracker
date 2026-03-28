import 'dart:io';
import 'dart:math';

import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:obsession_tracker/core/models/security_models.dart';

/// Privacy tools service for location fuzzing, EXIF stripping, and data anonymization
class PrivacyToolsService {
  factory PrivacyToolsService() => _instance ??= PrivacyToolsService._();
  PrivacyToolsService._();
  static PrivacyToolsService? _instance;

  // Privacy settings
  PrivacyToolsSettings _settings = const PrivacyToolsSettings();
  final Random _random = Random.secure();

  /// Initialize the privacy tools service
  Future<void> initialize(PrivacyToolsSettings settings) async {
    try {
      _settings = settings;
      debugPrint('Privacy tools service initialized');
    } catch (e) {
      debugPrint('Error initializing privacy tools service: $e');
      rethrow;
    }
  }

  /// Update privacy settings
  void updateSettings(PrivacyToolsSettings settings) {
    _settings = settings;
    debugPrint('Privacy tools settings updated');
  }

  /// Apply location fuzzing to coordinates
  Map<String, double> fuzzLocation(double latitude, double longitude) {
    if (!_settings.enableLocationFuzzing) {
      return {'latitude': latitude, 'longitude': longitude};
    }

    final radiusMeters = _settings.locationFuzzingLevel.radiusMeters;
    if (radiusMeters == 0) {
      return {'latitude': latitude, 'longitude': longitude};
    }

    // Generate random offset within the specified radius
    final angle = _random.nextDouble() * 2 * pi;
    final distance = _random.nextDouble() * radiusMeters;

    // Convert distance to degrees (approximate)
    final latOffset =
        (distance / 111320) * cos(angle); // 1 degree lat ≈ 111.32 km
    final lonOffset =
        (distance / (111320 * cos(latitude * pi / 180))) * sin(angle);

    final fuzzedLatitude = latitude + latOffset;
    final fuzzedLongitude = longitude + lonOffset;

    debugPrint('Location fuzzed by ${distance.toStringAsFixed(1)}m');

    return {
      'latitude': fuzzedLatitude,
      'longitude': fuzzedLongitude,
    };
  }

  /// Strip EXIF data from image file
  Future<bool> stripExifFromFile(String filePath) async {
    if (!_settings.enableExifStripping) return true;

    try {
      final file = File(filePath);
      if (!file.existsSync()) return false;

      // Read the image
      final imageBytes = await file.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) return false;

      // Re-encode the image without EXIF data
      Uint8List cleanImageBytes;
      final extension = filePath.toLowerCase().split('.').last;

      switch (extension) {
        case 'jpg':
        case 'jpeg':
          cleanImageBytes =
              Uint8List.fromList(img.encodeJpg(image, quality: 95));
          break;
        case 'png':
          cleanImageBytes = Uint8List.fromList(img.encodePng(image));
          break;
        default:
          // For unsupported formats (including webp), re-encode as JPEG
          cleanImageBytes =
              Uint8List.fromList(img.encodeJpg(image, quality: 95));
          break;
      }

      // Write the clean image back to file
      await file.writeAsBytes(cleanImageBytes);

      debugPrint('EXIF data stripped from: $filePath');
      return true;
    } catch (e) {
      debugPrint('Error stripping EXIF from $filePath: $e');
      return false;
    }
  }

  /// Strip EXIF data from image bytes
  Future<Uint8List?> stripExifFromBytes(
      Uint8List imageBytes, String format) async {
    if (!_settings.enableExifStripping) return imageBytes;

    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Re-encode the image without EXIF data
      switch (format.toLowerCase()) {
        case 'jpg':
        case 'jpeg':
          return Uint8List.fromList(img.encodeJpg(image, quality: 95));
        case 'png':
          return Uint8List.fromList(img.encodePng(image));
        default:
          // For unsupported formats (including webp), re-encode as JPEG
          return Uint8List.fromList(img.encodeJpg(image, quality: 95));
      }
    } catch (e) {
      debugPrint('Error stripping EXIF from bytes: $e');
      return null;
    }
  }

  /// Get EXIF data from image file
  Future<Map<String, dynamic>?> getExifData(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;

      final imageBytes = await file.readAsBytes();
      final exifData = await readExifFromBytes(imageBytes);

      if (exifData.isEmpty) return null;

      final result = <String, dynamic>{};
      for (final entry in exifData.entries) {
        result[entry.key] = entry.value.toString();
      }

      return result;
    } catch (e) {
      debugPrint('Error reading EXIF data from $filePath: $e');
      return null;
    }
  }

  /// Check if image has location data in EXIF
  Future<bool> hasLocationData(String filePath) async {
    try {
      final exifData = await getExifData(filePath);
      if (exifData == null) return false;

      return exifData.containsKey('GPS GPSLatitude') ||
          exifData.containsKey('GPS GPSLongitude');
    } catch (e) {
      debugPrint('Error checking location data in $filePath: $e');
      return false;
    }
  }

  /// Anonymize export data
  Map<String, dynamic> anonymizeExportData(Map<String, dynamic> data) {
    if (!_settings.enableDataAnonymization) return data;

    final anonymizedData = Map<String, dynamic>.from(data);

    try {
      // Remove or anonymize sensitive fields
      _anonymizeField(anonymizedData, 'deviceId');
      _anonymizeField(anonymizedData, 'userId');
      _anonymizeField(anonymizedData, 'userName');
      _anonymizeField(anonymizedData, 'userEmail');
      _anonymizeField(anonymizedData, 'deviceName');
      _anonymizeField(anonymizedData, 'deviceModel');
      _anonymizeField(anonymizedData, 'osVersion');
      _anonymizeField(anonymizedData, 'appVersion');

      // Anonymize nested data structures
      if (anonymizedData.containsKey('sessions')) {
        final sessions = anonymizedData['sessions'] as List?;
        if (sessions != null) {
          for (final session in sessions) {
            if (session is Map<String, dynamic>) {
              _anonymizeSessionData(session);
            }
          }
        }
      }

      if (anonymizedData.containsKey('waypoints')) {
        final waypoints = anonymizedData['waypoints'] as List?;
        if (waypoints != null) {
          for (final waypoint in waypoints) {
            if (waypoint is Map<String, dynamic>) {
              _anonymizeWaypointData(waypoint);
            }
          }
        }
      }

      debugPrint('Export data anonymized');
      return anonymizedData;
    } catch (e) {
      debugPrint('Error anonymizing export data: $e');
      return data; // Return original data if anonymization fails
    }
  }

  /// Anonymize a specific field
  void _anonymizeField(Map<String, dynamic> data, String fieldName) {
    if (data.containsKey(fieldName)) {
      data[fieldName] = _generateAnonymousId();
    }
  }

  /// Anonymize session data
  void _anonymizeSessionData(Map<String, dynamic> session) {
    // Replace session name with generic name
    if (session.containsKey('name')) {
      session['name'] = 'Session ${_generateShortId()}';
    }

    // Remove or anonymize description
    if (session.containsKey('description')) {
      session['description'] = 'Anonymized session';
    }

    // Apply location fuzzing to start/end coordinates
    if (session.containsKey('startLatitude') &&
        session.containsKey('startLongitude')) {
      final fuzzed = fuzzLocation(
        session['startLatitude'] as double,
        session['startLongitude'] as double,
      );
      session['startLatitude'] = fuzzed['latitude'];
      session['startLongitude'] = fuzzed['longitude'];
    }

    if (session.containsKey('endLatitude') &&
        session.containsKey('endLongitude')) {
      final fuzzed = fuzzLocation(
        session['endLatitude'] as double,
        session['endLongitude'] as double,
      );
      session['endLatitude'] = fuzzed['latitude'];
      session['endLongitude'] = fuzzed['longitude'];
    }
  }

  /// Anonymize waypoint data
  void _anonymizeWaypointData(Map<String, dynamic> waypoint) {
    // Replace waypoint name with generic name
    if (waypoint.containsKey('name')) {
      waypoint['name'] = 'Waypoint ${_generateShortId()}';
    }

    // Remove or anonymize notes
    if (waypoint.containsKey('notes')) {
      waypoint['notes'] = 'Anonymized waypoint';
    }

    // Apply location fuzzing to coordinates
    if (waypoint.containsKey('latitude') && waypoint.containsKey('longitude')) {
      final fuzzed = fuzzLocation(
        waypoint['latitude'] as double,
        waypoint['longitude'] as double,
      );
      waypoint['latitude'] = fuzzed['latitude'];
      waypoint['longitude'] = fuzzed['longitude'];
    }
  }

  /// Generate anonymous ID
  String _generateAnonymousId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(8, (index) => chars[_random.nextInt(chars.length)])
        .join();
  }

  /// Generate short ID
  String _generateShortId() => _random.nextInt(9999).toString().padLeft(4, '0');

  /// Create selective export with privacy controls
  Map<String, dynamic> createSelectiveExport(
    Map<String, dynamic> fullData,
    SelectiveExportOptions options,
  ) {
    if (!_settings.enableSelectiveExport) return fullData;

    final selectiveData = <String, dynamic>{};

    try {
      // Include basic metadata if requested
      if (options.includeMetadata) {
        selectiveData['exportDate'] = DateTime.now().toIso8601String();
        selectiveData['exportType'] = 'selective';
        selectiveData['privacyLevel'] = _settings.locationFuzzingLevel.name;
      }

      // Include sessions if requested
      if (options.includeSessions && fullData.containsKey('sessions')) {
        final sessions = fullData['sessions'] as List?;
        if (sessions != null) {
          selectiveData['sessions'] = sessions.where((session) {
            if (session is! Map<String, dynamic>) return false;

            // Apply date range filter if specified
            if (options.dateRange != null) {
              final sessionDate =
                  DateTime.tryParse(session['createdAt'] as String? ?? '');
              if (sessionDate != null) {
                return sessionDate.isAfter(options.dateRange!.start) &&
                    sessionDate.isBefore(options.dateRange!.end);
              }
            }

            return true;
          }).toList();
        }
      }

      // Include waypoints if requested
      if (options.includeWaypoints && fullData.containsKey('waypoints')) {
        final waypoints = fullData['waypoints'] as List?;
        if (waypoints != null) {
          selectiveData['waypoints'] = waypoints.where((waypoint) {
            if (waypoint is! Map<String, dynamic>) return false;

            // Apply type filter if specified
            if (options.waypointTypes != null &&
                options.waypointTypes!.isNotEmpty) {
              final waypointType = waypoint['type'] as String?;
              return options.waypointTypes!.contains(waypointType);
            }

            return true;
          }).toList();
        }
      }

      // Include photos if requested
      if (options.includePhotos && fullData.containsKey('photos')) {
        selectiveData['photos'] = fullData['photos'];
      }

      // Include statistics if requested
      if (options.includeStatistics && fullData.containsKey('statistics')) {
        selectiveData['statistics'] = fullData['statistics'];
      }

      // Apply anonymization if enabled
      final result = _settings.enableDataAnonymization
          ? anonymizeExportData(selectiveData)
          : selectiveData;

      debugPrint(
          'Selective export created with ${result.keys.length} data types');
      return result;
    } catch (e) {
      debugPrint('Error creating selective export: $e');
      return fullData; // Return full data if selective export fails
    }
  }

  /// Clean location history based on retention settings
  Future<int> cleanLocationHistory(
      List<Map<String, dynamic>> locationHistory) async {
    if (!_settings.enableLocationHistory) return 0;

    try {
      final cutoffDate =
          DateTime.now().subtract(_settings.locationHistoryRetention);
      final originalCount = locationHistory.length;

      locationHistory.removeWhere((location) {
        final timestamp =
            DateTime.tryParse(location['timestamp'] as String? ?? '');
        return timestamp != null && timestamp.isBefore(cutoffDate);
      });

      final removedCount = originalCount - locationHistory.length;
      debugPrint('Cleaned $removedCount old location history entries');
      return removedCount;
    } catch (e) {
      debugPrint('Error cleaning location history: $e');
      return 0;
    }
  }

  /// Get privacy report
  Map<String, dynamic> getPrivacyReport() => {
        'locationFuzzing': {
          'enabled': _settings.enableLocationFuzzing,
          'level': _settings.locationFuzzingLevel.name,
          'radiusMeters': _settings.locationFuzzingLevel.radiusMeters,
        },
        'exifStripping': {
          'enabled': _settings.enableExifStripping,
        },
        'dataAnonymization': {
          'enabled': _settings.enableDataAnonymization,
        },
        'selectiveExport': {
          'enabled': _settings.enableSelectiveExport,
        },
        'locationHistory': {
          'enabled': _settings.enableLocationHistory,
          'retentionDays': _settings.locationHistoryRetention.inDays,
        },
        'analytics': {
          'usageAnalytics': _settings.enableUsageAnalytics,
          'crashReporting': _settings.enableCrashReporting,
        },
      };

  /// Dispose of the service
  void dispose() {
    _instance = null;
  }
}

/// Selective export options
class SelectiveExportOptions {
  const SelectiveExportOptions({
    this.includeMetadata = true,
    this.includeSessions = true,
    this.includeWaypoints = true,
    this.includePhotos = false,
    this.includeStatistics = true,
    this.dateRange,
    this.waypointTypes,
  });

  final bool includeMetadata;
  final bool includeSessions;
  final bool includeWaypoints;
  final bool includePhotos;
  final bool includeStatistics;
  final DateTimeRange? dateRange;
  final List<String>? waypointTypes;
}

/// Date time range for filtering
class DateTimeRange {
  const DateTimeRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;
}
