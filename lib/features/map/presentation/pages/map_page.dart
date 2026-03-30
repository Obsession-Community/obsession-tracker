import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/activity_permissions.dart';
import 'package:obsession_tracker/core/models/comprehensive_land_ownership.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/models/mapbox_config.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/app_settings_provider.dart';
import 'package:obsession_tracker/core/providers/land_ownership_provider.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/core/providers/map_camera_provider.dart';
import 'package:obsession_tracker/core/providers/map_center_land_provider.dart';
import 'package:obsession_tracker/core/providers/map_search_provider.dart';
import 'package:obsession_tracker/core/providers/photo_provider.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/core/providers/waypoint_provider.dart';
import 'package:obsession_tracker/core/services/app_settings_service.dart';
import 'package:obsession_tracker/core/services/map_search_service.dart';
import 'package:obsession_tracker/core/services/offline_land_rights_service.dart';
import 'package:obsession_tracker/core/services/state_download_manager.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/core/widgets/compact_offline_indicator.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/core_map_view.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/custom_marker_creation_sheet.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/maintenance_banner.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/map_controls_sheet.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/map_search_widget.dart';
import 'package:obsession_tracker/features/offline/presentation/pages/land_trail_data_page.dart';
import 'package:obsession_tracker/features/permissions/presentation/widgets/permission_status_banner.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/fullscreen_photo_viewer.dart';

/// Map page displaying Mapbox with real-time location, breadcrumb trail, and waypoints.
///
/// This page provides enhanced map functionality including:
/// - Mapbox Maps SDK integration
/// - Current location display with camera following
/// - Real-time breadcrumb trail rendering
/// - Waypoint creation and management with touch-to-mark functionality
/// - Map controls (zoom, pan, center on location)
/// - Photo capture FAB during active tracking sessions
///
/// Uses [CoreMapView] for shared map functionality (land, trails, historical places,
/// custom markers, overlays, etc.) and adds MapPage-specific UI (search, permission
/// banners, waypoint creation).
class MapPage extends ConsumerStatefulWidget {
  const MapPage({
    super.key,
    this.playbackSession,
  });

  /// Optional session to display in playback mode
  final TrackingSession? playbackSession;

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  // Map reference for MapPage-specific operations (search, centering)
  MapboxMap? _mapboxMap;

  // CoreMapView key for accessing filter panel and refresh
  final GlobalKey<CoreMapViewState> _coreMapKey = GlobalKey<CoreMapViewState>();

  // UI state
  bool _showSearchOverlay = false;
  bool _followUserLocation = true;
  bool _isProgrammaticCameraMove = false;
  bool _hasInitializedFromSettings = false;
  bool _hasInitialCentered = false; // Track if we've centered on first location

  // Current visible bounds for search (updated when camera changes)
  double? _visibleNorth;
  double? _visibleSouth;
  double? _visibleEast;
  double? _visibleWest;

  // Map center tracking for permission banners
  LatLng? _mapCenterLocation;
  String? _currentStateCode;
  bool? _currentStateHasLandData;
  bool _isDownloadingCurrentState = false;
  bool _isBannerDragging = false;
  StateDownloadProgress? _currentDownloadProgress;
  StreamSubscription<DownloadManagerState>? _downloadSubscription;
  StreamSubscription<DownloadManagerState>? _globalDownloadSubscription;
  bool _wasDownloading = false;

