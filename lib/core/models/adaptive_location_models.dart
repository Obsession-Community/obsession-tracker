import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/services/location_service.dart';

/// Location tracking parameters for adaptive updates
@immutable
class LocationTrackingParameters {
  const LocationTrackingParameters({
    required this.updateIntervalSeconds,
    required this.minimumDistanceMeters,
    required this.accuracy,
  });

  /// Create default parameters
  factory LocationTrackingParameters.defaultParameters() =>
      const LocationTrackingParameters(
        updateIntervalSeconds: 15,
        minimumDistanceMeters: 5.0,
        accuracy: LocationAccuracy.high,
      );

  /// Update interval in seconds
  final int updateIntervalSeconds;

  /// Minimum distance between updates in meters
  final double minimumDistanceMeters;

  /// Required location accuracy
  final LocationAccuracy accuracy;

  /// Create a copy with modified parameters
  LocationTrackingParameters copyWith({
    int? updateIntervalSeconds,
    double? minimumDistanceMeters,
    LocationAccuracy? accuracy,
  }) =>
      LocationTrackingParameters(
        updateIntervalSeconds:
            updateIntervalSeconds ?? this.updateIntervalSeconds,
        minimumDistanceMeters:
            minimumDistanceMeters ?? this.minimumDistanceMeters,
        accuracy: accuracy ?? this.accuracy,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationTrackingParameters &&
          runtimeType == other.runtimeType &&
          updateIntervalSeconds == other.updateIntervalSeconds &&
          minimumDistanceMeters == other.minimumDistanceMeters &&
          accuracy == other.accuracy;

  @override
  int get hashCode =>
      updateIntervalSeconds.hashCode ^
      minimumDistanceMeters.hashCode ^
      accuracy.hashCode;

  @override
  String toString() => 'LocationTrackingParameters('
      'interval: ${updateIntervalSeconds}s, '
      'distance: ${minimumDistanceMeters}m, '
      'accuracy: ${accuracy.name}'
      ')';
}

/// Adaptive location update with context information
@immutable
class AdaptiveLocationUpdate {
  const AdaptiveLocationUpdate({
    required this.locationData,
    required this.movementPattern,
    required this.activityLevel,
    required this.trackingParameters,
    required this.adaptationReason,
    required this.timestamp,
  });

  /// Enhanced location data
  final EnhancedLocationData locationData;

  /// Detected movement pattern
  final MovementPattern movementPattern;

  /// Current activity level
  final ActivityLevel activityLevel;

  /// Current tracking parameters
  final LocationTrackingParameters trackingParameters;

  /// Reason for last parameter adaptation
  final String adaptationReason;

  /// Update timestamp
  final DateTime timestamp;

  /// Get the GPS position
  Position get position => locationData.position;

  /// Get the best available speed
  double get speed => locationData.bestSpeed ?? 0.0;

  /// Get the accuracy in meters
  double get accuracy => position.accuracy;

  @override
  String toString() => 'AdaptiveLocationUpdate('
      'lat: ${position.latitude.toStringAsFixed(6)}, '
      'lng: ${position.longitude.toStringAsFixed(6)}, '
      'accuracy: ${accuracy.toStringAsFixed(1)}m, '
      'pattern: ${movementPattern.name}, '
      'activity: ${activityLevel.name}'
      ')';
}

/// Movement sample for pattern analysis
@immutable
class MovementSample {
  const MovementSample({
    required this.position,
    required this.speed,
    required this.accuracy,
    required this.timestamp,
  });

  /// GPS position
  final Position position;

  /// Speed in m/s
  final double speed;

  /// Position accuracy in meters
  final double accuracy;

  /// Sample timestamp
  final DateTime timestamp;

  @override
  String toString() => 'MovementSample('
      'speed: ${speed.toStringAsFixed(1)}m/s, '
      'accuracy: ${accuracy.toStringAsFixed(1)}m, '
      'time: ${timestamp.toIso8601String()}'
      ')';
}

/// Location accuracy measurement for performance tracking
@immutable
class LocationAccuracyMeasurement {
  const LocationAccuracyMeasurement({
    required this.accuracy,
    required this.parameters,
    required this.movementPattern,
    required this.timestamp,
  });

