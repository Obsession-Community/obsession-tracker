// Gamification Service for Milestone 10
// Provides achievement system, statistics tracking, and personal records

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:logger/logger.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/gamification_models.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing gamification features
class GamificationService {
  factory GamificationService() => _instance;

  GamificationService._internal();
  static final GamificationService _instance = GamificationService._internal();

  final Logger _logger = Logger();
  final Map<String, Achievement> _achievements = {};
  final Map<String, UserAchievement> _userAchievements = {};
  final Map<PersonalRecordType, PersonalRecord> _personalRecords = {};
  final StreamController<UserAchievement> _achievementUnlockedController =
      StreamController<UserAchievement>.broadcast();
  final StreamController<PersonalRecord> _recordBrokenController =
      StreamController<PersonalRecord>.broadcast();
  final StreamController<UserStatistics> _statisticsController =
      StreamController<UserStatistics>.broadcast();

  bool _isInitialized = false;
  SharedPreferences? _prefs;
  UserStatistics? _currentStats;
  Timer? _dailyResetTimer;

  /// Stream of newly unlocked achievements
  Stream<UserAchievement> get achievementUnlockedStream =>
      _achievementUnlockedController.stream;

  /// Stream of broken personal records
  Stream<PersonalRecord> get recordBrokenStream =>
      _recordBrokenController.stream;

  /// Stream of updated statistics
  Stream<UserStatistics> get statisticsStream => _statisticsController.stream;

  /// Current user statistics
  UserStatistics? get currentStatistics => _currentStats;

  /// All available achievements
  List<Achievement> get allAchievements => _achievements.values.toList();

  /// User's achievement progress
  List<UserAchievement> get userAchievements =>
      _userAchievements.values.toList();

  /// Personal records
  List<PersonalRecord> get personalRecords => _personalRecords.values.toList();

  /// Initialize the gamification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.i('Initializing Gamification Service');

      _prefs = await SharedPreferences.getInstance();

      // Load achievements and user progress
      await _loadAchievements();
      await _loadUserAchievements();
      await _loadPersonalRecords();
      await _loadUserStatistics();

      // Set up daily reset timer
      _setupDailyResetTimer();

