import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';

/// Search bar widget for help content
class HelpSearchBar extends StatefulWidget {
  const HelpSearchBar({
    required this.controller,
    required this.onSearch,
    required this.onClear,
    super.key,
    this.hintText = 'Search help content...',
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final String hintText;
  final bool autofocus;

  @override
  State<HelpSearchBar> createState() => _HelpSearchBarState();
}

class _HelpSearchBarState extends State<HelpSearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);

    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    if (_isSearching != hasText) {
      setState(() {
        _isSearching = hasText;
      });
    }
  }

  void _performSearch() {
    final query = widget.controller.text.trim();
    if (query.isNotEmpty) {
      widget.onSearch(query);
      _focusNode.unfocus();
    }
  }

  void _clearSearch() {
    widget.controller.clear();
    widget.onClear();
    setState(() {
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focusNode.hasFocus
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _performSearch(),
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.isTablet ? 20 : 16,
              vertical: context.isTablet ? 16 : 12,
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.only(
                left: context.isTablet ? 16 : 12,
                right: 8,
              ),
              child: Icon(
                Icons.search,
                color: _focusNode.hasFocus
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                size: context.isTablet ? 24 : 20,
              ),
            ),
            prefixIconConstraints: BoxConstraints(
              minWidth: context.isTablet ? 48 : 40,
            ),
            suffixIcon: _isSearching
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search suggestions button
                      IconButton(
                        onPressed: _showSearchSuggestions,
                        icon: Icon(
                          Icons.auto_awesome,
                          size: context.isTablet ? 20 : 18,
                        ),
                        tooltip: 'Search suggestions',
                        visualDensity: VisualDensity.compact,
                      ),

                      // Clear button
                      IconButton(
                        onPressed: _clearSearch,
                        icon: Icon(
                          Icons.clear,
                          size: context.isTablet ? 20 : 18,
                        ),
                        tooltip: 'Clear search',
                        visualDensity: VisualDensity.compact,
                      ),

                      SizedBox(width: context.isTablet ? 8 : 4),
                    ],
                  )
                : null,
          ),
        ),
      );

  void _showSearchSuggestions() {
    final suggestions = _getSearchSuggestions();
    if (suggestions.isEmpty) return;

    showModalBottomSheet<String>(
      context: context,
      builder: (context) => _SearchSuggestionsSheet(
        suggestions: suggestions,
        onSuggestionSelected: (suggestion) {
          widget.controller.text = suggestion;
          widget.onSearch(suggestion);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  List<String> _getSearchSuggestions() =>
      // Common search terms based on app functionality
      [
        'GPS not working',
        'How to start tracking',
        'Battery optimization',
        'Export data',
        'Photo waypoints',
        'Offline maps',
        'Compass calibration',
        'Location accuracy',
        'Privacy settings',
        'Backup sessions',
        'Import GPX',
        'Trail recording',
        'Waypoint management',
        'Map layers',
        'Distance measurement',
      ];
}

/// Bottom sheet for search suggestions
class _SearchSuggestionsSheet extends StatelessWidget {
  const _SearchSuggestionsSheet({
    required this.suggestions,
    required this.onSuggestionSelected,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSuggestionSelected;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Search Suggestions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Suggestions list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return ListTile(
                    leading: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.outline,
                      size: 20,
                    ),
                    title: Text(suggestion),
                    onTap: () => onSuggestionSelected(suggestion),
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Popular searches
            Text(
              'Popular Searches',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions
                  .take(5)
                  .map((suggestion) => ActionChip(
                        label: Text(suggestion),
                        onPressed: () => onSuggestionSelected(suggestion),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ),
      );
}
