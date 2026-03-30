import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/enhanced_camera_provider.dart';
import 'package:obsession_tracker/core/services/enhanced_camera_controller_service.dart';

/// Camera page for capturing photos that returns the file instead of saving directly.
///
/// Used when creating new markers where the marker ID doesn't exist yet.
/// Returns the captured File on success, null if cancelled.
class PendingPhotoCameraPage extends ConsumerStatefulWidget {
  const PendingPhotoCameraPage({super.key});

  @override
  ConsumerState<PendingPhotoCameraPage> createState() =>
      _PendingPhotoCameraPageState();
}

class _PendingPhotoCameraPageState extends ConsumerState<PendingPhotoCameraPage>
    with WidgetsBindingObserver {
  bool _isCapturing = false;
  String? _errorMessage;

  late final EnhancedCameraControllerService _cameraService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraService = ref.read(enhancedCameraServiceProvider);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.disposeController();
    super.dispose();
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
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      HapticFeedback.heavyImpact();
      final XFile photo = await _cameraService.takePicture();

      // Show preview and confirmation
      if (mounted) {
        await _showPhotoPreview(photo);
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

  Future<void> _showPhotoPreview(XFile photo) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PhotoPreviewDialog(
        photo: photo,
        onUse: () => Navigator.pop(context, true),
        onRetake: () => Navigator.pop(context, false),
      ),
    );

    if (result == true && mounted) {
      // Return the file
      Navigator.pop(context, File(photo.path));
    }
    // If result is false, user wants to retake - just return to camera
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
          onPressed: () => Navigator.pop(context),
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

        // Bottom controls
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

/// Photo preview dialog for confirmation before using
class _PhotoPreviewDialog extends StatelessWidget {
  const _PhotoPreviewDialog({
    required this.photo,
    required this.onUse,
    required this.onRetake,
  });

  final XFile photo;
  final VoidCallback onUse;
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
                    onPressed: onUse,
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

/// Helper function to open camera and get a photo file
Future<File?> showPendingPhotoCamera(BuildContext context) {
  return Navigator.of(context).push<File>(
    MaterialPageRoute(
      builder: (context) => const PendingPhotoCameraPage(),
      fullscreenDialog: true,
    ),
  );
}
