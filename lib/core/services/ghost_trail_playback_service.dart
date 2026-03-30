import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/waypoint_service.dart';

/// Playback state for ghost trail animation
enum PlaybackState {
  stopped,
  playing,
  paused,
  loading,
  completed,
}

/// Playback speed options
enum PlaybackSpeed {
  quarter(0.25, '0.25x'),
  half(0.5, '0.5x'),
  normal(1.0, '1x'),
  double(2.0, '2x'),
  quadruple(4.0, '4x'),
  octuple(8.0, '8x');

  const PlaybackSpeed(this.multiplier, this.displayName);

  final num multiplier;
  final String displayName;
}

/// Current playback position and state
@immutable
class PlaybackPosition {
  const PlaybackPosition({
    required this.currentIndex,
    required this.progress,
    required this.currentLocation,
    required this.elapsedTime,
    required this.totalTime,
    required this.currentBreadcrumb,
    this.nextBreadcrumb,
    this.interpolatedPosition,
  });

  /// Current breadcrumb index
  final int currentIndex;

  /// Progress through the trail (0.0 to 1.0)
  final double progress;

  /// Current location on the trail
  final LatLng currentLocation;

  /// Elapsed playback time
  final Duration elapsedTime;

  /// Total trail duration
  final Duration totalTime;

  /// Current breadcrumb
  final Breadcrumb currentBreadcrumb;

  /// Next breadcrumb (for interpolation)
  final Breadcrumb? nextBreadcrumb;

  /// Interpolated position between breadcrumbs
  final LatLng? interpolatedPosition;

  PlaybackPosition copyWith({
    int? currentIndex,
    double? progress,
    LatLng? currentLocation,
    Duration? elapsedTime,
    Duration? totalTime,
    Breadcrumb? currentBreadcrumb,
    Breadcrumb? nextBreadcrumb,
    LatLng? interpolatedPosition,
  }) =>
      PlaybackPosition(
        currentIndex: currentIndex ?? this.currentIndex,
        progress: progress ?? this.progress,
        currentLocation: currentLocation ?? this.currentLocation,
        elapsedTime: elapsedTime ?? this.elapsedTime,
        totalTime: totalTime ?? this.totalTime,
        currentBreadcrumb: currentBreadcrumb ?? this.currentBreadcrumb,
        nextBreadcrumb: nextBreadcrumb ?? this.nextBreadcrumb,
        interpolatedPosition: interpolatedPosition ?? this.interpolatedPosition,
      );
}

/// Ghost trail segment for rendering
@immutable
class GhostTrailSegment {
  const GhostTrailSegment({
    required this.points,
    required this.opacity,
    required this.color,
    required this.strokeWidth,
    required this.isActive,
  });

  final List<LatLng> points;
  final double opacity;
  final int color;
  final double strokeWidth;
  final bool isActive;
}

/// Service for ghost trail playback with animated route replay
class GhostTrailPlaybackService {
  factory GhostTrailPlaybackService() =>
      _instance ??= GhostTrailPlaybackService._();
  GhostTrailPlaybackService._();
  static GhostTrailPlaybackService? _instance;

  final DatabaseService _databaseService = DatabaseService();
  final WaypointService _waypointService = WaypointService.instance;

  // State management
  PlaybackState _state = PlaybackState.stopped;
  PlaybackSpeed _speed = PlaybackSpeed.normal;
  TrackingSession? _currentSession;
  List<Breadcrumb> _breadcrumbs = [];
  List<Waypoint> _waypoints = [];
  PlaybackPosition? _currentPosition;

  // Animation control
  Timer? _playbackTimer;
  DateTime? _playbackStartTime;

  // Stream controllers
  final StreamController<PlaybackState> _stateController =
      StreamController<PlaybackState>.broadcast();
  final StreamController<PlaybackPosition> _positionController =
      StreamController<PlaybackPosition>.broadcast();
  final StreamController<List<GhostTrailSegment>> _trailController =
      StreamController<List<GhostTrailSegment>>.broadcast();

  // Configuration
  static const Duration _updateInterval = Duration(milliseconds: 50); // 20 FPS
  static const int _maxTrailSegments = 50;

  // Getters
  PlaybackState get state => _state;
  PlaybackSpeed get speed => _speed;
  TrackingSession? get currentSession => _currentSession;
  PlaybackPosition? get currentPosition => _currentPosition;

