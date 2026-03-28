import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/providers/photo_provider.dart';
import 'package:obsession_tracker/features/waypoints/presentation/pages/enhanced_photo_viewer_page.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/photo_annotation_display_widget.dart';

/// Enhanced photo gallery widget with batch operations and advanced features
class EnhancedPhotoGalleryWidget extends ConsumerStatefulWidget {
  const EnhancedPhotoGalleryWidget({
    required this.sessionId,
    super.key,
    this.onPhotoTap,
    this.showSelectionControls = true,
    this.crossAxisCount = 3,
    this.aspectRatio = 1.0,
  });

  final String sessionId;
  final void Function(
          PhotoWaypoint photo, List<PhotoWaypoint> allPhotos, int index)?
      onPhotoTap;
  final bool showSelectionControls;
  final int crossAxisCount;
  final double aspectRatio;

  @override
  ConsumerState<EnhancedPhotoGalleryWidget> createState() =>
      _EnhancedPhotoGalleryWidgetState();
}

class _EnhancedPhotoGalleryWidgetState
    extends ConsumerState<EnhancedPhotoGalleryWidget>
    with TickerProviderStateMixin {
  late AnimationController _selectionController;
  late AnimationController _batchController;

  @override
  void initState() {
    super.initState();
    _selectionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _batchController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Load photos when widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(photoProvider.notifier).loadPhotosForSession(widget.sessionId);
    });
  }

  @override
  void dispose() {
    _selectionController.dispose();
    _batchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photoState = ref.watch(photoProvider);

    return Column(
      children: [
        // Selection controls
        if (widget.showSelectionControls) _buildSelectionControls(photoState),

        // Batch operation progress
        if (photoState.batchOperation != null)
          _buildBatchProgress(photoState.batchOperation!),

        // Photo grid
        Expanded(
          child: _buildPhotoGrid(photoState),
        ),

        // Undo snackbar area
        if (photoState.deletedPhotos.isNotEmpty) _buildUndoArea(photoState),
      ],
    );
  }

  Widget _buildSelectionControls(PhotoState photoState) {
    final selectedCount = photoState.selectedPhotos.length;
    final totalCount = photoState.filteredPhotos.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: photoState.isSelectionMode ? 60 : 0,
      child: photoState.isSelectionMode
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Text(
                    '$selectedCount selected',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const Spacer(),

                  // Select all/none
                  TextButton(
                    onPressed: () {
                      if (selectedCount == totalCount) {
                        ref.read(photoProvider.notifier).clearSelection();
                      } else {
                        ref.read(photoProvider.notifier).selectAllPhotos();
                      }
                    },
                    child: Text(selectedCount == totalCount ? 'None' : 'All'),
                  ),

                  const SizedBox(width: 8),

                  // Batch actions
                  if (selectedCount > 0) ...[
                    IconButton(
                      onPressed: () => _showBatchFavoriteDialog(photoState),
                      icon: const Icon(Icons.favorite_border),
                      tooltip: 'Favorite Selected',
                    ),
                    IconButton(
                      onPressed: () => _showBatchDeleteDialog(photoState),
                      icon: const Icon(Icons.delete),
                      tooltip: 'Delete Selected',
                    ),
                  ],

                  // Exit selection mode
                  IconButton(
                    onPressed: () =>
                        ref.read(photoProvider.notifier).exitSelectionMode(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Exit Selection',
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildBatchProgress(BatchOperationProgress progress) =>
      AnimatedBuilder(
        animation: _batchController,
        builder: (context, child) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_getBatchOperationIcon(progress.type)),
                  const SizedBox(width: 8),
                  Text(
                    _getBatchOperationTitle(progress.type),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  Text(
                    '${progress.completed + progress.failed}/${progress.total}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress.progress,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.3),
              ),
              if (progress.currentItem != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Processing: ${progress.currentItem!.split('/').last}',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (progress.error != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Error: ${progress.error!}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _buildPhotoGrid(PhotoState photoState) {
    if (photoState.isLoading && photoState.photos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (photoState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading photos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              photoState.error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref
                  .read(photoProvider.notifier)
                  .refreshPhotos(widget.sessionId),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (photoState.filteredPhotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No photos found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Photos you take will appear here',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(photoProvider.notifier).refreshPhotos(widget.sessionId),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: widget.aspectRatio,
        ),
        itemCount:
            photoState.filteredPhotos.length + (photoState.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= photoState.filteredPhotos.length) {
            // Load more indicator
            if (!photoState.isLoadingMore) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref
                    .read(photoProvider.notifier)
                    .loadMorePhotos(widget.sessionId);
              });
            }
            return const Center(child: CircularProgressIndicator());
          }

          final photo = photoState.filteredPhotos[index];
          return _buildPhotoTile(photo, index, photoState);
        },
      ),
    );
  }

  Widget _buildPhotoTile(
      PhotoWaypoint photo, int index, PhotoState photoState) {
    final isSelected = photoState.selectedPhotos.contains(photo.id);
    final isSelectionMode = photoState.isSelectionMode;

    return GestureDetector(
      onTap: () => _handlePhotoTap(photo, index, photoState),
      onLongPress: () => _handlePhotoLongPress(photo, photoState),
      child: Stack(
        children: [
          // Photo thumbnail
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    )
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: widget.aspectRatio,
                child: FutureBuilder<File?>(
                  future: _getThumbnailFile(photo),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return Image.file(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildErrorThumbnail(),
                      );
                    }
                    return _buildLoadingThumbnail();
                  },
                ),
              ),
            ),
          ),

          // Selection overlay
          if (isSelectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedScale(
                scale: isSelected ? 1.0 : 0.8,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: Theme.of(context).colorScheme.onPrimary,
                        )
                      : null,
                ),
              ),
            ),

          // Favorite indicator
          if (_isFavorite(photo, photoState))
            const Positioned(
              top: 8,
              left: 8,
              child: Icon(
                Icons.favorite,
                color: Colors.red,
                size: 20,
              ),
            ),

          // Annotation indicator
          if (_hasAnnotations(photo, photoState))
            Positioned(
              top: 8,
              right: isSelectionMode ? 40 : 8,
              child: CompactPhotoAnnotationWidget(
                annotations: _getPhotoAnnotations(photo, photoState),
              ),
            ),

          // Photo info overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(8)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Text(
                _formatPhotoTime(photo.createdAt),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUndoArea(PhotoState photoState) {
    final recentDeletions = photoState.deletedPhotos
        .where((deleted) => deleted.deletedAt
            .isAfter(DateTime.now().subtract(const Duration(seconds: 30))))
        .length;

    if (recentDeletions == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.delete,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$recentDeletions photo${recentDeletions == 1 ? '' : 's'} deleted',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final success =
                  await ref.read(photoProvider.notifier).undoRecentDeletions();
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Photos restored')),
                );
              }
            },
            child: Text(
              'UNDO',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingThumbnail() => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );

  Widget _buildErrorThumbnail() => ColoredBox(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          Icons.broken_image,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      );

  Future<File?> _getThumbnailFile(PhotoWaypoint photo) async {
    try {
      // Try thumbnail first
      if (photo.thumbnailPath != null) {
        final thumbnailFile = File(photo.thumbnailPath!);
        if (thumbnailFile.existsSync()) {
          return thumbnailFile;
        }
      }

      // Fall back to original
      final originalFile = File(photo.filePath);
      if (originalFile.existsSync()) {
        return originalFile;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  void _handlePhotoTap(PhotoWaypoint photo, int index, PhotoState photoState) {
    if (photoState.isSelectionMode) {
      ref.read(photoProvider.notifier).togglePhotoSelection(photo.id);
    } else {
      if (widget.onPhotoTap != null) {
        widget.onPhotoTap!(photo, photoState.filteredPhotos, index);
      } else {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => EnhancedPhotoViewerPage(
              photo: photo,
              sessionId: widget.sessionId,
              initialPhotos: photoState.filteredPhotos,
              initialIndex: index,
            ),
          ),
        );
      }
    }
  }

  void _handlePhotoLongPress(PhotoWaypoint photo, PhotoState photoState) {
    if (!photoState.isSelectionMode) {
      ref.read(photoProvider.notifier).toggleSelectionMode();
      _selectionController.forward();
    }
    ref.read(photoProvider.notifier).togglePhotoSelection(photo.id);
  }

  void _showBatchDeleteDialog(PhotoState photoState) {
    final selectedCount = photoState.selectedPhotos.length;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photos'),
        content: Text(
          'Are you sure you want to delete $selectedCount photo${selectedCount == 1 ? '' : 's'}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              final selectedIds = photoState.selectedPhotos.toList();
              final success = await ref
                  .read(photoProvider.notifier)
                  .batchDeletePhotos(selectedIds, widget.sessionId);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '$selectedCount photo${selectedCount == 1 ? '' : 's'} deleted'
                          : 'Some photos could not be deleted',
                    ),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showBatchFavoriteDialog(PhotoState photoState) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Favorite Photos'),
        content: const Text('Mark selected photos as favorites?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              final selectedIds = photoState.selectedPhotos.toList();
              final success = await ref
                  .read(photoProvider.notifier)
                  .batchToggleFavorite(selectedIds, favorite: true);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Photos marked as favorites'
                          : 'Some photos could not be updated',
                    ),
                  ),
                );
              }
            },
            child: const Text('Favorite'),
          ),
        ],
      ),
    );
  }

  bool _isFavorite(PhotoWaypoint photo, PhotoState photoState) {
    final metadata = photoState.photoMetadata[photo.id] ?? [];
    return metadata.any(
        (meta) => meta.key == CustomKeys.favorite && meta.typedValue == true);
  }

  String _formatPhotoTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  IconData _getBatchOperationIcon(BatchOperationType type) {
    switch (type) {
      case BatchOperationType.delete:
        return Icons.delete;
      case BatchOperationType.favorite:
        return Icons.favorite;
      case BatchOperationType.unfavorite:
        return Icons.favorite_border;
      case BatchOperationType.addTag:
        return Icons.label;
      case BatchOperationType.removeTag:
        return Icons.label_off;
    }
  }

  String _getBatchOperationTitle(BatchOperationType type) {
    switch (type) {
      case BatchOperationType.delete:
        return 'Deleting Photos';
      case BatchOperationType.favorite:
        return 'Adding to Favorites';
      case BatchOperationType.unfavorite:
        return 'Removing from Favorites';
      case BatchOperationType.addTag:
        return 'Adding Tags';
      case BatchOperationType.removeTag:
        return 'Removing Tags';
    }
  }

  bool _hasAnnotations(PhotoWaypoint photo, PhotoState photoState) {
    final metadata = photoState.photoMetadata[photo.id] ?? <PhotoMetadata>[];
    return metadata.any((meta) => meta.isCustomData);
  }

  List<PhotoMetadata> _getPhotoAnnotations(
      PhotoWaypoint photo, PhotoState photoState) {
    final metadata = photoState.photoMetadata[photo.id] ?? <PhotoMetadata>[];
    return metadata.where((meta) => meta.isCustomData).toList();
  }
}
