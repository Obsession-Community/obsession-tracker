import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/app_settings.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/providers/land_lookup_provider.dart';
import 'package:obsession_tracker/core/providers/settings_provider.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/core/services/land_ownership_service.dart';

/// Provider for land ownership filter state (synced with settings)
final landOwnershipFilterProvider =
    NotifierProvider<LandOwnershipFilterNotifier, LandOwnershipFilter>(
        LandOwnershipFilterNotifier.new);

/// Provider for land ownership overlay visibility (synced with settings)
final landOverlayVisibilityProvider =
    NotifierProvider<LandOverlayVisibilityNotifier, bool>(
        LandOverlayVisibilityNotifier.new);

/// Provider for land ownership overlay opacity (synced with settings)
final landOverlayOpacityProvider =
    NotifierProvider<LandOverlayOpacityNotifier, double>(
        LandOverlayOpacityNotifier.new);

/// Provider for land ownership data in current view - with subscription check
final landOwnershipDataProvider =
    FutureProvider.family<List<LandOwnership>, LandBounds>((ref, bounds) async {
  try {
    // Check subscription status before fetching data
    final isPremium = ref.watch(isPremiumProvider);

    if (!isPremium) {
      // Free tier users don't get land ownership data
      debugPrint('🚫 Land ownership data blocked - premium subscription required');
      return [];
    }

    // Use land lookup service which handles entitlement checking
    final landLookupService = ref.read(landLookupServiceProvider);
    final result = await landLookupService.getLandOwnershipData(
      northBound: bounds.north,
      southBound: bounds.south,
      eastBound: bounds.east,
      westBound: bounds.west,
      limit: 200, // Get more data for better map coverage
    );

    if (!result.success) {
      debugPrint('Land data fetch failed: ${result.error}');
      return [];
    }

    // Apply local filters to the data
    final filter = ref.watch(landOwnershipFilterProvider);
    return _applyFiltersToData(result.data ?? [], filter);
  } catch (e) {
    debugPrint('Land ownership data error: $e');
    // Return empty list on error to avoid breaking the map
    return [];
  }
});

/// Provider for land ownership statistics
final landOwnershipStatsProvider =
    FutureProvider<Map<LandOwnershipType, int>>((ref) async {
  final service = LandOwnershipService.instance;
  await service.initialize();
  return service.getLandOwnershipCountByType();
});

/// Provider for checking if land data exists for a region
final landDataAvailabilityProvider =
    FutureProvider.family<bool, LandBounds>((ref, bounds) async {
  final service = LandOwnershipService.instance;
  await service.initialize();
  return service.hasDataForRegion(bounds);
});

/// Notifier for land overlay visibility that syncs with settings
class LandOverlayVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Listen to settings changes and update accordingly
    ref.listen<AppSettings>(appSettingsProvider, (previous, next) {
      // Only update if the value has actually changed
      if (previous?.map.showLandOverlay != next.map.showLandOverlay) {
        _updateFromSettings(next.map.showLandOverlay);
      }
    });

    // Get initial value from settings
    final settings = ref.read(appSettingsProvider);
    return settings.map.showLandOverlay;
  }

  void toggle() {
    state = !state;
    _saveToSettings();
  }

  void set({required bool value}) {
    state = value;
    _saveToSettings();
  }

  void _updateFromSettings(bool value) {
    // Update state without triggering a settings save (to avoid circular updates)
    state = value;
  }

  void _saveToSettings() {
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    final currentSettings = ref.read(appSettingsProvider);
    final newMapSettings = currentSettings.map.copyWith(showLandOverlay: state);
    settingsNotifier.updateMapSettings(newMapSettings);
  }
}

/// Notifier for land overlay opacity that syncs with settings
class LandOverlayOpacityNotifier extends Notifier<double> {
  @override
  double build() {
    // Get initial value from settings
    final settings = ref.read(appSettingsProvider);
    return settings.map.landOverlayOpacity;
  }

  void setOpacity(double opacity) {
    state = opacity.clamp(0.0, 1.0);
    _saveToSettings();
  }

  void _saveToSettings() {
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    final currentSettings = ref.read(appSettingsProvider);
    final newMapSettings =
        currentSettings.map.copyWith(landOverlayOpacity: state);
    settingsNotifier.updateMapSettings(newMapSettings);
  }
}

