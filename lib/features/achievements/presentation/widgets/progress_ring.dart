import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A circular progress ring widget for displaying achievement progress
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 60,
    this.strokeWidth = 6,
    this.backgroundColor,
    this.progressColor,
    this.child,
  });

  /// Progress value from 0.0 to 1.0
  final double progress;

  /// Size of the ring (diameter)
  final double size;

  /// Width of the ring stroke
  final double strokeWidth;

  /// Background color of the ring track
  final Color? backgroundColor;

  /// Color of the progress arc
  final Color? progressColor;

  /// Widget to display in the center of the ring
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = backgroundColor ?? colorScheme.surfaceContainerHighest;
    final fgColor = progressColor ?? colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ProgressRingPainter(
              progress: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              backgroundColor: bgColor,
              progressColor: fgColor,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
  });

  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Start from top
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor;
  }
}

/// A larger progress ring with percentage text in the center
class ProgressRingWithLabel extends StatelessWidget {
  const ProgressRingWithLabel({
    super.key,
    required this.progress,
    this.size = 80,
    this.strokeWidth = 8,
    this.progressColor,
    this.showPercentage = true,
    this.label,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color? progressColor;
  final bool showPercentage;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return ProgressRing(
      progress: progress,
      size: size,
      strokeWidth: strokeWidth,
      progressColor: progressColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPercentage)
            Text(
              '${(progress * 100).toInt()}%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          if (label != null)
            Text(
              label!,
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}
