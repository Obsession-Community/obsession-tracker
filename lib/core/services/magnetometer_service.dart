import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Comprehensive magnetometer service with advanced calibration
/// Provides raw magnetometer data, calibrated readings, and magnetic field strength
class MagnetometerService {
  MagnetometerService();

  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamController<MagnetometerReading>? _readingController;
  StreamController<CalibrationStatus>? _calibrationController;

  // Raw magnetometer data

  // Calibration data
  final List<MagnetometerEvent> _calibrationSamples = <MagnetometerEvent>[];
  static const int _maxCalibrationSamples = 100;
  static const int _minCalibrationSamples = 50;

  // Calibration offsets (hard iron correction)
  double _offsetX = 0.0;
  double _offsetY = 0.0;
  double _offsetZ = 0.0;

  // Calibration scaling (soft iron correction)
  double _scaleX = 1.0;
  double _scaleY = 1.0;
  double _scaleZ = 1.0;

  // Calibration state
  bool _isCalibrated = false;
  bool _isCalibrating = false;
  CalibrationQuality _calibrationQuality = CalibrationQuality.poor;

  // Filtering
  static const double _alpha = 0.8; // Low-pass filter coefficient
  double _filteredX = 0.0;
  double _filteredY = 0.0;
  double _filteredZ = 0.0;

  // Magnetic field analysis
  double _magneticFieldStrength = 0.0;
  MagneticEnvironment _magneticEnvironment = MagneticEnvironment.unknown;

  /// Stream of magnetometer readings
  Stream<MagnetometerReading> get readingStream {
    _readingController ??= StreamController<MagnetometerReading>.broadcast();
    return _readingController!.stream;
  }

  /// Stream of calibration status updates
  Stream<CalibrationStatus> get calibrationStream {
    _calibrationController ??= StreamController<CalibrationStatus>.broadcast();
    return _calibrationController!.stream;
  }

  /// Current calibration status
  bool get isCalibrated => _isCalibrated;

  /// Current calibration quality
  CalibrationQuality get calibrationQuality => _calibrationQuality;

  /// Whether calibration is in progress
  bool get isCalibrating => _isCalibrating;

  /// Current magnetic field strength in µT
  double get magneticFieldStrength => _magneticFieldStrength;

  /// Current magnetic environment assessment
  MagneticEnvironment get magneticEnvironment => _magneticEnvironment;

  /// Start magnetometer service
  Future<void> start() async {
    try {
      await stop(); // Ensure clean start

      _readingController ??= StreamController<MagnetometerReading>.broadcast();
      _calibrationController ??=
          StreamController<CalibrationStatus>.broadcast();

      debugPrint('🧲 Starting magnetometer service...');

      // Start magnetometer stream
      _magnetometerSubscription = magnetometerEventStream().listen(
        _handleMagnetometerEvent,
        onError: _handleMagnetometerError,
        onDone: () {
          debugPrint('🧲 Magnetometer stream completed');
        },
      );

      debugPrint('🧲 Magnetometer service started');
    } catch (e) {
      debugPrint('🧲 Error starting magnetometer service: $e');
      rethrow;
    }
  }

  /// Stop magnetometer service
  Future<void> stop() async {
    await _magnetometerSubscription?.cancel();
    _magnetometerSubscription = null;

    await _readingController?.close();
    _readingController = null;

    await _calibrationController?.close();
    _calibrationController = null;

    debugPrint('🧲 Magnetometer service stopped');
  }

  /// Start calibration process
  void startCalibration() {
    if (_isCalibrating) return;

    _isCalibrating = true;
    _calibrationSamples.clear();
    _calibrationQuality = CalibrationQuality.poor;

    debugPrint('🧲 Starting magnetometer calibration...');
    _notifyCalibrationStatus();
  }

  /// Stop calibration and apply results
  void stopCalibration() {
    if (!_isCalibrating) return;

    _isCalibrating = false;

    if (_calibrationSamples.length >= _minCalibrationSamples) {
      _calculateCalibration();
      _isCalibrated = true;
      debugPrint(
          '🧲 Calibration completed with ${_calibrationSamples.length} samples');
    } else {
      debugPrint(
          '🧲 Calibration cancelled - insufficient samples (${_calibrationSamples.length} < $_minCalibrationSamples)');
    }

    _notifyCalibrationStatus();
  }

