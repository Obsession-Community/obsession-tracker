/// Battery monitoring and optimization models
///
/// Provides comprehensive battery tracking, usage analytics, and power management
/// for the Obsession Tracker app.

import 'package:flutter/foundation.dart';

/// Battery level information
@immutable
class BatteryLevel {
  const BatteryLevel({
    required this.percentage,
    required this.isCharging,
    required this.chargingState,
    required this.timestamp,
  });

  final int percentage;
  final bool isCharging;
  final BatteryChargingState chargingState;
  final DateTime timestamp;

  /// Whether battery is critically low (< 15%)
  bool get isCriticallyLow => percentage < 15;

  /// Whether battery is low (< 30%)
  bool get isLow => percentage < 30;

  /// Whether battery is healthy (> 50%)
  bool get isHealthy => percentage > 50;

  @override
  String toString() => 'BatteryLevel($percentage%, charging: $isCharging)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatteryLevel &&
          runtimeType == other.runtimeType &&
          percentage == other.percentage &&
          isCharging == other.isCharging &&
          chargingState == other.chargingState;

  @override
  int get hashCode =>
      percentage.hashCode ^ isCharging.hashCode ^ chargingState.hashCode;
}

/// Battery charging states
enum BatteryChargingState {
  unknown,
  charging,
  discharging,
  notCharging,
  full;

  String get description {
    switch (this) {
      case BatteryChargingState.unknown:
        return 'Unknown';
      case BatteryChargingState.charging:
        return 'Charging';
      case BatteryChargingState.discharging:
        return 'Discharging';
      case BatteryChargingState.notCharging:
        return 'Not Charging';
      case BatteryChargingState.full:
        return 'Full';
    }
  }
}

/// Power management modes
enum PowerMode {
  highPerformance,
  balanced,
  batterySaver,
  ultraBatterySaver;

  String get name {
    switch (this) {
      case PowerMode.highPerformance:
        return 'High Performance';
      case PowerMode.balanced:
        return 'Balanced';
      case PowerMode.batterySaver:
        return 'Battery Saver';
      case PowerMode.ultraBatterySaver:
        return 'Ultra Battery Saver';
    }
  }

  String get description {
    switch (this) {
      case PowerMode.highPerformance:
        return 'Maximum accuracy and features, higher battery usage';
      case PowerMode.balanced:
        return 'Optimal balance of features and battery life';
      case PowerMode.batterySaver:
        return 'Reduced features and frequency for longer battery life';
      case PowerMode.ultraBatterySaver:
        return 'Minimal features, maximum battery conservation';
    }
  }

  /// Get recommended GPS update interval in seconds
  int get gpsUpdateInterval {
    switch (this) {
      case PowerMode.highPerformance:
        return 5;
      case PowerMode.balanced:
        return 15;
      case PowerMode.batterySaver:
        return 60;
      case PowerMode.ultraBatterySaver:
        return 300;
    }
  }

  /// Get recommended sensor update frequency
  Duration get sensorUpdateFrequency {
    switch (this) {
      case PowerMode.highPerformance:
        return const Duration(milliseconds: 100);
      case PowerMode.balanced:
        return const Duration(milliseconds: 500);
      case PowerMode.batterySaver:
        return const Duration(seconds: 2);
      case PowerMode.ultraBatterySaver:
        return const Duration(seconds: 10);
    }
  }

  /// Whether background processing should be limited
  bool get limitBackgroundProcessing {
    switch (this) {
      case PowerMode.highPerformance:
      case PowerMode.balanced:
        return false;
      case PowerMode.batterySaver:
      case PowerMode.ultraBatterySaver:
        return true;
    }
  }
}

/// Battery usage measurement for a specific feature or service
class BatteryUsageEntry {
  const BatteryUsageEntry({
    required this.featureName,
    required this.serviceType,
    required this.startTime,
    required this.endTime,
    required this.startBatteryLevel,
    required this.endBatteryLevel,
    required this.estimatedUsagePercent,
    required this.powerMode,
    this.additionalData = const {},
  });

