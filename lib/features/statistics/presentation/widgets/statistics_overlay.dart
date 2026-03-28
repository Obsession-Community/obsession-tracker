import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/providers/statistics_provider.dart';

/// Compact statistics overlay for map display
///
/// Shows essential statistics in a minimal overlay that doesn't
/// obstruct the map view while providing key tracking information.
class StatisticsOverlay extends StatefulWidget {
  const StatisticsOverlay({
    required this.statisticsProvider,
    super.key,
    this.position = StatisticsOverlayPosition.topRight,
    this.showBackground = true,
  });

  /// Statistics provider instance
  final StatisticsProvider statisticsProvider;

  /// Position of the overlay on screen
  final StatisticsOverlayPosition position;

  /// Whether to show background
  final bool showBackground;

  @override
  State<StatisticsOverlay> createState() => _StatisticsOverlayState();
}

enum StatisticsOverlayPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class _StatisticsOverlayState extends State<StatisticsOverlay> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    widget.statisticsProvider.addListener(_onProviderUpdate);
  }

  @override
  void dispose() {
    widget.statisticsProvider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _onProviderUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.statisticsProvider.isTracking) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: _getTop(),
      left: _getLeft(),
      right: _getRight(),
      bottom: _getBottom(),
      child: SafeArea(
        child: _buildOverlay(),
      ),
    );
  }

  double? _getTop() {
    switch (widget.position) {
      case StatisticsOverlayPosition.topLeft:
      case StatisticsOverlayPosition.topRight:
        return 16.0;
      case StatisticsOverlayPosition.bottomLeft:
      case StatisticsOverlayPosition.bottomRight:
        return null;
    }
  }

  double? _getLeft() {
    switch (widget.position) {
      case StatisticsOverlayPosition.topLeft:
      case StatisticsOverlayPosition.bottomLeft:
        return 16.0;
      case StatisticsOverlayPosition.topRight:
      case StatisticsOverlayPosition.bottomRight:
        return null;
    }
  }

  double? _getRight() {
    switch (widget.position) {
      case StatisticsOverlayPosition.topLeft:
      case StatisticsOverlayPosition.bottomLeft:
        return null;
      case StatisticsOverlayPosition.topRight:
      case StatisticsOverlayPosition.bottomRight:
        return 16.0;
    }
  }

  double? _getBottom() {
    switch (widget.position) {
      case StatisticsOverlayPosition.topLeft:
      case StatisticsOverlayPosition.topRight:
        return null;
      case StatisticsOverlayPosition.bottomLeft:
      case StatisticsOverlayPosition.bottomRight:
        return 16.0;
    }
  }

  Widget _buildOverlay() => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _isExpanded ? 280 : 120,
        decoration: widget.showBackground
            ? BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              )
            : null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: _isExpanded
                  ? _buildExpandedContent()
                  : _buildCompactContent(),
            ),
          ),
        ),
      );

  Widget _buildCompactContent() {
    final StatisticsProvider provider = widget.statisticsProvider;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.analytics,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'Stats',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCompactStat(Icons.straighten, provider.formattedDistance),
        const SizedBox(height: 4),
        _buildCompactStat(Icons.timer, provider.formattedTotalDuration),
        const SizedBox(height: 4),
        _buildCompactStat(Icons.speed, provider.formattedCurrentSpeed),
        if (provider.currentStatistics?.hasAltitudeData == true) ...<Widget>[
          const SizedBox(height: 4),
          _buildCompactStat(Icons.terrain, provider.formattedCurrentAltitude),
        ],
      ],
    );
  }

  Widget _buildExpandedContent() {
    final StatisticsProvider provider = widget.statisticsProvider;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.analytics,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Statistics',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            Icon(
              Icons.compress,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildExpandedStat(
            'Distance', provider.formattedDistance, Icons.straighten),
        const SizedBox(height: 8),
        _buildExpandedStat(
            'Duration', provider.formattedTotalDuration, Icons.timer),
        const SizedBox(height: 8),
        _buildExpandedStat(
            'Current Speed', provider.formattedCurrentSpeed, Icons.speed),
        const SizedBox(height: 8),
        _buildExpandedStat(
            'Average Speed', provider.formattedAverageSpeed, Icons.trending_up),
        if (provider.currentStatistics?.hasAltitudeData == true) ...<Widget>[
          const SizedBox(height: 8),
          _buildExpandedStat(
              'Altitude', provider.formattedCurrentAltitude, Icons.terrain),
          const SizedBox(height: 8),
          _buildExpandedStat('Elevation Gain', provider.formattedElevationGain,
              Icons.arrow_upward),
        ],
        if (provider.waypointCount > 0) ...<Widget>[
          const SizedBox(height: 8),
          _buildExpandedStat(
              'Waypoints', provider.waypointCount.toString(), Icons.place),
        ],
      ],
    );
  }

  Widget _buildCompactStat(IconData icon, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

  Widget _buildExpandedStat(String label, String value, IconData icon) => Row(
        children: <Widget>[
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      );
}

/// Floating action button for statistics
///
/// Provides quick access to statistics panel with a floating button
/// that shows current key metrics and opens full statistics on tap.
class StatisticsFAB extends StatefulWidget {
  const StatisticsFAB({
    required this.statisticsProvider,
    required this.onPressed,
    super.key,
  });

  /// Statistics provider instance
  final StatisticsProvider statisticsProvider;

  /// Callback when FAB is pressed
  final VoidCallback onPressed;

  @override
  State<StatisticsFAB> createState() => _StatisticsFABState();
}

class _StatisticsFABState extends State<StatisticsFAB> {
  @override
  void initState() {
    super.initState();
    widget.statisticsProvider.addListener(_onProviderUpdate);
  }

  @override
  void dispose() {
    widget.statisticsProvider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _onProviderUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.statisticsProvider.isTracking) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton.extended(
      onPressed: widget.onPressed,
      icon: const Icon(Icons.analytics),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.statisticsProvider.formattedDistance,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            widget.statisticsProvider.formattedTotalDuration,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
    );
  }
}
