import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/services/accelerometer_service.dart';
import 'package:obsession_tracker/core/services/barometric_pressure_service.dart';
import 'package:obsession_tracker/core/services/device_orientation_service.dart'
    as orientation;
import 'package:obsession_tracker/core/services/enhanced_compass_service.dart';
import 'package:obsession_tracker/core/services/magnetometer_service.dart';
import 'package:obsession_tracker/core/services/sensor_permissions_service.dart';
import 'package:permission_handler/permission_handler.dart';

/// Comprehensive sensor fusion service that combines all sensor data
/// Provides unified sensor readings and intelligent sensor management
class SensorFusionService {
  SensorFusionService({
    AccelerometerService? accelerometerService,
    MagnetometerService? magnetometerService,
    BarometricPressureService? pressureService,
    orientation.DeviceOrientationService? orientationService,
    EnhancedCompassService? compassService,
    SensorPermissionsService? permissionsService,
  })  : _accelerometerService = accelerometerService ?? AccelerometerService(),
        _magnetometerService = magnetometerService ?? MagnetometerService(),
        _pressureService = pressureService ?? BarometricPressureService(),
        _orientationService =
            orientationService ?? orientation.DeviceOrientationService(),
        _compassService = compassService ?? EnhancedCompassService(),
        _permissionsService = permissionsService ?? SensorPermissionsService();

  final AccelerometerService _accelerometerService;
  final MagnetometerService _magnetometerService;
  final BarometricPressureService _pressureService;
  final orientation.DeviceOrientationService _orientationService;
  final EnhancedCompassService _compassService;
  final SensorPermissionsService _permissionsService;

  // Sensor subscriptions
  StreamSubscription<AccelerometerReading>? _accelerometerSubscription;
  StreamSubscription<MagnetometerReading>? _magnetometerSubscription;
  StreamSubscription<PressureReading>? _pressureSubscription;
  StreamSubscription<orientation.OrientationReading>? _orientationSubscription;
  StreamSubscription<EnhancedCompassReading>? _compassSubscription;

  // Stream controllers
  StreamController<SensorFusionReading>? _fusionController;
  StreamController<SensorHealthStatus>? _healthController;
  StreamController<SensorCalibrationStatus>? _calibrationController;

  // Current sensor readings
  AccelerometerReading? _lastAccelerometerReading;
  MagnetometerReading? _lastMagnetometerReading;
  PressureReading? _lastPressureReading;
  orientation.OrientationReading? _lastOrientationReading;
  EnhancedCompassReading? _lastCompassReading;

  // Service state
  bool _isActive = false;
  SensorFusionMode _mode = SensorFusionMode.balanced;
  Set<SensorType> _enabledSensors = {};
  final Map<SensorType, SensorStatus> _sensorStatus = {};

  // Health monitoring
  Timer? _healthCheckTimer;
  static const Duration _healthCheckInterval = Duration(seconds: 5);

  /// Stream of fused sensor readings
  Stream<SensorFusionReading> get fusionStream {
    _fusionController ??= StreamController<SensorFusionReading>.broadcast();
    return _fusionController!.stream;
  }

  /// Stream of sensor health status updates
  Stream<SensorHealthStatus> get healthStream {
    _healthController ??= StreamController<SensorHealthStatus>.broadcast();
    return _healthController!.stream;
  }

  /// Stream of sensor calibration status updates
  Stream<SensorCalibrationStatus> get calibrationStream {
    _calibrationController ??=
        StreamController<SensorCalibrationStatus>.broadcast();
    return _calibrationController!.stream;
  }

  /// Current sensor fusion mode
  SensorFusionMode get mode => _mode;

  /// Whether the sensor fusion service is active
  bool get isActive => _isActive;

  /// Currently enabled sensors
  Set<SensorType> get enabledSensors => Set.from(_enabledSensors);

  /// Current sensor status map
  Map<SensorType, SensorStatus> get sensorStatus => Map.from(_sensorStatus);

