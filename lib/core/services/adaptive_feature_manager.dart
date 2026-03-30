import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/battery_models.dart';
import 'package:obsession_tracker/core/models/intelligent_frequency_models.dart';
import 'package:obsession_tracker/core/services/battery_monitoring_service.dart';

/// Adaptive feature management service that intelligently enables/disables
/// app features based on battery level, usage patterns, and system conditions.
///
/// This service provides intelligent feature toggling to maximize battery life
/// while maintaining essential functionality based on user needs and context.
class AdaptiveFeatureManager {
  factory AdaptiveFeatureManager() => _instance ??= AdaptiveFeatureManager._();
  AdaptiveFeatureManager._();
  static AdaptiveFeatureManager? _instance;

  final BatteryMonitoringService _batteryService = BatteryMonitoringService();

  // Stream controllers
  StreamController<FeatureAdaptationEvent>? _adaptationController;
  StreamController<FeatureRecommendation>? _recommendationController;

  // Service state
  bool _isActive = false;
  AdaptiveFeatureConfig _config = AdaptiveFeatureConfig.defaultConfig();

  // Feature management
  final Map<String, FeatureState> _featureStates = {};
  final Map<String, FeatureUsageStats> _usageStats = {};
  final List<FeatureAdaptationRecord> _adaptationHistory =
      <FeatureAdaptationRecord>[];
  static const int _maxHistoryLength = 500;

  // Monitoring and adaptation
  Timer? _adaptationTimer;
  Timer? _usageAnalysisTimer;
  StreamSubscription<BatteryLevel>? _batterySubscription;

  // Context tracking
  bool _isInForeground = true;

  /// Stream of feature adaptation events
  Stream<FeatureAdaptationEvent> get adaptationStream {
    _adaptationController ??=
        StreamController<FeatureAdaptationEvent>.broadcast();
    return _adaptationController!.stream;
  }

  /// Stream of feature recommendations
  Stream<FeatureRecommendation> get recommendationStream {
    _recommendationController ??=
        StreamController<FeatureRecommendation>.broadcast();
    return _recommendationController!.stream;
  }

  /// Whether the service is active
  bool get isActive => _isActive;

  /// Current configuration
  AdaptiveFeatureConfig get config => _config;

  /// Current feature states
  Map<String, FeatureState> get featureStates => Map.from(_featureStates);

  /// Start adaptive feature management
  Future<void> start({
    AdaptiveFeatureConfig? config,
  }) async {
    try {
      await stop(); // Ensure clean start

      _config = config ?? AdaptiveFeatureConfig.defaultConfig();

      debugPrint('🎛️ Starting adaptive feature manager...');
      debugPrint('  Adaptation mode: ${_config.adaptationMode.name}');
      debugPrint('  Auto-adaptation enabled: ${_config.enableAutoAdaptation}');

      // Initialize stream controllers
      _adaptationController ??=
          StreamController<FeatureAdaptationEvent>.broadcast();
      _recommendationController ??=
          StreamController<FeatureRecommendation>.broadcast();

      // Initialize feature states
      await _initializeFeatureStates();

      // Subscribe to battery changes
      _subscribeToServices();

      // Start monitoring timers
      _startMonitoringTimers();

      _isActive = true;
      debugPrint('🎛️ Adaptive feature manager started successfully');
    } catch (e) {
      debugPrint('🎛️ Error starting adaptive feature manager: $e');
      rethrow;
    }
  }

  /// Stop adaptive feature management
  Future<void> stop() async {
    // Cancel subscriptions
    await _batterySubscription?.cancel();
    _batterySubscription = null;

    // Cancel timers
    _adaptationTimer?.cancel();
    _adaptationTimer = null;

    _usageAnalysisTimer?.cancel();
    _usageAnalysisTimer = null;

    // Close stream controllers
    await _adaptationController?.close();
    _adaptationController = null;

    await _recommendationController?.close();
    _recommendationController = null;

    _isActive = false;
    debugPrint('🎛️ Adaptive feature manager stopped');
  }

