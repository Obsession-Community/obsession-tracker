import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/map_gesture_settings.dart';
import 'package:obsession_tracker/core/providers/app_settings_provider.dart';

// Legacy flutter_map InteractiveFlag replacement - all gestures enabled
const int _kInteractiveFlagAll = 0xFF;

/// State for map gesture handling
@immutable
class MapGestureProviderState {
  const MapGestureProviderState({
    this.settings = const MapGestureSettings(),
    this.currentGestureState = MapGestureState.idle,
    this.isGestureActive = false,
    this.lastRotationAngle = 0.0,
    this.lastZoomLevel = 0.0,
    this.gestureStartTime,
    this.rotationAccumulator = 0.0,
    this.zoomAccumulator = 0.0,
    this.interactiveFlags = _kInteractiveFlagAll,
  });

  /// Current gesture settings
  final MapGestureSettings settings;

  /// Current gesture state for UI feedback
  final MapGestureState currentGestureState;

  /// Whether any gesture is currently active
  final bool isGestureActive;

  /// Last recorded rotation angle
  final double lastRotationAngle;

  /// Last recorded zoom level
  final double lastZoomLevel;

  /// When the current gesture started
  final DateTime? gestureStartTime;

  /// Accumulated rotation during current gesture
  final double rotationAccumulator;

  /// Accumulated zoom during current gesture
  final double zoomAccumulator;

  /// Current interactive flags (legacy from OSM, kept for compatibility)
  final int interactiveFlags;

  /// Create a copy with modified values
  MapGestureProviderState copyWith({
    MapGestureSettings? settings,
    MapGestureState? currentGestureState,
    bool? isGestureActive,
    double? lastRotationAngle,
    double? lastZoomLevel,
    DateTime? gestureStartTime,
    double? rotationAccumulator,
    double? zoomAccumulator,
    int? interactiveFlags,
  }) =>
      MapGestureProviderState(
        settings: settings ?? this.settings,
        currentGestureState: currentGestureState ?? this.currentGestureState,
        isGestureActive: isGestureActive ?? this.isGestureActive,
        lastRotationAngle: lastRotationAngle ?? this.lastRotationAngle,
        lastZoomLevel: lastZoomLevel ?? this.lastZoomLevel,
        gestureStartTime: gestureStartTime ?? this.gestureStartTime,
        rotationAccumulator: rotationAccumulator ?? this.rotationAccumulator,
        zoomAccumulator: zoomAccumulator ?? this.zoomAccumulator,
        interactiveFlags: interactiveFlags ?? this.interactiveFlags,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapGestureProviderState &&
        other.settings == settings &&
        other.currentGestureState == currentGestureState &&
        other.isGestureActive == isGestureActive &&
        other.lastRotationAngle == lastRotationAngle &&
        other.lastZoomLevel == lastZoomLevel &&
        other.gestureStartTime == gestureStartTime &&
        other.rotationAccumulator == rotationAccumulator &&
        other.zoomAccumulator == zoomAccumulator &&
        other.interactiveFlags == interactiveFlags;
  }

  @override
  int get hashCode => Object.hash(
        settings,
        currentGestureState,
        isGestureActive,
        lastRotationAngle,
        lastZoomLevel,
        gestureStartTime,
        rotationAccumulator,
        zoomAccumulator,
        interactiveFlags,
      );
}

/// Notifier for managing map gesture behavior
class MapGestureNotifier extends Notifier<MapGestureProviderState> {
  Timer? _gestureTimeoutTimer;

  @override
  MapGestureProviderState build() {
    ref.onDispose(() {
      _gestureTimeoutTimer?.cancel();
    });
    _initializeFromSettings();
    return const MapGestureProviderState();
  }

  static const Duration _gestureTimeout = Duration(milliseconds: 500);

