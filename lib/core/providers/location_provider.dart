import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/providers/settings_provider.dart';
import 'package:obsession_tracker/core/services/achievement_service.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/lifetime_statistics_service.dart';
import 'package:obsession_tracker/core/services/location_service.dart';

/// State for location tracking functionality
@immutable
class LocationState {
  const LocationState({
    this.status = LocationStatus.unknown,
    this.currentPosition,
    this.enhancedLocationData,
    this.activeSession,
    this.currentBreadcrumbs = const <Breadcrumb>[],
    this.errorMessage,
    this.isTracking = false,
    this.useEnhancedTracking = true,
    this.detailedPermission,
    this.hasAlwaysPermission = false,
  });
  final LocationStatus status;
  final Position? currentPosition;
  final EnhancedLocationData? enhancedLocationData;
  final TrackingSession? activeSession;
  final List<Breadcrumb> currentBreadcrumbs;
  final String? errorMessage;
  final bool isTracking;
  final bool useEnhancedTracking;
  final LocationPermission? detailedPermission;
  final bool hasAlwaysPermission;

  LocationState copyWith({
    LocationStatus? status,
    Position? currentPosition,
    EnhancedLocationData? enhancedLocationData,
    TrackingSession? activeSession,
    List<Breadcrumb>? currentBreadcrumbs,
    String? errorMessage,
    bool? isTracking,
    bool? useEnhancedTracking,
    LocationPermission? detailedPermission,
    bool? hasAlwaysPermission,
  }) =>
      LocationState(
        status: status ?? this.status,
        currentPosition: currentPosition ?? this.currentPosition,
        enhancedLocationData: enhancedLocationData ?? this.enhancedLocationData,
        activeSession: activeSession ?? this.activeSession,
        currentBreadcrumbs: currentBreadcrumbs ?? this.currentBreadcrumbs,
        errorMessage: errorMessage,
        isTracking: isTracking ?? this.isTracking,
        useEnhancedTracking: useEnhancedTracking ?? this.useEnhancedTracking,
        detailedPermission: detailedPermission ?? this.detailedPermission,
        hasAlwaysPermission: hasAlwaysPermission ?? this.hasAlwaysPermission,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          currentPosition == other.currentPosition &&
          enhancedLocationData == other.enhancedLocationData &&
          activeSession == other.activeSession &&
          listEquals(currentBreadcrumbs, other.currentBreadcrumbs) &&
          errorMessage == other.errorMessage &&
          isTracking == other.isTracking &&
          useEnhancedTracking == other.useEnhancedTracking &&
          detailedPermission == other.detailedPermission &&
          hasAlwaysPermission == other.hasAlwaysPermission;

  @override
  int get hashCode =>
      status.hashCode ^
      currentPosition.hashCode ^
      enhancedLocationData.hashCode ^
      activeSession.hashCode ^
      currentBreadcrumbs.hashCode ^
      errorMessage.hashCode ^
      isTracking.hashCode ^
      useEnhancedTracking.hashCode ^
      detailedPermission.hashCode ^
      hasAlwaysPermission.hashCode;
}

/// Notifier for managing location tracking state and operations
class LocationNotifier extends Notifier<LocationState> {
  late final LocationService _locationService;
  late final DatabaseService _databaseService;
  late final LifetimeStatisticsService _lifetimeStatsService;
  late final AchievementService _achievementService;
  Timer? _breadcrumbTimer;

  // Flag to prevent race conditions during stop tracking
  bool _isStoppingTracking = false;

  // Flag to prevent state updates after provider is disposed
  // This prevents the "_lifecycleState != _ElementLifecycle.defunct" error
  bool _isDisposed = false;

  // Compass tracking (only active during tracking)
  StreamSubscription<CompassEvent>? _compassSubscription;
  double? _currentHeading;

  /// Safely update state with error handling for disposed widgets.
  ///
  /// Riverpod's notification scheduler is async - even with disposal guards,
  /// notifications queued before disposal may still try to notify defunct widgets.
  /// This wrapper catches those errors gracefully.
  void _safeSetState(LocationState Function() newStateBuilder) {
    if (_isDisposed) return;
    try {
      state = newStateBuilder();
    } catch (e) {
      // Catch "_lifecycleState != _ElementLifecycle.defunct" errors
      // This happens when Riverpod tries to notify a widget that was disposed
      // after the notification was queued but before it was delivered.
      // It's harmless - the widget is already gone, so we just log and continue.
      if (e.toString().contains('defunct')) {
        debugPrint('📍 Ignoring defunct widget notification (widget was disposed during state update)');
      } else {
        // Re-throw other errors
        rethrow;
      }
    }
  }

