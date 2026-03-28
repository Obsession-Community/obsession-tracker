import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/services/photo_capture_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Export format options for photos
enum PhotoExportFormat {
  /// Original format (no conversion)
  original,

  /// JPEG with compression
  jpeg,

  /// PNG format
  png,

  /// ZIP archive containing all photos
  zip,
}

/// Export quality settings
enum ExportQuality {
  /// Low quality (high compression)
  low(30),

  /// Medium quality (balanced)
  medium(70),

  /// High quality (low compression)
  high(90),

  /// Maximum quality (minimal compression)
  maximum(100);

  const ExportQuality(this.quality);

  /// JPEG quality value (0-100)
  final int quality;
}

/// Export options for photo batch operations
@immutable
class PhotoExportOptions {
  const PhotoExportOptions({
    this.format = PhotoExportFormat.original,
    this.quality = ExportQuality.high,
    this.includeMetadata = true,
    this.stripPrivateData = false,
    this.includeOriginals = true,
    this.includeThumbnails = false,
    this.maxWidth,
    this.maxHeight,
    this.watermarkText,
    this.customFilenamePattern,
  });

  /// Export format
  final PhotoExportFormat format;

  /// Export quality (for JPEG)
  final ExportQuality quality;

  /// Whether to include metadata files
  final bool includeMetadata;

  /// Whether to strip private data (GPS, etc.)
  final bool stripPrivateData;

  /// Whether to include original photos
  final bool includeOriginals;

  /// Whether to include thumbnails
  final bool includeThumbnails;

  /// Maximum width for resizing (optional)
  final int? maxWidth;

  /// Maximum height for resizing (optional)
  final int? maxHeight;

  /// Watermark text to add (optional)
  final String? watermarkText;

  /// Custom filename pattern (optional)
  final String? customFilenamePattern;

  PhotoExportOptions copyWith({
    PhotoExportFormat? format,
    ExportQuality? quality,
    bool? includeMetadata,
    bool? stripPrivateData,
    bool? includeOriginals,
    bool? includeThumbnails,
    int? maxWidth,
    int? maxHeight,
    String? watermarkText,
    String? customFilenamePattern,
  }) =>
      PhotoExportOptions(
        format: format ?? this.format,
        quality: quality ?? this.quality,
        includeMetadata: includeMetadata ?? this.includeMetadata,
        stripPrivateData: stripPrivateData ?? this.stripPrivateData,
        includeOriginals: includeOriginals ?? this.includeOriginals,
        includeThumbnails: includeThumbnails ?? this.includeThumbnails,
        maxWidth: maxWidth ?? this.maxWidth,
        maxHeight: maxHeight ?? this.maxHeight,
        watermarkText: watermarkText ?? this.watermarkText,
        customFilenamePattern:
            customFilenamePattern ?? this.customFilenamePattern,
      );
}

/// Progress callback for export operations
typedef ExportProgressCallback = void Function(
    int completed, int total, String? currentFile);

/// Result of a photo export operation
@immutable
class PhotoExportResult {
  const PhotoExportResult({
    required this.success,
    this.exportPath,
    this.exportedFiles = const <String>[],
    this.totalFiles = 0,
    this.totalSize = 0,
    this.error,
  });

  /// Whether the export was successful
  final bool success;

  /// Path to the exported file/directory
  final String? exportPath;

  /// List of exported file paths
  final List<String> exportedFiles;

  /// Total number of files exported
  final int totalFiles;

  /// Total size of exported files in bytes
  final int totalSize;

  /// Error message if failed
  final String? error;
}

/// Service for exporting photos with various options and formats
class PhotoExportService {
  factory PhotoExportService() => _instance ??= PhotoExportService._();
  PhotoExportService._();
  static PhotoExportService? _instance;

  final PhotoCaptureService _photoCaptureService = PhotoCaptureService();

