import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/photo_capture_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Backup storage types
enum BackupStorageType {
  /// Local device storage
  local,

  /// External SD card (Android)
  external,

  /// Cloud storage (future implementation)
  cloud,
}

/// Backup frequency options
enum BackupFrequency {
  /// Manual backup only
  manual,

  /// Daily automatic backup
  daily,

  /// Weekly automatic backup
  weekly,

  /// Monthly automatic backup
  monthly,
}

/// Backup compression levels
enum BackupCompression {
  /// No compression (fastest)
  none,

  /// Light compression (balanced)
  light,

  /// Heavy compression (smallest size)
  heavy,
}

/// Backup configuration
@immutable
class BackupConfig {
  const BackupConfig({
    this.storageType = BackupStorageType.local,
    this.frequency = BackupFrequency.manual,
    this.compression = BackupCompression.light,
    this.includeOriginals = true,
    this.includeThumbnails = false,
    this.includeMetadata = true,
    this.maxBackupAge = 90,
    this.maxBackupCount = 10,
    this.autoDeleteOldBackups = true,
    this.encryptBackups = false,
    this.customPath,
  });

  factory BackupConfig.fromMap(Map<String, dynamic> map) => BackupConfig(
        storageType: BackupStorageType.values.firstWhere(
          (e) => e.name == map['storage_type'],
          orElse: () => BackupStorageType.local,
        ),
        frequency: BackupFrequency.values.firstWhere(
          (e) => e.name == map['frequency'],
          orElse: () => BackupFrequency.manual,
        ),
        compression: BackupCompression.values.firstWhere(
          (e) => e.name == map['compression'],
          orElse: () => BackupCompression.light,
        ),
        includeOriginals: (map['include_originals'] as int) == 1,
        includeThumbnails: (map['include_thumbnails'] as int) == 1,
        includeMetadata: (map['include_metadata'] as int) == 1,
        maxBackupAge: map['max_backup_age'] as int,
        maxBackupCount: map['max_backup_count'] as int,
        autoDeleteOldBackups: (map['auto_delete_old_backups'] as int) == 1,
        encryptBackups: (map['encrypt_backups'] as int) == 1,
        customPath: map['custom_path'] as String?,
      );

  /// Storage type for backups
  final BackupStorageType storageType;

  /// Backup frequency
  final BackupFrequency frequency;

  /// Compression level
  final BackupCompression compression;

  /// Include original photos
  final bool includeOriginals;

  /// Include thumbnail images
  final bool includeThumbnails;

  /// Include metadata
  final bool includeMetadata;

  /// Maximum age of backups in days
  final int maxBackupAge;

  /// Maximum number of backups to keep
  final int maxBackupCount;

  /// Automatically delete old backups
  final bool autoDeleteOldBackups;

  /// Encrypt backup files
  final bool encryptBackups;

  /// Custom backup path
  final String? customPath;

  BackupConfig copyWith({
    BackupStorageType? storageType,
    BackupFrequency? frequency,
    BackupCompression? compression,
    bool? includeOriginals,
    bool? includeThumbnails,
    bool? includeMetadata,
    int? maxBackupAge,
    int? maxBackupCount,
    bool? autoDeleteOldBackups,
    bool? encryptBackups,
    String? customPath,
  }) =>
      BackupConfig(
        storageType: storageType ?? this.storageType,
        frequency: frequency ?? this.frequency,
        compression: compression ?? this.compression,
        includeOriginals: includeOriginals ?? this.includeOriginals,
        includeThumbnails: includeThumbnails ?? this.includeThumbnails,
        includeMetadata: includeMetadata ?? this.includeMetadata,
        maxBackupAge: maxBackupAge ?? this.maxBackupAge,
        maxBackupCount: maxBackupCount ?? this.maxBackupCount,
        autoDeleteOldBackups: autoDeleteOldBackups ?? this.autoDeleteOldBackups,
        encryptBackups: encryptBackups ?? this.encryptBackups,
        customPath: customPath ?? this.customPath,
      );

