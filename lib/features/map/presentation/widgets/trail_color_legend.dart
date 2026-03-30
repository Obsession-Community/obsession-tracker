import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/session_statistics.dart';
import 'package:obsession_tracker/core/models/trail_color_scheme.dart';
import 'package:obsession_tracker/core/providers/trail_color_provider.dart';
import 'package:obsession_tracker/core/services/trail_color_service.dart';

/// Widget that displays a color legend for the current trail color scheme
class TrailColorLegend extends ConsumerWidget {
  const TrailColorLegend({
    super.key,
    this.sessionId,
    this.isCompact = false,
  });

  /// Session ID to get statistics for
  final String? sessionId;

  /// Whether to show a compact version of the legend
  final bool isCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TrailColorState colorState = ref.watch(trailColorProvider);

    // Don't show legend if disabled or color coding is disabled
    if (!colorState.showLegend || !colorState.isEnabled) {
      return const SizedBox.shrink();
    }

    // For now, pass null statistics - in a full implementation you would
    // integrate with the statistics provider to get session statistics
    const SessionStatistics? statistics = null;

    final List<ColorLegendItem> legendItems =
        ref.read(trailColorProvider.notifier).getColorLegend(statistics);

    if (legendItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  _getIconForColorMode(colorState.currentScheme.mode),
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _getTitleForColorMode(colorState.currentScheme.mode),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (!isCompact) ...<Widget>[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () =>
                        ref.read(trailColorProvider.notifier).toggleLegend(),
                    tooltip: 'Hide legend',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (isCompact)
              _buildCompactLegend(context, legendItems)
            else
              _buildFullLegend(context, legendItems),
            if (colorState.currentScheme.description != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                colorState.currentScheme.description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFullLegend(BuildContext context, List<ColorLegendItem> items) =>
      Column(
        children: items
            .map((ColorLegendItem item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 20,
                        height: 12,
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(2),
                          border:
                              Border.all(color: Colors.grey[300]!, width: 0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.label,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      );

  Widget _buildCompactLegend(
          BuildContext context, List<ColorLegendItem> items) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ...items.take(3).map((ColorLegendItem item) => Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Tooltip(
                  message: item.label,
                  child: Container(
                    width: 16,
                    height: 8,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(1),
                      border: Border.all(color: Colors.grey[300]!, width: 0.5),
                    ),
                  ),
                ),
              )),
          if (items.length > 3) ...<Widget>[
            const SizedBox(width: 4),
            Text(
              '+${items.length - 3}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ],
      );

  IconData _getIconForColorMode(TrailColorMode mode) {
    switch (mode) {
      case TrailColorMode.speed:
        return Icons.speed;
      case TrailColorMode.time:
        return Icons.schedule;
      case TrailColorMode.elevation:
        return Icons.terrain;
      case TrailColorMode.accuracy:
        return Icons.gps_fixed;
      case TrailColorMode.single:
        return Icons.palette;
    }
  }

  String _getTitleForColorMode(TrailColorMode mode) {
    switch (mode) {
      case TrailColorMode.speed:
        return 'Speed';
      case TrailColorMode.time:
        return 'Time';
      case TrailColorMode.elevation:
        return 'Elevation';
      case TrailColorMode.accuracy:
        return 'GPS Accuracy';
      case TrailColorMode.single:
        return 'Trail';
    }
  }
}

/// Floating action button for toggling color legend visibility
class ColorLegendToggleButton extends ConsumerWidget {
  const ColorLegendToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TrailColorState colorState = ref.watch(trailColorProvider);

    if (!colorState.isEnabled) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton.small(
      heroTag: 'color_legend_toggle',
      onPressed: () => ref.read(trailColorProvider.notifier).toggleLegend(),
      backgroundColor: colorState.showLegend ? Colors.blue : null,
      child: Icon(
        colorState.showLegend
            ? Icons.legend_toggle
            : Icons.legend_toggle_outlined,
      ),
    );
  }
}

/// Mini color indicator that shows current color scheme
class TrailColorIndicator extends ConsumerWidget {
  const TrailColorIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TrailColorState colorState = ref.watch(trailColorProvider);

    if (!colorState.isEnabled ||
        colorState.currentScheme.mode == TrailColorMode.single) {
      return Container(
        width: 24,
        height: 12,
        decoration: BoxDecoration(
          color: colorState.currentScheme.colors.first,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: Colors.grey[300]!, width: 0.5),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: colorState.currentScheme.colors
          .take(4)
          .map((Color color) => Container(
                width: 6,
                height: 12,
                margin: const EdgeInsets.only(right: 1),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1),
                ),
              ))
          .toList(),
    );
  }
}
