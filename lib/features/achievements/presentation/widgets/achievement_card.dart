import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/services/achievement_service.dart';
import 'package:obsession_tracker/features/achievements/presentation/widgets/progress_ring.dart';

/// Color configuration for achievement difficulty levels
class AchievementColors {
  static const bronze = Color(0xFFCD7F32);
  static const silver = Color(0xFFC0C0C0);
  static const gold = Color(0xFFFFD700);
  static const platinum = Color(0xFFE5E4E2);

  static Color forDifficulty(String difficulty) {
    switch (difficulty) {
      case 'bronze':
        return bronze;
      case 'silver':
        return silver;
      case 'gold':
        return gold;
      case 'platinum':
        return platinum;
      default:
        return bronze;
    }
  }
}

/// A card widget for displaying an achievement badge
class AchievementCard extends StatelessWidget {
  const AchievementCard({
    super.key,
    required this.achievement,
    this.onTap,
    this.showProgress = true,
    this.compact = false,
  });

  /// The user's achievement progress
  final UserAchievementProgress achievement;

  /// Optional tap handler
  final VoidCallback? onTap;

  /// Whether to show progress for incomplete achievements
  final bool showProgress;

  /// Whether to use compact layout
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompact(context);
    }
    return _buildFull(context);
  }

  Widget _buildFull(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final def = achievement.achievement;
    final isCompleted = achievement.isCompleted;
    final difficulty = def?.difficulty ?? 'bronze';
    final difficultyColor = AchievementColors.forDifficulty(difficulty);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: isCompleted
              ? BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      difficultyColor.withValues(alpha: 0.1),
                      difficultyColor.withValues(alpha: 0.05),
                    ],
                  ),
                )
              : null,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildBadgeIcon(context, def, isCompleted, difficultyColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            def?.name ?? 'Unknown',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted ? null : colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        _buildDifficultyBadge(context, difficulty, difficultyColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      def?.description ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (!isCompleted && showProgress) ...[
                      const SizedBox(height: 8),
                      _buildProgressBar(context, difficultyColor),
                    ],
                    if (isCompleted && achievement.completedAt != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Completed ${_formatDate(achievement.completedAt!)}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.green,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final def = achievement.achievement;
    final isCompleted = achievement.isCompleted;
    final difficulty = def?.difficulty ?? 'bronze';
    final difficultyColor = AchievementColors.forDifficulty(difficulty);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: isCompleted
              ? BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      difficultyColor.withValues(alpha: 0.15),
                      difficultyColor.withValues(alpha: 0.05),
                    ],
                  ),
                )
              : null,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBadgeIcon(context, def, isCompleted, difficultyColor, size: 48),
              const SizedBox(height: 8),
              Text(
                def?.name ?? 'Unknown',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? null : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isCompleted && showProgress) ...[
                const SizedBox(height: 8),
                _buildProgressBar(context, difficultyColor, compact: true),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeIcon(
    BuildContext context,
    AchievementDefinition? def,
    bool isCompleted,
    Color difficultyColor, {
    double size = 56,
  }) {
    final iconData = _getIconData(def?.iconName ?? 'star');

    if (isCompleted) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              difficultyColor,
              difficultyColor.withValues(alpha: 0.7),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: difficultyColor.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          iconData,
          size: size * 0.5,
          color: Colors.white,
        ),
      );
    }

    // Show progress ring for incomplete achievements
    return ProgressRing(
      progress: achievement.progressPercentage,
      size: size,
      strokeWidth: 4,
      progressColor: difficultyColor,
      child: Icon(
        iconData,
        size: size * 0.4,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildDifficultyBadge(BuildContext context, String difficulty, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        difficulty.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, Color color, {bool compact = false}) {
    final def = achievement.achievement;
    final progress = achievement.progressPercentage;
    final current = achievement.currentProgress.toInt();
    final target = def?.requirementValue.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: compact ? 4 : 6,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          Text(
            '$current / $target',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'hiking':
        return Icons.hiking;
      case 'explore':
        return Icons.explore;
      case 'map':
        return Icons.map;
      case 'terrain':
        return Icons.terrain;
      case 'stars':
        return Icons.stars;
      case 'military_tech':
        return Icons.military_tech;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'directions_run':
        return Icons.directions_run;
      case 'route':
        return Icons.route;
      case 'flight':
        return Icons.flight;
      case 'public':
        return Icons.public;
      case 'place':
        return Icons.place;
      case 'travel_explore':
        return Icons.travel_explore;
      case 'flag':
        return Icons.flag;
      case 'language':
        return Icons.language;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'whatshot':
        return Icons.whatshot;
      case 'bolt':
        return Icons.bolt;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'diamond':
        return Icons.diamond;
      case 'camera_alt':
        return Icons.camera_alt;
      case 'photo_library':
        return Icons.photo_library;
      case 'photo_camera':
        return Icons.photo_camera;
      case 'collections':
        return Icons.collections;
      case 'mic':
        return Icons.mic;
      case 'record_voice_over':
        return Icons.record_voice_over;
      case 'search':
        return Icons.search;
      case 'manage_search':
        return Icons.manage_search;
      case 'workspace_premium':
        return Icons.workspace_premium;
      default:
        return Icons.star;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      final weeks = diff.inDays ~/ 7;
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

/// A small badge showing achievement completion status
class AchievementBadge extends StatelessWidget {
  const AchievementBadge({
    super.key,
    required this.completed,
    required this.total,
    this.showLabel = true,
  });

  final int completed;
  final int total;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_events,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '$completed/$total',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              'Badges',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Category header for achievement lists
class AchievementCategoryHeader extends StatelessWidget {
  const AchievementCategoryHeader({
    super.key,
    required this.category,
    required this.completedCount,
    required this.totalCount,
  });

  final String category;
  final int completedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(_getCategoryIcon(), size: 20, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            _getCategoryLabel(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  letterSpacing: 1,
                ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$completedCount/$totalCount',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryLabel() {
    switch (category) {
      case 'milestone':
        return 'MILESTONES';
      case 'distance':
        return 'DISTANCE';
      case 'explorer':
        return 'EXPLORER';
      case 'dedication':
        return 'DEDICATION';
      case 'memory':
        return 'MEMORIES';
      case 'hunter':
        return 'HUNTER';
      default:
        return category.toUpperCase();
    }
  }

  IconData _getCategoryIcon() {
    switch (category) {
      case 'milestone':
        return Icons.flag;
      case 'distance':
        return Icons.route;
      case 'explorer':
        return Icons.explore;
      case 'dedication':
        return Icons.local_fire_department;
      case 'memory':
        return Icons.photo_camera;
      case 'hunter':
        return Icons.search;
      default:
        return Icons.star;
    }
  }
}
