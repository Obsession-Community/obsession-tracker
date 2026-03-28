import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

/// Result of a GPX export operation
class GpxExportResult {
  final bool success;
  final String? filePath;
  final String? errorMessage;
  final int? fileSize;

  const GpxExportResult({
    required this.success,
    this.filePath,
    this.errorMessage,
    this.fileSize,
  });

  factory GpxExportResult.success(String filePath, int fileSize) =>
      GpxExportResult(
        success: true,
        filePath: filePath,
        fileSize: fileSize,
      );

  factory GpxExportResult.failure(String errorMessage) => GpxExportResult(
        success: false,
        errorMessage: errorMessage,
      );
}

/// Service for exporting tracking sessions to GPX format.
///
/// GPX (GPS Exchange Format) is the standard XML format for GPS data.
/// Compatible with:
/// - Gaia GPS
/// - AllTrails
/// - Garmin devices
/// - Google Earth
/// - Most GPS apps and devices
///
/// Exports:
/// - Session track (breadcrumbs as track points)
/// - Waypoints (with names and descriptions)
/// - Session metadata (name, description, time)
/// - Elevation data (when available)
///
/// Does NOT export (GPX limitations):
/// - Photos (use .obstrack for complete backup)
/// - Voice notes
/// - Custom waypoint metadata
class SessionGpxExportService {
  final DatabaseService _databaseService = DatabaseService();

  /// Export a session to GPX format
  ///
  /// [sessionId] - ID of session to export
  /// [outputDirectory] - Optional directory (defaults to Downloads/Obsession)
  /// [includeWaypoints] - Include waypoints in GPX (default: true)
  ///
  /// Returns [GpxExportResult] with file path or error
  Future<GpxExportResult> exportSession({
    required String sessionId,
    String? outputDirectory,
    bool includeWaypoints = true,
  }) async {
    try {
      debugPrint('📍 Starting GPX export for session: $sessionId');

      // 1. Load session data from database
      final session = await _databaseService.getSession(sessionId);
      if (session == null) {
        return GpxExportResult.failure('Session not found: $sessionId');
      }

      final breadcrumbs =
          await _databaseService.getBreadcrumbsForSession(sessionId);
      if (breadcrumbs.isEmpty) {
        return GpxExportResult.failure('Session has no track data to export');
      }

      List<Waypoint> waypoints = [];
      if (includeWaypoints) {
        waypoints =
            await _databaseService.getWaypointsForSession(sessionId);
      }

      // 2. Build GPX XML
      final gpxXml = _buildGpxXml(session, breadcrumbs, waypoints);

      // 3. Write to file
      final outputPath = await _writeGpxFile(
        session,
        gpxXml,
        outputDirectory,
      );

      final fileSize = File(outputPath).lengthSync();
      debugPrint('✅ GPX export complete: $outputPath ($fileSize bytes)');
      debugPrint('   Exported: ${breadcrumbs.length} track points, ${waypoints.length} waypoints');

      return GpxExportResult.success(outputPath, fileSize);
    } catch (e, stack) {
      debugPrint('❌ GPX export failed: $e');
      debugPrint('Stack: $stack');
      return GpxExportResult.failure('Export failed: $e');
    }
  }

