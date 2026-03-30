import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/map_overlay.dart';
import 'package:obsession_tracker/core/models/trail.dart';

/// Renders a highlighted trail group on the map with START/END markers
/// and segment junction indicators
///
/// This overlay displays all segments of a selected trail with a thicker,
/// brighter line and adds green START, red END, and orange junction markers.
class HighlightedTrailOverlay extends MapOverlay {
  HighlightedTrailOverlay({
    required this.trailGroup,
    this.lineOpacity = 1.0,
    this.lineWidth = 6.0,
    this.lineColor = 0xFFFF9800, // Orange color for highlighting
  });

  final TrailGroup trailGroup;
  final double lineOpacity;
  final double lineWidth;
  final int lineColor;

  static const String sourceId = 'highlighted-trail-source';
  static const String lineLayerId = 'highlighted-trail-line-layer';
  static const String markersSourceId = 'highlighted-trail-markers-source';
  static const String startMarkerId = 'highlighted-trail-start-layer';
  static const String endMarkerId = 'highlighted-trail-end-layer';
  static const String junctionMarkerId = 'highlighted-trail-junction-layer';
  static const String tappedMarkerId = 'highlighted-trail-tapped-layer';

  @override
  String get id => 'highlighted-trail-overlay';

  bool _isVisible = true;

  @override
  bool get isVisible => _isVisible;

