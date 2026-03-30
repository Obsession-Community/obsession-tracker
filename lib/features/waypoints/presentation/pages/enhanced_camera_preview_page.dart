import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';
import 'package:obsession_tracker/core/models/voice_note.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/app_settings_provider.dart';
import 'package:obsession_tracker/core/providers/photo_provider.dart';
import 'package:obsession_tracker/core/providers/voice_note_provider.dart';
import 'package:obsession_tracker/core/services/photo_capture_service.dart';
import 'package:obsession_tracker/core/services/voice_recording_service.dart';
import 'package:obsession_tracker/core/utils/coordinate_formatter.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/camera_annotation_overlay_widget.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/location_aware_suggestions_widget.dart';
import 'package:permission_handler/permission_handler.dart';

/// Enhanced camera preview page with integrated annotation capabilities
class EnhancedCameraPreviewPage extends ConsumerStatefulWidget {
  const EnhancedCameraPreviewPage({
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
  ConsumerState<EnhancedCameraPreviewPage> createState() =>
      _EnhancedCameraPreviewPageState();
}

class _EnhancedCameraPreviewPageState
    extends ConsumerState<EnhancedCameraPreviewPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
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

  // Annotation state
  CameraAnnotationData _currentAnnotation = const CameraAnnotationData();
  bool _showAnnotationOverlay = true;
  bool _showSuggestions = false;
  VoiceRecordingResult? _pendingVoiceNote;

  // Animation controllers
  late AnimationController _overlayController;
  late AnimationController _suggestionsController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _overlayController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _suggestionsController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _initializeCamera();
    _startLocationTracking();
    _overlayController.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    _photoCaptureService?.dispose();
    _overlayController.dispose();
    _suggestionsController.dispose();
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
      debugPrint('Enhanced camera preview: Starting camera initialization...');

      _photoCaptureService = ref.read(photoCaptureServiceProvider);

      final bool initialized = await _photoCaptureService!.initialize();

      if (!initialized) {
        debugPrint(
            'Enhanced camera preview: Camera service initialization failed');
        setState(() {
          _initializationError =
              'Failed to initialize camera service. Please check camera permissions and try again.';
          _isInitializing = false;
        });
        return;
      }

      debugPrint('Enhanced camera preview: Camera initialization successful');
      setState(() {
        _isInitializing = false;
      });
    } on CameraInitializationException catch (e) {
      debugPrint(
          'Enhanced camera preview: CameraInitializationException caught: $e');
      setState(() {
        _initializationError = _handleCameraException(e);
        _isInitializing = false;
      });
    } catch (e) {
      debugPrint(
          'Enhanced camera preview: Unexpected error during initialization: $e');
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

  /// Capture photo with annotations
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
      );

