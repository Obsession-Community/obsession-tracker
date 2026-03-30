import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/map_gesture_settings.dart';
import 'package:obsession_tracker/core/providers/map_gesture_provider.dart';

/// Visual indicator showing current map gesture state
class GestureIndicator extends ConsumerWidget {
  const GestureIndicator({
    super.key,
    this.showWhenIdle = false,
    this.position = GestureIndicatorPosition.topLeft,
  });

  /// Whether to show the indicator when no gesture is active
  final bool showWhenIdle;

  /// Position of the indicator on screen
  final GestureIndicatorPosition position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gestureState = ref.watch(currentMapGestureStateProvider);
    final settings = ref.watch(mapGestureSettingsProvider);

    // Don't show if indicators are disabled in settings
    if (!settings.showGestureIndicators) {
      return const SizedBox.shrink();
    }

    // Don't show when idle unless explicitly requested
    if (gestureState == MapGestureState.idle && !showWhenIdle) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: gestureState == MapGestureState.idle ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getBackgroundColor(gestureState, context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getGestureIcon(gestureState),
              size: 16,
              color: _getIconColor(gestureState, context),
            ),
            const SizedBox(width: 6),
            Text(
              gestureState.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _getTextColor(gestureState, context),
              ),
            ),
            if (gestureState.isRotationIgnored) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.block,
                size: 12,
                color: Colors.orange.shade700,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Get background color based on gesture state
  Color _getBackgroundColor(MapGestureState state, BuildContext context) {
    final theme = Theme.of(context);

    switch (state) {
      case MapGestureState.idle:
        return theme.colorScheme.surface.withValues(alpha: 0.9);
      case MapGestureState.zooming:
        return Colors.blue.shade100.withValues(alpha: 0.9);
      case MapGestureState.rotating:
        return Colors.green.shade100.withValues(alpha: 0.9);
      case MapGestureState.zoomingAndRotating:
        return Colors.purple.shade100.withValues(alpha: 0.9);
      case MapGestureState.zoomingWithIgnoredRotation:
        return Colors.orange.shade100.withValues(alpha: 0.9);
    }
  }

  /// Get icon color based on gesture state
  Color _getIconColor(MapGestureState state, BuildContext context) {
    switch (state) {
      case MapGestureState.idle:
        return Theme.of(context).colorScheme.onSurface;
      case MapGestureState.zooming:
        return Colors.blue.shade700;
      case MapGestureState.rotating:
        return Colors.green.shade700;
      case MapGestureState.zoomingAndRotating:
        return Colors.purple.shade700;
      case MapGestureState.zoomingWithIgnoredRotation:
        return Colors.orange.shade700;
    }
  }

  /// Get text color based on gesture state
  Color _getTextColor(MapGestureState state, BuildContext context) {
    switch (state) {
      case MapGestureState.idle:
        return Theme.of(context).colorScheme.onSurface;
      case MapGestureState.zooming:
        return Colors.blue.shade800;
      case MapGestureState.rotating:
        return Colors.green.shade800;
      case MapGestureState.zoomingAndRotating:
        return Colors.purple.shade800;
      case MapGestureState.zoomingWithIgnoredRotation:
        return Colors.orange.shade800;
    }
  }

  /// Get icon for gesture state
  IconData _getGestureIcon(MapGestureState state) {
    switch (state) {
      case MapGestureState.idle:
        return Icons.touch_app;
      case MapGestureState.zooming:
        return Icons.zoom_in;
      case MapGestureState.rotating:
        return Icons.rotate_right;
      case MapGestureState.zoomingAndRotating:
        return Icons.open_with;
      case MapGestureState.zoomingWithIgnoredRotation:
        return Icons.zoom_in;
    }
  }
}

/// Position options for the gesture indicator
enum GestureIndicatorPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  center,
}

/// Positioned gesture indicator that can be placed in a Stack
class PositionedGestureIndicator extends StatelessWidget {
  const PositionedGestureIndicator({
    super.key,
    this.position = GestureIndicatorPosition.topLeft,
    this.margin = const EdgeInsets.all(16),
    this.showWhenIdle = false,
  });

  final GestureIndicatorPosition position;
  final EdgeInsets margin;
  final bool showWhenIdle;

