import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Represents an imported route from GPX or KML file
@immutable
class ImportedRoute {
  final String id;
  final String name;
  final String? description;
  final List<RoutePoint> points;
  final List<RouteWaypoint> waypoints;
  final double totalDistance;
  final double? estimatedDuration;
  final DateTime importedAt;
  final String sourceFormat; // 'gpx' or 'kml'
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ImportedRoute({
    required this.id,
    required this.name,
    this.description,
    required this.points,
    required this.waypoints,
    required this.totalDistance,
    this.estimatedDuration,
    required this.importedAt,
    required this.sourceFormat,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  ImportedRoute copyWith({
    String? id,
    String? name,
    String? description,
    List<RoutePoint>? points,
    List<RouteWaypoint>? waypoints,
    double? totalDistance,
    double? estimatedDuration,
    DateTime? importedAt,
    String? sourceFormat,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ImportedRoute(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      points: points ?? this.points,
      waypoints: waypoints ?? this.waypoints,
      totalDistance: totalDistance ?? this.totalDistance,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      importedAt: importedAt ?? this.importedAt,
      sourceFormat: sourceFormat ?? this.sourceFormat,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'points': points.map((p) => p.toJson()).toList(),
      'waypoints': waypoints.map((w) => w.toJson()).toList(),
      'totalDistance': totalDistance,
      'estimatedDuration': estimatedDuration,
      'importedAt': importedAt.millisecondsSinceEpoch,
      'sourceFormat': sourceFormat,
      'metadata': metadata,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ImportedRoute.fromJson(Map<String, dynamic> json) {
    return ImportedRoute(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      points: (json['points'] as List)
          .map((p) => RoutePoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      waypoints: (json['waypoints'] as List)
          .map((w) => RouteWaypoint.fromJson(w as Map<String, dynamic>))
          .toList(),
      totalDistance: (json['totalDistance'] as num).toDouble(),
      estimatedDuration: (json['estimatedDuration'] as num?)?.toDouble(),
      importedAt:
          DateTime.fromMillisecondsSinceEpoch(json['importedAt'] as int),
      sourceFormat: json['sourceFormat'] as String,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
    );
  }

  /// Create from database row
  factory ImportedRoute.fromDatabase(Map<String, dynamic> row) {
    return ImportedRoute(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      points: const [], // Points loaded separately for performance
      waypoints: const [], // Waypoints loaded separately for performance
      totalDistance: (row['total_distance'] as num).toDouble(),
      estimatedDuration: (row['estimated_duration'] as num?)?.toDouble(),
      importedAt:
          DateTime.fromMillisecondsSinceEpoch(row['imported_at'] as int),
      sourceFormat: row['source_format'] as String,
      metadata: row['metadata'] != null
          ? jsonDecode(row['metadata'] as String) as Map<String, dynamic>
          : {},
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  /// Convert to database row
  Map<String, dynamic> toDatabaseRow() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'total_distance': totalDistance,
      'estimated_duration': estimatedDuration,
      'imported_at': importedAt.millisecondsSinceEpoch,
      'source_format': sourceFormat,
      'metadata': jsonEncode(metadata),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() =>
      'ImportedRoute(id: $id, name: $name, points: ${points.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportedRoute &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Individual point along a route
class RoutePoint {
  final String id;
  final String routeId;
  final double latitude;
  final double longitude;
  final double? elevation;
  final DateTime? timestamp;
  final int sequenceNumber;

  const RoutePoint({
    required this.id,
    required this.routeId,
    required this.latitude,
    required this.longitude,
    this.elevation,
    this.timestamp,
    required this.sequenceNumber,
  });

  RoutePoint copyWith({
    String? id,
    String? routeId,
    double? latitude,
    double? longitude,
    double? elevation,
    DateTime? timestamp,
    int? sequenceNumber,
  }) {
    return RoutePoint(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      elevation: elevation ?? this.elevation,
      timestamp: timestamp ?? this.timestamp,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'routeId': routeId,
      'latitude': latitude,
      'longitude': longitude,
      'elevation': elevation,
      'timestamp': timestamp?.millisecondsSinceEpoch,
      'sequenceNumber': sequenceNumber,
    };
  }

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      id: json['id'] as String,
      routeId: json['routeId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      elevation: (json['elevation'] as num?)?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : null,
      sequenceNumber: json['sequenceNumber'] as int,
    );
  }

  /// Create from database row
  factory RoutePoint.fromDatabase(Map<String, dynamic> row) {
    return RoutePoint(
      id: row['id'] as String,
      routeId: row['route_id'] as String,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      elevation: (row['elevation'] as num?)?.toDouble(),
      timestamp: row['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int)
          : null,
      sequenceNumber: row['sequence_number'] as int,
    );
  }

  /// Convert to database row
  Map<String, dynamic> toDatabaseRow() {
    return {
      'id': id,
      'route_id': routeId,
      'latitude': latitude,
      'longitude': longitude,
      'elevation': elevation,
      'timestamp': timestamp?.millisecondsSinceEpoch,
      'sequence_number': sequenceNumber,
    };
  }

  @override
  String toString() =>
      'RoutePoint(lat: $latitude, lon: $longitude, seq: $sequenceNumber)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutePoint && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Waypoint along a route (POI, turn, etc.)
class RouteWaypoint {
  final String id;
  final String routeId;
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final double? elevation;
  final String? type;
  final Map<String, dynamic> properties;

  const RouteWaypoint({
    required this.id,
    required this.routeId,
    required this.name,
    this.description,
    required this.latitude,
    required this.longitude,
    this.elevation,
    this.type,
    required this.properties,
  });

  RouteWaypoint copyWith({
    String? id,
    String? routeId,
    String? name,
    String? description,
    double? latitude,
    double? longitude,
    double? elevation,
    String? type,
    Map<String, dynamic>? properties,
  }) {
    return RouteWaypoint(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      name: name ?? this.name,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      elevation: elevation ?? this.elevation,
      type: type ?? this.type,
      properties: properties ?? this.properties,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'routeId': routeId,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'elevation': elevation,
      'type': type,
      'properties': properties,
    };
  }

  factory RouteWaypoint.fromJson(Map<String, dynamic> json) {
    return RouteWaypoint(
      id: json['id'] as String,
      routeId: json['routeId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      elevation: (json['elevation'] as num?)?.toDouble(),
      type: json['type'] as String?,
      properties: Map<String, dynamic>.from(json['properties'] as Map),
    );
  }

  /// Create from database row
  factory RouteWaypoint.fromDatabase(Map<String, dynamic> row) {
    return RouteWaypoint(
      id: row['id'] as String,
      routeId: row['route_id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      elevation: (row['elevation'] as num?)?.toDouble(),
      type: row['type'] as String?,
      properties: row['properties'] != null
          ? jsonDecode(row['properties'] as String) as Map<String, dynamic>
          : {},
    );
  }

  /// Convert to database row
  Map<String, dynamic> toDatabaseRow() {
    return {
      'id': id,
      'route_id': routeId,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'elevation': elevation,
      'type': type,
      'properties': jsonEncode(properties),
    };
  }

  @override
  String toString() =>
      'RouteWaypoint(name: $name, lat: $latitude, lon: $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteWaypoint &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
