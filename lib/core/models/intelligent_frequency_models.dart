import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/battery_models.dart';

/// Models for intelligent frequency management and optimization
///
/// Provides data structures for machine learning-inspired algorithms
/// that dynamically adjust GPS update frequencies.

/// Frequency management modes
enum FrequencyMode {
  realTime,
  highAccuracy,
  balanced,
  batterySaver,
  adaptive;

  String get name {
    switch (this) {
      case FrequencyMode.realTime:
        return 'Real-time';
      case FrequencyMode.highAccuracy:
        return 'High Accuracy';
      case FrequencyMode.balanced:
        return 'Balanced';
      case FrequencyMode.batterySaver:
        return 'Battery Saver';
      case FrequencyMode.adaptive:
        return 'Adaptive';
    }
  }

  String get description {
    switch (this) {
      case FrequencyMode.realTime:
        return 'Maximum frequency for real-time tracking';
      case FrequencyMode.highAccuracy:
        return 'High frequency for accurate tracking';
      case FrequencyMode.balanced:
        return 'Balanced frequency for general use';
      case FrequencyMode.batterySaver:
        return 'Reduced frequency to save battery';
      case FrequencyMode.adaptive:
        return 'Intelligent frequency based on conditions';
    }
  }
}

/// Frequency adjustment algorithms
enum FrequencyAlgorithm {
  modeSwitch,
  movementBased,
  batteryBased,
  accuracyBased,
  patternBased,
  predictive,
  combined;

  String get name {
    switch (this) {
      case FrequencyAlgorithm.modeSwitch:
        return 'Mode Switch';
      case FrequencyAlgorithm.movementBased:
        return 'Movement Based';
      case FrequencyAlgorithm.batteryBased:
        return 'Battery Based';
      case FrequencyAlgorithm.accuracyBased:
        return 'Accuracy Based';
      case FrequencyAlgorithm.patternBased:
        return 'Pattern Based';
      case FrequencyAlgorithm.predictive:
        return 'Predictive';
      case FrequencyAlgorithm.combined:
        return 'Combined';
    }
  }
}

/// Configuration for frequency algorithms
class FrequencyAlgorithmConfig {
  const FrequencyAlgorithmConfig({
    required this.minFrequencySeconds,
    required this.maxFrequencySeconds,
    required this.defaultFrequencySeconds,
    required this.learningIntervalMinutes,
    required this.optimizationIntervalMinutes,
    required this.enablePredictiveAlgorithms,
    required this.enablePatternLearning,
    required this.batteryThresholds,
    required this.movementThresholds,
    required this.accuracyThresholds,
  });

  /// Default configuration
  factory FrequencyAlgorithmConfig.defaultConfig() =>
      const FrequencyAlgorithmConfig(
        minFrequencySeconds: 2,
        maxFrequencySeconds: 300,
        defaultFrequencySeconds: 15,
        learningIntervalMinutes: 10,
        optimizationIntervalMinutes: 5,
        enablePredictiveAlgorithms: true,
        enablePatternLearning: true,
        batteryThresholds: BatteryThresholds(
          critical: 15,
          low: 30,
          normal: 50,
          high: 80,
        ),
        movementThresholds: MovementThresholds(
          stationary: 0.5,
          walking: 2.0,
          jogging: 5.0,
          cycling: 15.0,
          driving: 50.0,
        ),
        accuracyThresholds: AccuracyThresholds(
          excellent: 5.0,
          good: 10.0,
          fair: 20.0,
          poor: 50.0,
        ),
      );

  final int minFrequencySeconds;
  final int maxFrequencySeconds;
  final int defaultFrequencySeconds;
  final int learningIntervalMinutes;
  final int optimizationIntervalMinutes;
  final bool enablePredictiveAlgorithms;
  final bool enablePatternLearning;
  final BatteryThresholds batteryThresholds;
  final MovementThresholds movementThresholds;
  final AccuracyThresholds accuracyThresholds;

