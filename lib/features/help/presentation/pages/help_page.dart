import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/help_models.dart';
import 'package:obsession_tracker/core/providers/help_provider.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:obsession_tracker/features/help/presentation/widgets/contextual_help_panel.dart';
import 'package:obsession_tracker/features/help/presentation/widgets/help_category_tabs.dart';
import 'package:obsession_tracker/features/help/presentation/widgets/help_content_card.dart';
import 'package:obsession_tracker/features/help/presentation/widgets/help_search_bar.dart';
import 'package:obsession_tracker/features/help/presentation/widgets/quick_help_fab.dart';

/// Main help page with comprehensive help system
class HelpPage extends ConsumerStatefulWidget {
  const HelpPage({
    super.key,
    this.initialContext = HelpContext.general,
    this.initialContentId,
  });

  final HelpContext initialContext;
  final String? initialContentId;

  @override
  ConsumerState<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends ConsumerState<HelpPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  HelpContentType? _selectedType;
  HelpDifficulty? _selectedDifficulty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: HelpContentType.values.length,
      vsync: this,
    );

    // Initialize help system
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(helpNotifierProvider.notifier).initialize();
      ref
          .read(helpNotifierProvider.notifier)
          .setCurrentContext(widget.initialContext);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final helpState = ref.watch(helpNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: context.responsivePadding,
                child: HelpSearchBar(
                  controller: _searchController,
                  onSearch: _performSearch,
                  onClear: _clearSearch,
                ),
              ),
              const SizedBox(height: 8),

              // Category tabs
              HelpCategoryTabs(
                controller: _tabController,
                onTypeChanged: (type) {
                  setState(() {
                    _selectedType = type;
                  });
                  _performSearch(_searchController.text);
                },
              ),
            ],
          ),
        ),
        actions: [
          // Filter button
          PopupMenuButton<String>(
            icon: Icon(
              Icons.filter_list,
              color: _selectedDifficulty != null
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onSelected: _handleFilterSelection,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'difficulty_header',
                enabled: false,
                child: Text(
                  'Difficulty Level',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...HelpDifficulty.values.map((difficulty) => PopupMenuItem(
                    value: 'difficulty_${difficulty.name}',
                    child: Row(
                      children: [
                        Icon(
                          _selectedDifficulty == difficulty
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(_getDifficultyLabel(difficulty)),
                      ],
                    ),
                  )),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear_filters',
                child: Row(
                  children: [
                    Icon(Icons.clear, size: 20),
                    SizedBox(width: 8),
                    Text('Clear Filters'),
                  ],
                ),
              ),
            ],
          ),

          // Settings button
          IconButton(
            onPressed: _showHelpSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Help Settings',
          ),
        ],
      ),
      body: helpState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : helpState.error != null
              ? _buildErrorView(helpState.error!)
              : _buildHelpContent(),
      floatingActionButton: const QuickHelpFAB(),
    );
  }

  Widget _buildHelpContent() {
    final helpState = ref.watch(helpNotifierProvider);

    if (helpState.searchResults.isNotEmpty ||
        helpState.lastSearchQuery.isNotEmpty) {
      return _buildSearchResults();
    }

    return TabBarView(
      controller: _tabController,
      children: HelpContentType.values.map(_buildContentTypeView).toList(),
    );
  }

  Widget _buildContentTypeView(HelpContentType type) => Consumer(
        builder: (context, ref, child) {
          final contentAsync = ref.watch(helpContentByTypeProvider(type));

          return contentAsync.when(
            data: (content) {
              if (content.isEmpty) {
                return _buildEmptyState(type);
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(helpContentByTypeProvider(type));
                },
                child: CustomScrollView(
                  slivers: [
                    // Contextual help panel
                    if (type == HelpContentType.quickTip)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: context.responsivePadding,
                          child: const ContextualHelpPanel(),
                        ),
                      ),

                    // Content grid/list
                    SliverPadding(
                      padding: context.responsivePadding,
                      sliver: context.isTablet
                          ? _buildContentGrid(content)
                          : _buildContentList(content),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _buildErrorView(error.toString()),
          );
        },
      );

  Widget _buildContentGrid(List<HelpContent> content) => SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: context.isDesktop ? 3 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => HelpContentCard(
            content: content[index],
            onTap: () => _openContent(content[index]),
          ),
          childCount: content.length,
        ),
      );

  Widget _buildContentList(List<HelpContent> content) => SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: HelpContentCard(
              content: content[index],
              onTap: () => _openContent(content[index]),
              isCompact: true,
            ),
          ),
          childCount: content.length,
        ),
      );

  Widget _buildSearchResults() {
    final helpState = ref.watch(helpNotifierProvider);

    if (helpState.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (helpState.searchResults.isEmpty) {
      return _buildNoSearchResults();
    }

    return RefreshIndicator(
      onRefresh: () async {
        _performSearch(helpState.lastSearchQuery);
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: context.responsivePadding,
              child: Text(
                '${helpState.searchResults.length} results for "${helpState.lastSearchQuery}"',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          SliverPadding(
            padding: context.responsivePadding,
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final result = helpState.searchResults[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: HelpContentCard(
                      content: result.content,
                      onTap: () => _openContent(result.content),
                      searchResult: result,
                      isCompact: true,
                    ),
                  );
                },
                childCount: helpState.searchResults.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(HelpContentType type) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getTypeIcon(type),
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${_getTypeLabel(type).toLowerCase()} available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new content',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );

  Widget _buildNoSearchResults() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or browse categories',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearSearch,
              child: const Text('Clear Search'),
            ),
          ],
        ),
      );

  Widget _buildErrorView(String error) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load help content',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(helpNotifierProvider.notifier).initialize();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );

  void _performSearch(String query) {
    ref.read(helpNotifierProvider.notifier).searchContent(
          query,
          type: _selectedType,
          difficulty: _selectedDifficulty,
        );
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(helpNotifierProvider.notifier).clearSearch();
    setState(() {
      _selectedType = null;
      _selectedDifficulty = null;
    });
  }

  void _handleFilterSelection(String value) {
    if (value.startsWith('difficulty_')) {
      final difficultyName = value.substring(11);
      final difficulty =
          HelpDifficulty.values.firstWhere((d) => d.name == difficultyName);

      setState(() {
        _selectedDifficulty =
            _selectedDifficulty == difficulty ? null : difficulty;
      });

      _performSearch(_searchController.text);
    } else if (value == 'clear_filters') {
      setState(() {
        _selectedType = null;
        _selectedDifficulty = null;
      });
      _performSearch(_searchController.text);
    }
  }

  void _openContent(HelpContent content) {
    Navigator.of(context).pushNamed(
      '/help/content',
      arguments: content,
    );
  }

  void _showHelpSettings() {
    Navigator.of(context).pushNamed('/help/settings');
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

  String _getTypeLabel(HelpContentType type) {
    switch (type) {
      case HelpContentType.tutorial:
        return 'Tutorials';
      case HelpContentType.guide:
        return 'Guides';
      case HelpContentType.faq:
        return 'FAQ';
      case HelpContentType.troubleshooting:
        return 'Troubleshooting';
      case HelpContentType.documentation:
        return 'Documentation';
      case HelpContentType.video:
        return 'Videos';
      case HelpContentType.interactive:
        return 'Interactive';
      case HelpContentType.quickTip:
        return 'Quick Tips';
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
}
