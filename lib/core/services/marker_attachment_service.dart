import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:obsession_tracker/core/models/marker_attachment.dart';
import 'package:obsession_tracker/core/services/custom_marker_service.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

/// Service for managing custom marker attachments.
///
/// Provides a complete API for adding, updating, and deleting attachments
/// (images, PDFs, documents, notes, links) associated with custom markers.
///
/// Features:
/// - File-based attachment storage (images, PDFs, documents)
/// - Inline content storage (notes, links)
/// - Thumbnail generation for images
/// - UUID-based file naming for privacy
class MarkerAttachmentService {
  factory MarkerAttachmentService() =>
      _instance ??= MarkerAttachmentService._();
  MarkerAttachmentService._();
  static MarkerAttachmentService? _instance;

  static const Uuid _uuid = Uuid();
  final DatabaseService _db = DatabaseService();
  final CustomMarkerService _markerService = CustomMarkerService();

  /// Subdirectories within marker directory
  static const String _imagesDir = 'images';
  static const String _pdfsDir = 'pdfs';
  static const String _documentsDir = 'documents';
  static const String _thumbnailsDir = 'thumbnails';
  static const String _audioDir = 'audio';

  /// Thumbnail size for image previews
  static const int _thumbnailSize = 200;

  // ============================================================
  // Directory Management
  // ============================================================

  /// Get the images directory for a marker
  Future<Directory> _getImagesDirectory(String markerId) async {
    final Directory markerDir = await _markerService.getMarkerDirectory(markerId);
    final Directory imagesDir = Directory(
      path.join(markerDir.path, _imagesDir),
    );

    if (!imagesDir.existsSync()) {
      await imagesDir.create(recursive: true);
    }

    return imagesDir;
  }

  /// Get the PDFs directory for a marker
  Future<Directory> _getPdfsDirectory(String markerId) async {
    final Directory markerDir = await _markerService.getMarkerDirectory(markerId);
    final Directory pdfsDir = Directory(
      path.join(markerDir.path, _pdfsDir),
    );

    if (!pdfsDir.existsSync()) {
      await pdfsDir.create(recursive: true);
    }

    return pdfsDir;
  }

  /// Get the documents directory for a marker
  Future<Directory> _getDocumentsDirectory(String markerId) async {
    final Directory markerDir = await _markerService.getMarkerDirectory(markerId);
    final Directory docsDir = Directory(
      path.join(markerDir.path, _documentsDir),
    );

    if (!docsDir.existsSync()) {
      await docsDir.create(recursive: true);
    }

    return docsDir;
  }

  /// Get the thumbnails directory for a marker
  Future<Directory> _getThumbnailsDirectory(String markerId) async {
    final Directory markerDir = await _markerService.getMarkerDirectory(markerId);
    final Directory thumbnailsDir = Directory(
      path.join(markerDir.path, _thumbnailsDir),
    );

    if (!thumbnailsDir.existsSync()) {
      await thumbnailsDir.create(recursive: true);
    }

    return thumbnailsDir;
  }

  /// Get the audio directory for a marker
  Future<Directory> _getAudioDirectory(String markerId) async {
    final Directory markerDir = await _markerService.getMarkerDirectory(markerId);
    final Directory audioDir = Directory(
      path.join(markerDir.path, _audioDir),
    );

    if (!audioDir.existsSync()) {
      await audioDir.create(recursive: true);
    }

    return audioDir;
  }

  // ============================================================
  // Thumbnail Generation
  // ============================================================

