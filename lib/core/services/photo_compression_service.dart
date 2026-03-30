import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/services/photo_storage_service.dart';
import 'package:path/path.dart' as path;

/// Compression quality levels
enum CompressionLevel {
  /// Low compression (high quality, larger file)
  low(85),

  /// Medium compression (balanced quality and size)
  medium(70),

  /// High compression (lower quality, smaller file)
  high(50),

  /// Maximum compression (lowest quality, smallest file)
  maximum(30);

  const CompressionLevel(this.quality);

  /// JPEG quality value (0-100)
  final int quality;
}

/// Compression strategy options
enum CompressionStrategy {
  /// Compress based on file size thresholds
  sizeThreshold,

  /// Compress based on storage space available
  storageOptimization,

  /// Compress based on photo age
  ageBasedCompression,

  /// Compress all photos uniformly
  uniform,
}

/// Compression settings
@immutable
class CompressionSettings {
  const CompressionSettings({
    this.level = CompressionLevel.medium,
    this.strategy = CompressionStrategy.sizeThreshold,
    this.maxWidth = 2048,
    this.maxHeight = 2048,
    this.sizeThresholdMB = 5.0,
    this.preserveOriginals = true,
    this.compressOlderThanDays = 30,
    this.targetStorageUsagePercent = 80.0,
  });

  /// Compression quality level
  final CompressionLevel level;

  /// Compression strategy
  final CompressionStrategy strategy;

  /// Maximum width for resizing
  final int maxWidth;

  /// Maximum height for resizing
  final int maxHeight;

  /// File size threshold in MB for compression
  final double sizeThresholdMB;

  /// Whether to keep original files
  final bool preserveOriginals;

  /// Compress photos older than this many days
  final int compressOlderThanDays;

  /// Target storage usage percentage
  final double targetStorageUsagePercent;

  CompressionSettings copyWith({
    CompressionLevel? level,
    CompressionStrategy? strategy,
    int? maxWidth,
    int? maxHeight,
    double? sizeThresholdMB,
    bool? preserveOriginals,
    int? compressOlderThanDays,
    double? targetStorageUsagePercent,
  }) =>
      CompressionSettings(
        level: level ?? this.level,
        strategy: strategy ?? this.strategy,
        maxWidth: maxWidth ?? this.maxWidth,
        maxHeight: maxHeight ?? this.maxHeight,
        sizeThresholdMB: sizeThresholdMB ?? this.sizeThresholdMB,
        preserveOriginals: preserveOriginals ?? this.preserveOriginals,
        compressOlderThanDays:
            compressOlderThanDays ?? this.compressOlderThanDays,
        targetStorageUsagePercent:
            targetStorageUsagePercent ?? this.targetStorageUsagePercent,
      );
}

/// Progress callback for compression operations
typedef CompressionProgressCallback = void Function(
    int completed, int total, String? currentFile);

/// Result of a compression operation
@immutable
class CompressionResult {
  const CompressionResult({
    required this.success,
    this.originalSize = 0,
    this.compressedSize = 0,
    this.filesProcessed = 0,
    this.filesCompressed = 0,
    this.spaceSaved = 0,
    this.error,
  });

  /// Whether the compression was successful
  final bool success;

  /// Original total size in bytes
  final int originalSize;

  /// Compressed total size in bytes
  final int compressedSize;

  /// Number of files processed
  final int filesProcessed;

  /// Number of files actually compressed
  final int filesCompressed;

  /// Space saved in bytes
  final int spaceSaved;

  /// Error message if failed
  final String? error;

  /// Compression ratio (0.0 to 1.0)
  double get compressionRatio =>
      originalSize > 0 ? compressedSize / originalSize : 0.0;

  /// Space saved percentage
  double get spaceSavedPercent =>
      originalSize > 0 ? (spaceSaved / originalSize) * 100 : 0.0;
}

