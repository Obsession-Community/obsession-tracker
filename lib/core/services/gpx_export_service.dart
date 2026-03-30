import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/desktop_file_system_service.dart';
import 'package:obsession_tracker/core/services/waypoint_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service for exporting tracking sessions to GPX format
class GpxExportService {
  factory GpxExportService() => _instance;
  GpxExportService._internal();
  static final GpxExportService _instance = GpxExportService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final WaypointService _waypointService = WaypointService.instance;

  /// Export a session to GPX format and share it (or save on desktop)
  Future<bool> exportSessionToGpx(TrackingSession session) async {
    try {
      debugPrint('Starting GPX export for session: ${session.id}');

      // Get breadcrumbs and waypoints for the session
      final breadcrumbs =
          await _databaseService.getBreadcrumbsForSession(session.id);
      final waypoints =
          await _waypointService.getWaypointsForSession(session.id);

      // Generate GPX content
      final gpxContent = _generateGpxContent(session, breadcrumbs, waypoints);

      // On desktop, use native save file dialog
      if (DesktopFileSystemService.isDesktop) {
        return await _exportToDesktop(session.name, gpxContent);
      }

      // On mobile, use share sheet
      final file = await _saveToTempFile(session.name, gpxContent);

      await SharePlus.instance.share(
        ShareParams(
          text: 'Exported tracking session from Obsession Tracker',
          files: [XFile(file.path)],
          subject: 'GPX Export: ${session.name}',
        ),
      );

      debugPrint('Successfully exported session to GPX: ${file.path}');
      return true;
    } catch (error) {
      debugPrint('Error exporting session to GPX: $error');
      return false;
    }
  }

  /// Export GPX file on desktop using native save file dialog
  Future<bool> _exportToDesktop(String sessionName, String gpxContent) async {
    try {
      final fileName = '${_sanitizeFileName(sessionName)}.gpx';

      // Use native save file dialog
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save GPX File',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['gpx'],
      );

      if (outputPath == null) {
        debugPrint('GPX export cancelled by user');
        return false;
      }

      // Ensure the file has the correct extension
      final finalPath = outputPath.endsWith('.gpx') ? outputPath : '$outputPath.gpx';

      // Write the file
      final file = File(finalPath);
      await file.writeAsString(gpxContent);

      debugPrint('Successfully exported session to GPX: $finalPath');

      // Optionally open the containing folder
      final directory = file.parent.path;
      await DesktopFileSystemService().openDirectoryInExplorer(directory);

      return true;
    } catch (error) {
      debugPrint('Error exporting GPX on desktop: $error');
      return false;
    }
  }

  /// Generate GPX XML content from session data
  String _generateGpxContent(
    TrackingSession session,
    List<Breadcrumb> breadcrumbs,
    List<Waypoint> waypoints,
  ) {
    final buffer = StringBuffer();

    // GPX header
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
        '<gpx version="1.1" creator="Obsession Tracker" xmlns="http://www.topografix.com/GPX/1/1">');

    // Metadata
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>${_escapeXml(session.name)}</name>');
    if (session.description != null) {
      buffer.writeln('    <desc>${_escapeXml(session.description!)}</desc>');
    }
    buffer.writeln(
        '    <time>${session.createdAt.toUtc().toIso8601String()}</time>');
    buffer.writeln('  </metadata>');

    // Add waypoints
    for (final waypoint in waypoints) {
      buffer.writeln(
          '  <wpt lat="${waypoint.coordinates.latitude}" lon="${waypoint.coordinates.longitude}">');
      if (waypoint.altitude != null) {
        buffer.writeln('    <ele>${waypoint.altitude}</ele>');
      }
      buffer.writeln(
          '    <time>${waypoint.timestamp.toUtc().toIso8601String()}</time>');
      buffer.writeln('    <name>${_escapeXml(waypoint.displayName)}</name>');
      if (waypoint.notes != null) {
        buffer.writeln('    <desc>${_escapeXml(waypoint.notes!)}</desc>');
      }
      buffer.writeln('    <type>${waypoint.type.displayName}</type>');
      buffer.writeln('  </wpt>');
    }

    // Add track if we have breadcrumbs
    if (breadcrumbs.isNotEmpty) {
      buffer.writeln('  <trk>');
      buffer.writeln('    <name>${_escapeXml(session.name)} Track</name>');
      if (session.description != null) {
        buffer.writeln('    <desc>${_escapeXml(session.description!)}</desc>');
      }
      buffer.writeln('    <trkseg>');

      for (final breadcrumb in breadcrumbs) {
        buffer.writeln(
            '      <trkpt lat="${breadcrumb.coordinates.latitude}" lon="${breadcrumb.coordinates.longitude}">');
        if (breadcrumb.altitude != null) {
          buffer.writeln('        <ele>${breadcrumb.altitude}</ele>');
        }
        buffer.writeln(
            '        <time>${breadcrumb.timestamp.toUtc().toIso8601String()}</time>');

        // Add extensions for additional data
        if (breadcrumb.speed != null || breadcrumb.heading != null) {
          buffer.writeln('        <extensions>');
          if (breadcrumb.speed != null) {
            buffer.writeln('          <speed>${breadcrumb.speed}</speed>');
          }
          if (breadcrumb.heading != null) {
            buffer.writeln('          <course>${breadcrumb.heading}</course>');
          }
          buffer.writeln('          <hdop>${breadcrumb.accuracy}</hdop>');
          buffer.writeln('        </extensions>');
        }

        buffer.writeln('      </trkpt>');
      }

      buffer.writeln('    </trkseg>');
      buffer.writeln('  </trk>');
    }

    // GPX footer
    buffer.writeln('</gpx>');

    return buffer.toString();
  }

  /// Save GPX content to a temporary file
  Future<File> _saveToTempFile(String sessionName, String gpxContent) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = '${_sanitizeFileName(sessionName)}.gpx';
    final file = File('${tempDir.path}/$fileName');

    await file.writeAsString(gpxContent);
    return file;
  }

  /// Sanitize filename for safe file system usage
  String _sanitizeFileName(String name) =>
      // Replace invalid characters with underscores
      name
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase();

  /// Escape XML special characters
  String _escapeXml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  /// Get export statistics for a session
  Future<Map<String, dynamic>> getExportStats(String sessionId) async {
    try {
      final breadcrumbs =
          await _databaseService.getBreadcrumbsForSession(sessionId);
      final waypoints =
          await _waypointService.getWaypointsForSession(sessionId);

      return {
        'breadcrumbCount': breadcrumbs.length,
        'waypointCount': waypoints.length,
        'hasTrackData': breadcrumbs.isNotEmpty,
        'hasWaypoints': waypoints.isNotEmpty,
      };
    } catch (error) {
      debugPrint('Error getting export stats: $error');
      return {
        'breadcrumbCount': 0,
        'waypointCount': 0,
        'hasTrackData': false,
        'hasWaypoints': false,
      };
    }
  }
}
