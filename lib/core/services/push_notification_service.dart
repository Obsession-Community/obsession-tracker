import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:obsession_tracker/core/config/bff_config.dart';
import 'package:obsession_tracker/core/services/device_registration_service.dart';

/// Background message handler - must be top-level function
/// Note: With notification+data messages, FCM displays the notification directly.
/// This handler is called for data processing but notification is already shown.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background message received: ${message.messageId}');
  debugPrint('📬   notification: ${message.notification?.title}');
  debugPrint('📬   data: ${message.data}');
  // No need to show local notification - FCM shows it via notification payload
}

/// Data class for notification tap events
class NotificationTapEvent {
  final String? announcementId;
  final String? huntId;
  final String? type;
  final Map<String, dynamic> data;

  NotificationTapEvent({
    this.announcementId,
    this.huntId,
    this.type,
    required this.data,
  });

  factory NotificationTapEvent.fromData(Map<String, dynamic> data) {
    return NotificationTapEvent(
      announcementId: data['announcement_id'] as String?,
      huntId: data['hunt_id'] as String?,
      type: data['type'] as String?,
      data: data,
    );
  }
}

/// Privacy-first push notification service for announcements and hunts.
///
/// Key privacy features:
/// - Uses notification+data messages for reliable delivery and tap handling
/// - No analytics or tracking
/// - FCM token can be deleted for complete opt-out
class PushNotificationService {
  PushNotificationService._internal();
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  static PushNotificationService get instance => _instance;

  /// Test mode flag - when true, skips permission requests and Firebase initialization.
  /// Set this to true BEFORE calling initialize() in integration tests.
  static bool testMode = false;

  /// Global navigator key for deep linking from notifications
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  FirebaseMessaging? _messaging;
  String? _fcmToken;
  bool _initialized = false;
  bool _lastKnownPermissionGranted = false;

  // Stream controller for notification tap events
  final StreamController<NotificationTapEvent> _notificationTapController =
      StreamController<NotificationTapEvent>.broadcast();

  /// Stream of notification tap events for the app to listen to
  Stream<NotificationTapEvent> get onNotificationTap =>
      _notificationTapController.stream;

  /// Get the current FCM token (for debugging/testing)
  String? get fcmToken => _fcmToken;

  /// Check if service is initialized
  bool get isInitialized => _initialized;

