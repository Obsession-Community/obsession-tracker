import 'dart:io' show File, Platform;
import 'dart:math' as math;

import 'package:camera/camera.dart' as camera_lib;
import 'package:exif/exif.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/photo_storage_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Camera error types for better error handling
enum CameraErrorType {
  permissionDenied,
  noCamerasAvailable,
  cameraInUse,
  initializationFailed,
}

/// Custom exception for camera initialization failures
class CameraInitializationException implements Exception {
  const CameraInitializationException(
    this.message,
    this.errorType, {
    this.isIOS = false,
    this.originalError,
  });

  final String message;
  final CameraErrorType errorType;
  final bool isIOS;
  final String? originalError;

  @override
  String toString() {
    final platform = isIOS ? 'iOS' : 'Android';
    final originalErrorText =
        originalError != null ? ' (Original: $originalError)' : '';
    return 'CameraInitializationException [$platform - ${errorType.name}]: $message$originalErrorText';
  }
}

/// Privacy settings for photo geotagging
@immutable
class PhotoPrivacySettings {
  const PhotoPrivacySettings({
    this.enableGpsTagging = true,
    this.enableCompassHeading = true,
    this.enableExifGpsWriting = true,
    this.locationAccuracyFuzzing = LocationAccuracyFuzzing.none,
    this.stripLocationOnShare = false,
  });

  /// Whether to capture and store GPS coordinates
  final bool enableGpsTagging;

  /// Whether to capture compass heading data
  final bool enableCompassHeading;

  /// Whether to write GPS data to EXIF metadata
  final bool enableExifGpsWriting;

  /// Level of location accuracy fuzzing for privacy
  final LocationAccuracyFuzzing locationAccuracyFuzzing;

  /// Whether to strip location data when sharing photos
  final bool stripLocationOnShare;

  PhotoPrivacySettings copyWith({
    bool? enableGpsTagging,
    bool? enableCompassHeading,
    bool? enableExifGpsWriting,
    LocationAccuracyFuzzing? locationAccuracyFuzzing,
    bool? stripLocationOnShare,
  }) =>
      PhotoPrivacySettings(
        enableGpsTagging: enableGpsTagging ?? this.enableGpsTagging,
        enableCompassHeading: enableCompassHeading ?? this.enableCompassHeading,
        enableExifGpsWriting: enableExifGpsWriting ?? this.enableExifGpsWriting,
        locationAccuracyFuzzing:
            locationAccuracyFuzzing ?? this.locationAccuracyFuzzing,
        stripLocationOnShare: stripLocationOnShare ?? this.stripLocationOnShare,
      );
}

/// Location accuracy fuzzing levels for privacy protection
enum LocationAccuracyFuzzing {
  /// No fuzzing - exact coordinates
  none,

  /// Round to ~100m accuracy
  low,

  /// Round to ~1km accuracy
  medium,

  /// Round to ~10km accuracy
  high,
}

/// Enhanced location data for photo capture
@immutable
class PhotoLocationData {
  const PhotoLocationData({
    required this.position,
    this.compassHeading,
    this.magneticDeclination,
    this.trueHeading,
    this.magnetometerData,
    this.timestamp,
    this.locationAccuracyData,
  });

  /// GPS position data
  final Position position;

  /// Compass heading in degrees (0-360)
  final double? compassHeading;

  /// Magnetic declination at this location
  final double? magneticDeclination;

  /// True heading (compass heading + magnetic declination)
  final double? trueHeading;

  /// Raw magnetometer data if available (x, y, z values in microteslas)
  final Map<String, double>? magnetometerData;

  /// Timestamp when location was captured
  final DateTime? timestamp;

  /// Additional location accuracy information
  final Map<String, double>? locationAccuracyData;

  /// Apply privacy fuzzing to coordinates
  PhotoLocationData applyPrivacyFuzzing(LocationAccuracyFuzzing fuzzing) {
    if (fuzzing == LocationAccuracyFuzzing.none) {
      return this;
    }

    double fuzzingFactor;
    switch (fuzzing) {
      case LocationAccuracyFuzzing.low:
        fuzzingFactor = 0.001; // ~100m
        break;
      case LocationAccuracyFuzzing.medium:
        fuzzingFactor = 0.01; // ~1km
        break;
      case LocationAccuracyFuzzing.high:
        fuzzingFactor = 0.1; // ~10km
        break;
      case LocationAccuracyFuzzing.none:
        return this;
    }

    final double fuzzedLat =
        (position.latitude / fuzzingFactor).round() * fuzzingFactor;
    final double fuzzedLng =
        (position.longitude / fuzzingFactor).round() * fuzzingFactor;

    final Position fuzzedPosition = Position(
      latitude: fuzzedLat,
      longitude: fuzzedLng,
      timestamp: position.timestamp,
      accuracy: position.accuracy,
      altitude: position.altitude,
      altitudeAccuracy: position.altitudeAccuracy,
      heading: position.heading,
      headingAccuracy: position.headingAccuracy,
      speed: position.speed,
      speedAccuracy: position.speedAccuracy,
    );

    return PhotoLocationData(
      position: fuzzedPosition,
      compassHeading: compassHeading,
      magneticDeclination: magneticDeclination,
      trueHeading: trueHeading,
      magnetometerData: magnetometerData,
      timestamp: timestamp,
      locationAccuracyData: locationAccuracyData,
    );
  }
}

/// Result of a photo capture operation
class PhotoCaptureResult {
  const PhotoCaptureResult({
    required this.success,
    this.photoWaypoint,
    this.waypoint,
    this.locationData,
    this.error,
  });

  /// Whether the capture was successful
  final bool success;

  /// The created photo waypoint (if successful)
  final PhotoWaypoint? photoWaypoint;

  /// The associated waypoint (if successful)
  final Waypoint? waypoint;

  /// Location data captured with the photo
  final PhotoLocationData? locationData;

  /// Error message (if failed)
  final String? error;
}