  @override
  Future<void> load(MapboxMap map) async {
    try {
      // Remove existing layers and sources if they exist
      await _removeExistingLayersAndSources(map);

      // Check if we have any segments with valid geometry
      final validSegments = trailGroup.segments
          .where((t) => t.geometry.coordinates.isNotEmpty)
          .toList();

      if (validSegments.isEmpty) {
        debugPrint('⚠️ HighlightedTrailOverlay: No segments with geometry');
        return;
      }

      // Create GeoJSON features for ALL segments of the trail
      final features = <Map<String, dynamic>>[];
      for (int i = 0; i < validSegments.length; i++) {
        final segment = validSegments[i];
        features.add({
          'type': 'Feature',
          'id': 'segment-$i',
          'geometry': {
            'type': segment.geometry.type,
            'coordinates': segment.geometry.rawCoordinates,
          },
          'properties': {
            'id': segment.id,
            'trail_name': segment.trailName,
            'segment_index': i,
            'is_tapped': segment.id == trailGroup.tappedSegment.id,
          },
        });
      }

      final trailGeoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };

      // Add GeoJSON source for all trail segments
      await map.style.addSource(
        GeoJsonSource(
          id: sourceId,
          data: jsonEncode(trailGeoJson),
        ),
      );

      // Add line layer for highlighted trail segments
      await map.style.addLayer(
        LineLayer(
          id: lineLayerId,
          sourceId: sourceId,
          lineColor: lineColor,
          lineWidth: lineWidth,
          lineOpacity: lineOpacity,
        ),
      );

      // Create START, END, and junction markers
      await _addMarkers(map, validSegments);

      final segmentInfo = trailGroup.isMultiSegment
          ? ' (${trailGroup.segmentCount} segments)'
          : '';
      debugPrint(
          '✅ HighlightedTrailOverlay loaded: ${trailGroup.trailName}$segmentInfo');
    } catch (e) {
      debugPrint('❌ HighlightedTrailOverlay load error: $e');
    }
  }

  /// Add START (green), END (red), and junction (orange) markers
  /// Junction markers show where trail segments meet or split
  Future<void> _addMarkers(MapboxMap map, List<Trail> segments) async {
    try {
      if (segments.isEmpty) return;

      final markerFeatures = <Map<String, dynamic>>[];

      // Collect all segment endpoints for junction detection
      final allEndpoints = <String, List<Map<String, dynamic>>>{};

      for (int i = 0; i < segments.length; i++) {
        final segment = segments[i];
        final coords = segment.geometry.coordinates;
        if (coords.isEmpty) continue;

        final startCoord = [
          (coords.first[0] as num).toDouble(),
          (coords.first[1] as num).toDouble(),
        ];
        final endCoord = [
          (coords.last[0] as num).toDouble(),
          (coords.last[1] as num).toDouble(),
        ];

        // Create key for endpoint (rounded to ~10m precision for matching)
        final startKey =
            '${(startCoord[0] * 10000).round()},${(startCoord[1] * 10000).round()}';
        final endKey =
            '${(endCoord[0] * 10000).round()},${(endCoord[1] * 10000).round()}';

        // Track endpoints
        allEndpoints.putIfAbsent(startKey, () => []);
        allEndpoints[startKey]!.add({
          'coord': startCoord,
          'segment': i,
          'isStart': true,
        });

        allEndpoints.putIfAbsent(endKey, () => []);
        allEndpoints[endKey]!.add({
          'coord': endCoord,
          'segment': i,
          'isStart': false,
        });
      }

      // Find true start and end points (endpoints that only appear once)
      // and junction points (endpoints that appear multiple times)
      final trueEndpoints = <Map<String, dynamic>>[];
      final junctions = <List<double>>[];

      for (final entry in allEndpoints.entries) {
        final points = entry.value;
        if (points.length == 1) {
          // This is a true endpoint (start or end of trail)
          trueEndpoints.add(points.first);
        } else if (points.length >= 2) {
          // This is a junction where segments meet
          junctions.add(points.first['coord'] as List<double>);
        }
      }

      // Determine which endpoints are START and END
      // For simplicity, use first segment's start as START, last segment's end as END
      if (segments.isNotEmpty) {
        final firstSegment = segments.first;
        final lastSegment = segments.last;

        if (firstSegment.geometry.coordinates.isNotEmpty) {
          final startCoord = firstSegment.geometry.coordinates.first;
          markerFeatures.add({
            'type': 'Feature',
            'id': 'start-marker',
            'geometry': {
              'type': 'Point',
              'coordinates': [
                (startCoord[0] as num).toDouble(),
                (startCoord[1] as num).toDouble(),
              ],
            },
            'properties': {'marker_type': 'start'},
          });
        }

        if (lastSegment.geometry.coordinates.isNotEmpty) {
          final endCoord = lastSegment.geometry.coordinates.last;
          markerFeatures.add({
            'type': 'Feature',
            'id': 'end-marker',
            'geometry': {
              'type': 'Point',
              'coordinates': [
                (endCoord[0] as num).toDouble(),
                (endCoord[1] as num).toDouble(),
              ],
            },
            'properties': {'marker_type': 'end'},
          });
        }
      }

      // Add junction markers (where segments meet)
      for (int i = 0; i < junctions.length; i++) {
        markerFeatures.add({
          'type': 'Feature',
          'id': 'junction-$i',
          'geometry': {
            'type': 'Point',
            'coordinates': junctions[i],
          },
          'properties': {'marker_type': 'junction'},
        });
      }

      if (markerFeatures.isEmpty) return;

      final markersGeoJson = {
        'type': 'FeatureCollection',
        'features': markerFeatures,
      };

      // Add markers source
      await map.style.addSource(
        GeoJsonSource(
          id: markersSourceId,
          data: jsonEncode(markersGeoJson),
        ),
      );

      // Add START marker layer (green)
      await map.style.addLayer(
        CircleLayer(
          id: startMarkerId,
          sourceId: markersSourceId,
          circleRadius: 8.0,
          circleColor: 0xFF4CAF50, // Green
          circleStrokeWidth: 2.0,
          circleStrokeColor: 0xFFFFFFFF, // White border
          filter: ['==', ['get', 'marker_type'], 'start'],
        ),
      );

      // Add END marker layer (red)
      await map.style.addLayer(
        CircleLayer(
          id: endMarkerId,
          sourceId: markersSourceId,
          circleRadius: 8.0,
          circleColor: 0xFFF44336, // Red
          circleStrokeWidth: 2.0,
          circleStrokeColor: 0xFFFFFFFF, // White border
          filter: ['==', ['get', 'marker_type'], 'end'],
        ),
      );

      // Add junction marker layer (orange) - smaller dots where segments connect
      if (junctions.isNotEmpty) {
        await map.style.addLayer(
          CircleLayer(
            id: junctionMarkerId,
            sourceId: markersSourceId,
            circleRadius: 5.0,
            circleColor: 0xFFFF9800, // Orange
            circleStrokeWidth: 1.5,
            circleStrokeColor: 0xFFFFFFFF, // White border
            filter: ['==', ['get', 'marker_type'], 'junction'],
          ),
        );
      }

      final junctionInfo =
          junctions.isNotEmpty ? ', ${junctions.length} junctions' : '';
      debugPrint('✅ Markers added: START, END$junctionInfo');
    } catch (e) {
      debugPrint('❌ Error adding markers: $e');
    }
  }

  /// Remove existing layers and sources to prevent "already exists" errors
  Future<void> _removeExistingLayersAndSources(MapboxMap map) async {
    // Remove layers first (in reverse order of creation)
    try {
      await map.style.removeStyleLayer(junctionMarkerId);
    } catch (_) {}
    try {
      await map.style.removeStyleLayer(endMarkerId);
    } catch (_) {}
    try {
      await map.style.removeStyleLayer(startMarkerId);
    } catch (_) {}
    try {
      await map.style.removeStyleLayer(lineLayerId);
    } catch (_) {}

    // Remove sources
    try {
      await map.style.removeStyleSource(markersSourceId);
    } catch (_) {}
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
      debugPrint('✅ HighlightedTrailOverlay unloaded');
    } catch (e) {
      debugPrint('❌ HighlightedTrailOverlay unload error: $e');
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
      await map.style.setStyleLayerProperty(
        startMarkerId,
        'visibility',
        visibility,
      );
      await map.style.setStyleLayerProperty(
        endMarkerId,
        'visibility',
        visibility,
      );
      // Junction markers may not exist for single-segment trails
      try {
        await map.style.setStyleLayerProperty(
          junctionMarkerId,
          'visibility',
          visibility,
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('❌ HighlightedTrailOverlay visibility error: $e');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HighlightedTrailOverlay &&
          runtimeType == other.runtimeType &&
          trailGroup == other.trailGroup;

  @override
  int get hashCode => trailGroup.hashCode;
}
