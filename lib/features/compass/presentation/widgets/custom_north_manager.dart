import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/custom_north_reference.dart';
import 'package:obsession_tracker/core/providers/custom_north_provider.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';

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
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Pre-fill with current location if available
    final pos = ref.read(locationProvider).currentPosition;
    if (pos != null) {
      latController.text = pos.latitude.toStringAsFixed(6);
      lonController.text = pos.longitude.toStringAsFixed(6);
    }

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add Custom North'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g., Polaris Peak',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  autofocus: true,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: latController,
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
                TextFormField(
                  controller: lonController,
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
                if (pos != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        latController.text = pos.latitude.toStringAsFixed(6);
                        lonController.text = pos.longitude.toStringAsFixed(6);
                      },
                      icon: const Icon(Icons.gps_fixed, size: 16),
                      label: const Text('Use Current Location'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  ref.read(customNorthProvider.notifier).addReference(
                        nameController.text.trim(),
                        double.parse(latController.text.trim()),
                        double.parse(lonController.text.trim()),
                      );
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } finally {
      nameController.dispose();
      latController.dispose();
      lonController.dispose();
    }
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
