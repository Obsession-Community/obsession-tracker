import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/multi_day_session.dart';

/// Service for trail planning, route comparison, and navigation assistance
class TrailPlanningService {
  TrailPlanningService._();

  static final TrailPlanningService _instance = TrailPlanningService._();
  static TrailPlanningService get instance => _instance;

  Timer? _deviationCheckTimer;
  bool _isInitialized = false;

  // Navigation state
  PlannedRoute? _activeRoute;
  final List<Breadcrumb> _actualPath = <Breadcrumb>[];
  RouteProgress? _currentProgress;
  final List<RouteDeviation> _deviations = <RouteDeviation>[];
  final StreamController<NavigationUpdate> _navigationController =
      StreamController<NavigationUpdate>.broadcast();

  /// Stream of navigation updates
  Stream<NavigationUpdate> get navigationUpdates =>
      _navigationController.stream;

  /// Initialize the trail planning service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;
    debugPrint('TrailPlanningService initialized');
  }

  /// Dispose of the service
  void dispose() {
    _deviationCheckTimer?.cancel();
    _navigationController.close();
    _isInitialized = false;
  }

  /// Create a new planned route
  Future<PlannedRoute> createPlannedRoute({
    required String name,
    required List<LatLng> waypoints,
    String? description,
    RouteDifficulty difficulty = RouteDifficulty.moderate,
    RouteType routeType = RouteType.hiking,
    List<RouteCheckpoint> checkpoints = const [],
    List<String> warnings = const [],
    List<String> tags = const [],
  }) async {
    final String routeId = DateTime.now().millisecondsSinceEpoch.toString();

    // Calculate route statistics
    final RouteStatistics stats = await _calculateRouteStatistics(waypoints);

    final PlannedRoute route = PlannedRoute(
      id: routeId,
      name: name,
      description: description,
      waypoints: waypoints,
      createdAt: DateTime.now(),
      estimatedDistance: stats.totalDistance,
      estimatedDuration: stats.estimatedDuration,
      difficulty: difficulty,
      routeType: routeType,
      elevationGain: stats.elevationGain,
      elevationLoss: stats.elevationLoss,
      maxElevation: stats.maxElevation,
      minElevation: stats.minElevation,
      checkpoints: checkpoints,
      warnings: warnings,
      tags: tags,
    );

    // Save to database (would need to implement this method)
    // await _databaseService.insertPlannedRoute(route);

    return route;
  }

  /// Start navigation with a planned route
  Future<void> startNavigation(PlannedRoute route) async {
    _activeRoute = route;
    _actualPath.clear();
    _deviations.clear();
    _currentProgress = RouteProgress.initial(route);

    // Start deviation monitoring
    _startDeviationMonitoring();

    _navigationController.add(NavigationUpdate(
      type: NavigationUpdateType.routeStarted,
      route: route,
      progress: _currentProgress!,
    ));

    debugPrint('Navigation started for route: ${route.name}');
  }

  /// Stop navigation
  Future<void> stopNavigation() async {
    _deviationCheckTimer?.cancel();

    if (_activeRoute != null && _currentProgress != null) {
      final route = _activeRoute!;
      final RouteComparison comparison = await generateRouteComparison(
        route,
        _actualPath,
      );

      _navigationController.add(NavigationUpdate(
        type: NavigationUpdateType.routeCompleted,
        route: route,
        progress: _currentProgress!,
        comparison: comparison,
      ));
    }

    _activeRoute = null;
    _actualPath.clear();
    _deviations.clear();
    _currentProgress = null;

    debugPrint('Navigation stopped');
  }

  /// Update current position during navigation
  Future<void> updatePosition(Position position) async {
    if (_activeRoute == null || _currentProgress == null) return;

    final route = _activeRoute!; // Null-checked above
    final LatLng currentLocation =
        LatLng(position.latitude, position.longitude);

    // Add to actual path
    final Breadcrumb breadcrumb = Breadcrumb.fromPosition(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: DateTime.now(),
      sessionId: 'navigation_${route.id}',
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
    );
    _actualPath.add(breadcrumb);

    // Update progress
    _currentProgress = _calculateProgress(currentLocation);

    // Check for deviations
    final RouteDeviation? deviation = _checkForDeviation(currentLocation);
    if (deviation != null) {
      _deviations.add(deviation);
      _navigationController.add(NavigationUpdate(
        type: NavigationUpdateType.deviationDetected,
        route: route,
        progress: _currentProgress!,
        deviation: deviation,
      ));
    }

    // Check for checkpoint arrivals
    final RouteCheckpoint? arrivedCheckpoint =
        _checkCheckpointArrival(currentLocation);
    if (arrivedCheckpoint != null) {
      _navigationController.add(NavigationUpdate(
        type: NavigationUpdateType.checkpointReached,
        route: route,
        progress: _currentProgress!,
        checkpoint: arrivedCheckpoint,
      ));
    }

    // Send progress update
    _navigationController.add(NavigationUpdate(
      type: NavigationUpdateType.progressUpdate,
      route: route,
      progress: _currentProgress!,
    ));
  }

  /// Generate route comparison between planned and actual
  Future<RouteComparison> generateRouteComparison(
    PlannedRoute plannedRoute,
    List<Breadcrumb> actualPath,
  ) async {
    if (actualPath.isEmpty) {
      return RouteComparison.empty(plannedRoute);
    }

    // Calculate actual route statistics
    final double actualDistance = _calculateActualDistance(actualPath);
    final Duration actualDuration = _calculateActualDuration(actualPath);
    final double averageSpeed = actualDistance / actualDuration.inSeconds;

    // Calculate deviations
    final List<RouteDeviation> allDeviations = await _analyzeDeviations(
      plannedRoute,
      actualPath,
    );

    // Calculate efficiency metrics
    final double routeEfficiency =
        plannedRoute.estimatedDistance / actualDistance;
    final double timeEfficiency =
        plannedRoute.estimatedDuration / actualDuration.inMilliseconds;

    // Analyze checkpoint performance
    final List<CheckpointPerformance> checkpointPerformance =
        _analyzeCheckpointPerformance(plannedRoute, actualPath);

    return RouteComparison(
      plannedRoute: plannedRoute,
      actualPath: actualPath,
      actualDistance: actualDistance,
      actualDuration: actualDuration,
      averageSpeed: averageSpeed,
      deviations: allDeviations,
      routeEfficiency: routeEfficiency,
      timeEfficiency: timeEfficiency,
      checkpointPerformance: checkpointPerformance,
      completedAt: DateTime.now(),
    );
  }

  /// Get navigation instructions for current position
  List<NavigationInstruction> getNavigationInstructions(
      LatLng currentPosition) {
    if (_activeRoute == null || _currentProgress == null) return [];

    final List<NavigationInstruction> instructions = <NavigationInstruction>[];
    final List<LatLng> waypoints = _activeRoute!.waypoints;
    final int nextWaypointIndex = _currentProgress!.nextWaypointIndex;

    if (nextWaypointIndex < waypoints.length) {
      final LatLng nextWaypoint = waypoints[nextWaypointIndex];
      final double distance = const Distance().as(
        LengthUnit.Meter,
        currentPosition,
        nextWaypoint,
      );
      final double bearing =
          const Distance().bearing(currentPosition, nextWaypoint);

      instructions.add(NavigationInstruction(
        type: InstructionType.proceed,
        description: 'Continue ${_formatDistance(distance)} to next waypoint',
        distance: distance,
        bearing: bearing,
        waypoint: nextWaypoint,
      ));

      // Add turn instructions if needed
      if (nextWaypointIndex + 1 < waypoints.length) {
        final LatLng followingWaypoint = waypoints[nextWaypointIndex + 1];
        final double nextBearing =
            const Distance().bearing(nextWaypoint, followingWaypoint);
        final double turnAngle = (nextBearing - bearing + 360) % 360;

        if (turnAngle > 30 && turnAngle < 330) {
          final String turnDirection = turnAngle < 180 ? 'right' : 'left';
          instructions.add(NavigationInstruction(
            type: InstructionType.turn,
            description: 'Turn $turnDirection at next waypoint',
            distance: distance,
            bearing: nextBearing,
            waypoint: followingWaypoint,
          ));
        }
      }
    }

    return instructions;
  }

  /// Calculate route statistics
  Future<RouteStatistics> _calculateRouteStatistics(
      List<LatLng> waypoints) async {
    if (waypoints.length < 2) {
      return const RouteStatistics();
    }

    double totalDistance = 0.0;
    double elevationGain = 0.0;
    double elevationLoss = 0.0;
    double maxElevation = 0.0;
    double minElevation = double.infinity;

    for (int i = 1; i < waypoints.length; i++) {
      final double segmentDistance = const Distance().as(
        LengthUnit.Meter,
        waypoints[i - 1],
        waypoints[i],
      );
      totalDistance += segmentDistance;

      // For elevation, we'd need elevation data - using placeholder for now
      // In a real implementation, you'd query elevation services
      const double elevation1 = 0.0; // await _getElevation(waypoints[i - 1]);
      const double elevation2 = 0.0; // await _getElevation(waypoints[i]);

      const double elevationDiff = elevation2 - elevation1;
      if (elevationDiff > 0) {
        elevationGain += elevationDiff;
      } else {
        elevationLoss += elevationDiff.abs();
      }

      maxElevation = math.max(maxElevation, math.max(elevation1, elevation2));
      minElevation = math.min(minElevation, math.min(elevation1, elevation2));
    }

    // Estimate duration based on distance and terrain
    final int estimatedDuration =
        _estimateDuration(totalDistance, elevationGain);

    return RouteStatistics(
      totalDistance: totalDistance,
      estimatedDuration: estimatedDuration,
      elevationGain: elevationGain,
      elevationLoss: elevationLoss,
      maxElevation: maxElevation,
      minElevation: minElevation == double.infinity ? 0.0 : minElevation,
    );
  }

  /// Start monitoring for route deviations
  void _startDeviationMonitoring() {
    _deviationCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      // Deviation checking is handled in updatePosition
      // This timer could be used for other periodic checks
    });
  }

  /// Calculate current progress along the route
  RouteProgress _calculateProgress(LatLng currentPosition) {
    if (_activeRoute == null) {
      throw StateError('No active route');
    }

    final List<LatLng> waypoints = _activeRoute!.waypoints;
    double totalDistance = 0.0;
    double completedDistance = 0.0;
    int nextWaypointIndex = 0;

    // Calculate total route distance
    for (int i = 1; i < waypoints.length; i++) {
      totalDistance += const Distance().as(
        LengthUnit.Meter,
        waypoints[i - 1],
        waypoints[i],
      );
    }

    // Find closest point on route and calculate completed distance
    double minDistanceToRoute = double.infinity;
    for (int i = 1; i < waypoints.length; i++) {
      final double segmentDistance = const Distance().as(
        LengthUnit.Meter,
        waypoints[i - 1],
        waypoints[i],
      );

      final double distanceToSegment = _distanceToLineSegment(
        currentPosition,
        waypoints[i - 1],
        waypoints[i],
      );

      if (distanceToSegment < minDistanceToRoute) {
        minDistanceToRoute = distanceToSegment;
        nextWaypointIndex = i;

        // Calculate completed distance up to this segment
        completedDistance = 0.0;
        for (int j = 1; j < i; j++) {
          completedDistance += const Distance().as(
            LengthUnit.Meter,
            waypoints[j - 1],
            waypoints[j],
          );
        }

        // Add partial distance along current segment
        final double distanceAlongSegment = const Distance().as(
          LengthUnit.Meter,
          waypoints[i - 1],
          currentPosition,
        );
        completedDistance += math.min(distanceAlongSegment, segmentDistance);
      }
    }

    final double progressPercentage = totalDistance > 0
        ? (completedDistance / totalDistance).clamp(0.0, 1.0)
        : 0.0;

    return RouteProgress(
      totalDistance: totalDistance,
      completedDistance: completedDistance,
      remainingDistance: totalDistance - completedDistance,
      progressPercentage: progressPercentage,
      nextWaypointIndex: nextWaypointIndex,
      distanceToRoute: minDistanceToRoute,
      estimatedTimeRemaining: _estimateTimeRemaining(
        totalDistance - completedDistance,
        0.0, // elevation gain remaining - would need calculation
      ),
    );
  }

  /// Check for route deviation
  RouteDeviation? _checkForDeviation(LatLng currentPosition) {
    if (_activeRoute == null || _currentProgress == null) return null;

    const double maxDeviationDistance = 100.0; // meters
    final double distanceToRoute = _currentProgress!.distanceToRoute;

    if (distanceToRoute > maxDeviationDistance) {
      return RouteDeviation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        position: currentPosition,
        distanceFromRoute: distanceToRoute,
        timestamp: DateTime.now(),
        severity: _getDeviationSeverity(distanceToRoute),
        suggestedAction: _getSuggestedAction(distanceToRoute),
      );
    }

    return null;
  }

  /// Check if arrived at a checkpoint
  RouteCheckpoint? _checkCheckpointArrival(LatLng currentPosition) {
    if (_activeRoute == null) return null;

    const double arrivalThreshold = 50.0; // meters

    for (final RouteCheckpoint checkpoint in _activeRoute!.checkpoints) {
      final double distance = const Distance().as(
        LengthUnit.Meter,
        currentPosition,
        checkpoint.coordinates,
      );

      if (distance <= arrivalThreshold) {
        return checkpoint;
      }
    }

    return null;
  }

  /// Calculate actual distance traveled
  double _calculateActualDistance(List<Breadcrumb> path) {
    if (path.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 1; i < path.length; i++) {
      totalDistance += path[i - 1].distanceTo(path[i]);
    }
    return totalDistance;
  }

  /// Calculate actual duration
  Duration _calculateActualDuration(List<Breadcrumb> path) {
    if (path.length < 2) return Duration.zero;

    final DateTime start = path.first.timestamp;
    final DateTime end = path.last.timestamp;
    return end.difference(start);
  }

  /// Analyze all deviations in the route
  Future<List<RouteDeviation>> _analyzeDeviations(
    PlannedRoute plannedRoute,
    List<Breadcrumb> actualPath,
  ) async {
    final List<RouteDeviation> deviations = <RouteDeviation>[];

    for (final Breadcrumb breadcrumb in actualPath) {
      final double distanceToRoute = _calculateDistanceToRoute(
        breadcrumb.coordinates,
        plannedRoute.waypoints,
      );

      if (distanceToRoute > 50.0) {
        // 50m threshold
        deviations.add(RouteDeviation(
          id: '${breadcrumb.id}_deviation',
          position: breadcrumb.coordinates,
          distanceFromRoute: distanceToRoute,
          timestamp: breadcrumb.timestamp,
          severity: _getDeviationSeverity(distanceToRoute),
          suggestedAction: _getSuggestedAction(distanceToRoute),
        ));
      }
    }

    return deviations;
  }

  /// Analyze checkpoint performance
  List<CheckpointPerformance> _analyzeCheckpointPerformance(
    PlannedRoute plannedRoute,
    List<Breadcrumb> actualPath,
  ) {
    final List<CheckpointPerformance> performance = <CheckpointPerformance>[];

    for (final RouteCheckpoint checkpoint in plannedRoute.checkpoints) {
      // Find closest approach to checkpoint
      double minDistance = double.infinity;
      DateTime? arrivalTime;
      bool wasReached = false;

      for (final Breadcrumb breadcrumb in actualPath) {
        final double distance = const Distance().as(
          LengthUnit.Meter,
          breadcrumb.coordinates,
          checkpoint.coordinates,
        );

        if (distance < minDistance) {
          minDistance = distance;
          arrivalTime = breadcrumb.timestamp;
        }

        if (distance <= 50.0) {
          // 50m arrival threshold
          wasReached = true;
        }
      }

      performance.add(CheckpointPerformance(
        checkpoint: checkpoint,
        wasReached: wasReached,
        closestDistance: minDistance,
        arrivalTime: arrivalTime,
        timeDifference:
            arrivalTime != null && checkpoint.estimatedTimeFromStart > 0
                ? arrivalTime.difference(
                    plannedRoute.createdAt.add(
                      Duration(milliseconds: checkpoint.estimatedTimeFromStart),
                    ),
                  )
                : null,
      ));
    }

    return performance;
  }

  /// Calculate distance from point to route
  double _calculateDistanceToRoute(LatLng point, List<LatLng> routeWaypoints) {
    if (routeWaypoints.length < 2) return double.infinity;

    double minDistance = double.infinity;
    for (int i = 1; i < routeWaypoints.length; i++) {
      final double distance = _distanceToLineSegment(
        point,
        routeWaypoints[i - 1],
        routeWaypoints[i],
      );
      minDistance = math.min(minDistance, distance);
    }

    return minDistance;
  }

  /// Calculate distance from point to line segment
  double _distanceToLineSegment(
      LatLng point, LatLng lineStart, LatLng lineEnd) {
    // Simplified calculation - in a real implementation you'd use proper
    // great circle distance calculations
    final double A = point.latitude - lineStart.latitude;
    final double B = point.longitude - lineStart.longitude;
    final double C = lineEnd.latitude - lineStart.latitude;
    final double D = lineEnd.longitude - lineStart.longitude;

    final double dot = A * C + B * D;
    final double lenSq = C * C + D * D;

    if (lenSq == 0) {
      return const Distance().as(LengthUnit.Meter, point, lineStart);
    }

    final double param = dot / lenSq;

    LatLng closestPoint;
    if (param < 0) {
      closestPoint = lineStart;
    } else if (param > 1) {
      closestPoint = lineEnd;
    } else {
      closestPoint = LatLng(
        lineStart.latitude + param * C,
        lineStart.longitude + param * D,
      );
    }

    return const Distance().as(LengthUnit.Meter, point, closestPoint);
  }

  /// Estimate duration based on distance and elevation
  int _estimateDuration(double distance, double elevationGain) {
    // Naismith's rule: 1 hour for every 5km + 1 hour for every 600m of ascent
    final double baseTime = distance / 1000 / 5; // hours
    final double elevationTime = elevationGain / 600; // hours
    return ((baseTime + elevationTime) * 3600 * 1000).round(); // milliseconds
  }

  /// Estimate time remaining
  Duration _estimateTimeRemaining(
      double remainingDistance, double remainingElevation) {
    final int milliseconds =
        _estimateDuration(remainingDistance, remainingElevation);
    return Duration(milliseconds: milliseconds);
  }

  /// Get deviation severity
  DeviationSeverity _getDeviationSeverity(double distance) {
    if (distance < 50) return DeviationSeverity.minor;
    if (distance < 100) return DeviationSeverity.moderate;
    if (distance < 200) return DeviationSeverity.major;
    return DeviationSeverity.critical;
  }

  /// Get suggested action for deviation
  String _getSuggestedAction(double distance) {
    if (distance < 100) return 'Return to planned route when safe';
    if (distance < 200) return 'Check map and navigate back to route';
    return 'Stop and reassess your position - you may be significantly off route';
  }

  /// Format distance for display
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }
}

