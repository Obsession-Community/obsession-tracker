import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/session_statistics.dart';
import 'package:obsession_tracker/core/models/trail_color_scheme.dart';
import 'package:obsession_tracker/core/models/trail_segment.dart';

/// Service for calculating trail colors based on various metrics
class TrailColorService {
  TrailColorService._();

  /// Singleton instance
  static final TrailColorService _instance = TrailColorService._();
  static TrailColorService get instance => _instance;

  /// Color cache for performance optimization
  final Map<String, Color> _colorCache = <String, Color>{};

  /// Calculate color for a breadcrumb based on the color scheme
  Color calculateColor(
    Breadcrumb breadcrumb,
    TrailColorScheme scheme,
    SessionStatistics? statistics,
    List<Breadcrumb>? allBreadcrumbs,
  ) {
    final String cacheKey = _generateCacheKey(breadcrumb, scheme);
    if (_colorCache.containsKey(cacheKey)) {
      return _colorCache[cacheKey]!;
    }

    Color color;
    switch (scheme.mode) {
      case TrailColorMode.speed:
        color = _calculateSpeedColor(breadcrumb, scheme);
        break;
      case TrailColorMode.time:
        color = _calculateTimeColor(breadcrumb, scheme, allBreadcrumbs);
        break;
      case TrailColorMode.elevation:
        color = _calculateElevationColor(breadcrumb, scheme, statistics);
        break;
      case TrailColorMode.accuracy:
        color = _calculateAccuracyColor(breadcrumb, scheme);
        break;
      case TrailColorMode.single:
        color = scheme.colors.first;
        break;
    }

    _colorCache[cacheKey] = color;
    return color;
  }

  /// Calculate color based on speed
  Color _calculateSpeedColor(Breadcrumb breadcrumb, TrailColorScheme scheme) {
    final double? speed = breadcrumb.speed;
    if (speed == null) {
      return scheme.colors.first; // Default to first color if no speed data
    }

    return _interpolateColor(speed, scheme.thresholds, scheme.colors);
  }

  /// Calculate color based on time progression
  Color _calculateTimeColor(
    Breadcrumb breadcrumb,
    TrailColorScheme scheme,
    List<Breadcrumb>? allBreadcrumbs,
  ) {
    if (allBreadcrumbs == null || allBreadcrumbs.isEmpty) {
      return scheme.colors.first;
    }

    // Sort breadcrumbs by timestamp to ensure proper ordering
    final List<Breadcrumb> sortedBreadcrumbs = List<Breadcrumb>.from(
        allBreadcrumbs)
      ..sort(
          (Breadcrumb a, Breadcrumb b) => a.timestamp.compareTo(b.timestamp));

    final DateTime startTime = sortedBreadcrumbs.first.timestamp;
    final DateTime endTime = sortedBreadcrumbs.last.timestamp;
    final Duration totalDuration = endTime.difference(startTime);

    if (totalDuration.inMilliseconds == 0) {
      return scheme.colors.first;
    }

    final Duration elapsed = breadcrumb.timestamp.difference(startTime);
    final double normalizedTime =
        elapsed.inMilliseconds / totalDuration.inMilliseconds;

    return _interpolateColorNormalized(normalizedTime, scheme.colors);
  }

  /// Calculate color based on elevation
  Color _calculateElevationColor(
    Breadcrumb breadcrumb,
    TrailColorScheme scheme,
    SessionStatistics? statistics,
  ) {
    final double? altitude = breadcrumb.altitude;
    if (altitude == null || statistics == null) {
      return scheme.colors.first;
    }

    final double? minAltitude = statistics.minAltitude;
    final double? maxAltitude = statistics.maxAltitude;

    if (minAltitude == null ||
        maxAltitude == null ||
        minAltitude == maxAltitude) {
      return scheme.colors.first;
    }

    final double normalizedElevation =
        (altitude - minAltitude) / (maxAltitude - minAltitude);

    return _interpolateColorNormalized(
        normalizedElevation.clamp(0.0, 1.0), scheme.colors);
  }

  /// Calculate color based on GPS accuracy
  Color _calculateAccuracyColor(
      Breadcrumb breadcrumb, TrailColorScheme scheme) {
    final double accuracy = breadcrumb.accuracy;
    return _interpolateColor(accuracy, scheme.thresholds, scheme.colors);
  }

