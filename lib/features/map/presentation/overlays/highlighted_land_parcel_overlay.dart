import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/models/map_overlay.dart';

/// Renders a highlighted land parcel on the map
///
/// This overlay displays a selected land parcel with a thicker, brighter border
/// to provide visual feedback when the user taps on a land polygon.
class HighlightedLandParcelOverlay extends MapOverlay {
  HighlightedLandParcelOverlay({
    required this.parcel,
    this.fillOpacity = 0.2,
    this.strokeOpacity = 1.0,
    this.strokeWidth = 4.0,
    this.strokeColor = 0xFFFF9800, // Orange color for highlighting
  });

  final LandOwnership parcel;
  final double fillOpacity;
  final double strokeOpacity;
  final double strokeWidth;
  final int strokeColor;

  static const String sourceId = 'highlighted-parcel-source';
  static const String fillLayerId = 'highlighted-parcel-fill-layer';
  static const String lineLayerId = 'highlighted-parcel-line-layer';

  @override
  String get id => 'highlighted-land-parcel-overlay';

  bool _isVisible = true;

  @override
  bool get isVisible => _isVisible;

  @override
  Future<void> load(MapboxMap map) async {
    try {
      // Remove existing layers and sources if they exist
      await _removeExistingLayersAndSources(map);

      // Check if parcel has valid polygon coordinates
      if (parcel.polygonCoordinates == null ||
          parcel.polygonCoordinates!.isEmpty) {
        debugPrint('⚠️ HighlightedLandParcelOverlay: Parcel has no polygon coordinates');
        return;
      }

      // Split MultiPolygon into separate Polygon features
      // This ensures all parts of a MultiPolygon parcel are highlighted
      final polygons = _splitMultiPolygonCoordinates(parcel.polygonCoordinates!);

      final features = <Map<String, dynamic>>[];
      for (int i = 0; i < polygons.length; i++) {
        features.add({
          'type': 'Feature',
          'id': 'highlighted-parcel-$i',
          'geometry': {
            'type': 'Polygon',
            'coordinates': polygons[i],
          },
          'properties': {
            'id': parcel.id,
            'owner_name': parcel.ownerName,
          },
        });
      }

      final parcelGeoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };

      // Add GeoJSON source for parcel
      await map.style.addSource(
        GeoJsonSource(
          id: sourceId,
          data: jsonEncode(parcelGeoJson),
        ),
      );

      // Add fill layer for highlighted parcel (subtle fill)
      await map.style.addLayer(
        FillLayer(
          id: fillLayerId,
          sourceId: sourceId,
          fillOpacity: fillOpacity,
        ),
      );

      // Set fill color to orange
      await map.style.setStyleLayerProperty(
        fillLayerId,
        'fill-color',
        _colorToRgba(strokeColor, fillOpacity),
      );

      // Add line layer for highlighted parcel border (thick, bright)
      await map.style.addLayer(
        LineLayer(
          id: lineLayerId,
          sourceId: sourceId,
          lineColor: strokeColor,
          lineWidth: strokeWidth,
          lineOpacity: strokeOpacity,
        ),
      );

      debugPrint('✅ HighlightedLandParcelOverlay loaded for parcel: ${parcel.ownerName}');
    } catch (e) {
      debugPrint('❌ HighlightedLandParcelOverlay load error: $e');
    }
  }

  /// Remove existing layers and sources to prevent "already exists" errors
  Future<void> _removeExistingLayersAndSources(MapboxMap map) async {
    // Remove layers first (in reverse order of creation)
    try {
      await map.style.removeStyleLayer(lineLayerId);
    } catch (_) {}
    try {
      await map.style.removeStyleLayer(fillLayerId);
    } catch (_) {}

    // Remove source
    try {
      await map.style.removeStyleSource(sourceId);
    } catch (_) {}
  }

  @override
  Future<void> update(MapboxMap map) async {
    // For now, just reload the overlay
    // Could optimize later to update source data directly
    await unload(map);
    await load(map);
  }

  @override
  Future<void> unload(MapboxMap map) async {
    try {
      await _removeExistingLayersAndSources(map);
      debugPrint('✅ HighlightedLandParcelOverlay unloaded');
    } catch (e) {
      debugPrint('❌ HighlightedLandParcelOverlay unload error: $e');
    }
  }

  @override
  Future<void> setVisibility(MapboxMap map, {required bool visible}) async {
    _isVisible = visible;
    try {
      final visibility = visible ? 'visible' : 'none';
      await map.style.setStyleLayerProperty(
        fillLayerId,
        'visibility',
        visibility,
      );
      await map.style.setStyleLayerProperty(
        lineLayerId,
        'visibility',
        visibility,
      );
    } catch (e) {
      debugPrint('❌ HighlightedLandParcelOverlay visibility error: $e');
    }
  }

  /// Split MultiPolygon coordinates into separate Polygon coordinate arrays
  ///
  /// When a parcel has multiple exterior rings (from a MultiPolygon), this method
  /// splits them into separate polygons so each renders correctly.
  List<List<List<List<double>>>> _splitMultiPolygonCoordinates(
    List<List<List<double>>> coordinates,
  ) {
    // If only 1 ring, it's a simple polygon - keep as-is
    if (coordinates.length <= 1) {
      return [coordinates];
    }

    // Multiple rings: treat each as a separate polygon
    return coordinates.map((ring) => [ring]).toList();
  }

  /// Convert Flutter color (int) to RGBA string for Mapbox
  /// Example: 0xFFFF5733 with opacity 0.3 -> "rgba(255, 87, 51, 0.3)"
  String _colorToRgba(int colorValue, double opacity) {
    final r = (colorValue >> 16) & 0xFF;
    final g = (colorValue >> 8) & 0xFF;
    final b = colorValue & 0xFF;
    return 'rgba($r, $g, $b, $opacity)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HighlightedLandParcelOverlay &&
          runtimeType == other.runtimeType &&
          parcel.id == other.parcel.id;

  @override
  int get hashCode => parcel.id.hashCode;
}