/// Statistics for a planned route
@immutable
class RouteStatistics {
  const RouteStatistics({
    this.totalDistance = 0.0,
    this.estimatedDuration = 0,
    this.elevationGain = 0.0,
    this.elevationLoss = 0.0,
    this.maxElevation = 0.0,
    this.minElevation = 0.0,
  });

  final double totalDistance;
  final int estimatedDuration;
  final double elevationGain;
  final double elevationLoss;
  final double maxElevation;
  final double minElevation;
}

/// Progress along a route
@immutable
class RouteProgress {
  const RouteProgress({
    required this.totalDistance,
    required this.completedDistance,
    required this.remainingDistance,
    required this.progressPercentage,
    required this.nextWaypointIndex,
    required this.distanceToRoute,
    required this.estimatedTimeRemaining,
  });

  factory RouteProgress.initial(PlannedRoute route) => RouteProgress(
        totalDistance: route.estimatedDistance,
        completedDistance: 0.0,
        remainingDistance: route.estimatedDistance,
        progressPercentage: 0.0,
        nextWaypointIndex: 0,
        distanceToRoute: 0.0,
        estimatedTimeRemaining: Duration(milliseconds: route.estimatedDuration),
      );

  final double totalDistance;
  final double completedDistance;
  final double remainingDistance;
  final double progressPercentage;
  final int nextWaypointIndex;
  final double distanceToRoute;
  final Duration estimatedTimeRemaining;
}

