import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/route_planning_provider.dart';
import 'package:obsession_tracker/core/services/route_planning_service.dart';

/// Modal bottom sheet for selecting a route to follow during tracking
class RouteSelectionModal extends ConsumerStatefulWidget {
  const RouteSelectionModal({super.key});

  @override
  ConsumerState<RouteSelectionModal> createState() => _RouteSelectionModalState();
}

class _RouteSelectionModalState extends ConsumerState<RouteSelectionModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PlannedRoute> _getFilteredRoutes(List<PlannedRoute> routes) {
    // Filter by search query
    final filtered = routes.where((route) {
      if (_searchQuery.isEmpty) return true;
      return route.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (route.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();

    // Sort by most recent first
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routePlanningProvider);
    final routes = _getFilteredRoutes(routeState.savedRoutes);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Route',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${routes.length} route${routes.length != 1 ? 's' : ''} available',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search routes...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              // "No route" option
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.explore, color: Colors.grey),
                ),
                title: const Text('No route - freeform tracking'),
                subtitle: const Text('Track without following a planned route'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context),
              ),

              const Divider(),

              // Route list
              Expanded(
                child: routes.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: routes.length,
                        itemBuilder: (context, index) {
                          final route = routes[index];
                          return _buildRouteCard(route);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteCard(PlannedRoute route) {
    final now = DateTime.now();
    final difference = now.difference(route.createdAt);

    String timeAgo;
    if (difference.inDays > 30) {
      timeAgo = '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() != 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      timeAgo = '${difference.inDays} day${difference.inDays != 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      timeAgo = '${difference.inHours} hour${difference.inHours != 1 ? 's' : ''} ago';
    } else {
      timeAgo = 'Just now';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pop(context, route),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Route icon with difficulty color
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getDifficultyColor(route.difficulty).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.route,
                  color: _getDifficultyColor(route.difficulty),
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              // Route details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (route.description != null)
                      Text(
                        route.description!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${route.routePoints.length} pts',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          route.formattedDistance,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          timeAgo,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No routes found' : 'No matching routes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Create a route in the Routes tab'
                : 'Try a different search term',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(int difficulty) {
    switch (difficulty) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.lightGreen;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.deepOrange;
      case 5:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
