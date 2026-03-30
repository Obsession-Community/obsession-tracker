import 'dart:io';

import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/photo_capture_data.dart';

/// Action the user can take on the photo preview page
enum PhotoPreviewAction {
  save,
  retake,
}

/// Result returned from the photo preview page
class PhotoPreviewResult {
  const PhotoPreviewResult({
    required this.action,
    this.note,
  });

  final PhotoPreviewAction action;
  final String? note;

  /// Create a save result with optional note
  factory PhotoPreviewResult.save({String? note}) => PhotoPreviewResult(
        action: PhotoPreviewAction.save,
        note: note?.trim().isEmpty == true ? null : note?.trim(),
      );

  /// Create a retake result
  factory PhotoPreviewResult.retake() => const PhotoPreviewResult(
        action: PhotoPreviewAction.retake,
      );
}

/// Photo preview page shown after capturing a photo
/// Allows user to add a note, save, or retake the photo
class PhotoPreviewPage extends StatefulWidget {
  const PhotoPreviewPage({
    required this.captureData,
    required this.sessionId,
    super.key,
  });

  final PhotoCaptureData captureData;
  final String sessionId;

  @override
  State<PhotoPreviewPage> createState() => _PhotoPreviewPageState();
}

class _PhotoPreviewPageState extends State<PhotoPreviewPage> {
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      PhotoPreviewResult.save(note: _noteController.text),
    );
  }

  void _retake() {
    Navigator.of(context).pop(PhotoPreviewResult.retake());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Preview'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Save',
              style: TextStyle(
                color: isDark ? Colors.white : theme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Photo preview
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildPhotoPreview(),
                  ),
                ),
              ),
            ),

            // Note input section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Note text field
                    Expanded(
                      child: TextField(
                        controller: _noteController,
                        focusNode: _noteFocusNode,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: 'Add a note about this photo...',
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Retake button
                    OutlinedButton.icon(
                      onPressed: _retake,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Retake Photo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    final orientation = widget.captureData.photoOrientation;

    // Load photo from file
    final imageWidget = Image.file(
      File(widget.captureData.photo.path),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return ColoredBox(
          color: Colors.grey.shade800,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.red, size: 48),
                SizedBox(height: 8),
                Text(
                  'Failed to load photo',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );

    // For landscape photos, rotate 90 degrees counter-clockwise
    if (orientation == 'landscape') {
      return RotatedBox(
        quarterTurns: 3, // 270° clockwise = 90° counter-clockwise
        child: imageWidget,
      );
    }

    // Portrait or unknown - display as-is
    return imageWidget;
  }
}
