import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:obsession_tracker/core/models/bff_app_config.dart';
import 'package:obsession_tracker/core/services/bff_mapping_service.dart';
import 'package:obsession_tracker/core/services/dynamic_land_data_service.dart';
import 'package:obsession_tracker/core/services/offline_land_rights_service.dart';

/// Status of a single state download
enum StateDownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  cancelled,
}

/// Tracks the download state of a single state
class StateDownloadProgress {
  StateDownloadProgress({
    required this.stateCode,
    required this.stateName,
    this.status = StateDownloadStatus.pending,
    this.message = 'Waiting...',
    this.recordCount = 0,
    this.trailCount = 0,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
  });

  final String stateCode;
  final String stateName;
  StateDownloadStatus status;
  String message;
  int recordCount;
  int trailCount;
  int bytesDownloaded;
  int totalBytes;

  /// Progress as a value between 0.0 and 1.0
  double get progress {
    if (status == StateDownloadStatus.completed) return 1.0;
    if (status == StateDownloadStatus.pending) return 0.0;
    if (totalBytes > 0) return bytesDownloaded / totalBytes;
    return 0.0;
  }

  StateDownloadProgress copyWith({
    StateDownloadStatus? status,
    String? message,
    int? recordCount,
    int? trailCount,
    int? bytesDownloaded,
    int? totalBytes,
  }) {
    return StateDownloadProgress(
      stateCode: stateCode,
      stateName: stateName,
      status: status ?? this.status,
      message: message ?? this.message,
      recordCount: recordCount ?? this.recordCount,
      trailCount: trailCount ?? this.trailCount,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
    );
  }
}

/// Overall download manager state
class DownloadManagerState {
  const DownloadManagerState({
    this.isDownloading = false,
    this.isCancelling = false,
    this.downloads = const {},
    this.completedCount = 0,
    this.totalCount = 0,
  });

  final bool isDownloading;
  final bool isCancelling;
  final Map<String, StateDownloadProgress> downloads;
  final int completedCount;
  final int totalCount;

  /// Overall progress as a value between 0.0 and 1.0
  double get overallProgress {
    if (totalCount == 0) return 0.0;
    return completedCount / totalCount;
  }