  FrequencyAlgorithmConfig copyWith({
    int? minFrequencySeconds,
    int? maxFrequencySeconds,
    int? defaultFrequencySeconds,
    int? learningIntervalMinutes,
    int? optimizationIntervalMinutes,
    bool? enablePredictiveAlgorithms,
    bool? enablePatternLearning,
    BatteryThresholds? batteryThresholds,
    MovementThresholds? movementThresholds,
    AccuracyThresholds? accuracyThresholds,
  }) =>
      FrequencyAlgorithmConfig(
        minFrequencySeconds: minFrequencySeconds ?? this.minFrequencySeconds,
        maxFrequencySeconds: maxFrequencySeconds ?? this.maxFrequencySeconds,
        defaultFrequencySeconds:
            defaultFrequencySeconds ?? this.defaultFrequencySeconds,
        learningIntervalMinutes:
            learningIntervalMinutes ?? this.learningIntervalMinutes,
        optimizationIntervalMinutes:
            optimizationIntervalMinutes ?? this.optimizationIntervalMinutes,
        enablePredictiveAlgorithms:
            enablePredictiveAlgorithms ?? this.enablePredictiveAlgorithms,
        enablePatternLearning:
            enablePatternLearning ?? this.enablePatternLearning,
        batteryThresholds: batteryThresholds ?? this.batteryThresholds,
        movementThresholds: movementThresholds ?? this.movementThresholds,
        accuracyThresholds: accuracyThresholds ?? this.accuracyThresholds,
      );
}

/// Battery level thresholds
class BatteryThresholds {
  const BatteryThresholds({
    required this.critical,
    required this.low,
    required this.normal,
    required this.high,
  });

  final int critical;
  final int low;
  final int normal;
  final int high;
}

/// Movement speed thresholds
class MovementThresholds {
  const MovementThresholds({
    required this.stationary,
    required this.walking,
    required this.jogging,
    required this.cycling,
    required this.driving,
  });

  final double stationary;
  final double walking;
  final double jogging;
  final double cycling;
  final double driving;
}

/// GPS accuracy thresholds
class AccuracyThresholds {
  const AccuracyThresholds({
    required this.excellent,
    required this.good,
    required this.fair,
    required this.poor,
  });

  final double excellent;
  final double good;
  final double fair;
  final double poor;
}

/// Movement data point for learning
class MovementDataPoint {
  const MovementDataPoint({
    required this.position,
    required this.speed,
    required this.accuracy,
    required this.frequency,
    required this.timestamp,
  });

  final Position position;
  final double speed;
  final double accuracy;
  final int frequency;
  final DateTime timestamp;
}

/// Battery data point for learning
class BatteryDataPoint {
  const BatteryDataPoint({
    required this.batteryLevel,
    required this.frequency,
    required this.powerMode,
    required this.timestamp,
  });

  final BatteryLevel batteryLevel;
  final int frequency;
  final PowerMode powerMode;
  final DateTime timestamp;
}

/// Frequency recommendation
class FrequencyRecommendation {
  const FrequencyRecommendation({
    required this.recommendedFrequency,
    required this.reason,
    required this.algorithm,
    required this.confidence,
    required this.expectedBatteryImpact,
    required this.expectedAccuracyImprovement,
  });

  final int recommendedFrequency;
  final String reason;
  final FrequencyAlgorithm algorithm;
  final double confidence; // 0.0 to 1.0
  final double expectedBatteryImpact; // Percentage per hour
  final double expectedAccuracyImprovement; // 0.0 to 1.0

  @override
  String toString() =>
      'FrequencyRecommendation(${recommendedFrequency}s, ${algorithm.name}, ${(confidence * 100).toStringAsFixed(1)}%)';
}

/// Frequency adjustment event
class FrequencyAdjustmentEvent {
  const FrequencyAdjustmentEvent({
    required this.oldFrequency,
    required this.newFrequency,
    required this.reason,
    required this.algorithm,
    required this.confidence,
    required this.timestamp,
  });

  final int oldFrequency;
  final int newFrequency;
  final String reason;
  final FrequencyAlgorithm algorithm;
  final double confidence;
  final DateTime timestamp;

  @override
  String toString() =>
      'FrequencyAdjustmentEvent(${oldFrequency}s → ${newFrequency}s: $reason)';
}

/// Learned frequency profile for a movement pattern
class FrequencyProfile {
  const FrequencyProfile({
    required this.optimalFrequency,
    required this.batteryEfficiency,
    required this.accuracyScore,
    required this.confidence,
  });

