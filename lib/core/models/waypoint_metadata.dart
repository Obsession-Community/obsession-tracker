import 'package:flutter/foundation.dart';

/// Advanced metadata for waypoints with custom fields and validation
@immutable
class WaypointMetadata {
  const WaypointMetadata({
    required this.waypointId,
    required this.customFields,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const <String>[],
    this.priority = WaypointPriority.normal,
    this.visibility = WaypointVisibility.private,
    this.weatherConditions,
    this.elevation,
    this.difficulty,
    this.estimatedDuration,
    this.accessibilityInfo,
    this.safetyNotes,
    this.bestTimeToVisit,
    this.equipment,
    this.permits,
    this.fees,
    this.contacts,
    this.urls,
  });

  /// Create metadata from database map
  factory WaypointMetadata.fromMap(Map<String, dynamic> map) =>
      WaypointMetadata(
        waypointId: map['waypoint_id'] as String,
        customFields: Map<String, dynamic>.from(map['custom_fields'] as Map),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
        tags: map['tags'] != null
            ? List<String>.from(map['tags'] as List)
            : const <String>[],
        priority: WaypointPriority.values.firstWhere(
          (p) => p.name == map['priority'],
          orElse: () => WaypointPriority.normal,
        ),
        visibility: WaypointVisibility.values.firstWhere(
          (v) => v.name == map['visibility'],
          orElse: () => WaypointVisibility.private,
        ),
        weatherConditions: map['weather_conditions'] as String?,
        elevation: map['elevation'] as double?,
        difficulty: map['difficulty'] != null
            ? WaypointDifficulty.values.firstWhere(
                (d) => d.name == map['difficulty'],
                orElse: () => WaypointDifficulty.easy,
              )
            : null,
        estimatedDuration: map['estimated_duration'] as int?,
        accessibilityInfo: map['accessibility_info'] as String?,
        safetyNotes: map['safety_notes'] as String?,
        bestTimeToVisit: map['best_time_to_visit'] as String?,
        equipment: map['equipment'] != null
            ? List<String>.from(map['equipment'] as List)
            : null,
        permits: map['permits'] as String?,
        fees: map['fees'] as String?,
        contacts: map['contacts'] != null
            ? List<String>.from(map['contacts'] as List)
            : null,
        urls:
            map['urls'] != null ? List<String>.from(map['urls'] as List) : null,
      );

  /// ID of the waypoint this metadata belongs to
  final String waypointId;

  /// Custom fields with dynamic values
  final Map<String, dynamic> customFields;

  /// When this metadata was created
  final DateTime createdAt;

  /// When this metadata was last updated
  final DateTime updatedAt;

  /// Tags for categorization and search
  final List<String> tags;

  /// Priority level of the waypoint
  final WaypointPriority priority;

  /// Visibility/sharing level
  final WaypointVisibility visibility;

  /// Weather conditions when waypoint was created/visited
  final String? weatherConditions;

  /// Elevation in meters
  final double? elevation;

  /// Difficulty rating
  final WaypointDifficulty? difficulty;

  /// Estimated duration to reach/complete in minutes
  final int? estimatedDuration;

  /// Accessibility information
  final String? accessibilityInfo;

  /// Safety notes and warnings
  final String? safetyNotes;

  /// Best time to visit information
  final String? bestTimeToVisit;

  /// Required or recommended equipment
  final List<String>? equipment;

  /// Required permits or permissions
  final String? permits;

  /// Associated fees or costs
  final String? fees;

  /// Emergency or relevant contacts
  final List<String>? contacts;

  /// Related URLs or resources
  final List<String>? urls;

