import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// A named GPS coordinate used as a custom "North" reference for the compass.
///
/// When active, the compass N marker points toward this coordinate
/// instead of magnetic north — useful for treasure hunts with custom
/// directional landmarks (e.g., "Polaris Peak").
@immutable
class CustomNorthReference {
  const CustomNorthReference({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create a new reference with auto-generated UUID and timestamp.
  factory CustomNorthReference.create({
    required String name,
    required double latitude,
    required double longitude,
  }) =>
      CustomNorthReference(
        id: const Uuid().v4(),
        name: name,
        latitude: latitude,
        longitude: longitude,
        createdAt: DateTime.now(),
      );

  /// Deserialize from a SQLite row map.
  factory CustomNorthReference.fromMap(Map<String, dynamic> map) =>
      CustomNorthReference(
        id: map['id'] as String,
        name: map['name'] as String,
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        updatedAt: map['updated_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
            : null,
      );

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Serialize to a SQLite row map.
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt?.millisecondsSinceEpoch,
      };

  CustomNorthReference copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      CustomNorthReference(
        id: id ?? this.id,
        name: name ?? this.name,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomNorthReference &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() =>
      'CustomNorthReference(id: $id, name: $name, lat: $latitude, lon: $longitude)';
}
