import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/bff_app_config.dart';
import 'package:obsession_tracker/core/services/announcements_api_service.dart';
import 'package:obsession_tracker/core/services/app_lifecycle_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State representing the current announcements
class AnnouncementsState {
  const AnnouncementsState({
    this.announcements = const [],
    this.dismissedIds = const {},
    this.readIds = const {},
    this.isLoading = true,
    this.error,
  });

  /// All cached announcements (persisted locally)
  final List<Announcement> announcements;

  /// Set of dismissed announcement IDs
  final Set<String> dismissedIds;

  /// Set of read announcement IDs
  final Set<String> readIds;

  /// Whether announcements are still loading
  final bool isLoading;

  /// Error message if loading failed
  final String? error;

  /// Get visible announcements (not dismissed, not expired)
  List<Announcement> get visibleAnnouncements {
    return announcements
        .where((a) => !dismissedIds.contains(a.id) && !a.isExpired)
        .toList()
      ..sort((a, b) {
        // Sort unread first, then by priority, then by type
        final aUnread = !readIds.contains(a.id);
        final bUnread = !readIds.contains(b.id);
        if (aUnread != bUnread) return aUnread ? -1 : 1;

        final priorityCompare = _priorityValue(b.priority).compareTo(_priorityValue(a.priority));
        if (priorityCompare != 0) return priorityCompare;
        return _typeValue(b.type).compareTo(_typeValue(a.type));
      });
  }

  /// Get unread announcements (visible and not yet read)
  List<Announcement> get unreadAnnouncements {
    return visibleAnnouncements.where((a) => !readIds.contains(a.id)).toList();
  }

  /// Get read announcements (visible but already read)
  List<Announcement> get readAnnouncements {
    return visibleAnnouncements.where((a) => readIds.contains(a.id)).toList();
  }

  /// Count of unread/visible announcements for badge display
  int get unreadCount => unreadAnnouncements.length;

  /// Total count of visible announcements
  int get visibleCount => visibleAnnouncements.length;

  /// Whether there are any visible announcements
  bool get hasAnnouncements => visibleAnnouncements.isNotEmpty;

  /// Whether there are any unread announcements
  bool get hasUnread => unreadAnnouncements.isNotEmpty;

  /// Get highest priority visible announcement (for prominent display)
  Announcement? get topAnnouncement {
    final visible = visibleAnnouncements;
    return visible.isNotEmpty ? visible.first : null;
  }

  /// Get announcements of a specific type
  List<Announcement> getByType(AnnouncementType type) {
    return visibleAnnouncements.where((a) => a.type == type).toList();
  }

  /// Check if a specific announcement is read
  bool isRead(String id) => readIds.contains(id);

  /// Check if a specific announcement is dismissed
  bool isDismissed(String id) => dismissedIds.contains(id);

  /// Priority value for sorting (higher = more important)
  static int _priorityValue(AnnouncementPriority priority) {
    switch (priority) {
      case AnnouncementPriority.high:
        return 3;
      case AnnouncementPriority.medium:
        return 2;
      case AnnouncementPriority.low:
        return 1;
    }
  }

  /// Type value for sorting (higher = more important)
  static int _typeValue(AnnouncementType type) {
    switch (type) {
      case AnnouncementType.critical:
        return 10;
      case AnnouncementType.maintenance:
        return 9;
      case AnnouncementType.appUpdate:
        return 8;
      case AnnouncementType.treasureFound:
        return 7;
      case AnnouncementType.newHunt:
        return 6;
      case AnnouncementType.huntUpdate:
        return 5;
      case AnnouncementType.landData:
        return 4;
      case AnnouncementType.warning:
        return 3;
      case AnnouncementType.info:
        return 2;
      case AnnouncementType.general:
        return 1;
    }
  }

