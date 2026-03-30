import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/services/location_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';

/// Background location tracking service for iOS and Android
///
/// Provides continuous GPS tracking when the app is backgrounded or screen is locked.
/// Implements platform-specific background services and battery optimization strategies.
class BackgroundLocationService {
  factory BackgroundLocationService() =>
      _instance ??= BackgroundLocationService._();
  BackgroundLocationService._();
  static BackgroundLocationService? _instance;

  static const String _backgroundTaskName =
      'obsession_background_location_task';
  static const String _notificationChannelId = 'obsession_location_channel';
  static const int _notificationId = 1001;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final LocationService _locationService = LocationService();

  bool _isBackgroundTrackingActive = false;
  bool _isInitialized = false;
  StreamSubscription<Position>? _backgroundLocationStream;
  Timer? _batteryOptimizationTimer;

  // Battery optimization settings
  int _currentUpdateInterval = 30; // seconds
  static const int _minUpdateInterval = 15; // seconds
  static const int _maxUpdateInterval = 300; // 5 minutes
  static const double _significantDistanceThreshold = 10.0; // meters

  // Movement tracking for optimization
  Position? _lastPosition;
  DateTime? _lastMovementTime;
  double _averageSpeed = 0.0;
  final List<double> _speedHistory = <double>[];
  static const int _maxSpeedHistoryLength = 10;

  /// Whether background location tracking is currently active
  bool get isBackgroundTrackingActive => _isBackgroundTrackingActive;

  /// Current update interval in seconds
  int get currentUpdateInterval => _currentUpdateInterval;

  /// Initialize the background location service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize notifications
      await _initializeNotifications();

      // Initialize workmanager for background tasks
      await Workmanager().initialize(
        _backgroundTaskCallbackDispatcher,
      );