  final int optimalFrequency;
  final double batteryEfficiency; // 0.0 to 1.0
  final double accuracyScore; // 0.0 to 1.0
  final double confidence; // 0.0 to 1.0

  @override
  String toString() =>
      'FrequencyProfile(${optimalFrequency}s, efficiency: ${(batteryEfficiency * 100).toStringAsFixed(1)}%)';
}

/// Frequency performance record
class FrequencyPerformanceRecord {
  const FrequencyPerformanceRecord({
    required this.frequency,
    required this.algorithm,
    required this.confidence,
    required this.actualBatteryImpact,
    required this.actualAccuracyImprovement,
    required this.timestamp,
  });

  final int frequency;
  final FrequencyAlgorithm algorithm;
  final double confidence;
  final double actualBatteryImpact;
  final double actualAccuracyImprovement;
  final DateTime timestamp;
}

/// Frequency performance metrics
class FrequencyPerformanceMetrics {
  const FrequencyPerformanceMetrics({
    required this.totalRecommendations,
    required this.averageConfidence,
    required this.algorithmPerformance,
    required this.batteryEfficiency,
    required this.accuracyImprovement,
    required this.timestamp,
  });

  final int totalRecommendations;
  final double averageConfidence;
  final Map<FrequencyAlgorithm, double> algorithmPerformance;
  final double batteryEfficiency;
  final double accuracyImprovement;
  final DateTime timestamp;
}

/// Movement predictor for anticipating future movement patterns
class MovementPredictor {
  MovementPredictor();

  /// Predict next movement based on historical data
  PredictedMovement? predictNextMovement(List<MovementDataPoint> history) {
    if (history.length < 5) return null;

    final recentData = history.take(10).toList();
    final averageSpeed =
        recentData.map((d) => d.speed).reduce((a, b) => a + b) /
            recentData.length;
    final speedTrend = _calculateSpeedTrend(recentData);

    return PredictedMovement(
      speed: averageSpeed + speedTrend,
      confidence: 0.7,
      timestamp: DateTime.now(),
    );
  }

  double _calculateSpeedTrend(List<MovementDataPoint> data) {
    if (data.length < 2) return 0.0;

    final firstHalf = data
            .take(data.length ~/ 2)
            .map((d) => d.speed)
            .reduce((a, b) => a + b) /
        (data.length ~/ 2);
    final secondHalf = data
            .skip(data.length ~/ 2)
            .map((d) => d.speed)
            .reduce((a, b) => a + b) /
        (data.length - data.length ~/ 2);

    return secondHalf - firstHalf;
  }
}

/// Battery predictor for anticipating battery level changes
class BatteryPredictor {
  BatteryPredictor();

  /// Predict battery level based on historical data
  PredictedBattery? predictBatteryLevel(List<BatteryDataPoint> history) {
    if (history.length < 3) return null;

    final recentData = history.take(10).toList();
    final averageLevel = recentData
            .map((d) => d.batteryLevel.percentage)
            .reduce((a, b) => a + b) /
        recentData.length;
    final drainRate = _calculateDrainRate(recentData);

    // Predict battery level in 1 hour
    final predictedLevel = (averageLevel - drainRate).clamp(0, 100);

    return PredictedBattery(
      percentage: predictedLevel.round(),
      confidence: 0.6,
      timestamp: DateTime.now(),
    );
  }

  double _calculateDrainRate(List<BatteryDataPoint> data) {
    if (data.length < 2) return 0.0;

    final first = data.first;
    final last = data.last;
    final timeDiff = last.timestamp.difference(first.timestamp).inHours;

    if (timeDiff <= 0) return 0.0;

    return (first.batteryLevel.percentage - last.batteryLevel.percentage) /
        timeDiff;
  }
}

/// Predicted movement data
class PredictedMovement {
  const PredictedMovement({
    required this.speed,
    required this.confidence,
    required this.timestamp,
  });

  final double speed;
  final double confidence;
  final DateTime timestamp;
}

/// Predicted battery data
class PredictedBattery {
  const PredictedBattery({
    required this.percentage,
    required this.confidence,
    required this.timestamp,
  });

  final int percentage;
  final double confidence;
  final DateTime timestamp;
}
