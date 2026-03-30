import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/models/trail.dart';

/// Utility for building GeoJSON strings in background isolates
///
/// This prevents UI jank when processing large datasets (1000+ parcels/trails)
/// by moving the CPU-intensive GeoJSON encoding off the main thread.
class GeoJsonBuilder {
  /// Build land ownership GeoJSON in a background isolate
  ///
  /// Returns the encoded GeoJSON string ready for Mapbox, or null if no valid features.
  static Future<String?> buildLandOwnershipGeoJson({
    required List<LandOwnership> parcels,
    required double fillOpacity,
    required int Function(String?, LandOwnershipType) getAgencyColor,
  }) async {
    if (parcels.isEmpty) return null;

    // Prepare serializable data for the isolate
    final parcelData = parcels
        .where((p) => p.polygonCoordinates != null && p.polygonCoordinates!.isNotEmpty)
        .map((p) => _LandParcelData(
              id: p.id,
              ownerName: p.ownerName,
              ownershipType: p.ownershipType.name,
              accessType: p.accessType.name,
              unitName: p.unitName,
              designation: p.designation,
              polygonCoordinates: p.polygonCoordinates!,
              agencyColor: getAgencyColor(p.ownerName, p.ownershipType),
            ))
        .toList();

    if (parcelData.isEmpty) return null;

    // Run GeoJSON building in background isolate
    return compute(
      _buildLandGeoJsonIsolate,
      _LandGeoJsonParams(parcels: parcelData, fillOpacity: fillOpacity),
    );
  }

  /// Filter trails in a background isolate to prevent UI jank
  ///
  /// This moves the O(n) filtering and viewport bounds checking off the main thread.
  /// Returns a tuple of (viewportFilteredTrails, allFilteredTrails).
  static Future<TrailFilterResult> filterTrailsInBackground({
    required List<Trail> trails,
    required Set<String> enabledSources,
    required Set<String> enabledTypes,
    required double north,
    required double south,
    required double east,
    required double west,
  }) async {
    if (trails.isEmpty) {
      return const TrailFilterResult(viewportTrails: [], allFilteredTrails: []);
    }

    // Prepare serializable data for the isolate
    final trailData = trails.map((t) => _TrailFilterData(
      index: trails.indexOf(t),
      dataSource: t.dataSource,
      trailType: t.trailType,
      rawCoordinates: t.geometry.rawCoordinates,
    )).toList();

    final params = _TrailFilterParams(
      trails: trailData,
      enabledSources: enabledSources.toList(),
      enabledTypes: enabledTypes.toList(),
      north: north,
      south: south,
      east: east,
      west: west,
    );

    // Run filtering in background isolate
    final result = await compute(_filterTrailsIsolate, params);

    // Map indices back to Trail objects
    final viewportTrails = result.viewportIndices.map((int i) => trails[i]).toList();
    final allFilteredTrails = result.allFilteredIndices.map((int i) => trails[i]).toList();

    return TrailFilterResult(
      viewportTrails: viewportTrails,
      allFilteredTrails: allFilteredTrails,
    );
  }

  /// Build trails GeoJSON in a background isolate
  ///
  /// Returns the encoded GeoJSON string ready for Mapbox, or null if no valid features.
  static Future<String?> buildTrailsGeoJson({
    required List<Trail> trails,
  }) async {
    if (trails.isEmpty) return null;

    // Prepare serializable data for the isolate
    final trailData = trails
        .where((t) => t.geometry.coordinates.isNotEmpty)
        .map((t) => _TrailData(
              id: t.id,
              trailName: t.trailName,
              trailNumber: t.trailNumber,
              trailType: t.trailType,
              lengthMiles: t.lengthMiles,
              difficulty: t.difficulty,
              managingAgency: t.managingAgency,
              geometryType: t.geometry.type,
              rawCoordinates: t.geometry.rawCoordinates,
            ))
        .toList();

    if (trailData.isEmpty) return null;

    // Run GeoJSON building in background isolate
    return compute(_buildTrailsGeoJsonIsolate, trailData);
  }
}

// ============================================================================
// Public result classes
// ============================================================================

/// Result from trail filtering containing both viewport and all filtered trails
class TrailFilterResult {
  const TrailFilterResult({
    required this.viewportTrails,
    required this.allFilteredTrails,
  });

