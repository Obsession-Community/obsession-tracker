import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/photo_capture_data.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';
import 'package:obsession_tracker/core/providers/enhanced_camera_provider.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/core/providers/settings_provider.dart';
import 'package:obsession_tracker/core/services/accelerometer_service.dart' as accelerometer;
import 'package:obsession_tracker/core/services/enhanced_camera_controller_service.dart';
import 'package:obsession_tracker/core/utils/orientation_calculator.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/camera_hud_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Professional camera page with full orientation, multi-lens, and video support
/// This replaces the old camera preview pages with a modern, feature-rich implementation
class ProCameraPage extends ConsumerStatefulWidget {
  const ProCameraPage({
    required this.sessionId,
    super.key,
    this.onPhotoCapture,
    this.onVideoCapture,
  });

  final String sessionId;
  final void Function(PhotoCaptureData data)? onPhotoCapture;
  final void Function(XFile video)? onVideoCapture;

  @override
  ConsumerState<ProCameraPage> createState() => _ProCameraPageState();
}

class _ProCameraPageState extends ConsumerState<ProCameraPage>
    with WidgetsBindingObserver {
  bool _isCapturing = false;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  // HUD overlay
  bool _showHUD = false;
  double _pitch = 0.0;
  double _roll = 0.0;
  double _heading = 0.0;
  bool _useImperialUnits = true;
  CoordinateFormat _coordinateFormat = CoordinateFormat.decimal;

  // Physical device orientation (from accelerometer, not OS rotation)
  accelerometer.DeviceOrientation _physicalOrientation = accelerometer.DeviceOrientation.portraitUp;

  // Sensor services
  final accelerometer.AccelerometerService _accelerometerService = accelerometer.AccelerometerService();
  StreamSubscription<accelerometer.AccelerometerReading>? _accelerometerSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;

  // IMPORTANT: Store camera service reference for safe disposal
  // We save this in initState so we can access it in dispose() without using ref
  late final EnhancedCameraControllerService _cameraService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Store reference to camera service for safe disposal
    _cameraService = ref.read(enhancedCameraServiceProvider);

    // Apply photo quality setting before initializing camera
    final photoQuality = ref.read(appSettingsProvider).tracking.photoQuality;
    _cameraService.updatePhotoQuality(photoQuality);

    _initializeCamera();
    _initializeSensors();
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _compassSubscription?.cancel();
    _accelerometerService.stop();

    // Dispose camera controller when leaving the page
    // Use the service's disposeController() method which properly resets state
    // so the camera can be re-initialized next time
    debugPrint('📷 ProCameraPage: Calling disposeController()');
    _cameraService.disposeController();

    // Note: Don't use ref.invalidate() here - it's unsafe during dispose()
    // The disposeController() already resets all state properly

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle lifecycle changes for camera
    if (state == AppLifecycleState.inactive) {
      // Pause camera when app goes to background
      // Use disposeController() to properly reset state
      debugPrint('📷 ProCameraPage: App inactive, disposing camera');
      _cameraService.disposeController();
    } else if (state == AppLifecycleState.resumed) {
      // Resume camera when app comes back to foreground
      debugPrint('📷 ProCameraPage: App resumed, re-initializing camera');
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      // Use cached service reference
      if (!_cameraService.isInitialized) {
        await _cameraService.initialize();
      }
    } catch (e) {
      debugPrint('Failed to initialize camera: $e');
    }
  }

  Future<void> _initializeSensors() async {
    try {
      debugPrint('Initializing sensors for HUD overlay...');
      await _accelerometerService.start();

      // Subscribe to accelerometer for pitch, roll, and physical orientation
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

            // Track physical device orientation for rotating GUI controls
            final newOrientation = _accelerometerService.deviceOrientation;
            if (newOrientation != _physicalOrientation &&
                (newOrientation == accelerometer.DeviceOrientation.portraitUp ||
                 newOrientation == accelerometer.DeviceOrientation.landscapeLeft ||
                 newOrientation == accelerometer.DeviceOrientation.landscapeRight)) {
              _physicalOrientation = newOrientation;
            }
          });
        }
      });

      // Subscribe to flutter_compass for heading (direct from device magnetometer)
      _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
        if (mounted && event.heading != null) {
          setState(() {
            _heading = event.heading!;
          });
        }
      }, onError: (Object error) {
        debugPrint('❌ Compass error: $error');
      });

      debugPrint('✅ Sensors initialized for HUD');
    } catch (e) {
      debugPrint('Error initializing sensors for HUD: $e');
    }
  }

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

  void _toggleHUD() {
    setState(() {
      _showHUD = !_showHUD;
    });
    HapticFeedback.lightImpact();
    debugPrint('HUD overlay ${_showHUD ? "enabled" : "disabled"}');
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      HapticFeedback.heavyImpact();

      final service = ref.read(enhancedCameraServiceProvider);
      final photo = await service.takePicture();

      // Determine photo orientation based on physical device orientation
      String? photoOrientation;
      if (_physicalOrientation == accelerometer.DeviceOrientation.landscapeLeft ||
          _physicalOrientation == accelerometer.DeviceOrientation.landscapeRight) {
        photoOrientation = 'landscape';
      } else if (_physicalOrientation == accelerometer.DeviceOrientation.portraitUp) {
        photoOrientation = 'portrait';
      }

      // Create capture data with sensor readings
      final captureData = PhotoCaptureData(
        photo: photo,
        devicePitch: _pitch,
        deviceRoll: _roll,
        deviceYaw: _heading,
        photoOrientation: photoOrientation,
      );

      debugPrint('📸 Photo captured with sensor data:');
      debugPrint('   Pitch: ${_pitch.toStringAsFixed(1)}°');
      debugPrint('   Roll: ${_roll.toStringAsFixed(1)}°');
      debugPrint('   Heading: ${_heading.toStringAsFixed(1)}°');
      debugPrint('   Orientation: $photoOrientation');

      // Call the callback - the parent (IntegratedCameraPage) will handle navigation
      widget.onPhotoCapture?.call(captureData);

      // Don't pop here - let the parent handle it to avoid type conflicts
      // The IntegratedCameraPage will convert XFile to PhotoCaptureResult and pop
    } catch (e) {
      _showError('Failed to capture photo: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _toggleVideoRecording() async {
    final service = ref.read(enhancedCameraServiceProvider);

    if (service.isRecording) {
      await _stopVideoRecording();
    } else {
      await _startVideoRecording();
    }
  }

  Future<void> _startVideoRecording() async {
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      HapticFeedback.mediumImpact();

      final service = ref.read(enhancedCameraServiceProvider);
      await service.startVideoRecording();

      // Start recording timer
      _recordingDuration = Duration.zero;
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration = Duration(seconds: timer.tick);
          });
        }
      });

      setState(() {
        _isCapturing = false;
      });
    } catch (e) {
      _showError('Failed to start recording: $e');
      setState(() {
        _isCapturing = false;
      });
    }
  }

  Future<void> _stopVideoRecording() async {
    setState(() {
      _isCapturing = true;
    });

    try {
      HapticFeedback.heavyImpact();

      final service = ref.read(enhancedCameraServiceProvider);
      final video = await service.stopVideoRecording();

      _recordingTimer?.cancel();
      _recordingTimer = null;

      if (video != null) {
        // Call the callback - the parent (IntegratedCameraPage) will handle navigation
        widget.onVideoCapture?.call(video);

        // Don't pop here - let the parent handle it
      }
    } catch (e) {
      _showError('Failed to stop recording: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _recordingDuration = Duration.zero;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cameraStateAsync = ref.watch(currentCameraStateProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: cameraStateAsync.when(
        data: (state) => state == null
            ? _buildError('Camera not initialized')
            : _buildCameraView(state),
        loading: _buildLoading,
        error: (error, stack) => _buildError(error.toString()),
      ),
    );
  }

  Widget _buildLoading() => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );

  Widget _buildError(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeCamera,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _buildCameraView(CameraState state) {
    final service = ref.read(enhancedCameraServiceProvider);
    final controller = service.controller;

    if (controller == null || !controller.value.isInitialized) {
      return _buildLoading();
    }

    // Get current GPS position from provider
    final Position? currentPosition = ref.watch(currentPositionProvider);

    // Calculate rotation based on physical device orientation
    // This allows controls to rotate while camera preview stays fixed
    final int quarterTurns = _getQuarterTurns(_physicalOrientation);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview fills full screen and never rotates
        // Up is always up regardless of device rotation
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.previewSize!.height,
              height: controller.value.previewSize!.width,
              child: CameraPreview(controller),
            ),
          ),
        ),

        // HUD overlay rotates with physical device orientation
        if (_showHUD)
          RotatedBox(
            quarterTurns: quarterTurns,
            child: CameraHUDOverlay(
              pitch: _pitch,
              roll: _roll,
              heading: _heading,
              position: currentPosition,
              useImperial: _useImperialUnits,
              coordinateFormat: _coordinateFormat,
              isVisible: _showHUD,
            ),
          ),

        // Controls rotate with physical device orientation
        // Like iOS Camera app: controls rotate, preview doesn't
        RotatedBox(
          quarterTurns: quarterTurns,
          child: Stack(
            children: [
              _buildTopControls(state),
              _buildBottomControls(state),
            ],
          ),
        ),

        // Recording indicator rotates with controls
        if (state.isRecording)
          RotatedBox(
            quarterTurns: quarterTurns,
            child: _buildRecordingIndicator(),
          ),
      ],
    );
  }

  /// Convert physical device orientation to quarter turns for RotatedBox
  /// - portraitUp: 0 turns (no rotation)
  /// - landscapeLeft: 1 turn (90° clockwise)
  /// - landscapeRight: 3 turns (270° clockwise = 90° counter-clockwise)
  int _getQuarterTurns(accelerometer.DeviceOrientation orientation) {
    switch (orientation) {
      case accelerometer.DeviceOrientation.portraitUp:
        return 0;
      case accelerometer.DeviceOrientation.landscapeLeft:
        // Device rotated 90° counter-clockwise, rotate UI 90° clockwise
        return 1;
      case accelerometer.DeviceOrientation.landscapeRight:
        // Device rotated 90° clockwise, rotate UI 90° counter-clockwise
        return 3;
      default:
        return 0; // Fallback to portrait
    }
  }

  Widget _buildTopControls(CameraState state) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Close button
              _buildControlButton(
                icon: Icons.close,
                onPressed: () => Navigator.of(context).pop(),
              ),

              const Spacer(),

              // HUD toggle button
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _showHUD
                      ? const Color(0xFF00FF00).withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.6),
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
                    size: 24,
                  ),
                  tooltip: 'Toggle HUD',
                ),
              ),

              const SizedBox(width: 8),

              // Flash toggle
              _buildControlButton(
                icon: _getFlashIcon(state.settings.flashMode),
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  final service = ref.read(enhancedCameraServiceProvider);
                  await service.toggleFlashMode();
                },
              ),
            ],
          ),
        ),
      );

  Widget _buildZoomSelector(CameraState state) {
    final service = ref.read(enhancedCameraServiceProvider);
    final availableZoomLevels = service.getAvailableZoomLevels();
    final currentZoom = state.settings.zoomLevel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: availableZoomLevels.map((zoomLevel) {
          final isSelected = (currentZoom - zoomLevel).abs() < 0.1;
          // Format label: show decimal for 0.5x, otherwise show as integer
          final label = zoomLevel < 1.0 ? '${zoomLevel}x' : '${zoomLevel.toInt()}x';

          return GestureDetector(
            onTap: () async {
              if (!isSelected) {
                HapticFeedback.selectionClick();
                await service.setZoomLevel(zoomLevel);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomControls(CameraState state) => Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom selector (like iPhone camera app)
                _buildZoomSelector(state),
                const SizedBox(height: 16),

                // Mode selector
                _buildModeSelector(state),
                const SizedBox(height: 24),

                // Main controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Spacer
                    const SizedBox(width: 48),

                    // Capture button
                    _buildCaptureButton(state),

                    // Camera flip
                    _buildControlButton(
                      icon: Icons.flip_camera_ios,
                      onPressed: () async {
                        HapticFeedback.selectionClick();
                        final service =
                            ref.read(enhancedCameraServiceProvider);
                        await service.toggleCamera();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  // Video mode disabled until video waypoint support is implemented
  Widget _buildModeSelector(CameraState state) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildModeButton(
            'PHOTO',
            true, // Always selected since video is disabled
            HapticFeedback.selectionClick,
          ),
        ],
      );

  Widget _buildModeButton(String label, bool isSelected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontSize: isSelected ? 18 : 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _buildCaptureButton(CameraState state) {
    final isVideoMode = state.settings.captureMode == CameraCaptureMode.video;
    final isRecording = state.isRecording;

    return GestureDetector(
      onTap: isVideoMode ? _toggleVideoRecording : _capturePhoto,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
        ),
        child: Center(
          child: Container(
            width: isVideoMode && isRecording ? 32 : 68,
            height: isVideoMode && isRecording ? 32 : 68,
            decoration: BoxDecoration(
              color: isRecording ? Colors.red : Colors.white,
              borderRadius: BorderRadius.circular(
                isVideoMode && isRecording ? 6 : 34,
              ),
            ),
            child: _isCapturing
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 3,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingIndicator() => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_recordingDuration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) =>
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.6),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 24),
        ),
      );

  IconData _getFlashIcon(FlashMode mode) {
    switch (mode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.highlight;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
