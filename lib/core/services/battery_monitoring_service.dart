import 'dart:async';
import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/battery_models.dart';

/// Comprehensive battery monitoring and analytics service
///
/// Provides real-time battery monitoring, usage tracking, analytics,
/// and intelligent power management recommendations for optimal battery life.
class BatteryMonitoringService {
  factory BatteryMonitoringService() =>
      _instance ??= BatteryMonitoringService._();
  BatteryMonitoringService._();
  static BatteryMonitoringService? _instance;

  final Battery _battery = Battery();

  // Stream controllers
  StreamController<BatteryLevel>? _batteryLevelController;
  StreamController<BatteryAnalytics>? _analyticsController;
  StreamController<BatteryHealthAssessment>? _healthController;

  // Service state
  bool _isMonitoring = false;
  BatteryLevel? _currentBatteryLevel;
  PowerManagementConfig _config = PowerManagementConfig.defaultConfig();

  // Usage tracking
  final List<BatteryUsageEntry> _usageHistory = <BatteryUsageEntry>[];
  final Map<ServiceType, DateTime> _serviceStartTimes = {};
  final Map<ServiceType, int> _serviceStartBatteryLevels = {};
  static const int _maxUsageHistoryLength = 1000;

  // Monitoring timers
  Timer? _batteryMonitorTimer;
  Timer? _analyticsTimer;
  Timer? _healthAssessmentTimer;
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  // Analytics data
  DateTime _monitoringStartTime = DateTime.now();
  int _totalBatteryReadings = 0;

  /// Stream of battery level updates
  Stream<BatteryLevel> get batteryLevelStream {
    _batteryLevelController ??= StreamController<BatteryLevel>.broadcast();
    return _batteryLevelController!.stream;
  }

  /// Stream of battery analytics updates
  Stream<BatteryAnalytics> get analyticsStream {
    _analyticsController ??= StreamController<BatteryAnalytics>.broadcast();
    return _analyticsController!.stream;
  }

  /// Stream of battery health assessments
  Stream<BatteryHealthAssessment> get healthStream {
    _healthController ??= StreamController<BatteryHealthAssessment>.broadcast();
    return _healthController!.stream;
  }

  /// Current battery level
  BatteryLevel? get currentBatteryLevel => _currentBatteryLevel;

  /// Whether monitoring is active
  bool get isMonitoring => _isMonitoring;

  /// Current power management configuration
  PowerManagementConfig get config => _config;

  /// Total usage entries recorded
  int get totalUsageEntries => _usageHistory.length;

  /// Start battery monitoring
  Future<void> startMonitoring({
    PowerManagementConfig? config,
    Duration batteryCheckInterval = const Duration(seconds: 30),
    Duration analyticsInterval = const Duration(minutes: 5),
    Duration healthCheckInterval = const Duration(minutes: 15),
  }) async {
    try {
      await stopMonitoring(); // Ensure clean start

      _config = config ?? PowerManagementConfig.defaultConfig();
      _monitoringStartTime = DateTime.now();
      debugPrint('Battery monitoring started at $_monitoringStartTime');

      debugPrint('🔋 Starting battery monitoring service...');
      debugPrint('  Power mode: ${_config.mode.name}');
      debugPrint('  Auto-switch enabled: ${_config.autoSwitchEnabled}');

      // Initialize stream controllers
      _batteryLevelController ??= StreamController<BatteryLevel>.broadcast();
      _analyticsController ??= StreamController<BatteryAnalytics>.broadcast();
      _healthController ??=
          StreamController<BatteryHealthAssessment>.broadcast();

      // Get initial battery level
      await _updateBatteryLevel();

      // Start periodic battery monitoring
      _batteryMonitorTimer = Timer.periodic(batteryCheckInterval, (_) {
        _updateBatteryLevel();
      });

      // Subscribe to battery state changes
      _batteryStateSubscription = _battery.onBatteryStateChanged.listen(
        _handleBatteryStateChange,
        onError: (Object error) {
          debugPrint('🔋 Battery state subscription error: $error');
        },
      );

      // Start analytics generation
      _analyticsTimer = Timer.periodic(analyticsInterval, (_) {
        _generateAnalytics();
      });

      // Start health assessments
      _healthAssessmentTimer = Timer.periodic(healthCheckInterval, (_) {
        _performHealthAssessment();
      });

      _isMonitoring = true;
      debugPrint('🔋 Battery monitoring service started successfully');
    } catch (e) {
      debugPrint('🔋 Error starting battery monitoring service: $e');
      rethrow;
    }
  }

