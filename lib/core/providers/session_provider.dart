import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/lifetime_statistics_service.dart';
import 'package:obsession_tracker/core/services/photo_storage_service.dart';
import 'package:obsession_tracker/core/services/statistics_service.dart';
import 'package:obsession_tracker/core/services/waypoint_service.dart';

/// State notifier for managing session operations
class SessionNotifier extends Notifier<AsyncValue<List<TrackingSession>>> {
  late final DatabaseService _databaseService;
  late final PhotoStorageService _photoStorageService;
  late final WaypointService _waypointService;
  late final StatisticsService _statisticsService;

  @override
  AsyncValue<List<TrackingSession>> build() {
    _databaseService = DatabaseService();
    _photoStorageService = PhotoStorageService();
    _waypointService = WaypointService.instance;
    _statisticsService = StatisticsService.instance;

    // Load sessions asynchronously
    loadSessions();
    return const AsyncValue.loading();
  }

  /// Load all sessions from database
  Future<void> loadSessions() async {
    try {
      debugPrint('DEBUG: SessionNotifier.loadSessions starting...');
      state = const AsyncValue.loading();
      final sessions = await _databaseService.getAllSessions();
      debugPrint(
          'DEBUG: Loaded ${sessions.length} sessions, updating state...');
      state = AsyncValue.data(sessions);
      debugPrint('DEBUG: SessionNotifier state updated successfully');
    } catch (error, stackTrace) {
      debugPrint('DEBUG: Error loading sessions: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Delete a session and all associated data
  /// Returns true if successful, false otherwise
  /// Note: Does not automatically reload sessions to prevent disposed ref issues
  Future<bool> deleteSession(String sessionId) async {
    try {
      debugPrint(
          'DEBUG: SessionNotifier.deleteSession starting for $sessionId');

      // Delete associated data first
      await _waypointService.deleteWaypointsForSession(sessionId);
      await _photoStorageService.deleteSessionPhotos(sessionId);
      // Stop any active statistics tracking for this session
      _statisticsService.stopSession(sessionId);

      // Delete the session itself
      await _databaseService.deleteSession(sessionId);

      debugPrint(
          'DEBUG: Session $sessionId deleted from database successfully');

      // Recalculate lifetime stats from remaining sessions
      // This ensures stats stay accurate after deletion (Option C: Hybrid approach)
      final lifetimeStatsService = LifetimeStatisticsService();
      await lifetimeStatsService.recalculateFromAllSessions();
      debugPrint('DEBUG: Lifetime stats recalculated after session deletion');

      // Don't automatically reload sessions here to prevent disposed ref issues
      // The calling widget should handle reloading if it's still mounted

      debugPrint('DEBUG: Successfully deleted session: $sessionId');
      return true;
    } catch (error) {
      debugPrint('DEBUG: Error deleting session $sessionId: $error');
      return false;
    }
  }

  /// Manually reload sessions after deletion (to be called by UI when still mounted)
  Future<void> reloadAfterDeletion() async {
    debugPrint('DEBUG: Manually reloading sessions after deletion...');
    await loadSessions();
  }

  /// Update session details
  Future<bool> updateSession(TrackingSession session) async {
    try {
      await _databaseService.updateSession(session);
      await loadSessions();
      debugPrint('Successfully updated session: ${session.id}');
      return true;
    } catch (error) {
      debugPrint('Error updating session ${session.id}: $error');
      return false;
    }
  }

  /// Refresh sessions list
  Future<void> refresh() async {
    await loadSessions();
  }
}

/// Provider for session management
final sessionProvider =
    NotifierProvider<SessionNotifier, AsyncValue<List<TrackingSession>>>(
  SessionNotifier.new,
);

/// Provider for getting a specific session by ID
final sessionByIdProvider =
    Provider.family<TrackingSession?, String>((ref, sessionId) {
  final sessionsAsync = ref.watch(sessionProvider);
  return sessionsAsync.maybeWhen(
    data: (sessions) {
      try {
        return sessions.firstWhere((session) => session.id == sessionId);
      } catch (e) {
        return null;
      }
    },
    orElse: () => null,
  );
});
