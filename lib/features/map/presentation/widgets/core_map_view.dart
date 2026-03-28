import 'dart:async';
import 'dart:io' show File, Platform;
import 'dart:math' show cos, pi;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/cell_tower.dart';
import 'package:obsession_tracker/core/models/custom_marker.dart';
import 'package:obsession_tracker/core/models/historical_place.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/models/mapbox_config.dart';
import 'package:obsession_tracker/core/models/trail.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/app_settings_provider.dart';
import 'package:obsession_tracker/core/providers/cell_coverage_provider.dart';
import 'package:obsession_tracker/core/providers/custom_markers_provider.dart';
import 'package:obsession_tracker/core/providers/historical_maps_provider.dart';
import 'package:obsession_tracker/core/providers/historical_places_provider.dart';
import 'package:obsession_tracker/core/providers/land_ownership_provider.dart';
import 'package:obsession_tracker/core/providers/map_camera_provider.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/core/providers/trails_provider.dart';
import 'package:obsession_tracker/core/services/app_settings_service.dart';
import 'package:obsession_tracker/core/services/bff_mapping_service.dart';
import 'package:obsession_tracker/core/services/device_capability_service.dart';
import 'package:obsession_tracker/core/services/historical_maps_service.dart';
import 'package:obsession_tracker/core/services/mbtiles_tile_server.dart';
import 'package:obsession_tracker/core/services/quadrangle_detection_service.dart';
import 'package:obsession_tracker/core/services/quadrangle_download_service.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/breadcrumb_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/cell_coverage_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/custom_markers_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/highlighted_land_parcel_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/highlighted_trail_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/historical_places_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/land_ownership_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/trails_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/waypoint_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/custom_marker_creation_sheet.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/custom_marker_detail_sheet.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/custom_marker_edit_sheet.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/desktop_map_webview.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/historical_place_detail_sheet.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/land_filter_panel.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/land_parcel_bottom_sheet.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/map_controls_sheet.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/mapbox_map_widget.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/offscreen_tower_indicators.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/time_slider_panel.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/trail_bottom_sheet.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/zoom_hint_banner.dart';
import 'package:obsession_tracker/features/map/utils/desktop_geojson_converter.dart';

/// Minimum zoom level required to load land ownership data
/// Zoom 5 ≈ state/multi-county view (~300-500km across)
/// Below this, show "Zoom in" hint instead of loading data
const double kMinZoomForLandData = 5.0;

/// Minimum zoom level required to load trail data
/// Zoom 9 ≈ county view - trails need to be zoomed in to be useful
const double kMinZoomForTrailData = 9.0;

/// Minimum zoom level required to load cell coverage data
/// Zoom 7 ≈ regional view (~100-150km across) - useful for route planning
const double kMinZoomForCellData = 7.0;

/// Viewport buffer multiplier for seamless panning
/// Loads data for 40% beyond visible bounds
const double kViewportBufferMultiplier = 0.4;

/// Maximum cell tower coverage radius in meters for query expansion
/// Cell towers can have coverage up to 20km in rural areas
/// We use 15km as a reasonable maximum to capture most overlapping coverage
const double kMaxCellTowerRangeMeters = 15000.0;

/// Approximate meters per degree of latitude (varies slightly with latitude)
const double kMetersPerDegreeLat = 111320.0;

/// Simple camera info class used for data loading on both mobile and desktop.
/// Avoids direct dependency on Mapbox's CameraState which isn't available on desktop.
class _CameraInfo {
  const _CameraInfo({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    this.bearing = 0.0,
  });

  final double latitude;
  final double longitude;
  final double zoom;
  final double bearing;
}

/// A reusable map view widget that handles all shared map functionality.
///
/// This widget encapsulates:
/// - Land ownership overlay with zoom-based loading
/// - Trails overlay with filtering
/// - Historical places overlay
/// - Custom markers overlay
/// - Breadcrumb and waypoint overlays (data provided externally)
/// - Selection highlights and detail sheets
/// - Filter panel
///
/// Both MapPage and SessionPlaybackPage compose this widget, adding only
/// their specific UI (waypoint creation, playback controls, etc.)
class CoreMapView extends ConsumerStatefulWidget {
  const CoreMapView({
    super.key,
    required this.config,
    this.breadcrumbs,
    this.waypoints,
    this.plannedRoute,
    this.sessionId,
    this.enableZoomBasedReload = true,
    this.enableTrails = true,
    this.enableHistoricalPlaces = true,
    this.enableCustomMarkers = true,
    this.showFollowLocationButton = true,
    this.showFilterButton = true,
    this.showLandRightsBanner = false,
    this.isTrackingActive = false,
    this.hideOverlays = false,
    this.disableOverlayTapHandlers = false,
    this.onMapCreated,
    this.onMapViewChanged,
    this.onCameraMovingFast,
    this.onWaypointTap,
    this.onMapTap,
    this.onMapLongPress,
    this.onAddWaypoint,
    this.onFollowLocationToggle,
    this.onCheckPermissions,
    this.onToggleLandRightsBanner,
    this.onLandDataLoaded,
    this.onFilterPanelVisibilityChanged,
    this.isFollowingLocation = false,
    this.additionalOverlays = const [],
    this.additionalStackWidgets = const [],
  });

  /// Map configuration (tracking, playback, screenshot modes)
  final MapboxMapConfig config;

  /// External breadcrumb data (from active session or playback)
  final List<geo.Position>? breadcrumbs;

  /// External waypoint data (from session)
  final List<Waypoint>? waypoints;

  /// Planned route points (rendered as dashed line)
  final PlannedRoute? plannedRoute;

  /// Session ID for session-specific marker filtering
  /// When set, the filter panel shows a "Session Markers Only" toggle
  final String? sessionId;

  /// Whether to reload data when user pans/zooms
  final bool enableZoomBasedReload;

  /// Whether to load and display trails
  final bool enableTrails;

  /// Whether to load and display historical places
  final bool enableHistoricalPlaces;

  /// Whether to load and display custom markers
  final bool enableCustomMarkers;

  /// Whether to show follow location button in controls
  final bool showFollowLocationButton;

  /// Whether to show filter button in app bar
  final bool showFilterButton;

  /// Whether to show land rights banner
  final bool showLandRightsBanner;

  /// Whether tracking is currently active
  final bool isTrackingActive;

  /// Whether to hide HUD overlays (for search mode)
  final bool hideOverlays;

  /// Whether to disable tap handlers for land/trail/marker overlays
  /// Useful for route planning where taps should only add waypoints
  final bool disableOverlayTapHandlers;

  /// Callback when map is created
  final Future<void> Function(MapboxMap)? onMapCreated;

  /// Callback when map view changes (pan/zoom stops)
  final Future<void> Function(MapboxMap)? onMapViewChanged;

  /// Callback during fast camera movement
  final Future<void> Function(MapboxMap)? onCameraMovingFast;

  /// Callback when waypoint is tapped
  final void Function(Waypoint)? onWaypointTap;

  /// Callback for map tap (e.g., adding route waypoints)
  final Future<void> Function(Point)? onMapTap;

  /// Callback for map long-press (custom marker creation)
  final Future<void> Function(Point)? onMapLongPress;

  /// Callback for add waypoint button
  final VoidCallback? onAddWaypoint;

  /// Callback when follow location is toggled
  final void Function(bool)? onFollowLocationToggle;

  /// Callback for permission check button
  final Future<void> Function()? onCheckPermissions;

  /// Callback to toggle land rights banner
  final VoidCallback? onToggleLandRightsBanner;

  /// Callback when land data finishes loading (for updating land rights banner)
  final VoidCallback? onLandDataLoaded;

  /// Callback when filter panel visibility changes
  final ValueChanged<bool>? onFilterPanelVisibilityChanged;

  /// Whether currently following user location
  final bool isFollowingLocation;

  /// Additional overlays to add (e.g., position marker for playback)
  final List<MapOverlayConfig> additionalOverlays;

  /// Additional widgets to add to the stack (e.g., playback controls)
  final List<Widget> additionalStackWidgets;

  @override
  ConsumerState<CoreMapView> createState() => CoreMapViewState();
}

