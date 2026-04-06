import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/services/map_search_service.dart';
import 'package:uuid/uuid.dart';

/// A user-saved location for quick offline access across all search UIs.
///
/// Saved locations appear first in search results, reducing API calls
/// and enabling offline place lookup for treasure hunting workflows.
@immutable
class SavedLocation {
  const SavedLocation({
    required this.id,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.address,
    this.placeType,
    this.category,
    this.isFavorite = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create a new saved location with auto-generated UUID and timestamp.
  factory SavedLocation.create({
    required String displayName,
    required double latitude,
    required double longitude,
    String? address,
    String? placeType,
    String? category,
  }) =>
      SavedLocation(
        id: const Uuid().v4(),
        displayName: displayName,
        latitude: latitude,
        longitude: longitude,
        address: address,
        placeType: placeType,
        category: category,
        createdAt: DateTime.now(),
      );

  /// Create from a resolved MapSearchResult.
  ///
  /// The result must have non-null coordinates (resolve via
  /// `MapSearchService.retrieveCoordinates` first if `needsRetrieval`).
  factory SavedLocation.fromSearchResult(MapSearchResult result) {
    assert(
      result.latitude != null && result.longitude != null,
      'MapSearchResult must have coordinates before saving',
    );
    return SavedLocation.create(
      displayName: result.displayName,
      latitude: result.latitude!,
      longitude: result.longitude!,
      address: result.address,
      placeType: result.placeType,
    );
  }

  /// Deserialize from a SQLite row map.
  factory SavedLocation.fromMap(Map<String, dynamic> map) => SavedLocation(
        id: map['id'] as String,
        displayName: map['display_name'] as String,
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
        address: map['address'] as String?,
        placeType: map['place_type'] as String?,
        category: map['category'] as String?,
        isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        updatedAt: map['updated_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
            : null,
      );

  final String id;
  final String displayName;
  final double latitude;
  final double longitude;
  final String? address;
  final String? placeType;
  final String? category;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Serialize to a SQLite row map.
  Map<String, dynamic> toMap() => {
        'id': id,
        'display_name': displayName,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'place_type': placeType,
        'category': category,
        'is_favorite': isFavorite ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt?.millisecondsSinceEpoch,
      };

  /// Convert back to a MapSearchResult for use in search UIs.
  MapSearchResult toSearchResult() => MapSearchResult(
        displayName: displayName,
        latitude: latitude,
        longitude: longitude,
        address: address,
        placeType: 'saved_location',
      );

  SavedLocation copyWith({
    String? id,
    String? displayName,
    double? latitude,
    double? longitude,
    String? address,
    String? placeType,
    String? category,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      SavedLocation(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        address: address ?? this.address,
        placeType: placeType ?? this.placeType,
        category: category ?? this.category,
        isFavorite: isFavorite ?? this.isFavorite,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedLocation &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          address == other.address &&
          placeType == other.placeType &&
          category == other.category &&
          isFavorite == other.isFavorite &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      displayName.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      address.hashCode ^
      placeType.hashCode ^
      category.hashCode ^
      isFavorite.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() =>
      'SavedLocation(id: $id, name: $displayName, lat: $latitude, lon: $longitude)';
}