  /// Generate a thumbnail for an image file
  Future<String?> _generateThumbnail(
    String markerId,
    String imagePath,
  ) async {
    try {
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) return null;

      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Resize to thumbnail size
      final thumbnail = img.copyResize(
        image,
        width: _thumbnailSize,
        height: _thumbnailSize,
        maintainAspect: true,
      );

      // Determine output format based on original
      final extension = path.extension(imagePath).toLowerCase();
      final thumbnailsDir = await _getThumbnailsDirectory(markerId);
      final thumbnailFileName =
          '${path.basenameWithoutExtension(imagePath)}_thumb$extension';
      final thumbnailPath = path.join(thumbnailsDir.path, thumbnailFileName);

      // Encode and save
      List<int> thumbnailBytes;
      if (extension == '.png') {
        thumbnailBytes = img.encodePng(thumbnail);
      } else {
        thumbnailBytes = img.encodeJpg(thumbnail, quality: 85);
      }

      final thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(thumbnailBytes);

      debugPrint('Generated thumbnail: $thumbnailPath');
      return thumbnailPath;
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  // ============================================================
  // Add Attachments
  // ============================================================

  /// Add an image attachment to a marker
  ///
  /// [initialRotation] is the number of quarter turns to apply for proper orientation.
  /// This is useful when the device was held in landscape when capturing the photo.
  /// Values: 0=none, 1=90°CW, 2=180°, 3=270°CW (90°CCW)
  Future<MarkerAttachment> addImage({
    required String markerId,
    required String name,
    required File imageFile,
    int? initialRotation,
  }) async {
    final String id = _uuid.v4();
    final String extension = path.extension(imageFile.path).toLowerCase();
    final String fileName = '$id$extension';

    // Copy image to marker's images directory
    final Directory imagesDir = await _getImagesDirectory(markerId);
    final String destPath = path.join(imagesDir.path, fileName);
    await imageFile.copy(destPath);

    // Get file size
    final fileSize = await imageFile.length();

    // Generate thumbnail
    final String? thumbnailPath = await _generateThumbnail(markerId, destPath);

    final attachment = MarkerAttachment(
      id: id,
      markerId: markerId,
      name: name,
      type: MarkerAttachmentType.image,
      filePath: destPath,
      thumbnailPath: thumbnailPath,
      createdAt: DateTime.now(),
      fileSize: fileSize,
      userRotation: initialRotation,
    );

    await _db.insertMarkerAttachment(attachment);
    debugPrint('Added image to marker $markerId: $name${initialRotation != null ? ' (rotation: $initialRotation)' : ''}');

    return attachment;
  }

  /// Add a PDF attachment to a marker
  Future<MarkerAttachment> addPdf({
    required String markerId,
    required String name,
    required File pdfFile,
  }) async {
    final String id = _uuid.v4();
    final String fileName = '$id.pdf';

    // Copy PDF to marker's PDFs directory
    final Directory pdfsDir = await _getPdfsDirectory(markerId);
    final String destPath = path.join(pdfsDir.path, fileName);
    await pdfFile.copy(destPath);

    // Get file size
    final fileSize = await pdfFile.length();

    final attachment = MarkerAttachment(
      id: id,
      markerId: markerId,
      name: name,
      type: MarkerAttachmentType.pdf,
      filePath: destPath,
      createdAt: DateTime.now(),
      fileSize: fileSize,
    );

    await _db.insertMarkerAttachment(attachment);
    debugPrint('Added PDF to marker $markerId: $name');

    return attachment;
  }

  /// Add a document attachment to a marker (txt, doc, csv, gpx, kml, etc.)
  Future<MarkerAttachment> addDocument({
    required String markerId,
    required String name,
    required File documentFile,
  }) async {
    final String id = _uuid.v4();
    final String extension = path.extension(documentFile.path).toLowerCase();
    final String fileName = '$id$extension';

    // Copy document to marker's documents directory
    final Directory docsDir = await _getDocumentsDirectory(markerId);
    final String destPath = path.join(docsDir.path, fileName);
    await documentFile.copy(destPath);

    // Get file size
    final fileSize = await documentFile.length();

    final attachment = MarkerAttachment(
      id: id,
      markerId: markerId,
      name: name,
      type: MarkerAttachmentType.document,
      filePath: destPath,
      createdAt: DateTime.now(),
      fileSize: fileSize,
    );

    await _db.insertMarkerAttachment(attachment);
    debugPrint('Added document to marker $markerId: $name');

    return attachment;
  }

  /// Add a note attachment to a marker (stored in database, not file system)
  Future<MarkerAttachment> addNote({
    required String markerId,
    required String name,
    required String content,
  }) async {
    final String id = _uuid.v4();

    final attachment = MarkerAttachment(
      id: id,
      markerId: markerId,
      name: name,
      type: MarkerAttachmentType.note,
      content: content,
      createdAt: DateTime.now(),
    );

    await _db.insertMarkerAttachment(attachment);
    debugPrint('Added note to marker $markerId: $name');

    return attachment;
  }

  /// Add a link attachment to a marker (stored in database, not file system)
  Future<MarkerAttachment> addLink({
    required String markerId,
    required String name,
    required String url,
  }) async {
    final String id = _uuid.v4();

    final attachment = MarkerAttachment(
      id: id,
      markerId: markerId,
      name: name,
      type: MarkerAttachmentType.link,
      url: url,
      createdAt: DateTime.now(),
    );

    await _db.insertMarkerAttachment(attachment);
    debugPrint('Added link to marker $markerId: $name');

    return attachment;
  }

  /// Add an audio attachment (voice memo) to a marker
  Future<MarkerAttachment> addAudio({
    required String markerId,
    required String name,
    required File audioFile,
  }) async {
    final String id = _uuid.v4();
    final String extension = path.extension(audioFile.path).toLowerCase();
    final String fileName = '$id$extension';

    // Copy audio to marker's audio directory
    final Directory audioDir = await _getAudioDirectory(markerId);
    final String destPath = path.join(audioDir.path, fileName);
    await audioFile.copy(destPath);

    // Get file size
    final fileSize = await audioFile.length();

    final attachment = MarkerAttachment(
      id: id,
      markerId: markerId,
      name: name,
      type: MarkerAttachmentType.audio,
      filePath: destPath,
      createdAt: DateTime.now(),
      fileSize: fileSize,
    );

    await _db.insertMarkerAttachment(attachment);
    debugPrint('Added audio to marker $markerId: $name');

    return attachment;
  }

  // ============================================================
  // Read Attachments
  // ============================================================

  /// Get an attachment by ID
  Future<MarkerAttachment?> getAttachment(String attachmentId) async {
    return _db.getMarkerAttachment(attachmentId);
  }

  /// Get all attachments for a marker
  Future<List<MarkerAttachment>> getAttachmentsForMarker(
    String markerId,
  ) async {
    return _db.getAttachmentsForMarker(markerId);
  }

  /// Get attachments for a marker filtered by type
  Future<List<MarkerAttachment>> getAttachmentsByType(
    String markerId,
    MarkerAttachmentType type,
  ) async {
    return _db.getAttachmentsForMarkerByType(markerId, type);
  }

  /// Get count of attachments for a marker
  Future<int> getAttachmentCount(String markerId) async {
    return _db.getMarkerAttachmentCount(markerId);
  }

  // ============================================================
  // Update Attachments
  // ============================================================

  /// Update an attachment's name
  Future<MarkerAttachment> updateAttachmentName(
    String attachmentId,
    String newName,
  ) async {
    final attachment = await getAttachment(attachmentId);
    if (attachment == null) {
      throw Exception('Attachment not found: $attachmentId');
    }

    final updated = attachment.copyWith(
      name: newName,
      updatedAt: DateTime.now(),
    );
    await _db.updateMarkerAttachment(updated);
    return updated;
  }

  /// Update a note attachment's content
  Future<MarkerAttachment> updateNoteContent(
    String attachmentId,
    String newContent,
  ) async {
    final attachment = await getAttachment(attachmentId);
    if (attachment == null) {
      throw Exception('Attachment not found: $attachmentId');
    }
    if (attachment.type != MarkerAttachmentType.note) {
      throw Exception('Attachment is not a note: $attachmentId');
    }

    final updated = attachment.copyWith(
      content: newContent,
      updatedAt: DateTime.now(),
    );
    await _db.updateMarkerAttachment(updated);
    return updated;
  }

  /// Update a link attachment's URL
  Future<MarkerAttachment> updateLinkUrl(
    String attachmentId,
    String newUrl,
  ) async {
    final attachment = await getAttachment(attachmentId);
    if (attachment == null) {
      throw Exception('Attachment not found: $attachmentId');
    }
    if (attachment.type != MarkerAttachmentType.link) {
      throw Exception('Attachment is not a link: $attachmentId');
    }

    final updated = attachment.copyWith(
      url: newUrl,
      updatedAt: DateTime.now(),
    );
    await _db.updateMarkerAttachment(updated);
    return updated;
  }

  /// Update an image attachment's rotation
  ///
  /// [rotation] is the number of quarter turns clockwise (0-3):
  /// - 0: No rotation
  /// - 1: 90° clockwise
  /// - 2: 180°
  /// - 3: 270° clockwise (90° counter-clockwise)
  Future<MarkerAttachment> updateAttachmentRotation(
    String attachmentId,
    int rotation,
  ) async {
    final attachment = await getAttachment(attachmentId);
    if (attachment == null) {
      throw Exception('Attachment not found: $attachmentId');
    }

    // Normalize rotation to 0-3 range
    final normalizedRotation = rotation % 4;

    final updated = attachment.copyWith(
      userRotation: normalizedRotation,
      updatedAt: DateTime.now(),
    );
    await _db.updateMarkerAttachment(updated);
    debugPrint('Updated rotation for attachment $attachmentId to $normalizedRotation');
    return updated;
  }

  // ============================================================
  // Delete Attachments
  // ============================================================

  /// Delete an attachment
  ///
  /// For file-based attachments, also deletes the file and thumbnail.
  Future<void> deleteAttachment(String attachmentId) async {
    final attachment = await getAttachment(attachmentId);
    if (attachment == null) {
      debugPrint('Attachment not found for deletion: $attachmentId');
      return;
    }

    // Delete files if applicable
    if (attachment.type.hasFile && attachment.filePath != null) {
      try {
        final file = File(attachment.filePath!);
        if (await file.exists()) {
          await file.delete();
          debugPrint('Deleted attachment file: ${attachment.filePath}');
        }
      } catch (e) {
        debugPrint('Error deleting attachment file: $e');
      }
    }

    // Delete thumbnail if applicable
    if (attachment.thumbnailPath != null) {
      try {
        final thumbnail = File(attachment.thumbnailPath!);
        if (await thumbnail.exists()) {
          await thumbnail.delete();
          debugPrint('Deleted thumbnail: ${attachment.thumbnailPath}');
        }
      } catch (e) {
        debugPrint('Error deleting thumbnail: $e');
      }
    }

    // Delete from database
    await _db.deleteMarkerAttachment(attachmentId);
    debugPrint('Deleted attachment: $attachmentId');
  }

  /// Delete all attachments for a marker
  Future<void> deleteAllAttachmentsForMarker(String markerId) async {
    final attachments = await getAttachmentsForMarker(markerId);
    for (final attachment in attachments) {
      await deleteAttachment(attachment.id);
    }
    debugPrint('Deleted all ${attachments.length} attachments for marker $markerId');
  }

  // ============================================================
  // Utility Methods
  // ============================================================

  /// Check if a file exists for an attachment
  Future<bool> attachmentFileExists(String attachmentId) async {
    final attachment = await getAttachment(attachmentId);
    if (attachment == null) return false;
    if (!attachment.type.hasFile) return true; // Notes/links don't have files
    if (attachment.filePath == null) return false;

    return File(attachment.filePath!).existsSync();
  }

  /// Get total size of all attachments for a marker
  Future<int> getTotalAttachmentSize(String markerId) async {
    final attachments = await getAttachmentsForMarker(markerId);
    var totalSize = 0;
    for (final attachment in attachments) {
      if (attachment.fileSize != null) {
        totalSize += attachment.fileSize!;
      }
    }
    return totalSize;
  }
}
