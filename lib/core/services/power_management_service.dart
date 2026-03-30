import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/battery_models.dart';
import 'package:obsession_tracker/core/services/adaptive_location_service.dart';
import 'package:obsession_tracker/core/services/background_location_service.dart';
import 'package:obsession_tracker/core/services/battery_monitoring_service.dart';
import 'package:obsession_tracker/core/services/sensor_fusion_service.dart';

/// Comprehensive power management service that coordinates all app services
/// for optimal battery life while maintaining functionality.
///
/// This service acts as the central coordinator for battery optimization,
/// managing power modes, adaptive features, and intelligent resource allocation.
class PowerManagementService {
  factory PowerManagementService() => _instance ??= PowerManagementService._();
  PowerManagementService._();
  static PowerManagementService? _instance;

  // Service dependencies
  final BatteryMonitoringService _batteryService = BatteryMonitoringService();
  final BackgroundLocationService _backgroundLocationService =
      BackgroundLocationService();
  final AdaptiveLocationService _adaptiveLocationService =
      AdaptiveLocationService();
  SensorFusionService? _sensorFusionService;

  // Stream controllers
  StreamController<PowerModeChangeEvent>? _powerModeController;
  StreamController<FeatureStateChangeEvent>? _featureStateController;
  StreamController<PowerOptimizationEvent>? _optimizationController;

  // Service state
  bool _isActive = false;
  PowerManagementConfig _config = PowerManagementConfig.defaultConfig();
  PowerMode _currentMode = PowerMode.balanced;
  final Map<String, bool> _featureStates = {};
  final Map<String, dynamic> _serviceConfigurations = {};

  // Subscriptions
  StreamSubscription<BatteryLevel>? _batterySubscription;
  StreamSubscription<BatteryAnalytics>? _analyticsSubscription;
  StreamSubscription<BatteryHealthAssessment>? _healthSubscription;

  // Optimization timers
  Timer? _optimizationTimer;
  Timer? _featureManagementTimer;

  /// Stream of power mode changes
  Stream<PowerModeChangeEvent> get powerModeStream {
    _powerModeController ??= StreamController<PowerModeChangeEvent>.broadcast();
    return _powerModeController!.stream;
  }

  /// Stream of feature state changes
  Stream<FeatureStateChangeEvent> get featureStateStream {
    _featureStateController ??=
        StreamController<FeatureStateChangeEvent>.broadcast();
    return _featureStateController!.stream;
  }

  /// Stream of power optimization events
  Stream<PowerOptimizationEvent> get optimizationStream {
    _optimizationController ??=
        StreamController<PowerOptimizationEvent>.broadcast();
    return _optimizationController!.stream;
  }

  /// Whether the power management service is active
  bool get isActive => _isActive;

  /// Current power mode
  PowerMode get currentMode => _currentMode;

  /// Current power management configuration
  PowerManagementConfig get config => _config;

  /// Current feature states
  Map<String, bool> get featureStates => Map.from(_featureStates);

  /// Start power management service
  Future<void> start({
    PowerManagementConfig? config,
    SensorFusionService? sensorFusionService,
  }) async {
    try {
      await stop(); // Ensure clean start

      _config = config ?? PowerManagementConfig.defaultConfig();
      _currentMode = _config.mode;
      _sensorFusionService = sensorFusionService;

      debugPrint('⚡ Starting power management service...');
      debugPrint('  Initial mode: ${_currentMode.name}');
      debugPrint('  Auto-switch enabled: ${_config.autoSwitchEnabled}');

      // Initialize stream controllers
      _powerModeController ??=
          StreamController<PowerModeChangeEvent>.broadcast();
      _featureStateController ??=
          StreamController<FeatureStateChangeEvent>.broadcast();
      _optimizationController ??=
          StreamController<PowerOptimizationEvent>.broadcast();

      // Start battery monitoring
      await _batteryService.startMonitoring(config: _config);

      // Subscribe to battery events
      _subscribeToServices();

      // Initialize feature states
      await _initializeFeatureStates();

      // Apply initial power mode configuration
      await _applyPowerModeConfiguration(_currentMode);

      // Start optimization timers
      _startOptimizationTimers();

      _isActive = true;
      debugPrint('⚡ Power management service started successfully');
    } catch (e) {
      debugPrint('⚡ Error starting power management service: $e');
      rethrow;
    }
  }

