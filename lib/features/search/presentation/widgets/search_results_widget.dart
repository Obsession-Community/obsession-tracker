import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/search_models.dart';
import 'package:obsession_tracker/core/providers/search_provider.dart';

/// Widget for displaying search results with different layouts
class SearchResultsWidget extends ConsumerWidget {
  const SearchResultsWidget({
    super.key,
    this.onResultTap,
    this.showGroupedResults = true,
  });

  final void Function(SearchResult)? onResultTap;
  final bool showGroupedResults;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchProvider);
    final results = searchState.results;

    if (searchState.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (searchState.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Search Error',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                searchState.error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(searchProvider.notifier).clearError(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!searchState.hasSearched) {
      return _buildEmptyState(context, 'Start typing to search');
    }

    if (results.isEmpty) {
      return _buildEmptyState(context, 'No results found');
    }

    if (showGroupedResults) {
      return _buildGroupedResults(context, results);
    } else {
      return _buildListResults(context, results);
    }
  }

  Widget _buildEmptyState(BuildContext context, String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _buildGroupedResults(
      BuildContext context, List<SearchResult> results) {
    // Group results by type
    final Map<SearchContentType, List<SearchResult>> groupedResults =
        <SearchContentType, List<SearchResult>>{};
    for (final result in results) {
      groupedResults.putIfAbsent(result.type, () => []).add(result);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: groupedResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 24),
      itemBuilder: (context, index) {
        final type = groupedResults.keys.elementAt(index);
        final typeResults = groupedResults[type]!;

        return _buildResultGroup(context, type, typeResults);
      },
    );
  }

  Widget _buildResultGroup(
    BuildContext context,
    SearchContentType type,
    List<SearchResult> results,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header
          Row(
            children: [
              Icon(
                _getTypeIcon(type),
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                type.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    '${results.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Results
          ...results.take(5).map((result) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SearchResultCard(
                  result: result,
                  onTap: () => onResultTap?.call(result),
                ),
              )),

          // Show more button if there are more results
          if (results.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () {
                  // Navigate to full results for this type
                },
                child: Text(
                    'Show ${results.length - 5} more ${type.displayName.toLowerCase()}'),
              ),
            ),
        ],
      );

  Widget _buildListResults(BuildContext context, List<SearchResult> results) =>
      ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: results.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final result = results[index];
          return SearchResultCard(
            result: result,
            onTap: () => onResultTap?.call(result),
          );
        },
      );

  IconData _getTypeIcon(SearchContentType type) {
    switch (type) {
      case SearchContentType.all:
        return Icons.search;
      case SearchContentType.photos:
        return Icons.photo_camera;
      case SearchContentType.waypoints:
        return Icons.place;
      case SearchContentType.sessions:
        return Icons.route;
      case SearchContentType.voiceNotes:
        return Icons.mic;
    }
  }
}

/// Individual search result card
class SearchResultCard extends StatelessWidget {
  const SearchResultCard({
    required this.result,
    super.key,
    this.onTap,
    this.showType = false,
  });

  final SearchResult result;
  final VoidCallback? onTap;
  final bool showType;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Leading icon/thumbnail
                _buildLeading(context),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with type badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              result.title,
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
                          if (showType) ...[
                            const SizedBox(width: 8),
                            _buildTypeBadge(context),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Subtitle
                      Text(
                        result.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Timestamp and relevance
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            result.formattedTimestamp,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                          const Spacer(),
                          if (result.relevanceScore > 0)
                            _buildRelevanceIndicator(context),
                        ],
                      ),
                    ],
                  ),
                ),

                // Trailing arrow
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildLeading(BuildContext context) {
    if (result.thumbnailPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 48,
          height: 48,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.image),
        ),
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _getTypeColor(context, result.type).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getTypeIcon(result.type),
        color: _getTypeColor(context, result.type),
        size: 24,
      ),
    );
  }

  Widget _buildTypeBadge(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: _getTypeColor(context, result.type).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            result.type.displayName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getTypeColor(context, result.type),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      );

  Widget _buildRelevanceIndicator(BuildContext context) {
    final int stars = (result.relevanceScore * 5).round();
    if (stars == 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < stars ? Icons.star : Icons.star_border,
          size: 12,
          color: index < stars
              ? Colors.amber
              : Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.3),
        ),
      ),
    );
  }

  IconData _getTypeIcon(SearchContentType type) {
    switch (type) {
      case SearchContentType.all:
        return Icons.search;
      case SearchContentType.photos:
        return Icons.photo_camera;
      case SearchContentType.waypoints:
        return Icons.place;
      case SearchContentType.sessions:
        return Icons.route;
      case SearchContentType.voiceNotes:
        return Icons.mic;
    }
  }

  Color _getTypeColor(BuildContext context, SearchContentType type) {
    switch (type) {
      case SearchContentType.all:
        return Theme.of(context).colorScheme.primary;
      case SearchContentType.photos:
        return Colors.blue;
      case SearchContentType.waypoints:
        return Colors.green;
      case SearchContentType.sessions:
        return Colors.orange;
      case SearchContentType.voiceNotes:
        return Colors.purple;
    }
  }
}

/// Sort options widget
class SearchSortWidget extends ConsumerWidget {
  const SearchSortWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSort = ref.watch(searchProvider).query.sortOption;
    final searchNotifier = ref.read(searchProvider.notifier);

    return PopupMenuButton<SearchSortOption>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sort,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            currentSort.displayName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      onSelected: searchNotifier.updateSortOption,
      itemBuilder: (context) => SearchSortOption.values
          .map((option) => PopupMenuItem<SearchSortOption>(
                value: option,
                child: Row(
                  children: [
                    if (option == currentSort)
                      Icon(
                        Icons.check,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(option.displayName),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
