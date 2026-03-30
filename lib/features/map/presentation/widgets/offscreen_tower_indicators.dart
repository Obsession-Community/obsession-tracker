import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';
import 'package:obsession_tracker/core/providers/app_settings_provider.dart';
import 'package:obsession_tracker/core/providers/cell_coverage_provider.dart';

/// Widget that displays indicators for off-screen cell towers at screen edges
///
/// Shows simple arrow indicators pointing toward nearby cell towers that are
/// outside the current viewport, with distance labels.
class OffscreenTowerIndicators extends ConsumerWidget {
  const OffscreenTowerIndicators({
    super.key,
    required this.indicators,
  });

  final List<OffscreenTowerIndicator> indicators;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (indicators.isEmpty) return const SizedBox.shrink();

    final generalSettings = ref.watch(generalSettingsProvider);
    final useMetric = generalSettings.units == MeasurementUnits.metric;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: indicators.map((indicator) {
            return _EdgeIndicator(
              indicator: indicator,
              useMetric: useMetric,
              screenWidth: constraints.maxWidth,
              screenHeight: constraints.maxHeight,
            );
          }).toList(),
        );
      },
    );
  }
}

/// Simple edge-hugging indicator with arrow and distance
class _EdgeIndicator extends StatelessWidget {
  const _EdgeIndicator({
    required this.indicator,
    required this.useMetric,
    required this.screenWidth,
    required this.screenHeight,
  });

  final OffscreenTowerIndicator indicator;
  final bool useMetric;
  final double screenWidth;
  final double screenHeight;

  // Minimal margins - just enough to avoid system UI
  static const double _edgeInset = 4.0;
  static const double _topSafeArea = 60.0; // Status bar area
  static const double _bottomSafeArea = 100.0; // Bottom controls

  String _formatDistance(double meters) {
    if (useMetric) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    } else {
      final miles = meters / 1609.344;
      return '${miles.toStringAsFixed(1)}mi';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = indicator.tower.radioType.color;
    final distance = _formatDistance(indicator.distanceMeters);

    // Arrow rotation: bearing 0° = north = up
    final arrowRotation = indicator.bearingDegrees * (math.pi / 180);

    // Calculate position along the edge based on bearing
    final pos = _getEdgePosition();

    return Positioned(
      left: pos.left,
      top: pos.top,
      right: pos.right,
      bottom: pos.bottom,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Arrow pointing toward tower
            Transform.rotate(
              angle: arrowRotation,
              child: Icon(
                Icons.navigation,
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(width: 3),
            // Distance only - keep it simple
            Text(
              distance,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Calculate position directly on the screen edge
  ({double? left, double? top, double? right, double? bottom}) _getEdgePosition() {
    final bearing = indicator.bearingDegrees;

    // Usable range on each edge (avoiding corners and safe areas)
    final horizontalRange = screenWidth - 120; // Leave 60px on each side for corners
    final verticalRange = screenHeight - _topSafeArea - _bottomSafeArea - 40; // Leave room

    switch (indicator.edgePosition) {
      case ScreenEdge.top:
        // Bearing 315-360-0-45 maps along top edge
        // 315° = left side, 0° = center, 45° = right side
        double normalizedBearing = bearing;
        if (bearing >= 315) {
          normalizedBearing = bearing - 315; // 315->0, 360->45
        } else {
          normalizedBearing = bearing + 45; // 0->45, 45->90
        }
        final fraction = (normalizedBearing / 90.0).clamp(0.0, 1.0);
        final leftPos = 60 + (horizontalRange * fraction) - 30; // Center the widget
        return (left: leftPos.clamp(8.0, screenWidth - 80), top: _topSafeArea, right: null, bottom: null);

      case ScreenEdge.right:
        // Bearing 45-135 maps along right edge
        final fraction = ((bearing - 45) / 90.0).clamp(0.0, 1.0);
        final topPos = _topSafeArea + 20 + (verticalRange * fraction);
        return (left: null, top: topPos.clamp(_topSafeArea, screenHeight - _bottomSafeArea - 30), right: _edgeInset, bottom: null);

      case ScreenEdge.bottom:
        // Bearing 135-225 maps along bottom edge (right to left)
        final fraction = ((bearing - 135) / 90.0).clamp(0.0, 1.0);
        final rightPos = 60 + (horizontalRange * fraction) - 30;
        return (left: null, top: null, right: rightPos.clamp(8.0, screenWidth - 80), bottom: _bottomSafeArea);

      case ScreenEdge.left:
        // Bearing 225-315 maps along left edge (bottom to top)
        final fraction = ((bearing - 225) / 90.0).clamp(0.0, 1.0);
        final bottomPos = _bottomSafeArea + 20 + (verticalRange * fraction);
        return (left: _edgeInset, top: null, right: null, bottom: bottomPos.clamp(_bottomSafeArea, screenHeight - _topSafeArea - 30));
    }
  }
}
