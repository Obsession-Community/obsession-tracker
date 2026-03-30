import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:obsession_tracker/core/models/performance_models.dart';
import 'package:obsession_tracker/core/services/memory_monitoring_service.dart';
import 'package:path_provider/path_provider.dart';

/// Comprehensive performance profiling and diagnostic service
///
/// Provides real-time performance monitoring, frame rate analysis, CPU usage tracking,
/// and detailed performance diagnostics for optimization insights.
class PerformanceProfilingService {
  factory PerformanceProfilingService() =>
      _instance ??= PerformanceProfilingService._();
  PerformanceProfilingService._();
  static PerformanceProfilingService? _instance;

  // Stream controllers
  StreamController<PerformanceProfile>? _profileController;
  StreamController<PerformanceDiagnostics>? _diagnosticsController;
  StreamController<FrameAnalysis>? _frameAnalysisController;

  // Service state
  bool _isActive = false;
  PerformanceMonitoringConfig _config = const PerformanceMonitoringConfig();

  // Performance tracking
  final List<PerformanceProfile> _performanceHistory = <PerformanceProfile>[];
  final List<FrameMetrics> _frameMetrics = <FrameMetrics>[];
  final Map<String, List<double>> _cpuUsageHistory = {};
  static const int _maxFrameMetricsLength = 500;

  // Monitoring timers and observers
  Timer? _profilingTimer;
  Timer? _diagnosticsTimer;
  FrameCallback? _frameCallback;

  // Dependencies
  final MemoryMonitoringService _memoryService = MemoryMonitoringService();

  // Performance baseline
  DateTime _profilingStartTime = DateTime.now();

  // Frame tracking
  int _totalFrames = 0;
  int _jankFrames = 0;
  double _totalFrameTime = 0.0;
  DateTime _lastFrameTime = DateTime.now();

  /// Stream of performance profiles
  Stream<PerformanceProfile> get profileStream {
    _profileController ??= StreamController<PerformanceProfile>.broadcast();
    return _profileController!.stream;
  }

  /// Stream of performance diagnostics
  Stream<PerformanceDiagnostics> get diagnosticsStream {
    _diagnosticsController ??=
        StreamController<PerformanceDiagnostics>.broadcast();
    return _diagnosticsController!.stream;
  }

  /// Stream of frame analysis
  Stream<FrameAnalysis> get frameAnalysisStream {
    _frameAnalysisController ??= StreamController<FrameAnalysis>.broadcast();
    return _frameAnalysisController!.stream;
  }

  /// Whether profiling is active
  bool get isActive => _isActive;

  /// Current performance profile
  PerformanceProfile? get currentProfile =>
      _performanceHistory.isNotEmpty ? _performanceHistory.last : null;

  /// Performance history
  List<PerformanceProfile> get performanceHistory =>
      List.unmodifiable(_performanceHistory);

  /// Start performance profiling
  Future<void> startProfiling({
    PerformanceMonitoringConfig? config,
  }) async {
    try {
      await stopProfiling(); // Ensure clean start

      _config = config ?? const PerformanceMonitoringConfig();
      _profilingStartTime = DateTime.now();

      debugPrint('📊 Starting performance profiling service...');
      debugPrint('  Profiling enabled: ${_config.performanceProfilingEnabled}');
      debugPrint('  Detailed profiling: ${_config.enableDetailedProfiling}');

      if (!_config.performanceProfilingEnabled) {
        debugPrint('📊 Performance profiling is disabled in configuration');
        return;
      }

      // Initialize stream controllers
      _profileController ??= StreamController<PerformanceProfile>.broadcast();
      _diagnosticsController ??=
          StreamController<PerformanceDiagnostics>.broadcast();
      _frameAnalysisController ??= StreamController<FrameAnalysis>.broadcast();

      // Start frame monitoring
      _startFrameMonitoring();

      // Start periodic profiling
      _profilingTimer = Timer.periodic(_config.monitoringInterval, (_) {
        _collectPerformanceProfile();
      });

      // Start diagnostics
      _diagnosticsTimer = Timer.periodic(
        const Duration(minutes: 2),
        (_) => _performDiagnostics(),
      );

      // Get baseline profile
      await _collectPerformanceProfile();

      _isActive = true;
      debugPrint('📊 Performance profiling service started successfully');
    } catch (e) {
      debugPrint('📊 Error starting performance profiling service: $e');
      rethrow;
    }
  }

