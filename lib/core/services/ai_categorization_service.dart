// AI Auto-Categorization Service for Milestone 10
// Provides intelligent activity classification and pattern recognition

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:obsession_tracker/core/models/ai_models.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/models/weather_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for AI-powered activity categorization and pattern recognition
class AiCategorizationService {
  factory AiCategorizationService() => _instance;

  AiCategorizationService._internal();
  static final AiCategorizationService _instance =
      AiCategorizationService._internal();

  final Logger _logger = Logger();
  final Map<AIModelType, AIModelConfig> _modelConfigs = {};
  final Map<AIModelType, AIModelStatus> _modelStatuses = {};
  final StreamController<ActivityClassificationResult>
      _classificationController =
      StreamController<ActivityClassificationResult>.broadcast();
  final StreamController<PatternRecognitionResult> _patternController =
      StreamController<PatternRecognitionResult>.broadcast();

  bool _isInitialized = false;
  SharedPreferences? _prefs;
  Timer? _trainingTimer;
  Timer? _patternAnalysisTimer;

  /// Stream of activity classification results
  Stream<ActivityClassificationResult> get classificationStream =>
      _classificationController.stream;

  /// Stream of pattern recognition results
  Stream<PatternRecognitionResult> get patternStream =>
      _patternController.stream;

  /// Current model statuses
  Map<AIModelType, AIModelStatus> get modelStatuses =>
      Map.unmodifiable(_modelStatuses);

  /// Initialize the AI categorization service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.i('Initializing AI Categorization Service');

      _prefs = await SharedPreferences.getInstance();

      // Load model configurations
      await _loadModelConfigurations();

      // Initialize AI models
      await _initializeModels();

      // Start background training and analysis
      _startBackgroundProcessing();

