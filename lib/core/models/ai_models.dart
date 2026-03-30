// AI and Machine Learning Models for Milestone 10
// Supports auto-categorization, pattern recognition, and intelligent analysis

import 'package:flutter/foundation.dart';

/// AI model types supported by the system
enum AIModelType {
  activityClassification,
  routeOptimization,
  patternRecognition,
  weatherPrediction,
  anomalyDetection,
  behaviorAnalysis,
  locationClustering,
  timeSeriesForecasting,
}

/// AI model status
enum AIModelStatus {
  notLoaded,
  loading,
  loaded,
  training,
  ready,
  error,
  updating,
}

/// Confidence levels for AI predictions
enum ConfidenceLevel {
  veryLow, // 0-20%
  low, // 20-40%
  medium, // 40-60%
  high, // 60-80%
  veryHigh, // 80-100%
}

/// Activity categories that can be auto-detected
enum ActivityCategory {
  hiking,
  running,
  cycling,
  walking,
  climbing,
  skiing,
  kayaking,
  fishing,
  hunting,
  geocaching,
  photography,
  birdwatching,
  camping,
  backpacking,
  mountaineering,
  trailRunning,
  orienteering,
  adventure,
  exploration,
  research,
  survey,
  unknown,
}

/// Base class for AI model configurations
@immutable
abstract class AIModelConfig {
  const AIModelConfig({
    required this.modelType,
    required this.version,
    required this.accuracy,
    required this.lastUpdated,
    required this.isEnabled,
  });

  final AIModelType modelType;
  final String version;
  final double accuracy; // 0.0 to 1.0
  final DateTime lastUpdated;
  final bool isEnabled;

  Map<String, dynamic> toJson();
}

/// Activity classification model configuration
@immutable
class ActivityClassificationConfig extends AIModelConfig {
  const ActivityClassificationConfig({
    required super.modelType,
    required super.version,
    required super.accuracy,
    required super.lastUpdated,
    required super.isEnabled,
    required this.supportedActivities,
    required this.minDataPoints,
    required this.confidenceThreshold,
    required this.features,
  });

  factory ActivityClassificationConfig.fromJson(Map<String, dynamic> json) =>
      ActivityClassificationConfig(
        modelType: AIModelType.values[json['modelType'] as int],
        version: json['version'] as String,
        accuracy: json['accuracy'] as double,
        lastUpdated: DateTime.parse(json['lastUpdated'] as String),
        isEnabled: json['isEnabled'] as bool,
        supportedActivities: (json['supportedActivities'] as List<dynamic>)
            .map((e) => ActivityCategory.values[e as int])
            .toList(),
        minDataPoints: json['minDataPoints'] as int,
        confidenceThreshold: json['confidenceThreshold'] as double,
        features: (json['features'] as List<dynamic>).cast<String>(),
      );

  final List<ActivityCategory> supportedActivities;
  final int minDataPoints;
  final double confidenceThreshold;
  final List<String> features;

  @override
  Map<String, dynamic> toJson() => {
        'modelType': modelType.index,
        'version': version,
        'accuracy': accuracy,
        'lastUpdated': lastUpdated.toIso8601String(),
        'isEnabled': isEnabled,
        'supportedActivities': supportedActivities.map((e) => e.index).toList(),
        'minDataPoints': minDataPoints,
        'confidenceThreshold': confidenceThreshold,
        'features': features,
      };
}

/// AI prediction result
@immutable
class AIPrediction {
  const AIPrediction({
    required this.modelType,
    required this.prediction,
    required this.confidence,
    required this.confidenceLevel,
    required this.timestamp,
    required this.features,
    required this.metadata,
  });

  factory AIPrediction.fromJson(Map<String, dynamic> json) => AIPrediction(
        modelType: AIModelType.values[json['modelType'] as int],
        prediction: json['prediction'],
        confidence: json['confidence'] as double,
        confidenceLevel: ConfidenceLevel.values[json['confidenceLevel'] as int],
        timestamp: DateTime.parse(json['timestamp'] as String),
        features: Map<String, double>.from(json['features'] as Map),
        metadata: Map<String, dynamic>.from(json['metadata'] as Map),
      );

