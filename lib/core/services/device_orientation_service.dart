import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Comprehensive device orientation service
/// Handles screen rotation, sensor orientation, and provides orientation-aware functionality
class DeviceOrientationService {
  DeviceOrientationService();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamController<OrientationReading>? _orientationController;
  StreamController<RotationEvent>? _rotationController;

  // Device information
  String _deviceModel = '';
  String _devicePlatform = '';
  final bool _supportsAutoRotation = true;

  // Current orientation state
  DeviceOrientation _currentOrientation = DeviceOrientation.portraitUp;
  DeviceOrientation _previousOrientation = DeviceOrientation.portraitUp;
  ScreenOrientation _screenOrientation = ScreenOrientation.portrait;

  // Sensor-based orientation detection
  double _gravityX = 0.0;
  double _gravityY = 0.0;
  double _gravityZ = 0.0;
  static const double _gravityAlpha = 0.8;
  static const double _orientationThreshold = 6.0; // m/s²

  // Rotation detection
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  double _rotationZ = 0.0;
  static const double _rotationThreshold = 1.0; // rad/s
  bool _isRotating = false;

  // Orientation stability
  static const Duration _stabilityDelay = Duration(milliseconds: 500);
  Timer? _stabilityTimer;

  // Auto-rotation settings
  bool _autoRotationEnabled = true;
  Set<DeviceOrientation> _allowedOrientations = {
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  };

  /// Stream of orientation readings
  Stream<OrientationReading> get orientationStream {
    _orientationController ??= StreamController<OrientationReading>.broadcast();
    return _orientationController!.stream;
  }

  /// Stream of rotation events
  Stream<RotationEvent> get rotationStream {
    _rotationController ??= StreamController<RotationEvent>.broadcast();
    return _rotationController!.stream;
  }

  /// Current device orientation
  DeviceOrientation get currentOrientation => _currentOrientation;

  /// Current screen orientation
  ScreenOrientation get screenOrientation => _screenOrientation;

  /// Whether auto-rotation is enabled
  bool get autoRotationEnabled => _autoRotationEnabled;

  /// Allowed orientations for auto-rotation
  Set<DeviceOrientation> get allowedOrientations =>
      Set.from(_allowedOrientations);

  /// Whether the device is currently rotating
  bool get isRotating => _isRotating;

  /// Device model information
  String get deviceModel => _deviceModel;

  /// Whether the device supports auto-rotation
  bool get supportsAutoRotation => _supportsAutoRotation;

  /// Start device orientation service
  Future<void> start() async {
    try {
      await stop(); // Ensure clean start

      _orientationController ??=
          StreamController<OrientationReading>.broadcast();
      _rotationController ??= StreamController<RotationEvent>.broadcast();

      debugPrint('📱 Starting device orientation service...');

      // Get device information
      await _getDeviceInfo();

      // Start sensor streams
      _accelerometerSubscription = accelerometerEventStream().listen(
        _handleAccelerometerEvent,
        onError: _handleAccelerometerError,
      );

      _gyroscopeSubscription = gyroscopeEventStream().listen(
        _handleGyroscopeEvent,
        onError: _handleGyroscopeError,
      );

      // Get initial orientation
      await _updateScreenOrientation();

      debugPrint('📱 Device orientation service started');
      debugPrint('  Device: $_deviceModel ($_devicePlatform)');
      debugPrint('  Auto-rotation support: $_supportsAutoRotation');
    } catch (e) {
      debugPrint('📱 Error starting device orientation service: $e');
      rethrow;
    }
  }

  /// Stop device orientation service
  Future<void> stop() async {
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;

    await _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;

    _stabilityTimer?.cancel();
    _stabilityTimer = null;

    await _orientationController?.close();
    _orientationController = null;

    await _rotationController?.close();
    _rotationController = null;

    debugPrint('📱 Device orientation service stopped');
  }

  /// Enable or disable auto-rotation
  void setAutoRotationEnabled({required bool enabled}) {
    _autoRotationEnabled = enabled;
    debugPrint('📱 Auto-rotation ${enabled ? 'enabled' : 'disabled'}');

    if (!enabled) {
      // Lock to current orientation
      _lockToOrientation(_currentOrientation);
    } else {
      // Enable all allowed orientations
      _setAllowedOrientations(_allowedOrientations);
    }
  }

  /// Set allowed orientations for auto-rotation
  void setAllowedOrientations(Set<DeviceOrientation> orientations) {
    _allowedOrientations = Set.from(orientations);

    if (_autoRotationEnabled) {
      _setAllowedOrientations(_allowedOrientations);
    }

    debugPrint(
        '📱 Allowed orientations updated: ${orientations.map((o) => o.name).join(', ')}');
  }

  /// Lock device to specific orientation
  Future<void> lockToOrientation(DeviceOrientation orientation) async {
    _autoRotationEnabled = false;
    await _lockToOrientation(orientation);
    debugPrint('📱 Locked to orientation: ${orientation.name}');
  }