  @override
  void initState() {
    super.initState();
    // Listen for download completions globally (regardless of where download was initiated)
    // This ensures the map refreshes when downloads complete from LandTrailDataPage
    _globalDownloadSubscription = StateDownloadManager.instance.stateStream.listen((state) {
      if (_wasDownloading && !state.isDownloading && mounted) {
        debugPrint('📥 MapPage: Global download completed - triggering refresh');
        _coreMapKey.currentState?.forceRefreshMapData();
      }
      _wasDownloading = state.isDownloading;
    });
    // Initialize with current state
    _wasDownloading = StateDownloadManager.instance.state.isDownloading;
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    _globalDownloadSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final waypointState = ref.watch(waypointProvider);
    final landOverlayVisible = ref.watch(landOverlayVisibilityProvider);
    final mapCenterLandState = ref.watch(mapCenterLandProvider);
    final mapSettings = ref.watch(mapSettingsProvider);
    final isPremium = ref.watch(isPremiumProvider);

    // Initialize follow location from saved settings on first build
    // But disable follow mode when in screenshot mode to preserve screenshot center/zoom
    if (!_hasInitializedFromSettings) {
      _hasInitializedFromSettings = true;
      _followUserLocation = !MapboxPresets.screenshotMode && mapSettings.followLocation;
    }

    // Auto-center on user location when:
    // 1. First valid location acquired (one-time, regardless of follow mode)
    // 2. Follow mode is enabled and position changes significantly
    // Works on both mobile (_mapboxMap) and desktop (CoreMapView)
    ref.listen<LocationState>(locationProvider, (previous, next) {
      final mapReady = _mapboxMap != null || _coreMapKey.currentState != null;
      if (next.currentPosition != null && mapReady) {
        final pos = next.currentPosition!;

        // First location acquisition: center once regardless of follow mode
        // Skip in screenshot mode since it uses a fixed center
        if (!_hasInitialCentered && !MapboxPresets.screenshotMode) {
          _hasInitialCentered = true;
          debugPrint('📍 Initial location acquired - centering map on user location');
          _centerOnLocation(pos.latitude, pos.longitude);
          return;
        }

        // Subsequent updates: only recenter if follow mode is enabled
        if (_followUserLocation) {
          // Only recenter if position changed significantly (avoid jitter)
          if (previous?.currentPosition == null ||
              (pos.latitude - previous!.currentPosition!.latitude).abs() > 0.00001 ||
              (pos.longitude - previous.currentPosition!.longitude).abs() > 0.00001) {
            _centerOnLocation(pos.latitude, pos.longitude);
          }
        }
      }
    });

    // Desktop: Listen to camera position changes (since we don't have MapboxMap callbacks)
    final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    if (isDesktop) {
      ref.listen<MapCameraPosition?>(mapCameraPositionProvider, (previous, next) {
        if (next != null) {
          _onDesktopCameraPositionChanged(next);
        }
      });
    }

    final sessionId = widget.playbackSession?.id ?? locationState.activeSession?.id ?? 'default-session';
    final isPlaybackMode = widget.playbackSession != null;

    // Filter waypoints for current session
    final sessionWaypoints = waypointState.waypoints.where((Waypoint wp) => wp.sessionId == sessionId).toList();

    // Get breadcrumbs from location provider
    final breadcrumbs = locationState.currentBreadcrumbs
        .map(
          (b) => geo.Position(
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
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isPlaybackMode ? 'Playback: ${widget.playbackSession!.name}' : 'Map',
        ),
        centerTitle: true,
        actions: <Widget>[
          // Search button
          IconButton(
            icon: Icon(
              Icons.search,
              color: _showSearchOverlay ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () {
              setState(() {
                _showSearchOverlay = !_showSearchOverlay;
              });
            },
            tooltip: 'Search Map',
          ),
          // Land filter button with badge when historical maps available
          if (landOverlayVisible)
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.filter_alt,
                    color: _coreMapKey.currentState?.isFilterPanelVisible == true
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  // Badge indicator when historical maps are available
                  if (_coreMapKey.currentState?.hasAvailableMaps == true)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.purple,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () => _coreMapKey.currentState?.toggleFilterPanel(),
              tooltip: 'Land Type Filters',
            ),
          // Map info button
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showMapInfo,
            tooltip: 'Map Info',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main CoreMapView with all shared map functionality
          CoreMapView(
            key: _coreMapKey,
            config: isPlaybackMode
                ? MapboxPresets.sessionPlayback
                : MapboxPresets.tracking.copyWith(
                    followUserLocation: false,
                    enableTouchToMark: !locationState.isTracking,
                    initialZoom: MapboxPresets.screenshotMode
                        ? (MapboxPresets.screenshotHistoricalMapMode
                            ? MapboxPresets.screenshotHistoricalZoom
                            : MapboxPresets.screenshotZoom)
                        : null,
                    initialCenter: MapboxPresets.screenshotMode
                        ? (MapboxPresets.screenshotHistoricalMapMode
                            ? MapboxPresets.screenshotHistoricalCenter
                            : MapboxPresets.screenshotCenter)
                        : null,
                  ),
            breadcrumbs: breadcrumbs,
            waypoints: sessionWaypoints,
            isTrackingActive: locationState.isTracking,
            showLandRightsBanner: isPremium && mapSettings.showLandRightsBanner,
            hideOverlays: _showSearchOverlay,
            isFollowingLocation: _followUserLocation,
            onMapCreated: _onMapCreated,
            onMapViewChanged: _onMapViewChanged,
            onCameraMovingFast: _onCameraMovingFast,
            onFollowLocationToggle: (isFollowing) {
              debugPrint('🎯 Follow toggle: $isFollowing');
              setState(() {
                _followUserLocation = isFollowing;
              });
              // Persist the follow location setting
              final appSettingsService = ref.read(appSettingsServiceProvider);
              final currentMapSettings = ref.read(mapSettingsProvider);
              appSettingsService.updateMapSettings(
                currentMapSettings.copyWith(followLocation: isFollowing),
              );
              // If enabling follow mode, center on current location immediately
              if (isFollowing) {
                final currentLocation = ref.read(locationProvider);
                final pos = currentLocation.currentPosition;
                if (pos != null) {
                  _centerOnLocation(pos.latitude, pos.longitude);
                }
              }
            },
            onWaypointTap: _onWaypointSelected,
            onMapLongPress: isPlaybackMode ? null : _onMapLongPress,
            onAddWaypoint: locationState.activeSession != null
                ? () => _openMarkerCreation(locationState.activeSession!.id)
                : null,
            onCheckPermissions: isPlaybackMode ? null : _showQuickPermissionCheck,
            onToggleLandRightsBanner: isPremium ? _toggleLandRightsBanner : null,
            onLandDataLoaded: _onLandDataLoaded,
            onFilterPanelVisibilityChanged: (_) => setState(() {}),
          ),

          // Search overlay
          if (_showSearchOverlay)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildSearchOverlay(locationState),
            ),

          // Maintenance mode banner (shows when BFF is under maintenance)
          const Positioned(
            bottom: 160,
            left: 0,
            right: 0,
            child: MaintenanceBanner(),
          ),

          // Permission status banner (shows land rights at map center)
          // Draggable to accommodate other HUD elements
          if (!_showSearchOverlay &&
              _coreMapKey.currentState?.isFilterPanelVisible != true &&
              mapSettings.showLandRightsBanner &&
              isPremium &&
              mapCenterLandState.hasData &&
              mapCenterLandState.property != null)
            Consumer(
              builder: (context, ref, child) {
                final bannerTop = ref.watch(landRightsBannerPositionProvider);
                // Leave space on right for map zoom controls (56px)
                final screenWidth = MediaQuery.of(context).size.width;
                final maxBannerWidth = screenWidth - 16 - 56; // 16px left margin, 56px right for controls
                return Positioned(
                  top: bannerTop,
                  left: 0,
                  right: 56, // Leave room for zoom controls
                  child: SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxBannerWidth,
                        ),
                        child: GestureDetector(
                          onVerticalDragStart: (_) {
                            setState(() => _isBannerDragging = true);
                          },
                          onVerticalDragUpdate: (details) {
                            _updateBannerPosition(context, bannerTop, details.delta.dy, ref);
                          },
                          onVerticalDragEnd: (_) {
                            setState(() => _isBannerDragging = false);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            decoration: _isBannerDragging
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.gold.withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  )
                                : null,
                            child: PermissionStatusBanner(
                              property: mapCenterLandState.property!,
                              compact: true,
                              isMapCenterMode: true,
                              onTap: () {
                                _showPermissionDetails(mapCenterLandState.property!);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          // "Likely Private Property" banner when no land data found
          // Also draggable
          if (!_showSearchOverlay &&
              _coreMapKey.currentState?.isFilterPanelVisible != true &&
              mapSettings.showLandRightsBanner &&
              isPremium &&
              _mapCenterLocation != null &&
              mapCenterLandState.property == null)
            Consumer(
              builder: (context, ref, child) {
                final bannerTop = ref.watch(landRightsBannerPositionProvider);
                // Leave space on right for map zoom controls (56px)
                final screenWidth = MediaQuery.of(context).size.width;
                final maxBannerWidth = screenWidth - 16 - 56; // 16px left margin, 56px right for controls
                return Positioned(
                  top: bannerTop,
                  left: 0,
                  right: 56, // Leave room for zoom controls
                  child: SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxBannerWidth,
                        ),
                        child: GestureDetector(
                          onVerticalDragStart: (_) {
                            setState(() => _isBannerDragging = true);
                          },
                          onVerticalDragUpdate: (details) {
                            _updateBannerPosition(context, bannerTop, details.delta.dy, ref);
                          },
                          onVerticalDragEnd: (_) {
                            setState(() => _isBannerDragging = false);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            decoration: _isBannerDragging
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.gold.withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  )
                                : null,
                            child: _buildPrivatePropertyBanner(),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          // Compact offline indicator (bottom-left corner)
          const Positioned(
            bottom: 100,
            left: 16,
            child: CompactOfflineIndicator(),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // Map callbacks
  // ============================================================================

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    debugPrint('🗺️ MapPage: onMapCreated called');
    _mapboxMap = mapboxMap;
  }

  Future<void> _onMapViewChanged(MapboxMap mapboxMap) async {
    // Disable follow mode when user manually moves the map
    if (_followUserLocation && !_isProgrammaticCameraMove) {
      setState(() {
        _followUserLocation = false;
      });
      // Persist the follow location setting
      final appSettingsService = ref.read(appSettingsServiceProvider);
      final currentMapSettings = ref.read(mapSettingsProvider);
      appSettingsService.updateMapSettings(
        currentMapSettings.copyWith(followLocation: false),
      );
    }
    _isProgrammaticCameraMove = false;

    // Update map center for permission banners
    await _updateMapCenterFromMap(mapboxMap);
  }

  Future<void> _onCameraMovingFast(MapboxMap mapboxMap) async {
    // Lightweight updates during pan
    await _updateMapCenterFromMap(mapboxMap);
  }

  /// Called when CoreMapView finishes loading land data
  /// Re-queries map center to update land rights banner now that overlay has rendered
  void _onLandDataLoaded() {
    if (_mapCenterLocation == null) return;

    final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    if (isDesktop) {
      // Desktop: Update land rights using the loaded parcels
      _updateDesktopMapCenterLandRights(
        _mapCenterLocation!.latitude,
        _mapCenterLocation!.longitude,
      );
    } else if (_mapboxMap != null) {
      // Mobile: Query rendered features
      final center = Point(
        coordinates: Position(_mapCenterLocation!.longitude, _mapCenterLocation!.latitude),
      );
      _updateMapCenterLandRights(
        _mapboxMap!,
        center,
        _mapCenterLocation!.latitude,
        _mapCenterLocation!.longitude,
      );
    }
  }

  Future<void> _updateMapCenterFromMap(MapboxMap mapboxMap) async {
    try {
      final cameraState = await mapboxMap.getCameraState();
      final center = cameraState.center;
      final latitude = center.coordinates.lat.toDouble();
      final longitude = center.coordinates.lng.toDouble();

      // Update visible bounds for search
      final bounds = await mapboxMap.coordinateBoundsForCamera(
        CameraOptions(center: center, zoom: cameraState.zoom),
      );
      _visibleNorth = bounds.northeast.coordinates.lat.toDouble();
      _visibleSouth = bounds.southwest.coordinates.lat.toDouble();
      _visibleEast = bounds.northeast.coordinates.lng.toDouble();
      _visibleWest = bounds.southwest.coordinates.lng.toDouble();

      if (mounted) {
        setState(() {
          _mapCenterLocation = LatLng(latitude, longitude);
        });
        _updateStateDataStatus(latitude, longitude);

        // Update land rights banner by querying land at map center
        await _updateMapCenterLandRights(mapboxMap, center, latitude, longitude);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to update map center: $e');
    }
  }

  /// Update land rights display for the current map center
  /// Uses Mapbox's queryRenderedFeatures for accurate polygon detection (including holes)
  Future<void> _updateMapCenterLandRights(
    MapboxMap mapboxMap,
    Point center,
    double latitude,
    double longitude,
  ) async {
    try {
      // Convert map center to screen coordinates for Mapbox query
      final screenCoord = await mapboxMap.pixelForCoordinate(center);

      // Query Mapbox for land ownership features at the map center
      // This correctly handles polygon holes (unlike custom point-in-polygon)
      ComprehensiveLandOwnership? containingProperty;
      try {
        final features = await mapboxMap.queryRenderedFeatures(
          RenderedQueryGeometry.fromScreenCoordinate(screenCoord),
          RenderedQueryOptions(layerIds: ['land-ownership-fill-layer']),
        );

        if (features.isNotEmpty && features.first != null) {
          final featureId = features.first!.queriedFeature.feature['id'];
          if (featureId != null) {
            // Find the parcel matching this feature ID from CoreMapView's land data
            // Feature IDs may have _part_N suffix from MultiPolygon splitting
            final baseParcelId = _extractBaseParcelId(featureId.toString());
            final landParcels = _coreMapKey.currentState?.landParcels ?? [];
            try {
              final matchingParcel = landParcels.firstWhere(
                (p) => p.id == baseParcelId,
              );
              // Convert to ComprehensiveLandOwnership for the banner
              containingProperty = ComprehensiveLandOwnership.fromLandOwnership(matchingParcel);
              debugPrint('🎯 Map center: Found ${matchingParcel.ownerName} via Mapbox query');
            } catch (e) {
              // Feature ID not found in current parcels (stale render)
              debugPrint('⚠️ Map center: Feature ID $featureId not found in current parcels');
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Mapbox query failed: $e');
      }

      // Update the provider with the found property (or null if none)
      ref.read(mapCenterLandProvider.notifier).setProperty(
            containingProperty,
            latitude: latitude,
            longitude: longitude,
          );
    } catch (e) {
      debugPrint('⚠️ Failed to update map center land rights: $e');
    }
  }

  /// Extract base parcel ID from composite feature ID
  /// MultiPolygon parcels have IDs like "parcel_123_part_0" - extract "parcel_123"
  String _extractBaseParcelId(String featureId) {
    final partIndex = featureId.lastIndexOf('_part_');
    if (partIndex > 0) {
      return featureId.substring(0, partIndex);
    }
    return featureId;
  }

  /// Handle camera position changes on desktop (since we don't have MapboxMap callbacks)
  void _onDesktopCameraPositionChanged(MapCameraPosition cameraPos) {
    final latitude = cameraPos.latitude;
    final longitude = cameraPos.longitude;

    // Update map center location for banners
    if (mounted) {
      setState(() {
        _mapCenterLocation = LatLng(latitude, longitude);
      });
      _updateStateDataStatus(latitude, longitude);

      // Update land rights using point-in-polygon check against loaded parcels
      _updateDesktopMapCenterLandRights(latitude, longitude);
    }
  }

  /// Update land rights on desktop using point-in-polygon check
  /// Since we don't have Mapbox's queryRenderedFeatures, we check against loaded parcels
  void _updateDesktopMapCenterLandRights(double latitude, double longitude) {
    final landParcels = _coreMapKey.currentState?.landParcels ?? [];
    LandOwnership? bestMatch;
    double bestMatchArea = double.infinity;

    // Create a point from the coordinates
    final point = LandPoint(latitude: latitude, longitude: longitude);

    debugPrint('🎯 Desktop land check: Point ($latitude, $longitude), checking ${landParcels.length} parcels');

    // Find the smallest parcel that actually contains the point
    int boundsPassed = 0;
    int polygonPassed = 0;
    for (final parcel in landParcels) {
      // Quick bounding box check first (fast rejection)
      if (!parcel.bounds.contains(point)) continue;
      boundsPassed++;

      // Actual point-in-polygon check
      if (_isPointInParcel(latitude, longitude, parcel)) {
        polygonPassed++;
        // Calculate approximate area from bounding box to prefer smaller parcels
        final area = (parcel.bounds.north - parcel.bounds.south) *
            (parcel.bounds.east - parcel.bounds.west);

        if (area < bestMatchArea) {
          bestMatch = parcel;
          bestMatchArea = area;
        }
      }
    }

    debugPrint('🎯 Desktop land check: $boundsPassed passed bounds, $polygonPassed passed polygon');
    if (bestMatch != null) {
      debugPrint('🎯 Desktop map center: Found ${bestMatch.ownerName} (area: ${bestMatchArea.toStringAsFixed(4)}°²)');
    } else {
      debugPrint('🎯 Desktop map center: No match found - showing Private Property fallback');
    }

    // Update the provider with the found property (or null if none)
    ref.read(mapCenterLandProvider.notifier).setProperty(
          bestMatch != null
              ? ComprehensiveLandOwnership.fromLandOwnership(bestMatch)
              : null,
          latitude: latitude,
          longitude: longitude,
        );
  }

  /// Check if a point is inside a parcel's polygon using ray casting algorithm
  ///
  /// NOTE: The polygon data treats each ring as a SEPARATE polygon part
  /// (like different sections of a national forest), NOT as exterior + holes.
  /// This matches how _splitMultiPolygonCoordinates works in land_ownership_overlay.dart
  bool _isPointInParcel(double lat, double lng, LandOwnership parcel) {
    final coords = parcel.polygonCoordinates;
    if (coords == null || coords.isEmpty) return false;

    // Check if point is in ANY of the rings (each ring is a separate polygon part)
    // This handles MultiPolygon-style data where each ring is an exterior boundary
    for (final ring in coords) {
      if (_isPointInRing(lat, lng, ring)) {
        return true;
      }
    }

    return false;
  }

  /// Ray casting algorithm to check if point is inside a polygon ring
  /// Coordinates are in GeoJSON format: [longitude, latitude]
  bool _isPointInRing(double lat, double lng, List<List<double>> ring) {
    if (ring.length < 3) return false;

    var inside = false;
    var j = ring.length - 1;

    for (var i = 0; i < ring.length; i++) {
      final xi = ring[i][0]; // longitude
      final yi = ring[i][1]; // latitude
      final xj = ring[j][0];
      final yj = ring[j][1];

      if (((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  // ============================================================================
  // Search
  // ============================================================================

  Widget _buildSearchOverlay(LocationState locationState) {
    final searchService = ref.watch(mapSearchServiceProvider);
    final position = locationState.currentPosition;

    return MapSearchWidget(
      searchService: searchService,
      proximityLat: position?.latitude,
      proximityLon: position?.longitude,
      northBound: _visibleNorth,
      southBound: _visibleSouth,
      eastBound: _visibleEast,
      westBound: _visibleWest,
      onResultSelected: _onSearchResultSelected,
      onClose: () {
        setState(() {
          _showSearchOverlay = false;
        });
      },
    );
  }

  Future<void> _onSearchResultSelected(MapSearchResult result) async {
    debugPrint('🔍 Search result selected: ${result.displayName}');

    // Coordinates should be present after retrieval
    final lat = result.latitude;
    final lon = result.longitude;
    if (lat == null || lon == null) return;

    // Calculate appropriate zoom level based on bounding box
    double zoom = 14.0;
    if (result.bbox != null && result.bbox!.length == 4) {
      final bbox = result.bbox!;
      final latDiff = (bbox[3] - bbox[1]).abs();
      final lonDiff = (bbox[2] - bbox[0]).abs();
      final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;

      if (maxDiff > 10) {
        zoom = 8.0;
      } else if (maxDiff > 1) {
        zoom = 10.0;
      } else if (maxDiff > 0.1) {
        zoom = 12.0;
      } else if (maxDiff > 0.01) {
        zoom = 14.0;
      } else {
        zoom = 15.0;
      }
    }

    // Use CoreMapView's centerOnLocation which works on both mobile and desktop
    final coreMapState = _coreMapKey.currentState;
    if (coreMapState != null) {
      await coreMapState.centerOnLocation(lat, lon, zoom: zoom);
    } else if (_mapboxMap != null) {
      // Fallback for mobile if CoreMapView not ready yet
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(lon, lat)),
          zoom: zoom,
        ),
        MapAnimationOptions(duration: 1500),
      );
    }

    setState(() {
      _showSearchOverlay = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigated to: ${result.displayName}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ============================================================================
  // Map actions
  // ============================================================================

  Future<void> _centerOnLocation(double latitude, double longitude) async {
    _isProgrammaticCameraMove = true;

    // Use CoreMapView's centerOnLocation which works on both mobile and desktop
    final coreMapState = _coreMapKey.currentState;
    if (coreMapState != null) {
      await coreMapState.centerOnLocation(latitude, longitude);
      return;
    }

    // Fallback for mobile if CoreMapView not ready yet
    if (_mapboxMap == null) return;
    try {
      await _mapboxMap!.flyTo(
        CameraOptions(center: Point(coordinates: Position(longitude, latitude))),
        MapAnimationOptions(duration: 500),
      );
    } catch (e) {
      debugPrint('⚠️ Failed to center on location: $e');
      _isProgrammaticCameraMove = false;
    }
  }

  void _toggleLandRightsBanner() {
    final currentMapSettings = ref.read(mapSettingsProvider);
    final newValue = !currentMapSettings.showLandRightsBanner;
    AppSettingsService.instance.updateMapSettings(
      currentMapSettings.copyWith(showLandRightsBanner: newValue),
    );
  }

  void _updateBannerPosition(BuildContext context, double currentTop, double deltaY, WidgetRef ref) {
    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;

    // Banner height is approximately 60-80 for compact mode
    const bannerHeight = 80.0;
    // Minimum distance from top (to show status bar)
    final minTop = safeAreaTop + 8.0;
    // Maximum distance from top (leave room for map and bottom controls)
    final maxTop = screenSize.height - bannerHeight - 200;

    // Dragging down increases top offset, dragging up decreases it
    final newTop = (currentTop + deltaY).clamp(minTop, maxTop);

    ref.read(landRightsBannerPositionProvider.notifier).setPosition(newTop);
  }

  // ============================================================================
  // State data status (for download banners)
  // ============================================================================

  Future<void> _updateStateDataStatus(double latitude, double longitude) async {
    final stateCode = _getStateCodeForLocation(latitude, longitude);
    if (stateCode == _currentStateCode) return;

    _currentStateCode = stateCode;

    if (stateCode == null) {
      if (mounted) {
        setState(() {
          _currentStateHasLandData = null;
        });
      }
      return;
    }

    try {
      final downloadedStates = await OfflineLandRightsService().getDownloadedStates();
      final hasData = downloadedStates.any(
        (state) => state.stateCode == stateCode && state.propertyCount > 0,
      );
      if (mounted) {
        setState(() {
          _currentStateHasLandData = hasData;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Failed to check state download status: $e');
    }
  }

  String? _getStateCodeForLocation(double latitude, double longitude) {
    const stateBounds = {
      'AL': {'north': 35.01, 'south': 30.22, 'east': -84.89, 'west': -88.47},
      'AR': {'north': 36.50, 'south': 33.00, 'east': -89.64, 'west': -94.62},
      'AZ': {'north': 37.00, 'south': 31.33, 'east': -109.05, 'west': -114.82},
      'CA': {'north': 42.01, 'south': 32.53, 'east': -114.13, 'west': -124.48},
      'CO': {'north': 41.00, 'south': 36.99, 'east': -102.04, 'west': -109.06},
      'CT': {'north': 42.05, 'south': 40.98, 'east': -71.79, 'west': -73.73},
      'DE': {'north': 39.84, 'south': 38.45, 'east': -75.05, 'west': -75.79},
      'FL': {'north': 31.00, 'south': 24.52, 'east': -80.03, 'west': -87.63},
      'GA': {'north': 35.00, 'south': 30.36, 'east': -80.84, 'west': -85.61},
      'IA': {'north': 43.50, 'south': 40.38, 'east': -90.14, 'west': -96.64},
      'ID': {'north': 49.00, 'south': 41.99, 'east': -111.04, 'west': -117.24},
      'IL': {'north': 42.51, 'south': 36.97, 'east': -87.50, 'west': -91.51},
      'IN': {'north': 41.76, 'south': 37.77, 'east': -84.78, 'west': -88.10},
      'KS': {'north': 40.00, 'south': 36.99, 'east': -94.59, 'west': -102.05},
      'KY': {'north': 39.15, 'south': 36.50, 'east': -81.96, 'west': -89.57},
      'LA': {'north': 33.02, 'south': 28.93, 'east': -88.82, 'west': -94.04},
      'MA': {'north': 42.89, 'south': 41.24, 'east': -69.93, 'west': -73.51},
      'MD': {'north': 39.72, 'south': 37.91, 'east': -75.05, 'west': -79.49},
      'ME': {'north': 47.46, 'south': 43.06, 'east': -66.95, 'west': -71.08},
      'MI': {'north': 48.31, 'south': 41.70, 'east': -82.41, 'west': -90.42},
      'MN': {'north': 49.38, 'south': 43.50, 'east': -89.49, 'west': -97.24},
      'MO': {'north': 40.61, 'south': 35.99, 'east': -89.10, 'west': -95.77},
      'MS': {'north': 35.00, 'south': 30.17, 'east': -88.10, 'west': -91.66},
      'MT': {'north': 49.00, 'south': 44.36, 'east': -104.04, 'west': -116.05},
      'NC': {'north': 36.59, 'south': 33.84, 'east': -75.46, 'west': -84.32},
      'ND': {'north': 49.00, 'south': 45.94, 'east': -96.55, 'west': -104.05},
      'NE': {'north': 43.00, 'south': 40.00, 'east': -95.31, 'west': -104.05},
      'NH': {'north': 45.31, 'south': 42.70, 'east': -70.70, 'west': -72.56},
      'NJ': {'north': 41.36, 'south': 38.93, 'east': -73.89, 'west': -75.56},
      'NM': {'north': 37.00, 'south': 31.33, 'east': -103.00, 'west': -109.05},
      'NV': {'north': 42.00, 'south': 35.00, 'east': -114.04, 'west': -120.00},
      'NY': {'north': 45.02, 'south': 40.50, 'east': -71.86, 'west': -79.76},
      'OH': {'north': 42.33, 'south': 38.40, 'east': -80.52, 'west': -84.82},
      'OK': {'north': 37.00, 'south': 33.62, 'east': -94.43, 'west': -103.00},
      'OR': {'north': 46.29, 'south': 41.99, 'east': -116.46, 'west': -124.57},
      'PA': {'north': 42.27, 'south': 39.72, 'east': -74.69, 'west': -80.52},
      'RI': {'north': 42.02, 'south': 41.15, 'east': -71.12, 'west': -71.86},
      'SC': {'north': 35.22, 'south': 32.03, 'east': -78.54, 'west': -83.35},
      'SD': {'north': 45.95, 'south': 42.48, 'east': -96.44, 'west': -104.06},
      'TN': {'north': 36.68, 'south': 34.98, 'east': -81.65, 'west': -90.31},
      'TX': {'north': 36.50, 'south': 25.84, 'east': -93.51, 'west': -106.65},
      'UT': {'north': 42.00, 'south': 36.99, 'east': -109.05, 'west': -114.05},
      'VA': {'north': 39.47, 'south': 36.54, 'east': -75.24, 'west': -83.68},
      'VT': {'north': 45.02, 'south': 42.73, 'east': -71.46, 'west': -73.44},
      'WA': {'north': 49.00, 'south': 45.54, 'east': -116.92, 'west': -124.73},
      'WI': {'north': 47.31, 'south': 42.49, 'east': -86.25, 'west': -92.89},
      'WV': {'north': 40.64, 'south': 37.20, 'east': -77.72, 'west': -82.64},
      'WY': {'north': 45.01, 'south': 40.99, 'east': -104.05, 'west': -111.05},
      'AK': {'north': 71.50, 'south': 51.21, 'east': -129.99, 'west': -179.15},
    };

    for (final entry in stateBounds.entries) {
      final bounds = entry.value;
      if (latitude <= bounds['north']! &&
          latitude >= bounds['south']! &&
          longitude <= bounds['east']! &&
          longitude >= bounds['west']!) {
        return entry.key;
      }
    }
    return null;
  }

  Widget _buildPrivatePropertyBanner() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bool needsDownload = _currentStateHasLandData == false;
    final bool isDownloading = _isDownloadingCurrentState;

    final String emoji = isDownloading ? '' : (needsDownload ? '📥' : '🏠');

    // Build download message with progress if available
    // Note: progress.message already includes percentage, so don't append it again
    String downloadMessage;
    if (isDownloading && _currentDownloadProgress != null) {
      final progress = _currentDownloadProgress!;
      downloadMessage = '${progress.stateName}: ${progress.message}';
    } else {
      downloadMessage = 'Downloading ${_currentStateCode ?? 'state'} data...';
    }

    final String message = isDownloading
        ? downloadMessage
        : (needsDownload
            ? 'Download ${_currentStateCode ?? 'state'} data for land info'
            : '📍 Likely Private Property');
    final Color borderColor = isDownloading ? Colors.green : (needsDownload ? Colors.blue : Colors.orange);
    final Color? textColor = isDownloading ? Colors.green[800] : (needsDownload ? Colors.blue[800] : Colors.orange[800]);
    final Color bgTint = isDownloading
        ? Colors.green.withValues(alpha: 0.1)
        : (needsDownload
            ? Colors.blue.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1));

    final backgroundColor = isDark ? Colors.black.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.92);

    return GestureDetector(
      onTap: isDownloading ? null : (needsDownload ? _navigateToOfflineData : _showQuickPermissionCheck),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 2.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: bgTint,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              if (isDownloading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor ?? Colors.green),
                  ),
                )
              else
                Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              if (!isDownloading)
                Icon(
                  needsDownload ? Icons.download : Icons.chevron_right,
                  size: 16,
                  color: textColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToOfflineData() async {
    final stateCode = _currentStateCode;
    if (stateCode == null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (context) => const LandTrailDataPage()),
      );
      return;
    }

    if (_isDownloadingCurrentState || StateDownloadManager.instance.state.isDownloading) {
      return;
    }

    setState(() {
      _isDownloadingCurrentState = true;
    });

    await _downloadSubscription?.cancel();

    _downloadSubscription = StateDownloadManager.instance.stateStream.listen((state) {
      if (!mounted) return;

      final progress = state.downloads[stateCode];

      // Update progress for banner display during download
      if (state.isDownloading && progress != null) {
        setState(() {
          _currentDownloadProgress = progress;
        });
        return;
      }

      // Download finished
      final succeeded = progress?.status == StateDownloadStatus.completed;
      debugPrint('📥 MapPage: Download finished - stateCode=$stateCode, status=${progress?.status}, succeeded=$succeeded');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(succeeded ? '$stateCode download complete!' : '$stateCode download failed'),
          backgroundColor: succeeded ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        _isDownloadingCurrentState = false;
        _currentDownloadProgress = null;
        _currentStateCode = null;
        _currentStateHasLandData = succeeded ? true : _currentStateHasLandData;
      });

      if (_mapCenterLocation != null) {
        _updateStateDataStatus(_mapCenterLocation!.latitude, _mapCenterLocation!.longitude);
      }

      // Refresh map overlays to show newly downloaded land data
      if (succeeded) {
        debugPrint('📥 MapPage: Triggering forceRefreshMapData');
        _coreMapKey.currentState?.forceRefreshMapData();
      }

      _downloadSubscription?.cancel();
      _downloadSubscription = null;
    });

    // ignore: unawaited_futures
    StateDownloadManager.instance.startDownloads([stateCode]);
  }

  // ============================================================================
  // Waypoint handling
  // ============================================================================

  void _onWaypointSelected(Waypoint waypoint) {
    debugPrint('📍 Waypoint selected: ${waypoint.name}');
    _showWaypointDetail(waypoint);
  }

  Future<void> _showWaypointDetail(Waypoint waypoint) async {
    // Get photos for this waypoint
    final photoState = ref.read(photoProvider);
    final waypointPhotos = photoState.photos.where((p) => p.waypointId == waypoint.id).toList();

    if (waypointPhotos.isNotEmpty) {
      // Show photo viewer for photo waypoints
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => FullscreenPhotoViewer(
            photoWaypoint: waypointPhotos.first,
            allPhotos: waypointPhotos,
          ),
        ),
      );
    } else {
      // Show note detail for text waypoints
      _showNoteWaypointDetail(waypoint);
    }
  }

  void _showNoteWaypointDetail(Waypoint waypoint) {
    final theme = Theme.of(context);
    // Get icon based on waypoint type
    final iconData = _getWaypointIcon(waypoint.type);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Header with icon
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: iconData.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(iconData.icon, color: iconData.color, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              waypoint.name ?? iconData.label,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _formatDateTime(waypoint.timestamp),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Notes
                  if (waypoint.notes != null && waypoint.notes!.isNotEmpty) ...[
                    Text('Notes', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(waypoint.notes!, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Location info
                  _buildInfoRow(
                    icon: Icons.location_on,
                    label: 'Location',
                    value: '${waypoint.coordinates.latitude.toStringAsFixed(5)}, ${waypoint.coordinates.longitude.toStringAsFixed(5)}',
                    theme: theme,
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              )),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'Just now';
        }
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    }
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }

  /// Get icon data for a waypoint type
  ({IconData icon, Color color, String label}) _getWaypointIcon(WaypointType type) {
    switch (type) {
      case WaypointType.photo:
        return (icon: Icons.camera_alt, color: Colors.blue, label: 'Photo');
      case WaypointType.voice:
        return (icon: Icons.mic, color: Colors.purple, label: 'Voice Note');
      case WaypointType.note:
        return (icon: Icons.note, color: Colors.orange, label: 'Note');
      case WaypointType.treasure:
        return (icon: Icons.diamond, color: Colors.amber, label: 'Treasure');
      case WaypointType.viewpoint:
        return (icon: Icons.landscape, color: Colors.green, label: 'Viewpoint');
      case WaypointType.camp:
        return (icon: Icons.cabin, color: Colors.brown, label: 'Camp');
      case WaypointType.parking:
        return (icon: Icons.local_parking, color: Colors.blueGrey, label: 'Parking');
      case WaypointType.warning:
        return (icon: Icons.warning, color: Colors.red, label: 'Warning');
      default:
        return (icon: Icons.place, color: Colors.teal, label: type.name);
    }
  }

  // ============================================================================
  // Custom marker from long-press
  // ============================================================================

  Future<void> _onMapLongPress(Point point) async {
    debugPrint('📍 Map long press at: ${point.coordinates.lat}, ${point.coordinates.lng}');

    // Show custom marker creation sheet (same UI as Edit Marker)
    final marker = await showCustomMarkerCreationSheet(
      context,
      latitude: point.coordinates.lat.toDouble(),
      longitude: point.coordinates.lng.toDouble(),
    );

    if (marker != null && mounted) {
      // Refresh custom markers in CoreMapView
      _coreMapKey.currentState?.forceRefreshMapData();
    }
  }

  Future<void> _openMarkerCreation(String sessionId) async {
    // Use the same custom marker creation sheet for markers during tracking
    // This provides the same experience as Edit Marker with camera support
    final locationState = ref.read(locationProvider);
    final currentPosition = locationState.currentPosition;

    if (currentPosition != null) {
      final marker = await showCustomMarkerCreationSheet(
        context,
        latitude: currentPosition.latitude,
        longitude: currentPosition.longitude,
        sessionId: sessionId,
      );

      if (marker != null && mounted) {
        // Refresh custom markers in CoreMapView
        _coreMapKey.currentState?.forceRefreshMapData();
      }
    } else {
      // No GPS position available
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waiting for GPS location...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ============================================================================
  // Permission check dialogs
  // ============================================================================

  Future<void> _showQuickPermissionCheck() async {
    // Show the private property sheet with recommendations
    _showPrivatePropertySheet();
  }

  void _showPrivatePropertySheet() {
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Warning header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.warning_amber, color: Colors.orange, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Likely Private Property',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'This location appears to be on private land. We recommend:',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _buildRecommendationItem('Check for "No Trespassing" signs'),
              _buildRecommendationItem('Verify ownership with county records'),
              _buildRecommendationItem('Obtain permission before entering'),
              _buildRecommendationItem('Respect property boundaries'),
              const SizedBox(height: 32),
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecommendationItem(String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  void _showPermissionDetails(ComprehensiveLandOwnership property) {
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _getOwnershipColor(property.ownershipType).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_getOwnershipIcon(property.ownershipType), color: _getOwnershipColor(property.ownershipType), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              property.displayName,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              property.ownershipType,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Permission grid
                  _buildPermissionGrid(context, property),
                  const SizedBox(height: 24),
                  // Contact card
                  if (property.agencyName != null) _buildContactCard(context, property),
                  const SizedBox(height: 48),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPermissionGrid(BuildContext context, ComprehensiveLandOwnership property) {
    final permissions = property.activityPermissions;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildPermissionChip(context, 'Hunting', permissions.hunting),
        _buildPermissionChip(context, 'Fishing', permissions.fishing),
        _buildPermissionChip(context, 'Camping', permissions.camping),
        _buildPermissionChip(context, 'Metal Detecting', permissions.metalDetecting),
        _buildPermissionChip(context, 'Treasure Hunting', permissions.treasureHunting),
        _buildPermissionChip(context, 'Archaeology', permissions.archaeology),
      ],
    );
  }

  Widget _buildPermissionChip(BuildContext context, String activity, PermissionStatus status) {
    final theme = Theme.of(context);

    Color chipColor;
    IconData chipIcon;
    switch (status) {
      case PermissionStatus.allowed:
        chipColor = Colors.green;
        chipIcon = Icons.check_circle;
      case PermissionStatus.permitRequired:
      case PermissionStatus.ownerPermissionRequired:
        chipColor = Colors.orange;
        chipIcon = Icons.warning;
      case PermissionStatus.prohibited:
        chipColor = Colors.red;
        chipIcon = Icons.cancel;
      case PermissionStatus.unknown:
        chipColor = Colors.grey;
        chipIcon = Icons.help;
    }

    return Chip(
      avatar: Icon(chipIcon, color: chipColor, size: 18),
      label: Text(activity),
      backgroundColor: chipColor.withValues(alpha: 0.1),
      side: BorderSide(color: chipColor.withValues(alpha: 0.3)),
      labelStyle: theme.textTheme.bodySmall?.copyWith(color: chipColor),
    );
  }

  Widget _buildContactCard(BuildContext context, ComprehensiveLandOwnership property) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Managing Agency',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(property.agencyName!, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  /// Get color for ownership type
  Color _getOwnershipColor(String ownershipType) {
    final type = ownershipType.toLowerCase();
    if (type.contains('federal') || type.contains('blm') || type.contains('usfs')) {
      return Colors.green;
    } else if (type.contains('state')) {
      return Colors.blue;
    } else if (type.contains('tribal')) {
      return Colors.purple;
    } else if (type.contains('private')) {
      return Colors.orange;
    }
    return Colors.grey;
  }

  /// Get icon for ownership type
  IconData _getOwnershipIcon(String ownershipType) {
    final type = ownershipType.toLowerCase();
    if (type.contains('federal') || type.contains('blm') || type.contains('usfs')) {
      return Icons.forest;
    } else if (type.contains('state')) {
      return Icons.account_balance;
    } else if (type.contains('tribal')) {
      return Icons.groups;
    } else if (type.contains('private')) {
      return Icons.home;
    }
    return Icons.landscape;
  }

  // ============================================================================
  // Map info
  // ============================================================================

  void _showMapInfo() {
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Map Information',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'This map displays land ownership data, trails, and historical places. '
                'Use the filter panel to customize which layers are visible.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                '• Tap land parcels for ownership details\n'
                '• Tap trails for trail information\n'
                '• Tap markers for waypoint details\n'
                '• Long-press to create waypoints\n'
                '• Use search to find locations',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