  /// Convert to map for database storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'waypoint_id': waypointId,
        'custom_fields': customFields,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'tags': tags,
        'priority': priority.name,
        'visibility': visibility.name,
        'weather_conditions': weatherConditions,
        'elevation': elevation,
        'difficulty': difficulty?.name,
        'estimated_duration': estimatedDuration,
        'accessibility_info': accessibilityInfo,
        'safety_notes': safetyNotes,
        'best_time_to_visit': bestTimeToVisit,
        'equipment': equipment,
        'permits': permits,
        'fees': fees,
        'contacts': contacts,
        'urls': urls,
      };

  /// Create a copy with updated values
  WaypointMetadata copyWith({
    String? waypointId,
    Map<String, dynamic>? customFields,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    WaypointPriority? priority,
    WaypointVisibility? visibility,
    String? weatherConditions,
    double? elevation,
    WaypointDifficulty? difficulty,
    int? estimatedDuration,
    String? accessibilityInfo,
    String? safetyNotes,
    String? bestTimeToVisit,
    List<String>? equipment,
    String? permits,
    String? fees,
    List<String>? contacts,
    List<String>? urls,
  }) =>
      WaypointMetadata(
        waypointId: waypointId ?? this.waypointId,
        customFields: customFields ?? this.customFields,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        tags: tags ?? this.tags,
        priority: priority ?? this.priority,
        visibility: visibility ?? this.visibility,
        weatherConditions: weatherConditions ?? this.weatherConditions,
        elevation: elevation ?? this.elevation,
        difficulty: difficulty ?? this.difficulty,
        estimatedDuration: estimatedDuration ?? this.estimatedDuration,
        accessibilityInfo: accessibilityInfo ?? this.accessibilityInfo,
        safetyNotes: safetyNotes ?? this.safetyNotes,
        bestTimeToVisit: bestTimeToVisit ?? this.bestTimeToVisit,
        equipment: equipment ?? this.equipment,
        permits: permits ?? this.permits,
        fees: fees ?? this.fees,
        contacts: contacts ?? this.contacts,
        urls: urls ?? this.urls,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaypointMetadata &&
          runtimeType == other.runtimeType &&
          waypointId == other.waypointId;

  @override
  int get hashCode => waypointId.hashCode;

  @override
  String toString() =>
      'WaypointMetadata{waypointId: $waypointId, tags: ${tags.length}, priority: $priority}';
}

/// Priority levels for waypoints
enum WaypointPriority {
  low,
  normal,
  high,
  critical,
}

/// Extension for waypoint priority
extension WaypointPriorityExtension on WaypointPriority {
  /// Display name for the priority
  String get displayName {
    switch (this) {
      case WaypointPriority.low:
        return 'Low';
      case WaypointPriority.normal:
        return 'Normal';
      case WaypointPriority.high:
        return 'High';
      case WaypointPriority.critical:
        return 'Critical';
    }
  }

  /// Numeric value for sorting
  int get value {
    switch (this) {
      case WaypointPriority.low:
        return 1;
      case WaypointPriority.normal:
        return 2;
      case WaypointPriority.high:
        return 3;
      case WaypointPriority.critical:
        return 4;
    }
  }
}

/// Visibility levels for waypoints
enum WaypointVisibility {
  private,
  friends,
  public,
}

/// Extension for waypoint visibility
extension WaypointVisibilityExtension on WaypointVisibility {
  /// Display name for the visibility
  String get displayName {
    switch (this) {
      case WaypointVisibility.private:
        return 'Private';
      case WaypointVisibility.friends:
        return 'Friends';
      case WaypointVisibility.public:
        return 'Public';
    }
  }
}

/// Difficulty levels for waypoints
enum WaypointDifficulty {
  easy,
  moderate,
  difficult,
  expert,
}

/// Extension for waypoint difficulty
extension WaypointDifficultyExtension on WaypointDifficulty {
  /// Display name for the difficulty
  String get displayName {
    switch (this) {
      case WaypointDifficulty.easy:
        return 'Easy';
      case WaypointDifficulty.moderate:
        return 'Moderate';
      case WaypointDifficulty.difficult:
        return 'Difficult';
      case WaypointDifficulty.expert:
        return 'Expert';
    }
  }

  /// Numeric value for sorting
  int get value {
    switch (this) {
      case WaypointDifficulty.easy:
        return 1;
      case WaypointDifficulty.moderate:
        return 2;
      case WaypointDifficulty.difficult:
        return 3;
      case WaypointDifficulty.expert:
        return 4;
    }
  }
}

/// Relationship between waypoints
@immutable
class WaypointRelationship {
  const WaypointRelationship({
    required this.id,
    required this.fromWaypointId,
    required this.toWaypointId,
    required this.relationshipType,
    required this.createdAt,
    this.description,
    this.distance,
    this.estimatedTravelTime,
    this.difficulty,
    this.notes,
  });

