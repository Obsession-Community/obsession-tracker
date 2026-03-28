import 'dart:convert';

/// State of the local sync operation
enum LocalSyncState {
  idle,
  preparing,
  waitingForConnection,
  connected,
  transferring,
  completed,
  failed,
  cancelled,
}

/// Role in the sync operation
enum SyncRole {
  sender,
  receiver,
}

/// Type of sync operation
enum SyncType {
  fullBackup,
  selective,
}

/// Merge strategy when receiving data
enum MergeStrategy {
  merge, // Add to existing data
  replace, // Replace all data
}

/// Session information encoded in QR code
class SyncSession {
  final String sessionId;
  final String sessionToken;
  final String senderIp;
  final int senderPort;
  final DateTime timestamp;
  final String deviceName;
  final int version;

  static const int currentVersion = 1;
  static const Duration sessionTimeout = Duration(minutes: 10);

  SyncSession({
    required this.sessionId,
    required this.sessionToken,
    required this.senderIp,
    required this.senderPort,
    required this.timestamp,
    required this.deviceName,
    this.version = currentVersion,
  });

  /// Check if session has expired
  bool get isExpired =>
      DateTime.now().difference(timestamp) > sessionTimeout;

  /// Time remaining before expiration
  Duration get timeRemaining {
    final elapsed = DateTime.now().difference(timestamp);
    final remaining = sessionTimeout - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Convert to JSON for QR code
  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'session_token': sessionToken,
        'sender_ip': senderIp,
        'sender_port': senderPort,
        'timestamp': timestamp.toIso8601String(),
        'device_name': deviceName,
        'version': version,
      };

  /// Create from JSON (scanned from QR code)
  factory SyncSession.fromJson(Map<String, dynamic> json) {
    return SyncSession(
      sessionId: json['session_id'] as String,
      sessionToken: json['session_token'] as String,
      senderIp: json['sender_ip'] as String,
      senderPort: json['sender_port'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      deviceName: json['device_name'] as String,
      version: json['version'] as int? ?? 1,
    );
  }

  /// Encode to base64 for QR code
  String toQrData() => base64Encode(utf8.encode(jsonEncode(toJson())));

  /// Decode from QR code data
  factory SyncSession.fromQrData(String qrData) {
    final json = jsonDecode(utf8.decode(base64Decode(qrData)));
    return SyncSession.fromJson(json as Map<String, dynamic>);
  }
}

/// Information about the sender device and backup
class SyncInfo {
  final String deviceName;
  final String platform;
  final int totalSessions;
  final int totalHunts;
  final int totalRoutes;
  final int totalWaypoints;
  final int backupSizeBytes;
  final String appVersion;

  SyncInfo({
    required this.deviceName,
    required this.platform,
    required this.totalSessions,
    required this.totalHunts,
    required this.totalRoutes,
    required this.totalWaypoints,
    required this.backupSizeBytes,
    required this.appVersion,
  });

  String get formattedSize {
    if (backupSizeBytes < 1024) {
      return '$backupSizeBytes B';
    } else if (backupSizeBytes < 1024 * 1024) {
      return '${(backupSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(backupSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  Map<String, dynamic> toJson() => {
        'device_name': deviceName,
        'platform': platform,
        'total_sessions': totalSessions,
        'total_hunts': totalHunts,
        'total_routes': totalRoutes,
        'total_waypoints': totalWaypoints,
        'backup_size_bytes': backupSizeBytes,
        'app_version': appVersion,
      };

  factory SyncInfo.fromJson(Map<String, dynamic> json) {
    return SyncInfo(
      deviceName: json['device_name'] as String,
      platform: json['platform'] as String,
      totalSessions: json['total_sessions'] as int,
      totalHunts: json['total_hunts'] as int,
      totalRoutes: json['total_routes'] as int,
      totalWaypoints: json['total_waypoints'] as int,
      backupSizeBytes: json['backup_size_bytes'] as int,
      appVersion: json['app_version'] as String,
    );
  }
}

/// Manifest of items available for selective sync
class SyncManifest {
  final List<SyncSessionItem> sessions;
  final List<SyncHuntItem> hunts;
  final List<SyncRouteItem> routes;

  SyncManifest({
    required this.sessions,
    required this.hunts,
    required this.routes,
  });

