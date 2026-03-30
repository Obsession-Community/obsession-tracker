import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

/// Types of map annotations
enum AnnotationType {
  /// Simple marker/pin
  marker,

  /// Text label
  text,

  /// Line/polyline
  line,

  /// Polygon/area
  polygon,

  /// Circle
  circle,

  /// Rectangle
  rectangle,

  /// Arrow
  arrow,

  /// Freehand drawing
  freehand,
}

/// Drawing modes for map interaction
enum DrawingMode {
  /// No drawing mode active
  none,

  /// Drawing lines
  line,

  /// Drawing polygons
  polygon,

  /// Drawing circles
  circle,

  /// Drawing rectangles
  rectangle,

  /// Freehand drawing
  freehand,

  /// Adding markers
  marker,

  /// Adding text
  text,
}

/// Base class for all map annotations
@immutable
abstract class MapAnnotation {
  const MapAnnotation({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    this.color = Colors.blue,
    this.strokeWidth = 2.0,
    this.opacity = 1.0,
    this.isVisible = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final AnnotationType type;
  final String name;
  final String? description;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final bool isVisible;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Convert to map for storage
  Map<String, dynamic> toMap();

  /// Create copy with updated properties
  MapAnnotation copyWith({
    String? name,
    String? description,
    Color? color,
    double? strokeWidth,
    double? opacity,
    bool? isVisible,
  });
}

/// Marker annotation
@immutable
class MarkerAnnotation extends MapAnnotation {
  const MarkerAnnotation({
    required super.id,
    required super.name,
    required this.position,
    super.description,
    super.color,
    super.strokeWidth,
    super.opacity,
    super.isVisible,
    super.createdAt,
    super.updatedAt,
    this.icon,
    this.size = 24.0,
  }) : super(type: AnnotationType.marker);

  final LatLng position;
  final IconData? icon;
  final double size;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'name': name,
        'description': description,
        'color': color.toARGB32(),
        'strokeWidth': strokeWidth,
        'opacity': opacity,
        'isVisible': isVisible,
        'createdAt': createdAt?.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'icon': icon?.codePoint,
        'size': size,
      };

  @override
  MarkerAnnotation copyWith({
    String? name,
    String? description,
    Color? color,
    double? strokeWidth,
    double? opacity,
    bool? isVisible,
    LatLng? position,
    IconData? icon,
    double? size,
  }) =>
      MarkerAnnotation(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        color: color ?? this.color,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        opacity: opacity ?? this.opacity,
        isVisible: isVisible ?? this.isVisible,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        position: position ?? this.position,
        icon: icon ?? this.icon,
        size: size ?? this.size,
      );
}

/// Text annotation
@immutable
class TextAnnotation extends MapAnnotation {
  const TextAnnotation({
    required super.id,
    required super.name,
    required this.position,
    required this.text,
    super.description,
    super.color,
    super.strokeWidth,
    super.opacity,
    super.isVisible,
    super.createdAt,
    super.updatedAt,
    this.fontSize = 14.0,
    this.fontWeight = FontWeight.normal,
    this.backgroundColor,
  }) : super(type: AnnotationType.text);

  final LatLng position;
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? backgroundColor;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'name': name,
        'description': description,
        'color': color.toARGB32(),
        'strokeWidth': strokeWidth,
        'opacity': opacity,
        'isVisible': isVisible,
        'createdAt': createdAt?.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'text': text,
        'fontSize': fontSize,
        'fontWeight': fontWeight.index,
        'backgroundColor': backgroundColor?.toARGB32(),
      };

  @override
  TextAnnotation copyWith({
    String? name,
    String? description,
    Color? color,
    double? strokeWidth,
    double? opacity,
    bool? isVisible,
    LatLng? position,
    String? text,
    double? fontSize,
    FontWeight? fontWeight,
    Color? backgroundColor,
  }) =>
      TextAnnotation(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        color: color ?? this.color,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        opacity: opacity ?? this.opacity,
        isVisible: isVisible ?? this.isVisible,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        position: position ?? this.position,
        text: text ?? this.text,
        fontSize: fontSize ?? this.fontSize,
        fontWeight: fontWeight ?? this.fontWeight,
        backgroundColor: backgroundColor ?? this.backgroundColor,
      );
}

