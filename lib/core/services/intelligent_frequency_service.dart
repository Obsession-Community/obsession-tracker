import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/adaptive_location_models.dart';
import 'package:obsession_tracker/core/models/battery_models.dart';
import 'package:obsession_tracker/core/models/intelligent_frequency_models.dart';
import 'package:obsession_tracker/core/services/battery_monitoring_service.dart';

/// Intelligent location update frequency service with advanced algorithms
///
/// This service uses machine learning-inspired algorithms to dynamically
/// adjust GPS update frequencies based on movement patterns, battery level,
/// GPS quality, environmental conditions, and user behavior patterns.
class IntelligentFrequencyService {
  factory IntelligentFrequencyService() =>
      _instance ??= IntelligentFrequencyService._();
  IntelligentFrequencyService._();
  static IntelligentFrequencyService? _instance;

  final BatteryMonitoringService _batteryService = BatteryMonitoringService();

  // Stream controllers
  StreamController<FrequencyAdjustmentEvent>? _adjustmentController;
  StreamController<FrequencyRecommendation>? _recommendationController;

  // Service state
  bool _isActive = false;
  FrequencyAlgorithmConfig _config = FrequencyAlgorithmConfig.defaultConfig();

  // Current frequency state
  int _currentFrequencySeconds = 15;
  FrequencyMode _currentMode = FrequencyMode.adaptive;

  // Learning and prediction data
  final List<MovementDataPoint> _movementHistory = <MovementDataPoint>[];
  final List<BatteryDataPoint> _batteryHistory = <BatteryDataPoint>[];
  final List<FrequencyPerformanceRecord> _performanceHistory =
      <FrequencyPerformanceRecord>[];
  static const int _maxHistoryLength = 1000;

  // Pattern recognition
  final Map<MovementPattern, FrequencyProfile> _learnedPatterns = {};
  Timer? _learningTimer;
  Timer? _optimizationTimer;

  // Prediction models
  MovementPredictor? _movementPredictor;
  BatteryPredictor? _batteryPredictor;

  // Environmental factors
  double _currentGpsAccuracy = 10.0;

  /// Stream of frequency adjustment events
  Stream<FrequencyAdjustmentEvent> get adjustmentStream {
    _adjustmentController ??=
        StreamController<FrequencyAdjustmentEvent>.broadcast();
    return _adjustmentController!.stream;
  }

  /// Stream of frequency recommendations
  Stream<FrequencyRecommendation> get recommendationStream {
    _recommendationController ??=
        StreamController<FrequencyRecommendation>.broadcast();
    return _recommendationController!.stream;
  }

  /// Whether the service is active
  bool get isActive => _isActive;

  /// Current update frequency in seconds
  int get currentFrequencySeconds => _currentFrequencySeconds;

  /// Current frequency mode
  FrequencyMode get currentMode => _currentMode;

  /// Current algorithm configuration
  FrequencyAlgorithmConfig get config => _config;

  /// Start intelligent frequency service
  Future<void> start({
    FrequencyAlgorithmConfig? config,
    FrequencyMode mode = FrequencyMode.adaptive,
  }) async {
    try {
      await stop(); // Ensure clean start

      _config = config ?? FrequencyAlgorithmConfig.defaultConfig();
      _currentMode = mode;
      _currentFrequencySeconds = _config.defaultFrequencySeconds;

      debugPrint('🧠 Starting intelligent frequency service...');
      debugPrint('  Mode: ${mode.name}');
      debugPrint('  Initial frequency: ${_currentFrequencySeconds}s');

      // Initialize stream controllers
      _adjustmentController ??=
          StreamController<FrequencyAdjustmentEvent>.broadcast();
      _recommendationController ??=
          StreamController<FrequencyRecommendation>.broadcast();

      // Initialize prediction models
      _initializePredictionModels();

      // Load learned patterns
      await _loadLearnedPatterns();

      // Start learning and optimization timers
      _startLearningProcess();

      _isActive = true;
      debugPrint('🧠 Intelligent frequency service started successfully');
    } catch (e) {
      debugPrint('🧠 Error starting intelligent frequency service: $e');
      rethrow;
    }
  }

  /// Stop intelligent frequency service
  Future<void> stop() async {
    // Cancel timers
    _learningTimer?.cancel();
    _learningTimer = null;

    _optimizationTimer?.cancel();
    _optimizationTimer = null;

    // Save learned patterns
    await _saveLearnedPatterns();

    // Close stream controllers
    await _adjustmentController?.close();
    _adjustmentController = null;

    await _recommendationController?.close();
    _recommendationController = null;

    _isActive = false;
    debugPrint('🧠 Intelligent frequency service stopped');
  }