  /// Stop power management service
  Future<void> stop() async {
    // Cancel subscriptions
    await _batterySubscription?.cancel();
    _batterySubscription = null;

    await _analyticsSubscription?.cancel();
    _analyticsSubscription = null;

    await _healthSubscription?.cancel();
    _healthSubscription = null;

    // Cancel timers
    _optimizationTimer?.cancel();
    _optimizationTimer = null;

    _featureManagementTimer?.cancel();
    _featureManagementTimer = null;

    // Stop battery monitoring
    await _batteryService.stopMonitoring();

    // Close stream controllers
    await _powerModeController?.close();
    _powerModeController = null;

    await _featureStateController?.close();
    _featureStateController = null;

    await _optimizationController?.close();
    _optimizationController = null;

    _isActive = false;
    debugPrint('⚡ Power management service stopped');
  }

  /// Change power mode
  Future<void> setPowerMode(PowerMode newMode, {String? reason}) async {
    if (newMode == _currentMode) return;

    final oldMode = _currentMode;
    _currentMode = newMode;

    debugPrint('⚡ Changing power mode: ${oldMode.name} → ${newMode.name}');
    if (reason != null) {
      debugPrint('  Reason: $reason');
    }

    // Update configuration
    _config = _config.copyWith(mode: newMode);
    await _batteryService.updateConfig(_config);

    // Apply new power mode configuration
    await _applyPowerModeConfiguration(newMode);

    // Emit power mode change event
    final event = PowerModeChangeEvent(
      oldMode: oldMode,
      newMode: newMode,
      reason: reason ?? 'Manual change',
      timestamp: DateTime.now(),
    );
    _powerModeController?.add(event);

    debugPrint('⚡ Power mode changed successfully');
  }

  /// Update power management configuration
  Future<void> updateConfig(PowerManagementConfig newConfig) async {
    final oldConfig = _config;
    _config = newConfig;

    debugPrint('⚡ Updating power management configuration');

    // Update battery service configuration
    await _batteryService.updateConfig(newConfig);

    // Apply mode change if needed
    if (oldConfig.mode != newConfig.mode) {
      await setPowerMode(newConfig.mode, reason: 'Configuration update');
    }

    debugPrint('⚡ Configuration updated successfully');
  }

  /// Enable or disable a specific feature
  Future<void> setFeatureEnabled(String featureName,
      {required bool enabled, String? reason}) async {
    final wasEnabled = _featureStates[featureName] ?? false;
    if (wasEnabled == enabled) return;

    _featureStates[featureName] = enabled;

    debugPrint('⚡ Feature $featureName ${enabled ? 'enabled' : 'disabled'}');
    if (reason != null) {
      debugPrint('  Reason: $reason');
    }

    // Apply feature configuration
    await _applyFeatureConfiguration(featureName, enabled);

    // Emit feature state change event
    final event = FeatureStateChangeEvent(
      featureName: featureName,
      enabled: enabled,
      reason: reason ?? 'Manual change',
      timestamp: DateTime.now(),
    );
    _featureStateController?.add(event);
  }

  /// Get current battery level
  BatteryLevel? getCurrentBatteryLevel() => _batteryService.currentBatteryLevel;

  /// Get current battery analytics
  BatteryAnalytics getCurrentBatteryAnalytics() =>
      _batteryService.getCurrentAnalytics();

  /// Get current battery health assessment
  BatteryHealthAssessment getCurrentBatteryHealth() =>
      _batteryService.getCurrentHealthAssessment();

  /// Start tracking battery usage for a service
  void startServiceTracking(ServiceType serviceType) {
    _batteryService.startServiceTracking(serviceType);
  }

  /// Stop tracking battery usage for a service
  void stopServiceTracking(ServiceType serviceType,
      {Map<String, dynamic>? additionalData}) {
    _batteryService.stopServiceTracking(serviceType,
        additionalData: additionalData);
  }

  /// Trigger immediate power optimization
  Future<void> triggerOptimization({String? reason}) async {
    debugPrint('⚡ Triggering power optimization');
    if (reason != null) {
      debugPrint('  Reason: $reason');
    }

    await _performPowerOptimization();
  }

