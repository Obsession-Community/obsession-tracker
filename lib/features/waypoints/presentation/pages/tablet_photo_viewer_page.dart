import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/providers/photo_provider.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';

/// Tablet-optimized full-screen photo viewer with enhanced features
class TabletPhotoViewerPage extends ConsumerStatefulWidget {
  const TabletPhotoViewerPage({
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
  ConsumerState<TabletPhotoViewerPage> createState() =>
      _TabletPhotoViewerPageState();
}

class _TabletPhotoViewerPageState extends ConsumerState<TabletPhotoViewerPage>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _overlayController;
  late AnimationController _metadataController;

  List<PhotoWaypoint> _photos = <PhotoWaypoint>[];
  int _currentIndex = 0;
  bool _showOverlay = true;
  bool _showMetadata = false;
  bool _isLoading = false;

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
    _metadataController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _overlayController.forward();

    // Start in immersive mode for tablets
    _enterImmersiveMode();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _overlayController.dispose();
    _metadataController.dispose();

    // Restore system UI
    _exitImmersiveMode();
    super.dispose();
  }

  void _enterImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  void _exitImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Photo gallery viewer
            _buildPhotoGallery(),

            // Top overlay with navigation and controls
            if (_showOverlay) _buildTopOverlay(),

            // Bottom overlay with photo info and actions
            if (_showOverlay) _buildBottomOverlay(),

            // Side metadata panel
            if (_showMetadata) _buildMetadataPanel(),

