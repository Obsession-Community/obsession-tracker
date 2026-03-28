import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/map_overlay.dart';
import 'package:obsession_tracker/core/models/mapbox_config.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';
import 'package:obsession_tracker/core/providers/app_settings_provider.dart';
import 'package:obsession_tracker/core/providers/historical_maps_provider.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/core/providers/map_camera_provider.dart';
import 'package:obsession_tracker/core/services/historical_maps_service.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/custom_markers_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/historical_map_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/historical_places_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/land_ownership_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/trails_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/waypoint_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/map_controls_sheet.dart';

/// Reusable Mapbox map widget that can be configured for different use cases
///
/// This widget replaces WaypointMapWidget with a modular, DRY approach.
/// Use MapboxMapConfig to customize behavior for tracking, route planning, etc.
class MapboxMapWidget extends ConsumerStatefulWidget {
  const MapboxMapWidget({
    required this.config,
    super.key,
    this.overlays = const [],
    this.onMapCreated,
    this.onMapViewChanged,
    this.onCameraMoving,
    this.onCameraMovingFast,
    this.onMapTap,
    this.onMapLongPress,
    this.onFollowLocationToggle,
    this.isFollowingLocation = false,
    this.onControlsExpandedChanged,
    this.onAddWaypoint,
    this.onCheckPermissions,
    this.isTrackingActive = false,
    this.showLandRightsBanner = true,
    this.onToggleLandRightsBanner,
    this.hideOverlays = false,
  });

  final MapboxMapConfig config;
  final List<MapOverlayConfig> overlays;
  final ValueChanged<MapboxMap>? onMapCreated;
  final ValueChanged<MapboxMap>? onMapViewChanged;
  /// Called during camera movement (500ms throttle) for data loading
  final ValueChanged<MapboxMap>? onCameraMoving;
  /// Called more frequently during camera movement (200ms throttle) for lightweight UI updates like banner
  final ValueChanged<MapboxMap>? onCameraMovingFast;
  final ValueChanged<Point>? onMapTap;
  final ValueChanged<Point>? onMapLongPress;
  final ValueChanged<bool>? onFollowLocationToggle;
  final bool isFollowingLocation;
  final ValueChanged<bool>? onControlsExpandedChanged;
  /// Callback to open unified waypoint creation (passed through to MapControlsSheet)
  final VoidCallback? onAddWaypoint;
  /// Callback to check land permissions (passed through to MapControlsSheet)
  final VoidCallback? onCheckPermissions;
  /// Whether GPS tracking is currently active
  final bool isTrackingActive;
  /// Whether the land rights banner is visible (passed through to MapControlsSheet)
  final bool showLandRightsBanner;
  /// Callback to toggle land rights banner visibility (passed through to MapControlsSheet)
  final VoidCallback? onToggleLandRightsBanner;
  /// Whether to hide all overlays (HUD, controls, center target) - used when search is active
  final bool hideOverlays;

  @override
  ConsumerState<MapboxMapWidget> createState() => _MapboxMapWidgetState();
}

class _MapboxMapWidgetState extends ConsumerState<MapboxMapWidget> {
  MapboxMap? _mapboxMap;
  bool _isMapReady = false;
  bool _isStyleLoaded = false; // Style must be loaded before adding overlays
  final List<MapOverlay> _loadedOverlays = [];
  bool _rotationEnabled = false; // Default to rotation locked
  late String _currentStyleUri;
  MapStylePreference _stylePreference = MapStylePreference.outdoors; // Persisted preference
  bool _hasInitializedFromSettings = false; // Only initialize from saved settings once
  Timer? _cameraChangeDebounceTimer;
  DateTime? _lastCameraMovingCallback; // Track last continuous callback time (500ms)
  DateTime? _lastCameraMovingFastCallback; // Track last fast callback time (200ms)
  DateTime? _lastMapViewChangedCallback; // Track last onMapViewChanged to enforce max wait
  bool _isReloadingOverlays = false; // Prevent concurrent overlay reloads
  bool _overlaysChangedDuringReload = false; // Track if overlays changed while reloading
  double _currentBearing = 0.0; // Current map bearing for compass display
  MapHudOptions _hudOptions = const MapHudOptions(); // HUD display options
  StreamSubscription<geo.Position>? _locationSubscription; // For follow mode
  bool _isFollowModeCameraMove = false; // Track follow-mode camera moves
  bool _isZoomingToHistoricalMap = false; // Temporarily suppress follow mode when zooming to historical map bounds

  // Track historical maps currently being loaded to prevent concurrent duplicate loads
  final Set<String> _loadingHistoricalMapIds = {};

  // Multi-touch gesture tracking for pinch-to-zoom detection
  int _activePointerCount = 0;
  bool _wasMultiTouch = false;

  // Long-press movement tracking to prevent long-tap during pan
  Offset? _longPressStartPosition;
  bool _hasMovedDuringPress = false;
  static const double _longPressMoveThreshold = 15.0; // pixels

  @override
  void initState() {
    super.initState();
    // Use config style as initial value, will be updated based on saved preference
    _currentStyleUri = widget.config.styleUri;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Settings initialization is handled in build() when appSettingsProvider has data
    // This avoids reading default values before settings are loaded
  }

  @override
  void didUpdateWidget(MapboxMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Debug: trace overlay changes
    final oldTypes = oldWidget.overlays.map((o) => o.type.name).toList();
    final newTypes = widget.overlays.map((o) => o.type.name).toList();
    if (oldTypes.toString() != newTypes.toString()) {
      debugPrint('🔍 didUpdateWidget overlay types changed: $oldTypes → $newTypes');
    }

    // Reload overlays if they changed
    // Always call _reloadOverlaysIfNeeded - it handles the _isReloadingOverlays check internally
    // and sets _overlaysChangedDuringReload to ensure retry after current load completes
    if (_mapboxMap != null && _isMapReady) {
      _reloadOverlaysIfNeeded(oldWidget.overlays);
    } else {
      debugPrint('⏸️ didUpdateWidget skipped: mapboxMap=${_mapboxMap != null}, isMapReady=$_isMapReady');
    }

    // Handle follow mode changes
    if (widget.isFollowingLocation != oldWidget.isFollowingLocation) {
      if (widget.isFollowingLocation) {
        _startFollowingLocation();
      } else {
        _stopFollowingLocation();
      }
    }
  }

  /// Start listening to location updates for follow mode
  void _startFollowingLocation() {
    if (_locationSubscription != null) return; // Already listening

    debugPrint('📍 Starting location stream for follow mode');

    _locationSubscription = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen(
      (geo.Position position) {
        // Skip follow mode updates while zooming to historical map bounds
        if (_isZoomingToHistoricalMap) {
          debugPrint('📍 Skipping follow mode update - zooming to historical map');
          return;
        }
        if (_mapboxMap != null && _isMapReady && widget.isFollowingLocation) {
          // Mark this as a follow-mode camera move so onMapViewChanged doesn't disable follow
          _isFollowModeCameraMove = true;
          // Use smooth easing for continuous follow mode (not abrupt flyTo)
          _smoothEaseToPosition(position.latitude, position.longitude);
        }
      },
      onError: (Object error) {
        debugPrint('📍 Location stream error: $error');
      },
    );
  }

  /// Stop listening to location updates
  void _stopFollowingLocation() {
    debugPrint('📍 Stopping location stream');
    _locationSubscription?.cancel();
    _locationSubscription = null;
    // Reset the follow mode camera flag so manual pans aren't blocked
    _isFollowModeCameraMove = false;
  }

