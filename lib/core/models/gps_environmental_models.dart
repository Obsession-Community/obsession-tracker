import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/gps_accuracy_models.dart';

/// Environmental test result
@immutable
class EnvironmentalTestResult {
  const EnvironmentalTestResult({
    required this.test,
    required this.metrics,
    required this.passed,
    required this.issues,
    required this.score,
    required this.timestamp,
  });

  /// The test that was performed
  final EnvironmentalTest test;

  /// Performance metrics collected during the test
  final GpsPerformanceMetrics metrics;

  /// Whether the test passed
  final bool passed;

  /// List of issues found during the test
  final List<String> issues;

  /// Test score (0-100)
  final double score;

  /// Test completion timestamp
  final DateTime timestamp;

  @override
  String toString() => 'EnvironmentalTestResult('
      'test: ${test.name}, '
      'passed: $passed, '
      'score: ${score.toStringAsFixed(1)}, '
      'issues: ${issues.length} '
      ')';
}

/// Test progress update
@immutable
class TestProgressUpdate {
  const TestProgressUpdate({
    required this.currentTestIndex,
    required this.totalTests,
    required this.currentTest,
    required this.progress,
    required this.estimatedTimeRemaining,
    required this.timestamp,
  });

  /// Current test index (0-based)
  final int currentTestIndex;

  /// Total number of tests
  final int totalTests;

  /// Currently running test (null if completed)
  final EnvironmentalTest? currentTest;

  /// Progress as a fraction (0.0 to 1.0)
  final double progress;

  /// Estimated time remaining
  final Duration estimatedTimeRemaining;

  /// Update timestamp
  final DateTime timestamp;

  /// Progress as percentage (0-100)
  double get progressPercentage => progress * 100.0;

  @override
  String toString() => 'TestProgressUpdate('
      'test: ${currentTestIndex + 1}/$totalTests, '
      'progress: ${progressPercentage.toStringAsFixed(1)}%, '
      'remaining: ${estimatedTimeRemaining.inMinutes}min '
      ')';
}

/// GPS performance metrics for an environment
@immutable
class GpsPerformanceMetrics {
  const GpsPerformanceMetrics({
    required this.environment,
    required this.sampleCount,
    required this.averageAccuracy,
    required this.bestAccuracy,
    required this.worstAccuracy,
    required this.averageSignalStrength,
    required this.averageSatelliteCount,
    required this.driftLevel,
    required this.averageDriftDistance,
    required this.signalQualityDistribution,
    required this.testDuration,
    required this.timestamp,
  });

  /// Environment where the test was conducted
  final EnvironmentalCondition environment;

  /// Number of GPS samples collected
  final int sampleCount;

  /// Average accuracy in meters
  final double averageAccuracy;

  /// Best accuracy achieved in meters
  final double bestAccuracy;

  /// Worst accuracy recorded in meters
  final double worstAccuracy;

  /// Average signal strength (0-100)
  final double averageSignalStrength;

  /// Average number of satellites
  final double averageSatelliteCount;

  /// Drift level observed
  final GpsDriftLevel driftLevel;

  /// Average drift distance in meters
  final double averageDriftDistance;

  /// Distribution of signal quality levels
  final Map<GpsSignalQuality, double> signalQualityDistribution;

  /// Duration of the test
  final Duration testDuration;

  /// Metrics timestamp
  final DateTime timestamp;

  /// Get accuracy range
  double get accuracyRange => worstAccuracy - bestAccuracy;

  /// Get accuracy consistency score (0-100)
  double get consistencyScore {
    if (averageAccuracy == 0) return 0.0;
    final variability = accuracyRange / averageAccuracy;
    return (1.0 - variability.clamp(0.0, 1.0)) * 100.0;
  }

  /// Get overall performance score (0-100)
  double get performanceScore {
    double score = 0.0;

    // Accuracy score (40% weight)
    final accuracyScore = averageAccuracy <= 5.0
        ? 100.0
        : averageAccuracy <= 10.0
            ? 80.0
            : averageAccuracy <= 20.0
                ? 60.0
                : averageAccuracy <= 50.0
                    ? 40.0
                    : 20.0;
    score += accuracyScore * 0.4;

    // Signal strength score (30% weight)
    score += (averageSignalStrength / 100.0) * 30.0;

    // Consistency score (20% weight)
    score += consistencyScore * 0.2;

    // Satellite count score (10% weight)
    final satelliteScore =
        (averageSatelliteCount / 12.0).clamp(0.0, 1.0) * 10.0;
    score += satelliteScore;

    return score.clamp(0.0, 100.0);
  }

