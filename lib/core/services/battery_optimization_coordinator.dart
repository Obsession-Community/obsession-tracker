import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/battery_models.dart';
import 'package:obsession_tracker/core/models/intelligent_frequency_models.dart';
import 'package:obsession_tracker/core/services/adaptive_feature_manager.dart';
import 'package:obsession_tracker/core/services/adaptive_location_service.dart';
import 'package:obsession_tracker/core/services/background_location_service.dart';
import 'package:obsession_tracker/core/services/background_task_manager.dart';
import 'package:obsession_tracker/core/services/battery_analytics_service.dart';
import 'package:obsession_tracker/core/services/battery_monitoring_service.dart';
import 'package:obsession_tracker/core/services/intelligent_frequency_service.dart';
import 'package:obsession_tracker/core/services/power_management_service.dart';
import 'package:obsession_tracker/core/services/sensor_fusion_service.dart';

/// Central coordinator for all battery optimization services
///
/// This service integrates and coordinates all battery optimization components
/// to provide a unified, intelligent power management system for the app.
class BatteryOptimizationCoordinator {
  factory BatteryOptimizationCoordinator() =>
      _instance ??= BatteryOptimizationCoordinator._();
  BatteryOptimizationCoordinator._();
  static BatteryOptimizationCoordinator? _instance;

  // Core services
  final BatteryMonitoringService _batteryService = BatteryMonitoringService();
  final PowerManagementService _powerService = PowerManagementService();
  final AdaptiveFeatureManager _featureManager = AdaptiveFeatureManager();
  final BatteryAnalyticsService _analyticsService = BatteryAnalyticsService();
  final IntelligentFrequencyService _frequencyService =
      IntelligentFrequencyService();
  final BackgroundTaskManager _taskManager = BackgroundTaskManager();

  // Optional services (injected)
  SensorFusionService? _sensorFusionService;
  AdaptiveLocationService? _adaptiveLocationService;

  // Stream controllers
  StreamController<BatteryOptimizationEvent>? _eventController;
  StreamController<SystemHealthStatus>? _healthController;

  // Service state
  bool _isActive = false;
  BatteryOptimizationConfig _config = BatteryOptimizationConfig.defaultConfig();

  // Coordination state
  Timer? _coordinationTimer;
  Timer? _healthCheckTimer;
  final Map<String, StreamSubscription<dynamic>> _subscriptions = {};

  /// Stream of battery optimization events
  Stream<BatteryOptimizationEvent> get eventStream {
    _eventController ??= StreamController<BatteryOptimizationEvent>.broadcast();
    return _eventController!.stream;
  }

  /// Stream of system health status
  Stream<SystemHealthStatus> get healthStream {
    _healthController ??= StreamController<SystemHealthStatus>.broadcast();
    return _healthController!.stream;
  }

  /// Whether the coordinator is active
  bool get isActive => _isActive;

  /// Current configuration
  BatteryOptimizationConfig get config => _config;

  /// Start battery optimization coordination
  Future<void> start({
    BatteryOptimizationConfig? config,
    SensorFusionService? sensorFusionService,
    AdaptiveLocationService? adaptiveLocationService,
    BackgroundLocationService? backgroundLocationService,
  }) async {
    try {
      await stop(); // Ensure clean start

      _config = config ?? BatteryOptimizationConfig.defaultConfig();
      _sensorFusionService = sensorFusionService;
      _adaptiveLocationService = adaptiveLocationService;

      debugPrint('🔋 Starting battery optimization coordinator...');
      debugPrint('  Mode: ${_config.optimizationMode.name}');
      debugPrint('  Auto-optimization: ${_config.enableAutoOptimization}');

      // Initialize stream controllers
      _eventController ??=
          StreamController<BatteryOptimizationEvent>.broadcast();
      _healthController ??= StreamController<SystemHealthStatus>.broadcast();

      // Start core services
      await _startCoreServices();

      // Start optional services
      await _startOptionalServices();

      // Subscribe to service events
      _subscribeToServices();

      // Start coordination timers
      _startCoordinationTimers();

      _isActive = true;

      // Emit startup event
      _emitEvent(BatteryOptimizationEvent(
        type: OptimizationEventType.systemStartup,
        description: 'Battery optimization coordinator started',
        impact: 'All optimization services are now active',
        timestamp: DateTime.now(),
      ));

      debugPrint('🔋 Battery optimization coordinator started successfully');
    } catch (e) {
      debugPrint('🔋 Error starting battery optimization coordinator: $e');
      rethrow;
    }
  }

