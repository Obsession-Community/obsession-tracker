import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/mapbox_config.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/land_ownership_provider.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/route_planning_service.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/land_ownership_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/mapbox_map_widget.dart';

/// Page for editing route waypoints with drag-and-drop
class RouteEditPage extends ConsumerStatefulWidget {
  const RouteEditPage({
    required this.route,
    super.key,
  });

  final PlannedRoute route;

  @override
  ConsumerState<RouteEditPage> createState() => _RouteEditPageState();
}

class _RouteEditPageState extends ConsumerState<RouteEditPage> {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _routeLineManager;
  late List<LatLng> _waypoints;
  late RoutePlanningAlgorithm _selectedAlgorithm;
  bool _hasChanges = false;
  PlannedRoute? _previewRoute;
  int? _selectedWaypointIndex;
  final List<PolylineAnnotation> _routeAnnotations = [];

  @override
  void initState() {
    super.initState();
    // Initialize with existing route waypoints (control points)
    _waypoints = [
      widget.route.startPoint,
      ...widget.route.waypoints.map((w) => w.coordinates),
      widget.route.endPoint,
    ];
    _selectedAlgorithm = widget.route.algorithm;
    _previewRoute = widget.route;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), _fitRouteBounds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final landOverlayVisible = ref.watch(landOverlayVisibilityProvider);
    final landOpacity = ref.watch(landOverlayOpacityProvider);

    // Calculate initial center from route bounds
    Point initialCenter;
    double initialZoom = 13.0;

    if (widget.route.routePoints.isNotEmpty) {
      double totalLat = 0;
      double totalLng = 0;
      for (final point in widget.route.routePoints) {
        totalLat += point.latitude;
        totalLng += point.longitude;
      }
      initialCenter = Point(
        coordinates: Position(
          totalLng / widget.route.routePoints.length,
          totalLat / widget.route.routePoints.length,
        ),
      );
      final distance = widget.route.totalDistance / 1000;
      if (distance < 1) {
        initialZoom = 15.0;
      } else if (distance < 5) {
        initialZoom = 13.0;
      } else if (distance < 20) {
        initialZoom = 11.0;
      } else {
        initialZoom = 9.0;
      }
    } else {
      initialCenter = Point(coordinates: Position(-103.0, 44.0));
    }

    final mapConfig = MapboxMapConfig(
      initialCenter: initialCenter,
      initialZoom: initialZoom,
      followUserLocation: false,
    );