  AnnouncementsState copyWith({
    List<Announcement>? announcements,
    Set<String>? dismissedIds,
    Set<String>? readIds,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AnnouncementsState(
      announcements: announcements ?? this.announcements,
      dismissedIds: dismissedIds ?? this.dismissedIds,
      readIds: readIds ?? this.readIds,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Provider for announcements state
final announcementsProvider =
    NotifierProvider<AnnouncementsNotifier, AnnouncementsState>(
        AnnouncementsNotifier.new);

/// Provider for unread count (useful for badge display)
final announcementsUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(announcementsProvider).unreadCount;
});

/// Provider for checking if there are any announcements
final hasAnnouncementsProvider = Provider<bool>((ref) {
  return ref.watch(announcementsProvider).hasAnnouncements;
});

/// Provider for checking if there are unread announcements
final hasUnreadAnnouncementsProvider = Provider<bool>((ref) {
  return ref.watch(announcementsProvider).hasUnread;
});

/// Provider for the top/most important announcement
final topAnnouncementProvider = Provider<Announcement?>((ref) {
  return ref.watch(announcementsProvider).topAnnouncement;
});

/// Notifier that manages announcements state and persistence
class AnnouncementsNotifier extends Notifier<AnnouncementsState> {
  static const String _dismissedIdsKey = 'dismissed_announcement_ids';
  static const String _readIdsKey = 'read_announcement_ids';
  static const String _cachedAnnouncementsKey = 'cached_announcements';
  static const String _dismissedTimestampsKey = 'dismissed_announcement_timestamps';

  /// How long to remember dismissed announcements (30 days)
  static const Duration _dismissedRetentionPeriod = Duration(days: 30);

  StreamSubscription<AppLifecycleState>? _lifecycleSubscription;

  @override
  AnnouncementsState build() {
    // Subscribe to app lifecycle events for foreground refresh
    _lifecycleSubscription = AppLifecycleService().stateChanges.listen(_onLifecycleChange);

    // Clean up subscription when provider is disposed
    ref.onDispose(() {
      _lifecycleSubscription?.cancel();
    });

    _initialize();
    return const AnnouncementsState();
  }

  /// Handle app lifecycle changes - refresh announcements on foreground
  void _onLifecycleChange(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      debugPrint('📢 App resumed - refreshing announcements');
      refresh();
    }
  }

  Future<void> _initialize() async {
    try {
      // Load persisted data from storage
      final dismissedIds = await _loadDismissedIds();
      final readIds = await _loadReadIds();
      final cachedAnnouncements = await _loadCachedAnnouncements();

      // Update state with cached data first (fast initial load)
      state = state.copyWith(
        announcements: cachedAnnouncements,
        dismissedIds: dismissedIds,
        readIds: readIds,
        isLoading: cachedAnnouncements.isEmpty,
      );

      debugPrint('📢 Loaded ${cachedAnnouncements.length} cached announcements');

      // Fetch new announcements from API
      await _fetchAndMerge();

    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize announcements: $e');
      debugPrint('$stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load announcements',
      );
    }
  }

  /// Fetch all active announcements and update cache.
  ///
  /// The BFF returns ALL active announcements (published and not expired).
  /// This replaces the cache since the server is the source of truth for what's active.
  Future<void> _fetchAndMerge() async {
    try {
      // Get the custom endpoint from settings
      final prefs = await SharedPreferences.getInstance();
      final customEndpoint = prefs.getString('customApiEndpoint');

      // Fetch all active announcements from BFF
      final apiService = AnnouncementsApiService.instance;
      final result = await apiService.fetchAnnouncements(
        customEndpoint: customEndpoint,
        platform: apiService.getCurrentPlatform(),
      );

      if (result.success) {
        final fetchedAnnouncements = result.announcements;

        // Find truly new announcements (not in our current read set)
        final existingIds = state.announcements.map((a) => a.id).toSet();
        final newCount = fetchedAnnouncements
            .where((a) => !existingIds.contains(a.id))
            .length;

        if (newCount > 0) {
          debugPrint('📢 Found $newCount new announcements');
        }

        // Persist the updated cache (BFF response is source of truth)
        await _saveCachedAnnouncements(fetchedAnnouncements);

        state = state.copyWith(
          announcements: fetchedAnnouncements,
          isLoading: false,
          clearError: true,
        );

        debugPrint('📢 Total active: ${state.announcements.length}, '
            'visible: ${state.visibleCount}, unread: ${state.unreadCount}');
      } else {
        // Fetch failed but we still have cached data
        debugPrint('⚠️ Fetch failed, using cached announcements');
        state = state.copyWith(
          isLoading: false,
          error: result.error,
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch announcements: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to refresh announcements',
      );
    }
  }

  /// Refresh announcements from BFF
  Future<void> refresh() async {
    await _fetchAndMerge();
  }

  /// Mark an announcement as read
  Future<void> markAsRead(String announcementId) async {
    if (state.readIds.contains(announcementId)) return;

    final newReadIds = Set<String>.from(state.readIds)..add(announcementId);
    state = state.copyWith(readIds: newReadIds);
    await _saveReadIds(newReadIds);

    debugPrint('📢 Marked as read: $announcementId');
  }

  /// Mark all visible announcements as read
  Future<void> markAllAsRead() async {
    final allVisibleIds = state.visibleAnnouncements.map((a) => a.id).toSet();
    final newReadIds = Set<String>.from(state.readIds)..addAll(allVisibleIds);

    state = state.copyWith(readIds: newReadIds);
    await _saveReadIds(newReadIds);

    debugPrint('📢 Marked all ${allVisibleIds.length} as read');
  }

  /// Dismiss an announcement
  Future<void> dismiss(String announcementId) async {
    final newDismissedIds = Set<String>.from(state.dismissedIds)..add(announcementId);

    state = state.copyWith(dismissedIds: newDismissedIds);
    await _saveDismissedIds(newDismissedIds);

    debugPrint('📢 Dismissed announcement: $announcementId');
  }

  /// Dismiss all visible announcements
  Future<void> dismissAll() async {
    final allIds = state.visibleAnnouncements.map((a) => a.id).toSet();
    final newDismissedIds = Set<String>.from(state.dismissedIds)..addAll(allIds);

    state = state.copyWith(dismissedIds: newDismissedIds);
    await _saveDismissedIds(newDismissedIds);

    debugPrint('📢 Dismissed all ${allIds.length} announcements');
  }

  /// Restore a dismissed announcement (make it visible again)
  Future<void> restore(String announcementId) async {
    final newDismissedIds = Set<String>.from(state.dismissedIds)..remove(announcementId);

    state = state.copyWith(dismissedIds: newDismissedIds);
    await _saveDismissedIds(newDismissedIds);

    debugPrint('📢 Restored announcement: $announcementId');
  }

  /// Clear all dismissed announcements (for testing/debugging)
  Future<void> clearDismissed() async {
    state = state.copyWith(dismissedIds: {});

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedIdsKey);
    await prefs.remove(_dismissedTimestampsKey);

    debugPrint('📢 Cleared all dismissed announcements');
  }

  /// Clear all read status (for testing/debugging)
  Future<void> clearReadStatus() async {
    state = state.copyWith(readIds: {});

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_readIdsKey);

    debugPrint('📢 Cleared all read status');
  }