  /// Stop performance profiling
  Future<void> stopProfiling() async {
    // Cancel timers
    _profilingTimer?.cancel();
    _profilingTimer = null;

    _diagnosticsTimer?.cancel();
    _diagnosticsTimer = null;

    // Stop frame monitoring
    _stopFrameMonitoring();

    // Close stream controllers
    await _profileController?.close();
    _profileController = null;

    await _diagnosticsController?.close();
    _diagnosticsController = null;

    await _frameAnalysisController?.close();
    _frameAnalysisController = null;

    _isActive = false;
    debugPrint('📊 Performance profiling service stopped');
  }

  /// Update configuration
  Future<void> updateConfig(PerformanceMonitoringConfig newConfig) async {
    _config = newConfig;
    debugPrint('📊 Performance profiling config updated');

    // Restart if needed
    if (_isActive) {
      await startProfiling(config: newConfig);
    }
  }

  /// Get performance analytics
  PerformanceAnalytics getPerformanceAnalytics() =>
      _generatePerformanceAnalytics();

  /// Get performance recommendations
  List<PerformanceRecommendation> getPerformanceRecommendations() {
    final recommendations = <PerformanceRecommendation>[];
    final currentProfile = this.currentProfile;

    if (currentProfile == null) return recommendations;

    // Frame rate recommendations
    if (currentProfile.frameRate < 45) {
      recommendations.add(PerformanceRecommendation(
        type: PerformanceIssueType.frameDrops,
        title: 'Improve Frame Rate',
        description:
            'Frame rate is below optimal. Consider reducing UI complexity or optimizing animations.',
        priority: currentProfile.frameRate < 30
            ? OptimizationPriority.high
            : OptimizationPriority.medium,
        impact: 80.0,
      ));
    }

    // Memory recommendations
    if (currentProfile.memoryUsage.isHigh) {
      recommendations.add(PerformanceRecommendation(
        type: PerformanceIssueType.memoryLeak,
        title: 'Optimize Memory Usage',
        description:
            'Memory usage is high. Consider clearing caches or reducing memory-intensive operations.',
        priority: currentProfile.memoryUsage.isCritical
            ? OptimizationPriority.critical
            : OptimizationPriority.high,
        impact: 70.0,
      ));
    }

    // CPU recommendations
    if (currentProfile.cpuUsage > 80) {
      recommendations.add(const PerformanceRecommendation(
        type: PerformanceIssueType.highCpuUsage,
        title: 'Reduce CPU Usage',
        description:
            'CPU usage is high. Consider optimizing algorithms or reducing background processing.',
        priority: OptimizationPriority.high,
        impact: 75.0,
      ));
    }

    // Battery recommendations
    if (currentProfile.batteryDrain > 15) {
      recommendations.add(const PerformanceRecommendation(
        type: PerformanceIssueType.excessiveBatteryDrain,
        title: 'Optimize Battery Usage',
        description:
            'Battery drain is high. Consider reducing GPS frequency or sensor usage.',
        priority: OptimizationPriority.medium,
        impact: 60.0,
      ));
    }

    // Jank recommendations
    if (currentProfile.jankPercentage > 5) {
      recommendations.add(PerformanceRecommendation(
        type: PerformanceIssueType.frameDrops,
        title: 'Reduce Frame Jank',
        description:
            'High percentage of janky frames detected. Optimize UI rendering and animations.',
        priority: currentProfile.jankPercentage > 10
            ? OptimizationPriority.high
            : OptimizationPriority.medium,
        impact: 65.0,
      ));
    }

    return recommendations;
  }