  /// Stop battery optimization coordination
  Future<void> stop() async {
    // Cancel subscriptions
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    // Cancel timers
    _coordinationTimer?.cancel();
    _coordinationTimer = null;

    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    // Stop services
    await _stopAllServices();

    // Close stream controllers
    await _eventController?.close();
    _eventController = null;

    await _healthController?.close();
    _healthController = null;

    _isActive = false;
    debugPrint('🔋 Battery optimization coordinator stopped');
  }

  /// Update configuration
  Future<void> updateConfig(BatteryOptimizationConfig newConfig) async {
    final oldConfig = _config;
    _config = newConfig;

    debugPrint('🔋 Updating optimization configuration...');

    // Update service configurations
    await _updateServiceConfigurations(oldConfig, newConfig);

    _emitEvent(BatteryOptimizationEvent(
      type: OptimizationEventType.configurationChange,
      description: 'Optimization configuration updated',
      impact: 'Service parameters adjusted for new configuration',
      timestamp: DateTime.now(),
    ));

    debugPrint('🔋 Configuration updated successfully');
  }

  /// Get current system health status
  SystemHealthStatus getCurrentSystemHealth() => _generateSystemHealthStatus();

  /// Get comprehensive optimization report
  Future<OptimizationReport> generateOptimizationReport() async {
    debugPrint('🔋 Generating comprehensive optimization report...');

    final batteryReport = await _analyticsService.generateReport();
    final systemHealth = getCurrentSystemHealth();
    final recommendations = _generateSystemRecommendations();

    final report = OptimizationReport(
      batteryReport: batteryReport,
      systemHealth: systemHealth,
      recommendations: recommendations,
      serviceStatus: _getServiceStatus(),
      optimizationEffectiveness: _calculateOptimizationEffectiveness(),
      generatedAt: DateTime.now(),
    );

    debugPrint('🔋 Optimization report generated successfully');
    return report;
  }

  /// Trigger immediate system optimization
  Future<void> triggerOptimization({String? reason}) async {
    debugPrint('🔋 Triggering immediate system optimization...');
    if (reason != null) {
      debugPrint('  Reason: $reason');
    }

    // Trigger optimization across all services
    await _powerService.triggerOptimization(reason: reason);
    await _featureManager
        .applyRecommendations(_featureManager.getFeatureRecommendations());

    if (_frequencyService.isActive) {
      final recommendation = _frequencyService.getFrequencyRecommendation();
      await _frequencyService.applyRecommendation(recommendation);
    }

    _emitEvent(BatteryOptimizationEvent(
      type: OptimizationEventType.manualOptimization,
      description: reason ?? 'Manual optimization triggered',
      impact: 'System-wide optimization performed',
      timestamp: DateTime.now(),
    ));

    debugPrint('🔋 System optimization completed');
  }

  /// Handle critical battery level
  Future<void> handleCriticalBattery() async {
    debugPrint('🔋 Handling critical battery level...');

    // Switch to ultra battery saver mode
    await _powerService.setPowerMode(PowerMode.ultraBatterySaver,
        reason: 'Critical battery level');

    // Apply aggressive feature management
    final criticalConfig = AdaptiveFeatureConfig.defaultConfig().copyWith(
      adaptationMode: AdaptationMode.aggressive,
    );
    await _featureManager.updateConfig(criticalConfig);

    // Set conservative frequency mode
    if (_frequencyService.isActive) {
      await _frequencyService.setMode(FrequencyMode.batterySaver);
    }

    _emitEvent(BatteryOptimizationEvent(
      type: OptimizationEventType.criticalBattery,
      description:
          'Critical battery level detected - emergency optimizations applied',
      impact: 'Maximum battery conservation measures activated',
      timestamp: DateTime.now(),
    ));

    debugPrint('🔋 Critical battery handling completed');
  }

