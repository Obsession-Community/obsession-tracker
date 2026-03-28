import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/gps_accuracy_models.dart';
import 'package:obsession_tracker/core/models/gps_environmental_models.dart';
import 'package:obsession_tracker/core/services/gps_accuracy_service.dart';
import 'package:obsession_tracker/core/services/sensor_fusion_service.dart';

/// GPS environmental testing service for accuracy assessment in various conditions
///
/// Provides comprehensive testing framework to evaluate GPS performance across
/// different environmental conditions including urban, forest, mountain, indoor,
/// and other challenging scenarios.
class GpsEnvironmentalTestingService {
  factory GpsEnvironmentalTestingService() =>
      _instance ??= GpsEnvironmentalTestingService._();
  GpsEnvironmentalTestingService._();
  static GpsEnvironmentalTestingService? _instance;

  final GpsAccuracyService _gpsAccuracyService = GpsAccuracyService();
  SensorFusionService? _sensorFusionService;

  // Stream controllers
  StreamController<EnvironmentalTestResult>? _testResultController;
  StreamController<TestProgressUpdate>? _progressController;

  // Service state
  bool _isActive = false;
  bool _isTestingActive = false;
  EnvironmentalTestSuite? _currentTestSuite;

  // Test tracking
  final List<EnvironmentalTestResult> _testResults =
      <EnvironmentalTestResult>[];
  final Map<EnvironmentalCondition, List<GpsPerformanceMetrics>>
      _performanceByEnvironment = {};

  // Current test state
  EnvironmentalTest? _currentTest;
  DateTime? _testStartTime;
  int _currentTestIndex = 0;
  Timer? _testTimer;

  /// Stream of environmental test results
  Stream<EnvironmentalTestResult> get testResultStream {
    _testResultController ??=
        StreamController<EnvironmentalTestResult>.broadcast();
    return _testResultController!.stream;
  }

  /// Stream of test progress updates
  Stream<TestProgressUpdate> get progressStream {
    _progressController ??= StreamController<TestProgressUpdate>.broadcast();
    return _progressController!.stream;
  }

  /// Whether the service is active
  bool get isActive => _isActive;

  /// Whether testing is currently active
  bool get isTestingActive => _isTestingActive;

  /// Current test suite
  EnvironmentalTestSuite? get currentTestSuite => _currentTestSuite;

  /// All test results
  List<EnvironmentalTestResult> get testResults =>
      List.unmodifiable(_testResults);

  /// Start environmental testing service
  Future<void> start({
    SensorFusionService? sensorFusionService,
  }) async {
    try {
      await stop(); // Ensure clean start

      _sensorFusionService = sensorFusionService;

      debugPrint('🧪 Starting GPS environmental testing service...');

      // Initialize stream controllers
      _testResultController ??=
          StreamController<EnvironmentalTestResult>.broadcast();
      _progressController ??= StreamController<TestProgressUpdate>.broadcast();

      // Start GPS accuracy monitoring
      await _gpsAccuracyService.start(
        mode: GpsAccuracyMode.comprehensive,
        sensorFusionService: _sensorFusionService,
      );

      _isActive = true;
      debugPrint('🧪 GPS environmental testing service started successfully');
    } catch (e) {
      debugPrint('🧪 Error starting GPS environmental testing service: $e');
      rethrow;
    }
  }

  /// Stop environmental testing service
  Future<void> stop() async {
    // Stop any active test
    await stopTesting();

    // Stop GPS accuracy service
    await _gpsAccuracyService.stop();

    // Close stream controllers
    await _testResultController?.close();
    _testResultController = null;

    await _progressController?.close();
    _progressController = null;

    _isActive = false;
    debugPrint('🧪 GPS environmental testing service stopped');
  }

  /// Start environmental testing with a predefined test suite
  Future<void> startTesting(EnvironmentalTestSuite testSuite) async {
    if (!_isActive) {
      throw StateError('Service must be started before testing');
    }

    if (_isTestingActive) {
      throw StateError('Testing is already active');
    }

    try {
      _currentTestSuite = testSuite;
      _isTestingActive = true;
      _currentTestIndex = 0;

      debugPrint('🧪 Starting environmental test suite: ${testSuite.name}');
      debugPrint('  Tests: ${testSuite.tests.length}');

      // Start first test
      await _startNextTest();
    } catch (e) {
      debugPrint('🧪 Error starting environmental testing: $e');
      _isTestingActive = false;
      rethrow;
    }
  }

