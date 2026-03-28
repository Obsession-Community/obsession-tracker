import 'dart:io';

import 'package:flutter/foundation.dart';

/// Service for detecting platform capabilities
/// Used to gracefully handle features that aren't available on all platforms
class PlatformService {
  factory PlatformService() => _instance ??= PlatformService._();
  PlatformService._();
  static PlatformService? _instance;

  /// Whether running on a desktop platform (macOS, Windows, Linux)
  bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  /// Whether running on a mobile platform (iOS, Android)
  bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  /// Whether running on macOS specifically
  bool get isMacOS {
    if (kIsWeb) return false;
    return Platform.isMacOS;
  }

  /// Platform name for API calls and logging
  String get platformName {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Whether GPS tracking is available on this platform
  /// Desktop devices don't have GPS hardware
  bool get supportsGpsTracking => isMobile;

  /// Whether live location updates are available
  bool get supportsLiveLocation => isMobile;

  /// Whether background location tracking is available
  bool get supportsBackgroundLocation => isMobile;

  /// Whether camera capture is available
  /// Desktop can import photos but not capture with camera widget
  bool get supportsCamera => isMobile;

  /// Whether native in-app purchases are available
  /// Desktop platforms may have different store integrations
  bool get supportsInAppPurchase {
    if (kIsWeb) return false;
    // iOS, Android, and macOS all support StoreKit/Play Billing
    return Platform.isIOS || Platform.isAndroid || Platform.isMacOS;
  }

  /// Whether biometric authentication is available
  bool get supportsBiometricAuth => isMobile || Platform.isMacOS;

  /// Whether accelerometer/compass sensors are available
  bool get supportsSensors => isMobile;

  /// Whether push notifications are available
  bool get supportsPushNotifications => isMobile;

  /// Whether background tasks (workmanager) are available
  bool get supportsBackgroundTasks => isMobile;

  /// Whether the platform uses App Store (iOS/macOS)
  bool get isAppStore {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

  /// Whether the platform uses Google Play (Android)
  bool get isPlayStore {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  /// Get a user-friendly platform display name
  String get displayName {
    if (kIsWeb) return 'Web';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}
