import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/mapbox_config.dart';
import 'package:obsession_tracker/core/models/playback_media.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/waypoint_provider.dart';
import 'package:obsession_tracker/core/services/marker_attachment_service.dart';
import 'package:obsession_tracker/core/services/route_planning_service.dart' as route_service;
import 'package:obsession_tracker/features/map/presentation/widgets/core_map_view.dart';
import 'package:obsession_tracker/features/sessions/presentation/controllers/playback_controller.dart';
import 'package:obsession_tracker/features/sessions/presentation/widgets/session_export_menu.dart';

/// Session playback page with animated GPS timeline and photo sync.
///
/// This page is the core differentiating feature, allowing users to watch
/// an animated replay of their tracking session with:
/// - Animated user dot moving along GPS breadcrumb trail
/// - Photos appearing when dot reaches their waypoint
/// - Playback controls (play/pause/scrub/speed)
/// - Full map context with land ownership, trails, historical places
///
/// Uses CoreMapView for shared map functionality, adding only playback-specific UI.
class SessionPlaybackPage extends ConsumerStatefulWidget {
  const SessionPlaybackPage({
    required this.session,
    this.initialWaypoint,
    super.key,
  });

  final TrackingSession session;
  final Waypoint? initialWaypoint;

  @override
  ConsumerState<SessionPlaybackPage> createState() => _SessionPlaybackPageState();
}

class _SessionPlaybackPageState extends ConsumerState<SessionPlaybackPage> {
  MapboxMap? _mapboxMap;
  route_service.PlannedRoute? _plannedRoute;

  // Playback position marker
  CircleAnnotationManager? _positionMarkerManager;
  CircleAnnotation? _positionMarker;

  // CoreMapView key for accessing state
  final GlobalKey<CoreMapViewState> _coreMapKey = GlobalKey<CoreMapViewState>();

  // Cached breadcrumbs to avoid recreating list on every build
  List<geo.Position>? _cachedBreadcrumbs;
  int _cachedBreadcrumbsLength = 0;

  // Cached planned route conversion to avoid recreating on every build
  PlannedRoute? _cachedCoreMapPlannedRoute;
  String? _cachedPlannedRouteId;

  // Follow mode - when enabled, camera smoothly follows playback position
  bool _followPlaybackPosition = true;

  /// Track rotations locally for thumbnails (updated when viewer changes rotation)
  final Map<String, int> _rotations = {};

