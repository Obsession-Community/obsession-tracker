import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/session_statistics.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/location_service.dart';

/// Configuration for statistics calculation
class StatisticsConfig {
  const StatisticsConfig({
    this.movingSpeedThreshold = 0.5, // m/s (1.8 km/h)
    this.elevationChangeThreshold = 2.0, // meters
    this.accuracyThreshold = 10.0, // meters
    this.speedSmoothingWindow = 5,
    this.elevationSmoothingWindow = 3,
    this.maxReasonableSpeed = 55.56, // m/s (200 km/h)
    this.maxReasonableElevationChange = 100.0, // meters per update
  });

  /// Speed threshold to consider movement (m/s)
  final double movingSpeedThreshold;

  /// Minimum elevation change to record (meters)
  final double elevationChangeThreshold;

  /// GPS accuracy threshold for reliable data (meters)
  final double accuracyThreshold;

  /// Number of readings for speed smoothing
  final int speedSmoothingWindow;

  /// Number of readings for elevation smoothing
  final int elevationSmoothingWindow;

  /// Maximum reasonable speed to prevent GPS errors (m/s)
  final double maxReasonableSpeed;

  /// Maximum reasonable elevation change per update (meters)
  final double maxReasonableElevationChange;
}

/// Internal data for tracking calculations
class _StatisticsData {
  _StatisticsData({
    required this.sessionId,
    required this.sessionStartTime,
  });

  final String sessionId;
  final DateTime sessionStartTime;

  // Location tracking
  EnhancedLocationData? lastLocation;
  DateTime? lastLocationTime;
  final List<EnhancedLocationData> locationHistory = <EnhancedLocationData>[];

  // Distance tracking
  double totalDistance = 0.0;
  double segmentDistance = 0.0;

  // Time tracking
  Duration movingTime = Duration.zero;
  Duration stationaryTime = Duration.zero;
  DateTime? lastMovingTime;
  DateTime? lastStationaryTime;

  // Speed tracking
  final List<double> speedHistory = <double>[];
  double maxSpeed = 0.0;
  double totalSpeedSum = 0.0;
  double movingSpeedSum = 0.0;
  int speedReadings = 0;
  int movingSpeedReadings = 0;

  // Elevation tracking
  final List<double> elevationHistory = <double>[];
  double? minAltitude;
  double? maxAltitude;
  double totalElevationGain = 0.0;
  double totalElevationLoss = 0.0;
  double? lastSmoothedElevation;

  // Accuracy tracking
  final List<double> accuracyHistory = <double>[];
  int goodAccuracyCount = 0;
  int totalAccuracyReadings = 0;

  // Waypoint tracking
  final Map<String, int> waypointsByType = <String, int>{};
  int waypointCount = 0;
}

/// Service for calculating real-time session statistics
///
/// Provides efficient, accurate statistics calculation without impacting
/// GPS tracking performance. Uses rolling calculations and data smoothing
/// for reliable metrics.
class StatisticsService {
  StatisticsService._();
  static StatisticsService? _instance;
  static StatisticsService get instance => _instance ??= StatisticsService._();

  final Map<String, _StatisticsData> _sessionData = <String, _StatisticsData>{};
  final StatisticsConfig _config = const StatisticsConfig();

  final StreamController<SessionStatistics> _statisticsController =
      StreamController<SessionStatistics>.broadcast();

  /// Stream of real-time statistics updates
  Stream<SessionStatistics> get statisticsStream =>
      _statisticsController.stream;

  /// Start statistics tracking for a session
  void startSession(String sessionId, DateTime startTime) {
    debugPrint('StatisticsService: Starting session $sessionId');

    _sessionData[sessionId] = _StatisticsData(
      sessionId: sessionId,
      sessionStartTime: startTime,
    );
  }

  /// Stop statistics tracking for a session
  void stopSession(String sessionId) {
    debugPrint('StatisticsService: Stopping session $sessionId');
    _sessionData.remove(sessionId);
  }

  /// Update statistics with new location data
  void updateLocation(String sessionId, EnhancedLocationData location) {
    final _StatisticsData? data = _sessionData[sessionId];
    if (data == null) {
      debugPrint('StatisticsService: No session data for $sessionId');
      return;
    }

    final DateTime now = DateTime.now();

    try {
      _processLocationUpdate(data, location, now);
      final SessionStatistics stats = _calculateStatistics(data, now);
      _statisticsController.add(stats);
    } catch (e) {
      debugPrint('StatisticsService: Error updating location: $e');
    }
  }

