import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/services/internationalization_service.dart';

/// Status of a tracking session
enum SessionStatus {
  /// Session is currently recording GPS data
  active,

  /// Session has been paused by user
  paused,

  /// Session has been completed and saved
  completed,

  /// Session was stopped without being saved
  cancelled,
}

/// A GPS tracking session containing metadata and settings.
///
/// Represents a complete adventure tracking session with start/end times,
/// distance calculations, and session settings for privacy-first tracking.
@immutable
class TrackingSession {
  const TrackingSession({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
    this.description,
    this.startedAt,
    this.completedAt,
    this.totalDistance = 0.0,
    this.totalDuration = 0,
    this.breadcrumbCount = 0,
    this.accuracyThreshold = 10.0,
    this.recordingInterval = 5,
    this.startLocation,
    this.endLocation,
    this.minimumSpeed = 0.0,
    this.recordAltitude = true,
    this.recordSpeed = true,
    this.recordHeading = true,
    this.plannedRouteId,
    this.plannedRouteSnapshot,
    // Hunt association
    this.huntId,
    // Elevation tracking
    this.elevationGain = 0.0,
    this.elevationLoss = 0.0,
    this.maxAltitude,
    this.minAltitude,
    // Speed tracking
    this.maxSpeed,
  });

  /// Create a new session with default settings
  factory TrackingSession.create({
    required String id,
    required String name,
    String? description,
    double accuracyThreshold = 10.0,
    int recordingInterval = 5,
    double minimumSpeed = 0.0,
    bool recordAltitude = true,
    bool recordSpeed = true,
    bool recordHeading = true,
    String? plannedRouteId,
    String? plannedRouteSnapshot,
    String? huntId,
  }) =>
      TrackingSession(
        id: id,
        name: name,
        description: description,
        status: SessionStatus.active,
        createdAt: DateTime.now(),
        accuracyThreshold: accuracyThreshold,
        recordingInterval: recordingInterval,
        minimumSpeed: minimumSpeed,
        recordAltitude: recordAltitude,
        recordSpeed: recordSpeed,
        recordHeading: recordHeading,
        plannedRouteId: plannedRouteId,
        plannedRouteSnapshot: plannedRouteSnapshot,
        huntId: huntId,
      );

