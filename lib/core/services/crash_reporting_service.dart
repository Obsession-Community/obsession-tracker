import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/performance_models.dart';
import 'package:obsession_tracker/core/services/memory_monitoring_service.dart';
import 'package:path_provider/path_provider.dart';

/// Comprehensive crash reporting and error analytics service
///
/// Provides automatic crash detection, error logging, analytics, and reporting
/// for debugging and improving app stability.
class CrashReportingService {
  factory CrashReportingService() => _instance ??= CrashReportingService._();
  CrashReportingService._();
  static CrashReportingService? _instance;

  // Stream controllers
  StreamController<CrashReport>? _crashReportController;
  StreamController<ErrorAnalytics>? _analyticsController;

  // Service state
  bool _isActive = false;
  PerformanceMonitoringConfig _config = const PerformanceMonitoringConfig();

  // Crash tracking
  final List<CrashReport> _crashReports = <CrashReport>[];
  final List<String> _userActionHistory = <String>[];
  final Map<String, int> _errorFrequency = {};
  static const int _maxUserActions = 50;

  // Dependencies
  final MemoryMonitoringService _memoryService = MemoryMonitoringService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // File paths
  String? _crashReportsPath;
  String? _errorLogsPath;

  /// Stream of crash reports
  Stream<CrashReport> get crashReportStream {
    _crashReportController ??= StreamController<CrashReport>.broadcast();
    return _crashReportController!.stream;
  }

  /// Stream of error analytics
  Stream<ErrorAnalytics> get analyticsStream {
    _analyticsController ??= StreamController<ErrorAnalytics>.broadcast();
    return _analyticsController!.stream;
  }

  /// Whether crash reporting is active
  bool get isActive => _isActive;

  /// Total crash reports recorded
  int get totalCrashReports => _crashReports.length;

  /// Recent crash reports
  List<CrashReport> get recentCrashReports => List.unmodifiable(_crashReports);

  /// Start crash reporting service
  Future<void> start({
    PerformanceMonitoringConfig? config,
  }) async {
    try {
      await stop(); // Ensure clean start

      _config = config ?? const PerformanceMonitoringConfig();

      debugPrint('💥 Starting crash reporting service...');
      debugPrint('  Crash reporting enabled: ${_config.crashReportingEnabled}');

      if (!_config.crashReportingEnabled) {
        debugPrint('💥 Crash reporting is disabled in configuration');
        return;
      }

      // Initialize file paths
      await _initializeFilePaths();

      // Initialize stream controllers
      _crashReportController ??= StreamController<CrashReport>.broadcast();
      _analyticsController ??= StreamController<ErrorAnalytics>.broadcast();

      // Load existing crash reports
      await _loadCrashReports();

      // Set up global error handlers
      _setupErrorHandlers();

      _isActive = true;
      debugPrint('💥 Crash reporting service started successfully');
    } catch (e) {
      debugPrint('💥 Error starting crash reporting service: $e');
      rethrow;
    }
  }

  /// Stop crash reporting service
  Future<void> stop() async {
    // Save crash reports before stopping
    if (_isActive) {
      await _saveCrashReports();
    }

    // Close stream controllers
    await _crashReportController?.close();
    _crashReportController = null;

    await _analyticsController?.close();
    _analyticsController = null;

    _isActive = false;
    debugPrint('💥 Crash reporting service stopped');
  }

  /// Update configuration
  Future<void> updateConfig(PerformanceMonitoringConfig newConfig) async {
    _config = newConfig;
    debugPrint('💥 Crash reporting config updated');

    // Restart if needed
    if (_isActive && !newConfig.crashReportingEnabled) {
      await stop();
    } else if (!_isActive && newConfig.crashReportingEnabled) {
      await start(config: newConfig);
    }
  }

  /// Record user action for crash context
  void recordUserAction(String action) {
    if (!_isActive) return;

    final timestamp = DateTime.now().toIso8601String();
    final actionWithTime = '[$timestamp] $action';

    _userActionHistory.add(actionWithTime);
    if (_userActionHistory.length > _maxUserActions) {
      _userActionHistory.removeAt(0);
    }

    debugPrint('💥 User action recorded: $action');
  }

