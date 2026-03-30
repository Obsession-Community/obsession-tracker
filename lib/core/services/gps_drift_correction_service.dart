import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/services/location_service.dart';
import 'package:obsession_tracker/core/services/sensor_fusion_service.dart';

/// GPS drift detection and correction service
///
/// Provides advanced algorithms to detect and correct GPS drift, especially
/// when the device is stationary or moving slowly. Uses sensor fusion and
/// statistical analysis to improve location accuracy.
class GpsDriftCorrectionService {
  factory GpsDriftCorrectionService() =>
      _instance ??= GpsDriftCorrectionService._();
  GpsDriftCorrectionService._();
  static GpsDriftCorrectionService? _instance;

  final LocationService _locationService = LocationService();
  SensorFusionService? _sensorFusionService;

  // Stream controllers
  StreamController<DriftCorrectionUpdate>? _correctionController;
  StreamController<DriftDetectionAlert>? _alertController;

  // Service state
  bool _isActive = false;
  DriftCorrectionMode _mode = DriftCorrectionMode.balanced;

  // Location tracking
  StreamSubscription<EnhancedLocationData>? _locationSubscription;
  StreamSubscription<SensorFusionReading>? _sensorSubscription;

  // Drift detection state
  final List<LocationSample> _locationHistory = <LocationSample>[];
  static const int _maxLocationHistoryLength = 50;

  // Stationary detection
  Position? _stationaryBasePosition;
  int _stationaryReadingCount = 0;
  static const int _minStationaryReadings = 5;
  static const double _stationarySpeedThreshold = 0.5; // m/s
  static const double _stationaryDistanceThreshold = 5.0; // meters

  // Drift correction algorithms
  final List<Position> _correctedPositions = <Position>[];
  final KalmanFilter _kalmanFilter = KalmanFilter();
  final MovingAverageFilter _movingAverageFilter =
      MovingAverageFilter(windowSize: 5);

  // Drift statistics
  double _currentDriftMagnitude = 0.0;
  double _averageDriftMagnitude = 0.0;
  final List<double> _driftHistory = <double>[];
  static const int _maxDriftHistoryLength = 100;

  // Correction performance
  int _totalCorrections = 0;
  int _successfulCorrections = 0;
  double _averageAccuracyImprovement = 0.0;

  /// Stream of drift correction updates
  Stream<DriftCorrectionUpdate> get correctionStream {
    _correctionController ??=
        StreamController<DriftCorrectionUpdate>.broadcast();
    return _correctionController!.stream;
  }

  /// Stream of drift detection alerts
  Stream<DriftDetectionAlert> get alertStream {
    _alertController ??= StreamController<DriftDetectionAlert>.broadcast();
    return _alertController!.stream;
  }

  /// Current drift correction mode
  DriftCorrectionMode get mode => _mode;

  /// Whether the service is active
  bool get isActive => _isActive;

  /// Current drift magnitude in meters
  double get currentDriftMagnitude => _currentDriftMagnitude;

  /// Average drift magnitude over time
  double get averageDriftMagnitude => _averageDriftMagnitude;

  /// Correction success rate (0-1)
  double get correctionSuccessRate =>
      _totalCorrections > 0 ? _successfulCorrections / _totalCorrections : 0.0;

  /// Start GPS drift detection and correction
  Future<void> start({
    DriftCorrectionMode mode = DriftCorrectionMode.balanced,
    SensorFusionService? sensorFusionService,
  }) async {
    try {
      await stop(); // Ensure clean start

      _mode = mode;
      _sensorFusionService = sensorFusionService;

      debugPrint('🎯 Starting GPS drift correction service...');
      debugPrint('  Mode: ${mode.name}');

      // Initialize stream controllers
      _correctionController ??=
          StreamController<DriftCorrectionUpdate>.broadcast();
      _alertController ??= StreamController<DriftDetectionAlert>.broadcast();

      // Start location monitoring
      await _startLocationMonitoring();

      // Start sensor monitoring if available
      if (_sensorFusionService != null) {
        _startSensorMonitoring();
      }

      _isActive = true;
      debugPrint('🎯 GPS drift correction service started successfully');
    } catch (e) {
      debugPrint('🎯 Error starting GPS drift correction service: $e');
      rethrow;
    }
  }

