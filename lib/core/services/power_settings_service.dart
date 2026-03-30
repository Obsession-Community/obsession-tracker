import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/battery_models.dart';
import 'package:obsession_tracker/core/models/intelligent_frequency_models.dart';
import 'package:obsession_tracker/core/services/adaptive_feature_manager.dart';
import 'package:obsession_tracker/core/services/battery_optimization_coordinator.dart';

/// User-configurable power-saving settings service
///
/// Provides a comprehensive interface for users to customize battery optimization
/// settings, create custom power profiles, and manage power-saving preferences.
class PowerSettingsService {
  factory PowerSettingsService() => _instance ??= PowerSettingsService._();
  PowerSettingsService._();
  static PowerSettingsService? _instance;

  final BatteryOptimizationCoordinator _coordinator =
      BatteryOptimizationCoordinator();

  // Stream controllers
  StreamController<PowerSettingsEvent>? _settingsController;
  StreamController<PowerProfile>? _profileController;

  // Service state
  bool _isActive = false;
  PowerSettings _currentSettings = PowerSettings.defaultSettings();
  final Map<String, PowerProfile> _customProfiles = {};
  final List<PowerSettingsChange> _changeHistory = <PowerSettingsChange>[];
  static const int _maxHistoryLength = 100;

  /// Stream of power settings events
  Stream<PowerSettingsEvent> get settingsStream {
    _settingsController ??= StreamController<PowerSettingsEvent>.broadcast();
    return _settingsController!.stream;
  }

  /// Stream of power profile changes
  Stream<PowerProfile> get profileStream {
    _profileController ??= StreamController<PowerProfile>.broadcast();
    return _profileController!.stream;
  }

  /// Whether the service is active
  bool get isActive => _isActive;

  /// Current power settings
  PowerSettings get currentSettings => _currentSettings;

  /// Available power profiles
  Map<String, PowerProfile> get availableProfiles => {
        ...getBuiltInProfiles(),
        ..._customProfiles,
      };

  /// Start power settings service
  Future<void> start() async {
    try {
      await stop(); // Ensure clean start

      debugPrint('⚙️ Starting power settings service...');

      // Initialize stream controllers
      _settingsController ??= StreamController<PowerSettingsEvent>.broadcast();
      _profileController ??= StreamController<PowerProfile>.broadcast();

      // Load saved settings
      await _loadSettings();

      // Load custom profiles
      await _loadCustomProfiles();

      // Apply current settings
      await _applySettings(_currentSettings);

      _isActive = true;
      debugPrint('⚙️ Power settings service started successfully');
    } catch (e) {
      debugPrint('⚙️ Error starting power settings service: $e');
      rethrow;
    }
  }

  /// Stop power settings service
  Future<void> stop() async {
    // Save current settings
    await _saveSettings();

    // Save custom profiles
    await _saveCustomProfiles();

    // Close stream controllers
    await _settingsController?.close();
    _settingsController = null;

    await _profileController?.close();
    _profileController = null;

    _isActive = false;
    debugPrint('⚙️ Power settings service stopped');
  }

  /// Update power settings
  Future<void> updateSettings(PowerSettings newSettings) async {
    final oldSettings = _currentSettings;
    _currentSettings = newSettings;

    debugPrint('⚙️ Updating power settings...');

    // Record change
    _recordSettingsChange(oldSettings, newSettings);

    // Apply new settings
    await _applySettings(newSettings);

    // Save settings
    await _saveSettings();

    // Emit event
    _emitSettingsEvent(PowerSettingsEvent(
      type: SettingsEventType.settingsUpdated,
      description: 'Power settings updated',
      oldSettings: oldSettings,
      newSettings: newSettings,
      timestamp: DateTime.now(),
    ));

    debugPrint('⚙️ Power settings updated successfully');
  }

  /// Create custom power profile
  Future<void> createCustomProfile(PowerProfile profile) async {
    if (_customProfiles.containsKey(profile.id)) {
      throw ArgumentError('Profile with ID ${profile.id} already exists');
    }

    _customProfiles[profile.id] = profile;
    await _saveCustomProfiles();

    _profileController?.add(profile);

    _emitSettingsEvent(PowerSettingsEvent(
      type: SettingsEventType.profileCreated,
      description: 'Custom profile "${profile.name}" created',
      timestamp: DateTime.now(),
    ));

    debugPrint('⚙️ Custom profile "${profile.name}" created');
  }

