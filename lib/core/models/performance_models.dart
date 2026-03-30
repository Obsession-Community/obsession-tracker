/// Performance monitoring and optimization models
///
/// Provides comprehensive performance tracking, memory monitoring, crash reporting,
/// and optimization analytics for the Obsession Tracker app.

/// Memory usage information
class MemoryUsage {
  const MemoryUsage({
    required this.totalMemory,
    required this.usedMemory,
    required this.freeMemory,
    required this.appMemoryUsage,
    required this.timestamp,
    this.memoryPressure = MemoryPressureLevel.normal,
    this.gcCollections = 0,
    this.heapSize = 0,
    this.externalMemory = 0,
  });

  final int totalMemory; // Total device memory in bytes
  final int usedMemory; // Used device memory in bytes
  final int freeMemory; // Free device memory in bytes
  final int appMemoryUsage; // App-specific memory usage in bytes
  final DateTime timestamp;
  final MemoryPressureLevel memoryPressure;
  final int gcCollections; // Garbage collection count
  final int heapSize; // Dart heap size in bytes
  final int externalMemory; // External memory usage in bytes

  /// Memory usage percentage
  double get usagePercentage => (usedMemory / totalMemory) * 100;

  /// App memory usage percentage
  double get appUsagePercentage => (appMemoryUsage / totalMemory) * 100;

  /// Whether memory usage is critical
  bool get isCritical =>
      usagePercentage > 90 || memoryPressure == MemoryPressureLevel.critical;

  /// Whether memory usage is high
  bool get isHigh =>
      usagePercentage > 75 || memoryPressure == MemoryPressureLevel.high;

  @override
  String toString() =>
      'MemoryUsage(${(appMemoryUsage / 1024 / 1024).toStringAsFixed(1)}MB app, ${usagePercentage.toStringAsFixed(1)}% total)';
}

/// Memory pressure levels
enum MemoryPressureLevel {
  normal,
  moderate,
  high,
  critical;

  String get description {
    switch (this) {
      case MemoryPressureLevel.normal:
        return 'Normal';
      case MemoryPressureLevel.moderate:
        return 'Moderate Pressure';
      case MemoryPressureLevel.high:
        return 'High Pressure';
      case MemoryPressureLevel.critical:
        return 'Critical Pressure';
    }
  }

  String get colorHex {
    switch (this) {
      case MemoryPressureLevel.normal:
        return '#4CAF50'; // Green
      case MemoryPressureLevel.moderate:
        return '#FF9800'; // Orange
      case MemoryPressureLevel.high:
        return '#FF5722'; // Deep Orange
      case MemoryPressureLevel.critical:
        return '#F44336'; // Red
    }
  }
}

/// Memory leak detection result
class MemoryLeakDetection {
  const MemoryLeakDetection({
    required this.isLeakDetected,
    required this.leakSeverity,
    required this.suspiciousObjects,
    required this.memoryGrowthRate,
    required this.detectionTime,
    this.recommendations = const [],
  });

  final bool isLeakDetected;
  final LeakSeverity leakSeverity;
  final List<SuspiciousObject> suspiciousObjects;
  final double memoryGrowthRate; // MB per minute
  final DateTime detectionTime;
  final List<String> recommendations;

  /// Whether immediate action is required
  bool get requiresImmediateAction => leakSeverity == LeakSeverity.critical;
}

/// Memory leak severity levels
enum LeakSeverity {
  none,
  minor,
  moderate,
  major,
  critical;

  String get description {
    switch (this) {
      case LeakSeverity.none:
        return 'No Leak Detected';
      case LeakSeverity.minor:
        return 'Minor Leak';
      case LeakSeverity.moderate:
        return 'Moderate Leak';
      case LeakSeverity.major:
        return 'Major Leak';
      case LeakSeverity.critical:
        return 'Critical Leak';
    }
  }
}

/// Suspicious object information
class SuspiciousObject {
  const SuspiciousObject({
    required this.objectType,
    required this.instanceCount,
    required this.memorySize,
    required this.growthRate,
    this.stackTrace,
  });

  final String objectType;
  final int instanceCount;
  final int memorySize; // bytes
  final double growthRate; // instances per minute
  final String? stackTrace;

  @override
  String toString() =>
      'SuspiciousObject($objectType: $instanceCount instances, ${(memorySize / 1024).toStringAsFixed(1)}KB)';
}

/// Performance profiling data
class PerformanceProfile {
  const PerformanceProfile({
    required this.cpuUsage,
    required this.memoryUsage,
    required this.frameRenderTime,
    required this.networkLatency,
    required this.diskIOTime,
    required this.batteryDrain,
    required this.timestamp,
    this.jankFrames = 0,
    this.totalFrames = 0,
    this.gpuUsage = 0.0,
  });

