import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// History entry for waypoint changes and versioning
@immutable
class WaypointHistoryEntry {
  const WaypointHistoryEntry({
    required this.id,
    required this.waypointId,
    required this.version,
    required this.changeType,
    required this.timestamp,
    required this.userId,
    required this.changes,
    this.previousVersion,
    this.description,
    this.deviceInfo,
    this.sessionId,
  });

  /// Create history entry from database map
  factory WaypointHistoryEntry.fromMap(Map<String, dynamic> map) =>
      WaypointHistoryEntry(
        id: map['id'] as String,
        waypointId: map['waypoint_id'] as String,
        version: map['version'] as int,
        changeType: WaypointChangeType.values.firstWhere(
          (type) => type.name == map['change_type'],
          orElse: () => WaypointChangeType.updated,
        ),
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        userId: map['user_id'] as String,
        changes: Map<String, dynamic>.from(map['changes'] as Map),
        previousVersion: map['previous_version'] as int?,
        description: map['description'] as String?,
        deviceInfo: map['device_info'] as String?,
        sessionId: map['session_id'] as String?,
      );

  /// Unique identifier for this history entry
  final String id;

  /// ID of the waypoint this history belongs to
  final String waypointId;

  /// Version number of the waypoint after this change
  final int version;

  /// Type of change that occurred
  final WaypointChangeType changeType;

  /// When this change occurred
  final DateTime timestamp;

  /// ID of the user who made the change
  final String userId;

  /// Details of what changed (field -> {old, new} values)
  final Map<String, dynamic> changes;

  /// Previous version number (if applicable)
  final int? previousVersion;

  /// Optional description of the change
  final String? description;

  /// Device information where change was made
  final String? deviceInfo;

  /// Session ID when change was made (if applicable)
  final String? sessionId;

  /// Convert to map for database storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'waypoint_id': waypointId,
        'version': version,
        'change_type': changeType.name,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'user_id': userId,
        'changes': changes,
        'previous_version': previousVersion,
        'description': description,
        'device_info': deviceInfo,
        'session_id': sessionId,
      };

  /// Get a summary of changes for display
  String get changeSummary {
    final List<String> summaryParts = <String>[];

    for (final MapEntry<String, dynamic> entry in changes.entries) {
      final String field = entry.key;
      final Map<String, dynamic> change = entry.value as Map<String, dynamic>;
      final dynamic oldValue = change['old'];
      final dynamic newValue = change['new'];

      if (oldValue == null && newValue != null) {
        summaryParts.add('Added $field');
      } else if (oldValue != null && newValue == null) {
        summaryParts.add('Removed $field');
      } else if (oldValue != newValue) {
        summaryParts.add('Changed $field');
      }
    }

    return summaryParts.isEmpty ? 'No changes' : summaryParts.join(', ');
  }

  /// Create a copy with updated values
  WaypointHistoryEntry copyWith({
    String? id,
    String? waypointId,
    int? version,
    WaypointChangeType? changeType,
    DateTime? timestamp,
    String? userId,
    Map<String, dynamic>? changes,
    int? previousVersion,
    String? description,
    String? deviceInfo,
    String? sessionId,
  }) =>
      WaypointHistoryEntry(
        id: id ?? this.id,
        waypointId: waypointId ?? this.waypointId,
        version: version ?? this.version,
        changeType: changeType ?? this.changeType,
        timestamp: timestamp ?? this.timestamp,
        userId: userId ?? this.userId,
        changes: changes ?? this.changes,
        previousVersion: previousVersion ?? this.previousVersion,
        description: description ?? this.description,
        deviceInfo: deviceInfo ?? this.deviceInfo,
        sessionId: sessionId ?? this.sessionId,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaypointHistoryEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'WaypointHistoryEntry{id: $id, waypointId: $waypointId, version: $version, changeType: $changeType}';
}

/// Types of changes that can occur to waypoints
enum WaypointChangeType {
  created,
  updated,
  deleted,
  restored,
  moved,
  merged,
  split,
  imported,
  exported,
  shared,
  archived,
}

/// Extension for waypoint change types
extension WaypointChangeTypeExtension on WaypointChangeType {
  /// Display name for the change type
  String get displayName {
    switch (this) {
      case WaypointChangeType.created:
        return 'Created';
      case WaypointChangeType.updated:
        return 'Updated';
      case WaypointChangeType.deleted:
        return 'Deleted';
      case WaypointChangeType.restored:
        return 'Restored';
      case WaypointChangeType.moved:
        return 'Moved';
      case WaypointChangeType.merged:
        return 'Merged';
      case WaypointChangeType.split:
        return 'Split';
      case WaypointChangeType.imported:
        return 'Imported';
      case WaypointChangeType.exported:
        return 'Exported';
      case WaypointChangeType.shared:
        return 'Shared';
      case WaypointChangeType.archived:
        return 'Archived';
    }
  }

  /// Whether this change type represents a destructive action
  bool get isDestructive {
    switch (this) {
      case WaypointChangeType.deleted:
      case WaypointChangeType.archived:
        return true;
      default:
        return false;
    }
  }

  /// Whether this change type can be undone
  bool get canUndo {
    switch (this) {
      case WaypointChangeType.updated:
      case WaypointChangeType.moved:
      case WaypointChangeType.deleted:
      case WaypointChangeType.archived:
        return true;
      default:
        return false;
    }
  }
}

