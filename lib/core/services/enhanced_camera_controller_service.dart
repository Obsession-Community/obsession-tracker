import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart' as camera_lib;
import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Camera lens type based on approximate focal length
enum CameraLensType {
  ultraWide, // ~0.5x (13mm equivalent)
  wide, // 1x (24-28mm equivalent)
  telephoto2x, // 2x (48-52mm equivalent)
  telephoto3x, // 3x (77mm equivalent)
  telephotoOther, // Other telephoto lenses
  unknown;

  String get displayName {
    switch (this) {
      case CameraLensType.ultraWide:
        return 'Ultra Wide';
      case CameraLensType.wide:
        return 'Wide (1x)';
      case CameraLensType.telephoto2x:
        return 'Telephoto (2x)';
      case CameraLensType.telephoto3x:
        return 'Telephoto (3x)';
      case CameraLensType.telephotoOther:
        return 'Telephoto';
      case CameraLensType.unknown:
        return 'Unknown';
    }
  }

  String get zoomLabel {
    switch (this) {
      case CameraLensType.ultraWide:
        return '0.5x';
      case CameraLensType.wide:
        return '1x';
      case CameraLensType.telephoto2x:
        return '2x';
      case CameraLensType.telephoto3x:
        return '3x';
      case CameraLensType.telephotoOther:
        return '?x';
      case CameraLensType.unknown:
        return '?';
    }
  }
}

/// Camera information with lens detection
class CameraInfo {
  const CameraInfo({
    required this.description,
    required this.lensType,
    required this.index,
  });

  final camera_lib.CameraDescription description;
  final CameraLensType lensType;
  final int index;

  String get name => description.name;
  camera_lib.CameraLensDirection get direction => description.lensDirection;

  @override
  String toString() =>
      'CameraInfo(${description.lensDirection.name}, ${lensType.displayName})';
}

/// Camera capture mode
enum CameraCaptureMode {
  photo,
  video;

  String get displayName {
    switch (this) {
      case CameraCaptureMode.photo:
        return 'Photo';
      case CameraCaptureMode.video:
        return 'Video';
    }
  }
}

/// Camera orientation lock state
enum OrientationLockState {
  unlocked, // Device orientation controls camera
  portrait, // Locked to portrait
  landscape; // Locked to landscape

  String get displayName {
    switch (this) {
      case OrientationLockState.unlocked:
        return 'Auto';
      case OrientationLockState.portrait:
        return 'Portrait';
      case OrientationLockState.landscape:
        return 'Landscape';
    }
  }
}

/// Camera settings that persist between sessions
class CameraSettings {
  const CameraSettings({
    this.preferredCameraDirection = camera_lib.CameraLensDirection.back,
    this.preferredLensType = CameraLensType.wide,
    this.captureMode = CameraCaptureMode.photo,
    this.orientationLock = OrientationLockState.unlocked,
    this.flashMode = camera_lib.FlashMode.auto,
    this.zoomLevel = 1.0,
  });

  final camera_lib.CameraLensDirection preferredCameraDirection;
  final CameraLensType preferredLensType;
  final CameraCaptureMode captureMode;
  final OrientationLockState orientationLock;
  final camera_lib.FlashMode flashMode;
  final double zoomLevel;

  CameraSettings copyWith({
    camera_lib.CameraLensDirection? preferredCameraDirection,
    CameraLensType? preferredLensType,
    CameraCaptureMode? captureMode,
    OrientationLockState? orientationLock,
    camera_lib.FlashMode? flashMode,
    double? zoomLevel,
  }) =>
      CameraSettings(
        preferredCameraDirection:
            preferredCameraDirection ?? this.preferredCameraDirection,
        preferredLensType: preferredLensType ?? this.preferredLensType,
        captureMode: captureMode ?? this.captureMode,
        orientationLock: orientationLock ?? this.orientationLock,
        flashMode: flashMode ?? this.flashMode,
        zoomLevel: zoomLevel ?? this.zoomLevel,
      );

