import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Comprehensive sensor permissions service
/// Handles permission requests and status checks for all sensor types
class SensorPermissionsService {
  SensorPermissionsService();

  // Permission status cache
  final Map<SensorType, PermissionStatus> _permissionCache = {};

  /// Check if a specific sensor permission is granted
  Future<bool> hasSensorPermission(SensorType sensorType) async {
    try {
      final permission = _getSensorPermission(sensorType);
      if (permission == null) {
        // Some sensors don't require explicit permissions
        return true;
      }

      final status = await permission.status;
      _permissionCache[sensorType] = status;

      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('🔐 Error checking ${sensorType.name} permission: $e');
      return false;
    }
  }

  /// Request permission for a specific sensor
  Future<PermissionStatus> requestSensorPermission(
      SensorType sensorType) async {
    try {
      final permission = _getSensorPermission(sensorType);
      if (permission == null) {
        // Some sensors don't require explicit permissions
        return PermissionStatus.granted;
      }

      debugPrint('🔐 Requesting ${sensorType.name} permission...');

      final status = await permission.request();
      _permissionCache[sensorType] = status;

      debugPrint('🔐 ${sensorType.name} permission result: ${status.name}');

      return status;
    } catch (e) {
      debugPrint('🔐 Error requesting ${sensorType.name} permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Request multiple sensor permissions at once
  Future<Map<SensorType, PermissionStatus>> requestMultipleSensorPermissions(
    List<SensorType> sensorTypes,
  ) async {
    final Map<SensorType, PermissionStatus> results = {};

    try {
      debugPrint(
          '🔐 Requesting permissions for: ${sensorTypes.map((s) => s.name).join(', ')}');

      // Group permissions by actual Permission objects
      final Map<Permission, List<SensorType>> permissionGroups = {};

      for (final sensorType in sensorTypes) {
        final permission = _getSensorPermission(sensorType);
        if (permission != null) {
          permissionGroups.putIfAbsent(permission, () => []).add(sensorType);
        } else {
          // Sensors that don't require permissions
          results[sensorType] = PermissionStatus.granted;
        }
      }

      // Request permissions in groups
      for (final entry in permissionGroups.entries) {
        final permission = entry.key;
        final associatedSensors = entry.value;

        final status = await permission.request();

        // Apply the same status to all associated sensors
        for (final sensorType in associatedSensors) {
          results[sensorType] = status;
          _permissionCache[sensorType] = status;
        }
      }

      debugPrint(
          '🔐 Permission results: ${results.map((k, v) => MapEntry(k.name, v.name))}');

      return results;
    } catch (e) {
      debugPrint('🔐 Error requesting multiple sensor permissions: $e');

      // Return denied status for all requested sensors on error
      for (final sensorType in sensorTypes) {
        results[sensorType] = PermissionStatus.denied;
      }

      return results;
    }
  }

  /// Check if all required sensor permissions are granted
  Future<bool> hasAllRequiredPermissions(
      List<SensorType> requiredSensors) async {
    try {
      for (final sensorType in requiredSensors) {
        final hasPermission = await hasSensorPermission(sensorType);
        if (!hasPermission) {
          debugPrint('🔐 Missing permission for ${sensorType.name}');
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('🔐 Error checking required permissions: $e');
      return false;
    }
  }

  /// Get detailed permission status for all sensors
  Future<Map<SensorType, SensorPermissionInfo>>
      getAllSensorPermissions() async {
    final Map<SensorType, SensorPermissionInfo> results = {};

    for (final sensorType in SensorType.values) {
      try {
        final permission = _getSensorPermission(sensorType);
        PermissionStatus status;
        bool isRequired;
        String description;

        if (permission == null) {
          status = PermissionStatus.granted;
          isRequired = false;
          description = 'No explicit permission required';
        } else {
          status = await permission.status;
          isRequired = _isSensorPermissionRequired(sensorType);
          description = _getSensorPermissionDescription(sensorType);
        }

        results[sensorType] = SensorPermissionInfo(
          sensorType: sensorType,
          status: status,
          isRequired: isRequired,
          description: description,
          isAvailable: await _isSensorAvailable(sensorType),
        );

        _permissionCache[sensorType] = status;
      } catch (e) {
        debugPrint(
            '🔐 Error getting permission info for ${sensorType.name}: $e');

        results[sensorType] = SensorPermissionInfo(
          sensorType: sensorType,
          status: PermissionStatus.denied,
          isRequired: _isSensorPermissionRequired(sensorType),
          description: 'Error checking permission',
          isAvailable: false,
        );
      }
    }

    return results;
  }

  /// Open app settings for manual permission management
  Future<bool> openAppSettings() async {
    try {
      debugPrint('🔐 Opening app settings for manual permission management');
      return await openAppSettings();
    } catch (e) {
      debugPrint('🔐 Error opening app settings: $e');
      return false;
    }
  }

  /// Check if a sensor permission is permanently denied
  Future<bool> isSensorPermissionPermanentlyDenied(
      SensorType sensorType) async {
    try {
      final permission = _getSensorPermission(sensorType);
      if (permission == null) return false;

      final status = await permission.status;
      return status == PermissionStatus.permanentlyDenied;
    } catch (e) {
      debugPrint(
          '🔐 Error checking permanent denial for ${sensorType.name}: $e');
      return false;
    }
  }

  /// Get the appropriate Permission object for a sensor type
  Permission? _getSensorPermission(SensorType sensorType) {
    switch (sensorType) {
      case SensorType.location:
        return Permission.location;
      case SensorType.locationAlways:
        return Permission.locationAlways;
      case SensorType.locationWhenInUse:
        return Permission.locationWhenInUse;
      case SensorType.camera:
        return Permission.camera;
      case SensorType.microphone:
        return Permission.microphone;
      case SensorType.sensors:
        return Permission.sensors;
      case SensorType.activityRecognition:
        return Permission.activityRecognition;
      case SensorType.accelerometer:
      case SensorType.gyroscope:
      case SensorType.magnetometer:
      case SensorType.barometer:
        // These typically don't require explicit permissions on most platforms
        return null;
    }
  }

  /// Check if a sensor permission is required for the app to function
  bool _isSensorPermissionRequired(SensorType sensorType) {
    switch (sensorType) {
      case SensorType.location:
      case SensorType.locationWhenInUse:
        return true; // Essential for tracking app
      case SensorType.locationAlways:
        return false; // Nice to have for background tracking
      case SensorType.camera:
        return false; // Optional for photo capture
      case SensorType.microphone:
        return false; // Optional for voice notes
      case SensorType.sensors:
      case SensorType.activityRecognition:
        return false; // Optional for enhanced features
      case SensorType.accelerometer:
      case SensorType.gyroscope:
      case SensorType.magnetometer:
      case SensorType.barometer:
        return false; // Optional sensor enhancements
    }
  }

  /// Get human-readable description for sensor permission
  String _getSensorPermissionDescription(SensorType sensorType) {
    switch (sensorType) {
      case SensorType.location:
        return 'Required for GPS tracking and navigation';
      case SensorType.locationAlways:
        return 'Enables background location tracking';
      case SensorType.locationWhenInUse:
        return 'Required for GPS tracking while app is active';
      case SensorType.camera:
        return 'Optional for capturing photos at waypoints';
      case SensorType.microphone:
        return 'Optional for recording voice notes';
      case SensorType.sensors:
        return 'Enables motion detection and activity recognition';
      case SensorType.activityRecognition:
        return 'Detects walking, running, and other activities';
      case SensorType.accelerometer:
        return 'Detects device motion and orientation';
      case SensorType.gyroscope:
        return 'Detects device rotation and orientation changes';
      case SensorType.magnetometer:
        return 'Provides compass functionality and magnetic field detection';
      case SensorType.barometer:
        return 'Improves altitude accuracy and weather awareness';
    }
  }

  /// Check if a sensor is available on the current device
  Future<bool> _isSensorAvailable(SensorType sensorType) async {
    try {
      // This is a simplified check - in a real implementation,
      // you might use platform-specific code to detect sensor availability
      switch (sensorType) {
        case SensorType.location:
        case SensorType.locationAlways:
        case SensorType.locationWhenInUse:
          return true; // GPS is available on all mobile devices
        case SensorType.camera:
          return true; // Camera is available on all mobile devices
        case SensorType.microphone:
          return true; // Microphone is available on all mobile devices
        case SensorType.accelerometer:
          return true; // Accelerometer is standard on mobile devices
        case SensorType.gyroscope:
          return true; // Gyroscope is common on modern devices
        case SensorType.magnetometer:
          return true; // Magnetometer is common for compass functionality
        case SensorType.barometer:
          // Barometer is less common, especially on older devices
          return Platform.isAndroid || Platform.isIOS;
        case SensorType.sensors:
        case SensorType.activityRecognition:
          return Platform.isAndroid; // Android-specific permissions
      }
    } catch (e) {
      debugPrint(
          '🔐 Error checking sensor availability for ${sensorType.name}: $e');
      return false;
    }
  }

  /// Clear permission cache
  void clearCache() {
    _permissionCache.clear();
    debugPrint('🔐 Permission cache cleared');
  }

  /// Get cached permission status (if available)
  PermissionStatus? getCachedPermissionStatus(SensorType sensorType) =>
      _permissionCache[sensorType];
}

/// Information about a sensor permission
class SensorPermissionInfo {
  const SensorPermissionInfo({
    required this.sensorType,
    required this.status,
    required this.isRequired,
    required this.description,
    required this.isAvailable,
  });

  final SensorType sensorType;
  final PermissionStatus status;
  final bool isRequired;
  final String description;
  final bool isAvailable;

  bool get isGranted => status == PermissionStatus.granted;
  bool get isDenied => status == PermissionStatus.denied;
  bool get isPermanentlyDenied => status == PermissionStatus.permanentlyDenied;
  bool get isRestricted => status == PermissionStatus.restricted;
  bool get isLimited => status == PermissionStatus.limited;

  /// Whether this permission blocks core app functionality
  bool get blocksCoreFunctionality => isRequired && !isGranted;

  /// Whether this permission can be requested
  bool get canBeRequested =>
      status != PermissionStatus.permanentlyDenied &&
      status != PermissionStatus.restricted;
}

/// Types of sensors that may require permissions
enum SensorType {
  location,
  locationAlways,
  locationWhenInUse,
  camera,
  microphone,
  sensors,
  activityRecognition,
  accelerometer,
  gyroscope,
  magnetometer,
  barometer;

  String get displayName {
    switch (this) {
      case SensorType.location:
        return 'Location';
      case SensorType.locationAlways:
        return 'Background Location';
      case SensorType.locationWhenInUse:
        return 'Location (When In Use)';
      case SensorType.camera:
        return 'Camera';
      case SensorType.microphone:
        return 'Microphone';
      case SensorType.sensors:
        return 'Sensors';
      case SensorType.activityRecognition:
        return 'Activity Recognition';
      case SensorType.accelerometer:
        return 'Accelerometer';
      case SensorType.gyroscope:
        return 'Gyroscope';
      case SensorType.magnetometer:
        return 'Magnetometer';
      case SensorType.barometer:
        return 'Barometer';
    }
  }
}