/// Snapshot of a waypoint at a specific version
@immutable
class WaypointSnapshot {
  const WaypointSnapshot({
    required this.id,
    required this.waypointId,
    required this.version,
    required this.timestamp,
    required this.data,
    required this.userId,
    this.description,
    this.isAutoSnapshot = false,
  });

  /// Create snapshot from database map
  factory WaypointSnapshot.fromMap(Map<String, dynamic> map) =>
      WaypointSnapshot(
        id: map['id'] as String,
        waypointId: map['waypoint_id'] as String,
        version: map['version'] as int,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        data: Map<String, dynamic>.from(map['data'] as Map),
        userId: map['user_id'] as String,
        description: map['description'] as String?,
        isAutoSnapshot: (map['is_auto_snapshot'] as int?) == 1,
      );

  /// Unique identifier for this snapshot
  final String id;

  /// ID of the waypoint this snapshot belongs to
  final String waypointId;

  /// Version number of this snapshot
  final int version;

  /// When this snapshot was created
  final DateTime timestamp;

  /// Complete waypoint data at this version
  final Map<String, dynamic> data;

  /// ID of the user who created this snapshot
  final String userId;

  /// Optional description of the snapshot
  final String? description;

  /// Whether this was an automatically created snapshot
  final bool isAutoSnapshot;

  /// Convert to map for database storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'waypoint_id': waypointId,
        'version': version,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'data': data,
        'user_id': userId,
        'description': description,
        'is_auto_snapshot': isAutoSnapshot ? 1 : 0,
      };

  /// Get the waypoint coordinates from the snapshot data
  LatLng? get coordinates {
    final double? lat = data['latitude'] as double?;
    final double? lng = data['longitude'] as double?;
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return null;
  }

  /// Get the waypoint name from the snapshot data
  String? get name => data['name'] as String? ?? data['custom_name'] as String?;

  /// Get the waypoint type from the snapshot data
  String? get type => data['type'] as String?;

  /// Create a copy with updated values
  WaypointSnapshot copyWith({
    String? id,
    String? waypointId,
    int? version,
    DateTime? timestamp,
    Map<String, dynamic>? data,
    String? userId,
    String? description,
    bool? isAutoSnapshot,
  }) =>
      WaypointSnapshot(
        id: id ?? this.id,
        waypointId: waypointId ?? this.waypointId,
        version: version ?? this.version,
        timestamp: timestamp ?? this.timestamp,
        data: data ?? this.data,
        userId: userId ?? this.userId,
        description: description ?? this.description,
        isAutoSnapshot: isAutoSnapshot ?? this.isAutoSnapshot,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaypointSnapshot &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'WaypointSnapshot{id: $id, waypointId: $waypointId, version: $version}';
}

/// Configuration for waypoint versioning behavior
@immutable
class WaypointVersioningConfig {
  const WaypointVersioningConfig({
    this.enableAutoSnapshots = true,
    this.maxVersionsToKeep = 50,
    this.snapshotInterval = const Duration(hours: 1),
    this.enableChangeTracking = true,
    this.trackLocationChanges = true,
    this.trackMetadataChanges = true,
    this.trackRelationshipChanges = true,
    this.compressOldSnapshots = true,
    this.retentionPeriod = const Duration(days: 365),
  });

  /// Whether to automatically create snapshots
  final bool enableAutoSnapshots;

  /// Maximum number of versions to keep per waypoint
  final int maxVersionsToKeep;

  /// Minimum interval between automatic snapshots
  final Duration snapshotInterval;

  /// Whether to track detailed changes
  final bool enableChangeTracking;

  /// Whether to track location coordinate changes
  final bool trackLocationChanges;

  /// Whether to track metadata changes
  final bool trackMetadataChanges;

  /// Whether to track relationship changes
  final bool trackRelationshipChanges;

  /// Whether to compress old snapshots to save space
  final bool compressOldSnapshots;

  /// How long to retain version history
  final Duration retentionPeriod;

  /// Create a copy with updated values
  WaypointVersioningConfig copyWith({
    bool? enableAutoSnapshots,
    int? maxVersionsToKeep,
    Duration? snapshotInterval,
    bool? enableChangeTracking,
    bool? trackLocationChanges,
    bool? trackMetadataChanges,
    bool? trackRelationshipChanges,
    bool? compressOldSnapshots,
    Duration? retentionPeriod,
  }) =>
      WaypointVersioningConfig(
        enableAutoSnapshots: enableAutoSnapshots ?? this.enableAutoSnapshots,
        maxVersionsToKeep: maxVersionsToKeep ?? this.maxVersionsToKeep,
        snapshotInterval: snapshotInterval ?? this.snapshotInterval,
        enableChangeTracking: enableChangeTracking ?? this.enableChangeTracking,
        trackLocationChanges: trackLocationChanges ?? this.trackLocationChanges,
        trackMetadataChanges: trackMetadataChanges ?? this.trackMetadataChanges,
        trackRelationshipChanges:
            trackRelationshipChanges ?? this.trackRelationshipChanges,
        compressOldSnapshots: compressOldSnapshots ?? this.compressOldSnapshots,
        retentionPeriod: retentionPeriod ?? this.retentionPeriod,
      );

  @override
  String toString() =>
      'WaypointVersioningConfig{autoSnapshots: $enableAutoSnapshots, maxVersions: $maxVersionsToKeep}';
}
