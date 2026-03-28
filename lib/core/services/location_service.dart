import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;

/// Custom exception for location service errors
class LocationServiceException implements Exception {
  const LocationServiceException(this.message, this.type);
  final String message;
  final LocationServiceError type;

  @override
  String toString() => 'LocationServiceException: $message';
}

/// Types of location service errors
enum LocationServiceError {
  permissionDenied,
  serviceDisabled,
  permissionDeniedForever,
  timeout,
  notSupported,
  unknown,
}

/// Current status of location permissions and service
enum LocationStatus {
  unknown,
  checking,
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  notSupported,
}

/// Enhanced location data with additional GPS information
@immutable
class EnhancedLocationData {
  const EnhancedLocationData({
    required this.position,
    this.calculatedSpeed,
    this.speedAccuracy,
    this.altitudeAccuracy,
    this.headingAccuracy,
    this.isEnhancedDataAvailable = false,
  });

  /// The base GPS position
  final Position position;

  /// Speed calculated from GPS position changes (m/s)
  final double? calculatedSpeed;

  /// Accuracy of speed measurement (m/s)
  final double? speedAccuracy;

  /// Accuracy of altitude measurement (meters)
  final double? altitudeAccuracy;

  /// Accuracy of heading measurement (degrees)
  final double? headingAccuracy;

  /// Whether enhanced data beyond basic lat/lng is available
  final bool isEnhancedDataAvailable;

  /// Get the best available speed (calculated or device-provided)
  double? get bestSpeed {
    // Prefer calculated speed if available and seems reasonable
    if (calculatedSpeed != null && calculatedSpeed! >= 0) {
      return calculatedSpeed;
    }
    // Fall back to device-provided speed
    return position.speed >= 0 ? position.speed : null;
  }

  /// Get the best available altitude with accuracy check
  double? get bestAltitude {
    // Only return altitude if it seems reasonable
    if (position.altitude != 0.0) {
      return position.altitude;
    }
    return null;
  }

  /// Get the best available heading
  double? get bestHeading {
    // Normalize heading to 0-360 range
    if (position.heading >= 0 && position.heading <= 360) {
      return position.heading;
    }
    return null;
  }

  /// Check if this location has good overall accuracy
  bool get hasGoodAccuracy => position.accuracy <= 10.0;

  /// Check if enhanced data is reliable
  bool get hasReliableEnhancedData =>
      isEnhancedDataAvailable &&
      position.accuracy <= 5.0 && // Good base accuracy
      (altitudeAccuracy == null || altitudeAccuracy! <= 10.0);
}

/// Wrapper service for GPS location functionality using geolocator package.
///
/// Provides high-accuracy location tracking with enhanced GPS data collection
/// including altitude, speed calculation, heading, and accuracy indicators.
/// Uses privacy-first approach for the Obsession Tracker app.
class LocationService {
  factory LocationService() => _instance ??= LocationService._();
  LocationService._();
  static LocationService? _instance;

  StreamSubscription<dynamic>? _positionStream;
  Position? _lastKnownPosition;
  EnhancedLocationData? _lastEnhancedLocation;
  LocationStatus _status = LocationStatus.unknown;

  // For speed calculation
  Position? _previousPosition;
  DateTime? _previousTimestamp;
  final List<double> _speedHistory = <double>[];
  static const int _maxSpeedHistoryLength = 5;

  /// Current location permission and service status
  LocationStatus get status => _status;

