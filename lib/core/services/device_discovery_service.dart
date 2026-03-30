import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Discovered device information
class DiscoveredDevice {
  final String name;
  final String ip;
  final int port;
  final String sessionId;
  final String sessionToken;
  final DateTime discoveredAt;

  DiscoveredDevice({
    required this.name,
    required this.ip,
    required this.port,
    required this.sessionId,
    required this.sessionToken,
    required this.discoveredAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice &&
          runtimeType == other.runtimeType &&
          sessionId == other.sessionId;

  @override
  int get hashCode => sessionId.hashCode;

  @override
  String toString() => 'DiscoveredDevice($name @ $ip:$port)';
}

/// Represents a device that was found but couldn't be fully resolved
/// Used to notify UI that QR code fallback may be needed
class UnresolvedDevice {
  final String name;
  final String? platform;
  final int resolutionAttempts;
  final DateTime foundAt;

  UnresolvedDevice({
    required this.name,
    this.platform,
    required this.resolutionAttempts,
    required this.foundAt,
  });

  @override
  String toString() => 'UnresolvedDevice($name, attempts: $resolutionAttempts)';
}

/// Service for mDNS-based device discovery
///
/// Sender mode: Advertises the sync service on the local network
/// Receiver mode: Discovers nearby sync services
class DeviceDiscoveryService {
  factory DeviceDiscoveryService() => _instance;
  DeviceDiscoveryService._();

  static final DeviceDiscoveryService _instance = DeviceDiscoveryService._();

  /// Service type for Obsession Tracker sync
  static const String serviceType = '_obstrack._tcp';

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySubscription;

  final Map<String, DiscoveredDevice> _discoveredDevices = {};

  /// Services found but not yet resolved (keyed by name)
  final Map<String, BonsoirService> _pendingServices = {};

  /// Track resolution attempts per service
  final Map<String, int> _resolutionAttempts = {};

  /// Maximum resolution attempts before giving up
  static const int _maxResolutionAttempts = 3;

  Timer? _resolutionTimeoutTimer;

  /// Callback when devices are discovered/lost
  void Function(List<DiscoveredDevice> devices)? onDevicesChanged;

  /// Callback when a device is found but can't be resolved (suggests QR code fallback)
  void Function(UnresolvedDevice device)? onUnresolvedDevice;

  /// Whether we're currently advertising
  bool get isAdvertising => _broadcast != null;

  /// Whether we're currently discovering
  bool get isDiscovering => _discovery != null;

  /// Current list of discovered devices
  List<DiscoveredDevice> get discoveredDevices =>
      _discoveredDevices.values.toList();

  // ============================================================
  // Permissions
  // ============================================================

  /// Check and request NEARBY_WIFI_DEVICES permission on Android 13+
  /// Returns true if permission is granted or not needed (non-Android or older Android)
  Future<bool> _checkNearbyWifiPermission() async {
    if (!Platform.isAndroid) {
      return true; // Not needed on iOS/macOS/etc
    }

    // Check Android version - NEARBY_WIFI_DEVICES is only required on Android 13+ (API 33+)
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    if (androidInfo.version.sdkInt < 33) {
      debugPrint('DeviceDiscoveryService: Android ${androidInfo.version.sdkInt}, NEARBY_WIFI_DEVICES not required');
      return true; // Not needed on Android 12 and below
    }

    debugPrint('DeviceDiscoveryService: Android ${androidInfo.version.sdkInt}, checking NEARBY_WIFI_DEVICES permission');

    // Check current permission status
    final status = await Permission.nearbyWifiDevices.status;
    if (status.isGranted) {
      debugPrint('DeviceDiscoveryService: NEARBY_WIFI_DEVICES permission already granted');
      return true;
    }

    // Request permission
    debugPrint('DeviceDiscoveryService: Requesting NEARBY_WIFI_DEVICES permission');
    final result = await Permission.nearbyWifiDevices.request();

    if (result.isGranted) {
      debugPrint('DeviceDiscoveryService: NEARBY_WIFI_DEVICES permission granted');
      return true;
    }

    debugPrint('DeviceDiscoveryService: NEARBY_WIFI_DEVICES permission denied: $result');
    return false;
  }

  // ============================================================
  // Sender: Advertise sync service
  // ============================================================

  /// Start advertising this device as available for sync
  Future<void> startAdvertising({
    required String deviceName,
    required int port,
    required String sessionId,
    required String sessionToken,
  }) async {
    if (_broadcast != null) {
      debugPrint('DeviceDiscoveryService: Already advertising');
      return;
    }

    try {
      // Check Android 13+ permission
      final hasPermission = await _checkNearbyWifiPermission();
      if (!hasPermission) {
        throw Exception('NEARBY_WIFI_DEVICES permission required for device discovery on Android 13+');
      }
      // Get local IP address to include in attributes (fallback for resolution issues)
      String? localIp;
      try {
        localIp = await _getLocalWifiIp();
        debugPrint('DeviceDiscoveryService: Local IP: $localIp');
      } catch (e) {
        debugPrint('DeviceDiscoveryService: Could not get local IP: $e');
      }

      // Create the service to advertise
      // Include IP and port in attributes as fallback for platforms where resolution fails
      final attributes = {
        'sid': sessionId,
        'tok': sessionToken,
        'plat': _getPlatformName(),
        if (localIp != null) 'ip': localIp,
        'port': port.toString(),
      };

      debugPrint('DeviceDiscoveryService: Creating service...');
      debugPrint('  - Name: $deviceName');
      debugPrint('  - Type: $serviceType');
      debugPrint('  - Port: $port');
      debugPrint('  - Attributes: $attributes');

      final service = BonsoirService(
        name: deviceName,
        type: serviceType,
        port: port,
        attributes: attributes,
      );

      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.initialize();

      // Listen for broadcast events
      _broadcast!.eventStream?.listen((event) {
        debugPrint('DeviceDiscoveryService: Broadcast event: ${event.runtimeType}');
      });

      await _broadcast!.start();

      debugPrint('DeviceDiscoveryService: Started advertising "$deviceName" on port $port');
    } catch (e) {
      debugPrint('DeviceDiscoveryService: Failed to start advertising: $e');
      _broadcast = null;
      rethrow;
    }
  }

  /// Stop advertising
  Future<void> stopAdvertising() async {
    if (_broadcast == null) return;

    try {
      await _broadcast!.stop();
      debugPrint('DeviceDiscoveryService: Stopped advertising');
    } catch (e) {
      debugPrint('DeviceDiscoveryService: Error stopping broadcast: $e');
    } finally {
      _broadcast = null;
    }
  }

  // ============================================================
  // Receiver: Discover nearby devices
  // ============================================================

  /// Start discovering nearby devices offering sync
  Future<void> startDiscovery() async {
    if (_discovery != null) {
      debugPrint('DeviceDiscoveryService: Already discovering');
      return;
    }

    try {
      // Check Android 13+ permission
      final hasPermission = await _checkNearbyWifiPermission();
      if (!hasPermission) {
        throw Exception('NEARBY_WIFI_DEVICES permission required for device discovery on Android 13+');
      }

      _discoveredDevices.clear();

      _discovery = BonsoirDiscovery(type: serviceType);
      await _discovery!.initialize();

      _discoverySubscription = _discovery!.eventStream?.listen(
        _handleDiscoveryEvent,
        onError: (Object error) {
          debugPrint('DeviceDiscoveryService: Discovery error: $error');
        },
      );

      await _discovery!.start();
      debugPrint('DeviceDiscoveryService: Started discovery for $serviceType');
    } catch (e) {
      debugPrint('DeviceDiscoveryService: Failed to start discovery: $e');
      _discovery = null;
      _discoverySubscription = null;
      rethrow;
    }
  }


  /// Stop discovering
  Future<void> stopDiscovery() async {
    _resolutionTimeoutTimer?.cancel();
    _resolutionTimeoutTimer = null;
    _pendingServices.clear();
    _resolutionAttempts.clear();

    if (_discovery == null) return;

    try {
      await _discoverySubscription?.cancel();
      _discoverySubscription = null;
      await _discovery!.stop();
      debugPrint('DeviceDiscoveryService: Stopped discovery');
    } catch (e) {
      debugPrint('DeviceDiscoveryService: Error stopping discovery: $e');
    } finally {
      _discovery = null;
      _discoveredDevices.clear();
    }
  }

  /// Handle discovery events
  void _handleDiscoveryEvent(BonsoirDiscoveryEvent event) {
    debugPrint('DeviceDiscoveryService: Event ${event.runtimeType} - ${event.service?.name}');

    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent():
        final service = event.service;
        debugPrint('DeviceDiscoveryService: Found service ${service.name}');
        debugPrint('  - Type: ${service.type}');
        debugPrint('  - Port: ${service.port}');
        debugPrint('  - Host: ${service.host}');
        debugPrint('  - Attributes: ${service.attributes}');

        // Check if we have host from resolution OR from attributes
        final hasResolvedHost = service.host != null && service.host!.isNotEmpty;
        final hasAttributeIp = service.attributes['ip'] != null;
        final hasSessionInfo = service.attributes['sid'] != null;

        if ((hasResolvedHost || hasAttributeIp) && hasSessionInfo) {
          debugPrint('DeviceDiscoveryService: Have IP ${hasResolvedHost ? "(resolved)" : "(from attributes)"} and session info, processing...');
          _handleServiceResolved(service);
        } else {
          debugPrint('DeviceDiscoveryService: Missing info (host: $hasResolvedHost, attrIp: $hasAttributeIp, session: $hasSessionInfo)');
          debugPrint('DeviceDiscoveryService: Explicitly resolving service...');
          // Store as pending
          _pendingServices[service.name] = service;

          // Explicitly resolve the service - required on Android to get TXT records
          // On Android, NsdManager doesn't automatically resolve services
          service.resolve(_discovery!.serviceResolver);

          // Start timeout in case resolution fails
          _startResolutionTimeout();
        }

      case BonsoirDiscoveryServiceResolvedEvent():
        final resolvedService = event.service;
        debugPrint('DeviceDiscoveryService: Service resolved!');
        debugPrint('  - Name: ${resolvedService.name}');
        debugPrint('  - Host: ${resolvedService.host}');
        debugPrint('  - Port: ${resolvedService.port}');
        debugPrint('  - Attributes: ${resolvedService.attributes}');
        _pendingServices.remove(resolvedService.name);
        _resolutionAttempts.remove(resolvedService.name);
        _handleServiceResolved(resolvedService);

      case BonsoirDiscoveryServiceLostEvent():
        _handleServiceLost(event.service);

      case BonsoirDiscoveryStartedEvent():
        debugPrint('DeviceDiscoveryService: Discovery started');

      case BonsoirDiscoveryStoppedEvent():
        debugPrint('DeviceDiscoveryService: Discovery stopped');

      default:
        // Handle BonsoirDiscoveryServiceUpdatedEvent (comes as dynamic type)
        // This event is fired when service attributes are updated after initial discovery
        final service = event.service;
        if (service != null) {
          debugPrint('DeviceDiscoveryService: Service updated: ${service.name}');
          debugPrint('  - Attributes: ${service.attributes}');

          // Check if this update provides the IP we need
          final hasResolvedHost = service.host != null && service.host!.isNotEmpty;
          final hasAttributeIp = service.attributes['ip'] != null;

          if (hasResolvedHost || hasAttributeIp) {
            debugPrint('DeviceDiscoveryService: Update contains IP, processing...');
            _pendingServices.remove(service.name);
            _handleServiceResolved(service);
          }
        } else {
          debugPrint('DeviceDiscoveryService: Event with no service: ${event.runtimeType}');
        }
        break;
    }
  }

  /// Start a timeout to check for unresolved services
  void _startResolutionTimeout() {
    _resolutionTimeoutTimer?.cancel();
    _resolutionTimeoutTimer = Timer(const Duration(seconds: 3), () {
      if (_pendingServices.isNotEmpty) {
        debugPrint('DeviceDiscoveryService: ${_pendingServices.length} service(s) still pending after timeout');

        // Collect services to process (avoid concurrent modification)
        final servicesToProcess = Map<String, BonsoirService>.from(_pendingServices);
        final servicesToRemove = <String>[];
        final unresolvedToNotify = <UnresolvedDevice>[];

        for (final entry in servicesToProcess.entries) {
          final name = entry.key;
          final service = entry.value;
          final attempts = _resolutionAttempts[name] ?? 0;

          debugPrint('  - $name: host=${service.host}, port=${service.port}, attempts=$attempts');
          debugPrint('    attributes: ${service.attributes}');

          if (attempts < _maxResolutionAttempts) {
            // Increment attempts and try to resolve again
            _resolutionAttempts[name] = attempts + 1;
            debugPrint('DeviceDiscoveryService: Retry resolve attempt ${attempts + 1} for $name');

            // Re-trigger explicit resolve
            if (_discovery != null) {
              service.resolve(_discovery!.serviceResolver);
            }
          } else {
            // Max attempts reached - notify UI that this device needs QR code
            debugPrint('DeviceDiscoveryService: Max resolution attempts reached for $name');
            servicesToRemove.add(name);

            unresolvedToNotify.add(UnresolvedDevice(
              name: name,
              platform: service.attributes['plat'],
              resolutionAttempts: attempts,
              foundAt: DateTime.now(),
            ));
          }
        }

        // Now safely remove and notify after iteration
        servicesToRemove.forEach(_pendingServices.remove);

        final callback = onUnresolvedDevice;
        if (callback != null) {
          unresolvedToNotify.forEach(callback);
        }

        // If we still have pending services, restart the timeout to check again
        if (_pendingServices.isNotEmpty) {
          debugPrint('DeviceDiscoveryService: ${_pendingServices.length} services still pending, will check again...');
          _startResolutionTimeout();
        }
      }
    });
  }

  void _handleServiceResolved(BonsoirService service) {
    final attributes = service.attributes;

    final sessionId = attributes['sid'];
    final sessionToken = attributes['tok'];

    if (sessionId == null || sessionToken == null) {
      debugPrint('DeviceDiscoveryService: Service ${service.name} missing session info');
      return;
    }

    // Get the host/IP address - prefer resolved host, fallback to attribute
    String? ip = service.host;
    if (ip == null || ip.isEmpty) {
      // Use IP from attributes as fallback (for platforms where resolution fails)
      ip = attributes['ip'];
      if (ip != null) {
        debugPrint('DeviceDiscoveryService: Using IP from attributes: $ip');
      }
    }

    if (ip == null || ip.isEmpty) {
      debugPrint('DeviceDiscoveryService: Service ${service.name} has no host address');
      return;
    }

    // Skip link-local IPv6 addresses
    if (ip.startsWith('fe80:') || ip.contains('%')) {
      debugPrint('DeviceDiscoveryService: Skipping link-local address $ip');
      return;
    }

    // Get port - prefer resolved port, fallback to attribute
    int port = service.port;
    if (port == 0) {
      final portStr = attributes['port'];
      if (portStr != null) {
        port = int.tryParse(portStr) ?? 0;
        debugPrint('DeviceDiscoveryService: Using port from attributes: $port');
      }
    }

    if (port == 0) {
      debugPrint('DeviceDiscoveryService: Service ${service.name} has no valid port');
      return;
    }

    final device = DiscoveredDevice(
      name: service.name,
      ip: ip,
      port: port,
      sessionId: sessionId,
      sessionToken: sessionToken,
      discoveredAt: DateTime.now(),
    );

    _discoveredDevices[sessionId] = device;
    debugPrint('DeviceDiscoveryService: Resolved device: $device');

    onDevicesChanged?.call(discoveredDevices);
  }

  void _handleServiceLost(BonsoirService service) {
    // Find and remove the device by matching name since we might not have the session ID
    final toRemove = _discoveredDevices.entries
        .where((e) => e.value.name == service.name)
        .map((e) => e.key)
        .toList();

    for (final key in toRemove) {
      _discoveredDevices.remove(key);
      debugPrint('DeviceDiscoveryService: Lost device: ${service.name}');
    }

    if (toRemove.isNotEmpty) {
      onDevicesChanged?.call(discoveredDevices);
    }
  }

  /// Clean up all resources
  Future<void> dispose() async {
    await stopAdvertising();
    await stopDiscovery();
    onDevicesChanged = null;
    onUnresolvedDevice = null;
  }

  String _getPlatformName() {
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  /// Get local WiFi IP address, filtering out link-local and other unusable addresses
  Future<String?> _getLocalWifiIp() async {
    // Try network_info_plus first
    try {
      final networkInfo = NetworkInfo();
      final wifiIp = await networkInfo.getWifiIP();
      if (wifiIp != null && _isUsableIp(wifiIp)) {
        debugPrint('DeviceDiscoveryService: Got IP from network_info_plus: $wifiIp');
        return wifiIp;
      }
      debugPrint('DeviceDiscoveryService: network_info_plus returned unusable IP: $wifiIp');
    } catch (e) {
      debugPrint('DeviceDiscoveryService: network_info_plus failed: $e');
    }

    // Fallback: enumerate network interfaces
    // Prefer WiFi interfaces over cellular
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );

      String? wifiIp;
      String? otherIp;

      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();

        // Skip loopback, virtual, and VPN interfaces
        if (name.startsWith('lo') ||
            name.startsWith('docker') ||
            name.startsWith('veth') ||
            name.startsWith('utun') ||
            name.startsWith('ipsec')) {
          continue;
        }

        // Skip cellular interfaces (iOS: pdp_ip*, Android: rmnet*)
        final isCellular = name.startsWith('pdp_ip') || name.startsWith('rmnet');

        for (final addr in interface.addresses) {
          if (_isUsableIp(addr.address)) {
            debugPrint('DeviceDiscoveryService: Found IP ${addr.address} on ${interface.name} (${isCellular ? "cellular" : "other"})');

            // WiFi interfaces: en0 (iOS/macOS), wlan0 (Android/Linux)
            if (name == 'en0' || name.startsWith('wlan')) {
              wifiIp = addr.address;
              debugPrint('DeviceDiscoveryService: Identified as WiFi interface');
            } else if (!isCellular) {
              // Store non-cellular as backup
              otherIp ??= addr.address;
            }
          }
        }
      }

      // Prefer WiFi over other interfaces
      if (wifiIp != null) {
        debugPrint('DeviceDiscoveryService: Using WiFi IP: $wifiIp');
        return wifiIp;
      }
      if (otherIp != null) {
        debugPrint('DeviceDiscoveryService: Using non-cellular IP: $otherIp');
        return otherIp;
      }

      debugPrint('DeviceDiscoveryService: No suitable WiFi interface found');
    } catch (e) {
      debugPrint('DeviceDiscoveryService: NetworkInterface.list failed: $e');
    }

    return null;
  }

  /// Check if an IP address is usable for local network sync
  bool _isUsableIp(String ip) {
    // Reject link-local addresses (169.254.x.x)
    if (ip.startsWith('169.254.')) {
      return false;
    }
    // Reject loopback
    if (ip.startsWith('127.')) {
      return false;
    }
    // Accept private network ranges
    // 10.x.x.x, 172.16-31.x.x, 192.168.x.x
    if (ip.startsWith('10.') ||
        ip.startsWith('192.168.') ||
        _isIn172Range(ip)) {
      return true;
    }
    // Accept other addresses (could be public, but might work on some networks)
    return true;
  }

  bool _isIn172Range(String ip) {
    if (!ip.startsWith('172.')) return false;
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
  }
}
