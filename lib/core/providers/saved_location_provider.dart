import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/saved_location.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/map_search_service.dart';

/// State for saved locations management.
@immutable
class SavedLocationState {
  const SavedLocationState({
    this.locations = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<SavedLocation> locations;
  final bool isLoading;
  final String? errorMessage;

  SavedLocationState copyWith({
    List<SavedLocation>? locations,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) =>
      SavedLocationState(
        locations: locations ?? this.locations,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedLocationState &&
          runtimeType == other.runtimeType &&
          locations == other.locations &&
          isLoading == other.isLoading &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      locations.hashCode ^ isLoading.hashCode ^ errorMessage.hashCode;
}

/// Notifier for managing saved locations.
class SavedLocationNotifier extends Notifier<SavedLocationState> {
  @override
  SavedLocationState build() {
    Future.microtask(loadLocations);
    return const SavedLocationState();
  }

  /// Load all saved locations from the database.
  Future<void> loadLocations() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final db = DatabaseService();
      final locations = await db.getSavedLocations();
      state = state.copyWith(locations: locations, isLoading: false);
    } catch (e) {
      debugPrint('Error loading saved locations: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load saved locations: $e',
      );
    }
  }

  /// Save a search result as a saved location.
  ///
  /// The [result] must have non-null coordinates.
  Future<void> addFromSearchResult(MapSearchResult result) async {
    if (result.latitude == null || result.longitude == null) return;
    try {
      final location = SavedLocation.fromSearchResult(result);
      final db = DatabaseService();
      await db.insertSavedLocation(location);
      state = state.copyWith(
        locations: [...state.locations, location],
        clearError: true,
      );
    } catch (e) {
      debugPrint('Error saving location: $e');
      state = state.copyWith(errorMessage: 'Failed to save location: $e');
    }
  }

  /// Delete a saved location by ID.
  Future<void> deleteLocation(String id) async {
    try {
      final db = DatabaseService();
      await db.deleteSavedLocation(id);
      state = state.copyWith(
        locations: state.locations.where((l) => l.id != id).toList(),
        clearError: true,
      );
    } catch (e) {
      debugPrint('Error deleting saved location: $e');
      state = state.copyWith(errorMessage: 'Failed to delete location: $e');
    }
  }

  /// Delete a saved location by display name.
  Future<void> deleteByDisplayName(String displayName) async {
    final match = state.locations
        .where((l) => l.displayName == displayName)
        .firstOrNull;
    if (match != null) await deleteLocation(match.id);
  }

  /// Toggle favorite status for a saved location.
  Future<void> toggleFavorite(String id) async {
    try {
      final location =
          state.locations.where((l) => l.id == id).firstOrNull;
      if (location == null) return;
      final updated = location.copyWith(
        isFavorite: !location.isFavorite,
        updatedAt: DateTime.now(),
      );
      final db = DatabaseService();
      await db.updateSavedLocation(updated);
      state = state.copyWith(
        locations: state.locations
            .map((l) => l.id == id ? updated : l)
            .toList(),
        clearError: true,
      );
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      state = state.copyWith(errorMessage: 'Failed to update location: $e');
    }
  }
}

/// Provider for saved locations state.
final savedLocationProvider =
    NotifierProvider<SavedLocationNotifier, SavedLocationState>(
  SavedLocationNotifier.new,
);

/// Check if a location with the given display name is already saved.
final isLocationSavedProvider = Provider.family<bool, String>(
  (ref, displayName) {
    final locations = ref.watch(savedLocationProvider).locations;
    return locations.any((loc) => loc.displayName == displayName);
  },
);