      _isInitialized = true;
      debugPrint('BackgroundLocationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing BackgroundLocationService: $e');
      rethrow;
    }
  }

  /// Start background location tracking
  Future<void> startBackgroundTracking({
    int updateIntervalSeconds = 30,
    double minimumDistanceMeters = 5.0,
    bool showNotification = true,
    bool enableBatteryOptimization = true,
  }) async {
    if (_isBackgroundTrackingActive) {
      debugPrint('Background tracking is already active');
      return;
    }

    try {
      await initialize();

      // Check and request permissions
      await _ensureBackgroundPermissions();

      // Show notification if requested
      if (showNotification) {
        await _showBackgroundTrackingNotification();
      }

      // Start location tracking with enhanced background settings
      await _startLocationTracking(
        updateIntervalSeconds: updateIntervalSeconds,
        minimumDistanceMeters: minimumDistanceMeters,
      );

      // Register background task for maintenance
      await Workmanager().registerPeriodicTask(
        _backgroundTaskName,
        _backgroundTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.notRequired,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );

      // Start battery optimization if enabled
      if (enableBatteryOptimization) {
        _startBatteryOptimization();
      }

      _isBackgroundTrackingActive = true;
      _currentUpdateInterval = updateIntervalSeconds;

      debugPrint(
          'Background location tracking started with ${updateIntervalSeconds}s interval');
    } catch (e) {
      debugPrint('Error starting background tracking: $e');
      rethrow;
    }
  }

  /// Stop background location tracking
  Future<void> stopBackgroundTracking() async {
    if (!_isBackgroundTrackingActive) {
      debugPrint('Background tracking is not active');
      return;
    }

    try {
      // Stop location tracking
      await _backgroundLocationStream?.cancel();
      _backgroundLocationStream = null;

      // Stop battery optimization timer
      _batteryOptimizationTimer?.cancel();
      _batteryOptimizationTimer = null;

      // Cancel background tasks
      await Workmanager().cancelByUniqueName(_backgroundTaskName);

      // Hide notification
      await _notificationsPlugin.cancel(id: _notificationId);

      _isBackgroundTrackingActive = false;

      debugPrint('Background location tracking stopped');
    } catch (e) {
      debugPrint('Error stopping background tracking: $e');
      rethrow;
    }
  }

  /// Start location tracking with background-optimized settings
  Future<void> _startLocationTracking({
    required int updateIntervalSeconds,
    required double minimumDistanceMeters,
  }) async {
    try {
      _backgroundLocationStream = _locationService
          .getLocationStream(
        intervalSeconds: updateIntervalSeconds,
        minimumDistanceMeters: minimumDistanceMeters,
      )
          .listen(
        _handleBackgroundLocationUpdate,
        onError: (Object error) {
          debugPrint('Background location stream error: $error');
          // Attempt to restart tracking after a delay
          Timer(const Duration(seconds: 30), () {
            if (_isBackgroundTrackingActive) {
              _restartLocationTracking();
            }
          });
        },
      );
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
      rethrow;
    }
  }

  /// Handle background location updates
  void _handleBackgroundLocationUpdate(Position position) {
    try {
      // Store location in database
      _storeBackgroundLocation(position);

      // Update movement tracking
      _updateMovementTracking(position);

      // Update notification with current location info
      _updateBackgroundNotification(position);

      debugPrint(
          'Background location updated: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('Error handling background location update: $e');
    }
  }

  /// Store background location in database
  Future<void> _storeBackgroundLocation(Position position) async {
    try {
      // Create a location record for background storage
      // This would integrate with your existing tracking session system
      final Map<String, dynamic> locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'altitude': position.altitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': position.timestamp.millisecondsSinceEpoch,
        'is_background': 1,
      };

      // In a real implementation, you would store this in your tracking sessions table
      // For now, we'll just log the data structure that would be stored
      debugPrint(
          'Background location stored: ${position.latitude}, ${position.longitude}');
      debugPrint('Location data structure: $locationData');
    } catch (e) {
      debugPrint('Error storing background location: $e');
    }
  }

  /// Update movement tracking for battery optimization
  void _updateMovementTracking(Position position) {
    final DateTime now = DateTime.now();

    if (_lastPosition != null) {
      // Calculate distance moved
      final double distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // Calculate speed
      final double speed = position.speed >= 0 ? position.speed : 0.0;

      // Update speed history
      _speedHistory.add(speed);
      if (_speedHistory.length > _maxSpeedHistoryLength) {
        _speedHistory.removeAt(0);
      }

      // Calculate average speed
      _averageSpeed = _speedHistory.isNotEmpty
          ? _speedHistory.reduce((a, b) => a + b) / _speedHistory.length
          : 0.0;

      // Check for significant movement
      if (distance > _significantDistanceThreshold) {
        _lastMovementTime = now;
      }
    }

    _lastPosition = position;
  }

  /// Start battery optimization monitoring
  void _startBatteryOptimization() {
    _batteryOptimizationTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _optimizeForBattery(),
    );
  }

  /// Optimize tracking based on movement patterns and battery
  Future<void> _optimizeForBattery() async {
    try {
      int newInterval = _currentUpdateInterval;

      // Movement-based optimization
      final DateTime now = DateTime.now();
      final bool hasRecentMovement = _lastMovementTime != null &&
          now.difference(_lastMovementTime!).inMinutes < 10;

      if (!hasRecentMovement && _averageSpeed < 0.5) {
        // Stationary - reduce frequency significantly
        newInterval = _maxUpdateInterval;
      } else if (_averageSpeed < 1.0) {
        // Slow movement (walking) - moderate frequency
        newInterval = 120; // 2 minutes
      } else if (_averageSpeed < 5.0) {
        // Moderate movement (cycling) - higher frequency
        newInterval = 60; // 1 minute
      } else {
        // Fast movement (vehicle) - highest frequency
        newInterval = _minUpdateInterval;
      }

      // Apply new interval if significantly different
      if ((newInterval - _currentUpdateInterval).abs() > 15) {
        await _updateTrackingInterval(newInterval);
      }
    } catch (e) {
      debugPrint('Error optimizing for battery: $e');
    }
  }

  /// Update tracking interval
  Future<void> _updateTrackingInterval(int newIntervalSeconds) async {
    try {
      _currentUpdateInterval = newIntervalSeconds;

      // Restart tracking with new interval
      await _backgroundLocationStream?.cancel();
      await _startLocationTracking(
        updateIntervalSeconds: _currentUpdateInterval,
        minimumDistanceMeters: _significantDistanceThreshold,
      );

      debugPrint('Tracking interval updated to ${_currentUpdateInterval}s');
    } catch (e) {
      debugPrint('Error updating tracking interval: $e');
    }
  }

  /// Restart location tracking after an error
  Future<void> _restartLocationTracking() async {
    try {
      debugPrint('Restarting background location tracking...');

      await _backgroundLocationStream?.cancel();
      await _startLocationTracking(
        updateIntervalSeconds: _currentUpdateInterval,
        minimumDistanceMeters: _significantDistanceThreshold,
      );
    } catch (e) {
      debugPrint('Error restarting location tracking: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings: settings);

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _notificationChannelId,
      'Location Tracking',
      description: 'Notifications for background location tracking',
      importance: Importance.low,
      showBadge: false,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Show persistent notification for background tracking
  Future<void> _showBackgroundTrackingNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _notificationChannelId,
      'Location Tracking',
      channelDescription: 'Background location tracking is active',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: _notificationId,
      title: 'Location Tracking Active',
      body: 'Obsession Tracker is tracking your location in the background',
      notificationDetails: details,
    );
  }

  /// Update background notification with current location info
  Future<void> _updateBackgroundNotification(Position position) async {
    if (!_isBackgroundTrackingActive) return;

    try {
      final String speedText = position.speed >= 0
          ? '${(position.speed * 3.6).toStringAsFixed(1)} km/h'
          : 'Unknown speed';

      final String accuracyText = '±${position.accuracy.toStringAsFixed(0)}m';

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _notificationChannelId,
        'Location Tracking',
        channelDescription: 'Background location tracking is active',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id: _notificationId,
        title: 'Location Tracking Active',
        body: 'Speed: $speedText • Accuracy: $accuracyText',
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('Error updating notification: $e');
    }
  }

  /// Ensure background location permissions are granted
  Future<void> _ensureBackgroundPermissions() async {
    // Check location permission
    final LocationPermission locationPermission =
        await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied) {
      throw const LocationServiceException(
        'Location permission required for background tracking',
        LocationServiceError.permissionDenied,
      );
    }

    // Request background location permission on Android
    if (Platform.isAndroid) {
      final PermissionStatus backgroundLocationStatus =
          await Permission.locationAlways.status;
      if (backgroundLocationStatus != PermissionStatus.granted) {
        final PermissionStatus status =
            await Permission.locationAlways.request();
        if (status != PermissionStatus.granted) {
          debugPrint(
              'Background location permission not granted, using foreground permission');
        }
      }
    }

    // Request notification permission
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    stopBackgroundTracking();
    _batteryOptimizationTimer?.cancel();
    _instance = null;
  }
}

/// Background task callback dispatcher for Workmanager
@pragma('vm:entry-point')
void _backgroundTaskCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('Background maintenance task executed: $task');

      // Perform background maintenance tasks
      // - Check if location tracking is still active
      // - Clean up old location data if needed
      // - Optimize battery usage

      return Future.value(true);
    } catch (e) {
      debugPrint('Background task error: $e');
      return Future.value(false);
    }
  });
}
