import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/adaptive_location_models.dart';
import 'package:obsession_tracker/core/models/gps_accuracy_models.dart';
import 'package:obsession_tracker/core/services/accelerometer_service.dart'
    as accelerometer;
import 'package:obsession_tracker/core/services/gps_accuracy_service.dart';
import 'package:obsession_tracker/core/services/location_service.dart';
import 'package:obsession_tracker/core/services/sensor_fusion_service.dart';

/// Adaptive location update service that intelligently adjusts tracking parameters
/// based on movement patterns, GPS accuracy, and environmental conditions.
///
/// This service enhances the existing location tracking by:
/// - Dynamically adjusting update intervals based on activity
/// - Optimizing accuracy requirements based on movement speed
/// - Adapting to environmental conditions for better battery life
/// - Providing intelligent frequency adjustment algorithms
class AdaptiveLocationService {
  factory AdaptiveLocationService() =>
      _instance ??= AdaptiveLocationService._();
  AdaptiveLocationService._();
  static AdaptiveLocationService? _instance;

  final LocationService _locationService = LocationService();
  final GpsAccuracyService _gpsAccuracyService = GpsAccuracyService();
  SensorFusionService? _sensorFusionService;

  // Stream controllers
  StreamController<AdaptiveLocationUpdate>? _updateController;
  StreamController<LocationTrackingParameters>? _parametersController;

  // Service state
  bool _isActive = false;
  AdaptiveTrackingMode _mode = AdaptiveTrackingMode.balanced;
  LocationTrackingParameters _currentParameters =
      LocationTrackingParameters.defaultParameters();

  // Location tracking
  StreamSubscription<EnhancedLocationData>? _locationSubscription;
  StreamSubscription<GpsQualityReading>? _gpsQualitySubscription;
  StreamSubscription<SensorFusionReading>? _sensorSubscription;

  // Movement analysis
  final List<MovementSample> _movementHistory = <MovementSample>[];
  static const int _maxMovementHistoryLength = 20;
  MovementPattern _currentMovementPattern = MovementPattern.unknown;
  ActivityLevel _currentActivityLevel = ActivityLevel.unknown;

  // Adaptive parameters
  Timer? _adaptationTimer;
  DateTime _lastAdaptation = DateTime.now();
  static const Duration _adaptationInterval = Duration(seconds: 30);

  // Performance tracking
  final List<LocationAccuracyMeasurement> _accuracyMeasurements =
      <LocationAccuracyMeasurement>[];
  final List<BatteryUsageMeasurement> _batteryMeasurements =
      <BatteryUsageMeasurement>[];
  static const int _maxMeasurementHistory = 100;

  /// Stream of adaptive location updates
  Stream<AdaptiveLocationUpdate> get updateStream {
    _updateController ??= StreamController<AdaptiveLocationUpdate>.broadcast();
    return _updateController!.stream;
  }

  /// Stream of tracking parameter changes
  Stream<LocationTrackingParameters> get parametersStream {
    _parametersController ??=
        StreamController<LocationTrackingParameters>.broadcast();
    return _parametersController!.stream;
  }

  /// Current adaptive tracking mode
  AdaptiveTrackingMode get mode => _mode;

  /// Whether the service is active
  bool get isActive => _isActive;

  /// Current tracking parameters
  LocationTrackingParameters get currentParameters => _currentParameters;

  /// Current movement pattern
  MovementPattern get currentMovementPattern => _currentMovementPattern;

  /// Current activity level
  ActivityLevel get currentActivityLevel => _currentActivityLevel;

