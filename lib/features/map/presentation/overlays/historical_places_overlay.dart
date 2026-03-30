import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/historical_place.dart';
import 'package:obsession_tracker/core/models/map_overlay.dart';
import 'package:obsession_tracker/core/services/historical_place_icon_service.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/map_text_style.dart';

/// Renders GNIS places as point markers on the map
///
/// Displays all place types from USGS GNIS data with type-specific icons
/// and colors. Types are loaded dynamically from the data, so new
/// types can be added without app updates.
///
/// Uses:
/// - SymbolLayer with custom marker images (emoji on colored circle)
/// - SymbolLayer for place name labels
class HistoricalPlacesOverlay extends MapOverlay {
  HistoricalPlacesOverlay({
    required this.places,
    this.onPlaceTap,
  });

  final List<HistoricalPlace> places;
  final ValueChanged<HistoricalPlace>? onPlaceTap;

  static const String sourceId = 'historical-places-source';

  // Cluster layer IDs
  static const String clusterCircleLayerId = 'hist-cluster-circle';
  static const String clusterCountLayerId = 'hist-cluster-count';

  // SymbolLayer for unclustered points with custom marker icons
  static const String unclusteredIconLayerId = 'hist-unclustered-icon';
  static const String unclusteredLabelLayerId = 'hist-unclustered-label';

  /// Icon service for generating marker images
  static final _iconService = HistoricalPlaceIconService.instance;

  @override
  String get id => 'historical-places-overlay';

  bool _isVisible = true;

  @override
  bool get isVisible => _isVisible;

  /// Get all layer IDs for this overlay
  List<String> get allLayerIds => [
        clusterCircleLayerId,
        clusterCountLayerId,
        unclusteredIconLayerId,
        unclusteredLabelLayerId,
      ];