  /// Initialize push notification service
  /// Call this after Firebase.initializeApp() in main.dart
  Future<void> initialize() async {
    if (_initialized) return;

    // Skip initialization in test mode to avoid permission dialogs
    if (testMode) {
      debugPrint('📬 Push notification service skipped (test mode)');
      _initialized = true;
      return;
    }

    try {
      _messaging = FirebaseMessaging.instance;

      // Configure iOS to show notifications when app is in foreground
      await _messaging!.setForegroundNotificationPresentationOptions(
        alert: true,
        sound: true,
      );

      // Initialize local notifications (for foreground on Android)
      await _initializeLocalNotifications();

      // Request permission (respects user choice)
      final settings = await _messaging!.requestPermission(
        badge: false, // Privacy: no badge count tracking
      );

      _lastKnownPermissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (_lastKnownPermissionGranted) {
        debugPrint('📬 Push notifications authorized');

        // Get FCM token (with APNS retry on iOS)
        _fcmToken = await _getTokenWithAPNSRetry();
        if (_fcmToken != null) {
          debugPrint('📬 FCM token: ${_fcmToken!.substring(0, 20)}...');
          // Sync token with BFF for push delivery
          _syncTokenWithBFF(_fcmToken!);
        } else {
          debugPrint('📬 Could not get FCM token - will retry on next app resume');
        }

        // Listen for token refresh
        _messaging!.onTokenRefresh.listen(_handleTokenRefresh);

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle notification taps (app in background)
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // Check for initial message (app launched from notification)
        final initialMessage = await _messaging!.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('📬 App launched from notification');
          // Delay to allow app to initialize
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleNotificationTap(initialMessage);
          });
        }
      } else {
        debugPrint('📬 Push notifications not authorized');
      }

      _initialized = true;
      debugPrint('✅ Push notification service initialized');
    } catch (e, stack) {
      debugPrint('❌ Push notification initialization error: $e');
      debugPrint('Stack: $stack');
    }
  }

  /// Initialize local notifications for showing data-only messages
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // Already requested via FCM
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Check if app was launched from a local notification tap
    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchDetails?.notificationResponse != null) {
      debugPrint('📬 App launched from local notification tap');
      // Delay to allow app to initialize before handling navigation
      Future.delayed(const Duration(milliseconds: 500), () {
        _onLocalNotificationTap(launchDetails!.notificationResponse!);
      });
    }

    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'obsession_announcements',
      'Announcements',
      description: 'Announcements and hunt updates from Obsession Tracker',
      importance: Importance.high,
      showBadge: false, // Privacy
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Handle token refresh
  void _handleTokenRefresh(String newToken) {
    debugPrint('📬 FCM token refreshed');
    _fcmToken = newToken;
    _syncTokenWithBFF(newToken);
  }

  /// Detect if running in a development/sandbox environment.
  /// Returns true for debug builds OR TestFlight/sandbox installs.
  Future<bool> _isDevEnvironment() async {
    // Debug builds are always development
    if (kDebugMode) return true;

    // On iOS, check for TestFlight/sandbox by examining the receipt URL
    if (Platform.isIOS) {
      try {
        const channel = MethodChannel('com.obsessiontracker.app/environment');
        final isSandbox = await channel.invokeMethod<bool>('isSandbox');
        return isSandbox ?? false;
      } catch (e) {
        // If method channel not available, check via receipt URL path
        // TestFlight receipts contain "sandboxReceipt" in the path
        debugPrint('📬 Environment check fallback (no native channel)');
        return false;
      }
    }

    // On Android, could check for debug signing or test track
    // For now, only debug builds are considered development
    return false;
  }

  /// Send FCM token to BFF for push notification delivery
  Future<void> _syncTokenWithBFF(String token) async {
    try {
      final apiKey = await DeviceRegistrationService.instance.getApiKey();
      if (apiKey == null) {
        debugPrint('📬 No API key available, skipping FCM token sync');
        return;
      }

      final baseUrl = BFFConfig.getBaseUrl();
      final isDev = await _isDevEnvironment();
      final environment = isDev ? 'development' : 'production';

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/devices/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
        body: jsonEncode({
          'fcm_token': token,
          'environment': environment,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('📬 FCM token synced with BFF (env: $environment)');
      } else {
        debugPrint('📬 FCM token sync failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('📬 FCM token sync error: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 Foreground message received');
    debugPrint('📬   notification: ${message.notification?.title}');
    debugPrint('📬   data: ${message.data}');

    // On iOS, setForegroundNotificationPresentationOptions shows the notification
    // On Android, we need to show a local notification for foreground messages
    if (Platform.isAndroid && message.notification != null) {
      _showLocalNotification({
        'title': message.notification!.title ?? 'Obsession Tracker',
        'body': message.notification!.body ?? '',
        ...message.data,
      });
    }
  }

  /// Show local notification from data payload
  Future<void> _showLocalNotification(Map<String, dynamic> data) async {
    final title = data['title'] as String? ?? 'Obsession Tracker';
    final body = data['body'] as String? ?? '';

    // Create payload for deep linking
    final payload = _encodePayload(data);

    const androidDetails = AndroidNotificationDetails(
      'obsession_announcements',
      'Announcements',
      channelDescription: 'Announcements and hunt updates from Obsession Tracker',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false, // Privacy
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Handle notification tap from FCM (background/terminated)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('📬 Notification tapped (FCM): ${message.data}');

    final event = NotificationTapEvent.fromData(
      message.data.map((k, v) => MapEntry(k, v as dynamic)),
    );
    _notificationTapController.add(event);
  }

  /// Handle local notification tap
  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('📬 Local notification tapped!');
    debugPrint('📬   actionId: ${response.actionId}');
    debugPrint('📬   payload: ${response.payload}');
    debugPrint('📬   notificationResponseType: ${response.notificationResponseType}');

    if (response.payload != null && response.payload!.isNotEmpty) {
      final data = _decodePayload(response.payload!);
      debugPrint('📬   decoded data: $data');
      final event = NotificationTapEvent.fromData(data);
      _notificationTapController.add(event);
    } else {
      debugPrint('📬   No payload in notification');
    }
  }

  /// Encode data map to payload string
  String _encodePayload(Map<String, dynamic> data) {
    // Simple encoding: key1=value1&key2=value2
    return data.entries
        .where((e) => e.value != null)
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
  }

  /// Decode payload string to data map
  Map<String, dynamic> _decodePayload(String payload) {
    final Map<String, dynamic> data = {};
    for (final part in payload.split('&')) {
      final kv = part.split('=');
      if (kv.length == 2) {
        data[Uri.decodeComponent(kv[0])] = Uri.decodeComponent(kv[1]);
      }
    }
    return data;
  }

  /// Check permission status when app resumes from background.
  /// Call this from your app's didChangeAppLifecycleState when state is resumed.
  Future<void> checkPermissionStatus() async {
    if (_messaging == null || !_initialized) return;

    try {
      final settings = await _messaging!.getNotificationSettings();
      final isNowGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (_lastKnownPermissionGranted && !isNowGranted) {
        // Permission was revoked - remove token from BFF
        debugPrint('📬 Permission revoked - removing FCM token from BFF');
        await _removeTokenFromBFF();
        _fcmToken = null;
        _lastKnownPermissionGranted = false;
      } else if (!_lastKnownPermissionGranted && isNowGranted) {
        // Permission was granted - register token with BFF
        debugPrint('📬 Permission granted - registering FCM token');
        _fcmToken = await _getTokenWithAPNSRetry();
        if (_fcmToken != null) {
          await _syncTokenWithBFF(_fcmToken!);
        }
        _lastKnownPermissionGranted = true;
      }
    } catch (e) {
      debugPrint('📬 Error checking permission status: $e');
    }
  }

  /// Get FCM token, waiting for APNS token on iOS if needed.
  /// iOS requires APNS token before FCM token can be generated.
  Future<String?> _getTokenWithAPNSRetry({int maxRetries = 5}) async {
    if (Platform.isIOS) {
      // On iOS, wait for APNS token to be available
      for (int i = 0; i < maxRetries; i++) {
        final apnsToken = await _messaging!.getAPNSToken();
        if (apnsToken != null) {
          debugPrint('📬 APNS token available, getting FCM token');
          return _messaging!.getToken();
        }
        debugPrint('📬 Waiting for APNS token (attempt ${i + 1}/$maxRetries)');
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      debugPrint('📬 APNS token not available after $maxRetries attempts');
      return null;
    }
    // Android doesn't need APNS
    return _messaging!.getToken();
  }

  /// Remove FCM token from BFF (called when user revokes permission)
  Future<void> _removeTokenFromBFF() async {
    try {
      final apiKey = await DeviceRegistrationService.instance.getApiKey();
      if (apiKey == null) {
        debugPrint('📬 No API key available, skipping FCM token removal');
        return;
      }

      final baseUrl = BFFConfig.getBaseUrl();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/devices/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
      );

      if (response.statusCode == 200) {
        debugPrint('📬 FCM token removed from BFF');
      } else {
        debugPrint('📬 FCM token removal failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('📬 FCM token removal error: $e');
    }
  }

  /// Delete FCM token (privacy - complete opt-out)
  Future<void> deleteToken() async {
    try {
      // Remove from BFF first
      await _removeTokenFromBFF();
      // Then delete from Firebase
      await _messaging?.deleteToken();
      _fcmToken = null;
      _lastKnownPermissionGranted = false;
      debugPrint('📬 FCM token deleted');
    } catch (e) {
      debugPrint('📬 Error deleting token: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _notificationTapController.close();
  }
}