/// Notifier for managing land ownership filter state
class LandOwnershipFilterNotifier extends Notifier<LandOwnershipFilter> {
  @override
  LandOwnershipFilter build() {
    // Get initial value from settings
    final settings = ref.read(appSettingsProvider);
    final savedFilter = settings.map.landOwnershipFilter;
    final defaultFilter = LandOwnershipFilter.defaultFilter();

    // Check if saved filter is outdated based on version
    // If version changed, reset to defaults to ensure all new types are enabled
    final LandOwnershipFilter initialFilter;
    if (savedFilter != null &&
        savedFilter.enabledTypes.isNotEmpty &&
        savedFilter.version == LandOwnershipFilter.currentVersion) {
      // Version matches - use saved filter as-is
      initialFilter = savedFilter;
      debugPrint('[LandFilter] Using saved filter v${savedFilter.version} with ${savedFilter.enabledTypes.length} enabled types');
    } else if (savedFilter != null && savedFilter.version < LandOwnershipFilter.currentVersion) {
      // Version outdated - reset to defaults
      initialFilter = defaultFilter;
      debugPrint('[LandFilter] 🔄 Filter version outdated (v${savedFilter.version} → v${LandOwnershipFilter.currentVersion}), resetting to defaults with ${defaultFilter.enabledTypes.length} types');
      // Save the new default filter to persist the version update
      Future.microtask(_saveToSettings);
    } else {
      // No saved filter or empty - use defaults
      initialFilter = defaultFilter;
      debugPrint('[LandFilter] Using default filter v${defaultFilter.version} with ${defaultFilter.enabledTypes.length} enabled types');
    }

    debugPrint('[LandFilter] Enabled types: ${initialFilter.enabledTypes.map((t) => t.displayName).join(", ")}');

    // Listen to settings changes and update accordingly
    ref.listen<AppSettings>(appSettingsProvider, (previous, next) {
      // Only update if the land filter has actually changed
      if (previous?.map.landOwnershipFilter != next.map.landOwnershipFilter) {
        if (next.map.landOwnershipFilter != null) {
          _updateFromSettings(next.map.landOwnershipFilter!);
        }
      }
    });

    return initialFilter;
  }

  /// Update the entire filter
  void updateFilter(LandOwnershipFilter filter) {
    state = filter;
    // Legacy OSM polygon cache removed - using Mapbox annotations now
    _saveToSettings();
  }

  /// Update filter from settings (internal use)
  void _updateFromSettings(LandOwnershipFilter filter) {
    state = filter;
    // Don't save to settings again to avoid loops
    // Legacy OSM polygon cache removed - using Mapbox annotations now
  }

  /// Save current filter state to settings
  void _saveToSettings() {
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    final currentSettings = ref.read(appSettingsProvider);
    final newMapSettings = currentSettings.map.copyWith(landOwnershipFilter: state);
    settingsNotifier.updateMapSettings(newMapSettings);
  }

  /// Toggle a land ownership type
  void toggleOwnershipType(LandOwnershipType type) {
    final enabledTypes = Set<LandOwnershipType>.from(state.enabledTypes);
    if (enabledTypes.contains(type)) {
      enabledTypes.remove(type);
    } else {
      enabledTypes.add(type);
    }
    state = state.copyWith(enabledTypes: enabledTypes);
    _saveToSettings();
  }

  /// Toggle multiple ownership types
  void toggleOwnershipTypes(List<LandOwnershipType> types) {
    final enabledTypes = Set<LandOwnershipType>.from(state.enabledTypes);
    for (final type in types) {
      if (enabledTypes.contains(type)) {
        enabledTypes.remove(type);
      } else {
        enabledTypes.add(type);
      }
    }
    state = state.copyWith(enabledTypes: enabledTypes);
    _saveToSettings();
  }

  /// Set enabled ownership types
  void setEnabledTypes(Set<LandOwnershipType> types) {
    state = state.copyWith(enabledTypes: types);
    _saveToSettings();
  }

  /// Clear all enabled types
  void clearEnabledTypes() {
    state = state.copyWith(enabledTypes: const <LandOwnershipType>{});
    _saveToSettings();
  }

  /// Set public land only filter
  void setShowPublicLandOnly({required bool showPublicLandOnly}) {
    state = state.copyWith(
      showPublicLandOnly: showPublicLandOnly,
      showPrivateLandOnly: !showPublicLandOnly && state.showPrivateLandOnly,
    );
    _saveToSettings();
  }

  /// Set private land only filter
  void setShowPrivateLandOnly({required bool showPrivateLandOnly}) {
    state = state.copyWith(
      showPrivateLandOnly: showPrivateLandOnly,
      showPublicLandOnly: !showPrivateLandOnly && state.showPublicLandOnly,
    );
    _saveToSettings();
  }

