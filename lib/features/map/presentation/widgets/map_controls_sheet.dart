import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';
import 'package:obsession_tracker/core/providers/app_settings_provider.dart';
import 'package:obsession_tracker/core/providers/astronomical_provider.dart';
import 'package:obsession_tracker/core/providers/compass_provider.dart';
import 'package:obsession_tracker/core/providers/data_update_provider.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/core/providers/map_camera_provider.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/core/services/app_settings_service.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/core/utils/coordinate_formatter.dart';
import 'package:obsession_tracker/features/offline/presentation/pages/land_trail_data_page.dart';
import 'package:obsession_tracker/features/tracking/presentation/pages/tracking_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// HUD display options for the map
/// Note: Center target crosshair is now controlled by showLandRightsBanner setting, not HUD
class MapHudOptions {
  const MapHudOptions({
    this.showCoordinates = false,
    this.showElevation = false,
    this.showSpeed = false,
    this.showHeading = false,
    this.showSunMoon = false,
  });

  final bool showCoordinates;
  final bool showElevation;
  final bool showSpeed;
  final bool showHeading;
  final bool showSunMoon;

  MapHudOptions copyWith({
    bool? showCoordinates,
    bool? showElevation,
    bool? showSpeed,
    bool? showHeading,
    bool? showSunMoon,
  }) {
    return MapHudOptions(
      showCoordinates: showCoordinates ?? this.showCoordinates,
      showElevation: showElevation ?? this.showElevation,
      showSpeed: showSpeed ?? this.showSpeed,
      showHeading: showHeading ?? this.showHeading,
      showSunMoon: showSunMoon ?? this.showSunMoon,
    );
  }

  bool get hasAnyEnabled =>
      showCoordinates || showElevation || showSpeed || showHeading || showSunMoon;

  bool get allEnabled =>
      showCoordinates && showElevation && showSpeed && showHeading && showSunMoon;

  /// Returns a new instance with all options enabled or disabled
  MapHudOptions toggleAll(bool enabled) {
    return MapHudOptions(
      showCoordinates: enabled,
      showElevation: enabled,
      showSpeed: enabled,
      showHeading: enabled,
      showSunMoon: enabled,
    );
  }
}

/// Compact map controls bar with popup menus
class MapControlsSheet extends ConsumerStatefulWidget {
  const MapControlsSheet({
    required this.onCenterLocation,
    required this.onResetNorth,
    required this.onToggleRotation,
    required this.onShowStyleSelector,
    required this.onHudOptionsChanged,
    super.key,
    this.isFollowingLocation = false,
    this.isRotationEnabled = false,
    this.currentBearing = 0.0,
    this.showRotationControl = true,
    this.hudOptions = const MapHudOptions(),
    this.onExpandedChanged,
    this.onAddWaypoint,
    this.onCheckPermissions,
    this.isTrackingActive = false,
    this.showLandRightsBanner = true,
    this.onToggleLandRightsBanner,
  });

  final VoidCallback onCenterLocation;
  final VoidCallback onResetNorth;
  final VoidCallback onToggleRotation;
  final VoidCallback onShowStyleSelector;
  final ValueChanged<MapHudOptions> onHudOptionsChanged;
  final bool isFollowingLocation;
  final bool isRotationEnabled;
  final double currentBearing;
  final bool showRotationControl;
  final MapHudOptions hudOptions;
  final ValueChanged<bool>? onExpandedChanged;
  /// Callback to open unified waypoint creation (only shown when tracking)
  final VoidCallback? onAddWaypoint;
  /// Callback to check land permissions
  final VoidCallback? onCheckPermissions;
  /// Whether GPS tracking is currently active
  final bool isTrackingActive;
  /// Whether the land rights banner is visible
  final bool showLandRightsBanner;
  /// Callback to toggle land rights banner visibility
  final VoidCallback? onToggleLandRightsBanner;

  @override
  ConsumerState<MapControlsSheet> createState() => _MapControlsSheetState();
}

