import 'dart:io';

import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/imported_route.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/route_import_service.dart';
import 'package:obsession_tracker/features/routes/presentation/pages/route_library_page.dart';
import 'package:obsession_tracker/features/routes/presentation/pages/route_planning_page.dart';
import 'package:obsession_tracker/features/routes/presentation/widgets/route_import_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Page for managing imported routes and planned routes
class RoutesPage extends StatefulWidget {
  const RoutesPage({super.key});

  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> {
  final RouteImportService _routeImportService = RouteImportService();
  List<ImportedRoute> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final routes = await _routeImportService.getAllRoutes();
      setState(() {
        _routes = routes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load routes: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routes'),
        actions: [
          IconButton(
            onPressed: _openRoutePlanner,
            icon: const Icon(Icons.add_location_alt),
            tooltip: 'Plan New Route',
          ),
          IconButton(
            onPressed: _openPlannedRoutes,
            icon: const Icon(Icons.folder),
            tooltip: 'My Planned Routes',
          ),
          IconButton(
            onPressed: _showImportDialog,
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import Route',
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick action buttons at the top
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openRoutePlanner,
                    icon: const Icon(Icons.edit_location),
                    label: const Text('Plan Route'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openPlannedRoutes,
                    icon: const Icon(Icons.route),
                    label: const Text('My Routes'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // Existing imported routes list
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showImportDialog,
        tooltip: 'Import Route',
        child: const Icon(Icons.file_upload),
      ),
    );
  }

  void _openRoutePlanner() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const RoutePlanningPage(),
      ),
    ).then((_) => _loadRoutes()); // Refresh when returning
  }

  void _openPlannedRoutes() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const RouteLibraryPage(),
      ),
    ).then((_) => _loadRoutes()); // Refresh when returning
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_routes.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadRoutes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _routes.length,
        itemBuilder: (context, index) => _buildRouteCard(_routes[index]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.route,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No imported routes',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create custom routes or import GPX/KML files',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showImportDialog,
            icon: const Icon(Icons.file_upload),
            label: const Text('Import Route'),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(ImportedRoute route) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            route.sourceFormat.toUpperCase()[0],
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          route.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (route.description != null) ...[
              const SizedBox(height: 4),
              Text(
                route.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _buildChip(
                  Icons.straighten,
                  '${(route.totalDistance / 1000).toStringAsFixed(1)} km',
                ),
                const SizedBox(width: 8),
                _buildChip(
                  Icons.timeline,
                  '${route.points.length} pts',
                ),
                if (route.waypoints.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildChip(
                    Icons.place,
                    '${route.waypoints.length} wp',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Imported ${_formatDate(route.importedAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleRouteAction(value, route),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility),
                  SizedBox(width: 8),
                  Text('View on Map'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'follow',
              child: Row(
                children: [
                  Icon(Icons.directions),
                  SizedBox(width: 8),
                  Text('Start Following'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Rename'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share),
                  SizedBox(width: 8),
                  Text('Export GPX'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _handleRouteAction('view', route),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _showImportDialog() async {
    final route = await showDialog<ImportedRoute>(
      context: context,
      builder: (context) => const RouteImportDialog(),
    );
    if (route != null) {
      _loadRoutes(); // Refresh the list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported "${route.name}" successfully')),
        );
      }
    }
  }

  void _handleRouteAction(String action, ImportedRoute route) {
    switch (action) {
      case 'view':
        _viewRoute(route);
        break;
      case 'follow':
        _followRoute(route);
        break;
      case 'rename':
        _renameRoute(route);
        break;
      case 'share':
        _shareRoute(route);
        break;
      case 'delete':
        _deleteRoute(route);
        break;
    }
  }

  void _viewRoute(ImportedRoute route) {
    // Navigate to map page with the route displayed
    Navigator.of(context).pushNamed(
      '/route-map',
      arguments: {'routeId': route.id},
    );
  }

  Future<void> _followRoute(ImportedRoute route) async {
    // Create a tracking session with the route name
    final session = TrackingSession.create(
      id: 'session-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Following: ${route.name}',
      description: 'Route following session for ${route.name}',
    );

    // Save the session
    final dbService = DatabaseService();
    await dbService.insertSession(session);

    if (!mounted) return;

    // Navigate to tracking page
    Navigator.of(context).pushNamed('/tracking', arguments: {
      'sessionId': session.id,
      'followingRoute': route,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Started following "${route.name}"'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _renameRoute(ImportedRoute route) async {
    final controller = TextEditingController(text: route.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Route'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Route Name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != route.name) {
      try {
        final updatedRoute = route.copyWith(
          name: newName,
          updatedAt: DateTime.now(),
        );
        await _routeImportService.updateRoute(updatedRoute);
        _loadRoutes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Route renamed successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to rename route: $e')),
          );
        }
      }
    }
  }

  Future<void> _shareRoute(ImportedRoute route) async {
    try {
      // Export route to GPX format
      final gpxContent = _routeImportService.exportToGPX(route);

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final fileName = '${route.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.gpx';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(gpxContent);

      // Share the file
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sharing ${route.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export route: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRoute(ImportedRoute route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text(
            'Are you sure you want to delete "${route.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _routeImportService.deleteRoute(route.id);
        _loadRoutes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Route deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete route: $e')),
          );
        }
      }
    }
  }
}
