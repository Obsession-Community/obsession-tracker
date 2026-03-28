import 'package:flutter/foundation.dart';

/// Unit system for displaying statistics
enum UnitSystem {
  /// Metric system (meters, kilometers, km/h)
  metric,

  /// Imperial system (feet, miles, mph)
  imperial,
}

/// Real-time statistics for a tracking session
///
/// Provides comprehensive metrics including distance, time, speed, elevation,
/// and waypoint statistics calculated in real-time during tracking sessions.
@immutable
class SessionStatistics {
  const SessionStatistics({
    required this.sessionId,
    required this.timestamp,
    this.totalDistance = 0.0,
    this.segmentDistance = 0.0,
    this.totalDuration = Duration.zero,
    this.movingDuration = Duration.zero,
    this.stationaryDuration = Duration.zero,
    this.currentSpeed = 0.0,
    this.averageSpeed = 0.0,
    this.movingAverageSpeed = 0.0,
    this.maxSpeed = 0.0,
    this.currentAltitude,
    this.minAltitude,
    this.maxAltitude,
    this.totalElevationGain = 0.0,
    this.totalElevationLoss = 0.0,
    this.currentHeading,
    this.waypointCount = 0,
    this.waypointsByType = const <String, int>{},
    this.waypointDensity = 0.0,
    this.lastLocationAccuracy,
    this.averageAccuracy,
    this.goodAccuracyPercentage = 0.0,
  });

