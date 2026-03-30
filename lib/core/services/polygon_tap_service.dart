import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';

/// Service for detecting which land ownership polygons are tapped on the map
class PolygonTapService {
  /// Check if a tap point intersects with any land ownership polygons
  /// Returns the land ownership that was tapped, or null if none
  static LandOwnership? findTappedPolygon(
    LatLng tapPoint,
    List<LandOwnership> landOwnerships,
  ) {
    // Check each land ownership to see if the tap point is inside its polygon
    for (final land in landOwnerships) {
      if (_isPointInLandOwnership(tapPoint, land)) {
        return land;
      }
    }
    return null;
  }

  /// Check if a point is inside a land ownership's polygon or bounds
  static bool _isPointInLandOwnership(LatLng point, LandOwnership land) {
    // First check if point is within the general bounds for quick filtering
    final boundsContains = land.bounds.contains(LandPoint(
      latitude: point.latitude,
      longitude: point.longitude,
    ));

    // Quick bounds filter - skip if point is clearly outside
    if (!boundsContains) {
      return false;
    }

    // If we have detailed polygon coordinates, use precise polygon intersection
    if (land.polygonCoordinates != null && land.polygonCoordinates!.isNotEmpty) {
      final result = _isPointInPolygonCoordinates(point, land.polygonCoordinates!);
      if (result) {
        debugPrint('[PolygonTap] ✅ Point is INSIDE ${land.ownerName} (detailed polygon)');
      }
      return result;
    }

    // Fallback to bounds check (always true at this point since we passed the bounds check above)
    debugPrint('[PolygonTap] ⚠️ Using bounds check for ${land.ownerName} (no detailed coords)');
    return true;
  }

  /// Check if a point is inside polygon coordinates using ray casting algorithm
  static bool _isPointInPolygonCoordinates(
    LatLng point,
    List<List<List<double>>> polygonCoordinates,
  ) {
    // Handle MultiPolygon - check if point is in any of the polygons
    // Use early return optimization to avoid checking all parts unnecessarily
    for (int polyIdx = 0; polyIdx < polygonCoordinates.length; polyIdx++) {
      final polygon = polygonCoordinates[polyIdx];
      if (polygon.isEmpty) continue;

      // Handle the actual structure - polygon is List<List<double>>
      // Each element is a ring, first ring is outer boundary
      try {
        // Convert to proper ring structure - each ring is List<List<double>>
        final List<List<double>> outerRing = [];
        for (final coord in polygon) {
          // coord should be [longitude, latitude]
          if (coord.length >= 2) {
            outerRing.add([
              (coord[0] as num).toDouble(),
              (coord[1] as num).toDouble(),
            ]);
          }
                }

        if (outerRing.length >= 3) {
          if (_isPointInRing(point, outerRing)) {
            // Only log when we find a match
            debugPrint('[PolygonTap] ✅ Point is inside polygon part $polyIdx');
            return true;
          }
        }
      } catch (e) {
        // Only log errors, not normal flow
        debugPrint('[PolygonTap] Error parsing polygon $polyIdx: $e');
        continue;
      }
    }

    return false;
  }