  Map<String, dynamic> toJson() => {
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'hunts': hunts.map((h) => h.toJson()).toList(),
        'routes': routes.map((r) => r.toJson()).toList(),
      };

  factory SyncManifest.fromJson(Map<String, dynamic> json) {
    return SyncManifest(
      sessions: (json['sessions'] as List)
          .map((s) => SyncSessionItem.fromJson(s as Map<String, dynamic>))
          .toList(),
      hunts: (json['hunts'] as List)
          .map((h) => SyncHuntItem.fromJson(h as Map<String, dynamic>))
          .toList(),
      routes: (json['routes'] as List)
          .map((r) => SyncRouteItem.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Session item in manifest
class SyncSessionItem {
  final String id;
  final String name;
  final DateTime createdAt;
  final int waypointCount;
  final int breadcrumbCount;
  final double? distanceMeters;

  SyncSessionItem({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.waypointCount,
    required this.breadcrumbCount,
    this.distanceMeters,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'waypoint_count': waypointCount,
        'breadcrumb_count': breadcrumbCount,
        'distance_meters': distanceMeters,
      };

  factory SyncSessionItem.fromJson(Map<String, dynamic> json) {
    return SyncSessionItem(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      waypointCount: json['waypoint_count'] as int,
      breadcrumbCount: json['breadcrumb_count'] as int,
      distanceMeters: json['distance_meters'] as double?,
    );
  }
}

/// Hunt item in manifest
class SyncHuntItem {
  final String id;
  final String name;
  final DateTime createdAt;
  final int clueCount;

  SyncHuntItem({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.clueCount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'clue_count': clueCount,
      };

  factory SyncHuntItem.fromJson(Map<String, dynamic> json) {
    return SyncHuntItem(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      clueCount: json['clue_count'] as int,
    );
  }
}

/// Route item in manifest
class SyncRouteItem {
  final String id;
  final String name;
  final DateTime importedAt;
  final int pointCount;
  final double? totalDistance;

  SyncRouteItem({
    required this.id,
    required this.name,
    required this.importedAt,
    required this.pointCount,
    this.totalDistance,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imported_at': importedAt.toIso8601String(),
        'point_count': pointCount,
        'total_distance': totalDistance,
      };

  factory SyncRouteItem.fromJson(Map<String, dynamic> json) {
    return SyncRouteItem(
      id: json['id'] as String,
      name: json['name'] as String,
      importedAt: DateTime.parse(json['imported_at'] as String),
      pointCount: json['point_count'] as int,
      totalDistance: json['total_distance'] as double?,
    );
  }
}

/// Request to start a selective transfer
///
/// For sender-side selection, the lists can be null (meaning "include all" of that type)
/// or a specific list of IDs (meaning "include only these").
/// Password is only required for receiver-side requests.
class SelectiveSyncRequest {
  /// Session IDs to include (null = all sessions)
  final List<String>? sessionIds;

  /// Hunt IDs to include (null = all hunts)
  final List<String>? huntIds;

  /// Route IDs to include (null = all routes)
  final List<String>? routeIds;

  /// Password for decryption (only needed for receiver requests)
  final String? password;

  SelectiveSyncRequest({
    this.sessionIds,
    this.huntIds,
    this.routeIds,
    this.password,
  });

  /// Whether this is a selective request (any filter specified)
  bool get isSelective =>
      sessionIds != null || huntIds != null || routeIds != null;

  Map<String, dynamic> toJson() => {
        if (sessionIds != null) 'session_ids': sessionIds,
        if (huntIds != null) 'hunt_ids': huntIds,
        if (routeIds != null) 'route_ids': routeIds,
        if (password != null) 'password': password,
      };

  factory SelectiveSyncRequest.fromJson(Map<String, dynamic> json) {
    return SelectiveSyncRequest(
      sessionIds: json['session_ids'] != null
          ? (json['session_ids'] as List).cast<String>()
          : null,
      huntIds: json['hunt_ids'] != null
          ? (json['hunt_ids'] as List).cast<String>()
          : null,
      routeIds: json['route_ids'] != null
          ? (json['route_ids'] as List).cast<String>()
          : null,
      password: json['password'] as String?,
    );
  }
}

/// Progress of a sync transfer
class SyncProgress {
  final int bytesTransferred;
  final int totalBytes;
  final String? currentItem;
  final int itemsCompleted;
  final int totalItems;

  SyncProgress({
    required this.bytesTransferred,
    required this.totalBytes,
    this.currentItem,
    this.itemsCompleted = 0,
    this.totalItems = 1,
  });

  double get progress => totalBytes > 0 ? bytesTransferred / totalBytes : 0.0;

  String get formattedProgress {
    final percent = (progress * 100).toStringAsFixed(1);
    return '$percent%';
  }

  String get formattedBytes {
    String format(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${format(bytesTransferred)} / ${format(totalBytes)}';
  }

  SyncProgress copyWith({
    int? bytesTransferred,
    int? totalBytes,
    String? currentItem,
    int? itemsCompleted,
    int? totalItems,
  }) {
    return SyncProgress(
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      currentItem: currentItem ?? this.currentItem,
      itemsCompleted: itemsCompleted ?? this.itemsCompleted,
      totalItems: totalItems ?? this.totalItems,
    );
  }
}

/// Result of a completed sync
class SyncResult {
  final bool success;
  final String? error;
  final int sessionsTransferred;
  final int huntsTransferred;
  final int routesTransferred;
  final int waypointsTransferred;
  // Skipped counts (items that already existed in merge mode)
  final int sessionsSkipped;
  final int huntsSkipped;
  final int routesSkipped;
  final Duration duration;

  SyncResult({
    required this.success,
    this.error,
    this.sessionsTransferred = 0,
    this.huntsTransferred = 0,
    this.routesTransferred = 0,
    this.waypointsTransferred = 0,
    this.sessionsSkipped = 0,
    this.huntsSkipped = 0,
    this.routesSkipped = 0,
    required this.duration,
  });

  /// Whether any items were skipped (already existed)
  bool get hasSkippedItems =>
      sessionsSkipped > 0 || huntsSkipped > 0 || routesSkipped > 0;

  /// Total items imported
  int get totalImported =>
      sessionsTransferred + huntsTransferred + routesTransferred;

  /// Total items skipped
  int get totalSkipped => sessionsSkipped + huntsSkipped + routesSkipped;

  factory SyncResult.success({
    required int sessionsTransferred,
    required int huntsTransferred,
    required int routesTransferred,
    required int waypointsTransferred,
    int sessionsSkipped = 0,
    int huntsSkipped = 0,
    int routesSkipped = 0,
    required Duration duration,
  }) {
    return SyncResult(
      success: true,
      sessionsTransferred: sessionsTransferred,
      huntsTransferred: huntsTransferred,
      routesTransferred: routesTransferred,
      waypointsTransferred: waypointsTransferred,
      sessionsSkipped: sessionsSkipped,
      huntsSkipped: huntsSkipped,
      routesSkipped: routesSkipped,
      duration: duration,
    );
  }

  factory SyncResult.failure(String error, Duration duration) {
    return SyncResult(
      success: false,
      error: error,
      duration: duration,
    );
  }
}

/// Error types for sync operations
enum SyncErrorType {
  networkError,
  sessionExpired,
  authenticationFailed,
  transferInterrupted,
  decryptionFailed,
  insufficientStorage,
  versionMismatch,
  unknown,
}

/// Exception for sync operations
class LocalSyncException implements Exception {
  final String message;
  final SyncErrorType type;

  const LocalSyncException(this.message, this.type);

  @override
  String toString() => 'LocalSyncException: $message (type: $type)';

  /// Get user-friendly error message
  String get userMessage {
    switch (type) {
      case SyncErrorType.networkError:
        return 'Connection failed. Make sure both devices are on the same WiFi network.';
      case SyncErrorType.sessionExpired:
        return 'Session expired. Please generate a new QR code.';
      case SyncErrorType.authenticationFailed:
        return 'Authentication failed. Please try again.';
      case SyncErrorType.transferInterrupted:
        return 'Transfer was interrupted. Please try again.';
      case SyncErrorType.decryptionFailed:
        return 'Incorrect password. Please check and try again.';
      case SyncErrorType.insufficientStorage:
        return 'Not enough storage space. Please free up some space and try again.';
      case SyncErrorType.versionMismatch:
        return 'App version mismatch. Please update both devices to the latest version.';
      case SyncErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}