  // Streams
  Stream<PlaybackState> get stateStream => _stateController.stream;
  Stream<PlaybackPosition> get positionStream => _positionController.stream;
  Stream<List<GhostTrailSegment>> get trailStream => _trailController.stream;

  /// Load a session for playback
  Future<bool> loadSession(TrackingSession session) async {
    try {
      _setState(PlaybackState.loading);

      _currentSession = session;
      _breadcrumbs =
          await _databaseService.getBreadcrumbsForSession(session.id);
      _waypoints = await _waypointService.getWaypointsForSession(session.id);

      if (_breadcrumbs.isEmpty) {
        debugPrint('No breadcrumbs found for session: ${session.id}');
        _setState(PlaybackState.stopped);
        return false;
      }

      // Sort breadcrumbs by timestamp
      _breadcrumbs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Initialize position
      _currentPosition = PlaybackPosition(
        currentIndex: 0,
        progress: 0.0,
        currentLocation: _breadcrumbs.first.coordinates,
        elapsedTime: Duration.zero,
        totalTime: _calculateTotalDuration(),
        currentBreadcrumb: _breadcrumbs.first,
        nextBreadcrumb: _breadcrumbs.length > 1 ? _breadcrumbs[1] : null,
      );

      _positionController.add(_currentPosition!);
      _updateTrailSegments();
      _setState(PlaybackState.stopped);

      debugPrint(
          'Loaded session for playback: ${session.name} (${_breadcrumbs.length} breadcrumbs)');
      return true;
    } catch (e) {
      debugPrint('Error loading session for playback: $e');
      _setState(PlaybackState.stopped);
      return false;
    }
  }

  /// Start playback
  Future<void> play() async {
    if (_currentSession == null || _breadcrumbs.isEmpty) {
      debugPrint('No session loaded for playback');
      return;
    }

    if (_state == PlaybackState.completed) {
      // Restart from beginning
      await seekToProgress(0.0);
    }

    _playbackStartTime =
        DateTime.now().subtract(_currentPosition?.elapsedTime ?? Duration.zero);

    _playbackTimer = Timer.periodic(_updateInterval, _updatePlayback);
    _setState(PlaybackState.playing);

    debugPrint('Started ghost trail playback at ${_speed.displayName}');
  }

  /// Pause playback
  Future<void> pause() async {
    if (_state != PlaybackState.playing) return;

    _playbackTimer?.cancel();
    _playbackTimer = null;

    if (_playbackStartTime != null && _currentPosition != null) {}

    _setState(PlaybackState.paused);
    debugPrint('Paused ghost trail playback');
  }

  /// Stop playback and reset to beginning
  Future<void> stop() async {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _playbackStartTime = null;

    if (_breadcrumbs.isNotEmpty) {
      await seekToProgress(0.0);
    }

    _setState(PlaybackState.stopped);
    debugPrint('Stopped ghost trail playback');
  }

  /// Seek to specific progress (0.0 to 1.0)
  Future<void> seekToProgress(double progress) async {
    if (_breadcrumbs.isEmpty) return;

    final double clampedProgress = progress.clamp(0.0, 1.0);
    final int targetIndex =
        (clampedProgress * (_breadcrumbs.length - 1)).round();
    final Duration targetTime = Duration(
      milliseconds:
          (clampedProgress * _calculateTotalDuration().inMilliseconds).round(),
    );

    _currentPosition = PlaybackPosition(
      currentIndex: targetIndex,
      progress: progress,
      currentLocation: _breadcrumbs[targetIndex].coordinates,
      elapsedTime: targetTime,
      totalTime: _calculateTotalDuration(),
      currentBreadcrumb: _breadcrumbs[targetIndex],
      nextBreadcrumb: targetIndex < _breadcrumbs.length - 1
          ? _breadcrumbs[targetIndex + 1]
          : null,
    );

    _positionController.add(_currentPosition!);
    _updateTrailSegments();

    // Update playback start time if playing
    if (_state == PlaybackState.playing && _playbackStartTime != null) {
      _playbackStartTime = DateTime.now().subtract(targetTime);
    }

    debugPrint('Seeked to progress: ${(progress * 100).toStringAsFixed(1)}%');
  }

