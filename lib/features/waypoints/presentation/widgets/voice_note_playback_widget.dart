import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/voice_note.dart';
import 'package:obsession_tracker/core/providers/voice_note_provider.dart';
import 'package:obsession_tracker/core/services/voice_playback_service.dart';

/// Widget for playing back voice notes with controls
class VoiceNotePlaybackWidget extends ConsumerWidget {
  const VoiceNotePlaybackWidget({
    required this.voiceNote,
    super.key,
    this.onDelete,
    this.showDeleteButton = true,
  });

  final VoiceNote voiceNote;
  final VoidCallback? onDelete;
  final bool showDeleteButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<VoicePlaybackState> playbackStateAsync =
        ref.watch(voicePlaybackStateProvider);
    final AsyncValue<Duration> positionAsync =
        ref.watch(voicePlaybackPositionProvider);
    final AsyncValue<VoiceNote?> currentVoiceNoteAsync =
        ref.watch(currentPlayingVoiceNoteProvider);

    final VoicePlaybackState playbackState =
        playbackStateAsync.value ?? VoicePlaybackState.stopped;
    final Duration position = positionAsync.value ?? Duration.zero;
    final VoiceNote? currentVoiceNote = currentVoiceNoteAsync.value;

    final bool isCurrentlyPlaying = currentVoiceNote?.id == voiceNote.id;
    final bool isPlaying =
        isCurrentlyPlaying && playbackState == VoicePlaybackState.playing;
    final bool isPaused =
        isCurrentlyPlaying && playbackState == VoicePlaybackState.paused;
    final bool isLoading =
        isCurrentlyPlaying && playbackState == VoicePlaybackState.loading;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentlyPlaying
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Voice note header
          Row(
            children: [
              Icon(
                Icons.mic,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Voice Note',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const Spacer(),
              Text(
                _formatDateTime(voiceNote.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
              if (showDeleteButton) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 16),
                  color: Colors.red,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  tooltip: 'Delete voice note',
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Playback controls
          Row(
            children: [
              // Play/pause button
              _buildPlayButton(context, ref, isPlaying, isPaused, isLoading),

              const SizedBox(width: 12),

              // Progress and duration
              Expanded(
                child: _buildProgressSection(
                    context, ref, position, isCurrentlyPlaying),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Voice note metadata
          _buildMetadata(context),
        ],
      ),
    );
  }

  Widget _buildPlayButton(BuildContext context, WidgetRef ref, bool isPlaying,
      bool isPaused, bool isLoading) {
    IconData iconData;
    VoidCallback? onPressed;

    if (isLoading) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (isPlaying) {
      iconData = Icons.pause;
      onPressed = () => _pausePlayback(ref);
    } else {
      iconData = Icons.play_arrow;
      onPressed = () => _startPlayback(ref);
    }

    return IconButton(
      onPressed: onPressed,
      icon: Icon(iconData),
      color: Theme.of(context).colorScheme.primary,
      style: IconButton.styleFrom(
        backgroundColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        shape: const CircleBorder(),
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context, WidgetRef ref,
      Duration position, bool isCurrentlyPlaying) {
    final Duration totalDuration = Duration(milliseconds: voiceNote.duration);
    final double progress =
        isCurrentlyPlaying && totalDuration.inMilliseconds > 0
            ? (position.inMilliseconds / totalDuration.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: progress,
            onChanged:
                isCurrentlyPlaying ? (value) => _seekTo(ref, value) : null,
            activeColor: Theme.of(context).colorScheme.primary,
            inactiveColor:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),

        // Time display
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isCurrentlyPlaying ? _formatDuration(position) : '0:00',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
            Text(
              voiceNote.durationFormatted,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetadata(BuildContext context) => Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 14,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 4),
          Text(
            '${voiceNote.fileSizeFormatted} • ${voiceNote.durationFormatted}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
          ),
        ],
      );

  Future<void> _startPlayback(WidgetRef ref) async {
    final VoicePlaybackService playbackService =
        ref.read(voicePlaybackServiceProvider);
    await playbackService.playVoiceNote(voiceNote);
  }

  Future<void> _pausePlayback(WidgetRef ref) async {
    final VoicePlaybackService playbackService =
        ref.read(voicePlaybackServiceProvider);
    await playbackService.pause();
  }

  Future<void> _seekTo(WidgetRef ref, double value) async {
    final VoicePlaybackService playbackService =
        ref.read(voicePlaybackServiceProvider);
    final Duration totalDuration = Duration(milliseconds: voiceNote.duration);
    final Duration seekPosition = Duration(
      milliseconds: (totalDuration.inMilliseconds * value).round(),
    );
    await playbackService.seek(seekPosition);
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) =>
      '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}

/// Widget for displaying a list of voice notes
class VoiceNoteListWidget extends ConsumerWidget {
  const VoiceNoteListWidget({
    required this.voiceNotes,
    super.key,
    this.onDeleteVoiceNote,
    this.showDeleteButtons = true,
  });

  final List<VoiceNote> voiceNotes;
  final void Function(VoiceNote voiceNote)? onDeleteVoiceNote;
  final bool showDeleteButtons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (voiceNotes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.mic_off,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'No voice notes',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Voice Notes (${voiceNotes.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...voiceNotes.map((voiceNote) => VoiceNotePlaybackWidget(
              voiceNote: voiceNote,
              onDelete: onDeleteVoiceNote != null
                  ? () => onDeleteVoiceNote!(voiceNote)
                  : null,
              showDeleteButton: showDeleteButtons,
            )),
      ],
    );
  }
}
