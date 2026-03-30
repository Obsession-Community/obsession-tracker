import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/providers/photo_provider.dart';
import 'package:obsession_tracker/features/waypoints/presentation/pages/photo_viewer_page.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/photo_gallery_widget.dart';
import 'package:share_plus/share_plus.dart';

/// Full-screen photo gallery page with navigation and controls
class PhotoGalleryPage extends ConsumerStatefulWidget {
  const PhotoGalleryPage({
    required this.sessionId,
    super.key,
    this.sessionName,
  });

  /// Session ID to display photos for
  final String sessionId;

  /// Optional session name for display
  final String? sessionName;

  @override
  ConsumerState<PhotoGalleryPage> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends ConsumerState<PhotoGalleryPage> {
  bool _isSelectionMode = false;
  Set<String> _selectedPhotos = <String>{};

  @override
  Widget build(BuildContext context) {
    final photoState = ref.watch(photoProvider);
    final photoNotifier = ref.read(photoProvider.notifier);

    return Scaffold(
      appBar: _buildAppBar(context, photoState, photoNotifier),
      body: PhotoGalleryWidget(
        sessionId: widget.sessionId,
        enableSelection: _isSelectionMode,
        selectedPhotos: _selectedPhotos,
        onSelectionChanged: _handleSelectionChanged,
        onPhotoTap: _handlePhotoTap,
        onPhotoLongPress: _handlePhotoLongPress,
      ),
      floatingActionButton: _buildFloatingActionButton(context),
      bottomNavigationBar: _isSelectionMode
          ? _buildSelectionBottomBar(context, photoNotifier)
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    PhotoState photoState,
    PhotoNotifier photoNotifier,
  ) {
    if (_isSelectionMode) {
      return AppBar(
        title: Text('${_selectedPhotos.length} selected'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectionMode,
        ),
        actions: [
          if (_selectedPhotos.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.favorite_border),
              onPressed: _toggleSelectedFavorites,
              tooltip: 'Toggle Favorites',
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareSelectedPhotos,
              tooltip: 'Share',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteSelectedPhotos(context, photoNotifier),
              tooltip: 'Delete',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: _selectAllPhotos,
            tooltip: 'Select All',
          ),
        ],
      );
    }

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Photo Gallery'),
          if (widget.sessionName != null)
            Text(
              widget.sessionName!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      actions: [
        // View mode toggle
        IconButton(
          icon: const Icon(Icons.view_module),
          onPressed: () => _showViewOptionsBottomSheet(context),
          tooltip: 'View Options',
        ),

        // Selection mode toggle
        IconButton(
          icon: const Icon(Icons.checklist),
          onPressed: _enterSelectionMode,
          tooltip: 'Select Photos',
        ),

        // More options
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value, photoNotifier),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: ListTile(
                leading: Icon(Icons.refresh),
                title: Text('Refresh'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'clear_cache',
              child: ListTile(
                leading: Icon(Icons.clear_all),
                title: Text('Clear Cache'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'storage_info',
              child: ListTile(
                leading: Icon(Icons.storage),
                title: Text('Storage Info'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    if (_isSelectionMode) return null;

    // Photo capture removed from gallery - users should capture photos during tracking
    // This reduces confusion about context and consolidates photo capture workflow
    return null;
  }

  Widget _buildSelectionBottomBar(
    BuildContext context,
    PhotoNotifier photoNotifier,
  ) =>
      BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed:
                    _selectedPhotos.isEmpty ? null : _toggleSelectedFavorites,
                icon: const Icon(Icons.favorite),
                label: const Text('Favorite'),
              ),
              TextButton.icon(
                onPressed:
                    _selectedPhotos.isEmpty ? null : _shareSelectedPhotos,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
              TextButton.icon(
                onPressed: _selectedPhotos.isEmpty
                    ? null
                    : () => _deleteSelectedPhotos(context, photoNotifier),
                icon: const Icon(Icons.delete),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      );

  void _handlePhotoTap(PhotoWaypoint photo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PhotoViewerPage(
          photo: photo,
          sessionId: widget.sessionId,
        ),
      ),
    );
  }

  void _handlePhotoLongPress(PhotoWaypoint photo) {
    if (!_isSelectionMode) {
      _enterSelectionMode();
      _handleSelectionChanged({photo.id});
    }
  }

  void _handleSelectionChanged(Set<String> selectedPhotos) {
    setState(() {
      _selectedPhotos = selectedPhotos;
    });
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedPhotos = <String>{};
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPhotos = <String>{};
    });
  }

  void _selectAllPhotos() {
    final photoState = ref.read(photoProvider);
    setState(() {
      _selectedPhotos =
          photoState.filteredPhotos.map((photo) => photo.id).toSet();
    });
  }

  void _toggleSelectedFavorites() {
    final photoNotifier = ref.read(photoProvider.notifier);
    final photoState = ref.read(photoProvider);

    for (final photoId in _selectedPhotos) {
      final photo =
          photoState.filteredPhotos.firstWhere((p) => p.id == photoId);
      photoNotifier.toggleFavorite(photo);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Updated ${_selectedPhotos.length} photo(s)'),
      ),
    );
  }

  Future<void> _shareSelectedPhotos() async {
    try {
      final photoState = ref.read(photoProvider);
      final selectedPhotos = photoState.photos
          .where((photo) => _selectedPhotos.contains(photo.id))
          .toList();
      
      if (selectedPhotos.isEmpty) return;

      final List<XFile> filesToShare = [];
      for (final photo in selectedPhotos) {
        if (await File(photo.filePath).exists()) {
          filesToShare.add(XFile(photo.filePath));
        }
      }

      if (filesToShare.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            files: filesToShare,
            text: 'Photos from Obsession Tracker${selectedPhotos.length > 1 ? ' (${selectedPhotos.length} photos)' : ''}',
          ),
        );
        // Clear selection after sharing
        _selectedPhotos.clear();
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid photo files found to share')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing photos: $e')),
      );
    }
  }

  void _deleteSelectedPhotos(
      BuildContext context, PhotoNotifier photoNotifier) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photos'),
        content: Text(
          'Are you sure you want to delete ${_selectedPhotos.length} photo(s)? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performDelete(photoNotifier);
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

  Future<void> _performDelete(PhotoNotifier photoNotifier) async {
    final photoState = ref.read(photoProvider);
    final photosToDelete = photoState.filteredPhotos
        .where((photo) => _selectedPhotos.contains(photo.id))
        .toList();

    int deletedCount = 0;
    for (final photo in photosToDelete) {
      final success = await photoNotifier.deletePhoto(photo);
      if (success) deletedCount++;
    }

    _exitSelectionMode();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Deleted $deletedCount of ${photosToDelete.length} photo(s)'),
          backgroundColor: deletedCount == photosToDelete.length
              ? null
              : Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showViewOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'View Options',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Grid size options
            Text(
              'Grid Size',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGridSizeOption(context, 2, 'Small'),
                _buildGridSizeOption(context, 3, 'Medium'),
                _buildGridSizeOption(context, 4, 'Large'),
              ],
            ),

            const SizedBox(height: 16),

            // Display options
            SwitchListTile(
              title: const Text('Show Metadata'),
              subtitle: const Text('Display date and size on photos'),
              value: true, // TODO(dev): Make this configurable
              onChanged: (value) {
                // TODO(dev): Implement metadata toggle
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGridSizeOption(
          BuildContext context, int columns, String label) =>
      Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: columns * columns,
              itemBuilder: (context, index) => Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );

  void _handleMenuAction(String action, PhotoNotifier photoNotifier) {
    switch (action) {
      case 'refresh':
        photoNotifier.refreshPhotos(widget.sessionId);
        break;
      case 'clear_cache':
        photoNotifier.clearCache();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared')),
        );
        break;
      case 'storage_info':
        _showStorageInfo(context);
        break;
    }
  }

  void _showStorageInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Information'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Storage details will be implemented with photo storage service integration.'),
            SizedBox(height: 16),
            Text('Features to include:'),
            Text('• Total photos count'),
            Text('• Storage space used'),
            Text('• Cache size'),
            Text('• Cleanup options'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