  /// Whether GPS location is supported on this platform
  /// Desktop platforms don't have GPS hardware
  bool get isLocationSupported {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  /// Last known GPS position (may be cached)
  Position? get lastKnownPosition => _lastKnownPosition;

  /// Last known enhanced location data
  EnhancedLocationData? get lastEnhancedLocation => _lastEnhancedLocation;

  /// Check if we have "Always" location permission (for background tracking)
  /// Returns true only if permission is set to "Always Allow" on iOS
  Future<bool> hasAlwaysLocationPermission() async {
    try {
      final LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always;
    } catch (e) {
      debugPrint('Error checking always permission: $e');
      return false;
    }
  }

  /// Get detailed permission status for UI display
  Future<LocationPermission> getDetailedPermissionStatus() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      debugPrint('Error getting detailed permission: $e');
      return LocationPermission.unableToDetermine;
    }
  }

  /// Check if location services are available and permissions are granted
  Future<LocationStatus> checkLocationStatus() async {
    // Desktop platforms don't support GPS
    if (!isLocationSupported) {
      _status = LocationStatus.notSupported;
      return _status;
    }

    _status = LocationStatus.checking;

    try {
      // Check if location services are enabled
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _status = LocationStatus.serviceDisabled;
        return _status;
      }

      // Check location permissions
      final LocationPermission permission = await Geolocator.checkPermission();

      switch (permission) {
        case LocationPermission.denied:
          _status = LocationStatus.denied;
          break;
        case LocationPermission.deniedForever:
          _status = LocationStatus.deniedForever;
          break;
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          _status = LocationStatus.granted;
          break;
        case LocationPermission.unableToDetermine:
          _status = LocationStatus.unknown;
          break;
      }

      return _status;
    } on Exception catch (e) {
      debugPrint('Error checking location status: $e');
      _status = LocationStatus.unknown;
      return _status;
    }
  }

  /// Request location permissions from the user
  /// For background tracking, this will request "always" permission on iOS
  Future<LocationStatus> requestLocationPermission({
    bool requestAlwaysPermission = true,
  }) async {
    // Desktop platforms don't support GPS
    if (!isLocationSupported) {
      _status = LocationStatus.notSupported;
      throw const LocationServiceException(
        'GPS location is not available on desktop platforms.',
        LocationServiceError.notSupported,
      );
    }

    try {
      // First check if service is enabled
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _status = LocationStatus.serviceDisabled;
        throw const LocationServiceException(
          'Location services are disabled. Please enable location services in device settings.',
          LocationServiceError.serviceDisabled,
        );
      }

      // Check current permission first
      LocationPermission currentPermission = await Geolocator.checkPermission();

      // If we need always permission and only have whileInUse, request upgrade
      if (requestAlwaysPermission &&
          currentPermission == LocationPermission.whileInUse &&
          Platform.isIOS) {
        debugPrint(
            'Requesting upgrade from whileInUse to always permission for background tracking');
        // On iOS, request permission again to potentially upgrade to always
        currentPermission = await Geolocator.requestPermission();
      } else if (currentPermission == LocationPermission.denied) {
        // Request initial permission
        currentPermission = await Geolocator.requestPermission();
      }

      switch (currentPermission) {
        case LocationPermission.denied:
          _status = LocationStatus.denied;
          throw const LocationServiceException(
            'Location permission denied. Please grant location access to track your adventures.',
            LocationServiceError.permissionDenied,
          );
        case LocationPermission.deniedForever:
          _status = LocationStatus.deniedForever;
          throw const LocationServiceException(
            'Location permission permanently denied. Please enable location access in app settings.',
            LocationServiceError.permissionDeniedForever,
          );
        case LocationPermission.whileInUse:
          _status = LocationStatus.granted;
          if (requestAlwaysPermission && Platform.isIOS) {
            debugPrint(
                'Warning: Only "When In Use" permission granted. Background tracking may be limited.');
          }
          break;
        case LocationPermission.always:
          _status = LocationStatus.granted;
          debugPrint(
              'Always location permission granted - background tracking enabled');
          break;
        case LocationPermission.unableToDetermine:
          _status = LocationStatus.unknown;
          throw const LocationServiceException(
            'Unable to determine location permission status.',
            LocationServiceError.unknown,
          );
      }

      return _status;
    } catch (e) {
      if (e is LocationServiceException) {
        rethrow;
      }

      debugPrint('Error requesting location permission: $e');
      _status = LocationStatus.unknown;
      throw LocationServiceException(
        'Failed to request location permission: $e',
        LocationServiceError.unknown,
      );
    }
  }

  /// Get current GPS position with high accuracy
  Future<Position> getCurrentPosition({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await _ensurePermissions();

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );

      _lastKnownPosition = position;
      return position;
    } on TimeoutException {
      throw const LocationServiceException(
        'GPS timeout - unable to get location within time limit.',
        LocationServiceError.timeout,
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
      throw LocationServiceException(
        'Failed to get current location: $e',
        LocationServiceError.unknown,
      );
    }
  }

  /// Get current GPS position with enhanced data collection
  Future<EnhancedLocationData> getCurrentEnhancedPosition({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await _ensurePermissions();

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );

      final EnhancedLocationData enhancedData =
          _createEnhancedLocationData(position);
      _lastKnownPosition = position;
      _lastEnhancedLocation = enhancedData;

      return enhancedData;
    } on TimeoutException {
      throw const LocationServiceException(
        'GPS timeout - unable to get location within time limit.',
        LocationServiceError.timeout,
      );
    } catch (e) {
      debugPrint('Error getting current enhanced position: $e');
      throw LocationServiceException(
        'Failed to get current enhanced location: $e',
        LocationServiceError.unknown,
      );
    }
  }

  /// Start listening to location updates with specified settings
  Stream<Position> getLocationStream({
    int intervalSeconds = 5,
    double minimumDistanceMeters = 0,
    LocationAccuracy accuracy = LocationAccuracy.high,
    bool enableBackgroundLocation = true,
  }) async* {
    await _ensurePermissions();

    // Configure location settings for background operation on iOS
    LocationSettings locationSettings;

    if (Platform.isIOS && enableBackgroundLocation) {
      locationSettings = AppleSettings(
        accuracy: accuracy,
        distanceFilter: minimumDistanceMeters.round(),
        showBackgroundLocationIndicator:
            true, // Show blue bar when using location in background
      );
    } else if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: accuracy,
        distanceFilter: minimumDistanceMeters.round(),
        intervalDuration: Duration(seconds: intervalSeconds),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText:
              'Obsession Tracker is tracking your location in the background',
          notificationTitle: 'Location Tracking Active',
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = LocationSettings(
        accuracy: accuracy,
        distanceFilter: minimumDistanceMeters.round(),
      );
    }

    try {
      await for (final Position position
          in Geolocator.getPositionStream(locationSettings: locationSettings)) {
        _lastKnownPosition = position;
        yield position;
      }
    } catch (e) {
      debugPrint('Error in location stream: $e');
      throw LocationServiceException(
        'Location tracking stream error: $e',
        LocationServiceError.unknown,
      );
    }
  }

  /// Start listening to enhanced location updates with additional GPS data
  Stream<EnhancedLocationData> getEnhancedLocationStream({
    int intervalSeconds = 5,
    double minimumDistanceMeters = 0,
    LocationAccuracy accuracy = LocationAccuracy.high,
    bool enableBackgroundLocation = true,
  }) async* {
    await _ensurePermissions();

    // Configure location settings for background operation on iOS
    LocationSettings locationSettings;

    if (Platform.isIOS && enableBackgroundLocation) {
      locationSettings = AppleSettings(
        accuracy: accuracy,
        distanceFilter: minimumDistanceMeters.round(),
        showBackgroundLocationIndicator:
            true, // Show blue bar when using location in background
      );
    } else if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: accuracy,
        distanceFilter: minimumDistanceMeters.round(),
        intervalDuration: Duration(seconds: intervalSeconds),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText:
              'Obsession Tracker is tracking your location in the background',
          notificationTitle: 'Location Tracking Active',
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = LocationSettings(
        accuracy: accuracy,
        distanceFilter: minimumDistanceMeters.round(),
      );
    }

    try {
      await for (final Position position
          in Geolocator.getPositionStream(locationSettings: locationSettings)) {
        final EnhancedLocationData enhancedData =
            _createEnhancedLocationData(position);
        _lastKnownPosition = position;
        _lastEnhancedLocation = enhancedData;
        yield enhancedData;
      }
    } catch (e) {
      debugPrint('Error in enhanced location stream: $e');
      throw LocationServiceException(
        'Enhanced location tracking stream error: $e',
        LocationServiceError.unknown,
      );
    }
  }

  /// Start continuous location tracking
  Future<void> startLocationTracking({
    required void Function(Position) onLocationUpdate,
    required void Function(LocationServiceException) onError,
    int intervalSeconds = 5,
    double minimumDistanceMeters = 0,
    LocationAccuracy accuracy = LocationAccuracy.high,
    bool enableBackgroundLocation = true,
  }) async {
    await stopLocationTracking(); // Stop any existing tracking

    try {
      _positionStream = getLocationStream(
        intervalSeconds: intervalSeconds,
        minimumDistanceMeters: minimumDistanceMeters,
        accuracy: accuracy,
        enableBackgroundLocation: enableBackgroundLocation,
      ).listen(
        onLocationUpdate,
        onError: (Object error) {
          if (error is LocationServiceException) {
            onError(error);
          } else {
            onError(LocationServiceException(
              'Unexpected location tracking error: $error',
              LocationServiceError.unknown,
            ));
          }
        },
      );
    } on Exception catch (e) {
      onError(LocationServiceException(
        'Failed to start location tracking: $e',
        LocationServiceError.unknown,
      ));
    }
  }

  /// Start continuous enhanced location tracking with additional GPS data
  Future<void> startEnhancedLocationTracking({
    required void Function(EnhancedLocationData) onLocationUpdate,
    required void Function(LocationServiceException) onError,
    int intervalSeconds = 5,
    double minimumDistanceMeters = 0,
    LocationAccuracy accuracy = LocationAccuracy.high,
    bool enableBackgroundLocation = true,
  }) async {
    await stopLocationTracking(); // Stop any existing tracking

    try {
      _positionStream = getEnhancedLocationStream(
        intervalSeconds: intervalSeconds,
        minimumDistanceMeters: minimumDistanceMeters,
        accuracy: accuracy,
        enableBackgroundLocation: enableBackgroundLocation,
      ).listen(
        onLocationUpdate,
        onError: (Object error) {
          if (error is LocationServiceException) {
            onError(error);
          } else {
            onError(LocationServiceException(
              'Unexpected enhanced location tracking error: $error',
              LocationServiceError.unknown,
            ));
          }
        },
      );
    } on Exception catch (e) {
      onError(LocationServiceException(
        'Failed to start enhanced location tracking: $e',
        LocationServiceError.unknown,
      ));
    }
  }

  /// Stop location tracking
  Future<void> stopLocationTracking() async {
    try {
      await _positionStream?.cancel();
    } on Exception catch (e) {
      // Handle timeout or other cancellation errors gracefully
      debugPrint(
          'Warning: Stream cancellation encountered error (continuing): $e');
    } finally {
      // Always ensure stream is marked as null regardless of cancellation result
      _positionStream = null;
    }
  }

  /// Check if location tracking is currently active
  bool get isTracking => _positionStream != null;

  /// Get distance between two positions in meters
  double getDistanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) =>
      Geolocator.distanceBetween(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
      );

  /// Get bearing between two positions in degrees
  double getBearingBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) =>
      Geolocator.bearingBetween(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
      );

  /// Open device location settings
  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } on Exception catch (e) {
      debugPrint('Error opening location settings: $e');
      // Fallback to permission handler
      await openAppSettings();
    }
  }

  /// Open app settings page - opens device settings directly to this app's settings
  Future<void> openAppSettings() async {
    try {
      // Use permission_handler's openAppSettings to open device settings
      // This takes the user directly to the app's settings page where they can
      // change location permissions (e.g., from "While Using" to "Always")
      final bool opened = await permission_handler.openAppSettings();
      if (!opened) {
        debugPrint('⚠️ Failed to open app settings');
      } else {
        debugPrint('✅ Opened app settings successfully');
      }
    } on Exception catch (e) {
      debugPrint('❌ Error opening app settings: $e');
    }
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    stopLocationTracking();
    _instance = null;
  }

  /// Create enhanced location data from a GPS position
  EnhancedLocationData _createEnhancedLocationData(Position position) {
    final DateTime now = DateTime.now();

    // Calculate speed from position changes if we have previous data
    double? calculatedSpeed;
    double? speedAccuracy;

    if (_previousPosition != null && _previousTimestamp != null) {
      calculatedSpeed = _calculateSpeedFromPositions(
        _previousPosition!,
        position,
        _previousTimestamp!,
        now,
      );

      if (calculatedSpeed != null) {
        _updateSpeedHistory(calculatedSpeed);
        speedAccuracy = _calculateSpeedAccuracy();
      }
    }

    // Update previous position for next calculation
    _previousPosition = position;
    _previousTimestamp = now;

    // Determine if enhanced data is available and reliable
    final bool isEnhancedDataAvailable = _isEnhancedDataAvailable(position);

    return EnhancedLocationData(
      position: position,
      calculatedSpeed: calculatedSpeed,
      speedAccuracy: speedAccuracy,
      altitudeAccuracy: _getAltitudeAccuracy(position),
      headingAccuracy: _getHeadingAccuracy(position),
      isEnhancedDataAvailable: isEnhancedDataAvailable,
    );
  }

  /// Calculate speed between two positions
  double? _calculateSpeedFromPositions(
    Position previous,
    Position current,
    DateTime previousTime,
    DateTime currentTime,
  ) {
    try {
      final double distance = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );

      final int timeDiffMs =
          currentTime.difference(previousTime).inMilliseconds;
      if (timeDiffMs <= 0) {
        return null;
      }

      final double timeDiffSeconds = timeDiffMs / 1000.0;
      final double speed = distance / timeDiffSeconds;

      // Sanity check - reject unrealistic speeds (over 200 km/h for hiking/walking)
      if (speed > 55.56) {
        return null; // 200 km/h in m/s
      }

      return speed;
    } on Exception catch (e) {
      debugPrint('Error calculating speed: $e');
      return null;
    }
  }

  /// Update speed history for accuracy calculation
  void _updateSpeedHistory(double speed) {
    _speedHistory.add(speed);
    if (_speedHistory.length > _maxSpeedHistoryLength) {
      _speedHistory.removeAt(0);
    }
  }

  /// Calculate speed accuracy based on recent speed variations
  double? _calculateSpeedAccuracy() {
    if (_speedHistory.length < 2) {
      return null;
    }

    final double average = _speedHistory.reduce((double a, double b) => a + b) /
        _speedHistory.length;
    final double variance = _speedHistory
            .map((double speed) => (speed - average) * (speed - average))
            .reduce((double a, double b) => a + b) /
        _speedHistory.length;

    return variance.isFinite ? variance : null;
  }

  /// Check if enhanced data is available from the GPS
  bool _isEnhancedDataAvailable(Position position) =>
      // Consider enhanced data available if we have good accuracy and additional fields
      position.accuracy <= 10.0 &&
      (position.altitude != 0.0 ||
          position.speed >= 0 ||
          (position.heading >= 0 && position.heading <= 360));

  /// Get altitude accuracy estimate
  double? _getAltitudeAccuracy(Position position) {
    // Platform-specific altitude accuracy estimation
    if (Platform.isIOS) {
      // iOS typically provides better altitude accuracy
      return position.accuracy * 1.5; // Rough estimate
    } else if (Platform.isAndroid) {
      // Android altitude can be less accurate
      return position.accuracy * 2.0; // Rough estimate
    }
    return null;
  }

  /// Get heading accuracy estimate
  double? _getHeadingAccuracy(Position position) {
    // Heading accuracy depends on speed and GPS accuracy
    if (position.speed < 1.0) {
      // Low speed = poor heading accuracy
      return 45.0; // degrees
    } else if (position.accuracy > 5.0) {
      // Poor GPS accuracy = poor heading accuracy
      return 30.0; // degrees
    }
    return 15.0; // degrees - reasonable accuracy
  }

  /// Internal method to ensure permissions are granted before location operations
  Future<void> _ensurePermissions() async {
    // Check for desktop platform first
    if (!isLocationSupported) {
      throw const LocationServiceException(
        'GPS location is not available on desktop platforms.',
        LocationServiceError.notSupported,
      );
    }

    final LocationStatus status = await checkLocationStatus();

    if (status != LocationStatus.granted) {
      if (status == LocationStatus.serviceDisabled) {
        throw const LocationServiceException(
          'Location services are disabled. Please enable location services.',
          LocationServiceError.serviceDisabled,
        );
      } else if (status == LocationStatus.deniedForever) {
        throw const LocationServiceException(
          'Location permission permanently denied. Please enable in app settings.',
          LocationServiceError.permissionDeniedForever,
        );
      } else if (status == LocationStatus.notSupported) {
        throw const LocationServiceException(
          'GPS location is not available on this platform.',
          LocationServiceError.notSupported,
        );
      } else {
        // Try to request permission
        await requestLocationPermission();
      }
    }
  }
}
