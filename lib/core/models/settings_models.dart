import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';

// Supporting enums and classes for app settings

/// Measurement units for distance, speed, etc.
enum MeasurementUnits {
  imperial,
  metric;

  String get displayName {
    switch (this) {
      case MeasurementUnits.imperial:
        return 'Imperial (mi, mph)';
      case MeasurementUnits.metric:
        return 'Metric (km, m/s)';
    }
  }
}

/// Coordinate display format
enum CoordinateFormat {
  decimal,
  degreesMinutes,
  degreesMinutesSeconds;

  String get displayName {
    switch (this) {
      case CoordinateFormat.decimal:
        return 'Decimal (12.34567°)';
      case CoordinateFormat.degreesMinutes:
        return "Degrees Minutes (12° 20.74')";
      case CoordinateFormat.degreesMinutesSeconds:
        return 'Degrees Minutes Seconds (12° 20\' 44.4")';
    }
  }
}

/// Time format preference
enum TimeFormat {
  format12,
  format24;

  String get displayName {
    switch (this) {
      case TimeFormat.format12:
        return '12-hour (2:30 PM)';
      case TimeFormat.format24:
        return '24-hour (14:30)';
    }
  }
}

/// Font size options
enum FontSize {
  small,
  medium,
  large,
  extraLarge;

  String get displayName {
    switch (this) {
      case FontSize.small:
        return 'Small';
      case FontSize.medium:
        return 'Medium';
      case FontSize.large:
        return 'Large';
      case FontSize.extraLarge:
        return 'Extra Large';
    }
  }

  double get scaleFactor {
    switch (this) {
      case FontSize.small:
        return 0.85;
      case FontSize.medium:
        return 1.0;
      case FontSize.large:
        return 1.15;
      case FontSize.extraLarge:
        return 1.3;
    }
  }
}

/// Color blindness support types
enum ColorBlindnessType {
  none,
  protanopia,
  deuteranopia,
  tritanopia;

  String get displayName {
    switch (this) {
      case ColorBlindnessType.none:
        return 'None';
      case ColorBlindnessType.protanopia:
        return 'Protanopia (Red-blind)';
      case ColorBlindnessType.deuteranopia:
        return 'Deuteranopia (Green-blind)';
      case ColorBlindnessType.tritanopia:
        return 'Tritanopia (Blue-blind)';
    }
  }
}

/// Vibration pattern options
enum VibrationPattern {
  none,
  light,
  standard,
  strong,
  custom;

  String get displayName {
    switch (this) {
      case VibrationPattern.none:
        return 'None';
      case VibrationPattern.light:
        return 'Light';
      case VibrationPattern.standard:
        return 'Standard';
      case VibrationPattern.strong:
        return 'Strong';
      case VibrationPattern.custom:
        return 'Custom';
    }
  }
}

/// GPS mode options
enum GpsMode {
  lowPower,
  balanced,
  highAccuracy;

  String get displayName {
    switch (this) {
      case GpsMode.lowPower:
        return 'Low Power';
      case GpsMode.balanced:
        return 'Balanced';
      case GpsMode.highAccuracy:
        return 'High Accuracy';
    }
  }
}

/// Photo quality options for waypoint photos
enum PhotoQuality {
  /// 720p - faster, smaller files
  high,
  /// 1080p - good balance
  veryHigh,
  /// 4K/2160p - high quality, larger files
  ultraHigh,
  /// Maximum available resolution
  max;

  String get displayName {
    switch (this) {
      case PhotoQuality.high:
        return 'High (720p)';
      case PhotoQuality.veryHigh:
        return 'Very High (1080p)';
      case PhotoQuality.ultraHigh:
        return 'Ultra High (4K)';
      case PhotoQuality.max:
        return 'Maximum';
    }
  }

  String get description {
    switch (this) {
      case PhotoQuality.high:
        return 'Faster capture, smaller files';
      case PhotoQuality.veryHigh:
        return 'Good balance of quality and size';
      case PhotoQuality.ultraHigh:
        return 'High quality, larger files';
      case PhotoQuality.max:
        return 'Best quality your camera supports';
    }
  }
}

/// Custom color scheme for advanced theming
@immutable
class CustomColorScheme {
  const CustomColorScheme({
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.background,
    required this.error,
    required this.onPrimary,
    required this.onSecondary,
    required this.onSurface,
    required this.onBackground,
    required this.onError,
  });

  factory CustomColorScheme.fromJson(Map<String, dynamic> json) =>
      CustomColorScheme(
        primary: Color(json['primary'] as int),
        secondary: Color(json['secondary'] as int),
        surface: Color(json['surface'] as int),
        background: Color(json['background'] as int),
        error: Color(json['error'] as int),
        onPrimary: Color(json['on_primary'] as int),
        onSecondary: Color(json['on_secondary'] as int),
        onSurface: Color(json['on_surface'] as int),
        onBackground: Color(json['on_background'] as int),
        onError: Color(json['on_error'] as int),
      );

  final Color primary;
  final Color secondary;
  final Color surface;
  final Color background;
  final Color error;
  final Color onPrimary;
  final Color onSecondary;
  final Color onSurface;
  final Color onBackground;
  final Color onError;

  Map<String, dynamic> toJson() => {
        'primary': primary.toARGB32(),
        'secondary': secondary.toARGB32(),
        'surface': surface.toARGB32(),
        'background': background.toARGB32(),
        'error': error.toARGB32(),
        'on_primary': onPrimary.toARGB32(),
        'on_secondary': onSecondary.toARGB32(),
        'on_surface': onSurface.toARGB32(),
        'on_background': onBackground.toARGB32(),
        'on_error': onError.toARGB32(),
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomColorScheme &&
        other.primary == primary &&
        other.secondary == secondary &&
        other.surface == surface &&
        other.background == background &&
        other.error == error &&
        other.onPrimary == onPrimary &&
        other.onSecondary == onSecondary &&
        other.onSurface == onSurface &&
        other.onBackground == onBackground &&
        other.onError == onError;
  }

  @override
  int get hashCode => Object.hash(
        primary,
        secondary,
        surface,
        background,
        error,
        onPrimary,
        onSecondary,
        onSurface,
        onBackground,
        onError,
      );
}

/// Tracking notification settings
@immutable
class TrackingNotificationSettings {
  const TrackingNotificationSettings({
    this.sessionStarted = true,
    this.sessionPaused = true,
    this.sessionResumed = true,
    this.sessionCompleted = true,
    this.waypointAdded = true,
    this.photoTaken = true,
    this.lowBattery = true,
    this.gpsSignalLost = true,
    this.backgroundTracking = true,
  });

  factory TrackingNotificationSettings.fromJson(Map<String, dynamic> json) =>
      TrackingNotificationSettings(
        sessionStarted: json['session_started'] as bool? ?? true,
        sessionPaused: json['session_paused'] as bool? ?? true,
        sessionResumed: json['session_resumed'] as bool? ?? true,
        sessionCompleted: json['session_completed'] as bool? ?? true,
        waypointAdded: json['waypoint_added'] as bool? ?? true,
        photoTaken: json['photo_taken'] as bool? ?? true,
        lowBattery: json['low_battery'] as bool? ?? true,
        gpsSignalLost: json['gps_signal_lost'] as bool? ?? true,
        backgroundTracking: json['background_tracking'] as bool? ?? true,
      );

  final bool sessionStarted;
  final bool sessionPaused;
  final bool sessionResumed;
  final bool sessionCompleted;
  final bool waypointAdded;
  final bool photoTaken;
  final bool lowBattery;
  final bool gpsSignalLost;
  final bool backgroundTracking;

  TrackingNotificationSettings copyWith({
    bool? sessionStarted,
    bool? sessionPaused,
    bool? sessionResumed,
    bool? sessionCompleted,
    bool? waypointAdded,
    bool? photoTaken,
    bool? lowBattery,
    bool? gpsSignalLost,
    bool? backgroundTracking,
  }) =>
      TrackingNotificationSettings(
        sessionStarted: sessionStarted ?? this.sessionStarted,
        sessionPaused: sessionPaused ?? this.sessionPaused,
        sessionResumed: sessionResumed ?? this.sessionResumed,
        sessionCompleted: sessionCompleted ?? this.sessionCompleted,
        waypointAdded: waypointAdded ?? this.waypointAdded,
        photoTaken: photoTaken ?? this.photoTaken,
        lowBattery: lowBattery ?? this.lowBattery,
        gpsSignalLost: gpsSignalLost ?? this.gpsSignalLost,
        backgroundTracking: backgroundTracking ?? this.backgroundTracking,
      );

  Map<String, dynamic> toJson() => {
        'session_started': sessionStarted,
        'session_paused': sessionPaused,
        'session_resumed': sessionResumed,
        'session_completed': sessionCompleted,
        'waypoint_added': waypointAdded,
        'photo_taken': photoTaken,
        'low_battery': lowBattery,
        'gps_signal_lost': gpsSignalLost,
        'background_tracking': backgroundTracking,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrackingNotificationSettings &&
        other.sessionStarted == sessionStarted &&
        other.sessionPaused == sessionPaused &&
        other.sessionResumed == sessionResumed &&
        other.sessionCompleted == sessionCompleted &&
        other.waypointAdded == waypointAdded &&
        other.photoTaken == photoTaken &&
        other.lowBattery == lowBattery &&
        other.gpsSignalLost == gpsSignalLost &&
        other.backgroundTracking == backgroundTracking;
  }