  /// Seek to specific time
  Future<void> seekToTime(Duration time) async {
    if (_breadcrumbs.isEmpty) return;

    final Duration totalDuration = _calculateTotalDuration();
    final double progress = totalDuration.inMilliseconds > 0
        ? (time.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    await seekToProgress(progress);
  }

  /// Set playback speed
  void setSpeed(PlaybackSpeed speed) {
    _speed = speed;

    // Adjust playback timer if playing
    if (_state == PlaybackState.playing &&
        _playbackStartTime != null &&
        _currentPosition != null) {
      _playbackStartTime = DateTime.now().subtract(
        Duration(
            milliseconds: (_currentPosition!.elapsedTime.inMilliseconds /
                    speed.multiplier)
                .round()),
      );
    }

    debugPrint('Set playback speed to: ${speed.displayName}');
  }

  /// Update playback position during animation
  void _updatePlayback(Timer timer) {
    if (_playbackStartTime == null ||
        _currentPosition == null ||
        _breadcrumbs.isEmpty) {
      return;
    }

    final Duration realElapsed = DateTime.now().difference(_playbackStartTime!);
    final Duration scaledElapsed = Duration(
      milliseconds: (realElapsed.inMilliseconds * _speed.multiplier).round(),
    );

    final Duration totalDuration = _calculateTotalDuration();
    if (scaledElapsed >= totalDuration) {
      // Playback completed
      _currentPosition = PlaybackPosition(
        currentIndex: _breadcrumbs.length - 1,
        progress: 1.0,
        currentLocation: _breadcrumbs.last.coordinates,
        elapsedTime: totalDuration,
        totalTime: totalDuration,
        currentBreadcrumb: _breadcrumbs.last,
      );

      _positionController.add(_currentPosition!);
      _updateTrailSegments();

      _playbackTimer?.cancel();
      _playbackTimer = null;
      _setState(PlaybackState.completed);
      return;
    }

    // Find current position based on elapsed time
    final PlaybackPosition newPosition =
        _calculatePositionAtTime(scaledElapsed);
    _currentPosition = newPosition;
    _positionController.add(_currentPosition!);
    _updateTrailSegments();
  }

  /// Calculate position at specific time
  PlaybackPosition _calculatePositionAtTime(Duration elapsedTime) {
    if (_breadcrumbs.isEmpty) {
      return PlaybackPosition(
        currentIndex: 0,
        progress: 0.0,
        currentLocation: const LatLng(0, 0),
        elapsedTime: elapsedTime,
        totalTime: Duration.zero,
        currentBreadcrumb: _breadcrumbs.first,
      );
    }

    final Duration totalDuration = _calculateTotalDuration();
    final double progress = totalDuration.inMilliseconds > 0
        ? (elapsedTime.inMilliseconds / totalDuration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    // Find the appropriate breadcrumb index
    int currentIndex = 0;
    for (int i = 0; i < _breadcrumbs.length - 1; i++) {
      final Duration breadcrumbTime =
          _breadcrumbs[i].timestamp.difference(_breadcrumbs.first.timestamp);
      if (elapsedTime >= breadcrumbTime) {
        currentIndex = i;
      } else {
        break;
      }
    }

    currentIndex = currentIndex.clamp(0, _breadcrumbs.length - 1);
    final Breadcrumb currentBreadcrumb = _breadcrumbs[currentIndex];
    final Breadcrumb? nextBreadcrumb = currentIndex < _breadcrumbs.length - 1
        ? _breadcrumbs[currentIndex + 1]
        : null;

    // Interpolate position if we have a next breadcrumb
    LatLng currentLocation = currentBreadcrumb.coordinates;
    LatLng? interpolatedPosition;

    if (nextBreadcrumb != null) {
      final Duration currentTime =
          currentBreadcrumb.timestamp.difference(_breadcrumbs.first.timestamp);
      final Duration nextTime =
          nextBreadcrumb.timestamp.difference(_breadcrumbs.first.timestamp);
      final Duration segmentDuration = nextTime - currentTime;

      if (segmentDuration.inMilliseconds > 0) {
        final Duration timeInSegment = elapsedTime - currentTime;
        final double segmentProgress =
            (timeInSegment.inMilliseconds / segmentDuration.inMilliseconds)
                .clamp(0.0, 1.0);

        // Interpolate between current and next breadcrumb
        final double lat = currentBreadcrumb.coordinates.latitude +
            (nextBreadcrumb.coordinates.latitude -
                    currentBreadcrumb.coordinates.latitude) *
                segmentProgress;
        final double lng = currentBreadcrumb.coordinates.longitude +
            (nextBreadcrumb.coordinates.longitude -
                    currentBreadcrumb.coordinates.longitude) *
                segmentProgress;

        interpolatedPosition = LatLng(lat, lng);
        currentLocation = interpolatedPosition;
      }
    }

    return PlaybackPosition(
      currentIndex: currentIndex,
      progress: progress,
      currentLocation: currentLocation,
      elapsedTime: elapsedTime,
      totalTime: totalDuration,
      currentBreadcrumb: currentBreadcrumb,
      nextBreadcrumb: nextBreadcrumb,
      interpolatedPosition: interpolatedPosition,
    );
  }

  /// Calculate total duration of the trail
  Duration _calculateTotalDuration() {
    if (_breadcrumbs.length < 2) return Duration.zero;
    return _breadcrumbs.last.timestamp.difference(_breadcrumbs.first.timestamp);
  }

  /// Update trail segments for rendering
  void _updateTrailSegments() {
    if (_breadcrumbs.isEmpty || _currentPosition == null) {
      _trailController.add([]);
      return;
    }

    final List<GhostTrailSegment> segments = <GhostTrailSegment>[];
    final int currentIndex = _currentPosition!.currentIndex;

    // Create segments with fading effect
    const int segmentLength = 10; // Points per segment
    const double maxOpacity = 0.8;
    const double minOpacity = 0.1;

    for (int i = 0; i <= currentIndex; i += segmentLength) {
      final int endIndex = math.min(i + segmentLength, currentIndex + 1);
      if (endIndex <= i) continue;

      final List<LatLng> segmentPoints =
          _breadcrumbs.sublist(i, endIndex).map((b) => b.coordinates).toList();

      // Add interpolated position if this is the current segment
      if (endIndex > currentIndex &&
          _currentPosition!.interpolatedPosition != null) {
        segmentPoints.add(_currentPosition!.interpolatedPosition!);
      }

      // Calculate opacity based on distance from current position
      final double distanceFromCurrent = (currentIndex - i).abs().toDouble();
      final double normalizedDistance =
          (distanceFromCurrent / _maxTrailSegments).clamp(0.0, 1.0);
      final double opacity =
          maxOpacity - (normalizedDistance * (maxOpacity - minOpacity));

      // Determine if this is the active segment
      final bool isActive = i <= currentIndex && endIndex > currentIndex;

      segments.add(GhostTrailSegment(
        points: segmentPoints,
        opacity: opacity,
        color: isActive
            ? 0xFF00FF00
            : 0xFF0066CC, // Green for active, blue for trail
        strokeWidth: isActive ? 4.0 : 2.0,
        isActive: isActive,
      ));
    }

    _trailController.add(segments);
  }

  /// Set playback state
  void _setState(PlaybackState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  /// Get waypoints that should be visible at current position
  List<Waypoint> getVisibleWaypoints() {
    if (_currentPosition == null || _waypoints.isEmpty) return [];

    final Duration currentTime = _currentPosition!.elapsedTime;
    final DateTime sessionStart =
        _breadcrumbs.isNotEmpty ? _breadcrumbs.first.timestamp : DateTime.now();

    return _waypoints.where((waypoint) {
      final Duration waypointTime = waypoint.timestamp.difference(sessionStart);
      return waypointTime <= currentTime;
    }).toList();
  }

  /// Get playback statistics
  Map<String, dynamic> getPlaybackStats() {
    if (_currentSession == null || _currentPosition == null) {
      return <String, dynamic>{};
    }

    return <String, dynamic>{
      'session_name': _currentSession!.name,
      'total_breadcrumbs': _breadcrumbs.length,
      'total_waypoints': _waypoints.length,
      'current_index': _currentPosition!.currentIndex,
      'progress_percent': (_currentPosition!.progress * 100).toStringAsFixed(1),
      'elapsed_time': _formatDuration(_currentPosition!.elapsedTime),
      'total_time': _formatDuration(_currentPosition!.totalTime),
      'playback_speed': _speed.displayName,
      'state': _state.name,
    };
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Dispose of the service
  void dispose() {
    _playbackTimer?.cancel();
    _stateController.close();
    _positionController.close();
    _trailController.close();
    _instance = null;
  }
}
