import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/cell_tower.dart';
import 'package:obsession_tracker/core/models/map_overlay.dart';

/// Renders cell tower coverage on the map as actual geographic radius circles
///
/// Displays cell towers with coverage areas based on their range_meters.
/// Colors indicate radio technology: 2G=red, 3G=orange, 4G=green, 5G=blue.
///
/// Uses:
/// - FillLayer for coverage area polygons (semi-transparent, shows overlaps)
/// - LineLayer for coverage area outlines
/// - CircleLayer for tower center points (small dots)
///
/// No clustering - overlapping coverage zones are intentionally visible.
class CellCoverageOverlay extends MapOverlay {
  CellCoverageOverlay({
    required this.towers,
    this.onTowerTap,
    this.fillOpacity = 0.25,
  });

  final List<CellTower> towers;
  final ValueChanged<CellTower>? onTowerTap;
  final double fillOpacity;

  // Source IDs
  static const String coverageSourceId = 'cell-coverage-polygons';
  static const String pointSourceId = 'cell-tower-points';

  // Layer IDs
  static const String coverageFillLayerId = 'cell-coverage-fill';
  static const String coverageLineLayerId = 'cell-coverage-line';
  static const String pointLayerId = 'cell-tower-markers';

  @override
  String get id => 'cell-coverage-overlay';

  bool _isVisible = true;

  @override
  bool get isVisible => _isVisible;

  /// Get all layer IDs for this overlay
  List<String> get allLayerIds => [
        coverageFillLayerId,
        coverageLineLayerId,
        pointLayerId,
      ];

  /// Get all source IDs for this overlay
  List<String> get allSourceIds => [
        coverageSourceId,
        pointSourceId,
      ];

  @override
  Future<void> load(MapboxMap map) async {
    if (towers.isEmpty) {
      debugPrint('[WARNING] CellCoverageOverlay: No towers to display');
      return;
    }

    try {
      // Remove existing layers/source if they exist
      await _safeUnload(map);

      // Count towers by radio type for logging
      final typeCounts = <String, int>{};
      for (final tower in towers) {
        typeCounts[tower.radioType.code] =
            (typeCounts[tower.radioType.code] ?? 0) + 1;
      }
      debugPrint(
          '[INFO] CellCoverageOverlay: ${towers.length} towers (${typeCounts.entries.map((e) => '${e.key}: ${e.value}').join(', ')})');

      // Generate coverage polygons (circles based on effective range)
      // Uses effectiveRangeMeters which applies minimum range by radio type
      // Log effective ranges being used
      final sampleRanges = towers.take(3).map((t) => '${t.radioType.code}:${t.effectiveRangeMeters}m').join(', ');
      debugPrint('[INFO] CellCoverageOverlay: Using effective ranges (sample): $sampleRanges');

      final coverageFeatures = towers.map((tower) {
        final polygon = _createCirclePolygon(
          tower.latitude,
          tower.longitude,
          tower.effectiveRangeMeters.toDouble(),
        );
        return {
          'type': 'Feature',
          'id': tower.id,
          'geometry': {
            'type': 'Polygon',
            'coordinates': [polygon],
          },
          'properties': {
            'id': tower.id,
            'radio': tower.radioType.code,
            'carrier': tower.carrier ?? 'Unknown',
            'range_meters': tower.effectiveRangeMeters,
          },
        };
      }).toList();

      final coverageGeoJson = {
        'type': 'FeatureCollection',
        'features': coverageFeatures,
      };

      // Create point features for tower markers
      final pointFeatures = towers.map((tower) => tower.toGeoJsonFeature()).toList();
      final pointGeoJson = {
        'type': 'FeatureCollection',
        'features': pointFeatures,
      };

      // Add coverage polygon source (no clustering)
      await map.style.addSource(
        GeoJsonSource(
          id: coverageSourceId,
          data: jsonEncode(coverageGeoJson),
        ),
      );

      // Add point source for tower markers (no clustering)
      await map.style.addSource(
        GeoJsonSource(
          id: pointSourceId,
          data: jsonEncode(pointGeoJson),
        ),
      );

      // Add coverage fill layer (semi-transparent)
      await map.style.addLayer(
        FillLayer(
          id: coverageFillLayerId,
          sourceId: coverageSourceId,
          fillOpacity: fillOpacity,
        ),
      );

      // Set fill color based on radio type using rgba() format
      await map.style.setStyleLayerProperty(
        coverageFillLayerId,
        'fill-color',
        [
          'match',
          ['get', 'radio'],
          'GSM', 'rgba(255, 107, 107, 1)', // Red for 2G
          'CDMA', 'rgba(255, 107, 107, 1)', // Red for 2G
          'UMTS', 'rgba(255, 169, 77, 1)', // Orange for 3G
          'LTE', 'rgba(0, 188, 212, 1)', // Cyan for 4G - visible on green terrain
          'NR', 'rgba(156, 39, 176, 1)', // Purple for 5G - distinct
          'rgba(0, 188, 212, 1)', // Default to cyan (LTE)
        ],
      );

      // Add coverage outline layer
      await map.style.addLayer(
        LineLayer(
          id: coverageLineLayerId,
          sourceId: coverageSourceId,
          lineWidth: 1.0,
          lineOpacity: 0.4,
        ),
      );

      // Set line color based on radio type using rgba() format
      await map.style.setStyleLayerProperty(
        coverageLineLayerId,
        'line-color',
        [
          'match',
          ['get', 'radio'],
          'GSM', 'rgba(255, 107, 107, 1)',
          'CDMA', 'rgba(255, 107, 107, 1)',
          'UMTS', 'rgba(255, 169, 77, 1)',
          'LTE', 'rgba(0, 188, 212, 1)', // Cyan for 4G
          'NR', 'rgba(156, 39, 176, 1)', // Purple for 5G
          'rgba(0, 188, 212, 1)',
        ],
      );

      // Add tower marker layer (small dots at tower locations)
      await map.style.addLayer(
        CircleLayer(
          id: pointLayerId,
          sourceId: pointSourceId,
          circleRadius: 4.0,
          circleOpacity: 1.0,
          circleStrokeWidth: 1.5,
          circleStrokeColor: 0xFFFFFFFF,
          minZoom: 8.0, // Show markers when zoomed in enough to see individual towers
        ),
      );

      // Set marker color based on radio type using rgba() format
      await map.style.setStyleLayerProperty(
        pointLayerId,
        'circle-color',
        [
          'match',
          ['get', 'radio'],
          'GSM', 'rgba(255, 107, 107, 1)',
          'CDMA', 'rgba(255, 107, 107, 1)',
          'UMTS', 'rgba(255, 169, 77, 1)',
          'LTE', 'rgba(0, 188, 212, 1)', // Cyan for 4G
          'NR', 'rgba(156, 39, 176, 1)', // Purple for 5G
          'rgba(0, 188, 212, 1)',
        ],
      );

      debugPrint('[SUCCESS] CellCoverageOverlay loaded: ${towers.length} coverage circles');
    } catch (e, st) {
      debugPrint('[ERROR] CellCoverageOverlay load error: $e');
      debugPrint('   Stack trace: $st');
    }
  }