  /// Update statistics with new waypoint
  void updateWaypoint(String sessionId, Waypoint waypoint) {
    final _StatisticsData? data = _sessionData[sessionId];
    if (data == null) return;

    data.waypointCount++;
    final String type = waypoint.type.name;
    data.waypointsByType[type] = (data.waypointsByType[type] ?? 0) + 1;

    final DateTime now = DateTime.now();
    final SessionStatistics stats = _calculateStatistics(data, now);
    _statisticsController.add(stats);
  }

  /// Get current statistics for a session
  SessionStatistics? getCurrentStatistics(String sessionId) {
    final _StatisticsData? data = _sessionData[sessionId];
    if (data == null) return null;

    return _calculateStatistics(data, DateTime.now());
  }

  /// Process location update and calculate metrics
  void _processLocationUpdate(
      _StatisticsData data, EnhancedLocationData location, DateTime now) {
    // Add to location history
    data.locationHistory.add(location);
    if (data.locationHistory.length > 100) {
      data.locationHistory.removeAt(0);
    }

    // Process distance and speed if we have previous location
    if (data.lastLocation != null && data.lastLocationTime != null) {
      _updateDistanceAndSpeed(data, location, now);
      _updateTimeTracking(data, location, now);
    }

    // Update elevation tracking
    _updateElevationTracking(data, location);

    // Update accuracy tracking
    _updateAccuracyTracking(data, location);

    // Update last location
    data.lastLocation = location;
    data.lastLocationTime = now;
  }

  /// Update distance and speed calculations
  void _updateDistanceAndSpeed(
      _StatisticsData data, EnhancedLocationData location, DateTime now) {
    final EnhancedLocationData lastLocation = data.lastLocation!;

    // Calculate distance using Haversine formula
    final double distance = Geolocator.distanceBetween(
      lastLocation.position.latitude,
      lastLocation.position.longitude,
      location.position.latitude,
      location.position.longitude,
    );

    // Only add distance if it's reasonable (prevents GPS jumps)
    if (distance > 0 && distance < 1000) {
      // Max 1km per update
      data.totalDistance += distance;
      data.segmentDistance += distance;
    }

    // Calculate and track speed
    final double? speed = location.bestSpeed;
    if (speed != null && speed >= 0 && speed <= _config.maxReasonableSpeed) {
      data.speedHistory.add(speed);
      if (data.speedHistory.length > _config.speedSmoothingWindow) {
        data.speedHistory.removeAt(0);
      }

      data.totalSpeedSum += speed;
      data.speedReadings++;

      if (speed > data.maxSpeed) {
        data.maxSpeed = speed;
      }

      // Track moving speed separately
      if (speed >= _config.movingSpeedThreshold) {
        data.movingSpeedSum += speed;
        data.movingSpeedReadings++;
      }
    }
  }

  /// Update time tracking (moving vs stationary)
  void _updateTimeTracking(
      _StatisticsData data, EnhancedLocationData location, DateTime now) {
    final Duration timeDiff = now.difference(data.lastLocationTime!);

    final double? speed = location.bestSpeed;
    final bool isMoving =
        speed != null && speed >= _config.movingSpeedThreshold;

    if (isMoving) {
      data.movingTime += timeDiff;
      data.lastMovingTime = now;
    } else {
      data.stationaryTime += timeDiff;
      data.lastStationaryTime = now;
    }
  }

  /// Update elevation tracking with smoothing
  void _updateElevationTracking(
      _StatisticsData data, EnhancedLocationData location) {
    final double? altitude = location.bestAltitude;
    if (altitude == null) return;

    // Add to elevation history for smoothing
    data.elevationHistory.add(altitude);
    if (data.elevationHistory.length > _config.elevationSmoothingWindow) {
      data.elevationHistory.removeAt(0);
    }

    // Calculate smoothed elevation
    final double smoothedElevation =
        data.elevationHistory.reduce((double a, double b) => a + b) /
            data.elevationHistory.length;

    // Update min/max altitude
    data.minAltitude = data.minAltitude == null
        ? altitude
        : math.min(data.minAltitude!, altitude);
    data.maxAltitude = data.maxAltitude == null
        ? altitude
        : math.max(data.maxAltitude!, altitude);

    // Calculate elevation gain/loss
    if (data.lastSmoothedElevation != null) {
      final double elevationChange =
          smoothedElevation - data.lastSmoothedElevation!;

      if (elevationChange.abs() >= _config.elevationChangeThreshold &&
          elevationChange.abs() <= _config.maxReasonableElevationChange) {
        if (elevationChange > 0) {
          data.totalElevationGain += elevationChange;
        } else {
          data.totalElevationLoss += elevationChange.abs();
        }
      }
    }

    data.lastSmoothedElevation = smoothedElevation;
  }

