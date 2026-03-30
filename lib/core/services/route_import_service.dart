import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:obsession_tracker/core/models/imported_route.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/gpx_parser_service.dart';
import 'package:xml/xml.dart';

/// Service for importing routes from GPX and KML files
class RouteImportService {
  final GPXParserService _gpxParser = GPXParserService();
  final DatabaseService _database = DatabaseService();

  /// Pick and import a GPX/KML file
  Future<ImportedRoute?> pickAndImportFile() async {
    try {
      // Pick file using file picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx', 'kml'],
      );

      if (result == null || result.files.isEmpty) {
        return null; // User cancelled
      }

      final file = result.files.first;
      if (file.path == null) {
        throw const RouteImportException('Cannot access selected file');
      }

      return await importFromFile(File(file.path!));
    } catch (e) {
      throw RouteImportException('Failed to pick file: $e');
    }
  }

  /// Import route from a specific file
  Future<ImportedRoute> importFromFile(File file) async {
    try {
      final fileName = file.path.split('/').last.toLowerCase();

      if (!_isValidRouteFile(fileName)) {
        throw const RouteImportException(
            'Invalid file type. Only GPX and KML files are supported.');
      }

      // Check file size (max 10MB)
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw const RouteImportException('File too large. Maximum size is 10MB.');
      }

      ImportedRoute route;

      if (fileName.endsWith('.gpx')) {
        route = await _gpxParser.parseGPXFile(file);
      } else if (fileName.endsWith('.kml')) {
        route = await _parseKMLFile(file);
      } else {
        throw const RouteImportException('Unsupported file format');
      }

      // Validate route has points
      if (route.points.isEmpty) {
        throw const RouteImportException('Route file contains no track points');
      }

      // Simplify route if it has too many points
      final simplifiedRoute = _simplifyRouteIfNeeded(route);

      // Save to database
      await _database.insertImportedRoute(simplifiedRoute);

      return simplifiedRoute;
    } catch (e) {
      if (e is RouteImportException) {
        rethrow;
      }
      throw RouteImportException('Failed to import route: $e');
    }
  }

  /// Import route from file content (for testing or URL imports)
  Future<ImportedRoute> importFromContent(
    String content,
    String fileName,
    String format,
  ) async {
    try {
      ImportedRoute route;

      if (format.toLowerCase() == 'gpx') {
        route = _gpxParser.parseGPXContent(content, fileName);
      } else if (format.toLowerCase() == 'kml') {
        route = _parseKMLContent(content, fileName);
      } else {
        throw RouteImportException('Format $format not supported');
      }

      // Validate route has points
      if (route.points.isEmpty) {
        throw const RouteImportException('Route content contains no track points');
      }

      // Simplify route if needed
      final simplifiedRoute = _simplifyRouteIfNeeded(route);

      // Save to database
      await _database.insertImportedRoute(simplifiedRoute);

      return simplifiedRoute;
    } catch (e) {
      if (e is RouteImportException) {
        rethrow;
      }
      throw RouteImportException('Failed to import route content: $e');
    }
  }

  /// Get all imported routes
  Future<List<ImportedRoute>> getAllRoutes() async {
    return _database.getImportedRoutes();
  }

  /// Get specific route by ID with all details
  Future<ImportedRoute?> getRouteById(String routeId) async {
    return _database.getImportedRouteById(routeId);
  }

  /// Delete an imported route
  Future<void> deleteRoute(String routeId) async {
    await _database.deleteImportedRoute(routeId);
  }

  /// Update route metadata (name, description)
  Future<void> updateRoute(ImportedRoute route) async {
    await _database.updateImportedRoute(route);
  }

  /// Check if file is a valid route file
  bool _isValidRouteFile(String fileName) {
    return fileName.endsWith('.gpx') || fileName.endsWith('.kml');
  }

  /// Simplify route if it has too many points
  ImportedRoute _simplifyRouteIfNeeded(ImportedRoute route) {
    const maxPoints = 5000;

    if (route.points.length <= maxPoints) {
      return route;
    }

    // Simplify using GPX parser service
    final simplifiedPoints =
        _gpxParser.simplifyRoute(route.points, toleranceMeters: 15.0);

    // If still too many points, use more aggressive simplification
    final finalPoints = simplifiedPoints.length > maxPoints
        ? _gpxParser.simplifyRoute(simplifiedPoints, toleranceMeters: 25.0)
        : simplifiedPoints;

    return route.copyWith(points: finalPoints);
  }

  /// Validate GPX content before import
  bool validateGPXContent(String content) {
    return _gpxParser.validateGPXContent(content);
  }

  /// Get import statistics
  Future<Map<String, dynamic>> getImportStatistics() async {
    final routes = await getAllRoutes();

    int totalPoints = 0;
    int totalWaypoints = 0;
    double totalDistance = 0.0;
    final formatCounts = <String, int>{};

    for (final route in routes) {
      final fullRoute = await getRouteById(route.id);
      if (fullRoute != null) {
        totalPoints += fullRoute.points.length;
        totalWaypoints += fullRoute.waypoints.length;
        totalDistance += fullRoute.totalDistance;
        formatCounts[fullRoute.sourceFormat] =
            (formatCounts[fullRoute.sourceFormat] ?? 0) + 1;
      }
    }

    return {
      'totalRoutes': routes.length,
      'totalPoints': totalPoints,
      'totalWaypoints': totalWaypoints,
      'totalDistance': totalDistance,
      'formatBreakdown': formatCounts,
    };
  }

  /// Parse KML file and create ImportedRoute
  Future<ImportedRoute> _parseKMLFile(File file) async {
    try {
      final content = await file.readAsString();
      return _parseKMLContent(content, file.path.split('/').last);
    } catch (e) {
      throw RouteImportException('Failed to read KML file: $e');
    }
  }

  /// Parse KML content and create ImportedRoute
  ImportedRoute _parseKMLContent(String content, String fileName) {
    try {
      final document = XmlDocument.parse(content);
      final kmlElement = document.findElements('kml').first;
      
      // Find Document or direct Placemarks
      final docElement = kmlElement.findElements('Document').firstOrNull ?? kmlElement;
      
      // Extract metadata
      String name = fileName.replaceAll('.kml', '');
      String? description;
      
      final nameElement = docElement.findElements('name').firstOrNull;
      if (nameElement != null) {
        name = nameElement.innerText;
      }
      
      final descElement = docElement.findElements('description').firstOrNull;
      if (descElement != null) {
        description = descElement.innerText;
      }

      final List<RoutePoint> points = [];
      final List<RouteWaypoint> waypoints = [];

      // Find all Placemarks
      final placemarks = docElement.findAllElements('Placemark');
      
      for (final placemark in placemarks) {
        final placemarkName = placemark.findElements('name').firstOrNull?.innerText ?? '';
        final placemarkDesc = placemark.findElements('description').firstOrNull?.innerText;
        
        // Check for LineString (track/path)
        final lineString = placemark.findElements('LineString').firstOrNull;
        if (lineString != null) {
          final coordinates = lineString.findElements('coordinates').firstOrNull?.innerText;
          if (coordinates != null) {
            final coords = _parseKMLCoordinates(coordinates);
            for (int i = 0; i < coords.length; i++) {
              points.add(RoutePoint(
                id: '${name}_point_$i',
                routeId: '', // Will be set later
                latitude: coords[i]['lat']!,
                longitude: coords[i]['lng']!,
                elevation: coords[i]['ele'],
                sequenceNumber: i,
              ));
            }
          }
        }
        
        // Check for Point (waypoint)
        final point = placemark.findElements('Point').firstOrNull;
        if (point != null) {
          final coordinates = point.findElements('coordinates').firstOrNull?.innerText;
          if (coordinates != null) {
            final coords = _parseKMLCoordinates(coordinates);
            if (coords.isNotEmpty) {
              waypoints.add(RouteWaypoint(
                id: '${name}_waypoint_${waypoints.length}',
                routeId: '', // Will be set later
                name: placemarkName,
                description: placemarkDesc,
                latitude: coords[0]['lat']!,
                longitude: coords[0]['lng']!,
                elevation: coords[0]['ele'],
                type: 'waypoint',
                properties: <String, dynamic>{},
              ));
            }
          }
        }
      }

      // Calculate total distance
      double totalDistance = 0.0;
      for (int i = 1; i < points.length; i++) {
        totalDistance += _calculateDistance(
          points[i - 1].latitude,
          points[i - 1].longitude,
          points[i].latitude,
          points[i].longitude,
        );
      }

      final routeId = DateTime.now().millisecondsSinceEpoch.toString();
      final now = DateTime.now();

      // Create points and waypoints with correct route IDs
      final finalPoints = <RoutePoint>[];
      final finalWaypoints = <RouteWaypoint>[];

      for (int i = 0; i < points.length; i++) {
        final point = points[i];
        finalPoints.add(RoutePoint(
          id: '${routeId}_point_$i',
          routeId: routeId,
          latitude: point.latitude,
          longitude: point.longitude,
          elevation: point.elevation,
          sequenceNumber: i,
          timestamp: point.timestamp,
        ));
      }

      for (int i = 0; i < waypoints.length; i++) {
        final waypoint = waypoints[i];
        finalWaypoints.add(RouteWaypoint(
          id: '${routeId}_waypoint_$i',
          routeId: routeId,
          name: waypoint.name,
          description: waypoint.description,
          latitude: waypoint.latitude,
          longitude: waypoint.longitude,
          elevation: waypoint.elevation,
          type: waypoint.type,
          properties: <String, dynamic>{},
        ));
      }

      // Create the route
      final route = ImportedRoute(
        id: routeId,
        name: name,
        description: description,
        sourceFormat: 'kml',
        points: finalPoints,
        waypoints: finalWaypoints,
        totalDistance: totalDistance,
        importedAt: now,
        metadata: <String, dynamic>{
          'originalFormat': 'KML',
          'fileName': fileName,
          'parsedAt': now.toIso8601String(),
        },
        createdAt: now,
        updatedAt: now,
      );

      return route;
    } catch (e) {
      throw RouteImportException('Failed to parse KML content: $e');
    }
  }

  /// Parse KML coordinate string into list of coordinate maps
  List<Map<String, double?>> _parseKMLCoordinates(String coordinateString) {
    final List<Map<String, double?>> coordinates = [];
    
    // KML coordinates are in format: lng,lat,ele lng,lat,ele (space or newline separated)
    final coordPairs = coordinateString.trim().split(RegExp(r'\s+'));
    
    for (final coordPair in coordPairs) {
      if (coordPair.trim().isEmpty) continue;
      
      final parts = coordPair.split(',');
      if (parts.length >= 2) {
        final lng = double.tryParse(parts[0]);
        final lat = double.tryParse(parts[1]);
        final ele = parts.length >= 3 ? double.tryParse(parts[2]) : null;
        
        if (lng != null && lat != null) {
          coordinates.add({
            'lng': lng,
            'lat': lat,
            'ele': ele,
          });
        }
      }
    }
    
    return coordinates;
  }

  /// Calculate distance between two points in meters using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) => degrees * (math.pi / 180);

  /// Export route back to GPX format (for sharing)
  String exportToGPX(ImportedRoute route) {
    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="Obsession Tracker">');

    // Metadata
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name><![CDATA[${route.name}]]></name>');
    if (route.description != null) {
      buffer.writeln('    <desc><![CDATA[${route.description}]]></desc>');
    }
    buffer.writeln(
        '    <time>${DateTime.now().toUtc().toIso8601String()}</time>');
    buffer.writeln('  </metadata>');

    // Waypoints
    for (final waypoint in route.waypoints) {
      buffer.writeln(
          '  <wpt lat="${waypoint.latitude}" lon="${waypoint.longitude}">');
      if (waypoint.elevation != null) {
        buffer.writeln('    <ele>${waypoint.elevation}</ele>');
      }
      buffer.writeln('    <name><![CDATA[${waypoint.name}]]></name>');
      if (waypoint.description != null) {
        buffer.writeln('    <desc><![CDATA[${waypoint.description}]]></desc>');
      }
      if (waypoint.type != null) {
        buffer.writeln('    <type><![CDATA[${waypoint.type}]]></type>');
      }
      buffer.writeln('  </wpt>');
    }

    // Track
    buffer.writeln('  <trk>');
    buffer.writeln('    <name><![CDATA[${route.name}]]></name>');
    if (route.description != null) {
      buffer.writeln('    <desc><![CDATA[${route.description}]]></desc>');
    }
    buffer.writeln('    <trkseg>');

    for (final point in route.points) {
      buffer.writeln(
          '      <trkpt lat="${point.latitude}" lon="${point.longitude}">');
      if (point.elevation != null) {
        buffer.writeln('        <ele>${point.elevation}</ele>');
      }
      if (point.timestamp != null) {
        buffer.writeln(
            '        <time>${point.timestamp!.toUtc().toIso8601String()}</time>');
      }
      buffer.writeln('      </trkpt>');
    }

    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');

    return buffer.toString();
  }
}

/// Exception thrown when route import fails
class RouteImportException implements Exception {
  final String message;

  const RouteImportException(this.message);

  @override
  String toString() => 'RouteImportException: $message';
}
