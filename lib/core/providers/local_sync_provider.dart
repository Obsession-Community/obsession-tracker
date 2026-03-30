import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/local_sync_models.dart';
import 'package:obsession_tracker/core/services/device_discovery_service.dart';
import 'package:obsession_tracker/core/services/local_sync_service.dart';

/// State for local WiFi sync provider
@immutable
class LocalSyncProviderState {
  const LocalSyncProviderState({
    this.syncState = LocalSyncState.idle,
    this.role,
    this.qrCodeData,
    this.remoteDeviceInfo,
    this.manifest,
    this.progress,
    this.result,
    this.error,
    this.sessionTimeRemaining,
    this.discoveredDevices = const [],
    this.unresolvedDevices = const [],
    this.isDiscovering = false,
    this.availableItems,
    this.selectedSessionIds = const <String>{},
    this.selectedHuntIds = const <String>{},
    this.selectedRouteIds = const <String>{},
  });

  /// Current sync operation state
  final LocalSyncState syncState;

  /// Current role (sender or receiver)
  final SyncRole? role;

  /// QR code data for sender to display
  final String? qrCodeData;

  /// Information about the remote device (for receiver)
  final SyncInfo? remoteDeviceInfo;

  /// Manifest of available items (for receiver)
  final SyncManifest? manifest;

  /// Current transfer progress
  final SyncProgress? progress;

  /// Result of completed sync
  final SyncResult? result;

  /// Error message if any
  final String? error;

  /// Time remaining for session (sender only)
  final Duration? sessionTimeRemaining;

  /// Discovered devices (for receiver)
  final List<DiscoveredDevice> discoveredDevices;

  /// Devices found but not fully resolved (suggests QR code fallback)
  final List<UnresolvedDevice> unresolvedDevices;

  /// Whether discovery is in progress
  final bool isDiscovering;

  /// Available items for selective sync (sender only)
  final SyncManifest? availableItems;

  /// Selected session IDs for selective sync (sender only)
  final Set<String> selectedSessionIds;

  /// Selected hunt IDs for selective sync (sender only)
  final Set<String> selectedHuntIds;

  /// Selected route IDs for selective sync (sender only)
  final Set<String> selectedRouteIds;

  /// Whether we're idle
  bool get isIdle => syncState == LocalSyncState.idle;

  /// Whether we're waiting for connection
  bool get isWaiting => syncState == LocalSyncState.waitingForConnection;

  /// Whether a transfer is in progress
  bool get isTransferring => syncState == LocalSyncState.transferring;

  /// Whether sync completed successfully
  bool get isCompleted => syncState == LocalSyncState.completed;

  /// Whether sync failed
  bool get isFailed => syncState == LocalSyncState.failed;

  /// Whether any items are selected for selective sync
  bool get hasSelection =>
      selectedSessionIds.isNotEmpty ||
      selectedHuntIds.isNotEmpty ||
      selectedRouteIds.isNotEmpty;

  /// Total number of selected items
  int get selectedItemCount =>
      selectedSessionIds.length +
      selectedHuntIds.length +
      selectedRouteIds.length;

