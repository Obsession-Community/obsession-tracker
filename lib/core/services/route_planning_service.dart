import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/internationalization_service.dart';

/// Route planning algorithms
enum RoutePlanningAlgorithm {
  /// Direct straight line
  straightLine,

  /// Shortest path (A* algorithm)
  shortestPath,

  /// Fastest route considering terrain
  fastest,

  /// Most scenic route
  scenic,

  /// Safest route avoiding hazards
  safest,
}

/// Route segment types
enum RouteSegmentType {
  /// Walking/hiking segment
  walking,

  /// Cycling segment
  cycling,

  /// Driving segment
  driving,

  /// Water crossing
  water,

  /// Climbing/scrambling
  climbing,
}

/// Navigation instruction types
enum NavigationInstructionType {
  start,
  straight,
  turnLeft,
  turnRight,
  turnSlightLeft,
  turnSlightRight,
  turnSharpLeft,
  turnSharpRight,
  uTurn,
  waypoint,
  destination,
  warning,
}

/// Represents a single route segment
@immutable
class RouteSegment {
  const RouteSegment({
    required this.startPoint,
    required this.endPoint,
    required this.distance,
    required this.duration,
    required this.type,
    this.elevation,
    this.difficulty,
    this.instructions = const [],
    this.waypoints = const [],
  });

  final LatLng startPoint;
  final LatLng endPoint;
  final double distance; // in meters
  final Duration duration;
  final RouteSegmentType type;
  final double? elevation; // elevation gain in meters
  final int? difficulty; // 1-5 scale
  final List<NavigationInstruction> instructions;
  final List<LatLng> waypoints;

  RouteSegment copyWith({
    LatLng? startPoint,
    LatLng? endPoint,
    double? distance,
    Duration? duration,
    RouteSegmentType? type,
    double? elevation,
    int? difficulty,
    List<NavigationInstruction>? instructions,
    List<LatLng>? waypoints,
  }) =>
      RouteSegment(
        startPoint: startPoint ?? this.startPoint,
        endPoint: endPoint ?? this.endPoint,
        distance: distance ?? this.distance,
        duration: duration ?? this.duration,
        type: type ?? this.type,
        elevation: elevation ?? this.elevation,
        difficulty: difficulty ?? this.difficulty,
        instructions: instructions ?? this.instructions,
        waypoints: waypoints ?? this.waypoints,
      );
}

/// Navigation instruction
@immutable
class NavigationInstruction {
  const NavigationInstruction({
    required this.type,
    required this.description,
    required this.distance,
    required this.position,
    this.bearing,
    this.icon,
  });

  final NavigationInstructionType type;
  final String description;
  final double distance; // distance to this instruction
  final LatLng position;
  final double? bearing; // compass bearing in degrees
  final String? icon;

  NavigationInstruction copyWith({
    NavigationInstructionType? type,
    String? description,
    double? distance,
    LatLng? position,
    double? bearing,
    String? icon,
  }) =>
      NavigationInstruction(
        type: type ?? this.type,
        description: description ?? this.description,
        distance: distance ?? this.distance,
        position: position ?? this.position,
        bearing: bearing ?? this.bearing,
        icon: icon ?? this.icon,
      );
}

/// Complete route with all segments and metadata
@immutable
class PlannedRoute {
  const PlannedRoute({
    required this.id,
    required this.name,
    required this.startPoint,
    required this.endPoint,
    required this.segments,
    required this.algorithm,
    required this.createdAt,
    this.description,
    this.totalDistance = 0.0,
    this.totalDuration = Duration.zero,
    this.totalElevationGain = 0.0,
    this.difficulty = 1,
    this.waypoints = const [],
    this.instructions = const [],
  });

  final String id;
  final String name;
  final String? description;
  final LatLng startPoint;
  final LatLng endPoint;
  final List<RouteSegment> segments;
  final RoutePlanningAlgorithm algorithm;
  final DateTime createdAt;
  final double totalDistance; // in meters
  final Duration totalDuration;
  final double totalElevationGain; // in meters
  final int difficulty; // 1-5 scale
  final List<Waypoint> waypoints;
  final List<NavigationInstruction> instructions;