            // Loading indicator
            if (_isLoading) _buildLoadingOverlay(),
          ],
        ),
      );

  Widget _buildPhotoGallery() => PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          final photo = _photos[index];
          return PhotoViewGalleryPageOptions(
            imageProvider: FileImage(File(photo.filePath)),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained * 0.3,
            maxScale: PhotoViewComputedScale.covered * 5.0,
            heroAttributes: PhotoViewHeroAttributes(tag: 'photo_${photo.id}'),
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
            onTapUp: (context, details, controllerValue) => _toggleOverlay(),
          );
        },
        itemCount: _photos.length,
        loadingBuilder: (context, event) => _buildPhotoLoadingWidget(event),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        pageController: _pageController,
        onPageChanged: _onPageChanged,
      );

  Widget _buildTopOverlay() => AnimatedBuilder(
        animation: _overlayController,
        builder: (context, child) => Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Transform.translate(
            offset: Offset(0, -100 * (1 - _overlayController.value)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(context.isTablet ? 24 : 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        iconSize: context.isTablet ? 28 : 24,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDateTime(_photos[_currentIndex].createdAt),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: context.isTablet ? 20 : 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_photos.length > 1)
                              Text(
                                '${_currentIndex + 1} of ${_photos.length}',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: context.isTablet ? 16 : 14,
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
                        tooltip: 'Photo Info',
                      ),
                      PopupMenuButton<String>(
                        onSelected: _handleMenuAction,
                        icon: const Icon(Icons.more_vert, color: Colors.white),
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
                              title: Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildBottomOverlay() {
    final photo = _photos[_currentIndex];

    return AnimatedBuilder(
      animation: _overlayController,
      builder: (context, child) => Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Transform.translate(
          offset: Offset(0, 100 * (1 - _overlayController.value)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(context.isTablet ? 24 : 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Photo info and quick actions
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (photo.dimensionsFormatted != null)
                                Text(
                                  photo.dimensionsFormatted!,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: context.isTablet ? 16 : 14,
                                  ),
                                ),
                              Text(
                                photo.fileSizeFormatted,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: context.isTablet ? 14 : 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Quick action buttons
                        IconButton(
                          onPressed: _toggleFavorite,
                          icon: Icon(
                            _isFavorite()
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _isFavorite() ? Colors.red : Colors.white,
                            size: context.isTablet ? 28 : 24,
                          ),
                          tooltip: 'Toggle Favorite',
                        ),

                        IconButton(
                          onPressed: _sharePhoto,
                          icon: Icon(
                            Icons.share,
                            color: Colors.white,
                            size: context.isTablet ? 28 : 24,
                          ),
                          tooltip: 'Share',
                        ),

                        IconButton(
                          onPressed: _showOnMap,
                          icon: Icon(
                            Icons.map,
                            color: Colors.white,
                            size: context.isTablet ? 28 : 24,
                          ),
                          tooltip: 'Show on Map',
                        ),
                      ],
                    ),

                    // Enhanced thumbnail strip for tablets
                    if (_photos.length > 1)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        height: context.isTablet ? 80 : 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photos.length,
                          itemBuilder: (context, index) =>
                              _buildThumbnail(index),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(int index) {
    final photo = _photos[index];
    final isSelected = index == _currentIndex;
    final size = context.isTablet ? 80.0 : 60.0;

    return GestureDetector(
      onTap: () => _jumpToPhoto(index),
      child: Container(
        width: size,
        height: size,
        margin: EdgeInsets.only(right: context.isTablet ? 12 : 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: context.isTablet ? 3 : 2,
          ),
          borderRadius: BorderRadius.circular(context.isTablet ? 8 : 4),
          boxShadow: isSelected && context.isTablet
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.isTablet ? 6 : 2),
          child: Stack(
            children: [
              Image.file(
                File(photo.thumbnailPath ?? photo.filePath),
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[800],
                  child: Icon(
                    Icons.photo,
                    color: Colors.white54,
                    size: context.isTablet ? 32 : 24,
                  ),
                ),
              ),

              // Photo index indicator for tablets
              if (context.isTablet)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataPanel() {
    final photo = _photos[_currentIndex];
    final photoState = ref.watch(photoProvider);
    final metadata = photoState.photoMetadata[photo.id] ?? <PhotoMetadata>[];

    return AnimatedBuilder(
      animation: _metadataController,
      builder: (context, child) => Positioned(
        right: -400 + (400 * _metadataController.value),
        top: 0,
        bottom: 0,
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(-5, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Photo Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
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
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetadataSection('Basic Information', [
                          _MetadataItem(
                              'Created', _formatDateTime(photo.createdAt)),
                          _MetadataItem('File Size', photo.fileSizeFormatted),
                          if (photo.dimensionsFormatted != null)
                            _MetadataItem(
                                'Dimensions', photo.dimensionsFormatted!),
                          _MetadataItem(
                              'File Name', photo.filePath.split('/').last),
                        ]),
                        if (metadata.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          _buildMetadataSection(
                            'Location Data',
                            metadata
                                .where((m) => m.key.startsWith('location_'))
                                .map((m) => _MetadataItem(
                                    _formatMetadataKey(m.key), m.displayValue))
                                .toList(),
                          ),
                          const SizedBox(height: 32),
                          _buildMetadataSection(
                            'Camera Settings',
                            metadata
                                .where((m) => m.isExifData)
                                .map((m) => _MetadataItem(
                                    _formatMetadataKey(m.key), m.displayValue))
                                .toList(),
                          ),
                          const SizedBox(height: 32),
                          _buildMetadataSection(
                            'Custom Data',
                            metadata
                                .where((m) => m.isCustomData)
                                .map((m) => _MetadataItem(
                                    _formatMetadataKey(m.key), m.displayValue))
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 32),
                        _buildPrivacyControls(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      item.key,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      item.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildPrivacyControls() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Privacy Controls',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Location Data Included',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'This photo contains GPS coordinates and location metadata. Use "Share (No Location)" to remove this data when sharing.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildLoadingOverlay() => ColoredBox(
        color: Colors.black.withValues(alpha: 0.5),
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );

  Widget _buildErrorWidget() => Container(
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
      );

  Widget _buildPhotoLoadingWidget(ImageChunkEvent? event) => ColoredBox(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                value: event?.expectedTotalBytes != null
                    ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
                    : null,
                strokeWidth: 3,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                event?.expectedTotalBytes != null
                    ? 'Loading ${(event!.cumulativeBytesLoaded / 1024 / 1024).toStringAsFixed(1)}MB / ${(event.expectedTotalBytes! / 1024 / 1024).toStringAsFixed(1)}MB'
                    : 'Loading high-resolution image...',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
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

    if (_showMetadata) {
      _metadataController.forward();
    } else {
      _metadataController.reverse();
    }
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

  Future<void> _sharePhoto({bool includeLocation = true}) async {
    final photo = _photos[_currentIndex];

    try {
      setState(() => _isLoading = true);

      await SharePlus.instance.share(
        ShareParams(
          text: includeLocation
              ? 'Photo taken at ${_formatDateTime(photo.createdAt)}'
              : 'Photo (location data removed)',
          files: [XFile(photo.filePath)],
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