  LocalSyncProviderState copyWith({
    LocalSyncState? syncState,
    SyncRole? role,
    String? qrCodeData,
    SyncInfo? remoteDeviceInfo,
    SyncManifest? manifest,
    SyncProgress? progress,
    SyncResult? result,
    String? error,
    Duration? sessionTimeRemaining,
    List<DiscoveredDevice>? discoveredDevices,
    List<UnresolvedDevice>? unresolvedDevices,
    bool? isDiscovering,
    SyncManifest? availableItems,
    Set<String>? selectedSessionIds,
    Set<String>? selectedHuntIds,
    Set<String>? selectedRouteIds,
    bool clearRole = false,
    bool clearQrCode = false,
    bool clearRemoteDeviceInfo = false,
    bool clearManifest = false,
    bool clearProgress = false,
    bool clearResult = false,
    bool clearError = false,
    bool clearSessionTime = false,
    bool clearDiscoveredDevices = false,
    bool clearUnresolvedDevices = false,
    bool clearAvailableItems = false,
    bool clearSelection = false,
  }) {
    return LocalSyncProviderState(
      syncState: syncState ?? this.syncState,
      role: clearRole ? null : (role ?? this.role),
      qrCodeData: clearQrCode ? null : (qrCodeData ?? this.qrCodeData),
      remoteDeviceInfo: clearRemoteDeviceInfo
          ? null
          : (remoteDeviceInfo ?? this.remoteDeviceInfo),
      manifest: clearManifest ? null : (manifest ?? this.manifest),
      progress: clearProgress ? null : (progress ?? this.progress),
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
      sessionTimeRemaining: clearSessionTime
          ? null
          : (sessionTimeRemaining ?? this.sessionTimeRemaining),
      discoveredDevices: clearDiscoveredDevices
          ? const []
          : (discoveredDevices ?? this.discoveredDevices),
      unresolvedDevices: clearUnresolvedDevices
          ? const []
          : (unresolvedDevices ?? this.unresolvedDevices),
      isDiscovering: isDiscovering ?? this.isDiscovering,
      availableItems: clearAvailableItems
          ? null
          : (availableItems ?? this.availableItems),
      selectedSessionIds: clearSelection
          ? const <String>{}
          : (selectedSessionIds ?? this.selectedSessionIds),
      selectedHuntIds: clearSelection
          ? const <String>{}
          : (selectedHuntIds ?? this.selectedHuntIds),
      selectedRouteIds: clearSelection
          ? const <String>{}
          : (selectedRouteIds ?? this.selectedRouteIds),
    );
  }
}

/// Notifier for local sync state
class LocalSyncNotifier extends Notifier<LocalSyncProviderState> {
  late final LocalSyncService _syncService;

  @override
  LocalSyncProviderState build() {
    _syncService = LocalSyncService();

    // Set up callbacks
    _syncService.onStateChange = _handleStateChange;
    _syncService.onProgress = _handleProgress;
    _syncService.onComplete = _handleComplete;
    _syncService.onDevicesChanged = _handleDevicesChanged;
    _syncService.onUnresolvedDevice = _handleUnresolvedDevice;

    return const LocalSyncProviderState();
  }

  void _handleDevicesChanged(List<DiscoveredDevice> devices) {
    state = state.copyWith(discoveredDevices: devices);
  }

  void _handleUnresolvedDevice(UnresolvedDevice device) {
    // Add to list of unresolved devices (avoid duplicates by name)
    final existing = state.unresolvedDevices.where((d) => d.name != device.name).toList();
    state = state.copyWith(unresolvedDevices: [...existing, device]);
  }

  void _handleStateChange(LocalSyncState newState) {
    state = state.copyWith(syncState: newState);
  }

  void _handleProgress(SyncProgress progress) {
    state = state.copyWith(progress: progress);
  }

  void _handleComplete(SyncResult result) {
    try {
      debugPrint('LocalSyncNotifier: _handleComplete called with success=${result.success}');
      debugPrint('LocalSyncNotifier: Current state before update: ${state.syncState}');
      final newState = state.copyWith(
        result: result,
        syncState: result.success
            ? LocalSyncState.completed
            : LocalSyncState.failed,
        error: result.error,
      );
      debugPrint('LocalSyncNotifier: New state object syncState: ${newState.syncState}');
      state = newState;
      debugPrint('LocalSyncNotifier: State assigned, verifying: ${state.syncState}');
    } catch (e, stackTrace) {
      debugPrint('LocalSyncNotifier: ERROR in _handleComplete: $e');
      debugPrint('LocalSyncNotifier: Stack trace: $stackTrace');
    }
  }

  // ============================================================
  // Sender Actions
  // ============================================================