  /// Update custom power profile
  Future<void> updateCustomProfile(PowerProfile profile) async {
    if (!_customProfiles.containsKey(profile.id)) {
      throw ArgumentError('Profile with ID ${profile.id} does not exist');
    }

    _customProfiles[profile.id] = profile;
    await _saveCustomProfiles();

    _profileController?.add(profile);

    _emitSettingsEvent(PowerSettingsEvent(
      type: SettingsEventType.profileUpdated,
      description: 'Custom profile "${profile.name}" updated',
      timestamp: DateTime.now(),
    ));

    debugPrint('⚙️ Custom profile "${profile.name}" updated');
  }

  /// Delete custom power profile
  Future<void> deleteCustomProfile(String profileId) async {
    final profile = _customProfiles.remove(profileId);
    if (profile == null) {
      throw ArgumentError('Profile with ID $profileId does not exist');
    }

    await _saveCustomProfiles();

    _emitSettingsEvent(PowerSettingsEvent(
      type: SettingsEventType.profileDeleted,
      description: 'Custom profile "${profile.name}" deleted',
      timestamp: DateTime.now(),
    ));

    debugPrint('⚙️ Custom profile "${profile.name}" deleted');
  }

  /// Apply power profile
  Future<void> applyProfile(String profileId) async {
    final profile = availableProfiles[profileId];
    if (profile == null) {
      throw ArgumentError('Profile with ID $profileId does not exist');
    }

    debugPrint('⚙️ Applying power profile: ${profile.name}');

    // Convert profile to settings
    final settings = _profileToSettings(profile);
    await updateSettings(settings);

    _emitSettingsEvent(PowerSettingsEvent(
      type: SettingsEventType.profileApplied,
      description: 'Applied power profile "${profile.name}"',
      timestamp: DateTime.now(),
    ));

    debugPrint('⚙️ Power profile "${profile.name}" applied successfully');
  }

  /// Get built-in power profiles
  Map<String, PowerProfile> getBuiltInProfiles() => {
        'maximum_performance': const PowerProfile(
          id: 'maximum_performance',
          name: 'Maximum Performance',
          description: 'Highest accuracy and features, maximum battery usage',
          isBuiltIn: true,
          powerMode: PowerMode.highPerformance,
          gpsUpdateInterval: 3,
          enableBackgroundLocation: true,
          enableSensorFusion: true,
          enableAdaptiveLocation: true,
          enableIntelligentFrequency: false,
          featureSettings: FeatureSettings(
            enableCamera: true,
            enableAudioRecording: true,
            enableMapRendering: true,
            enableNotifications: true,
            enableDataSync: true,
            enableAnalytics: true,
          ),
          batteryThresholds: BatteryThresholds(
            critical: 10,
            low: 20,
            normal: 40,
            high: 70,
          ),
        ),
        'balanced': const PowerProfile(
          id: 'balanced',
          name: 'Balanced',
          description: 'Optimal balance of features and battery life',
          isBuiltIn: true,
          powerMode: PowerMode.balanced,
          gpsUpdateInterval: 15,
          enableBackgroundLocation: true,
          enableSensorFusion: true,
          enableAdaptiveLocation: true,
          enableIntelligentFrequency: true,
          featureSettings: FeatureSettings(
            enableCamera: true,
            enableAudioRecording: true,
            enableMapRendering: true,
            enableNotifications: true,
            enableDataSync: true,
            enableAnalytics: false,
          ),
          batteryThresholds: BatteryThresholds(
            critical: 15,
            low: 30,
            normal: 50,
            high: 80,
          ),
        ),
        'battery_saver': const PowerProfile(
          id: 'battery_saver',
          name: 'Battery Saver',
          description: 'Extended battery life with reduced features',
          isBuiltIn: true,
          powerMode: PowerMode.batterySaver,
          gpsUpdateInterval: 60,
          enableBackgroundLocation: false,
          enableSensorFusion: false,
          enableAdaptiveLocation: true,
          enableIntelligentFrequency: true,
          featureSettings: FeatureSettings(
            enableCamera: false,
            enableAudioRecording: false,
            enableMapRendering: true,
            enableNotifications: true,
            enableDataSync: false,
            enableAnalytics: false,
          ),
          batteryThresholds: BatteryThresholds(
            critical: 20,
            low: 40,
            normal: 60,
            high: 85,
          ),
        ),
        'ultra_battery_saver': const PowerProfile(
          id: 'ultra_battery_saver',
          name: 'Ultra Battery Saver',
          description: 'Maximum battery conservation, minimal features',
          isBuiltIn: true,
          powerMode: PowerMode.ultraBatterySaver,
          gpsUpdateInterval: 300,
          enableBackgroundLocation: false,
          enableSensorFusion: false,
          enableAdaptiveLocation: false,
          enableIntelligentFrequency: false,
          featureSettings: FeatureSettings(
            enableCamera: false,
            enableAudioRecording: false,
            enableMapRendering: false,
            enableNotifications: true,
            enableDataSync: false,
            enableAnalytics: false,
          ),
          batteryThresholds: BatteryThresholds(
            critical: 25,
            low: 50,
            normal: 70,
            high: 90,
          ),
        ),
      };

