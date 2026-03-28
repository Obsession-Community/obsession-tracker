import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/features/journal/data/models/entry_type.dart';
import 'package:obsession_tracker/features/journal/data/models/journal_entry.dart';
import 'package:obsession_tracker/features/journal/data/models/mood.dart';
import 'package:uuid/uuid.dart';

/// Service for managing journal entries.
///
/// Provides a complete API for the Field Journal feature, handling:
/// - CRUD operations for journal entries
/// - Filtering by session, hunt, and entry type
/// - Search and organization
/// - Statistics and summaries
class JournalService {
  factory JournalService() => _instance ??= JournalService._();
  JournalService._();
  static JournalService? _instance;

  static const Uuid _uuid = Uuid();
  final DatabaseService _db = DatabaseService();

  // ============================================================
  // Journal Entry CRUD
  // ============================================================

  /// Create a new journal entry
  Future<JournalEntry> createEntry({
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
    final String id = _uuid.v4();
    final DateTime now = DateTime.now();

    final entry = JournalEntry(
      id: id,
      title: title,
      content: content,
      entryType: entryType,
      sessionId: sessionId,
      huntId: huntId,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      timestamp: now,
      mood: mood,
      weatherNotes: weatherNotes,
      tags: tags,
      isPinned: isPinned,
      isHighlight: isHighlight,
      createdAt: now,
    );

    await _db.insertJournalEntry(entry);
    debugPrint('Created journal entry: ${entry.title ?? entry.entryType.displayName} (${entry.id})');

    return entry;
  }

  /// Update an existing journal entry
  Future<JournalEntry> updateEntry(JournalEntry entry) async {
    final updated = entry.copyWith(updatedAt: DateTime.now());
    await _db.updateJournalEntry(updated);
    debugPrint('Updated journal entry: ${updated.title ?? updated.entryType.displayName} (${updated.id})');
    return updated;
  }

  /// Get a journal entry by ID
  Future<JournalEntry?> getEntry(String entryId) async {
    return _db.getJournalEntry(entryId);
  }

  /// Get all journal entries with optional filtering
  Future<List<JournalEntry>> getAllEntries({
    JournalEntryType? entryType,
    String? sessionId,
    String? huntId,
    bool? isPinned,
    bool? isHighlight,
    int? limit,
    int? offset,
  }) async {
    return _db.getJournalEntries(
      entryType: entryType?.name,
      sessionId: sessionId,
      huntId: huntId,
      isPinned: isPinned,
      isHighlight: isHighlight,
      limit: limit,
      offset: offset,
    );
  }

  /// Get journal entries for a specific session
  Future<List<JournalEntry>> getEntriesForSession(String sessionId) async {
    return _db.getJournalEntriesForSession(sessionId);
  }

  /// Get journal entries for a specific hunt
  Future<List<JournalEntry>> getEntriesForHunt(String huntId) async {
    return _db.getJournalEntriesForHunt(huntId);
  }

  /// Get pinned entries (convenience method)
  Future<List<JournalEntry>> getPinnedEntries() async {
    return getAllEntries(isPinned: true);
  }

  /// Get highlighted entries (convenience method)
  Future<List<JournalEntry>> getHighlightedEntries() async {
    return getAllEntries(isHighlight: true);
  }

  /// Get entries by type (convenience method)
  Future<List<JournalEntry>> getEntriesByType(JournalEntryType type) async {
    return getAllEntries(entryType: type);
  }

  /// Get standalone entries (no session or hunt link)
  Future<List<JournalEntry>> getStandaloneEntries() async {
    final allEntries = await getAllEntries();
    return allEntries.where((e) => e.isStandalone).toList();
  }

  /// Get entries with location data
  Future<List<JournalEntry>> getEntriesWithLocation() async {
    final allEntries = await getAllEntries();
    return allEntries.where((e) => e.hasLocation).toList();
  }

  /// Delete a journal entry
  Future<void> deleteEntry(String entryId) async {
    await _db.deleteJournalEntry(entryId);
    debugPrint('Deleted journal entry: $entryId');
  }

  // ============================================================
  // Entry Operations
  // ============================================================

  /// Toggle pin status on an entry
  Future<JournalEntry> togglePin(String entryId) async {
    final entry = await getEntry(entryId);
    if (entry == null) {
      throw Exception('Journal entry not found: $entryId');
    }

    final updated = entry.copyWith(
      isPinned: !entry.isPinned,
      updatedAt: DateTime.now(),
    );
    await _db.updateJournalEntry(updated);
    return updated;
  }

  /// Toggle highlight status on an entry
  Future<JournalEntry> toggleHighlight(String entryId) async {
    final entry = await getEntry(entryId);
    if (entry == null) {
      throw Exception('Journal entry not found: $entryId');
    }

    final updated = entry.copyWith(
      isHighlight: !entry.isHighlight,
      updatedAt: DateTime.now(),
    );
    await _db.updateJournalEntry(updated);
    return updated;
  }

  /// Link an entry to a session
  Future<JournalEntry> linkToSession(String entryId, String sessionId) async {
    final entry = await getEntry(entryId);
    if (entry == null) {
      throw Exception('Journal entry not found: $entryId');
    }

    final updated = entry.copyWith(
      sessionId: sessionId,
      updatedAt: DateTime.now(),
    );
    await _db.updateJournalEntry(updated);
    debugPrint('Linked entry $entryId to session $sessionId');
    return updated;
  }

  /// Unlink an entry from its session
  Future<JournalEntry> unlinkFromSession(String entryId) async {
    final entry = await getEntry(entryId);
    if (entry == null) {
      throw Exception('Journal entry not found: $entryId');
    }

    final updated = entry.clearSession();
    await _db.updateJournalEntry(updated);
    debugPrint('Unlinked entry $entryId from session');
    return updated;
  }

  /// Link an entry to a hunt
  Future<JournalEntry> linkToHunt(String entryId, String huntId) async {
    final entry = await getEntry(entryId);
    if (entry == null) {
      throw Exception('Journal entry not found: $entryId');
    }

    final updated = entry.copyWith(
      huntId: huntId,
      updatedAt: DateTime.now(),
    );
    await _db.updateJournalEntry(updated);
    debugPrint('Linked entry $entryId to hunt $huntId');
    return updated;
  }

  /// Unlink an entry from its hunt
  Future<JournalEntry> unlinkFromHunt(String entryId) async {
    final entry = await getEntry(entryId);
    if (entry == null) {
      throw Exception('Journal entry not found: $entryId');
    }

    final updated = entry.clearHunt();
    await _db.updateJournalEntry(updated);
    debugPrint('Unlinked entry $entryId from hunt');
    return updated;
  }

  /// Set location on an entry
  Future<JournalEntry> setLocation(
    String entryId, {
    required double latitude,
    required double longitude,
    String? locationName,
  }) async {
    final entry = await getEntry(entryId);
    if (entry == null) {
      throw Exception('Journal entry not found: $entryId');
    }

    final updated = entry.copyWith(
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      updatedAt: DateTime.now(),
    );
    await _db.updateJournalEntry(updated);
    return updated;
  }

  /// Clear location from an entry
  Future<JournalEntry> clearLocation(String entryId) async {
    final entry = await getEntry(entryId);
    if (entry == null) {
      throw Exception('Journal entry not found: $entryId');
    }

    final updated = entry.clearLocation();
    await _db.updateJournalEntry(updated);
    return updated;
  }

  // ============================================================
  // Statistics
  // ============================================================

  /// Get total entry count
  Future<int> getEntryCount() async {
    return _db.getJournalEntryCount();
  }

  /// Get entry counts by type
  Future<Map<JournalEntryType, int>> getCountsByType() async {
    final Map<JournalEntryType, int> counts = {};
    for (final type in JournalEntryType.values) {
      final entries = await getAllEntries(entryType: type);
      counts[type] = entries.length;
    }
    return counts;
  }

  /// Get journal statistics summary
  Future<JournalStatistics> getStatistics() async {
    final allEntries = await getAllEntries();
    final pinnedCount = allEntries.where((e) => e.isPinned).length;
    final highlightCount = allEntries.where((e) => e.isHighlight).length;
    final withLocationCount = allEntries.where((e) => e.hasLocation).length;
    final withSessionCount = allEntries.where((e) => e.hasSession).length;
    final withHuntCount = allEntries.where((e) => e.hasHunt).length;
    final standaloneCount = allEntries.where((e) => e.isStandalone).length;

    final Map<JournalEntryType, int> countsByType = {};
    for (final type in JournalEntryType.values) {
      countsByType[type] = allEntries.where((e) => e.entryType == type).length;
    }

    return JournalStatistics(
      totalEntries: allEntries.length,
      pinnedCount: pinnedCount,
      highlightCount: highlightCount,
      withLocationCount: withLocationCount,
      withSessionCount: withSessionCount,
      withHuntCount: withHuntCount,
      standaloneCount: standaloneCount,
      countsByType: countsByType,
    );
  }

  // ============================================================
  // Search
  // ============================================================

  /// Search entries by content and title
  Future<List<JournalEntry>> searchEntries(String query) async {
    if (query.isEmpty) {
      return [];
    }

    final allEntries = await getAllEntries();
    final lowerQuery = query.toLowerCase();

    return allEntries.where((entry) {
      final titleMatch = entry.title?.toLowerCase().contains(lowerQuery) ?? false;
      final contentMatch = entry.content.toLowerCase().contains(lowerQuery);
      final locationMatch = entry.locationName?.toLowerCase().contains(lowerQuery) ?? false;
      final tagMatch = entry.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));

      return titleMatch || contentMatch || locationMatch || tagMatch;
    }).toList();
  }

  /// Get entries by tag
  Future<List<JournalEntry>> getEntriesByTag(String tag) async {
    final allEntries = await getAllEntries();
    final lowerTag = tag.toLowerCase();

    return allEntries.where((entry) {
      return entry.tags.any((t) => t.toLowerCase() == lowerTag);
    }).toList();
  }

  /// Get all unique tags used in entries
  Future<List<String>> getAllTags() async {
    final allEntries = await getAllEntries();
    final Set<String> tags = {};

    for (final entry in allEntries) {
      tags.addAll(entry.tags);
    }

    return tags.toList()..sort();
  }

  // ============================================================
  // Milestone Generation (Auto-generated entries)
  // ============================================================

  /// Create a milestone entry (auto-generated)
  Future<JournalEntry> createMilestone({
    required String content,
    String? title,
    String? sessionId,
    String? huntId,
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    return createEntry(
      content: content,
      title: title,
      entryType: JournalEntryType.milestone,
      sessionId: sessionId,
      huntId: huntId,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
    );
  }
}

/// Journal statistics summary
@immutable
class JournalStatistics {
  const JournalStatistics({
    required this.totalEntries,
    required this.pinnedCount,
    required this.highlightCount,
    required this.withLocationCount,
    required this.withSessionCount,
    required this.withHuntCount,
    required this.standaloneCount,
    required this.countsByType,
  });

  final int totalEntries;
  final int pinnedCount;
  final int highlightCount;
  final int withLocationCount;
  final int withSessionCount;
  final int withHuntCount;
  final int standaloneCount;
  final Map<JournalEntryType, int> countsByType;
}
