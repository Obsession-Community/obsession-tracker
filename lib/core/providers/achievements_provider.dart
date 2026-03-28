import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/services/achievement_service.dart';
import 'package:obsession_tracker/core/services/lifetime_statistics_service.dart';

// ============================================================
// Lifetime Statistics Providers
// ============================================================

/// Notifier for lifetime statistics
class LifetimeStatsNotifier extends Notifier<AsyncValue<LifetimeStats>> {
  late final LifetimeStatisticsService _statsService;

  @override
  AsyncValue<LifetimeStats> build() {
    _statsService = LifetimeStatisticsService();
    loadStats();
    return const AsyncValue.loading();
  }

  /// Load lifetime statistics
  Future<void> loadStats() async {
    try {
      debugPrint('LifetimeStatsNotifier: Loading statistics...');
      state = const AsyncValue.loading();
      await _statsService.initialize();
      final stats = await _statsService.getStatistics();
      debugPrint('LifetimeStatsNotifier: Loaded stats - ${stats.totalSessions} sessions');
      state = AsyncValue.data(stats);
    } catch (error, stackTrace) {
      debugPrint('LifetimeStatsNotifier: Error loading stats: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Refresh statistics
  Future<void> refresh() async {
    await loadStats();
  }

  /// Recalculate all statistics from existing sessions
  Future<void> recalculate() async {
    try {
      state = const AsyncValue.loading();
      await _statsService.recalculateFromAllSessions();
      final stats = await _statsService.getStatistics();
      state = AsyncValue.data(stats);
    } catch (error, stackTrace) {
      debugPrint('LifetimeStatsNotifier: Error recalculating: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Increment hunts created count
  Future<void> incrementHuntsCreated() async {
    try {
      await _statsService.incrementHuntsCreated();
      await loadStats();
    } catch (error) {
      debugPrint('LifetimeStatsNotifier: Error incrementing hunts: $error');
    }
  }

  /// Increment hunts solved count
  Future<void> incrementHuntsSolved() async {
    try {
      await _statsService.incrementHuntsSolved();
      await loadStats();
    } catch (error) {
      debugPrint('LifetimeStatsNotifier: Error incrementing solved: $error');
    }
  }
}

/// Provider for lifetime statistics
final lifetimeStatsProvider =
    NotifierProvider<LifetimeStatsNotifier, AsyncValue<LifetimeStats>>(
  LifetimeStatsNotifier.new,
);

/// Stream provider for stats updates (real-time)
final lifetimeStatsStreamProvider = StreamProvider<LifetimeStats>((ref) {
  final service = LifetimeStatisticsService();
  return service.statsStream;
});

// ============================================================
// Achievement Providers
// ============================================================

/// Notifier for user achievements
class AchievementNotifier
    extends Notifier<AsyncValue<List<UserAchievementProgress>>> {
  late final AchievementService _achievementService;

  @override
  AsyncValue<List<UserAchievementProgress>> build() {
    _achievementService = AchievementService();
    loadAchievements();
    return const AsyncValue.loading();
  }

  /// Load all user achievements
  Future<void> loadAchievements() async {
    try {
      debugPrint('AchievementNotifier: Loading achievements...');
      state = const AsyncValue.loading();
      await _achievementService.initialize();
      final achievements = await _achievementService.getUserAchievements();
      debugPrint('AchievementNotifier: Loaded ${achievements.length} achievements');
      state = AsyncValue.data(achievements);
    } catch (error, stackTrace) {
      debugPrint('AchievementNotifier: Error loading achievements: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Check achievements and refresh list
  Future<List<AchievementUnlockedEvent>> checkAndRefresh() async {
    try {
      final unlocked = await _achievementService.checkAllAchievements();
      await loadAchievements();
      return unlocked;
    } catch (error) {
      debugPrint('AchievementNotifier: Error checking achievements: $error');
      return [];
    }
  }

  /// Refresh achievements
  Future<void> refresh() async {
    await loadAchievements();
  }

  /// Get achievement definitions
  List<AchievementDefinition> getDefinitions() {
    return _achievementService.getDefinitions();
  }

  /// Get total achievement count
  int getTotalCount() {
    return _achievementService.getTotalCount();
  }
}

/// Provider for user achievements
final achievementProvider = NotifierProvider<AchievementNotifier,
    AsyncValue<List<UserAchievementProgress>>>(
  AchievementNotifier.new,
);

/// Stream provider for achievement unlock events
final achievementUnlockStreamProvider =
    StreamProvider<AchievementUnlockedEvent>((ref) {
  final service = AchievementService();
  return service.unlockStream;
});

/// Provider for completed achievement count
final completedAchievementCountProvider = FutureProvider<int>((ref) async {
  final service = AchievementService();
  await service.initialize();
  return service.getCompletedCount();
});

/// Provider for total achievement count
final totalAchievementCountProvider = Provider<int>((ref) {
  final service = AchievementService();
  return service.getTotalCount();
});

/// Provider for achievements by category
final achievementsByCategoryProvider =
    FutureProvider.family<List<UserAchievementProgress>, String>(
        (ref, category) async {
  final service = AchievementService();
  await service.initialize();
  return service.getAchievementsByCategory(category);
});

// ============================================================
// Explored States Providers
// ============================================================

/// Notifier for explored states
class ExploredStatesNotifier
    extends Notifier<AsyncValue<List<ExploredState>>> {
  late final LifetimeStatisticsService _statsService;

  @override
  AsyncValue<List<ExploredState>> build() {
    _statsService = LifetimeStatisticsService();
    loadStates();
    return const AsyncValue.loading();
  }

  /// Load explored states
  Future<void> loadStates() async {
    try {
      debugPrint('ExploredStatesNotifier: Loading explored states...');
      state = const AsyncValue.loading();
      await _statsService.initialize();
      final states = await _statsService.getExploredStates();
      debugPrint('ExploredStatesNotifier: Loaded ${states.length} states');
      state = AsyncValue.data(states);
    } catch (error, stackTrace) {
      debugPrint('ExploredStatesNotifier: Error loading states: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Refresh states
  Future<void> refresh() async {
    await loadStates();
  }
}

/// Provider for explored states
final exploredStatesProvider =
    NotifierProvider<ExploredStatesNotifier, AsyncValue<List<ExploredState>>>(
  ExploredStatesNotifier.new,
);

/// Provider for explored state by code
final exploredStateByCodeProvider =
    FutureProvider.family<ExploredState?, String>((ref, stateCode) async {
  final service = LifetimeStatisticsService();
  await service.initialize();
  return service.getExploredState(stateCode);
});

/// Provider for explored states count
final exploredStatesCountProvider = Provider<int>((ref) {
  final statesAsync = ref.watch(exploredStatesProvider);
  return statesAsync.maybeWhen(
    data: (states) => states.length,
    orElse: () => 0,
  );
});

// ============================================================
// Derived/Convenience Providers
// ============================================================

/// Provider for achievement progress summary
final achievementProgressProvider = Provider<({int completed, int total})>((ref) {
  final achievementsAsync = ref.watch(achievementProvider);
  return achievementsAsync.maybeWhen(
    data: (achievements) {
      final completed = achievements.where((a) => a.isCompleted).length;
      return (completed: completed, total: achievements.length);
    },
    orElse: () => (completed: 0, total: 0),
  );
});

/// Provider for recent achievements (completed, sorted by date)
final recentAchievementsProvider =
    Provider<List<UserAchievementProgress>>((ref) {
  final achievementsAsync = ref.watch(achievementProvider);
  return achievementsAsync.maybeWhen(
    data: (achievements) {
      final completed =
          achievements.where((a) => a.isCompleted && a.completedAt != null).toList();
      completed.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
      return completed.take(5).toList();
    },
    orElse: () => [],
  );
});

/// Provider for in-progress achievements
final inProgressAchievementsProvider =
    Provider<List<UserAchievementProgress>>((ref) {
  final achievementsAsync = ref.watch(achievementProvider);
  return achievementsAsync.maybeWhen(
    data: (achievements) {
      final inProgress = achievements.where((a) => a.isInProgress).toList();
      // Sort by progress percentage (closest to completion first)
      inProgress.sort((a, b) =>
          b.progressPercentage.compareTo(a.progressPercentage));
      return inProgress;
    },
    orElse: () => [],
  );
});

/// Provider for formatted total distance
final totalDistanceFormattedProvider = Provider<String>((ref) {
  final statsAsync = ref.watch(lifetimeStatsProvider);
  return statsAsync.maybeWhen(
    data: (stats) => '${stats.totalDistanceMiles.toStringAsFixed(1)} mi',
    orElse: () => '0.0 mi',
  );
});

/// Provider for formatted total time
final totalTimeFormattedProvider = Provider<String>((ref) {
  final statsAsync = ref.watch(lifetimeStatsProvider);
  return statsAsync.maybeWhen(
    data: (stats) => stats.formattedTotalTime,
    orElse: () => '0m',
  );
});

/// Provider for current streak
final currentStreakProvider = Provider<int>((ref) {
  final statsAsync = ref.watch(lifetimeStatsProvider);
  return statsAsync.maybeWhen(
    data: (stats) => stats.currentStreak,
    orElse: () => 0,
  );
});

/// Provider for session count
final totalSessionsProvider = Provider<int>((ref) {
  final statsAsync = ref.watch(lifetimeStatsProvider);
  return statsAsync.maybeWhen(
    data: (stats) => stats.totalSessions,
    orElse: () => 0,
  );
});
