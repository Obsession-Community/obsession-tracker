import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/historical_place.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/core/services/app_settings_service.dart';
import 'package:obsession_tracker/core/services/offline_land_rights_service.dart';

/// Provider for historical places overlay visibility
final historicalPlacesVisibilityProvider =
    NotifierProvider<HistoricalPlacesVisibilityNotifier, bool>(
        HistoricalPlacesVisibilityNotifier.new);

/// Provider for historical places filter configuration
final historicalPlacesFilterProvider =
    NotifierProvider<HistoricalPlacesFilterNotifier, HistoricalPlaceFilter>(
        HistoricalPlacesFilterNotifier.new);

/// Provider for historical places data in current view
///
/// Returns historical places from SQLite cache based on map bounds.
/// Requires premium subscription and downloaded state data.
final historicalPlacesDataProvider =
    FutureProvider.family<List<HistoricalPlace>, LandBounds>((ref, bounds) async {
  try {
    // Check subscription status
    final isPremium = ref.watch(isPremiumProvider);
    if (!isPremium) {
      debugPrint('[INFO] Historical places blocked - premium subscription required');
      return [];
    }

    // Check visibility
    final isVisible = ref.watch(historicalPlacesVisibilityProvider);
    if (!isVisible) {
      return [];
    }

    // Get filter configuration
    final filter = ref.watch(historicalPlacesFilterProvider);
    if (filter.noCategoriesEnabled) {
      return [];
    }

    // Query from SQLite cache
    final offlineService = OfflineLandRightsService();
    final places = await offlineService.queryHistoricalPlacesForBounds(
      north: bounds.north,
      south: bounds.south,
      east: bounds.east,
      west: bounds.west,
      categoryFilter: filter.enabledCategories,
      typeCodeFilter: filter.enabledTypeCodes,
    );

    debugPrint('[Historical Places] Found ${places.length} places in bounds');
    return places;
  } catch (e) {
    debugPrint('[Historical Places] Error fetching data: $e');
    return [];
  }
});

/// Provider for historical places download info
///
/// Returns list of states with downloaded historical places data.
final historicalPlacesDownloadsProvider =
    FutureProvider<List<HistoricalPlacesDownloadInfo>>((ref) async {
  try {
    final offlineService = OfflineLandRightsService();
    return offlineService.getHistoricalPlacesDownloads();
  } catch (e) {
    debugPrint('[Historical Places] Error fetching downloads: $e');
    return [];
  }
});

/// Provider for total historical places count
final historicalPlacesTotalCountProvider = FutureProvider<int>((ref) async {
  try {
    final offlineService = OfflineLandRightsService();
    return offlineService.getTotalHistoricalPlacesCount();
  } catch (e) {
    return 0;
  }
});

/// Notifier for historical places overlay visibility with persistence via AppSettingsService
class HistoricalPlacesVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Read from AppSettingsService which is already loaded at app startup
    final settings = AppSettingsService.instance.currentSettings;
    debugPrint('[Historical Places] Initial visibility from settings: ${settings.map.showHistoricalPlaces}');
    return settings.map.showHistoricalPlaces;
  }

  Future<void> _persistState() async {
    try {
      final settings = AppSettingsService.instance.currentSettings;
      await AppSettingsService.instance.updateMapSettings(
        settings.map.copyWith(showHistoricalPlaces: state),
      );
    } catch (e) {
      debugPrint('[Historical Places] Error persisting state: $e');
    }
  }

  void toggle() {
    state = !state;
    debugPrint('[Historical Places] Visibility toggled to: $state');
    _persistState();
  }

  void set({required bool value}) {
    state = value;
    debugPrint('[Historical Places] Visibility set to: $state');
    _persistState();
  }
}

/// Notifier for historical places filter configuration
class HistoricalPlacesFilterNotifier extends Notifier<HistoricalPlaceFilter> {
  @override
  HistoricalPlaceFilter build() => HistoricalPlaceFilter.defaultFilter;

  /// Toggle a category filter
  void toggleCategory(String categoryId) {
    state = state.toggleCategory(categoryId);
    final category = PlaceTypeRegistry().getCategory(categoryId);
    debugPrint('[Historical Places Filter] Toggled ${category.name}: ${state.enabledCategories.contains(categoryId)}');
  }

  /// Toggle a specific type code filter
  void toggleTypeCode(String typeCode) {
    state = state.toggleTypeCode(typeCode);
    final typeMeta = PlaceTypeRegistry().getType(typeCode);
    debugPrint('[Historical Places Filter] Toggled ${typeMeta.name}: ${state.enabledTypeCodes.contains(typeCode)}');
  }

  /// Enable all categories
  void enableAllCategories() {
    state = state.enableAllCategories();
    debugPrint('[Historical Places Filter] Enabled all categories');
  }

  /// Disable all categories
  void disableAllCategories() {
    state = state.disableAllCategories();
    debugPrint('[Historical Places Filter] Disabled all categories');
  }

  /// Set specific categories
  void setCategories(Set<String> categories) {
    state = state.copyWith(enabledCategories: categories, enabledTypeCodes: const {});
    debugPrint('[Historical Places Filter] Set categories: ${categories.join(", ")}');
  }

  /// Set specific type codes
  void setTypeCodes(Set<String> typeCodes) {
    state = state.copyWith(enabledTypeCodes: typeCodes);
    debugPrint('[Historical Places Filter] Set type codes: ${typeCodes.join(", ")}');
  }

  /// Set search query
  void setSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query);
    debugPrint('[Historical Places Filter] Search query: $query');
  }

  /// Reset to default
  void reset() {
    state = HistoricalPlaceFilter.defaultFilter;
    debugPrint('[Historical Places Filter] Reset to default');
  }
}

/// Provider for searching historical places by name
final historicalPlacesSearchProvider =
    FutureProvider.family<List<HistoricalPlace>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];

  try {
    // Check subscription status
    final isPremium = ref.watch(isPremiumProvider);
    if (!isPremium) {
      return [];
    }

    final offlineService = OfflineLandRightsService();
    final places = await offlineService.searchHistoricalPlaces(
      query: query,
    );

    debugPrint('[Historical Places Search] Found ${places.length} results for "$query"');
    return places;
  } catch (e) {
    debugPrint('[Historical Places Search] Error: $e');
    return [];
  }
});

/// Provider to check if any historical places data is downloaded
final hasHistoricalPlacesDataProvider = FutureProvider<bool>((ref) async {
  try {
    final offlineService = OfflineLandRightsService();
    final states = await offlineService.getStatesWithHistoricalPlaces();
    return states.isNotEmpty;
  } catch (e) {
    return false;
  }
});
