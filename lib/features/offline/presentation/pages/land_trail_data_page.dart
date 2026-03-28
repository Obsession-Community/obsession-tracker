import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/bff_app_config.dart';
import 'package:obsession_tracker/core/providers/data_update_provider.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/core/services/bff_mapping_service.dart';
import 'package:obsession_tracker/core/services/dynamic_land_data_service.dart';
import 'package:obsession_tracker/core/services/historical_maps_service.dart';
import 'package:obsession_tracker/core/services/offline_land_rights_service.dart';
import 'package:obsession_tracker/core/services/quadrangle_download_service.dart';
import 'package:obsession_tracker/core/services/state_download_manager.dart';
import 'package:obsession_tracker/features/offline/presentation/pages/historical_map_layers_page.dart';
import 'package:obsession_tracker/features/subscription/presentation/widgets/paywall_widget.dart';

/// Unified page for managing all map data downloads (land, trails, historical)
///
/// Shows all available states (continental U.S.) with their download status and allows:
/// - Downloading missing data types
/// - Updating outdated data types
/// - Bulk deletion via selection mode
class LandTrailDataPage extends ConsumerStatefulWidget {
  const LandTrailDataPage({super.key});

  @override
  ConsumerState<LandTrailDataPage> createState() => _LandTrailDataPageState();
}

class _LandTrailDataPageState extends ConsumerState<LandTrailDataPage> {
  final DynamicLandDataService _landDataService = DynamicLandDataService.instance;
  final OfflineLandRightsService _offlineService = OfflineLandRightsService();
  final StateDownloadManager _downloadManager = StateDownloadManager.instance;
  final HistoricalMapsService _historicalMapsService = HistoricalMapsService.instance;
  final QuadrangleDownloadService _quadrangleService = QuadrangleDownloadService.instance;

  StreamSubscription<DownloadManagerState>? _downloadSubscription;

  List<String> _availableStates = [];
  List<StateDownloadInfo> _downloadedStates = [];
  final Map<String, int> _stateSizes = {};
  bool _isLoading = true;

  // Download state from manager
  DownloadManagerState _downloadState = const DownloadManagerState();

  // Selection mode for deletion
  bool _isSelectionMode = false;
  final Set<String> _selectedForDeletion = {};

  // Deletion progress
  bool _isDeleting = false;
  int _deletionProgress = 0;
  int _deletionTotal = 0;

  // Historical maps state (legacy)
  List<DownloadedHistoricalMap> _downloadedHistoricalMaps = [];