  /// Start a new send session
  ///
  /// [password] - Password for encrypting the backup
  /// [syncType] - Full backup or selective sync
  /// [useSelection] - If true and items are selected, use selective sync
  Future<void> startSendSession({
    required String password,
    SyncType syncType = SyncType.fullBackup,
    bool useSelection = false,
  }) async {
    try {
      state = state.copyWith(
        syncState: LocalSyncState.preparing,
        role: SyncRole.sender,
        clearError: true,
        clearResult: true,
        clearProgress: true,
      );

      // Get selection if using selective sync
      final selection = useSelection ? getSelectionRequest() : null;

      final qrData = await _syncService.startSendSession(
        password: password,
        syncType: selection != null ? SyncType.selective : syncType,
        selection: selection,
      );

      state = state.copyWith(
        qrCodeData: qrData,
        syncState: LocalSyncState.waitingForConnection,
      );

      // Start timer update loop
      _updateSessionTime();
    } catch (e) {
      state = state.copyWith(
        syncState: LocalSyncState.failed,
        error: e is LocalSyncException ? e.userMessage : e.toString(),
      );
    }
  }

  /// Update session time remaining
  void _updateSessionTime() {
    final remaining = _syncService.getSessionTimeRemaining();
    if (remaining != null && state.role == SyncRole.sender) {
      state = state.copyWith(sessionTimeRemaining: remaining);

      // Continue updating every second if still waiting
      if (remaining > Duration.zero &&
          state.syncState == LocalSyncState.waitingForConnection) {
        Future.delayed(const Duration(seconds: 1), _updateSessionTime);
      }
    }
  }

  // ============================================================
  // Sender Selection (for selective sync)
  // ============================================================

  /// Load available items from local database for selection UI
  Future<void> loadAvailableItems() async {
    try {
      final manifest = await _syncService.getLocalManifest();
      state = state.copyWith(availableItems: manifest);
    } catch (e) {
      state = state.copyWith(
        error: e is LocalSyncException ? e.userMessage : e.toString(),
      );
    }
  }

  /// Toggle selection of a session
  void toggleSessionSelection(String sessionId) {
    final current = Set<String>.from(state.selectedSessionIds);
    if (current.contains(sessionId)) {
      current.remove(sessionId);
    } else {
      current.add(sessionId);
    }
    state = state.copyWith(selectedSessionIds: current);
  }

  /// Toggle selection of a hunt
  void toggleHuntSelection(String huntId) {
    final current = Set<String>.from(state.selectedHuntIds);
    if (current.contains(huntId)) {
      current.remove(huntId);
    } else {
      current.add(huntId);
    }
    state = state.copyWith(selectedHuntIds: current);
  }

  /// Toggle selection of a route
  void toggleRouteSelection(String routeId) {
    final current = Set<String>.from(state.selectedRouteIds);
    if (current.contains(routeId)) {
      current.remove(routeId);
    } else {
      current.add(routeId);
    }
    state = state.copyWith(selectedRouteIds: current);
  }

  /// Select all sessions
  void selectAllSessions() {
    if (state.availableItems == null) return;
    final allIds = state.availableItems!.sessions.map((s) => s.id).toSet();
    state = state.copyWith(selectedSessionIds: allIds);
  }

  /// Deselect all sessions
  void deselectAllSessions() {
    state = state.copyWith(selectedSessionIds: const <String>{});
  }

  /// Select all hunts
  void selectAllHunts() {
    if (state.availableItems == null) return;
    final allIds = state.availableItems!.hunts.map((h) => h.id).toSet();
    state = state.copyWith(selectedHuntIds: allIds);
  }

  /// Deselect all hunts
  void deselectAllHunts() {
    state = state.copyWith(selectedHuntIds: const <String>{});
  }

  /// Select all routes
  void selectAllRoutes() {
    if (state.availableItems == null) return;
    final allIds = state.availableItems!.routes.map((r) => r.id).toSet();
    state = state.copyWith(selectedRouteIds: allIds);
  }

  /// Deselect all routes
  void deselectAllRoutes() {
    state = state.copyWith(selectedRouteIds: const <String>{});
  }

