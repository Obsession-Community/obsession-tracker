import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/custom_marker.dart';
import 'package:obsession_tracker/core/models/imported_route.dart';
import 'package:obsession_tracker/core/models/marker_attachment.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/models/session_statistics.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/treasure_hunt.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/achievement_service.dart';
import 'package:obsession_tracker/core/services/app_settings_service.dart';
import 'package:obsession_tracker/core/services/custom_marker_service.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/hunt_service.dart';
import 'package:obsession_tracker/core/services/lifetime_statistics_service.dart';
import 'package:obsession_tracker/core/services/marker_attachment_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Progress callback for backup/restore operations
///
/// [phase] - Current operation phase (e.g., 'Exporting hunts', 'Encrypting')
/// [progress] - Progress percentage (0.0 to 1.0) within the current phase
/// [detail] - Optional detail message (e.g., 'Session 3 of 10')
typedef BackupProgressCallback = void Function(String phase, double progress, String? detail);

/// Backup format version - increment when making breaking changes
///
/// ## Version History
/// - 1: Initial version with hunts, sessions, routes, settings
/// - 2: Added custom markers and marker attachments for sessions
///
/// ## Backup File Format (.obk)
///
/// The .obk format is an AES-256-GCM encrypted ZIP archive containing:
///
/// ```
/// backup.obk/
/// ├── manifest.json          # Version, timestamp, stats, data types
/// ├── hunts/
/// │   ├── hunts.json         # Hunt metadata
/// │   ├── documents.json     # Hunt documents
/// │   ├── locations.json     # Hunt locations
/// │   ├── session_links.json # Hunt-session associations
/// │   ├── covers/            # Hunt cover images
/// │   ├── files/             # Document files (images, PDFs, etc.)
/// │   └── thumbnails/        # Document thumbnails
/// ├── sessions/
/// │   ├── sessions.json      # Session metadata
/// │   └── {session_id}/      # Per-session data
/// │       ├── breadcrumbs.json
/// │       ├── waypoints.json
/// │       ├── custom_markers.json   # Custom markers (includes migrated photos)
/// │       ├── marker_attachments.json # Attachments for custom markers
/// │       └── attachments/          # Marker attachment files
/// │           ├── image/
/// │           ├── audio/
/// │           ├── pdf/
/// │           ├── document/
/// │           └── thumbnails/
/// ├── routes/
/// │   └── routes.json        # Imported routes with points/waypoints
/// └── settings.json          # App settings
/// ```
///
/// ## Adding Support for New Features
///
/// When adding a new feature that stores data:
/// 1. Add export method in _exportXXX()
/// 2. Add import method in _importXXX()
/// 3. Add to manifest dataTypes list
/// 4. Update kBackupFormatVersion if breaking changes
/// 5. Update this documentation
const int kBackupFormatVersion = 2;

/// Result of a backup operation
class BackupResult {
  const BackupResult({
    required this.success,
    this.filePath,
    this.error,
    this.stats,
  });

  final bool success;
  final String? filePath;
  final String? error;
  final BackupStats? stats;
}

/// Statistics about what was backed up
class BackupStats {
  const BackupStats({
    this.huntCount = 0,
    this.huntDocumentCount = 0,
    this.huntLocationCount = 0,
    this.sessionCount = 0,
    this.routeCount = 0,
    this.customMarkerCount = 0,
    this.markerAttachmentCount = 0,
    this.totalFileSize = 0,
    // Skipped counts (for merge mode)
    this.skippedHuntCount = 0,
    this.skippedSessionCount = 0,
    this.skippedRouteCount = 0,
  });

  final int huntCount;
  final int huntDocumentCount;
  final int huntLocationCount;
  final int sessionCount;
  final int routeCount;
  final int customMarkerCount;
  final int markerAttachmentCount;
  final int totalFileSize;
  // Skipped counts (items that already existed during merge)
  final int skippedHuntCount;
  final int skippedSessionCount;
  final int skippedRouteCount;

  /// Whether any items were skipped during merge
  bool get hasSkippedItems =>
      skippedHuntCount > 0 || skippedSessionCount > 0 || skippedRouteCount > 0;

  /// Total items imported
  int get totalImported => huntCount + sessionCount + routeCount;

  /// Total items skipped
  int get totalSkipped =>
      skippedHuntCount + skippedSessionCount + skippedRouteCount;

  Map<String, dynamic> toJson() => {
    'huntCount': huntCount,
    'huntDocumentCount': huntDocumentCount,
    'huntLocationCount': huntLocationCount,
    'sessionCount': sessionCount,
    'routeCount': routeCount,
    'customMarkerCount': customMarkerCount,
    'markerAttachmentCount': markerAttachmentCount,
    'totalFileSize': totalFileSize,
    'skippedHuntCount': skippedHuntCount,
    'skippedSessionCount': skippedSessionCount,
    'skippedRouteCount': skippedRouteCount,
  };
}

/// Result of a restore operation
class RestoreResult {
  const RestoreResult({
    required this.success,
    this.error,
    this.stats,
    this.warnings = const [],
  });

  final bool success;
  final String? error;
  final BackupStats? stats;
  final List<String> warnings;
}

/// Options for restore operation
class RestoreOptions {
  const RestoreOptions({
    this.replaceExisting = false,
    this.importHunts = true,
    this.importSessions = true,
    this.importRoutes = true,
    this.importSettings = true,
  });

  /// If true, replace all existing data. If false, merge (skip duplicates).
  final bool replaceExisting;

  /// Whether to import hunt data
  final bool importHunts;

  /// Whether to import session data
  final bool importSessions;

  /// Whether to import route data
  final bool importRoutes;

  /// Whether to import settings
  final bool importSettings;
}

/// Options for creating a selective backup
///
/// When any of the ID lists is non-null, only those items are included.
/// A null list means "include all items of that type".
class SelectiveBackupOptions {
  const SelectiveBackupOptions({
    this.sessionIds,
    this.huntIds,
    this.routeIds,
    this.includeSettings = false,
  });

  /// Session IDs to include (null = all sessions)
  final List<String>? sessionIds;

  /// Hunt IDs to include (null = all hunts)
  final List<String>? huntIds;

  /// Route IDs to include (null = all routes)
  final List<String>? routeIds;

  /// Whether to include app settings (usually false for selective sync)
  final bool includeSettings;

  /// Whether this is a selective backup (any filter specified)
  bool get isSelective =>
      sessionIds != null || huntIds != null || routeIds != null;
}

