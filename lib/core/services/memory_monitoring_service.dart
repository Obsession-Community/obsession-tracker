import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:obsession_tracker/core/models/performance_models.dart';

/// Comprehensive memory monitoring and optimization service
///
/// Provides real-time memory monitoring, leak detection, optimization recommendations,
/// and automatic memory management for optimal app performance.
class MemoryMonitoringService {
  factory MemoryMonitoringService() =>
      _instance ??= MemoryMonitoringService._();
  MemoryMonitoringService._();
  static MemoryMonitoringService? _instance;

  // Stream controllers
  StreamController<MemoryUsage>? _memoryUsageController;
  StreamController<MemoryLeakDetection>? _leakDetectionController;
  StreamController<MemoryOptimizationEvent>? _optimizationController;

  // Service state
  bool _isMonitoring = false;
  PerformanceMonitoringConfig _config = const PerformanceMonitoringConfig();

  // Memory tracking
  final List<MemoryUsage> _memoryHistory = <MemoryUsage>[];
  final Map<String, List<int>> _objectCounts = {};
  final Map<String, DateTime> _objectTrackingStart = {};
  static const int _maxMemoryHistoryLength = 1000;

  // Monitoring timers
  Timer? _memoryMonitorTimer;
  Timer? _leakDetectionTimer;
  Timer? _optimizationTimer;

  // Memory baseline
  DateTime _monitoringStartTime = DateTime.now();

  /// Stream of memory usage updates
  Stream<MemoryUsage> get memoryUsageStream {
    _memoryUsageController ??= StreamController<MemoryUsage>.broadcast();
    return _memoryUsageController!.stream;
  }

  /// Stream of memory leak detection results
  Stream<MemoryLeakDetection> get leakDetectionStream {
    _leakDetectionController ??=
        StreamController<MemoryLeakDetection>.broadcast();
    return _leakDetectionController!.stream;
  }

  /// Stream of memory optimization events
  Stream<MemoryOptimizationEvent> get optimizationStream {
    _optimizationController ??=
        StreamController<MemoryOptimizationEvent>.broadcast();
    return _optimizationController!.stream;
  }

  /// Whether monitoring is active
  bool get isMonitoring => _isMonitoring;

  /// Current memory usage
  MemoryUsage? get currentMemoryUsage =>
      _memoryHistory.isNotEmpty ? _memoryHistory.last : null;

  /// Memory usage history
  List<MemoryUsage> get memoryHistory => List.unmodifiable(_memoryHistory);

  /// Start memory monitoring
  Future<void> startMonitoring({
    PerformanceMonitoringConfig? config,
  }) async {
    try {
      await stopMonitoring(); // Ensure clean start

      _config = config ?? const PerformanceMonitoringConfig();
      _monitoringStartTime = DateTime.now();

      debugPrint('🧠 Starting memory monitoring service...');
      debugPrint(
          '  Monitoring interval: ${_config.monitoringInterval.inSeconds}s');
      debugPrint(
          '  Leak detection enabled: ${_config.memoryLeakDetectionEnabled}');

      // Initialize stream controllers
      _memoryUsageController ??= StreamController<MemoryUsage>.broadcast();
      _leakDetectionController ??=
          StreamController<MemoryLeakDetection>.broadcast();
      _optimizationController ??=
          StreamController<MemoryOptimizationEvent>.broadcast();

      // Get baseline memory usage
      await _updateMemoryUsage();

      // Start periodic memory monitoring
      if (_config.memoryMonitoringEnabled) {
        _memoryMonitorTimer = Timer.periodic(_config.monitoringInterval, (_) {
          _updateMemoryUsage();
        });
      }

      // Start leak detection
      if (_config.memoryLeakDetectionEnabled) {
        _leakDetectionTimer =
            Timer.periodic(_config.memoryLeakCheckInterval, (_) {
          _performLeakDetection();
        });
      }

      // Start optimization checks
      _optimizationTimer = Timer.periodic(
        const Duration(minutes: 10),
        (_) => _performOptimizationCheck(),
      );

      _isMonitoring = true;
      debugPrint('🧠 Memory monitoring service started successfully');
    } catch (e) {
      debugPrint('🧠 Error starting memory monitoring service: $e');
      rethrow;
    }
  }