  Future<void> _startCoreServices() async {
    // Start battery monitoring
    await _batteryService.startMonitoring(
        config: _config.powerManagementConfig);

    // Start power management
    await _powerService.start(
      config: _config.powerManagementConfig,
      sensorFusionService: _sensorFusionService,
    );

    // Start feature management
    await _featureManager.start(config: _config.featureManagementConfig);

    // Start analytics
    await _analyticsService.start();

    // Start task management
    await _taskManager.start(
        initialPowerMode: _config.powerManagementConfig.mode);
  }

  Future<void> _startOptionalServices() async {
    // Start frequency service if enabled
    if (_config.enableIntelligentFrequency) {
      await _frequencyService.start(
        config: _config.frequencyConfig,
      );
    }

    // Start adaptive location if available
    if (_adaptiveLocationService != null && _config.enableAdaptiveLocation) {
      await _adaptiveLocationService!.start(
        sensorFusionService: _sensorFusionService,
      );
    }
  }

  void _subscribeToServices() {
    // Subscribe to battery level changes
    _subscriptions['battery'] = _batteryService.batteryLevelStream.listen(
      _handleBatteryLevelChange,
      onError: (Object error) =>
          debugPrint('🔋 Battery subscription error: $error'),
    );

    // Subscribe to power mode changes
    _subscriptions['power'] = _powerService.powerModeStream.listen(
      _handlePowerModeChange,
      onError: (Object error) =>
          debugPrint('🔋 Power mode subscription error: $error'),
    );

    // Subscribe to feature adaptations
    _subscriptions['features'] = _featureManager.adaptationStream.listen(
      _handleFeatureAdaptation,
      onError: (Object error) =>
          debugPrint('🔋 Feature adaptation subscription error: $error'),
    );

    // Subscribe to frequency adjustments
    if (_frequencyService.isActive) {
      _subscriptions['frequency'] = _frequencyService.adjustmentStream.listen(
        _handleFrequencyAdjustment,
        onError: (Object error) =>
            debugPrint('🔋 Frequency adjustment subscription error: $error'),
      );
    }

    // Subscribe to task events
    _subscriptions['tasks'] = _taskManager.taskEventStream.listen(
      _handleTaskEvent,
      onError: (Object error) =>
          debugPrint('🔋 Task event subscription error: $error'),
    );
  }