  /// Measured accuracy in meters
  final double accuracy;

  /// Tracking parameters used
  final LocationTrackingParameters parameters;

  /// Movement pattern at time of measurement
  final MovementPattern movementPattern;

  /// Measurement timestamp
  final DateTime timestamp;

  @override
  String toString() => 'LocationAccuracyMeasurement('
      'accuracy: ${accuracy.toStringAsFixed(1)}m, '
      'pattern: ${movementPattern.name}, '
      'interval: ${parameters.updateIntervalSeconds}s '
      ')';
}

/// Battery usage measurement for optimization
@immutable
class BatteryUsageMeasurement {
  const BatteryUsageMeasurement({
    required this.parameters,
    required this.movementPattern,
    required this.estimatedBatteryImpact,
    required this.timestamp,
  });

  /// Tracking parameters used
  final LocationTrackingParameters parameters;

  /// Movement pattern during measurement
  final MovementPattern movementPattern;

  /// Estimated battery impact (0-100 scale)
  final double estimatedBatteryImpact;

  /// Measurement timestamp
  final DateTime timestamp;

  @override
  String toString() => 'BatteryUsageMeasurement('
      'impact: ${estimatedBatteryImpact.toStringAsFixed(1)}%, '
      'pattern: ${movementPattern.name}, '
      'interval: ${parameters.updateIntervalSeconds}s '
      ')';
}

/// Comprehensive tracking metrics
@immutable
class AdaptiveTrackingMetrics {
  const AdaptiveTrackingMetrics({
    required this.accuracyStatistics,
    required this.batteryStatistics,
    required this.adaptationStatistics,
    required this.currentParameters,
    required this.movementPattern,
    required this.activityLevel,
    required this.timestamp,
  });

  /// Accuracy performance statistics
  final AccuracyStatistics accuracyStatistics;

  /// Battery usage statistics
  final BatteryStatistics batteryStatistics;

  /// Adaptation behavior statistics
  final AdaptationStatistics adaptationStatistics;

  /// Current tracking parameters
  final LocationTrackingParameters currentParameters;

  /// Current movement pattern
  final MovementPattern movementPattern;

  /// Current activity level
  final ActivityLevel activityLevel;

  /// Metrics timestamp
  final DateTime timestamp;

  /// Get overall performance score (0-100)
  double get performanceScore {
    double score = 0.0;

    // Accuracy contributes 50%
    if (accuracyStatistics.meanAccuracy <= 5.0) {
      score += 50.0;
    } else if (accuracyStatistics.meanAccuracy <= 10.0) {
      score += 40.0;
    } else if (accuracyStatistics.meanAccuracy <= 20.0) {
      score += 30.0;
    } else {
      score += 20.0;
    }

    // Battery efficiency contributes 30%
    if (batteryStatistics.averageBatteryImpact <= 20.0) {
      score += 30.0;
    } else if (batteryStatistics.averageBatteryImpact <= 40.0) {
      score += 25.0;
    } else if (batteryStatistics.averageBatteryImpact <= 60.0) {
      score += 20.0;
    } else {
      score += 15.0;
    }

    // Adaptation effectiveness contributes 20%
    if (adaptationStatistics.totalAdaptations > 0) {
      score += 20.0;
    } else {
      score += 10.0;
    }

    return score;
  }

  @override
  String toString() => 'AdaptiveTrackingMetrics('
      'accuracy: ${accuracyStatistics.meanAccuracy.toStringAsFixed(1)}m, '
      'battery: ${batteryStatistics.averageBatteryImpact.toStringAsFixed(1)}%, '
      'adaptations: ${adaptationStatistics.totalAdaptations}, '
      'score: ${performanceScore.toStringAsFixed(1)}/100 '
      ')';
}

/// Accuracy statistics
@immutable
class AccuracyStatistics {
  const AccuracyStatistics({
    required this.sampleCount,
    required this.meanAccuracy,
    required this.medianAccuracy,
    required this.minAccuracy,
    required this.maxAccuracy,
  });

  /// Create empty statistics
  factory AccuracyStatistics.empty() => const AccuracyStatistics(
        sampleCount: 0,
        meanAccuracy: 0.0,
        medianAccuracy: 0.0,
        minAccuracy: 0.0,
        maxAccuracy: 0.0,
      );

