import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/services/gpx_export_service.dart';

/// Dialog for exporting session data with format options
class SessionExportDialog extends ConsumerStatefulWidget {
  const SessionExportDialog({
    required this.session,
    super.key,
  });

  final TrackingSession session;

  @override
  ConsumerState<SessionExportDialog> createState() =>
      _SessionExportDialogState();
}

class _SessionExportDialogState extends ConsumerState<SessionExportDialog> {
  final GpxExportService _exportService = GpxExportService();
  bool _isLoading = false;
  Map<String, dynamic>? _exportStats;

  @override
  void initState() {
    super.initState();
    _loadExportStats();
  }

  Future<void> _loadExportStats() async {
    final stats = await _exportService.getExportStats(widget.session.id);
    if (mounted) {
      setState(() {
        _exportStats = stats;
      });
    }
  }

  Future<void> _exportToGpx() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _exportService.exportSessionToGpx(widget.session);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session exported successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to export session. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Export Session'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.session.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          widget.session.formattedDuration,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.straighten,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          widget.session.formattedDistance,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Export statistics
            if (_exportStats != null) ...[
              Text(
                'Export Contents',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildStatRow(
                        icon: Icons.timeline,
                        label: 'Track Points',
                        value: '${_exportStats!['breadcrumbCount']}',
                        hasData: _exportStats!['hasTrackData'] as bool,
                      ),
                      const SizedBox(height: 8),
                      _buildStatRow(
                        icon: Icons.place,
                        label: 'Waypoints',
                        value: '${_exportStats!['waypointCount']}',
                        hasData: _exportStats!['hasWaypoints'] as bool,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Format selection
            Text(
              'Export Format',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.map),
                title: const Text('GPX Format'),
                subtitle: const Text(
                    'Standard GPS exchange format compatible with most mapping applications'),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
                onTap: _isLoading ? null : _exportToGpx,
              ),
            ),

            const SizedBox(height: 8),

            // Info note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GPX files can be imported into mapping apps like Google Earth, Garmin devices, and hiking apps.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _exportToGpx,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Export GPX'),
        ),
      ],
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required bool hasData,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: hasData
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: hasData
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          hasData ? Icons.check_circle : Icons.remove_circle,
          size: 16,
          color: hasData ? Colors.green : theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}
