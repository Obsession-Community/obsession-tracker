import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:obsession_tracker/core/models/cell_tower.dart';
import 'package:obsession_tracker/core/models/custom_marker.dart';
import 'package:obsession_tracker/core/models/historical_place.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/models/trail.dart';
import 'package:obsession_tracker/core/providers/cell_coverage_provider.dart';
import 'package:obsession_tracker/core/providers/custom_markers_provider.dart';
import 'package:obsession_tracker/core/providers/historical_maps_provider.dart';
import 'package:obsession_tracker/core/providers/historical_places_provider.dart';
import 'package:obsession_tracker/core/providers/land_ownership_provider.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/core/providers/trails_provider.dart';
import 'package:obsession_tracker/core/services/quadrangle_detection_service.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/features/subscription/presentation/widgets/paywall_widget.dart';

/// Panel for filtering land ownership overlays
class LandFilterPanel extends ConsumerStatefulWidget {
  const LandFilterPanel({
    super.key,
    this.onFilterChanged,
    this.onClose,
    this.sessionId,
    this.onHistoricalMapToggled,
    this.onHistoricalMapOpacityChanged,
    this.availableMaps = const [],
    this.onDownloadAvailableMap,
    this.onOpenTimeline,
  });

  final void Function(LandOwnershipFilter)? onFilterChanged;
  final VoidCallback? onClose;

  /// If set, enables session-specific marker filtering option
  final String? sessionId;

  /// Callback when a historical map is toggled on/off
  final void Function(HistoricalMapState mapState, bool enabled)? onHistoricalMapToggled;

  /// Callback when historical map opacity is changed
  final void Function(HistoricalMapState mapState, double opacity)? onHistoricalMapOpacityChanged;

  /// Available historical maps for the current viewport (not yet downloaded)
  final List<QuadrangleSuggestion> availableMaps;

  /// Callback when user requests to download an available map
  final void Function(QuadrangleSuggestion suggestion)? onDownloadAvailableMap;

  /// Callback when user wants to open the timeline view for historical maps
  final VoidCallback? onOpenTimeline;

  @override
  ConsumerState<LandFilterPanel> createState() => _LandFilterPanelState();
}