  /// Get all route points for drawing on map
  List<LatLng> get routePoints {
    final List<LatLng> points = <LatLng>[];
    for (final RouteSegment segment in segments) {
      points.add(segment.startPoint);
      points.addAll(segment.waypoints);
    }
    if (segments.isNotEmpty) {
      points.add(segments.last.endPoint);
    }
    return points;
  }

  /// Get formatted distance string (respects user's imperial/metric preference)
  String get formattedDistance =>
      InternationalizationService().formatDistance(totalDistance);

  /// Get formatted duration string
  String get formattedDuration {
    final int hours = totalDuration.inHours;
    final int minutes = totalDuration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Get difficulty description
  String get difficultyDescription {
    switch (difficulty) {
      case 1:
        return 'Easy';
      case 2:
        return 'Moderate';
      case 3:
        return 'Challenging';
      case 4:
        return 'Difficult';
      case 5:
        return 'Expert';
      default:
        return 'Unknown';
    }
  }

  PlannedRoute copyWith({
    String? id,
    String? name,
    String? description,
    LatLng? startPoint,
    LatLng? endPoint,
    List<RouteSegment>? segments,
    RoutePlanningAlgorithm? algorithm,
    DateTime? createdAt,
    double? totalDistance,
    Duration? totalDuration,
    double? totalElevationGain,
    int? difficulty,
    List<Waypoint>? waypoints,
    List<NavigationInstruction>? instructions,
  }) =>
      PlannedRoute(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        startPoint: startPoint ?? this.startPoint,
        endPoint: endPoint ?? this.endPoint,
        segments: segments ?? this.segments,
        algorithm: algorithm ?? this.algorithm,
        createdAt: createdAt ?? this.createdAt,
        totalDistance: totalDistance ?? this.totalDistance,
        totalDuration: totalDuration ?? this.totalDuration,
        totalElevationGain: totalElevationGain ?? this.totalElevationGain,
        difficulty: difficulty ?? this.difficulty,
        waypoints: waypoints ?? this.waypoints,
        instructions: instructions ?? this.instructions,
      );

  /// Convert route to database map for storage
  Map<String, dynamic> toDatabaseMap() {
    debugPrint('🔵 toDatabaseMap() called for route: $name');
    debugPrint('🔵 Route has ${waypoints.length} intermediate waypoints');
    debugPrint('🔵 Start: $startPoint, End: $endPoint');

    // Serialize all route points (from segments)
    final List<Map<String, dynamic>> routePointsData = routePoints.map((point) {
      return {
        'lat': point.latitude,
        'lng': point.longitude,
      };
    }).toList();

    // Serialize waypoint IDs
    final List<String> waypointIds = waypoints.map((w) => w.id).toList();

    final routeDataJson = jsonEncode(routePointsData);
    debugPrint('📦 Serializing route with ${routePoints.length} points');
    debugPrint('📦 Route data JSON length: ${routeDataJson.length}');
    debugPrint('📦 Route data preview: ${routeDataJson.substring(0, routeDataJson.length > 100 ? 100 : routeDataJson.length)}...');

    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.millisecondsSinceEpoch,
      'total_distance': totalDistance,
      'total_duration': totalDuration.inMilliseconds,
      'total_elevation_gain': totalElevationGain,
      'difficulty': difficulty,
      'algorithm': algorithm.name,
      'route_data': routeDataJson,
      'waypoint_ids': waypointIds.join(','),
    };
  }