  final AIModelType modelType;
  final dynamic prediction; // Can be ActivityCategory, route, pattern, etc.
  final double confidence; // 0.0 to 1.0
  final ConfidenceLevel confidenceLevel;
  final DateTime timestamp;
  final Map<String, double> features;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'modelType': modelType.index,
        'prediction': prediction,
        'confidence': confidence,
        'confidenceLevel': confidenceLevel.index,
        'timestamp': timestamp.toIso8601String(),
        'features': features,
        'metadata': metadata,
      };

  AIPrediction copyWith({
    AIModelType? modelType,
    Object? prediction,
    double? confidence,
    ConfidenceLevel? confidenceLevel,
    DateTime? timestamp,
    Map<String, double>? features,
    Map<String, dynamic>? metadata,
  }) =>
      AIPrediction(
        modelType: modelType ?? this.modelType,
        prediction: prediction ?? this.prediction,
        confidence: confidence ?? this.confidence,
        confidenceLevel: confidenceLevel ?? this.confidenceLevel,
        timestamp: timestamp ?? this.timestamp,
        features: features ?? this.features,
        metadata: metadata ?? this.metadata,
      );
}

/// Activity classification result
@immutable
class ActivityClassificationResult extends AIPrediction {
  const ActivityClassificationResult({
    required super.modelType,
    required super.prediction,
    required super.confidence,
    required super.confidenceLevel,
    required super.timestamp,
    required super.features,
    required super.metadata,
    required this.activity,
    required this.alternativeActivities,
    required this.reasoningFactors,
  });

  factory ActivityClassificationResult.fromPrediction(
    AIPrediction prediction, {
    required ActivityCategory activity,
    required List<ActivityCategoryScore> alternativeActivities,
    required List<String> reasoningFactors,
  }) =>
      ActivityClassificationResult(
        modelType: prediction.modelType,
        prediction: prediction.prediction,
        confidence: prediction.confidence,
        confidenceLevel: prediction.confidenceLevel,
        timestamp: prediction.timestamp,
        features: prediction.features,
        metadata: prediction.metadata,
        activity: activity,
        alternativeActivities: alternativeActivities,
        reasoningFactors: reasoningFactors,
      );

  final ActivityCategory activity;
  final List<ActivityCategoryScore> alternativeActivities;
  final List<String> reasoningFactors;

  ActivityCategory get predictedActivity => activity;
}

/// Activity category with confidence score
@immutable
class ActivityCategoryScore {
  const ActivityCategoryScore({
    required this.category,
    required this.score,
    required this.reasoning,
  });

  factory ActivityCategoryScore.fromJson(Map<String, dynamic> json) =>
      ActivityCategoryScore(
        category: ActivityCategory.values[json['category'] as int],
        score: json['score'] as double,
        reasoning: json['reasoning'] as String,
      );

  final ActivityCategory category;
  final double score; // 0.0 to 1.0
  final String reasoning;

  Map<String, dynamic> toJson() => {
        'category': category.index,
        'score': score,
        'reasoning': reasoning,
      };
}

/// Pattern recognition result
@immutable
class PatternRecognitionResult {
  const PatternRecognitionResult({
    required this.patternType,
    required this.pattern,
    required this.confidence,
    required this.occurrences,
    required this.timeRange,
    required this.characteristics,
    required this.predictions,
  });

  factory PatternRecognitionResult.fromJson(Map<String, dynamic> json) =>
      PatternRecognitionResult(
        patternType: PatternType.values[json['patternType'] as int],
        pattern: Map<String, dynamic>.from(json['pattern'] as Map),
        confidence: json['confidence'] as double,
        occurrences: json['occurrences'] as int,
        timeRange: DateTimeRange(
          start: DateTime.parse(json['timeRangeStart'] as String),
          end: DateTime.parse(json['timeRangeEnd'] as String),
        ),
        characteristics:
            Map<String, dynamic>.from(json['characteristics'] as Map),
        predictions: (json['predictions'] as List<dynamic>).cast<String>(),
      );