  /// Stop battery monitoring
  Future<void> stopMonitoring() async {
    // Cancel timers
    _batteryMonitorTimer?.cancel();
    _batteryMonitorTimer = null;

    _analyticsTimer?.cancel();
    _analyticsTimer = null;

    _healthAssessmentTimer?.cancel();
    _healthAssessmentTimer = null;

    // Cancel subscriptions
    await _batteryStateSubscription?.cancel();
    _batteryStateSubscription = null;

    // Close stream controllers
    await _batteryLevelController?.close();
    _batteryLevelController = null;

    await _analyticsController?.close();
    _analyticsController = null;

    await _healthController?.close();
    _healthController = null;

    _isMonitoring = false;
    debugPrint('🔋 Battery monitoring service stopped');
  }

  /// Update power management configuration
  Future<void> updateConfig(PowerManagementConfig newConfig) async {
    _config = newConfig;
    debugPrint('🔋 Power management config updated: ${newConfig.mode.name}');

    // Trigger immediate health assessment with new config
    if (_isMonitoring) {
      _performHealthAssessment();
    }
  }

  /// Start tracking battery usage for a specific service
  void startServiceTracking(ServiceType serviceType) {
    if (!_isMonitoring) return;

    final now = DateTime.now();
    final currentLevel = _currentBatteryLevel?.percentage ?? 100;

    _serviceStartTimes[serviceType] = now;
    _serviceStartBatteryLevels[serviceType] = currentLevel;

    debugPrint('🔋 Started tracking ${serviceType.displayName}');
  }

  /// Stop tracking battery usage for a specific service
  void stopServiceTracking(ServiceType serviceType,
      {Map<String, dynamic>? additionalData}) {
    if (!_isMonitoring) return;

    final startTime = _serviceStartTimes[serviceType];
    final startBatteryLevel = _serviceStartBatteryLevels[serviceType];

    if (startTime == null || startBatteryLevel == null) {
      debugPrint(
          '🔋 Warning: No start tracking data for ${serviceType.displayName}');
      return;
    }

    final now = DateTime.now();
    final currentLevel = _currentBatteryLevel?.percentage ?? 100;
    final estimatedUsage = _calculateServiceUsage(serviceType, startTime, now);

    final usageEntry = BatteryUsageEntry(
      featureName: serviceType.displayName,
      serviceType: serviceType,
      startTime: startTime,
      endTime: now,
      startBatteryLevel: startBatteryLevel,
      endBatteryLevel: currentLevel,
      estimatedUsagePercent: estimatedUsage,
      powerMode: _config.mode,
      additionalData: additionalData ?? {},
    );

    _usageHistory.add(usageEntry);
    if (_usageHistory.length > _maxUsageHistoryLength) {
      _usageHistory.removeAt(0);
    }

    // Clean up tracking data
    _serviceStartTimes.remove(serviceType);
    _serviceStartBatteryLevels.remove(serviceType);

    debugPrint(
        '🔋 Stopped tracking ${serviceType.displayName}: ${estimatedUsage.toStringAsFixed(2)}%');
  }

  /// Get current battery analytics
  BatteryAnalytics getCurrentAnalytics() => _generateAnalyticsData();

  /// Get current battery health assessment
  BatteryHealthAssessment getCurrentHealthAssessment() =>
      _generateHealthAssessment();

  /// Get usage history for a specific service
  List<BatteryUsageEntry> getServiceUsageHistory(ServiceType serviceType) =>
      _usageHistory.where((entry) => entry.serviceType == serviceType).toList();

  /// Get usage history within a time range
  List<BatteryUsageEntry> getUsageHistoryInRange(
          DateTime start, DateTime end) =>
      _usageHistory
          .where((entry) =>
              entry.startTime.isAfter(start) && entry.endTime.isBefore(end))
          .toList();

  /// Clear usage history
  void clearUsageHistory() {
    _usageHistory.clear();
    debugPrint('🔋 Usage history cleared');
  }

  /// Get estimated remaining battery time
  Duration? getEstimatedRemainingTime() {
    if (_currentBatteryLevel == null || _usageHistory.isEmpty) return null;

    final currentLevel = _currentBatteryLevel!.percentage;
    if (currentLevel <= 0) return Duration.zero;

    // Calculate average usage rate from recent history
    final recentEntries = _usageHistory
        .where((entry) => DateTime.now().difference(entry.endTime).inHours < 24)
        .toList();

    if (recentEntries.isEmpty) return null;

    final totalUsage = recentEntries.fold<double>(
      0.0,
      (sum, entry) => sum + entry.estimatedUsagePercent,
    );

    final totalTime = recentEntries.fold<Duration>(
      Duration.zero,
      (sum, entry) => sum + entry.duration,
    );

    if (totalTime.inMilliseconds == 0) return null;

    final usageRatePerHour =
        totalUsage / (totalTime.inMilliseconds / (1000 * 60 * 60));
    if (usageRatePerHour <= 0) return null;

    final remainingHours = currentLevel / usageRatePerHour;
    return Duration(milliseconds: (remainingHours * 60 * 60 * 1000).round());
  }

