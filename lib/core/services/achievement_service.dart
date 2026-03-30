import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/lifetime_statistics_service.dart';

/// Achievement definition model
class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.category,
    required this.difficulty,
    required this.name,
    required this.description,
    required this.iconName,
    required this.requirementType,
    required this.requirementValue,
    required this.sortOrder,
  });

  factory AchievementDefinition.fromMap(Map<String, dynamic> map) {
    return AchievementDefinition(
      id: map['id'] as String,
      category: map['category'] as String,
      difficulty: map['difficulty'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      iconName: map['icon_name'] as String,
      requirementType: map['requirement_type'] as String,
      requirementValue: (map['requirement_value'] as num).toDouble(),
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  final String id;
  final String category; // milestone, distance, explorer, dedication, memory, hunter
  final String difficulty; // bronze, silver, gold, platinum
  final String name;
  final String description;
  final String iconName;
  final String requirementType; // session_count, distance, states, streak, photos, voice_notes, hunts, hunts_solved
  final double requirementValue;
  final int sortOrder;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'difficulty': difficulty,
      'name': name,
      'description': description,
      'icon_name': iconName,
      'requirement_type': requirementType,
      'requirement_value': requirementValue,
      'sort_order': sortOrder,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

/// User's progress on an achievement
class UserAchievementProgress {
  const UserAchievementProgress({
    required this.id,
    required this.achievementId,
    required this.status,
    required this.currentProgress,
    this.unlockedAt,
    this.completedAt,
    this.achievement,
  });

  factory UserAchievementProgress.fromMap(Map<String, dynamic> map) {
    AchievementDefinition? achievement;
    // If joined with achievement table, parse it
    if (map.containsKey('name') && map.containsKey('category')) {
      achievement = AchievementDefinition(
        id: map['achievement_id'] as String,
        category: map['category'] as String,
        difficulty: map['difficulty'] as String,
        name: map['name'] as String,
        description: map['description'] as String,
        iconName: map['icon_name'] as String,
        requirementType: map['requirement_type'] as String,
        requirementValue: (map['requirement_value'] as num).toDouble(),
        sortOrder: 0,
      );
    }

    return UserAchievementProgress(
      id: map['id'] as String,
      achievementId: map['achievement_id'] as String,
      status: map['status'] as String,
      currentProgress: (map['current_progress'] as num).toDouble(),
      unlockedAt: map['unlocked_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['unlocked_at'] as int)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
          : null,
      achievement: achievement,
    );
  }

  final String id;
  final String achievementId;
  final String status; // locked, in_progress, completed
  final double currentProgress;
  final DateTime? unlockedAt;
  final DateTime? completedAt;
  final AchievementDefinition? achievement;

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get isLocked => status == 'locked';

  double get progressPercentage {
    if (achievement == null) return 0;
    if (achievement!.requirementValue == 0) return 0;
    return (currentProgress / achievement!.requirementValue).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'achievement_id': achievementId,
      'status': status,
      'current_progress': currentProgress,
      'unlocked_at': unlockedAt?.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
    };
  }

  UserAchievementProgress copyWith({
    String? id,
    String? achievementId,
    String? status,
    double? currentProgress,
    DateTime? unlockedAt,
    DateTime? completedAt,
    AchievementDefinition? achievement,
  }) {
    return UserAchievementProgress(
      id: id ?? this.id,
      achievementId: achievementId ?? this.achievementId,
      status: status ?? this.status,
      currentProgress: currentProgress ?? this.currentProgress,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      completedAt: completedAt ?? this.completedAt,
      achievement: achievement ?? this.achievement,
    );
  }
}

/// Event emitted when an achievement is unlocked
class AchievementUnlockedEvent {
  const AchievementUnlockedEvent({
    required this.achievement,
    required this.unlockedAt,
  });

  final AchievementDefinition achievement;
  final DateTime unlockedAt;
}

/// Service for managing achievements
///
/// Tracks achievement progress, unlocks achievements when requirements are met,
/// and emits events for UI notifications.
class AchievementService {
  factory AchievementService() => _instance;
  AchievementService._internal();
  static final AchievementService _instance = AchievementService._internal();

  final DatabaseService _db = DatabaseService();
  final LifetimeStatisticsService _stats = LifetimeStatisticsService();

  bool _isInitialized = false;
  List<AchievementDefinition>? _cachedDefinitions;

  /// Lock to prevent concurrent checkAllAchievements calls
  /// which can cause duplicate unlock events due to race conditions
  Future<List<AchievementUnlockedEvent>>? _checkInProgress;

  /// Set of achievement IDs that have been unlocked this session
  /// to prevent duplicate notifications
  final Set<String> _unlockedThisSession = {};

  // Stream for achievement unlock notifications
  final _unlockController = StreamController<AchievementUnlockedEvent>.broadcast();
  Stream<AchievementUnlockedEvent> get unlockStream => _unlockController.stream;

  /// Initialize the service and seed achievement definitions
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Pass skipAchievementCheck to prevent circular dependency:
    // AchievementService.initialize() -> _stats.initialize() -> migration
    // -> checkAllAchievements() -> DEADLOCK (we're already in checkAllAchievements)
    await _stats.initialize(skipAchievementCheck: true);
    await _seedAchievements();
    _isInitialized = true;
    debugPrint('AchievementService initialized');
  }

  /// Seed achievement definitions into the database
  Future<void> _seedAchievements() async {
    final existing = await _db.getAchievements();
    if (existing.isNotEmpty) {
      _cachedDefinitions = existing.map(AchievementDefinition.fromMap).toList();
      debugPrint('Loaded ${_cachedDefinitions!.length} existing achievements');
      return;
    }

    // Seed all achievement definitions
    final definitions = _getAchievementDefinitions();
    for (final def in definitions) {
      await _db.insertAchievement(def.toMap());
    }
    _cachedDefinitions = definitions;
    debugPrint('Seeded ${definitions.length} achievement definitions');
  }

  /// Get all achievement definitions
  List<AchievementDefinition> _getAchievementDefinitions() {
    return [
      // ============ Milestone Achievements ============
      const AchievementDefinition(
        id: 'first_session',
        category: 'milestone',
        difficulty: 'bronze',
        name: 'First Steps',
        description: 'Complete your first adventure',
        iconName: 'hiking',
        requirementType: 'session_count',
        requirementValue: 1,
        sortOrder: 100,
      ),
      const AchievementDefinition(
        id: 'sessions_10',
        category: 'milestone',
        difficulty: 'bronze',
        name: 'Getting Started',
        description: 'Complete 10 adventures',
        iconName: 'explore',
        requirementType: 'session_count',
        requirementValue: 10,
        sortOrder: 101,
      ),
      const AchievementDefinition(
        id: 'sessions_25',
        category: 'milestone',
        difficulty: 'silver',
        name: 'Regular Explorer',
        description: 'Complete 25 adventures',
        iconName: 'map',
        requirementType: 'session_count',
        requirementValue: 25,
        sortOrder: 102,
      ),
      const AchievementDefinition(
        id: 'sessions_50',
        category: 'milestone',
        difficulty: 'silver',
        name: 'Dedicated Hunter',
        description: 'Complete 50 adventures',
        iconName: 'terrain',
        requirementType: 'session_count',
        requirementValue: 50,
        sortOrder: 103,
      ),
      const AchievementDefinition(
        id: 'sessions_100',
        category: 'milestone',
        difficulty: 'gold',
        name: 'Century Club',
        description: 'Complete 100 adventures',
        iconName: 'stars',
        requirementType: 'session_count',
        requirementValue: 100,
        sortOrder: 104,
      ),
      const AchievementDefinition(
        id: 'sessions_500',
        category: 'milestone',
        difficulty: 'platinum',
        name: 'Veteran Explorer',
        description: 'Complete 500 adventures',
        iconName: 'military_tech',
        requirementType: 'session_count',
        requirementValue: 500,
        sortOrder: 105,
      ),

      // ============ Distance Achievements ============
      const AchievementDefinition(
        id: 'distance_10mi',
        category: 'distance',
        difficulty: 'bronze',
        name: 'First Ten',
        description: 'Track 10 miles total',
        iconName: 'directions_walk',
        requirementType: 'distance',
        requirementValue: 16093, // 10 miles in meters
        sortOrder: 200,
      ),
      const AchievementDefinition(
        id: 'distance_50mi',
        category: 'distance',
        difficulty: 'silver',
        name: 'Long Haul',
        description: 'Track 50 miles total',
        iconName: 'directions_run',
        requirementType: 'distance',
        requirementValue: 80467, // 50 miles
        sortOrder: 201,
      ),
      const AchievementDefinition(
        id: 'distance_100mi',
        category: 'distance',
        difficulty: 'silver',
        name: 'Century Miles',
        description: 'Track 100 miles total',
        iconName: 'route',
        requirementType: 'distance',
        requirementValue: 160934, // 100 miles
        sortOrder: 202,
      ),
      const AchievementDefinition(
        id: 'distance_500mi',
        category: 'distance',
        difficulty: 'gold',
        name: 'Cross-Country',
        description: 'Track 500 miles total',
        iconName: 'flight',
        requirementType: 'distance',
        requirementValue: 804672, // 500 miles
        sortOrder: 203,
      ),
      const AchievementDefinition(
        id: 'distance_1000mi',
        category: 'distance',
        difficulty: 'platinum',
        name: 'Thousand Miler',
        description: 'Track 1,000 miles total',
        iconName: 'public',
        requirementType: 'distance',
        requirementValue: 1609344, // 1000 miles
        sortOrder: 204,
      ),

      // ============ Explorer (States) Achievements ============
      const AchievementDefinition(
        id: 'states_1',
        category: 'explorer',
        difficulty: 'bronze',
        name: 'Home State',
        description: 'Explore your first state',
        iconName: 'place',
        requirementType: 'states',
        requirementValue: 1,
        sortOrder: 300,
      ),
      const AchievementDefinition(
        id: 'states_5',
        category: 'explorer',
        difficulty: 'silver',
        name: 'Regional Explorer',
        description: 'Explore 5 different states',
        iconName: 'travel_explore',
        requirementType: 'states',
        requirementValue: 5,
        sortOrder: 301,
      ),
      const AchievementDefinition(
        id: 'states_10',
        category: 'explorer',
        difficulty: 'gold',
        name: 'Multi-State Hunter',
        description: 'Explore 10 different states',
        iconName: 'flag',
        requirementType: 'states',
        requirementValue: 10,
        sortOrder: 302,
      ),
      const AchievementDefinition(
        id: 'states_25',
        category: 'explorer',
        difficulty: 'gold',
        name: 'Half the Nation',
        description: 'Explore 25 different states',
        iconName: 'language',
        requirementType: 'states',
        requirementValue: 25,
        sortOrder: 303,
      ),
      const AchievementDefinition(
        id: 'states_50',
        category: 'explorer',
        difficulty: 'platinum',
        name: 'All 50 States',
        description: 'Explore all 50 US states',
        iconName: 'emoji_events',
        requirementType: 'states',
        requirementValue: 50,
        sortOrder: 304,
      ),

      // ============ Dedication (Streaks) Achievements ============
      const AchievementDefinition(
        id: 'streak_3',
        category: 'dedication',
        difficulty: 'bronze',
        name: 'Getting Consistent',
        description: 'Achieve a 3-day session streak',
        iconName: 'local_fire_department',
        requirementType: 'streak',
        requirementValue: 3,
        sortOrder: 400,
      ),
      const AchievementDefinition(
        id: 'streak_7',
        category: 'dedication',
        difficulty: 'silver',
        name: 'Week Warrior',
        description: 'Achieve a 7-day session streak',
        iconName: 'whatshot',
        requirementType: 'streak',
        requirementValue: 7,
        sortOrder: 401,
      ),
      const AchievementDefinition(
        id: 'streak_14',
        category: 'dedication',
        difficulty: 'silver',
        name: 'Two Week Dedication',
        description: 'Achieve a 14-day session streak',
        iconName: 'bolt',
        requirementType: 'streak',
        requirementValue: 14,
        sortOrder: 402,
      ),
      const AchievementDefinition(
        id: 'streak_30',
        category: 'dedication',
        difficulty: 'gold',
        name: 'Monthly Commitment',
        description: 'Achieve a 30-day session streak',
        iconName: 'auto_awesome',
        requirementType: 'streak',
        requirementValue: 30,
        sortOrder: 403,
      ),
      const AchievementDefinition(
        id: 'streak_100',
        category: 'dedication',
        difficulty: 'platinum',
        name: 'Ultimate Dedication',
        description: 'Achieve a 100-day session streak',
        iconName: 'diamond',
        requirementType: 'streak',
        requirementValue: 100,
        sortOrder: 404,
      ),

      // ============ Memory (Photos/Voice) Achievements ============
      const AchievementDefinition(
        id: 'photos_10',
        category: 'memory',
        difficulty: 'bronze',
        name: 'Shutterbug',
        description: 'Take 10 photos',
        iconName: 'camera_alt',
        requirementType: 'photos',
        requirementValue: 10,
        sortOrder: 500,
      ),
      const AchievementDefinition(
        id: 'photos_50',
        category: 'memory',
        difficulty: 'silver',
        name: 'Photo Collector',
        description: 'Take 50 photos',
        iconName: 'photo_library',
        requirementType: 'photos',
        requirementValue: 50,
        sortOrder: 501,
      ),
      const AchievementDefinition(
        id: 'photos_100',
        category: 'memory',
        difficulty: 'silver',
        name: 'Photographer',
        description: 'Take 100 photos',
        iconName: 'photo_camera',
        requirementType: 'photos',
        requirementValue: 100,
        sortOrder: 502,
      ),
      const AchievementDefinition(
        id: 'photos_500',
        category: 'memory',
        difficulty: 'gold',
        name: 'Photo Master',
        description: 'Take 500 photos',
        iconName: 'collections',
        requirementType: 'photos',
        requirementValue: 500,
        sortOrder: 503,
      ),
      const AchievementDefinition(
        id: 'voice_10',
        category: 'memory',
        difficulty: 'bronze',
        name: 'Voice Logger',
        description: 'Record 10 voice notes',
        iconName: 'mic',
        requirementType: 'voice_notes',
        requirementValue: 10,
        sortOrder: 510,
      ),
      const AchievementDefinition(
        id: 'voice_50',
        category: 'memory',
        difficulty: 'silver',
        name: 'Audio Chronicler',
        description: 'Record 50 voice notes',
        iconName: 'record_voice_over',
        requirementType: 'voice_notes',
        requirementValue: 50,
        sortOrder: 511,
      ),

      // ============ Hunter (Hunts) Achievements ============
      const AchievementDefinition(
        id: 'hunt_first',
        category: 'hunter',
        difficulty: 'bronze',
        name: 'First Hunt',
        description: 'Create your first hunt',
        iconName: 'search',
        requirementType: 'hunts',
        requirementValue: 1,
        sortOrder: 600,
      ),
      const AchievementDefinition(
        id: 'hunt_5',
        category: 'hunter',
        difficulty: 'silver',
        name: 'Active Hunter',
        description: 'Create 5 hunts',
        iconName: 'manage_search',
        requirementType: 'hunts',
        requirementValue: 5,
        sortOrder: 601,
      ),
      const AchievementDefinition(
        id: 'hunt_solved',
        category: 'hunter',
        difficulty: 'gold',
        name: 'Treasure Found',
        description: 'Solve your first hunt',
        iconName: 'workspace_premium',
        requirementType: 'hunts_solved',
        requirementValue: 1,
        sortOrder: 610,
      ),
      const AchievementDefinition(
        id: 'hunt_solved_5',
        category: 'hunter',
        difficulty: 'platinum',
        name: 'Serial Solver',
        description: 'Solve 5 hunts',
        iconName: 'emoji_events',
        requirementType: 'hunts_solved',
        requirementValue: 5,
        sortOrder: 611,
      ),
    ];
  }

  /// Check all achievements against current stats and update progress
  ///
  /// Uses a lock to prevent concurrent calls from causing duplicate unlock events.
  /// If a check is already in progress, waits for it to complete and returns its result.
  Future<List<AchievementUnlockedEvent>> checkAllAchievements() async {
    // If a check is already in progress, wait for it instead of starting a new one
    if (_checkInProgress != null) {
      debugPrint('AchievementService: checkAllAchievements already in progress, waiting...');
      return _checkInProgress!;
    }

    // Start new check and store the future
    _checkInProgress = _doCheckAllAchievements();
    try {
      return await _checkInProgress!;
    } finally {
      _checkInProgress = null;
    }
  }

  /// Internal implementation of checkAllAchievements
  Future<List<AchievementUnlockedEvent>> _doCheckAllAchievements() async {
    await initialize();

    final stats = await _stats.getStatistics();
    final definitions = _cachedDefinitions ?? [];
    final unlocked = <AchievementUnlockedEvent>[];

    for (final def in definitions) {
      final currentValue = _getCurrentValueForType(def.requirementType, stats);
      final result = await _updateAchievementProgress(def, currentValue);
      if (result != null) {
        unlocked.add(result);
      }
    }

    return unlocked;
  }

  /// Get current value for a requirement type from stats
  double _getCurrentValueForType(String requirementType, LifetimeStats stats) {
    switch (requirementType) {
      case 'session_count':
        return stats.totalSessions.toDouble();
      case 'distance':
        return stats.totalDistance;
      case 'states':
        return stats.statesExplored.toDouble();
      case 'streak':
        return stats.longestStreak.toDouble();
      case 'photos':
        return stats.totalPhotos.toDouble();
      case 'voice_notes':
        return stats.totalVoiceNotes.toDouble();
      case 'hunts':
        return stats.totalHuntsCreated.toDouble();
      case 'hunts_solved':
        return stats.totalHuntsSolved.toDouble();
      default:
        return 0;
    }
  }

  /// Update achievement progress and return unlock event if newly completed
  Future<AchievementUnlockedEvent?> _updateAchievementProgress(
    AchievementDefinition def,
    double currentValue,
  ) async {
    // Skip if we've already notified about this achievement this session
    if (_unlockedThisSession.contains(def.id)) {
      return null;
    }

    final existing = await _db.getUserAchievement(def.id);
    final now = DateTime.now();

    if (existing == null) {
      // Create new progress entry
      final status = currentValue >= def.requirementValue ? 'completed' : 'in_progress';
      await _db.upsertUserAchievement({
        'id': 'ua_${def.id}',
        'achievement_id': def.id,
        'status': status,
        'current_progress': currentValue,
        'unlocked_at': now.millisecondsSinceEpoch,
        'completed_at': status == 'completed' ? now.millisecondsSinceEpoch : null,
      });

      if (status == 'completed') {
        _unlockedThisSession.add(def.id);
        final event = AchievementUnlockedEvent(
          achievement: def,
          unlockedAt: now,
        );
        _unlockController.add(event);
        return event;
      }
    } else {
      final progress = UserAchievementProgress.fromMap(existing);

      // Skip if already completed
      if (progress.isCompleted) return null;

      // Check if now completed
      if (currentValue >= def.requirementValue) {
        await _db.upsertUserAchievement({
          'id': progress.id,
          'achievement_id': def.id,
          'status': 'completed',
          'current_progress': currentValue,
          'unlocked_at': progress.unlockedAt?.millisecondsSinceEpoch ?? now.millisecondsSinceEpoch,
          'completed_at': now.millisecondsSinceEpoch,
        });

        _unlockedThisSession.add(def.id);
        final event = AchievementUnlockedEvent(
          achievement: def,
          unlockedAt: now,
        );
        _unlockController.add(event);
        return event;
      } else if (currentValue > progress.currentProgress) {
        // Update progress
        await _db.upsertUserAchievement({
          'id': progress.id,
          'achievement_id': def.id,
          'status': 'in_progress',
          'current_progress': currentValue,
          'unlocked_at': progress.unlockedAt?.millisecondsSinceEpoch ?? now.millisecondsSinceEpoch,
          'completed_at': null,
        });
      }
    }

    return null;
  }

  /// Get all user achievements with definitions
  Future<List<UserAchievementProgress>> getUserAchievements() async {
    await initialize();

    final results = await _db.getUserAchievements();
    return results.map(UserAchievementProgress.fromMap).toList();
  }

  /// Get achievements by category
  Future<List<UserAchievementProgress>> getAchievementsByCategory(String category) async {
    final all = await getUserAchievements();
    return all.where((a) => a.achievement?.category == category).toList();
  }

  /// Get completed achievement count
  Future<int> getCompletedCount() {
    return _db.getCompletedAchievementCount();
  }

  /// Get total achievement count
  int getTotalCount() {
    return _cachedDefinitions?.length ?? 0;
  }

  /// Get all achievement definitions
  List<AchievementDefinition> getDefinitions() {
    return _cachedDefinitions ?? [];
  }

  /// Dispose resources
  void dispose() {
    _unlockController.close();
  }
}