  /// Number of accuracy samples
  final int sampleCount;

  /// Mean accuracy in meters
  final double meanAccuracy;

  /// Median accuracy in meters
  final double medianAccuracy;

  /// Best accuracy achieved
  final double minAccuracy;

  /// Worst accuracy recorded
  final double maxAccuracy;

  /// Get accuracy range
  double get accuracyRange => maxAccuracy - minAccuracy;

  /// Check if accuracy is consistent (low variance)
  bool get isConsistent => accuracyRange <= 10.0;

  @override
  String toString() => 'AccuracyStatistics('
      'samples: $sampleCount, '
      'mean: ${meanAccuracy.toStringAsFixed(1)}m, '
      'range: ${minAccuracy.toStringAsFixed(1)}-${maxAccuracy.toStringAsFixed(1)}m '
      ')';
}

/// Battery usage statistics
@immutable
class BatteryStatistics {
  const BatteryStatistics({
    required this.sampleCount,
    required this.averageBatteryImpact,
    required this.totalEstimatedUsage,
  });

  /// Create empty statistics
  factory BatteryStatistics.empty() => const BatteryStatistics(
        sampleCount: 0,
        averageBatteryImpact: 0.0,
        totalEstimatedUsage: 0.0,
      );

  /// Number of battery measurements
  final int sampleCount;

  /// Average battery impact (0-100 scale)
  final double averageBatteryImpact;

  /// Total estimated battery usage
  final double totalEstimatedUsage;

  /// Get battery efficiency rating
  BatteryEfficiency get efficiency {
    if (averageBatteryImpact <= 20.0) return BatteryEfficiency.excellent;
    if (averageBatteryImpact <= 40.0) return BatteryEfficiency.good;
    if (averageBatteryImpact <= 60.0) return BatteryEfficiency.fair;
    if (averageBatteryImpact <= 80.0) return BatteryEfficiency.poor;
    return BatteryEfficiency.critical;
  }

  @override
  String toString() => 'BatteryStatistics('
      'samples: $sampleCount, '
      'avg impact: ${averageBatteryImpact.toStringAsFixed(1)}%, '
      'efficiency: ${efficiency.name}'
      ')';
}

/// Adaptation behavior statistics
@immutable
class AdaptationStatistics {
  const AdaptationStatistics({
    required this.totalAdaptations,
    required this.lastAdaptationTime,
    required this.averageAdaptationInterval,
  });

  /// Total number of parameter adaptations
  final int totalAdaptations;

  /// Time of last adaptation
  final DateTime lastAdaptationTime;

  /// Average time between adaptations
  final Duration averageAdaptationInterval;

  /// Get adaptation frequency (adaptations per hour)
  double get adaptationFrequency {
    if (totalAdaptations == 0) return 0.0;

    final totalHours = averageAdaptationInterval.inMilliseconds /
        (1000 * 60 * 60); // Convert to hours
    return totalAdaptations / totalHours;
  }

  /// Check if adaptation is active
  bool get isAdaptationActive {
    final timeSinceLastAdaptation =
        DateTime.now().difference(lastAdaptationTime);
    return timeSinceLastAdaptation < const Duration(minutes: 5);
  }

  @override
  String toString() => 'AdaptationStatistics('
      'total: $totalAdaptations, '
      'frequency: ${adaptationFrequency.toStringAsFixed(2)}/hr, '
      'last: ${lastAdaptationTime.toIso8601String()}'
      ')';
}

/// Movement patterns detected from location data
enum MovementPattern {
  unknown,
  stationary,
  walking,
  jogging,
  cycling,
  driving,
  highSpeed,
  indoor;

  String get description {
    switch (this) {
      case MovementPattern.unknown:
        return 'Unknown movement pattern';
      case MovementPattern.stationary:
        return 'Stationary or very slow movement';
      case MovementPattern.walking:
        return 'Walking pace';
      case MovementPattern.jogging:
        return 'Jogging or running pace';
      case MovementPattern.cycling:
        return 'Cycling pace';
      case MovementPattern.driving:
        return 'Driving or vehicle speed';
      case MovementPattern.highSpeed:
        return 'High-speed travel';
      case MovementPattern.indoor:
        return 'Indoor movement';
    }
  }

