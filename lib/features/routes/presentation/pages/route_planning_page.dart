import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/mapbox_config.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/core/providers/map_search_provider.dart';
import 'package:obsession_tracker/core/services/map_search_service.dart';
import 'package:obsession_tracker/core/services/route_planning_service.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/core_map_view.dart' hide PlannedRoute;
import 'package:obsession_tracker/features/map/presentation/widgets/map_search_widget.dart';

/// Interactive route planning page for creating pre-session routes
///
/// Uses CoreMapView for consistent map behavior with MapPage and SessionPlaybackPage,
/// including zoom-based data loading, filters, and all overlay types.
class RoutePlanningPage extends ConsumerStatefulWidget {
  const RoutePlanningPage({
    this.existingRoute,
    super.key,
  });

  final PlannedRoute? existingRoute;

  @override
  ConsumerState<RoutePlanningPage> createState() => _RoutePlanningPageState();
}

class _RoutePlanningPageState extends ConsumerState<RoutePlanningPage> {
  MapboxMap? _mapboxMap;
  late List<LatLng> _routeWaypoints;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _showSearchOverlay = false;

  PlannedRoute? _previewRoute;

  // CoreMapView key for accessing state
  final GlobalKey<CoreMapViewState> _coreMapKey = GlobalKey<CoreMapViewState>();

  // Annotation managers for route line
  PolylineAnnotationManager? _routeLineManager;
  final List<PolylineAnnotation> _routeLineAnnotations = [];
  bool _isUpdatingRouteLine = false;