  @override
  Widget build(BuildContext context) => Positioned(
        top: _getTop(),
        bottom: _getBottom(),
        left: _getLeft(),
        right: _getRight(),
        child: GestureIndicator(
          showWhenIdle: showWhenIdle,
          position: position,
        ),
      );

  double? _getTop() {
    switch (position) {
      case GestureIndicatorPosition.topLeft:
      case GestureIndicatorPosition.topRight:
        return margin.top;
      case GestureIndicatorPosition.center:
        return null;
      case GestureIndicatorPosition.bottomLeft:
      case GestureIndicatorPosition.bottomRight:
        return null;
    }
  }

  double? _getBottom() {
    switch (position) {
      case GestureIndicatorPosition.bottomLeft:
      case GestureIndicatorPosition.bottomRight:
        return margin.bottom;
      case GestureIndicatorPosition.topLeft:
      case GestureIndicatorPosition.topRight:
      case GestureIndicatorPosition.center:
        return null;
    }
  }

  double? _getLeft() {
    switch (position) {
      case GestureIndicatorPosition.topLeft:
      case GestureIndicatorPosition.bottomLeft:
        return margin.left;
      case GestureIndicatorPosition.center:
        return null;
      case GestureIndicatorPosition.topRight:
      case GestureIndicatorPosition.bottomRight:
        return null;
    }
  }

  double? _getRight() {
    switch (position) {
      case GestureIndicatorPosition.topRight:
      case GestureIndicatorPosition.bottomRight:
        return margin.right;
      case GestureIndicatorPosition.topLeft:
      case GestureIndicatorPosition.bottomLeft:
      case GestureIndicatorPosition.center:
        return null;
    }
  }
}

/// Compact gesture indicator for toolbar use
class CompactGestureIndicator extends ConsumerWidget {
  const CompactGestureIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gestureState = ref.watch(currentMapGestureStateProvider);
    final settings = ref.watch(mapGestureSettingsProvider);

    if (!settings.showGestureIndicators) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getBackgroundColor(gestureState, context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBorderColor(gestureState, context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getGestureIcon(gestureState),
            size: 14,
            color: _getIconColor(gestureState, context),
          ),
          if (gestureState.isRotationIgnored) ...[
            const SizedBox(width: 2),
            Icon(
              Icons.block,
              size: 10,
              color: Colors.orange.shade700,
            ),
          ],
        ],
      ),
    );
  }

  Color _getBackgroundColor(MapGestureState state, BuildContext context) {
    if (state == MapGestureState.idle) {
      return Colors.transparent;
    }

    switch (state) {
      case MapGestureState.idle:
        return Colors.transparent;
      case MapGestureState.zooming:
        return Colors.blue.shade50;
      case MapGestureState.rotating:
        return Colors.green.shade50;
      case MapGestureState.zoomingAndRotating:
        return Colors.purple.shade50;
      case MapGestureState.zoomingWithIgnoredRotation:
        return Colors.orange.shade50;
    }
  }

  Color _getBorderColor(MapGestureState state, BuildContext context) {
    switch (state) {
      case MapGestureState.idle:
        return Colors.grey.shade300;
      case MapGestureState.zooming:
        return Colors.blue.shade300;
      case MapGestureState.rotating:
        return Colors.green.shade300;
      case MapGestureState.zoomingAndRotating:
        return Colors.purple.shade300;
      case MapGestureState.zoomingWithIgnoredRotation:
        return Colors.orange.shade300;
    }
  }

  Color _getIconColor(MapGestureState state, BuildContext context) {
    switch (state) {
      case MapGestureState.idle:
        return Colors.grey.shade600;
      case MapGestureState.zooming:
        return Colors.blue.shade600;
      case MapGestureState.rotating:
        return Colors.green.shade600;
      case MapGestureState.zoomingAndRotating:
        return Colors.purple.shade600;
      case MapGestureState.zoomingWithIgnoredRotation:
        return Colors.orange.shade600;
    }
  }

  IconData _getGestureIcon(MapGestureState state) {
    switch (state) {
      case MapGestureState.idle:
        return Icons.touch_app_outlined;
      case MapGestureState.zooming:
        return Icons.zoom_in;
      case MapGestureState.rotating:
        return Icons.rotate_right;
      case MapGestureState.zoomingAndRotating:
        return Icons.open_with;
      case MapGestureState.zoomingWithIgnoredRotation:
        return Icons.zoom_in;
    }
  }
}
