import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/map_overlay.dart';
import 'package:obsession_tracker/core/models/trail.dart';

/// Renders trails on the map as LineStrings with color-coded trail types
///
/// This overlay displays hiking/biking trails for treasure hunting exploration.
/// Uses LineLayer with data-driven styling for color-coding based on trail type.
class TrailsOverlay extends MapOverlay {
  TrailsOverlay({
    required this.trails,
    this.onTrailTap,
    this.lineOpacity = 0.8,
    this.lineWidth = 3.0,
  });

  final List<Trail> trails;
  final ValueChanged<Trail>? onTrailTap;
  final double lineOpacity;
  final double lineWidth;

  /// Color map for trail types (matches filter panel colors)
  static Map<String, int> get trailTypeColors => {
        // Official trail types (USFS)
        'TERRA': 0xFF8B4513, // Saddle brown for land trails
        'SNOW': 0xFF00BCD4, // Cyan for snowmobile trails
        'WATER': 0xFF2196F3, // Blue for water trails
        // OSM trail types (from state ZIP data)
        'BICYCLE': 0xFF4CAF50, // Green for bicycle trails
        'ROAD': 0xFF795548, // Brown for roads/tracks
        // Community trail types (OSM)
        'Hiker/Biker': 0xFF4CAF50, // Green for hiker/biker
        'Hiker/Horse': 0xFFFF9800, // Orange for hiker/horse
        'Hiker/Pedestrian Only': 0xFF9C27B0, // Purple for pedestrian only
      };

  static const String sourceId = 'trails-source';
  static const String lineLayerId = 'trails-line-layer';

  /// Lock to prevent concurrent load operations that cause race conditions
  static bool _loadInProgress = false;

  @override
  String get id => 'trails-overlay';

  bool _isVisible = true;

  @override
  bool get isVisible => _isVisible;

