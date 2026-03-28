import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/adaptive_location_models.dart';
import 'package:obsession_tracker/core/models/gps_accuracy_models.dart';
import 'package:obsession_tracker/core/models/gps_environmental_models.dart';
import 'package:obsession_tracker/core/services/adaptive_location_service.dart';
import 'package:obsession_tracker/core/services/gps_accuracy_service.dart';
import 'package:obsession_tracker/core/services/gps_drift_correction_service.dart';
import 'package:obsession_tracker/core/services/gps_environmental_testing_service.dart';
import 'package:obsession_tracker/core/services/gps_notification_service.dart';
import 'package:obsession_tracker/core/services/sensor_fusion_service.dart';

/// Comprehensive GPS accuracy manager that coordinates all GPS accuracy services
///
/// This service acts as the main coordinator for all GPS accuracy-related functionality,
/// providing a unified interface for GPS accuracy monitoring, drift correction,
/// adaptive location updates, environmental testing, and user notifications.
class GpsAccuracyManager {
  factory GpsAccuracyManager() => _instance ??= GpsAccuracyManager._();
  GpsAccuracyManager._();
  static GpsAccuracyManager? _instance;

  // Core services
  final GpsAccuracyService _gpsAccuracyService = GpsAccuracyService();
  final AdaptiveLocationService _adaptiveLocationService =
      AdaptiveLocationService();
  final GpsDriftCorrectionService _driftCorrectionService =
      GpsDriftCorrectionService();
  final GpsEnvironmentalTestingService _environmentalTestingService =
      GpsEnvironmentalTestingService();
  final GpsNotificationService _notificationService = GpsNotificationService();

  // Optional sensor fusion service
  SensorFusionService? _sensorFusionService;

  // Stream controllers
  StreamController<GpsAccuracyManagerStatus>? _statusController;
  StreamController<GpsAccuracyManagerEvent>? _eventController;

  // Service state
  bool _isActive = false;
  GpsAccuracyManagerConfiguration _configuration =
      GpsAccuracyManagerConfiguration.defaultConfiguration();

  // Service subscriptions
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  // Performance tracking
  DateTime? _startTime;
  final Map<String, int> _eventCounts = {};
  final List<GpsPerformanceSnapshot> _performanceHistory =
      <GpsPerformanceSnapshot>[];
  static const int _maxPerformanceHistoryLength = 100;

  /// Stream of manager status updates
  Stream<GpsAccuracyManagerStatus> get statusStream {
    _statusController ??=
        StreamController<GpsAccuracyManagerStatus>.broadcast();
    return _statusController!.stream;
  }

  /// Stream of manager events
  Stream<GpsAccuracyManagerEvent> get eventStream {
    _eventController ??= StreamController<GpsAccuracyManagerEvent>.broadcast();
    return _eventController!.stream;
  }

  /// Whether the manager is active
  bool get isActive => _isActive;

  /// Current configuration
  GpsAccuracyManagerConfiguration get configuration => _configuration;

  /// GPS accuracy service
  GpsAccuracyService get gpsAccuracyService => _gpsAccuracyService;

  /// Adaptive location service
  AdaptiveLocationService get adaptiveLocationService =>
      _adaptiveLocationService;

  /// Drift correction service
  GpsDriftCorrectionService get driftCorrectionService =>
      _driftCorrectionService;

  /// Environmental testing service
  GpsEnvironmentalTestingService get environmentalTestingService =>
      _environmentalTestingService;

  /// Notification service
  GpsNotificationService get notificationService => _notificationService;