  void _startCoordinationTimers() {
    // Coordination timer - coordinate between services
    _coordinationTimer = Timer.periodic(
      Duration(minutes: _config.coordinationIntervalMinutes),
      (_) => _performCoordination(),
    );

    // Health check timer - monitor system health
    _healthCheckTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _performHealthCheck(),
    );
  }

  void _handleBatteryLevelChange(BatteryLevel batteryLevel) {
    debugPrint('🔋 Battery level changed: ${batteryLevel.percentage}%');

    // Handle critical battery
    if (batteryLevel.isCriticallyLow) {
      handleCriticalBattery();
    }

    // Update frequency service with battery data
    if (_frequencyService.isActive) {
      _frequencyService.recordBatteryData(batteryLevel);
    }
  }

  void _handlePowerModeChange(PowerModeChangeEvent event) {
    debugPrint(
        '🔋 Power mode changed: ${event.oldMode.name} → ${event.newMode.name}');

    // Update task manager priority threshold
    _taskManager.updatePowerMode(event.newMode);

    _emitEvent(BatteryOptimizationEvent(
      type: OptimizationEventType.powerModeChange,
      description: 'Power mode changed to ${event.newMode.name}',
      impact: event.reason,
      timestamp: DateTime.now(),
    ));
  }

  void _handleFeatureAdaptation(FeatureAdaptationEvent event) {
    debugPrint('🔋 Feature adapted: ${event.featureId} ${event.action.name}');

    _emitEvent(BatteryOptimizationEvent(
      type: OptimizationEventType.featureAdaptation,
      description: 'Feature ${event.featureId} ${event.action.name}',
      impact: event.reason,
      timestamp: DateTime.now(),
    ));
  }

  void _handleFrequencyAdjustment(FrequencyAdjustmentEvent event) {
    debugPrint(
        '🔋 Frequency adjusted: ${event.oldFrequency}s → ${event.newFrequency}s');

    _emitEvent(BatteryOptimizationEvent(
      type: OptimizationEventType.frequencyAdjustment,
      description: 'GPS frequency adjusted to ${event.newFrequency}s',
      impact: event.reason,
      timestamp: DateTime.now(),
    ));
  }

  void _handleTaskEvent(BackgroundTaskEvent event) {
    if (event.type == TaskEventType.failed ||
        event.type == TaskEventType.timeout) {
      debugPrint('🔋 Task issue: ${event.taskId} ${event.type.name}');

      _emitEvent(BatteryOptimizationEvent(
        type: OptimizationEventType.taskManagement,
        description: 'Background task ${event.type.name}: ${event.taskId}',
        impact: event.description,
        timestamp: DateTime.now(),
      ));
    }
  }

  Future<void> _performCoordination() async {
    debugPrint('🔋 Performing service coordination...');

    // Get current system state
    final batteryLevel = _batteryService.currentBatteryLevel;
    final systemHealth = getCurrentSystemHealth();

    // Coordinate based on system state
    if (batteryLevel != null &&
        systemHealth.overallHealth == SystemHealth.poor) {
      await _coordinateForPoorHealth();
    } else if (batteryLevel != null && batteryLevel.isLow) {
      await _coordinateForLowBattery();
    }

    debugPrint('🔋 Service coordination completed');
  }

  Future<void> _coordinateForPoorHealth() async {
    debugPrint('🔋 Coordinating for poor system health...');

    // Apply conservative optimizations across all services
    await _powerService.setPowerMode(PowerMode.batterySaver,
        reason: 'Poor system health');

    if (_frequencyService.isActive) {
      await _frequencyService.setMode(FrequencyMode.batterySaver);
    }
  }

  Future<void> _coordinateForLowBattery() async {
    debugPrint('🔋 Coordinating for low battery...');

    // Apply battery-saving measures
    final recommendations = _featureManager
        .getFeatureRecommendations()
        .where((r) =>
            r.priority == FeaturePriority.high ||
            r.priority == FeaturePriority.critical)
        .toList();

    await _featureManager.applyRecommendations(recommendations);
  }

  void _performHealthCheck() {
    final healthStatus = _generateSystemHealthStatus();
    _healthController?.add(healthStatus);

    if (healthStatus.overallHealth == SystemHealth.critical) {
      _emitEvent(BatteryOptimizationEvent(
        type: OptimizationEventType.healthAlert,
        description: 'Critical system health detected',
        impact: 'Immediate optimization required',
        timestamp: DateTime.now(),
      ));
    }
  }

  SystemHealthStatus _generateSystemHealthStatus() {
    final batteryHealth = _batteryService.getCurrentHealthAssessment();
    final serviceStates = _getServiceStatus();

    // Calculate overall health
    final healthScores = [
      batteryHealth.overallScore,
      _calculateServiceHealthScore(serviceStates),
    ];

    final overallScore =
        healthScores.reduce((a, b) => a + b) / healthScores.length;
    final overallHealth = _mapScoreToHealth(overallScore);

    return SystemHealthStatus(
      overallHealth: overallHealth,
      overallScore: overallScore,
      batteryHealth: batteryHealth,
      serviceStates: serviceStates,
      activeOptimizations: _getActiveOptimizations(),
      timestamp: DateTime.now(),
    );
  }

  double _calculateServiceHealthScore(Map<String, ServiceState> serviceStates) {
    final activeServices = serviceStates.values.where((s) => s.isActive).length;
    final totalServices = serviceStates.length;

    return totalServices > 0 ? (activeServices / totalServices) * 100 : 0.0;
  }

  SystemHealth _mapScoreToHealth(double score) {
    if (score >= 80) return SystemHealth.excellent;
    if (score >= 60) return SystemHealth.good;
    if (score >= 40) return SystemHealth.fair;
    if (score >= 20) return SystemHealth.poor;
    return SystemHealth.critical;
  }

  Map<String, ServiceState> _getServiceStatus() => {
        'battery_monitoring': ServiceState(
          serviceName: 'Battery Monitoring',
          isActive: _batteryService.isMonitoring,
          healthScore: 100.0,
          lastUpdate: DateTime.now(),
        ),
        'power_management': ServiceState(
          serviceName: 'Power Management',
          isActive: _powerService.isActive,
          healthScore: 100.0,
          lastUpdate: DateTime.now(),
        ),
        'feature_management': ServiceState(
          serviceName: 'Feature Management',
          isActive: _featureManager.isActive,
          healthScore: 100.0,
          lastUpdate: DateTime.now(),
        ),
        'analytics': ServiceState(
          serviceName: 'Analytics',
          isActive: _analyticsService.isActive,
          healthScore: 100.0,
          lastUpdate: DateTime.now(),
        ),
        'task_management': ServiceState(
          serviceName: 'Task Management',
          isActive: _taskManager.isActive,
          healthScore: 100.0,
          lastUpdate: DateTime.now(),
        ),
        'frequency_service': ServiceState(
          serviceName: 'Intelligent Frequency',
          isActive: _frequencyService.isActive,
          healthScore: 100.0,
          lastUpdate: DateTime.now(),
        ),
      };

  List<String> _getActiveOptimizations() {
    final optimizations = <String>[];

    if (_powerService.currentMode != PowerMode.balanced) {
      optimizations.add('Power mode: ${_powerService.currentMode.name}');
    }

    if (_frequencyService.isActive &&
        _frequencyService.currentMode == FrequencyMode.adaptive) {
      optimizations.add('Adaptive GPS frequency');
    }

    return optimizations;
  }

  List<SystemRecommendation> _generateSystemRecommendations() {
    final recommendations = <SystemRecommendation>[];
    final systemHealth = getCurrentSystemHealth();

    if (systemHealth.overallHealth == SystemHealth.poor ||
        systemHealth.overallHealth == SystemHealth.critical) {
      recommendations.add(const SystemRecommendation(
        title: 'Enable Aggressive Battery Optimization',
        description:
            'System health is poor. Consider enabling aggressive battery optimization.',
        priority: RecommendationPriority.high,
        category: RecommendationCategory.optimization,
        estimatedImpact: 'Significant battery life improvement',
      ));
    }

    return recommendations;
  }

  double _calculateOptimizationEffectiveness() {
    // Calculate how effective the optimizations have been
    final analytics = _batteryService.getCurrentAnalytics();
    return analytics.batteryHealthScore;
  }

  Future<void> _updateServiceConfigurations(
    BatteryOptimizationConfig oldConfig,
    BatteryOptimizationConfig newConfig,
  ) async {
    // Update power management config
    if (oldConfig.powerManagementConfig != newConfig.powerManagementConfig) {
      await _powerService.updateConfig(newConfig.powerManagementConfig);
    }

    // Update feature management config
    if (oldConfig.featureManagementConfig !=
        newConfig.featureManagementConfig) {
      await _featureManager.updateConfig(newConfig.featureManagementConfig);
    }

    // Update frequency config
    if (oldConfig.frequencyConfig != newConfig.frequencyConfig) {
      await _frequencyService.updateConfig(newConfig.frequencyConfig);
    }
  }

  Future<void> _stopAllServices() async {
    await _batteryService.stopMonitoring();
    await _powerService.stop();
    await _featureManager.stop();
    await _analyticsService.stop();
    await _taskManager.stop();
    await _frequencyService.stop();

    if (_adaptiveLocationService?.isActive == true) {
      await _adaptiveLocationService!.stop();
    }
  }

  void _emitEvent(BatteryOptimizationEvent event) {
    _eventController?.add(event);
    debugPrint('🔋 Event: ${event.description}');
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    stop();
    _batteryService.dispose();
    _powerService.dispose();
    _featureManager.dispose();
    _analyticsService.dispose();
    _taskManager.dispose();
    _frequencyService.dispose();
    _instance = null;
  }
}

