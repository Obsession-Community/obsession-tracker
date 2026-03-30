import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/providers/voice_note_provider.dart';
import 'package:obsession_tracker/core/services/voice_recording_service.dart';

/// Real-time annotation overlay for camera preview
class CameraAnnotationOverlayWidget extends ConsumerStatefulWidget {
  const CameraAnnotationOverlayWidget({
    required this.onAnnotationChanged,
    super.key,
    this.initialNote,
    this.initialTags,
    this.initialRating = 0,
    this.initialFavorite = false,
    this.showQuickActions = true,
    this.isCompact = false,
  });

  final void Function(CameraAnnotationData annotation) onAnnotationChanged;
  final String? initialNote;
  final String? initialTags;
  final int initialRating;
  final bool initialFavorite;
  final bool showQuickActions;
  final bool isCompact;

  @override
  ConsumerState<CameraAnnotationOverlayWidget> createState() =>
      _CameraAnnotationOverlayWidgetState();
}

class _CameraAnnotationOverlayWidgetState
    extends ConsumerState<CameraAnnotationOverlayWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;

  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();

  bool _isExpanded = false;
  bool _isFavorite = false;
  int _rating = 0;
  bool _isRecordingVoice = false;
  Timer? _voiceRecordingTimer;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Initialize with provided values
    _noteController.text = widget.initialNote ?? '';
    _tagsController.text = widget.initialTags ?? '';
    _rating = widget.initialRating;
    _isFavorite = widget.initialFavorite;

    // Listen for changes
    _noteController.addListener(_onAnnotationChanged);
    _tagsController.addListener(_onAnnotationChanged);

    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    _noteController.dispose();
    _tagsController.dispose();
    _noteFocusNode.dispose();
    _voiceRecordingTimer?.cancel();
    super.dispose();
  }

  void _onAnnotationChanged() {
    final annotation = CameraAnnotationData(
      note: _noteController.text.trim(),
      tags: _tagsController.text.trim(),
      rating: _rating,
      isFavorite: _isFavorite,
    );
    widget.onAnnotationChanged(annotation);
  }

  @override
  Widget build(BuildContext context) {
    final VoiceRecordingState recordingState =
        ref.watch(voiceRecordingProvider);

    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isRecordingVoice
                ? Colors.red.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.2),
            width: _isRecordingVoice ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            if (_isExpanded) ...[
              _buildExpandedContent(),
            ] else if (widget.showQuickActions) ...[
              _buildQuickActions(),
            ],
            if (_isRecordingVoice)
              _buildVoiceRecordingIndicator(recordingState),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.edit_note,
              color: Colors.white,
              size: widget.isCompact ? 16 : 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isExpanded ? 'Photo Annotation' : 'Quick Note',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.isCompact ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_hasAnnotations()) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_getAnnotationCount()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            GestureDetector(
              onTap: _toggleExpanded,
              child: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
      );

  Widget _buildQuickActions() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Quick note input
            Expanded(
              child: TextField(
                controller: _noteController,
                focusNode: _noteFocusNode,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Quick note...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                ),
                textInputAction: TextInputAction.done,
              ),
            ),
            const SizedBox(width: 8),
            // Voice note button
            _buildVoiceNoteButton(),
            const SizedBox(width: 4),
            // Favorite button
            _buildFavoriteButton(),
          ],
        ),
      );

  Widget _buildExpandedContent() => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Note field
            TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Note',
                labelStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                hintText: 'Add your thoughts about this photo...',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Tags field
            TextField(
              controller: _tagsController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Tags',
                labelStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                hintText: 'adventure, sunset, wildlife',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Rating and favorite row
            Row(
              children: [
                // Rating
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rating',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildRatingSelector(),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Voice note and favorite
                Column(
                  children: [
                    _buildVoiceNoteButton(),
                    const SizedBox(height: 8),
                    _buildFavoriteButton(),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildRatingSelector() => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final starIndex = index + 1;
          return GestureDetector(
            onTap: () {
              setState(() {
                _rating = starIndex == _rating ? 0 : starIndex;
              });
              _onAnnotationChanged();
              HapticFeedback.lightImpact();
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                starIndex <= _rating ? Icons.star : Icons.star_border,
                color: starIndex <= _rating
                    ? Colors.amber
                    : Colors.white.withValues(alpha: 0.5),
                size: 20,
              ),
            ),
          );
        }),
      );

  Widget _buildFavoriteButton() => GestureDetector(
        onTap: () {
          setState(() {
            _isFavorite = !_isFavorite;
          });
          _onAnnotationChanged();
          HapticFeedback.lightImpact();
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isFavorite
                ? Colors.red.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFavorite
                  ? Colors.red
                  : Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? Colors.red : Colors.white,
            size: 20,
          ),
        ),
      );

  Widget _buildVoiceNoteButton() {
    final VoiceRecordingState recordingState =
        ref.watch(voiceRecordingProvider);
    final bool isRecording = recordingState.isRecording;

    return GestureDetector(
      onTap: isRecording ? _stopVoiceRecording : _startVoiceRecording,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) => Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isRecording
                ? Colors.red
                    .withValues(alpha: 0.3 + 0.2 * _pulseController.value)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isRecording
                  ? Colors.red
                  : Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            isRecording ? Icons.stop : Icons.mic,
            color: isRecording ? Colors.red : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceRecordingIndicator(VoiceRecordingState state) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => Icon(
                Icons.fiber_manual_record,
                color: Colors.red
                    .withValues(alpha: 0.7 + 0.3 * _pulseController.value),
                size: 12,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Recording: ${_formatDuration(state.recordingDuration)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${_formatDuration(state.remainingTime)} left',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _slideController.forward();
    } else {
      _slideController.reverse();
    }

    HapticFeedback.lightImpact();
  }

  Future<void> _startVoiceRecording() async {
    try {
      final bool hasPermission =
          await ref.read(voiceRecordingProvider.notifier).requestPermission();

      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Microphone permission is required for voice notes'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final bool success =
          await ref.read(voiceRecordingProvider.notifier).startRecording();

      if (success) {
        setState(() {
          _isRecordingVoice = true;
        });
        _pulseController.repeat(reverse: true);
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint('Error starting voice recording: $e');
    }
  }

  Future<void> _stopVoiceRecording() async {
    try {
      final VoiceRecordingResult result =
          await ref.read(voiceRecordingProvider.notifier).stopRecording();

      setState(() {
        _isRecordingVoice = false;
      });
      _pulseController.stop();
      _pulseController.reset();

      if (result.success) {
        HapticFeedback.mediumImpact();
        // Voice note will be handled by the camera preview page
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Failed to record voice note'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isRecordingVoice = false;
      });
      _pulseController.stop();
      _pulseController.reset();
      debugPrint('Error stopping voice recording: $e');
    }
  }

  bool _hasAnnotations() =>
      _noteController.text.trim().isNotEmpty ||
      _tagsController.text.trim().isNotEmpty ||
      _rating > 0 ||
      _isFavorite;

  int _getAnnotationCount() {
    int count = 0;
    if (_noteController.text.trim().isNotEmpty) count++;
    if (_tagsController.text.trim().isNotEmpty) count++;
    if (_rating > 0) count++;
    if (_isFavorite) count++;
    return count;
  }

  String _formatDuration(int milliseconds) {
    final Duration duration = Duration(milliseconds: milliseconds);
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Data class for camera annotation information
@immutable
class CameraAnnotationData {
  const CameraAnnotationData({
    this.note = '',
    this.tags = '',
    this.rating = 0,
    this.isFavorite = false,
  });

  final String note;
  final String tags;
  final int rating;
  final bool isFavorite;

  bool get hasAnnotations =>
      note.isNotEmpty || tags.isNotEmpty || rating > 0 || isFavorite;

  List<PhotoMetadata> toPhotoMetadata(String photoWaypointId) {
    final List<PhotoMetadata> metadata = <PhotoMetadata>[];
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final String photoWaypointIdStr = photoWaypointId;

    if (note.isNotEmpty) {
      metadata.add(PhotoMetadata.string(
        id: timestamp + 1,
        photoWaypointId: photoWaypointIdStr,
        key: CustomKeys.userNote,
        value: note,
      ));
    }

    if (tags.isNotEmpty) {
      metadata.add(PhotoMetadata.string(
        id: timestamp + 2,
        photoWaypointId: photoWaypointIdStr,
        key: CustomKeys.tags,
        value: tags,
      ));
    }

    if (rating > 0) {
      metadata.add(PhotoMetadata.integer(
        id: timestamp + 3,
        photoWaypointId: photoWaypointIdStr,
        key: CustomKeys.rating,
        value: rating,
      ));
    }

    metadata.add(PhotoMetadata.boolean(
      id: timestamp + 4,
      photoWaypointId: photoWaypointIdStr,
      key: CustomKeys.favorite,
      value: isFavorite,
    ));

    return metadata;
  }

  CameraAnnotationData copyWith({
    String? note,
    String? tags,
    int? rating,
    bool? isFavorite,
  }) =>
      CameraAnnotationData(
        note: note ?? this.note,
        tags: tags ?? this.tags,
        rating: rating ?? this.rating,
        isFavorite: isFavorite ?? this.isFavorite,
      );
}