  /// Stop GPS drift detection and correction
  Future<void> stop() async {
    // Cancel subscriptions
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    await _sensorSubscription?.cancel();
    _sensorSubscription = null;

    // Close stream controllers
    await _correctionController?.close();
    _correctionController = null;

    await _alertController?.close();
    _alertController = null;

    _isActive = false;
    debugPrint('🎯 GPS drift correction service stopped');
  }

  /// Change drift correction mode
  Future<void> setMode(DriftCorrectionMode newMode) async {
    if (newMode == _mode) return;

    debugPrint(
        '🎯 Changing drift correction mode: ${_mode.name} → ${newMode.name}');

    final wasActive = _isActive;
    if (wasActive) {
      await stop();
    }

    _mode = newMode;

    if (wasActive) {
      await start(mode: newMode, sensorFusionService: _sensorFusionService);
    }
  }

  /// Get current drift correction statistics
  DriftCorrectionStatistics getDriftStatistics() => DriftCorrectionStatistics(
        totalCorrections: _totalCorrections,
        successfulCorrections: _successfulCorrections,
        successRate: correctionSuccessRate,
        currentDriftMagnitude: _currentDriftMagnitude,
        averageDriftMagnitude: _averageDriftMagnitude,
        averageAccuracyImprovement: _averageAccuracyImprovement,
        driftHistory: List.from(_driftHistory),
        timestamp: DateTime.now(),
      );