  /// Start adaptive location tracking
  Future<void> start({
    AdaptiveTrackingMode mode = AdaptiveTrackingMode.balanced,
    SensorFusionService? sensorFusionService,
    LocationTrackingParameters? initialParameters,
  }) async {
    try {
      await stop(); // Ensure clean start

      _mode = mode;
      _sensorFusionService = sensorFusionService;
      _currentParameters =
          initialParameters ?? _getDefaultParametersForMode(mode);

      debugPrint('🎯 Starting adaptive location service...');
      debugPrint('  Mode: ${mode.name}');
      debugPrint('  Initial parameters: $_currentParameters');

      // Initialize stream controllers
      _updateController ??=
          StreamController<AdaptiveLocationUpdate>.broadcast();
      _parametersController ??=
          StreamController<LocationTrackingParameters>.broadcast();

      // Start GPS accuracy monitoring
      await _gpsAccuracyService.start(
        sensorFusionService: _sensorFusionService,
      );

      // Start location monitoring
      await _startLocationMonitoring();

      // Subscribe to GPS quality updates
      _subscribeToGpsQuality();

      // Subscribe to sensor updates if available
      if (_sensorFusionService != null) {
        _subscribeToSensorUpdates();
      }

      // Start adaptation timer
      _startAdaptationTimer();

      _isActive = true;
      debugPrint('🎯 Adaptive location service started successfully');
    } catch (e) {
      debugPrint('🎯 Error starting adaptive location service: $e');
      rethrow;
    }
  }

  /// Stop adaptive location tracking
  Future<void> stop() async {
    // Cancel subscriptions
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    await _gpsQualitySubscription?.cancel();
    _gpsQualitySubscription = null;

    await _sensorSubscription?.cancel();
    _sensorSubscription = null;

    // Stop timers
    _adaptationTimer?.cancel();
    _adaptationTimer = null;

    // Stop GPS accuracy service
    await _gpsAccuracyService.stop();

    // Close stream controllers
    await _updateController?.close();
    _updateController = null;

    await _parametersController?.close();
    _parametersController = null;

    _isActive = false;
    debugPrint('🎯 Adaptive location service stopped');
  }

  /// Change adaptive tracking mode
  Future<void> setMode(AdaptiveTrackingMode newMode) async {
    if (newMode == _mode) return;

    debugPrint(
        '🎯 Changing adaptive tracking mode: ${_mode.name} → ${newMode.name}');

    final wasActive = _isActive;
    if (wasActive) {
      await stop();
    }

    _mode = newMode;

    if (wasActive) {
      await start(mode: newMode, sensorFusionService: _sensorFusionService);
    }
  }

  /// Manually trigger parameter adaptation
  Future<void> triggerAdaptation() async {
    if (!_isActive) return;

    await _performAdaptation();
  }

  /// Get current tracking performance metrics
  AdaptiveTrackingMetrics getTrackingMetrics() {
    final accuracyStats = _calculateAccuracyStatistics();
    final batteryStats = _calculateBatteryStatistics();
    final adaptationStats = _calculateAdaptationStatistics();

    return AdaptiveTrackingMetrics(
      accuracyStatistics: accuracyStats,
      batteryStatistics: batteryStats,
      adaptationStatistics: adaptationStats,
      currentParameters: _currentParameters,
      movementPattern: _currentMovementPattern,
      activityLevel: _currentActivityLevel,
      timestamp: DateTime.now(),
    );
  }

  Future<void> _startLocationMonitoring() async {
    _locationSubscription = _locationService
        .getEnhancedLocationStream(
      intervalSeconds: _currentParameters.updateIntervalSeconds,
      minimumDistanceMeters: _currentParameters.minimumDistanceMeters,
      accuracy: _currentParameters.accuracy,
    )
        .listen(
      _handleLocationUpdate,
      onError: (Object error) {
        debugPrint('🎯 Adaptive location stream error: $error');
      },
    );
  }

  void _subscribeToGpsQuality() {
    _gpsQualitySubscription = _gpsAccuracyService.qualityStream.listen(
      _handleGpsQualityUpdate,
      onError: (Object error) {
        debugPrint('🎯 GPS quality stream error: $error');
      },
    );
  }

  void _subscribeToSensorUpdates() {
    if (_sensorFusionService == null) return;

    _sensorSubscription = _sensorFusionService!.fusionStream.listen(
      _handleSensorUpdate,
      onError: (Object error) {
        debugPrint('🎯 Sensor fusion stream error: $error');
      },
    );
  }

  void _startAdaptationTimer() {
    _adaptationTimer = Timer.periodic(_adaptationInterval, (_) {
      _performAdaptation();
    });
  }