  /// Get expected speed range for this pattern
  (double min, double max) get speedRange {
    switch (this) {
      case MovementPattern.stationary:
        return (0.0, 0.5);
      case MovementPattern.walking:
        return (0.5, 2.0);
      case MovementPattern.jogging:
        return (2.0, 5.0);
      case MovementPattern.cycling:
        return (5.0, 15.0);
      case MovementPattern.driving:
        return (15.0, 50.0);
      case MovementPattern.highSpeed:
        return (50.0, double.infinity);
      case MovementPattern.indoor:
        return (0.0, 1.0);
      case MovementPattern.unknown:
        return (0.0, double.infinity);
    }
  }

  /// Get recommended update interval for this pattern
  int get recommendedUpdateInterval {
    switch (this) {
      case MovementPattern.stationary:
        return 60; // 1 minute
      case MovementPattern.walking:
        return 15; // 15 seconds
      case MovementPattern.jogging:
        return 10; // 10 seconds
      case MovementPattern.cycling:
        return 8; // 8 seconds
      case MovementPattern.driving:
        return 5; // 5 seconds
      case MovementPattern.highSpeed:
        return 3; // 3 seconds
      case MovementPattern.indoor:
        return 120; // 2 minutes
      case MovementPattern.unknown:
        return 15; // Default
    }
  }
}

/// Activity levels for adaptive tracking
enum ActivityLevel {
  unknown,
  stationary,
  walking,
  jogging,
  cycling,
  driving,
  highSpeed;

  String get description {
    switch (this) {
      case ActivityLevel.unknown:
        return 'Unknown activity';
      case ActivityLevel.stationary:
        return 'Stationary';
      case ActivityLevel.walking:
        return 'Walking';
      case ActivityLevel.jogging:
        return 'Jogging/Running';
      case ActivityLevel.cycling:
        return 'Cycling';
      case ActivityLevel.driving:
        return 'Driving';
      case ActivityLevel.highSpeed:
        return 'High-speed travel';
    }
  }

  /// Get activity intensity (0-100 scale)
  int get intensity {
    switch (this) {
      case ActivityLevel.stationary:
        return 0;
      case ActivityLevel.walking:
        return 20;
      case ActivityLevel.jogging:
        return 60;
      case ActivityLevel.cycling:
        return 40;
      case ActivityLevel.driving:
        return 30;
      case ActivityLevel.highSpeed:
        return 80;
      case ActivityLevel.unknown:
        return 25; // Default moderate intensity
    }
  }

  /// Get expected battery impact multiplier
  double get batteryImpactMultiplier {
    switch (this) {
      case ActivityLevel.stationary:
        return 0.5; // Lower impact when stationary
      case ActivityLevel.walking:
        return 1.0; // Baseline
      case ActivityLevel.jogging:
        return 1.2; // Slightly higher for frequent updates
      case ActivityLevel.cycling:
        return 1.1; // Moderate increase
      case ActivityLevel.driving:
        return 1.3; // Higher for vehicle tracking
      case ActivityLevel.highSpeed:
        return 1.5; // Highest for high-speed tracking
      case ActivityLevel.unknown:
        return 1.0; // Default
    }
  }
}

/// Battery efficiency ratings
enum BatteryEfficiency {
  excellent,
  good,
  fair,
  poor,
  critical;

  String get description {
    switch (this) {
      case BatteryEfficiency.excellent:
        return 'Excellent battery efficiency';
      case BatteryEfficiency.good:
        return 'Good battery efficiency';
      case BatteryEfficiency.fair:
        return 'Fair battery efficiency';
      case BatteryEfficiency.poor:
        return 'Poor battery efficiency';
      case BatteryEfficiency.critical:
        return 'Critical battery usage';
    }
  }

  /// Get color representation for UI
  String get colorHex {
    switch (this) {
      case BatteryEfficiency.excellent:
        return '#4CAF50'; // Green
      case BatteryEfficiency.good:
        return '#8BC34A'; // Light Green
      case BatteryEfficiency.fair:
        return '#FF9800'; // Orange
      case BatteryEfficiency.poor:
        return '#F44336'; // Red
      case BatteryEfficiency.critical:
        return '#9C27B0'; // Purple
    }
  }
}