/// Line annotation
@immutable
class LineAnnotation extends MapAnnotation {
  const LineAnnotation({
    required super.id,
    required super.name,
    required this.points,
    super.description,
    super.color,
    super.strokeWidth,
    super.opacity,
    super.isVisible,
    super.createdAt,
    super.updatedAt,
    this.isDashed = false,
    this.dashPattern = const [5, 5],
  }) : super(type: AnnotationType.line);

  final List<LatLng> points;
  final bool isDashed;
  final List<double> dashPattern;

  /// Get total length of the line
  double get length {
    if (points.length < 2) return 0.0;

    double totalLength = 0.0;
    const Distance distance = Distance();

    for (int i = 0; i < points.length - 1; i++) {
      totalLength += distance.as(LengthUnit.Meter, points[i], points[i + 1]);
    }

    return totalLength;
  }

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'name': name,
        'description': description,
        'color': color.toARGB32(),
        'strokeWidth': strokeWidth,
        'opacity': opacity,
        'isVisible': isVisible,
        'createdAt': createdAt?.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
        'points':
            points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
        'isDashed': isDashed,
        'dashPattern': dashPattern,
      };

  @override
  LineAnnotation copyWith({
    String? name,
    String? description,
    Color? color,
    double? strokeWidth,
    double? opacity,
    bool? isVisible,
    List<LatLng>? points,
    bool? isDashed,
    List<double>? dashPattern,
  }) =>
      LineAnnotation(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        color: color ?? this.color,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        opacity: opacity ?? this.opacity,
        isVisible: isVisible ?? this.isVisible,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        points: points ?? this.points,
        isDashed: isDashed ?? this.isDashed,
        dashPattern: dashPattern ?? this.dashPattern,
      );
}

/// Polygon annotation
@immutable
class PolygonAnnotation extends MapAnnotation {
  const PolygonAnnotation({
    required super.id,
    required super.name,
    required this.points,
    super.description,
    super.color,
    super.strokeWidth,
    super.opacity,
    super.isVisible,
    super.createdAt,
    super.updatedAt,
    this.fillColor,
    this.fillOpacity = 0.3,
  }) : super(type: AnnotationType.polygon);

  final List<LatLng> points;
  final Color? fillColor;
  final double fillOpacity;

  /// Get area of the polygon in square meters
  double get area {
    if (points.length < 3) return 0.0;

    // Use shoelace formula for polygon area
    double area = 0.0;
    const double earthRadius = 6371000; // Earth radius in meters

    for (int i = 0; i < points.length; i++) {
      final int j = (i + 1) % points.length;
      final double lat1 = points[i].latitude * math.pi / 180;
      final double lat2 = points[j].latitude * math.pi / 180;
      final double lng1 = points[i].longitude * math.pi / 180;
      final double lng2 = points[j].longitude * math.pi / 180;

      area += (lng2 - lng1) * (2 + math.sin(lat1) + math.sin(lat2));
    }

    area = area.abs() * earthRadius * earthRadius / 2;
    return area;
  }

  /// Get perimeter of the polygon
  double get perimeter {
    if (points.length < 2) return 0.0;

    double totalLength = 0.0;
    const Distance distance = Distance();

    for (int i = 0; i < points.length; i++) {
      final int j = (i + 1) % points.length;
      totalLength += distance.as(LengthUnit.Meter, points[i], points[j]);
    }

    return totalLength;
  }

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'name': name,
        'description': description,
        'color': color.toARGB32(),
        'strokeWidth': strokeWidth,
        'opacity': opacity,
        'isVisible': isVisible,
        'createdAt': createdAt?.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
        'points':
            points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
        'fillColor': fillColor?.toARGB32(),
        'fillOpacity': fillOpacity,
      };

  @override
  PolygonAnnotation copyWith({
    String? name,
    String? description,
    Color? color,
    double? strokeWidth,
    double? opacity,
    bool? isVisible,
    List<LatLng>? points,
    Color? fillColor,
    double? fillOpacity,
  }) =>
      PolygonAnnotation(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        color: color ?? this.color,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        opacity: opacity ?? this.opacity,
        isVisible: isVisible ?? this.isVisible,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        points: points ?? this.points,
        fillColor: fillColor ?? this.fillColor,
        fillOpacity: fillOpacity ?? this.fillOpacity,
      );
}