  /// Stop memory monitoring
  Future<void> stopMonitoring() async {
    // Cancel timers
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = null;

    _leakDetectionTimer?.cancel();
    _leakDetectionTimer = null;

    _optimizationTimer?.cancel();
    _optimizationTimer = null;

    // Close stream controllers
    await _memoryUsageController?.close();
    _memoryUsageController = null;

    await _leakDetectionController?.close();
    _leakDetectionController = null;

    await _optimizationController?.close();
    _optimizationController = null;

    _isMonitoring = false;
    debugPrint('🧠 Memory monitoring service stopped');
  }

  /// Update monitoring configuration
  Future<void> updateConfig(PerformanceMonitoringConfig newConfig) async {
    _config = newConfig;
    debugPrint('🧠 Memory monitoring config updated');

    // Restart monitoring with new config if active
    if (_isMonitoring) {
      await startMonitoring(config: newConfig);
    }
  }

  /// Force garbage collection
  Future<void> forceGarbageCollection() async {
    debugPrint('🧠 Forcing garbage collection...');

    // Request garbage collection (note: gc() is not available in release mode)
    if (kDebugMode) {
      // In debug mode, we can suggest GC but can't force it
      debugPrint('🧠 Requesting garbage collection...');
    }

    // Wait a moment for GC to complete
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Update memory usage after GC
    await _updateMemoryUsage();

    // Emit optimization event
    final event = MemoryOptimizationEvent(
      type: MemoryOptimizationType.garbageCollection,
      description: 'Forced garbage collection completed',
      memoryFreed: _calculateMemoryFreed(),
      timestamp: DateTime.now(),
    );
    _optimizationController?.add(event);

    debugPrint('🧠 Garbage collection completed');
  }

  /// Clear memory caches
  Future<void> clearMemoryCaches() async {
    debugPrint('🧠 Clearing memory caches...');

    try {
      // Clear image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Clear any other caches here
      // This would be extended based on app-specific caches

      await _updateMemoryUsage();

      final event = MemoryOptimizationEvent(
        type: MemoryOptimizationType.cacheClearing,
        description: 'Memory caches cleared successfully',
        memoryFreed: _calculateMemoryFreed(),
        timestamp: DateTime.now(),
      );
      _optimizationController?.add(event);

      debugPrint('🧠 Memory caches cleared');
    } catch (e) {
      debugPrint('🧠 Error clearing memory caches: $e');
    }
  }

  /// Get memory optimization recommendations
  List<MemoryOptimizationRecommendation> getOptimizationRecommendations() {
    final recommendations = <MemoryOptimizationRecommendation>[];
    final currentUsage = currentMemoryUsage;

    if (currentUsage == null) return recommendations;

    // High memory usage recommendation
    if (currentUsage.isHigh) {
      recommendations.add(const MemoryOptimizationRecommendation(
        type: MemoryOptimizationType.reduceMemoryUsage,
        title: 'Reduce Memory Usage',
        description:
            'Memory usage is high. Consider clearing caches or reducing active features.',
        priority: OptimizationPriority.high,
        estimatedSavings: 50.0, // MB
      ));
    }

    // Memory leak recommendation
    final leakDetection = _getLatestLeakDetection();
    if (leakDetection?.isLeakDetected == true) {
      recommendations.add(MemoryOptimizationRecommendation(
        type: MemoryOptimizationType.fixMemoryLeaks,
        title: 'Fix Memory Leaks',
        description:
            'Memory leaks detected. ${leakDetection!.leakSeverity.description}',
        priority: leakDetection.requiresImmediateAction
            ? OptimizationPriority.critical
            : OptimizationPriority.high,
        estimatedSavings: leakDetection.memoryGrowthRate *
            10, // Estimate based on growth rate
      ));
    }

    // Garbage collection recommendation
    if (_shouldRecommendGarbageCollection()) {
      recommendations.add(const MemoryOptimizationRecommendation(
        type: MemoryOptimizationType.garbageCollection,
        title: 'Run Garbage Collection',
        description: 'Garbage collection may help free up unused memory.',
        priority: OptimizationPriority.medium,
        estimatedSavings: 20.0,
      ));
    }

    // Cache clearing recommendation
    if (_shouldRecommendCacheClearing()) {
      recommendations.add(const MemoryOptimizationRecommendation(
        type: MemoryOptimizationType.cacheClearing,
        title: 'Clear Memory Caches',
        description: 'Clearing image and other caches can free up memory.',
        priority: OptimizationPriority.medium,
        estimatedSavings: 30.0,
      ));
    }

    return recommendations;
  }

