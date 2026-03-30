import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:obsession_tracker/core/models/gps_accuracy_models.dart';
import 'package:obsession_tracker/core/services/gps_accuracy_service.dart';

/// GPS notification service for user feedback about GPS quality and recommendations
///
/// Provides intelligent notifications about GPS performance, accuracy issues,
/// environmental conditions, and actionable recommendations to improve tracking.
class GpsNotificationService {
  factory GpsNotificationService() => _instance ??= GpsNotificationService._();
  GpsNotificationService._();
  static GpsNotificationService? _instance;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final GpsAccuracyService _gpsAccuracyService = GpsAccuracyService();

  // Stream controllers
  StreamController<GpsNotification>? _notificationController;

  // Service state
  bool _isActive = false;
  GpsNotificationSettings _settings = GpsNotificationSettings.defaultSettings();

  // Notification tracking
  final Set<int> _activeNotificationIds = {};
  final Map<GpsNotificationType, DateTime> _lastNotificationTime = {};
  final Map<GpsNotificationType, int> _notificationCounts = {};

  // Subscription to GPS accuracy updates
  StreamSubscription<GpsQualityReading>? _qualitySubscription;
  StreamSubscription<GpsAccuracyAlert>? _alertSubscription;
  StreamSubscription<EnvironmentalCondition>? _environmentSubscription;

  // Notification channels
  static const String _channelId = 'gps_quality_notifications';
  static const String _channelName = 'GPS Quality';
  static const String _channelDescription =
      'Notifications about GPS accuracy and recommendations';

  /// Stream of GPS notifications
  Stream<GpsNotification> get notificationStream {
    _notificationController ??= StreamController<GpsNotification>.broadcast();
    return _notificationController!.stream;
  }

  /// Whether the service is active
  bool get isActive => _isActive;

  /// Current notification settings
  GpsNotificationSettings get settings => _settings;

  /// Start GPS notification service
  Future<void> start({
    GpsNotificationSettings? settings,
  }) async {
    try {
      await stop(); // Ensure clean start

      _settings = settings ?? GpsNotificationSettings.defaultSettings();

      debugPrint('🔔 Starting GPS notification service...');

      // Initialize notifications
      await _initializeNotifications();

      // Initialize stream controller
      _notificationController ??= StreamController<GpsNotification>.broadcast();

      // Subscribe to GPS accuracy updates
      _subscribeToGpsUpdates();

      _isActive = true;
      debugPrint('🔔 GPS notification service started successfully');
    } catch (e) {
      debugPrint('🔔 Error starting GPS notification service: $e');
      rethrow;
    }
  }

  /// Stop GPS notification service
  Future<void> stop() async {
    // Cancel subscriptions
    await _qualitySubscription?.cancel();
    _qualitySubscription = null;

    await _alertSubscription?.cancel();
    _alertSubscription = null;

    await _environmentSubscription?.cancel();
    _environmentSubscription = null;

    // Clear active notifications
    await _clearAllNotifications();

    // Close stream controller
    await _notificationController?.close();
    _notificationController = null;

    _isActive = false;
    debugPrint('🔔 GPS notification service stopped');
  }

  /// Update notification settings
  Future<void> updateSettings(GpsNotificationSettings newSettings) async {
    _settings = newSettings;

    if (!_settings.enabled) {
      // Clear all notifications if disabled
      await _clearAllNotifications();
    }

    debugPrint('🔔 GPS notification settings updated');
  }

  /// Manually show a GPS notification
  Future<void> showNotification(GpsNotification notification) async {
    if (!_isActive || !_settings.enabled) return;

    try {
      // Check if notification type is enabled
      if (!_isNotificationTypeEnabled(notification.type)) return;

      // Check rate limiting
      if (!_shouldShowNotification(notification.type)) return;

      // Show system notification
      await _showSystemNotification(notification);

      // Emit notification event
      _notificationController?.add(notification);

      // Update tracking
      _updateNotificationTracking(notification.type);

      debugPrint('🔔 GPS notification shown: ${notification.title}');
    } catch (e) {
      debugPrint('🔔 Error showing GPS notification: $e');
    }
  }

  /// Clear a specific notification
  Future<void> clearNotification(int notificationId) async {
    try {
      await _notificationsPlugin.cancel(id: notificationId);
      _activeNotificationIds.remove(notificationId);
    } catch (e) {
      debugPrint('🔔 Error clearing notification: $e');
    }
  }