    final overlays = <MapOverlayConfig>[
      if (landOverlayVisible)
        MapOverlayConfig(
          type: MapOverlayType.landOwnership,
          data: LandOwnershipOverlay(
            landParcels: const [],
            fillOpacity: landOpacity,
            filter: ref.watch(landOwnershipFilterProvider),
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit: ${widget.route.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showRouteInfo,
            tooltip: 'Route info',
          ),
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
              tooltip: 'Save changes',
            ),
        ],
      ),
      body: Stack(
        children: [
          // Mapbox Map
          MapboxMapWidget(
            config: mapConfig,
            onMapCreated: _onMapCreated,
            overlays: overlays,
          ),

          // Draggable waypoint markers overlay
          ..._buildWaypointMarkers(),

          // Instructions banner
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Card(
              color: Colors.black.withValues(alpha: 0.7),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Drag markers to move • Tap marker to delete',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    if (_hasChanges)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Unsaved',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<RoutePlanningAlgorithm>(
                            initialValue: _selectedAlgorithm,
                            decoration: const InputDecoration(
                              labelText: 'Algorithm',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            items: RoutePlanningAlgorithm.values.map((algorithm) {
                              return DropdownMenuItem(
                                value: algorithm,
                                child: Text(_algorithmName(algorithm), style: const TextStyle(fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedAlgorithm = value);
                                _recalculateRoute();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _hasChanges ? _saveChanges : null,
                            icon: const Icon(Icons.save, size: 18),
                            label: const Text('Save', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _hasChanges ? Colors.green : null,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWaypointMarkers() {
    final markers = <Widget>[];

    for (var i = 0; i < _waypoints.length; i++) {
      final waypoint = _waypoints[i];

      // Determine color based on position
      final color = i == 0
          ? Colors.green
          : i == _waypoints.length - 1
              ? Colors.red
              : Colors.blue;

      final icon = i == 0
          ? Icons.flag
          : i == _waypoints.length - 1
              ? Icons.sports_score
              : Icons.location_on;

      markers.add(
        _DraggableWaypointMarker(
          key: ValueKey('waypoint-$i'),
          waypoint: waypoint,
          index: i,
          color: color,
          icon: icon,
          isSelected: _selectedWaypointIndex == i,
          onDragUpdate: (newPosition) => _onWaypointDragged(i, newPosition),
          onTap: () => _onWaypointTapped(i),
          mapboxMap: _mapboxMap,
        ),
      );
    }

    return markers;
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;
    _routeLineManager = await map.annotations.createPolylineAnnotationManager();

    // Draw initial route
    if (widget.route.routePoints.isNotEmpty) {
      await _updateRouteLine(widget.route.routePoints);
    }

    // Force rebuild to show markers
    setState(() {});
  }

  void _onWaypointDragged(int index, LatLng newPosition) {
    setState(() {
      _waypoints[index] = newPosition;
      _hasChanges = true;
    });
    _recalculateRoute();
  }

  void _onWaypointTapped(int index) {
    // Can't delete start or end
    if (index == 0 || index == _waypoints.length - 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete start or end point'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      _waypoints.removeAt(index);
      _hasChanges = true;
    });
    _recalculateRoute();
  }

  void _showRouteInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Route Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Waypoints: ${_waypoints.length}'),
            if (_previewRoute != null) ...[
              Text('Distance: ${_previewRoute!.formattedDistance}'),
              Text('Duration: ${_previewRoute!.formattedDuration}'),
              Text('Difficulty: ${_previewRoute!.difficultyDescription}'),
              Text('Algorithm: ${_algorithmName(_selectedAlgorithm)}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _fitRouteBounds() async {
    if (_mapboxMap == null || _waypoints.isEmpty) return;

    double minLat = _waypoints.first.latitude;
    double maxLat = _waypoints.first.latitude;
    double minLng = _waypoints.first.longitude;
    double maxLng = _waypoints.first.longitude;

    for (final point in _waypoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

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

  Future<void> _recalculateRoute() async {
    if (_waypoints.length < 2) return;

    try {
      final routePlanningService = RoutePlanningService();

      // Convert intermediate waypoints to Waypoint objects
      final intermediateWaypoints = _waypoints
          .sublist(1, _waypoints.length - 1)
          .asMap()
          .entries
          .map((entry) {
            final pos = entry.value;
            return Waypoint(
              id: 'temp-${entry.key}',
              sessionId: 'editing',
              coordinates: pos,
              timestamp: DateTime.now(),
              type: WaypointType.custom,
            );
          })
          .toList();

      final route = await routePlanningService.planRoute(
        startPoint: _waypoints.first,
        endPoint: _waypoints.last,
        algorithm: _selectedAlgorithm,
        waypoints: intermediateWaypoints,
        name: widget.route.name,
        description: widget.route.description,
      );

      setState(() => _previewRoute = route);

      await _updateRouteLine(route.routePoints);
    } catch (e) {
      debugPrint('Error recalculating route: $e');
    }
  }

  Future<void> _updateRouteLine(List<LatLng> routePoints) async {
    if (_routeLineManager == null) return;

    // Clear existing route line
    for (final annotation in _routeAnnotations) {
      await _routeLineManager!.delete(annotation);
    }
    _routeAnnotations.clear();

    final lineCoordinates = routePoints
        .map((p) => Position(p.longitude, p.latitude))
        .toList();

    final options = PolylineAnnotationOptions(
      geometry: LineString(coordinates: lineCoordinates),
      lineColor: 0xFF2196F3,
      lineWidth: 4.0,
    );

    final annotation = await _routeLineManager!.create(options);
    _routeAnnotations.add(annotation);
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges || _previewRoute == null) {
      Navigator.of(context).pop();
      return;
    }

    try {
      final db = DatabaseService();
      await db.updatePlannedRoute({
        'id': widget.route.id,
        'name': _previewRoute!.name,
        'description': _previewRoute!.description,
        'created_at': widget.route.createdAt.millisecondsSinceEpoch,
        'total_distance': _previewRoute!.totalDistance,
        'total_duration': _previewRoute!.totalDuration.inSeconds,
        'total_elevation_gain': _previewRoute!.totalElevationGain,
        'difficulty': _previewRoute!.difficulty,
        'algorithm': _previewRoute!.algorithm.name,
        'route_data': jsonEncode({
          'segments': _previewRoute!.segments.map((s) => {
            'start': {'lat': s.startPoint.latitude, 'lng': s.startPoint.longitude},
            'end': {'lat': s.endPoint.latitude, 'lng': s.endPoint.longitude},
            'distance': s.distance,
            'duration': s.duration.inSeconds,
            'type': s.type.name,
          }).toList(),
        }),
        'waypoint_ids': jsonEncode(_previewRoute!.waypoints.map((w) => w.id).toList()),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(_previewRoute);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating route: $e')),
        );
      }
    }
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

/// Draggable waypoint marker widget
class _DraggableWaypointMarker extends StatefulWidget {
  const _DraggableWaypointMarker({
    required super.key,
    required this.waypoint,
    required this.index,
    required this.color,
    required this.icon,
    required this.isSelected,
    required this.onDragUpdate,
    required this.onTap,
    required this.mapboxMap,
  });

  final LatLng waypoint;
  final int index;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final void Function(LatLng) onDragUpdate;
  final VoidCallback onTap;
  final MapboxMap? mapboxMap;

  @override
  State<_DraggableWaypointMarker> createState() => _DraggableWaypointMarkerState();
}

class _DraggableWaypointMarkerState extends State<_DraggableWaypointMarker> {
  Offset? _screenPosition;

  @override
  void initState() {
    super.initState();
    _updateScreenPosition();
  }

  @override
  void didUpdateWidget(_DraggableWaypointMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.waypoint != widget.waypoint) {
      _updateScreenPosition();
    }
  }

  Future<void> _updateScreenPosition() async {
    if (widget.mapboxMap == null) return;

    try {
      final screenCoord = await widget.mapboxMap!.pixelForCoordinate(
        Point(
          coordinates: Position(
            widget.waypoint.longitude,
            widget.waypoint.latitude,
          ),
        ),
      );

      if (mounted) {
        setState(() {
          _screenPosition = Offset(screenCoord.x, screenCoord.y);
        });
      }
    } catch (e) {
      debugPrint('Error converting coordinate to pixel: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_screenPosition == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: _screenPosition!.dx - 20,
      top: _screenPosition!.dy - 40,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanUpdate: (details) async {
          final newScreenPos = Offset(
            _screenPosition!.dx + details.delta.dx,
            _screenPosition!.dy + details.delta.dy,
          );

          try {
            final newCoord = await widget.mapboxMap!.coordinateForPixel(
              ScreenCoordinate(x: newScreenPos.dx, y: newScreenPos.dy),
            );

            final newLatLng = LatLng(
              newCoord.coordinates.lat.toDouble(),
              newCoord.coordinates.lng.toDouble(),
            );

            setState(() {
              _screenPosition = newScreenPos;
            });

            widget.onDragUpdate(newLatLng);
          } catch (e) {
            debugPrint('Error during drag: $e');
          }
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isSelected ? Colors.yellow : Colors.white,
              width: widget.isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