  void _handleLocationUpdate(EnhancedLocationData locationData) {
    final position = locationData.position;
    final now = DateTime.now();

    // Create movement sample
    final movementSample = MovementSample(
      position: position,
      speed: locationData.bestSpeed ?? 0.0,
      accuracy: position.accuracy,
      timestamp: now,
    );

    // Update movement history
    _movementHistory.add(movementSample);
    if (_movementHistory.length > _maxMovementHistoryLength) {
      _movementHistory.removeAt(0);
    }

    // Analyze movement pattern
    _analyzeMovementPattern();

    // Record accuracy measurement
    _recordAccuracyMeasurement(position.accuracy, now);

    // Create adaptive location update
    final adaptiveUpdate = AdaptiveLocationUpdate(
      locationData: locationData,
      movementPattern: _currentMovementPattern,
      activityLevel: _currentActivityLevel,
      trackingParameters: _currentParameters,
      adaptationReason: _getLastAdaptationReason(),
      timestamp: now,
    );

    // Emit update
    _updateController?.add(adaptiveUpdate);
  }

  void _handleGpsQualityUpdate(GpsQualityReading qualityReading) {
    // Use GPS quality information for adaptation decisions
    // This will be considered in the next adaptation cycle
  }

  void _handleSensorUpdate(SensorFusionReading sensorReading) {
    // Use sensor data to enhance movement pattern detection
    if (sensorReading.accelerometer != null) {
      final activityType = sensorReading.currentActivity;

      // Update activity level based on sensor data
      if (activityType != null) {
        _currentActivityLevel = _mapActivityTypeToLevel(activityType);
      }
    }
  }

  void _analyzeMovementPattern() {
    if (_movementHistory.length < 3) {
      _currentMovementPattern = MovementPattern.unknown;
      return;
    }

    final recentSamples = _movementHistory.take(10).toList();
    final speeds = recentSamples.map((s) => s.speed).toList();
    final accuracies = recentSamples.map((s) => s.accuracy).toList();

    // Calculate movement statistics
    final avgSpeed = speeds.reduce((a, b) => a + b) / speeds.length;
    final speedVariance = _calculateVariance(speeds);
    final avgAccuracy = accuracies.reduce((a, b) => a + b) / accuracies.length;

    // Determine movement pattern
    if (avgSpeed < 0.5) {
      _currentMovementPattern = MovementPattern.stationary;
      _currentActivityLevel = ActivityLevel.stationary;
    } else if (avgSpeed < 2.0 && speedVariance < 1.0) {
      _currentMovementPattern = MovementPattern.walking;
      _currentActivityLevel = ActivityLevel.walking;
    } else if (avgSpeed < 5.0 && speedVariance < 4.0) {
      _currentMovementPattern = MovementPattern.jogging;
      _currentActivityLevel = ActivityLevel.jogging;
    } else if (avgSpeed < 15.0) {
      _currentMovementPattern = MovementPattern.cycling;
      _currentActivityLevel = ActivityLevel.cycling;
    } else if (avgSpeed < 50.0) {
      _currentMovementPattern = MovementPattern.driving;
      _currentActivityLevel = ActivityLevel.driving;
    } else {
      _currentMovementPattern = MovementPattern.highSpeed;
      _currentActivityLevel = ActivityLevel.highSpeed;
    }

    // Consider accuracy for pattern refinement
    if (avgAccuracy > 20.0) {
      // Poor accuracy might indicate challenging environment
      if (_currentMovementPattern == MovementPattern.stationary) {
        _currentMovementPattern = MovementPattern.indoor;
      }
    }
  }

  Future<void> _performAdaptation() async {
    final now = DateTime.now();

    // Skip if too soon since last adaptation
    if (now.difference(_lastAdaptation) < _adaptationInterval) {
      return;
    }

    debugPrint('🎯 Performing adaptive parameter adjustment...');

    final oldParameters = _currentParameters;
    final newParameters = _calculateOptimalParameters();

    if (_shouldUpdateParameters(oldParameters, newParameters)) {
      _currentParameters = newParameters;
      _lastAdaptation = now;

      debugPrint('🎯 Parameters updated: $oldParameters → $newParameters');

      // Restart location monitoring with new parameters
      await _locationSubscription?.cancel();
      await _startLocationMonitoring();

      // Emit parameter change
      _parametersController?.add(_currentParameters);

      // Record battery usage measurement
      _recordBatteryMeasurement(now);
    }
  }

