import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/mapbox_config.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/core/providers/waypoint_provider.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/breadcrumb_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/waypoint_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/mapbox_map_widget.dart';

/// Example tracking page using the new MapboxMapWidget with overlays
///
/// This demonstrates the DRY approach to map integration:
/// - Single MapboxMapWidget configured for tracking
/// - Modular overlays for breadcrumbs, waypoints, and land ownership
/// - Integration with existing providers (location, waypoint, land)
class MapboxTrackingPage extends ConsumerStatefulWidget {
  const MapboxTrackingPage({
    super.key,
    this.sessionId,
  });

  final String? sessionId;

  @override
  ConsumerState<MapboxTrackingPage> createState() =>
      _MapboxTrackingPageState();
}

class _MapboxTrackingPageState extends ConsumerState<MapboxTrackingPage> {
  @override
  void initState() {
    super.initState();

    // Load data for session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sessionId = widget.sessionId ?? _getCurrentSessionId();
      if (sessionId.isNotEmpty) {
        ref.read(waypointProvider.notifier).loadWaypointsForSession(sessionId);
      }
    });
  }

  String _getCurrentSessionId() {
    final locationState = ref.read(locationProvider);
    return locationState.activeSession?.id ?? 'default-session';
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final waypointState = ref.watch(waypointProvider);

    final sessionId = widget.sessionId ?? _getCurrentSessionId();

    // Filter waypoints for current session
    final sessionWaypoints = waypointState.waypoints
        .where((Waypoint wp) => wp.sessionId == sessionId)
        .toList();

    // Get breadcrumbs from location provider
    final List<geo.Position> breadcrumbs = locationState.currentBreadcrumbs
        .map(
          (b) => geo.Position(
            latitude: b.coordinates.latitude,
            longitude: b.coordinates.longitude,
            timestamp: b.timestamp,
            accuracy: b.accuracy,
            altitude: b.altitude ?? 0.0,
            altitudeAccuracy: 0.0,
            heading: b.heading ?? 0.0,
            headingAccuracy: 0.0,
            speed: b.speed ?? 0.0,
            speedAccuracy: 0.0,
          ),
        )
        .toList();

    // Build overlay configs
    final overlays = <MapOverlayConfig>[
      // Breadcrumb trail overlay
      if (breadcrumbs.isNotEmpty)
        MapOverlayConfig(
          type: MapOverlayType.breadcrumbTrail,
          data: BreadcrumbOverlay(
            breadcrumbs: breadcrumbs,
          ),
        ),

      // Waypoint markers overlay
      if (sessionWaypoints.isNotEmpty)
        MapOverlayConfig(
          type: MapOverlayType.waypoints,
          data: WaypointOverlay(
            waypoints: sessionWaypoints,
            onWaypointTap: _onWaypointTapped,
          ),
        ),

      // Land ownership overlay example (disabled for now)
      // Note: Enable this by providing land data from BFF
      // MapOverlayConfig(
      //   type: MapOverlayType.landOwnership,
      //   data: LandOwnershipOverlay(
      //     landParcels: <LandOwnership>[],
      //     onParcelTap: _onLandParcelTapped,
      //   ),
      // ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapbox Tracking'),
        actions: [
          // Toggle location following
          IconButton(
            icon: Icon(
              locationState.isTracking
                  ? Icons.location_on
                  : Icons.location_off,
            ),
            onPressed: () {
              if (locationState.isTracking) {
                ref.read(locationProvider.notifier).stopTracking();
              } else {
                ref
                    .read(locationProvider.notifier)
                    .startTracking(sessionName: 'Mapbox Tracking');
              }
            },
            tooltip:
                locationState.isTracking ? 'Stop Tracking' : 'Start Tracking',
          ),

          // Settings menu
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reload_overlays',
                child: Text('Reload Overlays'),
              ),
              const PopupMenuItem(
                value: 'center_location',
                child: Text('Center on Location'),
              ),
            ],
          ),
        ],
      ),
      body: MapboxMapWidget(
        config: MapboxPresets.tracking.copyWith(
          followUserLocation: locationState.isTracking,
          enableTouchToMark: true,
        ),
        overlays: overlays,
        onMapTap: _onMapTap,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showOverlayInfo,
        tooltip: 'Overlay Info',
        child: const Icon(Icons.info_outline),
      ),
    );
  }

  void _onWaypointTapped(Waypoint waypoint) {
    debugPrint('Waypoint tapped: ${waypoint.displayName}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Waypoint: ${waypoint.displayName}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onMapTap(Point point) {
    debugPrint(
      'Map tapped at: ${point.coordinates.lat}, ${point.coordinates.lng}',
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'reload_overlays':
        setState(() {
          // Trigger rebuild to reload overlays
        });
        break;
      case 'center_location':
        // TODO(mapbox): Implement center on location
        break;
    }
  }

  void _showOverlayInfo() {
    final locationState = ref.read(locationProvider);
    final waypointState = ref.read(waypointProvider);

    final sessionId = widget.sessionId ?? _getCurrentSessionId();
    final sessionWaypoints = waypointState.waypoints
        .where((Waypoint wp) => wp.sessionId == sessionId)
        .toList();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Active Overlays'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Breadcrumbs: ${locationState.currentBreadcrumbs.length}'),
            Text('Waypoints: ${sessionWaypoints.length}'),
            const SizedBox(height: 16),
            const Text(
              'This demonstrates the DRY overlay system:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('• BreadcrumbOverlay for GPS trail'),
            const Text('• WaypointOverlay for markers'),
            const Text('• LandOwnershipOverlay (see code for example)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
