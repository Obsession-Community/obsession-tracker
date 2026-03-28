import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Compact visual indicator showing when app is offline
///
/// Designed to be subtle and non-intrusive - shows as a small floating chip
/// in the corner of the map when the device has no network connectivity.
class CompactOfflineIndicator extends StatefulWidget {
  const CompactOfflineIndicator({
    super.key,
    this.showWhenOnline = false,
  });

  /// If true, shows a green "Online" indicator when connected
  /// Default is false (only show when offline)
  final bool showWhenOnline;

  @override
  State<CompactOfflineIndicator> createState() =>
      _CompactOfflineIndicatorState();
}

class _CompactOfflineIndicatorState extends State<CompactOfflineIndicator>
    with SingleTickerProviderStateMixin {
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup fade animation for smooth appearance/disappearance
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _checkConnectivity();

    // Listen for connectivity changes
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      _checkConnectivity();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = !connectivityResult.contains(ConnectivityResult.mobile) &&
        !connectivityResult.contains(ConnectivityResult.wifi) &&
        !connectivityResult.contains(ConnectivityResult.ethernet);

    if (mounted && _isOffline != isOffline) {
      setState(() {
        _isOffline = isOffline;
      });

      // Animate the indicator
      if (_isOffline || widget.showWhenOnline) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we should show the indicator
    final shouldShow = _isOffline || (widget.showWhenOnline && !_isOffline);

    if (!shouldShow && !_animationController.isAnimating) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colors based on status
    final backgroundColor = _isOffline
        ? (isDark ? Colors.orange.shade800 : Colors.orange.shade600)
        : (isDark ? Colors.green.shade800 : Colors.green.shade600);
    const iconColor = Colors.white;
    const textColor = Colors.white;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Tooltip(
        message: _isOffline
            ? 'No network connection. Displaying cached data from previous sessions.'
            : 'Connected to server',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: backgroundColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isOffline ? Icons.cloud_off : Icons.cloud_done,
                color: iconColor,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                _isOffline ? 'Offline' : 'Online',
                style: const TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
