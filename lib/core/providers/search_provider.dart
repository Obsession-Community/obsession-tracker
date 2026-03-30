import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/search_models.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/photo_capture_service.dart';

/// Provider for the database service
final Provider<DatabaseService> databaseServiceProvider =
    Provider<DatabaseService>((Ref ref) => DatabaseService());

/// Provider for the photo capture service
final Provider<PhotoCaptureService> photoCaptureServiceProvider =
    Provider<PhotoCaptureService>((Ref ref) => PhotoCaptureService());

/// Search state for managing search functionality
@immutable
class SearchState {
  const SearchState({
    this.query = const SearchQuery(
      text: '',
      filters: SearchFilters(),
      sortOption: SearchSortOption.relevance,
    ),
    this.results = const [],
    this.suggestions = const [],
    this.isLoading = false,
    this.isLoadingSuggestions = false,
    this.error,
    this.hasSearched = false,
    this.recentSearches = const [],
  });

  final SearchQuery query;
  final List<SearchResult> results;
  final List<SearchSuggestion> suggestions;
  final bool isLoading;
  final bool isLoadingSuggestions;
  final String? error;
  final bool hasSearched;
  final List<String> recentSearches;

  SearchState copyWith({
    SearchQuery? query,
    List<SearchResult>? results,
    List<SearchSuggestion>? suggestions,
    bool? isLoading,
    bool? isLoadingSuggestions,
    String? error,
    bool? hasSearched,
    List<String>? recentSearches,
    bool clearError = false,
  }) =>
      SearchState(
        query: query ?? this.query,
        results: results ?? this.results,
        suggestions: suggestions ?? this.suggestions,
        isLoading: isLoading ?? this.isLoading,
        isLoadingSuggestions: isLoadingSuggestions ?? this.isLoadingSuggestions,
        error: clearError ? null : (error ?? this.error),
        hasSearched: hasSearched ?? this.hasSearched,
        recentSearches: recentSearches ?? this.recentSearches,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchState &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          listEquals(results, other.results) &&
          listEquals(suggestions, other.suggestions) &&
          isLoading == other.isLoading &&
          isLoadingSuggestions == other.isLoadingSuggestions &&
          error == other.error &&
          hasSearched == other.hasSearched &&
          listEquals(recentSearches, other.recentSearches);

  @override
  int get hashCode => Object.hash(
        query,
        Object.hashAll(results),
        Object.hashAll(suggestions),
        isLoading,
        isLoadingSuggestions,
        error,
        hasSearched,
        Object.hashAll(recentSearches),
      );
}

/// Search notifier for managing search state and operations
class SearchNotifier extends Notifier<SearchState> {
  /// Debounce timer for search suggestions
  Timer? _suggestionTimer;

  @override
  SearchState build() {
    ref.onDispose(() {
      _suggestionTimer?.cancel();
    });
    _loadRecentSearches();
    return const SearchState();
  }
  static const Duration _suggestionDebounce = Duration(milliseconds: 300);

  /// Cache for search suggestions
  final Map<String, List<SearchSuggestion>> _suggestionCache =
      <String, List<SearchSuggestion>>{};
  final Map<String, DateTime> _suggestionCacheTimestamps = <String, DateTime>{};
  static const Duration _suggestionCacheTimeout = Duration(minutes: 5);

  /// Recent searches storage
  static const int _maxRecentSearches = 10;

