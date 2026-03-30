import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/custom_marker.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/models/marker_attachment.dart';
import 'package:obsession_tracker/core/services/app_settings_service.dart';
import 'package:obsession_tracker/core/services/custom_marker_service.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/marker_attachment_service.dart';

/// Provider for custom markers overlay visibility
final customMarkersVisibilityProvider =
    NotifierProvider<CustomMarkersVisibilityNotifier, bool>(
        CustomMarkersVisibilityNotifier.new);

/// Provider for custom markers filter configuration
final customMarkersFilterProvider =
    NotifierProvider<CustomMarkersFilterNotifier, CustomMarkerFilter>(
        CustomMarkersFilterNotifier.new);

/// Provider for custom markers data in current view
///
/// Returns custom markers from SQLite based on map bounds.
/// Does not require premium subscription (user's own data).
final customMarkersDataProvider =
    FutureProvider.family<List<CustomMarker>, LandBounds>((ref, bounds) async {
  try {
    // Check visibility
    final isVisible = ref.watch(customMarkersVisibilityProvider);
    if (!isVisible) {
      return [];
    }

    // Get filter configuration
    final filter = ref.watch(customMarkersFilterProvider);
    if (filter.noCategoriesEnabled) {
      return [];
    }

    // Query from SQLite
    final service = CustomMarkerService();
    final markers = await service.getMarkersForBounds(
      north: bounds.north,
      south: bounds.south,
      east: bounds.east,
      west: bounds.west,
      categoryFilter: filter.enabledCategories,
    );

    debugPrint('[Custom Markers] Found ${markers.length} markers in bounds');
    return markers;
  } catch (e) {
    debugPrint('[Custom Markers] Error fetching data: $e');
    return [];
  }
});

/// Provider for all custom markers (not bounds-limited)
///
/// Used for list views, search, and global marker management.
final allCustomMarkersProvider = FutureProvider<List<CustomMarker>>((ref) async {
  try {
    final service = CustomMarkerService();
    return service.getAllMarkers();
  } catch (e) {
    debugPrint('[Custom Markers] Error fetching all markers: $e');
    return [];
  }
});

/// Provider for custom markers count
final customMarkersCountProvider = FutureProvider<int>((ref) async {
  try {
    final db = DatabaseService();
    return db.getCustomMarkerCount();
  } catch (e) {
    return 0;
  }
});

/// Provider for attachments of a specific marker
final markerAttachmentsProvider =
    FutureProvider.family<List<MarkerAttachment>, String>((ref, markerId) async {
  try {
    final service = MarkerAttachmentService();
    return service.getAttachmentsForMarker(markerId);
  } catch (e) {
    debugPrint('[Marker Attachments] Error fetching attachments: $e');
    return [];
  }
});

/// Provider for a single custom marker by ID
final customMarkerByIdProvider =
    FutureProvider.family<CustomMarker?, String>((ref, markerId) async {
  try {
    final service = CustomMarkerService();
    return service.getMarker(markerId);
  } catch (e) {
    debugPrint('[Custom Markers] Error fetching marker: $e');
    return null;
  }
});

/// Provider for markers linked to a specific hunt
final markersForHuntProvider =
    FutureProvider.family<List<CustomMarker>, String>((ref, huntId) async {
  try {
    final service = CustomMarkerService();
    return service.getMarkersForHunt(huntId);
  } catch (e) {
    debugPrint('[Custom Markers] Error fetching markers for hunt: $e');
    return [];
  }
});

/// Notifier for custom markers overlay visibility with persistence via AppSettingsService
class CustomMarkersVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Read from AppSettingsService which is already loaded at app startup
    final settings = AppSettingsService.instance.currentSettings;
    debugPrint('[Custom Markers] Initial visibility from settings: ${settings.map.showCustomMarkers}');
    return settings.map.showCustomMarkers;
  }

  Future<void> _persistState() async {
    try {
      final settings = AppSettingsService.instance.currentSettings;
      await AppSettingsService.instance.updateMapSettings(
        settings.map.copyWith(showCustomMarkers: state),
      );
    } catch (e) {
      debugPrint('[Custom Markers] Error persisting state: $e');
    }
  }

  void toggle() {
    state = !state;
    debugPrint('[Custom Markers] Visibility toggled to: $state');
    _persistState();
  }

  void set({required bool value}) {
    state = value;
    debugPrint('[Custom Markers] Visibility set to: $state');
    _persistState();
  }
}