  @override
  LocationState build() {
    _locationService = LocationService();
    _databaseService = DatabaseService();
    _lifetimeStatsService = LifetimeStatisticsService();
    _achievementService = AchievementService();
    _isDisposed = false; // Reset on rebuild

    // Register cleanup on dispose
    ref.onDispose(() {
      _isDisposed = true; // Set FIRST to prevent any more state updates
      _stopBreadcrumbTimer();
      _locationService.stopLocationTracking();
      _compassSubscription?.cancel();
    });

    _checkInitialLocationStatus();
    return const LocationState();
  }

  /// Start compass for accurate heading data
  void _startCompass() {
    if (_compassSubscription != null) return; // Already started

    debugPrint('📍 Starting compass for tracking');
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      // Guard against updates after disposal
      if (_isDisposed) return;
      if (event.heading != null) {
        _currentHeading = event.heading;
      }
    });
  }

  /// Stop compass to save battery
  void _stopCompass() {
    if (_compassSubscription == null) return; // Already stopped

    debugPrint('📍 Stopping compass');
    _compassSubscription?.cancel();
    _compassSubscription = null;
    _currentHeading = null;
  }

  /// Check initial location permission and service status
  Future<void> _checkInitialLocationStatus() async {
    try {
      final LocationStatus status =
          await _locationService.checkLocationStatus();

      // Also get detailed permission status for background tracking checks
      final LocationPermission detailedPermission =
          await _locationService.getDetailedPermissionStatus();
      final bool hasAlways = await _locationService.hasAlwaysLocationPermission();

      state = state.copyWith(
        status: status,
        detailedPermission: detailedPermission,
        hasAlwaysPermission: hasAlways,
      );

      // If permission is granted, get initial position
      if (status == LocationStatus.granted) {
        await getCurrentPosition();
      }
    } on Exception catch (e) {
      debugPrint('Error checking initial location status: $e');
      state = state.copyWith(
        status: LocationStatus.unknown,
        errorMessage: 'Failed to check location status',
      );
    }
  }

  /// Refresh permission status (call after user returns from Settings)
  Future<void> refreshPermissionStatus() async {
    try {
      final LocationPermission detailedPermission =
          await _locationService.getDetailedPermissionStatus();
      final bool hasAlways = await _locationService.hasAlwaysLocationPermission();

      state = state.copyWith(
        detailedPermission: detailedPermission,
        hasAlwaysPermission: hasAlways,
      );

      debugPrint('Permission status refreshed: ${detailedPermission.name}, always: $hasAlways');
    } on Exception catch (e) {
      debugPrint('Error refreshing permission status: $e');
    }
  }

  /// Request location permissions
  /// For background tracking, this will request "always" permission on iOS
  Future<bool> requestLocationPermission({
    bool requestAlwaysPermission = true,
  }) async {
    try {
      state = state.copyWith(status: LocationStatus.checking);
      final LocationStatus status =
          await _locationService.requestLocationPermission(
        requestAlwaysPermission: requestAlwaysPermission,
      );

      // Also get detailed permission status
      final LocationPermission detailedPermission =
          await _locationService.getDetailedPermissionStatus();
      final bool hasAlways = await _locationService.hasAlwaysLocationPermission();

      state = state.copyWith(
        status: status,
        detailedPermission: detailedPermission,
        hasAlwaysPermission: hasAlways,
      );

      // If permission was granted, automatically get current position
      if (status == LocationStatus.granted) {
        // Use a small delay to ensure GPS is ready after permission grant
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await getCurrentPosition();
      }

      return status == LocationStatus.granted;
    } on LocationServiceException catch (e) {
      state = state.copyWith(
        status: _getLocationStatusFromError(e.type),
        errorMessage: e.message,
      );
      return false;
    } on Exception catch (e) {
      debugPrint('Error requesting location permission: $e');
      state = state.copyWith(
        status: LocationStatus.unknown,
        errorMessage: 'Failed to request location permission',
      );
      return false;
    }
  }

  /// Get current GPS position
  Future<Position?> getCurrentPosition() async {
    try {
      state = state.copyWith();

      if (state.useEnhancedTracking) {
        final EnhancedLocationData enhancedData =
            await _locationService.getCurrentEnhancedPosition();
        state = state.copyWith(
          currentPosition: enhancedData.position,
          enhancedLocationData: enhancedData,
        );
        return enhancedData.position;
      } else {
        final Position position = await _locationService.getCurrentPosition();
        state = state.copyWith(currentPosition: position);
        return position;
      }
    } on LocationServiceException catch (e) {
      state = state.copyWith(
        status: _getLocationStatusFromError(e.type),
        errorMessage: e.message,
      );
      return null;
    } on Exception catch (e) {
      debugPrint('Error getting current position: $e');
      state = state.copyWith(
        errorMessage: 'Failed to get current location',
      );
      return null;
    }
  }

  /// Start a new tracking session
  Future<bool> startTracking({
    required String sessionName,
    String? description,
    double accuracyThreshold = 10.0,
    int recordingInterval = 5,
    double minimumSpeed = 0.0,
    String? plannedRouteId,
    String? plannedRouteSnapshot,
    String? huntId,
    bool recordElevation = true,
    bool recordBearing = true,
    GpsMode? gpsMode,
    bool enableBackgroundTracking = false,
  }) async {
    if (state.isTracking) {
      debugPrint('Already tracking - stopping current session first');
      await stopTracking();
    }

    try {
      // Create new session with user's tracking preferences
      final String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final TrackingSession session = TrackingSession.create(
        id: sessionId,
        name: sessionName,
        description: description,
        accuracyThreshold: accuracyThreshold,
        recordingInterval: recordingInterval,
        minimumSpeed: minimumSpeed,
        plannedRouteId: plannedRouteId,
        plannedRouteSnapshot: plannedRouteSnapshot,
        huntId: huntId,
        recordAltitude: recordElevation,
        recordHeading: recordBearing,
      );

      // Get initial position
      final Position? initialPosition = await getCurrentPosition();
      if (initialPosition == null) {
        state = state.copyWith(
          errorMessage: 'Unable to get initial GPS position',
        );
        return false;
      }

      // Update session with start location and time
      final TrackingSession updatedSession = session.copyWith(
        startedAt: DateTime.now(),
        startLocation:
            LatLng(initialPosition.latitude, initialPosition.longitude),
      );

      // Map GPS mode to LocationAccuracy
      LocationAccuracy locationAccuracy;
      switch (gpsMode) {
        case GpsMode.lowPower:
          locationAccuracy = LocationAccuracy.low;
          break;
        case GpsMode.highAccuracy:
          locationAccuracy = LocationAccuracy.best;
          break;
        case GpsMode.balanced:
        case null:
          locationAccuracy = LocationAccuracy.high;
          break;
      }

      debugPrint('📍 Starting tracking with GPS mode: $gpsMode, accuracy: $locationAccuracy, background: $enableBackgroundTracking');

      // Start location tracking (enhanced or regular based on settings)
      if (state.useEnhancedTracking) {
        await _locationService.startEnhancedLocationTracking(
          onLocationUpdate: _handleEnhancedLocationUpdate,
          onError: _handleLocationError,
          intervalSeconds: recordingInterval,
          accuracy: locationAccuracy,
          enableBackgroundLocation: enableBackgroundTracking,
        );
      } else {
        await _locationService.startLocationTracking(
          onLocationUpdate: _handleLocationUpdate,
          onError: _handleLocationError,
          intervalSeconds: recordingInterval,
          accuracy: locationAccuracy,
          enableBackgroundLocation: enableBackgroundTracking,
        );
      }

      // Start compass for accurate heading data
      _startCompass();

      // Start breadcrumb recording timer
      _startBreadcrumbTimer(recordingInterval);

      // Save session to database
      await _databaseService.insertSession(updatedSession);

      state = state.copyWith(
        isTracking: true,
        activeSession: updatedSession,
        currentBreadcrumbs: <Breadcrumb>[],
      );

      return true;
    } on Exception catch (e) {
      debugPrint('Error starting tracking: $e');
      state = state.copyWith(
        errorMessage: 'Failed to start tracking: $e',
        isTracking: false,
      );
      return false;
    }
  }

  /// Stop the current tracking session
  Future<void> stopTracking() async {
    // CRITICAL: Set the stopping flag FIRST to prevent any more breadcrumbs
    // from being recorded during the shutdown sequence (race condition fix)
    _isStoppingTracking = true;

    try {
      // Capture session data before clearing state
      final TrackingSession? session = state.activeSession;
      final List<Breadcrumb> breadcrumbs = List<Breadcrumb>.from(state.currentBreadcrumbs);
      final Position? currentPos = state.currentPosition;

      // Stop timer and compass immediately (synchronous)
      _stopBreadcrumbTimer();
      _stopCompass();

      // Calculate final session stats BEFORE any async operations
      final double totalDistance = _calculateTotalDistanceFromBreadcrumbs(breadcrumbs);
      final int duration = session?.startedAt != null
          ? DateTime.now().difference(session!.startedAt!).inMilliseconds
          : 0;

      debugPrint('📍 Stopping session - calculated distance: ${totalDistance.toStringAsFixed(1)}m from ${breadcrumbs.length} breadcrumbs');

      // Create completed session with ALL final data
      final TrackingSession? completedSession = session?.copyWith(
        status: SessionStatus.completed,
        completedAt: DateTime.now(),
        totalDistance: totalDistance,
        totalDuration: duration,
        breadcrumbCount: breadcrumbs.length,
        endLocation: currentPos != null
            ? LatLng(currentPos.latitude, currentPos.longitude)
            : null,
      );

      // Update UI state IMMEDIATELY - before any async operations that might hang
      state = state.copyWith(
        isTracking: false,
        activeSession: completedSession,
      );

      debugPrint('📍 UI state updated - session marked as completed');

      // Now stop location service asynchronously (this can hang/timeout)
      // Use unawaited pattern so UI isn't blocked
      _locationService.stopLocationTracking().then((_) {
        debugPrint('📍 Location service stopped');
      }).catchError((Object error) {
        debugPrint('📍 Error stopping location service (non-fatal): $error');
      });

      // Save to database asynchronously (won't block UI)
      if (completedSession != null) {
        _databaseService.updateSession(completedSession).then((_) {
          debugPrint('📍 Session saved to database: ${completedSession.name} - ${completedSession.formattedDistance}');

          // Update lifetime statistics and check achievements (async, non-blocking)
          _updateStatsAndAchievements(completedSession, breadcrumbs);
        }).catchError((Object error) {
          debugPrint('Error saving session to database: $error');
        });
      }

      debugPrint('📍 Tracking stopped successfully');
    } on Exception catch (e) {
      // Handle timeout and other exceptions gracefully during stop tracking
      debugPrint('Error stopping tracking: $e');

      // Always ensure tracking is marked as stopped, even if there were errors
      // This prevents the UI from getting stuck in a "tracking" state
      _stopBreadcrumbTimer();
      _stopCompass();

      // Calculate what we can from breadcrumbs
      final List<Breadcrumb> breadcrumbs = List<Breadcrumb>.from(state.currentBreadcrumbs);
      final double totalDistance = _calculateTotalDistanceFromBreadcrumbs(breadcrumbs);
      final int duration = state.activeSession?.startedAt != null
          ? DateTime.now().difference(state.activeSession!.startedAt!).inMilliseconds
          : 0;

      // Mark session as completed even on error, so UI shows correct status
      final TrackingSession? errorSession = state.activeSession?.copyWith(
        status: SessionStatus.completed,
        completedAt: DateTime.now(),
        totalDistance: totalDistance,
        totalDuration: duration,
        breadcrumbCount: breadcrumbs.length,
      );

      state = state.copyWith(
        isTracking: false,
        activeSession: errorSession,
      );

      // Try to save to database even on error
      if (errorSession != null) {
        _databaseService.updateSession(errorSession).catchError((Object error) {
          debugPrint('Error saving session after error: $error');
        });
      }
    } finally {
      // CRITICAL: Reset the stopping flag after shutdown is complete
      _isStoppingTracking = false;
    }
  }

  /// Calculate total distance from a list of breadcrumbs
  double _calculateTotalDistanceFromBreadcrumbs(List<Breadcrumb> breadcrumbs) {
    if (breadcrumbs.length < 2) {
      return 0.0;
    }

    double totalDistance = 0.0;
    for (int i = 1; i < breadcrumbs.length; i++) {
      final Breadcrumb prev = breadcrumbs[i - 1];
      final Breadcrumb current = breadcrumbs[i];
      totalDistance += prev.distanceTo(current);
    }
    return totalDistance;
  }

  /// Pause the current tracking session
  Future<void> pauseTracking() async {
    if (!state.isTracking || state.activeSession == null) {
      return;
    }

    // Set stopping flag to prevent race conditions
    _isStoppingTracking = true;

    try {
      final TrackingSession pausedSession = state.activeSession!.copyWith(
        status: SessionStatus.paused,
      );

      // Update UI state immediately
      state = state.copyWith(
        isTracking: false,
        activeSession: pausedSession,
      );

      // Stop tracking services
      _stopBreadcrumbTimer();

      // Stop location service (don't block UI)
      await _locationService.stopLocationTracking();

      debugPrint('📍 Tracking paused successfully');
    } on Exception catch (e) {
      debugPrint('Error pausing tracking: $e');
      // Ensure UI still updates even on error
      state = state.copyWith(
        errorMessage: 'Error pausing tracking: $e',
        isTracking: false,
      );
    } finally {
      _isStoppingTracking = false;
    }
  }

  /// Resume a paused tracking session
  Future<bool> resumeTracking() async {
    if (state.activeSession?.status != SessionStatus.paused) {
      return false;
    }

    try {
      final TrackingSession session = state.activeSession!.copyWith(
        status: SessionStatus.active,
      );

      if (state.useEnhancedTracking) {
        await _locationService.startEnhancedLocationTracking(
          onLocationUpdate: _handleEnhancedLocationUpdate,
          onError: _handleLocationError,
          intervalSeconds: session.recordingInterval,
        );
      } else {
        await _locationService.startLocationTracking(
          onLocationUpdate: _handleLocationUpdate,
          onError: _handleLocationError,
          intervalSeconds: session.recordingInterval,
        );
      }

      _startBreadcrumbTimer(session.recordingInterval);

      state = state.copyWith(
        isTracking: true,
        activeSession: session,
      );

      return true;
    } on Exception catch (e) {
      debugPrint('Error resuming tracking: $e');
      state = state.copyWith(
        errorMessage: 'Error resuming tracking: $e',
      );
      return false;
    }
  }

  /// Handle location updates from the service
  void _handleLocationUpdate(Position position) {
    _safeSetState(() => state.copyWith(currentPosition: position));
  }

  /// Handle enhanced location updates from the service
  void _handleEnhancedLocationUpdate(EnhancedLocationData enhancedData) {
    _safeSetState(() => state.copyWith(
      currentPosition: enhancedData.position,
      enhancedLocationData: enhancedData,
    ));
  }

  /// Handle location service errors
  void _handleLocationError(LocationServiceException error) {
    debugPrint('Location service error: $error');
    _safeSetState(() => state.copyWith(
      status: _getLocationStatusFromError(error.type),
      errorMessage: error.message,
    ));
  }

  /// Start timer for recording breadcrumbs
  void _startBreadcrumbTimer(int intervalSeconds) {
    _stopBreadcrumbTimer();
    _breadcrumbTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _recordBreadcrumb(),
    );
  }

  /// Stop breadcrumb recording timer
  void _stopBreadcrumbTimer() {
    _breadcrumbTimer?.cancel();
    _breadcrumbTimer = null;
  }

  /// Record a breadcrumb if conditions are met
  void _recordBreadcrumb() {
    // CRITICAL: Check disposed flag first to prevent lifecycle errors
    // This prevents "_lifecycleState != _ElementLifecycle.defunct" crashes
    if (_isDisposed) {
      debugPrint('📍 Skipping breadcrumb - provider is disposed');
      return;
    }

    // CRITICAL: Check the stopping flag to prevent race conditions
    // This ensures no breadcrumbs are recorded during shutdown sequence
    if (_isStoppingTracking) {
      debugPrint('📍 Skipping breadcrumb - tracking is stopping');
      return;
    }

    final Position? position = state.currentPosition;
    final EnhancedLocationData? enhancedData = state.enhancedLocationData;
    final TrackingSession? session = state.activeSession;

    if (position == null || session == null || !state.isTracking) {
      return;
    }

    // Check accuracy threshold
    if (position.accuracy > session.accuracyThreshold) {
      debugPrint('Skipping breadcrumb - poor accuracy: ${position.accuracy}m');
      return;
    }

    // Distance filter: Only record if moved at least the configured distance from last breadcrumb
    // This prevents recording duplicate points when stationary (GPS drift)
    if (state.currentBreadcrumbs.isNotEmpty) {
      // Get user's distance threshold from settings (default: 5.0 meters)
      final double minDistance = ref.read(appSettingsProvider).tracking.minDistanceFilter;

      final Breadcrumb lastBreadcrumb = state.currentBreadcrumbs.last;
      final double distanceFromLast = Geolocator.distanceBetween(
        lastBreadcrumb.coordinates.latitude,
        lastBreadcrumb.coordinates.longitude,
        position.latitude,
        position.longitude,
      );

      // Check if moved enough distance (configurable in settings)
      if (distanceFromLast < minDistance) {
        debugPrint('Skipping breadcrumb - too close to last point: ${distanceFromLast.toStringAsFixed(1)}m (threshold: ${minDistance.toStringAsFixed(1)}m)');
        return;
      }
    }

    // Use enhanced data for better speed and accuracy checks
    double? speedToCheck = position.speed;
    if (enhancedData != null && enhancedData.bestSpeed != null) {
      speedToCheck = enhancedData.bestSpeed;
    }

    // Check minimum speed if specified
    if (session.minimumSpeed > 0 &&
        speedToCheck != null &&
        speedToCheck < session.minimumSpeed) {
      debugPrint(
          'Skipping breadcrumb - below minimum speed: ${speedToCheck}m/s');
      return;
    }

    // Use enhanced data for better altitude and heading when available
    double? altitudeToRecord = position.altitude;
    double? headingToRecord = position.heading;

    if (enhancedData != null) {
      altitudeToRecord = enhancedData.bestAltitude ?? altitudeToRecord;
      headingToRecord = enhancedData.bestHeading ?? headingToRecord;
    }

    // Use compass heading if available (more accurate than GPS heading, especially when stationary)
    if (_currentHeading != null) {
      headingToRecord = _currentHeading;
      debugPrint('📍 Using compass heading: ${headingToRecord!.toStringAsFixed(1)}°');
    }

    // Create new breadcrumb with enhanced data
    final String breadcrumbId =
        '${session.id}_${DateTime.now().millisecondsSinceEpoch}';
    final Breadcrumb breadcrumb = Breadcrumb.fromPosition(
      id: breadcrumbId,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: DateTime.now(),
      sessionId: session.id,
      altitude: session.recordAltitude ? altitudeToRecord : null,
      speed: session.recordSpeed ? speedToCheck : null,
      heading: session.recordHeading ? headingToRecord : null,
    );

    // Add to breadcrumb list
    final List<Breadcrumb> updatedBreadcrumbs = <Breadcrumb>[
      ...state.currentBreadcrumbs,
      breadcrumb
    ];

    // Calculate real-time stats
    double newDistance = session.totalDistance;
    double newElevationGain = session.elevationGain;
    double newElevationLoss = session.elevationLoss;
    double? newMaxAltitude = session.maxAltitude;
    double? newMinAltitude = session.minAltitude;
    double? newMaxSpeed = session.maxSpeed;

    // Calculate distance from last breadcrumb
    if (state.currentBreadcrumbs.isNotEmpty) {
      final Breadcrumb lastBreadcrumb = state.currentBreadcrumbs.last;
      final double distanceFromLast = lastBreadcrumb.distanceTo(breadcrumb);
      newDistance += distanceFromLast;

      // Calculate elevation change if both have altitude data
      if (lastBreadcrumb.altitude != null && breadcrumb.altitude != null) {
        final double elevationChange = breadcrumb.altitude! - lastBreadcrumb.altitude!;
        if (elevationChange > 0) {
          newElevationGain += elevationChange;
        } else {
          newElevationLoss += elevationChange.abs();
        }
      }
    }

    // Track max/min altitude
    if (breadcrumb.altitude != null) {
      if (newMaxAltitude == null || breadcrumb.altitude! > newMaxAltitude) {
        newMaxAltitude = breadcrumb.altitude;
      }
      if (newMinAltitude == null || breadcrumb.altitude! < newMinAltitude) {
        newMinAltitude = breadcrumb.altitude;
      }
    }

    // Track max speed
    if (breadcrumb.speed != null && breadcrumb.speed! > 0) {
      if (newMaxSpeed == null || breadcrumb.speed! > newMaxSpeed) {
        newMaxSpeed = breadcrumb.speed;
      }
    }

    // Update session with all real-time stats
    final TrackingSession updatedSession = session.copyWith(
      breadcrumbCount: updatedBreadcrumbs.length,
      totalDistance: newDistance,
      elevationGain: newElevationGain,
      elevationLoss: newElevationLoss,
      maxAltitude: newMaxAltitude,
      minAltitude: newMinAltitude,
      maxSpeed: newMaxSpeed,
    );

    _safeSetState(() => state.copyWith(
      currentBreadcrumbs: updatedBreadcrumbs,
      activeSession: updatedSession,
    ));

    // Save breadcrumb to database
    _databaseService.insertBreadcrumb(breadcrumb);

    // Enhanced logging with stats
    debugPrint('📍 Breadcrumb #${updatedBreadcrumbs.length}: ${breadcrumb.coordinates.latitude.toStringAsFixed(5)}, ${breadcrumb.coordinates.longitude.toStringAsFixed(5)} | '
        'Dist: ${newDistance.toStringAsFixed(0)}m | '
        'Elev: +${newElevationGain.toStringAsFixed(0)}/-${newElevationLoss.toStringAsFixed(0)}m | '
        'Speed: ${breadcrumb.speed?.toStringAsFixed(1) ?? '-'}m/s');
  }


  /// Convert location service error to location status
  LocationStatus _getLocationStatusFromError(LocationServiceError error) {
    switch (error) {
      case LocationServiceError.permissionDenied:
        return LocationStatus.denied;
      case LocationServiceError.permissionDeniedForever:
        return LocationStatus.deniedForever;
      case LocationServiceError.serviceDisabled:
        return LocationStatus.serviceDisabled;
      case LocationServiceError.notSupported:
        return LocationStatus.notSupported;
      case LocationServiceError.timeout:
      case LocationServiceError.unknown:
        return LocationStatus.unknown;
    }
  }

  /// Open device location settings
  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  /// Clear the active session (e.g., after viewing a completed session)
  void clearActiveSession() {
    state = LocationState(
      status: state.status,
      currentPosition: state.currentPosition,
      enhancedLocationData: state.enhancedLocationData,
      useEnhancedTracking: state.useEnhancedTracking,
      detailedPermission: state.detailedPermission,
      hasAlwaysPermission: state.hasAlwaysPermission,
    );
  }

  /// Update the active session with new data (e.g., after linking a route)
  void updateActiveSession(TrackingSession updatedSession) {
    state = state.copyWith(activeSession: updatedSession);
  }

  /// Toggle enhanced location tracking
  void setEnhancedTracking({required bool enabled}) {
    if (state.useEnhancedTracking != enabled) {
      state = state.copyWith(useEnhancedTracking: enabled);

      // If currently tracking, restart with new mode
      if (state.isTracking && state.activeSession != null) {
        debugPrint(
            'Switching tracking mode to ${enabled ? 'enhanced' : 'standard'}');
        // Note: In a real implementation, you might want to restart tracking
        // For now, we'll just log the change
      }
    }
  }

  /// Get enhanced location capabilities info
  Map<String, dynamic> getEnhancedLocationInfo() {
    final EnhancedLocationData? enhanced = state.enhancedLocationData;

    return <String, dynamic>{
      'isEnhancedTrackingEnabled': state.useEnhancedTracking,
      'hasEnhancedData': enhanced?.isEnhancedDataAvailable ?? false,
      'hasReliableEnhancedData': enhanced?.hasReliableEnhancedData ?? false,
      'calculatedSpeed': enhanced?.calculatedSpeed,
      'speedAccuracy': enhanced?.speedAccuracy,
      'altitudeAccuracy': enhanced?.altitudeAccuracy,
      'headingAccuracy': enhanced?.headingAccuracy,
      'bestSpeed': enhanced?.bestSpeed,
      'bestAltitude': enhanced?.bestAltitude,
      'bestHeading': enhanced?.bestHeading,
    };
  }

  /// Update lifetime statistics and check achievements after session completion
  ///
  /// This runs asynchronously and doesn't block the UI.
  /// Any errors are caught and logged to prevent affecting the main tracking flow.
  Future<void> _updateStatsAndAchievements(
    TrackingSession session,
    List<Breadcrumb> breadcrumbs,
  ) async {
    try {
      debugPrint('🏆 Updating lifetime statistics...');

      // Get photo and voice note counts for achievement tracking
      final photoCount = await _databaseService.countPhotosForSession(session.id);
      final voiceNoteCount = await _databaseService.countVoiceNotesForSession(session.id);
      debugPrint('🏆 Session has $photoCount photos and $voiceNoteCount voice notes');

      // Update lifetime statistics with session data including media counts
      await _lifetimeStatsService.updateFromSession(
        session,
        breadcrumbs,
        photoCount: photoCount,
        voiceNoteCount: voiceNoteCount,
      );

      debugPrint('🏆 Checking achievements...');

      // Check all achievements for newly unlocked badges
      final unlocked = await _achievementService.checkAllAchievements();

      if (unlocked.isNotEmpty) {
        for (final event in unlocked) {
          debugPrint('🏆 Achievement unlocked: ${event.achievement.name}');
        }
      }

      debugPrint('🏆 Stats and achievements updated successfully');
    } catch (e) {
      // Don't let stats/achievement errors affect the main tracking flow
      debugPrint('🏆 Error updating stats/achievements (non-fatal): $e');
    }
  }
}