  /// Clear all GPS notifications
  Future<void> clearAllNotifications() async {
    await _clearAllNotifications();
  }

  /// Get notification statistics
  GpsNotificationStatistics getNotificationStatistics() =>
      GpsNotificationStatistics(
        totalNotifications:
            _notificationCounts.values.fold(0, (sum, count) => sum + count),
        notificationsByType: Map.from(_notificationCounts),
        activeNotifications: _activeNotificationIds.length,
        lastNotificationTimes: Map.from(_lastNotificationTime),
        timestamp: DateTime.now(),
      );

  Future<void> _initializeNotifications() async {
    // Initialize notification plugin
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestBadgePermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings: initSettings);

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      showBadge: false,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  void _subscribeToGpsUpdates() {
    // Subscribe to GPS quality updates
    _qualitySubscription = _gpsAccuracyService.qualityStream.listen(
      _handleGpsQualityUpdate,
      onError: (Object error) {
        debugPrint('🔔 GPS quality stream error: $error');
      },
    );

    // Subscribe to GPS alerts
    _alertSubscription = _gpsAccuracyService.alertStream.listen(
      _handleGpsAlert,
      onError: (Object error) {
        debugPrint('🔔 GPS alert stream error: $error');
      },
    );

    // Subscribe to environmental condition changes
    _environmentSubscription = _gpsAccuracyService.environmentStream.listen(
      _handleEnvironmentChange,
      onError: (Object error) {
        debugPrint('🔔 GPS environment stream error: $error');
      },
    );
  }

  void _handleGpsQualityUpdate(GpsQualityReading reading) {
    // Check for quality-based notifications
    _checkQualityNotifications(reading);
  }

  void _handleGpsAlert(GpsAccuracyAlert alert) {
    // Convert GPS alert to notification
    final notification = _createNotificationFromAlert(alert);
    if (notification != null) {
      showNotification(notification);
    }
  }

  void _handleEnvironmentChange(EnvironmentalCondition environment) {
    // Show notification about environment change and recommendations
    final notification = _createEnvironmentNotification(environment);
    if (notification != null) {
      showNotification(notification);
    }
  }

  void _checkQualityNotifications(GpsQualityReading reading) {
    // Check for poor accuracy
    if (reading.accuracy > 20.0 && _settings.notifyPoorAccuracy) {
      final notification = GpsNotification(
        id: _generateNotificationId(GpsNotificationType.poorAccuracy),
        type: GpsNotificationType.poorAccuracy,
        title: 'Poor GPS Accuracy',
        message:
            'GPS accuracy is ${reading.accuracy.toStringAsFixed(1)}m. Consider moving to an open area.',
        priority: NotificationPriority.medium,
        actions: const [
          NotificationAction.moveToOpenArea,
          NotificationAction.checkSettings,
        ],
        timestamp: DateTime.now(),
      );
      showNotification(notification);
    }

    // Check for weak signal
    if (reading.signalStrength < 30.0 && _settings.notifyWeakSignal) {
      final notification = GpsNotification(
        id: _generateNotificationId(GpsNotificationType.weakSignal),
        type: GpsNotificationType.weakSignal,
        title: 'Weak GPS Signal',
        message:
            'GPS signal strength is low (${reading.signalStrength.toStringAsFixed(0)}%). Try moving away from buildings.',
        priority: NotificationPriority.low,
        actions: const [
          NotificationAction.moveToOpenArea,
          NotificationAction.restartGps,
        ],
        timestamp: DateTime.now(),
      );
      showNotification(notification);
    }

    // Check for excellent accuracy (positive feedback)
    if (reading.accuracy <= 3.0 && _settings.notifyGoodConditions) {
      final notification = GpsNotification(
        id: _generateNotificationId(GpsNotificationType.excellentAccuracy),
        type: GpsNotificationType.excellentAccuracy,
        title: 'Excellent GPS Accuracy',
        message:
            'GPS accuracy is excellent (${reading.accuracy.toStringAsFixed(1)}m). Perfect conditions for tracking!',
        priority: NotificationPriority.low,
        actions: const [
          NotificationAction.startTracking,
        ],
        timestamp: DateTime.now(),
      );
      showNotification(notification);
    }
  }