  /// Start sensor fusion service
  Future<void> start({
    SensorFusionMode mode = SensorFusionMode.balanced,
    Set<SensorType>? enabledSensors,
  }) async {
    try {
      await stop(); // Ensure clean start

      _mode = mode;
      _enabledSensors = enabledSensors ?? _getDefaultEnabledSensors(mode);

      debugPrint('🔄 Starting sensor fusion service...');
      debugPrint('  Mode: ${mode.name}');
      debugPrint(
          '  Enabled sensors: ${_enabledSensors.map((s) => s.name).join(', ')}');

      // Check and request permissions
      await _checkAndRequestPermissions();

      // Initialize stream controllers
      _fusionController ??= StreamController<SensorFusionReading>.broadcast();
      _healthController ??= StreamController<SensorHealthStatus>.broadcast();
      _calibrationController ??=
          StreamController<SensorCalibrationStatus>.broadcast();

      // Start enabled sensor services
      await _startEnabledSensors();

      // Subscribe to sensor streams
      _subscribeToSensorStreams();

      // Start health monitoring
      _startHealthMonitoring();

      _isActive = true;
      debugPrint('🔄 Sensor fusion service started successfully');
    } catch (e) {
      debugPrint('🔄 Error starting sensor fusion service: $e');
      rethrow;
    }
  }

  /// Stop sensor fusion service
  Future<void> stop() async {
    // Cancel subscriptions
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;

    await _magnetometerSubscription?.cancel();
    _magnetometerSubscription = null;

    await _pressureSubscription?.cancel();
    _pressureSubscription = null;

    await _orientationSubscription?.cancel();
    _orientationSubscription = null;

    await _compassSubscription?.cancel();
    _compassSubscription = null;

    // Stop health monitoring
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    // Stop sensor services
    await _accelerometerService.stop();
    await _magnetometerService.stop();
    await _pressureService.stop();
    await _orientationService.stop();
    await _compassService.stop();

    // Close stream controllers
    await _fusionController?.close();
    _fusionController = null;

    await _healthController?.close();
    _healthController = null;

    await _calibrationController?.close();
    _calibrationController = null;

    _isActive = false;
    debugPrint('🔄 Sensor fusion service stopped');
  }

  /// Change sensor fusion mode
  Future<void> setMode(SensorFusionMode newMode) async {
    if (newMode == _mode) return;

    debugPrint(
        '🔄 Changing sensor fusion mode: ${_mode.name} → ${newMode.name}');

    final wasActive = _isActive;
    if (wasActive) {
      await stop();
    }

    _mode = newMode;
    _enabledSensors = _getDefaultEnabledSensors(newMode);

    if (wasActive) {
      await start(mode: newMode);
    }
  }

  /// Enable or disable specific sensors
  Future<void> setSensorEnabled(SensorType sensorType,
      {required bool enabled}) async {
    if (enabled) {
      _enabledSensors.add(sensorType);
    } else {
      _enabledSensors.remove(sensorType);
    }

    debugPrint(
        '🔄 Sensor ${sensorType.name} ${enabled ? 'enabled' : 'disabled'}');

    // Restart service if active to apply changes
    if (_isActive) {
      await start(mode: _mode, enabledSensors: _enabledSensors);
    }
  }

  /// Start calibration for magnetometer
  void startMagnetometerCalibration() {
    if (_enabledSensors.contains(SensorType.magnetometer)) {
      _magnetometerService.startCalibration();
      debugPrint('🔄 Started magnetometer calibration');
    }
  }

  /// Stop magnetometer calibration
  void stopMagnetometerCalibration() {
    if (_enabledSensors.contains(SensorType.magnetometer)) {
      _magnetometerService.stopCalibration();
      debugPrint('🔄 Stopped magnetometer calibration');
    }
  }