/// Service for full app data backup and restore.
///
/// Creates a portable .obk (Obsession Backup) file containing:
/// - manifest.json: Version info, timestamps, data inventory
/// - hunts/: Hunt data and associated files
/// - sessions/: Session data (delegated to existing services)
/// - routes/: Route data
/// - settings.json: App settings
///
/// ## Adding Support for New Features
///
/// When you add a new feature that stores data:
///
/// 1. Add export logic in the appropriate _exportXXX method
/// 2. Add import logic in the appropriate _importXXX method
/// 3. Update the manifest dataTypes to include the new type
/// 4. Add stats tracking if relevant
/// 5. Update kBackupFormatVersion if format is incompatible
///
/// Example for a new "challenges" feature:
/// ```dart
/// // In _buildManifest:
/// 'dataTypes': ['hunts', 'sessions', 'routes', 'settings', 'challenges'],
///
/// // Add new export method:
/// Future<void> _exportChallenges(Archive archive) async { ... }
///
/// // Add new import method:
/// Future<void> _importChallenges(Archive archive) async { ... }
/// ```
class AppBackupService {
  factory AppBackupService() => _instance;
  AppBackupService._();
  static final AppBackupService _instance = AppBackupService._();

  final DatabaseService _db = DatabaseService();
  final HuntService _huntService = HuntService();

  // Encryption constants (same as SessionExportService for consistency)
  static const String _magicBytes = 'OBKV'; // Obsession Backup Version
  static const String _encryptionAlgorithm = 'AES-256-GCM';
  static const String _kdfAlgorithm = 'PBKDF2-SHA256';
  static const int _kdfIterations = 600000; // OWASP 2024 recommendation
  static const int _saltLength = 32; // 256 bits
  static const int _nonceLength = 16; // 128 bits for GCM
  static const int _headerSize = 256; // Fixed header size

