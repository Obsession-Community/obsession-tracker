import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/compass_provider.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/compass/compass_legend.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/compass/compass_needle.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/compass/compass_rose.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/compass/dual_compass_needle.dart';

/// Main compass widget that displays heading with rose and needle
class CompassWidget extends ConsumerWidget {
  const CompassWidget({
    this.size = 120.0,
    this.showHeadingText = true,
    this.showAccuracyIndicator = true,
    this.useDualNeedles = true,
    this.showLegend = true,
    this.compactLegend = true,
    super.key,
  });

  /// Size of the compass widget
  final double size;

  /// Whether to show heading text below compass
  final bool showHeadingText;

  /// Whether to show accuracy indicator
  final bool showAccuracyIndicator;

  /// Whether to use dual needles (magnetic + map orientation)
  final bool useDualNeedles;

  /// Whether to show the compass legend
  final bool showLegend;

  /// Whether to use compact legend format
  final bool compactLegend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CompassState compassState = ref.watch(compassProvider);
    final String bearingText = ref.watch(compassBearingProvider);
    final theme = Theme.of(context);

    return SizedBox(
      height: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main compass display - use Expanded to fit within available space
          Expanded(
            child: SizedBox(
              width: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Compass rose (static, but rotated by map rotation to show map orientation)
                  Transform.rotate(
                    angle: compassState.mapRotation * (3.14159 / 180),
                    child: CompassRose(
                      size: size,
                      backgroundColor: theme.colorScheme.surface,
                      borderColor: compassState.isMapRotated
                          ? theme.colorScheme.primary.withValues(alpha: 0.6)
                          : theme.colorScheme.outline,
                      textColor: compassState.isMapRotated
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      majorTickColor: compassState.isMapRotated
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      minorTickColor: compassState.isMapRotated
                          ? theme.colorScheme.primary.withValues(alpha: 0.6)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),

                  // Compass needle system - dual needles or single needle
                  if (useDualNeedles)
                    EnhancedDualCompassNeedle(
                      heading: compassState.heading,
                      mapRotation: compassState.mapRotation,
                      size: size * 0.7,
                      magneticNeedleColor: theme.colorScheme.error,
                      mapNeedleColor: theme.colorScheme.primary,
                      isMapRotated: compassState.isMapRotated,
                    )
                  else
                    // Legacy single needle (for backward compatibility)
                    AnimatedRotation(
                      turns:
                          -(compassState.heading + compassState.mapRotation) /
                              360,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: CompassNeedle(
                        heading: 0, // Needle is rotated by AnimatedRotation
                        size: size * 0.7,
                        needleColor: theme.colorScheme.error,
                        southColor:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),

                  // Map rotation indicator
                  if (compassState.isMapRotated)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.refresh,
                          size: 10,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),

                  // Inactive overlay
                  if (!compassState.isActive)
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.compass_calibration,
                        size: size * 0.3,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Heading text with map rotation indicator
          if (showHeadingText) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  compassState.isActive ? bearingText : 'Compass Inactive',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: compassState.isActive
                        ? (compassState.isMapRotated
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (compassState.isMapRotated) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.screen_rotation,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
            if (compassState.isMapRotated) ...[
              const SizedBox(height: 2),
              Text(
                'Map rotated ${compassState.mapRotation.round()}°',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],

          // Accuracy indicator
          if (showAccuracyIndicator && compassState.isActive) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getAccuracyIcon(compassState),
                  size: 12,
                  color: _getAccuracyColor(compassState, theme),
                ),
                const SizedBox(width: 4),
                Text(
                  compassState.accuracyDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _getAccuracyColor(compassState, theme),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],

          // Error message
          if (compassState.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              compassState.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Compass legend (only for dual needle mode)
          if (useDualNeedles && showLegend) ...[
            const SizedBox(height: 8),
            AnimatedCompassLegend(
              magneticNeedleColor: theme.colorScheme.error,
              mapNeedleColor: theme.colorScheme.primary,
              isMapRotated: compassState.isMapRotated,
              isCompact: compactLegend,
            ),
          ],
        ],
      ),
    );
  }

  IconData _getAccuracyIcon(CompassState state) {
    if (!state.isCalibrated) {
      return Icons.sync;
    } else if (state.isUsingGpsFallback) {
      return Icons.gps_fixed;
    } else {
      return Icons.explore;
    }
  }

  Color _getAccuracyColor(CompassState state, ThemeData theme) {
    if (!state.isCalibrated) {
      return theme.colorScheme.secondary;
    } else if (state.isUsingGpsFallback) {
      return theme.colorScheme.primary;
    } else {
      return theme.colorScheme.tertiary;
    }
  }
}
