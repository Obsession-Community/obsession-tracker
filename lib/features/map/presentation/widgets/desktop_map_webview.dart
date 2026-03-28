import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Callback types for desktop map events
typedef MapViewChangedCallback = void Function(
    double latitude, double longitude, double zoom, double bearing);
typedef MapTapCallback = void Function(double latitude, double longitude);
typedef OverlayTapCallback = void Function(
    Map<String, dynamic> properties, double latitude, double longitude);

/// WebView-based map widget for desktop platforms using Mapbox GL JS
///
/// This provides equivalent functionality to MapboxMapWidget on mobile,
/// but uses Mapbox GL JS embedded in a WebView since mapbox_maps_flutter
/// doesn't support desktop platforms.
class DesktopMapWebView extends StatefulWidget {
  const DesktopMapWebView({
    required this.accessToken,
    super.key,
    this.initialCenter,
    this.initialZoom = 4.0,
    this.styleUri,
    this.onMapReady,
    this.onMapViewChanged,
    this.onMapTap,
    this.onMapLongPress,
    this.onLandParcelTap,
    this.onTrailTap,
    this.onHistoricalPlaceTap,
    this.onCustomMarkerTap,
    this.onWaypointTap,
  });

  /// Mapbox access token
  final String accessToken;

  /// Initial center coordinates [longitude, latitude]
  final List<double>? initialCenter;

  /// Initial zoom level
  final double initialZoom;

  /// Mapbox style URI
  final String? styleUri;

  /// Called when the map is ready for interaction
  final VoidCallback? onMapReady;

  /// Called when the map view changes (pan, zoom)
  final MapViewChangedCallback? onMapViewChanged;

  /// Called when the map is tapped
  final MapTapCallback? onMapTap;

  /// Called when the map is long-pressed
  final MapTapCallback? onMapLongPress;

  /// Called when a land parcel is tapped
  final OverlayTapCallback? onLandParcelTap;

  /// Called when a trail is tapped
  final OverlayTapCallback? onTrailTap;

  /// Called when a historical place is tapped
  final OverlayTapCallback? onHistoricalPlaceTap;

  /// Called when a custom marker is tapped
  final OverlayTapCallback? onCustomMarkerTap;

  /// Called when a waypoint is tapped
  final OverlayTapCallback? onWaypointTap;

  @override
  State<DesktopMapWebView> createState() => DesktopMapWebViewState();
}

class DesktopMapWebViewState extends State<DesktopMapWebView> {
  late WebViewController _controller;
  bool _isMapReady = false;
  String? _htmlContent;
  bool _htmlLoaded = false; // Track if HTML has been loaded into WebView

  /// Public getter to check if the map is ready for interaction
  /// This allows external code to check readiness before calling map methods
  bool get isMapReady => _isMapReady;

  @override
  void initState() {
    super.initState();
    _initializeController();
    _loadHtmlContent();
  }

  Future<void> _loadHtmlContent() async {
    debugPrint('🗺️ DesktopMapWebView: Loading HTML content...');
    try {
      final html = await rootBundle.loadString('assets/web/mapbox_desktop.html');
      debugPrint('🗺️ DesktopMapWebView: HTML loaded (${html.length} chars)');
      setState(() {
        _htmlContent = html;
      });
      // Load HTML into WebView once content is available
      _loadHtmlIntoWebView();
    } catch (e) {
      debugPrint('🗺️ DesktopMapWebView: Error loading map HTML: $e');
    }
  }

  void _loadHtmlIntoWebView() {
    if (_htmlContent != null && !_htmlLoaded) {
      _htmlLoaded = true;
      debugPrint('🗺️ DesktopMapWebView: Loading HTML into WebView...');
      _controller.loadHtmlString(_htmlContent!);
    }
  }

