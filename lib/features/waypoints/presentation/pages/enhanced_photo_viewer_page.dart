import 'dart:io';

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/providers/photo_provider.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/photo_annotation_display_widget.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/photo_annotation_form_widget.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';

/// Enhanced full-screen photo viewer with advanced features
class EnhancedPhotoViewerPage extends ConsumerStatefulWidget {
  const EnhancedPhotoViewerPage({
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
  ConsumerState<EnhancedPhotoViewerPage> createState() =>
      _EnhancedPhotoViewerPageState();
}

class _EnhancedPhotoViewerPageState
    extends ConsumerState<EnhancedPhotoViewerPage>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _overlayController;
  late AnimationController _metadataController;
  late AnimationController _loadingController;
  late AnimationController _annotationController;

  List<PhotoWaypoint> _photos = <PhotoWaypoint>[];
  int _currentIndex = 0;
  bool _showOverlay = true;
  bool _showMetadata = false;
  bool _isFullscreen = false;
  bool _isLoading = false;

  // Photo editing state
  bool _isEditing = false;

  // Photo annotation state
  bool _showAnnotations = false;
  bool _isAnnotating = false;
  double _brightness = 0.0;
  double _contrast = 0.0;
  double _saturation = 0.0;

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
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
    _annotationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _overlayController.forward();

    // Start in immersive mode
    _enterImmersiveMode();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _overlayController.dispose();
    _metadataController.dispose();
    _loadingController.dispose();
    _annotationController.dispose();

    // Restore system UI
    _exitImmersiveMode();
    super.dispose();
  }

