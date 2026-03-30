import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/services/achievement_service.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/state_detection_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model for lifetime statistics
class LifetimeStats {
  const LifetimeStats({
    this.totalDistance = 0,
    this.totalDuration = 0,
    this.totalSessions = 0,
    this.totalWaypoints = 0,
    this.totalPhotos = 0,
    this.totalVoiceNotes = 0,
    this.totalHuntsCreated = 0,
    this.totalHuntsSolved = 0,
    this.totalElevationGain = 0,
    this.statesExplored = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActivityDate,
    this.prLongestSessionDistance,
    this.prLongestSessionDuration,
    this.prMostElevationGain,
    this.prLongestSessionId,
    this.prElevationSessionId,
  });

  factory LifetimeStats.fromMap(Map<String, dynamic> map) {
    return LifetimeStats(
      totalDistance: (map['total_distance'] as num?)?.toDouble() ?? 0,
      totalDuration: (map['total_duration'] as int?) ?? 0,
      totalSessions: (map['total_sessions'] as int?) ?? 0,
      totalWaypoints: (map['total_waypoints'] as int?) ?? 0,
      totalPhotos: (map['total_photos'] as int?) ?? 0,
      totalVoiceNotes: (map['total_voice_notes'] as int?) ?? 0,
      totalHuntsCreated: (map['total_hunts_created'] as int?) ?? 0,
      totalHuntsSolved: (map['total_hunts_solved'] as int?) ?? 0,
      totalElevationGain: (map['total_elevation_gain'] as num?)?.toDouble() ?? 0,
      statesExplored: (map['states_explored'] as int?) ?? 0,
      currentStreak: (map['current_streak'] as int?) ?? 0,
      longestStreak: (map['longest_streak'] as int?) ?? 0,
      lastActivityDate: map['last_activity_date'] as String?,
      prLongestSessionDistance: (map['pr_longest_session_distance'] as num?)?.toDouble(),
      prLongestSessionDuration: map['pr_longest_session_duration'] as int?,
      prMostElevationGain: (map['pr_most_elevation_gain'] as num?)?.toDouble(),
      prLongestSessionId: map['pr_longest_session_id'] as String?,
      prElevationSessionId: map['pr_elevation_session_id'] as String?,
    );
  }

  final double totalDistance; // meters
  final int totalDuration; // milliseconds
  final int totalSessions;
  final int totalWaypoints;
  final int totalPhotos;
  final int totalVoiceNotes;
  final int totalHuntsCreated;
  final int totalHuntsSolved;
  final double totalElevationGain; // meters
  final int statesExplored;
  final int currentStreak; // days
  final int longestStreak; // days
  final String? lastActivityDate; // YYYY-MM-DD
  final double? prLongestSessionDistance;
  final int? prLongestSessionDuration;
  final double? prMostElevationGain;
  final String? prLongestSessionId;
  final String? prElevationSessionId;

  /// Get total distance in miles
  double get totalDistanceMiles => totalDistance / 1609.344;

  /// Get total duration as Duration
  Duration get totalDurationDuration => Duration(milliseconds: totalDuration);