  /// Create relationship from database map
  factory WaypointRelationship.fromMap(Map<String, dynamic> map) =>
      WaypointRelationship(
        id: map['id'] as String,
        fromWaypointId: map['from_waypoint_id'] as String,
        toWaypointId: map['to_waypoint_id'] as String,
        relationshipType: WaypointRelationshipType.values.firstWhere(
          (type) => type.name == map['relationship_type'],
          orElse: () => WaypointRelationshipType.related,
        ),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        description: map['description'] as String?,
        distance: map['distance'] as double?,
        estimatedTravelTime: map['estimated_travel_time'] as int?,
        difficulty: map['difficulty'] != null
            ? WaypointDifficulty.values.firstWhere(
                (d) => d.name == map['difficulty'],
                orElse: () => WaypointDifficulty.easy,
              )
            : null,
        notes: map['notes'] as String?,
      );

  /// Unique identifier for this relationship
  final String id;

  /// Source waypoint ID
  final String fromWaypointId;

  /// Target waypoint ID
  final String toWaypointId;

  /// Type of relationship
  final WaypointRelationshipType relationshipType;

  /// When this relationship was created
  final DateTime createdAt;

  /// Optional description of the relationship
  final String? description;

  /// Distance between waypoints in meters
  final double? distance;

  /// Estimated travel time in minutes
  final int? estimatedTravelTime;

  /// Difficulty of traveling between waypoints
  final WaypointDifficulty? difficulty;

  /// Additional notes about the relationship
  final String? notes;

  /// Convert to map for database storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'from_waypoint_id': fromWaypointId,
        'to_waypoint_id': toWaypointId,
        'relationship_type': relationshipType.name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'description': description,
        'distance': distance,
        'estimated_travel_time': estimatedTravelTime,
        'difficulty': difficulty?.name,
        'notes': notes,
      };

  /// Create a copy with updated values
  WaypointRelationship copyWith({
    String? id,
    String? fromWaypointId,
    String? toWaypointId,
    WaypointRelationshipType? relationshipType,
    DateTime? createdAt,
    String? description,
    double? distance,
    int? estimatedTravelTime,
    WaypointDifficulty? difficulty,
    String? notes,
  }) =>
      WaypointRelationship(
        id: id ?? this.id,
        fromWaypointId: fromWaypointId ?? this.fromWaypointId,
        toWaypointId: toWaypointId ?? this.toWaypointId,
        relationshipType: relationshipType ?? this.relationshipType,
        createdAt: createdAt ?? this.createdAt,
        description: description ?? this.description,
        distance: distance ?? this.distance,
        estimatedTravelTime: estimatedTravelTime ?? this.estimatedTravelTime,
        difficulty: difficulty ?? this.difficulty,
        notes: notes ?? this.notes,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaypointRelationship &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'WaypointRelationship{id: $id, type: $relationshipType, from: $fromWaypointId, to: $toWaypointId}';
}

/// Types of relationships between waypoints
enum WaypointRelationshipType {
  /// General relationship
  related,

  /// Sequential waypoints in a route
  nextInRoute,

  /// Previous waypoint in a route
  previousInRoute,

  /// Alternative route to same destination
  alternative,

  /// Waypoint is a prerequisite for another
  prerequisite,

  /// Waypoint depends on another
  dependsOn,

  /// Waypoints are part of the same group/cluster
  grouped,

  /// One waypoint is a variant of another
  variant,

  /// Waypoints are connected by a trail
  trailConnection,

  /// Emergency or safety relationship
  emergency,
}

/// Extension for waypoint relationship types
extension WaypointRelationshipTypeExtension on WaypointRelationshipType {
  /// Display name for the relationship type
  String get displayName {
    switch (this) {
      case WaypointRelationshipType.related:
        return 'Related';
      case WaypointRelationshipType.nextInRoute:
        return 'Next in Route';
      case WaypointRelationshipType.previousInRoute:
        return 'Previous in Route';
      case WaypointRelationshipType.alternative:
        return 'Alternative';
      case WaypointRelationshipType.prerequisite:
        return 'Prerequisite';
      case WaypointRelationshipType.dependsOn:
        return 'Depends On';
      case WaypointRelationshipType.grouped:
        return 'Grouped';
      case WaypointRelationshipType.variant:
        return 'Variant';
      case WaypointRelationshipType.trailConnection:
        return 'Trail Connection';
      case WaypointRelationshipType.emergency:
        return 'Emergency';
    }
  }

  /// Whether this relationship type is directional
  bool get isDirectional {
    switch (this) {
      case WaypointRelationshipType.nextInRoute:
      case WaypointRelationshipType.previousInRoute:
      case WaypointRelationshipType.prerequisite:
      case WaypointRelationshipType.dependsOn:
        return true;
      default:
        return false;
    }
  }
}