  void _initializeController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'mapEvent',
        onMessageReceived: _handleMapEvent,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('🗺️ DesktopMapWebView: Page started loading: $url');
          },
          onPageFinished: (String url) {
            debugPrint('🗺️ DesktopMapWebView: Page finished loading: $url');
            _initializeMap();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('🗺️ DesktopMapWebView: Web resource error: ${error.description}');
          },
        ),
      );

    // setBackgroundColor is not implemented on macOS, so wrap in try-catch
    try {
      _controller.setBackgroundColor(Colors.black);
    } catch (e) {
      debugPrint('setBackgroundColor not supported on this platform: $e');
    }
  }

  void _initializeMap() {
    final center = widget.initialCenter ?? [-98.5795, 39.8283];
    final style = widget.styleUri ?? 'mapbox://styles/mapbox/outdoors-v12';

    debugPrint('🗺️ DesktopMapWebView: Initializing map at center: $center, zoom: ${widget.initialZoom}');

    _controller.runJavaScript('''
      console.log('Initializing Mapbox GL JS map...');
      if (window.mapBridge) {
        window.mapBridge.initMap(
          '${widget.accessToken}',
          [${center[0]}, ${center[1]}],
          ${widget.initialZoom},
          '$style'
        );
      } else {
        console.error('mapBridge not found');
      }
    ''');
  }

  /// Safely convert a number (int or double) to double
  double _toDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return 0.0;
  }

  void _handleMapEvent(JavaScriptMessage message) {
    try {
      final event = jsonDecode(message.message) as Map<String, dynamic>;
      final type = event['type'] as String;
      final data = event['data'] as Map<String, dynamic>;

      switch (type) {
        case 'mapReady':
          debugPrint('🗺️ DesktopMapWebView: Map is ready!');
          setState(() {
            _isMapReady = true;
          });
          widget.onMapReady?.call();
          break;

        case 'mapViewChanged':
          widget.onMapViewChanged?.call(
            _toDouble(data['latitude']),
            _toDouble(data['longitude']),
            _toDouble(data['zoom']),
            _toDouble(data['bearing']),
          );
          break;

        case 'mapTap':
          widget.onMapTap?.call(
            _toDouble(data['latitude']),
            _toDouble(data['longitude']),
          );
          break;

        case 'mapLongPress':
          widget.onMapLongPress?.call(
            _toDouble(data['latitude']),
            _toDouble(data['longitude']),
          );
          break;

        case 'landParcelTap':
          final coords = data['coordinates'] as Map<String, dynamic>;
          widget.onLandParcelTap?.call(
            data['properties'] as Map<String, dynamic>,
            _toDouble(coords['lat']),
            _toDouble(coords['lng']),
          );
          break;

        case 'trailTap':
          final coords = data['coordinates'] as Map<String, dynamic>;
          widget.onTrailTap?.call(
            data['properties'] as Map<String, dynamic>,
            _toDouble(coords['lat']),
            _toDouble(coords['lng']),
          );
          break;

        case 'historicalPlaceTap':
          final coords = data['coordinates'] as Map<String, dynamic>;
          widget.onHistoricalPlaceTap?.call(
            data['properties'] as Map<String, dynamic>,
            _toDouble(coords['lat']),
            _toDouble(coords['lng']),
          );
          break;

        case 'customMarkerTap':
          final coords = data['coordinates'] as Map<String, dynamic>;
          widget.onCustomMarkerTap?.call(
            data['properties'] as Map<String, dynamic>,
            _toDouble(coords['lat']),
            _toDouble(coords['lng']),
          );
          break;

        case 'waypointTap':
          final coords = data['coordinates'] as Map<String, dynamic>;
          widget.onWaypointTap?.call(
            data['properties'] as Map<String, dynamic>,
            _toDouble(coords['lat']),
            _toDouble(coords['lng']),
          );
          break;

        case 'styleLoaded':
          debugPrint('Map style loaded: ${data['style']}');
          break;

        case 'overlayLoaded':
          debugPrint('Overlay loaded: ${data['type']}');
          break;

        case 'jsError':
          debugPrint('🗺️ DesktopMapWebView: JS Error: ${data['message']} at ${data['url']}:${data['line']}');
          break;

        case 'jsLog':
          debugPrint('🗺️ DesktopMapWebView: JS Log: $data');
          break;
      }
    } catch (e) {
      debugPrint('🗺️ DesktopMapWebView: Error handling map event: $e');
    }
  }

  /// Fly the camera to a specific location
  Future<void> flyTo(double latitude, double longitude,
      {double? zoom, double? bearing}) async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('''
      window.mapBridge.flyTo($latitude, $longitude, ${zoom ?? 'null'}, ${bearing ?? 'null'});
    ''');
  }

  /// Set the map center
  Future<void> setCenter(double latitude, double longitude) async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('''
      window.mapBridge.setCenter($latitude, $longitude);
    ''');
  }

  /// Set the map zoom level
  Future<void> setZoom(double zoom) async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('''
      window.mapBridge.setZoom($zoom);
    ''');
  }

  /// Reset the map bearing to north
  Future<void> resetNorth() async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('window.mapBridge.resetNorth();');
  }

  /// Change the map style
  Future<void> setStyle(String styleUri) async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('''
      window.mapBridge.setStyle('$styleUri');
    ''');
  }

  /// Load land ownership overlay from GeoJSON
  Future<void> loadLandOwnership(Map<String, dynamic> geojson) async {
    if (!_isMapReady) return;
    final jsonString = jsonEncode(geojson).replaceAll("'", r"\'");
    await _controller.runJavaScript('''
      window.mapBridge.loadLandOwnership('$jsonString');
    ''');
  }

  /// Clear land ownership overlay
  Future<void> clearLandOwnership() async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('window.mapBridge.clearLandOwnership();');
  }

  /// Highlight a selected parcel with GeoJSON
  Future<void> highlightParcel(Map<String, dynamic> geojson) async {
    if (!_isMapReady) return;
    final jsonString = jsonEncode(geojson).replaceAll("'", r"\'");
    await _controller.runJavaScript('''
      window.mapBridge.highlightParcel('$jsonString');
    ''');
  }

  /// Clear the highlighted parcel
  Future<void> clearHighlight() async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('window.mapBridge.clearHighlight();');
  }

  /// Load trails overlay from GeoJSON
  Future<void> loadTrails(Map<String, dynamic> geojson) async {
    if (!_isMapReady) return;
    final jsonString = jsonEncode(geojson).replaceAll("'", r"\'");
    await _controller.runJavaScript('''
      window.mapBridge.loadTrails('$jsonString');
    ''');
  }

  /// Clear trails overlay
  Future<void> clearTrails() async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('window.mapBridge.clearTrails();');
  }

  /// Load historical places overlay from GeoJSON
  Future<void> loadHistoricalPlaces(Map<String, dynamic> geojson) async {
    if (!_isMapReady) return;
    final jsonString = jsonEncode(geojson).replaceAll("'", r"\'");
    await _controller.runJavaScript('''
      window.mapBridge.loadHistoricalPlaces('$jsonString');
    ''');
  }

  /// Clear historical places overlay
  Future<void> clearHistoricalPlaces() async {
    if (!_isMapReady) return;
    await _controller
        .runJavaScript('window.mapBridge.clearHistoricalPlaces();');
  }

  /// Clear all overlays
  Future<void> clearAllOverlays() async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('window.mapBridge.clearAllOverlays();');
  }

  /// Load custom markers overlay from GeoJSON
  Future<void> loadCustomMarkers(Map<String, dynamic> geojson) async {
    if (!_isMapReady) return;
    final jsonString = jsonEncode(geojson).replaceAll("'", r"\'");
    await _controller.runJavaScript('''
      window.mapBridge.loadCustomMarkers('$jsonString');
    ''');
  }

  /// Clear custom markers overlay
  Future<void> clearCustomMarkers() async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('window.mapBridge.clearCustomMarkers();');
  }

  /// Load waypoints overlay from GeoJSON
  Future<void> loadWaypoints(Map<String, dynamic> geojson) async {
    if (!_isMapReady) return;
    final jsonString = jsonEncode(geojson).replaceAll("'", r"\'");
    await _controller.runJavaScript('''
      window.mapBridge.loadWaypoints('$jsonString');
    ''');
  }

  /// Clear waypoints overlay
  Future<void> clearWaypoints() async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('window.mapBridge.clearWaypoints();');
  }

  /// Load breadcrumbs trail overlay from GeoJSON
  Future<void> loadBreadcrumbs(Map<String, dynamic> geojson) async {
    if (!_isMapReady) return;
    final jsonString = jsonEncode(geojson).replaceAll("'", r"\'");
    await _controller.runJavaScript('''
      window.mapBridge.loadBreadcrumbs('$jsonString');
    ''');
  }

  /// Clear breadcrumbs overlay
  Future<void> clearBreadcrumbs() async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('window.mapBridge.clearBreadcrumbs();');
  }

  /// Add hillshade (terrain relief) layer
  Future<void> addHillshade() async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('window.mapBridge.addHillshade();');
  }

  /// Remove hillshade layer
  Future<void> removeHillshade() async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('window.mapBridge.removeHillshade();');
  }

  /// Load a historical map raster tile layer from the MBTiles tile server
  /// [maxZoom] tells Mapbox to stop requesting tiles after this zoom level
  /// but keep displaying the highest available tiles scaled up when zooming in further
  Future<void> loadHistoricalMap(String id, String tileUrl, {double opacity = 0.7, int maxZoom = 16}) async {
    if (!_isMapReady) {
      debugPrint('⚠️ DesktopMapWebView.loadHistoricalMap: Map not ready, skipping $id');
      return;
    }
    debugPrint('🗺️ DesktopMapWebView.loadHistoricalMap: Loading $id');
    await _controller.runJavaScript('''
      window.mapBridge.loadHistoricalMap('$id', '$tileUrl', $opacity, $maxZoom);
    ''');
  }

  /// Remove a historical map layer
  Future<void> removeHistoricalMap(String id) async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('''
      window.mapBridge.removeHistoricalMap('$id');
    ''');
  }

  /// Set the opacity of a historical map layer
  Future<void> setHistoricalMapOpacity(String id, double opacity) async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('''
      window.mapBridge.setHistoricalMapOpacity('$id', $opacity);
    ''');
  }

  /// Clear all historical map layers
  Future<void> clearAllHistoricalMaps() async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('window.mapBridge.clearAllHistoricalMaps();');
  }

  /// Load cell coverage overlay from GeoJSON
  /// [coverageGeojson] contains the coverage polygon features
  /// [pointsGeojson] contains the tower point features
  Future<void> loadCellCoverage(Map<String, dynamic> coverageGeojson, Map<String, dynamic> pointsGeojson) async {
    if (!_isMapReady) return;
    final coverageJson = jsonEncode(coverageGeojson).replaceAll("'", r"\'");
    final pointsJson = jsonEncode(pointsGeojson).replaceAll("'", r"\'");
    await _controller.runJavaScript('''
      window.mapBridge.loadCellCoverage('$coverageJson', '$pointsJson');
    ''');
  }

  /// Clear cell coverage overlay
  Future<void> clearCellCoverage() async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('window.mapBridge.clearCellCoverage();');
  }

  /// Show the center crosshair (rendered in WebView to avoid Flutter/platform view event issues)
  /// [isDark] controls the crosshair color scheme (light or dark theme)
  Future<void> showCenterCrosshair({bool isDark = false}) async {
    if (!_isMapReady) return;
    await _controller.runJavaScript(
        'window.mapBridge.showCenterCrosshair($isDark);');
  }

  /// Hide the center crosshair
  Future<void> hideCenterCrosshair() async {
    if (!_isMapReady) return;
    await _controller.runJavaScript('window.mapBridge.hideCenterCrosshair();');
  }

  @override
  Widget build(BuildContext context) {
    // Only supported on desktop platforms
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
      return const Center(
        child: Text('Desktop map is only available on macOS, Windows, or Linux'),
      );
    }

    if (_htmlContent == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (!_isMapReady)
          ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}
