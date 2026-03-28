import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/security_models.dart';
import 'package:obsession_tracker/core/models/sync_models.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/services/data_encryption_service.dart';

/// End-to-end encrypted cloud synchronization service
class EncryptedCloudSyncService {
  EncryptedCloudSyncService({
    required DataEncryptionService encryptionService,
  }) : _encryptionService = encryptionService;

  final DataEncryptionService _encryptionService;

  // Service state
  bool _isInitialized = false;
  bool _isSyncing = false;
  SyncConfiguration _config = const SyncConfiguration();
  String? _deviceId;

  // Sync state
  final Map<String, SyncOperation> _pendingOperations = {};
  final Map<String, SyncConflict> _conflicts = {};
  final List<SyncDevice> _devices = <SyncDevice>[];

  // Stream controllers
  final StreamController<SyncOperation> _operationController =
      StreamController.broadcast();
  final StreamController<SyncConflict> _conflictController =
      StreamController.broadcast();
  final StreamController<SyncStatistics> _statisticsController =
      StreamController.broadcast();
  final StreamController<List<SyncDevice>> _devicesController =
      StreamController.broadcast();

  // Timers
  Timer? _syncTimer;
  Timer? _heartbeatTimer;

  /// Stream of sync operations
  Stream<SyncOperation> get operationStream => _operationController.stream;

  /// Stream of sync conflicts
  Stream<SyncConflict> get conflictStream => _conflictController.stream;

  /// Stream of sync statistics
  Stream<SyncStatistics> get statisticsStream => _statisticsController.stream;

  /// Stream of connected devices
  Stream<List<SyncDevice>> get devicesStream => _devicesController.stream;

  /// Current sync configuration
  SyncConfiguration get configuration => _config;

  /// Whether sync is currently active
  bool get isSyncing => _isSyncing;

  /// List of pending sync conflicts
  List<SyncConflict> get pendingConflicts =>
      _conflicts.values.where((c) => !c.isResolved).toList();

  /// Initialize the encrypted cloud sync service
  Future<void> initialize({
    required String userId,
    SyncConfiguration? config,
  }) async {
    if (_isInitialized) return;

    try {
      debugPrint('🔄 Initializing encrypted cloud sync service...');

      _config = config ?? const SyncConfiguration();

      // Initialize device ID
      await _initializeDeviceId();

      // Initialize encryption service
      await _encryptionService.initialize(
        const DataEncryptionSettings(),
      );

      // Register current device
      await _registerDevice();

      // Load pending operations
      await _loadPendingOperations();

      // Start sync timer if auto-sync is enabled
      if (_config.enableAutoSync) {
        _startSyncTimer();
      }

      // Start device heartbeat
      _startHeartbeat();

      _isInitialized = true;
      debugPrint('✅ Encrypted cloud sync service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize encrypted cloud sync service: $e');
      rethrow;
    }
  }

  /// Stop the sync service
  Future<void> stop() async {
    if (!_isInitialized) return;

    debugPrint('🛑 Stopping encrypted cloud sync service...');

    // Cancel timers
    _syncTimer?.cancel();
    _heartbeatTimer?.cancel();

    // Complete pending operations
    await _completePendingOperations();

    // Update device status
    await _updateDeviceStatus(isOnline: false);

    _isInitialized = false;
    _isSyncing = false;

    debugPrint('✅ Encrypted cloud sync service stopped');
  }

  /// Update sync configuration
  Future<void> updateConfiguration(SyncConfiguration newConfig) async {
    _config = newConfig;

    // Restart sync timer if needed
    _syncTimer?.cancel();
    if (_config.enableAutoSync) {
      _startSyncTimer();
    }

    // Save configuration
    await _saveConfiguration();

    debugPrint('⚙️ Sync configuration updated');
  }

