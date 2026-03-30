import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:obsession_tracker/core/config/bff_config.dart';
import 'package:obsession_tracker/core/utils/app_logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

/// Service for managing device registration and API key authentication
///
/// This service:
/// - Generates a unique device ID on first launch
/// - Registers the device with the BFF server
/// - Stores and manages the API key securely
/// - Provides entitlements information based on subscription tier
class DeviceRegistrationService {
  DeviceRegistrationService._internal();
  static final DeviceRegistrationService _instance =
      DeviceRegistrationService._internal();
  static DeviceRegistrationService get instance => _instance;

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    // macOS: Use default options - _safeWrite handles duplicate item errors
  );

  /// Safe write that handles existing keychain items on macOS
  /// Deletes the key first to avoid -25299 duplicate item errors
  static Future<void> _safeWrite(String key, String? value) async {
    if (value == null) return;

    try {
      // On macOS, delete first to avoid duplicate item errors
      await _secureStorage.delete(key: key);
    } catch (_) {
      // Ignore delete errors - key may not exist
    }

    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      // If write still fails, try deleteAll and write again (last resort)
      debugPrint('⚠️ Keychain write failed for $key: $e');
      debugPrint('⚠️ Keychain may need manual reset via Keychain Access app');
    }
  }

  static const _deviceIdKey = 'obsession_device_id';
  static const _apiKeyKey = 'obsession_api_key';
  static const _entitlementsKey = 'obsession_entitlements';
  static const _tierKey = 'obsession_tier';
  static const _registeredEndpointKey = 'obsession_registered_endpoint';
  static const _entitlementsCachedAtKey = 'obsession_entitlements_cached_at';

  // SECURITY: Maximum age for cached premium entitlements (7 days)
  // After this, must re-verify with server
  static const Duration _maxEntitlementsCacheAge = Duration(days: 7);

  String? _cachedApiKey;
  String? _cachedDeviceId;
  DeviceEntitlements? _cachedEntitlements;
  String? _cachedTier;
  bool _initialized = false;
  bool _mockMode = false;

  /// Initialize the service and ensure device is registered
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Try to load cached values first
      _cachedDeviceId = await _secureStorage.read(key: _deviceIdKey);
      _cachedApiKey = await _secureStorage.read(key: _apiKeyKey);
      final registeredEndpoint = await _secureStorage.read(key: _registeredEndpointKey);

      final cachedTier = await _secureStorage.read(key: _tierKey);
      final cachedEntitlements = await _secureStorage.read(key: _entitlementsKey);
      final cachedAtStr = await _secureStorage.read(key: _entitlementsCachedAtKey);

      // SECURITY: Check if cached entitlements have expired
      bool entitlementsExpired = false;
      if (cachedAtStr != null) {
        try {
          final cachedAt = DateTime.parse(cachedAtStr);
          final age = DateTime.now().difference(cachedAt);
          if (age > _maxEntitlementsCacheAge) {
            debugPrint('📱 Cached entitlements expired (${age.inDays} days old)');
            entitlementsExpired = true;
          }
        } catch (e) {
          // If we can't parse the date, treat as expired
          entitlementsExpired = true;
        }
      }

      if (cachedTier != null && !entitlementsExpired) {
        _cachedTier = cachedTier;
      }
      if (cachedEntitlements != null && !entitlementsExpired) {
        try {
          final decoded = jsonDecode(cachedEntitlements);
          if (decoded is Map<String, dynamic>) {
            _cachedEntitlements = DeviceEntitlements.fromJson(decoded);
          }
        } catch (e) {
          debugPrint('Failed to parse cached entitlements: $e');
        }
      } else if (entitlementsExpired) {
        // Clear expired entitlements - will fall back to free tier until refreshed
        _cachedTier = 'free';
        _cachedEntitlements = DeviceEntitlements.free();
        debugPrint('📱 Using free tier until entitlements are refreshed');
      }

      // If no device ID, generate one
      if (_cachedDeviceId == null) {
        _cachedDeviceId = const Uuid().v4();
        await _safeWrite(_deviceIdKey, _cachedDeviceId);
        debugPrint('📱 Generated new device ID: $_cachedDeviceId');
      }

      // Check if endpoint changed - if so, invalidate API key and re-register
      // Also invalidate if we have an API key but don't know what endpoint it was for
      // (happens when upgrading from old code that didn't track endpoints)
      final currentEndpoint = _getBaseUrl();
      if (_cachedApiKey != null) {
        if (registeredEndpoint == null) {
          debugPrint('🔄 API key exists but no registered endpoint stored (upgrade case)');
          debugPrint('🔄 Invalidating API key and re-registering with $currentEndpoint...');
          await _secureStorage.delete(key: _apiKeyKey);
          _cachedApiKey = null;
        } else if (registeredEndpoint != currentEndpoint) {
          debugPrint('🔄 BFF endpoint changed from $registeredEndpoint to $currentEndpoint');
          debugPrint('🔄 Invalidating API key and re-registering...');
          await _secureStorage.delete(key: _apiKeyKey);
          _cachedApiKey = null;
        }
      }

      // If no API key, register with server
      if (_cachedApiKey == null) {
        debugPrint('⚠️ No cached API key found - attempting device registration...');
        await _registerDevice();
        if (_cachedApiKey == null) {
          debugPrint('❌ Device registration did not return an API key!');
          debugPrint('❌ All BFF requests will fail with 401 Unauthorized');
        }
      } else {
        // SECURITY: Never log API keys, even partial values
        debugPrint('📱 Using cached API key');
        // Optionally refresh entitlements in background
        _refreshEntitlementsInBackground();
      }

      _initialized = true;
    } catch (e) {
      AppLogger.error('Failed to initialize device registration', e);
      // Still mark as initialized so app can work offline
      _initialized = true;
    }
  }

  /// Get the API key for authenticated requests
  Future<String?> getApiKey() async {
    if (!_initialized) {
      await initialize();
    }
    return _cachedApiKey;
  }

  /// Get the device ID
  Future<String?> getDeviceId() async {
    if (!_initialized) {
      await initialize();
    }
    return _cachedDeviceId;
  }

  /// Get current subscription tier
  String get tier => _cachedTier ?? 'free';

  /// Get current entitlements
  DeviceEntitlements get entitlements =>
      _cachedEntitlements ?? DeviceEntitlements.free();

  /// Check if a specific feature is available
  bool hasFeature(Feature feature) {
    return switch (feature) {
      Feature.basicMap => entitlements.basicMap,
      Feature.federalLands => entitlements.federalLands,
      Feature.stateLands => entitlements.stateLands,
      Feature.trails => entitlements.trails,
      Feature.detailedMarkers => entitlements.detailedMarkers,
    };
  }

  /// Get the base URL for API calls
  /// Always uses production endpoint (Cloudflare Workers)
  String _getBaseUrl() {
    return BFFConfig.getBaseUrl();
  }

  /// Register device with the BFF server
  Future<void> _registerDevice() async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final packageInfo = await PackageInfo.fromPlatform();

      final baseUrl = _getBaseUrl();
      debugPrint('📱 Registering device at: $baseUrl/api/v1/devices/register');

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/devices/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': _cachedDeviceId,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'app_version': '${packageInfo.version}+${packageInfo.buildNumber}',
          'device_model': deviceInfo.model,
          'os_version': deviceInfo.osVersion,
        }),
      );

      // Accept both 200 (OK) and 201 (Created) as success
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _cachedApiKey = data['api_key'] as String?;
        _cachedTier = (data['tier'] as String?) ?? 'free';

        final entitlementsData = data['entitlements'];
        if (entitlementsData is Map<String, dynamic>) {
          _cachedEntitlements = DeviceEntitlements.fromJson(entitlementsData);
        } else {
          _cachedEntitlements = DeviceEntitlements.free();
        }

        // Store securely (using _safeWrite to handle macOS keychain issues)
        await _safeWrite(_apiKeyKey, _cachedApiKey);
        await _safeWrite(_tierKey, _cachedTier);
        await _safeWrite(
          _entitlementsKey,
          jsonEncode(_cachedEntitlements!.toJson()),
        );
        // Store the endpoint this key was registered with
        await _safeWrite(_registeredEndpointKey, baseUrl);
        // SECURITY: Store cache timestamp for expiration checking
        await _safeWrite(
          _entitlementsCachedAtKey,
          DateTime.now().toIso8601String(),
        );

        debugPrint('📱 Device registered successfully. Tier: $_cachedTier');
        // SECURITY: Never log API keys, even partial values
        debugPrint('📱 Registered endpoint: $baseUrl');
      } else {
        final errorBody = response.body;
        debugPrint('❌ Device registration failed: ${response.statusCode}');
        debugPrint('❌ Error body: $errorBody');
        debugPrint('❌ Request URL: $baseUrl/api/v1/devices/register');
        AppLogger.error(
            'Device registration failed: ${response.statusCode} - $errorBody');

        // Use free tier as fallback
        _cachedTier = 'free';
        _cachedEntitlements = DeviceEntitlements.free();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Device registration exception: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      AppLogger.error('Device registration error', e);
      // Use free tier as fallback for offline mode
      _cachedTier = 'free';
      _cachedEntitlements = DeviceEntitlements.free();
    }
  }

  /// Refresh entitlements from server (background operation)
  void _refreshEntitlementsInBackground() {
    Future.microtask(() async {
      try {
        final baseUrl = _getBaseUrl();

        final response = await http.get(
          Uri.parse('$baseUrl/api/v1/devices/me'),
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': _cachedApiKey!,
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          _cachedTier = (data['tier'] as String?) ?? 'free';

          final entitlementsData = data['entitlements'];
          if (entitlementsData is Map<String, dynamic>) {
            _cachedEntitlements = DeviceEntitlements.fromJson(entitlementsData);
          }

          // Update stored values
          await _safeWrite(_tierKey, _cachedTier);
          await _safeWrite(
            _entitlementsKey,
            jsonEncode(_cachedEntitlements!.toJson()),
          );
          // SECURITY: Update cache timestamp
          await _safeWrite(
            _entitlementsCachedAtKey,
            DateTime.now().toIso8601String(),
          );

          debugPrint('📱 Entitlements refreshed. Tier: $_cachedTier');
        }
      } catch (e) {
        // Silently fail - use cached values
        debugPrint('📱 Background entitlement refresh failed: $e');
      }
    });
  }

  /// Force refresh entitlements (call after subscription purchase)
  Future<void> refreshEntitlements() async {
    if (_cachedApiKey == null) {
      await initialize();
      return;
    }

    try {
      final baseUrl = _getBaseUrl();

      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/devices/me'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': _cachedApiKey!,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _cachedTier = (data['tier'] as String?) ?? 'free';

        final entitlementsData = data['entitlements'];
        if (entitlementsData is Map<String, dynamic>) {
          _cachedEntitlements = DeviceEntitlements.fromJson(entitlementsData);
        }

        await _safeWrite(_tierKey, _cachedTier);
        await _safeWrite(
          _entitlementsKey,
          jsonEncode(_cachedEntitlements!.toJson()),
        );
        // SECURITY: Update cache timestamp
        await _safeWrite(
          _entitlementsCachedAtKey,
          DateTime.now().toIso8601String(),
        );

        debugPrint('📱 Entitlements force refreshed. Tier: $_cachedTier');
      }
    } catch (e) {
      AppLogger.error('Failed to refresh entitlements', e);
    }
  }

  /// Enable mock mode for screenshots/testing
  /// Sets Pro entitlements without server registration
  void enableMockMode() {
    _mockMode = true;
    _cachedDeviceId = 'mock-device-id-screenshots';
    _cachedApiKey = 'mock-api-key-screenshots';
    _cachedTier = 'pro';
    _cachedEntitlements = DeviceEntitlements.pro();
    _initialized = true;
    debugPrint('📱 Mock mode enabled with Pro entitlements');
  }

  /// Disable mock mode
  void disableMockMode() {
    _mockMode = false;
    _cachedApiKey = null;
    _cachedTier = null;
    _cachedEntitlements = null;
    _initialized = false;
    debugPrint('📱 Mock mode disabled');
  }

  /// Switch from mock mode to real BFF mode with device registration
  ///
  /// Use this in integration tests when you need real BFF data.
  /// Call this AFTER setting the desired endpoint in SharedPreferences.
  /// This will register the device with the BFF and get a real API key.
  Future<void> switchToRealMode() async {
    _mockMode = false;
    _cachedApiKey = null;
    _cachedTier = null;
    _cachedEntitlements = null;
    _initialized = false;

    debugPrint('📱 Switching to real BFF mode...');

    // Re-initialize to register with the BFF
    await initialize();

    if (_cachedApiKey != null) {
      // SECURITY: Never log API keys, even partial values
      debugPrint('✅ Successfully registered with BFF');
    } else {
      debugPrint('❌ Failed to get API key from BFF - land/trail data will not load');
    }
  }

  /// Check if mock mode is enabled
  bool get isMockMode => _mockMode;

  /// Clear all stored credentials (for logout/reset)
  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _apiKeyKey);
    await _secureStorage.delete(key: _entitlementsKey);
    await _secureStorage.delete(key: _tierKey);
    await _secureStorage.delete(key: _registeredEndpointKey);
    // Keep device ID - it's tied to this installation

    _cachedApiKey = null;
    _cachedTier = 'free';
    _cachedEntitlements = DeviceEntitlements.free();
    _initialized = false;

    debugPrint('📱 Device credentials cleared');
  }

  /// Called when BFF endpoint is changed in settings
  /// Clears the API key and re-registers with the new endpoint
  Future<void> onEndpointChanged() async {
    debugPrint('🔄 BFF endpoint changed - re-registering device...');

    // Clear API key and registered endpoint
    await _secureStorage.delete(key: _apiKeyKey);
    await _secureStorage.delete(key: _registeredEndpointKey);
    _cachedApiKey = null;
    _initialized = false;

    // Re-initialize to register with new endpoint
    await initialize();

    debugPrint('🔄 Device re-registration complete');
  }

  /// Get device information
  Future<_DeviceInfo> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return _DeviceInfo(
        model: iosInfo.model,
        osVersion: 'iOS ${iosInfo.systemVersion}',
      );
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return _DeviceInfo(
        model: '${androidInfo.manufacturer} ${androidInfo.model}',
        osVersion: 'Android ${androidInfo.version.release}',
      );
    }

    return _DeviceInfo(model: 'Unknown', osVersion: 'Unknown');
  }
}