  /// Stop environmental testing
  Future<void> stopTesting() async {
    if (!_isTestingActive) return;

    // Stop current test
    _testTimer?.cancel();
    _testTimer = null;

    // Finalize current test if active
    if (_currentTest != null) {
      await _finalizeCurrentTest();
    }

    _isTestingActive = false;
    _currentTestSuite = null;
    _currentTest = null;
    _currentTestIndex = 0;

    debugPrint('🧪 Environmental testing stopped');
  }

  /// Create a comprehensive test suite for all environments
  EnvironmentalTestSuite createComprehensiveTestSuite() {
    final tests = <EnvironmentalTest>[];

    // Add tests for each environment type
    for (final environment in EnvironmentalCondition.values) {
      if (environment != EnvironmentalCondition.unknown) {
        tests.add(EnvironmentalTest(
          name: '${environment.description} Test',
          environment: environment,
          duration: const Duration(minutes: 5),
          expectedConditions: _getExpectedConditionsForEnvironment(environment),
          testParameters: _getTestParametersForEnvironment(environment),
        ));
      }
    }

    return EnvironmentalTestSuite(
      name: 'Comprehensive GPS Environmental Test Suite',
      description: 'Tests GPS accuracy across all environmental conditions',
      tests: tests,
      estimatedDuration: Duration(
        milliseconds:
            tests.map((t) => t.duration.inMilliseconds).reduce((a, b) => a + b),
      ),
    );
  }

  /// Create a quick test suite for basic environments
  EnvironmentalTestSuite createQuickTestSuite() => const EnvironmentalTestSuite(
        name: 'Quick GPS Environmental Test Suite',
        description: 'Quick tests for common environmental conditions',
        tests: [
          EnvironmentalTest(
            name: 'Open Area Test',
            environment: EnvironmentalCondition.openArea,
            duration: Duration(minutes: 2),
            expectedConditions: ExpectedTestConditions(
              minAccuracy: 3.0,
              maxAccuracy: 8.0,
              minSignalStrength: 80.0,
              expectedDriftLevel: GpsDriftLevel.minimal,
            ),
            testParameters: TestParameters(
              updateInterval: 5,
              minimumSamples: 24,
              accuracyThreshold: 10.0,
            ),
          ),
          EnvironmentalTest(
            name: 'Urban Test',
            environment: EnvironmentalCondition.urban,
            duration: Duration(minutes: 3),
            expectedConditions: ExpectedTestConditions(
              minAccuracy: 5.0,
              maxAccuracy: 15.0,
              minSignalStrength: 60.0,
              expectedDriftLevel: GpsDriftLevel.low,
            ),
            testParameters: TestParameters(
              updateInterval: 5,
              minimumSamples: 36,
              accuracyThreshold: 20.0,
            ),
          ),
          EnvironmentalTest(
            name: 'Indoor Test',
            environment: EnvironmentalCondition.indoor,
            duration: Duration(minutes: 2),
            expectedConditions: ExpectedTestConditions(
              minAccuracy: 20.0,
              maxAccuracy: 100.0,
              minSignalStrength: 20.0,
              expectedDriftLevel: GpsDriftLevel.high,
            ),
            testParameters: TestParameters(
              updateInterval: 10,
              minimumSamples: 12,
              accuracyThreshold: 50.0,
            ),
          ),
        ],
        estimatedDuration: Duration(minutes: 7),
      );