  final PatternType patternType;
  final Map<String, dynamic> pattern;
  final double confidence;
  final int occurrences;
  final DateTimeRange timeRange;
  final Map<String, dynamic> characteristics;
  final List<String> predictions;

  Map<String, dynamic> toJson() => {
        'patternType': patternType.index,
        'pattern': pattern,
        'confidence': confidence,
        'occurrences': occurrences,
        'timeRangeStart': timeRange.start.toIso8601String(),
        'timeRangeEnd': timeRange.end.toIso8601String(),
        'characteristics': characteristics,
        'predictions': predictions,
      };
}

/// Types of patterns that can be recognized
enum PatternType {
  routePattern,
  timePattern,
  locationPattern,
  behaviorPattern,
  seasonalPattern,
  weatherPattern,
  activityPattern,
  performancePattern,
}

/// Route optimization result
@immutable
class RouteOptimizationResult {
  const RouteOptimizationResult({
    required this.originalRoute,
    required this.optimizedRoute,
    required this.improvementMetrics,
    required this.optimizationFactors,
    required this.confidence,
    required this.estimatedSavings,
  });

  factory RouteOptimizationResult.fromJson(Map<String, dynamic> json) =>
      RouteOptimizationResult(
        originalRoute: (json['originalRoute'] as List<dynamic>)
            .map((e) => RoutePoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        optimizedRoute: (json['optimizedRoute'] as List<dynamic>)
            .map((e) => RoutePoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        improvementMetrics: RouteImprovementMetrics.fromJson(
            json['improvementMetrics'] as Map<String, dynamic>),
        optimizationFactors:
            (json['optimizationFactors'] as List<dynamic>).cast<String>(),
        confidence: json['confidence'] as double,
        estimatedSavings:
            Map<String, double>.from(json['estimatedSavings'] as Map),
      );

  final List<RoutePoint> originalRoute;
  final List<RoutePoint> optimizedRoute;
  final RouteImprovementMetrics improvementMetrics;
  final List<String> optimizationFactors;
  final double confidence;
  final Map<String, double> estimatedSavings;

  Map<String, dynamic> toJson() => {
        'originalRoute': originalRoute.map((e) => e.toJson()).toList(),
        'optimizedRoute': optimizedRoute.map((e) => e.toJson()).toList(),
        'improvementMetrics': improvementMetrics.toJson(),
        'optimizationFactors': optimizationFactors,
        'confidence': confidence,
        'estimatedSavings': estimatedSavings,
      };
}

/// Route point for optimization
@immutable
class RoutePoint {
  const RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.elevation,
    required this.timestamp,
    required this.waypoint,
    required this.metadata,
  });

  factory RoutePoint.fromJson(Map<String, dynamic> json) => RoutePoint(
        latitude: json['latitude'] as double,
        longitude: json['longitude'] as double,
        elevation: json['elevation'] as double?,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : null,
        waypoint: json['waypoint'] as bool,
        metadata: Map<String, dynamic>.from(json['metadata'] as Map),
      );

  final double latitude;
  final double longitude;
  final double? elevation;
  final DateTime? timestamp;
  final bool waypoint;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'elevation': elevation,
        'timestamp': timestamp?.toIso8601String(),
        'waypoint': waypoint,
        'metadata': metadata,
      };
}

/// Route improvement metrics
@immutable
class RouteImprovementMetrics {
  const RouteImprovementMetrics({
    required this.distanceReduction,
    required this.timeReduction,
    required this.elevationGainReduction,
    required this.energyEfficiencyImprovement,
    required this.safetyImprovement,
    required this.scenicValueImprovement,
  }); // score 0-1

  factory RouteImprovementMetrics.fromJson(Map<String, dynamic> json) =>
      RouteImprovementMetrics(
        distanceReduction: json['distanceReduction'] as double,
        timeReduction: Duration(milliseconds: json['timeReduction'] as int),
        elevationGainReduction: json['elevationGainReduction'] as double,
        energyEfficiencyImprovement:
            json['energyEfficiencyImprovement'] as double,
        safetyImprovement: json['safetyImprovement'] as double,
        scenicValueImprovement: json['scenicValueImprovement'] as double,
      );

