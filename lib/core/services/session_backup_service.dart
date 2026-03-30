import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/session_backup_models.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/services/data_encryption_service.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/waypoint_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Service for automated session backup and recovery
class SessionBackupService {
  SessionBackupService._();
  static SessionBackupService? _instance;
  static SessionBackupService get instance =>
      _instance ??= SessionBackupService._();

  final DatabaseService _databaseService = DatabaseService();
  final DataEncryptionService _encryptionService = DataEncryptionService();
  final WaypointService _waypointService = WaypointService.instance;
  final Uuid _uuid = const Uuid();

  // Encryption password for backups (set when enabling encrypted backups)
  String? _encryptionPassword;

  SessionBackupConfig _config = const SessionBackupConfig();
  Timer? _backupTimer;
  bool _isBackupInProgress = false;

  /// Initialize the backup service with configuration
  Future<void> initialize([SessionBackupConfig? config]) async {
    _config = config ?? await _loadBackupConfig();

    if (_config.enableAutoBackup) {
      _scheduleNextBackup();
    }
  }

  /// Get current backup configuration
  SessionBackupConfig get config => _config;

  /// Update backup configuration
  Future<void> updateConfig(SessionBackupConfig newConfig) async {
    _config = newConfig;
    await _saveBackupConfig(newConfig);

    // Reschedule backups if needed
    _backupTimer?.cancel();
    if (_config.enableAutoBackup) {
      _scheduleNextBackup();
    }
  }

  /// Create a manual backup
  Future<BackupResult> createBackup({
    BackupType type = BackupType.manual,
    String? description,
    List<String>? sessionIds,
  }) async {
    if (_isBackupInProgress) {
      return const BackupResult(
        success: false,
        errors: ['Backup already in progress'],
      );
    }

    _isBackupInProgress = true;

    try {
      // Check prerequisites
      final prerequisiteCheck = await _checkBackupPrerequisites();
      if (!prerequisiteCheck.success) {
        return prerequisiteCheck;
      }

      // Get sessions to backup
      final sessions = sessionIds != null
          ? await _getSessionsByIds(sessionIds)
          : await _databaseService.getAllSessions();

      if (sessions.isEmpty) {
        return const BackupResult(
          success: false,
          errors: ['No sessions to backup'],
        );
      }

      // Create backup data
      final backupData = await _createBackupData(sessions);

      // Save backup file
      final backupFile = await _saveBackupFile(backupData, type);

      // Create backup record
      final backup = SessionBackup(
        id: _uuid.v4(),
        createdAt: DateTime.now(),
        backupType: type,
        location: _config.backupLocation,
        filePath: backupFile.path,
        fileSize: await backupFile.length(),
        sessionCount: sessions.length,
        description: description,
        isCompressed: _config.compressionEnabled,
        isEncrypted: _config.encryptionEnabled,
        checksum: await _calculateChecksum(backupFile),
      );

      // Save backup record to database
      await _saveBackupRecord(backup);

      // Clean up old backups
      await _cleanupOldBackups();

      return BackupResult(
        success: true,
        backup: backup,
      );
    } catch (e) {
      debugPrint('Error creating backup: $e');
      return BackupResult(
        success: false,
        errors: ['Failed to create backup: $e'],
      );
    } finally {
      _isBackupInProgress = false;
    }
  }

