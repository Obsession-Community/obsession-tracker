import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/models/voice_note.dart';
import 'package:obsession_tracker/core/services/voice_recording_service.dart';
import 'package:obsession_tracker/core/services/waypoint_media_service.dart';
import 'package:uuid/uuid.dart';

/// Represents a photo that hasn't been saved yet (during waypoint creation)
@immutable
class PendingPhoto {
  const PendingPhoto({
    required this.id,
    required this.photoData,
    required this.createdAt,
    this.width,
    this.height,
    this.devicePitch,
    this.deviceRoll,
    this.deviceYaw,
  });

  /// Temporary ID for tracking during creation
  final String id;

  /// Raw photo bytes (not yet saved to storage)
  final Uint8List photoData;

  /// When this photo was captured
  final DateTime createdAt;

  /// Image dimensions
  final int? width;
  final int? height;

  /// Device orientation data
  final double? devicePitch;
  final double? deviceRoll;
  final double? deviceYaw;

  /// File size in bytes
  int get fileSize => photoData.length;
}

/// Represents a voice note that hasn't been saved yet (during waypoint creation)
@immutable
class PendingVoiceNote {
  const PendingVoiceNote({
    required this.id,
    required this.filePath,
    required this.duration,
    required this.fileSize,
    required this.createdAt,
  });

  /// Create from a recording result
  factory PendingVoiceNote.fromRecordingResult(VoiceRecordingResult result) {
    return PendingVoiceNote(
      id: const Uuid().v4(),
      filePath: result.filePath!,
      duration: result.duration,
      fileSize: result.fileSize,
      createdAt: DateTime.now(),
    );
  }

  /// Temporary ID for tracking during creation
  final String id;

  /// Path to the recorded audio file
  final String filePath;

  /// Duration in milliseconds
  final int duration;

  /// File size in bytes
  final int fileSize;

  /// When this voice note was recorded
  final DateTime createdAt;

  /// Get formatted duration string
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
}

/// State for managing pending media during waypoint creation
@immutable
class WaypointMediaState {
  const WaypointMediaState({
    this.pendingPhotos = const <PendingPhoto>[],
    this.pendingVoiceNotes = const <PendingVoiceNote>[],
    this.savedPhotos = const <PhotoWaypoint>[],
    this.savedVoiceNotes = const <VoiceNote>[],
    this.isSaving = false,
    this.error,
  });

  /// Photos captured but not yet saved to database
  final List<PendingPhoto> pendingPhotos;

  /// Voice notes recorded but not yet saved to database
  final List<PendingVoiceNote> pendingVoiceNotes;

  /// Photos that have been saved (when editing existing waypoint)
  final List<PhotoWaypoint> savedPhotos;

  /// Voice notes that have been saved (when editing existing waypoint)
  final List<VoiceNote> savedVoiceNotes;

  /// Whether media is currently being saved
  final bool isSaving;

  /// Error message if save failed
  final String? error;

  /// Total pending media count
  int get pendingCount => pendingPhotos.length + pendingVoiceNotes.length;

  /// Total saved media count
  int get savedCount => savedPhotos.length + savedVoiceNotes.length;

  /// Total media count (pending + saved)
  int get totalCount => pendingCount + savedCount;

  /// Whether there is any media (pending or saved)
  bool get hasAnyMedia => totalCount > 0;

  /// Whether there are any pending items to save
  bool get hasPendingMedia => pendingCount > 0;

  /// Whether there are any photos (pending or saved)
  bool get hasPhotos => pendingPhotos.isNotEmpty || savedPhotos.isNotEmpty;

  /// Whether there are any voice notes (pending or saved)
  bool get hasVoiceNotes =>
      pendingVoiceNotes.isNotEmpty || savedVoiceNotes.isNotEmpty;

  WaypointMediaState copyWith({
    List<PendingPhoto>? pendingPhotos,
    List<PendingVoiceNote>? pendingVoiceNotes,
    List<PhotoWaypoint>? savedPhotos,
    List<VoiceNote>? savedVoiceNotes,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) =>
      WaypointMediaState(
        pendingPhotos: pendingPhotos ?? this.pendingPhotos,
        pendingVoiceNotes: pendingVoiceNotes ?? this.pendingVoiceNotes,
        savedPhotos: savedPhotos ?? this.savedPhotos,
        savedVoiceNotes: savedVoiceNotes ?? this.savedVoiceNotes,
        isSaving: isSaving ?? this.isSaving,
        error: clearError ? null : (error ?? this.error),
      );

  /// Create an empty state
  static const WaypointMediaState empty = WaypointMediaState();
}

/// Notifier for managing waypoint media state during creation/editing
class WaypointMediaNotifier extends Notifier<WaypointMediaState> {
  static const Uuid _uuid = Uuid();

