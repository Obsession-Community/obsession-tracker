import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/trail.dart';

/// Trail path preview with distance markers
/// Shows the trail shape and marks distances along the path
/// Supports multi-segment trails via TrailGroup
class TrailPathPreview extends StatelessWidget {
  const TrailPathPreview({
    required this.trailGroup,
    this.height = 200,
    super.key,
  });

  final TrailGroup trailGroup;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Check if trail group has valid geometry
    final allCoords = trailGroup.allCoordinates;
    if (allCoords.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'No trail path data available',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: TrailPathPainter(
            trailGroup: trailGroup,
            trailColor: const Color(0xFF2196F3),
            startColor: Colors.green,
            endColor: Colors.red,
            markerColor: theme.colorScheme.primary,
            textColor: theme.colorScheme.onSurface,
            labelBackgroundColor: theme.colorScheme.surface,
          ),
          child: Container(),
        ),
      ),
    );
  }
}

/// Custom painter for trail path with distance markers
/// Supports multi-segment trails via TrailGroup
class TrailPathPainter extends CustomPainter {
  TrailPathPainter({
    required this.trailGroup,
    required this.trailColor,
    required this.startColor,
    required this.endColor,
    required this.markerColor,
    required this.textColor,
    required this.labelBackgroundColor,
  });

  final TrailGroup trailGroup;
  final Color trailColor;
  final Color startColor;
  final Color endColor;
  final Color markerColor;
  final Color textColor;
  final Color labelBackgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Get all coordinates from all segments
    final allCoords = trailGroup.allCoordinates;
    if (allCoords.isEmpty) return;

    // Convert to points list
    final allPoints = allCoords.map((coord) {
      return [
        (coord[0] as num).toDouble(),
        (coord[1] as num).toDouble(),
      ];
    }).toList();

    if (allPoints.isEmpty) return;

    // Calculate bounding box across all segments
    double minLon = allPoints[0][0];
    double maxLon = allPoints[0][0];
    double minLat = allPoints[0][1];
    double maxLat = allPoints[0][1];

    for (final point in allPoints) {
      minLon = math.min(minLon, point[0]);
      maxLon = math.max(maxLon, point[0]);
      minLat = math.min(minLat, point[1]);
      maxLat = math.max(maxLat, point[1]);
    }

    // Add padding
    const padding = 30.0;
    final availableWidth = size.width - (padding * 2);
    final availableHeight = size.height - (padding * 2);

    // Calculate scale to fit
    final lonRange = maxLon - minLon;
    final latRange = maxLat - minLat;

    // Handle case where trail is a single point or very small
    final scale = (lonRange < 0.0001 || latRange < 0.0001)
        ? 1.0
        : math.min(
            availableWidth / lonRange,
            availableHeight / latRange,
          );

    // Helper to convert geo to canvas coordinates
    Offset toCanvas(List<double> point) {
      final x = ((point[0] - minLon) * scale) + padding;
      final y = size.height - (((point[1] - minLat) * scale) + padding);
      return Offset(x, y);
    }

    // Draw each segment separately (handles gaps between segments)
    final pathPaint = Paint()
      ..color = trailColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Offset? firstPoint;
    Offset? lastPoint;

    for (final segment in trailGroup.segments) {
      final coords = segment.geometry.coordinates;
      if (coords.isEmpty) continue;

      final segmentPoints = coords.map((coord) {
        return [
          (coord[0] as num).toDouble(),
          (coord[1] as num).toDouble(),
        ];
      }).toList();

      if (segmentPoints.isEmpty) continue;

      final canvasPoints = segmentPoints.map(toCanvas).toList();

      // Track first and last points across all segments
      firstPoint ??= canvasPoints.first;
      lastPoint = canvasPoints.last;

      // Draw this segment's path
      final path = Path();
      path.moveTo(canvasPoints[0].dx, canvasPoints[0].dy);
      for (var i = 1; i < canvasPoints.length; i++) {
        path.lineTo(canvasPoints[i].dx, canvasPoints[i].dy);
      }
      canvas.drawPath(path, pathPaint);
    }