/// Service for photo compression and storage optimization
class PhotoCompressionService {
  factory PhotoCompressionService() =>
      _instance ??= PhotoCompressionService._();
  PhotoCompressionService._();
  static PhotoCompressionService? _instance;

  final PhotoStorageService _storageService = PhotoStorageService();

  /// Compress a single photo
  Future<CompressionResult> compressPhoto({
    required PhotoWaypoint photo,
    required String sessionId,
    required CompressionSettings settings,
  }) async {
    try {
      final File originalFile = File(photo.filePath);
      if (!originalFile.existsSync()) {
        return CompressionResult(
          success: false,
          error: 'Original photo file not found: ${photo.filePath}',
        );
      }

      final int originalSize = await originalFile.length();

      // Check if compression is needed based on strategy
      if (!_shouldCompressPhoto(photo, originalSize, settings)) {
        return CompressionResult(
          success: true,
          originalSize: originalSize,
          compressedSize: originalSize,
          filesProcessed: 1,
        );
      }

      // Read and decode the image
      final Uint8List originalData = await originalFile.readAsBytes();
      final img.Image? image = img.decodeImage(originalData);

      if (image == null) {
        return CompressionResult(
          success: false,
          error: 'Failed to decode image: ${photo.filePath}',
        );
      }

      // Apply compression
      final Uint8List compressedData = await _compressImage(image, settings);

      // Save compressed version
      String compressedPath;
      if (settings.preserveOriginals) {
        // Save as a separate compressed file
        final String originalName =
            path.basenameWithoutExtension(photo.filePath);
        final String extension = path.extension(photo.filePath);
        compressedPath = photo.filePath.replaceAll(
          '$originalName$extension',
          '${originalName}_compressed$extension',
        );
      } else {
        // Replace original file
        compressedPath = photo.filePath;
      }

      await File(compressedPath).writeAsBytes(compressedData);

      // Regenerate thumbnails for compressed image
      await _storageService.generateAllThumbnails(
        originalPhotoPath: compressedPath,
        sessionId: sessionId,
      );

      final int compressedSize = compressedData.length;
      final int spaceSaved = originalSize - compressedSize;

      debugPrint(
          'Compressed photo ${photo.id}: $originalSize -> $compressedSize bytes (${(spaceSaved / originalSize * 100).toStringAsFixed(1)}% saved)');

      return CompressionResult(
        success: true,
        originalSize: originalSize,
        compressedSize: compressedSize,
        filesProcessed: 1,
        filesCompressed: 1,
        spaceSaved: spaceSaved,
      );
    } catch (e) {
      debugPrint('Error compressing photo ${photo.id}: $e');
      return CompressionResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Compress multiple photos with progress tracking
  Future<CompressionResult> compressPhotos({
    required List<PhotoWaypoint> photos,
    required String sessionId,
    required CompressionSettings settings,
    CompressionProgressCallback? onProgress,
  }) async {
    int totalOriginalSize = 0;
    int totalCompressedSize = 0;
    int filesProcessed = 0;
    int filesCompressed = 0;
    int totalSpaceSaved = 0;

    try {
      for (int i = 0; i < photos.length; i++) {
        final PhotoWaypoint photo = photos[i];
        onProgress?.call(i, photos.length, photo.filePath);

        final CompressionResult result = await compressPhoto(
          photo: photo,
          sessionId: sessionId,
          settings: settings,
        );

        if (result.success) {
          totalOriginalSize += result.originalSize;
          totalCompressedSize += result.compressedSize;
          filesProcessed += result.filesProcessed;
          filesCompressed += result.filesCompressed;
          totalSpaceSaved += result.spaceSaved;
        } else {
          debugPrint('Failed to compress photo ${photo.id}: ${result.error}');
          filesProcessed++;
        }
      }

      onProgress?.call(photos.length, photos.length, null);

      return CompressionResult(
        success: true,
        originalSize: totalOriginalSize,
        compressedSize: totalCompressedSize,
        filesProcessed: filesProcessed,
        filesCompressed: filesCompressed,
        spaceSaved: totalSpaceSaved,
      );
    } catch (e) {
      debugPrint('Error in batch compression: $e');
      return CompressionResult(
        success: false,
        originalSize: totalOriginalSize,
        compressedSize: totalCompressedSize,
        filesProcessed: filesProcessed,
        filesCompressed: filesCompressed,
        spaceSaved: totalSpaceSaved,
        error: e.toString(),
      );
    }
  }

  /// Optimize storage by compressing photos based on available space
  Future<CompressionResult> optimizeStorage({
    required String sessionId,
    required CompressionSettings settings,
    CompressionProgressCallback? onProgress,
  }) async {
    try {
      // Get storage statistics
      final Map<String, dynamic> storageStats =
          await _storageService.getSessionStorageStats(sessionId);

      final int totalSize = storageStats['totalSize'] as int;

      // Calculate if optimization is needed
      final double currentUsagePercent =
          (totalSize / (1024 * 1024 * 1024)) * 100; // Convert to GB percentage

      if (currentUsagePercent < settings.targetStorageUsagePercent) {
        return const CompressionResult(
          success: true,
        );
      }

      // Get photos that need compression
      final List<PhotoWaypoint> photosToCompress =
          await _getPhotosForOptimization(
        sessionId,
        settings,
      );

      if (photosToCompress.isEmpty) {
        return const CompressionResult(
          success: true,
        );
      }

      // Compress photos
      return await compressPhotos(
        photos: photosToCompress,
        sessionId: sessionId,
        settings: settings,
        onProgress: onProgress,
      );
    } catch (e) {
      debugPrint('Error optimizing storage: $e');
      return CompressionResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Check if a photo should be compressed based on settings
  bool _shouldCompressPhoto(
    PhotoWaypoint photo,
    int fileSize,
    CompressionSettings settings,
  ) {
    switch (settings.strategy) {
      case CompressionStrategy.sizeThreshold:
        final double fileSizeMB = fileSize / (1024 * 1024);
        return fileSizeMB > settings.sizeThresholdMB;

      case CompressionStrategy.ageBasedCompression:
        final DateTime cutoffDate = DateTime.now().subtract(
          Duration(days: settings.compressOlderThanDays),
        );
        return photo.createdAt.isBefore(cutoffDate);

      case CompressionStrategy.uniform:
        return true;

      case CompressionStrategy.storageOptimization:
        // This is handled at a higher level in optimizeStorage
        return true;
    }
  }

  /// Compress an image with the specified settings
  Future<Uint8List> _compressImage(
    img.Image image,
    CompressionSettings settings,
  ) async {
    img.Image processedImage = image;

    // Resize if needed
    if (image.width > settings.maxWidth || image.height > settings.maxHeight) {
      processedImage = img.copyResize(
        image,
        width: settings.maxWidth,
        height: settings.maxHeight,
        maintainAspect: true,
      );
    }

    // Encode with compression
    final List<int> compressedBytes = img.encodeJpg(
      processedImage,
      quality: settings.level.quality,
    );

    return Uint8List.fromList(compressedBytes);
  }

  /// Get photos that should be compressed for optimization
  Future<List<PhotoWaypoint>> _getPhotosForOptimization(
    String sessionId,
    CompressionSettings settings,
  ) async {
    try {
      // This would need to be implemented with access to photo database
      // For now, return empty list
      // In a real implementation, you'd query photos based on the strategy
      debugPrint('Getting photos for optimization - implementation needed');
      return <PhotoWaypoint>[];
    } catch (e) {
      debugPrint('Error getting photos for optimization: $e');
      return <PhotoWaypoint>[];
    }
  }

  /// Clean up old compressed files
  Future<bool> cleanupOldCompressedFiles({
    required String sessionId,
    int olderThanDays = 90,
  }) async {
    try {
      // final DateTime cutoffDate = DateTime.now().subtract(
      //   Duration(days: olderThanDays),
      // );

      // This would need implementation to find and delete old compressed files
      debugPrint('Cleanup of old compressed files - implementation needed');

      return true;
    } catch (e) {
      debugPrint('Error cleaning up old compressed files: $e');
      return false;
    }
  }

  /// Get compression recommendations based on current storage
  Future<Map<String, dynamic>> getCompressionRecommendations({
    required String sessionId,
  }) async {
    try {
      final Map<String, dynamic> storageStats =
          await _storageService.getSessionStorageStats(sessionId);

      final int totalSize = storageStats['totalSize'] as int;
      final int originalSize = storageStats['originalSize'] as int;
      final int originalFiles = storageStats['originalFiles'] as int;

      // Calculate potential savings
      final double averageFileSize =
          originalFiles > 0 ? originalSize / originalFiles : 0;
      final double estimatedSavings =
          originalSize * 0.3; // Estimate 30% savings

      final List<String> recommendations = <String>[];

      if (totalSize > 100 * 1024 * 1024) {
        // > 100MB
        recommendations
            .add('Consider compressing photos to save storage space');
      }

      if (averageFileSize > 5 * 1024 * 1024) {
        // > 5MB average
        recommendations
            .add('Large photo files detected - compression recommended');
      }

      if (originalFiles > 100) {
        recommendations
            .add('Large number of photos - batch compression recommended');
      }

      return <String, dynamic>{
        'total_size': totalSize,
        'original_size': originalSize,
        'original_files': originalFiles,
        'average_file_size': averageFileSize,
        'estimated_savings': estimatedSavings,
        'estimated_savings_percent':
            originalSize > 0 ? (estimatedSavings / originalSize) * 100 : 0,
        'recommendations': recommendations,
        'should_compress': recommendations.isNotEmpty,
      };
    } catch (e) {
      debugPrint('Error getting compression recommendations: $e');
      return <String, dynamic>{
        'error': e.toString(),
        'should_compress': false,
      };
    }
  }

  /// Estimate compression results without actually compressing
  Future<Map<String, dynamic>> estimateCompression({
    required List<PhotoWaypoint> photos,
    required CompressionSettings settings,
  }) async {
    int totalOriginalSize = 0;
    int estimatedCompressedSize = 0;
    int photosToCompress = 0;

    for (final PhotoWaypoint photo in photos) {
      try {
        final File file = File(photo.filePath);
        if (file.existsSync()) {
          final int fileSize = await file.length();
          totalOriginalSize += fileSize;

          if (_shouldCompressPhoto(photo, fileSize, settings)) {
            photosToCompress++;
            // Estimate compression ratio based on quality level
            double compressionRatio;
            switch (settings.level) {
              case CompressionLevel.low:
                compressionRatio = 0.8;
                break;
              case CompressionLevel.medium:
                compressionRatio = 0.6;
                break;
              case CompressionLevel.high:
                compressionRatio = 0.4;
                break;
              case CompressionLevel.maximum:
                compressionRatio = 0.3;
                break;
            }
            estimatedCompressedSize += (fileSize * compressionRatio).round();
          } else {
            estimatedCompressedSize += fileSize;
          }
        }
      } catch (e) {
        debugPrint('Error estimating compression for photo ${photo.id}: $e');
      }
    }

    final int estimatedSavings = totalOriginalSize - estimatedCompressedSize;

    return <String, dynamic>{
      'total_photos': photos.length,
      'photos_to_compress': photosToCompress,
      'original_size': totalOriginalSize,
      'estimated_compressed_size': estimatedCompressedSize,
      'estimated_savings': estimatedSavings,
      'estimated_savings_percent': totalOriginalSize > 0
          ? (estimatedSavings / totalOriginalSize) * 100
          : 0,
    };
  }

  /// Dispose of the service
  void dispose() {
    _instance = null;
  }
}