  @override
  int get hashCode => Object.hash(
        sessionStarted,
        sessionPaused,
        sessionResumed,
        sessionCompleted,
        waypointAdded,
        photoTaken,
        lowBattery,
        gpsSignalLost,
        backgroundTracking,
      );
}

/// GPS notification settings
@immutable
class GpsNotificationSettings {
  const GpsNotificationSettings({
    this.enabled = true,
    this.notifyPoorAccuracy = true,
    this.notifyWeakSignal = true,
    this.notifyDrift = true,
    this.notifyEnvironmentChanges = true,
    this.notifyGoodConditions = false,
    this.notifyRecommendations = true,
  });

  factory GpsNotificationSettings.fromJson(Map<String, dynamic> json) =>
      GpsNotificationSettings(
        enabled: json['enabled'] as bool? ?? true,
        notifyPoorAccuracy: json['notify_poor_accuracy'] as bool? ?? true,
        notifyWeakSignal: json['notify_weak_signal'] as bool? ?? true,
        notifyDrift: json['notify_drift'] as bool? ?? true,
        notifyEnvironmentChanges:
            json['notify_environment_changes'] as bool? ?? true,
        notifyGoodConditions: json['notify_good_conditions'] as bool? ?? false,
        notifyRecommendations: json['notify_recommendations'] as bool? ?? true,
      );

  final bool enabled;
  final bool notifyPoorAccuracy;
  final bool notifyWeakSignal;
  final bool notifyDrift;
  final bool notifyEnvironmentChanges;
  final bool notifyGoodConditions;
  final bool notifyRecommendations;

  GpsNotificationSettings copyWith({
    bool? enabled,
    bool? notifyPoorAccuracy,
    bool? notifyWeakSignal,
    bool? notifyDrift,
    bool? notifyEnvironmentChanges,
    bool? notifyGoodConditions,
    bool? notifyRecommendations,
  }) =>
      GpsNotificationSettings(
        enabled: enabled ?? this.enabled,
        notifyPoorAccuracy: notifyPoorAccuracy ?? this.notifyPoorAccuracy,
        notifyWeakSignal: notifyWeakSignal ?? this.notifyWeakSignal,
        notifyDrift: notifyDrift ?? this.notifyDrift,
        notifyEnvironmentChanges:
            notifyEnvironmentChanges ?? this.notifyEnvironmentChanges,
        notifyGoodConditions: notifyGoodConditions ?? this.notifyGoodConditions,
        notifyRecommendations:
            notifyRecommendations ?? this.notifyRecommendations,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'notify_poor_accuracy': notifyPoorAccuracy,
        'notify_weak_signal': notifyWeakSignal,
        'notify_drift': notifyDrift,
        'notify_environment_changes': notifyEnvironmentChanges,
        'notify_good_conditions': notifyGoodConditions,
        'notify_recommendations': notifyRecommendations,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GpsNotificationSettings &&
        other.enabled == enabled &&
        other.notifyPoorAccuracy == notifyPoorAccuracy &&
        other.notifyWeakSignal == notifyWeakSignal &&
        other.notifyDrift == notifyDrift &&
        other.notifyEnvironmentChanges == notifyEnvironmentChanges &&
        other.notifyGoodConditions == notifyGoodConditions &&
        other.notifyRecommendations == notifyRecommendations;
  }

  @override
  int get hashCode => Object.hash(
        enabled,
        notifyPoorAccuracy,
        notifyWeakSignal,
        notifyDrift,
        notifyEnvironmentChanges,
        notifyGoodConditions,
        notifyRecommendations,
      );
}

/// System notification settings
@immutable
class SystemNotificationSettings {
  const SystemNotificationSettings({
    this.appUpdates = true,
    this.maintenanceAlerts = true,
    this.storageWarnings = true,
    this.permissionRequests = true,
    this.backupReminders = true,
    this.exportComplete = true,
    this.importComplete = true,
    this.errorAlerts = true,
  });

  factory SystemNotificationSettings.fromJson(Map<String, dynamic> json) =>
      SystemNotificationSettings(
        appUpdates: json['app_updates'] as bool? ?? true,
        maintenanceAlerts: json['maintenance_alerts'] as bool? ?? true,
        storageWarnings: json['storage_warnings'] as bool? ?? true,
        permissionRequests: json['permission_requests'] as bool? ?? true,
        backupReminders: json['backup_reminders'] as bool? ?? true,
        exportComplete: json['export_complete'] as bool? ?? true,
        importComplete: json['import_complete'] as bool? ?? true,
        errorAlerts: json['error_alerts'] as bool? ?? true,
      );

  final bool appUpdates;
  final bool maintenanceAlerts;
  final bool storageWarnings;
  final bool permissionRequests;
  final bool backupReminders;
  final bool exportComplete;
  final bool importComplete;
  final bool errorAlerts;

  SystemNotificationSettings copyWith({
    bool? appUpdates,
    bool? maintenanceAlerts,
    bool? storageWarnings,
    bool? permissionRequests,
    bool? backupReminders,
    bool? exportComplete,
    bool? importComplete,
    bool? errorAlerts,
  }) =>
      SystemNotificationSettings(
        appUpdates: appUpdates ?? this.appUpdates,
        maintenanceAlerts: maintenanceAlerts ?? this.maintenanceAlerts,
        storageWarnings: storageWarnings ?? this.storageWarnings,
        permissionRequests: permissionRequests ?? this.permissionRequests,
        backupReminders: backupReminders ?? this.backupReminders,
        exportComplete: exportComplete ?? this.exportComplete,
        importComplete: importComplete ?? this.importComplete,
        errorAlerts: errorAlerts ?? this.errorAlerts,
      );

  Map<String, dynamic> toJson() => {
        'app_updates': appUpdates,
        'maintenance_alerts': maintenanceAlerts,
        'storage_warnings': storageWarnings,
        'permission_requests': permissionRequests,
        'backup_reminders': backupReminders,
        'export_complete': exportComplete,
        'import_complete': importComplete,
        'error_alerts': errorAlerts,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SystemNotificationSettings &&
        other.appUpdates == appUpdates &&
        other.maintenanceAlerts == maintenanceAlerts &&
        other.storageWarnings == storageWarnings &&
        other.permissionRequests == permissionRequests &&
        other.backupReminders == backupReminders &&
        other.exportComplete == exportComplete &&
        other.importComplete == importComplete &&
        other.errorAlerts == errorAlerts;
  }

  @override
  int get hashCode => Object.hash(
        appUpdates,
        maintenanceAlerts,
        storageWarnings,
        permissionRequests,
        backupReminders,
        exportComplete,
        importComplete,
        errorAlerts,
      );
}

/// Map-specific settings
@immutable
class MapSettings {
  const MapSettings({
    this.defaultMapType = MapType.streets,
    this.mapStylePreference = MapStylePreference.outdoors,
    this.showScale = true,
    this.showCompass = true,
    this.showCurrentLocation = true,
    this.followLocation = true,
    this.rotateWithCompass = false,
    this.showTrail = true,
    this.trailColor = const Color(0xFF2196F3),
    this.trailWidth = 3.0,
    // Land overlay settings
    this.showLandOverlay = true,
    this.landOverlayOpacity = 0.5,
    this.useBFFData = true,
    this.landOwnershipFilter,
    // Terrain relief (hillshade) overlay
    this.showHillshade = false,
    // HUD display options
    this.hudShowCoordinates = false,
    this.hudShowElevation = false,
    this.hudShowSpeed = false,
    this.hudShowHeading = false,
    this.hudShowCenterTarget = false,
    // Control bar visibility
    this.showControlBar = true,
    // Land rights banner (shows permission status at map center)
    this.showLandRightsBanner = true,
    // Filter overlay visibility (persisted across sessions)
    this.showTrailsOverlay = true,
    this.showHistoricalPlaces = true,
    this.showCustomMarkers = true,
    // Cell coverage overlay (premium feature)
    this.showCellCoverage = false,
  });

