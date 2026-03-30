import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/voice_note.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/voice_playback_service.dart';
import 'package:obsession_tracker/core/services/voice_recording_service.dart';

/// State for voice note operations
@immutable
class VoiceNoteState {
  const VoiceNoteState({
    this.voiceNotes = const <VoiceNote>[],
    this.isLoading = false,
    this.error,
  });

  final List<VoiceNote> voiceNotes;
  final bool isLoading;
  final String? error;

  VoiceNoteState copyWith({
    List<VoiceNote>? voiceNotes,
    bool? isLoading,
    String? error,
  }) =>
      VoiceNoteState(
        voiceNotes: voiceNotes ?? this.voiceNotes,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

/// Voice note state notifier
class VoiceNoteNotifier extends Notifier<VoiceNoteState> {
  late final DatabaseService _databaseService;

  @override
  VoiceNoteState build() {
    _databaseService = DatabaseService();
    return const VoiceNoteState();
  }

  /// Load voice notes for a waypoint
  Future<void> loadVoiceNotesForWaypoint(String waypointId) async {
    state = state.copyWith(isLoading: true);

    try {
      final List<VoiceNote> voiceNotes =
          await _databaseService.getVoiceNotesForWaypoint(waypointId);

      state = state.copyWith(
        voiceNotes: voiceNotes,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error loading voice notes for waypoint: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load voice notes: $e',
      );
    }
  }

  /// Load voice notes for a session
  Future<void> loadVoiceNotesForSession(String sessionId) async {
    state = state.copyWith(isLoading: true);

    try {
      final List<VoiceNote> voiceNotes =
          await _databaseService.getVoiceNotesForSession(sessionId);

      state = state.copyWith(
        voiceNotes: voiceNotes,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error loading voice notes for session: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load voice notes: $e',
      );
    }
  }

  /// Add a new voice note
  Future<bool> addVoiceNote(VoiceNote voiceNote) async {
    try {
      await _databaseService.insertVoiceNote(voiceNote);

      // Add to current state
      final List<VoiceNote> updatedVoiceNotes = [
        ...state.voiceNotes,
        voiceNote
      ];
      state = state.copyWith(voiceNotes: updatedVoiceNotes);

      return true;
    } catch (e) {
      debugPrint('Error adding voice note: $e');
      state = state.copyWith(error: 'Failed to add voice note: $e');
      return false;
    }
  }

  /// Update a voice note
  Future<bool> updateVoiceNote(VoiceNote voiceNote) async {
    try {
      await _databaseService.updateVoiceNote(voiceNote);

      // Update in current state
      final List<VoiceNote> updatedVoiceNotes = state.voiceNotes
          .map((vn) => vn.id == voiceNote.id ? voiceNote : vn)
          .toList();

      state = state.copyWith(voiceNotes: updatedVoiceNotes);

      return true;
    } catch (e) {
      debugPrint('Error updating voice note: $e');
      state = state.copyWith(error: 'Failed to update voice note: $e');
      return false;
    }
  }

  /// Delete a voice note
  Future<bool> deleteVoiceNote(String voiceNoteId) async {
    try {
      // Find the voice note to get file path
      final VoiceNote? voiceNote =
          state.voiceNotes.where((vn) => vn.id == voiceNoteId).firstOrNull;

      if (voiceNote != null) {
        // Delete file first
        final VoiceRecordingService recordingService = VoiceRecordingService();
        await recordingService.deleteVoiceNoteFile(voiceNote.filePath);
      }

      // Delete from database
      await _databaseService.deleteVoiceNote(voiceNoteId);

      // Remove from current state
      final List<VoiceNote> updatedVoiceNotes =
          state.voiceNotes.where((vn) => vn.id != voiceNoteId).toList();

      state = state.copyWith(voiceNotes: updatedVoiceNotes);

      return true;
    } catch (e) {
      debugPrint('Error deleting voice note: $e');
      state = state.copyWith(error: 'Failed to delete voice note: $e');
      return false;
    }
  }

  /// Clear current voice notes
  void clearVoiceNotes() {
    state = const VoiceNoteState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith();
  }
}

/// State for voice recording operations
@immutable
class VoiceRecordingState {
  const VoiceRecordingState({
    this.isRecording = false,
    this.recordingDuration = 0,
    this.remainingTime = VoiceRecordingService.maxRecordingDurationMs,
    this.hasPermission = false,
    this.error,
  });

  final bool isRecording;
  final int recordingDuration; // in milliseconds
  final int remainingTime; // in milliseconds
  final bool hasPermission;
  final String? error;

  VoiceRecordingState copyWith({
    bool? isRecording,
    int? recordingDuration,
    int? remainingTime,
    bool? hasPermission,
    String? error,
  }) =>
      VoiceRecordingState(
        isRecording: isRecording ?? this.isRecording,
        recordingDuration: recordingDuration ?? this.recordingDuration,
        remainingTime: remainingTime ?? this.remainingTime,
        hasPermission: hasPermission ?? this.hasPermission,
        error: error,
      );
}

/// Voice recording state notifier
class VoiceRecordingNotifier extends Notifier<VoiceRecordingState> {
  late final VoiceRecordingService _recordingService;

  @override
  VoiceRecordingState build() {
    _recordingService = VoiceRecordingService();
    _checkPermission();
    return const VoiceRecordingState();
  }

  /// Check microphone permission
  Future<void> _checkPermission() async {
    final bool hasPermission = await _recordingService.hasPermission();
    state = state.copyWith(hasPermission: hasPermission);
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final bool granted = await _recordingService.requestPermission();
    state = state.copyWith(hasPermission: granted);
    return granted;
  }

  /// Start recording
  Future<bool> startRecording() async {
    if (!state.hasPermission) {
      if (!await requestPermission()) {
        state = state.copyWith(error: 'Microphone permission required');
        return false;
      }
    }

    final bool success = await _recordingService.startRecording();
    if (success) {
      state = state.copyWith(
        isRecording: true,
        recordingDuration: 0,
        remainingTime: VoiceRecordingService.maxRecordingDurationMs,
      );
    } else {
      state = state.copyWith(error: 'Failed to start recording');
    }

    return success;
  }

  /// Stop recording
  Future<VoiceRecordingResult> stopRecording() async {
    final VoiceRecordingResult result = await _recordingService.stopRecording();

    state = state.copyWith(
      isRecording: false,
      recordingDuration: 0,
      remainingTime: VoiceRecordingService.maxRecordingDurationMs,
      error: result.success ? null : result.error,
    );

    return result;
  }

  /// Cancel recording
  Future<void> cancelRecording() async {
    await _recordingService.cancelRecording();

    state = state.copyWith(
      isRecording: false,
      recordingDuration: 0,
      remainingTime: VoiceRecordingService.maxRecordingDurationMs,
    );
  }

  /// Update recording progress
  void updateProgress() {
    if (state.isRecording) {
      final int duration = _recordingService.currentRecordingDuration;
      final int remaining = _recordingService.remainingRecordingTime;

      state = state.copyWith(
        recordingDuration: duration,
        remainingTime: remaining,
      );
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith();
  }
}

/// Providers

/// Database service provider
final databaseServiceProvider =
    Provider<DatabaseService>((ref) => DatabaseService());

/// Voice recording service provider
final voiceRecordingServiceProvider =
    Provider<VoiceRecordingService>((ref) => VoiceRecordingService());

/// Voice playback service provider
final voicePlaybackServiceProvider =
    Provider<VoicePlaybackService>((ref) => VoicePlaybackService());

/// Voice note state provider
final voiceNoteProvider =
    NotifierProvider<VoiceNoteNotifier, VoiceNoteState>(
        VoiceNoteNotifier.new);

/// Voice recording state provider
final voiceRecordingProvider =
    NotifierProvider<VoiceRecordingNotifier, VoiceRecordingState>(
        VoiceRecordingNotifier.new);

/// Voice playback state stream provider
final voicePlaybackStateProvider = StreamProvider<VoicePlaybackState>((ref) {
  final VoicePlaybackService playbackService =
      ref.watch(voicePlaybackServiceProvider);
  return playbackService.stateStream;
});

/// Voice playback position stream provider
final voicePlaybackPositionProvider = StreamProvider<Duration>((ref) {
  final VoicePlaybackService playbackService =
      ref.watch(voicePlaybackServiceProvider);
  return playbackService.positionStream;
});

/// Current playing voice note stream provider
final currentPlayingVoiceNoteProvider = StreamProvider<VoiceNote?>((ref) {
  final VoicePlaybackService playbackService =
      ref.watch(voicePlaybackServiceProvider);
  return playbackService.currentVoiceNoteStream;
});
