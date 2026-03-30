import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/voice_note_provider.dart';
import 'package:obsession_tracker/core/services/voice_recording_service.dart';

/// Widget for recording voice notes with visual feedback
class VoiceRecordingWidget extends ConsumerStatefulWidget {
  const VoiceRecordingWidget({
    required this.onRecordingComplete,
    super.key,
    this.onRecordingStart,
    this.onRecordingCancel,
  });

  final void Function(VoiceRecordingResult result) onRecordingComplete;
  final VoidCallback? onRecordingStart;
  final VoidCallback? onRecordingCancel;

  @override
  ConsumerState<VoiceRecordingWidget> createState() =>
      _VoiceRecordingWidgetState();
}

class _VoiceRecordingWidgetState extends ConsumerState<VoiceRecordingWidget>
    with TickerProviderStateMixin {
  Timer? _progressTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VoiceRecordingState recordingState =
        ref.watch(voiceRecordingProvider);

    // Start/stop progress timer based on recording state
    if (recordingState.isRecording && _progressTimer == null) {
      _startProgressTimer();
      _pulseController.repeat(reverse: true);
    } else if (!recordingState.isRecording && _progressTimer != null) {
      _stopProgressTimer();
      _pulseController.stop();
      _pulseController.reset();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: recordingState.isRecording
              ? Colors.red.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Recording status and timer
          _buildRecordingStatus(recordingState),
          const SizedBox(height: 16),

          // Recording button and controls
          _buildRecordingControls(recordingState),

          // Error message
          if (recordingState.error != null) ...[
            const SizedBox(height: 12),
            _buildErrorMessage(recordingState.error!),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordingStatus(VoiceRecordingState state) {
    if (!state.isRecording) {
      return Column(
        children: [
          Icon(
            Icons.mic,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to record voice note',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          Text(
            'Maximum 30 seconds',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Animated recording icon
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) => Transform.scale(
            scale: _pulseAnimation.value,
            child: const Icon(
              Icons.mic,
              size: 32,
              color: Colors.red,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Recording timer
        Text(
          _formatDuration(state.recordingDuration),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
        ),

        // Remaining time
        Text(
          'Remaining: ${_formatDuration(state.remainingTime)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
        ),

        const SizedBox(height: 8),

        // Progress bar
        LinearProgressIndicator(
          value: state.recordingDuration /
              VoiceRecordingService.maxRecordingDurationMs,
          backgroundColor:
              Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
        ),
      ],
    );
  }

  Widget _buildRecordingControls(VoiceRecordingState state) {
    if (!state.isRecording) {
      return ElevatedButton.icon(
        onPressed: state.hasPermission ? _startRecording : _requestPermission,
        icon: Icon(state.hasPermission ? Icons.mic : Icons.mic_off),
        label: Text(state.hasPermission ? 'Record' : 'Allow Microphone'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Cancel button
        ElevatedButton.icon(
          onPressed: _cancelRecording,
          icon: const Icon(Icons.close),
          label: const Text('Cancel'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            side: BorderSide(color: Theme.of(context).colorScheme.outline),
          ),
        ),

        // Stop button
        ElevatedButton.icon(
          onPressed: _stopRecording,
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(String error) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                    ),
              ),
            ),
            IconButton(
              onPressed: () =>
                  ref.read(voiceRecordingProvider.notifier).clearError(),
              icon: const Icon(Icons.close, size: 16),
              color: Colors.red,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      );

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        ref.read(voiceRecordingProvider.notifier).updateProgress();
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  Future<void> _requestPermission() async {
    final bool granted =
        await ref.read(voiceRecordingProvider.notifier).requestPermission();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Microphone permission is required to record voice notes'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startRecording() async {
    final bool success =
        await ref.read(voiceRecordingProvider.notifier).startRecording();
    if (success) {
      widget.onRecordingStart?.call();
    }
  }

  Future<void> _stopRecording() async {
    final VoiceRecordingResult result =
        await ref.read(voiceRecordingProvider.notifier).stopRecording();
    widget.onRecordingComplete(result);
  }

  Future<void> _cancelRecording() async {
    await ref.read(voiceRecordingProvider.notifier).cancelRecording();
    widget.onRecordingCancel?.call();
  }

  String _formatDuration(int milliseconds) {
    final int seconds = (milliseconds / 1000).round();
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