  /// Update configuration
  Future<void> updateConfig(AdaptiveFeatureConfig newConfig) async {
    _config = newConfig;
    debugPrint('🎛️ Configuration updated');

    // Re-evaluate features with new config
    if (_isActive) {
      await _performFeatureAdaptation();
    }
  }

  /// Manually enable/disable a feature
  Future<void> setFeatureEnabled(String featureId,
      {required bool enabled, String? reason}) async {
    if (!_isActive) return;

    final currentState = _featureStates[featureId];
    if (currentState?.isEnabled == enabled) return;

    await _updateFeatureState(featureId, enabled, reason ?? 'Manual override');
  }

  /// Get feature recommendations
  List<FeatureRecommendation> getFeatureRecommendations() =>
      _generateFeatureRecommendations();

  /// Apply feature recommendations
  Future<void> applyRecommendations(
      List<FeatureRecommendation> recommendations) async {
    for (final recommendation in recommendations) {
      if (recommendation.priority == FeaturePriority.high ||
          recommendation.priority == FeaturePriority.critical) {
        await _applyRecommendation(recommendation);
      }
    }
  }

  /// Record user activity for context awareness
  void recordUserActivity(String activityType) {
    // Update usage stats
    const featureId = 'user_activity';
    _updateUsageStats(featureId, activityType);
  }

  /// Update app foreground/background state
  void updateAppState({required bool isInForeground}) {
    _isInForeground = isInForeground;
    debugPrint(
        '🎛️ App state changed: ${isInForeground ? 'foreground' : 'background'}');

    // Trigger immediate adaptation for background state
    if (!isInForeground && _config.enableBackgroundOptimization) {
      _performFeatureAdaptation();
    }
  }

  /// Get feature usage statistics
  Map<String, FeatureUsageStats> getUsageStatistics() => Map.from(_usageStats);

  /// Get adaptation history
  List<FeatureAdaptationRecord> getAdaptationHistory({Duration? timeRange}) {
    var history = _adaptationHistory.toList();

    if (timeRange != null) {
      final cutoff = DateTime.now().subtract(timeRange);
      history =
          history.where((record) => record.timestamp.isAfter(cutoff)).toList();
    }

    return history;
  }

  Future<void> _initializeFeatureStates() async {
    // Initialize all managed features
    final features = [
      'gps_tracking',
      'background_location',
      'sensor_fusion',
      'compass',
      'accelerometer',
      'magnetometer',
      'barometer',
      'camera',
      'audio_recording',
      'map_rendering',
      'notifications',
      'data_sync',
      'analytics',
    ];

    for (final featureId in features) {
      _featureStates[featureId] = FeatureState(
        featureId: featureId,
        isEnabled: true,
        isEssential: _isEssentialFeature(featureId),
        lastModified: DateTime.now(),
        reason: 'Initial state',
      );

      _usageStats[featureId] = FeatureUsageStats(
        featureId: featureId,
        usageCount: 0,
        totalUsageTime: Duration.zero,
        lastUsed: DateTime.now(),
        averageSessionDuration: Duration.zero,
        batteryImpact: 0.0,
      );
    }

    debugPrint('🎛️ Initialized ${features.length} feature states');
  }

  bool _isEssentialFeature(String featureId) {
    const essentialFeatures = {
      'gps_tracking',
      'notifications',
    };
    return essentialFeatures.contains(featureId);
  }

  void _subscribeToServices() {
    // Subscribe to battery level changes
    _batterySubscription = _batteryService.batteryLevelStream.listen(
      _handleBatteryLevelChange,
      onError: (Object error) =>
          debugPrint('🎛️ Battery subscription error: $error'),
    );
  }