  /// Export multiple photos with specified options
  Future<PhotoExportResult> exportPhotos({
    required List<PhotoWaypoint> photos,
    required PhotoExportOptions options,
    ExportProgressCallback? onProgress,
  }) async {
    try {
      if (photos.isEmpty) {
        return const PhotoExportResult(
          success: false,
          error: 'No photos to export',
        );
      }

      // Create temporary export directory
      final Directory tempDir = await getTemporaryDirectory();
      final String exportDirPath = path.join(
        tempDir.path,
        'photo_export_${DateTime.now().millisecondsSinceEpoch}',
      );
      final Directory exportDir = Directory(exportDirPath);
      await exportDir.create(recursive: true);

      final List<String> exportedFiles = <String>[];
      int totalSize = 0;
      int completed = 0;

      for (final PhotoWaypoint photo in photos) {
        onProgress?.call(completed, photos.length, photo.filePath);

        try {
          // Process the photo based on options
          final String? exportedPath = await _processPhotoForExport(
            photo,
            exportDir,
            options,
          );

          if (exportedPath != null) {
            exportedFiles.add(exportedPath);
            final File exportedFile = File(exportedPath);
            if (exportedFile.existsSync()) {
              totalSize += await exportedFile.length();
            }
          }

          // Export metadata if requested
          if (options.includeMetadata) {
            final String? metadataPath = await _exportPhotoMetadata(
              photo,
              exportDir,
              options,
            );
            if (metadataPath != null) {
              exportedFiles.add(metadataPath);
              final File metadataFile = File(metadataPath);
              if (metadataFile.existsSync()) {
                totalSize += await metadataFile.length();
              }
            }
          }

          completed++;
        } catch (e) {
          debugPrint('Error processing photo ${photo.id}: $e');
          completed++;
          continue;
        }
      }

      onProgress?.call(completed, photos.length, null);

      // Create final export based on format
      String finalExportPath;
      if (options.format == PhotoExportFormat.zip) {
        finalExportPath = await _createZipArchive(exportDir, exportedFiles);
        totalSize = await File(finalExportPath).length();
      } else {
        finalExportPath = exportDirPath;
      }

      return PhotoExportResult(
        success: true,
        exportPath: finalExportPath,
        exportedFiles: exportedFiles,
        totalFiles: exportedFiles.length,
        totalSize: totalSize,
      );
    } catch (e) {
      debugPrint('Error exporting photos: $e');
      return PhotoExportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Process a single photo for export
  Future<String?> _processPhotoForExport(
    PhotoWaypoint photo,
    Directory exportDir,
    PhotoExportOptions options,
  ) async {
    try {
      final File originalFile = File(photo.filePath);
      if (!originalFile.existsSync()) {
        debugPrint('Original photo file not found: ${photo.filePath}');
        return null;
      }

      // Generate export filename
      final String exportFilename = _generateExportFilename(photo, options);
      final String exportPath = path.join(exportDir.path, exportFilename);

      // Read original photo data
      Uint8List photoData = await originalFile.readAsBytes();

      // Apply privacy stripping if requested
      if (options.stripPrivateData) {
        photoData = await _stripPrivateData(photoData);
      }

      // Apply processing based on format and options
      switch (options.format) {
        case PhotoExportFormat.original:
          // Copy as-is
          await File(exportPath).writeAsBytes(photoData);
          break;

        case PhotoExportFormat.jpeg:
          // Convert/compress to JPEG
          photoData = await _convertToJpeg(photoData, options.quality);
          await File(exportPath).writeAsBytes(photoData);
          break;

        case PhotoExportFormat.png:
          // Convert to PNG
          photoData = await _convertToPng(photoData);
          await File(exportPath).writeAsBytes(photoData);
          break;

        case PhotoExportFormat.zip:
          // For ZIP, we'll process as original and zip later
          await File(exportPath).writeAsBytes(photoData);
          break;
      }

      return exportPath;
    } catch (e) {
      debugPrint('Error processing photo for export: $e');
      return null;
    }
  }

  /// Export photo metadata to JSON file
  Future<String?> _exportPhotoMetadata(
    PhotoWaypoint photo,
    Directory exportDir,
    PhotoExportOptions options,
  ) async {
    try {
      // Get metadata from service
      final List<PhotoMetadata> metadata =
          await _photoCaptureService.getPhotoMetadata(photo.id);

      // Filter metadata based on privacy settings
      List<PhotoMetadata> filteredMetadata = metadata;
      if (options.stripPrivateData) {
        filteredMetadata = metadata
            .where((meta) =>
                // Remove GPS and other private data
                !meta.key.contains('location_') &&
                !meta.key.contains('gps_') &&
                !meta.key.contains('compass_') &&
                !meta.key.contains('magnetometer_'))
            .toList();
      }

      // Create metadata JSON
      final Map<String, dynamic> metadataJson = {
        'photo_id': photo.id,
        'waypoint_id': photo.waypointId,
        'created_at': photo.createdAt.toIso8601String(),
        'file_size': photo.fileSize,
        'dimensions': {
          'width': photo.width,
          'height': photo.height,
        },
        'metadata': filteredMetadata
            .map((meta) => {
                  'key': meta.key,
                  'value': meta.value,
                  'type': meta.type.name,
                  'display_value': meta.displayValue,
                })
            .toList(),
        'export_info': {
          'exported_at': DateTime.now().toIso8601String(),
          'privacy_stripped': options.stripPrivateData,
          'export_format': options.format.name,
        },
      };

      // Write metadata file
      final String metadataFilename =
          '${path.basenameWithoutExtension(_generateExportFilename(photo, options))}_metadata.json';
      final String metadataPath = path.join(exportDir.path, metadataFilename);

      await File(metadataPath).writeAsString(
        const JsonEncoder.withIndent('  ').convert(metadataJson),
      );

      return metadataPath;
    } catch (e) {
      debugPrint('Error exporting photo metadata: $e');
      return null;
    }
  }

  /// Generate export filename based on options
  String _generateExportFilename(
      PhotoWaypoint photo, PhotoExportOptions options) {
    if (options.customFilenamePattern != null) {
      // Apply custom pattern
      String filename = options.customFilenamePattern!;
      filename = filename.replaceAll('{id}', photo.id);
      filename = filename.replaceAll('{waypoint_id}', photo.waypointId);
      filename = filename.replaceAll(
          '{date}', photo.createdAt.toIso8601String().split('T')[0]);
      filename = filename.replaceAll('{time}',
          photo.createdAt.toIso8601String().split('T')[1].split('.')[0]);
      filename = filename.replaceAll(
          '{timestamp}', photo.createdAt.millisecondsSinceEpoch.toString());
      return filename;
    }

    // Default pattern: photo_YYYYMMDD_HHMMSS_id.ext
    final String dateStr = photo.createdAt
        .toIso8601String()
        .replaceAll('-', '')
        .replaceAll(':', '')
        .replaceAll('T', '_')
        .split('.')[0];

    String extension;
    switch (options.format) {
      case PhotoExportFormat.jpeg:
        extension = 'jpg';
        break;
      case PhotoExportFormat.png:
        extension = 'png';
        break;
      case PhotoExportFormat.original:
      case PhotoExportFormat.zip:
        extension = path.extension(photo.filePath).substring(1);
        break;
    }

    return 'photo_${dateStr}_${photo.id.substring(0, 8)}.$extension';
  }

  /// Strip private data from photo EXIF
  Future<Uint8List> _stripPrivateData(Uint8List photoData) async {
    try {
      // TODO(obsession): Implement EXIF stripping
      // For now, return original data
      // In production, you'd use a library to remove GPS and other private EXIF data
      debugPrint('Privacy data stripping not yet implemented');
      return photoData;
    } catch (e) {
      debugPrint('Error stripping private data: $e');
      return photoData;
    }
  }

  /// Convert photo to JPEG with specified quality
  Future<Uint8List> _convertToJpeg(
      Uint8List photoData, ExportQuality quality) async {
    try {
      // TODO(obsession): Implement image conversion with compression
      // For now, return original data
      // In production, you'd use image processing library
      debugPrint('JPEG conversion not yet implemented');
      return photoData;
    } catch (e) {
      debugPrint('Error converting to JPEG: $e');
      return photoData;
    }
  }

  /// Convert photo to PNG
  Future<Uint8List> _convertToPng(Uint8List photoData) async {
    try {
      // TODO(obsession): Implement PNG conversion
      // For now, return original data
      debugPrint('PNG conversion not yet implemented');
      return photoData;
    } catch (e) {
      debugPrint('Error converting to PNG: $e');
      return photoData;
    }
  }

  /// Create ZIP archive from exported files
  Future<String> _createZipArchive(
      Directory exportDir, List<String> files) async {
    try {
      final Archive archive = Archive();

      for (final String filePath in files) {
        final File file = File(filePath);
        if (file.existsSync()) {
          final Uint8List fileData = await file.readAsBytes();
          final String relativePath =
              path.relative(filePath, from: exportDir.path);
          archive.addFile(ArchiveFile(relativePath, fileData.length, fileData));
        }
      }

      final Uint8List zipData =
          Uint8List.fromList(ZipEncoder().encode(archive));

      final String zipPath = '${exportDir.path}.zip';
      await File(zipPath).writeAsBytes(zipData);

      // Clean up temporary directory
      await exportDir.delete(recursive: true);

      return zipPath;
    } catch (e) {
      debugPrint('Error creating ZIP archive: $e');
      rethrow;
    }
  }

  /// Share exported photos using the system share dialog
  Future<bool> shareExportedPhotos(PhotoExportResult exportResult) async {
    try {
      if (!exportResult.success || exportResult.exportPath == null) {
        return false;
      }

      final String exportPath = exportResult.exportPath!;
      final File exportFile = File(exportPath);

      if (exportFile.existsSync()) {
        // Share single file (ZIP or directory)
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(exportPath)],
            text:
                'Exported ${exportResult.totalFiles} photos from Obsession Tracker',
          ),
        );
        return true;
      } else {
        // Share multiple files from directory
        final Directory exportDir = Directory(exportPath);
        if (exportDir.existsSync()) {
          final List<XFile> files = <XFile>[];
          await for (final FileSystemEntity entity in exportDir.list()) {
            if (entity is File) {
              files.add(XFile(entity.path));
            }
          }

          if (files.isNotEmpty) {
            await SharePlus.instance.share(
              ShareParams(
                files: files,
                text:
                    'Exported ${exportResult.totalFiles} photos from Obsession Tracker',
              ),
            );
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error sharing exported photos: $e');
      return false;
    }
  }

  /// Clean up temporary export files
  Future<void> cleanupExportFiles(String exportPath) async {
    try {
      final File file = File(exportPath);
      final Directory dir = Directory(exportPath);

      if (file.existsSync()) {
        await file.delete();
      } else if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error cleaning up export files: $e');
    }
  }

  /// Get estimated export size
  Future<int> estimateExportSize({
    required List<PhotoWaypoint> photos,
    required PhotoExportOptions options,
  }) async {
    int estimatedSize = 0;

    for (final PhotoWaypoint photo in photos) {
      // Base photo size
      int photoSize = photo.fileSize;

      // Adjust for compression/format
      switch (options.format) {
        case PhotoExportFormat.jpeg:
          // Estimate compression ratio based on quality
          final double compressionRatio = options.quality.quality / 100.0;
          photoSize = (photoSize * compressionRatio).round();
          break;
        case PhotoExportFormat.png:
          // PNG is typically larger than JPEG
          photoSize = (photoSize * 1.2).round();
          break;
        case PhotoExportFormat.original:
        case PhotoExportFormat.zip:
          // Keep original size
          break;
      }

      estimatedSize += photoSize;

      // Add metadata file size estimate
      if (options.includeMetadata) {
        estimatedSize += 2048; // ~2KB per metadata file
      }
    }

    // Add ZIP overhead if applicable
    if (options.format == PhotoExportFormat.zip) {
      estimatedSize = (estimatedSize * 1.1).round(); // 10% overhead
    }

    return estimatedSize;
  }

  /// Dispose of the service
  void dispose() {
    _instance = null;
  }
}