  factory MapSettings.fromJson(Map<String, dynamic> json) => MapSettings(
        defaultMapType: MapType.values.firstWhere(
          (e) => e.name == json['default_map_type'],
          orElse: () => MapType.streets,
        ),
        mapStylePreference: MapStylePreference.values.firstWhere(
          (e) => e.name == json['map_style_preference'],
          orElse: () => MapStylePreference.outdoors,
        ),
        showScale: json['show_scale'] as bool? ?? true,
        showCompass: json['show_compass'] as bool? ?? true,
        showCurrentLocation: json['show_current_location'] as bool? ?? true,
        followLocation: json['follow_location'] as bool? ?? true,
        rotateWithCompass: json['rotate_with_compass'] as bool? ?? false,
        showTrail: json['show_trail'] as bool? ?? true,
        trailColor: Color(json['trail_color'] as int? ?? 0xFF2196F3),
        trailWidth: (json['trail_width'] as num?)?.toDouble() ?? 3.0,
        showLandOverlay: json['show_land_overlay'] as bool? ?? true,
        landOverlayOpacity:
            (json['land_overlay_opacity'] as num?)?.toDouble() ?? 0.5,
        useBFFData: json['use_bff_data'] as bool? ?? true,
        landOwnershipFilter: json['land_ownership_filter'] != null
          ? LandOwnershipFilter.fromJson(json['land_ownership_filter'] as Map<String, dynamic>)
          : null,
        showHillshade: json['show_hillshade'] as bool? ?? false,
        hudShowCoordinates: json['hud_show_coordinates'] as bool? ?? false,
        hudShowElevation: json['hud_show_elevation'] as bool? ?? false,
        hudShowSpeed: json['hud_show_speed'] as bool? ?? false,
        hudShowHeading: json['hud_show_heading'] as bool? ?? false,
        hudShowCenterTarget: json['hud_show_center_target'] as bool? ?? false,
        showControlBar: json['show_control_bar'] as bool? ?? true,
        showLandRightsBanner: json['show_land_rights_banner'] as bool? ?? true,
        showTrailsOverlay: json['show_trails_overlay'] as bool? ?? true,
        showHistoricalPlaces: json['show_historical_places'] as bool? ?? true,
        showCustomMarkers: json['show_custom_markers'] as bool? ?? true,
        showCellCoverage: json['show_cell_coverage'] as bool? ?? false,
      );

  final MapType defaultMapType;
  final MapStylePreference mapStylePreference;
  final bool showScale;
  final bool showCompass;
  final bool showCurrentLocation;
  final bool followLocation;
  final bool rotateWithCompass;
  final bool showTrail;
  final Color trailColor;
  final double trailWidth;
  // Land overlay settings
  final bool showLandOverlay;
  final double landOverlayOpacity;
  final bool useBFFData;
  final LandOwnershipFilter? landOwnershipFilter;
  // Terrain relief (hillshade) overlay
  final bool showHillshade;
  // HUD display options
  final bool hudShowCoordinates;
  final bool hudShowElevation;
  final bool hudShowSpeed;
  final bool hudShowHeading;
  final bool hudShowCenterTarget;
  // Control bar visibility
  final bool showControlBar;
  // Land rights banner (shows permission status at map center)
  final bool showLandRightsBanner;
  // Filter overlay visibility (persisted across sessions)
  final bool showTrailsOverlay;
  final bool showHistoricalPlaces;
  final bool showCustomMarkers;
  // Cell coverage overlay (premium feature)
  final bool showCellCoverage;

  MapSettings copyWith({
    MapType? defaultMapType,
    MapStylePreference? mapStylePreference,
    bool? showScale,
    bool? showCompass,
    bool? showCurrentLocation,
    bool? followLocation,
    bool? rotateWithCompass,
    bool? showTrail,
    Color? trailColor,
    double? trailWidth,
    bool? showLandOverlay,
    double? landOverlayOpacity,
    bool? useBFFData,
    LandOwnershipFilter? landOwnershipFilter,
    bool? showHillshade,
    bool? hudShowCoordinates,
    bool? hudShowElevation,
    bool? hudShowSpeed,
    bool? hudShowHeading,
    bool? hudShowCenterTarget,
    bool? showControlBar,
    bool? showLandRightsBanner,
    bool? showTrailsOverlay,
    bool? showHistoricalPlaces,
    bool? showCustomMarkers,
    bool? showCellCoverage,
  }) =>
      MapSettings(
        defaultMapType: defaultMapType ?? this.defaultMapType,
        mapStylePreference: mapStylePreference ?? this.mapStylePreference,
        showScale: showScale ?? this.showScale,
        showCompass: showCompass ?? this.showCompass,
        showCurrentLocation: showCurrentLocation ?? this.showCurrentLocation,
        followLocation: followLocation ?? this.followLocation,
        rotateWithCompass: rotateWithCompass ?? this.rotateWithCompass,
        showTrail: showTrail ?? this.showTrail,
        trailColor: trailColor ?? this.trailColor,
        trailWidth: trailWidth ?? this.trailWidth,
        showLandOverlay: showLandOverlay ?? this.showLandOverlay,
        landOverlayOpacity: landOverlayOpacity ?? this.landOverlayOpacity,
        useBFFData: useBFFData ?? this.useBFFData,
        landOwnershipFilter: landOwnershipFilter ?? this.landOwnershipFilter,
        showHillshade: showHillshade ?? this.showHillshade,
        hudShowCoordinates: hudShowCoordinates ?? this.hudShowCoordinates,
        hudShowElevation: hudShowElevation ?? this.hudShowElevation,
        hudShowSpeed: hudShowSpeed ?? this.hudShowSpeed,
        hudShowHeading: hudShowHeading ?? this.hudShowHeading,
        hudShowCenterTarget: hudShowCenterTarget ?? this.hudShowCenterTarget,
        showControlBar: showControlBar ?? this.showControlBar,
        showLandRightsBanner: showLandRightsBanner ?? this.showLandRightsBanner,
        showTrailsOverlay: showTrailsOverlay ?? this.showTrailsOverlay,
        showHistoricalPlaces: showHistoricalPlaces ?? this.showHistoricalPlaces,
        showCustomMarkers: showCustomMarkers ?? this.showCustomMarkers,
        showCellCoverage: showCellCoverage ?? this.showCellCoverage,
      );

  Map<String, dynamic> toJson() => {
        'default_map_type': defaultMapType.name,
        'map_style_preference': mapStylePreference.name,
        'show_scale': showScale,
        'show_compass': showCompass,
        'show_current_location': showCurrentLocation,
        'follow_location': followLocation,
        'rotate_with_compass': rotateWithCompass,
        'show_trail': showTrail,
        'trail_color': trailColor.toARGB32(),
        'trail_width': trailWidth,
        'show_land_overlay': showLandOverlay,
        'land_overlay_opacity': landOverlayOpacity,
        'use_bff_data': useBFFData,
        'land_ownership_filter': landOwnershipFilter?.toJson(),
        'show_hillshade': showHillshade,
        'hud_show_coordinates': hudShowCoordinates,
        'hud_show_elevation': hudShowElevation,
        'hud_show_speed': hudShowSpeed,
        'hud_show_heading': hudShowHeading,
        'hud_show_center_target': hudShowCenterTarget,
        'show_control_bar': showControlBar,
        'show_land_rights_banner': showLandRightsBanner,
        'show_trails_overlay': showTrailsOverlay,
        'show_historical_places': showHistoricalPlaces,
        'show_custom_markers': showCustomMarkers,
        'show_cell_coverage': showCellCoverage,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapSettings &&
        other.defaultMapType == defaultMapType &&
        other.showScale == showScale &&
        other.showCompass == showCompass &&
        other.showCurrentLocation == showCurrentLocation &&
        other.followLocation == followLocation &&
        other.rotateWithCompass == rotateWithCompass &&
        other.showTrail == showTrail &&
        other.trailColor == trailColor &&
        other.trailWidth == trailWidth &&
        other.showLandOverlay == showLandOverlay &&
        other.landOverlayOpacity == landOverlayOpacity &&
        other.useBFFData == useBFFData &&
        other.landOwnershipFilter == landOwnershipFilter &&
        other.showHillshade == showHillshade &&
        other.hudShowCoordinates == hudShowCoordinates &&
        other.hudShowElevation == hudShowElevation &&
        other.hudShowSpeed == hudShowSpeed &&
        other.hudShowHeading == hudShowHeading &&
        other.hudShowCenterTarget == hudShowCenterTarget &&
        other.showControlBar == showControlBar &&
        other.showLandRightsBanner == showLandRightsBanner &&
        other.showTrailsOverlay == showTrailsOverlay &&
        other.showHistoricalPlaces == showHistoricalPlaces &&
        other.showCustomMarkers == showCustomMarkers &&
        other.showCellCoverage == showCellCoverage;
  }

  @override
  int get hashCode => Object.hash(
        defaultMapType,
        showScale,
        showCompass,
        showCurrentLocation,
        followLocation,
        rotateWithCompass,
        showTrail,
        trailColor,
        trailWidth,
        showLandOverlay,
        landOverlayOpacity,
        useBFFData,
        landOwnershipFilter,
        hudShowCoordinates,
        hudShowElevation,
        Object.hash(showHillshade, hudShowSpeed, hudShowHeading, hudShowCenterTarget, showControlBar, showLandRightsBanner, showTrailsOverlay, showHistoricalPlaces, showCustomMarkers, showCellCoverage),
      );
}

/// Map type options (Mapbox styles)
enum MapType {
  streets,
  satellite,
  terrain,
  hybrid;

  String get displayName {
    switch (this) {
      case MapType.streets:
        return 'Streets';
      case MapType.satellite:
        return 'Satellite';
      case MapType.terrain:
        return 'Outdoors';
      case MapType.hybrid:
        return 'Satellite Streets';
    }
  }
}

/// User's preferred map style (persisted across sessions)
enum MapStylePreference {
  /// Theme-aware style (dark/light mode) - default
  outdoors,
  /// Satellite with street labels
  satellite,
  /// Standard street map
  streets;

  String get displayName {
    switch (this) {
      case MapStylePreference.outdoors:
        return 'Outdoors';
      case MapStylePreference.satellite:
        return 'Satellite';
      case MapStylePreference.streets:
        return 'Streets';
    }
  }
}