  void _startMonitoringTimers() {
    // Adaptation timer - check for needed adaptations
    _adaptationTimer = Timer.periodic(
      Duration(minutes: _config.adaptationIntervalMinutes),
      (_) => _performFeatureAdaptation(),
    );

    // Usage analysis timer - analyze feature usage patterns
    _usageAnalysisTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _analyzeFeatureUsage(),
    );
  }

  void _handleBatteryLevelChange(BatteryLevel batteryLevel) {
    debugPrint('🎛️ Battery level changed: ${batteryLevel.percentage}%');

    // Trigger immediate adaptation for critical battery levels
    if (batteryLevel.isCriticallyLow || batteryLevel.isLow) {
      _performFeatureAdaptation();
    }
  }

  Future<void> _performFeatureAdaptation() async {
    if (!_config.enableAutoAdaptation) return;

    debugPrint('🎛️ Performing feature adaptation...');

    final batteryLevel = _batteryService.currentBatteryLevel;
    if (batteryLevel == null) return;

    final recommendations = _generateFeatureRecommendations();
    final criticalRecommendations = recommendations
        .where((r) => r.priority == FeaturePriority.critical)
        .toList();

    // Apply critical recommendations immediately
    for (final recommendation in criticalRecommendations) {
      await _applyRecommendation(recommendation);
    }

    // Emit recommendations for user consideration
    if (_recommendationController != null) {
      recommendations.forEach(_recommendationController!.add);
    }

    debugPrint(
        '🎛️ Feature adaptation completed: ${criticalRecommendations.length} critical changes applied');
  }

  List<FeatureRecommendation> _generateFeatureRecommendations() {
    final recommendations = <FeatureRecommendation>[];
    final batteryLevel = _batteryService.currentBatteryLevel;

    if (batteryLevel == null) return recommendations;

    // Battery-based recommendations
    if (batteryLevel.isCriticallyLow) {
      recommendations.addAll(_getCriticalBatteryRecommendations());
    } else if (batteryLevel.isLow) {
      recommendations.addAll(_getLowBatteryRecommendations());
    }

    // Context-based recommendations
    if (!_isInForeground) {
      recommendations.addAll(_getBackgroundRecommendations());
    }

    // Usage-based recommendations
    recommendations.addAll(_getUsageBasedRecommendations());

    return recommendations;
  }

  List<FeatureRecommendation> _getCriticalBatteryRecommendations() => [
        const FeatureRecommendation(
          featureId: 'sensor_fusion',
          action: FeatureAction.disable,
          reason: 'Critical battery level - disable sensor fusion',
          priority: FeaturePriority.critical,
          expectedBatterySavings: 15.0,
          impactOnFunctionality: 'Reduced sensor accuracy',
        ),
        const FeatureRecommendation(
          featureId: 'background_location',
          action: FeatureAction.disable,
          reason: 'Critical battery level - disable background location',
          priority: FeaturePriority.critical,
          expectedBatterySavings: 20.0,
          impactOnFunctionality: 'No background tracking',
        ),
        const FeatureRecommendation(
          featureId: 'map_rendering',
          action: FeatureAction.disable,
          reason: 'Critical battery level - disable map rendering',
          priority: FeaturePriority.critical,
          expectedBatterySavings: 10.0,
          impactOnFunctionality: 'No map display',
        ),
      ];

  List<FeatureRecommendation> _getLowBatteryRecommendations() => [
        const FeatureRecommendation(
          featureId: 'camera',
          action: FeatureAction.disable,
          reason: 'Low battery level - disable camera features',
          priority: FeaturePriority.high,
          expectedBatterySavings: 12.0,
          impactOnFunctionality: 'No photo capture',
        ),
        const FeatureRecommendation(
          featureId: 'audio_recording',
          action: FeatureAction.disable,
          reason: 'Low battery level - disable audio recording',
          priority: FeaturePriority.high,
          expectedBatterySavings: 8.0,
          impactOnFunctionality: 'No voice notes',
        ),
      ];

  List<FeatureRecommendation> _getBackgroundRecommendations() => [
        const FeatureRecommendation(
          featureId: 'data_sync',
          action: FeatureAction.disable,
          reason: 'App in background - defer data synchronization',
          priority: FeaturePriority.medium,
          expectedBatterySavings: 5.0,
          impactOnFunctionality: 'Delayed sync',
        ),
        const FeatureRecommendation(
          featureId: 'analytics',
          action: FeatureAction.disable,
          reason: 'App in background - disable analytics',
          priority: FeaturePriority.low,
          expectedBatterySavings: 2.0,
          impactOnFunctionality: 'No usage analytics',
        ),
      ];

  List<FeatureRecommendation> _getUsageBasedRecommendations() {
    final recommendations = <FeatureRecommendation>[];
    final now = DateTime.now();

    // Check for unused features
    for (final entry in _usageStats.entries) {
      final featureId = entry.key;
      final stats = entry.value;
      final state = _featureStates[featureId];

      if (state?.isEnabled == true && !state!.isEssential) {
        final timeSinceLastUse = now.difference(stats.lastUsed);

        if (timeSinceLastUse.inHours > 24 && stats.usageCount < 5) {
          recommendations.add(FeatureRecommendation(
            featureId: featureId,
            action: FeatureAction.disable,
            reason: 'Feature unused for ${timeSinceLastUse.inHours} hours',
            priority: FeaturePriority.low,
            expectedBatterySavings: stats.batteryImpact,
            impactOnFunctionality: 'Feature will be unavailable',
          ));
        }
      }
    }

    return recommendations;
  }

  Future<void> _applyRecommendation(
      FeatureRecommendation recommendation) async {
    final enabled = recommendation.action == FeatureAction.enable;
    await _updateFeatureState(
      recommendation.featureId,
      enabled,
      recommendation.reason,
    );

    // Record adaptation
    _recordAdaptation(recommendation);
  }

  Future<void> _updateFeatureState(
      String featureId, bool enabled, String reason) async {
    final currentState = _featureStates[featureId];
    if (currentState?.isEnabled == enabled) return;

    _featureStates[featureId] = FeatureState(
      featureId: featureId,
      isEnabled: enabled,
      isEssential: currentState?.isEssential ?? false,
      lastModified: DateTime.now(),
      reason: reason,
    );

    // Emit adaptation event
    final event = FeatureAdaptationEvent(
      featureId: featureId,
      action: enabled ? FeatureAction.enable : FeatureAction.disable,
      reason: reason,
      timestamp: DateTime.now(),
    );
    _adaptationController?.add(event);

    debugPrint(
        '🎛️ Feature $featureId ${enabled ? 'enabled' : 'disabled'}: $reason');
  }

  void _updateUsageStats(String featureId, String activityType) {
    final currentStats = _usageStats[featureId];
    if (currentStats == null) return;

    _usageStats[featureId] = FeatureUsageStats(
      featureId: featureId,
      usageCount: currentStats.usageCount + 1,
      totalUsageTime: currentStats.totalUsageTime +
          const Duration(minutes: 1), // Simplified
      lastUsed: DateTime.now(),
      averageSessionDuration: currentStats.averageSessionDuration,
      batteryImpact: currentStats.batteryImpact,
    );
  }

  void _recordAdaptation(FeatureRecommendation recommendation) {
    final record = FeatureAdaptationRecord(
      featureId: recommendation.featureId,
      action: recommendation.action,
      reason: recommendation.reason,
      priority: recommendation.priority,
      expectedBatterySavings: recommendation.expectedBatterySavings,
      timestamp: DateTime.now(),
    );

    _adaptationHistory.add(record);
    if (_adaptationHistory.length > _maxHistoryLength) {
      _adaptationHistory.removeAt(0);
    }
  }

  void _analyzeFeatureUsage() {
    debugPrint('🎛️ Analyzing feature usage patterns...');

    // Update battery impact estimates based on actual usage
    for (final entry in _usageStats.entries) {
      final featureId = entry.key;
      final stats = entry.value;

      // Estimate battery impact based on usage frequency and type
      final batteryImpact = _estimateFeatureBatteryImpact(featureId, stats);

      _usageStats[featureId] = FeatureUsageStats(
        featureId: featureId,
        usageCount: stats.usageCount,
        totalUsageTime: stats.totalUsageTime,
        lastUsed: stats.lastUsed,
        averageSessionDuration: stats.averageSessionDuration,
        batteryImpact: batteryImpact,
      );
    }

    debugPrint('🎛️ Feature usage analysis completed');
  }

  double _estimateFeatureBatteryImpact(
      String featureId, FeatureUsageStats stats) {
    // Base impact estimates for different feature types
    const baseImpacts = {
      'gps_tracking': 15.0,
      'background_location': 12.0,
      'sensor_fusion': 8.0,
      'camera': 20.0,
      'audio_recording': 10.0,
      'map_rendering': 6.0,
      'compass': 3.0,
      'accelerometer': 2.0,
      'magnetometer': 2.0,
      'barometer': 1.0,
      'notifications': 1.0,
      'data_sync': 4.0,
      'analytics': 1.0,
    };

    final baseImpact = baseImpacts[featureId] ?? 2.0;

    // Adjust based on usage frequency
    final usageMultiplier = math.min(2.0, stats.usageCount / 100.0);

    return baseImpact * (1.0 + usageMultiplier);
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    stop();
    _featureStates.clear();
    _usageStats.clear();
    _adaptationHistory.clear();
    _instance = null;
  }
}