  final String featureName;
  final ServiceType serviceType;
  final DateTime startTime;
  final DateTime endTime;
  final int startBatteryLevel;
  final int endBatteryLevel;
  final double estimatedUsagePercent;
  final PowerMode powerMode;
  final Map<String, dynamic> additionalData;

  /// Duration of the usage session
  Duration get duration => endTime.difference(startTime);

  /// Actual battery drain during this session
  int get actualBatteryDrain => startBatteryLevel - endBatteryLevel;

  /// Usage rate per hour
  double get usageRatePerHour {
    final hours = duration.inMilliseconds / (1000 * 60 * 60);
    return hours > 0 ? estimatedUsagePercent / hours : 0.0;
  }

  @override
  String toString() =>
      'BatteryUsageEntry($featureName: ${estimatedUsagePercent.toStringAsFixed(2)}%)';
}

/// Types of services that consume battery
enum ServiceType {
  gpsTracking,
  backgroundLocation,
  sensorFusion,
  compass,
  accelerometer,
  magnetometer,
  barometer,
  camera,
  notification,
  database,
  networking,
  mapRendering,
  audioRecording;

  String get displayName {
    switch (this) {
      case ServiceType.gpsTracking:
        return 'GPS Tracking';
      case ServiceType.backgroundLocation:
        return 'Background Location';
      case ServiceType.sensorFusion:
        return 'Sensor Fusion';
      case ServiceType.compass:
        return 'Compass';
      case ServiceType.accelerometer:
        return 'Accelerometer';
      case ServiceType.magnetometer:
        return 'Magnetometer';
      case ServiceType.barometer:
        return 'Barometer';
      case ServiceType.camera:
        return 'Camera';
      case ServiceType.notification:
        return 'Notifications';
      case ServiceType.database:
        return 'Database';
      case ServiceType.networking:
        return 'Networking';
      case ServiceType.mapRendering:
        return 'Map Rendering';
      case ServiceType.audioRecording:
        return 'Audio Recording';
    }
  }

  /// Estimated base power consumption (0-100 scale)
  double get basePowerConsumption {
    switch (this) {
      case ServiceType.gpsTracking:
        return 25.0;
      case ServiceType.backgroundLocation:
        return 20.0;
      case ServiceType.sensorFusion:
        return 15.0;
      case ServiceType.compass:
        return 8.0;
      case ServiceType.accelerometer:
        return 5.0;
      case ServiceType.magnetometer:
        return 6.0;
      case ServiceType.barometer:
        return 3.0;
      case ServiceType.camera:
        return 30.0;
      case ServiceType.notification:
        return 2.0;
      case ServiceType.database:
        return 4.0;
      case ServiceType.networking:
        return 10.0;
      case ServiceType.mapRendering:
        return 12.0;
      case ServiceType.audioRecording:
        return 18.0;
    }
  }
}

/// Battery usage analytics and statistics
class BatteryAnalytics {
  const BatteryAnalytics({
    required this.totalUsageEntries,
    required this.averageUsagePerHour,
    required this.peakUsagePerHour,
    required this.mostPowerHungryService,
    required this.totalTrackingTime,
    required this.estimatedRemainingTime,
    required this.usageByService,
    required this.usageByPowerMode,
    required this.batteryHealthScore,
    required this.optimizationSuggestions,
    required this.generatedAt,
  });

  final int totalUsageEntries;
  final double averageUsagePerHour;
  final double peakUsagePerHour;
  final ServiceType mostPowerHungryService;
  final Duration totalTrackingTime;
  final Duration? estimatedRemainingTime;
  final Map<ServiceType, double> usageByService;
  final Map<PowerMode, double> usageByPowerMode;
  final double batteryHealthScore; // 0-100
  final List<BatteryOptimizationSuggestion> optimizationSuggestions;
  final DateTime generatedAt;

