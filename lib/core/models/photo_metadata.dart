import 'package:flutter/foundation.dart';

/// Types of metadata that can be stored for photos
enum PhotoMetadataType {
  /// String value
  string,

  /// Integer value
  integer,

  /// Double/float value
  double,

  /// Boolean value
  boolean,

  /// Date/time value (stored as ISO string)
  datetime,
}

/// Extension to provide utility methods for metadata types
extension PhotoMetadataTypeExtension on PhotoMetadataType {
  /// Get the string representation for database storage
  String get name {
    switch (this) {
      case PhotoMetadataType.string:
        return 'string';
      case PhotoMetadataType.integer:
        return 'integer';
      case PhotoMetadataType.double:
        return 'double';
      case PhotoMetadataType.boolean:
        return 'boolean';
      case PhotoMetadataType.datetime:
        return 'datetime';
    }
  }

  /// Parse a metadata type from string
  static PhotoMetadataType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'integer':
        return PhotoMetadataType.integer;
      case 'double':
        return PhotoMetadataType.double;
      case 'boolean':
        return PhotoMetadataType.boolean;
      case 'datetime':
        return PhotoMetadataType.datetime;
      case 'string':
      default:
        return PhotoMetadataType.string;
    }
  }
}

/// A metadata entry for a photo waypoint.
///
/// Stores flexible key-value pairs with type information for EXIF data,
/// custom annotations, and other photo-related metadata.
@immutable
class PhotoMetadata {
  const PhotoMetadata({
    required this.id,
    required this.photoWaypointId,
    required this.key,
    required this.type,
    this.value,
  });

  /// Create a photo metadata entry from database map
  factory PhotoMetadata.fromMap(Map<String, dynamic> map) => PhotoMetadata(
        id: map['id'] as int,
        photoWaypointId: map['photo_waypoint_id'] as String,
        key: map['key'] as String,
        value: map['value'] as String?,
        type: PhotoMetadataTypeExtension.fromString(map['type'] as String),
      );

  /// Create a string metadata entry
  factory PhotoMetadata.string({
    required int id,
    required String photoWaypointId,
    required String key,
    required String value,
  }) =>
      PhotoMetadata(
        id: id,
        photoWaypointId: photoWaypointId,
        key: key,
        value: value,
        type: PhotoMetadataType.string,
      );

  /// Create an integer metadata entry
  factory PhotoMetadata.integer({
    required int id,
    required String photoWaypointId,
    required String key,
    required int value,
  }) =>
      PhotoMetadata(
        id: id,
        photoWaypointId: photoWaypointId,
        key: key,
        value: value.toString(),
        type: PhotoMetadataType.integer,
      );

  /// Create a double metadata entry
  factory PhotoMetadata.double({
    required int id,
    required String photoWaypointId,
    required String key,
    required double value,
  }) =>
      PhotoMetadata(
        id: id,
        photoWaypointId: photoWaypointId,
        key: key,
        value: value.toString(),
        type: PhotoMetadataType.double,
      );

  /// Create a boolean metadata entry
  factory PhotoMetadata.boolean({
    required int id,
    required String photoWaypointId,
    required String key,
    required bool value,
  }) =>
      PhotoMetadata(
        id: id,
        photoWaypointId: photoWaypointId,
        key: key,
        value: value.toString(),
        type: PhotoMetadataType.boolean,
      );

  /// Create a datetime metadata entry
  factory PhotoMetadata.datetime({
    required int id,
    required String photoWaypointId,
    required String key,
    required DateTime value,
  }) =>
      PhotoMetadata(
        id: id,
        photoWaypointId: photoWaypointId,
        key: key,
        value: value.toIso8601String(),
        type: PhotoMetadataType.datetime,
      );

  /// Auto-incrementing ID from database
  final int id;

  /// ID of the photo waypoint this metadata belongs to
  final String photoWaypointId;

  /// Metadata key (e.g., 'camera_make', 'iso', 'custom_note')
  final String key;

  /// String representation of the value
  final String? value;

  /// Type of the metadata value
  final PhotoMetadataType type;

