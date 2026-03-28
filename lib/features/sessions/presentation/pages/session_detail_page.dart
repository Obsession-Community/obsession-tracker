import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/mapbox_config.dart';
import 'package:obsession_tracker/core/models/marker_attachment.dart';
import 'package:obsession_tracker/core/models/playback_media.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/custom_marker_service.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/internationalization_service.dart';
import 'package:obsession_tracker/core/services/marker_attachment_service.dart';
import 'package:obsession_tracker/core/services/route_planning_service.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/breadcrumb_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/mapbox_map_widget.dart';
import 'package:obsession_tracker/features/sessions/presentation/pages/session_playback_page.dart';
import 'package:obsession_tracker/features/sessions/presentation/widgets/session_export_menu.dart';

/// Session detail page showing full session information with prominent Play Session button.
///
/// This page serves as the entry point to the session playback feature,
/// displaying session metadata, photos, waypoints, and export options.
class SessionDetailPage extends ConsumerStatefulWidget {
  const SessionDetailPage({
    required this.session,
    super.key,
  });

  final TrackingSession session;

  @override
  ConsumerState<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends ConsumerState<SessionDetailPage> {
  PlannedRoute? _plannedRoute;

  // Cached overlay instances
  BreadcrumbOverlay? _cachedBreadcrumbOverlay;
  BreadcrumbOverlay? _cachedPlannedRouteOverlay;

  // Cached future for breadcrumbs to prevent FutureBuilder from restarting
  late final Future<List<Breadcrumb>> _breadcrumbsFuture;

  // Cached future for PlaybackMedia (new system) to prevent FutureBuilder from restarting
  late final Future<List<PlaybackMedia>> _playbackMediaFuture;

  // Calculated distance from breadcrumbs (more accurate than stored value)
  double? _calculatedDistanceMeters;

  // Key to force FutureBuilder rebuild when waypoints are updated
  final int _waypointsKey = 0;

  /// Track rotations locally for thumbnails (updated when viewer changes rotation)
  final Map<String, int> _rotations = {};

  @override
  void initState() {
    super.initState();
    _breadcrumbsFuture = DatabaseService().getBreadcrumbsForSession(widget.session.id);

    // Load PlaybackMedia from custom markers (new system)
    _playbackMediaFuture = _loadPlaybackMediaForSession();

    // Calculate distance from breadcrumbs when they load
    _breadcrumbsFuture.then((breadcrumbs) {
      if (breadcrumbs.length >= 2) {
        double distance = 0.0;
        for (int i = 1; i < breadcrumbs.length; i++) {
          distance += breadcrumbs[i - 1].distanceTo(breadcrumbs[i]);
        }
        if (mounted) {
          setState(() {
            _calculatedDistanceMeters = distance;
          });
        }
      }
    });

    // Load planned route if session has one
    if (widget.session.plannedRouteId != null) {
      _loadPlannedRoute(widget.session.plannedRouteId!);
    }
  }

  /// Load PlaybackMedia from CustomMarker attachments for this session
  Future<List<PlaybackMedia>> _loadPlaybackMediaForSession() async {
    final markerService = CustomMarkerService();
    final attachmentService = MarkerAttachmentService();

    final customMarkers = await markerService.getMarkersForSession(widget.session.id);
    final List<PlaybackMedia> allMedia = [];

    for (final marker in customMarkers) {
      final attachments = await attachmentService.getAttachmentsForMarker(marker.id);
      // Filter to only image attachments
      final imageAttachments = attachments
          .where((a) => a.type == MarkerAttachmentType.image)
          .toList();

      for (final attachment in imageAttachments) {
        final media = PlaybackMedia.tryFromMarkerAttachment(attachment, marker);
        if (media != null) {
          allMedia.add(media);
          // Cache the rotation for thumbnail display
          if (attachment.userRotation != null && attachment.userRotation != 0) {
            _rotations[media.id] = attachment.userRotation!;
          }
        }
      }
    }

    // Sort chronologically
    allMedia.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return allMedia;
  }

  @override
  void dispose() {
    _cachedBreadcrumbOverlay = null;
    _cachedPlannedRouteOverlay = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareSession,
            tooltip: 'Share Session',
          ),
        ],
      ),
      body: FutureBuilder<List<Waypoint>>(
        key: ValueKey(_waypointsKey),
        future: DatabaseService().getWaypointsForSession(widget.session.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading waypoints: ${snapshot.error}'));
          }
          return _buildContent(context, snapshot.data ?? []);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Waypoint> waypoints) {
    // Filter out photo-type waypoints as photos are now shown via PlaybackMedia
    final otherWaypoints = waypoints.where((w) => w.type != WaypointType.photo).toList();

    return Stack(
      children: [
        // Main scrollable content
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Static map preview (placeholder for now)
          _buildMapPreview(context),

          const SizedBox(height: 16),

          // Statistics cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildStatisticsCards(context),
          ),

          const SizedBox(height: 24),

          // BIG Play Session button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _launchPlayback,
                icon: const Icon(Icons.play_circle, size: 28),
                label: const Text(
                  'Play Session',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Session info
          if (widget.session.description != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.session.description!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

          // Photos section - uses PlaybackMedia from custom markers
          FutureBuilder<List<PlaybackMedia>>(
            future: _playbackMediaFuture,
            builder: (context, mediaSnapshot) {
              final playbackMedia = mediaSnapshot.data ?? [];

              if (playbackMedia.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Text(
                          'Photos',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${playbackMedia.length}',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPlaybackMediaGrid(context, playbackMedia),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),

          // Other waypoints section
          if (otherWaypoints.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text(
                    'Waypoints',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${otherWaypoints.length}',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildWaypointList(context, otherWaypoints),
            const SizedBox(height: 24),
          ],

              // Session metadata
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildSessionMetadata(context),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapPreview(BuildContext context) {
    // Simple track preview - no land data, just breadcrumb trail and planned route
    // For full map experience, use "Play Session" button
    return FutureBuilder<List<Breadcrumb>>(
      future: _breadcrumbsFuture, // Use cached future to prevent FutureBuilder restart
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 200,
            color: Colors.grey.shade200,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            height: 200,
            color: Colors.grey.shade200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No route data available',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        final breadcrumbs = snapshot.data!;

        // Convert breadcrumbs to geo.Position format for overlay
        final geoBreadcrumbs = breadcrumbs
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

        // Calculate bounds to fit only the actual breadcrumbs (track walked)
        // Don't include planned route - we want to zoom to what was actually tracked
        final lats = breadcrumbs.map((b) => b.coordinates.latitude).toList();
        final lons = breadcrumbs.map((b) => b.coordinates.longitude).toList();

        final minLat = lats.reduce((a, b) => a < b ? a : b);
        final maxLat = lats.reduce((a, b) => a > b ? a : b);
        final minLon = lons.reduce((a, b) => a < b ? a : b);
        final maxLon = lons.reduce((a, b) => a > b ? a : b);

        final centerLat = (minLat + maxLat) / 2;
        final centerLon = (minLon + maxLon) / 2;

        // Calculate zoom to fit bounds in a 200px tall container
        // Container is roughly 2:1 aspect ratio (wider than tall)
        final latDiff = maxLat - minLat;
        final lonDiff = maxLon - minLon;

        // Add 30% padding to bounds on all sides
        final paddedLatDiff = latDiff * 1.6; // 30% each side = 1.6x total
        final paddedLonDiff = lonDiff * 1.6;

        // Use the dimension that requires more zoom-out
        // Account for container being wider than tall (~2:1 aspect ratio)
        // Latitude needs more consideration since container is short
        final effectiveDiff = paddedLatDiff > (paddedLonDiff / 2)
            ? paddedLatDiff
            : paddedLonDiff / 2;

        // Calculate zoom from the effective bounds difference
        // Using log2 relationship: each zoom level doubles the view
        double zoom;
        if (effectiveDiff > 0.5) {
          zoom = 7.0;
        } else if (effectiveDiff > 0.2) {
          zoom = 8.0;
        } else if (effectiveDiff > 0.1) {
          zoom = 9.0;
        } else if (effectiveDiff > 0.05) {
          zoom = 10.0;
        } else if (effectiveDiff > 0.02) {
          zoom = 11.0;
        } else if (effectiveDiff > 0.01) {
          zoom = 12.0;
        } else if (effectiveDiff > 0.005) {
          zoom = 13.0;
        } else if (effectiveDiff > 0.002) {
          zoom = 14.0;
        } else {
          zoom = 15.0;
        }

        // Build overlay configs - simple track preview only
        final overlays = <MapOverlayConfig>[
          // Planned route overlay (show below breadcrumbs)
          if (_plannedRoute != null)
            MapOverlayConfig(
              type: MapOverlayType.plannedRoute,
              data: _getPlannedRouteOverlay(_plannedRoute!),
              zIndex: 1,
            ),

          // Breadcrumb trail overlay
          if (geoBreadcrumbs.isNotEmpty)
            MapOverlayConfig(
              type: MapOverlayType.breadcrumbTrail,
              data: _getBreadcrumbOverlay(geoBreadcrumbs),
              zIndex: 1,
            ),
        ];

        return GestureDetector(
          onTap: _launchPlayback,
          child: SizedBox(
            height: 200,
            child: MapboxMapWidget(
              key: ValueKey('session_detail_map_${widget.session.id}'),
              config: MapboxPresets.sessionPlayback.copyWith(
                initialCenter: Point(coordinates: Position(centerLon, centerLat)),
                initialZoom: zoom,
                gesturesEnabled: false, // Make it static/non-interactive
                enableRotation: false,
                showCompass: false,
                showScaleBar: false,
                showAttribution: false,
                showMapControls: false,
                showCurrentLocation: false, // No location puck in preview
              ),
              overlays: overlays,
              // No callbacks needed - this is a static preview
            ),
          ),
        );
      },
    );
  }

  /// Get formatted distance - uses calculated distance from breadcrumbs if available
  String get _formattedDistance {
    // Prefer calculated distance from actual breadcrumbs (more accurate)
    if (_calculatedDistanceMeters != null && _calculatedDistanceMeters! > 0) {
      return InternationalizationService().formatDistance(_calculatedDistanceMeters!);
    }
    // Fall back to stored session distance
    return widget.session.formattedDistance;
  }

  Widget _buildStatisticsCards(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.straighten,
            label: 'Distance',
            value: _formattedDistance,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.schedule,
            label: 'Duration',
            value: widget.session.formattedDuration,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.timeline,
            label: 'Points',
            value: '${widget.session.breadcrumbCount}',
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build photo grid for PlaybackMedia (from CustomMarker attachments)
  Widget _buildPlaybackMediaGrid(BuildContext context, List<PlaybackMedia> media) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final item = media[index];
        final file = File(item.thumbnailPath ?? item.filePath);
        final rotation = _rotations[item.id] ?? 0;

        return GestureDetector(
          onTap: () => _openPlaybackMediaViewer(context, item, media, index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Photo thumbnail with rotation
                if (file.existsSync())
                  rotation != 0
                      ? RotatedBox(
                          quarterTurns: rotation,
                          child: Image.file(
                            file,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => ColoredBox(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        )
                      : Image.file(
                          file,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => ColoredBox(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.broken_image),
                          ),
                        )
                else
                  ColoredBox(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.photo),
                  ),
                // Category emoji badge
                if (item.categoryEmoji != null)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.categoryEmoji!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                // Photo number badge
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Open fullscreen viewer for PlaybackMedia
  void _openPlaybackMediaViewer(
    BuildContext context,
    PlaybackMedia media,
    List<PlaybackMedia> allMedia,
    int index,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SessionMediaViewer(
          media: media,
          allMedia: allMedia,
          initialIndex: index,
          onRotationChanged: (mediaId, rotation) {
            // Update local rotation cache so thumbnails reflect the change
            setState(() {
              if (rotation == 0) {
                _rotations.remove(mediaId);
              } else {
                _rotations[mediaId] = rotation;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildWaypointList(BuildContext context, List<Waypoint> waypoints) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: waypoints.length,
      itemBuilder: (context, index) {
        final waypoint = waypoints[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(_getWaypointIcon(waypoint.type)),
            title: Text(waypoint.name ?? 'Waypoint ${index + 1}'),
            subtitle: waypoint.notes != null
                ? Text(waypoint.notes!)
                : null,
            trailing: Text(
              DateFormat('h:mm a').format(waypoint.timestamp),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSessionMetadata(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildMetadataRow(context, 'Started', DateFormat('MMM d, y • h:mm a').format(widget.session.startedAt ?? widget.session.createdAt)),
            if (widget.session.completedAt != null)
              _buildMetadataRow(context, 'Completed', DateFormat('MMM d, y • h:mm a').format(widget.session.completedAt!)),
            _buildMetadataRow(context, 'Status', _getStatusText(widget.session.status)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  IconData _getWaypointIcon(WaypointType type) {
    switch (type) {
      // Personal Markers
      case WaypointType.treasure:
        return Icons.stars;
      case WaypointType.custom:
        return Icons.location_pin;
      case WaypointType.photo:
        return Icons.photo_camera;
      case WaypointType.note:
        return Icons.sticky_note_2;
      case WaypointType.voice:
        return Icons.mic;
      case WaypointType.favorite:
        return Icons.favorite;
      case WaypointType.memory:
        return Icons.auto_awesome;
      case WaypointType.goal:
        return Icons.flag;
      // Outdoor Activities
      case WaypointType.hiking:
        return Icons.hiking;
      case WaypointType.climbing:
        return Icons.terrain;
      case WaypointType.camp:
        return Icons.cabin;
      case WaypointType.fishing:
        return Icons.phishing;
      case WaypointType.hunting:
        return Icons.gps_fixed;
      case WaypointType.cycling:
        return Icons.pedal_bike;
      case WaypointType.kayaking:
        return Icons.kayaking;
      case WaypointType.skiing:
        return Icons.downhill_skiing;
      // Points of Interest
      case WaypointType.interest:
        return Icons.place;
      case WaypointType.viewpoint:
        return Icons.panorama;
      case WaypointType.landmark:
        return Icons.account_balance;
      case WaypointType.waterfall:
        return Icons.water;
      case WaypointType.cave:
        return Icons.dark_mode;
      case WaypointType.bridge:
        return Icons.architecture;
      case WaypointType.ruins:
        return Icons.castle;
      case WaypointType.wildlife:
        return Icons.pets;
      case WaypointType.flora:
        return Icons.eco;
      // Facilities & Services
      case WaypointType.parking:
        return Icons.local_parking;
      case WaypointType.restroom:
        return Icons.wc;
      case WaypointType.shelter:
        return Icons.house;
      case WaypointType.waterSource:
        return Icons.water_drop;
      case WaypointType.fuelStation:
        return Icons.local_gas_station;
      case WaypointType.restaurant:
        return Icons.restaurant;
      case WaypointType.lodging:
        return Icons.hotel;
      // Safety & Navigation
      case WaypointType.warning:
        return Icons.warning;
      case WaypointType.danger:
        return Icons.dangerous;
      case WaypointType.emergency:
        return Icons.emergency;
      case WaypointType.firstAid:
        return Icons.medical_services;
    }
  }

  String _getStatusText(SessionStatus status) {
    switch (status) {
      case SessionStatus.active:
        return 'Active';
      case SessionStatus.paused:
        return 'Paused';
      case SessionStatus.completed:
        return 'Completed';
      case SessionStatus.cancelled:
        return 'Cancelled';
    }
  }

  Future<void> _launchPlayback() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SessionPlaybackPage(session: widget.session),
      ),
    );
    // Refresh rotations when returning from playback (user may have rotated images there)
    if (mounted) {
      await _refreshRotationsFromDatabase();
    }
  }

  /// Refresh rotation cache from database (called when returning from playback)
  Future<void> _refreshRotationsFromDatabase() async {
    final attachmentService = MarkerAttachmentService();

    for (final mediaId in _rotations.keys.toList()) {
      try {
        final attachment = await attachmentService.getAttachment(mediaId);
        if (attachment != null && mounted) {
          final newRotation = attachment.userRotation ?? 0;
          if (_rotations[mediaId] != newRotation) {
            setState(() {
              if (newRotation == 0) {
                _rotations.remove(mediaId);
              } else {
                _rotations[mediaId] = newRotation;
              }
            });
          }
        }
      } catch (e) {
        debugPrint('Failed to refresh rotation for $mediaId: $e');
      }
    }

    // Also check for any media that wasn't in _rotations but now has rotation
    try {
      final mediaList = await _playbackMediaFuture;
      for (final media in mediaList) {
        if (!_rotations.containsKey(media.id)) {
          final attachment = await attachmentService.getAttachment(media.id);
          if (attachment != null && attachment.userRotation != null && attachment.userRotation != 0 && mounted) {
            setState(() {
              _rotations[media.id] = attachment.userRotation!;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to check new rotations: $e');
    }
  }

  void _shareSession() {
    SessionExportMenu.show(context, widget.session);
  }

  /// Get or create breadcrumb overlay with caching
  BreadcrumbOverlay _getBreadcrumbOverlay(List<geo.Position> breadcrumbs) {
    debugPrint('📍 Creating breadcrumb overlay with ${breadcrumbs.length} points');
    _cachedBreadcrumbOverlay = BreadcrumbOverlay(
      breadcrumbs: breadcrumbs,
    );
    return _cachedBreadcrumbOverlay!;
  }

  /// Load planned route from database or snapshot
  Future<void> _loadPlannedRoute(String routeId) async {
    try {
      debugPrint('📍 SessionDetail: Loading planned route: $routeId');
      final routeService = RoutePlanningService();
      await routeService.loadRoutes();

      PlannedRoute? route;
      try {
        route = routeService.savedRoutes.firstWhere(
          (r) => r.id == routeId,
        );
        debugPrint('✅ SessionDetail: Found route in database: ${route.name}');
      } catch (e) {
        debugPrint('⚠️ SessionDetail: Route not found in database, checking snapshot...');

        // Route not found in database, try to load from session snapshot
        if (widget.session.plannedRouteSnapshot != null) {
          try {
            final snapshotData = jsonDecode(widget.session.plannedRouteSnapshot!);
            route = PlannedRoute.fromDatabaseMap(snapshotData as Map<String, dynamic>);
            debugPrint('✅ SessionDetail: Restored route from snapshot: ${route.name} (${route.routePoints.length} points)');
          } catch (snapshotError) {
            debugPrint('❌ SessionDetail: Failed to deserialize route snapshot: $snapshotError');
          }
        }
      }

      if (route != null && mounted) {
        setState(() {
          _plannedRoute = route;
        });
        debugPrint('✅ SessionDetail: Loaded planned route: ${route.name} (${route.routePoints.length} points)');
      } else if (mounted) {
        debugPrint('❌ SessionDetail: Could not load route from database or snapshot');
      }
    } catch (e) {
      debugPrint('❌ SessionDetail: Failed to load planned route: $e');
    }
  }

  /// Get or create planned route overlay
  BreadcrumbOverlay _getPlannedRouteOverlay(PlannedRoute route) {
    // Convert route points to geo.Position for breadcrumb overlay
    final positions = route.routePoints.map((point) => geo.Position(
      latitude: point.latitude,
      longitude: point.longitude,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    )).toList();

    _cachedPlannedRouteOverlay = BreadcrumbOverlay(
      breadcrumbs: positions,
      lineColor: const Color(0xFFFF6B35), // Orange color for planned route
      lineWidth: 3.0,
      lineOpacity: 0.7,
      sourceId: 'planned-route-source', // Unique source ID
      layerId: 'planned-route-layer', // Unique layer ID
      overlayId: 'planned-route-overlay', // Unique overlay ID
    );
    return _cachedPlannedRouteOverlay!;
  }
}

/// Fullscreen viewer for PlaybackMedia items in session detail
class _SessionMediaViewer extends StatefulWidget {
  const _SessionMediaViewer({
    required this.media,
    required this.allMedia,
    required this.initialIndex,
    this.onRotationChanged,
  });

  final PlaybackMedia media;
  final List<PlaybackMedia> allMedia;
  final int initialIndex;

  /// Callback when rotation changes - passes (mediaId, newRotation)
  final void Function(String mediaId, int rotation)? onRotationChanged;

  @override
  State<_SessionMediaViewer> createState() => _SessionMediaViewerState();
}

class _SessionMediaViewerState extends State<_SessionMediaViewer> {
  late PageController _pageController;
  late int _currentIndex;

  /// Track rotation for each image by media ID
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
      // Notify parent so thumbnail updates
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