  /// Unlock device orientation (enable auto-rotation)
  Future<void> unlockOrientation() async {
    _autoRotationEnabled = true;
    await _setAllowedOrientations(_allowedOrientations);
    debugPrint('📱 Orientation unlocked');
  }

  /// Force orientation update
  Future<void> forceOrientationUpdate() async {
    await _updateScreenOrientation();
  }

  Future<void> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
        _devicePlatform = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceModel = iosInfo.model;
        _devicePlatform = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      } else {
        _deviceModel = 'Unknown';
        _devicePlatform = Platform.operatingSystem;
      }
    } catch (e) {
      debugPrint('📱 Error getting device info: $e');
      _deviceModel = 'Unknown';
      _devicePlatform = Platform.operatingSystem;
    }
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    try {
      // Update gravity estimation with low-pass filter
      _gravityX = _gravityAlpha * _gravityX + (1 - _gravityAlpha) * event.x;
      _gravityY = _gravityAlpha * _gravityY + (1 - _gravityAlpha) * event.y;
      _gravityZ = _gravityAlpha * _gravityZ + (1 - _gravityAlpha) * event.z;

      // Determine orientation from gravity vector
      final newOrientation =
          _calculateOrientationFromGravity(_gravityX, _gravityY, _gravityZ);

      // Update orientation if changed and stable
      if (newOrientation != _currentOrientation) {
        _handleOrientationChange(newOrientation);
      }

      // Create orientation reading
      final reading = OrientationReading(
        deviceOrientation: _currentOrientation,
        screenOrientation: _screenOrientation,
        gravityX: _gravityX,
        gravityY: _gravityY,
        gravityZ: _gravityZ,
        isRotating: _isRotating,
        timestamp: DateTime.now(),
        autoRotationEnabled: _autoRotationEnabled,
      );

      _orientationController?.add(reading);
    } catch (e) {
      debugPrint('📱 Error processing accelerometer event: $e');
    }
  }

  void _handleGyroscopeEvent(GyroscopeEvent event) {
    try {
      _rotationX = event.x;
      _rotationY = event.y;
      _rotationZ = event.z;

      // Calculate total rotation magnitude
      final rotationMagnitude = math.sqrt(_rotationX * _rotationX +
          _rotationY * _rotationY +
          _rotationZ * _rotationZ);

      final wasRotating = _isRotating;
      _isRotating = rotationMagnitude > _rotationThreshold;

      // Track rotation state for events

      // Emit rotation events
      if (_isRotating != wasRotating) {
        final rotationEvent = RotationEvent(
          type: _isRotating ? RotationType.started : RotationType.stopped,
          magnitude: rotationMagnitude,
          rotationX: _rotationX,
          rotationY: _rotationY,
          rotationZ: _rotationZ,
          timestamp: DateTime.now(),
        );

        _rotationController?.add(rotationEvent);
      }
    } catch (e) {
      debugPrint('📱 Error processing gyroscope event: $e');
    }
  }

  void _handleAccelerometerError(Object error) {
    debugPrint('📱 Accelerometer error: $error');
  }

  void _handleGyroscopeError(Object error) {
    debugPrint('📱 Gyroscope error: $error');
  }

  DeviceOrientation _calculateOrientationFromGravity(
      double x, double y, double z) {
    final double absX = x.abs();
    final double absY = y.abs();
    final double absZ = z.abs();

    // Check if device is flat (face up/down)
    if (absZ > _orientationThreshold && absZ > absX && absZ > absY) {
      return z > 0 ? DeviceOrientation.faceDown : DeviceOrientation.faceUp;
    }

    // Determine portrait/landscape orientation
    if (absX > absY) {
      // Landscape orientation
      return x > 0
          ? DeviceOrientation.landscapeLeft
          : DeviceOrientation.landscapeRight;
    } else {
      // Portrait orientation
      return y > 0
          ? DeviceOrientation.portraitDown
          : DeviceOrientation.portraitUp;
    }
  }

  void _handleOrientationChange(DeviceOrientation newOrientation) {
    // Cancel any pending stability timer
    _stabilityTimer?.cancel();

    // Start stability timer to prevent rapid orientation changes
    _stabilityTimer = Timer(_stabilityDelay, () {
      if (newOrientation != _currentOrientation) {
        _previousOrientation = _currentOrientation;
        _currentOrientation = newOrientation;
        debugPrint(
            '📱 Orientation changed: ${_previousOrientation.name} → ${newOrientation.name}');

        // Update screen orientation if auto-rotation is enabled
        if (_autoRotationEnabled &&
            _allowedOrientations.contains(newOrientation)) {
          _updateScreenOrientationForDevice(newOrientation);
        }
      }
    });
  }

  Future<void> _updateScreenOrientation() async {
    try {
      // This would typically query the system for current screen orientation
      // For now, we'll derive it from device orientation
      _screenOrientation =
          _deviceOrientationToScreenOrientation(_currentOrientation);
    } catch (e) {
      debugPrint('📱 Error updating screen orientation: $e');
    }
  }

  Future<void> _updateScreenOrientationForDevice(
      DeviceOrientation deviceOrientation) async {
    final screenOrientation =
        _deviceOrientationToScreenOrientation(deviceOrientation);

    if (screenOrientation != _screenOrientation) {
      _screenOrientation = screenOrientation;
      debugPrint('📱 Screen orientation updated: ${screenOrientation.name}');
    }
  }

  ScreenOrientation _deviceOrientationToScreenOrientation(
      DeviceOrientation deviceOrientation) {
    switch (deviceOrientation) {
      case DeviceOrientation.portraitUp:
      case DeviceOrientation.portraitDown:
        return ScreenOrientation.portrait;
      case DeviceOrientation.landscapeLeft:
      case DeviceOrientation.landscapeRight:
        return ScreenOrientation.landscape;
      case DeviceOrientation.faceUp:
      case DeviceOrientation.faceDown:
        return _screenOrientation; // Keep current screen orientation
      case DeviceOrientation.unknown:
        return ScreenOrientation.portrait; // Default to portrait
    }
  }

  Future<void> _lockToOrientation(DeviceOrientation orientation) async {
    try {
      // Log the orientation lock request
      debugPrint('📱 Locking to orientation: ${orientation.name}');

      // In a production app, you would implement actual orientation locking here
      // This would typically involve platform-specific code or using a plugin
      // For now, we just track the intended orientation
      _autoRotationEnabled = false;
    } catch (e) {
      debugPrint('📱 Error locking orientation: $e');
    }
  }

  Future<void> _setAllowedOrientations(
      Set<DeviceOrientation> orientations) async {
    try {
      // Log the allowed orientations
      debugPrint(
          '📱 Setting allowed orientations: ${orientations.map((o) => o.name).join(', ')}');

      // In a production app, you would implement actual orientation constraints here
      // For now, we just track the allowed orientations
      _allowedOrientations = Set.from(orientations);
    } catch (e) {
      debugPrint('📱 Error setting allowed orientations: $e');
    }
  }

  /// Get orientation-corrected compass heading
  double getOrientationCorrectedHeading(double magneticHeading) {
    // Adjust compass heading based on device orientation
    switch (_currentOrientation) {
      case DeviceOrientation.portraitUp:
        return magneticHeading;
      case DeviceOrientation.portraitDown:
        return (magneticHeading + 180) % 360;
      case DeviceOrientation.landscapeLeft:
        return (magneticHeading + 90) % 360;
      case DeviceOrientation.landscapeRight:
        return (magneticHeading - 90 + 360) % 360;
      default:
        return magneticHeading; // No correction for face up/down
    }
  }

  /// Check if orientation is suitable for camera use
  bool isOrientationSuitableForCamera() =>
      _currentOrientation != DeviceOrientation.faceDown &&
      _currentOrientation != DeviceOrientation.faceUp &&
      !_isRotating;

  /// Check if orientation is suitable for compass use
  bool isOrientationSuitableForCompass() =>
      _currentOrientation != DeviceOrientation.faceDown && !_isRotating;

  /// Dispose of resources
  void dispose() {
    stop();
  }
}

