// Gamification Models for Milestone 10
// Supports achievement system, statistics tracking, and personal records

import 'package:flutter/foundation.dart';

/// Achievement categories
enum AchievementCategory {
  distance,
  duration,
  elevation,
  speed,
  exploration,
  consistency,
  photography,
  navigation,
  endurance,
  discovery,
}

/// Achievement difficulty levels
enum AchievementDifficulty {
  bronze,
  silver,
  gold,
  platinum,
  legendary,
}

/// Achievement status
enum AchievementStatus {
  locked,
  available,
  inProgress,
  completed,
}

/// Achievement type
enum AchievementType {
  single, // One-time achievement
  progressive, // Multi-level achievement
  recurring, // Can be earned multiple times
  seasonal, // Time-limited achievement
}

/// Base achievement model
@immutable
class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.type,
    required this.requirements,
    required this.rewards,
    required this.iconPath,
    required this.isSecret,
    required this.sortOrder,
    this.prerequisiteIds = const [],
    this.seasonalStart,
    this.seasonalEnd,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        category: AchievementCategory.values[json['category'] as int],
        difficulty: AchievementDifficulty.values[json['difficulty'] as int],
        type: AchievementType.values[json['type'] as int],
        requirements: AchievementRequirements.fromJson(
            json['requirements'] as Map<String, dynamic>),
        rewards: AchievementRewards.fromJson(
            json['rewards'] as Map<String, dynamic>),
        iconPath: json['iconPath'] as String,
        isSecret: json['isSecret'] as bool,
        sortOrder: json['sortOrder'] as int,
        prerequisiteIds:
            (json['prerequisiteIds'] as List<dynamic>).cast<String>(),
        seasonalStart: json['seasonalStart'] != null
            ? DateTime.parse(json['seasonalStart'] as String)
            : null,
        seasonalEnd: json['seasonalEnd'] != null
            ? DateTime.parse(json['seasonalEnd'] as String)
            : null,
      );

  final String id;
  final String name;
  final String description;
  final AchievementCategory category;
  final AchievementDifficulty difficulty;
  final AchievementType type;
  final AchievementRequirements requirements;
  final AchievementRewards rewards;
  final String iconPath;
  final bool isSecret;
  final int sortOrder;
  final List<String> prerequisiteIds;
  final DateTime? seasonalStart;
  final DateTime? seasonalEnd;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category.index,
        'difficulty': difficulty.index,
        'type': type.index,
        'requirements': requirements.toJson(),
        'rewards': rewards.toJson(),
        'iconPath': iconPath,
        'isSecret': isSecret,
        'sortOrder': sortOrder,
        'prerequisiteIds': prerequisiteIds,
        'seasonalStart': seasonalStart?.toIso8601String(),
        'seasonalEnd': seasonalEnd?.toIso8601String(),
      };

  bool get isSeasonal => seasonalStart != null && seasonalEnd != null;

  bool get isCurrentlyAvailable {
    if (!isSeasonal) return true;
    final now = DateTime.now();
    return now.isAfter(seasonalStart!) && now.isBefore(seasonalEnd!);
  }
}

/// Achievement requirements
@immutable
class AchievementRequirements {
  const AchievementRequirements({
    this.totalDistance,
    this.totalDuration,
    this.totalElevationGain,
    this.maxSpeed,
    this.averageSpeed,
    this.sessionCount,
    this.consecutiveDays,
    this.waypointCount,
    this.photoCount,
    this.uniqueLocations,
    this.customConditions = const {},
  });

  factory AchievementRequirements.fromJson(Map<String, dynamic> json) =>
      AchievementRequirements(
        totalDistance: json['totalDistance'] as double?,
        totalDuration: json['totalDuration'] != null
            ? Duration(milliseconds: json['totalDuration'] as int)
            : null,
        totalElevationGain: json['totalElevationGain'] as double?,
        maxSpeed: json['maxSpeed'] as double?,
        averageSpeed: json['averageSpeed'] as double?,
        sessionCount: json['sessionCount'] as int?,
        consecutiveDays: json['consecutiveDays'] as int?,
        waypointCount: json['waypointCount'] as int?,
        photoCount: json['photoCount'] as int?,
        uniqueLocations: json['uniqueLocations'] as int?,
        customConditions:
            Map<String, dynamic>.from(json['customConditions'] as Map? ?? {}),
      );

  final double? totalDistance; // meters
  final Duration? totalDuration;
  final double? totalElevationGain; // meters
  final double? maxSpeed; // m/s
  final double? averageSpeed; // m/s
  final int? sessionCount;
  final int? consecutiveDays;
  final int? waypointCount;
  final int? photoCount;
  final int? uniqueLocations;
  final Map<String, dynamic> customConditions;

  Map<String, dynamic> toJson() => {
        'totalDistance': totalDistance,
        'totalDuration': totalDuration?.inMilliseconds,
        'totalElevationGain': totalElevationGain,
        'maxSpeed': maxSpeed,
        'averageSpeed': averageSpeed,
        'sessionCount': sessionCount,
        'consecutiveDays': consecutiveDays,
        'waypointCount': waypointCount,
        'photoCount': photoCount,
        'uniqueLocations': uniqueLocations,
        'customConditions': customConditions,
      };
}