  /// Create session from database map
  factory TrackingSession.fromMap(Map<String, dynamic> map) => TrackingSession(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        status: SessionStatus.values.firstWhere(
          (SessionStatus e) => e.name == map['status'],
          orElse: () => SessionStatus.cancelled,
        ),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        startedAt: map['started_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int)
            : null,
        completedAt: map['completed_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
            : null,
        totalDistance: map['total_distance'] as double,
        totalDuration: map['total_duration'] as int,
        breadcrumbCount: map['breadcrumb_count'] as int,
        accuracyThreshold: map['accuracy_threshold'] as double,
        recordingInterval: map['recording_interval'] as int,
        startLocation:
            map['start_latitude'] != null && map['start_longitude'] != null
                ? LatLng(map['start_latitude'] as double,
                    map['start_longitude'] as double)
                : null,
        endLocation: map['end_latitude'] != null && map['end_longitude'] != null
            ? LatLng(
                map['end_latitude'] as double, map['end_longitude'] as double)
            : null,
        minimumSpeed: map['minimum_speed'] as double,
        recordAltitude: (map['record_altitude'] as int) == 1,
        recordSpeed: (map['record_speed'] as int) == 1,
        recordHeading: (map['record_heading'] as int) == 1,
        plannedRouteId: map['planned_route_id'] as String?,
        plannedRouteSnapshot: map['planned_route_snapshot'] as String?,
        huntId: map['hunt_id'] as String?,
        elevationGain: (map['elevation_gain'] as num?)?.toDouble() ?? 0.0,
        elevationLoss: (map['elevation_loss'] as num?)?.toDouble() ?? 0.0,
        maxAltitude: (map['max_altitude'] as num?)?.toDouble(),
        minAltitude: (map['min_altitude'] as num?)?.toDouble(),
        maxSpeed: (map['max_speed'] as num?)?.toDouble(),
      );

  /// Unique identifier for this session
  final String id;

  /// User-defined name for this adventure
  final String name;

  /// Optional description of the adventure
  final String? description;

  /// Current status of the session
  final SessionStatus status;

  /// When the session was created
  final DateTime createdAt;

  /// When tracking actually started (null if never started)
  final DateTime? startedAt;

  /// When the session was completed (null if still active)
  final DateTime? completedAt;

  /// Total distance traveled in meters
  final double totalDistance;

  /// Total duration of active tracking in milliseconds
  final int totalDuration;

  /// Number of breadcrumbs recorded
  final int breadcrumbCount;

  /// GPS accuracy threshold for recording breadcrumbs (meters)
  final double accuracyThreshold;

  /// Recording interval in seconds (5-30 seconds)
  final int recordingInterval;

  /// Starting location (set when tracking begins)
  final LatLng? startLocation;

  /// Ending location (set when tracking completes)
  final LatLng? endLocation;

  /// Minimum speed to record breadcrumb (m/s, 0 to record all)
  final double minimumSpeed;

  /// Whether to record altitude data
  final bool recordAltitude;

  /// Whether to record speed data
  final bool recordSpeed;

  /// Whether to record heading data
  final bool recordHeading;

  /// Optional planned route ID this session follows
  final String? plannedRouteId;

  /// Snapshot of the planned route data (JSON) to preserve if route is deleted
  final String? plannedRouteSnapshot;

  /// Optional hunt ID this session is associated with
  final String? huntId;

  /// Total elevation gain in meters (sum of all climbs)
  final double elevationGain;

  /// Total elevation loss in meters (sum of all descents)
  final double elevationLoss;

  /// Maximum altitude reached in meters
  final double? maxAltitude;

  /// Minimum altitude reached in meters
  final double? minAltitude;

  /// Maximum speed recorded in m/s
  final double? maxSpeed;

  /// Convert session to map for database storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
        'status': status.name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'started_at': startedAt?.millisecondsSinceEpoch,
        'completed_at': completedAt?.millisecondsSinceEpoch,
        'total_distance': totalDistance,
        'total_duration': totalDuration,
        'breadcrumb_count': breadcrumbCount,
        'accuracy_threshold': accuracyThreshold,
        'recording_interval': recordingInterval,
        'start_latitude': startLocation?.latitude,
        'start_longitude': startLocation?.longitude,
        'end_latitude': endLocation?.latitude,
        'end_longitude': endLocation?.longitude,
        'minimum_speed': minimumSpeed,
        'record_altitude': recordAltitude ? 1 : 0,
        'record_speed': recordSpeed ? 1 : 0,
        'record_heading': recordHeading ? 1 : 0,
        'planned_route_id': plannedRouteId,
        'planned_route_snapshot': plannedRouteSnapshot,
        'hunt_id': huntId,
        'elevation_gain': elevationGain,
        'elevation_loss': elevationLoss,
        'max_altitude': maxAltitude,
        'min_altitude': minAltitude,
        'max_speed': maxSpeed,
      };

  /// Check if the session is currently recording
  bool get isActive => status == SessionStatus.active;

  /// Check if the session is paused
  bool get isPaused => status == SessionStatus.paused;

  /// Check if the session is completed
  bool get isCompleted => status == SessionStatus.completed;

  /// Get total duration as a Duration object
  /// For active sessions, calculates live duration from startedAt
  /// For completed sessions, uses the stored totalDuration
  Duration get duration {
    // If session is active and has started, calculate live duration
    if (status == SessionStatus.active && startedAt != null) {
      return DateTime.now().difference(startedAt!);
    }
    // For completed/paused sessions, use stored duration
    return Duration(milliseconds: totalDuration);
  }

  /// Get the current duration in milliseconds (live for active, stored for completed)
  int get currentDurationMs {
    if (status == SessionStatus.active && startedAt != null) {
      return DateTime.now().difference(startedAt!).inMilliseconds;
    }
    return totalDuration;
  }

  /// Get average speed in m/s (null if no distance or time)
  /// Uses live duration for active sessions
  double? get averageSpeed {
    final int durationMs = currentDurationMs;
    if (totalDistance == 0 || durationMs == 0) {
      return null;
    }
    return totalDistance / (durationMs / 1000);
  }

  /// Get formatted duration string (HH:MM:SS)
  /// Uses live duration for active sessions
  String get formattedDuration {
    final Duration dur = duration; // Uses the dynamic duration getter
    final int hours = dur.inHours;
    final int minutes = dur.inMinutes.remainder(60);
    final int seconds = dur.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Get formatted distance string (respects user's imperial/metric preference)
  String get formattedDistance =>
      InternationalizationService().formatDistance(totalDistance);

  /// Get formatted elevation gain string
  String get formattedElevationGain =>
      InternationalizationService().formatAltitude(elevationGain);

  /// Get formatted elevation loss string
  String get formattedElevationLoss =>
      InternationalizationService().formatAltitude(elevationLoss);

  /// Get formatted max altitude string
  String? get formattedMaxAltitude => maxAltitude != null
      ? InternationalizationService().formatAltitude(maxAltitude!)
      : null;

  /// Get formatted min altitude string
  String? get formattedMinAltitude => minAltitude != null
      ? InternationalizationService().formatAltitude(minAltitude!)
      : null;

  /// Get formatted max speed string
  String? get formattedMaxSpeed => maxSpeed != null
      ? InternationalizationService().formatSpeed(maxSpeed!)
      : null;

  /// Get formatted average speed string
  String? get formattedAverageSpeed => averageSpeed != null
      ? InternationalizationService().formatSpeed(averageSpeed!)
      : null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackingSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'TrackingSession{id: $id, name: $name, status: $status, distance: $formattedDistance, duration: $formattedDuration}';

  /// Create a copy of this session with updated values
  ///
  /// For nullable fields (description, huntId, etc.), use the clearX parameter
  /// to explicitly set the field to null. For example:
  /// - `copyWith(huntId: 'abc')` sets huntId to 'abc'
  /// - `copyWith(clearHuntId: true)` sets huntId to null
  /// - `copyWith()` leaves huntId unchanged
  TrackingSession copyWith({
    String? id,
    String? name,
    String? description,
    bool clearDescription = false,
    SessionStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    double? totalDistance,
    int? totalDuration,
    int? breadcrumbCount,
    double? accuracyThreshold,
    int? recordingInterval,
    LatLng? startLocation,
    bool clearStartLocation = false,
    LatLng? endLocation,
    bool clearEndLocation = false,
    double? minimumSpeed,
    bool? recordAltitude,
    bool? recordSpeed,
    bool? recordHeading,
    String? plannedRouteId,
    bool clearPlannedRouteId = false,
    String? plannedRouteSnapshot,
    bool clearPlannedRouteSnapshot = false,
    String? huntId,
    bool clearHuntId = false,
    double? elevationGain,
    double? elevationLoss,
    double? maxAltitude,
    bool clearMaxAltitude = false,
    double? minAltitude,
    bool clearMinAltitude = false,
    double? maxSpeed,
    bool clearMaxSpeed = false,
  }) =>
      TrackingSession(
        id: id ?? this.id,
        name: name ?? this.name,
        description: clearDescription ? null : (description ?? this.description),
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
        completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
        totalDistance: totalDistance ?? this.totalDistance,
        totalDuration: totalDuration ?? this.totalDuration,
        breadcrumbCount: breadcrumbCount ?? this.breadcrumbCount,
        accuracyThreshold: accuracyThreshold ?? this.accuracyThreshold,
        recordingInterval: recordingInterval ?? this.recordingInterval,
        startLocation: clearStartLocation ? null : (startLocation ?? this.startLocation),
        endLocation: clearEndLocation ? null : (endLocation ?? this.endLocation),
        minimumSpeed: minimumSpeed ?? this.minimumSpeed,
        recordAltitude: recordAltitude ?? this.recordAltitude,
        recordSpeed: recordSpeed ?? this.recordSpeed,
        recordHeading: recordHeading ?? this.recordHeading,
        plannedRouteId: clearPlannedRouteId ? null : (plannedRouteId ?? this.plannedRouteId),
        plannedRouteSnapshot: clearPlannedRouteSnapshot ? null : (plannedRouteSnapshot ?? this.plannedRouteSnapshot),
        huntId: clearHuntId ? null : (huntId ?? this.huntId),
        elevationGain: elevationGain ?? this.elevationGain,
        elevationLoss: elevationLoss ?? this.elevationLoss,
        maxAltitude: clearMaxAltitude ? null : (maxAltitude ?? this.maxAltitude),
        minAltitude: clearMinAltitude ? null : (minAltitude ?? this.minAltitude),
        maxSpeed: clearMaxSpeed ? null : (maxSpeed ?? this.maxSpeed),
      );
}
