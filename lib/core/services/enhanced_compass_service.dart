import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/services/accelerometer_service.dart';
import 'package:obsession_tracker/core/services/device_orientation_service.dart'
    as orientation;
import 'package:obsession_tracker/core/services/magnetometer_service.dart';

/// Enhanced compass service that combines magnetometer, accelerometer, and device orientation
/// Provides accurate heading with tilt compensation and calibration
class EnhancedCompassService {
  EnhancedCompassService({
    MagnetometerService? magnetometerService,
    AccelerometerService? accelerometerService,
    orientation.DeviceOrientationService? orientationService,
  })  : _magnetometerService = magnetometerService ?? MagnetometerService(),
        _accelerometerService = accelerometerService ?? AccelerometerService(),
        _orientationService =
            orientationService ?? orientation.DeviceOrientationService();

  final MagnetometerService _magnetometerService;
  final AccelerometerService _accelerometerService;
  final orientation.DeviceOrientationService _orientationService;

  StreamSubscription<MagnetometerReading>? _magnetometerSubscription;
  StreamSubscription<AccelerometerReading>? _accelerometerSubscription;
  StreamSubscription<orientation.OrientationReading>? _orientationSubscription;

  StreamController<EnhancedCompassReading>? _compassController;
  StreamController<CompassCalibrationEvent>? _calibrationController;

  // Current sensor readings
  MagnetometerReading? _lastMagnetometerReading;
  AccelerometerReading? _lastAccelerometerReading;
  orientation.OrientationReading? _lastOrientationReading;

  // Compass state
  double _currentHeading = 0.0;
  double _tiltCompensatedHeading = 0.0;
  double _orientationCorrectedHeading = 0.0;
  CompassAccuracy _accuracy = CompassAccuracy.unreliable;
  bool _isActive = false;

  // Tilt compensation
  bool _tiltCompensationEnabled = true;
  static const double _maxTiltAngle = 60.0; // degrees

  // GPS heading fallback
  double? _gpsHeading;
  DateTime? _lastGpsUpdate;
  static const Duration _gpsTimeout = Duration(seconds: 10);

  // Filtering
  static const double _headingAlpha = 0.8;
  double _filteredHeading = 0.0;

  /// Stream of enhanced compass readings
  Stream<EnhancedCompassReading> get compassStream {
    _compassController ??= StreamController<EnhancedCompassReading>.broadcast();
    return _compassController!.stream;
  }

  /// Stream of calibration events
  Stream<CompassCalibrationEvent> get calibrationStream {
    _calibrationController ??=
        StreamController<CompassCalibrationEvent>.broadcast();
    return _calibrationController!.stream;
  }

  /// Current compass heading in degrees (0-360)
  double get currentHeading => _orientationCorrectedHeading;

  /// Current compass accuracy
  CompassAccuracy get accuracy => _accuracy;

  /// Whether the compass is active
  bool get isActive => _isActive;

  /// Whether tilt compensation is enabled
  bool get tiltCompensationEnabled => _tiltCompensationEnabled;

  /// Whether GPS heading is being used as fallback
  bool get isUsingGpsFallback {
    if (_gpsHeading == null || _lastGpsUpdate == null) return false;
    return DateTime.now().difference(_lastGpsUpdate!) < _gpsTimeout;
  }

  /// Start enhanced compass service
  Future<void> start() async {
    try {
      await stop(); // Ensure clean start

      _compassController ??=
          StreamController<EnhancedCompassReading>.broadcast();
      _calibrationController ??=
          StreamController<CompassCalibrationEvent>.broadcast();

      debugPrint('🧭✨ Starting enhanced compass service...');

      // Start underlying sensor services
      await _magnetometerService.start();
      await _accelerometerService.start();
      await _orientationService.start();

      // Subscribe to sensor streams
      _magnetometerSubscription = _magnetometerService.readingStream.listen(
        _handleMagnetometerReading,
        onError: _handleMagnetometerError,
      );

      _accelerometerSubscription = _accelerometerService.readingStream.listen(
        _handleAccelerometerReading,
        onError: _handleAccelerometerError,
      );

      _orientationSubscription = _orientationService.orientationStream.listen(
        _handleOrientationReading,
        onError: _handleOrientationError,
      );

      // Subscribe to magnetometer calibration events
      _magnetometerService.calibrationStream.listen(
        _handleMagnetometerCalibration,
        onError: (Object error) =>
            debugPrint('🧭✨ Magnetometer calibration error: $error'),
      );

      _isActive = true;
      debugPrint('🧭✨ Enhanced compass service started');
    } catch (e) {
      debugPrint('🧭✨ Error starting enhanced compass service: $e');
      rethrow;
    }
  }

