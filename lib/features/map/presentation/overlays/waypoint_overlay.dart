import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/map_overlay.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/map_text_style.dart';

/// Renders waypoints as point annotations on the map
///
/// This overlay displays user-marked waypoints with type-specific icons and colors.
/// Supports interactive waypoints that can be tapped for details.
class WaypointOverlay extends MapOverlay {
  WaypointOverlay({
    required this.waypoints,
    this.onWaypointTap,
  });

  final List<Waypoint> waypoints;
  final ValueChanged<Waypoint>? onWaypointTap;

  static const String sourceId = 'waypoint-source';
  static const String layerId = 'waypoint-layer'; // Circle layer for regular waypoints
  static const String symbolLayerId = 'waypoint-symbol-layer'; // Text labels for regular
  static const String photoIconLayerId = 'waypoint-photo-icon-layer'; // Circle layer for photos
  static const String noteIconLayerId = 'waypoint-note-icon-layer'; // Circle layer for notes

  @override
  String get id => 'waypoint-overlay';

  bool _isVisible = true;

  @override
  bool get isVisible => _isVisible;

  @override
  Future<void> load(MapboxMap map) async {
    if (waypoints.isEmpty) {
      debugPrint('⚠️ WaypointOverlay: No waypoints to display');
      return;
    }

    try {
      // Remove existing layers/source if they exist (cleanup from failed unload)
      await _safeUnload(map);

      // Create GeoJSON FeatureCollection from waypoints
      final features = waypoints.map((waypoint) {
        // For photo and note waypoints, use emoji icons
        String displayLabel;
        if (waypoint.type == WaypointType.photo) {
          // Use sunglasses emoji for Meta glasses photos, camera for phone photos
          final isMetaGlasses = waypoint.notes?.contains('meta_glasses') == true ||
              waypoint.name?.toLowerCase().contains('meta') == true;
          displayLabel = isMetaGlasses ? '🕶️' : '📷';
        } else if (waypoint.type == WaypointType.note) {
          displayLabel = '📝';
        } else {
          displayLabel = waypoint.displayName;
        }

        return {
          'type': 'Feature',
          'id': waypoint.id,
          'geometry': {
            'type': 'Point',
            'coordinates': [
              waypoint.coordinates.longitude,
              waypoint.coordinates.latitude,
            ],
          },
          'properties': {
            'id': waypoint.id,
            'name': displayLabel,
            'type': waypoint.type.name,
            'color': waypoint.type.colorHex,
            'icon': waypoint.type.iconName,
            'notes': waypoint.notes ?? '',
            'timestamp': waypoint.timestamp.millisecondsSinceEpoch,
          },
        };
      }).toList();

      final geoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };

      // Add GeoJSON source
      await map.style.addSource(
        GeoJsonSource(
          id: sourceId,
          data: jsonEncode(geoJson),
        ),
      );

      // Add circle layer for regular waypoints (blue) - excludes photo and note
      await map.style.addLayer(
        CircleLayer(
          id: layerId,
          sourceId: sourceId,
          circleRadius: 12.0,
          circleColor: 0xFF2196F3, // Blue for regular waypoints
          circleStrokeWidth: 2.0,
          circleStrokeColor: 0xFFFFFFFF, // White border
          filter: ['all', ['!=', ['get', 'type'], 'photo'], ['!=', ['get', 'type'], 'note']],
        ),
      );

      // Add circle layer for photo waypoints (orange)
      await map.style.addLayer(
        CircleLayer(
          id: photoIconLayerId,
          sourceId: sourceId,
          circleRadius: 14.0, // Slightly larger for photos
          circleColor: 0xFFFF6B35, // Orange for photos
          circleStrokeWidth: 2.0,
          circleStrokeColor: 0xFFFFFFFF, // White border
          filter: ['==', ['get', 'type'], 'photo'],
        ),
      );

      // Add circle layer for note waypoints (cyan)
      await map.style.addLayer(
        CircleLayer(
          id: noteIconLayerId,
          sourceId: sourceId,
          circleRadius: 14.0, // Same size as photos
          circleColor: 0xFF00BCD4, // Cyan for notes
          circleStrokeWidth: 2.0,
          circleStrokeColor: 0xFFFFFFFF, // White border
          filter: ['==', ['get', 'type'], 'note'],
        ),
      );

      // Add symbol layer for text labels on regular waypoints
      await map.style.addLayer(
        SymbolLayer(
          id: symbolLayerId,
          sourceId: sourceId,
          textField: '{name}',
          textFont: MapTextStyle.labelFont,
          textSize: MapTextStyle.waypointLabelSize,
          textColor: MapTextStyle.textColor,
          textHaloColor: MapTextStyle.textHaloColor,
          textHaloWidth: MapTextStyle.textHaloWidth,
          textHaloBlur: MapTextStyle.textHaloBlur,
          textLetterSpacing: MapTextStyle.textLetterSpacing,
          textMaxWidth: MapTextStyle.textMaxWidth,
          textAnchor: TextAnchor.TOP,
          textOffset: [0, 1.5],
          filter: ['all', ['!=', ['get', 'type'], 'photo'], ['!=', ['get', 'type'], 'note']],
        ),
      );

      // Add symbol layer for photo waypoints - emoji labels
      await map.style.addLayer(
        SymbolLayer(
          id: '$photoIconLayerId-label',
          sourceId: sourceId,
          textField: '{name}', // Emoji (📷 or 🕶️)
          textSize: 16.0,
          textAnchor: TextAnchor.CENTER,
          textAllowOverlap: true,
          textIgnorePlacement: true,
          filter: ['==', ['get', 'type'], 'photo'],
        ),
      );

      // Add symbol layer for note waypoints - emoji labels
      await map.style.addLayer(
        SymbolLayer(
          id: '$noteIconLayerId-label',
          sourceId: sourceId,
          textField: '{name}', // Emoji (📝)
          textSize: 16.0,
          textAnchor: TextAnchor.CENTER,
          textAllowOverlap: true,
          textIgnorePlacement: true,
          filter: ['==', ['get', 'type'], 'note'],
        ),
      );

      debugPrint('✅ WaypointOverlay loaded: ${waypoints.length} waypoints');
    } catch (e) {
      debugPrint('❌ WaypointOverlay load error: $e');
    }
  }

  @override
  Future<void> update(MapboxMap map) async {
    if (waypoints.isEmpty) {
      await unload(map);
      return;
    }

    try {
      // Remove existing layers and source
      await _safeUnload(map);

      // Re-add with updated data
      final features = waypoints.map((waypoint) {
        // For photo and note waypoints, use emoji icons
        String displayLabel;
        if (waypoint.type == WaypointType.photo) {
          final isMetaGlasses = waypoint.notes?.contains('meta_glasses') == true ||
              waypoint.name?.toLowerCase().contains('meta') == true;
          displayLabel = isMetaGlasses ? '🕶️' : '📷';
        } else if (waypoint.type == WaypointType.note) {
          displayLabel = '📝';
        } else {
          displayLabel = waypoint.displayName;
        }

        return {
          'type': 'Feature',
          'id': waypoint.id,
          'geometry': {
            'type': 'Point',
            'coordinates': [
              waypoint.coordinates.longitude,
              waypoint.coordinates.latitude,
            ],
          },
          'properties': {
            'id': waypoint.id,
            'name': displayLabel,
            'type': waypoint.type.name,
            'color': waypoint.type.colorHex,
            'icon': waypoint.type.iconName,
            'notes': waypoint.notes ?? '',
            'timestamp': waypoint.timestamp.millisecondsSinceEpoch,
          },
        };
      }).toList();

      final geoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };

      await map.style.addSource(
        GeoJsonSource(
          id: sourceId,
          data: jsonEncode(geoJson),
        ),
      );

      // Add circle layer for regular waypoints (blue) - excludes photo and note
      await map.style.addLayer(
        CircleLayer(
          id: layerId,
          sourceId: sourceId,
          circleRadius: 12.0,
          circleColor: 0xFF2196F3, // Blue for regular waypoints
          circleStrokeWidth: 2.0,
          circleStrokeColor: 0xFFFFFFFF,
          filter: ['all', ['!=', ['get', 'type'], 'photo'], ['!=', ['get', 'type'], 'note']],
        ),
      );

      // Add circle layer for photo waypoints (orange)
      await map.style.addLayer(
        CircleLayer(
          id: photoIconLayerId,
          sourceId: sourceId,
          circleRadius: 14.0,
          circleColor: 0xFFFF6B35, // Orange for photos
          circleStrokeWidth: 2.0,
          circleStrokeColor: 0xFFFFFFFF,
          filter: ['==', ['get', 'type'], 'photo'],
        ),
      );

      // Add circle layer for note waypoints (cyan)
      await map.style.addLayer(
        CircleLayer(
          id: noteIconLayerId,
          sourceId: sourceId,
          circleRadius: 14.0,
          circleColor: 0xFF00BCD4, // Cyan for notes
          circleStrokeWidth: 2.0,
          circleStrokeColor: 0xFFFFFFFF,
          filter: ['==', ['get', 'type'], 'note'],
        ),
      );

      // Add symbol layer for text labels on regular waypoints
      await map.style.addLayer(
        SymbolLayer(
          id: symbolLayerId,
          sourceId: sourceId,
          textField: '{name}',
          textFont: MapTextStyle.labelFont,
          textSize: MapTextStyle.waypointLabelSize,
          textColor: MapTextStyle.textColor,
          textHaloColor: MapTextStyle.textHaloColor,
          textHaloWidth: MapTextStyle.textHaloWidth,
          textHaloBlur: MapTextStyle.textHaloBlur,
          textLetterSpacing: MapTextStyle.textLetterSpacing,
          textMaxWidth: MapTextStyle.textMaxWidth,
          textAnchor: TextAnchor.TOP,
          textOffset: [0, 1.5],
          filter: ['all', ['!=', ['get', 'type'], 'photo'], ['!=', ['get', 'type'], 'note']],
        ),
      );

      // Add symbol layer for photo waypoints - emoji labels
      await map.style.addLayer(
        SymbolLayer(
          id: '$photoIconLayerId-label',
          sourceId: sourceId,
          textField: '{name}', // Emoji (📷 or 🕶️)
          textSize: 16.0,
          textAnchor: TextAnchor.CENTER,
          textAllowOverlap: true,
          textIgnorePlacement: true,
          filter: ['==', ['get', 'type'], 'photo'],
        ),
      );

      // Add symbol layer for note waypoints - emoji labels
      await map.style.addLayer(
        SymbolLayer(
          id: '$noteIconLayerId-label',
          sourceId: sourceId,
          textField: '{name}', // Emoji (📝)
          textSize: 16.0,
          textAnchor: TextAnchor.CENTER,
          textAllowOverlap: true,
          textIgnorePlacement: true,
          filter: ['==', ['get', 'type'], 'note'],
        ),
      );

      debugPrint('✅ WaypointOverlay updated: ${waypoints.length} waypoints');
    } catch (e) {
      debugPrint('❌ WaypointOverlay update error: $e');
    }
  }

  @override
  Future<void> unload(MapboxMap map) async {
    await _safeUnload(map);
  }

  /// Safely remove layers and source, ignoring errors if they don't exist
  Future<void> _safeUnload(MapboxMap map) async {
    // Remove layers first, then source
    try {
      await map.style.removeStyleLayer('$noteIconLayerId-label');
    } catch (_) {
      // Ignore - layer may not exist
    }
    try {
      await map.style.removeStyleLayer(noteIconLayerId);
    } catch (_) {
      // Ignore - layer may not exist
    }
    try {
      await map.style.removeStyleLayer('$photoIconLayerId-label');
    } catch (_) {
      // Ignore - layer may not exist
    }
    try {
      await map.style.removeStyleLayer(photoIconLayerId);
    } catch (_) {
      // Ignore - layer may not exist
    }
    try {
      await map.style.removeStyleLayer(symbolLayerId);
    } catch (_) {
      // Ignore - layer may not exist
    }
    try {
      await map.style.removeStyleLayer(layerId);
    } catch (_) {
      // Ignore - layer may not exist
    }
    try {
      await map.style.removeStyleSource(sourceId);
    } catch (_) {
      // Ignore - source may not exist
    }
    debugPrint('✅ WaypointOverlay unloaded');
  }

  @override
  Future<void> setVisibility(MapboxMap map, {required bool visible}) async {
    _isVisible = visible;
    try {
      final visibility = visible ? 'visible' : 'none';
      await map.style.setStyleLayerProperty(
        layerId,
        'visibility',
        visibility,
      );
      await map.style.setStyleLayerProperty(
        symbolLayerId,
        'visibility',
        visibility,
      );
      await map.style.setStyleLayerProperty(
        photoIconLayerId,
        'visibility',
        visibility,
      );
      await map.style.setStyleLayerProperty(
        '$photoIconLayerId-label',
        'visibility',
        visibility,
      );
      await map.style.setStyleLayerProperty(
        noteIconLayerId,
        'visibility',
        visibility,
      );
      await map.style.setStyleLayerProperty(
        '$noteIconLayerId-label',
        'visibility',
        visibility,
      );
    } catch (e) {
      debugPrint('❌ WaypointOverlay visibility error: $e');
    }
  }

  /// Handle map tap to detect if user tapped on a waypoint
  /// Returns the tapped Waypoint if found, null otherwise
  Future<Waypoint?> handleTap(
    MapboxMap map,
    ScreenCoordinate screenCoordinate,
  ) async {
    try {
      // Query features at the tap location on all circle layers
      final features = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenCoordinate),
        RenderedQueryOptions(layerIds: [layerId, photoIconLayerId, noteIconLayerId]),
      );

      if (features.isEmpty) return null;

      // Get the feature ID from the queried feature
      final feature = features.first;
      if (feature == null) return null;

      final featureId = feature.queriedFeature.feature['id'];
      if (featureId == null) return null;

      // Find the corresponding waypoint
      final waypoint = waypoints.firstWhere(
        (w) => w.id == featureId.toString(),
        orElse: () => waypoints.first,
      );

      debugPrint('🎯 Tapped waypoint: ${waypoint.displayName} (${waypoint.type.name})');
      return waypoint;
    } catch (e) {
      debugPrint('❌ WaypointOverlay handleTap error: $e');
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaypointOverlay &&
          runtimeType == other.runtimeType &&
          waypoints.length == other.waypoints.length;

  @override
  int get hashCode => waypoints.length.hashCode;
}
