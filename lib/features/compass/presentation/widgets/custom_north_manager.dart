import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/custom_north_reference.dart';
import 'package:obsession_tracker/core/providers/custom_north_provider.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/core/providers/map_search_provider.dart';
import 'package:obsession_tracker/core/services/map_search_service.dart';

/// Bottom sheet for managing saved custom North references.
class CustomNorthManager extends ConsumerStatefulWidget {
  const CustomNorthManager({super.key});

  /// Show this as a modal bottom sheet.
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const CustomNorthManager(),
      );

  @override
  ConsumerState<CustomNorthManager> createState() => _CustomNorthManagerState();
}

class _CustomNorthManagerState extends ConsumerState<CustomNorthManager> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customNorthState = ref.watch(customNorthProvider);
    final references = customNorthState.references;
    final activeRef = customNorthState.activeReference;

    return DraggableScrollableSheet(
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.my_location, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Custom North References',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Magnetic North toggle
                if (activeRef != null)
                  TextButton.icon(
                    onPressed: () {
                      ref
                          .read(customNorthProvider.notifier)
                          .setActiveReference(null);
                    },
                    icon: const Icon(Icons.explore, size: 18),
                    label: const Text('Magnetic'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Reference list or empty state
          Expanded(
            child: references.isEmpty
                ? _buildEmptyState(theme)
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: references.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) => _buildReferenceTile(
                      context,
                      references[index],
                      isActive: activeRef?.id == references[index].id,
                    ),
                  ),
          ),

          // Add button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _showAddDialog(context),
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Add Custom North'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_off,
              size: 64,
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Custom North References',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a GPS coordinate to use as your custom North.\n'
              'Great for treasure hunts with directional clues!',
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

  Widget _buildReferenceTile(
    BuildContext context,
    CustomNorthReference reference, {
    required bool isActive,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: isActive ? 2 : 0,
      color: isActive
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: ListTile(
        leading: Icon(
          isActive ? Icons.my_location : Icons.location_on_outlined,
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        title: Text(
          reference.name,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          '${reference.latitude.toStringAsFixed(5)}°, '
          '${reference.longitude.toStringAsFixed(5)}°',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: isActive
                ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        trailing: isActive
            ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
            : null,
        onTap: () {
          ref.read(customNorthProvider.notifier).setActiveReference(
                isActive ? null : reference.id,
              );
        },
        onLongPress: () => _confirmDelete(context, reference),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final searchService = ref.read(mapSearchServiceProvider);
    final pos = ref.read(locationProvider).currentPosition;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddCustomNorthDialog(
        theme: theme,
        searchService: searchService,
        currentLat: pos?.latitude,
        currentLon: pos?.longitude,
        onSave: (name, lat, lon) {
          ref.read(customNorthProvider.notifier).addReference(name, lat, lon);
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CustomNorthReference reference,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reference'),
        content: Text('Delete "${reference.name}"? This cannot be undone.'),
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

    if (confirmed == true) {
      ref.read(customNorthProvider.notifier).deleteReference(reference.id);
    }
  }
}

/// Stateful dialog for adding a custom North reference with place search.
class _AddCustomNorthDialog extends StatefulWidget {
  const _AddCustomNorthDialog({
    required this.theme,
    required this.searchService,
    required this.onSave,
    this.currentLat,
    this.currentLon,
  });

  final ThemeData theme;
  final MapSearchService searchService;
  final void Function(String name, double lat, double lon) onSave;
  final double? currentLat;
  final double? currentLon;

  @override
  State<_AddCustomNorthDialog> createState() => _AddCustomNorthDialogState();
}

class _AddCustomNorthDialogState extends State<_AddCustomNorthDialog> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();

  Timer? _debounce;
  List<MapSearchResult> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentLat != null && widget.currentLon != null) {
      _latController.text = widget.currentLat!.toStringAsFixed(6);
      _lonController.text = widget.currentLon!.toStringAsFixed(6);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await widget.searchService.search(
          query.trim(),
          proximityLat: widget.currentLat,
          proximityLon: widget.currentLon,
        );
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _selectResult(MapSearchResult result) async {
    var selected = result;
    // Retrieve coordinates if needed (Mapbox suggestion pattern)
    if (selected.needsRetrieval && selected.mapboxId != null) {
      final retrieved =
          await widget.searchService.retrieveCoordinates(selected);
      if (retrieved != null) selected = retrieved;
    }

    if (selected.latitude != null && selected.longitude != null) {
      setState(() {
        _nameController.text = selected.displayName;
        _latController.text = selected.latitude!.toStringAsFixed(6);
        _lonController.text = selected.longitude!.toStringAsFixed(6);
        _searchResults = [];
        _searchController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Custom North'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Place search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search a place',
                    hintText: 'e.g., Polaris, MT',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchResults = []);
                                },
                              )
                            : null,
                  ),
                  onChanged: _onSearchChanged,
                ),

                // Search results
                if (_searchResults.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: widget.theme.colorScheme.outline
                            .withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final r = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.place,
                            size: 20,
                            color: widget.theme.colorScheme.primary,
                          ),
                          title: Text(
                            r.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: r.address != null
                              ? Text(
                                  r.address!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                          onTap: () => _selectResult(r),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 16),

                // Name field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g., Polaris Peak',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 12),

                // Latitude
                TextFormField(
                  controller: _latController,
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    hintText: 'e.g., 45.3772',
                    prefixIcon: Icon(Icons.north),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final val = double.tryParse(v.trim());
                    if (val == null || val < -90 || val > 90) {
                      return 'Must be between -90 and 90';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Longitude
                TextFormField(
                  controller: _lonController,
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    hintText: 'e.g., -113.7872',
                    prefixIcon: Icon(Icons.east),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final val = double.tryParse(v.trim());
                    if (val == null || val < -180 || val > 180) {
                      return 'Must be between -180 and 180';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Use current location button
                if (widget.currentLat != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        _latController.text =
                            widget.currentLat!.toStringAsFixed(6);
                        _lonController.text =
                            widget.currentLon!.toStringAsFixed(6);
                      },
                      icon: const Icon(Icons.gps_fixed, size: 16),
                      label: const Text('Use Current Location'),
                      style: TextButton.styleFrom(
                        foregroundColor: widget.theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              widget.onSave(
                _nameController.text.trim(),
                double.parse(_latController.text.trim()),
                double.parse(_lonController.text.trim()),
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
