import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Device type enumeration for responsive design
enum DeviceType {
  phone,
  tablet,
  desktop,
}

/// Screen size category for more granular control
enum ScreenSize {
  small, // < 600dp
  medium, // 600-840dp
  large, // 840-1200dp
  extraLarge, // > 1200dp
}

/// Platform-specific device categories
enum PlatformDevice {
  androidPhone,
  androidTablet,
  iPhone,
  iPad,
  macOS,
  windows,
  linux,
  web,
}

/// Responsive breakpoints following Material Design 3 guidelines
class ResponsiveBreakpoints {
  static const double phoneMaxWidth = 600.0;
  static const double tabletMaxWidth = 840.0;
  static const double desktopMaxWidth = 1200.0;

  // Tablet-specific breakpoints
  static const double smallTabletMaxWidth = 720.0;
  static const double largeTabletMinWidth = 720.0;

  // Max content width for forms, text fields, buttons, etc.
  // Prevents content from stretching too wide on large screens
  static const double maxFormContentWidth = 600.0; // Standard form width
  static const double maxReadingContentWidth = 720.0; // Comfortable reading width
  static const double maxCardContentWidth = 480.0; // Card/dialog content

  // iPad-specific breakpoints
  static const double iPadMiniWidth = 744.0;
  static const double iPadMiniHeight = 1133.0;
  static const double iPadProWidth = 834.0;
  static const double iPadProHeight = 1194.0;
  static const double iPadProLargeWidth = 1024.0;
  static const double iPadProLargeHeight = 1366.0;

  // Android tablet common sizes
  static const double androidTablet7InchWidth = 600.0;
  static const double androidTablet10InchWidth = 800.0;
  static const double androidTablet12InchWidth = 1000.0;
}

