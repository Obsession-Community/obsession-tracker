import 'package:flutter/foundation.dart';

/// Configuration for session backup and recovery
@immutable
class SessionBackupConfig {
  const SessionBackupConfig({
    this.enableAutoBackup = true,
    this.backupFrequency = BackupFrequency.daily,
    this.backupLocation = BackupLocation.local,
    this.maxBackupCount = 30,
    this.compressionEnabled = true,
    this.encryptionEnabled = false,
    this.includePhotos = true,
    this.includeWaypoints = true,
    this.includeStatistics = true,
    this.backupOnSessionComplete = true,
    this.backupOnAppClose = false,
    this.wifiOnlyBackup = false,
    this.lowBatterySkip = true,
    this.batteryThreshold = 20,
  });

  factory SessionBackupConfig.fromMap(Map<String, dynamic> map) =>
      SessionBackupConfig(
        enableAutoBackup: map['enable_auto_backup'] as bool? ?? true,
        backupFrequency: BackupFrequency.values.firstWhere(
          (e) => e.name == map['backup_frequency'],
          orElse: () => BackupFrequency.daily,
        ),
        backupLocation: BackupLocation.values.firstWhere(
          (e) => e.name == map['backup_location'],
          orElse: () => BackupLocation.local,
        ),
        maxBackupCount: map['max_backup_count'] as int? ?? 30,
        compressionEnabled: map['compression_enabled'] as bool? ?? true,
        encryptionEnabled: map['encryption_enabled'] as bool? ?? false,
        includePhotos: map['include_photos'] as bool? ?? true,
        includeWaypoints: map['include_waypoints'] as bool? ?? true,
        includeStatistics: map['include_statistics'] as bool? ?? true,
        backupOnSessionComplete:
            map['backup_on_session_complete'] as bool? ?? true,
        backupOnAppClose: map['backup_on_app_close'] as bool? ?? false,
        wifiOnlyBackup: map['wifi_only_backup'] as bool? ?? false,
        lowBatterySkip: map['low_battery_skip'] as bool? ?? true,
        batteryThreshold: map['battery_threshold'] as int? ?? 20,
      );

  /// Whether automatic backup is enabled
  final bool enableAutoBackup;

  /// How frequently to perform backups
  final BackupFrequency backupFrequency;

  /// Where to store backups
  final BackupLocation backupLocation;

  /// Maximum number of backups to keep
  final int maxBackupCount;

  /// Whether to compress backup files
  final bool compressionEnabled;

  /// Whether to encrypt backup files
  final bool encryptionEnabled;

  /// Whether to include photos in backups
  final bool includePhotos;

  /// Whether to include waypoints in backups
  final bool includeWaypoints;

  /// Whether to include statistics in backups
  final bool includeStatistics;

  /// Whether to backup when a session is completed
  final bool backupOnSessionComplete;

  /// Whether to backup when the app is closed
  final bool backupOnAppClose;

  /// Whether to only backup on WiFi
  final bool wifiOnlyBackup;

  /// Whether to skip backup when battery is low
  final bool lowBatterySkip;

  /// Battery percentage threshold for skipping backup
  final int batteryThreshold;

  SessionBackupConfig copyWith({
    bool? enableAutoBackup,
    BackupFrequency? backupFrequency,
    BackupLocation? backupLocation,
    int? maxBackupCount,
    bool? compressionEnabled,
    bool? encryptionEnabled,
    bool? includePhotos,
    bool? includeWaypoints,
    bool? includeStatistics,
    bool? backupOnSessionComplete,
    bool? backupOnAppClose,
    bool? wifiOnlyBackup,
    bool? lowBatterySkip,
    int? batteryThreshold,
  }) =>
      SessionBackupConfig(
        enableAutoBackup: enableAutoBackup ?? this.enableAutoBackup,
        backupFrequency: backupFrequency ?? this.backupFrequency,
        backupLocation: backupLocation ?? this.backupLocation,
        maxBackupCount: maxBackupCount ?? this.maxBackupCount,
        compressionEnabled: compressionEnabled ?? this.compressionEnabled,
        encryptionEnabled: encryptionEnabled ?? this.encryptionEnabled,
        includePhotos: includePhotos ?? this.includePhotos,
        includeWaypoints: includeWaypoints ?? this.includeWaypoints,
        includeStatistics: includeStatistics ?? this.includeStatistics,
        backupOnSessionComplete:
            backupOnSessionComplete ?? this.backupOnSessionComplete,
        backupOnAppClose: backupOnAppClose ?? this.backupOnAppClose,
        wifiOnlyBackup: wifiOnlyBackup ?? this.wifiOnlyBackup,
        lowBatterySkip: lowBatterySkip ?? this.lowBatterySkip,
        batteryThreshold: batteryThreshold ?? this.batteryThreshold,
      );