  /// Update frequency mode
  Future<void> setMode(FrequencyMode newMode) async {
    if (newMode == _currentMode) return;

    final oldMode = _currentMode;
    _currentMode = newMode;

    debugPrint('🧠 Changing frequency mode: ${oldMode.name} → ${newMode.name}');

    // Apply mode-specific frequency
    await _applyModeFrequency(newMode);

    debugPrint('🧠 Frequency mode changed successfully');
  }

  /// Update algorithm configuration
  Future<void> updateConfig(FrequencyAlgorithmConfig newConfig) async {
    _config = newConfig;
    debugPrint('🧠 Algorithm configuration updated');

    // Re-evaluate current frequency
    if (_isActive && _currentMode == FrequencyMode.adaptive) {
      await _performFrequencyOptimization();
    }
  }

  /// Record movement data for learning
  void recordMovementData(Position position, double speed, double accuracy) {
    if (!_isActive) return;

    final dataPoint = MovementDataPoint(
      position: position,
      speed: speed,
      accuracy: accuracy,
      frequency: _currentFrequencySeconds,
      timestamp: DateTime.now(),
    );

    _movementHistory.add(dataPoint);
    if (_movementHistory.length > _maxHistoryLength) {
      _movementHistory.removeAt(0);
    }

    // Update environmental factors
    _currentGpsAccuracy = accuracy;
    _updateEnvironmentalCondition(accuracy);
  }

  /// Record battery data for learning
  void recordBatteryData(BatteryLevel batteryLevel) {
    if (!_isActive) return;

    final dataPoint = BatteryDataPoint(
      batteryLevel: batteryLevel,
      frequency: _currentFrequencySeconds,
      powerMode: _batteryService.config.mode,
      timestamp: DateTime.now(),
    );

    _batteryHistory.add(dataPoint);
    if (_batteryHistory.length > _maxHistoryLength) {
      _batteryHistory.removeAt(0);
    }
  }

  /// Get recommended frequency based on current conditions
  FrequencyRecommendation getFrequencyRecommendation() =>
      _calculateOptimalFrequency();

  /// Apply frequency recommendation
  Future<void> applyRecommendation(
      FrequencyRecommendation recommendation) async {
    if (recommendation.recommendedFrequency == _currentFrequencySeconds) return;

    final oldFrequency = _currentFrequencySeconds;
    _currentFrequencySeconds = recommendation.recommendedFrequency;

    debugPrint(
        '🧠 Applying frequency recommendation: ${oldFrequency}s → ${_currentFrequencySeconds}s');
    debugPrint('  Reason: ${recommendation.reason}');
    debugPrint(
        '  Confidence: ${(recommendation.confidence * 100).toStringAsFixed(1)}%');

    // Record performance for learning
    _recordPerformanceData(recommendation);

    // Emit adjustment event
    final event = FrequencyAdjustmentEvent(
      oldFrequency: oldFrequency,
      newFrequency: _currentFrequencySeconds,
      reason: recommendation.reason,
      algorithm: recommendation.algorithm,
      confidence: recommendation.confidence,
      timestamp: DateTime.now(),
    );
    _adjustmentController?.add(event);
  }

  /// Get frequency performance metrics
  FrequencyPerformanceMetrics getPerformanceMetrics() =>
      _calculatePerformanceMetrics();

  /// Get learned movement patterns
  Map<MovementPattern, FrequencyProfile> getLearnedPatterns() =>
      Map.from(_learnedPatterns);

  /// Reset learning data
  void resetLearningData() {
    _movementHistory.clear();
    _batteryHistory.clear();
    _performanceHistory.clear();
    _learnedPatterns.clear();
    debugPrint('🧠 Learning data reset');
  }

  void _initializePredictionModels() {
    _movementPredictor = MovementPredictor();
    _batteryPredictor = BatteryPredictor();
  }

