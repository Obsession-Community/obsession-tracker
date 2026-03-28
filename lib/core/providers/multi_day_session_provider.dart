import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/multi_day_session.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/core/services/session_persistence_service.dart';
import 'package:obsession_tracker/core/services/trail_planning_service.dart';

/// State for multi-day session management
@immutable
class MultiDaySessionState {
  const MultiDaySessionState({
    this.activeMultiDaySession,
    this.currentDaySession,
    this.isMultiDayMode = false,
    this.autoResumeScheduled = false,
    this.batteryOptimizationActive = false,
    this.errorMessage,
  });

  final MultiDaySession? activeMultiDaySession;
  final TrackingSession? currentDaySession;
  final bool isMultiDayMode;
  final bool autoResumeScheduled;
  final bool batteryOptimizationActive;
  final String? errorMessage;

  MultiDaySessionState copyWith({
    MultiDaySession? activeMultiDaySession,
    TrackingSession? currentDaySession,
    bool? isMultiDayMode,
    bool? autoResumeScheduled,
    bool? batteryOptimizationActive,
    String? errorMessage,
    bool clearActiveSession = false,
    bool clearCurrentDaySession = false,
  }) =>
      MultiDaySessionState(
        activeMultiDaySession: clearActiveSession
            ? null
            : (activeMultiDaySession ?? this.activeMultiDaySession),
        currentDaySession: clearCurrentDaySession
            ? null
            : (currentDaySession ?? this.currentDaySession),
        isMultiDayMode: isMultiDayMode ?? this.isMultiDayMode,
        autoResumeScheduled: autoResumeScheduled ?? this.autoResumeScheduled,
        batteryOptimizationActive:
            batteryOptimizationActive ?? this.batteryOptimizationActive,
        errorMessage: errorMessage,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultiDaySessionState &&
          runtimeType == other.runtimeType &&
          activeMultiDaySession == other.activeMultiDaySession &&
          currentDaySession == other.currentDaySession &&
          isMultiDayMode == other.isMultiDayMode &&
          autoResumeScheduled == other.autoResumeScheduled &&
          batteryOptimizationActive == other.batteryOptimizationActive &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      activeMultiDaySession.hashCode ^
      currentDaySession.hashCode ^
      isMultiDayMode.hashCode ^
      autoResumeScheduled.hashCode ^
      batteryOptimizationActive.hashCode ^
      errorMessage.hashCode;
}

/// Notifier for managing multi-day session state and operations
class MultiDaySessionNotifier extends Notifier<MultiDaySessionState> {
  late final SessionPersistenceService _persistenceService;
  late final TrailPlanningService _trailPlanningService;

  Timer? _autoResumeTimer;
  Timer? _autoPauseTimer;
  Timer? _batteryCheckTimer;

  @override
  MultiDaySessionState build() {
    _persistenceService = SessionPersistenceService.instance;
    _trailPlanningService = TrailPlanningService.instance;

    ref.onDispose(() {
      _autoResumeTimer?.cancel();
      _autoPauseTimer?.cancel();
      _batteryCheckTimer?.cancel();
    });

    _initialize();
    return const MultiDaySessionState();
  }

  /// Initialize the multi-day session provider
  Future<void> _initialize() async {
    try {
      await _persistenceService.initialize();
      await _trailPlanningService.initialize();

      // Check for recoverable multi-day session
      final recovery = await _persistenceService.recoverSessionState();
      if (recovery.success && recovery.multiDaySession != null) {
        state = state.copyWith(
          activeMultiDaySession: recovery.multiDaySession,
          isMultiDayMode: true,
        );

        // Resume if it was active
        if (recovery.multiDaySession!.isActive) {
          await _resumeMultiDaySession();
        }
      }
    } catch (e) {
      debugPrint('Error initializing MultiDaySessionNotifier: $e');
      state = state.copyWith(errorMessage: 'Failed to initialize: $e');
    }
  }

