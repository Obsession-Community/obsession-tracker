import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/photo_provider.dart';
import 'package:obsession_tracker/core/services/accelerometer_service.dart';
import 'package:obsession_tracker/core/services/enhanced_compass_service.dart';
import 'package:obsession_tracker/core/services/photo_capture_service.dart';
import 'package:obsession_tracker/core/utils/coordinate_formatter.dart';
import 'package:obsession_tracker/core/utils/orientation_calculator.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/camera_hud_overlay.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Camera preview page for capturing photos with live preview and location overlay
class CameraPreviewPage extends ConsumerStatefulWidget {
  const CameraPreviewPage({
    required this.sessionId,
    super.key,
    this.waypointType = WaypointType.photo,
    this.waypointName,
    this.waypointNotes,
    this.onPhotoCapture,
  });

  final String sessionId;
  final WaypointType waypointType;
  final String? waypointName;
  final String? waypointNotes;
  final void Function(PhotoCaptureResult result)? onPhotoCapture;

  @override
  ConsumerState<CameraPreviewPage> createState() => _CameraPreviewPageState();
}

class _CameraPreviewPageState extends ConsumerState<CameraPreviewPage>
    with WidgetsBindingObserver {
  PhotoCaptureService? _photoCaptureService;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _initializationError;

  // Location tracking
  Position? _currentPosition;
  Timer? _locationTimer;
  bool _isLocationLoading = true;

  // Camera controls
  bool _isFlashOn = false;
  int _currentCameraIndex = 0;

  // Photo preview
  PhotoCaptureResult? _capturedPhoto;
  bool _showPhotoPreview = false;

  // HUD overlay
  bool _showHUD = false;
  double _pitch = 0.0;
  double _roll = 0.0;
  double _heading = 0.0;
  bool _useImperialUnits = true;
  CoordinateFormat _coordinateFormat = CoordinateFormat.decimal;

  // Sensor services
  final AccelerometerService _accelerometerService = AccelerometerService();
  final EnhancedCompassService _compassService = EnhancedCompassService();
  StreamSubscription<AccelerometerReading>? _accelerometerSubscription;
  StreamSubscription<EnhancedCompassReading>? _compassSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _startLocationTracking();
    _initializeSensors();
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _compassSubscription?.cancel();
    _accelerometerService.stop();
    _compassService.stop();
    _photoCaptureService?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController =
        _photoCaptureService?.cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  /// Initialize camera service
  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializing = true;
      _initializationError = null;
    });

    try {
      debugPrint('Camera preview: Starting camera initialization...');

      _photoCaptureService = ref.read(photoCaptureServiceProvider);

      // Call initialize and handle the result properly
      final bool initialized = await _photoCaptureService!.initialize();

      if (!initialized) {
        debugPrint('Camera preview: Camera service initialization failed');
        setState(() {
          _initializationError =
              'Failed to initialize camera service. Please check camera permissions and try again.';
          _isInitializing = false;
        });
        return;
      }

      debugPrint('Camera preview: Camera initialization successful');
      setState(() {
        _isInitializing = false;
      });
    } on CameraInitializationException catch (e) {
      debugPrint('Camera preview: CameraInitializationException caught: $e');
      setState(() {
        _initializationError = _handleCameraException(e);
        _isInitializing = false;
      });
    } catch (e) {
      debugPrint('Camera preview: Unexpected error during initialization: $e');
      setState(() {
        _initializationError = _getGenericErrorMessage(e);
        _isInitializing = false;
      });
    }
  }

  /// Handle camera initialization exceptions with iOS-specific messaging
  String _handleCameraException(CameraInitializationException e) {
    if (e.isIOS) {
      switch (e.errorType) {
        case CameraErrorType.permissionDenied:
          return 'Camera access is required. Please enable camera access in iOS Settings > Privacy & Security > Camera > Obsession Tracker.';
        case CameraErrorType.noCamerasAvailable:
          return 'No cameras are available on this device.';
        case CameraErrorType.cameraInUse:
          return 'Camera is currently in use by another app. Please close other camera apps and try again.';
        case CameraErrorType.initializationFailed:
          return 'Failed to initialize camera. Please restart the app and try again.';
      }
    } else {
      switch (e.errorType) {
        case CameraErrorType.permissionDenied:
          return 'Camera permission is required to take photos. Please grant permission in your device settings.';
        case CameraErrorType.noCamerasAvailable:
          return 'No cameras are available on this device.';
        case CameraErrorType.cameraInUse:
          return 'Camera is currently in use. Please try again.';
        case CameraErrorType.initializationFailed:
          return 'Failed to initialize camera. Please try again.';
      }
    }
  }

  /// Get generic error message for unexpected errors
  String _getGenericErrorMessage(Object error) {
    final String errorString = error.toString();

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (errorString.contains('permission') ||
          errorString.contains('Permission')) {
        return 'Camera permission is required. Please enable camera access in iOS Settings > Privacy & Security > Camera > Obsession Tracker.';
      }
      if (errorString.contains('camera') || errorString.contains('Camera')) {
        return 'Camera initialization failed. Please restart the app and try again.';
      }
    }

    return 'An unexpected error occurred while initializing the camera. Please try again.';
  }

  /// Open app settings for permission management
  Future<void> _openAppSettings() async {
    try {
      debugPrint('Opening app settings for camera permissions');
      // Import permission_handler to use openAppSettings
      await openAppSettings();
    } catch (e) {
      debugPrint('Failed to open app settings: $e');
      _showErrorSnackBar(
          'Unable to open settings. Please manually enable camera permissions in your device settings.');
    }
  }

  /// Start tracking location for overlay
  void _startLocationTracking() {
    _updateLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateLocation();
    });
  }

  /// Update current location
  Future<void> _updateLocation() async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLocationLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
        });
      }
    }
  }

  /// Initialize sensor services for HUD overlay
  Future<void> _initializeSensors() async {
    try {
      debugPrint('Initializing sensors for HUD overlay...');
      await _accelerometerService.start();
      await _compassService.start();

      // Listen to accelerometer for pitch/roll
      _accelerometerSubscription =
          _accelerometerService.readingStream.listen((reading) {
        if (mounted) {
          setState(() {
            _pitch = OrientationCalculator.calculatePitch(
              reading.gravityX,
              reading.gravityY,
              reading.gravityZ,
            );
            _roll = OrientationCalculator.calculateRoll(
              reading.gravityX,
              reading.gravityY,
              reading.gravityZ,
            );
          });
        }
      });

      // Listen to compass for heading
      _compassSubscription =
          _compassService.compassStream.listen((EnhancedCompassReading reading) {
        if (mounted) {
          setState(() {
            _heading = reading.heading;
          });
        }
      });

      debugPrint('✅ Sensors initialized for HUD');
    } catch (e) {
      debugPrint('Error initializing sensors for HUD: $e');
    }
  }

  /// Load user settings (units preference)
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unitsIndex = prefs.getInt('units') ?? 0;
      final coordFormatName = prefs.getString('coordinate_format');
      if (mounted) {
        setState(() {
          _useImperialUnits =
              MeasurementUnits.values[unitsIndex] == MeasurementUnits.imperial;
          _coordinateFormat = CoordinateFormat.values.firstWhere(
            (f) => f.name == coordFormatName,
            orElse: () => CoordinateFormat.decimal,
          );
        });
      }
      debugPrint(
          '✅ Settings loaded: ${_useImperialUnits ? "Imperial" : "Metric"} units, ${_coordinateFormat.name} coordinates');
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  /// Toggle HUD overlay visibility
  void _toggleHUD() {
    setState(() {
      _showHUD = !_showHUD;
    });
    HapticFeedback.lightImpact();
    debugPrint('HUD overlay ${_showHUD ? "enabled" : "disabled"}');
  }

  /// Toggle flash mode
  Future<void> _toggleFlash() async {
    final CameraController? controller = _photoCaptureService?.cameraController;
    if (controller == null) return;

    try {
      if (_isFlashOn) {
        await controller.setFlashMode(FlashMode.off);
      } else {
        await controller.setFlashMode(FlashMode.torch);
      }

      setState(() {
        _isFlashOn = !_isFlashOn;
      });

      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  /// Switch between front and back cameras
  Future<void> _switchCamera() async {
    final List<CameraDescription>? cameras =
        _photoCaptureService?.availableCameras;
    if (cameras == null || cameras.length <= 1) return;

    setState(() {
      _isInitializing = true;
    });

    try {
      _currentCameraIndex = (_currentCameraIndex + 1) % cameras.length;
      final bool switched = await _photoCaptureService!
          .switchCamera(cameras[_currentCameraIndex]);

      if (switched) {
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Error switching camera: $e');
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  /// Capture photo
  Future<void> _capturePhoto() async {
    if (_isCapturing || _photoCaptureService == null) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      HapticFeedback.heavyImpact();

      final PhotoCaptureResult result =
          await _photoCaptureService!.capturePhotoWaypoint(
        sessionId: widget.sessionId,
        waypointType: widget.waypointType,
        waypointName: widget.waypointName ?? 'Photo Waypoint',
        waypointNotes: widget.waypointNotes,
        devicePitch: _pitch,
        deviceRoll: _roll,
        deviceYaw: _heading,
      );

      if (result.success) {
        setState(() {
          _capturedPhoto = result;
          _showPhotoPreview = true;
        });

        // Notify parent if callback provided
        widget.onPhotoCapture?.call(result);
      } else {
        _showErrorSnackBar(result.error ?? 'Failed to capture photo');
      }
    } catch (e) {
      _showErrorSnackBar('Error capturing photo: $e');
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  /// Show error snackbar
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Retake photo
  void _retakePhoto() {
    setState(() {
      _capturedPhoto = null;
      _showPhotoPreview = false;
    });
    HapticFeedback.lightImpact();
  }

  /// Dismiss camera and navigate back with proper cleanup
  void _dismissCamera() {
    // Provide haptic feedback
    HapticFeedback.lightImpact();

    // Navigate back without any result
    Navigator.of(context).pop();
  }

  /// Save photo and close
  void _savePhoto() {
    if (_capturedPhoto != null) {
      // Refresh photo provider to show new photo
      ref.invalidate(photoProvider);

      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(_capturedPhoto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = ResponsiveUtils.isTablet(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: _showPhotoPreview
          ? _buildPhotoPreview()
          : _buildCameraPreview(isTablet),
    );
  }

  /// Build camera preview interface
  Widget _buildCameraPreview(bool isTablet) => Stack(
        children: [
          // Camera preview
          _buildCameraView(),

          // HUD overlay (aircraft-style heads-up display)
          if (_showHUD)
            CameraHUDOverlay(
              pitch: _pitch,
              roll: _roll,
              heading: _heading,
              position: _currentPosition,
              useImperial: _useImperialUnits,
              coordinateFormat: _coordinateFormat,
              isVisible: _showHUD,
            ),

          // Location overlay
          _buildLocationOverlay(isTablet),

          // HUD toggle button
          _buildHUDToggleButton(isTablet),

          // Camera controls
          _buildCameraControls(isTablet),

          // Loading overlay
          if (_isInitializing || _isCapturing) _buildLoadingOverlay(),
        ],
      );

  /// Build camera view
  Widget _buildCameraView() {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_initializationError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _initializationError!.contains('permission') ||
                        _initializationError!.contains('Permission')
                    ? Icons.camera_alt_outlined
                    : Icons.error_outline,
                size: 64,
                color: _initializationError!.contains('permission') ||
                        _initializationError!.contains('Permission')
                    ? Colors.orange
                    : Colors.white54,
              ),
              const SizedBox(height: 16),
              Text(
                _initializationError!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _initializeCamera,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                  if (_initializationError!.contains('permission') ||
                      _initializationError!.contains('Permission')) ...[
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _openAppSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Settings'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final CameraController? controller = _photoCaptureService?.cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize!.height,
          height: controller.value.previewSize!.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  /// Build location information overlay
  Widget _buildLocationOverlay(bool isTablet) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 80, // Leave space for HUD toggle button on the right
        child: Container(
          padding: EdgeInsets.all(isTablet ? 16 : 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: _isLocationLoading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Getting location...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: isTablet ? 16 : 14,
                      ),
                    ),
                  ],
                )
              : _currentPosition != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.green,
                              size: isTablet ? 20 : 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'GPS Location',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CoordinateFormatter.formatPair(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                              _coordinateFormat),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: isTablet ? 14 : 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          'Accuracy: ±${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: isTablet ? 12 : 10,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_off,
                          color: Colors.orange,
                          size: isTablet ? 20 : 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Location unavailable',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: isTablet ? 16 : 14,
                          ),
                        ),
                      ],
                    ),
        ),
      );

  /// Build HUD toggle button
  Widget _buildHUDToggleButton(bool isTablet) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        right: 16,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _showHUD
                ? const Color(0xFF00FF00).withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.5),
            border: Border.all(
              color: _showHUD
                  ? const Color(0xFF00FF00)
                  : Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: IconButton(
            onPressed: _toggleHUD,
            icon: Icon(
              Icons.grid_on,
              color: _showHUD ? const Color(0xFF00FF00) : Colors.white,
              size: isTablet ? 28 : 24,
            ),
            tooltip: 'Toggle HUD',
          ),
        ),
      );

  /// Build camera controls
  Widget _buildCameraControls(bool isTablet) {
    final List<CameraDescription>? cameras =
        _photoCaptureService?.availableCameras;
    final bool hasMultipleCameras = cameras != null && cameras.length > 1;
    final bool hasFlash =
        _photoCaptureService?.cameraController?.value.isInitialized == true;

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + (isTablet ? 32 : 24),
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Dismiss button
            _buildControlButton(
              icon: Icons.close,
              onPressed: _dismissCamera,
              isTablet: isTablet,
            ),

            // Flash toggle
            _buildControlButton(
              icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
              onPressed: hasFlash ? _toggleFlash : null,
              isTablet: isTablet,
            ),

            // Capture button
            GestureDetector(
              onTap: _capturePhoto,
              child: Container(
                width: isTablet ? 80 : 70,
                height: isTablet ? 80 : 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.white,
                    width: 4,
                  ),
                ),
                child: _isCapturing
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 3,
                        ),
                      )
                    : Icon(
                        Icons.camera_alt,
                        color: Colors.black,
                        size: isTablet ? 36 : 32,
                      ),
              ),
            ),

            // Camera switch
            _buildControlButton(
              icon: Icons.flip_camera_ios,
              onPressed: hasMultipleCameras ? _switchCamera : null,
              isTablet: isTablet,
            ),
          ],
        ),
      ),
    );
  }

  /// Build control button
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isTablet,
  }) =>
      Container(
        width: isTablet ? 56 : 48,
        height: isTablet ? 56 : 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.5),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            color: onPressed != null
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
            size: isTablet ? 28 : 24,
          ),
        ),
      );

  /// Build loading overlay
  Widget _buildLoadingOverlay() => ColoredBox(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _isInitializing
                    ? 'Initializing camera...'
                    : 'Capturing photo...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );

  /// Build photo preview with retake/save options
  Widget _buildPhotoPreview() {
    if (_capturedPhoto?.photoWaypoint?.filePath == null) {
      return const Center(
        child: Text(
          'Photo preview unavailable',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final bool isTablet = ResponsiveUtils.isTablet(context);

    return Stack(
      children: [
        // Photo preview
        Center(
          child: Image.file(
            File(_capturedPhoto!.photoWaypoint!.filePath),
            fit: BoxFit.contain,
          ),
        ),

        // Controls overlay
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + (isTablet ? 32 : 24),
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Retake button
                ElevatedButton.icon(
                  onPressed: _retakePhoto,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.7),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 24 : 20,
                      vertical: isTablet ? 16 : 12,
                    ),
                  ),
                ),

                // Save button
                ElevatedButton.icon(
                  onPressed: _savePhoto,
                  icon: const Icon(Icons.check),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 24 : 20,
                      vertical: isTablet ? 16 : 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Close button
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          right: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.5),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.close,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