/// Responsive utility class for screen size detection and adaptive layouts
class ResponsiveUtils {
  /// Get device type based on screen width
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < ResponsiveBreakpoints.phoneMaxWidth) {
      return DeviceType.phone;
    } else if (width < ResponsiveBreakpoints.desktopMaxWidth) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  /// Get screen size category
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < ResponsiveBreakpoints.phoneMaxWidth) {
      return ScreenSize.small;
    } else if (width < ResponsiveBreakpoints.tabletMaxWidth) {
      return ScreenSize.medium;
    } else if (width < ResponsiveBreakpoints.desktopMaxWidth) {
      return ScreenSize.large;
    } else {
      return ScreenSize.extraLarge;
    }
  }

  /// Get platform-specific device type
  static PlatformDevice getPlatformDevice(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;

    // On web, we can't detect the actual platform, so we use screen size heuristics
    if (kIsWeb) {
      // For web, determine device type based on screen dimensions
      if (width >= ResponsiveBreakpoints.phoneMaxWidth) {
        return PlatformDevice.web; // Treat larger screens as web
      }
      return PlatformDevice.web; // All web devices return web
    }

    // For non-web platforms, we would need conditional imports
    // For now, default to web since we're running in web context
    return PlatformDevice.web;
  }

  /// Check if device is a tablet
  static bool isTablet(BuildContext context) =>
      getDeviceType(context) == DeviceType.tablet;

  /// Check if device is a phone
  static bool isPhone(BuildContext context) =>
      getDeviceType(context) == DeviceType.phone;

  /// Check if device is desktop
  static bool isDesktop(BuildContext context) =>
      getDeviceType(context) == DeviceType.desktop;

  /// Check if device is iPad
  static bool isIPad(BuildContext context) =>
      getPlatformDevice(context) == PlatformDevice.iPad;

  /// Check if device is Android tablet
  static bool isAndroidTablet(BuildContext context) =>
      getPlatformDevice(context) == PlatformDevice.androidTablet;

  /// Check if screen is in landscape orientation
  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  /// Check if screen is in portrait orientation
  static bool isPortrait(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.portrait;

  /// Get optimal column count for grid layouts
  static int getGridColumnCount(
    BuildContext context, {
    int phoneColumns = 2,
    int tabletPortraitColumns = 3,
    int tabletLandscapeColumns = 4,
    int desktopColumns = 6,
  }) {
    final deviceType = getDeviceType(context);
    final isLandscapeMode = isLandscape(context);

    switch (deviceType) {
      case DeviceType.phone:
        return phoneColumns;
      case DeviceType.tablet:
        return isLandscapeMode ? tabletLandscapeColumns : tabletPortraitColumns;
      case DeviceType.desktop:
        return desktopColumns;
    }
  }

  /// Get optimal photo gallery column count
  static int getPhotoGalleryColumns(BuildContext context) {
    final deviceType = getDeviceType(context);
    final isLandscapeMode = isLandscape(context);
    final width = MediaQuery.of(context).size.width;

    switch (deviceType) {
      case DeviceType.phone:
        return isLandscapeMode ? 4 : 3;
      case DeviceType.tablet:
        if (width < ResponsiveBreakpoints.smallTabletMaxWidth) {
          return isLandscapeMode ? 5 : 4;
        } else {
          return isLandscapeMode ? 7 : 5;
        }
      case DeviceType.desktop:
        return isLandscapeMode ? 8 : 6;
    }
  }

  /// Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(
    BuildContext context, {
    EdgeInsets? phone,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
  }) {
    final deviceType = getDeviceType(context);

    switch (deviceType) {
      case DeviceType.phone:
        return phone ?? const EdgeInsets.all(16.0);
      case DeviceType.tablet:
        return tablet ?? const EdgeInsets.all(24.0);
      case DeviceType.desktop:
        return desktop ?? const EdgeInsets.all(32.0);
    }
  }

  /// Get responsive margin based on screen size
  static EdgeInsets getResponsiveMargin(
    BuildContext context, {
    EdgeInsets? phone,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
  }) {
    final deviceType = getDeviceType(context);

    switch (deviceType) {
      case DeviceType.phone:
        return phone ?? const EdgeInsets.all(8.0);
      case DeviceType.tablet:
        return tablet ?? const EdgeInsets.all(16.0);
      case DeviceType.desktop:
        return desktop ?? const EdgeInsets.all(24.0);
    }
  }

  /// Get responsive font size
  static double getResponsiveFontSize(
    BuildContext context, {
    double? phone,
    double? tablet,
    double? desktop,
  }) {
    final deviceType = getDeviceType(context);

    switch (deviceType) {
      case DeviceType.phone:
        return phone ?? 14.0;
      case DeviceType.tablet:
        return tablet ?? 16.0;
      case DeviceType.desktop:
        return desktop ?? 18.0;
    }
  }

  /// Check if master-detail layout should be used
  static bool shouldUseMasterDetailLayout(BuildContext context) {
    final deviceType = getDeviceType(context);
    final isLandscapeMode = isLandscape(context);
    final width = MediaQuery.of(context).size.width;

    // Use master-detail on tablets in landscape or large tablets in portrait
    return (deviceType == DeviceType.tablet && isLandscapeMode) ||
        (deviceType == DeviceType.tablet &&
            width > ResponsiveBreakpoints.largeTabletMinWidth) ||
        deviceType == DeviceType.desktop;
  }

  /// Get master panel width for master-detail layouts
  static double getMasterPanelWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width > 1200) {
      return 400.0; // Desktop
    } else if (width > 900) {
      return 350.0; // Large tablet
    } else {
      return 300.0; // Medium tablet
    }
  }

  /// Get detail panel minimum width
  static double getDetailPanelMinWidth(BuildContext context) {
    final deviceType = getDeviceType(context);

    switch (deviceType) {
      case DeviceType.tablet:
        return 400.0;
      case DeviceType.desktop:
        return 600.0;
      case DeviceType.phone:
        return 300.0;
    }
  }

  /// Check if floating panels should be used instead of full-screen dialogs
  static bool shouldUseFloatingPanels(BuildContext context) =>
      isTablet(context) || isDesktop(context);

  /// Get safe area padding considering device type
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final deviceType = getDeviceType(context);

    // Tablets typically have less intrusive safe areas
    if (deviceType == DeviceType.tablet) {
      return EdgeInsets.only(
        top: mediaQuery.padding.top,
        bottom:
            mediaQuery.padding.bottom * 0.5, // Reduce bottom padding on tablets
      );
    }

    return mediaQuery.padding;
  }

  /// Get max content width for forms and content areas
  /// Returns null on phones (no constraint needed), constrained width on tablets/desktop
  static double? getMaxContentWidth(
    BuildContext context, {
    double maxWidth = ResponsiveBreakpoints.maxFormContentWidth,
  }) {
    final deviceType = getDeviceType(context);
    if (deviceType == DeviceType.phone) {
      return null; // No constraint on phones - use full width
    }
    return maxWidth;
  }

  /// Private helper to detect iPad based on dimensions
}