  final double cpuUsage; // Percentage
  final MemoryUsage memoryUsage;
  final double frameRenderTime; // Milliseconds
  final double networkLatency; // Milliseconds
  final double diskIOTime; // Milliseconds
  final double batteryDrain; // Percentage per hour
  final DateTime timestamp;
  final int jankFrames; // Frames that took >16ms to render
  final int totalFrames;
  final double gpuUsage; // Percentage

  /// Frame rate (FPS)
  double get frameRate => totalFrames > 0 ? 1000 / frameRenderTime : 0.0;

  /// Jank percentage
  double get jankPercentage =>
      totalFrames > 0 ? (jankFrames / totalFrames) * 100 : 0.0;

  /// Overall performance score (0-100)
  double get performanceScore {
    double score = 100.0;

    // CPU penalty
    if (cpuUsage > 80)
      score -= 20;
    else if (cpuUsage > 60)
      score -= 10;
    else if (cpuUsage > 40) score -= 5;

    // Memory penalty
    if (memoryUsage.isCritical)
      score -= 25;
    else if (memoryUsage.isHigh) score -= 15;

    // Frame rate penalty
    if (frameRate < 30)
      score -= 20;
    else if (frameRate < 45)
      score -= 10;
    else if (frameRate < 55) score -= 5;

    // Jank penalty
    if (jankPercentage > 10)
      score -= 15;
    else if (jankPercentage > 5)
      score -= 8;
    else if (jankPercentage > 2) score -= 3;

    // Battery penalty
    if (batteryDrain > 20)
      score -= 15;
    else if (batteryDrain > 10)
      score -= 8;
    else if (batteryDrain > 5) score -= 3;

    return score.clamp(0.0, 100.0);
  }

  /// Performance grade
  PerformanceGrade get grade {
    final score = performanceScore;
    if (score >= 90) return PerformanceGrade.excellent;
    if (score >= 75) return PerformanceGrade.good;
    if (score >= 60) return PerformanceGrade.fair;
    if (score >= 40) return PerformanceGrade.poor;
    return PerformanceGrade.critical;
  }
}

/// Performance grades
enum PerformanceGrade {
  excellent,
  good,
  fair,
  poor,
  critical;

  String get displayName {
    switch (this) {
      case PerformanceGrade.excellent:
        return 'Excellent';
      case PerformanceGrade.good:
        return 'Good';
      case PerformanceGrade.fair:
        return 'Fair';
      case PerformanceGrade.poor:
        return 'Poor';
      case PerformanceGrade.critical:
        return 'Critical';
    }
  }

  String get colorHex {
    switch (this) {
      case PerformanceGrade.excellent:
        return '#4CAF50'; // Green
      case PerformanceGrade.good:
        return '#8BC34A'; // Light Green
      case PerformanceGrade.fair:
        return '#FF9800'; // Orange
      case PerformanceGrade.poor:
        return '#FF5722'; // Deep Orange
      case PerformanceGrade.critical:
        return '#F44336'; // Red
    }
  }
}

/// Crash report information
class CrashReport {
  const CrashReport({
    required this.crashId,
    required this.timestamp,
    required this.errorMessage,
    required this.stackTrace,
    required this.deviceInfo,
    required this.appVersion,
    required this.crashType,
    this.userActions = const [],
    this.memoryUsageAtCrash,
    this.performanceDataAtCrash,
    this.additionalContext = const {},
  });

  factory CrashReport.fromMap(Map<String, dynamic> map) => CrashReport(
        crashId: map['crashId'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        errorMessage: map['errorMessage'] as String,
        stackTrace: map['stackTrace'] as String,
        deviceInfo: Map<String, dynamic>.from(map['deviceInfo'] as Map),
        appVersion: map['appVersion'] as String,
        crashType: CrashType.values.firstWhere(
          (e) => e.name == map['crashType'],
          orElse: () => CrashType.unknown,
        ),
        userActions: List<String>.from(map['userActions'] as List? ?? []),
        additionalContext:
            Map<String, dynamic>.from(map['additionalContext'] as Map? ?? {}),
      );

  final String crashId;
  final DateTime timestamp;
  final String errorMessage;
  final String stackTrace;
  final Map<String, dynamic> deviceInfo;
  final String appVersion;
  final CrashType crashType;
  final List<String> userActions; // Actions leading to crash
  final MemoryUsage? memoryUsageAtCrash;
  final PerformanceProfile? performanceDataAtCrash;
  final Map<String, dynamic> additionalContext;

  /// Whether this is a critical crash
  bool get isCritical =>
      crashType == CrashType.fatal || crashType == CrashType.anr;

  Map<String, dynamic> toMap() => {
        'crashId': crashId,
        'timestamp': timestamp.toIso8601String(),
        'errorMessage': errorMessage,
        'stackTrace': stackTrace,
        'deviceInfo': deviceInfo,
        'appVersion': appVersion,
        'crashType': crashType.name,
        'userActions': userActions,
        'additionalContext': additionalContext,
      };
}

/// Types of crashes
enum CrashType {
  fatal,
  exception,
  anr, // Application Not Responding
  outOfMemory,
  networkError,
  storageError,
  permissionError,
  unknown;

