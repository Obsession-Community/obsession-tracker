import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// GPS quality reading with comprehensive accuracy information
@immutable
class GpsQualityReading {
  const GpsQualityReading({
    required this.position,
    required this.signalQuality,
    required this.signalStrength,
    required this.accuracy,
    required this.speed,
    required this.satelliteCount,
    required this.driftDistance,
    required this.environmentalCondition,
    required this.timestamp,
    this.altitude,
    this.heading,
  });

  /// GPS position data
  final Position position;

  /// Overall signal quality assessment
  final GpsSignalQuality signalQuality;

  /// Estimated signal strength (0-100)
  final double signalStrength;

  /// Position accuracy in meters
  final double accuracy;

  /// Current speed in m/s
  final double speed;

  /// Altitude in meters (if available)
  final double? altitude;

  /// Heading in degrees (if available)
  final double? heading;

  /// Estimated number of satellites
  final int satelliteCount;

  /// Current drift distance in meters
  final double driftDistance;

  /// Current environmental condition
  final EnvironmentalCondition environmentalCondition;

  /// Timestamp of the reading
  final DateTime timestamp;

  @override
  String toString() => 'GpsQualityReading('
      'accuracy: ${accuracy.toStringAsFixed(1)}m, '
      'quality: ${signalQuality.name}, '
      'strength: ${signalStrength.toStringAsFixed(0)}%, '
      'satellites: $satelliteCount, '
      'drift: ${driftDistance.toStringAsFixed(1)}m '
      ')';
}

/// GPS accuracy alert for user notifications
@immutable
class GpsAccuracyAlert {
  const GpsAccuracyAlert({
    required this.type,
    required this.severity,
    required this.message,
    required this.timestamp,
    this.data,
  });

  /// Type of GPS alert
  final GpsAlertType type;

  /// Severity level of the alert
  final AlertSeverity severity;

  /// Human-readable alert message
  final String message;

  /// Additional alert data
  final Map<String, dynamic>? data;

  /// Timestamp when alert was generated
  final DateTime timestamp;

  @override
  String toString() => 'GpsAccuracyAlert('
      'type: ${type.name}, '
      'severity: ${severity.name}, '
      'message: $message'
      ')';
}

/// Comprehensive GPS quality assessment
@immutable
class GpsQualityAssessment {
  const GpsQualityAssessment({
    required this.overallQuality,
    required this.signalQuality,
    required this.averageAccuracy,
    required this.driftDistance,
    required this.driftLevel,
    required this.environmentalCondition,
    required this.environmentalImpact,
    required this.recommendedActions,
    required this.timestamp,
  });

  /// Overall GPS quality rating
  final GpsOverallQuality overallQuality;

  /// Signal quality assessment
  final GpsSignalQuality signalQuality;

  /// Average accuracy in meters
  final double averageAccuracy;

  /// Current drift distance in meters
  final double driftDistance;

  /// Drift level assessment
  final GpsDriftLevel driftLevel;

  /// Current environmental condition
  final EnvironmentalCondition environmentalCondition;

  /// Environmental impact on GPS
  final EnvironmentalImpact environmentalImpact;

  /// Recommended actions for improvement
  final List<String> recommendedActions;

  /// Assessment timestamp
  final DateTime timestamp;

  /// Get a summary score (0-100)
  int get summaryScore {
    int score = 0;

    // Overall quality contributes 60%
    switch (overallQuality) {
      case GpsOverallQuality.excellent:
        score += 60;
        break;
      case GpsOverallQuality.good:
        score += 48;
        break;
      case GpsOverallQuality.fair:
        score += 36;
        break;
      case GpsOverallQuality.poor:
        score += 24;
        break;
      case GpsOverallQuality.unavailable:
        score += 0;
        break;
    }

    // Drift level contributes 25%
    switch (driftLevel) {
      case GpsDriftLevel.minimal:
        score += 25;
        break;
      case GpsDriftLevel.low:
        score += 20;
        break;
      case GpsDriftLevel.moderate:
        score += 15;
        break;
      case GpsDriftLevel.high:
        score += 10;
        break;
      case GpsDriftLevel.excessive:
        score += 0;
        break;
    }

    // Environmental impact contributes 15%
    switch (environmentalImpact) {
      case EnvironmentalImpact.minimal:
        score += 15;
        break;
      case EnvironmentalImpact.low:
        score += 12;
        break;
      case EnvironmentalImpact.moderate:
        score += 9;
        break;
      case EnvironmentalImpact.high:
        score += 6;
        break;
      case EnvironmentalImpact.severe:
        score += 0;
        break;
    }

    return score;
  }

