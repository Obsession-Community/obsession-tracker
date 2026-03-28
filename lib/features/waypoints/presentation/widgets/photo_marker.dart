import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/providers/photo_provider.dart';

/// A map marker that displays a photo thumbnail
class PhotoMarker extends ConsumerWidget {
  const PhotoMarker({
    required this.photo,
    required this.onTap,
    super.key,
    this.size = 40,
    this.showBorder = true,
    this.showShadow = true,
  });

  /// The photo to display
  final PhotoWaypoint photo;

  /// Callback when the marker is tapped
  final VoidCallback onTap;

  /// Size of the marker
  final double size;

  /// Whether to show a border around the marker
  final bool showBorder;

  /// Whether to show a shadow
  final bool showShadow;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: showBorder
                ? Border.all(
                    color: Colors.white,
                    width: 2,
                  )
                : null,
            boxShadow: showShadow
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: ClipOval(
            child: FutureBuilder<Uint8List?>(
              future: ref.read(photoProvider.notifier).getThumbnail(photo),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildFallbackImage(context),
                  );
                } else if (photo.hasThumbnail && photo.thumbnailPath != null) {
                  return Image.file(
                    File(photo.thumbnailPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildFallbackImage(context),
                  );
                } else {
                  return Image.file(
                    File(photo.filePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildFallbackImage(context),
                  );
                }
              },
            ),
          ),
        ),
      );

  Widget _buildFallbackImage(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.photo,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: size * 0.5,
        ),
      );
}

/// A clustered photo marker showing multiple photos
class ClusteredPhotoMarker extends StatelessWidget {
  const ClusteredPhotoMarker({
    required this.photos,
    required this.onTap,
    super.key,
    this.size = 50,
  });

  /// The photos in this cluster
  final List<PhotoWaypoint> photos;

  /// Callback when the marker is tapped
  final VoidCallback onTap;

  /// Size of the marker
  final double size;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background circle
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),

            // Photo count
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.photo_library,
                  color: Colors.white,
                  size: size * 0.4,
                ),
                Text(
                  '${photos.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

/// A photo marker with a count badge for waypoints with multiple photos
class PhotoWaypointMarker extends ConsumerWidget {
  const PhotoWaypointMarker({
    required this.photos,
    required this.onTap,
    super.key,
    this.size = 40,
  });

  /// The photos at this waypoint
  final List<PhotoWaypoint> photos;

  /// Callback when the marker is tapped
  final VoidCallback onTap;

  /// Size of the marker
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (photos.isEmpty) {
      return const SizedBox.shrink();
    }

    if (photos.length == 1) {
      return PhotoMarker(
        photo: photos.first,
        onTap: onTap,
        size: size,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main photo
          PhotoMarker(
            photo: photos.first,
            onTap: onTap,
            size: size,
          ),

          // Count badge
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                ),
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                '${photos.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
