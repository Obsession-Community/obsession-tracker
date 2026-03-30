import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/app_settings.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';
import 'package:obsession_tracker/core/services/app_settings_service.dart';

/// Provider for the app settings service
final appSettingsServiceProvider =
    Provider<AppSettingsService>((ref) => AppSettingsService());

/// Provider for current app settings
final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

/// Notifier for managing app settings state
class AppSettingsNotifier extends Notifier<AppSettings> {
  late final AppSettingsService _settingsService;

  @override
  AppSettings build() {
    _settingsService = ref.watch(appSettingsServiceProvider);
    _initialize();
    return AppSettings.defaultSettings();
  }

  Future<void> _initialize() async {
    await _settingsService.initialize();
    state = _settingsService.currentSettings;
  }

  /// Update map settings
  Future<void> updateMapSettings(MapSettings mapSettings) async {
    final newSettings = state.copyWith(map: mapSettings);
    await _settingsService.updateSettings(newSettings);
    state = newSettings;
  }

  /// Update theme settings
  Future<void> updateThemeSettings(ThemeSettings themeSettings) async {
    final newSettings = state.copyWith(theme: themeSettings);
    await _settingsService.updateSettings(newSettings);
    state = newSettings;
  }

  /// Update privacy settings
  Future<void> updatePrivacySettings(PrivacySettings privacySettings) async {
    final newSettings = state.copyWith(privacy: privacySettings);
    await _settingsService.updateSettings(newSettings);
    state = newSettings;
  }

  /// Update tracking settings
  Future<void> updateTrackingSettings(TrackingSettings trackingSettings) async {
    final newSettings = state.copyWith(tracking: trackingSettings);
    await _settingsService.updateSettings(newSettings);
    state = newSettings;
  }

  /// Update general settings
  Future<void> updateGeneralSettings(GeneralSettings generalSettings) async {
    final newSettings = state.copyWith(general: generalSettings);
    await _settingsService.updateSettings(newSettings);
    state = newSettings;
  }

  /// Update a specific setting
  Future<void> updateSetting(String key, Object? value) async {
    // This is a generic method that could be used for simple updates
    // Implementation would depend on the specific setting being updated
  }
}