/// Configuration for adaptive feature management
class AdaptiveFeatureConfig {
  const AdaptiveFeatureConfig({
    required this.adaptationMode,
    required this.enableAutoAdaptation,
    required this.enableBackgroundOptimization,
    required this.adaptationIntervalMinutes,
    required this.batteryThresholds,
    required this.usageThresholds,
  });

  /// Default configuration
  factory AdaptiveFeatureConfig.defaultConfig() => const AdaptiveFeatureConfig(
        adaptationMode: AdaptationMode.balanced,
        enableAutoAdaptation: true,
        enableBackgroundOptimization: true,
        adaptationIntervalMinutes: 5,
        batteryThresholds: BatteryThresholds(
          critical: 15,
          low: 30,
          normal: 50,
          high: 80,
        ),
        usageThresholds: UsageThresholds(
          minUsageCount: 5,
          maxUnusedHours: 24,
          minSessionDuration: Duration(minutes: 1),
        ),
      );

  final AdaptationMode adaptationMode;
  final bool enableAutoAdaptation;
  final bool enableBackgroundOptimization;
  final int adaptationIntervalMinutes;
  final BatteryThresholds batteryThresholds;
  final UsageThresholds usageThresholds;

  AdaptiveFeatureConfig copyWith({
    AdaptationMode? adaptationMode,
    bool? enableAutoAdaptation,
    bool? enableBackgroundOptimization,
    int? adaptationIntervalMinutes,
    BatteryThresholds? batteryThresholds,
    UsageThresholds? usageThresholds,
  }) =>
      AdaptiveFeatureConfig(
        adaptationMode: adaptationMode ?? this.adaptationMode,
        enableAutoAdaptation: enableAutoAdaptation ?? this.enableAutoAdaptation,
        enableBackgroundOptimization:
            enableBackgroundOptimization ?? this.enableBackgroundOptimization,
        adaptationIntervalMinutes:
            adaptationIntervalMinutes ?? this.adaptationIntervalMinutes,
        batteryThresholds: batteryThresholds ?? this.batteryThresholds,
        usageThresholds: usageThresholds ?? this.usageThresholds,
      );
}

