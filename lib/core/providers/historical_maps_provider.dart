import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/services/historical_maps_service.dart';
import 'package:obsession_tracker/core/services/quadrangle_download_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State for a single historical map overlay
class HistoricalMapState {
  const HistoricalMapState({
    required this.stateCode,
    required this.layerId,
    required this.layerName,
    required this.filePath,
    this.isEnabled = false,
    this.opacity = 0.7,
    this.era,
    this.bounds,
  });

  final String stateCode;
  final String layerId;
  final String layerName;
  final String filePath;
  final bool isEnabled;
  final double opacity;
  final String? era;
  final HistoricalMapBounds? bounds;

  String get key => '${stateCode}_$layerId';

  HistoricalMapState copyWith({
    bool? isEnabled,
    double? opacity,
    HistoricalMapBounds? bounds,
  }) {
    return HistoricalMapState(
      stateCode: stateCode,
      layerId: layerId,
      layerName: layerName,
      filePath: filePath,
      isEnabled: isEnabled ?? this.isEnabled,
      opacity: opacity ?? this.opacity,
      era: era,
      bounds: bounds ?? this.bounds,
    );
  }

  factory HistoricalMapState.fromDownloadedMap(DownloadedHistoricalMap map) {
    return HistoricalMapState(
      stateCode: map.stateCode,
      layerId: map.layerId,
      layerName: map.name,
      filePath: map.filePath,
      era: map.era,
    );
  }
}

/// State for all historical map overlays
class HistoricalMapsState {
  const HistoricalMapsState({
    this.maps = const {},
    this.isLoading = false,
    this.pendingZoomBounds,
  });

  /// Map of state_layerId -> HistoricalMapState
  final Map<String, HistoricalMapState> maps;
  final bool isLoading;

  /// Bounds to zoom to after enabling a historical map (cleared after zoom)
  final HistoricalMapBounds? pendingZoomBounds;

  /// Get all enabled overlays
  List<HistoricalMapState> get enabledMaps =>
      maps.values.where((m) => m.isEnabled).toList();

  /// Check if any historical map is enabled
  bool get hasEnabledMaps => maps.values.any((m) => m.isEnabled);

  /// Get overlays for a specific state
  List<HistoricalMapState> getMapsForState(String stateCode) =>
      maps.values.where((m) => m.stateCode == stateCode.toUpperCase()).toList();

  HistoricalMapsState copyWith({
    Map<String, HistoricalMapState>? maps,
    bool? isLoading,
    HistoricalMapBounds? pendingZoomBounds,
    bool clearPendingZoom = false,
  }) {
    return HistoricalMapsState(
      maps: maps ?? this.maps,
      isLoading: isLoading ?? this.isLoading,
      pendingZoomBounds: clearPendingZoom ? null : (pendingZoomBounds ?? this.pendingZoomBounds),
    );
  }
}

/// Provider for managing historical map overlay state
final historicalMapsProvider =
    NotifierProvider<HistoricalMapsNotifier, HistoricalMapsState>(
  HistoricalMapsNotifier.new,
);

/// Notifier for managing historical map overlays
class HistoricalMapsNotifier extends Notifier<HistoricalMapsState> {
  static const String _enabledKey = 'historical_maps_enabled';
  static const String _opacityKey = 'historical_maps_opacity';

  @override
  HistoricalMapsState build() {
    _loadDownloadedMaps();
    return const HistoricalMapsState(isLoading: true);
  }