  /// Initialize gesture settings from app settings
  void _initializeFromSettings() {
    debugPrint('🧭 MapGesture: Starting settings initialization...');

    // Listen to app settings changes to initialize rotation lock
    ref.listen(appSettingsProvider, (previous, next) {
      debugPrint('🧭 MapGesture: Settings listener triggered, previous: $previous, next: $next');
      next.when(
        data: (appSettings) {
          // FORCE rotation lock to be enabled for all users
          const forceRotationLockEnabled = true;
          debugPrint('🧭 MapGesture: Listener - rotateWithCompass: ${appSettings.map.rotateWithCompass}, FORCING rotationLockEnabled: $forceRotationLockEnabled');

          // Always force rotation lock enabled
          if (state.settings.rotationLockEnabled != forceRotationLockEnabled) {
            final initialSettings = state.settings.copyWith(
              rotationLockEnabled: forceRotationLockEnabled,
            );

            state = state.copyWith(settings: initialSettings);
            _updateInteractiveFlags();

            debugPrint('🧭 MapGesture: Updated rotation lock from listener (FORCED): $forceRotationLockEnabled');
          } else {
            debugPrint('🧭 MapGesture: No change needed, current: ${state.settings.rotationLockEnabled}, forced: $forceRotationLockEnabled');
          }
        },
        loading: () => debugPrint('🧭 MapGesture: Settings listener - still loading'),
        error: (error, stack) => debugPrint('🧭 MapGesture: Settings listener error: $error'),
      );
    });

    // Also try to read current settings immediately if available
    final appSettingsAsync = ref.read(appSettingsProvider);
    debugPrint('🧭 MapGesture: Immediate read result: $appSettingsAsync');

    appSettingsAsync.when(
      data: (appSettings) {
        // FORCE rotation lock to be enabled on startup for all users
        const forceRotationLockEnabled = true;
        debugPrint('🧭 MapGesture: Immediate - rotateWithCompass: ${appSettings.map.rotateWithCompass}, FORCING rotationLockEnabled: $forceRotationLockEnabled');

        final initialSettings = state.settings.copyWith(
          rotationLockEnabled: forceRotationLockEnabled,
        );

        state = state.copyWith(settings: initialSettings);
        _updateInteractiveFlags();

        // Also persist this forced setting to app settings so UI shows correct state
        if (appSettings.map.rotateWithCompass) {
          debugPrint('🧭 MapGesture: Updating app settings to disable rotateWithCompass');
          final newMapSettings = appSettings.map.copyWith(
            rotateWithCompass: false,
          );
          ref.read(appSettingsServiceProvider).updateMapSettings(newMapSettings);
        }

        debugPrint('🧭 MapGesture: Set initial rotation lock setting (FORCED): $forceRotationLockEnabled');
      },
      loading: () => debugPrint('🧭 MapGesture: App settings still loading during initialization'),
      error: (error, stack) => debugPrint('🧭 MapGesture: App settings error during initialization: $error'),
    );
  }

  /// Update gesture settings
  void updateSettings(MapGestureSettings settings) {
    state = state.copyWith(settings: settings);
    _updateInteractiveFlags();
  }