/// Notifier for custom markers filter configuration
class CustomMarkersFilterNotifier extends Notifier<CustomMarkerFilter> {
  @override
  CustomMarkerFilter build() => CustomMarkerFilter.defaultFilter;

  /// Toggle a category filter
  void toggleCategory(CustomMarkerCategory category) {
    state = state.toggleCategory(category);
    debugPrint(
        '[Custom Markers Filter] Toggled ${category.displayName}: ${state.enabledCategories.contains(category)}');
  }

  /// Enable all categories
  void enableAllCategories() {
    state = state.enableAllCategories();
    debugPrint('[Custom Markers Filter] Enabled all categories');
  }

  /// Disable all categories
  void disableAllCategories() {
    state = state.disableAllCategories();
    debugPrint('[Custom Markers Filter] Disabled all categories');
  }

  /// Set specific categories
  void setCategories(Set<CustomMarkerCategory> categories) {
    state = state.copyWith(enabledCategories: categories);
    debugPrint(
        '[Custom Markers Filter] Set categories: ${categories.map((c) => c.displayName).join(", ")}');
  }

  /// Set search query
  void setSearchQuery(String? query) {
    state = state.copyWith(
      searchQuery: query,
      clearSearchQuery: query == null || query.isEmpty,
    );
    debugPrint('[Custom Markers Filter] Search query: $query');
  }

  /// Set hunt ID filter
  void setHuntFilter(String? huntId) {
    state = state.copyWith(
      huntIdFilter: huntId,
      clearHuntIdFilter: huntId == null,
    );
    debugPrint('[Custom Markers Filter] Hunt filter: $huntId');
  }

  /// Clear hunt filter
  void clearHuntFilter() {
    state = state.copyWith(clearHuntIdFilter: true);
    debugPrint('[Custom Markers Filter] Cleared hunt filter');
  }

  /// Reset filter to defaults
  void reset() {
    state = CustomMarkerFilter.defaultFilter;
    debugPrint('[Custom Markers Filter] Reset to defaults');
  }
}