  @override
  String toString() => 'GpsQualityAssessment('
      'overall: ${overallQuality.name}, '
      'accuracy: ${averageAccuracy.toStringAsFixed(1)}m, '
      'drift: ${driftDistance.toStringAsFixed(1)}m, '
      'environment: ${environmentalCondition.name}, '
      'score: $summaryScore/100 '
      ')';
}

/// GPS accuracy statistics over time
@immutable
class GpsAccuracyStatistics {
  const GpsAccuracyStatistics({
    required this.sampleCount,
    required this.meanAccuracy,
    required this.medianAccuracy,
    required this.minAccuracy,
    required this.maxAccuracy,
    required this.standardDeviation,
    required this.qualityDistribution,
    required this.timestamp,
  });

  /// Create empty statistics
  factory GpsAccuracyStatistics.empty() => GpsAccuracyStatistics(
        sampleCount: 0,
        meanAccuracy: 0.0,
        medianAccuracy: 0.0,
        minAccuracy: 0.0,
        maxAccuracy: 0.0,
        standardDeviation: 0.0,
        qualityDistribution: {
          for (final quality in GpsSignalQuality.values) quality: 0.0
        },
        timestamp: DateTime.now(),
      );

  /// Number of samples in statistics
  final int sampleCount;

  /// Mean accuracy in meters
  final double meanAccuracy;

  /// Median accuracy in meters
  final double medianAccuracy;

  /// Best (minimum) accuracy achieved
  final double minAccuracy;

  /// Worst (maximum) accuracy recorded
  final double maxAccuracy;

  /// Standard deviation of accuracy
  final double standardDeviation;

  /// Distribution of quality levels
  final Map<GpsSignalQuality, double> qualityDistribution;

  /// Statistics timestamp
  final DateTime timestamp;

  /// Get the most common quality level
  GpsSignalQuality get mostCommonQuality {
    if (qualityDistribution.isEmpty) return GpsSignalQuality.unavailable;

    return qualityDistribution.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Get percentage of excellent quality readings
  double get excellentQualityPercentage =>
      (qualityDistribution[GpsSignalQuality.excellent] ?? 0.0) * 100;

  /// Get percentage of good or better quality readings
  double get goodOrBetterPercentage =>
      ((qualityDistribution[GpsSignalQuality.excellent] ?? 0.0) +
          (qualityDistribution[GpsSignalQuality.good] ?? 0.0)) *
      100;

  @override
  String toString() => 'GpsAccuracyStatistics('
      'samples: $sampleCount, '
      'mean: ${meanAccuracy.toStringAsFixed(1)}m, '
      'median: ${medianAccuracy.toStringAsFixed(1)}m, '
      'range: ${minAccuracy.toStringAsFixed(1)}-${maxAccuracy.toStringAsFixed(1)}m, '
      'std: ${standardDeviation.toStringAsFixed(1)}m '
      ')';
}

/// Types of GPS alerts
enum GpsAlertType {
  locationServiceError,
  poorAccuracy,
  weakSignal,
  excessiveDrift,
  challengingEnvironment,
  signalLost,
  accuracyImproved,
  environmentChanged;

  String get description {
    switch (this) {
      case GpsAlertType.locationServiceError:
        return 'Location Service Error';
      case GpsAlertType.poorAccuracy:
        return 'Poor GPS Accuracy';
      case GpsAlertType.weakSignal:
        return 'Weak GPS Signal';
      case GpsAlertType.excessiveDrift:
        return 'Excessive GPS Drift';
      case GpsAlertType.challengingEnvironment:
        return 'Challenging GPS Environment';
      case GpsAlertType.signalLost:
        return 'GPS Signal Lost';
      case GpsAlertType.accuracyImproved:
        return 'GPS Accuracy Improved';
      case GpsAlertType.environmentChanged:
        return 'GPS Environment Changed';
    }
  }
}

/// Alert severity levels
enum AlertSeverity {
  low,
  medium,
  high,
  critical;