  /// Get settings change history
  List<PowerSettingsChange> getChangeHistory({Duration? timeRange}) {
    var history = _changeHistory.toList();

    if (timeRange != null) {
      final cutoff = DateTime.now().subtract(timeRange);
      history =
          history.where((change) => change.timestamp.isAfter(cutoff)).toList();
    }

    return history;
  }

  /// Reset settings to default
  Future<void> resetToDefault() async {
    debugPrint('⚙️ Resetting settings to default...');

    final defaultSettings = PowerSettings.defaultSettings();
    await updateSettings(defaultSettings);

    _emitSettingsEvent(PowerSettingsEvent(
      type: SettingsEventType.settingsReset,
      description: 'Settings reset to default',
      timestamp: DateTime.now(),
    ));

    debugPrint('⚙️ Settings reset to default successfully');
  }

  /// Export settings
  Future<String> exportSettings() async {
    debugPrint('⚙️ Exporting power settings...');

    final exportData = {
      'version': '1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'settings': _currentSettings.toJson(),
      'custom_profiles':
          _customProfiles.map((key, value) => MapEntry(key, value.toJson())),
      'change_history':
          _changeHistory.map((change) => change.toJson()).toList(),
    };

    return jsonEncode(exportData);
  }

  /// Import settings
  Future<void> importSettings(String settingsJson) async {
    debugPrint('⚙️ Importing power settings...');

    try {
      final data = jsonDecode(settingsJson) as Map<String, dynamic>;

      // Import settings
      if (data.containsKey('settings')) {
        final settings =
            PowerSettings.fromJson(data['settings'] as Map<String, dynamic>);
        await updateSettings(settings);
      }

      // Import custom profiles
      if (data.containsKey('custom_profiles')) {
        final profiles = data['custom_profiles'] as Map<String, dynamic>;
        for (final entry in profiles.entries) {
          final profile =
              PowerProfile.fromJson(entry.value as Map<String, dynamic>);
          _customProfiles[entry.key] = profile;
        }
        await _saveCustomProfiles();
      }

      _emitSettingsEvent(PowerSettingsEvent(
        type: SettingsEventType.settingsImported,
        description: 'Settings imported successfully',
        timestamp: DateTime.now(),
      ));

      debugPrint('⚙️ Settings imported successfully');
    } catch (e) {
      debugPrint('⚙️ Error importing settings: $e');
      throw Exception('Failed to import settings: $e');
    }
  }

  /// Get optimization recommendations based on usage patterns
  List<SettingsRecommendation> getOptimizationRecommendations() {
    final recommendations = <SettingsRecommendation>[];

    // Analyze current settings and usage patterns
    if (_currentSettings.powerMode == PowerMode.highPerformance) {
      recommendations.add(SettingsRecommendation(
        title: 'Consider Balanced Mode',
        description:
            'High performance mode uses significant battery. Consider switching to balanced mode for better battery life.',
        category: RecommendationCategory.optimization,
        priority: RecommendationPriority.medium,
        estimatedBatterySavings: 25.0,
        settingsChange:
            _currentSettings.copyWith(powerMode: PowerMode.balanced),
      ));
    }

    if (_currentSettings.gpsUpdateInterval < 10) {
      recommendations.add(SettingsRecommendation(
        title: 'Increase GPS Update Interval',
        description:
            'Very frequent GPS updates consume significant battery. Consider increasing the interval.',
        category: RecommendationCategory.optimization,
        priority: RecommendationPriority.medium,
        estimatedBatterySavings: 15.0,
        settingsChange: _currentSettings.copyWith(gpsUpdateInterval: 15),
      ));
    }

    return recommendations;
  }

