import 'dart:convert';

import 'package:flutter/material.dart';

/// Category of custom map marker for filtering and display
enum CustomMarkerCategory {
  researchLead, // Potential site to investigate
  permissionNeeded, // Requires landowner contact
  searched, // Already explored this location
  favorite, // Important/interesting location
  hazard, // Dangerous area warning
  parking, // Vehicle access point
  campsite, // Camping location
  photo, // Photo marker from session (migrated from PhotoWaypoint)
}

/// Extension to provide display properties for marker categories
extension CustomMarkerCategoryExtension on CustomMarkerCategory {
  /// Display name for the category
  String get displayName {
    switch (this) {
      case CustomMarkerCategory.researchLead:
        return 'Research Lead';
      case CustomMarkerCategory.permissionNeeded:
        return 'Permission Needed';
      case CustomMarkerCategory.searched:
        return 'Searched';
      case CustomMarkerCategory.favorite:
        return 'Favorite';
      case CustomMarkerCategory.hazard:
        return 'Hazard';
      case CustomMarkerCategory.parking:
        return 'Parking';
      case CustomMarkerCategory.campsite:
        return 'Campsite';
      case CustomMarkerCategory.photo:
        return 'Photo';
    }
  }

  /// Icon for the category
  IconData get iconData {
    switch (this) {
      case CustomMarkerCategory.researchLead:
        return Icons.search;
      case CustomMarkerCategory.permissionNeeded:
        return Icons.assignment;
      case CustomMarkerCategory.searched:
        return Icons.check_circle;
      case CustomMarkerCategory.favorite:
        return Icons.star;
      case CustomMarkerCategory.hazard:
        return Icons.warning;
      case CustomMarkerCategory.parking:
        return Icons.local_parking;
      case CustomMarkerCategory.campsite:
        return Icons.cabin;
      case CustomMarkerCategory.photo:
        return Icons.photo_camera;
    }
  }

  /// Emoji icon for map display
  String get emoji {
    switch (this) {
      case CustomMarkerCategory.researchLead:
        return '\u{1F50D}'; // Magnifying glass
      case CustomMarkerCategory.permissionNeeded:
        return '\u{1F4CB}'; // Clipboard
      case CustomMarkerCategory.searched:
        return '\u{2713}'; // Check mark
      case CustomMarkerCategory.favorite:
        return '\u{2B50}'; // Star
      case CustomMarkerCategory.hazard:
        return '\u{26A0}'; // Warning
      case CustomMarkerCategory.parking:
        return '\u{1F17F}'; // P button
      case CustomMarkerCategory.campsite:
        return '\u{26FA}'; // Tent
      case CustomMarkerCategory.photo:
        return '\u{1F4F7}'; // Camera
    }
  }

  /// Default color for the category
  Color get defaultColor {
    switch (this) {
      case CustomMarkerCategory.researchLead:
        return const Color(0xFFFFD700); // Gold
      case CustomMarkerCategory.permissionNeeded:
        return const Color(0xFFFF6B35); // Orange
      case CustomMarkerCategory.searched:
        return const Color(0xFF4CAF50); // Green
      case CustomMarkerCategory.favorite:
        return const Color(0xFFE91E63); // Pink
      case CustomMarkerCategory.hazard:
        return const Color(0xFFF44336); // Red
      case CustomMarkerCategory.parking:
        return const Color(0xFF2196F3); // Blue
      case CustomMarkerCategory.campsite:
        return const Color(0xFF8BC34A); // Light Green
      case CustomMarkerCategory.photo:
        return const Color(0xFF9C27B0); // Purple
    }
  }

  /// Hex color string for GeoJSON/Mapbox styling
  String get hexColor {
    switch (this) {
      case CustomMarkerCategory.researchLead:
        return '#FFD700';
      case CustomMarkerCategory.permissionNeeded:
        return '#FF6B35';
      case CustomMarkerCategory.searched:
        return '#4CAF50';
      case CustomMarkerCategory.favorite:
        return '#E91E63';
      case CustomMarkerCategory.hazard:
        return '#F44336';
      case CustomMarkerCategory.parking:
        return '#2196F3';
      case CustomMarkerCategory.campsite:
        return '#8BC34A';
      case CustomMarkerCategory.photo:
        return '#9C27B0';
    }
  }

