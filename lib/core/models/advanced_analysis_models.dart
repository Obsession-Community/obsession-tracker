// Advanced Analysis Models for Milestone 10
// Supports heat maps, pattern analysis, and success rate tracking

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Heat map data point
@immutable
class HeatMapPoint {
  const HeatMapPoint({
    required this.location,
    required this.intensity,
    required this.weight,
    required this.timestamp,
    required this.metadata,
  });

  factory HeatMapPoint.fromJson(Map<String, dynamic> json) => HeatMapPoint(
        location: LatLng(
          json['latitude'] as double,
          json['longitude'] as double,
        ),
        intensity: json['intensity'] as double,
        weight: json['weight'] as double,
        timestamp: DateTime.parse(json['timestamp'] as String),
        metadata: Map<String, dynamic>.from(json['metadata'] as Map),
      );

  final LatLng location;
  final double intensity; // 0.0 to 1.0
  final double weight; // Relative importance
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'intensity': intensity,
        'weight': weight,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };
}

/// Heat map configuration
@immutable
class HeatMapConfig {
  const HeatMapConfig({
    required this.radius,
    required this.maxIntensity,
    required this.gradient,
    required this.opacity,
    required this.blur,
    required this.minOpacity,
  }); // Minimum opacity for points

  factory HeatMapConfig.fromJson(Map<String, dynamic> json) => HeatMapConfig(
        radius: json['radius'] as double,
        maxIntensity: json['maxIntensity'] as double,
        gradient: (json['gradient'] as List<dynamic>)
            .map((e) => HeatMapGradientStop.fromJson(e as Map<String, dynamic>))
            .toList(),
        opacity: json['opacity'] as double,
        blur: json['blur'] as double,
        minOpacity: json['minOpacity'] as double,
      );

  final double radius; // Radius in pixels
  final double maxIntensity; // Maximum intensity value
  final List<HeatMapGradientStop> gradient;
  final double opacity; // Overall opacity 0.0 to 1.0
  final double blur; // Blur factor
  final double minOpacity;

  Map<String, dynamic> toJson() => {
        'radius': radius,
        'maxIntensity': maxIntensity,
        'gradient': gradient.map((e) => e.toJson()).toList(),
        'opacity': opacity,
        'blur': blur,
        'minOpacity': minOpacity,
      };
}

/// Heat map gradient stop
@immutable
class HeatMapGradientStop {
  const HeatMapGradientStop({
    required this.offset,
    required this.color,
  }); // ARGB color value

  factory HeatMapGradientStop.fromJson(Map<String, dynamic> json) =>
      HeatMapGradientStop(
        offset: json['offset'] as double,
        color: json['color'] as int,
      );

  final double offset; // 0.0 to 1.0
  final int color;

  Map<String, dynamic> toJson() => {
        'offset': offset,
        'color': color,
      };
}

/// Heat map types
enum HeatMapType {
  activity, // Activity frequency
  speed, // Speed distribution
  elevation, // Elevation changes
  duration, // Time spent
  waypoints, // Waypoint density
  photos, // Photo locations
  success, // Success rate
  difficulty, // Route difficulty
}

/// Analysis time period
enum AnalysisPeriod {
  day,
  week,
  month,
  quarter,
  year,
  allTime,
  custom,
}

/// Pattern analysis result
@immutable
class PatternAnalysisResult {
  const PatternAnalysisResult({
    required this.patternId,
    required this.type,
    required this.confidence,
    required this.frequency,
    required this.locations,
    required this.timePattern,
    required this.characteristics,
    required this.predictions,
    required this.recommendations,
  });

  factory PatternAnalysisResult.fromJson(Map<String, dynamic> json) =>
      PatternAnalysisResult(
        patternId: json['patternId'] as String,
        type: PatternType.values[json['type'] as int],
        confidence: json['confidence'] as double,
        frequency: json['frequency'] as int,
        locations: (json['locations'] as List<dynamic>)
            .map((e) => LatLng(e['lat'] as double, e['lng'] as double))
            .toList(),
        timePattern:
            TimePattern.fromJson(json['timePattern'] as Map<String, dynamic>),
        characteristics:
            Map<String, dynamic>.from(json['characteristics'] as Map),
        predictions: (json['predictions'] as List<dynamic>).cast<String>(),
        recommendations:
            (json['recommendations'] as List<dynamic>).cast<String>(),
      );

  final String patternId;
  final PatternType type;
  final double confidence; // 0.0 to 1.0
  final int frequency; // How often this pattern occurs
  final List<LatLng> locations; // Key locations for this pattern
  final TimePattern timePattern;
  final Map<String, dynamic> characteristics;
  final List<String> predictions;
  final List<String> recommendations;

