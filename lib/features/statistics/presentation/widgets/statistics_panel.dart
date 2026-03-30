import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/session_statistics.dart';
import 'package:obsession_tracker/core/providers/statistics_provider.dart';

/// Widget for displaying real-time session statistics
///
/// Shows comprehensive tracking metrics in a clean, configurable layout
/// with support for different unit systems and metric visibility options.
class StatisticsPanel extends StatefulWidget {
  const StatisticsPanel({
    super.key,
    this.compact = false,
    this.showConfiguration = true,
    this.statisticsProvider,
  });

  /// Whether to show compact layout
  final bool compact;

  /// Whether to show configuration options
  final bool showConfiguration;

  /// Statistics provider instance
  final StatisticsProvider? statisticsProvider;

  @override
  State<StatisticsPanel> createState() => _StatisticsPanelState();
}

class _StatisticsPanelState extends State<StatisticsPanel> {
  bool _isExpanded = true;
  StatisticsProvider? _provider;

  @override
  void initState() {
    super.initState();
    _provider = widget.statisticsProvider ?? StatisticsProvider();
    _provider?.addListener(_onProviderUpdate);
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderUpdate);
    if (widget.statisticsProvider == null) {
      _provider?.dispose();
    }
    super.dispose();
  }

  void _onProviderUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_provider == null) {
      return _buildNotTrackingCard();
    }

    if (!_provider!.isTracking) {
      return _buildNotTrackingCard();
    }

    if (_provider!.error != null) {
      return _buildErrorCard(_provider!.error!);
    }

    return _buildStatisticsCard(_provider!);
  }

  Widget _buildNotTrackingCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.analytics_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'Statistics',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Start tracking to see real-time statistics',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _buildErrorCard(String error) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 8),
              Text(
                'Statistics Error',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                error,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _buildStatisticsCard(StatisticsProvider provider) => Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildHeader(provider),
            if (_isExpanded) ...<Widget>[
              const Divider(height: 1),
              _buildStatisticsContent(provider),
            ],
          ],
        ),
      );

  Widget _buildHeader(StatisticsProvider provider) => ListTile(
        leading: Icon(
          Icons.analytics,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Statistics'),
        subtitle: provider.currentStatistics != null
            ? Text(
                'Updated ${_formatTimestamp(provider.currentStatistics!.timestamp)}')
            : const Text('Calculating...'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.showConfiguration)
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _showConfigurationDialog(provider),
                tooltip: 'Configure statistics',
              ),
            IconButton(
              icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
              tooltip: _isExpanded ? 'Collapse' : 'Expand',
            ),
          ],
        ),
      );

  Widget _buildStatisticsContent(StatisticsProvider provider) {
    if (provider.currentStatistics == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: widget.compact
          ? _buildCompactLayout(provider)
          : _buildFullLayout(provider),
    );
  }

  Widget _buildCompactLayout(StatisticsProvider provider) => Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                  child: _buildMetricCard('Distance',
                      provider.formattedDistance, Icons.straighten)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildMetricCard('Duration',
                      provider.formattedTotalDuration, Icons.timer)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                  child: _buildMetricCard(
                      'Speed', provider.formattedCurrentSpeed, Icons.speed)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildMetricCard('Altitude',
                      provider.formattedCurrentAltitude, Icons.terrain)),
            ],
          ),
        ],
      );

  Widget _buildFullLayout(StatisticsProvider provider) {
    final List<Widget> sections = <Widget>[];

    if (provider.isMetricVisible('distance')) {
      sections.add(_buildDistanceSection(provider));
    }
    if (provider.isMetricVisible('duration')) {
      sections.add(_buildTimeSection(provider));
    }
    if (provider.isMetricVisible('speed')) {
      sections.add(_buildSpeedSection(provider));
    }
    if (provider.isMetricVisible('altitude')) {
      sections.add(_buildAltitudeSection(provider));
    }
    if (provider.isMetricVisible('waypoints')) {
      sections.add(_buildWaypointSection(provider));
    }
    sections.add(_buildAccuracySection(provider));

    return Column(children: sections);
  }

  Widget _buildDistanceSection(StatisticsProvider provider) => _buildSection(
        'Distance',
        Icons.straighten,
        <Widget>[
          _buildStatRow('Total Distance', provider.formattedDistance),
        ],
      );

  Widget _buildTimeSection(StatisticsProvider provider) => _buildSection(
        'Time',
        Icons.timer,
        <Widget>[
          _buildStatRow('Total Time', provider.formattedTotalDuration),
          _buildStatRow('Moving Time', provider.formattedMovingDuration),
        ],
      );

  Widget _buildSpeedSection(StatisticsProvider provider) => _buildSection(
        'Speed',
        Icons.speed,
        <Widget>[
          _buildStatRow('Current Speed', provider.formattedCurrentSpeed),
          _buildStatRow('Average Speed', provider.formattedAverageSpeed),
          _buildStatRow('Moving Average', provider.formattedMovingAverageSpeed),
          _buildStatRow('Max Speed', provider.formattedMaxSpeed),
        ],
      );

  Widget _buildAltitudeSection(StatisticsProvider provider) {
    if (provider.currentStatistics?.hasAltitudeData != true) {
      return const SizedBox.shrink();
    }

    return _buildSection(
      'Elevation',
      Icons.terrain,
      <Widget>[
        _buildStatRow('Current Altitude', provider.formattedCurrentAltitude),
        _buildStatRow('Elevation Gain', provider.formattedElevationGain),
        _buildStatRow('Elevation Loss', provider.formattedElevationLoss),
        _buildStatRow('Net Change', provider.formattedNetElevationChange),
      ],
    );
  }

  Widget _buildWaypointSection(StatisticsProvider provider) => _buildSection(
        'Waypoints',
        Icons.place,
        <Widget>[
          _buildStatRow('Total Waypoints', provider.waypointCount.toString()),
          _buildStatRow('Density', provider.formattedWaypointDensity),
        ],
      );

  Widget _buildAccuracySection(StatisticsProvider provider) => _buildSection(
        'GPS Accuracy',
        Icons.gps_fixed,
        <Widget>[
          _buildStatRow('Current Accuracy', provider.formattedAccuracy),
          _buildStatRow('Good Readings', provider.formattedAccuracyPercentage),
        ],
      );

  Widget _buildSection(String title, IconData icon, List<Widget> children) =>
      Column(
        children: <Widget>[
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Icon(icon,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      );

  Widget _buildStatRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      );

  Widget _buildMetricCard(String label, String value, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  void _showConfigurationDialog(StatisticsProvider provider) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          _StatisticsConfigDialog(provider: provider),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }
}

