import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to detect device capabilities and provide adaptive limits
///
/// Used to prevent OOM crashes on low-RAM devices when rendering
/// large amounts of map data (land polygons, trails, etc.)
class DeviceCapabilityService {
  DeviceCapabilityService._internal();

  static final DeviceCapabilityService _instance =
      DeviceCapabilityService._internal();
  static DeviceCapabilityService get instance => _instance;

  bool _initialized = false;
  DeviceCapabilityTier _tier = DeviceCapabilityTier.medium;
  int _totalRamMB = 4096; // Default to 4GB

  /// Device capability tier based on available RAM
  DeviceCapabilityTier get tier => _tier;

  /// Total RAM in MB
  int get totalRamMB => _totalRamMB;

  /// Whether device has been analyzed
  bool get isInitialized => _initialized;

  /// Initialize and detect device capabilities
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Android provides total memory in bytes via SystemInfo
        // We can estimate from device model or use a reasonable default
        _totalRamMB = _estimateAndroidRam(androidInfo);
        debugPrint('📱 Device: ${androidInfo.model}, estimated RAM: $_totalRamMB MB');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _totalRamMB = _estimateIosRam(iosInfo);
        debugPrint('📱 Device: ${iosInfo.utsname.machine}, estimated RAM: $_totalRamMB MB');
      }

      // Determine tier based on RAM
      // Be conservative - 4GB devices (Pixel 3, older iPhones) struggle with Alaska
      if (_totalRamMB <= 4096) {
        _tier = DeviceCapabilityTier.low;  // 4GB and below = low tier
      } else if (_totalRamMB <= 6144) {
        _tier = DeviceCapabilityTier.medium;  // 5-6GB = medium tier
      } else {
        _tier = DeviceCapabilityTier.high;  // 7GB+ = high tier
      }

      debugPrint('📊 Device capability tier: ${_tier.name} (${_totalRamMB}MB RAM)');
      _initialized = true;
    } catch (e) {
      debugPrint('⚠️ Failed to detect device capabilities: $e');
      // Default to medium tier on failure
      _tier = DeviceCapabilityTier.medium;
      _initialized = true;
    }
  }

  /// Get maximum parcel limit for map rendering based on device capability
  ///
  /// [baseLimit] - The default limit from settings/caller
  /// [zoomLevel] - Current map zoom level (higher = more zoomed in)
  ///
  /// BFF now applies ST_SimplifyPreserveTopology(0.001) which reduces polygon
  /// complexity by ~62%. With simplification, we can use the full baseLimit
  /// and let natural viewport constraints handle limiting visible parcels.
  int getParcelLimit({required int baseLimit, required double zoomLevel}) {
    // With BFF polygon simplification, just use the baseLimit directly.
    // The viewport and zoom level naturally limit how many parcels are visible.
    // No artificial limits needed - let the data speak for itself.
    return baseLimit;
  }

  /// Get minimum zoom level for land data based on device capability
  ///
  /// With BFF polygon simplification, we can show land data at lower zoom levels.
  double getMinZoomForLandData({required double baseMinZoom}) {
    return switch (_tier) {
      DeviceCapabilityTier.low => baseMinZoom + 2.0,    // Require zoom 9+
      DeviceCapabilityTier.medium => baseMinZoom + 1.0, // Require zoom 8+
      DeviceCapabilityTier.high => baseMinZoom,         // Use base zoom (typically 7)
    };
  }

  /// Estimate Android RAM based on device info
  int _estimateAndroidRam(AndroidDeviceInfo info) {
    // Use SDK version as a rough proxy for device age/capability
    // Newer devices tend to have more RAM
    final sdkInt = info.version.sdkInt;

    // Check for known low-RAM device models
    final model = info.model.toLowerCase();
    if (model.contains('pixel 3') ||
        model.contains('pixel 2') ||
        model.contains('pixel 1') ||
        model.contains('moto g') ||
        model.contains('galaxy a1') ||
        model.contains('galaxy a2')) {
      return 4096; // 4GB devices
    }

    // Check for known high-RAM devices
    if (model.contains('pixel 8') ||
        model.contains('pixel 7') ||
        model.contains('pixel 6') ||
        model.contains('galaxy s2') ||
        model.contains('galaxy s3') ||
        model.contains('galaxy z')) {
      return 8192; // 8GB+ devices
    }

    // Estimate based on SDK version
    if (sdkInt >= 33) {
      return 8192; // Android 13+ devices typically have 8GB+
    } else if (sdkInt >= 30) {
      return 6144; // Android 11-12 typically have 6GB
    } else if (sdkInt >= 28) {
      return 4096; // Android 9-10 typically have 4GB
    } else {
      return 3072; // Older devices
    }
  }

  /// Estimate iOS RAM based on device info
  int _estimateIosRam(IosDeviceInfo info) {
    final machine = info.utsname.machine;

    // iPhone RAM estimates by model
    // iPhone 8 and earlier: 2-3GB
    // iPhone X, XS, XR: 3-4GB
    // iPhone 11: 4GB
    // iPhone 12: 4GB
    // iPhone 13: 4-6GB
    // iPhone 14: 6GB
    // iPhone 15: 6-8GB

    if (machine.contains('iPhone15') || machine.contains('iPhone16')) {
      return 8192;
    } else if (machine.contains('iPhone14') || machine.contains('iPhone13')) {
      return 6144;
    } else if (machine.contains('iPhone12') || machine.contains('iPhone11')) {
      return 4096;
    } else if (machine.contains('iPhone10') || machine.contains('iPhoneX')) {
      return 3072;
    } else {
      return 4096; // Default for unknown iPhones
    }
  }
}

/// Device capability tier for adaptive resource limits
enum DeviceCapabilityTier {
  /// Low-end devices (<=3GB RAM) - aggressive limits to prevent OOM
  low,

  /// Mid-range devices (4-6GB RAM) - moderate limits
  medium,

  /// High-end devices (>6GB RAM) - full capability
  high,
}