  Map<String, dynamic> toJson() => {
        'patternId': patternId,
        'type': type.index,
        'confidence': confidence,
        'frequency': frequency,
        'locations': locations
            .map((e) => {'lat': e.latitude, 'lng': e.longitude})
            .toList(),
        'timePattern': timePattern.toJson(),
        'characteristics': characteristics,
        'predictions': predictions,
        'recommendations': recommendations,
      };
}

/// Pattern types for analysis
enum PatternType {
  routePreference, // Preferred routes
  timePreference, // Preferred times
  locationCluster, // Frequently visited locations
  activityPattern, // Activity type patterns
  seasonalPattern, // Seasonal variations
  weatherPattern, // Weather-based patterns
  performancePattern, // Performance trends
  socialPattern, // Social activity patterns
}

/// Time pattern analysis
@immutable
class TimePattern {
  const TimePattern({
    required this.preferredHours,
    required this.preferredDays,
    required this.seasonalTrends,
    required this.duration,
    required this.frequency,
  }); // Activities per week

  factory TimePattern.fromJson(Map<String, dynamic> json) => TimePattern(
        preferredHours: (json['preferredHours'] as List<dynamic>).cast<int>(),
        preferredDays: (json['preferredDays'] as List<dynamic>).cast<int>(),
        seasonalTrends: Map<String, double>.from(json['seasonalTrends'] as Map),
        duration: Duration(milliseconds: json['duration'] as int),
        frequency: json['frequency'] as double,
      );

  final List<int> preferredHours; // 0-23
  final List<int> preferredDays; // 1-7 (Monday = 1)
  final Map<String, double> seasonalTrends; // Season -> activity level
  final Duration duration; // Typical duration
  final double frequency;

  Map<String, dynamic> toJson() => {
        'preferredHours': preferredHours,
        'preferredDays': preferredDays,
        'seasonalTrends': seasonalTrends,
        'duration': duration.inMilliseconds,
        'frequency': frequency,
      };
}

/// Success rate metrics
@immutable
class SuccessRateMetrics {
  const SuccessRateMetrics({
    required this.overallSuccessRate,
    required this.categorySuccessRates,
    required this.timeBasedSuccessRates,
    required this.locationBasedSuccessRates,
    required this.difficultyBasedSuccessRates,
    required this.trends,
    required this.factors,
  });

