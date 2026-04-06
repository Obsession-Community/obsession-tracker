import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/saved_location_provider.dart';
import 'package:obsession_tracker/core/models/saved_location.dart';

/// Full management page for saved locations.
class SavedLocationsPage extends ConsumerWidget {
  const SavedLocationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(savedLocationProvider);
    final locations = state.locations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Locations'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : locations.isEmpty
              ? _buildEmptyState(context, theme)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: locations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _buildLocationTile(context, ref, locations[index], theme),
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Saved Locations',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save locations from search results to access\n'
              'them quickly offline. Tap the bookmark icon\n'
              'on any search result to save it.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTile(
    BuildContext context,
    WidgetRef ref,
    SavedLocation location,
    ThemeData theme,
  ) {
    return Dismissible(
      key: Key(location.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context, location),
      onDismissed: (_) {
        ref.read(savedLocationProvider.notifier).deleteLocation(location.id);
      },
      child: ListTile(
        leading: Icon(
          Icons.bookmark,
          color: location.isFavorite
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        title: Text(location.displayName),
        subtitle: Text(
          location.address ??
              '${location.latitude.toStringAsFixed(5)}, '
                  '${location.longitude.toStringAsFixed(5)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            location.isFavorite ? Icons.star : Icons.star_border,
            color: location.isFavorite
                ? Colors.amber
                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          onPressed: () {
            ref
                .read(savedLocationProvider.notifier)
                .toggleFavorite(location.id);
          },
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(
    BuildContext context,
    SavedLocation location,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text('Remove "${location.displayName}" from saved locations?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
