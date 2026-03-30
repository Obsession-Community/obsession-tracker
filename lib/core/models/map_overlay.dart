import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Base interface for map overlays that can be added to MapboxMapWidget
///
/// Each overlay type (breadcrumbs, waypoints, land ownership) implements this
/// interface to provide consistent loading/unloading behavior.
abstract class MapOverlay {
  /// Unique identifier for this overlay instance
  String get id;

  /// Load this overlay onto the map
  ///
  /// Called when the map style is loaded or when the overlay is added
  Future<void> load(MapboxMap map);

  /// Update this overlay with new data
  ///
  /// Called when underlying data changes (e.g., new breadcrumb points)
  Future<void> update(MapboxMap map);

  /// Remove this overlay from the map
  ///
  /// Called when the overlay is no longer needed or map is being disposed
  Future<void> unload(MapboxMap map);

  /// Whether this overlay is currently visible
  bool get isVisible;

  /// Show or hide this overlay
  Future<void> setVisibility(MapboxMap map, {required bool visible});
}