/// Notifier for managing custom marker CRUD operations
///
/// This notifier is used to trigger marker creation, updates, and deletion
/// with proper state management and provider invalidation.
class CustomMarkerOperationsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  final CustomMarkerService _service = CustomMarkerService();

  /// Create a new custom marker
  Future<CustomMarker?> createMarker({
    required double latitude,
    required double longitude,
    required String name,
    required CustomMarkerCategory category,
    String? notes,
    int? colorArgb,
    String? sessionId,
    String? huntId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final marker = await _service.createMarker(
        latitude: latitude,
        longitude: longitude,
        name: name,
        category: category,
        notes: notes,
        colorArgb: colorArgb,
        sessionId: sessionId,
        huntId: huntId,
      );

      // Invalidate providers to refresh data
      ref.invalidate(allCustomMarkersProvider);
      ref.invalidate(customMarkersCountProvider);
      ref.invalidate(customMarkersDataProvider); // Invalidate bounds-based cache

      state = const AsyncValue.data(null);
      return marker;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Update an existing marker
  Future<CustomMarker?> updateMarker(CustomMarker marker) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _service.updateMarker(marker);

      // Invalidate providers
      ref.invalidate(allCustomMarkersProvider);
      ref.invalidate(customMarkerByIdProvider(marker.id));
      ref.invalidate(customMarkersDataProvider); // Invalidate bounds-based cache

      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Delete a marker
  Future<bool> deleteMarker(String markerId) async {
    state = const AsyncValue.loading();
    try {
      await _service.deleteMarker(markerId);

      // Invalidate providers
      ref.invalidate(allCustomMarkersProvider);
      ref.invalidate(customMarkersCountProvider);
      ref.invalidate(customMarkersDataProvider); // Invalidate bounds-based cache

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Provider for custom marker operations (CRUD)
final customMarkerOperationsProvider =
    NotifierProvider<CustomMarkerOperationsNotifier, AsyncValue<void>>(
        CustomMarkerOperationsNotifier.new);

// ============================================================================
// SESSION MARKERS - Separate overlay for markers linked to a specific session
// Only shown in session playback/detail views
// ============================================================================

/// Provider for session markers overlay visibility
final sessionMarkersVisibilityProvider =
    NotifierProvider<SessionMarkersVisibilityNotifier, bool>(
        SessionMarkersVisibilityNotifier.new);

/// Provider for session markers category filter
final sessionMarkersCategoryFilterProvider =
    NotifierProvider<SessionMarkersCategoryFilterNotifier, Set<CustomMarkerCategory>>(
        SessionMarkersCategoryFilterNotifier.new);

/// Parameters for session markers data query
class SessionMarkersParams {
  const SessionMarkersParams({
    required this.bounds,
    required this.sessionId,
  });

  final LandBounds bounds;
  final String sessionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionMarkersParams &&
          runtimeType == other.runtimeType &&
          bounds == other.bounds &&
          sessionId == other.sessionId;

  @override
  int get hashCode => Object.hash(bounds, sessionId);
}

/// Provider for session markers data in current view
///
/// Returns custom markers linked to a specific session based on map bounds.
/// Only used in session playback/detail views.
final sessionMarkersDataProvider =
    FutureProvider.family<List<CustomMarker>, SessionMarkersParams>((ref, params) async {
  try {
    // Check visibility
    final isVisible = ref.watch(sessionMarkersVisibilityProvider);
    if (!isVisible) {
      return [];
    }

    // Get category filter
    final enabledCategories = ref.watch(sessionMarkersCategoryFilterProvider);
    if (enabledCategories.isEmpty) {
      return [];
    }

    // Query from SQLite - get all markers in bounds
    final service = CustomMarkerService();
    final markers = await service.getMarkersForBounds(
      north: params.bounds.north,
      south: params.bounds.south,
      east: params.bounds.east,
      west: params.bounds.west,
      categoryFilter: enabledCategories,
    );

    // Filter to only markers linked to this session
    final sessionMarkers = markers.where((m) => m.sessionId == params.sessionId).toList();

    debugPrint('[Session Markers] Found ${sessionMarkers.length} markers for session ${params.sessionId}');
    return sessionMarkers;
  } catch (e) {
    debugPrint('[Session Markers] Error fetching data: $e');
    return [];
  }
});

/// Notifier for session markers overlay visibility
class SessionMarkersVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true; // Default: visible

  void toggle() {
    state = !state;
    debugPrint('[Session Markers] Visibility toggled to: $state');
  }

  void set({required bool value}) {
    state = value;
    debugPrint('[Session Markers] Visibility set to: $state');
  }
}

/// Notifier for session markers category filter
class SessionMarkersCategoryFilterNotifier extends Notifier<Set<CustomMarkerCategory>> {
  @override
  Set<CustomMarkerCategory> build() => Set<CustomMarkerCategory>.from(CustomMarkerCategory.values);

  /// Toggle a category filter
  void toggleCategory(CustomMarkerCategory category) {
    final newCategories = Set<CustomMarkerCategory>.from(state);
    if (newCategories.contains(category)) {
      newCategories.remove(category);
    } else {
      newCategories.add(category);
    }
    state = newCategories;
    debugPrint('[Session Markers Filter] Toggled ${category.displayName}: ${newCategories.contains(category)}');
  }

  /// Enable all categories
  void enableAll() {
    state = Set<CustomMarkerCategory>.from(CustomMarkerCategory.values);
    debugPrint('[Session Markers Filter] Enabled all categories');
  }

  /// Disable all categories
  void disableAll() {
    state = {};
    debugPrint('[Session Markers Filter] Disabled all categories');
  }

  /// Check if a category is enabled
  bool isCategoryEnabled(CustomMarkerCategory category) => state.contains(category);

  /// Check if all categories are enabled
  bool get allEnabled => state.length == CustomMarkerCategory.values.length;

  /// Check if no categories are enabled
  bool get noneEnabled => state.isEmpty;
}