/// Storage and data management settings
@immutable
class StorageSettings {
  const StorageSettings({
    this.maxStorageSize = 1024, // MB
    this.enableAutoCleanup = true,
    this.cleanupThreshold = 0.9, // 90%
    this.keepRecentDays = 30,
    this.compressOldData = true,
    this.compressionThreshold = 90, // days
    this.enableBackup = true,
    this.backupFrequency = BackupFrequency.weekly,
    this.backupLocation = BackupLocation.local,
    this.maxBackupCount = 5,
  });

  factory StorageSettings.fromJson(Map<String, dynamic> json) =>
      StorageSettings(
        maxStorageSize: json['max_storage_size'] as int? ?? 1024,
        enableAutoCleanup: json['enable_auto_cleanup'] as bool? ?? true,
        cleanupThreshold:
            (json['cleanup_threshold'] as num?)?.toDouble() ?? 0.9,
        keepRecentDays: json['keep_recent_days'] as int? ?? 30,
        compressOldData: json['compress_old_data'] as bool? ?? true,
        compressionThreshold: json['compression_threshold'] as int? ?? 90,
        enableBackup: json['enable_backup'] as bool? ?? true,
        backupFrequency: BackupFrequency.values.firstWhere(
          (e) => e.name == json['backup_frequency'],
          orElse: () => BackupFrequency.weekly,
        ),
        backupLocation: BackupLocation.values.firstWhere(
          (e) => e.name == json['backup_location'],
          orElse: () => BackupLocation.local,
        ),
        maxBackupCount: json['max_backup_count'] as int? ?? 5,
      );

  final int maxStorageSize;
  final bool enableAutoCleanup;
  final double cleanupThreshold;
  final int keepRecentDays;
  final bool compressOldData;
  final int compressionThreshold;
  final bool enableBackup;
  final BackupFrequency backupFrequency;
  final BackupLocation backupLocation;
  final int maxBackupCount;

  StorageSettings copyWith({
    int? maxStorageSize,
    bool? enableAutoCleanup,
    double? cleanupThreshold,
    int? keepRecentDays,
    bool? compressOldData,
    int? compressionThreshold,
    bool? enableBackup,
    BackupFrequency? backupFrequency,
    BackupLocation? backupLocation,
    int? maxBackupCount,
  }) =>
      StorageSettings(
        maxStorageSize: maxStorageSize ?? this.maxStorageSize,
        enableAutoCleanup: enableAutoCleanup ?? this.enableAutoCleanup,
        cleanupThreshold: cleanupThreshold ?? this.cleanupThreshold,
        keepRecentDays: keepRecentDays ?? this.keepRecentDays,
        compressOldData: compressOldData ?? this.compressOldData,
        compressionThreshold: compressionThreshold ?? this.compressionThreshold,
        enableBackup: enableBackup ?? this.enableBackup,
        backupFrequency: backupFrequency ?? this.backupFrequency,
        backupLocation: backupLocation ?? this.backupLocation,
        maxBackupCount: maxBackupCount ?? this.maxBackupCount,
      );

  Map<String, dynamic> toJson() => {
        'max_storage_size': maxStorageSize,
        'enable_auto_cleanup': enableAutoCleanup,
        'cleanup_threshold': cleanupThreshold,
        'keep_recent_days': keepRecentDays,
        'compress_old_data': compressOldData,
        'compression_threshold': compressionThreshold,
        'enable_backup': enableBackup,
        'backup_frequency': backupFrequency.name,
        'backup_location': backupLocation.name,
        'max_backup_count': maxBackupCount,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StorageSettings &&
        other.maxStorageSize == maxStorageSize &&
        other.enableAutoCleanup == enableAutoCleanup &&
        other.cleanupThreshold == cleanupThreshold &&
        other.keepRecentDays == keepRecentDays &&
        other.compressOldData == compressOldData &&
        other.compressionThreshold == compressionThreshold &&
        other.enableBackup == enableBackup &&
        other.backupFrequency == backupFrequency &&
        other.backupLocation == backupLocation &&
        other.maxBackupCount == maxBackupCount;
  }

  @override
  int get hashCode => Object.hash(
        maxStorageSize,
        enableAutoCleanup,
        cleanupThreshold,
        keepRecentDays,
        compressOldData,
        compressionThreshold,
        enableBackup,
        backupFrequency,
        backupLocation,
        maxBackupCount,
      );
}

/// Backup frequency options
enum BackupFrequency {
  manual,
  daily,
  weekly,
  monthly;

  String get displayName {
    switch (this) {
      case BackupFrequency.manual:
        return 'Manual Only';
      case BackupFrequency.daily:
        return 'Daily';
      case BackupFrequency.weekly:
        return 'Weekly';
      case BackupFrequency.monthly:
        return 'Monthly';
    }
  }
}

/// Backup location options
enum BackupLocation {
  local,
  cloud,
  external;

  String get displayName {
    switch (this) {
      case BackupLocation.local:
        return 'Local Storage';
      case BackupLocation.cloud:
        return 'Cloud Storage';
      case BackupLocation.external:
        return 'External Storage';
    }
  }
}

/// Export and import settings
@immutable
class ExportSettings {
  const ExportSettings({
    this.defaultFormat = ExportFormat.gpx,
    this.includePhotos = true,
    this.includeWaypoints = true,
    this.includeStatistics = true,
    this.compressExports = true,
    this.anonymizeData = false,
    this.coordinatePrecision = 6,
    this.timestampFormat = TimestampFormat.iso8601,
    this.enableAutoExport = false,
    this.autoExportFrequency = AutoExportFrequency.weekly,
  });

  factory ExportSettings.fromJson(Map<String, dynamic> json) => ExportSettings(
        defaultFormat: ExportFormat.values.firstWhere(
          (e) => e.name == json['default_format'],
          orElse: () => ExportFormat.gpx,
        ),
        includePhotos: json['include_photos'] as bool? ?? true,
        includeWaypoints: json['include_waypoints'] as bool? ?? true,
        includeStatistics: json['include_statistics'] as bool? ?? true,
        compressExports: json['compress_exports'] as bool? ?? true,
        anonymizeData: json['anonymize_data'] as bool? ?? false,
        coordinatePrecision: json['coordinate_precision'] as int? ?? 6,
        timestampFormat: TimestampFormat.values.firstWhere(
          (e) => e.name == json['timestamp_format'],
          orElse: () => TimestampFormat.iso8601,
        ),
        enableAutoExport: json['enable_auto_export'] as bool? ?? false,
        autoExportFrequency: AutoExportFrequency.values.firstWhere(
          (e) => e.name == json['auto_export_frequency'],
          orElse: () => AutoExportFrequency.weekly,
        ),
      );

  final ExportFormat defaultFormat;
  final bool includePhotos;
  final bool includeWaypoints;
  final bool includeStatistics;
  final bool compressExports;
  final bool anonymizeData;
  final int coordinatePrecision;
  final TimestampFormat timestampFormat;
  final bool enableAutoExport;
  final AutoExportFrequency autoExportFrequency;

  ExportSettings copyWith({
    ExportFormat? defaultFormat,
    bool? includePhotos,
    bool? includeWaypoints,
    bool? includeStatistics,
    bool? compressExports,
    bool? anonymizeData,
    int? coordinatePrecision,
    TimestampFormat? timestampFormat,
    bool? enableAutoExport,
    AutoExportFrequency? autoExportFrequency,
  }) =>
      ExportSettings(
        defaultFormat: defaultFormat ?? this.defaultFormat,
        includePhotos: includePhotos ?? this.includePhotos,
        includeWaypoints: includeWaypoints ?? this.includeWaypoints,
        includeStatistics: includeStatistics ?? this.includeStatistics,
        compressExports: compressExports ?? this.compressExports,
        anonymizeData: anonymizeData ?? this.anonymizeData,
        coordinatePrecision: coordinatePrecision ?? this.coordinatePrecision,
        timestampFormat: timestampFormat ?? this.timestampFormat,
        enableAutoExport: enableAutoExport ?? this.enableAutoExport,
        autoExportFrequency: autoExportFrequency ?? this.autoExportFrequency,
      );

  Map<String, dynamic> toJson() => {
        'default_format': defaultFormat.name,
        'include_photos': includePhotos,
        'include_waypoints': includeWaypoints,
        'include_statistics': includeStatistics,
        'compress_exports': compressExports,
        'anonymize_data': anonymizeData,
        'coordinate_precision': coordinatePrecision,
        'timestamp_format': timestampFormat.name,
        'enable_auto_export': enableAutoExport,
        'auto_export_frequency': autoExportFrequency.name,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExportSettings &&
        other.defaultFormat == defaultFormat &&
        other.includePhotos == includePhotos &&
        other.includeWaypoints == includeWaypoints &&
        other.includeStatistics == includeStatistics &&
        other.compressExports == compressExports &&
        other.anonymizeData == anonymizeData &&
        other.coordinatePrecision == coordinatePrecision &&
        other.timestampFormat == timestampFormat &&
        other.enableAutoExport == enableAutoExport &&
        other.autoExportFrequency == autoExportFrequency;
  }

  @override
  int get hashCode => Object.hash(
        defaultFormat,
        includePhotos,
        includeWaypoints,
        includeStatistics,
        compressExports,
        anonymizeData,
        coordinatePrecision,
        timestampFormat,
        enableAutoExport,
        autoExportFrequency,
      );
}