  /// Report a crash manually
  Future<void> reportCrash({
    required String errorMessage,
    required String stackTrace,
    required CrashType crashType,
    Map<String, dynamic>? additionalContext,
  }) async {
    if (!_isActive) return;

    try {
      final crashReport = await _createCrashReport(
        errorMessage: errorMessage,
        stackTrace: stackTrace,
        crashType: crashType,
        additionalContext: additionalContext ?? {},
      );

      await _processCrashReport(crashReport);
    } catch (e) {
      debugPrint('💥 Error reporting crash: $e');
    }
  }

  /// Get crash analytics
  ErrorAnalytics getCrashAnalytics() => _generateErrorAnalytics();

  /// Get crash reports by type
  List<CrashReport> getCrashReportsByType(CrashType type) =>
      _crashReports.where((report) => report.crashType == type).toList();

  /// Get crash reports in date range
  List<CrashReport> getCrashReportsInRange(DateTime start, DateTime end) =>
      _crashReports
          .where((report) =>
              report.timestamp.isAfter(start) && report.timestamp.isBefore(end))
          .toList();

  /// Clear crash reports
  Future<void> clearCrashReports() async {
    _crashReports.clear();
    _errorFrequency.clear();
    await _saveCrashReports();
    debugPrint('💥 Crash reports cleared');
  }

  /// Export crash reports
  Future<String> exportCrashReports() async {
    try {
      final exportData = {
        'exportTime': DateTime.now().toIso8601String(),
        'totalReports': _crashReports.length,
        'reports': _crashReports.map((report) => report.toMap()).toList(),
        'analytics': getCrashAnalytics().toMap(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final exportFile = File('${directory.path}/crash_reports_export.json');
      await exportFile.writeAsString(jsonString);

      debugPrint('💥 Crash reports exported to: ${exportFile.path}');
      return exportFile.path;
    } catch (e) {
      debugPrint('💥 Error exporting crash reports: $e');
      rethrow;
    }
  }

  Future<void> _initializeFilePaths() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final crashDir = Directory('${directory.path}/crash_reports');

      if (!crashDir.existsSync()) {
        await crashDir.create(recursive: true);
      }

      _crashReportsPath = '${crashDir.path}/crash_reports.json';
      _errorLogsPath = '${crashDir.path}/error_logs.txt';
    } catch (e) {
      debugPrint('💥 Error initializing file paths: $e');
    }
  }

  void _setupErrorHandlers() {
    // Handle Flutter framework errors
    FlutterError.onError = _handleFlutterError;

    // Handle async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      _handleAsyncError(error, stack);
      return true;
    };

    // Handle isolate errors (simplified for Flutter apps)
    // Note: In Flutter apps, isolate error handling is typically handled
    // by the framework. This is a placeholder for custom isolate error handling.
    if (kDebugMode) {
      debugPrint('💥 Isolate error handling setup (debug mode only)');
    }
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    debugPrint('💥 Flutter error detected: ${details.exception}');

