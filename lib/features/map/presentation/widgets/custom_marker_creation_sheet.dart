import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/custom_marker.dart';
import 'package:obsession_tracker/core/models/marker_attachment.dart';
import 'package:obsession_tracker/core/providers/custom_markers_provider.dart';
import 'package:obsession_tracker/core/services/marker_attachment_service.dart';
import 'package:obsession_tracker/core/services/voice_recording_service.dart';
import 'package:obsession_tracker/features/map/presentation/pages/pending_photo_camera_page.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/voice_recording_widget.dart';

/// Bottom sheet for creating a new custom marker at a specific location
///
/// Can optionally be associated with a tracking session via [sessionId].
/// When sessionId is provided, the marker will be linked to that session.
class CustomMarkerCreationSheet extends ConsumerStatefulWidget {
  const CustomMarkerCreationSheet({
    super.key,
    required this.latitude,
    required this.longitude,
    this.sessionId,
  });

  final double latitude;
  final double longitude;

  /// Optional session ID to associate this marker with a tracking session
  final String? sessionId;

  @override
  ConsumerState<CustomMarkerCreationSheet> createState() =>
      _CustomMarkerCreationSheetState();
}

class _CustomMarkerCreationSheetState
    extends ConsumerState<CustomMarkerCreationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  CustomMarkerCategory _selectedCategory = CustomMarkerCategory.researchLead;
  bool _isCreating = false;

  // Pending attachments to add after marker is created
  final List<_PendingAttachment> _pendingAttachments = [];
  bool _isAddingAttachment = false;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    // Clean up any pending attachment files if user cancels
    for (final attachment in _pendingAttachments) {
      if (attachment.file != null) {
        try {
          attachment.file!.delete();
        } catch (_) {}
      }
    }
    super.dispose();
  }

  Future<void> _createMarker() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final operations = ref.read(customMarkerOperationsProvider.notifier);
      final marker = await operations.createMarker(
        latitude: widget.latitude,
        longitude: widget.longitude,
        name: _nameController.text.trim(),
        category: _selectedCategory,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        sessionId: widget.sessionId,
      );

      if (marker != null && mounted) {
        // Save any pending attachments
        if (_pendingAttachments.isNotEmpty) {
          await _savePendingAttachments(marker.id);
        }

        // Auto-enable visibility when creating first marker
        final visibility = ref.read(customMarkersVisibilityProvider);
        if (!visibility) {
          ref.read(customMarkersVisibilityProvider.notifier).set(value: true);
        }

        Navigator.pop(context, marker);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created marker "${marker.name}"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create marker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _savePendingAttachments(String markerId) async {
    final service = MarkerAttachmentService();

    for (final attachment in _pendingAttachments) {
      try {
        switch (attachment.type) {
          case MarkerAttachmentType.image:
            if (attachment.file != null) {
              await service.addImage(
                markerId: markerId,
                name: attachment.name,
                imageFile: attachment.file!,
              );
            }
          case MarkerAttachmentType.audio:
            if (attachment.file != null) {
              await service.addAudio(
                markerId: markerId,
                name: attachment.name,
                audioFile: attachment.file!,
              );
            }
          case MarkerAttachmentType.pdf:
            if (attachment.file != null) {
              await service.addPdf(
                markerId: markerId,
                name: attachment.name,
                pdfFile: attachment.file!,
              );
            }
          case MarkerAttachmentType.document:
            if (attachment.file != null) {
              await service.addDocument(
                markerId: markerId,
                name: attachment.name,
                documentFile: attachment.file!,
              );
            }
          case MarkerAttachmentType.note:
            // Note attachments are not supported in creation flow
            // (use the marker's notes field instead)
            break;
          case MarkerAttachmentType.link:
            if (attachment.url != null) {
              await service.addLink(
                markerId: markerId,
                name: attachment.name,
                url: attachment.url!,
              );
            }
        }
      } catch (e) {
        debugPrint('Failed to save attachment ${attachment.name}: $e');
      }
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _takePhoto() async {
    _dismissKeyboard();
    // Open camera to capture a new photo
    final file = await showPendingPhotoCamera(context);

    if (file != null && mounted) {
      final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      setState(() {
        _pendingAttachments.add(_PendingAttachment(
          type: MarkerAttachmentType.image,
          name: fileName,
          file: file,
        ));
      });
    }
  }

  Future<void> _addPhotoFromGallery() async {
    _dismissKeyboard();
    setState(() => _isAddingAttachment = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        final file = File(result.files.first.path!);
        setState(() {
          _pendingAttachments.add(_PendingAttachment(
            type: MarkerAttachmentType.image,
            name: result.files.first.name,
            file: file,
          ));
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingAttachment = false);
      }
    }
  }

  Future<void> _addVoice() async {
    _dismissKeyboard();
    final result = await showDialog<VoiceRecordingResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Record Voice Memo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              VoiceRecordingWidget(
                onRecordingComplete: (voiceResult) {
                  Navigator.pop(context, voiceResult);
                },
                onRecordingCancel: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null && result.success && result.filePath != null) {
      final duration = Duration(milliseconds: result.duration);
      final durationStr =
          '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

      setState(() {
        _pendingAttachments.add(_PendingAttachment(
          type: MarkerAttachmentType.audio,
          name: 'Voice memo ($durationStr)',
          file: File(result.filePath!),
        ));
      });
    }
  }

  Future<void> _addDocument() async {
    _dismissKeyboard();
    setState(() => _isAddingAttachment = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'txt',
          'rtf',
          'gpx',
          'kml',
          'kmz',
        ],
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        final file = File(result.files.first.path!);
        final extension = result.files.first.extension?.toLowerCase() ?? '';
        final type = extension == 'pdf'
            ? MarkerAttachmentType.pdf
            : MarkerAttachmentType.document;

        setState(() {
          _pendingAttachments.add(_PendingAttachment(
            type: type,
            name: result.files.first.name,
            file: file,
          ));
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingAttachment = false);
      }
    }
  }

  Future<void> _addLink() async {
    _dismissKeyboard();
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter link name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true &&
        nameController.text.isNotEmpty &&
        urlController.text.isNotEmpty) {
      setState(() {
        _pendingAttachments.add(_PendingAttachment(
          type: MarkerAttachmentType.link,
          name: nameController.text,
          url: urlController.text,
        ));
      });
    }

    nameController.dispose();
    urlController.dispose();
  }

  void _removePendingAttachment(int index) {
    final attachment = _pendingAttachments[index];
    // Delete file if it exists
    if (attachment.file != null) {
      try {
        attachment.file!.delete();
      } catch (_) {}
    }
    setState(() {
      _pendingAttachments.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _selectedCategory.defaultColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _selectedCategory.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Marker',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Name field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter a name for this marker',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                autofocus: true,
              ),
            ),

            const SizedBox(height: 16),

            // Category selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CustomMarkerCategory.values.map((category) {
                      final isSelected = category == _selectedCategory;
                      return FilterChip(
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          }
                        },
                        avatar: Text(
                          category.emoji,
                          style: const TextStyle(fontSize: 14),
                        ),
                        label: Text(
                          category.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selectedColor: category.defaultColor.withValues(alpha: 0.3),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Notes field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Add any notes about this location',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),

            const SizedBox(height: 16),

            // Attachments section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attachments (optional)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Add attachment buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _AttachmentButton(
                          icon: Icons.camera_alt,
                          label: 'Camera',
                          onTap: _isAddingAttachment ? null : _takePhoto,
                        ),
                        const SizedBox(width: 8),
                        _AttachmentButton(
                          icon: Icons.photo_library,
                          label: 'Gallery',
                          onTap: _isAddingAttachment ? null : _addPhotoFromGallery,
                        ),
                        const SizedBox(width: 8),
                        _AttachmentButton(
                          icon: Icons.mic,
                          label: 'Voice',
                          onTap: _isAddingAttachment ? null : _addVoice,
                        ),
                        const SizedBox(width: 8),
                        _AttachmentButton(
                          icon: Icons.attach_file,
                          label: 'Document',
                          onTap: _isAddingAttachment ? null : _addDocument,
                        ),
                        const SizedBox(width: 8),
                        _AttachmentButton(
                          icon: Icons.link,
                          label: 'Link',
                          onTap: _isAddingAttachment ? null : _addLink,
                        ),
                      ],
                    ),
                  ),

                  // Pending attachments list
                  if (_pendingAttachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _pendingAttachments.asMap().entries.map((entry) {
                        final index = entry.key;
                        final attachment = entry.value;
                        return InputChip(
                          avatar: Text(attachment.type.icon),
                          label: Text(
                            attachment.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removePendingAttachment(index),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Privacy notice
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue.withValues(alpha: 0.1)
                      : Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your markers stay on your device. Only shared when you choose to export.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isCreating ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _isCreating ? null : _createMarker,
                      icon: _isCreating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_location_alt),
                      label: Text(_isCreating ? 'Creating...' : 'Create Marker'),
                    ),
                  ),
                ],
              ),
            ),

              // Bottom padding for safe area
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Helper function to show the custom marker creation sheet
///
/// If [sessionId] is provided, the created marker will be associated
/// with that tracking session.
Future<CustomMarker?> showCustomMarkerCreationSheet(
  BuildContext context, {
  required double latitude,
  required double longitude,
  String? sessionId,
}) {
  return showModalBottomSheet<CustomMarker>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: CustomMarkerCreationSheet(
        latitude: latitude,
        longitude: longitude,
        sessionId: sessionId,
      ),
    ),
  );
}

/// Represents a pending attachment to be added after marker creation
class _PendingAttachment {
  _PendingAttachment({
    required this.type,
    required this.name,
    this.file,
    this.url,
  });

  final MarkerAttachmentType type;
  final String name;
  final File? file;
  final String? url;
}

/// Small button for adding attachments
class _AttachmentButton extends StatelessWidget {
  const _AttachmentButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: onTap == null
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: onTap == null
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