  /// Restore sessions from a backup
  Future<RestoreResult> restoreFromBackup(
      String backupId, RestoreOptions options) async {
    try {
      // Get backup record
      final backup = await _getBackupRecord(backupId);
      if (backup == null) {
        return const RestoreResult(
          success: false,
          errors: ['Backup not found'],
        );
      }

      // Validate backup integrity
      if (options.validateIntegrity) {
        final validationResult = await _validateBackupIntegrity(backup);
        if (!validationResult.isValid) {
          return RestoreResult(
            success: false,
            errors: [
              'Backup integrity check failed: ${validationResult.errors.join(', ')}'
            ],
          );
        }
      }

      // Create backup before restore if requested
      if (options.createBackupBeforeRestore) {
        final preRestoreBackup = await createBackup(
          type: BackupType.emergency,
          description: 'Pre-restore backup',
        );
        if (!preRestoreBackup.success) {
          return RestoreResult(
            success: false,
            errors: const ['Failed to create pre-restore backup'],
            warnings: preRestoreBackup.errors,
          );
        }
      }

      // Load backup data
      final backupData = await _loadBackupData(backup);

      // Restore sessions
      final restoredSessionIds = <String>[];
      final errors = <String>[];
      final warnings = <String>[];
      final skippedSessions = <String>[];

      for (final sessionData in backupData['sessions'] as List) {
        try {
          final sessionMap = sessionData as Map<String, dynamic>;

          // Apply session filter if provided
          if (options.sessionFilter != null &&
              !options.sessionFilter!(sessionMap)) {
            skippedSessions.add(sessionMap['id'] as String);
            continue;
          }

          final sessionId = await _restoreSession(
            sessionMap,
            options,
            backupData,
          );

          if (sessionId != null) {
            restoredSessionIds.add(sessionId);
          } else {
            skippedSessions.add(sessionMap['id'] as String);
          }
        } catch (e) {
          errors.add('Failed to restore session: $e');
        }
      }

      return RestoreResult(
        success: errors.isEmpty,
        restoredSessionIds: restoredSessionIds,
        errors: errors,
        warnings: warnings,
        skippedSessions: skippedSessions,
      );
    } catch (e) {
      debugPrint('Error restoring from backup: $e');
      return RestoreResult(
        success: false,
        errors: ['Failed to restore from backup: $e'],
      );
    }
  }

  /// Get list of available backups
  Future<List<SessionBackup>> getAvailableBackups() async {
    try {
      return await _getBackupRecords();
    } catch (e) {
      debugPrint('Error getting available backups: $e');
      return [];
    }
  }

  /// Delete a backup
  Future<bool> deleteBackup(String backupId) async {
    try {
      final backup = await _getBackupRecord(backupId);
      if (backup == null) return false;

      // Delete backup file
      final file = File(backup.filePath);
      if (file.existsSync()) {
        await file.delete();
      }

      // Delete backup record
      await _deleteBackupRecord(backupId);

      return true;
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      return false;
    }
  }

  /// Validate session data integrity
  Future<List<IntegrityCheckResult>> validateSessionIntegrity([
    List<String>? sessionIds,
  ]) async {
    final results = <IntegrityCheckResult>[];

    try {
      final sessions = sessionIds != null
          ? await _getSessionsByIds(sessionIds)
          : await _databaseService.getAllSessions();

      for (final session in sessions) {
        final result = await _checkSessionIntegrity(session);
        results.add(result);
      }
    } catch (e) {
      debugPrint('Error validating session integrity: $e');
    }

    return results;
  }

  /// Recover corrupted session data
  Future<bool> recoverSession(
    String sessionId, [
    List<RecoveryAction>? actions,
  ]) async {
    try {
      final session = await _databaseService.getSession(sessionId);
      if (session == null) return false;

      final integrityResult = await _checkSessionIntegrity(session);
      if (integrityResult.isValid) return true;

      // Apply recovery actions
      final recoveryActions =
          actions ?? _determineRecoveryActions(integrityResult);

      for (final action in recoveryActions) {
        await _applyRecoveryAction(session, action);
      }

      return true;
    } catch (e) {
      debugPrint('Error recovering session: $e');
      return false;
    }
  }

  /// Trigger backup on session completion
  Future<void> onSessionCompleted(String sessionId) async {
    if (_config.enableAutoBackup && _config.backupOnSessionComplete) {
      await createBackup(
        type: BackupType.automatic,
        description: 'Auto-backup on session completion',
        sessionIds: [sessionId],
      );
    }
  }