  /// Get formatted total time
  String get formattedTotalTime {
    final duration = totalDurationDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Map<String, dynamic> toMap() {
    return {
      'total_distance': totalDistance,
      'total_duration': totalDuration,
      'total_sessions': totalSessions,
      'total_waypoints': totalWaypoints,
      'total_photos': totalPhotos,
      'total_voice_notes': totalVoiceNotes,
      'total_hunts_created': totalHuntsCreated,
      'total_hunts_solved': totalHuntsSolved,
      'total_elevation_gain': totalElevationGain,
      'states_explored': statesExplored,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_activity_date': lastActivityDate,
      'pr_longest_session_distance': prLongestSessionDistance,
      'pr_longest_session_duration': prLongestSessionDuration,
      'pr_most_elevation_gain': prMostElevationGain,
      'pr_longest_session_id': prLongestSessionId,
      'pr_elevation_session_id': prElevationSessionId,
    };
  }

  LifetimeStats copyWith({
    double? totalDistance,
    int? totalDuration,
    int? totalSessions,
    int? totalWaypoints,
    int? totalPhotos,
    int? totalVoiceNotes,
    int? totalHuntsCreated,
    int? totalHuntsSolved,
    double? totalElevationGain,
    int? statesExplored,
    int? currentStreak,
    int? longestStreak,
    String? lastActivityDate,
    double? prLongestSessionDistance,
    int? prLongestSessionDuration,
    double? prMostElevationGain,
    String? prLongestSessionId,
    String? prElevationSessionId,
  }) {
    return LifetimeStats(
      totalDistance: totalDistance ?? this.totalDistance,
      totalDuration: totalDuration ?? this.totalDuration,
      totalSessions: totalSessions ?? this.totalSessions,
      totalWaypoints: totalWaypoints ?? this.totalWaypoints,
      totalPhotos: totalPhotos ?? this.totalPhotos,
      totalVoiceNotes: totalVoiceNotes ?? this.totalVoiceNotes,
      totalHuntsCreated: totalHuntsCreated ?? this.totalHuntsCreated,
      totalHuntsSolved: totalHuntsSolved ?? this.totalHuntsSolved,
      totalElevationGain: totalElevationGain ?? this.totalElevationGain,
      statesExplored: statesExplored ?? this.statesExplored,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      prLongestSessionDistance: prLongestSessionDistance ?? this.prLongestSessionDistance,
      prLongestSessionDuration: prLongestSessionDuration ?? this.prLongestSessionDuration,
      prMostElevationGain: prMostElevationGain ?? this.prMostElevationGain,
      prLongestSessionId: prLongestSessionId ?? this.prLongestSessionId,
      prElevationSessionId: prElevationSessionId ?? this.prElevationSessionId,
    );
  }
}

/// Model for explored state
class ExploredState {
  const ExploredState({
    required this.id,
    required this.stateCode,
    required this.stateName,
    required this.firstVisitedAt,
    required this.lastVisitedAt,
    this.sessionCount = 1,
    this.totalDistance = 0,
    this.totalDuration = 0,
  });

  factory ExploredState.fromMap(Map<String, dynamic> map) {
    return ExploredState(
      id: map['id'] as String,
      stateCode: map['state_code'] as String,
      stateName: map['state_name'] as String,
      firstVisitedAt: DateTime.fromMillisecondsSinceEpoch(map['first_visited_at'] as int),
      lastVisitedAt: DateTime.fromMillisecondsSinceEpoch(map['last_visited_at'] as int),
      sessionCount: (map['session_count'] as int?) ?? 1,
      totalDistance: (map['total_distance'] as num?)?.toDouble() ?? 0,
      totalDuration: (map['total_duration'] as int?) ?? 0,
    );
  }

  final String id;
  final String stateCode;
  final String stateName;
  final DateTime firstVisitedAt;
  final DateTime lastVisitedAt;
  final int sessionCount;
  final double totalDistance;
  final int totalDuration;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'state_code': stateCode,
      'state_name': stateName,
      'first_visited_at': firstVisitedAt.millisecondsSinceEpoch,
      'last_visited_at': lastVisitedAt.millisecondsSinceEpoch,
      'session_count': sessionCount,
      'total_distance': totalDistance,
      'total_duration': totalDuration,
    };
  }
}

/// Service for managing lifetime statistics
///
/// Tracks aggregate statistics across all sessions, personal records,
/// state exploration, and session streaks. All data is stored locally
/// for privacy.
class LifetimeStatisticsService {
  factory LifetimeStatisticsService() => _instance;
  LifetimeStatisticsService._internal();
  static final LifetimeStatisticsService _instance = LifetimeStatisticsService._internal();

  /// Key for tracking whether achievement migration has been completed
  static const String _achievementMigrationKey = 'achievements_migrated_v1';

  final DatabaseService _db = DatabaseService();
  final StateDetectionService _stateDetection = StateDetectionService();

  LifetimeStats? _cachedStats;
  bool _isInitialized = false;

  // Stream controller for stats updates
  final _statsController = StreamController<LifetimeStats>.broadcast();
  Stream<LifetimeStats> get statsStream => _statsController.stream;