  /// Interpolate color based on value and thresholds
  Color _interpolateColor(
      double value, List<double> thresholds, List<Color> colors) {
    if (thresholds.isEmpty || colors.isEmpty) {
      return colors.isNotEmpty ? colors.first : Colors.blue;
    }

    // Handle single color
    if (colors.length == 1) {
      return colors.first;
    }

    // Find the appropriate color range
    for (int i = 0; i < thresholds.length; i++) {
      if (value <= thresholds[i]) {
        if (i == 0) {
          return colors.first;
        }

        // Interpolate between colors[i-1] and colors[i]
        final double prevThreshold = i > 0 ? thresholds[i - 1] : 0.0;
        final double currentThreshold = thresholds[i];
        final double normalizedValue =
            (value - prevThreshold) / (currentThreshold - prevThreshold);

        return Color.lerp(colors[i], colors[math.min(i + 1, colors.length - 1)],
                normalizedValue.clamp(0.0, 1.0)) ??
            colors[i];
      }
    }

    // Value exceeds all thresholds, return last color
    return colors.last;
  }

  /// Interpolate color based on normalized value (0.0 to 1.0)
  Color _interpolateColorNormalized(
      double normalizedValue, List<Color> colors) {
    if (colors.isEmpty) return Colors.blue;
    if (colors.length == 1) return colors.first;

    final double clampedValue = normalizedValue.clamp(0.0, 1.0);
    final double segmentSize = 1.0 / (colors.length - 1);
    final int segmentIndex = (clampedValue / segmentSize).floor();
    final double segmentProgress = (clampedValue % segmentSize) / segmentSize;

    final int startIndex = segmentIndex.clamp(0, colors.length - 2);
    final int endIndex = (startIndex + 1).clamp(0, colors.length - 1);

    return Color.lerp(colors[startIndex], colors[endIndex], segmentProgress) ??
        colors[startIndex];
  }

  /// Generate trail segments from breadcrumbs with color coding
  List<TrailSegment> generateColoredSegments(
    List<Breadcrumb> breadcrumbs,
    TrailColorScheme scheme,
    SessionStatistics? statistics,
  ) {
    if (breadcrumbs.length < 2) {
      return <TrailSegment>[];
    }

    final List<TrailSegment> segments = <TrailSegment>[];

    for (int i = 0; i < breadcrumbs.length - 1; i++) {
      final Breadcrumb startBreadcrumb = breadcrumbs[i];
      final Breadcrumb endBreadcrumb = breadcrumbs[i + 1];

      // Calculate color for the end breadcrumb (represents the segment)
      final Color segmentColor = calculateColor(
        endBreadcrumb,
        scheme,
        statistics,
        breadcrumbs,
      );

      // Calculate value for the segment based on the color mode
      final double? segmentValue = _calculateSegmentValue(
        startBreadcrumb,
        endBreadcrumb,
        scheme.mode,
      );

      final TrailSegment segment = TrailSegment.fromBreadcrumbs(
        id: '${startBreadcrumb.id}_${endBreadcrumb.id}',
        startBreadcrumb: startBreadcrumb,
        endBreadcrumb: endBreadcrumb,
        color: segmentColor,
        value: segmentValue,
      );

      segments.add(segment);
    }

    return segments;
  }

  /// Calculate the representative value for a segment
  double? _calculateSegmentValue(
    Breadcrumb startBreadcrumb,
    Breadcrumb endBreadcrumb,
    TrailColorMode mode,
  ) {
    switch (mode) {
      case TrailColorMode.speed:
        return endBreadcrumb.speed;
      case TrailColorMode.elevation:
        return endBreadcrumb.altitude;
      case TrailColorMode.accuracy:
        return endBreadcrumb.accuracy;
      case TrailColorMode.time:
        return endBreadcrumb.timestamp.millisecondsSinceEpoch.toDouble();
      case TrailColorMode.single:
        return null;
    }
  }

  /// Generate cache key for color caching
  String _generateCacheKey(Breadcrumb breadcrumb, TrailColorScheme scheme) =>
      '${breadcrumb.id}_${scheme.name}_${scheme.mode.name}';

