import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/mapbox_config.dart';
import 'package:obsession_tracker/core/providers/map_search_provider.dart';
import 'package:obsession_tracker/core/services/map_search_service.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/map_search_widget.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/mapbox_map_widget.dart';

/// Result from the location map picker
class LocationPickerResult {
  const LocationPickerResult({
    required this.latitude,
    required this.longitude,
    this.placeName,
  });

  final double latitude;
  final double longitude;
  final String? placeName;
}

/// Full-screen map picker for selecting a location by tapping or searching
class LocationMapPicker extends ConsumerStatefulWidget {
  const LocationMapPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.title = 'Pick Location',
  });

  /// Initial latitude to center the map on (if provided)
  final double? initialLatitude;

  /// Initial longitude to center the map on (if provided)
  final double? initialLongitude;

  /// Title shown in the app bar
  final String title;

  @override
  ConsumerState<LocationMapPicker> createState() => _LocationMapPickerState();
}

class _LocationMapPickerState extends ConsumerState<LocationMapPicker> {
  MapboxMap? _mapboxMap;
  double? _selectedLat;
  double? _selectedLon;
  String? _selectedPlaceName;
  bool _isLoadingLocation = true;
  bool _showSearch = false;
  PointAnnotationManager? _markerManager;
  PointAnnotation? _centerMarker;

  @override
  void initState() {
    super.initState();
    // Use initial coordinates if provided, otherwise get current location
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLat = widget.initialLatitude;
      _selectedLon = widget.initialLongitude;
      _isLoadingLocation = false;
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Default to US center if location unavailable
        setState(() {
          _selectedLat = 39.8283;
          _selectedLon = -98.5795;
          _isLoadingLocation = false;
        });
        return;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        // Default to US center
        setState(() {
          _selectedLat = 39.8283;
          _selectedLon = -98.5795;
          _isLoadingLocation = false;
        });
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      setState(() {
        _selectedLat = position.latitude;
        _selectedLon = position.longitude;
        _isLoadingLocation = false;
      });
    } catch (e) {
      // Default to US center on error
      setState(() {
        _selectedLat = 39.8283;
        _selectedLon = -98.5795;
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    // Create annotation manager for center marker
    _markerManager = await map.annotations.createPointAnnotationManager();

    // Add initial marker if we have coordinates
    if (_selectedLat != null && _selectedLon != null) {
      await _updateCenterMarker();
    }
  }

  Future<void> _updateCenterMarker() async {
    if (_markerManager == null || _selectedLat == null || _selectedLon == null) {
      return;
    }

    // Remove existing marker
    if (_centerMarker != null) {
      await _markerManager!.delete(_centerMarker!);
      _centerMarker = null;
    }

    // Create new marker at selected position
    final options = PointAnnotationOptions(
      geometry: Point(
        coordinates: Position(_selectedLon!, _selectedLat!),
      ),
      iconSize: 1.5,
      iconColor: AppTheme.gold.toARGB32(),
      // Use built-in marker icon
      iconImage: 'marker-15',
    );

    _centerMarker = await _markerManager!.create(options);
  }

  void _onMapTap(Point point) {
    final coordinates = point.coordinates;
    setState(() {
      _selectedLat = coordinates.lat.toDouble();
      _selectedLon = coordinates.lng.toDouble();
      _selectedPlaceName = null; // Clear place name when tapping map
    });
    _updateCenterMarker();
  }

  void _onSearchResultSelected(MapSearchResult result) {
    // Coordinates should be present after retrieval
    final lat = result.latitude;
    final lon = result.longitude;
    if (lat == null || lon == null) return;

    setState(() {
      _selectedLat = lat;
      _selectedLon = lon;
      _selectedPlaceName = result.displayName;
      _showSearch = false;
    });

    // Fly to the selected location
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(lon, lat),
        ),
        zoom: 15.0,
      ),
      MapAnimationOptions(duration: 1000),
    );

    _updateCenterMarker();
  }

  void _confirmSelection() {
    if (_selectedLat != null && _selectedLon != null) {
      Navigator.of(context).pop(
        LocationPickerResult(
          latitude: _selectedLat!,
          longitude: _selectedLon!,
          placeName: _selectedPlaceName,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchService = ref.watch(mapSearchServiceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoadingLocation) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Getting location...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () => setState(() => _showSearch = !_showSearch),
            tooltip: 'Search location',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          MapboxMapWidget(
            config: MapboxMapConfig(
              initialCenter: Point(
                coordinates: Position(_selectedLon!, _selectedLat!),
              ),
              initialZoom: 14.0,
              followUserLocation: false,
              showMapControls: false,
            ),
            onMapCreated: _onMapCreated,
            onMapTap: _onMapTap,
          ),

          // Center crosshair overlay (visual feedback)
          Center(
            child: IgnorePointer(
              child: Container(
                width: 2,
                height: 40,
                color: AppTheme.gold.withValues(alpha: 0.7),
              ),
            ),
          ),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 40,
                height: 2,
                color: AppTheme.gold.withValues(alpha: 0.7),
              ),
            ),
          ),

          // Search overlay
          if (_showSearch)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: isDark ? Colors.black87 : Colors.white,
                padding: const EdgeInsets.all(16),
                child: SafeArea(
                  child: MapSearchWidget(
                    searchService: searchService,
                    onResultSelected: _onSearchResultSelected,
                    proximityLat: _selectedLat,
                    proximityLon: _selectedLon,
                  ),
                ),
              ),
            ),

          // Bottom panel with coordinates and confirm button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Coordinates display
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey[800]
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedPlaceName != null) ...[
                              Text(
                                _selectedPlaceName!,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                            ],
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: AppTheme.gold,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_selectedLat?.toStringAsFixed(6)}, ${_selectedLon?.toStringAsFixed(6)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Help text
                      Text(
                        'Tap the map or search to select a location',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Confirm button
                      ElevatedButton.icon(
                        onPressed: _selectedLat != null && _selectedLon != null
                            ? _confirmSelection
                            : null,
                        icon: const Icon(Icons.check),
                        label: const Text('Use This Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
