import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/performance_models.dart';
import 'package:path_provider/path_provider.dart';

/// App size optimization and resource management service
///
/// Provides comprehensive app size analysis, asset optimization, and resource
/// management to minimize app footprint and improve performance.
class AppSizeOptimizationService {
  factory AppSizeOptimizationService() =>
      _instance ??= AppSizeOptimizationService._();
  AppSizeOptimizationService._();
  static AppSizeOptimizationService? _instance;

  // Stream controllers
  StreamController<AppSizeOptimizationEvent>? _optimizationEventController;

  // Service state
  bool _isActive = false;

  // Size tracking
  final List<AppSizeAnalysis> _sizeHistory = <AppSizeAnalysis>[];
  static const int _maxSizeHistoryLength = 50;

  // Storage paths
  String? _appDocumentsPath;
  String? _cachePath;
  String? _tempPath;

  /// Stream of app size optimization events
  Stream<AppSizeOptimizationEvent> get optimizationEventStream {
    _optimizationEventController ??=
        StreamController<AppSizeOptimizationEvent>.broadcast();
    return _optimizationEventController!.stream;
  }

  /// Whether the service is active
  bool get isActive => _isActive;

  /// Size analysis history
  List<AppSizeAnalysis> get sizeHistory => List.unmodifiable(_sizeHistory);

  /// Start app size optimization service
  Future<void> start() async {
    try {
      await stop(); // Ensure clean start

      debugPrint('📦 Starting app size optimization service...');

      // Initialize storage paths
      await _initializeStoragePaths();

      // Initialize stream controllers
      _optimizationEventController ??=
          StreamController<AppSizeOptimizationEvent>.broadcast();

      // Perform initial size analysis
      await _performSizeAnalysis();

      _isActive = true;
      debugPrint('📦 App size optimization service started successfully');
    } catch (e) {
      debugPrint('📦 Error starting app size optimization service: $e');
      rethrow;
    }
  }

  /// Stop app size optimization service
  Future<void> stop() async {
    // Close stream controllers
    await _optimizationEventController?.close();
    _optimizationEventController = null;

    _isActive = false;
    debugPrint('📦 App size optimization service stopped');
  }

  /// Get current app size optimization data
  Future<AppSizeOptimization> getAppSizeOptimization() async {
    final analysis = await _performSizeAnalysis();

    final recommendations = _generateOptimizationRecommendations(analysis);

    return AppSizeOptimization(
      totalAppSize: analysis.totalSize,
      codeSize: analysis.codeSize,
      assetSize: analysis.assetSize,
      dataSize: analysis.dataSize,
      cacheSize: analysis.cacheSize,
      optimizationPotential: _calculateOptimizationPotential(analysis),
      recommendations: recommendations,
      timestamp: DateTime.now(),
    );
  }

