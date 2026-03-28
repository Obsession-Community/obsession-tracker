import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/custom_marker.dart';
import 'package:obsession_tracker/core/models/marker_attachment.dart';

/// A unified model for media items in the session playback carousel.
///
/// Combines data from [MarkerAttachment] (image file info) with location
/// data from the parent [CustomMarker] for display in the photo carousel
/// during session playback.
@immutable
class PlaybackMedia {
  const PlaybackMedia({
    required this.id,
    required this.filePath,
    required this.createdAt,
    required this.latitude,
    required this.longitude,
    required this.markerId,
    this.thumbnailPath,
    this.markerName,
    this.markerCategory,
    this.attachmentName,
    this.userRotation,
  });

  /// Unique identifier (from MarkerAttachment.id)
  final String id;

  /// Absolute path to the image file
  final String filePath;

  /// When the attachment was created (used for timeline positioning)
  final DateTime createdAt;

  /// Geographic latitude from the parent CustomMarker
  final double latitude;

  /// Geographic longitude from the parent CustomMarker
  final double longitude;

  /// ID of the parent CustomMarker
  final String markerId;

  /// Optional thumbnail path for faster loading
  final String? thumbnailPath;

  /// Name of the parent CustomMarker
  final String? markerName;

  /// Category of the parent CustomMarker
  final CustomMarkerCategory? markerCategory;

  /// Name of the attachment (e.g., filename)
  final String? attachmentName;

  /// User-applied rotation in quarter turns (0=none, 1=90°CW, 2=180°, 3=270°CW)
  final int? userRotation;

  /// Factory to create PlaybackMedia from a MarkerAttachment and its parent CustomMarker.
  ///
  /// Returns null if the attachment doesn't have a valid file path (required for images).
  factory PlaybackMedia.fromMarkerAttachment(
    MarkerAttachment attachment,
    CustomMarker marker,
  ) {
    // Ensure attachment has a file path (required for image display)
    if (attachment.filePath == null || attachment.filePath!.isEmpty) {
      throw ArgumentError('MarkerAttachment must have a filePath for PlaybackMedia');
    }

    return PlaybackMedia(
      id: attachment.id,
      filePath: attachment.filePath!,
      createdAt: attachment.createdAt,
      latitude: marker.latitude,
      longitude: marker.longitude,
      markerId: marker.id,
      thumbnailPath: attachment.thumbnailPath,
      markerName: marker.name,
      markerCategory: marker.category,
      attachmentName: attachment.name,
      userRotation: attachment.userRotation,
    );
  }

  /// Try to create PlaybackMedia, returning null if attachment has no file path.
  static PlaybackMedia? tryFromMarkerAttachment(
    MarkerAttachment attachment,
    CustomMarker marker,
  ) {
    if (attachment.filePath == null || attachment.filePath!.isEmpty) {
      return null;
    }
    return PlaybackMedia.fromMarkerAttachment(attachment, marker);
  }

  /// Get the display path - prefers thumbnail for performance, falls back to full image
  String get displayPath => thumbnailPath ?? filePath;

  /// Check if this media has a separate thumbnail
  bool get hasThumbnail => thumbnailPath != null && thumbnailPath!.isNotEmpty;

  /// Get display name for the media item
  String get displayName => markerName ?? attachmentName ?? 'Photo';

  /// Get the category emoji if available
  String? get categoryEmoji => markerCategory?.emoji;

  /// Create a copy with updated values
  PlaybackMedia copyWith({
    String? id,
    String? filePath,
    DateTime? createdAt,
    double? latitude,
    double? longitude,
    String? markerId,
    String? thumbnailPath,
    String? markerName,
    CustomMarkerCategory? markerCategory,
    String? attachmentName,
    int? userRotation,
    bool clearThumbnailPath = false,
    bool clearMarkerName = false,
    bool clearMarkerCategory = false,
    bool clearAttachmentName = false,
    bool clearUserRotation = false,
  }) {
    return PlaybackMedia(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      markerId: markerId ?? this.markerId,
      thumbnailPath:
          clearThumbnailPath ? null : (thumbnailPath ?? this.thumbnailPath),
      markerName: clearMarkerName ? null : (markerName ?? this.markerName),
      markerCategory: clearMarkerCategory
          ? null
          : (markerCategory ?? this.markerCategory),
      attachmentName:
          clearAttachmentName ? null : (attachmentName ?? this.attachmentName),
      userRotation:
          clearUserRotation ? null : (userRotation ?? this.userRotation),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackMedia &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PlaybackMedia{id: $id, markerId: $markerId, markerName: $markerName, lat: $latitude, lng: $longitude}';
}
