import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/performance_models.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/photo_storage_service.dart';
import 'package:path_provider/path_provider.dart';

/// Comprehensive storage cleanup and management service
///
/// Provides automatic storage cleanup, optimization, monitoring, and maintenance
/// to ensure optimal app performance and storage efficiency.
class StorageCleanupService {
  factory StorageCleanupService() => _instance ??= StorageCleanupService._();
  StorageCleanupService._();
  static StorageCleanupService? _instance;

  // Stream controllers
  StreamController<StorageCleanupEvent>? _cleanupEventController;
  StreamController<StorageAnalytics>? _analyticsController;

  // Service state
  bool _isActive = false;
  StorageCleanupConfig _config = StorageCleanupConfig.defaultConfig();

  // Storage tracking
  final List<StorageCleanupResult> _cleanupHistory = <StorageCleanupResult>[];
  final Map<String, int> _storageUsageHistory = {};
  static const int _maxCleanupHistoryLength = 100;

  // Cleanup timers
  Timer? _automaticCleanupTimer;
  Timer? _monitoringTimer;

  // Dependencies
  final DatabaseService _databaseService = DatabaseService();
  final PhotoStorageService _photoStorageService = PhotoStorageService();
//   final TileCacheService _tileCacheService = TileCacheService();

  // Storage paths
  String? _appDocumentsPath;
  String? _tempPath;
  String? _cachePath;

  /// Stream of storage cleanup events
  Stream<StorageCleanupEvent> get cleanupEventStream {
    _cleanupEventController ??=
        StreamController<StorageCleanupEvent>.broadcast();
    return _cleanupEventController!.stream;
  }

  /// Stream of storage analytics
  Stream<StorageAnalytics> get analyticsStream {
    _analyticsController ??= StreamController<StorageAnalytics>.broadcast();
    return _analyticsController!.stream;
  }

  /// Whether storage cleanup is active
  bool get isActive => _isActive;

  /// Current storage cleanup configuration
  StorageCleanupConfig get config => _config;

  /// Cleanup history
  List<StorageCleanupResult> get cleanupHistory =>
      List.unmodifiable(_cleanupHistory);

  /// Start storage cleanup service
  Future<void> start({
    StorageCleanupConfig? config,
  }) async {
    try {
      await stop(); // Ensure clean start

      _config = config ?? StorageCleanupConfig.defaultConfig();

      debugPrint('🧹 Starting storage cleanup service...');
      debugPrint('  Auto cleanup enabled: ${_config.automaticCleanupEnabled}');
      debugPrint(
          '  Cleanup interval: ${_config.automaticCleanupInterval.inHours}h');

      // Initialize storage paths
      await _initializeStoragePaths();

      // Initialize stream controllers
      _cleanupEventController ??=
          StreamController<StorageCleanupEvent>.broadcast();
      _analyticsController ??= StreamController<StorageAnalytics>.broadcast();

      // Start automatic cleanup if enabled
      if (_config.automaticCleanupEnabled) {
        _automaticCleanupTimer =
            Timer.periodic(_config.automaticCleanupInterval, (_) {
          performAutomaticCleanup();
        });
      }

      // Start storage monitoring
      _monitoringTimer = Timer.periodic(
        const Duration(hours: 1),
        (_) => _monitorStorageUsage(),
      );

      // Perform initial storage analysis
      await _monitorStorageUsage();

      _isActive = true;
      debugPrint('🧹 Storage cleanup service started successfully');
    } catch (e) {
      debugPrint('🧹 Error starting storage cleanup service: $e');
      rethrow;
    }
  }

  /// Stop storage cleanup service
  Future<void> stop() async {
    // Cancel timers
    _automaticCleanupTimer?.cancel();
    _automaticCleanupTimer = null;

    _monitoringTimer?.cancel();
    _monitoringTimer = null;

    // Close stream controllers
    await _cleanupEventController?.close();
    _cleanupEventController = null;

    await _analyticsController?.close();
    _analyticsController = null;

    _isActive = false;
    debugPrint('🧹 Storage cleanup service stopped');
  }

  /// Update configuration
  Future<void> updateConfig(StorageCleanupConfig newConfig) async {
    _config = newConfig;
    debugPrint('🧹 Storage cleanup config updated');

    // Restart if needed
    if (_isActive) {
      await start(config: newConfig);
    }
  }