  WaypointMediaService get _mediaService => ref.read(waypointMediaServiceProvider);
  VoiceRecordingService get _voiceRecordingService =>
      ref.read(voiceRecordingServiceProvider);

  @override
  WaypointMediaState build() {
    return WaypointMediaState.empty;
  }

  // MARK: - Initialization

  /// Start a new waypoint creation (clear all pending media)
  void startNewWaypoint() {
    state = WaypointMediaState.empty;
    debugPrint('Started new waypoint media session');
  }

  /// Load existing media for editing an existing waypoint
  Future<void> loadExistingMedia(String waypointId) async {
    try {
      final WaypointMedia media =
          await _mediaService.getMediaForWaypoint(waypointId);

      state = state.copyWith(
        savedPhotos: media.photos,
        savedVoiceNotes: media.voiceNotes,
        pendingPhotos: <PendingPhoto>[],
        pendingVoiceNotes: <PendingVoiceNote>[],
      );

      debugPrint(
          'Loaded existing media for waypoint $waypointId: ${media.photos.length} photos, ${media.voiceNotes.length} voice notes');
    } catch (e) {
      debugPrint('Error loading existing media: $e');
      state = state.copyWith(error: 'Failed to load existing media');
    }
  }

  // MARK: - Photo Operations

  /// Add a pending photo from captured bytes
  void addPendingPhoto({
    required Uint8List photoData,
    int? width,
    int? height,
    double? devicePitch,
    double? deviceRoll,
    double? deviceYaw,
  }) {
    final PendingPhoto pendingPhoto = PendingPhoto(
      id: _uuid.v4(),
      photoData: photoData,
      createdAt: DateTime.now(),
      width: width,
      height: height,
      devicePitch: devicePitch,
      deviceRoll: deviceRoll,
      deviceYaw: deviceYaw,
    );

    state = state.copyWith(
      pendingPhotos: [...state.pendingPhotos, pendingPhoto],
      clearError: true,
    );

    debugPrint('Added pending photo ${pendingPhoto.id}');
  }

  /// Remove a pending photo
  void removePendingPhoto(String photoId) {
    state = state.copyWith(
      pendingPhotos: state.pendingPhotos
          .where((photo) => photo.id != photoId)
          .toList(),
    );
    debugPrint('Removed pending photo $photoId');
  }

  /// Remove a saved photo (marks for deletion on save)
  Future<bool> removeSavedPhoto(String photoId) async {
    try {
      final bool success = await _mediaService.deletePhoto(photoId);

      if (success) {
        state = state.copyWith(
          savedPhotos: state.savedPhotos
              .where((photo) => photo.id != photoId)
              .toList(),
        );
        debugPrint('Removed saved photo $photoId');
      }

      return success;
    } catch (e) {
      debugPrint('Error removing saved photo: $e');
      state = state.copyWith(error: 'Failed to delete photo');
      return false;
    }
  }

  // MARK: - Voice Note Operations

  /// Add a pending voice note from a recording result
  void addPendingVoiceNote(VoiceRecordingResult recordingResult) {
    if (!recordingResult.success || recordingResult.filePath == null) {
      debugPrint('Cannot add pending voice note: recording was not successful');
      return;
    }

    final PendingVoiceNote pendingVoiceNote =
        PendingVoiceNote.fromRecordingResult(recordingResult);

    state = state.copyWith(
      pendingVoiceNotes: [...state.pendingVoiceNotes, pendingVoiceNote],
      clearError: true,
    );

    debugPrint('Added pending voice note ${pendingVoiceNote.id}');
  }

  /// Remove a pending voice note (also deletes the file)
  Future<void> removePendingVoiceNote(String voiceNoteId) async {
    final PendingVoiceNote? voiceNote = state.pendingVoiceNotes
        .cast<PendingVoiceNote?>()
        .firstWhere((vn) => vn?.id == voiceNoteId, orElse: () => null);

    if (voiceNote != null) {
      // Delete the file
      await _voiceRecordingService.deleteVoiceNoteFile(voiceNote.filePath);
    }

    state = state.copyWith(
      pendingVoiceNotes: state.pendingVoiceNotes
          .where((vn) => vn.id != voiceNoteId)
          .toList(),
    );

    debugPrint('Removed pending voice note $voiceNoteId');
  }