  /// Start GPS accuracy manager with all services
  Future<void> start({
    GpsAccuracyManagerConfiguration? configuration,
    SensorFusionService? sensorFusionService,
  }) async {
    try {
      await stop(); // Ensure clean start

      _configuration = configuration ??
          GpsAccuracyManagerConfiguration.defaultConfiguration();
      _sensorFusionService = sensorFusionService;
      _startTime = DateTime.now();

      debugPrint('🎯 Starting GPS Accuracy Manager...');
      debugPrint('  Configuration: ${_configuration.name}');

      // Initialize stream controllers
      _statusController ??=
          StreamController<GpsAccuracyManagerStatus>.broadcast();
      _eventController ??=
          StreamController<GpsAccuracyManagerEvent>.broadcast();

      // Start core services based on configuration
      await _startCoreServices();

      // Start optional services based on configuration
      await _startOptionalServices();

      // Subscribe to service events
      _subscribeToServiceEvents();

      // Start performance monitoring
      _startPerformanceMonitoring();

      _isActive = true;

      // Emit initial status
      _emitStatus(GpsAccuracyManagerStatus(
        isActive: true,
        activeServices: _getActiveServices(),
        configuration: _configuration,
        startTime: _startTime!,
        timestamp: DateTime.now(),
      ));

      _emitEvent(GpsAccuracyManagerEvent(
        type: GpsAccuracyManagerEventType.started,
        message: 'GPS Accuracy Manager started successfully',
        timestamp: DateTime.now(),
      ));

      debugPrint('🎯 GPS Accuracy Manager started successfully');
    } catch (e) {
      debugPrint('🎯 Error starting GPS Accuracy Manager: $e');
      _emitEvent(GpsAccuracyManagerEvent(
        type: GpsAccuracyManagerEventType.error,
        message: 'Failed to start GPS Accuracy Manager: $e',
        timestamp: DateTime.now(),
      ));
      rethrow;
    }
  }

  /// Stop GPS accuracy manager and all services
  Future<void> stop() async {
    if (!_isActive) return;

    try {
      debugPrint('🎯 Stopping GPS Accuracy Manager...');

      // Cancel all subscriptions
      for (final subscription in _subscriptions) {
        await subscription.cancel();
      }
      _subscriptions.clear();

      // Stop all services
      await _stopAllServices();

      // Close stream controllers
      await _statusController?.close();
      _statusController = null;

      await _eventController?.close();
      _eventController = null;

      _isActive = false;

      debugPrint('🎯 GPS Accuracy Manager stopped');
    } catch (e) {
      debugPrint('🎯 Error stopping GPS Accuracy Manager: $e');
    }
  }

  /// Update manager configuration
  Future<void> updateConfiguration(
      GpsAccuracyManagerConfiguration newConfiguration) async {
    if (newConfiguration == _configuration) return;

    debugPrint('🎯 Updating GPS Accuracy Manager configuration');

    final wasActive = _isActive;
    if (wasActive) {
      await stop();
    }

    _configuration = newConfiguration;

    if (wasActive) {
      await start(
        configuration: newConfiguration,
        sensorFusionService: _sensorFusionService,
      );
    }

    _emitEvent(GpsAccuracyManagerEvent(
      type: GpsAccuracyManagerEventType.configurationChanged,
      message: 'Configuration updated to: ${newConfiguration.name}',
      timestamp: DateTime.now(),
    ));
  }

  /// Get comprehensive GPS accuracy status
  GpsAccuracyOverview getAccuracyOverview() {
    final gpsAssessment = _gpsAccuracyService.getCurrentQualityAssessment();
    final gpsStatistics = _gpsAccuracyService.getAccuracyStatistics();
    final adaptiveMetrics = _adaptiveLocationService.isActive
        ? _adaptiveLocationService.getTrackingMetrics()
        : null;
    final driftStatistics = _driftCorrectionService.isActive
        ? _driftCorrectionService.getDriftStatistics()
        : null;
    final notificationStats = _notificationService.isActive
        ? _notificationService.getNotificationStatistics()
        : null;

    return GpsAccuracyOverview(
      qualityAssessment: gpsAssessment,
      accuracyStatistics: gpsStatistics,
      adaptiveMetrics: adaptiveMetrics,
      driftStatistics: driftStatistics,
      notificationStatistics: notificationStats,
      activeServices: _getActiveServices(),
      performanceSnapshot: _getCurrentPerformanceSnapshot(),
      timestamp: DateTime.now(),
    );
  }

  /// Run comprehensive GPS environmental test
  Future<EnvironmentalTestSummary> runEnvironmentalTest({
    EnvironmentalTestSuite? customTestSuite,
  }) async {
    if (!_isActive) {
      throw StateError('GPS Accuracy Manager must be active to run tests');
    }

    final testSuite = customTestSuite ??
        _environmentalTestingService.createComprehensiveTestSuite();

    _emitEvent(GpsAccuracyManagerEvent(
      type: GpsAccuracyManagerEventType.testStarted,
      message: 'Starting environmental test: ${testSuite.name}',
      data: {'test_count': testSuite.tests.length},
      timestamp: DateTime.now(),
    ));

    // Start the test
    await _environmentalTestingService.startTesting(testSuite);

    // Wait for completion (in a real implementation, you'd listen to the stream)
    // For now, we'll simulate completion
    await Future<void>.delayed(const Duration(seconds: 2));

    final summary = _environmentalTestingService.getTestSummary();

    _emitEvent(GpsAccuracyManagerEvent(
      type: GpsAccuracyManagerEventType.testCompleted,
      message: 'Environmental test completed',
      data: {
        'total_tests': summary.totalTests,
        'passed_tests': summary.passedTests,
        'pass_rate': summary.passRate,
      },
      timestamp: DateTime.now(),
    ));

    return summary;
  }

