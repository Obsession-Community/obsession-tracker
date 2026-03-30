import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:obsession_tracker/core/models/voice_note.dart';

/// Playback state for voice notes
enum VoicePlaybackState {
  stopped,
  playing,
  paused,
  loading,
  error,
}

/// Service for playing voice notes
class VoicePlaybackService {
  factory VoicePlaybackService() => _instance ??= VoicePlaybackService._();
  VoicePlaybackService._();
  static VoicePlaybackService? _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();
  VoiceNote? _currentVoiceNote;
  VoicePlaybackState _state = VoicePlaybackState.stopped;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration?>? _positionSubscription;

  // Stream controllers for state management
  final StreamController<VoicePlaybackState> _stateController =
      StreamController<VoicePlaybackState>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<VoiceNote?> _currentVoiceNoteController =
      StreamController<VoiceNote?>.broadcast();

  /// Stream of playback state changes
  Stream<VoicePlaybackState> get stateStream => _stateController.stream;

  /// Stream of playback position changes
  Stream<Duration> get positionStream => _positionController.stream;

  /// Stream of current voice note changes
  Stream<VoiceNote?> get currentVoiceNoteStream =>
      _currentVoiceNoteController.stream;

  /// Current playback state
  VoicePlaybackState get state => _state;

  /// Currently playing voice note
  VoiceNote? get currentVoiceNote => _currentVoiceNote;

  /// Current playback position
  Duration get position => _audioPlayer.position;

  /// Total duration of current voice note
  Duration? get duration => _audioPlayer.duration;

  /// Whether audio is currently playing
  bool get isPlaying => _state == VoicePlaybackState.playing;

  /// Whether audio is currently paused
  bool get isPaused => _state == VoicePlaybackState.paused;

  /// Whether audio is currently loading
  bool get isLoading => _state == VoicePlaybackState.loading;

  /// Initialize the service
  void _initialize() {
    // Listen to player state changes
    _playerStateSubscription =
        _audioPlayer.playerStateStream.listen(_updateStateFromPlayerState);

    // Listen to position changes
    _positionSubscription =
        _audioPlayer.positionStream.listen(_positionController.add);

    // Handle playback completion
    _audioPlayer.playerStateStream
        .where((state) => state.processingState == ProcessingState.completed)
        .listen((_) {
      _onPlaybackCompleted();
    });
  }

  /// Update internal state based on player state
  void _updateStateFromPlayerState(PlayerState playerState) {
    VoicePlaybackState newState;

    switch (playerState.processingState) {
      case ProcessingState.idle:
        newState = VoicePlaybackState.stopped;
        break;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        newState = VoicePlaybackState.loading;
        break;
      case ProcessingState.ready:
        newState = playerState.playing
            ? VoicePlaybackState.playing
            : VoicePlaybackState.paused;
        break;
      case ProcessingState.completed:
        newState = VoicePlaybackState.stopped;
        break;
    }

    if (newState != _state) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  /// Handle playback completion
  void _onPlaybackCompleted() {
    _state = VoicePlaybackState.stopped;
    _stateController.add(_state);

    // Reset to beginning
    _audioPlayer.seek(Duration.zero);
  }

  /// Play a voice note
  Future<bool> playVoiceNote(VoiceNote voiceNote) async {
    try {
      // Check if file exists
      final File audioFile = File(voiceNote.filePath);
      if (!audioFile.existsSync()) {
        debugPrint('Voice note file does not exist: ${voiceNote.filePath}');
        _state = VoicePlaybackState.error;
        _stateController.add(_state);
        return false;
      }

      // Initialize if not already done
      if (_playerStateSubscription == null) {
        _initialize();
      }

      // Stop current playback if playing different voice note
      if (_currentVoiceNote?.id != voiceNote.id) {
        await stop();
        _currentVoiceNote = voiceNote;
        _currentVoiceNoteController.add(_currentVoiceNote);
      }

      // Set audio source if not already set or if different voice note
      if (_audioPlayer.audioSource == null ||
          _currentVoiceNote?.id != voiceNote.id) {
        _state = VoicePlaybackState.loading;
        _stateController.add(_state);

        await _audioPlayer.setFilePath(voiceNote.filePath);
      }

      // Start playback
      await _audioPlayer.play();

      debugPrint('Started playing voice note: ${voiceNote.id}');
      return true;
    } catch (e) {
      debugPrint('Error playing voice note: $e');
      _state = VoicePlaybackState.error;
      _stateController.add(_state);
      return false;
    }
  }

  /// Pause playback
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      debugPrint('Paused voice note playback');
    } catch (e) {
      debugPrint('Error pausing voice note: $e');
    }
  }

  /// Resume playback
  Future<void> resume() async {
    try {
      await _audioPlayer.play();
      debugPrint('Resumed voice note playback');
    } catch (e) {
      debugPrint('Error resuming voice note: $e');
    }
  }

  /// Stop playback
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.seek(Duration.zero);
      _currentVoiceNote = null;
      _currentVoiceNoteController.add(null);
      debugPrint('Stopped voice note playback');
    } catch (e) {
      debugPrint('Error stopping voice note: $e');
    }
  }

  /// Seek to specific position
  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
      debugPrint('Seeked to position: ${position.inMilliseconds}ms');
    } catch (e) {
      debugPrint('Error seeking voice note: $e');
    }
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    try {
      await _audioPlayer.setSpeed(speed.clamp(0.25, 2.0));
      debugPrint('Set playback speed to: ${speed}x');
    } catch (e) {
      debugPrint('Error setting playback speed: $e');
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else if (isPaused) {
      await resume();
    }
  }

  /// Get formatted position string
  String getFormattedPosition() {
    final Duration pos = position;
    final int minutes = pos.inMinutes;
    final int seconds = pos.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted duration string
  String getFormattedDuration() {
    final Duration? dur = duration;
    if (dur == null) return '0:00';

    final int minutes = dur.inMinutes;
    final int seconds = dur.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get playback progress (0.0 to 1.0)
  double getProgress() {
    final Duration? dur = duration;
    if (dur == null || dur.inMilliseconds == 0) return 0.0;

    return (position.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Dispose of the service
  Future<void> dispose() async {
    await stop();
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _stateController.close();
    await _positionController.close();
    await _currentVoiceNoteController.close();
    await _audioPlayer.dispose();
    _instance = null;
  }
}