  /// Get test results summary for all environments
  EnvironmentalTestSummary getTestSummary() {
    final summaryByEnvironment =
        <EnvironmentalCondition, EnvironmentTestSummary>{};

    for (final environment in EnvironmentalCondition.values) {
      final environmentResults =
          _testResults.where((r) => r.test.environment == environment).toList();

      if (environmentResults.isNotEmpty) {
        summaryByEnvironment[environment] = _createEnvironmentSummary(
          environment,
          environmentResults,
        );
      }
    }

    return EnvironmentalTestSummary(
      totalTests: _testResults.length,
      passedTests: _testResults.where((r) => r.passed).length,
      failedTests: _testResults.where((r) => !r.passed).length,
      averageAccuracy: _calculateOverallAverageAccuracy(),
      bestEnvironment: _getBestEnvironment(),
      worstEnvironment: _getWorstEnvironment(),
      summaryByEnvironment: summaryByEnvironment,
      timestamp: DateTime.now(),
    );
  }

  Future<void> _startNextTest() async {
    if (_currentTestSuite == null ||
        _currentTestIndex >= _currentTestSuite!.tests.length) {
      // All tests completed
      await _completeTestSuite();
      return;
    }

    _currentTest = _currentTestSuite!.tests[_currentTestIndex];
    _testStartTime = DateTime.now();

    debugPrint(
        '🧪 Starting test ${_currentTestIndex + 1}/${_currentTestSuite!.tests.length}: ${_currentTest!.name}');

    // Emit progress update
    _progressController?.add(TestProgressUpdate(
      currentTestIndex: _currentTestIndex,
      totalTests: _currentTestSuite!.tests.length,
      currentTest: _currentTest,
      progress: _currentTestIndex / _currentTestSuite!.tests.length,
      estimatedTimeRemaining: _calculateRemainingTime(),
      timestamp: DateTime.now(),
    ));

    // Start test timer
    _testTimer = Timer(_currentTest!.duration, _finalizeCurrentTest);
  }

  Future<void> _finalizeCurrentTest() async {
    if (_currentTest == null || _testStartTime == null) return;

    try {
      // Collect GPS performance data
      final performanceMetrics = await _collectPerformanceMetrics();

      // Evaluate test results
      final testResult = _evaluateTestResult(_currentTest!, performanceMetrics);

      // Store results
      _testResults.add(testResult);
      _storePerformanceMetrics(_currentTest!.environment, performanceMetrics);

      // Emit test result
      _testResultController?.add(testResult);

      debugPrint(
          '🧪 Test completed: ${_currentTest!.name} - ${testResult.passed ? 'PASSED' : 'FAILED'}');

      // Move to next test
      _currentTestIndex++;
      await _startNextTest();
    } catch (e) {
      debugPrint('🧪 Error finalizing test: $e');
      // Continue to next test even if current test failed
      _currentTestIndex++;
      await _startNextTest();
    }
  }

  Future<void> _completeTestSuite() async {
    debugPrint('🧪 Test suite completed: ${_currentTestSuite!.name}');

    // Emit final progress update
    _progressController?.add(TestProgressUpdate(
      currentTestIndex: _currentTestSuite!.tests.length,
      totalTests: _currentTestSuite!.tests.length,
      currentTest: null,
      progress: 1.0,
      estimatedTimeRemaining: Duration.zero,
      timestamp: DateTime.now(),
    ));

    _isTestingActive = false;
    _currentTestSuite = null;
    _currentTest = null;
    _currentTestIndex = 0;
  }