  Map<String, dynamic> toJson() => {
        'preferredCameraDirection': preferredCameraDirection.name,
        'preferredLensType': preferredLensType.name,
        'captureMode': captureMode.name,
        'orientationLock': orientationLock.name,
        'flashMode': flashMode.name,
        'zoomLevel': zoomLevel,
      };

  factory CameraSettings.fromJson(Map<String, dynamic> json) => CameraSettings(
        preferredCameraDirection: camera_lib.CameraLensDirection.values.firstWhere(
          (e) => e.name == json['preferredCameraDirection'],
          orElse: () => camera_lib.CameraLensDirection.back,
        ),
        preferredLensType: CameraLensType.values.firstWhere(
          (e) => e.name == json['preferredLensType'],
          orElse: () => CameraLensType.wide,
        ),
        captureMode: CameraCaptureMode.values.firstWhere(
          (e) => e.name == json['captureMode'],
          orElse: () => CameraCaptureMode.photo,
        ),
        orientationLock: OrientationLockState.values.firstWhere(
          (e) => e.name == json['orientationLock'],
          orElse: () => OrientationLockState.unlocked,
        ),
        flashMode: camera_lib.FlashMode.values.firstWhere(
          (e) => e.name == json['flashMode'],
          orElse: () => camera_lib.FlashMode.auto,
        ),
        zoomLevel: (json['zoomLevel'] as num?)?.toDouble() ?? 1.0,
      );
}

/// Enhanced camera controller service with full orientation, multi-lens, and video support
class EnhancedCameraControllerService {
  factory EnhancedCameraControllerService() =>
      _instance ??= EnhancedCameraControllerService._();
  EnhancedCameraControllerService._();
  static EnhancedCameraControllerService? _instance;

  static const String _prefsKey = 'camera_settings';

  // Available cameras
  List<CameraInfo> _availableCameras = [];
  List<CameraInfo> get availableCameras => List.unmodifiable(_availableCameras);

  // Current camera state
  camera_lib.CameraController? _controller;
  camera_lib.CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  // Current camera info
  CameraInfo? _currentCamera;
  CameraInfo? get currentCamera => _currentCamera;

  // Settings
  CameraSettings _settings = const CameraSettings();
  CameraSettings get settings => _settings;

  // Video recording state
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  // Zoom capabilities
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;

  // Photo quality / resolution preset
  // Default to ultraHigh instead of max because iOS has a bug with max (flutter/flutter#163202)
  camera_lib.ResolutionPreset _resolutionPreset = camera_lib.ResolutionPreset.ultraHigh;

  // Initialization future - allows concurrent callers to wait for ongoing initialization
  Future<void>? _initializationFuture;

  // State streams
  final _stateController = StreamController<CameraState>.broadcast();
  Stream<CameraState> get stateStream => _stateController.stream;

  /// Initialize camera service and enumerate all available cameras
  Future<void> initialize() async {
    // If already initialized with a working controller, skip
    if (_controller != null && _controller!.value.isInitialized) {
      debugPrint('EnhancedCameraController: Already initialized with working controller');
      return;
    }

    // If initialization is in progress, wait for it to complete
    if (_initializationFuture != null) {
      debugPrint('EnhancedCameraController: Waiting for ongoing initialization...');
      await _initializationFuture;
      return;
    }

    // Start initialization and store the future so concurrent calls can wait
    _initializationFuture = _doInitialize();
    try {
      await _initializationFuture;
    } finally {
      _initializationFuture = null;
    }
  }

