import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/location_service.dart';
import 'package:uuid/uuid.dart';

/// Service for managing waypoints with enhanced location data integration.
///
/// Provides high-level operations for creating, updating, and managing waypoints
/// with integration to the enhanced location service from Phase 1.
class WaypointService {
  WaypointService._();
  static WaypointService? _instance;
  static WaypointService get instance => _instance ??= WaypointService._();

  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();
  final Uuid _uuid = const Uuid();

  /// Create a waypoint at the current location
  Future<Waypoint> createWaypointAtCurrentLocation({
    required String sessionId,
    required WaypointType type,
    String? name,
    String? notes,
  }) async {
    try {
      // Get current enhanced location data
      final EnhancedLocationData? enhancedLocation =
          _locationService.lastEnhancedLocation;

      if (enhancedLocation == null) {
        throw Exception('No location data available');
      }

      final Position position = enhancedLocation.position;

      // Create waypoint with enhanced location data
      final Waypoint waypoint = Waypoint.fromLocation(
        id: _uuid.v4(),
        latitude: position.latitude,
        longitude: position.longitude,
        type: type,
        timestamp: DateTime.now(),
        sessionId: sessionId,
        name: name,
        notes: notes,
        altitude: enhancedLocation.bestAltitude,
        accuracy: position.accuracy,
        speed: enhancedLocation.bestSpeed,
        heading: enhancedLocation.bestHeading,
      );

      // Save to database
      await _databaseService.insertWaypoint(waypoint);

      debugPrint('Created waypoint: ${waypoint.id} at ${waypoint.coordinates}');
      return waypoint;
    } catch (e) {
      debugPrint('Error creating waypoint at current location: $e');
      rethrow;
    }
  }

  /// Create a waypoint at specific coordinates
  ///
  /// If [sessionId] is null, creates a standalone waypoint not associated with
  /// any tracking session.
  Future<Waypoint> createWaypointAtCoordinates({
    String? sessionId,
    required double latitude,
    required double longitude,
    required WaypointType type,
    String? name,
    String? notes,
    double? altitude,
    double? accuracy,
  }) async {
    try {
      final Waypoint waypoint = Waypoint.fromLocation(
        id: _uuid.v4(),
        latitude: latitude,
        longitude: longitude,
        type: type,
        timestamp: DateTime.now(),
        sessionId: sessionId,
        name: name,
        notes: notes,
        altitude: altitude,
        accuracy: accuracy,
      );

      await _databaseService.insertWaypoint(waypoint);

      debugPrint('Created waypoint: ${waypoint.id} at ($latitude, $longitude)');
      return waypoint;
    } catch (e) {
      debugPrint('Error creating waypoint at coordinates: $e');
      rethrow;
    }
  }

  /// Update an existing waypoint
  Future<Waypoint> updateWaypoint(Waypoint waypoint) async {
    try {
      await _databaseService.updateWaypoint(waypoint);
      debugPrint('Updated waypoint: ${waypoint.id}');
      return waypoint;
    } catch (e) {
      debugPrint('Error updating waypoint: $e');
      rethrow;
    }
  }

  /// Get a waypoint by ID
  Future<Waypoint?> getWaypoint(String waypointId) async {
    try {
      return await _databaseService.getWaypoint(waypointId);
    } catch (e) {
      debugPrint('Error getting waypoint: $e');
      rethrow;
    }
  }

  /// Get all waypoints for a session
  Future<List<Waypoint>> getWaypointsForSession(String sessionId) async {
    try {
      return await _databaseService.getWaypointsForSession(sessionId);
    } catch (e) {
      debugPrint('Error getting waypoints for session: $e');
      rethrow;
    }
  }

  /// Get waypoints by type for a session
  Future<List<Waypoint>> getWaypointsByType({
    required String sessionId,
    required WaypointType type,
  }) async {
    try {
      return await _databaseService.getWaypointsByType(
        sessionId: sessionId,
        type: type,
      );
    } catch (e) {
      debugPrint('Error getting waypoints by type: $e');
      rethrow;
    }
  }