  @override
  void initState() {
    super.initState();

    // Initialize from existing route if provided
    if (widget.existingRoute != null) {
      _routeWaypoints = [
        widget.existingRoute!.startPoint,
        ...widget.existingRoute!.waypoints.map((w) => w.coordinates),
        widget.existingRoute!.endPoint,
      ];
      _previewRoute = widget.existingRoute;
      _nameController.text = widget.existingRoute!.name;
      _descriptionController.text = widget.existingRoute!.description ?? '';
    } else {
      _routeWaypoints = [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);

    final currentLocation = locationState.currentPosition != null
        ? Point(
            coordinates: Position(
              locationState.currentPosition!.longitude,
              locationState.currentPosition!.latitude,
            ),
          )
        : Point(coordinates: Position(-103.0, 44.0)); // Default to Black Hills

    // Build map config
    final mapConfig = MapboxMapConfig(
      initialCenter: currentLocation,
      initialZoom: 13.0,
      followUserLocation: false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingRoute != null ? 'Edit Route' : 'Plan Route'),
        actions: [
          // Filter button
          IconButton(
            icon: Icon(
              Icons.layers,
              color: _coreMapKey.currentState?.isFilterPanelVisible == true
                  ? Colors.blue
                  : null,
            ),
            onPressed: () {
              _coreMapKey.currentState?.toggleFilterPanel();
              setState(() {}); // Refresh to update button color
            },
            tooltip: 'Map Layers',
          ),
          // Search button
          IconButton(
            icon: Icon(
              Icons.search,
              color: _showSearchOverlay ? Colors.blue : null,
            ),
            onPressed: () {
              setState(() {
                _showSearchOverlay = !_showSearchOverlay;
              });
            },
            tooltip: 'Search Map',
          ),
          if (_routeWaypoints.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _removeLastWaypoint,
              tooltip: 'Undo last waypoint',
            ),
          if (_routeWaypoints.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearRoute,
              tooltip: 'Clear route',
            ),
          if (_previewRoute != null)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveRoute,
              tooltip: 'Save route',
            ),
        ],
      ),
      body: Stack(
        children: [
          // CoreMapView handles all shared map functionality
          // Disable overlay tap handlers so taps only add route waypoints
          CoreMapView(
            key: _coreMapKey,
            config: mapConfig,
            hideOverlays: _showSearchOverlay,
            disableOverlayTapHandlers: true,
            onMapCreated: _onMapCreated,
            onMapTap: _onMapTap,
          ),

          // Draggable waypoint markers overlaid on map
          ..._buildDraggableWaypoints(),

          // Search overlay
          if (_showSearchOverlay)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildSearchOverlay(locationState),
            ),

          // Bottom route controls card
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route details
                    if (_previewRoute != null) ...[
                      Text(
                        'Route Details',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text('Waypoints: ${_routeWaypoints.length}'),
                      Text('Distance: ${_previewRoute!.formattedDistance}'),
                      Text('Duration: ${_previewRoute!.formattedDuration}'),
                      Text('Difficulty: ${_previewRoute!.difficultyDescription}'),
                      const SizedBox(height: 12),
                    ] else if (_routeWaypoints.isNotEmpty) ...[
                      Text('Waypoints: ${_routeWaypoints.length}'),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _routeWaypoints.length >= 2 ? _calculateRoute : null,
                            icon: const Icon(Icons.route),
                            label: const Text('Calculate'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _addCurrentLocation,
                            icon: const Icon(Icons.add_location),
                            label: const Text('Add Current'),
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

  List<Widget> _buildDraggableWaypoints() {
    if (_mapboxMap == null) return [];

    return _routeWaypoints.asMap().entries.map((entry) {
      final index = entry.key;
      final waypoint = entry.value;

      // Determine color based on position
      final color = index == 0
          ? Colors.green // Start
          : index == _routeWaypoints.length - 1
              ? Colors.red // End
              : Colors.blue; // Intermediate

      return _DraggableWaypointMarker(
        key: ValueKey('waypoint-$index-${waypoint.latitude}-${waypoint.longitude}'),
        waypoint: waypoint,
        index: index,
        color: color,
        mapboxMap: _mapboxMap,
        onDragUpdate: (newPosition) => _onWaypointDragged(index, newPosition),
        onDragEnd: _onWaypointDragEnd,
      );
    }).toList();
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _routeLineManager = await mapboxMap.annotations.createPolylineAnnotationManager();

    // If editing an existing route, draw it on the map
    if (widget.existingRoute != null && _routeWaypoints.isNotEmpty) {
      await _updateRouteLine(_routeWaypoints);

      // Center the map on the route
      if (_routeWaypoints.length >= 2) {
        await _centerOnRoute();
      }

      // Trigger rebuild to show waypoint markers
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _onMapTap(Point point) async {
    // Convert map point to LatLng
    final latLng = LatLng(
      point.coordinates.lat.toDouble(),
      point.coordinates.lng.toDouble(),
    );

    setState(() => _routeWaypoints.add(latLng));

    // If we have 2+ waypoints, draw lines between them
    if (_routeWaypoints.length >= 2) {
      await _updateRouteLine(_routeWaypoints);
    }

    // Auto-calculate route if we have enough waypoints
    if (_routeWaypoints.length >= 2) {
      await _calculateRoute();
    }
  }

  Future<void> _addCurrentLocation() async {
    final locationState = ref.read(locationProvider);
    if (locationState.currentPosition != null) {
      final latLng = LatLng(
        locationState.currentPosition!.latitude,
        locationState.currentPosition!.longitude,
      );
      setState(() => _routeWaypoints.add(latLng));

      if (_routeWaypoints.length >= 2) {
        await _updateRouteLine(_routeWaypoints);
        await _calculateRoute();
      }
    }
  }

  Future<void> _removeLastWaypoint() async {
    if (_routeWaypoints.isNotEmpty) {
      setState(_routeWaypoints.removeLast);

      if (_routeWaypoints.length >= 2) {
        await _updateRouteLine(_routeWaypoints);
        await _calculateRoute();
      } else {
        setState(() => _previewRoute = null);
        await _clearRouteLine();
      }
    }
  }

  Future<void> _clearRoute() async {
    setState(() {
      _routeWaypoints.clear();
      _previewRoute = null;
    });
    await _clearRouteLine();
  }

  void _onWaypointDragged(int index, LatLng newPosition) {
    // Update waypoint position without triggering full rebuild
    _routeWaypoints[index] = newPosition;

    // Update the line immediately for visual feedback
    if (_routeWaypoints.length >= 2) {
      _updateRouteLine(_routeWaypoints);
    }
  }

  void _onWaypointDragEnd() {
    // Only recalculate route when drag is complete
    if (_routeWaypoints.length >= 2) {
      _calculateRoute();
    }
  }

  Future<void> _updateRouteLine(List<LatLng> routePoints) async {
    if (_routeLineManager == null) return;

    // Prevent overlapping updates - skip if already updating
    if (_isUpdatingRouteLine) {
      debugPrint('[ROUTE] Skipping route line update - already in progress');
      return;
    }

    _isUpdatingRouteLine = true;

    try {
      // Clear existing route line
      await _clearRouteLine();

      // Create new route line
      final lineCoordinates =
          routePoints.map((p) => Position(p.longitude, p.latitude)).toList();

      final options = PolylineAnnotationOptions(
        geometry: LineString(coordinates: lineCoordinates),
        lineColor: 0xFF2196F3, // Blue
        lineWidth: 4.0,
      );

      final annotation = await _routeLineManager!.create(options);
      _routeLineAnnotations.add(annotation);
    } finally {
      _isUpdatingRouteLine = false;
    }
  }

  Future<void> _clearRouteLine() async {
    if (_routeLineManager != null) {
      // Create a copy to avoid concurrent modification during async iteration
      final annotationsToDelete = List<PolylineAnnotation>.from(_routeLineAnnotations);
      for (final annotation in annotationsToDelete) {
        await _routeLineManager!.delete(annotation);
      }
      _routeLineAnnotations.clear();
    }
  }

  Future<void> _centerOnRoute() async {
    if (_mapboxMap == null || _routeWaypoints.isEmpty) return;

    // Calculate bounds
    double minLat = _routeWaypoints.first.latitude;
    double maxLat = _routeWaypoints.first.latitude;
    double minLng = _routeWaypoints.first.longitude;
    double maxLng = _routeWaypoints.first.longitude;

    for (final point in _routeWaypoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Calculate center
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    // Calculate zoom level based on bounds
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    double zoom = 13.0;
    if (maxDiff > 0.5) {
      zoom = 9.0;
    } else if (maxDiff > 0.1) {
      zoom = 11.0;
    } else if (maxDiff > 0.05) {
      zoom = 12.0;
    }

    // Fly to the center
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _calculateRoute() async {
    if (_routeWaypoints.length < 2) return;

    try {
      final routePlanningService = RoutePlanningService();

      // Convert intermediate waypoints to Waypoint objects
      final waypoints = _routeWaypoints
          .sublist(1, _routeWaypoints.length - 1)
          .asMap()
          .entries
          .map((entry) {
        final pos = entry.value;
        return Waypoint(
          id: 'temp-${entry.key}',
          sessionId: 'planning',
          coordinates: pos,
          timestamp: DateTime.now(),
          type: WaypointType.custom,
        );
      }).toList();

      final route = await routePlanningService.planRoute(
        startPoint: _routeWaypoints.first,
        endPoint: _routeWaypoints.last,
        algorithm: RoutePlanningAlgorithm.straightLine,
        waypoints: waypoints,
      );

      setState(() => _previewRoute = route);
      await _updateRouteLine(route.routePoints);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error calculating route: $e')),
        );
      }
    }
  }

  Future<void> _saveRoute() async {
    // Ensure route is calculated with current waypoints before saving
    if (_routeWaypoints.length >= 2) {
      await _calculateRoute();
    }

    if (_previewRoute == null) return;

    // If editing existing route, skip dialog and just save
    if (widget.existingRoute != null) {
      try {
        final routeToSave = _previewRoute!.copyWith(
          id: widget.existingRoute!.id,
          name: _nameController.text.isNotEmpty
              ? _nameController.text
              : widget.existingRoute!.name,
          description: _descriptionController.text,
        );

        debugPrint('Saving route with ${routeToSave.routePoints.length} route points');

        final routePlanningService = RoutePlanningService();
        await routePlanningService.saveRoute(routeToSave);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Route updated successfully')),
          );
          Navigator.of(context).pop(routeToSave);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating route: $e')),
          );
        }
      }
      return;
    }

    // For new routes, show the save dialog
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Route'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Route Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop({
                'name': _nameController.text.isNotEmpty
                    ? _nameController.text
                    : 'Route ${DateTime.now().toString()}',
                'description': _descriptionController.text,
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    try {
      final routeToSave = _previewRoute!.copyWith(
        name: result['name'] ?? 'Unnamed Route',
        description: result['description'],
      );

      final routePlanningService = RoutePlanningService();
      await routePlanningService.saveRoute(routeToSave);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Route "${result['name']}" saved successfully')),
        );
        // Pop back to RouteLibraryPage instead of pushing a replacement
        Navigator.of(context).pop(routeToSave);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving route: $e')),
        );
      }
    }
  }

