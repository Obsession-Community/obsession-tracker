import 'dart:io';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/imported_route.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

/// Service for parsing GPX files into ImportedRoute objects
class GPXParserService {
  static const _uuid = Uuid();

  /// Parse a GPX file and return an ImportedRoute
  Future<ImportedRoute> parseGPXFile(File file) async {
    try {
      final content = await file.readAsString();
      return parseGPXContent(content, file.path.split('/').last);
    } catch (e) {
      throw GPXParseException('Failed to read GPX file: $e');
    }
  }

  /// Parse GPX content string
  ImportedRoute parseGPXContent(String content, String filename) {
    try {
      final document = XmlDocument.parse(content);
      return _extractGPXData(document, filename);
    } catch (e) {
      throw GPXParseException('Failed to parse GPX content: $e');
    }
  }

  /// Validate GPX file structure
  bool validateGPXContent(String content) {
    try {
      final document = XmlDocument.parse(content);
      final gpxElement = document.findElements('gpx').firstOrNull;
      return gpxElement != null;
    } catch (e) {
      return false;
    }
  }

  /// Extract data from GPX document
  ImportedRoute _extractGPXData(XmlDocument document, String filename) {
    final gpxElement = document.findElements('gpx').firstOrNull;
    if (gpxElement == null) {
      throw const GPXParseException('No GPX root element found');
    }

    final now = DateTime.now();
    final routeId = _uuid.v4();

    // Extract metadata
    final metadata = _extractMetadata(gpxElement);
    final name = _extractName(gpxElement, filename);
    final description = _extractDescription(gpxElement);

    // Extract track points and waypoints
    final points = <RoutePoint>[];
    final waypoints = <RouteWaypoint>[];

    // Process tracks (most common for routes)
    _extractTracks(gpxElement, routeId, points);

    // Process routes (alternative format)
    _extractRoutes(gpxElement, routeId, points);

    // Process waypoints
    _extractWaypoints(gpxElement, routeId, waypoints);

    // Sort points by sequence
    points.sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

    // Calculate total distance
    final totalDistance = _calculateTotalDistance(points);

    return ImportedRoute(
      id: routeId,
      name: name,
      description: description,
      points: points,
      waypoints: waypoints,
      totalDistance: totalDistance,
      estimatedDuration: _estimateTime(totalDistance),
      importedAt: now,
      sourceFormat: 'gpx',
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Extract metadata from GPX
  Map<String, dynamic> _extractMetadata(XmlElement gpx) {
    final metadata = <String, dynamic>{};

    // GPX version
    metadata['version'] = gpx.getAttribute('version') ?? '1.1';

    // Creator
    metadata['creator'] = gpx.getAttribute('creator') ?? 'Unknown';

    // Metadata element
    final metadataElement = gpx.findElements('metadata').firstOrNull;
    if (metadataElement != null) {
      final nameElement = metadataElement.findElements('name').firstOrNull;
      if (nameElement != null) {
        metadata['originalName'] = nameElement.innerText;
      }

      final descElement = metadataElement.findElements('desc').firstOrNull;
      if (descElement != null) {
        metadata['originalDescription'] = descElement.innerText;
      }

      final timeElement = metadataElement.findElements('time').firstOrNull;
      if (timeElement != null) {
        metadata['creationTime'] = timeElement.innerText;
      }
    }

    return metadata;
  }

  /// Extract name from GPX
  String _extractName(XmlElement gpx, String filename) {
    // Try metadata name first
    final metadataElement = gpx.findElements('metadata').firstOrNull;
    if (metadataElement != null) {
      final nameElement = metadataElement.findElements('name').firstOrNull;
      if (nameElement != null && nameElement.innerText.isNotEmpty) {
        return nameElement.innerText;
      }
    }

    // Try first track name
    final trackElement = gpx.findElements('trk').firstOrNull;
    if (trackElement != null) {
      final nameElement = trackElement.findElements('name').firstOrNull;
      if (nameElement != null && nameElement.innerText.isNotEmpty) {
        return nameElement.innerText;
      }
    }

    // Try first route name
    final routeElement = gpx.findElements('rte').firstOrNull;
    if (routeElement != null) {
      final nameElement = routeElement.findElements('name').firstOrNull;
      if (nameElement != null && nameElement.innerText.isNotEmpty) {
        return nameElement.innerText;
      }
    }

    // Fallback to filename
    return filename.replaceAll('.gpx', '').replaceAll('.GPX', '');
  }

  /// Extract description from GPX
  String? _extractDescription(XmlElement gpx) {
    final metadataElement = gpx.findElements('metadata').firstOrNull;
    if (metadataElement != null) {
      final descElement = metadataElement.findElements('desc').firstOrNull;
      if (descElement != null && descElement.innerText.isNotEmpty) {
        return descElement.innerText;
      }
    }

    final trackElement = gpx.findElements('trk').firstOrNull;
    if (trackElement != null) {
      final descElement = trackElement.findElements('desc').firstOrNull;
      if (descElement != null && descElement.innerText.isNotEmpty) {
        return descElement.innerText;
      }
    }

    return null;
  }

  /// Extract track points from GPX tracks
  void _extractTracks(XmlElement gpx, String routeId, List<RoutePoint> points) {
    int sequenceNumber = points.length;

    for (final track in gpx.findElements('trk')) {
      for (final segment in track.findElements('trkseg')) {
        for (final point in segment.findElements('trkpt')) {
          final routePoint = _parsePoint(point, routeId, sequenceNumber++);
          if (routePoint != null) {
            points.add(routePoint);
          }
        }
      }
    }
  }

  /// Extract route points from GPX routes
  void _extractRoutes(XmlElement gpx, String routeId, List<RoutePoint> points) {
    int sequenceNumber = points.length;

    for (final route in gpx.findElements('rte')) {
      for (final point in route.findElements('rtept')) {
        final routePoint = _parsePoint(point, routeId, sequenceNumber++);
        if (routePoint != null) {
          points.add(routePoint);
        }
      }
    }
  }

  /// Extract waypoints from GPX
  void _extractWaypoints(
      XmlElement gpx, String routeId, List<RouteWaypoint> waypoints) {
    for (final waypoint in gpx.findElements('wpt')) {
      final routeWaypoint = _parseWaypoint(waypoint, routeId);
      if (routeWaypoint != null) {
        waypoints.add(routeWaypoint);
      }
    }
  }

  /// Parse a track/route point
  RoutePoint? _parsePoint(
      XmlElement point, String routeId, int sequenceNumber) {
    final latStr = point.getAttribute('lat');
    final lonStr = point.getAttribute('lon');

    if (latStr == null || lonStr == null) {
      return null;
    }

    final lat = double.tryParse(latStr);
    final lon = double.tryParse(lonStr);

    if (lat == null || lon == null) {
      return null;
    }

    // Validate coordinates
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      return null;
    }

    // Parse elevation
    double? elevation;
    final elevationElement = point.findElements('ele').firstOrNull;
    if (elevationElement != null) {
      elevation = double.tryParse(elevationElement.innerText);
    }

    // Parse timestamp
    DateTime? timestamp;
    final timeElement = point.findElements('time').firstOrNull;
    if (timeElement != null) {
      timestamp = DateTime.tryParse(timeElement.innerText);
    }

    return RoutePoint(
      id: _uuid.v4(),
      routeId: routeId,
      latitude: lat,
      longitude: lon,
      elevation: elevation,
      timestamp: timestamp,
      sequenceNumber: sequenceNumber,
    );
  }

  /// Parse a waypoint
  RouteWaypoint? _parseWaypoint(XmlElement waypoint, String routeId) {
    final latStr = waypoint.getAttribute('lat');
    final lonStr = waypoint.getAttribute('lon');

    if (latStr == null || lonStr == null) {
      return null;
    }

    final lat = double.tryParse(latStr);
    final lon = double.tryParse(lonStr);

    if (lat == null || lon == null) {
      return null;
    }

    // Validate coordinates
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      return null;
    }

    // Extract name
    final nameElement = waypoint.findElements('name').firstOrNull;
    final name = nameElement?.innerText ?? 'Waypoint';

    // Extract description
    final descElement = waypoint.findElements('desc').firstOrNull;
    final description = descElement?.innerText;

    // Extract type
    final typeElement = waypoint.findElements('type').firstOrNull;
    final type = typeElement?.innerText;

    // Extract elevation
    double? elevation;
    final elevationElement = waypoint.findElements('ele').firstOrNull;
    if (elevationElement != null) {
      elevation = double.tryParse(elevationElement.innerText);
    }

    // Additional properties
    final properties = <String, dynamic>{};

    // Extract extensions if present
    final extensionsElement = waypoint.findElements('extensions').firstOrNull;
    if (extensionsElement != null) {
      for (final extension in extensionsElement.children) {
        if (extension is XmlElement) {
          properties[extension.name.local] = extension.innerText;
        }
      }
    }

    return RouteWaypoint(
      id: _uuid.v4(),
      routeId: routeId,
      name: name,
      description: description,
      latitude: lat,
      longitude: lon,
      elevation: elevation,
      type: type,
      properties: properties,
    );
  }

