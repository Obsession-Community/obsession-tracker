import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/providers/photo_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Full-screen photo viewer with pinch-to-zoom and metadata overlay
class PhotoViewerPage extends ConsumerStatefulWidget {
  const PhotoViewerPage({
    required this.photo,
    required this.sessionId,
    super.key,
    this.initialPhotos,
    this.initialIndex = 0,
  });

  /// The photo to display
  final PhotoWaypoint photo;

  /// Session ID for context
  final String sessionId;

  /// Optional list of photos for swiping between them
  final List<PhotoWaypoint>? initialPhotos;

  /// Initial index in the photos list
  final int initialIndex;

  @override
  ConsumerState<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends ConsumerState<PhotoViewerPage>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _overlayController;
  late AnimationController _zoomController;

  List<PhotoWaypoint> _photos = <PhotoWaypoint>[];
  int _currentIndex = 0;
  bool _showOverlay = true;
  bool _showMetadata = false;

  // Zoom and pan state
  final TransformationController _transformationController =
      TransformationController();
  late Animation<Matrix4> _zoomAnimation;

  @override
  void initState() {
    super.initState();

    _photos = widget.initialPhotos ?? [widget.photo];
    _currentIndex = widget.initialIndex;

    _pageController = PageController(initialPage: _currentIndex);
    _overlayController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _zoomAnimation = Matrix4Tween(
      begin: Matrix4.identity(),
      end: Matrix4.identity(),
    ).animate(_zoomController);

    _overlayController.forward();

    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _overlayController.dispose();
    _zoomController.dispose();
    _transformationController.dispose();

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Photo viewer
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _photos.length,
              itemBuilder: (context, index) => _buildPhotoView(_photos[index]),
            ),

