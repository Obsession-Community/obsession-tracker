import 'package:flutter/material.dart';

/// Compact banner shown when user is zoomed out too far to display full data
///
/// Helps users understand why data coverage may be limited and guides them to zoom in.
class ZoomHintBanner extends StatelessWidget {
  const ZoomHintBanner({
    super.key,
    required this.currentZoom,
    required this.minZoomForLandData, // Kept for API compatibility, not used
    required this.minZoomForTrailData,
    required this.landOverlayVisible, // Kept for API compatibility, not used
    required this.trailsOverlayVisible,
  });

  final double currentZoom;
  final double minZoomForLandData; // Deprecated - land data now works at all zoom levels
  final double minZoomForTrailData;
  final bool landOverlayVisible; // Deprecated - land data now works at all zoom levels
  final bool trailsOverlayVisible;

  @override
  Widget build(BuildContext context) {
    // Show banner when zoomed out past the trail data threshold
    // At this zoom level, both land and trail data are limited
    final tooZoomedOut = trailsOverlayVisible && currentZoom < minZoomForTrailData;

    // Don't show if we're zoomed in enough or trails aren't enabled
    if (!tooZoomedOut) {
      return const SizedBox.shrink();
    }

    // Message indicating both land and trail data are limited at this zoom
    const String message = 'Zoom in for land and trail data';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.blueGrey.shade800.withValues(alpha: 0.95)
            : Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.blueGrey.shade600 : Colors.blueGrey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.zoom_in,
            color: isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.blueGrey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
