import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Comprehensive accelerometer service with motion detection and activity recognition
/// Provides motion analysis, activity classification, and device orientation
class AccelerometerService {
  AccelerometerService();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamController<AccelerometerReading>? _readingController;
  StreamController<MotionEvent>? _motionController;
  StreamController<ActivityEvent>? _activityController;

  // Filtering and smoothing
  static const double _alpha = 0.3; // Low-pass filter coefficient (lower = more responsive)
  double _filteredX = 0.0;
  double _filteredY = 0.0;
  double _filteredZ = 0.0;

  // Gravity estimation (for motion detection)
  double _gravityX = 0.0;
  double _gravityY = 0.0;
  double _gravityZ = 0.0;
  static const double _gravityAlpha = 0.6; // Gravity filter coefficient (lower = more responsive)

  // Motion detection
  static const double _motionThreshold = 2.0; // m/s²
  static const double _stillThreshold = 0.5; // m/s²
  bool _isInMotion = false;
  DateTime _lastMotionTime = DateTime.now();
  DateTime _lastStillTime = DateTime.now();

  // Activity recognition
  final List<double> _magnitudeHistory = <double>[];
  static const int _historySize = 50; // ~2.5 seconds at 20Hz
  ActivityType _currentActivity = ActivityType.stationary;
  double _activityConfidence = 0.0;
  Timer? _activityAnalysisTimer;

  // Step detection
  int _stepCount = 0;
  double _lastStepMagnitude = 0.0;
  DateTime _lastStepTime = DateTime.now();
  static const double _stepThreshold = 12.0; // m/s²
  static const Duration _minStepInterval = Duration(milliseconds: 300);

  // Device orientation
  DeviceOrientation _deviceOrientation = DeviceOrientation.unknown;

  /// Stream of accelerometer readings
  Stream<AccelerometerReading> get readingStream {
    _readingController ??= StreamController<AccelerometerReading>.broadcast();
    return _readingController!.stream;
  }

  /// Stream of motion events
  Stream<MotionEvent> get motionStream {
    _motionController ??= StreamController<MotionEvent>.broadcast();
    return _motionController!.stream;
  }

  /// Stream of activity events
  Stream<ActivityEvent> get activityStream {
    _activityController ??= StreamController<ActivityEvent>.broadcast();
    return _activityController!.stream;
  }

  /// Current motion state
  bool get isInMotion => _isInMotion;

  /// Current activity type
  ActivityType get currentActivity => _currentActivity;

  /// Current activity confidence (0.0 to 1.0)
  double get activityConfidence => _activityConfidence;

  /// Current step count
  int get stepCount => _stepCount;

  /// Current device orientation
  DeviceOrientation get deviceOrientation => _deviceOrientation;

  /// Time since last motion detected
  Duration get timeSinceLastMotion =>
      DateTime.now().difference(_lastMotionTime);

  /// Time since last still period
  Duration get timeSinceLastStill => DateTime.now().difference(_lastStillTime);

