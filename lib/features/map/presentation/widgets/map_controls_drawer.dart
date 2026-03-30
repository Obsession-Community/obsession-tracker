import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/compass_provider.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';

/// A collapsible drawer for map controls that slides in from the right edge.
///
/// This widget provides a clean, minimalist approach to map controls:
/// - When collapsed: Shows only a small expand button
/// - When expanded: Shows all map controls in a vertical stack
///
/// Controls included:
/// - Dual compass (device heading + map orientation)
/// - Center on location
/// - Map style selector
/// - Rotation lock toggle
class MapControlsDrawer extends ConsumerStatefulWidget {
  const MapControlsDrawer({
    required this.onCenterLocation,
    required this.onResetNorth,
    required this.onToggleRotation,
    required this.onShowStyleSelector,
    super.key,
    this.isFollowingLocation = false,
    this.isRotationEnabled = false,
    this.currentBearing = 0.0,
    this.showRotationControl = true,
  });

  final VoidCallback onCenterLocation;
  final VoidCallback onResetNorth;
  final VoidCallback onToggleRotation;
  final VoidCallback onShowStyleSelector;
  final bool isFollowingLocation;
  final bool isRotationEnabled;
  final double currentBearing; // Map rotation/bearing
  final bool showRotationControl;

  @override
  ConsumerState<MapControlsDrawer> createState() => _MapControlsDrawerState();
}