  GpsNotification? _createNotificationFromAlert(GpsAccuracyAlert alert) {
    switch (alert.type) {
      case GpsAlertType.poorAccuracy:
        if (!_settings.notifyPoorAccuracy) return null;
        return GpsNotification(
          id: _generateNotificationId(GpsNotificationType.poorAccuracy),
          type: GpsNotificationType.poorAccuracy,
          title: 'GPS Accuracy Alert',
          message: alert.message,
          priority: _mapAlertSeverityToPriority(alert.severity),
          actions: const [
            NotificationAction.moveToOpenArea,
            NotificationAction.checkSettings,
          ],
          timestamp: alert.timestamp,
        );

      case GpsAlertType.weakSignal:
        if (!_settings.notifyWeakSignal) return null;
        return GpsNotification(
          id: _generateNotificationId(GpsNotificationType.weakSignal),
          type: GpsNotificationType.weakSignal,
          title: 'GPS Signal Alert',
          message: alert.message,
          priority: _mapAlertSeverityToPriority(alert.severity),
          actions: const [
            NotificationAction.moveToOpenArea,
            NotificationAction.restartGps,
          ],
          timestamp: alert.timestamp,
        );

      case GpsAlertType.excessiveDrift:
        if (!_settings.notifyDrift) return null;
        return GpsNotification(
          id: _generateNotificationId(GpsNotificationType.drift),
          type: GpsNotificationType.drift,
          title: 'GPS Drift Detected',
          message: alert.message,
          priority: _mapAlertSeverityToPriority(alert.severity),
          actions: const [
            NotificationAction.calibrateCompass,
            NotificationAction.restartGps,
          ],
          timestamp: alert.timestamp,
        );

      case GpsAlertType.challengingEnvironment:
        if (!_settings.notifyEnvironmentChanges) return null;
        return GpsNotification(
          id: _generateNotificationId(GpsNotificationType.environmentChange),
          type: GpsNotificationType.environmentChange,
          title: 'Challenging GPS Environment',
          message: alert.message,
          priority: NotificationPriority.low,
          actions: const [
            NotificationAction.adjustSettings,
            NotificationAction.viewTips,
          ],
          timestamp: alert.timestamp,
        );

      default:
        return null;
    }
  }

  GpsNotification? _createEnvironmentNotification(
      EnvironmentalCondition environment) {
    if (!_settings.notifyEnvironmentChanges) return null;

    final recommendations = _getEnvironmentRecommendations(environment);
    if (recommendations.isEmpty) return null;

    return GpsNotification(
      id: _generateNotificationId(GpsNotificationType.environmentChange),
      type: GpsNotificationType.environmentChange,
      title: 'GPS Environment: ${environment.description}',
      message: recommendations.first,
      priority: NotificationPriority.low,
      actions: const [
        NotificationAction.viewTips,
        NotificationAction.adjustSettings,
      ],
      timestamp: DateTime.now(),
    );
  }

  List<String> _getEnvironmentRecommendations(
      EnvironmentalCondition environment) {
    switch (environment) {
      case EnvironmentalCondition.urbanCanyon:
        return [
          'GPS accuracy may be reduced in urban canyons. Consider increasing update frequency.',
          'Try moving to a more open area for better GPS reception.',
        ];
      case EnvironmentalCondition.denseForest:
        return [
          'Dense forest can block GPS signals. Expect reduced accuracy.',
          'Consider using compass and manual waypoints as backup.',
        ];
      case EnvironmentalCondition.indoor:
        return [
          'GPS signals are weak indoors. Consider pausing tracking.',
          'Use WiFi positioning if available for indoor navigation.',
        ];
      case EnvironmentalCondition.mountainous:
        return [
          'Mountain terrain can affect GPS accuracy. Allow extra time for signal acquisition.',
          'Consider using barometric altitude for better elevation tracking.',
        ];
      default:
        return [];
    }
  }

