import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/models/voice_note.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/photo_storage_service.dart';
import 'package:obsession_tracker/core/services/voice_recording_service.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Aggregated media content for a waypoint
@immutable
class WaypointMedia {
  const WaypointMedia({
    this.photos = const <PhotoWaypoint>[],
    this.voiceNotes = const <VoiceNote>[],
  });

  /// All photos attached to this waypoint
  final List<PhotoWaypoint> photos;

  /// All voice notes attached to this waypoint
  final List<VoiceNote> voiceNotes;

  /// Whether this waypoint has any media attachments
  bool get hasAnyMedia => photos.isNotEmpty || voiceNotes.isNotEmpty;

  /// Total count of all media attachments
  int get totalCount => photos.length + voiceNotes.length;

  /// Whether this waypoint has photos
  bool get hasPhotos => photos.isNotEmpty;

  /// Whether this waypoint has voice notes
  bool get hasVoiceNotes => voiceNotes.isNotEmpty;

  /// Get the first photo (for thumbnail display)
  PhotoWaypoint? get primaryPhoto => photos.isNotEmpty ? photos.first : null;

  /// Get the first voice note
  VoiceNote? get primaryVoiceNote =>
      voiceNotes.isNotEmpty ? voiceNotes.first : null;

  WaypointMedia copyWith({
    List<PhotoWaypoint>? photos,
    List<VoiceNote>? voiceNotes,
  }) =>
      WaypointMedia(
        photos: photos ?? this.photos,
        voiceNotes: voiceNotes ?? this.voiceNotes,
      );

  /// Create an empty WaypointMedia
  static const WaypointMedia empty = WaypointMedia();
}

/// Service for managing media attachments (photos, voice notes) on waypoints.
///
/// This service provides a unified interface for:
/// - Adding multiple photos to a single waypoint
/// - Adding multiple voice notes to a single waypoint
/// - Retrieving all media for a waypoint
/// - Deleting individual media attachments
///
/// Unlike the existing PhotoCaptureService which creates waypoints along with
/// photos, this service works with existing waypoints to add media attachments.
class WaypointMediaService {
  factory WaypointMediaService() => _instance ??= WaypointMediaService._();
  WaypointMediaService._();
  static WaypointMediaService? _instance;

  static const Uuid _uuid = Uuid();

  final DatabaseService _databaseService = DatabaseService();
  final PhotoStorageService _photoStorageService = PhotoStorageService();
  final VoiceRecordingService _voiceRecordingService = VoiceRecordingService();

  // MARK: - Private Helpers

