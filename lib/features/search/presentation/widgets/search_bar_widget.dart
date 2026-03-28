import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/search_models.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/search_provider.dart';

/// Enhanced search bar widget with suggestions and filters
class SearchBarWidget extends ConsumerStatefulWidget {
  const SearchBarWidget({
    super.key,
    this.hintText = 'Search photos, waypoints, sessions...',
    this.showFilters = true,
    this.autoFocus = false,
    this.onSubmitted,
  });

  final String hintText;
  final bool showFilters;
  final bool autoFocus;
  final VoidCallback? onSubmitted;

  @override
  ConsumerState<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends ConsumerState<SearchBarWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();

    _focusNode.addListener(() {
      setState(() {
        _showSuggestions = _focusNode.hasFocus;
      });
    });

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final searchNotifier = ref.read(searchProvider.notifier);

    // Update controller text if it differs from state
    if (_controller.text != searchState.query.text) {
      _controller.text = searchState.query.text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }

    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
              width: _focusNode.hasFocus ? 2 : 1,
            ),
            boxShadow: [
              if (_focusNode.hasFocus)
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            children: [
              // Search icon
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),

              // Search input field
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                  ),
                  onChanged: searchNotifier.updateSearchText,
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      searchNotifier.search();
                      _focusNode.unfocus();
                      widget.onSubmitted?.call();
                    }
                  },
                  textInputAction: TextInputAction.search,
                ),
              ),

              // Clear button
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: () {
                    _controller.clear();
                    searchNotifier.updateSearchText('');
                    searchNotifier.clearSearch();
                  },
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),

              // Filter button
              if (widget.showFilters)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Stack(
                      children: [
                        Icon(
                          Icons.tune,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        if (searchState.query.filters.hasActiveFilters)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: () => _showFilterDialog(context),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Search suggestions
        if (_showSuggestions && searchState.suggestions.isNotEmpty)
          _buildSuggestions(context, searchState.suggestions, searchNotifier),
      ],
    );
  }

  Widget _buildSuggestions(
    BuildContext context,
    List<SearchSuggestion> suggestions,
    SearchNotifier searchNotifier,
  ) =>
      Container(
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: suggestions.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return ListTile(
              dense: true,
              leading: Icon(
                _getSuggestionIcon(suggestion.type),
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(
                suggestion.text,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: suggestion.count != null
                  ? Text(
                      '${suggestion.count} results',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    )
                  : null,
              trailing: suggestion.type == SearchSuggestionType.recent
                  ? Icon(
                      Icons.north_west,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )
                  : null,
              onTap: () {
                _controller.text = suggestion.text;
                searchNotifier.updateSearchText(suggestion.text);
                searchNotifier.search();
                _focusNode.unfocus();
                widget.onSubmitted?.call();
              },
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
            );
          },
        ),
      );

  IconData _getSuggestionIcon(SearchSuggestionType type) {
    switch (type) {
      case SearchSuggestionType.recent:
        return Icons.history;
      case SearchSuggestionType.tag:
        return Icons.label_outline;
      case SearchSuggestionType.location:
        return Icons.place_outlined;
      case SearchSuggestionType.waypointType:
        return Icons.category_outlined;
      case SearchSuggestionType.session:
        return Icons.route_outlined;
    }
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SearchFiltersWidget(),
    );
  }
}

/// Search filters widget for advanced filtering options
class SearchFiltersWidget extends ConsumerStatefulWidget {
  const SearchFiltersWidget({super.key});

  @override
  ConsumerState<SearchFiltersWidget> createState() =>
      _SearchFiltersWidgetState();
}

class _SearchFiltersWidgetState extends ConsumerState<SearchFiltersWidget> {
  late SearchFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = ref.read(searchProvider).query.filters;
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Search Filters',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  if (_filters.hasActiveFilters)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filters = const SearchFilters();
                        });
                      },
                      child: const Text('Clear All'),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Filter content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildContentTypeFilter(),
                    const SizedBox(height: 24),
                    _buildDateRangeFilter(),
                    const SizedBox(height: 24),
                    _buildWaypointFilters(),
                    const SizedBox(height: 24),
                    _buildPhotoFilters(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Apply button
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(searchProvider.notifier).updateFilters(_filters);
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Apply Filters${_filters.activeFilterCount > 0 ? ' (${_filters.activeFilterCount})' : ''}',
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildContentTypeFilter() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Content Type',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SearchContentType.values.map((type) {
              final isSelected = _filters.contentTypes.contains(type);
              return FilterChip(
                label: Text(type.displayName),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    final newTypes =
                        Set<SearchContentType>.from(_filters.contentTypes);
                    if (selected) {
                      newTypes.add(type);
                    } else {
                      newTypes.remove(type);
                    }
                    if (newTypes.isEmpty) {
                      newTypes.add(SearchContentType.all);
                    }
                    _filters = _filters.copyWith(contentTypes: newTypes);
                  });
                },
              );
            }).toList(),
          ),
        ],
      );

  Widget _buildDateRangeFilter() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Date Range',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SearchDateRange.values.map((range) {
              final isSelected = _filters.dateRange == range;
              return FilterChip(
                label: Text(range.displayName),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _filters = _filters.copyWith(
                      dateRange: selected ? range : SearchDateRange.all,
                    );
                  });
                },
              );
            }).toList(),
          ),
        ],
      );

  Widget _buildWaypointFilters() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Waypoint Types',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: WaypointType.values.map((WaypointType type) {
              final isSelected = _filters.waypointTypes.contains(type);
              return FilterChip(
                label: Text(type.displayName),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    final newTypes =
                        Set<WaypointType>.from(_filters.waypointTypes);
                    if (selected) {
                      newTypes.add(type);
                    } else {
                      newTypes.remove(type);
                    }
                    _filters =
                        _filters.copyWith(waypointTypes: newTypes);
                  });
                },
              );
            }).toList(),
          ),
        ],
      );

  Widget _buildPhotoFilters() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photo Filters',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Favorites Only'),
            value: _filters.favoritesOnly,
            onChanged: (value) {
              setState(() {
                _filters = _filters.copyWith(favoritesOnly: value);
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('Has Voice Notes'),
            value: _filters.hasVoiceNotes,
            onChanged: (value) {
              setState(() {
                _filters = _filters.copyWith(hasVoiceNotes: value);
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
        ],
      );
}
