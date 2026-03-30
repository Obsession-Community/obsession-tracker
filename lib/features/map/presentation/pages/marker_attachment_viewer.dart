import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:obsession_tracker/core/models/marker_attachment.dart';
import 'package:obsession_tracker/core/services/marker_attachment_service.dart';
import 'package:obsession_tracker/features/hunts/presentation/pages/document_viewer_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Viewer for marker attachments.
///
/// Routes to appropriate viewer based on attachment type:
/// - Images: Fullscreen zoomable viewer
/// - PDFs/Documents: DocumentViewerPage
/// - Notes: Text display
/// - Links: Opens in browser
class MarkerAttachmentViewer extends StatelessWidget {
  const MarkerAttachmentViewer({
    super.key,
    required this.attachment,
    this.allAttachments,
    this.initialIndex,
  });

  final MarkerAttachment attachment;
  final List<MarkerAttachment>? allAttachments;
  final int? initialIndex;

  @override
  Widget build(BuildContext context) {
    switch (attachment.type) {
      case MarkerAttachmentType.image:
        return _ImageAttachmentViewer(
          attachment: attachment,
          allImages: allAttachments
              ?.where((a) => a.type == MarkerAttachmentType.image)
              .toList(),
          initialIndex: initialIndex,
        );

      case MarkerAttachmentType.pdf:
      case MarkerAttachmentType.document:
        if (attachment.filePath == null) {
          return const _ErrorView(message: 'File path not found');
        }
        return DocumentViewerPage(
          title: attachment.name,
          filePath: attachment.filePath!,
        );

      case MarkerAttachmentType.note:
        return _NoteAttachmentViewer(attachment: attachment);

      case MarkerAttachmentType.link:
        // Links open in browser immediately
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openLink(context, attachment.url);
          Navigator.pop(context);
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );

      case MarkerAttachmentType.audio:
        if (attachment.filePath == null) {
          return const _ErrorView(message: 'Audio file path not found');
        }
        return _AudioAttachmentViewer(attachment: attachment);
    }
  }

  Future<void> _openLink(BuildContext context, String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No URL provided')),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid URL: $url')),
      );
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $url')),
        );
      }
    }
  }
}

/// Fullscreen image viewer with swipe gallery and rotation controls
class _ImageAttachmentViewer extends StatefulWidget {
  const _ImageAttachmentViewer({
    required this.attachment,
    this.allImages,
    this.initialIndex,
  });

  final MarkerAttachment attachment;
  final List<MarkerAttachment>? allImages;
  final int? initialIndex;

  @override
  State<_ImageAttachmentViewer> createState() => _ImageAttachmentViewerState();
}

class _ImageAttachmentViewerState extends State<_ImageAttachmentViewer> {
  late PageController _pageController;
  late int _currentIndex;

  /// Track rotation for each image by attachment ID
  /// Values are 0-3 representing quarter turns (0=0°, 1=90°CW, 2=180°, 3=270°CW)
  final Map<String, int> _rotations = {};

  final MarkerAttachmentService _attachmentService = MarkerAttachmentService();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
    _pageController = PageController(initialPage: _currentIndex);
    _initializeRotations();
  }

  void _initializeRotations() {
    // Initialize rotations from saved values
    if (widget.allImages != null) {
      for (final attachment in widget.allImages!) {
        _rotations[attachment.id] = attachment.userRotation ?? 0;
        debugPrint('📷 Loaded rotation for ${attachment.id}: ${attachment.userRotation}');
      }
    } else {
      _rotations[widget.attachment.id] = widget.attachment.userRotation ?? 0;
      debugPrint('📷 Loaded rotation for ${widget.attachment.id}: ${widget.attachment.userRotation}');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  MarkerAttachment get _currentAttachment =>
      widget.allImages != null && widget.allImages!.isNotEmpty
          ? widget.allImages![_currentIndex]
          : widget.attachment;

  bool get _hasMultipleImages =>
      widget.allImages != null && widget.allImages!.length > 1;

  int get _currentRotation => _rotations[_currentAttachment.id] ?? 0;

  Future<void> _rotateLeft() async {
    HapticFeedback.lightImpact();
    final attachmentId = _currentAttachment.id;
    final currentRotation = _rotations[attachmentId] ?? 0;
    // Rotate counter-clockwise: 0 -> 3 -> 2 -> 1 -> 0
    final newRotation = (currentRotation - 1 + 4) % 4;

    setState(() {
      _rotations[attachmentId] = newRotation;
    });

    // Save to database
    await _saveRotation(attachmentId, newRotation);
  }

  Future<void> _rotateRight() async {
    HapticFeedback.lightImpact();
    final attachmentId = _currentAttachment.id;
    final currentRotation = _rotations[attachmentId] ?? 0;
    // Rotate clockwise: 0 -> 1 -> 2 -> 3 -> 0
    final newRotation = (currentRotation + 1) % 4;

    setState(() {
      _rotations[attachmentId] = newRotation;
    });

    // Save to database
    await _saveRotation(attachmentId, newRotation);
  }

  Future<void> _saveRotation(String attachmentId, int rotation) async {
    try {
      debugPrint('📷 Saving rotation for $attachmentId: $rotation');
      await _attachmentService.updateAttachmentRotation(attachmentId, rotation);
      debugPrint('📷 Rotation saved successfully');
    } catch (e) {
      debugPrint('📷 Error saving rotation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save rotation')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: _hasMultipleImages
            ? Text(
                '${_currentIndex + 1} / ${widget.allImages!.length}',
                style: const TextStyle(fontSize: 16),
              )
            : Text(
                _currentAttachment.name,
                style: const TextStyle(fontSize: 16),
              ),
        actions: [
          // Rotate left button
          IconButton(
            icon: const Icon(Icons.rotate_left),
            onPressed: _rotateLeft,
            tooltip: 'Rotate left',
          ),
          // Rotate right button
          IconButton(
            icon: const Icon(Icons.rotate_right),
            onPressed: _rotateRight,
            tooltip: 'Rotate right',
          ),
          // Share button
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareImage,
            tooltip: 'Share',
          ),
        ],
      ),
      body: _hasMultipleImages
          ? PageView.builder(
              controller: _pageController,
              itemCount: widget.allImages!.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final attachment = widget.allImages![index];
                return _buildImageView(attachment, _rotations[attachment.id] ?? 0);
              },
            )
          : _buildImageView(widget.attachment, _currentRotation),
    );
  }

  Widget _buildImageView(MarkerAttachment attachment, int rotation) {
    if (attachment.filePath == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: Colors.white54, size: 64),
            SizedBox(height: 16),
            Text(
              'Image file not found',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    final file = File(attachment.filePath!);
    if (!file.existsSync()) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: Colors.white54, size: 64),
            SizedBox(height: 16),
            Text(
              'Image file not found',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    Widget imageWidget = Image.file(
      file,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(
          Icons.broken_image,
          color: Colors.white54,
          size: 64,
        );
      },
    );

    // Apply rotation if needed
    if (rotation != 0) {
      imageWidget = RotatedBox(
        quarterTurns: rotation,
        child: imageWidget,
      );
    }

    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: imageWidget,
      ),
    );
  }

  Future<void> _shareImage() async {
    final filePath = _currentAttachment.filePath;
    if (filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File path not found')),
      );
      return;
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found')),
      );
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        subject: _currentAttachment.name,
      ),
    );
  }
}

