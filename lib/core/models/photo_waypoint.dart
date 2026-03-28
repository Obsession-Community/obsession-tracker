import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/services/hunt_path_resolver.dart';

/// A photo waypoint representing a captured photo associated with a waypoint.
///
/// Contains file paths, metadata, and creation information for photos
/// taken at waypoint locations during adventures.
@immutable
class PhotoWaypoint {
  const PhotoWaypoint({
    required this.id,
    required this.waypointId,
    required this.filePath,
    required this.createdAt,
    required this.fileSize,
    this.thumbnailPath,
    this.width,
    this.height,
    this.devicePitch,
    this.deviceRoll,
    this.deviceYaw,
    this.photoOrientation,
    this.cameraTiltAngle,
    this.source,
  });

  /// Create a photo waypoint from database map
  ///
  /// Resolves relative file paths to absolute paths using [HuntPathResolver].
  factory PhotoWaypoint.fromMap(Map<String, dynamic> map) => PhotoWaypoint(
        id: map['id'] as String,
        waypointId: map['waypoint_id'] as String,
        // Resolve relative paths to absolute for filesystem access
        filePath: HuntPathResolver.resolveFromDatabase(
              map['file_path'] as String?,
            ) ??
            '',
        thumbnailPath: HuntPathResolver.resolveFromDatabase(
          map['thumbnail_path'] as String?,
        ),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        fileSize: map['file_size'] as int,
        width: map['width'] as int?,
        height: map['height'] as int?,
        devicePitch: map['device_pitch'] as double?,
        deviceRoll: map['device_roll'] as double?,
        deviceYaw: map['device_yaw'] as double?,
        photoOrientation: map['photo_orientation'] as String?,
        cameraTiltAngle: map['camera_tilt_angle'] as double?,
        source: map['source'] as String?,
      );

  /// Unique identifier for this photo waypoint
  final String id;

  /// ID of the waypoint this photo is associated with
  final String waypointId;

  /// Full path to the original photo file
  final String filePath;

  /// Path to the thumbnail image (optional)
  final String? thumbnailPath;

  /// When this photo was created
  final DateTime createdAt;

  /// File size in bytes
  final int fileSize;

  /// Image width in pixels (if available)
  final int? width;

  /// Image height in pixels (if available)
  final int? height;

  /// Device pitch angle in degrees when photo was taken (-90 to +90)
  /// Negative values = device tilted down, Positive = device tilted up
  final double? devicePitch;

  /// Device roll angle in degrees when photo was taken (-180 to +180)
  /// Negative values = tilted left, Positive = tilted right
  final double? deviceRoll;

  /// Device yaw/heading angle in degrees when photo was taken (0-360)
  /// Compass heading the device was facing
  final double? deviceYaw;

  /// Photo orientation when captured
  /// Values: 'portrait', 'landscape', 'landscape_left', 'landscape_right'
  final String? photoOrientation;

  /// Calculated camera tilt angle from device orientation
  /// Combined pitch/roll measurement for camera perspective
  final double? cameraTiltAngle;

  /// Source device that captured this photo
  /// Values: 'phone_camera' (default), 'meta_glasses'
  final String? source;

  /// Whether this photo was captured from Meta glasses
  bool get isFromMetaGlasses => source == 'meta_glasses';

  /// Convert photo waypoint to map for database storage
  ///
  /// Converts absolute file paths to relative paths for portability using [HuntPathResolver].
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'waypoint_id': waypointId,
        // Store relative paths for portability across iOS container changes
        'file_path': HuntPathResolver.prepareForDatabase(filePath),
        'thumbnail_path': HuntPathResolver.prepareForDatabase(thumbnailPath),
        'created_at': createdAt.millisecondsSinceEpoch,
        'file_size': fileSize,
        'width': width,
        'height': height,
        'device_pitch': devicePitch,
        'device_roll': deviceRoll,
        'device_yaw': deviceYaw,
        'photo_orientation': photoOrientation,
        'camera_tilt_angle': cameraTiltAngle,
        'source': source,
      };

  /// Get human-readable file size
  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Get image dimensions as a string (if available)
  String? get dimensionsFormatted {
    if (width != null && height != null) {
      return '${width}x$height';
    }
    return null;
  }

  /// Check if this photo has a thumbnail
  bool get hasThumbnail => thumbnailPath != null;

  /// Get aspect ratio (if dimensions are available)
  double? get aspectRatio {
    if (width != null && height != null && height! > 0) {
      return width! / height!;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoWaypoint &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PhotoWaypoint{id: $id, waypointId: $waypointId, filePath: $filePath, fileSize: $fileSizeFormatted}';

  /// Create a copy of this photo waypoint with updated values
  PhotoWaypoint copyWith({
    String? id,
    String? waypointId,
    String? filePath,
    String? thumbnailPath,
    DateTime? createdAt,
    int? fileSize,
    int? width,
    int? height,
    double? devicePitch,
    double? deviceRoll,
    double? deviceYaw,
    String? photoOrientation,
    double? cameraTiltAngle,
    String? source,
  }) =>
      PhotoWaypoint(
        id: id ?? this.id,
        waypointId: waypointId ?? this.waypointId,
        filePath: filePath ?? this.filePath,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        createdAt: createdAt ?? this.createdAt,
        fileSize: fileSize ?? this.fileSize,
        width: width ?? this.width,
        height: height ?? this.height,
        devicePitch: devicePitch ?? this.devicePitch,
        deviceRoll: deviceRoll ?? this.deviceRoll,
        deviceYaw: deviceYaw ?? this.deviceYaw,
        photoOrientation: photoOrientation ?? this.photoOrientation,
        cameraTiltAngle: cameraTiltAngle ?? this.cameraTiltAngle,
        source: source ?? this.source,
      );
}