  /// Stop enhanced compass service
  Future<void> stop() async {
    await _magnetometerSubscription?.cancel();
    _magnetometerSubscription = null;

    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;

    await _orientationSubscription?.cancel();
    _orientationSubscription = null;

    await _magnetometerService.stop();
    await _accelerometerService.stop();
    await _orientationService.stop();

    await _compassController?.close();
    _compassController = null;

    await _calibrationController?.close();
    _calibrationController = null;

    _isActive = false;
    debugPrint('🧭✨ Enhanced compass service stopped');
  }

  /// Start magnetometer calibration
  void startCalibration() {
    _magnetometerService.startCalibration();
    debugPrint('🧭✨ Started magnetometer calibration');
  }

  /// Stop magnetometer calibration
  void stopCalibration() {
    _magnetometerService.stopCalibration();
    debugPrint('🧭✨ Stopped magnetometer calibration');
  }

  /// Reset magnetometer calibration
  void resetCalibration() {
    _magnetometerService.resetCalibration();
    debugPrint('🧭✨ Reset magnetometer calibration');
  }

  /// Enable or disable tilt compensation
  void setTiltCompensationEnabled({required bool enabled}) {
    _tiltCompensationEnabled = enabled;
    debugPrint('🧭✨ Tilt compensation ${enabled ? 'enabled' : 'disabled'}');

    // Recalculate heading with new setting
    _updateCompassReading();
  }

  /// Update GPS heading for fallback
  void updateGpsHeading(double? heading) {
    if (heading != null && heading >= 0 && heading <= 360) {
      _gpsHeading = heading;
      _lastGpsUpdate = DateTime.now();

      debugPrint('🧭✨ GPS heading updated: ${heading.toStringAsFixed(1)}°');

      // Update compass reading with GPS fallback if needed
      _updateCompassReading();
    }
  }

  void _handleMagnetometerReading(MagnetometerReading reading) {
    _lastMagnetometerReading = reading;
    _updateCompassReading();
  }

  void _handleAccelerometerReading(AccelerometerReading reading) {
    _lastAccelerometerReading = reading;
    _updateCompassReading();
  }

  void _handleOrientationReading(orientation.OrientationReading reading) {
    _lastOrientationReading = reading;
    _updateCompassReading();
  }

  void _handleMagnetometerError(Object error) {
    debugPrint('🧭✨ Magnetometer error: $error');
    _accuracy = CompassAccuracy.unreliable;
  }

  void _handleAccelerometerError(Object error) {
    debugPrint('🧭✨ Accelerometer error: $error');
  }

  void _handleOrientationError(Object error) {
    debugPrint('🧭✨ Orientation error: $error');
  }

  void _handleMagnetometerCalibration(CalibrationStatus status) {
    final event = CompassCalibrationEvent(
      isCalibrating: status.isCalibrating,
      isCalibrated: status.isCalibrated,
      quality: status.quality,
      progress: status.progress,
      sampleCount: status.sampleCount,
      timestamp: DateTime.now(),
    );

    _calibrationController?.add(event);
  }

  void _updateCompassReading() {
    if (_lastMagnetometerReading == null) return;

    try {
      // Calculate basic heading from magnetometer
      _currentHeading = _lastMagnetometerReading!.heading;

      // Apply tilt compensation if enabled and accelerometer data is available
      if (_tiltCompensationEnabled && _lastAccelerometerReading != null) {
        _tiltCompensatedHeading = _calculateTiltCompensatedHeading();
      } else {
        _tiltCompensatedHeading = _currentHeading;
      }

      // Apply device orientation correction
      if (_lastOrientationReading != null) {
        _orientationCorrectedHeading = _orientationService
            .getOrientationCorrectedHeading(_tiltCompensatedHeading);
      } else {
        _orientationCorrectedHeading = _tiltCompensatedHeading;
      }

      // Apply filtering
      if (_filteredHeading == 0.0) {
        _filteredHeading = _orientationCorrectedHeading;
      } else {
        _filteredHeading = _applyLowPassFilter(_orientationCorrectedHeading);
      }

      // Determine accuracy
      _accuracy = _calculateAccuracy();

      // Use GPS fallback if compass is unreliable
      double finalHeading = _filteredHeading;
      bool usingGpsFallback = false;

      if (_accuracy == CompassAccuracy.unreliable && isUsingGpsFallback) {
        finalHeading = _gpsHeading!;
        usingGpsFallback = true;
      }

      // Create enhanced compass reading
      final reading = EnhancedCompassReading(
        heading: finalHeading,
        rawMagneticHeading: _currentHeading,
        tiltCompensatedHeading: _tiltCompensatedHeading,
        orientationCorrectedHeading: _orientationCorrectedHeading,
        filteredHeading: _filteredHeading,
        accuracy: _accuracy,
        magneticFieldStrength: _lastMagnetometerReading!.magneticFieldStrength,
        magneticEnvironment: _lastMagnetometerReading!.magneticEnvironment,
        tiltAngle: _calculateTiltAngle(),
        deviceOrientation: _convertDeviceOrientation(
            _lastOrientationReading?.deviceOrientation),
        isCalibrated: _lastMagnetometerReading!.isCalibrated,
        isTiltCompensated:
            _tiltCompensationEnabled && _lastAccelerometerReading != null,
        isUsingGpsFallback: usingGpsFallback,
        timestamp: DateTime.now(),
      );

      _compassController?.add(reading);
    } catch (e) {
      debugPrint('🧭✨ Error updating compass reading: $e');
    }
  }