  /// Export performance data
  Future<String> exportPerformanceData() async {
    try {
      final analytics = getPerformanceAnalytics();
      final recommendations = getPerformanceRecommendations();

      final exportData = {
        'exportTime': DateTime.now().toIso8601String(),
        'profilingDuration':
            DateTime.now().difference(_profilingStartTime).inMinutes,
        'totalProfiles': _performanceHistory.length,
        'analytics': analytics.toMap(),
        'recommendations': recommendations.map((r) => r.toMap()).toList(),
        'profiles': _performanceHistory.map((p) => p.toMap()).toList(),
        'frameMetrics': _frameMetrics.map((f) => f.toMap()).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final exportFile = File('${directory.path}/performance_data_export.json');
      await exportFile.writeAsString(jsonString);

      debugPrint('📊 Performance data exported to: ${exportFile.path}');
      return exportFile.path;
    } catch (e) {
      debugPrint('📊 Error exporting performance data: $e');
      rethrow;
    }
  }

  /// Clear performance history
  void clearHistory() {
    _performanceHistory.clear();
    _frameMetrics.clear();
    _cpuUsageHistory.clear();
    _totalFrames = 0;
    _jankFrames = 0;
    _totalFrameTime = 0.0;
    debugPrint('📊 Performance profiling history cleared');
  }

  void _startFrameMonitoring() {
    _frameCallback = (Duration timestamp) {
      _onFrameRendered(timestamp);
      SchedulerBinding.instance.addPostFrameCallback(_frameCallback!);
    };

    SchedulerBinding.instance.addPostFrameCallback(_frameCallback!);
  }

  void _stopFrameMonitoring() {
    _frameCallback = null;
  }

  void _onFrameRendered(Duration timestamp) {
    final now = DateTime.now();
    final frameTime =
        now.difference(_lastFrameTime).inMicroseconds / 1000.0; // milliseconds

    _totalFrames++;
    _totalFrameTime += frameTime;

    // Check for jank (frames taking longer than 16.67ms for 60fps)
    if (frameTime > 16.67) {
      _jankFrames++;
    }

    // Store frame metrics
    final frameMetric = FrameMetrics(
      frameNumber: _totalFrames,
      renderTime: frameTime,
      timestamp: now,
      isJank: frameTime > 16.67,
    );

    _frameMetrics.add(frameMetric);
    if (_frameMetrics.length > _maxFrameMetricsLength) {
      _frameMetrics.removeAt(0);
    }

    _lastFrameTime = now;

    // Emit frame analysis periodically
    if (_totalFrames % 60 == 0) {
      // Every 60 frames
      _emitFrameAnalysis();
    }
  }

  void _emitFrameAnalysis() {
    if (_frameMetrics.isEmpty) return;

    final recentFrames = _frameMetrics.length > 60
        ? _frameMetrics.sublist(_frameMetrics.length - 60)
        : _frameMetrics;

    final averageFrameTime =
        recentFrames.map((f) => f.renderTime).reduce((a, b) => a + b) /
            recentFrames.length;

    final jankCount = recentFrames.where((f) => f.isJank).length;
    final jankPercentage = (jankCount / recentFrames.length) * 100;

    final frameAnalysis = FrameAnalysis(
      totalFrames: recentFrames.length,
      averageFrameTime: averageFrameTime,
      jankFrames: jankCount,
      jankPercentage: jankPercentage,
      frameRate: 1000 / averageFrameTime,
      timestamp: DateTime.now(),
    );

    _frameAnalysisController?.add(frameAnalysis);
  }

  Future<void> _collectPerformanceProfile() async {
    try {
      // Get memory usage
      final memoryUsage = _memoryService.currentMemoryUsage ??
          MemoryUsage(
            totalMemory: 0,
            usedMemory: 0,
            freeMemory: 0,
            appMemoryUsage: 0,
            timestamp: DateTime.now(),
          );

      // Estimate other metrics (in a real implementation, these would be measured)
      final cpuUsage = _estimateCpuUsage();
      final networkLatency = _estimateNetworkLatency();
      final diskIOTime = _estimateDiskIOTime();
      final batteryDrain = _estimateBatteryDrain();
      final gpuUsage = _estimateGpuUsage();

      final profile = PerformanceProfile(
        cpuUsage: cpuUsage,
        memoryUsage: memoryUsage,
        frameRenderTime:
            _totalFrames > 0 ? _totalFrameTime / _totalFrames : 0.0,
        networkLatency: networkLatency,
        diskIOTime: diskIOTime,
        batteryDrain: batteryDrain,
        timestamp: DateTime.now(),
        jankFrames: _jankFrames,
        totalFrames: _totalFrames,
        gpuUsage: gpuUsage,
      );

      // Add to history
      _performanceHistory.add(profile);
      if (_performanceHistory.length > _config.maxPerformanceProfiles) {
        _performanceHistory.removeAt(0);
      }

      // Emit profile
      _profileController?.add(profile);

      // Store CPU usage for trend analysis
      _storeCpuUsageHistory(cpuUsage);
    } catch (e) {
      debugPrint('📊 Error collecting performance profile: $e');
    }
  }

  double _estimateCpuUsage() {
    // In a real implementation, this would use platform channels to get actual CPU usage
    // For now, estimate based on frame performance and memory pressure
    double usage = 20.0; // Base usage

    if (_frameMetrics.isNotEmpty) {
      final recentFrames = _frameMetrics.length > 10
          ? _frameMetrics.sublist(_frameMetrics.length - 10)
          : _frameMetrics;

      final averageFrameTime =
          recentFrames.map((f) => f.renderTime).reduce((a, b) => a + b) /
              recentFrames.length;

      // Higher frame times suggest higher CPU usage
      if (averageFrameTime > 20)
        usage += 30;
      else if (averageFrameTime > 16.67) usage += 15;
    }

    // Memory pressure can indicate CPU usage
    final memoryUsage = _memoryService.currentMemoryUsage;
    if (memoryUsage?.isCritical == true)
      usage += 20;
    else if (memoryUsage?.isHigh == true) usage += 10;

    return usage.clamp(0.0, 100.0);
  }

  double _estimateNetworkLatency() =>
      // Placeholder - would measure actual network requests
      50.0; // 50ms estimate

  double _estimateDiskIOTime() =>
      // Placeholder - would measure actual disk operations
      10.0; // 10ms estimate

  double _estimateBatteryDrain() =>
      // Placeholder - would integrate with battery monitoring service
      8.0; // 8% per hour estimate

  double _estimateGpuUsage() =>
      // Placeholder - would use platform channels for GPU metrics
      25.0; // 25% estimate

  void _storeCpuUsageHistory(double cpuUsage) {
    const key = 'cpu_usage';
    _cpuUsageHistory[key] ??= [];
    _cpuUsageHistory[key]!.add(cpuUsage);

    // Keep only recent history
    if (_cpuUsageHistory[key]!.length > 100) {
      _cpuUsageHistory[key]!.removeAt(0);
    }
  }

  Future<void> _performDiagnostics() async {
    try {
      final diagnostics = _generatePerformanceDiagnostics();
      _diagnosticsController?.add(diagnostics);
    } catch (e) {
      debugPrint('📊 Error performing diagnostics: $e');
    }
  }

  PerformanceDiagnostics _generatePerformanceDiagnostics() {
    final issues = <PerformanceIssue>[];
    final recommendations = getPerformanceRecommendations();

    // Analyze performance trends
    if (_performanceHistory.length >= 10) {
      final recent =
          _performanceHistory.sublist(_performanceHistory.length - 10);

      // Check for degrading performance
      final averageScore =
          recent.map((p) => p.performanceScore).reduce((a, b) => a + b) /
              recent.length;
      if (averageScore < 60) {
        issues.add(PerformanceIssue(
          type: PerformanceIssueType.frameDrops,
          severity:
              averageScore < 40 ? IssueSeverity.critical : IssueSeverity.high,
          description: 'Overall performance score is declining',
          frequency: recent.length,
          impact: 100 - averageScore,
          recommendation:
              'Review recent changes and optimize performance bottlenecks',
        ));
      }

      // Check for memory growth
      final memoryTrend = _analyzeMemoryTrend(recent);
      if (memoryTrend == MemoryUsageTrend.rapidlyIncreasing) {
        issues.add(const PerformanceIssue(
          type: PerformanceIssueType.memoryLeak,
          severity: IssueSeverity.high,
          description: 'Memory usage is rapidly increasing',
          frequency: 1,
          impact: 80.0,
          recommendation: 'Check for memory leaks and optimize memory usage',
        ));
      }
    }

    return PerformanceDiagnostics(
      overallHealthScore: _calculateOverallHealthScore(),
      performanceGrade: _calculatePerformanceGrade(),
      identifiedIssues: issues,
      recommendations: recommendations,
      diagnosticsTime: DateTime.now(),
    );
  }

  PerformanceAnalytics _generatePerformanceAnalytics() {
    if (_performanceHistory.isEmpty) {
      return PerformanceAnalytics(
        averagePerformanceScore: 100.0,
        memoryUsageTrend: MemoryUsageTrend.stable,
        crashFrequency: 0.0,
        batteryEfficiencyScore: 100.0,
        frameRateConsistency: 100.0,
        topPerformanceIssues: [],
        optimizationRecommendations: [],
        generatedAt: DateTime.now(),
      );
    }

    final averageScore = _performanceHistory
            .map((p) => p.performanceScore)
            .reduce((a, b) => a + b) /
        _performanceHistory.length;

    final memoryTrend = _analyzeMemoryTrend(_performanceHistory);

    final batteryEfficiency = _calculateBatteryEfficiency();
    final frameRateConsistency = _calculateFrameRateConsistency();

    final topIssues = _identifyTopPerformanceIssues();
    final recommendations =
        getPerformanceRecommendations().map((r) => r.description).toList();

    return PerformanceAnalytics(
      averagePerformanceScore: averageScore,
      memoryUsageTrend: memoryTrend,
      crashFrequency: 0.0, // Would integrate with crash reporting service
      batteryEfficiencyScore: batteryEfficiency,
      frameRateConsistency: frameRateConsistency,
      topPerformanceIssues: topIssues,
      optimizationRecommendations: recommendations,
      generatedAt: DateTime.now(),
    );
  }

  MemoryUsageTrend _analyzeMemoryTrend(List<PerformanceProfile> profiles) {
    if (profiles.length < 5) return MemoryUsageTrend.stable;

    final memoryUsages =
        profiles.map((p) => p.memoryUsage.appUsagePercentage).toList();
    final first = memoryUsages.first;
    final last = memoryUsages.last;
    final change = last - first;

    if (change > 20) return MemoryUsageTrend.rapidlyIncreasing;
    if (change > 10) return MemoryUsageTrend.increasing;
    if (change < -10) return MemoryUsageTrend.decreasing;
    return MemoryUsageTrend.stable;
  }

  double _calculateBatteryEfficiency() {
    if (_performanceHistory.isEmpty) return 100.0;

    final averageDrain =
        _performanceHistory.map((p) => p.batteryDrain).reduce((a, b) => a + b) /
            _performanceHistory.length;

    // Efficient battery usage is < 5% per hour
    if (averageDrain <= 5) return 100.0;
    if (averageDrain <= 10) return 80.0;
    if (averageDrain <= 15) return 60.0;
    if (averageDrain <= 20) return 40.0;
    return 20.0;
  }

  double _calculateFrameRateConsistency() {
    if (_frameMetrics.isEmpty) return 100.0;

    final frameTimes = _frameMetrics.map((f) => f.renderTime).toList();
    final average = frameTimes.reduce((a, b) => a + b) / frameTimes.length;

    // Calculate variance
    final variance = frameTimes
            .map((time) => (time - average) * (time - average))
            .reduce((a, b) => a + b) /
        frameTimes.length;

    final standardDeviation = math.sqrt(variance);

    // Lower standard deviation = higher consistency
    final consistency = (20 - standardDeviation.clamp(0, 20)) / 20 * 100;
    return consistency.clamp(0.0, 100.0);
  }

  List<PerformanceIssue> _identifyTopPerformanceIssues() {
    final issues = <PerformanceIssue>[];

    if (_performanceHistory.isNotEmpty) {
      final recent = _performanceHistory.last;

      if (recent.frameRate < 45) {
        issues.add(PerformanceIssue(
          type: PerformanceIssueType.frameDrops,
          severity:
              recent.frameRate < 30 ? IssueSeverity.high : IssueSeverity.medium,
          description: 'Low frame rate detected',
          frequency: 1,
          impact: (60 - recent.frameRate) / 60 * 100,
        ));
      }

      if (recent.memoryUsage.isHigh) {
        issues.add(PerformanceIssue(
          type: PerformanceIssueType.memoryLeak,
          severity: recent.memoryUsage.isCritical
              ? IssueSeverity.critical
              : IssueSeverity.high,
          description: 'High memory usage detected',
          frequency: 1,
          impact: recent.memoryUsage.usagePercentage,
        ));
      }

      if (recent.cpuUsage > 80) {
        issues.add(PerformanceIssue(
          type: PerformanceIssueType.highCpuUsage,
          severity: IssueSeverity.high,
          description: 'High CPU usage detected',
          frequency: 1,
          impact: recent.cpuUsage,
        ));
      }
    }

    return issues;
  }

  double _calculateOverallHealthScore() {
    if (_performanceHistory.isEmpty) return 100.0;

    final recent = _performanceHistory.last;
    return recent.performanceScore;
  }

  PerformanceGrade _calculatePerformanceGrade() {
    final score = _calculateOverallHealthScore();
    if (score >= 90) return PerformanceGrade.excellent;
    if (score >= 75) return PerformanceGrade.good;
    if (score >= 60) return PerformanceGrade.fair;
    if (score >= 40) return PerformanceGrade.poor;
    return PerformanceGrade.critical;
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    stopProfiling();
    clearHistory();
    _instance = null;
  }
}

/// Frame metrics data
class FrameMetrics {
  const FrameMetrics({
    required this.frameNumber,
    required this.renderTime,
    required this.timestamp,
    required this.isJank,
  });