/// Achievement rewards
@immutable
class AchievementRewards {
  const AchievementRewards({
    required this.points,
    this.badges = const [],
    this.titles = const [],
    this.unlocks = const [],
  }); // Features or content unlocked

  factory AchievementRewards.fromJson(Map<String, dynamic> json) =>
      AchievementRewards(
        points: json['points'] as int,
        badges: (json['badges'] as List<dynamic>).cast<String>(),
        titles: (json['titles'] as List<dynamic>).cast<String>(),
        unlocks: (json['unlocks'] as List<dynamic>).cast<String>(),
      );

  final int points;
  final List<String> badges;
  final List<String> titles;
  final List<String> unlocks;

  Map<String, dynamic> toJson() => {
        'points': points,
        'badges': badges,
        'titles': titles,
        'unlocks': unlocks,
      };
}

/// User's achievement progress
@immutable
class UserAchievement {
  const UserAchievement({
    required this.achievementId,
    required this.status,
    required this.progress,
    required this.maxProgress,
    required this.unlockedAt,
    required this.completedAt,
    required this.currentStreak,
    required this.bestStreak,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) =>
      UserAchievement(
        achievementId: json['achievementId'] as String,
        status: AchievementStatus.values[json['status'] as int],
        progress: json['progress'] as double,
        maxProgress: json['maxProgress'] as double,
        unlockedAt: json['unlockedAt'] != null
            ? DateTime.parse(json['unlockedAt'] as String)
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
        currentStreak: json['currentStreak'] as int,
        bestStreak: json['bestStreak'] as int,
      );

  final String achievementId;
  final AchievementStatus status;
  final double progress;
  final double maxProgress;
  final DateTime? unlockedAt;
  final DateTime? completedAt;
  final int currentStreak;
  final int bestStreak;

  double get progressPercentage =>
      maxProgress > 0 ? progress / maxProgress : 0.0;

  bool get isCompleted => status == AchievementStatus.completed;

  Map<String, dynamic> toJson() => {
        'achievementId': achievementId,
        'status': status.index,
        'progress': progress,
        'maxProgress': maxProgress,
        'unlockedAt': unlockedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
      };

  UserAchievement copyWith({
    String? achievementId,
    AchievementStatus? status,
    double? progress,
    double? maxProgress,
    DateTime? unlockedAt,
    DateTime? completedAt,
    int? currentStreak,
    int? bestStreak,
  }) =>
      UserAchievement(
        achievementId: achievementId ?? this.achievementId,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        maxProgress: maxProgress ?? this.maxProgress,
        unlockedAt: unlockedAt ?? this.unlockedAt,
        completedAt: completedAt ?? this.completedAt,
        currentStreak: currentStreak ?? this.currentStreak,
        bestStreak: bestStreak ?? this.bestStreak,
      );
}

/// Personal record types
enum PersonalRecordType {
  longestDistance,
  longestDuration,
  highestElevationGain,
  fastestSpeed,
  mostWaypoints,
  mostPhotos,
  longestStreak,
  mostActiveDay,
  bestMonth,
  bestYear,
}

/// Personal record entry
@immutable
class PersonalRecord {
  const PersonalRecord({
    required this.id,
    required this.type,
    required this.value,
    required this.unit,
    required this.achievedAt,
    required this.sessionId,
    required this.description,
    required this.metadata,
  });

  factory PersonalRecord.fromJson(Map<String, dynamic> json) => PersonalRecord(
        id: json['id'] as String,
        type: PersonalRecordType.values[json['type'] as int],
        value: json['value'] as double,
        unit: json['unit'] as String,
        achievedAt: DateTime.parse(json['achievedAt'] as String),
        sessionId: json['sessionId'] as String?,
        description: json['description'] as String,
        metadata: Map<String, dynamic>.from(json['metadata'] as Map),
      );

  final String id;
  final PersonalRecordType type;
  final double value;
  final String unit;
  final DateTime achievedAt;
  final String? sessionId;
  final String description;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'value': value,
        'unit': unit,
        'achievedAt': achievedAt.toIso8601String(),
        'sessionId': sessionId,
        'description': description,
        'metadata': metadata,
      };

  String get formattedValue {
    switch (type) {
      case PersonalRecordType.longestDistance:
        return value < 1000
            ? '${value.toStringAsFixed(0)} m'
            : '${(value / 1000).toStringAsFixed(2)} km';
      case PersonalRecordType.longestDuration:
        final duration = Duration(milliseconds: value.toInt());
        final hours = duration.inHours;
        final minutes = duration.inMinutes.remainder(60);
        return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
      case PersonalRecordType.highestElevationGain:
        return '${value.toStringAsFixed(0)} m';
      case PersonalRecordType.fastestSpeed:
        return '${(value * 3.6).toStringAsFixed(1)} km/h';
      // ignore: no_default_cases
      default:
        return '${value.toStringAsFixed(0)} $unit';
    }
  }
}