  LocationTrackingParameters _calculateOptimalParameters() {
    // Base parameters on current mode
    var parameters = _getDefaultParametersForMode(_mode);

    // Adjust based on movement pattern
    parameters = _adjustForMovementPattern(parameters);

    // Adjust based on GPS quality
    parameters = _adjustForGpsQuality(parameters);

    // Adjust based on environmental conditions
    parameters = _adjustForEnvironmentalConditions(parameters);

    // Apply battery optimization
    parameters = _applyBatteryOptimization(parameters);

    return parameters;
  }

  LocationTrackingParameters _adjustForMovementPattern(
      LocationTrackingParameters params) {
    switch (_currentMovementPattern) {
      case MovementPattern.stationary:
        // Reduce frequency for stationary users
        return params.copyWith(
          updateIntervalSeconds: math.max(params.updateIntervalSeconds * 2, 60),
          minimumDistanceMeters: math.max(params.minimumDistanceMeters, 10.0),
        );

      case MovementPattern.walking:
        // Standard parameters for walking
        return params.copyWith(
          updateIntervalSeconds: 15,
          minimumDistanceMeters: 5.0,
        );

      case MovementPattern.jogging:
        // Higher frequency for jogging
        return params.copyWith(
          updateIntervalSeconds: 10,
          minimumDistanceMeters: 3.0,
        );

      case MovementPattern.cycling:
        // Balanced parameters for cycling
        return params.copyWith(
          updateIntervalSeconds: 8,
          minimumDistanceMeters: 5.0,
        );

      case MovementPattern.driving:
        // Higher frequency for driving
        return params.copyWith(
          updateIntervalSeconds: 5,
          minimumDistanceMeters: 10.0,
        );

      case MovementPattern.highSpeed:
        // Maximum frequency for high speed
        return params.copyWith(
          updateIntervalSeconds: 3,
          minimumDistanceMeters: 15.0,
        );

      case MovementPattern.indoor:
        // Reduced frequency for indoor
        return params.copyWith(
          updateIntervalSeconds:
              math.max(params.updateIntervalSeconds * 3, 120),
          minimumDistanceMeters: 0.0, // Capture any movement indoors
          accuracy: LocationAccuracy.medium, // Reduce accuracy requirement
        );

      case MovementPattern.unknown:
        // Use default parameters
        return params;
    }
  }

  LocationTrackingParameters _adjustForGpsQuality(
      LocationTrackingParameters params) {
    final gpsQuality = _gpsAccuracyService.currentSignalQuality;

    switch (gpsQuality) {
      case GpsSignalQuality.excellent:
        // Can use longer intervals with excellent signal
        return params.copyWith(
          updateIntervalSeconds: math.max(params.updateIntervalSeconds, 10),
        );

      case GpsSignalQuality.good:
        // Standard parameters
        return params;

      case GpsSignalQuality.fair:
        // Slightly more frequent updates
        return params.copyWith(
          updateIntervalSeconds: math.max(params.updateIntervalSeconds - 2, 5),
        );

      case GpsSignalQuality.poor:
        // More frequent updates to compensate
        return params.copyWith(
          updateIntervalSeconds: math.max(params.updateIntervalSeconds - 5, 3),
          minimumDistanceMeters:
              math.max(params.minimumDistanceMeters - 2.0, 0.0),
        );

      case GpsSignalQuality.unavailable:
        // Maximum frequency to try to get any signal
        return params.copyWith(
          updateIntervalSeconds: 2,
          minimumDistanceMeters: 0.0,
          accuracy: LocationAccuracy.medium,
        );
    }
  }

