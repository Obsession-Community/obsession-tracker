import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/providers/photo_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';

/// Tablet-optimized photo viewer widget for master-detail layouts
class TabletPhotoViewerWidget extends ConsumerStatefulWidget {
  const TabletPhotoViewerWidget({
    required this.photo,
    required this.sessionId,
    super.key,
    this.onPhotoChanged,
    this.onClose,
  });

  /// The photo to display
  final PhotoWaypoint photo;

  /// Session ID for context
  final String sessionId;

  /// Callback when photo changes (for navigation)
  final void Function(PhotoWaypoint photo, int index)? onPhotoChanged;

  /// Callback when viewer is closed
  final VoidCallback? onClose;

  @override
  ConsumerState<TabletPhotoViewerWidget> createState() =>
      _TabletPhotoViewerWidgetState();
}

class _TabletPhotoViewerWidgetState
    extends ConsumerState<TabletPhotoViewerWidget>
    with TickerProviderStateMixin {
  late AnimationController _metadataController;
  bool _showMetadata = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _metadataController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _metadataController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          // Header with controls
          _buildHeader(),

          // Photo viewer
          Expanded(
            child: Stack(
              children: [
                // Main photo view
                _buildPhotoView(),

                // Metadata panel overlay
                if (_showMetadata) _buildMetadataPanel(),

                // Loading overlay
                if (_isLoading) _buildLoadingOverlay(),
              ],
            ),
          ),

          // Bottom controls
          _buildBottomControls(),
        ],
      );

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border(
            bottom: BorderSide(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDateTime(widget.photo.createdAt),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (widget.photo.dimensionsFormatted != null)
                    Text(
                      '${widget.photo.dimensionsFormatted} • ${widget.photo.fileSizeFormatted}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                ],
              ),
            ),

            // Action buttons
            IconButton(
              onPressed: _toggleFavorite,
              icon: Icon(
                _isFavorite() ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite() ? Colors.red : null,
              ),
              tooltip: 'Toggle Favorite',
            ),

            IconButton(
              onPressed: _toggleMetadata,
              icon: Icon(
                _showMetadata ? Icons.info : Icons.info_outline,
              ),
              tooltip: 'Photo Info',
            ),

            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share),
                    title: Text('Share'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'share_no_location',
                  child: ListTile(
                    leading: Icon(Icons.share_location),
                    title: Text('Share (No Location)'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'show_on_map',
                  child: ListTile(
                    leading: Icon(Icons.map),
                    title: Text('Show on Map'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),

            if (widget.onClose != null)
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
          ],
        ),
      );

  Widget _buildPhotoView() => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: PhotoView(
          imageProvider: FileImage(File(widget.photo.filePath)),
          initialScale: PhotoViewComputedScale.contained,
          minScale: PhotoViewComputedScale.contained * 0.5,
          maxScale: PhotoViewComputedScale.covered * 3.0,
          heroAttributes:
              PhotoViewHeroAttributes(tag: 'photo_${widget.photo.id}'),
          filterQuality: FilterQuality.high,
          backgroundDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
          ),
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
          loadingBuilder: (context, event) => _buildPhotoLoadingWidget(event),
        ),
      );

  Widget _buildMetadataPanel() {
    final photoState = ref.watch(photoProvider);
    final metadata =
        photoState.photoMetadata[widget.photo.id] ?? <PhotoMetadata>[];

    return AnimatedBuilder(
      animation: _metadataController,
      builder: (context, child) => Positioned(
        right: -350 + (350 * _metadataController.value),
        top: 0,
        bottom: 0,
        child: Container(
          width: 350,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Metadata header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Photo Details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _toggleMetadata,
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                    ),
                  ],
                ),
              ),

              // Metadata content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetadataSection('Basic Information', [
                        _MetadataItem(
                            'Created', _formatDateTime(widget.photo.createdAt)),
                        _MetadataItem(
                            'File Size', widget.photo.fileSizeFormatted),
                        if (widget.photo.dimensionsFormatted != null)
                          _MetadataItem(
                              'Dimensions', widget.photo.dimensionsFormatted!),
                        _MetadataItem(
                            'File Name', widget.photo.filePath.split('/').last),
                      ]),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildMetadataSection(
                          'Location Data',
                          metadata
                              .where((m) => m.key.startsWith('location_'))
                              .map((m) => _MetadataItem(
                                  _formatMetadataKey(m.key), m.displayValue))
                              .toList(),
                        ),
                        const SizedBox(height: 24),
                        _buildMetadataSection(
                          'Camera Settings',
                          metadata
                              .where((m) => m.isExifData)
                              .map((m) => _MetadataItem(
                                  _formatMetadataKey(m.key), m.displayValue))
                              .toList(),
                        ),
                        const SizedBox(height: 24),
                        _buildMetadataSection(
                          'Custom Data',
                          metadata
                              .where((m) => m.isCustomData)
                              .map((m) => _MetadataItem(
                                  _formatMetadataKey(m.key), m.displayValue))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _buildPrivacyInfo(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataSection(String title, List<_MetadataItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      item.key,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      item.value,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildPrivacyInfo() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.privacy_tip,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Privacy Notice',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'This photo contains location metadata. Use "Share (No Location)" to remove GPS data when sharing.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
            ),
          ],
        ),
      );

  Widget _buildBottomControls() {
    final photoState = ref.watch(photoProvider);
    final allPhotos = photoState.filteredPhotos;
    final currentIndex = allPhotos.indexWhere((p) => p.id == widget.photo.id);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Navigation info
          if (allPhotos.length > 1)
            Text(
              '${currentIndex + 1} of ${allPhotos.length}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),

          const Spacer(),

          // Navigation buttons
          if (allPhotos.length > 1) ...[
            IconButton(
              onPressed: currentIndex > 0 ? _previousPhoto : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous Photo',
            ),
            IconButton(
              onPressed:
                  currentIndex < allPhotos.length - 1 ? _nextPhoto : null,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next Photo',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorWidget() => ColoredBox(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image,
                size: 64,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load image',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
              ),
            ],
          ),
        ),
      );

  Widget _buildPhotoLoadingWidget(ImageChunkEvent? event) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: event?.expectedTotalBytes != null
                  ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              event?.expectedTotalBytes != null
                  ? 'Loading ${(event!.cumulativeBytesLoaded / 1024 / 1024).toStringAsFixed(1)}MB / ${(event.expectedTotalBytes! / 1024 / 1024).toStringAsFixed(1)}MB'
                  : 'Loading image...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );

  Widget _buildLoadingOverlay() => ColoredBox(
        color: Colors.black.withValues(alpha: 0.5),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );

  void _toggleMetadata() {
    setState(() {
      _showMetadata = !_showMetadata;
    });

    if (_showMetadata) {
      _metadataController.forward();
    } else {
      _metadataController.reverse();
    }
  }

  bool _isFavorite() {
    final photoState = ref.read(photoProvider);
    final metadata =
        photoState.photoMetadata[widget.photo.id] ?? <PhotoMetadata>[];
    return metadata.any(
        (meta) => meta.key == CustomKeys.favorite && meta.typedValue == true);
  }

  void _toggleFavorite() {
    final photoNotifier = ref.read(photoProvider.notifier);
    photoNotifier.toggleFavorite(widget.photo);
  }

  void _previousPhoto() {
    final photoState = ref.read(photoProvider);
    final allPhotos = photoState.filteredPhotos;
    final currentIndex = allPhotos.indexWhere((p) => p.id == widget.photo.id);

    if (currentIndex > 0) {
      final previousPhoto = allPhotos[currentIndex - 1];
      widget.onPhotoChanged?.call(previousPhoto, currentIndex - 1);
    }
  }

  void _nextPhoto() {
    final photoState = ref.read(photoProvider);
    final allPhotos = photoState.filteredPhotos;
    final currentIndex = allPhotos.indexWhere((p) => p.id == widget.photo.id);

    if (currentIndex < allPhotos.length - 1) {
      final nextPhoto = allPhotos[currentIndex + 1];
      widget.onPhotoChanged?.call(nextPhoto, currentIndex + 1);
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'share':
        _sharePhoto();
        break;
      case 'share_no_location':
        _sharePhoto(includeLocation: false);
        break;
      case 'show_on_map':
        _showOnMap();
        break;
      case 'delete':
        _deletePhoto();
        break;
    }
  }

  Future<void> _sharePhoto({bool includeLocation = true}) async {
    try {
      setState(() => _isLoading = true);

      await SharePlus.instance.share(
        ShareParams(
          text: includeLocation
              ? 'Photo taken at ${_formatDateTime(widget.photo.createdAt)}'
              : 'Photo (location data removed)',
          files: [XFile(widget.photo.filePath)],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share photo: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showOnMap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Map integration not yet implemented')),
    );
  }

  void _deletePhoto() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text(
            'Are you sure you want to delete this photo? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              setState(() => _isLoading = true);

              final photoNotifier = ref.read(photoProvider.notifier);
              final success = await photoNotifier.deletePhoto(widget.photo);

              if (success && mounted) {
                widget.onClose?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Photo deleted')),
                );
              }

              setState(() => _isLoading = false);
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

  String _formatDateTime(DateTime dateTime) =>
      '${dateTime.day}/${dateTime.month}/${dateTime.year} '
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';

  String _formatMetadataKey(String key) => key
      .replaceAll('_', ' ')
      .replaceAll('location', '')
      .replaceAll('exif', '')
      .replaceAll('custom', '')
      .trim()
      .split(' ')
      .map((word) =>
          word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

class _MetadataItem {
  const _MetadataItem(this.key, this.value);

  final String key;
  final String value;
}