  /// Initialize the service
  ///
  /// [skipAchievementCheck] - Set to true when called from AchievementService.initialize()
  /// to prevent circular dependency deadlock. The AchievementService will handle
  /// achievement checking after its own initialization completes.
  Future<void> initialize({bool skipAchievementCheck = false}) async {
    if (_isInitialized) return;

    await _stateDetection.initialize();
    await _loadStats();
    _isInitialized = true;
    debugPrint('LifetimeStatisticsService initialized');

    // Check if achievement migration has been completed
    // This handles existing users upgrading to a version with achievements
    final prefs = await SharedPreferences.getInstance();
    final achievementsMigrated = prefs.getBool(_achievementMigrationKey) ?? false;

    final sessions = await _db.getAllSessions();
    final completedSessionCount = sessions.where((s) => s.status == SessionStatus.completed).length;

    if (!achievementsMigrated && completedSessionCount > 0) {
      // First-time migration: recalculate all stats and check all achievements
      debugPrint('🔄 Achievement migration needed - $completedSessionCount completed sessions found');
      debugPrint('🔄 Recalculating lifetime statistics from existing data...');
      await recalculateFromAllSessions();

      // Only check achievements if not being called from AchievementService
      // to prevent circular dependency deadlock
      if (!skipAchievementCheck) {
        debugPrint('🏆 Checking achievements for existing data...');
        final achievementService = AchievementService();
        await achievementService.checkAllAchievements();
      } else {
        debugPrint('🏆 Skipping achievement check (will be handled by caller)');
      }

      // Mark migration as complete
      await prefs.setBool(_achievementMigrationKey, true);
      debugPrint('✅ Achievement migration complete');
    } else if (completedSessionCount > 0 &&
        (_cachedStats == null ||
         _cachedStats!.totalSessions == 0 ||
         _cachedStats!.statesExplored == 0)) {
      // Stats are incomplete but migration was done - just recalculate stats
      debugPrint('🔄 Stats incomplete - auto-recalculating...');
      await recalculateFromAllSessions();
    }
  }

  /// Get current lifetime statistics
  Future<LifetimeStats> getStatistics() async {
    if (_cachedStats != null) return _cachedStats!;
    await _loadStats();
    return _cachedStats ?? const LifetimeStats();
  }

  /// Force reload statistics from database
  ///
  /// Use this after directly modifying the database (e.g., mock data for screenshots).
  Future<void> reloadStats() async {
    _cachedStats = null;
    await _loadStats();
    if (_cachedStats != null) {
      _statsController.add(_cachedStats!);
    }
    debugPrint('LifetimeStatisticsService: Stats reloaded from database');
  }

  /// Load statistics from database
  Future<void> _loadStats() async {
    try {
      final map = await _db.getLifetimeStatistics();
      if (map != null) {
        _cachedStats = LifetimeStats.fromMap(map);
      } else {
        _cachedStats = const LifetimeStats();
      }
    } catch (e) {
      debugPrint('Error loading lifetime statistics: $e');
      _cachedStats = const LifetimeStats();
    }
  }

  /// Update statistics after a session is completed
  Future<void> updateFromSession(
    TrackingSession session,
    List<Breadcrumb> breadcrumbs, {
    int waypointCount = 0,
    int photoCount = 0,
    int voiceNoteCount = 0,
  }) async {
    try {
      await initialize();

      final now = DateTime.now();
      final today = _formatDate(now);
      var stats = _cachedStats ?? const LifetimeStats();

      // Update basic stats
      stats = stats.copyWith(
        totalDistance: stats.totalDistance + session.totalDistance,
        totalDuration: stats.totalDuration + session.totalDuration,
        totalSessions: stats.totalSessions + 1,
        totalWaypoints: stats.totalWaypoints + waypointCount,
        totalPhotos: stats.totalPhotos + photoCount,
        totalVoiceNotes: stats.totalVoiceNotes + voiceNoteCount,
        totalElevationGain: stats.totalElevationGain + session.elevationGain,
      );

      // Check for personal records
      if (stats.prLongestSessionDistance == null ||
          session.totalDistance > stats.prLongestSessionDistance!) {
        stats = stats.copyWith(
          prLongestSessionDistance: session.totalDistance,
          prLongestSessionId: session.id,
        );
      }

      if (stats.prLongestSessionDuration == null ||
          session.totalDuration > stats.prLongestSessionDuration!) {
        stats = stats.copyWith(
          prLongestSessionDuration: session.totalDuration,
        );
      }

      if (stats.prMostElevationGain == null ||
          session.elevationGain > stats.prMostElevationGain!) {
        stats = stats.copyWith(
          prMostElevationGain: session.elevationGain,
          prElevationSessionId: session.id,
        );
      }

      // Update streak
      final streakResult = await _updateStreak(today, stats.lastActivityDate);
      stats = stats.copyWith(
        currentStreak: streakResult.currentStreak,
        longestStreak: streakResult.longestStreak > stats.longestStreak
            ? streakResult.longestStreak
            : stats.longestStreak,
        lastActivityDate: today,
      );

      // Update state exploration from breadcrumbs
      if (breadcrumbs.isNotEmpty) {
        await _updateStateExploration(breadcrumbs, session);
        final statesCount = await _db.getExploredStatesCount();
        stats = stats.copyWith(statesExplored: statesCount);
      }

      // Save to database
      await _db.updateLifetimeStatistics(stats.toMap());
      _cachedStats = stats;
      _statsController.add(stats);

      debugPrint('Updated lifetime stats: ${stats.totalSessions} sessions, '
          '${stats.totalDistanceMiles.toStringAsFixed(1)} miles');
    } catch (e) {
      debugPrint('Error updating lifetime statistics: $e');
    }
  }

