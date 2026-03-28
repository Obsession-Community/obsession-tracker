import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/gps_accuracy_models.dart';
import 'package:obsession_tracker/core/services/location_service.dart';
import 'package:obsession_tracker/core/services/sensor_fusion_service.dart';

/// Comprehensive GPS accuracy monitoring and quality assessment service
///
/// Provides real-time GPS signal quality monitoring, accuracy assessment,
/// drift detection, and environmental condition analysis for optimal
/// location tracking performance.
class GpsAccuracyService {
  factory GpsAccuracyService() => _instance ??= GpsAccuracyService._();
  GpsAccuracyService._();
  static GpsAccuracyService? _instance;

  final LocationService _locationService = LocationService();
  SensorFusionService? _sensorFusionService;

  // Stream controllers
  StreamController<GpsQualityReading>? _qualityController;
  StreamController<GpsAccuracyAlert>? _alertController;
  StreamController<EnvironmentalCondition>? _environmentController;

  // Service state
  bool _isActive = false;
  GpsAccuracyMode _mode = GpsAccuracyMode.balanced;

  // Location tracking
  StreamSubscription<EnhancedLocationData>? _locationSubscription;
  StreamSubscription<SensorFusionReading>? _sensorSubscription;

  // GPS quality tracking
  final List<GpsQualityReading> _qualityHistory = <GpsQualityReading>[];
  static const int _maxQualityHistoryLength = 100;

  // Accuracy statistics
  final List<double> _accuracyHistory = <double>[];
  final List<double> _speedHistory = <double>[];
  final List<Position> _positionHistory = <Position>[];
  static const int _maxHistoryLength = 50;

  // Drift detection
  Position? _lastStablePosition;
  double _driftDistance = 0.0;
  int _consecutiveStableReadings = 0;
  static const int _stableReadingsThreshold = 5;
  static const double _stationarySpeedThreshold = 0.5; // m/s
  static const double _maxDriftThreshold = 20.0; // meters

  // Environmental condition detection
  EnvironmentalCondition _currentEnvironment = EnvironmentalCondition.unknown;
  Timer? _environmentCheckTimer;

  // Signal strength monitoring
  double _averageSignalStrength = 0.0;
  final List<double> _signalStrengthHistory = <double>[];

  /// Stream of GPS quality readings
  Stream<GpsQualityReading> get qualityStream {
    _qualityController ??= StreamController<GpsQualityReading>.broadcast();
    return _qualityController!.stream;
  }

  /// Stream of GPS accuracy alerts
  Stream<GpsAccuracyAlert> get alertStream {
    _alertController ??= StreamController<GpsAccuracyAlert>.broadcast();
    return _alertController!.stream;
  }

  /// Stream of environmental condition updates
  Stream<EnvironmentalCondition> get environmentStream {
    _environmentController ??=
        StreamController<EnvironmentalCondition>.broadcast();
    return _environmentController!.stream;
  }

  /// Current GPS accuracy mode
  GpsAccuracyMode get mode => _mode;

  /// Whether the service is active
  bool get isActive => _isActive;

  /// Current environmental condition
  EnvironmentalCondition get currentEnvironment => _currentEnvironment;

  /// Current average accuracy in meters
  double get currentAverageAccuracy {
    if (_accuracyHistory.isEmpty) return 0.0;
    return _accuracyHistory.reduce((a, b) => a + b) / _accuracyHistory.length;
  }

  /// Current GPS signal quality
  GpsSignalQuality get currentSignalQuality {
    final accuracy = currentAverageAccuracy;
    if (accuracy <= 3.0) return GpsSignalQuality.excellent;
    if (accuracy <= 5.0) return GpsSignalQuality.good;
    if (accuracy <= 10.0) return GpsSignalQuality.fair;
    if (accuracy <= 20.0) return GpsSignalQuality.poor;
    return GpsSignalQuality.unavailable;
  }

  /// Start GPS accuracy monitoring
  Future<void> start({
    GpsAccuracyMode mode = GpsAccuracyMode.balanced,
    SensorFusionService? sensorFusionService,
  }) async {
    try {
      await stop(); // Ensure clean start

      _mode = mode;
      _sensorFusionService = sensorFusionService;

      debugPrint('🎯 Starting GPS accuracy service...');
      debugPrint('  Mode: ${mode.name}');

      // Initialize stream controllers
      _qualityController ??= StreamController<GpsQualityReading>.broadcast();
      _alertController ??= StreamController<GpsAccuracyAlert>.broadcast();
      _environmentController ??=
          StreamController<EnvironmentalCondition>.broadcast();

      // Start location monitoring
      await _startLocationMonitoring();

      // Start sensor monitoring if available
      if (_sensorFusionService != null) {
        _startSensorMonitoring();
      }

      // Start environmental monitoring
      _startEnvironmentalMonitoring();

      _isActive = true;
      debugPrint('🎯 GPS accuracy service started successfully');
    } catch (e) {
      debugPrint('🎯 Error starting GPS accuracy service: $e');
      rethrow;
    }
  }