  String get displayName {
    switch (this) {
      case CrashType.fatal:
        return 'Fatal Error';
      case CrashType.exception:
        return 'Exception';
      case CrashType.anr:
        return 'App Not Responding';
      case CrashType.outOfMemory:
        return 'Out of Memory';
      case CrashType.networkError:
        return 'Network Error';
      case CrashType.storageError:
        return 'Storage Error';
      case CrashType.permissionError:
        return 'Permission Error';
      case CrashType.unknown:
        return 'Unknown Error';
    }
  }
}

/// App size optimization data
class AppSizeOptimization {
  const AppSizeOptimization({
    required this.totalAppSize,
    required this.codeSize,
    required this.assetSize,
    required this.dataSize,
    required this.cacheSize,
    required this.optimizationPotential,
    required this.recommendations,
    required this.timestamp,
  });

  final int totalAppSize; // bytes
  final int codeSize; // bytes
  final int assetSize; // bytes
  final int dataSize; // bytes
  final int cacheSize; // bytes
  final int optimizationPotential; // bytes that can be saved
  final List<SizeOptimizationRecommendation> recommendations;
  final DateTime timestamp;

  /// Optimization potential percentage
  double get optimizationPercentage =>
      (optimizationPotential / totalAppSize) * 100;

  /// Size breakdown
  Map<String, double> get sizeBreakdown => {
        'Code': (codeSize / totalAppSize) * 100,
        'Assets': (assetSize / totalAppSize) * 100,
        'Data': (dataSize / totalAppSize) * 100,
        'Cache': (cacheSize / totalAppSize) * 100,
      };
}

/// Size optimization recommendation
class SizeOptimizationRecommendation {
  const SizeOptimizationRecommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.potentialSavings,
    required this.priority,
    required this.effort,
  });

  final OptimizationType type;
  final String title;
  final String description;
  final int potentialSavings; // bytes
  final OptimizationPriority priority;
  final OptimizationEffort effort;

  /// Potential savings in MB
  double get potentialSavingsMB => potentialSavings / (1024 * 1024);
}

/// Optimization types for app size
enum OptimizationType {
  compressAssets,
  removeUnusedAssets,
  optimizeImages,
  cleanupCache,
  removeOldData,
  compressDatabase,
  enableCodeSplitting,
  optimizeDependencies;

  String get displayName {
    switch (this) {
      case OptimizationType.compressAssets:
        return 'Compress Assets';
      case OptimizationType.removeUnusedAssets:
        return 'Remove Unused Assets';
      case OptimizationType.optimizeImages:
        return 'Optimize Images';
      case OptimizationType.cleanupCache:
        return 'Cleanup Cache';
      case OptimizationType.removeOldData:
        return 'Remove Old Data';
      case OptimizationType.compressDatabase:
        return 'Compress Database';
      case OptimizationType.enableCodeSplitting:
        return 'Enable Code Splitting';
      case OptimizationType.optimizeDependencies:
        return 'Optimize Dependencies';
    }
  }
}

/// Optimization priority levels
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
}

/// Optimization effort levels
enum OptimizationEffort {
  minimal,
  low,
  medium,
  high;

  String get displayName {
    switch (this) {
      case OptimizationEffort.minimal:
        return 'Minimal';
      case OptimizationEffort.low:
        return 'Low';
      case OptimizationEffort.medium:
        return 'Medium';
      case OptimizationEffort.high:
        return 'High';
    }
  }
}

/// Performance monitoring configuration
class PerformanceMonitoringConfig {
  const PerformanceMonitoringConfig({
    this.memoryMonitoringEnabled = true,
    this.crashReportingEnabled = true,
    this.performanceProfilingEnabled = true,
    this.memoryLeakDetectionEnabled = true,
    this.monitoringInterval = const Duration(seconds: 30),
    this.memoryLeakCheckInterval = const Duration(minutes: 5),
    this.maxCrashReports = 100,
    this.maxPerformanceProfiles = 1000,
    this.enableDetailedProfiling = false,
  });

  final bool memoryMonitoringEnabled;
  final bool crashReportingEnabled;
  final bool performanceProfilingEnabled;
  final bool memoryLeakDetectionEnabled;
  final Duration monitoringInterval;
  final Duration memoryLeakCheckInterval;
  final int maxCrashReports;
  final int maxPerformanceProfiles;
  final bool enableDetailedProfiling;