  factory SuccessRateMetrics.fromJson(Map<String, dynamic> json) =>
      SuccessRateMetrics(
        overallSuccessRate: json['overallSuccessRate'] as double,
        categorySuccessRates:
            Map<String, double>.from(json['categorySuccessRates'] as Map),
        timeBasedSuccessRates:
            Map<String, double>.from(json['timeBasedSuccessRates'] as Map),
        locationBasedSuccessRates:
            Map<String, double>.from(json['locationBasedSuccessRates'] as Map),
        difficultyBasedSuccessRates: Map<String, double>.from(
            json['difficultyBasedSuccessRates'] as Map),
        trends: (json['trends'] as List<dynamic>)
            .map((e) => SuccessTrend.fromJson(e as Map<String, dynamic>))
            .toList(),
        factors: (json['factors'] as List<dynamic>)
            .map((e) => SuccessFactor.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final double overallSuccessRate; // 0.0 to 1.0
  final Map<String, double> categorySuccessRates; // Category -> success rate
  final Map<String, double>
      timeBasedSuccessRates; // Time period -> success rate
  final Map<String, double>
      locationBasedSuccessRates; // Location -> success rate
  final Map<String, double>
      difficultyBasedSuccessRates; // Difficulty -> success rate
  final List<SuccessTrend> trends;
  final List<SuccessFactor> factors;

  Map<String, dynamic> toJson() => {
        'overallSuccessRate': overallSuccessRate,
        'categorySuccessRates': categorySuccessRates,
        'timeBasedSuccessRates': timeBasedSuccessRates,
        'locationBasedSuccessRates': locationBasedSuccessRates,
        'difficultyBasedSuccessRates': difficultyBasedSuccessRates,
        'trends': trends.map((e) => e.toJson()).toList(),
        'factors': factors.map((e) => e.toJson()).toList(),
      };
}

/// Success trend over time
@immutable
class SuccessTrend {
  const SuccessTrend({
    required this.period,
    required this.successRate,
    required this.change,
    required this.direction,
  });

  factory SuccessTrend.fromJson(Map<String, dynamic> json) => SuccessTrend(
        period: json['period'] as String,
        successRate: json['successRate'] as double,
        change: json['change'] as double,
        direction: TrendDirection.values[json['direction'] as int],
      );

  final String period; // Time period identifier
  final double successRate;
  final double change; // Change from previous period
  final TrendDirection direction;

  Map<String, dynamic> toJson() => {
        'period': period,
        'successRate': successRate,
        'change': change,
        'direction': direction.index,
      };
}

/// Trend direction
enum TrendDirection {
  improving,
  declining,
  stable,
}

/// Factor affecting success rate
@immutable
class SuccessFactor {
  const SuccessFactor({
    required this.name,
    required this.impact,
    required this.correlation,
    required this.description,
  });

  factory SuccessFactor.fromJson(Map<String, dynamic> json) => SuccessFactor(
        name: json['name'] as String,
        impact: json['impact'] as double,
        correlation: json['correlation'] as double,
        description: json['description'] as String,
      );

  final String name;
  final double impact; // -1.0 to 1.0 (negative = decreases success)
  final double correlation; // Statistical correlation
  final String description;

  Map<String, dynamic> toJson() => {
        'name': name,
        'impact': impact,
        'correlation': correlation,
        'description': description,
      };
}

/// Performance analytics data
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

  factory PerformanceAnalytics.fromJson(Map<String, dynamic> json) =>
      PerformanceAnalytics(
        averageSpeed: SpeedAnalytics.fromJson(
            json['averageSpeed'] as Map<String, dynamic>),
        speedTrends: (json['speedTrends'] as List<dynamic>)
            .map((e) => SpeedTrend.fromJson(e as Map<String, dynamic>))
            .toList(),
        distanceMetrics: DistanceMetrics.fromJson(
            json['distanceMetrics'] as Map<String, dynamic>),
        elevationMetrics: ElevationMetrics.fromJson(
            json['elevationMetrics'] as Map<String, dynamic>),
        enduranceMetrics: EnduranceMetrics.fromJson(
            json['enduranceMetrics'] as Map<String, dynamic>),
        efficiencyMetrics: EfficiencyMetrics.fromJson(
            json['efficiencyMetrics'] as Map<String, dynamic>),
        improvementAreas: (json['improvementAreas'] as List<dynamic>)
            .map((e) => ImprovementArea.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final SpeedAnalytics averageSpeed;
  final List<SpeedTrend> speedTrends;
  final DistanceMetrics distanceMetrics;
  final ElevationMetrics elevationMetrics;
  final EnduranceMetrics enduranceMetrics;
  final EfficiencyMetrics efficiencyMetrics;
  final List<ImprovementArea> improvementAreas;

  Map<String, dynamic> toJson() => {
        'averageSpeed': averageSpeed.toJson(),
        'speedTrends': speedTrends.map((e) => e.toJson()).toList(),
        'distanceMetrics': distanceMetrics.toJson(),
        'elevationMetrics': elevationMetrics.toJson(),
        'enduranceMetrics': enduranceMetrics.toJson(),
        'efficiencyMetrics': efficiencyMetrics.toJson(),
        'improvementAreas': improvementAreas.map((e) => e.toJson()).toList(),
      };
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
  }); // Percentage improvement

  factory SpeedAnalytics.fromJson(Map<String, dynamic> json) => SpeedAnalytics(
        current: json['current'] as double,
        average: json['average'] as double,
        maximum: json['maximum'] as double,
        percentile95: json['percentile95'] as double,
        improvement: json['improvement'] as double,
      );

  final double current; // m/s
  final double average; // m/s
  final double maximum; // m/s
  final double percentile95; // m/s
  final double improvement;

  Map<String, dynamic> toJson() => {
        'current': current,
        'average': average,
        'maximum': maximum,
        'percentile95': percentile95,
        'improvement': improvement,
      };
}

/// Speed trend over time
@immutable
class SpeedTrend {
  const SpeedTrend({
    required this.period,
    required this.averageSpeed,
    required this.change,
  });

  factory SpeedTrend.fromJson(Map<String, dynamic> json) => SpeedTrend(
        period: json['period'] as String,
        averageSpeed: json['averageSpeed'] as double,
        change: json['change'] as double,
      );

  final String period;
  final double averageSpeed;
  final double change;

  Map<String, dynamic> toJson() => {
        'period': period,
        'averageSpeed': averageSpeed,
        'change': change,
      };
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

  factory DistanceMetrics.fromJson(Map<String, dynamic> json) =>
      DistanceMetrics(
        totalDistance: json['totalDistance'] as double,
        averageDistance: json['averageDistance'] as double,
        longestDistance: json['longestDistance'] as double,
        weeklyAverage: json['weeklyAverage'] as double,
        monthlyAverage: json['monthlyAverage'] as double,
        improvement: json['improvement'] as double,
      );

  final double totalDistance;
  final double averageDistance;
  final double longestDistance;
  final double weeklyAverage;
  final double monthlyAverage;
  final double improvement;

  Map<String, dynamic> toJson() => {
        'totalDistance': totalDistance,
        'averageDistance': averageDistance,
        'longestDistance': longestDistance,
        'weeklyAverage': weeklyAverage,
        'monthlyAverage': monthlyAverage,
        'improvement': improvement,
      };
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