  LocationTrackingParameters _adjustForEnvironmentalConditions(
      LocationTrackingParameters params) {
    final environment = _gpsAccuracyService.currentEnvironment;

    switch (environment) {
      case EnvironmentalCondition.openArea:
        // Can use longer intervals in open areas
        return params.copyWith(
          updateIntervalSeconds: math.max(params.updateIntervalSeconds, 15),
        );

      case EnvironmentalCondition.urban:
      case EnvironmentalCondition.suburban:
        // Standard parameters
        return params;

      case EnvironmentalCondition.urbanCanyon:
      case EnvironmentalCondition.denseForest:
        // More frequent updates in challenging environments
        return params.copyWith(
          updateIntervalSeconds: math.max(params.updateIntervalSeconds - 3, 5),
          minimumDistanceMeters:
              math.max(params.minimumDistanceMeters - 2.0, 0.0),
        );

      case EnvironmentalCondition.mountainous:
        // Balanced approach for mountainous terrain
        return params.copyWith(
          updateIntervalSeconds: math.max(params.updateIntervalSeconds - 2, 8),
        );

      case EnvironmentalCondition.indoor:
      case EnvironmentalCondition.underground:
        // Minimal updates for indoor/underground
        return params.copyWith(
          updateIntervalSeconds:
              math.max(params.updateIntervalSeconds * 4, 180),
          minimumDistanceMeters: 0.0,
          accuracy: LocationAccuracy.low,
        );

      case EnvironmentalCondition.unknown:
        // Use default parameters
        return params;
    }
  }

  LocationTrackingParameters _applyBatteryOptimization(
      LocationTrackingParameters params) {
    // Apply battery optimization based on mode
    switch (_mode) {
      case AdaptiveTrackingMode.batteryOptimized:
        return params.copyWith(
          updateIntervalSeconds: math.max(params.updateIntervalSeconds * 2, 30),
          accuracy: LocationAccuracy.medium,
        );

      case AdaptiveTrackingMode.balanced:
        // No additional optimization
        return params;

      case AdaptiveTrackingMode.highAccuracy:
        // Prioritize accuracy over battery
        return params.copyWith(
          updateIntervalSeconds: math.max(params.updateIntervalSeconds - 2, 3),
          accuracy: LocationAccuracy.high,
        );

      case AdaptiveTrackingMode.realTime:
        // Maximum frequency
        return params.copyWith(
          updateIntervalSeconds: 2,
          minimumDistanceMeters: 0.0,
          accuracy: LocationAccuracy.high,
        );
    }
  }

  bool _shouldUpdateParameters(
    LocationTrackingParameters oldParams,
    LocationTrackingParameters newParams,
  ) {
    // Only update if there's a significant change
    final intervalDiff =
        (newParams.updateIntervalSeconds - oldParams.updateIntervalSeconds)
            .abs();
    final distanceDiff =
        (newParams.minimumDistanceMeters - oldParams.minimumDistanceMeters)
            .abs();

    return intervalDiff >= 3 ||
        distanceDiff >= 2.0 ||
        newParams.accuracy != oldParams.accuracy;
  }

  LocationTrackingParameters _getDefaultParametersForMode(
      AdaptiveTrackingMode mode) {
    switch (mode) {
      case AdaptiveTrackingMode.batteryOptimized:
        return const LocationTrackingParameters(
          updateIntervalSeconds: 30,
          minimumDistanceMeters: 10.0,
          accuracy: LocationAccuracy.medium,
        );

      case AdaptiveTrackingMode.balanced:
        return const LocationTrackingParameters(
          updateIntervalSeconds: 15,
          minimumDistanceMeters: 5.0,
          accuracy: LocationAccuracy.high,
        );

      case AdaptiveTrackingMode.highAccuracy:
        return const LocationTrackingParameters(
          updateIntervalSeconds: 8,
          minimumDistanceMeters: 3.0,
          accuracy: LocationAccuracy.high,
        );

      case AdaptiveTrackingMode.realTime:
        return const LocationTrackingParameters(
          updateIntervalSeconds: 3,
          minimumDistanceMeters: 0.0,
          accuracy: LocationAccuracy.high,
        );
    }
  }

