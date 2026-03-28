import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/providers/photo_provider.dart';
import 'package:obsession_tracker/core/services/photo_capture_service.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:obsession_tracker/core/widgets/adaptive_layout.dart';
import 'package:obsession_tracker/features/waypoints/presentation/pages/adaptive_camera_preview_page.dart';
import 'package:obsession_tracker/features/waypoints/presentation/pages/enhanced_photo_viewer_page.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/enhanced_photo_gallery_widget.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/tablet_photo_viewer_widget.dart';

/// Adaptive photo gallery page that provides optimal experience across all screen sizes
class AdaptivePhotoGalleryPage extends ConsumerStatefulWidget {
  const AdaptivePhotoGalleryPage({
    required this.sessionId,
    required this.sessionName,
    super.key,
  });

  final String sessionId;
  final String sessionName;

  @override
  ConsumerState<AdaptivePhotoGalleryPage> createState() =>
      _AdaptivePhotoGalleryPageState();
}

class _AdaptivePhotoGalleryPageState
    extends ConsumerState<AdaptivePhotoGalleryPage> {
  PhotoWaypoint? _selectedPhoto;

  @override
  void initState() {
    super.initState();
    // Load photos when page initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(photoProvider.notifier).loadPhotosForSession(widget.sessionId);
    });
  }

  @override
  Widget build(BuildContext context) => AdaptiveLayout(
        phone: _buildPhoneLayout(),
        tablet: _buildTabletLayout(),
        desktop: _buildDesktopLayout(),
      );

  /// Phone layout - traditional single-panel gallery
  Widget _buildPhoneLayout() => Scaffold(
        appBar: AppBar(
          title: Text(widget.sessionName),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _showFilterOptions,
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filter Photos',
            ),
            IconButton(
              onPressed: _showSortOptions,
              icon: const Icon(Icons.sort),
              tooltip: 'Sort Photos',
            ),
          ],
        ),
        body: EnhancedPhotoGalleryWidget(
          sessionId: widget.sessionId,
          crossAxisCount: context.photoGalleryColumns,
          onPhotoTap: _handlePhotoTap,
        ),
        floatingActionButton: _buildFloatingActionButton(),
      );

  /// Tablet layout - master-detail with adaptive behavior
  Widget _buildTabletLayout() => MasterDetailLayout(
        masterTitle: widget.sessionName,
        detailTitle: _selectedPhoto != null ? 'Photo Details' : null,
        masterBuilder: (context, {required bool isSelected}) =>
            _buildMasterPanel(),
        detailBuilder: (context) => _buildDetailPanel(),
        floatingActionButton: _buildFloatingActionButton(),
        showMasterInPortrait: true,
      );

  /// Desktop layout - enhanced master-detail with more features
  Widget _buildDesktopLayout() =>
      _buildTabletLayout(); // Same as tablet for now, can be enhanced later

  /// Master panel containing the photo grid
  Widget _buildMasterPanel() => Column(
        children: [
          // Filter and sort controls for tablets
          if (context.isTablet) _buildTabletControls(),

          // Photo grid
          Expanded(
            child: EnhancedPhotoGalleryWidget(
              sessionId: widget.sessionId,
              crossAxisCount: _getTabletGridColumns(),
              onPhotoTap: _handleMasterDetailPhotoTap,
            ),
          ),
        ],
      );

  /// Detail panel showing selected photo
  Widget _buildDetailPanel() {
    if (_selectedPhoto == null) {
      return _buildEmptyDetailPanel();
    }

    return TabletPhotoViewerWidget(
      photo: _selectedPhoto!,
      sessionId: widget.sessionId,
      onPhotoChanged: _handleDetailPhotoChanged,
      onClose: () => setState(() {
        _selectedPhoto = null;
      }),
    );
  }

  /// Empty state for detail panel
  Widget _buildEmptyDetailPanel() => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 24),
              Text(
                'Select a photo to view',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose any photo from the gallery to see it in detail',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  /// Tablet-specific controls for filtering and sorting
  Widget _buildTabletControls() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              child: Consumer(
                builder: (context, ref, child) {
                  final photoState = ref.watch(photoProvider);
                  final totalPhotos = photoState.photos.length;
                  final filteredPhotos = photoState.filteredPhotos.length;

                  return Text(
                    filteredPhotos == totalPhotos
                        ? '$totalPhotos photos'
                        : '$filteredPhotos of $totalPhotos photos',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                },
              ),
            ),

            // View mode toggle
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 3,
                  icon: Icon(Icons.grid_view, size: 16),
                  label: Text('Grid'),
                ),
                ButtonSegment(
                  value: 2,
                  icon: Icon(Icons.view_list, size: 16),
                  label: Text('List'),
                ),
              ],
              selected: {_getTabletGridColumns()},
              onSelectionChanged: (Set<int> selection) {
                // Handle view mode change
              },
            ),

            const SizedBox(width: 8),

            // Filter button
            IconButton(
              onPressed: _showFilterOptions,
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filter Photos',
            ),

            // Sort button
            IconButton(
              onPressed: _showSortOptions,
              icon: const Icon(Icons.sort),
              tooltip: 'Sort Photos',
            ),
          ],
        ),
      );

  /// Floating action button for photo capture
  Widget _buildFloatingActionButton() => FloatingActionButton(
        onPressed: _capturePhoto,
        tooltip: 'Take Photo',
        child: const Icon(Icons.camera_alt),
      );

  /// Handle photo tap for phone layout
  void _handlePhotoTap(
      PhotoWaypoint photo, List<PhotoWaypoint> allPhotos, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => EnhancedPhotoViewerPage(
          photo: photo,
          sessionId: widget.sessionId,
          initialPhotos: allPhotos,
          initialIndex: index,
        ),
      ),
    );
  }

  /// Handle photo tap for master-detail layout
  void _handleMasterDetailPhotoTap(
      PhotoWaypoint photo, List<PhotoWaypoint> allPhotos, int index) {
    setState(() {
      _selectedPhoto = photo;
    });
  }

  /// Handle photo change in detail panel
  void _handleDetailPhotoChanged(PhotoWaypoint photo, int index) {
    setState(() {
      _selectedPhoto = photo;
    });
  }

  /// Get appropriate grid column count for tablets
  int _getTabletGridColumns() {
    if (context.isLandscape) {
      return context.isIPad ? 6 : 5;
    } else {
      return context.isIPad ? 4 : 3;
    }
  }

  /// Show filter options
  void _showFilterOptions() {
    showAdaptiveBottomSheet<void>(
      context: context,
      child: _buildFilterSheet(),
      height: 400,
    );
  }

  /// Show sort options
  void _showSortOptions() {
    showAdaptiveBottomSheet<void>(
      context: context,
      child: _buildSortSheet(),
      height: 300,
    );
  }

  /// Build filter options sheet
  Widget _buildFilterSheet() => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filter Photos',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),

            // Date range filter
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Date Range'),
              subtitle: const Text('Filter by date taken'),
              onTap: () {
                Navigator.pop(context);
                _showDateRangePicker();
              },
            ),

            // Favorites filter
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Favorites Only'),
              subtitle: const Text('Show only favorite photos'),
              onTap: () {
                Navigator.pop(context);
                // TODO(dev): Implement favorites filter
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Favorites filter not yet implemented')),
                );
              },
            ),

            // Location filter
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Location'),
              subtitle: const Text('Filter by location data'),
              onTap: () {
                Navigator.pop(context);
                // TODO(dev): Implement location filter
              },
            ),

            const SizedBox(height: 16),

            // Clear filters
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO(dev): Implement clear filters
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Clear filters not yet implemented')),
                  );
                },
                child: const Text('Clear All Filters'),
              ),
            ),
          ],
        ),
      );

  /// Build sort options sheet
  Widget _buildSortSheet() => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sort Photos',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Date (Newest First)'),
              onTap: () {
                Navigator.pop(context);
                // TODO(dev): Implement sort order
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Sort by date (newest) not yet implemented')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Date (Oldest First)'),
              onTap: () {
                Navigator.pop(context);
                // TODO(dev): Implement sort order
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Sort by date (oldest) not yet implemented')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha),
              title: const Text('Name (A-Z)'),
              onTap: () {
                Navigator.pop(context);
                // TODO(dev): Implement sort order
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Sort by name not yet implemented')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.data_usage),
              title: const Text('File Size'),
              onTap: () {
                Navigator.pop(context);
                // TODO(dev): Implement sort order
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Sort by size not yet implemented')),
                );
              },
            ),
          ],
        ),
      );

  /// Show date range picker
  void _showDateRangePicker() {
    showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    ).then((dateRange) {
      if (dateRange != null) {
        // TODO(dev): Implement date range filter
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Date range filter not yet implemented: ${dateRange.start} - ${dateRange.end}')),
        );
      }
    });
  }

  /// Capture new photo using camera preview
  Future<void> _capturePhoto() async {
    try {
      // Show camera preview and wait for result
      final PhotoCaptureResult? result = await showCameraPreview(
        context,
        sessionId: widget.sessionId,
        waypointName: 'Photo Waypoint',
      );

      if (result != null &&
          result.success &&
          result.waypoint != null &&
          result.photoWaypoint != null) {
        // Refresh photo provider to show the new photo
        final PhotoNotifier photoNotifier = ref.read(photoProvider.notifier);
        await photoNotifier.refreshPhotos(widget.sessionId);

        // Show success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo captured successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result?.error ?? 'Failed to capture photo'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Enum for photo sort orders (to be added to photo provider)
enum PhotoSortOrder {
  dateDesc,
  dateAsc,
  nameAsc,
  nameDesc,
  sizeAsc,
  sizeDesc,
}
