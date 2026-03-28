import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/services/location_service.dart';
import 'package:obsession_tracker/core/services/offline_land_rights_service.dart';
import 'package:obsession_tracker/features/offline/presentation/widgets/download_area_dialog.dart';
import 'package:obsession_tracker/features/offline/presentation/widgets/offline_area_tile.dart';

class OfflineAreasPage extends ConsumerStatefulWidget {
  const OfflineAreasPage({super.key});

  @override
  ConsumerState<OfflineAreasPage> createState() => _OfflineAreasPageState();
}

class _OfflineAreasPageState extends ConsumerState<OfflineAreasPage> {
  final OfflineLandRightsService _offlineService = OfflineLandRightsService();
  final LocationService _locationService = LocationService();
  
  List<DownloadArea> _downloadAreas = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDownloadAreas();
  }

  Future<void> _loadDownloadAreas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final areas = await _offlineService.getDownloadAreas();
      setState(() {
        _downloadAreas = areas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load offline areas: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadCurrentArea() async {
    try {
      final position = await _locationService.getCurrentPosition();
      
      if (!mounted) return;
      
      final result = await showDialog<DownloadAreaConfig?>(
        context: context,
        builder: (context) => DownloadAreaDialog(
          centerLatitude: position.latitude,
          centerLongitude: position.longitude,
        ),
      );

      if (result != null) {
        await _startDownload(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get current location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadCustomArea() async {
    final result = await showDialog<DownloadAreaConfig?>(
      context: context,
      builder: (context) => const DownloadAreaDialog(),
    );

    if (result != null) {
      await _startDownload(result);
    }
  }

  Future<void> _startDownload(DownloadAreaConfig config) async {
    try {
      await _offlineService.downloadAreaForOfflineUse(
        name: config.name,
        centerLatitude: config.centerLatitude,
        centerLongitude: config.centerLongitude,
        radiusKm: config.radiusKm,
        onProgress: (progress) {
          // Progress will be handled by the tile widget
        },
      );
      
      await _loadDownloadAreas(); // Refresh the list
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download started for ${config.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start download: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshArea(DownloadArea area) async {
    try {
      // Re-download the area to refresh cached data
      await _offlineService.downloadAreaForOfflineUse(
        name: area.name,
        centerLatitude: area.centerLatitude,
        centerLongitude: area.centerLongitude,
        radiusKm: area.radiusKm,
        onProgress: (progress) {
          // Progress will be handled by the tile widget
        },
      );

      await _loadDownloadAreas();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refreshing ${area.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh area: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _retryDownload(DownloadArea area) async {
    try {
      // Retry downloading the failed area
      await _offlineService.downloadAreaForOfflineUse(
        name: area.name,
        centerLatitude: area.centerLatitude,
        centerLongitude: area.centerLongitude,
        radiusKm: area.radiusKm,
        onProgress: (progress) {
          // Progress will be handled by the tile widget
        },
      );

      await _loadDownloadAreas();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retrying download for ${area.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to retry download: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteArea(DownloadArea area) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Offline Area'),
        content: Text('Are you sure you want to delete "${area.name}"?\n\n'
            'This will remove all cached data for this area.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _offlineService.deleteDownloadArea(area.id);
        await _loadDownloadAreas();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted ${area.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete area: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Areas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDownloadAreas,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'current',
            onPressed: _downloadCurrentArea,
            icon: const Icon(Icons.my_location),
            label: const Text('Download Current Area'),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'custom',
            onPressed: _downloadCustomArea,
            icon: const Icon(Icons.add),
            label: const Text('Download Custom Area'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDownloadAreas,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_downloadAreas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.offline_pin,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No Offline Areas',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                "Download areas to access land rights information when you're offline.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _downloadCurrentArea,
              icon: const Icon(Icons.my_location),
              label: const Text('Download Current Area'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDownloadAreas,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 160), // Space for FABs
        itemCount: _downloadAreas.length,
        itemBuilder: (context, index) {
          final area = _downloadAreas[index];
          return OfflineAreaTile(
            area: area,
            onDelete: () => _deleteArea(area),
            onRefresh: () => _refreshArea(area),
            onRetry: () => _retryDownload(area),
          );
        },
      ),
    );
  }
}