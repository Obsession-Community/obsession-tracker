import 'dart:math';

/// Advanced trail editing service for desktop platforms
class TrailEditingService {
  factory TrailEditingService() => _instance;
  TrailEditingService._internal();
  static final TrailEditingService _instance = TrailEditingService._internal();

  final List<TrailEditOperation> _undoStack = <TrailEditOperation>[];
  final List<TrailEditOperation> _redoStack = <TrailEditOperation>[];
  final int _maxUndoOperations = 50;

  /// Undo the last operation
  bool undo() {
    if (_undoStack.isEmpty) return false;

    final operation = _undoStack.removeLast();
    operation.undo();
    _redoStack.add(operation);

    // Limit redo stack size
    if (_redoStack.length > _maxUndoOperations) {
      _redoStack.removeAt(0);
    }

    return true;
  }

  /// Redo the last undone operation
  bool redo() {
    if (_redoStack.isEmpty) return false;

    final operation = _redoStack.removeLast();
    operation.execute();
    _undoStack.add(operation);

    return true;
  }

  /// Execute an operation and add it to the undo stack
  void executeOperation(TrailEditOperation operation) {
    operation.execute();
    _undoStack.add(operation);

    // Clear redo stack when new operation is executed
    _redoStack.clear();

    // Limit undo stack size
    if (_undoStack.length > _maxUndoOperations) {
      _undoStack.removeAt(0);
    }
  }

  /// Clear all undo/redo history
  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
  }

  /// Check if undo is available
  bool get canUndo => _undoStack.isNotEmpty;

  /// Check if redo is available
  bool get canRedo => _redoStack.isNotEmpty;

  /// Get the name of the next undo operation
  String? get nextUndoOperationName =>
      _undoStack.isNotEmpty ? _undoStack.last.name : null;

  /// Get the name of the next redo operation
  String? get nextRedoOperationName =>
      _redoStack.isNotEmpty ? _redoStack.last.name : null;
}

/// Base class for trail editing operations
abstract class TrailEditOperation {
  const TrailEditOperation({required this.name});

  final String name;

  /// Execute the operation
  void execute();

  /// Undo the operation
  void undo();
}

/// Operation to add waypoints to a trail
class AddWaypointsOperation extends TrailEditOperation {
  AddWaypointsOperation({
    required this.trail,
    required this.waypoints,
    required this.insertIndex,
  }) : super(
            name:
                'Add ${waypoints.length} waypoint${waypoints.length == 1 ? '' : 's'}');

  final TrailData trail;
  final List<TrailWaypoint> waypoints;
  final int insertIndex;

  @override
  void execute() {
    trail.waypoints.insertAll(insertIndex, waypoints);
  }

  @override
  void undo() {
    trail.waypoints.removeRange(insertIndex, insertIndex + waypoints.length);
  }
}

/// Operation to remove waypoints from a trail
class RemoveWaypointsOperation extends TrailEditOperation {
  RemoveWaypointsOperation({
    required this.trail,
    required this.startIndex,
    required this.count,
  }) : super(name: 'Remove $count waypoint${count == 1 ? '' : 's'}') {
    // Store removed waypoints for undo
    _removedWaypoints = trail.waypoints.sublist(startIndex, startIndex + count);
  }

  final TrailData trail;
  final int startIndex;
  final int count;
  late final List<TrailWaypoint> _removedWaypoints;

  @override
  void execute() {
    trail.waypoints.removeRange(startIndex, startIndex + count);
  }

  @override
  void undo() {
    trail.waypoints.insertAll(startIndex, _removedWaypoints);
  }
}

/// Operation to move waypoints within a trail
class MoveWaypointsOperation extends TrailEditOperation {
  MoveWaypointsOperation({
    required this.trail,
    required this.fromIndex,
    required this.toIndex,
    required this.count,
  }) : super(name: 'Move $count waypoint${count == 1 ? '' : 's'}');

  final TrailData trail;
  final int fromIndex;
  final int toIndex;
  final int count;

  @override
  void execute() {
    final waypoints = trail.waypoints.sublist(fromIndex, fromIndex + count);
    trail.waypoints.removeRange(fromIndex, fromIndex + count);

    final adjustedToIndex = toIndex > fromIndex ? toIndex - count : toIndex;
    trail.waypoints.insertAll(adjustedToIndex, waypoints);
  }

  @override
  void undo() {
    final waypoints = trail.waypoints.sublist(toIndex, toIndex + count);
    trail.waypoints.removeRange(toIndex, toIndex + count);
    trail.waypoints.insertAll(fromIndex, waypoints);
  }
}

/// Operation to edit waypoint properties
class EditWaypointOperation extends TrailEditOperation {
  EditWaypointOperation({
    required this.waypoint,
    required this.newProperties,
  }) : super(name: 'Edit waypoint') {
    // Store original properties for undo
    _originalProperties = WaypointProperties(
      name: waypoint.name,
      description: waypoint.description,
      elevation: waypoint.elevation,
      timestamp: waypoint.timestamp,
    );
  }

  final TrailWaypoint waypoint;
  final WaypointProperties newProperties;
  late final WaypointProperties _originalProperties;

  @override
  void execute() {
    waypoint.name = newProperties.name;
    waypoint.description = newProperties.description;
    waypoint.elevation = newProperties.elevation;
    waypoint.timestamp = newProperties.timestamp;
  }

  @override
  void undo() {
    waypoint.name = _originalProperties.name;
    waypoint.description = _originalProperties.description;
    waypoint.elevation = _originalProperties.elevation;
    waypoint.timestamp = _originalProperties.timestamp;
  }
}