  Future<void> _loadSettings() async {
    // In a real implementation, this would load from persistent storage
    // For now, use default settings
    _currentSettings = PowerSettings.defaultSettings();
    debugPrint('⚙️ Loaded power settings');
  }

  Future<void> _saveSettings() async {
    // In a real implementation, this would save to persistent storage
    debugPrint('⚙️ Saved power settings');
  }

  Future<void> _loadCustomProfiles() async {
    // In a real implementation, this would load from persistent storage
    debugPrint('⚙️ Loaded custom profiles');
  }

  Future<void> _saveCustomProfiles() async {
    // In a real implementation, this would save to persistent storage
    debugPrint('⚙️ Saved custom profiles');
  }

  Future<void> _applySettings(PowerSettings settings) async {
    debugPrint('⚙️ Applying power settings...');

    // Create optimization configuration from settings
    final optimizationConfig = BatteryOptimizationConfig(
      optimizationMode: _mapPowerModeToOptimizationMode(settings.powerMode),
      enableAutoOptimization: settings.enableAutoOptimization,
      enableIntelligentFrequency: settings.enableIntelligentFrequency,
      enableAdaptiveLocation: settings.enableAdaptiveLocation,
      coordinationIntervalMinutes: 10,
      powerManagementConfig: PowerManagementConfig(
        mode: settings.powerMode,
        autoSwitchEnabled: settings.enableAutoModeSwitch,
        criticalBatteryThreshold: settings.batteryThresholds.critical,
        lowBatteryThreshold: settings.batteryThresholds.low,
        autoSwitchToBatterySaver: settings.batteryThresholds.low,
        autoSwitchToUltraSaver: settings.batteryThresholds.critical,
        enableAdaptiveFrequency: settings.enableIntelligentFrequency,
        enableBackgroundOptimization: settings.enableBackgroundOptimization,
        customSettings: {},
      ),
      featureManagementConfig: AdaptiveFeatureConfig(
        adaptationMode: _mapOptimizationModeToAdaptationMode(
            _mapPowerModeToOptimizationMode(settings.powerMode)),
        enableAutoAdaptation: settings.enableAutoOptimization,
        enableBackgroundOptimization: settings.enableBackgroundOptimization,
        adaptationIntervalMinutes: 5,
        batteryThresholds: settings.batteryThresholds,
        usageThresholds: const UsageThresholds(
          minUsageCount: 5,
          maxUnusedHours: 24,
          minSessionDuration: Duration(minutes: 1),
        ),
      ),
      frequencyConfig: FrequencyAlgorithmConfig(
        minFrequencySeconds: 2,
        maxFrequencySeconds: 300,
        defaultFrequencySeconds: settings.gpsUpdateInterval,
        learningIntervalMinutes: 10,
        optimizationIntervalMinutes: 5,
        enablePredictiveAlgorithms: settings.enableIntelligentFrequency,
        enablePatternLearning: settings.enableIntelligentFrequency,
        batteryThresholds: settings.batteryThresholds,
        movementThresholds: const MovementThresholds(
          stationary: 0.5,
          walking: 2.0,
          jogging: 5.0,
          cycling: 15.0,
          driving: 50.0,
        ),
        accuracyThresholds: const AccuracyThresholds(
          excellent: 5.0,
          good: 10.0,
          fair: 20.0,
          poor: 50.0,
        ),
      ),
    );

    // Apply configuration to coordinator
    if (_coordinator.isActive) {
      await _coordinator.updateConfig(optimizationConfig);
    }

    debugPrint('⚙️ Power settings applied successfully');
  }

  OptimizationMode _mapPowerModeToOptimizationMode(PowerMode powerMode) {
    switch (powerMode) {
      case PowerMode.highPerformance:
        return OptimizationMode.conservative;
      case PowerMode.balanced:
        return OptimizationMode.balanced;
      case PowerMode.batterySaver:
      case PowerMode.ultraBatterySaver:
        return OptimizationMode.aggressive;
    }
  }

  AdaptationMode _mapOptimizationModeToAdaptationMode(
      OptimizationMode optimizationMode) {
    switch (optimizationMode) {
      case OptimizationMode.conservative:
        return AdaptationMode.conservative;
      case OptimizationMode.balanced:
        return AdaptationMode.balanced;
      case OptimizationMode.aggressive:
        return AdaptationMode.aggressive;
    }
  }