  /// Toggle rotation lock
  Future<void> toggleRotationLock() async {
    final newRotationLockEnabled = !state.settings.rotationLockEnabled;

    final newSettings = state.settings.copyWith(
      rotationLockEnabled: newRotationLockEnabled,
    );
    updateSettings(newSettings);

    // Persist to app settings
    final appSettingsAsync = ref.read(appSettingsProvider);
    appSettingsAsync.whenData((appSettings) async {
      final newMapSettings = appSettings.map.copyWith(
        rotateWithCompass: !newRotationLockEnabled,
      );

      try {
        await ref.read(appSettingsServiceProvider).updateMapSettings(newMapSettings);
      } catch (e) {
        // If saving fails, revert the in-memory state
        final revertedSettings = state.settings.copyWith(
          rotationLockEnabled: !newRotationLockEnabled,
        );
        updateSettings(revertedSettings);
        rethrow;
      }
    });

    if (state.settings.hapticFeedbackEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Set rotation sensitivity
  void setRotationSensitivity(RotationSensitivity sensitivity) {
    final newSettings =
        state.settings.copyWith(rotationSensitivity: sensitivity);
    updateSettings(newSettings);
  }

  /// Handle map position changes to detect and filter gestures
  /// Legacy OSM MapCamera removed - using simple double values now
  void handleMapPositionChanged(
    double rotation,
    double zoom, {
    required bool hasGesture,
  }) {
    if (!hasGesture) {
      _endGesture();
      return;
    }

    final now = DateTime.now();
    final isNewGesture = !state.isGestureActive;

    if (isNewGesture) {
      _startGesture(now, rotation, zoom);
    }

    _updateGestureState(rotation, zoom, now);
    _resetGestureTimeout();
  }

  /// Start a new gesture
  void _startGesture(DateTime startTime, double rotation, double zoom) {
    state = state.copyWith(
      isGestureActive: true,
      gestureStartTime: startTime,
      lastRotationAngle: rotation,
      lastZoomLevel: zoom,
      rotationAccumulator: 0.0,
      zoomAccumulator: 0.0,
    );
  }

  /// Update gesture state based on camera changes
  void _updateGestureState(double rotation, double zoom, DateTime now) {
    final rotationDelta = _calculateRotationDelta(rotation);
    final zoomDelta = zoom - state.lastZoomLevel;

    // Accumulate gesture changes
    final newRotationAccumulator =
        state.rotationAccumulator + rotationDelta.abs();
    final newZoomAccumulator = state.zoomAccumulator + zoomDelta.abs();

    state = state.copyWith(
      lastRotationAngle: rotation,
      lastZoomLevel: zoom,
      rotationAccumulator: newRotationAccumulator,
      zoomAccumulator: newZoomAccumulator,
    );

    // Determine gesture type based on accumulated changes
    final gestureState = _determineGestureState(
      newRotationAccumulator,
      newZoomAccumulator,
    );

    if (gestureState != state.currentGestureState) {
      state = state.copyWith(currentGestureState: gestureState);

      // Update interactive flags based on gesture state
      _updateInteractiveFlagsForGesture(gestureState);

      // Provide haptic feedback for state changes
      if (state.settings.hapticFeedbackEnabled) {
        _provideHapticFeedback(gestureState);
      }
    }
  }

  /// Calculate rotation delta, handling 360-degree wraparound
  double _calculateRotationDelta(double newRotation) {
    double delta = newRotation - state.lastRotationAngle;

    // Handle 360-degree wraparound
    if (delta > 180) {
      delta -= 360;
    } else if (delta < -180) {
      delta += 360;
    }

    return delta;
  }

  /// Determine the current gesture state based on accumulated changes
  MapGestureState _determineGestureState(
      double rotationAccum, double zoomAccum) {
    final settings = state.settings;

    // If rotation is disabled, only consider zoom
    if (settings.isRotationDisabled) {
      return zoomAccum > 0.1 ? MapGestureState.zooming : MapGestureState.idle;
    }

    final hasSignificantRotation =
        rotationAccum > settings.effectiveRotationThreshold;
    final hasSignificantZoom = zoomAccum > 0.1;

    if (!hasSignificantRotation && !hasSignificantZoom) {
      return MapGestureState.idle;
    }

    if (hasSignificantZoom && hasSignificantRotation) {
      // Both gestures detected - check if zoom should take priority
      if (settings.zoomPriorityEnabled) {
        final zoomToRotationRatio =
            zoomAccum / (rotationAccum / 10.0); // Normalize rotation
        if (zoomToRotationRatio > settings.effectiveSimultaneousThreshold) {
          return MapGestureState.zoomingWithIgnoredRotation;
        }
      }
      return MapGestureState.zoomingAndRotating;
    }

    if (hasSignificantZoom) {
      return MapGestureState.zooming;
    }

    if (hasSignificantRotation) {
      return MapGestureState.rotating;
    }

    return MapGestureState.idle;
  }

  /// Update interactive flags based on current gesture state
  /// Legacy OSM InteractiveFlag removed - kept for compatibility
  void _updateInteractiveFlagsForGesture(MapGestureState gestureState) {
    int flags = _kInteractiveFlagAll;

    if (state.settings.isRotationDisabled) {
      flags = flags & ~0x04; // Disable rotation flag
    } else if (gestureState == MapGestureState.zoomingWithIgnoredRotation) {
      // Temporarily disable rotation when zoom takes priority
      flags = flags & ~0x04; // Disable rotation flag
    }

    if (flags != state.interactiveFlags) {
      state = state.copyWith(interactiveFlags: flags);
    }
  }

  /// Update interactive flags based on settings
  void _updateInteractiveFlags() {
    int flags = _kInteractiveFlagAll;

    if (state.settings.isRotationDisabled) {
      flags = flags & ~0x04; // Disable rotation flag
    }

    state = state.copyWith(interactiveFlags: flags);
  }

  /// Provide haptic feedback for gesture state changes
  void _provideHapticFeedback(MapGestureState gestureState) {
    switch (gestureState) {
      case MapGestureState.idle:
        // No feedback for idle state
        break;
      case MapGestureState.zooming:
      case MapGestureState.rotating:
        HapticFeedback.lightImpact();
        break;
      case MapGestureState.zoomingAndRotating:
        HapticFeedback.mediumImpact();
        break;
      case MapGestureState.zoomingWithIgnoredRotation:
        // Double tap for ignored rotation
        HapticFeedback.lightImpact();
        Future<void>.delayed(
            const Duration(milliseconds: 50), HapticFeedback.lightImpact);
        break;
    }
  }

  /// Reset gesture timeout timer
  void _resetGestureTimeout() {
    _gestureTimeoutTimer?.cancel();
    _gestureTimeoutTimer = Timer(_gestureTimeout, _endGesture);
  }

  /// End the current gesture
  void _endGesture() {
    _gestureTimeoutTimer?.cancel();

    if (state.isGestureActive) {
      state = state.copyWith(
        isGestureActive: false,
        currentGestureState: MapGestureState.idle,
        rotationAccumulator: 0.0,
        zoomAccumulator: 0.0,
      );

      // Reset interactive flags to default
      _updateInteractiveFlags();
    }
  }

  /// Get current gesture duration
  Duration? get currentGestureDuration {
    final startTime = state.gestureStartTime;
    if (startTime == null) return null;
    return DateTime.now().difference(startTime);
  }

  /// Check if rotation is currently being ignored
  bool get isRotationIgnored => state.currentGestureState.isRotationIgnored;

  /// Get a description of the current gesture state
  String get gestureStateDescription {
    final gestureState = state.currentGestureState;
    final settings = state.settings;

    if (settings.isRotationDisabled) {
      return 'Rotation locked';
    }

    switch (gestureState) {
      case MapGestureState.idle:
        return 'Ready for gestures';
      case MapGestureState.zooming:
        return 'Zooming map';
      case MapGestureState.rotating:
        return 'Rotating map';
      case MapGestureState.zoomingAndRotating:
        return 'Zoom and rotate';
      case MapGestureState.zoomingWithIgnoredRotation:
        return 'Zoom only (rotation ignored)';
    }
  }
}

/// Provider for map gesture management
final mapGestureProvider =
    NotifierProvider<MapGestureNotifier, MapGestureProviderState>(
  MapGestureNotifier.new,
);

/// Convenience provider for current gesture settings
final mapGestureSettingsProvider = Provider<MapGestureSettings>(
  (ref) => ref.watch(mapGestureProvider).settings,
);

/// Convenience provider for current interactive flags
final mapInteractiveFlagsProvider = Provider<int>(
  (ref) => ref.watch(mapGestureProvider).interactiveFlags,
);

/// Convenience provider for current gesture state
final currentMapGestureStateProvider = Provider<MapGestureState>(
  (ref) => ref.watch(mapGestureProvider).currentGestureState,
);