  Future<void> _showSystemNotification(GpsNotification notification) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: _mapPriorityToImportance(notification.priority),
      priority: _mapPriorityToAndroidPriority(notification.priority),
      icon: _getNotificationIcon(notification.type),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: notification.id,
      title: notification.title,
      body: notification.message,
      notificationDetails: details,
    );

    _activeNotificationIds.add(notification.id);
  }

  bool _isNotificationTypeEnabled(GpsNotificationType type) {
    switch (type) {
      case GpsNotificationType.poorAccuracy:
        return _settings.notifyPoorAccuracy;
      case GpsNotificationType.weakSignal:
        return _settings.notifyWeakSignal;
      case GpsNotificationType.drift:
        return _settings.notifyDrift;
      case GpsNotificationType.environmentChange:
        return _settings.notifyEnvironmentChanges;
      case GpsNotificationType.excellentAccuracy:
        return _settings.notifyGoodConditions;
      case GpsNotificationType.recommendation:
        return _settings.notifyRecommendations;
    }
  }

  bool _shouldShowNotification(GpsNotificationType type) {
    final lastTime = _lastNotificationTime[type];
    if (lastTime == null) return true;

    final minInterval = _getMinIntervalForType(type);
    return DateTime.now().difference(lastTime) >= minInterval;
  }

  Duration _getMinIntervalForType(GpsNotificationType type) {
    switch (type) {
      case GpsNotificationType.poorAccuracy:
      case GpsNotificationType.weakSignal:
        return const Duration(minutes: 5);
      case GpsNotificationType.drift:
        return const Duration(minutes: 3);
      case GpsNotificationType.environmentChange:
        return const Duration(minutes: 10);
      case GpsNotificationType.excellentAccuracy:
        return const Duration(minutes: 15);
      case GpsNotificationType.recommendation:
        return const Duration(minutes: 10);
    }
  }

  void _updateNotificationTracking(GpsNotificationType type) {
    _lastNotificationTime[type] = DateTime.now();
    _notificationCounts[type] = (_notificationCounts[type] ?? 0) + 1;
  }

  int _generateNotificationId(GpsNotificationType type) =>
      // Generate unique ID based on type and timestamp
      type.hashCode + DateTime.now().millisecondsSinceEpoch.hashCode;

  NotificationPriority _mapAlertSeverityToPriority(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return NotificationPriority.low;
      case AlertSeverity.medium:
        return NotificationPriority.medium;
      case AlertSeverity.high:
        return NotificationPriority.high;
      case AlertSeverity.critical:
        return NotificationPriority.critical;
    }
  }

  Importance _mapPriorityToImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Importance.low;
      case NotificationPriority.medium:
        return Importance.defaultImportance;
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.critical:
        return Importance.max;
    }
  }

  Priority _mapPriorityToAndroidPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Priority.low;
      case NotificationPriority.medium:
        return Priority.defaultPriority;
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.critical:
        return Priority.max;
    }
  }

  String? _getNotificationIcon(GpsNotificationType type) {
    switch (type) {
      case GpsNotificationType.poorAccuracy:
        return '@drawable/ic_gps_poor';
      case GpsNotificationType.weakSignal:
        return '@drawable/ic_signal_weak';
      case GpsNotificationType.drift:
        return '@drawable/ic_gps_drift';
      case GpsNotificationType.environmentChange:
        return '@drawable/ic_environment';
      case GpsNotificationType.excellentAccuracy:
        return '@drawable/ic_gps_excellent';
      case GpsNotificationType.recommendation:
        return '@drawable/ic_recommendation';
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      for (final id in _activeNotificationIds) {
        await _notificationsPlugin.cancel(id: id);
      }
      _activeNotificationIds.clear();
    } catch (e) {
      debugPrint('🔔 Error clearing notifications: $e');
    }
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    stop();
    _instance = null;
  }
}

/// GPS notification data
@immutable
class GpsNotification {
  const GpsNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.priority,
    required this.actions,
    required this.timestamp,
  });

  final int id;
  final GpsNotificationType type;
  final String title;
  final String message;
  final NotificationPriority priority;
  final List<NotificationAction> actions;
  final DateTime timestamp;

  @override
  String toString() => 'GpsNotification('
      'type: ${type.name}, '
      'title: $title, '
      'priority: ${priority.name}'
      ')';
}

/// GPS notification settings
@immutable
class GpsNotificationSettings {
  const GpsNotificationSettings({
    required this.enabled,
    required this.notifyPoorAccuracy,
    required this.notifyWeakSignal,
    required this.notifyDrift,
    required this.notifyEnvironmentChanges,
    required this.notifyGoodConditions,
    required this.notifyRecommendations,
    required this.soundEnabled,
    required this.vibrationEnabled,
  });