  /// Get waypoints within a geographic area
  Future<List<Waypoint>> getWaypointsInArea({
    required String sessionId,
    required LatLng center,
    required double radiusMeters,
  }) async {
    try {
      // Calculate approximate lat/lng bounds
      final double latDelta =
          radiusMeters / 111320; // Approximate meters per degree latitude
      final double lngDelta =
          radiusMeters / (111320 * cos(center.latitude * pi / 180));

      return await _databaseService.getWaypointsInArea(
        sessionId: sessionId,
        minLatitude: center.latitude - latDelta,
        maxLatitude: center.latitude + latDelta,
        minLongitude: center.longitude - lngDelta,
        maxLongitude: center.longitude + lngDelta,
      );
    } catch (e) {
      debugPrint('Error getting waypoints in area: $e');
      rethrow;
    }
  }

  /// Find waypoints near a location
  Future<List<Waypoint>> findNearbyWaypoints({
    required String sessionId,
    required LatLng location,
    required double maxDistanceMeters,
    WaypointType? type,
  }) async {
    try {
      // Get waypoints in the general area first
      final List<Waypoint> areaWaypoints = await getWaypointsInArea(
        sessionId: sessionId,
        center: location,
        radiusMeters: maxDistanceMeters,
      );

      // Filter by exact distance and type
      final List<Waypoint> nearbyWaypoints = <Waypoint>[];

      for (final Waypoint waypoint in areaWaypoints) {
        final double distance = waypoint.distanceToCoordinates(location);

        if (distance <= maxDistanceMeters) {
          if (type == null || waypoint.type == type) {
            nearbyWaypoints.add(waypoint);
          }
        }
      }

      // Sort by distance
      nearbyWaypoints.sort((Waypoint a, Waypoint b) {
        final double distanceA = a.distanceToCoordinates(location);
        final double distanceB = b.distanceToCoordinates(location);
        return distanceA.compareTo(distanceB);
      });

      return nearbyWaypoints;
    } catch (e) {
      debugPrint('Error finding nearby waypoints: $e');
      rethrow;
    }
  }

  /// Delete a waypoint
  Future<void> deleteWaypoint(String waypointId) async {
    try {
      await _databaseService.deleteWaypoint(waypointId);
      debugPrint('Deleted waypoint: $waypointId');
    } catch (e) {
      debugPrint('Error deleting waypoint: $e');
      rethrow;
    }
  }

  /// Delete all waypoints for a session
  Future<void> deleteWaypointsForSession(String sessionId) async {
    try {
      await _databaseService.deleteWaypointsForSession(sessionId);
      debugPrint('Deleted all waypoints for session: $sessionId');
    } catch (e) {
      debugPrint('Error deleting waypoints for session: $e');
      rethrow;
    }
  }

  /// Get waypoint statistics for a session
  Future<Map<WaypointType, int>> getWaypointStatistics(String sessionId) async {
    try {
      final List<Waypoint> waypoints = await getWaypointsForSession(sessionId);
      final Map<WaypointType, int> stats = <WaypointType, int>{};

      // Initialize all types with 0
      for (final WaypointType type in WaypointType.values) {
        stats[type] = 0;
      }

      // Count waypoints by type
      for (final Waypoint waypoint in waypoints) {
        stats[waypoint.type] = (stats[waypoint.type] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      debugPrint('Error getting waypoint statistics: $e');
      rethrow;
    }
  }

  /// Check if location has good accuracy for waypoint creation
  bool hasGoodLocationAccuracy() {
    final EnhancedLocationData? enhancedLocation =
        _locationService.lastEnhancedLocation;

    return enhancedLocation?.hasGoodAccuracy ?? false;
  }

  /// Get current location accuracy description
  String getCurrentLocationAccuracyDescription() {
    final EnhancedLocationData? enhancedLocation =
        _locationService.lastEnhancedLocation;

    if (enhancedLocation == null) return 'No location data';

    final double accuracy = enhancedLocation.position.accuracy;
    if (accuracy <= 3) return 'Excellent';
    if (accuracy <= 5) return 'Good';
    if (accuracy <= 10) return 'Fair';
    if (accuracy <= 20) return 'Poor';
    return 'Very Poor';
  }
}
