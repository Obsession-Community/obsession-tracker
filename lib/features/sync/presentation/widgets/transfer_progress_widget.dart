import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/local_sync_models.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';

/// Widget to display transfer progress during sync
class TransferProgressWidget extends StatelessWidget {
  const TransferProgressWidget({
    super.key,
    required this.progress,
    this.title,
  });

  final SyncProgress progress;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated progress indicator
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 6,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.gold.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                // Progress circle
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: progress.progress,
                    strokeWidth: 6,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
                  ),
                ),
                // Percentage text
                Text(
                  progress.formattedProgress,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.gold,
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Title
          if (title != null)
            Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),

          if (title != null) const SizedBox(height: 8),

          // Current item
          if (progress.currentItem != null)
            Text(
              progress.currentItem!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 16),

          // Linear progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.progress,
              backgroundColor: AppTheme.gold.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
              minHeight: 8,
            ),
          ),

          const SizedBox(height: 8),

          // Bytes transferred
          Text(
            progress.formattedBytes,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
          ),
        ],
      ),
    );
  }
}

/// Widget to display sync completion result
class SyncResultWidget extends StatelessWidget {
  const SyncResultWidget({
    super.key,
    required this.result,
    this.onDone,
  });

  final SyncResult result;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final isSuccess = result.success;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isSuccess
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuccess
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            size: 64,
            color: isSuccess ? Colors.green : Colors.red,
          ),

          const SizedBox(height: 16),

          // Title
          Text(
            isSuccess ? 'Transfer Complete!' : 'Transfer Failed',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Details
          if (isSuccess) ...[
            // Show imported items
            if (result.totalImported > 0) ...[
              Text(
                'Imported',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              if (result.sessionsTransferred > 0)
                _buildStatRow(
                  context,
                  Icons.route,
                  'Sessions',
                  result.sessionsTransferred.toString(),
                ),
              if (result.huntsTransferred > 0) ...[
                const SizedBox(height: 4),
                _buildStatRow(
                  context,
                  Icons.search,
                  'Hunts',
                  result.huntsTransferred.toString(),
                ),
              ],
              if (result.routesTransferred > 0) ...[
                const SizedBox(height: 4),
                _buildStatRow(
                  context,
                  Icons.map,
                  'Routes',
                  result.routesTransferred.toString(),
                ),
              ],
              const SizedBox(height: 12),
            ],
            // Show skipped items (already existed)
            if (result.hasSkippedItems) ...[
              Text(
                'Already Existed',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: 8),
              if (result.sessionsSkipped > 0)
                _buildStatRow(
                  context,
                  Icons.route,
                  'Sessions',
                  result.sessionsSkipped.toString(),
                  isSkipped: true,
                ),
              if (result.huntsSkipped > 0) ...[
                const SizedBox(height: 4),
                _buildStatRow(
                  context,
                  Icons.search,
                  'Hunts',
                  result.huntsSkipped.toString(),
                  isSkipped: true,
                ),
              ],
              if (result.routesSkipped > 0) ...[
                const SizedBox(height: 4),
                _buildStatRow(
                  context,
                  Icons.map,
                  'Routes',
                  result.routesSkipped.toString(),
                  isSkipped: true,
                ),
              ],
              const SizedBox(height: 12),
            ],
            // Show message when nothing was transferred
            if (result.totalImported == 0 && result.hasSkippedItems) ...[
              const SizedBox(height: 8),
              Text(
                'All items already existed on this device.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            _buildStatRow(
              context,
              Icons.timer,
              'Duration',
              _formatDuration(result.duration),
            ),
          ] else if (result.error != null) ...[
            Text(
              result.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red,
                  ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),

          // Done button
          if (onDone != null)
            FilledButton(
              onPressed: onDone,
              style: FilledButton.styleFrom(
                backgroundColor: isSuccess ? Colors.green : null,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Done'),
            ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isSkipped = false,
  }) {
    final color = isSkipped
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
        : Colors.green;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isSkipped ? color : null,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isSkipped ? color : null,
              ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
    return '${duration.inSeconds}s';
  }
}