  PowerSettings _profileToSettings(PowerProfile profile) => PowerSettings(
        powerMode: profile.powerMode,
        gpsUpdateInterval: profile.gpsUpdateInterval,
        enableBackgroundLocation: profile.enableBackgroundLocation,
        enableSensorFusion: profile.enableSensorFusion,
        enableAdaptiveLocation: profile.enableAdaptiveLocation,
        enableIntelligentFrequency: profile.enableIntelligentFrequency,
        enableAutoOptimization: true,
        enableAutoModeSwitch: true,
        enableBackgroundOptimization: true,
        batteryThresholds: profile.batteryThresholds,
        featureSettings: profile.featureSettings,
      );

  void _recordSettingsChange(
      PowerSettings oldSettings, PowerSettings newSettings) {
    final change = PowerSettingsChange(
      oldSettings: oldSettings,
      newSettings: newSettings,
      changeType: ChangeType.manual,
      reason: 'User modification',
      timestamp: DateTime.now(),
    );

    _changeHistory.add(change);
    if (_changeHistory.length > _maxHistoryLength) {
      _changeHistory.removeAt(0);
    }
  }

  void _emitSettingsEvent(PowerSettingsEvent event) {
    _settingsController?.add(event);
    debugPrint('⚙️ Event: ${event.description}');
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    stop();
    _customProfiles.clear();
    _changeHistory.clear();
    _instance = null;
  }
}

/// Power settings configuration
class PowerSettings {
  const PowerSettings({
    required this.powerMode,
    required this.gpsUpdateInterval,
    required this.enableBackgroundLocation,
    required this.enableSensorFusion,
    required this.enableAdaptiveLocation,
    required this.enableIntelligentFrequency,
    required this.enableAutoOptimization,
    required this.enableAutoModeSwitch,
    required this.enableBackgroundOptimization,
    required this.batteryThresholds,
    required this.featureSettings,
  });

  /// Default settings
  factory PowerSettings.defaultSettings() => const PowerSettings(
        powerMode: PowerMode.balanced,
        gpsUpdateInterval: 15,
        enableBackgroundLocation: true,
        enableSensorFusion: true,
        enableAdaptiveLocation: true,
        enableIntelligentFrequency: true,
        enableAutoOptimization: true,
        enableAutoModeSwitch: true,
        enableBackgroundOptimization: true,
        batteryThresholds: BatteryThresholds(
          critical: 15,
          low: 30,
          normal: 50,
          high: 80,
        ),
        featureSettings: FeatureSettings(
          enableCamera: true,
          enableAudioRecording: true,
          enableMapRendering: true,
          enableNotifications: true,
          enableDataSync: true,
          enableAnalytics: false,
        ),
      );

  factory PowerSettings.fromJson(Map<String, dynamic> json) => PowerSettings(
        powerMode: PowerMode.values
            .firstWhere((mode) => mode.name == json['power_mode']),
        gpsUpdateInterval: json['gps_update_interval'] as int,
        enableBackgroundLocation: json['enable_background_location'] as bool,
        enableSensorFusion: json['enable_sensor_fusion'] as bool,
        enableAdaptiveLocation: json['enable_adaptive_location'] as bool,
        enableIntelligentFrequency:
            json['enable_intelligent_frequency'] as bool,
        enableAutoOptimization: json['enable_auto_optimization'] as bool,
        enableAutoModeSwitch: json['enable_auto_mode_switch'] as bool,
        enableBackgroundOptimization:
            json['enable_background_optimization'] as bool,
        batteryThresholds: BatteryThresholds(
          critical: json['battery_thresholds']['critical'] as int,
          low: json['battery_thresholds']['low'] as int,
          normal: json['battery_thresholds']['normal'] as int,
          high: json['battery_thresholds']['high'] as int,
        ),
        featureSettings: FeatureSettings.fromJson(
            json['feature_settings'] as Map<String, dynamic>),
      );

  final PowerMode powerMode;
  final int gpsUpdateInterval;
  final bool enableBackgroundLocation;
  final bool enableSensorFusion;
  final bool enableAdaptiveLocation;
  final bool enableIntelligentFrequency;
  final bool enableAutoOptimization;
  final bool enableAutoModeSwitch;
  final bool enableBackgroundOptimization;
  final BatteryThresholds batteryThresholds;
  final FeatureSettings featureSettings;

