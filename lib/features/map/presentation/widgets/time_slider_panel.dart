import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/historical_maps_provider.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/core/services/quadrangle_detection_service.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/timeline_map_entry.dart';
import 'package:obsession_tracker/features/subscription/presentation/widgets/paywall_widget.dart';

/// A floating bottom panel for browsing historical maps by year
///
/// Features:
/// - Year-based timeline slider (1850-1960)
/// - Tick marks for available and downloaded maps
/// - Color-coded states (enabled, downloaded, available)
/// - Dynamic updates based on viewport
/// - Smooth time travel animation when sliding
class TimeSliderPanel extends ConsumerStatefulWidget {
  const TimeSliderPanel({
    super.key,
    required this.downloadedMaps,
    required this.availableMaps,
    this.onClose,
    this.onMapSelected,
    this.onDownloadRequested,
    this.onOpacityChanged,
  });

  /// Downloaded historical maps
  final List<HistoricalMapState> downloadedMaps;

  /// Available maps for the current viewport
  final List<QuadrangleSuggestion> availableMaps;

  /// Called when the panel is closed
  final VoidCallback? onClose;

  /// Called when a map is selected (to toggle visibility)
  final void Function(TimelineMapEntry entry)? onMapSelected;

  /// Called when a download is requested for an available map
  final void Function(QuadrangleSuggestion suggestion)? onDownloadRequested;

  /// Called when opacity is changed
  final void Function(double opacity)? onOpacityChanged;

  @override
  ConsumerState<TimeSliderPanel> createState() => _TimeSliderPanelState();
}

/// Represents a cluster of maps at the same year position
class _YearCluster {
  _YearCluster({
    required this.year,
    required this.entries,
  });

  final int year;
  final List<TimelineMapEntry> entries;

  /// Get the highest priority state (enabled > downloaded > available)
  TimelineMapState get displayState {
    if (entries.any((e) => e.state == TimelineMapState.enabledAndVisible)) {
      return TimelineMapState.enabledAndVisible;
    }
    if (entries.any((e) => e.state == TimelineMapState.downloaded)) {
      return TimelineMapState.downloaded;
    }
    return TimelineMapState.available;
  }

  /// Count of maps in this cluster
  int get count => entries.length;

  /// Whether this cluster has multiple maps
  bool get isClustered => entries.length > 1;
}