  /// Stop GPS accuracy monitoring
  Future<void> stop() async {
    // Cancel subscriptions
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    await _sensorSubscription?.cancel();
    _sensorSubscription = null;

    // Stop timers
    _environmentCheckTimer?.cancel();
    _environmentCheckTimer = null;

    // Close stream controllers
    await _qualityController?.close();
    _qualityController = null;

    await _alertController?.close();
    _alertController = null;

    await _environmentController?.close();
    _environmentController = null;

    _isActive = false;
    debugPrint('🎯 GPS accuracy service stopped');
  }

  /// Change GPS accuracy monitoring mode
  Future<void> setMode(GpsAccuracyMode newMode) async {
    if (newMode == _mode) return;

    debugPrint(
        '🎯 Changing GPS accuracy mode: ${_mode.name} → ${newMode.name}');

    final wasActive = _isActive;
    if (wasActive) {
      await stop();
    }

    _mode = newMode;

    if (wasActive) {
      await start(mode: newMode, sensorFusionService: _sensorFusionService);
    }
  }

  /// Get current GPS quality assessment
  GpsQualityAssessment getCurrentQualityAssessment() {
    final accuracy = currentAverageAccuracy;
    final signalQuality = currentSignalQuality;
    final driftLevel = _getDriftLevel();
    final environmentalImpact = _getEnvironmentalImpact();

    return GpsQualityAssessment(
      overallQuality: _calculateOverallQuality(
          signalQuality, driftLevel, environmentalImpact),
      signalQuality: signalQuality,
      averageAccuracy: accuracy,
      driftDistance: _driftDistance,
      driftLevel: driftLevel,
      environmentalCondition: _currentEnvironment,
      environmentalImpact: environmentalImpact,
      recommendedActions: _getRecommendedActions(
          signalQuality, driftLevel, environmentalImpact),
      timestamp: DateTime.now(),
    );
  }

  /// Get GPS accuracy statistics
  GpsAccuracyStatistics getAccuracyStatistics() {
    if (_accuracyHistory.isEmpty) {
      return GpsAccuracyStatistics.empty();
    }

    final sortedAccuracy = List<double>.from(_accuracyHistory)..sort();
    final mean =
        _accuracyHistory.reduce((a, b) => a + b) / _accuracyHistory.length;
    final median = sortedAccuracy[sortedAccuracy.length ~/ 2];
    final min = sortedAccuracy.first;
    final max = sortedAccuracy.last;

    // Calculate standard deviation
    final variance = _accuracyHistory
            .map((x) => math.pow(x - mean, 2))
            .reduce((a, b) => a + b) /
        _accuracyHistory.length;
    final standardDeviation = math.sqrt(variance);

    return GpsAccuracyStatistics(
      sampleCount: _accuracyHistory.length,
      meanAccuracy: mean,
      medianAccuracy: median,
      minAccuracy: min,
      maxAccuracy: max,
      standardDeviation: standardDeviation,
      qualityDistribution: _calculateQualityDistribution(),
      timestamp: DateTime.now(),
    );
  }

  Future<void> _startLocationMonitoring() async {
    final updateInterval = _getUpdateIntervalForMode(_mode);

    _locationSubscription = _locationService
        .getEnhancedLocationStream(
      intervalSeconds: updateInterval,
    )
        .listen(
      _handleLocationUpdate,
      onError: (Object error) {
        debugPrint('🎯 Location stream error: $error');
        _emitAlert(GpsAccuracyAlert(
          type: GpsAlertType.locationServiceError,
          severity: AlertSeverity.high,
          message: 'GPS location service error: $error',
          timestamp: DateTime.now(),
        ));
      },
    );
  }

  void _startSensorMonitoring() {
    if (_sensorFusionService == null) return;

    _sensorSubscription = _sensorFusionService!.fusionStream.listen(
      _handleSensorUpdate,
      onError: (Object error) {
        debugPrint('🎯 Sensor fusion error: $error');
      },
    );
  }

