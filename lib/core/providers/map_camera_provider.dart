import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for persisting map camera position across tab navigation
///
/// Stores the last known camera position so the map can restore it
/// when the user navigates back to the map tab.
final mapCameraPositionProvider =
    NotifierProvider<MapCameraPositionNotifier, MapCameraPosition?>(
        MapCameraPositionNotifier.new);

/// Represents a saved map camera position
class MapCameraPosition {
  const MapCameraPosition({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    this.bearing = 0.0,
  });

  final double latitude;
  final double longitude;
  final double zoom;
  final double bearing;

  @override
  String toString() =>
      'MapCameraPosition(lat: $latitude, lng: $longitude, zoom: $zoom, bearing: $bearing)';
}

/// Notifier for managing saved map camera position
class MapCameraPositionNotifier extends Notifier<MapCameraPosition?> {
  @override
  MapCameraPosition? build() {
    return null; // No saved position initially
  }

  /// Save the current camera position
  void savePosition({
    required double latitude,
    required double longitude,
    required double zoom,
    double bearing = 0.0,
  }) {
    state = MapCameraPosition(
      latitude: latitude,
      longitude: longitude,
      zoom: zoom,
      bearing: bearing,
    );
  }

  /// Clear the saved position (e.g., on logout)
  void clear() {
    state = null;
  }
}