/// A deviation from the planned route
@immutable
class RouteDeviation {
  const RouteDeviation({
    required this.id,
    required this.position,
    required this.distanceFromRoute,
    required this.timestamp,
    required this.severity,
    required this.suggestedAction,
  });

  final String id;
  final LatLng position;
  final double distanceFromRoute;
  final DateTime timestamp;
  final DeviationSeverity severity;
  final String suggestedAction;
}

/// Severity levels for route deviations
enum DeviationSeverity {
  minor,
  moderate,
  major,
  critical,
}

/// Navigation update types
enum NavigationUpdateType {
  routeStarted,
  progressUpdate,
  deviationDetected,
  checkpointReached,
  routeCompleted,
}

/// Navigation update
@immutable
class NavigationUpdate {
  const NavigationUpdate({
    required this.type,
    required this.route,
    required this.progress,
    this.deviation,
    this.checkpoint,
    this.comparison,
  });

  final NavigationUpdateType type;
  final PlannedRoute route;
  final RouteProgress progress;
  final RouteDeviation? deviation;
  final RouteCheckpoint? checkpoint;
  final RouteComparison? comparison;
}

/// Navigation instruction
@immutable
class NavigationInstruction {
  const NavigationInstruction({
    required this.type,
    required this.description,
    required this.distance,
    required this.bearing,
    required this.waypoint,
  });