  Future<void> _updateBatteryLevel() async {
    try {
      final batteryLevel = await _battery.batteryLevel;
      final batteryState = await _battery.batteryState;
      final isCharging = batteryState == BatteryState.charging;

      final chargingState = _mapBatteryState(batteryState);

      final newBatteryLevel = BatteryLevel(
        percentage: batteryLevel,
        isCharging: isCharging,
        chargingState: chargingState,
        timestamp: DateTime.now(),
      );

      // Track battery drain
      if (_currentBatteryLevel != null && !isCharging) {
        final drain = _currentBatteryLevel!.percentage - batteryLevel;
        if (drain > 0) {}
      }

      _currentBatteryLevel = newBatteryLevel;
      _totalBatteryReadings++;
      if (_totalBatteryReadings % 100 == 0) {
        debugPrint('Battery readings collected: $_totalBatteryReadings');
      }

      // Emit battery level update
      _batteryLevelController?.add(newBatteryLevel);

      // Check for auto power mode switching
      if (_config.autoSwitchEnabled) {
        await _checkAutoModeSwitch(batteryLevel);
      }
    } catch (e) {
      debugPrint('🔋 Error updating battery level: $e');
    }
  }

  void _handleBatteryStateChange(BatteryState state) {
    debugPrint('🔋 Battery state changed: ${state.name}');
    _updateBatteryLevel();
  }

  BatteryChargingState _mapBatteryState(BatteryState state) {
    switch (state) {
      case BatteryState.charging:
        return BatteryChargingState.charging;
      case BatteryState.discharging:
        return BatteryChargingState.discharging;
      case BatteryState.full:
        return BatteryChargingState.full;
      case BatteryState.unknown:
        return BatteryChargingState.unknown;
      default:
        return BatteryChargingState.unknown;
    }
  }

  Future<void> _checkAutoModeSwitch(int batteryLevel) async {
    PowerMode? newMode;

    if (batteryLevel <= _config.autoSwitchToUltraSaver &&
        _config.mode != PowerMode.ultraBatterySaver) {
      newMode = PowerMode.ultraBatterySaver;
    } else if (batteryLevel <= _config.autoSwitchToBatterySaver &&
        _config.mode != PowerMode.batterySaver) {
      newMode = PowerMode.batterySaver;
    } else if (batteryLevel > _config.lowBatteryThreshold &&
        _config.mode == PowerMode.ultraBatterySaver) {
      newMode = PowerMode.batterySaver;
    } else if (batteryLevel > 50 && _config.mode == PowerMode.batterySaver) {
      newMode = PowerMode.balanced;
    }

    if (newMode != null) {
      debugPrint(
          '🔋 Auto-switching power mode: ${_config.mode.name} → ${newMode.name}');
      await updateConfig(_config.copyWith(mode: newMode));
    }
  }

  double _calculateServiceUsage(
      ServiceType serviceType, DateTime startTime, DateTime endTime) {
    final duration = endTime.difference(startTime);
    final hours = duration.inMilliseconds / (1000 * 60 * 60);

    // Base consumption rate adjusted by power mode
    double baseRate = serviceType.basePowerConsumption;

    // Adjust for power mode
    switch (_config.mode) {
      case PowerMode.highPerformance:
        baseRate *= 1.5;
        break;
      case PowerMode.balanced:
        baseRate *= 1.0;
        break;
      case PowerMode.batterySaver:
        baseRate *= 0.7;
        break;
      case PowerMode.ultraBatterySaver:
        baseRate *= 0.4;
        break;
    }

    return baseRate * hours / 100; // Convert to percentage
  }

  void _generateAnalytics() {
    final analytics = _generateAnalyticsData();
    _analyticsController?.add(analytics);
  }