  /// Start accelerometer service
  Future<void> start() async {
    try {
      await stop(); // Ensure clean start

      _readingController ??= StreamController<AccelerometerReading>.broadcast();
      _motionController ??= StreamController<MotionEvent>.broadcast();
      _activityController ??= StreamController<ActivityEvent>.broadcast();

      debugPrint('📱 Starting accelerometer service...');

      // Start accelerometer stream
      _accelerometerSubscription = accelerometerEventStream().listen(
        _handleAccelerometerEvent,
        onError: _handleAccelerometerError,
        onDone: () {
          debugPrint('📱 Accelerometer stream completed');
        },
      );

      // Start periodic activity analysis
      _activityAnalysisTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _analyzeActivity(),
      );

      debugPrint('📱 Accelerometer service started');
    } catch (e) {
      debugPrint('📱 Error starting accelerometer service: $e');
      rethrow;
    }
  }

  /// Stop accelerometer service
  Future<void> stop() async {
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;

    _activityAnalysisTimer?.cancel();
    _activityAnalysisTimer = null;

    await _readingController?.close();
    _readingController = null;

    await _motionController?.close();
    _motionController = null;

    await _activityController?.close();
    _activityController = null;

    debugPrint('📱 Accelerometer service stopped');
  }

  /// Reset step counter
  void resetStepCount() {
    _stepCount = 0;
    debugPrint('📱 Step count reset');
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    try {
      // Apply low-pass filter to raw data
      if (_filteredX == 0.0 && _filteredY == 0.0 && _filteredZ == 0.0) {
        // Initialize filter
        _filteredX = event.x;
        _filteredY = event.y;
        _filteredZ = event.z;
        _gravityX = event.x;
        _gravityY = event.y;
        _gravityZ = event.z;
      } else {
        // Apply filter
        _filteredX = _alpha * _filteredX + (1 - _alpha) * event.x;
        _filteredY = _alpha * _filteredY + (1 - _alpha) * event.y;
        _filteredZ = _alpha * _filteredZ + (1 - _alpha) * event.z;

        // Estimate gravity (very low-pass filter)
        _gravityX = _gravityAlpha * _gravityX + (1 - _gravityAlpha) * event.x;
        _gravityY = _gravityAlpha * _gravityY + (1 - _gravityAlpha) * event.y;
        _gravityZ = _gravityAlpha * _gravityZ + (1 - _gravityAlpha) * event.z;
      }

      // Calculate linear acceleration (remove gravity)
      final double linearX = event.x - _gravityX;
      final double linearY = event.y - _gravityY;
      final double linearZ = event.z - _gravityZ;

      // Calculate total acceleration magnitude
      final double totalMagnitude =
          math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      // Calculate linear acceleration magnitude
      final double linearMagnitude =
          math.sqrt(linearX * linearX + linearY * linearY + linearZ * linearZ);

      // Update motion detection
      _updateMotionDetection(linearMagnitude);

      // Update device orientation
      _updateDeviceOrientation(event.x, event.y, event.z);

      // Add to magnitude history for activity recognition
      _magnitudeHistory.add(totalMagnitude);
      if (_magnitudeHistory.length > _historySize) {
        _magnitudeHistory.removeAt(0);
      }

      // Step detection
      _detectSteps(totalMagnitude);

      // Create reading
      final reading = AccelerometerReading(
        rawX: event.x,
        rawY: event.y,
        rawZ: event.z,
        filteredX: _filteredX,
        filteredY: _filteredY,
        filteredZ: _filteredZ,
        linearX: linearX,
        linearY: linearY,
        linearZ: linearZ,
        gravityX: _gravityX,
        gravityY: _gravityY,
        gravityZ: _gravityZ,
        totalMagnitude: totalMagnitude,
        linearMagnitude: linearMagnitude,
        timestamp: DateTime.now(),
        isInMotion: _isInMotion,
        deviceOrientation: _deviceOrientation,
        stepCount: _stepCount,
      );

      _readingController?.add(reading);
    } catch (e) {
      debugPrint('📱 Error processing accelerometer event: $e');
    }
  }

  void _handleAccelerometerError(Object error) {
    debugPrint('📱 Accelerometer error: $error');
  }

  void _updateMotionDetection(double linearMagnitude) {
    if (linearMagnitude > _motionThreshold) {
      if (!_isInMotion) {
        _isInMotion = true;
        _lastMotionTime = DateTime.now();

        final motionEvent = MotionEvent(
          type: MotionType.started,
          magnitude: linearMagnitude,
          timestamp: DateTime.now(),
        );
        _motionController?.add(motionEvent);

        debugPrint(
            '📱 Motion started (magnitude: ${linearMagnitude.toStringAsFixed(2)})');
      } else {
        _lastMotionTime = DateTime.now();
      }
    } else if (linearMagnitude < _stillThreshold) {
      if (_isInMotion) {
        _isInMotion = false;
        _lastStillTime = DateTime.now();

        final motionEvent = MotionEvent(
          type: MotionType.stopped,
          magnitude: linearMagnitude,
          timestamp: DateTime.now(),
        );
        _motionController?.add(motionEvent);

        debugPrint(
            '📱 Motion stopped (magnitude: ${linearMagnitude.toStringAsFixed(2)})');
      }
    }
  }

  void _updateDeviceOrientation(double x, double y, double z) {
    // Determine device orientation based on gravity vector
    final double absX = x.abs();
    final double absY = y.abs();
    final double absZ = z.abs();

    DeviceOrientation newOrientation;

    // Only consider device "flat" if Z is significantly dominant (1.5x threshold)
    // This prevents false flat detection when holding phone at an angle (e.g., camera use)
    // Typical camera-holding angle is 45-60° from horizontal, where Z is significant but not dominant
    final bool isTrulyFlat = absZ > absX * 1.5 && absZ > absY * 1.5;

    if (isTrulyFlat) {
      // Device is flat (lying on a surface or held very horizontally)
      newOrientation =
          z > 0 ? DeviceOrientation.faceDown : DeviceOrientation.faceUp;
    } else if (absX > absY) {
      // Device is in landscape
      newOrientation = x > 0
          ? DeviceOrientation.landscapeLeft
          : DeviceOrientation.landscapeRight;
    } else {
      // Device is in portrait
      newOrientation =
          y > 0 ? DeviceOrientation.portraitDown : DeviceOrientation.portraitUp;
    }

    if (newOrientation != _deviceOrientation) {
      _deviceOrientation = newOrientation;
      debugPrint(
          '📱 Device orientation changed to: ${_deviceOrientation.name}');
    }
  }

  void _detectSteps(double magnitude) {
    final now = DateTime.now();

    // Simple step detection using magnitude peaks
    if (magnitude > _stepThreshold &&
        magnitude > _lastStepMagnitude + 2.0 &&
        now.difference(_lastStepTime) > _minStepInterval) {
      _stepCount++;
      _lastStepTime = now;
      _lastStepMagnitude = magnitude;

      debugPrint(
          '📱 Step detected (count: $_stepCount, magnitude: ${magnitude.toStringAsFixed(2)})');
    }

    _lastStepMagnitude = magnitude;
  }

  void _analyzeActivity() {
    if (_magnitudeHistory.length < 20) return; // Need minimum data

    // Calculate statistics from magnitude history
    final double mean =
        _magnitudeHistory.reduce((a, b) => a + b) / _magnitudeHistory.length;
    final double variance = _magnitudeHistory
            .map((x) => math.pow(x - mean, 2))
            .reduce((a, b) => a + b) /
        _magnitudeHistory.length;
    final double stdDev = math.sqrt(variance);

    // Simple activity classification based on variance and mean
    ActivityType newActivity;
    double confidence;

    if (stdDev < 0.5 && mean < 10.5) {
      // Low variance, low mean = stationary
      newActivity = ActivityType.stationary;
      confidence = math.min(1.0, (1.0 - stdDev) * 0.8 + 0.2);
    } else if (stdDev < 2.0 && mean < 12.0) {
      // Moderate variance, moderate mean = walking
      newActivity = ActivityType.walking;
      confidence = math.min(1.0, stdDev * 0.4 + 0.3);
    } else if (stdDev > 2.0 && mean > 11.0) {
      // High variance, high mean = running
      newActivity = ActivityType.running;
      confidence = math.min(1.0, stdDev * 0.2 + 0.5);
    } else {
      // Uncertain activity
      newActivity = ActivityType.unknown;
      confidence = 0.3;
    }

    // Update activity if changed significantly
    if (newActivity != _currentActivity ||
        (_activityConfidence - confidence).abs() > 0.2) {
      final previousActivity = _currentActivity;
      _currentActivity = newActivity;
      _activityConfidence = confidence;

      final activityEvent = ActivityEvent(
        activity: newActivity,
        previousActivity: previousActivity,
        confidence: confidence,
        timestamp: DateTime.now(),
        stepCount: _stepCount,
      );

      _activityController?.add(activityEvent);

      debugPrint(
          '📱 Activity changed: ${newActivity.name} (confidence: ${(confidence * 100).round()}%)');
    }
  }

  /// Dispose of resources
  void dispose() {
    stop();
  }
}

