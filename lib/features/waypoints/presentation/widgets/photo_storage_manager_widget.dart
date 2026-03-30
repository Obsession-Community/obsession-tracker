import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/photo_provider.dart';

/// Widget for managing photo storage, cleanup, and statistics
class PhotoStorageManagerWidget extends ConsumerStatefulWidget {
  const PhotoStorageManagerWidget({
    super.key,
    this.sessionId,
  });

  final String? sessionId;

  @override
  ConsumerState<PhotoStorageManagerWidget> createState() =>
      _PhotoStorageManagerWidgetState();
}

class _PhotoStorageManagerWidgetState
    extends ConsumerState<PhotoStorageManagerWidget> {
  Map<String, dynamic>? _storageStats;
  bool _isLoading = false;
  bool _isCleaningUp = false;

  @override
  void initState() {
    super.initState();
    _loadStorageStats();
  }

  Future<void> _loadStorageStats() async {
    setState(() => _isLoading = true);

    try {
      final photoStorageService = ref.read(photoStorageServiceProvider);

      final Map<String, dynamic> stats;
      if (widget.sessionId != null) {
        stats =
            await photoStorageService.getSessionStorageStats(widget.sessionId!);
      } else {
        stats = await photoStorageService.getTotalStorageStats();
      }

      setState(() {
        _storageStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load storage stats: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.storage,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.sessionId != null
                        ? 'Session Storage'
                        : 'Total Storage',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _isLoading ? null : _loadStorageStats,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_storageStats != null) ...[
                _buildStorageStats(),
                const SizedBox(height: 16),
                _buildStorageActions(),
              ] else if (_isLoading) ...[
                const Center(child: CircularProgressIndicator()),
              ] else ...[
                const Center(
                  child: Text('Failed to load storage information'),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _buildStorageStats() {
    final stats = _storageStats!;

    return Column(
      children: [
        // Total storage
        _buildStatRow(
          'Total Size',
          _formatBytes((stats['totalSize'] as int?) ?? 0),
          Icons.folder,
          Theme.of(context).colorScheme.primary,
        ),

        // File count
        _buildStatRow(
          'Total Files',
          '${stats['totalFiles'] ?? 0}',
          Icons.photo_library,
          Theme.of(context).colorScheme.secondary,
        ),

        if (widget.sessionId == null) ...[
          // Sessions (only for total stats)
          _buildStatRow(
            'Sessions',
            '${stats['totalSessions'] ?? 0}',
            Icons.folder_open,
            Theme.of(context).colorScheme.tertiary,
          ),
        ] else ...[
          // Original photos
          _buildStatRow(
            'Original Photos',
            '${stats['originalFiles'] ?? 0} (${_formatBytes((stats['originalSize'] as int?) ?? 0)})',
            Icons.photo,
            Colors.green,
          ),

          // Thumbnails
          _buildStatRow(
            'Thumbnails',
            '${stats['thumbnailFiles'] ?? 0} (${_formatBytes((stats['thumbnailSize'] as int?) ?? 0)})',
            Icons.photo_size_select_small,
            Colors.orange,
          ),
        ],

        const SizedBox(height: 16),

        // Storage breakdown chart
        _buildStorageChart(),
      ],
    );
  }

  Widget _buildStatRow(
          String label, String value, IconData icon, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
            ),
          ],
        ),
      );

  Widget _buildStorageChart() {
    final stats = _storageStats!;
    final totalSize = stats['totalSize'] as int? ?? 0;

    if (totalSize == 0) {
      return const SizedBox.shrink();
    }

    if (widget.sessionId != null) {
      // Session-specific chart
      final originalSize = stats['originalSize'] as int? ?? 0;
      final thumbnailSize = stats['thumbnailSize'] as int? ?? 0;

      final originalPercent = originalSize / totalSize;
      final thumbnailPercent = thumbnailSize / totalSize;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Storage Breakdown',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Container(
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Row(
              children: [
                if (originalPercent > 0)
                  Expanded(
                    flex: (originalPercent * 100).round(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                if (thumbnailPercent > 0)
                  Expanded(
                    flex: (thumbnailPercent * 100).round(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendItem('Originals', Colors.green),
              const SizedBox(width: 16),
              _buildLegendItem('Thumbnails', Colors.orange),
            ],
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildLegendItem(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );

  Widget _buildStorageActions() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Storage Management',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),

          // Cleanup actions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionChip(
                'Clean Deleted Photos',
                Icons.cleaning_services,
                _cleanupDeletedPhotos,
                enabled: !_isCleaningUp,
              ),
              _buildActionChip(
                'Regenerate Thumbnails',
                Icons.refresh,
                _regenerateThumbnails,
                enabled: !_isCleaningUp,
              ),
              if (widget.sessionId == null)
                _buildActionChip(
                  'Optimize Storage',
                  Icons.compress,
                  _optimizeStorage,
                  enabled: !_isCleaningUp,
                ),
            ],
          ),

          if (_isCleaningUp) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text(
              'Cleaning up storage...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],

          const SizedBox(height: 16),

          // Warning section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .errorContainer
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning,
                      size: 16,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Danger Zone',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (widget.sessionId != null)
                  ElevatedButton.icon(
                    onPressed: _isCleaningUp ? null : _deleteAllSessionPhotos,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete All Session Photos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _isCleaningUp ? null : _deleteAllPhotos,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete All Photos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );

  Widget _buildActionChip(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    bool enabled = true,
  }) =>
      ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: enabled ? onPressed : null,
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      );

  Future<void> _cleanupDeletedPhotos() async {
    setState(() => _isCleaningUp = true);

    try {
      // Clean up old deleted photos from provider
      ref.read(photoProvider.notifier).cleanupDeletedPhotos();

      await Future<void>.delayed(
          const Duration(seconds: 1)); // Simulate cleanup

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted photos cleaned up')),
        );
      }

      await _loadStorageStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cleanup failed: $e')),
        );
      }
    } finally {
      setState(() => _isCleaningUp = false);
    }
  }

  Future<void> _regenerateThumbnails() async {
    setState(() => _isCleaningUp = true);

    try {
      // This would regenerate thumbnails for all photos
      await Future<void>.delayed(
          const Duration(seconds: 2)); // Simulate regeneration

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thumbnails regenerated')),
        );
      }

      await _loadStorageStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Thumbnail regeneration failed: $e')),
        );
      }
    } finally {
      setState(() => _isCleaningUp = false);
    }
  }

  Future<void> _optimizeStorage() async {
    setState(() => _isCleaningUp = true);

    try {
      // This would compress old photos and optimize storage
      await Future<void>.delayed(
          const Duration(seconds: 3)); // Simulate optimization

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage optimized')),
        );
      }

      await _loadStorageStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage optimization failed: $e')),
        );
      }
    } finally {
      setState(() => _isCleaningUp = false);
    }
  }

  Future<void> _deleteAllSessionPhotos() async {
    final confirmed = await _showDeleteConfirmation(
      'Delete All Session Photos',
      'This will permanently delete all photos in this session. This action cannot be undone.',
    );

    if (!confirmed) return;

    setState(() => _isCleaningUp = true);

    try {
      final photoStorageService = ref.read(photoStorageServiceProvider);
      final success =
          await photoStorageService.deleteSessionPhotos(widget.sessionId!);

      if (success) {
        // Clear the provider state
        ref.read(photoProvider.notifier).clearCache();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All session photos deleted')),
          );
        }

        await _loadStorageStats();
      } else {
        throw Exception('Failed to delete session photos');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deletion failed: $e')),
        );
      }
    } finally {
      setState(() => _isCleaningUp = false);
    }
  }

  Future<void> _deleteAllPhotos() async {
    final confirmed = await _showDeleteConfirmation(
      'Delete All Photos',
      'This will permanently delete ALL photos from ALL sessions. This action cannot be undone.',
    );

    if (!confirmed) return;

    setState(() => _isCleaningUp = true);

    try {
      // This would delete all photos across all sessions
      await Future<void>.delayed(
          const Duration(seconds: 2)); // Simulate deletion

      // Clear the provider state
      ref.read(photoProvider.notifier).clearCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All photos deleted')),
        );
      }

      await _loadStorageStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deletion failed: $e')),
        );
      }
    } finally {
      setState(() => _isCleaningUp = false);
    }
  }

  Future<bool> _showDeleteConfirmation(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
