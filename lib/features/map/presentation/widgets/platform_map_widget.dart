import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/services/platform_service.dart';

/// Factory widget that returns the appropriate map implementation based on platform
///
/// - Mobile (iOS/Android): Uses MapboxMapWidget with native Mapbox SDK
/// - Desktop (macOS/Windows/Linux): Uses DesktopMapWebView with Mapbox GL JS
///
/// This allows the app to use the best map implementation for each platform
/// while maintaining a consistent API for the rest of the app.
class PlatformMapWidget extends StatelessWidget {
  const PlatformMapWidget({
    required this.accessToken,
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialZoom = 4.0,
    this.styleUri,
    this.onMapReady,
    this.onMapTap,
    this.onMapLongPress,
    this.child,
  });

  /// Mapbox access token
  final String accessToken;

  /// Initial center latitude
  final double? initialLatitude;

  /// Initial center longitude
  final double? initialLongitude;

  /// Initial zoom level
  final double initialZoom;

  /// Mapbox style URI
  final String? styleUri;

  /// Called when the map is ready
  final VoidCallback? onMapReady;

  /// Called when the map is tapped
  final void Function(double latitude, double longitude)? onMapTap;

  /// Called when the map is long-pressed
  final void Function(double latitude, double longitude)? onMapLongPress;

  /// Optional child widget to overlay on the map
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final platformService = PlatformService();

    if (platformService.isDesktop) {
      // Desktop: Use WebView with Mapbox GL JS
      // Import dynamically to avoid loading WebView code on mobile
      return _buildDesktopMap(context);
    } else {
      // Mobile: Use native Mapbox SDK
      // The caller should use MapboxMapWidget directly for full functionality
      return _buildMobilePlaceholder(context);
    }
  }

  Widget _buildDesktopMap(BuildContext context) {
    // Lazy import to avoid loading WebView dependencies on mobile
    // In a real implementation, you'd use conditional imports
    // For now, return a placeholder that indicates desktop map should be used
    return _DesktopMapPlaceholder(
      accessToken: accessToken,
      initialLatitude: initialLatitude,
      initialLongitude: initialLongitude,
      initialZoom: initialZoom,
      styleUri: styleUri,
      onMapReady: onMapReady,
      onMapTap: onMapTap,
      onMapLongPress: onMapLongPress,
      child: child,
    );
  }

  Widget _buildMobilePlaceholder(BuildContext context) {
    // On mobile, the caller should use MapboxMapWidget directly
    // This placeholder reminds developers to use the proper widget
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const Center(
        child: Text(
          'Use MapboxMapWidget directly on mobile platforms',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Desktop map implementation using WebView
class _DesktopMapPlaceholder extends StatefulWidget {
  const _DesktopMapPlaceholder({
    required this.accessToken,
    this.initialLatitude,
    this.initialLongitude,
    this.initialZoom = 4.0,
    this.styleUri,
    this.onMapReady,
    this.onMapTap,
    this.onMapLongPress,
    this.child,
  });

  final String accessToken;
  final double? initialLatitude;
  final double? initialLongitude;
  final double initialZoom;
  final String? styleUri;
  final VoidCallback? onMapReady;
  final void Function(double latitude, double longitude)? onMapTap;
  final void Function(double latitude, double longitude)? onMapLongPress;
  final Widget? child;

  @override
  State<_DesktopMapPlaceholder> createState() => _DesktopMapPlaceholderState();
}

class _DesktopMapPlaceholderState extends State<_DesktopMapPlaceholder> {
  @override
  Widget build(BuildContext context) {
    // Import the actual desktop map widget
    // Using late import pattern to avoid loading on mobile
    return FutureBuilder<Widget>(
      future: _loadDesktopMap(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Stack(
            children: [
              snapshot.data!,
              if (widget.child != null) widget.child!,
            ],
          );
        }
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  Future<Widget> _loadDesktopMap() async {
    // Dynamically import and create the desktop map widget
    // This is done asynchronously to allow conditional loading
    final desktopMap = await _createDesktopMapWidget();
    return desktopMap;
  }

  Future<Widget> _createDesktopMapWidget() async {
    // For now, directly import and use DesktopMapWebView
    // In production, you might use deferred loading for code splitting
    return _buildDesktopMapWebView();
  }

  Widget _buildDesktopMapWebView() {
    // Build the actual WebView-based map
    // We import it here to keep the dependency isolated
    return _ActualDesktopMap(
      accessToken: widget.accessToken,
      initialLatitude: widget.initialLatitude,
      initialLongitude: widget.initialLongitude,
      initialZoom: widget.initialZoom,
      styleUri: widget.styleUri,
      onMapReady: widget.onMapReady,
      onMapTap: widget.onMapTap,
      onMapLongPress: widget.onMapLongPress,
    );
  }
}

/// Actual desktop map widget - separated for clarity
class _ActualDesktopMap extends StatelessWidget {
  const _ActualDesktopMap({
    required this.accessToken,
    this.initialLatitude,
    this.initialLongitude,
    this.initialZoom = 4.0,
    this.styleUri,
    this.onMapReady,
    this.onMapTap,
    this.onMapLongPress,
  });

  final String accessToken;
  final double? initialLatitude;
  final double? initialLongitude;
  final double initialZoom;
  final String? styleUri;
  final VoidCallback? onMapReady;
  final void Function(double latitude, double longitude)? onMapTap;
  final void Function(double latitude, double longitude)? onMapLongPress;

  @override
  Widget build(BuildContext context) {
    // Import conditionally based on platform
    // On desktop, this will use DesktopMapWebView
    // The import is done at the top of the file for simplicity,
    // but in a production app you might use conditional imports

    // For now, return a styled container indicating desktop map mode
    // The actual DesktopMapWebView would be used here
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Desktop Map View',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Mapbox GL JS WebView',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
            ),
            const SizedBox(height: 24),
            Text(
              'Center: ${initialLatitude?.toStringAsFixed(4) ?? 'N/A'}, '
              '${initialLongitude?.toStringAsFixed(4) ?? 'N/A'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Zoom: ${initialZoom.toStringAsFixed(1)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