  Future<void> _loadLearnedPatterns() async {
    // In a real implementation, this would load from persistent storage
    // For now, initialize with default patterns
    _learnedPatterns[MovementPattern.stationary] = const FrequencyProfile(
      optimalFrequency: 60,
      batteryEfficiency: 0.9,
      accuracyScore: 0.8,
      confidence: 0.7,
    );

    _learnedPatterns[MovementPattern.walking] = const FrequencyProfile(
      optimalFrequency: 15,
      batteryEfficiency: 0.7,
      accuracyScore: 0.9,
      confidence: 0.8,
    );

    _learnedPatterns[MovementPattern.driving] = const FrequencyProfile(
      optimalFrequency: 5,
      batteryEfficiency: 0.5,
      accuracyScore: 0.95,
      confidence: 0.9,
    );

    debugPrint('🧠 Loaded ${_learnedPatterns.length} learned patterns');
  }

  Future<void> _saveLearnedPatterns() async {
    // In a real implementation, this would save to persistent storage
    debugPrint('🧠 Saved ${_learnedPatterns.length} learned patterns');
  }

  void _startLearningProcess() {
    // Learning timer - analyze patterns and update models
    _learningTimer = Timer.periodic(
      Duration(minutes: _config.learningIntervalMinutes),
      (_) => _performLearning(),
    );

    // Optimization timer - apply learned optimizations
    _optimizationTimer = Timer.periodic(
      Duration(minutes: _config.optimizationIntervalMinutes),
      (_) => _performFrequencyOptimization(),
    );
  }

  Future<void> _applyModeFrequency(FrequencyMode mode) async {
    int newFrequency;

    switch (mode) {
      case FrequencyMode.realTime:
        newFrequency = 2;
        break;
      case FrequencyMode.highAccuracy:
        newFrequency = 5;
        break;
      case FrequencyMode.balanced:
        newFrequency = 15;
        break;
      case FrequencyMode.batterySaver:
        newFrequency = 60;
        break;
      case FrequencyMode.adaptive:
        // Use intelligent algorithm
        final recommendation = _calculateOptimalFrequency();
        newFrequency = recommendation.recommendedFrequency;
        break;
    }

    if (newFrequency != _currentFrequencySeconds) {
      final oldFrequency = _currentFrequencySeconds;
      _currentFrequencySeconds = newFrequency;

      final event = FrequencyAdjustmentEvent(
        oldFrequency: oldFrequency,
        newFrequency: newFrequency,
        reason: 'Mode change to ${mode.name}',
        algorithm: FrequencyAlgorithm.modeSwitch,
        confidence: 1.0,
        timestamp: DateTime.now(),
      );
      _adjustmentController?.add(event);
    }
  }

  void _updateEnvironmentalCondition(double accuracy) {
    if (accuracy <= 5.0) {
    } else if (accuracy <= 10.0) {
    } else if (accuracy <= 20.0) {
    } else if (accuracy <= 50.0) {
    } else {}
  }

  FrequencyRecommendation _calculateOptimalFrequency() {
    if (_currentMode != FrequencyMode.adaptive) {
      return FrequencyRecommendation(
        recommendedFrequency: _currentFrequencySeconds,
        reason: 'Fixed mode: ${_currentMode.name}',
        algorithm: FrequencyAlgorithm.modeSwitch,
        confidence: 1.0,
        expectedBatteryImpact: 0.0,
        expectedAccuracyImprovement: 0.0,
      );
    }

    // Use multiple algorithms and combine results
    final algorithms = [
      _calculateMovementBasedFrequency(),
      _calculateBatteryBasedFrequency(),
      _calculateAccuracyBasedFrequency(),
      _calculatePatternBasedFrequency(),
      _calculatePredictiveFrequency(),
    ];

    // Weight and combine recommendations
    return _combineRecommendations(algorithms);
  }