  /// Create a polygon approximating a circle at the given center with radius in meters
  ///
  /// Returns a list of [lng, lat] coordinates forming the polygon ring
  List<List<double>> _createCirclePolygon(
    double centerLat,
    double centerLng,
    double radiusMeters, {
    int segments = 32,
  }) {
    const earthRadius = 6371000.0; // Earth radius in meters
    final points = <List<double>>[];

    for (int i = 0; i <= segments; i++) {
      final bearing = (i * 360.0 / segments) * (math.pi / 180.0); // radians

      // Calculate destination point using spherical geometry
      final lat1 = centerLat * (math.pi / 180.0);
      final lng1 = centerLng * (math.pi / 180.0);
      final angularDistance = radiusMeters / earthRadius;

      final lat2 = math.asin(
        math.sin(lat1) * math.cos(angularDistance) +
            math.cos(lat1) * math.sin(angularDistance) * math.cos(bearing),
      );

      final lng2 = lng1 +
          math.atan2(
            math.sin(bearing) * math.sin(angularDistance) * math.cos(lat1),
            math.cos(angularDistance) - math.sin(lat1) * math.sin(lat2),
          );

      // Convert back to degrees
      final destLat = lat2 * (180.0 / math.pi);
      final destLng = lng2 * (180.0 / math.pi);

      points.add([destLng, destLat]); // GeoJSON uses [lng, lat] order
    }

    return points;
  }

  @override
  Future<void> update(MapboxMap map) async {
    if (towers.isEmpty) {
      await unload(map);
      return;
    }

    // Full reload since we need to regenerate polygon geometries
    await _safeUnload(map);
    await load(map);
  }

  @override
  Future<void> unload(MapboxMap map) async {
    await _safeUnload(map);
  }

  /// Safely remove layers and sources, ignoring errors if they don't exist
  Future<void> _safeUnload(MapboxMap map) async {
    // Remove layers first
    for (final layerId in allLayerIds) {
      try {
        await map.style.removeStyleLayer(layerId);
      } catch (_) {
        // Ignore - layer may not exist
      }
    }

    // Remove sources
    for (final sourceId in allSourceIds) {
      try {
        await map.style.removeStyleSource(sourceId);
      } catch (_) {
        // Ignore - source may not exist
      }
    }

    debugPrint('[SUCCESS] CellCoverageOverlay unloaded');
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
      debugPrint('[ERROR] CellCoverageOverlay visibility error: $e');
    }
  }

  /// Handle map tap to detect if user tapped on a cell tower coverage area
  /// Returns the tapped CellTower if found, null otherwise
  Future<CellTower?> handleTap(
    MapboxMap map,
    ScreenCoordinate screenCoordinate,
  ) async {
    try {
      // Use a tolerance box around the tap point
      const tapTolerance = 8.0;
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

      // Query features on coverage and point layers
      final features = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenBox(screenBox),
        RenderedQueryOptions(layerIds: [coverageFillLayerId, pointLayerId]),
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

      final towerId = properties['id']?.toString();
      if (towerId == null) return null;

      // Find the corresponding tower
      final tower = towers.firstWhere(
        (t) => t.id == towerId,
        orElse: () => towers.first,
      );

      debugPrint('[TAP] Tapped: ${tower.carrier ?? 'Unknown'} ${tower.radioType.displayName} (${tower.rangeMeters}m range)');
      return tower;
    } catch (e, st) {
      debugPrint('[ERROR] CellCoverageOverlay handleTap error: $e');
      debugPrint('   Stack trace: $st');
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellCoverageOverlay &&
          runtimeType == other.runtimeType &&
          towers.length == other.towers.length;

  @override
  int get hashCode => towers.length.hashCode;
}
