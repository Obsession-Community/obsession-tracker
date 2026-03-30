import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/compass_provider.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/compass/compass_widget.dart';

/// Compass overlay widget for map display
/// Provides a compact compass that can be positioned on the map
class CompassOverlay extends ConsumerStatefulWidget {
  const CompassOverlay({
    this.size = 80.0,
    this.autoStart = true,
    this.showHeadingText = false,
    this.showAccuracyIndicator = false,
    this.onTap,
    super.key,
  });

  /// Size of the compass overlay
  final double size;

  /// Whether to automatically start compass when widget is created
  final bool autoStart;

  /// Whether to show heading text (usually false for overlay)
  final bool showHeadingText;

  /// Whether to show accuracy indicator (usually false for overlay)
  final bool showAccuracyIndicator;

  /// Callback when compass is tapped
  final VoidCallback? onTap;

  @override
  ConsumerState<CompassOverlay> createState() => _CompassOverlayState();
}

class _CompassOverlayState extends ConsumerState<CompassOverlay>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.autoStart) {
      // Start compass after widget is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startCompass();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Don't call _stopCompass() here as ref is not available during disposal
    // The compass service will be cleaned up by its own disposal mechanism
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    // Handle app lifecycle changes for better battery management
    switch (state) {
      case AppLifecycleState.resumed:
        if (widget.autoStart) {
          _startCompass();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _stopCompass();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopCompass();
        break;
    }
  }

  void _startCompass() {
    if (!mounted) return;

    final compassNotifier = ref.read(compassProvider.notifier);
    final compassState = ref.read(compassProvider);

    if (!compassState.isActive) {
      compassNotifier.start();
    }
  }

  void _stopCompass() {
    if (!mounted) return;

    final compassNotifier = ref.read(compassProvider.notifier);
    if (ref.read(compassProvider).isActive) {
      compassNotifier.stop();
    }
  }

  void _handleTap() {
    if (!mounted) return;

    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      // Default behavior: toggle compass or show calibration dialog
      final compassState = ref.read(compassProvider);
      if (!compassState.isActive) {
        _startCompass();
      } else if (!compassState.isCalibrated) {
        _showCalibrationDialog();
      }
    }
  }

  void _showCalibrationDialog() {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compass Calibration'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To calibrate your compass:'),
            SizedBox(height: 8),
            Text('1. Hold your device away from metal objects'),
            Text('2. Move your device in a figure-8 pattern'),
            Text('3. Rotate the device in all directions'),
            SizedBox(height: 8),
            Text('The compass will automatically calibrate as you move.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(compassProvider.notifier).calibrate();
            },
            child: const Text('Start Calibration'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compassState = ref.watch(compassProvider);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: _handleTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Main compass widget (this already has its own shadow via CompassRose)
            CompassWidget(
              size: widget.size,
              showHeadingText: widget.showHeadingText,
              showAccuracyIndicator: widget.showAccuracyIndicator,
              showLegend: false, // Never show legend in overlay mode
            ),

            // Visual indicator for map rotation state
            if (compassState.isMapRotated)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                    ),
                  ),
                  child: Icon(
                    Icons.refresh,
                    size: 8,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),

            // Tap hint overlay when map is rotated
            if (compassState.isMapRotated)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact compass overlay for minimal space usage
class CompactCompassOverlay extends ConsumerWidget {
  const CompactCompassOverlay({
    this.size = 60.0,
    this.onTap,
    super.key,
  });

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compassState = ref.watch(compassProvider);
    final String direction = ref.watch(compassDirectionProvider);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(
            color: compassState.isMapRotated
                ? theme.colorScheme.primary.withValues(alpha: 0.6)
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: compassState.isMapRotated ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Direction text
            Text(
              compassState.isActive ? direction : '?',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: compassState.isActive
                    ? (compassState.isMapRotated
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),

            // North indicator (small red dot) - rotated by map rotation + compass heading
            if (compassState.isActive)
              Positioned(
                top: 4,
                child: Transform.rotate(
                  angle: -(compassState.heading + compassState.mapRotation) *
                      (3.14159 / 180),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

            // Map rotation indicator
            if (compassState.isMapRotated)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

            // Status indicator
            if (!compassState.isActive || !compassState.isCalibrated)
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: !compassState.isActive
                        ? theme.colorScheme.error
                        : theme.colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