  /// Update state exploration from breadcrumbs
  Future<void> _updateStateExploration(
    List<Breadcrumb> breadcrumbs,
    TrackingSession session,
  ) async {
    // Sample breadcrumbs for state detection (every 10th point for performance)
    final sampledCoords = <({double lat, double lng})>[];
    for (var i = 0; i < breadcrumbs.length; i += 10) {
      sampledCoords.add((
        lat: breadcrumbs[i].coordinates.latitude,
        lng: breadcrumbs[i].coordinates.longitude,
      ));
    }
    // Always include the last point
    if (breadcrumbs.isNotEmpty) {
      sampledCoords.add((
        lat: breadcrumbs.last.coordinates.latitude,
        lng: breadcrumbs.last.coordinates.longitude,
      ));
    }

    final states = _stateDetection.getStatesFromCoordinates(sampledCoords);
    final now = DateTime.now();

    for (final stateCode in states) {
      final existing = await _db.getExploredState(stateCode);

      if (existing != null) {
        // Update existing state
        final existingState = ExploredState.fromMap(existing);
        await _db.upsertExploredState({
          'id': existingState.id,
          'state_code': stateCode,
          'state_name': _stateDetection.getStateName(stateCode),
          'first_visited_at': existingState.firstVisitedAt.millisecondsSinceEpoch,
          'last_visited_at': now.millisecondsSinceEpoch,
          'session_count': existingState.sessionCount + 1,
          'total_distance': existingState.totalDistance + session.totalDistance,
          'total_duration': existingState.totalDuration + session.totalDuration,
        });
      } else {
        // Insert new state
        await _db.upsertExploredState({
          'id': 'state_$stateCode',
          'state_code': stateCode,
          'state_name': _stateDetection.getStateName(stateCode),
          'first_visited_at': now.millisecondsSinceEpoch,
          'last_visited_at': now.millisecondsSinceEpoch,
          'session_count': 1,
          'total_distance': session.totalDistance,
          'total_duration': session.totalDuration,
        });
      }
    }
  }

  /// Update streak and return new values
  Future<({int currentStreak, int longestStreak})> _updateStreak(
    String today,
    String? lastActivityDate,
  ) async {
    // Record today's session
    await _db.recordSessionDay(today);

    // Calculate current streak
    final streakDays = await _db.getSessionStreakDays(limit: 365);
    if (streakDays.isEmpty) {
      return (currentStreak: 1, longestStreak: 1);
    }

    var currentStreak = 0;
    var longestStreak = 0;
    var tempStreak = 0;
    DateTime? previousDate;

    for (final day in streakDays) {
      final dateStr = day['date'] as String;
      final date = DateTime.parse(dateStr);

      if (previousDate == null) {
        tempStreak = 1;
        currentStreak = 1;
      } else {
        final diff = previousDate.difference(date).inDays;
        if (diff == 1) {
          tempStreak++;
          if (currentStreak == tempStreak - 1) {
            currentStreak = tempStreak;
          }
        } else {
          if (tempStreak > longestStreak) {
            longestStreak = tempStreak;
          }
          tempStreak = 1;
        }
      }

      previousDate = date;
    }

    if (tempStreak > longestStreak) {
      longestStreak = tempStreak;
    }

    return (currentStreak: currentStreak, longestStreak: longestStreak);
  }

