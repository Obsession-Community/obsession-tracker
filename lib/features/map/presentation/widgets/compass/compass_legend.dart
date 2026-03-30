import 'package:flutter/material.dart';

/// Smart legend that explains what each needle in the dual compass represents
/// Shows contextual information based on compass state
class CompassLegend extends StatelessWidget {
  const CompassLegend({
    this.magneticNeedleColor,
    this.mapNeedleColor,
    this.isMapRotated = false,
    this.isCompact = false,
    this.showOnlyWhenRotated = true,
    super.key,
  });

  /// Color of the magnetic north needle (defaults to theme error color)
  final Color? magneticNeedleColor;

  /// Color of the map orientation needle (defaults to theme primary color)
  final Color? mapNeedleColor;

  /// Whether the map is currently rotated
  final bool isMapRotated;

  /// Whether to show a compact version of the legend
  final bool isCompact;

  /// Whether to only show the legend when the map is rotated
  final bool showOnlyWhenRotated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveMagneticColor =
        magneticNeedleColor ?? theme.colorScheme.error;
    final effectiveMapColor = mapNeedleColor ?? theme.colorScheme.primary;

    // Don't show legend if map is not rotated and showOnlyWhenRotated is true
    if (showOnlyWhenRotated && !isMapRotated) {
      return const SizedBox.shrink();
    }

    if (isCompact) {
      return _buildCompactLegend(
          context, effectiveMagneticColor, effectiveMapColor);
    } else {
      return _buildFullLegend(
          context, effectiveMagneticColor, effectiveMapColor);
    }
  }

  Widget _buildCompactLegend(
      BuildContext context, Color magneticColor, Color mapColor) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Magnetic needle indicator
          _NeedleIndicator(
            color: magneticColor,
            icon: Icons.explore,
            size: 12,
          ),
          const SizedBox(width: 2),
          Text(
            'Device',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),

          if (isMapRotated) ...[
            const SizedBox(width: 4),
            // Map needle indicator
            _NeedleIndicator(
              color: mapColor,
              icon: Icons.map,
              size: 12,
            ),
            const SizedBox(width: 2),
            Text(
              'Map',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullLegend(
      BuildContext context, Color magneticColor, Color mapColor) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Compass Needles',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Magnetic needle explanation
          _LegendItem(
            color: magneticColor,
            icon: Icons.explore,
            title: 'Device North',
            description: 'Points to magnetic north',
          ),

          if (isMapRotated) ...[
            const SizedBox(height: 6),
            // Map orientation explanation
            _LegendItem(
              color: mapColor,
              icon: Icons.map,
              title: 'Map Up',
              description: 'Shows map orientation',
            ),
          ],
        ],
      ),
    );
  }
}

/// Individual legend item showing needle color, icon, and description
class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.icon,
    required this.title,
    required this.description,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NeedleIndicator(
          color: color,
          icon: icon,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Visual indicator for needle color and type
class _NeedleIndicator extends StatelessWidget {
  const _NeedleIndicator({
    required this.color,
    required this.icon,
    required this.size,
  });

  final Color color;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size + 4,
        height: size + 4,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
          ),
        ),
        child: Icon(
          icon,
          size: size * 0.6,
          color: Colors.white,
        ),
      );
}

/// Animated legend that smoothly appears/disappears based on map rotation
class AnimatedCompassLegend extends StatelessWidget {
  const AnimatedCompassLegend({
    this.magneticNeedleColor,
    this.mapNeedleColor,
    this.isMapRotated = false,
    this.isCompact = false,
    this.showOnlyWhenRotated = true,
    this.animationDuration = const Duration(milliseconds: 300),
    super.key,
  });

  /// Color of the magnetic north needle (defaults to theme error color)
  final Color? magneticNeedleColor;

  /// Color of the map orientation needle (defaults to theme primary color)
  final Color? mapNeedleColor;

  /// Whether the map is currently rotated
  final bool isMapRotated;

  /// Whether to show a compact version of the legend
  final bool isCompact;

  /// Whether to only show the legend when the map is rotated
  final bool showOnlyWhenRotated;

  /// Duration for the animation
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final shouldShow = !showOnlyWhenRotated || isMapRotated;

    return AnimatedSwitcher(
      duration: animationDuration,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: child,
        ),
      ),
      child: shouldShow
          ? CompassLegend(
              key: ValueKey(isMapRotated),
              magneticNeedleColor: magneticNeedleColor,
              mapNeedleColor: mapNeedleColor,
              isMapRotated: isMapRotated,
              isCompact: isCompact,
              showOnlyWhenRotated: false, // Already handled by AnimatedSwitcher
            )
          : const SizedBox.shrink(),
    );
  }
}