  @override
  String toString() => 'GpsPerformanceMetrics('
      'env: ${environment.name}, '
      'samples: $sampleCount, '
      'avg accuracy: ${averageAccuracy.toStringAsFixed(1)}m, '
      'signal: ${averageSignalStrength.toStringAsFixed(1)}%, '
      'score: ${performanceScore.toStringAsFixed(1)} '
      ')';
}

/// Environmental test suite containing multiple tests
@immutable
class EnvironmentalTestSuite {
  const EnvironmentalTestSuite({
    required this.name,
    required this.description,
    required this.tests,
    required this.estimatedDuration,
  });

  /// Test suite name
  final String name;

  /// Test suite description
  final String description;

  /// List of tests in the suite
  final List<EnvironmentalTest> tests;

  /// Estimated total duration
  final Duration estimatedDuration;

  /// Number of tests in the suite
  int get testCount => tests.length;

  @override
  String toString() => 'EnvironmentalTestSuite('
      'name: $name, '
      'tests: ${tests.length}, '
      'duration: ${estimatedDuration.inMinutes}min '
      ')';
}

/// Individual environmental test
@immutable
class EnvironmentalTest {
  const EnvironmentalTest({
    required this.name,
    required this.environment,
    required this.duration,
    required this.expectedConditions,
    required this.testParameters,
  });

  /// Test name
  final String name;

  /// Environment being tested
  final EnvironmentalCondition environment;

  /// Test duration
  final Duration duration;

  /// Expected test conditions
  final ExpectedTestConditions expectedConditions;

  /// Test parameters
  final TestParameters testParameters;

  @override
  String toString() => 'EnvironmentalTest('
      'name: $name, '
      'env: ${environment.name}, '
      'duration: ${duration.inMinutes}min '
      ')';
}

/// Expected conditions for a test
@immutable
class ExpectedTestConditions {
  const ExpectedTestConditions({
    required this.minAccuracy,
    required this.maxAccuracy,
    required this.minSignalStrength,
    required this.expectedDriftLevel,
  });

  /// Minimum expected accuracy (best case)
  final double minAccuracy;

  /// Maximum expected accuracy (worst acceptable)
  final double maxAccuracy;

  /// Minimum expected signal strength
  final double minSignalStrength;

  /// Expected drift level
  final GpsDriftLevel expectedDriftLevel;

  /// Get accuracy range
  double get accuracyRange => maxAccuracy - minAccuracy;

  @override
  String toString() => 'ExpectedTestConditions('
      'accuracy: ${minAccuracy.toStringAsFixed(1)}-${maxAccuracy.toStringAsFixed(1)}m, '
      'signal: ${minSignalStrength.toStringAsFixed(1)}%, '
      'drift: ${expectedDriftLevel.name} '
      ')';
}

/// Test parameters
@immutable
class TestParameters {
  const TestParameters({
    required this.updateInterval,
    required this.minimumSamples,
    required this.accuracyThreshold,
  });

  /// GPS update interval in seconds
  final int updateInterval;

  /// Minimum number of samples to collect
  final int minimumSamples;

  /// Accuracy threshold for filtering samples
  final double accuracyThreshold;

  /// Estimated test duration based on parameters
  Duration get estimatedDuration => Duration(
        seconds: minimumSamples * updateInterval,
      );

  @override
  String toString() => 'TestParameters('
      'interval: ${updateInterval}s, '
      'samples: $minimumSamples, '
      'threshold: ${accuracyThreshold.toStringAsFixed(1)}m '
      ')';
}

/// Environmental test summary
@immutable
class EnvironmentalTestSummary {
  const EnvironmentalTestSummary({
    required this.totalTests,
    required this.passedTests,
    required this.failedTests,
    required this.averageAccuracy,
    required this.bestEnvironment,
    required this.worstEnvironment,
    required this.summaryByEnvironment,
    required this.timestamp,
  });

  /// Total number of tests performed
  final int totalTests;

  /// Number of tests that passed
  final int passedTests;

  /// Number of tests that failed
  final int failedTests;

  /// Overall average accuracy across all tests
  final double averageAccuracy;

  /// Environment with best performance
  final EnvironmentalCondition? bestEnvironment;

  /// Environment with worst performance
  final EnvironmentalCondition? worstEnvironment;

  /// Summary by environment
  final Map<EnvironmentalCondition, EnvironmentTestSummary>
      summaryByEnvironment;

  /// Summary timestamp
  final DateTime timestamp;

  /// Pass rate as percentage (0-100)
  double get passRate =>
      totalTests > 0 ? (passedTests / totalTests) * 100.0 : 0.0;