/// Battery optimization configuration
class BatteryOptimizationConfig {
  const BatteryOptimizationConfig({
    required this.optimizationMode,
    required this.enableAutoOptimization,
    required this.enableIntelligentFrequency,
    required this.enableAdaptiveLocation,
    required this.coordinationIntervalMinutes,
    required this.powerManagementConfig,
    required this.featureManagementConfig,
    required this.frequencyConfig,
  });

  /// Default configuration
  factory BatteryOptimizationConfig.defaultConfig() =>
      BatteryOptimizationConfig(
        optimizationMode: OptimizationMode.balanced,
        enableAutoOptimization: true,
        enableIntelligentFrequency: true,
        enableAdaptiveLocation: true,
        coordinationIntervalMinutes: 10,
        powerManagementConfig: PowerManagementConfig.defaultConfig(),
        featureManagementConfig: AdaptiveFeatureConfig.defaultConfig(),
        frequencyConfig: FrequencyAlgorithmConfig.defaultConfig(),
      );

  final OptimizationMode optimizationMode;
  final bool enableAutoOptimization;
  final bool enableIntelligentFrequency;
  final bool enableAdaptiveLocation;
  final int coordinationIntervalMinutes;
  final PowerManagementConfig powerManagementConfig;
  final AdaptiveFeatureConfig featureManagementConfig;
  final FrequencyAlgorithmConfig frequencyConfig;