/// Service for capturing photos with camera integration and metadata extraction.
///
/// Handles camera initialization, photo capture with automatic geotagging,
/// EXIF metadata extraction, and integration with location services.
class PhotoCaptureService {
  factory PhotoCaptureService() => _instance ??= PhotoCaptureService._();
  PhotoCaptureService._();
  static PhotoCaptureService? _instance;

  static const Uuid _uuid = Uuid();

  camera_lib.CameraController? _cameraController;
  List<camera_lib.CameraDescription>? _cameras;
  bool _isInitialized = false;

  final DatabaseService _databaseService = DatabaseService();
  final PhotoStorageService _storageService = PhotoStorageService();
  // LocationService integration will be added later

  /// Privacy settings for photo geotagging
  PhotoPrivacySettings _privacySettings = const PhotoPrivacySettings();

  /// Camera resolution preset (from photo quality setting)
  camera_lib.ResolutionPreset _resolutionPreset = camera_lib.ResolutionPreset.max;

  /// Current compass heading (cached for performance)
  double? _lastCompassHeading;

  /// Current magnetometer data (cached for performance)
  Map<String, double>? _lastMagnetometerData;

  /// Check if the camera service is initialized
  bool get isInitialized =>
      _isInitialized && _cameraController?.value.isInitialized == true;

  /// Get available cameras
  List<camera_lib.CameraDescription>? get availableCameras => _cameras;

  /// Get current camera controller
  camera_lib.CameraController? get cameraController => _cameraController;

  /// Get current privacy settings
  PhotoPrivacySettings get privacySettings => _privacySettings;

  /// Update privacy settings
  void updatePrivacySettings(PhotoPrivacySettings settings) {
    _privacySettings = settings;
    debugPrint(
        'Updated photo privacy settings: GPS=${settings.enableGpsTagging}, Compass=${settings.enableCompassHeading}');
  }

  /// Update photo quality setting
  void updatePhotoQuality(PhotoQuality quality) {
    _resolutionPreset = _photoQualityToResolutionPreset(quality);
    debugPrint('Updated photo quality to: ${quality.displayName} (${_resolutionPreset.name})');
  }

  /// Convert PhotoQuality enum to camera ResolutionPreset
  camera_lib.ResolutionPreset _photoQualityToResolutionPreset(PhotoQuality quality) {
    switch (quality) {
      case PhotoQuality.high:
        return camera_lib.ResolutionPreset.high;
      case PhotoQuality.veryHigh:
        return camera_lib.ResolutionPreset.veryHigh;
      case PhotoQuality.ultraHigh:
        return camera_lib.ResolutionPreset.ultraHigh;
      case PhotoQuality.max:
        // iOS has a bug with ResolutionPreset.max causing crashes (flutter/flutter#163202)
        // Cap at ultraHigh on iOS until the bug is fixed
        return Platform.isIOS ? camera_lib.ResolutionPreset.ultraHigh : camera_lib.ResolutionPreset.max;
    }
  }

  /// Validate location data quality and provide user feedback
  Map<String, dynamic> validateLocationQuality(
      PhotoLocationData? locationData) {
    if (locationData == null) {
      return {
        'isValid': false,
        'quality': 'none',
        'message': 'No location data available',
        'recommendations': [
          'Enable GPS tagging in privacy settings',
          'Ensure location services are enabled'
        ],
      };
    }

    final Position position = locationData.position;
    final List<String> issues = <String>[];
    final List<String> recommendations = <String>[];
    String quality = 'excellent';

    // Check GPS accuracy
    if (position.accuracy > 50.0) {
      quality = 'poor';
      issues.add(
          'GPS accuracy is poor (${position.accuracy.toStringAsFixed(1)}m)');
      recommendations.add('Move to an area with better GPS reception');
    } else if (position.accuracy > 20.0) {
      quality = 'fair';
      issues.add(
          'GPS accuracy is moderate (${position.accuracy.toStringAsFixed(1)}m)');
    } else if (position.accuracy > 10.0) {
      quality = 'good';
    }

    // Check if we're indoors (poor GPS + no compass)
    if (position.accuracy > 30.0 && locationData.compassHeading == null) {
      issues.add('Possible indoor location detected');
      recommendations.add('Move outdoors for better GPS and compass accuracy');
    }

    // Check compass availability
    if (_privacySettings.enableCompassHeading &&
        locationData.compassHeading == null) {
      issues.add('Compass data not available');
      recommendations.add(
          'Calibrate device compass or move away from magnetic interference');
    }

    // Check altitude data
    if (position.altitude == 0.0) {
      issues.add('Altitude data not available');
    }

    return {
      'isValid': position.accuracy <=
          100.0, // Consider valid if accuracy is better than 100m
      'quality': quality,
      'accuracy': position.accuracy,
      'hasCompass': locationData.compassHeading != null,
      'hasAltitude': position.altitude != 0.0,
      'issues': issues,
      'recommendations': recommendations,
      'message': issues.isEmpty
          ? 'Location data quality is $quality'
          : 'Location data has ${issues.length} issue(s)',
    };
  }

  /// Get current compass heading
  Future<double?> _getCurrentCompassHeading() async {
    if (!_privacySettings.enableCompassHeading) {
      return null;
    }

    try {
      // TODO(dev): Implement compass functionality with flutter_compass
      // For now, return null - this will be enhanced in a future update
      debugPrint('Compass functionality not yet implemented');
      return null;
    } catch (e) {
      debugPrint('Error getting compass heading: $e');
    }

    return _lastCompassHeading; // Return cached value if available
  }

  /// Get current magnetometer data
  Future<Map<String, double>?> _getCurrentMagnetometerData() async {
    if (!_privacySettings.enableCompassHeading) {
      return null;
    }

    try {
      // TODO(dev): Implement magnetometer functionality with sensors_plus
      // For now, return null - this will be enhanced in a future update
      debugPrint('Magnetometer functionality not yet implemented');
      return null;
    } catch (e) {
      debugPrint('Error getting magnetometer data: $e');
    }

    return _lastMagnetometerData; // Return cached value if available
  }