/// Accelerometer reading with comprehensive motion data
class AccelerometerReading {
  const AccelerometerReading({
    required this.rawX,
    required this.rawY,
    required this.rawZ,
    required this.filteredX,
    required this.filteredY,
    required this.filteredZ,
    required this.linearX,
    required this.linearY,
    required this.linearZ,
    required this.gravityX,
    required this.gravityY,
    required this.gravityZ,
    required this.totalMagnitude,
    required this.linearMagnitude,
    required this.timestamp,
    required this.isInMotion,
    required this.deviceOrientation,
    required this.stepCount,
  });

  final double rawX, rawY, rawZ;
  final double filteredX, filteredY, filteredZ;
  final double linearX, linearY, linearZ;
  final double gravityX, gravityY, gravityZ;
  final double totalMagnitude;
  final double linearMagnitude;
  final DateTime timestamp;
  final bool isInMotion;
  final DeviceOrientation deviceOrientation;
  final int stepCount;
}

/// Motion event information
class MotionEvent {
  const MotionEvent({
    required this.type,
    required this.magnitude,
    required this.timestamp,
  });

  final MotionType type;
  final double magnitude;
  final DateTime timestamp;
}

/// Activity event information
class ActivityEvent {
  const ActivityEvent({
    required this.activity,
    required this.previousActivity,
    required this.confidence,
    required this.timestamp,
    required this.stepCount,
  });