/// Widget that constrains content to a max width and centers it on larger screens.
/// On phones, it uses full width. On tablets/desktop, it constrains and centers.
///
/// Usage:
/// ```dart
/// ResponsiveContentBox(
///   child: Column(
///     children: [
///       TextFormField(...),
///       ElevatedButton(...),
///     ],
///   ),
/// )
/// ```
class ResponsiveContentBox extends StatelessWidget {
  const ResponsiveContentBox({
    required this.child,
    this.maxWidth = ResponsiveBreakpoints.maxFormContentWidth,
    this.alignment = Alignment.topCenter,
    this.padding,
    super.key,
  });

  /// The content to constrain
  final Widget child;

  /// Maximum width for the content (default: 600dp for forms)
  final double maxWidth;

  /// Alignment of the constrained content (default: top center)
  final AlignmentGeometry alignment;

  /// Optional padding to apply around the content
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final constrainedMaxWidth = ResponsiveUtils.getMaxContentWidth(
      context,
      maxWidth: maxWidth,
    );

    Widget content = child;

    // Apply padding if provided
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    // On phones, no constraint needed
    if (constrainedMaxWidth == null) {
      return content;
    }

    // On tablets/desktop, constrain and center
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: constrainedMaxWidth),
        child: content,
      ),
    );
  }
}

/// Extension on BuildContext for easier access to responsive utilities
extension ResponsiveContext on BuildContext {
  DeviceType get deviceType => ResponsiveUtils.getDeviceType(this);
  ScreenSize get screenSize => ResponsiveUtils.getScreenSize(this);
  PlatformDevice get platformDevice => ResponsiveUtils.getPlatformDevice(this);

  bool get isPhone => ResponsiveUtils.isPhone(this);
  bool get isTablet => ResponsiveUtils.isTablet(this);
  bool get isDesktop => ResponsiveUtils.isDesktop(this);
  bool get isIPad => ResponsiveUtils.isIPad(this);
  bool get isAndroidTablet => ResponsiveUtils.isAndroidTablet(this);
  bool get isLandscape => ResponsiveUtils.isLandscape(this);
  bool get isPortrait => ResponsiveUtils.isPortrait(this);

  bool get shouldUseMasterDetail =>
      ResponsiveUtils.shouldUseMasterDetailLayout(this);
  bool get shouldUseFloatingPanels =>
      ResponsiveUtils.shouldUseFloatingPanels(this);

  int get photoGalleryColumns => ResponsiveUtils.getPhotoGalleryColumns(this);
  double get masterPanelWidth => ResponsiveUtils.getMasterPanelWidth(this);
  double get detailPanelMinWidth =>
      ResponsiveUtils.getDetailPanelMinWidth(this);

  EdgeInsets get responsivePadding =>
      ResponsiveUtils.getResponsivePadding(this);
  EdgeInsets get responsiveMargin => ResponsiveUtils.getResponsiveMargin(this);
  EdgeInsets get safeAreaPadding => ResponsiveUtils.getSafeAreaPadding(this);

  /// Max content width for forms (600dp on tablets/desktop, null on phones)
  double? get maxContentWidth => ResponsiveUtils.getMaxContentWidth(this);

  /// Max reading width for text content (720dp on tablets/desktop, null on phones)
  double? get maxReadingWidth => ResponsiveUtils.getMaxContentWidth(
        this,
        maxWidth: ResponsiveBreakpoints.maxReadingContentWidth,
      );
}