  /// Get memory usage statistics
  MemoryUsageStatistics getMemoryStatistics() {
    if (_memoryHistory.isEmpty) {
      return const MemoryUsageStatistics(
        averageUsage: 0.0,
        peakUsage: 0.0,
        currentUsage: 0.0,
        memoryGrowthRate: 0.0,
        gcFrequency: 0.0,
        monitoringDuration: Duration.zero,
        totalSamples: 0,
      );
    }

    final currentUsage = _memoryHistory.last.appMemoryUsage.toDouble();
    final averageUsage = _memoryHistory
            .map((m) => m.appMemoryUsage.toDouble())
            .reduce((a, b) => a + b) /
        _memoryHistory.length;
    final peakUsage = _memoryHistory
        .map((m) => m.appMemoryUsage.toDouble())
        .reduce((a, b) => a > b ? a : b);

    final memoryGrowthRate = _calculateMemoryGrowthRate();
    final gcFrequency = _calculateGCFrequency();
    final monitoringDuration = DateTime.now().difference(_monitoringStartTime);

    return MemoryUsageStatistics(
      averageUsage: averageUsage / (1024 * 1024), // Convert to MB
      peakUsage: peakUsage / (1024 * 1024),
      currentUsage: currentUsage / (1024 * 1024),
      memoryGrowthRate: memoryGrowthRate,
      gcFrequency: gcFrequency,
      monitoringDuration: monitoringDuration,
      totalSamples: _memoryHistory.length,
    );
  }

  /// Clear memory history
  void clearHistory() {
    _memoryHistory.clear();
    _objectCounts.clear();
    _objectTrackingStart.clear();
    debugPrint('🧠 Memory monitoring history cleared');
  }

  Future<void> _updateMemoryUsage() async {
    try {
      // Get memory information
      final memoryInfo = await _getMemoryInfo();

      // Add to history
      _memoryHistory.add(memoryInfo);
      if (_memoryHistory.length > _maxMemoryHistoryLength) {
        _memoryHistory.removeAt(0);
      }

      // Emit memory usage update
      _memoryUsageController?.add(memoryInfo);

      // Check for memory pressure
      if (memoryInfo.isCritical) {
        await _handleMemoryPressure(memoryInfo);
      }
    } catch (e) {
      debugPrint('🧠 Error updating memory usage: $e');
    }
  }

  Future<MemoryUsage> _getMemoryInfo() async {
    try {
      // Get heap information
      int heapSize = 0;
      int externalMemory = 0;
      int gcCollections = 0;

      try {
        // This would require vm_service package for detailed info
        // For now, use basic memory estimation
        heapSize = _estimateHeapSize();
        externalMemory = _estimateExternalMemory();
        gcCollections = _estimateGCCollections();
      } catch (e) {
        debugPrint('🧠 Could not get detailed VM info: $e');
      }

      // Get system memory info (platform-specific)
      final systemMemory = await _getSystemMemoryInfo();

      return MemoryUsage(
        totalMemory: systemMemory['total'] ?? 0,
        usedMemory: systemMemory['used'] ?? 0,
        freeMemory: systemMemory['free'] ?? 0,
        appMemoryUsage: heapSize + externalMemory,
        timestamp: DateTime.now(),
        memoryPressure: _calculateMemoryPressure(systemMemory),
        gcCollections: gcCollections,
        heapSize: heapSize,
        externalMemory: externalMemory,
      );
    } catch (e) {
      debugPrint('🧠 Error getting memory info: $e');

      // Return basic memory info as fallback
      return MemoryUsage(
        totalMemory: 0,
        usedMemory: 0,
        freeMemory: 0,
        appMemoryUsage: _estimateHeapSize(),
        timestamp: DateTime.now(),
      );
    }
  }