  factory ElevationMetrics.fromJson(Map<String, dynamic> json) =>
      ElevationMetrics(
        totalElevationGain: json['totalElevationGain'] as double,
        averageElevationGain: json['averageElevationGain'] as double,
        maxElevationGain: json['maxElevationGain'] as double,
        climbingEfficiency: json['climbingEfficiency'] as double,
        improvement: json['improvement'] as double,
      );

  final double totalElevationGain;
  final double averageElevationGain;
  final double maxElevationGain;
  final double climbingEfficiency; // Elevation gain per distance
  final double improvement;

  Map<String, dynamic> toJson() => {
        'totalElevationGain': totalElevationGain,
        'averageElevationGain': averageElevationGain,
        'maxElevationGain': maxElevationGain,
        'climbingEfficiency': climbingEfficiency,
        'improvement': improvement,
      };
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

  factory EnduranceMetrics.fromJson(Map<String, dynamic> json) =>
      EnduranceMetrics(
        totalDuration: Duration(milliseconds: json['totalDuration'] as int),
        averageDuration: Duration(milliseconds: json['averageDuration'] as int),
        longestDuration: Duration(milliseconds: json['longestDuration'] as int),
        enduranceIndex: json['enduranceIndex'] as double,
        improvement: json['improvement'] as double,
      );

  final Duration totalDuration;
  final Duration averageDuration;
  final Duration longestDuration;
  final double enduranceIndex; // Calculated endurance score
  final double improvement;

  Map<String, dynamic> toJson() => {
        'totalDuration': totalDuration.inMilliseconds,
        'averageDuration': averageDuration.inMilliseconds,
        'longestDuration': longestDuration.inMilliseconds,
        'enduranceIndex': enduranceIndex,
        'improvement': improvement,
      };
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
  }); // Combined efficiency score

  factory EfficiencyMetrics.fromJson(Map<String, dynamic> json) =>
      EfficiencyMetrics(
        speedEfficiency: json['speedEfficiency'] as double,
        energyEfficiency: json['energyEfficiency'] as double,
        routeEfficiency: json['routeEfficiency'] as double,
        timeEfficiency: json['timeEfficiency'] as double,
        overallEfficiency: json['overallEfficiency'] as double,
      );

  final double speedEfficiency; // Speed vs. effort ratio
  final double energyEfficiency; // Distance per energy unit
  final double routeEfficiency; // Direct vs. actual distance
  final double timeEfficiency; // Goal achievement rate
  final double overallEfficiency;

  Map<String, dynamic> toJson() => {
        'speedEfficiency': speedEfficiency,
        'energyEfficiency': energyEfficiency,
        'routeEfficiency': routeEfficiency,
        'timeEfficiency': timeEfficiency,
        'overallEfficiency': overallEfficiency,
      };
}

/// Area for improvement
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

  factory ImprovementArea.fromJson(Map<String, dynamic> json) =>
      ImprovementArea(
        category: json['category'] as String,
        currentScore: json['currentScore'] as double,
        targetScore: json['targetScore'] as double,
        priority: ImprovementPriority.values[json['priority'] as int],
        recommendations:
            (json['recommendations'] as List<dynamic>).cast<String>(),
        timeframe: json['timeframe'] as String,
      );

  final String category;
  final double currentScore;
  final double targetScore;
  final ImprovementPriority priority;
  final List<String> recommendations;
  final String timeframe;

  Map<String, dynamic> toJson() => {
        'category': category,
        'currentScore': currentScore,
        'targetScore': targetScore,
        'priority': priority.index,
        'recommendations': recommendations,
        'timeframe': timeframe,
      };
}

/// Improvement priority levels
enum ImprovementPriority {
  low,
  medium,
  high,
  critical,
}

/// Analysis request configuration
@immutable
class AnalysisRequest {
  const AnalysisRequest({
    required this.type,
    required this.period,
    required this.filters,
    required this.options,
  });

  factory AnalysisRequest.fromJson(Map<String, dynamic> json) =>
      AnalysisRequest(
        type: AnalysisType.values[json['type'] as int],
        period: AnalysisPeriod.values[json['period'] as int],
        filters: Map<String, dynamic>.from(json['filters'] as Map),
        options: Map<String, dynamic>.from(json['options'] as Map),
      );

  final AnalysisType type;
  final AnalysisPeriod period;
  final Map<String, dynamic> filters;
  final Map<String, dynamic> options;

  Map<String, dynamic> toJson() => {
        'type': type.index,
        'period': period.index,
        'filters': filters,
        'options': options,
      };
}

/// Analysis types
enum AnalysisType {
  heatMap,
  patternAnalysis,
  successRate,
  performance,
  trends,
  comparison,
  prediction,
}
