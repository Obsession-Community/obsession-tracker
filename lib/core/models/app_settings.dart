import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/security_models.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';

/// Comprehensive application settings model
@immutable
class AppSettings {
  const AppSettings({
    this.general = const GeneralSettings(),
    this.theme = const ThemeSettings(),
    this.privacy = const PrivacySettings(),
    this.notifications = const NotificationSettings(),
    this.tracking = const TrackingSettings(),
    this.map = const MapSettings(),
    this.storage = const StorageSettings(),
    this.export = const ExportSettings(),
    this.accessibility = const AccessibilitySettings(),
    this.advanced = const AdvancedSettings(),
    this.security = const AppSecuritySettings(),
    this.dataEncryption = const DataEncryptionSettings(),
    this.privacyTools = const PrivacyToolsSettings(),
    this.secureBackup = const SecureBackupSettings(),
  });

  /// Create default settings
  factory AppSettings.defaultSettings() => const AppSettings();

  /// Create from JSON
  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        general: GeneralSettings.fromJson(
            json['general'] as Map<String, dynamic>? ?? {}),
        theme: ThemeSettings.fromJson(
            json['theme'] as Map<String, dynamic>? ?? {}),
        privacy: PrivacySettings.fromJson(
            json['privacy'] as Map<String, dynamic>? ?? {}),
        notifications: NotificationSettings.fromJson(
            json['notifications'] as Map<String, dynamic>? ?? {}),
        tracking: TrackingSettings.fromJson(
            json['tracking'] as Map<String, dynamic>? ?? {}),
        map: MapSettings.fromJson(json['map'] as Map<String, dynamic>? ?? {}),
        storage: StorageSettings.fromJson(
            json['storage'] as Map<String, dynamic>? ?? {}),
        export: ExportSettings.fromJson(
            json['export'] as Map<String, dynamic>? ?? {}),
        accessibility: AccessibilitySettings.fromJson(
            json['accessibility'] as Map<String, dynamic>? ?? {}),
        advanced: AdvancedSettings.fromJson(
            json['advanced'] as Map<String, dynamic>? ?? {}),
      );

  final GeneralSettings general;
  final ThemeSettings theme;
  final PrivacySettings privacy;
  final NotificationSettings notifications;
  final TrackingSettings tracking;
  final MapSettings map;
  final StorageSettings storage;
  final ExportSettings export;
  final AccessibilitySettings accessibility;
  final AdvancedSettings advanced;
  final AppSecuritySettings security;
  final DataEncryptionSettings dataEncryption;
  final PrivacyToolsSettings privacyTools;
  final SecureBackupSettings secureBackup;

  AppSettings copyWith({
    GeneralSettings? general,
    ThemeSettings? theme,
    PrivacySettings? privacy,
    NotificationSettings? notifications,
    TrackingSettings? tracking,
    MapSettings? map,
    StorageSettings? storage,
    ExportSettings? export,
    AccessibilitySettings? accessibility,
    AdvancedSettings? advanced,
    AppSecuritySettings? security,
    DataEncryptionSettings? dataEncryption,
    PrivacyToolsSettings? privacyTools,
    SecureBackupSettings? secureBackup,
  }) =>
      AppSettings(
        general: general ?? this.general,
        theme: theme ?? this.theme,
        privacy: privacy ?? this.privacy,
        notifications: notifications ?? this.notifications,
        tracking: tracking ?? this.tracking,
        map: map ?? this.map,
        storage: storage ?? this.storage,
        export: export ?? this.export,
        accessibility: accessibility ?? this.accessibility,
        advanced: advanced ?? this.advanced,
        security: security ?? this.security,
        dataEncryption: dataEncryption ?? this.dataEncryption,
        privacyTools: privacyTools ?? this.privacyTools,
        secureBackup: secureBackup ?? this.secureBackup,
      );

  Map<String, dynamic> toJson() => {
        'general': general.toJson(),
        'theme': theme.toJson(),
        'privacy': privacy.toJson(),
        'notifications': notifications.toJson(),
        'tracking': tracking.toJson(),
        'map': map.toJson(),
        'storage': storage.toJson(),
        'export': export.toJson(),
        'accessibility': accessibility.toJson(),
        'advanced': advanced.toJson(),
        'security': security.toJson(),
        'data_encryption': dataEncryption.toJson(),
        'privacy_tools': privacyTools.toJson(),
        'secure_backup': secureBackup.toJson(),
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.general == general &&
        other.theme == theme &&
        other.privacy == privacy &&
        other.notifications == notifications &&
        other.tracking == tracking &&
        other.map == map &&
        other.storage == storage &&
        other.export == export &&
        other.accessibility == accessibility &&
        other.advanced == advanced &&
        other.security == security &&
        other.dataEncryption == dataEncryption &&
        other.privacyTools == privacyTools &&
        other.secureBackup == secureBackup;
  }

  @override
  int get hashCode => Object.hash(
        general,
        theme,
        privacy,
        notifications,
        tracking,
        map,
        storage,
        export,
        accessibility,
        advanced,
        security,
        dataEncryption,
        privacyTools,
        secureBackup,
      );

  @override
  String toString() => 'AppSettings('
      'general: $general, '
      'theme: $theme, '
      'privacy: $privacy, '
      'notifications: $notifications, '
      'tracking: $tracking, '
      'map: $map, '
      'storage: $storage, '
      'export: $export, '
      'accessibility: $accessibility, '
      'advanced: $advanced, '
      'security: $security, '
      'dataEncryption: $dataEncryption, '
      'privacyTools: $privacyTools, '
      'secureBackup: $secureBackup'
      ')';
}

