import 'package:flutter/material.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/compass/magnetic_compass_needle.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/compass/map_orientation_needle.dart';

/// Dual compass needle system that displays both magnetic north and map orientation
/// Combines the red magnetic needle and blue map orientation needle
class DualCompassNeedle extends StatelessWidget {
  const DualCompassNeedle({
    required this.heading,
    required this.mapRotation,
    this.size = 80.0,
    this.magneticNeedleColor,
    this.mapNeedleColor,
    super.key,
  });

  /// Current compass heading in degrees (0-360)
  final double heading;

  /// Current map rotation in degrees (0-360)
  final double mapRotation;

  /// Size of the compass needles
  final double size;

  /// Color of the magnetic north needle (defaults to theme error color)
  final Color? magneticNeedleColor;

  /// Color of the map orientation needle (defaults to theme primary color)
  final Color? mapNeedleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Map orientation needle (blue) - rendered first (behind)
          Transform.rotate(
            angle: mapRotation * (3.14159 / 180),
            child: MapOrientationNeedle(
              mapRotation: 0, // Rotation handled by Transform.rotate
              size: size,
              needleColor: mapNeedleColor ?? theme.colorScheme.primary,
            ),
          ),

          // Magnetic compass needle (red) - rendered second (in front)
          Transform.rotate(
            angle: -(heading + mapRotation) * (3.14159 / 180),
            child: MagneticCompassNeedle(
              heading: 0, // Rotation handled by Transform.rotate
              size: size,
              needleColor: magneticNeedleColor ?? theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

/// Enhanced dual compass needle with additional visual features
class EnhancedDualCompassNeedle extends StatelessWidget {
  const EnhancedDualCompassNeedle({
    required this.heading,
    required this.mapRotation,
    this.size = 80.0,
    this.magneticNeedleColor,
    this.mapNeedleColor,
    this.showNeedleLabels = false,
    this.isMapRotated = false,
    super.key,
  });

  /// Current compass heading in degrees (0-360)
  final double heading;

  /// Current map rotation in degrees (0-360)
  final double mapRotation;

  /// Size of the compass needles
  final double size;

  /// Color of the magnetic north needle (defaults to theme error color)
  final Color? magneticNeedleColor;

  /// Color of the map orientation needle (defaults to theme primary color)
  final Color? mapNeedleColor;

  /// Whether to show small labels on the needles
  final bool showNeedleLabels;

  /// Whether the map is currently rotated (affects needle prominence)
  final bool isMapRotated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveMagneticColor =
        magneticNeedleColor ?? theme.colorScheme.error;
    final effectiveMapColor = mapNeedleColor ?? theme.colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Map orientation needle (blue) - adjust opacity based on map rotation
          AnimatedOpacity(
            opacity: isMapRotated ? 1.0 : 0.6,
            duration: const Duration(milliseconds: 200),
            child: Transform.rotate(
              angle: mapRotation * (3.14159 / 180),
              child: MapOrientationNeedle(
                mapRotation: 0, // Rotation handled by Transform.rotate
                size: size,
                needleColor: effectiveMapColor,
              ),
            ),
          ),

          // Magnetic compass needle (red) - always prominent
          Transform.rotate(
            angle: -(heading + mapRotation) * (3.14159 / 180),
            child: MagneticCompassNeedle(
              heading: 0, // Rotation handled by Transform.rotate
              size: size,
              needleColor: effectiveMagneticColor,
            ),
          ),

          // Optional needle labels
          if (showNeedleLabels) ...[
            // Magnetic needle label
            Positioned(
              top: size * 0.15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: effectiveMagneticColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'N',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Map orientation label (only when map is rotated)
            if (isMapRotated)
              Positioned(
                bottom: size * 0.15,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: effectiveMapColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'M',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