  /// Check if a point is inside a polygon ring using ray casting algorithm
  static bool _isPointInRing(LatLng point, List<List<double>> ring) {
    if (ring.length < 3) return false; // Not a valid polygon

    int intersectionCount = 0;
    final double x = point.longitude;
    final double y = point.latitude;

    for (int i = 0; i < ring.length; i++) {
      final j = (i + 1) % ring.length;

      // Get coordinates (GeoJSON format: [longitude, latitude])
      final double xi = ring[i][0];
      final double yi = ring[i][1];
      final double xj = ring[j][0];
      final double yj = ring[j][1];

      // Check if point is exactly on a vertex
      if ((xi == x && yi == y) || (xj == x && yj == y)) {
        return true;
      }

      // Ray casting: count intersections with horizontal ray to the right
      if (((yi > y) != (yj > y)) &&
          (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
        intersectionCount++;
      }
    }

    // Point is inside if intersection count is odd
    return (intersectionCount % 2) == 1;
  }

  /// Get all land ownerships that contain a specific point
  /// Useful for overlapping polygons
  static List<LandOwnership> findAllContainingPolygons(
    LatLng tapPoint,
    List<LandOwnership> landOwnerships,
  ) {
    final containingPolygons = <LandOwnership>[];

    for (final land in landOwnerships) {
      if (_isPointInLandOwnership(tapPoint, land)) {
        containingPolygons.add(land);
      }
    }

    // Sort by area (smallest first) to prioritize more specific polygons
    containingPolygons.sort((a, b) => a.bounds.area.compareTo(b.bounds.area));

    return containingPolygons;
  }

  /// Find the most specific (smallest area) land ownership at a point
  /// Useful when multiple polygons overlap
  static LandOwnership? findMostSpecificPolygon(
    LatLng tapPoint,
    List<LandOwnership> landOwnerships,
  ) {
    final containing = findAllContainingPolygons(tapPoint, landOwnerships);
    return containing.isNotEmpty ? containing.first : null;
  }

  /// Calculate distance from a point to the nearest edge of a polygon
  /// Useful for tap tolerance (finding nearby polygons even if not exactly inside)
  static double distanceToPolygon(LatLng point, LandOwnership land) {
    // If point is inside, distance is 0
    if (_isPointInLandOwnership(point, land)) {
      return 0.0;
    }

    // If we have detailed coordinates, calculate distance to nearest edge
    if (land.polygonCoordinates != null && land.polygonCoordinates!.isNotEmpty) {
      return _distanceToPolygonCoordinates(point, land.polygonCoordinates!);
    }

    // Fallback to distance to bounds rectangle
    return _distanceToBounds(point, land.bounds);
  }

  /// Calculate distance to polygon coordinates
  static double _distanceToPolygonCoordinates(
    LatLng point,
    List<List<List<double>>> polygonCoordinates,
  ) {
    double minDistance = double.infinity;

    for (final polygon in polygonCoordinates) {
      if (polygon.isNotEmpty) {
        // Check distance to outer ring
        final ringDistance = _distanceToRing(point, polygon[0].cast<List<double>>());
        if (ringDistance < minDistance) {
          minDistance = ringDistance;
        }
      }
    }

    return minDistance;
  }

  /// Calculate distance to a polygon ring
  static double _distanceToRing(LatLng point, List<List<double>> ring) {
    if (ring.length < 2) return double.infinity;

    double minDistance = double.infinity;

    for (int i = 0; i < ring.length - 1; i++) {
      final p1 = LatLng(ring[i][1], ring[i][0]); // [lon, lat] -> LatLng(lat, lon)
      final p2 = LatLng(ring[i + 1][1], ring[i + 1][0]);

      final distance = _distanceToLineSegment(point, p1, p2);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }

  /// Calculate distance from point to bounds rectangle
  static double _distanceToBounds(LatLng point, LandBounds bounds) {
    final double x = point.longitude;
    final double y = point.latitude;

    // If point is inside bounds, distance is 0
    if (bounds.contains(LandPoint(latitude: y, longitude: x))) {
      return 0.0;
    }

    // Calculate distance to nearest edge of rectangle
    double dx = 0.0;
    double dy = 0.0;

    if (x < bounds.west) {
      dx = bounds.west - x;
    } else if (x > bounds.east) {
      dx = x - bounds.east;
    }

    if (y < bounds.south) {
      dy = bounds.south - y;
    } else if (y > bounds.north) {
      dy = y - bounds.north;
    }

    // Convert to meters (approximate)
    return math.sqrt(dx * dx + dy * dy) * 111000; // ~111km per degree
  }

  /// Calculate distance from point to line segment
  static double _distanceToLineSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    const Distance distance = Distance();

    // If line segment is just a point
    if (lineStart.latitude == lineEnd.latitude && lineStart.longitude == lineEnd.longitude) {
      return distance.as(LengthUnit.Meter, point, lineStart);
    }

    // Calculate the projection of point onto the line segment
    final double A = point.longitude - lineStart.longitude;
    final double B = point.latitude - lineStart.latitude;
    final double C = lineEnd.longitude - lineStart.longitude;
    final double D = lineEnd.latitude - lineStart.latitude;

    final double dot = A * C + B * D;
    final double lenSq = C * C + D * D;

    if (lenSq == 0) {
      return distance.as(LengthUnit.Meter, point, lineStart);
    }

    final double param = dot / lenSq;

    LatLng closestPoint;
    if (param < 0) {
      closestPoint = lineStart;
    } else if (param > 1) {
      closestPoint = lineEnd;
    } else {
      closestPoint = LatLng(
        lineStart.latitude + param * D,
        lineStart.longitude + param * C,
      );
    }

    return distance.as(LengthUnit.Meter, point, closestPoint);
  }

  /// Find polygons within a certain distance (tap tolerance)
  static List<LandOwnership> findPolygonsWithinDistance(
    LatLng tapPoint,
    List<LandOwnership> landOwnerships,
    double maxDistanceMeters,
  ) {
    final nearby = <LandOwnership>[];

    for (final land in landOwnerships) {
      final distance = distanceToPolygon(tapPoint, land);
      if (distance <= maxDistanceMeters) {
        nearby.add(land);
      }
    }

    // Sort by distance (closest first)
    nearby.sort((a, b) {
      final distA = distanceToPolygon(tapPoint, a);
      final distB = distanceToPolygon(tapPoint, b);
      return distA.compareTo(distB);
    });

    return nearby;
  }
}