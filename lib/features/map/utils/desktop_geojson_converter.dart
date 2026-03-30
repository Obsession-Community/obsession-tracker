import 'dart:math' as math;

import 'package:obsession_tracker/core/models/cell_tower.dart';
import 'package:obsession_tracker/core/models/custom_marker.dart';
import 'package:obsession_tracker/core/models/historical_place.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/models/trail.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';

/// Utility class for converting map overlay models to GeoJSON format
/// for use with the desktop WebView map (Mapbox GL JS).
class DesktopGeoJsonConverter {
  /// Map of type codes to simple symbols that render reliably in Mapbox GL JS.
  /// These are all within the Basic Multilingual Plane (BMP).
  static const Map<String, String> _typeSymbols = {
    // Historic
    'MINE': '⚒',      // U+2692 Hammer and pick
    'LOCALE': '⌂',    // U+2302 House
    'CEMETERY': '✝',  // U+271D Latin cross
    'POST_OFFICE': '✉', // U+2709 Envelope
    // Cultural
    'CHURCH': '†',    // U+2020 Dagger (cross-like)
    'SCHOOL': '✎',    // U+270E Pencil
    'POPULATED': '⌂', // U+2302 House
    // Water
    'STREAM': '〜',   // U+301C Wave dash
    'LAKE': '○',      // U+25CB Circle
    'SPRING': '◎',    // U+25CE Bullseye
    'FALLS': '▼',     // U+25BC Triangle down
    'RAPIDS': '≈',    // U+2248 Almost equal
    'BEND': '↩',      // U+21A9 Arrow hook left
    // Terrain
    'SUMMIT': '▲',    // U+25B2 Triangle up
    'VALLEY': '▽',    // U+25BD Triangle down outline
    'RIDGE': '∧',     // U+2227 Wedge
    'GAP': '⌒',       // U+2312 Arc
    'BASIN': '∪',     // U+222A Union
    'FLAT': '▬',      // U+25AC Rectangle
    'CLIFF': '▌',     // U+258C Left half block
    'OTHER': '●',     // U+25CF Circle
  };

  /// Get a reliable symbol for a place type code.
  /// Falls back to a circle if type not found.
  static String _getSymbolForType(String? typeCode) {
    if (typeCode == null) return '●';
    return _typeSymbols[typeCode] ?? '●';
  }

  /// Sanitize emoji for Mapbox GL JS which doesn't support glyphs > 65535
  /// (Unicode codepoints outside the Basic Multilingual Plane).
  /// Returns a safe fallback emoji if the original contains unsupported characters.
  static String _sanitizeEmoji(String emoji, {String? typeCode}) {
    // First, check if we have a known type symbol
    if (typeCode != null && _typeSymbols.containsKey(typeCode)) {
      return _typeSymbols[typeCode]!;
    }

    // Check if any codepoint exceeds 65535 (BMP limit)
    for (final codeUnit in emoji.codeUnits) {
      // Surrogate pairs indicate codepoints > 65535
      if (codeUnit >= 0xD800 && codeUnit <= 0xDFFF) {
        // This is a surrogate pair, emoji is outside BMP
        // Return a simple fallback marker
        return '●';
      }
    }
    return emoji;
  }