  /// Set federal land only filter
  void setShowFederalLandOnly({required bool showFederalLandOnly}) {
    state = state.copyWith(
      showFederalLandOnly: showFederalLandOnly,
      showStateLandOnly: !showFederalLandOnly && state.showStateLandOnly,
    );
    _saveToSettings();
  }

  /// Set state land only filter
  void setShowStateLandOnly({required bool showStateLandOnly}) {
    state = state.copyWith(
      showStateLandOnly: showStateLandOnly,
      showFederalLandOnly: !showStateLandOnly && state.showFederalLandOnly,
    );
    _saveToSettings();
  }

  /// Set fee areas only filter
  void setShowFeeAreasOnly({required bool showFeeAreasOnly}) {
    state = state.copyWith(showFeeAreasOnly: showFeeAreasOnly);
    _saveToSettings();
  }

  /// Set hide restricted areas filter
  void setHideRestrictedAreas({required bool hideRestrictedAreas}) {
    state = state.copyWith(hideRestrictedAreas: hideRestrictedAreas);
    _saveToSettings();
  }

  /// Set minimum area filter
  void setMinArea(double minArea) {
    state = state.copyWith(minArea: minArea);
    _saveToSettings();
  }

  /// Set search query
  void setSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query);
    _saveToSettings();
  }

  /// Clear all filters
  void clearAllFilters() {
    state = const LandOwnershipFilter();
    // Legacy OSM polygon cache removed - using Mapbox annotations now
    _saveToSettings();
  }

  /// Set common outdoor recreation land types
  void setCommonOutdoorTypes() {
    state = state.copyWith(
      enabledTypes: {
        LandOwnershipType.nationalForest,
        LandOwnershipType.nationalPark,
        LandOwnershipType.bureauOfLandManagement,
        LandOwnershipType.stateForest,
        LandOwnershipType.statePark,
        LandOwnershipType.wilderness,
        LandOwnershipType.nationalWildlifeRefuge,
        LandOwnershipType.stateWildlifeArea,
      },
    );
    // Legacy OSM polygon cache removed - using Mapbox annotations now
    _saveToSettings();
  }

  /// Set hunting/fishing focused land types
  void setHuntingFishingTypes() {
    state = state.copyWith(
      enabledTypes: {
        LandOwnershipType.nationalForest,
        LandOwnershipType.bureauOfLandManagement,
        LandOwnershipType.stateForest,
        LandOwnershipType.nationalWildlifeRefuge,
        LandOwnershipType.stateWildlifeArea,
        LandOwnershipType.wildlifeManagementArea,
      },
    );
    _saveToSettings();
  }

  /// Set treasure hunting focused land types (public accessible land)
  void setTreasureHuntingTypes() {
    state = state.copyWith(
      enabledTypes: {
        LandOwnershipType.nationalForest,
        LandOwnershipType.bureauOfLandManagement,
        LandOwnershipType.stateForest,
        LandOwnershipType.stateLand,
      },
      hideRestrictedAreas: true,
    );
    _saveToSettings();
  }

  /// Set South Dakota comprehensive filter (show all available property types in SD)
  void setSouthDakotaFilter() {
    state = state.copyWith(
      enabledTypes: {
        LandOwnershipType.nationalPark, // Wind Cave, Mount Rushmore
        LandOwnershipType.nationalForest, // Black Hills National Forest
        LandOwnershipType.statePark, // Custer State Park
        LandOwnershipType.bureauOfLandManagement,
        LandOwnershipType.nationalWildlifeRefuge,
        LandOwnershipType.stateForest,
        LandOwnershipType.wilderness,
        LandOwnershipType.nationalMonument,
        LandOwnershipType.stateWildlifeArea,
        LandOwnershipType.stateLand,
        LandOwnershipType.tribalLand,
      },
      showPublicLandOnly: false, // Allow all land types
      hideRestrictedAreas: false, // Show all areas for comprehensive view
    );
    // Legacy OSM polygon cache removed - using Mapbox annotations now
    _saveToSettings();
  }
}

// Legacy OSM polygon/marker providers removed - using Mapbox annotations now

/// Provider for land ownership import progress
final landDataImportProvider =
    NotifierProvider<LandDataImportNotifier, LandDataImportState>(
        LandDataImportNotifier.new);

/// State for land data import process
class LandDataImportState {
  const LandDataImportState({
    this.isImporting = false,
    this.currentState = '',
    this.progress = 0.0,
    this.error,
    this.completedStates = const [],
  });

  final bool isImporting;
  final String currentState;
  final double progress;
  final String? error;
  final List<String> completedStates;