  Future<GpsPerformanceMetrics> _collectPerformanceMetrics() async {
    // Get current GPS quality assessment
    final qualityAssessment = _gpsAccuracyService.getCurrentQualityAssessment();

    // Collect additional metrics
    final samples = <GpsQualityReading>[];
    final sampleCount = _currentTest!.testParameters.minimumSamples;

    // In a real implementation, we would collect samples over the test duration
    // For now, we'll simulate based on current conditions
    for (int i = 0; i < sampleCount; i++) {
      // This would be actual GPS readings collected during the test
      samples.add(GpsQualityReading(
        position: Position(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime.now(),
          accuracy: qualityAssessment.averageAccuracy +
              (math.Random().nextDouble() - 0.5) * 5,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
        signalQuality: qualityAssessment.signalQuality,
        signalStrength: 75.0 + (math.Random().nextDouble() - 0.5) * 30,
        accuracy: qualityAssessment.averageAccuracy,
        speed: 0.0,
        satelliteCount: 8 + math.Random().nextInt(8),
        driftDistance: qualityAssessment.driftDistance,
        environmentalCondition: qualityAssessment.environmentalCondition,
        timestamp: DateTime.now(),
      ));
    }

    return GpsPerformanceMetrics(
      environment: _currentTest!.environment,
      sampleCount: samples.length,
      averageAccuracy: samples.map((s) => s.accuracy).reduce((a, b) => a + b) /
          samples.length,
      bestAccuracy: samples.map((s) => s.accuracy).reduce(math.min),
      worstAccuracy: samples.map((s) => s.accuracy).reduce(math.max),
      averageSignalStrength:
          samples.map((s) => s.signalStrength).reduce((a, b) => a + b) /
              samples.length,
      averageSatelliteCount:
          samples.map((s) => s.satelliteCount).reduce((a, b) => a + b) /
              samples.length,
      driftLevel: qualityAssessment.driftLevel,
      averageDriftDistance: qualityAssessment.driftDistance,
      signalQualityDistribution: _calculateSignalQualityDistribution(samples),
      testDuration: _currentTest!.duration,
      timestamp: DateTime.now(),
    );
  }

  EnvironmentalTestResult _evaluateTestResult(
    EnvironmentalTest test,
    GpsPerformanceMetrics metrics,
  ) {
    final expected = test.expectedConditions;
    final issues = <String>[];

    // Check accuracy requirements
    if (metrics.averageAccuracy < expected.minAccuracy) {
      issues.add(
          'Average accuracy too good (${metrics.averageAccuracy.toStringAsFixed(1)}m < ${expected.minAccuracy}m) - may indicate test environment mismatch');
    }
    if (metrics.averageAccuracy > expected.maxAccuracy) {
      issues.add(
          'Average accuracy too poor (${metrics.averageAccuracy.toStringAsFixed(1)}m > ${expected.maxAccuracy}m)');
    }

    // Check signal strength
    if (metrics.averageSignalStrength < expected.minSignalStrength) {
      issues.add(
          'Signal strength too low (${metrics.averageSignalStrength.toStringAsFixed(1)}% < ${expected.minSignalStrength}%)');
    }

    // Check drift level
    if (_getDriftLevelSeverity(metrics.driftLevel) >
        _getDriftLevelSeverity(expected.expectedDriftLevel)) {
      issues.add(
          'Drift level higher than expected (${metrics.driftLevel.name} > ${expected.expectedDriftLevel.name})');
    }

    final passed = issues.isEmpty;

    return EnvironmentalTestResult(
      test: test,
      metrics: metrics,
      passed: passed,
      issues: issues,
      score: _calculateTestScore(metrics, expected),
      timestamp: DateTime.now(),
    );
  }

  double _calculateTestScore(
      GpsPerformanceMetrics metrics, ExpectedTestConditions expected) {
    double score = 100.0;

    // Accuracy score (40% weight)
    final accuracyScore =
        _calculateAccuracyScore(metrics.averageAccuracy, expected);
    score = score * 0.6 + accuracyScore * 0.4;

    // Signal strength score (30% weight)
    final signalScore = math.min(
            metrics.averageSignalStrength / expected.minSignalStrength, 1.0) *
        100;
    score = score * 0.7 + signalScore * 0.3;

    // Drift score (30% weight)
    final driftScore =
        _calculateDriftScore(metrics.driftLevel, expected.expectedDriftLevel);
    score = score * 0.7 + driftScore * 0.3;

    return math.max(0.0, math.min(100.0, score));
  }

  double _calculateAccuracyScore(
      double actualAccuracy, ExpectedTestConditions expected) {
    if (actualAccuracy <= expected.minAccuracy) return 100.0;
    if (actualAccuracy >= expected.maxAccuracy) return 0.0;

    // Linear interpolation between min and max
    final range = expected.maxAccuracy - expected.minAccuracy;
    final position = (actualAccuracy - expected.minAccuracy) / range;
    return (1.0 - position) * 100.0;
  }

  double _calculateDriftScore(GpsDriftLevel actual, GpsDriftLevel expected) {
    final actualSeverity = _getDriftLevelSeverity(actual);
    final expectedSeverity = _getDriftLevelSeverity(expected);

    if (actualSeverity <= expectedSeverity) return 100.0;

    // Penalize higher drift levels
    final penalty = (actualSeverity - expectedSeverity) * 20.0;
    return math.max(0.0, 100.0 - penalty);
  }

  int _getDriftLevelSeverity(GpsDriftLevel level) {
    switch (level) {
      case GpsDriftLevel.minimal:
        return 0;
      case GpsDriftLevel.low:
        return 1;
      case GpsDriftLevel.moderate:
        return 2;
      case GpsDriftLevel.high:
        return 3;
      case GpsDriftLevel.excessive:
        return 4;
    }
  }

  Map<GpsSignalQuality, double> _calculateSignalQualityDistribution(
      List<GpsQualityReading> samples) {
    final distribution = <GpsSignalQuality, int>{};

    for (final sample in samples) {
      distribution[sample.signalQuality] =
          (distribution[sample.signalQuality] ?? 0) + 1;
    }

    final total = samples.length;
    return distribution
        .map((quality, count) => MapEntry(quality, count / total));
  }

  void _storePerformanceMetrics(
      EnvironmentalCondition environment, GpsPerformanceMetrics metrics) {
    _performanceByEnvironment[environment] ??= [];
    _performanceByEnvironment[environment]!.add(metrics);
  }

  ExpectedTestConditions _getExpectedConditionsForEnvironment(
      EnvironmentalCondition environment) {
    switch (environment) {
      case EnvironmentalCondition.openArea:
        return const ExpectedTestConditions(
          minAccuracy: 2.0,
          maxAccuracy: 8.0,
          minSignalStrength: 80.0,
          expectedDriftLevel: GpsDriftLevel.minimal,
        );
      case EnvironmentalCondition.urban:
        return const ExpectedTestConditions(
          minAccuracy: 5.0,
          maxAccuracy: 15.0,
          minSignalStrength: 60.0,
          expectedDriftLevel: GpsDriftLevel.low,
        );
      case EnvironmentalCondition.suburban:
        return const ExpectedTestConditions(
          minAccuracy: 3.0,
          maxAccuracy: 10.0,
          minSignalStrength: 70.0,
          expectedDriftLevel: GpsDriftLevel.low,
        );
      case EnvironmentalCondition.urbanCanyon:
        return const ExpectedTestConditions(
          minAccuracy: 10.0,
          maxAccuracy: 30.0,
          minSignalStrength: 40.0,
          expectedDriftLevel: GpsDriftLevel.moderate,
        );
      case EnvironmentalCondition.denseForest:
        return const ExpectedTestConditions(
          minAccuracy: 15.0,
          maxAccuracy: 50.0,
          minSignalStrength: 30.0,
          expectedDriftLevel: GpsDriftLevel.high,
        );
      case EnvironmentalCondition.mountainous:
        return const ExpectedTestConditions(
          minAccuracy: 8.0,
          maxAccuracy: 25.0,
          minSignalStrength: 50.0,
          expectedDriftLevel: GpsDriftLevel.moderate,
        );
      case EnvironmentalCondition.indoor:
        return const ExpectedTestConditions(
          minAccuracy: 20.0,
          maxAccuracy: 100.0,
          minSignalStrength: 20.0,
          expectedDriftLevel: GpsDriftLevel.high,
        );
      case EnvironmentalCondition.underground:
        return const ExpectedTestConditions(
          minAccuracy: 50.0,
          maxAccuracy: 200.0,
          minSignalStrength: 10.0,
          expectedDriftLevel: GpsDriftLevel.excessive,
        );
      case EnvironmentalCondition.unknown:
        return const ExpectedTestConditions(
          minAccuracy: 5.0,
          maxAccuracy: 20.0,
          minSignalStrength: 50.0,
          expectedDriftLevel: GpsDriftLevel.moderate,
        );
    }
  }

  TestParameters _getTestParametersForEnvironment(
      EnvironmentalCondition environment) {
    switch (environment) {
      case EnvironmentalCondition.openArea:
      case EnvironmentalCondition.suburban:
        return const TestParameters(
          updateInterval: 5,
          minimumSamples: 60,
          accuracyThreshold: 10.0,
        );
      case EnvironmentalCondition.urban:
      case EnvironmentalCondition.mountainous:
        return const TestParameters(
          updateInterval: 5,
          minimumSamples: 60,
          accuracyThreshold: 20.0,
        );
      case EnvironmentalCondition.urbanCanyon:
      case EnvironmentalCondition.denseForest:
        return const TestParameters(
          updateInterval: 10,
          minimumSamples: 30,
          accuracyThreshold: 50.0,
        );
      case EnvironmentalCondition.indoor:
      case EnvironmentalCondition.underground:
        return const TestParameters(
          updateInterval: 15,
          minimumSamples: 20,
          accuracyThreshold: 100.0,
        );
      case EnvironmentalCondition.unknown:
        return const TestParameters(
          updateInterval: 5,
          minimumSamples: 60,
          accuracyThreshold: 25.0,
        );
    }
  }

  EnvironmentTestSummary _createEnvironmentSummary(
    EnvironmentalCondition environment,
    List<EnvironmentalTestResult> results,
  ) {
    final passedTests = results.where((r) => r.passed).length;
    final averageScore =
        results.map((r) => r.score).reduce((a, b) => a + b) / results.length;
    final averageAccuracy =
        results.map((r) => r.metrics.averageAccuracy).reduce((a, b) => a + b) /
            results.length;

    return EnvironmentTestSummary(
      environment: environment,
      totalTests: results.length,
      passedTests: passedTests,
      failedTests: results.length - passedTests,
      averageScore: averageScore,
      averageAccuracy: averageAccuracy,
      bestAccuracy: results.map((r) => r.metrics.bestAccuracy).reduce(math.min),
      worstAccuracy:
          results.map((r) => r.metrics.worstAccuracy).reduce(math.max),
    );
  }

  double _calculateOverallAverageAccuracy() {
    if (_testResults.isEmpty) return 0.0;
    return _testResults
            .map((r) => r.metrics.averageAccuracy)
            .reduce((a, b) => a + b) /
        _testResults.length;
  }

  EnvironmentalCondition? _getBestEnvironment() {
    if (_testResults.isEmpty) return null;

    final environmentScores = <EnvironmentalCondition, double>{};
    final environmentCounts = <EnvironmentalCondition, int>{};

    for (final result in _testResults) {
      final env = result.test.environment;
      environmentScores[env] = (environmentScores[env] ?? 0.0) + result.score;
      environmentCounts[env] = (environmentCounts[env] ?? 0) + 1;
    }

    EnvironmentalCondition? bestEnv;
    double bestScore = 0.0;

    for (final entry in environmentScores.entries) {
      final avgScore = entry.value / environmentCounts[entry.key]!;
      if (avgScore > bestScore) {
        bestScore = avgScore;
        bestEnv = entry.key;
      }
    }

    return bestEnv;
  }

  EnvironmentalCondition? _getWorstEnvironment() {
    if (_testResults.isEmpty) return null;

    final environmentScores = <EnvironmentalCondition, double>{};
    final environmentCounts = <EnvironmentalCondition, int>{};

    for (final result in _testResults) {
      final env = result.test.environment;
      environmentScores[env] = (environmentScores[env] ?? 0.0) + result.score;
      environmentCounts[env] = (environmentCounts[env] ?? 0) + 1;
    }

    EnvironmentalCondition? worstEnv;
    double worstScore = 100.0;

    for (final entry in environmentScores.entries) {
      final avgScore = entry.value / environmentCounts[entry.key]!;
      if (avgScore < worstScore) {
        worstScore = avgScore;
        worstEnv = entry.key;
      }
    }

    return worstEnv;
  }

  Duration _calculateRemainingTime() {
    if (_currentTestSuite == null) return Duration.zero;

    final remainingTests =
        _currentTestSuite!.tests.length - _currentTestIndex - 1;
    if (remainingTests <= 0) return Duration.zero;

    final remainingDuration = _currentTestSuite!.tests
        .skip(_currentTestIndex + 1)
        .map((t) => t.duration.inMilliseconds)
        .reduce((a, b) => a + b);

    return Duration(milliseconds: remainingDuration);
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    stop();
    _gpsAccuracyService.dispose();
    _instance = null;
  }
}