  /// Create a full backup of all app data
  ///
  /// [password] - Required password to encrypt the backup (min 8 characters)
  /// [description] - Optional description stored in manifest
  /// [shareAfterCreate] - Whether to show share dialog after creation
  /// [onProgress] - Optional callback for progress updates
  /// [selectiveOptions] - Optional filtering to create selective backup
  Future<BackupResult> createBackup({
    required String password,
    String? description,
    bool shareAfterCreate = true,
    BackupProgressCallback? onProgress,
    SelectiveBackupOptions? selectiveOptions,
  }) async {
    try {
      debugPrint('AppBackupService: Starting full backup...');

      // Validate password
      if (password.length < 8) {
        return const BackupResult(
          success: false,
          error: 'Password must be at least 8 characters',
        );
      }

      final archive = Archive();
      final stats = _MutableBackupStats();

      // Export all data types first (before manifest so we have stats)
      onProgress?.call('Exporting hunts', 0.0, null);
      await _exportHunts(archive, stats, onProgress, selectiveOptions?.huntIds);

      onProgress?.call('Exporting sessions', 0.25, null);
      await _exportSessions(archive, stats, onProgress, selectiveOptions?.sessionIds);

      onProgress?.call('Exporting routes', 0.5, null);
      await _exportRoutes(archive, stats, onProgress, selectiveOptions?.routeIds);

      // Only export settings for full backups or when explicitly requested
      if (selectiveOptions == null || selectiveOptions.includeSettings) {
        onProgress?.call('Exporting settings', 0.6, null);
        await _exportSettings(archive);
      }

      // Build and add manifest LAST with final stats
      onProgress?.call('Building manifest', 0.65, null);
      final manifest = await _buildManifest(description: description);
      manifest['stats'] = stats.toStats().toJson();
      _addJsonToArchive(archive, 'manifest.json', manifest);

      // Encode to ZIP
      onProgress?.call('Compressing data', 0.7, null);
      final zipData = ZipEncoder().encode(archive);
      debugPrint('AppBackupService: Created ZIP archive: ${zipData.length} bytes');

      // Encrypt the ZIP data
      onProgress?.call('Encrypting backup', 0.8, null);
      final encryptedData = _encryptData(Uint8List.fromList(zipData), password);
      debugPrint('AppBackupService: Encrypted data: ${encryptedData.length} bytes');

      // Save to file
      onProgress?.call('Saving file', 0.95, null);
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = 'obsession_backup_$timestamp.obk';

      final tempDir = await getTemporaryDirectory();
      final filePath = path.join(tempDir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(encryptedData);

      stats.totalFileSize = encryptedData.length;

      debugPrint('AppBackupService: Backup created: $filePath (${_formatBytes(encryptedData.length)})');

      onProgress?.call('Complete', 1.0, null);

      // Optionally share the file
      if (shareAfterCreate) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(filePath)],
            subject: 'Obsession Tracker Backup',
          ),
        );
      }

      return BackupResult(
        success: true,
        filePath: filePath,
        stats: stats.toStats(),
      );
    } catch (e, stack) {
      debugPrint('AppBackupService: Backup failed: $e');
      debugPrint('$stack');
      return BackupResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Restore from a backup file
  ///
  /// [password] - Required password to decrypt the backup
  /// [onProgress] - Optional callback for progress updates
  Future<RestoreResult> restoreFromBackup(
    String backupPath, {
    required String password,
    RestoreOptions options = const RestoreOptions(),
    BackupProgressCallback? onProgress,
  }) async {
    try {
      debugPrint('AppBackupService: Starting restore from $backupPath...');

      onProgress?.call('Reading backup file', 0.0, null);

      final file = File(backupPath);
      if (!await file.exists()) {
        return const RestoreResult(
          success: false,
          error: 'Backup file not found',
        );
      }

      final encryptedBytes = await file.readAsBytes();

      // Decrypt the backup
      onProgress?.call('Decrypting backup', 0.1, null);
      final decryptedBytes = _decryptData(Uint8List.fromList(encryptedBytes), password);
      if (decryptedBytes == null) {
        return const RestoreResult(
          success: false,
          error: 'Invalid password or corrupted backup file',
        );
      }

      onProgress?.call('Extracting data', 0.15, null);
      final archive = ZipDecoder().decodeBytes(decryptedBytes);

      // Read and validate manifest
      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) {
        return const RestoreResult(
          success: false,
          error: 'Invalid backup: missing manifest',
        );
      }

      final manifest = json.decode(utf8.decode(manifestFile.content as List<int>))
          as Map<String, dynamic>;

      final version = manifest['version'] as int? ?? 0;
      if (version > kBackupFormatVersion) {
        return RestoreResult(
          success: false,
          error: 'Backup was created with a newer app version (v$version). '
                 'Please update the app to restore this backup.',
        );
      }

      final warnings = <String>[];
      final stats = _MutableBackupStats();

      // Clear existing data if replacing
      if (options.replaceExisting) {
        onProgress?.call('Clearing existing data', 0.2, null);
        debugPrint('AppBackupService: Clearing existing data...');
        await _clearAllData();
      }

      // Import data types
      if (options.importHunts) {
        onProgress?.call('Importing hunts', 0.3, null);
        await _importHunts(archive, stats, options, warnings, onProgress);
      }
      if (options.importSessions) {
        onProgress?.call('Importing sessions', 0.5, null);
        await _importSessions(archive, stats, options, warnings, onProgress);
      }
      if (options.importRoutes) {
        onProgress?.call('Importing routes', 0.85, null);
        await _importRoutes(archive, stats, options, warnings);
      }
      if (options.importSettings) {
        onProgress?.call('Importing settings', 0.95, null);
        await _importSettings(archive, warnings);
      }

      // Recalculate lifetime stats and check achievements after restore
      // Only recalculate if we actually imported new sessions
      if (options.importSessions && stats.sessionCount > 0) {
        onProgress?.call('Recalculating statistics', 0.97, null);
        final lifetimeStatsService = LifetimeStatisticsService();
        await lifetimeStatsService.recalculateFromAllSessions();
        debugPrint('AppBackupService: Lifetime stats recalculated');

        final achievementService = AchievementService();
        await achievementService.checkAllAchievements();
        debugPrint('AppBackupService: Achievements checked');
      } else if (options.importSessions) {
        debugPrint('AppBackupService: No new sessions imported, skipping stats recalculation');
      }

      onProgress?.call('Complete', 1.0, null);
      debugPrint('AppBackupService: Restore complete');

      return RestoreResult(
        success: true,
        stats: stats.toStats(),
        warnings: warnings,
      );
    } catch (e, stack) {
      debugPrint('AppBackupService: Restore failed: $e');
      debugPrint('$stack');
      return RestoreResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Validate a backup file without importing
  ///
  /// [password] - Required password to decrypt and validate
  /// Returns the manifest if valid, null if invalid or wrong password
  Future<Map<String, dynamic>?> validateBackup(
    String backupPath, {
    required String password,
  }) async {
    try {
      final file = File(backupPath);
      if (!await file.exists()) return null;

      final encryptedBytes = await file.readAsBytes();

      // Decrypt the backup
      final decryptedBytes = _decryptData(Uint8List.fromList(encryptedBytes), password);
      if (decryptedBytes == null) {
        debugPrint('AppBackupService: Decryption failed - wrong password or corrupted file');
        return null;
      }

      final archive = ZipDecoder().decodeBytes(decryptedBytes);

      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) return null;

      return json.decode(utf8.decode(manifestFile.content as List<int>))
          as Map<String, dynamic>;
    } catch (e) {
      debugPrint('AppBackupService: Validation failed: $e');
      return null;
    }
  }

  /// Check if a file is a valid encrypted backup (without decrypting)
  ///
  /// Returns true if the file has the correct magic bytes header
  Future<bool> isEncryptedBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (!await file.exists()) return false;

      final bytes = await file.openRead(0, 4).first;
      final magic = utf8.decode(bytes);
      return magic == _magicBytes;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // Private: Manifest
  // ============================================================

  Future<Map<String, dynamic>> _buildManifest({String? description}) async {
    return {
      'version': kBackupFormatVersion,
      'appVersion': '1.0.0', // TODO(dev): Get from package_info_plus
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'description': description,
      'platform': Platform.operatingSystem,
      'dataTypes': ['hunts', 'sessions', 'routes', 'settings', 'custom_markers'],
      'stats': <String, dynamic>{}, // Populated after export
    };
  }

  // ============================================================
  // Private: Export Methods
  // ============================================================

  Future<void> _exportHunts(
    Archive archive,
    _MutableBackupStats stats,
    BackupProgressCallback? onProgress,
    List<String>? filterIds,
  ) async {
    debugPrint('AppBackupService: Exporting hunts...');

    // Get all hunts, then filter if selective
    // filterIds == null means "include all" (full backup)
    // filterIds == [] means "include nothing" (selective with none selected)
    // filterIds == [id1, id2] means "include only these"
    var hunts = await _db.getAllTreasureHunts();
    if (filterIds != null) {
      if (filterIds.isEmpty) {
        hunts = [];
        debugPrint('AppBackupService: No hunts selected (selective sync)');
      } else {
        final filterSet = filterIds.toSet();
        hunts = hunts.where((h) => filterSet.contains(h.id)).toList();
        debugPrint('AppBackupService: Filtered to ${hunts.length} hunts (selective sync)');
      }
    }
    stats.huntCount = hunts.length;

    // Export hunt metadata
    final huntsData = hunts.map((h) => h.toDatabaseMap()).toList();
    _addJsonToArchive(archive, 'hunts/hunts.json', huntsData);

    // Export documents, locations, session links for each hunt
    final allDocuments = <Map<String, dynamic>>[];
    final allLocations = <Map<String, dynamic>>[];
    final allSessionLinks = <Map<String, dynamic>>[];

    for (final hunt in hunts) {
      // Documents
      final docs = await _db.getHuntDocuments(hunt.id);
      for (final doc in docs) {
        final docMap = doc.toDatabaseMap();

        // Copy associated files
        if (doc.filePath != null) {
          final file = File(doc.filePath!);
          if (await file.exists()) {
            final relativePath = 'hunts/files/${hunt.id}/${path.basename(doc.filePath!)}';
            final fileBytes = await file.readAsBytes();
            archive.addFile(ArchiveFile(relativePath, fileBytes.length, fileBytes));
            docMap['_exportedFilePath'] = relativePath;
          }
        }
        if (doc.thumbnailPath != null) {
          final thumb = File(doc.thumbnailPath!);
          if (await thumb.exists()) {
            final relativePath = 'hunts/thumbnails/${hunt.id}/${path.basename(doc.thumbnailPath!)}';
            final thumbBytes = await thumb.readAsBytes();
            archive.addFile(ArchiveFile(relativePath, thumbBytes.length, thumbBytes));
            docMap['_exportedThumbnailPath'] = relativePath;
          }
        }

        allDocuments.add(docMap);
        stats.huntDocumentCount++;
      }

      // Locations
      final locations = await _db.getHuntLocations(hunt.id);
      for (final loc in locations) {
        allLocations.add(loc.toDatabaseMap());
        stats.huntLocationCount++;
      }

      // Session links
      final links = await _db.getHuntSessionLinks(hunt.id);
      for (final link in links) {
        allSessionLinks.add(link.toDatabaseMap());
      }

      // Cover image
      if (hunt.coverImagePath != null) {
        final cover = File(hunt.coverImagePath!);
        if (await cover.exists()) {
          final relativePath = 'hunts/covers/${path.basename(hunt.coverImagePath!)}';
          final coverBytes = await cover.readAsBytes();
          archive.addFile(ArchiveFile(relativePath, coverBytes.length, coverBytes));
        }
      }
    }

    _addJsonToArchive(archive, 'hunts/documents.json', allDocuments);
    _addJsonToArchive(archive, 'hunts/locations.json', allLocations);
    _addJsonToArchive(archive, 'hunts/session_links.json', allSessionLinks);

    debugPrint('AppBackupService: Exported ${hunts.length} hunts');
  }

  Future<void> _exportSessions(
    Archive archive,
    _MutableBackupStats stats,
    BackupProgressCallback? onProgress,
    List<String>? filterIds,
  ) async {
    debugPrint('AppBackupService: Exporting sessions...');

    // Get all sessions from database, then filter if selective
    // filterIds == null means "include all" (full backup)
    // filterIds == [] means "include nothing" (selective with none selected)
    // filterIds == [id1, id2] means "include only these"
    var sessions = await _db.getAllSessions();
    if (filterIds != null) {
      if (filterIds.isEmpty) {
        sessions = [];
        debugPrint('AppBackupService: No sessions selected (selective sync)');
      } else {
        final filterSet = filterIds.toSet();
        sessions = sessions.where((s) => filterSet.contains(s.id)).toList();
        debugPrint('AppBackupService: Filtered to ${sessions.length} sessions (selective sync)');
      }
    }
    stats.sessionCount = sessions.length;

    // Export session metadata
    final sessionsData = sessions.map((TrackingSession s) => s.toMap()).toList();
    _addJsonToArchive(archive, 'sessions/sessions.json', sessionsData);

    // Export breadcrumbs, waypoints, and custom markers for each session
    // Note: Legacy photo_waypoints are now migrated to custom_markers + attachments,
    // so we only export the new format. Old backups can still be imported via legacy code.
    for (var i = 0; i < sessions.length; i++) {
      final session = sessions[i];
      onProgress?.call(
        'Exporting sessions',
        0.25 + (0.25 * i / sessions.length),
        'Session ${i + 1} of ${sessions.length}',
      );

      // Breadcrumbs
      final breadcrumbs = await _db.getBreadcrumbsForSession(session.id);
      if (breadcrumbs.isNotEmpty) {
        final bcData = breadcrumbs.map((Breadcrumb b) => b.toMap()).toList();
        _addJsonToArchive(archive, 'sessions/${session.id}/breadcrumbs.json', bcData);
      }

      // Waypoints
      final waypoints = await _db.getWaypointsForSession(session.id);
      if (waypoints.isNotEmpty) {
        final wpData = waypoints.map((Waypoint w) => w.toMap()).toList();
        _addJsonToArchive(archive, 'sessions/${session.id}/waypoints.json', wpData);
      }

      // Export custom markers for this session (includes migrated photo_waypoints)
      final markerService = CustomMarkerService();
      final attachmentService = MarkerAttachmentService();
      final customMarkers = await markerService.getMarkersForSession(session.id);

      if (customMarkers.isNotEmpty) {
        final markersData = <Map<String, dynamic>>[];
        final attachmentsData = <Map<String, dynamic>>[];

        for (final marker in customMarkers) {
          final markerMap = marker.toDatabaseMap();
          markersData.add(markerMap);
          stats.customMarkerCount++;

          // Get attachments for this marker
          final attachments = await attachmentService.getAttachmentsForMarker(marker.id);

          for (final attachment in attachments) {
            final attachmentMap = attachment.toDatabaseMap();

            // Copy attachment file to archive if it exists
            if (attachment.filePath != null && attachment.type.hasFile) {
              final file = File(attachment.filePath!);
              if (await file.exists()) {
                final typeDir = attachment.type.name; // image, audio, pdf, document
                final fileName = path.basename(attachment.filePath!);
                final archivePath = 'sessions/${session.id}/attachments/$typeDir/$fileName';
                final fileBytes = await file.readAsBytes();
                archive.addFile(ArchiveFile(archivePath, fileBytes.length, fileBytes));
                attachmentMap['_exportedFilePath'] = archivePath;
              }
            }

            // Copy thumbnail if exists
            if (attachment.thumbnailPath != null) {
              final thumbFile = File(attachment.thumbnailPath!);
              if (await thumbFile.exists()) {
                final thumbName = path.basename(attachment.thumbnailPath!);
                final archivePath = 'sessions/${session.id}/attachments/thumbnails/$thumbName';
                final thumbBytes = await thumbFile.readAsBytes();
                archive.addFile(ArchiveFile(archivePath, thumbBytes.length, thumbBytes));
                attachmentMap['_exportedThumbnailPath'] = archivePath;
              }
            }

            attachmentsData.add(attachmentMap);
            stats.markerAttachmentCount++;
          }
        }

        _addJsonToArchive(archive, 'sessions/${session.id}/custom_markers.json', markersData);
        if (attachmentsData.isNotEmpty) {
          _addJsonToArchive(archive, 'sessions/${session.id}/marker_attachments.json', attachmentsData);
        }
        debugPrint('AppBackupService: Exported ${customMarkers.length} custom markers with ${attachmentsData.length} attachments for session ${session.id}');
      }

      // Export session statistics
      final sessionStats = await _db.getSessionStatistics(session.id);
      if (sessionStats.isNotEmpty) {
        final statsData = sessionStats.map((s) => s.toMap()).toList();
        _addJsonToArchive(archive, 'sessions/${session.id}/statistics.json', statsData);
        debugPrint('AppBackupService: Exported ${sessionStats.length} statistics records for session ${session.id}');
      }
    }

    debugPrint('AppBackupService: Exported ${sessions.length} sessions');
  }

  Future<void> _exportRoutes(
    Archive archive,
    _MutableBackupStats stats,
    BackupProgressCallback? onProgress,
    List<String>? filterIds,
  ) async {
    debugPrint('AppBackupService: Exporting routes...');

    // Export imported routes (from GPX/KML files), filter if selective
    // filterIds == null means "include all" (full backup)
    // filterIds == [] means "include nothing" (selective with none selected)
    // filterIds == [id1, id2] means "include only these"
    var importedRoutes = await _db.getImportedRoutes();
    if (filterIds != null) {
      if (filterIds.isEmpty) {
        importedRoutes = [];
        debugPrint('AppBackupService: No routes selected (selective sync)');
      } else {
        final filterSet = filterIds.toSet();
        importedRoutes = importedRoutes.where((r) => filterSet.contains(r.id)).toList();
        debugPrint('AppBackupService: Filtered to ${importedRoutes.length} routes (selective sync)');
      }
    }
    final importedRoutesData = <Map<String, dynamic>>[];
    for (final route in importedRoutes) {
      // Load points and waypoints separately (they're not loaded by default)
      final points = await _db.getRoutePoints(route.id);
      final waypoints = await _db.getRouteWaypoints(route.id);

      // Create full route with all data
      final fullRoute = route.copyWith(
        points: points,
        waypoints: waypoints,
      );
      importedRoutesData.add(fullRoute.toJson());
    }
    _addJsonToArchive(archive, 'routes/imported_routes.json', importedRoutesData);
    debugPrint('AppBackupService: Exported ${importedRoutes.length} imported routes');

    // Export planned routes (created in-app) - only for full backups
    // Selective sync only includes imported routes from the manifest
    var plannedCount = 0;
    if (filterIds == null) {
      final plannedRoutes = await _db.getPlannedRoutes();
      _addJsonToArchive(archive, 'routes/planned_routes.json', plannedRoutes);
      plannedCount = plannedRoutes.length;
      debugPrint('AppBackupService: Exported $plannedCount planned routes');
    }

    stats.routeCount = importedRoutes.length + plannedCount;
    debugPrint('AppBackupService: Exported ${stats.routeCount} total routes');
  }

  Future<void> _exportSettings(Archive archive) async {
    debugPrint('AppBackupService: Exporting settings...');

    // Read app settings from storage (app_settings.json is the actual filename)
    final docsDir = await getApplicationDocumentsDirectory();
    final settingsFile = File(path.join(docsDir.path, 'app_settings.json'));

    if (settingsFile.existsSync()) {
      final settingsJson = await settingsFile.readAsString();
      final settingsBytes = utf8.encode(settingsJson);
      archive.addFile(ArchiveFile('app_settings.json', settingsBytes.length, settingsBytes));
      debugPrint('AppBackupService: Settings file found and exported');
    } else {
      // No settings file exists yet (user hasn't changed from defaults)
      // Export the default settings so backup always has settings
      debugPrint('AppBackupService: No settings file found, exporting defaults');
      final settingsService = AppSettingsService();
      await settingsService.initialize();
      final defaultSettingsJson = jsonEncode(settingsService.currentSettings.toJson());
      final settingsBytes = utf8.encode(defaultSettingsJson);
      archive.addFile(ArchiveFile('app_settings.json', settingsBytes.length, settingsBytes));
      debugPrint('AppBackupService: Default settings exported');
    }

    debugPrint('AppBackupService: Settings exported');
  }

  // ============================================================
  // Private: Import Methods
  // ============================================================

  Future<void> _importHunts(
    Archive archive,
    _MutableBackupStats stats,
    RestoreOptions options,
    List<String> warnings,
    BackupProgressCallback? onProgress,
  ) async {
    debugPrint('AppBackupService: Importing hunts...');

    // Read hunt data
    final huntsFile = archive.findFile('hunts/hunts.json');
    if (huntsFile == null) {
      warnings.add('No hunt data found in backup');
      return;
    }

    final huntsData = json.decode(utf8.decode(huntsFile.content as List<int>)) as List;
    final docsDir = await getApplicationDocumentsDirectory();
    final huntsBaseDir = Directory(path.join(docsDir.path, 'hunts'));

    for (final huntMap in huntsData) {
      try {
        // Check if hunt already exists
        final existingHunt = await _db.getTreasureHunt(huntMap['id'] as String);
        if (existingHunt != null && !options.replaceExisting) {
          stats.skippedHuntCount++;
          continue;
        }

        // Restore cover image
        String? newCoverPath;
        if (huntMap['cover_image_path'] != null) {
          final originalCoverName = path.basename(huntMap['cover_image_path'] as String);
          final coverFile = archive.findFile('hunts/covers/$originalCoverName');
          if (coverFile != null) {
            final coversDir = Directory(path.join(huntsBaseDir.path, 'covers'));
            if (!await coversDir.exists()) {
              await coversDir.create(recursive: true);
            }
            newCoverPath = path.join(coversDir.path, originalCoverName);
            await File(newCoverPath).writeAsBytes(coverFile.content as List<int>);
          }
        }

        // Create hunt with updated cover path
        final hunt = TreasureHunt.fromDatabaseMap({
          ...huntMap as Map<String, dynamic>,
          'cover_image_path': newCoverPath,
        });

        if (existingHunt != null) {
          await _db.updateTreasureHunt(hunt);
        } else {
          await _db.insertTreasureHunt(hunt);
        }
        stats.huntCount++;
      } catch (e) {
        warnings.add('Failed to import hunt "${huntMap['name']}": $e');
      }
    }

    // Import documents
    final docsFile = archive.findFile('hunts/documents.json');
    if (docsFile != null) {
      final docsData = json.decode(utf8.decode(docsFile.content as List<int>)) as List;

      for (final docMap in docsData) {
        try {
          final huntId = docMap['hunt_id'] as String;

          // Restore file if present
          String? newFilePath;
          if (docMap['_exportedFilePath'] != null) {
            final exportedFile = archive.findFile(docMap['_exportedFilePath'] as String);
            if (exportedFile != null) {
              final huntFilesDir = Directory(path.join(huntsBaseDir.path, huntId, 'documents'));
              if (!await huntFilesDir.exists()) {
                await huntFilesDir.create(recursive: true);
              }
              final fileName = path.basename(docMap['_exportedFilePath'] as String);
              newFilePath = path.join(huntFilesDir.path, fileName);
              await File(newFilePath).writeAsBytes(exportedFile.content as List<int>);
            }
          }

          // Restore thumbnail if present
          String? newThumbPath;
          if (docMap['_exportedThumbnailPath'] != null) {
            final exportedThumb = archive.findFile(docMap['_exportedThumbnailPath'] as String);
            if (exportedThumb != null) {
              final thumbsDir = Directory(path.join(huntsBaseDir.path, huntId, 'thumbnails'));
              if (!await thumbsDir.exists()) {
                await thumbsDir.create(recursive: true);
              }
              final thumbName = path.basename(docMap['_exportedThumbnailPath'] as String);
              newThumbPath = path.join(thumbsDir.path, thumbName);
              await File(newThumbPath).writeAsBytes(exportedThumb.content as List<int>);
            }
          }

          final doc = HuntDocument.fromDatabaseMap({
            ...docMap as Map<String, dynamic>,
            'file_path': newFilePath ?? docMap['file_path'],
            'thumbnail_path': newThumbPath ?? docMap['thumbnail_path'],
          });

          await _db.insertHuntDocument(doc);
          stats.huntDocumentCount++;
        } catch (e) {
          warnings.add('Failed to import document "${docMap['name']}": $e');
        }
      }
    }

    // Import locations
    final locsFile = archive.findFile('hunts/locations.json');
    if (locsFile != null) {
      final locsData = json.decode(utf8.decode(locsFile.content as List<int>)) as List;

      for (final locMap in locsData) {
        try {
          final location = HuntLocation.fromDatabaseMap(locMap as Map<String, dynamic>);
          await _db.insertHuntLocation(location);
          stats.huntLocationCount++;
        } catch (e) {
          warnings.add('Failed to import location "${locMap['name']}": $e');
        }
      }
    }

    // Import session links
    final linksFile = archive.findFile('hunts/session_links.json');
    if (linksFile != null) {
      final linksData = json.decode(utf8.decode(linksFile.content as List<int>)) as List;

      for (final linkMap in linksData) {
        try {
          final link = HuntSessionLink.fromDatabaseMap(linkMap as Map<String, dynamic>);
          await _db.insertHuntSessionLink(link);
        } catch (e) {
          // Session links may fail if session doesn't exist - that's OK
          debugPrint('AppBackupService: Skipped session link: $e');
        }
      }
    }

    debugPrint('AppBackupService: Imported ${stats.huntCount} hunts');
  }

  Future<void> _importSessions(
    Archive archive,
    _MutableBackupStats stats,
    RestoreOptions options,
    List<String> warnings,
    BackupProgressCallback? onProgress,
  ) async {
    debugPrint('AppBackupService: Importing sessions...');

    final sessionsFile = archive.findFile('sessions/sessions.json');
    if (sessionsFile == null) {
      warnings.add('No session data found in backup');
      return;
    }

    final sessionsData = json.decode(utf8.decode(sessionsFile.content as List<int>)) as List;
    final totalSessions = sessionsData.length;

    for (var i = 0; i < sessionsData.length; i++) {
      final sessionMap = sessionsData[i];
      onProgress?.call(
        'Importing sessions',
        0.5 + (0.35 * i / totalSessions),
        'Session ${i + 1} of $totalSessions',
      );
      try {
        final sessionId = sessionMap['id'] as String;

        // Check if session already exists
        final existingSession = await _db.getSession(sessionId);
        if (existingSession != null && !options.replaceExisting) {
          stats.skippedSessionCount++;
          continue;
        }

        // Import session using model constructor
        final session = TrackingSession.fromMap(sessionMap as Map<String, dynamic>);
        if (existingSession != null) {
          await _db.updateSession(session);
        } else {
          await _db.insertSession(session);
        }
        stats.sessionCount++;

        // Import breadcrumbs
        final bcFile = archive.findFile('sessions/$sessionId/breadcrumbs.json');
        if (bcFile != null) {
          final bcData = json.decode(utf8.decode(bcFile.content as List<int>)) as List;
          final breadcrumbs = bcData
              .map((bc) => Breadcrumb.fromMap(bc as Map<String, dynamic>))
              .toList();
          await _db.insertBreadcrumbs(breadcrumbs);
        }

        // Import waypoints
        final wpFile = archive.findFile('sessions/$sessionId/waypoints.json');
        if (wpFile != null) {
          final wpData = json.decode(utf8.decode(wpFile.content as List<int>)) as List;
          for (final wpMap in wpData) {
            final waypoint = Waypoint.fromMap(wpMap as Map<String, dynamic>);
            await _db.insertWaypoint(waypoint);
          }
        }

        // Import photo waypoints
        final photoFile = archive.findFile('sessions/$sessionId/photo_waypoints.json');
        if (photoFile != null) {
          final docsDir = await getApplicationDocumentsDirectory();

          // Use the same directory structure as PhotoStorageService:
          // photos/sessions/{sessionId}/originals/ for photos
          // photos/sessions/{sessionId}/thumbnails/ for thumbnails
          final photoBaseDir = Directory(path.join(docsDir.path, 'photos', 'sessions', sessionId, 'originals'));
          final thumbBaseDir = Directory(path.join(docsDir.path, 'photos', 'sessions', sessionId, 'thumbnails'));

          final photoData = json.decode(utf8.decode(photoFile.content as List<int>)) as List;

          for (final photoMap in photoData) {
            try {
              String? newRelativeFilePath;
              String? newRelativeThumbPath;

              // Restore photo file if present in archive
              if (photoMap['_exportedFilePath'] != null) {
                final exportedFile = archive.findFile(photoMap['_exportedFilePath'] as String);
                if (exportedFile != null) {
                  if (!photoBaseDir.existsSync()) {
                    await photoBaseDir.create(recursive: true);
                  }
                  final fileName = path.basename(photoMap['_exportedFilePath'] as String);
                  final absolutePath = path.join(photoBaseDir.path, fileName);
                  await File(absolutePath).writeAsBytes(exportedFile.content as List<int>);

                  // Store RELATIVE path (matching PhotoStorageService format)
                  newRelativeFilePath = path.join('photos', 'sessions', sessionId, 'originals', fileName);
                }
              }

              // Restore thumbnail if present in archive
              if (photoMap['_exportedThumbnailPath'] != null) {
                final exportedThumb = archive.findFile(photoMap['_exportedThumbnailPath'] as String);
                if (exportedThumb != null) {
                  if (!thumbBaseDir.existsSync()) {
                    await thumbBaseDir.create(recursive: true);
                  }
                  final thumbName = path.basename(photoMap['_exportedThumbnailPath'] as String);
                  final absoluteThumbPath = path.join(thumbBaseDir.path, thumbName);
                  await File(absoluteThumbPath).writeAsBytes(exportedThumb.content as List<int>);

                  // Store RELATIVE path (matching PhotoStorageService format)
                  newRelativeThumbPath = path.join('photos', 'sessions', sessionId, 'thumbnails', thumbName);
                }
              }

              // Create photo waypoint with RELATIVE paths (not absolute)
              // This ensures paths survive iOS container changes and app restarts
              final photoWaypoint = PhotoWaypoint.fromMap({
                ...photoMap as Map<String, dynamic>,
                'file_path': newRelativeFilePath ?? photoMap['file_path'],
                'thumbnail_path': newRelativeThumbPath ?? photoMap['thumbnail_path'],
              });

              await _insertPhotoWaypoint(photoWaypoint);
            } catch (e) {
              warnings.add('Failed to import photo for session "$sessionId": $e');
            }
          }
          debugPrint('AppBackupService: Imported ${photoData.length} photos for session $sessionId');
        }

        // Import custom markers for this session
        final markersFile = archive.findFile('sessions/$sessionId/custom_markers.json');
        if (markersFile != null) {
          final markersData = json.decode(utf8.decode(markersFile.content as List<int>)) as List;

          for (final markerMap in markersData) {
            try {
              final marker = CustomMarker.fromDatabaseMap(markerMap as Map<String, dynamic>);
              await _db.insertCustomMarker(marker);
              stats.customMarkerCount++;
            } catch (e) {
              warnings.add('Failed to import custom marker "${markerMap['name']}": $e');
            }
          }
          debugPrint('AppBackupService: Imported ${markersData.length} custom markers for session $sessionId');
        }

        // Import marker attachments for this session
        final attachmentsFile = archive.findFile('sessions/$sessionId/marker_attachments.json');
        if (attachmentsFile != null) {
          final attachmentsData = json.decode(utf8.decode(attachmentsFile.content as List<int>)) as List;

          // Create base directory for attachments
          final attachDocsDir = await getApplicationDocumentsDirectory();
          final attachmentsBaseDir = Directory(path.join(attachDocsDir.path, 'markers'));

          for (final attachmentMap in attachmentsData) {
            try {
              final markerId = attachmentMap['marker_id'] as String;
              String? newFilePath;
              String? newThumbPath;

              // Restore attachment file if present in archive
              if (attachmentMap['_exportedFilePath'] != null) {
                final exportedFile = archive.findFile(attachmentMap['_exportedFilePath'] as String);
                if (exportedFile != null) {
                  // Determine the type subdirectory (image, audio, pdf, document)
                  final typeDir = attachmentMap['type'] as String? ?? 'image';
                  final markerAttachDir = Directory(
                    path.join(attachmentsBaseDir.path, markerId, typeDir == 'image' ? 'images' : typeDir),
                  );
                  if (!markerAttachDir.existsSync()) {
                    await markerAttachDir.create(recursive: true);
                  }
                  final fileName = path.basename(attachmentMap['_exportedFilePath'] as String);
                  newFilePath = path.join(markerAttachDir.path, fileName);
                  await File(newFilePath).writeAsBytes(exportedFile.content as List<int>);
                }
              }

              // Restore thumbnail if present in archive
              if (attachmentMap['_exportedThumbnailPath'] != null) {
                final exportedThumb = archive.findFile(attachmentMap['_exportedThumbnailPath'] as String);
                if (exportedThumb != null) {
                  final thumbDir = Directory(
                    path.join(attachmentsBaseDir.path, markerId, 'thumbnails'),
                  );
                  if (!thumbDir.existsSync()) {
                    await thumbDir.create(recursive: true);
                  }
                  final thumbName = path.basename(attachmentMap['_exportedThumbnailPath'] as String);
                  newThumbPath = path.join(thumbDir.path, thumbName);
                  await File(newThumbPath).writeAsBytes(exportedThumb.content as List<int>);
                }
              }

              // Create attachment with restored file paths
              final attachment = MarkerAttachment.fromDatabaseMap({
                ...attachmentMap as Map<String, dynamic>,
                'file_path': newFilePath ?? attachmentMap['file_path'],
                'thumbnail_path': newThumbPath ?? attachmentMap['thumbnail_path'],
              });

              await _db.insertMarkerAttachment(attachment);
              stats.markerAttachmentCount++;
            } catch (e) {
              warnings.add('Failed to import marker attachment: $e');
            }
          }
          debugPrint('AppBackupService: Imported ${attachmentsData.length} marker attachments for session $sessionId');
        }

        // Import session statistics
        final statsFile = archive.findFile('sessions/$sessionId/statistics.json');
        if (statsFile != null) {
          final statsData = json.decode(utf8.decode(statsFile.content as List<int>)) as List;

          for (final statMap in statsData) {
            try {
              final statistics = SessionStatistics.fromMap(statMap as Map<String, dynamic>);
              await _db.saveSessionStatistics(statistics);
            } catch (e) {
              warnings.add('Failed to import statistics for session "$sessionId": $e');
            }
          }
          debugPrint('AppBackupService: Imported ${statsData.length} statistics records for session $sessionId');
        }
      } catch (e) {
        warnings.add('Failed to import session "${sessionMap['name']}": $e');
      }
    }

    debugPrint('AppBackupService: Imported ${stats.sessionCount} sessions');
  }

  /// Insert a photo waypoint into the database
  Future<void> _insertPhotoWaypoint(PhotoWaypoint photoWaypoint) async {
    try {
      final db = await _db.database;
      await db.insert(
        'photo_waypoints',
        photoWaypoint.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('AppBackupService: Error inserting photo waypoint: $e');
      rethrow;
    }
  }

  Future<void> _importRoutes(
    Archive archive,
    _MutableBackupStats stats,
    RestoreOptions options,
    List<String> warnings,
  ) async {
    debugPrint('AppBackupService: Importing routes...');

    // Import imported routes (from GPX/KML)
    final importedRoutesFile = archive.findFile('routes/imported_routes.json');
    if (importedRoutesFile != null) {
      final routesData = json.decode(utf8.decode(importedRoutesFile.content as List<int>)) as List;

      for (final routeMap in routesData) {
        try {
          final routeId = routeMap['id'] as String;

          // Check if route already exists
          final existingRoute = await _db.getImportedRouteById(routeId);
          if (existingRoute != null && !options.replaceExisting) {
            stats.skippedRouteCount++;
            continue;
          }

          // Parse the full route from JSON (includes points and waypoints)
          final route = ImportedRoute.fromJson(routeMap as Map<String, dynamic>);

          if (existingRoute != null) {
            await _db.deleteImportedRoute(routeId);
          }

          await _db.insertImportedRoute(route);
          stats.routeCount++;
        } catch (e) {
          warnings.add('Failed to import route "${routeMap['name']}": $e');
        }
      }
      debugPrint('AppBackupService: Imported ${stats.routeCount} imported routes');
    }

    // Import planned routes (created in-app)
    final plannedRoutesFile = archive.findFile('routes/planned_routes.json');
    if (plannedRoutesFile != null) {
      final plannedData = json.decode(utf8.decode(plannedRoutesFile.content as List<int>)) as List;
      var plannedCount = 0;

      for (final routeMap in plannedData) {
        try {
          final routeId = routeMap['id'] as String;

          // Check if route already exists
          final existingRoute = await _db.getPlannedRoute(routeId);
          if (existingRoute != null && !options.replaceExisting) {
            stats.skippedRouteCount++;
            continue;
          }

          if (existingRoute != null) {
            await _db.deletePlannedRoute(routeId);
          }

          await _db.insertPlannedRoute(routeMap as Map<String, dynamic>);
          plannedCount++;
          stats.routeCount++;
        } catch (e) {
          warnings.add('Failed to import planned route "${routeMap['name']}": $e');
        }
      }
      debugPrint('AppBackupService: Imported $plannedCount planned routes');
    }

    // Handle legacy backup format (routes/routes.json)
    if (importedRoutesFile == null && plannedRoutesFile == null) {
      final legacyRoutesFile = archive.findFile('routes/routes.json');
      if (legacyRoutesFile != null) {
        final routesData = json.decode(utf8.decode(legacyRoutesFile.content as List<int>)) as List;
        for (final routeMap in routesData) {
          try {
            final route = ImportedRoute.fromJson(routeMap as Map<String, dynamic>);
            await _db.insertImportedRoute(route);
            stats.routeCount++;
          } catch (e) {
            warnings.add('Failed to import legacy route: $e');
          }
        }
      } else {
        warnings.add('No route data found in backup');
      }
    }

    debugPrint('AppBackupService: Imported ${stats.routeCount} total routes');
  }

  Future<void> _importSettings(Archive archive, List<String> warnings) async {
    debugPrint('AppBackupService: Importing settings...');

    // Try new filename first, then legacy filename
    var settingsFile = archive.findFile('app_settings.json');
    settingsFile ??= archive.findFile('settings.json');

    if (settingsFile == null) {
      warnings.add('No settings found in backup');
      return;
    }

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final settingsPath = path.join(docsDir.path, 'app_settings.json');
      await File(settingsPath).writeAsBytes(settingsFile.content as List<int>);
      debugPrint('AppBackupService: Settings imported to $settingsPath');
    } catch (e) {
      warnings.add('Failed to import settings: $e');
    }
  }

  // ============================================================
  // Private: Utilities
  // ============================================================

  void _addJsonToArchive(Archive archive, String path, Object data) {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final bytes = utf8.encode(jsonStr);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  Future<void> _clearAllData() async {
    // Clear custom markers first (they have ON DELETE SET NULL for session_id,
    // so they won't be automatically deleted when sessions are deleted)
    final customMarkerService = CustomMarkerService();
    await customMarkerService.deleteAllMarkers();
    debugPrint('AppBackupService: Cleared all custom markers');

    // Clear hunts (cascades to hunt_documents, hunt_locations, hunt_session_links)
    final hunts = await _db.getAllTreasureHunts();
    for (final hunt in hunts) {
      await _huntService.deleteHunt(hunt.id);
    }
    debugPrint('AppBackupService: Cleared ${hunts.length} hunts');

    // Clear sessions (cascades to breadcrumbs, waypoints, photo_waypoints, statistics)
    final sessions = await _db.getAllSessions();
    for (final session in sessions) {
      await _db.deleteSession(session.id);
    }
    debugPrint('AppBackupService: Cleared ${sessions.length} sessions');

    // Clear imported routes (cascades to route_points, route_waypoints)
    final importedRoutes = await _db.getImportedRoutes();
    for (final route in importedRoutes) {
      await _db.deleteImportedRoute(route.id);
    }
    debugPrint('AppBackupService: Cleared ${importedRoutes.length} imported routes');

    // Clear planned routes
    final plannedRoutes = await _db.getPlannedRoutes();
    for (final route in plannedRoutes) {
      await _db.deletePlannedRoute(route['id'] as String);
    }
    debugPrint('AppBackupService: Cleared ${plannedRoutes.length} planned routes');

    debugPrint('AppBackupService: Cleared all existing data');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ============================================================
  // Private: Encryption Methods
  // ============================================================

  /// Encrypt data with AES-256-GCM using password-based key derivation
  Uint8List _encryptData(Uint8List plaintext, String password) {
    // Generate random salt and nonce
    final salt = _generateSecureRandom(_saltLength);
    final nonce = _generateSecureRandom(_nonceLength);

    // Derive encryption key from password using PBKDF2
    final key = _deriveKey(password, salt);

    // Encrypt with AES-256-GCM
    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(
        encrypt_lib.Key(key),
        mode: encrypt_lib.AESMode.gcm,
      ),
    );

    final encrypted = encrypter.encryptBytes(
      plaintext,
      iv: encrypt_lib.IV(nonce),
    );

    // Build encrypted file format:
    // [Header 256 bytes][Encrypted data]
    final header = _buildHeader(salt, nonce);
    final result = Uint8List(header.length + encrypted.bytes.length);
    result.setRange(0, header.length, header);
    result.setRange(header.length, result.length, encrypted.bytes);

    return result;
  }

  /// Decrypt data with AES-256-GCM using password-based key derivation
  /// Returns null if decryption fails (wrong password or corrupted)
  Uint8List? _decryptData(Uint8List encryptedData, String password) {
    try {
      if (encryptedData.length < _headerSize + 16) {
        debugPrint('AppBackupService: File too small to be valid encrypted backup');
        return null;
      }

      // Parse header
      final header = encryptedData.sublist(0, _headerSize);

      // Verify magic bytes
      final magic = utf8.decode(header.sublist(0, 4));
      if (magic != _magicBytes) {
        debugPrint('AppBackupService: Invalid magic bytes: $magic');
        return null;
      }

      // Extract salt and nonce from header
      final salt = Uint8List.fromList(header.sublist(72, 72 + _saltLength));
      final nonce = Uint8List.fromList(header.sublist(104, 104 + _nonceLength));

      // Derive key from password
      final key = _deriveKey(password, salt);

      // Decrypt with AES-256-GCM
      final encrypter = encrypt_lib.Encrypter(
        encrypt_lib.AES(
          encrypt_lib.Key(key),
          mode: encrypt_lib.AESMode.gcm,
        ),
      );

      final ciphertext = encryptedData.sublist(_headerSize);
      final encrypted = encrypt_lib.Encrypted(ciphertext);

      final decrypted = encrypter.decryptBytes(
        encrypted,
        iv: encrypt_lib.IV(nonce),
      );

      return Uint8List.fromList(decrypted);
    } catch (e) {
      debugPrint('AppBackupService: Decryption failed: $e');
      return null;
    }
  }

  /// Derive encryption key from password using PBKDF2
  Uint8List _deriveKey(String password, Uint8List salt) {
    final passwordBytes = utf8.encode(password);
    final hmac = Hmac(sha256, passwordBytes);

    // PBKDF2 implementation
    final result = Uint8List(32); // 256 bits
    final block = Uint8List(32);

    // Simplified: single block for 256-bit key
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    for (var j = 0; j < 32; j++) {
      block[j] = u[j];
    }

    for (var iter = 1; iter < _kdfIterations; iter++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < 32; j++) {
        block[j] ^= u[j];
      }
    }

    result.setRange(0, 32, block);
    return result;
  }

  /// Build encrypted file header
  Uint8List _buildHeader(Uint8List salt, Uint8List nonce) {
    final header = Uint8List(_headerSize);

    // Magic bytes "OBKV" (Obsession Backup Version)
    header.setRange(0, 4, utf8.encode(_magicBytes));

    // Encryption algorithm (32 bytes, null-padded)
    final algBytes = utf8.encode(_encryptionAlgorithm);
    header.setRange(4, 4 + algBytes.length, algBytes);

    // KDF algorithm (32 bytes, null-padded)
    final kdfBytes = utf8.encode(_kdfAlgorithm);
    header.setRange(36, 36 + kdfBytes.length, kdfBytes);

    // KDF iterations (4 bytes, big-endian)
    header[68] = (_kdfIterations >> 24) & 0xFF;
    header[69] = (_kdfIterations >> 16) & 0xFF;
    header[70] = (_kdfIterations >> 8) & 0xFF;
    header[71] = _kdfIterations & 0xFF;

    // Salt (32 bytes)
    header.setRange(72, 72 + _saltLength, salt);

    // Nonce (16 bytes)
    header.setRange(104, 104 + _nonceLength, nonce);

    // Remaining bytes are reserved (zeros)
    return header;
  }

  /// Generate cryptographically secure random bytes
  Uint8List _generateSecureRandom(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }
}

/// Mutable stats for building during export/import
class _MutableBackupStats {
  int huntCount = 0;
  int huntDocumentCount = 0;
  int huntLocationCount = 0;
  int sessionCount = 0;
  int routeCount = 0;
  int customMarkerCount = 0;
  int markerAttachmentCount = 0;
  int totalFileSize = 0;
  // Skipped counts (for merge mode)
  int skippedHuntCount = 0;
  int skippedSessionCount = 0;
  int skippedRouteCount = 0;

  BackupStats toStats() => BackupStats(
    huntCount: huntCount,
    huntDocumentCount: huntDocumentCount,
    huntLocationCount: huntLocationCount,
    sessionCount: sessionCount,
    routeCount: routeCount,
    customMarkerCount: customMarkerCount,
    markerAttachmentCount: markerAttachmentCount,
    totalFileSize: totalFileSize,
    skippedHuntCount: skippedHuntCount,
    skippedSessionCount: skippedSessionCount,
    skippedRouteCount: skippedRouteCount,
  );
}
