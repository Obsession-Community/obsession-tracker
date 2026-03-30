import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/session_merge_split_models.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/waypoint_service.dart';
import 'package:uuid/uuid.dart';

/// Internal class for representing a session segment during splitting
@immutable
class SessionSegment {
  const SessionSegment({
    required this.index,
    required this.startTime,
    required this.endTime,
    required this.breadcrumbs,
    this.customName,
  });

  final int index;
  final DateTime startTime;
  final DateTime endTime;
  final List<Breadcrumb> breadcrumbs;
  final String? customName;
}

/// Service for merging and splitting tracking sessions
class SessionMergeSplitService {
  SessionMergeSplitService._();
  static SessionMergeSplitService? _instance;
  static SessionMergeSplitService get instance =>
      _instance ??= SessionMergeSplitService._();

  final DatabaseService _databaseService = DatabaseService();
  final WaypointService _waypointService = WaypointService.instance;
  final Uuid _uuid = const Uuid();

  /// Validate a session merge configuration
  Future<SessionOperationValidation> validateMergeConfig(
      SessionMergeConfig config) async {
    final List<String> errors = <String>[];
    final List<String> warnings = <String>[];
    final List<String> suggestions = <String>[];

    // Check minimum requirements
    if (config.sessionIds.length < 2) {
      errors.add('At least 2 sessions are required for merging');
    }

    if (config.mergedSessionName.trim().isEmpty) {
      errors.add('Merged session name cannot be empty');
    }

    // Check if all sessions exist and are valid
    for (final String sessionId in config.sessionIds) {
      try {
        final session = await _databaseService.getSession(sessionId);
        if (session == null) {
          errors.add('Session $sessionId not found');
          continue;
        }

        if (session.status == SessionStatus.active) {
          errors.add('Cannot merge active session: ${session.name}');
        }

        if (session.breadcrumbCount == 0) {
          warnings.add('Session "${session.name}" has no breadcrumbs');
        }
      } catch (e) {
        errors.add('Error accessing session $sessionId: $e');
      }
    }

    // Check for time overlaps if using chronological merge
    if (config.mergeStrategy == SessionMergeStrategy.chronological) {
      final sessions = await _getSessionsById(config.sessionIds);
      final overlaps = _detectTimeOverlaps(sessions);
      if (overlaps.isNotEmpty) {
        warnings
            .add('${overlaps.length} time overlaps detected between sessions');
        suggestions.add('Consider using geographical merge strategy instead');
      }
    }

    // Check for large gaps between sessions
    if (config.gapHandling == GapHandling.preserve) {
      final sessions = await _getSessionsById(config.sessionIds);
      final gaps = _detectLargeGaps(sessions, config.maxGapDuration);
      if (gaps.isNotEmpty) {
        warnings.add('${gaps.length} large gaps detected between sessions');
        suggestions.add('Consider using gap interpolation or marking gaps');
      }
    }

    return SessionOperationValidation(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  /// Validate a session split configuration
  Future<SessionOperationValidation> validateSplitConfig(
      SessionSplitConfig config) async {
    final List<String> errors = <String>[];
    final List<String> warnings = <String>[];
    final List<String> suggestions = <String>[];

    // Check if session exists
    final session = await _databaseService.getSession(config.sessionId);
    if (session == null) {
      errors.add('Session ${config.sessionId} not found');
      return SessionOperationValidation(isValid: false, errors: errors);
    }

    if (session.status == SessionStatus.active) {
      errors.add('Cannot split active session');
    }

    if (session.breadcrumbCount == 0) {
      errors.add('Cannot split session with no breadcrumbs');
    }

    // Validate split points
    if (config.splitPoints.isEmpty) {
      errors.add('At least one split point is required');
    }

    // Check split point timestamps are within session bounds
    if (session.startedAt != null && session.completedAt != null) {
      for (final point in config.splitPoints) {
        if (point.timestamp.isBefore(session.startedAt!) ||
            point.timestamp.isAfter(session.completedAt!)) {
          errors.add(
              'Split point ${point.timestamp} is outside session time range');
        }
      }
    }

    // Check for duplicate split points
    final timestamps = config.splitPoints.map((p) => p.timestamp).toList();
    final uniqueTimestamps = timestamps.toSet();
    if (timestamps.length != uniqueTimestamps.length) {
      warnings.add('Duplicate split points detected');
    }

    // Suggest minimum segment duration
    final sortedPoints = List<SessionSplitPoint>.from(config.splitPoints)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (int i = 0; i < sortedPoints.length - 1; i++) {
      final duration =
          sortedPoints[i + 1].timestamp.difference(sortedPoints[i].timestamp);
      if (duration.inMinutes < 5) {
        warnings
            .add('Very short segment detected (${duration.inMinutes} minutes)');
        suggestions
            .add('Consider merging short segments or adjusting split points');
      }
    }

    return SessionOperationValidation(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  /// Merge multiple sessions into a single session
  Future<SessionMergeResult> mergeSessions(SessionMergeConfig config) async {
    try {
      // Validate configuration
      final validation = await validateMergeConfig(config);
      if (!validation.isValid) {
        return SessionMergeResult(
          success: false,
          mergedSessionId: '',
          errors: validation.errors,
        );
      }

      // Get all sessions to merge
      final sessions = await _getSessionsById(config.sessionIds);
      if (sessions.length != config.sessionIds.length) {
        return const SessionMergeResult(
          success: false,
          mergedSessionId: '',
          errors: ['Some sessions could not be loaded'],
        );
      }

      // Sort sessions based on merge strategy
      final sortedSessions =
          _sortSessionsForMerge(sessions, config.mergeStrategy);

      // Create merged session
      final mergedSessionId = _uuid.v4();
      final mergedSession = await _createMergedSession(
        mergedSessionId,
        sortedSessions,
        config,
      );

      // Save merged session
      await _databaseService.insertSession(mergedSession);

      // Merge breadcrumbs
      await _mergeBreadcrumbs(mergedSessionId, sortedSessions, config);

      // Merge waypoints if requested
      if (config.preserveWaypoints) {
        await _mergeWaypoints(mergedSessionId, sortedSessions);
      }

      // Merge photos if requested
      if (config.preservePhotos) {
        await _mergePhotos(mergedSessionId, sortedSessions);
      }

      // Calculate merged statistics
      final mergedStats = await _calculateMergedStatistics(sortedSessions);

      // Delete original sessions (optional - could be configurable)
      for (final session in sessions) {
        await _databaseService.deleteSession(session.id);
      }

      return SessionMergeResult(
        success: true,
        mergedSessionId: mergedSessionId,
        originalSessionIds: config.sessionIds,
        warnings: validation.warnings,
        mergedStatistics: mergedStats,
      );
    } catch (e) {
      debugPrint('Error merging sessions: $e');
      return SessionMergeResult(
        success: false,
        mergedSessionId: '',
        errors: ['Failed to merge sessions: $e'],
      );
    }
  }

  /// Split a session into multiple sessions
  Future<SessionSplitResult> splitSession(SessionSplitConfig config) async {
    try {
      // Validate configuration
      final validation = await validateSplitConfig(config);
      if (!validation.isValid) {
        return SessionSplitResult(
          success: false,
          splitSessionIds: const [],
          errors: validation.errors,
        );
      }

      // Get the session to split
      final session = await _databaseService.getSession(config.sessionId);
      if (session == null) {
        return const SessionSplitResult(
          success: false,
          splitSessionIds: [],
          errors: ['Session not found'],
        );
      }

      // Get session breadcrumbs
      final breadcrumbs =
          await _databaseService.getBreadcrumbsForSession(config.sessionId);
      if (breadcrumbs.isEmpty) {
        return const SessionSplitResult(
          success: false,
          splitSessionIds: [],
          errors: ['No breadcrumbs found for session'],
        );
      }

      // Create split segments
      final segments = await _createSplitSegments(session, breadcrumbs, config);

      // Create new sessions for each segment
      final splitSessionIds = <String>[];
      final splitStats = <SplitSessionStatistics>[];

      for (int i = 0; i < segments.length; i++) {
        final segment = segments[i];
        final splitSessionId = _uuid.v4();

        // Create split session
        final splitSession = _createSplitSession(
          splitSessionId,
          session,
          segment,
          i,
          config,
        );

        // Save split session
        await _databaseService.insertSession(splitSession);

        // Save segment breadcrumbs
        await _saveSplitBreadcrumbs(splitSessionId, segment.breadcrumbs);

        // Redistribute waypoints and photos if requested
        if (config.redistributeWaypoints) {
          await _redistributeWaypoints(splitSessionId, session.id, segment);
        }

        if (config.redistributePhotos) {
          await _redistributePhotos(splitSessionId, session.id, segment);
        }

        splitSessionIds.add(splitSessionId);
        splitStats.add(_calculateSplitStatistics(segment, i));
      }

      // Delete original session if not preserving
      if (!config.preserveOriginal) {
        await _databaseService.deleteSession(config.sessionId);
      }

      return SessionSplitResult(
        success: true,
        splitSessionIds: splitSessionIds,
        originalSessionId: config.sessionId,
        warnings: validation.warnings,
        splitStatistics: splitStats,
      );
    } catch (e) {
      debugPrint('Error splitting session: $e');
      return SessionSplitResult(
        success: false,
        splitSessionIds: const [],
        errors: ['Failed to split session: $e'],
      );
    }
  }

  // Helper methods

  Future<List<TrackingSession>> _getSessionsById(
      List<String> sessionIds) async {
    final sessions = <TrackingSession>[];
    for (final id in sessionIds) {
      final session = await _databaseService.getSession(id);
      if (session != null) {
        sessions.add(session);
      }
    }
    return sessions;
  }

  List<Duration> _detectTimeOverlaps(List<TrackingSession> sessions) {
    final overlaps = <Duration>[];
    for (int i = 0; i < sessions.length - 1; i++) {
      for (int j = i + 1; j < sessions.length; j++) {
        final session1 = sessions[i];
        final session2 = sessions[j];

        if (session1.startedAt != null &&
            session1.completedAt != null &&
            session2.startedAt != null &&
            session2.completedAt != null) {
          final overlap = _calculateTimeOverlap(
            session1.startedAt!,
            session1.completedAt!,
            session2.startedAt!,
            session2.completedAt!,
          );

          if (overlap.inSeconds > 0) {
            overlaps.add(overlap);
          }
        }
      }
    }
    return overlaps;
  }

  Duration _calculateTimeOverlap(
      DateTime start1, DateTime end1, DateTime start2, DateTime end2) {
    final overlapStart = start1.isAfter(start2) ? start1 : start2;
    final overlapEnd = end1.isBefore(end2) ? end1 : end2;

    if (overlapStart.isBefore(overlapEnd)) {
      return overlapEnd.difference(overlapStart);
    }
    return Duration.zero;
  }

  List<Duration> _detectLargeGaps(
      List<TrackingSession> sessions, Duration maxGap) {
    final gaps = <Duration>[];
    final sortedSessions = List<TrackingSession>.from(sessions)
      ..sort((a, b) =>
          (a.startedAt ?? a.createdAt).compareTo(b.startedAt ?? b.createdAt));

    for (int i = 0; i < sortedSessions.length - 1; i++) {
      final current = sortedSessions[i];
      final next = sortedSessions[i + 1];

      if (current.completedAt != null && next.startedAt != null) {
        final gap = next.startedAt!.difference(current.completedAt!);
        if (gap > maxGap) {
          gaps.add(gap);
        }
      }
    }
    return gaps;
  }

  List<TrackingSession> _sortSessionsForMerge(
      List<TrackingSession> sessions, SessionMergeStrategy strategy) {
    switch (strategy) {
      case SessionMergeStrategy.chronological:
        return List<TrackingSession>.from(sessions)
          ..sort((a, b) => (a.startedAt ?? a.createdAt)
              .compareTo(b.startedAt ?? b.createdAt));

      case SessionMergeStrategy.geographical:
        // Sort by start location proximity (simplified)
        return List<TrackingSession>.from(sessions)
          ..sort((a, b) {
            if (a.startLocation == null || b.startLocation == null) return 0;
            final distanceA = const Distance()
                .as(LengthUnit.Meter, const LatLng(0, 0), a.startLocation!);
            final distanceB = const Distance()
                .as(LengthUnit.Meter, const LatLng(0, 0), b.startLocation!);
            return distanceA.compareTo(distanceB);
          });

      case SessionMergeStrategy.custom:
        // Return in the order provided
        return sessions;
    }
  }

  Future<TrackingSession> _createMergedSession(String mergedSessionId,
      List<TrackingSession> sessions, SessionMergeConfig config) async {
    final firstSession = sessions.first;
    final lastSession = sessions.last;

    // Calculate combined metrics
    double totalDistance = 0;
    int totalDuration = 0;
    int totalBreadcrumbs = 0;

    for (final session in sessions) {
      totalDistance += session.totalDistance;
      totalDuration += session.totalDuration;
      totalBreadcrumbs += session.breadcrumbCount;
    }

    return TrackingSession(
      id: mergedSessionId,
      name: config.mergedSessionName,
      description: config.mergedSessionDescription ??
          'Merged from ${sessions.length} sessions: ${sessions.map((s) => s.name).join(', ')}',
      status: SessionStatus.completed,
      createdAt: DateTime.now(),
      startedAt: firstSession.startedAt,
      completedAt: lastSession.completedAt,
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      breadcrumbCount: totalBreadcrumbs,
      accuracyThreshold: firstSession.accuracyThreshold,
      recordingInterval: firstSession.recordingInterval,
      startLocation: firstSession.startLocation,
      endLocation: lastSession.endLocation,
      minimumSpeed: firstSession.minimumSpeed,
      recordAltitude: firstSession.recordAltitude,
      recordSpeed: firstSession.recordSpeed,
      recordHeading: firstSession.recordHeading,
    );
  }

  Future<void> _mergeBreadcrumbs(String mergedSessionId,
      List<TrackingSession> sessions, SessionMergeConfig config) async {
    final allBreadcrumbs = <Breadcrumb>[];

    for (final session in sessions) {
      final breadcrumbs =
          await _databaseService.getBreadcrumbsForSession(session.id);
      allBreadcrumbs.addAll(breadcrumbs);
    }

    // Sort breadcrumbs chronologically
    allBreadcrumbs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Handle gaps based on configuration
    final processedBreadcrumbs =
        _processGapsInBreadcrumbs(allBreadcrumbs, config);

    // Save merged breadcrumbs
    for (final breadcrumb in processedBreadcrumbs) {
      final mergedBreadcrumb = breadcrumb.copyWith(
        id: _uuid.v4(),
        sessionId: mergedSessionId,
      );
      await _databaseService.insertBreadcrumb(mergedBreadcrumb);
    }
  }

  List<Breadcrumb> _processGapsInBreadcrumbs(
      List<Breadcrumb> breadcrumbs, SessionMergeConfig config) {
    switch (config.gapHandling) {
      case GapHandling.preserve:
        return breadcrumbs;

      case GapHandling.interpolate:
        return _interpolateGaps(breadcrumbs, config.maxGapDuration);

      case GapHandling.markGaps:
        return _markGaps(breadcrumbs, config.maxGapDuration);

      case GapHandling.removeGaps:
        return _removeGaps(breadcrumbs, config.maxGapDuration);
    }
  }

  List<Breadcrumb> _interpolateGaps(
      List<Breadcrumb> breadcrumbs, Duration maxGap) {
    // Implementation for interpolating gaps between breadcrumbs
    // This is a simplified version - could be more sophisticated
    final result = <Breadcrumb>[];

    for (int i = 0; i < breadcrumbs.length - 1; i++) {
      result.add(breadcrumbs[i]);

      final current = breadcrumbs[i];
      final next = breadcrumbs[i + 1];
      final gap = next.timestamp.difference(current.timestamp);

      if (gap > maxGap) {
        // Add interpolated breadcrumbs
        final interpolated = _createInterpolatedBreadcrumbs(current, next, gap);
        result.addAll(interpolated);
      }
    }

    if (breadcrumbs.isNotEmpty) {
      result.add(breadcrumbs.last);
    }

    return result;
  }

  List<Breadcrumb> _createInterpolatedBreadcrumbs(
      Breadcrumb start, Breadcrumb end, Duration gap) {
    final interpolated = <Breadcrumb>[];

    // Create breadcrumbs every 5 minutes during the gap
    const interval = Duration(minutes: 5);
    final steps = gap.inMilliseconds ~/ interval.inMilliseconds;

    for (int i = 1; i < steps; i++) {
      final ratio = i / steps;
      final timestamp = start.timestamp.add(Duration(
        milliseconds: (gap.inMilliseconds * ratio).round(),
      ));

      final lat = start.coordinates.latitude +
          (end.coordinates.latitude - start.coordinates.latitude) * ratio;
      final lng = start.coordinates.longitude +
          (end.coordinates.longitude - start.coordinates.longitude) * ratio;

      interpolated.add(Breadcrumb(
        id: _uuid.v4(),
        sessionId: start.sessionId,
        coordinates: LatLng(lat, lng),
        timestamp: timestamp,
        accuracy: max(start.accuracy, end.accuracy),
        altitude: start.altitude != null && end.altitude != null
            ? start.altitude! + (end.altitude! - start.altitude!) * ratio
            : null,
        speed: start.speed != null && end.speed != null
            ? start.speed! + (end.speed! - start.speed!) * ratio
            : null,
        heading: start.heading != null && end.heading != null
            ? start.heading! + (end.heading! - start.heading!) * ratio
            : null,
      ));
    }

    return interpolated;
  }

  List<Breadcrumb> _markGaps(List<Breadcrumb> breadcrumbs, Duration maxGap) =>
      // Mark gaps with special breadcrumbs or metadata
      // This is a simplified implementation
      breadcrumbs;

  List<Breadcrumb> _removeGaps(List<Breadcrumb> breadcrumbs, Duration maxGap) =>
      // Remove breadcrumbs that create large gaps
      // This is a simplified implementation
      breadcrumbs;

  Future<void> _mergeWaypoints(
      String mergedSessionId, List<TrackingSession> sessions) async {
    for (final session in sessions) {
      final waypoints =
          await _waypointService.getWaypointsForSession(session.id);
      for (final waypoint in waypoints) {
        final mergedWaypoint = waypoint.copyWith(
          id: _uuid.v4(),
          sessionId: mergedSessionId,
        );
        await _databaseService.insertWaypoint(mergedWaypoint);
      }
    }
  }

  Future<void> _mergePhotos(
      String mergedSessionId, List<TrackingSession> sessions) async {
    // Move photos - simplified implementation
    // This would need proper implementation based on photo storage structure
    debugPrint('Photo merging not yet implemented');
  }

  Future<MergedSessionStatistics> _calculateMergedStatistics(
      List<TrackingSession> sessions) async {
    double totalDistance = 0;
    Duration totalDuration = Duration.zero;
    int totalBreadcrumbs = 0;
    int totalWaypoints = 0;
    int totalPhotos = 0;

    for (final session in sessions) {
      totalDistance += session.totalDistance;
      totalDuration += Duration(milliseconds: session.totalDuration);
      totalBreadcrumbs += session.breadcrumbCount;

      final waypoints =
          await _waypointService.getWaypointsForSession(session.id);
      totalWaypoints += waypoints.length;

      // Count photos (simplified)
      totalPhotos += 0; // Would need to implement photo counting
    }

    return MergedSessionStatistics(
      totalSessions: sessions.length,
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      totalBreadcrumbs: totalBreadcrumbs,
      totalWaypoints: totalWaypoints,
      totalPhotos: totalPhotos,
    );
  }

  // Split-related helper methods

  Future<List<SessionSegment>> _createSplitSegments(TrackingSession session,
      List<Breadcrumb> breadcrumbs, SessionSplitConfig config) async {
    final segments = <SessionSegment>[];
    final sortedPoints = List<SessionSplitPoint>.from(config.splitPoints)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Sort breadcrumbs by timestamp
    breadcrumbs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    DateTime? segmentStart = session.startedAt;
    int breadcrumbIndex = 0;

    for (int i = 0; i <= sortedPoints.length; i++) {
      final segmentEnd = i < sortedPoints.length
          ? sortedPoints[i].timestamp
          : session.completedAt;

      if (segmentStart != null && segmentEnd != null) {
        final segmentBreadcrumbs = <Breadcrumb>[];

        // Collect breadcrumbs for this segment
        while (breadcrumbIndex < breadcrumbs.length &&
            breadcrumbs[breadcrumbIndex].timestamp.isBefore(segmentEnd)) {
          if (breadcrumbs[breadcrumbIndex].timestamp.isAfter(segmentStart) ||
              breadcrumbs[breadcrumbIndex]
                  .timestamp
                  .isAtSameMomentAs(segmentStart)) {
            segmentBreadcrumbs.add(breadcrumbs[breadcrumbIndex]);
          }
          breadcrumbIndex++;
        }

        if (segmentBreadcrumbs.isNotEmpty) {
          segments.add(SessionSegment(
            index: i,
            startTime: segmentStart,
            endTime: segmentEnd,
            breadcrumbs: segmentBreadcrumbs,
            customName:
                i < sortedPoints.length ? sortedPoints[i].customName : null,
          ));
        }

        segmentStart = segmentEnd;
      }
    }

    return segments;
  }

  TrackingSession _createSplitSession(
      String splitSessionId,
      TrackingSession originalSession,
      SessionSegment segment,
      int segmentIndex,
      SessionSplitConfig config) {
    final segmentName = _generateSplitSessionName(
      originalSession.name,
      segmentIndex,
      segment,
      config.namingStrategy,
    );

    // Calculate segment metrics
    final segmentDistance = _calculateSegmentDistance(segment.breadcrumbs);
    final segmentDuration = segment.endTime.difference(segment.startTime);

    return TrackingSession(
      id: splitSessionId,
      name: segmentName,
      description:
          'Split from "${originalSession.name}" - Segment ${segmentIndex + 1}',
      status: SessionStatus.completed,
      createdAt: DateTime.now(),
      startedAt: segment.startTime,
      completedAt: segment.endTime,
      totalDistance: segmentDistance,
      totalDuration: segmentDuration.inMilliseconds,
      breadcrumbCount: segment.breadcrumbs.length,
      accuracyThreshold: originalSession.accuracyThreshold,
      recordingInterval: originalSession.recordingInterval,
      startLocation: segment.breadcrumbs.isNotEmpty
          ? segment.breadcrumbs.first.coordinates
          : null,
      endLocation: segment.breadcrumbs.isNotEmpty
          ? segment.breadcrumbs.last.coordinates
          : null,
      minimumSpeed: originalSession.minimumSpeed,
      recordAltitude: originalSession.recordAltitude,
      recordSpeed: originalSession.recordSpeed,
      recordHeading: originalSession.recordHeading,
    );
  }

  String _generateSplitSessionName(String originalName, int segmentIndex,
      SessionSegment segment, SplitNamingStrategy strategy) {
    switch (strategy) {
      case SplitNamingStrategy.sequential:
        return '$originalName - Part ${segmentIndex + 1}';

      case SplitNamingStrategy.timeBased:
        final hour = segment.startTime.hour;
        String timeOfDay;
        if (hour < 6)
          timeOfDay = 'Night';
        else if (hour < 12)
          timeOfDay = 'Morning';
        else if (hour < 18)
          timeOfDay = 'Afternoon';
        else
          timeOfDay = 'Evening';
        return '$originalName - $timeOfDay';

      case SplitNamingStrategy.custom:
        return segment.customName ??
            '$originalName - Segment ${segmentIndex + 1}';

      case SplitNamingStrategy.activityBased:
        // Simplified activity detection based on speed/movement
        final avgSpeed = _calculateAverageSpeed(segment.breadcrumbs);
        String activity;
        if (avgSpeed < 0.5)
          activity = 'Rest';
        else if (avgSpeed < 2.0)
          activity = 'Walk';
        else if (avgSpeed < 5.0)
          activity = 'Hike';
        else
          activity = 'Travel';
        return '$originalName - $activity';
    }
  }

  double _calculateSegmentDistance(List<Breadcrumb> breadcrumbs) {
    if (breadcrumbs.length < 2) return 0.0;

    double totalDistance = 0.0;
    const distance = Distance();

    for (int i = 1; i < breadcrumbs.length; i++) {
      final prev = breadcrumbs[i - 1];
      final curr = breadcrumbs[i];

      totalDistance += distance.as(
        LengthUnit.Meter,
        prev.coordinates,
        curr.coordinates,
      );
    }

    return totalDistance;
  }

  double _calculateAverageSpeed(List<Breadcrumb> breadcrumbs) {
    if (breadcrumbs.length < 2) return 0.0;

    final speeds =
        breadcrumbs.where((b) => b.speed != null).map((b) => b.speed!).toList();

    if (speeds.isEmpty) return 0.0;

    return speeds.reduce((a, b) => a + b) / speeds.length;
  }

  Future<void> _saveSplitBreadcrumbs(
      String sessionId, List<Breadcrumb> breadcrumbs) async {
    for (final breadcrumb in breadcrumbs) {
      final splitBreadcrumb = breadcrumb.copyWith(
        id: _uuid.v4(),
        sessionId: sessionId,
      );
      await _databaseService.insertBreadcrumb(splitBreadcrumb);
    }
  }

  Future<void> _redistributeWaypoints(String newSessionId,
      String originalSessionId, SessionSegment segment) async {
    final waypoints =
        await _waypointService.getWaypointsForSession(originalSessionId);

    for (final waypoint in waypoints) {
      // Check if waypoint falls within this segment's time range
      if (waypoint.timestamp.isAfter(segment.startTime) &&
          waypoint.timestamp.isBefore(segment.endTime)) {
        final redistributedWaypoint = waypoint.copyWith(
          id: _uuid.v4(),
          sessionId: newSessionId,
        );
        await _databaseService.insertWaypoint(redistributedWaypoint);
      }
    }
  }

  Future<void> _redistributePhotos(String newSessionId,
      String originalSessionId, SessionSegment segment) async {
    // Simplified photo redistribution - would need proper implementation
    // based on photo timestamps and segment time ranges
  }

  SplitSessionStatistics _calculateSplitStatistics(
      SessionSegment segment, int index) {
    final distance = _calculateSegmentDistance(segment.breadcrumbs);
    final duration = segment.endTime.difference(segment.startTime);

    return SplitSessionStatistics(
      segmentIndex: index,
      segmentName: segment.customName ?? 'Segment ${index + 1}',
      startTime: segment.startTime,
      endTime: segment.endTime,
      distance: distance,
      duration: duration,
      breadcrumbCount: segment.breadcrumbs.length,
      waypointCount:
          0, // Would need to calculate based on redistributed waypoints
      photoCount: 0, // Would need to calculate based on redistributed photos
    );
  }
}