/// Theme-related settings
@immutable
class ThemeSettings {
  const ThemeSettings({
    this.themeMode = ThemeMode.system,
    this.useMaterial3 = true,
    this.fontFamily = 'System',
    this.fontSize = FontSize.medium,
    this.enableAnimations = true,
    this.reducedMotion = false,
    this.highContrast = false,
    this.colorBlindnessSupport = ColorBlindnessType.none,
    this.customColorScheme,
  });

  factory ThemeSettings.fromJson(Map<String, dynamic> json) => ThemeSettings(
        themeMode: ThemeMode.values.firstWhere(
          (e) => e.name == json['theme_mode'],
          orElse: () => ThemeMode.system,
        ),
        useMaterial3: json['use_material3'] as bool? ?? true,
        fontFamily: json['font_family'] as String? ?? 'System',
        fontSize: FontSize.values.firstWhere(
          (e) => e.name == json['font_size'],
          orElse: () => FontSize.medium,
        ),
        enableAnimations: json['enable_animations'] as bool? ?? true,
        reducedMotion: json['reduced_motion'] as bool? ?? false,
        highContrast: json['high_contrast'] as bool? ?? false,
        colorBlindnessSupport: ColorBlindnessType.values.firstWhere(
          (e) => e.name == json['color_blindness_support'],
          orElse: () => ColorBlindnessType.none,
        ),
        customColorScheme: json['custom_color_scheme'] != null
            ? CustomColorScheme.fromJson(
                json['custom_color_scheme'] as Map<String, dynamic>)
            : null,
      );

  final ThemeMode themeMode;
  final bool useMaterial3;
  final String fontFamily;
  final FontSize fontSize;
  final bool enableAnimations;
  final bool reducedMotion;
  final bool highContrast;
  final ColorBlindnessType colorBlindnessSupport;
  final CustomColorScheme? customColorScheme;

  ThemeSettings copyWith({
    ThemeMode? themeMode,
    bool? useMaterial3,
    String? fontFamily,
    FontSize? fontSize,
    bool? enableAnimations,
    bool? reducedMotion,
    bool? highContrast,
    ColorBlindnessType? colorBlindnessSupport,
    CustomColorScheme? customColorScheme,
  }) =>
      ThemeSettings(
        themeMode: themeMode ?? this.themeMode,
        useMaterial3: useMaterial3 ?? this.useMaterial3,
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        enableAnimations: enableAnimations ?? this.enableAnimations,
        reducedMotion: reducedMotion ?? this.reducedMotion,
        highContrast: highContrast ?? this.highContrast,
        colorBlindnessSupport:
            colorBlindnessSupport ?? this.colorBlindnessSupport,
        customColorScheme: customColorScheme ?? this.customColorScheme,
      );

  Map<String, dynamic> toJson() => {
        'theme_mode': themeMode.name,
        'use_material3': useMaterial3,
        'font_family': fontFamily,
        'font_size': fontSize.name,
        'enable_animations': enableAnimations,
        'reduced_motion': reducedMotion,
        'high_contrast': highContrast,
        'color_blindness_support': colorBlindnessSupport.name,
        'custom_color_scheme': customColorScheme?.toJson(),
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ThemeSettings &&
        other.themeMode == themeMode &&
        other.useMaterial3 == useMaterial3 &&
        other.fontFamily == fontFamily &&
        other.fontSize == fontSize &&
        other.enableAnimations == enableAnimations &&
        other.reducedMotion == reducedMotion &&
        other.highContrast == highContrast &&
        other.colorBlindnessSupport == colorBlindnessSupport &&
        other.customColorScheme == customColorScheme;
  }

  @override
  int get hashCode => Object.hash(
        themeMode,
        useMaterial3,
        fontFamily,
        fontSize,
        enableAnimations,
        reducedMotion,
        highContrast,
        colorBlindnessSupport,
        customColorScheme,
      );

  @override
  String toString() => 'ThemeSettings('
      'themeMode: $themeMode, '
      'useMaterial3: $useMaterial3, '
      'fontFamily: $fontFamily, '
      'fontSize: $fontSize, '
      'enableAnimations: $enableAnimations, '
      'reducedMotion: $reducedMotion, '
      'highContrast: $highContrast, '
      'colorBlindnessSupport: $colorBlindnessSupport, '
      'customColorScheme: $customColorScheme'
      ')';
}