  /// Create a copy with modified values
  PerformanceMonitoringConfig copyWith({
    bool? memoryMonitoringEnabled,
    bool? crashReportingEnabled,
    bool? performanceProfilingEnabled,
    bool? memoryLeakDetectionEnabled,
    Duration? monitoringInterval,
    Duration? memoryLeakCheckInterval,
    int? maxCrashReports,
    int? maxPerformanceProfiles,
    bool? enableDetailedProfiling,
  }) =>
      PerformanceMonitoringConfig(
        memoryMonitoringEnabled:
            memoryMonitoringEnabled ?? this.memoryMonitoringEnabled,
        crashReportingEnabled:
            crashReportingEnabled ?? this.crashReportingEnabled,
        performanceProfilingEnabled:
            performanceProfilingEnabled ?? this.performanceProfilingEnabled,
        memoryLeakDetectionEnabled:
            memoryLeakDetectionEnabled ?? this.memoryLeakDetectionEnabled,
        monitoringInterval: monitoringInterval ?? this.monitoringInterval,
        memoryLeakCheckInterval:
            memoryLeakCheckInterval ?? this.memoryLeakCheckInterval,
        maxCrashReports: maxCrashReports ?? this.maxCrashReports,
        maxPerformanceProfiles:
            maxPerformanceProfiles ?? this.maxPerformanceProfiles,
        enableDetailedProfiling:
            enableDetailedProfiling ?? this.enableDetailedProfiling,
      );
}

/// Performance analytics summary
class PerformanceAnalytics {
  const PerformanceAnalytics({
    required this.averagePerformanceScore,
    required this.memoryUsageTrend,
    required this.crashFrequency,
    required this.batteryEfficiencyScore,
    required this.frameRateConsistency,
    required this.topPerformanceIssues,
    required this.optimizationRecommendations,
    required this.generatedAt,
  });

  final double averagePerformanceScore;
  final MemoryUsageTrend memoryUsageTrend;
  final double crashFrequency; // crashes per day
  final double batteryEfficiencyScore;
  final double frameRateConsistency; // percentage
  final List<PerformanceIssue> topPerformanceIssues;
  final List<String> optimizationRecommendations;
  final DateTime generatedAt;

  /// Overall health grade
  PerformanceGrade get overallGrade {
    final score = (averagePerformanceScore +
            batteryEfficiencyScore +
            frameRateConsistency) /
        3;
    if (score >= 90) return PerformanceGrade.excellent;
    if (score >= 75) return PerformanceGrade.good;
    if (score >= 60) return PerformanceGrade.fair;
    if (score >= 40) return PerformanceGrade.poor;
    return PerformanceGrade.critical;
  }
}

/// Memory usage trend
enum MemoryUsageTrend {
  decreasing,
  stable,
  increasing,
  rapidlyIncreasing;

  String get displayName {
    switch (this) {
      case MemoryUsageTrend.decreasing:
        return 'Decreasing';
      case MemoryUsageTrend.stable:
        return 'Stable';
      case MemoryUsageTrend.increasing:
        return 'Increasing';
      case MemoryUsageTrend.rapidlyIncreasing:
        return 'Rapidly Increasing';
    }
  }

  String get colorHex {
    switch (this) {
      case MemoryUsageTrend.decreasing:
        return '#4CAF50'; // Green
      case MemoryUsageTrend.stable:
        return '#2196F3'; // Blue
      case MemoryUsageTrend.increasing:
        return '#FF9800'; // Orange
      case MemoryUsageTrend.rapidlyIncreasing:
        return '#F44336'; // Red
    }
  }
}

/// Performance issue
class PerformanceIssue {
  const PerformanceIssue({
    required this.type,
    required this.severity,
    required this.description,
    required this.frequency,
    required this.impact,
    this.recommendation,
  });

  final PerformanceIssueType type;
  final IssueSeverity severity;
  final String description;
  final int frequency; // occurrences
  final double impact; // 0-100 scale
  final String? recommendation;
}

/// Performance issue types
enum PerformanceIssueType {
  memoryLeak,
  highCpuUsage,
  frameDrops,
  slowNetworkRequests,
  excessiveBatteryDrain,
  storageIssues,
  crashFrequency;

  String get displayName {
    switch (this) {
      case PerformanceIssueType.memoryLeak:
        return 'Memory Leak';
      case PerformanceIssueType.highCpuUsage:
        return 'High CPU Usage';
      case PerformanceIssueType.frameDrops:
        return 'Frame Drops';
      case PerformanceIssueType.slowNetworkRequests:
        return 'Slow Network Requests';
      case PerformanceIssueType.excessiveBatteryDrain:
        return 'Excessive Battery Drain';
      case PerformanceIssueType.storageIssues:
        return 'Storage Issues';
      case PerformanceIssueType.crashFrequency:
        return 'Frequent Crashes';
    }
  }
}