  /// Calculate magnetic declination (simplified estimation)
  double? _calculateMagneticDeclination(double latitude, double longitude) {
    // This is a simplified calculation - in production, you'd use a proper
    // magnetic declination model like WMM (World Magnetic Model)
    // For now, we'll use a basic approximation

    // Rough approximation based on location (this is not accurate for all locations)
    // In a real implementation, you'd use a proper geomagnetic model
    final double approxDeclination = (longitude - 90.0) * 0.1;
    return approxDeclination.clamp(-30.0, 30.0);
  }

  /// Get comprehensive location data for photo capture
  Future<PhotoLocationData?> _getPhotoLocationData() async {
    if (!_privacySettings.enableGpsTagging) {
      debugPrint('GPS tagging disabled by privacy settings');
      return null;
    }

    try {
      // Check location permissions first
      final LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied, cannot capture GPS data');
        return null;
      }

      // Check if location services are enabled
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services disabled, cannot capture GPS data');
        return null;
      }

      // Get GPS position with high accuracy
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // Validate GPS data quality
      if (position.accuracy > 100.0) {
        debugPrint('Warning: GPS accuracy is poor (${position.accuracy}m)');
      }

      // Get compass heading if enabled
      double? compassHeading;
      double? magneticDeclination;
      double? trueHeading;
      Map<String, double>? magnetometerData;

      if (_privacySettings.enableCompassHeading) {
        compassHeading = await _getCurrentCompassHeading();
        magnetometerData = await _getCurrentMagnetometerData();

        if (compassHeading != null) {
          magneticDeclination = _calculateMagneticDeclination(
            position.latitude,
            position.longitude,
          );

          if (magneticDeclination != null) {
            trueHeading = (compassHeading + magneticDeclination) % 360;
          }
        }
      }

      final locationData = PhotoLocationData(
        position: position,
        compassHeading: compassHeading,
        magneticDeclination: magneticDeclination,
        trueHeading: trueHeading,
        magnetometerData: magnetometerData,
        timestamp: DateTime.now(),
        locationAccuracyData: <String, double>{
          'horizontal_accuracy': position.accuracy,
          'altitude_accuracy': position.altitudeAccuracy,
          'speed_accuracy': position.speedAccuracy,
          'heading_accuracy': position.headingAccuracy,
        },
      );

