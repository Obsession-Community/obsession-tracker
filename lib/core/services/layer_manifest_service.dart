import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:obsession_tracker/core/config/bff_config.dart';
import 'package:obsession_tracker/core/models/layer_manifest.dart';
import 'package:obsession_tracker/core/services/device_registration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for fetching and caching layer manifests from the API.
///
/// This service provides access to the manifest-based download system
/// that supports both vector (GeoJSON) and raster (MBTiles) layers.
class LayerManifestService {
  LayerManifestService._();
  static final LayerManifestService instance = LayerManifestService._();

  static const String _cacheKey = 'layer_manifests_cache';
  static const String _cacheTimestampKey = 'layer_manifests_cache_timestamp';
  static const Duration _cacheDuration = Duration(hours: 1);

  AllManifestsResponse? _cachedManifests;
  DateTime? _cacheTimestamp;
  bool _initialized = false;

  /// Initialize the service and load cached data
  Future<void> initialize() async {
    if (_initialized) return;

    await _loadFromCache();
    _initialized = true;
    debugPrint('📋 LayerManifestService initialized');
  }

  /// Get all manifests, fetching from API if cache is stale
  Future<AllManifestsResponse?> getAllManifests({bool forceRefresh = false}) async {
    await initialize();

    // Check if cache is valid
    if (!forceRefresh && _cachedManifests != null && _cacheTimestamp != null) {
      final age = DateTime.now().difference(_cacheTimestamp!);
      if (age < _cacheDuration) {
        debugPrint('📋 Using cached manifests (age: ${age.inMinutes}m)');
        return _cachedManifests;
      }
    }

    // Fetch from API
    try {
      final response = await _fetchManifests();
      if (response != null) {
        _cachedManifests = response;
        _cacheTimestamp = DateTime.now();
        await _saveToCache();
        debugPrint('📋 Fetched ${response.states.length} state manifests from API');
      }
      return response;
    } catch (e) {
      debugPrint('📋 Error fetching manifests: $e');
      // Return cached data even if stale
      return _cachedManifests;
    }
  }

  /// Get manifest for a specific state
  Future<StateManifest?> getStateManifest(String stateCode) async {
    final manifests = await getAllManifests();
    return manifests?.getStateManifest(stateCode.toUpperCase());
  }

  /// Get available historical map layers for a state
  Future<List<LayerManifest>> getHistoricalMapLayers(String stateCode) async {
    final manifest = await getStateManifest(stateCode);
    return manifest?.historicalMapLayers ?? [];
  }

  /// Check if historical maps are available for a state
  Future<bool> hasHistoricalMaps(String stateCode) async {
    final layers = await getHistoricalMapLayers(stateCode);
    return layers.isNotEmpty;
  }

  /// Fetch manifests from the API
  Future<AllManifestsResponse?> _fetchManifests() async {
    const baseUrl = BFFConfig.productionEndpoint;
    final uri = Uri.parse('$baseUrl/api/v1/downloads/manifests');

    // Get API key for authentication
    final apiKey = await DeviceRegistrationService.instance.getApiKey();

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (apiKey != null) 'X-API-Key': apiKey,
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return AllManifestsResponse.fromJson(json);
    } else {
      debugPrint('📋 API returned ${response.statusCode}: ${response.body}');
      return null;
    }
  }

  /// Fetch manifest for a single state from the API
  Future<StateManifest?> fetchStateManifest(String stateCode) async {
    const baseUrl = BFFConfig.productionEndpoint;
    final uri = Uri.parse(
      '$baseUrl/api/v1/downloads/states/${stateCode.toUpperCase()}/manifest',
    );

    final apiKey = await DeviceRegistrationService.instance.getApiKey();

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (apiKey != null) 'X-API-Key': apiKey,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return StateManifest.fromJson(json);
      } else {
        debugPrint('📋 API returned ${response.statusCode} for $stateCode');
        return null;
      }
    } catch (e) {
      debugPrint('📋 Error fetching manifest for $stateCode: $e');
      return null;
    }
  }

  /// Load cached manifests from SharedPreferences
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      final timestamp = prefs.getInt(_cacheTimestampKey);

      if (cached != null && timestamp != null) {
        final json = jsonDecode(cached) as Map<String, dynamic>;
        _cachedManifests = AllManifestsResponse.fromJson(json);
        _cacheTimestamp = DateTime.fromMillisecondsSinceEpoch(timestamp);
        debugPrint('📋 Loaded manifests from cache');
      }
    } catch (e) {
      debugPrint('📋 Error loading cache: $e');
    }
  }

  /// Save manifests to SharedPreferences
  Future<void> _saveToCache() async {
    if (_cachedManifests == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_cachedManifests!.toJson());
      await prefs.setString(_cacheKey, json);
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('📋 Saved manifests to cache');
    } catch (e) {
      debugPrint('📋 Error saving cache: $e');
    }
  }

  /// Clear the cache
  Future<void> clearCache() async {
    _cachedManifests = null;
    _cacheTimestamp = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimestampKey);
    debugPrint('📋 Cache cleared');
  }

  /// Get states that have historical map layers available
  Future<List<String>> getStatesWithHistoricalMaps() async {
    final manifests = await getAllManifests();
    if (manifests == null) return [];

    return manifests.states
        .where((s) => s.historicalMapLayers.isNotEmpty)
        .map((s) => s.state)
        .toList();
  }
}
