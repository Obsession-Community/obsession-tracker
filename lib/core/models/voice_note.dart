import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/services/hunt_path_resolver.dart';

/// A voice note representing an audio recording associated with a waypoint.
///
/// Contains file paths, metadata, and creation information for voice recordings
/// taken at waypoint locations during adventures.
@immutable
class VoiceNote {
  const VoiceNote({
    required this.id,
    required this.waypointId,
    required this.filePath,
    required this.createdAt,
    required this.fileSize,
    required this.duration,
    this.transcription,
  });

  /// Create a voice note from database map
  ///
  /// Resolves relative file paths to absolute paths using [HuntPathResolver].
  factory VoiceNote.fromMap(Map<String, dynamic> map) => VoiceNote(
        id: map['id'] as String,
        waypointId: map['waypoint_id'] as String,
        // Resolve relative paths to absolute for filesystem access
        filePath: HuntPathResolver.resolveFromDatabase(
              map['file_path'] as String?,
            ) ??
            '',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        fileSize: map['file_size'] as int,
        duration: map['duration'] as int,
        transcription: map['transcription'] as String?,
      );

  /// Unique identifier for this voice note
  final String id;

  /// ID of the waypoint this voice note is associated with
  final String waypointId;

  /// Full path to the audio file
  final String filePath;

  /// When this voice note was created
  final DateTime createdAt;

  /// File size in bytes
  final int fileSize;

  /// Duration of the recording in milliseconds
  final int duration;

  /// Optional transcription of the voice note
  final String? transcription;

  /// Convert voice note to map for database storage
  ///
  /// Converts absolute file paths to relative paths for portability using [HuntPathResolver].
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'waypoint_id': waypointId,
        // Store relative paths for portability across iOS container changes
        'file_path': HuntPathResolver.prepareForDatabase(filePath),
        'created_at': createdAt.millisecondsSinceEpoch,
        'file_size': fileSize,
        'duration': duration,
        'transcription': transcription,
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

  /// Get human-readable duration
  String get durationFormatted {
    final int seconds = (duration / 1000).round();
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;

    if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    } else {
      return '${remainingSeconds}s';
    }
  }

  /// Get duration in seconds as double
  double get durationInSeconds => duration / 1000.0;

  /// Check if this voice note has a transcription
  bool get hasTranscription =>
      transcription != null && transcription!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceNote && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'VoiceNote{id: $id, waypointId: $waypointId, filePath: $filePath, duration: $durationFormatted, fileSize: $fileSizeFormatted}';

  /// Create a copy of this voice note with updated values
  VoiceNote copyWith({
    String? id,
    String? waypointId,
    String? filePath,
    DateTime? createdAt,
    int? fileSize,
    int? duration,
    String? transcription,
  }) =>
      VoiceNote(
        id: id ?? this.id,
        waypointId: waypointId ?? this.waypointId,
        filePath: filePath ?? this.filePath,
        createdAt: createdAt ?? this.createdAt,
        fileSize: fileSize ?? this.fileSize,
        duration: duration ?? this.duration,
        transcription: transcription ?? this.transcription,
      );
}
