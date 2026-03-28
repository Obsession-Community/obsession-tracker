import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/app_settings.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';
import 'package:obsession_tracker/core/services/app_settings_service.dart';

/// Provider for the app settings service
final appSettingsServiceProvider =
    Provider<AppSettingsService>((ref) => AppSettingsService());

/// Provider for the current app settings
final appSettingsProvider = StreamProvider<AppSettings>((ref) {
  final service = ref.watch(appSettingsServiceProvider);
  return service.settingsStream;
});

/// Provider for settings change events
final settingsChangeProvider = StreamProvider<SettingsChangeEvent>((ref) {
  final service = ref.watch(appSettingsServiceProvider);
  return service.changeStream;
});

/// Provider for general settings
final generalSettingsProvider = Provider<GeneralSettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.general,
    loading: () => const GeneralSettings(),
    error: (_, __) => const GeneralSettings(),
  );
});

/// Provider for theme settings
final themeSettingsProvider = Provider<ThemeSettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.theme,
    loading: () => const ThemeSettings(),
    error: (_, __) => const ThemeSettings(),
  );
});

/// Provider for privacy settings
final privacySettingsProvider = Provider<PrivacySettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.privacy,
    loading: () => const PrivacySettings(),
    error: (_, __) => const PrivacySettings(),
  );
});

/// Provider for notification settings
final notificationSettingsProvider = Provider<NotificationSettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.notifications,
    loading: () => const NotificationSettings(),
    error: (_, __) => const NotificationSettings(),
  );
});

/// Provider for tracking settings
final trackingSettingsProvider = Provider<TrackingSettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.tracking,
    loading: () => const TrackingSettings(),
    error: (_, __) => const TrackingSettings(),
  );
});

/// Provider for map settings
final mapSettingsProvider = Provider<MapSettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.map,
    loading: () => const MapSettings(),
    error: (_, __) => const MapSettings(),
  );
});

/// Provider for storage settings
final storageSettingsProvider = Provider<StorageSettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.storage,
    loading: () => const StorageSettings(),
    error: (_, __) => const StorageSettings(),
  );
});

/// Provider for export settings
final exportSettingsProvider = Provider<ExportSettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.export,
    loading: () => const ExportSettings(),
    error: (_, __) => const ExportSettings(),
  );
});

/// Provider for accessibility settings
final accessibilitySettingsProvider = Provider<AccessibilitySettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.accessibility,
    loading: () => const AccessibilitySettings(),
    error: (_, __) => const AccessibilitySettings(),
  );
});

/// Provider for advanced settings
final advancedSettingsProvider = Provider<AdvancedSettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.advanced,
    loading: () => const AdvancedSettings(),
    error: (_, __) => const AdvancedSettings(),
  );
});

/// Notifier for managing settings updates
class AppSettingsNotifier extends Notifier<AsyncValue<AppSettings>> {
  late final AppSettingsService _service;

  @override
  AsyncValue<AppSettings> build() {
    _service = ref.watch(appSettingsServiceProvider);
    _initialize();
    return const AsyncValue.loading();
  }

  Future<void> _initialize() async {
    try {
      await _service.initialize();
      _service.settingsStream.listen((settings) {
        state = AsyncValue.data(settings);
      });
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Update general settings
  Future<void> updateGeneralSettings(GeneralSettings generalSettings) async {
    try {
      await _service.updateGeneralSettings(generalSettings);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Update theme settings
  Future<void> updateThemeSettings(ThemeSettings themeSettings) async {
    try {
      await _service.updateThemeSettings(themeSettings);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Update privacy settings
  Future<void> updatePrivacySettings(PrivacySettings privacySettings) async {
    try {
      await _service.updatePrivacySettings(privacySettings);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Update notification settings
  Future<void> updateNotificationSettings(
      NotificationSettings notificationSettings) async {
    try {
      await _service.updateNotificationSettings(notificationSettings);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Update tracking settings
  Future<void> updateTrackingSettings(TrackingSettings trackingSettings) async {
    try {
      await _service.updateTrackingSettings(trackingSettings);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Update map settings
  Future<void> updateMapSettings(MapSettings mapSettings) async {
    try {
      await _service.updateMapSettings(mapSettings);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Update storage settings
  Future<void> updateStorageSettings(StorageSettings storageSettings) async {
    try {
      await _service.updateStorageSettings(storageSettings);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Update export settings
  Future<void> updateExportSettings(ExportSettings exportSettings) async {
    try {
      await _service.updateExportSettings(exportSettings);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Update accessibility settings
  Future<void> updateAccessibilitySettings(
      AccessibilitySettings accessibilitySettings) async {
    try {
      await _service.updateAccessibilitySettings(accessibilitySettings);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Update advanced settings
  Future<void> updateAdvancedSettings(AdvancedSettings advancedSettings) async {
    try {
      await _service.updateAdvancedSettings(advancedSettings);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Reset settings to defaults
  Future<void> resetToDefaults() async {
    try {
      await _service.resetToDefaults();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Export settings
  String exportSettings() => _service.exportSettings();

  /// Import settings
  Future<void> importSettings(String settingsJson) async {
    try {
      await _service.importSettings(settingsJson);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Create backup
  Future<String> createBackup() async => _service.createBackup();

  /// Restore from backup
  Future<void> restoreFromBackup(String backupJson) async {
    try {
      await _service.restoreFromBackup(backupJson);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

/// Provider for the settings notifier
final appSettingsNotifierProvider =
    NotifierProvider<AppSettingsNotifier, AsyncValue<AppSettings>>(
        AppSettingsNotifier.new);