/// Usage thresholds for feature adaptation
class UsageThresholds {
  const UsageThresholds({
    required this.minUsageCount,
    required this.maxUnusedHours,
    required this.minSessionDuration,
  });

  final int minUsageCount;
  final int maxUnusedHours;
  final Duration minSessionDuration;
}

/// Adaptation modes
enum AdaptationMode {
  conservative,
  balanced,
  aggressive;

  String get name {
    switch (this) {
      case AdaptationMode.conservative:
        return 'Conservative';
      case AdaptationMode.balanced:
        return 'Balanced';
      case AdaptationMode.aggressive:
        return 'Aggressive';
    }
  }

  String get description {
    switch (this) {
      case AdaptationMode.conservative:
        return 'Minimal feature changes, prioritize functionality';
      case AdaptationMode.balanced:
        return 'Balanced approach between battery and functionality';
      case AdaptationMode.aggressive:
        return 'Maximum battery savings, may impact functionality';
    }
  }
}

/// Feature state information
class FeatureState {
  const FeatureState({
    required this.featureId,
    required this.isEnabled,
    required this.isEssential,
    required this.lastModified,
    required this.reason,
  });

  final String featureId;
  final bool isEnabled;
  final bool isEssential;
  final DateTime lastModified;
  final String reason;

  @override
  String toString() =>
      'FeatureState($featureId: ${isEnabled ? 'enabled' : 'disabled'})';
}

