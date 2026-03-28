import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';

/// Compass service that provides device heading using flutter_compass package
/// with GPS heading fallback for better accuracy
class CompassService {
  CompassService();

  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamController<double>? _headingController;

  // Calibration and filtering
  static const double _alpha = 0.8; // Low-pass filter coefficient
  double _filteredHeading = 0.0;
  bool _isCalibrated = false;

  // GPS fallback
  double? _gpsHeading;
  DateTime? _lastGpsUpdate;
  static const Duration _gpsTimeout = Duration(seconds: 10);

  /// Stream of compass heading in degrees (0-360)
  /// 0 = North, 90 = East, 180 = South, 270 = West
  Stream<double> get headingStream {
    _headingController ??= StreamController<double>.broadcast();
    return _headingController!.stream;
  }

  /// Current heading in degrees
  double get currentHeading => _filteredHeading;

  /// Whether the compass has been calibrated
  bool get isCalibrated => _isCalibrated;

  /// Whether GPS heading is being used as fallback
  bool get isUsingGpsFallback {
    if (_gpsHeading == null || _lastGpsUpdate == null) return false;
    return DateTime.now().difference(_lastGpsUpdate!) < _gpsTimeout;
  }

  /// Start compass service
  Future<void> start() async {
    try {
      await stop(); // Ensure clean start

      _headingController ??= StreamController<double>.broadcast();

      // Check if compass is available
      // debugPrint('🧭 Checking compass availability...');
      final compassEvents = FlutterCompass.events;

      if (compassEvents == null) {
        debugPrint(
            '🧭 ERROR: FlutterCompass.events is null - compass not available on this device');
        throw const CompassServiceException(
          'Compass not available on this device',
          CompassServiceError.sensorNotAvailable,
        );
      }

      // debugPrint(
      //     '🧭 Compass events stream available, starting subscription...');

      // Start flutter_compass stream
      _compassSubscription = compassEvents.listen(
        _handleCompassEvent,
        onError: _handleCompassError,
        onDone: () {
          // debugPrint('🧭 Compass stream completed/closed');
        },
      );

      // debugPrint('🧭 Compass service started using flutter_compass');
      // debugPrint(
      //     '🧭 Compass subscription active: ${_compassSubscription != null}');

      // Test if we get initial events
      Timer(const Duration(seconds: 3), () {
        if (!_isCalibrated) {
          // debugPrint('🧭 WARNING: No compass events received after 3 seconds');
        }
      });
    } catch (e) {
      debugPrint('🧭 Error starting compass service: $e');
      rethrow;
    }
  }

  /// Stop compass service
  Future<void> stop() async {
    await _compassSubscription?.cancel();
    _compassSubscription = null;

    await _headingController?.close();
    _headingController = null;

    // debugPrint('🧭 Compass service stopped');
  }

  /// Update GPS heading for fallback
  void updateGpsHeading(double? heading) {
    if (heading != null && heading >= 0 && heading <= 360) {
      _gpsHeading = heading;
      _lastGpsUpdate = DateTime.now();

      // If compass is not working well, use GPS heading
      if (!_isCalibrated || _shouldUseGpsFallback()) {
        _updateHeading(heading);
      }
    }
  }

  /// Calibrate compass (reset calibration state)
  void calibrate() {
    _isCalibrated = false;
    // debugPrint('🧭 Compass calibration reset');
  }

  void _handleCompassEvent(CompassEvent event) {
    try {
      final double? heading = event.heading;
      if (heading == null) {
        // debugPrint('🧭 Received null heading from compass');
        return;
      }

      // debugPrint(
      //     '🧭 Raw heading from flutter_compass: ${heading.toStringAsFixed(1)}°');

      // Apply low-pass filter for smoothing
      double filteredHeading;
      if (_isCalibrated) {
        filteredHeading = _applyLowPassFilter(heading);
        // debugPrint(
        //     '🧭 Filtered heading: ${filteredHeading.toStringAsFixed(1)}°');
      } else {
        _filteredHeading = heading;
        filteredHeading = heading;
        _isCalibrated = true;
        // debugPrint(
        //     '🧭 Compass calibrated with initial heading: ${filteredHeading.toStringAsFixed(1)}°');
      }

      _updateHeading(filteredHeading);
    } catch (e) {
      // debugPrint('🧭 Error processing compass event: $e');
    }
  }

  void _handleCompassError(Object error) {
    // debugPrint('🧭 Compass error: $error');

    // Fall back to GPS heading if available
    if (_gpsHeading != null && isUsingGpsFallback) {
      _updateHeading(_gpsHeading!);
    }
  }

  double _applyLowPassFilter(double newHeading) {
    // Handle angle wrapping for smooth filtering
    double diff = newHeading - _filteredHeading;

    // Normalize difference to -180 to 180
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;

    // Apply low-pass filter
    _filteredHeading += _alpha * diff;

    // Normalize result to 0-360
    while (_filteredHeading < 0) _filteredHeading += 360;
    while (_filteredHeading >= 360) _filteredHeading -= 360;

    return _filteredHeading;
  }

  bool _shouldUseGpsFallback() =>
      // Use GPS fallback if compass seems unreliable
      // This could be enhanced with more sophisticated detection
      false;

  void _updateHeading(double heading) {
    _filteredHeading = heading;
    _headingController?.add(heading);
  }

  /// Get compass accuracy description
  String get accuracyDescription {
    if (!_isCalibrated) {
      return 'Calibrating...';
    } else if (isUsingGpsFallback) {
      return 'GPS Heading';
    } else {
      return 'Compass';
    }
  }

  /// Dispose of resources
  void dispose() {
    stop();
  }
}

/// Exception thrown by compass service
class CompassServiceException implements Exception {
  const CompassServiceException(this.message,
      [this.type = CompassServiceError.unknown]);

  final String message;
  final CompassServiceError type;

  @override
  String toString() => 'CompassServiceException: $message';
}

/// Types of compass service errors
enum CompassServiceError {
  sensorNotAvailable,
  permissionDenied,
  calibrationRequired,
  unknown,
}