/// Issue severity levels
enum IssueSeverity {
  low,
  medium,
  high,
  critical;

  String get displayName {
    switch (this) {
      case IssueSeverity.low:
        return 'Low';
      case IssueSeverity.medium:
        return 'Medium';
      case IssueSeverity.high:
        return 'High';
      case IssueSeverity.critical:
        return 'Critical';
    }
  }

  String get colorHex {
    switch (this) {
      case IssueSeverity.low:
        return '#4CAF50'; // Green
      case IssueSeverity.medium:
        return '#FF9800'; // Orange
      case IssueSeverity.high:
        return '#FF5722'; // Deep Orange
      case IssueSeverity.critical:
        return '#F44336'; // Red
    }
  }
}

/// Storage cleanup event
class StorageCleanupEvent {
  const StorageCleanupEvent({
    required this.type,
    required this.description,
    required this.bytesFreed,
    required this.timestamp,
    this.result,
  });

  final StorageCleanupEventType type;
  final String description;
  final int bytesFreed;
  final DateTime timestamp;
  final StorageCleanupResult? result;

  @override
  String toString() =>
      'StorageCleanupEvent(${type.displayName}: $bytesFreed bytes freed)';
}

/// Storage cleanup event types
enum StorageCleanupEventType {
  cleanupStarted,
  cleanupCompleted,
  cleanupFailed,
  storageWarning,
  optimizationRecommendation;

  String get displayName {
    switch (this) {
      case StorageCleanupEventType.cleanupStarted:
        return 'Cleanup Started';
      case StorageCleanupEventType.cleanupCompleted:
        return 'Cleanup Completed';
      case StorageCleanupEventType.cleanupFailed:
        return 'Cleanup Failed';
      case StorageCleanupEventType.storageWarning:
        return 'Storage Warning';
      case StorageCleanupEventType.optimizationRecommendation:
        return 'Optimization Recommendation';
    }
  }
}

/// Storage cleanup result
class StorageCleanupResult {
  const StorageCleanupResult({
    required this.cleanupType,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.bytesFreed,
    required this.cleanupDetails,
    required this.errors,
    required this.success,
  });

  final StorageCleanupType cleanupType;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final int bytesFreed;
  final Map<String, int> cleanupDetails;
  final List<String> errors;
  final bool success;

  /// Cleanup efficiency score (0-100)
  double get efficiencyScore {
    if (duration.inSeconds == 0) return 0.0;

    double score = 100.0;

    // Penalize long cleanup times
    if (duration.inMinutes > 10)
      score -= 30;
    else if (duration.inMinutes > 5)
      score -= 15;
    else if (duration.inMinutes > 2) score -= 5;

    // Penalize errors
    score -= errors.length * 10;

    // Reward bytes freed
    if (bytesFreed > 100 * 1024 * 1024)
      score += 10; // 100MB+
    else if (bytesFreed > 50 * 1024 * 1024) score += 5; // 50MB+

    return score.clamp(0.0, 100.0);
  }
}

/// Storage cleanup types
enum StorageCleanupType {
  temporaryFiles,
  cacheFiles,
  oldPhotos,
  oldSessions,
  databaseOptimization,
  logFiles,
  comprehensive;

  String get displayName {
    switch (this) {
      case StorageCleanupType.temporaryFiles:
        return 'Temporary Files';
      case StorageCleanupType.cacheFiles:
        return 'Cache Files';
      case StorageCleanupType.oldPhotos:
        return 'Old Photos';
      case StorageCleanupType.oldSessions:
        return 'Old Sessions';
      case StorageCleanupType.databaseOptimization:
        return 'Database Optimization';
      case StorageCleanupType.logFiles:
        return 'Log Files';
      case StorageCleanupType.comprehensive:
        return 'Comprehensive Cleanup';
    }
  }
}

/// Storage analytics
class StorageAnalytics {
  const StorageAnalytics({
    required this.totalDeviceStorage,
    required this.totalUsedStorage,
    required this.totalFreeStorage,
    required this.appStorageUsage,
    required this.storageUsagePercentage,
    required this.storageBreakdown,
    required this.cacheSize,
    required this.tempSize,
    required this.databaseSize,
    required this.photoStorageSize,
    required this.storageHealth,
    required this.recommendations,
    required this.lastCleanup,
    required this.generatedAt,
  });

  final int totalDeviceStorage;
  final int totalUsedStorage;
  final int totalFreeStorage;
  final int appStorageUsage;
  final double storageUsagePercentage;
  final Map<String, int> storageBreakdown;
  final int cacheSize;
  final int tempSize;
  final int databaseSize;
  final int photoStorageSize;
  final StorageHealth storageHealth;
  final List<StorageOptimizationRecommendation> recommendations;
  final DateTime? lastCleanup;
  final DateTime generatedAt;

