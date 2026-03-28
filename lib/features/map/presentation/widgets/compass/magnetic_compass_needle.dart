import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Magnetic compass needle that points to magnetic north (device heading)
/// This is the red needle in the dual-needle system
class MagneticCompassNeedle extends StatelessWidget {
  const MagneticCompassNeedle({
    required this.heading,
    this.size = 80.0,
    this.needleColor = Colors.red,
    super.key,
  });

  /// Current compass heading in degrees (0-360)
  final double heading;

  /// Size of the compass needle
  final double size;

  /// Color of the magnetic north needle (default: red)
  final Color needleColor;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Transform.rotate(
          angle: -heading * (math.pi / 180), // Convert to radians and invert
          child: CustomPaint(
            painter: _MagneticNeedlePainter(
              needleColor: needleColor,
            ),
            size: Size(size, size),
          ),
        ),
      );
}

/// Custom painter for the magnetic compass needle
/// Creates a traditional pointed needle design for magnetic north
class _MagneticNeedlePainter extends CustomPainter {
  const _MagneticNeedlePainter({
    required this.needleColor,
  });

  final Color needleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width / 2;

    // Paint for magnetic north needle (red)
    final Paint northPaint = Paint()
      ..color = needleColor
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    // Paint for south end (lighter version of needle color)
    final Paint southPaint = Paint()
      ..color = needleColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    // Paint for needle outline
    final Paint outlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw magnetic north needle (traditional pointed design)
    final Path northPath = Path();
    northPath.moveTo(centerX, centerY - radius * 0.75); // Sharp top point
    northPath.lineTo(
        centerX - radius * 0.12, centerY - radius * 0.05); // Left side
    northPath.lineTo(centerX, centerY - radius * 0.08); // Center notch
    northPath.lineTo(
        centerX + radius * 0.12, centerY - radius * 0.05); // Right side
    northPath.close();

    canvas.drawPath(northPath, northPaint);
    canvas.drawPath(northPath, outlinePaint);

    // Draw south end (smaller, less prominent)
    final Path southPath = Path();
    southPath.moveTo(centerX, centerY + radius * 0.6); // Bottom point
    southPath.lineTo(
        centerX - radius * 0.08, centerY + radius * 0.05); // Left side
    southPath.lineTo(centerX, centerY + radius * 0.08); // Center notch
    southPath.lineTo(
        centerX + radius * 0.08, centerY + radius * 0.05); // Right side
    southPath.close();

    canvas.drawPath(southPath, southPaint);
    canvas.drawPath(southPath, outlinePaint);

    // Draw center pivot point
    final Paint centerPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(centerX, centerY),
      radius * 0.06,
      centerPaint,
    );

    // Draw center highlight
    final Paint highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(centerX, centerY),
      radius * 0.03,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      oldDelegate is! _MagneticNeedlePainter ||
      oldDelegate.needleColor != needleColor;
}
