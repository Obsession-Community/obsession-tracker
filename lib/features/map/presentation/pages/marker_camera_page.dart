import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/enhanced_camera_provider.dart';
import 'package:obsession_tracker/core/services/device_orientation_service.dart' as orientation;
import 'package:obsession_tracker/core/services/enhanced_camera_controller_service.dart';
import 'package:obsession_tracker/core/services/marker_attachment_service.dart';

/// Camera page for capturing photos for custom marker attachments.
///
/// Uses the same professional camera system as tracking sessions but
/// saves photos as marker attachments instead of waypoints.
class MarkerCameraPage extends ConsumerStatefulWidget {
  const MarkerCameraPage({
    required this.markerId,
    super.key,
  });

  final String markerId;

  @override
  ConsumerState<MarkerCameraPage> createState() => _MarkerCameraPageState();
}

class _MarkerCameraPageState extends ConsumerState<MarkerCameraPage>
    with WidgetsBindingObserver {
  bool _isCapturing = false;
  bool _isSaving = false;
  String? _errorMessage;

  late final EnhancedCameraControllerService _cameraService;
  final orientation.DeviceOrientationService _orientationService = orientation.DeviceOrientationService();

  /// Current device orientation for photo rotation correction
  orientation.DeviceOrientation _currentOrientation = orientation.DeviceOrientation.portraitUp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraService = ref.read(enhancedCameraServiceProvider);
    _initializeCamera();
    _initializeOrientationService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.disposeController();
    _orientationService.dispose();
    super.dispose();
  }

  Future<void> _initializeOrientationService() async {
    try {
      await _orientationService.start();
      // Listen to orientation changes
      _orientationService.orientationStream.listen((orientation.OrientationReading reading) {
        if (mounted) {
          _currentOrientation = reading.deviceOrientation;
        }
      });
    } catch (e) {
      debugPrint('Failed to initialize orientation service: $e');
      // Non-fatal - photos will still work, just without auto-rotation
    }
  }

  /// Convert device orientation to rotation quarter turns for photo correction.
  ///
  /// When the camera is locked in portrait mode but the user holds the device
  /// in landscape, we need to rotate the photo to display correctly.
  /// Returns 0-3 representing quarter turns clockwise.
  int? _getRotationForOrientation(orientation.DeviceOrientation deviceOrientation) {
    switch (deviceOrientation) {
      case orientation.DeviceOrientation.portraitUp:
        return null; // No rotation needed
      case orientation.DeviceOrientation.landscapeLeft:
        // Device rotated left (home button on right), rotate image 90° CW
        return 1;
      case orientation.DeviceOrientation.landscapeRight:
        // Device rotated right (home button on left), rotate image 90° CCW (270° CW)
        return 3;
      case orientation.DeviceOrientation.portraitDown:
        // Device upside down, rotate 180°
        return 2;
      default:
        // Face up, face down, unknown - no rotation
        return null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cameraService.disposeController();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _errorMessage = null;
      });
      if (!_cameraService.isInitialized) {
        await _cameraService.initialize();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize camera: $e';
        });
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing || _isSaving) return;

    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      HapticFeedback.heavyImpact();

      // Capture the orientation at the moment of photo capture
      final captureOrientation = _currentOrientation;
      final XFile photo = await _cameraService.takePicture();

      // Show preview and save option
      if (mounted) {
        await _showPhotoPreview(photo, captureOrientation);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error capturing photo: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _showPhotoPreview(XFile photo, orientation.DeviceOrientation captureOrientation) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PhotoPreviewDialog(
        photo: photo,
        onSave: () => Navigator.pop(context, true),
        onRetake: () => Navigator.pop(context, false),
      ),
    );

    if (result == true) {
      await _savePhotoAsAttachment(photo, captureOrientation);
    }
    // If result is false, user wants to retake - just return to camera
  }

  Future<void> _savePhotoAsAttachment(XFile photo, orientation.DeviceOrientation captureOrientation) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final service = MarkerAttachmentService();
      final fileName =
          'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Get rotation needed based on device orientation when photo was captured
      final initialRotation = _getRotationForOrientation(captureOrientation);

      await service.addImage(
        markerId: widget.markerId,
        name: fileName,
        imageFile: File(photo.path),
        initialRotation: initialRotation,
      );

      if (mounted) {
        Navigator.pop(context, true); // Return success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(initialRotation != null
                ? 'Photo added to marker (auto-rotated)'
                : 'Photo added to marker'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save photo: $e';
        });
      }
    }
  }

  Future<void> _toggleCamera() async {
    HapticFeedback.selectionClick();
    await _cameraService.toggleCamera();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cameraStateAsync = ref.watch(currentCameraStateProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Take Photo'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
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
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? message,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _initializeCamera,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _buildCameraView(CameraState state) {
    final controller = _cameraService.controller;

    if (controller == null || !controller.value.isInitialized) {
      return _buildLoading();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview fills full screen
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

        // Saving overlay
        if (_isSaving)
          const ColoredBox(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Saving photo...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

        // Bottom controls
        if (!_isSaving)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: 24 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Zoom selector
                  _buildZoomSelector(state),
                  const SizedBox(height: 24),

                  // Main controls row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Spacer for balance
                      const SizedBox(width: 48),

                      // Capture button
                      GestureDetector(
                        onTap: _isCapturing ? null : _capturePhoto,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 4,
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isCapturing ? Colors.grey : Colors.white,
                            ),
                            child: _isCapturing
                                ? const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.black,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),

                      // Switch camera button
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                        child: IconButton(
                          onPressed: _isCapturing ? null : _toggleCamera,
                          icon: const Icon(Icons.flip_camera_ios),
                          iconSize: 24,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildZoomSelector(CameraState state) {
    final availableZoomLevels = _cameraService.getAvailableZoomLevels();
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
          final label =
              zoomLevel < 1.0 ? '${zoomLevel}x' : '${zoomLevel.toInt()}x';

          return GestureDetector(
            onTap: () async {
              if (!isSelected) {
                HapticFeedback.selectionClick();
                await _cameraService.setZoomLevel(zoomLevel);
                if (mounted) setState(() {});
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
}

/// Photo preview dialog for confirmation before saving
class _PhotoPreviewDialog extends StatelessWidget {
  const _PhotoPreviewDialog({
    required this.photo,
    required this.onSave,
    required this.onRetake,
  });

  final XFile photo;
  final VoidCallback onSave;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Photo preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.file(
              File(photo.path),
              fit: BoxFit.contain,
              height: MediaQuery.of(context).size.height * 0.5,
            ),
          ),
          // Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRetake,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.check),
                    label: const Text('Use Photo'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to open marker camera
Future<bool?> showMarkerCamera(
  BuildContext context, {
  required String markerId,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (context) => MarkerCameraPage(markerId: markerId),
      fullscreenDialog: true,
    ),
  );
}
