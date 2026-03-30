import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/local_sync_models.dart';
import 'package:obsession_tracker/core/services/app_backup_service.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/sync_session_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Local HTTP server for device-to-device sync transfers
///
/// Endpoints:
/// - GET /info - Device and backup info (no auth)
/// - POST /auth - Validate session token
/// - GET /sync/manifest - List of available items for selective sync
/// - POST /sync/start - Begin transfer (returns download ID)
/// - GET /sync/download/:id - Stream encrypted backup file
/// - POST /sync/complete - Acknowledge transfer completion
class LocalHttpServer {
  factory LocalHttpServer() => _instance;
  LocalHttpServer._();

  static final LocalHttpServer _instance = LocalHttpServer._();

  final SyncSessionManager _sessionManager = SyncSessionManager();
  final AppBackupService _backupService = AppBackupService();
  final DatabaseService _db = DatabaseService();

  HttpServer? _server;
  String? _pendingBackupPath;
  String? _pendingDownloadId;
  String? _transferPassword;
  // ignore: unused_field
  SelectiveSyncRequest? _selectiveRequest;

  /// Callback for transfer progress
  void Function(SyncProgress)? onProgress;

  /// Callback when transfer completes
  /// Parameters: success, error, sessionsTransferred, huntsTransferred, routesTransferred,
  ///             sessionsSkipped, huntsSkipped, routesSkipped
  void Function(
    bool success,
    String? error,
    int sessions,
    int hunts,
    int routes,
    int sessionsSkipped,
    int huntsSkipped,
    int routesSkipped,
  )? onTransferComplete;

  /// Whether the server is currently running
  bool get isRunning => _server != null;

  /// The port the server is listening on
  int? get port => _server?.port;

  /// Start the HTTP server for sync
  ///
  /// [transferPassword] - Password for encrypting the backup
  /// [port] - Port to listen on
  /// [selection] - Optional selective sync request (sender-side selection)
  Future<void> start({
    required String transferPassword,
    int port = SyncSessionManager.defaultPort,
    SelectiveSyncRequest? selection,
  }) async {
    if (_server != null) {
      debugPrint('LocalHttpServer: Server already running on port ${_server!.port}');
      return;
    }

    _transferPassword = transferPassword;
    _selectiveRequest = selection;

    final router = Router()
      ..get('/info', _handleInfo)
      ..post('/auth', _handleAuth)
      ..get('/sync/manifest', _handleManifest)
      ..post('/sync/start', _handleStart)
      ..get('/sync/download/<id>', _handleDownload)
      ..post('/sync/complete', _handleComplete);

    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_loggingMiddleware())
        .addHandler(router.call);