  BatteryOptimizationConfig copyWith({
    OptimizationMode? optimizationMode,
    bool? enableAutoOptimization,
    bool? enableIntelligentFrequency,
    bool? enableAdaptiveLocation,
    int? coordinationIntervalMinutes,
    PowerManagementConfig? powerManagementConfig,
    AdaptiveFeatureConfig? featureManagementConfig,
    FrequencyAlgorithmConfig? frequencyConfig,
  }) =>
      BatteryOptimizationConfig(
        optimizationMode: optimizationMode ?? this.optimizationMode,
        enableAutoOptimization:
            enableAutoOptimization ?? this.enableAutoOptimization,
        enableIntelligentFrequency:
            enableIntelligentFrequency ?? this.enableIntelligentFrequency,
        enableAdaptiveLocation:
            enableAdaptiveLocation ?? this.enableAdaptiveLocation,
        coordinationIntervalMinutes:
            coordinationIntervalMinutes ?? this.coordinationIntervalMinutes,
        powerManagementConfig:
            powerManagementConfig ?? this.powerManagementConfig,
        featureManagementConfig:
            featureManagementConfig ?? this.featureManagementConfig,
        frequencyConfig: frequencyConfig ?? this.frequencyConfig,
      );
}

/// Optimization modes
enum OptimizationMode {
  conservative,
  balanced,
  aggressive;

  String get name {
    switch (this) {
      case OptimizationMode.conservative:
        return 'Conservative';
      case OptimizationMode.balanced:
        return 'Balanced';
      case OptimizationMode.aggressive:
        return 'Aggressive';
    }
  }
}

/// Battery optimization event
class BatteryOptimizationEvent {
  const BatteryOptimizationEvent({
    required this.type,
    required this.description,
    required this.impact,
    required this.timestamp,
  });

  final OptimizationEventType type;
  final String description;
  final String impact;
  final DateTime timestamp;