  /// Fly camera to a specific position, preserving current zoom level
  /// Used for initial centering (faster, more direct movement)
  Future<void> _flyToPosition(double latitude, double longitude) async {
    if (_mapboxMap == null) return;

    // Get current camera state to preserve zoom level
    final currentCamera = await _mapboxMap!.getCameraState();
    final currentZoom = currentCamera.zoom;

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(longitude, latitude),
        ),
        zoom: currentZoom, // Preserve current zoom instead of hardcoding 16.0
      ),
      MapAnimationOptions(duration: 500),
    );
  }

  /// Smoothly ease camera to a position for continuous follow mode
  ///
  /// Uses easeTo with a duration slightly longer than the GPS update interval
  /// (~1000ms). This creates overlapping animations where each new position
  /// smoothly "takes over" from the previous one, resulting in fluid motion
  /// instead of stop-start-stop-start behavior.
  Future<void> _smoothEaseToPosition(double latitude, double longitude) async {
    if (_mapboxMap == null) return;

    // Get current camera state to preserve zoom and bearing
    final currentCamera = await _mapboxMap!.getCameraState();

    await _mapboxMap!.easeTo(
      CameraOptions(
        center: Point(
          coordinates: Position(longitude, latitude),
        ),
        zoom: currentCamera.zoom,
        bearing: currentCamera.bearing,
      ),
      // Duration slightly longer than GPS update interval for smooth overlap
      // GPS updates every ~5 meters, so at walking speed (~1.4 m/s) that's ~3.5s
      // At jogging speed (~3 m/s) that's ~1.7s, at driving that's much faster
      // 1000ms provides smooth blending for typical outdoor movement speeds
      MapAnimationOptions(duration: 1000),
    );
  }

  /// Fly camera to fit historical map bounds
  /// Uses center and zoom from MBTiles metadata if available
  /// Temporarily suppresses follow mode during the zoom animation
  Future<void> _flyToHistoricalMapBounds(HistoricalMapBounds bounds) async {
    if (_mapboxMap == null) return;

    // Suppress follow mode during zoom
    _isZoomingToHistoricalMap = true;

    // Use the zoom from metadata, or default to 12 which is typical for USGS topos
    final zoom = bounds.defaultZoom ?? 12.0;

    debugPrint('🗺️ Flying to historical map bounds: center=(${bounds.centerLongitude}, ${bounds.centerLatitude}), zoom=$zoom');

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(bounds.centerLongitude, bounds.centerLatitude),
        ),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 1000),
    );

    // Clear the flag after animation completes (plus a small buffer)
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _isZoomingToHistoricalMap = false;
        debugPrint('🗺️ Historical map zoom complete, follow mode re-enabled');
      }
    });
  }

  // ===========================================================================
  // Multi-touch gesture tracking for scroll deceleration suppression
  // ===========================================================================
  // Problem: When pinching to zoom, if fingers lift at slightly different times
  // or velocities, the SDK interprets this as a fling gesture, causing unwanted
  // pan momentum.
  //
  // Solution: Track touch count and temporarily disable scroll deceleration
  // when transitioning from multi-touch (2+ fingers) to no touch. This preserves
  // normal pan momentum for single-finger panning while preventing the zoom-end
  // fling issue.
  // ===========================================================================

  void _handlePointerDown(PointerDownEvent event) {
    _activePointerCount++;
    if (_activePointerCount >= 2) {
      _wasMultiTouch = true;
    }

    // Track initial position for long-press movement detection
    if (_activePointerCount == 1) {
      _longPressStartPosition = event.localPosition;
      _hasMovedDuringPress = false;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    // Check if finger has moved significantly during press
    if (_longPressStartPosition != null && !_hasMovedDuringPress) {
      final distance = (event.localPosition - _longPressStartPosition!).distance;
      if (distance > _longPressMoveThreshold) {
        _hasMovedDuringPress = true;
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointerCount = (_activePointerCount - 1).clamp(0, 99);

    // When all fingers lift after a multi-touch gesture, suppress scroll deceleration
    if (_activePointerCount == 0 && _wasMultiTouch) {
      _suppressScrollDeceleration();
      _wasMultiTouch = false;
    }

    // Reset long-press tracking when all fingers lift
    if (_activePointerCount == 0) {
      _longPressStartPosition = null;
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointerCount = (_activePointerCount - 1).clamp(0, 99);

    // Also handle cancellation the same way as pointer up
    if (_activePointerCount == 0 && _wasMultiTouch) {
      _suppressScrollDeceleration();
      _wasMultiTouch = false;
    }

    // Reset long-press tracking on cancel
    if (_activePointerCount == 0) {
      _longPressStartPosition = null;
    }
  }

  /// Ensure scroll deceleration stays disabled after pinch-to-zoom gestures.
  /// (Deceleration is disabled globally for snappier panning)
  void _suppressScrollDeceleration() {
    // No-op: scroll deceleration is now disabled globally in _onMapCreated
    // Keeping this method in case we want to re-enable conditional behavior later
  }

  @override
  void dispose() {
    // Cancel location subscription
    _locationSubscription?.cancel();

    // Cancel debounce timer
    _cameraChangeDebounceTimer?.cancel();

    // Unload all overlays
    if (_mapboxMap != null) {
      for (final overlay in _loadedOverlays) {
        overlay.unload(_mapboxMap!);
      }
    }
    _loadedOverlays.clear();
    super.dispose();
  }

  /// Reload overlays if the overlay list or data has changed
  Future<void> _reloadOverlaysIfNeeded(List<MapOverlayConfig> oldOverlays) async {
    if (_mapboxMap == null) return;

    // If already reloading, mark that overlays changed and return
    // We'll retry after the current reload finishes
    if (_isReloadingOverlays) {
      debugPrint('⏸️ Overlay reload requested while already reloading - will retry after completion');
      _overlaysChangedDuringReload = true;
      return;
    }

    // INCREMENTAL OVERLAY MANAGEMENT: Handle additions/removals without reloading everything
    if (oldOverlays.length != widget.overlays.length) {
      debugPrint('🔄 Overlay count changed (${oldOverlays.length} → ${widget.overlays.length}), applying incremental changes');
      await _applyIncrementalOverlayChanges(oldOverlays);
      return;
    }

    // Check each overlay for changes and update instead of reload
    // Only update if the overlay type and enabled state match
    for (int i = 0; i < widget.overlays.length; i++) {
      // Check if type or enabled state changed - if so, do full reload
      if (oldOverlays[i].type != widget.overlays[i].type ||
          oldOverlays[i].enabled != widget.overlays[i].enabled) {
        debugPrint('🔄 Overlay type/enabled changed, reloading all overlays');
        await _reloadAllOverlays();
        return;
      }

      // Check if data reference changed (new instance)
      // Use identical() instead of != because overlay equality operators may be value-based
      // (e.g., TrailsOverlay.== only compares length, not actual trail data)
      if (!identical(oldOverlays[i].data, widget.overlays[i].data)) {
        // Only update if the overlay is actually loaded
        final overlay = widget.overlays[i].data;
        if (overlay != null && widget.overlays[i].enabled) {
          try {
            _isReloadingOverlays = true;

            // Remove old instance from _loadedOverlays
            final oldOverlay = _loadedOverlays.firstWhere(
              (o) => o.runtimeType.toString().contains(widget.overlays[i].type.toString()),
              orElse: () => oldOverlays[i].data!,
            );
            _loadedOverlays.remove(oldOverlay);

            // Use update() method to avoid flashing
            // Note: update() only changes the data source, not layer structure,
            // so z-order is preserved and location puck stays on top
            await overlay.update(_mapboxMap!);

            // Add new instance to _loadedOverlays
            _loadedOverlays.add(overlay);
            debugPrint('🔄 Updated ${widget.overlays[i].type} overlay (replaced instance in _loadedOverlays)');
          } catch (e) {
            debugPrint('⚠️ Failed to update overlay, doing full reload: $e');
            await _reloadAllOverlays();
            return;
          } finally {
            _isReloadingOverlays = false;
          }
        }
      }
    }
  }

  /// Apply incremental overlay changes (add/remove only changed overlays)
  Future<void> _applyIncrementalOverlayChanges(List<MapOverlayConfig> oldOverlays) async {
    if (_mapboxMap == null) return;

    _isReloadingOverlays = true;

    try {
      // Create maps of overlay types for quick lookup
      final oldOverlayMap = {for (final config in oldOverlays) config.type: config};
      final newOverlayMap = {for (final config in widget.overlays) config.type: config};

      // Find overlays to remove (in old but not in new, or disabled)
      for (final oldConfig in oldOverlays) {
        final newConfig = newOverlayMap[oldConfig.type];
        if (newConfig == null || !newConfig.enabled) {
          // Overlay was removed or disabled - unload it
          final loadedOverlay = _loadedOverlays.firstWhere(
            (overlay) => overlay.runtimeType.toString().contains(oldConfig.type.toString()),
            orElse: () => oldConfig.data!,
          );
          try {
            await loadedOverlay.unload(_mapboxMap!);
            _loadedOverlays.remove(loadedOverlay);
            debugPrint('➖ Removed ${oldConfig.type} overlay');
          } catch (e) {
            debugPrint('⚠️ Failed to unload ${oldConfig.type} overlay: $e');
          }
        }
      }

      // Find overlays to add (in new but not in old, or newly enabled)
      for (final newConfig in widget.overlays) {
        final oldConfig = oldOverlayMap[newConfig.type];
        final isNew = oldConfig == null || !oldConfig.enabled;

        debugPrint('🔍 Processing ${newConfig.type}: isNew=$isNew, enabled=${newConfig.enabled}, hasData=${newConfig.data != null}');

        if (isNew && newConfig.enabled && newConfig.data != null) {
          // Overlay is new or newly enabled - load it
          debugPrint('🔍 About to call load() on ${newConfig.type}...');
          try {
            await newConfig.data!.load(_mapboxMap!);
            _loadedOverlays.add(newConfig.data!);
            debugPrint('➕ Added ${newConfig.type} overlay');
          } catch (e) {
            debugPrint('❌ Failed to load ${newConfig.type} overlay: $e');
          }
        } else if (!isNew && newConfig.enabled && !identical(newConfig.data, oldConfig.data)) {
          // Overlay data changed - update it and replace instance in _loadedOverlays
          // Use identical() because overlay equality operators may be value-based
          try {
            // Remove old instance
            final oldOverlay = _loadedOverlays.firstWhere(
              (overlay) => overlay.runtimeType.toString().contains(newConfig.type.toString()),
              orElse: () => oldConfig.data!,
            );
            _loadedOverlays.remove(oldOverlay);

            // Update with new instance
            await newConfig.data!.update(_mapboxMap!);
            _loadedOverlays.add(newConfig.data!);
            debugPrint('🔄 Updated ${newConfig.type} overlay (replaced instance in _loadedOverlays)');
          } catch (e) {
            debugPrint('⚠️ Failed to update ${newConfig.type} overlay: $e');
          }
        }
      }
    } finally {
      _isReloadingOverlays = false;

      // If overlays changed while we were reloading, trigger a full reload
      // We use _reloadAllOverlays because the oldOverlays parameter is now stale
      if (_overlaysChangedDuringReload) {
        debugPrint('🔄 Overlays changed during reload, doing full reload to sync');
        _overlaysChangedDuringReload = false;
        // Schedule reload on next frame to avoid recursive calls
        // Note: _reloadAllOverlays will call _refreshLocationComponent, so skip it here
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _mapboxMap != null) {
            _reloadAllOverlays();
          }
        });
      } else {
        // Only refresh location component if we're not scheduling a full reload
        // (full reload will do it anyway)
        await _refreshLocationComponent();
      }
    }
  }

  /// Refresh the location component to ensure it renders above all map layers
  ///
  /// Disables then re-enables the location component to force its layers
  /// to be re-added at the top of the layer stack.
  Future<void> _refreshLocationComponent() async {
    if (_mapboxMap == null || !widget.config.showCurrentLocation) return;

    try {
      // Disable the location component (removes its layers)
      await _mapboxMap!.location.updateSettings(
        LocationComponentSettings(enabled: false),
      );

      // Small delay to ensure layers are removed before re-adding
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Re-enable the location component (adds layers at current top of stack)
      await _mapboxMap!.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
        ),
      );
      debugPrint('📍 Location puck re-enabled (should be on top now)');
    } catch (e) {
      debugPrint('⚠️ Failed to refresh location component: $e');
    }
  }

  /// Reload all overlays on the map
  Future<void> _reloadAllOverlays() async {
    if (_mapboxMap == null) return;

    // Prevent concurrent reloads to avoid "source already exists" errors
    if (_isReloadingOverlays) {
      debugPrint('⏸️ Overlay reload already in progress, skipping');
      return;
    }

    _isReloadingOverlays = true;

    try {
      // Unload old overlays - create a copy to avoid concurrent modification
      final overlaysToUnload = List<MapOverlay>.from(_loadedOverlays);
      for (final overlay in overlaysToUnload) {
        try {
          await overlay.unload(_mapboxMap!);
        } catch (e) {
          debugPrint('⚠️ Failed to unload overlay: $e');
        }
      }
      _loadedOverlays.clear();

      // Load new overlays
      for (final overlayConfig in widget.overlays) {
        if (overlayConfig.enabled) {
          try {
            await overlayConfig.data?.load(_mapboxMap!);
            if (overlayConfig.data != null) {
              _loadedOverlays.add(overlayConfig.data!);
            }
          } catch (e) {
            debugPrint('❌ Failed to load overlay ${overlayConfig.type}: $e');
          }
        }
      }

      // Refresh location component to ensure it stays above all layers
      await _refreshLocationComponent();

      // Trigger a widget rebuild to ensure overlay changes are reflected
      // This helps with the case where overlays are loaded but not immediately visible
      if (mounted) {
        setState(() {});
      }
    } finally {
      _isReloadingOverlays = false;
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;

    // Check for saved camera position first (restored when returning to map tab)
    final savedPosition = ref.read(mapCameraPositionProvider);

    // Get current location as fallback
    final locationState = ref.read(locationProvider);
    final position = locationState.currentPosition;

    // Priority: 1) config.initialCenter, 2) saved position, 3) current location, 4) US center
    Point initialCenter;
    double initialZoom;
    double initialBearing;

    if (widget.config.initialCenter != null) {
      // Config specifies an initial center (e.g., screenshot mode, route planning)
      initialCenter = widget.config.initialCenter!;
      initialZoom = widget.config.initialZoom;
      initialBearing = 0;
    } else if (savedPosition != null) {
      // Restore saved position from previous visit to map tab
      initialCenter = Point(
        coordinates: Position(
          savedPosition.longitude,
          savedPosition.latitude,
        ),
      );
      initialZoom = savedPosition.zoom;
      initialBearing = savedPosition.bearing;
      debugPrint('📍 Restoring saved map position: $savedPosition');
    } else if (position != null) {
      // Use current GPS location
      initialCenter = Point(
        coordinates: Position(
          position.longitude,
          position.latitude,
        ),
      );
      initialZoom = widget.config.initialZoom;
      initialBearing = 0;
    } else {
      // Fallback to US center
      initialCenter = Point(
        coordinates: Position(
          -98.5795, // US geographic center longitude
          39.8283, // US geographic center latitude
        ),
      );
      initialZoom = widget.config.initialZoom;
      initialBearing = 0;
    }

    _mapboxMap!.setCamera(
      CameraOptions(
        center: initialCenter,
        zoom: initialZoom,
        bearing: initialBearing,
      ),
    );

    // Disable rotation gestures by default (rotation locked)
    // Disable scroll deceleration for snappier panning (map stops when finger lifts)
    _mapboxMap!.gestures.updateSettings(
      GesturesSettings(
        rotateEnabled: _rotationEnabled,
        scrollDecelerationEnabled: false,
      ),
    );

    // Note: Location component is configured in _onStyleLoaded AFTER overlays
    // are loaded to ensure the blue location dot renders ABOVE all map layers

    setState(() {
      _isMapReady = true;
    });

    // Notify parent
    widget.onMapCreated?.call(mapboxMap);

    // Start following location if enabled
    if (widget.isFollowingLocation) {
      // Initial center
      if (position != null) {
        _flyToPosition(position.latitude, position.longitude);
      }
      // Start stream for continuous following
      _startFollowingLocation();
    }

    // Fallback: If _onStyleLoaded doesn't fire (e.g., style already loaded when widget mounts),
    // check after a delay and mark style as loaded
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_isStyleLoaded && _mapboxMap != null) {
        debugPrint('⚠️ Style loaded callback not fired after 500ms, checking style directly');
        _checkAndSetStyleLoaded();
      }
    });
  }

  /// Check if style is loaded and trigger overlay loading if needed
  Future<void> _checkAndSetStyleLoaded() async {
    if (_mapboxMap == null || _isStyleLoaded) return;

    try {
      // Try to access the style to verify it's loaded
      // If this succeeds without throwing, the style is ready
      await _mapboxMap!.style.getStyleURI();

      if (!_isStyleLoaded) {
        debugPrint('✅ Style confirmed loaded (fallback check)');
        _isStyleLoaded = true;

        // Sync any pending historical map overlays
        await _syncHistoricalMapOverlays();

        // Refresh location component
        await _refreshLocationComponent();
      }
    } catch (e) {
      debugPrint('⚠️ Style not ready yet: $e');
      // Schedule another check
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isStyleLoaded) {
          _checkAndSetStyleLoaded();
        }
      });
    }
  }

  void _centerOnCurrentLocation() {
    // Toggle follow mode
    final newFollowState = !widget.isFollowingLocation;
    widget.onFollowLocationToggle?.call(newFollowState);
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    debugPrint('✅ Mapbox style loaded');

    if (_mapboxMap == null) return;

    // Mark style as loaded - historical maps listener needs this
    _isStyleLoaded = true;

    // Prevent concurrent overlay loading - mark as reloading during initial load
    _isReloadingOverlays = true;

    try {
      // Configure map units based on user preference
      final generalSettings = ref.read(generalSettingsProvider);
      final useImperial = generalSettings.units == MeasurementUnits.imperial;

      // Configure scale bar to use correct unit system
      // isMetricUnits: true = metric (meters, km), false = imperial (feet, miles)
      try {
        await _mapboxMap!.scaleBar.updateSettings(
          ScaleBarSettings(
            enabled: true,
            isMetricUnits: !useImperial, // invert because imperial = false, metric = true
          ),
        );
        debugPrint('📏 Scale bar units set to ${useImperial ? "imperial (feet/miles)" : "metric (meters/km)"}');
      } catch (e) {
        debugPrint('⚠️ Failed to set scale bar units: $e');
      }

      // Clear the loaded overlays list when style changes
      // Note: We don't need to call unload() because changing the style
      // automatically removes all sources and layers
      _loadedOverlays.clear();

      // Load all configured overlays
      debugPrint('🔄 _onStyleLoaded loading ${widget.overlays.length} overlays: ${widget.overlays.map((o) => o.type.name).toList()}');
      for (final overlayConfig in widget.overlays) {
        if (overlayConfig.enabled) {
          try {
            await overlayConfig.data?.load(_mapboxMap!);
            if (overlayConfig.data != null) {
              _loadedOverlays.add(overlayConfig.data!);
              debugPrint('➕ _onStyleLoaded loaded ${overlayConfig.type}');
            }
          } catch (e) {
            debugPrint('❌ Failed to load overlay ${overlayConfig.type}: $e');
          }
        }
      }

      // Add hillshade layer if enabled in settings
      final mapSettings = ref.read(mapSettingsProvider);
      if (mapSettings.showHillshade) {
        await _addHillshadeLayer();
      }

      // Load any enabled historical map overlays
      // Note: The ref.listen callback will also handle this, but we check here
      // in case the provider has already loaded before the style is ready.
      final historicalMapsState = ref.read(historicalMapsProvider);
      if (historicalMapsState.isLoading) {
        debugPrint('🗺️ Style loaded: historical maps provider still loading, will be loaded via listener');
      } else {
        final enabledMaps = historicalMapsState.enabledMaps;
        debugPrint('🗺️ Style loaded: ${historicalMapsState.maps.length} historical maps in provider, ${enabledMaps.length} enabled');
        for (final mapState in enabledMaps) {
          // Check if already loaded (in case of style change)
          final overlayId = 'historical-map-${mapState.stateCode}-${mapState.layerId}';
          final alreadyLoaded = _loadedOverlays.any((o) => o.id == overlayId);
          if (!alreadyLoaded) {
            debugPrint('🗺️ Loading enabled historical map on style load: ${mapState.key} at ${mapState.filePath}');
            await _loadHistoricalMapOverlay(mapState);
          } else {
            debugPrint('🗺️ Historical map already loaded: ${mapState.key}');
          }
        }

        // Check for pending zoom bounds that may have been set before style loaded
        if (historicalMapsState.pendingZoomBounds != null) {
          debugPrint('🗺️ Style loaded: handling pending zoom bounds');
          _flyToHistoricalMapBounds(historicalMapsState.pendingZoomBounds!);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(historicalMapsProvider.notifier).clearPendingZoom();
            }
          });
        }
      }
    } finally {
      _isReloadingOverlays = false;

      // If overlays changed while we were loading initial set, reload them
      if (_overlaysChangedDuringReload) {
        debugPrint('🔄 Overlays changed during initial style load, applying changes');
        _overlaysChangedDuringReload = false;
        // Use the current widget.overlays as the "old" since we just loaded them
        // Note: _reloadAllOverlays will call _refreshLocationComponent, so skip it here
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _mapboxMap != null) {
            _reloadAllOverlays();
          }
        });
      } else {
        // Only refresh location component if we're not scheduling a full reload
        // (full reload will do it anyway)
        await _refreshLocationComponent();
      }
    }
  }

  void _onMapIdle(MapIdleEventData data) {
    // Skip if this was a follow-mode camera move to prevent disabling follow mode
    if (_isFollowModeCameraMove && widget.isFollowingLocation) {
      _isFollowModeCameraMove = false;
      return;
    }
    _isFollowModeCameraMove = false;

    // Notify parent that map view changed so it can reload data
    if (_mapboxMap != null) {
      _lastMapViewChangedCallback = DateTime.now();
      widget.onMapViewChanged?.call(_mapboxMap!);

      // Save camera position for restoration when returning to map tab
      // Only save if no explicit initialCenter is set (avoid overwriting for special modes)
      if (widget.config.initialCenter == null) {
        _saveCameraPosition();
      }
    }
  }

  /// Save current camera position to provider for restoration on tab return
  Future<void> _saveCameraPosition() async {
    if (_mapboxMap == null) return;

    try {
      final cameraState = await _mapboxMap!.getCameraState();
      final center = cameraState.center;

      ref.read(mapCameraPositionProvider.notifier).savePosition(
            latitude: center.coordinates.lat.toDouble(),
            longitude: center.coordinates.lng.toDouble(),
            zoom: cameraState.zoom,
            bearing: cameraState.bearing,
          );
    } catch (e) {
      debugPrint('⚠️ Failed to save camera position: $e');
    }
  }

  void _onCameraChange(CameraChangedEventData data) {
    // Update bearing for compass display
    if (_mapboxMap != null) {
      _mapboxMap!.getCameraState().then((cameraState) {
        if (mounted && cameraState.bearing != _currentBearing) {
          setState(() {
            _currentBearing = cameraState.bearing;
          });
        }
      });
    }

    // =========================================================================
    // FAST UI UPDATE: Throttled at 200ms for lightweight operations (banner)
    // =========================================================================
    // This fires more frequently for real-time UI updates that are cheap to run
    // (e.g., querying rendered features for land rights banner)
    // =========================================================================
    final now = DateTime.now();
    final timeSinceLastFastCallback = _lastCameraMovingFastCallback == null
        ? const Duration(milliseconds: 250) // First callback - allow immediately
        : now.difference(_lastCameraMovingFastCallback!);

    if (timeSinceLastFastCallback.inMilliseconds >= 200) {
      _lastCameraMovingFastCallback = now;
      // NOTE: onCameraMovingFast is for lightweight UI updates (like banner) and should
      // fire even during follow mode - it doesn't disable follow mode like onMapViewChanged
      if (_mapboxMap != null) {
        widget.onCameraMovingFast?.call(_mapboxMap!);

        // Update camera position provider for HUD coordinates display
        // This fires during panning so HUD shows real-time crosshair position
        _mapboxMap!.getCameraState().then((cameraState) {
          final center = cameraState.center;
          ref.read(mapCameraPositionProvider.notifier).savePosition(
                latitude: center.coordinates.lat.toDouble(),
                longitude: center.coordinates.lng.toDouble(),
                zoom: cameraState.zoom,
                bearing: cameraState.bearing,
              );
        });
      }
    }

    // =========================================================================
    // CONTINUOUS LOADING: Throttled at 500ms for data loading operations
    // =========================================================================
    // This allows data to load progressively while panning, instead of waiting
    // for the camera to fully stop. Throttled to 500ms to avoid API spam.
    // =========================================================================
    final timeSinceLastCallback = _lastCameraMovingCallback == null
        ? const Duration(milliseconds: 600) // First callback - allow immediately
        : now.difference(_lastCameraMovingCallback!);

    if (timeSinceLastCallback.inMilliseconds >= 500 && widget.onCameraMoving != null) {
      _lastCameraMovingCallback = now;
      // Don't trigger during follow mode or overlay reloads
      if (!_isFollowModeCameraMove && !_isReloadingOverlays && _mapboxMap != null) {
        widget.onCameraMoving?.call(_mapboxMap!);
      }
    }

    // =========================================================================
    // MAX WAIT TIME: Force data load if it's been too long since last update
    // =========================================================================
    // During continuous animations (e.g., session playback follow mode), the
    // debounce timer keeps resetting and onMapIdle never fires. This ensures
    // data still loads periodically (every 5 seconds) during such scenarios.
    // =========================================================================
    const maxWaitDuration = Duration(seconds: 5);
    final timeSinceLastViewChange = _lastMapViewChangedCallback == null
        ? maxWaitDuration // First time - allow if debounce triggers
        : now.difference(_lastMapViewChangedCallback!);

    if (timeSinceLastViewChange >= maxWaitDuration && _mapboxMap != null && !_isReloadingOverlays) {
      // Skip during follow mode to prevent disabling follow
      if (!_isFollowModeCameraMove || !widget.isFollowingLocation) {
        _lastMapViewChangedCallback = now;
        widget.onMapViewChanged?.call(_mapboxMap!);
      }
      // Don't return - still set up debounce for when camera actually stops
    }

    // =========================================================================
    // DEBOUNCED CALLBACK: Final update after camera stops moving
    // =========================================================================
    // Reduced from 1000ms to 300ms for more responsive feel while still
    // preventing excessive reloads during rapid panning.
    // =========================================================================
    _cameraChangeDebounceTimer?.cancel();
    _cameraChangeDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      // Skip the callback if this was a follow-mode camera move
      // This prevents the parent from disabling follow mode when we programmatically move the camera
      if (_isFollowModeCameraMove && widget.isFollowingLocation) {
        // Reset the flag so subsequent user pans aren't blocked
        // If location keeps updating, it will set the flag again anyway
        _isFollowModeCameraMove = false;
        return;
      }

      _isFollowModeCameraMove = false;

      if (_mapboxMap != null && !_isReloadingOverlays) {
        _lastMapViewChangedCallback = DateTime.now();
        widget.onMapViewChanged?.call(_mapboxMap!);
      }
    });
  }

  /// Handle long-press on the map (for creating custom markers)
  /// Ignores long-tap if the user moved their finger (panning) or is using multiple fingers (pinching)
  void _onMapLongTap(MapContentGestureContext context) {
    // Don't trigger long-press if user was panning or pinching
    if (_hasMovedDuringPress || _activePointerCount > 1) {
      return;
    }

    final point = context.point;
    widget.onMapLongPress?.call(point);
  }

  Future<void> _onMapTap(MapContentGestureContext context) async {
    final point = context.point;
    widget.onMapTap?.call(point);

    // Check if any overlay handles this tap
    // PRIORITY: Check trails first (they're on top), then land parcels
    if (_mapboxMap != null) {
      final screenCoord = await _mapboxMap!.pixelForCoordinate(point);

      // FIRST: Try to handle tap on waypoint overlay (highest priority - small targets)
      for (final overlay in _loadedOverlays) {
        if (overlay is WaypointOverlay) {
          final waypoint = await overlay.handleTap(_mapboxMap!, screenCoord);
          if (waypoint != null) {
            debugPrint('🎯 Tapped waypoint: ${waypoint.displayName}');
            overlay.onWaypointTap?.call(waypoint);
            return; // Tap handled by overlay
          }
        }
      }

      // SECOND: Try to handle tap on custom markers overlay (user-created markers)
      for (final overlay in _loadedOverlays) {
        if (overlay is CustomMarkersOverlay) {
          // Check for cluster tap first (zooms in on cluster)
          final clusterTapped = await overlay.handleClusterTap(_mapboxMap!, screenCoord);
          if (clusterTapped) {
            return; // Cluster tap handled
          }

          final marker = await overlay.handleTap(_mapboxMap!, screenCoord);
          if (marker != null) {
            debugPrint('🎯 Tapped custom marker: ${marker.name}');
            overlay.onMarkerTap?.call(marker);
            return; // Tap handled by overlay
          }
        }
      }

      // THIRD: Try to handle tap on historical places overlay (small point markers)
      debugPrint('🔍 Checking ${_loadedOverlays.length} overlays for historical places: ${_loadedOverlays.map((o) => o.runtimeType).toList()}');
      for (final overlay in _loadedOverlays) {
        if (overlay is HistoricalPlacesOverlay) {
          debugPrint('🔍 Found HistoricalPlacesOverlay with ${overlay.places.length} places, checking tap...');

          // Check for cluster tap first (zooms in on cluster)
          final clusterTapped = await overlay.handleClusterTap(_mapboxMap!, screenCoord);
          if (clusterTapped) {
            debugPrint('🔍 Cluster tapped - zooming in');
            return; // Cluster tap handled
          }

          final place = await overlay.handleTap(_mapboxMap!, screenCoord);
          if (place != null) {
            debugPrint('🎯 Tapped historical place: ${place.featureName}');
            overlay.onPlaceTap?.call(place);
            return; // Tap handled by overlay
          } else {
            debugPrint('⚠️ HistoricalPlacesOverlay.handleTap returned null');
          }
        }
      }

      // FOURTH: Try to handle tap on trails overlay (lines on top of land)
      debugPrint('🔍 Checking ${_loadedOverlays.length} overlays for trail tap');
      for (final overlay in _loadedOverlays) {
        if (overlay is TrailsOverlay) {
          debugPrint('🔍 Found TrailsOverlay, checking tap...');
          final trail = await overlay.handleTap(_mapboxMap!, screenCoord);
          if (trail != null) {
            debugPrint('🎯 Tapped trail: ${trail.trailName}');
            overlay.onTrailTap?.call(trail);
            return; // Tap handled by overlay
          } else {
            debugPrint('⚠️ TrailsOverlay.handleTap returned null');
          }
        }
      }
      debugPrint('⚠️ No TrailsOverlay found in loaded overlays');

      // FIFTH: If no trail detected, try land ownership overlay
      for (final overlay in _loadedOverlays) {
        if (overlay is LandOwnershipOverlay) {
          final parcel = await overlay.handleTap(_mapboxMap!, screenCoord);
          if (parcel != null) {
            debugPrint('🎯 Tapped land parcel: ${parcel.ownerName}');
            overlay.onParcelTap?.call(parcel);
            return; // Tap handled by overlay
          }
        }
      }
    }

    if (widget.config.enableTouchToMark) {
      // TODO(mapbox): Trigger waypoint creation dialog
      debugPrint(
        'Map tapped at: ${point.coordinates.lat}, ${point.coordinates.lng}',
      );
    }
  }

  void _toggleRotation() {
    if (_mapboxMap == null) return;

    setState(() {
      _rotationEnabled = !_rotationEnabled;
    });

    // Update map gestures settings to enable/disable rotation
    _mapboxMap!.gestures.updateSettings(
      GesturesSettings(
        rotateEnabled: _rotationEnabled,
      ),
    );

    // Persist the rotation setting
    final appSettingsService = ref.read(appSettingsServiceProvider);
    final currentMapSettings = ref.read(mapSettingsProvider);
    appSettingsService.updateMapSettings(
      currentMapSettings.copyWith(rotateWithCompass: _rotationEnabled),
    );

    // If locking rotation, reset to north
    if (!_rotationEnabled) {
      _resetNorth();
    }
  }

  void _resetNorth() {
    if (_mapboxMap == null) return;
    _mapboxMap!.setCamera(
      CameraOptions(
        bearing: 0, // North is 0 degrees
      ),
    );
  }

  Future<void> _changeMapStyle(String styleUri) async {
    if (_mapboxMap == null || !mounted) return;

    // Reset style loaded flag - will be set true again after style loads
    _isStyleLoaded = false;
    _loadedOverlays.clear(); // Clear loaded overlays since style change removes all layers

    setState(() {
      _currentStyleUri = styleUri;
    });

    try {
      await _mapboxMap!.loadStyleURI(styleUri);
    } catch (e) {
      // Handle cancelled style loads gracefully (e.g., when navigating away)
      debugPrint('⚠️ Map style change cancelled or failed: $e');
      return;
    }

    // Style is now loaded - mark as ready
    // Note: _onStyleLoaded callback may also fire, but setting twice is harmless
    _isStyleLoaded = true;

    // Reload overlays after style change (only if still mounted)
    if (_mapboxMap != null && mounted) {
      for (final overlayConfig in widget.overlays) {
        if (overlayConfig.enabled) {
          try {
            await overlayConfig.data?.load(_mapboxMap!);
            if (overlayConfig.data != null) {
              _loadedOverlays.add(overlayConfig.data!);
            }
          } catch (e) {
            debugPrint('❌ Failed to reload overlay ${overlayConfig.type}: $e');
          }
        }
      }

      // Sync historical map overlays after style change
      await _syncHistoricalMapOverlays();

      // Refresh location component to ensure it's on top
      await _refreshLocationComponent();
    }
  }

  /// Change map style and persist the preference
  Future<void> _selectMapStyle(MapStylePreference preference) async {
    final brightness = Theme.of(context).brightness;
    final styleUri = _getStyleUriForPreference(preference, brightness);

    setState(() {
      _stylePreference = preference;
      _currentStyleUri = styleUri;
    });

    // Persist the preference to settings
    final appSettingsService = ref.read(appSettingsServiceProvider);
    final currentMapSettings = ref.read(mapSettingsProvider);
    await appSettingsService.updateMapSettings(
      currentMapSettings.copyWith(mapStylePreference: preference),
    );
    debugPrint('🗺️ Style preference saved: $preference');

    // Change the map style
    await _changeMapStyle(styleUri);
  }

  void _showStyleSelector() {
    final currentMapSettings = ref.read(mapSettingsProvider);
    var showHillshade = currentMapSettings.showHillshade;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
                  padding: const EdgeInsets.all(16),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Map Style',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dark/light mode follows app appearance settings',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStyleOption(
                          'Outdoors',
                          MapStylePreference.outdoors,
                          Icons.terrain,
                        ),
                        _buildStyleOption(
                          'Satellite',
                          MapStylePreference.satellite,
                          Icons.satellite,
                        ),
                        _buildStyleOption(
                          'Streets',
                          MapStylePreference.streets,
                          Icons.map,
                        ),
                        const Divider(height: 24),
                        SwitchListTile(
                          secondary: const Icon(Icons.landscape),
                          title: const Text('Terrain Relief'),
                          subtitle: const Text('Show hillshade elevation'),
                          value: showHillshade,
                          activeTrackColor: AppTheme.gold.withValues(alpha: 0.5),
                          activeThumbColor: AppTheme.gold,
                          onChanged: (value) {
                            setSheetState(() {
                              showHillshade = value;
                            });
                            _toggleHillshade(value);
                          },
                        ),
                        // Note: Historical Maps are now in the Map Layers filter panel
                      ],
                    ),
                  ),
                );
              },
            );
      },
    );
  }

  /// Load a historical map overlay onto the map
  Future<void> _loadHistoricalMapOverlay(HistoricalMapState mapState) async {
    if (_mapboxMap == null) return;

    final overlayId = 'historical-map-${mapState.stateCode}-${mapState.layerId}';

    // Check if already loaded or currently loading (prevent concurrent duplicate loads)
    if (_loadedOverlays.any((o) => o.id == overlayId)) {
      debugPrint('🗺️ Historical map already loaded, skipping: ${mapState.key}');
      return;
    }
    if (_loadingHistoricalMapIds.contains(overlayId)) {
      debugPrint('🗺️ Historical map already loading, skipping: ${mapState.key}');
      return;
    }

    // Mark as loading
    _loadingHistoricalMapIds.add(overlayId);

    try {
      final overlay = HistoricalMapOverlay(
        stateCode: mapState.stateCode,
        layerId: mapState.layerId,
        layerName: mapState.layerName,
        filePath: mapState.filePath,
        opacity: mapState.opacity,
        era: mapState.era,
      );

      // Check if file exists before attempting load
      if (!overlay.fileExists) {
        debugPrint('⚠️ Historical map file not found: ${mapState.filePath}');
        return;
      }

      await overlay.load(_mapboxMap!);
      _loadedOverlays.add(overlay);
      debugPrint('🗺️ Historical map overlay loaded: ${mapState.key}');
    } catch (e) {
      debugPrint('❌ Error loading historical map overlay: $e');
    } finally {
      _loadingHistoricalMapIds.remove(overlayId);
    }
  }

  /// Unload a historical map overlay from the map
  Future<void> _unloadHistoricalMapOverlay(HistoricalMapState mapState) async {
    if (_mapboxMap == null) return;

    try {
      final overlayId = 'historical-map-${mapState.stateCode}-${mapState.layerId}';
      final overlay = _loadedOverlays.whereType<HistoricalMapOverlay>()
          .where((o) => o.id == overlayId)
          .firstOrNull;

      if (overlay != null) {
        await overlay.unload(_mapboxMap!);
        _loadedOverlays.remove(overlay);
        debugPrint('🗺️ Historical map overlay unloaded: ${mapState.key}');
      }
    } catch (e) {
      debugPrint('❌ Error unloading historical map overlay: $e');
    }
  }

  /// Update opacity of a historical map overlay
  Future<void> _updateHistoricalMapOpacity(HistoricalMapState mapState, double opacity) async {
    if (_mapboxMap == null) return;

    try {
      final overlayId = 'historical-map-${mapState.stateCode}-${mapState.layerId}';
      final overlay = _loadedOverlays.whereType<HistoricalMapOverlay>()
          .where((o) => o.id == overlayId)
          .firstOrNull;

      if (overlay != null) {
        await overlay.setOpacity(_mapboxMap!, opacity);
      }
    } catch (e) {
      debugPrint('❌ Error updating historical map opacity: $e');
    }
  }

  /// Sync historical map overlays with the provider state.
  /// This is called as a retry when the initial listener call was deferred due to style not being loaded.
  Future<void> _syncHistoricalMapOverlays() async {
    if (_mapboxMap == null || !_isStyleLoaded) return;

    final historicalMapsState = ref.read(historicalMapsProvider);
    debugPrint('🗺️ Syncing historical map overlays: ${historicalMapsState.maps.length} maps in provider');

    for (final mapState in historicalMapsState.maps.values) {
      final overlayId = 'historical-map-${mapState.stateCode}-${mapState.layerId}';
      final isLoaded = _loadedOverlays.any((o) => o.id == overlayId);

      if (mapState.isEnabled && !isLoaded) {
        // Map should be enabled but isn't loaded - load it
        debugPrint('🗺️ Sync: Loading historical map: ${mapState.key}');
        await _loadHistoricalMapOverlay(mapState);
      } else if (!mapState.isEnabled && isLoaded) {
        // Map should be disabled but is loaded - unload it
        debugPrint('🗺️ Sync: Unloading historical map: ${mapState.key}');
        await _unloadHistoricalMapOverlay(mapState);
      }
    }

    // Handle pending zoom bounds
    if (historicalMapsState.pendingZoomBounds != null) {
      debugPrint('🗺️ Sync: Zooming to pending bounds');
      _flyToHistoricalMapBounds(historicalMapsState.pendingZoomBounds!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(historicalMapsProvider.notifier).clearPendingZoom();
        }
      });
    }
  }

  /// Schedule retries for syncing historical map overlays when style isn't loaded yet.
  /// Uses exponential backoff: 200ms, 400ms, 800ms, 1600ms, 3200ms
  void _scheduleHistoricalMapRetry({required int retryCount, required int maxRetries}) {
    if (retryCount >= maxRetries) {
      // Don't log - fallback check will handle this
      return;
    }

    final delay = Duration(milliseconds: 200 * (1 << retryCount));

    Future.delayed(delay, () {
      if (!mounted) return;

      if (_isStyleLoaded && _mapboxMap != null) {
        debugPrint('🗺️ Historical maps: style ready, syncing overlays');
        _syncHistoricalMapOverlays();
      } else {
        // Silently schedule next retry
        _scheduleHistoricalMapRetry(retryCount: retryCount + 1, maxRetries: maxRetries);
      }
    });
  }

  Future<void> _toggleHillshade(bool enabled) async {
    // Save the setting
    final appSettingsService = ref.read(appSettingsServiceProvider);
    final currentMapSettings = ref.read(mapSettingsProvider);
    await appSettingsService.updateMapSettings(
      currentMapSettings.copyWith(showHillshade: enabled),
    );

    // Update the map layer
    if (enabled) {
      await _addHillshadeLayer();
    } else {
      await _removeHillshadeLayer();
    }
  }

  Future<void> _addHillshadeLayer() async {
    if (_mapboxMap == null) return;

    try {
      final style = _mapboxMap!.style;

      // Check if source already exists
      final sourceExists = await style.styleSourceExists('mapbox-dem');
      if (!sourceExists) {
        // Add the terrain DEM source
        await style.addSource(
          RasterDemSource(
            id: 'mapbox-dem',
            url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
            tileSize: 512,
            maxzoom: 14,
          ),
        );
      }

      // Check if layer already exists
      final layerExists = await style.styleLayerExists('hillshade-layer');
      if (!layerExists) {
        // Add hillshade layer below labels but above base map
        await style.addLayer(
          HillshadeLayer(
            id: 'hillshade-layer',
            sourceId: 'mapbox-dem',
            hillshadeIlluminationDirection: 335,
            hillshadeExaggeration: 0.5,
          ),
        );
      }

      debugPrint('🏔️ Hillshade layer added');
    } catch (e) {
      debugPrint('❌ Error adding hillshade layer: $e');
    }
  }

  Future<void> _removeHillshadeLayer() async {
    if (_mapboxMap == null) return;

    try {
      final style = _mapboxMap!.style;

      // Remove layer first
      final layerExists = await style.styleLayerExists('hillshade-layer');
      if (layerExists) {
        await style.removeStyleLayer('hillshade-layer');
      }

      // Remove source
      final sourceExists = await style.styleSourceExists('mapbox-dem');
      if (sourceExists) {
        await style.removeStyleSource('mapbox-dem');
      }

      debugPrint('🏔️ Hillshade layer removed');
    } catch (e) {
      debugPrint('❌ Error removing hillshade layer: $e');
    }
  }

  Widget _buildStyleOption(String label, MapStylePreference preference, IconData icon) {
    final isSelected = _stylePreference == preference;
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check, color: AppTheme.gold) : null,
      selected: isSelected,
      onTap: () {
        _selectMapStyle(preference);
        Navigator.pop(context);
      },
    );
  }

  /// Get the Mapbox style URI for a given preference and theme brightness
  String _getStyleUriForPreference(MapStylePreference preference, Brightness brightness) {
    switch (preference) {
      case MapStylePreference.outdoors:
        // Theme-aware: dark mode uses DARK, light mode uses OUTDOORS
        return brightness == Brightness.dark
            ? MapboxStyles.DARK
            : MapboxStyles.OUTDOORS;
      case MapStylePreference.satellite:
        return MapboxStyles.SATELLITE_STREETS;
      case MapStylePreference.streets:
        return MapboxStyles.STANDARD;
    }
  }

  /// Get the appropriate map style based on current theme brightness
  String _getThemeAppropriateStyle(Brightness brightness) {
    return _getStyleUriForPreference(_stylePreference, brightness);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    // Watch the settings provider to react when settings are loaded
    final appSettings = ref.watch(appSettingsProvider);

    // Listen for historical maps changes (toggled from filter panel or style selector)
    ref.listen<HistoricalMapsState>(historicalMapsProvider, (previous, next) {
      // ZOOM OPERATION: Only needs _mapboxMap, doesn't need style loaded
      // Handle this FIRST, before the style check, so zoom works even if style isn't ready
      if (_mapboxMap != null && next.pendingZoomBounds != null) {
        // Zoom if this is a NEW pending zoom (different from previous)
        final prevBounds = previous?.pendingZoomBounds;
        final isNewZoom = prevBounds == null ||
            prevBounds.centerLongitude != next.pendingZoomBounds!.centerLongitude ||
            prevBounds.centerLatitude != next.pendingZoomBounds!.centerLatitude;

        if (isNewZoom) {
          debugPrint('🗺️ Zooming to historical map: center=(${next.pendingZoomBounds!.centerLongitude.toStringAsFixed(2)}, ${next.pendingZoomBounds!.centerLatitude.toStringAsFixed(2)})');
          _flyToHistoricalMapBounds(next.pendingZoomBounds!);
        }
        // Always clear pending zoom to prevent stale state
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(historicalMapsProvider.notifier).clearPendingZoom();
          }
        });
      }

      // OVERLAY OPERATIONS: Need both _mapboxMap AND style loaded
      if (_mapboxMap == null || !_isStyleLoaded) {
        _scheduleHistoricalMapRetry(retryCount: 0, maxRetries: 5);
        return;
      }

      // Check all maps for load/unload/opacity changes
      for (final mapState in next.maps.values) {
        final overlayId = 'historical-map-${mapState.stateCode}-${mapState.layerId}';
        final isLoaded = _loadedOverlays.any((o) => o.id == overlayId);
        final isLoading = _loadingHistoricalMapIds.contains(overlayId);

        if (mapState.isEnabled && !isLoaded && !isLoading) {
          debugPrint('🗺️ Loading historical map overlay: ${mapState.key}');
          _loadHistoricalMapOverlay(mapState);
        } else if (!mapState.isEnabled && isLoaded) {
          debugPrint('🗺️ Unloading historical map overlay: ${mapState.key}');
          _unloadHistoricalMapOverlay(mapState);
        } else if (mapState.isEnabled && isLoaded) {
          // Map is enabled and loaded - check for opacity changes
          final previousState = previous?.maps[mapState.key];
          final previousOpacity = previousState?.opacity ?? 0.7;
          if (mapState.opacity != previousOpacity) {
            _updateHistoricalMapOpacity(mapState, mapState.opacity);
          }
        }
      }
    });

    // Initialize from saved settings ONCE when they become available
    if (!_hasInitializedFromSettings && appSettings.hasValue) {
      _hasInitializedFromSettings = true;
      final mapSettings = appSettings.value!.map;
      debugPrint('🗺️ Initializing from saved settings: style=${mapSettings.mapStylePreference}');

      // Apply saved settings (but use satellite for screenshots)
      _stylePreference = MapboxPresets.screenshotMode
          ? MapStylePreference.satellite
          : mapSettings.mapStylePreference;
      _rotationEnabled = mapSettings.rotateWithCompass;
      _hudOptions = MapHudOptions(
        showCoordinates: mapSettings.hudShowCoordinates,
        showElevation: mapSettings.hudShowElevation,
        showSpeed: mapSettings.hudShowSpeed,
        showHeading: mapSettings.hudShowHeading,
      );
      _currentStyleUri = _getStyleUriForPreference(_stylePreference, brightness);

      // If map is already ready, apply the style change
      if (_isMapReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _changeMapStyle(_currentStyleUri);
          }
        });
      }
    }

    // Sync map style with app theme when using theme-aware "outdoors" preference
    // This ensures dark/light mode changes are reflected in the map
    if (_isMapReady && _stylePreference == MapStylePreference.outdoors) {
      final themeStyle = _getThemeAppropriateStyle(brightness);
      if (_currentStyleUri != themeStyle) {
        // Schedule the style change after the build to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _changeMapStyle(themeStyle);
          }
        });
      }
    }

    return Stack(
      children: [
        // Wrap MapWidget with Listener to track multi-touch gestures
        // This enables scroll deceleration suppression after pinch-to-zoom
        Listener(
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          child: MapWidget(
            key: const ValueKey('mapboxWidget'),
            cameraOptions: CameraOptions(
              center: widget.config.initialCenter,
              zoom: widget.config.initialZoom,
            ),
            styleUri: _currentStyleUri,
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
            onCameraChangeListener: _onCameraChange,
            onMapIdleListener: _onMapIdle,
            onTapListener: _onMapTap,
            onLongTapListener: _onMapLongTap,
          ),
        ),

        // Loading indicator while map initializes (prevents black screen)
        if (!_isMapReady)
          ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),

        // HUD overlay (displays location data when enabled)
        // Hidden when hideOverlays is true (e.g., search overlay is active)
        if (widget.config.showMapControls && !widget.hideOverlays)
          MapHudOverlay(options: _hudOptions),

        // Center target crosshair (shows where land rights checks occur)
        // Tied to land rights banner setting - when banner is shown, crosshair shows the query location
        // Hidden when hideOverlays is true (e.g., search overlay is active)
        if (widget.config.showMapControls && widget.showLandRightsBanner && !widget.hideOverlays)
          const MapCenterTarget(),

        // Bottom sheet map controls
        // Hidden when hideOverlays is true (e.g., search overlay is active)
        if (widget.config.showMapControls && !widget.hideOverlays)
          MapControlsSheet(
            onCenterLocation: _centerOnCurrentLocation,
            onResetNorth: _resetNorth,
            onToggleRotation: _toggleRotation,
            onShowStyleSelector: _showStyleSelector,
            onHudOptionsChanged: (options) {
              setState(() {
                _hudOptions = options;
              });
              // Persist HUD settings
              // Note: Center target is now controlled by showLandRightsBanner, not HUD
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
            onExpandedChanged: widget.onControlsExpandedChanged,
            isFollowingLocation: widget.isFollowingLocation,
            isRotationEnabled: _rotationEnabled,
            currentBearing: _currentBearing,
            showRotationControl: widget.config.enableRotation,
            hudOptions: _hudOptions,
            onAddWaypoint: widget.onAddWaypoint,
            onCheckPermissions: widget.onCheckPermissions,
            isTrackingActive: widget.isTrackingActive,
            showLandRightsBanner: widget.showLandRightsBanner,
            onToggleLandRightsBanner: widget.onToggleLandRightsBanner,
          ),
      ],
    );
  }
}