  /// Calculate total distance between points
  double _calculateTotalDistance(List<RoutePoint> points) {
    if (points.length < 2) {
      return 0.0;
    }

    double totalDistance = 0.0;
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];

      final distance = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );

      totalDistance += distance;
    }

    return totalDistance;
  }

  /// Estimate time based on distance (assuming walking speed of 4 km/h)
  double? _estimateTime(double distanceInMeters) {
    if (distanceInMeters <= 0) {
      return null;
    }

    const walkingSpeedKmh = 4.0; // Conservative walking speed
    final distanceKm = distanceInMeters / 1000;
    final timeHours = distanceKm / walkingSpeedKmh;

    return timeHours * 3600; // Convert to seconds
  }

  /// Simplify route by removing redundant points
  List<RoutePoint> simplifyRoute(List<RoutePoint> points,
      {double toleranceMeters = 10.0}) {
    if (points.length <= 2) {
      return points;
    }

    final simplified = <RoutePoint>[points.first];

    for (int i = 1; i < points.length - 1; i++) {
      final prev = simplified.last;
      final curr = points[i];
      final next = points[i + 1];

      // Calculate distance from current point to line between prev and next
      final distance = _pointToLineDistance(
        curr.latitude,
        curr.longitude,
        prev.latitude,
        prev.longitude,
        next.latitude,
        next.longitude,
      );

      // Keep point if it's far enough from the line
      if (distance > toleranceMeters) {
        simplified.add(curr.copyWith(sequenceNumber: simplified.length));
      }
    }

    // Always keep the last point
    simplified.add(points.last.copyWith(sequenceNumber: simplified.length));

    return simplified;
  }

  /// Calculate perpendicular distance from point to line
  double _pointToLineDistance(
    double px,
    double py, // Point
    double x1,
    double y1, // Line start
    double x2,
    double y2, // Line end
  ) {
    final a = px - x1;
    final b = py - y1;
    final c = x2 - x1;
    final d = y2 - y1;

    final dot = a * c + b * d;
    final lenSq = c * c + d * d;

    if (lenSq == 0) {
      return math.sqrt(a * a + b * b) *
          111320; // Convert degrees to meters (approximate)
    }

    final param = dot / lenSq;

    double xx, yy;
    if (param < 0) {
      xx = x1;
      yy = y1;
    } else if (param > 1) {
      xx = x2;
      yy = y2;
    } else {
      xx = x1 + param * c;
      yy = y1 + param * d;
    }

    final dx = px - xx;
    final dy = py - yy;
    return math.sqrt(dx * dx + dy * dy) *
        111320; // Convert degrees to meters (approximate)
  }
}

/// Exception thrown when GPX parsing fails
class GPXParseException implements Exception {
  final String message;

  const GPXParseException(this.message);

  @override
  String toString() => 'GPXParseException: $message';
}
