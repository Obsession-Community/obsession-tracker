import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:obsession_tracker/core/config/bff_config.dart';
import 'package:obsession_tracker/core/models/bff_app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of fetching announcements
class AnnouncementsFetchResult {
  final List<Announcement> announcements;
  final bool success;
  final String? error;

  const AnnouncementsFetchResult({
    required this.announcements,
    required this.success,
    this.error,
  });

  factory AnnouncementsFetchResult.success(List<Announcement> announcements) {
    return AnnouncementsFetchResult(
      announcements: announcements,
      success: true,
    );
  }

  factory AnnouncementsFetchResult.failure(String error) {
    return AnnouncementsFetchResult(
      announcements: [],
      success: false,
      error: error,
    );
  }
}

/// Service for fetching announcements from the BFF /announcements endpoint.
///
/// This service:
/// - Fetches all active (published and not expired) announcements
/// - Supports platform filtering
/// - The BFF returns all active announcements, client handles caching/deduplication
class AnnouncementsApiService {
  AnnouncementsApiService._internal();
  static final AnnouncementsApiService _instance = AnnouncementsApiService._internal();
  static AnnouncementsApiService get instance => _instance;

  static const String _firstLaunchDateKey = 'first_launch_date';
  static const String _lastFetchDateKey = 'announcements_last_fetch_date';
  static const Duration _fetchTimeout = Duration(seconds: 10);

  DateTime? _cachedFirstLaunchDate;
  DateTime? _cachedLastFetchDate;

  /// Get the announcements endpoint URL
  static String getAnnouncementsEndpoint([String? customEndpoint]) {
    final endpoint = (customEndpoint == null || customEndpoint.trim().isEmpty)
        ? null
        : customEndpoint.trim();

    if (endpoint != null) {
      if (endpoint.startsWith('http')) {
        // In release mode, force production for non-production endpoints
        if (kReleaseMode && !endpoint.contains('api.obsessiontracker.com')) {
          return '${BFFConfig.productionEndpoint}/announcements';
        }
        if (endpoint.endsWith('/graphql')) {
          return endpoint.replaceAll('/graphql', '/announcements');
        } else if (endpoint.endsWith('/config')) {
          return endpoint.replaceAll('/config', '/announcements');
        } else if (!endpoint.endsWith('/announcements')) {
          return '$endpoint/announcements';
        }
        return endpoint;
      }
      switch (endpoint.toLowerCase()) {
        case 'production':
        case 'prod':
        default:
          return '${BFFConfig.productionEndpoint}/announcements';
      }
    }

    return '${BFFConfig.productionEndpoint}/announcements';
  }

  /// Get the first launch date, initializing if needed.
  ///
  /// The first time this is called, it records the current date as the
  /// first launch date. Subsequent calls return the stored date.
  Future<DateTime> getFirstLaunchDate() async {
    // Return cached value if available
    if (_cachedFirstLaunchDate != null) {
      return _cachedFirstLaunchDate!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedDate = prefs.getString(_firstLaunchDateKey);

      if (storedDate != null) {
        _cachedFirstLaunchDate = DateTime.parse(storedDate);
        debugPrint('📢 First launch date loaded: $_cachedFirstLaunchDate');
        return _cachedFirstLaunchDate!;
      }

      // First time user - store the current date
      final now = DateTime.now().toUtc();
      await prefs.setString(_firstLaunchDateKey, now.toIso8601String());
      _cachedFirstLaunchDate = now;
      debugPrint('📢 First launch date set: $now');
      return now;
    } catch (e) {
      debugPrint('❌ Failed to get/set first launch date: $e');
      // Return current time as fallback (will show all announcements)
      return DateTime.now().toUtc();
    }
  }

