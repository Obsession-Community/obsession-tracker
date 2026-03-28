import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/trail_color_scheme.dart';
import 'package:obsession_tracker/core/providers/trail_color_provider.dart';

/// Widget for selecting trail color schemes
class TrailColorSelector extends ConsumerWidget {
  const TrailColorSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TrailColorState colorState = ref.watch(trailColorProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.palette,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Trail Colors',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Switch(
                  value: colorState.isEnabled,
                  onChanged: (_) =>
                      ref.read(trailColorProvider.notifier).toggleEnabled(),
                ),
              ],
            ),
            if (colorState.isEnabled) ...<Widget>[
              const SizedBox(height: 16),
              _buildColorModeSelector(context, ref, colorState),
              const SizedBox(height: 16),
              _buildSchemeSelector(context, ref, colorState),
              const SizedBox(height: 16),
              _buildOptionsRow(context, ref, colorState),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildColorModeSelector(
    BuildContext context,
    WidgetRef ref,
    TrailColorState colorState,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Color Mode',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TrailColorMode.values.map((TrailColorMode mode) {
              final bool isSelected = colorState.currentScheme.mode == mode;
              return FilterChip(
                label: Text(_getModeName(mode)),
                selected: isSelected,
                onSelected: (_) => _selectMode(ref, mode, colorState),
                avatar: Icon(
                  _getModeIcon(mode),
                  size: 16,
                ),
              );
            }).toList(),
          ),
        ],
      );

  Widget _buildSchemeSelector(
    BuildContext context,
    WidgetRef ref,
    TrailColorState colorState,
  ) {
    final List<TrailColorScheme> availableSchemes = colorState.filteredSchemes
        .where((TrailColorScheme scheme) =>
            scheme.mode == colorState.currentScheme.mode)
        .toList();

    if (availableSchemes.length <= 1) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Color Scheme',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: availableSchemes.length,
            itemBuilder: (BuildContext context, int index) {
              final TrailColorScheme scheme = availableSchemes[index];
              final bool isSelected = scheme == colorState.currentScheme;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _buildSchemeCard(context, ref, scheme, isSelected),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSchemeCard(
    BuildContext context,
    WidgetRef ref,
    TrailColorScheme scheme,
    bool isSelected,
  ) =>
      GestureDetector(
        onTap: () =>
            ref.read(trailColorProvider.notifier).setColorScheme(scheme),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: scheme.colors
                    .take(4)
                    .map((Color color) => Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                                color: Colors.grey[300]!, width: 0.5),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 4),
              Text(
                scheme.name.split(' - ').last, // Show only the variant name
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : null,
                    ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (scheme.isAccessibilityFriendly)
                Icon(
                  Icons.accessibility,
                  size: 12,
                  color: Colors.green[600],
                ),
            ],
          ),
        ),
      );

  Widget _buildOptionsRow(
    BuildContext context,
    WidgetRef ref,
    TrailColorState colorState,
  ) =>
      Row(
        children: <Widget>[
          Expanded(
            child: CheckboxListTile(
              title: const Text('Show Legend'),
              subtitle: const Text('Display color meanings'),
              value: colorState.showLegend,
              onChanged: (_) =>
                  ref.read(trailColorProvider.notifier).toggleLegend(),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          Expanded(
            child: CheckboxListTile(
              title: const Text('Accessible Colors'),
              subtitle: const Text('Colorblind-friendly'),
              value: colorState.useAccessibilityColors,
              onChanged: (_) => ref
                  .read(trailColorProvider.notifier)
                  .toggleAccessibilityColors(),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      );

  void _selectMode(
      WidgetRef ref, TrailColorMode mode, TrailColorState colorState) {
    // Find the first available scheme for this mode
    final List<TrailColorScheme> schemesForMode = colorState.filteredSchemes
        .where((TrailColorScheme scheme) => scheme.mode == mode)
        .toList();

    if (schemesForMode.isNotEmpty) {
      ref
          .read(trailColorProvider.notifier)
          .setColorScheme(schemesForMode.first);
    }
  }

  String _getModeName(TrailColorMode mode) {
    switch (mode) {
      case TrailColorMode.speed:
        return 'Speed';
      case TrailColorMode.time:
        return 'Time';
      case TrailColorMode.elevation:
        return 'Elevation';
      case TrailColorMode.accuracy:
        return 'Accuracy';
      case TrailColorMode.single:
        return 'Single';
    }
  }

  IconData _getModeIcon(TrailColorMode mode) {
    switch (mode) {
      case TrailColorMode.speed:
        return Icons.speed;
      case TrailColorMode.time:
        return Icons.schedule;
      case TrailColorMode.elevation:
        return Icons.terrain;
      case TrailColorMode.accuracy:
        return Icons.gps_fixed;
      case TrailColorMode.single:
        return Icons.palette;
    }
  }
}

/// Compact trail color selector for toolbar use
class CompactTrailColorSelector extends ConsumerWidget {
  const CompactTrailColorSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TrailColorState colorState = ref.watch(trailColorProvider);

    return PopupMenuButton<TrailColorScheme>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            _getModeIcon(colorState.currentScheme.mode),
            size: 16,
          ),
          const SizedBox(width: 4),
          _buildColorIndicator(colorState.currentScheme),
        ],
      ),
      tooltip: 'Change trail colors',
      enabled: colorState.isEnabled,
      onSelected: (TrailColorScheme scheme) {
        ref.read(trailColorProvider.notifier).setColorScheme(scheme);
      },
      itemBuilder: (BuildContext context) {
        final List<PopupMenuEntry<TrailColorScheme>> items =
            <PopupMenuEntry<TrailColorScheme>>[];

        // Group schemes by mode
        for (final TrailColorMode mode in TrailColorMode.values) {
          final List<TrailColorScheme> schemesForMode = colorState
              .filteredSchemes
              .where((TrailColorScheme scheme) => scheme.mode == mode)
              .toList();

          if (schemesForMode.isNotEmpty) {
            // Add mode header
            items.add(PopupMenuItem<TrailColorScheme>(
              enabled: false,
              child: Text(
                _getModeName(mode),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ));

            // Add schemes for this mode
            for (final TrailColorScheme scheme in schemesForMode) {
              items.add(PopupMenuItem<TrailColorScheme>(
                value: scheme,
                child: Row(
                  children: <Widget>[
                    _buildColorIndicator(scheme),
                    const SizedBox(width: 8),
                    Expanded(child: Text(scheme.name)),
                    if (scheme.isAccessibilityFriendly)
                      Icon(
                        Icons.accessibility,
                        size: 16,
                        color: Colors.green[600],
                      ),
                  ],
                ),
              ));
            }

            if (mode != TrailColorMode.values.last) {
              items.add(const PopupMenuDivider());
            }
          }
        }

        return items;
      },
    );
  }

  Widget _buildColorIndicator(TrailColorScheme scheme) {
    if (scheme.colors.length == 1) {
      return Container(
        width: 20,
        height: 12,
        decoration: BoxDecoration(
          color: scheme.colors.first,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: Colors.grey[300]!, width: 0.5),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: scheme.colors
          .take(3)
          .map((Color color) => Container(
                width: 6,
                height: 12,
                margin: const EdgeInsets.only(right: 1),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1),
                ),
              ))
          .toList(),
    );
  }

  String _getModeName(TrailColorMode mode) {
    switch (mode) {
      case TrailColorMode.speed:
        return 'Speed';
      case TrailColorMode.time:
        return 'Time';
      case TrailColorMode.elevation:
        return 'Elevation';
      case TrailColorMode.accuracy:
        return 'Accuracy';
      case TrailColorMode.single:
        return 'Single';
    }
  }

  IconData _getModeIcon(TrailColorMode mode) {
    switch (mode) {
      case TrailColorMode.speed:
        return Icons.speed;
      case TrailColorMode.time:
        return Icons.schedule;
      case TrailColorMode.elevation:
        return Icons.terrain;
      case TrailColorMode.accuracy:
        return Icons.gps_fixed;
      case TrailColorMode.single:
        return Icons.palette;
    }
  }
}