  PowerSettings copyWith({
    PowerMode? powerMode,
    int? gpsUpdateInterval,
    bool? enableBackgroundLocation,
    bool? enableSensorFusion,
    bool? enableAdaptiveLocation,
    bool? enableIntelligentFrequency,
    bool? enableAutoOptimization,
    bool? enableAutoModeSwitch,
    bool? enableBackgroundOptimization,
    BatteryThresholds? batteryThresholds,
    FeatureSettings? featureSettings,
  }) =>
      PowerSettings(
        powerMode: powerMode ?? this.powerMode,
        gpsUpdateInterval: gpsUpdateInterval ?? this.gpsUpdateInterval,
        enableBackgroundLocation:
            enableBackgroundLocation ?? this.enableBackgroundLocation,
        enableSensorFusion: enableSensorFusion ?? this.enableSensorFusion,
        enableAdaptiveLocation:
            enableAdaptiveLocation ?? this.enableAdaptiveLocation,
        enableIntelligentFrequency:
            enableIntelligentFrequency ?? this.enableIntelligentFrequency,
        enableAutoOptimization:
            enableAutoOptimization ?? this.enableAutoOptimization,
        enableAutoModeSwitch: enableAutoModeSwitch ?? this.enableAutoModeSwitch,
        enableBackgroundOptimization:
            enableBackgroundOptimization ?? this.enableBackgroundOptimization,
        batteryThresholds: batteryThresholds ?? this.batteryThresholds,
        featureSettings: featureSettings ?? this.featureSettings,
      );

  Map<String, dynamic> toJson() => {
        'power_mode': powerMode.name,
        'gps_update_interval': gpsUpdateInterval,
        'enable_background_location': enableBackgroundLocation,
        'enable_sensor_fusion': enableSensorFusion,
        'enable_adaptive_location': enableAdaptiveLocation,
        'enable_intelligent_frequency': enableIntelligentFrequency,
        'enable_auto_optimization': enableAutoOptimization,
        'enable_auto_mode_switch': enableAutoModeSwitch,
        'enable_background_optimization': enableBackgroundOptimization,
        'battery_thresholds': {
          'critical': batteryThresholds.critical,
          'low': batteryThresholds.low,
          'normal': batteryThresholds.normal,
          'high': batteryThresholds.high,
        },
        'feature_settings': featureSettings.toJson(),
      };
}

/// Feature settings
class FeatureSettings {
  const FeatureSettings({
    required this.enableCamera,
    required this.enableAudioRecording,
    required this.enableMapRendering,
    required this.enableNotifications,
    required this.enableDataSync,
    required this.enableAnalytics,
  });

  factory FeatureSettings.fromJson(Map<String, dynamic> json) =>
      FeatureSettings(
        enableCamera: json['enable_camera'] as bool,
        enableAudioRecording: json['enable_audio_recording'] as bool,
        enableMapRendering: json['enable_map_rendering'] as bool,
        enableNotifications: json['enable_notifications'] as bool,
        enableDataSync: json['enable_data_sync'] as bool,
        enableAnalytics: json['enable_analytics'] as bool,
      );

  final bool enableCamera;
  final bool enableAudioRecording;
  final bool enableMapRendering;
  final bool enableNotifications;
  final bool enableDataSync;
  final bool enableAnalytics;

  Map<String, dynamic> toJson() => {
        'enable_camera': enableCamera,
        'enable_audio_recording': enableAudioRecording,
        'enable_map_rendering': enableMapRendering,
        'enable_notifications': enableNotifications,
        'enable_data_sync': enableDataSync,
        'enable_analytics': enableAnalytics,
      };
}