  ActivityLevel _mapActivityTypeToLevel(
      accelerometer.ActivityType activityType) {
    switch (activityType) {
      case accelerometer.ActivityType.stationary:
        return ActivityLevel.stationary;
      case accelerometer.ActivityType.walking:
        return ActivityLevel.walking;
      case accelerometer.ActivityType.running:
        return ActivityLevel.jogging;
      case accelerometer.ActivityType.unknown:
        return ActivityLevel.unknown;
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

  void _recordAccuracyMeasurement(double accuracy, DateTime timestamp) {
    final measurement = LocationAccuracyMeasurement(
      accuracy: accuracy,
      parameters: _currentParameters,
      movementPattern: _currentMovementPattern,
      timestamp: timestamp,
    );

    _accuracyMeasurements.add(measurement);
    if (_accuracyMeasurements.length > _maxMeasurementHistory) {
      _accuracyMeasurements.removeAt(0);
    }
  }

  void _recordBatteryMeasurement(DateTime timestamp) {
    final measurement = BatteryUsageMeasurement(
      parameters: _currentParameters,
      movementPattern: _currentMovementPattern,
      estimatedBatteryImpact: _estimateBatteryImpact(_currentParameters),
      timestamp: timestamp,
    );

    _batteryMeasurements.add(measurement);
    if (_batteryMeasurements.length > _maxMeasurementHistory) {
      _batteryMeasurements.removeAt(0);
    }
  }

  double _estimateBatteryImpact(LocationTrackingParameters parameters) {
    // Estimate battery impact based on parameters (0-100 scale)
    double impact = 0.0;

    // Update interval impact (more frequent = higher impact)
    impact += math.max(0, 60 - parameters.updateIntervalSeconds) * 0.5;

    // Accuracy impact
    switch (parameters.accuracy) {
      case LocationAccuracy.high:
        impact += 20;
        break;
      case LocationAccuracy.medium:
        impact += 10;
        break;
      case LocationAccuracy.low:
        impact += 5;
        break;
      default:
        break;
    }

    // Distance filter impact (lower = higher impact)
    impact += math.max(0, 10 - parameters.minimumDistanceMeters) * 2;

    return math.min(impact, 100.0);
  }

  AccuracyStatistics _calculateAccuracyStatistics() {
    if (_accuracyMeasurements.isEmpty) {
      return AccuracyStatistics.empty();
    }

    final accuracies = _accuracyMeasurements.map((m) => m.accuracy).toList();
    final mean = accuracies.reduce((a, b) => a + b) / accuracies.length;
    final sortedAccuracies = List<double>.from(accuracies)..sort();
    final median = sortedAccuracies[sortedAccuracies.length ~/ 2];

    return AccuracyStatistics(
      sampleCount: accuracies.length,
      meanAccuracy: mean,
      medianAccuracy: median,
      minAccuracy: sortedAccuracies.first,
      maxAccuracy: sortedAccuracies.last,
    );
  }

  BatteryStatistics _calculateBatteryStatistics() {
    if (_batteryMeasurements.isEmpty) {
      return BatteryStatistics.empty();
    }

    final impacts =
        _batteryMeasurements.map((m) => m.estimatedBatteryImpact).toList();
    final mean = impacts.reduce((a, b) => a + b) / impacts.length;

    return BatteryStatistics(
      sampleCount: impacts.length,
      averageBatteryImpact: mean,
      totalEstimatedUsage: impacts.reduce((a, b) => a + b),
    );
  }

  AdaptationStatistics _calculateAdaptationStatistics() => AdaptationStatistics(
        totalAdaptations: _batteryMeasurements.length,
        lastAdaptationTime: _lastAdaptation,
        averageAdaptationInterval: _adaptationInterval,
      );

  String _getLastAdaptationReason() =>
      // This would track the reason for the last adaptation
      // For now, return a generic reason
      'Movement pattern: ${_currentMovementPattern.name}';

  /// Dispose of the service and clean up resources
  void dispose() {
    stop();
    _gpsAccuracyService.dispose();
    _instance = null;
  }
}

/// Adaptive tracking modes
enum AdaptiveTrackingMode {
  batteryOptimized,
  balanced,
  highAccuracy,
  realTime;

  String get description {
    switch (this) {
      case AdaptiveTrackingMode.batteryOptimized:
        return 'Battery Optimized (Longer intervals, lower accuracy)';
      case AdaptiveTrackingMode.balanced:
        return 'Balanced (Optimal balance of accuracy and battery)';
      case AdaptiveTrackingMode.highAccuracy:
        return 'High Accuracy (Shorter intervals, high accuracy)';
      case AdaptiveTrackingMode.realTime:
        return 'Real-time (Maximum frequency and accuracy)';
    }
  }
}
