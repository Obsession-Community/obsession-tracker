import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/saved_location_provider.dart';
import 'package:obsession_tracker/core/services/map_search_service.dart';

/// Callback when a search result is selected
typedef SearchResultCallback = void Function(MapSearchResult result);

/// Search widget for finding places or coordinates on the map
class MapSearchWidget extends ConsumerStatefulWidget {
  const MapSearchWidget({
    required this.searchService,
    required this.onResultSelected,
    super.key,
    this.onClose,
    this.proximityLat,
    this.proximityLon,
    this.northBound,
    this.southBound,
    this.eastBound,
    this.westBound,
  });

  final MapSearchService searchService;
  final SearchResultCallback onResultSelected;
  /// Called when the user wants to close the search without selecting a result
  final VoidCallback? onClose;
  final double? proximityLat;
  final double? proximityLon;
  /// Current visible map bounds for local trail search
  final double? northBound;
  final double? southBound;
  final double? eastBound;
  final double? westBound;

  @override
  ConsumerState<MapSearchWidget> createState() => _MapSearchWidgetState();
}

class _MapSearchWidgetState extends ConsumerState<MapSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  List<MapSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  bool _searchedOnline = false; // Track if we've searched BFF
  bool _isSearchingOnline = false; // Loading state for online search

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Debounce search to avoid too many API calls
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      } else {
        setState(() {
          _searchResults = [];
          _showResults = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query, {bool searchOnline = false}) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _showResults = true;
      if (!searchOnline) {
        _searchedOnline = false; // Reset when starting new search
      }
    });

    try {
      final savedLocs = ref.read(savedLocationProvider).locations;
      final results = await widget.searchService.search(
        query,
        proximityLat: widget.proximityLat,
        proximityLon: widget.proximityLon,
        northBound: widget.northBound,
        southBound: widget.southBound,
        eastBound: widget.eastBound,
        westBound: widget.westBound,
        limit: 8,
        searchOnlineTrails: searchOnline,
        savedLocations: savedLocs,
      );

      setState(() {
        _searchResults = results;
        _isSearching = false;
        if (searchOnline) {
          _searchedOnline = true;
        }
      });
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  /// Search online for more trail results
  Future<void> _searchOnlineForMore() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isSearchingOnline = true;
    });

    try {
      await _performSearch(_searchController.text, searchOnline: true);
    } finally {
      setState(() {
        _isSearchingOnline = false;
      });
    }
  }

  bool _isRetrievingCoordinates = false;

  Future<void> _selectResult(MapSearchResult result) async {
    // If this is a Mapbox suggestion, we need to retrieve coordinates first
    if (result.needsRetrieval) {
      setState(() {
        _isRetrievingCoordinates = true;
      });

      try {
        final retrievedResult = await widget.searchService.retrieveCoordinates(result);
        if (retrievedResult != null && retrievedResult.latitude != null) {
          // Successfully retrieved coordinates
          _completeSelection(retrievedResult);
        } else {
          // Failed to retrieve - show error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not get location details')),
            );
            setState(() {
              _isRetrievingCoordinates = false;
            });
          }
        }
      } catch (e) {
        debugPrint('Error retrieving coordinates: $e');
        if (mounted) {
          setState(() {
            _isRetrievingCoordinates = false;
          });
        }
      }
    } else {
      // Already has coordinates (trails, historical places, coordinates)
      _completeSelection(result);
    }
  }

  void _completeSelection(MapSearchResult result) {
    // Clear search and hide results
    setState(() {
      _showResults = false;
      _isRetrievingCoordinates = false;
      _searchController.text = result.displayName;
    });

    // Unfocus to hide keyboard
    _searchFocusNode.unfocus();

    // Notify parent
    widget.onResultSelected(result);
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults = [];
      _showResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search bar
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search places, trails, or coordinates...',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.primary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : IconButton(
                        icon: const Icon(Icons.help_outline),
                        onPressed: _showSearchHelp,
                        tooltip: 'Search Help',
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (value) {
                if (_searchResults.isNotEmpty) {
                  _selectResult(_searchResults.first);
                } else {
                  // Close the search if no results to select
                  widget.onClose?.call();
                }
              },
            ),
          ),
        ),

        // Search results dropdown
        if (_showResults)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _isSearching || _isRetrievingCoordinates
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          if (_isRetrievingCoordinates) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Getting location...',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : _searchResults.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No results found',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try a place name or coordinates',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                            ),
                            // Show search online button when no local results
                            if (widget.northBound != null && !_searchedOnline && !_isSearchingOnline)
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: TextButton.icon(
                                  onPressed: _searchOnlineForMore,
                                  icon: const Icon(Icons.cloud_download, size: 18),
                                  label: const Text('Search online'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length + 1, // +1 for the button
                        itemBuilder: (context, index) {
                          // Last item is the "search online" button
                          if (index == _searchResults.length) {
                            if (widget.northBound != null && !_searchedOnline && !_isSearchingOnline) {
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextButton.icon(
                                  onPressed: _searchOnlineForMore,
                                  icon: const Icon(Icons.cloud_download, size: 18),
                                  label: const Text('Search online for more trails'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              );
                            } else if (_isSearchingOnline) {
                              return const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Searching online...'),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }

                          final result = _searchResults[index];
                          final isSaved = result.placeType == 'saved_location' ||
                              ref.watch(isLocationSavedProvider(result.displayName));
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: Icon(
                                  _getIconForPlaceType(result.placeType),
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                title: Text(
                                  result.displayName,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                subtitle: result.address != null
                                    ? Text(
                                        result.address!,
                                        style: Theme.of(context).textTheme.bodySmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : result.latitude != null && result.longitude != null
                                        ? Text(
                                            '${result.latitude!.toStringAsFixed(5)}, ${result.longitude!.toStringAsFixed(5)}',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          )
                                        : null,
                                trailing: IconButton(
                                  icon: Icon(
                                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                                    color: isSaved
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                    size: 20,
                                  ),
                                  tooltip: isSaved ? 'Remove saved location' : 'Save location',
                                  onPressed: () => _toggleSaveLocation(result, isSaved),
                                ),
                                onTap: () => _selectResult(result),
                              ),
                              if (index < _searchResults.length - 1)
                                const Divider(height: 1),
                            ],
                          );
                        },
                      ),
          ),
      ],
    );
  }

  Future<void> _toggleSaveLocation(MapSearchResult result, bool isSaved) async {
    if (isSaved) {
      ref.read(savedLocationProvider.notifier).deleteByDisplayName(result.displayName);
      return;
    }
    // Resolve coordinates first if needed
    var resolved = result;
    if (result.needsRetrieval) {
      final retrieved = await widget.searchService.retrieveCoordinates(result);
      if (retrieved == null || retrieved.latitude == null) return;
      resolved = retrieved;
    }
    if (resolved.latitude != null && resolved.longitude != null) {
      ref.read(savedLocationProvider.notifier).addFromSearchResult(resolved);
    }
  }

  IconData _getIconForPlaceType(String? placeType) {
    switch (placeType) {
      case 'trail':
        return Icons.hiking;
      case 'coordinate':
        return Icons.location_on;
      case 'country':
        return Icons.public;
      case 'region':
      case 'state':
        return Icons.map;
      case 'city':
      case 'town':
        return Icons.location_city;
      case 'address':
        return Icons.home;
      case 'poi':
        return Icons.place;
      case 'saved_location':
        return Icons.bookmark;
      default:
        return Icons.search;
    }
  }

  void _showSearchHelp() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline),
            SizedBox(width: 8),
            Text('Search Help'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Place Names',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text('• "Black Hills National Forest"'),
              const Text('• "Rapid City, South Dakota"'),
              const Text('• "BLM land near Deadwood"'),
              const SizedBox(height: 16),
              Text(
                'Trail Names',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text('• "Tea Kettle Trail"'),
              const Text('• "George Mickelson Trail"'),
              const Text('• Any trail name in the database'),
              const SizedBox(height: 16),
              Text(
                'Coordinates',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text('• Decimal: "44.5, -103.5"'),
              const Text('• DMS: "44°30\'N 103°30\'W"'),
              const Text('• Space or comma separated'),
              const SizedBox(height: 16),
              Text(
                'Tips',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text('• Results are ordered by relevance'),
              const Text('• Coordinates show exact location'),
              const Text('• Press Enter to select first result'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

/// Compact search button that expands into full search widget
class CompactMapSearchButton extends StatefulWidget {
  const CompactMapSearchButton({
    required this.searchService,
    required this.onResultSelected,
    super.key,
    this.proximityLat,
    this.proximityLon,
  });

  final MapSearchService searchService;
  final SearchResultCallback onResultSelected;
  final double? proximityLat;
  final double? proximityLon;

  @override
  State<CompactMapSearchButton> createState() => _CompactMapSearchButtonState();
}

class _CompactMapSearchButtonState extends State<CompactMapSearchButton>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        return Container(
          width: _isExpanded
              ? MediaQuery.of(context).size.width - 32
              : 56, // FAB size
          constraints: const BoxConstraints(maxWidth: 400),
          child: _isExpanded
              ? Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: _toggleExpanded,
                        ),
                        Expanded(
                          child: MapSearchWidget(
                            searchService: widget.searchService,
                            onResultSelected: (result) {
                              widget.onResultSelected(result);
                              _toggleExpanded(); // Collapse after selection
                            },
                            onClose: _toggleExpanded, // Collapse when dismissed
                            proximityLat: widget.proximityLat,
                            proximityLon: widget.proximityLon,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : FloatingActionButton(
                  onPressed: _toggleExpanded,
                  tooltip: 'Search Map',
                  child: const Icon(Icons.search),
                ),
        );
      },
    );
  }
}
