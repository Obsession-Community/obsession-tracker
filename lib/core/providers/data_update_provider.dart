import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/bff_app_config.dart';
import 'package:obsession_tracker/core/services/bff_config_service.dart';
import 'package:obsession_tracker/core/services/offline_land_rights_service.dart';

/// Per-type update info for a state
class StateTypeUpdateInfo {
  const StateTypeUpdateInfo({
    required this.stateCode,
    required this.dataType,
    required this.localVersion,
    required this.serverVersion,
  });

  final String stateCode;
  final DataType dataType;
  final String? localVersion;
  final String serverVersion;

  bool get needsUpdate => localVersion != serverVersion;
}

/// State representing data update availability
class DataUpdateState {
  const DataUpdateState({
    this.serverVersion = '',
    this.serverSource = '',
    this.serverDescription,
    this.outdatedStates = const [],
    this.perTypeUpdates = const {},
    this.serverVersions = const DataTypeVersions(),
    this.splitDownloadsAvailable = false,
    this.isLoading = false,
    this.lastChecked,
  });

  /// Current data version on server (e.g., "2025-01-15") - legacy combined version
  final String serverVersion;

  /// Data source identifier (e.g., "PAD-US-4.1")
  final String serverSource;

  /// Human-readable description of the update
  final String? serverDescription;

  /// List of state codes that have updates available (legacy - any type outdated)
  final List<String> outdatedStates;

  /// Per-type update tracking: {stateCode: {dataType: needsUpdate}}
  final Map<String, Map<DataType, bool>> perTypeUpdates;

  /// Server's per-type versions
  final DataTypeVersions serverVersions;

  /// Whether split downloads are available on server
  final bool splitDownloadsAvailable;

  /// Whether we're currently checking for updates
  final bool isLoading;

  /// When we last checked for updates
  final DateTime? lastChecked;

  /// Whether any downloaded states have updates available
  bool get hasUpdates => outdatedStates.isNotEmpty;

  /// Number of states with updates
  int get updateCount => outdatedStates.length;

  /// Get outdated data types for a specific state
  Set<DataType> getOutdatedTypesForState(String stateCode) {
    final updates = perTypeUpdates[stateCode.toUpperCase()];
    if (updates == null) return {};
    return updates.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toSet();
  }

  /// Check if a specific data type is outdated for a state
  bool isTypeOutdatedForState(String stateCode, DataType dataType) {
    return perTypeUpdates[stateCode.toUpperCase()]?[dataType] ?? false;
  }

