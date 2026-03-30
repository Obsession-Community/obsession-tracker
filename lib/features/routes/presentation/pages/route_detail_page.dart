import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/mapbox_config.dart';
import 'package:obsession_tracker/core/services/route_planning_service.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/mapbox_map_widget.dart';
import 'package:obsession_tracker/features/routes/presentation/pages/route_planning_page.dart';

/// Detail page for viewing and editing a planned route
class RouteDetailPage extends ConsumerStatefulWidget {
  const RouteDetailPage({
    required this.route,
    super.key,
  });

  final PlannedRoute route;

  @override
  ConsumerState<RouteDetailPage> createState() => _RouteDetailPageState();
}

class _RouteDetailPageState extends ConsumerState<RouteDetailPage> {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _routeLineManager;
  PointAnnotationManager? _markerManager;
  final List<PolylineAnnotation> _routeAnnotations = [];
  final List<PointAnnotation> _markerAnnotations = [];

  @override
  void initState() {
    super.initState();
    // Fit the route on the map after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), _fitRouteBounds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;

    // Build map config
    final mapConfig = MapboxMapConfig(
      initialCenter: _getRouteCenter(),
      initialZoom: 13.0,
      followUserLocation: false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(route.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editRoute,
            tooltip: 'Edit route',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareRoute,
            tooltip: 'Share route',
          ),
        ],
      ),
      body: Column(
        children: [
          // Map view
          Expanded(
            flex: 2,
            child: MapboxMapWidget(
              config: mapConfig,
              onMapCreated: (map) => _onMapCreated(map, route),
            ),
          ),

          // Route information
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (route.description != null) ...[
                    Text(
                      route.description!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Statistics
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Route Statistics',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Divider(),
                          _buildStatRow(
                            'Distance',
                            route.formattedDistance,
                            Icons.straighten,
                          ),
                          _buildStatRow(
                            'Duration',
                            route.formattedDuration,
                            Icons.access_time,
                          ),
                          _buildStatRow(
                            'Elevation Gain',
                            '${route.totalElevationGain.toStringAsFixed(0)}m',
                            Icons.terrain,
                          ),
                          _buildStatRow(
                            'Difficulty',
                            route.difficultyDescription,
                            Icons.fitness_center,
                          ),
                          _buildStatRow(
                            'Waypoints',
                            route.waypoints.length.toString(),
                            Icons.location_on,
                          ),
                          _buildStatRow(
                            'Algorithm',
                            _algorithmName(route.algorithm),
                            Icons.route,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _useForSession,
                          icon: const Icon(Icons.directions),
                          label: const Text('Use for Session'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _fitRouteBounds,
                          icon: const Icon(Icons.fit_screen),
                          label: const Text('Fit to Map'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onMapCreated(MapboxMap map, PlannedRoute route) async {
    _mapboxMap = map;
    _routeLineManager = await map.annotations.createPolylineAnnotationManager();
    _markerManager = await map.annotations.createPointAnnotationManager();

    // Draw the route and markers
    await _drawRoute(route);
    await _drawMarkers(route);
  }

  Future<void> _drawRoute(PlannedRoute route) async {
    if (_routeLineManager == null || route.routePoints.isEmpty) return;

    // Clear existing annotations
    for (final annotation in _routeAnnotations) {
      await _routeLineManager!.delete(annotation);
    }
    _routeAnnotations.clear();

    // Convert route points to Mapbox positions
    final lineCoordinates = route.routePoints
        .map((p) => Position(p.longitude, p.latitude))
        .toList();

    // Create polyline annotation
    final options = PolylineAnnotationOptions(
      geometry: LineString(coordinates: lineCoordinates),
      lineColor: 0xFF2196F3, // Blue
      lineWidth: 4.0,
    );

    final annotation = await _routeLineManager!.create(options);
    _routeAnnotations.add(annotation);
  }

  Future<void> _drawMarkers(PlannedRoute route) async {
    if (_markerManager == null || route.routePoints.isEmpty) return;

    // Clear existing markers
    for (final annotation in _markerAnnotations) {
      await _markerManager!.delete(annotation);
    }
    _markerAnnotations.clear();

    // Start marker (green)
    final startOptions = PointAnnotationOptions(
      geometry: Point(
        coordinates: Position(
          route.startPoint.longitude,
          route.startPoint.latitude,
        ),
      ),
      iconImage: 'marker-icon',
      iconSize: 1.5,
      iconColor: 0xFF4CAF50, // Green
    );
    final startMarker = await _markerManager!.create(startOptions);
    _markerAnnotations.add(startMarker);

    // End marker (red)
    final endOptions = PointAnnotationOptions(
      geometry: Point(
        coordinates: Position(
          route.endPoint.longitude,
          route.endPoint.latitude,
        ),
      ),
      iconImage: 'marker-icon',
      iconSize: 1.5,
      iconColor: 0xFFF44336, // Red
    );
    final endMarker = await _markerManager!.create(endOptions);
    _markerAnnotations.add(endMarker);
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }

  Point _getRouteCenter() {
    if (widget.route.routePoints.isEmpty) {
      return Point(coordinates: Position(-103.0, 44.0));
    }

    double totalLat = 0;
    double totalLng = 0;
    for (final point in widget.route.routePoints) {
      totalLat += point.latitude;
      totalLng += point.longitude;
    }

    return Point(
      coordinates: Position(
        totalLng / widget.route.routePoints.length,
        totalLat / widget.route.routePoints.length,
      ),
    );
  }

  Future<void> _fitRouteBounds() async {
    if (_mapboxMap == null || widget.route.routePoints.isEmpty) return;

    double minLat = widget.route.routePoints[0].latitude;
    double maxLat = widget.route.routePoints[0].latitude;
    double minLng = widget.route.routePoints[0].longitude;
    double maxLng = widget.route.routePoints[0].longitude;

    for (final point in widget.route.routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Calculate center and zoom to fit all points
    final cameraOptions = CameraOptions(
      center: Point(
        coordinates: Position(
          (minLng + maxLng) / 2,
          (minLat + maxLat) / 2,
        ),
      ),
    );

    await _mapboxMap!.flyTo(
      cameraOptions,
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _editRoute() async {
    final result = await Navigator.of(context).push<PlannedRoute>(
      MaterialPageRoute(
        builder: (context) => RoutePlanningPage(existingRoute: widget.route),
      ),
    );

    if (result != null && mounted) {
      // Refresh the page with updated route
      Navigator.of(context).pop(result);
    }
  }

  void _shareRoute() {
    // TODO(dev): Implement route sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Route sharing coming soon')),
    );
  }

  void _useForSession() {
    Navigator.of(context).pop(widget.route);
  }

  String _algorithmName(RoutePlanningAlgorithm algorithm) {
    switch (algorithm) {
      case RoutePlanningAlgorithm.straightLine:
        return 'Straight Line';
      case RoutePlanningAlgorithm.shortestPath:
        return 'Shortest Path';
      case RoutePlanningAlgorithm.fastest:
        return 'Fastest';
      case RoutePlanningAlgorithm.scenic:
        return 'Scenic';
      case RoutePlanningAlgorithm.safest:
        return 'Safest';
    }
  }
}
