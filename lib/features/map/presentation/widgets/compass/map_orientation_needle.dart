import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Map orientation needle that shows which way is "up" on the map
/// This is the blue needle in the dual-needle system
class MapOrientationNeedle extends StatelessWidget {
  const MapOrientationNeedle({
    required this.mapRotation,
    this.size = 80.0,
    this.needleColor = Colors.blue,
    super.key,
  });

  /// Current map rotation in degrees (0-360)
  final double mapRotation;

  /// Size of the compass needle
  final double size;

  /// Color of the map orientation needle (default: blue)
  final Color needleColor;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Transform.rotate(
          // Map needle shows the "up" direction, so we rotate by negative mapRotation
          // to show which way is up on the map
          angle: -mapRotation * (math.pi / 180),
          child: CustomPaint(
            painter: _MapOrientationNeedlePainter(
              needleColor: needleColor,
            ),
            size: Size(size, size),
          ),
        ),
      );
}

/// Custom painter for the map orientation needle
/// Creates an arrow-style design to differentiate from magnetic needle
class _MapOrientationNeedlePainter extends CustomPainter {
  const _MapOrientationNeedlePainter({
    required this.needleColor,
  });

  final Color needleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width / 2;

    // Paint for map orientation needle (blue)
    final Paint needlePaint = Paint()
      ..color = needleColor
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    // Paint for needle outline
    final Paint outlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Draw map orientation arrow (distinctive arrow design)
    final Path arrowPath = Path();

    // Arrow head (pointing up to show map "up" direction)
    arrowPath.moveTo(centerX, centerY - radius * 0.7); // Top point
    arrowPath.lineTo(
        centerX - radius * 0.18, centerY - radius * 0.45); // Left arrow wing
    arrowPath.lineTo(centerX - radius * 0.08,
        centerY - radius * 0.45); // Left shaft connection
    arrowPath.lineTo(
        centerX - radius * 0.08, centerY + radius * 0.5); // Left shaft
    arrowPath.lineTo(
        centerX + radius * 0.08, centerY + radius * 0.5); // Right shaft
    arrowPath.lineTo(centerX + radius * 0.08,
        centerY - radius * 0.45); // Right shaft connection
    arrowPath.lineTo(
        centerX + radius * 0.18, centerY - radius * 0.45); // Right arrow wing
    arrowPath.close();

    canvas.drawPath(arrowPath, needlePaint);
    canvas.drawPath(arrowPath, outlinePaint);

    // Draw directional indicator at the base (small triangle)
    final Path basePath = Path();
    basePath.moveTo(centerX, centerY + radius * 0.65); // Bottom point
    basePath.lineTo(
        centerX - radius * 0.06, centerY + radius * 0.5); // Left base
    basePath.lineTo(
        centerX + radius * 0.06, centerY + radius * 0.5); // Right base
    basePath.close();

    final Paint basePaint = Paint()
      ..color = needleColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawPath(basePath, basePaint);
    canvas.drawPath(basePath, outlinePaint);

    // Draw center pivot point (smaller than magnetic needle)
    final Paint centerPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(centerX, centerY),
      radius * 0.04,
      centerPaint,
    );

    // Draw center highlight
    final Paint highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(centerX, centerY),
      radius * 0.02,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      oldDelegate is! _MapOrientationNeedlePainter ||
      oldDelegate.needleColor != needleColor;
}