/// Export format options
enum ExportFormat {
  gpx,
  kml,
  geojson,
  csv,
  json;

  String get displayName {
    switch (this) {
      case ExportFormat.gpx:
        return 'GPX';
      case ExportFormat.kml:
        return 'KML';
      case ExportFormat.geojson:
        return 'GeoJSON';
      case ExportFormat.csv:
        return 'CSV';
      case ExportFormat.json:
        return 'JSON';
    }
  }

  String get fileExtension {
    switch (this) {
      case ExportFormat.gpx:
        return '.gpx';
      case ExportFormat.kml:
        return '.kml';
      case ExportFormat.geojson:
        return '.geojson';
      case ExportFormat.csv:
        return '.csv';
      case ExportFormat.json:
        return '.json';
    }
  }
}

/// Timestamp format options
enum TimestampFormat {
  iso8601,
  unix,
  readable;

  String get displayName {
    switch (this) {
      case TimestampFormat.iso8601:
        return 'ISO 8601 (2023-12-25T14:30:00Z)';
      case TimestampFormat.unix:
        return 'Unix Timestamp (1703516200)';
      case TimestampFormat.readable:
        return 'Human Readable (Dec 25, 2023 2:30 PM)';
    }
  }
}

/// Auto export frequency options
enum AutoExportFrequency {
  daily,
  weekly,
  monthly,
  afterSession;

  String get displayName {
    switch (this) {
      case AutoExportFrequency.daily:
        return 'Daily';
      case AutoExportFrequency.weekly:
        return 'Weekly';
      case AutoExportFrequency.monthly:
        return 'Monthly';
      case AutoExportFrequency.afterSession:
        return 'After Each Session';
    }
  }
}

/// Accessibility settings
@immutable
class AccessibilitySettings {
  const AccessibilitySettings({
    this.enableScreenReader = false,
    this.enableHighContrast = false,
    this.enableLargeText = false,
    this.enableVoiceCommands = false,
    this.enableHapticFeedback = true,
    this.enableAudioCues = false,
    this.reduceMotion = false,
    this.enableColorFilters = false,
    this.buttonSize = ButtonSize.medium,
    this.touchTargetSize = TouchTargetSize.medium,
  });

  factory AccessibilitySettings.fromJson(Map<String, dynamic> json) =>
      AccessibilitySettings(
        enableScreenReader: json['enable_screen_reader'] as bool? ?? false,
        enableHighContrast: json['enable_high_contrast'] as bool? ?? false,
        enableLargeText: json['enable_large_text'] as bool? ?? false,
        enableVoiceCommands: json['enable_voice_commands'] as bool? ?? false,
        enableHapticFeedback: json['enable_haptic_feedback'] as bool? ?? true,
        enableAudioCues: json['enable_audio_cues'] as bool? ?? false,
        reduceMotion: json['reduce_motion'] as bool? ?? false,
        enableColorFilters: json['enable_color_filters'] as bool? ?? false,
        buttonSize: ButtonSize.values.firstWhere(
          (e) => e.name == json['button_size'],
          orElse: () => ButtonSize.medium,
        ),
        touchTargetSize: TouchTargetSize.values.firstWhere(
          (e) => e.name == json['touch_target_size'],
          orElse: () => TouchTargetSize.medium,
        ),
      );

  final bool enableScreenReader;
  final bool enableHighContrast;
  final bool enableLargeText;
  final bool enableVoiceCommands;
  final bool enableHapticFeedback;
  final bool enableAudioCues;
  final bool reduceMotion;
  final bool enableColorFilters;
  final ButtonSize buttonSize;
  final TouchTargetSize touchTargetSize;

  AccessibilitySettings copyWith({
    bool? enableScreenReader,
    bool? enableHighContrast,
    bool? enableLargeText,
    bool? enableVoiceCommands,
    bool? enableHapticFeedback,
    bool? enableAudioCues,
    bool? reduceMotion,
    bool? enableColorFilters,
    ButtonSize? buttonSize,
    TouchTargetSize? touchTargetSize,
  }) =>
      AccessibilitySettings(
        enableScreenReader: enableScreenReader ?? this.enableScreenReader,
        enableHighContrast: enableHighContrast ?? this.enableHighContrast,
        enableLargeText: enableLargeText ?? this.enableLargeText,
        enableVoiceCommands: enableVoiceCommands ?? this.enableVoiceCommands,
        enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
        enableAudioCues: enableAudioCues ?? this.enableAudioCues,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        enableColorFilters: enableColorFilters ?? this.enableColorFilters,
        buttonSize: buttonSize ?? this.buttonSize,
        touchTargetSize: touchTargetSize ?? this.touchTargetSize,
      );

  Map<String, dynamic> toJson() => {
        'enable_screen_reader': enableScreenReader,
        'enable_high_contrast': enableHighContrast,
        'enable_large_text': enableLargeText,
        'enable_voice_commands': enableVoiceCommands,
        'enable_haptic_feedback': enableHapticFeedback,
        'enable_audio_cues': enableAudioCues,
        'reduce_motion': reduceMotion,
        'enable_color_filters': enableColorFilters,
        'button_size': buttonSize.name,
        'touch_target_size': touchTargetSize.name,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccessibilitySettings &&
        other.enableScreenReader == enableScreenReader &&
        other.enableHighContrast == enableHighContrast &&
        other.enableLargeText == enableLargeText &&
        other.enableVoiceCommands == enableVoiceCommands &&
        other.enableHapticFeedback == enableHapticFeedback &&
        other.enableAudioCues == enableAudioCues &&
        other.reduceMotion == reduceMotion &&
        other.enableColorFilters == enableColorFilters &&
        other.buttonSize == buttonSize &&
        other.touchTargetSize == touchTargetSize;
  }

  @override
  int get hashCode => Object.hash(
        enableScreenReader,
        enableHighContrast,
        enableLargeText,
        enableVoiceCommands,
        enableHapticFeedback,
        enableAudioCues,
        reduceMotion,
        enableColorFilters,
        buttonSize,
        touchTargetSize,
      );
}

/// Button size options
enum ButtonSize {
  small,
  medium,
  large,
  extraLarge;

  String get displayName {
    switch (this) {
      case ButtonSize.small:
        return 'Small';
      case ButtonSize.medium:
        return 'Medium';
      case ButtonSize.large:
        return 'Large';
      case ButtonSize.extraLarge:
        return 'Extra Large';
    }
  }

  double get scaleFactor {
    switch (this) {
      case ButtonSize.small:
        return 0.8;
      case ButtonSize.medium:
        return 1.0;
      case ButtonSize.large:
        return 1.2;
      case ButtonSize.extraLarge:
        return 1.4;
    }
  }
}

/// Touch target size options
enum TouchTargetSize {
  small,
  medium,
  large,
  extraLarge;

  String get displayName {
    switch (this) {
      case TouchTargetSize.small:
        return 'Small (36dp)';
      case TouchTargetSize.medium:
        return 'Medium (48dp)';
      case TouchTargetSize.large:
        return 'Large (56dp)';
      case TouchTargetSize.extraLarge:
        return 'Extra Large (64dp)';
    }
  }

  double get minSize {
    switch (this) {
      case TouchTargetSize.small:
        return 36.0;
      case TouchTargetSize.medium:
        return 48.0;
      case TouchTargetSize.large:
        return 56.0;
      case TouchTargetSize.extraLarge:
        return 64.0;
    }
  }
}

/// Advanced settings for power users
@immutable
class AdvancedSettings {
  const AdvancedSettings({
    this.enableDebugMode = false,
    this.enableVerboseLogging = false,
    this.enablePerformanceMonitoring = false,
    this.enableExperimentalFeatures = false,
    this.customApiEndpoint,
    this.networkTimeout = const Duration(seconds: 30),
    this.maxRetryAttempts = 3,
    this.enableDeveloperOptions = false,
    this.customUserAgent,
    this.enableBetaFeatures = false,
  });

  factory AdvancedSettings.fromJson(Map<String, dynamic> json) =>
      AdvancedSettings(
        enableDebugMode: json['enable_debug_mode'] as bool? ?? false,
        enableVerboseLogging: json['enable_verbose_logging'] as bool? ?? false,
        enablePerformanceMonitoring:
            json['enable_performance_monitoring'] as bool? ?? false,
        enableExperimentalFeatures:
            json['enable_experimental_features'] as bool? ?? false,
        customApiEndpoint: json['custom_api_endpoint'] as String?,
        networkTimeout:
            Duration(seconds: json['network_timeout_seconds'] as int? ?? 30),
        maxRetryAttempts: json['max_retry_attempts'] as int? ?? 3,
        enableDeveloperOptions:
            json['enable_developer_options'] as bool? ?? false,
        customUserAgent: json['custom_user_agent'] as String?,
        enableBetaFeatures: json['enable_beta_features'] as bool? ?? false,
      );

  final bool enableDebugMode;
  final bool enableVerboseLogging;
  final bool enablePerformanceMonitoring;
  final bool enableExperimentalFeatures;
  final String? customApiEndpoint;
  final Duration networkTimeout;
  final int maxRetryAttempts;
  final bool enableDeveloperOptions;
  final String? customUserAgent;
  final bool enableBetaFeatures;