  final List<Trail> viewportTrails;
  final List<Trail> allFilteredTrails;
}

// ============================================================================
// Private data classes for isolate communication
// These must be simple classes that can be sent across isolate boundaries
// ============================================================================

class _TrailFilterData {
  _TrailFilterData({
    required this.index,
    required this.dataSource,
    required this.trailType,
    required this.rawCoordinates,
  });

  final int index;
  final String dataSource;
  final String trailType;
  final dynamic rawCoordinates;
}

class _TrailFilterParams {
  _TrailFilterParams({
    required this.trails,
    required this.enabledSources,
    required this.enabledTypes,
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  final List<_TrailFilterData> trails;
  final List<String> enabledSources;
  final List<String> enabledTypes;
  final double north;
  final double south;
  final double east;
  final double west;
}

class _TrailFilterResultIndices {
  _TrailFilterResultIndices({
    required this.viewportIndices,
    required this.allFilteredIndices,
  });

  final List<int> viewportIndices;
  final List<int> allFilteredIndices;
}

class _LandParcelData {
  _LandParcelData({
    required this.id,
    required this.ownerName,
    required this.ownershipType,
    required this.accessType,
    required this.unitName,
    required this.designation,
    required this.polygonCoordinates,
    required this.agencyColor,
  });

  final String id;
  final String? ownerName;
  final String ownershipType;
  final String accessType;
  final String? unitName;
  final String? designation;
  final List<List<List<double>>> polygonCoordinates;
  final int agencyColor;
}

class _LandGeoJsonParams {
  _LandGeoJsonParams({
    required this.parcels,
    required this.fillOpacity,
  });

  final List<_LandParcelData> parcels;
  final double fillOpacity;
}

class _TrailData {
  _TrailData({
    required this.id,
    required this.trailName,
    required this.trailNumber,
    required this.trailType,
    required this.lengthMiles,
    required this.difficulty,
    required this.managingAgency,
    required this.geometryType,
    required this.rawCoordinates,
  });

  final String id;
  final String trailName;
  final String? trailNumber;
  final String trailType;
  final double lengthMiles;
  final String? difficulty;
  final String? managingAgency;
  final String geometryType;
  final dynamic rawCoordinates;
}

// ============================================================================
// Isolate entry points - these run in background threads
// ============================================================================

/// Build land ownership GeoJSON in isolate (top-level function required by compute)
String _buildLandGeoJsonIsolate(_LandGeoJsonParams params) {
  final features = <Map<String, dynamic>>[];

  for (final parcel in params.parcels) {
    // Split MultiPolygon into separate Polygon features
    final polygons = _splitMultiPolygonCoordinates(parcel.polygonCoordinates);

    for (int i = 0; i < polygons.length; i++) {
      final featureId = polygons.length > 1 ? '${parcel.id}_part_$i' : parcel.id;

      features.add({
        'type': 'Feature',
        'id': featureId,
        'geometry': {
          'type': 'Polygon',
          'coordinates': polygons[i],
        },
        'properties': {
          'id': parcel.id,
          'owner_name': parcel.ownerName,
          'ownership_type': parcel.ownershipType,
          'access_type': parcel.accessType,
          'unit_name': parcel.unitName ?? '',
          'designation': parcel.designation ?? '',
          'color': _colorToRgba(parcel.agencyColor, params.fillOpacity),
        },
      });
    }
  }

  final geoJson = {
    'type': 'FeatureCollection',
    'features': features,
  };

  return jsonEncode(geoJson);
}

/// Build trails GeoJSON in isolate (top-level function required by compute)
String _buildTrailsGeoJsonIsolate(List<_TrailData> trails) {
  final features = <Map<String, dynamic>>[];

  for (final trail in trails) {
    features.add({
      'type': 'Feature',
      'id': trail.id,
      'geometry': {
        'type': trail.geometryType,
        'coordinates': trail.rawCoordinates,
      },
      'properties': {
        'id': trail.id,
        'trail_name': trail.trailName,
        'trail_number': trail.trailNumber ?? '',
        'trail_type': trail.trailType,
        'length_miles': trail.lengthMiles,
        'difficulty': trail.difficulty ?? 'Unknown',
        'managing_agency': trail.managingAgency ?? '',
      },
    });
  }

  final geoJson = {
    'type': 'FeatureCollection',
    'features': features,
  };

  return jsonEncode(geoJson);
}

/// Filter trails in isolate (top-level function required by compute)
/// Returns indices of trails that pass the filter
_TrailFilterResultIndices _filterTrailsIsolate(_TrailFilterParams params) {
  // Known trail types that must be in enabledTypes to pass
  const allKnownTypes = {
    'TERRA', 'SNOW', 'WATER',
    'BICYCLE', 'ROAD',
    'Hiker/Biker', 'Hiker/Horse', 'Hiker/Pedestrian Only',
  };

  final enabledSourcesSet = params.enabledSources.toSet();
  final enabledTypesSet = params.enabledTypes.toSet();

  final allFilteredIndices = <int>[];
  final viewportIndices = <int>[];

  for (final trail in params.trails) {
    // Check source filter
    if (!enabledSourcesSet.contains(trail.dataSource.toUpperCase())) {
      continue;
    }

    // Check type filter
    final isKnownType = allKnownTypes.contains(trail.trailType);
    if (isKnownType && !enabledTypesSet.contains(trail.trailType)) {
      continue;
    }

    // Trail passes source and type filters
    allFilteredIndices.add(trail.index);

    // Check viewport bounds
    if (_trailIntersectsBounds(
      trail.rawCoordinates,
      params.north,
      params.south,
      params.east,
      params.west,
    )) {
      viewportIndices.add(trail.index);
    }
  }

  return _TrailFilterResultIndices(
    viewportIndices: viewportIndices,
    allFilteredIndices: allFilteredIndices,
  );
}

/// Check if trail coordinates intersect viewport bounds (isolate-safe)
bool _trailIntersectsBounds(
  Object? rawCoordinates,
  double north,
  double south,
  double east,
  double west,
) {
  // Extract coordinates from raw data
  final coords = _extractCoordinates(rawCoordinates);
  if (coords.isEmpty) return false;

  // Calculate trail's bounding box
  double trailNorth = -90, trailSouth = 90;
  double trailEast = -180, trailWest = 180;

  for (final coord in coords) {
    if (coord.length < 2) continue;
    final lon = coord[0];
    final lat = coord[1];

    if (lat > trailNorth) trailNorth = lat;
    if (lat < trailSouth) trailSouth = lat;
    if (lon > trailEast) trailEast = lon;
    if (lon < trailWest) trailWest = lon;
  }

  // Check bounding box intersection
  return !(trailNorth < south ||
           trailSouth > north ||
           trailEast < west ||
           trailWest > east);
}

/// Extract coordinates from raw GeoJSON coordinate data (isolate-safe)
List<List<double>> _extractCoordinates(Object? rawCoordinates) {
  final result = <List<double>>[];
  _extractCoordsRecursive(rawCoordinates, result);
  return result;
}

void _extractCoordsRecursive(Object? data, List<List<double>> result) {
  if (data is! List || data.isEmpty) return;

  // Check if this is a coordinate pair [lon, lat]
  if (data.length >= 2 && data[0] is num && data[1] is num) {
    result.add([(data[0] as num).toDouble(), (data[1] as num).toDouble()]);
    return;
  }

  // Otherwise recurse into nested lists
  for (final item in data) {
    _extractCoordsRecursive(item, result);
  }
}

// ============================================================================
// Helper functions (duplicated here to work in isolate without imports)
// ============================================================================

/// Split MultiPolygon coordinates into separate Polygon coordinate arrays
List<List<List<List<double>>>> _splitMultiPolygonCoordinates(
  List<List<List<double>>> coordinates,
) {
  if (coordinates.length <= 1) {
    return [coordinates];
  }
  return coordinates.map((ring) => [ring]).toList();
}

/// Convert Flutter color (int) to RGBA string for Mapbox
String _colorToRgba(int colorValue, double opacity) {
  final r = (colorValue >> 16) & 0xFF;
  final g = (colorValue >> 8) & 0xFF;
  final b = colorValue & 0xFF;
  return 'rgba($r, $g, $b, $opacity)';
}