  @override
  void initState() {
    super.initState();

    // Initialize playback controller with session data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(playbackControllerProvider(widget.session).notifier)
          .initializeSession(widget.session);
    });

    // Load planned route if session has one
    if (widget.session.plannedRouteId != null) {
      _loadPlannedRoute(widget.session.plannedRouteId!);
    }

    // If initial waypoint provided, jump to it after map initializes
    if (widget.initialWaypoint != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(playbackControllerProvider(widget.session).notifier)
            .jumpToWaypoint(widget.initialWaypoint!.id);
      });
    }
  }

  @override
  void dispose() {
    _mapboxMap = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(playbackControllerProvider(widget.session));

    // Update position marker when playback position changes
    ref.listen<PlaybackState>(
      playbackControllerProvider(widget.session),
      (previous, next) {
        if (previous?.currentPosition != next.currentPosition && _mapboxMap != null) {
          _updatePositionMarker(next.currentPosition);
          // Smoothly center camera on position when follow mode is active
          if (_followPlaybackPosition) {
            _centerOnPlaybackPosition(next.currentPosition);
          }
        }
        // Cache rotations when playbackMedia first loads
        if ((previous?.playbackMedia.isEmpty ?? true) && next.playbackMedia.isNotEmpty) {
          _cacheRotations(next.playbackMedia);
        }
      },
    );

    if (playbackState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.session.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (playbackState.error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.session.name)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(playbackState.error!),
            ],
          ),
        ),
      );
    }

    // Convert breadcrumbs to geo.Position format for CoreMapView
    // Cache to avoid creating new list on every build (which triggers overlay updates)
    final sourceBreadcrumbs = playbackState.breadcrumbs;
    if (_cachedBreadcrumbs == null || _cachedBreadcrumbsLength != sourceBreadcrumbs.length) {
      _cachedBreadcrumbs = sourceBreadcrumbs
          .map((b) => geo.Position(
                latitude: b.coordinates.latitude,
                longitude: b.coordinates.longitude,
                timestamp: b.timestamp,
                accuracy: b.accuracy,
                altitude: b.altitude ?? 0.0,
                altitudeAccuracy: 0.0,
                heading: b.heading ?? 0.0,
                headingAccuracy: 0.0,
                speed: b.speed ?? 0.0,
                speedAccuracy: 0.0,
              ))
          .toList();
      _cachedBreadcrumbsLength = sourceBreadcrumbs.length;
    }
    final breadcrumbs = _cachedBreadcrumbs!;

    // Convert planned route to CoreMapView format (cached to avoid rebuild loops)
    if (_plannedRoute != null && _cachedPlannedRouteId != _plannedRoute!.id) {
      _cachedCoreMapPlannedRoute = PlannedRoute(
        id: _plannedRoute!.id,
        name: _plannedRoute!.name,
        points: _plannedRoute!.routePoints
            .map((LatLng point) => PlannedRoutePoint(
                  latitude: point.latitude,
                  longitude: point.longitude,
                ))
            .toList(),
      );
      _cachedPlannedRouteId = _plannedRoute!.id;
    } else if (_plannedRoute == null) {
      _cachedCoreMapPlannedRoute = null;
      _cachedPlannedRouteId = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.name),
        actions: [
          // Refresh map data button
          IconButton(
            icon: _coreMapKey.currentState?.isLoadingLandData == true
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: () => _coreMapKey.currentState?.forceRefreshMapData(),
            tooltip: 'Refresh Map Data',
          ),
          // Land filter button
          IconButton(
            icon: Icon(
              Icons.filter_alt,
              color: _coreMapKey.currentState?.isFilterPanelVisible == true
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: () => _coreMapKey.currentState?.toggleFilterPanel(),
            tooltip: 'Land Type Filters',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _sharePlayback,
            tooltip: 'Share',
          ),
        ],
      ),
      body: Column(
        children: [
          // Map area - takes remaining space
          Expanded(
            child: Stack(
              children: [
                // CoreMapView with all shared functionality
                CoreMapView(
                  key: _coreMapKey,
                  config: MapboxPresets.sessionPlayback.copyWith(
                    initialCenter: breadcrumbs.isNotEmpty
                        ? Point(
                            coordinates: Position(
                              playbackState.currentPosition.longitude,
                              playbackState.currentPosition.latitude,
                            ),
                          )
                        : null,
                    initialZoom: 15.0,
                  ),
                  breadcrumbs: breadcrumbs,
                  waypoints: playbackState.waypoints,
                  plannedRoute: _cachedCoreMapPlannedRoute,
                  sessionId: widget.session.id, // For session-specific marker filtering
                  showFollowLocationButton: false, // Playback controls manage position
                  showFilterButton: false, // We have our own filter button in app bar
                  onMapCreated: _onMapCreated,
                  onWaypointTap: _onWaypointTapped,
                  onLandDataLoaded: _initializePositionMarker,
                ),

                // Compass showing playback bearing
                Positioned(
                  top: 16,
                  right: 16,
                  child: _buildPlaybackCompass(playbackState),
                ),

                // Follow playback position button
                Positioned(
                  top: 80, // Below compass
                  right: 16,
                  child: _buildFollowButton(),
                ),
              ],
            ),
          ),

          // Photo thumbnail carousel - unified PlaybackMedia from CustomMarker attachments
          if (playbackState.playbackMedia.isNotEmpty)
            _buildMediaCarousel(playbackState),

          // Playback controls
          _buildPlaybackControls(playbackState),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls(PlaybackState playbackState) {
    final controller = ref.read(playbackControllerProvider(widget.session).notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timeline scrubber
          Slider(
            value: playbackState.progress,
            onChanged: controller.seek,
          ),

          // Time display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_getCurrentDuration(playbackState)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  _formatDuration(widget.session.duration),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous photo button
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: playbackState.playbackMedia.isNotEmpty
                    ? controller.skipToPreviousMedia
                    : null,
                tooltip: 'Previous Photo',
              ),

              const SizedBox(width: 8),

              // Play/Pause button (larger)
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(playbackState.isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 36,
                  color: Theme.of(context).colorScheme.onPrimary,
                  onPressed: controller.togglePlayPause,
                  tooltip: playbackState.isPlaying ? 'Pause' : 'Play',
                ),
              ),

              const SizedBox(width: 8),

              // Next photo button
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: playbackState.playbackMedia.isNotEmpty
                    ? controller.skipToNextMedia
                    : null,
                tooltip: 'Next Photo',
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Speed controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Speed: ',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              for (final speed in [0.25, 0.5, 1.0, 2.0]) ...[
                const SizedBox(width: 4),
                ChoiceChip(
                  label: Text(
                    _formatSpeedLabel(speed),
                    style: TextStyle(
                      fontWeight: playbackState.speed == speed
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: playbackState.speed == speed
                          ? Theme.of(context).colorScheme.onPrimary
                          : null,
                    ),
                  ),
                  selected: playbackState.speed == speed,
                  onSelected: (_) => controller.setSpeed(speed),
                  showCheckmark: false,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Duration _getCurrentDuration(PlaybackState playbackState) {
    return Duration(
      milliseconds: (widget.session.totalDuration * playbackState.progress).round(),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String _formatSpeedLabel(double speed) {
    if (speed >= 1.0) {
      return '${speed.toInt()}x';
    } else {
      // Format as fraction-like display for slower speeds
      return '${speed.toString().replaceAll(RegExp(r'\.?0+$'), '')}x';
    }
  }

  /// Build compass showing the playback bearing (not current device bearing)
  Widget _buildPlaybackCompass(PlaybackState playbackState) {
    final bearing = playbackState.currentBreadcrumb?.heading ?? 0.0;
    final hasBearing = playbackState.currentBreadcrumb?.heading != null;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Compass needle rotated to show bearing
          Transform.rotate(
            angle: -bearing * (3.14159 / 180), // Convert degrees to radians
            child: Icon(
              Icons.navigation,
              size: 32,
              color: hasBearing
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
          // Bearing text
          Positioned(
            bottom: 4,
            child: Text(
              '${bearing.round()}°',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build follow button to toggle camera following playback position
  Widget _buildFollowButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _followPlaybackPosition = !_followPlaybackPosition;
        });
        // If enabling follow mode, immediately center on current position
        if (_followPlaybackPosition) {
          final playbackState = ref.read(playbackControllerProvider(widget.session));
          _centerOnPlaybackPosition(playbackState.currentPosition);
        }
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _followPlaybackPosition
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          _followPlaybackPosition ? Icons.gps_fixed : Icons.gps_not_fixed,
          size: 24,
          color: _followPlaybackPosition
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  void _sharePlayback() {
    SessionExportMenu.show(context, widget.session);
  }

  /// Build a horizontal scrollable media carousel showing all session photos (new system)
  /// Uses PlaybackMedia from CustomMarker attachments
  Widget _buildMediaCarousel(PlaybackState playbackState) {
    final controller = ref.read(playbackControllerProvider(widget.session).notifier);
    final mediaList = playbackState.playbackMedia;
    final currentMedia = playbackState.currentMedia;

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: mediaList.length,
        itemBuilder: (context, index) {
          final media = mediaList[index];
          final isCurrentMedia = currentMedia?.id == media.id;
          final theme = Theme.of(context);

          return GestureDetector(
            key: ValueKey(media.id),
            onTap: () {
              if (isCurrentMedia) {
                // Already highlighted - open fullscreen viewer
                _showFullscreenMedia(context, media, mediaList, index);
              } else {
                // Not highlighted - seek to this media's timestamp
                controller.jumpToMedia(media);
              }
            },
            onLongPress: () {
              // Long press always opens fullscreen viewer (seek first if needed)
              if (!isCurrentMedia) {
                controller.jumpToMedia(media);
              }
              _showFullscreenMedia(context, media, mediaList, index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isCurrentMedia ? 90 : 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCurrentMedia
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: isCurrentMedia ? 3 : 1,
                ),
                boxShadow: isCurrentMedia
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  // Thumbnail
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isCurrentMedia ? 5 : 7),
                      child: _buildMediaThumbnail(media),
                    ),
                  ),
                  // Selected indicator overlay
                  if (isCurrentMedia)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              theme.colorScheme.primary.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Now playing indicator
                  if (isCurrentMedia)
                    Positioned(
                      bottom: 4,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NOW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Cache rotations from PlaybackMedia for thumbnail display
  void _cacheRotations(List<PlaybackMedia> mediaList) {
    for (final media in mediaList) {
      if (media.userRotation != null && media.userRotation != 0) {
        _rotations[media.id] = media.userRotation!;
      }
    }
  }

  /// Build thumbnail for a PlaybackMedia item
  Widget _buildMediaThumbnail(PlaybackMedia media) {
    final thumbnailPath = media.thumbnailPath ?? media.filePath;
    final file = File(thumbnailPath);

    if (!file.existsSync()) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.broken_image,
            color: Theme.of(context).colorScheme.outline,
            size: 32,
          ),
        ),
      );
    }

    Widget imageWidget = Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.photo,
            color: Theme.of(context).colorScheme.outline,
            size: 32,
          ),
        ),
      ),
    );

    // Apply rotation if needed (use local cache for immediate updates)
    final rotation = _rotations[media.id] ?? media.userRotation ?? 0;
    if (rotation != 0) {
      imageWidget = RotatedBox(
        quarterTurns: rotation,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Show fullscreen viewer for PlaybackMedia
  void _showFullscreenMedia(
    BuildContext context,
    PlaybackMedia media,
    List<PlaybackMedia> allMedia,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _PlaybackMediaViewer(
          media: media,
          allMedia: allMedia,
          initialIndex: initialIndex,
          onMediaChanged: (newMedia) {
            // Jump playback to new media position
            ref
                .read(playbackControllerProvider(widget.session).notifier)
                .jumpToMedia(newMedia);
          },
          onRotationChanged: (mediaId, rotation) {
            // Update local rotation cache so thumbnail updates immediately
            setState(() {
              _rotations[mediaId] = rotation;
            });
          },
        ),
      ),
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    debugPrint('🗺️ SessionPlaybackPage: onMapCreated called');
    _mapboxMap = mapboxMap;

    // Create position marker immediately so it appears right away
    // It will be refreshed via onLandDataLoaded to ensure proper z-ordering
    await _initializePositionMarker();
  }

  /// Update the playback position marker on the map
  Future<void> _updatePositionMarker(LatLng position) async {
    if (_positionMarkerManager == null) return;

    final newGeometry = Point(
      coordinates: Position(position.longitude, position.latitude),
    );

    if (_positionMarker != null) {
      // Update existing marker geometry (don't delete/recreate - causes ghosts)
      _positionMarker!.geometry = newGeometry;
      await _positionMarkerManager!.update(_positionMarker!);
    } else {
      // Create marker for the first time
      _positionMarker = await _positionMarkerManager!.create(
        CircleAnnotationOptions(
          geometry: newGeometry,
          circleRadius: 12.0,
          circleColor: Colors.blue.toARGB32(),
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.toARGB32(),
        ),
      );
    }
  }

  /// Smoothly center the camera on the playback position
  Future<void> _centerOnPlaybackPosition(LatLng position) async {
    if (_mapboxMap == null) return;

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(position.longitude, position.latitude),
        ),
      ),
      MapAnimationOptions(duration: 300),
    );
  }

  /// Initialize the position marker after overlays are loaded.
  /// Called via onLandDataLoaded to ensure marker renders ABOVE all map layers.
  ///
  /// Recreates the annotation manager each time to ensure proper z-ordering
  /// (new managers are added on top of existing layers).
  Future<void> _initializePositionMarker() async {
    if (_mapboxMap == null) return;

    final playbackState = ref.read(playbackControllerProvider(widget.session));
    if (playbackState.breadcrumbs.isEmpty) return;

    // Remove old annotation manager if it exists to recreate at correct z-level
    if (_positionMarkerManager != null) {
      try {
        await _mapboxMap!.annotations.removeAnnotationManager(_positionMarkerManager!);
        debugPrint('📍 Removed old position marker manager for z-order fix');
      } catch (e) {
        debugPrint('⚠️ Failed to remove old position marker manager: $e');
      }
      _positionMarkerManager = null;
      _positionMarker = null;
    }

    // Create new annotation manager - this will be on top of all current layers
    _positionMarkerManager = await _mapboxMap!.annotations.createCircleAnnotationManager();
    debugPrint('📍 Position marker manager created (on top of overlays)');

    // Update marker to current position
    await _updatePositionMarker(playbackState.currentPosition);
  }

  /// Load planned route from database or snapshot
  Future<void> _loadPlannedRoute(String routeId) async {
    try {
      debugPrint('📍 SessionPlayback: Loading planned route: $routeId');
      final routePlanner = route_service.RoutePlanningService();
      await routePlanner.loadRoutes();

      route_service.PlannedRoute? route;
      try {
        route = routePlanner.savedRoutes.firstWhere(
          (route_service.PlannedRoute r) => r.id == routeId,
        );
        debugPrint('✅ SessionPlayback: Found route in database: ${route.name}');
      } catch (e) {
        debugPrint('⚠️ SessionPlayback: Route not found in database, checking snapshot...');

        // Route not found in database, try to load from session snapshot
        if (widget.session.plannedRouteSnapshot != null) {
          try {
            final snapshotData = jsonDecode(widget.session.plannedRouteSnapshot!);
            route = route_service.PlannedRoute.fromDatabaseMap(snapshotData as Map<String, dynamic>);
            debugPrint('✅ SessionPlayback: Restored route from snapshot: ${route.name} (${route.routePoints.length} points)');
          } catch (snapshotError) {
            debugPrint('❌ SessionPlayback: Failed to deserialize route snapshot: $snapshotError');
          }
        }
      }

      if (route != null && mounted) {
        setState(() {
          _plannedRoute = route;
        });
        debugPrint('✅ SessionPlayback: Loaded planned route: ${route.name} (${route.routePoints.length} points)');
      } else if (mounted) {
        debugPrint('❌ SessionPlayback: Could not load route from database or snapshot');
      }
    } catch (e) {
      debugPrint('❌ SessionPlayback: Failed to load planned route: $e');
    }
  }

  void _onWaypointTapped(Waypoint waypoint) {
    // Jump to waypoint in playback
    ref
        .read(playbackControllerProvider(widget.session).notifier)
        .jumpToWaypoint(waypoint.id);

    // Handle different waypoint types
    switch (waypoint.type) {
      case WaypointType.photo:
        // Photos are now handled via CustomMarker attachments (PlaybackMedia)
        // Find matching PlaybackMedia by timestamp
        final playbackState = ref.read(playbackControllerProvider(widget.session));
        final mediaList = playbackState.playbackMedia;
        if (mediaList.isNotEmpty) {
          // Find media closest to this waypoint's timestamp
          PlaybackMedia? matchingMedia;
          for (final media in mediaList) {
            final timeDiff = media.createdAt.difference(waypoint.timestamp).inSeconds.abs();
            if (timeDiff < 5) {
              matchingMedia = media;
              break;
            }
          }
          if (matchingMedia != null) {
            final index = mediaList.indexOf(matchingMedia);
            _showFullscreenMedia(context, matchingMedia, mediaList, index);
          }
        }
      case WaypointType.note:
        _showNoteWaypointDetail(waypoint);
      default:
        // For other waypoints, just jump to location (already done above)
        break;
    }
  }

  /// Show note waypoint detail in bottom sheet with edit capability
  void _showNoteWaypointDetail(Waypoint waypoint) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Track current waypoint state for updates
    Waypoint currentWaypoint = waypoint;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[600] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header with edit button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BCD4).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.sticky_note_2,
                        color: Color(0xFF00BCD4),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentWaypoint.name ?? 'Note',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatNoteDateTime(currentWaypoint.timestamp),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Edit button
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit Note',
                      onPressed: () => _showEditNoteSheet(
                        context,
                        currentWaypoint,
                        onSaved: (updatedWaypoint) {
                          setSheetState(() {
                            currentWaypoint = updatedWaypoint;
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Note content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (currentWaypoint.notes != null && currentWaypoint.notes!.isNotEmpty) ...[
                        Text(
                          currentWaypoint.notes!,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ] else ...[
                        Text(
                          'No note content',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Location info
                      if (currentWaypoint.coordinates.latitude != 0 ||
                          currentWaypoint.coordinates.longitude != 0) ...[
                        _buildNoteInfoRow(
                          icon: Icons.location_on,
                          label: 'Location',
                          value:
                              '${currentWaypoint.coordinates.latitude.toStringAsFixed(6)}, ${currentWaypoint.coordinates.longitude.toStringAsFixed(6)}',
                          isDark: isDark,
                        ),
                      ],
                      if (currentWaypoint.altitude != null) ...[
                        const SizedBox(height: 8),
                        _buildNoteInfoRow(
                          icon: Icons.terrain,
                          label: 'Altitude',
                          value: '${currentWaypoint.altitude!.toStringAsFixed(1)} m',
                          isDark: isDark,
                        ),
                      ],
                      if (currentWaypoint.accuracy != null) ...[
                        const SizedBox(height: 8),
                        _buildNoteInfoRow(
                          icon: Icons.gps_fixed,
                          label: 'Accuracy',
                          value: currentWaypoint.accuracyDescription,
                          isDark: isDark,
                        ),
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

  /// Show edit note bottom sheet
  void _showEditNoteSheet(
    BuildContext context,
    Waypoint waypoint, {
    required void Function(Waypoint updatedWaypoint) onSaved,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: waypoint.notes ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
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
                  Text(
                    'Edit Note',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final newNote = controller.text.trim();
                      Navigator.pop(context);
                      await _saveNoteWaypoint(
                        waypoint,
                        newNote.isEmpty ? null : newNote,
                        onSaved: onSaved,
                      );
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
                maxLines: 6,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Add details to your note...',
                  hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
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

  /// Save updated note waypoint
  Future<void> _saveNoteWaypoint(
    Waypoint waypoint,
    String? newNote, {
    required void Function(Waypoint updatedWaypoint) onSaved,
  }) async {
    try {
      final waypointService = ref.read(waypointServiceProvider);
      final updatedWaypoint = waypoint.copyWith(notes: newNote);

      await waypointService.updateWaypoint(updatedWaypoint);

      // Notify callback to update UI
      onSaved(updatedWaypoint);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note saved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildNoteInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  String _formatNoteDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final amPm = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$displayHour:$minute $amPm';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    }
  }
}

/// Fullscreen viewer for PlaybackMedia items with swipe navigation
class _PlaybackMediaViewer extends StatefulWidget {
  const _PlaybackMediaViewer({
    required this.media,
    required this.allMedia,
    required this.initialIndex,
    this.onMediaChanged,
    this.onRotationChanged,
  });

  final PlaybackMedia media;
  final List<PlaybackMedia> allMedia;
  final int initialIndex;
  final void Function(PlaybackMedia)? onMediaChanged;
  final void Function(String mediaId, int rotation)? onRotationChanged;

  @override
  State<_PlaybackMediaViewer> createState() => _PlaybackMediaViewerState();
}

class _PlaybackMediaViewerState extends State<_PlaybackMediaViewer> {
  late PageController _pageController;
  late int _currentIndex;

  /// Track rotation for each image by media ID (from MarkerAttachment.id)
  /// Values are 0-3 representing quarter turns (0=0°, 1=90°CW, 2=180°, 3=270°CW)
  final Map<String, int> _rotations = {};

  final MarkerAttachmentService _attachmentService = MarkerAttachmentService();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadRotations();
  }

  Future<void> _loadRotations() async {
    // Load rotations from the database for all media items
    for (final media in widget.allMedia) {
      try {
        final attachment = await _attachmentService.getAttachment(media.id);
        if (attachment != null && mounted) {
          setState(() {
            _rotations[media.id] = attachment.userRotation ?? 0;
          });
        }
      } catch (e) {
        debugPrint('Failed to load rotation for ${media.id}: $e');
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  PlaybackMedia get _currentMedia => widget.allMedia[_currentIndex];

  Future<void> _rotateLeft() async {
    HapticFeedback.lightImpact();
    final mediaId = _currentMedia.id;
    final currentRotation = _rotations[mediaId] ?? 0;
    // Rotate counter-clockwise: 0 -> 3 -> 2 -> 1 -> 0
    final newRotation = (currentRotation - 1 + 4) % 4;

    setState(() {
      _rotations[mediaId] = newRotation;
    });

    // Save to database
    await _saveRotation(mediaId, newRotation);
  }

  Future<void> _rotateRight() async {
    HapticFeedback.lightImpact();
    final mediaId = _currentMedia.id;
    final currentRotation = _rotations[mediaId] ?? 0;
    // Rotate clockwise: 0 -> 1 -> 2 -> 3 -> 0
    final newRotation = (currentRotation + 1) % 4;

    setState(() {
      _rotations[mediaId] = newRotation;
    });

    // Save to database
    await _saveRotation(mediaId, newRotation);
  }

  Future<void> _saveRotation(String attachmentId, int rotation) async {
    try {
      await _attachmentService.updateAttachmentRotation(attachmentId, rotation);
      // Notify parent so thumbnail updates immediately
      widget.onRotationChanged?.call(attachmentId, rotation);
    } catch (e) {
      debugPrint('Error saving rotation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save rotation')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.allMedia.length}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          // Rotate left button
          IconButton(
            icon: const Icon(Icons.rotate_left, color: Colors.white),
            onPressed: _rotateLeft,
            tooltip: 'Rotate left',
          ),
          // Rotate right button
          IconButton(
            icon: const Icon(Icons.rotate_right, color: Colors.white),
            onPressed: _rotateRight,
            tooltip: 'Rotate right',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Image page view
          PageView.builder(
            controller: _pageController,
            itemCount: widget.allMedia.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              widget.onMediaChanged?.call(widget.allMedia[index]);
            },
            itemBuilder: (context, index) {
              final media = widget.allMedia[index];
              final rotation = _rotations[media.id] ?? 0;

              Widget imageWidget = Image.file(
                File(media.filePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load image',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              );

              // Apply rotation if needed
              if (rotation != 0) {
                imageWidget = RotatedBox(
                  quarterTurns: rotation,
                  child: imageWidget,
                );
              }

              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(child: imageWidget),
              );
            },
          ),

          // Bottom info panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Marker name and category
                  Row(
                    children: [
                      if (widget.allMedia[_currentIndex].categoryEmoji != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            widget.allMedia[_currentIndex].categoryEmoji!,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          widget.allMedia[_currentIndex].displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Timestamp
                  Text(
                    _formatDateTime(widget.allMedia[_currentIndex].createdAt),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Location
                  Text(
                    '${widget.allMedia[_currentIndex].latitude.toStringAsFixed(6)}, '
                    '${widget.allMedia[_currentIndex].longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
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

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} at $displayHour:$minute $amPm';
  }
}