  /// Whether battery usage is considered efficient
  bool get isEfficient => batteryHealthScore >= 70.0;

  /// Whether immediate optimization is recommended
  bool get needsOptimization => batteryHealthScore < 50.0;
}

/// Battery optimization suggestions
class BatteryOptimizationSuggestion {
  const BatteryOptimizationSuggestion({
    required this.type,
    required this.title,
    required this.description,
    required this.estimatedSavings,
    required this.priority,
    required this.actionRequired,
  });

  final OptimizationType type;
  final String title;
  final String description;
  final double estimatedSavings; // Percentage savings
  final OptimizationPriority priority;
  final String actionRequired;

  @override
  String toString() =>
      'BatteryOptimizationSuggestion($title: ${estimatedSavings.toStringAsFixed(1)}% savings)';
}

/// Types of battery optimizations
enum OptimizationType {
  reduceGpsFrequency,
  disableUnusedSensors,
  switchPowerMode,
  limitBackgroundProcessing,
  optimizeMapRendering,
  reduceNotifications,
  enableAdaptiveTracking;

  String get displayName {
    switch (this) {
      case OptimizationType.reduceGpsFrequency:
        return 'Reduce GPS Frequency';
      case OptimizationType.disableUnusedSensors:
        return 'Disable Unused Sensors';
      case OptimizationType.switchPowerMode:
        return 'Switch Power Mode';
      case OptimizationType.limitBackgroundProcessing:
        return 'Limit Background Processing';
      case OptimizationType.optimizeMapRendering:
        return 'Optimize Map Rendering';
      case OptimizationType.reduceNotifications:
        return 'Reduce Notifications';
      case OptimizationType.enableAdaptiveTracking:
        return 'Enable Adaptive Tracking';
    }
  }
}

/// Priority levels for optimizations
enum OptimizationPriority {
  low,
  medium,
  high,
  critical;

  String get displayName {
    switch (this) {
      case OptimizationPriority.low:
        return 'Low';
      case OptimizationPriority.medium:
        return 'Medium';
      case OptimizationPriority.high:
        return 'High';
      case OptimizationPriority.critical:
        return 'Critical';
    }
  }

  /// Color representation for UI
  String get colorHex {
    switch (this) {
      case OptimizationPriority.low:
        return '#4CAF50'; // Green
      case OptimizationPriority.medium:
        return '#FF9800'; // Orange
      case OptimizationPriority.high:
        return '#F44336'; // Red
      case OptimizationPriority.critical:
        return '#9C27B0'; // Purple
    }
  }
}

/// Power management configuration
class PowerManagementConfig {
  const PowerManagementConfig({
    required this.mode,
    required this.autoSwitchEnabled,
    required this.criticalBatteryThreshold,
    required this.lowBatteryThreshold,
    required this.autoSwitchToBatterySaver,
    required this.autoSwitchToUltraSaver,
    required this.enableAdaptiveFrequency,
    required this.enableBackgroundOptimization,
    required this.customSettings,
  });

  /// Default power management configuration
  factory PowerManagementConfig.defaultConfig() => const PowerManagementConfig(
        mode: PowerMode.balanced,
        autoSwitchEnabled: true,
        criticalBatteryThreshold: 15,
        lowBatteryThreshold: 30,
        autoSwitchToBatterySaver: 30,
        autoSwitchToUltraSaver: 15,
        enableAdaptiveFrequency: true,
        enableBackgroundOptimization: true,
        customSettings: {},
      );

  final PowerMode mode;
  final bool autoSwitchEnabled;
  final int criticalBatteryThreshold; // Percentage
  final int lowBatteryThreshold; // Percentage
  final int autoSwitchToBatterySaver; // Battery percentage
  final int autoSwitchToUltraSaver; // Battery percentage
  final bool enableAdaptiveFrequency;
  final bool enableBackgroundOptimization;
  final Map<String, dynamic> customSettings;

