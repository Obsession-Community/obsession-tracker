import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:obsession_tracker/core/models/local_sync_models.dart';
import 'package:obsession_tracker/core/providers/local_sync_provider.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';

/// Page for selecting specific items to sync
class SelectSyncItemsPage extends ConsumerStatefulWidget {
  const SelectSyncItemsPage({
    required this.password,
    super.key,
  });

  /// The password for the sync session (passed from send page)
  final String password;

  @override
  ConsumerState<SelectSyncItemsPage> createState() =>
      _SelectSyncItemsPageState();
}

class _SelectSyncItemsPageState extends ConsumerState<SelectSyncItemsPage> {
  bool _sessionsExpanded = true;
  bool _huntsExpanded = true;
  bool _routesExpanded = true;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    // Load available items when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(localSyncProvider.notifier).loadAvailableItems();
    });
  }

  Future<void> _startSelectiveSync() async {
    final syncState = ref.read(localSyncProvider);
    if (!syncState.hasSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item to send'),
        ),
      );
      return;
    }

    setState(() => _isStarting = true);

    try {
      await ref.read(localSyncProvider.notifier).startSendSession(
            password: widget.password,
            useSelection: true,
          );

      if (mounted) {
        // Pop back to send page which will show the QR code
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(localSyncProvider);
    final availableItems = syncState.availableItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Items'),
        centerTitle: true,
      ),
      body: availableItems == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: context.responsivePadding,
                    child: ResponsiveContentBox(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Info text
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.gold.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.checklist,
                                  color: AppTheme.gold,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Select the items you want to transfer',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Sessions section
                          if (availableItems.sessions.isNotEmpty)
                            _buildSection(
                              title: 'Sessions',
                              icon: Icons.route,
                              items: availableItems.sessions,
                              selectedIds: syncState.selectedSessionIds,
                              isExpanded: _sessionsExpanded,
                              onExpandChanged: (expanded) =>
                                  setState(() => _sessionsExpanded = expanded),
                              onToggleItem: (id) => ref
                                  .read(localSyncProvider.notifier)
                                  .toggleSessionSelection(id),
                              onSelectAll: () => ref
                                  .read(localSyncProvider.notifier)
                                  .selectAllSessions(),
                              onDeselectAll: () => ref
                                  .read(localSyncProvider.notifier)
                                  .deselectAllSessions(),
                              itemBuilder: _buildSessionItem,
                            ),

                          // Hunts section
                          if (availableItems.hunts.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildSection(
                              title: 'Hunts',
                              icon: Icons.explore,
                              items: availableItems.hunts,
                              selectedIds: syncState.selectedHuntIds,
                              isExpanded: _huntsExpanded,
                              onExpandChanged: (expanded) =>
                                  setState(() => _huntsExpanded = expanded),
                              onToggleItem: (id) => ref
                                  .read(localSyncProvider.notifier)
                                  .toggleHuntSelection(id),
                              onSelectAll: () => ref
                                  .read(localSyncProvider.notifier)
                                  .selectAllHunts(),
                              onDeselectAll: () => ref
                                  .read(localSyncProvider.notifier)
                                  .deselectAllHunts(),
                              itemBuilder: _buildHuntItem,
                            ),
                          ],

                          // Routes section
                          if (availableItems.routes.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildSection(
                              title: 'Routes',
                              icon: Icons.map,
                              items: availableItems.routes,
                              selectedIds: syncState.selectedRouteIds,
                              isExpanded: _routesExpanded,
                              onExpandChanged: (expanded) =>
                                  setState(() => _routesExpanded = expanded),
                              onToggleItem: (id) => ref
                                  .read(localSyncProvider.notifier)
                                  .toggleRouteSelection(id),
                              onSelectAll: () => ref
                                  .read(localSyncProvider.notifier)
                                  .selectAllRoutes(),
                              onDeselectAll: () => ref
                                  .read(localSyncProvider.notifier)
                                  .deselectAllRoutes(),
                              itemBuilder: _buildRouteItem,
                            ),
                          ],

                          // Empty state
                          if (availableItems.sessions.isEmpty &&
                              availableItems.hunts.isEmpty &&
                              availableItems.routes.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      size: 64,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No data to transfer',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom bar with selection summary and continue button
                _buildBottomBar(syncState),
              ],
            ),
    );
  }

  Widget _buildSection<T>({
    required String title,
    required IconData icon,
    required List<T> items,
    required Set<String> selectedIds,
    required bool isExpanded,
    required void Function(bool) onExpandChanged,
    required void Function(String) onToggleItem,
    required VoidCallback onSelectAll,
    required VoidCallback onDeselectAll,
    required Widget Function(T) itemBuilder,
  }) {
    final allSelected =
        items.every((item) => selectedIds.contains((item as dynamic).id));

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => onExpandChanged(!isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$title (${items.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  // Select all / Deselect all
                  TextButton(
                    onPressed: allSelected ? onDeselectAll : onSelectAll,
                    child: Text(
                      allSelected ? 'Deselect All' : 'Select All',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                ],
              ),
            ),
          ),

          // Items list
          if (isExpanded)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final id = (item as dynamic).id as String;
                final isSelected = selectedIds.contains(id);

                return InkWell(
                  onTap: () => onToggleItem(id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) => onToggleItem(id),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: itemBuilder(item)),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(SyncSessionItem session) {
    final dateFormat = DateFormat.yMMMd();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          session.name,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 4),
        Text(
          '${dateFormat.format(session.createdAt)} - '
          '${session.waypointCount} waypoints, '
          '${_formatDistance(session.distanceMeters ?? 0)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
      ],
    );
  }

  Widget _buildHuntItem(SyncHuntItem hunt) {
    final dateFormat = DateFormat.yMMMd();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hunt.name,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 4),
        Text(
          '${dateFormat.format(hunt.createdAt)} - ${hunt.clueCount} clues',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
      ],
    );
  }

  Widget _buildRouteItem(SyncRouteItem route) {
    final dateFormat = DateFormat.yMMMd();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          route.name,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 4),
        Text(
          '${dateFormat.format(route.importedAt)} - '
          '${route.pointCount} points, '
          '${_formatDistance(route.totalDistance ?? 0)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(LocalSyncProviderState syncState) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Selection summary
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${syncState.selectedItemCount} items selected',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (syncState.hasSelection)
                  Text(
                    _buildSelectionSummary(syncState),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
              ],
            ),
          ),

          // Continue button
          FilledButton.icon(
            onPressed:
                _isStarting || !syncState.hasSelection ? null : _startSelectiveSync,
            icon: _isStarting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_forward),
            label: Text(_isStarting ? 'Starting...' : 'Continue'),
          ),
        ],
      ),
    );
  }

  String _buildSelectionSummary(LocalSyncProviderState syncState) {
    final parts = <String>[];
    if (syncState.selectedSessionIds.isNotEmpty) {
      parts.add('${syncState.selectedSessionIds.length} sessions');
    }
    if (syncState.selectedHuntIds.isNotEmpty) {
      parts.add('${syncState.selectedHuntIds.length} hunts');
    }
    if (syncState.selectedRouteIds.isNotEmpty) {
      parts.add('${syncState.selectedRouteIds.length} routes');
    }
    return parts.join(', ');
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }
}