  /// Update accuracy tracking
  void _updateAccuracyTracking(
      _StatisticsData data, EnhancedLocationData location) {
    final double accuracy = location.position.accuracy;

    data.accuracyHistory.add(accuracy);
    if (data.accuracyHistory.length > 20) {
      data.accuracyHistory.removeAt(0);
    }

    data.totalAccuracyReadings++;
    if (accuracy <= _config.accuracyThreshold) {
      data.goodAccuracyCount++;
    }
  }

  /// Calculate current statistics from data
  SessionStatistics _calculateStatistics(_StatisticsData data, DateTime now) {
    final Duration totalDuration = now.difference(data.sessionStartTime);

    // Calculate current speed (smoothed)
    final double currentSpeed = data.speedHistory.isNotEmpty
        ? data.speedHistory.reduce((double a, double b) => a + b) /
            data.speedHistory.length
        : 0.0;

    // Calculate average speeds
    final double averageSpeed =
        data.speedReadings > 0 ? data.totalSpeedSum / data.speedReadings : 0.0;

    final double movingAverageSpeed = data.movingSpeedReadings > 0
        ? data.movingSpeedSum / data.movingSpeedReadings
        : 0.0;

    // Calculate waypoint density (waypoints per km)
    final double waypointDensity = data.totalDistance > 0
        ? (data.waypointCount / (data.totalDistance / 1000))
        : 0.0;

    // Calculate accuracy metrics
    final double? averageAccuracy = data.accuracyHistory.isNotEmpty
        ? data.accuracyHistory.reduce((double a, double b) => a + b) /
            data.accuracyHistory.length
        : null;

    final double goodAccuracyPercentage = data.totalAccuracyReadings > 0
        ? (data.goodAccuracyCount / data.totalAccuracyReadings) * 100
        : 0.0;

    return SessionStatistics(
      sessionId: data.sessionId,
      timestamp: now,
      totalDistance: data.totalDistance,
      segmentDistance: data.segmentDistance,
      totalDuration: totalDuration,
      movingDuration: data.movingTime,
      stationaryDuration: data.stationaryTime,
      currentSpeed: currentSpeed,
      averageSpeed: averageSpeed,
      movingAverageSpeed: movingAverageSpeed,
      maxSpeed: data.maxSpeed,
      currentAltitude: data.lastLocation?.bestAltitude,
      minAltitude: data.minAltitude,
      maxAltitude: data.maxAltitude,
      totalElevationGain: data.totalElevationGain,
      totalElevationLoss: data.totalElevationLoss,
      currentHeading: data.lastLocation?.bestHeading,
      waypointCount: data.waypointCount,
      waypointsByType: Map<String, int>.from(data.waypointsByType),
      waypointDensity: waypointDensity,
      lastLocationAccuracy: data.lastLocation?.position.accuracy,
      averageAccuracy: averageAccuracy,
      goodAccuracyPercentage: goodAccuracyPercentage,
    );
  }

  /// Reset segment distance for a session
  void resetSegmentDistance(String sessionId) {
    final _StatisticsData? data = _sessionData[sessionId];
    if (data != null) {
      data.segmentDistance = 0.0;
    }
  }

  /// Get session data for debugging
  Map<String, dynamic>? getSessionDebugInfo(String sessionId) {
    final _StatisticsData? data = _sessionData[sessionId];
    if (data == null) return null;

    return <String, dynamic>{
      'sessionId': data.sessionId,
      'locationHistoryCount': data.locationHistory.length,
      'totalDistance': data.totalDistance,
      'speedHistoryCount': data.speedHistory.length,
      'elevationHistoryCount': data.elevationHistory.length,
      'waypointCount': data.waypointCount,
    };
  }

  /// Dispose of the service
  void dispose() {
    _sessionData.clear();
    _statisticsController.close();
    _instance = null;
  }
}
