import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/map_overlay.dart';

/// Renders GPS breadcrumb trail as a GeoJSON LineString layer
///
/// This overlay displays the user's tracking path as a colored line on the map.
/// Updates in real-time as new GPS positions are recorded.
class BreadcrumbOverlay extends MapOverlay {
  BreadcrumbOverlay({
    required this.breadcrumbs,
    this.lineColor = const Color(0xFF2196F3),
    this.lineWidth = 4.0,
    this.lineOpacity = 0.8,
    String? sourceId,
    String? layerId,
    String? overlayId,
  }) : sourceId = sourceId ?? 'breadcrumb-source',
       layerId = layerId ?? 'breadcrumb-layer',
       _overlayId = overlayId ?? 'breadcrumb-overlay';

  final List<geo.Position> breadcrumbs;
  final Color lineColor;
  final double lineWidth;
  final double lineOpacity;

  final String sourceId;
  final String layerId;
  final String _overlayId;

  @override
  String get id => _overlayId;

  bool _isVisible = true;

  @override
  bool get isVisible => _isVisible;

  @override
  Future<void> load(MapboxMap map) async {
    if (breadcrumbs.isEmpty) {
      debugPrint('⚠️ BreadcrumbOverlay: No breadcrumbs to display');
      return;
    }

    try {
      // Remove existing layer/source if they exist (cleanup from failed unload)
      await _safeUnload(map);

      // Create GeoJSON LineString from breadcrumb positions
      final coordinates = breadcrumbs
          .map((pos) => [pos.longitude, pos.latitude])
          .toList();

      final geoJson = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': coordinates,
            },
            'properties': {
              'name': 'Breadcrumb Trail',
            },
          },
        ],
      };

      // Add GeoJSON source
      await map.style.addSource(
        GeoJsonSource(
          id: sourceId,
          data: jsonEncode(geoJson),
        ),
      );

      // Add line layer with RGBA color
      final colorInt = ((lineColor.a * 255).toInt() << 24) |
          ((lineColor.r * 255).toInt() << 16) |
          ((lineColor.g * 255).toInt() << 8) |
          (lineColor.b * 255).toInt();

      await map.style.addLayer(
        LineLayer(
          id: layerId,
          sourceId: sourceId,
          lineColor: colorInt,
          lineWidth: lineWidth,
          lineOpacity: lineOpacity,
        ),
      );

      debugPrint('✅ BreadcrumbOverlay loaded: ${breadcrumbs.length} points');
    } catch (e) {
      debugPrint('❌ BreadcrumbOverlay load error: $e');
    }
  }

  @override
  Future<void> update(MapboxMap map) async {
    if (breadcrumbs.isEmpty) {
      await unload(map);
      return;
    }

    try {
      // Create updated GeoJSON
      final coordinates = breadcrumbs
          .map((pos) => [pos.longitude, pos.latitude])
          .toList();

      final geoJson = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': coordinates,
            },
            'properties': {
              'name': 'Breadcrumb Trail',
            },
          },
        ],
      };

      // Try to update source data directly (less flashing)
      try {
        await map.style.setStyleSourceProperty(
          sourceId,
          'data',
          jsonEncode(geoJson),
        );
        debugPrint('✅ BreadcrumbOverlay updated smoothly: ${breadcrumbs.length} points');
      } catch (e) {
        // Fallback: remove and re-add if direct update fails
        debugPrint('⚠️ Smooth update failed, doing full reload: $e');

        // Use safe unload to handle case where layer/source don't exist
        await _safeUnload(map);

        // Recreate source and layer
        await map.style.addSource(
          GeoJsonSource(
            id: sourceId,
            data: jsonEncode(geoJson),
          ),
        );

        final colorInt = ((lineColor.a * 255).toInt() << 24) |
            ((lineColor.r * 255).toInt() << 16) |
            ((lineColor.g * 255).toInt() << 8) |
            (lineColor.b * 255).toInt();

        await map.style.addLayer(
          LineLayer(
            id: layerId,
            sourceId: sourceId,
            lineColor: colorInt,
            lineWidth: lineWidth,
            lineOpacity: lineOpacity,
          ),
        );

        debugPrint('✅ BreadcrumbOverlay updated via reload: ${breadcrumbs.length} points');
      }
    } catch (e) {
      debugPrint('❌ BreadcrumbOverlay update error: $e');
    }
  }

  @override
  Future<void> unload(MapboxMap map) async {
    await _safeUnload(map);
  }

  /// Safely remove layer and source, ignoring errors if they don't exist
  Future<void> _safeUnload(MapboxMap map) async {
    try {
      // Remove layer first
      await map.style.removeStyleLayer(layerId);
    } catch (e) {
      // Ignore - layer may not exist
    }

    try {
      // Then remove source
      await map.style.removeStyleSource(sourceId);
    } catch (e) {
      // Ignore - source may not exist
    }
    debugPrint('✅ BreadcrumbOverlay unloaded');
  }

  @override
  Future<void> setVisibility(MapboxMap map, {required bool visible}) async {
    _isVisible = visible;
    try {
      await map.style.setStyleLayerProperty(
        layerId,
        'visibility',
        visible ? 'visible' : 'none',
      );
    } catch (e) {
      debugPrint('❌ BreadcrumbOverlay visibility error: $e');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BreadcrumbOverlay &&
          runtimeType == other.runtimeType &&
          sourceId == other.sourceId &&
          layerId == other.layerId &&
          _overlayId == other._overlayId &&
          breadcrumbs.length == other.breadcrumbs.length &&
          lineColor == other.lineColor &&
          lineWidth == other.lineWidth &&
          lineOpacity == other.lineOpacity;

  @override
  int get hashCode =>
      sourceId.hashCode ^
      layerId.hashCode ^
      _overlayId.hashCode ^
      breadcrumbs.length.hashCode ^
      lineColor.hashCode ^
      lineWidth.hashCode ^
      lineOpacity.hashCode;
}
