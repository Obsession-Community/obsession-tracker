import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';

/// Service for managing waypoint icons and their properties
///
/// Provides centralized access to SVG waypoint icons with support for:
/// - Basic and filled icon states
/// - Multiple size variants (16px, 24px, 32px)
/// - Color management for theming
/// - Integration with WaypointType enum
class WaypointIconService {
  WaypointIconService._();

  static final WaypointIconService _instance = WaypointIconService._();

  /// Singleton instance of the waypoint icon service
  static WaypointIconService get instance => _instance;

  /// Base path for waypoint SVG assets
  static const String _basePath = 'assets/icons/waypoints';

  /// Available icon sizes in pixels
  static const Map<String, double> iconSizes = <String, double>{
    'small': 16.0,
    'medium': 24.0,
    'large': 32.0,
  };

  /// Get the SVG asset path for a waypoint type
  ///
  /// [type] - The waypoint type
  /// [filled] - Whether to use the filled variant (default: false)
  ///
  /// Returns the asset path string for use with SvgPicture.asset()
  String getIconPath(WaypointType type, {bool filled = false}) {
    final String suffix = filled ? '_filled' : '';
    return '$_basePath/${type.iconName}$suffix.svg';
  }

  /// Get the primary color for a waypoint type
  ///
  /// [type] - The waypoint type
  ///
  /// Returns the Color object for the waypoint type
  Color getIconColor(WaypointType type) {
    final String colorHex = type.colorHex;
    return Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
  }

  /// Get the darker variant color for filled icons
  ///
  /// [type] - The waypoint type
  ///
  /// Returns a darker Color object for stroke/border use
  Color getIconDarkColor(WaypointType type) {
    // Get the base color from the type's colorHex and create a darker variant
    final baseColor = getIconColor(type);
    // Create a darker version by reducing brightness
    final hslColor = HSLColor.fromColor(baseColor);
    return hslColor.withLightness((hslColor.lightness * 0.7).clamp(0.0, 1.0)).toColor();
  }

  /// Create an SvgPicture widget for a waypoint type
  ///
  /// [type] - The waypoint type
  /// [size] - The icon size (default: 'medium')
  /// [filled] - Whether to use the filled variant (default: false)
  /// [color] - Optional color override (uses type color if null)
  ///
  /// Returns a configured SvgPicture widget
  Widget getIconWidget(
    WaypointType type, {
    String size = 'medium',
    bool filled = false,
    Color? color,
  }) {
    final double iconSize = iconSizes[size] ?? iconSizes['medium']!;
    final String assetPath = getIconPath(type, filled: filled);
    final Color iconColor = color ?? getIconColor(type);

    return SvgPicture.asset(
      assetPath,
      width: iconSize,
      height: iconSize,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      semanticsLabel: '${type.displayName} waypoint icon',
    );
  }

  /// Create an SvgPicture widget with custom size
  ///
  /// [type] - The waypoint type
  /// [width] - Custom width in pixels
  /// [height] - Custom height in pixels (defaults to width if null)
  /// [filled] - Whether to use the filled variant (default: false)
  /// [color] - Optional color override (uses type color if null)
  ///
  /// Returns a configured SvgPicture widget with custom dimensions
  Widget getIconWidgetCustomSize(
    WaypointType type, {
    required double width,
    double? height,
    bool filled = false,
    Color? color,
  }) {
    final String assetPath = getIconPath(type, filled: filled);
    final Color iconColor = color ?? getIconColor(type);

    return SvgPicture.asset(
      assetPath,
      width: width,
      height: height ?? width,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      semanticsLabel: '${type.displayName} waypoint icon',
    );
  }

  /// Get all available waypoint types with their display properties
  ///
  /// Returns a list of maps containing type information for UI building
  List<Map<String, dynamic>> getAllWaypointTypeInfo() => WaypointType.values
      .map((WaypointType type) => <String, Object>{
            'type': type,
            'name': type.displayName,
            'iconName': type.iconName,
            'color': getIconColor(type),
            'darkColor': getIconDarkColor(type),
            'colorHex': type.colorHex,
            'basicIconPath': getIconPath(type),
            'filledIconPath': getIconPath(type, filled: true),
          })
      .toList();

  /// Check if an icon asset exists for a waypoint type
  ///
  /// [type] - The waypoint type
  /// [filled] - Whether to check the filled variant
  ///
  /// Returns true if the asset path is valid (basic validation)
  bool hasIcon(WaypointType type, {bool filled = false}) {
    final String path = getIconPath(type, filled: filled);
    return path.isNotEmpty && path.contains(_basePath);
  }

  /// Get icon size in pixels for a size key
  ///
  /// [sizeKey] - The size key ('small', 'medium', 'large')
  ///
  /// Returns the size in pixels, defaults to medium if key not found
  double getIconSize(String sizeKey) =>
      iconSizes[sizeKey] ?? iconSizes['medium']!;

  /// Get all available size keys
  ///
  /// Returns a list of available size keys
  List<String> getAvailableSizes() => iconSizes.keys.toList();

  /// Create a colored container with waypoint icon for map markers
  ///
  /// [type] - The waypoint type
  /// [size] - The container size (default: 'medium')
  /// [filled] - Whether to use the filled variant (default: true)
  /// [showBorder] - Whether to show a border (default: true)
  ///
  /// Returns a Container widget suitable for map markers
  Widget getMapMarkerWidget(
    WaypointType type, {
    String size = 'medium',
    bool filled = true,
    bool showBorder = true,
  }) {
    final double containerSize = getIconSize(size) + 8; // Add padding
    final Color typeColor = getIconColor(type);
    final Color darkColor = getIconDarkColor(type);

    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: filled ? typeColor.withValues(alpha: 0.9) : Colors.white,
        shape: BoxShape.circle,
        border: showBorder ? Border.all(color: darkColor, width: 2) : null,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: getIconWidget(
          type,
          size: size,
          color: filled ? Colors.white : typeColor,
        ),
      ),
    );
  }
}