    try {
      _server = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
      debugPrint('LocalHttpServer: Started on port ${_server!.port}');
    } catch (e) {
      debugPrint('LocalHttpServer: Failed to start: $e');
      throw LocalSyncException(
        'Failed to start sync server: $e',
        SyncErrorType.networkError,
      );
    }
  }

  /// Stop the HTTP server
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      debugPrint('LocalHttpServer: Stopped');
    }

    // Clean up any pending backup file
    if (_pendingBackupPath != null) {
      try {
        await File(_pendingBackupPath!).delete();
      } catch (_) {}
      _pendingBackupPath = null;
    }

    _pendingDownloadId = null;
    _transferPassword = null;
    _selectiveRequest = null;
    onReceiverConnected = null;
  }

  /// CORS middleware to allow cross-origin requests
  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok(null, headers: _corsHeaders);
        }

        final response = await innerHandler(request);
        return response.change(headers: {...response.headers, ..._corsHeaders});
      };
    };
  }

  Map<String, String> get _corsHeaders => {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      };

  /// Logging middleware for debugging
  Middleware _loggingMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        debugPrint('LocalHttpServer: ${request.method} ${request.url}');
        final response = await innerHandler(request);
        debugPrint('LocalHttpServer: Response ${response.statusCode}');
        return response;
      };
    };
  }

  /// Check authorization header
  bool _isAuthorized(Request request) {
    final session = _sessionManager.currentSession;
    if (session == null || session.isExpired) {
      return false;
    }

    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return false;
    }

    final token = authHeader.substring(7);
    return _sessionManager.validateToken(session.sessionId, token);
  }

  /// GET /info - Returns device info and backup stats (no auth required)
  Future<Response> _handleInfo(Request request) async {
    try {
      final session = _sessionManager.currentSession;
      if (session == null) {
        return _errorResponse(401, 'No active sync session');
      }

      // Get data counts, filtered by selective sync if applicable
      var sessions = await _db.getAllSessions();
      var hunts = await _db.getAllTreasureHunts();
      var routes = await _db.getImportedRoutes();

      // Apply selective sync filtering if set
      // Note: null means "include all", empty list means "include nothing"
      if (_selectiveRequest != null) {
        if (_selectiveRequest!.sessionIds != null) {
          if (_selectiveRequest!.sessionIds!.isEmpty) {
            sessions = [];
          } else {
            final filterSet = _selectiveRequest!.sessionIds!.toSet();
            sessions = sessions.where((s) => filterSet.contains(s.id)).toList();
          }
        }
        if (_selectiveRequest!.huntIds != null) {
          if (_selectiveRequest!.huntIds!.isEmpty) {
            hunts = [];
          } else {
            final filterSet = _selectiveRequest!.huntIds!.toSet();
            hunts = hunts.where((h) => filterSet.contains(h.id)).toList();
          }
        }
        if (_selectiveRequest!.routeIds != null) {
          if (_selectiveRequest!.routeIds!.isEmpty) {
            routes = [];
          } else {
            final filterSet = _selectiveRequest!.routeIds!.toSet();
            routes = routes.where((r) => filterSet.contains(r.id)).toList();
          }
        }
      }

      // Count waypoints across selected sessions only
      int waypointCount = 0;
      for (final s in sessions) {
        final waypoints = await _db.getWaypointsForSession(s.id);
        waypointCount += waypoints.length;
      }

      // Estimate backup size (rough estimate based on data counts)
      final estimatedSize = _estimateBackupSize(
        sessions.length,
        hunts.length,
        routes.length,
        waypointCount,
      );

      final packageInfo = await PackageInfo.fromPlatform();

      final info = SyncInfo(
        deviceName: session.deviceName,
        platform: _sessionManager.getPlatformName(),
        totalSessions: sessions.length,
        totalHunts: hunts.length,
        totalRoutes: routes.length,
        totalWaypoints: waypointCount,
        backupSizeBytes: estimatedSize,
        appVersion: packageInfo.version,
      );

      return _jsonResponse(info.toJson());
    } catch (e) {
      debugPrint('LocalHttpServer: Error handling /info: $e');
      return _errorResponse(500, 'Internal server error');
    }
  }

  /// POST /auth - Validate session token
  Future<Response> _handleAuth(Request request) async {
    try {
      final body = await request.readAsString();
      final data = json.decode(body) as Map<String, dynamic>;

      final sessionId = data['session_id'] as String?;
      final token = data['token'] as String?;

      if (sessionId == null || token == null) {
        return _errorResponse(400, 'Missing session_id or token');
      }

      if (_sessionManager.validateToken(sessionId, token)) {
        return _jsonResponse({'authenticated': true});
      } else {
        return _errorResponse(401, 'Invalid session token');
      }
    } catch (e) {
      debugPrint('LocalHttpServer: Error handling /auth: $e');
      return _errorResponse(400, 'Invalid request body');
    }
  }

  /// GET /sync/manifest - List available items for selective sync
  Future<Response> _handleManifest(Request request) async {
    if (!_isAuthorized(request)) {
      return _errorResponse(401, 'Unauthorized');
    }

    try {
      // Get all sessions
      final sessions = await _db.getAllSessions();
      final sessionItems = <SyncSessionItem>[];

      for (final session in sessions) {
        final waypoints = await _db.getWaypointsForSession(session.id);
        final breadcrumbs = await _db.getBreadcrumbsForSession(session.id);

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
      final hunts = await _db.getAllTreasureHunts();
      final huntItems = <SyncHuntItem>[];

      for (final hunt in hunts) {
        final documents = await _db.getHuntDocuments(hunt.id);
        huntItems.add(SyncHuntItem(
          id: hunt.id,
          name: hunt.name,
          createdAt: hunt.createdAt,
          clueCount: documents.length,
        ));
      }

      // Get all routes
      final routes = await _db.getImportedRoutes();
      final routeItems = routes.map((route) => SyncRouteItem(
            id: route.id,
            name: route.name,
            importedAt: route.importedAt,
            pointCount: route.points.length,
            totalDistance: route.totalDistance,
          )).toList();

      final manifest = SyncManifest(
        sessions: sessionItems,
        hunts: huntItems,
        routes: routeItems,
      );

      return _jsonResponse(manifest.toJson());
    } catch (e) {
      debugPrint('LocalHttpServer: Error handling /sync/manifest: $e');
      return _errorResponse(500, 'Failed to get manifest');
    }
  }

  /// POST /sync/start - Begin transfer and return download ID
  Future<Response> _handleStart(Request request) async {
    if (!_isAuthorized(request)) {
      return _errorResponse(401, 'Unauthorized');
    }

    try {
      // Note: Selection comes from sender (stored when server started),
      // not from receiver's request body
      final selectiveOptions = _selectiveRequest != null
          ? SelectiveBackupOptions(
              sessionIds: _selectiveRequest!.sessionIds,
              huntIds: _selectiveRequest!.huntIds,
              routeIds: _selectiveRequest!.routeIds,
            )
          : null;

      // Create the backup file
      debugPrint('LocalHttpServer: Creating backup (selective: ${selectiveOptions != null})...');
      onProgress?.call(SyncProgress(
        bytesTransferred: 0,
        totalBytes: 0,
        currentItem: 'Preparing backup...',
      ));

      final result = await _backupService.createBackup(
        password: _transferPassword!,
        shareAfterCreate: false,
        selectiveOptions: selectiveOptions,
        onProgress: (phase, progress, detail) {
          onProgress?.call(SyncProgress(
            bytesTransferred: (progress * 100).toInt(),
            totalBytes: 100,
            currentItem: phase,
          ));
        },
      );

      if (!result.success || result.filePath == null) {
        return _errorResponse(500, result.error ?? 'Backup creation failed');
      }

      _pendingBackupPath = result.filePath;
      _pendingDownloadId = DateTime.now().millisecondsSinceEpoch.toString();

      final file = File(result.filePath!);
      final fileSize = await file.length();

      return _jsonResponse({
        'download_id': _pendingDownloadId,
        'file_size': fileSize,
        'file_name': 'sync_backup.obk',
      });
    } catch (e) {
      debugPrint('LocalHttpServer: Error handling /sync/start: $e');
      return _errorResponse(500, 'Failed to start sync: $e');
    }
  }

  /// Callback when a receiver connects and starts downloading
  void Function()? onReceiverConnected;

  /// GET /sync/download/:id - Stream the backup file
  Future<Response> _handleDownload(Request request, String id) async {
    if (!_isAuthorized(request)) {
      return _errorResponse(401, 'Unauthorized');
    }

    if (_pendingDownloadId != id || _pendingBackupPath == null) {
      return _errorResponse(404, 'Download not found or expired');
    }

    try {
      // Notify that receiver has connected and started downloading
      onReceiverConnected?.call();

      final file = File(_pendingBackupPath!);
      if (!await file.exists()) {
        return _errorResponse(404, 'Backup file not found');
      }

      final fileSize = await file.length();
      debugPrint('LocalHttpServer: Starting download of $fileSize bytes');
      final stream = file.openRead();

      // Track progress as data is streamed
      var bytesRead = 0;
      final progressStream = stream.map((chunk) {
        bytesRead += chunk.length;
        onProgress?.call(SyncProgress(
          bytesTransferred: bytesRead,
          totalBytes: fileSize,
          currentItem: 'Sending data...',
        ));
        return chunk;
      });

      return Response.ok(
        progressStream,
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Length': fileSize.toString(),
          'Content-Disposition': 'attachment; filename="sync_backup.obk"',
        },
      );
    } catch (e) {
      debugPrint('LocalHttpServer: Error handling /sync/download: $e');
      return _errorResponse(500, 'Failed to send file: $e');
    }
  }

  /// POST /sync/complete - Acknowledge transfer completion
  Future<Response> _handleComplete(Request request) async {
    if (!_isAuthorized(request)) {
      return _errorResponse(401, 'Unauthorized');
    }

    try {
      final body = await request.readAsString();
      final data = json.decode(body) as Map<String, dynamic>;

      final success = data['success'] as bool? ?? false;
      final error = data['error'] as String?;
      final sessionsTransferred = data['sessions_transferred'] as int? ?? 0;
      final huntsTransferred = data['hunts_transferred'] as int? ?? 0;
      final routesTransferred = data['routes_transferred'] as int? ?? 0;
      final sessionsSkipped = data['sessions_skipped'] as int? ?? 0;
      final huntsSkipped = data['hunts_skipped'] as int? ?? 0;
      final routesSkipped = data['routes_skipped'] as int? ?? 0;

      // Clean up backup file
      if (_pendingBackupPath != null) {
        try {
          await File(_pendingBackupPath!).delete();
        } catch (_) {}
        _pendingBackupPath = null;
      }

      _pendingDownloadId = null;

      // Notify completion with transfer stats
      onTransferComplete?.call(
        success,
        error,
        sessionsTransferred,
        huntsTransferred,
        routesTransferred,
        sessionsSkipped,
        huntsSkipped,
        routesSkipped,
      );

      return _jsonResponse({'acknowledged': true});
    } catch (e) {
      debugPrint('LocalHttpServer: Error handling /sync/complete: $e');
      return _errorResponse(500, 'Failed to complete sync');
    }
  }

  /// Estimate backup size based on data counts
  int _estimateBackupSize(int sessions, int hunts, int routes, int waypoints) {
    // Rough estimates:
    // - Base overhead: 50KB
    // - Per session: 10KB (metadata, breadcrumbs, etc.)
    // - Per hunt: 5KB base + documents
    // - Per route: 20KB (includes points)
    // - Per waypoint: 500 bytes
    // These are conservative estimates; actual may be larger with media files
    const baseOverhead = 50 * 1024;
    const perSession = 10 * 1024;
    const perHunt = 5 * 1024;
    const perRoute = 20 * 1024;
    const perWaypoint = 500;

    return baseOverhead +
        (sessions * perSession) +
        (hunts * perHunt) +
        (routes * perRoute) +
        (waypoints * perWaypoint);
  }

  /// Create a JSON response
  Response _jsonResponse(Object data) {
    return Response.ok(
      json.encode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Create an error response
  Response _errorResponse(int statusCode, String message) {
    return Response(
      statusCode,
      body: json.encode({'error': message}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