  DataUpdateState copyWith({
    String? serverVersion,
    String? serverSource,
    String? serverDescription,
    List<String>? outdatedStates,
    Map<String, Map<DataType, bool>>? perTypeUpdates,
    DataTypeVersions? serverVersions,
    bool? splitDownloadsAvailable,
    bool? isLoading,
    DateTime? lastChecked,
    bool clearDescription = false,
  }) {
    return DataUpdateState(
      serverVersion: serverVersion ?? this.serverVersion,
      serverSource: serverSource ?? this.serverSource,
      serverDescription: clearDescription ? null : (serverDescription ?? this.serverDescription),
      outdatedStates: outdatedStates ?? this.outdatedStates,
      perTypeUpdates: perTypeUpdates ?? this.perTypeUpdates,
      serverVersions: serverVersions ?? this.serverVersions,
      splitDownloadsAvailable: splitDownloadsAvailable ?? this.splitDownloadsAvailable,
      isLoading: isLoading ?? this.isLoading,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}

/// Provider for tracking data update availability
final dataUpdateProvider =
    NotifierProvider<DataUpdateNotifier, DataUpdateState>(
        DataUpdateNotifier.new);

/// Simple provider to check if updates are available (for badges/indicators)
final hasDataUpdatesProvider = Provider<bool>((ref) {
  return ref.watch(dataUpdateProvider).hasUpdates;
});

/// Provider for the number of states with updates
final dataUpdateCountProvider = Provider<int>((ref) {
  return ref.watch(dataUpdateProvider).updateCount;
});

/// Notifier that manages data update checking
class DataUpdateNotifier extends Notifier<DataUpdateState> {
  final _configService = BFFConfigService.instance;
  final _offlineService = OfflineLandRightsService();

  @override
  DataUpdateState build() {
    // Check for updates on initialization
    Future.microtask(checkForUpdates);
    return const DataUpdateState();
  }

  /// Check if any downloaded states have updates available
  ///
  /// Uses per-type version comparison when split downloads are available.
  /// Falls back to legacy combined version comparison otherwise.
  Future<void> checkForUpdates() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      // Fetch config from BFF (uses cache if fresh)
      final config = await _configService.fetchConfig();

      // If no data version info, nothing to check
      if (!config.data.hasVersion) {
        debugPrint('📊 No data version info from server');
        state = state.copyWith(
          isLoading: false,
          lastChecked: DateTime.now(),
        );
        return;
      }

      final serverVersion = config.data.currentVersion;
      final serverVersions = config.data.versions;
      final splitAvailable = config.data.splitDownloadsAvailable;

      debugPrint('📊 Server data version: $serverVersion (${config.data.source})');
      debugPrint('📊 Per-type versions: land=${serverVersions.land}, trails=${serverVersions.trails}, historical=${serverVersions.historical}, cell=${serverVersions.cell}');
      debugPrint('📊 Split downloads available: $splitAvailable');
      debugPrint('📊 NOTE: If land version shows PAD-US-4.1 instead of PAD-US-4.1-LOD5 in dev mode, clear cache via Settings > Land Data > Check for Updates');

      // Get all downloaded states
      final downloadedStates = await _offlineService.getDownloadedStates();

      if (downloadedStates.isEmpty) {
        debugPrint('📊 No downloaded states to check');
        state = state.copyWith(
          serverVersion: serverVersion,
          serverSource: config.data.source,
          serverDescription: config.data.description,
          serverVersions: serverVersions,
          splitDownloadsAvailable: splitAvailable,
          outdatedStates: [],
          perTypeUpdates: {},
          isLoading: false,
          lastChecked: DateTime.now(),
        );
        return;
      }

      // Track per-type updates
      final outdated = <String>[];
      final perTypeUpdates = <String, Map<DataType, bool>>{};

      for (final stateInfo in downloadedStates) {
        final stateCode = stateInfo.stateCode.toUpperCase();
        final typeUpdates = <DataType, bool>{};
        var hasAnyUpdate = false;

        // Check land version - needs update if missing or outdated
        // Note: Old combined ZIPs may have versions like "PAD-US-4.1-GNIS"
        // which should be considered compatible with server "PAD-US-4.1"
        final localLandVersion = stateInfo.landVersion ?? stateInfo.dataVersion;
        final hasLandData = stateInfo.propertyCount > 0;
        final serverHasLand = serverVersions.land.isNotEmpty;
        final landVersionMatch = _versionsMatch(localLandVersion, serverVersions.land);
        final landNeedsUpdate = serverHasLand && (!hasLandData || !landVersionMatch);
        typeUpdates[DataType.land] = landNeedsUpdate;
        if (landNeedsUpdate) hasAnyUpdate = true;

        // Check trails version - needs update if version doesn't match
        // Note: Old combined ZIPs didn't track trails version separately
        // If we have trail data but no version, assume it's up to date
        // If version matches but no data, server has no data for this state (e.g., Hawaii)
        final localTrailsVersion = stateInfo.trailsVersion;
        final hasTrailsData = stateInfo.uniqueTrailCount > 0;
        final serverHasTrails = serverVersions.trails.isNotEmpty;
        final trailsVersionMatch = _versionsMatch(localTrailsVersion, serverVersions.trails) ||
            (hasTrailsData && localTrailsVersion == null); // Legacy: has data, no version
        // Only needs update if version doesn't match (not just missing data)
        final trailsNeedsUpdate = serverHasTrails && !trailsVersionMatch;
        typeUpdates[DataType.trails] = trailsNeedsUpdate;
        if (trailsNeedsUpdate) hasAnyUpdate = true;

        // Check historical version - needs update if version doesn't match
        // Note: Old combined ZIPs may have historical data without separate version tracking
        // If version matches but no data, server has no data for this state
        final localHistoricalVersion = stateInfo.historicalVersion;
        final hasHistoricalData = stateInfo.historicalPlacesCount > 0;
        final serverHasHistorical = serverVersions.historical.isNotEmpty;
        final historicalVersionMatch = _versionsMatch(localHistoricalVersion, serverVersions.historical) ||
            (hasHistoricalData && localHistoricalVersion == null); // Legacy: has data, no version
        // Only needs update if version doesn't match (not just missing data)
        final historicalNeedsUpdate = serverHasHistorical && !historicalVersionMatch;
        typeUpdates[DataType.historical] = historicalNeedsUpdate;
        if (historicalNeedsUpdate) hasAnyUpdate = true;

        // Check cell coverage version - needs update if version doesn't match
        final localCellVersion = stateInfo.cellVersion;
        final hasCellData = stateInfo.cellTowerCount > 0;
        final serverHasCell = serverVersions.cell.isNotEmpty;
        final cellVersionMatch = _versionsMatch(localCellVersion, serverVersions.cell) ||
            (hasCellData && localCellVersion == null); // Legacy: has data, no version
        final cellNeedsUpdate = serverHasCell && !cellVersionMatch;
        typeUpdates[DataType.cell] = cellNeedsUpdate;
        if (cellNeedsUpdate) hasAnyUpdate = true;

        // Debug: log detailed version info for first state
        if (downloadedStates.indexOf(stateInfo) == 0) {
          debugPrint('  🔍 $stateCode detailed:');
          debugPrint('     land: local="$localLandVersion" server="${serverVersions.land}" hasData=$hasLandData needs=$landNeedsUpdate');
          debugPrint('     trails: local="$localTrailsVersion" server="${serverVersions.trails}" hasData=$hasTrailsData needs=$trailsNeedsUpdate');
          debugPrint('     historical: local="$localHistoricalVersion" server="${serverVersions.historical}" hasData=$hasHistoricalData needs=$historicalNeedsUpdate');
          debugPrint('     cell: local="$localCellVersion" server="${serverVersions.cell}" hasData=$hasCellData needs=$cellNeedsUpdate');
        }

        perTypeUpdates[stateCode] = typeUpdates;

        if (hasAnyUpdate) {
          outdated.add(stateCode);
          debugPrint('  📦 $stateCode: updates needed - land:$landNeedsUpdate, trails:$trailsNeedsUpdate, historical:$historicalNeedsUpdate, cell:$cellNeedsUpdate');
        } else {
          debugPrint('  ✅ $stateCode: all types up to date');
        }
      }

      state = state.copyWith(
        serverVersion: serverVersion,
        serverSource: config.data.source,
        serverDescription: config.data.description,
        serverVersions: serverVersions,
        splitDownloadsAvailable: splitAvailable,
        outdatedStates: outdated,
        perTypeUpdates: perTypeUpdates,
        isLoading: false,
        lastChecked: DateTime.now(),
      );

      if (outdated.isNotEmpty) {
        debugPrint('📊 ${outdated.length} state(s) have updates available');
      } else {
        debugPrint('📊 All downloaded states are up to date');
      }
    } catch (e) {
      debugPrint('⚠️ Error checking for data updates: $e');
      state = state.copyWith(
        isLoading: false,
        lastChecked: DateTime.now(),
      );
    }
  }

