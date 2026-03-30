import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Types of waypoint icons available for marking locations
enum WaypointType {
  // === Personal Markers ===
  /// Treasure or valuable item location
  treasure,

  /// Custom user-defined waypoint
  custom,

  /// Photo waypoint with captured image
  photo,

  /// Note waypoint with text only (no photo)
  note,

  /// Voice recording waypoint with audio message
  voice,

  /// Favorite location
  favorite,

  /// Memory or significant moment
  memory,

  /// Goal or destination
  goal,

  // === Outdoor Activities ===
  /// Hiking trail or trailhead
  hiking,

  /// Climbing spot or route
  climbing,

  /// Camping or rest area
  camp,

  /// Fishing spot
  fishing,

  /// Hunting area or stand
  hunting,

  /// Cycling route or point
  cycling,

  /// Kayaking or water access
  kayaking,

  /// Skiing area or run
  skiing,

  // === Points of Interest ===
  /// General point of interest
  interest,

  /// Scenic viewpoint
  viewpoint,

  /// Notable landmark
  landmark,

  /// Waterfall location
  waterfall,

  /// Cave entrance
  cave,

  /// Bridge crossing
  bridge,

  /// Ruins or historical site
  ruins,

  /// Wildlife sighting
  wildlife,

  /// Notable flora or plants
  flora,

  // === Facilities & Services ===
  /// Parking area
  parking,

  /// Restroom facilities
  restroom,

  /// Shelter or covered area
  shelter,

  /// Water source
  waterSource,

  /// Fuel or gas station
  fuelStation,

  /// Restaurant or food
  restaurant,

  /// Lodging or accommodation
  lodging,

  // === Safety & Navigation ===
  /// Warning or caution
  warning,

  /// Danger zone
  danger,

  /// Emergency point
  emergency,

  /// First aid location
  firstAid,
}

/// Extension to provide display properties for waypoint types
extension WaypointTypeExtension on WaypointType {
  /// Display name for the waypoint type
  String get displayName {
    switch (this) {
      // Personal Markers
      case WaypointType.treasure:
        return 'Treasure';
      case WaypointType.custom:
        return 'Custom';
      case WaypointType.photo:
        return 'Photo';
      case WaypointType.note:
        return 'Note';
      case WaypointType.voice:
        return 'Voice';
      case WaypointType.favorite:
        return 'Favorite';
      case WaypointType.memory:
        return 'Memory';
      case WaypointType.goal:
        return 'Goal';
      // Outdoor Activities
      case WaypointType.hiking:
        return 'Hiking';
      case WaypointType.climbing:
        return 'Climbing';
      case WaypointType.camp:
        return 'Camp';
      case WaypointType.fishing:
        return 'Fishing';
      case WaypointType.hunting:
        return 'Hunting';
      case WaypointType.cycling:
        return 'Cycling';
      case WaypointType.kayaking:
        return 'Kayaking';
      case WaypointType.skiing:
        return 'Skiing';
      // Points of Interest
      case WaypointType.interest:
        return 'Interest';
      case WaypointType.viewpoint:
        return 'Viewpoint';
      case WaypointType.landmark:
        return 'Landmark';
      case WaypointType.waterfall:
        return 'Waterfall';
      case WaypointType.cave:
        return 'Cave';
      case WaypointType.bridge:
        return 'Bridge';
      case WaypointType.ruins:
        return 'Ruins';
      case WaypointType.wildlife:
        return 'Wildlife';
      case WaypointType.flora:
        return 'Flora';
      // Facilities & Services
      case WaypointType.parking:
        return 'Parking';
      case WaypointType.restroom:
        return 'Restroom';
      case WaypointType.shelter:
        return 'Shelter';
      case WaypointType.waterSource:
        return 'Water Source';
      case WaypointType.fuelStation:
        return 'Fuel Station';
      case WaypointType.restaurant:
        return 'Restaurant';
      case WaypointType.lodging:
        return 'Lodging';
      // Safety & Navigation
      case WaypointType.warning:
        return 'Warning';
      case WaypointType.danger:
        return 'Danger';
      case WaypointType.emergency:
        return 'Emergency';
      case WaypointType.firstAid:
        return 'First Aid';
    }
  }

