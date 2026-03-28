import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/models/voice_note.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/app_settings_provider.dart';
import 'package:obsession_tracker/core/providers/voice_note_provider.dart';
import 'package:obsession_tracker/core/providers/waypoint_provider.dart';
import 'package:obsession_tracker/core/services/photo_capture_service.dart';
import 'package:obsession_tracker/core/services/voice_recording_service.dart';
import 'package:obsession_tracker/core/services/waypoint_icon_service.dart';
import 'package:obsession_tracker/core/services/waypoint_media_service.dart';
import 'package:obsession_tracker/core/utils/coordinate_formatter.dart';
import 'package:obsession_tracker/features/waypoints/presentation/pages/adaptive_camera_preview_page.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/fullscreen_photo_viewer.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/voice_note_playback_widget.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/voice_recording_widget.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Detail page for viewing and editing waypoint information including notes
class WaypointDetailPage extends ConsumerStatefulWidget {
  const WaypointDetailPage({
    required this.waypoint,
    super.key,
  });

  final Waypoint waypoint;

  @override
  ConsumerState<WaypointDetailPage> createState() => _WaypointDetailPageState();
}

class _WaypointDetailPageState extends ConsumerState<WaypointDetailPage> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _showVoiceRecording = false;

  // Photo state
  List<PhotoWaypoint> _photos = <PhotoWaypoint>[];
  bool _isLoadingPhotos = false;
  final WaypointMediaService _mediaService = WaypointMediaService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.waypoint.name ?? '');
    _notesController = TextEditingController(text: widget.waypoint.notes ?? '');

    // Listen for changes
    _nameController.addListener(_onTextChanged);
    _notesController.addListener(_onTextChanged);

    // Load voice notes and photos for this waypoint
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(voiceNoteProvider.notifier)
          .loadVoiceNotesForWaypoint(widget.waypoint.id);
      _loadPhotos();
    });
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoadingPhotos = true);
    try {
      final List<PhotoWaypoint> photos =
          await _mediaService.getPhotosForWaypoint(widget.waypoint.id);
      if (mounted) {
        setState(() {
          _photos = photos;
          _isLoadingPhotos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPhotos = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final bool hasChanges =
        _nameController.text != (widget.waypoint.name ?? '') ||
            _notesController.text != (widget.waypoint.notes ?? '');

    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.waypoint.displayName),
          actions: [
            if (_isEditing) ...[
              TextButton(
                onPressed: _hasChanges ? _saveChanges : null,
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ] else ...[
              IconButton(
                onPressed: _startEditing,
                icon: const Icon(Icons.edit),
                tooltip: 'Edit waypoint',
              ),
            ],
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Waypoint type and icon
              _buildWaypointHeader(),
              const SizedBox(height: 24),

              // Location information
              _buildLocationSection(),
              const SizedBox(height: 24),

              // Name section
              _buildNameSection(),
              const SizedBox(height: 24),

              // Notes section
              _buildNotesSection(),
              const SizedBox(height: 24),

              // Photos section
              _buildPhotosSection(),
              const SizedBox(height: 24),

              // Voice notes section
              _buildVoiceNotesSection(),
              const SizedBox(height: 24),

              // Metadata section
              _buildMetadataSection(),
            ],
          ),
        ),
      );

  Widget _buildWaypointHeader() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WaypointIconService.instance
              .getIconColor(widget.waypoint.type)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: WaypointIconService.instance
                .getIconColor(widget.waypoint.type)
                .withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: WaypointIconService.instance
                    .getIconColor(widget.waypoint.type),
                borderRadius: BorderRadius.circular(8),
              ),
              child: WaypointIconService.instance.getIconWidgetCustomSize(
                widget.waypoint.type,
                width: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.waypoint.type.displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Created ${_formatDateTime(widget.waypoint.timestamp)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildLocationSection() {
    final coordinateFormat = ref.watch(generalSettingsProvider).coordinateFormat;
    return _buildSection(
        title: 'Location',
        icon: Icons.location_on,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              'Coordinates',
              CoordinateFormatter.formatPair(
                  widget.waypoint.coordinates.latitude,
                  widget.waypoint.coordinates.longitude,
                  coordinateFormat),
            ),
            if (widget.waypoint.altitude != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                'Altitude',
                '${widget.waypoint.altitude!.toStringAsFixed(1)} m',
              ),
            ],
            if (widget.waypoint.accuracy != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                'GPS Accuracy',
                '${widget.waypoint.accuracy!.toStringAsFixed(1)} m (${widget.waypoint.accuracyDescription})',
              ),
            ],
            if (widget.waypoint.speed != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                'Speed',
                '${(widget.waypoint.speed! * 3.6).toStringAsFixed(1)} km/h',
              ),
            ],
            if (widget.waypoint.heading != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                'Heading',
                '${widget.waypoint.heading!.toStringAsFixed(0)}°',
              ),
            ],
          ],
        ),
      );
  }

  Widget _buildNameSection() => _buildSection(
        title: 'Name',
        icon: Icons.label,
        child: _isEditing
            ? TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Enter waypoint name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              )
            : Text(
                widget.waypoint.name?.isNotEmpty == true
                    ? widget.waypoint.name!
                    : 'No name set',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: widget.waypoint.name?.isNotEmpty == true
                          ? null
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                      fontStyle: widget.waypoint.name?.isNotEmpty == true
                          ? null
                          : FontStyle.italic,
                    ),
              ),
      );

  Widget _buildNotesSection() => _buildSection(
        title: 'Notes',
        icon: Icons.note,
        child: _isEditing
            ? TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  hintText: 'Add notes about this waypoint',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
              )
            : Text(
                widget.waypoint.notes?.isNotEmpty == true
                    ? widget.waypoint.notes!
                    : 'No notes added',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: widget.waypoint.notes?.isNotEmpty == true
                          ? null
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                      fontStyle: widget.waypoint.notes?.isNotEmpty == true
                          ? null
                          : FontStyle.italic,
                    ),
              ),
      );

  Widget _buildPhotosSection() => _buildSection(
        title: 'Photos',
        icon: Icons.photo_library,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add photo button (when not editing)
            if (!_isEditing) ...[
              ElevatedButton.icon(
                onPressed: _capturePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Add Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Photo grid
            if (_isLoadingPhotos)
              const Center(child: CircularProgressIndicator())
            else if (_photos.isEmpty)
              Text(
                'No photos added',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
              )
            else
              _buildPhotoGrid(),
          ],
        ),
      );

  Widget _buildPhotoGrid() => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _photos.length,
        itemBuilder: (BuildContext context, int index) {
          final PhotoWaypoint photo = _photos[index];
          return _buildPhotoThumbnail(photo, index);
        },
      );

  Widget _buildPhotoThumbnail(PhotoWaypoint photo, int index) =>
      GestureDetector(
        onTap: () => _openPhotoViewer(index),
        onLongPress: () => _showPhotoOptions(photo),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FutureBuilder<File>(
            future: _resolvePhotoFile(photo.filePath),
            builder: (BuildContext context, AsyncSnapshot<File> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ColoredBox(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return ColoredBox(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }

              return Image.file(
                snapshot.data!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

  Future<File> _resolvePhotoFile(String photoPath) async {
    if (photoPath.startsWith('/')) {
      return File(photoPath);
    }
    final Directory docs = await getApplicationDocumentsDirectory();
    final String absolutePath = path.join(docs.path, photoPath);
    return File(absolutePath);
  }

  void _openPhotoViewer(int index) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => FullscreenPhotoViewer(
          photoWaypoint: _photos[index],
          allPhotos: _photos,
          initialIndex: index,
          waypoints: <Waypoint>[widget.waypoint],
        ),
      ),
    );
  }

  Future<void> _capturePhoto() async {
    // Get sessionId for photo storage (may be null for standalone waypoints)
    final String sessionId =
        widget.waypoint.sessionId ?? 'standalone_${widget.waypoint.id}';

    final PhotoCaptureResult? result = await showCameraPreview(
      context,
      sessionId: sessionId,
      waypointName: widget.waypoint.displayName,
    );

    if (result != null && result.success && result.photoWaypoint != null) {
      // Re-associate the photo with this existing waypoint
      // The camera creates a new waypoint, but we want to link the photo to this one
      await _mediaService.addPhotoToWaypoint(
        waypointId: widget.waypoint.id,
        filePath: result.photoWaypoint!.filePath,
        fileSize: result.photoWaypoint!.fileSize,
        width: result.photoWaypoint!.width,
        height: result.photoWaypoint!.height,
        devicePitch: result.photoWaypoint!.devicePitch,
        deviceRoll: result.photoWaypoint!.deviceRoll,
        deviceYaw: result.photoWaypoint!.deviceYaw,
        photoOrientation: result.photoWaypoint!.photoOrientation,
        cameraTiltAngle: result.photoWaypoint!.cameraTiltAngle,
        source: result.photoWaypoint!.source,
        thumbnailPath: result.photoWaypoint!.thumbnailPath,
      );

      // Reload photos to show the new one
      await _loadPhotos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showPhotoOptions(PhotoWaypoint photo) async {
    final bool? shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Photo'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );

    if (shouldDelete == true) {
      await _deletePhoto(photo);
    }
  }

  Future<void> _deletePhoto(PhotoWaypoint photo) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text(
            'Are you sure you want to delete this photo? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final bool success = await _mediaService.deletePhoto(photo.id);

      if (success) {
        await _loadPhotos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete photo'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildVoiceNotesSection() {
    final VoiceNoteState voiceNoteState = ref.watch(voiceNoteProvider);

    return _buildSection(
      title: 'Voice Notes',
      icon: Icons.mic,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Voice recording widget
          if (_showVoiceRecording) ...[
            VoiceRecordingWidget(
              onRecordingComplete: _onVoiceRecordingComplete,
              onRecordingCancel: () =>
                  setState(() => _showVoiceRecording = false),
            ),
            const SizedBox(height: 16),
          ],

          // Add voice note button
          if (!_showVoiceRecording && !_isEditing) ...[
            ElevatedButton.icon(
              onPressed: () => setState(() => _showVoiceRecording = true),
              icon: const Icon(Icons.mic),
              label: const Text('Add Voice Note'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Voice notes list
          if (voiceNoteState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (voiceNoteState.error != null)
            Container(
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
                      voiceNoteState.error!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.red,
                          ),
                    ),
                  ),
                ],
              ),
            )
          else
            VoiceNoteListWidget(
              voiceNotes: voiceNoteState.voiceNotes,
              onDeleteVoiceNote: _onDeleteVoiceNote,
              showDeleteButtons: !_isEditing,
            ),
        ],
      ),
    );
  }

  Widget _buildMetadataSection() => _buildSection(
        title: 'Details',
        icon: Icons.info,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('ID', widget.waypoint.id),
            const SizedBox(height: 8),
            _buildInfoRow(
                'Session ID',
                widget.waypoint.sessionId ?? 'Standalone'),
            const SizedBox(height: 8),
            _buildInfoRow(
                'Created', _formatDateTime(widget.waypoint.timestamp)),
          ],
        ),
      );

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      );

  Widget _buildInfoRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final String? name = _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim();
      final String? notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      final Waypoint updatedWaypoint = widget.waypoint.copyWith(
        name: name,
        notes: notes,
      );

      final WaypointNotifier waypointNotifier =
          ref.read(waypointProvider.notifier);
      final bool success =
          await waypointNotifier.updateWaypoint(updatedWaypoint);

      if (success && mounted) {
        setState(() {
          _isEditing = false;
          _hasChanges = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Waypoint updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        final WaypointState waypointState = ref.read(waypointProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(waypointState.error ?? 'Failed to update waypoint'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating waypoint: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) =>
      '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

  /// Handle voice recording completion
  Future<void> _onVoiceRecordingComplete(VoiceRecordingResult result) async {
    setState(() {
      _showVoiceRecording = false;
    });

    if (!result.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to record voice note'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // Create voice note from recording result
      final VoiceRecordingService recordingService =
          ref.read(voiceRecordingServiceProvider);
      final VoiceNote voiceNote = recordingService.createVoiceNote(
        waypointId: widget.waypoint.id,
        result: result,
      );

      // Save to database
      final bool success =
          await ref.read(voiceNoteProvider.notifier).addVoiceNote(voiceNote);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice note saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save voice note'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving voice note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle voice note deletion
  Future<void> _onDeleteVoiceNote(VoiceNote voiceNote) async {
    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Voice Note'),
        content: const Text(
            'Are you sure you want to delete this voice note? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final bool success = await ref
          .read(voiceNoteProvider.notifier)
          .deleteVoiceNote(voiceNote.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                success ? 'Voice note deleted' : 'Failed to delete voice note'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}
