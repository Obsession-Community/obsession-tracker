import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/achievements_provider.dart';
import 'package:obsession_tracker/core/services/achievement_service.dart';
import 'package:obsession_tracker/core/services/lifetime_statistics_service.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/features/achievements/presentation/widgets/achievement_card.dart';
import 'package:obsession_tracker/features/achievements/presentation/widgets/progress_ring.dart';
import 'package:obsession_tracker/features/achievements/presentation/widgets/stat_card.dart';

/// Page displaying achievements, statistics, and state exploration
class AchievementsPage extends ConsumerStatefulWidget {
  const AchievementsPage({super.key});

  @override
  ConsumerState<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends ConsumerState<AchievementsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lifetimeStatsProvider.notifier).refresh();
      ref.read(achievementProvider.notifier).refresh();
      ref.read(exploredStatesProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfo,
            tooltip: 'About Achievements',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.gold,
          labelColor: AppTheme.gold,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Statistics'),
            Tab(icon: Icon(Icons.emoji_events), text: 'Badges'),
            Tab(icon: Icon(Icons.map), text: 'States'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StatisticsTab(),
          _BadgesTab(),
          _StatesTab(),
        ],
      ),
    );
  }

  void _showInfo() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: AppTheme.gold),
            SizedBox(width: 8),
            Text('Achievements'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Track Your Journey',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'All your statistics and achievements are calculated '
                'from your tracking sessions. Everything stays on your device.',
              ),
              SizedBox(height: 16),
              Text(
                'Statistics',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'View your lifetime totals including distance, time, '
                'photos, and more. Track your session streaks and '
                'personal records.',
              ),
              SizedBox(height: 16),
              Text(
                'Badges',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Earn badges for milestones, distance goals, streaks, '
                'and more. There are 32 badges to collect across '
                '6 categories.',
              ),
              SizedBox(height: 16),
              Text(
                'State Collection',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "See which US states you've explored. The app "
                'automatically detects states from your GPS coordinates.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              _recalculateStatistics();
            },
            child: const Text('Recalculate Stats'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: Colors.black,
            ),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  Future<void> _recalculateStatistics() async {
    // Show loading indicator
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Recalculating statistics...'),
          ],
        ),
      ),
    );

    try {
      // Recalculate all stats from sessions
      await ref.read(lifetimeStatsProvider.notifier).recalculate();

      // Check achievements
      final achievementService = AchievementService();
      await achievementService.checkAllAchievements();

      // Refresh all providers
      await ref.read(achievementProvider.notifier).refresh();
      await ref.read(exploredStatesProvider.notifier).refresh();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Statistics recalculated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Statistics tab showing lifetime stats
class _StatisticsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(lifetimeStatsProvider);
    final achievementProgress = ref.watch(achievementProgressProvider);

    return statsAsync.when(
      data: (stats) => RefreshIndicator(
        onRefresh: () => ref.read(lifetimeStatsProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero stats row
              Row(
                children: [
                  Expanded(
                    child: HeroStatCard(
                      label: 'Total Distance',
                      value: '${stats.totalDistanceMiles.toStringAsFixed(1)} mi',
                      icon: Icons.route,
                      color: AppTheme.gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quick stats grid
              Row(
                children: [
                  Expanded(
                    child: CompactStatCard(
                      label: 'Sessions',
                      value: '${stats.totalSessions}',
                      icon: Icons.explore,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CompactStatCard(
                      label: 'Time',
                      value: stats.formattedTotalTime,
                      icon: Icons.timer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CompactStatCard(
                      label: 'States',
                      value: '${stats.statesExplored}',
                      icon: Icons.map,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Streak card
              StreakCard(
                currentStreak: stats.currentStreak,
                longestStreak: stats.longestStreak,
              ),
              const SizedBox(height: 24),

              // Achievement progress
              _buildSectionHeader(context, 'Achievement Progress', Icons.emoji_events),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      ProgressRingWithLabel(
                        progress: achievementProgress.total > 0
                            ? achievementProgress.completed / achievementProgress.total
                            : 0,
                        progressColor: AppTheme.gold,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${achievementProgress.completed} of ${achievementProgress.total}',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Badges Earned',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Memories section
              _buildSectionHeader(context, 'Memories', Icons.photo_camera),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Photos',
                      value: '${stats.totalPhotos}',
                      icon: Icons.camera_alt,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'Voice Notes',
                      value: '${stats.totalVoiceNotes}',
                      icon: Icons.mic,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Waypoints',
                      value: '${stats.totalWaypoints}',
                      icon: Icons.place,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'Hunts Created',
                      value: '${stats.totalHuntsCreated}',
                      icon: Icons.search,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Personal Records
              if (stats.prLongestSessionDistance != null ||
                  stats.prMostElevationGain != null) ...[
                _buildSectionHeader(context, 'Personal Records', Icons.star),
                const SizedBox(height: 12),
                if (stats.prLongestSessionDistance != null)
                  _buildRecordTile(
                    context,
                    'Longest Session',
                    '${(stats.prLongestSessionDistance! / 1609.344).toStringAsFixed(2)} mi',
                    Icons.route,
                  ),
                if (stats.prMostElevationGain != null)
                  _buildRecordTile(
                    context,
                    'Most Elevation Gain',
                    '${(stats.prMostElevationGain! * 3.28084).toStringAsFixed(0)} ft',
                    Icons.terrain,
                  ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Error loading statistics'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.read(lifetimeStatsProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1,
              ),
        ),
      ],
    );
  }

  Widget _buildRecordTile(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.amber),
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}

/// Badges tab showing all achievements
class _BadgesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsAsync = ref.watch(achievementProvider);

    return achievementsAsync.when(
      data: (achievements) {
        if (achievements.isEmpty) {
          return _buildEmptyState(context, ref);
        }

        // Group by category
        final categories = <String, List<UserAchievementProgress>>{};
        for (final a in achievements) {
          final category = a.achievement?.category ?? 'other';
          categories.putIfAbsent(category, () => []);
          categories[category]!.add(a);
        }

        // Order categories
        final orderedCategories = [
          'milestone',
          'distance',
          'explorer',
          'dedication',
          'memory',
          'hunter',
        ];

        return RefreshIndicator(
          onRefresh: () => ref.read(achievementProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: orderedCategories.length,
            itemBuilder: (context, index) {
              final category = orderedCategories[index];
              final categoryAchievements = categories[category] ?? [];
              if (categoryAchievements.isEmpty) return const SizedBox.shrink();

              final completed =
                  categoryAchievements.where((a) => a.isCompleted).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AchievementCategoryHeader(
                    category: category,
                    completedCount: completed,
                    totalCount: categoryAchievements.length,
                  ),
                  ...categoryAchievements.map(
                    (a) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: AchievementCard(
                        achievement: a,
                        onTap: () => _showAchievementDetail(context, a),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Error loading achievements'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.read(achievementProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events,
              size: 80,
              color: AppTheme.gold.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 24),
            Text(
              'No Achievements Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start tracking your adventures to earn badges!\n'
              'Complete sessions, explore new states, and more.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAchievementDetail(
    BuildContext context,
    UserAchievementProgress achievement,
  ) {
    final def = achievement.achievement;
    if (def == null) return;

    final difficultyColor = AchievementColors.forDifficulty(def.difficulty);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: achievement.isCompleted
                    ? difficultyColor.withValues(alpha: 0.2)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconData(def.iconName),
                color: achievement.isCompleted
                    ? difficultyColor
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                def.name,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(def.description),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Difficulty: ',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: difficultyColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    def.difficulty.toUpperCase(),
                    style: TextStyle(
                      color: difficultyColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (achievement.isCompleted && achievement.completedAt != null)
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Completed on ${_formatDate(achievement.completedAt!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                        ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Progress: ${achievement.currentProgress.toInt()} / ${def.requirementValue.toInt()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: achievement.progressPercentage,
                    backgroundColor: difficultyColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(difficultyColor),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    // Same mapping as in achievement_card.dart
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
    return '${date.month}/${date.day}/${date.year}';
  }
}

/// States tab showing explored US states
class _StatesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statesAsync = ref.watch(exploredStatesProvider);

    return statesAsync.when(
      data: (states) {
        if (states.isEmpty) {
          return _buildEmptyState(context);
        }

        // Sort by first visited (most recent first)
        final sortedStates = List<ExploredState>.from(states)
          ..sort((a, b) => b.firstVisitedAt.compareTo(a.firstVisitedAt));

        return RefreshIndicator(
          onRefresh: () => ref.read(exploredStatesProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary card
              Card(
                color: AppTheme.gold.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.flag,
                          size: 32,
                          color: AppTheme.gold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${states.length} of 50',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.gold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'States Explored',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      ProgressRing(
                        progress: states.length / 50,
                        progressColor: AppTheme.gold,
                        child: Text(
                          '${((states.length / 50) * 100).toInt()}%',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // States list header
              Row(
                children: [
                  Icon(
                    Icons.place,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'EXPLORED STATES',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 1,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // States list
              ...sortedStates.map((state) => _buildStateTile(context, state)),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Error loading states'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.read(exploredStatesProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map,
              size: 80,
              color: AppTheme.gold.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 24),
            Text(
              'No States Explored Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start tracking sessions to see which\n'
              "US states you've explored!",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateTile(BuildContext context, ExploredState state) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            state.stateCode,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.gold,
                ),
          ),
        ),
        title: Text(
          state.stateName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${state.sessionCount} ${state.sessionCount == 1 ? 'session' : 'sessions'} '
          '• ${(state.totalDistance / 1609.344).toStringAsFixed(1)} mi',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'First visit',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            Text(
              _formatDate(state.firstVisitedAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        onTap: () => _showStateDetail(context, state),
      ),
    );
  }

  void _showStateDetail(BuildContext context, ExploredState state) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.stateCode,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.gold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(state.stateName),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow(
              context,
              Icons.explore,
              'Sessions',
              '${state.sessionCount}',
            ),
            _buildDetailRow(
              context,
              Icons.route,
              'Total Distance',
              '${(state.totalDistance / 1609.344).toStringAsFixed(2)} mi',
            ),
            _buildDetailRow(
              context,
              Icons.timer,
              'Total Time',
              _formatDuration(state.totalDuration),
            ),
            _buildDetailRow(
              context,
              Icons.calendar_today,
              'First Visit',
              _formatDate(state.firstVisitedAt),
            ),
            _buildDetailRow(
              context,
              Icons.update,
              'Last Visit',
              _formatDate(state.lastVisitedAt),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