  /// Force a fresh check (bypasses cache)
  Future<void> forceCheck() async {
    await _configService.clearCache();
    await checkForUpdates();
  }

  /// Check if a specific state has an update available
  bool hasUpdateForState(String stateCode) {
    return state.outdatedStates.contains(stateCode.toUpperCase());
  }

  /// Get outdated data types for a specific state
  Set<DataType> getOutdatedTypesForState(String stateCode) {
    return state.getOutdatedTypesForState(stateCode);
  }

  /// Mark a state as updated (after re-download)
  /// For legacy combined downloads, marks all types as updated.
  void markStateUpdated(String stateCode) {
    final upperCode = stateCode.toUpperCase();
    final updated = state.outdatedStates
        .where((s) => s != upperCode)
        .toList();

    // Remove from perTypeUpdates too
    final newPerTypeUpdates = Map<String, Map<DataType, bool>>.from(state.perTypeUpdates);
    newPerTypeUpdates.remove(upperCode);

    state = state.copyWith(
      outdatedStates: updated,
      perTypeUpdates: newPerTypeUpdates,
    );
  }

  /// Check if local version matches server version.
  /// Handles legacy versions like "PAD-US-4.1-GNIS" matching "PAD-US-4.1".
  bool _versionsMatch(String? localVersion, String serverVersion) {
    if (localVersion == null || localVersion.isEmpty) return false;
    if (serverVersion.isEmpty) return true; // No server version = nothing to compare

    // Exact match
    if (localVersion == serverVersion) return true;

    // Legacy combined ZIP versions may have suffixes like "-GNIS"
    // Consider "PAD-US-4.1-GNIS" as matching "PAD-US-4.1"
    if (localVersion.startsWith(serverVersion)) return true;

    return false;
  }

  /// Mark a specific data type as updated for a state
  void markTypeUpdatedForState(String stateCode, DataType dataType) {
    final upperCode = stateCode.toUpperCase();

    // Update perTypeUpdates
    final newPerTypeUpdates = Map<String, Map<DataType, bool>>.from(state.perTypeUpdates);
    final stateUpdates = Map<DataType, bool>.from(newPerTypeUpdates[upperCode] ?? {});
    stateUpdates[dataType] = false;
    newPerTypeUpdates[upperCode] = stateUpdates;

    // Check if all types are now up to date
    final allUpToDate = !stateUpdates.values.any((needsUpdate) => needsUpdate);

    // Update outdatedStates if all types are up to date
    List<String>? newOutdated;
    if (allUpToDate) {
      newOutdated = state.outdatedStates
          .where((s) => s != upperCode)
          .toList();
    }

    state = state.copyWith(
      outdatedStates: newOutdated,
      perTypeUpdates: newPerTypeUpdates,
    );
  }
}