/// Power profile
class PowerProfile {
  const PowerProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.isBuiltIn,
    required this.powerMode,
    required this.gpsUpdateInterval,
    required this.enableBackgroundLocation,
    required this.enableSensorFusion,
    required this.enableAdaptiveLocation,
    required this.enableIntelligentFrequency,
    required this.featureSettings,
    required this.batteryThresholds,
  });

  factory PowerProfile.fromJson(Map<String, dynamic> json) => PowerProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        isBuiltIn: json['is_built_in'] as bool,
        powerMode: PowerMode.values
            .firstWhere((mode) => mode.name == json['power_mode']),
        gpsUpdateInterval: json['gps_update_interval'] as int,
        enableBackgroundLocation: json['enable_background_location'] as bool,
        enableSensorFusion: json['enable_sensor_fusion'] as bool,
        enableAdaptiveLocation: json['enable_adaptive_location'] as bool,
        enableIntelligentFrequency:
            json['enable_intelligent_frequency'] as bool,
        featureSettings: FeatureSettings.fromJson(
            json['feature_settings'] as Map<String, dynamic>),
        batteryThresholds: BatteryThresholds(
          critical: json['battery_thresholds']['critical'] as int,
          low: json['battery_thresholds']['low'] as int,
          normal: json['battery_thresholds']['normal'] as int,
          high: json['battery_thresholds']['high'] as int,
        ),
      );

  final String id;
  final String name;
  final String description;
  final bool isBuiltIn;
  final PowerMode powerMode;
  final int gpsUpdateInterval;
  final bool enableBackgroundLocation;
  final bool enableSensorFusion;
  final bool enableAdaptiveLocation;
  final bool enableIntelligentFrequency;
  final FeatureSettings featureSettings;
  final BatteryThresholds batteryThresholds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'is_built_in': isBuiltIn,
        'power_mode': powerMode.name,
        'gps_update_interval': gpsUpdateInterval,
        'enable_background_location': enableBackgroundLocation,
        'enable_sensor_fusion': enableSensorFusion,
        'enable_adaptive_location': enableAdaptiveLocation,
        'enable_intelligent_frequency': enableIntelligentFrequency,
        'feature_settings': featureSettings.toJson(),
        'battery_thresholds': {
          'critical': batteryThresholds.critical,
          'low': batteryThresholds.low,
          'normal': batteryThresholds.normal,
          'high': batteryThresholds.high,
        },
      };
}

/// Settings recommendation
class SettingsRecommendation {
  const SettingsRecommendation({
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.estimatedBatterySavings,
    required this.settingsChange,
  });

  final String title;
  final String description;
  final RecommendationCategory category;
  final RecommendationPriority priority;
  final double estimatedBatterySavings;
  final PowerSettings settingsChange;
}

/// Power settings event
class PowerSettingsEvent {
  const PowerSettingsEvent({
    required this.type,
    required this.description,
    required this.timestamp,
    this.oldSettings,
    this.newSettings,
  });

  final SettingsEventType type;
  final String description;
  final DateTime timestamp;
  final PowerSettings? oldSettings;
  final PowerSettings? newSettings;
}

/// Settings event types
enum SettingsEventType {
  settingsUpdated,
  profileCreated,
  profileUpdated,
  profileDeleted,
  profileApplied,
  settingsReset,
  settingsImported;

  String get name {
    switch (this) {
      case SettingsEventType.settingsUpdated:
        return 'Settings Updated';
      case SettingsEventType.profileCreated:
        return 'Profile Created';
      case SettingsEventType.profileUpdated:
        return 'Profile Updated';
      case SettingsEventType.profileDeleted:
        return 'Profile Deleted';
      case SettingsEventType.profileApplied:
        return 'Profile Applied';
      case SettingsEventType.settingsReset:
        return 'Settings Reset';
      case SettingsEventType.settingsImported:
        return 'Settings Imported';
    }
  }
}

/// Power settings change record
class PowerSettingsChange {
  const PowerSettingsChange({
    required this.oldSettings,
    required this.newSettings,
    required this.changeType,
    required this.reason,
    required this.timestamp,
  });

  factory PowerSettingsChange.fromJson(Map<String, dynamic> json) =>
      PowerSettingsChange(
        oldSettings: PowerSettings.fromJson(
            json['old_settings'] as Map<String, dynamic>),
        newSettings: PowerSettings.fromJson(
            json['new_settings'] as Map<String, dynamic>),
        changeType: ChangeType.values
            .firstWhere((type) => type.name == json['change_type']),
        reason: json['reason'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  final PowerSettings oldSettings;
  final PowerSettings newSettings;
  final ChangeType changeType;
  final String reason;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'old_settings': oldSettings.toJson(),
        'new_settings': newSettings.toJson(),
        'change_type': changeType.name,
        'reason': reason,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Change types
enum ChangeType {
  manual,
  automatic,
  profileApplied,
  imported;

  String get name {
    switch (this) {
      case ChangeType.manual:
        return 'Manual';
      case ChangeType.automatic:
        return 'Automatic';
      case ChangeType.profileApplied:
        return 'Profile Applied';
      case ChangeType.imported:
        return 'Imported';
    }
  }
}