      // Apply privacy fuzzing if configured
      return locationData
          .applyPrivacyFuzzing(_privacySettings.locationAccuracyFuzzing);
    } catch (e) {
      debugPrint('Error getting photo location data: $e');
      return null;
    }
  }

  /// Open iOS Settings app for camera permissions
  Future<void> _openIOSSettings() async {
    if (Platform.isIOS) {
      try {
        debugPrint('Opening iOS Settings for camera permissions');
        await openAppSettings();
      } catch (e) {
        debugPrint('Failed to open iOS Settings: $e');
      }
    }
  }

  /// Check if iOS permission request can be made
  Future<bool> _canRequestIOSPermission() async {
    try {
      // Check if permission_handler is properly configured for iOS
      final PermissionStatus status = await Permission.camera.status;
      debugPrint('iOS permission status check successful: $status');
      return true;
    } catch (e) {
      debugPrint('iOS permission status check failed: $e');
      return false;
    }
  }

  /// Request iOS camera permission with enhanced error handling
  Future<PermissionStatus> _requestIOSCameraPermission() async {
    debugPrint('iOS: Starting enhanced camera permission request...');

    try {
      // Check current status before requesting
      final PermissionStatus currentStatus = await Permission.camera.status;
      debugPrint('iOS: Current permission status: $currentStatus');

      if (currentStatus.isGranted) {
        debugPrint('iOS: Permission already granted');
        return currentStatus;
      }

      if (currentStatus.isPermanentlyDenied) {
        debugPrint('iOS: Permission permanently denied');
        return currentStatus;
      }

      // Make the permission request
      debugPrint('iOS: Calling Permission.camera.request()...');
      final PermissionStatus requestResult = await Permission.camera.request();
      debugPrint(
          'iOS: Permission request completed with result: $requestResult');

      // Verify the result
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final PermissionStatus verifiedStatus = await Permission.camera.status;
      debugPrint('iOS: Verified permission status: $verifiedStatus');

      return verifiedStatus;
    } catch (e) {
      debugPrint('iOS: Error during permission request: $e');
      rethrow;
    }
  }

  /// Check if camera is supported on this platform
  bool get isCameraSupported {
    if (kIsWeb) return false;
    // Desktop platforms don't have camera hardware accessible via Flutter camera plugin
    return Platform.isIOS || Platform.isAndroid;
  }

  /// Initialize the camera service with enhanced iOS support
  Future<bool> initialize() async {
    try {
      debugPrint('Starting camera service initialization...');

      // Desktop platforms don't support camera capture
      if (!isCameraSupported) {
        debugPrint('Camera not supported on desktop platform - use importPhotoFromFile instead');
        throw const CameraInitializationException(
          'Camera capture is not available on desktop. Use the photo import feature to add photos from files.',
          CameraErrorType.noCamerasAvailable,
        );
      }

      // Enhanced iOS-specific camera permission checking
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint('iOS detected - performing enhanced permission checks');

        // First check if we can make permission requests
        final bool canRequestPermission = await _canRequestIOSPermission();
        if (!canRequestPermission) {
          throw const CameraInitializationException(
            'iOS permission system is not properly configured. Please check permission_handler setup.',
            CameraErrorType.initializationFailed,
            isIOS: true,
          );
        }

        // Check camera permission status first
        final PermissionStatus initialPermission =
            await Permission.camera.status;
        debugPrint('iOS initial camera permission status: $initialPermission');
        debugPrint('iOS permission isGranted: ${initialPermission.isGranted}');
        debugPrint('iOS permission isDenied: ${initialPermission.isDenied}');
        debugPrint(
            'iOS permission isPermanentlyDenied: ${initialPermission.isPermanentlyDenied}');
        debugPrint(
            'iOS permission isRestricted: ${initialPermission.isRestricted}');
        debugPrint('iOS permission isLimited: ${initialPermission.isLimited}');

        if (initialPermission == PermissionStatus.permanentlyDenied) {
          debugPrint(
              'iOS camera permission permanently denied - directing user to settings');
          // Attempt to open settings for user convenience
          await _openIOSSettings();
          throw const CameraInitializationException(
            'Camera access has been permanently denied. Please enable camera access in iOS Settings > Privacy & Security > Camera > Obsession Tracker to take photos.',
            CameraErrorType.permissionDenied,
            isIOS: true,
          );
        }

        if (!initialPermission.isGranted) {
          debugPrint(
              'iOS camera permission not granted - requesting permission');

          // Check app lifecycle state for iOS permission dialog
          final AppLifecycleState? appState =
              WidgetsBinding.instance.lifecycleState;
          debugPrint('iOS app lifecycle state: $appState');

          if (appState != AppLifecycleState.resumed) {
            debugPrint(
                'iOS WARNING: App not in resumed state, permission dialog may not appear');
          }

          // Use enhanced iOS permission request method
          final PermissionStatus requestResult =
              await _requestIOSCameraPermission();

          if (!requestResult.isGranted) {
            debugPrint(
                'iOS camera permission verification failed: $requestResult');

            if (requestResult == PermissionStatus.permanentlyDenied) {
              debugPrint(
                  'iOS camera permission permanently denied after request');
              // Attempt to open settings for user convenience
              await _openIOSSettings();
              throw const CameraInitializationException(
                'Camera access has been permanently denied. Please enable camera access in iOS Settings > Privacy & Security > Camera > Obsession Tracker to take photos.',
                CameraErrorType.permissionDenied,
                isIOS: true,
              );
            } else {
              throw const CameraInitializationException(
                'Camera access is required to take photos. Please grant camera permission and try again.',
                CameraErrorType.permissionDenied,
                isIOS: true,
              );
            }
          }
        }

        debugPrint('iOS camera permission granted successfully');
      } else {
        // Standard Android permission handling
        debugPrint('Android detected - performing standard permission checks');
        final PermissionStatus cameraPermission =
            await Permission.camera.status;
        if (!cameraPermission.isGranted) {
          final PermissionStatus requestResult =
              await Permission.camera.request();
          if (!requestResult.isGranted) {
            throw const CameraInitializationException(
              'Camera permission is required to take photos. Please grant camera permission and try again.',
              CameraErrorType.permissionDenied,
            );
          }
        }
      }

      // Get available cameras - CRITICAL FIX: Call as function, not property
      debugPrint('Getting available cameras...');
      // Use import prefix to avoid conflict with the getter
      final List<camera_lib.CameraDescription> availableCamerasList =
          await camera_lib.availableCameras();
      _cameras = availableCamerasList;
      debugPrint('Found ${_cameras?.length ?? 0} available cameras');

      if (_cameras == null || _cameras!.isEmpty) {
        debugPrint('No cameras available on device');
        throw CameraInitializationException(
          defaultTargetPlatform == TargetPlatform.iOS
              ? 'No cameras found on your device. Please ensure your device has a working camera and try again.'
              : 'No cameras available on this device.',
          CameraErrorType.noCamerasAvailable,
          isIOS: defaultTargetPlatform == TargetPlatform.iOS,
        );
      }

      // Log available cameras for debugging
      for (int i = 0; i < _cameras!.length; i++) {
        final camera = _cameras![i];
        debugPrint('Camera $i: ${camera.name} (${camera.lensDirection})');
      }

      // Initialize camera controller with the first available camera (usually back camera)
      final camera_lib.CameraDescription camera = _cameras!.first;
      debugPrint('Initializing camera controller with: ${camera.name}');

      // Only specify imageFormatGroup on Android - iOS doesn't support JPEG format
      // for video output and will crash with "Unsupported pixel format type"
      _cameraController = camera_lib.CameraController(
        camera,
        _resolutionPreset,
        enableAudio: false, // We don't need audio for photos
        imageFormatGroup: Platform.isAndroid ? camera_lib.ImageFormatGroup.jpeg : null,
      );

      debugPrint('Initializing camera controller with resolution: ${_resolutionPreset.name}...');
      await _cameraController!.initialize();
      _isInitialized = true;

      debugPrint('Camera service initialized successfully');
      debugPrint('Camera resolution: ${_cameraController!.value.previewSize}');
      return true;
    } on CameraInitializationException {
      // Re-throw our custom exceptions
      rethrow;
    } catch (e) {
      debugPrint('Error initializing camera service: $e');
      _isInitialized = false;

      // Provide user-friendly error messages based on platform and error type
      String userMessage;
      CameraErrorType errorType;

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        if (e.toString().contains('permission') ||
            e.toString().contains('authorized')) {
          userMessage =
              'Camera access is required to take photos. Please enable camera access in iOS Settings > Privacy & Security > Camera > Obsession Tracker.';
          errorType = CameraErrorType.permissionDenied;
        } else if (e.toString().contains('camera') &&
            e.toString().contains('use')) {
          userMessage =
              'Camera is currently being used by another app. Please close other camera apps and try again.';
          errorType = CameraErrorType.cameraInUse;
        } else {
          userMessage =
              'Unable to initialize camera on iOS. Please restart the app and try again. If the problem persists, restart your device.';
          errorType = CameraErrorType.initializationFailed;
        }
      } else {
        userMessage =
            'Unable to initialize camera. Please check that your device has a working camera and try again.';
        errorType = CameraErrorType.initializationFailed;
      }

      throw CameraInitializationException(
        userMessage,
        errorType,
        isIOS: defaultTargetPlatform == TargetPlatform.iOS,
        originalError: e.toString(),
      );
    }
  }

  /// Switch to a different camera (e.g., front/back)
  Future<bool> switchCamera(camera_lib.CameraDescription camera) async {
    try {
      if (_cameraController != null) {
        await _cameraController!.dispose();
      }

      // Only specify imageFormatGroup on Android - iOS doesn't support JPEG format
      _cameraController = camera_lib.CameraController(
        camera,
        _resolutionPreset,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? camera_lib.ImageFormatGroup.jpeg : null,
      );

      await _cameraController!.initialize();
      debugPrint('Switched to camera: ${camera.name}');
      return true;
    } catch (e) {
      debugPrint('Error switching camera: $e');
      return false;
    }
  }

  /// Capture a photo and create a photo waypoint
  Future<PhotoCaptureResult> capturePhotoWaypoint({
    required String sessionId,
    required WaypointType waypointType,
    String? waypointName,
    String? waypointNotes,
    double? devicePitch,
    double? deviceRoll,
    double? deviceYaw,
  }) async {
    try {
      if (!isInitialized) {
        return const PhotoCaptureResult(
          success: false,
          error: 'Camera not initialized',
        );
      }

      // Get comprehensive location data with privacy settings
      PhotoLocationData? locationData;
      Position? position;
      try {
        locationData = await _getPhotoLocationData();
        position = locationData?.position;
      } catch (e) {
        debugPrint('Warning: Could not get current location: $e');
      }

      // Capture the photo
      final camera_lib.XFile photoFile = await _cameraController!.takePicture();
      Uint8List photoData = await photoFile.readAsBytes();

      // Write GPS data to EXIF if enabled and location is available
      if (_privacySettings.enableExifGpsWriting && locationData != null) {
        photoData = await _writeGpsToExif(photoData, locationData);
      }

      // Generate unique IDs
      final String waypointId = _uuid.v4();
      final String photoWaypointId = _uuid.v4();
      final DateTime now = DateTime.now();

      // Save photo to app storage for immediate preview and persistence
      final String photoPath = await _storageService.storePhoto(
        sessionId: sessionId,
        photoData: photoData,
      );

      // Get image dimensions from data
      final decodedImage = img.decodeImage(photoData);
      final int? width = decodedImage?.width;
      final int? height = decodedImage?.height;
      final int fileSize = photoData.length;

      // Determine photo orientation from device sensors (roll), not pixel dimensions
      // This is important because camera may be locked in portrait mode, so pixels
      // are always portrait-oriented regardless of how the user holds the phone.
      // Roll values: ~0° = portrait, ~±90° = landscape
      String? photoOrientation;
      if (deviceRoll != null) {
        // Roll angle between 45° and 135° (or -45° and -135°) indicates landscape
        final absRoll = deviceRoll.abs();
        if (absRoll > 45 && absRoll < 135) {
          photoOrientation = 'landscape';
          debugPrint('📷 Photo orientation: landscape (roll=${deviceRoll.toStringAsFixed(1)}°)');
        } else {
          photoOrientation = 'portrait';
          debugPrint('📷 Photo orientation: portrait (roll=${deviceRoll.toStringAsFixed(1)}°)');
        }
      } else if (width != null && height != null) {
        // Fallback to pixel dimensions if no sensor data available
        if (width > height) {
          photoOrientation = 'landscape';
        } else if (height > width) {
          photoOrientation = 'portrait';
        } else {
          photoOrientation = 'square';
        }
        debugPrint('📷 Photo orientation from pixels: $photoOrientation (${width}x$height)');
      }

      // Calculate camera tilt angle from pitch and roll
      double? cameraTiltAngle;
      if (devicePitch != null && deviceRoll != null) {
        // Calculate combined tilt magnitude using Pythagorean theorem
        cameraTiltAngle = math.sqrt(
          devicePitch * devicePitch + deviceRoll * deviceRoll,
        );
      }

      // Create waypoint
      final Waypoint waypoint = Waypoint.fromLocation(
        id: waypointId,
        latitude: position?.latitude ?? 0.0,
        longitude: position?.longitude ?? 0.0,
        type: waypointType,
        timestamp: now,
        sessionId: sessionId,
        name: waypointName,
        notes: waypointNotes,
        altitude: position?.altitude,
        accuracy: position?.accuracy,
        speed: position?.speed,
        heading: position?.heading,
      );

      // Create photo waypoint with persistent file path and orientation metadata
      final PhotoWaypoint photoWaypoint = PhotoWaypoint(
        id: photoWaypointId,
        waypointId: waypointId,
        filePath: photoPath, // Persistent app storage path
        createdAt: now,
        fileSize: fileSize,
        width: width,
        height: height,
        devicePitch: devicePitch,
        deviceRoll: deviceRoll,
        deviceYaw: deviceYaw,
        photoOrientation: photoOrientation,
        cameraTiltAngle: cameraTiltAngle,
      );

      // Save to database
      await _databaseService.insertWaypoint(waypoint);
      await _insertPhotoWaypoint(photoWaypoint);

      // Extract and save EXIF metadata
      await _extractAndSaveExifMetadata(photoData, photoWaypointId);

      // Save comprehensive location metadata if available
      if (locationData != null) {
        await _saveEnhancedLocationMetadata(locationData, photoWaypointId);
      } else if (position != null) {
        // Fallback to basic location metadata
        await _saveLocationMetadata(position, photoWaypointId);
      }

      debugPrint('Successfully captured photo waypoint: $photoWaypointId');
      return PhotoCaptureResult(
        success: true,
        photoWaypoint: photoWaypoint,
        waypoint: waypoint,
        locationData: locationData,
      );
    } catch (e) {
      debugPrint('Error capturing photo waypoint: $e');
      return PhotoCaptureResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Create a photo waypoint from external bytes (e.g., Meta glasses)
  ///
  /// This method allows creating photo waypoints from photo data received
  /// from external sources like Ray-Ban Meta smart glasses, using the
  /// phone's GPS and orientation data.
  Future<PhotoCaptureResult> createPhotoWaypointFromBytes({
    required String sessionId,
    required Uint8List photoData,
    required WaypointType waypointType,
    String? waypointName,
    String? waypointNotes,
    String? source,
    double? devicePitch,
    double? deviceRoll,
    double? deviceYaw,
  }) async {
    try {
      // Get comprehensive location data with privacy settings
      PhotoLocationData? locationData;
      Position? position;
      try {
        locationData = await _getPhotoLocationData();
        position = locationData?.position;
      } catch (e) {
        debugPrint('Warning: Could not get current location: $e');
      }

      // Write GPS data to EXIF if enabled and location is available
      Uint8List processedPhotoData = photoData;
      if (_privacySettings.enableExifGpsWriting && locationData != null) {
        processedPhotoData = await _writeGpsToExif(photoData, locationData);
      }

      // Generate unique IDs
      final String waypointId = _uuid.v4();
      final String photoWaypointId = _uuid.v4();
      final DateTime now = DateTime.now();

      // Save photo to app storage
      final String photoPath = await _storageService.storePhoto(
        sessionId: sessionId,
        photoData: processedPhotoData,
      );

      // Get image dimensions from data
      final decodedImage = img.decodeImage(processedPhotoData);
      final int? width = decodedImage?.width;
      final int? height = decodedImage?.height;
      final int fileSize = processedPhotoData.length;

      // Determine photo orientation from device sensors (roll), not pixel dimensions
      // This is important because camera may be locked in portrait mode, so pixels
      // are always portrait-oriented regardless of how the user holds the phone.
      // Roll values: ~0° = portrait, ~±90° = landscape
      String? photoOrientation;
      if (deviceRoll != null) {
        // Roll angle between 45° and 135° (or -45° and -135°) indicates landscape
        final absRoll = deviceRoll.abs();
        if (absRoll > 45 && absRoll < 135) {
          photoOrientation = 'landscape';
          debugPrint('📷 Photo orientation: landscape (roll=${deviceRoll.toStringAsFixed(1)}°)');
        } else {
          photoOrientation = 'portrait';
          debugPrint('📷 Photo orientation: portrait (roll=${deviceRoll.toStringAsFixed(1)}°)');
        }
      } else if (width != null && height != null) {
        // Fallback to pixel dimensions if no sensor data available
        if (width > height) {
          photoOrientation = 'landscape';
        } else if (height > width) {
          photoOrientation = 'portrait';
        } else {
          photoOrientation = 'square';
        }
        debugPrint('📷 Photo orientation from pixels: $photoOrientation (${width}x$height)');
      }

      // Calculate camera tilt angle from pitch and roll
      double? cameraTiltAngle;
      if (devicePitch != null && deviceRoll != null) {
        cameraTiltAngle = math.sqrt(
          devicePitch * devicePitch + deviceRoll * deviceRoll,
        );
      }

      // Create waypoint
      final Waypoint waypoint = Waypoint.fromLocation(
        id: waypointId,
        latitude: position?.latitude ?? 0.0,
        longitude: position?.longitude ?? 0.0,
        type: waypointType,
        timestamp: now,
        sessionId: sessionId,
        name: waypointName,
        notes: waypointNotes,
        altitude: position?.altitude,
        accuracy: position?.accuracy,
        speed: position?.speed,
        heading: position?.heading,
      );

      // Create photo waypoint with source tracking
      final PhotoWaypoint photoWaypoint = PhotoWaypoint(
        id: photoWaypointId,
        waypointId: waypointId,
        filePath: photoPath,
        createdAt: now,
        fileSize: fileSize,
        width: width,
        height: height,
        devicePitch: devicePitch,
        deviceRoll: deviceRoll,
        deviceYaw: deviceYaw,
        photoOrientation: photoOrientation,
        cameraTiltAngle: cameraTiltAngle,
        source: source ?? 'external',
      );

      // Save to database
      await _databaseService.insertWaypoint(waypoint);
      await _insertPhotoWaypoint(photoWaypoint);

      // Extract and save EXIF metadata
      await _extractAndSaveExifMetadata(processedPhotoData, photoWaypointId);

      // Save comprehensive location metadata if available
      if (locationData != null) {
        await _saveEnhancedLocationMetadata(locationData, photoWaypointId);
      } else if (position != null) {
        await _saveLocationMetadata(position, photoWaypointId);
      }

      debugPrint('Successfully created photo waypoint from external source: $photoWaypointId');
      return PhotoCaptureResult(
        success: true,
        photoWaypoint: photoWaypoint,
        waypoint: waypoint,
        locationData: locationData,
      );
    } catch (e) {
      debugPrint('Error creating photo waypoint from bytes: $e');
      return PhotoCaptureResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Insert a photo waypoint into the database
  Future<void> _insertPhotoWaypoint(PhotoWaypoint photoWaypoint) async {
    final Database db = await _databaseService.database;
    await db.insert(
      'photo_waypoints',
      photoWaypoint.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Extract EXIF metadata from photo data and save to database
  Future<void> _extractAndSaveExifMetadata(
    Uint8List photoData,
    String photoWaypointId,
  ) async {
    try {
      final Map<String, IfdTag> exifData = await readExifFromBytes(photoData);

      if (exifData.isEmpty) {
        debugPrint('No EXIF data found in photo');
        return;
      }

      final List<PhotoMetadata> metadataList = <PhotoMetadata>[];
      int metadataId = 0; // Will be auto-incremented by database

      // Extract common EXIF fields
      final Map<String, String> exifMappings = <String, String>{
        'Image Make': ExifKeys.cameraMake,
        'Image Model': ExifKeys.cameraModel,
        'EXIF ISOSpeedRatings': ExifKeys.iso,
        'EXIF FNumber': ExifKeys.aperture,
        'EXIF ExposureTime': ExifKeys.shutterSpeed,
        'EXIF FocalLength': ExifKeys.focalLength,
        'EXIF Flash': ExifKeys.flash,
        'Image Orientation': ExifKeys.orientation,
        'Image DateTime': ExifKeys.dateTime,
        'GPS GPSLatitude': ExifKeys.gpsLatitude,
        'GPS GPSLongitude': ExifKeys.gpsLongitude,
        'GPS GPSAltitude': ExifKeys.gpsAltitude,
      };

      for (final MapEntry<String, String> mapping in exifMappings.entries) {
        final IfdTag? tag = exifData[mapping.key];
        if (tag != null) {
          final String value = tag.toString();
          metadataList.add(PhotoMetadata.string(
            id: metadataId++,
            photoWaypointId: photoWaypointId,
            key: mapping.value,
            value: value,
          ));
        }
      }

      // Save all metadata to database
      for (final PhotoMetadata metadata in metadataList) {
        await _insertPhotoMetadata(metadata);
      }

      debugPrint(
          'Extracted and saved ${metadataList.length} EXIF metadata entries');
    } catch (e) {
      debugPrint('Error extracting EXIF metadata: $e');
    }
  }

  /// Save location metadata to database
  Future<void> _saveLocationMetadata(
    Position position,
    String photoWaypointId,
  ) async {
    try {
      final List<PhotoMetadata> locationMetadata = <PhotoMetadata>[
        PhotoMetadata.double(
          id: 0,
          photoWaypointId: photoWaypointId,
          key: 'location_latitude',
          value: position.latitude,
        ),
        PhotoMetadata.double(
          id: 0,
          photoWaypointId: photoWaypointId,
          key: 'location_longitude',
          value: position.longitude,
        ),
        PhotoMetadata.double(
          id: 0,
          photoWaypointId: photoWaypointId,
          key: 'location_accuracy',
          value: position.accuracy,
        ),
      ];

      locationMetadata.add(PhotoMetadata.double(
        id: 0,
        photoWaypointId: photoWaypointId,
        key: 'location_altitude',
        value: position.altitude,
      ));

      locationMetadata.add(PhotoMetadata.double(
        id: 0,
        photoWaypointId: photoWaypointId,
        key: 'location_speed',
        value: position.speed,
      ));

      locationMetadata.add(PhotoMetadata.double(
        id: 0,
        photoWaypointId: photoWaypointId,
        key: 'location_heading',
        value: position.heading,
      ));

      for (final PhotoMetadata metadata in locationMetadata) {
        await _insertPhotoMetadata(metadata);
      }

      debugPrint('Saved location metadata for photo waypoint');
    } catch (e) {
      debugPrint('Error saving location metadata: $e');
    }
  }

  /// Save enhanced location metadata including compass data to database
  Future<void> _saveEnhancedLocationMetadata(
    PhotoLocationData locationData,
    String photoWaypointId,
  ) async {
    try {
      final List<PhotoMetadata> metadataList = <PhotoMetadata>[];

      // Basic GPS data
      metadataList.addAll([
        PhotoMetadata.double(
          id: 0,
          photoWaypointId: photoWaypointId,
          key: 'location_latitude',
          value: locationData.position.latitude,
        ),
        PhotoMetadata.double(
          id: 0,
          photoWaypointId: photoWaypointId,
          key: 'location_longitude',
          value: locationData.position.longitude,
        ),
        PhotoMetadata.double(
          id: 0,
          photoWaypointId: photoWaypointId,
          key: 'location_accuracy',
          value: locationData.position.accuracy,
        ),
      ]);

      // Optional GPS data
      if (locationData.position.altitude != 0.0) {
        metadataList.add(PhotoMetadata.double(
          id: 0,
          photoWaypointId: photoWaypointId,
          key: 'location_altitude',
          value: locationData.position.altitude,
        ));
      }

      if (locationData.position.speed >= 0) {
        metadataList.add(PhotoMetadata.double(
          id: 0,
          photoWaypointId: photoWaypointId,
          key: 'location_speed',
          value: locationData.position.speed,
        ));
      }

      if (locationData.position.heading >= 0 &&
          locationData.position.heading <= 360) {
        metadataList.add(PhotoMetadata.double(
          id: 0,
          photoWaypointId: photoWaypointId,
          key: 'location_gps_heading',
          value: locationData.position.heading,
        ));
      }

      // Compass data
      if (locationData.compassHeading != null) {
        metadataList.add(PhotoMetadata.double(
          id: 0,
          photoWaypointId: photoWaypointId,
          key: 'compass_heading',
          value: locationData.compassHeading!,
        ));
      }

      if (locationData.trueHeading != null) {
        metadataList.add(PhotoMetadata.double(
          id: 0,
          photoWaypointId: photoWaypointId,
          key: 'compass_true_heading',
          value: locationData.trueHeading!,
        ));
      }

      if (locationData.magneticDeclination != null) {
        metadataList.add(PhotoMetadata.double(
          id: 0,
          photoWaypointId: photoWaypointId,
          key: 'compass_magnetic_declination',
          value: locationData.magneticDeclination!,
        ));
      }

      // Magnetometer data
      if (locationData.magnetometerData != null) {
        final magnetometerData = locationData.magnetometerData!;
        metadataList.addAll([
          PhotoMetadata.double(
            id: 0,
            photoWaypointId: photoWaypointId,
            key: 'magnetometer_x',
            value: magnetometerData['x'] ?? 0.0,
          ),
          PhotoMetadata.double(
            id: 0,
            photoWaypointId: photoWaypointId,
            key: 'magnetometer_y',
            value: magnetometerData['y'] ?? 0.0,
          ),
          PhotoMetadata.double(
            id: 0,
            photoWaypointId: photoWaypointId,
            key: 'magnetometer_z',
            value: magnetometerData['z'] ?? 0.0,
          ),
        ]);
      }

      // Location accuracy data
      if (locationData.locationAccuracyData != null) {
        final accuracyData = locationData.locationAccuracyData!;
        for (final entry in accuracyData.entries) {
          metadataList.add(PhotoMetadata.double(
            id: 0,
            photoWaypointId: photoWaypointId,
            key: 'accuracy_${entry.key}',
            value: entry.value,
          ));
        }
      }

      // Timestamp
      if (locationData.timestamp != null) {
        metadataList.add(PhotoMetadata.datetime(
          id: 0,
          photoWaypointId: photoWaypointId,
          key: 'location_timestamp',
          value: locationData.timestamp!,
        ));
      }

      // Privacy settings applied
      metadataList.addAll([
        PhotoMetadata.boolean(
          id: 0,
          photoWaypointId: photoWaypointId,
          key: 'privacy_gps_enabled',
          value: _privacySettings.enableGpsTagging,
        ),
        PhotoMetadata.boolean(
          id: 0,
          photoWaypointId: photoWaypointId,
          key: 'privacy_compass_enabled',
          value: _privacySettings.enableCompassHeading,
        ),
        PhotoMetadata.string(
          id: 0,
          photoWaypointId: photoWaypointId,
          key: 'privacy_fuzzing_level',
          value: _privacySettings.locationAccuracyFuzzing.name,
        ),
      ]);

      // Save all metadata to database
      for (final PhotoMetadata metadata in metadataList) {
        await _insertPhotoMetadata(metadata);
      }

      debugPrint(
          'Saved ${metadataList.length} enhanced location metadata entries');
    } catch (e) {
      debugPrint('Error saving enhanced location metadata: $e');
    }
  }

  /// Insert photo metadata into the database
  Future<void> _insertPhotoMetadata(PhotoMetadata metadata) async {
    final Database db = await _databaseService.database;
    await db.insert(
      'photo_metadata',
      metadata.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Write GPS coordinates to EXIF data in photo
  Future<Uint8List> _writeGpsToExif(
      Uint8List photoData, PhotoLocationData locationData) async {
    try {
      // Note: The current exif package is primarily for reading EXIF data
      // Writing GPS data to EXIF requires more complex implementation
      // For now, we'll return the original photo data and log the GPS info
      // In a production app, you'd use a more comprehensive EXIF library

      debugPrint('GPS data to write to EXIF:');
      debugPrint('  Latitude: ${locationData.position.latitude}');
      debugPrint('  Longitude: ${locationData.position.longitude}');
      debugPrint('  Altitude: ${locationData.position.altitude}');
      debugPrint('  Compass Heading: ${locationData.compassHeading}');
      debugPrint('  True Heading: ${locationData.trueHeading}');

      // TODO(dev): Implement actual EXIF GPS writing
      // This would require a library like 'exif_writer' or native platform code
      // For now, we store the GPS data in our metadata system instead

      return photoData;
    } catch (e) {
      debugPrint('Error writing GPS to EXIF: $e');
      return photoData; // Return original data on error
    }
  }

  /// Get photo waypoints for a waypoint
  Future<List<PhotoWaypoint>> getPhotoWaypointsForWaypoint(
      String waypointId) async {
    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'photo_waypoints',
        where: 'waypoint_id = ?',
        whereArgs: <Object?>[waypointId],
        orderBy: 'created_at ASC',
      );

      return maps.map(PhotoWaypoint.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting photo waypoints: $e');
      return <PhotoWaypoint>[];
    }
  }

  /// Get photo metadata for a photo waypoint
  Future<List<PhotoMetadata>> getPhotoMetadata(String photoWaypointId) async {
    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'photo_metadata',
        where: 'photo_waypoint_id = ?',
        whereArgs: <Object?>[photoWaypointId],
        orderBy: 'key ASC',
      );

      return maps.map(PhotoMetadata.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting photo metadata: $e');
      return <PhotoMetadata>[];
    }
  }

  /// Get photo waypoints for a session with pagination
  Future<List<PhotoWaypoint>> getPhotoWaypointsForSession(
    String sessionId, {
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT pw.* FROM photo_waypoints pw
        INNER JOIN waypoints w ON pw.waypoint_id = w.id
        WHERE w.session_id = ?
        ORDER BY pw.created_at DESC
        LIMIT ? OFFSET ?
      ''', <Object?>[sessionId, limit, offset]);

      return maps.map(PhotoWaypoint.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting photo waypoints for session: $e');
      return <PhotoWaypoint>[];
    }
  }

  /// Get all photo waypoints for a session
  Future<List<PhotoWaypoint>> getAllPhotoWaypointsForSession(
      String sessionId) async {
    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT pw.* FROM photo_waypoints pw
        INNER JOIN waypoints w ON pw.waypoint_id = w.id
        WHERE w.session_id = ?
        ORDER BY pw.created_at DESC
      ''', <Object?>[sessionId]);

      return maps.map(PhotoWaypoint.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting all photo waypoints for session: $e');
      return <PhotoWaypoint>[];
    }
  }

  /// Delete a photo waypoint and its associated files
  Future<bool> deletePhotoWaypoint(PhotoWaypoint photoWaypoint) async {
    try {
      final Database db = await _databaseService.database;

      // Delete from database
      await db.delete(
        'photo_waypoints',
        where: 'id = ?',
        whereArgs: <Object?>[photoWaypoint.id],
      );

      // Delete photo files
      final String sessionId = photoWaypoint
          .waypointId; // Assuming we can derive session from waypoint
      await _storageService.deletePhoto(
        photoPath: photoWaypoint.filePath,
        sessionId: sessionId,
      );

      debugPrint('Deleted photo waypoint: ${photoWaypoint.id}');
      return true;
    } catch (e) {
      debugPrint('Error deleting photo waypoint: $e');
      return false;
    }
  }

  /// Import a photo from file picker (for desktop platforms)
  ///
  /// Opens a file picker dialog and creates a photo waypoint from the selected image.
  /// This is the primary method for adding photos on desktop platforms where
  /// camera capture is not available.
  Future<PhotoCaptureResult> importPhotoFromFile({
    required String sessionId,
    required WaypointType waypointType,
    String? waypointName,
    String? waypointNotes,
  }) async {
    try {
      // Open file picker for images
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return const PhotoCaptureResult(
          success: false,
          error: 'No file selected',
        );
      }

      final PlatformFile pickedFile = result.files.first;

      // Get file bytes
      Uint8List? photoData = pickedFile.bytes;
      if (photoData == null && pickedFile.path != null) {
        // Read from file path if bytes not available
        final File file = File(pickedFile.path!);
        photoData = await file.readAsBytes();
      }

      if (photoData == null) {
        return const PhotoCaptureResult(
          success: false,
          error: 'Could not read file data',
        );
      }

      // Use the existing createPhotoWaypointFromBytes method
      return await createPhotoWaypointFromBytes(
        sessionId: sessionId,
        photoData: photoData,
        waypointType: waypointType,
        waypointName: waypointName ?? pickedFile.name,
        waypointNotes: waypointNotes,
        source: 'file_import',
      );
    } catch (e) {
      debugPrint('Error importing photo from file: $e');
      return PhotoCaptureResult(
        success: false,
        error: 'Failed to import photo: $e',
      );
    }
  }

  /// Dispose of the camera service
  Future<void> dispose() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }
    _isInitialized = false;
    _instance = null;
  }
}