/// Operation to smooth trail segments
class SmoothTrailOperation extends TrailEditOperation {
  SmoothTrailOperation({
    required this.trail,
    required this.startIndex,
    required this.endIndex,
    required this.smoothingFactor,
  }) : super(name: 'Smooth trail segment') {
    // Store original waypoints for undo
    _originalWaypoints = trail.waypoints
        .sublist(startIndex, endIndex + 1)
        .map(TrailWaypoint.copy)
        .toList();
  }

  final TrailData trail;
  final int startIndex;
  final int endIndex;
  final double smoothingFactor;
  late final List<TrailWaypoint> _originalWaypoints;

  @override
  void execute() {
    _applySmoothingAlgorithm();
  }

  @override
  void undo() {
    for (int i = 0; i < _originalWaypoints.length; i++) {
      trail.waypoints[startIndex + i] = _originalWaypoints[i];
    }
  }

  void _applySmoothingAlgorithm() {
    // Simple moving average smoothing
    final segment = trail.waypoints.sublist(startIndex, endIndex + 1);
    final smoothed = <TrailWaypoint>[];

    for (int i = 0; i < segment.length; i++) {
      if (i == 0 || i == segment.length - 1) {
        // Keep first and last points unchanged
        smoothed.add(segment[i]);
        continue;
      }

      // Calculate weighted average of surrounding points
      final prev = segment[i - 1];
      final current = segment[i];
      final next = segment[i + 1];

      final smoothedLat =
          (prev.latitude + current.latitude * 2 + next.latitude) / 4;
      final smoothedLng =
          (prev.longitude + current.longitude * 2 + next.longitude) / 4;

      smoothed.add(TrailWaypoint(
        latitude: smoothedLat,
        longitude: smoothedLng,
        elevation: current.elevation,
        timestamp: current.timestamp,
        name: current.name,
        description: current.description,
      ));
    }

    // Replace segment with smoothed version
    trail.waypoints.replaceRange(startIndex, endIndex + 1, smoothed);
  }
}

/// Operation to simplify trail by removing redundant points
class SimplifyTrailOperation extends TrailEditOperation {
  SimplifyTrailOperation({
    required this.trail,
    required this.tolerance,
  }) : super(name: 'Simplify trail') {
    // Store original waypoints for undo
    _originalWaypoints = trail.waypoints.map(TrailWaypoint.copy).toList();
  }

  final TrailData trail;
  final double tolerance;
  late final List<TrailWaypoint> _originalWaypoints;

  @override
  void execute() {
    final simplified =
        _douglasPeuckerSimplification(trail.waypoints, tolerance);
    trail.waypoints.clear();
    trail.waypoints.addAll(simplified);
  }

  @override
  void undo() {
    trail.waypoints.clear();
    trail.waypoints.addAll(_originalWaypoints);
  }

  List<TrailWaypoint> _douglasPeuckerSimplification(
    List<TrailWaypoint> points,
    double tolerance,
  ) {
    if (points.length <= 2) return points;

    // Find the point with maximum distance from the line segment
    double maxDistance = 0;
    int maxIndex = 0;

    final start = points.first;
    final end = points.last;

    for (int i = 1; i < points.length - 1; i++) {
      final distance = _perpendicularDistance(points[i], start, end);
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    // If max distance is greater than tolerance, recursively simplify
    if (maxDistance > tolerance) {
      final leftSegment = _douglasPeuckerSimplification(
        points.sublist(0, maxIndex + 1),
        tolerance,
      );
      final rightSegment = _douglasPeuckerSimplification(
        points.sublist(maxIndex),
        tolerance,
      );

      // Combine results (remove duplicate point at junction)
      return [
        ...leftSegment.sublist(0, leftSegment.length - 1),
        ...rightSegment
      ];
    } else {
      // All points between start and end can be removed
      return [start, end];
    }
  }

  double _perpendicularDistance(
    TrailWaypoint point,
    TrailWaypoint lineStart,
    TrailWaypoint lineEnd,
  ) {
    // Calculate perpendicular distance from point to line segment
    final A = point.latitude - lineStart.latitude;
    final B = point.longitude - lineStart.longitude;
    final C = lineEnd.latitude - lineStart.latitude;
    final D = lineEnd.longitude - lineStart.longitude;

    final dot = A * C + B * D;
    final lenSq = C * C + D * D;

    if (lenSq == 0) return sqrt(A * A + B * B);

    final param = dot / lenSq;

    double xx, yy;
    if (param < 0) {
      xx = lineStart.latitude;
      yy = lineStart.longitude;
    } else if (param > 1) {
      xx = lineEnd.latitude;
      yy = lineEnd.longitude;
    } else {
      xx = lineStart.latitude + param * C;
      yy = lineStart.longitude + param * D;
    }

    final dx = point.latitude - xx;
    final dy = point.longitude - yy;
    return sqrt(dx * dx + dy * dy);
  }
}

/// Data classes for trail editing
class TrailData {
  TrailData({
    required this.id,
    required this.name,
    required this.waypoints,
  });

  final String id;
  String name;
  final List<TrailWaypoint> waypoints;
}

class TrailWaypoint {
  TrailWaypoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.elevation,
    this.name,
    this.description,
  });

  factory TrailWaypoint.copy(TrailWaypoint other) => TrailWaypoint(
        latitude: other.latitude,
        longitude: other.longitude,
        elevation: other.elevation,
        timestamp: other.timestamp,
        name: other.name,
        description: other.description,
      );

  double latitude;
  double longitude;
  double? elevation;
  DateTime timestamp;
  String? name;
  String? description;
}

class WaypointProperties {
  WaypointProperties({
    required this.timestamp,
    this.name,
    this.description,
    this.elevation,
  });

  final String? name;
  final String? description;
  final double? elevation;
  final DateTime timestamp;
}