class _MapControlsDrawerState extends ConsumerState<MapControlsDrawer>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Start compass when drawer is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(compassProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _showPrecisionCompass() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PrecisionCompassSheet(
        mapBearing: widget.currentBearing,
        onResetNorth: widget.onResetNorth,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch compass state for device heading
    final compassState = ref.watch(compassProvider);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Expanded controls panel
            if (_isExpanded || _animationController.value > 0)
              FadeTransition(
                opacity: _fadeAnimation,
                child: Transform.translate(
                  offset: Offset(60 * _slideAnimation.value, 0),
                  child: _buildControlsPanel(context, compassState),
                ),
              ),

            // Toggle button (always visible)
            const SizedBox(width: 8),
            _buildToggleButton(context),
          ],
        );
      },
    );
  }

  Widget _buildToggleButton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(28),
      color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      child: InkWell(
        onTap: _toggleExpanded,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
          ),
          child: AnimatedRotation(
            turns: _isExpanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Icon(
              Icons.chevron_left,
              color: isDark ? AppTheme.textOnDarkMuted : AppTheme.textOnLightMuted,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlsPanel(BuildContext context, CompassState compassState) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dual compass - tap to open precision view
            _buildDualCompass(context, isDark, compassState),
            const SizedBox(height: 4),
            _buildDivider(isDark),
            const SizedBox(height: 4),

            // Follow location toggle
            _buildControlButton(
              context: context,
              icon: widget.isFollowingLocation ? Icons.my_location : Icons.location_searching,
              tooltip: widget.isFollowingLocation
                  ? 'Following Location'
                  : 'Follow Location',
              onPressed: widget.onCenterLocation,
              isActive: widget.isFollowingLocation,
              isDark: isDark,
            ),
            const SizedBox(height: 4),

            // Map style selector
            _buildControlButton(
              context: context,
              icon: Icons.layers,
              tooltip: 'Map Style',
              onPressed: widget.onShowStyleSelector,
              isDark: isDark,
            ),

            // Rotation lock (conditional)
            if (widget.showRotationControl) ...[
              const SizedBox(height: 4),
              _buildControlButton(
                context: context,
                icon: widget.isRotationEnabled
                    ? Icons.screen_lock_rotation
                    : Icons.screen_rotation,
                tooltip: widget.isRotationEnabled
                    ? 'Lock Rotation'
                    : 'Enable Rotation',
                onPressed: widget.onToggleRotation,
                isActive: widget.isRotationEnabled,
                isDark: isDark,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDualCompass(
    BuildContext context,
    bool isDark,
    CompassState compassState,
  ) {
    final deviceHeading = compassState.heading;
    final mapBearing = widget.currentBearing;
    final needsReset = mapBearing.abs() > 1.0;

    return GestureDetector(
      onTap: _showPrecisionCompass,
      onLongPress: needsReset ? widget.onResetNorth : null,
      child: Tooltip(
        message: 'Tap for precision compass',
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: needsReset
                ? AppTheme.gold.withValues(alpha: isDark ? 0.2 : 0.1)
                : Colors.transparent,
          ),
          child: _DualCompassWidget(
            deviceHeading: deviceHeading,
            mapBearing: mapBearing,
            size: 56,
            isDark: isDark,
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required bool isDark,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isActive
                ? AppTheme.gold.withValues(alpha: isDark ? 0.3 : 0.15)
                : Colors.transparent,
          ),
          child: Icon(
            icon,
            color: isActive
                ? AppTheme.gold
                : (isDark ? AppTheme.textOnDarkMuted : AppTheme.textOnLightMuted),
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 32,
      height: 1,
      color: isDark ? Colors.grey[700] : Colors.grey[300],
    );
  }
}

/// Dual compass widget showing both device heading and map orientation
class _DualCompassWidget extends StatelessWidget {
  const _DualCompassWidget({
    required this.deviceHeading,
    required this.mapBearing,
    required this.size,
    required this.isDark,
  });

  final double deviceHeading;
  final double mapBearing;
  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DualCompassPainter(
          deviceHeading: deviceHeading,
          mapBearing: mapBearing,
          isDark: isDark,
        ),
      ),
    );
  }
}

/// Custom painter for the dual compass
class _DualCompassPainter extends CustomPainter {
  _DualCompassPainter({
    required this.deviceHeading,
    required this.mapBearing,
    required this.isDark,
  });

  final double deviceHeading;
  final double mapBearing;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Colors
    final ringColor = isDark ? Colors.grey[600]! : Colors.grey[300]!;
    final textColor = isDark ? Colors.white70 : Colors.grey[700]!;
    final northColor = Colors.red[600]!;
    final deviceNeedleColor = Colors.blue[600]!;

    // Draw outer ring
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, ringPaint);

    // Draw NESW markers (rotated by map bearing so they show map orientation)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final directions = ['N', 'E', 'S', 'W'];
    final directionColors = [northColor, textColor, textColor, textColor];

    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 - mapBearing - 90) * math.pi / 180;
      final markerRadius = radius - 8;
      final x = center.dx + markerRadius * math.cos(angle);
      final y = center.dy + markerRadius * math.sin(angle);

      textPainter.text = TextSpan(
        text: directions[i],
        style: TextStyle(
          color: directionColors[i],
          fontSize: 10,
          fontWeight:
              directions[i] == 'N' ? FontWeight.bold : FontWeight.normal,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }

    // Draw tick marks (rotated by map bearing)
    final tickPaint = Paint()
      ..color = ringColor
      ..strokeWidth = 1;

    for (int i = 0; i < 12; i++) {
      if (i % 3 == 0) continue; // Skip cardinal directions
      final angle = (i * 30 - mapBearing - 90) * math.pi / 180;
      final innerR = radius - 4;
      final outerR = radius;
      canvas.drawLine(
        Offset(center.dx + innerR * math.cos(angle),
            center.dy + innerR * math.sin(angle)),
        Offset(center.dx + outerR * math.cos(angle),
            center.dy + outerR * math.sin(angle)),
        tickPaint,
      );
    }

    // Draw device heading needle (blue arrow pointing where device is facing)
    final needleAngle = (deviceHeading - 90) * math.pi / 180;
    final needleLength = radius - 14;

    // Device needle (blue)
    final deviceNeedlePaint = Paint()
      ..color = deviceNeedleColor
      ..style = PaintingStyle.fill;

    final needlePath = Path();
    // Arrow tip
    needlePath.moveTo(
      center.dx + needleLength * math.cos(needleAngle),
      center.dy + needleLength * math.sin(needleAngle),
    );
    // Arrow base left
    needlePath.lineTo(
      center.dx + 6 * math.cos(needleAngle + math.pi * 0.85),
      center.dy + 6 * math.sin(needleAngle + math.pi * 0.85),
    );
    // Arrow center (towards center)
    needlePath.lineTo(
      center.dx + 4 * math.cos(needleAngle + math.pi),
      center.dy + 4 * math.sin(needleAngle + math.pi),
    );
    // Arrow base right
    needlePath.lineTo(
      center.dx + 6 * math.cos(needleAngle - math.pi * 0.85),
      center.dy + 6 * math.sin(needleAngle - math.pi * 0.85),
    );
    needlePath.close();
    canvas.drawPath(needlePath, deviceNeedlePaint);

    // Draw center dot
    final centerPaint = Paint()
      ..color = isDark ? Colors.grey[400]! : Colors.grey[600]!
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _DualCompassPainter oldDelegate) {
    return deviceHeading != oldDelegate.deviceHeading ||
        mapBearing != oldDelegate.mapBearing ||
        isDark != oldDelegate.isDark;
  }
}

