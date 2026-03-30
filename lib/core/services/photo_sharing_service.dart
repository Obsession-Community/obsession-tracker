import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/services/photo_capture_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Privacy levels for photo sharing
enum PrivacyLevel {
  /// No privacy protection (share as-is)
  none,

  /// Strip GPS and location data only
  location,

  /// Strip all EXIF metadata
  metadata,

  /// Strip metadata and add watermark
  watermarked,

  /// Maximum privacy (strip all data, blur faces, add watermark)
  maximum,
}

/// Sharing destination types
enum SharingDestination {
  /// System share dialog
  system,

  /// Email
  email,

  /// Social media
  social,

  /// Cloud storage
  cloud,

  /// Export to files
  files,
}

/// Photo sharing options
@immutable
class SharingOptions {
  const SharingOptions({
    this.privacyLevel = PrivacyLevel.metadata,
    this.destination = SharingDestination.system,
    this.includeWatermark = false,
    this.watermarkText,
    this.watermarkPosition = WatermarkPosition.bottomRight,
    this.watermarkOpacity = 0.7,
    this.resizeForSharing = true,
    this.maxWidth = 1920,
    this.maxHeight = 1080,
    this.jpegQuality = 85,
    this.includeMetadataFile = false,
    this.customMessage,
  });

  /// Privacy protection level
  final PrivacyLevel privacyLevel;

  /// Sharing destination
  final SharingDestination destination;

  /// Whether to include watermark
  final bool includeWatermark;

  /// Custom watermark text
  final String? watermarkText;

  /// Watermark position
  final WatermarkPosition watermarkPosition;

  /// Watermark opacity (0.0 to 1.0)
  final double watermarkOpacity;

  /// Whether to resize photos for sharing
  final bool resizeForSharing;

  /// Maximum width for shared photos
  final int maxWidth;

  /// Maximum height for shared photos
  final int maxHeight;

  /// JPEG quality for shared photos
  final int jpegQuality;

  /// Whether to include metadata as separate file
  final bool includeMetadataFile;

  /// Custom message to include with share
  final String? customMessage;

  SharingOptions copyWith({
    PrivacyLevel? privacyLevel,
    SharingDestination? destination,
    bool? includeWatermark,
    String? watermarkText,
    WatermarkPosition? watermarkPosition,
    double? watermarkOpacity,
    bool? resizeForSharing,
    int? maxWidth,
    int? maxHeight,
    int? jpegQuality,
    bool? includeMetadataFile,
    String? customMessage,
  }) =>
      SharingOptions(
        privacyLevel: privacyLevel ?? this.privacyLevel,
        destination: destination ?? this.destination,
        includeWatermark: includeWatermark ?? this.includeWatermark,
        watermarkText: watermarkText ?? this.watermarkText,
        watermarkPosition: watermarkPosition ?? this.watermarkPosition,
        watermarkOpacity: watermarkOpacity ?? this.watermarkOpacity,
        resizeForSharing: resizeForSharing ?? this.resizeForSharing,
        maxWidth: maxWidth ?? this.maxWidth,
        maxHeight: maxHeight ?? this.maxHeight,
        jpegQuality: jpegQuality ?? this.jpegQuality,
        includeMetadataFile: includeMetadataFile ?? this.includeMetadataFile,
        customMessage: customMessage ?? this.customMessage,
      );
}

/// Watermark position options
enum WatermarkPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  center,
}

/// Progress callback for sharing operations
typedef SharingProgressCallback = void Function(
    int completed, int total, String? currentFile);

/// Result of a sharing operation
@immutable
class SharingResult {
  const SharingResult({
    required this.success,
    this.sharedFiles = const <String>[],
    this.totalFiles = 0,
    this.error,
  });

  /// Whether the sharing was successful
  final bool success;

  /// List of shared file paths
  final List<String> sharedFiles;

  /// Total number of files shared
  final int totalFiles;

  /// Error message if failed
  final String? error;
}

/// Privacy analysis result
@immutable
class PrivacyAnalysis {
  const PrivacyAnalysis({
    required this.hasGpsData,
    required this.hasPersonalMetadata,
    required this.hasCameraInfo,
    required this.hasTimestamp,
    this.gpsAccuracy,
    this.recommendedPrivacyLevel = PrivacyLevel.metadata,
    this.warnings = const <String>[],
  });

  /// Whether photo contains GPS coordinates
  final bool hasGpsData;

  /// Whether photo contains personal metadata
  final bool hasPersonalMetadata;