  final int frameNumber;
  final double renderTime; // milliseconds
  final DateTime timestamp;
  final bool isJank;

  Map<String, dynamic> toMap() => {
        'frameNumber': frameNumber,
        'renderTime': renderTime,
        'timestamp': timestamp.toIso8601String(),
        'isJank': isJank,
      };
}

/// Frame analysis data
class FrameAnalysis {
  const FrameAnalysis({
    required this.totalFrames,
    required this.averageFrameTime,
    required this.jankFrames,
    required this.jankPercentage,
    required this.frameRate,
    required this.timestamp,
  });

  final int totalFrames;
  final double averageFrameTime; // milliseconds
  final int jankFrames;
  final double jankPercentage;
  final double frameRate; // FPS
  final DateTime timestamp;

  /// Frame performance grade
  PerformanceGrade get frameGrade {
    if (frameRate >= 55 && jankPercentage < 2)
      return PerformanceGrade.excellent;
    if (frameRate >= 45 && jankPercentage < 5) return PerformanceGrade.good;
    if (frameRate >= 30 && jankPercentage < 10) return PerformanceGrade.fair;
    if (frameRate >= 20) return PerformanceGrade.poor;
    return PerformanceGrade.critical;
  }
}

/// Performance diagnostics data
class PerformanceDiagnostics {
  const PerformanceDiagnostics({
    required this.overallHealthScore,
    required this.performanceGrade,
    required this.identifiedIssues,
    required this.recommendations,
    required this.diagnosticsTime,
  });