/// Full-screen precision compass bottom sheet
class _PrecisionCompassSheet extends ConsumerWidget {
  const _PrecisionCompassSheet({
    required this.mapBearing,
    required this.onResetNorth,
  });

  final double mapBearing;
  final VoidCallback onResetNorth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compassState = ref.watch(compassProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Precision Compass',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Large compass
              Expanded(
                child: Center(
                  child: _LargePrecisionCompass(
                    deviceHeading: compassState.heading,
                    mapBearing: mapBearing,
                    isDark: isDark,
                    accuracyDescription: compassState.accuracyDescription,
                    isCalibrated: compassState.isCalibrated,
                  ),
                ),
              ),

              // Heading display
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Large heading number
                    Text(
                      '${compassState.heading.round()}°',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w300,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getDirectionName(compassState.heading),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem(
                          color: Colors.blue[600]!,
                          label: 'Device Heading',
                        ),
                        const SizedBox(width: 24),
                        _buildLegendItem(
                          color: Colors.red[600]!,
                          label: 'North',
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Calibration status
                    if (!compassState.isCalibrated)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Move device in figure-8 to calibrate',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Reset north button (if map is rotated)
                    if (mapBearing.abs() > 1.0) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          onResetNorth();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.north),
                        label: const Text('Reset Map to North'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _getDirectionName(double heading) {
    const directions = [
      'N', 'NNE', 'NE', 'ENE',
      'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW',
      'W', 'WNW', 'NW', 'NNW',
    ];
    final index = ((heading + 11.25) % 360 / 22.5).floor();
    return directions[index];
  }
}

/// Large precision compass for the bottom sheet
class _LargePrecisionCompass extends StatelessWidget {
  const _LargePrecisionCompass({
    required this.deviceHeading,
    required this.mapBearing,
    required this.isDark,
    required this.accuracyDescription,
    required this.isCalibrated,
  });

  final double deviceHeading;
  final double mapBearing;
  final bool isDark;
  final String accuracyDescription;
  final bool isCalibrated;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: CustomPaint(
        painter: _PrecisionCompassPainter(
          deviceHeading: deviceHeading,
          mapBearing: mapBearing,
          isDark: isDark,
        ),
      ),
    );
  }
}

/// Custom painter for the large precision compass
class _PrecisionCompassPainter extends CustomPainter {
  _PrecisionCompassPainter({
    required this.deviceHeading,
    required this.mapBearing,
    required this.isDark,
  });

  final double deviceHeading;
  final double mapBearing;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Colors
    final ringColor = isDark ? Colors.grey[600]! : Colors.grey[300]!;
    final textColor = isDark ? Colors.white : Colors.grey[800]!;
    final northColor = Colors.red[600]!;
    final deviceNeedleColor = Colors.blue[600]!;

    // Draw outer ring
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, ringPaint);

