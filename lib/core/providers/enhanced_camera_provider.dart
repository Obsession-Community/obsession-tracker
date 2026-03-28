import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/services/enhanced_camera_controller_service.dart';

/// Provider for the enhanced camera controller service
final enhancedCameraServiceProvider =
    Provider<EnhancedCameraControllerService>((ref) {
  final service = EnhancedCameraControllerService();

  // Cleanup on provider disposal
  ref.onDispose(service.dispose);

  return service;
});

/// Provider for camera state stream
final cameraStateStreamProvider = StreamProvider<CameraState>((ref) {
  final service = ref.watch(enhancedCameraServiceProvider);
  return service.stateStream;
});

/// Provider for current camera state (uses stream for real-time updates)
///
/// This provider does NOT initialize the camera - the page is responsible for that.
/// It just listens for state updates and yields them.
final currentCameraStateProvider = StreamProvider<CameraState?>((ref) async* {
  final service = ref.watch(enhancedCameraServiceProvider);

  debugPrint('📷 CameraStateProvider: Starting, isInitialized=${service.isInitialized}');

  // If already initialized, yield current state immediately
  if (service.isInitialized && service.controller != null && service.currentCamera != null) {
    debugPrint('📷 CameraStateProvider: Yielding initial state (already initialized)');
    yield CameraState(
      isInitialized: true,
      currentCamera: service.currentCamera!,
      settings: service.settings,
      isRecording: service.isRecording,
      availableLenses: service.availableCameras
          .where((c) => c.description.lensDirection == service.currentCamera!.description.lensDirection)
          .toList(),
    );
  }

  // Listen to state stream for real-time updates
  debugPrint('📷 CameraStateProvider: Listening to state stream...');
  await for (final state in service.stateStream) {
    debugPrint('📷 CameraStateProvider: Got state from stream, isInitialized=${state.isInitialized}');
    yield state;
  }
});

/// Provider for available cameras
final availableCamerasProvider = Provider<List<CameraInfo>>((ref) {
  final service = ref.watch(enhancedCameraServiceProvider);
  return service.availableCameras;
});

/// Provider for camera settings
final cameraSettingsProvider = Provider<CameraSettings>((ref) {
  final service = ref.watch(enhancedCameraServiceProvider);
  return service.settings;
});
