import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/providers/photo_provider.dart';

/// A responsive photo gallery widget with grid layout
class PhotoGalleryWidget extends ConsumerStatefulWidget {
  const PhotoGalleryWidget({
    required this.sessionId,
    super.key,
    this.crossAxisCount,
    this.onPhotoTap,
    this.onPhotoLongPress,
    this.showMetadata = true,
    this.enableSelection = false,
    this.selectedPhotos = const <String>{},
    this.onSelectionChanged,
  });

  /// Session ID to load photos for
  final String sessionId;

  /// Number of columns in the grid (auto-calculated if null)
  final int? crossAxisCount;

  /// Callback when a photo is tapped
  final void Function(PhotoWaypoint photo)? onPhotoTap;

  /// Callback when a photo is long pressed
  final void Function(PhotoWaypoint photo)? onPhotoLongPress;

  /// Whether to show metadata overlay
  final bool showMetadata;

  /// Whether selection mode is enabled
  final bool enableSelection;

  /// Currently selected photo IDs
  final Set<String> selectedPhotos;

  /// Callback when selection changes
  final void Function(Set<String> selectedPhotos)? onSelectionChanged;

  @override
  ConsumerState<PhotoGalleryWidget> createState() => _PhotoGalleryWidgetState();
}

class _PhotoGalleryWidgetState extends ConsumerState<PhotoGalleryWidget> {
  final ScrollController _scrollController = ScrollController();
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more photos when near the bottom
      ref.read(photoProvider.notifier).loadMorePhotos(widget.sessionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoState = ref.watch(photoProvider);
    final photoNotifier = ref.read(photoProvider.notifier);

    // Initialize photos on first build
    if (!_hasInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        photoNotifier.loadPhotosForSession(widget.sessionId);
      });
      _hasInitialized = true;
    }

    return RefreshIndicator(
      onRefresh: () => photoNotifier.refreshPhotos(widget.sessionId),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Filter and search bar
          SliverToBoxAdapter(
            child: _buildFilterBar(context, photoState, photoNotifier),
          ),

          // Photo count
          SliverToBoxAdapter(
            child: _buildPhotoCount(context, photoState),
          ),

          // Photo grid
          if (photoState.isLoading && photoState.filteredPhotos.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (photoState.error != null)
            SliverFillRemaining(
              child:
                  _buildErrorWidget(context, photoState.error!, photoNotifier),
            )
          else if (photoState.filteredPhotos.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyWidget(context),
            )
          else
            SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _calculateCrossAxisCount(context),
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index < photoState.filteredPhotos.length) {
                    return _buildPhotoTile(
                      context,
                      photoState.filteredPhotos[index],
                      photoState,
                      photoNotifier,
                    );
                  } else if (photoState.isLoadingMore) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  return null;
                },
                childCount: photoState.filteredPhotos.length +
                    (photoState.isLoadingMore ? 1 : 0),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    PhotoState photoState,
    PhotoNotifier photoNotifier,
  ) =>
      Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search photos...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: photoState.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => photoNotifier.setSearchQuery(''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: photoNotifier.setSearchQuery,
            ),

            const SizedBox(height: 12),

            // Filter and sort row
            Row(
              children: [
                // Filter dropdown
                Expanded(
                  child: DropdownButtonFormField<PhotoFilter>(
                    initialValue: photoState.currentFilter,
                    decoration: InputDecoration(
                      labelText: 'Filter',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: PhotoFilter.values
                        .map((filter) => DropdownMenuItem(
                              value: filter,
                              child: Text(_getFilterLabel(filter)),
                            ))
                        .toList(),
                    onChanged: (filter) {
                      if (filter != null) {
                        photoNotifier.setFilter(filter);
                      }
                    },
                  ),
                ),

                const SizedBox(width: 12),

                // Sort dropdown
                Expanded(
                  child: DropdownButtonFormField<PhotoSort>(
                    initialValue: photoState.currentSort,
                    decoration: InputDecoration(
                      labelText: 'Sort',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: PhotoSort.values
                        .map((sort) => DropdownMenuItem(
                              value: sort,
                              child: Text(_getSortLabel(sort)),
                            ))
                        .toList(),
                    onChanged: (sort) {
                      if (sort != null) {
                        photoNotifier.setSort(sort);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildPhotoCount(BuildContext context, PhotoState photoState) {
    if (photoState.filteredPhotos.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        '${photoState.filteredPhotos.length} photo${photoState.filteredPhotos.length == 1 ? '' : 's'}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
      ),
    );
  }

  Widget _buildPhotoTile(
    BuildContext context,
    PhotoWaypoint photo,
    PhotoState photoState,
    PhotoNotifier photoNotifier,
  ) {
    final isSelected = widget.selectedPhotos.contains(photo.id);
    final metadata = photoState.photoMetadata[photo.id] ?? <PhotoMetadata>[];
    final isFavorite = metadata.any(
        (meta) => meta.key == CustomKeys.favorite && meta.typedValue == true);

    return GestureDetector(
      onTap: () => _handlePhotoTap(photo),
      onLongPress: () => _handlePhotoLongPress(photo),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo thumbnail
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    )
                  : null,
            ),
            child: FutureBuilder<Uint8List?>(
              future: photoNotifier.getThumbnail(photo),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPhotoPlaceholder(context, photo),
                  );
                } else if (photo.hasThumbnail && photo.thumbnailPath != null) {
                  return Image.file(
                    File(photo.thumbnailPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPhotoPlaceholder(context, photo),
                  );
                } else {
                  return Image.file(
                    File(photo.filePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPhotoPlaceholder(context, photo),
                  );
                }
              },
            ),
          ),

          // Selection overlay
          if (widget.enableSelection)
            Positioned(
              top: 8,
              right: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),

          // Favorite indicator
          if (isFavorite && !widget.enableSelection)
            const Positioned(
              top: 8,
              right: 8,
              child: Icon(
                Icons.favorite,
                color: Colors.red,
                size: 20,
              ),
            ),

          // Metadata overlay
          if (widget.showMetadata)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDateTime(photo.createdAt),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (photo.dimensionsFormatted != null)
                      Text(
                        photo.dimensionsFormatted!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoPlaceholder(BuildContext context, PhotoWaypoint photo) =>
      ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo,
              size: 32,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              photo.fileSizeFormatted,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildErrorWidget(
    BuildContext context,
    String error,
    PhotoNotifier photoNotifier,
  ) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  photoNotifier.clearError();
                  photoNotifier.refreshPhotos(widget.sessionId);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmptyWidget(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No photos found',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Photos you capture will appear here',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  void _handlePhotoTap(PhotoWaypoint photo) {
    if (widget.enableSelection) {
      _toggleSelection(photo.id);
    } else {
      widget.onPhotoTap?.call(photo);
    }
  }

  void _handlePhotoLongPress(PhotoWaypoint photo) {
    if (widget.enableSelection) {
      _toggleSelection(photo.id);
    } else {
      widget.onPhotoLongPress?.call(photo);
    }
  }

  void _toggleSelection(String photoId) {
    final Set<String> newSelection = Set<String>.from(widget.selectedPhotos);
    if (newSelection.contains(photoId)) {
      newSelection.remove(photoId);
    } else {
      newSelection.add(photoId);
    }
    widget.onSelectionChanged?.call(newSelection);
  }

  int _calculateCrossAxisCount(BuildContext context) {
    if (widget.crossAxisCount != null) {
      return widget.crossAxisCount!;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) {
      return 6; // Desktop/large tablet
    } else if (screenWidth > 800) {
      return 4; // Tablet
    } else if (screenWidth > 600) {
      return 3; // Large phone/small tablet
    } else {
      return 2; // Phone
    }
  }

  String _getFilterLabel(PhotoFilter filter) {
    switch (filter) {
      case PhotoFilter.all:
        return 'All Photos';
      case PhotoFilter.today:
        return 'Today';
      case PhotoFilter.thisWeek:
        return 'This Week';
      case PhotoFilter.thisMonth:
        return 'This Month';
      case PhotoFilter.favorites:
        return 'Favorites';
    }
  }

  String _getSortLabel(PhotoSort sort) {
    switch (sort) {
      case PhotoSort.newest:
        return 'Newest First';
      case PhotoSort.oldest:
        return 'Oldest First';
      case PhotoSort.name:
        return 'Name';
      case PhotoSort.size:
        return 'File Size';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
