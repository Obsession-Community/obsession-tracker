import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Thumbnail sizes for different use cases
enum ThumbnailSize {
  /// Small thumbnail (100px)
  small(100),

  /// Medium thumbnail (200px)
  medium(200),

  /// Large thumbnail (400px)
  large(400);

  const ThumbnailSize(this.size);

  /// Size in pixels (square)
  final int size;

  /// Get the directory name for this thumbnail size
  String get directoryName => 'thumbnails_${size}px';
}

/// Service for managing photo storage, thumbnails, and file operations.
///
/// Handles secure file storage with UUID-based naming for privacy,
/// thumbnail generation, and directory management.
class PhotoStorageService {
  factory PhotoStorageService() => _instance ??= PhotoStorageService._();
  PhotoStorageService._();
  static PhotoStorageService? _instance;

  static const Uuid _uuid = Uuid();

  /// Base directory structure: /photos/sessions/{session_id}/
  static const String _photosBaseDir = 'photos';
  static const String _sessionsDir = 'sessions';
  static const String _originalsDir = 'originals';
  static const String _thumbnailsDir = 'thumbnails';

  /// Get the application documents directory
  Future<Directory> get _documentsDirectory async =>
      getApplicationDocumentsDirectory();

  /// Get the base photos directory
  Future<Directory> get _photosDirectory async {
    final Directory docs = await _documentsDirectory;
    final Directory photosDir = Directory(path.join(docs.path, _photosBaseDir));

    if (!photosDir.existsSync()) {
      await photosDir.create(recursive: true);
    }

    return photosDir;
  }

  /// Get the session photos directory
  Future<Directory> _getSessionDirectory(String sessionId) async {
    final Directory photosDir = await _photosDirectory;
    final Directory sessionDir = Directory(
      path.join(photosDir.path, _sessionsDir, sessionId),
    );

    if (!sessionDir.existsSync()) {
      await sessionDir.create(recursive: true);
    }

    return sessionDir;
  }

  /// Get the originals directory for a session
  Future<Directory> _getOriginalsDirectory(String sessionId) async {
    final Directory sessionDir = await _getSessionDirectory(sessionId);
    final Directory originalsDir = Directory(
      path.join(sessionDir.path, _originalsDir),
    );

    if (!originalsDir.existsSync()) {
      await originalsDir.create(recursive: true);
    }

    return originalsDir;
  }

  /// Get the thumbnails directory for a session and size
  Future<Directory> _getThumbnailsDirectory(
    String sessionId,
    ThumbnailSize size,
  ) async {
    final Directory sessionDir = await _getSessionDirectory(sessionId);
    final Directory thumbnailsDir = Directory(
      path.join(sessionDir.path, _thumbnailsDir, size.directoryName),
    );

    if (!thumbnailsDir.existsSync()) {
      await thumbnailsDir.create(recursive: true);
    }

    return thumbnailsDir;
  }

  /// Generate a unique filename with UUID for privacy
  String _generateUniqueFilename({String extension = 'jpg'}) {
    final String uuid = _uuid.v4();
    return '$uuid.$extension';
  }

  /// Store a photo file and return the RELATIVE file path
  /// Returns a path relative to documents directory to handle iOS container changes
  Future<String> storePhoto({
    required String sessionId,
    required Uint8List photoData,
    String extension = 'jpg',
  }) async {
    try {
      final Directory originalsDir = await _getOriginalsDirectory(sessionId);
      final String filename = _generateUniqueFilename(extension: extension);
      final File photoFile = File(path.join(originalsDir.path, filename));

      debugPrint('💾 PhotoStorageService.storePhoto() starting...');
      debugPrint('   Session ID: $sessionId');
      debugPrint('   Originals dir: ${originalsDir.path}');
      debugPrint('   Filename: $filename');
      debugPrint('   Photo data size: ${photoData.length} bytes');
      debugPrint('   Full path: ${photoFile.path}');

      await photoFile.writeAsBytes(photoData);

      final bool fileExists = photoFile.existsSync();
      final int fileSize = fileExists ? await photoFile.length() : 0;

      debugPrint('✅ Stored photo: ${photoFile.path}');
      debugPrint('   File exists after write: $fileExists');
      debugPrint('   File size after write: $fileSize bytes');

      if (!fileExists) {
        throw Exception('Photo file does not exist after writing!');
      }

      // Return RELATIVE path to handle iOS container path changes
      final String relativePath = path.join(
        _photosBaseDir,
        _sessionsDir,
        sessionId,
        _originalsDir,
        filename,
      );

      debugPrint('   Relative path: $relativePath');
      return relativePath;
    } catch (e) {
      debugPrint('❌ Error storing photo: $e');
      rethrow;
    }
  }

