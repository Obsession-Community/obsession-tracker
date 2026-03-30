import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';

/// A segment of a trail with color coding information
@immutable
class TrailSegment {
  const TrailSegment({
    required this.id,
    required this.sessionId,
    required this.startPoint,
    required this.endPoint,
    required this.color,
    required this.timestamp,
    this.startBreadcrumbId,
    this.endBreadcrumbId,
    this.value,
    this.strokeWidth = 4.0,
    this.opacity = 1.0,
  });

  /// Create segment from two breadcrumbs
  factory TrailSegment.fromBreadcrumbs({
    required String id,
    required Breadcrumb startBreadcrumb,
    required Breadcrumb endBreadcrumb,
    required Color color,
    double? value,
    double strokeWidth = 4.0,
    double opacity = 1.0,
  }) =>
      TrailSegment(
        id: id,
        sessionId: startBreadcrumb.sessionId,
        startPoint: startBreadcrumb.coordinates,
        endPoint: endBreadcrumb.coordinates,
        color: color,
        timestamp: endBreadcrumb.timestamp,
        startBreadcrumbId: startBreadcrumb.id,
        endBreadcrumbId: endBreadcrumb.id,
        value: value,
        strokeWidth: strokeWidth,
        opacity: opacity,
      );

  /// Create from database map
  factory TrailSegment.fromMap(Map<String, dynamic> map) => TrailSegment(
        id: map['id'] as String,
        sessionId: map['session_id'] as String,
        startPoint: LatLng(
          map['start_latitude'] as double,
          map['start_longitude'] as double,
        ),
        endPoint: LatLng(
          map['end_latitude'] as double,
          map['end_longitude'] as double,
        ),
        color: Color(map['color'] as int),
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        startBreadcrumbId: map['start_breadcrumb_id'] as String?,
        endBreadcrumbId: map['end_breadcrumb_id'] as String?,
        value: map['value'] as double?,
        strokeWidth: map['stroke_width'] as double? ?? 4.0,
        opacity: map['opacity'] as double? ?? 1.0,
      );

  /// Unique identifier for this segment
  final String id;

  /// Session ID this segment belongs to
  final String sessionId;

  /// Starting point coordinates
  final LatLng startPoint;

  /// Ending point coordinates
  final LatLng endPoint;

  /// Color for this segment
  final Color color;

  /// Timestamp when this segment was created
  final DateTime timestamp;

  /// ID of the starting breadcrumb (if available)
  final String? startBreadcrumbId;

  /// ID of the ending breadcrumb (if available)
  final String? endBreadcrumbId;

  /// Value used for color calculation (speed, elevation, etc.)
  final double? value;

  /// Stroke width for rendering
  final double strokeWidth;

  /// Opacity for rendering
  final double opacity;

  /// Calculate distance of this segment in meters
  double get distance {
    const Distance distanceCalculator = Distance();
    return distanceCalculator.as(LengthUnit.Meter, startPoint, endPoint);
  }

  /// Get the midpoint of this segment
  LatLng get midpoint => LatLng(
        (startPoint.latitude + endPoint.latitude) / 2,
        (startPoint.longitude + endPoint.longitude) / 2,
      );

  /// Convert to map for database storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'session_id': sessionId,
        'start_latitude': startPoint.latitude,
        'start_longitude': startPoint.longitude,
        'end_latitude': endPoint.latitude,
        'end_longitude': endPoint.longitude,
        'color': color.toARGB32(),
        'timestamp': timestamp.millisecondsSinceEpoch,
        'start_breadcrumb_id': startBreadcrumbId,
        'end_breadcrumb_id': endBreadcrumbId,
        'value': value,
        'stroke_width': strokeWidth,
        'opacity': opacity,
      };

  /// Create a copy with updated values
  TrailSegment copyWith({
    String? id,
    String? sessionId,
    LatLng? startPoint,
    LatLng? endPoint,
    Color? color,
    DateTime? timestamp,
    String? startBreadcrumbId,
    String? endBreadcrumbId,
    double? value,
    double? strokeWidth,
    double? opacity,
  }) =>
      TrailSegment(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        startPoint: startPoint ?? this.startPoint,
        endPoint: endPoint ?? this.endPoint,
        color: color ?? this.color,
        timestamp: timestamp ?? this.timestamp,
        startBreadcrumbId: startBreadcrumbId ?? this.startBreadcrumbId,
        endBreadcrumbId: endBreadcrumbId ?? this.endBreadcrumbId,
        value: value ?? this.value,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        opacity: opacity ?? this.opacity,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrailSegment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'TrailSegment{id: $id, distance: ${distance.toStringAsFixed(1)}m, color: $color, value: $value}';
}

/// Collection of trail segments for efficient management
class TrailSegmentCollection {
  TrailSegmentCollection({
    required this.sessionId,
    List<TrailSegment>? segments,
  }) : _segments = segments ?? <TrailSegment>[];

  /// Create from list of maps
  factory TrailSegmentCollection.fromMapList(
    String sessionId,
    List<Map<String, dynamic>> mapList,
  ) =>
      TrailSegmentCollection(
        sessionId: sessionId,
        segments: mapList.map(TrailSegment.fromMap).toList(),
      );

  /// Session ID for all segments in this collection
  final String sessionId;

  /// Internal list of segments
  final List<TrailSegment> _segments;

  /// Get all segments
  List<TrailSegment> get segments => List<TrailSegment>.unmodifiable(_segments);

  /// Get number of segments
  int get length => _segments.length;

  /// Check if collection is empty
  bool get isEmpty => _segments.isEmpty;

  /// Check if collection is not empty
  bool get isNotEmpty => _segments.isNotEmpty;

  /// Add a segment to the collection
  void addSegment(TrailSegment segment) {
    if (segment.sessionId != sessionId) {
      throw ArgumentError(
          'Segment session ID does not match collection session ID');
    }
    _segments.add(segment);
  }

  /// Add multiple segments
  void addSegments(List<TrailSegment> segments) {
    segments.forEach(addSegment);
  }

  /// Remove a segment by ID
  bool removeSegment(String segmentId) {
    final int index =
        _segments.indexWhere((TrailSegment s) => s.id == segmentId);
    if (index != -1) {
      _segments.removeAt(index);
      return true;
    }
    return false;
  }

  /// Clear all segments
  void clear() {
    _segments.clear();
  }

  /// Get segment by ID
  TrailSegment? getSegment(String segmentId) {
    for (final TrailSegment segment in _segments) {
      if (segment.id == segmentId) {
        return segment;
      }
    }
    return null;
  }

  /// Get segments within a time range
  List<TrailSegment> getSegmentsInTimeRange(DateTime start, DateTime end) =>
      _segments
          .where((TrailSegment s) =>
              s.timestamp.isAfter(start) && s.timestamp.isBefore(end))
          .toList();

  /// Get segments with a specific color
  List<TrailSegment> getSegmentsByColor(Color color) =>
      _segments.where((TrailSegment s) => s.color == color).toList();

  /// Calculate total distance of all segments
  double get totalDistance => _segments.fold(
      0.0, (double sum, TrailSegment segment) => sum + segment.distance);

  /// Get unique colors used in segments
  Set<Color> get uniqueColors =>
      _segments.map((TrailSegment s) => s.color).toSet();

  /// Convert to list of maps for storage
  List<Map<String, dynamic>> toMapList() =>
      _segments.map((TrailSegment s) => s.toMap()).toList();

  @override
  String toString() =>
      'TrailSegmentCollection{sessionId: $sessionId, segments: ${_segments.length}, distance: ${totalDistance.toStringAsFixed(1)}m}';
}