  /// Whether photo contains camera information
  final bool hasCameraInfo;

  /// Whether photo contains timestamp
  final bool hasTimestamp;

  /// GPS accuracy if available
  final double? gpsAccuracy;

  /// Recommended privacy level
  final PrivacyLevel recommendedPrivacyLevel;

  /// Privacy warnings
  final List<String> warnings;
}

/// Service for sharing photos with privacy controls and EXIF stripping
class PhotoSharingService {
  factory PhotoSharingService() => _instance ??= PhotoSharingService._();
  PhotoSharingService._();
  static PhotoSharingService? _instance;

  final PhotoCaptureService _photoCaptureService = PhotoCaptureService();

  /// Share multiple photos with privacy controls
  Future<SharingResult> sharePhotos({
    required List<PhotoWaypoint> photos,
    required SharingOptions options,
    SharingProgressCallback? onProgress,
  }) async {
    try {
      if (photos.isEmpty) {
        return const SharingResult(
          success: false,
          error: 'No photos to share',
        );
      }

      // Create temporary directory for processed photos
      final Directory tempDir = await getTemporaryDirectory();
      final String shareDirPath = path.join(
        tempDir.path,
        'share_${DateTime.now().millisecondsSinceEpoch}',
      );
      final Directory shareDir = Directory(shareDirPath);
      await shareDir.create(recursive: true);

      final List<String> sharedFiles = <String>[];
      int completed = 0;

      try {
        for (final PhotoWaypoint photo in photos) {
          onProgress?.call(completed, photos.length, photo.filePath);

          // Process photo for sharing
          final String? processedPath = await _processPhotoForSharing(
            photo,
            shareDir,
            options,
          );

          if (processedPath != null) {
            sharedFiles.add(processedPath);

            // Create metadata file if requested
            if (options.includeMetadataFile) {
              final String? metadataPath = await _createMetadataFile(
                photo,
                shareDir,
                options,
              );
              if (metadataPath != null) {
                sharedFiles.add(metadataPath);
              }
            }
          }

          completed++;
        }

        onProgress?.call(photos.length, photos.length, null);

        // Share the processed files
        final bool shareSuccess = await _shareFiles(sharedFiles, options);

        // Clean up temporary files after a delay
        Future<void>.delayed(const Duration(minutes: 5), () async {
          try {
            if (shareDir.existsSync()) {
              await shareDir.delete(recursive: true);
            }
          } catch (e) {
            debugPrint('Error cleaning up share directory: $e');
          }
        });

        return SharingResult(
          success: shareSuccess,
          sharedFiles: sharedFiles,
          totalFiles: sharedFiles.length,
        );
      } catch (e) {
        // Clean up on error
        if (shareDir.existsSync()) {
          await shareDir.delete(recursive: true);
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('Error sharing photos: $e');
      return SharingResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Process a single photo for sharing
  Future<String?> _processPhotoForSharing(
    PhotoWaypoint photo,
    Directory shareDir,
    SharingOptions options,
  ) async {
    try {
      final File originalFile = File(photo.filePath);
      if (!originalFile.existsSync()) {
        debugPrint('Original photo file not found: ${photo.filePath}');
        return null;
      }

      // Read original photo data
      Uint8List photoData = await originalFile.readAsBytes();

      // Apply privacy controls
      photoData = await _applyPrivacyControls(photoData, photo, options);

      // Process image (resize, watermark, etc.)
      photoData = await _processImage(photoData, options);

      // Generate share filename
      final String shareFilename = _generateShareFilename(photo, options);
      final String sharePath = path.join(shareDir.path, shareFilename);

      // Save processed photo
      await File(sharePath).writeAsBytes(photoData);

      return sharePath;
    } catch (e) {
      debugPrint('Error processing photo for sharing: $e');
      return null;
    }
  }

  /// Apply privacy controls to photo data
  Future<Uint8List> _applyPrivacyControls(
    Uint8List photoData,
    PhotoWaypoint photo,
    SharingOptions options,
  ) async {
    try {
      switch (options.privacyLevel) {
        case PrivacyLevel.none:
          // No privacy protection
          return photoData;

        case PrivacyLevel.location:
          // Strip only GPS/location data
          return await _stripLocationData(photoData);

        case PrivacyLevel.metadata:
          // Strip all EXIF metadata
          return await _stripAllMetadata(photoData);

        case PrivacyLevel.watermarked:
          // Strip metadata and add watermark (watermark added in processImage)
          return await _stripAllMetadata(photoData);

        case PrivacyLevel.maximum:
          // Strip all data, blur faces, add watermark
          final strippedData = await _stripAllMetadata(photoData);
          final processedData = await _blurFaces(strippedData);
          return processedData;
      }
    } catch (e) {
      debugPrint('Error applying privacy controls: $e');
      return photoData;
    }
  }

  /// Strip location data from EXIF
  Future<Uint8List> _stripLocationData(Uint8List photoData) async {
    try {
      // TODO(obsession): Implement EXIF location data stripping
      // For now, return original data
      debugPrint('Location data stripping not yet implemented');
      return photoData;
    } catch (e) {
      debugPrint('Error stripping location data: $e');
      return photoData;
    }
  }

  /// Strip all EXIF metadata
  Future<Uint8List> _stripAllMetadata(Uint8List photoData) async {
    try {
      // Decode image to remove EXIF data
      final img.Image? image = img.decodeImage(photoData);
      if (image == null) {
        debugPrint('Failed to decode image for metadata stripping');
        return photoData;
      }

      // Re-encode without EXIF data
      final List<int> cleanData = img.encodeJpg(image, quality: 95);
      return Uint8List.fromList(cleanData);
    } catch (e) {
      debugPrint('Error stripping metadata: $e');
      return photoData;
    }
  }

  /// Blur faces in photo for privacy
  Future<Uint8List> _blurFaces(Uint8List photoData) async {
    try {
      // TODO(obsession): Implement face detection and blurring
      // This would require ML/AI libraries for face detection
      debugPrint('Face blurring not yet implemented');
      return photoData;
    } catch (e) {
      debugPrint('Error blurring faces: $e');
      return photoData;
    }
  }

  /// Process image (resize, watermark, etc.)
  Future<Uint8List> _processImage(
    Uint8List photoData,
    SharingOptions options,
  ) async {
    try {
      final img.Image? image = img.decodeImage(photoData);
      if (image == null) {
        debugPrint('Failed to decode image for processing');
        return photoData;
      }

      img.Image processedImage = image;

      // Resize if requested
      if (options.resizeForSharing) {
        if (image.width > options.maxWidth ||
            image.height > options.maxHeight) {
          processedImage = img.copyResize(
            image,
            width: options.maxWidth,
            height: options.maxHeight,
            maintainAspect: true,
          );
        }
      }

      // Add watermark if requested
      if (options.includeWatermark ||
          options.privacyLevel == PrivacyLevel.watermarked ||
          options.privacyLevel == PrivacyLevel.maximum) {
        processedImage = await _addWatermark(processedImage, options);
      }

      // Encode with specified quality
      final List<int> processedData = img.encodeJpg(
        processedImage,
        quality: options.jpegQuality,
      );

      return Uint8List.fromList(processedData);
    } catch (e) {
      debugPrint('Error processing image: $e');
      return photoData;
    }
  }

  /// Add watermark to image
  Future<img.Image> _addWatermark(
    img.Image image,
    SharingOptions options,
  ) async {
    try {
      // Get watermark text
      final String watermarkText = options.watermarkText ?? 'Obsession Tracker';

      // TODO(obsession): Implement proper text watermarking
      // For now, just return the original image
      debugPrint('Adding watermark: $watermarkText');

      // In a real implementation, you would:
      // 1. Create a text image with the watermark
      // 2. Position it according to watermarkPosition
      // 3. Composite it onto the main image with specified opacity

      return image;
    } catch (e) {
      debugPrint('Error adding watermark: $e');
      return image;
    }
  }

  /// Create metadata file for sharing
  Future<String?> _createMetadataFile(
    PhotoWaypoint photo,
    Directory shareDir,
    SharingOptions options,
  ) async {
    try {
      // Get metadata from service
      final List<PhotoMetadata> metadata =
          await _photoCaptureService.getPhotoMetadata(photo.id);

      // Filter metadata based on privacy level
      List<PhotoMetadata> filteredMetadata = metadata;
      if (options.privacyLevel != PrivacyLevel.none) {
        filteredMetadata = metadata.where((meta) {
          // Remove private data based on privacy level
          if (options.privacyLevel == PrivacyLevel.location) {
            return !meta.key.contains('location_') &&
                !meta.key.contains('gps_') &&
                !meta.key.contains('compass_');
          } else {
            // For metadata and higher levels, only include custom data
            return meta.isCustomData;
          }
        }).toList();
      }

      // Create metadata JSON
      final Map<String, dynamic> metadataJson = {
        'photo_info': {
          'id': photo.id,
          'created_at': photo.createdAt.toIso8601String(),
          'file_size': photo.fileSize,
          'dimensions': {
            'width': photo.width,
            'height': photo.height,
          },
        },
        'metadata': filteredMetadata
            .map((meta) => {
                  'key': meta.key,
                  'value': meta.value,
                  'type': meta.type.name,
                  'display_value': meta.displayValue,
                })
            .toList(),
        'sharing_info': {
          'shared_at': DateTime.now().toIso8601String(),
          'privacy_level': options.privacyLevel.name,
          'metadata_filtered': options.privacyLevel != PrivacyLevel.none,
        },
      };

      // Write metadata file
      final String metadataFilename =
          '${path.basenameWithoutExtension(_generateShareFilename(photo, options))}_info.json';
      final String metadataPath = path.join(shareDir.path, metadataFilename);

      await File(metadataPath).writeAsString(
        const JsonEncoder.withIndent('  ').convert(metadataJson),
      );

      return metadataPath;
    } catch (e) {
      debugPrint('Error creating metadata file: $e');
      return null;
    }
  }

  /// Generate filename for shared photo
  String _generateShareFilename(PhotoWaypoint photo, SharingOptions options) {
    // Create privacy-safe filename
    final String dateStr = photo.createdAt
        .toIso8601String()
        .replaceAll('-', '')
        .replaceAll(':', '')
        .replaceAll('T', '_')
        .split('.')[0];

    String privacyPrefix = '';
    switch (options.privacyLevel) {
      case PrivacyLevel.none:
        privacyPrefix = '';
        break;
      case PrivacyLevel.location:
        privacyPrefix = 'noloc_';
        break;
      case PrivacyLevel.metadata:
        privacyPrefix = 'clean_';
        break;
      case PrivacyLevel.watermarked:
        privacyPrefix = 'wm_';
        break;
      case PrivacyLevel.maximum:
        privacyPrefix = 'private_';
        break;
    }

    return '${privacyPrefix}photo_$dateStr.jpg';
  }

  /// Share files using the specified destination
  Future<bool> _shareFiles(
      List<String> filePaths, SharingOptions options) async {
    try {
      if (filePaths.isEmpty) {
        return false;
      }

      switch (options.destination) {
        case SharingDestination.system:
          return await _shareViaSystem(filePaths, options);
        case SharingDestination.email:
          return await _shareViaEmail(filePaths, options);
        case SharingDestination.social:
          return await _shareViaSocial(filePaths, options);
        case SharingDestination.cloud:
          return await _shareViaCloud(filePaths, options);
        case SharingDestination.files:
          return await _shareViaFiles(filePaths, options);
      }
    } catch (e) {
      debugPrint('Error sharing files: $e');
      return false;
    }
  }

  /// Share via system share dialog
  Future<bool> _shareViaSystem(
      List<String> filePaths, SharingOptions options) async {
    try {
      final List<XFile> files = filePaths.map(XFile.new).toList();

      String message = options.customMessage ?? 'Photos from Obsession Tracker';

      // Add privacy notice if applicable
      if (options.privacyLevel != PrivacyLevel.none) {
        message +=
            '\n\nPrivacy: ${_getPrivacyDescription(options.privacyLevel)}';
      }

      await SharePlus.instance.share(ShareParams(files: files, text: message));
      return true;
    } catch (e) {
      debugPrint('Error sharing via system: $e');
      return false;
    }
  }

  /// Share via email
  Future<bool> _shareViaEmail(
      List<String> filePaths, SharingOptions options) async {
    try {
      // TODO(obsession): Implement email sharing
      debugPrint('Email sharing not yet implemented');
      return false;
    } catch (e) {
      debugPrint('Error sharing via email: $e');
      return false;
    }
  }

  /// Share via social media
  Future<bool> _shareViaSocial(
      List<String> filePaths, SharingOptions options) async {
    try {
      // TODO(obsession): Implement social media sharing
      debugPrint('Social media sharing not yet implemented');
      return false;
    } catch (e) {
      debugPrint('Error sharing via social media: $e');
      return false;
    }
  }

  /// Share via cloud storage
  Future<bool> _shareViaCloud(
      List<String> filePaths, SharingOptions options) async {
    try {
      // TODO(obsession): Implement cloud storage sharing
      debugPrint('Cloud storage sharing not yet implemented');
      return false;
    } catch (e) {
      debugPrint('Error sharing via cloud: $e');
      return false;
    }
  }

  /// Share via files (save to device)
  Future<bool> _shareViaFiles(
      List<String> filePaths, SharingOptions options) async {
    try {
      // TODO(obsession): Implement file system sharing
      debugPrint('File system sharing not yet implemented');
      return false;
    } catch (e) {
      debugPrint('Error sharing via files: $e');
      return false;
    }
  }

  /// Get privacy level description
  String _getPrivacyDescription(PrivacyLevel level) {
    switch (level) {
      case PrivacyLevel.none:
        return 'No privacy protection applied';
      case PrivacyLevel.location:
        return 'Location data removed';
      case PrivacyLevel.metadata:
        return 'All metadata removed';
      case PrivacyLevel.watermarked:
        return 'Metadata removed, watermark added';
      case PrivacyLevel.maximum:
        return 'Maximum privacy protection applied';
    }
  }

  /// Analyze photo privacy risks
  Future<PrivacyAnalysis> analyzePhotoPrivacy(PhotoWaypoint photo) async {
    try {
      final List<PhotoMetadata> metadata =
          await _photoCaptureService.getPhotoMetadata(photo.id);

      bool hasGpsData = false;
      bool hasPersonalMetadata = false;
      bool hasCameraInfo = false;
      bool hasTimestamp = false;
      double? gpsAccuracy;
      final List<String> warnings = <String>[];

      for (final PhotoMetadata meta in metadata) {
        // Check for GPS data
        if (meta.key.contains('location_') || meta.key.contains('gps_')) {
          hasGpsData = true;
          if (meta.key == 'location_accuracy') {
            gpsAccuracy = meta.typedValue as double?;
            if (gpsAccuracy != null && gpsAccuracy < 10.0) {
              warnings.add(
                  'High-precision GPS data detected (${gpsAccuracy.toStringAsFixed(1)}m accuracy)');
            }
          }
        }

        // Check for camera info
        if (meta.key.contains('camera_') || meta.key.contains('exif_')) {
          hasCameraInfo = true;
        }

        // Check for personal metadata
        if (meta.isCustomData) {
          hasPersonalMetadata = true;
        }

        // Check for timestamp
        if (meta.key.contains('date') || meta.key.contains('time')) {
          hasTimestamp = true;
        }
      }

      // Add warnings based on findings
      if (hasGpsData) {
        warnings.add(
            'Photo contains location data that could reveal your position');
      }
      if (hasPersonalMetadata) {
        warnings.add(
            'Photo contains custom metadata that may include personal information');
      }
      if (hasCameraInfo) {
        warnings.add('Photo contains camera and device information');
      }

      // Determine recommended privacy level
      PrivacyLevel recommendedLevel = PrivacyLevel.none;
      if (hasGpsData || hasPersonalMetadata) {
        recommendedLevel = PrivacyLevel.metadata;
      } else if (hasCameraInfo) {
        recommendedLevel = PrivacyLevel.location;
      }

      return PrivacyAnalysis(
        hasGpsData: hasGpsData,
        hasPersonalMetadata: hasPersonalMetadata,
        hasCameraInfo: hasCameraInfo,
        hasTimestamp: hasTimestamp,
        gpsAccuracy: gpsAccuracy,
        recommendedPrivacyLevel: recommendedLevel,
        warnings: warnings,
      );
    } catch (e) {
      debugPrint('Error analyzing photo privacy: $e');
      return const PrivacyAnalysis(
        hasGpsData: false,
        hasPersonalMetadata: false,
        hasCameraInfo: false,
        hasTimestamp: false,
      );
    }
  }

  /// Get sharing presets for common scenarios
  List<SharingOptions> getSharingPresets() => [
        // Quick share (minimal privacy)
        const SharingOptions(
          privacyLevel: PrivacyLevel.location,
        ),

        // Social media share
        const SharingOptions(
          destination: SharingDestination.social,
          includeWatermark: true,
          maxWidth: 1080,
          jpegQuality: 80,
        ),

        // Professional share
        const SharingOptions(
          privacyLevel: PrivacyLevel.watermarked,
          destination: SharingDestination.email,
          includeWatermark: true,
          resizeForSharing: false,
          jpegQuality: 95,
          includeMetadataFile: true,
        ),

        // Maximum privacy share
        const SharingOptions(
          privacyLevel: PrivacyLevel.maximum,
          includeWatermark: true,
          maxWidth: 1024,
          maxHeight: 768,
          jpegQuality: 75,
        ),
      ];

  /// Dispose of the service
  void dispose() {
    _instance = null;
  }
}
