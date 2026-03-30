import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/app_settings.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';
import 'package:obsession_tracker/core/utils/app_logger.dart';
import 'package:path_provider/path_provider.dart';

/// Service for managing application settings persistence and synchronization
class AppSettingsService {
  /// Singleton instance
  static final AppSettingsService instance = AppSettingsService._internal();

  /// Factory constructor returns singleton
  factory AppSettingsService() => instance;

  /// Private constructor for singleton
  AppSettingsService._internal();

  static const String _settingsFileName = 'app_settings.json';

  AppSettings _currentSettings = AppSettings.defaultSettings();

  // Stream controllers for settings changes
  final StreamController<AppSettings> _settingsController =
      StreamController<AppSettings>.broadcast();
  final StreamController<SettingsChangeEvent> _changeController =
      StreamController<SettingsChangeEvent>.broadcast();

  /// Stream of settings changes
  Stream<AppSettings> get settingsStream => _settingsController.stream;

  /// Stream of specific settings change events
  Stream<SettingsChangeEvent> get changeStream => _changeController.stream;

  /// Current settings
  AppSettings get currentSettings => _currentSettings;

  /// Initialize the settings service
  Future<void> initialize() async {
    try {
      AppLogger.info('Initializing app settings service...');

      await _loadSettings();

      AppLogger.info('App settings service initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize app settings service: $e');
      rethrow;
    }
  }

  /// Load settings from persistent storage
  Future<void> _loadSettings() async {
    try {
      await _loadFromFile();

      // Emit the loaded settings
      _settingsController.add(_currentSettings);
    } catch (e) {
      AppLogger.warning('Failed to load settings, using defaults: $e');
      _currentSettings = AppSettings.defaultSettings();
      _settingsController.add(_currentSettings);
    }
  }

  /// Load settings from file storage
  Future<void> _loadFromFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_settingsFileName');

