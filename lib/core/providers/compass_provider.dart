import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/core/services/compass_service.dart';

/// State for compass functionality
@immutable
class CompassState {
  const CompassState({
    this.heading = 0.0,
    this.mapRotation = 0.0,
    this.isActive = false,
    this.isCalibrated = false,
    this.isUsingGpsFallback = false,
    this.accuracyDescription = 'Inactive',
    this.errorMessage,
  });

  /// Current compass heading in degrees (0-360)
  /// 0 = North, 90 = East, 180 = South, 270 = West
  final double heading;

  /// Current map rotation in degrees (0-360)
  /// 0 = North up, positive values = clockwise rotation
  final double mapRotation;

  /// Whether the compass is currently active
  final bool isActive;

  /// Whether the compass has been calibrated
  final bool isCalibrated;

  /// Whether GPS heading is being used as fallback
  final bool isUsingGpsFallback;

  /// Human-readable accuracy description
  final String accuracyDescription;

  /// Error message if any
  final String? errorMessage;

  CompassState copyWith({
    double? heading,
    double? mapRotation,
    bool? isActive,
    bool? isCalibrated,
    bool? isUsingGpsFallback,
    String? accuracyDescription,
    String? errorMessage,
  }) =>
      CompassState(
        heading: heading ?? this.heading,
        mapRotation: mapRotation ?? this.mapRotation,
        isActive: isActive ?? this.isActive,
        isCalibrated: isCalibrated ?? this.isCalibrated,
        isUsingGpsFallback: isUsingGpsFallback ?? this.isUsingGpsFallback,
        accuracyDescription: accuracyDescription ?? this.accuracyDescription,
        errorMessage: errorMessage,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompassState &&
          runtimeType == other.runtimeType &&
          heading == other.heading &&
          mapRotation == other.mapRotation &&
          isActive == other.isActive &&
          isCalibrated == other.isCalibrated &&
          isUsingGpsFallback == other.isUsingGpsFallback &&
          accuracyDescription == other.accuracyDescription &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      heading.hashCode ^
      mapRotation.hashCode ^
      isActive.hashCode ^
      isCalibrated.hashCode ^
      isUsingGpsFallback.hashCode ^
      accuracyDescription.hashCode ^
      errorMessage.hashCode;

  /// Whether the map is rotated away from north (tolerance of 5 degrees)
  bool get isMapRotated => (mapRotation % 360).abs() > 5.0;
}

/// Notifier for managing compass state and operations
class CompassNotifier extends Notifier<CompassState> {
  late final CompassService _compassService;
  StreamSubscription<double>? _headingSubscription;
  Timer? _updateTimer;
  DateTime _lastUpdateTime = DateTime.now();
  bool _isDisposed = false;

  @override
  CompassState build() {
    _compassService = CompassService();

    ref.onDispose(() {
      _isDisposed = true;
      _headingSubscription?.cancel();
      _updateTimer?.cancel();
      _compassService.dispose();
    });

    return const CompassState();
  }

  /// Start compass tracking
  Future<void> start() async {
    if (state.isActive) return;

    try {
      // debugPrint('🧭 Starting compass provider...');

      // Initialize location listener when starting (not in constructor)
      _initializeLocationListener();

      await _compassService.start();

      // Subscribe to heading updates with throttling
      _headingSubscription = _compassService.headingStream.listen(
        _handleHeadingUpdate,
        onError: _handleCompassError,
      );

      // Start periodic updates for accuracy status
      _updateTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _updateAccuracyStatus(),
      );

      state = state.copyWith(
        isActive: true,
      );

      // debugPrint('🧭 Compass provider started successfully');
      // debugPrint(
      //     '🧭 Heading stream subscription active: ${_headingSubscription != null}');
    } catch (e) {
      debugPrint('🧭 Error starting compass: $e');
      state = state.copyWith(
        errorMessage: 'Failed to start compass: $e',
      );
    }
  }

  /// Stop compass tracking
  Future<void> stop() async {
    if (!state.isActive) return;

    try {
      await _compassService.stop();
      await _headingSubscription?.cancel();
      _headingSubscription = null;

      _updateTimer?.cancel();
      _updateTimer = null;

      state = state.copyWith(
        isActive: false,
        isCalibrated: false,
        accuracyDescription: 'Inactive',
      );

      debugPrint('Compass stopped');
    } catch (e) {
      debugPrint('Error stopping compass: $e');
      state = state.copyWith(
        errorMessage: 'Error stopping compass: $e',
      );
    }
  }

  /// Calibrate compass
  void calibrate() {
    if (!state.isActive) return;

    _compassService.calibrate();
    state = state.copyWith(
      isCalibrated: false,
      accuracyDescription: 'Calibrating...',
    );

    debugPrint('Compass calibration initiated');
  }

  /// Initialize location listener for GPS heading fallback
  void _initializeLocationListener() {
    try {
      // Listen to location changes for GPS heading fallback
      ref.listen<LocationState>(
        locationProvider,
        (previous, next) {
          // Check if we're still active before handling updates
          if (!_isDisposed) {
            // Update GPS heading for fallback
            final double? gpsHeading = next.currentPosition?.heading;
            if (gpsHeading != null && gpsHeading >= 0) {
              _compassService.updateGpsHeading(gpsHeading);
            }
          }
        },
      );
    } catch (e) {
      // Handle cases where location provider might be disposed
      // debugPrint('🧭 Could not initialize location listener: $e');
    }
  }