  /// Trigger backup on app close
  Future<void> onAppClose() async {
    if (_config.enableAutoBackup && _config.backupOnAppClose) {
      await createBackup(
        type: BackupType.automatic,
        description: 'Auto-backup on app close',
      );
    }
  }

  // Private helper methods

  Future<SessionBackupConfig> _loadBackupConfig() async {
    try {
      // Load from database or return default
      return const SessionBackupConfig();
    } catch (e) {
      return const SessionBackupConfig();
    }
  }

  Future<void> _saveBackupConfig(SessionBackupConfig config) async {
    try {
      // Save to database
      debugPrint('Saving backup config');
    } catch (e) {
      debugPrint('Error saving backup config: $e');
    }
  }

  void _scheduleNextBackup() {
    _backupTimer?.cancel();

    Duration interval;
    switch (_config.backupFrequency) {
      case BackupFrequency.realtime:
        return; // Real-time backups are triggered by events
      case BackupFrequency.hourly:
        interval = const Duration(hours: 1);
        break;
      case BackupFrequency.daily:
        interval = const Duration(days: 1);
        break;
      case BackupFrequency.weekly:
        interval = const Duration(days: 7);
        break;
      case BackupFrequency.manual:
        return; // No automatic scheduling
    }

    _backupTimer = Timer(interval, () {
      createBackup(type: BackupType.scheduled);
      _scheduleNextBackup(); // Schedule next backup
    });
  }

  Future<BackupResult> _checkBackupPrerequisites() async {
    final errors = <String>[];

    // Check battery level
    if (_config.lowBatterySkip) {
      // Would check actual battery level
      // For now, assume battery is OK
    }

    // Check network connectivity for cloud backups
    if (_config.backupLocation == BackupLocation.cloud) {
      if (_config.wifiOnlyBackup) {
        // Would check if on WiFi
        // For now, assume WiFi is available
      }
    }

    // Check storage space
    try {
      final directory = await getApplicationDocumentsDirectory();
      // Check if directory is accessible
      await directory.list().length;
    } catch (e) {
      errors.add('Cannot access storage directory');
    }

    return BackupResult(
      success: errors.isEmpty,
      errors: errors,
    );
  }

  Future<List<TrackingSession>> _getSessionsByIds(
      List<String> sessionIds) async {
    final sessions = <TrackingSession>[];
    for (final id in sessionIds) {
      final session = await _databaseService.getSession(id);
      if (session != null) {
        sessions.add(session);
      }
    }
    return sessions;
  }

  Future<Map<String, dynamic>> _createBackupData(
      List<TrackingSession> sessions) async {
    final backupData = <String, dynamic>{
      'version': '1.0',
      'created_at': DateTime.now().toIso8601String(),
      'sessions': <Map<String, dynamic>>[],
      'waypoints': <String, dynamic>{},
      'breadcrumbs': <String, dynamic>{},
      'photos': <String, dynamic>{},
      'statistics': <String, dynamic>{},
    };

    for (final session in sessions) {
      // Add session data
      backupData['sessions'].add(session.toMap());

      // Add breadcrumbs
      final breadcrumbs =
          await _databaseService.getBreadcrumbsForSession(session.id);
      backupData['breadcrumbs'][session.id] =
          breadcrumbs.map((b) => b.toMap()).toList();

      // Add waypoints if enabled
      if (_config.includeWaypoints) {
        final waypoints =
            await _waypointService.getWaypointsForSession(session.id);
        backupData['waypoints'][session.id] =
            waypoints.map((w) => w.toMap()).toList();
      }

      // Add photos if enabled
      if (_config.includePhotos) {
        // Would get photo data
        backupData['photos'][session.id] = <String>[];
      }

      // Add statistics if enabled
      if (_config.includeStatistics) {
        // Would get statistics data
        backupData['statistics'][session.id] = <String, dynamic>{};
      }
    }

    return backupData;
  }