  @override
  Future<void> load(MapboxMap map) async {
    if (places.isEmpty) {
      debugPrint('[WARNING] HistoricalPlacesOverlay: No places to display');
      return;
    }

    try {
      // Remove existing layers/source if they exist
      await _safeUnload(map);

      // Create GeoJSON FeatureCollection from places
      final features = places.map((place) => place.toGeoJsonFeature()).toList();

      // Get unique type codes from the data
      final typeCodes = places.map((p) => p.typeCode).toSet();
      debugPrint('[INFO] HistoricalPlacesOverlay: ${typeCodes.length} unique types in ${places.length} places');

      final geoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };

      // Add GeoJSON source with clustering enabled
      await map.style.addSource(
        GeoJsonSource(
          id: sourceId,
          data: jsonEncode(geoJson),
          cluster: true,
          clusterRadius: 50,
          clusterMaxZoom: 14,
        ),
      );

      // Add cluster circle layer (shows when points are clustered)
      await map.style.addLayer(
        CircleLayer(
          id: clusterCircleLayerId,
          sourceId: sourceId,
          circleColor: 0xFF6B4C9A, // Purple for clusters
          circleRadius: 18.0,
          circleStrokeWidth: 3.0,
          circleStrokeColor: 0xFFFFFFFF,
          circleOpacity: 1.0,
          filter: ['has', 'point_count'],
        ),
      );

      // Add cluster count label
      await map.style.addLayer(
        SymbolLayer(
          id: clusterCountLayerId,
          sourceId: sourceId,
          textField: '{point_count_abbreviated}',
          textFont: MapTextStyle.boldFont,
          textSize: MapTextStyle.clusterCountSize,
          textColor: MapTextStyle.textColor,
          textHaloColor: MapTextStyle.textHaloColor,
          textHaloWidth: MapTextStyle.textHaloWidth,
          textHaloBlur: MapTextStyle.textHaloBlur,
          textAllowOverlap: true,
          textOpacity: 1.0,
          filter: ['has', 'point_count'],
        ),
      );

      // Register marker icons for all place types present in the data
      await _iconService.registerImagesForTypes(map, typeCodes);

      // Add SymbolLayer for unclustered points with custom marker icons
      await map.style.addLayer(
        SymbolLayer(
          id: unclusteredIconLayerId,
          sourceId: sourceId,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: IconAnchor.CENTER,
          iconSize: 0.4, // Smaller icons for cleaner map (Zillow-style)
          filter: ['!', ['has', 'point_count']],
        ),
      );

      // Set icon-image using match expression for type-specific icons
      await map.style.setStyleLayerProperty(
        unclusteredIconLayerId,
        'icon-image',
        _iconService.buildIconImageExpression(typeCodes),
      );

      // Add symbol layer for place name labels (visible when zoomed in)
      await map.style.addLayer(
        SymbolLayer(
          id: unclusteredLabelLayerId,
          sourceId: sourceId,
          textField: '{name}',
          textFont: MapTextStyle.labelFont,
          textSize: MapTextStyle.markerLabelSize,
          textColor: MapTextStyle.textColor,
          textHaloColor: MapTextStyle.textHaloColor,
          textHaloWidth: MapTextStyle.textHaloWidth,
          textHaloBlur: MapTextStyle.textHaloBlur,
          textLetterSpacing: MapTextStyle.textLetterSpacing,
          textAnchor: TextAnchor.TOP,
          textOffset: [0, 0.8], // Offset below the icon
          textMaxWidth: MapTextStyle.textMaxWidth,
          minZoom: 14.0, // Only show labels when zoomed in enough
          filter: ['!', ['has', 'point_count']],
        ),
      );

      debugPrint('[SUCCESS] HistoricalPlacesOverlay loaded: ${places.length} places with custom icons');
    } catch (e) {
      debugPrint('[ERROR] HistoricalPlacesOverlay load error: $e');
    }
  }

  @override
  Future<void> update(MapboxMap map) async {
    if (places.isEmpty) {
      await unload(map);
      return;
    }

    try {
      // Update source data directly if possible, otherwise reload
      final features = places.map((place) => place.toGeoJsonFeature()).toList();

      final geoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };

      // Try to update the source data
      try {
        final source = await map.style.getSource(sourceId);
        if (source != null && source is GeoJsonSource) {
          await source.updateGeoJSON(jsonEncode(geoJson));
          debugPrint('[SUCCESS] HistoricalPlacesOverlay updated: ${places.length} places');
          return;
        }
      } catch (_) {
        // Source doesn't exist or update failed, do full reload
      }

      // Full reload
      await _safeUnload(map);
      await load(map);
    } catch (e) {
      debugPrint('[ERROR] HistoricalPlacesOverlay update error: $e');
    }
  }

  @override
  Future<void> unload(MapboxMap map) async {
    await _safeUnload(map);
  }

  /// Safely remove layers and source, ignoring errors if they don't exist
  Future<void> _safeUnload(MapboxMap map) async {
    // Remove layers
    for (final layerId in allLayerIds) {
      try {
        await map.style.removeStyleLayer(layerId);
      } catch (_) {
        // Ignore - layer may not exist
      }
    }

    // Remove source
    try {
      await map.style.removeStyleSource(sourceId);
    } catch (_) {
      // Ignore - source may not exist
    }

    debugPrint('[SUCCESS] HistoricalPlacesOverlay unloaded');
  }

  @override
  Future<void> setVisibility(MapboxMap map, {required bool visible}) async {
    _isVisible = visible;
    try {
      final visibility = visible ? 'visible' : 'none';

      // Set visibility for all layers
      for (final layerId in allLayerIds) {
        try {
          await map.style.setStyleLayerProperty(
            layerId,
            'visibility',
            visibility,
          );
        } catch (_) {
          // Ignore - layer may not exist
        }
      }
    } catch (e) {
      debugPrint('[ERROR] HistoricalPlacesOverlay visibility error: $e');
    }
  }

  /// Handle map tap to detect if user tapped on a historical place
  /// Returns the tapped HistoricalPlace if found, null otherwise
  Future<HistoricalPlace?> handleTap(
    MapboxMap map,
    ScreenCoordinate screenCoordinate,
  ) async {
    try {
      // Use a tolerance box around the tap point (circles are radius 12)
      const tapTolerance = 24.0;
      final screenBox = ScreenBox(
        min: ScreenCoordinate(
          x: screenCoordinate.x - tapTolerance,
          y: screenCoordinate.y - tapTolerance,
        ),
        max: ScreenCoordinate(
          x: screenCoordinate.x + tapTolerance,
          y: screenCoordinate.y + tapTolerance,
        ),
      );

      // Query features in the tolerance box on the unclustered icon layer
      final features = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenBox(screenBox),
        RenderedQueryOptions(layerIds: [unclusteredIconLayerId]),
      );

      if (features.isEmpty) return null;

      // Get the feature from the queried feature
      final feature = features.first;
      if (feature == null) return null;

      final queriedFeature = feature.queriedFeature;
      final featureMapRaw = queriedFeature.feature;

      // Convert CastMap or other map types to Map<String, dynamic>
      final featureMap = Map<String, dynamic>.from(featureMapRaw);
      final propertiesRaw = featureMap['properties'];

      // Convert properties map (handles CastMap from Mapbox SDK)
      if (propertiesRaw is! Map) return null;
      final properties = Map<String, dynamic>.from(propertiesRaw);

      final placeId = properties['id']?.toString();
      if (placeId == null) return null;

      // Find the corresponding place
      final place = places.firstWhere(
        (p) => p.id == placeId,
        orElse: () => places.first,
      );

      debugPrint('[TAP] Tapped: ${place.featureName} (${place.typeMetadata.name})');
      return place;
    } catch (e, st) {
      debugPrint('[ERROR] HistoricalPlacesOverlay handleTap error: $e');
      debugPrint('   Stack trace: $st');
      return null;
    }
  }

  /// Handle cluster tap - returns true if a cluster was tapped (and zoomed in)
  Future<bool> handleClusterTap(
    MapboxMap map,
    ScreenCoordinate screenCoordinate,
  ) async {
    try {
      const tapTolerance = 20.0;
      final screenBox = ScreenBox(
        min: ScreenCoordinate(
          x: screenCoordinate.x - tapTolerance,
          y: screenCoordinate.y - tapTolerance,
        ),
        max: ScreenCoordinate(
          x: screenCoordinate.x + tapTolerance,
          y: screenCoordinate.y + tapTolerance,
        ),
      );

      // Query cluster layer
      final features = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenBox(screenBox),
        RenderedQueryOptions(layerIds: [clusterCircleLayerId]),
      );

      if (features.isEmpty) return false;

      final feature = features.first;
      if (feature == null) return false;

      final featureMap = Map<String, dynamic>.from(feature.queriedFeature.feature);
      final geometry = featureMap['geometry'] as Map?;
      if (geometry == null) return false;

      final coords = geometry['coordinates'] as List?;
      if (coords == null || coords.length < 2) return false;

      final lng = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();

      // Get current zoom and zoom in
      final cameraState = await map.getCameraState();
      final newZoom = (cameraState.zoom) + 2;

      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          zoom: newZoom > 18 ? 18 : newZoom,
        ),
        MapAnimationOptions(duration: 300),
      );

      debugPrint('[CLUSTER] Zoomed into cluster at ($lat, $lng)');
      return true;
    } catch (e) {
      debugPrint('[ERROR] handleClusterTap error: $e');
      return false;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoricalPlacesOverlay &&
          runtimeType == other.runtimeType &&
          places.length == other.places.length;

  @override
  int get hashCode => places.length.hashCode;
}
