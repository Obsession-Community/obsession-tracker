import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';

/// Platform-specific optimizations for iPad and Android tablets
class PlatformOptimizations {
  /// Configure iPad-specific optimizations
  static void configureIPadOptimizations(BuildContext context) {
    if (!ResponsiveUtils.isIPad(context)) return;

    // Configure status bar for iPad
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    // Enable iPad-specific gestures
    _enableIPadGestures();

    // Configure safe area handling for notched iPads
    _configureIPadSafeArea(context);
  }

  /// Configure Android tablet-specific optimizations
  static void configureAndroidTabletOptimizations(BuildContext context) {
    if (!ResponsiveUtils.isAndroidTablet(context)) return;

    // Configure navigation bar for Android tablets
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).colorScheme.surface,
        systemNavigationBarIconBrightness:
            Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
      ),
    );

    // Enable Android-specific optimizations
    _enableAndroidTabletOptimizations();
  }

  /// Get optimal image cache size based on device capabilities
  static int getOptimalImageCacheSize(BuildContext context) {
    final deviceType = ResponsiveUtils.getDeviceType(context);
    final screenSize = MediaQuery.of(context).size;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Calculate based on screen resolution and device type
    final totalPixels = screenSize.width * screenSize.height * pixelRatio;

    switch (deviceType) {
      case DeviceType.phone:
        return (totalPixels * 0.25).round(); // 25% of screen pixels
      case DeviceType.tablet:
        return (totalPixels * 0.4).round(); // 40% of screen pixels
      case DeviceType.desktop:
        return (totalPixels * 0.5).round(); // 50% of screen pixels
    }
  }

  /// Get optimal thumbnail size for device
  static Size getOptimalThumbnailSize(BuildContext context) {
    final deviceType = ResponsiveUtils.getDeviceType(context);
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;

    switch (deviceType) {
      case DeviceType.phone:
        return Size(150 * pixelRatio, 150 * pixelRatio);
      case DeviceType.tablet:
        return Size(200 * pixelRatio, 200 * pixelRatio);
      case DeviceType.desktop:
        return Size(250 * pixelRatio, 250 * pixelRatio);
    }
  }

  /// Configure memory management for large screens
  static void configureMemoryManagement(BuildContext context) {
    final deviceType = ResponsiveUtils.getDeviceType(context);

    if (deviceType == DeviceType.tablet || deviceType == DeviceType.desktop) {
      // Increase image cache size for tablets
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          getOptimalImageCacheSize(context);

      // Configure more aggressive caching for tablets
      PaintingBinding.instance.imageCache.maximumSize = 200;
    }
  }

  /// Get optimal grid column count for photo galleries
  static int getOptimalPhotoGridColumns(BuildContext context) {
    // Configure haptic feedback based on platform capabilities
    final isLandscape = ResponsiveUtils.isLandscape(context);
    final width = MediaQuery.of(context).size.width;

    if (ResponsiveUtils.isIPad(context)) {
      // iPad-specific column counts
      if (width > ResponsiveBreakpoints.iPadProLargeWidth) {
        return isLandscape ? 8 : 6; // iPad Pro 12.9"
      } else if (width > ResponsiveBreakpoints.iPadProWidth) {
        return isLandscape ? 7 : 5; // iPad Pro 11"
      } else {
        return isLandscape ? 6 : 4; // iPad Mini
      }
    } else if (ResponsiveUtils.isAndroidTablet(context)) {
      // Android tablet column counts
      if (width > ResponsiveBreakpoints.androidTablet12InchWidth) {
        return isLandscape ? 8 : 6; // Large Android tablets
      } else if (width > ResponsiveBreakpoints.androidTablet10InchWidth) {
        return isLandscape ? 6 : 4; // Medium Android tablets
      } else {
        return isLandscape ? 5 : 3; // Small Android tablets
      }
    }

    // Fallback for other devices
    return ResponsiveUtils.getPhotoGalleryColumns(context);
  }

  /// Configure haptic feedback for different platforms
  static void configureHapticFeedback(BuildContext context) {
    // On web, haptic feedback is not supported, so we skip platform-specific logic
    if (kIsWeb) {
      return; // No haptic feedback on web
    }

    // For non-web platforms, use default haptic feedback
    HapticFeedback.lightImpact();
  }

  /// Get platform-specific animation durations
  static Duration getPlatformAnimationDuration(BuildContext context) {
    if (ResponsiveUtils.isIPad(context)) {
      return const Duration(milliseconds: 350); // Slightly longer for iPad
    } else if (ResponsiveUtils.isAndroidTablet(context)) {
      return const Duration(milliseconds: 300); // Standard Material duration
    } else {
      return const Duration(milliseconds: 250); // Faster for phones
    }
  }

  /// Configure text scaling for different screen sizes
  static double getOptimalTextScaleFactor(BuildContext context) {
    final deviceType = ResponsiveUtils.getDeviceType(context);
    final width = MediaQuery.of(context).size.width;

    switch (deviceType) {
      case DeviceType.phone:
        return 1.0; // Standard scaling
      case DeviceType.tablet:
        if (width > 1000) {
          return 1.15; // Slightly larger text for large tablets
        } else {
          return 1.1; // Moderately larger text for medium tablets
        }
      case DeviceType.desktop:
        return 1.2; // Larger text for desktop
    }
  }

  /// Get optimal touch target size for platform
  static double getOptimalTouchTargetSize(BuildContext context) {
    if (ResponsiveUtils.isIPad(context)) {
      return 48.0; // iOS Human Interface Guidelines
    } else if (ResponsiveUtils.isAndroidTablet(context)) {
      return 48.0; // Material Design Guidelines
    } else {
      return 44.0; // Standard mobile size
    }
  }

  /// Configure keyboard shortcuts for tablets
  static void configureKeyboardShortcuts(BuildContext context) {
    if (!ResponsiveUtils.isTablet(context)) return;

    // TODO(dev): Implement keyboard shortcuts for:
    // - Photo navigation (arrow keys)
    // - Zoom controls (+ / -)
    // - Gallery actions (Delete, Favorite)
    // - Search (Cmd/Ctrl + F)
  }

  /// Private helper methods
  static void _enableIPadGestures() {
    // Configure iPad-specific gesture recognizers
    // This would typically involve setting up custom gesture recognizers
    // for iPad-specific interactions like Apple Pencil support
  }

  static void _configureIPadSafeArea(BuildContext context) {
    // Handle safe area insets for different iPad models
    final mediaQuery = MediaQuery.of(context);
    final hasNotch = mediaQuery.padding.top > 24;

    if (hasNotch) {
      // Configure for notched iPads (iPad Pro with Face ID)
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.dark,
        ),
      );
    }
  }

  static void _enableAndroidTabletOptimizations() {
    // Configure Android-specific optimizations
    // This could include enabling hardware acceleration,
    // configuring memory management, etc.
  }
}