  /// Remove a saved voice note
  Future<bool> removeSavedVoiceNote(String voiceNoteId) async {
    try {
      final bool success = await _mediaService.deleteVoiceNote(voiceNoteId);

      if (success) {
        state = state.copyWith(
          savedVoiceNotes: state.savedVoiceNotes
              .where((vn) => vn.id != voiceNoteId)
              .toList(),
        );
        debugPrint('Removed saved voice note $voiceNoteId');
      }

      return success;
    } catch (e) {
      debugPrint('Error removing saved voice note: $e');
      state = state.copyWith(error: 'Failed to delete voice note');
      return false;
    }
  }

  // MARK: - Save Operations

  /// Save all pending media to a waypoint
  ///
  /// This should be called after the waypoint has been created.
  /// Returns true if all media was saved successfully.
  Future<bool> saveAllMedia({
    required String waypointId,
    required String sessionId,
  }) async {
    if (!state.hasPendingMedia) {
      debugPrint('No pending media to save');
      return true;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final List<PhotoWaypoint> savedPhotos = List<PhotoWaypoint>.from(state.savedPhotos);
      final List<VoiceNote> savedVoiceNotes = List<VoiceNote>.from(state.savedVoiceNotes);

      // Save all pending photos
      for (final PendingPhoto pendingPhoto in state.pendingPhotos) {
        final PhotoWaypoint? saved = await _mediaService.addPhotoFromBytes(
          waypointId: waypointId,
          sessionId: sessionId,
          photoData: pendingPhoto.photoData,
          width: pendingPhoto.width,
          height: pendingPhoto.height,
          devicePitch: pendingPhoto.devicePitch,
          deviceRoll: pendingPhoto.deviceRoll,
          deviceYaw: pendingPhoto.deviceYaw,
        );

        if (saved != null) {
          savedPhotos.add(saved);
        } else {
          throw Exception('Failed to save photo');
        }
      }

      // Save all pending voice notes
      for (final PendingVoiceNote pendingVoiceNote in state.pendingVoiceNotes) {
        final VoiceNote? saved = await _mediaService.addVoiceNoteToWaypoint(
          waypointId: waypointId,
          filePath: pendingVoiceNote.filePath,
          duration: pendingVoiceNote.duration,
          fileSize: pendingVoiceNote.fileSize,
        );

        if (saved != null) {
          savedVoiceNotes.add(saved);
        } else {
          throw Exception('Failed to save voice note');
        }
      }

      // Update state - move pending to saved
      state = state.copyWith(
        pendingPhotos: <PendingPhoto>[],
        pendingVoiceNotes: <PendingVoiceNote>[],
        savedPhotos: savedPhotos,
        savedVoiceNotes: savedVoiceNotes,
        isSaving: false,
      );

      debugPrint('Saved all media to waypoint $waypointId');
      return true;
    } catch (e) {
      debugPrint('Error saving media: $e');
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to save some media: $e',
      );
      return false;
    }
  }

  // MARK: - Cleanup

  /// Cancel and clean up all pending media (delete files, clear state)
  Future<void> cancelAndCleanup() async {
    // Delete pending voice note files
    for (final PendingVoiceNote voiceNote in state.pendingVoiceNotes) {
      try {
        await _voiceRecordingService.deleteVoiceNoteFile(voiceNote.filePath);
      } catch (e) {
        debugPrint('Error deleting pending voice note file: $e');
      }
    }

    // Clear state
    state = WaypointMediaState.empty;
    debugPrint('Cancelled and cleaned up pending media');
  }

  /// Clear any error
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// MARK: - Providers

/// Provider for waypoint media service
final Provider<WaypointMediaService> waypointMediaServiceProvider =
    Provider<WaypointMediaService>((Ref ref) => WaypointMediaService());

/// Provider for voice recording service (re-export for convenience)
final Provider<VoiceRecordingService> voiceRecordingServiceProvider =
    Provider<VoiceRecordingService>((Ref ref) => VoiceRecordingService());

/// Provider for waypoint media state management
final NotifierProvider<WaypointMediaNotifier, WaypointMediaState>
    waypointMediaProvider =
    NotifierProvider<WaypointMediaNotifier, WaypointMediaState>(
        WaypointMediaNotifier.new);

/// Provider for checking if there is pending media
final Provider<bool> hasPendingMediaProvider = Provider<bool>((Ref ref) {
  final WaypointMediaState state = ref.watch(waypointMediaProvider);
  return state.hasPendingMedia;
});

/// Provider for total media count
final Provider<int> totalMediaCountProvider = Provider<int>((Ref ref) {
  final WaypointMediaState state = ref.watch(waypointMediaProvider);
  return state.totalCount;
});