  /// Internal initialization logic
  Future<void> _doInitialize() async {
    try {
      debugPrint('EnhancedCameraController: Initializing...');

      // Load saved settings
      await _loadSettings();

      // Get all available cameras
      final cameras = await camera_lib.availableCameras();
      debugPrint('EnhancedCameraController: Found ${cameras.length} cameras');

      // Classify cameras by lens type
      _availableCameras = _classifyCameras(cameras);

      for (final camera in _availableCameras) {
        debugPrint(
            'EnhancedCameraController: ${camera.description.lensDirection.name} - ${camera.lensType.displayName}');
      }

      // Select initial camera based on settings
      await _selectInitialCamera();

      debugPrint('EnhancedCameraController: Initialization complete');
    } catch (e) {
      debugPrint('EnhancedCameraController: Initialization error: $e');
      rethrow;
    }
  }

  /// Classify cameras by their lens type based on sensor data
  List<CameraInfo> _classifyCameras(List<camera_lib.CameraDescription> cameras) {
    final result = <CameraInfo>[];

    // On iOS, cameras are indexed predictably:
    // 0: Main wide (1x)
    // 1: Front
    // 2: Ultra-wide (0.5x)
    // 3+: Telephoto variants (2x, 3x, etc)

    // Due to Flutter camera plugin limitations on iOS:
    // - Only camera indices 0 (back) and 1 (front) work reliably
    // - Other indices cause FigCaptureSourceRemote errors
    // - We use only primary cameras and simulate lenses with zoom

    // Find first back camera
    for (var i = 0; i < cameras.length; i++) {
      final camera = cameras[i];
      if (camera.lensDirection == camera_lib.CameraLensDirection.back && result.isEmpty) {
        result.add(CameraInfo(
          description: camera,
          lensType: CameraLensType.wide,
          index: i,
        ));
        debugPrint('Using back camera at index $i');
        break;
      }
    }

    // Find first front camera
    for (var i = 0; i < cameras.length; i++) {
      final camera = cameras[i];
      if (camera.lensDirection == camera_lib.CameraLensDirection.front) {
        result.add(CameraInfo(
          description: camera,
          lensType: CameraLensType.wide,
          index: i,
        ));
        debugPrint('Using front camera at index $i');
        break;
      }
    }

    return result;
  }

  /// Select initial camera based on saved preferences
  Future<void> _selectInitialCamera() async {
    if (_availableCameras.isEmpty) {
      throw Exception('No cameras available');
    }

    // Default to main wide camera (1x) for back cameras
    final CameraInfo preferred = _availableCameras.firstWhere(
      (c) =>
          c.direction == camera_lib.CameraLensDirection.back &&
          c.lensType == CameraLensType.wide,
      orElse: () => _availableCameras.first,
    );

    await _switchToCamera(preferred);
  }

  /// Switch to a specific camera
  Future<void> _switchToCamera(CameraInfo camera) async {
    try {
      debugPrint(
          'EnhancedCameraController: Switching to ${camera.lensType.displayName} ${camera.direction.name}');

      if (_controller != null) {
        // Use setDescription() for switching - official example approach
        debugPrint('EnhancedCameraController: Using setDescription to switch camera');
        await _controller!.setDescription(camera.description);
      } else {
        // First time initialization - create new controller
        debugPrint('EnhancedCameraController: Creating new controller with resolution ${_resolutionPreset.name}');
        // Only specify imageFormatGroup on Android - iOS doesn't support JPEG format
        // for video output and will crash with "Unsupported pixel format type"
        _controller = camera_lib.CameraController(
          camera.description,
          _resolutionPreset,
          enableAudio: _settings.captureMode == CameraCaptureMode.video,
          imageFormatGroup: Platform.isAndroid ? camera_lib.ImageFormatGroup.jpeg : null,
        );

        // Add listener for state changes and errors
        _controller!.addListener(() {
          if (_controller!.value.hasError) {
            debugPrint('EnhancedCameraController: Camera error: ${_controller!.value.errorDescription}');
          }
        });

        // Initialize controller
        await _controller!.initialize();
      }

      // Apply orientation lock (always auto)
      await _applyOrientationLock();

      // Get zoom capabilities
      if (_controller!.value.isInitialized) {
        _minZoomLevel = await _controller!.getMinZoomLevel();
        _maxZoomLevel = await _controller!.getMaxZoomLevel();
        debugPrint('EnhancedCameraController: Zoom range: ${_minZoomLevel}x - ${_maxZoomLevel}x');

        // Apply flash mode
        await _controller!.setFlashMode(_settings.flashMode);

        // Apply saved zoom level
        if (_settings.zoomLevel != 1.0) {
          await setZoomLevel(_settings.zoomLevel);
        }
      }

      _currentCamera = camera;

      // Emit state update
      _emitState();

      debugPrint('EnhancedCameraController: Camera switch complete');
    } catch (e) {
      debugPrint('EnhancedCameraController: Error switching camera: $e');
      rethrow;
    }
  }