  /// Load all downloaded historical maps (legacy + quadrangles)
  Future<void> _loadDownloadedMaps() async {
    try {
      final legacyService = HistoricalMapsService.instance;
      final quadService = QuadrangleDownloadService.instance;

      // Initialize services
      await legacyService.initialize();
      await quadService.initialize();

      // Load legacy downloaded maps
      final legacyMaps = await legacyService.getDownloadedMaps();

      // Load downloaded quadrangles
      final downloadedQuads = quadService.getDownloadedQuadrangles();

      final prefs = await SharedPreferences.getInstance();
      final enabledList = prefs.getStringList(_enabledKey) ?? [];
      final opacityMap = _loadOpacityMap(prefs);
      debugPrint('🗺️ Loaded enabled list from prefs: $enabledList');

      final maps = <String, HistoricalMapState>{};

      // Add legacy maps
      for (final map in legacyMaps) {
        final key = '${map.stateCode}_${map.layerId}';
        maps[key] = HistoricalMapState(
          stateCode: map.stateCode,
          layerId: map.layerId,
          layerName: map.name,
          filePath: map.filePath,
          era: map.era,
          isEnabled: enabledList.contains(key),
          opacity: opacityMap[key] ?? 0.7,
        );
      }

      // Add downloaded quadrangles
      // Use layerId format: quad_{eraId}_{quadId} to match what _handleDownloadAvailableMap uses
      for (final quad in downloadedQuads) {
        final layerId = 'quad_${quad.eraId}_${quad.quadId}';
        final key = '${quad.stateCode}_$layerId';
        final isEnabled = enabledList.contains(key);

        // Convert QuadrangleBounds to HistoricalMapBounds
        final bounds = HistoricalMapBounds(
          west: quad.bounds.west,
          south: quad.bounds.south,
          east: quad.bounds.east,
          north: quad.bounds.north,
          centerLng: quad.bounds.centerLng,
          centerLat: quad.bounds.centerLat,
        );

        debugPrint('🗺️ Loading quadrangle: $key, enabled=$isEnabled, file=${quad.filePath}');
        maps[key] = HistoricalMapState(
          stateCode: quad.stateCode,
          layerId: layerId,
          layerName: '${quad.name} (${quad.year})',
          filePath: quad.filePath,
          era: quad.eraId,
          isEnabled: isEnabled,
          opacity: opacityMap[key] ?? 0.7,
          bounds: bounds,
        );
      }

      state = state.copyWith(maps: maps, isLoading: false);
      final enabledCount = maps.values.where((m) => m.isEnabled).length;
      debugPrint('🗺️ Loaded ${maps.length} historical maps (${legacyMaps.length} legacy + ${downloadedQuads.length} quadrangles, $enabledCount enabled)');
    } catch (e) {
      debugPrint('❌ Error loading historical maps: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Refresh the list of downloaded maps
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadDownloadedMaps();
  }

  /// Toggle a historical map overlay on/off
  /// When enabling, loads bounds and triggers zoom to coverage
  Future<void> toggleMap(String stateCode, String layerId) async {
    debugPrint('🗺️ toggleMap called: stateCode=$stateCode, layerId=$layerId');
    final key = '${stateCode.toUpperCase()}_$layerId';
    final currentMap = state.maps[key];
    if (currentMap == null) {
      debugPrint('🗺️ toggleMap: map not found for key $key');
      return;
    }

    final newEnabled = !currentMap.isEnabled;
    debugPrint('🗺️ toggleMap: newEnabled=$newEnabled (was ${currentMap.isEnabled})');
    final updatedMaps = Map<String, HistoricalMapState>.from(state.maps);

    HistoricalMapBounds? zoomBounds;

    if (newEnabled) {
      // First check if map already has bounds (e.g., quadrangles loaded from QuadrangleDownloadService)
      // If not, try loading from HistoricalMapsService (for legacy maps)
      HistoricalMapBounds? bounds = currentMap.bounds;
      if (bounds == null) {
        debugPrint('🗺️ toggleMap: no cached bounds, loading from MBTiles...');
        final service = HistoricalMapsService.instance;
        bounds = await service.getBoundsForLayer(stateCode, layerId);
        debugPrint('🗺️ toggleMap: getBoundsForLayer returned: $bounds');
      } else {
        debugPrint('🗺️ toggleMap: using cached bounds from map state');
      }

      if (bounds != null) {
        // Update map state with bounds
        updatedMaps[key] = currentMap.copyWith(isEnabled: true, bounds: bounds);
        zoomBounds = bounds;
        debugPrint('🗺️ Historical map $key enabled, will zoom to bounds: $bounds');
      } else {
        updatedMaps[key] = currentMap.copyWith(isEnabled: true);
        debugPrint('🗺️ Historical map $key enabled (no bounds available)');
      }
    } else {
      updatedMaps[key] = currentMap.copyWith(isEnabled: false);
      debugPrint('🗺️ Historical map $key disabled');
    }

    debugPrint('🗺️ toggleMap: setting state with pendingZoomBounds=$zoomBounds');
    state = state.copyWith(maps: updatedMaps, pendingZoomBounds: zoomBounds);

    // Persist enabled state
    await _saveEnabledState();
  }

  /// Enable a specific historical map overlay
  Future<void> enableMap(String stateCode, String layerId) async {
    final key = '${stateCode.toUpperCase()}_$layerId';
    final currentMap = state.maps[key];
    if (currentMap == null || currentMap.isEnabled) return;

    final updatedMaps = Map<String, HistoricalMapState>.from(state.maps);
    updatedMaps[key] = currentMap.copyWith(isEnabled: true);
    state = state.copyWith(maps: updatedMaps);

    await _saveEnabledState();
    debugPrint('🗺️ Historical map $key enabled');
  }

  /// Enable a historical map and zoom to its coverage area
  /// Used after downloading a new map to automatically show it
  ///
  /// For quadrangles, pass the [bounds] parameter since HistoricalMapsService
  /// doesn't track quadrangles.
  Future<void> enableMapWithZoom(
    String stateCode,
    String layerId, {
    HistoricalMapBounds? bounds,
  }) async {
    debugPrint('🗺️ enableMapWithZoom: stateCode=$stateCode, layerId=$layerId, hasBounds=${bounds != null}');
    final key = '${stateCode.toUpperCase()}_$layerId';
    final currentMap = state.maps[key];
    if (currentMap == null) {
      debugPrint('🗺️ enableMapWithZoom: map not found for key $key');
      debugPrint('🗺️ enableMapWithZoom: available keys: ${state.maps.keys.toList()}');
      return;
    }

    // First check if bounds was provided as parameter
    // Then check if map already has bounds (e.g., loaded from QuadrangleDownloadService)
    // Finally, try loading from HistoricalMapsService (for legacy maps)
    HistoricalMapBounds? zoomBounds = bounds ?? currentMap.bounds;
    if (zoomBounds == null) {
      final service = HistoricalMapsService.instance;
      zoomBounds = await service.getBoundsForLayer(stateCode, layerId);
    }
    debugPrint('🗺️ enableMapWithZoom: zoomBounds=$zoomBounds');

    final updatedMaps = Map<String, HistoricalMapState>.from(state.maps);
    if (zoomBounds != null) {
      updatedMaps[key] = currentMap.copyWith(isEnabled: true, bounds: zoomBounds);
      state = state.copyWith(maps: updatedMaps, pendingZoomBounds: zoomBounds);
      debugPrint('🗺️ Historical map $key enabled with zoom to bounds');
    } else {
      updatedMaps[key] = currentMap.copyWith(isEnabled: true);
      state = state.copyWith(maps: updatedMaps);
      debugPrint('🗺️ Historical map $key enabled (no bounds for zoom)');
    }

    await _saveEnabledState();
  }

  /// Disable a specific historical map overlay
  Future<void> disableMap(String stateCode, String layerId) async {
    final key = '${stateCode.toUpperCase()}_$layerId';
    final currentMap = state.maps[key];
    if (currentMap == null || !currentMap.isEnabled) return;

    final updatedMaps = Map<String, HistoricalMapState>.from(state.maps);
    updatedMaps[key] = currentMap.copyWith(isEnabled: false);
    state = state.copyWith(maps: updatedMaps);

    await _saveEnabledState();
    debugPrint('🗺️ Historical map $key disabled');
  }

  /// Enable all historical map overlays
  Future<void> enableAll() async {
    final updatedMaps = <String, HistoricalMapState>{};
    for (final entry in state.maps.entries) {
      updatedMaps[entry.key] = entry.value.copyWith(isEnabled: true);
    }
    state = state.copyWith(maps: updatedMaps);
    await _saveEnabledState();
    debugPrint('🗺️ All historical maps enabled');
  }

  /// Disable all historical map overlays
  Future<void> disableAll() async {
    final updatedMaps = <String, HistoricalMapState>{};
    for (final entry in state.maps.entries) {
      updatedMaps[entry.key] = entry.value.copyWith(isEnabled: false);
    }
    state = state.copyWith(maps: updatedMaps);
    await _saveEnabledState();
    debugPrint('🗺️ All historical maps disabled');
  }

  /// Enable or disable all maps for a specific era
  Future<void> toggleEra(String eraId, bool enabled) async {
    final updatedMaps = <String, HistoricalMapState>{};
    for (final entry in state.maps.entries) {
      if (entry.value.era == eraId) {
        updatedMaps[entry.key] = entry.value.copyWith(isEnabled: enabled);
      } else {
        updatedMaps[entry.key] = entry.value;
      }
    }
    state = state.copyWith(maps: updatedMaps);
    await _saveEnabledState();
    debugPrint('🗺️ Era $eraId ${enabled ? "enabled" : "disabled"}');
  }

  /// Set opacity for all maps in a specific era
  Future<void> setEraOpacity(String eraId, double opacity) async {
    final clampedOpacity = opacity.clamp(0.0, 1.0);
    final updatedMaps = <String, HistoricalMapState>{};
    for (final entry in state.maps.entries) {
      if (entry.value.era == eraId) {
        updatedMaps[entry.key] = entry.value.copyWith(opacity: clampedOpacity);
        await _saveOpacity(entry.key, clampedOpacity);
      } else {
        updatedMaps[entry.key] = entry.value;
      }
    }
    state = state.copyWith(maps: updatedMaps);
    debugPrint('🗺️ Era $eraId opacity set to $clampedOpacity');
  }

  /// Get maps grouped by era
  Map<String, List<HistoricalMapState>> get mapsByEra {
    final result = <String, List<HistoricalMapState>>{};
    for (final entry in state.maps.entries) {
      final eraId = entry.value.era ?? 'unknown';
      result.putIfAbsent(eraId, () => []).add(entry.value);
    }
    return result;
  }

  /// Set opacity for a historical map overlay
  Future<void> setOpacity(String stateCode, String layerId, double opacity) async {
    final key = '${stateCode.toUpperCase()}_$layerId';
    final currentMap = state.maps[key];
    if (currentMap == null) return;

    final clampedOpacity = opacity.clamp(0.0, 1.0);
    final updatedMaps = Map<String, HistoricalMapState>.from(state.maps);
    updatedMaps[key] = currentMap.copyWith(opacity: clampedOpacity);
    state = state.copyWith(maps: updatedMaps);

    await _saveOpacity(key, clampedOpacity);
    debugPrint('🗺️ Historical map $key opacity set to $clampedOpacity');
  }

  /// Check if a specific map is enabled
  bool isMapEnabled(String stateCode, String layerId) {
    final key = '${stateCode.toUpperCase()}_$layerId';
    return state.maps[key]?.isEnabled ?? false;
  }

  /// Get state for a specific map
  HistoricalMapState? getMapState(String stateCode, String layerId) {
    final key = '${stateCode.toUpperCase()}_$layerId';
    return state.maps[key];
  }

  /// Add a newly downloaded map to the state
  Future<void> addDownloadedMap(DownloadedHistoricalMap map) async {
    final key = '${map.stateCode}_${map.layerId}';
    final updatedMaps = Map<String, HistoricalMapState>.from(state.maps);
    updatedMaps[key] = HistoricalMapState.fromDownloadedMap(map);
    state = state.copyWith(maps: updatedMaps);
    debugPrint('🗺️ Added historical map to provider: $key');
  }

  /// Remove a deleted map from the state
  void removeMap(String stateCode, String layerId) {
    final key = '${stateCode.toUpperCase()}_$layerId';
    final updatedMaps = Map<String, HistoricalMapState>.from(state.maps);
    updatedMaps.remove(key);
    state = state.copyWith(maps: updatedMaps);
    debugPrint('🗺️ Removed historical map from provider: $key');
  }

  /// Clear pending zoom bounds after the map has zoomed
  void clearPendingZoom() {
    if (state.pendingZoomBounds != null) {
      state = state.copyWith(clearPendingZoom: true);
      debugPrint('🗺️ Cleared pending zoom bounds');
    }
  }

  /// Get bounds for a specific map (loads from MBTiles if not cached)
  Future<HistoricalMapBounds?> getBoundsForMap(String stateCode, String layerId) async {
    final key = '${stateCode.toUpperCase()}_$layerId';
    final mapState = state.maps[key];

    // Return cached bounds if available
    if (mapState?.bounds != null) {
      return mapState!.bounds;
    }

    // Load from MBTiles
    final service = HistoricalMapsService.instance;
    final bounds = await service.getBoundsForLayer(stateCode, layerId);

    // Cache in state if found
    if (bounds != null && mapState != null) {
      final updatedMaps = Map<String, HistoricalMapState>.from(state.maps);
      updatedMaps[key] = mapState.copyWith(bounds: bounds);
      state = state.copyWith(maps: updatedMaps);
    }

    return bounds;
  }

  Future<void> _saveEnabledState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabledList = state.maps.entries
          .where((e) => e.value.isEnabled)
          .map((e) => e.key)
          .toList();
      await prefs.setStringList(_enabledKey, enabledList);
      debugPrint('🗺️ Saved enabled state: $enabledList');
    } catch (e) {
      debugPrint('❌ Error saving enabled state: $e');
    }
  }

  Future<void> _saveOpacity(String key, double opacity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('${_opacityKey}_$key', opacity);
    } catch (e) {
      debugPrint('❌ Error saving opacity: $e');
    }
  }

  Map<String, double> _loadOpacityMap(SharedPreferences prefs) {
    final result = <String, double>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('${_opacityKey}_')) {
        final mapKey = key.substring('${_opacityKey}_'.length);
        result[mapKey] = prefs.getDouble(key) ?? 0.7;
      }
    }
    return result;
  }
}