  /// Perform search with the current query
  Future<void> search() async {
    if (state.query.isEmpty) {
      state = state.copyWith(
        results: [],
        hasSearched: false,
        clearError: true,
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final List<SearchResult> results = await _performSearch(state.query);

      // Add to recent searches
      _addToRecentSearches(state.query.text);

      state = state.copyWith(
        results: results,
        isLoading: false,
        hasSearched: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Search failed: $e',
      );
    }
  }

  /// Update search text and optionally trigger search
  void updateSearchText(String text, {bool autoSearch = false}) {
    final SearchQuery newQuery = state.query.copyWith(text: text);
    state = state.copyWith(query: newQuery);

    if (autoSearch && text.isNotEmpty) {
      search();
    }

    // Update suggestions with debounce
    _updateSuggestionsDebounced(text);
  }

  /// Update search filters
  void updateFilters(SearchFilters filters) {
    final SearchQuery newQuery = state.query.copyWith(filters: filters);
    state = state.copyWith(query: newQuery);

    // Re-search if we have searched before
    if (state.hasSearched) {
      search();
    }
  }

  /// Update sort option
  void updateSortOption(SearchSortOption sortOption) {
    final SearchQuery newQuery = state.query.copyWith(sortOption: sortOption);
    state = state.copyWith(query: newQuery);

    // Re-sort existing results
    if (state.results.isNotEmpty) {
      final List<SearchResult> sortedResults =
          _sortResults(state.results, sortOption);
      state = state.copyWith(results: sortedResults);
    }
  }

  /// Clear search results and query
  void clearSearch() {
    state = state.copyWith(
      query: const SearchQuery(
        text: '',
        filters: SearchFilters(),
        sortOption: SearchSortOption.relevance,
      ),
      results: [],
      suggestions: [],
      hasSearched: false,
      clearError: true,
    );
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Get suggestions for search input
  void _updateSuggestionsDebounced(String input) {
    _suggestionTimer?.cancel();
    _suggestionTimer = Timer(_suggestionDebounce, () {
      _updateSuggestions(input);
    });
  }

  /// Update suggestions based on input
  Future<void> _updateSuggestions(String input) async {
    if (input.trim().isEmpty) {
      state = state.copyWith(
        suggestions: _getRecentSearchSuggestions(),
        isLoadingSuggestions: false,
      );
      return;
    }

    // Check cache first
    final String cacheKey = input.toLowerCase();
    if (_suggestionCache.containsKey(cacheKey)) {
      final DateTime? timestamp = _suggestionCacheTimestamps[cacheKey];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _suggestionCacheTimeout) {
        state = state.copyWith(
          suggestions: _suggestionCache[cacheKey],
          isLoadingSuggestions: false,
        );
        return;
      }
    }

    state = state.copyWith(isLoadingSuggestions: true);

    try {
      final List<SearchSuggestion> suggestions = await _getSuggestions(input);

      // Cache the results
      _suggestionCache[cacheKey] = suggestions;
      _suggestionCacheTimestamps[cacheKey] = DateTime.now();

      state = state.copyWith(
        suggestions: suggestions,
        isLoadingSuggestions: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingSuggestions: false,
        error: 'Failed to load suggestions: $e',
      );
    }
  }

  /// Perform the actual search operation
  Future<List<SearchResult>> _performSearch(SearchQuery query) async {
    final List<SearchResult> results = <SearchResult>[];

    // Search based on content type filters
    final Set<SearchContentType> contentTypes = query.filters.contentTypes;

    if (contentTypes.contains(SearchContentType.all) ||
        contentTypes.contains(SearchContentType.photos)) {
      final List<PhotoSearchResult> photoResults = await _searchPhotos(query);
      results.addAll(photoResults);
    }

    if (contentTypes.contains(SearchContentType.all) ||
        contentTypes.contains(SearchContentType.waypoints)) {
      final List<WaypointSearchResult> waypointResults =
          await _searchWaypoints(query);
      results.addAll(waypointResults);
    }

    if (contentTypes.contains(SearchContentType.all) ||
        contentTypes.contains(SearchContentType.sessions)) {
      final List<SessionSearchResult> sessionResults =
          await _searchSessions(query);
      results.addAll(sessionResults);
    }

    if (contentTypes.contains(SearchContentType.all) ||
        contentTypes.contains(SearchContentType.voiceNotes)) {
      final List<VoiceNoteSearchResult> voiceNoteResults =
          await _searchVoiceNotes(query);
      results.addAll(voiceNoteResults);
    }

    // Apply additional filters
    final List<SearchResult> filteredResults =
        _applyFilters(results, query.filters);

    // Sort results
    final List<SearchResult> sortedResults =
        _sortResults(filteredResults, query.sortOption);

    return sortedResults;
  }

  /// Search photos (simplified implementation)
  Future<List<PhotoSearchResult>> _searchPhotos(SearchQuery query) async =>
      // This is a simplified implementation
      // In a real implementation, this would use the SearchService
      [];

  /// Search waypoints (simplified implementation)
  Future<List<WaypointSearchResult>> _searchWaypoints(
          SearchQuery query) async =>
      // This is a simplified implementation
      // In a real implementation, this would use the SearchService
      [];

  /// Search sessions (simplified implementation)
  Future<List<SessionSearchResult>> _searchSessions(SearchQuery query) async =>
      // This is a simplified implementation
      // In a real implementation, this would use the SearchService
      [];

  /// Search voice notes (simplified implementation)
  Future<List<VoiceNoteSearchResult>> _searchVoiceNotes(
          SearchQuery query) async =>
      // This is a simplified implementation
      // In a real implementation, this would use the SearchService
      [];

  /// Apply additional filters to search results
  List<SearchResult> _applyFilters(
          List<SearchResult> results, SearchFilters filters) =>
      results.where((result) {
        // Apply favorites filter for photos
        if (filters.favoritesOnly && result is PhotoSearchResult) {
          if (!result.isFavorite) return false;
        }

        // Apply rating filter for photos
        if (result is PhotoSearchResult) {
          if (filters.minRating != null &&
              (result.rating ?? 0) < filters.minRating!) {
            return false;
          }
          if (filters.maxRating != null &&
              (result.rating ?? 0) > filters.maxRating!) {
            return false;
          }
        }

        return true;
      }).toList();

  /// Sort search results based on sort option
  List<SearchResult> _sortResults(
      List<SearchResult> results, SearchSortOption sortOption) {
    final List<SearchResult> sortedResults = List<SearchResult>.from(results);

    switch (sortOption) {
      case SearchSortOption.relevance:
        sortedResults
            .sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
        break;
      case SearchSortOption.dateNewest:
        sortedResults.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case SearchSortOption.dateOldest:
        sortedResults.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case SearchSortOption.nameAZ:
        sortedResults.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SearchSortOption.nameZA:
        sortedResults.sort((a, b) => b.title.compareTo(a.title));
        break;
      case SearchSortOption.rating:
        sortedResults.sort((a, b) {
          if (a is PhotoSearchResult && b is PhotoSearchResult) {
            return (b.rating ?? 0).compareTo(a.rating ?? 0);
          }
          return 0;
        });
        break;
      case SearchSortOption.distance:
        // Would need current location to implement distance sorting
        break;
    }

    return sortedResults;
  }

  /// Get search suggestions based on input
  Future<List<SearchSuggestion>> _getSuggestions(String input) async {
    final List<SearchSuggestion> suggestions = <SearchSuggestion>[];

    // Add recent searches that match
    suggestions.addAll(_getMatchingRecentSearches(input));

    // Add waypoint type suggestions
    suggestions.addAll(_getWaypointTypeSuggestions(input));

    // Limit total suggestions
    return suggestions.take(10).toList();
  }

  /// Get recent search suggestions
  List<SearchSuggestion> _getRecentSearchSuggestions() => state.recentSearches
      .map((search) => SearchSuggestion(
            text: search,
            type: SearchSuggestionType.recent,
          ))
      .toList();

  /// Get matching recent searches
  List<SearchSuggestion> _getMatchingRecentSearches(String input) {
    final String inputLower = input.toLowerCase();
    return state.recentSearches
        .where((search) => search.toLowerCase().contains(inputLower))
        .map((search) => SearchSuggestion(
              text: search,
              type: SearchSuggestionType.recent,
            ))
        .toList();
  }

  /// Get waypoint type suggestions
  List<SearchSuggestion> _getWaypointTypeSuggestions(String input) {
    final String inputLower = input.toLowerCase();
    return WaypointType.values
        .where((WaypointType type) => type.displayName.toLowerCase().contains(inputLower))
        .map((WaypointType type) => SearchSuggestion(
              text: type.displayName,
              type: SearchSuggestionType.waypointType,
              icon: type.iconName,
            ))
        .take(5)
        .toList();
  }

  /// Add search to recent searches
  void _addToRecentSearches(String search) {
    if (search.trim().isEmpty) return;

    final List<String> updatedRecent = List<String>.from(state.recentSearches);
    updatedRecent.remove(search);
    updatedRecent.insert(0, search);

    if (updatedRecent.length > _maxRecentSearches) {
      updatedRecent.removeRange(_maxRecentSearches, updatedRecent.length);
    }

    state = state.copyWith(recentSearches: updatedRecent);
    _saveRecentSearches();
  }

  /// Load recent searches from storage
  void _loadRecentSearches() {
    // In a real implementation, this would load from shared preferences
    // For now, we'll start with an empty list
  }

  /// Save recent searches to storage
  void _saveRecentSearches() {
    // In a real implementation, this would save to shared preferences
  }

  /// Clear recent searches
  void clearRecentSearches() {
    state = state.copyWith(recentSearches: []);
    _saveRecentSearches();
  }

  /// Clear suggestion cache
  void clearSuggestionCache() {
    _suggestionCache.clear();
    _suggestionCacheTimestamps.clear();
  }

}

/// Provider for search state management
final NotifierProvider<SearchNotifier, SearchState> searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);

/// Provider for search results
final Provider<List<SearchResult>> searchResultsProvider =
    Provider<List<SearchResult>>((Ref ref) {
  final SearchState searchState = ref.watch(searchProvider);
  return searchState.results;
});

/// Provider for search suggestions
final Provider<List<SearchSuggestion>> searchSuggestionsProvider =
    Provider<List<SearchSuggestion>>((Ref ref) {
  final SearchState searchState = ref.watch(searchProvider);
  return searchState.suggestions;
});

/// Provider for search query
final Provider<SearchQuery> searchQueryProvider =
    Provider<SearchQuery>((Ref ref) {
  final SearchState searchState = ref.watch(searchProvider);
  return searchState.query;
});

/// Provider for search loading state
final Provider<bool> searchLoadingProvider = Provider<bool>((Ref ref) {
  final SearchState searchState = ref.watch(searchProvider);
  return searchState.isLoading;
});

/// Provider for search error
final Provider<String?> searchErrorProvider = Provider<String?>((Ref ref) {
  final SearchState searchState = ref.watch(searchProvider);
  return searchState.error;
});

/// Provider for filtered search results by type
final 
    searchResultsByTypeProvider =
    Provider.family<List<SearchResult>, SearchContentType>(
        (Ref ref, SearchContentType type) {
  final List<SearchResult> allResults = ref.watch(searchResultsProvider);

  if (type == SearchContentType.all) {
    return allResults;
  }

  return allResults.where((result) => result.type == type).toList();
});

/// Provider for search result count
final Provider<int> searchResultCountProvider = Provider<int>((Ref ref) {
  final List<SearchResult> results = ref.watch(searchResultsProvider);
  return results.length;
});

/// Provider for search result count by type
final  searchResultCountByTypeProvider =
    Provider.family<int, SearchContentType>((Ref ref, SearchContentType type) {
  final List<SearchResult> results =
      ref.watch(searchResultsByTypeProvider(type));
  return results.length;
});
