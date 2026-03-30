import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:obsession_tracker/core/models/treasure_hunt.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Service for managing treasure hunts, documents, and related file operations.
///
/// Provides a complete API for the Hunt Tracker feature, handling:
/// - CRUD operations for treasure hunts
/// - Document storage (PDFs, images, notes, links)
/// - File management with UUID-based naming for privacy
/// - Thumbnail generation for images
/// - Session linking
/// - Location management
class HuntService {
  factory HuntService() => _instance ??= HuntService._();
  HuntService._();
  static HuntService? _instance;

  static const Uuid _uuid = Uuid();
  final DatabaseService _db = DatabaseService();

  /// Base directory structure: /hunts/{hunt_id}/
  static const String _huntsBaseDir = 'hunts';
  static const String _documentsDir = 'documents';
  static const String _imagesDir = 'images';
  static const String _pdfsDir = 'pdfs';
  static const String _thumbnailsDir = 'thumbnails';
  static const String _coversDir = 'covers';

  /// Thumbnail size for document previews
  static const int _thumbnailSize = 200;

  // ============================================================
  // Directory Management
  // ============================================================

  /// Get the application documents directory
  Future<Directory> get _documentsDirectory async =>
      getApplicationDocumentsDirectory();

  /// Get the base hunts directory
  Future<Directory> get _huntsDirectory async {
    final Directory docs = await _documentsDirectory;
    final Directory huntsDir = Directory(path.join(docs.path, _huntsBaseDir));

    if (!huntsDir.existsSync()) {
      await huntsDir.create(recursive: true);
    }

    return huntsDir;
  }

  /// Get the directory for a specific hunt
  Future<Directory> _getHuntDirectory(String huntId) async {
    final Directory huntsDir = await _huntsDirectory;
    final Directory huntDir = Directory(path.join(huntsDir.path, huntId));

    if (!huntDir.existsSync()) {
      await huntDir.create(recursive: true);
    }

    return huntDir;
  }

  /// Get the documents directory for a hunt
  Future<Directory> _getDocumentsDirectory(String huntId) async {
    final Directory huntDir = await _getHuntDirectory(huntId);
    final Directory docsDir = Directory(
      path.join(huntDir.path, _documentsDir),
    );

    if (!docsDir.existsSync()) {
      await docsDir.create(recursive: true);
    }

    return docsDir;
  }

  /// Get the images directory for a hunt
  Future<Directory> _getImagesDirectory(String huntId) async {
    final Directory huntDir = await _getHuntDirectory(huntId);
    final Directory imagesDir = Directory(
      path.join(huntDir.path, _imagesDir),
    );

    if (!imagesDir.existsSync()) {
      await imagesDir.create(recursive: true);
    }

    return imagesDir;
  }

  /// Get the PDFs directory for a hunt
  Future<Directory> _getPdfsDirectory(String huntId) async {
    final Directory huntDir = await _getHuntDirectory(huntId);
    final Directory pdfsDir = Directory(
      path.join(huntDir.path, _pdfsDir),
    );

    if (!pdfsDir.existsSync()) {
      await pdfsDir.create(recursive: true);
    }

    return pdfsDir;
  }

  /// Get the thumbnails directory for a hunt
  Future<Directory> _getThumbnailsDirectory(String huntId) async {
    final Directory huntDir = await _getHuntDirectory(huntId);
    final Directory thumbnailsDir = Directory(
      path.join(huntDir.path, _thumbnailsDir),
    );

    if (!thumbnailsDir.existsSync()) {
      await thumbnailsDir.create(recursive: true);
    }

    return thumbnailsDir;
  }

  /// Get the covers directory (shared across all hunts)
  Future<Directory> get _coversDirectory async {
    final Directory huntsDir = await _huntsDirectory;
    final Directory coversDir = Directory(
      path.join(huntsDir.path, _coversDir),
    );

    if (!coversDir.existsSync()) {
      await coversDir.create(recursive: true);
    }

    return coversDir;
  }

  // ============================================================
  // Treasure Hunt CRUD
  // ============================================================