  @override
  Future<void> load(MapboxMap map) async {
    if (trails.isEmpty) {
      debugPrint('⚠️ TrailsOverlay: No trails to display');
      return;
    }

    // Prevent concurrent loads - serialize access to avoid race conditions
    if (_loadInProgress) {
      debugPrint('⏳ TrailsOverlay: Load already in progress, waiting...');
      // Wait a bit and retry once
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (_loadInProgress) {
        debugPrint('⏳ TrailsOverlay: Still busy, skipping duplicate load');
        return;
      }
    }

    _loadInProgress = true;

    try {
      // Create GeoJSON FeatureCollection from trails
      final features = <Map<String, dynamic>>[];
      final trailTypeCounts = <String, int>{};

      for (final trail in trails) {
        // Skip trails without geometry
        if (trail.geometry.coordinates.isEmpty) {
          continue;
        }

        // Count trail types for logging
        trailTypeCounts[trail.trailType] = (trailTypeCounts[trail.trailType] ?? 0) + 1;

        features.add({
          'type': 'Feature',
          'id': trail.id,
          'geometry': {
            'type': trail.geometry.type,
            'coordinates': trail.geometry.rawCoordinates,
          },
          'properties': {
            'id': trail.id,
            'trail_name': trail.trailName,
            'trail_number': trail.trailNumber ?? '',
            'trail_type': trail.trailType, // Added for color-coding
            'length_miles': trail.lengthMiles,
            'difficulty': trail.difficulty ?? 'Unknown',
            'managing_agency': trail.managingAgency ?? '',
          },
        });
      }

      if (features.isEmpty) {
        debugPrint('⚠️ TrailsOverlay: No trails with geometry coordinates');
        return;
      }

      debugPrint('🎨 TrailsOverlay: Rendering ${features.length} trails by type:');
      trailTypeCounts.forEach((type, count) {
        final color = trailTypeColors[type];
        final colorHex = color != null ? _colorToHex(color) : '#757575 (default gray)';
        debugPrint('   $type: $count trails → $colorHex');
      });

      final geoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };

      final geoJsonString = jsonEncode(geoJson);

      // Debug: Log sample GeoJSON structure for first trail
      if (features.isNotEmpty) {
        final firstFeature = features.first;
        final geom = firstFeature['geometry'] as Map<String, dynamic>;
        final coords = geom['coordinates'] as List<dynamic>;
        final coordCount = coords.length;
        final sampleCoord = coords.isNotEmpty ? coords.first : 'empty';
        debugPrint('🗺️ TrailsOverlay: GeoJSON structure check:');
        debugPrint('   - First trail geometry type: ${geom['type']}');
        debugPrint('   - First trail coordinate count: $coordCount');
        debugPrint('   - First trail sample coord: $sampleCoord');
        debugPrint('   - GeoJSON size: ${(geoJsonString.length / 1024).toStringAsFixed(1)} KB');
      }

      // Strategy: Try update first (optimistic), then create if needed
      // This avoids race conditions with check-then-act pattern
      bool updated = false;

      try {
        // Try to update existing source (fast path if already loaded)
        await map.style.setStyleSourceProperty(
          sourceId,
          'data',
          geoJsonString,
        );
        updated = true;
        debugPrint('✅ TrailsOverlay updated existing source: ${features.length} trails');
      } catch (e) {
        // Source doesn't exist yet - need to create it
        debugPrint('📝 TrailsOverlay: Source not found, creating new...');
      }

      if (!updated) {
        // Clean up any partial/stale state
        await _removeExistingLayersAndSource(map);

        // Add GeoJSON source
        await map.style.addSource(
          GeoJsonSource(
            id: sourceId,
            data: geoJsonString,
          ),
        );

        // Add line layer for trail paths with color-coded styling
        // IMPORTANT: lineColor MUST be set for layer to render - Mapbox won't show layers without base color
        // Start with opacity 0 for fade-in effect
        debugPrint('🎨 TrailsOverlay: Creating LineLayer (lineWidth=$lineWidth, lineOpacity=$lineOpacity)');
        await map.style.addLayer(
          LineLayer(
            id: lineLayerId,
            sourceId: sourceId,
            lineColor: 0xFF757575, // Default gray - will be overridden by data-driven styling below
            lineWidth: lineWidth,
            lineOpacity: 0.0, // Start invisible for fade-in
          ),
        );
        debugPrint('✅ TrailsOverlay: LineLayer added to map');

        // Apply data-driven styling for trail type colors
        // IMPORTANT: Pass expression as List, NOT jsonEncode - Mapbox expects raw expression
        debugPrint('🎨 TrailsOverlay: Applying data-driven line-color expression');
        await map.style.setStyleLayerProperty(
          lineLayerId,
          'line-color',
          [
            'match',
            ['get', 'trail_type'],
            'TERRA', _colorToHex(trailTypeColors['TERRA']!),
            'SNOW', _colorToHex(trailTypeColors['SNOW']!),
            'WATER', _colorToHex(trailTypeColors['WATER']!),
            'BICYCLE', _colorToHex(trailTypeColors['BICYCLE']!),
            'ROAD', _colorToHex(trailTypeColors['ROAD']!),
            'Hiker/Biker', _colorToHex(trailTypeColors['Hiker/Biker']!),
            'Hiker/Horse', _colorToHex(trailTypeColors['Hiker/Horse']!),
            'Hiker/Pedestrian Only', _colorToHex(trailTypeColors['Hiker/Pedestrian Only']!),
            '#757575' // Default gray for unknown types
          ],
        );

        // Add opacity transition for smooth fade-in (200ms)
        await map.style.setStyleLayerProperty(
          lineLayerId,
          'line-opacity-transition',
          {'duration': 200, 'delay': 0},
        );

        // Trigger fade-in animation
        await map.style.setStyleLayerProperty(
          lineLayerId,
          'line-opacity',
          lineOpacity,
        );
        debugPrint('✅ TrailsOverlay: Data-driven styling applied with fade-in');

        debugPrint('✅ TrailsOverlay loaded: ${features.length} trails');
      }
    } catch (e) {
      debugPrint('❌ TrailsOverlay load error: $e');
    } finally {
      _loadInProgress = false;
    }
  }

  /// Remove existing layers and source to prevent "already exists" errors
  Future<void> _removeExistingLayersAndSource(MapboxMap map) async {
    try {
      await map.style.removeStyleLayer(lineLayerId);
    } catch (_) {
      // Layer doesn't exist yet, ignore
    }
    try {
      await map.style.removeStyleSource(sourceId);
    } catch (_) {
      // Source doesn't exist yet, ignore
    }
  }

  /// Handle map tap to detect if user tapped on a trail
  /// Uses a tolerance radius around the tap point for easier targeting of thin lines
  /// This should be called from the map widget's tap handler
  Future<Trail?> handleTap(
    MapboxMap map,
    ScreenCoordinate screenCoordinate,
  ) async {
    try {
      debugPrint('🔍 TrailsOverlay.handleTap called - layerId: $lineLayerId, trails: ${trails.length}');

      // Use a bounding box around the tap point for better tap tolerance
      // 20 pixels in each direction = 40x40 pixel tap area
      const tapTolerance = 20.0;

      final minX = screenCoordinate.x - tapTolerance;
      final minY = screenCoordinate.y - tapTolerance;
      final maxX = screenCoordinate.x + tapTolerance;
      final maxY = screenCoordinate.y + tapTolerance;

      // Query features within the tap tolerance box
      final features = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenBox(
          ScreenBox(
            min: ScreenCoordinate(x: minX, y: minY),
            max: ScreenCoordinate(x: maxX, y: maxY),
          ),
        ),
        RenderedQueryOptions(layerIds: [lineLayerId]),
      );

      debugPrint('🔍 Trail query found ${features.length} features');

      if (features.isEmpty) {
        debugPrint('⚠️ No trail features found at tap location');
        return null;
      }

      // Get the feature ID from the queried feature
      final feature = features.first;
      if (feature == null) return null;

      final featureId = feature.queriedFeature.feature['id'];
      if (featureId == null) return null;

      // Find the corresponding trail
      try {
        final trail = trails.firstWhere(
          (t) => t.id == featureId.toString(),
        );
        debugPrint('🎯 Found trail in tap area: ${trail.trailName}');
        return trail;
      } catch (e) {
        debugPrint('⚠️ Trail tap: Feature ID $featureId not found in ${trails.length} trails');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Trail tap detection error: $e');
      return null;
    }
  }

  @override
  Future<void> update(MapboxMap map) async {
    if (trails.isEmpty) {
      await unload(map);
      return;
    }

    try {
      // Build features list
      final features = <Map<String, dynamic>>[];

      for (final trail in trails) {
        if (trail.geometry.coordinates.isEmpty) {
          continue;
        }

        features.add({
          'type': 'Feature',
          'id': trail.id,
          'geometry': {
            'type': trail.geometry.type,
            'coordinates': trail.geometry.rawCoordinates,
          },
          'properties': {
            'id': trail.id,
            'trail_name': trail.trailName,
            'trail_number': trail.trailNumber ?? '',
            'trail_type': trail.trailType, // Added for color-coding
            'length_miles': trail.lengthMiles,
            'difficulty': trail.difficulty ?? 'Unknown',
            'managing_agency': trail.managingAgency ?? '',
          },
        });
      }

      if (features.isEmpty) {
        debugPrint('⚠️ TrailsOverlay: No trails with geometry coordinates');
        return;
      }

      final geoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };

      // Try to update source data directly (smooth, no flashing)
      try {
        await map.style.setStyleSourceProperty(
          sourceId,
          'data',
          jsonEncode(geoJson),
        );
        debugPrint('✅ TrailsOverlay updated smoothly: ${features.length} trails');
      } catch (e) {
        // Fallback: remove and re-add if direct update fails
        debugPrint('⚠️ Smooth update failed, doing full reload: $e');

        try {
          await map.style.removeStyleLayer(lineLayerId);
        } catch (_) {}
        try {
          await map.style.removeStyleSource(sourceId);
        } catch (_) {}

        await map.style.addSource(
          GeoJsonSource(
            id: sourceId,
            data: jsonEncode(geoJson),
          ),
        );

        // IMPORTANT: lineColor MUST be set for layer to render - Mapbox won't show layers without base color
        // Start with opacity 0 for fade-in effect
        debugPrint('🎨 TrailsOverlay: Creating LineLayer in fallback (lineWidth=$lineWidth, lineOpacity=$lineOpacity)');
        await map.style.addLayer(
          LineLayer(
            id: lineLayerId,
            sourceId: sourceId,
            lineColor: 0xFF757575, // Default gray - will be overridden by data-driven styling below
            lineWidth: lineWidth,
            lineOpacity: 0.0, // Start invisible for fade-in
          ),
        );
        debugPrint('✅ TrailsOverlay: LineLayer added to map (fallback)');

        // Apply data-driven styling for trail type colors
        // IMPORTANT: Pass expression as List, NOT jsonEncode - Mapbox expects raw expression
        debugPrint('🎨 TrailsOverlay: Applying data-driven line-color expression (fallback)');
        await map.style.setStyleLayerProperty(
          lineLayerId,
          'line-color',
          [
            'match',
            ['get', 'trail_type'],
            'TERRA', _colorToHex(trailTypeColors['TERRA']!),
            'SNOW', _colorToHex(trailTypeColors['SNOW']!),
            'WATER', _colorToHex(trailTypeColors['WATER']!),
            'BICYCLE', _colorToHex(trailTypeColors['BICYCLE']!),
            'ROAD', _colorToHex(trailTypeColors['ROAD']!),
            'Hiker/Biker', _colorToHex(trailTypeColors['Hiker/Biker']!),
            'Hiker/Horse', _colorToHex(trailTypeColors['Hiker/Horse']!),
            'Hiker/Pedestrian Only', _colorToHex(trailTypeColors['Hiker/Pedestrian Only']!),
            '#757575' // Default gray for unknown types
          ],
        );

        // Add opacity transition for smooth fade-in
        await map.style.setStyleLayerProperty(
          lineLayerId,
          'line-opacity-transition',
          {'duration': 200, 'delay': 0},
        );

        // Trigger fade-in animation
        await map.style.setStyleLayerProperty(
          lineLayerId,
          'line-opacity',
          lineOpacity,
        );
        debugPrint('✅ TrailsOverlay: Data-driven styling applied with fade-in (fallback)');

        debugPrint('✅ TrailsOverlay updated via reload: ${features.length} trails');
      }
    } catch (e) {
      debugPrint('❌ TrailsOverlay update error: $e');
    }
  }

  @override
  Future<void> unload(MapboxMap map) async {
    try {
      // Remove layer first, then source
      try {
        await map.style.removeStyleLayer(lineLayerId);
      } catch (_) {}
      try {
        await map.style.removeStyleSource(sourceId);
      } catch (_) {}
      debugPrint('✅ TrailsOverlay unloaded');
    } catch (e) {
      debugPrint('❌ TrailsOverlay unload error: $e');
    }
  }

  @override
  Future<void> setVisibility(MapboxMap map, {required bool visible}) async {
    _isVisible = visible;
    try {
      final visibility = visible ? 'visible' : 'none';
      await map.style.setStyleLayerProperty(
        lineLayerId,
        'visibility',
        visibility,
      );
    } catch (e) {
      debugPrint('❌ TrailsOverlay visibility error: $e');
    }
  }

  /// Convert int color (0xAARRGGBB) to hex string (#RRGGBB)
  static String _colorToHex(int color) {
    return '#${(color & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrailsOverlay &&
          runtimeType == other.runtimeType &&
          trails.length == other.trails.length &&
          lineOpacity == other.lineOpacity;

  @override
  int get hashCode => trails.length.hashCode ^ lineOpacity.hashCode;
}