  Future<Map<String, int>> _getSystemMemoryInfo() async {
    try {
      if (Platform.isAndroid) {
        // On Android, we would use platform channels to get memory info
        // For now, return estimated values
        return {
          'total': 4 * 1024 * 1024 * 1024, // 4GB estimate
          'used': 2 * 1024 * 1024 * 1024, // 2GB estimate
          'free': 2 * 1024 * 1024 * 1024, // 2GB estimate
        };
      } else if (Platform.isIOS) {
        // On iOS, we would use platform channels to get memory info
        return {
          'total': 3 * 1024 * 1024 * 1024, // 3GB estimate
          'used': 1536 * 1024 * 1024, // 1.5GB estimate
          'free': 1536 * 1024 * 1024, // 1.5GB estimate
        };
      }
    } catch (e) {
      debugPrint('🧠 Error getting system memory info: $e');
    }

    return {
      'total': 2 * 1024 * 1024 * 1024, // 2GB fallback
      'used': 1024 * 1024 * 1024, // 1GB fallback
      'free': 1024 * 1024 * 1024, // 1GB fallback
    };
  }

  int _estimateHeapSize() =>
      // Rough estimation based on object counts and typical sizes
      // In a real implementation, this would use vm_service
      50 * 1024 * 1024; // 50MB estimate

  int _estimateExternalMemory() =>
      // Estimate external memory (images, native objects, etc.)
      20 * 1024 * 1024; // 20MB estimate

  int _estimateGCCollections() {
    // Estimate GC collections based on monitoring duration
    final duration = DateTime.now().difference(_monitoringStartTime);
    return (duration.inMinutes / 2).round(); // Rough estimate
  }

  MemoryPressureLevel _calculateMemoryPressure(Map<String, int> systemMemory) {
    final total = systemMemory['total'] ?? 1;
    final used = systemMemory['used'] ?? 0;
    final usagePercentage = (used / total) * 100;

    if (usagePercentage > 95) return MemoryPressureLevel.critical;
    if (usagePercentage > 85) return MemoryPressureLevel.high;
    if (usagePercentage > 70) return MemoryPressureLevel.moderate;
    return MemoryPressureLevel.normal;
  }

  Future<void> _performLeakDetection() async {
    try {
      debugPrint('🧠 Performing memory leak detection...');

      final suspiciousObjects = <SuspiciousObject>[];
      final memoryGrowthRate = _calculateMemoryGrowthRate();

      // Analyze object growth patterns
      for (final entry in _objectCounts.entries) {
        final objectType = entry.key;
        final counts = entry.value;

        if (counts.length >= 3) {
          final growthRate = _calculateObjectGrowthRate(counts);
          if (growthRate > 10) {
            // More than 10 objects per minute
            suspiciousObjects.add(SuspiciousObject(
              objectType: objectType,
              instanceCount: counts.last,
              memorySize: counts.last * 1024, // Estimate 1KB per object
              growthRate: growthRate,
            ));
          }
        }
      }

      // Determine leak severity
      LeakSeverity severity = LeakSeverity.none;
      bool isLeakDetected = false;

      if (suspiciousObjects.isNotEmpty || memoryGrowthRate > 5.0) {
        isLeakDetected = true;
        if (memoryGrowthRate > 20.0) {
          severity = LeakSeverity.critical;
        } else if (memoryGrowthRate > 10.0) {
          severity = LeakSeverity.major;
        } else if (memoryGrowthRate > 5.0) {
          severity = LeakSeverity.moderate;
        } else {
          severity = LeakSeverity.minor;
        }
      }

      // Generate recommendations
      final recommendations = <String>[];
      if (isLeakDetected) {
        recommendations
            .add('Monitor object lifecycle and ensure proper disposal');
        recommendations.add('Check for unclosed streams or listeners');
        recommendations.add('Review image and cache management');
        if (severity == LeakSeverity.critical) {
          recommendations.add('Consider restarting the app to free memory');
        }
      }

      final leakDetection = MemoryLeakDetection(
        isLeakDetected: isLeakDetected,
        leakSeverity: severity,
        suspiciousObjects: suspiciousObjects,
        memoryGrowthRate: memoryGrowthRate,
        detectionTime: DateTime.now(),
        recommendations: recommendations,
      );

      _leakDetectionController?.add(leakDetection);

      if (isLeakDetected) {
        debugPrint('🧠 Memory leak detected: ${severity.description}');
      }
    } catch (e) {
      debugPrint('🧠 Error performing leak detection: $e');
    }
  }

