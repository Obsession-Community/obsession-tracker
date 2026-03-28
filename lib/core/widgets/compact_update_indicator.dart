import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/data_update_provider.dart';
import 'package:obsession_tracker/features/offline/presentation/pages/land_trail_data_page.dart';

/// Compact visual indicator showing when data updates are available
///
/// Designed to be subtle but recognizable - shows as a small floating chip
/// in the corner of the map when downloaded states have updates available.
class CompactUpdateIndicator extends ConsumerStatefulWidget {
  const CompactUpdateIndicator({super.key});

  @override
  ConsumerState<CompactUpdateIndicator> createState() =>
      _CompactUpdateIndicatorState();
}

class _CompactUpdateIndicatorState extends ConsumerState<CompactUpdateIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup fade animation for smooth appearance
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToDataPage() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => const LandTrailDataPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(dataUpdateProvider);
    final hasUpdates = updateState.hasUpdates;
    final updateCount = updateState.updateCount;

    // Animate visibility based on update availability
    if (hasUpdates) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }

    if (!hasUpdates && !_animationController.isAnimating) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Blue color to indicate updates available (info-style)
    final backgroundColor =
        isDark ? Colors.blue.shade700 : Colors.blue.shade600;
    const iconColor = Colors.white;
    const textColor = Colors.white;

    // Check if this is a GNIS update (historical places)
    final isGnisUpdate = updateState.serverVersion.contains('GNIS') ||
        (updateState.serverDescription?.contains('historical') ?? false);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: _navigateToDataPage,
        child: Tooltip(
          message: isGnisUpdate
              ? 'New historical places data available! Tap to update.'
              : '$updateCount state(s) have updates available. Tap to update.',
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
                const Icon(
                  Icons.system_update_alt,
                  color: iconColor,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  isGnisUpdate ? 'New Data' : '$updateCount Update${updateCount > 1 ? 's' : ''}',
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
      ),
    );
  }
}
