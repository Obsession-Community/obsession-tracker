import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Trend direction
enum TrendDirection {
  improving,
  declining,
  stable,
}

/// Improvement priority
enum ImprovementPriority {
  low,
  medium,
  high,
  critical,
}

/// Success trend
@immutable
class SuccessTrend {
  const SuccessTrend({
    required this.period,
    required this.successRate,
    required this.change,
    required this.direction,
  });

  final String period;
  final double successRate;
  final double change;
  final TrendDirection direction;
}

/// Success factor
@immutable
class SuccessFactor {
  const SuccessFactor({
    required this.name,
    required this.impact,
    required this.correlation,
    required this.description,
  });

  final String name;
  final double impact;
  final double correlation;
  final String description;
}

/// Success metrics
@immutable
class SuccessMetrics {
  const SuccessMetrics({
    required this.overallSuccessRate,
    required this.categorySuccessRates,
    required this.trends,
    required this.factors,
  });

  final double overallSuccessRate;
  final Map<String, double> categorySuccessRates;
  final List<SuccessTrend> trends;
  final List<SuccessFactor> factors;
}

/// Speed analytics
@immutable
class SpeedAnalytics {
  const SpeedAnalytics({
    required this.current,
    required this.average,
    required this.maximum,
    required this.percentile95,
    required this.improvement,
  });

  final double current;
  final double average;
  final double maximum;
  final double percentile95;
  final double improvement;
}

/// Speed trend
@immutable
class SpeedTrend {
  const SpeedTrend({
    required this.period,
    required this.averageSpeed,
    required this.change,
  });

  final String period;
  final double averageSpeed;
  final double change;
}

/// Distance metrics
@immutable
class DistanceMetrics {
  const DistanceMetrics({
    required this.totalDistance,
    required this.averageDistance,
    required this.longestDistance,
    required this.weeklyAverage,
    required this.monthlyAverage,
    required this.improvement,
  });

  final double totalDistance;
  final double averageDistance;
  final double longestDistance;
  final double weeklyAverage;
  final double monthlyAverage;
  final double improvement;
}

/// Elevation metrics
@immutable
class ElevationMetrics {
  const ElevationMetrics({
    required this.totalElevationGain,
    required this.averageElevationGain,
    required this.maxElevationGain,
    required this.climbingEfficiency,
    required this.improvement,
  });

  final double totalElevationGain;
  final double averageElevationGain;
  final double maxElevationGain;
  final double climbingEfficiency;
  final double improvement;
}

/// Endurance metrics
@immutable
class EnduranceMetrics {
  const EnduranceMetrics({
    required this.totalDuration,
    required this.averageDuration,
    required this.longestDuration,
    required this.enduranceIndex,
    required this.improvement,
  });

  final Duration totalDuration;
  final Duration averageDuration;
  final Duration longestDuration;
  final double enduranceIndex;
  final double improvement;
}

/// Efficiency metrics
@immutable
class EfficiencyMetrics {
  const EfficiencyMetrics({
    required this.speedEfficiency,
    required this.energyEfficiency,
    required this.routeEfficiency,
    required this.timeEfficiency,
    required this.overallEfficiency,
  });

  final double speedEfficiency;
  final double energyEfficiency;
  final double routeEfficiency;
  final double timeEfficiency;
  final double overallEfficiency;
}

/// Improvement area
@immutable
class ImprovementArea {
  const ImprovementArea({
    required this.category,
    required this.currentScore,
    required this.targetScore,
    required this.priority,
    required this.recommendations,
    required this.timeframe,
  });

  final String category;
  final double currentScore;
  final double targetScore;
  final ImprovementPriority priority;
  final List<String> recommendations;
  final String timeframe;
}

/// Performance analytics
@immutable
class PerformanceAnalytics {
  const PerformanceAnalytics({
    required this.averageSpeed,
    required this.speedTrends,
    required this.distanceMetrics,
    required this.elevationMetrics,
    required this.enduranceMetrics,
    required this.efficiencyMetrics,
    required this.improvementAreas,
  });

  final SpeedAnalytics averageSpeed;
  final List<SpeedTrend> speedTrends;
  final DistanceMetrics distanceMetrics;
  final ElevationMetrics elevationMetrics;
  final EnduranceMetrics enduranceMetrics;
  final EfficiencyMetrics efficiencyMetrics;
  final List<ImprovementArea> improvementAreas;
}

/// Heat map point
@immutable
class HeatMapPoint {
  const HeatMapPoint({
    required this.location,
    required this.intensity,
    required this.timestamp,
    this.metadata = const {},
  });

  final LatLng location;
  final double intensity;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
}

/// Pattern types
enum PatternType {
  temporal,
  spatial,
  behavioral,
  environmental,
  performance,
}

/// Time pattern
@immutable
class TimePattern {
  const TimePattern({
    required this.hour,
    required this.dayOfWeek,
    required this.frequency,
  });

  final int hour;
  final int dayOfWeek;
  final double frequency;
}

/// Pattern analysis result
@immutable
class PatternAnalysisResult {
  const PatternAnalysisResult({
    required this.type,
    required this.confidence,
    required this.description,
    this.locations = const [],
    this.timePattern,
  });

  final PatternType type;
  final double confidence;
  final String description;
  final List<LatLng> locations;
  final TimePattern? timePattern;
}

/// Success rate metrics
@immutable
class SuccessRateMetrics {
  const SuccessRateMetrics({
    required this.completionRate,
    required this.goalAchievementRate,
    required this.improvementRate,
    required this.consistencyScore,
  });

  final double completionRate;
  final double goalAchievementRate;
  final double improvementRate;
  final double consistencyScore;
}
