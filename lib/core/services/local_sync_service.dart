import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/local_sync_models.dart';
import 'package:obsession_tracker/core/services/app_backup_service.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/device_discovery_service.dart';
import 'package:obsession_tracker/core/services/local_http_server.dart';
import 'package:obsession_tracker/core/services/sync_session_manager.dart';
import 'package:path_provider/path_provider.dart';

/// Main service for local WiFi sync between devices
///
/// ## Sender Flow (startSendSession):
/// 1. Create sync session with QR code data
/// 2. Start local HTTP server
/// 3. Wait for receiver to connect and authenticate
/// 4. Stream backup data to receiver
/// 5. Clean up and report result
///
/// ## Receiver Flow (connectToSender):
/// 1. Parse QR code to get session info
/// 2. Authenticate with sender's server
/// 3. Get sync info and manifest
/// 4. Download backup file
/// 5. Restore data and report result
class LocalSyncService {
  factory LocalSyncService() => _instance;
  LocalSyncService._();

  static final LocalSyncService _instance = LocalSyncService._();

  final SyncSessionManager _sessionManager = SyncSessionManager();
  final LocalHttpServer _httpServer = LocalHttpServer();
  final DeviceDiscoveryService _discoveryService = DeviceDiscoveryService();
  final AppBackupService _backupService = AppBackupService();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(minutes: 5),
    sendTimeout: const Duration(minutes: 5),
  ));

  // Current state
  LocalSyncState _state = LocalSyncState.idle;
  SyncRole? _currentRole;
  SyncSession? _remoteSession;
  DateTime? _startTime;

  // Callbacks
  void Function(LocalSyncState state)? onStateChange;
  void Function(SyncProgress progress)? onProgress;
  void Function(SyncResult result)? onComplete;
  void Function(List<DiscoveredDevice> devices)? onDevicesChanged;
  void Function(UnresolvedDevice device)? onUnresolvedDevice;

  /// Current sync state
  LocalSyncState get state => _state;

  /// Current role (sender/receiver)
  SyncRole? get currentRole => _currentRole;

  /// Whether a sync operation is in progress
  bool get isSyncing => _state != LocalSyncState.idle;

  /// Get the current session for QR code display
  SyncSession? get currentSession => _sessionManager.currentSession;

  /// Get discovered devices (for receiver)
  List<DiscoveredDevice> get discoveredDevices => _discoveryService.discoveredDevices;

  /// Whether discovery is active
  bool get isDiscovering => _discoveryService.isDiscovering;

  // ============================================================
  // Sender Flow
  // ============================================================

  /// Start a new send session
  ///
  /// [password] - Password for encrypting the backup
  /// [syncType] - Full backup or selective sync
  /// [selection] - Optional selective sync request (only for selective sync)
  ///
  /// Returns the QR code data string to display
  Future<String> startSendSession({
    required String password,
    SyncType syncType = SyncType.fullBackup,
    SelectiveSyncRequest? selection,
  }) async {
    if (isSyncing) {
      throw const LocalSyncException(
        'A sync operation is already in progress',
        SyncErrorType.unknown,
      );
    }

    try {
      _setState(LocalSyncState.preparing);
      _currentRole = SyncRole.sender;
      _startTime = DateTime.now();

      // Create the session
      final session = await _sessionManager.createSession();

      // Start the HTTP server with selection (for selective sync)
      await _httpServer.start(
        transferPassword: password,
        selection: selection,
      );

      // Set up callbacks
      _httpServer.onProgress = (progress) {
        onProgress?.call(progress);
      };

      _httpServer.onReceiverConnected = () {
        debugPrint('LocalSyncService: Receiver connected, starting transfer');
        _setState(LocalSyncState.transferring);
      };

      _httpServer.onTransferComplete = (
        success,
        error,
        sessions,
        hunts,
        routes,
        sessionsSkipped,
        huntsSkipped,
        routesSkipped,
      ) {
        if (success) {
          _complete(SyncResult.success(
            sessionsTransferred: sessions,
            huntsTransferred: hunts,
            routesTransferred: routes,
            waypointsTransferred: 0,
            sessionsSkipped: sessionsSkipped,
            huntsSkipped: huntsSkipped,
            routesSkipped: routesSkipped,
            duration: DateTime.now().difference(_startTime!),
          ));
        } else {
          _complete(SyncResult.failure(
            error ?? 'Transfer failed',
            DateTime.now().difference(_startTime!),
          ));
        }
      };

      // Start mDNS advertising so other devices can discover us
      await _discoveryService.startAdvertising(
        deviceName: session.deviceName,
        port: _httpServer.port ?? SyncSessionManager.defaultPort,
        sessionId: session.sessionId,
        sessionToken: session.sessionToken,
      );

      _setState(LocalSyncState.waitingForConnection);

      // Return QR code data (as fallback)
      return session.toQrData();
    } catch (e) {
      await cancelSync();
      if (e is LocalSyncException) rethrow;
      throw LocalSyncException(
        'Failed to start send session: $e',
        SyncErrorType.unknown,
      );
    }
  }

  /// Get time remaining for current session (sender only)
  Duration? getSessionTimeRemaining() {
    return _sessionManager.getTimeRemaining();
  }

  // ============================================================
  // Receiver Flow
  // ============================================================

  /// Start discovering nearby devices
  Future<void> startDiscovery() async {
    if (isSyncing) {
      throw const LocalSyncException(
        'A sync operation is already in progress',
        SyncErrorType.unknown,
      );
    }

    _currentRole = SyncRole.receiver;

    // Set up callback to forward device changes
    _discoveryService.onDevicesChanged = (devices) {
      onDevicesChanged?.call(devices);
    };

    // Set up callback for unresolved devices (suggests QR code fallback)
    _discoveryService.onUnresolvedDevice = (device) {
      onUnresolvedDevice?.call(device);
    };

    await _discoveryService.startDiscovery();
  }

  /// Stop discovering
  Future<void> stopDiscovery() async {
    await _discoveryService.stopDiscovery();
    _discoveryService.onDevicesChanged = null;
    _discoveryService.onUnresolvedDevice = null;
    if (_state == LocalSyncState.idle) {
      _currentRole = null;
    }
  }

  /// Connect to a discovered device
  Future<SyncInfo> connectToDiscoveredDevice(DiscoveredDevice device) async {
    if (_state != LocalSyncState.idle && _currentRole != SyncRole.receiver) {
      throw const LocalSyncException(
        'A sync operation is already in progress',
        SyncErrorType.unknown,
      );
    }

    try {
      _setState(LocalSyncState.preparing);
      _currentRole = SyncRole.receiver;
      _startTime = DateTime.now();

      // Stop discovery since we're connecting
      await _discoveryService.stopDiscovery();

      // Create session from discovered device info
      _remoteSession = SyncSession(
        sessionId: device.sessionId,
        sessionToken: device.sessionToken,
        senderIp: device.ip,
        senderPort: device.port,
        deviceName: device.name,
        timestamp: device.discoveredAt,
      );

      _setState(LocalSyncState.connected);

      // Get sync info from sender
      final info = await _getSyncInfo();
      return info;
    } catch (e) {
      await cancelSync();
      if (e is LocalSyncException) rethrow;
      throw LocalSyncException(
        'Failed to connect: $e',
        SyncErrorType.networkError,
      );
    }
  }

  /// Connect to a sender using QR code data (fallback method)
  Future<SyncInfo> connectToSender(String qrData) async {
    if (isSyncing) {
      throw const LocalSyncException(
        'A sync operation is already in progress',
        SyncErrorType.unknown,
      );
    }

    try {
      _setState(LocalSyncState.preparing);
      _currentRole = SyncRole.receiver;
      _startTime = DateTime.now();

      // Parse QR code
      final session = _sessionManager.parseQrCode(qrData);
      if (session == null) {
        throw const LocalSyncException(
          'Invalid QR code',
          SyncErrorType.unknown,
        );
      }

      // Validate session
      final error = _sessionManager.validateSessionForConnection(session);
      if (error != null) {
        throw error;
      }

      _remoteSession = session;
      _setState(LocalSyncState.connected);

      // Get sync info from sender
      final info = await _getSyncInfo();
      return info;
    } catch (e) {
      await cancelSync();
      if (e is LocalSyncException) rethrow;
      throw LocalSyncException(
        'Failed to connect: $e',
        SyncErrorType.networkError,
      );
    }
  }

  /// Get manifest of available items from sender
  Future<SyncManifest> getManifest() async {
    if (_remoteSession == null) {
      throw const LocalSyncException(
        'Not connected to sender',
        SyncErrorType.unknown,
      );
    }

    try {
      // Authenticate first
      await _authenticate();

      final response = await _dio.get<Map<String, dynamic>>(
        _buildUrl('/sync/manifest'),
        options: Options(headers: _authHeaders()),
      );

      return SyncManifest.fromJson(response.data!);
    } catch (e) {
      if (e is LocalSyncException) rethrow;
      throw LocalSyncException(
        'Failed to get manifest: $e',
        SyncErrorType.networkError,
      );
    }
  }

  /// Get manifest of local items (for sender-side selection UI)
  Future<SyncManifest> getLocalManifest() async {
    final db = DatabaseService();

    try {
      // Get all sessions
      final sessions = await db.getAllSessions();
      final sessionItems = <SyncSessionItem>[];

      for (final session in sessions) {
        final waypoints = await db.getWaypointsForSession(session.id);
        final breadcrumbs = await db.getBreadcrumbsForSession(session.id);

        sessionItems.add(SyncSessionItem(
          id: session.id,
          name: session.name,
          createdAt: session.createdAt,
          waypointCount: waypoints.length,
          breadcrumbCount: breadcrumbs.length,
          distanceMeters: session.totalDistance,
        ));
      }

      // Get all hunts
      final hunts = await db.getAllTreasureHunts();
      final huntItems = <SyncHuntItem>[];

      for (final hunt in hunts) {
        final documents = await db.getHuntDocuments(hunt.id);
        huntItems.add(SyncHuntItem(
          id: hunt.id,
          name: hunt.name,
          createdAt: hunt.createdAt,
          clueCount: documents.length,
        ));
      }

      // Get all imported routes
      final routes = await db.getImportedRoutes();
      final routeItems = routes
          .map((route) => SyncRouteItem(
                id: route.id,
                name: route.name,
                importedAt: route.importedAt,
                pointCount: route.points.length,
                totalDistance: route.totalDistance,
              ))
          .toList();

      return SyncManifest(
        sessions: sessionItems,
        hunts: huntItems,
        routes: routeItems,
      );
    } catch (e) {
      throw LocalSyncException(
        'Failed to load local items: $e',
        SyncErrorType.unknown,
      );
    }
  }

  /// Start receiving data from sender
  Future<void> startReceive({
    required String password,
    required MergeStrategy mergeStrategy,
    SelectiveSyncRequest? selection,
  }) async {
    if (_remoteSession == null) {
      throw const LocalSyncException(
        'Not connected to sender',
        SyncErrorType.unknown,
      );
    }

    try {
      _setState(LocalSyncState.transferring);

      // Authenticate first
      debugPrint('LocalSyncService: Authenticating with sender at ${_remoteSession!.senderIp}:${_remoteSession!.senderPort}...');
      await _authenticate();
      debugPrint('LocalSyncService: Authentication successful');

      // Start the transfer on sender
      debugPrint('LocalSyncService: Requesting transfer start...');
      final startResponse = await _dio.post<Map<String, dynamic>>(
        _buildUrl('/sync/start'),
        data: json.encode({
          'sync_type': selection != null ? 'selective' : 'full',
          if (selection != null) 'selection': selection.toJson(),
        }),
        options: Options(
          headers: {
            ..._authHeaders(),
            'Content-Type': 'application/json',
          },
        ),
      );

      final downloadId = startResponse.data!['download_id'] as String;
      final fileSize = startResponse.data!['file_size'] as int;
      debugPrint('LocalSyncService: Transfer started - downloadId=$downloadId, fileSize=$fileSize bytes');

      // Download the backup file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/sync_download_${DateTime.now().millisecondsSinceEpoch}.obk');
      debugPrint('LocalSyncService: Downloading to ${tempFile.path}...');

      await _downloadFile(downloadId, fileSize, tempFile);

      // Verify downloaded file
      final downloadedSize = await tempFile.length();
      debugPrint('LocalSyncService: Download complete - received $downloadedSize bytes (expected $fileSize)');

      // Restore the backup
      onProgress?.call(SyncProgress(
        bytesTransferred: fileSize,
        totalBytes: fileSize,
        currentItem: 'Importing data...',
      ));

      debugPrint('LocalSyncService: Starting restore with mergeStrategy=$mergeStrategy...');
      final restoreResult = await _backupService.restoreFromBackup(
        tempFile.path,
        password: password,
        options: RestoreOptions(
          replaceExisting: mergeStrategy == MergeStrategy.replace,
        ),
        onProgress: (phase, progress, detail) {
          onProgress?.call(SyncProgress(
            bytesTransferred: (progress * 100).toInt(),
            totalBytes: 100,
            currentItem: phase,
          ));
        },
      );

      // Clean up temp file
      try {
        await tempFile.delete();
        debugPrint('LocalSyncService: Cleaned up temp file');
      } catch (e) {
        debugPrint('LocalSyncService: Failed to delete temp file: $e');
      }

      // Notify sender of completion with stats
      debugPrint('LocalSyncService: Backup restore completed, success=${restoreResult.success}');
      if (!restoreResult.success) {
        debugPrint('LocalSyncService: Restore error: ${restoreResult.error}');
      }
      debugPrint('LocalSyncService: Restore stats - sessions=${restoreResult.stats?.sessionCount}, hunts=${restoreResult.stats?.huntCount}, routes=${restoreResult.stats?.routeCount}');

      await _notifyComplete(
        restoreResult.success,
        restoreResult.error,
        sessionsTransferred: restoreResult.stats?.sessionCount ?? 0,
        huntsTransferred: restoreResult.stats?.huntCount ?? 0,
        routesTransferred: restoreResult.stats?.routeCount ?? 0,
        sessionsSkipped: restoreResult.stats?.skippedSessionCount ?? 0,
        huntsSkipped: restoreResult.stats?.skippedHuntCount ?? 0,
        routesSkipped: restoreResult.stats?.skippedRouteCount ?? 0,
      );
      debugPrint('LocalSyncService: Notified sender of completion');

      if (restoreResult.success) {
        debugPrint('LocalSyncService: Calling _complete with success');
        _complete(SyncResult.success(
          sessionsTransferred: restoreResult.stats?.sessionCount ?? 0,
          huntsTransferred: restoreResult.stats?.huntCount ?? 0,
          routesTransferred: restoreResult.stats?.routeCount ?? 0,
          waypointsTransferred: 0,
          sessionsSkipped: restoreResult.stats?.skippedSessionCount ?? 0,
          huntsSkipped: restoreResult.stats?.skippedHuntCount ?? 0,
          routesSkipped: restoreResult.stats?.skippedRouteCount ?? 0,
          duration: DateTime.now().difference(_startTime!),
        ));
        debugPrint('LocalSyncService: _complete finished');
      } else {
        debugPrint('LocalSyncService: Calling _complete with failure: ${restoreResult.error}');
        _complete(SyncResult.failure(
          restoreResult.error ?? 'Restore failed',
          DateTime.now().difference(_startTime!),
        ));
      }
    } catch (e, stackTrace) {
      debugPrint('LocalSyncService: startReceive failed with error: $e');
      debugPrint('LocalSyncService: Stack trace: $stackTrace');

      // Try to notify sender of failure
      try {
        await _notifyComplete(false, e.toString());
      } catch (notifyError) {
        debugPrint('LocalSyncService: Failed to notify sender: $notifyError');
      }

      await cancelSync();
      if (e is LocalSyncException) rethrow;
      throw LocalSyncException(
        'Failed to receive data: $e',
        SyncErrorType.transferInterrupted,
      );
    }
  }

  // ============================================================
  // Common Operations
  // ============================================================

  /// Cancel the current sync operation
  Future<void> cancelSync() async {
    debugPrint('LocalSyncService: Cancelling sync...');

    if (_currentRole == SyncRole.sender) {
      await _httpServer.stop();
      await _discoveryService.stopAdvertising();
      _sessionManager.endSession();
    } else if (_currentRole == SyncRole.receiver) {
      await _discoveryService.stopDiscovery();
    }

    _remoteSession = null;
    _currentRole = null;
    _startTime = null;
    _setState(LocalSyncState.idle);
  }

  // ============================================================
  // Private Helpers
  // ============================================================

  void _setState(LocalSyncState newState) {
    _state = newState;
    onStateChange?.call(newState);
  }

  void _complete(SyncResult result) {
    debugPrint('LocalSyncService: _complete called with success=${result.success}');
    _state = result.success ? LocalSyncState.completed : LocalSyncState.failed;

    if (onComplete == null) {
      debugPrint('LocalSyncService: WARNING - onComplete callback is null!');
    } else {
      debugPrint('LocalSyncService: Calling onComplete callback');
      onComplete?.call(result);
    }

    // Auto-cleanup after completion
    if (_currentRole == SyncRole.sender) {
      _httpServer.stop();
      _discoveryService.stopAdvertising();
      _sessionManager.endSession();
    }

    _remoteSession = null;
    _currentRole = null;
  }

  String _buildUrl(String path) {
    if (_remoteSession == null) {
      throw const LocalSyncException(
        'Not connected to sender',
        SyncErrorType.unknown,
      );
    }
    return 'http://${_remoteSession!.senderIp}:${_remoteSession!.senderPort}$path';
  }

  Map<String, String> _authHeaders() {
    if (_remoteSession == null) return {};
    return {
      'Authorization': 'Bearer ${_remoteSession!.sessionToken}',
    };
  }

  Future<SyncInfo> _getSyncInfo() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_buildUrl('/info'));
      return SyncInfo.fromJson(response.data!);
    } catch (e) {
      throw LocalSyncException(
        'Failed to get sync info: $e',
        SyncErrorType.networkError,
      );
    }
  }

  Future<void> _authenticate() async {
    if (_remoteSession == null) return;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _buildUrl('/auth'),
        data: json.encode({
          'session_id': _remoteSession!.sessionId,
          'token': _remoteSession!.sessionToken,
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final authenticated = response.data?['authenticated'] as bool? ?? false;
      if (!authenticated) {
        throw const LocalSyncException(
          'Authentication failed',
          SyncErrorType.authenticationFailed,
        );
      }
    } catch (e) {
      if (e is LocalSyncException) rethrow;
      throw LocalSyncException(
        'Authentication failed: $e',
        SyncErrorType.authenticationFailed,
      );
    }
  }

  Future<void> _downloadFile(String downloadId, int fileSize, File targetFile) async {
    try {
      var receivedBytes = 0;
      final downloadUrl = _buildUrl('/sync/download/$downloadId');
      debugPrint('LocalSyncService: Starting download from $downloadUrl');

      await _dio.download(
        downloadUrl,
        targetFile.path,
        options: Options(headers: _authHeaders()),
        onReceiveProgress: (received, total) {
          receivedBytes = received;
          onProgress?.call(SyncProgress(
            bytesTransferred: received,
            totalBytes: total > 0 ? total : fileSize,
            currentItem: 'Downloading...',
          ));
        },
      );

      debugPrint('LocalSyncService: Downloaded $receivedBytes bytes to ${targetFile.path}');
    } catch (e, stackTrace) {
      debugPrint('LocalSyncService: Download failed: $e');
      debugPrint('LocalSyncService: Download stack trace: $stackTrace');
      throw LocalSyncException(
        'Download failed: $e',
        SyncErrorType.transferInterrupted,
      );
    }
  }

  Future<void> _notifyComplete(
    bool success,
    String? error, {
    int sessionsTransferred = 0,
    int huntsTransferred = 0,
    int routesTransferred = 0,
    int sessionsSkipped = 0,
    int huntsSkipped = 0,
    int routesSkipped = 0,
  }) async {
    try {
      await _dio.post<void>(
        _buildUrl('/sync/complete'),
        data: json.encode({
          'success': success,
          if (error != null) 'error': error,
          'sessions_transferred': sessionsTransferred,
          'hunts_transferred': huntsTransferred,
          'routes_transferred': routesTransferred,
          'sessions_skipped': sessionsSkipped,
          'hunts_skipped': huntsSkipped,
          'routes_skipped': routesSkipped,
        }),
        options: Options(
          headers: {
            ..._authHeaders(),
            'Content-Type': 'application/json',
          },
        ),
      );
    } catch (e) {
      debugPrint('LocalSyncService: Failed to notify completion: $e');
    }
  }
}
