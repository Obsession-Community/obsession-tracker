import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/imported_route.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/route_planning_provider.dart';
import 'package:obsession_tracker/core/services/route_planning_service.dart';
import 'package:obsession_tracker/features/routes/presentation/pages/route_planning_page.dart';
import 'package:obsession_tracker/features/routes/presentation/widgets/route_import_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Library page for viewing and managing saved planned routes
class RouteLibraryPage extends ConsumerStatefulWidget {
  const RouteLibraryPage({super.key});

  @override
  ConsumerState<RouteLibraryPage> createState() => _RouteLibraryPageState();
}

class _RouteLibraryPageState extends ConsumerState<RouteLibraryPage> {
  @override
  void initState() {
    super.initState();
    // Load routes from database when page opens
    Future.microtask(
      () => ref.read(routePlanningProvider.notifier).loadAllRoutes(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routePlanningProvider);
    final savedRoutes = routeState.savedRoutes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Routes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createNewRoute,
            tooltip: 'Plan new route',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _importRoute,
            tooltip: 'Import route',
          ),
        ],
      ),
      body: routeState.isPlanning
          ? const Center(child: CircularProgressIndicator())
          : savedRoutes.isEmpty
              ? _buildEmptyState()
              : _buildRouteList(savedRoutes),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.route,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No saved routes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Create a route to plan your next adventure',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createNewRoute,
            icon: const Icon(Icons.add),
            label: const Text('Create Route'),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteList(List<PlannedRoute> routes) {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: routes.length,
      itemBuilder: (context, index) {
        final route = routes[index];
        return _buildRouteCard(route);
      },
    );
  }

  Widget _buildRouteCard(PlannedRoute route) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: () => _openRouteDetail(route),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      route.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _buildDifficultyChip(route.difficulty),
                ],
              ),
              if (route.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  route.description!,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    route.formattedDistance,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    route.formattedDuration,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${route.waypoints.length + 2} pts',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () => _shareRoute(route, context),
                      tooltip: 'Export / Share route',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(route),
                    tooltip: 'Delete route',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(int difficulty) {
    Color color;
    String label;

    switch (difficulty) {
      case 1:
        color = Colors.green;
        label = 'Easy';
        break;
      case 2:
        color = Colors.lightGreen;
        label = 'Moderate';
        break;
      case 3:
        color = Colors.orange;
        label = 'Challenging';
        break;
      case 4:
        color = Colors.deepOrange;
        label = 'Difficult';
        break;
      case 5:
        color = Colors.red;
        label = 'Expert';
        break;
      default:
        color = Colors.grey;
        label = 'Unknown';
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _createNewRoute() async {
    final result = await Navigator.of(context).push<PlannedRoute>(
      MaterialPageRoute<PlannedRoute>(
        builder: (context) => const RoutePlanningPage(),
      ),
    );

    // Refresh the list if a route was saved
    if (result != null && mounted) {
      ref.read(routePlanningProvider.notifier).loadAllRoutes();
    }
  }

  Future<void> _importRoute() async {
    final importedRoute = await showDialog<ImportedRoute>(
      context: context,
      builder: (context) => const RouteImportDialog(),
    );
    if (importedRoute != null && mounted) {
      try {
        // Convert ImportedRoute to PlannedRoute
        final plannedRoute = _convertImportedRouteToPlannedRoute(importedRoute);

        // Save as PlannedRoute
        final routePlanningService = RoutePlanningService();
        await routePlanningService.saveRoute(plannedRoute);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported "${plannedRoute.name}" successfully')),
          );
          // Reload routes to include imported route
          ref.read(routePlanningProvider.notifier).loadAllRoutes();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error importing route: $e')),
          );
        }
      }
    }
  }

  /// Convert ImportedRoute to PlannedRoute
  PlannedRoute _convertImportedRouteToPlannedRoute(ImportedRoute importedRoute) {
    // Convert route points to LatLng
    final routePoints = importedRoute.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    if (routePoints.isEmpty) {
      throw Exception('Imported route has no points');
    }

    final startPoint = routePoints.first;
    final endPoint = routePoints.last;

    // Convert intermediate waypoints (excluding start and end)
    final List<Waypoint> waypoints = [];
    if (importedRoute.waypoints.isNotEmpty) {
      for (int i = 0; i < importedRoute.waypoints.length; i++) {
        final rw = importedRoute.waypoints[i];
        waypoints.add(Waypoint(
          id: rw.id,
          sessionId: importedRoute.id,
          coordinates: LatLng(rw.latitude, rw.longitude),
          timestamp: DateTime.now(),
          type: WaypointType.custom,
          notes: rw.description,
        ));
      }
    }

    // Create a single segment with all the route points
    final segment = RouteSegment(
      startPoint: startPoint,
      endPoint: endPoint,
      distance: importedRoute.totalDistance,
      duration: Duration(
        seconds: (importedRoute.estimatedDuration ??
                 (importedRoute.totalDistance / 1.4)).round(), // Assume 1.4 m/s walking speed
      ),
      type: RouteSegmentType.walking,
      waypoints: routePoints.sublist(1, routePoints.length - 1),
    );

    // Calculate difficulty based on distance and elevation
    int difficulty = 1;
    if (importedRoute.totalDistance > 10000) difficulty = 2;
    if (importedRoute.totalDistance > 20000) difficulty = 3;
    if (importedRoute.totalDistance > 30000) difficulty = 4;
    if (importedRoute.totalDistance > 50000) difficulty = 5;

    return PlannedRoute(
      id: importedRoute.id,
      name: importedRoute.name,
      description: importedRoute.description,
      startPoint: startPoint,
      endPoint: endPoint,
      segments: [segment],
      algorithm: RoutePlanningAlgorithm.straightLine,
      createdAt: importedRoute.createdAt,
      totalDistance: importedRoute.totalDistance,
      totalDuration: segment.duration,
      difficulty: difficulty,
      waypoints: waypoints,
    );
  }

  Future<void> _shareRoute(PlannedRoute route, BuildContext shareContext) async {
    try {
      // Generate GPX content
      final gpxContent = _generateSingleRouteGpx(route);

      // Save to temp file
      final directory = await getTemporaryDirectory();
      final safeName = route.name.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File('${directory.path}/${safeName}_$timestamp.gpx');
      await file.writeAsString(gpxContent);

      // Get button position for share sheet anchor (required on iOS/iPad)
      final box = shareContext.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      // Share the file - opens system share sheet
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          sharePositionOrigin: sharePositionOrigin,
        ),
      );

      debugPrint('Share result: ${result.status}');
    } catch (e) {
      debugPrint('Share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing route: $e')),
        );
      }
    }
  }

  /// Generate GPX content for a single route
  String _generateSingleRouteGpx(PlannedRoute route) {
    final buffer = StringBuffer();

    // GPX header
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="Obsession Tracker" xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>${_escapeXml(route.name)}</name>');
    if (route.description != null && route.description!.isNotEmpty) {
      buffer.writeln('    <desc>${_escapeXml(route.description!)}</desc>');
    }
    buffer.writeln('    <time>${route.createdAt.toUtc().toIso8601String()}</time>');
    buffer.writeln('  </metadata>');

    // Add route as a track
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>${_escapeXml(route.name)}</name>');
    if (route.description != null && route.description!.isNotEmpty) {
      buffer.writeln('    <desc>${_escapeXml(route.description!)}</desc>');
    }
    buffer.writeln('    <type>${route.algorithm.name}</type>');

    // Track segment with all route points
    buffer.writeln('    <trkseg>');
    for (final point in route.routePoints) {
      buffer.writeln('      <trkpt lat="${point.latitude}" lon="${point.longitude}">');
      buffer.writeln('        <time>${route.createdAt.toUtc().toIso8601String()}</time>');
      buffer.writeln('      </trkpt>');
    }
    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');

    // Also add waypoints as separate waypoint entries
    // Start point
    buffer.writeln('  <wpt lat="${route.startPoint.latitude}" lon="${route.startPoint.longitude}">');
    buffer.writeln('    <name>Start</name>');
    buffer.writeln('    <sym>Flag, Green</sym>');
    buffer.writeln('  </wpt>');

    // Intermediate waypoints
    for (int i = 0; i < route.waypoints.length; i++) {
      final waypoint = route.waypoints[i];
      buffer.writeln('  <wpt lat="${waypoint.coordinates.latitude}" lon="${waypoint.coordinates.longitude}">');
      buffer.writeln('    <name>Point ${i + 2}</name>');
      buffer.writeln('    <sym>Circle, Blue</sym>');
      buffer.writeln('  </wpt>');
    }

    // End point
    buffer.writeln('  <wpt lat="${route.endPoint.latitude}" lon="${route.endPoint.longitude}">');
    buffer.writeln('    <name>End</name>');
    buffer.writeln('    <sym>Flag, Red</sym>');
    buffer.writeln('  </wpt>');

    buffer.writeln('</gpx>');
    return buffer.toString();
  }

  /// Escape XML special characters
  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  Future<void> _openRouteDetail(PlannedRoute route) async {
    ref.read(routePlanningProvider.notifier).loadRoute(route.id);
    final result = await Navigator.of(context).push<PlannedRoute>(
      MaterialPageRoute(
        builder: (context) => RoutePlanningPage(existingRoute: route),
      ),
    );

    // If route was updated, refresh the list
    if (result != null && mounted) {
      ref.read(routePlanningProvider.notifier).loadAllRoutes();
    }
  }

  Future<void> _confirmDelete(PlannedRoute route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Route?'),
        content: Text('Are you sure you want to delete "${route.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(routePlanningProvider.notifier).deleteRoute(route.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${route.name}"')),
        );
      }
    }
  }
}