  /// Get recommended power mode based on current conditions
  PowerMode getRecommendedPowerMode() {
    final batteryLevel = _batteryService.currentBatteryLevel;
    if (batteryLevel == null) return PowerMode.balanced;

    final percentage = batteryLevel.percentage;
    final isCharging = batteryLevel.isCharging;

    // If charging, can use higher performance modes
    if (isCharging) {
      return percentage > 80 ? PowerMode.highPerformance : PowerMode.balanced;
    }

    // Battery level based recommendations
    if (percentage <= 15) return PowerMode.ultraBatterySaver;
    if (percentage <= 30) return PowerMode.batterySaver;
    if (percentage <= 50) return PowerMode.balanced;
    return PowerMode.highPerformance;
  }

  /// Get power optimization suggestions
  List<BatteryOptimizationSuggestion> getOptimizationSuggestions() {
    final analytics = _batteryService.getCurrentAnalytics();
    return analytics.optimizationSuggestions;
  }

  void _subscribeToServices() {
    // Subscribe to battery level changes
    _batterySubscription = _batteryService.batteryLevelStream.listen(
      _handleBatteryLevelChange,
      onError: (Object error) =>
          debugPrint('⚡ Battery level stream error: $error'),
    );

    // Subscribe to battery analytics
    _analyticsSubscription = _batteryService.analyticsStream.listen(
      _handleBatteryAnalytics,
      onError: (Object error) =>
          debugPrint('⚡ Battery analytics stream error: $error'),
    );

    // Subscribe to battery health assessments
    _healthSubscription = _batteryService.healthStream.listen(
      _handleBatteryHealthAssessment,
      onError: (Object error) =>
          debugPrint('⚡ Battery health stream error: $error'),
    );
  }

  Future<void> _initializeFeatureStates() async {
    // Initialize default feature states based on power mode
    _featureStates.clear();

    switch (_currentMode) {
      case PowerMode.highPerformance:
        _featureStates['gps_tracking'] = true;
        _featureStates['background_location'] = true;
        _featureStates['sensor_fusion'] = true;
        _featureStates['adaptive_location'] = true;
        _featureStates['compass'] = true;
        _featureStates['accelerometer'] = true;
        _featureStates['magnetometer'] = true;
        _featureStates['barometer'] = true;
        break;

      case PowerMode.balanced:
        _featureStates['gps_tracking'] = true;
        _featureStates['background_location'] = true;
        _featureStates['sensor_fusion'] = true;
        _featureStates['adaptive_location'] = true;
        _featureStates['compass'] = true;
        _featureStates['accelerometer'] = true;
        _featureStates['magnetometer'] = true;
        _featureStates['barometer'] = false;
        break;

      case PowerMode.batterySaver:
        _featureStates['gps_tracking'] = true;
        _featureStates['background_location'] = false;
        _featureStates['sensor_fusion'] = false;
        _featureStates['adaptive_location'] = true;
        _featureStates['compass'] = true;
        _featureStates['accelerometer'] = false;
        _featureStates['magnetometer'] = false;
        _featureStates['barometer'] = false;
        break;

      case PowerMode.ultraBatterySaver:
        _featureStates['gps_tracking'] = true;
        _featureStates['background_location'] = false;
        _featureStates['sensor_fusion'] = false;
        _featureStates['adaptive_location'] = false;
        _featureStates['compass'] = false;
        _featureStates['accelerometer'] = false;
        _featureStates['magnetometer'] = false;
        _featureStates['barometer'] = false;
        break;
    }

    debugPrint('⚡ Initialized feature states for ${_currentMode.name} mode');
  }

  Future<void> _applyPowerModeConfiguration(PowerMode mode) async {
    debugPrint('⚡ Applying power mode configuration: ${mode.name}');

    // Update feature states for the new mode
    await _initializeFeatureStates();

    // Configure GPS tracking
    await _configureGpsTracking(mode);

    // Configure sensor fusion
    await _configureSensorFusion(mode);

    // Configure adaptive location
    await _configureAdaptiveLocation(mode);

    // Store service configurations
    _serviceConfigurations['power_mode'] = mode;
    _serviceConfigurations['gps_interval'] = mode.gpsUpdateInterval;
    _serviceConfigurations['sensor_frequency'] = mode.sensorUpdateFrequency;
    _serviceConfigurations['background_processing_limited'] =
        mode.limitBackgroundProcessing;

    debugPrint('⚡ Power mode configuration applied successfully');
  }

