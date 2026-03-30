import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/voice_note.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// Result of a voice recording operation
class VoiceRecordingResult {
  const VoiceRecordingResult({
    required this.success,
    required this.filePath,
    required this.duration,
    required this.fileSize,
    this.error,
  });

  final bool success;
  final String? filePath;
  final int duration; // Duration in milliseconds
  final int fileSize; // File size in bytes
  final String? error;
}

/// Service for recording voice notes with 30-second limit
class VoiceRecordingService {
  factory VoiceRecordingService() => _instance ??= VoiceRecordingService._();
  VoiceRecordingService._();
  static VoiceRecordingService? _instance;

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _recordingTimer;
  DateTime? _recordingStartTime;
  bool _isRecording = false;
  String? _currentRecordingPath;

  static const int maxRecordingDurationMs = 30000; // 30 seconds
  static const String audioFileExtension = '.m4a';

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    try {
      final PermissionStatus status = await Permission.microphone.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('Error checking microphone permission: $e');
      return false;
    }
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    try {
      final PermissionStatus status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Get current recording duration in milliseconds
  int get currentRecordingDuration {
    if (!_isRecording || _recordingStartTime == null) {
      return 0;
    }
    return DateTime.now().difference(_recordingStartTime!).inMilliseconds;
  }

  /// Get remaining recording time in milliseconds
  int get remainingRecordingTime {
    final int current = currentRecordingDuration;
    return (maxRecordingDurationMs - current).clamp(0, maxRecordingDurationMs);
  }

  /// Start recording voice note
  Future<bool> startRecording() async {
    if (_isRecording) {
      debugPrint('Already recording');
      return false;
    }

    try {
      // Check permission
      if (!await hasPermission()) {
        if (!await requestPermission()) {
          debugPrint('Microphone permission denied');
          return false;
        }
      }

      // Check if recorder is available
      if (!await _recorder.hasPermission()) {
        debugPrint('Recorder permission not available');
        return false;
      }

      // Generate unique file path
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory voiceNotesDir =
          Directory(join(appDir.path, 'voice_notes'));
      if (!voiceNotesDir.existsSync()) {
        await voiceNotesDir.create(recursive: true);
      }

      final String fileName = '${const Uuid().v4()}$audioFileExtension';
      _currentRecordingPath = join(voiceNotesDir.path, fileName);

      // Configure recording settings
      const RecordConfig config = RecordConfig(
        numChannels: 1, // Mono
      );

      // Start recording
      await _recorder.start(config, path: _currentRecordingPath!);

      _isRecording = true;
      _recordingStartTime = DateTime.now();

      // Set up timer to stop recording after 30 seconds
      _recordingTimer = Timer(
        const Duration(milliseconds: maxRecordingDurationMs),
        () async {
          if (_isRecording) {
            await stopRecording();
          }
        },
      );

      debugPrint('Started voice recording: $_currentRecordingPath');
      return true;
    } catch (e) {
      debugPrint('Error starting voice recording: $e');
      _cleanup();
      return false;
    }
  }

  /// Stop recording and return result
  Future<VoiceRecordingResult> stopRecording() async {
    if (!_isRecording) {
      return const VoiceRecordingResult(
        success: false,
        filePath: null,
        duration: 0,
        fileSize: 0,
        error: 'Not currently recording',
      );
    }

    try {
      // Stop the recorder
      final String? recordedPath = await _recorder.stop();

      // Calculate duration
      final int duration = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;

      // Clean up timer and state
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _isRecording = false;
      _recordingStartTime = null;

      if (recordedPath == null || _currentRecordingPath == null) {
        return const VoiceRecordingResult(
          success: false,
          filePath: null,
          duration: 0,
          fileSize: 0,
          error: 'Recording path is null',
        );
      }

      // Check if file exists and get size
      final File recordedFile = File(_currentRecordingPath!);
      if (!recordedFile.existsSync()) {
        return const VoiceRecordingResult(
          success: false,
          filePath: null,
          duration: 0,
          fileSize: 0,
          error: 'Recorded file does not exist',
        );
      }

      final int fileSize = await recordedFile.length();
      final String filePath = _currentRecordingPath!;
      _currentRecordingPath = null;

      // Validate minimum recording duration (at least 1 second)
      if (duration < 1000) {
        // Delete the short recording
        try {
          await recordedFile.delete();
        } catch (e) {
          debugPrint('Error deleting short recording: $e');
        }

        return const VoiceRecordingResult(
          success: false,
          filePath: null,
          duration: 0,
          fileSize: 0,
          error: 'Recording too short (minimum 1 second)',
        );
      }

      debugPrint(
          'Voice recording completed: $filePath, duration: ${duration}ms, size: $fileSize bytes');

      return VoiceRecordingResult(
        success: true,
        filePath: filePath,
        duration: duration,
        fileSize: fileSize,
      );
    } catch (e) {
      debugPrint('Error stopping voice recording: $e');
      _cleanup();
      return VoiceRecordingResult(
        success: false,
        filePath: null,
        duration: 0,
        fileSize: 0,
        error: 'Error stopping recording: $e',
      );
    }
  }

  /// Cancel current recording
  Future<void> cancelRecording() async {
    if (!_isRecording) {
      return;
    }

    try {
      await _recorder.stop();

      // Delete the recorded file if it exists
      if (_currentRecordingPath != null) {
        final File recordedFile = File(_currentRecordingPath!);
        if (recordedFile.existsSync()) {
          await recordedFile.delete();
          debugPrint('Deleted cancelled recording: $_currentRecordingPath');
        }
      }
    } catch (e) {
      debugPrint('Error cancelling voice recording: $e');
    } finally {
      _cleanup();
    }
  }

  /// Create a VoiceNote model from recording result
  VoiceNote createVoiceNote({
    required String waypointId,
    required VoiceRecordingResult result,
  }) {
    if (!result.success || result.filePath == null) {
      throw ArgumentError(
          'Cannot create VoiceNote from failed recording result');
    }

    return VoiceNote(
      id: const Uuid().v4(),
      waypointId: waypointId,
      filePath: result.filePath!,
      createdAt: DateTime.now(),
      fileSize: result.fileSize,
      duration: result.duration,
    );
  }

  /// Delete a voice note file
  Future<bool> deleteVoiceNoteFile(String filePath) async {
    try {
      final File file = File(filePath);
      if (file.existsSync()) {
        await file.delete();
        debugPrint('Deleted voice note file: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting voice note file: $e');
      return false;
    }
  }

  /// Clean up resources
  void _cleanup() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _isRecording = false;
    _recordingStartTime = null;
    _currentRecordingPath = null;
  }

  /// Dispose of the service
  Future<void> dispose() async {
    await cancelRecording();
    await _recorder.dispose();
    _instance = null;
  }
}
