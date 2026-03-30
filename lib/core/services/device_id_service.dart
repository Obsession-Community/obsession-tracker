import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing a consistent device identifier
/// Used for privacy-preserving user tracking across app features
class DeviceIdService {
  factory DeviceIdService() => _instance ??= DeviceIdService._();
  DeviceIdService._();
  static DeviceIdService? _instance;

  String? _deviceId;
  static const String _deviceIdKey = 'device_id';

  /// Get the device ID (creates one if it doesn't exist)
  Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    // Try to load from shared preferences first
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_deviceIdKey);

    if (_deviceId != null) {
      debugPrint('📱 Loaded existing device ID: $_deviceId');
      return _deviceId!;
    }

    // Generate new device ID
    await _generateDeviceId();

    // Save to preferences
    await prefs.setString(_deviceIdKey, _deviceId!);
    debugPrint('📱 Generated and saved new device ID: $_deviceId');

    return _deviceId!;
  }

  Future<void> _generateDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ??
            'ios-${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        // systemGUID is persistent across app reinstalls (hardware-based)
        _deviceId = macInfo.systemGUID ??
            'macos-${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _deviceId = windowsInfo.deviceId;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        _deviceId = linuxInfo.machineId ??
            'linux-${DateTime.now().millisecondsSinceEpoch}';
      } else {
        _deviceId = 'device-${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      debugPrint('Error generating device ID: $e');
      _deviceId = 'fallback-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Clear the device ID (for testing or privacy reset)
  Future<void> clearDeviceId() async {
    _deviceId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
    debugPrint('📱 Device ID cleared');
  }
}
