import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:obsession_tracker/core/config/bff_config.dart';
import 'package:obsession_tracker/core/models/bff_app_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for fetching and caching BFF app configuration
///
/// This service fetches config from the database-independent /config endpoint
/// which works even during BFF database maintenance. Use this to:
/// - Check for required app updates (version enforcement)
/// - Handle maintenance mode gracefully
/// - Get dynamic links (Discord, support, etc.)
/// - Check feature flags
class BFFConfigService {
  BFFConfigService._internal();
  static final BFFConfigService _instance = BFFConfigService._internal();
  static BFFConfigService get instance => _instance;

  static const String _cacheKey = 'bff_app_config';
  static const String _cacheTimestampKey = 'bff_app_config_timestamp';
  static const String _acknowledgedLegalVersionKey = 'acknowledged_legal_version';

  /// Cache duration reduced to 15 minutes for more timely announcements
  /// Push notifications would eliminate the need for polling entirely
  static const Duration _cacheMaxAge = Duration(minutes: 15);
  static const Duration _fetchTimeout = Duration(seconds: 5);

  BFFAppConfig? _cachedConfig;
  DateTime? _lastFetchTime;

  /// Get the config endpoint URL
  /// Always uses production endpoint (Cloudflare Workers)
  static String getConfigEndpoint([String? _]) {
    return '${BFFConfig.productionEndpoint}/config';
  }