  Future<void> _configureGpsTracking(PowerMode mode) async {
    if (!(_featureStates['gps_tracking'] ?? false)) return;

    try {
      // Configure background location service
      if (_featureStates['background_location'] ?? false) {
        if (_backgroundLocationService.isBackgroundTrackingActive) {
          await _backgroundLocationService.stopBackgroundTracking();
        }

        await _backgroundLocationService.startBackgroundTracking(
          updateIntervalSeconds: mode.gpsUpdateInterval,
          minimumDistanceMeters:
              mode == PowerMode.ultraBatterySaver ? 20.0 : 5.0,
          enableBatteryOptimization: mode != PowerMode.highPerformance,
        );
      }

      debugPrint('⚡ GPS tracking configured for ${mode.name} mode');
    } catch (e) {
      debugPrint('⚡ Error configuring GPS tracking: $e');
    }
  }

  Future<void> _configureSensorFusion(PowerMode mode) async {
    if (_sensorFusionService == null) return;

    try {
      if (_featureStates['sensor_fusion'] ?? false) {
        final sensorMode = _getSensorFusionMode(mode);
        await _sensorFusionService!.setMode(sensorMode);
      } else {
        await _sensorFusionService!.stop();
      }

      debugPrint('⚡ Sensor fusion configured for ${mode.name} mode');
    } catch (e) {
      debugPrint('⚡ Error configuring sensor fusion: $e');
    }
  }

  Future<void> _configureAdaptiveLocation(PowerMode mode) async {
    if (!(_featureStates['adaptive_location'] ?? false)) {
      if (_adaptiveLocationService.isActive) {
        await _adaptiveLocationService.stop();
      }
      return;
    }

    try {
      final adaptiveMode = _getAdaptiveLocationMode(mode);
      await _adaptiveLocationService.setMode(adaptiveMode);

      debugPrint('⚡ Adaptive location configured for ${mode.name} mode');
    } catch (e) {
      debugPrint('⚡ Error configuring adaptive location: $e');
    }
  }

  Future<void> _applyFeatureConfiguration(
      String featureName, bool enabled) async {
    switch (featureName) {
      case 'background_location':
        await _configureBackgroundLocation(enabled);
        break;
      case 'sensor_fusion':
        await _configureSensorFusionFeature(enabled);
        break;
      case 'adaptive_location':
        await _configureAdaptiveLocationFeature(enabled);
        break;
      default:
        debugPrint('⚡ Unknown feature: $featureName');
    }
  }

  Future<void> _configureBackgroundLocation(bool enabled) async {
    try {
      if (enabled) {
        if (!_backgroundLocationService.isBackgroundTrackingActive) {
          await _backgroundLocationService.startBackgroundTracking(
            updateIntervalSeconds: _currentMode.gpsUpdateInterval,
            enableBatteryOptimization:
                _currentMode != PowerMode.highPerformance,
          );
        }
      } else {
        if (_backgroundLocationService.isBackgroundTrackingActive) {
          await _backgroundLocationService.stopBackgroundTracking();
        }
      }
    } catch (e) {
      debugPrint('⚡ Error configuring background location: $e');
    }
  }

  Future<void> _configureSensorFusionFeature(bool enabled) async {
    if (_sensorFusionService == null) return;

    try {
      if (enabled) {
        if (!_sensorFusionService!.isActive) {
          final mode = _getSensorFusionMode(_currentMode);
          await _sensorFusionService!.start(mode: mode);
        }
      } else {
        if (_sensorFusionService!.isActive) {
          await _sensorFusionService!.stop();
        }
      }
    } catch (e) {
      debugPrint('⚡ Error configuring sensor fusion feature: $e');
    }
  }

  Future<void> _configureAdaptiveLocationFeature(bool enabled) async {
    try {
      if (enabled) {
        if (!_adaptiveLocationService.isActive) {
          final mode = _getAdaptiveLocationMode(_currentMode);
          await _adaptiveLocationService.start(mode: mode);
        }
      } else {
        if (_adaptiveLocationService.isActive) {
          await _adaptiveLocationService.stop();
        }
      }
    } catch (e) {
      debugPrint('⚡ Error configuring adaptive location feature: $e');
    }
  }