  /// Reset calibration
  void resetCalibration() {
    _isCalibrated = false;
    _isCalibrating = false;
    _calibrationSamples.clear();
    _calibrationQuality = CalibrationQuality.poor;

    // Reset calibration parameters
    _offsetX = _offsetY = _offsetZ = 0.0;
    _scaleX = _scaleY = _scaleZ = 1.0;

    debugPrint('🧲 Magnetometer calibration reset');
    _notifyCalibrationStatus();
  }

  void _handleMagnetometerEvent(MagnetometerEvent event) {
    try {
      // Apply low-pass filter to raw data
      if (_filteredX == 0.0 && _filteredY == 0.0 && _filteredZ == 0.0) {
        // Initialize filter
        _filteredX = event.x;
        _filteredY = event.y;
        _filteredZ = event.z;
      } else {
        // Apply filter
        _filteredX = _alpha * _filteredX + (1 - _alpha) * event.x;
        _filteredY = _alpha * _filteredY + (1 - _alpha) * event.y;
        _filteredZ = _alpha * _filteredZ + (1 - _alpha) * event.z;
      }

      // Add to calibration samples if calibrating
      if (_isCalibrating &&
          _calibrationSamples.length < _maxCalibrationSamples) {
        _calibrationSamples.add(event);
        _updateCalibrationQuality();
      }

      // Apply calibration if available
      double calibratedX, calibratedY, calibratedZ;
      if (_isCalibrated) {
        calibratedX = (event.x - _offsetX) * _scaleX;
        calibratedY = (event.y - _offsetY) * _scaleY;
        calibratedZ = (event.z - _offsetZ) * _scaleZ;
      } else {
        calibratedX = event.x;
        calibratedY = event.y;
        calibratedZ = event.z;
      }

      // Calculate magnetic field strength
      _magneticFieldStrength = math.sqrt(calibratedX * calibratedX +
          calibratedY * calibratedY +
          calibratedZ * calibratedZ);

      // Assess magnetic environment
      _assessMagneticEnvironment();

      // Create reading
      final reading = MagnetometerReading(
        rawX: event.x,
        rawY: event.y,
        rawZ: event.z,
        filteredX: _filteredX,
        filteredY: _filteredY,
        filteredZ: _filteredZ,
        calibratedX: calibratedX,
        calibratedY: calibratedY,
        calibratedZ: calibratedZ,
        magneticFieldStrength: _magneticFieldStrength,
        timestamp: DateTime.now(),
        isCalibrated: _isCalibrated,
        calibrationQuality: _calibrationQuality,
        magneticEnvironment: _magneticEnvironment,
      );

      _readingController?.add(reading);
    } catch (e) {
      debugPrint('🧲 Error processing magnetometer event: $e');
    }
  }

  void _handleMagnetometerError(Object error) {
    debugPrint('🧲 Magnetometer error: $error');
  }

  void _calculateCalibration() {
    if (_calibrationSamples.isEmpty) return;

    // Calculate hard iron offsets (center of sphere)
    double minX = _calibrationSamples.first.x;
    double maxX = _calibrationSamples.first.x;
    double minY = _calibrationSamples.first.y;
    double maxY = _calibrationSamples.first.y;
    double minZ = _calibrationSamples.first.z;
    double maxZ = _calibrationSamples.first.z;

    for (final sample in _calibrationSamples) {
      minX = math.min(minX, sample.x);
      maxX = math.max(maxX, sample.x);
      minY = math.min(minY, sample.y);
      maxY = math.max(maxY, sample.y);
      minZ = math.min(minZ, sample.z);
      maxZ = math.max(maxZ, sample.z);
    }

    _offsetX = (minX + maxX) / 2;
    _offsetY = (minY + maxY) / 2;
    _offsetZ = (minZ + maxZ) / 2;

    // Calculate soft iron scaling (ellipsoid to sphere correction)
    final double rangeX = maxX - minX;
    final double rangeY = maxY - minY;
    final double rangeZ = maxZ - minZ;

    final double avgRange = (rangeX + rangeY + rangeZ) / 3;

    _scaleX = avgRange / rangeX;
    _scaleY = avgRange / rangeY;
    _scaleZ = avgRange / rangeZ;

    debugPrint('🧲 Calibration calculated:');
    debugPrint(
        '  Offsets: X=${_offsetX.toStringAsFixed(2)}, Y=${_offsetY.toStringAsFixed(2)}, Z=${_offsetZ.toStringAsFixed(2)}');
    debugPrint(
        '  Scales: X=${_scaleX.toStringAsFixed(3)}, Y=${_scaleY.toStringAsFixed(3)}, Z=${_scaleZ.toStringAsFixed(3)}');
  }