  /// Handle heading updates from compass service
  void _handleHeadingUpdate(double heading) {
    if (_isDisposed) return;

    final now = DateTime.now();
    final timeDiff = now.difference(_lastUpdateTime).inMilliseconds;
    final headingDiff = (heading - state.heading).abs();

    // debugPrint(
    //     '🧭 Received heading update: ${heading.toStringAsFixed(1)}° (diff: ${headingDiff.toStringAsFixed(2)}°, time: ${timeDiff}ms)');

    // Apply time-based throttling (~60Hz for smooth updates)
    if (timeDiff < 16) {
      // debugPrint('🧭 Skipping update - too frequent (${timeDiff}ms < 16ms)');
      return; // Skip updates that are too frequent
    }

    // Apply heading threshold to prevent excessive updates
    if (headingDiff < 0.1 && state.isCalibrated) {
      // debugPrint(
      //     '🧭 Skipping update - change too small (${headingDiff.toStringAsFixed(2)}° < 0.1°)');
      return; // Skip small changes to reduce UI updates
    }

    _lastUpdateTime = now;
    if (!_isDisposed) {
      state = state.copyWith(
        heading: heading,
        isCalibrated: _compassService.isCalibrated,
      );
    }

    // debugPrint(
    //     '🧭 State updated - heading: ${heading.toStringAsFixed(1)}°, calibrated: ${_compassService.isCalibrated}');
  }

  /// Handle compass service errors
  void _handleCompassError(Object error) {
    debugPrint('Compass error: $error');
    state = state.copyWith(
      errorMessage: 'Compass error: $error',
    );
  }

  /// Update accuracy status periodically
  void _updateAccuracyStatus() {
    if (!state.isActive) return;

    final bool isUsingGps = _compassService.isUsingGpsFallback;
    final String accuracy = _compassService.accuracyDescription;

    if (state.isUsingGpsFallback != isUsingGps ||
        state.accuracyDescription != accuracy) {
      state = state.copyWith(
        isUsingGpsFallback: isUsingGps,
        accuracyDescription: accuracy,
      );
    }
  }

  /// Get compass direction name from heading
  String getDirectionName(double heading) {
    const List<String> directions = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW'
    ];

    final int index = ((heading + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }

  /// Get compass bearing text
  String getBearingText(double heading) =>
      '${heading.round()}° ${getDirectionName(heading)}';

  /// Update map rotation state
  void updateMapRotation(double rotation) {
    // Normalize rotation to 0-360 range
    final double normalizedRotation = rotation % 360;
    if ((state.mapRotation - normalizedRotation).abs() > 1.0) {
      state = state.copyWith(mapRotation: normalizedRotation);
    }
  }

  /// Reset map rotation to north (0 degrees)
  /// Returns the target rotation for smooth animation via shortest path
  double resetMapToNorth() {
    final double currentRotation = state.mapRotation;

    // Normalize current rotation to 0-360 range
    final double normalizedCurrent = currentRotation % 360;

    // Calculate the shortest path to north (0 degrees)
    double targetRotation;

    // If rotation is > 180°, it's shorter to go forward to 360° (which equals 0°)
    // Example: 270° → 360° is +90° (shorter than 270° → 0° which is -270°)
    if (normalizedCurrent > 180) {
      // Use currentRotation (not normalized) to maintain animation direction
      // Round up to next 360 boundary
      targetRotation = ((currentRotation / 360).ceil() * 360).toDouble();
    } else {
      // If rotation is ≤ 180°, go directly to 0° (or round down to previous 360 boundary)
      // Example: 90° → 0° is -90° (shorter than 90° → 360° which is +270°)
      targetRotation = ((currentRotation / 360).floor() * 360).toDouble();
    }

    // Update state immediately to north
    state = state.copyWith(mapRotation: 0.0);

    return targetRotation;
  }

}

/// Provider for compass functionality
final NotifierProvider<CompassNotifier, CompassState> compassProvider =
    NotifierProvider<CompassNotifier, CompassState>(
  CompassNotifier.new,
);

/// Provider for current compass heading (convenience)
final Provider<double> compassHeadingProvider = Provider<double>(
  (ref) => ref.watch(compassProvider).heading,
);

/// Provider for compass active status (convenience)
final Provider<bool> compassActiveProvider = Provider<bool>(
  (ref) => ref.watch(compassProvider).isActive,
);

/// Provider for compass calibration status (convenience)
final Provider<bool> compassCalibratedProvider = Provider<bool>(
  (ref) => ref.watch(compassProvider).isCalibrated,
);

/// Provider for compass direction name (convenience)
final Provider<String> compassDirectionProvider = Provider<String>(
  (ref) {
    final compassState = ref.watch(compassProvider);
    final notifier = ref.read(compassProvider.notifier);
    return notifier.getDirectionName(compassState.heading);
  },
);

/// Provider for compass bearing text (convenience)
final Provider<String> compassBearingProvider = Provider<String>(
  (ref) {
    final compassState = ref.watch(compassProvider);
    final notifier = ref.read(compassProvider.notifier);
    return notifier.getBearingText(compassState.heading);
  },
);

/// Provider for map rotation (convenience)
final Provider<double> mapRotationProvider = Provider<double>(
  (ref) => ref.watch(compassProvider).mapRotation,
);

/// Provider for map rotated status (convenience)
final Provider<bool> mapRotatedProvider = Provider<bool>(
  (ref) => ref.watch(compassProvider).isMapRotated,
);