    reportCrash(
      errorMessage: details.exception.toString(),
      stackTrace: details.stack?.toString() ?? 'No stack trace available',
      crashType: _determineCrashType(details.exception),
      additionalContext: {
        'library': details.library ?? 'Unknown',
        'context': details.context?.toString() ?? 'No context',
        'informationCollector': details.informationCollector?.toString(),
      },
    );
  }

  bool _handleAsyncError(Object error, StackTrace stack) {
    debugPrint('💥 Async error detected: $error');

    reportCrash(
      errorMessage: error.toString(),
      stackTrace: stack.toString(),
      crashType: _determineCrashType(error),
      additionalContext: {
        'errorType': error.runtimeType.toString(),
        'isAsync': true,
      },
    );

    return true;
  }

  CrashType _determineCrashType(Object error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('out of memory') ||
        errorString.contains('memory')) {
      return CrashType.outOfMemory;
    } else if (errorString.contains('permission')) {
      return CrashType.permissionError;
    } else if (errorString.contains('network') ||
        errorString.contains('socket')) {
      return CrashType.networkError;
    } else if (errorString.contains('storage') ||
        errorString.contains('file')) {
      return CrashType.storageError;
    } else if (error is Exception) {
      return CrashType.exception;
    } else {
      return CrashType.fatal;
    }
  }

  Future<CrashReport> _createCrashReport({
    required String errorMessage,
    required String stackTrace,
    required CrashType crashType,
    required Map<String, dynamic> additionalContext,
  }) async {
    // Get device information
    final deviceInfo = await _getDeviceInfo();

    // Get memory usage at crash
    final memoryUsage = _memoryService.currentMemoryUsage;

    // Get app version (would be from package info in real implementation)
    const appVersion = '0.1.0+1';

    // Generate unique crash ID
    final crashId = 'crash_${DateTime.now().millisecondsSinceEpoch}';

    return CrashReport(
      crashId: crashId,
      timestamp: DateTime.now(),
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      deviceInfo: deviceInfo,
      appVersion: appVersion,
      crashType: crashType,
      userActions: List.from(_userActionHistory),
      memoryUsageAtCrash: memoryUsage,
      additionalContext: additionalContext,
    );
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'platform': 'Android',
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'version': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'brand': androidInfo.brand,
          'device': androidInfo.device,
          'hardware': androidInfo.hardware,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'platform': 'iOS',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'systemVersion': iosInfo.systemVersion,
          'localizedModel': iosInfo.localizedModel,
          'identifierForVendor': iosInfo.identifierForVendor,
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
        };
      } else {
        return {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
        };
      }
    } catch (e) {
      debugPrint('💥 Error getting device info: $e');
      return {
        'platform': Platform.operatingSystem,
        'error': 'Could not retrieve device info: $e',
      };
    }
  }

  Future<void> _processCrashReport(CrashReport crashReport) async {
    // Add to crash reports list
    _crashReports.add(crashReport);
    if (_crashReports.length > _config.maxCrashReports) {
      _crashReports.removeAt(0);
    }

    // Update error frequency
    final errorKey =
        '${crashReport.crashType.name}:${crashReport.errorMessage}';
    _errorFrequency[errorKey] = (_errorFrequency[errorKey] ?? 0) + 1;

    // Save crash reports
    await _saveCrashReports();

    // Log error to file
    await _logErrorToFile(crashReport);

    // Emit crash report
    _crashReportController?.add(crashReport);

    // Generate and emit analytics
    final analytics = _generateErrorAnalytics();
    _analyticsController?.add(analytics);

    debugPrint('💥 Crash report processed: ${crashReport.crashId}');

    // Log critical crashes
    if (crashReport.isCritical) {
      debugPrint('💥 CRITICAL CRASH: ${crashReport.errorMessage}');
    }
  }

  Future<void> _saveCrashReports() async {
    if (_crashReportsPath == null) return;

    try {
      final crashData = {
        'reports': _crashReports.map((report) => report.toMap()).toList(),
        'errorFrequency': _errorFrequency,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      final jsonString = jsonEncode(crashData);
      final file = File(_crashReportsPath!);
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('💥 Error saving crash reports: $e');
    }
  }

  Future<void> _loadCrashReports() async {
    if (_crashReportsPath == null) return;

    try {
      final file = File(_crashReportsPath!);
      if (!file.existsSync()) return;

      final jsonString = await file.readAsString();
      final crashData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Load crash reports
      final reports = crashData['reports'] as List<dynamic>? ?? [];
      _crashReports.clear();
      for (final reportData in reports) {
        try {
          final report =
              CrashReport.fromMap(reportData as Map<String, dynamic>);
          _crashReports.add(report);
        } catch (e) {
          debugPrint('💥 Error loading crash report: $e');
        }
      }

      // Load error frequency
      final frequency =
          crashData['errorFrequency'] as Map<String, dynamic>? ?? {};
      _errorFrequency.clear();
      frequency.forEach((key, value) {
        _errorFrequency[key] = value as int;
      });

      debugPrint('💥 Loaded ${_crashReports.length} crash reports');
    } catch (e) {
      debugPrint('💥 Error loading crash reports: $e');
    }
  }

  Future<void> _logErrorToFile(CrashReport crashReport) async {
    if (_errorLogsPath == null) return;

    try {
      final logEntry = '''
================================================================================
Crash ID: ${crashReport.crashId}
Timestamp: ${crashReport.timestamp.toIso8601String()}
Type: ${crashReport.crashType.displayName}
App Version: ${crashReport.appVersion}

Error Message:
${crashReport.errorMessage}

Stack Trace:
${crashReport.stackTrace}

Device Info:
${crashReport.deviceInfo.entries.map((e) => '${e.key}: ${e.value}').join('\n')}

User Actions:
${crashReport.userActions.join('\n')}

Additional Context:
${crashReport.additionalContext.entries.map((e) => '${e.key}: ${e.value}').join('\n')}

================================================================================

''';

      final file = File(_errorLogsPath!);
      await file.writeAsString(logEntry, mode: FileMode.append);
    } catch (e) {
      debugPrint('💥 Error logging to file: $e');
    }
  }

  ErrorAnalytics _generateErrorAnalytics() {
    if (_crashReports.isEmpty) {
      return ErrorAnalytics(
        totalCrashes: 0,
        crashFrequency: 0.0,
        mostCommonCrashType: CrashType.unknown,
        criticalCrashCount: 0,
        crashTrends: CrashTrend.stable,
        topErrors: [],
        stabilityScore: 100.0,
        generatedAt: DateTime.now(),
      );
    }

    // Calculate crash frequency (crashes per day)
    final now = DateTime.now();
    final oldestCrash = _crashReports.first.timestamp;
    final daysSinceOldest =
        now.difference(oldestCrash).inDays.clamp(1, double.infinity);
    final crashFrequency = _crashReports.length / daysSinceOldest;

    // Find most common crash type
    final crashTypeCounts = <CrashType, int>{};
    for (final report in _crashReports) {
      crashTypeCounts[report.crashType] =
          (crashTypeCounts[report.crashType] ?? 0) + 1;
    }
    final mostCommonCrashType =
        crashTypeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    // Count critical crashes
    final criticalCrashCount = _crashReports.where((r) => r.isCritical).length;

    // Determine crash trends
    final crashTrends = _calculateCrashTrends();

    // Get top errors
    final topErrors = _getTopErrors();

    // Calculate stability score
    final stabilityScore = _calculateStabilityScore();

    return ErrorAnalytics(
      totalCrashes: _crashReports.length,
      crashFrequency: crashFrequency,
      mostCommonCrashType: mostCommonCrashType,
      criticalCrashCount: criticalCrashCount,
      crashTrends: crashTrends,
      topErrors: topErrors,
      stabilityScore: stabilityScore,
      generatedAt: DateTime.now(),
    );
  }

  CrashTrend _calculateCrashTrends() {
    if (_crashReports.length < 10) return CrashTrend.stable;

    // Compare recent crashes to older ones
    final recent = _crashReports.length > 20
        ? _crashReports.sublist(_crashReports.length - 10)
        : _crashReports;
    final older = _crashReports.length > 20
        ? _crashReports.sublist(0, 10)
        : <CrashReport>[];

    if (older.isEmpty) return CrashTrend.stable;

    final recentRate = recent.length / 10.0;
    final olderRate = older.length / 10.0;

    if (recentRate > olderRate * 1.5) return CrashTrend.increasing;
    if (recentRate < olderRate * 0.5) return CrashTrend.decreasing;
    return CrashTrend.stable;
  }

  List<TopError> _getTopErrors() {
    final errorCounts = <String, int>{};

    for (final report in _crashReports) {
      final errorKey = report.errorMessage.length > 100
          ? '${report.errorMessage.substring(0, 100)}...'
          : report.errorMessage;
      errorCounts[errorKey] = (errorCounts[errorKey] ?? 0) + 1;
    }

    final sortedErrors = errorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedErrors
        .take(5)
        .map((entry) => TopError(
              errorMessage: entry.key,
              occurrences: entry.value,
              percentage: (entry.value / _crashReports.length) * 100,
            ))
        .toList();
  }

  double _calculateStabilityScore() {
    if (_crashReports.isEmpty) return 100.0;

    double score = 100.0;

    // Penalize based on crash frequency
    final analytics = _generateErrorAnalytics();
    if (analytics.crashFrequency > 5.0) {
      score -= 50;
    } else if (analytics.crashFrequency > 2.0) {
      score -= 30;
    } else if (analytics.crashFrequency > 1.0) {
      score -= 15;
    } else if (analytics.crashFrequency > 0.5) {
      score -= 5;
    }

    // Penalize critical crashes more heavily
    final criticalRatio = analytics.criticalCrashCount / _crashReports.length;
    score -= criticalRatio * 30;

    // Penalize increasing crash trends
    if (analytics.crashTrends == CrashTrend.increasing) {
      score -= 20;
    }

    return score.clamp(0.0, 100.0);
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    stop();
    _crashReports.clear();
    _userActionHistory.clear();
    _errorFrequency.clear();
    _instance = null;
  }
}