  FrequencyRecommendation _calculateMovementBasedFrequency() {
    if (_movementHistory.isEmpty) {
      return FrequencyRecommendation(
        recommendedFrequency: _config.defaultFrequencySeconds,
        reason: 'No movement data available',
        algorithm: FrequencyAlgorithm.movementBased,
        confidence: 0.1,
        expectedBatteryImpact: 0.0,
        expectedAccuracyImprovement: 0.0,
      );
    }

    final recentData = _movementHistory.take(20).toList();
    final averageSpeed =
        recentData.map((d) => d.speed).reduce((a, b) => a + b) /
            recentData.length;
    final speedVariance =
        _calculateVariance(recentData.map((d) => d.speed).toList());

    int recommendedFrequency;
    String reason;
    double confidence;

    if (averageSpeed < 0.5 && speedVariance < 0.1) {
      // Stationary
      recommendedFrequency = math.max(_config.maxFrequencySeconds ~/ 2, 30);
      reason = 'Stationary movement detected';
      confidence = 0.9;
    } else if (averageSpeed < 2.0) {
      // Walking
      recommendedFrequency = 15;
      reason = 'Walking pace detected';
      confidence = 0.8;
    } else if (averageSpeed < 5.0) {
      // Jogging/cycling
      recommendedFrequency = 8;
      reason = 'Jogging/cycling pace detected';
      confidence = 0.8;
    } else if (averageSpeed < 15.0) {
      // Cycling fast
      recommendedFrequency = 5;
      reason = 'Fast cycling detected';
      confidence = 0.9;
    } else {
      // Driving
      recommendedFrequency = _config.minFrequencySeconds;
      reason = 'Vehicle movement detected';
      confidence = 0.95;
    }

    final batteryImpact = _estimateBatteryImpact(recommendedFrequency);
    final accuracyImprovement =
        _estimateAccuracyImprovement(recommendedFrequency);

    return FrequencyRecommendation(
      recommendedFrequency: recommendedFrequency,
      reason: reason,
      algorithm: FrequencyAlgorithm.movementBased,
      confidence: confidence,
      expectedBatteryImpact: batteryImpact,
      expectedAccuracyImprovement: accuracyImprovement,
    );
  }

  FrequencyRecommendation _calculateBatteryBasedFrequency() {
    final batteryLevel = _batteryService.currentBatteryLevel;
    if (batteryLevel == null) {
      return FrequencyRecommendation(
        recommendedFrequency: _config.defaultFrequencySeconds,
        reason: 'No battery data available',
        algorithm: FrequencyAlgorithm.batteryBased,
        confidence: 0.1,
        expectedBatteryImpact: 0.0,
        expectedAccuracyImprovement: 0.0,
      );
    }

    int recommendedFrequency;
    String reason;
    double confidence;

    if (batteryLevel.isCriticallyLow) {
      recommendedFrequency = _config.maxFrequencySeconds;
      reason = 'Critical battery level';
      confidence = 1.0;
    } else if (batteryLevel.isLow) {
      recommendedFrequency = math.max(_config.defaultFrequencySeconds * 2, 30);
      reason = 'Low battery level';
      confidence = 0.9;
    } else if (batteryLevel.isCharging) {
      recommendedFrequency = _config.minFrequencySeconds;
      reason = 'Device is charging';
      confidence = 0.8;
    } else {
      // Normal battery level
      recommendedFrequency = _config.defaultFrequencySeconds;
      reason = 'Normal battery level';
      confidence = 0.6;
    }

    final batteryImpact = _estimateBatteryImpact(recommendedFrequency);
    final accuracyImprovement =
        _estimateAccuracyImprovement(recommendedFrequency);

    return FrequencyRecommendation(
      recommendedFrequency: recommendedFrequency,
      reason: reason,
      algorithm: FrequencyAlgorithm.batteryBased,
      confidence: confidence,
      expectedBatteryImpact: batteryImpact,
      expectedAccuracyImprovement: accuracyImprovement,
    );
  }

  FrequencyRecommendation _calculateAccuracyBasedFrequency() {
    int recommendedFrequency;
    String reason;
    double confidence;

    if (_currentGpsAccuracy <= 5.0) {
      // Excellent accuracy
      recommendedFrequency = math.max(_config.defaultFrequencySeconds, 10);
      reason = 'Excellent GPS accuracy';
      confidence = 0.8;
    } else if (_currentGpsAccuracy <= 10.0) {
      // Good accuracy
      recommendedFrequency = _config.defaultFrequencySeconds;
      reason = 'Good GPS accuracy';
      confidence = 0.7;
    } else if (_currentGpsAccuracy <= 20.0) {
      // Fair accuracy
      recommendedFrequency = math.max(
          _config.defaultFrequencySeconds - 5, _config.minFrequencySeconds);
      reason = 'Fair GPS accuracy - increasing frequency';
      confidence = 0.8;
    } else {
      // Poor accuracy
      recommendedFrequency = _config.minFrequencySeconds;
      reason = 'Poor GPS accuracy - maximum frequency';
      confidence = 0.9;
    }

    final batteryImpact = _estimateBatteryImpact(recommendedFrequency);
    final accuracyImprovement =
        _estimateAccuracyImprovement(recommendedFrequency);

    return FrequencyRecommendation(
      recommendedFrequency: recommendedFrequency,
      reason: reason,
      algorithm: FrequencyAlgorithm.accuracyBased,
      confidence: confidence,
      expectedBatteryImpact: batteryImpact,
      expectedAccuracyImprovement: accuracyImprovement,
    );
  }