  void _updateCalibrationQuality() {
    final int sampleCount = _calibrationSamples.length;

    if (sampleCount < 20) {
      _calibrationQuality = CalibrationQuality.poor;
    } else if (sampleCount < 50) {
      _calibrationQuality = CalibrationQuality.fair;
    } else if (sampleCount < 80) {
      _calibrationQuality = CalibrationQuality.good;
    } else {
      _calibrationQuality = CalibrationQuality.excellent;
    }

    _notifyCalibrationStatus();
  }

  void _assessMagneticEnvironment() {
    // Earth's magnetic field is typically 25-65 µT
    if (_magneticFieldStrength < 20) {
      _magneticEnvironment = MagneticEnvironment.weak;
    } else if (_magneticFieldStrength > 100) {
      _magneticEnvironment = MagneticEnvironment.interference;
    } else if (_magneticFieldStrength >= 25 && _magneticFieldStrength <= 65) {
      _magneticEnvironment = MagneticEnvironment.normal;
    } else {
      _magneticEnvironment = MagneticEnvironment.moderate;
    }
  }

  void _notifyCalibrationStatus() {
    final status = CalibrationStatus(
      isCalibrating: _isCalibrating,
      isCalibrated: _isCalibrated,
      quality: _calibrationQuality,
      sampleCount: _calibrationSamples.length,
      maxSamples: _maxCalibrationSamples,
      minSamples: _minCalibrationSamples,
    );

    _calibrationController?.add(status);
  }

  /// Dispose of resources
  void dispose() {
    stop();
  }
}

/// Magnetometer reading with raw, filtered, and calibrated data
class MagnetometerReading {
  const MagnetometerReading({
    required this.rawX,
    required this.rawY,
    required this.rawZ,
    required this.filteredX,
    required this.filteredY,
    required this.filteredZ,
    required this.calibratedX,
    required this.calibratedY,
    required this.calibratedZ,
    required this.magneticFieldStrength,
    required this.timestamp,
    required this.isCalibrated,
    required this.calibrationQuality,
    required this.magneticEnvironment,
  });

  final double rawX, rawY, rawZ;
  final double filteredX, filteredY, filteredZ;
  final double calibratedX, calibratedY, calibratedZ;
  final double magneticFieldStrength;
  final DateTime timestamp;
  final bool isCalibrated;
  final CalibrationQuality calibrationQuality;
  final MagneticEnvironment magneticEnvironment;

  /// Calculate heading from calibrated magnetometer data
  double get heading {
    // Calculate heading from X and Y components
    double heading = math.atan2(calibratedY, calibratedX) * (180 / math.pi);

    // Normalize to 0-360 degrees
    if (heading < 0) heading += 360;

    return heading;
  }
}

/// Calibration status information
class CalibrationStatus {
  const CalibrationStatus({
    required this.isCalibrating,
    required this.isCalibrated,
    required this.quality,
    required this.sampleCount,
    required this.maxSamples,
    required this.minSamples,
  });

  final bool isCalibrating;
  final bool isCalibrated;
  final CalibrationQuality quality;
  final int sampleCount;
  final int maxSamples;
  final int minSamples;

  double get progress => sampleCount / maxSamples;
  bool get hasMinimumSamples => sampleCount >= minSamples;
}

/// Quality levels for magnetometer calibration
enum CalibrationQuality {
  poor,
  fair,
  good,
  excellent;

  String get description {
    switch (this) {
      case CalibrationQuality.poor:
        return 'Poor';
      case CalibrationQuality.fair:
        return 'Fair';
      case CalibrationQuality.good:
        return 'Good';
      case CalibrationQuality.excellent:
        return 'Excellent';
    }
  }
}

/// Magnetic environment assessment
enum MagneticEnvironment {
  unknown,
  normal,
  weak,
  moderate,
  interference;

  String get description {
    switch (this) {
      case MagneticEnvironment.unknown:
        return 'Unknown';
      case MagneticEnvironment.normal:
        return 'Normal';
      case MagneticEnvironment.weak:
        return 'Weak Field';
      case MagneticEnvironment.moderate:
        return 'Moderate';
      case MagneticEnvironment.interference:
        return 'Interference';
    }
  }

  bool get isGoodForCompass =>
      this == MagneticEnvironment.normal ||
      this == MagneticEnvironment.moderate;
}
