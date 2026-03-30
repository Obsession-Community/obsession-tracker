import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/trail.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/trail_path_preview.dart';

/// Slide-up bottom sheet for trail details with expandable content
/// Shows trail name and quick stats when collapsed, full details when expanded
/// Supports multi-segment trails via TrailGroup
/// Can be used standalone (with internal DraggableScrollableSheet) or
/// inside a modal bottom sheet (with external scrollController)
class TrailBottomSheet extends StatelessWidget {
  const TrailBottomSheet({
    required this.trailGroup,
    required this.onDismiss,
    this.scrollController,
    super.key,
  });

  final TrailGroup trailGroup;
  final VoidCallback onDismiss;
  /// When provided, used instead of internal DraggableScrollableSheet
  final ScrollController? scrollController;

  /// Convenience getter for the representative trail (tapped segment)
  Trail get trail => trailGroup.representativeTrail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If scrollController is provided, render content directly (modal mode)
    if (scrollController != null) {
      return _buildContent(context, theme, scrollController!);
    }

    // Otherwise, wrap in DraggableScrollableSheet (standalone mode)
    return DraggableScrollableSheet(
      initialChildSize: 0.2, // Start at 20% of screen height
      minChildSize: 0.2, // Minimum collapsed size
      maxChildSize: 0.9, // Maximum expanded size
      snap: true,
      snapSizes: const [0.2, 0.5, 0.9], // Snap points for smooth UX
      builder: (context, controller) => _buildContent(context, theme, controller),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, ScrollController controller) {
    return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.zero,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onDismiss,
                  tooltip: 'Close',
                ),
              ),

              // Content with horizontal padding
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trail header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.hiking,
                            size: 28,
                            color: Color(0xFF2196F3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trail.trailName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (trail.trailNumber != null)
                                Text(
                                  'Trail #${trail.trailNumber}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              // Source badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: trail.isOfficial
                                      ? Colors.blue.withValues(alpha: 0.15)
                                      : Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: trail.isOfficial
                                        ? Colors.blue.withValues(alpha: 0.3)
                                        : Colors.orange.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      trail.sourceBadgeIcon,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      trail.sourceBadge,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: trail.isOfficial
                                            ? Colors.blue[700]
                                            : Colors.orange[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Segment indicator for multi-segment trails
                    if (trailGroup.isMultiSegment) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.segment,
                              size: 18,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This trail has ${trailGroup.segmentCount} segments '
                                '(viewing segment ${trailGroup.tappedSegmentIndex})',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.orange[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Quick stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            icon: Icons.straighten,
                            label: trailGroup.isMultiSegment
                                ? 'Total Length'
                                : 'Length',
                            value:
                                '${trailGroup.totalLengthMiles.toStringAsFixed(2)} mi',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            icon: Icons.terrain,
                            label: 'Difficulty',
                            value: trail.difficulty ?? 'Unknown',
                          ),
                        ),
                      ],
                    ),

                    // Show segment length if multi-segment
                    if (trailGroup.isMultiSegment) ...[
                      const SizedBox(height: 8),
                      Text(
                        'This segment: ${trail.lengthMiles.toStringAsFixed(2)} mi',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Trail path preview with distance markers
                    TrailPathPreview(
                      trailGroup: trailGroup,
                      height: 180,
                    ),
                    const SizedBox(height: 20),

                    // Trail details
                    _buildSection(
                      context,
                      title: 'Trail Information',
                      children: [
                        _buildInfoRow(
                          context,
                          'Trail Type',
                          _formatTrailType(trail.trailType),
                          Icons.category,
                        ),
                        if (trail.managingAgency != null)
                          _buildInfoRow(
                            context,
                            'Managing Agency',
                            trail.managingAgency!,
                            Icons.business,
                          ),
                        if (trail.surfaceType != null)
                          _buildInfoRow(
                            context,
                            'Surface Type',
                            trail.surfaceType!,
                            Icons.landscape,
                          ),
                        if (trail.trailClass != null)
                          _buildInfoRow(
                            context,
                            'Trail Class',
                            trail.trailClass!,
                            Icons.format_list_numbered,
                          ),
                      ],
                    ),

                    // Allowed uses
                    if (trail.allowedUses.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        context,
                        title: 'Allowed Uses',
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: trail.allowedUses.map((use) {
                              return Chip(
                                label: Text(
                                  _formatUseType(use),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.3),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ],

                    // Data source
                    const SizedBox(height: 20),
                    _buildSection(
                      context,
                      title: 'Data Source',
                      children: [
                        _buildInfoRow(
                          context,
                          'Source',
                          trail.dataSource,
                          Icons.source,
                        ),
                      ],
                    ),

                    const SizedBox(height: 100), // Bottom padding
                  ],
                ),
              ),
            ],
          ),
        );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData? icon,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTrailType(String type) {
    switch (type.toUpperCase()) {
      case 'TERRA':
        return 'Land Trail';
      case 'SNOW':
        return 'Snow Trail';
      case 'WATER':
        return 'Water Trail';
      default:
        return type;
    }
  }

  String _formatUseType(String use) {
    return use
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}