  Map<String, dynamic> toMap() => {
        'enable_auto_backup': enableAutoBackup,
        'backup_frequency': backupFrequency.name,
        'backup_location': backupLocation.name,
        'max_backup_count': maxBackupCount,
        'compression_enabled': compressionEnabled,
        'encryption_enabled': encryptionEnabled,
        'include_photos': includePhotos,
        'include_waypoints': includeWaypoints,
        'include_statistics': includeStatistics,
        'backup_on_session_complete': backupOnSessionComplete,
        'backup_on_app_close': backupOnAppClose,
        'wifi_only_backup': wifiOnlyBackup,
        'low_battery_skip': lowBatterySkip,
        'battery_threshold': batteryThreshold,
      };
}

/// Backup frequency options
enum BackupFrequency {
  realtime,
  hourly,
  daily,
  weekly,
  manual,
}

/// Backup location options
enum BackupLocation {
  local,
  cloud,
  external,
  network,
}

/// Information about a backup
@immutable
class SessionBackup {
  const SessionBackup({
    required this.id,
    required this.createdAt,
    required this.backupType,
    required this.location,
    required this.filePath,
    required this.fileSize,
    required this.sessionCount,
    this.description,
    this.isCompressed = false,
    this.isEncrypted = false,
    this.checksum,
    this.metadata = const {},
  });

  factory SessionBackup.fromMap(Map<String, dynamic> map) => SessionBackup(
        id: map['id'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        backupType: BackupType.values.firstWhere(
          (e) => e.name == map['backup_type'],
          orElse: () => BackupType.automatic,
        ),
        location: BackupLocation.values.firstWhere(
          (e) => e.name == map['location'],
          orElse: () => BackupLocation.local,
        ),
        filePath: map['file_path'] as String,
        fileSize: map['file_size'] as int,
        sessionCount: map['session_count'] as int,
        description: map['description'] as String?,
        isCompressed: map['is_compressed'] as bool? ?? false,
        isEncrypted: map['is_encrypted'] as bool? ?? false,
        checksum: map['checksum'] as String?,
        metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      );

  /// Unique identifier for the backup
  final String id;

  /// When the backup was created
  final DateTime createdAt;

  /// Type of backup
  final BackupType backupType;

  /// Where the backup is stored
  final BackupLocation location;

  /// File path or identifier for the backup
  final String filePath;

  /// Size of the backup file in bytes
  final int fileSize;

  /// Number of sessions included in the backup
  final int sessionCount;

  /// Optional description of the backup
  final String? description;

  /// Whether the backup is compressed
  final bool isCompressed;

  /// Whether the backup is encrypted
  final bool isEncrypted;

  /// Checksum for integrity verification
  final String? checksum;

  /// Additional metadata
  final Map<String, dynamic> metadata;

  /// Get formatted file size
  String get formattedFileSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'created_at': createdAt.millisecondsSinceEpoch,
        'backup_type': backupType.name,
        'location': location.name,
        'file_path': filePath,
        'file_size': fileSize,
        'session_count': sessionCount,
        'description': description,
        'is_compressed': isCompressed,
        'is_encrypted': isEncrypted,
        'checksum': checksum,
        'metadata': metadata,
      };
}

/// Types of backups
enum BackupType {
  automatic,
  manual,
  scheduled,
  emergency,
}