class _MapControlsSheetState extends ConsumerState<MapControlsSheet> {
  bool _isVisible = true;
  bool _hasInitializedFromSettings = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // Start compass
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(compassProvider.notifier).start();
    });
  }

  void _dismiss() {
    setState(() {
      _isVisible = false;
    });
    widget.onExpandedChanged?.call(false);
    // Persist the hidden state
    _saveControlBarVisibility(false);
  }

  void _show() {
    setState(() {
      _isVisible = true;
    });
    widget.onExpandedChanged?.call(false);
    // Persist the shown state
    _saveControlBarVisibility(true);
  }

  void _saveControlBarVisibility(bool visible) {
    final currentMapSettings = AppSettingsService.instance.currentSettings.map;
    AppSettingsService.instance.updateMapSettings(
      currentMapSettings.copyWith(showControlBar: visible),
    );
  }

  void _toggleHud() {
    // Simple toggle: if any HUD element is enabled, turn all off; otherwise turn all on
    final newState = !widget.hudOptions.hasAnyEnabled;
    widget.onHudOptionsChanged(widget.hudOptions.toggleAll(newState));
  }

  void _updateControlBarPosition(BuildContext context, double currentBottom, double deltaY) {
    final screenSize = MediaQuery.of(context).size;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    // Control bar height is approximately 72 (56 content + 16 padding)
    const controlBarHeight = 72.0;
    // Minimum distance from bottom (to show Mapbox logo)
    const minBottom = 20.0;
    // Maximum distance from bottom (leave room for app bar at top)
    final maxBottom = screenSize.height - MediaQuery.of(context).padding.top - kToolbarHeight - controlBarHeight - 20;

    // Dragging up increases bottom offset, dragging down decreases it
    final newBottom = (currentBottom - deltaY).clamp(minBottom + safeAreaBottom, maxBottom);

    ref.read(controlBarPositionProvider.notifier).setPosition(newBottom);
  }

  void _navigateToDataUpdates() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => const LandTrailDataPage(),
      ),
    );
  }

  void _navigateToTracking() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => const TrackingPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appSettings = ref.watch(appSettingsProvider);
    final updateState = ref.watch(dataUpdateProvider);
    final isPremium = ref.watch(isPremiumProvider);

    // Initialize from saved settings ONCE when they become available
    if (!_hasInitializedFromSettings && appSettings.hasValue) {
      _hasInitializedFromSettings = true;
      final savedVisibility = appSettings.value!.map.showControlBar;
      if (_isVisible != savedVisibility) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isVisible = savedVisibility;
            });
          }
        });
      }
    }

    final controlBarBottom = ref.watch(controlBarPositionProvider);

    // If dismissed, show expand FAB at same vertical position
    if (!_isVisible) {
      return Positioned(
        bottom: controlBarBottom,
        right: 16,
        child: FloatingActionButton.small(
          heroTag: 'map_controls_expand',
          onPressed: _show,
          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          foregroundColor: isDark ? Colors.white : Colors.black87,
          child: const Icon(Icons.tune, size: 20),
        ),
      );
    }

    // Control bar - centered, fits content, scrollable if needed on small screens
    return Positioned(
      bottom: controlBarBottom,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onVerticalDragStart: (_) {
            setState(() => _isDragging = true);
          },
          onVerticalDragUpdate: (details) {
            _updateControlBarPosition(context, controlBarBottom, details.delta.dy);
          },
          onVerticalDragEnd: (_) {
            setState(() => _isDragging = false);
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 32,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                borderRadius: BorderRadius.circular(28),
                border: _isDragging
                    ? Border.all(color: AppTheme.gold, width: 2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isDragging ? 0.4 : 0.2),
                    blurRadius: _isDragging ? 14 : 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Track button - primary action to access tracking page
                    _buildControlButton(
                      context: context,
                      icon: widget.isTrackingActive ? Icons.radio_button_checked : Icons.play_circle_outline,
                      label: widget.isTrackingActive ? 'Tracking' : 'Track',
                      onPressed: _navigateToTracking,
                      isDark: isDark,
                      isActive: widget.isTrackingActive,
                      customHighlightColor: widget.isTrackingActive ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 8),

                    // Data updates indicator (only for premium users with updates available)
                    if (isPremium && updateState.hasUpdates) ...[
                      _buildControlButton(
                        context: context,
                        icon: Icons.system_update_alt,
                        label: 'Update',
                        onPressed: _navigateToDataUpdates,
                        isDark: isDark,
                        customHighlightColor: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Add waypoint button (only when tracking)
                    if (widget.isTrackingActive && widget.onAddWaypoint != null) ...[
                      _buildControlButton(
                        context: context,
                        icon: Icons.add_location_alt,
                        label: 'Waypoint',
                        onPressed: widget.onAddWaypoint!,
                        isDark: isDark,
                        customHighlightColor: const Color(0xFFD4AF37), // Gold
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Permission check
                    if (widget.onCheckPermissions != null) ...[
                      _buildControlButton(
                        context: context,
                        icon: Icons.policy,
                        label: 'Check',
                        onPressed: widget.onCheckPermissions!,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Follow location
                    _buildControlButton(
                      context: context,
                      icon: widget.isFollowingLocation ? Icons.my_location : Icons.location_searching,
                      label: 'Follow',
                      isActive: widget.isFollowingLocation,
                      onPressed: widget.onCenterLocation,
                      isDark: isDark,
                    ),

                    const SizedBox(width: 8),

                    // Map layers/style
                    _buildControlButton(
                      context: context,
                      icon: Icons.layers,
                      label: 'Layers',
                      onPressed: widget.onShowStyleSelector,
                      isDark: isDark,
                    ),

                    const SizedBox(width: 8),

                    // Rotation lock
                    if (widget.showRotationControl) ...[
                      _buildControlButton(
                        context: context,
                        icon: widget.isRotationEnabled ? Icons.screen_rotation : Icons.screen_lock_rotation,
                        label: widget.isRotationEnabled ? 'Free' : 'Lock',
                        isActive: widget.isRotationEnabled,
                        onPressed: widget.onToggleRotation,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                    ],

                    // HUD toggle
                    _buildControlButton(
                      context: context,
                      icon: widget.hudOptions.hasAnyEnabled ? Icons.grid_view : Icons.grid_off,
                      label: 'HUD',
                      isActive: widget.hudOptions.hasAnyEnabled,
                      onPressed: _toggleHud,
                      isDark: isDark,
                    ),

                    // Land Rights banner toggle (premium feature)
                    if (widget.onToggleLandRightsBanner != null) ...[
                      const SizedBox(width: 8),
                      _buildControlButton(
                        context: context,
                        icon: widget.showLandRightsBanner ? Icons.security : Icons.shield_outlined,
                        label: 'Rights',
                        isActive: widget.showLandRightsBanner,
                        onPressed: widget.onToggleLandRightsBanner!,
                        isDark: isDark,
                      ),
                    ],

                    // Divider before Hide button
                    Container(
                      height: 40,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                    ),

                    // Hide button
                    _buildControlButton(
                      context: context,
                      icon: Icons.close,
                      label: 'Hide',
                      onPressed: _dismiss,
                      isDark: isDark,
                      small: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isDark,
    bool isActive = false,
    bool small = false,
    bool highlight = false,
    Color? customHighlightColor,
  }) {
    final size = small ? 32.0 : 40.0;
    final iconSize = small ? 16.0 : 20.0;

    // Highlight uses primary color (for camera button during tracking)
    // or custom color if provided
    final effectiveActive = isActive || highlight || customHighlightColor != null;
    final highlightColor = customHighlightColor
        ?? (highlight ? Theme.of(context).colorScheme.primary : AppTheme.gold);

    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size / 2),
              color: effectiveActive
                  ? highlightColor.withValues(alpha: isDark ? 0.3 : 0.15)
                  : (isDark ? Colors.grey[800] : Colors.grey[200]),
            ),
            child: Icon(
              icon,
              color: effectiveActive
                  ? highlightColor
                  : (isDark ? AppTheme.textOnDarkMuted : AppTheme.textOnLightMuted),
              size: iconSize,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: effectiveActive
                  ? highlightColor
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compass painter for the HUD overlay - shows north direction and device heading
class _HudCompassPainter extends CustomPainter {
  _HudCompassPainter({
    required this.heading,
    required this.isDark,
  });

  final double heading;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Draw cardinal direction markers
    final markerPaint = Paint()
      ..color = isDark ? Colors.grey[500]! : Colors.grey[500]!
      ..style = PaintingStyle.fill;

    // Draw tick marks at cardinal directions (relative to heading)
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45 - heading - 90) * math.pi / 180;
      final isCardinal = i.isEven;
      final tickLength = isCardinal ? 6.0 : 4.0;
      final tickWidth = isCardinal ? 2.0 : 1.5;

      final outerX = center.dx + (radius - 2) * math.cos(angle);
      final outerY = center.dy + (radius - 2) * math.sin(angle);
      final innerX = center.dx + (radius - 2 - tickLength) * math.cos(angle);
      final innerY = center.dy + (radius - 2 - tickLength) * math.sin(angle);

      canvas.drawLine(
        Offset(outerX, outerY),
        Offset(innerX, innerY),
        markerPaint..strokeWidth = tickWidth,
      );
    }

    // Draw north pointer (red) - always points to north relative to device heading
    final northAngle = (-heading - 90) * math.pi / 180;
    final northPaint = Paint()
      ..color = Colors.red[600]!
      ..style = PaintingStyle.fill;

    final northPath = Path();
    northPath.moveTo(
      center.dx + (radius - 8) * math.cos(northAngle),
      center.dy + (radius - 8) * math.sin(northAngle),
    );
    northPath.lineTo(
      center.dx + 5 * math.cos(northAngle + math.pi * 0.85),
      center.dy + 5 * math.sin(northAngle + math.pi * 0.85),
    );
    northPath.lineTo(
      center.dx,
      center.dy,
    );
    northPath.lineTo(
      center.dx + 5 * math.cos(northAngle - math.pi * 0.85),
      center.dy + 5 * math.sin(northAngle - math.pi * 0.85),
    );
    northPath.close();
    canvas.drawPath(northPath, northPaint);

    // Draw south pointer (white/grey) - opposite of north
    final southAngle = northAngle + math.pi;
    final southPaint = Paint()
      ..color = isDark ? Colors.grey[300]! : Colors.grey[600]!
      ..style = PaintingStyle.fill;

    final southPath = Path();
    southPath.moveTo(
      center.dx + (radius - 8) * math.cos(southAngle),
      center.dy + (radius - 8) * math.sin(southAngle),
    );
    southPath.lineTo(
      center.dx + 5 * math.cos(southAngle + math.pi * 0.85),
      center.dy + 5 * math.sin(southAngle + math.pi * 0.85),
    );
    southPath.lineTo(
      center.dx,
      center.dy,
    );
    southPath.lineTo(
      center.dx + 5 * math.cos(southAngle - math.pi * 0.85),
      center.dy + 5 * math.sin(southAngle - math.pi * 0.85),
    );
    southPath.close();
    canvas.drawPath(southPath, southPaint);

    // Center dot
    final centerPaint = Paint()
      ..color = isDark ? Colors.grey[400]! : Colors.grey[600]!
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _HudCompassPainter oldDelegate) {
    return heading != oldDelegate.heading || isDark != oldDelegate.isDark;
  }
}

/// Provider for HUD position persistence
final hudPositionProvider = NotifierProvider<HudPositionNotifier, Offset>(
  HudPositionNotifier.new,
);

/// Notifier for managing HUD position with persistence
class HudPositionNotifier extends Notifier<Offset> {
  static const String _keyX = 'hud_position_x';
  static const String _keyY = 'hud_position_y';
  static const Offset _defaultPosition = Offset(16, 120);

  @override
  Offset build() {
    _loadPosition();
    return _defaultPosition;
  }

  Future<void> _loadPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble(_keyX);
      final y = prefs.getDouble(_keyY);
      if (x != null && y != null) {
        state = Offset(x, y);
      }
    } catch (e) {
      debugPrint('Error loading HUD position: $e');
    }
  }

  Future<void> setPosition(Offset position) async {
    state = position;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyX, position.dx);
      await prefs.setDouble(_keyY, position.dy);
    } catch (e) {
      debugPrint('Error saving HUD position: $e');
    }
  }
}

/// Provider for control bar position persistence
final controlBarPositionProvider = NotifierProvider<ControlBarPositionNotifier, double>(
  ControlBarPositionNotifier.new,
);

/// Notifier for managing control bar vertical position with persistence
/// The control bar only moves vertically (bottom offset), not horizontally
class ControlBarPositionNotifier extends Notifier<double> {
  static const String _keyBottom = 'control_bar_bottom';
  static const double _defaultBottom = 80.0;

  @override
  double build() {
    _loadPosition();
    return _defaultBottom;
  }

  Future<void> _loadPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bottom = prefs.getDouble(_keyBottom);
      if (bottom != null) {
        state = bottom;
      }
    } catch (e) {
      debugPrint('Error loading control bar position: $e');
    }
  }

  Future<void> setPosition(double bottom) async {
    state = bottom;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyBottom, bottom);
    } catch (e) {
      debugPrint('Error saving control bar position: $e');
    }
  }

  /// Reset to default position
  Future<void> resetToDefault() async {
    await setPosition(_defaultBottom);
  }
}