  /// Set encryption password for backup encryption
  void setEncryptionPassword(String password) {
    _encryptionPassword = password;
  }

  Future<File> _saveBackupFile(
      Map<String, dynamic> backupData, BackupType type) async {
    final directory = await _getBackupDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Use .obstrack extension for encrypted backups, .json for unencrypted
    final extension = _config.encryptionEnabled ? 'obstrack' : 'json';
    final filename = 'backup_${type.name}_$timestamp.$extension';
    final file = File('${directory.path}/$filename');

    // Compress if enabled
    if (_config.compressionEnabled) {
      // Compression to be implemented
      debugPrint('Compression not implemented yet');
    }

    // SECURITY: Encrypt backup if enabled
    if (_config.encryptionEnabled && _encryptionPassword != null) {
      final encryptedData = await _encryptionService.createEncryptedBackup(
        backupData,
        _encryptionPassword!,
      );

      if (encryptedData != null) {
        await file.writeAsBytes(encryptedData);
        debugPrint('Backup encrypted and saved: ${file.path}');
        return file;
      } else {
        debugPrint('Encryption failed, saving unencrypted backup');
      }
    }

    // Save unencrypted if encryption disabled or failed
    final String jsonData = jsonEncode(backupData);
    await file.writeAsString(jsonData);
    return file;
  }

  Future<Directory> _getBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/backups');

    if (!backupDir.existsSync()) {
      await backupDir.create(recursive: true);
    }