/// Provider for location tracking functionality
final locationProvider =
    NotifierProvider<LocationNotifier, LocationState>(LocationNotifier.new);

/// Provider for current position (convenience)
final Provider<Position?> currentPositionProvider = Provider<Position?>(
    (Ref ref) => ref.watch(locationProvider).currentPosition);

/// Provider for active tracking session (convenience)
final Provider<TrackingSession?> activeSessionProvider =
    Provider<TrackingSession?>(
        (Ref ref) => ref.watch(locationProvider).activeSession);

/// Provider for current breadcrumbs (convenience)
final Provider<List<Breadcrumb>> currentBreadcrumbsProvider =
    Provider<List<Breadcrumb>>(
        (Ref ref) => ref.watch(locationProvider).currentBreadcrumbs);

/// Provider for tracking status (convenience)
final Provider<bool> isTrackingProvider =
    Provider<bool>((Ref ref) => ref.watch(locationProvider).isTracking);

/// Provider for enhanced location data (convenience)
final Provider<EnhancedLocationData?> enhancedLocationProvider =
    Provider<EnhancedLocationData?>(
        (Ref ref) => ref.watch(locationProvider).enhancedLocationData);

/// Provider for enhanced tracking status (convenience)
final Provider<bool> useEnhancedTrackingProvider = Provider<bool>(
    (Ref ref) => ref.watch(locationProvider).useEnhancedTracking);

/// Provider for enhanced location info (convenience)
final Provider<Map<String, dynamic>> enhancedLocationInfoProvider =
    Provider<Map<String, dynamic>>((Ref ref) {
  final LocationNotifier notifier = ref.read(locationProvider.notifier);
  return notifier.getEnhancedLocationInfo();
});

/// Provider for detailed location permission status (convenience)
final Provider<LocationPermission?> detailedPermissionProvider =
    Provider<LocationPermission?>(
        (Ref ref) => ref.watch(locationProvider).detailedPermission);

/// Provider for "Always" permission status (convenience)
final Provider<bool> hasAlwaysPermissionProvider =
    Provider<bool>((Ref ref) => ref.watch(locationProvider).hasAlwaysPermission);

/// Provider for loading breadcrumbs for a specific session (for playback mode)
final sessionBreadcrumbsProvider =
    FutureProvider.family<List<Breadcrumb>, String>((ref, sessionId) async {
  final DatabaseService databaseService = DatabaseService();
  return databaseService.getBreadcrumbsForSession(sessionId);
});