  BatteryAnalytics _generateAnalyticsData() {
    if (_usageHistory.isEmpty) {
      return BatteryAnalytics(
        totalUsageEntries: 0,
        averageUsagePerHour: 0.0,
        peakUsagePerHour: 0.0,
        mostPowerHungryService: ServiceType.gpsTracking,
        totalTrackingTime: Duration.zero,
        estimatedRemainingTime: null,
        usageByService: {},
        usageByPowerMode: {},
        batteryHealthScore: 100.0,
        optimizationSuggestions: [],
        generatedAt: DateTime.now(),
      );
    }

    // Calculate usage statistics
    final totalUsage = _usageHistory.fold<double>(
      0.0,
      (sum, entry) => sum + entry.estimatedUsagePercent,
    );

    final totalTime = _usageHistory.fold<Duration>(
      Duration.zero,
      (sum, entry) => sum + entry.duration,
    );

    final averageUsagePerHour = totalTime.inMilliseconds > 0
        ? totalUsage / (totalTime.inMilliseconds / (1000 * 60 * 60))
        : 0.0;

    // Find peak usage
    final peakUsagePerHour = _usageHistory.isEmpty
        ? 0.0
        : _usageHistory.map((e) => e.usageRatePerHour).reduce(math.max);

    // Usage by service
    final usageByService = <ServiceType, double>{};
    for (final serviceType in ServiceType.values) {
      final serviceEntries =
          _usageHistory.where((e) => e.serviceType == serviceType);
      final serviceUsage = serviceEntries.fold<double>(
        0.0,
        (sum, entry) => sum + entry.estimatedUsagePercent,
      );
      if (serviceUsage > 0) {
        usageByService[serviceType] = serviceUsage;
      }
    }

    // Most power hungry service
    final mostPowerHungryService = usageByService.isNotEmpty
        ? usageByService.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : ServiceType.gpsTracking;

    // Usage by power mode
    final usageByPowerMode = <PowerMode, double>{};
    for (final mode in PowerMode.values) {
      final modeEntries = _usageHistory.where((e) => e.powerMode == mode);
      final modeUsage = modeEntries.fold<double>(
        0.0,
        (sum, entry) => sum + entry.estimatedUsagePercent,
      );
      if (modeUsage > 0) {
        usageByPowerMode[mode] = modeUsage;
      }
    }

    // Battery health score
    final healthScore = _calculateBatteryHealthScore();

    // Optimization suggestions
    final suggestions =
        _generateOptimizationSuggestions(usageByService, averageUsagePerHour);

    return BatteryAnalytics(
      totalUsageEntries: _usageHistory.length,
      averageUsagePerHour: averageUsagePerHour,
      peakUsagePerHour: peakUsagePerHour,
      mostPowerHungryService: mostPowerHungryService,
      totalTrackingTime: totalTime,
      estimatedRemainingTime: getEstimatedRemainingTime(),
      usageByService: usageByService,
      usageByPowerMode: usageByPowerMode,
      batteryHealthScore: healthScore,
      optimizationSuggestions: suggestions,
      generatedAt: DateTime.now(),
    );
  }

  void _performHealthAssessment() {
    final assessment = _generateHealthAssessment();
    _healthController?.add(assessment);
  }

  BatteryHealthAssessment _generateHealthAssessment() {
    final usageEfficiency = _calculateUsageEfficiency();
    final powerModeOptimization = _calculatePowerModeOptimization();
    final serviceOptimization = _calculateServiceOptimization();
    final backgroundProcessingScore = _calculateBackgroundProcessingScore();

    final overallScore = (usageEfficiency +
            powerModeOptimization +
            serviceOptimization +
            backgroundProcessingScore) /
        4;

    final recommendations = _generateHealthRecommendations(
      usageEfficiency,
      powerModeOptimization,
      serviceOptimization,
      backgroundProcessingScore,
    );

    return BatteryHealthAssessment(
      overallScore: overallScore,
      usageEfficiency: usageEfficiency,
      powerModeOptimization: powerModeOptimization,
      serviceOptimization: serviceOptimization,
      backgroundProcessingScore: backgroundProcessingScore,
      recommendations: recommendations,
      assessmentTime: DateTime.now(),
    );
  }

  double _calculateBatteryHealthScore() {
    if (_usageHistory.isEmpty) return 100.0;

    double score = 100.0;

    // Penalize high usage rates
    final analytics = _generateAnalyticsData();
    if (analytics.averageUsagePerHour > 10.0) {
      score -= (analytics.averageUsagePerHour - 10.0) * 2;
    }

    // Reward balanced power mode usage
    final balancedModeUsage =
        analytics.usageByPowerMode[PowerMode.balanced] ?? 0.0;
    final totalUsage = analytics.usageByPowerMode.values
        .fold<double>(0.0, (sum, usage) => sum + usage);
    if (totalUsage > 0) {
      final balancedRatio = balancedModeUsage / totalUsage;
      score += balancedRatio * 10;
    }

    return math.max(0.0, math.min(100.0, score));
  }