/// Circle annotation
@immutable
class CircleAnnotation extends MapAnnotation {
  const CircleAnnotation({
    required super.id,
    required super.name,
    required this.center,
    required this.radius,
    super.description,
    super.color,
    super.strokeWidth,
    super.opacity,
    super.isVisible,
    super.createdAt,
    super.updatedAt,
    this.fillColor,
    this.fillOpacity = 0.3,
  }) : super(type: AnnotationType.circle);

  final LatLng center;
  final double radius; // in meters
  final Color? fillColor;
  final double fillOpacity;

  /// Get area of the circle
  double get area => math.pi * radius * radius;

  /// Get circumference of the circle
  double get circumference => 2 * math.pi * radius;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'name': name,
        'description': description,
        'color': color.toARGB32(),
        'strokeWidth': strokeWidth,
        'opacity': opacity,
        'isVisible': isVisible,
        'createdAt': createdAt?.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
        'centerLat': center.latitude,
        'centerLng': center.longitude,
        'radius': radius,
        'fillColor': fillColor?.toARGB32(),
        'fillOpacity': fillOpacity,
      };

  @override
  CircleAnnotation copyWith({
    String? name,
    String? description,
    Color? color,
    double? strokeWidth,
    double? opacity,
    bool? isVisible,
    LatLng? center,
    double? radius,
    Color? fillColor,
    double? fillOpacity,
  }) =>
      CircleAnnotation(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        color: color ?? this.color,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        opacity: opacity ?? this.opacity,
        isVisible: isVisible ?? this.isVisible,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        center: center ?? this.center,
        radius: radius ?? this.radius,
        fillColor: fillColor ?? this.fillColor,
        fillOpacity: fillOpacity ?? this.fillOpacity,
      );
}

/// Service for managing map annotations and drawings
class MapAnnotationService {
  factory MapAnnotationService() => _instance ??= MapAnnotationService._();
  MapAnnotationService._();
  static MapAnnotationService? _instance;

  final List<MapAnnotation> _annotations = <MapAnnotation>[];
  final StreamController<List<MapAnnotation>> _annotationsController =
      StreamController<List<MapAnnotation>>.broadcast();

  DrawingMode _currentDrawingMode = DrawingMode.none;
  Color currentColor = Colors.blue;
  double currentStrokeWidth = 2.0;
  double currentOpacity = 1.0;

  /// Stream of annotations
  Stream<List<MapAnnotation>> get annotationsStream =>
      _annotationsController.stream;

  /// Current drawing mode
  DrawingMode get currentDrawingMode => _currentDrawingMode;

  /// Get all annotations
  List<MapAnnotation> get annotations => List.unmodifiable(_annotations);

  /// Set drawing mode
  void setDrawingMode(DrawingMode mode) {
    _currentDrawingMode = mode;
    debugPrint('Drawing mode set to: $mode');
  }

  /// Add annotation
  void addAnnotation(MapAnnotation annotation) {
    _annotations.add(annotation);
    _broadcastAnnotations();
    debugPrint('Added annotation: ${annotation.name} (${annotation.type})');
  }

  /// Update annotation
  void updateAnnotation(MapAnnotation annotation) {
    final int index = _annotations.indexWhere((a) => a.id == annotation.id);
    if (index != -1) {
      _annotations[index] = annotation;
      _broadcastAnnotations();
      debugPrint('Updated annotation: ${annotation.name}');
    }
  }

  /// Remove annotation
  void removeAnnotation(String id) {
    final int index = _annotations.indexWhere((a) => a.id == id);
    if (index != -1) {
      final MapAnnotation removed = _annotations.removeAt(index);
      _broadcastAnnotations();
      debugPrint('Removed annotation: ${removed.name}');
    }
  }

  /// Clear all annotations
  void clearAnnotations() {
    _annotations.clear();
    _broadcastAnnotations();
    debugPrint('Cleared all annotations');
  }