  /// Create default notification settings
  factory GpsNotificationSettings.defaultSettings() =>
      const GpsNotificationSettings(
        enabled: true,
        notifyPoorAccuracy: true,
        notifyWeakSignal: true,
        notifyDrift: true,
        notifyEnvironmentChanges: true,
        notifyGoodConditions: false, // Disabled by default to avoid spam
        notifyRecommendations: true,
        soundEnabled: false, // Quiet by default
        vibrationEnabled: true,
      );

  /// Create settings with all notifications disabled
  factory GpsNotificationSettings.disabled() => const GpsNotificationSettings(
        enabled: false,
        notifyPoorAccuracy: false,
        notifyWeakSignal: false,
        notifyDrift: false,
        notifyEnvironmentChanges: false,
        notifyGoodConditions: false,
        notifyRecommendations: false,
        soundEnabled: false,
        vibrationEnabled: false,
      );

  final bool enabled;
  final bool notifyPoorAccuracy;
  final bool notifyWeakSignal;
  final bool notifyDrift;
  final bool notifyEnvironmentChanges;
  final bool notifyGoodConditions;
  final bool notifyRecommendations;
  final bool soundEnabled;
  final bool vibrationEnabled;

  /// Create a copy with modified settings
  GpsNotificationSettings copyWith({
    bool? enabled,
    bool? notifyPoorAccuracy,
    bool? notifyWeakSignal,
    bool? notifyDrift,
    bool? notifyEnvironmentChanges,
    bool? notifyGoodConditions,
    bool? notifyRecommendations,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) =>
      GpsNotificationSettings(
        enabled: enabled ?? this.enabled,
        notifyPoorAccuracy: notifyPoorAccuracy ?? this.notifyPoorAccuracy,
        notifyWeakSignal: notifyWeakSignal ?? this.notifyWeakSignal,
        notifyDrift: notifyDrift ?? this.notifyDrift,
        notifyEnvironmentChanges:
            notifyEnvironmentChanges ?? this.notifyEnvironmentChanges,
        notifyGoodConditions: notifyGoodConditions ?? this.notifyGoodConditions,
        notifyRecommendations:
            notifyRecommendations ?? this.notifyRecommendations,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      );
}

/// GPS notification statistics
@immutable
class GpsNotificationStatistics {
  const GpsNotificationStatistics({
    required this.totalNotifications,
    required this.notificationsByType,
    required this.activeNotifications,
    required this.lastNotificationTimes,
    required this.timestamp,
  });

  final int totalNotifications;
  final Map<GpsNotificationType, int> notificationsByType;
  final int activeNotifications;
  final Map<GpsNotificationType, DateTime> lastNotificationTimes;
  final DateTime timestamp;
}

/// Types of GPS notifications
enum GpsNotificationType {
  poorAccuracy,
  weakSignal,
  drift,
  environmentChange,
  excellentAccuracy,
  recommendation;

  String get description {
    switch (this) {
      case GpsNotificationType.poorAccuracy:
        return 'Poor GPS Accuracy';
      case GpsNotificationType.weakSignal:
        return 'Weak GPS Signal';
      case GpsNotificationType.drift:
        return 'GPS Drift';
      case GpsNotificationType.environmentChange:
        return 'Environment Change';
      case GpsNotificationType.excellentAccuracy:
        return 'Excellent GPS Accuracy';
      case GpsNotificationType.recommendation:
        return 'GPS Recommendation';
    }
  }
}

/// Notification priority levels
enum NotificationPriority {
  low,
  medium,
  high,
  critical;
}

/// Available notification actions
enum NotificationAction {
  moveToOpenArea,
  checkSettings,
  restartGps,
  calibrateCompass,
  adjustSettings,
  viewTips,
  startTracking;

  String get description {
    switch (this) {
      case NotificationAction.moveToOpenArea:
        return 'Move to Open Area';
      case NotificationAction.checkSettings:
        return 'Check Settings';
      case NotificationAction.restartGps:
        return 'Restart GPS';
      case NotificationAction.calibrateCompass:
        return 'Calibrate Compass';
      case NotificationAction.adjustSettings:
        return 'Adjust Settings';
      case NotificationAction.viewTips:
        return 'View Tips';
      case NotificationAction.startTracking:
        return 'Start Tracking';
    }
  }
}
