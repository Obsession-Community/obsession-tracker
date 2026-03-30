import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/map_overlay.dart';

/// Configuration for Mapbox map widget behavior and features
class MapboxMapConfig {
  const MapboxMapConfig({
    this.initialCenter,
    this.initialZoom = 16.0,
    this.minZoom = 3.0,
    this.maxZoom = 19.0,
    this.styleUri = MapboxStyles.OUTDOORS,
    this.showCurrentLocation = true,
    this.followUserLocation = true,
    this.enableRotation = true,
    this.showCompass = true,
    this.showScaleBar = false,
    this.showAttribution = true,
    this.enableTouchToMark = false,
    this.gesturesEnabled = true,
    this.showMapControls = true,
  });

  final Point? initialCenter;
  final double initialZoom;
  final double minZoom;
  final double maxZoom;
  final String styleUri;
  final bool showCurrentLocation;
  final bool followUserLocation;
  final bool enableRotation;
  final bool showCompass;
  final bool showScaleBar;
  final bool showAttribution;
  final bool enableTouchToMark;
  final bool gesturesEnabled;
  final bool showMapControls;

  MapboxMapConfig copyWith({
    Point? initialCenter,
    double? initialZoom,
    double? minZoom,
    double? maxZoom,
    String? styleUri,
    bool? showCurrentLocation,
    bool? followUserLocation,
    bool? enableRotation,
    bool? showCompass,
    bool? showScaleBar,
    bool? showAttribution,
    bool? enableTouchToMark,
    bool? gesturesEnabled,
    bool? showMapControls,
  }) {
    return MapboxMapConfig(
      initialCenter: initialCenter ?? this.initialCenter,
      initialZoom: initialZoom ?? this.initialZoom,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      styleUri: styleUri ?? this.styleUri,
      showCurrentLocation: showCurrentLocation ?? this.showCurrentLocation,
      followUserLocation: followUserLocation ?? this.followUserLocation,
      enableRotation: enableRotation ?? this.enableRotation,
      showCompass: showCompass ?? this.showCompass,
      showScaleBar: showScaleBar ?? this.showScaleBar,
      showAttribution: showAttribution ?? this.showAttribution,
      enableTouchToMark: enableTouchToMark ?? this.enableTouchToMark,
      gesturesEnabled: gesturesEnabled ?? this.gesturesEnabled,
      showMapControls: showMapControls ?? this.showMapControls,
    );
  }
}

/// Types of map overlays that can be displayed
enum MapOverlayType {
  breadcrumbTrail,
  waypoints,
  photoMarkers,
  landOwnership,
  highlightedLandParcel,
  trails,
  highlightedTrail,
  plannedRoute,
  trailSegments,
  heatmap,
  drawingTools,
  historicalPlaces,
  customMarkers,
  sessionMarkers,
  cellCoverage,
}

/// Configuration for a specific map overlay
class MapOverlayConfig {
  const MapOverlayConfig({
    required this.type,
    this.enabled = true,
    this.zIndex = 0,
    this.opacity = 1.0,
    this.interactive = true,
    this.data,
  });

  final MapOverlayType type;
  final bool enabled;
  final int zIndex;
  final double opacity;
  final bool interactive;
  final MapOverlay? data; // The overlay instance to render

  MapOverlayConfig copyWith({
    MapOverlayType? type,
    bool? enabled,
    int? zIndex,
    double? opacity,
    bool? interactive,
    MapOverlay? data,
  }) {
    return MapOverlayConfig(
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      zIndex: zIndex ?? this.zIndex,
      opacity: opacity ?? this.opacity,
      interactive: interactive ?? this.interactive,
      data: data ?? this.data,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapOverlayConfig &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          enabled == other.enabled &&
          zIndex == other.zIndex &&
          opacity == other.opacity &&
          interactive == other.interactive &&
          data == other.data; // Uses overlay's own equality operator

  @override
  int get hashCode =>
      type.hashCode ^
      enabled.hashCode ^
      zIndex.hashCode ^
      opacity.hashCode ^
      interactive.hashCode ^
      data.hashCode;
}

/// Preset configurations for common map use cases
class MapboxPresets {
  /// Screenshot mode flag - when true, uses zoomed out view for App Store screenshots
  /// Set this before navigating to the map in integration tests
  static bool screenshotMode = false;

  /// Historical map screenshot mode - uses Yellowstone/Gallatin area with historical overlay
  static bool screenshotHistoricalMapMode = false;

  /// Zoom level for screenshots - shows regional area for App Store screenshots
  /// Zoom 5 shows ~1 state, zoom 6 shows ~half state, zoom 10 shows regional area
  /// Zoom 12 shows detailed local area with trails, land parcels, and historical places visible
  static const double screenshotZoom = 12.0;

  /// Zoom level for historical map screenshots - slightly more zoomed to show topo detail
  static const double screenshotHistoricalZoom = 11.5;

  /// Center point for screenshots - Near Zion/Bryce area, Utah
  /// This area shows varied land types: BLM, USFS, NPS, and state lands
  static Point get screenshotCenter => Point(
        coordinates: Position(-112.116, 37.577), // Near Zion/Bryce with varied land types
      );

  /// Center point for historical map screenshots - Gallatin/Yellowstone area, Wyoming
  /// This area shows the 1885 USGS Gallatin quadrangle
  static Point get screenshotHistoricalCenter => Point(
        coordinates: Position(-110.74, 44.75), // Gallatin Range near West Yellowstone
      );

  /// Tracking page configuration - follows user, shows breadcrumbs
  static const MapboxMapConfig tracking = MapboxMapConfig(
    enableTouchToMark: true,
  );

  /// Route planning configuration - allows drawing, no location following
  static const MapboxMapConfig routePlanning = MapboxMapConfig(
    followUserLocation: false,
  );

  /// Session playback configuration - centered on session bounds
  static const MapboxMapConfig sessionPlayback = MapboxMapConfig(
    followUserLocation: false,
    showCurrentLocation: false,
    showMapControls: false, // Hide control bar during playback
  );

  /// Waypoint detail configuration - centered on waypoint
  static const MapboxMapConfig waypointDetail = MapboxMapConfig(
    followUserLocation: false,
    showCurrentLocation: false,
  );
}