  /// Create a new treasure hunt
  Future<TreasureHunt> createHunt({
    required String name,
    String? author,
    String? description,
    List<String> tags = const [],
    File? coverImage,
  }) async {
    final String id = _uuid.v4();
    final DateTime now = DateTime.now();

    String? coverImagePath;
    if (coverImage != null) {
      coverImagePath = await _saveCoverImage(id, coverImage);
    }

    final hunt = TreasureHunt(
      id: id,
      name: name,
      author: author,
      description: description,
      tags: tags,
      coverImagePath: coverImagePath,
      createdAt: now,
      startedAt: now,
    );

    await _db.insertTreasureHunt(hunt);
    debugPrint('Created treasure hunt: ${hunt.name} (${hunt.id})');

    return hunt;
  }

  /// Update an existing treasure hunt
  Future<TreasureHunt> updateHunt(
    TreasureHunt hunt, {
    File? newCoverImage,
  }) async {
    TreasureHunt updatedHunt = hunt;
    debugPrint('HuntService.updateHunt: Starting update for "${hunt.name}" (${hunt.id})');
    debugPrint('HuntService.updateHunt: Input coverImagePath: ${hunt.coverImagePath}');
    debugPrint('HuntService.updateHunt: newCoverImage provided: ${newCoverImage != null}');

    if (newCoverImage != null) {
      // Delete ALL old cover images for this hunt (handles extension changes)
      final Directory coversDir = await _coversDirectory;
      if (coversDir.existsSync()) {
        final prefix = '${hunt.id}_cover';
        await for (final entity in coversDir.list()) {
          if (entity is File && path.basename(entity.path).startsWith(prefix)) {
            try {
              await entity.delete();
              debugPrint('Deleted old cover: ${entity.path}');
            } catch (e) {
              debugPrint('Failed to delete old cover: $e');
            }
          }
        }
      }

      // Save new cover image
      final coverPath = await _saveCoverImage(hunt.id, newCoverImage);
      debugPrint('HuntService.updateHunt: New cover saved at: $coverPath');
      updatedHunt = hunt.copyWith(coverImagePath: coverPath);
      debugPrint('HuntService.updateHunt: Updated hunt coverImagePath: ${updatedHunt.coverImagePath}');
    }

    debugPrint('HuntService.updateHunt: Saving to database with coverImagePath: ${updatedHunt.coverImagePath}');
    await _db.updateTreasureHunt(updatedHunt);
    debugPrint('HuntService.updateHunt: Completed for "${updatedHunt.name}"');

    return updatedHunt;
  }

  /// Get a treasure hunt by ID
  Future<TreasureHunt?> getHunt(String huntId) async {
    return _db.getTreasureHunt(huntId);
  }

  /// Get all treasure hunts, optionally filtered by status
  Future<List<TreasureHunt>> getAllHunts({HuntStatus? status}) async {
    return _db.getAllTreasureHunts(status: status);
  }

  /// Get active hunts (convenience method)
  Future<List<TreasureHunt>> getActiveHunts() async {
    return getAllHunts(status: HuntStatus.active);
  }

  /// Delete a treasure hunt and all associated files
  Future<void> deleteHunt(String huntId) async {
    // Get hunt to check for cover image
    final hunt = await getHunt(huntId);

    // Delete cover image if exists
    if (hunt?.coverImagePath != null) {
      final coverFile = File(hunt!.coverImagePath!);
      if (await coverFile.exists()) {
        await coverFile.delete();
      }
    }

    // Delete hunt directory and all contents
    final huntDir = await _getHuntDirectory(huntId);
    if (await huntDir.exists()) {
      await huntDir.delete(recursive: true);
    }

    // Delete from database (cascades to documents, links, locations)
    await _db.deleteTreasureHunt(huntId);
    debugPrint('Deleted treasure hunt: $huntId');
  }

  /// Update hunt status
  Future<TreasureHunt> updateHuntStatus(
    String huntId,
    HuntStatus newStatus,
  ) async {
    final hunt = await getHunt(huntId);
    if (hunt == null) {
      throw Exception('Hunt not found: $huntId');
    }

    TreasureHunt updatedHunt = hunt.copyWith(status: newStatus);

    // Set completedAt when marking as solved
    if (newStatus == HuntStatus.solved && hunt.completedAt == null) {
      updatedHunt = updatedHunt.copyWith(completedAt: DateTime.now());
    }

    await _db.updateTreasureHunt(updatedHunt);
    return updatedHunt;
  }