  Widget _buildSearchOverlay(LocationState locationState) {
    final searchService = ref.watch(mapSearchServiceProvider);
    final position = locationState.currentPosition;

    return MapSearchWidget(
      searchService: searchService,
      proximityLat: position?.latitude,
      proximityLon: position?.longitude,
      onResultSelected: _onSearchResultSelected,
    );
  }

  Future<void> _onSearchResultSelected(MapSearchResult result) async {
    debugPrint('[SEARCH] Selected: ${result.displayName} at ${result.latitude}, ${result.longitude}');

    if (_mapboxMap == null) return;

    // Coordinates should be present after retrieval
    final lat = result.latitude;
    final lon = result.longitude;
    if (lat == null || lon == null) return;

    // Calculate appropriate zoom level based on bounding box
    double zoom = 14.0;

    if (result.bbox != null && result.bbox!.length == 4) {
      final bbox = result.bbox!;
      final latDiff = (bbox[3] - bbox[1]).abs();
      final lonDiff = (bbox[2] - bbox[0]).abs();
      final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;

      if (maxDiff > 10) {
        zoom = 8.0;
      } else if (maxDiff > 1) {
        zoom = 10.0;
      } else if (maxDiff > 0.1) {
        zoom = 12.0;
      } else {
        zoom = 14.0;
      }
    }

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(lon, lat),
        ),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 1500),
    );

    setState(() {
      _showSearchOverlay = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigated to: ${result.displayName}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// Draggable waypoint marker widget that can be positioned and dragged on the map
class _DraggableWaypointMarker extends StatefulWidget {
  const _DraggableWaypointMarker({
    required super.key,
    required this.waypoint,
    required this.index,
    required this.color,
    required this.mapboxMap,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final LatLng waypoint;
  final int index;
  final Color color;
  final MapboxMap? mapboxMap;
  final void Function(LatLng) onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  State<_DraggableWaypointMarker> createState() => _DraggableWaypointMarkerState();
}

class _DraggableWaypointMarkerState extends State<_DraggableWaypointMarker>
    with SingleTickerProviderStateMixin {
  Offset? _screenPosition;
  Offset? _dragStartPosition;
  bool _isDragging = false;
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _updateScreenPosition();
    // Use a ticker to continuously update position when camera moves
    _ticker = createTicker((_) {
      if (!_isDragging && mounted) {
        _updateScreenPosition();
      }
    });
    _ticker.start();
  }

  @override
  void didUpdateWidget(_DraggableWaypointMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.waypoint != widget.waypoint) {
      _updateScreenPosition();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
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
      // Ignore coordinate conversion errors
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_screenPosition == null) return const SizedBox.shrink();

    const markerSize = 40.0;

    return Positioned(
      left: _screenPosition!.dx - (markerSize / 2),
      top: _screenPosition!.dy - (markerSize / 2),
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
            _dragStartPosition = _screenPosition;
          });
        },
        onPanUpdate: (details) async {
          if (!_isDragging || _dragStartPosition == null) return;

          final newScreenPos = Offset(
            _screenPosition!.dx + details.delta.dx,
            _screenPosition!.dy + details.delta.dy,
          );

          setState(() {
            _screenPosition = newScreenPos;
          });

          try {
            final newCoord = await widget.mapboxMap!.coordinateForPixel(
              ScreenCoordinate(x: newScreenPos.dx, y: newScreenPos.dy),
            );

            final newLatLng = LatLng(
              newCoord.coordinates.lat.toDouble(),
              newCoord.coordinates.lng.toDouble(),
            );

            widget.onDragUpdate(newLatLng);
          } catch (e) {
            // Ignore coordinate conversion errors during drag
          }
        },
        onPanEnd: (_) {
          setState(() {
            _isDragging = false;
            _dragStartPosition = null;
          });
          _updateScreenPosition();
          widget.onDragEnd();
        },
        child: Container(
          width: markerSize,
          height: markerSize,
          decoration: BoxDecoration(
            color: _isDragging
                ? widget.color.withValues(alpha: 0.7)
                : widget.color.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${widget.index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