  void _startEnvironmentalMonitoring() {
    _environmentCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkEnvironmentalConditions(),
    );
  }

  void _handleLocationUpdate(EnhancedLocationData locationData) {
    final position = locationData.position;

    // Update position history
    _positionHistory.add(position);
    if (_positionHistory.length > _maxHistoryLength) {
      _positionHistory.removeAt(0);
    }

    // Update accuracy history
    _accuracyHistory.add(position.accuracy);
    if (_accuracyHistory.length > _maxHistoryLength) {
      _accuracyHistory.removeAt(0);
    }

    // Update speed history
    final speed = locationData.bestSpeed ?? 0.0;
    _speedHistory.add(speed);
    if (_speedHistory.length > _maxHistoryLength) {
      _speedHistory.removeAt(0);
    }

    // Perform drift detection
    _performDriftDetection(position, speed);

    // Calculate signal strength estimate
    _updateSignalStrengthEstimate(position);

    // Generate quality reading
    final qualityReading = _generateQualityReading(locationData);
    _qualityHistory.add(qualityReading);
    if (_qualityHistory.length > _maxQualityHistoryLength) {
      _qualityHistory.removeAt(0);
    }

    // Emit quality reading
    _qualityController?.add(qualityReading);

    // Check for alerts
    _checkForAlerts(qualityReading);
  }

  void _handleSensorUpdate(SensorFusionReading sensorReading) {
    // Use sensor data to enhance environmental condition detection
    // This will be used in environmental condition analysis
  }

  void _performDriftDetection(Position position, double speed) {
    final now = DateTime.now();

    // Check if device is stationary
    if (speed <= _stationarySpeedThreshold) {
      if (_lastStablePosition == null) {
        _lastStablePosition = position;
        _consecutiveStableReadings = 1;
      } else {
        _consecutiveStableReadings++;

        // Calculate drift from stable position
        final driftDistance = Geolocator.distanceBetween(
          _lastStablePosition!.latitude,
          _lastStablePosition!.longitude,
          position.latitude,
          position.longitude,
        );

        _driftDistance = driftDistance;

        // Check for excessive drift
        if (driftDistance > _maxDriftThreshold &&
            _consecutiveStableReadings >= _stableReadingsThreshold) {
          _emitAlert(GpsAccuracyAlert(
            type: GpsAlertType.excessiveDrift,
            severity: AlertSeverity.medium,
            message:
                'GPS drift detected: ${driftDistance.toStringAsFixed(1)}m while stationary',
            data: {'drift_distance': driftDistance},
            timestamp: now,
          ));
        }
      }
    } else {
      // Device is moving, reset stable position tracking
      _lastStablePosition = null;
      _consecutiveStableReadings = 0;
      _driftDistance = 0.0;
    }
  }

  void _updateSignalStrengthEstimate(Position position) {
    // Estimate signal strength based on accuracy and other factors
    // Better accuracy generally indicates stronger signal
    final signalStrength =
        _calculateSignalStrengthFromAccuracy(position.accuracy);

    _signalStrengthHistory.add(signalStrength);
    if (_signalStrengthHistory.length > _maxHistoryLength) {
      _signalStrengthHistory.removeAt(0);
    }

    _averageSignalStrength = _signalStrengthHistory.isNotEmpty
        ? _signalStrengthHistory.reduce((a, b) => a + b) /
            _signalStrengthHistory.length
        : 0.0;
  }

  double _calculateSignalStrengthFromAccuracy(double accuracy) {
    // Convert accuracy to signal strength estimate (0-100)
    // Better accuracy = higher signal strength
    if (accuracy <= 3.0) return 90.0 + (10.0 * (3.0 - accuracy) / 3.0);
    if (accuracy <= 5.0) return 80.0 + (10.0 * (5.0 - accuracy) / 2.0);
    if (accuracy <= 10.0) return 60.0 + (20.0 * (10.0 - accuracy) / 5.0);
    if (accuracy <= 20.0) return 30.0 + (30.0 * (20.0 - accuracy) / 10.0);
    return math.max(0.0, 30.0 - accuracy);
  }

  GpsQualityReading _generateQualityReading(EnhancedLocationData locationData) {
    final position = locationData.position;

    return GpsQualityReading(
      position: position,
      signalQuality: currentSignalQuality,
      signalStrength: _averageSignalStrength,
      accuracy: position.accuracy,
      speed: locationData.bestSpeed ?? 0.0,
      altitude: locationData.bestAltitude,
      heading: locationData.bestHeading,
      satelliteCount: _estimateSatelliteCount(position.accuracy),
      driftDistance: _driftDistance,
      environmentalCondition: _currentEnvironment,
      timestamp: DateTime.now(),
    );
  }

  int _estimateSatelliteCount(double accuracy) {
    // Estimate satellite count based on accuracy
    // This is an approximation since actual satellite count isn't available
    if (accuracy <= 3.0) return 12 + (accuracy * 2).round();
    if (accuracy <= 5.0) return 8 + (accuracy * 1.5).round();
    if (accuracy <= 10.0) return 6 + (accuracy * 0.5).round();
    return math.max(4, 10 - accuracy.round());
  }

  void _checkEnvironmentalConditions() {
    final newCondition = _detectEnvironmentalCondition();

    if (newCondition != _currentEnvironment) {
      _currentEnvironment = newCondition;
      _environmentController?.add(newCondition);

      debugPrint('🎯 Environmental condition changed: ${newCondition.name}');

      // Emit alert for challenging conditions
      if (_isChallengingEnvironment(newCondition)) {
        _emitAlert(GpsAccuracyAlert(
          type: GpsAlertType.challengingEnvironment,
          severity: AlertSeverity.low,
          message:
              'GPS accuracy may be affected by ${newCondition.description}',
          data: {'environment': newCondition.name},
          timestamp: DateTime.now(),
        ));
      }
    }
  }

  EnvironmentalCondition _detectEnvironmentalCondition() {
    // Analyze GPS accuracy patterns and sensor data to detect environment
    final recentAccuracy = _accuracyHistory.isNotEmpty
        ? _accuracyHistory.take(10).toList()
        : <double>[];

    if (recentAccuracy.isEmpty) return EnvironmentalCondition.unknown;

    final avgAccuracy =
        recentAccuracy.reduce((a, b) => a + b) / recentAccuracy.length;
    final accuracyVariance = _calculateVariance(recentAccuracy);

    // Urban canyon detection (high variance, poor accuracy)
    if (avgAccuracy > 15.0 && accuracyVariance > 50.0) {
      return EnvironmentalCondition.urbanCanyon;
    }

    // Dense forest detection (consistently poor accuracy)
    if (avgAccuracy > 20.0 && accuracyVariance < 20.0) {
      return EnvironmentalCondition.denseForest;
    }

    // Indoor detection (very poor accuracy, low signal strength)
    if (avgAccuracy > 30.0 && _averageSignalStrength < 30.0) {
      return EnvironmentalCondition.indoor;
    }

    // Mountain/valley detection (moderate accuracy, high variance)
    if (avgAccuracy > 10.0 && avgAccuracy < 20.0 && accuracyVariance > 30.0) {
      return EnvironmentalCondition.mountainous;
    }

    // Open area (good accuracy, low variance)
    if (avgAccuracy <= 5.0 && accuracyVariance < 10.0) {
      return EnvironmentalCondition.openArea;
    }

    // Default to urban
    return EnvironmentalCondition.urban;
  }

  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) /
            values.length;

    return variance;
  }

  void _checkForAlerts(GpsQualityReading reading) {
    // Check for poor accuracy
    if (reading.accuracy > 20.0) {
      _emitAlert(GpsAccuracyAlert(
        type: GpsAlertType.poorAccuracy,
        severity: AlertSeverity.medium,
        message:
            'GPS accuracy is poor (±${reading.accuracy.toStringAsFixed(1)}m)',
        data: {'accuracy': reading.accuracy},
        timestamp: reading.timestamp,
      ));
    }

    // Check for low signal strength
    if (reading.signalStrength < 30.0) {
      _emitAlert(GpsAccuracyAlert(
        type: GpsAlertType.weakSignal,
        severity: AlertSeverity.low,
        message:
            'GPS signal strength is weak (${reading.signalStrength.toStringAsFixed(0)}%)',
        data: {'signal_strength': reading.signalStrength},
        timestamp: reading.timestamp,
      ));
    }
  }

  void _emitAlert(GpsAccuracyAlert alert) {
    _alertController?.add(alert);
    debugPrint('🎯 GPS Alert: ${alert.message}');
  }

  GpsOverallQuality _calculateOverallQuality(
    GpsSignalQuality signalQuality,
    GpsDriftLevel driftLevel,
    EnvironmentalImpact environmentalImpact,
  ) {
    // Calculate weighted score
    int score = 0;

    // Signal quality weight: 40%
    switch (signalQuality) {
      case GpsSignalQuality.excellent:
        score += 40;
        break;
      case GpsSignalQuality.good:
        score += 32;
        break;
      case GpsSignalQuality.fair:
        score += 24;
        break;
      case GpsSignalQuality.poor:
        score += 16;
        break;
      case GpsSignalQuality.unavailable:
        score += 0;
        break;
    }

    // Drift level weight: 30%
    switch (driftLevel) {
      case GpsDriftLevel.minimal:
        score += 30;
        break;
      case GpsDriftLevel.low:
        score += 24;
        break;
      case GpsDriftLevel.moderate:
        score += 18;
        break;
      case GpsDriftLevel.high:
        score += 12;
        break;
      case GpsDriftLevel.excessive:
        score += 0;
        break;
    }

    // Environmental impact weight: 30%
    switch (environmentalImpact) {
      case EnvironmentalImpact.minimal:
        score += 30;
        break;
      case EnvironmentalImpact.low:
        score += 24;
        break;
      case EnvironmentalImpact.moderate:
        score += 18;
        break;
      case EnvironmentalImpact.high:
        score += 12;
        break;
      case EnvironmentalImpact.severe:
        score += 0;
        break;
    }

    // Convert score to quality level
    if (score >= 85) return GpsOverallQuality.excellent;
    if (score >= 70) return GpsOverallQuality.good;
    if (score >= 50) return GpsOverallQuality.fair;
    if (score >= 30) return GpsOverallQuality.poor;
    return GpsOverallQuality.unavailable;
  }

  GpsDriftLevel _getDriftLevel() {
    if (_driftDistance <= 2.0) return GpsDriftLevel.minimal;
    if (_driftDistance <= 5.0) return GpsDriftLevel.low;
    if (_driftDistance <= 10.0) return GpsDriftLevel.moderate;
    if (_driftDistance <= 20.0) return GpsDriftLevel.high;
    return GpsDriftLevel.excessive;
  }

  EnvironmentalImpact _getEnvironmentalImpact() {
    switch (_currentEnvironment) {
      case EnvironmentalCondition.openArea:
        return EnvironmentalImpact.minimal;
      case EnvironmentalCondition.urban:
        return EnvironmentalImpact.low;
      case EnvironmentalCondition.suburban:
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

  List<String> _getRecommendedActions(
    GpsSignalQuality signalQuality,
    GpsDriftLevel driftLevel,
    EnvironmentalImpact environmentalImpact,
  ) {
    final actions = <String>[];

    if (signalQuality == GpsSignalQuality.poor ||
        signalQuality == GpsSignalQuality.unavailable) {
      actions.add('Move to an area with better sky visibility');
      actions.add('Avoid areas with tall buildings or dense tree cover');
    }

    if (driftLevel == GpsDriftLevel.high ||
        driftLevel == GpsDriftLevel.excessive) {
      actions.add('Allow GPS to stabilize before starting tracking');
      actions.add('Consider recalibrating device compass');
    }

    if (environmentalImpact == EnvironmentalImpact.high ||
        environmentalImpact == EnvironmentalImpact.severe) {
      actions.add('Consider using alternative positioning methods');
      actions.add('Increase location update frequency for better accuracy');
    }

    if (actions.isEmpty) {
      actions.add('GPS conditions are optimal for tracking');
    }

    return actions;
  }

  Map<GpsSignalQuality, double> _calculateQualityDistribution() {
    if (_qualityHistory.isEmpty) {
      return {for (final quality in GpsSignalQuality.values) quality: 0.0};
    }

    final distribution = <GpsSignalQuality, int>{};
    for (final reading in _qualityHistory) {
      distribution[reading.signalQuality] =
          (distribution[reading.signalQuality] ?? 0) + 1;
    }

    final total = _qualityHistory.length;
    return distribution
        .map((quality, count) => MapEntry(quality, count / total));
  }

  bool _isChallengingEnvironment(EnvironmentalCondition condition) => [
        EnvironmentalCondition.urbanCanyon,
        EnvironmentalCondition.denseForest,
        EnvironmentalCondition.indoor,
        EnvironmentalCondition.underground,
      ].contains(condition);

  int _getUpdateIntervalForMode(GpsAccuracyMode mode) {
    switch (mode) {
      case GpsAccuracyMode.minimal:
        return 10; // 10 seconds
      case GpsAccuracyMode.balanced:
        return 5; // 5 seconds
      case GpsAccuracyMode.comprehensive:
        return 2; // 2 seconds
    }
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    stop();
    _instance = null;
  }
}

/// GPS accuracy monitoring modes
enum GpsAccuracyMode {
  minimal,
  balanced,
  comprehensive;

  String get description {
    switch (this) {
      case GpsAccuracyMode.minimal:
        return 'Minimal (Basic accuracy monitoring)';
      case GpsAccuracyMode.balanced:
        return 'Balanced (Standard monitoring)';
      case GpsAccuracyMode.comprehensive:
        return 'Comprehensive (Detailed analysis)';
    }
  }
}