  /// Manually trigger sync
  Future<void> triggerSync({
    List<String>? sessionIds,
    bool forceFullSync = false,
  }) async {
    if (!_isInitialized || _isSyncing) return;

    debugPrint('🔄 Triggering manual sync...');

    try {
      _isSyncing = true;

      // Check network connectivity
      if (!await _checkNetworkConnectivity()) {
        throw Exception('No network connectivity available');
      }

      // Perform sync operations
      if (forceFullSync) {
        await _performFullSync();
      } else {
        await _performIncrementalSync(sessionIds: sessionIds);
      }

      // Update statistics
      await _updateSyncStatistics();

      debugPrint('✅ Manual sync completed');
    } catch (e) {
      debugPrint('❌ Manual sync failed: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a specific session
  Future<void> syncSession(TrackingSession session) async {
    if (!_isInitialized) return;

    debugPrint('🔄 Syncing session: ${session.name}');

    try {
      // Create sync operation
      final operation = SyncOperation(
        id: _generateOperationId(),
        type: SyncOperationType.upload,
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
        deviceId: _deviceId!,
        dataType: 'session',
        recordId: session.id,
      );

      _pendingOperations[operation.id] = operation;
      _operationController.add(operation);

      // Encrypt session data
      final encryptedData = await _encryptSessionData(session);

      // Upload to cloud
      await _uploadSessionData(session.id, encryptedData);

      // Mark operation as completed
      final completedOperation = operation.copyWith(
        status: SyncStatus.completed,
        completedAt: DateTime.now(),
      );

      _pendingOperations[operation.id] = completedOperation;
      _operationController.add(completedOperation);

      debugPrint('✅ Session synced successfully: ${session.name}');
    } catch (e) {
      debugPrint('❌ Failed to sync session: $e');

      // Mark operation as failed
      final failedOperation = _pendingOperations[session.id]?.copyWith(
        status: SyncStatus.failed,
        errorMessage: e.toString(),
      );

      if (failedOperation != null) {
        _pendingOperations[failedOperation.id] = failedOperation;
        _operationController.add(failedOperation);
      }

      rethrow;
    }
  }

  /// Download session from cloud
  Future<TrackingSession?> downloadSession(String sessionId) async {
    if (!_isInitialized) return null;

    debugPrint('⬇️ Downloading session: $sessionId');

    try {
      // Create download operation
      final operation = SyncOperation(
        id: _generateOperationId(),
        type: SyncOperationType.download,
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
        deviceId: _deviceId!,
        dataType: 'session',
        recordId: sessionId,
      );

      _pendingOperations[operation.id] = operation;
      _operationController.add(operation);

      // Download encrypted data
      final encryptedData = await _downloadSessionData(sessionId);
      if (encryptedData == null) return null;

      // Decrypt session data
      final session = await _decryptSessionData(encryptedData);

      // Mark operation as completed
      final completedOperation = operation.copyWith(
        status: SyncStatus.completed,
        completedAt: DateTime.now(),
      );

      _pendingOperations[operation.id] = completedOperation;
      _operationController.add(completedOperation);

      debugPrint('✅ Session downloaded successfully: $sessionId');
      return session;
    } catch (e) {
      debugPrint('❌ Failed to download session: $e');
      rethrow;
    }
  }

  /// Resolve sync conflict
  Future<void> resolveConflict(
    String conflictId,
    ConflictResolution resolution, {
    Map<String, dynamic>? customData,
  }) async {
    final conflict = _conflicts[conflictId];
    if (conflict == null) return;

    debugPrint('🔧 Resolving conflict: $conflictId with $resolution');

    try {
      Map<String, dynamic> resolvedData;

      switch (resolution) {
        case ConflictResolution.localWins:
          resolvedData = conflict.localData;
          break;
        case ConflictResolution.remoteWins:
          resolvedData = conflict.remoteData;
          break;
        case ConflictResolution.merge:
          resolvedData = await _mergeConflictData(conflict);
          break;
        case ConflictResolution.keepBoth:
          resolvedData = await _keepBothConflictData(conflict);
          break;
        case ConflictResolution.manual:
          resolvedData = customData ?? conflict.localData;
          break;
      }

      // Update conflict record
      final resolvedConflict = SyncConflict(
        id: conflict.id,
        dataType: conflict.dataType,
        recordId: conflict.recordId,
        localData: conflict.localData,
        remoteData: conflict.remoteData,
        createdAt: conflict.createdAt,
        resolvedAt: DateTime.now(),
        resolution: resolution,
        resolvedData: resolvedData,
      );

      _conflicts[conflictId] = resolvedConflict;
      _conflictController.add(resolvedConflict);

      // Apply resolved data
      await _applyResolvedData(resolvedConflict);

      debugPrint('✅ Conflict resolved: $conflictId');
    } catch (e) {
      debugPrint('❌ Failed to resolve conflict: $e');
      rethrow;
    }
  }

  /// Get list of connected devices
  Future<List<SyncDevice>> getConnectedDevices() async {
    if (!_isInitialized) return [];

    try {
      // Fetch devices from cloud
      final devices = await _fetchDevicesFromCloud();

      _devices.clear();
      _devices.addAll(devices);
      _devicesController.add(_devices);

      return devices;
    } catch (e) {
      debugPrint('❌ Failed to get connected devices: $e');
      return _devices;
    }
  }

  /// Remove device from sync
  Future<void> removeDevice(String deviceId) async {
    if (!_isInitialized) return;

    debugPrint('🗑️ Removing device from sync: $deviceId');

    try {
      // Remove device from cloud
      await _removeDeviceFromCloud(deviceId);

      // Update local device list
      _devices.removeWhere((d) => d.id == deviceId);
      _devicesController.add(_devices);

      debugPrint('✅ Device removed from sync: $deviceId');
    } catch (e) {
      debugPrint('❌ Failed to remove device: $e');
      rethrow;
    }
  }

  /// Get sync statistics
  Future<SyncStatistics> getSyncStatistics() async {
    try {
      final stats = await _calculateSyncStatistics();
      _statisticsController.add(stats);
      return stats;
    } catch (e) {
      debugPrint('❌ Failed to get sync statistics: $e');
      return const SyncStatistics();
    }
  }

  // Private methods

  Future<void> _initializeDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceId;

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown-ios';
      } else {
        deviceId = 'unknown-${DateTime.now().millisecondsSinceEpoch}';
      }

      _deviceId = deviceId;
      debugPrint('📱 Device ID initialized: $deviceId');
    } catch (e) {
      debugPrint('❌ Failed to initialize device ID: $e');
      _deviceId = 'fallback-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _registerDevice() async {
    if (_deviceId == null) return;

    try {
      final device = SyncDevice(
        id: _deviceId!,
        name: await _getDeviceName(),
        type: _getDeviceType(),
        lastSyncAt: DateTime.now(),
        isCurrentDevice: true,
        isOnline: true,
        encryptionKeyId: await _getEncryptionKeyId(),
      );

      // Register device with cloud
      await _registerDeviceWithCloud(device);

      debugPrint('📱 Device registered: ${device.name}');
    } catch (e) {
      debugPrint('❌ Failed to register device: $e');
    }
  }

  Future<String> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name} (${iosInfo.model})';
      } else {
        return 'Unknown Device';
      }
    } catch (e) {
      return 'Unknown Device';
    }
  }

  DeviceType _getDeviceType() {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return DeviceType.mobile;
    } else if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return DeviceType.desktop;
    } else {
      return DeviceType.web;
    }
  }

  Future<String> _getEncryptionKeyId() async =>
      // Generate or retrieve encryption key ID
      'key-$_deviceId-${DateTime.now().millisecondsSinceEpoch}';

  void _startSyncTimer() {
    final interval = _getSyncInterval();
    _syncTimer = Timer.periodic(interval, (_) {
      if (!_isSyncing) {
        triggerSync();
      }
    });
  }

  Duration _getSyncInterval() {
    switch (_config.syncFrequency) {
      case SyncFrequency.realtime:
        return const Duration(seconds: 30);
      case SyncFrequency.every5Minutes:
        return const Duration(minutes: 5);
      case SyncFrequency.every15Minutes:
        return const Duration(minutes: 15);
      case SyncFrequency.hourly:
        return const Duration(hours: 1);
      case SyncFrequency.daily:
        return const Duration(days: 1);
      case SyncFrequency.manual:
        return const Duration(days: 365); // Effectively disabled
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _updateDeviceStatus(isOnline: true);
    });
  }

  Future<bool> _checkNetworkConnectivity() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();

      if (_config.wifiOnlySync) {
        return result.contains(ConnectivityResult.wifi);
      } else {
        return !result.contains(ConnectivityResult.none);
      }
    } catch (e) {
      debugPrint('❌ Failed to check network connectivity: $e');
      return false;
    }
  }

  Future<void> _performFullSync() async {
    debugPrint('🔄 Performing full sync...');

    // Sync all sessions
    await _syncAllSessions();

    // Sync all waypoints
    await _syncAllWaypoints();

    // Sync settings if enabled
    if (_config.syncSettings) {
      await _syncSettings();
    }
  }

  Future<void> _performIncrementalSync({List<String>? sessionIds}) async {
    debugPrint('🔄 Performing incremental sync...');

    // Sync specific sessions or recent changes
    if (sessionIds != null) {
      for (final sessionId in sessionIds) {
        // Load and sync session
        final session = await _loadSession(sessionId);
        if (session != null) {
          await syncSession(session);
        }
      }
    } else {
      await _syncRecentChanges();
    }
  }

  Future<void> _syncAllSessions() async {
    // Implementation would sync all sessions
    debugPrint('🔄 Syncing all sessions...');
  }

  Future<void> _syncAllWaypoints() async {
    // Implementation would sync all waypoints
    debugPrint('🔄 Syncing all waypoints...');
  }

  Future<void> _syncSettings() async {
    // Implementation would sync app settings
    debugPrint('🔄 Syncing settings...');
  }

  Future<void> _syncRecentChanges() async {
    // Implementation would sync recent changes
    debugPrint('🔄 Syncing recent changes...');
  }

  Future<TrackingSession?> _loadSession(String sessionId) async =>
      // Implementation would load session from local database
      null;

  Future<Map<String, dynamic>> _encryptSessionData(
      TrackingSession session) async {
    try {
      final sessionData = session.toMap();
      final jsonData = jsonEncode(sessionData);
      final encryptedData =
          await _encryptionService.encryptDatabaseData(jsonData);

      return {
        'encrypted_data': encryptedData,
        'encryption_key_id': await _getEncryptionKeyId(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      debugPrint('❌ Failed to encrypt session data: $e');
      rethrow;
    }
  }

  Future<TrackingSession> _decryptSessionData(
      Map<String, dynamic> encryptedData) async {
    try {
      final encryptedJson = encryptedData['encrypted_data'] as String;
      final decryptedJson =
          await _encryptionService.decryptDatabaseData(encryptedJson);
      final sessionData = jsonDecode(decryptedJson!) as Map<String, dynamic>;

      return TrackingSession.fromMap(sessionData);
    } catch (e) {
      debugPrint('❌ Failed to decrypt session data: $e');
      rethrow;
    }
  }

  Future<void> _uploadSessionData(
      String sessionId, Map<String, dynamic> encryptedData) async {
    // Implementation would upload encrypted data to cloud storage
    debugPrint('⬆️ Uploading session data: $sessionId');

    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  Future<Map<String, dynamic>?> _downloadSessionData(String sessionId) async {
    // Implementation would download encrypted data from cloud storage
    debugPrint('⬇️ Downloading session data: $sessionId');

    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 500));

    return null; // Would return actual encrypted data
  }

  Future<Map<String, dynamic>> _mergeConflictData(SyncConflict conflict) async {
    // Implementation would merge conflicting data intelligently
    final merged = Map<String, dynamic>.from(conflict.localData);

    // Simple merge strategy - prefer remote for timestamps, local for user data
    conflict.remoteData.forEach((key, value) {
      if (key.contains('timestamp') || key.contains('_at')) {
        merged[key] = value;
      }
    });

    return merged;
  }

  Future<Map<String, dynamic>> _keepBothConflictData(
          SyncConflict conflict) async =>
      // Implementation would create separate records for both versions
      conflict.localData; // Simplified implementation

  Future<void> _applyResolvedData(SyncConflict conflict) async {
    // Implementation would apply resolved data to local database
    debugPrint('✅ Applying resolved data for: ${conflict.recordId}');
  }

  Future<List<SyncDevice>> _fetchDevicesFromCloud() async =>
      // Implementation would fetch devices from cloud
      [];

  Future<void> _removeDeviceFromCloud(String deviceId) async {
    // Implementation would remove device from cloud
    debugPrint('🗑️ Removing device from cloud: $deviceId');
  }

  Future<void> _registerDeviceWithCloud(SyncDevice device) async {
    // Implementation would register device with cloud
    debugPrint('📱 Registering device with cloud: ${device.name}');
  }

  Future<void> _updateDeviceStatus({required bool isOnline}) async {
    // Implementation would update device status in cloud
    debugPrint('📱 Updating device status: online=$isOnline');
  }

  Future<void> _loadPendingOperations() async {
    // Implementation would load pending operations from local storage
    debugPrint('📂 Loading pending operations...');
  }

  Future<void> _completePendingOperations() async {
    // Implementation would complete or cancel pending operations
    debugPrint('✅ Completing pending operations...');
  }

  Future<void> _saveConfiguration() async {
    // Implementation would save configuration to local storage
    debugPrint('💾 Saving sync configuration...');
  }

  Future<void> _updateSyncStatistics() async {
    final stats = await _calculateSyncStatistics();
    _statisticsController.add(stats);
  }

  Future<SyncStatistics> _calculateSyncStatistics() async {
    final totalOps = _pendingOperations.length;
    final successfulOps = _pendingOperations.values
        .where((op) => op.status == SyncStatus.completed)
        .length;
    final failedOps = _pendingOperations.values
        .where((op) => op.status == SyncStatus.failed)
        .length;
    final conflictOps = _pendingOperations.values
        .where((op) => op.status == SyncStatus.conflict)
        .length;

    return SyncStatistics(
      totalOperations: totalOps,
      successfulOperations: successfulOps,
      failedOperations: failedOps,
      conflictOperations: conflictOps,
      lastSyncAt: DateTime.now(),
      deviceCount: _devices.length,
    );
  }

  String _generateOperationId() =>
      'op_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';

  /// Dispose of the service
  void dispose() {
    _syncTimer?.cancel();
    _heartbeatTimer?.cancel();
    _operationController.close();
    _conflictController.close();
    _statisticsController.close();
    _devicesController.close();
  }
}

/// Extension methods for SyncOperation
extension SyncOperationExtension on SyncOperation {
  SyncOperation copyWith({
    String? id,
    SyncOperationType? type,
    SyncStatus? status,
    DateTime? createdAt,
    String? deviceId,
    DateTime? completedAt,
    String? dataType,
    String? recordId,
    ConflictResolution? conflictResolution,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) =>
      SyncOperation(
        id: id ?? this.id,
        type: type ?? this.type,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        deviceId: deviceId ?? this.deviceId,
        completedAt: completedAt ?? this.completedAt,
        dataType: dataType ?? this.dataType,
        recordId: recordId ?? this.recordId,
        conflictResolution: conflictResolution ?? this.conflictResolution,
        errorMessage: errorMessage ?? this.errorMessage,
        metadata: metadata ?? this.metadata,
      );
}
