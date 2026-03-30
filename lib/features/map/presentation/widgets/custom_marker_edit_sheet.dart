import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/custom_marker.dart';
import 'package:obsession_tracker/core/models/marker_attachment.dart';
import 'package:obsession_tracker/core/providers/custom_markers_provider.dart';
import 'package:obsession_tracker/core/services/marker_attachment_service.dart';
import 'package:obsession_tracker/core/services/voice_recording_service.dart';
import 'package:obsession_tracker/features/map/presentation/pages/marker_attachment_viewer.dart';
import 'package:obsession_tracker/features/map/presentation/pages/marker_camera_page.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/voice_recording_widget.dart';

/// Bottom sheet for editing an existing custom marker
class CustomMarkerEditSheet extends ConsumerStatefulWidget {
  const CustomMarkerEditSheet({
    super.key,
    required this.marker,
  });

  final CustomMarker marker;

  @override
  ConsumerState<CustomMarkerEditSheet> createState() =>
      _CustomMarkerEditSheetState();
}

class _CustomMarkerEditSheetState extends ConsumerState<CustomMarkerEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late CustomMarkerCategory _selectedCategory;
  bool _isSaving = false;
  bool _isAddingAttachment = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.marker.name);
    _notesController = TextEditingController(text: widget.marker.notes ?? '');
    _selectedCategory = widget.marker.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveMarker() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final operations = ref.read(customMarkerOperationsProvider.notifier);

      // Create updated marker
      final updatedMarker = widget.marker.copyWith(
        name: _nameController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        clearNotes: _notesController.text.trim().isEmpty,
        category: _selectedCategory,
        // Update color if category changed
        colorArgb: _selectedCategory != widget.marker.category
            ? _selectedCategory.defaultColor.toARGB32()
            : null,
      );

      final result = await operations.updateMarker(updatedMarker);

      if (result != null && mounted) {
        Navigator.pop(context, result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated marker "${result.name}"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update marker: $e'),
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

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _takePhoto() async {
    _dismissKeyboard();
    // Open the camera page
    final result = await showMarkerCamera(
      context,
      markerId: widget.marker.id,
    );

    // If photo was taken and saved, refresh attachments
    if (result == true && mounted) {
      ref.invalidate(markerAttachmentsProvider(widget.marker.id));
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
        final fileName = result.files.first.name;

        final service = MarkerAttachmentService();
        await service.addImage(
          markerId: widget.marker.id,
          name: fileName,
          imageFile: file,
        );

        // Invalidate attachments provider to refresh
        ref.invalidate(markerAttachmentsProvider(widget.marker.id));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added photo "$fileName"'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingAttachment = false);
      }
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
          'txt',
          'doc',
          'docx',
          'csv',
          'gpx',
          'kml',
          'kmz',
          'json',
          'xml',
        ],
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        final file = File(result.files.first.path!);
        final fileName = result.files.first.name;
        final extension = fileName.split('.').last.toLowerCase();

        final service = MarkerAttachmentService();

        if (extension == 'pdf') {
          await service.addPdf(
            markerId: widget.marker.id,
            name: fileName,
            pdfFile: file,
          );
        } else {
          await service.addDocument(
            markerId: widget.marker.id,
            name: fileName,
            documentFile: file,
          );
        }

        // Invalidate attachments provider to refresh
        ref.invalidate(markerAttachmentsProvider(widget.marker.id));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added document "$fileName"'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add document: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
                labelText: 'Title',
                hintText: 'Enter link title',
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com',
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
        nameController.text.trim().isNotEmpty &&
        urlController.text.trim().isNotEmpty) {
      setState(() => _isAddingAttachment = true);

      try {
        final service = MarkerAttachmentService();
        await service.addLink(
          markerId: widget.marker.id,
          name: nameController.text.trim(),
          url: urlController.text.trim(),
        );

        // Invalidate attachments provider to refresh
        ref.invalidate(markerAttachmentsProvider(widget.marker.id));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added link "${nameController.text.trim()}"'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add link: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isAddingAttachment = false);
        }
      }
    }

    nameController.dispose();
    urlController.dispose();
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
      setState(() => _isAddingAttachment = true);

      try {
        final service = MarkerAttachmentService();
        final duration = Duration(milliseconds: result.duration);
        final durationStr =
            '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

        await service.addAudio(
          markerId: widget.marker.id,
          name: 'Voice memo ($durationStr)',
          audioFile: File(result.filePath!),
        );

        // Invalidate attachments provider to refresh
        ref.invalidate(markerAttachmentsProvider(widget.marker.id));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added voice memo ($durationStr)'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add voice memo: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isAddingAttachment = false);
        }
      }
    }
  }

  Future<void> _deleteAttachment(MarkerAttachment attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Attachment'),
        content: Text('Delete "${attachment.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final service = MarkerAttachmentService();
        await service.deleteAttachment(attachment.id);

        // Invalidate attachments provider to refresh
        ref.invalidate(markerAttachmentsProvider(widget.marker.id));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${attachment.name}"'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Watch attachments for this marker
    final attachmentsAsync =
        ref.watch(markerAttachmentsProvider(widget.marker.id));

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
                            'Edit Marker',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${widget.marker.latitude.toStringAsFixed(5)}, ${widget.marker.longitude.toStringAsFixed(5)}',
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
              attachmentsAsync.when(
                data: (attachments) =>
                    _buildAttachmentsSection(context, attachments),
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error loading attachments',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
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
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _saveMarker,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
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

  Widget _buildAttachmentsSection(
    BuildContext context,
    List<MarkerAttachment> attachments,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                attachments.isEmpty
                    ? 'Attachments'
                    : 'Attachments (${attachments.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_isAddingAttachment)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
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

          // Existing attachments
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 12),

            // Separate images from other attachments
            Builder(builder: (context) {
              final images = attachments
                  .where((a) => a.type == MarkerAttachmentType.image)
                  .toList();
              final others = attachments
                  .where((a) => a.type != MarkerAttachmentType.image)
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image gallery grid
                  if (images.isNotEmpty) ...[
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final image = images[index];
                          return _ImageThumbnail(
                            attachment: image,
                            onTap: () async {
                              await showMarkerAttachmentViewer(
                                context,
                                attachment: image,
                                allAttachments: images,
                                initialIndex: index,
                              );
                              // Refresh attachments in case rotation was changed
                              ref.invalidate(markerAttachmentsProvider(widget.marker.id));
                            },
                            onDelete: () => _deleteAttachment(image),
                          );
                        },
                      ),
                    ),
                    if (others.isNotEmpty) const SizedBox(height: 12),
                  ],

                  // Other attachments as chips
                  if (others.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: others.map((attachment) {
                        final index = attachments.indexOf(attachment);
                        return InputChip(
                          avatar: Text(attachment.type.icon),
                          label: Text(
                            attachment.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => showMarkerAttachmentViewer(
                            context,
                            attachment: attachment,
                            allAttachments: attachments,
                            initialIndex: index,
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _deleteAttachment(attachment),
                        );
                      }).toList(),
                    ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: onTap == null
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: onTap == null
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Image thumbnail with delete button overlay
class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({
    required this.attachment,
    required this.onTap,
    required this.onDelete,
  });

  final MarkerAttachment attachment;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final filePath = attachment.thumbnailPath ?? attachment.filePath;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Image thumbnail
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.3),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: filePath != null
                ? _buildRotatedImage(filePath)
                : const Center(
                    child: Icon(
                      Icons.image,
                      color: Colors.grey,
                    ),
                  ),
          ),

          // Delete button overlay
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRotatedImage(String filePath) {
    Widget imageWidget = Image.file(
      File(filePath),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.grey,
          ),
        );
      },
    );

    // Apply rotation if needed
    final rotation = attachment.userRotation;
    if (rotation != null && rotation != 0) {
      imageWidget = RotatedBox(
        quarterTurns: rotation,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// Helper function to show the custom marker edit sheet
Future<CustomMarker?> showCustomMarkerEditSheet(
  BuildContext context, {
  required CustomMarker marker,
}) {
  return showModalBottomSheet<CustomMarker>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: CustomMarkerEditSheet(
        marker: marker,
      ),
    ),
  );
}
