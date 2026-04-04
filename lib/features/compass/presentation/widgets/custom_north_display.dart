import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/custom_north_reference.dart';
import 'package:obsession_tracker/core/providers/custom_north_provider.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';

/// Displays live bearing and distance to the active custom North target.
class CustomNorthDisplay extends ConsumerWidget {
  const CustomNorthDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeRef = ref.watch(activeCustomNorthProvider);
    final locationState = ref.watch(locationProvider);

    if (activeRef == null) return const SizedBox.shrink();

    final pos = locationState.currentPosition;
    if (pos == null) {
      return _buildCard(
        theme: theme,
        reference: activeRef,
        bearingText: '---',
        distanceText: 'Waiting for GPS...',
      );
    }

    final bearing = CustomNorthNotifier.calculateBearingToTarget(
      pos.latitude,
      pos.longitude,
      activeRef.latitude,
      activeRef.longitude,
    );
    final distanceMeters = CustomNorthNotifier.calculateDistanceMeters(
      pos.latitude,
      pos.longitude,
      activeRef.latitude,
      activeRef.longitude,
    );

    final bearingText = '${bearing.round()}°';
    final distanceText = _formatDistance(distanceMeters);

    return _buildCard(
      theme: theme,
      reference: activeRef,
      bearingText: bearingText,
      distanceText: distanceText,
    );
  }

  Widget _buildCard({
    required ThemeData theme,
    required CustomNorthReference reference,
    required String bearingText,
    required String distanceText,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.my_location,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  reference.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(
                      'Bearing',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bearingText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                Column(
                  children: [
                    Text(
                      'Distance',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      distanceText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else if (meters < 100000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    } else {
      return '${(meters / 1000).round()} km';
    }
  }
}