  AdvancedSettings copyWith({
    bool? enableDebugMode,
    bool? enableVerboseLogging,
    bool? enablePerformanceMonitoring,
    bool? enableExperimentalFeatures,
    String? customApiEndpoint,
    Duration? networkTimeout,
    int? maxRetryAttempts,
    bool? enableDeveloperOptions,
    String? customUserAgent,
    bool? enableBetaFeatures,
  }) =>
      AdvancedSettings(
        enableDebugMode: enableDebugMode ?? this.enableDebugMode,
        enableVerboseLogging: enableVerboseLogging ?? this.enableVerboseLogging,
        enablePerformanceMonitoring:
            enablePerformanceMonitoring ?? this.enablePerformanceMonitoring,
        enableExperimentalFeatures:
            enableExperimentalFeatures ?? this.enableExperimentalFeatures,
        customApiEndpoint: customApiEndpoint ?? this.customApiEndpoint,
        networkTimeout: networkTimeout ?? this.networkTimeout,
        maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
        enableDeveloperOptions:
            enableDeveloperOptions ?? this.enableDeveloperOptions,
        customUserAgent: customUserAgent ?? this.customUserAgent,
        enableBetaFeatures: enableBetaFeatures ?? this.enableBetaFeatures,
      );

  Map<String, dynamic> toJson() => {
        'enable_debug_mode': enableDebugMode,
        'enable_verbose_logging': enableVerboseLogging,
        'enable_performance_monitoring': enablePerformanceMonitoring,
        'enable_experimental_features': enableExperimentalFeatures,
        'custom_api_endpoint': customApiEndpoint,
        'network_timeout_seconds': networkTimeout.inSeconds,
        'max_retry_attempts': maxRetryAttempts,
        'enable_developer_options': enableDeveloperOptions,
        'custom_user_agent': customUserAgent,
        'enable_beta_features': enableBetaFeatures,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdvancedSettings &&
        other.enableDebugMode == enableDebugMode &&
        other.enableVerboseLogging == enableVerboseLogging &&
        other.enablePerformanceMonitoring == enablePerformanceMonitoring &&
        other.enableExperimentalFeatures == enableExperimentalFeatures &&
        other.customApiEndpoint == customApiEndpoint &&
        other.networkTimeout == networkTimeout &&
        other.maxRetryAttempts == maxRetryAttempts &&
        other.enableDeveloperOptions == enableDeveloperOptions &&
        other.customUserAgent == customUserAgent &&
        other.enableBetaFeatures == enableBetaFeatures;
  }

  @override
  int get hashCode => Object.hash(
        enableDebugMode,
        enableVerboseLogging,
        enablePerformanceMonitoring,
        enableExperimentalFeatures,
        customApiEndpoint,
        networkTimeout,
        maxRetryAttempts,
        enableDeveloperOptions,
        customUserAgent,
        enableBetaFeatures,
      );
}

/// General application settings
@immutable
class GeneralSettings {
  const GeneralSettings({
    this.language = 'en',
    this.region = 'US',
    this.units = MeasurementUnits.imperial,
    this.coordinateFormat = CoordinateFormat.decimal,
    this.timeFormat = TimeFormat.format24,
    this.firstDayOfWeek = 1,
    this.enableAutoStart = false,
    this.enableAutoSave = true,
    this.autoSaveInterval = const Duration(minutes: 5),
    this.enableLocationServices = true,
    this.enableBackgroundLocation = false,
    this.showWelcomeScreen = true,
    this.enableTutorials = true,
    this.showTutorials = true,
    this.enableTips = true,
    this.confirmBeforeDelete = true,
    this.checkForUpdates = true,
    this.enableCrashReporting = true,
    this.enableAnalytics = false,
  });

  factory GeneralSettings.fromJson(Map<String, dynamic> json) =>
      GeneralSettings(
        language: json['language'] as String? ?? 'en',
        region: json['region'] as String? ?? 'US',
        units: MeasurementUnits.values.firstWhere(
          (e) => e.name == json['units'],
          orElse: () => MeasurementUnits.imperial,
        ),
        coordinateFormat: CoordinateFormat.values.firstWhere(
          (e) => e.name == json['coordinate_format'],
          orElse: () => CoordinateFormat.decimal,
        ),
        timeFormat: TimeFormat.values.firstWhere(
          (e) => e.name == json['time_format'],
          orElse: () => TimeFormat.format24,
        ),
        firstDayOfWeek: json['first_day_of_week'] as int? ?? 1,
        enableAutoStart: json['enable_auto_start'] as bool? ?? false,
        enableAutoSave: json['enable_auto_save'] as bool? ?? true,
        autoSaveInterval: Duration(
          minutes: json['auto_save_interval_minutes'] as int? ?? 5,
        ),
        enableLocationServices:
            json['enable_location_services'] as bool? ?? true,
        enableBackgroundLocation:
            json['enable_background_location'] as bool? ?? false,
        showWelcomeScreen: json['show_welcome_screen'] as bool? ?? true,
        enableTutorials: json['enable_tutorials'] as bool? ?? true,
        showTutorials: json['show_tutorials'] as bool? ?? true,
        enableTips: json['enable_tips'] as bool? ?? true,
        confirmBeforeDelete: json['confirm_before_delete'] as bool? ?? true,
        checkForUpdates: json['check_for_updates'] as bool? ?? true,
        enableCrashReporting: json['enable_crash_reporting'] as bool? ?? true,
        enableAnalytics: json['enable_analytics'] as bool? ?? false,
      );

  final String language;
  final String region;
  final MeasurementUnits units;
  final CoordinateFormat coordinateFormat;
  final TimeFormat timeFormat;
  final int firstDayOfWeek;
  final bool enableAutoStart;
  final bool enableAutoSave;
  final Duration autoSaveInterval;
  final bool enableLocationServices;
  final bool enableBackgroundLocation;
  final bool showWelcomeScreen;
  final bool enableTutorials;
  final bool showTutorials;
  final bool enableTips;
  final bool confirmBeforeDelete;
  final bool checkForUpdates;
  final bool enableCrashReporting;
  final bool enableAnalytics;

  GeneralSettings copyWith({
    String? language,
    String? region,
    MeasurementUnits? units,
    CoordinateFormat? coordinateFormat,
    TimeFormat? timeFormat,
    int? firstDayOfWeek,
    bool? enableAutoStart,
    bool? enableAutoSave,
    Duration? autoSaveInterval,
    bool? enableLocationServices,
    bool? enableBackgroundLocation,
    bool? showWelcomeScreen,
    bool? enableTutorials,
    bool? showTutorials,
    bool? enableTips,
    bool? confirmBeforeDelete,
    bool? checkForUpdates,
    bool? enableCrashReporting,
    bool? enableAnalytics,
  }) =>
      GeneralSettings(
        language: language ?? this.language,
        region: region ?? this.region,
        units: units ?? this.units,
        coordinateFormat: coordinateFormat ?? this.coordinateFormat,
        timeFormat: timeFormat ?? this.timeFormat,
        firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
        enableAutoStart: enableAutoStart ?? this.enableAutoStart,
        enableAutoSave: enableAutoSave ?? this.enableAutoSave,
        autoSaveInterval: autoSaveInterval ?? this.autoSaveInterval,
        enableLocationServices:
            enableLocationServices ?? this.enableLocationServices,
        enableBackgroundLocation:
            enableBackgroundLocation ?? this.enableBackgroundLocation,
        showWelcomeScreen: showWelcomeScreen ?? this.showWelcomeScreen,
        enableTutorials: enableTutorials ?? this.enableTutorials,
        showTutorials: showTutorials ?? this.showTutorials,
        enableTips: enableTips ?? this.enableTips,
        confirmBeforeDelete: confirmBeforeDelete ?? this.confirmBeforeDelete,
        checkForUpdates: checkForUpdates ?? this.checkForUpdates,
        enableCrashReporting: enableCrashReporting ?? this.enableCrashReporting,
        enableAnalytics: enableAnalytics ?? this.enableAnalytics,
      );

  Map<String, dynamic> toJson() => {
        'language': language,
        'region': region,
        'units': units.name,
        'coordinate_format': coordinateFormat.name,
        'time_format': timeFormat.name,
        'first_day_of_week': firstDayOfWeek,
        'enable_auto_start': enableAutoStart,
        'enable_auto_save': enableAutoSave,
        'auto_save_interval_minutes': autoSaveInterval.inMinutes,
        'enable_location_services': enableLocationServices,
        'enable_background_location': enableBackgroundLocation,
        'show_welcome_screen': showWelcomeScreen,
        'enable_tutorials': enableTutorials,
        'show_tutorials': showTutorials,
        'enable_tips': enableTips,
        'confirm_before_delete': confirmBeforeDelete,
        'check_for_updates': checkForUpdates,
        'enable_crash_reporting': enableCrashReporting,
        'enable_analytics': enableAnalytics,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeneralSettings &&
        other.language == language &&
        other.region == region &&
        other.units == units &&
        other.coordinateFormat == coordinateFormat &&
        other.timeFormat == timeFormat &&
        other.firstDayOfWeek == firstDayOfWeek &&
        other.enableAutoStart == enableAutoStart &&
        other.enableAutoSave == enableAutoSave &&
        other.autoSaveInterval == autoSaveInterval &&
        other.enableLocationServices == enableLocationServices &&
        other.enableBackgroundLocation == enableBackgroundLocation &&
        other.showWelcomeScreen == showWelcomeScreen &&
        other.enableTutorials == enableTutorials &&
        other.showTutorials == showTutorials &&
        other.enableTips == enableTips &&
        other.confirmBeforeDelete == confirmBeforeDelete &&
        other.checkForUpdates == checkForUpdates &&
        other.enableCrashReporting == enableCrashReporting &&
        other.enableAnalytics == enableAnalytics;
  }