  /// Build GPX XML document
  String _buildGpxXml(
    TrackingSession session,
    List<Breadcrumb> breadcrumbs,
    List<Waypoint> waypoints,
  ) {
    final builder = XmlBuilder();

    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('gpx', nest: () {
      // GPX attributes
      builder.attribute('version', '1.1');
      builder.attribute('creator', 'Obsession Tracker');
      builder.attribute(
        'xmlns',
        'http://www.topografix.com/GPX/1/1',
      );
      builder.attribute(
        'xmlns:xsi',
        'http://www.w3.org/2001/XMLSchema-instance',
      );
      builder.attribute(
        'xsi:schemaLocation',
        'http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd',
      );

      // Metadata
      builder.element('metadata', nest: () {
        builder.element('name', nest: session.name);
        if (session.description != null && session.description!.isNotEmpty) {
          builder.element('desc', nest: session.description);
        }
        builder.element('time', nest: session.createdAt.toUtc().toIso8601String());
        builder.element('author', nest: () {
          builder.element('name', nest: 'Obsession Tracker');
        });
      });

      // Waypoints
      for (final waypoint in waypoints) {
        builder.element('wpt', nest: () {
          builder.attribute('lat', waypoint.coordinates.latitude.toString());
          builder.attribute('lon', waypoint.coordinates.longitude.toString());

          // Elevation
          if (waypoint.altitude != null) {
            builder.element('ele', nest: waypoint.altitude.toString());
          }

          // Time
          builder.element('time', nest: waypoint.timestamp.toUtc().toIso8601String());

          // Name (use custom name or type)
          final name = waypoint.name ?? waypoint.type.displayName;
          builder.element('name', nest: name);

          // Description (notes)
          if (waypoint.notes != null && waypoint.notes!.isNotEmpty) {
            builder.element('desc', nest: waypoint.notes);
          }

          // Waypoint type/symbol
          builder.element('type', nest: waypoint.type.name);
          builder.element('sym', nest: _getGpxSymbol(waypoint.type));
        });
      }

      // Track
      builder.element('trk', nest: () {
        builder.element('name', nest: '${session.name} Track');
        if (session.description != null && session.description!.isNotEmpty) {
          builder.element('desc', nest: session.description);
        }

        // Track segment
        builder.element('trkseg', nest: () {
          for (final breadcrumb in breadcrumbs) {
            builder.element('trkpt', nest: () {
              builder.attribute('lat', breadcrumb.coordinates.latitude.toString());
              builder.attribute('lon', breadcrumb.coordinates.longitude.toString());

              // Elevation
              if (breadcrumb.altitude != null) {
                builder.element('ele', nest: breadcrumb.altitude.toString());
              }

              // Time
              builder.element('time', nest: breadcrumb.timestamp.toUtc().toIso8601String());

              // Extensions for additional data
              if (breadcrumb.speed != null || breadcrumb.heading != null) {
                builder.element('extensions', nest: () {
                  if (breadcrumb.speed != null) {
                    builder.element('speed', nest: breadcrumb.speed.toString());
                  }
                  if (breadcrumb.heading != null) {
                    builder.element('course', nest: breadcrumb.heading.toString());
                  }
                  builder.element('hdop', nest: (breadcrumb.accuracy / 5).toStringAsFixed(1));
                });
              }
            });
          }
        });
      });
    });

    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  /// Get GPX symbol for waypoint type
  String _getGpxSymbol(WaypointType type) {
    // Map waypoint types to standard GPX symbols
    switch (type) {
      case WaypointType.camp:
        return 'Campground';
      case WaypointType.viewpoint:
        return 'Scenic Area';
      case WaypointType.landmark:
        return 'Summit';
      case WaypointType.waterfall:
        return 'Water Source';
      case WaypointType.cave:
        return 'Geocache';
      case WaypointType.fishing:
        return 'Fishing Area';
      case WaypointType.hunting:
        return 'Hunting Area';
      case WaypointType.parking:
        return 'Parking Area';
      case WaypointType.restroom:
        return 'Restroom';
      case WaypointType.shelter:
        return 'Shelter';
      case WaypointType.waterSource:
        return 'Water Source';
      case WaypointType.restaurant:
        return 'Restaurant';
      case WaypointType.lodging:
        return 'Lodging';
      case WaypointType.warning:
        return 'Danger Area';
      case WaypointType.danger:
        return 'Danger Area';
      case WaypointType.emergency:
        return 'Medical Facility';
      case WaypointType.firstAid:
        return 'Medical Facility';
      case WaypointType.photo:
        return 'Photo';
      case WaypointType.hiking:
        return 'Trail Head';
      case WaypointType.bridge:
        return 'Bridge';
      default:
        return 'Pin, Blue';
    }
  }

  /// Write GPX XML to file
  Future<String> _writeGpxFile(
    TrackingSession session,
    String gpxXml,
    String? outputDirectory,
  ) async {
    // Determine output directory
    Directory outputDir;
    if (outputDirectory != null) {
      outputDir = Directory(outputDirectory);
    } else {
      // Use app's documents directory for exports (works on both iOS and Android)
      // Files are shared via the share sheet, not saved to a user-visible location
      final documentsDir = await getApplicationDocumentsDirectory();
      outputDir = Directory('${documentsDir.path}/exports');
    }

    // Create directory if it doesn't exist
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    // Generate filename: session_name_YYYY-MM-DD.gpx
    final timestamp = session.createdAt.toIso8601String().split('T')[0];
    final safeName = session.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');
    final filename = '${safeName}_$timestamp.gpx';
    final filePath = '${outputDir.path}/$filename';

    // Write file
    final file = File(filePath);
    await file.writeAsString(gpxXml);

    return filePath;
  }
}