  /// Delete a file at the given path
  Future<void> _deleteFileAtPath(String filePath) async {
    try {
      final File file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Deleted file: $filePath');
      }
    } catch (e) {
      debugPrint('Error deleting file at $filePath: $e');
    }
  }

  // MARK: - Photo Operations

  /// Add a photo to an existing waypoint
  ///
  /// This creates a PhotoWaypoint record linking the photo to the waypoint.
  /// The photo data should already be saved to storage.
  Future<PhotoWaypoint?> addPhotoToWaypoint({
    required String waypointId,
    required String filePath,
    required int fileSize,
    int? width,
    int? height,
    double? devicePitch,
    double? deviceRoll,
    double? deviceYaw,
    String? photoOrientation,
    double? cameraTiltAngle,
    String? source,
    String? thumbnailPath,
  }) async {
    try {
      final String photoId = _uuid.v4();
      final DateTime now = DateTime.now();

      final PhotoWaypoint photoWaypoint = PhotoWaypoint(
        id: photoId,
        waypointId: waypointId,
        filePath: filePath,
        createdAt: now,
        fileSize: fileSize,
        width: width,
        height: height,
        devicePitch: devicePitch,
        deviceRoll: deviceRoll,
        deviceYaw: deviceYaw,
        photoOrientation: photoOrientation,
        cameraTiltAngle: cameraTiltAngle,
        source: source,
        thumbnailPath: thumbnailPath,
      );

      final Database db = await _databaseService.database;
      await db.insert(
        'photo_waypoints',
        photoWaypoint.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('Added photo $photoId to waypoint $waypointId');
      return photoWaypoint;
    } catch (e) {
      debugPrint('Error adding photo to waypoint: $e');
      return null;
    }
  }

  /// Add a photo from captured bytes to an existing waypoint
  ///
  /// This handles saving the photo to storage and creating the database record.
  Future<PhotoWaypoint?> addPhotoFromBytes({
    required String waypointId,
    required String sessionId,
    required Uint8List photoData,
    int? width,
    int? height,
    double? devicePitch,
    double? deviceRoll,
    double? deviceYaw,
    String? source,
  }) async {
    try {
      // Save photo to storage
      final String filePath = await _photoStorageService.storePhoto(
        sessionId: sessionId,
        photoData: photoData,
      );

      // Determine orientation from device roll if available
      String? photoOrientation;
      if (deviceRoll != null) {
        final absRoll = deviceRoll.abs();
        if (absRoll > 45 && absRoll < 135) {
          photoOrientation = 'landscape';
        } else {
          photoOrientation = 'portrait';
        }
      } else if (width != null && height != null) {
        if (width > height) {
          photoOrientation = 'landscape';
        } else if (height > width) {
          photoOrientation = 'portrait';
        } else {
          photoOrientation = 'square';
        }
      }

      // Calculate camera tilt angle
      double? cameraTiltAngle;
      if (devicePitch != null && deviceRoll != null) {
        cameraTiltAngle = devicePitch * devicePitch + deviceRoll * deviceRoll;
        cameraTiltAngle =
            cameraTiltAngle > 0 ? cameraTiltAngle * 0.5 : cameraTiltAngle;
      }

      return addPhotoToWaypoint(
        waypointId: waypointId,
        filePath: filePath,
        fileSize: photoData.length,
        width: width,
        height: height,
        devicePitch: devicePitch,
        deviceRoll: deviceRoll,
        deviceYaw: deviceYaw,
        photoOrientation: photoOrientation,
        cameraTiltAngle: cameraTiltAngle,
        source: source,
      );
    } catch (e) {
      debugPrint('Error adding photo from bytes: $e');
      return null;
    }
  }

  /// Get all photos for a waypoint
  Future<List<PhotoWaypoint>> getPhotosForWaypoint(String waypointId) async {
    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'photo_waypoints',
        where: 'waypoint_id = ?',
        whereArgs: <Object?>[waypointId],
        orderBy: 'created_at ASC',
      );

      return maps.map(PhotoWaypoint.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting photos for waypoint: $e');
      return <PhotoWaypoint>[];
    }
  }

  /// Delete a photo attachment
  ///
  /// This removes the photo from the database and optionally deletes the file.
  Future<bool> deletePhoto(String photoId, {bool deleteFile = true}) async {
    try {
      final Database db = await _databaseService.database;

      // Get photo info for file deletion
      if (deleteFile) {
        final List<Map<String, dynamic>> photos = await db.query(
          'photo_waypoints',
          where: 'id = ?',
          whereArgs: <Object?>[photoId],
        );

        if (photos.isNotEmpty) {
          final PhotoWaypoint photo = PhotoWaypoint.fromMap(photos.first);
          // Delete photo file directly since we have the path
          // We can't use PhotoStorageService.deletePhoto as it requires sessionId
          // which is not stored on PhotoWaypoint
          await _deleteFileAtPath(photo.filePath);
          if (photo.thumbnailPath != null) {
            await _deleteFileAtPath(photo.thumbnailPath!);
          }
        }
      }

      // Delete from database
      await db.delete(
        'photo_waypoints',
        where: 'id = ?',
        whereArgs: <Object?>[photoId],
      );

      // Also delete associated metadata
      await db.delete(
        'photo_metadata',
        where: 'photo_waypoint_id = ?',
        whereArgs: <Object?>[photoId],
      );

      debugPrint('Deleted photo $photoId');
      return true;
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      return false;
    }
  }

  // MARK: - Voice Note Operations

  /// Add a voice note to an existing waypoint
  ///
  /// This creates a VoiceNote record linking the voice note to the waypoint.
  Future<VoiceNote?> addVoiceNoteToWaypoint({
    required String waypointId,
    required String filePath,
    required int duration,
    required int fileSize,
    String? transcription,
  }) async {
    try {
      final String voiceNoteId = _uuid.v4();
      final DateTime now = DateTime.now();

      final VoiceNote voiceNote = VoiceNote(
        id: voiceNoteId,
        waypointId: waypointId,
        filePath: filePath,
        duration: duration,
        fileSize: fileSize,
        createdAt: now,
        transcription: transcription,
      );

      await _databaseService.insertVoiceNote(voiceNote);

      debugPrint('Added voice note $voiceNoteId to waypoint $waypointId');
      return voiceNote;
    } catch (e) {
      debugPrint('Error adding voice note to waypoint: $e');
      return null;
    }
  }

  /// Add a voice note from a recording result
  Future<VoiceNote?> addVoiceNoteFromRecording({
    required String waypointId,
    required VoiceRecordingResult recordingResult,
  }) async {
    if (!recordingResult.success || recordingResult.filePath == null) {
      debugPrint('Cannot add voice note: recording was not successful');
      return null;
    }

    return addVoiceNoteToWaypoint(
      waypointId: waypointId,
      filePath: recordingResult.filePath!,
      duration: recordingResult.duration,
      fileSize: recordingResult.fileSize,
    );
  }

  /// Get all voice notes for a waypoint
  Future<List<VoiceNote>> getVoiceNotesForWaypoint(String waypointId) async {
    try {
      return await _databaseService.getVoiceNotesForWaypoint(waypointId);
    } catch (e) {
      debugPrint('Error getting voice notes for waypoint: $e');
      return <VoiceNote>[];
    }
  }

  /// Delete a voice note attachment
  ///
  /// This removes the voice note from the database and deletes the file.
  Future<bool> deleteVoiceNote(String voiceNoteId,
      {bool deleteFile = true}) async {
    try {
      // Get voice note info for file deletion
      if (deleteFile) {
        final VoiceNote? voiceNote =
            await _databaseService.getVoiceNote(voiceNoteId);

        if (voiceNote != null) {
          await _voiceRecordingService.deleteVoiceNoteFile(voiceNote.filePath);
        }
      }

      // Delete from database
      await _databaseService.deleteVoiceNote(voiceNoteId);

      debugPrint('Deleted voice note $voiceNoteId');
      return true;
    } catch (e) {
      debugPrint('Error deleting voice note: $e');
      return false;
    }
  }

  // MARK: - Combined Media Operations

  /// Get all media (photos and voice notes) for a waypoint
  Future<WaypointMedia> getMediaForWaypoint(String waypointId) async {
    try {
      final List<PhotoWaypoint> photos =
          await getPhotosForWaypoint(waypointId);
      final List<VoiceNote> voiceNotes =
          await getVoiceNotesForWaypoint(waypointId);

      return WaypointMedia(
        photos: photos,
        voiceNotes: voiceNotes,
      );
    } catch (e) {
      debugPrint('Error getting media for waypoint: $e');
      return WaypointMedia.empty;
    }
  }

  /// Get media for multiple waypoints efficiently
  ///
  /// Returns a map of waypointId -> WaypointMedia
  Future<Map<String, WaypointMedia>> getMediaForWaypoints(
      List<String> waypointIds) async {
    if (waypointIds.isEmpty) {
      return <String, WaypointMedia>{};
    }

    try {
      final Database db = await _databaseService.database;

      // Batch query photos
      final String placeholders =
          List<String>.filled(waypointIds.length, '?').join(',');
      final List<Map<String, dynamic>> photoMaps = await db.query(
        'photo_waypoints',
        where: 'waypoint_id IN ($placeholders)',
        whereArgs: waypointIds,
        orderBy: 'created_at ASC',
      );

      // Batch query voice notes
      final List<Map<String, dynamic>> voiceNoteMaps = await db.query(
        'voice_notes',
        where: 'waypoint_id IN ($placeholders)',
        whereArgs: waypointIds,
        orderBy: 'created_at ASC',
      );

      // Group by waypoint ID
      final Map<String, List<PhotoWaypoint>> photosByWaypoint =
          <String, List<PhotoWaypoint>>{};
      final Map<String, List<VoiceNote>> voiceNotesByWaypoint =
          <String, List<VoiceNote>>{};

      for (final Map<String, dynamic> map in photoMaps) {
        final PhotoWaypoint photo = PhotoWaypoint.fromMap(map);
        photosByWaypoint.putIfAbsent(photo.waypointId, () => <PhotoWaypoint>[]);
        photosByWaypoint[photo.waypointId]!.add(photo);
      }

      for (final Map<String, dynamic> map in voiceNoteMaps) {
        final VoiceNote voiceNote = VoiceNote.fromMap(map);
        voiceNotesByWaypoint.putIfAbsent(
            voiceNote.waypointId, () => <VoiceNote>[]);
        voiceNotesByWaypoint[voiceNote.waypointId]!.add(voiceNote);
      }

      // Build result map
      final Map<String, WaypointMedia> result = <String, WaypointMedia>{};
      for (final String waypointId in waypointIds) {
        result[waypointId] = WaypointMedia(
          photos: photosByWaypoint[waypointId] ?? <PhotoWaypoint>[],
          voiceNotes: voiceNotesByWaypoint[waypointId] ?? <VoiceNote>[],
        );
      }

      return result;
    } catch (e) {
      debugPrint('Error getting media for waypoints: $e');
      return <String, WaypointMedia>{};
    }
  }

  /// Delete all media for a waypoint
  ///
  /// This is useful when deleting a waypoint entirely.
  Future<bool> deleteAllMediaForWaypoint(String waypointId) async {
    try {
      final WaypointMedia media = await getMediaForWaypoint(waypointId);

      // Delete all photos
      for (final PhotoWaypoint photo in media.photos) {
        await deletePhoto(photo.id);
      }

      // Delete all voice notes
      for (final VoiceNote voiceNote in media.voiceNotes) {
        await deleteVoiceNote(voiceNote.id);
      }

      debugPrint('Deleted all media for waypoint $waypointId');
      return true;
    } catch (e) {
      debugPrint('Error deleting all media for waypoint: $e');
      return false;
    }
  }

  /// Check if a waypoint has any media attachments
  Future<bool> waypointHasMedia(String waypointId) async {
    try {
      final Database db = await _databaseService.database;

      // Check for photos
      final List<Map<String, dynamic>> photos = await db.query(
        'photo_waypoints',
        columns: <String>['id'],
        where: 'waypoint_id = ?',
        whereArgs: <Object?>[waypointId],
        limit: 1,
      );

      if (photos.isNotEmpty) return true;

      // Check for voice notes
      final List<Map<String, dynamic>> voiceNotes = await db.query(
        'voice_notes',
        columns: <String>['id'],
        where: 'waypoint_id = ?',
        whereArgs: <Object?>[waypointId],
        limit: 1,
      );

      return voiceNotes.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if waypoint has media: $e');
      return false;
    }
  }

  /// Get media counts for a waypoint (efficient for UI display)
  Future<({int photoCount, int voiceNoteCount})> getMediaCounts(
      String waypointId) async {
    try {
      final Database db = await _databaseService.database;

      final List<Map<String, dynamic>> photoResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM photo_waypoints WHERE waypoint_id = ?',
        <Object?>[waypointId],
      );

      final List<Map<String, dynamic>> voiceResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM voice_notes WHERE waypoint_id = ?',
        <Object?>[waypointId],
      );

      final int photoCount = photoResult.first['count'] as int? ?? 0;
      final int voiceNoteCount = voiceResult.first['count'] as int? ?? 0;

      return (photoCount: photoCount, voiceNoteCount: voiceNoteCount);
    } catch (e) {
      debugPrint('Error getting media counts: $e');
      return (photoCount: 0, voiceNoteCount: 0);
    }
  }
}