  /// Overall test grade
  TestGrade get overallGrade {
    if (passRate >= 90.0) return TestGrade.excellent;
    if (passRate >= 80.0) return TestGrade.good;
    if (passRate >= 70.0) return TestGrade.fair;
    if (passRate >= 60.0) return TestGrade.poor;
    return TestGrade.failing;
  }

  @override
  String toString() => 'EnvironmentalTestSummary('
      'tests: $totalTests, '
      'passed: $passedTests, '
      'pass rate: ${passRate.toStringAsFixed(1)}%, '
      'grade: ${overallGrade.name} '
      ')';
}

/// Summary for a specific environment
@immutable
class EnvironmentTestSummary {
  const EnvironmentTestSummary({
    required this.environment,
    required this.totalTests,
    required this.passedTests,
    required this.failedTests,
    required this.averageScore,
    required this.averageAccuracy,
    required this.bestAccuracy,
    required this.worstAccuracy,
  });

  /// Environment being summarized
  final EnvironmentalCondition environment;

  /// Total tests for this environment
  final int totalTests;

  /// Passed tests for this environment
  final int passedTests;

  /// Failed tests for this environment
  final int failedTests;

  /// Average test score
  final double averageScore;

  /// Average accuracy for this environment
  final double averageAccuracy;

  /// Best accuracy achieved
  final double bestAccuracy;

  /// Worst accuracy recorded
  final double worstAccuracy;

  /// Pass rate for this environment
  double get passRate =>
      totalTests > 0 ? (passedTests / totalTests) * 100.0 : 0.0;

  /// Performance grade for this environment
  TestGrade get grade {
    if (averageScore >= 90.0) return TestGrade.excellent;
    if (averageScore >= 80.0) return TestGrade.good;
    if (averageScore >= 70.0) return TestGrade.fair;
    if (averageScore >= 60.0) return TestGrade.poor;
    return TestGrade.failing;
  }

  @override
  String toString() => 'EnvironmentTestSummary('
      'env: ${environment.name}, '
      'tests: $totalTests, '
      'pass rate: ${passRate.toStringAsFixed(1)}%, '
      'avg score: ${averageScore.toStringAsFixed(1)}, '
      'grade: ${grade.name} '
      ')';
}

/// Test performance grades
enum TestGrade {
  excellent,
  good,
  fair,
  poor,
  failing;

  String get description {
    switch (this) {
      case TestGrade.excellent:
        return 'Excellent (90-100%)';
      case TestGrade.good:
        return 'Good (80-89%)';
      case TestGrade.fair:
        return 'Fair (70-79%)';
      case TestGrade.poor:
        return 'Poor (60-69%)';
      case TestGrade.failing:
        return 'Failing (<60%)';
    }
  }

  /// Get color representation for UI
  String get colorHex {
    switch (this) {
      case TestGrade.excellent:
        return '#4CAF50'; // Green
      case TestGrade.good:
        return '#8BC34A'; // Light Green
      case TestGrade.fair:
        return '#FF9800'; // Orange
      case TestGrade.poor:
        return '#F44336'; // Red
      case TestGrade.failing:
        return '#9C27B0'; // Purple
    }
  }
}

/// Test result status
enum TestStatus {
  pending,
  running,
  completed,
  failed,
  cancelled;

  String get description {
    switch (this) {
      case TestStatus.pending:
        return 'Pending';
      case TestStatus.running:
        return 'Running';
      case TestStatus.completed:
        return 'Completed';
      case TestStatus.failed:
        return 'Failed';
      case TestStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Test execution context
@immutable
class TestExecutionContext {
  const TestExecutionContext({
    required this.testSuite,
    required this.currentTestIndex,
    required this.startTime,
    required this.status,
    this.endTime,
    this.error,
  });

  /// Test suite being executed
  final EnvironmentalTestSuite testSuite;

  /// Current test index
  final int currentTestIndex;

  /// Execution start time
  final DateTime startTime;

  /// Execution end time (if completed)
  final DateTime? endTime;

  /// Current execution status
  final TestStatus status;

  /// Error message (if failed)
  final String? error;

  /// Execution duration
  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);

  /// Progress as fraction (0.0 to 1.0)
  double get progress =>
      testSuite.testCount > 0 ? currentTestIndex / testSuite.testCount : 0.0;

  /// Whether execution is complete
  bool get isComplete =>
      status == TestStatus.completed ||
      status == TestStatus.failed ||
      status == TestStatus.cancelled;

  @override
  String toString() => 'TestExecutionContext('
      'suite: ${testSuite.name}, '
      'progress: $currentTestIndex/${testSuite.testCount}, '
      'status: ${status.name}, '
      'duration: ${duration.inMinutes}min '
      ')';
}