class _TimeSliderPanelState extends ConsumerState<TimeSliderPanel>
    with SingleTickerProviderStateMixin {
  static const int _minYear = 1850;
  static const int _maxYear = 1970;

  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  double _selectedYear = 1900;
  double _masterOpacity = 0.7;
  bool _isExpanded = false;

  List<TimelineMapEntry> _allEntries = [];
  List<_YearCluster> _clusters = [];
  TimelineMapEntry? _selectedEntry;
  _YearCluster? _selectedCluster;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
    _buildEntries();
    _updateMasterOpacity();
  }

  @override
  void didUpdateWidget(TimeSliderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.downloadedMaps != widget.downloadedMaps ||
        oldWidget.availableMaps != widget.availableMaps) {
      _buildEntries();
    }
  }

  void _buildEntries() {
    final entries = <TimelineMapEntry>[];

    // Add downloaded maps
    for (final map in widget.downloadedMaps) {
      entries.add(TimelineMapEntry.fromHistoricalMapState(map));
    }

    // Add available maps (excluding duplicates)
    final downloadedIds = entries.map((e) => e.id).toSet();
    for (final suggestion in widget.availableMaps) {
      if (!downloadedIds.contains(suggestion.quad.id)) {
        entries.add(TimelineMapEntry.fromQuadrangleSuggestion(suggestion));
      }
    }

    // Sort by year
    entries.sort((a, b) => a.year.compareTo(b.year));

    // Build clusters by grouping entries within ±2 years
    // This prevents overlapping tick marks for close years
    final clusters = <_YearCluster>[];
    final entriesByYear = <int, List<TimelineMapEntry>>{};

    for (final entry in entries) {
      entriesByYear.putIfAbsent(entry.year, () => []).add(entry);
    }

    // Merge years that are too close (within 3 years on a 120-year timeline)
    final sortedYears = entriesByYear.keys.toList()..sort();
    final mergedGroups = <List<int>>[];
    List<int>? currentGroup;

    for (final year in sortedYears) {
      if (currentGroup == null ||
          year - currentGroup.last > 3) {
        // Start a new group
        currentGroup = [year];
        mergedGroups.add(currentGroup);
      } else {
        // Add to current group
        currentGroup.add(year);
      }
    }

    // Create clusters from merged groups
    for (final group in mergedGroups) {
      final clusterEntries = <TimelineMapEntry>[];
      for (final year in group) {
        clusterEntries.addAll(entriesByYear[year]!);
      }
      // Use the middle year for positioning
      final avgYear = (group.first + group.last) ~/ 2;
      clusters.add(_YearCluster(year: avgYear, entries: clusterEntries));
    }

    setState(() {
      _allEntries = entries;
      _clusters = clusters;
      // Select the closest entry to current year
      if (entries.isNotEmpty && _selectedEntry == null) {
        _selectedEntry = _findClosestEntry(_selectedYear.round());
      }
    });
  }

  void _updateMasterOpacity() {
    // Calculate average opacity of enabled maps
    final enabledMaps = widget.downloadedMaps.where((m) => m.isEnabled);
    if (enabledMaps.isNotEmpty) {
      final avgOpacity =
          enabledMaps.map((m) => m.opacity).reduce((a, b) => a + b) /
              enabledMaps.length;
      setState(() => _masterOpacity = avgOpacity);
    }
  }

  TimelineMapEntry? _findClosestEntry(int year) {
    if (_allEntries.isEmpty) return null;

    TimelineMapEntry? closest;
    int minDiff = 1000;

    for (final entry in _allEntries) {
      final diff = (entry.year - year).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = entry;
      }
    }

    return closest;
  }

  String _getEraForYear(int year) {
    if (year < 1890) return 'Survey Era (1850-1890)';
    if (year < 1920) return 'Early Topo (1890-1920)';
    if (year < 1960) return 'Mid-Century (1940-1960)';
    return 'Modern Era';
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleClose() {
    _animationController.reverse().then((_) {
      widget.onClose?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border.all(
            color: Colors.purple.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isDark),
            _buildTimeline(isDark),
            if (_isExpanded) ...[
              const Divider(height: 1),
              _buildExpandedContent(isDark),
            ],
            _buildControls(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final enabledCount =
        widget.downloadedMaps.where((m) => m.isEnabled).length;
    final downloadedCount = widget.downloadedMaps.length;
    final availableCount = widget.availableMaps.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: Colors.purple[400], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Historical Maps Timeline',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.purple[400],
                  ),
                ),
                Text(
                  '$enabledCount/$downloadedCount showing${availableCount > 0 ? ' • $availableCount available' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.purple[400],
            ),
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            tooltip: _isExpanded ? 'Collapse' : 'Expand',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.close,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              size: 20,
            ),
            onPressed: _handleClose,
            tooltip: 'Close',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Era label
          Text(
            _getEraForYear(_selectedYear.round()),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.purple[400],
            ),
          ),
          const SizedBox(height: 8),

          // Year slider with tick marks
          Stack(
            alignment: Alignment.center,
            children: [
              // Tick marks layer
              _buildTickMarks(),

              // Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.purple.withValues(alpha: 0.3),
                  inactiveTrackColor: isDark
                      ? Colors.grey[800]
                      : Colors.grey[300],
                  thumbColor: Colors.purple,
                  overlayColor: Colors.purple.withValues(alpha: 0.2),
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(),
                ),
                child: Slider(
                  value: _selectedYear,
                  min: _minYear.toDouble(),
                  max: _maxYear.toDouble(),
                  divisions: _maxYear - _minYear,
                  label: _selectedYear.round().toString(),
                  onChanged: (value) {
                    setState(() {
                      _selectedYear = value;
                      _selectedEntry = _findClosestEntry(value.round());
                    });
                  },
                ),
              ),
            ],
          ),

          // Year labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_minYear',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
              Text(
                '${_selectedYear.round()}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[400],
                ),
              ),
              Text(
                '$_maxYear',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTickMarks() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - 24; // Account for slider padding
        const yearRange = _maxYear - _minYear;

        return SizedBox(
          height: 30,
          child: Stack(
            clipBehavior: Clip.none,
            children: _clusters.map((cluster) {
              final position =
                  ((cluster.year - _minYear) / yearRange) * width + 12;

              Color color;
              double size;
              switch (cluster.displayState) {
                case TimelineMapState.enabledAndVisible:
                  color = Colors.purple;
                  size = 12;
                case TimelineMapState.downloaded:
                  color = Colors.green;
                  size = 10;
                case TimelineMapState.available:
                  color = Colors.grey;
                  size = 8;
              }

              return Positioned(
                left: position - (cluster.isClustered ? 12 : size / 2),
                top: 15 - size / 2,
                child: GestureDetector(
                  onTap: () => _handleClusterTap(cluster),
                  child: cluster.isClustered
                      ? _buildClusterBadge(cluster, color, size)
                      : Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            color: cluster.displayState ==
                                    TimelineMapState.available
                                ? Colors.transparent
                                : color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color,
                              width: cluster.displayState ==
                                      TimelineMapState.available
                                  ? 2
                                  : 0,
                            ),
                          ),
                        ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildClusterBadge(_YearCluster cluster, Color color, double size) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size - 4,
            height: size - 4,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '${cluster.count}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _handleClusterTap(_YearCluster cluster) {
    setState(() {
      _selectedYear = cluster.year.toDouble();
      _selectedCluster = cluster;
      // Select the first entry in the cluster
      _selectedEntry = cluster.entries.first;
      _isExpanded = true;
    });
  }


  Widget _buildExpandedContent(bool isDark) {
    if (_selectedEntry == null && _selectedCluster == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No maps available for this time period',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    final isPremium = ref.watch(isPremiumProvider);

    // If we have a cluster with multiple entries, show a list
    if (_selectedCluster != null && _selectedCluster!.isClustered) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                '${_selectedCluster!.count} maps around ${_selectedCluster!.year}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple[400],
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _selectedCluster!.entries.length,
                itemBuilder: (context, index) {
                  final entry = _selectedCluster!.entries[index];
                  return _buildCompactEntryTile(entry, isPremium, isDark);
                },
              ),
            ),
          ],
        ),
      );
    }

    // Single entry view
    final entry = _selectedEntry!;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Map icon with state indicator
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getStateColor(entry.state).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStateIcon(entry.state),
              color: _getStateColor(entry.state),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Map details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.year} • ${entry.eraName}${entry.size != null ? ' • ${entry.formattedSize}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Action button
          _buildActionButton(entry, isPremium),
        ],
      ),
    );
  }

  Widget _buildCompactEntryTile(
      TimelineMapEntry entry, bool isPremium, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // State indicator dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: entry.state == TimelineMapState.available
                  ? Colors.transparent
                  : _getStateColor(entry.state),
              shape: BoxShape.circle,
              border: Border.all(
                color: _getStateColor(entry.state),
                width: entry.state == TimelineMapState.available ? 2 : 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Name and year
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${entry.year}${entry.size != null ? ' • ${entry.formattedSize}' : ''}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Compact action button
          _buildCompactActionButton(entry, isPremium),
        ],
      ),
    );
  }

  Widget _buildCompactActionButton(TimelineMapEntry entry, bool isPremium) {
    if (entry.isDownloaded) {
      return IconButton(
        icon: Icon(
          entry.isEnabled ? Icons.visibility : Icons.visibility_off,
          size: 18,
          color: entry.isEnabled ? Colors.purple : Colors.grey,
        ),
        onPressed: () => widget.onMapSelected?.call(entry),
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(4),
      );
    } else {
      return IconButton(
        icon: Icon(
          isPremium ? Icons.download : Icons.lock,
          size: 18,
          color: Colors.purple,
        ),
        onPressed: () {
          if (isPremium) {
            if (entry.quadrangleSuggestion != null) {
              widget.onDownloadRequested?.call(entry.quadrangleSuggestion!);
            }
          } else {
            showPaywall(context, title: 'Unlock Historical Maps');
          }
        },
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(4),
      );
    }
  }

  Color _getStateColor(TimelineMapState state) {
    switch (state) {
      case TimelineMapState.enabledAndVisible:
        return Colors.purple;
      case TimelineMapState.downloaded:
        return Colors.green;
      case TimelineMapState.available:
        return Colors.grey;
    }
  }

  IconData _getStateIcon(TimelineMapState state) {
    switch (state) {
      case TimelineMapState.enabledAndVisible:
        return Icons.visibility;
      case TimelineMapState.downloaded:
        return Icons.check_circle;
      case TimelineMapState.available:
        return Icons.download;
    }
  }

  Widget _buildActionButton(TimelineMapEntry entry, bool isPremium) {
    if (entry.isDownloaded) {
      // Toggle visibility button
      return ElevatedButton.icon(
        onPressed: () => widget.onMapSelected?.call(entry),
        icon: Icon(
          entry.isEnabled ? Icons.visibility_off : Icons.visibility,
          size: 16,
        ),
        label: Text(
          entry.isEnabled ? 'Hide' : 'Show',
          style: const TextStyle(fontSize: 12),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              entry.isEnabled ? Colors.grey[600] : Colors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
    } else {
      // Download button
      return ElevatedButton.icon(
        onPressed: () {
          if (isPremium) {
            if (entry.quadrangleSuggestion != null) {
              widget.onDownloadRequested?.call(entry.quadrangleSuggestion!);
            }
          } else {
            showPaywall(context, title: 'Unlock Historical Maps');
          }
        },
        icon: Icon(
          isPremium ? Icons.download : Icons.lock,
          size: 16,
        ),
        label: Text(
          isPremium ? 'Download' : 'Premium',
          style: const TextStyle(fontSize: 12),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
    }
  }

  Widget _buildControls(bool isDark) {
    final enabledCount =
        widget.downloadedMaps.where((m) => m.isEnabled).length;

    if (enabledCount == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.opacity,
            size: 16,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Text(
            'Opacity',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Expanded(
            child: Slider(
              value: _masterOpacity,
              min: 0.1,
              divisions: 9,
              activeColor: Colors.purple,
              onChanged: (value) {
                setState(() => _masterOpacity = value);
                widget.onOpacityChanged?.call(value);
              },
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${(_masterOpacity * 100).round()}%',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
