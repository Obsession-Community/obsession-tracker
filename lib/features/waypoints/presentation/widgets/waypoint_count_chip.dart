import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/waypoint_provider.dart';
import 'package:obsession_tracker/core/services/waypoint_icon_service.dart';

/// Chip widget displaying waypoint count for the current session.
///
/// Shows total waypoint count with optional breakdown by type.
/// Provides visual feedback and can be tapped for more details.
class WaypointCountChip extends ConsumerWidget {
  const WaypointCountChip({
    required this.sessionId,
    super.key,
    this.showTypeBreakdown = false,
    this.onTap,
  });

  /// The session ID to count waypoints for
  final String sessionId;

  /// Whether to show breakdown by waypoint type
  final bool showTypeBreakdown;

  /// Callback when the chip is tapped
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int totalCount = ref.watch(totalWaypointCountProvider);

    if (totalCount == 0) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.place,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '$totalCount waypoint${totalCount == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              if (showTypeBreakdown && totalCount > 0) ...<Widget>[
                const SizedBox(width: 8),
                _buildTypeBreakdown(context, ref),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBreakdown(BuildContext context, WidgetRef ref) => Row(
        mainAxisSize: MainAxisSize.min,
        children: WaypointType.values
            .map((WaypointType type) {
              final int count = ref.watch(waypointCountByTypeProvider(type));
              if (count == 0) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: WaypointIconService.instance
                        .getIconColor(type)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      WaypointIconService.instance.getIconWidgetCustomSize(
                        type,
                        width: 12,
                        color: WaypointIconService.instance.getIconColor(type),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$count',
                        style: TextStyle(
                          color:
                              WaypointIconService.instance.getIconColor(type),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            })
            .where((Widget widget) => widget is! SizedBox)
            .toList(),
      );
}

/// Compact waypoint count display for minimal space usage
class CompactWaypointCount extends ConsumerWidget {
  const CompactWaypointCount({
    required this.sessionId,
    super.key,
    this.onTap,
  });

  /// The session ID to count waypoints for
  final String sessionId;

  /// Callback when the count is tapped
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int totalCount = ref.watch(totalWaypointCountProvider);

    if (totalCount == 0) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.place,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 2),
            Text(
              '$totalCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detailed waypoint statistics widget showing breakdown by type
class WaypointStatistics extends ConsumerWidget {
  const WaypointStatistics({
    required this.sessionId,
    super.key,
  });

  /// The session ID to show statistics for
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int totalCount = ref.watch(totalWaypointCountProvider);

    if (totalCount == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              Icon(
                Icons.place_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'No waypoints yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Start marking interesting locations during your adventure',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.place),
                const SizedBox(width: 8),
                Text(
                  'Waypoints',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalCount total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WaypointType.values
                  .map((WaypointType type) =>
                      _buildTypeStatistic(context, ref, type))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeStatistic(
      BuildContext context, WidgetRef ref, WaypointType type) {
    final int count = ref.watch(waypointCountByTypeProvider(type));
    final Color typeColor = WaypointIconService.instance.getIconColor(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: count > 0
            ? typeColor.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: count > 0
              ? typeColor.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          WaypointIconService.instance.getIconWidgetCustomSize(
            type,
            width: 16,
            color: count > 0 ? typeColor : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            type.displayName,
            style: TextStyle(
              color: count > 0 ? typeColor : Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: count > 0 ? typeColor : Colors.grey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