  double _calculateTiltCompensatedHeading() {
    if (_lastMagnetometerReading == null || _lastAccelerometerReading == null) {
      return _currentHeading;
    }

    try {
      // Get magnetometer and accelerometer readings
      final mx = _lastMagnetometerReading!.calibratedX;
      final my = _lastMagnetometerReading!.calibratedY;
      final mz = _lastMagnetometerReading!.calibratedZ;

      final ax = _lastAccelerometerReading!.gravityX;
      final ay = _lastAccelerometerReading!.gravityY;
      final az = _lastAccelerometerReading!.gravityZ;

      // Calculate tilt angle
      final tiltAngle = _calculateTiltAngle();

      // Skip tilt compensation if tilt is too extreme
      if (tiltAngle > _maxTiltAngle) {
        return _currentHeading;
      }

      // Normalize accelerometer vector
      final norm = math.sqrt(ax * ax + ay * ay + az * az);
      if (norm == 0) return _currentHeading;

      final axNorm = ax / norm;
      final ayNorm = ay / norm;
      final azNorm = az / norm;

      // Calculate roll and pitch
      final roll = math.atan2(ayNorm, azNorm);
      final pitch =
          math.atan2(-axNorm, math.sqrt(ayNorm * ayNorm + azNorm * azNorm));

      // Tilt compensation calculations
      final cosRoll = math.cos(roll);
      final sinRoll = math.sin(roll);
      final cosPitch = math.cos(pitch);
      final sinPitch = math.sin(pitch);

      // Compensate magnetometer readings for tilt
      final mxComp = mx * cosPitch + mz * sinPitch;
      final myComp =
          mx * sinRoll * sinPitch + my * cosRoll - mz * sinRoll * cosPitch;

      // Calculate tilt-compensated heading
      double heading = math.atan2(myComp, mxComp) * (180 / math.pi);

      // Normalize to 0-360 degrees
      if (heading < 0) heading += 360;

      return heading;
    } catch (e) {
      debugPrint('🧭✨ Error calculating tilt compensation: $e');
      return _currentHeading;
    }
  }

  double _calculateTiltAngle() {
    if (_lastAccelerometerReading == null) return 0.0;

    final ax = _lastAccelerometerReading!.gravityX;
    final ay = _lastAccelerometerReading!.gravityY;
    final az = _lastAccelerometerReading!.gravityZ;

    final norm = math.sqrt(ax * ax + ay * ay + az * az);
    if (norm == 0) return 0.0;

    // Calculate angle from vertical (Z-axis)
    return math.acos(az.abs() / norm) * (180 / math.pi);
  }

  CompassAccuracy _calculateAccuracy() {
    if (_lastMagnetometerReading == null) return CompassAccuracy.unreliable;

    final magnetometerReading = _lastMagnetometerReading!;

    // Check if magnetometer is calibrated
    if (!magnetometerReading.isCalibrated) {
      return CompassAccuracy.unreliable;
    }

    // Check magnetic environment
    if (!magnetometerReading.magneticEnvironment.isGoodForCompass) {
      return CompassAccuracy.low;
    }

    // Check tilt angle if tilt compensation is enabled
    if (_tiltCompensationEnabled) {
      final tiltAngle = _calculateTiltAngle();
      if (tiltAngle > _maxTiltAngle) {
        return CompassAccuracy.low;
      }
    }

    // Check device orientation suitability
    if (_lastOrientationReading != null &&
        !_orientationService.isOrientationSuitableForCompass()) {
      return CompassAccuracy.low;
    }

    // Determine accuracy based on calibration quality
    switch (magnetometerReading.calibrationQuality) {
      case CalibrationQuality.excellent:
        return CompassAccuracy.high;
      case CalibrationQuality.good:
        return CompassAccuracy.medium;
      case CalibrationQuality.fair:
        return CompassAccuracy.low;
      case CalibrationQuality.poor:
        return CompassAccuracy.unreliable;
    }
  }