  /// Whether storage cleanup is recommended
  bool get needsCleanup =>
      storageUsagePercentage > 75 ||
      storageHealth == StorageHealth.poor ||
      storageHealth == StorageHealth.critical;
}

/// Storage health levels
enum StorageHealth {
  excellent,
  good,
  fair,
  poor,
  critical,
  unknown;

  String get displayName {
    switch (this) {
      case StorageHealth.excellent:
        return 'Excellent';
      case StorageHealth.good:
        return 'Good';
      case StorageHealth.fair:
        return 'Fair';
      case StorageHealth.poor:
        return 'Poor';
      case StorageHealth.critical:
        return 'Critical';
      case StorageHealth.unknown:
        return 'Unknown';
    }
  }

  String get colorHex {
    switch (this) {
      case StorageHealth.excellent:
        return '#4CAF50'; // Green
      case StorageHealth.good:
        return '#8BC34A'; // Light Green
      case StorageHealth.fair:
        return '#FF9800'; // Orange
      case StorageHealth.poor:
        return '#FF5722'; // Deep Orange
      case StorageHealth.critical:
        return '#F44336'; // Red
      case StorageHealth.unknown:
        return '#9E9E9E'; // Grey
    }
  }
}

/// Storage optimization recommendation
class StorageOptimizationRecommendation {
  const StorageOptimizationRecommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    required this.potentialSavings,
    required this.effort,
  });

  final StorageOptimizationType type;
  final String title;
  final String description;
  final OptimizationPriority priority;
  final int potentialSavings; // bytes
  final OptimizationEffort effort;

  /// Potential savings in MB
  double get potentialSavingsMB => potentialSavings / (1024 * 1024);
}

/// Storage optimization types
enum StorageOptimizationType {
  cleanupCache,
  cleanupOldData,
  compressPhotos,
  optimizeDatabase,
  removeUnusedFiles;

  String get displayName {
    switch (this) {
      case StorageOptimizationType.cleanupCache:
        return 'Cleanup Cache';
      case StorageOptimizationType.cleanupOldData:
        return 'Cleanup Old Data';
      case StorageOptimizationType.compressPhotos:
        return 'Compress Photos';
      case StorageOptimizationType.optimizeDatabase:
        return 'Optimize Database';
      case StorageOptimizationType.removeUnusedFiles:
        return 'Remove Unused Files';
    }
  }
}

/// Storage cleanup configuration
class StorageCleanupConfig {
  const StorageCleanupConfig({
    this.automaticCleanupEnabled = true,
    this.automaticCleanupInterval = const Duration(days: 7),
    this.cleanOldPhotosEnabled = false,
    this.cleanOldSessionsEnabled = false,
    this.optimizeDatabaseEnabled = true,
    this.photoRetentionPeriod = const Duration(days: 365),
    this.sessionRetentionPeriod = const Duration(days: 90),
    this.maxCacheSize = 500 * 1024 * 1024, // 500MB
    this.maxTempSize = 100 * 1024 * 1024, // 100MB
  });

  /// Default configuration
  factory StorageCleanupConfig.defaultConfig() => const StorageCleanupConfig();

  final bool automaticCleanupEnabled;
  final Duration automaticCleanupInterval;
  final bool cleanOldPhotosEnabled;
  final bool cleanOldSessionsEnabled;
  final bool optimizeDatabaseEnabled;
  final Duration photoRetentionPeriod;
  final Duration sessionRetentionPeriod;
  final int maxCacheSize;
  final int maxTempSize;

  /// Create a copy with modified values
  StorageCleanupConfig copyWith({
    bool? automaticCleanupEnabled,
    Duration? automaticCleanupInterval,
    bool? cleanOldPhotosEnabled,
    bool? cleanOldSessionsEnabled,
    bool? optimizeDatabaseEnabled,
    Duration? photoRetentionPeriod,
    Duration? sessionRetentionPeriod,
    int? maxCacheSize,
    int? maxTempSize,
  }) =>
      StorageCleanupConfig(
        automaticCleanupEnabled:
            automaticCleanupEnabled ?? this.automaticCleanupEnabled,
        automaticCleanupInterval:
            automaticCleanupInterval ?? this.automaticCleanupInterval,
        cleanOldPhotosEnabled:
            cleanOldPhotosEnabled ?? this.cleanOldPhotosEnabled,
        cleanOldSessionsEnabled:
            cleanOldSessionsEnabled ?? this.cleanOldSessionsEnabled,
        optimizeDatabaseEnabled:
            optimizeDatabaseEnabled ?? this.optimizeDatabaseEnabled,
        photoRetentionPeriod: photoRetentionPeriod ?? this.photoRetentionPeriod,
        sessionRetentionPeriod:
            sessionRetentionPeriod ?? this.sessionRetentionPeriod,
        maxCacheSize: maxCacheSize ?? this.maxCacheSize,
        maxTempSize: maxTempSize ?? this.maxTempSize,
      );
}

