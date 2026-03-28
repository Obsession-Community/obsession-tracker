import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/custom_marker.dart';
import 'package:obsession_tracker/core/models/marker_attachment.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/models/playback_media.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/custom_marker_service.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/marker_attachment_service.dart';
import 'package:obsession_tracker/core/services/photo_capture_service.dart';

/// State for session playback
class PlaybackState {
  const PlaybackState({
    required this.isPlaying,
    required this.currentPosition,
    required this.progress,
    required this.speed,
    this.session,
    this.currentPhoto,
    this.currentPhotoWaypoint,
    this.breadcrumbs = const [],
    this.waypoints = const [],
    this.photoWaypoints = const [],
    this.customMarkers = const [],
    this.playbackMedia = const [],
    this.currentMedia,
    this.isLoading = true,
    this.error,
  });

  final bool isPlaying;
  final LatLng currentPosition;
  final double progress; // 0.0 to 1.0
  final double speed; // Playback speed multiplier
  final TrackingSession? session;
  final Waypoint? currentPhoto;
  final PhotoWaypoint? currentPhotoWaypoint;
  final List<Breadcrumb> breadcrumbs;
  final List<Waypoint> waypoints;
  final List<PhotoWaypoint> photoWaypoints;
  final List<CustomMarker> customMarkers;

  /// Unified media list for carousel (from MarkerAttachments on CustomMarkers)
  final List<PlaybackMedia> playbackMedia;

  /// Currently highlighted media in the carousel (based on playback position)
  final PlaybackMedia? currentMedia;

  final bool isLoading;
  final String? error;

  factory PlaybackState.initial() => const PlaybackState(
        isPlaying: false,
        currentPosition: LatLng(0, 0),
        progress: 0.0,
        speed: 1.0,
      );

  PlaybackState copyWith({
    bool? isPlaying,
    LatLng? currentPosition,
    double? progress,
    double? speed,
    TrackingSession? session,
    Waypoint? currentPhoto,
    PhotoWaypoint? currentPhotoWaypoint,
    List<Breadcrumb>? breadcrumbs,
    List<Waypoint>? waypoints,
    List<PhotoWaypoint>? photoWaypoints,
    List<CustomMarker>? customMarkers,
    List<PlaybackMedia>? playbackMedia,
    PlaybackMedia? currentMedia,
    bool clearCurrentMedia = false,
    bool? isLoading,
    String? error,
  }) =>
      PlaybackState(
        isPlaying: isPlaying ?? this.isPlaying,
        currentPosition: currentPosition ?? this.currentPosition,
        progress: progress ?? this.progress,
        speed: speed ?? this.speed,
        session: session ?? this.session,
        currentPhoto: currentPhoto ?? this.currentPhoto,
        currentPhotoWaypoint: currentPhotoWaypoint ?? this.currentPhotoWaypoint,
        breadcrumbs: breadcrumbs ?? this.breadcrumbs,
        waypoints: waypoints ?? this.waypoints,
        photoWaypoints: photoWaypoints ?? this.photoWaypoints,
        customMarkers: customMarkers ?? this.customMarkers,
        playbackMedia: playbackMedia ?? this.playbackMedia,
        currentMedia: clearCurrentMedia ? null : (currentMedia ?? this.currentMedia),
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
      );

  int get currentBreadcrumbIndex {
    if (breadcrumbs.isEmpty) return 0;
    if (progress.isNaN || progress.isInfinite) return 0;
    return (breadcrumbs.length * progress).floor().clamp(0, breadcrumbs.length - 1);
  }

  Breadcrumb? get currentBreadcrumb => breadcrumbs.isEmpty
      ? null
      : breadcrumbs[currentBreadcrumbIndex];
}

/// Controller for managing session playback state and animation
class PlaybackController extends Notifier<PlaybackState> {
  Timer? _animationTimer;
  int _currentIndex = 0;
  late final TrackingSession _session;

