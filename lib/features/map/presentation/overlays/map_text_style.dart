/// Mapbox text styling constants for universal visibility
///
/// These values follow Mapbox's recommendations for text that works
/// on both light and dark map themes across all devices.
///
/// Reference: https://docs.mapbox.com/help/troubleshooting/manage-fontstacks/
class MapTextStyle {
  MapTextStyle._();

  // ============================================================================
  // Colors - White text with black halo for universal visibility
  // ============================================================================

  /// White text - visible on both light and dark backgrounds when paired with halo
  static const int textColor = 0xFFFFFFFF;

  /// Black halo around text for contrast on any background
  static const int textHaloColor = 0xFF000000;

  // ============================================================================
  // Halo Settings - Mapbox recommended for mobile devices
  // ============================================================================

  /// Halo width for optimal visibility on mobile devices
  /// Note: Max text halo width is 1/4 of the font-size
  /// For 12px font, max is 3.0. Using 1.5 for clean look.
  static const double textHaloWidth = 1.5;

  /// Halo blur - 0 for sharp edges (Mapbox default recommendation)
  /// Higher values create softer halos but can look blurry on some devices
  static const double textHaloBlur = 0.0;

  // ============================================================================
  // Font Settings - Mapbox built-in fonts for best rendering
  // ============================================================================

  /// Mapbox recommended font stack for labels
  /// "Open Sans Semibold" is available in all Mapbox styles and renders well
  static const List<String> labelFont = ['Open Sans Semibold', 'Arial Unicode MS Bold'];

  /// Mapbox recommended font stack for bold text (cluster counts, emphasis)
  static const List<String> boldFont = ['Open Sans Bold', 'Arial Unicode MS Bold'];

  // ============================================================================
  // Text Sizes
  // ============================================================================

  /// Standard text size for marker labels
  static const double markerLabelSize = 12.0;

  /// Standard text size for waypoint labels
  static const double waypointLabelSize = 12.0;

  /// Standard text size for cluster counts
  static const double clusterCountSize = 12.0;

  // ============================================================================
  // Layout Settings
  // ============================================================================

  /// Maximum width for text wrapping (in ems)
  static const double textMaxWidth = 8.0;

  /// Letter spacing for better readability
  static const double textLetterSpacing = 0.05;
}