/// Performance alert
class PerformanceAlert {
  const PerformanceAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.actionRequired,
    this.metadata = const {},
  });

  final String id;
  final PerformanceAlertType type;
  final AlertSeverity severity;
  final String title;
  final String description;
  final DateTime timestamp;
  final bool actionRequired;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'severity': severity.name,
        'title': title,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'actionRequired': actionRequired,
        'metadata': metadata,
      };

  @override
  String toString() => 'PerformanceAlert($title: ${severity.displayName})';
}

/// Performance alert types
enum PerformanceAlertType {
  memoryPressure,
  batteryLow,
  storageSpace,
  performanceIssue,
  crashDetected,
  networkIssue;

  String get displayName {
    switch (this) {
      case PerformanceAlertType.memoryPressure:
        return 'Memory Pressure';
      case PerformanceAlertType.batteryLow:
        return 'Battery Low';
      case PerformanceAlertType.storageSpace:
        return 'Storage Space';
      case PerformanceAlertType.performanceIssue:
        return 'Performance Issue';
      case PerformanceAlertType.crashDetected:
        return 'Crash Detected';
      case PerformanceAlertType.networkIssue:
        return 'Network Issue';
    }
  }
}

/// Alert severity levels
enum AlertSeverity {
  low,
  medium,
  high,
  critical;

  String get displayName {
    switch (this) {
      case AlertSeverity.low:
        return 'Low';
      case AlertSeverity.medium:
        return 'Medium';
      case AlertSeverity.high:
        return 'High';
      case AlertSeverity.critical:
        return 'Critical';
    }
  }

  String get colorHex {
    switch (this) {
      case AlertSeverity.low:
        return '#4CAF50'; // Green
      case AlertSeverity.medium:
        return '#FF9800'; // Orange
      case AlertSeverity.high:
        return '#FF5722'; // Deep Orange
      case AlertSeverity.critical:
        return '#F44336'; // Red
    }
  }
}

/// Performance optimization result
class PerformanceOptimizationResult {
  const PerformanceOptimizationResult({
    required this.success,
    required this.duration,
    required this.optimizationResults,
    required this.errors,
    required this.performanceImprovement,
    required this.timestamp,
  });

  final bool success;
  final Duration duration;
  final Map<String, dynamic> optimizationResults;
  final List<String> errors;
  final double performanceImprovement; // percentage
  final DateTime timestamp;

  /// Optimization efficiency score (0-100)
  double get efficiencyScore {
    double score = success ? 80.0 : 20.0;

    // Reward performance improvement
    score += performanceImprovement.clamp(0.0, 20.0);

    // Penalize errors
    score -= errors.length * 5;

    // Reward quick optimization
    if (duration.inSeconds < 30)
      score += 10;
    else if (duration.inSeconds < 60) score += 5;

    return score.clamp(0.0, 100.0);
  }

