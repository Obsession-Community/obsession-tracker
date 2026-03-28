import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/help_models.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';

/// Card widget for displaying help content
class HelpContentCard extends StatelessWidget {
  const HelpContentCard({
    required this.content,
    required this.onTap,
    super.key,
    this.searchResult,
    this.isCompact = false,
    this.showProgress = false,
    this.progress,
  });

  final HelpContent content;
  final VoidCallback onTap;
  final HelpSearchResult? searchResult;
  final bool isCompact;
  final bool showProgress;
  final HelpProgress? progress;

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactCard(context);
    }
    return _buildFullCard(context);
  }

  Widget _buildFullCard(BuildContext context) => Card(
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(context.isTablet ? 20 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and type
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            _getTypeColor(content.type).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getTypeIcon(content.type),
                        size: context.isTablet ? 24 : 20,
                        color: _getTypeColor(content.type),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTypeLabel(content.type),
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: _getTypeColor(content.type),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (content.estimatedDuration != null)
                            Text(
                              _formatDuration(content.estimatedDuration!),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    _buildDifficultyBadge(context),
                  ],
                ),

                const SizedBox(height: 12),

                // Title
                Text(
                  content.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: context.isTablet ? 18 : 16,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // Description
                Text(
                  searchResult?.highlightedContent ?? content.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: context.isTablet ? 14 : 13,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Footer with tags and progress
                Row(
                  children: [
                    // Tags
                    if (content.tags.isNotEmpty)
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: content.tags
                              .take(2)
                              .map((tag) => Chip(
                                    label: Text(
                                      tag,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                      ),

                    // Progress indicator
                    if (showProgress && progress != null)
                      _buildProgressIndicator(context),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildCompactCard(BuildContext context) => Card(
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getTypeColor(content.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _getTypeIcon(content.type),
                    size: 20,
                    color: _getTypeColor(content.type),
                  ),
                ),

                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and type
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              content.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildDifficultyBadge(context, isSmall: true),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Description
                      Text(
                        searchResult?.highlightedContent ?? content.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Meta info
                      if (content.estimatedDuration != null ||
                          searchResult != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              if (content.estimatedDuration != null) ...[
                                Icon(
                                  Icons.schedule,
                                  size: 12,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDuration(content.estimatedDuration!),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                      ),
                                ),
                              ],
                              if (searchResult != null &&
                                  searchResult!.matchedTerms.isNotEmpty) ...[
                                if (content.estimatedDuration != null)
                                  const SizedBox(width: 8),
                                Icon(
                                  Icons.search,
                                  size: 12,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${searchResult!.matchedTerms.length} matches',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Progress indicator
                if (showProgress && progress != null)
                  _buildProgressIndicator(context, isSmall: true),

                // Arrow
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildDifficultyBadge(BuildContext context, {bool isSmall = false}) {
    final color = _getDifficultyColor(content.difficulty);
    final label = _getDifficultyLabel(content.difficulty);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(isSmall ? 8 : 12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: (isSmall
                ? Theme.of(context).textTheme.labelSmall
                : Theme.of(context).textTheme.labelMedium)
            ?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context, {bool isSmall = false}) {
    if (progress == null) return const SizedBox.shrink();

    final progressValue = progress!.isCompleted
        ? 1.0
        : progress!.currentStep / _getContentStepCount();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: isSmall ? 24 : 32,
          height: isSmall ? 24 : 32,
          child: CircularProgressIndicator(
            value: progressValue,
            strokeWidth: isSmall ? 2 : 3,
            backgroundColor:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        if (!isSmall) ...[
          const SizedBox(height: 4),
          Text(
            progress!.isCompleted
                ? 'Complete'
                : '${(progressValue * 100).round()}%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ],
    );
  }

  int _getContentStepCount() {
    switch (content.type) {
      case HelpContentType.tutorial:
        return (content as Tutorial).steps.length;
      case HelpContentType.guide:
        return (content as Guide).steps.length;
      case HelpContentType.interactive:
        return (content as InteractiveGuide).steps.length;
      default:
        return 1;
    }
  }

  IconData _getTypeIcon(HelpContentType type) {
    switch (type) {
      case HelpContentType.tutorial:
        return Icons.school;
      case HelpContentType.guide:
        return Icons.map;
      case HelpContentType.faq:
        return Icons.quiz;
      case HelpContentType.troubleshooting:
        return Icons.build;
      case HelpContentType.documentation:
        return Icons.description;
      case HelpContentType.video:
        return Icons.play_circle;
      case HelpContentType.interactive:
        return Icons.touch_app;
      case HelpContentType.quickTip:
        return Icons.lightbulb;
    }
  }

  Color _getTypeColor(HelpContentType type) {
    switch (type) {
      case HelpContentType.tutorial:
        return Colors.blue;
      case HelpContentType.guide:
        return Colors.green;
      case HelpContentType.faq:
        return Colors.orange;
      case HelpContentType.troubleshooting:
        return Colors.red;
      case HelpContentType.documentation:
        return Colors.purple;
      case HelpContentType.video:
        return Colors.pink;
      case HelpContentType.interactive:
        return Colors.teal;
      case HelpContentType.quickTip:
        return Colors.amber;
    }
  }

  String _getTypeLabel(HelpContentType type) {
    switch (type) {
      case HelpContentType.tutorial:
        return 'Tutorial';
      case HelpContentType.guide:
        return 'Guide';
      case HelpContentType.faq:
        return 'FAQ';
      case HelpContentType.troubleshooting:
        return 'Troubleshooting';
      case HelpContentType.documentation:
        return 'Documentation';
      case HelpContentType.video:
        return 'Video';
      case HelpContentType.interactive:
        return 'Interactive';
      case HelpContentType.quickTip:
        return 'Quick Tip';
    }
  }

  Color _getDifficultyColor(HelpDifficulty difficulty) {
    switch (difficulty) {
      case HelpDifficulty.beginner:
        return Colors.green;
      case HelpDifficulty.intermediate:
        return Colors.orange;
      case HelpDifficulty.advanced:
        return Colors.red;
    }
  }

  String _getDifficultyLabel(HelpDifficulty difficulty) {
    switch (difficulty) {
      case HelpDifficulty.beginner:
        return 'Beginner';
      case HelpDifficulty.intermediate:
        return 'Intermediate';
      case HelpDifficulty.advanced:
        return 'Advanced';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '< 1m';
    }
  }
}