    if (firstPoint == null || lastPoint == null) return;

    // Calculate distance markers using total trail length
    final totalMiles = trailGroup.totalLengthMiles;
    if (totalMiles > 0) {
      // Determine marker interval based on total length
      final markerInterval = totalMiles > 50
          ? 10.0
          : totalMiles > 10
              ? 5.0
              : totalMiles > 5
                  ? 1.0
                  : 0.5;

      // Place distance markers across all segments
      double accumulatedDistance = 0.0;
      int nextMarkerNumber = 1;

      for (final segment in trailGroup.segments) {
        final coords = segment.geometry.coordinates;
        if (coords.isEmpty) continue;

        final segmentPoints = coords.map((coord) {
          return [
            (coord[0] as num).toDouble(),
            (coord[1] as num).toDouble(),
          ];
        }).toList();

        final canvasPoints = segmentPoints.map(toCanvas).toList();

        for (var i = 0; i < segmentPoints.length - 1; i++) {
          final segmentStart = accumulatedDistance;
          final segmentDistance = _calculateDistance(
            segmentPoints[i][1],
            segmentPoints[i][0],
            segmentPoints[i + 1][1],
            segmentPoints[i + 1][0],
          );
          final segmentEnd = accumulatedDistance + segmentDistance;

          while (nextMarkerNumber * markerInterval <= segmentEnd &&
              nextMarkerNumber * markerInterval <= totalMiles) {
            final markerDistanceFromStart = nextMarkerNumber * markerInterval;
            final distanceIntoSegment = markerDistanceFromStart - segmentStart;
            final ratio =
                segmentDistance > 0 ? distanceIntoSegment / segmentDistance : 0;

            if (ratio >= 0 && ratio <= 1) {
              final markerPoint = Offset.lerp(
                canvasPoints[i],
                canvasPoints[i + 1],
                ratio.toDouble(),
              );

              if (markerPoint != null) {
                _drawDistanceMarker(
                  canvas,
                  markerPoint,
                  markerDistanceFromStart,
                  markerColor,
                  textColor,
                );
              }
            }

            nextMarkerNumber++;
          }

          accumulatedDistance += segmentDistance;
        }
      }
    }

    // Draw start marker (green circle) at first point of first segment
    final startPaint = Paint()
      ..color = startColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(firstPoint, 6, startPaint);
    canvas.drawCircle(
        firstPoint,
        8,
        Paint()
          ..color = startColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // Draw "START" label
    final startTextPainter = TextPainter(
      text: TextSpan(
        text: 'START',
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: labelBackgroundColor.withValues(alpha: 0.9),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    startTextPainter.layout();
    startTextPainter.paint(
      canvas,
      Offset(firstPoint.dx - startTextPainter.width / 2, firstPoint.dy - 20),
    );

    // Draw end marker (red circle) at last point of last segment
    final endPaint = Paint()
      ..color = endColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lastPoint, 6, endPaint);
    canvas.drawCircle(
        lastPoint,
        8,
        Paint()
          ..color = endColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // Draw "END" label
    final endTextPainter = TextPainter(
      text: TextSpan(
        text: 'END',
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: labelBackgroundColor.withValues(alpha: 0.9),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    endTextPainter.layout();
    endTextPainter.paint(
      canvas,
      Offset(lastPoint.dx - endTextPainter.width / 2, lastPoint.dy + 10),
    );
  }

  void _drawDistanceMarker(
    Canvas canvas,
    Offset position,
    double distanceMiles,
    Color markerColor,
    Color textColor,
  ) {
    // Draw marker circle
    final markerPaint = Paint()
      ..color = markerColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 4, markerPaint);

    // Draw distance label
    final text = '${distanceMiles.toStringAsFixed(1)}mi';
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          backgroundColor: labelBackgroundColor.withValues(alpha: 0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy - textPainter.height - 8),
    );
  }

  /// Calculate distance between two lat/lon points in miles (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusMiles = 3959.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMiles * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  @override
  bool shouldRepaint(TrailPathPainter oldDelegate) {
    return oldDelegate.trailGroup != trailGroup;
  }
}