  /// Initialize with session from the family argument
  void _initializeWithSession(TrackingSession session) {
    _session = session;
    _initialize();
  }

  /// The session being played back
  TrackingSession get session => _session;

  @override
  PlaybackState build() {
    ref.onDispose(() {
      _animationTimer?.cancel();
    });
    return PlaybackState.initial();
  }

  /// Initialize playback by loading breadcrumbs and waypoints
  Future<void> _initialize() async {
    try {
      // Load breadcrumbs, waypoints, photo waypoints, and custom markers from database
      final db = DatabaseService();
      final photoService = PhotoCaptureService();
      final markerService = CustomMarkerService();
      final attachmentService = MarkerAttachmentService();

      final breadcrumbs = await db.getBreadcrumbsForSession(_session.id);
      final waypoints = await db.getWaypointsForSession(_session.id);
      final photoWaypoints = await photoService.getAllPhotoWaypointsForSession(_session.id);
      final customMarkers = await markerService.getMarkersForSession(_session.id);

      // Load image attachments for each custom marker and create PlaybackMedia items
      final List<PlaybackMedia> allPlaybackMedia = [];
      debugPrint('📷 Loading attachments for ${customMarkers.length} custom markers...');
      for (final marker in customMarkers) {
        final attachments = await attachmentService.getAttachmentsForMarker(marker.id);
        debugPrint('📷 Marker ${marker.id} (${marker.name}): found ${attachments.length} attachments');
        // Filter to only image attachments
        final imageAttachments = attachments
            .where((a) => a.type == MarkerAttachmentType.image)
            .toList();

        debugPrint('📷   Image attachments: ${imageAttachments.length}');
        for (final attachment in imageAttachments) {
          debugPrint('📷   Attachment ${attachment.id}: filePath=${attachment.filePath}');
          final media = PlaybackMedia.tryFromMarkerAttachment(attachment, marker);
          if (media != null) {
            allPlaybackMedia.add(media);
            debugPrint('📷   Created PlaybackMedia for ${attachment.id}');
          } else {
            debugPrint('📷   FAILED to create PlaybackMedia (null filePath?)');
          }
        }
      }

      // Sort playback media chronologically (oldest first) for the carousel
      allPlaybackMedia.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Sort photo waypoints chronologically (oldest first) for the carousel (legacy)
      photoWaypoints.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (breadcrumbs.isEmpty) {
        state = state.copyWith(
          error: 'No breadcrumbs found for this session',
          isLoading: false,
          session: _session,
        );
        return;
      }

      // Sort breadcrumbs by timestamp
      breadcrumbs.sort((Breadcrumb a, Breadcrumb b) => a.timestamp.compareTo(b.timestamp));

      // Set initial position to first breadcrumb
      debugPrint('Playback initialized: ${breadcrumbs.length} breadcrumbs, ${customMarkers.length} custom markers');
      debugPrint('  PlaybackMedia (new): ${allPlaybackMedia.length} images from marker attachments');
      debugPrint('  Legacy waypoints: ${waypoints.length} (photo type: ${waypoints.where((Waypoint w) => w.type == WaypointType.photo).length})');
      debugPrint('  Legacy photo waypoints: ${photoWaypoints.length}');

      // Check for initial photo at position 0
      Waypoint? initialPhoto;
      PhotoWaypoint? initialPhotoWaypoint;
      final firstBreadcrumb = breadcrumbs[0];

      for (final Waypoint waypoint in waypoints.where((Waypoint w) => w.type == WaypointType.photo)) {
        final timeDiff = waypoint.timestamp.difference(firstBreadcrumb.timestamp).inSeconds.abs();
        if (timeDiff < 2) {
          initialPhoto = waypoint;
          break;
        }
      }

      if (initialPhoto != null) {
        for (final PhotoWaypoint pw in photoWaypoints) {
          if (pw.waypointId == initialPhoto.id) {
            initialPhotoWaypoint = pw;
            debugPrint('Found initial photo: ${pw.filePath}');
            break;
          }
        }
      }

      // Check for initial PlaybackMedia at position 0
      PlaybackMedia? initialMedia;
      for (final media in allPlaybackMedia) {
        final timeDiff = media.createdAt.difference(firstBreadcrumb.timestamp).inSeconds.abs();
        if (timeDiff < 2) {
          initialMedia = media;
          debugPrint('Found initial PlaybackMedia: ${media.displayName}');
          break;
        }
      }

      state = state.copyWith(
        breadcrumbs: breadcrumbs,
        waypoints: waypoints,
        photoWaypoints: photoWaypoints,
        customMarkers: customMarkers,
        playbackMedia: allPlaybackMedia,
        currentMedia: initialMedia,
        currentPosition: breadcrumbs[0].coordinates,
        currentPhoto: initialPhoto,
        currentPhotoWaypoint: initialPhotoWaypoint,
        isLoading: false,
        session: _session,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        error: 'Failed to load session data: $e',
        isLoading: false,
        session: _session,
      );
    }
  }

