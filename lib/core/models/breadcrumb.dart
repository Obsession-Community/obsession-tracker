import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// A GPS breadcrumb representing a single location point in a tracking session.
///
/// Contains essential location data including coordinates, timestamp,
/// and GPS accuracy information for privacy-first location tracking.
@immutable
class Breadcrumb {
  const Breadcrumb({
    required this.id,
    required this.coordinates,
    required this.accuracy,
    required this.timestamp,
    required this.sessionId,
    this.altitude,
    this.speed,
    this.heading,
  });

  /// Create a breadcrumb from GPS position data
  factory Breadcrumb.fromPosition({
    required String id,
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime timestamp,
    required String sessionId,
    double? altitude,
    double? speed,
    double? heading,
  }) =>
      Breadcrumb(
        id: id,
        coordinates: LatLng(latitude, longitude),
        accuracy: accuracy,
        timestamp: timestamp,
        sessionId: sessionId,
        altitude: altitude,
        speed: speed,
        heading: heading,
      );

  /// Create breadcrumb from database map
  factory Breadcrumb.fromMap(Map<String, dynamic> map) => Breadcrumb(
        id: map['id'] as String,
        coordinates: LatLng(
          map['latitude'] as double,
          map['longitude'] as double,
        ),
        altitude: map['altitude'] as double?,
        accuracy: map['accuracy'] as double,
        speed: map['speed'] as double?,
        heading: map['heading'] as double?,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        sessionId: map['session_id'] as String,
      );

  /// Unique identifier for this breadcrumb
  final String id;

  /// Geographic coordinates (latitude, longitude)
  final LatLng coordinates;

  /// Altitude in meters (null if not available)
  final double? altitude;

  /// GPS accuracy in meters
  final double accuracy;

  /// Speed in meters per second (null if not available)
  final double? speed;

  /// Heading/bearing in degrees (0-360, null if not available)
  final double? heading;

  /// Timestamp when this breadcrumb was recorded
  final DateTime timestamp;

  /// Session ID this breadcrumb belongs to
  final String sessionId;

  /// Convert breadcrumb to map for database storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'latitude': coordinates.latitude,
        'longitude': coordinates.longitude,
        'altitude': altitude,
        'accuracy': accuracy,
        'speed': speed,
        'heading': heading,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'session_id': sessionId,
      };

  /// Calculate distance to another breadcrumb in meters
  double distanceTo(Breadcrumb other) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, coordinates, other.coordinates);
  }

  /// Check if this breadcrumb has sufficient GPS accuracy for tracking
  bool get hasGoodAccuracy => accuracy <= 10.0; // Within 10 meters

  /// Get a human-readable accuracy description
  String get accuracyDescription {
    if (accuracy <= 3) {
      return 'Excellent';
    }
    if (accuracy <= 5) {
      return 'Good';
    }
    if (accuracy <= 10) {
      return 'Fair';
    }
    if (accuracy <= 20) {
      return 'Poor';
    }
    return 'Very Poor';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Breadcrumb && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Breadcrumb{id: $id, coordinates: $coordinates, accuracy: ${accuracy}m, timestamp: $timestamp}';

  /// Create a copy of this breadcrumb with updated values
  Breadcrumb copyWith({
    String? id,
    LatLng? coordinates,
    double? altitude,
    double? accuracy,
    double? speed,
    double? heading,
    DateTime? timestamp,
    String? sessionId,
  }) =>
      Breadcrumb(
        id: id ?? this.id,
        coordinates: coordinates ?? this.coordinates,
        altitude: altitude ?? this.altitude,
        accuracy: accuracy ?? this.accuracy,
        speed: speed ?? this.speed,
        heading: heading ?? this.heading,
        timestamp: timestamp ?? this.timestamp,
        sessionId: sessionId ?? this.sessionId,
      );
}
