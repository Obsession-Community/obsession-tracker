import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:obsession_tracker/core/config/bff_config.dart';

/// Result of an NHP knock operation
class NhpKnockResult {
  const NhpKnockResult({
    required this.success,
    this.errorMessage,
    this.openTimeSeconds,
  });

  final bool success;
  final String? errorMessage;
  final int? openTimeSeconds;

  factory NhpKnockResult.fromJson(Map<String, dynamic> json) {
    return NhpKnockResult(
      success: json['success'] == true,
      errorMessage: json['error'] as String? ?? json['message'] as String?,
      openTimeSeconds: json['open_time'] as int? ?? json['expires_in'] as int?,
    );
  }
}

/// Service for managing NHP (Network-resource Hiding Protocol) access
/// for premium download server authentication.
///
/// This service handles "knocking" the download server to whitelist
/// the device's IP address before downloading premium offline map data.
///
/// The NHP protocol provides "true invisibility" - the download server
/// is completely invisible to non-authenticated users (returns no response).
///
/// ## How It Works
///
/// 1. App calls [knockForDownloads] with device credentials
/// 2. NHP server validates subscription via tracker-api
/// 3. If premium, device's IP is whitelisted for 1 hour
/// 4. Downloads from [getStateDownloadUrl] now work
///
/// ## Subdomain Strategy
///
/// - `api.obsessiontracker.com` - REST API for subscription validation
/// - `downloads.obsessiontracker.com` - NHP-protected download server
class NhpDownloadService {
  NhpDownloadService._();
  static final NhpDownloadService instance = NhpDownloadService._();

  /// Timestamp of last successful knock (for caching)
  DateTime? _lastKnockTime;

  /// Downloads server host (NHP-protected)
  static const String _downloadsServerHost = 'downloads.obsessiontracker.com';

  /// Knock endpoint URL
  static const String _knockUrl = 'https://$_downloadsServerHost/knock';

  /// Feature flag for NHP downloads (can be toggled for gradual rollout)
  /// Set to true to enable NHP downloads, false to use BFF fallback
  static bool nhpDownloadsEnabled = true;

  /// Check if NHP downloads are enabled
  bool get isNhpDownloadsEnabled => nhpDownloadsEnabled;

  /// Check if we have a valid (non-expired) knock
  bool get hasValidKnock {
    if (_lastKnockTime == null) return false;
    final elapsed = DateTime.now().difference(_lastKnockTime!);
    // Consider knock valid if less than 50 minutes old (safety margin)
    return elapsed < const Duration(minutes: 50);
  }

  /// Knock the download server to whitelist this device's IP
  ///
  /// This must be called before attempting to download from the
  /// NHP-protected download server. After a successful knock,
  /// the device's IP will be whitelisted for 1 hour.
  ///
  /// Parameters:
  /// - [deviceId]: The device's unique identifier (for subscription lookup)
  /// - [apiKey]: The device's API key (for authentication)
  /// - [forceRefresh]: If true, ignores cached knock and performs new one
  ///
  /// Returns a [NhpKnockResult] indicating success or failure.
  Future<NhpKnockResult> knockForDownloads({
    required String deviceId,
    required String apiKey,
    bool forceRefresh = false,
  }) async {
    // Skip if NHP downloads disabled (use BFF fallback)
    if (!nhpDownloadsEnabled) {
      debugPrint('⚠️ NHP downloads disabled, using BFF proxy');
      return const NhpKnockResult(
        success: true,
        openTimeSeconds: 3600,
      );
    }

    // Use cached knock if still valid
    if (!forceRefresh && hasValidKnock) {
      debugPrint('🔐 Using cached NHP knock (still valid)');
      return const NhpKnockResult(
        success: true,
        openTimeSeconds: 3600,
      );
    }

    try {
      debugPrint('🔐 Knocking NHP download server for device: $deviceId');

      final response = await http.get(
        Uri.parse(_knockUrl),
        headers: {
          'X-Device-ID': deviceId,
          'X-API-Key': apiKey,
        },
      ).timeout(const Duration(seconds: 30));

      debugPrint('🔐 Knock response: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final result = NhpKnockResult.fromJson(json);

          if (result.success) {
            _lastKnockTime = DateTime.now();
            debugPrint('✅ NHP knock successful - IP whitelisted for ${result.openTimeSeconds}s');
          } else {
            debugPrint('❌ NHP knock failed: ${result.errorMessage}');
          }

          return result;
        } catch (e) {
          debugPrint('⚠️ Failed to parse knock response: $e');
          // If we got 200 but can't parse, assume success
          _lastKnockTime = DateTime.now();
          return const NhpKnockResult(
            success: true,
            openTimeSeconds: 3600,
          );
        }
      } else if (response.statusCode == 403) {
        return const NhpKnockResult(
          success: false,
          errorMessage: 'Premium subscription required for offline downloads',
        );
      } else if (response.statusCode == 401) {
        return const NhpKnockResult(
          success: false,
          errorMessage: 'Invalid device credentials',
        );
      } else if (response.statusCode == 0 || response.statusCode == 444) {
        // 444 = nginx silent close (invisibility mode)
        return const NhpKnockResult(
          success: false,
          errorMessage: 'Download server unavailable',
        );
      } else {
        return NhpKnockResult(
          success: false,
          errorMessage: 'Knock failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('❌ NHP knock error: $e');
      return NhpKnockResult(
        success: false,
        errorMessage: 'Network error: $e',
      );
    }
  }

  /// Get the base URL for downloads
  ///
  /// Returns NHP server if enabled, BFF otherwise.
  String getDownloadsBaseUrl() {
    if (!nhpDownloadsEnabled) {
      return '${BFFConfig.productionEndpoint}/api/v1/downloads';
    }
    return 'https://$_downloadsServerHost';
  }

  /// Get the full URL for a state data download
  ///
  /// Parameters:
  /// - [stateCode]: Two-letter state code (e.g., 'UT', 'CO')
  /// - [dataType]: Type of data ('land', 'trails', 'historical')
  String getStateDownloadUrl(String stateCode, String dataType) {
    if (!nhpDownloadsEnabled) {
      // BFF endpoint format
      return '${BFFConfig.productionEndpoint}/api/v1/downloads/states/${stateCode.toUpperCase()}/$dataType';
    }
    // NHP server format (files have .zip extension)
    return 'https://$_downloadsServerHost/states/${stateCode.toUpperCase()}/$dataType.zip';
  }

  /// Clear cached knock (force re-authentication on next download)
  void clearKnockCache() {
    _lastKnockTime = null;
    debugPrint('🔐 NHP knock cache cleared');
  }
}

/// Exception thrown when subscription is required but not active
class SubscriptionRequiredException implements Exception {
  const SubscriptionRequiredException([this.message = 'Premium subscription required']);
  final String message;

  @override
  String toString() => message;
}

/// Exception thrown when NHP knock fails
class NhpKnockException implements Exception {
  const NhpKnockException(this.message);
  final String message;

  @override
  String toString() => 'NHP knock failed: $message';
}