  DownloadManagerState copyWith({
    bool? isDownloading,
    bool? isCancelling,
    Map<String, StateDownloadProgress>? downloads,
    int? completedCount,
    int? totalCount,
  }) {
    return DownloadManagerState(
      isDownloading: isDownloading ?? this.isDownloading,
      isCancelling: isCancelling ?? this.isCancelling,
      downloads: downloads ?? this.downloads,
      completedCount: completedCount ?? this.completedCount,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

/// Singleton service that manages state downloads in the background
///
/// Downloads continue even when the user navigates away from the downloads page.
/// Sends local notifications for progress and completion.
class StateDownloadManager {
  StateDownloadManager._();
  static final StateDownloadManager instance = StateDownloadManager._();

  final _stateController = StreamController<DownloadManagerState>.broadcast();
  Stream<DownloadManagerState> get stateStream => _stateController.stream;

  DownloadManagerState _state = const DownloadManagerState();
  DownloadManagerState get state => _state;

  FlutterLocalNotificationsPlugin? _notifications;
  static const int _progressNotificationId = 9001;
  static const int _completionNotificationId = 9002;

  bool _initialized = false;

  /// Test mode flag - when true, skips notification initialization and permission requests
  /// Set this to true before downloading in integration tests to avoid permission dialogs
  static bool testMode = false;

  /// Initialize the download manager
  Future<void> initialize() async {
    if (_initialized) return;

    // Skip notification setup in test mode to avoid permission dialogs
    if (testMode) {
      _initialized = true;
      debugPrint('📥 StateDownloadManager initialized (test mode - no notifications)');
      return;
    }

    _notifications = FlutterLocalNotificationsPlugin();

    // Initialize with settings (should already be done by PushNotificationService,
    // but we ensure it here for standalone use)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings, // Required for macOS desktop
    );

    await _notifications!.initialize(settings: settings);

    // Request notification permission on Android 13+ (API 33+)
    // This is required for local notifications to appear
    if (Platform.isAndroid) {
      final androidPlugin = _notifications!.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      debugPrint('📥 Android notification permission granted: $granted');
    }

    _initialized = true;
    debugPrint('📥 StateDownloadManager initialized');
  }

  /// Start downloading the specified states
  ///
  /// Downloads continue in the background even if the UI navigates away.
  /// Set [forceRedownload] to true when updating existing states.
  Future<void> startDownloads(List<String> stateCodes, {bool forceRedownload = false}) async {
    if (_state.isDownloading) {
      debugPrint('📥 Downloads already in progress, ignoring request');
      return;
    }

    if (stateCodes.isEmpty) return;

    // Check connectivity
    final isOnline = await BFFMappingService.instance.isOnline;
    if (!isOnline) {
      debugPrint('📥 Cannot download while offline');
      return;
    }

    await initialize();

    // Initialize download state
    final downloads = <String, StateDownloadProgress>{};
    for (final stateCode in stateCodes) {
      final stateInfo = DynamicLandDataService.availableStates[stateCode];
      downloads[stateCode] = StateDownloadProgress(
        stateCode: stateCode,
        stateName: stateInfo?.name ?? stateCode,
      );
    }

    _updateState(_state.copyWith(
      isDownloading: true,
      isCancelling: false,
      downloads: downloads,
      completedCount: 0,
      totalCount: stateCodes.length,
    ));

    // Show initial progress notification
    await _showProgressNotification(
      'Downloading map data',
      'Starting ${stateCodes.length} state download${stateCodes.length > 1 ? 's' : ''}...',
    );

    // Process downloads
    int completedCount = 0;
    int failedCount = 0;

    for (final stateCode in stateCodes) {
      if (_state.isCancelling) {
        // Mark remaining as cancelled
        _markRemainingAsCancelled(stateCodes, stateCodes.indexOf(stateCode));
        break;
      }

      await _downloadState(stateCode, forceRedownload: forceRedownload);

      final status = _state.downloads[stateCode]?.status;
      if (status == StateDownloadStatus.completed) {
        completedCount++;
      } else if (status == StateDownloadStatus.failed) {
        failedCount++;
      }

      _updateState(_state.copyWith(completedCount: completedCount));

      // Update progress notification
      final remaining = stateCodes.length - completedCount - failedCount;
      if (remaining > 0 && !_state.isCancelling) {
        await _showProgressNotification(
          'Downloading map data',
          '$completedCount of ${stateCodes.length} complete, $remaining remaining',
        );
      }
    }

    // Clear progress notification
    await _notifications?.cancel(id: _progressNotificationId);

    // Show completion notification
    if (!_state.isCancelling) {
      if (failedCount == 0) {
        await _showCompletionNotification(
          'Downloads complete',
          '$completedCount state${completedCount > 1 ? 's' : ''} downloaded successfully',
        );
      } else {
        await _showCompletionNotification(
          'Downloads finished',
          '$completedCount succeeded, $failedCount failed',
        );
      }
    }

    _updateState(_state.copyWith(
      isDownloading: false,
      isCancelling: false,
    ));

    debugPrint('📥 All downloads complete: $completedCount succeeded, $failedCount failed');
  }

  /// Start selective downloads - only download specified data types per state
  ///
  /// This is more efficient than [startDownloads] when only some data types
  /// need updating (e.g., only historical places are missing).
  ///
  /// [stateDataTypes] maps state codes to the set of data types to download.
  Future<void> startSelectiveDownloads(
    Map<String, Set<DataType>> stateDataTypes,
  ) async {
    if (_state.isDownloading) {
      debugPrint('📥 Downloads already in progress, ignoring request');
      return;
    }

    if (stateDataTypes.isEmpty) return;

    // Check connectivity
    final isOnline = await BFFMappingService.instance.isOnline;
    if (!isOnline) {
      debugPrint('📥 Cannot download while offline');
      return;
    }

    await initialize();

    // Count total downloads (each state-type pair is one download unit)
    int totalDownloadUnits = 0;
    for (final types in stateDataTypes.values) {
      totalDownloadUnits += types.length;
    }

    // Initialize download state
    final downloads = <String, StateDownloadProgress>{};
    for (final stateCode in stateDataTypes.keys) {
      final stateInfo = DynamicLandDataService.availableStates[stateCode];
      final types = stateDataTypes[stateCode]!;
      downloads[stateCode] = StateDownloadProgress(
        stateCode: stateCode,
        stateName: stateInfo?.name ?? stateCode,
        message: 'Downloading ${types.map((t) => t.name).join(', ')}...',
      );
    }

    _updateState(_state.copyWith(
      isDownloading: true,
      isCancelling: false,
      downloads: downloads,
      completedCount: 0,
      totalCount: stateDataTypes.length,
    ));

    // Show initial progress notification
    await _showProgressNotification(
      'Downloading map data',
      'Starting $totalDownloadUnits download${totalDownloadUnits > 1 ? 's' : ''}...',
    );

    // Process downloads
    int completedCount = 0;
    int failedCount = 0;

    final offlineService = OfflineLandRightsService();
    await offlineService.initialize();

    for (final entry in stateDataTypes.entries) {
      final stateCode = entry.key;
      final dataTypes = entry.value;

      if (_state.isCancelling) {
        break;
      }

      _updateDownload(stateCode, (p) => p.copyWith(
        status: StateDownloadStatus.downloading,
        message: 'Downloading ${dataTypes.map((t) => t.name).join(', ')}...',
      ));

      bool anyFailed = false;
      int recordsDownloaded = 0;

      for (final dataType in dataTypes) {
        if (_state.isCancelling) break;

        _updateDownload(stateCode, (p) => p.copyWith(
          message: 'Downloading ${dataType.name}...',
        ));

        // Convert DataType to DataTypeLocal
        final localType = switch (dataType) {
          DataType.land => DataTypeLocal.land,
          DataType.trails => DataTypeLocal.trails,
          DataType.historical => DataTypeLocal.historical,
          DataType.cell => DataTypeLocal.cell,
        };

        final result = await BFFMappingService.instance.downloadStateDataTypeToDatabase(
          stateCode: stateCode,
          dataType: localType,
          offlineService: offlineService,
          onDownloadProgress: (received, total) {
            final receivedMB = (received / 1024 / 1024).toStringAsFixed(1);
            if (total > 0) {
              final percent = ((received / total) * 100).toInt();
              _updateDownload(stateCode, (p) => p.copyWith(
                message: '${dataType.name}: $receivedMB MB ($percent%)',
              ));
            }
          },
          onProcessProgress: (processed, total) {
            final percent = ((processed / total) * 100).toInt();
            _updateDownload(stateCode, (p) => p.copyWith(
              message: '${dataType.name}: Processing $processed/$total ($percent%)',
            ));
          },
        );

        switch (result) {
          case StateDownloadSuccess():
            recordsDownloaded += result.recordCount;
            debugPrint('✅ Downloaded ${dataType.name} for $stateCode: ${result.recordCount} records');
          case StateDownloadRateLimited():
            debugPrint('🚦 Rate limited for ${dataType.name} on $stateCode');
            anyFailed = true;
          case StateDownloadError():
            debugPrint('❌ Failed to download ${dataType.name} for $stateCode: ${result.message}');
            anyFailed = true;
        }
      }

      if (anyFailed) {
        _updateDownload(stateCode, (p) => p.copyWith(
          status: StateDownloadStatus.failed,
          message: 'Some downloads failed',
        ));
        failedCount++;
      } else {
        _updateDownload(stateCode, (p) => p.copyWith(
          status: StateDownloadStatus.completed,
          recordCount: recordsDownloaded,
          message: '$recordsDownloaded records',
        ));
        completedCount++;
      }

      _updateState(_state.copyWith(completedCount: completedCount));

      // Update progress notification
      final remaining = stateDataTypes.length - completedCount - failedCount;
      if (remaining > 0 && !_state.isCancelling) {
        await _showProgressNotification(
          'Downloading map data',
          '$completedCount of ${stateDataTypes.length} complete, $remaining remaining',
        );
      }
    }

    // Clear progress notification
    await _notifications?.cancel(id: _progressNotificationId);

    // Show completion notification
    if (!_state.isCancelling) {
      if (failedCount == 0) {
        await _showCompletionNotification(
          'Downloads complete',
          '$completedCount state${completedCount > 1 ? 's' : ''} updated successfully',
        );
      } else {
        await _showCompletionNotification(
          'Downloads finished',
          '$completedCount succeeded, $failedCount failed',
        );
      }
    }

    _updateState(_state.copyWith(
      isDownloading: false,
      isCancelling: false,
    ));

    debugPrint('📥 Selective downloads complete: $completedCount succeeded, $failedCount failed');
  }

  /// Download a single state using per-type downloads (land, trails, historical)
  ///
  /// Uses the split ZIP structure for accurate progress reporting.
  Future<void> _downloadState(String stateCode, {bool forceRedownload = false}) async {
    _updateDownload(stateCode, (p) => p.copyWith(
      status: StateDownloadStatus.downloading,
      message: 'Starting download...',
    ));

    try {
      final offlineService = OfflineLandRightsService();
      await offlineService.initialize();

      // If forcing re-download, delete existing data first
      if (forceRedownload && await offlineService.isStateDownloaded(stateCode)) {
        _updateDownload(stateCode, (p) => p.copyWith(message: 'Removing old data...'));
        await offlineService.deleteStateData(stateCode);
      }

      // Download all data types (land, trails, historical, cell coverage)
      const dataTypes = [DataType.land, DataType.trails, DataType.historical, DataType.cell];
      int totalRecords = 0;
      bool anyFailed = false;

      for (final dataType in dataTypes) {
        if (_state.isCancelling) break;

        _updateDownload(stateCode, (p) => p.copyWith(
          message: 'Downloading ${dataType.name}...',
        ));

        // Convert DataType to DataTypeLocal
        final localType = switch (dataType) {
          DataType.land => DataTypeLocal.land,
          DataType.trails => DataTypeLocal.trails,
          DataType.historical => DataTypeLocal.historical,
          DataType.cell => DataTypeLocal.cell,
        };

        final result = await BFFMappingService.instance.downloadStateDataTypeToDatabase(
          stateCode: stateCode,
          dataType: localType,
          offlineService: offlineService,
          onDownloadProgress: (received, total) {
            final receivedMB = (received / 1024 / 1024).toStringAsFixed(1);
            if (total > 0) {
              final percent = ((received / total) * 100).toInt();
              _updateDownload(stateCode, (p) => p.copyWith(
                message: '${dataType.name}: $receivedMB MB ($percent%)',
              ));
            }
          },
          onProcessProgress: (processed, total) {
            final percent = ((processed / total) * 100).toInt();
            _updateDownload(stateCode, (p) => p.copyWith(
              message: '${dataType.name}: Processing $processed/$total ($percent%)',
            ));
          },
        );

        switch (result) {
          case StateDownloadSuccess():
            totalRecords += result.recordCount;
            debugPrint('✅ Downloaded ${dataType.name} for $stateCode: ${result.recordCount} records');
          case StateDownloadRateLimited():
            debugPrint('🚦 Rate limited for ${dataType.name} on $stateCode');
            anyFailed = true;
          case StateDownloadError():
            debugPrint('❌ Failed to download ${dataType.name} for $stateCode: ${result.message}');
            anyFailed = true;
        }
      }

      if (anyFailed) {
        _updateDownload(stateCode, (p) => p.copyWith(
          status: StateDownloadStatus.failed,
          message: 'Some downloads failed',
        ));
      } else {
        // Update the state_downloads record with actual counts
        await offlineService.updateStateRecordCounts(stateCode);

        // Load trail count after download
        final downloadedStates = await offlineService.getDownloadedStates();
        final stateInfo = downloadedStates.where((s) => s.stateCode == stateCode).firstOrNull;

        _updateDownload(stateCode, (p) => p.copyWith(
          status: StateDownloadStatus.completed,
          recordCount: totalRecords,
          trailCount: stateInfo?.uniqueTrailCount ?? 0,
          message: '$totalRecords records',
        ));
      }
    } catch (e) {
      _updateDownload(stateCode, (p) => p.copyWith(
        status: StateDownloadStatus.failed,
        message: 'Error: $e',
      ));
    }
  }

  /// Cancel ongoing downloads
  void cancelDownloads() {
    if (!_state.isDownloading) return;

    debugPrint('📥 Cancelling downloads...');
    _updateState(_state.copyWith(isCancelling: true));
  }

  /// Mark remaining states as cancelled
  void _markRemainingAsCancelled(List<String> stateCodes, int startIndex) {
    for (int i = startIndex; i < stateCodes.length; i++) {
      final stateCode = stateCodes[i];
      if (_state.downloads[stateCode]?.status == StateDownloadStatus.pending ||
          _state.downloads[stateCode]?.status == StateDownloadStatus.downloading) {
        _updateDownload(stateCode, (p) => p.copyWith(
          status: StateDownloadStatus.cancelled,
          message: 'Cancelled',
        ));
      }
    }
  }

  /// Clear completed/failed downloads from state
  void clearCompletedDownloads() {
    if (_state.isDownloading) return;

    _updateState(const DownloadManagerState());
  }

  /// Update overall state
  void _updateState(DownloadManagerState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  /// Update a single download's state
  void _updateDownload(String stateCode, StateDownloadProgress Function(StateDownloadProgress) updater) {
    final current = _state.downloads[stateCode];
    if (current == null) return;

    final updated = updater(current);
    final newDownloads = Map<String, StateDownloadProgress>.from(_state.downloads);
    newDownloads[stateCode] = updated;

    _updateState(_state.copyWith(downloads: newDownloads));
  }

  /// Show progress notification (Android only shows ongoing)
  Future<void> _showProgressNotification(String title, String body) async {
    if (_notifications == null) return;

    const androidDetails = AndroidNotificationDetails(
      'download_progress',
      'Download Progress',
      channelDescription: 'Shows download progress for map data',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications!.show(
      id: _progressNotificationId,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// Show completion notification
  Future<void> _showCompletionNotification(String title, String body) async {
    if (_notifications == null) return;

    const androidDetails = AndroidNotificationDetails(
      'download_complete',
      'Download Complete',
      channelDescription: 'Notifies when map data downloads complete',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications!.show(
      id: _completionNotificationId,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// Dispose resources
  void dispose() {
    _stateController.close();
  }
}