class _LandFilterPanelState extends ConsumerState<LandFilterPanel> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(landOwnershipFilterProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(theme),
          if (isPremium)
            _buildFilterContent(theme, filter)
          else
            _buildPremiumUpsell(context),
        ],
      ),
    );
  }

  Widget _buildPremiumUpsell(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Premium icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: AppTheme.gold,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Premium Feature',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.gold,
                ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            'Unlock land ownership data, trail overlays, and activity permissions to hunt with confidence.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? AppTheme.textOnDarkMuted : AppTheme.textOnLightMuted,
                ),
          ),
          const SizedBox(height: 16),

          // Feature list
          _buildFeatureItem(context, Icons.map, 'Federal, State & Private Land Data'),
          _buildFeatureItem(context, Icons.hiking, 'Official & Community Trail Maps'),
          _buildFeatureItem(context, Icons.gavel, 'Activity Permission Status'),
          _buildFeatureItem(context, Icons.notifications_active, 'Real-Time Boundary Alerts'),

          const SizedBox(height: 20),

          // Upgrade button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await showPaywall(context, title: 'Unlock Map Data');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.darkBackground,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Start Free Trial',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: AppTheme.gold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? AppTheme.textOnDark : AppTheme.textOnLight,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.filter_list,
              color: AppTheme.gold,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Text(
              'Map Layers',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.gold,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                Icons.close,
                size: 18,
                color: theme.brightness == Brightness.dark
                    ? AppTheme.textOnDarkMuted
                    : AppTheme.textOnLightMuted,
              ),
              onPressed: widget.onClose,
              tooltip: 'Close filters',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );

  Widget _buildFilterContent(ThemeData theme, LandOwnershipFilter filter) =>
      ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6, // Max 60% of screen height
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Master layer controls at the top
              _buildMasterLayerControls(),

              const Divider(height: 20),

              // Historical maps overlay section (MBTiles raster maps) - Purple themed, featured
              _buildHistoricalMapsAccordion(),

              // Land ownership accordion
              _buildLandOwnershipAccordion(filter),

              // Trails accordion
              _buildTrailsAccordion(),

              // Historical places accordion
              _buildHistoricalPlacesAccordion(),

              // Cell coverage accordion (premium feature)
              _buildCellCoverageAccordion(),

              // Custom markers accordion
              _buildCustomMarkersAccordion(),

              // Session markers section (only in session context)
              if (widget.sessionId != null) _buildSessionMarkersAccordion(),
            ],
          ),
        ),
      );

  /// Accordion wrapper for Historical Maps section
  Widget _buildHistoricalMapsAccordion() {
    final historicalMapsState = ref.watch(historicalMapsProvider);
    final downloadedMaps = historicalMapsState.maps.values.toList();
    final availableMaps = widget.availableMaps;
    final enabledCount = downloadedMaps.where((m) => m.isEnabled).length;

    // Don't show section if no historical maps are downloaded AND none available
    if (downloadedMaps.isEmpty && availableMaps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Icon(Icons.history, size: 20, color: Colors.purple[400]),
        title: Text(
          'Historical Maps',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.purple[400],
          ),
        ),
        subtitle: Text(
          downloadedMaps.isEmpty
              ? '${availableMaps.length} available nearby'
              : '$enabledCount/${downloadedMaps.length} showing${availableMaps.isNotEmpty ? ' • ${availableMaps.length} available' : ''}',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (downloadedMaps.isNotEmpty)
              Switch(
                value: enabledCount > 0,
                activeTrackColor: Colors.purple,
                onChanged: (value) {
                  if (value) {
                    ref.read(historicalMapsProvider.notifier).enableAll();
                  } else {
                    ref.read(historicalMapsProvider.notifier).disableAll();
                  }
                },
              ),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
        children: [
          _buildHistoricalMapsContent(downloadedMaps, availableMaps),
        ],
      ),
    );
  }

  /// Content for Historical Maps accordion
  Widget _buildHistoricalMapsContent(
    List<HistoricalMapState> downloadedMaps,
    List<QuadrangleSuggestion> availableMaps,
  ) {
    // Group maps by era
    final mapsByEra = <String, List<HistoricalMapState>>{};
    for (final map in downloadedMaps) {
      final eraId = map.era ?? 'unknown';
      mapsByEra.putIfAbsent(eraId, () => []).add(map);
    }

    // Sort eras chronologically
    final sortedEras = mapsByEra.keys.toList()
      ..sort((a, b) => _getEraOrder(a).compareTo(_getEraOrder(b)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Open Timeline button
        if (downloadedMaps.isNotEmpty || availableMaps.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onOpenTimeline,
                icon: const Icon(Icons.timeline, size: 16),
                label: const Text(
                  'Open Timeline View',
                  style: TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple,
                  side: BorderSide(color: Colors.purple.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

        // Era-grouped downloaded maps
        if (downloadedMaps.isNotEmpty) ...[
          ...sortedEras.map((eraId) =>
              _buildEraSection(eraId, mapsByEra[eraId]!)),
        ],

        // Available maps section (not yet downloaded) - limit to 3
        if (availableMaps.isNotEmpty) ...[
          if (downloadedMaps.isNotEmpty) const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.download, size: 14, color: Colors.purple[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Available for This Area (${availableMaps.length})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Limit to 3 available maps to prevent scrolling
                ...availableMaps.take(3).map(_buildAvailableMapTile),
                if (availableMaps.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${availableMaps.length - 3} more in Timeline View',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Colors.purple[400],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Get order for era sorting (earlier eras first)
  /// Handles both quadrangle era IDs (survey, early_topo) and
  /// legacy layer IDs (maps_survey, maps_early_topo)
  int _getEraOrder(String eraId) {
    switch (eraId) {
      case 'survey':
      case 'maps_survey':
        return 0;
      case 'early_topo':
      case 'maps_early_topo':
        return 1;
      case 'midcentury':
        return 2;
      default:
        return 3;
    }
  }

  /// Get display info for an era
  /// Handles both quadrangle era IDs (survey, early_topo) and
  /// legacy layer IDs (maps_survey, maps_early_topo)
  ({String name, String yearRange}) _getEraInfo(String eraId) {
    switch (eraId) {
      case 'survey':
      case 'maps_survey':
        return (name: 'Survey Era', yearRange: '1850-1890');
      case 'early_topo':
      case 'maps_early_topo':
        return (name: 'Early Topo', yearRange: '1890-1920');
      case 'midcentury':
        return (name: 'Mid-Century', yearRange: '1940-1960');
      default:
        return (name: 'Historical', yearRange: '');
    }
  }

  /// Build a collapsible section for maps in an era
  Widget _buildEraSection(String eraId, List<HistoricalMapState> maps) {
    final eraInfo = _getEraInfo(eraId);
    final enabledCount = maps.where((m) => m.isEnabled).length;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: EdgeInsets.zero,
        dense: true,
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: enabledCount > 0 ? Colors.purple : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          '${eraInfo.name} (${eraInfo.yearRange})',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '$enabledCount/${maps.length} showing',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Era toggle switch
            Transform.scale(
              scale: 0.7,
              child: Switch(
                value: enabledCount > 0,
                activeTrackColor: Colors.purple,
                onChanged: (value) {
                  ref.read(historicalMapsProvider.notifier).toggleEra(eraId, value);
                },
              ),
            ),
            const Icon(Icons.expand_more, size: 16),
          ],
        ),
        children: [
          // Show maps in a compact list (virtualized if many)
          if (maps.length <= 5)
            ...maps.map(_buildCompactHistoricalMapTile)
          else
            SizedBox(
              height: 150,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: maps.length,
                itemBuilder: (context, index) =>
                    _buildCompactHistoricalMapTile(maps[index]),
              ),
            ),
        ],
      ),
    );
  }

  /// Compact tile for historical map in era section
  Widget _buildCompactHistoricalMapTile(HistoricalMapState mapState) {
    // Extract quad name from layer name
    final name = mapState.layerName.replaceAll(RegExp(r'\s*\(\d{4}\)'), '');
    final yearMatch = RegExp(r'\((\d{4})\)').firstMatch(mapState.layerName);
    final year = yearMatch?.group(1) ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          // State indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: mapState.isEnabled ? Colors.purple : Colors.grey[400],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          // Name and year
          Expanded(
            child: Text(
              '$name${year.isNotEmpty ? ' ($year)' : ''}',
              style: TextStyle(
                fontSize: 11,
                color: mapState.isEnabled ? null : Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Toggle button
          IconButton(
            icon: Icon(
              mapState.isEnabled ? Icons.visibility : Icons.visibility_off,
              size: 16,
              color: mapState.isEnabled ? Colors.purple : Colors.grey,
            ),
            onPressed: () {
              ref.read(historicalMapsProvider.notifier).toggleMap(
                    mapState.stateCode,
                    mapState.layerId,
                  );
            },
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
        ],
      ),
    );
  }

  /// Accordion wrapper for Land Ownership section
  Widget _buildLandOwnershipAccordion(LandOwnershipFilter filter) {
    final enabledCount = filter.enabledTypes.length;
    final totalCount = LandOwnershipType.values.length;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true, // Land ownership is primary, start expanded
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: const Icon(Icons.terrain, size: 20, color: AppTheme.gold),
        title: const Text(
          'Land Ownership',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppTheme.gold,
          ),
        ),
        subtitle: Text(
          '$enabledCount/$totalCount types showing',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: enabledCount > 0,
              // Use theme styling for consistent appearance
              onChanged: (value) {
                if (value) {
                  _selectAllTypes();
                } else {
                  _clearAllFilters();
                }
              },
            ),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
        children: [
          _buildLandOwnershipContent(filter),
        ],
      ),
    );
  }

  /// Content for Land Ownership accordion
  Widget _buildLandOwnershipContent(LandOwnershipFilter filter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick filters
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildQuickFilterChip('Public Land', filter.showPublicLandOnly,
                (value) {
              _updateFilter(filter.copyWith(showPublicLandOnly: value));
            }),
            _buildQuickFilterChip(
                'Private Land', filter.showPrivateLandOnly, (value) {
              _updateFilter(filter.copyWith(showPrivateLandOnly: value));
            }),
            _buildQuickFilterChip(
                'Federal Land', filter.showFederalLandOnly, (value) {
              _updateFilter(filter.copyWith(showFederalLandOnly: value));
            }),
            _buildQuickFilterChip('State Land', filter.showStateLandOnly,
                (value) {
              _updateFilter(filter.copyWith(showStateLandOnly: value));
            }),
          ],
        ),

        const SizedBox(height: 8),

        // Land ownership types
        _buildLandTypeGrid(filter),

        const SizedBox(height: 8),

        // Land action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Hide All', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _selectAllTypes,
                icon: const Icon(Icons.select_all, size: 16),
                label: const Text('Show All', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Accordion wrapper for Trails section
  Widget _buildTrailsAccordion() {
    final trailFilter = ref.watch(trailFilterProvider);
    final enabledCount = trailFilter.enabledTypes.length;
    final isVisible = ref.watch(trailsOverlayVisibilityProvider);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Icon(Icons.hiking, size: 20, color: Colors.brown[600]),
        title: Text(
          'Trails',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.brown[600],
          ),
        ),
        subtitle: Text(
          isVisible && enabledCount > 0 ? '$enabledCount types showing' : 'Hidden',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: isVisible && enabledCount > 0,
              activeTrackColor: Colors.brown[600],
              onChanged: (value) {
                if (value) {
                  ref.read(trailFilterProvider.notifier).enableAllTypes();
                  ref.read(trailFilterProvider.notifier).enableAllSources();
                  ref.read(trailsOverlayVisibilityProvider.notifier).set(value: true);
                } else {
                  ref.read(trailFilterProvider.notifier).disableAllTypes();
                  ref.read(trailsOverlayVisibilityProvider.notifier).set(value: false);
                }
              },
            ),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
        children: [
          _buildTrailsContent(trailFilter),
        ],
      ),
    );
  }

  /// Content for Trails accordion
  Widget _buildTrailsContent(TrailFilter trailFilter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTrailTypeGrid(trailFilter),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(trailFilterProvider.notifier).disableAllTypes();
                  ref.read(trailsOverlayVisibilityProvider.notifier).set(value: false);
                },
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Hide All', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(trailFilterProvider.notifier).enableAllTypes();
                  ref.read(trailFilterProvider.notifier).enableAllSources();
                  ref.read(trailsOverlayVisibilityProvider.notifier).set(value: true);
                },
                icon: const Icon(Icons.select_all, size: 16),
                label: const Text('Show All', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Accordion wrapper for Historical Places section
  Widget _buildHistoricalPlacesAccordion() {
    final historicalPlacesFilter = ref.watch(historicalPlacesFilterProvider);
    final isVisible = ref.watch(historicalPlacesVisibilityProvider);
    final enabledCount = historicalPlacesFilter.enabledCategories.length;
    final registry = PlaceTypeRegistry();
    final totalCount = registry.allCategories.length;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Icon(Icons.location_history, size: 20, color: Colors.brown[800]),
        title: Text(
          'Historical Places',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.brown[800],
          ),
        ),
        subtitle: Text(
          isVisible && enabledCount > 0 ? '$enabledCount/$totalCount categories' : 'Hidden',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: isVisible && enabledCount > 0,
              activeTrackColor: Colors.brown[800],
              onChanged: (value) {
                if (value) {
                  ref.read(historicalPlacesFilterProvider.notifier).enableAllCategories();
                  ref.read(historicalPlacesVisibilityProvider.notifier).set(value: true);
                } else {
                  ref.read(historicalPlacesFilterProvider.notifier).disableAllCategories();
                  ref.read(historicalPlacesVisibilityProvider.notifier).set(value: false);
                }
              },
            ),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
        children: [
          _buildHistoricalPlacesContent(historicalPlacesFilter),
        ],
      ),
    );
  }

  /// Content for Historical Places accordion
  Widget _buildHistoricalPlacesContent(HistoricalPlaceFilter historicalPlacesFilter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick preset filters
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildHistoricalPresetChip(
              label: '⛏️ Mines Only',
              isSelected: _isOnlyMinesSelected(historicalPlacesFilter),
              onTap: _selectOnlyMines,
            ),
            _buildHistoricalPresetChip(
              label: '👻 Ghost Towns',
              isSelected: _isOnlyGhostTownsSelected(historicalPlacesFilter),
              onTap: _selectOnlyGhostTowns,
            ),
            _buildHistoricalPresetChip(
              label: '🎯 Treasure Hunt',
              isSelected: _isTreasureHuntSelected(historicalPlacesFilter),
              onTap: _selectTreasureHuntPlaces,
              highlight: true,
            ),
          ],
        ),

        const SizedBox(height: 8),

        _buildHistoricalPlaceTypeGrid(historicalPlacesFilter),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(historicalPlacesFilterProvider.notifier).disableAllCategories();
                  ref.read(historicalPlacesVisibilityProvider.notifier).set(value: false);
                },
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Hide All', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(historicalPlacesFilterProvider.notifier).enableAllCategories();
                  ref.read(historicalPlacesVisibilityProvider.notifier).set(value: true);
                },
                icon: const Icon(Icons.select_all, size: 16),
                label: const Text('Show All', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Accordion wrapper for Cell Coverage section (premium feature)
  Widget _buildCellCoverageAccordion() {
    final isPremium = ref.watch(isPremiumProvider);
    final isVisible = ref.watch(cellCoverageVisibilityProvider);
    final cellFilter = ref.watch(cellCoverageFilterProvider);
    final enabledCount = cellFilter.enabledTypes.length;
    final totalCount = RadioType.values.length;
    final totalTowersAsync = ref.watch(cellCoverageTotalCountProvider);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Icon(Icons.cell_tower, size: 20, color: Colors.blue[400]),
        title: Text(
          'Cell Coverage',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.blue[400],
          ),
        ),
        subtitle: totalTowersAsync.when(
          data: (totalTowers) => Text(
            isPremium
                ? (isVisible && enabledCount > 0
                    ? '$enabledCount/$totalCount types${totalTowers > 0 ? ' • ${_formatTowerCount(totalTowers)} towers' : ''}'
                    : 'Hidden')
                : 'Premium feature',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          loading: () => Text(
            isPremium ? 'Loading...' : 'Premium feature',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          error: (_, __) => Text(
            isPremium ? 'Hidden' : 'Premium feature',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPremium)
              Switch(
                value: isVisible && enabledCount > 0,
                activeTrackColor: Colors.blue[400],
                onChanged: (value) {
                  if (value) {
                    ref.read(cellCoverageFilterProvider.notifier).enableAll();
                    ref.read(cellCoverageVisibilityProvider.notifier).set(value: true);
                  } else {
                    ref.read(cellCoverageFilterProvider.notifier).disableAll();
                    ref.read(cellCoverageVisibilityProvider.notifier).set(value: false);
                  }
                },
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium, size: 12, color: AppTheme.gold),
                    SizedBox(width: 2),
                    Text(
                      'Premium',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gold,
                      ),
                    ),
                  ],
                ),
              ),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
        children: [
          if (isPremium)
            _buildCellCoverageContent(cellFilter)
          else
            _buildCellCoveragePremiumUpsell(),
        ],
      ),
    );
  }

  /// Format tower count with K suffix for large numbers
  String _formatTowerCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  /// Content for Cell Coverage accordion
  Widget _buildCellCoverageContent(CellCoverageFilter filter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick presets
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildCellPresetChip(
              label: '4G+ Only',
              isSelected: filter.enabledTypes.length == 2 &&
                  filter.enabledTypes.contains(RadioType.lte) &&
                  filter.enabledTypes.contains(RadioType.nr),
              onTap: () {
                ref.read(cellCoverageFilterProvider.notifier).setModernOnly();
                ref.read(cellCoverageVisibilityProvider.notifier).set(value: true);
              },
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Radio type toggles
        _buildCellTypeGrid(filter),

        const SizedBox(height: 8),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(cellCoverageFilterProvider.notifier).disableAll();
                  ref.read(cellCoverageVisibilityProvider.notifier).set(value: false);
                },
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Hide All', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(cellCoverageFilterProvider.notifier).enableAll();
                  ref.read(cellCoverageVisibilityProvider.notifier).set(value: true);
                },
                icon: const Icon(Icons.select_all, size: 16),
                label: const Text('Show All', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build cell coverage type grid with color indicators
  Widget _buildCellTypeGrid(CellCoverageFilter filter) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: RadioType.values.map((type) => _buildCellTypeChip(type, filter)).toList(),
    );
  }

  /// Build a single cell type filter chip
  Widget _buildCellTypeChip(RadioType type, CellCoverageFilter filter) {
    final isEnabled = filter.enabledTypes.contains(type);
    return FilterChip(
      label: Text(
        type.displayName,
        style: const TextStyle(fontSize: 10),
      ),
      selected: isEnabled,
      onSelected: (selected) {
        ref.read(cellCoverageFilterProvider.notifier).toggleType(type);

        // Auto-enable visibility when selecting a type
        if (selected && !ref.read(cellCoverageVisibilityProvider)) {
          ref.read(cellCoverageVisibilityProvider.notifier).set(value: true);
        }

        // Auto-disable visibility if no types are selected
        final newFilter = ref.read(cellCoverageFilterProvider);
        if (!selected && newFilter.noTypesEnabled) {
          ref.read(cellCoverageVisibilityProvider.notifier).set(value: false);
        }
      },
      selectedColor: type.color.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      avatar: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: type.color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
    );
  }

  /// Build preset chip for cell coverage
  Widget _buildCellPresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      backgroundColor: isSelected ? Colors.blue.withValues(alpha: 0.2) : null,
      side: isSelected ? BorderSide(color: Colors.blue[400]!, width: 1.5) : null,
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  /// Premium upsell for cell coverage
  Widget _buildCellCoveragePremiumUpsell() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.cell_tower, size: 32, color: Colors.blue[400]),
          const SizedBox(height: 8),
          Text(
            'Plan Your Coverage',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.blue[400],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "See cell tower locations to know where you'll have signal before you go.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppTheme.textOnDarkMuted : AppTheme.textOnLightMuted,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await showPaywall(context, title: 'Unlock Cell Coverage');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Start Free Trial',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Accordion wrapper for Custom Markers section
  Widget _buildCustomMarkersAccordion() {
    final customMarkersFilter = ref.watch(customMarkersFilterProvider);
    final markerCountAsync = ref.watch(customMarkersCountProvider);
    final isVisible = ref.watch(customMarkersVisibilityProvider);
    final enabledCount = customMarkersFilter.enabledCategories.length;

    return markerCountAsync.when(
      data: (count) {
        // Always show section to allow users to learn about custom markers
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            leading: Icon(Icons.push_pin, size: 20, color: Colors.blue[600]),
            title: Text(
              'Custom Markers',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.blue[600],
              ),
            ),
            subtitle: Text(
              count == 0
                  ? 'Long-press map to add'
                  : isVisible && enabledCount > 0
                      ? '$count markers • $enabledCount categories'
                      : '$count markers • Hidden',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (count > 0)
                  Switch(
                    value: isVisible && enabledCount > 0,
                    activeTrackColor: Colors.blue[600],
                    onChanged: (value) {
                      if (value) {
                        ref.read(customMarkersFilterProvider.notifier).enableAllCategories();
                        ref.read(customMarkersVisibilityProvider.notifier).set(value: true);
                      } else {
                        ref.read(customMarkersFilterProvider.notifier).disableAllCategories();
                        ref.read(customMarkersVisibilityProvider.notifier).set(value: false);
                      }
                    },
                  ),
                const Icon(Icons.expand_more, size: 20),
              ],
            ),
            children: [
              _buildCustomMarkersContent(customMarkersFilter, count),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Content for Custom Markers accordion
  Widget _buildCustomMarkersContent(CustomMarkerFilter filter, int count) {
    if (count == 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.touch_app, size: 18, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Long-press anywhere on the map to add a marker',
                style: TextStyle(fontSize: 12, color: Colors.blue[700]),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCustomMarkerCategoryGrid(filter),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(customMarkersFilterProvider.notifier).disableAllCategories();
                  ref.read(customMarkersVisibilityProvider.notifier).set(value: false);
                },
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Hide All', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(customMarkersFilterProvider.notifier).enableAllCategories();
                  ref.read(customMarkersVisibilityProvider.notifier).set(value: true);
                },
                icon: const Icon(Icons.select_all, size: 16),
                label: const Text('Show All', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Accordion wrapper for Session Markers section
  Widget _buildSessionMarkersAccordion() {
    final enabledCategories = ref.watch(sessionMarkersCategoryFilterProvider);
    final isVisible = ref.watch(sessionMarkersVisibilityProvider);
    final enabledCount = enabledCategories.length;
    final totalCount = CustomMarkerCategory.values.length;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: const Icon(Icons.flag, size: 20, color: AppTheme.gold),
        title: Row(
          children: [
            const Text(
              'Session Markers',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppTheme.gold,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'This Session',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.gold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          isVisible && enabledCount > 0 ? '$enabledCount/$totalCount categories' : 'Hidden',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: isVisible && enabledCount > 0,
              // Use theme styling for consistent appearance
              onChanged: (value) {
                if (value) {
                  ref.read(sessionMarkersCategoryFilterProvider.notifier).enableAll();
                  ref.read(sessionMarkersVisibilityProvider.notifier).set(value: true);
                } else {
                  ref.read(sessionMarkersCategoryFilterProvider.notifier).disableAll();
                  ref.read(sessionMarkersVisibilityProvider.notifier).set(value: false);
                }
              },
            ),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
        children: [
          _buildSessionMarkersContent(enabledCategories),
        ],
      ),
    );
  }

  /// Content for Session Markers accordion
  Widget _buildSessionMarkersContent(Set<CustomMarkerCategory> enabledCategories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSessionMarkerCategoryGrid(enabledCategories),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(sessionMarkersCategoryFilterProvider.notifier).disableAll();
                  ref.read(sessionMarkersVisibilityProvider.notifier).set(value: false);
                },
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Hide All', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(sessionMarkersCategoryFilterProvider.notifier).enableAll();
                  ref.read(sessionMarkersVisibilityProvider.notifier).set(value: true);
                },
                icon: const Icon(Icons.select_all, size: 16),
                label: const Text('Show All', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Master layer controls - Show All / Hide All for entire map
  Widget _buildMasterLayerControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.layers, size: 18, color: AppTheme.gold),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'All Layers',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppTheme.gold,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _hideAllLayers,
            icon: const Icon(Icons.visibility_off, size: 16),
            label: const Text('Hide All', style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: _showAllLayers,
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('Show All', style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppTheme.gold,
            ),
          ),
        ],
      ),
    );
  }

  /// Hide all layers (land, trails, historical places, historical maps, custom markers, session markers)
  void _hideAllLayers() {
    // Hide land types
    _clearAllFilters();

    // Hide trails
    ref.read(trailFilterProvider.notifier).disableAllTypes();
    ref.read(trailsOverlayVisibilityProvider.notifier).set(value: false);

    // Hide historical places (GNIS points)
    ref.read(historicalPlacesFilterProvider.notifier).disableAllCategories();
    ref.read(historicalPlacesVisibilityProvider.notifier).set(value: false);

    // Hide historical maps (MBTiles overlays)
    ref.read(historicalMapsProvider.notifier).disableAll();

    // Hide custom markers
    ref.read(customMarkersFilterProvider.notifier).disableAllCategories();
    ref.read(customMarkersVisibilityProvider.notifier).set(value: false);

    // Hide cell coverage
    ref.read(cellCoverageFilterProvider.notifier).disableAll();
    ref.read(cellCoverageVisibilityProvider.notifier).set(value: false);

    // Hide session markers (if in session context)
    if (widget.sessionId != null) {
      ref.read(sessionMarkersCategoryFilterProvider.notifier).disableAll();
      ref.read(sessionMarkersVisibilityProvider.notifier).set(value: false);
    }
  }

  /// Show all layers (land, trails, historical places, cell coverage, custom markers, session markers)
  /// Note: Historical maps (MBTiles) are NOT auto-enabled by "Show All" to avoid
  /// unexpected large overlay downloads. They must be toggled individually.
  void _showAllLayers() {
    // Show all land types
    _selectAllTypes();

    // Show all trails
    ref.read(trailFilterProvider.notifier).enableAllTypes();
    ref.read(trailFilterProvider.notifier).enableAllSources();
    ref.read(trailsOverlayVisibilityProvider.notifier).set(value: true);

    // Show all historical places (GNIS points)
    ref.read(historicalPlacesFilterProvider.notifier).enableAllCategories();
    ref.read(historicalPlacesVisibilityProvider.notifier).set(value: true);

    // Note: Historical maps (MBTiles) are NOT auto-enabled here since they
    // can be large and may cause unexpected performance issues if all enabled at once.
    // Users should toggle them individually in the Historical Maps section.

    // Show all custom markers
    ref.read(customMarkersFilterProvider.notifier).enableAllCategories();
    ref.read(customMarkersVisibilityProvider.notifier).set(value: true);

    // Show cell coverage (premium feature - will check subscription in provider)
    ref.read(cellCoverageFilterProvider.notifier).enableAll();
    ref.read(cellCoverageVisibilityProvider.notifier).set(value: true);

    // Show all session markers (if in session context)
    if (widget.sessionId != null) {
      ref.read(sessionMarkersCategoryFilterProvider.notifier).enableAll();
      ref.read(sessionMarkersVisibilityProvider.notifier).set(value: true);
    }
  }

  Widget _buildQuickFilterChip(
          String label, bool isSelected, ValueChanged<bool> onChanged) =>
      FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: onChanged,
        selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.3),
      );


  /// Build a tile for an available (not downloaded) historical map
  Widget _buildAvailableMapTile(QuadrangleSuggestion suggestion) {
    final isPremium = ref.watch(isPremiumProvider);

    return InkWell(
      onTap: () {
        if (isPremium) {
          widget.onDownloadAvailableMap?.call(suggestion);
        } else {
          showPaywall(context, title: 'Unlock Historical Maps');
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.map_outlined,
                color: Colors.purple[400],
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${suggestion.subtitle} - ${suggestion.quad.formattedSize}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPremium ? Icons.download : Icons.lock,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPremium ? 'Download' : 'Premium',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build grid of session marker category filter chips
  Widget _buildSessionMarkerCategoryGrid(Set<CustomMarkerCategory> enabledCategories) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: CustomMarkerCategory.values.map((category) {
        final isEnabled = enabledCategories.contains(category);
        return FilterChip(
          selected: isEnabled,
          onSelected: (selected) {
            ref.read(sessionMarkersCategoryFilterProvider.notifier).toggleCategory(category);
            // Auto-enable visibility when selecting a category
            if (selected && !ref.read(sessionMarkersVisibilityProvider)) {
              ref.read(sessionMarkersVisibilityProvider.notifier).set(value: true);
            }
            // Auto-disable visibility if no categories are selected
            final newCategories = ref.read(sessionMarkersCategoryFilterProvider);
            if (!selected && newCategories.isEmpty) {
              ref.read(sessionMarkersVisibilityProvider.notifier).set(value: false);
            }
          },
          avatar: Text(
            category.emoji,
            style: const TextStyle(fontSize: 12),
          ),
          label: Text(
            category.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isEnabled ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          selectedColor: category.defaultColor.withValues(alpha: 0.3),
          showCheckmark: false,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  /// Build grid of custom marker category filter chips
  Widget _buildCustomMarkerCategoryGrid(CustomMarkerFilter filter) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: CustomMarkerCategory.values.map((category) {
        final isEnabled = filter.enabledCategories.contains(category);
        return FilterChip(
          selected: isEnabled,
          onSelected: (selected) {
            ref.read(customMarkersFilterProvider.notifier).toggleCategory(category);
          },
          avatar: Text(
            category.emoji,
            style: const TextStyle(fontSize: 12),
          ),
          label: Text(
            category.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isEnabled ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          selectedColor: category.defaultColor.withValues(alpha: 0.3),
          showCheckmark: false,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  /// Build a preset chip for historical places
  Widget _buildHistoricalPresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      backgroundColor: isSelected
          ? (highlight ? AppTheme.gold.withValues(alpha: 0.3) : Colors.brown.withValues(alpha: 0.2))
          : null,
      side: isSelected && highlight
          ? const BorderSide(color: AppTheme.gold, width: 1.5)
          : null,
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  /// Check if only mines are selected
  bool _isOnlyMinesSelected(HistoricalPlaceFilter filter) {
    return filter.enabledTypeCodes.length == 1 &&
        filter.enabledTypeCodes.contains('MINE');
  }

  /// Check if only ghost towns (locales) are selected
  bool _isOnlyGhostTownsSelected(HistoricalPlaceFilter filter) {
    return filter.enabledTypeCodes.length == 1 &&
        filter.enabledTypeCodes.contains('LOCALE');
  }

  /// Check if treasure hunt preset is selected (mines + ghost towns + cemeteries)
  bool _isTreasureHuntSelected(HistoricalPlaceFilter filter) {
    const treasureHuntTypes = {'MINE', 'LOCALE', 'CEMETERY'};
    return filter.enabledTypeCodes.length == treasureHuntTypes.length &&
        filter.enabledTypeCodes.containsAll(treasureHuntTypes);
  }

  /// Toggle mines only preset - if already selected, restore all categories
  void _selectOnlyMines() {
    final filter = ref.read(historicalPlacesFilterProvider);
    if (_isOnlyMinesSelected(filter)) {
      // Already selected - restore all categories
      ref.read(historicalPlacesFilterProvider.notifier).enableAllCategories();
    } else {
      // Select only mines
      ref.read(historicalPlacesFilterProvider.notifier).setTypeCodes({'MINE'});
    }
    ref.read(historicalPlacesVisibilityProvider.notifier).set(value: true);
  }

  /// Toggle ghost towns preset - if already selected, restore all categories
  void _selectOnlyGhostTowns() {
    final filter = ref.read(historicalPlacesFilterProvider);
    if (_isOnlyGhostTownsSelected(filter)) {
      // Already selected - restore all categories
      ref.read(historicalPlacesFilterProvider.notifier).enableAllCategories();
    } else {
      // Select only ghost towns
      ref.read(historicalPlacesFilterProvider.notifier).setTypeCodes({'LOCALE'});
    }
    ref.read(historicalPlacesVisibilityProvider.notifier).set(value: true);
  }

  /// Toggle treasure hunt preset - if already selected, restore all categories
  void _selectTreasureHuntPlaces() {
    final filter = ref.read(historicalPlacesFilterProvider);
    if (_isTreasureHuntSelected(filter)) {
      // Already selected - restore all categories
      ref.read(historicalPlacesFilterProvider.notifier).enableAllCategories();
    } else {
      // Select treasure hunt places
      ref.read(historicalPlacesFilterProvider.notifier).setTypeCodes({
        'MINE',
        'LOCALE',
        'CEMETERY',
      });
    }
    ref.read(historicalPlacesVisibilityProvider.notifier).set(value: true);
  }

  /// Build historical place category grid
  Widget _buildHistoricalPlaceTypeGrid(HistoricalPlaceFilter filter) {
    final registry = PlaceTypeRegistry();
    final categories = registry.allCategories.toList();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: categories.map((category) => _buildCategoryChip(category, filter)).toList(),
    );
  }

  /// Build a single category filter chip
  Widget _buildCategoryChip(PlaceCategory category, HistoricalPlaceFilter filter) {
    final isEnabled = filter.enabledCategories.contains(category.id);
    final categoryColors = {
      'water': const Color(0xFF1E90FF),
      'terrain': const Color(0xFF696969),
      'historic': const Color(0xFF8B4513),
      'cultural': const Color(0xFFFFD700),
      'parks': const Color(0xFF228B22),
      'infra': const Color(0xFF708090),
    };
    final color = categoryColors[category.id] ?? Colors.grey;

    return FilterChip(
      label: Text(
        category.name,
        style: const TextStyle(fontSize: 10),
      ),
      selected: isEnabled,
      onSelected: (selected) {
        ref.read(historicalPlacesFilterProvider.notifier).toggleCategory(category.id);

        // Auto-enable visibility when selecting a category
        if (selected && !ref.read(historicalPlacesVisibilityProvider)) {
          ref.read(historicalPlacesVisibilityProvider.notifier).set(value: true);
        }

        // Auto-disable visibility if no categories are selected
        final newFilter = ref.read(historicalPlacesFilterProvider);
        if (!selected && newFilter.noCategoriesEnabled) {
          ref.read(historicalPlacesVisibilityProvider.notifier).set(value: false);
        }
      },
      selectedColor: color.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      avatar: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        child: Center(
          child: Text(
            category.emoji,
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ),
    );
  }

  /// Build trail type grid with color indicators (like land types)
  Widget _buildTrailTypeGrid(TrailFilter filter) {
    // Official trail types (USFS, BLM, NPS)
    final officialTypes = [
      'TERRA',   // Land trails
      'SNOW',    // Snowmobile
      'WATER',   // Water trails
    ];

    // Community trail types (OSM)
    final communityTypes = [
      'Hiker/Biker',
      'Hiker/Horse',
      'Hiker/Pedestrian Only',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Official Trails (USFS)
        const Text(
          'Official Trails',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: officialTypes.map((type) => _buildTrailTypeChip(type, filter)).toList(),
        ),
        const SizedBox(height: 8),

        // Community Trails (OSM)
        const Text(
          'Community Trails',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: communityTypes.map((type) => _buildTrailTypeChip(type, filter)).toList(),
        ),
      ],
    );
  }

  /// Build a single trail type filter chip with color indicator
  Widget _buildTrailTypeChip(String type, TrailFilter filter) {
    final isEnabled = filter.enabledTypes.contains(type);
    return FilterChip(
      label: Text(
        _getTrailTypeLabel(type),
        style: const TextStyle(fontSize: 10),
      ),
      selected: isEnabled,
      onSelected: (selected) {
        // Toggle the trail type
        ref.read(trailFilterProvider.notifier).toggleType(type);

        // Read the updated filter state
        final newFilter = ref.read(trailFilterProvider);

        // Auto-enable trails visibility when selecting a trail type
        if (selected && !ref.read(trailsOverlayVisibilityProvider)) {
          ref.read(trailsOverlayVisibilityProvider.notifier).set(value: true);
        }

        // Auto-disable trails visibility if no trail types are selected
        if (!selected && newFilter.enabledTypes.isEmpty) {
          ref.read(trailsOverlayVisibilityProvider.notifier).set(value: false);
        }
      },
      selectedColor: _getTrailTypeColor(type).withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      avatar: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: _getTrailTypeColor(type),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
    );
  }

  /// Get display label for trail type
  String _getTrailTypeLabel(String type) {
    switch (type) {
      case 'TERRA':
        return 'Land Trails';
      case 'SNOW':
        return 'Snowmobile';
      case 'WATER':
        return 'Water Trails';
      case 'Hiker/Biker':
        return 'Hiker/Biker';
      case 'Hiker/Horse':
        return 'Hiker/Horse';
      case 'Hiker/Pedestrian Only':
        return 'Pedestrian Only';
      default:
        return type;
    }
  }

  /// Get color for trail type (will be used for map rendering too)
  Color _getTrailTypeColor(String type) {
    switch (type) {
      // Official trail types (USFS)
      case 'TERRA':
        return const Color(0xFF8B4513); // Saddle brown for land trails
      case 'SNOW':
        return const Color(0xFF00BCD4); // Cyan for snowmobile trails
      case 'WATER':
        return const Color(0xFF2196F3); // Blue for water trails

      // Community trail types (OSM)
      case 'Hiker/Biker':
        return const Color(0xFF4CAF50); // Green for hiker/biker
      case 'Hiker/Horse':
        return const Color(0xFFFF9800); // Orange for hiker/horse
      case 'Hiker/Pedestrian Only':
        return const Color(0xFF9C27B0); // Purple for pedestrian only

      default:
        return const Color(0xFF757575); // Gray for unknown
    }
  }

  Widget _buildLandTypeGrid(LandOwnershipFilter filter) {
    // All land ownership types organized by category
    final federalTypes = [
      LandOwnershipType.bureauOfLandManagement,
      LandOwnershipType.nationalForest,
      LandOwnershipType.nationalPark,
      LandOwnershipType.nationalWildlifeRefuge,
      LandOwnershipType.nationalMonument,
      LandOwnershipType.nationalRecreationArea,
      LandOwnershipType.wilderness,
    ];

    final stateTypes = [
      LandOwnershipType.stateLand,
      LandOwnershipType.stateForest,
      LandOwnershipType.statePark,
      LandOwnershipType.stateWildlifeArea,
    ];

    final otherTypes = [
      LandOwnershipType.countyLand,
      LandOwnershipType.cityLand,
      LandOwnershipType.tribalLand,
      LandOwnershipType.privateLand,
      LandOwnershipType.wildlifeManagementArea,
      LandOwnershipType.conservationEasement,
      LandOwnershipType.unknown,
    ];


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Federal Land Types
        const Text(
          'Federal Land',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: federalTypes.map((type) => _buildLandTypeChip(type, filter)).toList(),
        ),
        const SizedBox(height: 8),

        // State Land Types
        const Text(
          'State Land',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: stateTypes.map((type) => _buildLandTypeChip(type, filter)).toList(),
        ),
        const SizedBox(height: 8),

        // Other Land Types
        const Text(
          'Other',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: otherTypes.map((type) => _buildLandTypeChip(type, filter)).toList(),
        ),
      ],
    );
  }

  Widget _buildLandTypeChip(LandOwnershipType type, LandOwnershipFilter filter) {
    final isEnabled = filter.enabledTypes.contains(type);
    return FilterChip(
      label: Text(
        _getLandTypeLabel(type),
        style: const TextStyle(fontSize: 10),
      ),
      selected: isEnabled,
      onSelected: (selected) {
        final newEnabledTypes = Set<LandOwnershipType>.from(filter.enabledTypes);
        if (selected) {
          newEnabledTypes.add(type);
        } else {
          newEnabledTypes.remove(type);
        }
        _updateFilter(filter.copyWith(enabledTypes: newEnabledTypes));
      },
      selectedColor: _getLandTypeColor(type).withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      avatar: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: _getLandTypeColor(type),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
    );
  }

  String _getLandTypeLabel(LandOwnershipType type) {
    switch (type) {
      case LandOwnershipType.federalLand:
        return 'Federal Land';
      case LandOwnershipType.bureauOfLandManagement:
        return 'BLM';
      case LandOwnershipType.nationalPark:
        return 'National Park';
      case LandOwnershipType.nationalForest:
        return 'National Forest';
      case LandOwnershipType.nationalWildlifeRefuge:
        return 'Wildlife Refuge';
      case LandOwnershipType.nationalMonument:
        return 'Monument';
      case LandOwnershipType.nationalRecreationArea:
        return "Nat'l Recreation";
      case LandOwnershipType.wilderness:
        return 'Wilderness';
      case LandOwnershipType.stateForest:
        return 'State Forest';
      case LandOwnershipType.statePark:
        return 'State Park';
      case LandOwnershipType.stateLand:
        return 'State Land';
      case LandOwnershipType.stateWildlifeArea:
        return 'State Wildlife';
      case LandOwnershipType.privateLand:
        return 'Private';
      case LandOwnershipType.tribalLand:
        return 'Tribal';
      case LandOwnershipType.countyLand:
        return 'County';
      case LandOwnershipType.cityLand:
        return 'City';
      case LandOwnershipType.ngoConservation:
        return 'NGO Conservation';
      case LandOwnershipType.wildlifeManagementArea:
        return 'WMA';
      case LandOwnershipType.conservationEasement:
        return 'Conservation';
      case LandOwnershipType.unknown:
        return 'Unknown';
    }
  }

  Color _getLandTypeColor(LandOwnershipType type) {
    // Use the actual colors from the model - matches what's displayed on the map
    return Color(type.defaultColor);
  }

  void _updateFilter(LandOwnershipFilter newFilter) {
    widget.onFilterChanged?.call(newFilter);
    ref.read(landOwnershipFilterProvider.notifier).updateFilter(newFilter);
  }

  void _clearAllFilters() {
    const clearedFilter = LandOwnershipFilter();
    _updateFilter(clearedFilter);
  }

  void _selectAllTypes() {
    // Use the default filter which has all types enabled
    final allTypesFilter = LandOwnershipFilter.defaultFilter();
    _updateFilter(allTypesFilter);
  }
}