/// User statistics
@immutable
class UserStatistics {
  const UserStatistics({
    required this.totalDistance,
    required this.totalDuration,
    required this.totalElevationGain,
    required this.totalSessions,
    required this.totalWaypoints,
    required this.totalPhotos,
    required this.currentStreak,
    required this.longestStreak,
    required this.achievementPoints,
    required this.completedAchievements,
    required this.level,
    required this.experiencePoints,
    required this.lastActivityDate,
    required this.joinDate,
  });

  factory UserStatistics.fromJson(Map<String, dynamic> json) => UserStatistics(
        totalDistance: json['totalDistance'] as double,
        totalDuration: Duration(milliseconds: json['totalDuration'] as int),
        totalElevationGain: json['totalElevationGain'] as double,
        totalSessions: json['totalSessions'] as int,
        totalWaypoints: json['totalWaypoints'] as int,
        totalPhotos: json['totalPhotos'] as int,
        currentStreak: json['currentStreak'] as int,
        longestStreak: json['longestStreak'] as int,
        achievementPoints: json['achievementPoints'] as int,
        completedAchievements: json['completedAchievements'] as int,
        level: json['level'] as int,
        experiencePoints: json['experiencePoints'] as int,
        lastActivityDate: json['lastActivityDate'] != null
            ? DateTime.parse(json['lastActivityDate'] as String)
            : null,
        joinDate: DateTime.parse(json['joinDate'] as String),
      );

  final double totalDistance; // meters
  final Duration totalDuration;
  final double totalElevationGain; // meters
  final int totalSessions;
  final int totalWaypoints;
  final int totalPhotos;
  final int currentStreak; // days
  final int longestStreak; // days
  final int achievementPoints;
  final int completedAchievements;
  final int level;
  final int experiencePoints;
  final DateTime? lastActivityDate;
  final DateTime joinDate;

  Map<String, dynamic> toJson() => {
        'totalDistance': totalDistance,
        'totalDuration': totalDuration.inMilliseconds,
        'totalElevationGain': totalElevationGain,
        'totalSessions': totalSessions,
        'totalWaypoints': totalWaypoints,
        'totalPhotos': totalPhotos,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'achievementPoints': achievementPoints,
        'completedAchievements': completedAchievements,
        'level': level,
        'experiencePoints': experiencePoints,
        'lastActivityDate': lastActivityDate?.toIso8601String(),
        'joinDate': joinDate.toIso8601String(),
      };

  double get averageSessionDistance =>
      totalSessions > 0 ? totalDistance / totalSessions : 0.0;

  Duration get averageSessionDuration => totalSessions > 0
      ? Duration(milliseconds: totalDuration.inMilliseconds ~/ totalSessions)
      : Duration.zero;

  int get experienceToNextLevel => ((level + 1) * 1000) - experiencePoints;

  double get levelProgress {
    final currentLevelXp = level * 1000;
    final nextLevelXp = (level + 1) * 1000;
    final progressXp = experiencePoints - currentLevelXp;
    final requiredXp = nextLevelXp - currentLevelXp;
    return requiredXp > 0 ? progressXp / requiredXp : 0.0;
  }
}

/// Leaderboard entry
@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.rank,
    required this.value,
    required this.category,
    required this.period,
    required this.lastUpdated,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        userId: json['userId'] as String,
        username: json['username'] as String,
        rank: json['rank'] as int,
        value: json['value'] as double,
        category: json['category'] as String,
        period: json['period'] as String,
        lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      );

  final String userId;
  final String username;
  final int rank;
  final double value;
  final String category;
  final String period; // 'daily', 'weekly', 'monthly', 'all-time'
  final DateTime lastUpdated;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'rank': rank,
        'value': value,
        'category': category,
        'period': period,
        'lastUpdated': lastUpdated.toIso8601String(),
      };
}

/// Challenge types
enum ChallengeType {
  distance,
  duration,
  elevation,
  consistency,
  exploration,
  photography,
  social,
}

/// Challenge status
enum ChallengeStatus {
  upcoming,
  active,
  completed,
  failed,
  expired,
}

/// Time-limited challenge
@immutable
class Challenge {
  const Challenge({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.requirements,
    required this.rewards,
    required this.participants,
    required this.maxParticipants,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        type: ChallengeType.values[json['type'] as int],
        status: ChallengeStatus.values[json['status'] as int],
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
        requirements: AchievementRequirements.fromJson(
            json['requirements'] as Map<String, dynamic>),
        rewards: AchievementRewards.fromJson(
            json['rewards'] as Map<String, dynamic>),
        participants: json['participants'] as int,
        maxParticipants: json['maxParticipants'] as int?,
      );

  final String id;
  final String name;
  final String description;
  final ChallengeType type;
  final ChallengeStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final AchievementRequirements requirements;
  final AchievementRewards rewards;
  final int participants;
  final int? maxParticipants;

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  Duration get timeRemaining {
    final now = DateTime.now();
    return now.isBefore(endDate) ? endDate.difference(now) : Duration.zero;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'type': type.index,
        'status': status.index,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'requirements': requirements.toJson(),
        'rewards': rewards.toJson(),
        'participants': participants,
        'maxParticipants': maxParticipants,
      };
}