/// Feature usage statistics
class FeatureUsageStats {
  const FeatureUsageStats({
    required this.featureId,
    required this.usageCount,
    required this.totalUsageTime,
    required this.lastUsed,
    required this.averageSessionDuration,
    required this.batteryImpact,
  });

  final String featureId;
  final int usageCount;
  final Duration totalUsageTime;
  final DateTime lastUsed;
  final Duration averageSessionDuration;
  final double batteryImpact;
}

/// Feature recommendation
class FeatureRecommendation {
  const FeatureRecommendation({
    required this.featureId,
    required this.action,
    required this.reason,
    required this.priority,
    required this.expectedBatterySavings,
    required this.impactOnFunctionality,
  });

  final String featureId;
  final FeatureAction action;
  final String reason;
  final FeaturePriority priority;
  final double expectedBatterySavings;
  final String impactOnFunctionality;

  @override
  String toString() =>
      'FeatureRecommendation($featureId: ${action.name}, ${priority.name})';
}

/// Feature actions
enum FeatureAction {
  enable,
  disable,
  optimize;

  String get name {
    switch (this) {
      case FeatureAction.enable:
        return 'Enable';
      case FeatureAction.disable:
        return 'Disable';
      case FeatureAction.optimize:
        return 'Optimize';
    }
  }
}

/// Feature priorities
enum FeaturePriority {
  low,
  medium,
  high,
  critical;

  String get name {
    switch (this) {
      case FeaturePriority.low:
        return 'Low';
      case FeaturePriority.medium:
        return 'Medium';
      case FeaturePriority.high:
        return 'High';
      case FeaturePriority.critical:
        return 'Critical';
    }
  }
}

/// Feature adaptation event
class FeatureAdaptationEvent {
  const FeatureAdaptationEvent({
    required this.featureId,
    required this.action,
    required this.reason,
    required this.timestamp,
  });

  final String featureId;
  final FeatureAction action;
  final String reason;
  final DateTime timestamp;

  @override
  String toString() => 'FeatureAdaptationEvent($featureId: ${action.name})';
}

/// Feature adaptation record
class FeatureAdaptationRecord {
  const FeatureAdaptationRecord({
    required this.featureId,
    required this.action,
    required this.reason,
    required this.priority,
    required this.expectedBatterySavings,
    required this.timestamp,
  });

  final String featureId;
  final FeatureAction action;
  final String reason;
  final FeaturePriority priority;
  final double expectedBatterySavings;
  final DateTime timestamp;
}