      if (result.success) {
        setState(() {
          _capturedPhoto = result;
          _showPhotoPreview = true;
        });

        // Save annotations if any
        if (_currentAnnotation.hasAnnotations && result.photoWaypoint != null) {
          await _saveAnnotations(result.photoWaypoint!.id);
        }

        // Save voice note if recorded
        if (_pendingVoiceNote != null &&
            _pendingVoiceNote!.success &&
            result.photoWaypoint != null) {
          await _saveVoiceNote(result.photoWaypoint!.waypointId);
        }

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

  /// Save photo annotations
  Future<void> _saveAnnotations(String photoWaypointId) async {
    try {
      final List<PhotoMetadata> metadata =
          _currentAnnotation.toPhotoMetadata(photoWaypointId);

      // In a real implementation, this would save to database
      // For now, we'll just log the annotations
      debugPrint(
          'Saving ${metadata.length} annotations for photo $photoWaypointId');
      for (final annotation in metadata) {
        debugPrint('  ${annotation.key}: ${annotation.value}');
      }
    } catch (e) {
      debugPrint('Error saving annotations: $e');
    }
  }

  /// Save voice note
  Future<void> _saveVoiceNote(String waypointId) async {
    if (_pendingVoiceNote == null || !_pendingVoiceNote!.success) return;

    try {
      final VoiceRecordingService recordingService =
          ref.read(voiceRecordingServiceProvider);
      final VoiceNote voiceNote = recordingService.createVoiceNote(
        waypointId: waypointId,
        result: _pendingVoiceNote!,
      );

      final bool success =
          await ref.read(voiceNoteProvider.notifier).addVoiceNote(voiceNote);

      if (success) {
        debugPrint('Voice note saved successfully');
        setState(() {
          _pendingVoiceNote = null;
        });
      } else {
        debugPrint('Failed to save voice note');
      }
    } catch (e) {
      debugPrint('Error saving voice note: $e');
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
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  /// Save photo and close
  void _savePhoto() {
    if (_capturedPhoto != null) {
      ref.invalidate(photoProvider);
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(_capturedPhoto);
    }
  }

  /// Toggle annotation overlay visibility
  void _toggleAnnotationOverlay() {
    setState(() {
      _showAnnotationOverlay = !_showAnnotationOverlay;
    });

    if (_showAnnotationOverlay) {
      _overlayController.forward();
    } else {
      _overlayController.reverse();
    }

    HapticFeedback.lightImpact();
  }

  /// Toggle suggestions visibility
  void _toggleSuggestions() {
    setState(() {
      _showSuggestions = !_showSuggestions;
    });

    if (_showSuggestions) {
      _suggestionsController.forward();
    } else {
      _suggestionsController.reverse();
    }

    HapticFeedback.lightImpact();
  }

  /// Handle annotation changes
  void _onAnnotationChanged(CameraAnnotationData annotation) {
    setState(() {
      _currentAnnotation = annotation;
    });
  }

  /// Handle suggestion selection
  void _onSuggestionSelected(AnnotationSuggestion suggestion) {
    switch (suggestion.type) {
      case SuggestionType.note:
        setState(() {
          _currentAnnotation = _currentAnnotation.copyWith(
            note: suggestion.value,
          );
        });
        break;
      case SuggestionType.tags:
        setState(() {
          _currentAnnotation = _currentAnnotation.copyWith(
            tags: suggestion.value,
          );
        });
        break;
      case SuggestionType.weather:
        // Weather suggestions could be added to notes or a separate field
        setState(() {
          _currentAnnotation = _currentAnnotation.copyWith(
            note: _currentAnnotation.note.isEmpty
                ? suggestion.value
                : '${_currentAnnotation.note}, ${suggestion.value}',
          );
        });
        break;
      case SuggestionType.location:
        setState(() {
          _currentAnnotation = _currentAnnotation.copyWith(
            tags: _currentAnnotation.tags.isEmpty
                ? suggestion.value
                : '${_currentAnnotation.tags}, ${suggestion.value}',
          );
        });
        break;
    }

    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = ResponsiveUtils.isTablet(context);
    final generalSettings = ref.watch(generalSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: _showPhotoPreview
          ? _buildPhotoPreview()
          : _buildEnhancedCameraPreview(isTablet, generalSettings.coordinateFormat),
    );
  }

  /// Build enhanced camera preview interface with annotations
  Widget _buildEnhancedCameraPreview(bool isTablet, CoordinateFormat coordinateFormat) => Stack(
        children: [
          // Camera preview
          _buildCameraView(),

          // Location overlay
          _buildLocationOverlay(isTablet, coordinateFormat),

          // Annotation overlay
          if (_showAnnotationOverlay)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _overlayController,
                  curve: Curves.easeOutCubic,
                )),
                child: CameraAnnotationOverlayWidget(
                  onAnnotationChanged: _onAnnotationChanged,
                  initialNote: _currentAnnotation.note,
                  initialTags: _currentAnnotation.tags,
                  initialRating: _currentAnnotation.rating,
                  initialFavorite: _currentAnnotation.isFavorite,
                  isCompact: !isTablet,
                ),
              ),
            ),

          // Suggestions overlay
          if (_showSuggestions)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 120,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _suggestionsController,
                  curve: Curves.easeOutCubic,
                )),
                child: LocationAwareSuggestionsWidget(
                  onSuggestionSelected: _onSuggestionSelected,
                  currentNote: _currentAnnotation.note,
                  currentTags: _currentAnnotation.tags,
                ),
              ),
            ),

          // Enhanced camera controls
          _buildEnhancedCameraControls(isTablet),

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
  Widget _buildLocationOverlay(bool isTablet, CoordinateFormat coordinateFormat) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
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
                              coordinateFormat),
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

  /// Build enhanced camera controls with annotation toggles
  Widget _buildEnhancedCameraControls(bool isTablet) {
    final List<CameraDescription>? cameras =
        _photoCaptureService?.availableCameras;
    final bool hasMultipleCameras = cameras != null && cameras.length > 1;
    final bool hasFlash =
        _photoCaptureService?.cameraController?.value.isInitialized == true;

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + (isTablet ? 32 : 24),
      left: 0,
      right: 0,
      child: Column(
        children: [
          // Annotation controls row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Annotation overlay toggle
                _buildControlButton(
                  icon: _showAnnotationOverlay
                      ? Icons.edit_note
                      : Icons.edit_note_outlined,
                  onPressed: _toggleAnnotationOverlay,
                  isTablet: isTablet,
                  isActive: _showAnnotationOverlay,
                ),

                // Suggestions toggle
                _buildControlButton(
                  icon: _showSuggestions
                      ? Icons.lightbulb
                      : Icons.lightbulb_outline,
                  onPressed: _toggleSuggestions,
                  isTablet: isTablet,
                  isActive: _showSuggestions,
                ),

                // Annotation count indicator
                if (_currentAnnotation.hasAnnotations)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.blue,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ready',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Voice note indicator
                if (_pendingVoiceNote?.success == true)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.purple),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.mic,
                          color: Colors.purple,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Voice',
                          style: TextStyle(
                            color: Colors.purple,
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Main camera controls row
          Padding(
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
                  isActive: _isFlashOn,
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
        ],
      ),
    );
  }

  /// Build control button with active state support
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isTablet,
    bool isActive = false,
  }) =>
      Container(
        width: isTablet ? 56 : 48,
        height: isTablet ? 56 : 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? Colors.blue.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.5),
          border: Border.all(
            color: isActive ? Colors.blue : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            color: onPressed != null
                ? (isActive ? Colors.blue : Colors.white)
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

        // Annotation overlay on preview
        if (_currentAnnotation.hasAnnotations)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Annotations Saved',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_pendingVoiceNote?.success == true) ...[
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.mic,
                          color: Colors.purple,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Voice Note',
                          style: TextStyle(
                            color: Colors.purple,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_currentAnnotation.note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _currentAnnotation.note,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (_currentAnnotation.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: _currentAnnotation.tags
                          .split(',')
                          .map((tag) => tag.trim())
                          .where((tag) => tag.isNotEmpty)
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
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