/// Error analytics data
class ErrorAnalytics {
  const ErrorAnalytics({
    required this.totalCrashes,
    required this.crashFrequency,
    required this.mostCommonCrashType,
    required this.criticalCrashCount,
    required this.crashTrends,
    required this.topErrors,
    required this.stabilityScore,
    required this.generatedAt,
  });

  final int totalCrashes;
  final double crashFrequency; // crashes per day
  final CrashType mostCommonCrashType;
  final int criticalCrashCount;
  final CrashTrend crashTrends;
  final List<TopError> topErrors;
  final double stabilityScore; // 0-100
  final DateTime generatedAt;

  /// App stability grade
  StabilityGrade get stabilityGrade {
    if (stabilityScore >= 95) return StabilityGrade.excellent;
    if (stabilityScore >= 85) return StabilityGrade.good;
    if (stabilityScore >= 70) return StabilityGrade.fair;
    if (stabilityScore >= 50) return StabilityGrade.poor;
    return StabilityGrade.critical;
  }

  Map<String, dynamic> toMap() => {
        'totalCrashes': totalCrashes,
        'crashFrequency': crashFrequency,
        'mostCommonCrashType': mostCommonCrashType.name,
        'criticalCrashCount': criticalCrashCount,
        'crashTrends': crashTrends.name,
        'topErrors': topErrors.map((e) => e.toMap()).toList(),
        'stabilityScore': stabilityScore,
        'stabilityGrade': stabilityGrade.name,
        'generatedAt': generatedAt.toIso8601String(),
      };
}