  /// Create from database map
  factory SessionStatistics.fromMap(Map<String, dynamic> map) =>
      SessionStatistics(
        sessionId: map['session_id'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        totalDistance: map['total_distance'] as double,
        segmentDistance: map['segment_distance'] as double,
        totalDuration: Duration(milliseconds: map['total_duration'] as int),
        movingDuration: Duration(milliseconds: map['moving_duration'] as int),
        stationaryDuration:
            Duration(milliseconds: map['stationary_duration'] as int),
        currentSpeed: map['current_speed'] as double,
        averageSpeed: map['average_speed'] as double,
        movingAverageSpeed: map['moving_average_speed'] as double,
        maxSpeed: map['max_speed'] as double,
        currentAltitude: map['current_altitude'] as double?,
        minAltitude: map['min_altitude'] as double?,
        maxAltitude: map['max_altitude'] as double?,
        totalElevationGain: map['total_elevation_gain'] as double,
        totalElevationLoss: map['total_elevation_loss'] as double,
        currentHeading: map['current_heading'] as double?,
        waypointCount: map['waypoint_count'] as int,
        waypointsByType: Map<String, int>.from(
            map['waypoints_by_type'] as Map<String, dynamic>),
        waypointDensity: map['waypoint_density'] as double,
        lastLocationAccuracy: map['last_location_accuracy'] as double?,
        averageAccuracy: map['average_accuracy'] as double?,
        goodAccuracyPercentage: map['good_accuracy_percentage'] as double,
      );

  /// Session ID these statistics belong to
  final String sessionId;

  /// Timestamp when statistics were last calculated
  final DateTime timestamp;

  // Distance metrics
  /// Total distance traveled in meters
  final double totalDistance;

  /// Distance of current segment in meters
  final double segmentDistance;

  // Time metrics
  /// Total elapsed time since session start
  final Duration totalDuration;

  /// Time spent moving (speed > threshold)
  final Duration movingDuration;

  /// Time spent stationary
  final Duration stationaryDuration;

  // Speed metrics
  /// Current speed in m/s
  final double currentSpeed;

  /// Average speed over entire session in m/s
  final double averageSpeed;

  /// Average speed while moving in m/s
  final double movingAverageSpeed;

  /// Maximum speed recorded in m/s
  final double maxSpeed;

  // Elevation metrics
  /// Current altitude in meters
  final double? currentAltitude;

  /// Minimum altitude recorded in meters
  final double? minAltitude;

  /// Maximum altitude recorded in meters
  final double? maxAltitude;

  /// Total elevation gained in meters
  final double totalElevationGain;

  /// Total elevation lost in meters
  final double totalElevationLoss;

  // Navigation metrics
  /// Current heading/bearing in degrees
  final double? currentHeading;

  // Waypoint metrics
  /// Total number of waypoints created
  final int waypointCount;

  /// Count of waypoints by type
  final Map<String, int> waypointsByType;

  /// Waypoints per kilometer
  final double waypointDensity;

  // Accuracy metrics
  /// Last recorded GPS accuracy in meters
  final double? lastLocationAccuracy;

  /// Average GPS accuracy in meters
  final double? averageAccuracy;

  /// Percentage of readings with good accuracy (<= 10m)
  final double goodAccuracyPercentage;

  /// Get net elevation change (gain - loss)
  double get netElevationChange => totalElevationGain - totalElevationLoss;

  /// Get moving time percentage
  double get movingTimePercentage {
    if (totalDuration.inMilliseconds == 0) {
      return 0.0;
    }
    return (movingDuration.inMilliseconds / totalDuration.inMilliseconds) * 100;
  }

  /// Get stationary time percentage
  double get stationaryTimePercentage => 100.0 - movingTimePercentage;

  /// Check if altitude data is available
  bool get hasAltitudeData => currentAltitude != null;

  /// Check if heading data is available
  bool get hasHeadingData => currentHeading != null;

  /// Get altitude range (max - min)
  double? get altitudeRange {
    if (minAltitude == null || maxAltitude == null) {
      return null;
    }
    return maxAltitude! - minAltitude!;
  }

  /// Format distance for display
  String formatDistance(UnitSystem units) {
    switch (units) {
      case UnitSystem.metric:
        if (totalDistance < 1000) {
          return '${totalDistance.toStringAsFixed(0)} m';
        } else {
          return '${(totalDistance / 1000).toStringAsFixed(2)} km';
        }
      case UnitSystem.imperial:
        final double feet = totalDistance * 3.28084;
        if (feet < 5280) {
          return '${feet.toStringAsFixed(0)} ft';
        } else {
          final double miles = feet / 5280;
          return '${miles.toStringAsFixed(2)} mi';
        }
    }
  }

  /// Format speed for display
  String formatSpeed(double speedMs, UnitSystem units) {
    switch (units) {
      case UnitSystem.metric:
        final double kmh = speedMs * 3.6;
        return '${kmh.toStringAsFixed(1)} km/h';
      case UnitSystem.imperial:
        final double mph = speedMs * 2.23694;
        return '${mph.toStringAsFixed(1)} mph';
    }
  }

  /// Format current speed for display
  String formatCurrentSpeed(UnitSystem units) =>
      formatSpeed(currentSpeed, units);

  /// Format average speed for display
  String formatAverageSpeed(UnitSystem units) =>
      formatSpeed(averageSpeed, units);

  /// Format moving average speed for display
  String formatMovingAverageSpeed(UnitSystem units) =>
      formatSpeed(movingAverageSpeed, units);

  /// Format max speed for display
  String formatMaxSpeed(UnitSystem units) => formatSpeed(maxSpeed, units);

  /// Format altitude for display
  String formatAltitude(double? altitude, UnitSystem units) {
    if (altitude == null) {
      return 'N/A';
    }

    switch (units) {
      case UnitSystem.metric:
        return '${altitude.toStringAsFixed(0)} m';
      case UnitSystem.imperial:
        final double feet = altitude * 3.28084;
        return '${feet.toStringAsFixed(0)} ft';
    }
  }

  /// Format current altitude for display
  String formatCurrentAltitude(UnitSystem units) =>
      formatAltitude(currentAltitude, units);

  /// Format elevation gain for display
  String formatElevationGain(UnitSystem units) =>
      formatAltitude(totalElevationGain, units);

  /// Format elevation loss for display
  String formatElevationLoss(UnitSystem units) =>
      formatAltitude(totalElevationLoss, units);

  /// Format net elevation change for display
  String formatNetElevationChange(UnitSystem units) {
    final String formatted = formatAltitude(netElevationChange.abs(), units);
    final String sign = netElevationChange >= 0 ? '+' : '-';
    return '$sign$formatted';
  }

  /// Format duration for display (HH:MM:SS or MM:SS)
  String formatDuration(Duration duration) {
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Format total duration for display
  String get formattedTotalDuration => formatDuration(totalDuration);

  /// Format moving duration for display
  String get formattedMovingDuration => formatDuration(movingDuration);

  /// Format stationary duration for display
  String get formattedStationaryDuration => formatDuration(stationaryDuration);

  /// Format heading for display
  String formatHeading() {
    if (currentHeading == null) {
      return 'N/A';
    }

    final double heading = currentHeading!;
    final List<String> directions = <String>[
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW'
    ];
    final int index = ((heading + 11.25) / 22.5).floor() % 16;
    return '${directions[index]} (${heading.toStringAsFixed(0)}°)';
  }

  /// Format accuracy for display
  String formatAccuracy(double? accuracy) {
    if (accuracy == null) {
      return 'N/A';
    }
    return '±${accuracy.toStringAsFixed(1)} m';
  }

  /// Format last location accuracy for display
  String get formattedLastAccuracy => formatAccuracy(lastLocationAccuracy);

  /// Format average accuracy for display
  String get formattedAverageAccuracy => formatAccuracy(averageAccuracy);

  /// Convert to map for database storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'session_id': sessionId,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'total_distance': totalDistance,
        'segment_distance': segmentDistance,
        'total_duration': totalDuration.inMilliseconds,
        'moving_duration': movingDuration.inMilliseconds,
        'stationary_duration': stationaryDuration.inMilliseconds,
        'current_speed': currentSpeed,
        'average_speed': averageSpeed,
        'moving_average_speed': movingAverageSpeed,
        'max_speed': maxSpeed,
        'current_altitude': currentAltitude,
        'min_altitude': minAltitude,
        'max_altitude': maxAltitude,
        'total_elevation_gain': totalElevationGain,
        'total_elevation_loss': totalElevationLoss,
        'current_heading': currentHeading,
        'waypoint_count': waypointCount,
        'waypoints_by_type': waypointsByType,
        'waypoint_density': waypointDensity,
        'last_location_accuracy': lastLocationAccuracy,
        'average_accuracy': averageAccuracy,
        'good_accuracy_percentage': goodAccuracyPercentage,
      };

  /// Create a copy with updated values
  SessionStatistics copyWith({
    String? sessionId,
    DateTime? timestamp,
    double? totalDistance,
    double? segmentDistance,
    Duration? totalDuration,
    Duration? movingDuration,
    Duration? stationaryDuration,
    double? currentSpeed,
    double? averageSpeed,
    double? movingAverageSpeed,
    double? maxSpeed,
    double? currentAltitude,
    double? minAltitude,
    double? maxAltitude,
    double? totalElevationGain,
    double? totalElevationLoss,
    double? currentHeading,
    int? waypointCount,
    Map<String, int>? waypointsByType,
    double? waypointDensity,
    double? lastLocationAccuracy,
    double? averageAccuracy,
    double? goodAccuracyPercentage,
  }) =>
      SessionStatistics(
        sessionId: sessionId ?? this.sessionId,
        timestamp: timestamp ?? this.timestamp,
        totalDistance: totalDistance ?? this.totalDistance,
        segmentDistance: segmentDistance ?? this.segmentDistance,
        totalDuration: totalDuration ?? this.totalDuration,
        movingDuration: movingDuration ?? this.movingDuration,
        stationaryDuration: stationaryDuration ?? this.stationaryDuration,
        currentSpeed: currentSpeed ?? this.currentSpeed,
        averageSpeed: averageSpeed ?? this.averageSpeed,
        movingAverageSpeed: movingAverageSpeed ?? this.movingAverageSpeed,
        maxSpeed: maxSpeed ?? this.maxSpeed,
        currentAltitude: currentAltitude ?? this.currentAltitude,
        minAltitude: minAltitude ?? this.minAltitude,
        maxAltitude: maxAltitude ?? this.maxAltitude,
        totalElevationGain: totalElevationGain ?? this.totalElevationGain,
        totalElevationLoss: totalElevationLoss ?? this.totalElevationLoss,
        currentHeading: currentHeading ?? this.currentHeading,
        waypointCount: waypointCount ?? this.waypointCount,
        waypointsByType: waypointsByType ?? this.waypointsByType,
        waypointDensity: waypointDensity ?? this.waypointDensity,
        lastLocationAccuracy: lastLocationAccuracy ?? this.lastLocationAccuracy,
        averageAccuracy: averageAccuracy ?? this.averageAccuracy,
        goodAccuracyPercentage:
            goodAccuracyPercentage ?? this.goodAccuracyPercentage,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionStatistics &&
          runtimeType == other.runtimeType &&
          sessionId == other.sessionId &&
          timestamp == other.timestamp;

  @override
  int get hashCode => sessionId.hashCode ^ timestamp.hashCode;

  @override
  String toString() =>
      'SessionStatistics{sessionId: $sessionId, distance: ${formatDistance(UnitSystem.metric)}, duration: $formattedTotalDuration}';
}
