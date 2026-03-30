import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/public_hunt.dart';
import 'package:obsession_tracker/core/services/app_lifecycle_service.dart';
import 'package:obsession_tracker/core/services/public_hunts_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State representing the public hunts
class PublicHuntsState {
  const PublicHuntsState({
    this.hunts = const [],
    this.isLoading = true,
    this.error,
    this.lastFetchTime,
  });

  /// All fetched public hunts
  final List<PublicHunt> hunts;

  /// Whether hunts are still loading
  final bool isLoading;

  /// Error message if loading failed
  final String? error;

  /// Last successful fetch time
  final DateTime? lastFetchTime;

  /// Get featured hunts
  List<PublicHunt> get featuredHunts {
    return hunts.where((h) => h.featured).toList()
      ..sort((a, b) => (a.featuredOrder ?? 999).compareTo(b.featuredOrder ?? 999));
  }

  /// Get active hunts
  List<PublicHunt> get activeHunts {
    return hunts.where((h) => h.status == PublicHuntStatus.active).toList();
  }

  /// Get upcoming hunts
  List<PublicHunt> get upcomingHunts {
    return hunts.where((h) => h.status == PublicHuntStatus.upcoming).toList();
  }

  /// Get found/completed hunts
  List<PublicHunt> get foundHunts {
    return hunts.where((h) => h.status == PublicHuntStatus.found).toList();
  }

  /// Get hunts by type
  List<PublicHunt> getByType(PublicHuntType type) {
    return hunts.where((h) => h.huntType == type).toList();
  }

  /// Whether there are any hunts
  bool get hasHunts => hunts.isNotEmpty;

  /// Count of active hunts
  int get activeCount => activeHunts.length;

  PublicHuntsState copyWith({
    List<PublicHunt>? hunts,
    bool? isLoading,
    String? error,
    DateTime? lastFetchTime,
    bool clearError = false,
  }) {
    return PublicHuntsState(
      hunts: hunts ?? this.hunts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastFetchTime: lastFetchTime ?? this.lastFetchTime,
    );
  }
}

/// Provider for public hunts state
final publicHuntsProvider =
    NotifierProvider<PublicHuntsNotifier, PublicHuntsState>(
        PublicHuntsNotifier.new);

/// Provider for featured hunts only
final featuredHuntsProvider = Provider<List<PublicHunt>>((ref) {
  return ref.watch(publicHuntsProvider).featuredHunts;
});

/// Provider for active hunts only
final activePublicHuntsProvider = Provider<List<PublicHunt>>((ref) {
  return ref.watch(publicHuntsProvider).activeHunts;
});

/// Provider for checking if there are any hunts
final hasPublicHuntsProvider = Provider<bool>((ref) {
  return ref.watch(publicHuntsProvider).hasHunts;
});

/// Provider to get a specific hunt by slug
final publicHuntBySlugProvider =
    FutureProvider.family<PublicHunt?, String>((ref, slug) async {
  // First check if we already have it in the list
  final state = ref.watch(publicHuntsProvider);
  final cachedHunt = state.hunts.cast<PublicHunt?>().firstWhere(
        (h) => h?.slug == slug,
        orElse: () => null,
      );

  if (cachedHunt != null) {
    return cachedHunt;
  }

  // Otherwise fetch from API
  final customEndpoint = await PublicHuntsApiService.instance.getCustomEndpoint();
  final result = await PublicHuntsApiService.instance.fetchHuntBySlug(
    slug,
    customEndpoint: customEndpoint,
  );

  return result.hunt;
});

/// Notifier that manages public hunts state and caching
class PublicHuntsNotifier extends Notifier<PublicHuntsState> {
  static const String _cachedHuntsKey = 'cached_public_hunts';
  static const String _lastFetchTimeKey = 'public_hunts_last_fetch';

  /// Cache duration - refresh after 30 minutes
  static const Duration _cacheValidDuration = Duration(minutes: 30);

  StreamSubscription<AppLifecycleState>? _lifecycleSubscription;