  /// Convert a list of LandOwnership objects to a GeoJSON FeatureCollection
  /// Handles MultiPolygon parcels by splitting them into separate Polygon features
  static Map<String, dynamic> landOwnershipToGeoJson(
    List<LandOwnership> parcels,
  ) {
    final features = <Map<String, dynamic>>[];

    for (final parcel in parcels) {
      if (parcel.polygonCoordinates == null ||
          parcel.polygonCoordinates!.isEmpty) {
        continue;
      }

      // Determine color based on ownership type
      final color = _getLandOwnershipColor(parcel.ownershipType);

      // Split MultiPolygon into separate Polygon features to avoid rendering artifacts
      final polygons = _splitMultiPolygonCoordinates(parcel.polygonCoordinates!);

      for (var i = 0; i < polygons.length; i++) {
        // Use unique ID for each part of a multi-polygon
        final featureId = polygons.length > 1 ? '${parcel.id}_part_$i' : parcel.id;

        features.add({
          'type': 'Feature',
          'id': featureId,
          'geometry': {
            'type': 'Polygon',
            'coordinates': polygons[i],
          },
          'properties': {
            'id': parcel.id, // Keep original ID for tap handling
            'ownershipType': parcel.ownershipType.name,
            'ownerName': parcel.ownerName,
            'agencyName': parcel.agencyName,
            'unitName': parcel.unitName,
            'accessType': parcel.accessType.name,
            'color': color,
            'designation': parcel.designation,
          },
        });
      }
    }

    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  /// Split MultiPolygon coordinates into separate Polygon coordinate arrays
  /// Some parcels (like BLM, State Trust Lands) consist of multiple disconnected areas
  /// stored as separate rings. This splits them into individual polygons for correct rendering.
  static List<List<List<List<double>>>> _splitMultiPolygonCoordinates(
    List<List<List<double>>> coordinates,
  ) {
    // If only one ring, it's a simple polygon
    if (coordinates.length <= 1) {
      return [coordinates];
    }
    // Multiple rings - treat each as a separate polygon
    // (This handles the case where disconnected areas are stored as multiple outer rings)
    return coordinates.map((ring) => [ring]).toList();
  }

  /// Convert a list of Trail objects to a GeoJSON FeatureCollection
  static Map<String, dynamic> trailsToGeoJson(List<Trail> trails) {
    final features = <Map<String, dynamic>>[];

    for (final trail in trails) {
      // Determine color based on trail type
      final color = _getTrailColor(trail.trailType);

      features.add({
        'type': 'Feature',
        'id': trail.id,
        'geometry': {
          'type': trail.geometry.type,
          'coordinates': trail.geometry.rawCoordinates,
        },
        'properties': {
          'id': trail.id,
          'name': trail.trailName,
          'trailNumber': trail.trailNumber,
          'trailType': trail.trailType,
          'trailClass': trail.trailClass,
          'difficulty': trail.difficulty,
          'lengthMiles': trail.lengthMiles,
          'managingAgency': trail.managingAgency,
          'color': color,
        },
      });
    }

    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  /// Convert a list of HistoricalPlace objects to a GeoJSON FeatureCollection
  static Map<String, dynamic> historicalPlacesToGeoJson(
    List<HistoricalPlace> places,
  ) {
    final features = <Map<String, dynamic>>[];

    for (final place in places) {
      // Use the built-in toGeoJsonFeature method
      final feature = place.toGeoJsonFeature();
      // Replace emoji with reliable symbol for Mapbox GL JS compatibility
      if (feature['properties'] != null) {
        final typeCode = feature['properties']['place_type'] as String?;
        feature['properties']['emoji'] = _getSymbolForType(typeCode);
      }
      features.add(feature);
    }

    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  /// Convert a list of CustomMarker objects to a GeoJSON FeatureCollection
  static Map<String, dynamic> customMarkersToGeoJson(
    List<CustomMarker> markers,
  ) {
    final features = <Map<String, dynamic>>[];

    for (final marker in markers) {
      // Use the built-in toGeoJsonFeature method
      final feature = marker.toGeoJsonFeature();
      // Sanitize emoji for Mapbox GL JS compatibility (no type code for custom markers)
      if (feature['properties'] != null &&
          feature['properties']['emoji'] != null) {
        feature['properties']['emoji'] =
            _sanitizeEmoji(feature['properties']['emoji'] as String);
      }
      features.add(feature);
    }

    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  /// Convert a list of Waypoint objects to a GeoJSON FeatureCollection
  static Map<String, dynamic> waypointsToGeoJson(List<Waypoint> waypoints) {
    final features = <Map<String, dynamic>>[];

    for (final waypoint in waypoints) {
      final color = waypoint.type.colorHex;

      features.add({
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
          'name': waypoint.displayName,
          'type': waypoint.type.name,
          'color': color,
          'hasNotes': waypoint.notes != null && waypoint.notes!.isNotEmpty,
          'sessionId': waypoint.sessionId,
        },
      });
    }

    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  /// Convert breadcrumb coordinates to a GeoJSON LineString FeatureCollection
  /// [coordinates] is a list of [latitude, longitude] pairs
  /// [color] is the hex color for the trail line
  static Map<String, dynamic> breadcrumbsToGeoJson(
    List<List<double>> coordinates, {
    String color = '#FF6B35',
    String? sessionId,
  }) {
    if (coordinates.isEmpty) {
      return {
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      };
    }

    // Convert [lat, lng] pairs to GeoJSON [lng, lat] format
    final geoJsonCoordinates = coordinates
        .map((coord) => [coord[1], coord[0]]) // [lng, lat] for GeoJSON
        .toList();

    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'id': sessionId ?? 'breadcrumbs',
          'geometry': {
            'type': 'LineString',
            'coordinates': geoJsonCoordinates,
          },
          'properties': {
            'color': color,
            'sessionId': sessionId,
          },
        },
      ],
    };
  }

  /// Get color for land ownership type
  static String _getLandOwnershipColor(LandOwnershipType type) {
    switch (type) {
      // Federal lands
      case LandOwnershipType.federalLand:
        return '#556B2F'; // Dark olive green
      case LandOwnershipType.nationalForest:
        return '#228B22'; // Forest green
      case LandOwnershipType.nationalPark:
        return '#006400'; // Dark green
      case LandOwnershipType.nationalWildlifeRefuge:
        return '#4682B4'; // Steel blue
      case LandOwnershipType.bureauOfLandManagement:
        return '#DAA520'; // Goldenrod
      case LandOwnershipType.nationalMonument:
        return '#2E8B57'; // Sea green
      case LandOwnershipType.nationalRecreationArea:
        return '#3CB371'; // Medium sea green

      // State lands
      case LandOwnershipType.stateLand:
        return '#8FBC8F'; // Dark sea green
      case LandOwnershipType.stateForest:
        return '#2E8B57'; // Sea green
      case LandOwnershipType.statePark:
        return '#32CD32'; // Lime green
      case LandOwnershipType.stateWildlifeArea:
        return '#66CDAA'; // Medium aquamarine

      // Local government
      case LandOwnershipType.countyLand:
        return '#DEB887'; // Burlywood
      case LandOwnershipType.cityLand:
        return '#D2B48C'; // Tan

      // Tribal
      case LandOwnershipType.tribalLand:
        return '#CD853F'; // Peru

      // Private
      case LandOwnershipType.privateLand:
        return '#FFB6C1'; // Light pink

      // NGO Conservation
      case LandOwnershipType.ngoConservation:
        return '#98FB98'; // Pale green

      // Special designations
      case LandOwnershipType.wilderness:
        return '#006400'; // Dark green
      case LandOwnershipType.wildlifeManagementArea:
        return '#228B22'; // Forest green
      case LandOwnershipType.conservationEasement:
        return '#90EE90'; // Light green

      // Unknown
      case LandOwnershipType.unknown:
        return '#C0C0C0'; // Silver
    }
  }

  /// Get color for trail type
  static String _getTrailColor(String trailType) {
    switch (trailType.toUpperCase()) {
      case 'TERRA':
        return '#8B4513'; // Saddle brown (hiking trails)
      case 'SNOW':
        return '#87CEEB'; // Sky blue (snow trails)
      case 'WATER':
        return '#4169E1'; // Royal blue (water trails)
      case 'BICYCLE':
        return '#FF8C00'; // Dark orange (bike trails)
      case 'ROAD':
        return '#696969'; // Dim gray (road trails)
      default:
        return '#8B4513'; // Default to brown
    }
  }

  /// Convert a list of CellTower objects to GeoJSON for coverage polygons
  /// Returns a FeatureCollection of circle polygons representing coverage areas
  static Map<String, dynamic> cellTowerCoverageToGeoJson(List<CellTower> towers) {
    final features = <Map<String, dynamic>>[];

    for (final tower in towers) {
      final polygon = _createCirclePolygon(
        tower.latitude,
        tower.longitude,
        tower.effectiveRangeMeters.toDouble(),
      );
      features.add({
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
      });
    }

    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  /// Convert a list of CellTower objects to GeoJSON for tower point markers
  /// Returns a FeatureCollection of points at tower locations
  static Map<String, dynamic> cellTowerPointsToGeoJson(List<CellTower> towers) {
    final features = towers.map((tower) => tower.toGeoJsonFeature()).toList();
    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  /// Create a polygon approximating a circle at the given center with radius in meters
  /// Returns a list of [lng, lat] coordinates forming the polygon ring
  static List<List<double>> _createCirclePolygon(
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
}