  @override
  String toString() => 'BatteryOptimizationEvent(${type.name}: $description)';
}

/// Optimization event types
enum OptimizationEventType {
  systemStartup,
  configurationChange,
  powerModeChange,
  featureAdaptation,
  frequencyAdjustment,
  taskManagement,
  criticalBattery,
  healthAlert,
  manualOptimization;

  String get name {
    switch (this) {
      case OptimizationEventType.systemStartup:
        return 'System Startup';
      case OptimizationEventType.configurationChange:
        return 'Configuration Change';
      case OptimizationEventType.powerModeChange:
        return 'Power Mode Change';
      case OptimizationEventType.featureAdaptation:
        return 'Feature Adaptation';
      case OptimizationEventType.frequencyAdjustment:
        return 'Frequency Adjustment';
      case OptimizationEventType.taskManagement:
        return 'Task Management';
      case OptimizationEventType.criticalBattery:
        return 'Critical Battery';
      case OptimizationEventType.healthAlert:
        return 'Health Alert';
      case OptimizationEventType.manualOptimization:
        return 'Manual Optimization';
    }
  }
}

/// System health status
class SystemHealthStatus {
  const SystemHealthStatus({
    required this.overallHealth,
    required this.overallScore,
    required this.batteryHealth,
    required this.serviceStates,
    required this.activeOptimizations,
    required this.timestamp,
  });

  final SystemHealth overallHealth;
  final double overallScore;
  final BatteryHealthAssessment batteryHealth;
  final Map<String, ServiceState> serviceStates;
  final List<String> activeOptimizations;
  final DateTime timestamp;
}

/// System health levels
enum SystemHealth {
  critical,
  poor,
  fair,
  good,
  excellent;

  String get name {
    switch (this) {
      case SystemHealth.critical:
        return 'Critical';
      case SystemHealth.poor:
        return 'Poor';
      case SystemHealth.fair:
        return 'Fair';
      case SystemHealth.good:
        return 'Good';
      case SystemHealth.excellent:
        return 'Excellent';
    }
  }
}

/// Service state information
class ServiceState {
  const ServiceState({
    required this.serviceName,
    required this.isActive,
    required this.healthScore,
    required this.lastUpdate,
  });

  final String serviceName;
  final bool isActive;
  final double healthScore;
  final DateTime lastUpdate;
}

/// Comprehensive optimization report
class OptimizationReport {
  const OptimizationReport({
    required this.batteryReport,
    required this.systemHealth,
    required this.recommendations,
    required this.serviceStatus,
    required this.optimizationEffectiveness,
    required this.generatedAt,
  });

  final BatteryReport batteryReport;
  final SystemHealthStatus systemHealth;
  final List<SystemRecommendation> recommendations;
  final Map<String, ServiceState> serviceStatus;
  final double optimizationEffectiveness;
  final DateTime generatedAt;
}

/// System recommendation
class SystemRecommendation {
  const SystemRecommendation({
    required this.title,
    required this.description,
    required this.priority,
    required this.category,
    required this.estimatedImpact,
  });

  final String title;
  final String description;
  final RecommendationPriority priority;
  final RecommendationCategory category;
  final String estimatedImpact;
}

/// Recommendation priorities
enum RecommendationPriority {
  low,
  medium,
  high,
  critical;

  String get name {
    switch (this) {
      case RecommendationPriority.low:
        return 'Low';
      case RecommendationPriority.medium:
        return 'Medium';
      case RecommendationPriority.high:
        return 'High';
      case RecommendationPriority.critical:
        return 'Critical';
    }
  }
}

/// Recommendation categories
enum RecommendationCategory {
  optimization,
  configuration,
  maintenance,
  feature;

  String get name {
    switch (this) {
      case RecommendationCategory.optimization:
        return 'Optimization';
      case RecommendationCategory.configuration:
        return 'Configuration';
      case RecommendationCategory.maintenance:
        return 'Maintenance';
      case RecommendationCategory.feature:
        return 'Feature';
    }
  }
}
