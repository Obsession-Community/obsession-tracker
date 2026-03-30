import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/public_hunt.dart';
import 'package:obsession_tracker/core/providers/public_hunts_provider.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/features/hunts/presentation/pages/public_hunt_detail_page.dart';

/// Widget displaying public hunts from the BFF API.
///
/// Shows featured and active treasure hunts that users can browse.
class PublicHuntsList extends ConsumerStatefulWidget {
  const PublicHuntsList({super.key});

  @override
  ConsumerState<PublicHuntsList> createState() => _PublicHuntsListState();
}

class _PublicHuntsListState extends ConsumerState<PublicHuntsList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(publicHuntsProvider.notifier).loadHunts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(publicHuntsProvider);

    if (state.isLoading && state.hunts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.hunts.isEmpty) {
      return _buildErrorView(context, state.error!);
    }

    if (state.hunts.isEmpty) {
      return _buildEmptyState(context);
    }

    return _buildHuntsList(context, state);
  }

  Widget _buildHuntsList(BuildContext context, PublicHuntsState state) {
    final featuredHunts = state.hunts.where((h) => h.featured).toList();
    final activeHunts =
        state.hunts.where((h) => h.status == PublicHuntStatus.active && !h.featured).toList();
    final upcomingHunts =
        state.hunts.where((h) => h.status == PublicHuntStatus.upcoming).toList();
    final foundHunts =
        state.hunts.where((h) => h.status == PublicHuntStatus.found).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(publicHuntsProvider.notifier).loadHunts(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          // Header info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.public, color: AppTheme.gold, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Discover treasure hunts from around the world',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),

          // Featured hunts
          if (featuredHunts.isNotEmpty) ...[
            _buildSectionHeader('Featured', Icons.star, AppTheme.gold),
            ...featuredHunts.map((hunt) => _buildHuntCard(context, hunt, featured: true)),
          ],

          // Active hunts
          if (activeHunts.isNotEmpty) ...[
            _buildSectionHeader('Active Hunts', Icons.search, Colors.green),
            ...activeHunts.map((hunt) => _buildHuntCard(context, hunt)),
          ],

          // Upcoming hunts
          if (upcomingHunts.isNotEmpty) ...[
            _buildSectionHeader('Coming Soon', Icons.schedule, Colors.blue),
            ...upcomingHunts.map((hunt) => _buildHuntCard(context, hunt)),
          ],

          // Found hunts (historical)
          if (foundHunts.isNotEmpty) ...[
            _buildSectionHeader('Found', Icons.check_circle, Colors.grey),
            ...foundHunts.map((hunt) => _buildHuntCard(context, hunt)),
          ],

          // Show loading indicator if refreshing
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHuntCard(BuildContext context, PublicHunt hunt, {bool featured = false}) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: featured ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: featured
            ? BorderSide(color: AppTheme.gold.withValues(alpha: 0.5), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _openHuntDetail(hunt),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail image (fall back to hero image if no thumbnail)
            if (hunt.thumbnailUrl != null || hunt.heroImageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  hunt.thumbnailUrl ?? hunt.heroImageUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 120,
                    color: AppTheme.gold.withValues(alpha: 0.1),
                    child: Icon(Icons.image, color: AppTheme.gold.withValues(alpha: 0.3), size: 40),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row with status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hunt.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (hunt.subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                hunt.subtitle!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      _buildStatusBadge(hunt.status),
                    ],
                  ),

                  // Provider
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.business, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        hunt.providerName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),

                  // Hunt type and difficulty
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildTag(_getHuntTypeLabel(hunt.huntType), Icons.category),
                      if (hunt.difficulty != null)
                        _buildTag(_getDifficultyLabel(hunt.difficulty!), Icons.trending_up,
                            color: _getDifficultyColor(hunt.difficulty!)),
                      if (hunt.prizeValueUsd != null)
                        _buildTag('\$${hunt.prizeValueUsd!.toStringAsFixed(0)}', Icons.attach_money,
                            color: Colors.green),
                    ],
                  ),

                  // Search region
                  if (hunt.searchRegion != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hunt.searchRegion!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildTag(String label, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppTheme.gold).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color ?? AppTheme.gold),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color ?? AppTheme.gold,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(PublicHuntStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case PublicHuntStatus.active:
        color = Colors.green;
        label = 'Active';
        icon = Icons.play_circle;
        break;
      case PublicHuntStatus.upcoming:
        color = Colors.blue;
        label = 'Coming Soon';
        icon = Icons.schedule;
        break;
      case PublicHuntStatus.found:
        color = Colors.grey;
        label = 'Found';
        icon = Icons.check_circle;
        break;
      case PublicHuntStatus.archived:
        color = Colors.grey;
        label = 'Archived';
        icon = Icons.archive;
        break;
      case PublicHuntStatus.draft:
        color = Colors.orange;
        label = 'Draft';
        icon = Icons.edit;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getHuntTypeLabel(PublicHuntType type) {
    switch (type) {
      case PublicHuntType.armchair:
        return 'Armchair';
      case PublicHuntType.field:
        return 'Field';
      case PublicHuntType.hybrid:
        return 'Hybrid';
    }
  }

  String _getDifficultyLabel(PublicHuntDifficulty difficulty) {
    switch (difficulty) {
      case PublicHuntDifficulty.beginner:
        return 'Beginner';
      case PublicHuntDifficulty.intermediate:
        return 'Intermediate';
      case PublicHuntDifficulty.advanced:
        return 'Advanced';
      case PublicHuntDifficulty.expert:
        return 'Expert';
    }
  }

  Color _getDifficultyColor(PublicHuntDifficulty difficulty) {
    switch (difficulty) {
      case PublicHuntDifficulty.beginner:
        return Colors.green;
      case PublicHuntDifficulty.intermediate:
        return Colors.blue;
      case PublicHuntDifficulty.advanced:
        return Colors.orange;
      case PublicHuntDifficulty.expert:
        return Colors.red;
    }
  }

  void _openHuntDetail(PublicHunt hunt) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PublicHuntDetailPage(huntSlug: hunt.slug),
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
              Icons.public,
              size: 80,
              color: AppTheme.gold.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 24),
            Text(
              'No Public Hunts Available',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Check back later for featured treasure hunts\nand armchair hunts from around the world.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(publicHuntsProvider.notifier).loadHunts(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Hunts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(publicHuntsProvider.notifier).loadHunts(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