  LandDataImportState copyWith({
    bool? isImporting,
    String? currentState,
    double? progress,
    String? error,
    List<String>? completedStates,
  }) =>
      LandDataImportState(
        isImporting: isImporting ?? this.isImporting,
        currentState: currentState ?? this.currentState,
        progress: progress ?? this.progress,
        error: error ?? this.error,
        completedStates: completedStates ?? this.completedStates,
      );
}

/// Notifier for managing land data import process
class LandDataImportNotifier extends Notifier<LandDataImportState> {
  @override
  LandDataImportState build() => const LandDataImportState();

  /// Start importing land data for specified states
  Future<void> importLandData(List<String> stateCodes) async {
    state = state.copyWith(
      isImporting: true,
      completedStates: [],
      progress: 0.0,
    );

    try {
      final service = LandOwnershipService.instance;
      await service.initialize();

      await service.importPADUSData(
        stateCodes,
        onProgress: (message) {
          state = state.copyWith(currentState: message);
        },
        onError: (error) {
          state = state.copyWith(error: error);
        },
      );

      state = state.copyWith(
        isImporting: false,
        currentState: 'Import completed successfully',
        progress: 1.0,
        completedStates: stateCodes,
      );
    } catch (e) {
      state = state.copyWith(
        isImporting: false,
        error: 'Import failed: $e',
        progress: 0.0,
      );
    }
  }

  /// Clear import state
  void clearImportState() {
    state = const LandDataImportState();
  }
}

/// Provider for getting land ownership details by ID
final landOwnershipDetailsProvider =
    FutureProvider.family<LandOwnership?, String>((ref, id) async {
  final service = LandOwnershipService.instance;
  await service.initialize();
  return service.getLandOwnershipById(id);
});

/// Provider for land ownership search results
final landOwnershipSearchProvider =
    FutureProvider.family<List<LandOwnership>, String>((ref, query) async {
  if (query.isEmpty) return [];

  final service = LandOwnershipService.instance;
  await service.initialize();
  return service.searchLandOwnership(query);
});

/// Helper function to apply filters to BFF data
List<LandOwnership> _applyFiltersToData(
    List<LandOwnership> data, LandOwnershipFilter filter) {
  var filtered = data.toList();

  // Apply enabled types filter - if no types selected, show nothing
  if (filter.enabledTypes.isEmpty) {
    return [];
  }

  filtered = filtered
      .where((item) => filter.enabledTypes.contains(item.ownershipType))
      .toList();
  
  // Apply public/private filters
  if (filter.showPublicLandOnly) {
    filtered = filtered
        .where((item) => item.accessType == AccessType.publicOpen)
        .toList();
  } else if (filter.showPrivateLandOnly) {
    filtered = filtered
        .where((item) => item.accessType == AccessType.noPublicAccess ||
            item.accessType == AccessType.restrictedAccess)
        .toList();
  }
  
  // Apply federal/state filters
  if (filter.showFederalLandOnly) {
    filtered = filtered
        .where((item) => 
            item.ownershipType == LandOwnershipType.nationalPark ||
            item.ownershipType == LandOwnershipType.nationalForest ||
            item.ownershipType == LandOwnershipType.bureauOfLandManagement ||
            item.ownershipType == LandOwnershipType.nationalWildlifeRefuge ||
            item.ownershipType == LandOwnershipType.nationalMonument)
        .toList();
  } else if (filter.showStateLandOnly) {
    filtered = filtered
        .where((item) => 
            item.ownershipType == LandOwnershipType.statePark ||
            item.ownershipType == LandOwnershipType.stateForest ||
            item.ownershipType == LandOwnershipType.stateWildlifeArea)
        .toList();
  }
  
  // Apply fee areas filter
  if (filter.showFeeAreasOnly) {
    filtered = filtered
        .where((item) => item.accessType == AccessType.permitRequired ||
            item.accessType == AccessType.feeRequired)
        .toList();
  }
  
  // Apply restricted areas filter
  if (filter.hideRestrictedAreas) {
    filtered = filtered
        .where((item) => item.accessType != AccessType.restrictedAccess &&
            item.accessType != AccessType.noPublicAccess)
        .toList();
  }
  
  // Apply search query filter
  if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
    final query = filter.searchQuery!.toLowerCase();
    filtered = filtered
        .where((item) => 
            item.ownerName.toLowerCase().contains(query) ||
            (item.agencyName?.toLowerCase().contains(query) ?? false))
        .toList();
  }
  
  return filtered;
}
