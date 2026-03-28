import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/map_overlay.dart';
import 'package:obsession_tracker/core/services/historical_maps_service.dart';
import 'package:obsession_tracker/core/services/mbtiles_tile_server.dart';

/// Renders historical map raster overlays from local MBTiles files
///
/// This overlay displays historical topographic maps (GLO survey plats, early USGS topos)
/// as raster tile layers that can be toggled on/off with adjustable opacity.
///
/// The MBTiles files must be downloaded first via [HistoricalMapsService].
class HistoricalMapOverlay extends MapOverlay {
  HistoricalMapOverlay({
    required this.stateCode,
    required this.layerId,
    required this.layerName,
    required this.filePath,
    this.opacity = 0.7,
    this.era,
  });

  /// Two-letter state code (e.g., 'WY', 'CO')
  final String stateCode;

  /// Layer identifier (e.g., 'maps_survey', 'maps_early_topo')
  final String layerId;

  /// Human-readable layer name for display
  final String layerName;

  /// Absolute path to the local MBTiles file
  final String filePath;

  /// Opacity of the overlay (0.0 - 1.0)
  final double opacity;

  /// Era covered by this historical map (e.g., '1850-1890')
  final String? era;

  /// Source ID for the raster tiles
  String get sourceId => 'historical-map-source-$stateCode-$layerId';

  /// Layer ID for the raster tiles
  String get rasterLayerId => 'historical-map-layer-$stateCode-$layerId';

  bool _isVisible = true;
  bool _isLoaded = false;

  @override
  String get id => 'historical-map-$stateCode-$layerId';

  @override
  bool get isVisible => _isVisible;

  /// Check if the MBTiles file exists on disk
  bool get fileExists => File(filePath).existsSync();

  /// Create overlay from a downloaded historical map info object
  factory HistoricalMapOverlay.fromDownloadedMap(
    DownloadedHistoricalMap map, {
    double opacity = 0.7,
  }) {
    return HistoricalMapOverlay(
      stateCode: map.stateCode,
      layerId: map.layerId,
      layerName: map.name,
      filePath: map.filePath,
      opacity: opacity,
      era: map.era,
    );
  }

  /// Unique ID for this MBTiles file in the tile server
  String get mbtilesServerId => '${stateCode.toLowerCase()}_$layerId';

  @override
  Future<void> load(MapboxMap map) async {
    if (_isLoaded) {
      debugPrint('🗺️ HistoricalMapOverlay: Already loaded, skipping');
      return;
    }

    if (!fileExists) {
      debugPrint('⚠️ HistoricalMapOverlay: MBTiles file not found at $filePath');
      return;
    }

    try {
      debugPrint('🗺️ ===== LOADING HISTORICAL MAP OVERLAY =====');
      debugPrint('🗺️ Layer name: $layerName');
      debugPrint('🗺️ Layer ID: $layerId');
      debugPrint('🗺️ State code: $stateCode');
      debugPrint('🗺️ MBTiles server ID: $mbtilesServerId');
      debugPrint('🗺️ File path: $filePath');
      debugPrint('🗺️ Source ID: $sourceId');
      debugPrint('🗺️ Raster layer ID: $rasterLayerId');
      debugPrint('🗺️ Opacity: $opacity');

      // Clean up any stale layers/sources first
      await _removeExistingLayersAndSource(map);

      // Start the local tile server if not running
      final tileServer = MBTilesTileServer.instance;
      if (!tileServer.isRunning) {
        debugPrint('🌐 Starting MBTiles tile server...');
        await tileServer.start();
      }

      // Register this MBTiles file with the tile server
      debugPrint('🗺️ Registering MBTiles with ID: $mbtilesServerId');
      await tileServer.registerMBTiles(mbtilesServerId, filePath);
      debugPrint('🗺️ Registration complete. Registered IDs: ${tileServer.getRegisteredIds()}');

      // Get the tile URL template from the tile server
      final tileUrlTemplate = tileServer.getTileUrlTemplate(mbtilesServerId);
      debugPrint('🗺️ ===== TILE URL TEMPLATE =====');
      debugPrint('🗺️ URL: $tileUrlTemplate');
      debugPrint('🗺️ Server base URL: ${tileServer.baseUrl}');
      debugPrint('🗺️ Server running: ${tileServer.isRunning}');

      // Add raster source using typed RasterSource class
      // The tile server serves tiles at http://127.0.0.1:{port}/{id}/{z}/{x}/{y}.png
      debugPrint('🗺️ ===== ADDING RASTER SOURCE =====');
      debugPrint('🗺️ Source ID: $sourceId');
      debugPrint('🗺️ Tile URL: $tileUrlTemplate');

      // Read actual maxzoom from MBTiles metadata so Mapbox overzooms correctly.
      // Setting maxzoom to the actual tile data limit tells Mapbox to stop
      // requesting new tiles beyond that level and instead scale up (overzoom)
      // the last available tiles. This keeps the overlay visible at any zoom.
      final actualMaxZoom = await tileServer.getMaxZoom(mbtilesServerId) ?? 16;
      debugPrint('🗺️ MBTiles actual maxzoom: $actualMaxZoom');

      await map.style.addSource(
        RasterSource(
          id: sourceId,
          tiles: [tileUrlTemplate],
          tileSize: 256,
          scheme: Scheme.XYZ,
          maxzoom: actualMaxZoom.toDouble(),
        ),
      );
      debugPrint('🗺️ ✅ Raster source added successfully: $sourceId (maxzoom: $actualMaxZoom)');

      // Add raster layer using typed RasterLayer class
      debugPrint('🗺️ ===== ADDING RASTER LAYER =====');
      debugPrint('🗺️ Layer ID: $rasterLayerId');
      debugPrint('🗺️ Opacity: $opacity');

      await map.style.addLayer(
        RasterLayer(
          id: rasterLayerId,
          sourceId: sourceId,
          rasterOpacity: opacity,
        ),
      );
      debugPrint('🗺️ ✅ Raster layer added successfully: $rasterLayerId');

      _isLoaded = true;
      debugPrint('✅ HistoricalMapOverlay loaded: $layerName');
    } catch (e) {
      debugPrint('❌ HistoricalMapOverlay load error: $e');
      _isLoaded = false;
    }
  }