  /// Reset magnetometer calibration
  void resetMagnetometerCalibration() {
    if (_enabledSensors.contains(SensorType.magnetometer)) {
      _magnetometerService.resetCalibration();
      debugPrint('🔄 Reset magnetometer calibration');
    }
  }

  /// Calibrate barometric pressure with known altitude
  void calibrateBarometerWithAltitude(double altitude) {
    if (_enabledSensors.contains(SensorType.barometer)) {
      _pressureService.calibrateWithAltitude(altitude);
      debugPrint('🔄 Calibrated barometer with altitude: ${altitude}m');
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    final requiredSensors = _enabledSensors
        .where((sensor) =>
            sensor == SensorType.location ||
            sensor == SensorType.camera ||
            sensor == SensorType.microphone)
        .toList();

    if (requiredSensors.isNotEmpty) {
      final results = await _permissionsService
          .requestMultipleSensorPermissions(requiredSensors);

      for (final entry in results.entries) {
        if (entry.value != PermissionStatus.granted) {
          debugPrint('🔄 Warning: ${entry.key.name} permission not granted');
        }
      }
    }
  }

  Set<SensorType> _getDefaultEnabledSensors(SensorFusionMode mode) {
    switch (mode) {
      case SensorFusionMode.minimal:
        return {SensorType.accelerometer, SensorType.magnetometer};
      case SensorFusionMode.balanced:
        return {
          SensorType.accelerometer,
          SensorType.magnetometer,
          SensorType.gyroscope,
          SensorType.barometer,
        };
      case SensorFusionMode.comprehensive:
        return SensorType.values.toSet();
    }
  }

  Future<void> _startEnabledSensors() async {
    if (_enabledSensors.contains(SensorType.accelerometer)) {
      await _accelerometerService.start();
      _sensorStatus[SensorType.accelerometer] = SensorStatus.active;
    }

    if (_enabledSensors.contains(SensorType.magnetometer)) {
      await _magnetometerService.start();
      _sensorStatus[SensorType.magnetometer] = SensorStatus.active;
    }

    if (_enabledSensors.contains(SensorType.barometer)) {
      await _pressureService.start();
      _sensorStatus[SensorType.barometer] = SensorStatus.active;
    }

    if (_enabledSensors.contains(SensorType.gyroscope)) {
      await _orientationService.start();
      _sensorStatus[SensorType.gyroscope] = SensorStatus.active;
    }

    // Enhanced compass uses multiple sensors internally
    if (_enabledSensors.any((s) =>
        [SensorType.magnetometer, SensorType.accelerometer].contains(s))) {
      await _compassService.start();
    }
  }

  void _subscribeToSensorStreams() {
    if (_enabledSensors.contains(SensorType.accelerometer)) {
      _accelerometerSubscription = _accelerometerService.readingStream.listen(
        _handleAccelerometerReading,
        onError: (Object error) =>
            _handleSensorError(SensorType.accelerometer, error),
      );
    }

    if (_enabledSensors.contains(SensorType.magnetometer)) {
      _magnetometerSubscription = _magnetometerService.readingStream.listen(
        _handleMagnetometerReading,
        onError: (Object error) =>
            _handleSensorError(SensorType.magnetometer, error),
      );

      // Subscribe to calibration events
      _magnetometerService.calibrationStream.listen(
        _handleMagnetometerCalibration,
        onError: (Object error) =>
            debugPrint('🔄 Magnetometer calibration error: $error'),
      );
    }

    if (_enabledSensors.contains(SensorType.barometer)) {
      _pressureSubscription = _pressureService.readingStream.listen(
        _handlePressureReading,
        onError: (Object error) =>
            _handleSensorError(SensorType.barometer, error),
      );
    }

    if (_enabledSensors.contains(SensorType.gyroscope)) {
      _orientationSubscription = _orientationService.orientationStream.listen(
        _handleOrientationReading,
        onError: (Object error) =>
            _handleSensorError(SensorType.gyroscope, error),
      );
    }

    // Enhanced compass subscription
    if (_enabledSensors.any((s) =>
        [SensorType.magnetometer, SensorType.accelerometer].contains(s))) {
      _compassSubscription = _compassService.compassStream.listen(
        _handleCompassReading,
        onError: (Object error) => debugPrint('🔄 Compass error: $error'),
      );
    }
  }

  void _handleAccelerometerReading(AccelerometerReading reading) {
    _lastAccelerometerReading = reading;
    _updateSensorStatus(SensorType.accelerometer, SensorStatus.active);
    _generateFusionReading();
  }

  void _handleMagnetometerReading(MagnetometerReading reading) {
    _lastMagnetometerReading = reading;
    _updateSensorStatus(SensorType.magnetometer, SensorStatus.active);
    _generateFusionReading();
  }

  void _handlePressureReading(PressureReading reading) {
    _lastPressureReading = reading;
    _updateSensorStatus(SensorType.barometer, SensorStatus.active);
    _generateFusionReading();
  }

  void _handleOrientationReading(orientation.OrientationReading reading) {
    _lastOrientationReading = reading;
    _updateSensorStatus(SensorType.gyroscope, SensorStatus.active);
    _generateFusionReading();
  }

  void _handleCompassReading(EnhancedCompassReading reading) {
    _lastCompassReading = reading;
    _generateFusionReading();
  }

  void _handleMagnetometerCalibration(CalibrationStatus status) {
    final calibrationStatus = SensorCalibrationStatus(
      sensorType: SensorType.magnetometer,
      isCalibrating: status.isCalibrating,
      isCalibrated: status.isCalibrated,
      quality: status.quality.name,
      progress: status.progress,
      timestamp: DateTime.now(),
    );

    _calibrationController?.add(calibrationStatus);
  }

  void _handleSensorError(SensorType sensorType, Object error) {
    debugPrint('🔄 ${sensorType.name} error: $error');
    _updateSensorStatus(sensorType, SensorStatus.error);
  }

  void _updateSensorStatus(SensorType sensorType, SensorStatus status) {
    if (_sensorStatus[sensorType] != status) {
      _sensorStatus[sensorType] = status;
      debugPrint('🔄 ${sensorType.name} status: ${status.name}');
    }
  }

  void _generateFusionReading() {
    try {
      final reading = SensorFusionReading(
        accelerometer: _lastAccelerometerReading,
        magnetometer: _lastMagnetometerReading,
        pressure: _lastPressureReading,
        deviceOrientation: _lastOrientationReading,
        compass: _lastCompassReading,
        mode: _mode,
        enabledSensors: Set.from(_enabledSensors),
        sensorStatus: Map.from(_sensorStatus),
        timestamp: DateTime.now(),
      );

      _fusionController?.add(reading);
    } catch (e) {
      debugPrint('🔄 Error generating fusion reading: $e');
    }
  }

  void _startHealthMonitoring() {
    _healthCheckTimer =
        Timer.periodic(_healthCheckInterval, (_) => _performHealthCheck());
  }

  void _performHealthCheck() {
    final now = DateTime.now();
    final healthStatus = SensorHealthStatus(
      overallHealth: _calculateOverallHealth(),
      sensorStatus: Map.from(_sensorStatus),
      lastUpdateTimes: _getLastUpdateTimes(),
      timestamp: now,
    );

    _healthController?.add(healthStatus);
    // Health check completed
  }

  SensorHealth _calculateOverallHealth() {
    final activeSensors =
        _sensorStatus.values.where((s) => s == SensorStatus.active).length;
    final totalSensors = _enabledSensors.length;

    if (activeSensors == totalSensors) {
      return SensorHealth.excellent;
    } else if (activeSensors >= totalSensors * 0.8) {
      return SensorHealth.good;
    } else if (activeSensors >= totalSensors * 0.5) {
      return SensorHealth.fair;
    } else {
      return SensorHealth.poor;
    }
  }

  Map<SensorType, DateTime?> _getLastUpdateTimes() => {
        SensorType.accelerometer: _lastAccelerometerReading?.timestamp,
        SensorType.magnetometer: _lastMagnetometerReading?.timestamp,
        SensorType.barometer: _lastPressureReading?.timestamp,
        SensorType.gyroscope: _lastOrientationReading?.timestamp,
      };

  /// Dispose of resources
  void dispose() {
    stop();
    _accelerometerService.dispose();
    _magnetometerService.dispose();
    _pressureService.dispose();
    _orientationService.dispose();
    _compassService.dispose();
  }
}

/// Comprehensive sensor fusion reading
class SensorFusionReading {
  const SensorFusionReading({
    required this.accelerometer,
    required this.magnetometer,
    required this.pressure,
    required this.deviceOrientation,
    required this.compass,
    required this.mode,
    required this.enabledSensors,
    required this.sensorStatus,
    required this.timestamp,
  });