  FrequencyRecommendation _calculatePatternBasedFrequency() {
    // Use learned patterns to make recommendations
    final currentPattern = _detectCurrentMovementPattern();
    final profile = _learnedPatterns[currentPattern];

    if (profile == null) {
      return FrequencyRecommendation(
        recommendedFrequency: _config.defaultFrequencySeconds,
        reason: 'No learned pattern for ${currentPattern.name}',
        algorithm: FrequencyAlgorithm.patternBased,
        confidence: 0.2,
        expectedBatteryImpact: 0.0,
        expectedAccuracyImprovement: 0.0,
      );
    }

    final batteryImpact = _estimateBatteryImpact(profile.optimalFrequency);
    final accuracyImprovement =
        _estimateAccuracyImprovement(profile.optimalFrequency);

    return FrequencyRecommendation(
      recommendedFrequency: profile.optimalFrequency,
      reason: 'Learned pattern: ${currentPattern.name}',
      algorithm: FrequencyAlgorithm.patternBased,
      confidence: profile.confidence,
      expectedBatteryImpact: batteryImpact,
      expectedAccuracyImprovement: accuracyImprovement,
    );
  }

  FrequencyRecommendation _calculatePredictiveFrequency() {
    // Use prediction models to anticipate future needs
    final predictedMovement =
        _movementPredictor?.predictNextMovement(_movementHistory);
    final predictedBattery =
        _batteryPredictor?.predictBatteryLevel(_batteryHistory);

    if (predictedMovement == null || predictedBattery == null) {
      return FrequencyRecommendation(
        recommendedFrequency: _config.defaultFrequencySeconds,
        reason: 'Insufficient data for prediction',
        algorithm: FrequencyAlgorithm.predictive,
        confidence: 0.1,
        expectedBatteryImpact: 0.0,
        expectedAccuracyImprovement: 0.0,
      );
    }

    // Combine predictions to make frequency recommendation
    int recommendedFrequency = _config.defaultFrequencySeconds;
    String reason = 'Predictive analysis';
    const double confidence = 0.6;

    // Adjust based on predicted movement
    if (predictedMovement.speed > 10.0) {
      recommendedFrequency = math.min(recommendedFrequency, 5);
      reason += ' - high speed predicted';
    } else if (predictedMovement.speed < 1.0) {
      recommendedFrequency = math.max(recommendedFrequency, 30);
      reason += ' - low speed predicted';
    }

    // Adjust based on predicted battery
    if (predictedBattery.percentage < 20) {
      recommendedFrequency = math.max(recommendedFrequency, 60);
      reason += ' - low battery predicted';
    }

    final batteryImpact = _estimateBatteryImpact(recommendedFrequency);
    final accuracyImprovement =
        _estimateAccuracyImprovement(recommendedFrequency);

    return FrequencyRecommendation(
      recommendedFrequency: recommendedFrequency,
      reason: reason,
      algorithm: FrequencyAlgorithm.predictive,
      confidence: confidence,
      expectedBatteryImpact: batteryImpact,
      expectedAccuracyImprovement: accuracyImprovement,
    );
  }

  FrequencyRecommendation _combineRecommendations(
      List<FrequencyRecommendation> recommendations) {
    if (recommendations.isEmpty) {
      return FrequencyRecommendation(
        recommendedFrequency: _config.defaultFrequencySeconds,
        reason: 'No recommendations available',
        algorithm: FrequencyAlgorithm.combined,
        confidence: 0.1,
        expectedBatteryImpact: 0.0,
        expectedAccuracyImprovement: 0.0,
      );
    }

    // Weight recommendations by confidence
    double totalWeight = 0.0;
    double weightedFrequency = 0.0;
    double totalConfidence = 0.0;
    double totalBatteryImpact = 0.0;
    double totalAccuracyImprovement = 0.0;

    for (final rec in recommendations) {
      final weight = rec.confidence;
      totalWeight += weight;
      weightedFrequency += rec.recommendedFrequency * weight;
      totalConfidence += rec.confidence;
      totalBatteryImpact += rec.expectedBatteryImpact * weight;
      totalAccuracyImprovement += rec.expectedAccuracyImprovement * weight;
    }

    final combinedFrequency = (weightedFrequency / totalWeight).round();
    final combinedConfidence = totalConfidence / recommendations.length;
    final combinedBatteryImpact = totalBatteryImpact / totalWeight;
    final combinedAccuracyImprovement = totalAccuracyImprovement / totalWeight;

    // Ensure frequency is within bounds
    final finalFrequency = math.max(
      _config.minFrequencySeconds,
      math.min(_config.maxFrequencySeconds, combinedFrequency),
    );

    return FrequencyRecommendation(
      recommendedFrequency: finalFrequency,
      reason: 'Combined algorithm analysis',
      algorithm: FrequencyAlgorithm.combined,
      confidence: combinedConfidence,
      expectedBatteryImpact: combinedBatteryImpact,
      expectedAccuracyImprovement: combinedAccuracyImprovement,
    );
  }