  SensorFusionMode _getSensorFusionMode(PowerMode powerMode) {
    switch (powerMode) {
      case PowerMode.highPerformance:
        return SensorFusionMode.comprehensive;
      case PowerMode.balanced:
        return SensorFusionMode.balanced;
      case PowerMode.batterySaver:
      case PowerMode.ultraBatterySaver:
        return SensorFusionMode.minimal;
    }
  }

  AdaptiveTrackingMode _getAdaptiveLocationMode(PowerMode powerMode) {
    switch (powerMode) {
      case PowerMode.highPerformance:
        return AdaptiveTrackingMode.highAccuracy;
      case PowerMode.balanced:
        return AdaptiveTrackingMode.balanced;
      case PowerMode.batterySaver:
      case PowerMode.ultraBatterySaver:
        return AdaptiveTrackingMode.batteryOptimized;
    }
  }

  void _startOptimizationTimers() {
    // Periodic optimization check
    _optimizationTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _performPowerOptimization(),
    );

    // Feature management timer
    _featureManagementTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _performFeatureManagement(),
    );
  }

  void _handleBatteryLevelChange(BatteryLevel batteryLevel) {
    debugPrint('⚡ Battery level changed: ${batteryLevel.percentage}%');

    // Check for automatic power mode switching
    if (_config.autoSwitchEnabled) {
      _checkAutomaticModeSwitch(batteryLevel);
    }
  }

  void _handleBatteryAnalytics(BatteryAnalytics analytics) {
    debugPrint(
        '⚡ Battery analytics updated: ${analytics.batteryHealthScore.toStringAsFixed(1)} health score');

    // Emit optimization event if needed
    if (analytics.needsOptimization) {
      final event = PowerOptimizationEvent(
        type: OptimizationEventType.analyticsTriggered,
        description: 'Battery analytics indicate optimization needed',
        suggestions: analytics.optimizationSuggestions,
        timestamp: DateTime.now(),
      );
      _optimizationController?.add(event);
    }
  }

  void _handleBatteryHealthAssessment(BatteryHealthAssessment assessment) {
    debugPrint('⚡ Battery health assessment: ${assessment.grade.displayName}');

    // Emit optimization event for poor health
    if (assessment.grade == BatteryHealthGrade.poor ||
        assessment.grade == BatteryHealthGrade.critical) {
      final event = PowerOptimizationEvent(
        type: OptimizationEventType.healthAssessment,
        description:
            'Battery health assessment indicates immediate optimization needed',
        suggestions: [],
        timestamp: DateTime.now(),
      );
      _optimizationController?.add(event);
    }
  }

  void _checkAutomaticModeSwitch(BatteryLevel batteryLevel) {
    final percentage = batteryLevel.percentage;
    PowerMode? newMode;

    if (percentage <= _config.autoSwitchToUltraSaver &&
        _currentMode != PowerMode.ultraBatterySaver) {
      newMode = PowerMode.ultraBatterySaver;
    } else if (percentage <= _config.autoSwitchToBatterySaver &&
        _currentMode == PowerMode.balanced) {
      newMode = PowerMode.batterySaver;
    } else if (percentage > _config.lowBatteryThreshold &&
        _currentMode == PowerMode.ultraBatterySaver) {
      newMode = PowerMode.batterySaver;
    } else if (percentage > 50 &&
        _currentMode == PowerMode.batterySaver &&
        batteryLevel.isCharging) {
      newMode = PowerMode.balanced;
    }

    if (newMode != null) {
      setPowerMode(newMode, reason: 'Automatic switch based on battery level');
    }
  }

  Future<void> _performPowerOptimization() async {
    try {
      debugPrint('⚡ Performing power optimization...');

      final analytics = _batteryService.getCurrentAnalytics();
      final health = _batteryService.getCurrentHealthAssessment();

      // Apply optimizations based on analytics
      if (analytics.needsOptimization) {
        await _applyAnalyticsOptimizations(analytics);
      }

      // Apply optimizations based on health assessment
      if (health.grade == BatteryHealthGrade.poor ||
          health.grade == BatteryHealthGrade.critical) {
        await _applyHealthOptimizations(health);
      }

      // Emit optimization event
      final event = PowerOptimizationEvent(
        type: OptimizationEventType.periodicOptimization,
        description: 'Periodic power optimization completed',
        suggestions: analytics.optimizationSuggestions,
        timestamp: DateTime.now(),
      );
      _optimizationController?.add(event);

      debugPrint('⚡ Power optimization completed');
    } catch (e) {
      debugPrint('⚡ Error during power optimization: $e');
    }
  }

  Future<void> _applyAnalyticsOptimizations(BatteryAnalytics analytics) async {
    for (final suggestion in analytics.optimizationSuggestions) {
      if (suggestion.priority == OptimizationPriority.high ||
          suggestion.priority == OptimizationPriority.critical) {
        await _applySuggestion(suggestion);
      }
    }
  }

  Future<void> _applyHealthOptimizations(BatteryHealthAssessment health) async {
    if (health.overallScore < 40.0) {
      // Critical health - switch to ultra battery saver
      if (_currentMode != PowerMode.ultraBatterySaver) {
        await setPowerMode(PowerMode.ultraBatterySaver,
            reason: 'Critical battery health');
      }
    } else if (health.overallScore < 60.0) {
      // Poor health - switch to battery saver
      if (_currentMode == PowerMode.highPerformance ||
          _currentMode == PowerMode.balanced) {
        await setPowerMode(PowerMode.batterySaver,
            reason: 'Poor battery health');
      }
    }
  }

  Future<void> _applySuggestion(
      BatteryOptimizationSuggestion suggestion) async {
    switch (suggestion.type) {
      case OptimizationType.switchPowerMode:
        if (_currentMode != PowerMode.batterySaver) {
          await setPowerMode(PowerMode.batterySaver, reason: suggestion.title);
        }
        break;
      case OptimizationType.disableUnusedSensors:
        await setFeatureEnabled('sensor_fusion',
            enabled: false, reason: suggestion.title);
        break;
      case OptimizationType.limitBackgroundProcessing:
        await setFeatureEnabled('background_location',
            enabled: false, reason: suggestion.title);
        break;
      default:
        debugPrint('⚡ Unhandled optimization suggestion: ${suggestion.type}');
    }
  }

  Future<void> _performFeatureManagement() async {
    // This could include intelligent feature toggling based on usage patterns
    // For now, just log that feature management is running
    debugPrint('⚡ Performing feature management check...');
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    stop();
    _batteryService.dispose();
    _instance = null;
  }
}