  final AccelerometerReading? accelerometer;
  final MagnetometerReading? magnetometer;
  final PressureReading? pressure;
  final orientation.OrientationReading? deviceOrientation;
  final EnhancedCompassReading? compass;
  final SensorFusionMode mode;
  final Set<SensorType> enabledSensors;
  final Map<SensorType, SensorStatus> sensorStatus;
  final DateTime timestamp;

  /// Get the best available heading
  double? get bestHeading => compass?.heading ?? magnetometer?.heading;

  /// Get the best available altitude
  double? get bestAltitude => pressure?.altitude;

  /// Get current activity type
  ActivityType? get currentActivity => accelerometer?.isInMotion == true
      ? ActivityType.walking
      : ActivityType.stationary;

  /// Get device stability (inverse of motion)
  bool get isDeviceStable => accelerometer?.isInMotion == false;
}

/// Sensor health status
class SensorHealthStatus {
  const SensorHealthStatus({
    required this.overallHealth,
    required this.sensorStatus,
    required this.lastUpdateTimes,
    required this.timestamp,
  });

  final SensorHealth overallHealth;
  final Map<SensorType, SensorStatus> sensorStatus;
  final Map<SensorType, DateTime?> lastUpdateTimes;
  final DateTime timestamp;
}

/// Sensor calibration status
class SensorCalibrationStatus {
  const SensorCalibrationStatus({
    required this.sensorType,
    required this.isCalibrating,
    required this.isCalibrated,
    required this.quality,
    required this.progress,
    required this.timestamp,
  });

