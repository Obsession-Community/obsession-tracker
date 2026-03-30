import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/gps_accuracy_models.dart';
import 'package:obsession_tracker/core/models/gps_environmental_models.dart';
import 'package:obsession_tracker/core/services/gps_accuracy_manager.dart';
import 'package:obsession_tracker/core/services/sensor_fusion_service.dart';

/// Example demonstrating comprehensive GPS accuracy integration
///
/// This example shows how to:
/// 1. Initialize and configure the GPS accuracy manager
/// 2. Monitor GPS quality and environmental conditions
/// 3. Handle alerts and notifications
/// 4. Run environmental tests
/// 5. Integrate with sensor fusion for enhanced accuracy
class GpsAccuracyIntegrationExample {
  late GpsAccuracyManager _gpsManager;
  late SensorFusionService _sensorFusionService;

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  /// Initialize the GPS accuracy system
  Future<void> initialize() async {
    debugPrint('🎯 Initializing GPS Accuracy Integration Example');

    // Initialize sensor fusion service for enhanced accuracy
    _sensorFusionService = SensorFusionService();
    await _sensorFusionService.start();

    // Get GPS accuracy manager instance
    _gpsManager = GpsAccuracyManager();

    // Configure for high-performance GPS tracking
    final config = GpsAccuracyManagerConfiguration.highPerformance();

    // Start the GPS accuracy manager with sensor fusion
    await _gpsManager.start(
      configuration: config,
      sensorFusionService: _sensorFusionService,
    );

    // Set up monitoring and event handling
    _setupMonitoring();

    debugPrint('🎯 GPS Accuracy Integration initialized successfully');
  }

  /// Set up comprehensive monitoring of GPS accuracy
  void _setupMonitoring() {
    // Monitor GPS accuracy manager status
    _subscriptions.add(
      _gpsManager.statusStream.listen(_handleManagerStatus),
    );

    // Monitor GPS accuracy manager events
    _subscriptions.add(
      _gpsManager.eventStream.listen(_handleManagerEvent),
    );

    // Monitor GPS quality readings
    _subscriptions.add(
      _gpsManager.gpsAccuracyService.qualityStream
          .listen(_handleQualityReading),
    );

    // Monitor GPS accuracy alerts
    _subscriptions.add(
      _gpsManager.gpsAccuracyService.alertStream.listen(_handleGpsAlert),
    );

    // Monitor environmental condition changes
    _subscriptions.add(
      _gpsManager.gpsAccuracyService.environmentStream
          .listen(_handleEnvironmentChange),
    );

    // Monitor environmental test results if testing is enabled
    if (_gpsManager.environmentalTestingService.isActive) {
      _subscriptions.add(
        _gpsManager.environmentalTestingService.testResultStream
            .listen(_handleTestResult),
      );
    }
  }

  /// Handle GPS accuracy manager status updates
  void _handleManagerStatus(GpsAccuracyManagerStatus status) {
    debugPrint('🎯 Manager Status Update:');
    debugPrint('  Active: ${status.isActive}');
    debugPrint('  Uptime: ${status.uptime.inMinutes} minutes');
    debugPrint('  Active Services: ${status.activeServices.join(', ')}');
    debugPrint('  Configuration: ${status.configuration.name}');
  }

  /// Handle GPS accuracy manager events
  void _handleManagerEvent(GpsAccuracyManagerEvent event) {
    debugPrint('🎯 Manager Event: ${event.type.name}');
    debugPrint('  Message: ${event.message}');

    if (event.data != null) {
      debugPrint('  Data: ${event.data}');
    }

    // Handle specific event types
    switch (event.type) {
      case GpsAccuracyManagerEventType.gpsAlert:
        _handleManagerGpsAlert(event);
        break;
      case GpsAccuracyManagerEventType.testCompleted:
        _handleTestCompleted(event);
        break;
      case GpsAccuracyManagerEventType.error:
        _handleManagerError(event);
        break;
      default:
        break;
    }
  }

  /// Handle GPS quality readings
  void _handleQualityReading(GpsQualityReading reading) {
    debugPrint('🎯 GPS Quality Reading:');
    debugPrint('  Signal Quality: ${reading.signalQuality.name}');
    debugPrint('  Accuracy: ${reading.accuracy.toStringAsFixed(1)}m');
    debugPrint('  Speed: ${reading.speed.toStringAsFixed(1)} m/s');
    debugPrint('  Satellites: ${reading.satelliteCount}');
    debugPrint('  Environment: ${reading.environmentalCondition.name}');
    debugPrint('  Drift: ${reading.driftDistance.toStringAsFixed(1)}m');

    // Analyze quality and take action if needed
    _analyzeGpsQuality(reading);
  }