  /// Get hunt summary with statistics
  Future<HuntSummary> getHuntSummary(String huntId) async {
    final hunt = await getHunt(huntId);
    if (hunt == null) {
      throw Exception('Hunt not found: $huntId');
    }

    final stats = await _db.getHuntSummary(huntId);

    return HuntSummary(
      hunt: hunt,
      documentCount: stats['documents'] ?? 0,
      noteCount: stats['notes'] ?? 0,
      linkCount: stats['links'] ?? 0,
      sessionCount: stats['sessions'] ?? 0,
      locationCount: stats['locations'] ?? 0,
    );
  }

  // ============================================================
  // Document Management
  // ============================================================

  /// Add an image document to a hunt
  Future<HuntDocument> addImage({
    required String huntId,
    required String name,
    required File imageFile,
  }) async {
    final String id = _uuid.v4();
    final String extension = path.extension(imageFile.path).toLowerCase();
    final String fileName = '$id$extension';

    // Copy image to hunt's images directory
    final Directory imagesDir = await _getImagesDirectory(huntId);
    final String destPath = path.join(imagesDir.path, fileName);
    await imageFile.copy(destPath);

    // Generate thumbnail
    final String? thumbnailPath = await _generateThumbnail(huntId, destPath);

    final document = HuntDocument(
      id: id,
      huntId: huntId,
      name: name,
      type: HuntDocumentType.image,
      filePath: destPath,
      thumbnailPath: thumbnailPath,
      createdAt: DateTime.now(),
    );

    await _db.insertHuntDocument(document);
    debugPrint('Added image to hunt $huntId: $name');

    return document;
  }

  /// Add a PDF document to a hunt
  Future<HuntDocument> addPdf({
    required String huntId,
    required String name,
    required File pdfFile,
  }) async {
    final String id = _uuid.v4();
    final String fileName = '$id.pdf';

    // Copy PDF to hunt's PDFs directory
    final Directory pdfsDir = await _getPdfsDirectory(huntId);
    final String destPath = path.join(pdfsDir.path, fileName);
    await pdfFile.copy(destPath);

    final document = HuntDocument(
      id: id,
      huntId: huntId,
      name: name,
      type: HuntDocumentType.pdf,
      filePath: destPath,
      createdAt: DateTime.now(),
    );

    await _db.insertHuntDocument(document);
    debugPrint('Added PDF to hunt $huntId: $name');

    return document;
  }

  /// Add a note (text/markdown) to a hunt
  Future<HuntDocument> addNote({
    required String huntId,
    required String name,
    required String content,
  }) async {
    final String id = _uuid.v4();

    final document = HuntDocument(
      id: id,
      huntId: huntId,
      name: name,
      type: HuntDocumentType.note,
      content: content,
      createdAt: DateTime.now(),
    );

    await _db.insertHuntDocument(document);
    debugPrint('Added note to hunt $huntId: $name');

    return document;
  }

  /// Add a link to a hunt
  Future<HuntDocument> addLink({
    required String huntId,
    required String name,
    required String url,
  }) async {
    final String id = _uuid.v4();

    final document = HuntDocument(
      id: id,
      huntId: huntId,
      name: name,
      type: HuntDocumentType.link,
      url: url,
      createdAt: DateTime.now(),
    );

    await _db.insertHuntDocument(document);
    debugPrint('Added link to hunt $huntId: $name');

    return document;
  }

  /// Add a generic document (txt, doc, docx, csv, etc.) to a hunt
  Future<HuntDocument> addDocument({
    required String huntId,
    required String name,
    required File documentFile,
  }) async {
    final String id = _uuid.v4();
    final String extension = path.extension(documentFile.path).toLowerCase();
    final String fileName = '$id$extension';

    // Copy document to hunt's documents directory
    final Directory docsDir = await _getDocumentsDirectory(huntId);
    final String destPath = path.join(docsDir.path, fileName);
    await documentFile.copy(destPath);

    final document = HuntDocument(
      id: id,
      huntId: huntId,
      name: name,
      type: HuntDocumentType.document,
      filePath: destPath,
      createdAt: DateTime.now(),
    );

    await _db.insertHuntDocument(document);
    debugPrint('Added document to hunt $huntId: $name');

    return document;
  }

