import 'package:flutter/foundation.dart';

/// Device information for sync operations
@immutable
class SyncDevice {
  const SyncDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.lastSyncAt,
    this.isCurrentDevice = false,
    this.isOnline = false,
    this.syncEnabled = true,
    this.encryptionKeyId,
    this.metadata = const {},
  });

  factory SyncDevice.fromMap(Map<String, dynamic> map) => SyncDevice(
        id: map['id'] as String,
        name: map['name'] as String,
        type: DeviceType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => DeviceType.mobile,
        ),
        lastSyncAt:
            DateTime.fromMillisecondsSinceEpoch(map['last_sync_at'] as int),
        isCurrentDevice: map['is_current_device'] as bool? ?? false,
        isOnline: map['is_online'] as bool? ?? false,
        syncEnabled: map['sync_enabled'] as bool? ?? true,
        encryptionKeyId: map['encryption_key_id'] as String?,
        metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      );

  final String id;
  final String name;
  final DeviceType type;
  final DateTime lastSyncAt;
  final bool isCurrentDevice;
  final bool isOnline;
  final bool syncEnabled;
  final String? encryptionKeyId;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'last_sync_at': lastSyncAt.millisecondsSinceEpoch,
        'is_current_device': isCurrentDevice,
        'is_online': isOnline,
        'sync_enabled': syncEnabled,
        'encryption_key_id': encryptionKeyId,
        'metadata': metadata,
      };

  SyncDevice copyWith({
    String? id,
    String? name,
    DeviceType? type,
    DateTime? lastSyncAt,
    bool? isCurrentDevice,
    bool? isOnline,
    bool? syncEnabled,
    String? encryptionKeyId,
    Map<String, dynamic>? metadata,
  }) =>
      SyncDevice(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
        isOnline: isOnline ?? this.isOnline,
        syncEnabled: syncEnabled ?? this.syncEnabled,
        encryptionKeyId: encryptionKeyId ?? this.encryptionKeyId,
        metadata: metadata ?? this.metadata,
      );
}

/// Device types for sync
enum DeviceType {
  mobile,
  tablet,
  desktop,
  web,
}

/// Sync operation record
@immutable
class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.deviceId,
    this.completedAt,
    this.dataType,
    this.recordId,
    this.conflictResolution,
    this.errorMessage,
    this.metadata = const {},
  });

  factory SyncOperation.fromMap(Map<String, dynamic> map) => SyncOperation(
        id: map['id'] as String,
        type: SyncOperationType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => SyncOperationType.upload,
        ),
        status: SyncStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => SyncStatus.pending,
        ),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        deviceId: map['device_id'] as String,
        completedAt: map['completed_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
            : null,
        dataType: map['data_type'] as String?,
        recordId: map['record_id'] as String?,
        conflictResolution: map['conflict_resolution'] != null
            ? ConflictResolution.values.firstWhere(
                (e) => e.name == map['conflict_resolution'],
                orElse: () => ConflictResolution.manual,
              )
            : null,
        errorMessage: map['error_message'] as String?,
        metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      );

  final String id;
  final SyncOperationType type;
  final SyncStatus status;
  final DateTime createdAt;
  final String deviceId;
  final DateTime? completedAt;
  final String? dataType;
  final String? recordId;
  final ConflictResolution? conflictResolution;
  final String? errorMessage;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'status': status.name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'device_id': deviceId,
        'completed_at': completedAt?.millisecondsSinceEpoch,
        'data_type': dataType,
        'record_id': recordId,
        'conflict_resolution': conflictResolution?.name,
        'error_message': errorMessage,
        'metadata': metadata,
      };
}

/// Types of sync operations
enum SyncOperationType {
  upload,
  download,
  delete,
  merge,
  conflict,
}

/// Sync operation status
enum SyncStatus {
  pending,
  inProgress,
  completed,
  failed,
  cancelled,
  conflict,
}

/// Conflict resolution strategies
enum ConflictResolution {
  manual,
  localWins,
  remoteWins,
  merge,
  keepBoth,
}

/// Sync configuration
@immutable
class SyncConfiguration {
  const SyncConfiguration({
    this.enableAutoSync = true,
    this.syncFrequency = SyncFrequency.realtime,
    this.wifiOnlySync = false,
    this.enableEncryption = true,
    this.conflictResolution = ConflictResolution.manual,
    this.syncSessions = true,
    this.syncWaypoints = true,
    this.syncPhotos = true,
    this.syncSettings = false,
    this.maxRetryAttempts = 3,
    this.syncTimeoutSeconds = 30,
    this.batchSize = 10,
  });

  factory SyncConfiguration.fromMap(Map<String, dynamic> map) =>
      SyncConfiguration(
        enableAutoSync: map['enable_auto_sync'] as bool? ?? true,
        syncFrequency: SyncFrequency.values.firstWhere(
          (e) => e.name == map['sync_frequency'],
          orElse: () => SyncFrequency.realtime,
        ),
        wifiOnlySync: map['wifi_only_sync'] as bool? ?? false,
        enableEncryption: map['enable_encryption'] as bool? ?? true,
        conflictResolution: ConflictResolution.values.firstWhere(
          (e) => e.name == map['conflict_resolution'],
          orElse: () => ConflictResolution.manual,
        ),
        syncSessions: map['sync_sessions'] as bool? ?? true,
        syncWaypoints: map['sync_waypoints'] as bool? ?? true,
        syncPhotos: map['sync_photos'] as bool? ?? true,
        syncSettings: map['sync_settings'] as bool? ?? false,
        maxRetryAttempts: map['max_retry_attempts'] as int? ?? 3,
        syncTimeoutSeconds: map['sync_timeout_seconds'] as int? ?? 30,
        batchSize: map['batch_size'] as int? ?? 10,
      );

