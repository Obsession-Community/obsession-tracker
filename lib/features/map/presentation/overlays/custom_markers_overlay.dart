import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/custom_marker.dart';
import 'package:obsession_tracker/core/models/map_overlay.dart';
import 'package:obsession_tracker/core/services/custom_marker_icon_service.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/map_text_style.dart';

/// Renders custom markers as point markers on the map
///
/// Displays user-created custom markers with category-specific icons.
/// Uses:
/// - SymbolLayer with custom marker images (emoji on colored circle)
/// - SymbolLayer for marker name labels
///
/// The [idPrefix] parameter allows multiple instances of this overlay to coexist
/// on the map (e.g., 'custom-markers' vs 'session-markers').
class CustomMarkersOverlay extends MapOverlay {
  CustomMarkersOverlay({
    required this.markers,
    this.onMarkerTap,
    this.idPrefix = 'custom-markers',
  });

  final List<CustomMarker> markers;
  final ValueChanged<CustomMarker>? onMarkerTap;

  /// Prefix for source and layer IDs to allow multiple instances
  final String idPrefix;

  /// Get the source ID for this overlay instance
  String get sourceId => '$idPrefix-source';

  // Cluster layer IDs
  String get clusterCircleLayerId => '$idPrefix-cluster-circle';
  String get clusterCountLayerId => '$idPrefix-cluster-count';

  // SymbolLayer for unclustered points with custom marker icons
  String get unclusteredIconLayerId => '$idPrefix-icon';
  String get unclusteredLabelLayerId => '$idPrefix-label';

  /// Icon service for generating marker images
  static final _iconService = CustomMarkerIconService.instance;

  @override
  String get id => '$idPrefix-overlay';

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
    if (markers.isEmpty) {
      debugPrint('[WARNING] CustomMarkersOverlay: No markers to display');
      return;
    }

    try {
      // Remove existing layers/source if they exist
      await _safeUnload(map);

      // Create GeoJSON FeatureCollection from markers
      final features = markers.map((marker) => marker.toGeoJsonFeature()).toList();

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
          clusterRadius: 40,
          clusterMaxZoom: 15, // Cluster until zoom 15
        ),
      );

      // Add cluster circle layer (shows when markers are clustered)
      await map.style.addLayer(
        CircleLayer(
          id: clusterCircleLayerId,
          sourceId: sourceId,
          circleColor: 0xFF9C27B0, // Purple for clusters
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

      // Get unique categories from markers
      final categories = markers.map((m) => m.category).toSet();

      // Register marker icons for all categories present in the data
      await _iconService.registerImagesForCategories(map, categories);

      // Add SymbolLayer for unclustered markers with custom icons
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

      // Set icon-image using match expression for category-specific icons
      await map.style.setStyleLayerProperty(
        unclusteredIconLayerId,
        'icon-image',
        _iconService.buildIconImageExpression(categories),
      );

      // Add symbol layer for marker name labels (visible when zoomed in)
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

      debugPrint(
          '[SUCCESS] CustomMarkersOverlay loaded: ${markers.length} markers with custom icons');
    } catch (e) {
      debugPrint('[ERROR] CustomMarkersOverlay load error: $e');
    }
  }

  @override
  Future<void> update(MapboxMap map) async {
    if (markers.isEmpty) {
      await unload(map);
      return;
    }

    try {
      // Update source data directly if possible
      final features = markers.map((marker) => marker.toGeoJsonFeature()).toList();

      final geoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };

      // Try to update the source data
      try {
        final source = await map.style.getSource(sourceId);
        if (source != null && source is GeoJsonSource) {
          await source.updateGeoJSON(jsonEncode(geoJson));
          debugPrint(
              '[SUCCESS] CustomMarkersOverlay updated: ${markers.length} markers');
          return;
        }
      } catch (_) {
        // Source doesn't exist or update failed, do full reload
      }

      // Full reload
      await _safeUnload(map);
      await load(map);
    } catch (e) {
      debugPrint('[ERROR] CustomMarkersOverlay update error: $e');
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

    debugPrint('[SUCCESS] CustomMarkersOverlay unloaded');
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
      debugPrint('[ERROR] CustomMarkersOverlay visibility error: $e');
    }
  }

  /// Handle map tap to detect if user tapped on a custom marker
  /// Returns the tapped CustomMarker if found, null otherwise
  Future<CustomMarker?> handleTap(
    MapboxMap map,
    ScreenCoordinate screenCoordinate,
  ) async {
    try {
      // Use a tolerance box around the tap point (circles are radius 14)
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

      final markerId = properties['id']?.toString();
      if (markerId == null) return null;

      // Find the corresponding marker
      try {
        final marker = markers.firstWhere((m) => m.id == markerId);
        debugPrint('[TAP] Tapped marker: ${marker.name} (${marker.category.displayName})');
        return marker;
      } catch (_) {
        // Marker not found in current list
        return null;
      }
    } catch (e, st) {
      debugPrint('[ERROR] CustomMarkersOverlay handleTap error: $e');
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

      // Query for cluster features
      final features = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenBox(screenBox),
        RenderedQueryOptions(layerIds: [clusterCircleLayerId]),
      );

      if (features.isEmpty) return false;

      final feature = features.first;
      if (feature == null) return false;

      final queriedFeature = feature.queriedFeature;
      final featureMapRaw = queriedFeature.feature;
      final featureMap = Map<String, dynamic>.from(featureMapRaw);
      final propertiesRaw = featureMap['properties'];

      if (propertiesRaw is! Map) return false;
      final properties = Map<String, dynamic>.from(propertiesRaw);

      // Check if this is a cluster
      if (!properties.containsKey('point_count')) return false;

      // Get cluster coordinates from geometry
      final geometryRaw = featureMap['geometry'];
      if (geometryRaw is! Map) return false;
      final geometry = Map<String, dynamic>.from(geometryRaw);
      final coordinatesRaw = geometry['coordinates'];
      if (coordinatesRaw is! List || coordinatesRaw.length < 2) return false;

      final lng = (coordinatesRaw[0] as num).toDouble();
      final lat = (coordinatesRaw[1] as num).toDouble();

      // Zoom in on the cluster
      final currentZoom = await map.getCameraState();
      final newZoom = (currentZoom.zoom + 2).clamp(0, 18);

      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          zoom: newZoom.toDouble(),
        ),
        MapAnimationOptions(duration: 500),
      );

      debugPrint('[TAP] Zoomed in on cluster at ($lat, $lng)');
      return true;
    } catch (e) {
      debugPrint('[ERROR] CustomMarkersOverlay handleClusterTap error: $e');
      return false;
    }
  }
}