  /// Generate thumbnail for a photo
  Future<String?> generateThumbnail({
    required String originalPhotoPath,
    required String sessionId,
    required ThumbnailSize size,
  }) async {
    try {
      final File originalFile = File(originalPhotoPath);
      if (!originalFile.existsSync()) {
        debugPrint('Original photo file not found: $originalPhotoPath');
        return null;
      }

      // Read and decode the image
      final Uint8List imageData = await originalFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageData);

      if (image == null) {
        debugPrint('Failed to decode image: $originalPhotoPath');
        return null;
      }

      // Resize image to thumbnail size (maintaining aspect ratio)
      final img.Image thumbnail = img.copyResize(
        image,
        width: size.size,
        height: size.size,
        maintainAspect: true,
      );

      // Get thumbnail directory and generate filename
      final Directory thumbnailDir =
          await _getThumbnailsDirectory(sessionId, size);
      final String originalFilename =
          path.basenameWithoutExtension(originalPhotoPath);
      final String thumbnailFilename = '${originalFilename}_thumb.jpg';
      final File thumbnailFile =
          File(path.join(thumbnailDir.path, thumbnailFilename));

      // Encode and save thumbnail
      final Uint8List thumbnailData = Uint8List.fromList(
        img.encodeJpg(thumbnail, quality: 85),
      );
      await thumbnailFile.writeAsBytes(thumbnailData);

      debugPrint(
          'Generated ${size.directoryName} thumbnail: ${thumbnailFile.path}');
      return thumbnailFile.path;
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  /// Generate all thumbnail sizes for a photo
  Future<Map<ThumbnailSize, String?>> generateAllThumbnails({
    required String originalPhotoPath,
    required String sessionId,
  }) async {
    final Map<ThumbnailSize, String?> thumbnails = <ThumbnailSize, String?>{};

    for (final ThumbnailSize size in ThumbnailSize.values) {
      thumbnails[size] = await generateThumbnail(
        originalPhotoPath: originalPhotoPath,
        sessionId: sessionId,
        size: size,
      );
    }

    return thumbnails;
  }

  /// Get image dimensions from file
  Future<Map<String, int>?> getImageDimensions(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      if (!imageFile.existsSync()) {
        return null;
      }

      final Uint8List imageData = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageData);

      if (image == null) {
        return null;
      }

      return <String, int>{
        'width': image.width,
        'height': image.height,
      };
    } catch (e) {
      debugPrint('Error getting image dimensions: $e');
      return null;
    }
  }

  /// Get file size in bytes
  Future<int> getFileSize(String filePath) async {
    try {
      final File file = File(filePath);
      if (file.existsSync()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting file size: $e');
      return 0;
    }
  }

  /// Delete a photo and all its thumbnails
  Future<bool> deletePhoto({
    required String photoPath,
    required String sessionId,
  }) async {
    try {
      bool success = true;

      // Delete original photo
      final File originalFile = File(photoPath);
      if (originalFile.existsSync()) {
        await originalFile.delete();
        debugPrint('Deleted original photo: $photoPath');
      }

      // Delete all thumbnails
      final String originalFilename = path.basenameWithoutExtension(photoPath);
      for (final ThumbnailSize size in ThumbnailSize.values) {
        try {
          final Directory thumbnailDir =
              await _getThumbnailsDirectory(sessionId, size);
          final String thumbnailFilename = '${originalFilename}_thumb.jpg';
          final File thumbnailFile =
              File(path.join(thumbnailDir.path, thumbnailFilename));

          if (thumbnailFile.existsSync()) {
            await thumbnailFile.delete();
            debugPrint(
                'Deleted ${size.directoryName} thumbnail: ${thumbnailFile.path}');
          }
        } catch (e) {
          debugPrint('Error deleting ${size.directoryName} thumbnail: $e');
          success = false;
        }
      }

      return success;
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      return false;
    }
  }

  /// Delete all photos for a session
  Future<bool> deleteSessionPhotos(String sessionId) async {
    try {
      final Directory sessionDir = await _getSessionDirectory(sessionId);

      if (sessionDir.existsSync()) {
        await sessionDir.delete(recursive: true);
        debugPrint('Deleted all photos for session: $sessionId');
        return true;
      }

      return true; // Nothing to delete
    } catch (e) {
      debugPrint('Error deleting session photos: $e');
      return false;
    }
  }

  /// Get storage statistics for a session
  Future<Map<String, dynamic>> getSessionStorageStats(String sessionId) async {
    try {
      final Directory sessionDir = await _getSessionDirectory(sessionId);

      if (!sessionDir.existsSync()) {
        return <String, dynamic>{
          'totalFiles': 0,
          'totalSize': 0,
          'originalFiles': 0,
          'originalSize': 0,
          'thumbnailFiles': 0,
          'thumbnailSize': 0,
        };
      }

      int totalFiles = 0;
      int totalSize = 0;
      int originalFiles = 0;
      int originalSize = 0;
      int thumbnailFiles = 0;
      int thumbnailSize = 0;

      // Count originals
      final Directory originalsDir =
          Directory(path.join(sessionDir.path, _originalsDir));
      if (originalsDir.existsSync()) {
        await for (final FileSystemEntity entity in originalsDir.list()) {
          if (entity is File) {
            final int size = await entity.length();
            originalFiles++;
            originalSize += size;
            totalFiles++;
            totalSize += size;
          }
        }
      }

      // Count thumbnails
      final Directory thumbnailsBaseDir =
          Directory(path.join(sessionDir.path, _thumbnailsDir));
      if (thumbnailsBaseDir.existsSync()) {
        await for (final FileSystemEntity sizeDir in thumbnailsBaseDir.list()) {
          if (sizeDir is Directory) {
            await for (final FileSystemEntity entity in sizeDir.list()) {
              if (entity is File) {
                final int size = await entity.length();
                thumbnailFiles++;
                thumbnailSize += size;
                totalFiles++;
                totalSize += size;
              }
            }
          }
        }
      }

      return <String, dynamic>{
        'totalFiles': totalFiles,
        'totalSize': totalSize,
        'originalFiles': originalFiles,
        'originalSize': originalSize,
        'thumbnailFiles': thumbnailFiles,
        'thumbnailSize': thumbnailSize,
      };
    } catch (e) {
      debugPrint('Error getting session storage stats: $e');
      return <String, dynamic>{
        'totalFiles': 0,
        'totalSize': 0,
        'originalFiles': 0,
        'originalSize': 0,
        'thumbnailFiles': 0,
        'thumbnailSize': 0,
      };
    }
  }

  /// Get total storage statistics across all sessions
  Future<Map<String, dynamic>> getTotalStorageStats() async {
    try {
      final Directory photosDir = await _photosDirectory;
      final Directory sessionsDir =
          Directory(path.join(photosDir.path, _sessionsDir));

      if (!sessionsDir.existsSync()) {
        return <String, dynamic>{
          'totalSessions': 0,
          'totalFiles': 0,
          'totalSize': 0,
        };
      }

      int totalSessions = 0;
      int totalFiles = 0;
      int totalSize = 0;

      await for (final FileSystemEntity sessionEntity in sessionsDir.list()) {
        if (sessionEntity is Directory) {
          totalSessions++;
          final String sessionId = path.basename(sessionEntity.path);
          final Map<String, dynamic> sessionStats =
              await getSessionStorageStats(sessionId);
          totalFiles += sessionStats['totalFiles'] as int;
          totalSize += sessionStats['totalSize'] as int;
        }
      }

      return <String, dynamic>{
        'totalSessions': totalSessions,
        'totalFiles': totalFiles,
        'totalSize': totalSize,
      };
    } catch (e) {
      debugPrint('Error getting total storage stats: $e');
      return <String, dynamic>{
        'totalSessions': 0,
        'totalFiles': 0,
        'totalSize': 0,
      };
    }
  }

  /// Check if a photo file exists
  Future<bool> photoExists(String photoPath) async {
    try {
      final File file = File(photoPath);
      return file.existsSync();
    } catch (e) {
      debugPrint('Error checking if photo exists: $e');
      return false;
    }
  }

  /// Dispose of the service
  void dispose() {
    _instance = null;
  }
}