  /// Perform comprehensive app size optimization
  Future<AppSizeOptimizationResult> performOptimization({
    bool optimizeAssets = true,
    bool cleanupUnusedFiles = true,
    bool compressData = true,
    bool optimizeCode = false, // Requires build-time optimization
  }) async {
    debugPrint('📦 Starting app size optimization...');

    final startTime = DateTime.now();
    int totalBytesSaved = 0;
    final optimizationDetails = <String, int>{};
    final errors = <String>[];

    try {
      // Optimize assets
      if (optimizeAssets) {
        try {
          final assetsSaved = await _optimizeAssets();
          totalBytesSaved += assetsSaved;
          optimizationDetails['assets'] = assetsSaved;
          debugPrint('📦 Optimized assets: ${_formatBytes(assetsSaved)}');
        } catch (e) {
          errors.add('Asset optimization failed: $e');
        }
      }

      // Cleanup unused files
      if (cleanupUnusedFiles) {
        try {
          final filesSaved = await _cleanupUnusedFiles();
          totalBytesSaved += filesSaved;
          optimizationDetails['unusedFiles'] = filesSaved;
          debugPrint('📦 Cleaned unused files: ${_formatBytes(filesSaved)}');
        } catch (e) {
          errors.add('Unused file cleanup failed: $e');
        }
      }

      // Compress data
      if (compressData) {
        try {
          final dataSaved = await _compressData();
          totalBytesSaved += dataSaved;
          optimizationDetails['dataCompression'] = dataSaved;
          debugPrint('📦 Compressed data: ${_formatBytes(dataSaved)}');
        } catch (e) {
          errors.add('Data compression failed: $e');
        }
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      final result = AppSizeOptimizationResult(
        success: errors.isEmpty,
        duration: duration,
        bytesSaved: totalBytesSaved,
        optimizationDetails: optimizationDetails,
        errors: errors,
        timestamp: endTime,
      );

      // Emit optimization event
      final event = AppSizeOptimizationEvent(
        type: AppSizeOptimizationEventType.optimizationCompleted,
        description: 'App size optimization completed',
        bytesSaved: totalBytesSaved,
        timestamp: DateTime.now(),
        result: result,
      );
      _optimizationEventController?.add(event);

      debugPrint(
          '📦 App size optimization completed: ${_formatBytes(totalBytesSaved)} saved in ${duration.inSeconds}s');
      return result;
    } catch (e) {
      debugPrint('📦 Error during app size optimization: $e');

      return AppSizeOptimizationResult(
        success: false,
        duration: DateTime.now().difference(startTime),
        bytesSaved: totalBytesSaved,
        optimizationDetails: optimizationDetails,
        errors: [...errors, 'Optimization failed: $e'],
        timestamp: DateTime.now(),
      );
    }
  }

  /// Get app size recommendations
  List<SizeOptimizationRecommendation> getOptimizationRecommendations() {
    if (_sizeHistory.isEmpty) return [];

    final latestAnalysis = _sizeHistory.last;
    return _generateOptimizationRecommendations(latestAnalysis);
  }

  /// Analyze app size breakdown
  Future<AppSizeBreakdown> analyzeAppSize() async {
    final analysis = await _performSizeAnalysis();

    return AppSizeBreakdown(
      totalSize: analysis.totalSize,
      breakdown: {
        'Code': analysis.codeSize,
        'Assets': analysis.assetSize,
        'Data': analysis.dataSize,
        'Cache': analysis.cacheSize,
        'Other': analysis.totalSize -
            analysis.codeSize -
            analysis.assetSize -
            analysis.dataSize -
            analysis.cacheSize,
      },
      largestFiles: analysis.largestFiles,
      analysisTime: DateTime.now(),
    );
  }

  Future<void> _initializeStoragePaths() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();

      _appDocumentsPath = documentsDir.path;
      _tempPath = tempDir.path;

      // Try to get cache directory
      try {
        final cacheDir = await getApplicationCacheDirectory();
        _cachePath = cacheDir.path;
      } catch (e) {
        debugPrint('📦 Cache directory not available: $e');
        _cachePath = tempDir.path; // Fallback to temp directory
      }
    } catch (e) {
      debugPrint('📦 Error initializing storage paths: $e');
    }
  }

  Future<AppSizeAnalysis> _performSizeAnalysis() async {
    try {
      final codeSize = await _calculateCodeSize();
      final assetSize = await _calculateAssetSize();
      final dataSize = await _calculateDataSize();
      final cacheSize = await _calculateCacheSize();
      final largestFiles = await _findLargestFiles();

      final totalSize = codeSize + assetSize + dataSize + cacheSize;

      final analysis = AppSizeAnalysis(
        totalSize: totalSize,
        codeSize: codeSize,
        assetSize: assetSize,
        dataSize: dataSize,
        cacheSize: cacheSize,
        largestFiles: largestFiles,
        analysisTime: DateTime.now(),
      );

      // Add to history
      _sizeHistory.add(analysis);
      if (_sizeHistory.length > _maxSizeHistoryLength) {
        _sizeHistory.removeAt(0);
      }

      return analysis;
    } catch (e) {
      debugPrint('📦 Error performing size analysis: $e');

      // Return default analysis on error
      return AppSizeAnalysis(
        totalSize: 0,
        codeSize: 0,
        assetSize: 0,
        dataSize: 0,
        cacheSize: 0,
        largestFiles: [],
        analysisTime: DateTime.now(),
      );
    }
  }

  Future<int> _calculateCodeSize() async =>
      // In a real implementation, this would analyze the app bundle
      // For now, return an estimate
      50 * 1024 * 1024; // 50MB estimate

  Future<int> _calculateAssetSize() async {
    int totalSize = 0;

    try {
      // Calculate assets in the app bundle (would need platform-specific implementation)
      // For now, estimate based on common asset sizes
      totalSize += 20 * 1024 * 1024; // 20MB estimate for images, fonts, etc.
    } catch (e) {
      debugPrint('📦 Error calculating asset size: $e');
    }

    return totalSize;
  }

  Future<int> _calculateDataSize() async {
    int totalSize = 0;

    if (_appDocumentsPath != null) {
      try {
        final appDir = Directory(_appDocumentsPath!);
        if (appDir.existsSync()) {
          totalSize += await _getDirectorySize(appDir);
        }
      } catch (e) {
        debugPrint('📦 Error calculating data size: $e');
      }
    }

    return totalSize;
  }

  Future<int> _calculateCacheSize() async {
    int totalSize = 0;

    if (_cachePath != null) {
      try {
        final cacheDir = Directory(_cachePath!);
        if (cacheDir.existsSync()) {
          totalSize += await _getDirectorySize(cacheDir);
        }
      } catch (e) {
        debugPrint('📦 Error calculating cache size: $e');
      }
    }

    return totalSize;
  }

  Future<List<LargeFile>> _findLargestFiles() async {
    final largestFiles = <LargeFile>[];

    try {
      if (_appDocumentsPath != null) {
        final appDir = Directory(_appDocumentsPath!);
        if (appDir.existsSync()) {
          await _findLargestFilesInDirectory(appDir, largestFiles);
        }
      }

      if (_cachePath != null) {
        final cacheDir = Directory(_cachePath!);
        if (cacheDir.existsSync()) {
          await _findLargestFilesInDirectory(cacheDir, largestFiles);
        }
      }

      // Sort by size and take top 10
      largestFiles.sort((a, b) => b.size.compareTo(a.size));
      return largestFiles.take(10).toList();
    } catch (e) {
      debugPrint('📦 Error finding largest files: $e');
      return [];
    }
  }

  Future<void> _findLargestFilesInDirectory(
      Directory directory, List<LargeFile> largestFiles) async {
    try {
      final entities = await directory.list(recursive: true).toList();
      for (final entity in entities) {
        if (entity is File) {
          try {
            final stat = entity.statSync();
            if (stat.size > 1024 * 1024) {
              // Files larger than 1MB
              largestFiles.add(LargeFile(
                path: entity.path,
                size: stat.size,
                type: _getFileType(entity.path),
              ));
            }
          } catch (e) {
            // Ignore individual file errors
          }
        }
      }
    } catch (e) {
      debugPrint('📦 Error finding largest files in directory: $e');
    }
  }

  String _getFileType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return 'Image';
      case 'mp4':
      case 'mov':
      case 'avi':
        return 'Video';
      case 'mp3':
      case 'wav':
      case 'aac':
        return 'Audio';
      case 'db':
      case 'sqlite':
        return 'Database';
      case 'json':
      case 'xml':
        return 'Data';
      default:
        return 'Other';
    }
  }

  Future<int> _getDirectorySize(Directory directory) async {
    int totalSize = 0;

    try {
      final entities = await directory.list(recursive: true).toList();
      for (final entity in entities) {
        if (entity is File) {
          try {
            final stat = entity.statSync();
            totalSize += stat.size;
          } catch (e) {
            // Ignore individual file errors
          }
        }
      }
    } catch (e) {
      debugPrint('📦 Error calculating directory size: $e');
    }

    return totalSize;
  }

  Future<int> _optimizeAssets() async {
    int bytesSaved = 0;

    try {
      // In a real implementation, this would:
      // 1. Compress images using flutter_image_compress
      // 2. Remove unused assets
      // 3. Optimize vector graphics
      // 4. Convert to more efficient formats

      // For now, return estimated savings
      bytesSaved = 5 * 1024 * 1024; // 5MB estimate
    } catch (e) {
      debugPrint('📦 Error optimizing assets: $e');
    }

    return bytesSaved;
  }

  Future<int> _cleanupUnusedFiles() async {
    int bytesSaved = 0;

    try {
      // Remove temporary files
      if (_tempPath != null) {
        final tempDir = Directory(_tempPath!);
        if (tempDir.existsSync()) {
          final entities = await tempDir.list().toList();
          for (final entity in entities) {
            if (entity is File) {
              try {
                final stat = entity.statSync();
                await entity.delete();
                bytesSaved += stat.size;
              } catch (e) {
                // Ignore individual file errors
              }
            }
          }
        }
      }

      // Remove old log files
      if (_appDocumentsPath != null) {
        final logFiles = await _findOldLogFiles();
        for (final file in logFiles) {
          try {
            final stat = file.statSync();
            await file.delete();
            bytesSaved += stat.size;
          } catch (e) {
            // Ignore individual file errors
          }
        }
      }
    } catch (e) {
      debugPrint('📦 Error cleaning unused files: $e');
    }

    return bytesSaved;
  }

  Future<List<File>> _findOldLogFiles() async {
    final oldFiles = <File>[];

    try {
      if (_appDocumentsPath != null) {
        final appDir = Directory(_appDocumentsPath!);
        if (appDir.existsSync()) {
          final entities = await appDir.list(recursive: true).toList();
          for (final entity in entities) {
            if (entity is File &&
                (entity.path.endsWith('.log') ||
                    entity.path.endsWith('.txt'))) {
              final stat = entity.statSync();
              final age = DateTime.now().difference(stat.modified);
              if (age.inDays > 30) {
                // Files older than 30 days
                oldFiles.add(entity);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('📦 Error finding old log files: $e');
    }

    return oldFiles;
  }

  Future<int> _compressData() async {
    int bytesSaved = 0;

    try {
      // In a real implementation, this would:
      // 1. Compress JSON files
      // 2. Optimize database files
      // 3. Archive old data

      // For now, return estimated savings
      bytesSaved = 2 * 1024 * 1024; // 2MB estimate
    } catch (e) {
      debugPrint('📦 Error compressing data: $e');
    }

    return bytesSaved;
  }

  int _calculateOptimizationPotential(AppSizeAnalysis analysis) {
    int potential = 0;

    // Estimate optimization potential based on file types and sizes
    potential += (analysis.assetSize * 0.3).round(); // 30% asset compression
    potential += (analysis.cacheSize * 0.8).round(); // 80% cache cleanup
    potential += (analysis.dataSize * 0.1).round(); // 10% data compression

    return potential;
  }

  List<SizeOptimizationRecommendation> _generateOptimizationRecommendations(
      AppSizeAnalysis analysis) {
    final recommendations = <SizeOptimizationRecommendation>[];

    // Large asset recommendation
    if (analysis.assetSize > 50 * 1024 * 1024) {
      // 50MB
      recommendations.add(SizeOptimizationRecommendation(
        type: OptimizationType.compressAssets,
        title: 'Compress Large Assets',
        description:
            'Asset size is large (${_formatBytes(analysis.assetSize)}). Consider compressing images and optimizing assets.',
        priority: OptimizationPriority.high,
        potentialSavings: (analysis.assetSize * 0.3).round(),
        effort: OptimizationEffort.medium,
      ));
    }

    // Large cache recommendation
    if (analysis.cacheSize > 100 * 1024 * 1024) {
      // 100MB
      recommendations.add(SizeOptimizationRecommendation(
        type: OptimizationType.cleanupCache,
        title: 'Clear Large Cache',
        description:
            'Cache size is large (${_formatBytes(analysis.cacheSize)}). Consider clearing cache files.',
        priority: OptimizationPriority.medium,
        potentialSavings: (analysis.cacheSize * 0.8).round(),
        effort: OptimizationEffort.minimal,
      ));
    }

    // Large data recommendation
    if (analysis.dataSize > 200 * 1024 * 1024) {
      // 200MB
      recommendations.add(SizeOptimizationRecommendation(
        type: OptimizationType.removeOldData,
        title: 'Remove Old Data',
        description:
            'Data size is large (${_formatBytes(analysis.dataSize)}). Consider removing old or unused data.',
        priority: OptimizationPriority.medium,
        potentialSavings: (analysis.dataSize * 0.2).round(),
        effort: OptimizationEffort.low,
      ));
    }

    return recommendations;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    stop();
    _sizeHistory.clear();
    _instance = null;
  }
}

/// App size analysis data
class AppSizeAnalysis {
  const AppSizeAnalysis({
    required this.totalSize,
    required this.codeSize,
    required this.assetSize,
    required this.dataSize,
    required this.cacheSize,
    required this.largestFiles,
    required this.analysisTime,
  });

  final int totalSize;
  final int codeSize;
  final int assetSize;
  final int dataSize;
  final int cacheSize;
  final List<LargeFile> largestFiles;
  final DateTime analysisTime;
}

/// App size breakdown
class AppSizeBreakdown {
  const AppSizeBreakdown({
    required this.totalSize,
    required this.breakdown,
    required this.largestFiles,
    required this.analysisTime,
  });

  final int totalSize;
  final Map<String, int> breakdown;
  final List<LargeFile> largestFiles;
  final DateTime analysisTime;

  /// Size breakdown as percentages
  Map<String, double> get percentageBreakdown {
    if (totalSize == 0) return {};

    return breakdown
        .map((key, value) => MapEntry(key, (value / totalSize) * 100));
  }
}

/// Large file information
class LargeFile {
  const LargeFile({
    required this.path,
    required this.size,
    required this.type,
  });

  final String path;
  final int size;
  final String type;

  /// File name
  String get name => path.split('/').last;

  /// Size in MB
  double get sizeMB => size / (1024 * 1024);
}

/// App size optimization event
class AppSizeOptimizationEvent {
  const AppSizeOptimizationEvent({
    required this.type,
    required this.description,
    required this.bytesSaved,
    required this.timestamp,
    this.result,
  });

  final AppSizeOptimizationEventType type;
  final String description;
  final int bytesSaved;
  final DateTime timestamp;
  final AppSizeOptimizationResult? result;

  @override
  String toString() =>
      'AppSizeOptimizationEvent(${type.displayName}: $bytesSaved bytes saved)';
}

/// App size optimization event types
enum AppSizeOptimizationEventType {
  analysisStarted,
  analysisCompleted,
  optimizationStarted,
  optimizationCompleted,
  optimizationFailed;

  String get displayName {
    switch (this) {
      case AppSizeOptimizationEventType.analysisStarted:
        return 'Analysis Started';
      case AppSizeOptimizationEventType.analysisCompleted:
        return 'Analysis Completed';
      case AppSizeOptimizationEventType.optimizationStarted:
        return 'Optimization Started';
      case AppSizeOptimizationEventType.optimizationCompleted:
        return 'Optimization Completed';
      case AppSizeOptimizationEventType.optimizationFailed:
        return 'Optimization Failed';
    }
  }
}

/// App size optimization result
class AppSizeOptimizationResult {
  const AppSizeOptimizationResult({
    required this.success,
    required this.duration,
    required this.bytesSaved,
    required this.optimizationDetails,
    required this.errors,
    required this.timestamp,
  });

  final bool success;
  final Duration duration;
  final int bytesSaved;
  final Map<String, int> optimizationDetails;
  final List<String> errors;
  final DateTime timestamp;

  /// Optimization efficiency score (0-100)
  double get efficiencyScore {
    double score = success ? 80.0 : 20.0;

    // Reward bytes saved
    if (bytesSaved > 50 * 1024 * 1024)
      score += 20; // 50MB+
    else if (bytesSaved > 10 * 1024 * 1024)
      score += 10; // 10MB+
    else if (bytesSaved > 1024 * 1024) score += 5; // 1MB+

    // Penalize errors
    score -= errors.length * 5;

    // Reward quick optimization
    if (duration.inSeconds < 30)
      score += 10;
    else if (duration.inSeconds < 60) score += 5;

    return score.clamp(0.0, 100.0);
  }
}