/// Viewer for note attachments
class _NoteAttachmentViewer extends StatelessWidget {
  const _NoteAttachmentViewer({required this.attachment});

  final MarkerAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(attachment.name),
        actions: [
          if (attachment.content != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareNote(context),
              tooltip: 'Share',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          attachment.content ?? 'No content',
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Future<void> _shareNote(BuildContext context) async {
    final content = attachment.content;
    if (content == null) return;

    await SharePlus.instance.share(
      ShareParams(
        text: content,
        subject: attachment.name,
      ),
    );
  }
}

/// Viewer for audio attachments (voice memos)
class _AudioAttachmentViewer extends StatefulWidget {
  const _AudioAttachmentViewer({required this.attachment});

  final MarkerAttachment attachment;

  @override
  State<_AudioAttachmentViewer> createState() => _AudioAttachmentViewerState();
}

class _AudioAttachmentViewerState extends State<_AudioAttachmentViewer> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final file = File(widget.attachment.filePath!);
      if (!file.existsSync()) {
        setState(() {
          _error = 'Audio file not found';
          _isLoading = false;
        });
        return;
      }

      await _audioPlayer.setFilePath(widget.attachment.filePath!);

      _audioPlayer.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() => _duration = duration);
        }
      });

      _audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() => _position = position);
        }
      });

      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            if (state.processingState == ProcessingState.completed) {
              _isPlaying = false;
              _position = Duration.zero;
              _audioPlayer.seek(Duration.zero);
            }
          });
        }
      });

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load audio: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> _seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _shareAudio() async {
    final filePath = widget.attachment.filePath;
    if (filePath == null) return;

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        subject: widget.attachment.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.attachment.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareAudio,
            tooltip: 'Share',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _buildContent(theme),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    if (_error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Microphone icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mic,
            size: 64,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 32),

        // Title
        Text(
          widget.attachment.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // File size
        if (widget.attachment.fileSize != null)
          Text(
            widget.attachment.fileSizeFormatted,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 32),

        // Progress slider
        Slider(
          value: _duration.inMilliseconds > 0
              ? (_position.inMilliseconds / _duration.inMilliseconds)
                  .clamp(0.0, 1.0)
              : 0.0,
          onChanged: (value) {
            final newPosition = Duration(
              milliseconds: (value * _duration.inMilliseconds).round(),
            );
            _seek(newPosition);
          },
        ),

        // Time labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: theme.textTheme.bodySmall,
              ),
              Text(
                _formatDuration(_duration),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Play/Pause button
        FilledButton.icon(
          onPressed: _togglePlayPause,
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          label: Text(_isPlaying ? 'Pause' : 'Play'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ],
    );
  }
}

/// Error view for missing files
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to open attachment viewer
Future<void> showMarkerAttachmentViewer(
  BuildContext context, {
  required MarkerAttachment attachment,
  List<MarkerAttachment>? allAttachments,
  int? initialIndex,
}) async {
  // Handle links directly without navigation
  if (attachment.type == MarkerAttachmentType.link) {
    final url = attachment.url;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No URL provided')),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid URL: $url')),
      );
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $url')),
        );
      }
    }
    return;
  }

  // Navigate to viewer for other types
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => MarkerAttachmentViewer(
        attachment: attachment,
        allAttachments: allAttachments,
        initialIndex: initialIndex,
      ),
    ),
  );
}