  String get description {
    switch (this) {
      case AlertSeverity.low:
        return 'Low Priority';
      case AlertSeverity.medium:
        return 'Medium Priority';
      case AlertSeverity.high:
        return 'High Priority';
      case AlertSeverity.critical:
        return 'Critical';
    }
  }

  /// Get color representation for UI
  String get colorHex {
    switch (this) {
      case AlertSeverity.low:
        return '#4CAF50'; // Green
      case AlertSeverity.medium:
        return '#FF9800'; // Orange
      case AlertSeverity.high:
        return '#F44336'; // Red
      case AlertSeverity.critical:
        return '#9C27B0'; // Purple
    }
  }
}

/// Overall GPS quality levels
enum GpsOverallQuality {
  excellent,
  good,
  fair,
  poor,
  unavailable;

  String get description {
    switch (this) {
      case GpsOverallQuality.excellent:
        return 'Excellent GPS Quality';
      case GpsOverallQuality.good:
        return 'Good GPS Quality';
      case GpsOverallQuality.fair:
        return 'Fair GPS Quality';
      case GpsOverallQuality.poor:
        return 'Poor GPS Quality';
      case GpsOverallQuality.unavailable:
        return 'GPS Unavailable';
    }
  }

  /// Get color representation for UI
  String get colorHex {
    switch (this) {
      case GpsOverallQuality.excellent:
        return '#4CAF50'; // Green
      case GpsOverallQuality.good:
        return '#8BC34A'; // Light Green
      case GpsOverallQuality.fair:
        return '#FF9800'; // Orange
      case GpsOverallQuality.poor:
        return '#F44336'; // Red
      case GpsOverallQuality.unavailable:
        return '#9E9E9E'; // Grey
    }
  }

  /// Get score range for this quality level
  String get scoreRange {
    switch (this) {
      case GpsOverallQuality.excellent:
        return '85-100';
      case GpsOverallQuality.good:
        return '70-84';
      case GpsOverallQuality.fair:
        return '50-69';
      case GpsOverallQuality.poor:
        return '30-49';
      case GpsOverallQuality.unavailable:
        return '0-29';
    }
  }
}

/// GPS signal quality levels
enum GpsSignalQuality {
  excellent,
  good,
  fair,
  poor,
  unavailable;

  String get description {
    switch (this) {
      case GpsSignalQuality.excellent:
        return 'Excellent (≤3m accuracy)';
      case GpsSignalQuality.good:
        return 'Good (≤5m accuracy)';
      case GpsSignalQuality.fair:
        return 'Fair (≤10m accuracy)';
      case GpsSignalQuality.poor:
        return 'Poor (≤20m accuracy)';
      case GpsSignalQuality.unavailable:
        return 'Unavailable (>20m accuracy)';
    }
  }

  /// Get accuracy threshold for this quality level
  double get accuracyThreshold {
    switch (this) {
      case GpsSignalQuality.excellent:
        return 3.0;
      case GpsSignalQuality.good:
        return 5.0;
      case GpsSignalQuality.fair:
        return 10.0;
      case GpsSignalQuality.poor:
        return 20.0;
      case GpsSignalQuality.unavailable:
        return double.infinity;
    }
  }
}

/// GPS drift levels
enum GpsDriftLevel {
  minimal,
  low,
  moderate,
  high,
  excessive;

  String get description {
    switch (this) {
      case GpsDriftLevel.minimal:
        return 'Minimal (≤2m drift)';
      case GpsDriftLevel.low:
        return 'Low (≤5m drift)';
      case GpsDriftLevel.moderate:
        return 'Moderate (≤10m drift)';
      case GpsDriftLevel.high:
        return 'High (≤20m drift)';
      case GpsDriftLevel.excessive:
        return 'Excessive (>20m drift)';
    }
  }

  /// Get drift threshold for this level
  double get driftThreshold {
    switch (this) {
      case GpsDriftLevel.minimal:
        return 2.0;
      case GpsDriftLevel.low:
        return 5.0;
      case GpsDriftLevel.moderate:
        return 10.0;
      case GpsDriftLevel.high:
        return 20.0;
      case GpsDriftLevel.excessive:
        return double.infinity;
    }
  }
}

/// Environmental conditions affecting GPS
enum EnvironmentalCondition {
  unknown,
  openArea,
  urban,
  suburban,
  urbanCanyon,
  denseForest,
  mountainous,
  indoor,
  underground;