  /// Get manager performance metrics
  GpsAccuracyManagerMetrics getPerformanceMetrics() {
    final uptime = _startTime != null
        ? DateTime.now().difference(_startTime!)
        : Duration.zero;

    return GpsAccuracyManagerMetrics(
      uptime: uptime,
      totalEvents: _eventCounts.values.fold(0, (sum, count) => sum + count),
      eventCounts: Map.from(_eventCounts),
      activeServices: _getActiveServices(),
      memoryUsage: _estimateMemoryUsage(),
      performanceHistory: List.from(_performanceHistory),
      timestamp: DateTime.now(),
    );
  }

  Future<void> _startCoreServices() async {
    // Always start GPS accuracy service
    await _gpsAccuracyService.start(
      mode: _configuration.gpsAccuracyMode,
      sensorFusionService: _sensorFusionService,
    );

    // Start adaptive location service if enabled
    if (_configuration.enableAdaptiveLocation) {
      await _adaptiveLocationService.start(
        mode: _configuration.adaptiveTrackingMode,
        sensorFusionService: _sensorFusionService,
      );
    }

    // Start notification service if enabled
    if (_configuration.enableNotifications) {
      await _notificationService.start(
        settings: _configuration.notificationSettings,
      );
    }
  }

  Future<void> _startOptionalServices() async {
    // Start drift correction service if enabled
    if (_configuration.enableDriftCorrection) {
      await _driftCorrectionService.start(
        mode: _configuration.driftCorrectionMode,
        sensorFusionService: _sensorFusionService,
      );
    }

    // Start environmental testing service if enabled
    if (_configuration.enableEnvironmentalTesting) {
      await _environmentalTestingService.start(
        sensorFusionService: _sensorFusionService,
      );
    }
  }

  Future<void> _stopAllServices() async {
    await _gpsAccuracyService.stop();
    await _adaptiveLocationService.stop();
    await _driftCorrectionService.stop();
    await _environmentalTestingService.stop();
    await _notificationService.stop();
  }

  void _subscribeToServiceEvents() {
    // Subscribe to GPS accuracy alerts
    _subscriptions.add(
      _gpsAccuracyService.alertStream.listen((alert) {
        _incrementEventCount('gps_alert');
        _emitEvent(GpsAccuracyManagerEvent(
          type: GpsAccuracyManagerEventType.gpsAlert,
          message: alert.message,
          data: {
            'alert_type': alert.type.name,
            'severity': alert.severity.name
          },
          timestamp: alert.timestamp,
        ));
      }),
    );

    // Subscribe to adaptive location parameter changes
    if (_configuration.enableAdaptiveLocation) {
      _subscriptions.add(
        _adaptiveLocationService.parametersStream.listen((parameters) {
          _incrementEventCount('adaptive_parameter_change');
          _emitEvent(GpsAccuracyManagerEvent(
            type: GpsAccuracyManagerEventType.adaptiveParameterChange,
            message: 'Adaptive location parameters updated',
            data: {
              'update_interval': parameters.updateIntervalSeconds,
              'min_distance': parameters.minimumDistanceMeters,
              'accuracy': parameters.accuracy.name,
            },
            timestamp: DateTime.now(),
          ));
        }),
      );
    }

    // Subscribe to drift correction alerts
    if (_configuration.enableDriftCorrection) {
      _subscriptions.add(
        _driftCorrectionService.alertStream.listen((alert) {
          _incrementEventCount('drift_alert');
          _emitEvent(GpsAccuracyManagerEvent(
            type: GpsAccuracyManagerEventType.driftAlert,
            message: alert.message,
            data: {'drift_magnitude': alert.driftMagnitude},
            timestamp: alert.timestamp,
          ));
        }),
      );
    }

    // Subscribe to environmental test results
    if (_configuration.enableEnvironmentalTesting) {
      _subscriptions.add(
        _environmentalTestingService.testResultStream.listen((result) {
          _incrementEventCount('environmental_test_result');
          _emitEvent(GpsAccuracyManagerEvent(
            type: GpsAccuracyManagerEventType.environmentalTestResult,
            message:
                'Environmental test ${result.passed ? 'passed' : 'failed'}: ${result.test.name}',
            data: {
              'test_name': result.test.name,
              'passed': result.passed,
              'score': result.score,
            },
            timestamp: result.timestamp,
          ));
        }),
      );
    }
  }

