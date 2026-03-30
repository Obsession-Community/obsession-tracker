import 'package:flutter/material.dart';

/// Color coding modes for trail visualization
enum TrailColorMode {
  /// Color based on speed (slow/medium/fast)
  speed,

  /// Color based on time periods
  time,

  /// Color based on elevation changes
  elevation,

  /// Color based on GPS accuracy
  accuracy,

  /// Single color (default)
  single,
}

/// Predefined color schemes for different trail color modes
@immutable
class TrailColorScheme {
  const TrailColorScheme({
    required this.name,
    required this.mode,
    required this.colors,
    required this.thresholds,
    this.isAccessibilityFriendly = false,
    this.description,
  });

  /// Create from map
  factory TrailColorScheme.fromMap(Map<String, dynamic> map) =>
      TrailColorScheme(
        name: map['name'] as String,
        mode: TrailColorMode.values.firstWhere(
          (TrailColorMode mode) => mode.name == map['mode'],
        ),
        colors: (map['colors'] as List<dynamic>)
            .map((c) => Color(c as int))
            .toList(),
        thresholds: (map['thresholds'] as List<dynamic>)
            .map((t) => t as double)
            .toList(),
        isAccessibilityFriendly:
            map['isAccessibilityFriendly'] as bool? ?? false,
        description: map['description'] as String?,
      );

  /// Name of the color scheme
  final String name;

  /// Color mode this scheme applies to
  final TrailColorMode mode;

  /// List of colors used in the scheme
  final List<Color> colors;

  /// Threshold values for color transitions
  final List<double> thresholds;

  /// Whether this scheme is colorblind-friendly
  final bool isAccessibilityFriendly;

  /// Optional description of the scheme
  final String? description;

  /// Create a copy with updated values
  TrailColorScheme copyWith({
    String? name,
    TrailColorMode? mode,
    List<Color>? colors,
    List<double>? thresholds,
    bool? isAccessibilityFriendly,
    String? description,
  }) =>
      TrailColorScheme(
        name: name ?? this.name,
        mode: mode ?? this.mode,
        colors: colors ?? this.colors,
        thresholds: thresholds ?? this.thresholds,
        isAccessibilityFriendly:
            isAccessibilityFriendly ?? this.isAccessibilityFriendly,
        description: description ?? this.description,
      );

  /// Convert to map for storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'mode': mode.name,
        'colors': colors.map((Color c) => c.toARGB32()).toList(),
        'thresholds': thresholds,
        'isAccessibilityFriendly': isAccessibilityFriendly,
        'description': description,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrailColorScheme &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          mode == other.mode;

  @override
  int get hashCode => name.hashCode ^ mode.hashCode;
}

/// Predefined color schemes
class PredefinedColorSchemes {
  PredefinedColorSchemes._();

  /// Speed-based color schemes
  static const TrailColorScheme speedDefault = TrailColorScheme(
    name: 'Speed - Default',
    mode: TrailColorMode.speed,
    colors: <Color>[
      Colors.red, // Slow
      Colors.orange, // Medium
      Colors.green, // Fast
    ],
    thresholds: <double>[1.0, 3.0], // m/s thresholds
    description: 'Red for slow, orange for medium, green for fast speeds',
  );

  static const TrailColorScheme speedAccessible = TrailColorScheme(
    name: 'Speed - Accessible',
    mode: TrailColorMode.speed,
    colors: <Color>[
      Color(0xFF1f77b4), // Blue
      Color(0xFFff7f0e), // Orange
      Color(0xFF2ca02c), // Green
    ],
    thresholds: <double>[1.0, 3.0],
    isAccessibilityFriendly: true,
    description: 'Colorblind-friendly speed visualization',
  );

  /// Time-based color schemes
  static const TrailColorScheme timeDefault = TrailColorScheme(
    name: 'Time - Rainbow',
    mode: TrailColorMode.time,
    colors: <Color>[
      Colors.purple,
      Colors.blue,
      Colors.cyan,
      Colors.green,
      Colors.yellow,
      Colors.orange,
      Colors.red,
    ],
    thresholds: <double>[
      0.0,
      0.17,
      0.33,
      0.5,
      0.67,
      0.83,
      1.0
    ], // Normalized time
    description: 'Rainbow progression from start to end of trail',
  );

  static const TrailColorScheme timeAccessible = TrailColorScheme(
    name: 'Time - Accessible',
    mode: TrailColorMode.time,
    colors: <Color>[
      Color(0xFF1f77b4), // Blue
      Color(0xFF17becf), // Cyan
      Color(0xFF2ca02c), // Green
      Color(0xFFffbb78), // Light orange
    ],
    thresholds: <double>[0.0, 0.33, 0.67, 1.0],
    isAccessibilityFriendly: true,
    description: 'Colorblind-friendly time progression',
  );

  /// Elevation-based color schemes
  static const TrailColorScheme elevationDefault = TrailColorScheme(
    name: 'Elevation - Terrain',
    mode: TrailColorMode.elevation,
    colors: <Color>[
      Color(0xFF0066CC), // Deep blue (low)
      Color(0xFF00CC66), // Green (medium)
      Color(0xFFFFCC00), // Yellow (high)
      Color(0xFFCC6600), // Orange (higher)
      Color(0xFFCC0000), // Red (highest)
    ],
    thresholds: <double>[0.0, 0.25, 0.5, 0.75, 1.0], // Normalized elevation
    description: 'Terrain-like colors from low to high elevation',
  );

  /// Accuracy-based color schemes
  static const TrailColorScheme accuracyDefault = TrailColorScheme(
    name: 'Accuracy - Quality',
    mode: TrailColorMode.accuracy,
    colors: <Color>[
      Colors.green, // Excellent accuracy
      Colors.yellow, // Good accuracy
      Colors.orange, // Fair accuracy
      Colors.red, // Poor accuracy
    ],
    thresholds: <double>[3.0, 5.0, 10.0], // Accuracy in meters
    description: 'Green for excellent, red for poor GPS accuracy',
  );

  /// Single color scheme
  static const TrailColorScheme singleDefault = TrailColorScheme(
    name: 'Single - Blue',
    mode: TrailColorMode.single,
    colors: <Color>[Colors.blue],
    thresholds: <double>[],
    description: 'Single blue color for entire trail',
  );

  /// Get all predefined schemes
  static List<TrailColorScheme> get all => <TrailColorScheme>[
        speedDefault,
        speedAccessible,
        timeDefault,
        timeAccessible,
        elevationDefault,
        accuracyDefault,
        singleDefault,
      ];

  /// Get schemes for a specific mode
  static List<TrailColorScheme> forMode(TrailColorMode mode) =>
      all.where((TrailColorScheme scheme) => scheme.mode == mode).toList();

  /// Get accessibility-friendly schemes
  static List<TrailColorScheme> get accessibilityFriendly => all
      .where((TrailColorScheme scheme) => scheme.isAccessibilityFriendly)
      .toList();
}
