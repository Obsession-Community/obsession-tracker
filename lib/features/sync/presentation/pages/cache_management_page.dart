import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/services/bff_mapping_service.dart';
import 'package:obsession_tracker/core/services/offline_cache_service.dart';
import 'package:obsession_tracker/core/services/offline_land_rights_service.dart';
import 'package:obsession_tracker/features/offline/presentation/pages/offline_areas_page.dart';
import 'package:obsession_tracker/features/sync/presentation/widgets/sync_status_indicator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CacheManagementPage extends StatefulWidget {
  const CacheManagementPage({super.key});

  @override
  State<CacheManagementPage> createState() => _CacheManagementPageState();
}

class _CacheManagementPageState extends State<CacheManagementPage> {
  final OfflineLandRightsService _offlineService = OfflineLandRightsService();
  
  bool _isLoading = false;
  int _totalProperties = 0;
  int _cachedProperties = 0;
  DateTime? _lastSyncTime;
  String _cacheSize = '0 MB';
  List<DownloadArea> _downloadAreas = [];
  
  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }
  
  Future<void> _loadCacheStats() async {
    setState(() => _isLoading = true);
    
    try {
      await _offlineService.initialize();
      
      final areas = await _offlineService.getDownloadAreas();
      final cachedCount = await _offlineService.getCachedPropertyCount();
      final cacheSize = await _offlineService.getCacheSizeString();
      final lastSync = await _offlineService.getLastSyncTime();
      
      setState(() {
        _downloadAreas = areas;
        _cachedProperties = cachedCount;
        _totalProperties = areas.fold(0, (sum, area) => sum + (area.propertyCount ?? 0));
        _cacheSize = cacheSize;
        _lastSyncTime = lastSync;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load cache stats: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _clearAllCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Cache'),
        content: const Text(
          'This will delete all cached property data and download areas. '
          "You'll need to download areas again for offline use.\n\n"
          'Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _offlineService.clearAllCache();
        await _loadCacheStats();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cache cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear cache: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  Future<void> _syncNow() async {
    setState(() => _isLoading = true);

    try {
      // Get all cached areas and refresh them
      final cacheService = OfflineCacheService();
      final cachedAreas = await cacheService.getCachedAreas();

      if (cachedAreas.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No cached areas to sync'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      int successCount = 0;
      int failureCount = 0;

      for (final cacheInfo in cachedAreas) {
        try {
          // Fetch fresh data from BFF
          final radiusDegrees = cacheInfo.radiusKm / 111.0;
          final landData = await BFFMappingService.instance.getComprehensiveLandRightsDataWithRetry(
            northBound: cacheInfo.centerLatitude + radiusDegrees,
            southBound: cacheInfo.centerLatitude - radiusDegrees,
            eastBound: cacheInfo.centerLongitude + radiusDegrees,
            westBound: cacheInfo.centerLongitude - radiusDegrees,
            limit: 500,
          );

          // Re-cache the area with fresh data
          final result = await cacheService.cacheAreaForOfflineUse(
            areaName: cacheInfo.areaName,
            centerLatitude: cacheInfo.centerLatitude,
            centerLongitude: cacheInfo.centerLongitude,
            radiusKm: cacheInfo.radiusKm,
            landData: landData,
          );

          if (result.success) {
            successCount++;
          } else {
            failureCount++;
          }
        } catch (e) {
          failureCount++;
          debugPrint('Failed to sync ${cacheInfo.areaName}: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync complete: $successCount succeeded, $failureCount failed',
            ),
            backgroundColor: failureCount == 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _optimizeCache() async {
    setState(() => _isLoading = true);
    
    try {
      await _offlineService.optimizeDatabase();
      await _loadCacheStats();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache optimized successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to optimize cache: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cache Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCacheStats,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }
  
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading cache statistics...'),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadCacheStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cache status overview
          CacheStatusCard(
            totalProperties: _totalProperties,
            cachedProperties: _cachedProperties,
            lastSyncTime: _lastSyncTime,
            cacheSize: _cacheSize,
            onClearCache: _clearAllCache,
            onSyncNow: _syncNow,
          ),
          const SizedBox(height: 16),
          
          // Download areas summary
          _buildDownloadAreasCard(),
          const SizedBox(height: 16),
          
          // Cache management tools
          _buildManagementToolsCard(),
          const SizedBox(height: 16),
          
          // Cache details
          _buildCacheDetailsCard(),
        ],
      ),
    );
  }
  
  Widget _buildDownloadAreasCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download),
                const SizedBox(width: 8),
                Text(
                  'Download Areas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const OfflineAreasPage(),
                    ),
                  ),
                  child: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (_downloadAreas.isEmpty) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.offline_pin, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No download areas'),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ...(_downloadAreas.take(3).map((area) => ListTile(
                leading: Icon(
                  area.status == DownloadStatus.completed 
                      ? Icons.check_circle 
                      : Icons.schedule,
                  color: area.status == DownloadStatus.completed 
                      ? Colors.green 
                      : Colors.orange,
                ),
                title: Text(area.name),
                subtitle: Text(
                  '${area.radiusKm} km radius • '
                  '${area.propertyCount ?? 0} properties'
                ),
                trailing: Text(
                  _formatFileSize(area.estimatedSizeBytes ?? 0),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                contentPadding: EdgeInsets.zero,
              )).toList()),
              
              if (_downloadAreas.length > 3) ...[
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const OfflineAreasPage(),
                      ),
                    ),
                    child: Text('View all ${_downloadAreas.length} areas'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildManagementToolsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build),
                const SizedBox(width: 8),
                Text(
                  'Management Tools',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Optimize cache
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Optimize Cache'),
              subtitle: const Text('Compact database and remove orphaned data'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _optimizeCache,
              contentPadding: EdgeInsets.zero,
            ),
            
            // Export cache data
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('Export Cache Data'),
              subtitle: const Text('Create backup of cached properties'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _exportCache,
              contentPadding: EdgeInsets.zero,
            ),
            
            // Import cache data
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: const Text('Import Cache Data'),
              subtitle: const Text('Restore from backup file'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _importCache,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCacheDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 8),
                Text(
                  'Cache Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildDetailRow('Total Properties', _totalProperties.toString()),
            _buildDetailRow('Cached Properties', _cachedProperties.toString()),
            _buildDetailRow('Cache Size', _cacheSize),
            _buildDetailRow('Download Areas', _downloadAreas.length.toString()),
            _buildDetailRow(
              'Cache Hit Rate', 
              _totalProperties > 0 
                  ? '${((_cachedProperties / _totalProperties) * 100).toStringAsFixed(1)}%'
                  : 'N/A'
            ),
            _buildDetailRow(
              'Last Sync', 
              _lastSyncTime != null 
                  ? _formatLastSync(_lastSyncTime!)
                  : 'Never'
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} minutes ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';

    return '${lastSync.month}/${lastSync.day}/${lastSync.year}';
  }

  Future<void> _exportCache() async {
    setState(() => _isLoading = true);

    try {
      final cacheService = OfflineCacheService();
      final cachedAreas = await cacheService.getCachedAreas();

      if (cachedAreas.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No cached data to export'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Create export data structure
      final exportData = {
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'areas': cachedAreas.map((area) => {
          'areaName': area.areaName,
          'centerLatitude': area.centerLatitude,
          'centerLongitude': area.centerLongitude,
          'radiusKm': area.radiusKm,
          'cachedAt': area.cachedAt.toIso8601String(),
          'propertyCount': area.propertyCount,
        }).toList(),
      };

      // Convert to JSON and save
      final jsonContent = jsonEncode(exportData);
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'cache_export_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonContent);

      // Share the file
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Obsession Tracker Cache Export',
          text: 'Cache data backup from Obsession Tracker',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${cachedAreas.length} cached areas'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importCache() async {
    // Note: File picker integration would be needed here
    // For now, provide a message about the feature
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cache import requires file picker - use manual re-download for now'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}