  /// Handle GPS accuracy alerts
  void _handleGpsAlert(GpsAccuracyAlert alert) {
    debugPrint('🚨 GPS Alert: ${alert.type.name}');
    debugPrint('  Severity: ${alert.severity.name}');
    debugPrint('  Message: ${alert.message}');

    // Take action based on alert severity
    switch (alert.severity) {
      case AlertSeverity.critical:
        _handleCriticalAlert(alert);
        break;
      case AlertSeverity.high:
        _handleHighSeverityAlert(alert);
        break;
      case AlertSeverity.medium:
        _handleMediumSeverityAlert(alert);
        break;
      case AlertSeverity.low:
        _handleLowSeverityAlert(alert);
        break;
    }
  }

  /// Handle environmental condition changes
  void _handleEnvironmentChange(EnvironmentalCondition condition) {
    debugPrint('🌍 Environment Changed: ${condition.name}');
    debugPrint('  Description: ${condition.description}');

    // Adjust GPS settings based on environment
    _adjustForEnvironment(condition);
  }

  /// Handle environmental test results
  void _handleTestResult(EnvironmentalTestResult result) {
    debugPrint('🧪 Test Result: ${result.test.name}');
    debugPrint('  Passed: ${result.passed}');
    debugPrint('  Score: ${result.score.toStringAsFixed(1)}');
    debugPrint('  Timestamp: ${result.timestamp}');
  }

  /// Analyze GPS quality and take appropriate action
  void _analyzeGpsQuality(GpsQualityReading reading) {
    // Check if GPS quality is poor
    if (reading.signalQuality == GpsSignalQuality.poor ||
        reading.signalQuality == GpsSignalQuality.unavailable) {
      debugPrint('⚠️ Poor GPS quality detected - taking corrective action');

      // Switch to more aggressive tracking mode
      _switchToHighAccuracyMode();
    }

    // Check for excessive drift
    if (reading.driftDistance > 20.0) {
      debugPrint('⚠️ Excessive GPS drift detected');

      // Enable drift correction if not already active
      if (!_gpsManager.driftCorrectionService.isActive) {
        _enableDriftCorrection();
      }
    }

    // Check for challenging environment
    if (_isChallengingEnvironment(reading.environmentalCondition)) {
      debugPrint('⚠️ Challenging GPS environment detected');

      // Run environmental test to assess conditions
      _runEnvironmentalAssessment();
    }
  }

  /// Handle critical GPS alerts
  void _handleCriticalAlert(GpsAccuracyAlert alert) {
    debugPrint('🚨 CRITICAL GPS ALERT: ${alert.message}');

    // Take immediate action for critical alerts
    switch (alert.type) {
      case GpsAlertType.locationServiceError:
        _handleLocationServiceError();
        break;
      case GpsAlertType.weakSignal:
        _handleWeakSignal();
        break;
      default:
        _handleGenericCriticalAlert(alert);
        break;
    }
  }

  /// Handle high severity GPS alerts
  void _handleHighSeverityAlert(GpsAccuracyAlert alert) {
    debugPrint('⚠️ HIGH SEVERITY GPS ALERT: ${alert.message}');

    // Adjust GPS settings for high severity issues
    _switchToHighAccuracyMode();
  }

  /// Handle medium severity GPS alerts
  void _handleMediumSeverityAlert(GpsAccuracyAlert alert) {
    debugPrint('⚠️ MEDIUM SEVERITY GPS ALERT: ${alert.message}');

    // Log and monitor medium severity issues
    _logGpsIssue(alert);
  }

  /// Handle low severity GPS alerts
  void _handleLowSeverityAlert(GpsAccuracyAlert alert) {
    debugPrint('ℹ️ LOW SEVERITY GPS ALERT: ${alert.message}');

    // Just log low severity issues
    _logGpsIssue(alert);
  }

  /// Adjust GPS settings based on environmental conditions
  void _adjustForEnvironment(EnvironmentalCondition condition) {
    switch (condition) {
      case EnvironmentalCondition.indoor:
      case EnvironmentalCondition.underground:
        // Switch to battery-optimized mode indoors
        _switchToBatteryOptimizedMode();
        break;
      case EnvironmentalCondition.urbanCanyon:
      case EnvironmentalCondition.denseForest:
        // Use high-accuracy mode in challenging environments
        _switchToHighAccuracyMode();
        break;
      case EnvironmentalCondition.openArea:
        // Use balanced mode in open areas
        _switchToBalancedMode();
        break;
      default:
        // Keep current settings for unknown environments
        break;
    }
  }

  /// Switch to high accuracy GPS mode
  Future<void> _switchToHighAccuracyMode() async {
    debugPrint('🎯 Switching to high accuracy GPS mode');

    final config = GpsAccuracyManagerConfiguration.highPerformance();
    await _gpsManager.updateConfiguration(config);
  }

