import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/session_statistics.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/location_service.dart';
import 'package:obsession_tracker/core/services/statistics_service.dart';

/// Provider for managing session statistics state
///
/// Integrates with location and statistics services to provide
/// real-time statistics updates with proper state management.
class StatisticsProvider extends ChangeNotifier {
  StatisticsProvider() {
    _statisticsService = StatisticsService.instance;
    _locationService = LocationService();

    // Listen to statistics updates
    _statisticsSubscription = _statisticsService.statisticsStream.listen(
      _onStatisticsUpdate,
      onError: _onStatisticsError,
    );
  }

  late final StatisticsService _statisticsService;
  late final LocationService _locationService;
  StreamSubscription<SessionStatistics>? _statisticsSubscription;
  StreamSubscription<EnhancedLocationData>? _locationSubscription;

  // State
  SessionStatistics? _currentStatistics;
  String? _activeSessionId;
  UnitSystem _unitSystem = UnitSystem.metric;
  bool _isTracking = false;
  String? _error;
  bool _isDisposed = false;

  // Statistics display configuration
  final Set<String> _visibleMetrics = <String>{
    'distance',
    'duration',
    'speed',
    'altitude',
    'waypoints',
  };

  /// Current session statistics
  SessionStatistics? get currentStatistics => _currentStatistics;

  /// Active session ID
  String? get activeSessionId => _activeSessionId;

  /// Current unit system
  UnitSystem get unitSystem => _unitSystem;

  /// Whether statistics tracking is active
  bool get isTracking => _isTracking;

  /// Current error message
  String? get error => _error;

  /// Visible metrics configuration
  Set<String> get visibleMetrics => Set<String>.from(_visibleMetrics);

  /// Start statistics tracking for a session
  Future<void> startTracking(String sessionId) async {
    try {
      debugPrint(
          'StatisticsProvider: Starting tracking for session $sessionId');

      _activeSessionId = sessionId;
      _isTracking = true;
      _error = null;
      _currentStatistics = null;

      // Start statistics service
      _statisticsService.startSession(sessionId, DateTime.now());

      // Start listening to location updates
      await _startLocationTracking();

      notifyListeners();
    } on Exception catch (e) {
      _error = 'Failed to start statistics tracking: $e';
      _isTracking = false;
      debugPrint('StatisticsProvider: Error starting tracking: $e');
      notifyListeners();
    }
  }

  /// Stop statistics tracking
  Future<void> stopTracking() async {
    try {
      debugPrint('StatisticsProvider: Stopping tracking');

      if (_activeSessionId != null) {
        _statisticsService.stopSession(_activeSessionId!);
      }

      await _locationSubscription?.cancel();
      _locationSubscription = null;

      _activeSessionId = null;
      _isTracking = false;
      _error = null;

      notifyListeners();
    } on Exception catch (e) {
      _error = 'Failed to stop statistics tracking: $e';
      debugPrint('StatisticsProvider: Error stopping tracking: $e');
      notifyListeners();
    }
  }

  /// Update statistics with new waypoint
  void addWaypoint(Waypoint waypoint) {
    if (_activeSessionId != null && _activeSessionId == waypoint.sessionId) {
      _statisticsService.updateWaypoint(_activeSessionId!, waypoint);
    }
  }

  /// Reset segment distance
  void resetSegmentDistance() {
    if (_activeSessionId != null) {
      _statisticsService.resetSegmentDistance(_activeSessionId!);
    }
  }

  /// Set unit system
  void setUnitSystem(UnitSystem units) {
    if (_unitSystem != units) {
      _unitSystem = units;
      notifyListeners();
    }
  }

  /// Toggle metric visibility
  void toggleMetricVisibility(String metric) {
    if (_visibleMetrics.contains(metric)) {
      _visibleMetrics.remove(metric);
    } else {
      _visibleMetrics.add(metric);
    }
    notifyListeners();
  }

  /// Set metric visibility
  void setMetricVisibility(String metric, {required bool visible}) {
    if (visible) {
      _visibleMetrics.add(metric);
    } else {
      _visibleMetrics.remove(metric);
    }
    notifyListeners();
  }

  /// Check if metric is visible
  bool isMetricVisible(String metric) => _visibleMetrics.contains(metric);

  /// Get formatted distance
  String get formattedDistance =>
      _currentStatistics?.formatDistance(_unitSystem) ?? '0 m';