  /// Start a new multi-day session
  Future<bool> startMultiDaySession({
    required String name,
    String? description,
    PlannedRoute? plannedRoute,
    int maxDaysAllowed = 30,
    bool autoResumeEnabled = true,
    TimeOfDay? autoResumeTime,
    TimeOfDay? autoPauseTime,
    bool batteryOptimizationEnabled = true,
    int lowBatteryThreshold = 15,
    List<String> tags = const <String>[],
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    try {
      // Create multi-day session
      final String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final multiDaySession = MultiDaySession.create(
        id: sessionId,
        name: name,
        description: description,
        maxDaysAllowed: maxDaysAllowed,
        autoResumeEnabled: autoResumeEnabled,
        autoResumeTime: autoResumeTime,
        autoPauseTime: autoPauseTime,
        batteryOptimizationEnabled: batteryOptimizationEnabled,
        lowBatteryThreshold: lowBatteryThreshold,
        tags: tags,
        metadata: metadata,
      ).copyWith(
        plannedRoute: plannedRoute,
        startedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      // Start trail planning if route is provided
      if (plannedRoute != null) {
        await _trailPlanningService.startNavigation(plannedRoute);
      }

      // Start first day session
      final locationNotifier = ref.read(locationProvider.notifier);
      final success = await locationNotifier.startTracking(
        sessionName: '$name - Day 1',
        description: 'Day 1 of multi-day expedition: $name',
      );

      if (!success) {
        state = state.copyWith(errorMessage: 'Failed to start tracking');
        return false;
      }

      // Get the created session
      final locationState = ref.read(locationProvider);
      final daySession = locationState.activeSession;

      if (daySession != null) {
        // Update multi-day session with day session
        final updatedMultiDaySession = multiDaySession.copyWith(
          currentDaySessionId: daySession.id,
          dailySessions: [daySession.id],
        );

        state = state.copyWith(
          activeMultiDaySession: updatedMultiDaySession,
          currentDaySession: daySession,
          isMultiDayMode: true,
        );

        // Save to database and persistence
        await _saveMultiDaySession(updatedMultiDaySession);
        await _persistenceService.persistSessionState(
          activeSession: daySession,
          multiDaySession: updatedMultiDaySession,
        );

        // Schedule auto-resume/pause if enabled
        _scheduleAutoOperations(updatedMultiDaySession);

        // Start battery monitoring if enabled
        if (batteryOptimizationEnabled) {
          _startBatteryMonitoring(lowBatteryThreshold);
        }

        return true;
      }

      state = state.copyWith(errorMessage: 'Failed to create day session');
      return false;
    } catch (e) {
      debugPrint('Error starting multi-day session: $e');
      state = state.copyWith(errorMessage: 'Error starting session: $e');
      return false;
    }
  }

  /// Pause multi-day session for the day
  Future<void> pauseForDay() async {
    final multiDaySession = state.activeMultiDaySession;
    if (multiDaySession == null) return;

    try {
      // Pause current tracking
      final locationNotifier = ref.read(locationProvider.notifier);
      await locationNotifier.pauseTracking();

      // Update multi-day session status
      final updatedSession = multiDaySession.copyWith(
        status: MultiDaySessionStatus.pausedForDay,
        lastActiveAt: DateTime.now(),
      );

      state = state.copyWith(
        activeMultiDaySession: updatedSession,
      );

      await _saveMultiDaySession(updatedSession);
      await _persistenceService.persistSessionState(
        multiDaySession: updatedSession,
      );

      debugPrint('Multi-day session paused for day');
    } catch (e) {
      debugPrint('Error pausing multi-day session for day: $e');
      state = state.copyWith(errorMessage: 'Error pausing session: $e');
    }
  }

  /// Resume multi-day session (start new day or resume current day)
  Future<bool> resumeMultiDaySession() async {
    final multiDaySession = state.activeMultiDaySession;
    if (multiDaySession == null || !multiDaySession.canResume) return false;

    try {
      return await _resumeMultiDaySession();
    } catch (e) {
      debugPrint('Error resuming multi-day session: $e');
      state = state.copyWith(errorMessage: 'Error resuming session: $e');
      return false;
    }
  }

  /// Start a new day in the multi-day session
  Future<bool> startNewDay() async {
    final multiDaySession = state.activeMultiDaySession;
    if (multiDaySession == null) return false;

    try {
      // Check if we've reached max days
      if (multiDaySession.hasReachedMaxDays) {
        state = state.copyWith(
          errorMessage:
              'Maximum days (${multiDaySession.maxDaysAllowed}) reached',
        );
        return false;
      }

      // Stop current day session if active
      final locationNotifier = ref.read(locationProvider.notifier);
      await locationNotifier.stopTracking();

      // Start new day session
      final newDayNumber = multiDaySession.dayCount + 1;
      final success = await locationNotifier.startTracking(
        sessionName: '${multiDaySession.name} - Day $newDayNumber',
        description:
            'Day $newDayNumber of multi-day expedition: ${multiDaySession.name}',
      );

      if (!success) {
        state = state.copyWith(errorMessage: 'Failed to start new day');
        return false;
      }

      // Get the new day session
      final locationState = ref.read(locationProvider);
      final newDaySession = locationState.activeSession;

      if (newDaySession != null) {
        // Update multi-day session
        final updatedSession = multiDaySession.copyWith(
          status: MultiDaySessionStatus.active,
          dayCount: newDayNumber,
          currentDaySessionId: newDaySession.id,
          dailySessions: [...multiDaySession.dailySessions, newDaySession.id],
          lastActiveAt: DateTime.now(),
        );

        state = state.copyWith(
          activeMultiDaySession: updatedSession,
          currentDaySession: newDaySession,
        );

        await _saveMultiDaySession(updatedSession);
        await _persistenceService.persistSessionState(
          activeSession: newDaySession,
          multiDaySession: updatedSession,
        );

        debugPrint('Started new day $newDayNumber for multi-day session');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error starting new day: $e');
      state = state.copyWith(errorMessage: 'Error starting new day: $e');
      return false;
    }
  }

  /// Complete the multi-day session
  Future<void> completeMultiDaySession() async {
    final multiDaySession = state.activeMultiDaySession;
    if (multiDaySession == null) return;

    try {
      // Stop current tracking
      final locationNotifier = ref.read(locationProvider.notifier);
      await locationNotifier.stopTracking();

      // Stop trail planning if active
      await _trailPlanningService.stopNavigation();

      // Calculate final statistics
      final finalStats = await _calculateFinalStatistics(multiDaySession);

      // Update multi-day session
      final completedSession = multiDaySession.copyWith(
        status: MultiDaySessionStatus.completed,
        completedAt: DateTime.now(),
        totalDistance: finalStats.totalDistance,
        totalDuration: finalStats.totalDuration,
        activeDuration: finalStats.activeDuration,
        breadcrumbCount: finalStats.breadcrumbCount,
        waypointCount: finalStats.waypointCount,
        clearCurrentDaySessionId: true,
      );

      state = state.copyWith(
        activeMultiDaySession: completedSession,
        isMultiDayMode: false,
        clearCurrentDaySession: true,
      );

      await _saveMultiDaySession(completedSession);
      await _persistenceService.clearPersistedData();

      // Cancel timers
      _cancelAllTimers();

      debugPrint('Multi-day session completed: ${completedSession.name}');
    } catch (e) {
      debugPrint('Error completing multi-day session: $e');
      state = state.copyWith(errorMessage: 'Error completing session: $e');
    }
  }

  /// Cancel the multi-day session
  Future<void> cancelMultiDaySession() async {
    final multiDaySession = state.activeMultiDaySession;
    if (multiDaySession == null) return;

    try {
      // Stop current tracking
      final locationNotifier = ref.read(locationProvider.notifier);
      await locationNotifier.stopTracking();

      // Stop trail planning if active
      await _trailPlanningService.stopNavigation();

      // Update multi-day session
      final cancelledSession = multiDaySession.copyWith(
        status: MultiDaySessionStatus.cancelled,
        completedAt: DateTime.now(),
        clearCurrentDaySessionId: true,
      );

      state = state.copyWith(
        activeMultiDaySession: cancelledSession,
        isMultiDayMode: false,
        clearCurrentDaySession: true,
      );

      await _saveMultiDaySession(cancelledSession);
      await _persistenceService.clearPersistedData();

      // Cancel timers
      _cancelAllTimers();

      debugPrint('Multi-day session cancelled: ${cancelledSession.name}');
    } catch (e) {
      debugPrint('Error cancelling multi-day session: $e');
      state = state.copyWith(errorMessage: 'Error cancelling session: $e');
    }
  }

  /// Resume multi-day session implementation
  Future<bool> _resumeMultiDaySession() async {
    final multiDaySession = state.activeMultiDaySession!;

    // Check if we need to start a new day or resume current day
    final bool shouldStartNewDay =
        multiDaySession.status == MultiDaySessionStatus.pausedForDay;

    if (shouldStartNewDay) {
      return startNewDay();
    } else {
      // Resume current day
      final locationNotifier = ref.read(locationProvider.notifier);
      final success = await locationNotifier.resumeTracking();

      if (success) {
        final updatedSession = multiDaySession.copyWith(
          status: MultiDaySessionStatus.active,
          lastActiveAt: DateTime.now(),
        );

        state = state.copyWith(activeMultiDaySession: updatedSession);
        await _saveMultiDaySession(updatedSession);

        return true;
      }

      return false;
    }
  }

  /// Schedule auto-resume and auto-pause operations
  void _scheduleAutoOperations(MultiDaySession session) {
    _cancelAllTimers();

    if (!session.autoResumeEnabled) return;

    // Schedule auto-resume
    if (session.autoResumeTime != null) {
      _scheduleAutoResume(session.autoResumeTime!);
    }

    // Schedule auto-pause
    if (session.autoPauseTime != null) {
      _scheduleAutoPause(session.autoPauseTime!);
    }
  }

  /// Schedule auto-resume timer
  void _scheduleAutoResume(TimeOfDay resumeTime) {
    final now = DateTime.now();
    final resumeDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      resumeTime.hour,
      resumeTime.minute,
    );

    // If the time has passed today, schedule for tomorrow
    final targetTime = resumeDateTime.isBefore(now)
        ? resumeDateTime.add(const Duration(days: 1))
        : resumeDateTime;

    final duration = targetTime.difference(now);

    _autoResumeTimer = Timer(duration, () async {
      if (state.activeMultiDaySession?.canResume == true) {
        await resumeMultiDaySession();
      }

      // Reschedule for next day
      _scheduleAutoResume(resumeTime);
    });

    state = state.copyWith(autoResumeScheduled: true);
    debugPrint('Auto-resume scheduled for: $targetTime');
  }

  /// Schedule auto-pause timer
  void _scheduleAutoPause(TimeOfDay pauseTime) {
    final now = DateTime.now();
    final pauseDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      pauseTime.hour,
      pauseTime.minute,
    );

    // If the time has passed today, schedule for tomorrow
    final targetTime = pauseDateTime.isBefore(now)
        ? pauseDateTime.add(const Duration(days: 1))
        : pauseDateTime;

    final duration = targetTime.difference(now);

    _autoPauseTimer = Timer(duration, () async {
      if (state.activeMultiDaySession?.isActive == true) {
        await pauseForDay();
      }

      // Reschedule for next day
      _scheduleAutoPause(pauseTime);
    });

    debugPrint('Auto-pause scheduled for: $targetTime');
  }

  /// Start battery monitoring
  void _startBatteryMonitoring(int threshold) {
    _batteryCheckTimer =
        Timer.periodic(const Duration(minutes: 5), (timer) async {
      // In a real implementation, you'd check actual battery level
      // For now, this is a placeholder
      const batteryLevel = 50; // await Battery().batteryLevel;

      if (batteryLevel <= threshold &&
          state.activeMultiDaySession?.isActive == true) {
        debugPrint('Low battery detected ($batteryLevel%), suspending session');

        final updatedSession = state.activeMultiDaySession!.copyWith(
          status: MultiDaySessionStatus.suspended,
        );

        state = state.copyWith(
          activeMultiDaySession: updatedSession,
          batteryOptimizationActive: true,
        );

        // Pause tracking to save battery
        final locationNotifier = ref.read(locationProvider.notifier);
        await locationNotifier.pauseTracking();
      }
    });
  }

  /// Cancel all timers
  void _cancelAllTimers() {
    _autoResumeTimer?.cancel();
    _autoPauseTimer?.cancel();
    _batteryCheckTimer?.cancel();

    state = state.copyWith(
      autoResumeScheduled: false,
      batteryOptimizationActive: false,
    );
  }

  /// Save multi-day session to database
  Future<void> _saveMultiDaySession(MultiDaySession session) async {
    try {
      // In a real implementation, you'd save to database
      // await _databaseService.insertMultiDaySession(session);
      debugPrint('Multi-day session saved: ${session.id}');
    } catch (e) {
      debugPrint('Error saving multi-day session: $e');
    }
  }

  /// Calculate final statistics for completed session
  Future<SessionStatistics> _calculateFinalStatistics(
          MultiDaySession session) async =>
      // In a real implementation, you'd aggregate data from all daily sessions
      // For now, return placeholder data
      const SessionStatistics(
        totalDistance: 0.0,
        totalDuration: 0,
        activeDuration: 0,
        breadcrumbCount: 0,
        waypointCount: 0,
      );
}

/// Statistics for a completed multi-day session
@immutable
class SessionStatistics {
  const SessionStatistics({
    required this.totalDistance,
    required this.totalDuration,
    required this.activeDuration,
    required this.breadcrumbCount,
    required this.waypointCount,
  });

  final double totalDistance;
  final int totalDuration;
  final int activeDuration;
  final int breadcrumbCount;
  final int waypointCount;
}

/// Provider for multi-day session management
final NotifierProvider<MultiDaySessionNotifier, MultiDaySessionState>
    multiDaySessionProvider =
    NotifierProvider<MultiDaySessionNotifier, MultiDaySessionState>(
  MultiDaySessionNotifier.new,
);

/// Convenience providers
final Provider<MultiDaySession?> activeMultiDaySessionProvider =
    Provider<MultiDaySession?>(
  (ref) => ref.watch(multiDaySessionProvider).activeMultiDaySession,
);

final Provider<bool> isMultiDayModeProvider = Provider<bool>(
  (ref) => ref.watch(multiDaySessionProvider).isMultiDayMode,
);

final Provider<TrackingSession?> currentDaySessionProvider =
    Provider<TrackingSession?>(
  (ref) => ref.watch(multiDaySessionProvider).currentDaySession,
);