  /// Clear all selections
  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }

  /// Get the current selection as a SelectiveSyncRequest
  ///
  /// For selective sync, we use empty lists to mean "include nothing"
  /// (not null which means "include all"). This ensures only selected
  /// items are transferred.
  SelectiveSyncRequest? getSelectionRequest() {
    if (!state.hasSelection) return null;
    return SelectiveSyncRequest(
      // Use empty list if none selected (not null, which means "all")
      sessionIds: state.selectedSessionIds.toList(),
      huntIds: state.selectedHuntIds.toList(),
      routeIds: state.selectedRouteIds.toList(),
      // Password not needed for sender-side selection
    );
  }

  // ============================================================
  // Receiver Actions
  // ============================================================

  /// Start discovering nearby devices
  Future<void> startDiscovery() async {
    try {
      state = state.copyWith(
        isDiscovering: true,
        clearDiscoveredDevices: true,
        clearUnresolvedDevices: true,
        clearError: true,
      );
      await _syncService.startDiscovery();
    } catch (e) {
      state = state.copyWith(
        isDiscovering: false,
        error: e is LocalSyncException ? e.userMessage : e.toString(),
      );
    }
  }

  /// Stop discovering
  Future<void> stopDiscovery() async {
    await _syncService.stopDiscovery();
    state = state.copyWith(
      isDiscovering: false,
      clearDiscoveredDevices: true,
    );
  }

  /// Connect to a discovered device
  Future<void> connectToDiscoveredDevice(DiscoveredDevice device) async {
    try {
      state = state.copyWith(
        syncState: LocalSyncState.preparing,
        role: SyncRole.receiver,
        isDiscovering: false,
        clearError: true,
        clearResult: true,
        clearProgress: true,
      );

      final info = await _syncService.connectToDiscoveredDevice(device);

      state = state.copyWith(
        remoteDeviceInfo: info,
        syncState: LocalSyncState.connected,
      );
    } catch (e) {
      state = state.copyWith(
        syncState: LocalSyncState.failed,
        error: e is LocalSyncException ? e.userMessage : e.toString(),
      );
    }
  }

  /// Connect to a sender using QR code data (fallback)
  Future<void> connectToSender(String qrData) async {
    try {
      state = state.copyWith(
        syncState: LocalSyncState.preparing,
        role: SyncRole.receiver,
        clearError: true,
        clearResult: true,
        clearProgress: true,
      );

      final info = await _syncService.connectToSender(qrData);

      state = state.copyWith(
        remoteDeviceInfo: info,
        syncState: LocalSyncState.connected,
      );
    } catch (e) {
      state = state.copyWith(
        syncState: LocalSyncState.failed,
        error: e is LocalSyncException ? e.userMessage : e.toString(),
      );
    }
  }

  /// Get manifest of available items from sender
  Future<void> loadManifest() async {
    try {
      final manifest = await _syncService.getManifest();
      state = state.copyWith(manifest: manifest);
    } catch (e) {
      state = state.copyWith(
        error: e is LocalSyncException ? e.userMessage : e.toString(),
      );
    }
  }

  /// Start receiving data from sender
  Future<void> startReceive({
    required String password,
    required MergeStrategy mergeStrategy,
    SelectiveSyncRequest? selection,
  }) async {
    try {
      state = state.copyWith(
        syncState: LocalSyncState.transferring,
        clearError: true,
      );

      await _syncService.startReceive(
        password: password,
        mergeStrategy: mergeStrategy,
        selection: selection,
      );
    } catch (e) {
      state = state.copyWith(
        syncState: LocalSyncState.failed,
        error: e is LocalSyncException ? e.userMessage : e.toString(),
      );
    }
  }

  // ============================================================
  // Common Actions
  // ============================================================

  /// Cancel the current sync operation
  Future<void> cancelSync() async {
    await _syncService.cancelSync();
    state = const LocalSyncProviderState();
  }

  /// Reset state to idle
  void reset() {
    state = const LocalSyncProviderState();
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider for local sync state
final localSyncProvider =
    NotifierProvider<LocalSyncNotifier, LocalSyncProviderState>(
        LocalSyncNotifier.new);

/// Provider for sync service (for direct access if needed)
final localSyncServiceProvider =
    Provider<LocalSyncService>((ref) => LocalSyncService());