  /// Update a document
  Future<HuntDocument> updateDocument(HuntDocument document) async {
    final updated = document.copyWith(updatedAt: DateTime.now());
    await _db.updateHuntDocument(updated);
    return updated;
  }

  /// Get all documents for a hunt
  Future<List<HuntDocument>> getDocuments(
    String huntId, {
    HuntDocumentType? type,
  }) async {
    return _db.getHuntDocuments(huntId, type: type);
  }

  /// Delete a document and its files
  Future<void> deleteDocument(String documentId) async {
    // Get document to find file paths
    final documents = await _db.getHuntDocuments('');
    final document = documents.cast<HuntDocument?>().firstWhere(
          (d) => d?.id == documentId,
          orElse: () => null,
        );

    if (document != null) {
      // Delete file if exists
      if (document.filePath != null) {
        final file = File(document.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Delete thumbnail if exists
      if (document.thumbnailPath != null) {
        final thumbnail = File(document.thumbnailPath!);
        if (await thumbnail.exists()) {
          await thumbnail.delete();
        }
      }
    }

    await _db.deleteHuntDocument(documentId);
    debugPrint('Deleted document: $documentId');
  }

  // ============================================================
  // Session Links
  // ============================================================

  /// Link a tracking session to a hunt
  Future<HuntSessionLink> linkSession({
    required String huntId,
    required String sessionId,
    String? notes,
  }) async {
    final String id = _uuid.v4();

    final link = HuntSessionLink(
      id: id,
      huntId: huntId,
      sessionId: sessionId,
      notes: notes,
      createdAt: DateTime.now(),
    );

    await _db.insertHuntSessionLink(link);
    debugPrint('Linked session $sessionId to hunt $huntId');

    return link;
  }

  /// Get all session links for a hunt
  Future<List<HuntSessionLink>> getSessionLinks(String huntId) async {
    return _db.getHuntSessionLinks(huntId);
  }

  /// Get hunt IDs for a session
  Future<List<String>> getHuntsForSession(String sessionId) async {
    return _db.getHuntsForSession(sessionId);
  }

  /// Unlink a session from a hunt
  Future<void> unlinkSession(String linkId) async {
    await _db.deleteHuntSessionLink(linkId);
  }

  // ============================================================
  // Location Management
  // ============================================================

  /// Add a potential solve location to a hunt
  Future<HuntLocation> addLocation({
    required String huntId,
    required String name,
    required double latitude,
    required double longitude,
    String? notes,
  }) async {
    final String id = _uuid.v4();

    final location = HuntLocation(
      id: id,
      huntId: huntId,
      name: name,
      latitude: latitude,
      longitude: longitude,
      notes: notes,
      createdAt: DateTime.now(),
    );

    await _db.insertHuntLocation(location);
    debugPrint('Added location to hunt $huntId: $name');

    return location;
  }

  /// Update a hunt location
  Future<HuntLocation> updateLocation(HuntLocation location) async {
    await _db.updateHuntLocation(location);
    return location;
  }

  /// Mark a location as searched
  Future<HuntLocation> markLocationSearched(String locationId, String huntId) async {
    final locations = await _db.getHuntLocations(huntId);
    final location = locations.cast<HuntLocation?>().firstWhere(
          (l) => l?.id == locationId,
          orElse: () => null,
        );

    if (location == null) {
      throw Exception('Location not found: $locationId');
    }

    final updated = location.copyWith(
      status: HuntLocationStatus.searched,
      searchedAt: DateTime.now(),
    );

    await _db.updateHuntLocation(updated);
    return updated;
  }

  /// Get all locations for a hunt
  Future<List<HuntLocation>> getLocations(
    String huntId, {
    HuntLocationStatus? status,
  }) async {
    return _db.getHuntLocations(huntId, status: status);
  }

  /// Delete a hunt location
  Future<void> deleteLocation(String locationId) async {
    await _db.deleteHuntLocation(locationId);
  }

  // ============================================================
  // File Operations (Private)
  // ============================================================

  /// Save a cover image for a hunt
  ///
  /// Reads the source file bytes first to handle iOS temporary file cleanup,
  /// then writes to the permanent destination.
  Future<String> _saveCoverImage(String huntId, File sourceFile) async {
    final Directory coversDir = await _coversDirectory;

    try {
      // Read source bytes IMMEDIATELY (before iOS cleans up temp file)
      final bytes = await sourceFile.readAsBytes();
      debugPrint('Read ${bytes.length} bytes from source image');

      // Try to decode and re-encode as PNG for consistency
      final img.Image? decoded = img.decodeImage(bytes);
      if (decoded != null) {
        // Successfully decoded - save as PNG
        final String fileName = '${huntId}_cover.png';
        final String destPath = path.join(coversDir.path, fileName);
        final pngBytes = img.encodePng(decoded);
        await File(destPath).writeAsBytes(pngBytes);
        debugPrint('Saved cover image as PNG (${pngBytes.length} bytes): $destPath');
        return destPath;
      }

      // Decode failed - save with original extension
      final String sourceExt = path.extension(sourceFile.path).toLowerCase();
      final String ext = sourceExt.isNotEmpty ? sourceExt : '.jpg';
      final String fileName = '${huntId}_cover$ext';
      final String destPath = path.join(coversDir.path, fileName);
      await File(destPath).writeAsBytes(bytes);
      debugPrint('Saved cover image with original format ($ext, ${bytes.length} bytes): $destPath');
      return destPath;
    } catch (e) {
      debugPrint('Error reading source image: $e');
      // Last resort fallback - try direct copy with original extension
      final String sourceExt = path.extension(sourceFile.path).toLowerCase();
      final String ext = sourceExt.isNotEmpty ? sourceExt : '.jpg';
      final String fileName = '${huntId}_cover$ext';
      final String destPath = path.join(coversDir.path, fileName);
      await sourceFile.copy(destPath);
      debugPrint('Saved cover image via direct copy: $destPath');
      return destPath;
    }
  }

  /// Generate a thumbnail for an image
  Future<String?> _generateThumbnail(String huntId, String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final bytes = await imageFile.readAsBytes();

      final img.Image? original = img.decodeImage(bytes);
      if (original == null) {
        debugPrint('Failed to decode image for thumbnail: $imagePath');
        return null;
      }

      // Resize to thumbnail size (maintain aspect ratio)
      final img.Image thumbnail = img.copyResize(
        original,
        width: _thumbnailSize,
        height: _thumbnailSize,
        maintainAspect: true,
      );

      // Save thumbnail
      final String extension = path.extension(imagePath).toLowerCase();
      final String fileName =
          '${path.basenameWithoutExtension(imagePath)}_thumb$extension';

      final Directory thumbnailsDir = await _getThumbnailsDirectory(huntId);
      final String thumbnailPath = path.join(thumbnailsDir.path, fileName);

      final File thumbnailFile = File(thumbnailPath);
      if (extension == '.png') {
        await thumbnailFile.writeAsBytes(img.encodePng(thumbnail));
      } else {
        await thumbnailFile.writeAsBytes(img.encodeJpg(thumbnail, quality: 85));
      }

      return thumbnailPath;
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  /// Calculate total storage used by a hunt (in bytes)
  Future<int> getHuntStorageSize(String huntId) async {
    int totalSize = 0;

    final huntDir = await _getHuntDirectory(huntId);
    if (await huntDir.exists()) {
      await for (final entity in huntDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }

    // Check for cover image
    final hunt = await getHunt(huntId);
    if (hunt?.coverImagePath != null) {
      final coverFile = File(hunt!.coverImagePath!);
      if (await coverFile.exists()) {
        totalSize += await coverFile.length();
      }
    }

    return totalSize;
  }

  /// Format bytes to human readable string
  String formatStorageSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