/// Provider for land rights banner position persistence
final landRightsBannerPositionProvider = NotifierProvider<LandRightsBannerPositionNotifier, double>(
  LandRightsBannerPositionNotifier.new,
);

/// Notifier for managing land rights banner vertical position with persistence
/// The banner only moves vertically (top offset), not horizontally
class LandRightsBannerPositionNotifier extends Notifier<double> {
  static const String _keyTop = 'land_rights_banner_top';
  static const double _defaultTop = 60.0;

  @override
  double build() {
    _loadPosition();
    return _defaultTop;
  }

  Future<void> _loadPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final top = prefs.getDouble(_keyTop);
      if (top != null) {
        state = top;
      }
    } catch (e) {
      debugPrint('Error loading land rights banner position: $e');
    }
  }

  Future<void> setPosition(double top) async {
    state = top;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyTop, top);
    } catch (e) {
      debugPrint('Error saving land rights banner position: $e');
    }
  }

  /// Reset to default position
  Future<void> resetToDefault() async {
    await setPosition(_defaultTop);
  }
}

/// HUD overlay widget that displays location data on the map
/// Draggable and remembers position
class MapHudOverlay extends ConsumerStatefulWidget {
  const MapHudOverlay({
    required this.options,
    super.key,
  });

  final MapHudOptions options;