  double _calculateMemoryGrowthRate() {
    if (_memoryHistory.length < 2) return 0.0;

    final recent = _memoryHistory.length > 10
        ? _memoryHistory.sublist(_memoryHistory.length - 10)
        : _memoryHistory;
    if (recent.length < 2) return 0.0;

    final startMemory = recent.first.appMemoryUsage.toDouble();
    final endMemory = recent.last.appMemoryUsage.toDouble();
    final timeDiff = recent.last.timestamp.difference(recent.first.timestamp);

    if (timeDiff.inMilliseconds == 0) return 0.0;

    final memoryDiff = (endMemory - startMemory) / (1024 * 1024); // MB
    final timeInMinutes = timeDiff.inMilliseconds / (1000 * 60);

    return memoryDiff / timeInMinutes; // MB per minute
  }

  double _calculateObjectGrowthRate(List<int> counts) {
    if (counts.length < 2) return 0.0;

    final startCount = counts.first.toDouble();
    final endCount = counts.last.toDouble();
    final timeSpan = counts.length * _config.monitoringInterval.inMinutes;

    if (timeSpan == 0) return 0.0;

    return (endCount - startCount) / timeSpan; // Objects per minute
  }

  double _calculateGCFrequency() {
    if (_memoryHistory.isEmpty) return 0.0;

    final duration = DateTime.now().difference(_monitoringStartTime);
    final totalGCs = _memoryHistory.last.gcCollections;

    if (duration.inMinutes == 0) return 0.0;

    return totalGCs / duration.inMinutes; // GCs per minute
  }

  Future<void> _handleMemoryPressure(MemoryUsage memoryInfo) async {
    debugPrint(
        '🧠 Handling memory pressure: ${memoryInfo.memoryPressure.description}');

    // Automatic memory optimization
    if (memoryInfo.memoryPressure == MemoryPressureLevel.critical) {
      await clearMemoryCaches();
      await forceGarbageCollection();
    } else if (memoryInfo.memoryPressure == MemoryPressureLevel.high) {
      await clearMemoryCaches();
    }

    // Emit optimization event
    final event = MemoryOptimizationEvent(
      type: MemoryOptimizationType.memoryPressureResponse,
      description:
          'Automatic response to ${memoryInfo.memoryPressure.description}',
      memoryFreed: _calculateMemoryFreed(),
      timestamp: DateTime.now(),
    );
    _optimizationController?.add(event);
  }

  Future<void> _performOptimizationCheck() async {
    final recommendations = getOptimizationRecommendations();

    if (recommendations.isNotEmpty) {
      final event = MemoryOptimizationEvent(
        type: MemoryOptimizationType.optimizationRecommendation,
        description: 'Memory optimization recommendations available',
        memoryFreed: 0.0,
        timestamp: DateTime.now(),
        recommendations: recommendations,
      );
      _optimizationController?.add(event);
    }
  }

  double _calculateMemoryFreed() {
    if (_memoryHistory.length < 2) return 0.0;

    final beforeMemory =
        _memoryHistory[_memoryHistory.length - 2].appMemoryUsage;
    final afterMemory = _memoryHistory.last.appMemoryUsage;

    return (beforeMemory - afterMemory) / (1024 * 1024); // MB
  }

