import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Configuration for merging multiple sessions
@immutable
class SessionMergeConfig {
  const SessionMergeConfig({
    required this.sessionIds,
    required this.mergedSessionName,
    this.mergedSessionDescription,
    this.mergeStrategy = SessionMergeStrategy.chronological,
    this.gapHandling = GapHandling.preserve,
    this.maxGapDuration = const Duration(hours: 1),
    this.preserveWaypoints = true,
    this.preservePhotos = true,
    this.preserveStatistics = true,
  });

  /// List of session IDs to merge (in order)
  final List<String> sessionIds;

  /// Name for the merged session
  final String mergedSessionName;

  /// Optional description for the merged session
  final String? mergedSessionDescription;

  /// Strategy for merging sessions
  final SessionMergeStrategy mergeStrategy;

  /// How to handle gaps between sessions
  final GapHandling gapHandling;

  /// Maximum gap duration to consider sessions continuous
  final Duration maxGapDuration;

  /// Whether to preserve waypoints from all sessions
  final bool preserveWaypoints;

  /// Whether to preserve photos from all sessions
  final bool preservePhotos;

  /// Whether to preserve statistics from all sessions
  final bool preserveStatistics;
}

/// Strategy for merging sessions
enum SessionMergeStrategy {
  /// Merge sessions in chronological order
  chronological,

  /// Merge sessions based on geographical proximity
  geographical,

  /// Merge sessions with custom ordering
  custom,
}

/// How to handle gaps between sessions
enum GapHandling {
  /// Preserve gaps as they are
  preserve,

  /// Fill gaps with interpolated data
  interpolate,

  /// Mark gaps explicitly
  markGaps,

  /// Remove gaps entirely
  removeGaps,
}

/// Configuration for splitting a session
@immutable
class SessionSplitConfig {
  const SessionSplitConfig({
    required this.sessionId,
    required this.splitPoints,
    this.splitStrategy = SessionSplitStrategy.timeBasedSplit,
    this.namingStrategy = SplitNamingStrategy.sequential,
    this.preserveOriginal = false,
    this.redistributeWaypoints = true,
    this.redistributePhotos = true,
    this.recalculateStatistics = true,
  });

  /// ID of the session to split
  final String sessionId;

  /// Points where to split the session
  final List<SessionSplitPoint> splitPoints;

  /// Strategy for splitting the session
  final SessionSplitStrategy splitStrategy;

  /// How to name the split sessions
  final SplitNamingStrategy namingStrategy;

  /// Whether to preserve the original session
  final bool preserveOriginal;

  /// Whether to redistribute waypoints to appropriate segments
  final bool redistributeWaypoints;

  /// Whether to redistribute photos to appropriate segments
  final bool redistributePhotos;

  /// Whether to recalculate statistics for each segment
  final bool recalculateStatistics;
}

/// Point where a session should be split
@immutable
class SessionSplitPoint {
  const SessionSplitPoint({
    required this.timestamp,
    this.location,
    this.reason,
    this.customName,
  });

  /// Timestamp where to split
  final DateTime timestamp;

  /// Optional location for the split point
  final LatLng? location;

  /// Reason for the split
  final String? reason;

  /// Custom name for the segment starting at this point
  final String? customName;
}

/// Strategy for splitting sessions
enum SessionSplitStrategy {
  /// Split based on time intervals
  timeBasedSplit,

  /// Split based on distance intervals
  distanceBasedSplit,

  /// Split based on activity pauses
  pauseBasedSplit,

  /// Split based on geographical boundaries
  geographicalSplit,

  /// Split at custom points
  customSplit,
}

/// How to name split sessions
enum SplitNamingStrategy {
  /// Sequential numbering (Session 1, Session 2, etc.)
  sequential,

  /// Time-based naming (Morning, Afternoon, etc.)
  timeBased,

  /// Custom names provided in split points
  custom,

  /// Activity-based naming (Hike, Rest, etc.)
  activityBased,
}

/// Result of a session merge operation
@immutable
class SessionMergeResult {
  const SessionMergeResult({
    required this.success,
    required this.mergedSessionId,
    this.originalSessionIds = const [],
    this.warnings = const [],
    this.errors = const [],
    this.mergedStatistics,
  });

  /// Whether the merge was successful
  final bool success;

  /// ID of the newly created merged session
  final String mergedSessionId;

  /// IDs of the original sessions that were merged
  final List<String> originalSessionIds;

  /// Any warnings generated during merge
  final List<String> warnings;

  /// Any errors that occurred during merge
  final List<String> errors;

  /// Statistics for the merged session
  final MergedSessionStatistics? mergedStatistics;
}

/// Result of a session split operation
@immutable
class SessionSplitResult {
  const SessionSplitResult({
    required this.success,
    required this.splitSessionIds,
    this.originalSessionId,
    this.warnings = const [],
    this.errors = const [],
    this.splitStatistics = const [],
  });

  /// Whether the split was successful
  final bool success;

  /// IDs of the newly created split sessions
  final List<String> splitSessionIds;

  /// ID of the original session that was split
  final String? originalSessionId;

  /// Any warnings generated during split
  final List<String> warnings;

  /// Any errors that occurred during split
  final List<String> errors;

  /// Statistics for each split session
  final List<SplitSessionStatistics> splitStatistics;
}

/// Statistics for a merged session
@immutable
class MergedSessionStatistics {
  const MergedSessionStatistics({
    required this.totalSessions,
    required this.totalDistance,
    required this.totalDuration,
    required this.totalBreadcrumbs,
    required this.totalWaypoints,
    required this.totalPhotos,
    this.gaps = const [],
    this.overlaps = const [],
  });

  /// Number of sessions that were merged
  final int totalSessions;

  /// Combined distance from all sessions
  final double totalDistance;

  /// Combined duration from all sessions
  final Duration totalDuration;

  /// Total breadcrumbs from all sessions
  final int totalBreadcrumbs;

  /// Total waypoints from all sessions
  final int totalWaypoints;

  /// Total photos from all sessions
  final int totalPhotos;

  /// Time gaps between sessions
  final List<Duration> gaps;

  /// Any overlapping time periods
  final List<Duration> overlaps;
}

/// Statistics for a split session segment
@immutable
class SplitSessionStatistics {
  const SplitSessionStatistics({
    required this.segmentIndex,
    required this.segmentName,
    required this.startTime,
    required this.endTime,
    required this.distance,
    required this.duration,
    required this.breadcrumbCount,
    required this.waypointCount,
    required this.photoCount,
  });

  /// Index of this segment in the split
  final int segmentIndex;

  /// Name of this segment
  final String segmentName;

  /// Start time of this segment
  final DateTime startTime;

  /// End time of this segment
  final DateTime endTime;

  /// Distance covered in this segment
  final double distance;

  /// Duration of this segment
  final Duration duration;

  /// Number of breadcrumbs in this segment
  final int breadcrumbCount;

  /// Number of waypoints in this segment
  final int waypointCount;

  /// Number of photos in this segment
  final int photoCount;
}

/// Validation result for merge/split operations
@immutable
class SessionOperationValidation {
  const SessionOperationValidation({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.suggestions = const [],
  });

  /// Whether the operation is valid
  final bool isValid;

  /// Validation errors that prevent the operation
  final List<String> errors;

  /// Warnings about potential issues
  final List<String> warnings;

  /// Suggestions for improving the operation
  final List<String> suggestions;
}
