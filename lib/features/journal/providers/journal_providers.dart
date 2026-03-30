import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/features/journal/data/models/entry_type.dart';
import 'package:obsession_tracker/features/journal/data/models/journal_entry.dart';
import 'package:obsession_tracker/features/journal/data/models/mood.dart';
import 'package:obsession_tracker/features/journal/domain/services/journal_service.dart';

// ============================================================
// Journal Entry Notifier
// ============================================================

/// State notifier for managing journal entry operations
class JournalNotifier extends Notifier<AsyncValue<List<JournalEntry>>> {
  late final JournalService _journalService;

  @override
  AsyncValue<List<JournalEntry>> build() {
    _journalService = JournalService();

    // Load entries asynchronously
    loadEntries();
    return const AsyncValue.loading();
  }

  /// Load all journal entries from database
  Future<void> loadEntries() async {
    try {
      debugPrint('JournalNotifier: Loading journal entries...');
      state = const AsyncValue.loading();
      final entries = await _journalService.getAllEntries();
      debugPrint('JournalNotifier: Loaded ${entries.length} entries');
      state = AsyncValue.data(entries);
    } catch (error, stackTrace) {
      debugPrint('JournalNotifier: Error loading entries: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Create a new journal entry
  Future<JournalEntry?> createEntry({
    required String content,
    String? title,
    JournalEntryType entryType = JournalEntryType.note,
    String? sessionId,
    String? huntId,
    double? latitude,
    double? longitude,
    String? locationName,
    JournalMood? mood,
    String? weatherNotes,
    List<String> tags = const [],
    bool isPinned = false,
    bool isHighlight = false,
  }) async {
    try {
      final entry = await _journalService.createEntry(
        content: content,
        title: title,
        entryType: entryType,
        sessionId: sessionId,
        huntId: huntId,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
        mood: mood,
        weatherNotes: weatherNotes,
        tags: tags,
        isPinned: isPinned,
        isHighlight: isHighlight,
      );
      await loadEntries();
      return entry;
    } catch (error) {
      debugPrint('JournalNotifier: Error creating entry: $error');
      return null;
    }
  }

  /// Update an existing journal entry
  Future<bool> updateEntry(JournalEntry entry) async {
    try {
      await _journalService.updateEntry(entry);
      await loadEntries();
      return true;
    } catch (error) {
      debugPrint('JournalNotifier: Error updating entry: $error');
      return false;
    }
  }

  /// Delete a journal entry
  Future<bool> deleteEntry(String entryId) async {
    try {
      await _journalService.deleteEntry(entryId);
      await loadEntries();
      return true;
    } catch (error) {
      debugPrint('JournalNotifier: Error deleting entry: $error');
      return false;
    }
  }

  /// Toggle pin status on an entry
  Future<bool> togglePin(String entryId) async {
    try {
      await _journalService.togglePin(entryId);
      await loadEntries();
      return true;
    } catch (error) {
      debugPrint('JournalNotifier: Error toggling pin: $error');
      return false;
    }
  }

  /// Toggle highlight status on an entry
  Future<bool> toggleHighlight(String entryId) async {
    try {
      await _journalService.toggleHighlight(entryId);
      await loadEntries();
      return true;
    } catch (error) {
      debugPrint('JournalNotifier: Error toggling highlight: $error');
      return false;
    }
  }

  /// Link an entry to a session
  Future<bool> linkToSession(String entryId, String sessionId) async {
    try {
      await _journalService.linkToSession(entryId, sessionId);
      await loadEntries();
      return true;
    } catch (error) {
      debugPrint('JournalNotifier: Error linking to session: $error');
      return false;
    }
  }

  /// Unlink an entry from its session
  Future<bool> unlinkFromSession(String entryId) async {
    try {
      await _journalService.unlinkFromSession(entryId);
      await loadEntries();
      return true;
    } catch (error) {
      debugPrint('JournalNotifier: Error unlinking from session: $error');
      return false;
    }
  }

  /// Link an entry to a hunt
  Future<bool> linkToHunt(String entryId, String huntId) async {
    try {
      await _journalService.linkToHunt(entryId, huntId);
      await loadEntries();
      return true;
    } catch (error) {
      debugPrint('JournalNotifier: Error linking to hunt: $error');
      return false;
    }
  }

  /// Unlink an entry from its hunt
  Future<bool> unlinkFromHunt(String entryId) async {
    try {
      await _journalService.unlinkFromHunt(entryId);
      await loadEntries();
      return true;
    } catch (error) {
      debugPrint('JournalNotifier: Error unlinking from hunt: $error');
      return false;
    }
  }

  /// Set location on an entry
  Future<bool> setLocation(
    String entryId, {
    required double latitude,
    required double longitude,
    String? locationName,
  }) async {
    try {
      await _journalService.setLocation(
        entryId,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
      );
      await loadEntries();
      return true;
    } catch (error) {
      debugPrint('JournalNotifier: Error setting location: $error');
      return false;
    }
  }

  /// Clear location from an entry
  Future<bool> clearLocation(String entryId) async {
    try {
      await _journalService.clearLocation(entryId);
      await loadEntries();
      return true;
    } catch (error) {
      debugPrint('JournalNotifier: Error clearing location: $error');
      return false;
    }
  }

  /// Refresh entries list
  Future<void> refresh() async {
    await loadEntries();
  }
}

/// Main provider for journal entry management
final journalProvider =
    NotifierProvider<JournalNotifier, AsyncValue<List<JournalEntry>>>(
  JournalNotifier.new,
);

// ============================================================
// Individual Entry Providers
// ============================================================

/// Provider for getting a specific journal entry by ID
final journalEntryByIdProvider =
    Provider.family<JournalEntry?, String>((ref, entryId) {
  final entriesAsync = ref.watch(journalProvider);
  return entriesAsync.maybeWhen(
    data: (entries) {
      try {
        return entries.firstWhere((entry) => entry.id == entryId);
      } catch (e) {
        return null;
      }
    },
    orElse: () => null,
  );
});

// ============================================================
// Filtered Providers
// ============================================================

/// Provider for entries linked to a specific session
final entriesForSessionProvider =
    Provider.family<List<JournalEntry>, String>((ref, sessionId) {
  final entriesAsync = ref.watch(journalProvider);
  return entriesAsync.maybeWhen(
    data: (entries) =>
        entries.where((e) => e.sessionId == sessionId).toList(),
    orElse: () => [],
  );
});

/// Provider for entries linked to a specific hunt
final entriesForHuntProvider =
    Provider.family<List<JournalEntry>, String>((ref, huntId) {
  final entriesAsync = ref.watch(journalProvider);
  return entriesAsync.maybeWhen(
    data: (entries) => entries.where((e) => e.huntId == huntId).toList(),
    orElse: () => [],
  );
});

/// Provider for pinned entries only
final pinnedEntriesProvider = Provider<List<JournalEntry>>((ref) {
  final entriesAsync = ref.watch(journalProvider);
  return entriesAsync.maybeWhen(
    data: (entries) => entries.where((e) => e.isPinned).toList(),
    orElse: () => [],
  );
});

/// Provider for highlighted entries only
final highlightedEntriesProvider = Provider<List<JournalEntry>>((ref) {
  final entriesAsync = ref.watch(journalProvider);
  return entriesAsync.maybeWhen(
    data: (entries) => entries.where((e) => e.isHighlight).toList(),
    orElse: () => [],
  );
});

/// Provider for entries with location data
final entriesWithLocationProvider = Provider<List<JournalEntry>>((ref) {
  final entriesAsync = ref.watch(journalProvider);
  return entriesAsync.maybeWhen(
    data: (entries) => entries.where((e) => e.hasLocation).toList(),
    orElse: () => [],
  );
});

/// Provider for standalone entries (no session or hunt link)
final standaloneEntriesProvider = Provider<List<JournalEntry>>((ref) {
  final entriesAsync = ref.watch(journalProvider);
  return entriesAsync.maybeWhen(
    data: (entries) => entries.where((e) => e.isStandalone).toList(),
    orElse: () => [],
  );
});

/// Provider for entries by type
final entriesByTypeProvider =
    Provider.family<List<JournalEntry>, JournalEntryType>((ref, type) {
  final entriesAsync = ref.watch(journalProvider);
  return entriesAsync.maybeWhen(
    data: (entries) => entries.where((e) => e.entryType == type).toList(),
    orElse: () => [],
  );
});

// ============================================================
// Statistics Provider
// ============================================================

/// Provider for journal statistics
final journalStatisticsProvider =
    FutureProvider<JournalStatistics>((ref) async {
  final journalService = JournalService();
  return journalService.getStatistics();
});

/// Provider for total entry count
final journalEntryCountProvider = Provider<int>((ref) {
  final entriesAsync = ref.watch(journalProvider);
  return entriesAsync.maybeWhen(
    data: (entries) => entries.length,
    orElse: () => 0,
  );
});

// ============================================================
// Search Provider
// ============================================================

/// State notifier for journal search
class JournalSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

/// Provider for search query state
final journalSearchQueryProvider =
    NotifierProvider<JournalSearchNotifier, String>(JournalSearchNotifier.new);

/// Provider for search results
final journalSearchResultsProvider = Provider<List<JournalEntry>>((ref) {
  final query = ref.watch(journalSearchQueryProvider);
  if (query.isEmpty) return [];

  final entriesAsync = ref.watch(journalProvider);
  return entriesAsync.maybeWhen(
    data: (entries) {
      final lowerQuery = query.toLowerCase();
      return entries.where((entry) {
        final titleMatch =
            entry.title?.toLowerCase().contains(lowerQuery) ?? false;
        final contentMatch = entry.content.toLowerCase().contains(lowerQuery);
        final locationMatch =
            entry.locationName?.toLowerCase().contains(lowerQuery) ?? false;
        final tagMatch =
            entry.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
        return titleMatch || contentMatch || locationMatch || tagMatch;
      }).toList();
    },
    orElse: () => [],
  );
});

// ============================================================
// Filter Provider
// ============================================================

/// Filter state for journal list
@immutable
class JournalFilter {
  const JournalFilter({
    this.entryType,
    this.sessionId,
    this.huntId,
    this.showPinnedOnly = false,
    this.showHighlightsOnly = false,
    this.showWithLocationOnly = false,
  });

  final JournalEntryType? entryType;
  final String? sessionId;
  final String? huntId;
  final bool showPinnedOnly;
  final bool showHighlightsOnly;
  final bool showWithLocationOnly;

  bool get hasActiveFilter =>
      entryType != null ||
      sessionId != null ||
      huntId != null ||
      showPinnedOnly ||
      showHighlightsOnly ||
      showWithLocationOnly;

  JournalFilter copyWith({
    JournalEntryType? entryType,
    String? sessionId,
    String? huntId,
    bool? showPinnedOnly,
    bool? showHighlightsOnly,
    bool? showWithLocationOnly,
    bool clearEntryType = false,
    bool clearSessionId = false,
    bool clearHuntId = false,
  }) {
    return JournalFilter(
      entryType: clearEntryType ? null : (entryType ?? this.entryType),
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      huntId: clearHuntId ? null : (huntId ?? this.huntId),
      showPinnedOnly: showPinnedOnly ?? this.showPinnedOnly,
      showHighlightsOnly: showHighlightsOnly ?? this.showHighlightsOnly,
      showWithLocationOnly: showWithLocationOnly ?? this.showWithLocationOnly,
    );
  }

  static const JournalFilter none = JournalFilter();
}

/// State notifier for journal filter
class JournalFilterNotifier extends Notifier<JournalFilter> {
  @override
  JournalFilter build() => JournalFilter.none;

  void setEntryType(JournalEntryType? type) {
    state = state.copyWith(entryType: type, clearEntryType: type == null);
  }

  void setSessionId(String? sessionId) {
    state = state.copyWith(sessionId: sessionId, clearSessionId: sessionId == null);
  }

  void setHuntId(String? huntId) {
    state = state.copyWith(huntId: huntId, clearHuntId: huntId == null);
  }

  void setShowPinnedOnly(bool value) {
    state = state.copyWith(showPinnedOnly: value);
  }

  void setShowHighlightsOnly(bool value) {
    state = state.copyWith(showHighlightsOnly: value);
  }

  void setShowWithLocationOnly(bool value) {
    state = state.copyWith(showWithLocationOnly: value);
  }

  void clearFilters() {
    state = JournalFilter.none;
  }
}

/// Provider for filter state
final journalFilterProvider =
    NotifierProvider<JournalFilterNotifier, JournalFilter>(
  JournalFilterNotifier.new,
);

/// Provider for filtered entries based on current filter state
final filteredJournalEntriesProvider = Provider<List<JournalEntry>>((ref) {
  final filter = ref.watch(journalFilterProvider);
  final entriesAsync = ref.watch(journalProvider);

  return entriesAsync.maybeWhen(
    data: (entries) {
      var filtered = entries;

      if (filter.entryType != null) {
        filtered = filtered.where((e) => e.entryType == filter.entryType).toList();
      }

      if (filter.sessionId != null) {
        filtered = filtered.where((e) => e.sessionId == filter.sessionId).toList();
      }

      if (filter.huntId != null) {
        filtered = filtered.where((e) => e.huntId == filter.huntId).toList();
      }

      if (filter.showPinnedOnly) {
        filtered = filtered.where((e) => e.isPinned).toList();
      }

      if (filter.showHighlightsOnly) {
        filtered = filtered.where((e) => e.isHighlight).toList();
      }

      if (filter.showWithLocationOnly) {
        filtered = filtered.where((e) => e.hasLocation).toList();
      }

      return filtered;
    },
    orElse: () => [],
  );
});

// ============================================================
// Tags Provider
// ============================================================

/// Provider for all unique tags used in journal entries
final journalTagsProvider = Provider<List<String>>((ref) {
  final entriesAsync = ref.watch(journalProvider);
  return entriesAsync.maybeWhen(
    data: (entries) {
      final Set<String> tags = {};
      for (final entry in entries) {
        tags.addAll(entry.tags);
      }
      return tags.toList()..sort();
    },
    orElse: () => [],
  );
});

/// Provider for entries with a specific tag
final entriesByTagProvider =
    Provider.family<List<JournalEntry>, String>((ref, tag) {
  final entriesAsync = ref.watch(journalProvider);
  final lowerTag = tag.toLowerCase();
  return entriesAsync.maybeWhen(
    data: (entries) => entries
        .where((e) => e.tags.any((t) => t.toLowerCase() == lowerTag))
        .toList(),
    orElse: () => [],
  );
});