  String get description {
    switch (this) {
      case EnvironmentalCondition.unknown:
        return 'Unknown environment';
      case EnvironmentalCondition.openArea:
        return 'Open area with clear sky view';
      case EnvironmentalCondition.urban:
        return 'Urban environment';
      case EnvironmentalCondition.suburban:
        return 'Suburban environment';
      case EnvironmentalCondition.urbanCanyon:
        return 'Urban canyon with tall buildings';
      case EnvironmentalCondition.denseForest:
        return 'Dense forest or heavy tree cover';
      case EnvironmentalCondition.mountainous:
        return 'Mountainous terrain';
      case EnvironmentalCondition.indoor:
        return 'Indoor environment';
      case EnvironmentalCondition.underground:
        return 'Underground or tunnel';
    }
  }

  /// Get expected GPS impact for this environment
  EnvironmentalImpact get expectedImpact {
    switch (this) {
      case EnvironmentalCondition.openArea:
        return EnvironmentalImpact.minimal;
      case EnvironmentalCondition.suburban:
        return EnvironmentalImpact.low;
      case EnvironmentalCondition.urban:
        return EnvironmentalImpact.low;
      case EnvironmentalCondition.mountainous:
        return EnvironmentalImpact.moderate;
      case EnvironmentalCondition.urbanCanyon:
        return EnvironmentalImpact.high;
      case EnvironmentalCondition.denseForest:
        return EnvironmentalImpact.high;
      case EnvironmentalCondition.indoor:
        return EnvironmentalImpact.severe;
      case EnvironmentalCondition.underground:
        return EnvironmentalImpact.severe;
      case EnvironmentalCondition.unknown:
        return EnvironmentalImpact.moderate;
    }
  }

  /// Get icon name for UI representation
  String get iconName {
    switch (this) {
      case EnvironmentalCondition.openArea:
        return 'landscape';
      case EnvironmentalCondition.urban:
        return 'location_city';
      case EnvironmentalCondition.suburban:
        return 'home';
      case EnvironmentalCondition.urbanCanyon:
        return 'business';
      case EnvironmentalCondition.denseForest:
        return 'park';
      case EnvironmentalCondition.mountainous:
        return 'terrain';
      case EnvironmentalCondition.indoor:
        return 'home_work';
      case EnvironmentalCondition.underground:
        return 'subway';
      case EnvironmentalCondition.unknown:
        return 'help_outline';
    }
  }
}

/// Environmental impact on GPS accuracy
enum EnvironmentalImpact {
  minimal,
  low,
  moderate,
  high,
  severe;

  String get description {
    switch (this) {
      case EnvironmentalImpact.minimal:
        return 'Minimal impact on GPS accuracy';
      case EnvironmentalImpact.low:
        return 'Low impact on GPS accuracy';
      case EnvironmentalImpact.moderate:
        return 'Moderate impact on GPS accuracy';
      case EnvironmentalImpact.high:
        return 'High impact on GPS accuracy';
      case EnvironmentalImpact.severe:
        return 'Severe impact on GPS accuracy';
    }
  }

  /// Get color representation for UI
  String get colorHex {
    switch (this) {
      case EnvironmentalImpact.minimal:
        return '#4CAF50'; // Green
      case EnvironmentalImpact.low:
        return '#8BC34A'; // Light Green
      case EnvironmentalImpact.moderate:
        return '#FF9800'; // Orange
      case EnvironmentalImpact.high:
        return '#F44336'; // Red
      case EnvironmentalImpact.severe:
        return '#9C27B0'; // Purple
    }
  }

  /// Get expected accuracy degradation factor
  double get accuracyDegradationFactor {
    switch (this) {
      case EnvironmentalImpact.minimal:
        return 1.0;
      case EnvironmentalImpact.low:
        return 1.5;
      case EnvironmentalImpact.moderate:
        return 2.0;
      case EnvironmentalImpact.high:
        return 3.0;
      case EnvironmentalImpact.severe:
        return 5.0;
    }
  }
}