class CoreMapViewState extends ConsumerState<CoreMapView>
    with WidgetsBindingObserver {
  MapboxMap? _mapboxMap;
  bool _isMapFullyReady = false; // Track if map platform channel is ready

  /// Test-only: Static reference to the current map instance for integration tests
  /// This allows tests to programmatically control the camera
  static MapboxMap? testMapInstance;

  // Desktop map key for accessing WebView overlay methods
  final GlobalKey<DesktopMapWebViewState> _desktopMapKey =
      GlobalKey<DesktopMapWebViewState>();

  // Track if we're waiting for location permission dialog to be dismissed
  bool _pendingDesktopLocationPermission = false;

  // Data lists for overlays
  List<LandOwnership> _landParcels = [];
  List<Trail> _trails = [];
  List<Trail> _allStateTrails = [];
  List<HistoricalPlace> _historicalPlaces = [];
  List<CustomMarker> _customMarkers = [];
  List<CustomMarker> _sessionMarkers = [];
  List<CellTower> _cellTowers = [];
  List<OffscreenTowerIndicator> _offscreenTowerIndicators = [];

  // Selection state
  TrailGroup? _selectedTrailGroup;
  LandOwnership? _selectedParcel;

  // Loading and UI state
  bool _isLoadingLandData = false;
  bool _showLandFilterPanel = false;
  bool _showTimeSlider = false;
  double _currentZoom = 14.0;

  // Available historical maps for current viewport (for filter panel)
  List<QuadrangleSuggestion> _availableMaps = [];

  // Quadrangle download state
  bool _isDownloadingQuad = false;

  // Flag to indicate historical maps need to be loaded once provider is ready
  // This handles the case where onMapReady fires before provider finishes loading
  bool _pendingHistoricalMapsLoad = false;

  // Flag to track if the land layer has been established for the first time on desktop.
  // Historical maps need to be reloaded AFTER the land layer exists so they can be
  // positioned correctly (below the land-ownership-fill layer for proper z-ordering).
  bool _landLayerEstablished = false;

  // Debounce timer for available maps viewport check
  Timer? _availableMapsDebounceTimer;

  // Request versioning for available maps (prevents race conditions when panning quickly)
  int _availableMapsRequestId = 0;

  // Last viewport for available maps check (to avoid redundant calls)
  double? _lastAvailableMapsNorth;
  double? _lastAvailableMapsSouth;
  double? _lastAvailableMapsEast;
  double? _lastAvailableMapsWest;

  // Current visible bounds for search
  double? _visibleNorth;
  double? _visibleSouth;
  double? _visibleEast;
  double? _visibleWest;

  // Last loaded bounds - used to prevent unnecessary reloads when viewport hasn't changed
  double? _lastLoadedNorth;
  double? _lastLoadedSouth;
  double? _lastLoadedEast;
  double? _lastLoadedWest;
  double? _lastLoadedZoom;

  // Device capability
  double _adjustedMinZoomForLandData = kMinZoomForLandData;
  bool _deviceCapabilityInitialized = false;

  // Follow location state
  bool _followUserLocation = false;
  bool _isProgrammaticCameraMove = false;

  // Desktop-specific state
  MapHudOptions _desktopHudOptions = const MapHudOptions();

  // Cached overlay instances
  LandOwnershipOverlay? _cachedLandOverlay;
  TrailsOverlay? _cachedTrailsOverlay;
  BreadcrumbOverlay? _cachedBreadcrumbOverlay;
  int _cachedBreadcrumbsLength = 0; // Track length to detect actual changes
  BreadcrumbOverlay? _cachedPlannedRouteOverlay;
  String? _cachedPlannedRouteId; // Track which route is cached
  WaypointOverlay? _cachedWaypointOverlay;
  HistoricalPlacesOverlay? _cachedHistoricalPlacesOverlay;
  CustomMarkersOverlay? _cachedCustomMarkersOverlay;
  CustomMarkersOverlay? _cachedSessionMarkersOverlay;
  CellCoverageOverlay? _cachedCellCoverageOverlay;
  HighlightedLandParcelOverlay? _cachedHighlightedParcelOverlay;
  String? _cachedHighlightedParcelId; // Track which parcel is cached
  HighlightedTrailOverlay? _cachedHighlightedTrailOverlay;
  String? _cachedHighlightedTrailId; // Track which trail group is cached

  /// Public accessor for mapbox map instance
  MapboxMap? get mapboxMap => _mapboxMap;

  /// Public accessor for current zoom level
  double get currentZoom => _currentZoom;

  /// Public accessor for visible bounds
  ({double? north, double? south, double? east, double? west}) get visibleBounds => (
        north: _visibleNorth,
        south: _visibleSouth,
        east: _visibleEast,
        west: _visibleWest,
      );

  /// Public accessor for land parcels
  List<LandOwnership> get landParcels => _landParcels;

  /// Public accessor for loading state
  bool get isLoadingLandData => _isLoadingLandData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _followUserLocation = widget.isFollowingLocation;
    _initializeDesktopHudOptions();
  }

  @override
  void dispose() {
    _availableMapsDebounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('📍 CoreMapView lifecycle: $state (pending: $_pendingDesktopLocationPermission, isDesktop: $_isDesktop)');

    // When app resumes after permission dialog, check if permission was granted
    if (state == AppLifecycleState.resumed &&
        _pendingDesktopLocationPermission &&
        _isDesktop) {
      debugPrint('📍 App resumed with pending permission - checking...');
      _pendingDesktopLocationPermission = false;
      _checkPermissionAndCenterDesktop();
    }
  }

  /// Check permission status and center on user location if granted (desktop only)
  Future<void> _checkPermissionAndCenterDesktop() async {
    final permission = await geo.Geolocator.checkPermission();
    debugPrint('📍 Permission after dialog dismissed: $permission');

    if (permission == geo.LocationPermission.whileInUse ||
        permission == geo.LocationPermission.always) {
      // Permission granted, now get location
      await _getLocationAndCenterDesktop();
    } else {
      debugPrint('📍 Location permission still not granted');
    }
  }

  /// Get current position and center desktop map (assumes permission is granted)
  Future<void> _getLocationAndCenterDesktop() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );

      debugPrint(
          '📍 Desktop initial center: ${position.latitude}, ${position.longitude}');

      // Mark as programmatic move so onMapViewChanged doesn't disable follow
      _isProgrammaticCameraMove = true;

      // Fly desktop map to current location
      _desktopMapKey.currentState?.flyTo(
        position.latitude,
        position.longitude,
        zoom: 14.0,
      );
    } catch (e) {
      debugPrint('📍 Error getting location for desktop: $e');
    }
  }

  /// Initialize desktop HUD options from saved settings
  void _initializeDesktopHudOptions() {
    final mapSettings = ref.read(mapSettingsProvider);
    _desktopHudOptions = MapHudOptions(
      showCoordinates: mapSettings.hudShowCoordinates,
      showElevation: mapSettings.hudShowElevation,
      showSpeed: mapSettings.hudShowSpeed,
      showHeading: mapSettings.hudShowHeading,
    );
  }

  @override
  void didUpdateWidget(CoreMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFollowingLocation != oldWidget.isFollowingLocation) {
      _followUserLocation = widget.isFollowingLocation;
    }

    // Update desktop crosshair when showLandRightsBanner or hideOverlays changes
    final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    if (isDesktop &&
        (widget.showLandRightsBanner != oldWidget.showLandRightsBanner ||
            widget.hideOverlays != oldWidget.hideOverlays)) {
      _updateDesktopCenterCrosshair();
    }
  }

  @override
  Widget build(BuildContext context) {
    final landOverlayVisible = ref.watch(landOverlayVisibilityProvider);
    final landFilter = ref.watch(landOwnershipFilterProvider);
    final landOpacity = ref.watch(landOverlayOpacityProvider);
    final trailsVisible = ref.watch(trailsOverlayVisibilityProvider);
    final trailsOpacity = ref.watch(trailsOverlayOpacityProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final historicalPlacesVisible = ref.watch(historicalPlacesVisibilityProvider);
    final historicalPlacesFilter = ref.watch(historicalPlacesFilterProvider);
    final customMarkersVisible = ref.watch(customMarkersVisibilityProvider);
    final customMarkersFilter = ref.watch(customMarkersFilterProvider);
    final sessionMarkersVisible = ref.watch(sessionMarkersVisibilityProvider);
    final sessionMarkersCategories = ref.watch(sessionMarkersCategoryFilterProvider);
    final cellCoverageVisible = ref.watch(cellCoverageVisibilityProvider);
    final cellCoverageFilter = ref.watch(cellCoverageFilterProvider);

    // Listen for filter changes to reload data
    ref.listen<TrailFilter>(trailFilterProvider, (previous, next) {
      if (previous != next && widget.enableTrails) {
        debugPrint('🔄 Trail filter changed, reloading trails');
        _loadTrailsDataForCurrentView();
      }
    });

    ref.listen<CustomMarkerFilter>(customMarkersFilterProvider, (previous, next) {
      if (previous != next && widget.enableCustomMarkers) {
        debugPrint('🔄 Custom markers filter changed, reloading markers');
        _loadCustomMarkersDataForCurrentView();
      }
    });

    ref.listen<Set<CustomMarkerCategory>>(sessionMarkersCategoryFilterProvider, (previous, next) {
      if (previous != next && widget.sessionId != null) {
        debugPrint('🔄 Session markers filter changed, reloading session markers');
        _loadSessionMarkersDataForCurrentView();
      }
    });

    ref.listen<CellCoverageFilter>(cellCoverageFilterProvider, (previous, next) {
      if (previous != next) {
        debugPrint('🔄 Cell coverage filter changed, reloading cell towers');
        _loadCellTowersDataForCurrentView();
      }
    });

    // Load cell tower data when visibility is toggled ON
    // Also triggers on initial build if visibility is already true (previous is null)
    ref.listen<bool>(cellCoverageVisibilityProvider, (previous, next) {
      if ((previous == null || previous == false) && next == true) {
        debugPrint('🔄 Cell coverage visibility enabled, loading cell towers');
        _loadCellTowersDataForCurrentView();
      }
    });

    // Reload data when subscription status changes
    ref.listen<bool>(isPremiumProvider, (previous, next) {
      if (previous != null && previous != next) {
        debugPrint('🔄 Subscription status changed, reloading map data');
        _landParcels = [];
        _trails = [];
        _cellTowers = [];
        _offscreenTowerIndicators = [];
        if (landOverlayVisible || trailsVisible || historicalPlacesVisible || cellCoverageVisible) {
          _loadLandDataForCurrentView();
          if (widget.enableTrails) _loadTrailsDataForCurrentView();
          if (widget.enableHistoricalPlaces) _loadHistoricalPlacesDataForCurrentView();
          _loadCellTowersDataForCurrentView();
        }
      }
    });

    // Update desktop historical map overlays when state changes
    // NOTE: This calls _updateDesktopHistoricalMaps directly, NOT _updateDesktopOverlays,
    // so that changes to historical maps don't affect other overlays and vice versa.
    //
    // Key scenarios handled:
    // 1. Provider finishes loading AND map is ready -> load maps
    // 2. Provider finishes loading BUT map not ready -> onMapReady will handle it
    // 3. Map state changes (toggle on/off) AND map is ready -> load maps
    // 4. Pending load flag is set (onMapReady ran while provider loading) -> load maps
    ref.listen<HistoricalMapsState>(historicalMapsProvider, (previous, next) {
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        final wasLoading = previous?.isLoading ?? true;
        final isNowLoaded = !next.isLoading;
        final justFinishedLoading = wasLoading && isNowLoaded;

        debugPrint('🔄 Historical maps provider changed:');
        debugPrint('🔄   wasLoading=$wasLoading, isNowLoaded=$isNowLoaded');
        debugPrint('🔄   justFinishedLoading=$justFinishedLoading');
        debugPrint('🔄   pendingLoad=$_pendingHistoricalMapsLoad');
        debugPrint('🔄   maps=${next.maps.length}');

        final desktopMap = _desktopMapKey.currentState;
        if (desktopMap == null) {
          debugPrint('🔄 Desktop map state is null, onMapReady will handle loading');
          return;
        }

        if (!desktopMap.isMapReady) {
          debugPrint('🔄 Desktop map exists but JS not ready, onMapReady will handle loading');
          return;
        }

        // Map is ready - should we update?
        // Yes if: provider just finished loading, OR there's a pending load, OR maps state changed
        final shouldUpdate = justFinishedLoading || _pendingHistoricalMapsLoad || (previous != null && !wasLoading);

        if (shouldUpdate) {
          debugPrint('🔄 Desktop map is ready, updating historical maps');
          _updateDesktopHistoricalMaps(desktopMap);
        }
      }
    });

    // Update desktop overlays when visibility settings change
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      ref.listen<bool>(landOverlayVisibilityProvider, (previous, next) {
        if (previous != next) {
          debugPrint('🔄 Land visibility changed to $next, updating desktop overlays');
          _updateDesktopOverlays();
        }
      });

      ref.listen<bool>(trailsOverlayVisibilityProvider, (previous, next) {
        if (previous != next) {
          debugPrint('🔄 Trails visibility changed to $next, updating desktop overlays');
          _updateDesktopOverlays();
        }
      });

      ref.listen<bool>(historicalPlacesVisibilityProvider, (previous, next) {
        if (previous != next) {
          debugPrint('🔄 Historical places visibility changed to $next, updating desktop overlays');
          _updateDesktopOverlays();
        }
      });

      ref.listen<bool>(customMarkersVisibilityProvider, (previous, next) {
        if (previous != next) {
          debugPrint('🔄 Custom markers visibility changed to $next, updating desktop overlays');
          _updateDesktopOverlays();
        }
      });

      ref.listen<bool>(sessionMarkersVisibilityProvider, (previous, next) {
        if (previous != next) {
          debugPrint('🔄 Session markers visibility changed to $next, updating desktop overlays');
          _updateDesktopOverlays();
        }
      });

      ref.listen<LandOwnershipFilter>(landOwnershipFilterProvider, (previous, next) {
        if (previous != next) {
          debugPrint('🔄 Land filter changed, updating desktop overlays');
          _updateDesktopOverlays();
        }
      });

      ref.listen<double>(landOverlayOpacityProvider, (previous, next) {
        if (previous != next) {
          debugPrint('🔄 Land opacity changed to $next, updating desktop overlays');
          _updateDesktopOverlays();
        }
      });
    }

    // Build overlay configs
    final overlays = <MapOverlayConfig>[
      // Land ownership overlay
      if (landOverlayVisible && _landParcels.isNotEmpty && landFilter.enabledTypes.isNotEmpty)
        MapOverlayConfig(
          type: MapOverlayType.landOwnership,
          data: _getLandOverlay(landFilter, landOpacity),
        ),

      // Highlighted land parcel (cached to prevent reload loops)
      if (_selectedParcel != null)
        MapOverlayConfig(
          type: MapOverlayType.highlightedLandParcel,
          data: _getHighlightedParcelOverlay(_selectedParcel!),
          zIndex: 1,
        ),

      // Trails overlay
      if (widget.enableTrails && trailsVisible && _trails.isNotEmpty)
        MapOverlayConfig(
          type: MapOverlayType.trails,
          data: _getTrailsOverlay(trailsOpacity),
          zIndex: 1,
        ),

      // Historical places overlay
      if (widget.enableHistoricalPlaces &&
          historicalPlacesVisible &&
          _historicalPlaces.isNotEmpty &&
          !historicalPlacesFilter.noCategoriesEnabled)
        MapOverlayConfig(
          type: MapOverlayType.historicalPlaces,
          data: _getHistoricalPlacesOverlay(historicalPlacesFilter),
          zIndex: 2,
        ),

      // Custom markers overlay
      if (widget.enableCustomMarkers &&
          customMarkersVisible &&
          _customMarkers.isNotEmpty &&
          !customMarkersFilter.noCategoriesEnabled)
        MapOverlayConfig(
          type: MapOverlayType.customMarkers,
          data: _getCustomMarkersOverlay(customMarkersFilter),
          zIndex: 3,
        ),

      // Session markers overlay (separate from custom markers, only in session context)
      if (widget.sessionId != null &&
          sessionMarkersVisible &&
          _sessionMarkers.isNotEmpty &&
          sessionMarkersCategories.isNotEmpty)
        MapOverlayConfig(
          type: MapOverlayType.sessionMarkers,
          data: _getSessionMarkersOverlay(sessionMarkersCategories),
          zIndex: 4,
        ),

      // Cell coverage overlay (premium feature)
      if (isPremium &&
          cellCoverageVisible &&
          _cellTowers.isNotEmpty &&
          !cellCoverageFilter.noTypesEnabled)
        MapOverlayConfig(
          type: MapOverlayType.cellCoverage,
          data: _getCellCoverageOverlay(cellCoverageFilter),
          zIndex: 1,
        ),

      // Planned route overlay
      if (widget.plannedRoute != null)
        MapOverlayConfig(
          type: MapOverlayType.plannedRoute,
          data: _getPlannedRouteOverlay(widget.plannedRoute!),
          zIndex: 1,
        ),

      // Breadcrumb trail overlay
      if (widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty)
        MapOverlayConfig(
          type: MapOverlayType.breadcrumbTrail,
          data: _getBreadcrumbOverlay(widget.breadcrumbs!),
          zIndex: 1,
        ),

      // Highlighted trail overlay (cached to prevent reload loops)
      if (_selectedTrailGroup != null)
        MapOverlayConfig(
          type: MapOverlayType.highlightedTrail,
          data: _getHighlightedTrailOverlay(_selectedTrailGroup!),
          zIndex: 2,
        ),

      // Waypoint markers overlay
      if (widget.waypoints != null && widget.waypoints!.isNotEmpty)
        MapOverlayConfig(
          type: MapOverlayType.waypoints,
          data: _getWaypointOverlay(widget.waypoints!),
          zIndex: 3,
        ),

      // Additional overlays from parent (e.g., playback position marker)
      ...widget.additionalOverlays,
    ];

    // Check if running on desktop platform
    final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    return Stack(
      children: [
        // Main map widget - use WebView on desktop, native SDK on mobile
        if (isDesktop)
          DesktopMapWebView(
            key: _desktopMapKey,
            accessToken: const String.fromEnvironment('MAPBOX_ACCESS_TOKEN', defaultValue: ''),
            initialCenter: widget.config.initialCenter != null
                ? [
                    widget.config.initialCenter!.coordinates.lng.toDouble(),
                    widget.config.initialCenter!.coordinates.lat.toDouble(),
                  ]
                : null,
            initialZoom: widget.config.initialZoom,
            onMapReady: () async {
              setState(() {
                _isMapFullyReady = true;
              });

              // Check if there's a saved camera position to restore
              final savedPosition = ref.read(mapCameraPositionProvider);
              if (savedPosition == null) {
                // No saved position - try to center on user location
                await _centerOnUserLocationDesktop();
              } else {
                // Restore saved position
                _desktopMapKey.currentState?.flyTo(
                  savedPosition.latitude,
                  savedPosition.longitude,
                  zoom: savedPosition.zoom,
                );
              }

              // Load data and then update overlays for desktop
              await _loadInitialData();

              // Load historical maps (raster tile overlays) for desktop
              debugPrint('🗺️ Desktop onMapReady: Attempting to load historical maps...');
              final desktopMap = _desktopMapKey.currentState;
              debugPrint('🗺️ Desktop onMapReady: desktopMap state = ${desktopMap != null ? 'ready' : 'null'}');
              if (desktopMap != null) {
                await _updateDesktopHistoricalMaps(desktopMap);
              } else {
                debugPrint('🗺️ Desktop onMapReady: WARNING - Desktop map state is null!');
              }

              // Apply hillshade setting if enabled
              final mapSettings = ref.read(mapSettingsProvider);
              if (mapSettings.showHillshade) {
                await _desktopMapKey.currentState?.addHillshade();
              }

              // Show/hide center crosshair based on land rights banner setting
              // Crosshair is rendered in WebView (HTML/CSS) to avoid event passthrough issues
              await _updateDesktopCenterCrosshair();

              if (mounted) {
                setState(() {});
              }
            },
            onMapViewChanged: (lat, lng, zoom, bearing) async {
              // Update camera position provider for HUD display
              ref.read(mapCameraPositionProvider.notifier).savePosition(
                latitude: lat,
                longitude: lng,
                zoom: zoom,
                bearing: bearing,
              );

              // Update zoom state for zoom hint banner
              if (_currentZoom != zoom) {
                setState(() {
                  _currentZoom = zoom;
                });
              }

              // Reload data when viewport changes (desktop equivalent of mobile onMapViewChanged)
              if (widget.enableZoomBasedReload) {
                await _loadLandDataForCurrentView();
                if (widget.enableTrails) await _loadTrailsDataForCurrentView();
                if (widget.enableHistoricalPlaces) await _loadHistoricalPlacesDataForCurrentView();
                if (widget.enableCustomMarkers) await _loadCustomMarkersDataForCurrentView();
                if (widget.sessionId != null) await _loadSessionMarkersDataForCurrentView();
                await _loadCellTowersDataForCurrentView();
              }

              // Disable follow mode on manual pan (but not during programmatic move)
              if (_followUserLocation && !_isProgrammaticCameraMove) {
                setState(() {
                  _followUserLocation = false;
                });
                widget.onFollowLocationToggle?.call(false);
              }
              _isProgrammaticCameraMove = false;
            },
            onMapTap: (lat, lng) {
              widget.onMapTap?.call(Point(coordinates: Position(lng, lat)));
            },
            onMapLongPress: (lat, lng) {
              final handler = widget.onMapLongPress ?? (widget.enableCustomMarkers ? _onMapLongPress : null);
              handler?.call(Point(coordinates: Position(lng, lat)));
            },
            onLandParcelTap: (properties, lat, lng) {
              _handleDesktopLandParcelTap(properties);
            },
            onTrailTap: (properties, lat, lng) {
              _handleDesktopTrailTap(properties);
            },
            onHistoricalPlaceTap: (properties, lat, lng) {
              _handleDesktopHistoricalPlaceTap(properties);
            },
            onCustomMarkerTap: (properties, lat, lng) {
              _handleDesktopCustomMarkerTap(properties);
            },
            onWaypointTap: (properties, lat, lng) {
              _handleDesktopWaypointTap(properties);
            },
          )
        else
          MapboxMapWidget(
            config: widget.config,
            overlays: overlays,
            onMapCreated: _onMapCreated,
            onCameraMovingFast: (mapboxMap) async {
              await widget.onCameraMovingFast?.call(mapboxMap);
            },
            onMapViewChanged: (mapboxMap) async {
              final cameraInfo = await _getCameraInfo();
              if (cameraInfo == null) return; // Map not ready yet

              final newZoom = cameraInfo.zoom;

              if (_currentZoom != newZoom) {
                setState(() {
                  _currentZoom = newZoom;
                });
              }

              if (widget.enableZoomBasedReload) {
                await _loadLandDataForCurrentView();
                if (widget.enableTrails) await _loadTrailsDataForCurrentView();
                if (widget.enableHistoricalPlaces) await _loadHistoricalPlacesDataForCurrentView();
                if (widget.enableCustomMarkers) await _loadCustomMarkersDataForCurrentView();
                if (widget.sessionId != null) await _loadSessionMarkersDataForCurrentView();
                await _loadCellTowersDataForCurrentView();
              }

              // Debounced update for available historical maps
              _scheduleAvailableMapsUpdate();

              // Disable follow mode on manual pan
              if (_followUserLocation && !_isProgrammaticCameraMove) {
                setState(() {
                  _followUserLocation = false;
                });
                widget.onFollowLocationToggle?.call(false);
              }
              _isProgrammaticCameraMove = false;

              await widget.onMapViewChanged?.call(mapboxMap);
            },
            isFollowingLocation: _followUserLocation,
            onFollowLocationToggle: widget.showFollowLocationButton
                ? (isFollowing) {
                    setState(() {
                      _followUserLocation = isFollowing;
                    });
                    widget.onFollowLocationToggle?.call(isFollowing);
                    if (isFollowing) {
                      _centerOnCurrentLocation();
                    }
                  }
                : null,
            onControlsExpandedChanged: (_) {},
            onAddWaypoint: widget.onAddWaypoint,
            onMapTap: widget.onMapTap,
            onMapLongPress: widget.onMapLongPress ?? (widget.enableCustomMarkers ? _onMapLongPress : null),
            onCheckPermissions: widget.onCheckPermissions,
            isTrackingActive: widget.isTrackingActive,
            showLandRightsBanner: widget.showLandRightsBanner,
            onToggleLandRightsBanner: widget.onToggleLandRightsBanner,
            hideOverlays: widget.hideOverlays || _showLandFilterPanel,
          ),

        // Desktop HUD overlay (equivalent to MapboxMapWidget's built-in HUD)
        if (isDesktop && !widget.hideOverlays)
          MapHudOverlay(options: _desktopHudOptions),

        // NOTE: Desktop center crosshair is now rendered inside the WebView (HTML/CSS)
        // to avoid Flutter/platform view event passthrough issues.
        // See mapbox_desktop.html for the implementation.
        // Controlled via showCenterCrosshair/hideCenterCrosshair methods.

        // Desktop map controls (equivalent to MapboxMapWidget's built-in controls)
        if (isDesktop && !widget.hideOverlays && !_showLandFilterPanel)
          MapControlsSheet(
            onCenterLocation: _centerOnCurrentLocationDesktop,
            onResetNorth: _resetNorthDesktop,
            onToggleRotation: () {}, // Rotation not applicable on desktop WebView
            onShowStyleSelector: _showStyleSelectorDesktop,
            onHudOptionsChanged: (options) {
              setState(() {
                _desktopHudOptions = options;
              });
              // Persist HUD settings (same as mobile MapboxMapWidget)
              final appSettingsService = ref.read(appSettingsServiceProvider);
              final currentMapSettings = ref.read(mapSettingsProvider);
              appSettingsService.updateMapSettings(
                currentMapSettings.copyWith(
                  hudShowCoordinates: options.showCoordinates,
                  hudShowElevation: options.showElevation,
                  hudShowSpeed: options.showSpeed,
                  hudShowHeading: options.showHeading,
                ),
              );
            },
            isFollowingLocation: _followUserLocation,
            hudOptions: _desktopHudOptions,
            showRotationControl: false, // Desktop WebView doesn't support rotation lock
            onAddWaypoint: widget.onAddWaypoint,
            onCheckPermissions: widget.onCheckPermissions,
            isTrackingActive: widget.isTrackingActive,
            showLandRightsBanner: widget.showLandRightsBanner,
            onToggleLandRightsBanner: widget.onToggleLandRightsBanner,
          ),

        // Zoom hint banner
        if (isPremium && !widget.hideOverlays && !_showLandFilterPanel)
          Positioned(
            bottom: 200,
            left: 0,
            right: 0,
            child: Center(
              child: ZoomHintBanner(
                currentZoom: _currentZoom,
                minZoomForLandData: _adjustedMinZoomForLandData,
                minZoomForTrailData: kMinZoomForTrailData,
                landOverlayVisible: landOverlayVisible,
                trailsOverlayVisible: trailsVisible,
              ),
            ),
          ),

        // Off-screen cell tower indicators
        if (isPremium && !widget.hideOverlays && !_showLandFilterPanel && _offscreenTowerIndicators.isNotEmpty)
          OffscreenTowerIndicators(indicators: _offscreenTowerIndicators),

        // Land filter panel
        // Shows when toggled, either via internal button or external control (e.g., app bar)
        if (_showLandFilterPanel)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: LandFilterPanel(
              sessionId: widget.sessionId,
              availableMaps: _availableMaps,
              onClose: () {
                setState(() {
                  _showLandFilterPanel = false;
                });
                widget.onFilterPanelVisibilityChanged?.call(false);
              },
              onFilterChanged: (filter) {
                _loadLandDataForCurrentView();
              },
              onDownloadAvailableMap: _handleDownloadAvailableMap,
              onOpenTimeline: () {
                setState(() {
                  _showLandFilterPanel = false;
                  _showTimeSlider = true;
                });
                widget.onFilterPanelVisibilityChanged?.call(false);
              },
            ),
          ),

        // Time slider panel for historical maps
        if (_showTimeSlider)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Consumer(
              builder: (context, ref, _) {
                final historicalMapsState = ref.watch(historicalMapsProvider);
                final downloadedMaps = historicalMapsState.maps.values.toList();

                return TimeSliderPanel(
                  downloadedMaps: downloadedMaps,
                  availableMaps: _availableMaps,
                  onClose: () {
                    setState(() => _showTimeSlider = false);
                  },
                  onMapSelected: (entry) {
                    if (entry.historicalMapState != null) {
                      ref.read(historicalMapsProvider.notifier).toggleMap(
                            entry.historicalMapState!.stateCode,
                            entry.historicalMapState!.layerId,
                          );
                    }
                  },
                  onDownloadRequested: _handleDownloadAvailableMap,
                  onOpacityChanged: (opacity) {
                    // Apply opacity to all enabled maps
                    final notifier = ref.read(historicalMapsProvider.notifier);
                    for (final map in downloadedMaps) {
                      if (map.isEnabled) {
                        notifier.setOpacity(map.stateCode, map.layerId, opacity);
                      }
                    }
                  },
                );
              },
            ),
          ),

        // Note: Trail and land parcel detail sheets are now shown as modal bottom sheets
        // that overlay the entire screen (including playback controls).
        // See _showTrailDetailSheet and _showParcelDetailSheet methods.

        // Additional stack widgets from parent (e.g., playback controls)
        ...widget.additionalStackWidgets,
      ],
    );
  }

  // ============================================================================
  // Public methods for parent access
  // ============================================================================

  /// Toggle the filter panel visibility
  void toggleFilterPanel() {
    setState(() {
      _showLandFilterPanel = !_showLandFilterPanel;
    });
    widget.onFilterPanelVisibilityChanged?.call(_showLandFilterPanel);
    if (_landParcels.isEmpty) {
      _loadLandDataForCurrentView();
    }
    if (_trails.isEmpty && widget.enableTrails) {
      _loadTrailsDataForCurrentView();
    }
    if (_historicalPlaces.isEmpty && widget.enableHistoricalPlaces) {
      _loadHistoricalPlacesDataForCurrentView();
    }
    if (_cellTowers.isEmpty) {
      _loadCellTowersDataForCurrentView();
    }
    // Load available historical maps when opening filter panel
    if (_showLandFilterPanel) {
      _loadAvailableMapsForCurrentView();
    }
  }

  /// Force refresh all map data
  /// Clears cached viewport to ensure data is reloaded even if viewport hasn't changed
  Future<void> forceRefreshMapData() async {
    debugPrint('🗺️ CoreMapView: forceRefreshMapData - clearing cached viewport');
    // Clear cached viewport bounds to bypass the "viewport unchanged" optimization
    // This ensures data is reloaded after a download completes
    _lastLoadedNorth = null;
    _lastLoadedSouth = null;
    _lastLoadedEast = null;
    _lastLoadedWest = null;
    _lastLoadedZoom = null;
    // Also clear cached data to force fresh load from updated local database
    _landParcels = [];
    _trails = [];
    _historicalPlaces = [];
    _customMarkers = [];
    _cellTowers = [];
    _offscreenTowerIndicators = [];

    await _loadLandDataForCurrentView();
    if (widget.enableTrails) await _loadTrailsDataForCurrentView();
    if (widget.enableHistoricalPlaces) await _loadHistoricalPlacesDataForCurrentView();
    if (widget.enableCustomMarkers) await _loadCustomMarkersDataForCurrentView();
    if (widget.sessionId != null) await _loadSessionMarkersDataForCurrentView();
    await _loadCellTowersDataForCurrentView();

    // Trigger UI rebuild after data is loaded
    if (mounted) setState(() {});
  }

  /// Center map on given coordinates (works on both mobile and desktop)
  Future<void> centerOnLocation(double latitude, double longitude, {double? zoom}) async {
    _isProgrammaticCameraMove = true;

    if (_isDesktop) {
      // Desktop: Use WebView flyTo
      _desktopMapKey.currentState?.flyTo(latitude, longitude, zoom: zoom ?? 14.0);
    } else {
      // Mobile: Use Mapbox SDK
      if (_mapboxMap == null) return;
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(longitude, latitude)),
          zoom: zoom,
        ),
        MapAnimationOptions(duration: 500),
      );
    }
  }

  /// Get the filter panel visibility state
  bool get isFilterPanelVisible => _showLandFilterPanel;

  /// Check if there are available historical maps for the current viewport
  bool get hasAvailableMaps => _availableMaps.isNotEmpty;

  /// Get the count of available historical maps for the current viewport
  int get availableMapCount => _availableMaps.length;

  // ============================================================================
  // Private methods
  // ============================================================================

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    debugPrint('🗺️ CoreMapView: onMapCreated called');
    _mapboxMap = mapboxMap;

    // Set test-only static reference for integration tests
    testMapInstance = mapboxMap;

    // Initialize device capability detection
    if (!_deviceCapabilityInitialized) {
      await DeviceCapabilityService.instance.initialize();
      _adjustedMinZoomForLandData = DeviceCapabilityService.instance.getMinZoomForLandData(
        baseMinZoom: kMinZoomForLandData,
      );
      _deviceCapabilityInitialized = true;
      debugPrint(
        '📱 CoreMapView: Device tier=${DeviceCapabilityService.instance.tier.name}, '
        'adjusted min zoom=$_adjustedMinZoomForLandData',
      );
    }

    // Load initial data - these will return early if map platform isn't ready yet
    await _loadInitialData();

    // Notify parent
    await widget.onMapCreated?.call(mapboxMap);

    // Schedule a retry for data loading if map wasn't ready initially
    // This ensures data loads even if platform channel took time to establish
    if (!_isMapFullyReady) {
      debugPrint('🗺️ CoreMapView: Scheduling delayed data load retry...');
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted && !_isMapFullyReady) {
          debugPrint('🗺️ CoreMapView: Retrying initial data load...');
          await _loadInitialData();
          if (mounted) setState(() {});
        }
      });
    }

    // Ensure overlays render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  /// Load all initial data for the current map view.
  /// Called from _onMapCreated and may be retried if map isn't ready.
  Future<void> _loadInitialData() async {
    await _loadLandDataForCurrentView();
    if (widget.enableTrails) await _loadTrailsDataForCurrentView();
    if (widget.enableHistoricalPlaces) await _loadHistoricalPlacesDataForCurrentView();
    if (widget.enableCustomMarkers) await _loadCustomMarkersDataForCurrentView();
    if (widget.sessionId != null) await _loadSessionMarkersDataForCurrentView();
    await _loadCellTowersDataForCurrentView();
  }

  Future<void> _centerOnCurrentLocation() async {
    // This needs to be called from parent with location data
    // For now, just set the flag
    _isProgrammaticCameraMove = true;
  }

  /// Center on current location for desktop WebView map
  Future<void> _centerOnCurrentLocationDesktop() async {
    // If already following, turn it off (toggle behavior)
    if (_followUserLocation) {
      debugPrint('🎯 Follow toggle: false (was on, turning off)');
      setState(() {
        _followUserLocation = false;
      });
      widget.onFollowLocationToggle?.call(false);
      return;
    }

    debugPrint('🎯 Follow toggle: true (turning on, getting location...)');

    try {
      // Check location permission first
      final permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        final requested = await geo.Geolocator.requestPermission();
        if (requested == geo.LocationPermission.denied ||
            requested == geo.LocationPermission.deniedForever) {
          debugPrint('📍 Location permission denied for desktop');
          return;
        }
      }

      // Get current position
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );

      // Mark as programmatic move so onMapViewChanged doesn't disable follow
      _isProgrammaticCameraMove = true;

      // Fly desktop map to current location
      _desktopMapKey.currentState?.flyTo(
        position.latitude,
        position.longitude,
        zoom: 15.0,
      );

      // Update follow state
      setState(() {
        _followUserLocation = true;
      });
      widget.onFollowLocationToggle?.call(true);
    } catch (e) {
      debugPrint('📍 Error getting location for desktop: $e');
    }
  }

  /// Reset bearing to north for desktop WebView map
  void _resetNorthDesktop() {
    _desktopMapKey.currentState?.resetNorth();
  }

  /// Center on user location for initial desktop map load (no toggle behavior)
  Future<void> _centerOnUserLocationDesktop() async {
    try {
      // Check location permission first
      final permission = await geo.Geolocator.checkPermission();
      debugPrint('📍 Desktop initial permission check: $permission');

      if (permission == geo.LocationPermission.denied) {
        // Set flag before requesting - we'll handle the result in didChangeAppLifecycleState
        // when the app resumes after the permission dialog is dismissed
        _pendingDesktopLocationPermission = true;
        debugPrint('📍 Requesting location permission...');

        // This triggers the system permission dialog
        // On macOS, the dialog is synchronous and requestPermission returns the result
        final requestedPermission = await geo.Geolocator.requestPermission();
        debugPrint('📍 requestPermission returned: $requestedPermission');

        // Check the returned permission directly (macOS returns the result synchronously)
        if (requestedPermission == geo.LocationPermission.whileInUse ||
            requestedPermission == geo.LocationPermission.always) {
          debugPrint('📍 Permission granted via requestPermission result');
          _pendingDesktopLocationPermission = false;
          await _getLocationAndCenterDesktop();
          return;
        }

        // Double-check by calling checkPermission (some platforms need this)
        final updatedPermission = await geo.Geolocator.checkPermission();
        debugPrint('📍 checkPermission after request: $updatedPermission');
        if (updatedPermission == geo.LocationPermission.whileInUse ||
            updatedPermission == geo.LocationPermission.always) {
          _pendingDesktopLocationPermission = false;
          await _getLocationAndCenterDesktop();
          return;
        }

        // If still not granted, didChangeAppLifecycleState will handle it when app resumes
        // Also set up a fallback timer to check again (macOS might not fire lifecycle events)
        debugPrint('📍 Setting up fallback permission check timer');
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (_pendingDesktopLocationPermission && mounted) {
            final fallbackPermission = await geo.Geolocator.checkPermission();
            debugPrint('📍 Fallback permission check: $fallbackPermission');
            if (fallbackPermission == geo.LocationPermission.whileInUse ||
                fallbackPermission == geo.LocationPermission.always) {
              _pendingDesktopLocationPermission = false;
              await _getLocationAndCenterDesktop();
            }
          }
        });
        return;
      }

      if (permission == geo.LocationPermission.deniedForever) {
        debugPrint('📍 Location permission permanently denied');
        return;
      }

      // Permission already granted, get location directly
      await _getLocationAndCenterDesktop();
    } catch (e) {
      debugPrint('📍 Error in desktop initial center: $e');
      _pendingDesktopLocationPermission = false;
    }
  }

  /// Show style selector dialog for desktop WebView map
  void _showStyleSelectorDesktop() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mapSettings = ref.read(mapSettingsProvider);
    var showHillshade = mapSettings.showHillshade;

    showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1714) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Map Style',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.terrain),
                  title: const Text('Outdoors'),
                  subtitle: const Text('Topographic map with trails'),
                  onTap: () {
                    _desktopMapKey.currentState?.setStyle(MapboxStyles.OUTDOORS);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.satellite_alt),
                  title: const Text('Satellite'),
                  subtitle: const Text('Aerial imagery with labels'),
                  onTap: () {
                    _desktopMapKey.currentState?.setStyle(MapboxStyles.SATELLITE_STREETS);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                  title: Text(isDark ? 'Dark' : 'Light'),
                  subtitle: const Text('Matches app theme'),
                  onTap: () {
                    _desktopMapKey.currentState?.setStyle(
                      isDark ? MapboxStyles.DARK : MapboxStyles.LIGHT,
                    );
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 24),
                SwitchListTile(
                  secondary: const Icon(Icons.landscape),
                  title: const Text('Terrain Relief'),
                  subtitle: const Text('Show hillshade elevation'),
                  value: showHillshade,
                  activeTrackColor: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                  activeThumbColor: const Color(0xFFD4AF37),
                  onChanged: (value) {
                    setSheetState(() {
                      showHillshade = value;
                    });
                    _toggleDesktopHillshade(value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Toggle hillshade layer on desktop map
  Future<void> _toggleDesktopHillshade(bool enabled) async {
    // Save the setting
    final currentMapSettings = ref.read(mapSettingsProvider);
    await AppSettingsService.instance.updateMapSettings(
      currentMapSettings.copyWith(showHillshade: enabled),
    );

    // Update the map layer
    if (enabled) {
      await _desktopMapKey.currentState?.addHillshade();
    } else {
      await _desktopMapKey.currentState?.removeHillshade();
    }
  }

  // ============================================================================
  // Data loading methods
  // ============================================================================

  /// Check if running on desktop platform
  bool get _isDesktop => Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// Get camera info for data loading. Works on both mobile (Mapbox SDK) and desktop (camera provider).
  /// Returns null if the map isn't ready yet.
  Future<_CameraInfo?> _getCameraInfo() async {
    if (_isDesktop) {
      // On desktop, use the camera position provider
      final cameraPos = ref.read(mapCameraPositionProvider);
      if (cameraPos == null || !_isMapFullyReady) return null;

      return _CameraInfo(
        latitude: cameraPos.latitude,
        longitude: cameraPos.longitude,
        zoom: cameraPos.zoom,
        bearing: cameraPos.bearing,
      );
    }

    if (_mapboxMap == null) return null;

    try {
      final cameraState = await _mapboxMap!.getCameraState();
      // Mark map as fully ready on first successful camera state retrieval
      if (!_isMapFullyReady) {
        _isMapFullyReady = true;
        debugPrint('🗺️ CoreMapView: Map platform channel confirmed ready');
        // Schedule data reload now that map is ready
        // Use addPostFrameCallback to avoid calling during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            debugPrint('🗺️ CoreMapView: Triggering initial data load after map ready');
            _loadInitialData();
          }
        });
      }
      return _CameraInfo(
        latitude: cameraState.center.coordinates.lat.toDouble(),
        longitude: cameraState.center.coordinates.lng.toDouble(),
        zoom: cameraState.zoom,
        bearing: cameraState.bearing,
      );
    } catch (e) {
      // PlatformException occurs when map platform channel isn't ready
      // This is normal during initialization, especially in screenshot tests
      debugPrint('⏳ CoreMapView: Map not ready yet (getCameraState failed: $e)');
      return null;
    }
  }

  /// Get viewport bounds for current view.
  /// On mobile, uses Mapbox SDK. On desktop, calculates from camera position.
  Future<({double north, double south, double east, double west})?> _getViewportBounds() async {
    if (_isDesktop) {
      final cameraPos = ref.read(mapCameraPositionProvider);
      if (cameraPos == null) return null;

      // Calculate approximate bounds from center + zoom
      // At zoom 0, world is ~360 degrees wide. Each zoom level halves the view.
      // Approximate view size: 360 / 2^zoom for longitude, less for latitude due to Mercator
      final latSpan = 180 / (1 << cameraPos.zoom.round().clamp(0, 20));
      final lngSpan = 360 / (1 << cameraPos.zoom.round().clamp(0, 20));

      return (
        north: cameraPos.latitude + latSpan / 2,
        south: cameraPos.latitude - latSpan / 2,
        east: cameraPos.longitude + lngSpan / 2,
        west: cameraPos.longitude - lngSpan / 2,
      );
    }

    if (_mapboxMap == null) return null;

    final cameraInfo = await _getCameraInfo();
    if (cameraInfo == null) return null;

    final bounds = await _mapboxMap!.coordinateBoundsForCamera(
      CameraOptions(
        center: Point(coordinates: Position(cameraInfo.longitude, cameraInfo.latitude)),
        zoom: cameraInfo.zoom,
      ),
    );

    return (
      north: bounds.northeast.coordinates.lat.toDouble(),
      south: bounds.southwest.coordinates.lat.toDouble(),
      east: bounds.northeast.coordinates.lng.toDouble(),
      west: bounds.southwest.coordinates.lng.toDouble(),
    );
  }

  Future<void> _loadLandDataForCurrentView() async {
    // On mobile, check _mapboxMap. On desktop, check _isMapFullyReady
    if (!_isDesktop && _mapboxMap == null) return;
    if (_isDesktop && !_isMapFullyReady) return;
    if (_isLoadingLandData) return;

    final cameraInfo = await _getCameraInfo();
    if (cameraInfo == null) return; // Map not ready yet
    // Check mounted after await to prevent using ref when widget is disposed
    if (!mounted) return;

    final actualZoom = cameraInfo.zoom;

    // Use land data threshold, not trail threshold
    // _adjustedMinZoomForLandData accounts for device capabilities
    if (actualZoom < _adjustedMinZoomForLandData) {
      if (_landParcels.isNotEmpty) {
        setState(() {
          _landParcels = [];
          _isLoadingLandData = false;
        });
      }
      return;
    }

    // Get current bounds to check if we need to reload
    final viewportBounds = await _getViewportBounds();
    if (viewportBounds == null || !mounted) return;

    final currentNorth = viewportBounds.north;
    final currentSouth = viewportBounds.south;
    final currentEast = viewportBounds.east;
    final currentWest = viewportBounds.west;

    // Skip reload if viewport hasn't changed significantly (within 5% of view size)
    if (_lastLoadedNorth != null && _lastLoadedZoom != null) {
      final latRange = currentNorth - currentSouth;
      final lngRange = currentEast - currentWest;
      const threshold = 0.05; // 5% movement threshold

      final northDiff = (currentNorth - _lastLoadedNorth!).abs();
      final southDiff = (currentSouth - _lastLoadedSouth!).abs();
      final eastDiff = (currentEast - _lastLoadedEast!).abs();
      final westDiff = (currentWest - _lastLoadedWest!).abs();
      final zoomDiff = (actualZoom - _lastLoadedZoom!).abs();

      final viewportUnchanged = northDiff < latRange * threshold &&
          southDiff < latRange * threshold &&
          eastDiff < lngRange * threshold &&
          westDiff < lngRange * threshold &&
          zoomDiff < 0.5; // Less than 0.5 zoom level change

      if (viewportUnchanged) {
        // Viewport hasn't changed enough, skip reload
        return;
      }
    }

    setState(() {
      _isLoadingLandData = true;
    });

    try {
      // Update visible bounds
      _visibleNorth = currentNorth;
      _visibleSouth = currentSouth;
      _visibleEast = currentEast;
      _visibleWest = currentWest;

      final bufferedBounds = _expandBoundsWithBuffer(
        north: _visibleNorth!,
        south: _visibleSouth!,
        east: _visibleEast!,
        west: _visibleWest!,
      );

      final isPremium = ref.read(isPremiumProvider);
      if (!isPremium) {
        if (mounted) {
          setState(() {
            _landParcels = [];
            _isLoadingLandData = false;
          });
        }
        return;
      }

      // Progressive parcel limit based on 5-level LOD zoom buckets
      // At low zoom, even simplified geometry overwhelms memory when loading many parcels
      // The limit must account for TOTAL data, not just per-parcel complexity
      final int baseLimit;
      final String lodName;
      if (actualZoom >= 15) {
        // Full detail (survey-accurate) - fewer parcels needed
        baseLimit = 1000;
        lodName = 'full';
      } else if (actualZoom >= 12) {
        // High detail (~5.5m) - property level
        baseLimit = 1500;
        lodName = 'high';
      } else if (actualZoom >= 10) {
        // Medium detail (~22m) - neighborhood view
        baseLimit = 2500;
        lodName = 'medium';
      } else if (actualZoom >= 8) {
        // Low detail (~111m) - county view
        baseLimit = 2000;
        lodName = 'low';
      } else {
        // Overview (~555m) - state/regional view, limit aggressively
        baseLimit = 1000;
        lodName = 'overview';
      }

      // Calculate viewport size for logging
      final viewportHeight = bufferedBounds.north - bufferedBounds.south;
      final viewportWidth = (bufferedBounds.east - bufferedBounds.west).abs();
      final viewportSqDeg = viewportHeight * viewportWidth;

      debugPrint('🎯 LOD Query: zoom=${actualZoom.toStringAsFixed(1)}, LOD=$lodName, limit=$baseLimit');
      debugPrint('   Viewport: ${viewportHeight.toStringAsFixed(2)}° × ${viewportWidth.toStringAsFixed(2)}° = ${viewportSqDeg.toStringAsFixed(2)} sq°');

      final limit = DeviceCapabilityService.instance.getParcelLimit(
        baseLimit: baseLimit,
        zoomLevel: actualZoom,
      );

      final landData = await BFFMappingService.instance.getLandOwnershipData(
        northBound: bufferedBounds.north,
        southBound: bufferedBounds.south,
        eastBound: bufferedBounds.east,
        westBound: bufferedBounds.west,
        limit: limit,
        zoomLevel: actualZoom,
      );

      if (mounted) {
        // Update last loaded bounds to prevent unnecessary reloads
        _lastLoadedNorth = currentNorth;
        _lastLoadedSouth = currentSouth;
        _lastLoadedEast = currentEast;
        _lastLoadedWest = currentWest;
        _lastLoadedZoom = actualZoom;

        setState(() {
          _landParcels = landData;
          _isLoadingLandData = false;
          if (_selectedParcel != null && !landData.any((p) => p.id == _selectedParcel!.id)) {
            _selectedParcel = null;
          }
        });

        // Update desktop map overlays if on desktop
        if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
          await _updateDesktopOverlays();

          // After the land layer is first established, reload historical maps
          // and historical places so they can be positioned correctly below the
          // land-ownership-fill layer. This fixes the z-ordering issue where
          // overlays loaded before land data would end up on top of the layer stack.
          if (!_landLayerEstablished && landData.isNotEmpty) {
            _landLayerEstablished = true;
            debugPrint('🗺️ Land layer established - reloading overlays for z-ordering');
            final desktopMap = _desktopMapKey.currentState;
            if (desktopMap != null && desktopMap.isMapReady) {
              // Reload historical maps (raster tiles)
              await _updateDesktopHistoricalMaps(desktopMap);

              // Reload historical places (point markers) by clearing and re-adding
              // to ensure they're added after land layer exists
              final historicalPlacesVisible = ref.read(historicalPlacesVisibilityProvider);
              if (_historicalPlaces.isNotEmpty && historicalPlacesVisible) {
                debugPrint('🗺️ Reloading historical places for z-ordering');
                await desktopMap.clearHistoricalPlaces();
                final geojson = DesktopGeoJsonConverter.historicalPlacesToGeoJson(_historicalPlaces);
                await desktopMap.loadHistoricalPlaces(geojson);
              }
            }
          }
        }

        // Notify parent that land data has loaded (for updating land rights banner)
        // Use post-frame callback to ensure overlay has rendered before parent queries
        if (landData.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onLandDataLoaded?.call();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('❌ CoreMapView: Failed to load land data: $e');
      if (mounted) {
        setState(() {
          _isLoadingLandData = false;
        });
      }
    }
  }

  /// Schedule a debounced update for available historical maps
  void _scheduleAvailableMapsUpdate() {
    _availableMapsDebounceTimer?.cancel();
    _availableMapsDebounceTimer = Timer(
      const Duration(milliseconds: 500),
      _loadAvailableMapsForCurrentView,
    );
  }

  /// Load available historical maps for the current viewport
  /// Uses request versioning to prevent race conditions when panning quickly
  Future<void> _loadAvailableMapsForCurrentView() async {
    debugPrint('🗺️ CoreMapView: _loadAvailableMapsForCurrentView called');
    final cameraInfo = await _getCameraInfo();
    if (cameraInfo == null || !mounted) {
      debugPrint('🗺️ CoreMapView: No camera info or not mounted');
      return;
    }

    debugPrint('🗺️ CoreMapView: Camera at ${cameraInfo.latitude}, ${cameraInfo.longitude} zoom ${cameraInfo.zoom}');

    // Calculate viewport bounds (simple approximation)
    // At zoom 14, each tile is roughly 0.02 degrees
    final zoomFactor = 360.0 / (1 << cameraInfo.zoom.toInt().clamp(1, 20));
    final latBuffer = zoomFactor * 0.5;
    final lonBuffer = zoomFactor * 0.5;

    final north = cameraInfo.latitude + latBuffer;
    final south = cameraInfo.latitude - latBuffer;
    final east = cameraInfo.longitude + lonBuffer;
    final west = cameraInfo.longitude - lonBuffer;

    // Check if viewport has changed significantly (avoid redundant calls)
    if (_lastAvailableMapsNorth != null &&
        (north - _lastAvailableMapsNorth!).abs() < 0.01 &&
        (south - _lastAvailableMapsSouth!).abs() < 0.01 &&
        (east - _lastAvailableMapsEast!).abs() < 0.01 &&
        (west - _lastAvailableMapsWest!).abs() < 0.01) {
      debugPrint('🗺️ CoreMapView: Viewport unchanged, skipping');
      return;
    }

    // Update last viewport
    _lastAvailableMapsNorth = north;
    _lastAvailableMapsSouth = south;
    _lastAvailableMapsEast = east;
    _lastAvailableMapsWest = west;

    debugPrint('🗺️ CoreMapView: Viewport bounds - N:$north, S:$south, E:$east, W:$west');

    // Get ALL states that intersect this viewport
    final statesInViewport = _getStatesForViewport(north, south, east, west);
    if (statesInViewport.isEmpty || !mounted) {
      debugPrint('🗺️ CoreMapView: No states found for viewport');
      if (mounted) {
        setState(() {
          _availableMaps = [];
        });
      }
      return;
    }
    debugPrint('🗺️ CoreMapView: Detected states in viewport: ${statesInViewport.join(", ")}');

    // Increment request ID to invalidate any pending requests
    _availableMapsRequestId++;
    final thisRequestId = _availableMapsRequestId;
    debugPrint('🗺️ CoreMapView: Starting request #$thisRequestId for states: ${statesInViewport.join(", ")}');

    try {
      final detectionService = QuadrangleDetectionService.instance;
      final allSuggestions = <QuadrangleSuggestion>[];

      // Check each state in the viewport for available maps
      for (final state in statesInViewport) {
        // Check if this request is still current before each state query
        if (thisRequestId != _availableMapsRequestId) {
          debugPrint('🗺️ CoreMapView: Request #$thisRequestId superseded by #$_availableMapsRequestId, aborting');
          return;
        }

        final suggestions = await detectionService.findSuggestionsForViewport(
          stateCode: state,
          west: west,
          south: south,
          east: east,
          north: north,
          ignoreCooldown: true, // Filter panel always shows available maps
        );
        allSuggestions.addAll(suggestions);
      }

      // Check again before updating state (another request may have started during the last query)
      if (thisRequestId != _availableMapsRequestId) {
        debugPrint('🗺️ CoreMapView: Request #$thisRequestId superseded by #$_availableMapsRequestId after completion, discarding results');
        return;
      }

      // Sort by coverage (highest first) and limit to top results
      allSuggestions.sort((a, b) => b.coverage.compareTo(a.coverage));
      final topSuggestions = allSuggestions.take(5).toList();

      debugPrint('🗺️ CoreMapView: Request #$thisRequestId completed with ${topSuggestions.length} available maps');

      if (mounted) {
        setState(() {
          _availableMaps = topSuggestions;
        });
      }
    } catch (e) {
      debugPrint('❌ CoreMapView: Request #$thisRequestId failed: $e');
    }
  }

  /// State bounding boxes for all US states
  static const _stateBounds = {
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
  };

  /// Get all states that intersect the given viewport bounds
  List<String> _getStatesForViewport(double north, double south, double east, double west) {
    final states = <String>[];

    for (final entry in _stateBounds.entries) {
      final bounds = entry.value;
      // Check if state bounding box intersects viewport
      final stateNorth = bounds['north']!;
      final stateSouth = bounds['south']!;
      final stateEast = bounds['east']!;
      final stateWest = bounds['west']!;

      // Two rectangles intersect if they overlap in both dimensions
      final intersectsLat = north >= stateSouth && south <= stateNorth;
      final intersectsLon = east >= stateWest && west <= stateEast;

      if (intersectsLat && intersectsLon) {
        states.add(entry.key);
      }
    }

    return states;
  }


  /// Handle download request for an available historical map
  Future<void> _handleDownloadAvailableMap(QuadrangleSuggestion suggestion) async {
    debugPrint('🗺️ CoreMapView: Download requested for ${suggestion.title}');

    // Don't allow multiple downloads
    if (_isDownloadingQuad) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A download is already in progress'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Close the filter panel and start download
    setState(() {
      _showLandFilterPanel = false;
      _isDownloadingQuad = true;
    });
    widget.onFilterPanelVisibilityChanged?.call(false);

    // Show download started snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${suggestion.title}...'),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 2),
      ),
    );

    // Perform the download
    final downloadService = QuadrangleDownloadService.instance;
    final result = await downloadService.downloadQuadrangle(
      stateCode: suggestion.stateCode,
      eraId: suggestion.era.id,
      quad: suggestion.quad,
    );

    if (!mounted) return;

    // Reset download state
    setState(() {
      _isDownloadingQuad = false;
    });

    // Show result and refresh available maps
    switch (result) {
      case QuadrangleDownloadSuccess(:final filePath, :final sizeBytes):
        // Create a DownloadedHistoricalMap so it integrates with the existing system
        // Use a layerId that's unique per quadrangle: quad_{eraId}_{quadId}
        final layerId = 'quad_${suggestion.era.id}_${suggestion.quad.id}';
        final downloadedMap = DownloadedHistoricalMap(
          stateCode: suggestion.stateCode.toUpperCase(),
          layerId: layerId,
          name: '${suggestion.quad.name} (${suggestion.quad.year})',
          era: suggestion.era.name,
          filePath: filePath,
          sizeBytes: sizeBytes,
          downloadedAt: DateTime.now(),
        );

        // Add to the historical maps provider so it shows in the filter panel
        await ref.read(historicalMapsProvider.notifier).addDownloadedMap(downloadedMap);

        // Convert QuadrangleBounds to HistoricalMapBounds for zoom
        final zoomBounds = HistoricalMapBounds(
          west: suggestion.quad.bounds.west,
          south: suggestion.quad.bounds.south,
          east: suggestion.quad.bounds.east,
          north: suggestion.quad.bounds.north,
          centerLng: suggestion.quad.bounds.centerLng,
          centerLat: suggestion.quad.bounds.centerLat,
        );

        // Enable and zoom to the newly downloaded map
        await ref.read(historicalMapsProvider.notifier).enableMapWithZoom(
          suggestion.stateCode,
          layerId,
          bounds: zoomBounds,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded ${suggestion.quad.name}'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh available maps list (the downloaded one should no longer appear)
        _loadAvailableMapsForCurrentView();
      case QuadrangleDownloadError(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $message'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Future<void> _loadTrailsDataForCurrentView() async {
    // On mobile, check _mapboxMap. On desktop, check _isMapFullyReady
    if (!_isDesktop && _mapboxMap == null) return;
    if (_isDesktop && !_isMapFullyReady) return;

    final cameraInfo = await _getCameraInfo();
    if (cameraInfo == null) return; // Map not ready yet
    // Check mounted after await to prevent using ref when widget is disposed
    if (!mounted) return;

    final actualZoom = cameraInfo.zoom;

    if (actualZoom < kMinZoomForTrailData) {
      if (_trails.isNotEmpty || _allStateTrails.isNotEmpty) {
        setState(() {
          _trails = [];
          _allStateTrails = [];
          _cachedTrailsOverlay = null;
          _selectedTrailGroup = null;
        });
      }
      return;
    }

    try {
      final viewportBounds = await _getViewportBounds();
      if (viewportBounds == null || !mounted) return;

      final bufferedBounds = _expandBoundsWithBuffer(
        north: viewportBounds.north,
        south: viewportBounds.south,
        east: viewportBounds.east,
        west: viewportBounds.west,
      );

      final isPremium = ref.read(isPremiumProvider);
      if (!isPremium) {
        if (mounted) setState(() => _trails = []);
        return;
      }

      final int limit;
      if (actualZoom >= 12) {
        limit = 5000;
      } else if (actualZoom >= 10) {
        limit = 3000;
      } else {
        limit = 1500;
      }

      final trailsData = await BFFMappingService.instance.getTrailsData(
        northBound: bufferedBounds.north,
        southBound: bufferedBounds.south,
        eastBound: bufferedBounds.east,
        westBound: bufferedBounds.west,
        limit: limit,
      );
      if (!mounted) return;

      final trailFilter = ref.read(trailFilterProvider);
      final filteredTrails = trailsData.where(trailFilter.passes).toList();

      // Viewport filter
      final north = viewportBounds.north;
      final south = viewportBounds.south;
      final east = viewportBounds.east;
      final west = viewportBounds.west;

      final viewportFilteredTrails = filteredTrails.where((trail) {
        return trail.geometry.intersectsBounds(
          northBound: north,
          southBound: south,
          eastBound: east,
          westBound: west,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _trails = viewportFilteredTrails;
          _allStateTrails = filteredTrails;
          if (_selectedTrailGroup != null &&
              !filteredTrails.any((t) => _selectedTrailGroup!.segments.any((s) => s.id == t.id))) {
            _selectedTrailGroup = null;
          }
        });

        // Update desktop map overlays if on desktop
        if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
          _updateDesktopOverlays();
        }
      }
    } catch (e) {
      debugPrint('❌ CoreMapView: Failed to load trails: $e');
    }
  }

  Future<void> _loadHistoricalPlacesDataForCurrentView() async {
    // On mobile, check _mapboxMap. On desktop, check _isMapFullyReady
    if (!_isDesktop && _mapboxMap == null) return;
    if (_isDesktop && !_isMapFullyReady) return;

    final cameraInfo = await _getCameraInfo();
    if (cameraInfo == null) return; // Map not ready yet
    // Check mounted after await to prevent using ref when widget is disposed
    if (!mounted) return;

    final actualZoom = cameraInfo.zoom;

    if (actualZoom < kMinZoomForTrailData) {
      if (_historicalPlaces.isNotEmpty) {
        setState(() {
          _historicalPlaces = [];
          _cachedHistoricalPlacesOverlay = null;
        });
      }
      return;
    }

    final isVisible = ref.read(historicalPlacesVisibilityProvider);
    if (!isVisible) {
      if (_historicalPlaces.isNotEmpty) {
        setState(() {
          _historicalPlaces = [];
          _cachedHistoricalPlacesOverlay = null;
        });
      }
      return;
    }

    final isPremium = ref.read(isPremiumProvider);
    if (!isPremium) return;

    try {
      final viewportBounds = await _getViewportBounds();
      if (viewportBounds == null || !mounted) return;

      final bufferedBounds = _expandBoundsWithBuffer(
        north: viewportBounds.north,
        south: viewportBounds.south,
        east: viewportBounds.east,
        west: viewportBounds.west,
      );

      final landBounds = LandBounds(
        north: bufferedBounds.north,
        south: bufferedBounds.south,
        east: bufferedBounds.east,
        west: bufferedBounds.west,
      );

      final placesAsync = await ref.read(historicalPlacesDataProvider(landBounds).future);

      if (mounted) {
        setState(() {
          _historicalPlaces = placesAsync;
        });

        // Update desktop map overlays if on desktop
        if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
          _updateDesktopOverlays();
        }
      }
    } catch (e) {
      debugPrint('❌ CoreMapView: Failed to load historical places: $e');
    }
  }

  Future<void> _loadCellTowersDataForCurrentView() async {
    debugPrint('📶 _loadCellTowersDataForCurrentView called');
    // On mobile, check _mapboxMap. On desktop, check _isMapFullyReady
    if (!_isDesktop && _mapboxMap == null) {
      debugPrint('📶 Skipping - map not ready (mobile)');
      return;
    }
    if (_isDesktop && !_isMapFullyReady) {
      debugPrint('📶 Skipping - map not ready (desktop)');
      return;
    }

    final cameraInfo = await _getCameraInfo();
    if (cameraInfo == null) {
      debugPrint('📶 Skipping - camera info null');
      return; // Map not ready yet
    }
    // Check mounted after await to prevent using ref when widget is disposed
    if (!mounted) return;

    final actualZoom = cameraInfo.zoom;

    // Cell towers need reasonable zoom to be useful
    if (actualZoom < kMinZoomForCellData) {
      debugPrint('📶 Skipping - zoom too low ($actualZoom < $kMinZoomForCellData)');
      if (_cellTowers.isNotEmpty || _offscreenTowerIndicators.isNotEmpty) {
        setState(() {
          _cellTowers = [];
          _offscreenTowerIndicators = [];
          _cachedCellCoverageOverlay = null;
        });
      }
      return;
    }

    final isVisible = ref.read(cellCoverageVisibilityProvider);
    if (!isVisible) {
      debugPrint('📶 Skipping - cell coverage not visible');
      if (_cellTowers.isNotEmpty || _offscreenTowerIndicators.isNotEmpty) {
        setState(() {
          _cellTowers = [];
          _offscreenTowerIndicators = [];
          _cachedCellCoverageOverlay = null;
        });
      }
      return;
    }

    final isPremium = ref.read(isPremiumProvider);
    if (!isPremium) {
      debugPrint('📶 Skipping - not premium');
      return;
    }

    try {
      final viewportBounds = await _getViewportBounds();
      if (viewportBounds == null || !mounted) {
        debugPrint('📶 Skipping - viewport bounds null');
        return;
      }

      // For cell towers, we need to expand bounds by the maximum coverage radius
      // so towers outside the viewport (but whose coverage circles extend into it) are included
      final centerLat = (viewportBounds.north + viewportBounds.south) / 2;
      const latBuffer = kMaxCellTowerRangeMeters / kMetersPerDegreeLat;
      // Longitude degrees per meter varies with latitude
      final metersPerDegreeLon = kMetersPerDegreeLat * cos(centerLat * pi / 180);
      final lonBuffer = kMaxCellTowerRangeMeters / metersPerDegreeLon;

      final cellBounds = LandBounds(
        north: (viewportBounds.north + latBuffer).clamp(-90.0, 90.0),
        south: (viewportBounds.south - latBuffer).clamp(-90.0, 90.0),
        east: (viewportBounds.east + lonBuffer).clamp(-180.0, 180.0),
        west: (viewportBounds.west - lonBuffer).clamp(-180.0, 180.0),
      );

      debugPrint('📶 Fetching towers for expanded bounds: N:${cellBounds.north.toStringAsFixed(4)}, S:${cellBounds.south.toStringAsFixed(4)}, E:${cellBounds.east.toStringAsFixed(4)}, W:${cellBounds.west.toStringAsFixed(4)} (added ${(latBuffer * 111).toStringAsFixed(1)}km buffer)');

      final towersAsync = await ref.read(cellCoverageDataProvider(cellBounds).future);

      if (mounted) {
        final previousCount = _cellTowers.length;
        setState(() {
          _cellTowers = towersAsync;
        });

        debugPrint('📶 CoreMapView: Loaded ${_cellTowers.length} cell towers for viewport (was $previousCount)');

        // Also load off-screen tower indicators for edge display
        try {
          // Convert viewport record to LandBounds for the provider
          final indicatorBounds = LandBounds(
            north: viewportBounds.north,
            south: viewportBounds.south,
            east: viewportBounds.east,
            west: viewportBounds.west,
          );
          final offscreenIndicators = await ref.read(
            offscreenTowerIndicatorsProvider(indicatorBounds).future,
          );
          if (mounted) {
            setState(() {
              _offscreenTowerIndicators = offscreenIndicators;
            });
          }
        } catch (e) {
          debugPrint('📶 CoreMapView: Failed to load off-screen indicators: $e');
        }

        // Update desktop map overlays if on desktop
        if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
          _updateDesktopOverlays();
        }
      }
    } catch (e) {
      debugPrint('❌ CoreMapView: Failed to load cell towers: $e');
    }
  }

  Future<void> _loadCustomMarkersDataForCurrentView() async {
    // On mobile, check _mapboxMap. On desktop, check _isMapFullyReady
    if (!_isDesktop && _mapboxMap == null) return;
    if (_isDesktop && !_isMapFullyReady) return;

    final cameraInfo = await _getCameraInfo();
    if (cameraInfo == null) return; // Map not ready yet
    // Check mounted after await to prevent using ref when widget is disposed
    if (!mounted) return;

    final isVisible = ref.read(customMarkersVisibilityProvider);
    if (!isVisible) {
      if (_customMarkers.isNotEmpty) {
        setState(() {
          _customMarkers = [];
          _cachedCustomMarkersOverlay = null;
        });
      }
      return;
    }

    try {
      final viewportBounds = await _getViewportBounds();
      if (viewportBounds == null || !mounted) return;

      final bufferedBounds = _expandBoundsWithBuffer(
        north: viewportBounds.north,
        south: viewportBounds.south,
        east: viewportBounds.east,
        west: viewportBounds.west,
      );

      final landBounds = LandBounds(
        north: bufferedBounds.north,
        south: bufferedBounds.south,
        east: bufferedBounds.east,
        west: bufferedBounds.west,
      );

      final markersAsync = await ref.read(customMarkersDataProvider(landBounds).future);

      if (mounted) {
        setState(() {
          _customMarkers = markersAsync;
        });
      }
    } catch (e) {
      debugPrint('❌ CoreMapView: Failed to load custom markers: $e');
    }
  }

  Future<void> _loadSessionMarkersDataForCurrentView() async {
    // On mobile, check _mapboxMap. On desktop, check _isMapFullyReady
    if (!_isDesktop && _mapboxMap == null) return;
    if (_isDesktop && !_isMapFullyReady) return;
    if (widget.sessionId == null) return;

    final cameraInfo = await _getCameraInfo();
    if (cameraInfo == null) return; // Map not ready yet
    // Check mounted after await to prevent using ref when widget is disposed
    if (!mounted) return;

    final isVisible = ref.read(sessionMarkersVisibilityProvider);
    if (!isVisible) {
      if (_sessionMarkers.isNotEmpty) {
        setState(() {
          _sessionMarkers = [];
          _cachedSessionMarkersOverlay = null;
        });
      }
      return;
    }

    try {
      final viewportBounds = await _getViewportBounds();
      if (viewportBounds == null || !mounted) return;

      final bufferedBounds = _expandBoundsWithBuffer(
        north: viewportBounds.north,
        south: viewportBounds.south,
        east: viewportBounds.east,
        west: viewportBounds.west,
      );

      final landBounds = LandBounds(
        north: bufferedBounds.north,
        south: bufferedBounds.south,
        east: bufferedBounds.east,
        west: bufferedBounds.west,
      );

      final params = SessionMarkersParams(
        bounds: landBounds,
        sessionId: widget.sessionId!,
      );

      final markersAsync = await ref.read(sessionMarkersDataProvider(params).future);

      if (mounted) {
        setState(() {
          _sessionMarkers = markersAsync;
        });
      }
    } catch (e) {
      debugPrint('❌ CoreMapView: Failed to load session markers: $e');
    }
  }

  ({double north, double south, double east, double west}) _expandBoundsWithBuffer({
    required double north,
    required double south,
    required double east,
    required double west,
  }) {
    final latBuffer = (north - south) * kViewportBufferMultiplier;
    final lonBuffer = (east - west) * kViewportBufferMultiplier;

    return (
      north: (north + latBuffer).clamp(-90.0, 90.0),
      south: (south - latBuffer).clamp(-90.0, 90.0),
      east: (east + lonBuffer).clamp(-180.0, 180.0),
      west: (west - lonBuffer).clamp(-180.0, 180.0),
    );
  }

  // ============================================================================
  // Overlay builders
  // ============================================================================

  LandOwnershipOverlay _getLandOverlay(LandOwnershipFilter filter, double opacity) {
    final dataChanged = _cachedLandOverlay == null ||
        !_areLandParcelsEqual(_cachedLandOverlay!.landParcels, _landParcels);
    final filterChanged = _cachedLandOverlay != null && _cachedLandOverlay!.filter != filter;

    if (dataChanged || filterChanged) {
      _cachedLandOverlay = LandOwnershipOverlay(
        landParcels: _landParcels,
        filter: filter,
        onParcelTap: widget.disableOverlayTapHandlers ? null : _onParcelTapped,
        fillOpacity: opacity,
        strokeOpacity: opacity * 2,
      );
    }
    return _cachedLandOverlay!;
  }

  /// Get or create cached highlighted parcel overlay
  /// Only recreates when the selected parcel changes
  HighlightedLandParcelOverlay _getHighlightedParcelOverlay(LandOwnership parcel) {
    if (_cachedHighlightedParcelOverlay == null || _cachedHighlightedParcelId != parcel.id) {
      _cachedHighlightedParcelOverlay = HighlightedLandParcelOverlay(parcel: parcel);
      _cachedHighlightedParcelId = parcel.id;
    }
    return _cachedHighlightedParcelOverlay!;
  }

  /// Get or create cached highlighted trail overlay
  /// Only recreates when the selected trail group changes
  HighlightedTrailOverlay _getHighlightedTrailOverlay(TrailGroup trailGroup) {
    // Use the representative trail's ID as the cache key
    final trailId = trailGroup.representativeTrail.id;
    if (_cachedHighlightedTrailOverlay == null || _cachedHighlightedTrailId != trailId) {
      _cachedHighlightedTrailOverlay = HighlightedTrailOverlay(trailGroup: trailGroup);
      _cachedHighlightedTrailId = trailId;
    }
    return _cachedHighlightedTrailOverlay!;
  }

  bool _areLandParcelsEqual(List<LandOwnership> oldParcels, List<LandOwnership> newParcels) {
    if (oldParcels.length != newParcels.length) return false;
    final oldIds = oldParcels.map((p) => p.id).toSet();
    final newIds = newParcels.map((p) => p.id).toSet();
    return oldIds.difference(newIds).isEmpty && newIds.difference(oldIds).isEmpty;
  }

  TrailsOverlay _getTrailsOverlay(double opacity) {
    bool needsRecreate = _cachedTrailsOverlay == null ||
        _cachedTrailsOverlay!.trails.length != _trails.length ||
        _cachedTrailsOverlay!.lineOpacity != opacity;

    if (!needsRecreate && _trails.isNotEmpty && _cachedTrailsOverlay!.trails.isNotEmpty) {
      final oldFirst = _cachedTrailsOverlay!.trails.first.id;
      final oldLast = _cachedTrailsOverlay!.trails.last.id;
      final newFirst = _trails.first.id;
      final newLast = _trails.last.id;
      needsRecreate = oldFirst != newFirst || oldLast != newLast;
    }

    if (needsRecreate) {
      _cachedTrailsOverlay = TrailsOverlay(
        trails: _trails,
        lineOpacity: opacity,
        lineWidth: 4.0,
        onTrailTap: widget.disableOverlayTapHandlers ? null : _onTrailTapped,
      );
    }
    return _cachedTrailsOverlay!;
  }

  HistoricalPlacesOverlay _getHistoricalPlacesOverlay(HistoricalPlaceFilter filter) {
    final filteredPlaces = _historicalPlaces.where((place) => filter.passes(place)).toList();

    bool needsRecreate = _cachedHistoricalPlacesOverlay == null ||
        _cachedHistoricalPlacesOverlay!.places.length != filteredPlaces.length;

    if (!needsRecreate && filteredPlaces.isNotEmpty && _cachedHistoricalPlacesOverlay!.places.isNotEmpty) {
      final oldFirst = _cachedHistoricalPlacesOverlay!.places.first.id;
      final oldLast = _cachedHistoricalPlacesOverlay!.places.last.id;
      final newFirst = filteredPlaces.first.id;
      final newLast = filteredPlaces.last.id;
      needsRecreate = oldFirst != newFirst || oldLast != newLast;
    }

    if (needsRecreate) {
      _cachedHistoricalPlacesOverlay = HistoricalPlacesOverlay(
        places: filteredPlaces,
        onPlaceTap: widget.disableOverlayTapHandlers ? null : _onHistoricalPlaceSelected,
      );
    }
    return _cachedHistoricalPlacesOverlay!;
  }

  CustomMarkersOverlay _getCustomMarkersOverlay(CustomMarkerFilter filter) {
    // Filter by category, and filter session markers appropriately:
    // - Global markers (sessionId == null) are always shown
    // - Session markers are only shown when viewing that specific session
    //   (in the session markers overlay, not here)
    final filteredMarkers = _customMarkers
        .where((marker) => filter.enabledCategories.contains(marker.category))
        .where((marker) => marker.sessionId == null || marker.sessionId == widget.sessionId)
        .toList();

    bool needsRecreate = _cachedCustomMarkersOverlay == null ||
        _cachedCustomMarkersOverlay!.markers.length != filteredMarkers.length;

    if (!needsRecreate && filteredMarkers.isNotEmpty && _cachedCustomMarkersOverlay!.markers.isNotEmpty) {
      final oldFirst = _cachedCustomMarkersOverlay!.markers.first.id;
      final oldLast = _cachedCustomMarkersOverlay!.markers.last.id;
      final newFirst = filteredMarkers.first.id;
      final newLast = filteredMarkers.last.id;
      needsRecreate = oldFirst != newFirst || oldLast != newLast;
    }

    if (needsRecreate) {
      _cachedCustomMarkersOverlay = CustomMarkersOverlay(
        markers: filteredMarkers,
        onMarkerTap: widget.disableOverlayTapHandlers ? null : _onCustomMarkerSelected,
      );
    }
    return _cachedCustomMarkersOverlay!;
  }

  CustomMarkersOverlay _getSessionMarkersOverlay(Set<CustomMarkerCategory> enabledCategories) {
    final filteredMarkers = _sessionMarkers
        .where((marker) => enabledCategories.contains(marker.category))
        .toList();

    bool needsRecreate = _cachedSessionMarkersOverlay == null ||
        _cachedSessionMarkersOverlay!.markers.length != filteredMarkers.length;

    if (!needsRecreate && filteredMarkers.isNotEmpty && _cachedSessionMarkersOverlay!.markers.isNotEmpty) {
      final oldFirst = _cachedSessionMarkersOverlay!.markers.first.id;
      final oldLast = _cachedSessionMarkersOverlay!.markers.last.id;
      final newFirst = filteredMarkers.first.id;
      final newLast = filteredMarkers.last.id;
      needsRecreate = oldFirst != newFirst || oldLast != newLast;
    }

    if (needsRecreate) {
      _cachedSessionMarkersOverlay = CustomMarkersOverlay(
        markers: filteredMarkers,
        onMarkerTap: widget.disableOverlayTapHandlers ? null : _onCustomMarkerSelected,
        idPrefix: 'session-markers', // Unique prefix to avoid conflict with custom-markers
      );
    }
    return _cachedSessionMarkersOverlay!;
  }

  CellCoverageOverlay _getCellCoverageOverlay(CellCoverageFilter filter) {
    // Filter towers by enabled radio types
    final filteredTowers = _cellTowers
        .where((tower) => filter.enabledTypes.contains(tower.radioType))
        .toList();

    bool needsRecreate = _cachedCellCoverageOverlay == null ||
        _cachedCellCoverageOverlay!.towers.length != filteredTowers.length;

    if (!needsRecreate && filteredTowers.isNotEmpty && _cachedCellCoverageOverlay!.towers.isNotEmpty) {
      final oldFirst = _cachedCellCoverageOverlay!.towers.first.id;
      final oldLast = _cachedCellCoverageOverlay!.towers.last.id;
      final newFirst = filteredTowers.first.id;
      final newLast = filteredTowers.last.id;
      needsRecreate = oldFirst != newFirst || oldLast != newLast;
    }

    if (needsRecreate) {
      _cachedCellCoverageOverlay = CellCoverageOverlay(
        towers: filteredTowers,
        onTowerTap: widget.disableOverlayTapHandlers ? null : _onCellTowerSelected,
      );
    }
    return _cachedCellCoverageOverlay!;
  }

  void _onCellTowerSelected(CellTower tower) {
    debugPrint('📶 Selected cell tower: ${tower.carrier ?? 'Unknown'} ${tower.radioType.displayName}');
    // TODO(cell-coverage): Show cell tower detail sheet with carrier, signal type, range
  }

  BreadcrumbOverlay _getBreadcrumbOverlay(List<geo.Position> breadcrumbs) {
    // Only recreate overlay if breadcrumb count actually changed
    // This prevents unnecessary overlay updates during playback pause
    if (_cachedBreadcrumbOverlay == null || _cachedBreadcrumbsLength != breadcrumbs.length) {
      _cachedBreadcrumbOverlay = BreadcrumbOverlay(breadcrumbs: breadcrumbs);
      _cachedBreadcrumbsLength = breadcrumbs.length;
    }
    return _cachedBreadcrumbOverlay!;
  }

  WaypointOverlay _getWaypointOverlay(List<Waypoint> waypoints) {
    if (_cachedWaypointOverlay == null || _cachedWaypointOverlay!.waypoints != waypoints) {
      _cachedWaypointOverlay = WaypointOverlay(
        waypoints: waypoints,
        onWaypointTap: widget.onWaypointTap,
      );
    }
    return _cachedWaypointOverlay!;
  }

  BreadcrumbOverlay _getPlannedRouteOverlay(PlannedRoute route) {
    // Cache the planned route overlay to prevent rebuild loops
    if (_cachedPlannedRouteOverlay == null || _cachedPlannedRouteId != route.id) {
      final positions = route.points
          .map((PlannedRoutePoint point) => geo.Position(
                latitude: point.latitude,
                longitude: point.longitude,
                timestamp: DateTime.now(),
                accuracy: 0,
                altitude: point.elevation ?? 0,
                altitudeAccuracy: 0,
                heading: 0,
                headingAccuracy: 0,
                speed: 0,
                speedAccuracy: 0,
              ))
          .toList();
      _cachedPlannedRouteOverlay = BreadcrumbOverlay(
        breadcrumbs: positions,
        lineColor: const Color(0xFF9C27B0), // Purple for planned route
        lineWidth: 3.0,
      );
      _cachedPlannedRouteId = route.id;
    }
    return _cachedPlannedRouteOverlay!;
  }

  // ============================================================================
  // Tap handlers
  // ============================================================================

  void _onParcelTapped(LandOwnership parcel) {
    debugPrint('🎯 Land parcel selected: ${parcel.ownerName}');
    // Set state to show highlighted overlay on map
    setState(() {
      _selectedParcel = parcel;
      _selectedTrailGroup = null;
    });
    // Show modal bottom sheet (overlays entire screen including playback controls)
    _showParcelDetailSheet(parcel);
  }

  void _showParcelDetailSheet(LandOwnership parcel) {
    // On desktop, use larger initial size to take advantage of screen space
    final initialSize = _isDesktop ? 0.7 : 0.4;
    final snapSizes = _isDesktop ? const [0.5, 0.7, 0.9] : const [0.4, 0.7, 0.9];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: initialSize,
          minChildSize: 0.2,
          maxChildSize: 0.9,
          snap: true,
          snapSizes: snapSizes,
          builder: (context, scrollController) => GestureDetector(
            onTap: () {}, // Prevent taps on sheet from dismissing
            child: LandParcelBottomSheet(
              parcel: parcel,
              onDismiss: () {
                Navigator.pop(context);
              },
              scrollController: scrollController,
            ),
          ),
        ),
      ),
    ).whenComplete(_onDismissParcel);
  }

  void _onDismissParcel() {
    setState(() {
      _selectedParcel = null;
      _cachedHighlightedParcelOverlay = null;
      _cachedHighlightedParcelId = null;
    });
    // Clear highlight on desktop map
    if (_isDesktop) {
      _clearHighlightOnDesktop();
    }
  }

  Future<void> _onTrailTapped(Trail trail) async {
    final trailsForGrouping = _allStateTrails.isNotEmpty ? _allStateTrails : _trails;

    if (trail.hasRelation && trail.osmRelationId != null) {
      final localGroup = TrailGroup.fromTrailList(
        tappedTrail: trail,
        allTrails: trailsForGrouping,
      );
      setState(() {
        _selectedTrailGroup = localGroup;
        _selectedParcel = null;
      });
      // Show modal bottom sheet immediately with local data
      _showTrailDetailSheet(localGroup);

      // Fetch full data from BFF in background
      final bffGroup = await BFFMappingService.instance.getTrailGroup(
        relationId: trail.osmRelationId!,
        tappedSegment: trail,
      );

      if (bffGroup != null && mounted) {
        setState(() {
          _selectedTrailGroup = bffGroup;
        });
      }
    } else {
      final trailGroup = TrailGroup.fromTrailList(
        tappedTrail: trail,
        allTrails: trailsForGrouping,
      );
      setState(() {
        _selectedTrailGroup = trailGroup;
        _selectedParcel = null;
      });
      // Show modal bottom sheet (overlays entire screen including playback controls)
      _showTrailDetailSheet(trailGroup);
    }
  }

  void _showTrailDetailSheet(TrailGroup trailGroup) {
    // On desktop, use larger initial size to take advantage of screen space
    final initialSize = _isDesktop ? 0.7 : 0.4;
    final snapSizes = _isDesktop ? const [0.5, 0.7, 0.9] : const [0.4, 0.7, 0.9];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: initialSize,
          minChildSize: 0.2,
          maxChildSize: 0.9,
          snap: true,
          snapSizes: snapSizes,
          builder: (context, scrollController) => GestureDetector(
            onTap: () {}, // Prevent taps on sheet from dismissing
            child: TrailBottomSheet(
              trailGroup: trailGroup,
              onDismiss: () {
                Navigator.pop(context);
              },
              scrollController: scrollController,
            ),
          ),
        ),
      ),
    ).whenComplete(_onDismissTrail);
  }

  void _onDismissTrail() {
    setState(() {
      _selectedTrailGroup = null;
      _cachedHighlightedTrailOverlay = null;
      _cachedHighlightedTrailId = null;
    });
  }

  void _onHistoricalPlaceSelected(HistoricalPlace place) {
    showHistoricalPlaceDetailSheet(
      context,
      place,
      onNavigate: () {
        Navigator.pop(context);
        _navigateToHistoricalPlace(place);
      },
      onAddWaypoint: () {
        Navigator.pop(context);
        _showHistoricalPlaceInfo(place);
      },
    );
  }

  void _navigateToHistoricalPlace(HistoricalPlace place) {
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(place.longitude, place.latitude)),
        zoom: 15.0,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  void _showHistoricalPlaceInfo(HistoricalPlace place) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${place.typeMetadata.emoji} ${place.featureName}\n'
          'Location: ${place.latitude.toStringAsFixed(5)}, ${place.longitude.toStringAsFixed(5)}',
        ),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            final coords = '${place.latitude}, ${place.longitude}';
            Clipboard.setData(ClipboardData(text: coords));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Coordinates copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onCustomMarkerSelected(CustomMarker marker) {
    showCustomMarkerDetailSheet(
      context,
      ref,
      marker,
      onNavigate: () {
        Navigator.pop(context);
        _navigateToCustomMarker(marker);
      },
      onEdit: () async {
        Navigator.pop(context);
        await _editCustomMarker(marker);
      },
      onDelete: () async {
        Navigator.pop(context);
        await _deleteCustomMarker(marker);
      },
    );
  }

  void _navigateToCustomMarker(CustomMarker marker) {
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(marker.longitude, marker.latitude)),
        zoom: 15.0,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _editCustomMarker(CustomMarker marker) async {
    final updatedMarker = await showCustomMarkerEditSheet(context, marker: marker);
    if (updatedMarker != null && mounted) {
      setState(() {
        _customMarkers = _customMarkers.map((m) => m.id == updatedMarker.id ? updatedMarker : m).toList();
        _cachedCustomMarkersOverlay = null;
      });
    }
  }

  Future<void> _deleteCustomMarker(CustomMarker marker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Marker'),
        content: Text('Are you sure you want to delete "${marker.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final operations = ref.read(customMarkerOperationsProvider.notifier);
      final success = await operations.deleteMarker(marker.id);
      if (success && mounted) {
        setState(() {
          _customMarkers = _customMarkers.where((m) => m.id != marker.id).toList();
          _cachedCustomMarkersOverlay = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${marker.name}"')),
        );
      }
    }
  }

  Future<void> _onMapLongPress(Point point) async {
    final latitude = point.coordinates.lat.toDouble();
    final longitude = point.coordinates.lng.toDouble();

    final marker = await showCustomMarkerCreationSheet(
      context,
      latitude: latitude,
      longitude: longitude,
    );

    if (marker != null && mounted) {
      setState(() {
        _customMarkers = [..._customMarkers, marker];
        _cachedCustomMarkersOverlay = null;
      });
    }
  }

  // ============================================================
  // Desktop Map Overlay Methods
  // ============================================================

  /// Update all overlays on the desktop map
  Future<void> _updateDesktopOverlays() async {
    final desktopMap = _desktopMapKey.currentState;
    if (desktopMap == null) return;

    // Read visibility settings
    final landOverlayVisible = ref.read(landOverlayVisibilityProvider);
    final trailsVisible = ref.read(trailsOverlayVisibilityProvider);
    final historicalPlacesVisible = ref.read(historicalPlacesVisibilityProvider);
    final landFilter = ref.read(landOwnershipFilterProvider);

    debugPrint('🖥️ Desktop overlay update: land=$landOverlayVisible (${landFilter.enabledTypes.length} types), trails=$trailsVisible, places=$historicalPlacesVisible');
    debugPrint('🖥️ Data counts: landParcels=${_landParcels.length}, trails=${_trails.length}, places=${_historicalPlaces.length}');

    // Update land ownership overlay
    // Must have: parcels loaded, visibility on, AND at least one type enabled
    if (_landParcels.isNotEmpty && landOverlayVisible && landFilter.enabledTypes.isNotEmpty) {
      // Filter parcels based on enabled types and convert to GeoJSON
      final filteredParcels = _landParcels
          .where((p) => landFilter.enabledTypes.contains(p.ownershipType))
          .toList();
      debugPrint('🖥️ Loading land overlay (${filteredParcels.length}/${_landParcels.length} parcels after filter)');
      if (filteredParcels.isNotEmpty) {
        final geojson = DesktopGeoJsonConverter.landOwnershipToGeoJson(filteredParcels);
        await desktopMap.loadLandOwnership(geojson);
      } else {
        await desktopMap.clearLandOwnership();
      }
    } else {
      debugPrint('🖥️ Clearing land overlay (visible=$landOverlayVisible, parcels=${_landParcels.length}, types=${landFilter.enabledTypes.length})');
      await desktopMap.clearLandOwnership();
    }

    // Update trails overlay
    if (_trails.isNotEmpty && trailsVisible) {
      debugPrint('🥾 Desktop: Loading ${_trails.length} trails to WebView');
      final geojson = DesktopGeoJsonConverter.trailsToGeoJson(_trails);
      await desktopMap.loadTrails(geojson);
    } else {
      await desktopMap.clearTrails();
    }

    // Update historical places overlay
    if (_historicalPlaces.isNotEmpty && historicalPlacesVisible) {
      final geojson = DesktopGeoJsonConverter.historicalPlacesToGeoJson(_historicalPlaces);
      await desktopMap.loadHistoricalPlaces(geojson);
    } else {
      await desktopMap.clearHistoricalPlaces();
    }

    // Update custom markers overlay
    final allCustomMarkers = [..._customMarkers, ..._sessionMarkers];
    if (allCustomMarkers.isNotEmpty) {
      final geojson = DesktopGeoJsonConverter.customMarkersToGeoJson(allCustomMarkers);
      await desktopMap.loadCustomMarkers(geojson);
    } else {
      await desktopMap.clearCustomMarkers();
    }

    // Update waypoints overlay
    if (widget.waypoints != null && widget.waypoints!.isNotEmpty) {
      final geojson = DesktopGeoJsonConverter.waypointsToGeoJson(widget.waypoints!);
      await desktopMap.loadWaypoints(geojson);
    } else {
      await desktopMap.clearWaypoints();
    }

    // Update breadcrumbs overlay
    if (widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty) {
      final coordinates = widget.breadcrumbs!
          .map((pos) => [pos.latitude, pos.longitude])
          .toList();
      final geojson = DesktopGeoJsonConverter.breadcrumbsToGeoJson(
        coordinates,
        sessionId: widget.sessionId,
      );
      await desktopMap.loadBreadcrumbs(geojson);
    } else {
      await desktopMap.clearBreadcrumbs();
    }

    // Update cell coverage overlay
    final cellCoverageVisible = ref.read(cellCoverageVisibilityProvider);
    final cellCoverageFilter = ref.read(cellCoverageFilterProvider);
    if (_cellTowers.isNotEmpty && cellCoverageVisible) {
      // Filter towers based on enabled radio types
      final filteredTowers = _cellTowers
          .where((tower) => cellCoverageFilter.enabledTypes.contains(tower.radioType))
          .toList();
      debugPrint('📶 Desktop: Loading ${filteredTowers.length}/${_cellTowers.length} cell towers to WebView');
      final coverageGeojson = DesktopGeoJsonConverter.cellTowerCoverageToGeoJson(filteredTowers);
      final pointsGeojson = DesktopGeoJsonConverter.cellTowerPointsToGeoJson(filteredTowers);
      await desktopMap.loadCellCoverage(coverageGeojson, pointsGeojson);
    } else {
      await desktopMap.clearCellCoverage();
    }

    // NOTE: Historical maps are updated separately via _updateDesktopHistoricalMaps
    // which is called from the historicalMapsProvider listener.
    // We don't call it here to avoid clearing/reloading historical maps
    // every time land/trails/etc visibility changes.
  }

  /// Update the center crosshair visibility on desktop WebView
  /// The crosshair is rendered in HTML/CSS inside the WebView to avoid
  /// Flutter's IgnorePointer not working with platform views (WebView).
  Future<void> _updateDesktopCenterCrosshair() async {
    final desktopMap = _desktopMapKey.currentState;
    if (desktopMap == null || !desktopMap.isMapReady) return;

    final shouldShow = widget.showLandRightsBanner && !widget.hideOverlays;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (shouldShow) {
      await desktopMap.showCenterCrosshair(isDark: isDark);
    } else {
      await desktopMap.hideCenterCrosshair();
    }
  }

  /// Update historical map raster overlays on desktop
  Future<void> _updateDesktopHistoricalMaps(DesktopMapWebViewState desktopMap) async {
    final historicalMapsState = ref.read(historicalMapsProvider);

    // If provider is still loading, set pending flag and return
    // The listener will call us again when provider finishes loading
    if (historicalMapsState.isLoading) {
      debugPrint('🗺️ Desktop historical maps: Provider still loading, setting pending flag');
      _pendingHistoricalMapsLoad = true;
      return;
    }

    // Clear pending flag since we're now processing
    _pendingHistoricalMapsLoad = false;

    final allMaps = historicalMapsState.maps.values.toList();
    final enabledMaps = allMaps.where((m) => m.isEnabled).toList();

    debugPrint('🗺️ Desktop historical maps: ${allMaps.length} total, ${enabledMaps.length} enabled');
    for (final m in allMaps) {
      debugPrint('🗺️   - ${m.layerId}: enabled=${m.isEnabled}');
    }

    // Always clear first to remove any disabled maps, then re-add enabled ones
    // This ensures toggling a map OFF properly removes it
    await desktopMap.clearAllHistoricalMaps();

    if (enabledMaps.isEmpty) {
      debugPrint('🗺️ Desktop: No historical maps enabled');
      return;
    }

    // Start tile server FIRST before any MBTiles operations
    final tileServer = MBTilesTileServer.instance;
    if (!tileServer.isRunning) {
      debugPrint('🌐 Starting MBTiles tile server for desktop historical maps...');
      await tileServer.start();
      debugPrint('🌐 Tile server started on port ${tileServer.port}');
    }

    // Load each enabled historical map
    // Order of operations is critical:
    // 1. Register MBTiles with tile server (opens database)
    // 2. Get tile URL (requires server to be running)
    // 3. Get maxZoom from metadata (requires database to be open)
    // 4. Load on map (requires all of the above)
    for (final mapState in enabledMaps) {
      final filePath = mapState.filePath;
      if (!File(filePath).existsSync()) {
        debugPrint('⚠️ Historical map file not found: $filePath');
        continue;
      }

      // Create a unique ID for this map
      final mapId = '${mapState.stateCode}_${mapState.layerId}';

      // Step 1: Register with tile server (opens the SQLite database)
      debugPrint('🗺️ Registering MBTiles: $mapId');
      await tileServer.registerMBTiles(mapId, filePath);

      // Step 2: Get tile URL template (requires server to be running)
      final tileUrl = tileServer.getTileUrlTemplate(mapId);
      if (tileUrl.isEmpty) {
        debugPrint('⚠️ Failed to get tile URL for $mapId - server not running?');
        continue;
      }

      // Step 3: Get maxzoom from MBTiles metadata
      final maxZoom = await tileServer.getMaxZoom(mapId) ?? 16;

      debugPrint('🗺️ Desktop: Loading historical map $mapId');
      debugPrint('🗺️   Tile URL: $tileUrl');
      debugPrint('🗺️   Max zoom: $maxZoom');
      debugPrint('🗺️   Opacity: ${mapState.opacity}');

      // Step 4: Load on desktop map
      await desktopMap.loadHistoricalMap(mapId, tileUrl, opacity: mapState.opacity, maxZoom: maxZoom);
    }

    debugPrint('✅ Desktop historical maps: Update complete');
  }

  /// Handle land parcel tap on desktop map
  void _handleDesktopLandParcelTap(Map<String, dynamic> properties) {
    final parcelId = properties['id'] as String?;
    if (parcelId == null) return;

    // Find the parcel in our loaded data
    final parcel = _landParcels.cast<LandOwnership?>().firstWhere(
          (p) => p?.id == parcelId,
          orElse: () => null,
        );

    if (parcel != null) {
      // Highlight the parcel on the desktop map
      _highlightParcelOnDesktop(parcel);
      // Use the same handler as mobile
      _onParcelTapped(parcel);
    }
  }

  /// Highlight a parcel on the desktop WebView map
  void _highlightParcelOnDesktop(LandOwnership parcel) {
    if (parcel.polygonCoordinates == null) return;

    final geojson = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'id': parcel.id,
          'geometry': {
            'type': 'Polygon',
            'coordinates': parcel.polygonCoordinates,
          },
          'properties': {
            'id': parcel.id,
          },
        },
      ],
    };

    _desktopMapKey.currentState?.highlightParcel(geojson);
  }

  /// Clear parcel highlight on desktop WebView map
  void _clearHighlightOnDesktop() {
    _desktopMapKey.currentState?.clearHighlight();
  }

  /// Handle trail tap on desktop map
  void _handleDesktopTrailTap(Map<String, dynamic> properties) {
    final trailId = properties['id'] as String?;
    if (trailId == null) return;

    // Find the trail in our loaded data
    final trail = _trails.cast<Trail?>().firstWhere(
          (t) => t?.id == trailId,
          orElse: () => null,
        );

    if (trail != null) {
      // Use the existing trail tap handler which creates the TrailGroup
      _onTrailTapped(trail);
    }
  }

  /// Handle historical place tap on desktop map
  void _handleDesktopHistoricalPlaceTap(Map<String, dynamic> properties) {
    final placeId = properties['id'] as String?;
    if (placeId == null) return;

    // Find the place in our loaded data
    final place = _historicalPlaces.cast<HistoricalPlace?>().firstWhere(
          (p) => p?.id == placeId,
          orElse: () => null,
        );

    if (place != null) {
      _onHistoricalPlaceSelected(place);
    }
  }

  /// Handle custom marker tap on desktop map
  void _handleDesktopCustomMarkerTap(Map<String, dynamic> properties) {
    final markerId = properties['id'] as String?;
    if (markerId == null) return;

    // Find the marker in our loaded data (check both custom markers and session markers)
    CustomMarker? marker = _customMarkers.cast<CustomMarker?>().firstWhere(
          (m) => m?.id == markerId,
          orElse: () => null,
        );

    marker ??= _sessionMarkers.cast<CustomMarker?>().firstWhere(
          (m) => m?.id == markerId,
          orElse: () => null,
        );

    if (marker != null) {
      _onCustomMarkerSelected(marker);
    }
  }

  /// Handle waypoint tap on desktop map
  void _handleDesktopWaypointTap(Map<String, dynamic> properties) {
    final waypointId = properties['id'] as String?;
    if (waypointId == null) return;

    // Find the waypoint in our provided waypoints
    if (widget.waypoints == null) return;

    final waypoint = widget.waypoints!.cast<Waypoint?>().firstWhere(
          (w) => w?.id == waypointId,
          orElse: () => null,
        );

    if (waypoint != null) {
      widget.onWaypointTap?.call(waypoint);
    }
  }
}

/// Planned route data structure
class PlannedRoute {
  const PlannedRoute({
    required this.id,
    required this.name,
    required this.points,
  });

  final String id;
  final String name;
  final List<PlannedRoutePoint> points;
}

/// Single point in a planned route
class PlannedRoutePoint {
  const PlannedRoutePoint({
    required this.latitude,
    required this.longitude,
    this.elevation,
  });

  final double latitude;
  final double longitude;
  final double? elevation;
}