/// Power mode change event
class PowerModeChangeEvent {
  const PowerModeChangeEvent({
    required this.oldMode,
    required this.newMode,
    required this.reason,
    required this.timestamp,
  });

  final PowerMode oldMode;
  final PowerMode newMode;
  final String reason;
  final DateTime timestamp;

  @override
  String toString() =>
      'PowerModeChangeEvent(${oldMode.name} → ${newMode.name}: $reason)';
}

/// Feature state change event
class FeatureStateChangeEvent {
  const FeatureStateChangeEvent({
    required this.featureName,
    required this.enabled,
    required this.reason,
    required this.timestamp,
  });

  final String featureName;
  final bool enabled;
  final String reason;
  final DateTime timestamp;

  @override
  String toString() =>
      'FeatureStateChangeEvent($featureName: ${enabled ? 'enabled' : 'disabled'})';
}

/// Power optimization event
class PowerOptimizationEvent {
  const PowerOptimizationEvent({
    required this.type,
    required this.description,
    required this.suggestions,
    required this.timestamp,
  });

  final OptimizationEventType type;
  final String description;
  final List<BatteryOptimizationSuggestion> suggestions;
  final DateTime timestamp;

  @override
  String toString() => 'PowerOptimizationEvent(${type.name}: $description)';
}

/// Types of optimization events
enum OptimizationEventType {
  periodicOptimization,
  analyticsTriggered,
  healthAssessment,
  manualTrigger,
  batteryLevelChange;

  String get displayName {
    switch (this) {
      case OptimizationEventType.periodicOptimization:
        return 'Periodic Optimization';
      case OptimizationEventType.analyticsTriggered:
        return 'Analytics Triggered';
      case OptimizationEventType.healthAssessment:
        return 'Health Assessment';
      case OptimizationEventType.manualTrigger:
        return 'Manual Trigger';
      case OptimizationEventType.batteryLevelChange:
        return 'Battery Level Change';
    }
  }
}