/// Crash trend directions
enum CrashTrend {
  decreasing,
  stable,
  increasing;

  String get displayName {
    switch (this) {
      case CrashTrend.decreasing:
        return 'Decreasing';
      case CrashTrend.stable:
        return 'Stable';
      case CrashTrend.increasing:
        return 'Increasing';
    }
  }

  String get colorHex {
    switch (this) {
      case CrashTrend.decreasing:
        return '#4CAF50'; // Green
      case CrashTrend.stable:
        return '#2196F3'; // Blue
      case CrashTrend.increasing:
        return '#F44336'; // Red
    }
  }
}

/// App stability grades
enum StabilityGrade {
  excellent,
  good,
  fair,
  poor,
  critical;

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

  String get colorHex {
    switch (this) {
      case StabilityGrade.excellent:
        return '#4CAF50'; // Green
      case StabilityGrade.good:
        return '#8BC34A'; // Light Green
      case StabilityGrade.fair:
        return '#FF9800'; // Orange
      case StabilityGrade.poor:
        return '#FF5722'; // Deep Orange
      case StabilityGrade.critical:
        return '#F44336'; // Red
    }
  }
}

/// Top error information
class TopError {
  const TopError({
    required this.errorMessage,
    required this.occurrences,
    required this.percentage,
  });

  final String errorMessage;
  final int occurrences;
  final double percentage;

  Map<String, dynamic> toMap() => {
        'errorMessage': errorMessage,
        'occurrences': occurrences,
        'percentage': percentage,
      };

  @override
  String toString() =>
      'TopError($errorMessage: $occurrences occurrences, ${percentage.toStringAsFixed(1)}%)';
}