  final double distanceReduction; // meters
  final Duration timeReduction;
  final double elevationGainReduction; // meters
  final double energyEfficiencyImprovement; // percentage
  final double safetyImprovement; // score 0-1
  final double scenicValueImprovement;

  Map<String, dynamic> toJson() => {
        'distanceReduction': distanceReduction,
        'timeReduction': timeReduction.inMilliseconds,
        'elevationGainReduction': elevationGainReduction,
        'energyEfficiencyImprovement': energyEfficiencyImprovement,
        'safetyImprovement': safetyImprovement,
        'scenicValueImprovement': scenicValueImprovement,
      };
}

/// AI training data point
@immutable
class AITrainingData {
  const AITrainingData({
    required this.id,
    required this.modelType,
    required this.features,
    required this.label,
    required this.timestamp,
    required this.source,
    required this.quality,
  }); // 0.0 to 1.0

  factory AITrainingData.fromJson(Map<String, dynamic> json) => AITrainingData(
        id: json['id'] as String,
        modelType: AIModelType.values[json['modelType'] as int],
        features: Map<String, double>.from(json['features'] as Map),
        label: json['label'],
        timestamp: DateTime.parse(json['timestamp'] as String),
        source: json['source'] as String,
        quality: json['quality'] as double,
      );

  final String id;
  final AIModelType modelType;
  final Map<String, double> features;
  final dynamic label;
  final DateTime timestamp;
  final String source;
  final double quality;

  Map<String, dynamic> toJson() => {
        'id': id,
        'modelType': modelType.index,
        'features': features,
        'label': label,
        'timestamp': timestamp.toIso8601String(),
        'source': source,
        'quality': quality,
      };
}

/// AI model performance metrics
@immutable
class AIModelMetrics {
  const AIModelMetrics({
    required this.modelType,
    required this.accuracy,
    required this.precision,
    required this.recall,
    required this.f1Score,
    required this.confusionMatrix,
    required this.trainingDataSize,
    required this.validationDataSize,
    required this.lastEvaluated,
  });

  factory AIModelMetrics.fromJson(Map<String, dynamic> json) => AIModelMetrics(
        modelType: AIModelType.values[json['modelType'] as int],
        accuracy: json['accuracy'] as double,
        precision: json['precision'] as double,
        recall: json['recall'] as double,
        f1Score: json['f1Score'] as double,
        confusionMatrix: Map<String, Map<String, int>>.from(
          (json['confusionMatrix'] as Map).map(
            (key, value) => MapEntry(
              key as String,
              Map<String, int>.from(value as Map),
            ),
          ),
        ),
        trainingDataSize: json['trainingDataSize'] as int,
        validationDataSize: json['validationDataSize'] as int,
        lastEvaluated: DateTime.parse(json['lastEvaluated'] as String),
      );

  final AIModelType modelType;
  final double accuracy;
  final double precision;
  final double recall;
  final double f1Score;
  final Map<String, Map<String, int>> confusionMatrix;
  final int trainingDataSize;
  final int validationDataSize;
  final DateTime lastEvaluated;

  Map<String, dynamic> toJson() => {
        'modelType': modelType.index,
        'accuracy': accuracy,
        'precision': precision,
        'recall': recall,
        'f1Score': f1Score,
        'confusionMatrix': confusionMatrix,
        'trainingDataSize': trainingDataSize,
        'validationDataSize': validationDataSize,
        'lastEvaluated': lastEvaluated.toIso8601String(),
      };
}

/// Helper class for date time ranges
@immutable
class DateTimeRange {
  const DateTimeRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  bool contains(DateTime dateTime) =>
      dateTime.isAfter(start) && dateTime.isBefore(end);

  bool overlaps(DateTimeRange other) =>
      start.isBefore(other.end) && end.isAfter(other.start);
}