  double _applyLowPassFilter(double newHeading) {
    // Handle angle wrapping for smooth filtering
    double diff = newHeading - _filteredHeading;

    // Normalize difference to -180 to 180
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;

    // Apply low-pass filter
    _filteredHeading += _headingAlpha * diff;

    // Normalize result to 0-360
    while (_filteredHeading < 0) _filteredHeading += 360;
    while (_filteredHeading >= 360) _filteredHeading -= 360;

    return _filteredHeading;
  }

  /// Get compass direction name from heading
  String getDirectionName(double heading) {
    const List<String> directions = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW'
    ];

    final int index = ((heading + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }

  /// Get compass bearing text
  String getBearingText(double heading) =>
      '${heading.round()}° ${getDirectionName(heading)}';

  /// Convert between DeviceOrientation enums
  DeviceOrientation _convertDeviceOrientation(
      orientation.DeviceOrientation? orientationEnum) {
    if (orientationEnum == null) return DeviceOrientation.unknown;

    switch (orientationEnum) {
      case orientation.DeviceOrientation.portraitUp:
        return DeviceOrientation.portraitUp;
      case orientation.DeviceOrientation.portraitDown:
        return DeviceOrientation.portraitDown;
      case orientation.DeviceOrientation.landscapeLeft:
        return DeviceOrientation.landscapeLeft;
      case orientation.DeviceOrientation.landscapeRight:
        return DeviceOrientation.landscapeRight;
      case orientation.DeviceOrientation.faceUp:
        return DeviceOrientation.faceUp;
      case orientation.DeviceOrientation.faceDown:
        return DeviceOrientation.faceDown;
      case orientation.DeviceOrientation.unknown:
        return DeviceOrientation.unknown;
    }
  }

  /// Dispose of resources
  void dispose() {
    stop();
    _magnetometerService.dispose();
    _accelerometerService.dispose();
    _orientationService.dispose();
  }
}

/// Enhanced compass reading with comprehensive data
class EnhancedCompassReading {
  const EnhancedCompassReading({
    required this.heading,
    required this.rawMagneticHeading,
    required this.tiltCompensatedHeading,
    required this.orientationCorrectedHeading,
    required this.filteredHeading,
    required this.accuracy,
    required this.magneticFieldStrength,
    required this.magneticEnvironment,
    required this.tiltAngle,
    required this.deviceOrientation,
    required this.isCalibrated,
    required this.isTiltCompensated,
    required this.isUsingGpsFallback,
    required this.timestamp,
  });

  final double heading;
  final double rawMagneticHeading;
  final double tiltCompensatedHeading;
  final double orientationCorrectedHeading;
  final double filteredHeading;
  final CompassAccuracy accuracy;
  final double magneticFieldStrength;
  final MagneticEnvironment magneticEnvironment;
  final double tiltAngle;
  final DeviceOrientation deviceOrientation;
  final bool isCalibrated;
  final bool isTiltCompensated;
  final bool isUsingGpsFallback;
  final DateTime timestamp;
}

/// Compass calibration event
class CompassCalibrationEvent {
  const CompassCalibrationEvent({
    required this.isCalibrating,
    required this.isCalibrated,
    required this.quality,
    required this.progress,
    required this.sampleCount,
    required this.timestamp,
  });

  final bool isCalibrating;
  final bool isCalibrated;
  final CalibrationQuality quality;
  final double progress;
  final int sampleCount;
  final DateTime timestamp;
}

/// Compass accuracy levels
enum CompassAccuracy {
  unreliable,
  low,
  medium,
  high;

  String get description {
    switch (this) {
      case CompassAccuracy.unreliable:
        return 'Unreliable';
      case CompassAccuracy.low:
        return 'Low';
      case CompassAccuracy.medium:
        return 'Medium';
      case CompassAccuracy.high:
        return 'High';
    }
  }

  double get confidenceLevel {
    switch (this) {
      case CompassAccuracy.unreliable:
        return 0.0;
      case CompassAccuracy.low:
        return 0.3;
      case CompassAccuracy.medium:
        return 0.7;
      case CompassAccuracy.high:
        return 0.95;
    }
  }
}
