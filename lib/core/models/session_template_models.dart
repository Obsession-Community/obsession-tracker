import 'package:flutter/foundation.dart';

/// Template for creating pre-configured tracking sessions
@immutable
class SessionTemplate {
  const SessionTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.activityType,
    required this.settings,
    this.icon,
    this.estimatedDuration,
    this.estimatedDistance,
    this.difficultyLevel = DifficultyLevel.moderate,
    this.tags = const [],
    this.isBuiltIn = false,
    this.isCustom = false,
    this.usageCount = 0,
    this.lastUsed,
    this.createdAt,
    this.updatedAt,
  });

  /// Create from database map
  factory SessionTemplate.fromMap(Map<String, dynamic> map) => SessionTemplate(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String,
        category: TemplateCategory.values.firstWhere(
          (e) => e.name == map['category'],
          orElse: () => TemplateCategory.general,
        ),
        activityType: ActivityType.values.firstWhere(
          (e) => e.name == map['activity_type'],
          orElse: () => ActivityType.hiking,
        ),
        settings: SessionTemplateSettings.fromMap(
            map['settings'] as Map<String, dynamic>),
        icon: map['icon'] as String?,
        estimatedDuration: map['estimated_duration'] != null
            ? Duration(milliseconds: map['estimated_duration'] as int)
            : null,
        estimatedDistance: map['estimated_distance'] as double?,
        difficultyLevel: DifficultyLevel.values.firstWhere(
          (e) => e.name == map['difficulty_level'],
          orElse: () => DifficultyLevel.moderate,
        ),
        tags: (map['tags'] as String?)?.split(',') ?? [],
        isBuiltIn: (map['is_built_in'] as int) == 1,
        isCustom: (map['is_custom'] as int) == 1,
        usageCount: map['usage_count'] as int,
        lastUsed: map['last_used'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['last_used'] as int)
            : null,
        createdAt: map['created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
            : null,
      );

  /// Unique identifier for the template
  final String id;

  /// Display name for the template
  final String name;

  /// Detailed description of the template
  final String description;

  /// Category this template belongs to
  final TemplateCategory category;

  /// Type of activity this template is designed for
  final ActivityType activityType;

  /// Pre-configured session settings
  final SessionTemplateSettings settings;

  /// Icon identifier for the template
  final String? icon;

  /// Estimated duration for sessions using this template
  final Duration? estimatedDuration;

  /// Estimated distance for sessions using this template
  final double? estimatedDistance;

  /// Difficulty level of activities using this template
  final DifficultyLevel difficultyLevel;

  /// Tags for categorization and search
  final List<String> tags;

  /// Whether this is a built-in template
  final bool isBuiltIn;

  /// Whether this is a user-created custom template
  final bool isCustom;

  /// Number of times this template has been used
  final int usageCount;

  /// When this template was last used
  final DateTime? lastUsed;

  /// When this template was created
  final DateTime? createdAt;

  /// When this template was last updated
  final DateTime? updatedAt;

  /// Create a copy with updated values
  SessionTemplate copyWith({
    String? id,
    String? name,
    String? description,
    TemplateCategory? category,
    ActivityType? activityType,
    SessionTemplateSettings? settings,
    String? icon,
    Duration? estimatedDuration,
    double? estimatedDistance,
    DifficultyLevel? difficultyLevel,
    List<String>? tags,
    bool? isBuiltIn,
    bool? isCustom,
    int? usageCount,
    DateTime? lastUsed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      SessionTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        category: category ?? this.category,
        activityType: activityType ?? this.activityType,
        settings: settings ?? this.settings,
        icon: icon ?? this.icon,
        estimatedDuration: estimatedDuration ?? this.estimatedDuration,
        estimatedDistance: estimatedDistance ?? this.estimatedDistance,
        difficultyLevel: difficultyLevel ?? this.difficultyLevel,
        tags: tags ?? this.tags,
        isBuiltIn: isBuiltIn ?? this.isBuiltIn,
        isCustom: isCustom ?? this.isCustom,
        usageCount: usageCount ?? this.usageCount,
        lastUsed: lastUsed ?? this.lastUsed,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Convert to map for database storage
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category.name,
        'activity_type': activityType.name,
        'settings': settings.toMap(),
        'icon': icon,
        'estimated_duration': estimatedDuration?.inMilliseconds,
        'estimated_distance': estimatedDistance,
        'difficulty_level': difficultyLevel.name,
        'tags': tags.join(','),
        'is_built_in': isBuiltIn ? 1 : 0,
        'is_custom': isCustom ? 1 : 0,
        'usage_count': usageCount,
        'last_used': lastUsed?.millisecondsSinceEpoch,
        'created_at': createdAt?.millisecondsSinceEpoch,
        'updated_at': updatedAt?.millisecondsSinceEpoch,
      };
}

/// Categories for organizing session templates
enum TemplateCategory {
  general,
  hiking,
  running,
  cycling,
  walking,
  climbing,
  skiing,
  water,
  urban,
  nature,
  fitness,
  adventure,
  photography,
  research,
  custom,
}

/// Types of activities
enum ActivityType {
  hiking,
  running,
  walking,
  cycling,
  climbing,
  skiing,
  snowboarding,
  kayaking,
  swimming,
  photography,
  birdwatching,
  geocaching,
  research,
  fitness,
  commuting,
  touring,
  racing,
  training,
  leisure,
  custom,
}

/// Difficulty levels for activities
enum DifficultyLevel {
  beginner,
  easy,
  moderate,
  hard,
  expert,
  extreme,
}

/// Settings for a session template
@immutable
class SessionTemplateSettings {
  const SessionTemplateSettings({
    required this.accuracyThreshold,
    required this.recordingInterval,
    required this.minimumSpeed,
    required this.recordAltitude,
    required this.recordSpeed,
    required this.recordHeading,
    this.autoStart = false,
    this.autoPause = false,
    this.autoStop = false,
    this.pauseThreshold = 0.5,
    this.stopThreshold = const Duration(minutes: 5),
    this.batteryOptimization = BatteryOptimization.balanced,
    this.gpsMode = GpsMode.highAccuracy,
    this.waypointSettings,
    this.notificationSettings,
    this.exportSettings,
  });

  /// Create from map
  factory SessionTemplateSettings.fromMap(Map<String, dynamic> map) =>
      SessionTemplateSettings(
        accuracyThreshold: map['accuracy_threshold'] as double,
        recordingInterval: map['recording_interval'] as int,
        minimumSpeed: map['minimum_speed'] as double,
        recordAltitude: map['record_altitude'] as bool,
        recordSpeed: map['record_speed'] as bool,
        recordHeading: map['record_heading'] as bool,
        autoStart: map['auto_start'] as bool? ?? false,
        autoPause: map['auto_pause'] as bool? ?? false,
        autoStop: map['auto_stop'] as bool? ?? false,
        pauseThreshold: map['pause_threshold'] as double? ?? 0.5,
        stopThreshold:
            Duration(milliseconds: map['stop_threshold'] as int? ?? 300000),
        batteryOptimization: BatteryOptimization.values.firstWhere(
          (e) => e.name == map['battery_optimization'],
          orElse: () => BatteryOptimization.balanced,
        ),
        gpsMode: GpsMode.values.firstWhere(
          (e) => e.name == map['gps_mode'],
          orElse: () => GpsMode.highAccuracy,
        ),
        waypointSettings: map['waypoint_settings'] != null
            ? WaypointTemplateSettings.fromMap(
                map['waypoint_settings'] as Map<String, dynamic>)
            : null,
        notificationSettings: map['notification_settings'] != null
            ? NotificationTemplateSettings.fromMap(
                map['notification_settings'] as Map<String, dynamic>)
            : null,
        exportSettings: map['export_settings'] != null
            ? ExportTemplateSettings.fromMap(
                map['export_settings'] as Map<String, dynamic>)
            : null,
      );

  /// GPS accuracy threshold for recording breadcrumbs (meters)
  final double accuracyThreshold;

  /// Recording interval in seconds
  final int recordingInterval;

  /// Minimum speed to record breadcrumb (m/s)
  final double minimumSpeed;

  /// Whether to record altitude data
  final bool recordAltitude;

  /// Whether to record speed data
  final bool recordSpeed;

  /// Whether to record heading data
  final bool recordHeading;

  /// Whether to automatically start tracking
  final bool autoStart;

  /// Whether to automatically pause when stopped
  final bool autoPause;

  /// Whether to automatically stop after inactivity
  final bool autoStop;

  /// Speed threshold for auto-pause (m/s)
  final double pauseThreshold;

  /// Time threshold for auto-stop
  final Duration stopThreshold;

  /// Battery optimization level
  final BatteryOptimization batteryOptimization;

  /// GPS mode for tracking
  final GpsMode gpsMode;

  /// Waypoint-specific settings
  final WaypointTemplateSettings? waypointSettings;

  /// Notification settings
  final NotificationTemplateSettings? notificationSettings;

  /// Export settings
  final ExportTemplateSettings? exportSettings;

  /// Convert to map for storage
  Map<String, dynamic> toMap() => {
        'accuracy_threshold': accuracyThreshold,
        'recording_interval': recordingInterval,
        'minimum_speed': minimumSpeed,
        'record_altitude': recordAltitude,
        'record_speed': recordSpeed,
        'record_heading': recordHeading,
        'auto_start': autoStart,
        'auto_pause': autoPause,
        'auto_stop': autoStop,
        'pause_threshold': pauseThreshold,
        'stop_threshold': stopThreshold.inMilliseconds,
        'battery_optimization': batteryOptimization.name,
        'gps_mode': gpsMode.name,
        'waypoint_settings': waypointSettings?.toMap(),
        'notification_settings': notificationSettings?.toMap(),
        'export_settings': exportSettings?.toMap(),
      };
}

/// Battery optimization levels
enum BatteryOptimization {
  maximum,
  balanced,
  performance,
}

/// GPS modes
enum GpsMode {
  lowPower,
  balanced,
  highAccuracy,
}

/// Waypoint settings for templates
@immutable
class WaypointTemplateSettings {
  const WaypointTemplateSettings({
    this.autoCreateWaypoints = false,
    this.waypointInterval = const Duration(minutes: 10),
    this.autoPhotoWaypoints = false,
    this.photoInterval = const Duration(minutes: 5),
    this.defaultWaypointType,
    this.enableQuickWaypoints = true,
    this.quickWaypointTypes = const [],
  });

  factory WaypointTemplateSettings.fromMap(Map<String, dynamic> map) =>
      WaypointTemplateSettings(
        autoCreateWaypoints: map['auto_create_waypoints'] as bool? ?? false,
        waypointInterval:
            Duration(milliseconds: map['waypoint_interval'] as int? ?? 600000),
        autoPhotoWaypoints: map['auto_photo_waypoints'] as bool? ?? false,
        photoInterval:
            Duration(milliseconds: map['photo_interval'] as int? ?? 300000),
        defaultWaypointType: map['default_waypoint_type'] as String?,
        enableQuickWaypoints: map['enable_quick_waypoints'] as bool? ?? true,
        quickWaypointTypes:
            List<String>.from(map['quick_waypoint_types'] as List? ?? []),
      );

  /// Whether to automatically create waypoints
  final bool autoCreateWaypoints;

  /// Interval for automatic waypoint creation
  final Duration waypointInterval;

  /// Whether to automatically create photo waypoints
  final bool autoPhotoWaypoints;

  /// Interval for automatic photo waypoints
  final Duration photoInterval;

  /// Default waypoint type for quick creation
  final String? defaultWaypointType;

  /// Whether to enable quick waypoint creation
  final bool enableQuickWaypoints;

  /// Quick waypoint types for easy access
  final List<String> quickWaypointTypes;

  Map<String, dynamic> toMap() => {
        'auto_create_waypoints': autoCreateWaypoints,
        'waypoint_interval': waypointInterval.inMilliseconds,
        'auto_photo_waypoints': autoPhotoWaypoints,
        'photo_interval': photoInterval.inMilliseconds,
        'default_waypoint_type': defaultWaypointType,
        'enable_quick_waypoints': enableQuickWaypoints,
        'quick_waypoint_types': quickWaypointTypes,
      };
}

/// Notification settings for templates
@immutable
class NotificationTemplateSettings {
  const NotificationTemplateSettings({
    this.enableDistanceNotifications = false,
    this.distanceInterval = 1000,
    this.enableTimeNotifications = false,
    this.timeInterval = const Duration(minutes: 15),
    this.enableSpeedAlerts = false,
    this.speedAlertThreshold = 0,
    this.enableAccuracyAlerts = false,
    this.accuracyAlertThreshold = 20,
    this.enableBatteryAlerts = true,
    this.batteryAlertThreshold = 20,
  });

  factory NotificationTemplateSettings.fromMap(Map<String, dynamic> map) =>
      NotificationTemplateSettings(
        enableDistanceNotifications:
            map['enable_distance_notifications'] as bool? ?? false,
        distanceInterval: map['distance_interval'] as double? ?? 1000,
        enableTimeNotifications:
            map['enable_time_notifications'] as bool? ?? false,
        timeInterval:
            Duration(milliseconds: map['time_interval'] as int? ?? 900000),
        enableSpeedAlerts: map['enable_speed_alerts'] as bool? ?? false,
        speedAlertThreshold: map['speed_alert_threshold'] as double? ?? 0,
        enableAccuracyAlerts: map['enable_accuracy_alerts'] as bool? ?? false,
        accuracyAlertThreshold:
            map['accuracy_alert_threshold'] as double? ?? 20,
        enableBatteryAlerts: map['enable_battery_alerts'] as bool? ?? true,
        batteryAlertThreshold: map['battery_alert_threshold'] as int? ?? 20,
      );

  /// Whether to send distance-based notifications
  final bool enableDistanceNotifications;

  /// Distance interval for notifications (meters)
  final double distanceInterval;

  /// Whether to send time-based notifications
  final bool enableTimeNotifications;

  /// Time interval for notifications
  final Duration timeInterval;

  /// Whether to send speed alerts
  final bool enableSpeedAlerts;

  /// Speed threshold for alerts (m/s)
  final double speedAlertThreshold;

  /// Whether to send GPS accuracy alerts
  final bool enableAccuracyAlerts;

  /// Accuracy threshold for alerts (meters)
  final double accuracyAlertThreshold;

  /// Whether to send battery alerts
  final bool enableBatteryAlerts;

  /// Battery level threshold for alerts (percentage)
  final int batteryAlertThreshold;

  Map<String, dynamic> toMap() => {
        'enable_distance_notifications': enableDistanceNotifications,
        'distance_interval': distanceInterval,
        'enable_time_notifications': enableTimeNotifications,
        'time_interval': timeInterval.inMilliseconds,
        'enable_speed_alerts': enableSpeedAlerts,
        'speed_alert_threshold': speedAlertThreshold,
        'enable_accuracy_alerts': enableAccuracyAlerts,
        'accuracy_alert_threshold': accuracyAlertThreshold,
        'enable_battery_alerts': enableBatteryAlerts,
        'battery_alert_threshold': batteryAlertThreshold,
      };
}

/// Export settings for templates
@immutable
class ExportTemplateSettings {
  const ExportTemplateSettings({
    this.autoExport = false,
    this.exportFormats = const [],
    this.exportDestination = ExportDestination.local,
    this.includeWaypoints = true,
    this.includePhotos = true,
    this.includeStatistics = true,
    this.compressionLevel = CompressionLevel.medium,
  });

  factory ExportTemplateSettings.fromMap(Map<String, dynamic> map) =>
      ExportTemplateSettings(
        autoExport: map['auto_export'] as bool? ?? false,
        exportFormats: (map['export_formats'] as List?)
                ?.map((f) => ExportFormat.values.firstWhere((e) => e.name == f,
                    orElse: () => ExportFormat.gpx))
                .toList() ??
            [],
        exportDestination: ExportDestination.values.firstWhere(
          (e) => e.name == map['export_destination'],
          orElse: () => ExportDestination.local,
        ),
        includeWaypoints: map['include_waypoints'] as bool? ?? true,
        includePhotos: map['include_photos'] as bool? ?? true,
        includeStatistics: map['include_statistics'] as bool? ?? true,
        compressionLevel: CompressionLevel.values.firstWhere(
          (e) => e.name == map['compression_level'],
          orElse: () => CompressionLevel.medium,
        ),
      );

  /// Whether to automatically export sessions
  final bool autoExport;

  /// Export formats to use
  final List<ExportFormat> exportFormats;

  /// Where to export the data
  final ExportDestination exportDestination;

  /// Whether to include waypoints in export
  final bool includeWaypoints;

  /// Whether to include photos in export
  final bool includePhotos;

  /// Whether to include statistics in export
  final bool includeStatistics;

  /// Compression level for exports
  final CompressionLevel compressionLevel;

  Map<String, dynamic> toMap() => {
        'auto_export': autoExport,
        'export_formats': exportFormats.map((f) => f.name).toList(),
        'export_destination': exportDestination.name,
        'include_waypoints': includeWaypoints,
        'include_photos': includePhotos,
        'include_statistics': includeStatistics,
        'compression_level': compressionLevel.name,
      };
}

/// Export formats
enum ExportFormat {
  gpx,
  kml,
  json,
  csv,
  tcx,
}

/// Export destinations
enum ExportDestination {
  local,
  cloud,
  email,
  share,
}

/// Compression levels
enum CompressionLevel {
  none,
  low,
  medium,
  high,
}

/// Quick start configuration
@immutable
class QuickStartConfig {
  const QuickStartConfig({
    required this.templateId,
    required this.name,
    required this.description,
    this.icon,
    this.shortcut,
    this.autoStart = false,
    this.confirmBeforeStart = true,
    this.customSettings,
    this.isEnabled = true,
    this.sortOrder = 0,
  });

  /// ID of the template to use
  final String templateId;

  /// Display name for the quick start option
  final String name;

  /// Description of what this quick start does
  final String description;

  /// Icon for the quick start button
  final String? icon;

  /// Keyboard shortcut (if any)
  final String? shortcut;

  /// Whether to automatically start tracking
  final bool autoStart;

  /// Whether to show confirmation before starting
  final bool confirmBeforeStart;

  /// Custom settings that override template settings
  final Map<String, dynamic>? customSettings;

  /// Whether this quick start option is enabled
  final bool isEnabled;

  /// Sort order for display
  final int sortOrder;
}

/// Result of creating a session from a template
@immutable
class SessionCreationResult {
  const SessionCreationResult({
    required this.success,
    this.sessionId,
    this.errors = const [],
    this.warnings = const [],
  });

  /// Whether the session was created successfully
  final bool success;

  /// ID of the created session (if successful)
  final String? sessionId;

  /// Any errors that occurred
  final List<String> errors;

  /// Any warnings generated
  final List<String> warnings;
}

/// Template usage statistics
@immutable
class TemplateUsageStats {
  const TemplateUsageStats({
    required this.templateId,
    required this.totalUsage,
    required this.lastUsed,
    required this.averageSessionDuration,
    required this.averageSessionDistance,
    required this.successRate,
    required this.userRating,
  });

  final String templateId;
  final int totalUsage;
  final DateTime? lastUsed;
  final Duration averageSessionDuration;
  final double averageSessionDistance;
  final double successRate; // Percentage of completed sessions
  final double userRating; // 0-5 stars
}