  /// Switch to battery optimized GPS mode
  Future<void> _switchToBatteryOptimizedMode() async {
    debugPrint('🔋 Switching to battery optimized GPS mode');

    final config = GpsAccuracyManagerConfiguration.batteryOptimized();
    await _gpsManager.updateConfiguration(config);
  }

  /// Switch to balanced GPS mode
  Future<void> _switchToBalancedMode() async {
    debugPrint('⚖️ Switching to balanced GPS mode');

    final config = GpsAccuracyManagerConfiguration.defaultConfiguration();
    await _gpsManager.updateConfiguration(config);
  }

  /// Enable drift correction
  Future<void> _enableDriftCorrection() async {
    debugPrint('📍 Enabling GPS drift correction');

    if (!_gpsManager.driftCorrectionService.isActive) {
      await _gpsManager.driftCorrectionService.start(
        sensorFusionService: _sensorFusionService,
      );
    }
  }

  /// Run environmental assessment
  Future<void> _runEnvironmentalAssessment() async {
    debugPrint('🧪 Running environmental GPS assessment');

    try {
      final summary = await _gpsManager.runEnvironmentalTest();

      debugPrint('🧪 Environmental Assessment Results:');
      debugPrint('  Total Tests: ${summary.totalTests}');
      debugPrint('  Passed: ${summary.passedTests}');
      debugPrint('  Failed: ${summary.failedTests}');
      debugPrint('  Pass Rate: ${summary.passRate.toStringAsFixed(1)}%');

      // Take action based on test results
      if (summary.passRate < 50.0) {
        debugPrint('⚠️ Poor environmental conditions detected');
        _handlePoorEnvironmentalConditions();
      }
    } catch (e) {
      debugPrint('❌ Environmental assessment failed: $e');
    }
  }

  /// Get comprehensive GPS status report
  GpsStatusReport getStatusReport() {
    final overview = _gpsManager.getAccuracyOverview();
    final metrics = _gpsManager.getPerformanceMetrics();

    return GpsStatusReport(
      overview: overview,
      metrics: metrics,
      timestamp: DateTime.now(),
    );
  }

  /// Print comprehensive GPS status
  void printStatus() {
    final report = getStatusReport();

    debugPrint('📊 GPS Accuracy Status Report');
    debugPrint('=' * 50);

    // Overall quality
    final assessment = report.overview.qualityAssessment;
    debugPrint('Overall Quality: ${assessment.overallQuality.name}');
    debugPrint('Signal Quality: ${assessment.signalQuality.name}');
    debugPrint(
        'Average Accuracy: ${assessment.averageAccuracy.toStringAsFixed(1)}m');
    debugPrint(
        'Drift Distance: ${assessment.driftDistance.toStringAsFixed(1)}m');
    debugPrint('Environment: ${assessment.environmentalCondition.name}');
    debugPrint('Summary Score: ${assessment.summaryScore}/100');

    // Statistics
    final stats = report.overview.accuracyStatistics;
    debugPrint('\nStatistics:');
    debugPrint('Sample Count: ${stats.sampleCount}');
    debugPrint('Mean Accuracy: ${stats.meanAccuracy.toStringAsFixed(1)}m');
    debugPrint('Best Accuracy: ${stats.minAccuracy.toStringAsFixed(1)}m');
    debugPrint('Worst Accuracy: ${stats.maxAccuracy.toStringAsFixed(1)}m');

    // Performance
    debugPrint('\nPerformance:');
    debugPrint('Uptime: ${report.metrics.uptime.inMinutes} minutes');
    debugPrint('Total Events: ${report.metrics.totalEvents}');
    debugPrint(
        'Memory Usage: ${report.metrics.memoryUsage.toStringAsFixed(1)} MB');
    debugPrint('Active Services: ${report.overview.activeServices.join(', ')}');

    // Recommendations
    debugPrint('\nRecommendations:');
    for (final action in assessment.recommendedActions) {
      debugPrint('• $action');
    }

    debugPrint('=' * 50);
  }

  /// Handle manager GPS alerts
  void _handleManagerGpsAlert(GpsAccuracyManagerEvent event) {
    debugPrint('🚨 Manager GPS Alert: ${event.message}');

    // Extract alert details from event data
    final alertType = event.data?['alert_type'] as String?;
    final severity = event.data?['severity'] as String?;

    debugPrint('  Alert Type: $alertType');
    debugPrint('  Severity: $severity');
  }

  /// Handle test completion
  void _handleTestCompleted(GpsAccuracyManagerEvent event) {
    debugPrint('✅ Environmental Test Completed');

    final totalTests = event.data?['total_tests'] as int?;
    final passedTests = event.data?['passed_tests'] as int?;
    final passRate = event.data?['pass_rate'] as double?;

    debugPrint('  Total Tests: $totalTests');
    debugPrint('  Passed Tests: $passedTests');
    debugPrint('  Pass Rate: ${passRate?.toStringAsFixed(1)}%');
  }