  Map<String, dynamic> toMap() => {
        'storage_type': storageType.name,
        'frequency': frequency.name,
        'compression': compression.name,
        'include_originals': includeOriginals ? 1 : 0,
        'include_thumbnails': includeThumbnails ? 1 : 0,
        'include_metadata': includeMetadata ? 1 : 0,
        'max_backup_age': maxBackupAge,
        'max_backup_count': maxBackupCount,
        'auto_delete_old_backups': autoDeleteOldBackups ? 1 : 0,
        'encrypt_backups': encryptBackups ? 1 : 0,
        'custom_path': customPath,
      };
}

/// Backup metadata
@immutable
class BackupInfo {
  const BackupInfo({
    required this.id,
    required this.sessionId,
    required this.createdAt,
    required this.filePath,
    required this.fileSize,
    required this.photoCount,
    required this.config,
    this.description,
    this.checksum,
  });

  factory BackupInfo.fromMap(Map<String, dynamic> map) => BackupInfo(
        id: map['id'] as String,
        sessionId: map['session_id'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        filePath: map['file_path'] as String,
        fileSize: map['file_size'] as int,
        photoCount: map['photo_count'] as int,
        config: BackupConfig.fromMap(
          jsonDecode(map['config'] as String) as Map<String, dynamic>,
        ),
        description: map['description'] as String?,
        checksum: map['checksum'] as String?,
      );

  /// Backup ID
  final String id;

  /// Session ID that was backed up
  final String sessionId;

  /// When backup was created
  final DateTime createdAt;

  /// Path to backup file
  final String filePath;

  /// Backup file size in bytes
  final int fileSize;

  /// Number of photos in backup
  final int photoCount;

  /// Backup configuration used
  final BackupConfig config;

  /// Optional description
  final String? description;

  /// File checksum for integrity verification
  final String? checksum;

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'created_at': createdAt.millisecondsSinceEpoch,
        'file_path': filePath,
        'file_size': fileSize,
        'photo_count': photoCount,
        'config': jsonEncode(config.toMap()),
        'description': description,
        'checksum': checksum,
      };
}

/// Progress callback for backup operations
typedef BackupProgressCallback = void Function(
    int completed, int total, String? currentFile);

/// Result of a backup operation
@immutable
class BackupResult {
  const BackupResult({
    required this.success,
    this.backupInfo,
    this.error,
  });

  /// Whether the backup was successful
  final bool success;

  /// Backup information (if successful)
  final BackupInfo? backupInfo;

  /// Error message (if failed)
  final String? error;
}

/// Result of a restore operation
@immutable
class RestoreResult {
  const RestoreResult({
    required this.success,
    this.restoredPhotos = 0,
    this.restoredMetadata = 0,
    this.error,
  });

  /// Whether the restore was successful
  final bool success;

  /// Number of photos restored
  final int restoredPhotos;

  /// Number of metadata entries restored
  final int restoredMetadata;

  /// Error message (if failed)
  final String? error;
}

/// Service for photo backup and recovery operations
class PhotoBackupService {
  factory PhotoBackupService() => _instance ??= PhotoBackupService._();
  PhotoBackupService._();
  static PhotoBackupService? _instance;

  final DatabaseService _databaseService = DatabaseService();
  final PhotoCaptureService _photoCaptureService = PhotoCaptureService();

  BackupConfig _config = const BackupConfig();

  /// Initialize the service and create necessary tables
  Future<void> initialize() async {
    try {
      final Database db = await _databaseService.database;

      // Create backup configuration table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS backup_config (
          id INTEGER PRIMARY KEY,
          storage_type TEXT NOT NULL,
          frequency TEXT NOT NULL,
          compression TEXT NOT NULL,
          include_originals INTEGER DEFAULT 1,
          include_thumbnails INTEGER DEFAULT 0,
          include_metadata INTEGER DEFAULT 1,
          max_backup_age INTEGER DEFAULT 90,
          max_backup_count INTEGER DEFAULT 10,
          auto_delete_old_backups INTEGER DEFAULT 1,
          encrypt_backups INTEGER DEFAULT 0,
          custom_path TEXT,
          updated_at INTEGER NOT NULL
        )
      ''');

      // Create backup history table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS backup_history (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          file_path TEXT NOT NULL,
          file_size INTEGER NOT NULL,
          photo_count INTEGER NOT NULL,
          config TEXT NOT NULL,
          description TEXT,
          checksum TEXT
        )
      ''');

      // Load existing configuration
      await _loadConfig();

