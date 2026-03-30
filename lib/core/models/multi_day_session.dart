import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/services/internationalization_service.dart';

/// Status of a multi-day session
enum MultiDaySessionStatus {
  /// Session is currently active and recording
  active,

  /// Session is paused for the day but will continue
  pausedForDay,

  /// Session is paused indefinitely
  paused,

  /// Session has been completed
  completed,

  /// Session was cancelled
  cancelled,

  /// Session is suspended due to low battery or other issues
  suspended,
}

/// A multi-day tracking session that can span multiple days with pause/resume
@immutable
class MultiDaySession {
  const MultiDaySession({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
    this.description,
    this.startedAt,
    this.completedAt,
    this.lastActiveAt,
    this.totalDistance = 0.0,
    this.totalDuration = 0,
    this.activeDuration = 0,
    this.breadcrumbCount = 0,
    this.waypointCount = 0,
    this.dayCount = 1,
    this.dailySessions = const <String>[],
    this.currentDaySessionId,
    this.plannedRoute,
    this.maxDaysAllowed = 30,
    this.autoResumeEnabled = true,
    this.autoResumeTime,
    this.autoPauseTime,
    this.batteryOptimizationEnabled = true,
    this.lowBatteryThreshold = 15,
    this.tags = const <String>[],
    this.metadata = const <String, dynamic>{},
  });