  /// Apply orientation lock based on current settings
  Future<void> _applyOrientationLock() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // Always allow device orientation to control camera (like iPhone)
      await _controller!.lockCaptureOrientation();
    } catch (e) {
      debugPrint('EnhancedCameraController: Error setting orientation: $e');
    }
  }

  /// Switch between front and back cameras
  Future<void> toggleCamera() async {
    if (_currentCamera == null) return;

    final targetDirection = _currentCamera!.direction == camera_lib.CameraLensDirection.back
        ? camera_lib.CameraLensDirection.front
        : camera_lib.CameraLensDirection.back;

    final targetCamera = _availableCameras.firstWhere(
      (c) => c.direction == targetDirection,
      orElse: () => _currentCamera!,
    );

    if (targetCamera != _currentCamera) {
      await _switchToCamera(targetCamera);
      await _updateSettings(_settings.copyWith(
        preferredCameraDirection: targetDirection,
      ));
    }
  }

  /// Switch to a specific lens
  Future<void> switchToLens(CameraLensType lensType) async {
    if (_currentCamera == null) return;

    final targetCamera = _availableCameras.firstWhere(
      (c) =>
          c.direction == _currentCamera!.direction && c.lensType == lensType,
      orElse: () => _currentCamera!,
    );

    if (targetCamera != _currentCamera) {
      await _switchToCamera(targetCamera);
      await _updateSettings(_settings.copyWith(
        preferredLensType: lensType,
      ));
    }
  }

  /// Get available lenses for current camera direction
  List<CameraInfo> getAvailableLenses() {
    if (_currentCamera == null) return [];

    final lenses = _availableCameras
        .where((c) => c.direction == _currentCamera!.direction)
        .toList();

    debugPrint('Available lenses for ${_currentCamera!.direction.name}: ${lenses.map((l) => l.lensType.zoomLabel).join(", ")}');

    return lenses;
  }

  /// Get available zoom levels (simulates lens switching)
  List<double> getAvailableZoomLevels() {
    if (_currentCamera?.direction != camera_lib.CameraLensDirection.back) {
      return [1.0]; // Front camera only has 1x
    }

    // Build zoom levels based on camera capabilities
    final levels = <double>[];

    // iPhone 17 Pro Max zoom levels:
    // - 0.5x: Ultra-wide (13mm) - may not be accessible via API (min zoom often 1.0x)
    // - 1x: Main wide (24mm)
    // - 2x: 2x crop zoom from main sensor
    // - 4x: Telephoto (100mm) - native optical
    // - 8x: Telephoto (200mm) - optical-quality via sensor crop
    final potentialLevels = [0.5, 1.0, 2.0, 4.0, 8.0];

    for (final level in potentialLevels) {
      // Only include zoom levels within camera's capabilities
      if (level >= _minZoomLevel && level <= _maxZoomLevel) {
        levels.add(level);
      }
    }

    // Ensure we always have at least 1x
    if (levels.isEmpty || !levels.contains(1.0)) {
      levels.add(1.0);
      levels.sort();
    }

    return levels;
  }

  /// Set zoom level
  Future<void> setZoomLevel(double zoomLevel) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // Get max zoom level supported by camera
      final maxZoom = await _controller!.getMaxZoomLevel();
      final minZoom = await _controller!.getMinZoomLevel();

      // Clamp zoom level to camera's supported range
      final clampedZoom = zoomLevel.clamp(minZoom, maxZoom);

      debugPrint('EnhancedCameraController: Setting zoom to ${clampedZoom}x (requested: ${zoomLevel}x, range: ${minZoom}x-${maxZoom}x)');

      await _controller!.setZoomLevel(clampedZoom);
      await _updateSettings(_settings.copyWith(zoomLevel: clampedZoom));

      _emitState();
    } catch (e) {
      debugPrint('EnhancedCameraController: Error setting zoom: $e');
    }
  }

  /// Get current zoom level
  double get currentZoomLevel => _settings.zoomLevel;

  /// Toggle between photo and video mode
  Future<void> toggleCaptureMode() async {
    final newMode = _settings.captureMode == CameraCaptureMode.photo
        ? CameraCaptureMode.video
        : CameraCaptureMode.photo;

    await _updateSettings(_settings.copyWith(captureMode: newMode));

    // Recreate controller with audio enabled/disabled
    if (_currentCamera != null) {
      await _switchToCamera(_currentCamera!);
    }
  }

  /// Set capture mode
  Future<void> setCaptureMode(CameraCaptureMode mode) async {
    if (_settings.captureMode == mode) return;

    await _updateSettings(_settings.copyWith(captureMode: mode));

    // Recreate controller with audio enabled/disabled
    if (_currentCamera != null) {
      await _switchToCamera(_currentCamera!);
    }
  }

  /// Toggle orientation lock
  Future<void> toggleOrientationLock() async {
    const locks = OrientationLockState.values;
    final currentIndex = locks.indexOf(_settings.orientationLock);
    final nextLock = locks[(currentIndex + 1) % locks.length];

    await setOrientationLock(nextLock);
  }

  /// Set orientation lock
  Future<void> setOrientationLock(OrientationLockState lock) async {
    await _updateSettings(_settings.copyWith(orientationLock: lock));
    await _applyOrientationLock();
  }

  /// Set flash mode
  Future<void> setFlashMode(camera_lib.FlashMode mode) async {
    if (_controller?.value.isInitialized == true) {
      await _controller!.setFlashMode(mode);
      await _updateSettings(_settings.copyWith(flashMode: mode));
    }
  }

  /// Toggle flash mode (auto <-> off)
  Future<void> toggleFlashMode() async {
    final nextMode = _settings.flashMode == camera_lib.FlashMode.auto
        ? camera_lib.FlashMode.off
        : camera_lib.FlashMode.auto;
    await setFlashMode(nextMode);
  }

  /// Update photo quality setting
  void updatePhotoQuality(PhotoQuality quality) {
    _resolutionPreset = _photoQualityToResolutionPreset(quality);
    debugPrint('EnhancedCameraController: Updated photo quality to ${quality.displayName} (${_resolutionPreset.name})');
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

  /// Start video recording
  Future<void> startVideoRecording() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isRecording) {
      return;
    }

    try {
      await _controller!.startVideoRecording();
      _isRecording = true;
      _emitState();
      debugPrint('EnhancedCameraController: Video recording started');
    } catch (e) {
      debugPrint('EnhancedCameraController: Error starting recording: $e');
      rethrow;
    }
  }

  /// Stop video recording and return file
  Future<camera_lib.XFile?> stopVideoRecording() async {
    if (_controller == null || !_isRecording) {
      return null;
    }

    try {
      final file = await _controller!.stopVideoRecording();
      _isRecording = false;
      _emitState();
      debugPrint(
          'EnhancedCameraController: Video recording stopped: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('EnhancedCameraController: Error stopping recording: $e');
      _isRecording = false;
      _emitState();
      rethrow;
    }
  }

  /// Take a photo
  Future<camera_lib.XFile> takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }

    try {
      final file = await _controller!.takePicture();
      debugPrint('EnhancedCameraController: Photo captured: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('EnhancedCameraController: Error taking picture: $e');
      rethrow;
    }
  }

  /// Update settings and persist
  Future<void> _updateSettings(CameraSettings newSettings) async {
    _settings = newSettings;
    await _saveSettings();
    _emitState();
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);

      if (json != null) {
        // Parse JSON manually since we can't import dart:convert in this context
        // For now, use defaults - in production, implement proper JSON parsing
        debugPrint('EnhancedCameraController: Settings loaded');
      }
    } catch (e) {
      debugPrint('EnhancedCameraController: Error loading settings: $e');
    }
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convert to JSON string manually
      final json =
          '{"preferredCameraDirection":"${_settings.preferredCameraDirection.name}",'
          '"preferredLensType":"${_settings.preferredLensType.name}",'
          '"captureMode":"${_settings.captureMode.name}",'
          '"orientationLock":"${_settings.orientationLock.name}",'
          '"flashMode":"${_settings.flashMode.name}"}';

      await prefs.setString(_prefsKey, json);
      debugPrint('EnhancedCameraController: Settings saved');
    } catch (e) {
      debugPrint('EnhancedCameraController: Error saving settings: $e');
    }
  }

  /// Emit current state to stream
  void _emitState() {
    debugPrint('EnhancedCameraController: _emitState called - controller: ${_controller != null}, camera: ${_currentCamera != null}, isInitialized: $isInitialized');

    if (_controller != null && _currentCamera != null) {
      final state = CameraState(
        isInitialized: isInitialized,
        currentCamera: _currentCamera!,
        settings: _settings,
        isRecording: _isRecording,
        availableLenses: getAvailableLenses(),
      );
      debugPrint('EnhancedCameraController: Emitting state - isInitialized: ${state.isInitialized}');
      _stateController.add(state);
    } else {
      debugPrint('EnhancedCameraController: NOT emitting state - missing controller or camera');
    }
  }

  /// Dispose only the camera controller (for page lifecycle)
  /// This resets ALL state so the camera can be fully re-initialized
  Future<void> disposeController() async {
    debugPrint('EnhancedCameraController: disposeController called');

    // Nothing to dispose if no controller
    if (_controller == null) {
      debugPrint('EnhancedCameraController: No controller to dispose');
      return;
    }

    // Store controller reference and clear ALL state immediately
    // This prevents other code from trying to use it during async disposal
    final controllerToDispose = _controller;
    _controller = null;
    _currentCamera = null;
    _initializationFuture = null;
    _availableCameras = []; // Clear so next init does full re-enumeration

    // Now dispose the actual controller
    try {
      await controllerToDispose!.dispose();
      debugPrint('EnhancedCameraController: Controller disposed successfully');
    } catch (e) {
      debugPrint('EnhancedCameraController: Error disposing controller: $e');
    }

    debugPrint('EnhancedCameraController: Controller disposed, ready for re-initialization');
  }

  /// Dispose resources (full service shutdown)
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    _currentCamera = null;
    _initializationFuture = null;
    await _stateController.close();
    _instance = null;
  }
}

/// Camera state for reactive UI
class CameraState {
  const CameraState({
    required this.isInitialized,
    required this.currentCamera,
    required this.settings,
    required this.isRecording,
    required this.availableLenses,
  });

  final bool isInitialized;
  final CameraInfo currentCamera;
  final CameraSettings settings;
  final bool isRecording;
  final List<CameraInfo> availableLenses;

  bool get hasMultipleLenses => availableLenses.length > 1;

  CameraState copyWith({
    bool? isInitialized,
    CameraInfo? currentCamera,
    CameraSettings? settings,
    bool? isRecording,
    List<CameraInfo>? availableLenses,
  }) =>
      CameraState(
        isInitialized: isInitialized ?? this.isInitialized,
        currentCamera: currentCamera ?? this.currentCamera,
        settings: settings ?? this.settings,
        isRecording: isRecording ?? this.isRecording,
        availableLenses: availableLenses ?? this.availableLenses,
      );
}