  @override
  ConsumerState<MapHudOverlay> createState() => _MapHudOverlayState();
}

class _MapHudOverlayState extends ConsumerState<MapHudOverlay> {
  final GlobalKey _hudKey = GlobalKey();
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final options = widget.options;

    if (!options.hasAnyEnabled) {
      // No HUD elements enabled - don't show HUD panel
      return const SizedBox.shrink();
    }

    final locationState = ref.watch(locationProvider);
    final compassState = ref.watch(compassProvider);
    final generalSettings = ref.watch(generalSettingsProvider);
    final hudPosition = ref.watch(hudPositionProvider);
    final cameraPosition = ref.watch(mapCameraPositionProvider);
    final gpsPosition = locationState.currentPosition;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final useImperial = generalSettings.units == MeasurementUnits.imperial;

    // For coordinates: use map center (crosshairs) position
    // For speed/elevation: use GPS position (actual device movement)
    if (cameraPosition == null && gpsPosition == null) return const SizedBox.shrink();

    // Speed conversion: m/s to km/h (×3.6) or mph (×2.237)
    // Speed requires GPS position (actual device movement)
    final speedValue = gpsPosition != null
        ? (useImperial
            ? (gpsPosition.speed * 2.237).toStringAsFixed(1)
            : (gpsPosition.speed * 3.6).toStringAsFixed(1))
        : '--';
    final speedUnit = useImperial ? 'mph' : 'km/h';