  /// Clear all cached data (for testing/debugging)
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedIdsKey);
    await prefs.remove(_dismissedTimestampsKey);
    await prefs.remove(_readIdsKey);
    await prefs.remove(_cachedAnnouncementsKey);
    await AnnouncementsApiService.instance.resetAllDates();

    state = const AnnouncementsState(isLoading: false);
    debugPrint('📢 Cleared all announcement data');
  }

  // ============================================================
  // PERSISTENCE METHODS
  // ============================================================

  /// Load dismissed IDs from SharedPreferences
  Future<Set<String>> _loadDismissedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load IDs and timestamps
      final idsJson = prefs.getString(_dismissedIdsKey);
      final timestampsJson = prefs.getString(_dismissedTimestampsKey);

      if (idsJson == null) return {};

      final ids = (jsonDecode(idsJson) as List).cast<String>().toSet();

      // If we have timestamps, filter out old dismissals
      if (timestampsJson != null) {
        final timestamps = (jsonDecode(timestampsJson) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, DateTime.parse(v as String)));

        final now = DateTime.now();
        final validIds = ids.where((id) {
          final dismissedAt = timestamps[id];
          if (dismissedAt == null) return true; // Keep if no timestamp
          return now.difference(dismissedAt) < _dismissedRetentionPeriod;
        }).toSet();

        // Clean up if we removed some old ones
        if (validIds.length != ids.length) {
          await _saveDismissedIds(validIds);
        }

        return validIds;
      }

      return ids;
    } catch (e) {
      debugPrint('❌ Failed to load dismissed IDs: $e');
      return {};
    }
  }

  /// Save dismissed IDs to SharedPreferences
  Future<void> _saveDismissedIds(Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load existing timestamps
      final timestampsJson = prefs.getString(_dismissedTimestampsKey);
      final timestamps = timestampsJson != null
          ? (jsonDecode(timestampsJson) as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, DateTime.parse(v as String)))
          : <String, DateTime>{};

      // Add timestamps for new IDs
      final now = DateTime.now();
      for (final id in ids) {
        timestamps.putIfAbsent(id, () => now);
      }

      // Remove timestamps for IDs no longer dismissed
      timestamps.removeWhere((id, _) => !ids.contains(id));

      // Save both
      await prefs.setString(_dismissedIdsKey, jsonEncode(ids.toList()));
      await prefs.setString(
        _dismissedTimestampsKey,
        jsonEncode(timestamps.map((k, v) => MapEntry(k, v.toIso8601String()))),
      );
    } catch (e) {
      debugPrint('❌ Failed to save dismissed IDs: $e');
    }
  }

  /// Load read IDs from SharedPreferences
  Future<Set<String>> _loadReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idsJson = prefs.getString(_readIdsKey);

      if (idsJson == null) return {};

      return (jsonDecode(idsJson) as List).cast<String>().toSet();
    } catch (e) {
      debugPrint('❌ Failed to load read IDs: $e');
      return {};
    }
  }

  /// Save read IDs to SharedPreferences
  Future<void> _saveReadIds(Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_readIdsKey, jsonEncode(ids.toList()));
    } catch (e) {
      debugPrint('❌ Failed to save read IDs: $e');
    }
  }

  /// Load cached announcements from SharedPreferences
  Future<List<Announcement>> _loadCachedAnnouncements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cachedAnnouncementsKey);

      if (json == null) return [];

      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((item) => Announcement.fromJson(item as Map<String, dynamic>))
          .where((a) => !a.isExpired) // Filter out expired on load
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to load cached announcements: $e');
      return [];
    }
  }

  /// Save cached announcements to SharedPreferences
  Future<void> _saveCachedAnnouncements(List<Announcement> announcements) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(announcements.map((a) => a.toJson()).toList());
      await prefs.setString(_cachedAnnouncementsKey, json);
    } catch (e) {
      debugPrint('❌ Failed to save cached announcements: $e');
    }
  }
}