  /// Clear color cache
  void clearCache() {
    _colorCache.clear();
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() => <String, int>{
        'size': _colorCache.length,
      };

  /// Create custom color scheme
  TrailColorScheme createCustomScheme({
    required String name,
    required TrailColorMode mode,
    required List<Color> colors,
    required List<double> thresholds,
    bool isAccessibilityFriendly = false,
    String? description,
  }) {
    if (colors.isEmpty) {
      throw ArgumentError('Colors list cannot be empty');
    }

    if (mode != TrailColorMode.single && thresholds.isEmpty) {
      throw ArgumentError('Thresholds required for non-single color modes');
    }

    return TrailColorScheme(
      name: name,
      mode: mode,
      colors: colors,
      thresholds: thresholds,
      isAccessibilityFriendly: isAccessibilityFriendly,
      description: description,
    );
  }

  /// Validate color scheme
  bool validateColorScheme(TrailColorScheme scheme) {
    if (scheme.colors.isEmpty) return false;

    if (scheme.mode == TrailColorMode.single) {
      return scheme.colors.length == 1;
    }

    // For other modes, we need at least 2 colors and appropriate thresholds
    if (scheme.colors.length < 2) return false;
    if (scheme.thresholds.isEmpty) return false;

    // Check that thresholds are in ascending order
    for (int i = 1; i < scheme.thresholds.length; i++) {
      if (scheme.thresholds[i] <= scheme.thresholds[i - 1]) {
        return false;
      }
    }

    return true;
  }

  /// Get color legend information for a scheme
  List<ColorLegendItem> getColorLegend(
    TrailColorScheme scheme,
    SessionStatistics? statistics,
  ) {
    final List<ColorLegendItem> legend = <ColorLegendItem>[];

    switch (scheme.mode) {
      case TrailColorMode.speed:
        for (int i = 0; i < scheme.colors.length; i++) {
          final String label = _getSpeedLabel(i, scheme.thresholds);
          legend.add(ColorLegendItem(color: scheme.colors[i], label: label));
        }
        break;
      case TrailColorMode.time:
        legend.add(ColorLegendItem(color: scheme.colors.first, label: 'Start'));
        if (scheme.colors.length > 2) {
          legend.add(ColorLegendItem(
              color: scheme.colors[scheme.colors.length ~/ 2],
              label: 'Middle'));
        }
        legend.add(ColorLegendItem(color: scheme.colors.last, label: 'End'));
        break;
      case TrailColorMode.elevation:
        if (statistics?.hasAltitudeData == true) {
          legend.add(ColorLegendItem(
            color: scheme.colors.first,
            label:
                'Low (${statistics!.formatAltitude(statistics.minAltitude, UnitSystem.metric)})',
          ));
          legend.add(ColorLegendItem(
            color: scheme.colors.last,
            label:
                'High (${statistics.formatAltitude(statistics.maxAltitude, UnitSystem.metric)})',
          ));
        }
        break;
      case TrailColorMode.accuracy:
        for (int i = 0; i < scheme.colors.length; i++) {
          final String label = _getAccuracyLabel(i, scheme.thresholds);
          legend.add(ColorLegendItem(color: scheme.colors[i], label: label));
        }
        break;
      case TrailColorMode.single:
        legend.add(ColorLegendItem(color: scheme.colors.first, label: 'Trail'));
        break;
    }

    return legend;
  }

  String _getSpeedLabel(int index, List<double> thresholds) {
    if (index == 0)
      return 'Slow (< ${thresholds.isNotEmpty ? thresholds[0] : 1.0} m/s)';
    if (index == thresholds.length) return 'Fast (> ${thresholds.last} m/s)';
    return 'Medium (${thresholds[index - 1]} - ${thresholds[index]} m/s)';
  }

  String _getAccuracyLabel(int index, List<double> thresholds) {
    if (index == 0)
      return 'Excellent (< ${thresholds.isNotEmpty ? thresholds[0] : 3.0}m)';
    if (index == thresholds.length) return 'Poor (> ${thresholds.last}m)';
    return 'Good (${thresholds[index - 1]} - ${thresholds[index]}m)';
  }
}

/// Color legend item for displaying color meanings
class ColorLegendItem {
  const ColorLegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;
}