/// Orientation reading with comprehensive device state
class OrientationReading {
  const OrientationReading({
    required this.deviceOrientation,
    required this.screenOrientation,
    required this.gravityX,
    required this.gravityY,
    required this.gravityZ,
    required this.isRotating,
    required this.timestamp,
    required this.autoRotationEnabled,
  });

  final DeviceOrientation deviceOrientation;
  final ScreenOrientation screenOrientation;
  final double gravityX, gravityY, gravityZ;
  final bool isRotating;
  final DateTime timestamp;
  final bool autoRotationEnabled;

  /// Calculate tilt angle from vertical (0° = upright, 90° = horizontal)
  double get tiltAngle {
    final double totalGravity = math
        .sqrt(gravityX * gravityX + gravityY * gravityY + gravityZ * gravityZ);
    if (totalGravity == 0) return 0.0;

    // Calculate angle from vertical (Z-axis)
    return math.acos(gravityZ.abs() / totalGravity) * (180 / math.pi);
  }
}

/// Rotation event information
class RotationEvent {
  const RotationEvent({
    required this.type,
    required this.magnitude,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
    required this.timestamp,
  });

  final RotationType type;
  final double magnitude;
  final double rotationX, rotationY, rotationZ;
  final DateTime timestamp;
}

/// Device orientation enum (extended from accelerometer service)
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

/// Screen orientation enum
enum ScreenOrientation {
  portrait,
  landscape;

  String get description {
    switch (this) {
      case ScreenOrientation.portrait:
        return 'Portrait';
      case ScreenOrientation.landscape:
        return 'Landscape';
    }
  }
}

/// Types of rotation events
enum RotationType {
  started,
  stopped;

  String get description {
    switch (this) {
      case RotationType.started:
        return 'Rotation Started';
      case RotationType.stopped:
        return 'Rotation Stopped';
    }
  }
}