  final ActivityType activity;
  final ActivityType previousActivity;
  final double confidence;
  final DateTime timestamp;
  final int stepCount;
}

/// Types of motion events
enum MotionType {
  started,
  stopped;

  String get description {
    switch (this) {
      case MotionType.started:
        return 'Motion Started';
      case MotionType.stopped:
        return 'Motion Stopped';
    }
  }
}

/// Types of activities that can be recognized
enum ActivityType {
  stationary,
  walking,
  running,
  unknown;

  String get description {
    switch (this) {
      case ActivityType.stationary:
        return 'Stationary';
      case ActivityType.walking:
        return 'Walking';
      case ActivityType.running:
        return 'Running';
      case ActivityType.unknown:
        return 'Unknown';
    }
  }
}

/// Device orientation based on accelerometer
enum DeviceOrientation {
  unknown,
  portraitUp,
  portraitDown,
  landscapeLeft,
  landscapeRight,
  faceUp,
  faceDown;

  String get description {
    switch (this) {
      case DeviceOrientation.unknown:
        return 'Unknown';
      case DeviceOrientation.portraitUp:
        return 'Portrait Up';
      case DeviceOrientation.portraitDown:
        return 'Portrait Down';
      case DeviceOrientation.landscapeLeft:
        return 'Landscape Left';
      case DeviceOrientation.landscapeRight:
        return 'Landscape Right';
      case DeviceOrientation.faceUp:
        return 'Face Up';
      case DeviceOrientation.faceDown:
        return 'Face Down';
    }
  }

  bool get isPortrait =>
      this == DeviceOrientation.portraitUp ||
      this == DeviceOrientation.portraitDown;
  bool get isLandscape =>
      this == DeviceOrientation.landscapeLeft ||
      this == DeviceOrientation.landscapeRight;
  bool get isFlat =>
      this == DeviceOrientation.faceUp || this == DeviceOrientation.faceDown;
}
