import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/services/desktop_service.dart';
import 'package:obsession_tracker/core/services/internationalization_service.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:obsession_tracker/core/widgets/desktop_multi_panel_layout.dart';

/// Session comparison widget optimized for desktop large screens
class SessionComparisonWidget extends ConsumerStatefulWidget {
  const SessionComparisonWidget({
    required this.sessions,
    super.key,
    this.maxComparisons = 4,
  });

  final List<SessionData> sessions;
  final int maxComparisons;

  @override
  ConsumerState<SessionComparisonWidget> createState() =>
      _SessionComparisonWidgetState();
}

class _SessionComparisonWidgetState
    extends ConsumerState<SessionComparisonWidget> {
  final List<SessionData> _selectedSessions = <SessionData>[];
  ComparisonView _currentView = ComparisonView.overview;
  bool _showStatistics = true;
  bool _showMaps = true;
  bool _showTimeline = true;

  @override
  Widget build(BuildContext context) {
    if (!DesktopService.isDesktop || !context.isDesktop) {
      return _buildMobileLayout();
    }

    return DesktopMultiPanelLayout(
      leftPanel: _buildSessionSelector(),
      centerPanel: _buildComparisonContent(),
      rightPanel: _buildComparisonControls(),
      bottomPanel: _showTimeline ? _buildTimelineComparison() : null,
      showRightPanel: true,
      showBottomPanel: _showTimeline,
      rightPanelWidth: 250,
    );
  }

  Widget _buildMobileLayout() => Scaffold(
        appBar: AppBar(
          title: const Text('Session Comparison'),
          actions: [
            IconButton(
              onPressed: _showComparisonSettings,
              icon: const Icon(Icons.settings),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildSessionSelectorCompact(),
            Expanded(child: _buildComparisonContent()),
          ],
        ),
      );

  Widget _buildSessionSelector() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Sessions to Compare',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose up to ${widget.maxComparisons} sessions',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.sessions.length,
              itemBuilder: (context, index) {
                final session = widget.sessions[index];
                final isSelected = _selectedSessions.contains(session);
                final canSelect =
                    _selectedSessions.length < widget.maxComparisons;

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: canSelect || isSelected
                      ? (value) => _toggleSessionSelection(session)
                      : null,
                  title: Text(session.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatDate(session.createdAt)),
                      Text(
                        '${session.waypoints.length} waypoints • ${_formatDistance(session.totalDistance)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _getSessionColor(session)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.route,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );

  Widget _buildSessionSelectorCompact() => Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected Sessions (${_selectedSessions.length}/${widget.maxComparisons})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.maxComparisons,
                itemBuilder: (context, index) {
                  if (index < _selectedSessions.length) {
                    final session = _selectedSessions[index];
                    return _buildSessionChip(session, true);
                  } else {
                    return _buildEmptySessionSlot(index);
                  }
                },
              ),
            ),
          ],
        ),
      );

  Widget _buildSessionChip(SessionData session, bool isSelected) => Container(
        width: 120,
        margin: const EdgeInsets.only(right: 8),
        child: Card(
          color: isSelected ? _getSessionColor(session) : null,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.route,
                  color: isSelected ? Colors.white : null,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  session.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : null,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildEmptySessionSlot(int index) => Container(
        width: 120,
        margin: const EdgeInsets.only(right: 8),
        child: Card(
          child: InkWell(
            onTap: _showSessionPicker,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 20),
                  SizedBox(height: 4),
                  Text(
                    'Add Session',
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildComparisonContent() {
    if (_selectedSessions.isEmpty) {
      return _buildEmptyState();
    }

    switch (_currentView) {
      case ComparisonView.overview:
        return _buildOverviewComparison();
      case ComparisonView.maps:
        return _buildMapsComparison();
      case ComparisonView.statistics:
        return _buildStatisticsComparison();
      case ComparisonView.timeline:
        return _buildTimelineComparison();
    }
  }

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.compare_arrows,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Select sessions to compare',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose up to ${widget.maxComparisons} sessions from the left panel to start comparing',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildOverviewComparison() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildComparisonHeader(),
            const SizedBox(height: 24),
            if (_showStatistics) ...[
              _buildQuickStatsComparison(),
              const SizedBox(height: 24),
            ],
            if (_showMaps) ...[
              _buildMapsPreview(),
              const SizedBox(height: 24),
            ],
            _buildDetailedComparison(),
          ],
        ),
      );

  Widget _buildComparisonHeader() => Row(
        children: [
          Icon(
            Icons.compare_arrows,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session Comparison',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Comparing ${_selectedSessions.length} sessions',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          _buildViewSelector(),
        ],
      );

  Widget _buildViewSelector() => SegmentedButton<ComparisonView>(
        segments: const [
          ButtonSegment(
            value: ComparisonView.overview,
            label: Text('Overview'),
            icon: Icon(Icons.dashboard),
          ),
          ButtonSegment(
            value: ComparisonView.maps,
            label: Text('Maps'),
            icon: Icon(Icons.map),
          ),
          ButtonSegment(
            value: ComparisonView.statistics,
            label: Text('Stats'),
            icon: Icon(Icons.analytics),
          ),
        ],
        selected: {_currentView},
        onSelectionChanged: (Set<ComparisonView> selection) {
          setState(() {
            _currentView = selection.first;
          });
        },
      );

  Widget _buildQuickStatsComparison() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Statistics',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(),
                  2: FlexColumnWidth(),
                  3: FlexColumnWidth(),
                  4: FlexColumnWidth(),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    children: [
                      _buildTableHeader('Metric'),
                      ..._selectedSessions
                          .map((session) => _buildTableHeader(session.name)),
                    ],
                  ),
                  _buildStatRow(
                      'Distance',
                      _selectedSessions
                          .map((s) => _formatDistance(s.totalDistance))
                          .toList()),
                  _buildStatRow(
                      'Duration',
                      _selectedSessions
                          .map((s) => _formatDuration(s.duration))
                          .toList()),
                  _buildStatRow(
                      'Waypoints',
                      _selectedSessions
                          .map((s) => s.waypoints.length.toString())
                          .toList()),
                  _buildStatRow(
                      'Avg Speed',
                      _selectedSessions
                          .map((s) => _formatSpeed(s.averageSpeed))
                          .toList()),
                  _buildStatRow(
                      'Max Elevation',
                      _selectedSessions
                          .map((s) => _formatElevation(s.maxElevation))
                          .toList()),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildTableHeader(String text) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );

  TableRow _buildStatRow(String metric, List<String> values) => TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              metric,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          ...values.map((value) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text(value),
              )),
        ],
      );

  Widget _buildMapsPreview() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Route Comparison',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                      'Interactive map comparison would be implemented here'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildMapsComparison() => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildComparisonHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('Full-screen interactive map comparison'),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildStatisticsComparison() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildComparisonHeader(),
            const SizedBox(height: 24),
            _buildDetailedStatistics(),
          ],
        ),
      );

  Widget _buildDetailedStatistics() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detailed Statistics',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              // Placeholder for detailed statistics charts and graphs
              Container(
                height: 400,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                      'Detailed statistics charts would be implemented here'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildTimelineComparison() => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Timeline Comparison',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('Timeline comparison would be implemented here'),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildDetailedComparison() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detailed Comparison',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ..._selectedSessions.map(_buildSessionDetailCard),
            ],
          ),
        ),
      );

  Widget _buildSessionDetailCard(SessionData session) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getSessionColor(session),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.route, color: Colors.white),
          ),
          title: Text(session.name),
          subtitle: Text(_formatDate(session.createdAt)),
          trailing: PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'details',
                child: Text('View Details'),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Text('Export'),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: Text('Remove from Comparison'),
              ),
            ],
            onSelected: (value) =>
                _handleSessionAction(session, value.toString()),
          ),
        ),
      );

  Widget _buildComparisonControls() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comparison Options',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Show Statistics'),
                  value: _showStatistics,
                  onChanged: (value) {
                    setState(() {
                      _showStatistics = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Show Maps'),
                  value: _showMaps,
                  onChanged: (value) {
                    setState(() {
                      _showMaps = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Show Timeline'),
                  value: _showTimeline,
                  onChanged: (value) {
                    setState(() {
                      _showTimeline = value;
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: _exportComparison,
                  icon: const Icon(Icons.download),
                  label: const Text('Export Comparison'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _clearSelection,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Selection'),
                ),
              ],
            ),
          ),
        ],
      );

  // Helper methods
  void _toggleSessionSelection(SessionData session) {
    setState(() {
      if (_selectedSessions.contains(session)) {
        _selectedSessions.remove(session);
      } else if (_selectedSessions.length < widget.maxComparisons) {
        _selectedSessions.add(session);
      }
    });
  }

  Color _getSessionColor(SessionData session) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];
    final index = _selectedSessions.indexOf(session);
    return colors[index % colors.length];
  }

  void _showSessionPicker() {
    // Implementation for showing session picker dialog
  }

  void _showComparisonSettings() {
    // Implementation for showing comparison settings
  }

  void _handleSessionAction(SessionData session, String action) {
    switch (action) {
      case 'details':
        // Show session details
        break;
      case 'export':
        // Export session
        break;
      case 'remove':
        _toggleSessionSelection(session);
        break;
    }
  }

  void _exportComparison() {
    // Implementation for exporting comparison
  }

  void _clearSelection() {
    setState(_selectedSessions.clear);
  }

  // Formatting methods
  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  String _formatDistance(double distance) =>
      InternationalizationService().formatDistance(distance);

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  String _formatSpeed(double speed) => '${speed.toStringAsFixed(1)} km/h';

  String _formatElevation(double elevation) =>
      '${elevation.toStringAsFixed(0)} m';
}

enum ComparisonView {
  overview,
  maps,
  statistics,
  timeline,
}

// Placeholder data class
class SessionData {
  const SessionData({
    required this.id,
    required this.name,
    required this.createdAt,
    this.waypoints = const [],
    this.totalDistance = 0.0,
    this.duration = Duration.zero,
    this.averageSpeed = 0.0,
    this.maxElevation = 0.0,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final List<dynamic> waypoints;
  final double totalDistance;
  final Duration duration;
  final double averageSpeed;
  final double maxElevation;
}