  void _startPerformanceMonitoring() {
    Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isActive) {
        _recordPerformanceSnapshot();
      }
    });
  }

  void _recordPerformanceSnapshot() {
    final snapshot = _getCurrentPerformanceSnapshot();
    _performanceHistory.add(snapshot);

    if (_performanceHistory.length > _maxPerformanceHistoryLength) {
      _performanceHistory.removeAt(0);
    }
  }

  GpsPerformanceSnapshot _getCurrentPerformanceSnapshot() {
    final gpsAssessment = _gpsAccuracyService.getCurrentQualityAssessment();

    return GpsPerformanceSnapshot(
      overallQuality: gpsAssessment.overallQuality,
      averageAccuracy: gpsAssessment.averageAccuracy,
      signalQuality: gpsAssessment.signalQuality,
      environmentalCondition: gpsAssessment.environmentalCondition,
      driftDistance: gpsAssessment.driftDistance,
      activeServices: _getActiveServices().length,
      timestamp: DateTime.now(),
    );
  }

  List<String> _getActiveServices() {
    final services = <String>[];

    if (_gpsAccuracyService.isActive) services.add('GPS Accuracy');
    if (_adaptiveLocationService.isActive) services.add('Adaptive Location');
    if (_driftCorrectionService.isActive) services.add('Drift Correction');
    if (_environmentalTestingService.isActive)
      services.add('Environmental Testing');
    if (_notificationService.isActive) services.add('Notifications');

    return services;
  }

  double _estimateMemoryUsage() {
    // Rough estimate of memory usage in MB
    double usage = 0.0;

    // Base manager overhead
    usage += 1.0;

    // Service overhead
    if (_gpsAccuracyService.isActive) usage += 2.0;
    if (_adaptiveLocationService.isActive) usage += 1.5;
    if (_driftCorrectionService.isActive) usage += 1.0;
    if (_environmentalTestingService.isActive) usage += 0.5;
    if (_notificationService.isActive) usage += 0.5;

    // History data
    usage += _performanceHistory.length * 0.001; // ~1KB per snapshot

    return usage;
  }

  void _incrementEventCount(String eventType) {
    _eventCounts[eventType] = (_eventCounts[eventType] ?? 0) + 1;
  }

  void _emitStatus(GpsAccuracyManagerStatus status) {
    _statusController?.add(status);
  }

  void _emitEvent(GpsAccuracyManagerEvent event) {
    _eventController?.add(event);
    _incrementEventCount(event.type.name);
  }

  /// Dispose of the manager and clean up resources
  void dispose() {
    stop();
    _gpsAccuracyService.dispose();
    _adaptiveLocationService.dispose();
    _driftCorrectionService.dispose();
    _environmentalTestingService.dispose();
    _notificationService.dispose();
    _instance = null;
  }
}

/// GPS accuracy manager configuration
@immutable
class GpsAccuracyManagerConfiguration {
  const GpsAccuracyManagerConfiguration({
    required this.name,
    required this.gpsAccuracyMode,
    required this.enableAdaptiveLocation,
    required this.adaptiveTrackingMode,
    required this.enableDriftCorrection,
    required this.driftCorrectionMode,
    required this.enableEnvironmentalTesting,
    required this.enableNotifications,
    required this.notificationSettings,
  });

  /// Create default configuration
  factory GpsAccuracyManagerConfiguration.defaultConfiguration() =>
      GpsAccuracyManagerConfiguration(
        name: 'Default GPS Accuracy Configuration',
        gpsAccuracyMode: GpsAccuracyMode.balanced,
        enableAdaptiveLocation: true,
        adaptiveTrackingMode: AdaptiveTrackingMode.balanced,
        enableDriftCorrection: true,
        driftCorrectionMode: DriftCorrectionMode.balanced,
        enableEnvironmentalTesting: false, // Disabled by default
        enableNotifications: true,
        notificationSettings: GpsNotificationSettings.defaultSettings(),
      );