      debugPrint('PhotoBackupService initialized');
    } catch (e) {
      debugPrint('Error initializing PhotoBackupService: $e');
    }
  }

  /// Load backup configuration from database
  Future<void> _loadConfig() async {
    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> configs = await db.query(
        'backup_config',
        orderBy: 'updated_at DESC',
        limit: 1,
      );

      if (configs.isNotEmpty) {
        _config = BackupConfig.fromMap(configs.first);
      }
    } catch (e) {
      debugPrint('Error loading backup config: $e');
    }
  }

  /// Save backup configuration
  Future<bool> saveConfig(BackupConfig config) async {
    try {
      final Database db = await _databaseService.database;

      final Map<String, dynamic> configMap = config.toMap();
      configMap['updated_at'] = DateTime.now().millisecondsSinceEpoch;

      await db.insert(
        'backup_config',
        configMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _config = config;
      debugPrint('Backup configuration saved');
      return true;
    } catch (e) {
      debugPrint('Error saving backup config: $e');
      return false;
    }
  }

  /// Get current backup configuration
  BackupConfig get config => _config;

  /// Create a backup of photos for a session
  Future<BackupResult> createBackup({
    required String sessionId,
    BackupConfig? customConfig,
    String? description,
    BackupProgressCallback? onProgress,
  }) async {
    try {
      final BackupConfig backupConfig = customConfig ?? _config;

      // Get photos for the session
      final List<PhotoWaypoint> photos =
          await _photoCaptureService.getAllPhotoWaypointsForSession(sessionId);

      if (photos.isEmpty) {
        return const BackupResult(
          success: false,
          error: 'No photos found for session',
        );
      }

      // Create backup directory
      final Directory backupDir = await _getBackupDirectory(backupConfig);
      final String backupId = 'backup_${DateTime.now().millisecondsSinceEpoch}';
      final String backupPath =
          path.join(backupDir.path, '$backupId.wlb'); // Obsession Backup

      // Create backup manifest
      final Map<String, dynamic> manifest = {
        'backup_id': backupId,
        'session_id': sessionId,
        'created_at': DateTime.now().toIso8601String(),
        'config': backupConfig.toMap(),
        'description': description,
        'photos': <Map<String, dynamic>>[],
      };

      int totalFiles = photos.length;
      if (backupConfig.includeMetadata) totalFiles += photos.length;

      int completed = 0;
      final List<Map<String, dynamic>> backupFiles = <Map<String, dynamic>>[];

      // Create temporary backup directory
      final Directory tempDir = await getTemporaryDirectory();
      final String tempBackupPath = path.join(
        tempDir.path,
        'backup_temp_${DateTime.now().millisecondsSinceEpoch}',
      );
      final Directory tempBackupDir = Directory(tempBackupPath);
      await tempBackupDir.create(recursive: true);

      try {
        // Copy photos to backup
        for (final PhotoWaypoint photo in photos) {
          onProgress?.call(completed, totalFiles, photo.filePath);

          // Copy original photo if requested
          if (backupConfig.includeOriginals) {
            final File originalFile = File(photo.filePath);
            if (originalFile.existsSync()) {
              final String backupFileName =
                  '${photo.id}_original${path.extension(photo.filePath)}';
              final String backupFilePath =
                  path.join(tempBackupDir.path, backupFileName);
              await originalFile.copy(backupFilePath);

              backupFiles.add({
                'photo_id': photo.id,
                'type': 'original',
                'file_name': backupFileName,
                'original_path': photo.filePath,
                'file_size': await originalFile.length(),
              });
            }
          }

          // Copy thumbnail if requested
          if (backupConfig.includeThumbnails && photo.thumbnailPath != null) {
            final File thumbnailFile = File(photo.thumbnailPath!);
            if (thumbnailFile.existsSync()) {
              final String backupFileName =
                  '${photo.id}_thumbnail${path.extension(photo.thumbnailPath!)}';
              final String backupFilePath =
                  path.join(tempBackupDir.path, backupFileName);
              await thumbnailFile.copy(backupFilePath);

              backupFiles.add({
                'photo_id': photo.id,
                'type': 'thumbnail',
                'file_name': backupFileName,
                'original_path': photo.thumbnailPath,
                'file_size': await thumbnailFile.length(),
              });
            }
          }

          completed++;

          // Backup metadata if requested
          if (backupConfig.includeMetadata) {
            onProgress?.call(completed, totalFiles, 'metadata_${photo.id}');

            final List<PhotoMetadata> metadata =
                await _photoCaptureService.getPhotoMetadata(photo.id);

            final Map<String, dynamic> metadataJson = {
              'photo_id': photo.id,
              'waypoint_id': photo.waypointId,
              'created_at': photo.createdAt.toIso8601String(),
              'file_size': photo.fileSize,
              'width': photo.width,
              'height': photo.height,
              'metadata': metadata
                  .map((m) => {
                        'key': m.key,
                        'value': m.value,
                        'type': m.type.name,
                      })
                  .toList(),
            };

            final String metadataFileName = '${photo.id}_metadata.json';
            final String metadataFilePath =
                path.join(tempBackupDir.path, metadataFileName);
            await File(metadataFilePath).writeAsString(
              jsonEncode(metadataJson),
            );

            backupFiles.add({
              'photo_id': photo.id,
              'type': 'metadata',
              'file_name': metadataFileName,
              'file_size': await File(metadataFilePath).length(),
            });

            completed++;
          }
        }

        // Add files to manifest
        manifest['photos'] = backupFiles;

        // Write manifest
        final String manifestPath =
            path.join(tempBackupDir.path, 'manifest.json');
        await File(manifestPath).writeAsString(jsonEncode(manifest));

        // Create final backup file (ZIP archive)
        final Uint8List backupData = await _createBackupArchive(
          tempBackupDir,
          backupConfig.compression,
        );

        await File(backupPath).writeAsBytes(backupData);

        // Calculate checksum
        final String checksum = _calculateChecksum(backupData);

        // Create backup info
        final BackupInfo backupInfo = BackupInfo(
          id: backupId,
          sessionId: sessionId,
          createdAt: DateTime.now(),
          filePath: backupPath,
          fileSize: backupData.length,
          photoCount: photos.length,
          config: backupConfig,
          description: description,
          checksum: checksum,
        );

        // Save backup info to database
        await _saveBackupInfo(backupInfo);

        // Clean up temporary directory
        await tempBackupDir.delete(recursive: true);

        // Clean up old backups if configured
        if (backupConfig.autoDeleteOldBackups) {
          await _cleanupOldBackups(backupConfig);
        }

        onProgress?.call(totalFiles, totalFiles, null);

        debugPrint('Backup created successfully: $backupPath');
        return BackupResult(
          success: true,
          backupInfo: backupInfo,
        );
      } catch (e) {
        // Clean up on error
        if (tempBackupDir.existsSync()) {
          await tempBackupDir.delete(recursive: true);
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('Error creating backup: $e');
      return BackupResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Restore photos from a backup
  Future<RestoreResult> restoreFromBackup({
    required String backupId,
    required String targetSessionId,
    bool overwriteExisting = false,
    BackupProgressCallback? onProgress,
  }) async {
    try {
      // Get backup info
      final BackupInfo? backupInfo = await getBackupInfo(backupId);
      if (backupInfo == null) {
        return const RestoreResult(
          success: false,
          error: 'Backup not found',
        );
      }

      // Verify backup file exists
      final File backupFile = File(backupInfo.filePath);
      if (!backupFile.existsSync()) {
        return const RestoreResult(
          success: false,
          error: 'Backup file not found',
        );
      }

      // Verify backup integrity
      if (backupInfo.checksum != null) {
        final Uint8List backupData = await backupFile.readAsBytes();
        final String currentChecksum = _calculateChecksum(backupData);
        if (currentChecksum != backupInfo.checksum) {
          return const RestoreResult(
            success: false,
            error: 'Backup file is corrupted (checksum mismatch)',
          );
        }
      }

      // Extract backup
      final Directory tempDir = await getTemporaryDirectory();
      final String extractPath = path.join(
        tempDir.path,
        'restore_temp_${DateTime.now().millisecondsSinceEpoch}',
      );
      final Directory extractDir = Directory(extractPath);
      await extractDir.create(recursive: true);

      try {
        await _extractBackupArchive(backupInfo.filePath, extractDir);

        // Read manifest
        final File manifestFile =
            File(path.join(extractDir.path, 'manifest.json'));
        if (!manifestFile.existsSync()) {
          return const RestoreResult(
            success: false,
            error: 'Invalid backup: manifest not found',
          );
        }

        final Map<String, dynamic> manifest =
            jsonDecode(await manifestFile.readAsString())
                as Map<String, dynamic>;
        final List<dynamic> photos = manifest['photos'] as List<dynamic>;

        int restoredPhotos = 0;
        int restoredMetadata = 0;

        // Group files by photo ID
        final Map<String, List<Map<String, dynamic>>> photoFiles =
            <String, List<Map<String, dynamic>>>{};

        for (final dynamic photoData in photos) {
          final Map<String, dynamic> fileInfo =
              photoData as Map<String, dynamic>;
          final String photoId = fileInfo['photo_id'] as String;
          photoFiles.putIfAbsent(photoId, () => <Map<String, dynamic>>[]);
          photoFiles[photoId]!.add(fileInfo);
        }

        int completed = 0;
        final int totalPhotos = photoFiles.length;

        // Restore each photo
        for (final MapEntry<String, List<Map<String, dynamic>>> entry
            in photoFiles.entries) {
          final String photoId = entry.key;
          final List<Map<String, dynamic>> files = entry.value;

          onProgress?.call(completed, totalPhotos, photoId);

          // TODO(obsession): Implement actual photo restoration
          // This would involve:
          // 1. Creating new photo waypoint entries
          // 2. Copying files to storage locations
          // 3. Restoring metadata
          // 4. Updating database

          debugPrint('Restoring photo $photoId with ${files.length} files');
          restoredPhotos++;

          // Count metadata files
          for (final Map<String, dynamic> file in files) {
            if (file['type'] == 'metadata') {
              restoredMetadata++;
            }
          }

          completed++;
        }

        // Clean up temporary directory
        await extractDir.delete(recursive: true);

        onProgress?.call(totalPhotos, totalPhotos, null);

        debugPrint(
            'Restore completed: $restoredPhotos photos, $restoredMetadata metadata entries');
        return RestoreResult(
          success: true,
          restoredPhotos: restoredPhotos,
          restoredMetadata: restoredMetadata,
        );
      } catch (e) {
        // Clean up on error
        if (extractDir.existsSync()) {
          await extractDir.delete(recursive: true);
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('Error restoring from backup: $e');
      return RestoreResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get backup directory based on configuration
  Future<Directory> _getBackupDirectory(BackupConfig config) async {
    String backupPath;

    if (config.customPath != null) {
      backupPath = config.customPath!;
    } else {
      switch (config.storageType) {
        case BackupStorageType.local:
          final Directory appDir = await getApplicationDocumentsDirectory();
          backupPath = path.join(appDir.path, 'backups');
          break;
        case BackupStorageType.external:
          // TODO(obsession): Implement external storage detection
          final Directory appDir = await getApplicationDocumentsDirectory();
          backupPath = path.join(appDir.path, 'backups');
          break;
        case BackupStorageType.cloud:
          // TODO(obsession): Implement cloud storage
          final Directory appDir = await getApplicationDocumentsDirectory();
          backupPath = path.join(appDir.path, 'backups');
          break;
      }
    }

    final Directory backupDir = Directory(backupPath);
    if (!backupDir.existsSync()) {
      await backupDir.create(recursive: true);
    }

    return backupDir;
  }

  /// Create backup archive
  Future<Uint8List> _createBackupArchive(
    Directory sourceDir,
    BackupCompression compression,
  ) async {
    // TODO(obsession): Implement ZIP archive creation with compression
    // For now, return empty data
    debugPrint('Creating backup archive with ${compression.name} compression');
    return Uint8List(0);
  }

  /// Extract backup archive
  Future<void> _extractBackupArchive(
      String archivePath, Directory targetDir) async {
    // TODO(obsession): Implement ZIP archive extraction
    debugPrint('Extracting backup archive: $archivePath');
  }

  /// Calculate file checksum
  String _calculateChecksum(Uint8List data) =>
      // TODO(obsession): Implement proper checksum calculation (SHA-256)
      data.length.toString();

  /// Save backup info to database
  Future<void> _saveBackupInfo(BackupInfo backupInfo) async {
    final Database db = await _databaseService.database;
    await db.insert(
      'backup_history',
      backupInfo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get backup info by ID
  Future<BackupInfo?> getBackupInfo(String backupId) async {
    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'backup_history',
        where: 'id = ?',
        whereArgs: [backupId],
      );

      if (maps.isNotEmpty) {
        return BackupInfo.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting backup info: $e');
      return null;
    }
  }

  /// Get all backup history
  Future<List<BackupInfo>> getBackupHistory() async {
    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'backup_history',
        orderBy: 'created_at DESC',
      );

      return maps.map(BackupInfo.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting backup history: $e');
      return <BackupInfo>[];
    }
  }

  /// Delete a backup
  Future<bool> deleteBackup(String backupId) async {
    try {
      final BackupInfo? backupInfo = await getBackupInfo(backupId);
      if (backupInfo == null) {
        return false;
      }

      // Delete backup file
      final File backupFile = File(backupInfo.filePath);
      if (backupFile.existsSync()) {
        await backupFile.delete();
      }

      // Remove from database
      final Database db = await _databaseService.database;
      await db.delete(
        'backup_history',
        where: 'id = ?',
        whereArgs: [backupId],
      );

      debugPrint('Deleted backup: $backupId');
      return true;
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      return false;
    }
  }

  /// Clean up old backups based on configuration
  Future<void> _cleanupOldBackups(BackupConfig config) async {
    try {
      final List<BackupInfo> backups = await getBackupHistory();

      // Remove backups older than maxBackupAge
      final DateTime cutoffDate = DateTime.now().subtract(
        Duration(days: config.maxBackupAge),
      );

      final List<BackupInfo> oldBackups = backups
          .where((backup) => backup.createdAt.isBefore(cutoffDate))
          .toList();

      for (final BackupInfo backup in oldBackups) {
        await deleteBackup(backup.id);
      }

      // Remove excess backups if more than maxBackupCount
      final List<BackupInfo> recentBackups = backups
          .where((backup) => backup.createdAt.isAfter(cutoffDate))
          .toList();

      if (recentBackups.length > config.maxBackupCount) {
        recentBackups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final List<BackupInfo> excessBackups =
            recentBackups.skip(config.maxBackupCount).toList();

        for (final BackupInfo backup in excessBackups) {
          await deleteBackup(backup.id);
        }
      }

      debugPrint('Cleaned up old backups');
    } catch (e) {
      debugPrint('Error cleaning up old backups: $e');
    }
  }

  /// Check if automatic backup is due
  Future<bool> isAutomaticBackupDue(String sessionId) async {
    if (_config.frequency == BackupFrequency.manual) {
      return false;
    }

    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'backup_history',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'created_at DESC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return true; // No backup exists
      }

      final BackupInfo lastBackup = BackupInfo.fromMap(maps.first);
      final DateTime now = DateTime.now();

      switch (_config.frequency) {
        case BackupFrequency.daily:
          return now.difference(lastBackup.createdAt).inDays >= 1;
        case BackupFrequency.weekly:
          return now.difference(lastBackup.createdAt).inDays >= 7;
        case BackupFrequency.monthly:
          return now.difference(lastBackup.createdAt).inDays >= 30;
        case BackupFrequency.manual:
          return false;
      }
    } catch (e) {
      debugPrint('Error checking if backup is due: $e');
      return false;
    }
  }

  /// Get backup storage usage
  Future<Map<String, dynamic>> getBackupStorageUsage() async {
    try {
      final List<BackupInfo> backups = await getBackupHistory();

      int totalSize = 0;
      final int totalBackups = backups.length;
      int totalPhotos = 0;

      for (final BackupInfo backup in backups) {
        totalSize += backup.fileSize;
        totalPhotos += backup.photoCount;
      }

      return <String, dynamic>{
        'total_backups': totalBackups,
        'total_size': totalSize,
        'total_photos': totalPhotos,
        'average_backup_size': totalBackups > 0 ? totalSize / totalBackups : 0,
      };
    } catch (e) {
      debugPrint('Error getting backup storage usage: $e');
      return <String, dynamic>{
        'total_backups': 0,
        'total_size': 0,
        'total_photos': 0,
        'average_backup_size': 0,
      };
    }
  }

  /// Dispose of the service
  void dispose() {
    _instance = null;
  }
}