  /// Manually trigger drift correction for a position
  Position? correctPosition(Position position, {bool forceCorrection = false}) {
    if (!_isActive && !forceCorrection) return null;

    try {
      // Apply correction algorithms based on mode
      Position? correctedPosition;

      switch (_mode) {
        case DriftCorrectionMode.conservative:
          correctedPosition = _applyConservativeCorrection(position);
          break;
        case DriftCorrectionMode.balanced:
          correctedPosition = _applyBalancedCorrection(position);
          break;
        case DriftCorrectionMode.aggressive:
          correctedPosition = _applyAggressiveCorrection(position);
          break;
      }

      if (correctedPosition != null) {
        _recordCorrection(position, correctedPosition);
      }

      return correctedPosition ?? position;
    } catch (e) {
      debugPrint('🎯 Error correcting position: $e');
      return position;
    }
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
        debugPrint('🎯 Drift correction location stream error: $error');
      },
    );
  }

  void _startSensorMonitoring() {
    if (_sensorFusionService == null) return;

    _sensorSubscription = _sensorFusionService!.fusionStream.listen(
      _handleSensorUpdate,
      onError: (Object error) {
        debugPrint('🎯 Drift correction sensor stream error: $error');
      },
    );
  }

  void _handleLocationUpdate(EnhancedLocationData locationData) {
    final position = locationData.position;
    final now = DateTime.now();

    // Create location sample
    final sample = LocationSample(
      position: position,
      speed: locationData.bestSpeed ?? 0.0,
      timestamp: now,
    );

    // Update location history
    _locationHistory.add(sample);
    if (_locationHistory.length > _maxLocationHistoryLength) {
      _locationHistory.removeAt(0);
    }

    // Detect if device is stationary
    final isStationary = _detectStationaryState(sample);

    // Perform drift detection and correction
    final correctedPosition = _performDriftCorrection(position, isStationary);

    // Calculate drift magnitude
    if (correctedPosition != position) {
      _currentDriftMagnitude = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        correctedPosition.latitude,
        correctedPosition.longitude,
      );

      _updateDriftStatistics(_currentDriftMagnitude);
    } else {
      _currentDriftMagnitude = 0.0;
    }

    // Create correction update
    final correctionUpdate = DriftCorrectionUpdate(
      originalPosition: position,
      correctedPosition: correctedPosition,
      driftMagnitude: _currentDriftMagnitude,
      isStationary: isStationary,
      correctionMethod: _getLastCorrectionMethod(),
      confidence: _calculateCorrectionConfidence(position, correctedPosition),
      timestamp: now,
    );

    // Emit correction update
    _correctionController?.add(correctionUpdate);

    // Check for drift alerts
    _checkForDriftAlerts(correctionUpdate);
  }

  void _handleSensorUpdate(SensorFusionReading sensorReading) {
    // Use sensor data to enhance drift detection
    // Accelerometer data can help confirm stationary state
    if (sensorReading.accelerometer != null) {
      final isDeviceStable = !sensorReading.accelerometer!.isInMotion;

      // Use this information to improve stationary detection
      if (isDeviceStable && _stationaryBasePosition != null) {
        // Device sensors confirm stationary state
        // This increases confidence in drift detection
      }
    }
  }

  bool _detectStationaryState(LocationSample sample) {
    final isLowSpeed = sample.speed <= _stationarySpeedThreshold;

    if (isLowSpeed) {
      if (_stationaryBasePosition == null) {
        // Start tracking stationary state
        _stationaryBasePosition = sample.position;
        _stationaryReadingCount = 1;
        return false; // Not confirmed stationary yet
      } else {
        // Check if still within stationary threshold
        final distance = Geolocator.distanceBetween(
          _stationaryBasePosition!.latitude,
          _stationaryBasePosition!.longitude,
          sample.position.latitude,
          sample.position.longitude,
        );

        if (distance <= _stationaryDistanceThreshold) {
          _stationaryReadingCount++;
          return _stationaryReadingCount >= _minStationaryReadings;
        } else {
          // Moved too far, reset stationary tracking
          _resetStationaryTracking();
          return false;
        }
      }
    } else {
      // Device is moving, reset stationary tracking
      _resetStationaryTracking();
      return false;
    }
  }

  void _resetStationaryTracking() {
    _stationaryBasePosition = null;
    _stationaryReadingCount = 0;
  }

  Position _performDriftCorrection(Position position, bool isStationary) {
    if (!isStationary) {
      // For moving positions, use lighter correction
      return _applyMovingCorrection(position);
    } else {
      // For stationary positions, apply stronger drift correction
      return _applyStationaryCorrection(position);
    }
  }

  Position _applyMovingCorrection(Position position) =>
      // Use Kalman filter for moving positions
      _kalmanFilter.update(position);

  Position _applyStationaryCorrection(Position position) {
    if (_stationaryBasePosition == null) return position;

    // Calculate drift from base position
    final drift = Geolocator.distanceBetween(
      _stationaryBasePosition!.latitude,
      _stationaryBasePosition!.longitude,
      position.latitude,
      position.longitude,
    );

    // Apply correction based on mode and drift magnitude
    switch (_mode) {
      case DriftCorrectionMode.conservative:
        // Only correct significant drift
        if (drift > 10.0) {
          return _interpolateTowardsBase(position, 0.3);
        }
        break;

      case DriftCorrectionMode.balanced:
        // Moderate correction
        if (drift > 5.0) {
          return _interpolateTowardsBase(position, 0.5);
        }
        break;

      case DriftCorrectionMode.aggressive:
        // Strong correction for any drift
        if (drift > 2.0) {
          return _interpolateTowardsBase(position, 0.7);
        }
        break;
    }

    return position;
  }

  Position _interpolateTowardsBase(Position position, double factor) {
    if (_stationaryBasePosition == null) return position;

    final correctedLat = position.latitude +
        ((_stationaryBasePosition!.latitude - position.latitude) * factor);
    final correctedLng = position.longitude +
        ((_stationaryBasePosition!.longitude - position.longitude) * factor);

    return Position(
      latitude: correctedLat,
      longitude: correctedLng,
      timestamp: position.timestamp,
      accuracy: position.accuracy * 0.8, // Improve accuracy estimate
      altitude: position.altitude,
      altitudeAccuracy: position.altitudeAccuracy,
      heading: position.heading,
      headingAccuracy: position.headingAccuracy,
      speed: position.speed,
      speedAccuracy: position.speedAccuracy,
    );
  }

  Position? _applyConservativeCorrection(Position position) {
    // Only apply correction for significant drift
    if (_locationHistory.length < 5) return null;

    final recentPositions = _locationHistory.length >= 5
        ? _locationHistory
            .sublist(_locationHistory.length - 5)
            .map((s) => s.position)
            .toList()
        : _locationHistory.map((s) => s.position).toList();
    final avgAccuracy =
        recentPositions.map((p) => p.accuracy).reduce((a, b) => a + b) /
            recentPositions.length;

    // Only correct if accuracy is poor
    if (avgAccuracy > 15.0) {
      return _movingAverageFilter.update(position);
    }

    return null;
  }

  Position? _applyBalancedCorrection(Position position) {
    // Apply moderate correction using multiple algorithms
    final kalmanResult = _kalmanFilter.update(position);
    final movingAvgResult = _movingAverageFilter.update(position);

    // Blend results
    return Position(
      latitude: (kalmanResult.latitude + movingAvgResult.latitude) / 2,
      longitude: (kalmanResult.longitude + movingAvgResult.longitude) / 2,
      timestamp: position.timestamp,
      accuracy: math.min(kalmanResult.accuracy, movingAvgResult.accuracy),
      altitude: position.altitude,
      altitudeAccuracy: position.altitudeAccuracy,
      heading: position.heading,
      headingAccuracy: position.headingAccuracy,
      speed: position.speed,
      speedAccuracy: position.speedAccuracy,
    );
  }

  Position? _applyAggressiveCorrection(Position position) {
    // Apply strong correction using all available algorithms
    final kalmanResult = _kalmanFilter.update(position);
    final movingAvgResult = _movingAverageFilter.update(position);

    // Weighted blend favoring the filter with better accuracy
    final kalmanWeight = 1.0 / (kalmanResult.accuracy + 1.0);
    final movingAvgWeight = 1.0 / (movingAvgResult.accuracy + 1.0);
    final totalWeight = kalmanWeight + movingAvgWeight;

    return Position(
      latitude: (kalmanResult.latitude * kalmanWeight +
              movingAvgResult.latitude * movingAvgWeight) /
          totalWeight,
      longitude: (kalmanResult.longitude * kalmanWeight +
              movingAvgResult.longitude * movingAvgWeight) /
          totalWeight,
      timestamp: position.timestamp,
      accuracy: math.min(kalmanResult.accuracy, movingAvgResult.accuracy) * 0.9,
      altitude: position.altitude,
      altitudeAccuracy: position.altitudeAccuracy,
      heading: position.heading,
      headingAccuracy: position.headingAccuracy,
      speed: position.speed,
      speedAccuracy: position.speedAccuracy,
    );
  }

  void _recordCorrection(Position original, Position corrected) {
    _totalCorrections++;

    // Calculate accuracy improvement
    final accuracyImprovement = original.accuracy - corrected.accuracy;
    if (accuracyImprovement > 0) {
      _successfulCorrections++;
      _averageAccuracyImprovement =
          (_averageAccuracyImprovement * (_successfulCorrections - 1) +
                  accuracyImprovement) /
              _successfulCorrections;
    }

    _correctedPositions.add(corrected);
    if (_correctedPositions.length > _maxLocationHistoryLength) {
      _correctedPositions.removeAt(0);
    }
  }

  void _updateDriftStatistics(double driftMagnitude) {
    _driftHistory.add(driftMagnitude);
    if (_driftHistory.length > _maxDriftHistoryLength) {
      _driftHistory.removeAt(0);
    }

    _averageDriftMagnitude = _driftHistory.isNotEmpty
        ? _driftHistory.reduce((a, b) => a + b) / _driftHistory.length
        : 0.0;
  }

  double _calculateCorrectionConfidence(Position original, Position corrected) {
    // Calculate confidence based on various factors
    double confidence = 0.5; // Base confidence

    // Factor in accuracy improvement
    if (corrected.accuracy < original.accuracy) {
      confidence += 0.3;
    }

    // Factor in stationary state
    if (_stationaryBasePosition != null &&
        _stationaryReadingCount >= _minStationaryReadings) {
      confidence += 0.2;
    }

    // Factor in sensor confirmation
    if (_sensorFusionService != null) {
      confidence += 0.1;
    }

    return math.min(confidence, 1.0);
  }

  void _checkForDriftAlerts(DriftCorrectionUpdate update) {
    // Alert for excessive drift
    if (update.driftMagnitude > 20.0) {
      _emitAlert(DriftDetectionAlert(
        type: DriftAlertType.excessiveDrift,
        severity: DriftAlertSeverity.high,
        message:
            'Excessive GPS drift detected: ${update.driftMagnitude.toStringAsFixed(1)}m',
        driftMagnitude: update.driftMagnitude,
        timestamp: update.timestamp,
      ));
    }

    // Alert for correction failure
    if (update.confidence < 0.3) {
      _emitAlert(DriftDetectionAlert(
        type: DriftAlertType.correctionUncertain,
        severity: DriftAlertSeverity.medium,
        message: 'GPS drift correction has low confidence',
        driftMagnitude: update.driftMagnitude,
        timestamp: update.timestamp,
      ));
    }
  }

  void _emitAlert(DriftDetectionAlert alert) {
    _alertController?.add(alert);
    debugPrint('🎯 Drift Alert: ${alert.message}');
  }

  String _getLastCorrectionMethod() {
    switch (_mode) {
      case DriftCorrectionMode.conservative:
        return 'Conservative (Moving Average)';
      case DriftCorrectionMode.balanced:
        return 'Balanced (Kalman + Moving Average)';
      case DriftCorrectionMode.aggressive:
        return 'Aggressive (Weighted Blend)';
    }
  }

  int _getUpdateIntervalForMode(DriftCorrectionMode mode) {
    switch (mode) {
      case DriftCorrectionMode.conservative:
        return 10; // 10 seconds
      case DriftCorrectionMode.balanced:
        return 5; // 5 seconds
      case DriftCorrectionMode.aggressive:
        return 2; // 2 seconds
    }
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    stop();
    _instance = null;
  }
}