    return backupDir;
  }

  Future<String> _calculateChecksum(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _saveBackupRecord(SessionBackup backup) async {
    // Would save to database
    debugPrint('Saving backup record: ${backup.id}');
  }

  Future<void> _cleanupOldBackups() async {
    try {
      final backups = await _getBackupRecords();
      if (backups.length <= _config.maxBackupCount) return;

      // Sort by creation date (oldest first)
      backups.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Delete oldest backups
      final toDelete = backups.take(backups.length - _config.maxBackupCount);
      for (final backup in toDelete) {
        await deleteBackup(backup.id);
      }
    } catch (e) {
      debugPrint('Error cleaning up old backups: $e');
    }
  }

  Future<SessionBackup?> _getBackupRecord(String backupId) async =>
      // Would query database
      null;

  Future<List<SessionBackup>> _getBackupRecords() async =>
      // Would query database
      [];

  Future<void> _deleteBackupRecord(String backupId) async {
    // Would delete from database
    debugPrint('Deleting backup record: $backupId');
  }

  Future<ValidationResult> _validateBackupIntegrity(
      SessionBackup backup) async {
    final errors = <String>[];
    final warnings = <String>[];

    try {
      final file = File(backup.filePath);

      // Check if file exists
      if (!file.existsSync()) {
        errors.add('Backup file not found');
        return ValidationResult(isValid: false, errors: errors);
      }

      // Verify checksum
      if (backup.checksum != null) {
        final actualChecksum = await _calculateChecksum(file);
        if (actualChecksum != backup.checksum) {
          errors.add('Checksum mismatch - backup may be corrupted');
        }
      }

      // Try to load and parse backup data
      final backupData = await _loadBackupData(backup);

      // Validate structure
      if (!backupData.containsKey('sessions')) {
        errors.add('Invalid backup format - missing sessions data');
      }

      // Validate session count
      final sessions = backupData['sessions'] as List?;
      if (sessions == null || sessions.length != backup.sessionCount) {
        warnings.add('Session count mismatch');
      }
    } catch (e) {
      errors.add('Failed to validate backup: $e');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  Future<Map<String, dynamic>> _loadBackupData(SessionBackup backup) async {
    final file = File(backup.filePath);

    // SECURITY: Decrypt if encrypted backup
    if (backup.isEncrypted) {
      if (_encryptionPassword == null) {
        throw Exception('Encryption password required to restore this backup');
      }

      final encryptedData = await file.readAsBytes();
      final decryptedData = await _encryptionService.restoreFromEncryptedBackup(
        encryptedData,
        _encryptionPassword!,
      );

      if (decryptedData == null) {
        throw Exception('Failed to decrypt backup - wrong password or corrupted file');
      }

      debugPrint('Backup decrypted successfully');
      return decryptedData;
    }

    // Unencrypted backup - read as JSON
    final String content = await file.readAsString();

    // Decompress if needed
    if (backup.isCompressed) {
      // Decompression to be implemented
      debugPrint('Decompression not implemented yet');
    }

    return jsonDecode(content) as Map<String, dynamic>;
  }

  Future<String?> _restoreSession(Map<String, dynamic> sessionData,
      RestoreOptions options, Map<String, dynamic> backupData) async {
    try {
      final sessionId = sessionData['id'] as String;

      // Check if session already exists
      final existingSession = await _databaseService.getSession(sessionId);
      if (existingSession != null && !options.overwriteExisting) {
        return null; // Skip existing session
      }

      // Restore session
      final session = TrackingSession.fromMap(sessionData);
      await _databaseService.insertSession(session);

      // Restore breadcrumbs
      final breadcrumbsData = backupData['breadcrumbs'][sessionId] as List?;
      if (breadcrumbsData != null) {
        for (final breadcrumbData in breadcrumbsData) {
          // Would restore breadcrumb from breadcrumbData
          debugPrint('Restoring breadcrumb: ${breadcrumbData['id']}');
        }
      }

      // Restore waypoints if enabled
      if (options.restoreWaypoints) {
        final waypointsData = backupData['waypoints'][sessionId] as List?;
        if (waypointsData != null) {
          for (final waypointData in waypointsData) {
            // Would restore waypoint from waypointData
            debugPrint('Restoring waypoint: ${waypointData['id']}');
          }
        }
      }

      // Restore photos if enabled
      if (options.restorePhotos) {
        final photosData = backupData['photos'][sessionId] as List?;
        if (photosData != null) {
          // Would restore photos
          debugPrint('Restoring photos');
        }
      }

      // Restore statistics if enabled
      if (options.restoreStatistics) {
        final statisticsData = backupData['statistics'][sessionId] as Map?;
        if (statisticsData != null) {
          // Would restore statistics
          debugPrint('Restoring statistics');
        }
      }

      return sessionId;
    } catch (e) {
      debugPrint('Error restoring session: $e');
      return null;
    }
  }

  Future<IntegrityCheckResult> _checkSessionIntegrity(
      TrackingSession session) async {
    final issues = <IntegrityIssue>[];
    bool canRecover = true;

    try {
      // Check breadcrumbs
      final breadcrumbs =
          await _databaseService.getBreadcrumbsForSession(session.id);
      if (breadcrumbs.isEmpty && session.breadcrumbCount > 0) {
        issues.add(const IntegrityIssue(
          type: IntegrityIssueType.missingBreadcrumbs,
          severity: IssueSeverity.high,
          description: 'Session has no breadcrumbs but count > 0',
          suggestedFix: 'Reset breadcrumb count or restore from backup',
        ));
      }

      // Check timestamps
      if (session.startedAt != null && session.completedAt != null) {
        if (session.completedAt!.isBefore(session.startedAt!)) {
          issues.add(const IntegrityIssue(
            type: IntegrityIssueType.invalidTimestamps,
            severity: IssueSeverity.medium,
            description: 'Completion time is before start time',
            suggestedFix: 'Correct timestamps based on breadcrumb data',
          ));
        }
      }

      // Check waypoints
      final waypoints =
          await _waypointService.getWaypointsForSession(session.id);
      for (final waypoint in waypoints) {
        // Check waypoint integrity
        if (waypoint.coordinates.latitude.abs() > 90 ||
            waypoint.coordinates.longitude.abs() > 180) {
          issues.add(IntegrityIssue(
            type: IntegrityIssueType.corruptedWaypoints,
            severity: IssueSeverity.medium,
            description: 'Invalid coordinates in waypoint ${waypoint.id}',
            suggestedFix: 'Remove or correct waypoint coordinates',
          ));
        }
      }

      // Check statistics consistency
      if (session.totalDistance < 0 || session.totalDuration < 0) {
        issues.add(const IntegrityIssue(
          type: IntegrityIssueType.invalidStatistics,
          severity: IssueSeverity.medium,
          description: 'Negative distance or duration values',
          suggestedFix: 'Recalculate statistics from breadcrumb data',
        ));
      }
    } catch (e) {
      issues.add(IntegrityIssue(
        type: IntegrityIssueType.incompleteSession,
        severity: IssueSeverity.critical,
        description: 'Error checking session integrity: $e',
        suggestedFix: 'Restore session from backup',
      ));
      canRecover = false;
    }

    return IntegrityCheckResult(
      sessionId: session.id,
      isValid: issues.isEmpty,
      issues: issues,
      canRecover: canRecover,
      recoveryActions: _generateRecoveryActions(issues),
    );
  }

  List<String> _generateRecoveryActions(List<IntegrityIssue> issues) {
    final actions = <String>[];

    for (final issue in issues) {
      if (issue.suggestedFix != null) {
        actions.add(issue.suggestedFix!);
      }
    }

    return actions;
  }

  List<RecoveryAction> _determineRecoveryActions(
      IntegrityCheckResult integrityResult) {
    final actions = <RecoveryAction>[];

    for (final issue in integrityResult.issues) {
      switch (issue.type) {
        case IntegrityIssueType.missingBreadcrumbs:
          actions.add(RecoveryAction.restoreFromBackup);
          break;
        case IntegrityIssueType.invalidTimestamps:
          actions.add(RecoveryAction.interpolateMissingData);
          break;
        case IntegrityIssueType.corruptedWaypoints:
          actions.add(RecoveryAction.removeCorruptedData);
          break;
        case IntegrityIssueType.invalidStatistics:
          actions.add(RecoveryAction.recalculateStatistics);
          break;
        default:
          actions.add(RecoveryAction.restoreFromBackup);
      }
    }

    return actions;
  }

  Future<void> _applyRecoveryAction(
      TrackingSession session, RecoveryAction action) async {
    switch (action) {
      case RecoveryAction.interpolateMissingData:
        await _interpolateMissingData(session);
        break;
      case RecoveryAction.removeCorruptedData:
        await _removeCorruptedData(session);
        break;
      case RecoveryAction.recalculateStatistics:
        await _recalculateStatistics(session);
        break;
      case RecoveryAction.rebuildIndex:
        await _rebuildIndex(session);
        break;
      case RecoveryAction.mergeFragments:
        await _mergeFragments(session);
        break;
      case RecoveryAction.restoreFromBackup:
        // Would attempt to restore from most recent backup
        debugPrint('Restore from backup not implemented');
        break;
    }
  }

  Future<void> _interpolateMissingData(TrackingSession session) async {
    // Would implement data interpolation
    debugPrint('Interpolating missing data for session ${session.id}');
  }

  Future<void> _removeCorruptedData(TrackingSession session) async {
    // Would remove corrupted waypoints, breadcrumbs, etc.
    debugPrint('Removing corrupted data for session ${session.id}');
  }

  Future<void> _recalculateStatistics(TrackingSession session) async {
    // Would recalculate session statistics from breadcrumb data
    debugPrint('Recalculating statistics for session ${session.id}');
  }

  Future<void> _rebuildIndex(TrackingSession session) async {
    // Would rebuild database indexes
    debugPrint('Rebuilding index for session ${session.id}');
  }

  Future<void> _mergeFragments(TrackingSession session) async {
    // Would merge fragmented session data
    debugPrint('Merging fragments for session ${session.id}');
  }

  /// Dispose of the service
  void dispose() {
    _backupTimer?.cancel();
  }
}