  /// Icon name for the waypoint type (for asset loading)
  String get iconName {
    switch (this) {
      // Personal Markers
      case WaypointType.treasure:
        return 'treasure';
      case WaypointType.custom:
        return 'custom';
      case WaypointType.photo:
        return 'photo';
      case WaypointType.note:
        return 'note';
      case WaypointType.voice:
        return 'voice';
      case WaypointType.favorite:
        return 'favorite';
      case WaypointType.memory:
        return 'memory';
      case WaypointType.goal:
        return 'goal';
      // Outdoor Activities
      case WaypointType.hiking:
        return 'hiking';
      case WaypointType.climbing:
        return 'climbing';
      case WaypointType.camp:
        return 'camp';
      case WaypointType.fishing:
        return 'fishing';
      case WaypointType.hunting:
        return 'hunting';
      case WaypointType.cycling:
        return 'cycling';
      case WaypointType.kayaking:
        return 'kayaking';
      case WaypointType.skiing:
        return 'skiing';
      // Points of Interest
      case WaypointType.interest:
        return 'interest';
      case WaypointType.viewpoint:
        return 'viewpoint';
      case WaypointType.landmark:
        return 'landmark';
      case WaypointType.waterfall:
        return 'waterfall';
      case WaypointType.cave:
        return 'cave';
      case WaypointType.bridge:
        return 'bridge';
      case WaypointType.ruins:
        return 'ruins';
      case WaypointType.wildlife:
        return 'wildlife';
      case WaypointType.flora:
        return 'flora';
      // Facilities & Services
      case WaypointType.parking:
        return 'parking';
      case WaypointType.restroom:
        return 'restroom';
      case WaypointType.shelter:
        return 'shelter';
      case WaypointType.waterSource:
        return 'water_source';
      case WaypointType.fuelStation:
        return 'fuel_station';
      case WaypointType.restaurant:
        return 'restaurant';
      case WaypointType.lodging:
        return 'lodging';
      // Safety & Navigation
      case WaypointType.warning:
        return 'warning';
      case WaypointType.danger:
        return 'danger';
      case WaypointType.emergency:
        return 'emergency';
      case WaypointType.firstAid:
        return 'first_aid';
    }
  }

  /// Color associated with the waypoint type
  String get colorHex {
    switch (this) {
      // Personal Markers - Warm colors
      case WaypointType.treasure:
        return '#FFD700'; // Gold
      case WaypointType.custom:
        return '#9C27B0'; // Purple
      case WaypointType.photo:
        return '#FF6B35'; // Orange
      case WaypointType.note:
        return '#00BCD4'; // Cyan/Teal
      case WaypointType.voice:
        return '#7C4DFF'; // Deep Purple Accent
      case WaypointType.favorite:
        return '#E91E63'; // Pink
      case WaypointType.memory:
        return '#9C27B0'; // Purple
      case WaypointType.goal:
        return '#FF9800'; // Amber
      // Outdoor Activities - Green/Nature tones
      case WaypointType.hiking:
        return '#4CAF50'; // Green
      case WaypointType.climbing:
        return '#795548'; // Brown
      case WaypointType.camp:
        return '#4CAF50'; // Green
      case WaypointType.fishing:
        return '#03A9F4'; // Light Blue
      case WaypointType.hunting:
        return '#8D6E63'; // Brown
      case WaypointType.cycling:
        return '#FF5722'; // Deep Orange
      case WaypointType.kayaking:
        return '#00BCD4'; // Cyan
      case WaypointType.skiing:
        return '#90CAF9'; // Light Blue
      // Points of Interest - Blue tones
      case WaypointType.interest:
        return '#2196F3'; // Blue
      case WaypointType.viewpoint:
        return '#3F51B5'; // Indigo
      case WaypointType.landmark:
        return '#673AB7'; // Deep Purple
      case WaypointType.waterfall:
        return '#00ACC1'; // Cyan
      case WaypointType.cave:
        return '#5D4037'; // Dark Brown
      case WaypointType.bridge:
        return '#607D8B'; // Blue Grey
      case WaypointType.ruins:
        return '#8D6E63'; // Brown
      case WaypointType.wildlife:
        return '#8BC34A'; // Light Green
      case WaypointType.flora:
        return '#66BB6A'; // Green
      // Facilities & Services - Neutral tones
      case WaypointType.parking:
        return '#2196F3'; // Blue
      case WaypointType.restroom:
        return '#607D8B'; // Blue Grey
      case WaypointType.shelter:
        return '#795548'; // Brown
      case WaypointType.waterSource:
        return '#03A9F4'; // Light Blue
      case WaypointType.fuelStation:
        return '#FF9800'; // Amber
      case WaypointType.restaurant:
        return '#FF5722'; // Deep Orange
      case WaypointType.lodging:
        return '#9C27B0'; // Purple
      // Safety & Navigation - Alert colors
      case WaypointType.warning:
        return '#FF9800'; // Amber
      case WaypointType.danger:
        return '#F44336'; // Red
      case WaypointType.emergency:
        return '#D32F2F'; // Dark Red
      case WaypointType.firstAid:
        return '#F44336'; // Red
    }
  }
}

