import 'package:flutter/foundation.dart';

/// Settings for controlling map gesture behavior
@immutable
class MapGestureSettings {
  const MapGestureSettings({
    this.rotationEnabled = true,
    this.rotationSensitivity = RotationSensitivity.medium,
    this.rotationLockEnabled = true, // Default to locked (north-up)
    this.zoomPriorityEnabled = true,
    this.rotationThreshold = 15.0,
    this.simultaneousGestureThreshold = 0.3,
    this.showGestureIndicators = true,
    this.hapticFeedbackEnabled = true,
  });

  /// Whether rotation gestures are enabled at all
  final bool rotationEnabled;

  /// Sensitivity level for rotation detection
  final RotationSensitivity rotationSensitivity;

  /// Whether rotation is completely locked (overrides rotationEnabled)
  final bool rotationLockEnabled;

  /// Whether zoom gestures take priority over rotation when both are detected
  final bool zoomPriorityEnabled;

  /// Minimum rotation angle (in degrees) before rotation is considered intentional
  final double rotationThreshold;

  /// Threshold for detecting simultaneous gestures (0.0 to 1.0)
  /// Lower values make it easier to trigger zoom-only mode
  final double simultaneousGestureThreshold;

  /// Whether to show visual indicators for gesture states
  final bool showGestureIndicators;

  /// Whether to provide haptic feedback for gesture state changes
  final bool hapticFeedbackEnabled;

  /// Create a copy with modified values
  MapGestureSettings copyWith({
    bool? rotationEnabled,
    RotationSensitivity? rotationSensitivity,
    bool? rotationLockEnabled,
    bool? zoomPriorityEnabled,
    double? rotationThreshold,
    double? simultaneousGestureThreshold,
    bool? showGestureIndicators,
    bool? hapticFeedbackEnabled,
  }) =>
      MapGestureSettings(
        rotationEnabled: rotationEnabled ?? this.rotationEnabled,
        rotationSensitivity: rotationSensitivity ?? this.rotationSensitivity,
        rotationLockEnabled: rotationLockEnabled ?? this.rotationLockEnabled,
        zoomPriorityEnabled: zoomPriorityEnabled ?? this.zoomPriorityEnabled,
        rotationThreshold: rotationThreshold ?? this.rotationThreshold,
        simultaneousGestureThreshold:
            simultaneousGestureThreshold ?? this.simultaneousGestureThreshold,
        showGestureIndicators:
            showGestureIndicators ?? this.showGestureIndicators,
        hapticFeedbackEnabled:
            hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      );

  /// Get rotation threshold based on sensitivity setting
  double get effectiveRotationThreshold {
    switch (rotationSensitivity) {
      case RotationSensitivity.low:
        return rotationThreshold * 2.0; // 30 degrees
      case RotationSensitivity.medium:
        return rotationThreshold; // 15 degrees
      case RotationSensitivity.high:
        return rotationThreshold * 0.5; // 7.5 degrees
    }
  }

  /// Get simultaneous gesture threshold based on sensitivity
  double get effectiveSimultaneousThreshold {
    switch (rotationSensitivity) {
      case RotationSensitivity.low:
        return simultaneousGestureThreshold *
            0.5; // Easier to trigger zoom-only
      case RotationSensitivity.medium:
        return simultaneousGestureThreshold;
      case RotationSensitivity.high:
        return simultaneousGestureThreshold *
            1.5; // Harder to trigger zoom-only
    }
  }

  /// Whether rotation should be completely disabled
  bool get isRotationDisabled => rotationLockEnabled || !rotationEnabled;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapGestureSettings &&
        other.rotationEnabled == rotationEnabled &&
        other.rotationSensitivity == rotationSensitivity &&
        other.rotationLockEnabled == rotationLockEnabled &&
        other.zoomPriorityEnabled == zoomPriorityEnabled &&
        other.rotationThreshold == rotationThreshold &&
        other.simultaneousGestureThreshold == simultaneousGestureThreshold &&
        other.showGestureIndicators == showGestureIndicators &&
        other.hapticFeedbackEnabled == hapticFeedbackEnabled;
  }

  @override
  int get hashCode => Object.hash(
        rotationEnabled,
        rotationSensitivity,
        rotationLockEnabled,
        zoomPriorityEnabled,
        rotationThreshold,
        simultaneousGestureThreshold,
        showGestureIndicators,
        hapticFeedbackEnabled,
      );

  @override
  String toString() => 'MapGestureSettings('
      'rotationEnabled: $rotationEnabled, '
      'rotationSensitivity: $rotationSensitivity, '
      'rotationLockEnabled: $rotationLockEnabled, '
      'zoomPriorityEnabled: $zoomPriorityEnabled, '
      'rotationThreshold: $rotationThreshold, '
      'simultaneousGestureThreshold: $simultaneousGestureThreshold, '
      'showGestureIndicators: $showGestureIndicators, '
      'hapticFeedbackEnabled: $hapticFeedbackEnabled'
      ')';
}

/// Rotation sensitivity levels
enum RotationSensitivity {
  /// Low sensitivity - requires larger rotation angles to trigger
  low,

  /// Medium sensitivity - balanced rotation detection
  medium,

  /// High sensitivity - triggers rotation with smaller angles
  high,
}

extension RotationSensitivityExtension on RotationSensitivity {
  /// Human-readable name for the sensitivity level
  String get displayName {
    switch (this) {
      case RotationSensitivity.low:
        return 'Low';
      case RotationSensitivity.medium:
        return 'Medium';
      case RotationSensitivity.high:
        return 'High';
    }
  }

  /// Description of what this sensitivity level does
  String get description {
    switch (this) {
      case RotationSensitivity.low:
        return 'Requires larger finger movements to rotate the map';
      case RotationSensitivity.medium:
        return 'Balanced rotation detection for most users';
      case RotationSensitivity.high:
        return 'Responds to smaller finger movements for rotation';
    }
  }
}

/// Current gesture state for visual feedback
enum MapGestureState {
  /// No active gestures
  idle,

  /// User is zooming (pinch gesture detected)
  zooming,

  /// User is rotating (rotation gesture detected)
  rotating,

  /// User is performing both zoom and rotation
  zoomingAndRotating,

  /// Rotation is being ignored due to zoom priority
  zoomingWithIgnoredRotation,
}

extension MapGestureStateExtension on MapGestureState {
  /// Whether this state involves zooming
  bool get isZooming {
    switch (this) {
      case MapGestureState.idle:
      case MapGestureState.rotating:
        return false;
      case MapGestureState.zooming:
      case MapGestureState.zoomingAndRotating:
      case MapGestureState.zoomingWithIgnoredRotation:
        return true;
    }
  }

  /// Whether this state involves rotation
  bool get isRotating {
    switch (this) {
      case MapGestureState.idle:
      case MapGestureState.zooming:
      case MapGestureState.zoomingWithIgnoredRotation:
        return false;
      case MapGestureState.rotating:
      case MapGestureState.zoomingAndRotating:
        return true;
    }
  }

  /// Whether rotation is being ignored in this state
  bool get isRotationIgnored =>
      this == MapGestureState.zoomingWithIgnoredRotation;

  /// Display name for the gesture state
  String get displayName {
    switch (this) {
      case MapGestureState.idle:
        return 'Ready';
      case MapGestureState.zooming:
        return 'Zooming';
      case MapGestureState.rotating:
        return 'Rotating';
      case MapGestureState.zoomingAndRotating:
        return 'Zoom & Rotate';
      case MapGestureState.zoomingWithIgnoredRotation:
        return 'Zoom Only';
    }
  }
}
