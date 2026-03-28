import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:obsession_tracker/core/services/offline_land_rights_service.dart';

class OfflineAreaTile extends StatelessWidget {
  const OfflineAreaTile({
    super.key,
    required this.area,
    this.onDelete,
    this.onRefresh,
    this.onRetry,
  });

  final DownloadArea area;
  final VoidCallback? onDelete;
  final VoidCallback? onRefresh;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with name and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    area.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildStatusChip(context),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'delete':
                        onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Location information
            Row(
              children: [
                Icon(
                  Icons.place,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${area.centerLatitude.toStringAsFixed(4)}, ${area.centerLongitude.toStringAsFixed(4)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  Icons.circle,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${area.radiusKm} km radius',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar (if downloading)
            if (area.status == DownloadStatus.downloading) ...[
              LinearProgressIndicator(
                value: area.progress,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 4),
              Text(
                '${(area.progress * 100).toStringAsFixed(0)}% complete',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],

            // Statistics row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  context,
                  icon: Icons.storage,
                  label: 'Properties',
                  value: area.propertyCount?.toString() ?? '—',
                ),
                _buildStatItem(
                  context,
                  icon: Icons.download,
                  label: 'Downloaded',
                  value: DateFormat('MMM d').format(area.downloadedAt),
                ),
                _buildStatItem(
                  context,
                  icon: Icons.access_time,
                  label: 'Last Used',
                  value: area.lastAccessedAt != null 
                      ? _getRelativeTime(area.lastAccessedAt!)
                      : 'Never',
                ),
              ],
            ),

            // Cache expiration warning
            if (area.status == DownloadStatus.completed && area.isExpired) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 16,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cache expired. Data may be outdated.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onRefresh,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange[700],
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            ],

            // Error state
            if (area.status == DownloadStatus.failed && area.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error,
                      size: 16,
                      color: Colors.red[700],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        area.errorMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onRetry,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red[700],
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String label;

    switch (area.status) {
      case DownloadStatus.pending:
        backgroundColor = Colors.grey.withValues(alpha: 0.2);
        textColor = Colors.grey[700]!;
        icon = Icons.schedule;
        label = 'Pending';
        break;
      case DownloadStatus.downloading:
        backgroundColor = Colors.blue.withValues(alpha: 0.2);
        textColor = Colors.blue[700]!;
        icon = Icons.download;
        label = 'Downloading';
        break;
      case DownloadStatus.completed:
        backgroundColor = area.isExpired 
            ? Colors.orange.withValues(alpha: 0.2)
            : Colors.green.withValues(alpha: 0.2);
        textColor = area.isExpired 
            ? Colors.orange[700]!
            : Colors.green[700]!;
        icon = area.isExpired ? Icons.warning_amber : Icons.check_circle;
        label = area.isExpired ? 'Expired' : 'Ready';
        break;
      case DownloadStatus.failed:
        backgroundColor = Colors.red.withValues(alpha: 0.2);
        textColor = Colors.red[700]!;
        icon = Icons.error;
        label = 'Failed';
        break;
    }

    return Chip(
      avatar: Icon(
        icon,
        size: 16,
        color: textColor,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: backgroundColor,
      side: BorderSide.none,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}