  /// Get formatted current speed
  String get formattedCurrentSpeed =>
      _currentStatistics?.formatCurrentSpeed(_unitSystem) ?? '0 km/h';

  /// Get formatted average speed
  String get formattedAverageSpeed =>
      _currentStatistics?.formatAverageSpeed(_unitSystem) ?? '0 km/h';

  /// Get formatted moving average speed
  String get formattedMovingAverageSpeed =>
      _currentStatistics?.formatMovingAverageSpeed(_unitSystem) ?? '0 km/h';

  /// Get formatted max speed
  String get formattedMaxSpeed =>
      _currentStatistics?.formatMaxSpeed(_unitSystem) ?? '0 km/h';

  /// Get formatted current altitude
  String get formattedCurrentAltitude =>
      _currentStatistics?.formatCurrentAltitude(_unitSystem) ?? 'N/A';

  /// Get formatted elevation gain
  String get formattedElevationGain =>
      _currentStatistics?.formatElevationGain(_unitSystem) ?? '0 m';

  /// Get formatted elevation loss
  String get formattedElevationLoss =>
      _currentStatistics?.formatElevationLoss(_unitSystem) ?? '0 m';

  /// Get formatted net elevation change
  String get formattedNetElevationChange =>
      _currentStatistics?.formatNetElevationChange(_unitSystem) ?? '0 m';

  /// Get formatted total duration
  String get formattedTotalDuration =>
      _currentStatistics?.formattedTotalDuration ?? '00:00';

  /// Get formatted moving duration
  String get formattedMovingDuration =>
      _currentStatistics?.formattedMovingDuration ?? '00:00';

  /// Get formatted heading
  String get formattedHeading => _currentStatistics?.formatHeading() ?? 'N/A';

  /// Get waypoint count
  int get waypointCount => _currentStatistics?.waypointCount ?? 0;

  /// Get waypoint density
  String get formattedWaypointDensity {
    final double? density = _currentStatistics?.waypointDensity;
    if (density == null || density == 0) {
      return '0/km';
    }
    return '${density.toStringAsFixed(1)}/km';
  }

  /// Get accuracy information
  String get formattedAccuracy =>
      _currentStatistics?.formattedLastAccuracy ?? 'N/A';

  /// Get good accuracy percentage
  String get formattedAccuracyPercentage {
    final double? percentage = _currentStatistics?.goodAccuracyPercentage;
    if (percentage == null) {
      return '0%';
    }
    return '${percentage.toStringAsFixed(0)}%';
  }

  /// Start location tracking
  Future<void> _startLocationTracking() async {
    if (_activeSessionId == null) {
      return;
    }

    try {
      _locationSubscription =
          _locationService.getEnhancedLocationStream().listen(
        (EnhancedLocationData location) {
          if (_activeSessionId != null) {
            _statisticsService.updateLocation(_activeSessionId!, location);
          }
        },
        onError: (Object error) {
          if (_isDisposed) return;
          _error = 'Location tracking error: $error';
          debugPrint('StatisticsProvider: Location error: $error');
          notifyListeners();
        },
      );
    } on Exception catch (e) {
      if (_isDisposed) return;
      _error = 'Failed to start location tracking: $e';
      debugPrint('StatisticsProvider: Location tracking error: $e');
      notifyListeners();
    }
  }

  /// Handle statistics updates
  void _onStatisticsUpdate(SessionStatistics statistics) {
    if (_isDisposed) return;
    if (statistics.sessionId == _activeSessionId) {
      _currentStatistics = statistics;
      _error = null;
      notifyListeners();
    }
  }

  /// Handle statistics errors
  void _onStatisticsError(Object error) {
    if (_isDisposed) return;
    _error = 'Statistics error: $error';
    debugPrint('StatisticsProvider: Statistics error: $error');
    notifyListeners();
  }

  /// Get debug information
  Map<String, dynamic>? getDebugInfo() {
    if (_activeSessionId == null) {
      return null;
    }

    return <String, dynamic>{
      'activeSessionId': _activeSessionId,
      'isTracking': _isTracking,
      'hasStatistics': _currentStatistics != null,
      'unitSystem': _unitSystem.name,
      'visibleMetrics': _visibleMetrics.toList(),
      'error': _error,
      'serviceDebugInfo':
          _statisticsService.getSessionDebugInfo(_activeSessionId!),
    };
  }

  @override
  void dispose() {
    _isDisposed = true;
    _statisticsSubscription?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }
}