  @override
  Future<void> update(MapboxMap map) async {
    // For raster overlays, update is primarily about opacity changes
    // The tiles themselves don't change
    if (!_isLoaded) {
      await load(map);
      return;
    }

    try {
      await map.style.setStyleLayerProperty(
        rasterLayerId,
        'raster-opacity',
        _isVisible ? opacity : 0.0,
      );
      debugPrint('✅ HistoricalMapOverlay updated: $layerName (opacity: $opacity)');
    } catch (e) {
      debugPrint('❌ HistoricalMapOverlay update error: $e');
    }
  }

  @override
  Future<void> unload(MapboxMap map) async {
    try {
      await _removeExistingLayersAndSource(map);

      // NOTE: We intentionally do NOT unregister from the tile server here.
      // The database connection should remain open because:
      // 1. Mapbox may still have pending tile requests in flight
      // 2. The overlay may be reloaded shortly (e.g., style change)
      // 3. Opening SQLite databases is relatively expensive
      // The tile server will clean up all databases when it stops.

      _isLoaded = false;
      debugPrint('✅ HistoricalMapOverlay unloaded: $layerName');
    } catch (e) {
      debugPrint('❌ HistoricalMapOverlay unload error: $e');
    }
  }

  @override
  Future<void> setVisibility(MapboxMap map, {required bool visible}) async {
    _isVisible = visible;

    if (!_isLoaded) {
      if (visible) {
        await load(map);
      }
      return;
    }

    try {
      await map.style.setStyleLayerProperty(
        rasterLayerId,
        'visibility',
        visible ? 'visible' : 'none',
      );
      debugPrint('🗺️ HistoricalMapOverlay visibility: $visible');
    } catch (e) {
      debugPrint('❌ HistoricalMapOverlay visibility error: $e');
    }
  }

  /// Set the opacity of the overlay (0.0 - 1.0)
  Future<void> setOpacity(MapboxMap map, double newOpacity) async {
    if (!_isLoaded || !_isVisible) return;

    try {
      await map.style.setStyleLayerProperty(
        rasterLayerId,
        'raster-opacity',
        newOpacity.clamp(0.0, 1.0),
      );
      debugPrint('🗺️ HistoricalMapOverlay opacity set to: $newOpacity');
    } catch (e) {
      debugPrint('❌ HistoricalMapOverlay setOpacity error: $e');
    }
  }

  /// Remove existing layers and source to prevent conflicts
  Future<void> _removeExistingLayersAndSource(MapboxMap map) async {
    try {
      await map.style.removeStyleLayer(rasterLayerId);
    } catch (_) {
      // Layer doesn't exist yet, ignore
    }
    try {
      await map.style.removeStyleSource(sourceId);
    } catch (_) {
      // Source doesn't exist yet, ignore
    }
  }

  /// Move this overlay below another layer (for proper z-ordering)
  Future<void> moveBelow(MapboxMap map, String belowLayerId) async {
    if (!_isLoaded) return;

    try {
      // Remove and re-add the layer at the new position
      await map.style.removeStyleLayer(rasterLayerId);

      await map.style.addLayerAt(
        RasterLayer(
          id: rasterLayerId,
          sourceId: sourceId,
          rasterOpacity: _isVisible ? opacity : 0.0,
        ),
        LayerPosition(below: belowLayerId),
      );

      debugPrint('🗺️ HistoricalMapOverlay moved below $belowLayerId');
    } catch (e) {
      debugPrint('❌ HistoricalMapOverlay moveBelow error: $e');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoricalMapOverlay &&
          runtimeType == other.runtimeType &&
          stateCode == other.stateCode &&
          layerId == other.layerId &&
          filePath == other.filePath;

  @override
  int get hashCode => stateCode.hashCode ^ layerId.hashCode ^ filePath.hashCode;

  @override
  String toString() =>
      'HistoricalMapOverlay($stateCode-$layerId: $layerName, era: $era)';
}