  @override
  int get hashCode => Object.hash(
        language,
        region,
        units,
        coordinateFormat,
        timeFormat,
        firstDayOfWeek,
        enableAutoStart,
        enableAutoSave,
        autoSaveInterval,
        enableLocationServices,
        enableBackgroundLocation,
        showWelcomeScreen,
        enableTutorials,
        showTutorials,
        enableTips,
        confirmBeforeDelete,
        checkForUpdates,
        enableCrashReporting,
        enableAnalytics,
      );
}

/// Privacy and data protection settings
@immutable
class PrivacySettings {
  const PrivacySettings({
    this.enableDataCollection = false,
    this.enableLocationSharing = false,
    this.enableUsageStatistics = false,
    this.enableCrashReports = true,
    this.enablePersonalization = false,
    this.dataRetentionDays = 365,
    this.enableDataExport = true,
    this.enableDataDeletion = true,
    this.enableAnonymization = true,
    this.shareDataWithPartners = false,
    this.enableTargetedAds = false,
    this.enableCookies = false,
    this.enableTracking = false,
    this.enableFingerprinting = false,
    this.enableGeolocationTracking = false,
    this.enableBehaviorAnalytics = false,
  });

  factory PrivacySettings.fromJson(Map<String, dynamic> json) =>
      PrivacySettings(
        enableDataCollection: json['enable_data_collection'] as bool? ?? false,
        enableLocationSharing:
            json['enable_location_sharing'] as bool? ?? false,
        enableUsageStatistics:
            json['enable_usage_statistics'] as bool? ?? false,
        enableCrashReports: json['enable_crash_reports'] as bool? ?? true,
        enablePersonalization: json['enable_personalization'] as bool? ?? false,
        dataRetentionDays: json['data_retention_days'] as int? ?? 365,
        enableDataExport: json['enable_data_export'] as bool? ?? true,
        enableDataDeletion: json['enable_data_deletion'] as bool? ?? true,
        enableAnonymization: json['enable_anonymization'] as bool? ?? true,
        shareDataWithPartners:
            json['share_data_with_partners'] as bool? ?? false,
        enableTargetedAds: json['enable_targeted_ads'] as bool? ?? false,
        enableCookies: json['enable_cookies'] as bool? ?? false,
        enableTracking: json['enable_tracking'] as bool? ?? false,
        enableFingerprinting: json['enable_fingerprinting'] as bool? ?? false,
        enableGeolocationTracking:
            json['enable_geolocation_tracking'] as bool? ?? false,
        enableBehaviorAnalytics:
            json['enable_behavior_analytics'] as bool? ?? false,
      );

  final bool enableDataCollection;
  final bool enableLocationSharing;
  final bool enableUsageStatistics;
  final bool enableCrashReports;
  final bool enablePersonalization;
  final int dataRetentionDays;
  final bool enableDataExport;
  final bool enableDataDeletion;
  final bool enableAnonymization;
  final bool shareDataWithPartners;
  final bool enableTargetedAds;
  final bool enableCookies;
  final bool enableTracking;
  final bool enableFingerprinting;
  final bool enableGeolocationTracking;
  final bool enableBehaviorAnalytics;

  PrivacySettings copyWith({
    bool? enableDataCollection,
    bool? enableLocationSharing,
    bool? enableUsageStatistics,
    bool? enableCrashReports,
    bool? enablePersonalization,
    int? dataRetentionDays,
    bool? enableDataExport,
    bool? enableDataDeletion,
    bool? enableAnonymization,
    bool? shareDataWithPartners,
    bool? enableTargetedAds,
    bool? enableCookies,
    bool? enableTracking,
    bool? enableFingerprinting,
    bool? enableGeolocationTracking,
    bool? enableBehaviorAnalytics,
  }) =>
      PrivacySettings(
        enableDataCollection: enableDataCollection ?? this.enableDataCollection,
        enableLocationSharing:
            enableLocationSharing ?? this.enableLocationSharing,
        enableUsageStatistics:
            enableUsageStatistics ?? this.enableUsageStatistics,
        enableCrashReports: enableCrashReports ?? this.enableCrashReports,
        enablePersonalization:
            enablePersonalization ?? this.enablePersonalization,
        dataRetentionDays: dataRetentionDays ?? this.dataRetentionDays,
        enableDataExport: enableDataExport ?? this.enableDataExport,
        enableDataDeletion: enableDataDeletion ?? this.enableDataDeletion,
        enableAnonymization: enableAnonymization ?? this.enableAnonymization,
        shareDataWithPartners:
            shareDataWithPartners ?? this.shareDataWithPartners,
        enableTargetedAds: enableTargetedAds ?? this.enableTargetedAds,
        enableCookies: enableCookies ?? this.enableCookies,
        enableTracking: enableTracking ?? this.enableTracking,
        enableFingerprinting: enableFingerprinting ?? this.enableFingerprinting,
        enableGeolocationTracking:
            enableGeolocationTracking ?? this.enableGeolocationTracking,
        enableBehaviorAnalytics:
            enableBehaviorAnalytics ?? this.enableBehaviorAnalytics,
      );

  Map<String, dynamic> toJson() => {
        'enable_data_collection': enableDataCollection,
        'enable_location_sharing': enableLocationSharing,
        'enable_usage_statistics': enableUsageStatistics,
        'enable_crash_reports': enableCrashReports,
        'enable_personalization': enablePersonalization,
        'data_retention_days': dataRetentionDays,
        'enable_data_export': enableDataExport,
        'enable_data_deletion': enableDataDeletion,
        'enable_anonymization': enableAnonymization,
        'share_data_with_partners': shareDataWithPartners,
        'enable_targeted_ads': enableTargetedAds,
        'enable_cookies': enableCookies,
        'enable_tracking': enableTracking,
        'enable_fingerprinting': enableFingerprinting,
        'enable_geolocation_tracking': enableGeolocationTracking,
        'enable_behavior_analytics': enableBehaviorAnalytics,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrivacySettings &&
        other.enableDataCollection == enableDataCollection &&
        other.enableLocationSharing == enableLocationSharing &&
        other.enableUsageStatistics == enableUsageStatistics &&
        other.enableCrashReports == enableCrashReports &&
        other.enablePersonalization == enablePersonalization &&
        other.dataRetentionDays == dataRetentionDays &&
        other.enableDataExport == enableDataExport &&
        other.enableDataDeletion == enableDataDeletion &&
        other.enableAnonymization == enableAnonymization &&
        other.shareDataWithPartners == shareDataWithPartners &&
        other.enableTargetedAds == enableTargetedAds &&
        other.enableCookies == enableCookies &&
        other.enableTracking == enableTracking &&
        other.enableFingerprinting == enableFingerprinting &&
        other.enableGeolocationTracking == enableGeolocationTracking &&
        other.enableBehaviorAnalytics == enableBehaviorAnalytics;
  }

  @override
  int get hashCode => Object.hash(
        enableDataCollection,
        enableLocationSharing,
        enableUsageStatistics,
        enableCrashReports,
        enablePersonalization,
        dataRetentionDays,
        enableDataExport,
        enableDataDeletion,
        enableAnonymization,
        shareDataWithPartners,
        enableTargetedAds,
        enableCookies,
        enableTracking,
        enableFingerprinting,
        enableGeolocationTracking,
        enableBehaviorAnalytics,
      );
}