  /// Get the last successful fetch date.
  ///
  /// Returns null if no successful fetch has occurred yet.
  Future<DateTime?> getLastFetchDate() async {
    // Return cached value if available
    if (_cachedLastFetchDate != null) {
      return _cachedLastFetchDate;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedDate = prefs.getString(_lastFetchDateKey);

      if (storedDate != null) {
        _cachedLastFetchDate = DateTime.parse(storedDate);
        debugPrint('📢 Last fetch date loaded: $_cachedLastFetchDate');
        return _cachedLastFetchDate;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Failed to get last fetch date: $e');
      return null;
    }
  }

  /// Update the last fetch date after a successful fetch.
  Future<void> updateLastFetchDate(DateTime fetchTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastFetchDateKey, fetchTime.toIso8601String());
      _cachedLastFetchDate = fetchTime;
      debugPrint('📢 Last fetch date updated: $fetchTime');
    } catch (e) {
      debugPrint('❌ Failed to update last fetch date: $e');
    }
  }

  /// Get the appropriate 'since' date for fetching announcements.
  ///
  /// Uses lastFetchDate if available, otherwise falls back to firstLaunchDate.
  Future<DateTime> getSinceDate() async {
    final lastFetch = await getLastFetchDate();
    if (lastFetch != null) {
      return lastFetch;
    }
    return getFirstLaunchDate();
  }

  /// Fetch all active announcements from BFF.
  ///
  /// The BFF returns all announcements that are:
  /// - Published (published_at <= now)
  /// - Not expired (expires_at is null or > now)
  ///
  /// The client handles caching, deduplication, and read/unread tracking.
  ///
  /// Parameters:
  /// - [customEndpoint]: Optional custom API endpoint
  /// - [platform]: Platform filter ('ios' or 'android')
  /// - [limit]: Maximum number of announcements to return
  Future<AnnouncementsFetchResult> fetchAnnouncements({
    String? customEndpoint,
    String? platform,
    int limit = 50,
  }) async {
    try {
      final endpoint = getAnnouncementsEndpoint(customEndpoint);
      final fetchTime = DateTime.now().toUtc();

      // Build query parameters
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };

      if (platform != null && platform.isNotEmpty) {
        queryParams['platform'] = platform;
      }

      final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
      debugPrint('📢 Fetching active announcements from: $uri');

      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(_fetchTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List<dynamic>;
        final announcements = json
            .map((item) => Announcement.fromApiJson(item as Map<String, dynamic>))
            .where((a) => !a.isExpired) // Filter expired locally too
            .toList();

        // Update last fetch date on success (for debugging/logging)
        await updateLastFetchDate(fetchTime);

        debugPrint('📢 Fetched ${announcements.length} active announcements');
        return AnnouncementsFetchResult.success(announcements);
      } else {
        debugPrint('❌ Announcements API returned ${response.statusCode}');
        return AnnouncementsFetchResult.failure(
          'Server returned ${response.statusCode}',
        );
      }
    } on SocketException catch (e) {
      debugPrint('❌ Network error fetching announcements: $e');
      return AnnouncementsFetchResult.failure('Network error');
    } on http.ClientException catch (e) {
      debugPrint('❌ HTTP error fetching announcements: $e');
      return AnnouncementsFetchResult.failure('HTTP error');
    } catch (e) {
      debugPrint('❌ Error fetching announcements: $e');
      return AnnouncementsFetchResult.failure(e.toString());
    }
  }

  /// Get the current platform string for API filtering
  String getCurrentPlatform() {
    if (Platform.isIOS) {
      return 'ios';
    } else if (Platform.isAndroid) {
      return 'android';
    }
    return '';
  }

  /// Clear cached data (for testing)
  Future<void> clearCache() async {
    _cachedFirstLaunchDate = null;
    _cachedLastFetchDate = null;
  }

  /// Reset first launch date (for testing/debugging)
  Future<void> resetFirstLaunchDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_firstLaunchDateKey);
      _cachedFirstLaunchDate = null;
      debugPrint('📢 First launch date reset');
    } catch (e) {
      debugPrint('❌ Failed to reset first launch date: $e');
    }
  }

  /// Reset last fetch date (for testing/debugging - forces full refetch)
  Future<void> resetLastFetchDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastFetchDateKey);
      _cachedLastFetchDate = null;
      debugPrint('📢 Last fetch date reset');
    } catch (e) {
      debugPrint('❌ Failed to reset last fetch date: $e');
    }
  }

  /// Reset all dates (for testing/debugging)
  Future<void> resetAllDates() async {
    await resetFirstLaunchDate();
    await resetLastFetchDate();
  }
}