  /// Get all explored states
  Future<List<ExploredState>> getExploredStates() async {
    try {
      final maps = await _db.getExploredStates();
      return maps.map(ExploredState.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting explored states: $e');
      return [];
    }
  }

  /// Get explored state by code
  Future<ExploredState?> getExploredState(String stateCode) async {
    try {
      final map = await _db.getExploredState(stateCode);
      return map != null ? ExploredState.fromMap(map) : null;
    } catch (e) {
      debugPrint('Error getting explored state: $e');
      return null;
    }
  }

  /// Increment hunt created count
  Future<void> incrementHuntsCreated() async {
    try {
      await initialize();
      var stats = _cachedStats ?? const LifetimeStats();
      stats = stats.copyWith(totalHuntsCreated: stats.totalHuntsCreated + 1);
      await _db.updateLifetimeStatistics(stats.toMap());
      _cachedStats = stats;
      _statsController.add(stats);
    } catch (e) {
      debugPrint('Error incrementing hunts created: $e');
    }
  }

  /// Increment hunt solved count
  Future<void> incrementHuntsSolved() async {
    try {
      await initialize();
      var stats = _cachedStats ?? const LifetimeStats();
      stats = stats.copyWith(totalHuntsSolved: stats.totalHuntsSolved + 1);
      await _db.updateLifetimeStatistics(stats.toMap());
      _cachedStats = stats;
      _statsController.add(stats);
    } catch (e) {
      debugPrint('Error incrementing hunts solved: $e');
    }
  }

  /// Recalculate all statistics from existing sessions
  ///
  /// Use this for data recovery or initial population.
  Future<void> recalculateFromAllSessions() async {
    try {
      debugPrint('Recalculating lifetime statistics from all sessions...');

      final sessions = await _db.getAllSessions();
      var stats = const LifetimeStats();

      int totalWaypoints = 0;
      int totalPhotos = 0;
      int totalVoiceNotes = 0;

      for (final session in sessions) {
        if (session.status != SessionStatus.completed) continue;

        final breadcrumbs = await _db.getBreadcrumbsForSession(session.id);

        // Count waypoints, photos, and voice notes for this session
        final waypoints = await _db.getWaypointsForSession(session.id);
        final photoCount = await _db.countPhotosForSession(session.id);
        final voiceNoteCount = await _db.countVoiceNotesForSession(session.id);

        totalWaypoints += waypoints.length;
        totalPhotos += photoCount;
        totalVoiceNotes += voiceNoteCount;

        stats = stats.copyWith(
          totalDistance: stats.totalDistance + session.totalDistance,
          totalDuration: stats.totalDuration + session.totalDuration,
          totalSessions: stats.totalSessions + 1,
          totalElevationGain: stats.totalElevationGain + session.elevationGain,
        );

        // Update PRs
        if (stats.prLongestSessionDistance == null ||
            session.totalDistance > stats.prLongestSessionDistance!) {
          stats = stats.copyWith(
            prLongestSessionDistance: session.totalDistance,
            prLongestSessionId: session.id,
          );
        }
        if (stats.prMostElevationGain == null ||
            session.elevationGain > stats.prMostElevationGain!) {
          stats = stats.copyWith(
            prMostElevationGain: session.elevationGain,
            prElevationSessionId: session.id,
          );
        }

        // Update state exploration
        if (breadcrumbs.isNotEmpty) {
          await _updateStateExploration(breadcrumbs, session);
        }
      }

      final statesCount = await _db.getExploredStatesCount();
      stats = stats.copyWith(
        statesExplored: statesCount,
        totalWaypoints: totalWaypoints,
        totalPhotos: totalPhotos,
        totalVoiceNotes: totalVoiceNotes,
      );

      await _db.updateLifetimeStatistics(stats.toMap());
      _cachedStats = stats;
      _statsController.add(stats);

      debugPrint('Recalculation complete: ${stats.totalSessions} sessions, '
          '$totalWaypoints waypoints, $totalPhotos photos, $totalVoiceNotes voice notes');
    } catch (e) {
      debugPrint('Error recalculating lifetime statistics: $e');
    }
  }

  /// Format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Dispose of resources
  void dispose() {
    _statsController.close();
  }
}
