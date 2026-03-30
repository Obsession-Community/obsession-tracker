import 'dart:convert';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:obsession_tracker/core/models/local_sync_models.dart';
import 'package:uuid/uuid.dart';

/// Manages sync sessions, tokens, and validation for local WiFi sync
class SyncSessionManager {
  factory SyncSessionManager() => _instance;
  SyncSessionManager._internal();
  static final SyncSessionManager _instance = SyncSessionManager._internal();

  final NetworkInfo _networkInfo = NetworkInfo();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final _random = Random.secure();

  SyncSession? _currentSession;
  final Set<String> _usedTokens = {};

  /// Default port for sync server
  static const int defaultPort = 8742;

  /// Get the current active session
  SyncSession? get currentSession => _currentSession;

  /// Check if there's an active session
  bool get hasActiveSession =>
      _currentSession != null && !_currentSession!.isExpired;

  /// Create a new sync session for sending data
  Future<SyncSession> createSession() async {
    final sessionId = const Uuid().v4();
    final sessionToken = _generateSecureToken();
    final deviceName = await _getDeviceName();
    final localIp = await _getLocalIpAddress();

    if (localIp == null) {
      throw const LocalSyncException(
        'Cannot determine local IP address. Make sure you are connected to WiFi.',
        SyncErrorType.networkError,
      );
    }

    _currentSession = SyncSession(
      sessionId: sessionId,
      sessionToken: sessionToken,
      senderIp: localIp,
      senderPort: defaultPort,
      timestamp: DateTime.now(),
      deviceName: deviceName,
    );

    _usedTokens.add(sessionToken);

    debugPrint(
        'Created sync session: $sessionId on $localIp:$defaultPort');

    return _currentSession!;
  }

  /// Validate an incoming session token
  bool validateToken(String sessionId, String token) {
    if (_currentSession == null) {
      debugPrint('No active session to validate against');
      return false;
    }

    if (_currentSession!.sessionId != sessionId) {
      debugPrint('Session ID mismatch');
      return false;
    }

    if (_currentSession!.sessionToken != token) {
      debugPrint('Token mismatch');
      return false;
    }

    if (_currentSession!.isExpired) {
      debugPrint('Session expired');
      return false;
    }

    return true;
  }

  /// End the current session
  void endSession() {
    if (_currentSession != null) {
      debugPrint('Ending sync session: ${_currentSession!.sessionId}');
      _currentSession = null;
    }
  }

  /// Check if the session has expired
  bool isSessionExpired() {
    return _currentSession?.isExpired ?? true;
  }

  /// Get time remaining for current session
  Duration? getTimeRemaining() {
    return _currentSession?.timeRemaining;
  }

  /// Generate a cryptographically secure token
  String _generateSecureToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Get the device name for display
  Future<String> _getDeviceName() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.name;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.model;
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        return macInfo.computerName;
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        return windowsInfo.computerName;
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        final linuxInfo = await _deviceInfo.linuxInfo;
        return linuxInfo.prettyName;
      }
    } catch (e) {
      debugPrint('Error getting device name: $e');
    }
    return 'Unknown Device';
  }

  /// Get the local IP address on the WiFi network
  Future<String?> _getLocalIpAddress() async {
    try {
      final wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP != null && _isPrivateIp(wifiIP)) {
        return wifiIP;
      }

      // Fallback: try to get any local IP
      debugPrint('WiFi IP not available or not private, trying fallback');
      return null;
    } catch (e) {
      debugPrint('Error getting local IP: $e');
      return null;
    }
  }

  /// Check if an IP address is in a private range (RFC 1918)
  bool _isPrivateIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    try {
      final first = int.parse(parts[0]);
      final second = int.parse(parts[1]);

      // 10.0.0.0 - 10.255.255.255
      if (first == 10) return true;

      // 172.16.0.0 - 172.31.255.255
      if (first == 172 && second >= 16 && second <= 31) return true;

      // 192.168.0.0 - 192.168.255.255
      if (first == 192 && second == 168) return true;

      // 169.254.0.0 - 169.254.255.255 (link-local)
      if (first == 169 && second == 254) return true;

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Validate that an IP is on the local network (same subnet assumption)
  bool isLocalNetworkIp(String ip) {
    return _isPrivateIp(ip);
  }

  /// Parse session from QR code data
  SyncSession? parseQrCode(String qrData) {
    try {
      return SyncSession.fromQrData(qrData);
    } catch (e) {
      debugPrint('Error parsing QR code: $e');
      return null;
    }
  }

  /// Validate a parsed session for connection
  LocalSyncException? validateSessionForConnection(SyncSession session) {
    // Check version compatibility
    if (session.version > SyncSession.currentVersion) {
      return const LocalSyncException(
        'Session version is newer than supported',
        SyncErrorType.versionMismatch,
      );
    }

    // Check if session is expired
    if (session.isExpired) {
      return const LocalSyncException(
        'Session has expired',
        SyncErrorType.sessionExpired,
      );
    }

    // Check if IP is on local network
    if (!isLocalNetworkIp(session.senderIp)) {
      return const LocalSyncException(
        'Sender IP is not on local network',
        SyncErrorType.networkError,
      );
    }

    return null;
  }

  /// Get current platform name
  String getPlatformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }
}
