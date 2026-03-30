import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:obsession_tracker/core/config/bff_config.dart';
import 'package:obsession_tracker/core/models/public_hunt.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of fetching public hunts
class PublicHuntsFetchResult {
  final List<PublicHunt> hunts;
  final bool success;
  final String? error;

  const PublicHuntsFetchResult({
    required this.hunts,
    required this.success,
    this.error,
  });

  factory PublicHuntsFetchResult.success(List<PublicHunt> hunts) {
    return PublicHuntsFetchResult(
      hunts: hunts,
      success: true,
    );
  }

  factory PublicHuntsFetchResult.failure(String error) {
    return PublicHuntsFetchResult(
      hunts: [],
      success: false,
      error: error,
    );
  }
}

/// Result of fetching a single hunt
class PublicHuntFetchResult {
  final PublicHunt? hunt;
  final bool success;
  final String? error;

  const PublicHuntFetchResult({
    this.hunt,
    required this.success,
    this.error,
  });

  factory PublicHuntFetchResult.success(PublicHunt hunt) {
    return PublicHuntFetchResult(
      hunt: hunt,
      success: true,
    );
  }

  factory PublicHuntFetchResult.failure(String error) {
    return PublicHuntFetchResult(
      success: false,
      error: error,
    );
  }
}

/// Service for fetching public hunts from the BFF /hunts endpoint.
///
/// This service:
/// - Fetches all active/featured hunts for discovery
/// - Fetches individual hunt details by slug
class PublicHuntsApiService {
  PublicHuntsApiService._internal();
  static final PublicHuntsApiService _instance = PublicHuntsApiService._internal();
  static PublicHuntsApiService get instance => _instance;

  static const Duration _fetchTimeout = Duration(seconds: 15);

  /// Get the hunts endpoint URL
  static String getHuntsEndpoint([String? customEndpoint]) {
    final endpoint = (customEndpoint == null || customEndpoint.trim().isEmpty)
        ? null
        : customEndpoint.trim();

    if (endpoint != null) {
      if (endpoint.startsWith('http')) {
        // In release mode, force production for non-production endpoints
        if (kReleaseMode && !endpoint.contains('api.obsessiontracker.com')) {
          return '${BFFConfig.productionEndpoint}/hunts';
        }
        if (endpoint.endsWith('/graphql')) {
          return endpoint.replaceAll('/graphql', '/hunts');
        } else if (endpoint.endsWith('/config')) {
          return endpoint.replaceAll('/config', '/hunts');
        } else if (!endpoint.endsWith('/hunts')) {
          return '$endpoint/hunts';
        }
        return endpoint;
      }
      switch (endpoint.toLowerCase()) {
        case 'production':
        case 'prod':
        default:
          return '${BFFConfig.productionEndpoint}/hunts';
      }
    }

    return '${BFFConfig.productionEndpoint}/hunts';
  }

  /// Fetch all active/featured public hunts from BFF.
  ///
  /// The BFF returns hunts that are:
  /// - Status: active, upcoming, or found (not draft or archived)
  ///
  /// Parameters:
  /// - [customEndpoint]: Optional custom API endpoint
  /// - [featuredOnly]: Only return featured hunts
  /// - [status]: Filter by status (active, upcoming, found)
  /// - [limit]: Maximum number of hunts to return
  Future<PublicHuntsFetchResult> fetchHunts({
    String? customEndpoint,
    bool? featuredOnly,
    String? status,
    int limit = 50,
  }) async {
    try {
      final endpoint = getHuntsEndpoint(customEndpoint);

      // Build query parameters
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };

      if (featuredOnly == true) {
        queryParams['featured'] = 'true';
      }

      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
      debugPrint('🎯 Fetching public hunts from: $uri');

      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(_fetchTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List<dynamic>;
        final hunts = json
            .map((item) => PublicHunt.fromJson(item as Map<String, dynamic>))
            .toList();

        debugPrint('🎯 Fetched ${hunts.length} public hunts');
        return PublicHuntsFetchResult.success(hunts);
      } else {
        debugPrint('❌ Public hunts API returned ${response.statusCode}');
        return PublicHuntsFetchResult.failure(
          'Server returned ${response.statusCode}',
        );
      }
    } on SocketException catch (e) {
      debugPrint('❌ Network error fetching public hunts: $e');
      return PublicHuntsFetchResult.failure('Network error');
    } on http.ClientException catch (e) {
      debugPrint('❌ HTTP error fetching public hunts: $e');
      return PublicHuntsFetchResult.failure('HTTP error');
    } catch (e) {
      debugPrint('❌ Error fetching public hunts: $e');
      return PublicHuntsFetchResult.failure(e.toString());
    }
  }

  /// Fetch a single hunt by slug.
  ///
  /// Returns full hunt details including media, links, and updates.
  Future<PublicHuntFetchResult> fetchHuntBySlug(
    String slug, {
    String? customEndpoint,
  }) async {
    try {
      final baseEndpoint = getHuntsEndpoint(customEndpoint);
      final uri = Uri.parse('$baseEndpoint/$slug');
      debugPrint('🎯 Fetching hunt by slug: $uri');

      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(_fetchTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final hunt = PublicHunt.fromJson(json);

        debugPrint('🎯 Fetched hunt: ${hunt.title}');
        return PublicHuntFetchResult.success(hunt);
      } else if (response.statusCode == 404) {
        debugPrint('❌ Hunt not found: $slug');
        return PublicHuntFetchResult.failure('Hunt not found');
      } else {
        debugPrint('❌ Public hunt API returned ${response.statusCode}');
        return PublicHuntFetchResult.failure(
          'Server returned ${response.statusCode}',
        );
      }
    } on SocketException catch (e) {
      debugPrint('❌ Network error fetching hunt: $e');
      return PublicHuntFetchResult.failure('Network error');
    } on http.ClientException catch (e) {
      debugPrint('❌ HTTP error fetching hunt: $e');
      return PublicHuntFetchResult.failure('HTTP error');
    } catch (e) {
      debugPrint('❌ Error fetching hunt: $e');
      return PublicHuntFetchResult.failure(e.toString());
    }
  }

  /// Get the custom endpoint from settings if available
  Future<String?> getCustomEndpoint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('customApiEndpoint');
    } catch (e) {
      return null;
    }
  }
}