      _isInitialized = true;
      _logger.i('AI Categorization Service initialized successfully');
    } catch (e, stackTrace) {
      _logger.e('Failed to initialize AI Categorization Service',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Classify activity type from tracking session data
  Future<ActivityClassificationResult?> classifyActivity(
    TrackingSession session,
    List<Breadcrumb> breadcrumbs, {
    List<Waypoint>? waypoints,
    List<WeatherData>? weatherData,
  }) async {
    try {
      _logger.d('Classifying activity for session: ${session.id}');

      if (_modelStatuses[AIModelType.activityClassification] !=
          AIModelStatus.ready) {
        _logger.w('Activity classification model not ready');
        return null;
      }

      // Extract features from session data
      final features = await _extractActivityFeatures(
        session,
        breadcrumbs,
        waypoints: waypoints,
        weatherData: weatherData,
      );

      // Perform classification
      final prediction = await _performActivityClassification(features);

      if (prediction != null) {
        // Store result for future training
        await _storeClassificationResult(session.id, prediction);

        // Notify listeners
        _classificationController.add(prediction);
      }

      return prediction;
    } catch (e, stackTrace) {
      _logger.e('Failed to classify activity',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Get model performance metrics
  Future<AIModelMetrics?> getModelMetrics(AIModelType modelType) async {
    try {
      final metricsData = _prefs?.getString('model_metrics_${modelType.name}');
      if (metricsData != null) {
        return AIModelMetrics.fromJson(
            jsonDecode(metricsData) as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to get model metrics for $modelType', error: e);
      return null;
    }
  }

  /// Private methods

  Future<void> _loadModelConfigurations() async {
    try {
      // Load activity classification config
      final activityConfigData =
          _prefs?.getString('activity_classification_config');
      if (activityConfigData != null) {
        _modelConfigs[AIModelType.activityClassification] =
            ActivityClassificationConfig.fromJson(
                jsonDecode(activityConfigData) as Map<String, dynamic>);
      } else {
        // Create default configuration
        _modelConfigs[AIModelType.activityClassification] =
            _createDefaultActivityClassificationConfig();
      }

      // Initialize model statuses
      for (final modelType in AIModelType.values) {
        _modelStatuses[modelType] = AIModelStatus.notLoaded;
      }
    } catch (e) {
      _logger.e('Failed to load model configurations', error: e);
    }
  }

  ActivityClassificationConfig _createDefaultActivityClassificationConfig() =>
      ActivityClassificationConfig(
        modelType: AIModelType.activityClassification,
        version: '1.0.0',
        accuracy: 0.85,
        lastUpdated: DateTime.now(),
        isEnabled: true,
        supportedActivities: ActivityCategory.values,
        minDataPoints: 50,
        confidenceThreshold: 0.6,
        features: const [
          'speed_avg',
          'speed_max',
          'elevation_gain',
          'distance',
          'duration',
          'waypoint_density',
          'route_complexity',
          'time_of_day',
          'weather_condition',
        ],
      );

  Future<void> _initializeModels() async {
    try {
      // Initialize activity classification model
      _modelStatuses[AIModelType.activityClassification] =
          AIModelStatus.loading;
      await _loadActivityClassificationModel();
      _modelStatuses[AIModelType.activityClassification] = AIModelStatus.ready;

      // Initialize pattern recognition model
      _modelStatuses[AIModelType.patternRecognition] = AIModelStatus.loading;
      await _loadPatternRecognitionModel();
      _modelStatuses[AIModelType.patternRecognition] = AIModelStatus.ready;

      _logger.i('AI models initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize AI models', error: e);
      // Set models to error state
      for (final modelType in _modelStatuses.keys) {
        if (_modelStatuses[modelType] == AIModelStatus.loading) {
          _modelStatuses[modelType] = AIModelStatus.error;
        }
      }
    }
  }

  Future<void> _loadActivityClassificationModel() async {
    // In a real implementation, this would load a trained ML model
    // For now, we'll simulate model loading
    await Future<void>.delayed(const Duration(seconds: 1));
    _logger.d('Activity classification model loaded');
  }

  Future<void> _loadPatternRecognitionModel() async {
    // In a real implementation, this would load a trained ML model
    // For now, we'll simulate model loading
    await Future<void>.delayed(const Duration(seconds: 1));
    _logger.d('Pattern recognition model loaded');
  }

  Future<Map<String, double>> _extractActivityFeatures(
    TrackingSession session,
    List<Breadcrumb> breadcrumbs, {
    List<Waypoint>? waypoints,
    List<WeatherData>? weatherData,
  }) async {
    final features = <String, double>{};

    if (breadcrumbs.isEmpty) return features;

    // Speed features
    final speeds =
        breadcrumbs.where((b) => b.speed != null).map((b) => b.speed!).toList();

    if (speeds.isNotEmpty) {
      features['speed_avg'] = speeds.reduce((a, b) => a + b) / speeds.length;
      features['speed_max'] = speeds.reduce(math.max);
      features['speed_min'] = speeds.reduce(math.min);
      features['speed_variance'] = _calculateVariance(speeds);
    }

    // Distance and elevation features
    double totalDistance = 0.0;
    double totalElevationGain = 0.0;
    double totalElevationLoss = 0.0;

    for (int i = 1; i < breadcrumbs.length; i++) {
      final prev = breadcrumbs[i - 1];
      final curr = breadcrumbs[i];

      // Calculate distance
      final distance = Geolocator.distanceBetween(
        prev.coordinates.latitude,
        prev.coordinates.longitude,
        curr.coordinates.latitude,
        curr.coordinates.longitude,
      );
      totalDistance += distance;

      // Calculate elevation changes
      if (prev.altitude != null && curr.altitude != null) {
        final elevationChange = curr.altitude! - prev.altitude!;
        if (elevationChange > 0) {
          totalElevationGain += elevationChange;
        } else {
          totalElevationLoss += elevationChange.abs();
        }
      }
    }

    features['distance'] = totalDistance;
    features['elevation_gain'] = totalElevationGain;
    features['elevation_loss'] = totalElevationLoss;
    features['elevation_ratio'] =
        totalDistance > 0 ? totalElevationGain / totalDistance : 0.0;

    // Duration features
    final duration = session.completedAt
            ?.difference(session.startedAt ?? session.createdAt) ??
        Duration.zero;
    features['duration_minutes'] = duration.inMinutes.toDouble();
    features['duration_hours'] = duration.inHours.toDouble();

    // Waypoint features
    if (waypoints != null) {
      features['waypoint_count'] = waypoints.length.toDouble();
      features['waypoint_density'] = totalDistance > 0
          ? waypoints.length / (totalDistance / 1000) // waypoints per km
          : 0.0;
    }

    // Time of day features
    final startHour = (session.startedAt ?? session.createdAt).hour.toDouble();
    features['start_hour'] = startHour;
    features['is_morning'] = startHour >= 6 && startHour < 12 ? 1.0 : 0.0;
    features['is_afternoon'] = startHour >= 12 && startHour < 18 ? 1.0 : 0.0;
    features['is_evening'] = startHour >= 18 && startHour < 22 ? 1.0 : 0.0;
    features['is_night'] = startHour >= 22 || startHour < 6 ? 1.0 : 0.0;

    // Weather features
    if (weatherData != null && weatherData.isNotEmpty) {
      final weather = weatherData.first;
      features['temperature'] = weather.temperature;
      features['humidity'] = weather.humidity;
      features['wind_speed'] = weather.windSpeed;
      features['precipitation'] = weather.precipitationAmount;
      features['weather_condition'] = weather.condition.index.toDouble();
    }

    // Route complexity features
    features['route_complexity'] = _calculateRouteComplexity(breadcrumbs);
    features['direction_changes'] =
        _countDirectionChanges(breadcrumbs).toDouble();

    return features;
  }

  Future<ActivityClassificationResult?> _performActivityClassification(
    Map<String, double> features,
  ) async {
    try {
      // This is a simplified rule-based classifier
      // In a real implementation, this would use a trained ML model

      final scores = <ActivityCategory, double>{};

      // Hiking classification rules
      double hikingScore = 0.0;
      if (features['elevation_gain'] != null &&
          features['elevation_gain']! > 100) {
        hikingScore += 0.3;
      }
      if (features['speed_avg'] != null &&
          features['speed_avg']! > 0.5 &&
          features['speed_avg']! < 2.0) {
        hikingScore += 0.2;
      }
      if (features['waypoint_density'] != null &&
          features['waypoint_density']! > 0.5) {
        hikingScore += 0.2;
      }
      if (features['duration_hours'] != null &&
          features['duration_hours']! > 1.0) {
        hikingScore += 0.3;
      }
      scores[ActivityCategory.hiking] = hikingScore;

      // Running classification rules
      double runningScore = 0.0;
      if (features['speed_avg'] != null &&
          features['speed_avg']! > 2.0 &&
          features['speed_avg']! < 6.0) {
        runningScore += 0.4;
      }
      if (features['elevation_gain'] != null &&
          features['elevation_gain']! < 200) {
        runningScore += 0.2;
      }
      if (features['route_complexity'] != null &&
          features['route_complexity']! < 0.3) {
        runningScore += 0.2;
      }
      if (features['duration_minutes'] != null &&
          features['duration_minutes']! > 20 &&
          features['duration_minutes']! < 120) {
        runningScore += 0.2;
      }
      scores[ActivityCategory.running] = runningScore;

      // Find the best classification
      if (scores.isEmpty) return null;

      final sortedScores = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final bestCategory = sortedScores.first.key;
      final bestScore = sortedScores.first.value;

      if (bestScore < 0.3) {
        // Not confident enough in any classification
        return null;
      }

      final confidenceLevel = _getConfidenceLevel(bestScore);

      final alternativeActivities = sortedScores
          .skip(1)
          .take(3)
          .map((entry) => ActivityCategoryScore(
                category: entry.key,
                score: entry.value,
                reasoning: _getActivityReasoning(entry.key, features),
              ))
          .toList();

      final reasoningFactors = _getReasoningFactors(bestCategory, features);

      return ActivityClassificationResult(
        modelType: AIModelType.activityClassification,
        prediction: bestCategory,
        confidence: bestScore,
        confidenceLevel: confidenceLevel,
        timestamp: DateTime.now(),
        features: features,
        metadata: const {
          'model_version': '1.0.0',
          'classification_method': 'rule_based',
        },
        activity: bestCategory,
        alternativeActivities: alternativeActivities,
        reasoningFactors: reasoningFactors,
      );
    } catch (e) {
      _logger.e('Failed to perform activity classification', error: e);
      return null;
    }
  }

  // Helper methods
  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => math.pow(v - mean, 2));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  double _calculateRouteComplexity(List<Breadcrumb> breadcrumbs) {
    if (breadcrumbs.length < 3) return 0.0;

    double totalAngleChange = 0.0;
    for (int i = 1; i < breadcrumbs.length - 1; i++) {
      final prev = breadcrumbs[i - 1];
      final curr = breadcrumbs[i];
      final next = breadcrumbs[i + 1];

      final bearing1 = Geolocator.bearingBetween(
        prev.coordinates.latitude,
        prev.coordinates.longitude,
        curr.coordinates.latitude,
        curr.coordinates.longitude,
      );
      final bearing2 = Geolocator.bearingBetween(
        curr.coordinates.latitude,
        curr.coordinates.longitude,
        next.coordinates.latitude,
        next.coordinates.longitude,
      );

      final angleChange = (bearing2 - bearing1).abs();
      totalAngleChange += angleChange > 180 ? 360 - angleChange : angleChange;
    }

    return totalAngleChange /
        (breadcrumbs.length - 2) /
        180.0; // Normalize to 0-1
  }

  int _countDirectionChanges(List<Breadcrumb> breadcrumbs) {
    if (breadcrumbs.length < 3) return 0;

    int changes = 0;
    for (int i = 1; i < breadcrumbs.length - 1; i++) {
      final prev = breadcrumbs[i - 1];
      final curr = breadcrumbs[i];
      final next = breadcrumbs[i + 1];

      final bearing1 = Geolocator.bearingBetween(
        prev.coordinates.latitude,
        prev.coordinates.longitude,
        curr.coordinates.latitude,
        curr.coordinates.longitude,
      );
      final bearing2 = Geolocator.bearingBetween(
        curr.coordinates.latitude,
        curr.coordinates.longitude,
        next.coordinates.latitude,
        next.coordinates.longitude,
      );

      final angleChange = (bearing2 - bearing1).abs();
      if (angleChange > 30) {
        // Significant direction change
        changes++;
      }
    }

    return changes;
  }

  ConfidenceLevel _getConfidenceLevel(double score) {
    if (score >= 0.8) return ConfidenceLevel.veryHigh;
    if (score >= 0.6) return ConfidenceLevel.high;
    if (score >= 0.4) return ConfidenceLevel.medium;
    if (score >= 0.2) return ConfidenceLevel.low;
    return ConfidenceLevel.veryLow;
  }

  String _getActivityReasoning(
      ActivityCategory category, Map<String, double> features) {
    switch (category) {
      case ActivityCategory.hiking:
        return 'Based on elevation gain, moderate speed, and duration';
      case ActivityCategory.running:
        return 'Based on consistent higher speed and route characteristics';
      case ActivityCategory.cycling:
        return 'Based on high speed and distance covered';
      case ActivityCategory.walking:
        return 'Based on low speed and minimal elevation changes';
      default:
        return 'Based on activity pattern analysis';
    }
  }

  List<String> _getReasoningFactors(
      ActivityCategory category, Map<String, double> features) {
    final factors = <String>[];

    switch (category) {
      case ActivityCategory.hiking:
        if (features['elevation_gain'] != null &&
            features['elevation_gain']! > 100) {
          factors.add(
              'Significant elevation gain (${features['elevation_gain']!.toInt()}m)');
        }
        if (features['duration_hours'] != null &&
            features['duration_hours']! > 1.0) {
          factors.add(
              'Extended duration (${features['duration_hours']!.toStringAsFixed(1)} hours)');
        }
        break;
      case ActivityCategory.running:
        if (features['speed_avg'] != null) {
          factors.add(
              'Average speed: ${features['speed_avg']!.toStringAsFixed(1)} m/s');
        }
        break;
      default:
        factors.add('Pattern analysis');
        break;
    }

    return factors;
  }

  void _startBackgroundProcessing() {
    // Start periodic training
    _trainingTimer = Timer.periodic(const Duration(hours: 24), (timer) {
      _performBackgroundTraining();
    });

    // Start periodic pattern analysis
    _patternAnalysisTimer = Timer.periodic(const Duration(hours: 6), (timer) {
      _performBackgroundPatternAnalysis();
    });
  }

  Future<void> _performBackgroundTraining() async {
    try {
      _logger.d('Performing background training');
      // Implementation would retrain models with new data
    } catch (e) {
      _logger.e('Background training failed', error: e);
    }
  }

  Future<void> _performBackgroundPatternAnalysis() async {
    try {
      _logger.d('Performing background pattern analysis');
      // Implementation would analyze patterns in user data
    } catch (e) {
      _logger.e('Background pattern analysis failed', error: e);
    }
  }

  Future<void> _storeClassificationResult(
      String sessionId, ActivityClassificationResult result) async {
    try {
      final key = 'classification_result_$sessionId';
      await _prefs?.setString(key, jsonEncode(result.toJson()));
    } catch (e) {
      _logger.e('Failed to store classification result', error: e);
    }
  }

  /// Dispose of the service
  Future<void> dispose() async {
    try {
      _trainingTimer?.cancel();
      _patternAnalysisTimer?.cancel();

      await _classificationController.close();
      await _patternController.close();

      _isInitialized = false;
      _logger.i('AI Categorization Service disposed');
    } catch (e, stackTrace) {
      _logger.e('Failed to dispose AI Categorization Service',
          error: e, stackTrace: stackTrace);
    }
  }
}