/// Simple device info container
class _DeviceInfo {
  final String model;
  final String osVersion;

  _DeviceInfo({required this.model, required this.osVersion});
}

/// Features that can be gated by subscription
enum Feature {
  basicMap,
  federalLands,
  stateLands,
  trails,
  detailedMarkers,
}

/// Entitlements based on subscription tier
class DeviceEntitlements {
  final bool basicMap;
  final bool federalLands;
  final bool stateLands;
  final bool trails;
  final bool detailedMarkers;
  final int maxOfflineRegions;

  const DeviceEntitlements({
    required this.basicMap,
    required this.federalLands,
    required this.stateLands,
    required this.trails,
    required this.detailedMarkers,
    required this.maxOfflineRegions,
  });

  /// Free tier entitlements
  factory DeviceEntitlements.free() => const DeviceEntitlements(
        basicMap: true,
        federalLands: false,
        stateLands: false,
        trails: false,
        detailedMarkers: false,
        maxOfflineRegions: 1,
      );

  /// Explorer tier entitlements ($4.99/mo)
  factory DeviceEntitlements.explorer() => const DeviceEntitlements(
        basicMap: true,
        federalLands: true,
        stateLands: false,
        trails: false,
        detailedMarkers: false,
        maxOfflineRegions: 5,
      );

  /// Pro tier entitlements ($9.99/mo)
  factory DeviceEntitlements.pro() => const DeviceEntitlements(
        basicMap: true,
        federalLands: true,
        stateLands: true,
        trails: true,
        detailedMarkers: true,
        maxOfflineRegions: 20,
      );

  factory DeviceEntitlements.fromJson(Map<String, dynamic> json) {
    return DeviceEntitlements(
      basicMap: (json['basic_map'] as bool?) ?? true,
      federalLands: (json['federal_lands'] as bool?) ?? false,
      stateLands: (json['state_lands'] as bool?) ?? false,
      trails: (json['trails'] as bool?) ?? false,
      detailedMarkers: (json['detailed_markers'] as bool?) ?? false,
      maxOfflineRegions: (json['max_offline_regions'] as int?) ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'basic_map': basicMap,
        'federal_lands': federalLands,
        'state_lands': stateLands,
        'trails': trails,
        'detailed_markers': detailedMarkers,
        'max_offline_regions': maxOfflineRegions,
      };

  @override
  String toString() =>
      'DeviceEntitlements(federalLands: $federalLands, stateLands: $stateLands, trails: $trails)';
}