            // Top overlay
            AnimatedBuilder(
              animation: _overlayController,
              builder: (context, child) => Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Transform.translate(
                  offset: Offset(0, -100 * (1 - _overlayController.value)),
                  child: _buildTopOverlay(),
                ),
              ),
            ),

            // Bottom overlay
            AnimatedBuilder(
              animation: _overlayController,
              builder: (context, child) => Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Transform.translate(
                  offset: Offset(0, 100 * (1 - _overlayController.value)),
                  child: _buildBottomOverlay(),
                ),
              ),
            ),

            // Metadata overlay
            if (_showMetadata)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: _buildMetadataOverlay(),
              ),
          ],
        ),
      );

  Widget _buildPhotoView(PhotoWaypoint photo) => GestureDetector(
        onTap: _toggleOverlay,
        onDoubleTap: () => _handleDoubleTap(photo),
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Hero(
              tag: 'photo_${photo.id}',
              child: Image.file(
                File(photo.filePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 64,
                          color: Colors.white54,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildTopOverlay() {
    if (!_showOverlay) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateTime(_photos[_currentIndex].createdAt),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_photos.length > 1)
                      Text(
                        '${_currentIndex + 1} of ${_photos.length}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _toggleMetadata,
                icon: Icon(
                  _showMetadata ? Icons.info : Icons.info_outline,
                  color: Colors.white,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: _handleMenuAction,
                icon: const Icon(Icons.more_vert, color: Colors.white),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'favorite',
                    child: ListTile(
                      leading: Icon(Icons.favorite_border),
                      title: Text('Toggle Favorite'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      leading: Icon(Icons.share),
                      title: Text('Share'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete),
                      title: Text('Delete'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'details',
                    child: ListTile(
                      leading: Icon(Icons.info),
                      title: Text('Photo Details'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomOverlay() {
    if (!_showOverlay) return const SizedBox.shrink();

    final photo = _photos[_currentIndex];

    return DecoratedBox(
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
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Photo info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (photo.dimensionsFormatted != null)
                          Text(
                            photo.dimensionsFormatted!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        Text(
                          photo.fileSizeFormatted,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
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
                      color: _isFavorite() ? Colors.red : Colors.white,
                    ),
                  ),

                  IconButton(
                    onPressed: _sharePhoto,
                    icon: const Icon(Icons.share, color: Colors.white),
                  ),

                  IconButton(
                    onPressed: _showOnMap,
                    icon: const Icon(Icons.map, color: Colors.white),
                  ),
                ],
              ),

              // Thumbnail strip for multiple photos
              if (_photos.length > 1)
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length,
                    itemBuilder: (context, index) => _buildThumbnail(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(int index) {
    final photo = _photos[index];
    final isSelected = index == _currentIndex;

    return GestureDetector(
      onTap: () => _jumpToPhoto(index),
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Image.file(
            File(photo.thumbnailPath ?? photo.filePath),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[800],
              child: const Icon(
                Icons.photo,
                color: Colors.white54,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataOverlay() {
    final photo = _photos[_currentIndex];
    final photoState = ref.watch(photoProvider);
    final metadata = photoState.photoMetadata[photo.id] ?? <PhotoMetadata>[];

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Photo Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _toggleMetadata,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetadataSection('Basic Info', [
                        _MetadataItem(
                            'Created', _formatDateTime(photo.createdAt)),
                        _MetadataItem('File Size', photo.fileSizeFormatted),
                        if (photo.dimensionsFormatted != null)
                          _MetadataItem(
                              'Dimensions', photo.dimensionsFormatted!),
                      ]),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildMetadataSection(
                            'EXIF Data',
                            metadata
                                .where((m) => m.isExifData)
                                .map((m) => _MetadataItem(
                                    m.key.replaceAll('exif_', ''),
                                    m.displayValue))
                                .toList()),
                        const SizedBox(height: 16),
                        _buildMetadataSection(
                            'Location Data',
                            metadata
                                .where((m) => m.key.startsWith('location_'))
                                .map((m) => _MetadataItem(
                                    m.key.replaceAll('location_', ''),
                                    m.displayValue))
                                .toList()),
                        const SizedBox(height: 16),
                        _buildMetadataSection(
                            'Custom Data',
                            metadata
                                .where((m) => m.isCustomData)
                                .map((m) => _MetadataItem(
                                    m.key.replaceAll('custom_', ''),
                                    m.displayValue))
                                .toList()),
                      ],
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      item.key,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Reset zoom when changing photos
    _transformationController.value = Matrix4.identity();
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });

    if (_showOverlay) {
      _overlayController.forward();
    } else {
      _overlayController.reverse();
    }
  }

  void _toggleMetadata() {
    setState(() {
      _showMetadata = !_showMetadata;
    });
  }

  void _handleDoubleTap(PhotoWaypoint photo) {
    final Matrix4 currentTransform = _transformationController.value;
    final double currentScale = currentTransform.getMaxScaleOnAxis();

    Matrix4 targetTransform;
    if (currentScale > 1.5) {
      // Zoom out
      targetTransform = Matrix4.identity();
    } else {
      // Zoom in
      targetTransform = Matrix4.identity()
        ..scaleByDouble(2.0, 2.0, 1.0, 1.0);
    }

    _zoomAnimation = Matrix4Tween(
      begin: currentTransform,
      end: targetTransform,
    ).animate(CurvedAnimation(
      parent: _zoomController,
      curve: Curves.easeInOut,
    ));

    _zoomController.reset();
    _zoomController.forward().then((_) {
      _transformationController.value = targetTransform;
    });

    _zoomAnimation.addListener(() {
      _transformationController.value = _zoomAnimation.value;
    });
  }

  void _jumpToPhoto(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _isFavorite() {
    final photoState = ref.read(photoProvider);
    final metadata = photoState.photoMetadata[_photos[_currentIndex].id] ??
        <PhotoMetadata>[];
    return metadata.any(
        (meta) => meta.key == CustomKeys.favorite && meta.typedValue == true);
  }

  void _toggleFavorite() {
    final photoNotifier = ref.read(photoProvider.notifier);
    photoNotifier.toggleFavorite(_photos[_currentIndex]);
  }

  Future<void> _sharePhoto() async {
    try {
      final String photoPath = widget.photo.filePath;
      if (await File(photoPath).exists()) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(photoPath)],
            text: 'Photo from Obsession Tracker',
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo file not found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing photo: $e')),
      );
    }
  }

  void _showOnMap() {
    // Navigate to the map page and highlight the waypoint
    Navigator.of(context).pushNamed(
      '/map',
      arguments: {
        'sessionId': widget.sessionId,
        'highlightWaypointId': widget.photo.waypointId,
      },
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'favorite':
        _toggleFavorite();
        break;
      case 'share':
        _sharePhoto();
        break;
      case 'delete':
        _deletePhoto();
        break;
      case 'details':
        _toggleMetadata();
        break;
    }
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
              final photoNotifier = ref.read(photoProvider.notifier);
              final success =
                  await photoNotifier.deletePhoto(_photos[_currentIndex]);

              if (success && mounted) {
                if (_photos.length == 1) {
                  Navigator.of(context).pop();
                } else {
                  setState(() {
                    _photos.removeAt(_currentIndex);
                    if (_currentIndex >= _photos.length) {
                      _currentIndex = _photos.length - 1;
                    }
                  });
                  _pageController.animateToPage(
                    _currentIndex,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Photo deleted')),
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

  String _formatDateTime(DateTime dateTime) =>
      '${dateTime.day}/${dateTime.month}/${dateTime.year} '
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';
}

class _MetadataItem {
  const _MetadataItem(this.key, this.value);

  final String key;
  final String value;
}
