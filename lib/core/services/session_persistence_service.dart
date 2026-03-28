import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/multi_day_session.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting and recovering tracking sessions across app restarts
class SessionPersistenceService {
  SessionPersistenceService._();

  static final SessionPersistenceService _instance =
      SessionPersistenceService._();
  static SessionPersistenceService get instance => _instance;

  static const String _activeSessionKey = 'active_session_state';
  static const String _multiDaySessionKey = 'active_multi_day_session';
  static const String _sessionBackupDir = 'session_backups';
  static const String _recoveryStateKey = 'recovery_state';
  static const String _lastAppCloseKey = 'last_app_close_time';
  static const String _crashRecoveryKey = 'crash_recovery_data';

  late final SharedPreferences _prefs;
  Timer? _persistenceTimer;
  Timer? _recoveryCheckTimer;
  bool _isInitialized = false;

  /// Initialize the persistence service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();

    // Start periodic persistence
    _startPeriodicPersistence();

    // Start recovery monitoring
    _startRecoveryMonitoring();

    _isInitialized = true;
    debugPrint('SessionPersistenceService initialized');
  }

  /// Dispose of the service
  void dispose() {
    _persistenceTimer?.cancel();
    _recoveryCheckTimer?.cancel();
    _isInitialized = false;
  }

  /// Save the current session state for recovery
  Future<void> persistSessionState({
    TrackingSession? activeSession,
    MultiDaySession? multiDaySession,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final Map<String, dynamic> sessionState = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'active_session': activeSession?.toMap(),
        'multi_day_session': multiDaySession?.toMap(),
        'additional_data': additionalData ?? {},
        'app_version': '1.0.0', // Should come from package info
        'persistence_version': 1,
      };

      // Save to SharedPreferences for quick access
      await _prefs.setString(_activeSessionKey, jsonEncode(sessionState));

      // Also save to file for more robust recovery
      await _saveSessionStateToFile(sessionState);

      // Update crash recovery data
      await _updateCrashRecoveryData(sessionState);

      debugPrint('Session state persisted successfully');
    } catch (e) {
      debugPrint('Error persisting session state: $e');
    }
  }

  /// Recover session state after app restart
  Future<SessionRecoveryResult> recoverSessionState() async {
    try {
      // Check if we need to recover from a crash
      final bool wasCrash = await _detectCrash();

      // Try to recover from SharedPreferences first
      SessionRecoveryResult? result = await _recoverFromPreferences();

      // If that fails, try to recover from file backup
      result ??= await _recoverFromFileBackup();

      // If that fails, try database recovery
      result ??= await _recoverFromDatabase();

      if (result != null) {
        result = result.copyWith(wasCrash: wasCrash);

        // Clean up recovery data after successful recovery
        await _cleanupRecoveryData();

        debugPrint('Session recovery completed: ${result.recoveryType}');
        return result;
      }

      return SessionRecoveryResult.noRecovery();
    } catch (e) {
      debugPrint('Error during session recovery: $e');
      return SessionRecoveryResult.failed(error: e.toString());
    }
  }

  /// Clear all persisted session data
  Future<void> clearPersistedData() async {
    try {
      await _prefs.remove(_activeSessionKey);
      await _prefs.remove(_multiDaySessionKey);
      await _prefs.remove(_recoveryStateKey);
      await _prefs.remove(_crashRecoveryKey);

      // Clear file backups
      await _clearSessionBackupFiles();

      debugPrint('Persisted session data cleared');
    } catch (e) {
      debugPrint('Error clearing persisted data: $e');
    }
  }

  /// Mark app as properly closed (not crashed)
  Future<void> markAppClosed() async {
    try {
      await _prefs.setInt(
          _lastAppCloseKey, DateTime.now().millisecondsSinceEpoch);
      await _prefs.remove(_crashRecoveryKey);
      debugPrint('App marked as properly closed');
    } catch (e) {
      debugPrint('Error marking app as closed: $e');
    }
  }

  /// Check if there are any sessions that need recovery
  Future<bool> hasRecoverableSession() async {
    try {
      final String? sessionData = _prefs.getString(_activeSessionKey);
      if (sessionData != null) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(jsonDecode(sessionData) as Map);
        return data['active_session'] != null ||
            data['multi_day_session'] != null;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking recoverable session: $e');
      return false;
    }
  }

  /// Get recovery statistics
  Future<RecoveryStatistics> getRecoveryStatistics() async {
    try {
      final int totalRecoveries = _prefs.getInt('total_recoveries') ?? 0;
      final int crashRecoveries = _prefs.getInt('crash_recoveries') ?? 0;
      final int lastRecoveryTime = _prefs.getInt('last_recovery_time') ?? 0;
      final String lastRecoveryType =
          _prefs.getString('last_recovery_type') ?? 'none';

      return RecoveryStatistics(
        totalRecoveries: totalRecoveries,
        crashRecoveries: crashRecoveries,
        lastRecoveryTime: lastRecoveryTime > 0
            ? DateTime.fromMillisecondsSinceEpoch(lastRecoveryTime)
            : null,
        lastRecoveryType: lastRecoveryType,
      );
    } catch (e) {
      debugPrint('Error getting recovery statistics: $e');
      return const RecoveryStatistics();
    }
  }

  /// Start periodic persistence of session state
  void _startPeriodicPersistence() {
    _persistenceTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      // This would be called by the location provider to persist current state
      // Implementation depends on how the location provider is structured
    });
  }

  /// Start recovery monitoring
  void _startRecoveryMonitoring() {
    _recoveryCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _updateRecoveryHeartbeat();
    });
  }

  /// Save session state to file for robust recovery
  Future<void> _saveSessionStateToFile(
      Map<String, dynamic> sessionState) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory backupDir =
          Directory('${appDir.path}/$_sessionBackupDir');

      if (!backupDir.existsSync()) {
        await backupDir.create(recursive: true);
      }

      final File backupFile = File('${backupDir.path}/current_session.json');
      await backupFile.writeAsString(jsonEncode(sessionState));

      // Keep a timestamped backup as well
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final File timestampedBackup =
          File('${backupDir.path}/session_$timestamp.json');
      await timestampedBackup.writeAsString(jsonEncode(sessionState));

      // Clean up old backups (keep last 10)
      await _cleanupOldBackups(backupDir);
    } catch (e) {
      debugPrint('Error saving session state to file: $e');
    }
  }

  /// Recover session state from SharedPreferences
  Future<SessionRecoveryResult?> _recoverFromPreferences() async {
    try {
      final String? sessionData = _prefs.getString(_activeSessionKey);
      if (sessionData == null) return null;

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(jsonDecode(sessionData) as Map);
      return _createRecoveryResult(data, RecoveryType.preferences);
    } catch (e) {
      debugPrint('Error recovering from preferences: $e');
      return null;
    }
  }

  /// Recover session state from file backup
  Future<SessionRecoveryResult?> _recoverFromFileBackup() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final File backupFile =
          File('${appDir.path}/$_sessionBackupDir/current_session.json');

      if (!backupFile.existsSync()) return null;

      final String content = await backupFile.readAsString();
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(jsonDecode(content) as Map);
      return _createRecoveryResult(data, RecoveryType.fileBackup);
    } catch (e) {
      debugPrint('Error recovering from file backup: $e');
      return null;
    }
  }

  /// Recover session state from database
  Future<SessionRecoveryResult?> _recoverFromDatabase() async {
    try {
      // Look for incomplete sessions in the database
      // For now, we'll skip database recovery until the method is implemented
      // final List<TrackingSession> incompleteSessions =
      //     await _databaseService.getIncompleteSessions();
      return null;
    } catch (e) {
      debugPrint('Error recovering from database: $e');
      return null;
    }
  }

  /// Create recovery result from data map
  SessionRecoveryResult _createRecoveryResult(
    Map<String, dynamic> data,
    RecoveryType recoveryType,
  ) {
    TrackingSession? activeSession;
    MultiDaySession? multiDaySession;

    if (data['active_session'] != null) {
      activeSession = TrackingSession.fromMap(
        Map<String, dynamic>.from(data['active_session'] as Map),
      );
    }

    if (data['multi_day_session'] != null) {
      multiDaySession = MultiDaySession.fromMap(
        Map<String, dynamic>.from(data['multi_day_session'] as Map),
      );
    }

    return SessionRecoveryResult(
      success: true,
      recoveryType: recoveryType,
      activeSession: activeSession,
      multiDaySession: multiDaySession,
      additionalData: Map<String, dynamic>.from(
          (data['additional_data'] ?? <String, dynamic>{}) as Map),
    );
  }

  /// Detect if the app crashed on last run
  Future<bool> _detectCrash() async {
    try {
      final int? lastCloseTime = _prefs.getInt(_lastAppCloseKey);
      final String? crashData = _prefs.getString(_crashRecoveryKey);

      // If we have crash recovery data but no proper close time, it was likely a crash
      return crashData != null && lastCloseTime == null;
    } catch (e) {
      debugPrint('Error detecting crash: $e');
      return false;
    }
  }

  /// Update crash recovery data
  Future<void> _updateCrashRecoveryData(
      Map<String, dynamic> sessionState) async {
    try {
      final Map<String, dynamic> crashData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'session_state': sessionState,
        'heartbeat': DateTime.now().millisecondsSinceEpoch,
      };

      await _prefs.setString(_crashRecoveryKey, jsonEncode(crashData));
    } catch (e) {
      debugPrint('Error updating crash recovery data: $e');
    }
  }

  /// Update recovery heartbeat
  Future<void> _updateRecoveryHeartbeat() async {
    try {
      final String? crashData = _prefs.getString(_crashRecoveryKey);
      if (crashData != null) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(jsonDecode(crashData) as Map);
        data['heartbeat'] = DateTime.now().millisecondsSinceEpoch;
        await _prefs.setString(_crashRecoveryKey, jsonEncode(data));
      }
    } catch (e) {
      debugPrint('Error updating recovery heartbeat: $e');
    }
  }

  /// Clean up recovery data after successful recovery
  Future<void> _cleanupRecoveryData() async {
    try {
      // Update recovery statistics
      final int totalRecoveries = (_prefs.getInt('total_recoveries') ?? 0) + 1;
      await _prefs.setInt('total_recoveries', totalRecoveries);
      await _prefs.setInt(
          'last_recovery_time', DateTime.now().millisecondsSinceEpoch);

      // Clear temporary recovery data
      await _prefs.remove(_recoveryStateKey);
    } catch (e) {
      debugPrint('Error cleaning up recovery data: $e');
    }
  }

  /// Clean up old backup files
  Future<void> _cleanupOldBackups(Directory backupDir) async {
    try {
      final List<FileSystemEntity> files = await backupDir.list().toList();
      final List<File> backupFiles = files
          .whereType<File>()
          .where((f) => f.path.contains('session_') && f.path.endsWith('.json'))
          .toList();

      // Sort by modification time (newest first)
      backupFiles
          .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      // Keep only the last 10 backups
      if (backupFiles.length > 10) {
        for (int i = 10; i < backupFiles.length; i++) {
          await backupFiles[i].delete();
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up old backups: $e');
    }
  }

  /// Clear all session backup files
  Future<void> _clearSessionBackupFiles() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory backupDir =
          Directory('${appDir.path}/$_sessionBackupDir');

      if (backupDir.existsSync()) {
        await backupDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing session backup files: $e');
    }
  }
}