/// A waypoint representing a marked location on the map with metadata.
///
/// Contains location data, type information, and user-provided details
/// for quick marking and navigation during adventures.
///
/// Waypoints can be associated with a tracking session via [sessionId],
/// or created as standalone waypoints (when [sessionId] is null).
/// A waypoint can have multiple attachments (photos, voice notes, text notes)
/// regardless of its [type].
@immutable
class Waypoint {
  const Waypoint({
    required this.id,
    required this.coordinates,
    required this.type,
    required this.timestamp,
    this.sessionId,
    this.name,
    this.notes,
    this.altitude,
    this.accuracy,
    this.speed,
    this.heading,
  });

  /// Create a waypoint from enhanced location data
  factory Waypoint.fromLocation({
    required String id,
    required double latitude,
    required double longitude,
    required WaypointType type,
    required DateTime timestamp,
    String? sessionId,
    String? name,
    String? notes,
    double? altitude,
    double? accuracy,
    double? speed,
    double? heading,
  }) =>
      Waypoint(
        id: id,
        coordinates: LatLng(latitude, longitude),
        type: type,
        timestamp: timestamp,
        sessionId: sessionId,
        name: name,
        notes: notes,
        altitude: altitude,
        accuracy: accuracy,
        speed: speed,
        heading: heading,
      );

  /// Create waypoint from database map
  factory Waypoint.fromMap(Map<String, dynamic> map) => Waypoint(
        id: map['id'] as String,
        coordinates: LatLng(
          map['latitude'] as double,
          map['longitude'] as double,
        ),
        type: WaypointType.values.firstWhere(
          (WaypointType e) => e.name == map['type'],
          orElse: () => WaypointType.custom,
        ),
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        sessionId: map['session_id'] as String?,
        name: map['name'] as String?,
        notes: map['notes'] as String?,
        altitude: map['altitude'] as double?,
        accuracy: map['accuracy'] as double?,
        speed: map['speed'] as double?,
        heading: map['heading'] as double?,
      );

  /// Unique identifier for this waypoint
  final String id;

  /// Geographic coordinates (latitude, longitude)
  final LatLng coordinates;

  /// Type of waypoint (determines icon and color)
  final WaypointType type;

  /// When this waypoint was created
  final DateTime timestamp;

  /// Session ID this waypoint belongs to (null for standalone waypoints)
  final String? sessionId;

  /// Whether this waypoint is standalone (not associated with a session)
  bool get isStandalone => sessionId == null;

  /// Optional user-defined name for the waypoint
  final String? name;

  /// Optional user notes about this waypoint
  final String? notes;

  /// Altitude in meters (from enhanced location data)
  final double? altitude;

  /// GPS accuracy in meters when waypoint was created
  final double? accuracy;

  /// Speed in meters per second when waypoint was created
  final double? speed;

  /// Heading/bearing in degrees when waypoint was created
  final double? heading;

  /// Convert waypoint to map for database storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'latitude': coordinates.latitude,
        'longitude': coordinates.longitude,
        'type': type.name,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'session_id': sessionId,
        'name': name,
        'notes': notes,
        'altitude': altitude,
        'accuracy': accuracy,
        'speed': speed,
        'heading': heading,
      };

  /// Get display name (user name or type name)
  String get displayName => name ?? type.displayName;

  /// Check if this waypoint has good GPS accuracy
  bool get hasGoodAccuracy => accuracy != null && accuracy! <= 10.0;

  /// Get a human-readable accuracy description
  String get accuracyDescription {
    if (accuracy == null) {
      return 'Unknown';
    }
    if (accuracy! <= 3) {
      return 'Excellent';
    }
    if (accuracy! <= 5) {
      return 'Good';
    }
    if (accuracy! <= 10) {
      return 'Fair';
    }
    if (accuracy! <= 20) {
      return 'Poor';
    }
    return 'Very Poor';
  }

  /// Calculate distance to another waypoint in meters
  double distanceTo(Waypoint other) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, coordinates, other.coordinates);
  }

  /// Calculate distance to coordinates in meters
  double distanceToCoordinates(LatLng coordinates) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, this.coordinates, coordinates);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Waypoint && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Waypoint{id: $id, type: ${type.displayName}, coordinates: $coordinates, name: $displayName}';

  /// Create a copy of this waypoint with updated values
  Waypoint copyWith({
    String? id,
    LatLng? coordinates,
    WaypointType? type,
    DateTime? timestamp,
    String? sessionId,
    String? name,
    String? notes,
    double? altitude,
    double? accuracy,
    double? speed,
    double? heading,
  }) =>
      Waypoint(
        id: id ?? this.id,
        coordinates: coordinates ?? this.coordinates,
        type: type ?? this.type,
        timestamp: timestamp ?? this.timestamp,
        sessionId: sessionId ?? this.sessionId,
        name: name ?? this.name,
        notes: notes ?? this.notes,
        altitude: altitude ?? this.altitude,
        accuracy: accuracy ?? this.accuracy,
        speed: speed ?? this.speed,
        heading: heading ?? this.heading,
      );
}
