import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/waypoint_provider.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Fullscreen photo viewer with swipe navigation and toggleable metadata panel
class FullscreenPhotoViewer extends ConsumerStatefulWidget {
  const FullscreenPhotoViewer({
    required this.photoWaypoint,
    this.allPhotos,
    this.initialIndex,
    this.waypoints,
    this.onWaypointUpdated,
    super.key,
  });

  final PhotoWaypoint photoWaypoint;
  final List<PhotoWaypoint>? allPhotos;
  final int? initialIndex;
  final List<Waypoint>? waypoints;
  final void Function(Waypoint updatedWaypoint)? onWaypointUpdated;

  @override
  ConsumerState<FullscreenPhotoViewer> createState() => _FullscreenPhotoViewerState();
}

class _FullscreenPhotoViewerState extends ConsumerState<FullscreenPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;
  late List<Waypoint> _waypoints;

  // Static to persist across instances when navigating between photos
  static bool _showMetadata = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
    _pageController = PageController(initialPage: _currentIndex);
    // Create mutable copy of waypoints for local updates
    _waypoints = List.from(widget.waypoints ?? []);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  PhotoWaypoint get _currentPhoto =>
    widget.allPhotos != null && widget.allPhotos!.isNotEmpty
      ? widget.allPhotos![_currentIndex]
      : widget.photoWaypoint;

  /// Look up the waypoint associated with the current photo
  Waypoint? get _currentWaypoint {
    if (_waypoints.isEmpty) return null;
    try {
      return _waypoints.firstWhere(
        (w) => w.id == _currentPhoto.waypointId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiplePhotos = widget.allPhotos != null && widget.allPhotos!.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: hasMultiplePhotos
          ? Text(
              '${_currentIndex + 1} / ${widget.allPhotos!.length}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            )
          : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () => _showShareOptions(context),
            tooltip: 'Share',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _currentWaypoint != null ? () => _showEditNoteSheet(context) : null,
            tooltip: 'Edit Note',
          ),
          IconButton(
            icon: Icon(_showMetadata ? Icons.info : Icons.info_outline),
            onPressed: _toggleMetadata,
            tooltip: _showMetadata ? 'Hide Metadata' : 'Show Metadata',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Photo viewer with swipe navigation
          if (hasMultiplePhotos)
            PageView.builder(
              controller: _pageController,
              itemCount: widget.allPhotos!.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                return Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: _buildRotatedPhoto(widget.allPhotos![index]),
                  ),
                );
              },
            )
          else
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: _buildRotatedPhoto(_currentPhoto),
              ),
            ),

          // Toggleable metadata panel
          if (_showMetadata)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Notes section - show if waypoint has notes
                      if (_currentWaypoint?.notes != null &&
                          _currentWaypoint!.notes!.isNotEmpty) ...[
                        _buildMetadataSection('Note', [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _currentWaypoint!.notes!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),
                      ],

                      // Location section - coordinates and elevation from waypoint
                      if (_currentWaypoint != null) ...[
                        _buildMetadataSection('Location', [
                          _buildMetadataRow(
                            Icons.location_on,
                            'Latitude',
                            _currentWaypoint!.coordinates.latitude.toStringAsFixed(6),
                          ),
                          _buildMetadataRow(
                            Icons.location_on,
                            'Longitude',
                            _currentWaypoint!.coordinates.longitude.toStringAsFixed(6),
                          ),
                          if (_currentWaypoint!.altitude != null)
                            _buildMetadataRow(
                              Icons.terrain,
                              'Elevation',
                              '${_currentWaypoint!.altitude!.toStringAsFixed(1)} m (${(_currentWaypoint!.altitude! * 3.28084).toStringAsFixed(0)} ft)',
                            ),
                          if (_currentWaypoint!.accuracy != null)
                            _buildMetadataRow(
                              Icons.gps_fixed,
                              'GPS Accuracy',
                              '${_currentWaypoint!.accuracy!.toStringAsFixed(1)} m (${_currentWaypoint!.accuracyDescription})',
                            ),
                        ]),
                        const SizedBox(height: 20),
                      ],

                      // Camera orientation section
                      if (_currentPhoto.deviceYaw != null ||
                          _currentPhoto.devicePitch != null ||
                          _currentPhoto.deviceRoll != null) ...[
                        _buildMetadataSection('Camera Orientation', [
                          if (_currentPhoto.deviceYaw != null)
                            _buildMetadataRow(
                              Icons.explore,
                              'Direction',
                              '${_currentPhoto.deviceYaw!.toStringAsFixed(0)}° ${_getCompassDirection(_currentPhoto.deviceYaw!)}',
                            ),
                          if (_currentPhoto.devicePitch != null)
                            _buildMetadataRow(
                              Icons.swap_vert,
                              'Pitch',
                              '${_currentPhoto.devicePitch!.toStringAsFixed(1)}°',
                            ),
                          if (_currentPhoto.deviceRoll != null)
                            _buildMetadataRow(
                              Icons.screen_rotation,
                              'Roll',
                              '${_currentPhoto.deviceRoll!.toStringAsFixed(1)}°',
                            ),
                          if (_currentPhoto.cameraTiltAngle != null)
                            _buildMetadataRow(
                              Icons.camera,
                              'Camera Tilt',
                              '${_currentPhoto.cameraTiltAngle!.toStringAsFixed(1)}°',
                            ),
                        ]),
                        const SizedBox(height: 20),
                      ],

                      // Photo info section
                      _buildMetadataSection('Photo Information', [
                        _buildMetadataRow(
                          Icons.access_time,
                          'Captured',
                          _formatDateTime(_currentPhoto.createdAt),
                        ),
                        if (_currentPhoto.source != null)
                          _buildMetadataRow(
                            _currentPhoto.isFromMetaGlasses ? Icons.visibility : Icons.camera_alt,
                            'Source',
                            _currentPhoto.isFromMetaGlasses ? 'Meta Ray-Ban Glasses' : 'Phone Camera',
                          ),
                        _buildMetadataRow(
                          Icons.storage,
                          'File Size',
                          _currentPhoto.fileSizeFormatted,
                        ),
                        if (_currentPhoto.dimensionsFormatted != null)
                          _buildMetadataRow(
                            Icons.photo_size_select_actual,
                            'Dimensions',
                            _currentPhoto.dimensionsFormatted!,
                          ),
                        if (_currentPhoto.photoOrientation != null)
                          _buildMetadataRow(
                            Icons.crop_rotate,
                            'Orientation',
                            _currentPhoto.photoOrientation!.replaceAll('_', ' ').toUpperCase(),
                          ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleMetadata() {
    setState(() => _showMetadata = !_showMetadata);
  }

  void _showEditNoteSheet(BuildContext context) {
    final waypoint = _currentWaypoint;
    if (waypoint == null) return;

    final controller = TextEditingController(text: waypoint.notes ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Note',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final newNote = controller.text.trim();
                      Navigator.pop(context);
                      await _saveNote(waypoint, newNote.isEmpty ? null : newNote);
                    },
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 4,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add a note about this photo...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  filled: true,
                  fillColor: Colors.grey.shade800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveNote(Waypoint waypoint, String? newNote) async {
    try {
      final waypointService = ref.read(waypointServiceProvider);
      final updatedWaypoint = waypoint.copyWith(notes: newNote);

      await waypointService.updateWaypoint(updatedWaypoint);

      // Update local list
      final index = _waypoints.indexWhere((w) => w.id == waypoint.id);
      if (index != -1) {
        setState(() {
          _waypoints[index] = updatedWaypoint;
        });
      }

      // Notify parent
      widget.onWaypointUpdated?.call(updatedWaypoint);

      if (mounted) {
        _showSnackBar('Note saved');
      }
    } catch (e) {
      debugPrint('Error saving note: $e');
      if (mounted) {
        _showSnackBar('Failed to save note', isError: true);
      }
    }
  }

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share, color: Colors.white),
                title: const Text(
                  'Share Photo...',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Save to Files, Camera Roll, or send to others',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _sharePhoto();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sharePhoto() async {
    try {
      final file = await _resolvePhotoFile(_currentPhoto.filePath);
      if (!file.existsSync()) {
        _showSnackBar('Photo file not found', isError: true);
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Photo from Obsession Tracker',
        ),
      );
    } catch (e) {
      debugPrint('Error sharing photo: $e');
      _showSnackBar('Failed to share photo: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildMetadataSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildMetadataRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, y • h:mm a').format(dateTime);
  }

  /// Convert heading degrees to compass direction
  String _getCompassDirection(double heading) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((heading + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  /// Build photo with rotation based on our saved orientation metadata
  /// Don't use EXIF because camera is locked in portrait mode
  Widget _buildRotatedPhoto(PhotoWaypoint photo) {
    // Load photo directly without EXIF processing
    return FutureBuilder<File>(
      future: _resolvePhotoFile(photo.filePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red, size: 48),
                SizedBox(height: 16),
                Text(
                  'Failed to load photo',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }

        final orientation = photo.photoOrientation;
        debugPrint('📸 Photo orientation from database: $orientation');

        // Create image widget without EXIF processing
        final imageWidget = Image.file(
          snapshot.data!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.broken_image, color: Colors.red, size: 48),
            );
          },
        );

        // For landscape photos, rotate 90 degrees counter-clockwise
        if (orientation == 'landscape') {
          return RotatedBox(
            quarterTurns: 3, // 270° clockwise = 90° counter-clockwise
            child: imageWidget,
          );
        }

        // Portrait or unknown - display as-is
        return imageWidget;
      },
    );
  }

  /// Resolve photo file path - converts relative paths to absolute
  Future<File> _resolvePhotoFile(String photoPath) async {
    if (photoPath.startsWith('/')) {
      return File(photoPath);
    }

    final Directory docs = await getApplicationDocumentsDirectory();
    final String absolutePath = path.join(docs.path, photoPath);
    return File(absolutePath);
  }
}