/// Extension to easily apply platform optimizations
extension PlatformOptimizationsExtension on BuildContext {
  /// Apply all relevant platform optimizations
  void applyPlatformOptimizations() {
    PlatformOptimizations.configureIPadOptimizations(this);
    PlatformOptimizations.configureAndroidTabletOptimizations(this);
    PlatformOptimizations.configureMemoryManagement(this);
    PlatformOptimizations.configureKeyboardShortcuts(this);
  }

  /// Get optimal image cache size for this context
  int get optimalImageCacheSize =>
      PlatformOptimizations.getOptimalImageCacheSize(this);

  /// Get optimal thumbnail size for this context
  Size get optimalThumbnailSize =>
      PlatformOptimizations.getOptimalThumbnailSize(this);

  /// Get optimal photo grid columns for this context
  int get optimalPhotoGridColumns =>
      PlatformOptimizations.getOptimalPhotoGridColumns(this);

  /// Get platform-specific animation duration
  Duration get platformAnimationDuration =>
      PlatformOptimizations.getPlatformAnimationDuration(this);

  /// Get optimal text scale factor for this context
  double get optimalTextScaleFactor =>
      PlatformOptimizations.getOptimalTextScaleFactor(this);

  /// Get optimal touch target size for this context
  double get optimalTouchTargetSize =>
      PlatformOptimizations.getOptimalTouchTargetSize(this);
}

/// Performance monitoring utilities
class PerformanceMonitor {
  static final Map<String, Stopwatch> _timers = <String, Stopwatch>{};

  /// Start timing an operation
  static void startTimer(String operation) {
    _timers[operation] = Stopwatch()..start();
  }

  /// Stop timing and log the result
  static void stopTimer(String operation) {
    final timer = _timers[operation];
    if (timer != null) {
      timer.stop();
      debugPrint('Performance: $operation took ${timer.elapsedMilliseconds}ms');
      _timers.remove(operation);
    }
  }

  /// Monitor memory usage
  static void logMemoryUsage(String context) {
    // This would typically use platform-specific APIs to get memory info
    debugPrint('Memory usage check: $context');
  }
}