    // Draw degree markings and NESW (rotated by map bearing)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int deg = 0; deg < 360; deg += 10) {
      final angle = (deg - mapBearing - 90) * math.pi / 180;
      final isCardinal = deg % 90 == 0;
      final is30Deg = deg % 30 == 0;

      // Tick marks
      final tickLength = isCardinal ? 12 : (is30Deg ? 8 : 4);
      final tickPaint = Paint()
        ..color = isCardinal ? (deg == 0 ? northColor : textColor) : ringColor
        ..strokeWidth = isCardinal ? 2 : 1;

      final innerR = radius - tickLength;
      canvas.drawLine(
        Offset(center.dx + innerR * math.cos(angle),
            center.dy + innerR * math.sin(angle)),
        Offset(center.dx + radius * math.cos(angle),
            center.dy + radius * math.sin(angle)),
        tickPaint,
      );

      // Degree labels (every 30 degrees)
      if (is30Deg && !isCardinal) {
        final labelRadius = radius - 22;
        final x = center.dx + labelRadius * math.cos(angle);
        final y = center.dy + labelRadius * math.sin(angle);

        textPainter.text = TextSpan(
          text: '$deg',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, y - textPainter.height / 2),
        );
      }
    }

    // Draw NESW labels
    final directions = ['N', 'E', 'S', 'W'];
    final directionDegs = [0, 90, 180, 270];
    final directionColors = [northColor, textColor, textColor, textColor];

    for (int i = 0; i < 4; i++) {
      final angle = (directionDegs[i] - mapBearing - 90) * math.pi / 180;
      final labelRadius = radius - 28;
      final x = center.dx + labelRadius * math.cos(angle);
      final y = center.dy + labelRadius * math.sin(angle);

      textPainter.text = TextSpan(
        text: directions[i],
        style: TextStyle(
          color: directionColors[i],
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }

    // Draw device heading needle (blue arrow)
    final needleAngle = (deviceHeading - 90) * math.pi / 180;
    final needleLength = radius - 45;

    // Needle shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final shadowPath = _createNeedlePath(
      center + const Offset(2, 2),
      needleAngle,
      needleLength,
      12,
    );
    canvas.drawPath(shadowPath, shadowPaint);

    // Device needle (blue)
    final deviceNeedlePaint = Paint()
      ..color = deviceNeedleColor
      ..style = PaintingStyle.fill;

    final needlePath = _createNeedlePath(center, needleAngle, needleLength, 12);
    canvas.drawPath(needlePath, deviceNeedlePaint);

    // Needle outline
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(needlePath, outlinePaint);

    // Draw center circle
    final centerBgPaint = Paint()
      ..color = isDark ? Colors.grey[800]! : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 12, centerBgPaint);

    final centerBorderPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 12, centerBorderPaint);

    // Center dot
    final centerDotPaint = Paint()
      ..color = deviceNeedleColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, centerDotPaint);
  }

  Path _createNeedlePath(
    Offset center,
    double angle,
    double length,
    double baseWidth,
  ) {
    final path = Path();
    // Arrow tip
    path.moveTo(
      center.dx + length * math.cos(angle),
      center.dy + length * math.sin(angle),
    );
    // Arrow base left
    path.lineTo(
      center.dx + baseWidth * math.cos(angle + math.pi * 0.8),
      center.dy + baseWidth * math.sin(angle + math.pi * 0.8),
    );
    // Arrow tail
    path.lineTo(
      center.dx + (length * 0.3) * math.cos(angle + math.pi),
      center.dy + (length * 0.3) * math.sin(angle + math.pi),
    );
    // Arrow base right
    path.lineTo(
      center.dx + baseWidth * math.cos(angle - math.pi * 0.8),
      center.dy + baseWidth * math.sin(angle - math.pi * 0.8),
    );
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _PrecisionCompassPainter oldDelegate) {
    return deviceHeading != oldDelegate.deviceHeading ||
        mapBearing != oldDelegate.mapBearing ||
        isDark != oldDelegate.isDark;
  }
}
