import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/models/trail.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/core/services/app_settings_service.dart';
import 'package:obsession_tracker/core/services/bff_mapping_service.dart';

/// Provider for trails overlay visibility
final trailsOverlayVisibilityProvider =
    NotifierProvider<TrailsOverlayVisibilityNotifier, bool>(
        TrailsOverlayVisibilityNotifier.new);

/// Provider for trails overlay opacity
final trailsOverlayOpacityProvider =
    NotifierProvider<TrailsOverlayOpacityNotifier, double>(
        TrailsOverlayOpacityNotifier.new);

/// Provider for trail filter configuration
final trailFilterProvider =
    NotifierProvider<TrailFilterNotifier, TrailFilter>(TrailFilterNotifier.new);

/// Provider for trails data in current view - with subscription check
final trailsDataProvider =
    FutureProvider.family<List<Trail>, LandBounds>((ref, bounds) async {
  try {
    // Check subscription status before fetching trail data
    final isPremium = ref.watch(isPremiumProvider);

    if (!isPremium) {
      // Free tier users don't get trail data
      debugPrint('🚫 Trail data blocked - premium subscription required');
      return [];
    }

    // Fetch trails from BFF GraphQL API
    final trails = await BFFMappingService.instance.getTrailsData(
      northBound: bounds.north,
      southBound: bounds.south,
      eastBound: bounds.east,
      westBound: bounds.west,
      limit: 10000, // High limit to get all trails in view - matches land data limit
    );

    debugPrint('[Trails Provider] Fetched ${trails.length} trails for bounds');
    return trails;
  } catch (e) {
    debugPrint('[Trails Provider] Error fetching trails: $e');
    // Return empty list on error to avoid breaking the map
    return [];
  }
});

/// Notifier for trails overlay visibility with persistence via AppSettingsService
class TrailsOverlayVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Read from AppSettingsService which is already loaded at app startup
    final settings = AppSettingsService.instance.currentSettings;
    debugPrint('[Trails Overlay] Initial visibility from settings: ${settings.map.showTrailsOverlay}');
    return settings.map.showTrailsOverlay;
  }

  Future<void> _persistState() async {
    try {
      final settings = AppSettingsService.instance.currentSettings;
      await AppSettingsService.instance.updateMapSettings(
        settings.map.copyWith(showTrailsOverlay: state),
      );
    } catch (e) {
      debugPrint('[Trails Overlay] Error persisting state: $e');
    }
  }

  void toggle() {
    state = !state;
    debugPrint('[Trails Overlay] Visibility toggled to: $state');
    _persistState();
  }

  void set({required bool value}) {
    state = value;
    debugPrint('[Trails Overlay] Visibility set to: $state');
    _persistState();
  }
}

/// Notifier for trails overlay opacity
class TrailsOverlayOpacityNotifier extends Notifier<double> {
  @override
  double build() => 0.8; // Initial value: 80% opacity

  void setOpacity(double value) {
    state = value.clamp(0.0, 1.0);
    debugPrint('[Trails Overlay] Opacity set to: $state');
  }
}

/// Notifier for trail filter configuration
class TrailFilterNotifier extends Notifier<TrailFilter> {
  @override
  TrailFilter build() => const TrailFilter();

  /// Toggle a trail source filter
  void toggleSource(String source) {
    state = state.toggleSource(source);
    debugPrint('[Trail Filter] Toggled source $source: ${state.enabledSources}');
  }

  /// Toggle a trail type filter
  void toggleType(String type) {
    state = state.toggleType(type);
    debugPrint('[Trail Filter] Toggled type $type: ${state.enabledTypes}');
  }

  /// Enable all sources
  void enableAllSources() {
    state = state.enableAllSources();
    debugPrint('[Trail Filter] Enabled all sources');
  }

  /// Enable all types
  void enableAllTypes() {
    state = state.enableAllTypes();
    debugPrint('[Trail Filter] Enabled all types');
  }

  /// Disable all types (hide all trails)
  void disableAllTypes() {
    state = TrailFilter(
      enabledTypes: const {},
      enabledSources: state.enabledSources,
    );
    debugPrint('[Trail Filter] Disabled all types');
  }

  /// Reset to default (all enabled)
  void reset() {
    state = const TrailFilter();
    debugPrint('[Trail Filter] Reset to default');
  }
}