  final SensorType sensorType;
  final bool isCalibrating;
  final bool isCalibrated;
  final String quality;
  final double progress;
  final DateTime timestamp;
}

/// Sensor fusion modes
enum SensorFusionMode {
  minimal,
  balanced,
  comprehensive;

  String get description {
    switch (this) {
      case SensorFusionMode.minimal:
        return 'Minimal (Basic sensors only)';
      case SensorFusionMode.balanced:
        return 'Balanced (Core sensors)';
      case SensorFusionMode.comprehensive:
        return 'Comprehensive (All sensors)';
    }
  }
}

/// Sensor status
enum SensorStatus {
  inactive,
  active,
  error,
  calibrating;

  String get description {
    switch (this) {
      case SensorStatus.inactive:
        return 'Inactive';
      case SensorStatus.active:
        return 'Active';
      case SensorStatus.error:
        return 'Error';
      case SensorStatus.calibrating:
        return 'Calibrating';
    }
  }
}

/// Overall sensor health
enum SensorHealth {
  poor,
  fair,
  good,
  excellent;

  String get description {
    switch (this) {
      case SensorHealth.poor:
        return 'Poor';
      case SensorHealth.fair:
        return 'Fair';
      case SensorHealth.good:
        return 'Good';
      case SensorHealth.excellent:
        return 'Excellent';
    }
  }
}