  /// Short description of the category
  String get description {
    switch (this) {
      case CustomMarkerCategory.researchLead:
        return 'Potential site to investigate';
      case CustomMarkerCategory.permissionNeeded:
        return 'Requires landowner contact';
      case CustomMarkerCategory.searched:
        return 'Already explored this location';
      case CustomMarkerCategory.favorite:
        return 'Important or interesting location';
      case CustomMarkerCategory.hazard:
        return 'Dangerous area warning';
      case CustomMarkerCategory.parking:
        return 'Vehicle access point';
      case CustomMarkerCategory.campsite:
        return 'Camping location';
      case CustomMarkerCategory.photo:
        return 'Photo captured during session';
    }
  }
}

/// Status for community sharing (future feature)
enum ShareStatus {
  private, // Default - never leaves device
  shared, // User explicitly shared to community
}

/// A custom map marker that users can place anywhere on the map
///
/// Custom markers can be standalone (for at-home research, planning) or
/// associated with a tracking session. When sessionId is set, the marker
/// was created during active tracking and is linked to that session.
@immutable
class CustomMarker {
  const CustomMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.category,
    required this.colorArgb,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.sessionId,
    this.huntId,
    this.shareStatus = ShareStatus.private,
    this.communityId,
    this.sharedAt,
    this.metadata,
  });

  /// Unique identifier (UUID)
  final String id;

  /// Geographic latitude
  final double latitude;

  /// Geographic longitude
  final double longitude;

  /// User-defined name for the marker (required)
  final String name;

  /// Optional notes/description
  final String? notes;

  /// Category for filtering and default styling
  final CustomMarkerCategory category;

  /// Color as ARGB32 integer (uses category default if not customized)
  final int colorArgb;

  /// When the marker was created
  final DateTime createdAt;

  /// When the marker was last updated
  final DateTime updatedAt;

  /// Optional association with a tracking session
  final String? sessionId;

  /// Optional association with a treasure hunt
  final String? huntId;

  /// Community sharing status (future feature)
  final ShareStatus shareStatus;

  /// ID assigned by obsession.community when shared (future feature)
  final String? communityId;

  /// When the marker was shared to community (future feature)
  final DateTime? sharedAt;

  /// Extensible metadata as JSON
  final Map<String, dynamic>? metadata;

  /// Get the effective color for display
  Color get effectiveColor => Color(colorArgb);

  /// Check if marker is standalone (not tied to a session)
  bool get isStandalone => sessionId == null;

  /// Check if marker is linked to a session
  bool get isLinkedToSession => sessionId != null;

  /// Check if marker is linked to a hunt
  bool get isLinkedToHunt => huntId != null;

  /// Check if marker has been shared to community
  bool get isShared => shareStatus == ShareStatus.shared;

  /// Create from database map
  factory CustomMarker.fromDatabaseMap(Map<String, dynamic> map) {
    return CustomMarker(
      id: map['id'] as String,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      name: map['name'] as String,
      notes: map['notes'] as String?,
      category: CustomMarkerCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => CustomMarkerCategory.researchLead,
      ),
      colorArgb: map['color_argb'] as int,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      sessionId: map['session_id'] as String?,
      huntId: map['hunt_id'] as String?,
      shareStatus: ShareStatus.values.firstWhere(
        (s) => s.name == map['share_status'],
        orElse: () => ShareStatus.private,
      ),
      communityId: map['community_id'] as String?,
      sharedAt: map['shared_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['shared_at'] as int)
          : null,
      metadata: map['metadata'] != null
          ? jsonDecode(map['metadata'] as String) as Map<String, dynamic>
          : null,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'name': name,
      'notes': notes,
      'category': category.name,
      'color_argb': colorArgb,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'session_id': sessionId,
      'hunt_id': huntId,
      'share_status': shareStatus.name,
      'community_id': communityId,
      'shared_at': sharedAt?.millisecondsSinceEpoch,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
    };
  }

  /// Convert to GeoJSON Feature for map overlay
  Map<String, dynamic> toGeoJsonFeature() {
    return {
      'type': 'Feature',
      'id': id,
      'geometry': {
        'type': 'Point',
        'coordinates': [longitude, latitude], // GeoJSON uses [lng, lat]
      },
      'properties': {
        'id': id,
        'name': name,
        'category': category.name,
        'color': category.hexColor,
        'emoji': category.emoji,
        'hasNotes': notes != null && notes!.isNotEmpty,
        'isLinkedToHunt': isLinkedToHunt,
      },
    };
  }

  /// Create a copy with updated values
  CustomMarker copyWith({
    String? id,
    double? latitude,
    double? longitude,
    String? name,
    String? notes,
    CustomMarkerCategory? category,
    int? colorArgb,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sessionId,
    String? huntId,
    ShareStatus? shareStatus,
    String? communityId,
    DateTime? sharedAt,
    Map<String, dynamic>? metadata,
    bool clearNotes = false,
    bool clearSessionId = false,
    bool clearHuntId = false,
    bool clearMetadata = false,
  }) {
    return CustomMarker(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      name: name ?? this.name,
      notes: clearNotes ? null : (notes ?? this.notes),
      category: category ?? this.category,
      colorArgb: colorArgb ?? this.colorArgb,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      huntId: clearHuntId ? null : (huntId ?? this.huntId),
      shareStatus: shareStatus ?? this.shareStatus,
      communityId: communityId ?? this.communityId,
      sharedAt: sharedAt ?? this.sharedAt,
      metadata: clearMetadata ? null : (metadata ?? this.metadata),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomMarker &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CustomMarker{id: $id, name: $name, category: ${category.displayName}, lat: $latitude, lng: $longitude}';
}

/// Filter configuration for custom markers
@immutable
class CustomMarkerFilter {
  const CustomMarkerFilter({
    this.enabledCategories = const {
      CustomMarkerCategory.researchLead,
      CustomMarkerCategory.permissionNeeded,
      CustomMarkerCategory.searched,
      CustomMarkerCategory.favorite,
      CustomMarkerCategory.hazard,
      CustomMarkerCategory.parking,
      CustomMarkerCategory.campsite,
      CustomMarkerCategory.photo,
    },
    this.searchQuery,
    this.showOnlyWithAttachments = false,
    this.huntIdFilter,
  });

  /// Categories to show (all enabled by default)
  final Set<CustomMarkerCategory> enabledCategories;

  /// Optional search query for name/notes
  final String? searchQuery;

  /// If true, only show markers that have attachments
  final bool showOnlyWithAttachments;

  /// If set, only show markers linked to this hunt
  final String? huntIdFilter;

  /// Check if no categories are enabled
  bool get noCategoriesEnabled => enabledCategories.isEmpty;

  /// Check if all categories are enabled
  bool get allCategoriesEnabled =>
      enabledCategories.length == CustomMarkerCategory.values.length;

  /// Check if a specific category is enabled
  bool isCategoryEnabled(CustomMarkerCategory category) =>
      enabledCategories.contains(category);

  /// Default filter with all categories enabled
  static const CustomMarkerFilter defaultFilter = CustomMarkerFilter();

  /// Create a copy with a category toggled
  CustomMarkerFilter toggleCategory(CustomMarkerCategory category) {
    final newCategories = Set<CustomMarkerCategory>.from(enabledCategories);
    if (newCategories.contains(category)) {
      newCategories.remove(category);
    } else {
      newCategories.add(category);
    }
    return copyWith(enabledCategories: newCategories);
  }

  /// Create a copy with all categories enabled
  CustomMarkerFilter enableAllCategories() {
    return copyWith(
      enabledCategories: Set<CustomMarkerCategory>.from(
        CustomMarkerCategory.values,
      ),
    );
  }

  /// Create a copy with all categories disabled
  CustomMarkerFilter disableAllCategories() {
    return copyWith(enabledCategories: const {});
  }

  /// Create a copy with updated values
  CustomMarkerFilter copyWith({
    Set<CustomMarkerCategory>? enabledCategories,
    String? searchQuery,
    bool? showOnlyWithAttachments,
    String? huntIdFilter,
    bool clearSearchQuery = false,
    bool clearHuntIdFilter = false,
  }) {
    return CustomMarkerFilter(
      enabledCategories: enabledCategories ?? this.enabledCategories,
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      showOnlyWithAttachments:
          showOnlyWithAttachments ?? this.showOnlyWithAttachments,
      huntIdFilter:
          clearHuntIdFilter ? null : (huntIdFilter ?? this.huntIdFilter),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomMarkerFilter &&
          runtimeType == other.runtimeType &&
          setEquals(enabledCategories, other.enabledCategories) &&
          searchQuery == other.searchQuery &&
          showOnlyWithAttachments == other.showOnlyWithAttachments &&
          huntIdFilter == other.huntIdFilter;

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(enabledCategories),
        searchQuery,
        showOnlyWithAttachments,
        huntIdFilter,
      );
}

/// Helper for set equality check
bool setEquals<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  return a.containsAll(b);
}