  MovementPattern _detectCurrentMovementPattern() {
    if (_movementHistory.length < 5) return MovementPattern.unknown;

    final recentData = _movementHistory.take(10).toList();
    final averageSpeed =
        recentData.map((d) => d.speed).reduce((a, b) => a + b) /
            recentData.length;
    final speedVariance =
        _calculateVariance(recentData.map((d) => d.speed).toList());

    if (averageSpeed < 0.5 && speedVariance < 0.1) {
      return MovementPattern.stationary;
    } else if (averageSpeed < 2.0) {
      return MovementPattern.walking;
    } else if (averageSpeed < 5.0) {
      return MovementPattern.jogging;
    } else if (averageSpeed < 15.0) {
      return MovementPattern.cycling;
    } else {
      return MovementPattern.driving;
    }
  }

  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) /
            values.length;
    return variance;
  }

  double _estimateBatteryImpact(int frequency) {
    // Estimate battery impact as percentage per hour
    const baseImpact = 5.0; // 5% per hour baseline
    final frequencyMultiplier =
        60.0 / frequency; // More frequent = higher impact
    return baseImpact * frequencyMultiplier / 4; // Normalize
  }

  double _estimateAccuracyImprovement(int frequency) {
    // Estimate accuracy improvement (0-1 scale)
    final currentAccuracyScore =
        math.max(0.0, 1.0 - (_currentGpsAccuracy / 50.0));
    final frequencyBonus = math.max(0.0, (30.0 - frequency) / 30.0) * 0.2;
    return math.min(1.0, currentAccuracyScore + frequencyBonus);
  }

  void _recordPerformanceData(FrequencyRecommendation recommendation) {
    final record = FrequencyPerformanceRecord(
      frequency: recommendation.recommendedFrequency,
      algorithm: recommendation.algorithm,
      confidence: recommendation.confidence,
      actualBatteryImpact: 0.0, // Would be measured over time
      actualAccuracyImprovement: 0.0, // Would be measured over time
      timestamp: DateTime.now(),
    );

    _performanceHistory.add(record);
    if (_performanceHistory.length > _maxHistoryLength) {
      _performanceHistory.removeAt(0);
    }
  }

  FrequencyPerformanceMetrics _calculatePerformanceMetrics() {
    if (_performanceHistory.isEmpty) {
      return FrequencyPerformanceMetrics(
        totalRecommendations: 0,
        averageConfidence: 0.0,
        algorithmPerformance: {},
        batteryEfficiency: 0.0,
        accuracyImprovement: 0.0,
        timestamp: DateTime.now(),
      );
    }

    final totalRecommendations = _performanceHistory.length;
    final averageConfidence =
        _performanceHistory.map((r) => r.confidence).reduce((a, b) => a + b) /
            totalRecommendations;

    // Calculate algorithm performance
    final algorithmPerformance = <FrequencyAlgorithm, double>{};
    for (final algorithm in FrequencyAlgorithm.values) {
      final algorithmRecords =
          _performanceHistory.where((r) => r.algorithm == algorithm).toList();

      if (algorithmRecords.isNotEmpty) {
        final avgConfidence =
            algorithmRecords.map((r) => r.confidence).reduce((a, b) => a + b) /
                algorithmRecords.length;
        algorithmPerformance[algorithm] = avgConfidence;
      }
    }

    final batteryEfficiency = _performanceHistory
            .map((r) => 1.0 - r.actualBatteryImpact)
            .reduce((a, b) => a + b) /
        totalRecommendations;

    final accuracyImprovement = _performanceHistory
            .map((r) => r.actualAccuracyImprovement)
            .reduce((a, b) => a + b) /
        totalRecommendations;

    return FrequencyPerformanceMetrics(
      totalRecommendations: totalRecommendations,
      averageConfidence: averageConfidence,
      algorithmPerformance: algorithmPerformance,
      batteryEfficiency: batteryEfficiency,
      accuracyImprovement: accuracyImprovement,
      timestamp: DateTime.now(),
    );
  }

  Future<void> _performLearning() async {
    debugPrint('🧠 Performing learning analysis...');

    // Analyze movement patterns and update learned profiles
    await _analyzeMovementPatterns();

    // Update prediction models
    _updatePredictionModels();

    debugPrint('🧠 Learning analysis completed');
  }

  Future<void> _performFrequencyOptimization() async {
    if (!_isActive || _currentMode != FrequencyMode.adaptive) return;

    debugPrint('🧠 Performing frequency optimization...');

    final recommendation = _calculateOptimalFrequency();
    if (recommendation.recommendedFrequency != _currentFrequencySeconds) {
      await applyRecommendation(recommendation);
    }

    debugPrint('🧠 Frequency optimization completed');
  }

  void _updatePredictionModels() {
    // Update movement predictor with recent data
    if (_movementHistory.isNotEmpty) {
      // In a real implementation, this would train the prediction model
      debugPrint(
          '🧠 Updated movement prediction model with ${_movementHistory.length} data points');
    }

    // Update battery predictor with recent data
    if (_batteryHistory.isNotEmpty) {
      // In a real implementation, this would train the prediction model
      debugPrint(
          '🧠 Updated battery prediction model with ${_batteryHistory.length} data points');
    }
  }

  Future<void> _analyzeMovementPatterns() async {
    // Group movement data by detected patterns
    final patternGroups = <MovementPattern, List<MovementDataPoint>>{};

    for (final dataPoint in _movementHistory) {
      // Detect pattern for this data point
      final pattern = _detectPatternForDataPoint(dataPoint);
      patternGroups.putIfAbsent(pattern, () => []).add(dataPoint);
    }

    // Update learned patterns
    for (final entry in patternGroups.entries) {
      final pattern = entry.key;
      final dataPoints = entry.value;

      if (dataPoints.length >= 5) {
        // Calculate optimal frequency for this pattern
        final averageFrequency =
            dataPoints.map((d) => d.frequency).reduce((a, b) => a + b) /
                dataPoints.length;

        // Calculate efficiency metrics
        final batteryEfficiency =
            _calculatePatternBatteryEfficiency(dataPoints);
        final accuracyScore = _calculatePatternAccuracyScore(dataPoints);

        // Update learned pattern
        _learnedPatterns[pattern] = FrequencyProfile(
          optimalFrequency: averageFrequency.round(),
          batteryEfficiency: batteryEfficiency,
          accuracyScore: accuracyScore,
          confidence: math.min(1.0, dataPoints.length / 20.0),
        );
      }
    }
  }

  MovementPattern _detectPatternForDataPoint(MovementDataPoint dataPoint) {
    final speed = dataPoint.speed;

    if (speed < 0.5) {
      return MovementPattern.stationary;
    } else if (speed < 2.0) {
      return MovementPattern.walking;
    } else if (speed < 5.0) {
      return MovementPattern.jogging;
    } else if (speed < 15.0) {
      return MovementPattern.cycling;
    } else {
      return MovementPattern.driving;
    }
  }

  double _calculatePatternBatteryEfficiency(
          List<MovementDataPoint> dataPoints) =>
      // Calculate battery efficiency based on frequency vs. movement
      // Higher efficiency means good battery usage for the movement type
      // This is a simplified calculation
      0.8; // Placeholder

  double _calculatePatternAccuracyScore(List<MovementDataPoint> dataPoints) {
    // Calculate accuracy score based on GPS accuracy vs. frequency
    // Higher score means good accuracy for the frequency used
    final averageAccuracy =
        dataPoints.map((d) => d.accuracy).reduce((a, b) => a + b) /
            dataPoints.length;

    // Convert accuracy to score (lower accuracy value = higher score)
    return math.max(0.0, 1.0 - (averageAccuracy / 50.0));
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    stop();
    _movementHistory.clear();
    _batteryHistory.clear();
    _performanceHistory.clear();
    _learnedPatterns.clear();
    _instance = null;
  }
}