  /// Create a copy with modified values
  PowerManagementConfig copyWith({
    PowerMode? mode,
    bool? autoSwitchEnabled,
    int? criticalBatteryThreshold,
    int? lowBatteryThreshold,
    int? autoSwitchToBatterySaver,
    int? autoSwitchToUltraSaver,
    bool? enableAdaptiveFrequency,
    bool? enableBackgroundOptimization,
    Map<String, dynamic>? customSettings,
  }) =>
      PowerManagementConfig(
        mode: mode ?? this.mode,
        autoSwitchEnabled: autoSwitchEnabled ?? this.autoSwitchEnabled,
        criticalBatteryThreshold:
            criticalBatteryThreshold ?? this.criticalBatteryThreshold,
        lowBatteryThreshold: lowBatteryThreshold ?? this.lowBatteryThreshold,
        autoSwitchToBatterySaver:
            autoSwitchToBatterySaver ?? this.autoSwitchToBatterySaver,
        autoSwitchToUltraSaver:
            autoSwitchToUltraSaver ?? this.autoSwitchToUltraSaver,
        enableAdaptiveFrequency:
            enableAdaptiveFrequency ?? this.enableAdaptiveFrequency,
        enableBackgroundOptimization:
            enableBackgroundOptimization ?? this.enableBackgroundOptimization,
        customSettings: customSettings ?? this.customSettings,
      );

  @override
  String toString() =>
      'PowerManagementConfig(mode: ${mode.name}, autoSwitch: $autoSwitchEnabled)';
}

/// Battery health assessment
class BatteryHealthAssessment {
  const BatteryHealthAssessment({
    required this.overallScore,
    required this.usageEfficiency,
    required this.powerModeOptimization,
    required this.serviceOptimization,
    required this.backgroundProcessingScore,
    required this.recommendations,
    required this.assessmentTime,
  });

  final double overallScore; // 0-100
  final double usageEfficiency; // 0-100
  final double powerModeOptimization; // 0-100
  final double serviceOptimization; // 0-100
  final double backgroundProcessingScore; // 0-100
  final List<String> recommendations;
  final DateTime assessmentTime;

  /// Health grade based on overall score
  BatteryHealthGrade get grade {
    if (overallScore >= 90) return BatteryHealthGrade.excellent;
    if (overallScore >= 75) return BatteryHealthGrade.good;
    if (overallScore >= 60) return BatteryHealthGrade.fair;
    if (overallScore >= 40) return BatteryHealthGrade.poor;
    return BatteryHealthGrade.critical;
  }
}

/// Battery health grades
enum BatteryHealthGrade {
  excellent,
  good,
  fair,
  poor,
  critical;

  String get displayName {
    switch (this) {
      case BatteryHealthGrade.excellent:
        return 'Excellent';
      case BatteryHealthGrade.good:
        return 'Good';
      case BatteryHealthGrade.fair:
        return 'Fair';
      case BatteryHealthGrade.poor:
        return 'Poor';
      case BatteryHealthGrade.critical:
        return 'Critical';
    }
  }

  String get description {
    switch (this) {
      case BatteryHealthGrade.excellent:
        return 'Battery usage is highly optimized';
      case BatteryHealthGrade.good:
        return 'Battery usage is well optimized';
      case BatteryHealthGrade.fair:
        return 'Battery usage could be improved';
      case BatteryHealthGrade.poor:
        return 'Battery usage needs optimization';
      case BatteryHealthGrade.critical:
        return 'Battery usage requires immediate attention';
    }
  }

  /// Color representation for UI
  String get colorHex {
    switch (this) {
      case BatteryHealthGrade.excellent:
        return '#4CAF50'; // Green
      case BatteryHealthGrade.good:
        return '#8BC34A'; // Light Green
      case BatteryHealthGrade.fair:
        return '#FF9800'; // Orange
      case BatteryHealthGrade.poor:
        return '#FF5722'; // Deep Orange
      case BatteryHealthGrade.critical:
        return '#F44336'; // Red
    }
  }
}
