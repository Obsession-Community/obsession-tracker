import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/search_models.dart';
import 'package:obsession_tracker/core/providers/search_provider.dart';
import 'package:obsession_tracker/features/search/presentation/widgets/search_bar_widget.dart';
import 'package:obsession_tracker/features/search/presentation/widgets/search_results_widget.dart';

/// Main search page with comprehensive search functionality
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final searchNotifier = ref.read(searchProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          // Clear search button
          if (searchState.hasSearched)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: searchNotifier.clearSearch,
              tooltip: 'Clear search',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2),
                ),
              ),
            ),
            child: SearchBarWidget(
              autoFocus: true,
              onSubmitted: () {
                // Optionally close suggestions or perform other actions
              },
            ),
          ),

          // Results header with tabs and sort
          if (searchState.hasSearched) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Results summary and sort
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          _getResultsSummary(searchState),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        const Spacer(),
                        const SearchSortWidget(),
                      ],
                    ),
                  ),

                  // Content type tabs
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    tabs: [
                      _buildTab(context, 'All', searchState.results.length),
                      _buildTab(
                          context,
                          'Photos',
                          _getResultCountByType(
                              searchState, SearchContentType.photos)),
                      _buildTab(
                          context,
                          'Waypoints',
                          _getResultCountByType(
                              searchState, SearchContentType.waypoints)),
                      _buildTab(
                          context,
                          'Sessions',
                          _getResultCountByType(
                              searchState, SearchContentType.sessions)),
                      _buildTab(
                          context,
                          'Voice Notes',
                          _getResultCountByType(
                              searchState, SearchContentType.voiceNotes)),
                    ],
                  ),
                ],
              ),
            ),

            // Results content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // All results
                  SearchResultsWidget(
                    onResultTap: _handleResultTap,
                  ),
                  // Photos
                  _buildTypeResults(SearchContentType.photos),
                  // Waypoints
                  _buildTypeResults(SearchContentType.waypoints),
                  // Sessions
                  _buildTypeResults(SearchContentType.sessions),
                  // Voice Notes
                  _buildTypeResults(SearchContentType.voiceNotes),
                ],
              ),
            ),
          ] else
            // Empty state or recent searches
            Expanded(
              child: _buildEmptySearchState(context, searchState),
            ),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, String label, int count) => Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 10,
                      ),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _buildTypeResults(SearchContentType type) => Consumer(
        builder: (context, ref, child) {
          final results = ref.watch(searchResultsByTypeProvider(type));

          if (results.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getTypeIcon(type),
                      size: 48,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No ${type.displayName.toLowerCase()} found',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final result = results[index];
              return SearchResultCard(
                result: result,
                onTap: () => _handleResultTap(result),
              );
            },
          );
        },
      );

  Widget _buildEmptySearchState(
          BuildContext context, SearchState searchState) =>
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recent searches
            if (searchState.recentSearches.isNotEmpty) ...[
              Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: searchState.recentSearches
                    .map((search) => ActionChip(
                          label: Text(search),
                          onPressed: () {
                            ref
                                .read(searchProvider.notifier)
                                .updateSearchText(search, autoSearch: true);
                          },
                          avatar: const Icon(Icons.history, size: 16),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 32),
            ],

            // Search tips
            Text(
              'Search Tips',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _buildSearchTip(
              context,
              Icons.photo_camera,
              'Photos',
              'Search by filename, tags, or annotations',
            ),
            _buildSearchTip(
              context,
              Icons.place,
              'Waypoints',
              'Find waypoints by name, type, or notes',
            ),
            _buildSearchTip(
              context,
              Icons.route,
              'Sessions',
              'Search sessions by name or description',
            ),
            _buildSearchTip(
              context,
              Icons.mic,
              'Voice Notes',
              'Find transcribed voice recordings',
            ),
            const SizedBox(height: 24),

            // Quick filters
            Text(
              'Quick Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickFilter(context, 'Today', SearchDateRange.today),
                _buildQuickFilter(
                    context, 'This Week', SearchDateRange.thisWeek),
                _buildQuickFilter(context, 'Favorites', null,
                    favoritesOnly: true),
                _buildQuickFilter(context, 'With Voice Notes', null,
                    hasVoiceNotes: true),
              ],
            ),
          ],
        ),
      );

  Widget _buildSearchTip(BuildContext context, IconData icon, String title,
          String description) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildQuickFilter(
    BuildContext context,
    String label,
    SearchDateRange? dateRange, {
    bool favoritesOnly = false,
    bool hasVoiceNotes = false,
  }) =>
      ActionChip(
        label: Text(label),
        onPressed: () {
          final searchNotifier = ref.read(searchProvider.notifier);
          final currentFilters = ref.read(searchProvider).query.filters;

          SearchFilters newFilters = currentFilters;

          if (dateRange != null) {
            newFilters = newFilters.copyWith(dateRange: dateRange);
          }
          if (favoritesOnly) {
            newFilters = newFilters.copyWith(favoritesOnly: true);
          }
          if (hasVoiceNotes) {
            newFilters = newFilters.copyWith(hasVoiceNotes: true);
          }

          searchNotifier.updateFilters(newFilters);
          if (ref.read(searchProvider).query.text.isNotEmpty) {
            searchNotifier.search();
          }
        },
      );

  String _getResultsSummary(SearchState searchState) {
    final count = searchState.results.length;
    if (count == 0) {
      return 'No results found';
    } else if (count == 1) {
      return '1 result';
    } else {
      return '$count results';
    }
  }

  int _getResultCountByType(SearchState searchState, SearchContentType type) =>
      searchState.results.where((result) => result.type == type).length;

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

  void _handleResultTap(SearchResult result) {
    // Navigate to the appropriate detail page based on result type
    switch (result.type) {
      case SearchContentType.photos:
        if (result is PhotoSearchResult) {
          // Navigate to photo viewer
          // Navigator.of(context).push(...);
        }
        break;
      case SearchContentType.waypoints:
        if (result is WaypointSearchResult) {
          // Navigate to waypoint detail or map
          // Navigator.of(context).push(...);
        }
        break;
      case SearchContentType.sessions:
        if (result is SessionSearchResult) {
          // Navigate to session detail
          // Navigator.of(context).push(...);
        }
        break;
      case SearchContentType.voiceNotes:
        if (result is VoiceNoteSearchResult) {
          // Navigate to voice note player
          // Navigator.of(context).push(...);
        }
        break;
      case SearchContentType.all:
        // Handle generic result
        break;
    }
  }
}