  @override
  PublicHuntsState build() {
    // Subscribe to app lifecycle events for foreground refresh
    _lifecycleSubscription =
        AppLifecycleService().stateChanges.listen(_onLifecycleChange);

    // Clean up subscription when provider is disposed
    ref.onDispose(() {
      _lifecycleSubscription?.cancel();
    });

    _initialize();
    return const PublicHuntsState();
  }

  /// Handle app lifecycle changes - refresh hunts on foreground if stale
  void _onLifecycleChange(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      // Only refresh if cache is stale
      if (_isCacheStale()) {
        debugPrint('🎯 App resumed with stale cache - refreshing public hunts');
        refresh();
      }
    }
  }

  bool _isCacheStale() {
    final lastFetch = state.lastFetchTime;
    if (lastFetch == null) return true;
    return DateTime.now().difference(lastFetch) > _cacheValidDuration;
  }

  Future<void> _initialize() async {
    try {
      // Load cached data first for fast initial load
      final cachedHunts = await _loadCachedHunts();
      final lastFetch = await _loadLastFetchTime();

      state = state.copyWith(
        hunts: cachedHunts,
        lastFetchTime: lastFetch,
        isLoading: cachedHunts.isEmpty,
      );

      debugPrint('🎯 Loaded ${cachedHunts.length} cached public hunts');

      // Fetch fresh data if cache is stale or empty
      if (_isCacheStale() || cachedHunts.isEmpty) {
        await _fetchHunts();
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize public hunts: $e');
      debugPrint('$stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load hunts',
      );
    }
  }

  /// Fetch hunts from the BFF API
  Future<void> _fetchHunts() async {
    try {
      final customEndpoint = await PublicHuntsApiService.instance.getCustomEndpoint();
      final result = await PublicHuntsApiService.instance.fetchHunts(
        customEndpoint: customEndpoint,
      );

      if (result.success) {
        final fetchTime = DateTime.now();

        // Save to cache
        await _saveCachedHunts(result.hunts);
        await _saveLastFetchTime(fetchTime);

        state = state.copyWith(
          hunts: result.hunts,
          lastFetchTime: fetchTime,
          isLoading: false,
          clearError: true,
        );

        debugPrint('🎯 Fetched ${result.hunts.length} public hunts');
      } else {
        debugPrint('⚠️ Fetch failed, using cached hunts');
        state = state.copyWith(
          isLoading: false,
          error: result.error,
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch public hunts: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to refresh hunts',
      );
    }
  }

  /// Refresh hunts from BFF
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _fetchHunts();
  }

  /// Force refresh (ignores cache)
  Future<void> forceRefresh() async {
    state = state.copyWith(isLoading: true);
    await _fetchHunts();
  }

  /// Load hunts - calls refresh or forceRefresh based on forceRefresh parameter
  Future<void> loadHunts({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await this.forceRefresh();
    } else {
      await refresh();
    }
  }

  // ============================================================
  // PERSISTENCE METHODS
  // ============================================================

  Future<List<PublicHunt>> _loadCachedHunts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cachedHuntsKey);

      if (json == null) return [];

      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((item) => PublicHunt.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to load cached public hunts: $e');
      return [];
    }
  }

  Future<void> _saveCachedHunts(List<PublicHunt> hunts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(hunts.map((h) => h.toJson()).toList());
      await prefs.setString(_cachedHuntsKey, json);
    } catch (e) {
      debugPrint('❌ Failed to save cached public hunts: $e');
    }
  }

  Future<DateTime?> _loadLastFetchTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeStr = prefs.getString(_lastFetchTimeKey);
      if (timeStr == null) return null;
      return DateTime.parse(timeStr);
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveLastFetchTime(DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastFetchTimeKey, time.toIso8601String());
    } catch (e) {
      debugPrint('❌ Failed to save last fetch time: $e');
    }
  }

  /// Clear all cached data (for testing/debugging)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedHuntsKey);
      await prefs.remove(_lastFetchTimeKey);
      state = const PublicHuntsState(isLoading: false);
      debugPrint('🎯 Cleared public hunts cache');
    } catch (e) {
      debugPrint('❌ Failed to clear cache: $e');
    }
  }
}