/// Result of a session recovery operation
@immutable
class SessionRecoveryResult {
  const SessionRecoveryResult({
    required this.success,
    required this.recoveryType,
    this.activeSession,
    this.multiDaySession,
    this.additionalData = const {},
    this.wasCrash = false,
    this.error,
  });

  /// Create a result indicating no recovery was needed
  factory SessionRecoveryResult.noRecovery() => const SessionRecoveryResult(
        success: true,
        recoveryType: RecoveryType.none,
      );

  /// Create a result indicating recovery failed
  factory SessionRecoveryResult.failed({String? error}) =>
      SessionRecoveryResult(
        success: false,
        recoveryType: RecoveryType.failed,
        error: error,
      );

  /// Whether the recovery was successful
  final bool success;

  /// Type of recovery that was performed
  final RecoveryType recoveryType;

  /// Recovered active session (if any)
  final TrackingSession? activeSession;

  /// Recovered multi-day session (if any)
  final MultiDaySession? multiDaySession;

  /// Additional recovered data
  final Map<String, dynamic> additionalData;

  /// Whether the recovery was due to a crash
  final bool wasCrash;

  /// Error message if recovery failed
  final String? error;

  /// Whether any session was recovered
  bool get hasRecoveredSession =>
      activeSession != null || multiDaySession != null;