  /// Convert photo metadata to map for database storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'photo_waypoint_id': photoWaypointId,
        'key': key,
        'value': value,
        'type': type.name,
      };

  /// Get the typed value based on the metadata type
  dynamic get typedValue {
    if (value == null) return null;

    switch (type) {
      case PhotoMetadataType.string:
        return value;
      case PhotoMetadataType.integer:
        return int.tryParse(value!);
      case PhotoMetadataType.double:
        return double.tryParse(value!);
      case PhotoMetadataType.boolean:
        return value!.toLowerCase() == 'true';
      case PhotoMetadataType.datetime:
        return DateTime.tryParse(value!);
    }
  }

  /// Get a human-readable display value
  String get displayValue {
    if (value == null) return 'N/A';

    switch (type) {
      case PhotoMetadataType.boolean:
        return typedValue == true ? 'Yes' : 'No';
      case PhotoMetadataType.datetime:
        final DateTime? dateTime = typedValue as DateTime?;
        if (dateTime != null) {
          return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
        }
        return value!;
      case PhotoMetadataType.string:
      case PhotoMetadataType.integer:
      case PhotoMetadataType.double:
        return value!;
    }
  }

  /// Check if this metadata represents EXIF data
  bool get isExifData => key.startsWith('exif_') || key.startsWith('camera_');

  /// Check if this metadata is custom user data
  bool get isCustomData => key.startsWith('custom_') || key.startsWith('user_');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoMetadata &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PhotoMetadata{id: $id, key: $key, value: $value, type: ${type.name}}';

  /// Create a copy of this photo metadata with updated values
  PhotoMetadata copyWith({
    int? id,
    String? photoWaypointId,
    String? key,
    String? value,
    PhotoMetadataType? type,
  }) =>
      PhotoMetadata(
        id: id ?? this.id,
        photoWaypointId: photoWaypointId ?? this.photoWaypointId,
        key: key ?? this.key,
        value: value ?? this.value,
        type: type ?? this.type,
      );
}

/// Common EXIF metadata keys for photos
class ExifKeys {
  static const String cameraMake = 'exif_camera_make';
  static const String cameraModel = 'exif_camera_model';
  static const String iso = 'exif_iso';
  static const String aperture = 'exif_aperture';
  static const String shutterSpeed = 'exif_shutter_speed';
  static const String focalLength = 'exif_focal_length';
  static const String flash = 'exif_flash';
  static const String orientation = 'exif_orientation';
  static const String dateTime = 'exif_date_time';
  static const String gpsLatitude = 'exif_gps_latitude';
  static const String gpsLongitude = 'exif_gps_longitude';
  static const String gpsAltitude = 'exif_gps_altitude';
}

/// Location and compass metadata keys
class LocationKeys {
  // Basic GPS coordinates
  static const String latitude = 'location_latitude';
  static const String longitude = 'location_longitude';
  static const String altitude = 'location_altitude';
  static const String accuracy = 'location_accuracy';
  static const String speed = 'location_speed';
  static const String gpsHeading = 'location_gps_heading';
  static const String timestamp = 'location_timestamp';

  // Compass and magnetometer data
  static const String compassHeading = 'compass_heading';
  static const String trueHeading = 'compass_true_heading';
  static const String magneticDeclination = 'compass_magnetic_declination';
  static const String magnetometerX = 'magnetometer_x';
  static const String magnetometerY = 'magnetometer_y';
  static const String magnetometerZ = 'magnetometer_z';

  // Accuracy information
  static const String horizontalAccuracy = 'accuracy_horizontal_accuracy';
  static const String altitudeAccuracy = 'accuracy_altitude_accuracy';
  static const String speedAccuracy = 'accuracy_speed_accuracy';
  static const String headingAccuracy = 'accuracy_heading_accuracy';

  // Privacy settings
  static const String privacyGpsEnabled = 'privacy_gps_enabled';
  static const String privacyCompassEnabled = 'privacy_compass_enabled';
  static const String privacyFuzzingLevel = 'privacy_fuzzing_level';
}

/// Common custom metadata keys for user annotations
class CustomKeys {
  static const String userNote = 'custom_user_note';
  static const String tags = 'custom_tags';
  static const String rating = 'custom_rating';
  static const String favorite = 'custom_favorite';
  static const String weatherConditions = 'custom_weather';
  static const String companions = 'custom_companions';
}
