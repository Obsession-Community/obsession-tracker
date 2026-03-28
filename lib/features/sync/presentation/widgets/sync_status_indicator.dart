import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

enum SyncStatus {
  online,
  offline,
  syncing,
  error,
}

class SyncStatusIndicator extends StatefulWidget {
  const SyncStatusIndicator({
    super.key,
    this.compact = false,
    this.showLabel = true,
  });

  final bool compact;
  final bool showLabel;

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  
  SyncStatus _currentStatus = SyncStatus.offline;
  String _statusMessage = 'Checking connection...';
  
  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
    
    _checkConnectivity();
    _setupConnectivityListener();
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }
  
  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _checkConnectivity();
    });
  }
  
  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _updateStatus(SyncStatus.offline, 'Offline - Using cached data');
    } else {
      _updateStatus(SyncStatus.online, 'Online - Data is current');
    }
  }
  
  void _updateStatus(SyncStatus status, String message) {
    if (!mounted) return;
    
    setState(() {
      _currentStatus = status;
      _statusMessage = message;
    });
    
    // Handle animations based on status
    switch (status) {
      case SyncStatus.online:
        _pulseController.stop();
        _rotationController.stop();
        break;
      case SyncStatus.offline:
        _pulseController.stop();
        _rotationController.stop();
        break;
      case SyncStatus.syncing:
        _rotationController.repeat();
        break;
      case SyncStatus.error:
        _pulseController.repeat(reverse: true);
        _rotationController.stop();
        break;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactIndicator();
    }
    return _buildFullIndicator();
  }
  
  Widget _buildCompactIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusIcon(),
        if (widget.showLabel) ...[
          const SizedBox(width: 6),
          Text(
            _getShortStatusText(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _getStatusColor(),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildFullIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor().withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusIcon(),
          const SizedBox(width: 8),
          if (widget.showLabel)
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: _getStatusColor(),
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildStatusIcon() {
    Widget icon;
    
    switch (_currentStatus) {
      case SyncStatus.online:
        icon = Icon(
          Icons.cloud_done,
          color: _getStatusColor(),
          size: widget.compact ? 16 : 18,
        );
        break;
      case SyncStatus.offline:
        icon = Icon(
          Icons.cloud_off,
          color: _getStatusColor(),
          size: widget.compact ? 16 : 18,
        );
        break;
      case SyncStatus.syncing:
        icon = RotationTransition(
          turns: _rotationAnimation,
          child: Icon(
            Icons.sync,
            color: _getStatusColor(),
            size: widget.compact ? 16 : 18,
          ),
        );
        break;
      case SyncStatus.error:
        icon = ScaleTransition(
          scale: _pulseAnimation,
          child: Icon(
            Icons.cloud_sync,
            color: _getStatusColor(),
            size: widget.compact ? 16 : 18,
          ),
        );
        break;
    }
    
    return icon;
  }
  
  Color _getStatusColor() {
    switch (_currentStatus) {
      case SyncStatus.online:
        return Colors.green;
      case SyncStatus.offline:
        return Colors.orange;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.error:
        return Colors.red;
    }
  }
  
  String _getShortStatusText() {
    switch (_currentStatus) {
      case SyncStatus.online:
        return 'Online';
      case SyncStatus.offline:
        return 'Offline';
      case SyncStatus.syncing:
        return 'Syncing';
      case SyncStatus.error:
        return 'Error';
    }
  }
  
  void startSync() {
    _updateStatus(SyncStatus.syncing, 'Syncing data...');
  }
  
  void syncCompleted() {
    _updateStatus(SyncStatus.online, 'Sync completed');
  }
  
  void syncError(String error) {
    _updateStatus(SyncStatus.error, 'Sync failed: $error');
  }
}

class CacheStatusCard extends StatelessWidget {
  const CacheStatusCard({
    super.key,
    required this.totalProperties,
    required this.cachedProperties,
    required this.lastSyncTime,
    required this.cacheSize,
    this.onClearCache,
    this.onSyncNow,
  });

  final int totalProperties;
  final int cachedProperties;
  final DateTime? lastSyncTime;
  final String cacheSize;
  final VoidCallback? onClearCache;
  final VoidCallback? onSyncNow;

  @override
  Widget build(BuildContext context) {
    final cacheRatio = totalProperties > 0 ? cachedProperties / totalProperties : 0.0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storage,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Cache Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const SyncStatusIndicator(compact: true),
              ],
            ),
            const SizedBox(height: 16),
            
            // Cache progress
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cached Properties',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '${cachedProperties.toString()} / ${totalProperties.toString()}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: cacheRatio,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(cacheRatio * 100).toStringAsFixed(1)}% cached',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Cache details
            Row(
              children: [
                Expanded(
                  child: _buildStatColumn(
                    context,
                    'Cache Size',
                    cacheSize,
                    Icons.folder,
                  ),
                ),
                Expanded(
                  child: _buildStatColumn(
                    context,
                    'Last Sync',
                    _formatLastSync(lastSyncTime),
                    Icons.access_time,
                  ),
                ),
                Expanded(
                  child: _buildStatColumn(
                    context,
                    'Properties',
                    cachedProperties.toString(),
                    Icons.location_on,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onClearCache,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear Cache'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onSyncNow,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatColumn(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
  
  String _formatLastSync(DateTime? lastSync) {
    if (lastSync == null) return 'Never';
    
    final now = DateTime.now();
    final difference = now.difference(lastSync);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    
    return '${lastSync.month}/${lastSync.day}';
  }
}