  double _calculateUsageEfficiency() {
    if (_usageHistory.isEmpty) return 100.0;

    final averageUsage = _usageHistory.fold<double>(
          0.0,
          (sum, entry) => sum + entry.usageRatePerHour,
        ) /
        _usageHistory.length;

    // Efficient usage is considered < 8% per hour
    if (averageUsage <= 8.0) return 100.0;
    if (averageUsage <= 12.0) return 80.0;
    if (averageUsage <= 16.0) return 60.0;
    if (averageUsage <= 20.0) return 40.0;
    return 20.0;
  }

  double _calculatePowerModeOptimization() {
    final currentLevel = _currentBatteryLevel?.percentage ?? 100;

    // Check if power mode is appropriate for battery level
    switch (_config.mode) {
      case PowerMode.highPerformance:
        return currentLevel > 50 ? 100.0 : 30.0;
      case PowerMode.balanced:
        return currentLevel > 30 ? 100.0 : 70.0;
      case PowerMode.batterySaver:
        return currentLevel <= 50 ? 100.0 : 80.0;
      case PowerMode.ultraBatterySaver:
        return currentLevel <= 20 ? 100.0 : 60.0;
    }
  }

  double _calculateServiceOptimization() =>
      // This would analyze which services are running and their necessity
      // For now, return a baseline score
      80.0;

  double _calculateBackgroundProcessingScore() =>
      // This would analyze background processing efficiency
      // For now, return a baseline score
      85.0;

  List<BatteryOptimizationSuggestion> _generateOptimizationSuggestions(
    Map<ServiceType, double> usageByService,
    double averageUsagePerHour,
  ) {
    final suggestions = <BatteryOptimizationSuggestion>[];

    // High usage rate suggestion
    if (averageUsagePerHour > 15.0) {
      suggestions.add(const BatteryOptimizationSuggestion(
        type: OptimizationType.switchPowerMode,
        title: 'Switch to Battery Saver Mode',
        description:
            'Your current usage rate is high. Consider switching to Battery Saver mode.',
        estimatedSavings: 25.0,
        priority: OptimizationPriority.high,
        actionRequired: 'Change power mode in settings',
      ));
    }

    // GPS frequency suggestion
    final gpsUsage = usageByService[ServiceType.gpsTracking] ?? 0.0;
    if (gpsUsage > 30.0) {
      suggestions.add(const BatteryOptimizationSuggestion(
        type: OptimizationType.reduceGpsFrequency,
        title: 'Reduce GPS Update Frequency',
        description:
            'GPS tracking is consuming significant battery. Consider reducing update frequency.',
        estimatedSavings: 15.0,
        priority: OptimizationPriority.medium,
        actionRequired: 'Adjust GPS settings or enable adaptive tracking',
      ));
    }

    // Sensor optimization
    final sensorUsage = (usageByService[ServiceType.sensorFusion] ?? 0.0) +
        (usageByService[ServiceType.accelerometer] ?? 0.0) +
        (usageByService[ServiceType.magnetometer] ?? 0.0);
    if (sensorUsage > 20.0) {
      suggestions.add(const BatteryOptimizationSuggestion(
        type: OptimizationType.disableUnusedSensors,
        title: 'Optimize Sensor Usage',
        description:
            'Multiple sensors are active. Disable unused sensors to save battery.',
        estimatedSavings: 10.0,
        priority: OptimizationPriority.medium,
        actionRequired: 'Review and disable unnecessary sensors',
      ));
    }

    return suggestions;
  }

  List<String> _generateHealthRecommendations(
    double usageEfficiency,
    double powerModeOptimization,
    double serviceOptimization,
    double backgroundProcessingScore,
  ) {
    final recommendations = <String>[];

    if (usageEfficiency < 70.0) {
      recommendations.add(
          'Consider reducing GPS update frequency or switching to a more efficient power mode');
    }

    if (powerModeOptimization < 70.0) {
      recommendations.add(
          'Your current power mode may not be optimal for your battery level');
    }

    if (serviceOptimization < 70.0) {
      recommendations
          .add('Review active services and disable unnecessary features');
    }

    if (backgroundProcessingScore < 70.0) {
      recommendations
          .add('Optimize background processing to improve battery life');
    }

    if (recommendations.isEmpty) {
      recommendations.add('Your battery usage is well optimized');
    }

    return recommendations;
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    stopMonitoring();
    _usageHistory.clear();
    _serviceStartTimes.clear();
    _serviceStartBatteryLevels.clear();
    _instance = null;
  }
}