  /// Create PlannedRoute from database map
  factory PlannedRoute.fromDatabaseMap(Map<String, dynamic> map) {
    // Parse route points from JSON
    List<LatLng> parsedRoutePoints = [];
    try {
      final routeDataStr = map['route_data'];
      debugPrint('📥 Loading route data: ${routeDataStr?.runtimeType}');

      if (routeDataStr != null && routeDataStr is String && routeDataStr.isNotEmpty) {
        debugPrint('📥 Route data string length: ${routeDataStr.length}');
        debugPrint('📥 Route data preview: ${routeDataStr.substring(0, routeDataStr.length > 100 ? 100 : routeDataStr.length)}...');

        final decoded = jsonDecode(routeDataStr);
        debugPrint('📥 Decoded type: ${decoded.runtimeType}');

        // Handle both List and Map formats for backwards compatibility
        if (decoded is List) {
          debugPrint('📥 Decoded list has ${decoded.length} items');
          parsedRoutePoints = decoded.map((point) {
            if (point is Map<String, dynamic>) {
              return LatLng(
                (point['lat'] as num).toDouble(),
                (point['lng'] as num).toDouble(),
              );
            }
            return const LatLng(0, 0);
          }).toList();
        } else if (decoded is Map) {
          // Handle legacy segment-based format
          debugPrint('📥 Converting legacy segment format to point list');
          final segments = decoded['segments'] as List?;
          if (segments != null && segments.isNotEmpty) {
            // Extract all points from segments
            for (final segment in segments) {
              if (segment is Map<String, dynamic>) {
                // Add start point if this is the first segment
                if (parsedRoutePoints.isEmpty && segment['start'] != null) {
                  final start = segment['start'] as Map<String, dynamic>;
                  parsedRoutePoints.add(LatLng(
                    (start['lat'] as num).toDouble(),
                    (start['lng'] as num).toDouble(),
                  ));
                }
                // Add end point
                if (segment['end'] != null) {
                  final end = segment['end'] as Map<String, dynamic>;
                  parsedRoutePoints.add(LatLng(
                    (end['lat'] as num).toDouble(),
                    (end['lng'] as num).toDouble(),
                  ));
                }
              }
            }
            debugPrint('📥 Converted ${segments.length} segments to ${parsedRoutePoints.length} points');
          } else {
            debugPrint('⚠️ Legacy format with no segments, treating as empty route');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error parsing route data: $e');
    }

    // Get start and end points
    final startPoint = parsedRoutePoints.isNotEmpty
        ? parsedRoutePoints.first
        : const LatLng(0, 0);
    final endPoint = parsedRoutePoints.isNotEmpty
        ? parsedRoutePoints.last
        : const LatLng(0, 0);

    // Create waypoints from intermediate route points (excluding start and end)
    final List<Waypoint> waypoints = [];
    if (parsedRoutePoints.length > 2) {
      final intermediatePoints = parsedRoutePoints.sublist(1, parsedRoutePoints.length - 1);
      for (int i = 0; i < intermediatePoints.length; i++) {
        waypoints.add(Waypoint(
          id: 'waypoint-$i',
          sessionId: 'route-planning',
          coordinates: intermediatePoints[i],
          timestamp: DateTime.now(),
          type: WaypointType.custom,
        ));
      }
    }
    debugPrint('📥 Reconstructed ${waypoints.length} waypoints from ${parsedRoutePoints.length} route points');

    // Create segments from route points
    final segments = <RouteSegment>[];
    if (parsedRoutePoints.length >= 2) {
      for (int i = 0; i < parsedRoutePoints.length - 1; i++) {
        segments.add(RouteSegment(
          startPoint: parsedRoutePoints[i],
          endPoint: parsedRoutePoints[i + 1],
          distance: 0, // Will be recalculated
          duration: Duration.zero,
          type: RouteSegmentType.walking,
        ));
      }
    }

    return PlannedRoute(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      startPoint: startPoint,
      endPoint: endPoint,
      segments: segments,
      algorithm: RoutePlanningAlgorithm.values.firstWhere(
        (a) => a.name == map['algorithm'],
        orElse: () => RoutePlanningAlgorithm.straightLine,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      totalDistance: map['total_distance'] as double,
      totalDuration: Duration(milliseconds: map['total_duration'] as int),
      totalElevationGain: map['total_elevation_gain'] as double,
      difficulty: map['difficulty'] as int,
      waypoints: waypoints,
    );
  }
}

/// Service for route planning and navigation
class RoutePlanningService {
  factory RoutePlanningService() => _instance ??= RoutePlanningService._();
  RoutePlanningService._();
  static RoutePlanningService? _instance;

  final Distance _distance = const Distance();
  final List<PlannedRoute> _savedRoutes = <PlannedRoute>[];
  final DatabaseService _databaseService = DatabaseService();

  /// Plan a route between two points
  Future<PlannedRoute> planRoute({
    required LatLng startPoint,
    required LatLng endPoint,
    required RoutePlanningAlgorithm algorithm,
    List<Waypoint> waypoints = const [],
    String? name,
    String? description,
  }) async {
    try {
      final String routeId = DateTime.now().millisecondsSinceEpoch.toString();
      final String routeName = name ?? 'Route ${_savedRoutes.length + 1}';

      // Calculate route based on algorithm
      final List<RouteSegment> segments = await _calculateRoute(
        startPoint,
        endPoint,
        algorithm,
        waypoints,
      );

      // Calculate totals
      final double totalDistance = segments.fold(
        0.0,
        (sum, segment) => sum + segment.distance,
      );

      final Duration totalDuration = segments.fold(
        Duration.zero,
        (sum, segment) => sum + segment.duration,
      );

      final double totalElevationGain = segments.fold(
        0.0,
        (sum, segment) => sum + (segment.elevation ?? 0.0),
      );

      // Generate navigation instructions
      final List<NavigationInstruction> instructions =
          _generateNavigationInstructions(segments, waypoints);

      // Determine difficulty
      final int difficulty = _calculateDifficulty(
        totalDistance,
        totalElevationGain,
        segments,
      );

      final PlannedRoute route = PlannedRoute(
        id: routeId,
        name: routeName,
        description: description,
        startPoint: startPoint,
        endPoint: endPoint,
        segments: segments,
        algorithm: algorithm,
        createdAt: DateTime.now(),
        totalDistance: totalDistance,
        totalDuration: totalDuration,
        totalElevationGain: totalElevationGain,
        difficulty: difficulty,
        waypoints: waypoints,
        instructions: instructions,
      );

      debugPrint(
          'Planned route: $routeName (${route.formattedDistance}, ${route.formattedDuration})');
      return route;
    } catch (e) {
      debugPrint('Error planning route: $e');
      rethrow;
    }
  }

  /// Calculate route segments based on algorithm
  Future<List<RouteSegment>> _calculateRoute(
    LatLng startPoint,
    LatLng endPoint,
    RoutePlanningAlgorithm algorithm,
    List<Waypoint> waypoints,
  ) async {
    switch (algorithm) {
      case RoutePlanningAlgorithm.straightLine:
        return _calculateStraightLineRoute(startPoint, endPoint, waypoints);
      case RoutePlanningAlgorithm.shortestPath:
        return _calculateShortestPathRoute(startPoint, endPoint, waypoints);
      case RoutePlanningAlgorithm.fastest:
        return _calculateFastestRoute(startPoint, endPoint, waypoints);
      case RoutePlanningAlgorithm.scenic:
        return _calculateScenicRoute(startPoint, endPoint, waypoints);
      case RoutePlanningAlgorithm.safest:
        return _calculateSafestRoute(startPoint, endPoint, waypoints);
    }
  }

  /// Calculate straight line route
  List<RouteSegment> _calculateStraightLineRoute(
    LatLng startPoint,
    LatLng endPoint,
    List<Waypoint> waypoints,
  ) {
    final List<RouteSegment> segments = <RouteSegment>[];
    LatLng currentPoint = startPoint;

    // Add waypoint segments
    for (final Waypoint waypoint in waypoints) {
      final double distance =
          _distance.as(LengthUnit.Meter, currentPoint, waypoint.coordinates);
      final Duration duration =
          _estimateDuration(distance, RouteSegmentType.walking);

      segments.add(RouteSegment(
        startPoint: currentPoint,
        endPoint: waypoint.coordinates,
        distance: distance,
        duration: duration,
        type: RouteSegmentType.walking,
      ));

      currentPoint = waypoint.coordinates;
    }

    // Add final segment to destination
    final double finalDistance =
        _distance.as(LengthUnit.Meter, currentPoint, endPoint);
    final Duration finalDuration =
        _estimateDuration(finalDistance, RouteSegmentType.walking);

    segments.add(RouteSegment(
      startPoint: currentPoint,
      endPoint: endPoint,
      distance: finalDistance,
      duration: finalDuration,
      type: RouteSegmentType.walking,
    ));

    return segments;
  }

  /// Calculate shortest path route (simplified A* implementation)
  List<RouteSegment> _calculateShortestPathRoute(
    LatLng startPoint,
    LatLng endPoint,
    List<Waypoint> waypoints,
  ) {
    // For now, use straight line with optimized waypoint order
    final List<Waypoint> optimizedWaypoints = _optimizeWaypointOrder(
      startPoint,
      endPoint,
      waypoints,
    );

    return _calculateStraightLineRoute(
        startPoint, endPoint, optimizedWaypoints);
  }

  /// Calculate fastest route
  List<RouteSegment> _calculateFastestRoute(
    LatLng startPoint,
    LatLng endPoint,
    List<Waypoint> waypoints,
  ) {
    // Use straight line but with faster movement types where possible
    final List<RouteSegment> segments = _calculateStraightLineRoute(
      startPoint,
      endPoint,
      waypoints,
    );

    // Adjust segment types for faster travel
    return segments.map((segment) {
      RouteSegmentType type = RouteSegmentType.walking;

      // Use cycling for longer segments
      if (segment.distance > 1000) {
        type = RouteSegmentType.cycling;
      }

      final Duration adjustedDuration =
          _estimateDuration(segment.distance, type);

      return segment.copyWith(
        type: type,
        duration: adjustedDuration,
      );
    }).toList();
  }

  /// Calculate scenic route
  List<RouteSegment> _calculateScenicRoute(
    LatLng startPoint,
    LatLng endPoint,
    List<Waypoint> waypoints,
  ) {
    // Add some detour for scenic value (simplified)
    final List<RouteSegment> baseSegments = _calculateStraightLineRoute(
      startPoint,
      endPoint,
      waypoints,
    );

    // Add 20% distance for scenic detours
    return baseSegments.map((segment) {
      final double scenicDistance = segment.distance * 1.2;
      final Duration scenicDuration =
          _estimateDuration(scenicDistance, segment.type);

      return segment.copyWith(
        distance: scenicDistance,
        duration: scenicDuration,
      );
    }).toList();
  }

  /// Calculate safest route
  List<RouteSegment> _calculateSafestRoute(
    LatLng startPoint,
    LatLng endPoint,
    List<Waypoint> waypoints,
  ) {
    // Use walking for all segments and add safety buffer
    final List<RouteSegment> baseSegments = _calculateStraightLineRoute(
      startPoint,
      endPoint,
      waypoints,
    );

    return baseSegments.map((segment) {
      final Duration safeDuration = Duration(
        milliseconds: (segment.duration.inMilliseconds * 1.3).round(),
      );

      return segment.copyWith(
        type: RouteSegmentType.walking,
        duration: safeDuration,
        difficulty: 1, // Always easy for safety
      );
    }).toList();
  }

  /// Optimize waypoint order for shortest total distance
  List<Waypoint> _optimizeWaypointOrder(
    LatLng startPoint,
    LatLng endPoint,
    List<Waypoint> waypoints,
  ) {
    if (waypoints.length <= 1) return waypoints;

    // Simple nearest neighbor algorithm
    final List<Waypoint> optimized = <Waypoint>[];
    final List<Waypoint> remaining = List.from(waypoints);
    LatLng currentPoint = startPoint;

    while (remaining.isNotEmpty) {
      double minDistance = double.infinity;
      Waypoint? nearest;

      for (final Waypoint waypoint in remaining) {
        final double distance = _distance.as(
          LengthUnit.Meter,
          currentPoint,
          waypoint.coordinates,
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearest = waypoint;
        }
      }

      if (nearest != null) {
        optimized.add(nearest);
        remaining.remove(nearest);
        currentPoint = nearest.coordinates;
      }
    }

    return optimized;
  }

  /// Estimate duration based on distance and segment type
  Duration _estimateDuration(double distance, RouteSegmentType type) {
    double speedKmh;

    switch (type) {
      case RouteSegmentType.walking:
        speedKmh = 4.0; // 4 km/h
        break;
      case RouteSegmentType.cycling:
        speedKmh = 15.0; // 15 km/h
        break;
      case RouteSegmentType.driving:
        speedKmh = 50.0; // 50 km/h
        break;
      case RouteSegmentType.water:
        speedKmh = 2.0; // 2 km/h swimming
        break;
      case RouteSegmentType.climbing:
        speedKmh = 1.0; // 1 km/h climbing
        break;
    }

    final double distanceKm = distance / 1000;
    final double hours = distanceKm / speedKmh;
    return Duration(milliseconds: (hours * 3600 * 1000).round());
  }

  /// Generate navigation instructions
  List<NavigationInstruction> _generateNavigationInstructions(
    List<RouteSegment> segments,
    List<Waypoint> waypoints,
  ) {
    final List<NavigationInstruction> instructions = <NavigationInstruction>[];
    double cumulativeDistance = 0.0;

    // Start instruction
    if (segments.isNotEmpty) {
      instructions.add(NavigationInstruction(
        type: NavigationInstructionType.start,
        description: 'Start your journey',
        distance: 0.0,
        position: segments.first.startPoint,
        bearing: _calculateBearing(
          segments.first.startPoint,
          segments.first.endPoint,
        ),
      ));
    }

    // Segment instructions
    for (int i = 0; i < segments.length; i++) {
      final RouteSegment segment = segments[i];
      cumulativeDistance += segment.distance;

      // Add waypoint instruction if this segment ends at a waypoint
      final Waypoint? waypoint = waypoints
          .where((w) =>
              _distance.as(LengthUnit.Meter, w.coordinates, segment.endPoint) <
              10)
          .firstOrNull;

      if (waypoint != null) {
        instructions.add(NavigationInstruction(
          type: NavigationInstructionType.waypoint,
          description: 'Reached waypoint: ${waypoint.displayName}',
          distance: cumulativeDistance,
          position: segment.endPoint,
        ));
      }

      // Add turn instruction for next segment
      if (i < segments.length - 1) {
        final RouteSegment nextSegment = segments[i + 1];
        final NavigationInstructionType turnType = _calculateTurnType(
          segment.startPoint,
          segment.endPoint,
          nextSegment.endPoint,
        );

        instructions.add(NavigationInstruction(
          type: turnType,
          description: _getTurnDescription(turnType),
          distance: cumulativeDistance,
          position: segment.endPoint,
          bearing: _calculateBearing(segment.endPoint, nextSegment.endPoint),
        ));
      }
    }

    // Destination instruction
    if (segments.isNotEmpty) {
      instructions.add(NavigationInstruction(
        type: NavigationInstructionType.destination,
        description: 'You have arrived at your destination',
        distance: cumulativeDistance,
        position: segments.last.endPoint,
      ));
    }

    return instructions;
  }

  /// Calculate bearing between two points
  double _calculateBearing(LatLng from, LatLng to) {
    final double lat1Rad = from.latitude * (math.pi / 180);
    final double lat2Rad = to.latitude * (math.pi / 180);
    final double deltaLonRad =
        (to.longitude - from.longitude) * (math.pi / 180);

    final double y = math.sin(deltaLonRad) * math.cos(lat2Rad);
    final double x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(deltaLonRad);

    final double bearingRad = math.atan2(y, x);
    final double bearingDeg = bearingRad * (180 / math.pi);

    return (bearingDeg + 360) % 360;
  }

  /// Calculate turn type based on bearing change
  NavigationInstructionType _calculateTurnType(
    LatLng from,
    LatLng via,
    LatLng to,
  ) {
    final double bearing1 = _calculateBearing(from, via);
    final double bearing2 = _calculateBearing(via, to);

    double angleDiff = bearing2 - bearing1;
    if (angleDiff > 180) angleDiff -= 360;
    if (angleDiff < -180) angleDiff += 360;

    if (angleDiff.abs() < 15) {
      return NavigationInstructionType.straight;
    } else if (angleDiff > 15 && angleDiff < 45) {
      return NavigationInstructionType.turnSlightRight;
    } else if (angleDiff >= 45 && angleDiff < 135) {
      return NavigationInstructionType.turnRight;
    } else if (angleDiff >= 135) {
      return NavigationInstructionType.turnSharpRight;
    } else if (angleDiff < -15 && angleDiff > -45) {
      return NavigationInstructionType.turnSlightLeft;
    } else if (angleDiff <= -45 && angleDiff > -135) {
      return NavigationInstructionType.turnLeft;
    } else {
      return NavigationInstructionType.turnSharpLeft;
    }
  }

  /// Get turn description
  String _getTurnDescription(NavigationInstructionType type) {
    switch (type) {
      case NavigationInstructionType.straight:
        return 'Continue straight';
      case NavigationInstructionType.turnLeft:
        return 'Turn left';
      case NavigationInstructionType.turnRight:
        return 'Turn right';
      case NavigationInstructionType.turnSlightLeft:
        return 'Turn slightly left';
      case NavigationInstructionType.turnSlightRight:
        return 'Turn slightly right';
      case NavigationInstructionType.turnSharpLeft:
        return 'Turn sharp left';
      case NavigationInstructionType.turnSharpRight:
        return 'Turn sharp right';
      case NavigationInstructionType.uTurn:
        return 'Make a U-turn';
      default:
        return 'Continue';
    }
  }

  /// Calculate route difficulty
  int _calculateDifficulty(
    double totalDistance,
    double totalElevationGain,
    List<RouteSegment> segments,
  ) {
    int difficulty = 1;

    // Distance factor
    if (totalDistance > 5000) difficulty = math.max(difficulty, 2);
    if (totalDistance > 10000) difficulty = math.max(difficulty, 3);
    if (totalDistance > 20000) difficulty = math.max(difficulty, 4);

    // Elevation factor
    if (totalElevationGain > 200) difficulty = math.max(difficulty, 2);
    if (totalElevationGain > 500) difficulty = math.max(difficulty, 3);
    if (totalElevationGain > 1000) difficulty = math.max(difficulty, 4);
    if (totalElevationGain > 2000) difficulty = math.max(difficulty, 5);

    // Segment type factor
    for (final RouteSegment segment in segments) {
      if (segment.type == RouteSegmentType.climbing) {
        difficulty = math.max(difficulty, 4);
      } else if (segment.type == RouteSegmentType.water) {
        difficulty = math.max(difficulty, 3);
      }
    }

    return difficulty.clamp(1, 5);
  }

  /// Save a route
  Future<void> saveRoute(PlannedRoute route) async {
    try {
      _savedRoutes.removeWhere((r) => r.id == route.id);
      _savedRoutes.add(route);

      // Persist to database
      await _databaseService.insertPlannedRoute(route.toDatabaseMap());
      debugPrint('Saved route: ${route.name}');
    } catch (e) {
      debugPrint('Error saving route: $e');
      rethrow;
    }
  }

  /// Get all saved routes
  List<PlannedRoute> get savedRoutes => List.unmodifiable(_savedRoutes);

  /// Get route by ID
  PlannedRoute? getRoute(String id) {
    try {
      return _savedRoutes.firstWhere((route) => route.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Delete a route
  Future<void> deleteRoute(String id) async {
    try {
      _savedRoutes.removeWhere((route) => route.id == id);
      await _databaseService.deletePlannedRoute(id);
      debugPrint('Deleted route: $id');
    } catch (e) {
      debugPrint('Error deleting route: $e');
      rethrow;
    }
  }

  /// Clear all routes
  Future<void> clearRoutes() async {
    try {
      _savedRoutes.clear();
      // Note: This would require a method to delete all routes from DB
      debugPrint('Cleared all routes from memory');
    } catch (e) {
      debugPrint('Error clearing routes: $e');
      rethrow;
    }
  }

  /// Load routes from database
  Future<void> loadRoutes() async {
    try {
      final List<Map<String, dynamic>> dbRoutes =
          await _databaseService.getPlannedRoutes();
      _savedRoutes.clear();
      _savedRoutes.addAll(
        dbRoutes.map(PlannedRoute.fromDatabaseMap),
      );
      debugPrint('Loaded ${_savedRoutes.length} routes from database');
    } catch (e) {
      debugPrint('Error loading routes: $e');
      rethrow;
    }
  }

  /// Clear routes from memory (does not affect database)
  /// Note: This does NOT reset the singleton instance - the service persists
  void clearMemory() {
    _savedRoutes.clear();
  }
}