/// Simple Kalman filter for GPS position smoothing
class KalmanFilter {
  Position? _lastPosition;
  final double _processNoise = 1.0;
  final double _measurementNoise = 4.0;
  double _estimationError = 1.0;

  Position update(Position measurement) {
    if (_lastPosition == null) {
      _lastPosition = measurement;
      return measurement;
    }

    // Simplified Kalman filter implementation
    final kalmanGain =
        _estimationError / (_estimationError + _measurementNoise);

    final correctedLat = _lastPosition!.latitude +
        kalmanGain * (measurement.latitude - _lastPosition!.latitude);
    final correctedLng = _lastPosition!.longitude +
        kalmanGain * (measurement.longitude - _lastPosition!.longitude);

    _estimationError = (1 - kalmanGain) * _estimationError + _processNoise;

    final correctedPosition = Position(
      latitude: correctedLat,
      longitude: correctedLng,
      timestamp: measurement.timestamp,
      accuracy: measurement.accuracy * (1 - kalmanGain),
      altitude: measurement.altitude,
      altitudeAccuracy: measurement.altitudeAccuracy,
      heading: measurement.heading,
      headingAccuracy: measurement.headingAccuracy,
      speed: measurement.speed,
      speedAccuracy: measurement.speedAccuracy,
    );

    _lastPosition = correctedPosition;
    return correctedPosition;
  }
}