/// Result of a backup operation
@immutable
class BackupResult {
  const BackupResult({
    required this.success,
    this.backup,
    this.errors = const [],
    this.warnings = const [],
    this.skippedSessions = const [],
  });

  /// Whether the backup was successful
  final bool success;

  /// The created backup (if successful)
  final SessionBackup? backup;

  /// Any errors that occurred
  final List<String> errors;

  /// Any warnings generated
  final List<String> warnings;

  /// Sessions that were skipped
  final List<String> skippedSessions;
}

/// Result of a restore operation
@immutable
class RestoreResult {
  const RestoreResult({
    required this.success,
    this.restoredSessionIds = const [],
    this.errors = const [],
    this.warnings = const [],
    this.skippedSessions = const [],
  });

  /// Whether the restore was successful
  final bool success;

  /// IDs of sessions that were restored
  final List<String> restoredSessionIds;

  /// Any errors that occurred
  final List<String> errors;

  /// Any warnings generated
  final List<String> warnings;

  /// Sessions that were skipped during restore
  final List<String> skippedSessions;
}

/// Options for restore operations
@immutable
class RestoreOptions {
  const RestoreOptions({
    this.overwriteExisting = false,
    this.restorePhotos = true,
    this.restoreWaypoints = true,
    this.restoreStatistics = true,
    this.validateIntegrity = true,
    this.createBackupBeforeRestore = true,
    this.sessionFilter,
  });

  /// Whether to overwrite existing sessions
  final bool overwriteExisting;

  /// Whether to restore photos
  final bool restorePhotos;

  /// Whether to restore waypoints
  final bool restoreWaypoints;

  /// Whether to restore statistics
  final bool restoreStatistics;

  /// Whether to validate backup integrity before restore
  final bool validateIntegrity;

  /// Whether to create a backup before restoring
  final bool createBackupBeforeRestore;

  /// Optional filter for which sessions to restore
  final bool Function(Map<String, dynamic> sessionData)? sessionFilter;
}

/// Session data validation result
@immutable
class ValidationResult {
  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.corruptedSessions = const [],
    this.missingData = const [],
  });

  /// Whether the data is valid
  final bool isValid;

  /// Validation errors
  final List<String> errors;

  /// Validation warnings
  final List<String> warnings;

  /// Sessions that appear to be corrupted
  final List<String> corruptedSessions;

  /// Types of missing data
  final List<String> missingData;
}

/// Session integrity check result
@immutable
class IntegrityCheckResult {
  const IntegrityCheckResult({
    required this.sessionId,
    required this.isValid,
    this.issues = const [],
    this.canRecover = false,
    this.recoveryActions = const [],
  });

  /// ID of the checked session
  final String sessionId;

  /// Whether the session data is valid
  final bool isValid;

  /// List of integrity issues found
  final List<IntegrityIssue> issues;

  /// Whether the session can be automatically recovered
  final bool canRecover;

  /// Suggested recovery actions
  final List<String> recoveryActions;
}

/// Types of integrity issues
@immutable
class IntegrityIssue {
  const IntegrityIssue({
    required this.type,
    required this.severity,
    required this.description,
    this.affectedData,
    this.suggestedFix,
  });

  /// Type of integrity issue
  final IntegrityIssueType type;

  /// Severity of the issue
  final IssueSeverity severity;

  /// Description of the issue
  final String description;

  /// What data is affected
  final String? affectedData;

  /// Suggested fix for the issue
  final String? suggestedFix;
}

/// Types of integrity issues
enum IntegrityIssueType {
  missingBreadcrumbs,
  invalidTimestamps,
  corruptedWaypoints,
  missingPhotos,
  invalidStatistics,
  checksumMismatch,
  incompleteSession,
  duplicateData,
}

/// Severity levels for issues
enum IssueSeverity {
  low,
  medium,
  high,
  critical,
}

/// Recovery action types
enum RecoveryAction {
  interpolateMissingData,
  removeCorruptedData,
  recalculateStatistics,
  rebuildIndex,
  mergeFragments,
  restoreFromBackup,
}