  final bool enableAutoSync;
  final SyncFrequency syncFrequency;
  final bool wifiOnlySync;
  final bool enableEncryption;
  final ConflictResolution conflictResolution;
  final bool syncSessions;
  final bool syncWaypoints;
  final bool syncPhotos;
  final bool syncSettings;
  final int maxRetryAttempts;
  final int syncTimeoutSeconds;
  final int batchSize;

  Map<String, dynamic> toMap() => {
        'enable_auto_sync': enableAutoSync,
        'sync_frequency': syncFrequency.name,
        'wifi_only_sync': wifiOnlySync,
        'enable_encryption': enableEncryption,
        'conflict_resolution': conflictResolution.name,
        'sync_sessions': syncSessions,
        'sync_waypoints': syncWaypoints,
        'sync_photos': syncPhotos,
        'sync_settings': syncSettings,
        'max_retry_attempts': maxRetryAttempts,
        'sync_timeout_seconds': syncTimeoutSeconds,
        'batch_size': batchSize,
      };

  SyncConfiguration copyWith({
    bool? enableAutoSync,
    SyncFrequency? syncFrequency,
    bool? wifiOnlySync,
    bool? enableEncryption,
    ConflictResolution? conflictResolution,
    bool? syncSessions,
    bool? syncWaypoints,
    bool? syncPhotos,
    bool? syncSettings,
    int? maxRetryAttempts,
    int? syncTimeoutSeconds,
    int? batchSize,
  }) =>
      SyncConfiguration(
        enableAutoSync: enableAutoSync ?? this.enableAutoSync,
        syncFrequency: syncFrequency ?? this.syncFrequency,
        wifiOnlySync: wifiOnlySync ?? this.wifiOnlySync,
        enableEncryption: enableEncryption ?? this.enableEncryption,
        conflictResolution: conflictResolution ?? this.conflictResolution,
        syncSessions: syncSessions ?? this.syncSessions,
        syncWaypoints: syncWaypoints ?? this.syncWaypoints,
        syncPhotos: syncPhotos ?? this.syncPhotos,
        syncSettings: syncSettings ?? this.syncSettings,
        maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
        syncTimeoutSeconds: syncTimeoutSeconds ?? this.syncTimeoutSeconds,
        batchSize: batchSize ?? this.batchSize,
      );
}

/// Sync frequency options
enum SyncFrequency {
  realtime,
  every5Minutes,
  every15Minutes,
  hourly,
  daily,
  manual,
}

/// Sync conflict information
@immutable
class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.dataType,
    required this.recordId,
    required this.localData,
    required this.remoteData,
    required this.createdAt,
    this.resolvedAt,
    this.resolution,
    this.resolvedData,
  });

  factory SyncConflict.fromMap(Map<String, dynamic> map) => SyncConflict(
        id: map['id'] as String,
        dataType: map['data_type'] as String,
        recordId: map['record_id'] as String,
        localData: Map<String, dynamic>.from(map['local_data'] as Map),
        remoteData: Map<String, dynamic>.from(map['remote_data'] as Map),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        resolvedAt: map['resolved_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['resolved_at'] as int)
            : null,
        resolution: map['resolution'] != null
            ? ConflictResolution.values.firstWhere(
                (e) => e.name == map['resolution'],
                orElse: () => ConflictResolution.manual,
              )
            : null,
        resolvedData: map['resolved_data'] != null
            ? Map<String, dynamic>.from(map['resolved_data'] as Map)
            : null,
      );

  final String id;
  final String dataType;
  final String recordId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final ConflictResolution? resolution;
  final Map<String, dynamic>? resolvedData;

  bool get isResolved => resolvedAt != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'data_type': dataType,
        'record_id': recordId,
        'local_data': localData,
        'remote_data': remoteData,
        'created_at': createdAt.millisecondsSinceEpoch,
        'resolved_at': resolvedAt?.millisecondsSinceEpoch,
        'resolution': resolution?.name,
        'resolved_data': resolvedData,
      };
}

/// Sync statistics
@immutable
class SyncStatistics {
  const SyncStatistics({
    this.totalOperations = 0,
    this.successfulOperations = 0,
    this.failedOperations = 0,
    this.conflictOperations = 0,
    this.lastSyncAt,
    this.totalDataSynced = 0,
    this.averageSyncTime = 0,
    this.deviceCount = 0,
  });

  final int totalOperations;
  final int successfulOperations;
  final int failedOperations;
  final int conflictOperations;
  final DateTime? lastSyncAt;
  final int totalDataSynced;
  final double averageSyncTime;
  final int deviceCount;

  double get successRate =>
      totalOperations > 0 ? successfulOperations / totalOperations : 0.0;

  double get conflictRate =>
      totalOperations > 0 ? conflictOperations / totalOperations : 0.0;
}