/// Moving average filter for GPS position smoothing
class MovingAverageFilter {
  MovingAverageFilter({required this.windowSize});
  final int windowSize;
  final List<Position> _positions = <Position>[];

  Position update(Position position) {
    _positions.add(position);
    if (_positions.length > windowSize) {
      _positions.removeAt(0);
    }

    if (_positions.length == 1) {
      return position;
    }

    // Calculate average position
    final avgLat = _positions.map((p) => p.latitude).reduce((a, b) => a + b) /
        _positions.length;
    final avgLng = _positions.map((p) => p.longitude).reduce((a, b) => a + b) /
        _positions.length;
    final avgAccuracy =
        _positions.map((p) => p.accuracy).reduce((a, b) => a + b) /
            _positions.length;

    return Position(
      latitude: avgLat,
      longitude: avgLng,
      timestamp: position.timestamp,
      accuracy: avgAccuracy,
      altitude: position.altitude,
      altitudeAccuracy: position.altitudeAccuracy,
      heading: position.heading,
      headingAccuracy: position.headingAccuracy,
      speed: position.speed,
      speedAccuracy: position.speedAccuracy,
    );
  }
}

/// Location sample for drift analysis
@immutable
class LocationSample {
  const LocationSample({
    required this.position,
    required this.speed,
    required this.timestamp,
  });