  /// Handle manager errors
  void _handleManagerError(GpsAccuracyManagerEvent event) {
    debugPrint('❌ GPS Manager Error: ${event.message}');

    // Attempt recovery
    _attemptRecovery();
  }

  /// Handle location service errors
  void _handleLocationServiceError() {
    debugPrint('❌ Location service error - attempting restart');

    // Restart GPS accuracy service
    _restartGpsService();
  }

  /// Handle weak GPS signal
  void _handleWeakSignal() {
    debugPrint('📡 Weak GPS signal - adjusting settings');

    // Switch to high accuracy mode to improve signal
    _switchToHighAccuracyMode();
  }

  /// Handle generic critical alerts
  void _handleGenericCriticalAlert(GpsAccuracyAlert alert) {
    debugPrint('🚨 Generic critical alert: ${alert.message}');

    // Log critical issue and attempt recovery
    _logCriticalIssue(alert);
    _attemptRecovery();
  }

  /// Log GPS issues
  void _logGpsIssue(GpsAccuracyAlert alert) {
    debugPrint('📝 Logging GPS issue: ${alert.type.name} - ${alert.message}');

    // In a real app, this would log to analytics or crash reporting
  }

  /// Log critical issues
  void _logCriticalIssue(GpsAccuracyAlert alert) {
    debugPrint(
        '📝 Logging CRITICAL GPS issue: ${alert.type.name} - ${alert.message}');

    // In a real app, this would immediately report to crash analytics
  }

  /// Handle poor environmental conditions
  void _handlePoorEnvironmentalConditions() {
    debugPrint('🌍 Handling poor environmental conditions');

    // Switch to high accuracy mode and enable all features
    _switchToHighAccuracyMode();
    _enableDriftCorrection();
  }

  /// Check if environment is challenging for GPS
  bool _isChallengingEnvironment(EnvironmentalCondition condition) => [
        EnvironmentalCondition.indoor,
        EnvironmentalCondition.underground,
        EnvironmentalCondition.urbanCanyon,
        EnvironmentalCondition.denseForest,
      ].contains(condition);

  /// Attempt recovery from GPS issues
  Future<void> _attemptRecovery() async {
    debugPrint('🔄 Attempting GPS system recovery');

    try {
      // Stop and restart the GPS manager
      await _gpsManager.stop();
      await Future<void>.delayed(const Duration(seconds: 2));
      await _gpsManager.start(
        configuration: GpsAccuracyManagerConfiguration.defaultConfiguration(),
        sensorFusionService: _sensorFusionService,
      );

      debugPrint('✅ GPS system recovery successful');
    } catch (e) {
      debugPrint('❌ GPS system recovery failed: $e');
    }
  }

  /// Restart GPS service
  Future<void> _restartGpsService() async {
    debugPrint('🔄 Restarting GPS accuracy service');

    try {
      await _gpsManager.gpsAccuracyService.stop();
      await Future<void>.delayed(const Duration(seconds: 1));
      await _gpsManager.gpsAccuracyService.start(
        sensorFusionService: _sensorFusionService,
      );

      debugPrint('✅ GPS accuracy service restart successful');
    } catch (e) {
      debugPrint('❌ GPS accuracy service restart failed: $e');
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    debugPrint('🧹 Disposing GPS Accuracy Integration Example');

    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    // Stop GPS manager
    await _gpsManager.stop();
    _gpsManager.dispose();

    // Stop sensor fusion service
    await _sensorFusionService.stop();
    _sensorFusionService.dispose();

    debugPrint('✅ GPS Accuracy Integration Example disposed');
  }
}

/// GPS status report containing comprehensive information
@immutable
class GpsStatusReport {
  const GpsStatusReport({
    required this.overview,
    required this.metrics,
    required this.timestamp,
  });

  final GpsAccuracyOverview overview;
  final GpsAccuracyManagerMetrics metrics;
  final DateTime timestamp;
}

/// Example usage function
Future<void> runGpsAccuracyExample() async {
  final example = GpsAccuracyIntegrationExample();

  try {
    // Initialize the GPS accuracy system
    await example.initialize();

    // Let it run for a while to collect data
    debugPrint('🎯 Running GPS accuracy monitoring for 30 seconds...');
    await Future<void>.delayed(const Duration(seconds: 30));

    // Print comprehensive status
    example.printStatus();

    // Run environmental test
    debugPrint('🧪 Running environmental test...');
    // This would be called automatically by the example based on conditions

    // Let it run a bit more
    await Future<void>.delayed(const Duration(seconds: 10));

    // Final status
    example.printStatus();
  } finally {
    // Clean up
    await example.dispose();
  }
}