  final double overallHealthScore;
  final PerformanceGrade performanceGrade;
  final List<PerformanceIssue> identifiedIssues;
  final List<PerformanceRecommendation> recommendations;
  final DateTime diagnosticsTime;

  /// Whether immediate action is required
  bool get requiresImmediateAction =>
      performanceGrade == PerformanceGrade.critical ||
      identifiedIssues.any((issue) => issue.severity == IssueSeverity.critical);
}

/// Performance recommendation
class PerformanceRecommendation {
  const PerformanceRecommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    required this.impact,
    this.estimatedEffort = OptimizationEffort.medium,
  });

  final PerformanceIssueType type;
  final String title;
  final String description;
  final OptimizationPriority priority;
  final double impact; // 0-100 scale
  final OptimizationEffort estimatedEffort;

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'title': title,
        'description': description,
        'priority': priority.name,
        'impact': impact,
        'estimatedEffort': estimatedEffort.name,
      };

  @override
  String toString() =>
      'PerformanceRecommendation($title: ${impact.toStringAsFixed(1)}% impact)';
}

/// Extension methods for PerformanceProfile
extension PerformanceProfileExtensions on PerformanceProfile {
  Map<String, dynamic> toMap() => {
        'cpuUsage': cpuUsage,
        'memoryUsage': {
          'totalMemory': memoryUsage.totalMemory,
          'usedMemory': memoryUsage.usedMemory,
          'appMemoryUsage': memoryUsage.appMemoryUsage,
          'usagePercentage': memoryUsage.usagePercentage,
        },
        'frameRenderTime': frameRenderTime,
        'networkLatency': networkLatency,
        'diskIOTime': diskIOTime,
        'batteryDrain': batteryDrain,
        'jankFrames': jankFrames,
        'totalFrames': totalFrames,
        'gpuUsage': gpuUsage,
        'frameRate': frameRate,
        'jankPercentage': jankPercentage,
        'performanceScore': performanceScore,
        'grade': grade.name,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Extension methods for PerformanceAnalytics
extension PerformanceAnalyticsExtensions on PerformanceAnalytics {
  Map<String, dynamic> toMap() => {
        'averagePerformanceScore': averagePerformanceScore,
        'memoryUsageTrend': memoryUsageTrend.name,
        'crashFrequency': crashFrequency,
        'batteryEfficiencyScore': batteryEfficiencyScore,
        'frameRateConsistency': frameRateConsistency,
        'topPerformanceIssues': topPerformanceIssues
            .map((i) => {
                  'type': i.type.name,
                  'severity': i.severity.name,
                  'description': i.description,
                  'frequency': i.frequency,
                  'impact': i.impact,
                })
            .toList(),
        'optimizationRecommendations': optimizationRecommendations,
        'generatedAt': generatedAt.toIso8601String(),
      };
}