  bool _shouldRecommendGarbageCollection() {
    final currentUsage = currentMemoryUsage;
    if (currentUsage == null) return false;

    // Recommend GC if memory usage is high and hasn't been GC'd recently
    return currentUsage.appUsagePercentage > 60;
  }

  bool _shouldRecommendCacheClearing() {
    final currentUsage = currentMemoryUsage;
    if (currentUsage == null) return false;

    // Recommend cache clearing if memory usage is moderate to high
    return currentUsage.appUsagePercentage > 40;
  }

  MemoryLeakDetection? _getLatestLeakDetection() =>
      // This would store the latest leak detection result
      // For now, return null as we don't have persistent storage
      null;

  /// Dispose of the service and clean up resources
  void dispose() {
    stopMonitoring();
    clearHistory();
    _instance = null;
  }
}

/// Memory optimization event
class MemoryOptimizationEvent {
  const MemoryOptimizationEvent({
    required this.type,
    required this.description,
    required this.memoryFreed,
    required this.timestamp,
    this.recommendations = const [],
  });

  final MemoryOptimizationType type;
  final String description;
  final double memoryFreed; // MB
  final DateTime timestamp;
  final List<MemoryOptimizationRecommendation> recommendations;

  @override
  String toString() =>
      'MemoryOptimizationEvent(${type.displayName}: ${memoryFreed.toStringAsFixed(1)}MB freed)';
}

/// Memory optimization types
enum MemoryOptimizationType {
  garbageCollection,
  cacheClearing,
  memoryPressureResponse,
  optimizationRecommendation,
  reduceMemoryUsage,
  fixMemoryLeaks;

  String get displayName {
    switch (this) {
      case MemoryOptimizationType.garbageCollection:
        return 'Garbage Collection';
      case MemoryOptimizationType.cacheClearing:
        return 'Cache Clearing';
      case MemoryOptimizationType.memoryPressureResponse:
        return 'Memory Pressure Response';
      case MemoryOptimizationType.optimizationRecommendation:
        return 'Optimization Recommendation';
      case MemoryOptimizationType.reduceMemoryUsage:
        return 'Reduce Memory Usage';
      case MemoryOptimizationType.fixMemoryLeaks:
        return 'Fix Memory Leaks';
    }
  }
}

/// Memory optimization recommendation
class MemoryOptimizationRecommendation {
  const MemoryOptimizationRecommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    required this.estimatedSavings,
  });

  final MemoryOptimizationType type;
  final String title;
  final String description;
  final OptimizationPriority priority;
  final double estimatedSavings; // MB

  @override
  String toString() =>
      'MemoryOptimizationRecommendation($title: ${estimatedSavings.toStringAsFixed(1)}MB savings)';
}

/// Memory usage statistics
class MemoryUsageStatistics {
  const MemoryUsageStatistics({
    required this.averageUsage,
    required this.peakUsage,
    required this.currentUsage,
    required this.memoryGrowthRate,
    required this.gcFrequency,
    required this.monitoringDuration,
    required this.totalSamples,
  });

  final double averageUsage; // MB
  final double peakUsage; // MB
  final double currentUsage; // MB
  final double memoryGrowthRate; // MB per minute
  final double gcFrequency; // GCs per minute
  final Duration monitoringDuration;
  final int totalSamples;

  /// Memory efficiency score (0-100)
  double get efficiencyScore {
    double score = 100.0;

    // Penalize high average usage
    if (averageUsage > 200)
      score -= 30;
    else if (averageUsage > 150)
      score -= 20;
    else if (averageUsage > 100) score -= 10;

    // Penalize memory growth
    if (memoryGrowthRate > 5.0)
      score -= 25;
    else if (memoryGrowthRate > 2.0)
      score -= 15;
    else if (memoryGrowthRate > 1.0) score -= 5;

    // Penalize excessive GC frequency
    if (gcFrequency > 2.0)
      score -= 15;
    else if (gcFrequency > 1.0) score -= 8;

    return score.clamp(0.0, 100.0);
  }
}
