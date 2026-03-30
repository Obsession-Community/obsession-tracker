import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/maintenance_state_provider.dart';

/// Compact, collapsible banner displayed when BFF is in maintenance mode
///
/// Features:
/// - Minimized state: Small pill showing icon + countdown (doesn't block other UI)
/// - Expanded state: Full details with message, ETA, and retry button
/// - Tap to expand/collapse
/// - Auto-retry continues working in both states
class MaintenanceBanner extends ConsumerStatefulWidget {
  const MaintenanceBanner({super.key});

  @override
  ConsumerState<MaintenanceBanner> createState() => _MaintenanceBannerState();
}

class _MaintenanceBannerState extends ConsumerState<MaintenanceBanner> {
  Timer? _countdownTimer;
  bool _isExpanded = true; // Start expanded so user sees the message

  @override
  void initState() {
    super.initState();
    // Update UI every second to show countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maintenanceState = ref.watch(maintenanceStateProvider);

    // Don't show if not in maintenance
    if (!maintenanceState.isInMaintenance) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _isExpanded
          ? _buildExpandedBanner(maintenanceState, isDark)
          : _buildMinimizedBanner(maintenanceState, isDark),
    );
  }

  /// Minimized state - compact pill that doesn't block other UI
  Widget _buildMinimizedBanner(MaintenanceState state, bool isDark) {
    final nextRetry = state.nextRetryTime;
    final remaining = nextRetry?.difference(DateTime.now());
    final seconds = remaining?.inSeconds.clamp(0, 999) ?? 0;

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.orange.shade900.withValues(alpha: 0.95)
              : Colors.orange.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.orange.shade400,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction,
              color: isDark ? Colors.orange.shade200 : Colors.orange.shade700,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Maintenance',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.orange.shade900,
              ),
            ),
            if (seconds > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.orange.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${seconds}s',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.orange.shade200 : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              color: isDark ? Colors.orange.shade300 : Colors.orange.shade600,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// Expanded state - full details
  Widget _buildExpandedBanner(MaintenanceState state, bool isDark) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.orange.shade900.withValues(alpha: 0.95)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.shade400,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with minimize button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: Row(
              children: [
                Icon(
                  Icons.construction,
                  color: isDark ? Colors.orange.shade200 : Colors.orange.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maintenance Mode',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.orange.shade900,
                        ),
                      ),
                      if (state.estimatedEndDisplay != null)
                        Text(
                          'Est. ${state.estimatedEndDisplay}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.orange.shade200
                                : Colors.orange.shade700,
                          ),
                        ),
                    ],
                  ),
                ),
                // Minimize button
                IconButton(
                  onPressed: () => setState(() => _isExpanded = false),
                  icon: Icon(
                    Icons.expand_less,
                    color: isDark ? Colors.orange.shade300 : Colors.orange.shade600,
                  ),
                  iconSize: 20,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  tooltip: 'Minimize',
                ),
              ],
            ),
          ),

          // Message
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Text(
              state.message ?? 'Map data is temporarily unavailable.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ),

          // Bottom row with cache info and retry
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.orange.shade100.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                // Cache indicator
                Icon(
                  Icons.cached,
                  size: 12,
                  color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Using cached data',
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                    ),
                  ),
                ),
                // Retry countdown/button
                _buildRetrySection(state, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetrySection(MaintenanceState state, bool isDark) {
    final canRetry = state.canManualRetry;
    final nextRetry = state.nextRetryTime;
    final remaining = nextRetry?.difference(DateTime.now());
    final seconds = remaining?.inSeconds.clamp(0, 999) ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Countdown
        if (seconds > 0) ...[
          Icon(
            Icons.timer_outlined,
            size: 12,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
          const SizedBox(width: 2),
          Text(
            '${seconds}s',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 8),
        ],
        // Retry button
        GestureDetector(
          onTap: canRetry
              ? () async {
                  final notifier = ref.read(maintenanceStateProvider.notifier);
                  await notifier.manualRetry();
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: canRetry
                  ? (isDark ? Colors.orange.shade800 : Colors.orange.shade200)
                  : Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh,
                  size: 12,
                  color: canRetry
                      ? (isDark ? Colors.white : Colors.orange.shade800)
                      : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  canRetry ? 'Retry' : 'Wait',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: canRetry
                        ? (isDark ? Colors.white : Colors.orange.shade800)
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