  /// Fetch config from BFF, falling back to cached config on failure
  ///
  /// This should be called during app startup before other BFF calls.
  /// The endpoint is database-independent, so it works during maintenance.
  Future<BFFAppConfig> fetchConfig({String? customEndpoint}) async {
    // Return cached config if still fresh
    if (_cachedConfig != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!) < _cacheMaxAge) {
        debugPrint('BFFConfigService: Using in-memory cached config');
        return _cachedConfig!;
      }
    }

    try {
      final endpoint = getConfigEndpoint(customEndpoint);
      final useDevData = BFFConfig.useDevData;
      debugPrint('BFFConfigService: Fetching config from $endpoint (dev: $useDevData)');

      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Accept': 'application/json',
          if (useDevData) 'X-Environment': 'dev',
        },
      ).timeout(_fetchTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final config = BFFAppConfig.fromJson(json);

        // Cache the config
        _cachedConfig = config;
        _lastFetchTime = DateTime.now();
        await _persistConfig(config);

        debugPrint('BFFConfigService: Config fetched successfully (v${config.apiVersion})');
        return config;
      } else {
        debugPrint('BFFConfigService: Server returned ${response.statusCode}');
        return await _getFallbackConfig();
      }
    } on SocketException catch (e) {
      debugPrint('BFFConfigService: Network error: $e');
      return _getFallbackConfig();
    } on http.ClientException catch (e) {
      debugPrint('BFFConfigService: HTTP error: $e');
      return _getFallbackConfig();
    } catch (e) {
      debugPrint('BFFConfigService: Error fetching config: $e');
      return _getFallbackConfig();
    }
  }

  /// Get fallback config (cached or defaults)
  Future<BFFAppConfig> _getFallbackConfig() async {
    // Try in-memory cache first
    if (_cachedConfig != null) {
      debugPrint('BFFConfigService: Using in-memory cache');
      return _cachedConfig!;
    }

    // Try persisted cache
    final cached = await _loadCachedConfig();
    if (cached != null) {
      _cachedConfig = cached;
      debugPrint('BFFConfigService: Using persisted cache');
      return cached;
    }

    // Fall back to defaults
    debugPrint('BFFConfigService: Using default config');
    return BFFAppConfig.defaults();
  }

  /// Persist config to SharedPreferences
  Future<void> _persistConfig(BFFAppConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(config.toJson()));
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('BFFConfigService: Error persisting config: $e');
    }
  }

  /// Load config from SharedPreferences
  Future<BFFAppConfig?> _loadCachedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_cacheKey);
      if (jsonString == null) return null;

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return BFFAppConfig.fromJson(json);
    } catch (e) {
      debugPrint('BFFConfigService: Error loading cached config: $e');
      return null;
    }
  }

  /// Check if app version is below minimum required version
  /// Returns true if user MUST update the app
  Future<bool> isUpdateRequired(BFFAppConfig config) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final minVersion = Platform.isIOS
        ? config.minAppVersion.ios
        : config.minAppVersion.android;

    return _isVersionLower(currentVersion, minVersion);
  }

  /// Check if app version is below recommended version
  /// Returns true if user SHOULD update (soft prompt)
  Future<bool> isUpdateRecommended(BFFAppConfig config) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final recommendedVersion = Platform.isIOS
        ? config.recommendedAppVersion.ios
        : config.recommendedAppVersion.android;

    return _isVersionLower(currentVersion, recommendedVersion);
  }

  /// Compare semantic versions
  /// Returns true if version1 < version2
  bool _isVersionLower(String version1, String version2) {
    try {
      final v1Parts = version1.split('.').map(int.parse).toList();
      final v2Parts = version2.split('.').map(int.parse).toList();

      // Pad shorter version with zeros
      while (v1Parts.length < 3) v1Parts.add(0);
      while (v2Parts.length < 3) v2Parts.add(0);

      for (var i = 0; i < 3; i++) {
        if (v1Parts[i] < v2Parts[i]) return true;
        if (v1Parts[i] > v2Parts[i]) return false;
      }
      return false; // Equal versions
    } catch (e) {
      debugPrint('BFFConfigService: Error comparing versions: $e');
      return false; // Assume no update needed on parse error
    }
  }

  /// Clear cached config (useful for testing)
  Future<void> clearCache() async {
    _cachedConfig = null;
    _lastFetchTime = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
    } catch (e) {
      debugPrint('BFFConfigService: Error clearing cache: $e');
    }
  }

  /// Get Discord link from config, with fallback
  String? getDiscordLink(BFFAppConfig config) {
    return config.links.discord;
  }

  /// Get support link from config, with fallback
  String getSupportLink(BFFAppConfig config) {
    return config.links.support ?? 'mailto:support@obsessiontracker.com';
  }

  /// Get privacy policy URL from config
  String getPrivacyUrl(BFFAppConfig config) {
    return config.links.privacy ?? 'https://obsessiontracker.com/privacy';
  }

  /// Get terms of service URL from config
  String getTermsUrl(BFFAppConfig config) {
    return config.links.terms ?? 'https://obsessiontracker.com/terms';
  }

  /// Get appropriate app store URL for current platform
  String? getAppStoreUrl(BFFAppConfig config) {
    return Platform.isIOS
        ? config.links.appStoreIos
        : config.links.appStoreAndroid;
  }

  /// Get non-expired announcements
  List<Announcement> getActiveAnnouncements(BFFAppConfig config) {
    return config.announcements.where((a) => !a.isExpired).toList();
  }

  /// Get the current server data version
  String getCurrentDataVersion(BFFAppConfig config) {
    return config.data.currentVersion;
  }

  /// Get the data source name
  String getDataSource(BFFAppConfig config) {
    return config.data.source;
  }

  /// Check if a local data version is outdated
  /// Returns true if the server has a newer version available
  bool isDataOutdated(BFFAppConfig config, String localVersion) {
    return config.data.isNewerThan(localVersion);
  }

  // ============================================================
  // Legal Version Management
  // ============================================================

  /// Check if user needs to acknowledge updated legal documents
  /// Returns true if the config has a legal version that the user hasn't acknowledged
  Future<bool> needsLegalAcknowledgment(BFFAppConfig config) async {
    // If no legal version in config, nothing to acknowledge
    if (!config.legal.hasVersion) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final acknowledgedVersion = prefs.getString(_acknowledgedLegalVersionKey);

      // If user hasn't acknowledged any version, they need to acknowledge
      if (acknowledgedVersion == null) return true;

      // If server version is different from acknowledged, show update notice
      return config.legal.version != acknowledgedVersion;
    } catch (e) {
      debugPrint('BFFConfigService: Error checking legal acknowledgment: $e');
      return false;
    }
  }

  /// Get the last acknowledged legal version
  Future<String?> getAcknowledgedLegalVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_acknowledgedLegalVersionKey);
    } catch (e) {
      debugPrint('BFFConfigService: Error getting acknowledged version: $e');
      return null;
    }
  }

  /// Mark the current legal version as acknowledged by the user
  Future<void> acknowledgeLegalVersion(BFFAppConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_acknowledgedLegalVersionKey, config.legal.version);
      debugPrint('BFFConfigService: Legal version ${config.legal.version} acknowledged');
    } catch (e) {
      debugPrint('BFFConfigService: Error acknowledging legal version: $e');
    }
  }

  /// Get the privacy URL, preferring legal config over links config
  String getLegalPrivacyUrl(BFFAppConfig config) {
    return config.legal.privacyUrl ??
        config.links.privacy ??
        'https://obsessiontracker.com/privacy.html';
  }

  /// Get the terms URL, preferring legal config over links config
  String getLegalTermsUrl(BFFAppConfig config) {
    return config.legal.termsUrl ??
        config.links.terms ??
        'https://obsessiontracker.com/terms.html';
  }

  /// Clear legal acknowledgment (useful for testing)
  Future<void> clearLegalAcknowledgment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_acknowledgedLegalVersionKey);
    } catch (e) {
      debugPrint('BFFConfigService: Error clearing legal acknowledgment: $e');
    }
  }
}