      if (file.existsSync()) {
        final settingsJson = await file.readAsString();
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        _currentSettings = AppSettings.fromJson(settingsMap);
        AppLogger.info('Settings loaded from file storage');
      } else {
        AppLogger.info('No existing settings file found, using defaults');
      }
    } catch (e) {
      AppLogger.warning('Failed to load settings from file: $e');
    }
  }

  /// Save settings to persistent storage
  Future<void> _saveSettings() async {
    try {
      final settingsJson = jsonEncode(_currentSettings.toJson());
      await _saveToFile(settingsJson);
      AppLogger.info('Settings saved successfully');
    } catch (e) {
      AppLogger.error('Failed to save settings: $e');
      rethrow;
    }
  }

  /// Save settings to file storage
  Future<void> _saveToFile(String settingsJson) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_settingsFileName');
      await file.writeAsString(settingsJson);
    } catch (e) {
      AppLogger.error('Failed to save settings to file: $e');
      rethrow;
    }
  }

  /// Update settings
  Future<void> updateSettings(AppSettings newSettings) async {
    final oldSettings = _currentSettings;
    _currentSettings = newSettings;

    try {
      await _saveSettings();

      // OSM land overlay cache removed - using Mapbox annotations now

      // Emit settings change event
      _settingsController.add(_currentSettings);
      _changeController.add(SettingsChangeEvent(
        oldSettings: oldSettings,
        newSettings: newSettings,
        timestamp: DateTime.now(),
      ));

      AppLogger.info('Settings updated successfully');
    } catch (e) {
      // Revert on error
      _currentSettings = oldSettings;
      AppLogger.error('Failed to update settings: $e');
      rethrow;
    }
  }

  /// Update general settings
  Future<void> updateGeneralSettings(GeneralSettings generalSettings) async {
    await updateSettings(_currentSettings.copyWith(general: generalSettings));
  }

  /// Update theme settings
  Future<void> updateThemeSettings(ThemeSettings themeSettings) async {
    await updateSettings(_currentSettings.copyWith(theme: themeSettings));
  }

  /// Update privacy settings
  Future<void> updatePrivacySettings(PrivacySettings privacySettings) async {
    await updateSettings(_currentSettings.copyWith(privacy: privacySettings));
  }

  /// Update notification settings
  Future<void> updateNotificationSettings(
      NotificationSettings notificationSettings) async {
    await updateSettings(
        _currentSettings.copyWith(notifications: notificationSettings));
  }

  /// Update tracking settings
  Future<void> updateTrackingSettings(TrackingSettings trackingSettings) async {
    await updateSettings(_currentSettings.copyWith(tracking: trackingSettings));
  }

  /// Update map settings
  Future<void> updateMapSettings(MapSettings mapSettings) async {
    await updateSettings(_currentSettings.copyWith(map: mapSettings));
  }

  /// Update storage settings
  Future<void> updateStorageSettings(StorageSettings storageSettings) async {
    await updateSettings(_currentSettings.copyWith(storage: storageSettings));
  }

  /// Update export settings
  Future<void> updateExportSettings(ExportSettings exportSettings) async {
    await updateSettings(_currentSettings.copyWith(export: exportSettings));
  }

  /// Update accessibility settings
  Future<void> updateAccessibilitySettings(
      AccessibilitySettings accessibilitySettings) async {
    await updateSettings(
        _currentSettings.copyWith(accessibility: accessibilitySettings));
  }

  /// Update advanced settings
  Future<void> updateAdvancedSettings(AdvancedSettings advancedSettings) async {
    await updateSettings(_currentSettings.copyWith(advanced: advancedSettings));
  }

  /// Reset settings to defaults
  Future<void> resetToDefaults() async {
    final oldSettings = _currentSettings;
    await updateSettings(AppSettings.defaultSettings());

    _changeController.add(SettingsChangeEvent(
      oldSettings: oldSettings,
      newSettings: _currentSettings,
      timestamp: DateTime.now(),
      isReset: true,
    ));
  }

  /// Export settings to JSON string
  String exportSettings() {
    try {
      final exportData = {
        'settings': _currentSettings.toJson(),
        'exported_at': DateTime.now().toIso8601String(),
        'app_version': '1.0.0', // Would be dynamic in real app
        'export_format_version': '1.0',
      };

      return jsonEncode(exportData);
    } catch (e) {
      AppLogger.error('Failed to export settings: $e');
      rethrow;
    }
  }

  /// Import settings from JSON string
  Future<void> importSettings(String settingsJson) async {
    try {
      final importData = jsonDecode(settingsJson) as Map<String, dynamic>;

      // Validate import data
      if (!importData.containsKey('settings')) {
        throw Exception('Invalid settings format: missing settings data');
      }

      final settingsData = importData['settings'] as Map<String, dynamic>;
      final importedSettings = AppSettings.fromJson(settingsData);

      await updateSettings(importedSettings);

      _changeController.add(SettingsChangeEvent(
        oldSettings: _currentSettings,
        newSettings: importedSettings,
        timestamp: DateTime.now(),
        isImport: true,
      ));

      AppLogger.info('Settings imported successfully');
    } catch (e) {
      AppLogger.error('Failed to import settings: $e');
      rethrow;
    }
  }

  /// Create a backup of current settings
  Future<String> createBackup() async {
    try {
      final backupData = {
        'settings': _currentSettings.toJson(),
        'backup_created_at': DateTime.now().toIso8601String(),
        'app_version': '1.0.0',
        'backup_format_version': '1.0',
      };

      return jsonEncode(backupData);
    } catch (e) {
      AppLogger.error('Failed to create settings backup: $e');
      rethrow;
    }
  }

  /// Restore settings from backup
  Future<void> restoreFromBackup(String backupJson) async {
    try {
      final backupData = jsonDecode(backupJson) as Map<String, dynamic>;

      if (!backupData.containsKey('settings')) {
        throw Exception('Invalid backup format: missing settings data');
      }

      final settingsData = backupData['settings'] as Map<String, dynamic>;
      final restoredSettings = AppSettings.fromJson(settingsData);

      await updateSettings(restoredSettings);

      _changeController.add(SettingsChangeEvent(
        oldSettings: _currentSettings,
        newSettings: restoredSettings,
        timestamp: DateTime.now(),
        isRestore: true,
      ));

      AppLogger.info('Settings restored from backup successfully');
    } catch (e) {
      AppLogger.error('Failed to restore settings from backup: $e');
      rethrow;
    }
  }

  /// Validate settings integrity
  bool validateSettings(AppSettings settings) {
    try {
      // Basic validation checks
      if (settings.general.autoSaveInterval.inSeconds < 1) return false;
      if (settings.tracking.minDistanceFilter < 0) return false;
      if (settings.storage.maxStorageSize < 1) return false;
      if (settings.privacy.dataRetentionDays < 1) return false;

      return true;
    } catch (e) {
      AppLogger.warning('Settings validation failed: $e');
      return false;
    }
  }

  /// Get settings change history (simplified version)
  List<SettingsChangeEvent> getChangeHistory({Duration? timeRange}) =>
      // In a real implementation, this would maintain a persistent history
      // For now, return empty list as this is a simplified version
      [];

  /// Dispose of the service
  void dispose() {
    _settingsController.close();
    _changeController.close();
  }
}

/// Event representing a settings change
@immutable
class SettingsChangeEvent {
  const SettingsChangeEvent({
    required this.oldSettings,
    required this.newSettings,
    required this.timestamp,
    this.isReset = false,
    this.isImport = false,
    this.isRestore = false,
  });

  final AppSettings oldSettings;
  final AppSettings newSettings;
  final DateTime timestamp;
  final bool isReset;
  final bool isImport;
  final bool isRestore;

  String get changeType {
    if (isReset) return 'Reset';
    if (isImport) return 'Import';
    if (isRestore) return 'Restore';
    return 'Update';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SettingsChangeEvent &&
        other.oldSettings == oldSettings &&
        other.newSettings == newSettings &&
        other.timestamp == timestamp &&
        other.isReset == isReset &&
        other.isImport == isImport &&
        other.isRestore == isRestore;
  }

  @override
  int get hashCode => Object.hash(
        oldSettings,
        newSettings,
        timestamp,
        isReset,
        isImport,
        isRestore,
      );
}
