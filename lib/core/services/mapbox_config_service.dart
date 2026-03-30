import 'package:flutter/services.dart';

/// Service to read Mapbox configuration from native platform
class MapboxConfigService {
  static const MethodChannel _channel = MethodChannel('obsession_tracker/mapbox');

  static String? _cachedToken;

  /// Get the Mapbox access token from native platform configuration
  ///
  /// On iOS: Reads from Info.plist (MBXAccessToken)
  /// On Android: Reads from AndroidManifest.xml meta-data (MAPBOX_ACCESS_TOKEN)
  /// Token provided via --dart-define=MAPBOX_ACCESS_TOKEN=your_token
  static const String _envToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  static Future<String?> getAccessToken() async {
    // Return cached token if available
    if (_cachedToken != null) {
      return _cachedToken;
    }

    try {
      // Try to get from platform channel first
      final token = await _channel.invokeMethod<String>('getAccessToken');
      if (token != null && token.isNotEmpty) {
        _cachedToken = token;
        return token;
      }
    } catch (e) {
      // Platform channel not available, use compile-time token
    }

    // Use token from --dart-define
    if (_envToken.isNotEmpty) {
      _cachedToken = _envToken;
      return _cachedToken;
    }

    return null;
  }

  /// Clear cached token (useful for testing)
  static void clearCache() {
    _cachedToken = null;
  }
}
