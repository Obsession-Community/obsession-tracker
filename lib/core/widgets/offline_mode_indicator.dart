import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/services/offline_land_rights_service.dart';

/// Visual indicator showing when app is using offline cached data
class OfflineModeIndicator extends StatefulWidget {
  const OfflineModeIndicator({super.key});

  @override
  State<OfflineModeIndicator> createState() => _OfflineModeIndicatorState();
}

class _OfflineModeIndicatorState extends State<OfflineModeIndicator> {
  bool _isOffline = false;
  bool _hasCachedData = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _checkCachedData();

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((results) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = !connectivityResult.contains(ConnectivityResult.mobile) &&
        !connectivityResult.contains(ConnectivityResult.wifi) &&
        !connectivityResult.contains(ConnectivityResult.ethernet);

    if (mounted) {
      setState(() {
        _isOffline = isOffline;
      });
    }
  }

  Future<void> _checkCachedData() async {
    // Check if any states are downloaded in SQLite
    try {
      final offlineService = OfflineLandRightsService();
      await offlineService.initialize();
      final downloadedStates = await offlineService.getDownloadedStates();
      if (mounted) {
        setState(() {
          _hasCachedData = downloadedStates.isNotEmpty;
        });
      }
    } catch (e) {
      // If check fails, assume no cached data
      if (mounted) {
        setState(() {
          _hasCachedData = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show indicator when offline
    if (!_isOffline) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: _hasCachedData
            ? Colors.orange.shade700
            : Colors.red.shade700,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _hasCachedData ? Icons.offline_pin : Icons.wifi_off,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _hasCachedData
                      ? 'Offline Mode - Using Cached Data'
                      : 'Offline - No Cached Data Available',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