    // Elevation conversion: meters to feet (×3.281)
    // Elevation requires GPS position (actual device altitude)
    final elevationValue = gpsPosition != null
        ? (useImperial
            ? (gpsPosition.altitude * 3.281).round().toString()
            : gpsPosition.altitude.round().toString())
        : '--';
    final elevationUnit = useImperial ? 'ft' : 'm';

    return Positioned(
      left: hudPosition.dx,
      top: hudPosition.dy,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() => _isDragging = true);
        },
        onPanUpdate: (details) {
          _updatePosition(context, hudPosition, details.delta);
        },
        onPanEnd: (_) {
          setState(() => _isDragging = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          key: _hudKey,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white)
                .withValues(alpha: _isDragging ? 0.95 : 0.85),
            borderRadius: BorderRadius.circular(12),
            border: _isDragging
                ? Border.all(color: AppTheme.gold, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isDragging ? 0.4 : 0.2),
                blurRadius: _isDragging ? 12 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (options.showCoordinates && cameraPosition != null) ...[
                _buildCoordinatesWithCopy(
                  cameraPosition.latitude,
                  cameraPosition.longitude,
                  generalSettings.coordinateFormat,
                  isDark,
                ),
              ],
              if (options.showElevation)
                _buildHudRow(
                  Icons.terrain,
                  '$elevationValue $elevationUnit',
                  isDark,
                ),
              if (options.showSpeed)
                _buildHudRow(
                  Icons.speed,
                  '$speedValue $speedUnit',
                  isDark,
                ),
              if (options.showHeading)
                _buildCompassWidget(compassState.heading, isDark),
              if (options.showSunMoon)
                _buildSunMoonWidget(ref, isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a compact sun/moon display widget for the HUD
  Widget _buildSunMoonWidget(WidgetRef ref, bool isDark) {
    final astroState = ref.watch(astronomicalProvider);
    final data = astroState.data;

    if (data == null) {
      // Waiting for location or calculating
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wb_sunny_outlined,
              size: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              astroState.isLoading ? 'Calculating...' : 'Waiting for GPS...',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // Format next sun event time
    final nextEvent = data.nextSunEvent;
    final isSunrise = data.isNextEventSunrise;
    final timeUntil = data.timeUntilNextSunEvent;

    String sunEventText;
    IconData sunIcon;
    Color sunColor;

    if (nextEvent != null && timeUntil != null) {
      final hours = timeUntil.inHours;
      final minutes = timeUntil.inMinutes.remainder(60);
      final timeStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
      sunEventText = '${isSunrise ? 'Rise' : 'Set'} in $timeStr';
      sunIcon = isSunrise ? Icons.wb_sunny : Icons.nights_stay;
      sunColor = isSunrise ? Colors.orange : Colors.deepOrange;
    } else {
      // No sunrise/sunset today (polar region or past all events)
      sunEventText = data.isDaytime ? 'Daylight' : 'Night';
      sunIcon = data.isDaytime ? Icons.wb_sunny : Icons.nights_stay;
      sunColor = data.isDaytime ? Colors.orange : Colors.indigo;
    }

    // Check for golden/blue hour
    String? specialTime;
    Color? specialColor;
    if (data.isGoldenHour) {
      specialTime = 'Golden Hour';
      specialColor = const Color(0xFFD4AF37);
    } else if (data.isBlueHour) {
      specialTime = 'Blue Hour';
      specialColor = Colors.blue;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sun event row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                sunIcon,
                size: 14,
                color: sunColor,
              ),
              const SizedBox(width: 6),
              Text(
                sunEventText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Moon phase row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.moonPhase.emoji,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 6),
              Text(
                '${data.moonIllumination.round()}%',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ],
          ),
          // Special time indicator (golden/blue hour)
          if (specialTime != null) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: specialColor!.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                specialTime,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: specialColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _updatePosition(BuildContext context, Offset currentPosition, Offset delta) {
    final screenSize = MediaQuery.of(context).size;
    final appBarHeight = MediaQuery.of(context).padding.top + kToolbarHeight;

    // Estimate HUD size (approximate, will be refined after first render)
    const hudWidth = 180.0;
    const hudHeight = 120.0;

    // Calculate new position with bounds checking
    final newX = (currentPosition.dx + delta.dx).clamp(
      8.0,
      screenSize.width - hudWidth - 8,
    );
    final newY = (currentPosition.dy + delta.dy).clamp(
      appBarHeight + 8,
      screenSize.height - hudHeight - 180, // Leave room for bottom controls
    );

    ref.read(hudPositionProvider.notifier).setPosition(Offset(newX, newY));
  }

  Widget _buildHudRow(IconData? icon, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            const SizedBox(width: 6),
          ] else
            const SizedBox(width: 20),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /// Build coordinates display with copy to clipboard button
  Widget _buildCoordinatesWithCopy(
    double latitude,
    double longitude,
    CoordinateFormat format,
    bool isDark,
  ) {
    final latStr = CoordinateFormatter.formatLatitude(latitude, format);
    final lngStr = CoordinateFormatter.formatLongitude(longitude, format);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on,
              size: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              latStr,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _copyCoordinates(latitude, longitude),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.copy,
                  size: 12,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 20), // Align with lat row
              Text(
                lngStr,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Copy coordinates to clipboard in a simple decimal format for debugging
  Future<void> _copyCoordinates(double latitude, double longitude) async {
    // Format: "lat, lng" with 6 decimal places for precision
    final coordString = '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
    await Clipboard.setData(ClipboardData(text: coordString));

    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied: $coordString'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Build a visual compass widget for the HUD
  Widget _buildCompassWidget(double heading, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Visual compass
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              border: Border.all(
                color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                width: 2,
              ),
            ),
            child: CustomPaint(
              painter: _HudCompassPainter(
                heading: heading,
                isDark: isDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Heading text
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${heading.round()}°',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                _getDirectionName(heading),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getDirectionName(double heading) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((heading + 22.5) % 360 / 45).floor();
    return directions[index];
  }
}

/// Center target crosshair widget that shows where permission checks occur.
/// IgnorePointer wraps the entire widget to ensure all pointer events
/// (clicks, scrolls, drags) pass through to the map underneath.
class MapCenterTarget extends StatelessWidget {
  const MapCenterTarget({super.key});

  static const double _size = 60.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // IgnorePointer at the top level ensures all pointer events pass through.
    // This is critical for desktop where the crosshair is in the center of the map.
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: _size,
          height: _size,
          child: CustomPaint(
            painter: _CenterTargetPainter(isDark: isDark),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the center target crosshair
class _CenterTargetPainter extends CustomPainter {
  _CenterTargetPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;

    // Outer circle paint
    final outerPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Crosshair line paint
    final linePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw outer circle
    canvas.drawCircle(center, outerRadius - 2, outerPaint);

    // Draw crosshair lines (small gap in center for visibility)
    const gap = 4.0;
    // Top line
    canvas.drawLine(
      Offset(center.dx, center.dy - outerRadius + 4),
      Offset(center.dx, center.dy - gap),
      linePaint,
    );
    // Bottom line
    canvas.drawLine(
      Offset(center.dx, center.dy + gap),
      Offset(center.dx, center.dy + outerRadius - 4),
      linePaint,
    );
    // Left line
    canvas.drawLine(
      Offset(center.dx - outerRadius + 4, center.dy),
      Offset(center.dx - gap, center.dy),
      linePaint,
    );
    // Right line
    canvas.drawLine(
      Offset(center.dx + gap, center.dy),
      Offset(center.dx + outerRadius - 4, center.dy),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CenterTargetPainter oldDelegate) {
    return isDark != oldDelegate.isDark;
  }
}