  /// Get annotation by ID
  MapAnnotation? getAnnotation(String id) {
    try {
      return _annotations.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get annotations by type
  List<MapAnnotation> getAnnotationsByType(AnnotationType type) =>
      _annotations.where((a) => a.type == type).toList();

  /// Create marker annotation
  MarkerAnnotation createMarker({
    required LatLng position,
    required String name,
    String? description,
    IconData? icon,
    double? size,
  }) {
    final String id = const Uuid().v4();
    return MarkerAnnotation(
      id: id,
      name: name,
      description: description,
      position: position,
      color: currentColor,
      opacity: currentOpacity,
      icon: icon,
      size: size ?? 24.0,
      createdAt: DateTime.now(),
    );
  }

  /// Create text annotation
  TextAnnotation createText({
    required LatLng position,
    required String text,
    String? name,
    String? description,
    double? fontSize,
    FontWeight? fontWeight,
    Color? backgroundColor,
  }) {
    final String id = const Uuid().v4();
    return TextAnnotation(
      id: id,
      name: name ?? 'Text ${_annotations.length + 1}',
      description: description,
      position: position,
      text: text,
      color: currentColor,
      opacity: currentOpacity,
      fontSize: fontSize ?? 14.0,
      fontWeight: fontWeight ?? FontWeight.normal,
      backgroundColor: backgroundColor,
      createdAt: DateTime.now(),
    );
  }

  /// Create line annotation
  LineAnnotation createLine({
    required List<LatLng> points,
    String? name,
    String? description,
    bool isDashed = false,
    List<double>? dashPattern,
  }) {
    final String id = const Uuid().v4();
    return LineAnnotation(
      id: id,
      name: name ?? 'Line ${_annotations.length + 1}',
      description: description,
      points: points,
      color: currentColor,
      strokeWidth: currentStrokeWidth,
      opacity: currentOpacity,
      isDashed: isDashed,
      dashPattern: dashPattern ?? const [5, 5],
      createdAt: DateTime.now(),
    );
  }

  /// Create polygon annotation
  PolygonAnnotation createPolygon({
    required List<LatLng> points,
    String? name,
    String? description,
    Color? fillColor,
    double? fillOpacity,
  }) {
    final String id = const Uuid().v4();
    return PolygonAnnotation(
      id: id,
      name: name ?? 'Polygon ${_annotations.length + 1}',
      description: description,
      points: points,
      color: currentColor,
      strokeWidth: currentStrokeWidth,
      opacity: currentOpacity,
      fillColor: fillColor ?? currentColor.withValues(alpha: 0.3),
      fillOpacity: fillOpacity ?? 0.3,
      createdAt: DateTime.now(),
    );
  }

  /// Create circle annotation
  CircleAnnotation createCircle({
    required LatLng center,
    required double radius,
    String? name,
    String? description,
    Color? fillColor,
    double? fillOpacity,
  }) {
    final String id = const Uuid().v4();
    return CircleAnnotation(
      id: id,
      name: name ?? 'Circle ${_annotations.length + 1}',
      description: description,
      center: center,
      radius: radius,
      color: currentColor,
      strokeWidth: currentStrokeWidth,
      opacity: currentOpacity,
      fillColor: fillColor ?? currentColor.withValues(alpha: 0.3),
      fillOpacity: fillOpacity ?? 0.3,
      createdAt: DateTime.now(),
    );
  }

  /// Toggle annotation visibility
  void toggleAnnotationVisibility(String id) {
    final int index = _annotations.indexWhere((a) => a.id == id);
    if (index != -1) {
      final MapAnnotation annotation = _annotations[index];
      _annotations[index] =
          annotation.copyWith(isVisible: !annotation.isVisible);
      _broadcastAnnotations();
    }
  }

  /// Get total measurements for all annotations
  Map<String, dynamic> getTotalMeasurements() {
    double totalLength = 0.0;
    double totalArea = 0.0;
    int lineCount = 0;
    int polygonCount = 0;
    int circleCount = 0;

    for (final MapAnnotation annotation in _annotations) {
      if (annotation is LineAnnotation) {
        totalLength += annotation.length;
        lineCount++;
      } else if (annotation is PolygonAnnotation) {
        totalArea += annotation.area;
        totalLength += annotation.perimeter;
        polygonCount++;
      } else if (annotation is CircleAnnotation) {
        totalArea += annotation.area;
        totalLength += annotation.circumference;
        circleCount++;
      }
    }

    return {
      'totalLength': totalLength,
      'totalArea': totalArea,
      'lineCount': lineCount,
      'polygonCount': polygonCount,
      'circleCount': circleCount,
      'totalAnnotations': _annotations.length,
    };
  }

  /// Broadcast annotations to stream
  void _broadcastAnnotations() {
    _annotationsController.add(List.from(_annotations));
  }

  /// Dispose of the service
  void dispose() {
    _annotationsController.close();
    _annotations.clear();
    _instance = null;
  }
}