  // Quadrangle download summaries per state
  final Map<String, QuadrangleDownloadSummary> _quadrangleSummaries = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToDownloads();
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToDownloads() {
    _downloadState = _downloadManager.state;
    _downloadSubscription = _downloadManager.stateStream.listen((state) async {
      if (mounted) {
        final wasDownloading = _downloadState.isDownloading;
        final previousCompletedCount = _downloadState.completedCount;
        setState(() => _downloadState = state);

        // Check if a new state just completed (not just the entire batch)
        final newStateCompleted = state.completedCount > previousCompletedCount;

        if (newStateCompleted) {
          // A state just finished - reload data and update the banner
          await _loadData();
          if (mounted) {
            await ref.read(dataUpdateProvider.notifier).checkForUpdates();
          }
        } else if (wasDownloading && !state.isDownloading) {
          // All downloads complete - final refresh
          await _loadData();
          if (mounted) {
            await ref.read(dataUpdateProvider.notifier).checkForUpdates();
          }
        }
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _availableStates = _landDataService.getAvailableStates();

      // Run all initializations in parallel
      await Future.wait([
        _offlineService.initialize(),
        _historicalMapsService.initialize(),
      ]);

      // Fetch all data in parallel (much faster than sequential)
      final (downloadedStates, stateSizes, historicalMaps) =
          await (
            _offlineService.getDownloadedStates(),
            _landDataService.getAllStateSizes(),
            _historicalMapsService.getDownloadedMaps(),
          ).wait;

      _downloadedStates = downloadedStates;
      _stateSizes
        ..clear()
        ..addAll(stateSizes);
      _downloadedHistoricalMaps = historicalMaps;

      // Load only LOCAL quadrangle data (no API calls - instant)
      // Full manifests are fetched on-demand when user taps Maps chip
      await _quadrangleService.initialize();
      _quadrangleSummaries.clear();
      for (final stateCode in _availableStates) {
        final downloaded = _quadrangleService.getDownloadedQuadranglesForState(stateCode);
        if (downloaded.isNotEmpty) {
          // Only create summary for states with downloaded quads (local data only)
          _quadrangleSummaries[stateCode] = QuadrangleDownloadSummary(
            stateCode: stateCode,
            totalAvailableQuads: 0, // Will be fetched on-demand
            downloadedQuads: downloaded.length,
            totalAvailableSize: 0,
            downloadedSize: downloaded.fold(0, (sum, q) => sum + q.sizeBytes),
            eras: [], // Full era info fetched on-demand
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool get _isDownloading => _downloadState.isDownloading;

  StateDownloadInfo? _getDownloadedState(String stateCode) {
    return _downloadedStates.where((s) => s.stateCode == stateCode).firstOrNull;
  }

  Future<void> _downloadStates(List<String> stateCodes, {bool forceRedownload = false}) async {
    // Check premium status
    final isPremium = ref.read(isPremiumProvider);
    if (!isPremium) {
      final upgraded = await showPaywall(
        context,
        title: 'Offline Downloads - Premium Feature',
      );
      if (upgraded != true) return;
    }

    // Check connectivity
    final isOnline = await BFFMappingService.instance.isOnline;
    if (!isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot download while offline'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // If this is an update (forceRedownload), use selective downloads to only
    // download the data types that are actually missing or outdated
    if (forceRedownload) {
      final updateState = ref.read(dataUpdateProvider);
      final serverVersions = updateState.serverVersions;
      final selectiveDownloads = <String, Set<DataType>>{};

      for (final stateCode in stateCodes) {
        final typesToDownload = <DataType>{};
        final downloadedState = _getDownloadedState(stateCode);

        if (downloadedState != null) {
          // Check each type for updates or missing data
          // Land
          final landNeedsUpdate = updateState.isTypeOutdatedForState(stateCode, DataType.land);
          final landMissing = serverVersions.land.isNotEmpty && downloadedState.propertyCount == 0;
          if (landNeedsUpdate || landMissing) {
            typesToDownload.add(DataType.land);
          }

          // Trails
          final trailsNeedsUpdate = updateState.isTypeOutdatedForState(stateCode, DataType.trails);
          final trailsMissing = serverVersions.trails.isNotEmpty && downloadedState.uniqueTrailCount == 0;
          if (trailsNeedsUpdate || trailsMissing) {
            typesToDownload.add(DataType.trails);
          }

          // Historical places
          final historicalNeedsUpdate = updateState.isTypeOutdatedForState(stateCode, DataType.historical);
          final historicalMissing = serverVersions.historical.isNotEmpty && downloadedState.historicalPlacesCount == 0;
          if (historicalNeedsUpdate || historicalMissing) {
            typesToDownload.add(DataType.historical);
          }

          // Cell coverage
          final cellNeedsUpdate = updateState.isTypeOutdatedForState(stateCode, DataType.cell);
          final cellMissing = serverVersions.cell.isNotEmpty && downloadedState.cellTowerCount == 0;
          if (cellNeedsUpdate || cellMissing) {
            typesToDownload.add(DataType.cell);
          }

          if (typesToDownload.isNotEmpty) {
            selectiveDownloads[stateCode] = typesToDownload;
            debugPrint('📦 $stateCode needs: ${typesToDownload.map((t) => t.name).join(', ')}');
          }
        } else {
          // State not downloaded at all - download everything
          selectiveDownloads[stateCode] = {DataType.land, DataType.trails, DataType.historical, DataType.cell};
          debugPrint('📦 $stateCode: fresh download (all types)');
        }
      }

      if (selectiveDownloads.isNotEmpty) {
        _downloadManager.startSelectiveDownloads(selectiveDownloads);
      }
    } else {
      // Fresh download - use standard method that downloads everything
      _downloadManager.startDownloads(stateCodes, forceRedownload: forceRedownload);
    }
  }

  Future<void> _deleteStates(List<String> stateCodes) async {
    if (stateCodes.isEmpty) return;

    // Get info for confirmation dialog
    final statesInfo = stateCodes
        .map(_getDownloadedState)
        .nonNulls
        .toList();

    if (statesInfo.isEmpty) return;

    final totalRecords = statesInfo.fold<int>(0, (sum, s) => sum + s.propertyCount);
    final totalTrails = statesInfo.fold<int>(0, (sum, s) => sum + s.uniqueTrailCount);
    final totalPlaces = statesInfo.fold<int>(0, (sum, s) => sum + s.historicalPlacesCount);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(stateCodes.length == 1 ? 'Delete State Data' : 'Delete ${stateCodes.length} States'),
        content: Text(
          stateCodes.length == 1
              ? 'Delete offline data for ${statesInfo.first.stateName}?\n\n'
                  '${statesInfo.first.propertyCount} land records'
                  '${statesInfo.first.uniqueTrailCount > 0 ? ', ${statesInfo.first.uniqueTrailCount} trails' : ''}'
                  '${statesInfo.first.historicalPlacesCount > 0 ? ', ${_formatNumber(statesInfo.first.historicalPlacesCount)} historical places' : ''}.'
              : 'Delete offline data for ${stateCodes.length} states?\n\n'
                  '• $totalRecords land records\n'
                  '${totalTrails > 0 ? '• $totalTrails trails\n' : ''}'
                  '${totalPlaces > 0 ? '• ${_formatNumber(totalPlaces)} historical places\n' : ''}\n'
                  'You will need to redownload to use offline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show deletion progress
      setState(() {
        _isDeleting = true;
        _deletionProgress = 0;
        _deletionTotal = stateCodes.length;
      });

      try {
        for (final stateCode in stateCodes) {
          await _offlineService.deleteStateData(stateCode);
          BFFMappingService.instance.clearTrailsCache(stateCode);
          if (mounted) {
            setState(() => _deletionProgress++);
          }
        }
        await _loadData();
        // Refresh the data update provider to reflect deleted states
        if (mounted) {
          await ref.read(dataUpdateProvider.notifier).checkForUpdates();
        }
        _exitSelectionMode();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(stateCodes.length == 1
                  ? 'Deleted ${statesInfo.first.stateName} data'
                  : 'Deleted ${stateCodes.length} states'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isDeleting = false);
        }
      }
    }
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedForDeletion.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedForDeletion.clear();
    });
  }

  void _toggleSelection(String stateCode) {
    setState(() {
      if (_selectedForDeletion.contains(stateCode)) {
        _selectedForDeletion.remove(stateCode);
      } else {
        _selectedForDeletion.add(stateCode);
      }
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(dataUpdateProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final hasDownloadedStates = _downloadedStates.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode
            ? '${_selectedForDeletion.length} selected'
            : 'Map Data'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: _isSelectionMode
            ? [
                // Select all downloaded states
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: () {
                    setState(() {
                      _selectedForDeletion.addAll(
                        _downloadedStates.map((s) => s.stateCode),
                      );
                    });
                  },
                  tooltip: 'Select All',
                ),
                // Delete selected
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _selectedForDeletion.isEmpty
                      ? null
                      : () => _deleteStates(_selectedForDeletion.toList()),
                  tooltip: 'Delete Selected',
                ),
              ]
            : [
                // Enter selection mode (only if there are downloaded states)
                if (hasDownloadedStates)
                  IconButton(
                    icon: const Icon(Icons.checklist),
                    onPressed: _enterSelectionMode,
                    tooltip: 'Select for Deletion',
                  ),
                // Refresh (also clears manifest cache)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    // Clear cached manifests so fresh data is fetched from server
                    _quadrangleService.clearManifestCache();
                    _loadData();
                    ref.read(dataUpdateProvider.notifier).forceCheck();
                  },
                  tooltip: 'Refresh',
                ),
              ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Premium upsell banner for free users
                if (!isPremium) _buildPremiumUpsellBanner(),

                // Update banner (when not in selection mode and user is premium)
                if (!_isSelectionMode && isPremium) _buildUpdateBanner(updateState),

                // Download progress (if downloading)
                if (_isDownloading) _buildDownloadProgress(),

                // Deletion progress (if deleting)
                if (_isDeleting) _buildDeletionProgress(),

                // Storage summary
                _buildStorageSummary(updateState),

                // All states list
                Expanded(
                  child: _buildStatesList(updateState, isPremium),
                ),
              ],
            ),
    );
  }

  Widget _buildPremiumUpsellBanner() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: Colors.amber.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Colors.amber,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premium Feature',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.amber[800],
                        ),
                  ),
                  Text(
                    'Offline map data requires a premium subscription',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.amber[700],
                        ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                await showPaywall(context, title: 'Unlock Offline Maps');
              },
              child: const Text('Upgrade'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateBanner(DataUpdateState updateState) {
    if (!updateState.hasUpdates || updateState.isLoading) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: Colors.orange.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.system_update,
                color: Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Updates Available',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[800],
                        ),
                  ),
                  Text(
                    '${updateState.updateCount} state${updateState.updateCount > 1 ? 's have' : ' has'} newer data',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange[700],
                        ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                final outdated = updateState.outdatedStates;
                _downloadStates(outdated, forceRedownload: true);
              },
              child: const Text('Update All'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadProgress() {
    final completed = _downloadState.downloads.values
        .where((s) => s.status == StateDownloadStatus.completed)
        .length;
    final total = _downloadState.totalCount;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: Colors.blue.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Downloading $completed of $total states...',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: _downloadManager.cancelDownloads,
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? completed / total : 0,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            // Show current downloading state
            ..._downloadState.downloads.entries
                .where((e) => e.value.status == StateDownloadStatus.downloading)
                .map((e) => Text(
                      '${e.value.stateName}: ${e.value.message}',
                      style: Theme.of(context).textTheme.bodySmall,
                    )),
          ],
        ),
      ),
    );
  }

  Widget _buildDeletionProgress() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: Colors.red.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Deleting $_deletionProgress of $_deletionTotal states...',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _deletionTotal > 0 ? _deletionProgress / _deletionTotal : 0,
                minHeight: 6,
                backgroundColor: Colors.red.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageSummary(DataUpdateState updateState) {
    final serverVersions = updateState.serverVersions;
    final hasVersions = serverVersions.land.isNotEmpty ||
        serverVersions.trails.isNotEmpty ||
        serverVersions.historical.isNotEmpty ||
        serverVersions.cell.isNotEmpty;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: download status + updates count
            Row(
              children: [
                Icon(
                  Icons.cloud_done,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_downloadedStates.length} of ${_availableStates.length} states',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                if (updateState.hasUpdates)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${updateState.updateCount} update${updateState.updateCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),

            // Version info row
            if (hasVersions) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildVersionBadge(
                    'Land',
                    serverVersions.land,
                    Icons.landscape,
                    Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _buildVersionBadge(
                    'Trails',
                    serverVersions.trails,
                    Icons.hiking,
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildVersionBadge(
                    'Places',
                    serverVersions.historical,
                    Icons.place,
                    Colors.orange,
                  ),
                  if (serverVersions.cell.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _buildVersionBadge(
                      'Cell',
                      serverVersions.cell,
                      Icons.cell_tower,
                      Colors.blue,
                    ),
                  ],
                ],
              ),
            ],

            // Historical maps row (if any quadrangles downloaded)
            if (_downloadedHistoricalMaps.isNotEmpty ||
                _quadrangleSummaries.values.any((s) => s.downloadedQuads > 0)) ...[
              const SizedBox(height: 8),
              _buildHistoricalMapsSummary(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVersionBadge(String label, String version, IconData icon, Color color) {
    if (version.isEmpty) {
      return const SizedBox.shrink();
    }

    // Simplify version display
    String displayVersion = version;
    if (version.startsWith('PAD-US-')) {
      displayVersion = version.replaceFirst('PAD-US-', '');
    } else if (version.startsWith('GNIS-')) {
      displayVersion = version.replaceFirst('GNIS-', '');
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'v$displayVersion',
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build summary row for downloaded historical maps (quadrangles)
  Widget _buildHistoricalMapsSummary() {
    // Calculate totals from quadrangle summaries
    int totalQuadsDownloaded = 0;
    int totalQuadsAvailable = 0;
    int totalSize = 0;
    final statesWithDownloads = <String>[];

    for (final entry in _quadrangleSummaries.entries) {
      final summary = entry.value;
      totalQuadsAvailable += summary.totalAvailableQuads;
      totalQuadsDownloaded += summary.downloadedQuads;
      totalSize += summary.downloadedSize;
      if (summary.downloadedQuads > 0) {
        statesWithDownloads.add(entry.key);
      }
    }

    // Also include legacy historical maps if any
    for (final map in _downloadedHistoricalMaps) {
      totalSize += map.sizeBytes;
    }

    if (totalQuadsDownloaded == 0 && _downloadedHistoricalMaps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.history, size: 14, color: Colors.purple[700]),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Historical Maps',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.purple[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$totalQuadsDownloaded${totalQuadsAvailable > 0 ? '/$totalQuadsAvailable' : ''} quadrangle${totalQuadsDownloaded != 1 ? 's' : ''} • '
                  '${statesWithDownloads.length} state${statesWithDownloads.length != 1 ? 's' : ''} • '
                  '${_formatFileSize(totalSize)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.purple[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatesList(DataUpdateState updateState, bool isPremium) {
    // In selection mode, only show downloaded states
    final statesToShow = _isSelectionMode
        ? _downloadedStates.map((s) => s.stateCode).toList()
        : _availableStates;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: statesToShow.length,
      itemBuilder: (context, index) {
        final stateCode = statesToShow[index];
        return _buildStateCard(stateCode, updateState, isPremium);
      },
    );
  }

  Widget _buildStateCard(String stateCode, DataUpdateState updateState, bool isPremium) {
    final stateInfo = DynamicLandDataService.availableStates[stateCode];
    final downloadedState = _getDownloadedState(stateCode);
    final isDownloaded = downloadedState != null;

    // Check download/update status per type
    final outdatedTypes = updateState.getOutdatedTypesForState(stateCode);
    final serverVersions = updateState.serverVersions;

    // Check for missing data types (server has data, local doesn't)
    bool hasMissingTypes = false;
    if (downloadedState != null) {
      hasMissingTypes =
        (serverVersions.land.isNotEmpty && downloadedState.propertyCount == 0) ||
        (serverVersions.trails.isNotEmpty && downloadedState.uniqueTrailCount == 0) ||
        (serverVersions.historical.isNotEmpty && downloadedState.historicalPlacesCount == 0);
    }

    // Determine what action is needed
    final needsAnyDownload = !isDownloaded;
    final needsAnyUpdate = outdatedTypes.isNotEmpty || hasMissingTypes;
    final needsAction = needsAnyDownload || needsAnyUpdate;

    // Check if currently downloading
    final downloadProgress = _downloadState.downloads[stateCode];
    final isCurrentlyDownloading = downloadProgress?.status == StateDownloadStatus.downloading;
    final isPending = downloadProgress?.status == StateDownloadStatus.pending;

    // Selection mode check
    final isSelectedForDeletion = _selectedForDeletion.contains(stateCode);
    final canSelect = _isSelectionMode && isDownloaded;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: canSelect ? () => _toggleSelection(stateCode) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Selection checkbox or state avatar
              if (_isSelectionMode)
                Checkbox(
                  value: isSelectedForDeletion,
                  onChanged: isDownloaded
                      ? (value) => _toggleSelection(stateCode)
                      : null,
                )
              else
                CircleAvatar(
                  backgroundColor: isDownloaded
                      ? (needsAnyUpdate ? Colors.orange : Colors.green)
                      : Colors.grey[300],
                  radius: 20,
                  child: Text(
                    stateCode,
                    style: TextStyle(
                      color: isDownloaded ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),

              const SizedBox(width: 12),

              // State info and type status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stateInfo?.name ?? stateCode,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    // Type status row
                    _buildTypeStatusRow(
                      downloadedState: downloadedState,
                      outdatedTypes: outdatedTypes,
                      serverVersions: serverVersions,
                      stateCode: stateCode,
                    ),
                  ],
                ),
              ),

              // Action button (not in selection mode)
              if (!_isSelectionMode)
                _buildActionButton(
                  stateCode: stateCode,
                  isDownloaded: isDownloaded,
                  needsAction: needsAction,
                  needsAnyUpdate: needsAnyUpdate,
                  isCurrentlyDownloading: isCurrentlyDownloading,
                  isPending: isPending,
                  isPremium: isPremium,
                  downloadProgress: downloadProgress,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeStatusRow({
    required StateDownloadInfo? downloadedState,
    required Set<DataType> outdatedTypes,
    required DataTypeVersions serverVersions,
    required String stateCode,
  }) {
    final isDownloaded = downloadedState != null;

    if (!isDownloaded) {
      // Not downloaded - show what's available
      final size = _stateSizes[stateCode] ?? 0;
      return Text(
        'Not downloaded • Est. ${_formatFileSize(size)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
      );
    }

    // Downloaded - show per-type status
    // Check what's available on server
    final serverHasLand = serverVersions.land.isNotEmpty;
    final serverHasTrails = serverVersions.trails.isNotEmpty;
    final serverHasHistorical = serverVersions.historical.isNotEmpty;
    final serverHasCell = serverVersions.cell.isNotEmpty;

    // Get quadrangle summary for this state
    final quadSummary = _quadrangleSummaries[stateCode];

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _buildTypeChip(
          label: 'Land',
          hasData: downloadedState.propertyCount > 0,
          needsUpdate: outdatedTypes.contains(DataType.land),
          serverHasData: serverHasLand,
          count: '${downloadedState.propertyCount}',
        ),
        _buildTypeChip(
          label: 'Trails',
          hasData: downloadedState.uniqueTrailCount > 0,
          needsUpdate: outdatedTypes.contains(DataType.trails),
          serverHasData: serverHasTrails,
          count: '${downloadedState.uniqueTrailCount}',
        ),
        _buildTypeChip(
          label: 'Places',
          hasData: downloadedState.historicalPlacesCount > 0,
          needsUpdate: outdatedTypes.contains(DataType.historical),
          serverHasData: serverHasHistorical,
          count: _formatNumber(downloadedState.historicalPlacesCount),
        ),
        if (serverHasCell || downloadedState.cellTowerCount > 0)
          _buildTypeChip(
            label: 'Cell',
            hasData: downloadedState.cellTowerCount > 0,
            needsUpdate: outdatedTypes.contains(DataType.cell),
            serverHasData: serverHasCell,
            count: _formatNumber(downloadedState.cellTowerCount),
          ),
        // Historical maps - navigates to quad selection page
        // Show chip if user has downloaded quads OR if we know quads are available
        if (quadSummary != null &&
            (quadSummary.downloadedQuads > 0 || quadSummary.totalAvailableQuads > 0))
          _buildHistoricalMapsChip(
            stateCode: stateCode,
            stateName: DynamicLandDataService.availableStates[stateCode]?.name ?? stateCode,
            summary: quadSummary,
          ),
      ],
    );
  }

  /// Build a chip for historical maps that navigates to the quad selection page
  Widget _buildHistoricalMapsChip({
    required String stateCode,
    required String stateName,
    required QuadrangleDownloadSummary summary,
  }) {
    final hasDownloads = summary.downloadedQuads > 0;
    final eraCount = summary.eras.length;

    Color backgroundColor;
    Color textColor;
    IconData icon;

    if (hasDownloads) {
      // Has some downloads - purple with partial fill appearance
      backgroundColor = Colors.purple.withValues(alpha: 0.15);
      textColor = Colors.purple[700]!;
      icon = Icons.map;
    } else {
      // Nothing downloaded yet - grey/purple hint
      backgroundColor = Colors.purple.withValues(alpha: 0.08);
      textColor = Colors.purple[400]!;
      icon = Icons.map_outlined;
    }

    // Build display text
    String displayText;
    if (hasDownloads && summary.totalAvailableQuads > 0) {
      // Full info available (fetched from API)
      displayText = 'Maps: ${summary.downloadedQuads}/${summary.totalAvailableQuads}';
    } else if (hasDownloads) {
      // Only local info (fast load - API not yet called)
      displayText = 'Maps: ${summary.downloadedQuads}';
    } else if (eraCount > 0) {
      displayText = 'Maps: $eraCount era${eraCount > 1 ? 's' : ''}';
    } else {
      displayText = 'Maps';
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => HistoricalMapLayersPage(
              stateCode: stateCode,
              stateName: stateName,
            ),
          ),
        ).then((_) {
          // Refresh data when returning from the page
          _loadData();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: textColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
            Text(
              displayText,
              style: TextStyle(
                fontSize: 11,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 14, color: textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required bool hasData,
    required bool needsUpdate,
    required bool serverHasData,
    required String count,
  }) {
    Color backgroundColor;
    Color textColor;
    IconData? icon;
    String displayText;

    if (!hasData && !serverHasData) {
      // Server doesn't have this data type - grey
      backgroundColor = Colors.grey[200]!;
      textColor = Colors.grey[500]!;
      displayText = label;
    } else if (!hasData && serverHasData) {
      // Not downloaded but available on server - blue (downloadable)
      backgroundColor = Colors.blue.withValues(alpha: 0.15);
      textColor = Colors.blue[700]!;
      icon = Icons.download;
      displayText = label;
    } else if (needsUpdate) {
      // Has data but update available - orange
      backgroundColor = Colors.orange.withValues(alpha: 0.2);
      textColor = Colors.orange[800]!;
      icon = Icons.arrow_upward;
      displayText = '$label: $count';
    } else {
      // Has data and up to date - green
      backgroundColor = Colors.green.withValues(alpha: 0.15);
      textColor = Colors.green[700]!;
      icon = Icons.check;
      displayText = '$label: $count';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            displayText,
            style: TextStyle(
              fontSize: 11,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String stateCode,
    required bool isDownloaded,
    required bool needsAction,
    required bool needsAnyUpdate,
    required bool isCurrentlyDownloading,
    required bool isPending,
    required bool isPremium,
    required StateDownloadProgress? downloadProgress,
  }) {
    if (isCurrentlyDownloading) {
      return SizedBox(
        width: 48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 4),
            Text(
              downloadProgress?.message ?? '',
              style: const TextStyle(fontSize: 9),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    if (isPending) {
      return const SizedBox(
        width: 48,
        child: Center(
          child: Icon(Icons.hourglass_empty, color: Colors.grey),
        ),
      );
    }

    if (!needsAction) {
      // Fully up to date - show checkmark
      return const SizedBox(
        width: 48,
        child: Center(
          child: Icon(Icons.check_circle, color: Colors.green),
        ),
      );
    }

    // Show download/update button
    return IconButton(
      icon: Icon(
        isPremium
            ? (needsAnyUpdate ? Icons.sync : Icons.download)
            : Icons.lock,
        color: isPremium
            ? (needsAnyUpdate ? Colors.orange : Colors.blue)
            : Colors.grey,
      ),
      onPressed: _isDownloading
          ? null
          : () => _downloadStates([stateCode], forceRedownload: needsAnyUpdate),
      tooltip: isPremium
          ? (needsAnyUpdate ? 'Update' : 'Download')
          : 'Premium Required',
    );
  }
}