      _isInitialized = true;
      _logger.i('Gamification Service initialized successfully');
    } catch (e, stackTrace) {
      _logger.e('Failed to initialize Gamification Service',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Process a completed tracking session for achievements and records
  Future<void> processSession(
    TrackingSession session,
    List<Breadcrumb> breadcrumbs, {
    List<Waypoint>? waypoints,
    List<PhotoWaypoint>? photos,
  }) async {
    try {
      _logger.d('Processing session for gamification: ${session.id}');

      // Update statistics
      await _updateStatistics(session, breadcrumbs,
          waypoints: waypoints, photos: photos);

      // Check for personal records
      await _checkPersonalRecords(session, breadcrumbs,
          waypoints: waypoints, photos: photos);

      // Check for achievement progress
      await _checkAchievementProgress(session, breadcrumbs,
          waypoints: waypoints, photos: photos);

      // Award experience points
      await _awardExperiencePoints(session, breadcrumbs,
          waypoints: waypoints, photos: photos);
    } catch (e, stackTrace) {
      _logger.e('Failed to process session for gamification',
          error: e, stackTrace: stackTrace);
    }
  }

  /// Get achievements by category
  List<Achievement> getAchievementsByCategory(AchievementCategory category) =>
      _achievements.values
          .where((achievement) => achievement.category == category)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// Get completed achievements
  List<UserAchievement> getCompletedAchievements() => _userAchievements.values
      .where((userAchievement) => userAchievement.isCompleted)
      .toList();

  /// Get achievements in progress
  List<UserAchievement> getAchievementsInProgress() => _userAchievements.values
      .where((userAchievement) =>
          userAchievement.status == AchievementStatus.inProgress)
      .toList();

  /// Get personal record by type
  PersonalRecord? getPersonalRecord(PersonalRecordType type) =>
      _personalRecords[type];

  /// Get leaderboard data (mock implementation)
  Future<List<LeaderboardEntry>> getLeaderboard({
    required String category,
    required String period,
    int limit = 10,
  }) async =>
      // In a real implementation, this would fetch from a server
      // For now, return mock data
      List.generate(
          limit,
          (index) => LeaderboardEntry(
                userId: 'user_$index',
                username: 'User ${index + 1}',
                rank: index + 1,
                value: 1000.0 - (index * 50),
                category: category,
                period: period,
                lastUpdated: DateTime.now(),
              ));

  /// Private methods

  Future<void> _loadAchievements() async {
    try {
      // Load built-in achievements
      _achievements.addAll(_createBuiltInAchievements());

      // Load custom achievements from storage
      final customAchievementsData = _prefs?.getString('custom_achievements');
      if (customAchievementsData != null) {
        final customAchievements =
            jsonDecode(customAchievementsData) as List<dynamic>;
        for (final achievementData in customAchievements) {
          final achievement =
              Achievement.fromJson(achievementData as Map<String, dynamic>);
          _achievements[achievement.id] = achievement;
        }
      }

      _logger.i('Loaded ${_achievements.length} achievements');
    } catch (e) {
      _logger.e('Failed to load achievements', error: e);
    }
  }

  Map<String, Achievement> _createBuiltInAchievements() {
    final achievements = <String, Achievement>{};

    // Distance achievements
    achievements['first_km'] = const Achievement(
      id: 'first_km',
      name: 'First Steps',
      description: 'Complete your first kilometer',
      category: AchievementCategory.distance,
      difficulty: AchievementDifficulty.bronze,
      type: AchievementType.single,
      requirements: AchievementRequirements(totalDistance: 1000),
      rewards: AchievementRewards(points: 100),
      iconPath: 'assets/icons/achievements/first_km.svg',
      isSecret: false,
      sortOrder: 1,
    );

    achievements['marathon_distance'] = const Achievement(
      id: 'marathon_distance',
      name: 'Marathon Walker',
      description: 'Walk or run a marathon distance (42.2km)',
      category: AchievementCategory.distance,
      difficulty: AchievementDifficulty.gold,
      type: AchievementType.single,
      requirements: AchievementRequirements(totalDistance: 42200),
      rewards: AchievementRewards(points: 1000, badges: ['marathon_badge']),
      iconPath: 'assets/icons/achievements/marathon.svg',
      isSecret: false,
      sortOrder: 10,
    );

    // Duration achievements
    achievements['hour_explorer'] = const Achievement(
      id: 'hour_explorer',
      name: 'Hour Explorer',
      description: 'Spend an hour exploring',
      category: AchievementCategory.duration,
      difficulty: AchievementDifficulty.bronze,
      type: AchievementType.single,
      requirements: AchievementRequirements(totalDuration: Duration(hours: 1)),
      rewards: AchievementRewards(points: 150),
      iconPath: 'assets/icons/achievements/hour_explorer.svg',
      isSecret: false,
      sortOrder: 2,
    );

    // Elevation achievements
    achievements['hill_climber'] = const Achievement(
      id: 'hill_climber',
      name: 'Hill Climber',
      description: 'Gain 500m of elevation in a single session',
      category: AchievementCategory.elevation,
      difficulty: AchievementDifficulty.silver,
      type: AchievementType.single,
      requirements: AchievementRequirements(totalElevationGain: 500),
      rewards: AchievementRewards(points: 300),
      iconPath: 'assets/icons/achievements/hill_climber.svg',
      isSecret: false,
      sortOrder: 3,
    );

    // Photography achievements
    achievements['shutterbug'] = const Achievement(
      id: 'shutterbug',
      name: 'Shutterbug',
      description: 'Take 100 photos during your adventures',
      category: AchievementCategory.photography,
      difficulty: AchievementDifficulty.silver,
      type: AchievementType.single,
      requirements: AchievementRequirements(photoCount: 100),
      rewards: AchievementRewards(points: 250),
      iconPath: 'assets/icons/achievements/shutterbug.svg',
      isSecret: false,
      sortOrder: 4,
    );

    // Consistency achievements
    achievements['week_warrior'] = const Achievement(
      id: 'week_warrior',
      name: 'Week Warrior',
      description: 'Track activities for 7 consecutive days',
      category: AchievementCategory.consistency,
      difficulty: AchievementDifficulty.silver,
      type: AchievementType.single,
      requirements: AchievementRequirements(consecutiveDays: 7),
      rewards: AchievementRewards(points: 400),
      iconPath: 'assets/icons/achievements/week_warrior.svg',
      isSecret: false,
      sortOrder: 5,
    );

    // Exploration achievements
    achievements['waypoint_master'] = const Achievement(
      id: 'waypoint_master',
      name: 'Waypoint Master',
      description: 'Create 500 waypoints',
      category: AchievementCategory.exploration,
      difficulty: AchievementDifficulty.gold,
      type: AchievementType.single,
      requirements: AchievementRequirements(waypointCount: 500),
      rewards: AchievementRewards(points: 750),
      iconPath: 'assets/icons/achievements/waypoint_master.svg',
      isSecret: false,
      sortOrder: 6,
    );

    // Speed achievements
    achievements['speed_demon'] = const Achievement(
      id: 'speed_demon',
      name: 'Speed Demon',
      description: 'Reach a top speed of 50 km/h',
      category: AchievementCategory.speed,
      difficulty: AchievementDifficulty.gold,
      type: AchievementType.single,
      requirements: AchievementRequirements(maxSpeed: 13.89), // 50 km/h in m/s
      rewards: AchievementRewards(points: 500),
      iconPath: 'assets/icons/achievements/speed_demon.svg',
      isSecret: false,
      sortOrder: 7,
    );

    return achievements;
  }

  Future<void> _loadUserAchievements() async {
    try {
      final userAchievementsData = _prefs?.getString('user_achievements');
      if (userAchievementsData != null) {
        final userAchievements =
            jsonDecode(userAchievementsData) as Map<String, dynamic>;
        for (final entry in userAchievements.entries) {
          final userAchievement =
              UserAchievement.fromJson(entry.value as Map<String, dynamic>);
          _userAchievements[entry.key] = userAchievement;
        }
      }

      // Initialize achievements that don't have user progress yet
      for (final achievement in _achievements.values) {
        if (!_userAchievements.containsKey(achievement.id)) {
          _userAchievements[achievement.id] = UserAchievement(
            achievementId: achievement.id,
            status: AchievementStatus.available,
            progress: 0.0,
            maxProgress: _getMaxProgress(achievement),
            unlockedAt: null,
            completedAt: null,
            currentStreak: 0,
            bestStreak: 0,
          );
        }
      }

      _logger.i('Loaded ${_userAchievements.length} user achievements');
    } catch (e) {
      _logger.e('Failed to load user achievements', error: e);
    }
  }

  double _getMaxProgress(Achievement achievement) {
    final req = achievement.requirements;
    if (req.totalDistance != null) return req.totalDistance!;
    if (req.totalDuration != null)
      return req.totalDuration!.inMilliseconds.toDouble();
    if (req.totalElevationGain != null) return req.totalElevationGain!;
    if (req.sessionCount != null) return req.sessionCount!.toDouble();
    if (req.waypointCount != null) return req.waypointCount!.toDouble();
    if (req.photoCount != null) return req.photoCount!.toDouble();
    if (req.consecutiveDays != null) return req.consecutiveDays!.toDouble();
    if (req.maxSpeed != null) return req.maxSpeed!;
    return 1.0;
  }

  Future<void> _loadPersonalRecords() async {
    try {
      final personalRecordsData = _prefs?.getString('personal_records');
      if (personalRecordsData != null) {
        final records = jsonDecode(personalRecordsData) as Map<String, dynamic>;
        for (final entry in records.entries) {
          final recordType = PersonalRecordType.values[int.parse(entry.key)];
          final record =
              PersonalRecord.fromJson(entry.value as Map<String, dynamic>);
          _personalRecords[recordType] = record;
        }
      }

      _logger.i('Loaded ${_personalRecords.length} personal records');
    } catch (e) {
      _logger.e('Failed to load personal records', error: e);
    }
  }

  Future<void> _loadUserStatistics() async {
    try {
      final statisticsData = _prefs?.getString('user_statistics');
      if (statisticsData != null) {
        _currentStats = UserStatistics.fromJson(
            jsonDecode(statisticsData) as Map<String, dynamic>);
      } else {
        // Initialize with default statistics
        _currentStats = UserStatistics(
          totalDistance: 0.0,
          totalDuration: Duration.zero,
          totalElevationGain: 0.0,
          totalSessions: 0,
          totalWaypoints: 0,
          totalPhotos: 0,
          currentStreak: 0,
          longestStreak: 0,
          achievementPoints: 0,
          completedAchievements: 0,
          level: 1,
          experiencePoints: 0,
          lastActivityDate: null,
          joinDate: DateTime.now(),
        );
      }

      _logger.i('Loaded user statistics');
    } catch (e) {
      _logger.e('Failed to load user statistics', error: e);
    }
  }

  Future<void> _updateStatistics(
    TrackingSession session,
    List<Breadcrumb> breadcrumbs, {
    List<Waypoint>? waypoints,
    List<PhotoWaypoint>? photos,
  }) async {
    if (_currentStats == null) return;

    try {
      final now = DateTime.now();

      // Update streak
      int newCurrentStreak = _currentStats!.currentStreak;
      if (_currentStats!.lastActivityDate != null) {
        final daysSinceLastActivity =
            now.difference(_currentStats!.lastActivityDate!).inDays;
        if (daysSinceLastActivity == 1) {
          newCurrentStreak++;
        } else if (daysSinceLastActivity > 1) {
          newCurrentStreak = 1;
        }
      } else {
        newCurrentStreak = 1;
      }

      final newLongestStreak =
          math.max(_currentStats!.longestStreak, newCurrentStreak);

      // Calculate elevation gain
      double elevationGain = 0.0;
      for (int i = 1; i < breadcrumbs.length; i++) {
        final prev = breadcrumbs[i - 1];
        final curr = breadcrumbs[i];
        if (prev.altitude != null && curr.altitude != null) {
          final gain = curr.altitude! - prev.altitude!;
          if (gain > 0) elevationGain += gain;
        }
      }

      // Update statistics
      _currentStats = UserStatistics(
        totalDistance: _currentStats!.totalDistance + session.totalDistance,
        totalDuration: _currentStats!.totalDuration + session.duration,
        totalElevationGain: _currentStats!.totalElevationGain + elevationGain,
        totalSessions: _currentStats!.totalSessions + 1,
        totalWaypoints:
            _currentStats!.totalWaypoints + (waypoints?.length ?? 0),
        totalPhotos: _currentStats!.totalPhotos + (photos?.length ?? 0),
        currentStreak: newCurrentStreak,
        longestStreak: newLongestStreak,
        achievementPoints: _currentStats!.achievementPoints,
        completedAchievements: _currentStats!.completedAchievements,
        level: _currentStats!.level,
        experiencePoints: _currentStats!.experiencePoints,
        lastActivityDate: now,
        joinDate: _currentStats!.joinDate,
      );

      await _saveUserStatistics();
      if (_currentStats != null) {
        _statisticsController.add(_currentStats!);
      }
    } catch (e) {
      _logger.e('Failed to update statistics', error: e);
    }
  }

  Future<void> _checkPersonalRecords(
    TrackingSession session,
    List<Breadcrumb> breadcrumbs, {
    List<Waypoint>? waypoints,
    List<PhotoWaypoint>? photos,
  }) async {
    try {
      final records = <PersonalRecord>[];

      // Check distance record
      final currentDistanceRecord =
          _personalRecords[PersonalRecordType.longestDistance];
      if (currentDistanceRecord == null ||
          session.totalDistance > currentDistanceRecord.value) {
        records.add(PersonalRecord(
          id: 'distance_${DateTime.now().millisecondsSinceEpoch}',
          type: PersonalRecordType.longestDistance,
          value: session.totalDistance,
          unit: 'meters',
          achievedAt: DateTime.now(),
          sessionId: session.id,
          description: 'Longest distance in a single session',
          metadata: {'session_name': session.name},
        ));
      }

      // Check duration record
      final currentDurationRecord =
          _personalRecords[PersonalRecordType.longestDuration];
      if (currentDurationRecord == null ||
          session.duration.inMilliseconds > currentDurationRecord.value) {
        records.add(PersonalRecord(
          id: 'duration_${DateTime.now().millisecondsSinceEpoch}',
          type: PersonalRecordType.longestDuration,
          value: session.duration.inMilliseconds.toDouble(),
          unit: 'milliseconds',
          achievedAt: DateTime.now(),
          sessionId: session.id,
          description: 'Longest duration in a single session',
          metadata: {'session_name': session.name},
        ));
      }

      // Check speed record
      if (session.averageSpeed != null) {
        final currentSpeedRecord =
            _personalRecords[PersonalRecordType.fastestSpeed];
        if (currentSpeedRecord == null ||
            session.averageSpeed! > currentSpeedRecord.value) {
          records.add(PersonalRecord(
            id: 'speed_${DateTime.now().millisecondsSinceEpoch}',
            type: PersonalRecordType.fastestSpeed,
            value: session.averageSpeed!,
            unit: 'm/s',
            achievedAt: DateTime.now(),
            sessionId: session.id,
            description: 'Fastest average speed',
            metadata: {'session_name': session.name},
          ));
        }
      }

      // Save and notify about new records
      for (final record in records) {
        _personalRecords[record.type] = record;
        _recordBrokenController.add(record);
      }

      if (records.isNotEmpty) {
        await _savePersonalRecords();
      }
    } catch (e) {
      _logger.e('Failed to check personal records', error: e);
    }
  }

  Future<void> _checkAchievementProgress(
    TrackingSession session,
    List<Breadcrumb> breadcrumbs, {
    List<Waypoint>? waypoints,
    List<PhotoWaypoint>? photos,
  }) async {
    if (_currentStats == null) return;

    try {
      final unlockedAchievements = <UserAchievement>[];

      for (final achievement in _achievements.values) {
        final userAchievement = _userAchievements[achievement.id];
        if (userAchievement == null || userAchievement.isCompleted) continue;

        final newProgress =
            _calculateAchievementProgress(achievement, _currentStats!);
        final maxProgress = _getMaxProgress(achievement);

        if (newProgress != userAchievement.progress) {
          final updatedUserAchievement = userAchievement.copyWith(
            progress: newProgress,
            status: newProgress >= maxProgress
                ? AchievementStatus.completed
                : AchievementStatus.inProgress,
            completedAt: newProgress >= maxProgress ? DateTime.now() : null,
          );

          _userAchievements[achievement.id] = updatedUserAchievement;

          if (updatedUserAchievement.isCompleted &&
              !userAchievement.isCompleted) {
            unlockedAchievements.add(updatedUserAchievement);

            // Award achievement points
            _currentStats = _currentStats!.copyWith(
              achievementPoints:
                  _currentStats!.achievementPoints + achievement.rewards.points,
              completedAchievements: _currentStats!.completedAchievements + 1,
            );
          }
        }
      }

      // Save progress and notify about unlocked achievements
      if (unlockedAchievements.isNotEmpty) {
        await _saveUserAchievements();
        await _saveUserStatistics();

        unlockedAchievements.forEach(_achievementUnlockedController.add);
      }
    } catch (e) {
      _logger.e('Failed to check achievement progress', error: e);
    }
  }

  double _calculateAchievementProgress(
      Achievement achievement, UserStatistics stats) {
    final req = achievement.requirements;

    if (req.totalDistance != null) return stats.totalDistance;
    if (req.totalDuration != null)
      return stats.totalDuration.inMilliseconds.toDouble();
    if (req.totalElevationGain != null) return stats.totalElevationGain;
    if (req.sessionCount != null) return stats.totalSessions.toDouble();
    if (req.waypointCount != null) return stats.totalWaypoints.toDouble();
    if (req.photoCount != null) return stats.totalPhotos.toDouble();
    if (req.consecutiveDays != null) return stats.currentStreak.toDouble();

    return 0.0;
  }

  Future<void> _awardExperiencePoints(
    TrackingSession session,
    List<Breadcrumb> breadcrumbs, {
    List<Waypoint>? waypoints,
    List<PhotoWaypoint>? photos,
  }) async {
    if (_currentStats == null) return;

    try {
      // Calculate experience points based on session
      int xpGained = 0;

      // Base XP for completing a session
      xpGained += 50;

      // Distance bonus (1 XP per 100m)
      xpGained += (session.totalDistance / 100).round();

      // Duration bonus (1 XP per minute)
      xpGained += session.duration.inMinutes;

      // Waypoint bonus (5 XP per waypoint)
      xpGained += (waypoints?.length ?? 0) * 5;

      // Photo bonus (2 XP per photo)
      xpGained += (photos?.length ?? 0) * 2;

      final newXP = _currentStats!.experiencePoints + xpGained;
      final newLevel = (newXP / 1000).floor() + 1;

      _currentStats = _currentStats!.copyWith(
        experiencePoints: newXP,
        level: newLevel,
      );

      await _saveUserStatistics();
    } catch (e) {
      _logger.e('Failed to award experience points', error: e);
    }
  }

  void _setupDailyResetTimer() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = tomorrow.difference(now);

    _dailyResetTimer = Timer(timeUntilMidnight, () {
      _performDailyReset();
      // Set up recurring daily timer
      _dailyResetTimer = Timer.periodic(const Duration(days: 1), (_) {
        _performDailyReset();
      });
    });
  }

  void _performDailyReset() {
    try {
      _logger.d('Performing daily reset');
      // Reset daily challenges, streaks, etc.
      // Implementation would depend on specific daily features
    } catch (e) {
      _logger.e('Failed to perform daily reset', error: e);
    }
  }

  Future<void> _saveUserAchievements() async {
    try {
      final achievementsMap = <String, Map<String, dynamic>>{};
      for (final entry in _userAchievements.entries) {
        achievementsMap[entry.key] = entry.value.toJson();
      }
      await _prefs?.setString('user_achievements', jsonEncode(achievementsMap));
    } catch (e) {
      _logger.e('Failed to save user achievements', error: e);
    }
  }

  Future<void> _savePersonalRecords() async {
    try {
      final recordsMap = <String, Map<String, dynamic>>{};
      for (final entry in _personalRecords.entries) {
        recordsMap[entry.key.index.toString()] = entry.value.toJson();
      }
      await _prefs?.setString('personal_records', jsonEncode(recordsMap));
    } catch (e) {
      _logger.e('Failed to save personal records', error: e);
    }
  }

  Future<void> _saveUserStatistics() async {
    try {
      if (_currentStats != null) {
        await _prefs?.setString(
            'user_statistics', jsonEncode(_currentStats!.toJson()));
      }
    } catch (e) {
      _logger.e('Failed to save user statistics', error: e);
    }
  }

  /// Dispose of the service
  Future<void> dispose() async {
    try {
      _dailyResetTimer?.cancel();

      await _achievementUnlockedController.close();
      await _recordBrokenController.close();
      await _statisticsController.close();

      _isInitialized = false;
      _logger.i('Gamification Service disposed');
    } catch (e, stackTrace) {
      _logger.e('Failed to dispose Gamification Service',
          error: e, stackTrace: stackTrace);
    }
  }
}