  Map<String, dynamic> toMap() => {
        'success': success,
        'duration': duration.inMilliseconds,
        'optimizationResults': optimizationResults,
        'errors': errors,
        'performanceImprovement': performanceImprovement,
        'efficiencyScore': efficiencyScore,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Battery analytics (placeholder for missing import)
class BatteryAnalytics {
  const BatteryAnalytics({
    required this.totalUsageEntries,
    required this.averageUsagePerHour,
    required this.peakUsagePerHour,
    required this.batteryHealthScore,
    required this.needsOptimization,
    required this.generatedAt,
  });

  final int totalUsageEntries;
  final double averageUsagePerHour;
  final double peakUsagePerHour;
  final double batteryHealthScore;
  final bool needsOptimization;
  final DateTime generatedAt;

  Map<String, dynamic> toMap() => {
        'totalUsageEntries': totalUsageEntries,
        'averageUsagePerHour': averageUsagePerHour,
        'peakUsagePerHour': peakUsagePerHour,
        'batteryHealthScore': batteryHealthScore,
        'needsOptimization': needsOptimization,
        'generatedAt': generatedAt.toIso8601String(),
      };
}

/// Battery level (placeholder for missing import)
class BatteryLevel {
  const BatteryLevel({
    required this.percentage,
    required this.isCharging,
    required this.timestamp,
  });

  final int percentage;
  final bool isCharging;
  final DateTime timestamp;

  /// Whether battery is critically low (< 15%)
  bool get isCriticallyLow => percentage < 15;

  /// Whether battery is low (< 30%)
  bool get isLow => percentage < 30;
}

/// Battery health grade (placeholder for missing import)
enum BatteryHealthGrade {
  excellent,
  good,
  fair,
  poor,
  critical;

  String get name {
    switch (this) {
      case BatteryHealthGrade.excellent:
        return 'excellent';
      case BatteryHealthGrade.good:
        return 'good';
      case BatteryHealthGrade.fair:
        return 'fair';
      case BatteryHealthGrade.poor:
        return 'poor';
      case BatteryHealthGrade.critical:
        return 'critical';
    }
  }

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
}

/// Stability grade (placeholder for missing import)
enum StabilityGrade {
  excellent,
  good,
  fair,
  poor,
  critical;

  String get name {
    switch (this) {
      case StabilityGrade.excellent:
        return 'excellent';
      case StabilityGrade.good:
        return 'good';
      case StabilityGrade.fair:
        return 'fair';
      case StabilityGrade.poor:
        return 'poor';
      case StabilityGrade.critical:
        return 'critical';
    }
  }

  String get displayName {
    switch (this) {
      case StabilityGrade.excellent:
        return 'Excellent';
      case StabilityGrade.good:
        return 'Good';
      case StabilityGrade.fair:
        return 'Fair';
      case StabilityGrade.poor:
        return 'Poor';
      case StabilityGrade.critical:
        return 'Critical';
    }
  }
}

/// Performance overview model
class PerformanceOverview {
  const PerformanceOverview({
    required this.overallScore,
    required this.memoryHealth,
    required this.storageHealth,
    required this.batteryHealth,
    required this.crashStability,
    required this.performanceGrade,
    required this.activeIssues,
    required this.recommendations,
    required this.lastUpdated,
  });

  final double overallScore; // 0-100
  final PerformanceGrade memoryHealth;
  final PerformanceGrade storageHealth;
  final BatteryHealthGrade batteryHealth;
  final StabilityGrade crashStability;
  final PerformanceGrade performanceGrade;
  final List<PerformanceIssue> activeIssues;
  final List<PerformanceRecommendation> recommendations;
  final DateTime lastUpdated;

  /// Overall health status
  PerformanceGrade get overallGrade {
    if (overallScore >= 90) return PerformanceGrade.excellent;
    if (overallScore >= 75) return PerformanceGrade.good;
    if (overallScore >= 60) return PerformanceGrade.fair;
    if (overallScore >= 40) return PerformanceGrade.poor;
    return PerformanceGrade.critical;
  }

  /// Number of critical issues
  int get criticalIssueCount => activeIssues
      .where((issue) => issue.severity == IssueSeverity.critical)
      .length;

  /// Whether immediate action is required
  bool get requiresImmediateAction =>
      overallScore < 40 || criticalIssueCount > 0;
}

/// Performance recommendation model
class PerformanceRecommendation {
  const PerformanceRecommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    required this.impact,
    this.estimatedTimeToImplement,
    this.difficulty = RecommendationDifficulty.medium,
    this.category = RecommendationCategory.optimization,
  });

  final PerformanceIssueType type;
  final String title;
  final String description;
  final RecommendationPriority priority;
  final double impact; // Expected improvement 0-100
  final Duration? estimatedTimeToImplement;
  final RecommendationDifficulty difficulty;
  final RecommendationCategory category;

  /// Recommendation score (0-100)
  double get score {
    double score = impact;

    // Adjust based on priority
    switch (priority) {
      case RecommendationPriority.critical:
        score += 40;
        break;
      case RecommendationPriority.high:
        score += 30;
        break;
      case RecommendationPriority.medium:
        score += 20;
        break;
      case RecommendationPriority.low:
        score += 10;
        break;
    }

    // Adjust based on difficulty (easier = higher score)
    switch (difficulty) {
      case RecommendationDifficulty.easy:
        score += 20;
        break;
      case RecommendationDifficulty.medium:
        score += 10;
        break;
      case RecommendationDifficulty.hard:
        score -= 10;
        break;
    }

    return score.clamp(0, 100);
  }
}

/// Recommendation priority levels
enum RecommendationPriority {
  low,
  medium,
  high,
  critical;

  String get displayName {
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

/// Recommendation difficulty levels
enum RecommendationDifficulty {
  easy,
  medium,
  hard;

  String get displayName {
    switch (this) {
      case RecommendationDifficulty.easy:
        return 'Easy';
      case RecommendationDifficulty.medium:
        return 'Medium';
      case RecommendationDifficulty.hard:
        return 'Hard';
    }
  }
}

/// Recommendation categories
enum RecommendationCategory {
  optimization,
  maintenance,
  configuration,
  upgrade;

  String get displayName {
    switch (this) {
      case RecommendationCategory.optimization:
        return 'Optimization';
      case RecommendationCategory.maintenance:
        return 'Maintenance';
      case RecommendationCategory.configuration:
        return 'Configuration';
      case RecommendationCategory.upgrade:
        return 'Upgrade';
    }
  }
}
