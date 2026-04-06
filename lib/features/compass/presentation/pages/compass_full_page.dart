import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/compass_provider.dart';
import 'package:obsession_tracker/core/providers/custom_north_provider.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/features/compass/presentation/widgets/custom_north_display.dart';
import 'package:obsession_tracker/features/compass/presentation/widgets/custom_north_manager.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/compass/compass_rose.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/compass/magnetic_compass_needle.dart';

/// Full-page compass screen with magnetic and custom North modes.
class CompassFullPage extends ConsumerStatefulWidget {
  const CompassFullPage({super.key});

  @override
  ConsumerState<CompassFullPage> createState() => _CompassFullPageState();
}

class _CompassFullPageState extends ConsumerState<CompassFullPage> {
  // Track cumulative turns to avoid snapping at 0/360 boundary
  double _previousTurns = 0;

  @override
  void initState() {
    super.initState();
    // Start compass when page opens
    Future.microtask(() {
      ref.read(compassProvider.notifier).start();
    });
  }

  /// Convert a target rotation (in degrees) to cumulative turns that
  /// always take the shortest path, avoiding the 0/360 snap.
  double _smoothTurns(double targetDegrees) {
    final targetTurns = targetDegrees / 360.0;
    // Calculate the shortest delta (wrapping around ±0.5 turns)
    var delta = targetTurns - _previousTurns;
    delta = delta - (delta + 0.5).floorToDouble(); // normalize to [-0.5, 0.5)
    _previousTurns += delta;
    return _previousTurns;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compassState = ref.watch(compassProvider);
    final compassNotifier = ref.read(compassProvider.notifier);
    final customNorthState = ref.watch(customNorthProvider);
    final activeRef = customNorthState.activeReference;
    final locationState = ref.watch(locationProvider);
    final isCustomNorth = activeRef != null;

    // Calculate bearing to custom North target (null when in magnetic mode)
    final double? bearingToTarget =
        isCustomNorth && locationState.currentPosition != null
            ? CustomNorthNotifier.calculateBearingToTarget(
                locationState.currentPosition!.latitude,
                locationState.currentPosition!.longitude,
                activeRef.latitude,
                activeRef.longitude,
              )
            : null;

    // Rotation: In magnetic mode, rotate rose by -heading so N points north.
    // In custom North mode, rotate so the N marker points toward the target.
    // The rose must rotate by -(heading - bearingToTarget) so that when the
    // device faces the target (heading == bearingToTarget), N points up.
    final rotationDegrees = bearingToTarget != null
        ? -(compassState.heading - bearingToTarget)
        : -compassState.heading;

    final displayHeading = bearingToTarget ?? compassState.heading;
    final bearingText = compassNotifier.getBearingText(displayHeading);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compass'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.explore),
            tooltip: 'Custom North References',
            onPressed: () => CustomNorthManager.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Mode indicator
            _buildModeIndicator(theme, activeRef?.name, isCustomNorth),
            const SizedBox(height: 24),

            // Compass rose — large, centered
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxSize = math.min(
                      constraints.maxWidth * 0.85,
                      constraints.maxHeight * 0.85,
                    );
                    final roseSize = math.max(200.0, maxSize);

                    return AnimatedRotation(
                      turns: _smoothTurns(rotationDegrees),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: SizedBox(
                        width: roseSize,
                        height: roseSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CompassRose(
                              size: roseSize,
                              backgroundColor: theme.colorScheme.surface,
                              borderColor: isCustomNorth
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.6)
                                  : theme.colorScheme.outline,
                              textColor: isCustomNorth
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                              majorTickColor: isCustomNorth
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                              minorTickColor: isCustomNorth
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.6)
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                            ),
                            MagneticCompassNeedle(
                              heading: 0, // Needle points up; rose rotates
                              size: roseSize * 0.7,
                              needleColor: isCustomNorth
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Bearing display
            Text(
              bearingText,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),

            // Accuracy indicator
            _buildAccuracyIndicator(theme, compassState),
            const SizedBox(height: 16),

            // Custom North info card (only when active)
            if (isCustomNorth)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: CustomNorthDisplay(),
              ),

            // Set Custom North button (when in magnetic mode)
            if (!isCustomNorth)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => CustomNorthManager.show(context),
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('Set Custom North'),
                  ),
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildModeIndicator(ThemeData theme, String? refName, bool isCustom) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isCustom
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCustom ? Icons.my_location : Icons.explore,
            size: 16,
            color: isCustom
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface,
          ),
          const SizedBox(width: 8),
          Text(
            isCustom ? refName ?? 'Custom North' : 'Magnetic North',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isCustom
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyIndicator(ThemeData theme, CompassState compassState) {
    if (!compassState.isActive) {
      return Text(
        'Compass Inactive',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }

    Color indicatorColor;
    if (!compassState.isCalibrated) {
      indicatorColor = theme.colorScheme.secondary;
    } else if (compassState.isUsingGpsFallback) {
      indicatorColor = theme.colorScheme.primary;
    } else {
      indicatorColor = theme.colorScheme.tertiary;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          compassState.isCalibrated ? Icons.explore : Icons.sync,
          size: 14,
          color: indicatorColor,
        ),
        const SizedBox(width: 4),
        Text(
          compassState.accuracyDescription,
          style: theme.textTheme.bodySmall?.copyWith(
            color: indicatorColor,
          ),
        ),
      ],
    );
  }
}
