import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Compass rose widget showing cardinal and intercardinal directions
class CompassRose extends StatelessWidget {
  const CompassRose({
    this.size = 120.0,
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.black,
    this.textColor = Colors.black,
    this.majorTickColor = Colors.black,
    this.minorTickColor = Colors.grey,
    super.key,
  });

  /// Size of the compass rose
  final double size;

  /// Background color of the compass rose
  final Color backgroundColor;

  /// Border color of the compass rose
  final Color borderColor;

  /// Text color for direction labels
  final Color textColor;

  /// Color for major tick marks (N, E, S, W)
  final Color majorTickColor;

  /// Color for minor tick marks
  final Color minorTickColor;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: CustomPaint(
          painter: _CompassRosePainter(
            textColor: textColor,
            majorTickColor: majorTickColor,
            minorTickColor: minorTickColor,
          ),
          size: Size(size, size),
        ),
      );
}

/// Custom painter for the compass rose
class _CompassRosePainter extends CustomPainter {
  const _CompassRosePainter({
    required this.textColor,
    required this.majorTickColor,
    required this.minorTickColor,
  });

  final Color textColor;
  final Color majorTickColor;
  final Color minorTickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width / 2;

    // Draw tick marks and labels
    _drawTickMarks(canvas, centerX, centerY, radius);
    _drawDirectionLabels(canvas, centerX, centerY, radius);
  }

  void _drawTickMarks(
      Canvas canvas, double centerX, double centerY, double radius) {
    // Paint for major ticks (every 90 degrees)
    final Paint majorTickPaint = Paint()
      ..color = majorTickColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Paint for minor ticks (every 30 degrees)
    final Paint minorTickPaint = Paint()
      ..color = minorTickColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw tick marks every 30 degrees
    for (int i = 0; i < 12; i++) {
      final double angle = i * 30 * (math.pi / 180);
      final bool isMajorTick = i % 3 == 0; // Every 90 degrees

      final Paint tickPaint = isMajorTick ? majorTickPaint : minorTickPaint;
      final double tickLength = isMajorTick ? radius * 0.15 : radius * 0.08;

      final double startX =
          centerX + (radius - tickLength) * math.cos(angle - math.pi / 2);
      final double startY =
          centerY + (radius - tickLength) * math.sin(angle - math.pi / 2);
      final double endX =
          centerX + (radius - 4) * math.cos(angle - math.pi / 2);
      final double endY =
          centerY + (radius - 4) * math.sin(angle - math.pi / 2);

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        tickPaint,
      );
    }
  }

  void _drawDirectionLabels(
      Canvas canvas, double centerX, double centerY, double radius) {
    final TextStyle textStyle = TextStyle(
      color: textColor,
      fontSize: radius * 0.15,
      fontWeight: FontWeight.bold,
    );

    // Cardinal directions
    final List<MapEntry<String, double>> directions = [
      const MapEntry('N', 0),
      const MapEntry('E', 90),
      const MapEntry('S', 180),
      const MapEntry('W', 270),
    ];

    for (final MapEntry<String, double> direction in directions) {
      final double angle = direction.value * (math.pi / 180) - math.pi / 2;
      final double labelRadius = radius * 0.7;

      final double labelX = centerX + labelRadius * math.cos(angle);
      final double labelY = centerY + labelRadius * math.sin(angle);

      final TextPainter textPainter = TextPainter(
        text: TextSpan(text: direction.key, style: textStyle),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Center the text
      final Offset offset = Offset(
        labelX - textPainter.width / 2,
        labelY - textPainter.height / 2,
      );

      textPainter.paint(canvas, offset);
    }

    // Draw intercardinal directions (smaller text)
    final TextStyle smallTextStyle = TextStyle(
      color: textColor.withValues(alpha: 0.7),
      fontSize: radius * 0.1,
      fontWeight: FontWeight.w500,
    );

    final List<MapEntry<String, double>> interCardinals = [
      const MapEntry('NE', 45),
      const MapEntry('SE', 135),
      const MapEntry('SW', 225),
      const MapEntry('NW', 315),
    ];

    for (final MapEntry<String, double> direction in interCardinals) {
      final double angle = direction.value * (math.pi / 180) - math.pi / 2;
      final double labelRadius = radius * 0.55;

      final double labelX = centerX + labelRadius * math.cos(angle);
      final double labelY = centerY + labelRadius * math.sin(angle);

      final TextPainter textPainter = TextPainter(
        text: TextSpan(text: direction.key, style: smallTextStyle),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      final Offset offset = Offset(
        labelX - textPainter.width / 2,
        labelY - textPainter.height / 2,
      );

      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      oldDelegate is! _CompassRosePainter ||
      oldDelegate.textColor != textColor ||
      oldDelegate.majorTickColor != majorTickColor ||
      oldDelegate.minorTickColor != minorTickColor;
}
