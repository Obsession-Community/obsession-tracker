import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Compass needle widget that points to magnetic north
class CompassNeedle extends StatelessWidget {
  const CompassNeedle({
    required this.heading,
    this.size = 80.0,
    this.needleColor = Colors.red,
    this.southColor = Colors.white,
    super.key,
  });

  /// Current compass heading in degrees
  final double heading;

  /// Size of the compass needle
  final double size;

  /// Color of the north-pointing needle
  final Color needleColor;

  /// Color of the south-pointing needle
  final Color southColor;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Transform.rotate(
          angle: -heading * (math.pi / 180), // Convert to radians and invert
          child: CustomPaint(
            painter: _CompassNeedlePainter(
              needleColor: needleColor,
              southColor: southColor,
            ),
            size: Size(size, size),
          ),
        ),
      );
}

/// Custom painter for the compass needle
class _CompassNeedlePainter extends CustomPainter {
  const _CompassNeedlePainter({
    required this.needleColor,
    required this.southColor,
  });

  final Color needleColor;
  final Color southColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width / 2;

    // Paint for north needle (red)
    final Paint northPaint = Paint()
      ..color = needleColor
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    // Paint for south needle (white/light)
    final Paint southPaint = Paint()
      ..color = southColor
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    // Paint for needle outline
    final Paint outlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw north needle (pointing up)
    final Path northPath = Path();
    northPath.moveTo(centerX, centerY - radius * 0.8); // Top point
    northPath.lineTo(centerX - radius * 0.15, centerY); // Left center
    northPath.lineTo(centerX, centerY - radius * 0.1); // Center notch
    northPath.lineTo(centerX + radius * 0.15, centerY); // Right center
    northPath.close();

    canvas.drawPath(northPath, northPaint);
    canvas.drawPath(northPath, outlinePaint);

    // Draw south needle (pointing down)
    final Path southPath = Path();
    southPath.moveTo(centerX, centerY + radius * 0.8); // Bottom point
    southPath.lineTo(centerX - radius * 0.15, centerY); // Left center
    southPath.lineTo(centerX, centerY + radius * 0.1); // Center notch
    southPath.lineTo(centerX + radius * 0.15, centerY); // Right center
    southPath.close();

    canvas.drawPath(southPath, southPaint);
    canvas.drawPath(southPath, outlinePaint);

    // Draw center circle
    final Paint centerPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(centerX, centerY),
      radius * 0.08,
      centerPaint,
    );

    // Draw center highlight
    final Paint highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(centerX, centerY),
      radius * 0.05,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      oldDelegate is! _CompassNeedlePainter ||
      oldDelegate.needleColor != needleColor ||
      oldDelegate.southColor != southColor;
}