  final Position position;
  final double speed;
  final DateTime timestamp;
}

/// Drift correction update
@immutable
class DriftCorrectionUpdate {
  const DriftCorrectionUpdate({
    required this.originalPosition,
    required this.correctedPosition,
    required this.driftMagnitude,
    required this.isStationary,
    required this.correctionMethod,
    required this.confidence,
    required this.timestamp,
  });

  final Position originalPosition;
  final Position correctedPosition;
  final double driftMagnitude;
  final bool isStationary;
  final String correctionMethod;
  final double confidence;
  final DateTime timestamp;
}

/// Drift detection alert
@immutable
class DriftDetectionAlert {
  const DriftDetectionAlert({
    required this.type,
    required this.severity,
    required this.message,
    required this.driftMagnitude,
    required this.timestamp,
  });

  final DriftAlertType type;
  final DriftAlertSeverity severity;
  final String message;
  final double driftMagnitude;
  final DateTime timestamp;
}

/// Drift correction statistics
@immutable
class DriftCorrectionStatistics {
  const DriftCorrectionStatistics({
    required this.totalCorrections,
    required this.successfulCorrections,
    required this.successRate,
    required this.currentDriftMagnitude,
    required this.averageDriftMagnitude,
    required this.averageAccuracyImprovement,
    required this.driftHistory,
    required this.timestamp,
  });

  final int totalCorrections;
  final int successfulCorrections;
  final double successRate;
  final double currentDriftMagnitude;
  final double averageDriftMagnitude;
  final double averageAccuracyImprovement;
  final List<double> driftHistory;
  final DateTime timestamp;
}

/// Drift correction modes
enum DriftCorrectionMode {
  conservative,
  balanced,
  aggressive;

  String get description {
    switch (this) {
      case DriftCorrectionMode.conservative:
        return 'Conservative (Minimal correction)';
      case DriftCorrectionMode.balanced:
        return 'Balanced (Moderate correction)';
      case DriftCorrectionMode.aggressive:
        return 'Aggressive (Maximum correction)';
    }
  }
}

/// Drift alert types
enum DriftAlertType {
  excessiveDrift,
  correctionUncertain,
  stationaryDriftDetected,
  correctionImproved;
}

/// Drift alert severity levels
enum DriftAlertSeverity {
  low,
  medium,
  high;
}