  /// Start playback animation
  void play() {
    if (state.breadcrumbs.isEmpty) return;

    state = state.copyWith(isPlaying: true);
    _startAnimation();
  }

  /// Pause playback
  void pause() {
    state = state.copyWith(isPlaying: false);
    _animationTimer?.cancel();
    _animationTimer = null;
  }

  /// Toggle play/pause
  void togglePlayPause() {
    if (state.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  /// Seek to specific position (0.0 to 1.0)
  void seek(double position) {
    if (state.breadcrumbs.isEmpty) return;
    if (position.isNaN || position.isInfinite) return;
    final targetIndex = (state.breadcrumbs.length * position).floor();
    _currentIndex = targetIndex.clamp(0, state.breadcrumbs.length - 1);
    _updatePosition();
  }

  /// Skip to next photo waypoint
  void skipToNextPhoto() {
    final currentTimestamp = state.currentBreadcrumb?.timestamp;
    if (currentTimestamp == null) return;

    final photoWaypoints = state.waypoints
        .where((Waypoint w) => w.type == WaypointType.photo)
        .toList()
      ..sort((Waypoint a, Waypoint b) => a.timestamp.compareTo(b.timestamp));

    // Find next photo after current position
    final nextPhoto = photoWaypoints.firstWhere(
      (Waypoint photo) => photo.timestamp.isAfter(currentTimestamp),
      orElse: () => photoWaypoints.isNotEmpty
          ? photoWaypoints.last
          : Waypoint(
              id: '',
              sessionId: _session.id,
              type: WaypointType.photo,
              coordinates: const LatLng(0, 0),
              timestamp: currentTimestamp,
            ),
    );

    // Find breadcrumb closest to photo timestamp
    final photoIndex = state.breadcrumbs.indexWhere(
      (Breadcrumb b) => b.timestamp.isAfter(nextPhoto.timestamp),
    );

    if (photoIndex != -1) {
      _currentIndex = photoIndex;
      _updatePosition();
    }
  }

  /// Skip to previous photo waypoint
  void skipToPreviousPhoto() {
    final currentTimestamp = state.currentBreadcrumb?.timestamp;
    if (currentTimestamp == null) return;

    final photoWaypoints = state.waypoints
        .where((Waypoint w) => w.type == WaypointType.photo)
        .toList()
      ..sort((Waypoint a, Waypoint b) => b.timestamp.compareTo(a.timestamp)); // Reverse sort

    // Find previous photo before current position
    final prevPhoto = photoWaypoints.firstWhere(
      (Waypoint photo) => photo.timestamp.isBefore(currentTimestamp),
      orElse: () => photoWaypoints.isNotEmpty
          ? photoWaypoints.last
          : Waypoint(
              id: '',
              sessionId: _session.id,
              type: WaypointType.photo,
              coordinates: const LatLng(0, 0),
              timestamp: currentTimestamp,
            ),
    );

    // Find breadcrumb closest to photo timestamp
    final photoIndex = state.breadcrumbs.lastIndexWhere(
      (Breadcrumb b) => b.timestamp.isBefore(prevPhoto.timestamp),
    );

    if (photoIndex != -1) {
      _currentIndex = photoIndex;
      _updatePosition();
    }
  }

  /// Change playback speed
  void setSpeed(double speed) {
    final wasPlaying = state.isPlaying;
    if (wasPlaying) {
      pause();
    }

    state = state.copyWith(speed: speed);

    if (wasPlaying) {
      play();
    }
  }

  /// Start the animation timer
  void _startAnimation() {
    _animationTimer?.cancel();

    // Calculate interval based on speed and breadcrumb density
    const baseInterval = 100; // ms between updates at 1x speed
    final interval = (baseInterval / state.speed).round();

    _animationTimer = Timer.periodic(
      Duration(milliseconds: interval),
      (_) => _advancePlayback(),
    );
  }

  /// Advance playback by one step
  void _advancePlayback() {
    if (_currentIndex >= state.breadcrumbs.length - 1) {
      // Reached end
      pause();
      return;
    }

    _currentIndex++;
    _updatePosition();
  }

  /// Update position and check for nearby waypoints
  void _updatePosition() {
    if (state.breadcrumbs.isEmpty) return;
    final breadcrumb = state.breadcrumbs[_currentIndex];
    // Guard against division by zero when there's only 1 breadcrumb
    final progress = state.breadcrumbs.length <= 1
        ? 0.0
        : _currentIndex / (state.breadcrumbs.length - 1);

    // Check for nearby photo waypoints (legacy)
    Waypoint? nearbyPhoto;
    PhotoWaypoint? nearbyPhotoWaypoint;

    for (final Waypoint waypoint in state.waypoints.where((Waypoint w) => w.type == WaypointType.photo)) {
      final timeDiff = waypoint.timestamp.difference(breadcrumb.timestamp).inSeconds.abs();
      if (timeDiff < 2) {
        nearbyPhoto = waypoint;
        break;
      }
    }

    // Also check photo waypoints for matching (legacy)
    if (nearbyPhoto != null) {
      for (final PhotoWaypoint pw in state.photoWaypoints) {
        if (pw.waypointId == nearbyPhoto.id) {
          nearbyPhotoWaypoint = pw;
          break;
        }
      }

      // If no match by waypointId, try by timestamp
      if (nearbyPhotoWaypoint == null) {
        debugPrint('No match by waypointId for ${nearbyPhoto.id}, trying timestamp match');

        for (final PhotoWaypoint pw in state.photoWaypoints) {
          final timeDiff = pw.createdAt.difference(nearbyPhoto.timestamp).inSeconds.abs();
          if (timeDiff < 5) {
            nearbyPhotoWaypoint = pw;
            debugPrint('Found timestamp match: ${pw.filePath}');
            break;
          }
        }
      }
    }

    // Check for nearby PlaybackMedia (new unified system)
    // Keep the most recent media highlighted until the next one is reached
    // This ensures a photo stays selected once we've passed its timestamp
    PlaybackMedia? nearbyMedia;
    for (final media in state.playbackMedia) {
      // Select this media if we've reached or passed its timestamp
      if (!media.createdAt.isAfter(breadcrumb.timestamp)) {
        // This media was created at or before current position
        // Keep the most recent one (last one we passed)
        if (nearbyMedia == null || media.createdAt.isAfter(nearbyMedia.createdAt)) {
          nearbyMedia = media;
        }
      }
    }

    state = state.copyWith(
      currentPosition: breadcrumb.coordinates,
      progress: progress,
      currentPhoto: nearbyPhoto,
      currentPhotoWaypoint: nearbyPhotoWaypoint,
      currentMedia: nearbyMedia,
      clearCurrentMedia: nearbyMedia == null,
    );
  }

  /// Jump to a specific PlaybackMedia item by seeking to its timestamp
  void jumpToMedia(PlaybackMedia media) {
    // Find the breadcrumb closest to the media's createdAt timestamp
    final mediaIndex = state.breadcrumbs.indexWhere(
      (Breadcrumb b) => b.timestamp.isAfter(media.createdAt) ||
                        b.timestamp.isAtSameMomentAs(media.createdAt),
    );

    if (mediaIndex != -1) {
      _currentIndex = mediaIndex;
      _updatePosition();
    } else if (state.breadcrumbs.isNotEmpty) {
      // If media timestamp is after all breadcrumbs, go to the last one
      _currentIndex = state.breadcrumbs.length - 1;
      _updatePosition();
    }
  }

  /// Skip to next PlaybackMedia item
  void skipToNextMedia() {
    if (state.playbackMedia.isEmpty) return;

    final currentTimestamp = state.currentBreadcrumb?.timestamp;
    if (currentTimestamp == null) return;

    // Find next media after current position
    final nextMedia = state.playbackMedia.firstWhere(
      (media) => media.createdAt.isAfter(currentTimestamp),
      orElse: () => state.playbackMedia.last,
    );

    jumpToMedia(nextMedia);
  }

  /// Skip to previous PlaybackMedia item
  void skipToPreviousMedia() {
    if (state.playbackMedia.isEmpty) return;

    final currentTimestamp = state.currentBreadcrumb?.timestamp;
    if (currentTimestamp == null) return;

    // Find previous media before current position (search in reverse)
    final sortedReverse = state.playbackMedia.reversed.toList();
    final prevMedia = sortedReverse.firstWhere(
      (media) => media.createdAt.isBefore(currentTimestamp),
      orElse: () => state.playbackMedia.first,
    );

    jumpToMedia(prevMedia);
  }

  /// Reset playback to start
  void reset() {
    pause();
    _currentIndex = 0;

    if (state.breadcrumbs.isNotEmpty) {
      state = state.copyWith(
        currentPosition: state.breadcrumbs[0].coordinates,
        progress: 0.0,
      );
    }
  }

  /// Get breadcrumb at specific time
  Breadcrumb? getBreadcrumbAtTime(DateTime time) {
    return state.breadcrumbs.firstWhere(
      (Breadcrumb b) => b.timestamp.isAtSameMomentAs(time) || b.timestamp.isAfter(time),
      orElse: () => state.breadcrumbs.last,
    );
  }

  /// Jump to a specific waypoint by ID
  void jumpToWaypoint(String waypointId) {
    final waypoint = state.waypoints.firstWhere(
      (Waypoint w) => w.id == waypointId,
      orElse: () => state.waypoints.first,
    );

    // Find the breadcrumb closest to the waypoint's timestamp
    final waypointIndex = state.breadcrumbs.indexWhere(
      (Breadcrumb b) => b.timestamp.isAfter(waypoint.timestamp) ||
                        b.timestamp.isAtSameMomentAs(waypoint.timestamp),
    );

    if (waypointIndex != -1) {
      _currentIndex = waypointIndex;
      _updatePosition();
    }
  }
}

/// Provider for playback controller - family provider keyed by session
final playbackControllerProvider = NotifierProvider.family<
    PlaybackController,
    PlaybackState,
    TrackingSession>((TrackingSession session) {
  final controller = PlaybackController();
  // Note: initialization happens after the Notifier is created
  // We use a post-creation approach
  return controller;
});

/// Helper to get initialized playback controller
/// Use this instead of directly accessing the family provider
extension PlaybackControllerExtension on PlaybackController {
  /// Initialize with the session - call this after getting the notifier
  void initializeSession(TrackingSession session) {
    _initializeWithSession(session);
  }
}