  /// Perform comprehensive storage cleanup
  Future<StorageCleanupResult> performComprehensiveCleanup({
    bool cleanTempFiles = true,
    bool cleanCacheFiles = true,
    bool cleanOldPhotos = false,
    bool cleanOldSessions = false,
    bool optimizeDatabase = true,
    bool cleanLogs = true,
  }) async {
    debugPrint('🧹 Starting comprehensive storage cleanup...');

    final startTime = DateTime.now();
    int totalBytesFreed = 0;
    final cleanupDetails = <String, int>{};
    final errors = <String>[];

    try {
      // Clean temporary files
      if (cleanTempFiles) {
        try {
          final tempBytesFreed = await _cleanTemporaryFiles();
          totalBytesFreed += tempBytesFreed;
          cleanupDetails['temporaryFiles'] = tempBytesFreed;
          debugPrint(
              '🧹 Cleaned temporary files: ${_formatBytes(tempBytesFreed)}');
        } catch (e) {
          errors.add('Failed to clean temporary files: $e');
        }
      }

      // Clean cache files
      if (cleanCacheFiles) {
        try {
          final cacheBytesFreed = await _cleanCacheFiles();
          totalBytesFreed += cacheBytesFreed;
          cleanupDetails['cacheFiles'] = cacheBytesFreed;
          debugPrint(
              '🧹 Cleaned cache files: ${_formatBytes(cacheBytesFreed)}');
        } catch (e) {
          errors.add('Failed to clean cache files: $e');
        }
      }

      // Clean old photos (if enabled)
      if (cleanOldPhotos && _config.cleanOldPhotosEnabled) {
        try {
          final photoBytesFreed = await _cleanOldPhotos();
          totalBytesFreed += photoBytesFreed;
          cleanupDetails['oldPhotos'] = photoBytesFreed;
          debugPrint('🧹 Cleaned old photos: ${_formatBytes(photoBytesFreed)}');
        } catch (e) {
          errors.add('Failed to clean old photos: $e');
        }
      }

      // Clean old sessions (if enabled)
      if (cleanOldSessions && _config.cleanOldSessionsEnabled) {
        try {
          final sessionBytesFreed = await _cleanOldSessions();
          totalBytesFreed += sessionBytesFreed;
          cleanupDetails['oldSessions'] = sessionBytesFreed;
          debugPrint(
              '🧹 Cleaned old sessions: ${_formatBytes(sessionBytesFreed)}');
        } catch (e) {
          errors.add('Failed to clean old sessions: $e');
        }
      }

      // Optimize database
      if (optimizeDatabase) {
        try {
          final dbBytesFreed = await _optimizeDatabase();
          totalBytesFreed += dbBytesFreed;
          cleanupDetails['databaseOptimization'] = dbBytesFreed;
          debugPrint('🧹 Optimized database: ${_formatBytes(dbBytesFreed)}');
        } catch (e) {
          errors.add('Failed to optimize database: $e');
        }
      }

      // Clean log files
      if (cleanLogs) {
        try {
          final logBytesFreed = await _cleanLogFiles();
          totalBytesFreed += logBytesFreed;
          cleanupDetails['logFiles'] = logBytesFreed;
          debugPrint('🧹 Cleaned log files: ${_formatBytes(logBytesFreed)}');
        } catch (e) {
          errors.add('Failed to clean log files: $e');
        }
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      final result = StorageCleanupResult(
        cleanupType: StorageCleanupType.comprehensive,
        startTime: startTime,
        endTime: endTime,
        duration: duration,
        bytesFreed: totalBytesFreed,
        cleanupDetails: cleanupDetails,
        errors: errors,
        success: errors.isEmpty,
      );

      // Add to history
      _cleanupHistory.add(result);
      if (_cleanupHistory.length > _maxCleanupHistoryLength) {
        _cleanupHistory.removeAt(0);
      }

      // Emit cleanup event
      final event = StorageCleanupEvent(
        type: StorageCleanupEventType.cleanupCompleted,
        description: 'Comprehensive cleanup completed',
        bytesFreed: totalBytesFreed,
        timestamp: DateTime.now(),
        result: result,
      );
      _cleanupEventController?.add(event);

      debugPrint(
          '🧹 Comprehensive cleanup completed: ${_formatBytes(totalBytesFreed)} freed in ${duration.inSeconds}s');
      return result;
    } catch (e) {
      debugPrint('🧹 Error during comprehensive cleanup: $e');

      final result = StorageCleanupResult(
        cleanupType: StorageCleanupType.comprehensive,
        startTime: startTime,
        endTime: DateTime.now(),
        duration: DateTime.now().difference(startTime),
        bytesFreed: totalBytesFreed,
        cleanupDetails: cleanupDetails,
        errors: [...errors, 'Cleanup failed: $e'],
        success: false,
      );

      _cleanupHistory.add(result);
      return result;
    }
  }

  /// Perform automatic cleanup based on configuration
  Future<StorageCleanupResult> performAutomaticCleanup() async {
    debugPrint('🧹 Performing automatic storage cleanup...');

    return performComprehensiveCleanup(
      cleanOldPhotos: _config.cleanOldPhotosEnabled,
      cleanOldSessions: _config.cleanOldSessionsEnabled,
      optimizeDatabase: _config.optimizeDatabaseEnabled,
    );
  }

  /// Get current storage analytics
  Future<StorageAnalytics> getStorageAnalytics() async =>
      _generateStorageAnalytics();

  /// Get storage optimization recommendations
  Future<List<StorageOptimizationRecommendation>>
      getOptimizationRecommendations() async {
    final recommendations = <StorageOptimizationRecommendation>[];
    final analytics = await getStorageAnalytics();

    // High storage usage recommendation
    if (analytics.storageUsagePercentage > 80) {
      recommendations.add(StorageOptimizationRecommendation(
        type: StorageOptimizationType.cleanupOldData,
        title: 'Storage Usage Critical',
        description:
            'Storage usage is very high (${analytics.storageUsagePercentage.toStringAsFixed(1)}%). Consider cleaning old data.',
        priority: OptimizationPriority.critical,
        potentialSavings:
            (analytics.totalUsedStorage * 0.3).round(), // Estimate 30% savings
        effort: OptimizationEffort.low,
      ));
    } else if (analytics.storageUsagePercentage > 60) {
      recommendations.add(StorageOptimizationRecommendation(
        type: StorageOptimizationType.cleanupCache,
        title: 'High Storage Usage',
        description:
            'Storage usage is high (${analytics.storageUsagePercentage.toStringAsFixed(1)}%). Consider cleaning cache and temporary files.',
        priority: OptimizationPriority.high,
        potentialSavings: (analytics.cacheSize + analytics.tempSize).round(),
        effort: OptimizationEffort.minimal,
      ));
    }

    // Large cache recommendation
    if (analytics.cacheSize > 100 * 1024 * 1024) {
      // 100MB
      recommendations.add(StorageOptimizationRecommendation(
        type: StorageOptimizationType.cleanupCache,
        title: 'Large Cache Size',
        description:
            'Cache size is large (${_formatBytes(analytics.cacheSize)}). Cleaning cache can free up space.',
        priority: OptimizationPriority.medium,
        potentialSavings: analytics.cacheSize,
        effort: OptimizationEffort.minimal,
      ));
    }

    // Database optimization recommendation
    if (analytics.databaseSize > 50 * 1024 * 1024) {
      // 50MB
      recommendations.add(StorageOptimizationRecommendation(
        type: StorageOptimizationType.optimizeDatabase,
        title: 'Database Optimization',
        description:
            'Database size is large (${_formatBytes(analytics.databaseSize)}). Optimization can improve performance.',
        priority: OptimizationPriority.medium,
        potentialSavings:
            (analytics.databaseSize * 0.2).round(), // Estimate 20% savings
        effort: OptimizationEffort.low,
      ));
    }

    // Old photos recommendation
    if (analytics.photoStorageSize > 500 * 1024 * 1024) {
      // 500MB
      recommendations.add(StorageOptimizationRecommendation(
        type: StorageOptimizationType.compressPhotos,
        title: 'Photo Storage Optimization',
        description:
            'Photo storage is large (${_formatBytes(analytics.photoStorageSize)}). Consider compressing or removing old photos.',
        priority: OptimizationPriority.low,
        potentialSavings:
            (analytics.photoStorageSize * 0.4).round(), // Estimate 40% savings
        effort: OptimizationEffort.medium,
      ));
    }

    return recommendations;
  }

  /// Clean specific storage type
  Future<int> cleanStorageType(StorageCleanupType type) async {
    switch (type) {
      case StorageCleanupType.temporaryFiles:
        return _cleanTemporaryFiles();
      case StorageCleanupType.cacheFiles:
        return _cleanCacheFiles();
      case StorageCleanupType.oldPhotos:
        return _cleanOldPhotos();
      case StorageCleanupType.oldSessions:
        return _cleanOldSessions();
      case StorageCleanupType.databaseOptimization:
        return _optimizeDatabase();
      case StorageCleanupType.logFiles:
        return _cleanLogFiles();
      case StorageCleanupType.comprehensive:
        final result = await performComprehensiveCleanup();
        return result.bytesFreed;
    }
  }

  Future<void> _initializeStoragePaths() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();

      _appDocumentsPath = documentsDir.path;
      _tempPath = tempDir.path;

      // Try to get cache directory (may not be available on all platforms)
      try {
        final cacheDir = await getApplicationCacheDirectory();
        _cachePath = cacheDir.path;
      } catch (e) {
        debugPrint('🧹 Cache directory not available: $e');
        _cachePath = tempDir.path; // Fallback to temp directory
      }
    } catch (e) {
      debugPrint('🧹 Error initializing storage paths: $e');
    }
  }

  Future<int> _cleanTemporaryFiles() async {
    if (_tempPath == null) return 0;

    int bytesFreed = 0;
    try {
      final tempDir = Directory(_tempPath!);
      if (!tempDir.existsSync()) return 0;

      final entities = await tempDir.list(recursive: true).toList();
      for (final entity in entities) {
        if (entity is File) {
          try {
            final stat = entity.statSync();
            await entity.delete();
            bytesFreed += stat.size;
          } catch (e) {
            debugPrint('🧹 Error deleting temp file ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('🧹 Error cleaning temporary files: $e');
    }

    return bytesFreed;
  }

  Future<int> _cleanCacheFiles() async {
    int bytesFreed = 0;

    try {
      // OSM tile cache removed - no longer needed with Mapbox
      const tileCacheCleaned = 0;
      const tileCacheSizeCleaned = 0;

      // Estimate bytes freed (rough calculation)
      bytesFreed += (tileCacheCleaned + tileCacheSizeCleaned) *
          1024; // Assume 1KB per tile
    } catch (e) {
      debugPrint('🧹 Error cleaning tile cache: $e');
    }

    // Clean other cache files
    if (_cachePath != null) {
      try {
        final cacheDir = Directory(_cachePath!);
        if (cacheDir.existsSync()) {
          final entities = await cacheDir.list(recursive: true).toList();
          for (final entity in entities) {
            if (entity is File && entity.path.contains('cache')) {
              try {
                final stat = entity.statSync();
                await entity.delete();
                bytesFreed += stat.size;
              } catch (e) {
                debugPrint('🧹 Error deleting cache file ${entity.path}: $e');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('🧹 Error cleaning cache files: $e');
      }
    }

    return bytesFreed;
  }

  Future<int> _cleanOldPhotos() async {
    if (!_config.cleanOldPhotosEnabled) return 0;

    const int bytesFreed = 0;
    try {
      final cutoffDate = DateTime.now().subtract(_config.photoRetentionPeriod);

      // This would integrate with the photo storage service to clean old photos
      // For now, return 0 as we don't want to accidentally delete user photos
      debugPrint(
          '🧹 Old photo cleanup would remove photos older than $cutoffDate');

      // In a real implementation, this would:
      // 1. Query database for photos older than cutoff date
      // 2. Check if photos are still referenced
      // 3. Delete unreferenced old photos
      // 4. Update database
    } catch (e) {
      debugPrint('🧹 Error cleaning old photos: $e');
    }

    return bytesFreed;
  }

  Future<int> _cleanOldSessions() async {
    if (!_config.cleanOldSessionsEnabled) return 0;

    const int bytesFreed = 0;
    try {
      final cutoffDate =
          DateTime.now().subtract(_config.sessionRetentionPeriod);

      // This would integrate with the database service to clean old sessions
      debugPrint(
          '🧹 Old session cleanup would remove sessions older than $cutoffDate');

      // In a real implementation, this would:
      // 1. Query database for sessions older than cutoff date
      // 2. Delete associated breadcrumbs, waypoints, and photos
      // 3. Clean up related files
      // 4. Update statistics
    } catch (e) {
      debugPrint('🧹 Error cleaning old sessions: $e');
    }

    return bytesFreed;
  }

  Future<int> _optimizeDatabase() async {
    if (!_config.optimizeDatabaseEnabled) return 0;

    int bytesFreed = 0;
    try {
      // Get database size before optimization
      final dbPath = await _databaseService.getDatabasePath();
      final dbFile = File(dbPath);
      final sizeBefore = await dbFile.length();

      // Perform database optimization
      await _databaseService.cleanupOldStatistics();
      // Add more database optimization operations here

      // Calculate bytes freed
      final sizeAfter = await dbFile.length();
      bytesFreed = sizeBefore - sizeAfter;

      debugPrint('🧹 Database optimized: ${_formatBytes(bytesFreed)} freed');
    } catch (e) {
      debugPrint('🧹 Error optimizing database: $e');
    }

    return bytesFreed;
  }

  Future<int> _cleanLogFiles() async {
    int bytesFreed = 0;

    if (_appDocumentsPath == null) return 0;

    try {
      final logPatterns = ['*.log', '*.txt', 'crash_reports', 'error_logs'];

      for (final pattern in logPatterns) {
        final logDir = Directory('$_appDocumentsPath/$pattern');
        if (logDir.existsSync()) {
          final entities = await logDir.list(recursive: true).toList();
          for (final entity in entities) {
            if (entity is File) {
              try {
                final stat = entity.statSync();
                final age = DateTime.now().difference(stat.modified);

                // Delete log files older than 30 days
                if (age.inDays > 30) {
                  await entity.delete();
                  bytesFreed += stat.size;
                }
              } catch (e) {
                debugPrint('🧹 Error deleting log file ${entity.path}: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('🧹 Error cleaning log files: $e');
    }

    return bytesFreed;
  }

  Future<void> _monitorStorageUsage() async {
    try {
      final analytics = await _generateStorageAnalytics();

      // Store usage history
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      _storageUsageHistory[timestamp] = analytics.totalUsedStorage;

      // Keep only recent history (last 30 days)
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 30))
          .millisecondsSinceEpoch;
      _storageUsageHistory.removeWhere((key, value) => int.parse(key) < cutoff);

      // Emit analytics
      _analyticsController?.add(analytics);

      // Check for storage warnings
      if (analytics.storageUsagePercentage > 90) {
        final event = StorageCleanupEvent(
          type: StorageCleanupEventType.storageWarning,
          description:
              'Storage usage critical: ${analytics.storageUsagePercentage.toStringAsFixed(1)}%',
          bytesFreed: 0,
          timestamp: DateTime.now(),
        );
        _cleanupEventController?.add(event);
      } else if (analytics.storageUsagePercentage > 75) {
        final event = StorageCleanupEvent(
          type: StorageCleanupEventType.storageWarning,
          description:
              'Storage usage high: ${analytics.storageUsagePercentage.toStringAsFixed(1)}%',
          bytesFreed: 0,
          timestamp: DateTime.now(),
        );
        _cleanupEventController?.add(event);
      }
    } catch (e) {
      debugPrint('🧹 Error monitoring storage usage: $e');
    }
  }

  Future<StorageAnalytics> _generateStorageAnalytics() async {
    try {
      // Get total device storage (platform-specific implementation needed)
      final totalStorage = await _getTotalDeviceStorage();
      final freeStorage = await _getFreeDeviceStorage();
      final usedStorage = totalStorage - freeStorage;

      // Get app-specific storage usage
      final appStorageUsage = await _getAppStorageUsage();
      final cacheSize = await _getCacheSize();
      final tempSize = await _getTempSize();
      final databaseSize = await _getDatabaseSize();
      final photoStorageSize = await _getPhotoStorageSize();

      // Calculate storage breakdown
      final storageBreakdown = <String, int>{
        'photos': photoStorageSize,
        'database': databaseSize,
        'cache': cacheSize,
        'temporary': tempSize,
        'other': appStorageUsage -
            photoStorageSize -
            databaseSize -
            cacheSize -
            tempSize,
      };

      // Calculate usage percentage
      final usagePercentage = (usedStorage / totalStorage) * 100;

      // Determine storage health
      final storageHealth = _calculateStorageHealth(usagePercentage);

      // Get cleanup recommendations
      final recommendations = await getOptimizationRecommendations();

      return StorageAnalytics(
        totalDeviceStorage: totalStorage,
        totalUsedStorage: usedStorage,
        totalFreeStorage: freeStorage,
        appStorageUsage: appStorageUsage,
        storageUsagePercentage: usagePercentage,
        storageBreakdown: storageBreakdown,
        cacheSize: cacheSize,
        tempSize: tempSize,
        databaseSize: databaseSize,
        photoStorageSize: photoStorageSize,
        storageHealth: storageHealth,
        recommendations: recommendations,
        lastCleanup:
            _cleanupHistory.isNotEmpty ? _cleanupHistory.last.endTime : null,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('🧹 Error generating storage analytics: $e');

      // Return default analytics on error
      return StorageAnalytics(
        totalDeviceStorage: 0,
        totalUsedStorage: 0,
        totalFreeStorage: 0,
        appStorageUsage: 0,
        storageUsagePercentage: 0.0,
        storageBreakdown: {},
        cacheSize: 0,
        tempSize: 0,
        databaseSize: 0,
        photoStorageSize: 0,
        storageHealth: StorageHealth.unknown,
        recommendations: [],
        lastCleanup: null,
        generatedAt: DateTime.now(),
      );
    }
  }

  Future<int> _getTotalDeviceStorage() async =>
      // Platform-specific implementation needed
      // For now, return estimated value
      64 * 1024 * 1024 * 1024; // 64GB estimate

  Future<int> _getFreeDeviceStorage() async =>
      // Platform-specific implementation needed
      // For now, return estimated value
      32 * 1024 * 1024 * 1024; // 32GB estimate

  Future<int> _getAppStorageUsage() async {
    int totalSize = 0;

    if (_appDocumentsPath != null) {
      try {
        final appDir = Directory(_appDocumentsPath!);
        if (appDir.existsSync()) {
          totalSize += await _getDirectorySize(appDir);
        }
      } catch (e) {
        debugPrint('🧹 Error calculating app storage usage: $e');
      }
    }

    return totalSize;
  }

  Future<int> _getCacheSize() async {
    if (_cachePath == null) return 0;

    try {
      final cacheDir = Directory(_cachePath!);
      if (cacheDir.existsSync()) {
        return await _getDirectorySize(cacheDir);
      }
    } catch (e) {
      debugPrint('🧹 Error calculating cache size: $e');
    }

    return 0;
  }

  Future<int> _getTempSize() async {
    if (_tempPath == null) return 0;

    try {
      final tempDir = Directory(_tempPath!);
      if (tempDir.existsSync()) {
        return await _getDirectorySize(tempDir);
      }
    } catch (e) {
      debugPrint('🧹 Error calculating temp size: $e');
    }

    return 0;
  }

  Future<int> _getDatabaseSize() async {
    try {
      final dbPath = await _databaseService.getDatabasePath();
      final dbFile = File(dbPath);
      if (dbFile.existsSync()) {
        return await dbFile.length();
      }
    } catch (e) {
      debugPrint('🧹 Error calculating database size: $e');
    }

    return 0;
  }

  Future<int> _getPhotoStorageSize() async {
    try {
      final stats = await _photoStorageService.getTotalStorageStats();
      return stats['totalSize'] as int? ?? 0;
    } catch (e) {
      debugPrint('🧹 Error calculating photo storage size: $e');
    }

    return 0;
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
      debugPrint('🧹 Error calculating directory size: $e');
    }

    return totalSize;
  }

  StorageHealth _calculateStorageHealth(double usagePercentage) {
    if (usagePercentage >= 95) return StorageHealth.critical;
    if (usagePercentage >= 85) return StorageHealth.poor;
    if (usagePercentage >= 70) return StorageHealth.fair;
    if (usagePercentage >= 50) return StorageHealth.good;
    return StorageHealth.excellent;
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
    _cleanupHistory.clear();
    _storageUsageHistory.clear();
    _instance = null;
  }
}
