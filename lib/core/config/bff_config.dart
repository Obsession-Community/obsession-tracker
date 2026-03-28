import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration for BFF (Backend-for-Frontend) REST API service
/// Uses droplet-hosted tracker-api service
class BFFConfig {
  // Production endpoint (Droplet - tracker-api service)
  static const String productionEndpoint = 'https://api.obsessiontracker.com';

  // SharedPreferences key for dev data toggle
  static const String _useDevDataKey = 'bff_use_dev_data';

  // In-memory cache for dev data setting (to avoid async calls everywhere)
  static bool _useDevDataCached = false;

  /// Whether to use dev data from R2 (only available in debug builds)
  /// When true, downloads use dev/ prefix in R2 bucket
  static bool get useDevData => kDebugMode && _useDevDataCached;

  /// Initialize the dev data setting from SharedPreferences
  /// Should be called during app startup
  static Future<void> initializeDevDataSetting() async {
    if (!kDebugMode) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _useDevDataCached = prefs.getBool(_useDevDataKey) ?? false;
      debugPrint('🔧 BFFConfig: useDevData = $_useDevDataCached');
    } catch (e) {
      debugPrint('🔧 BFFConfig: Error loading dev data setting: $e');
    }
  }

  /// Set the dev data preference (only works in debug builds)
  static Future<void> setUseDevData(bool value) async {
    if (!kDebugMode) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_useDevDataKey, value);
      _useDevDataCached = value;
      debugPrint('🔧 BFFConfig: useDevData set to $value');
    } catch (e) {
      debugPrint('🔧 BFFConfig: Error saving dev data setting: $e');
    }
  }

  /// Get the base API URL - always returns production endpoint
  static String getBaseUrl([String? _]) {
    // Always use production - custom endpoints no longer supported
    return productionEndpoint;
  }

  /// Get the health check endpoint
  static String getHealthEndpoint([String? _]) {
    return '$productionEndpoint/health';
  }

  /// Get the traditional health endpoint (backwards compatibility)
  static String get healthEndpoint => getHealthEndpoint();

  /// Configuration for spatial queries
  static const int defaultSpatialQueryLimit = 50;
  static const int maxSpatialQueryLimit = 10000;
  static const Duration queryTimeout = Duration(seconds: 15); // Extended for spotty connectivity

  /// Performance monitoring flags
  static const bool enablePerformanceMonitoring = true;
  static const bool logApiQueries = kDebugMode; // Only in debug mode

  /// Network configuration
  static const Duration networkTimeout = Duration(seconds: 30);
  static const int maxRetryAttempts = 3;

  /// Environment detection helpers
  static bool get isDevelopment => kDebugMode;
  static bool get isProduction => kReleaseMode;

  /// Get display name for current environment
  static String get environmentName {
    if (kDebugMode) return 'Development';
    if (kReleaseMode) return 'Production';
    return 'Unknown';
  }

  /// Get base URL without path for display purposes
  static String get baseUrl => productionEndpoint;
}