  final InstructionType type;
  final String description;
  final double distance;
  final double bearing;
  final LatLng waypoint;
}

/// Types of navigation instructions
enum InstructionType {
  proceed,
  turn,
  arrive,
  warning,
}

/// Comparison between planned and actual route
@immutable
class RouteComparison {
  const RouteComparison({
    required this.plannedRoute,
    required this.actualPath,
    required this.actualDistance,
    required this.actualDuration,
    required this.averageSpeed,
    required this.deviations,
    required this.routeEfficiency,
    required this.timeEfficiency,
    required this.checkpointPerformance,
    required this.completedAt,
  });

  factory RouteComparison.empty(PlannedRoute plannedRoute) => RouteComparison(
        plannedRoute: plannedRoute,
        actualPath: const [],
        actualDistance: 0.0,
        actualDuration: Duration.zero,
        averageSpeed: 0.0,
        deviations: const [],
        routeEfficiency: 0.0,
        timeEfficiency: 0.0,
        checkpointPerformance: const [],
        completedAt: DateTime.now(),
      );

  final PlannedRoute plannedRoute;
  final List<Breadcrumb> actualPath;
  final double actualDistance;
  final Duration actualDuration;
  final double averageSpeed;
  final List<RouteDeviation> deviations;
  final double routeEfficiency;
  final double timeEfficiency;
  final List<CheckpointPerformance> checkpointPerformance;
  final DateTime completedAt;
}

/// Performance at a checkpoint
@immutable
class CheckpointPerformance {
  const CheckpointPerformance({
    required this.checkpoint,
    required this.wasReached,
    required this.closestDistance,
    this.arrivalTime,
    this.timeDifference,
  });

  final RouteCheckpoint checkpoint;
  final bool wasReached;
  final double closestDistance;
  final DateTime? arrivalTime;
  final Duration? timeDifference;
}
