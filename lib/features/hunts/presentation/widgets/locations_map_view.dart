import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/mapbox_config.dart';
import 'package:obsession_tracker/core/models/treasure_hunt.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/mapbox_map_widget.dart';

/// Map view showing all hunt locations as colored pins by status
class LocationsMapView extends ConsumerStatefulWidget {
  const LocationsMapView({
    super.key,
    required this.locations,
    required this.onLocationTap,
  });

  final List<HuntLocation> locations;
  final void Function(HuntLocation location) onLocationTap;

  @override
  ConsumerState<LocationsMapView> createState() => _LocationsMapViewState();
}

class _LocationsMapViewState extends ConsumerState<LocationsMapView> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleManager;
  PointAnnotationManager? _labelManager;
  Cancelable? _tapCancelable;
  final Map<String, HuntLocation> _annotationIdToLocation = {};

  @override
  void didUpdateWidget(LocationsMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild markers if locations changed
    if (widget.locations != oldWidget.locations) {
      _updateMarkers();
    }
  }

  @override
  void dispose() {
    _tapCancelable?.cancel();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    // Create circle manager for colored dots
    _circleManager = await map.annotations.createCircleAnnotationManager();

    // Create point manager for text labels
    _labelManager = await map.annotations.createPointAnnotationManager();

    // Set up tap listener on circles using new tapEvents API
    _tapCancelable = _circleManager?.tapEvents(
      onTap: (CircleAnnotation annotation) {
        final location = _annotationIdToLocation[annotation.id];
        if (location != null) {
          widget.onLocationTap(location);
        }
      },
    );

    await _updateMarkers();

    // Wait a frame then fit bounds
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await _fitBoundsToLocations();
  }

  Future<void> _updateMarkers() async {
    if (_circleManager == null || _labelManager == null) return;

    // Clear existing markers
    await _circleManager!.deleteAll();
    await _labelManager!.deleteAll();
    _annotationIdToLocation.clear();

    // Add markers for each location
    for (final location in widget.locations) {
      final color = _getStatusColor(location.status);

      // Create colored circle (size matches legend)
      final circleOptions = CircleAnnotationOptions(
        geometry: Point(
          coordinates: Position(location.longitude, location.latitude),
        ),
        circleRadius: 6.0,
        circleColor: color.toARGB32(),
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 1.5,
      );

      final circle = await _circleManager!.create(circleOptions);
      _annotationIdToLocation[circle.id] = location;

      // Create text label below the circle
      final labelOptions = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(location.longitude, location.latitude),
        ),
        textField: location.name,
        textSize: 12.0,
        textColor: Colors.white.toARGB32(),
        textHaloColor: Colors.black.toARGB32(),
        textHaloWidth: 1.5,
        textOffset: [0.0, 2.0],
        textAnchor: TextAnchor.TOP,
      );

      await _labelManager!.create(labelOptions);
    }
  }

  Future<void> _fitBoundsToLocations() async {
    if (_mapboxMap == null || widget.locations.isEmpty) return;

    if (widget.locations.length == 1) {
      // Single location - just center on it
      final loc = widget.locations.first;
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(loc.longitude, loc.latitude)),
          zoom: 14.0,
        ),
        MapAnimationOptions(duration: 500),
      );
    } else {
      // Multiple locations - calculate bounds
      double minLat = double.infinity;
      double maxLat = double.negativeInfinity;
      double minLon = double.infinity;
      double maxLon = double.negativeInfinity;

      for (final loc in widget.locations) {
        if (loc.latitude < minLat) minLat = loc.latitude;
        if (loc.latitude > maxLat) maxLat = loc.latitude;
        if (loc.longitude < minLon) minLon = loc.longitude;
        if (loc.longitude > maxLon) maxLon = loc.longitude;
      }

      // Add moderate padding to fit markers and labels comfortably
      final latDiff = maxLat - minLat;
      final lonDiff = maxLon - minLon;
      // 60% padding - balanced between tight fit and breathing room
      final latPadding = (latDiff * 0.4).clamp(0.006, double.infinity);
      final lonPadding = (lonDiff * 0.4).clamp(0.006, double.infinity);

      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              (minLon + maxLon) / 2,
              (minLat + maxLat) / 2,
            ),
          ),
          // Calculate appropriate zoom based on bounds
          zoom: _calculateZoomForBounds(
            minLat - latPadding,
            maxLat + latPadding,
            minLon - lonPadding,
            maxLon + lonPadding,
          ),
        ),
        MapAnimationOptions(duration: 500),
      );
    }
  }

  double _calculateZoomForBounds(
    double minLat,
    double maxLat,
    double minLon,
    double maxLon,
  ) {
    final latDiff = maxLat - minLat;
    final lonDiff = maxLon - minLon;
    final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;

    // Continuous zoom calculation using logarithmic scale
    // At zoom 0, world is ~360 degrees. Each zoom level halves the visible area.
    // zoom = log2(360 / maxDiff) approximately
    if (maxDiff <= 0) return 14.0;

    final zoom = (math.log(360.0 / maxDiff) / math.ln2).clamp(3.0, 18.0);
    return zoom;
  }

  Color _getStatusColor(HuntLocationStatus status) {
    switch (status) {
      case HuntLocationStatus.potential:
        return AppTheme.gold;
      case HuntLocationStatus.searched:
        return Colors.green;
      case HuntLocationStatus.eliminated:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.locations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 64,
              color: AppTheme.gold.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No locations to display',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Calculate initial center from all locations (center of bounds)
    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLon = double.infinity;
    double maxLon = double.negativeInfinity;
    for (final loc in widget.locations) {
      if (loc.latitude < minLat) minLat = loc.latitude;
      if (loc.latitude > maxLat) maxLat = loc.latitude;
      if (loc.longitude < minLon) minLon = loc.longitude;
      if (loc.longitude > maxLon) maxLon = loc.longitude;
    }
    final initialCenter = Point(
      coordinates: Position(
        (minLon + maxLon) / 2,
        (minLat + maxLat) / 2,
      ),
    );

    return Stack(
      children: [
        MapboxMapWidget(
          config: MapboxMapConfig(
            initialCenter: initialCenter,
            initialZoom: 8.0, // Start zoomed out, will fly to fit bounds
            followUserLocation: false,
            showCurrentLocation: false,
            showMapControls: false,
          ),
          onMapCreated: _onMapCreated,
        ),
        // Legend
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLegendItem(AppTheme.gold, 'Potential'),
                const SizedBox(height: 4),
                _buildLegendItem(Colors.green, 'Searched'),
                const SizedBox(height: 4),
                _buildLegendItem(Colors.grey, 'Eliminated'),
              ],
            ),
          ),
        ),
        // Tap hint at bottom
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Tap a marker to view details • Pinch to zoom',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}