  /// Create a copy with updated values
  SessionRecoveryResult copyWith({
    bool? success,
    RecoveryType? recoveryType,
    TrackingSession? activeSession,
    MultiDaySession? multiDaySession,
    Map<String, dynamic>? additionalData,
    bool? wasCrash,
    String? error,
  }) =>
      SessionRecoveryResult(
        success: success ?? this.success,
        recoveryType: recoveryType ?? this.recoveryType,
        activeSession: activeSession ?? this.activeSession,
        multiDaySession: multiDaySession ?? this.multiDaySession,
        additionalData: additionalData ?? this.additionalData,
        wasCrash: wasCrash ?? this.wasCrash,
        error: error ?? this.error,
      );

  @override
  String toString() =>
      'SessionRecoveryResult{success: $success, type: $recoveryType, hasSession: $hasRecoveredSession, wasCrash: $wasCrash}';
}

/// Types of recovery methods
enum RecoveryType {
  none,
  preferences,
  fileBackup,
  database,
  failed,
}

/// Statistics about session recovery
@immutable
class RecoveryStatistics {
  const RecoveryStatistics({
    this.totalRecoveries = 0,
    this.crashRecoveries = 0,
    this.lastRecoveryTime,
    this.lastRecoveryType = 'none',
  });

  /// Total number of recoveries performed
  final int totalRecoveries;

  /// Number of crash recoveries
  final int crashRecoveries;

  /// Time of last recovery
  final DateTime? lastRecoveryTime;

  /// Type of last recovery
  final String lastRecoveryType;

  @override
  String toString() =>
      'RecoveryStatistics{total: $totalRecoveries, crashes: $crashRecoveries, lastType: $lastRecoveryType}';
}