/// Comprehensive notification settings
@immutable
class NotificationSettings {
  const NotificationSettings({
    this.enableNotifications = true,
    this.enablePushNotifications = true,
    this.enableInAppNotifications = true,
    this.enableEmailNotifications = false,
    this.enableSmsNotifications = false,
    this.notificationSound = true,
    this.vibrationPattern = VibrationPattern.standard,
    this.enableQuietHours = false,
    this.quietHoursStart = const TimeOfDay(hour: 22, minute: 0),
    this.quietHoursEnd = const TimeOfDay(hour: 7, minute: 0),
    this.enableDoNotDisturb = false,
    this.priorityNotificationsOnly = false,
    this.tracking = const TrackingNotificationSettings(),
    this.gps = const GpsNotificationSettings(),
    this.system = const SystemNotificationSettings(),
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        enableNotifications: json['enable_notifications'] as bool? ?? true,
        enablePushNotifications:
            json['enable_push_notifications'] as bool? ?? true,
        enableInAppNotifications:
            json['enable_in_app_notifications'] as bool? ?? true,
        enableEmailNotifications:
            json['enable_email_notifications'] as bool? ?? false,
        enableSmsNotifications:
            json['enable_sms_notifications'] as bool? ?? false,
        notificationSound: json['notification_sound'] as bool? ?? true,
        vibrationPattern: VibrationPattern.values.firstWhere(
          (e) => e.name == json['vibration_pattern'],
          orElse: () => VibrationPattern.standard,
        ),
        enableQuietHours: json['enable_quiet_hours'] as bool? ?? false,
        quietHoursStart: _timeOfDayFromJson(json['quiet_hours_start']) ??
            const TimeOfDay(hour: 22, minute: 0),
        quietHoursEnd: _timeOfDayFromJson(json['quiet_hours_end']) ??
            const TimeOfDay(hour: 7, minute: 0),
        enableDoNotDisturb: json['enable_do_not_disturb'] as bool? ?? false,
        priorityNotificationsOnly:
            json['priority_notifications_only'] as bool? ?? false,
        tracking: TrackingNotificationSettings.fromJson(
            json['tracking'] as Map<String, dynamic>? ?? {}),
        gps: GpsNotificationSettings.fromJson(
            json['gps'] as Map<String, dynamic>? ?? {}),
        system: SystemNotificationSettings.fromJson(
            json['system'] as Map<String, dynamic>? ?? {}),
      );

  static TimeOfDay? _timeOfDayFromJson(Object? json) {
    if (json is Map<String, dynamic>) {
      return TimeOfDay(
        hour: json['hour'] as int? ?? 0,
        minute: json['minute'] as int? ?? 0,
      );
    }
    return null;
  }

  static Map<String, dynamic> _timeOfDayToJson(TimeOfDay time) => {
        'hour': time.hour,
        'minute': time.minute,
      };

  final bool enableNotifications;
  final bool enablePushNotifications;
  final bool enableInAppNotifications;
  final bool enableEmailNotifications;
  final bool enableSmsNotifications;
  final bool notificationSound;
  final VibrationPattern vibrationPattern;
  final bool enableQuietHours;
  final TimeOfDay quietHoursStart;
  final TimeOfDay quietHoursEnd;
  final bool enableDoNotDisturb;
  final bool priorityNotificationsOnly;
  final TrackingNotificationSettings tracking;
  final GpsNotificationSettings gps;
  final SystemNotificationSettings system;

  NotificationSettings copyWith({
    bool? enableNotifications,
    bool? enablePushNotifications,
    bool? enableInAppNotifications,
    bool? enableEmailNotifications,
    bool? enableSmsNotifications,
    bool? notificationSound,
    VibrationPattern? vibrationPattern,
    bool? enableQuietHours,
    TimeOfDay? quietHoursStart,
    TimeOfDay? quietHoursEnd,
    bool? enableDoNotDisturb,
    bool? priorityNotificationsOnly,
    TrackingNotificationSettings? tracking,
    GpsNotificationSettings? gps,
    SystemNotificationSettings? system,
  }) =>
      NotificationSettings(
        enableNotifications: enableNotifications ?? this.enableNotifications,
        enablePushNotifications:
            enablePushNotifications ?? this.enablePushNotifications,
        enableInAppNotifications:
            enableInAppNotifications ?? this.enableInAppNotifications,
        enableEmailNotifications:
            enableEmailNotifications ?? this.enableEmailNotifications,
        enableSmsNotifications:
            enableSmsNotifications ?? this.enableSmsNotifications,
        notificationSound: notificationSound ?? this.notificationSound,
        vibrationPattern: vibrationPattern ?? this.vibrationPattern,
        enableQuietHours: enableQuietHours ?? this.enableQuietHours,
        quietHoursStart: quietHoursStart ?? this.quietHoursStart,
        quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
        enableDoNotDisturb: enableDoNotDisturb ?? this.enableDoNotDisturb,
        priorityNotificationsOnly:
            priorityNotificationsOnly ?? this.priorityNotificationsOnly,
        tracking: tracking ?? this.tracking,
        gps: gps ?? this.gps,
        system: system ?? this.system,
      );

  Map<String, dynamic> toJson() => {
        'enable_notifications': enableNotifications,
        'enable_push_notifications': enablePushNotifications,
        'enable_in_app_notifications': enableInAppNotifications,
        'enable_email_notifications': enableEmailNotifications,
        'enable_sms_notifications': enableSmsNotifications,
        'notification_sound': notificationSound,
        'vibration_pattern': vibrationPattern.name,
        'enable_quiet_hours': enableQuietHours,
        'quiet_hours_start': _timeOfDayToJson(quietHoursStart),
        'quiet_hours_end': _timeOfDayToJson(quietHoursEnd),
        'enable_do_not_disturb': enableDoNotDisturb,
        'priority_notifications_only': priorityNotificationsOnly,
        'tracking': tracking.toJson(),
        'gps': gps.toJson(),
        'system': system.toJson(),
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationSettings &&
        other.enableNotifications == enableNotifications &&
        other.enablePushNotifications == enablePushNotifications &&
        other.enableInAppNotifications == enableInAppNotifications &&
        other.enableEmailNotifications == enableEmailNotifications &&
        other.enableSmsNotifications == enableSmsNotifications &&
        other.notificationSound == notificationSound &&
        other.vibrationPattern == vibrationPattern &&
        other.enableQuietHours == enableQuietHours &&
        other.quietHoursStart == quietHoursStart &&
        other.quietHoursEnd == quietHoursEnd &&
        other.enableDoNotDisturb == enableDoNotDisturb &&
        other.priorityNotificationsOnly == priorityNotificationsOnly &&
        other.tracking == tracking &&
        other.gps == gps &&
        other.system == system;
  }

  @override
  int get hashCode => Object.hash(
        enableNotifications,
        enablePushNotifications,
        enableInAppNotifications,
        enableEmailNotifications,
        enableSmsNotifications,
        notificationSound,
        vibrationPattern,
        enableQuietHours,
        quietHoursStart,
        quietHoursEnd,
        enableDoNotDisturb,
        priorityNotificationsOnly,
        tracking,
        gps,
        system,
      );
}

/// Tracking and GPS-related settings
@immutable
class TrackingSettings {
  const TrackingSettings({
    this.enableTracking = true,
    this.enableBackgroundTracking = true,
    this.gpsMode = GpsMode.balanced,
    this.minDistanceFilter = 5.0, // meters (about 16 feet)
    this.recordElevation = true,
    this.recordSpeed = true,
    this.recordBearing = true,
    this.photoQuality = PhotoQuality.max,
  });

  factory TrackingSettings.fromJson(Map<String, dynamic> json) =>
      TrackingSettings(
        enableTracking: json['enable_tracking'] as bool? ?? true,
        enableBackgroundTracking:
            json['enable_background_tracking'] as bool? ?? true,
        gpsMode: GpsMode.values.firstWhere(
          (e) => e.name == json['gps_mode'],
          orElse: () => GpsMode.balanced,
        ),
        minDistanceFilter:
            (json['min_distance_filter'] as num?)?.toDouble() ?? 5.0,
        recordElevation: json['record_elevation'] as bool? ?? true,
        recordSpeed: json['record_speed'] as bool? ?? true,
        recordBearing: json['record_bearing'] as bool? ?? true,
        photoQuality: PhotoQuality.values.firstWhere(
          (e) => e.name == json['photo_quality'],
          orElse: () => PhotoQuality.max,
        ),
      );

  final bool enableTracking;
  final bool enableBackgroundTracking;
  final GpsMode gpsMode;
  final double minDistanceFilter;
  final bool recordElevation;
  final bool recordSpeed;
  final bool recordBearing;
  final PhotoQuality photoQuality;

  TrackingSettings copyWith({
    bool? enableTracking,
    bool? enableBackgroundTracking,
    GpsMode? gpsMode,
    double? minDistanceFilter,
    bool? recordElevation,
    bool? recordSpeed,
    bool? recordBearing,
    PhotoQuality? photoQuality,
  }) =>
      TrackingSettings(
        enableTracking: enableTracking ?? this.enableTracking,
        enableBackgroundTracking:
            enableBackgroundTracking ?? this.enableBackgroundTracking,
        gpsMode: gpsMode ?? this.gpsMode,
        minDistanceFilter: minDistanceFilter ?? this.minDistanceFilter,
        recordElevation: recordElevation ?? this.recordElevation,
        recordSpeed: recordSpeed ?? this.recordSpeed,
        recordBearing: recordBearing ?? this.recordBearing,
        photoQuality: photoQuality ?? this.photoQuality,
      );

  Map<String, dynamic> toJson() => {
        'enable_tracking': enableTracking,
        'enable_background_tracking': enableBackgroundTracking,
        'gps_mode': gpsMode.name,
        'min_distance_filter': minDistanceFilter,
        'record_elevation': recordElevation,
        'record_speed': recordSpeed,
        'record_bearing': recordBearing,
        'photo_quality': photoQuality.name,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrackingSettings &&
        other.enableTracking == enableTracking &&
        other.enableBackgroundTracking == enableBackgroundTracking &&
        other.gpsMode == gpsMode &&
        other.minDistanceFilter == minDistanceFilter &&
        other.recordElevation == recordElevation &&
        other.recordSpeed == recordSpeed &&
        other.recordBearing == recordBearing &&
        other.photoQuality == photoQuality;
  }

  @override
  int get hashCode => Object.hash(
        enableTracking,
        enableBackgroundTracking,
        gpsMode,
        minDistanceFilter,
        recordElevation,
        recordSpeed,
        recordBearing,
        photoQuality,
      );
}