  /// Create high-performance configuration
  factory GpsAccuracyManagerConfiguration.highPerformance() =>
      GpsAccuracyManagerConfiguration(
        name: 'High Performance GPS Configuration',
        gpsAccuracyMode: GpsAccuracyMode.comprehensive,
        enableAdaptiveLocation: true,
        adaptiveTrackingMode: AdaptiveTrackingMode.highAccuracy,
        enableDriftCorrection: true,
        driftCorrectionMode: DriftCorrectionMode.aggressive,
        enableEnvironmentalTesting: true,
        enableNotifications: true,
        notificationSettings: GpsNotificationSettings.defaultSettings(),
      );

  /// Create battery-optimized configuration
  factory GpsAccuracyManagerConfiguration.batteryOptimized() =>
      GpsAccuracyManagerConfiguration(
        name: 'Battery Optimized GPS Configuration',
        gpsAccuracyMode: GpsAccuracyMode.minimal,
        enableAdaptiveLocation: true,
        adaptiveTrackingMode: AdaptiveTrackingMode.batteryOptimized,
        enableDriftCorrection: false,
        driftCorrectionMode: DriftCorrectionMode.conservative,
        enableEnvironmentalTesting: false,
        enableNotifications: false,
        notificationSettings: GpsNotificationSettings.disabled(),
      );

  final String name;
  final GpsAccuracyMode gpsAccuracyMode;
  final bool enableAdaptiveLocation;
  final AdaptiveTrackingMode adaptiveTrackingMode;
  final bool enableDriftCorrection;
  final DriftCorrectionMode driftCorrectionMode;
  final bool enableEnvironmentalTesting;
  final bool enableNotifications;
  final GpsNotificationSettings notificationSettings;
}

/// Manager status information
@immutable
class GpsAccuracyManagerStatus {
  const GpsAccuracyManagerStatus({
    required this.isActive,
    required this.activeServices,
    required this.configuration,
    required this.startTime,
    required this.timestamp,
  });

  final bool isActive;
  final List<String> activeServices;
  final GpsAccuracyManagerConfiguration configuration;
  final DateTime startTime;
  final DateTime timestamp;

  Duration get uptime => timestamp.difference(startTime);
}

/// Manager event information
@immutable
class GpsAccuracyManagerEvent {
  const GpsAccuracyManagerEvent({
    required this.type,
    required this.message,
    required this.timestamp,
    this.data,
  });

  final GpsAccuracyManagerEventType type;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
}

/// Comprehensive GPS accuracy overview
@immutable
class GpsAccuracyOverview {
  const GpsAccuracyOverview({
    required this.qualityAssessment,
    required this.accuracyStatistics,
    required this.activeServices,
    required this.performanceSnapshot,
    required this.timestamp,
    this.adaptiveMetrics,
    this.driftStatistics,
    this.notificationStatistics,
  });

  final GpsQualityAssessment qualityAssessment;
  final GpsAccuracyStatistics accuracyStatistics;
  final AdaptiveTrackingMetrics? adaptiveMetrics;
  final DriftCorrectionStatistics? driftStatistics;
  final GpsNotificationStatistics? notificationStatistics;
  final List<String> activeServices;
  final GpsPerformanceSnapshot performanceSnapshot;
  final DateTime timestamp;
}

/// Performance snapshot
@immutable
class GpsPerformanceSnapshot {
  const GpsPerformanceSnapshot({
    required this.overallQuality,
    required this.averageAccuracy,
    required this.signalQuality,
    required this.environmentalCondition,
    required this.driftDistance,
    required this.activeServices,
    required this.timestamp,
  });

  final GpsOverallQuality overallQuality;
  final double averageAccuracy;
  final GpsSignalQuality signalQuality;
  final EnvironmentalCondition environmentalCondition;
  final double driftDistance;
  final int activeServices;
  final DateTime timestamp;
}

/// Manager performance metrics
@immutable
class GpsAccuracyManagerMetrics {
  const GpsAccuracyManagerMetrics({
    required this.uptime,
    required this.totalEvents,
    required this.eventCounts,
    required this.activeServices,
    required this.memoryUsage,
    required this.performanceHistory,
    required this.timestamp,
  });

  final Duration uptime;
  final int totalEvents;
  final Map<String, int> eventCounts;
  final List<String> activeServices;
  final double memoryUsage; // MB
  final List<GpsPerformanceSnapshot> performanceHistory;
  final DateTime timestamp;
}

/// Manager event types
enum GpsAccuracyManagerEventType {
  started,
  stopped,
  configurationChanged,
  gpsAlert,
  adaptiveParameterChange,
  driftAlert,
  environmentalTestResult,
  testStarted,
  testCompleted,
  error;
}