  /// Create a new multi-day session
  factory MultiDaySession.create({
    required String id,
    required String name,
    String? description,
    int maxDaysAllowed = 30,
    bool autoResumeEnabled = true,
    TimeOfDay? autoResumeTime,
    TimeOfDay? autoPauseTime,
    bool batteryOptimizationEnabled = true,
    int lowBatteryThreshold = 15,
    List<String> tags = const <String>[],
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) =>
      MultiDaySession(
        id: id,
        name: name,
        description: description,
        status: MultiDaySessionStatus.active,
        createdAt: DateTime.now(),
        maxDaysAllowed: maxDaysAllowed,
        autoResumeEnabled: autoResumeEnabled,
        autoResumeTime: autoResumeTime,
        autoPauseTime: autoPauseTime,
        batteryOptimizationEnabled: batteryOptimizationEnabled,
        lowBatteryThreshold: lowBatteryThreshold,
        tags: tags,
        metadata: metadata,
      );

  /// Create from database map
  factory MultiDaySession.fromMap(Map<String, dynamic> map) => MultiDaySession(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        status: MultiDaySessionStatus.values.firstWhere(
          (status) => status.name == map['status'],
          orElse: () => MultiDaySessionStatus.cancelled,
        ),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        startedAt: map['started_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int)
            : null,
        completedAt: map['completed_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
            : null,
        lastActiveAt: map['last_active_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['last_active_at'] as int)
            : null,
        totalDistance: map['total_distance'] as double? ?? 0.0,
        totalDuration: map['total_duration'] as int? ?? 0,
        activeDuration: map['active_duration'] as int? ?? 0,
        breadcrumbCount: map['breadcrumb_count'] as int? ?? 0,
        waypointCount: map['waypoint_count'] as int? ?? 0,
        dayCount: map['day_count'] as int? ?? 1,
        dailySessions: map['daily_sessions'] != null
            ? List<String>.from(map['daily_sessions'] as List)
            : const <String>[],
        currentDaySessionId: map['current_day_session_id'] as String?,
        plannedRoute: map['planned_route'] != null
            ? PlannedRoute.fromMap(map['planned_route'] as Map<String, dynamic>)
            : null,
        maxDaysAllowed: map['max_days_allowed'] as int? ?? 30,
        autoResumeEnabled: (map['auto_resume_enabled'] as int?) == 1,
        autoResumeTime:
            map['auto_resume_hour'] != null && map['auto_resume_minute'] != null
                ? TimeOfDay(
                    hour: map['auto_resume_hour'] as int,
                    minute: map['auto_resume_minute'] as int,
                  )
                : null,
        autoPauseTime:
            map['auto_pause_hour'] != null && map['auto_pause_minute'] != null
                ? TimeOfDay(
                    hour: map['auto_pause_hour'] as int,
                    minute: map['auto_pause_minute'] as int,
                  )
                : null,
        batteryOptimizationEnabled:
            (map['battery_optimization_enabled'] as int?) == 1,
        lowBatteryThreshold: map['low_battery_threshold'] as int? ?? 15,
        tags: map['tags'] != null
            ? List<String>.from(map['tags'] as List)
            : const <String>[],
        metadata: map['metadata'] != null
            ? Map<String, dynamic>.from(map['metadata'] as Map)
            : const <String, dynamic>{},
      );

  /// Unique identifier for this multi-day session
  final String id;

  /// User-defined name for this expedition
  final String name;

  /// Optional description of the expedition
  final String? description;

  /// Current status of the multi-day session
  final MultiDaySessionStatus status;

  /// When the session was created
  final DateTime createdAt;

  /// When tracking actually started (null if never started)
  final DateTime? startedAt;

  /// When the session was completed (null if still active)
  final DateTime? completedAt;

  /// Last time the session was active
  final DateTime? lastActiveAt;

  /// Total distance traveled across all days in meters
  final double totalDistance;

  /// Total duration including paused time in milliseconds
  final int totalDuration;

  /// Active tracking duration (excluding paused time) in milliseconds
  final int activeDuration;

  /// Total number of breadcrumbs recorded across all days
  final int breadcrumbCount;

  /// Total number of waypoints recorded across all days
  final int waypointCount;

  /// Number of days this session has been active
  final int dayCount;

  /// List of daily session IDs that belong to this multi-day session
  final List<String> dailySessions;

  /// Current day's session ID (if active)
  final String? currentDaySessionId;

  /// Planned route for this expedition (optional)
  final PlannedRoute? plannedRoute;

  /// Maximum number of days allowed for this session
  final int maxDaysAllowed;

  /// Whether to automatically resume tracking at a specific time
  final bool autoResumeEnabled;

  /// Time to automatically resume tracking each day
  final TimeOfDay? autoResumeTime;

  /// Time to automatically pause tracking each day
  final TimeOfDay? autoPauseTime;

  /// Whether battery optimization is enabled
  final bool batteryOptimizationEnabled;

  /// Battery percentage threshold for automatic suspension
  final int lowBatteryThreshold;

  /// Tags for organizing sessions
  final List<String> tags;

  /// Additional metadata
  final Map<String, dynamic> metadata;

  /// Check if the session is currently active
  bool get isActive => status == MultiDaySessionStatus.active;

  /// Check if the session is paused
  bool get isPaused =>
      status == MultiDaySessionStatus.paused ||
      status == MultiDaySessionStatus.pausedForDay;

  /// Check if the session is completed
  bool get isCompleted => status == MultiDaySessionStatus.completed;

  /// Check if the session is suspended
  bool get isSuspended => status == MultiDaySessionStatus.suspended;

  /// Check if the session can be resumed
  bool get canResume => isPaused || isSuspended;

  /// Check if the session has reached maximum days
  bool get hasReachedMaxDays => dayCount >= maxDaysAllowed;

  /// Get total duration as a Duration object
  Duration get duration => Duration(milliseconds: totalDuration);

  /// Get active duration as a Duration object
  Duration get activeDurationObject => Duration(milliseconds: activeDuration);

  /// Get average speed in m/s (null if no distance or time)
  double? get averageSpeed {
    if (totalDistance == 0 || activeDuration == 0) {
      return null;
    }
    return totalDistance / (activeDuration / 1000);
  }

  /// Get formatted total duration string (DD:HH:MM:SS)
  String get formattedTotalDuration {
    final Duration duration = Duration(milliseconds: totalDuration);
    final int days = duration.inDays;
    final int hours = duration.inHours.remainder(24);
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);

    if (days > 0) {
      return '${days}d ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Get formatted active duration string
  String get formattedActiveDuration {
    final Duration duration = Duration(milliseconds: activeDuration);
    final int days = duration.inDays;
    final int hours = duration.inHours.remainder(24);
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);

    if (days > 0) {
      return '${days}d ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Get formatted distance string (respects user's imperial/metric preference)
  String get formattedDistance =>
      InternationalizationService().formatDistance(totalDistance);

  /// Convert to map for database storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
        'status': status.name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'started_at': startedAt?.millisecondsSinceEpoch,
        'completed_at': completedAt?.millisecondsSinceEpoch,
        'last_active_at': lastActiveAt?.millisecondsSinceEpoch,
        'total_distance': totalDistance,
        'total_duration': totalDuration,
        'active_duration': activeDuration,
        'breadcrumb_count': breadcrumbCount,
        'waypoint_count': waypointCount,
        'day_count': dayCount,
        'daily_sessions': dailySessions,
        'current_day_session_id': currentDaySessionId,
        'planned_route': plannedRoute?.toMap(),
        'max_days_allowed': maxDaysAllowed,
        'auto_resume_enabled': autoResumeEnabled ? 1 : 0,
        'auto_resume_hour': autoResumeTime?.hour,
        'auto_resume_minute': autoResumeTime?.minute,
        'auto_pause_hour': autoPauseTime?.hour,
        'auto_pause_minute': autoPauseTime?.minute,
        'battery_optimization_enabled': batteryOptimizationEnabled ? 1 : 0,
        'low_battery_threshold': lowBatteryThreshold,
        'tags': tags,
        'metadata': metadata,
      };

  /// Create a copy with updated values
  MultiDaySession copyWith({
    String? id,
    String? name,
    String? description,
    MultiDaySessionStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? lastActiveAt,
    double? totalDistance,
    int? totalDuration,
    int? activeDuration,
    int? breadcrumbCount,
    int? waypointCount,
    int? dayCount,
    List<String>? dailySessions,
    String? currentDaySessionId,
    PlannedRoute? plannedRoute,
    int? maxDaysAllowed,
    bool? autoResumeEnabled,
    TimeOfDay? autoResumeTime,
    TimeOfDay? autoPauseTime,
    bool? batteryOptimizationEnabled,
    int? lowBatteryThreshold,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    bool clearCurrentDaySessionId = false,
    bool clearPlannedRoute = false,
  }) =>
      MultiDaySession(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
        totalDistance: totalDistance ?? this.totalDistance,
        totalDuration: totalDuration ?? this.totalDuration,
        activeDuration: activeDuration ?? this.activeDuration,
        breadcrumbCount: breadcrumbCount ?? this.breadcrumbCount,
        waypointCount: waypointCount ?? this.waypointCount,
        dayCount: dayCount ?? this.dayCount,
        dailySessions: dailySessions ?? this.dailySessions,
        currentDaySessionId: clearCurrentDaySessionId
            ? null
            : (currentDaySessionId ?? this.currentDaySessionId),
        plannedRoute:
            clearPlannedRoute ? null : (plannedRoute ?? this.plannedRoute),
        maxDaysAllowed: maxDaysAllowed ?? this.maxDaysAllowed,
        autoResumeEnabled: autoResumeEnabled ?? this.autoResumeEnabled,
        autoResumeTime: autoResumeTime ?? this.autoResumeTime,
        autoPauseTime: autoPauseTime ?? this.autoPauseTime,
        batteryOptimizationEnabled:
            batteryOptimizationEnabled ?? this.batteryOptimizationEnabled,
        lowBatteryThreshold: lowBatteryThreshold ?? this.lowBatteryThreshold,
        tags: tags ?? this.tags,
        metadata: metadata ?? this.metadata,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultiDaySession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MultiDaySession{id: $id, name: $name, status: $status, days: $dayCount, distance: $formattedDistance}';
}

/// A planned route for multi-day expeditions
@immutable
class PlannedRoute {
  const PlannedRoute({
    required this.id,
    required this.name,
    required this.waypoints,
    required this.createdAt,
    this.description,
    this.estimatedDistance = 0.0,
    this.estimatedDuration = 0,
    this.difficulty = RouteDifficulty.moderate,
    this.routeType = RouteType.hiking,
    this.elevationGain = 0.0,
    this.elevationLoss = 0.0,
    this.maxElevation = 0.0,
    this.minElevation = 0.0,
    this.checkpoints = const <RouteCheckpoint>[],
    this.warnings = const <String>[],
    this.tags = const <String>[],
  });

  /// Create from database map
  factory PlannedRoute.fromMap(Map<String, dynamic> map) => PlannedRoute(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        waypoints: (map['waypoints'] as List)
            .map((w) => LatLng(w['lat'] as double, w['lng'] as double))
            .toList(),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        estimatedDistance: map['estimated_distance'] as double? ?? 0.0,
        estimatedDuration: map['estimated_duration'] as int? ?? 0,
        difficulty: RouteDifficulty.values.firstWhere(
          (d) => d.name == map['difficulty'],
          orElse: () => RouteDifficulty.moderate,
        ),
        routeType: RouteType.values.firstWhere(
          (t) => t.name == map['route_type'],
          orElse: () => RouteType.hiking,
        ),
        elevationGain: map['elevation_gain'] as double? ?? 0.0,
        elevationLoss: map['elevation_loss'] as double? ?? 0.0,
        maxElevation: map['max_elevation'] as double? ?? 0.0,
        minElevation: map['min_elevation'] as double? ?? 0.0,
        checkpoints: map['checkpoints'] != null
            ? (map['checkpoints'] as List)
                .map((c) => RouteCheckpoint.fromMap(c as Map<String, dynamic>))
                .toList()
            : const <RouteCheckpoint>[],
        warnings: map['warnings'] != null
            ? List<String>.from(map['warnings'] as List)
            : const <String>[],
        tags: map['tags'] != null
            ? List<String>.from(map['tags'] as List)
            : const <String>[],
      );

  /// Unique identifier for the route
  final String id;

  /// Name of the planned route
  final String name;

  /// Description of the route
  final String? description;

  /// List of waypoints that define the route
  final List<LatLng> waypoints;

  /// When the route was created
  final DateTime createdAt;

  /// Estimated distance in meters
  final double estimatedDistance;

  /// Estimated duration in milliseconds
  final int estimatedDuration;

  /// Difficulty level of the route
  final RouteDifficulty difficulty;

  /// Type of route (hiking, cycling, etc.)
  final RouteType routeType;

  /// Total elevation gain in meters
  final double elevationGain;

  /// Total elevation loss in meters
  final double elevationLoss;

  /// Maximum elevation in meters
  final double maxElevation;

  /// Minimum elevation in meters
  final double minElevation;

  /// Important checkpoints along the route
  final List<RouteCheckpoint> checkpoints;

  /// Warnings about the route
  final List<String> warnings;

  /// Tags for organizing routes
  final List<String> tags;

  /// Convert to map for database storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
        'waypoints': waypoints
            .map((w) => {'lat': w.latitude, 'lng': w.longitude})
            .toList(),
        'created_at': createdAt.millisecondsSinceEpoch,
        'estimated_distance': estimatedDistance,
        'estimated_duration': estimatedDuration,
        'difficulty': difficulty.name,
        'route_type': routeType.name,
        'elevation_gain': elevationGain,
        'elevation_loss': elevationLoss,
        'max_elevation': maxElevation,
        'min_elevation': minElevation,
        'checkpoints': checkpoints.map((c) => c.toMap()).toList(),
        'warnings': warnings,
        'tags': tags,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedRoute &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Difficulty levels for planned routes
enum RouteDifficulty {
  easy,
  moderate,
  hard,
  expert,
  extreme,
}

/// Types of routes
enum RouteType {
  hiking,
  cycling,
  running,
  walking,
  climbing,
  skiing,
  custom,
}

/// A checkpoint along a planned route
@immutable
class RouteCheckpoint {
  const RouteCheckpoint({
    required this.id,
    required this.name,
    required this.coordinates,
    required this.distanceFromStart,
    this.description,
    this.estimatedTimeFromStart = 0,
    this.elevation = 0.0,
    this.checkpointType = CheckpointType.waypoint,
    this.isRequired = false,
    this.warnings = const <String>[],
  });

  /// Create from database map
  factory RouteCheckpoint.fromMap(Map<String, dynamic> map) => RouteCheckpoint(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        coordinates: LatLng(
          map['latitude'] as double,
          map['longitude'] as double,
        ),
        distanceFromStart: map['distance_from_start'] as double,
        estimatedTimeFromStart: map['estimated_time_from_start'] as int? ?? 0,
        elevation: map['elevation'] as double? ?? 0.0,
        checkpointType: CheckpointType.values.firstWhere(
          (t) => t.name == map['checkpoint_type'],
          orElse: () => CheckpointType.waypoint,
        ),
        isRequired: (map['is_required'] as int?) == 1,
        warnings: map['warnings'] != null
            ? List<String>.from(map['warnings'] as List)
            : const <String>[],
      );

  /// Unique identifier for the checkpoint
  final String id;

  /// Name of the checkpoint
  final String name;

  /// Description of the checkpoint
  final String? description;

  /// Geographic coordinates
  final LatLng coordinates;

  /// Distance from route start in meters
  final double distanceFromStart;

  /// Estimated time from start in milliseconds
  final int estimatedTimeFromStart;

  /// Elevation at this checkpoint in meters
  final double elevation;

  /// Type of checkpoint
  final CheckpointType checkpointType;

  /// Whether this checkpoint is required to be visited
  final bool isRequired;

  /// Warnings specific to this checkpoint
  final List<String> warnings;

  /// Convert to map for database storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
        'latitude': coordinates.latitude,
        'longitude': coordinates.longitude,
        'distance_from_start': distanceFromStart,
        'estimated_time_from_start': estimatedTimeFromStart,
        'elevation': elevation,
        'checkpoint_type': checkpointType.name,
        'is_required': isRequired ? 1 : 0,
        'warnings': warnings,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteCheckpoint &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Types of route checkpoints
enum CheckpointType {
  waypoint,
  restStop,
  waterSource,
  campsite,
  viewpoint,
  hazard,
  junction,
  summit,
  shelter,
  resupply,
}

/// Time of day helper class
@immutable
class TimeOfDay {
  const TimeOfDay({required this.hour, required this.minute});

  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeOfDay &&
          runtimeType == other.runtimeType &&
          hour == other.hour &&
          minute == other.minute;

  @override
  int get hashCode => hour.hashCode ^ minute.hashCode;

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