/// Extension to add copyWith method to UserStatistics
extension UserStatisticsCopyWith on UserStatistics {
  UserStatistics copyWith({
    double? totalDistance,
    Duration? totalDuration,
    double? totalElevationGain,
    int? totalSessions,
    int? totalWaypoints,
    int? totalPhotos,
    int? currentStreak,
    int? longestStreak,
    int? achievementPoints,
    int? completedAchievements,
    int? level,
    int? experiencePoints,
    DateTime? lastActivityDate,
    DateTime? joinDate,
  }) =>
      UserStatistics(
        totalDistance: totalDistance ?? this.totalDistance,
        totalDuration: totalDuration ?? this.totalDuration,
        totalElevationGain: totalElevationGain ?? this.totalElevationGain,
        totalSessions: totalSessions ?? this.totalSessions,
        totalWaypoints: totalWaypoints ?? this.totalWaypoints,
        totalPhotos: totalPhotos ?? this.totalPhotos,
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        achievementPoints: achievementPoints ?? this.achievementPoints,
        completedAchievements:
            completedAchievements ?? this.completedAchievements,
        level: level ?? this.level,
        experiencePoints: experiencePoints ?? this.experiencePoints,
        lastActivityDate: lastActivityDate ?? this.lastActivityDate,
        joinDate: joinDate ?? this.joinDate,
      );
}