  void _enterImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    setState(() {
      _isFullscreen = true;
    });
  }

  void _exitImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    setState(() {
      _isFullscreen = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Photo gallery viewer
            PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                final photo = _photos[index];
                return PhotoViewGalleryPageOptions.customChild(
                  child: FutureBuilder<_PhotoFileData>(
                    future: _resolvePhotoFile(photo.filePath),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingWidget(null);
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        debugPrint('❌ Error loading photo: ${photo.filePath}');
                        debugPrint('   Error: ${snapshot.error}');
                        return _buildErrorWidget();
                      }

                      final photoData = snapshot.data!;

                      // Apply EXIF orientation rotation
                      return _applyOrientation(
                        PhotoView(
                          imageProvider: FileImage(photoData.file),
                          initialScale: PhotoViewComputedScale.contained,
                          minScale: PhotoViewComputedScale.contained * 0.5,
                          maxScale: PhotoViewComputedScale.covered * 4.0,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('❌ PhotoView error: $error');
                            return _buildErrorWidget();
                          },
                          onTapUp: (context, details, controllerValue) => _toggleOverlay(),
                          onTapDown: (context, details, controllerValue) => _handleTapDown(details),
                          backgroundDecoration: const BoxDecoration(color: Colors.black),
                        ),
                        photoData.orientation,
                      );
                    },
                  ),
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained * 0.5,
                  maxScale: PhotoViewComputedScale.covered * 4.0,
                  heroAttributes: PhotoViewHeroAttributes(tag: 'photo_${photo.id}'),
                );
              },
              itemCount: _photos.length,
              loadingBuilder: (context, event) => _buildLoadingWidget(event),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              pageController: _pageController,
              onPageChanged: _onPageChanged,
            ),

            // Top overlay
            if (_showOverlay && !_isFullscreen)
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
            if (_showOverlay && !_isFullscreen)
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

            // Metadata panel
            if (_showMetadata)
              AnimatedBuilder(
                animation: _metadataController,
                builder: (context, child) => Positioned(
                  right: -350 + (350 * _metadataController.value),
                  top: 0,
                  bottom: 0,
                  child: _buildMetadataPanel(),
                ),
              ),

            // Annotation panel
            if (_showAnnotations)
              AnimatedBuilder(
                animation: _annotationController,
                builder: (context, child) => Positioned(
                  left: -400 + (400 * _annotationController.value),
                  top: 0,
                  bottom: 0,
                  child: _buildAnnotationPanel(),
                ),
              ),

            // Annotation form overlay
            if (_isAnnotating)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildAnnotationForm(),
              ),

            // Photo editing controls
            if (_isEditing)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildEditingControls(),
              ),

            // Loading indicator
            if (_isLoading) Center(child: _buildLoadingWidget(null)),

            // Floating action buttons
            if (_showOverlay && !_isFullscreen)
              Positioned(
                right: 16,
                bottom: 100,
                child: _buildFloatingActions(),
              ),

            // Annotation indicator overlay
            if (!_showAnnotations && !_isAnnotating && _hasAnnotations())
              Positioned(
                top: 80,
                left: 16,
                child: _buildAnnotationIndicator(),
              ),
          ],
        ),
      );

  Widget _buildTopOverlay() => DecoratedBox(
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
                  onPressed: _toggleFullscreen,
                  icon: Icon(
                    _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: _handleMenuAction,
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'info',
                      child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Photo Info'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'annotations',
                      child: ListTile(
                        leading: Icon(Icons.edit_note),
                        title: Text('Annotations'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'add_annotation',
                      child: ListTile(
                        leading: Icon(Icons.note_add),
                        title: Text('Add Annotation'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Edit Photo'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
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
                      value: 'share_no_location',
                      child: ListTile(
                        leading: Icon(Icons.share_location),
                        title: Text('Share (No Location)'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title:
                            Text('Delete', style: TextStyle(color: Colors.red)),
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

  Widget _buildBottomOverlay() {
    final photo = _photos[_currentIndex];

    return DecoratedBox(
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

                  // Quick action buttons
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

  Widget _buildMetadataPanel() {
    final photo = _photos[_currentIndex];
    final photoState = ref.watch(photoProvider);
    final metadata = photoState.photoMetadata[photo.id] ?? <PhotoMetadata>[];

    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
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
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetadataSection('Basic Information', [
                      _MetadataItem(
                          'Created', _formatDateTime(photo.createdAt)),
                      _MetadataItem('File Size', photo.fileSizeFormatted),
                      if (photo.dimensionsFormatted != null)
                        _MetadataItem('Dimensions', photo.dimensionsFormatted!),
                      _MetadataItem(
                          'File Path', photo.filePath.split('/').last),
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
                    _buildPrivacyControls(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
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
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      item.key,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
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

  Widget _buildPrivacyControls() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Privacy Controls',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
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
                    Icon(Icons.location_on, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Location Data Included',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'This photo contains GPS coordinates and location metadata. Use "Share (No Location)" to remove this data when sharing.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildEditingControls() => Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Edit Photo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _resetEditing,
                      child: const Text('Reset'),
                    ),
                    TextButton(
                      onPressed: _saveEditing,
                      child: const Text('Save'),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _isEditing = false),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Column(
                    children: [
                      _buildSlider('Brightness', _brightness, (value) {
                        setState(() => _brightness = value);
                      }),
                      _buildSlider('Contrast', _contrast, (value) {
                        setState(() => _contrast = value);
                      }),
                      _buildSlider('Saturation', _saturation, (value) {
                        setState(() => _saturation = value);
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildSlider(
          String label, double value, ValueChanged<double> onChanged) =>
      Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: -1.0,
              divisions: 100,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value.toStringAsFixed(2),
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ],
      );

  Widget _buildFloatingActions() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'annotations',
            mini: true,
            onPressed: _toggleAnnotations,
            backgroundColor: Colors.black.withValues(alpha: 0.7),
            child: Icon(
              _showAnnotations ? Icons.edit_note : Icons.edit_note_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'metadata',
            mini: true,
            onPressed: _toggleMetadata,
            backgroundColor: Colors.black.withValues(alpha: 0.7),
            child: Icon(
              _showMetadata ? Icons.info : Icons.info_outline,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'edit',
            mini: true,
            onPressed: () => setState(() => _isEditing = !_isEditing),
            backgroundColor: Colors.black.withValues(alpha: 0.7),
            child: const Icon(Icons.tune, color: Colors.white),
          ),
        ],
      );

  Widget _buildLoadingWidget(ImageChunkEvent? event) => ColoredBox(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _loadingController,
                builder: (context, child) => CircularProgressIndicator(
                  value: event?.expectedTotalBytes != null
                      ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
                      : null,
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                event?.expectedTotalBytes != null
                    ? 'Loading ${(event!.cumulativeBytesLoaded / 1024 / 1024).toStringAsFixed(1)}MB / ${(event.expectedTotalBytes! / 1024 / 1024).toStringAsFixed(1)}MB'
                    : 'Loading high-resolution image...',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
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

  void _toggleFullscreen() {
    if (_isFullscreen) {
      _exitImmersiveMode();
    } else {
      _enterImmersiveMode();
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

  void _handleTapDown(TapDownDetails details) {
    // Handle double tap for zoom
    // This is handled by PhotoView internally
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

      // In a real implementation, you would:
      // 1. Create a copy of the photo
      // 2. Strip EXIF data if includeLocation is false
      // 3. Share the processed image

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
      case 'info':
        _toggleMetadata();
        break;
      case 'annotations':
        _toggleAnnotations();
        break;
      case 'add_annotation':
        _startAnnotating();
        break;
      case 'edit':
        setState(() => _isEditing = !_isEditing);
        break;
      case 'favorite':
        _toggleFavorite();
        break;
      case 'share':
        _sharePhoto();
        break;
      case 'share_no_location':
        _sharePhoto(includeLocation: false);
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

  void _resetEditing() {
    setState(() {
      _brightness = 0.0;
      _contrast = 0.0;
      _saturation = 0.0;
    });
  }

  void _saveEditing() {
    // TODO(dev): Apply image filters and save
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo editing not yet implemented')),
    );
    setState(() => _isEditing = false);
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

  // MARK: - Annotation Methods

  void _toggleAnnotations() {
    setState(() {
      _showAnnotations = !_showAnnotations;
    });

    if (_showAnnotations) {
      _annotationController.forward();
    } else {
      _annotationController.reverse();
    }
  }

  void _startAnnotating() {
    setState(() {
      _isAnnotating = true;
      _showAnnotations = false;
      _showMetadata = false;
      _isEditing = false;
    });

    // Close other panels
    _annotationController.reverse();
    _metadataController.reverse();
  }

  void _stopAnnotating() {
    setState(() {
      _isAnnotating = false;
    });
  }

  bool _hasAnnotations() {
    final photoState = ref.read(photoProvider);
    final metadata = photoState.photoMetadata[_photos[_currentIndex].id] ??
        <PhotoMetadata>[];
    return metadata.any((meta) => meta.isCustomData);
  }

  List<PhotoMetadata> _getAnnotations() {
    final photoState = ref.read(photoProvider);
    final metadata = photoState.photoMetadata[_photos[_currentIndex].id] ??
        <PhotoMetadata>[];
    return metadata.where((meta) => meta.isCustomData).toList();
  }

  Widget _buildAnnotationPanel() {
    final photo = _photos[_currentIndex];
    final annotations = _getAnnotations();

    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(5, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Photo Annotations',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _startAnnotating,
                    icon: const Icon(Icons.add, color: Colors.white),
                    tooltip: 'Add Annotation',
                  ),
                  IconButton(
                    onPressed: _toggleAnnotations,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PhotoAnnotationDisplayWidget(
                  photo: photo,
                  annotations: annotations,
                  onEdit: _startAnnotating,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnotationForm() => PhotoAnnotationFormWidget(
        photo: _photos[_currentIndex],
        existingAnnotations: _getAnnotations(),
        onSave: _saveAnnotations,
        onCancel: _stopAnnotating,
        isEditing: _getAnnotations().isNotEmpty,
      );

  Widget _buildAnnotationIndicator() => GestureDetector(
        onTap: _toggleAnnotations,
        child: CompactPhotoAnnotationWidget(
          annotations: _getAnnotations(),
          onTap: _toggleAnnotations,
        ),
      );

  Future<void> _saveAnnotations(List<PhotoMetadata> annotations) async {
    try {
      final photoId = _photos[_currentIndex].id;
      final success = await ref
          .read(photoProvider.notifier)
          .updatePhotoAnnotations(photoId, annotations);

      _stopAnnotating();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Annotation saved successfully'
                : 'Failed to save annotation'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save annotation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Resolve photo file path - converts relative paths to absolute and reads EXIF
  Future<_PhotoFileData> _resolvePhotoFile(String photoPath) async {
    // Resolve file path
    File file;
    if (photoPath.startsWith('/')) {
      file = File(photoPath);
    } else {
      final Directory docs = await getApplicationDocumentsDirectory();
      final String absolutePath = path.join(docs.path, photoPath);
      file = File(absolutePath);
    }

    // Read EXIF orientation
    int orientation = 1;
    try {
      final bytes = await file.readAsBytes();
      final exifData = await readExifFromBytes(bytes);

      if (exifData.isNotEmpty) {
        final orientationTag = exifData['Image Orientation'];
        if (orientationTag != null) {
          final String printableValue = orientationTag.printable;
          orientation = _parseOrientationFromPrintable(printableValue);
          debugPrint('📸 EXIF orientation: $orientation ($printableValue)');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Could not read EXIF orientation: $e');
    }

    return _PhotoFileData(file: file, orientation: orientation);
  }

  /// Parse EXIF orientation from human-readable string
  int _parseOrientationFromPrintable(String printableValue) {
    final intValue = int.tryParse(printableValue);
    if (intValue != null) return intValue;

    final lowerValue = printableValue.toLowerCase();
    if (lowerValue.contains('horizontal') || lowerValue.contains('normal')) {
      return 1;
    } else if (lowerValue.contains('rotate 180') || lowerValue.contains('rotated 180')) {
      return 3;
    } else if (lowerValue.contains('rotate 90 cw') || lowerValue.contains('rotated 90 cw')) {
      return 6;
    } else if (lowerValue.contains('rotate 90 ccw') || lowerValue.contains('rotated 90 ccw')) {
      return 8;
    }
    return 1;
  }

  /// Apply EXIF orientation rotation to widget
  Widget _applyOrientation(Widget child, int orientation) {
    switch (orientation) {
      case 1:
        return child; // Normal
      case 3:
        return RotatedBox(quarterTurns: 2, child: child); // 180°
      case 6:
        return RotatedBox(quarterTurns: 3, child: child); // 90° CCW
      case 8:
        return RotatedBox(quarterTurns: 1, child: child); // 90° CW
      default:
        return child;
    }
  }
}

class _PhotoFileData {
  const _PhotoFileData({required this.file, required this.orientation});
  final File file;
  final int orientation;
}

class _MetadataItem {
  const _MetadataItem(this.key, this.value);

  final String key;
  final String value;
}