class _StatisticsConfigDialog extends StatefulWidget {
  const _StatisticsConfigDialog({required this.provider});

  final StatisticsProvider provider;

  @override
  State<_StatisticsConfigDialog> createState() =>
      _StatisticsConfigDialogState();
}

class _StatisticsConfigDialogState extends State<_StatisticsConfigDialog> {
  late UnitSystem _selectedUnits;
  late Set<String> _visibleMetrics;

  @override
  void initState() {
    super.initState();
    _selectedUnits = widget.provider.unitSystem;
    _visibleMetrics = Set<String>.from(widget.provider.visibleMetrics);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Statistics Configuration'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Unit System',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Metric (km, m, km/h)'),
                leading: Icon(
                  _selectedUnits == UnitSystem.metric
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                onTap: () {
                  setState(() => _selectedUnits = UnitSystem.metric);
                },
              ),
              ListTile(
                title: const Text('Imperial (mi, ft, mph)'),
                leading: Icon(
                  _selectedUnits == UnitSystem.imperial
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                onTap: () {
                  setState(() => _selectedUnits = UnitSystem.imperial);
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Visible Metrics',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ..._buildMetricCheckboxes(),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saveConfiguration,
            child: const Text('Save'),
          ),
        ],
      );

  List<Widget> _buildMetricCheckboxes() {
    final List<MapEntry<String, String>> metrics = <MapEntry<String, String>>[
      const MapEntry<String, String>('distance', 'Distance'),
      const MapEntry<String, String>('duration', 'Time'),
      const MapEntry<String, String>('speed', 'Speed'),
      const MapEntry<String, String>('altitude', 'Elevation'),
      const MapEntry<String, String>('waypoints', 'Waypoints'),
    ];

    return metrics
        .map((MapEntry<String, String> metric) => CheckboxListTile(
              title: Text(metric.value),
              value: _visibleMetrics.contains(metric.key),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _visibleMetrics.add(metric.key);
                  } else {
                    _visibleMetrics.remove(metric.key);
                  }
                });
              },
            ))
        .toList();
  }

  void _saveConfiguration() {
    widget.provider.setUnitSystem(_selectedUnits);

    // Update metric visibility
    for (final String metric in <String>[
      'distance',
      'duration',
      'speed',
      'altitude',
      'waypoints'
    ]) {
      widget.provider.setMetricVisibility(metric,
          visible: _visibleMetrics.contains(metric));
    }

    Navigator.of(context).pop();
  }
}
