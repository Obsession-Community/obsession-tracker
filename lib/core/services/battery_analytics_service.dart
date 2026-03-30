import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/battery_models.dart';
import 'package:obsession_tracker/core/services/battery_monitoring_service.dart';

/// Comprehensive battery usage reporting and analytics service
///
/// Provides detailed analytics, reports, and insights about battery usage
/// patterns, optimization effectiveness, and recommendations for users.
class BatteryAnalyticsService {
  factory BatteryAnalyticsService() =>
      _instance ??= BatteryAnalyticsService._();
  BatteryAnalyticsService._();
  static BatteryAnalyticsService? _instance;

  final BatteryMonitoringService _batteryService = BatteryMonitoringService();

  // Stream controllers
  StreamController<BatteryReport>? _reportController;
  StreamController<BatteryInsight>? _insightController;

  // Service state
  bool _isActive = false;

  // Analytics data
  final List<BatterySessionRecord> _sessionHistory = <BatterySessionRecord>[];
  final List<BatteryTrendData> _trendData = <BatteryTrendData>[];
  final Map<String, ServiceAnalytics> _serviceAnalytics = {};
  static const int _maxHistoryLength = 1000;

  // Report generation
  Timer? _reportTimer;
  Timer? _trendAnalysisTimer;
  DateTime _lastReportGeneration = DateTime.now();

  /// Stream of battery reports
  Stream<BatteryReport> get reportStream {
    _reportController ??= StreamController<BatteryReport>.broadcast();
    return _reportController!.stream;
  }

  /// Stream of battery insights
  Stream<BatteryInsight> get insightStream {
    _insightController ??= StreamController<BatteryInsight>.broadcast();
    return _insightController!.stream;
  }

  /// Whether the service is active
  bool get isActive => _isActive;

  /// Start battery analytics service
  Future<void> start() async {
    try {
      await stop(); // Ensure clean start

      debugPrint('📊 Starting battery analytics service...');

      // Initialize stream controllers
      _reportController ??= StreamController<BatteryReport>.broadcast();
      _insightController ??= StreamController<BatteryInsight>.broadcast();

      // Start monitoring timers
      _startAnalysisTimers();

      // Generate initial report
      await _generateDailyReport();

      _isActive = true;
      debugPrint('📊 Battery analytics service started successfully');
    } catch (e) {
      debugPrint('📊 Error starting battery analytics service: $e');
      rethrow;
    }
  }

  /// Stop battery analytics service
  Future<void> stop() async {
    // Cancel timers
    _reportTimer?.cancel();
    _reportTimer = null;

    _trendAnalysisTimer?.cancel();
    _trendAnalysisTimer = null;

    // Close stream controllers
    await _reportController?.close();
    _reportController = null;

    await _insightController?.close();
    _insightController = null;

    _isActive = false;
    debugPrint('📊 Battery analytics service stopped');
  }

  /// Generate comprehensive battery report
  Future<BatteryReport> generateReport({
    ReportType type = ReportType.daily,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    debugPrint('📊 Generating ${type.name} battery report...');

    final now = DateTime.now();
    final reportStartDate = startDate ?? _getReportStartDate(type, now);
    final reportEndDate = endDate ?? now;

    // Collect data for the report period
    final analytics = _batteryService.getCurrentAnalytics();
    final healthAssessment = _batteryService.getCurrentHealthAssessment();
    final usageHistory =
        _batteryService.getUsageHistoryInRange(reportStartDate, reportEndDate);

    // Generate report sections
    final summary =
        _generateReportSummary(usageHistory, reportStartDate, reportEndDate);
    final trends = _generateTrendAnalysis(reportStartDate, reportEndDate);
    final serviceBreakdown = _generateServiceBreakdown(usageHistory);
    final recommendations =
        _generateRecommendations(analytics, healthAssessment);
    final insights = _generateInsights(usageHistory, trends);

    final report = BatteryReport(
      type: type,
      startDate: reportStartDate,
      endDate: reportEndDate,
      summary: summary,
      trends: trends,
      serviceBreakdown: serviceBreakdown,
      recommendations: recommendations,
      insights: insights,
      generatedAt: now,
    );

    // Emit report
    _reportController?.add(report);

    debugPrint('📊 ${type.name} battery report generated successfully');
    return report;
  }

  /// Get battery usage trends
  List<BatteryTrendData> getBatteryTrends({Duration? timeRange}) {
    var trends = _trendData.toList();

    if (timeRange != null) {
      final cutoff = DateTime.now().subtract(timeRange);
      trends =
          trends.where((trend) => trend.timestamp.isAfter(cutoff)).toList();
    }

    return trends;
  }

  /// Get service-specific analytics
  Map<String, ServiceAnalytics> getServiceAnalytics() =>
      Map.from(_serviceAnalytics);

  /// Get battery efficiency score
  double getBatteryEfficiencyScore() {
    final analytics = _batteryService.getCurrentAnalytics();
    return analytics.batteryHealthScore;
  }

  /// Get optimization impact analysis
  OptimizationImpactAnalysis getOptimizationImpact() =>
      _calculateOptimizationImpact();

  /// Record battery session data
  void recordBatterySession(BatterySessionRecord session) {
    _sessionHistory.add(session);
    if (_sessionHistory.length > _maxHistoryLength) {
      _sessionHistory.removeAt(0);
    }

    // Update service analytics
    _updateServiceAnalytics(session);

    // Check for insights
    _checkForInsights(session);
  }

  /// Export battery data
  Future<String> exportBatteryData({
    ExportFormat format = ExportFormat.json,
    Duration? timeRange,
  }) async {
    debugPrint('📊 Exporting battery data in ${format.name} format...');

    final now = DateTime.now();
    final startDate = timeRange != null
        ? now.subtract(timeRange)
        : DateTime.fromMillisecondsSinceEpoch(0);

    final data = {
      'export_info': {
        'format': format.name,
        'generated_at': now.toIso8601String(),
        'time_range': {
          'start': startDate.toIso8601String(),
          'end': now.toIso8601String(),
        },
      },
      'battery_analytics': _batteryService.getCurrentAnalytics(),
      'health_assessment': _batteryService.getCurrentHealthAssessment(),
      'usage_history': _batteryService.getUsageHistoryInRange(startDate, now),
      'trends': getBatteryTrends(timeRange: timeRange),
      'service_analytics': getServiceAnalytics(),
    };

    switch (format) {
      case ExportFormat.json:
        return _exportAsJson(data);
      case ExportFormat.csv:
        return _exportAsCsv(data);
      case ExportFormat.summary:
        return _exportAsSummary(data);
    }
  }

  void _startAnalysisTimers() {
    // Daily report generation
    _reportTimer = Timer.periodic(
      const Duration(hours: 24),
      (_) => _generateDailyReport(),
    );

    // Trend analysis
    _trendAnalysisTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _performTrendAnalysis(),
    );
  }

  Future<void> _generateDailyReport() async {
    await generateReport();
    _lastReportGeneration = DateTime.now();
    debugPrint('Battery report generated at $_lastReportGeneration');
  }

  void _performTrendAnalysis() {
    debugPrint('📊 Performing trend analysis...');

    final now = DateTime.now();
    final analytics = _batteryService.getCurrentAnalytics();
    final batteryLevel = _batteryService.currentBatteryLevel;

    if (batteryLevel != null) {
      final trendData = BatteryTrendData(
        timestamp: now,
        batteryLevel: batteryLevel.percentage,
        usageRate: analytics.averageUsagePerHour,
        healthScore: analytics.batteryHealthScore,
        activeServices: analytics.usageByService.length,
        powerMode: _batteryService.config.mode,
      );

      _trendData.add(trendData);
      if (_trendData.length > _maxHistoryLength) {
        _trendData.removeAt(0);
      }
    }

    debugPrint('📊 Trend analysis completed');
  }

  DateTime _getReportStartDate(ReportType type, DateTime endDate) {
    switch (type) {
      case ReportType.hourly:
        return endDate.subtract(const Duration(hours: 1));
      case ReportType.daily:
        return endDate.subtract(const Duration(days: 1));
      case ReportType.weekly:
        return endDate.subtract(const Duration(days: 7));
      case ReportType.monthly:
        return endDate.subtract(const Duration(days: 30));
    }
  }

  BatteryReportSummary _generateReportSummary(
    List<BatteryUsageEntry> usageHistory,
    DateTime startDate,
    DateTime endDate,
  ) {
    if (usageHistory.isEmpty) {
      return const BatteryReportSummary(
        totalUsageTime: Duration.zero,
        averageUsagePerHour: 0.0,
        peakUsagePerHour: 0.0,
        totalBatteryDrain: 0,
        averageBatteryLevel: 0,
        chargingTime: Duration.zero,
        mostUsedService: 'None',
        efficiencyScore: 0.0,
      );
    }

    final totalUsageTime = endDate.difference(startDate);
    final totalUsage = usageHistory.fold<double>(
        0.0, (sum, entry) => sum + entry.estimatedUsagePercent);
    final averageUsagePerHour =
        totalUsageTime.inHours > 0 ? totalUsage / totalUsageTime.inHours : 0.0;
    final peakUsagePerHour =
        usageHistory.map((e) => e.usageRatePerHour).fold<double>(0.0, math.max);

    final batteryDrains =
        usageHistory.map((e) => e.actualBatteryDrain).where((d) => d > 0);
    final totalBatteryDrain =
        batteryDrains.isNotEmpty ? batteryDrains.reduce((a, b) => a + b) : 0;

    final serviceUsage = <ServiceType, double>{};
    for (final entry in usageHistory) {
      serviceUsage[entry.serviceType] =
          (serviceUsage[entry.serviceType] ?? 0.0) +
              entry.estimatedUsagePercent;
    }

    final mostUsedService = serviceUsage.isNotEmpty
        ? serviceUsage.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key
            .displayName
        : 'None';

    final analytics = _batteryService.getCurrentAnalytics();
    final efficiencyScore = analytics.batteryHealthScore;

    return BatteryReportSummary(
      totalUsageTime: totalUsageTime,
      averageUsagePerHour: averageUsagePerHour,
      peakUsagePerHour: peakUsagePerHour,
      totalBatteryDrain: totalBatteryDrain,
      averageBatteryLevel: 50, // Simplified
      chargingTime: Duration.zero, // Would be calculated from charging events
      mostUsedService: mostUsedService,
      efficiencyScore: efficiencyScore,
    );
  }

  List<BatteryTrendData> _generateTrendAnalysis(
          DateTime startDate, DateTime endDate) =>
      _trendData
          .where((trend) =>
              trend.timestamp.isAfter(startDate) &&
              trend.timestamp.isBefore(endDate))
          .toList();

  Map<ServiceType, ServiceUsageBreakdown> _generateServiceBreakdown(
      List<BatteryUsageEntry> usageHistory) {
    final breakdown = <ServiceType, ServiceUsageBreakdown>{};

    for (final serviceType in ServiceType.values) {
      final serviceEntries =
          usageHistory.where((e) => e.serviceType == serviceType).toList();

      if (serviceEntries.isNotEmpty) {
        final totalUsage = serviceEntries.fold<double>(
            0.0, (sum, entry) => sum + entry.estimatedUsagePercent);
        final averageUsage = totalUsage / serviceEntries.length;
        final totalTime = serviceEntries.fold<Duration>(
            Duration.zero, (sum, entry) => sum + entry.duration);
        final usageCount = serviceEntries.length;

        breakdown[serviceType] = ServiceUsageBreakdown(
          serviceType: serviceType,
          totalUsage: totalUsage,
          averageUsage: averageUsage,
          totalTime: totalTime,
          usageCount: usageCount,
          efficiencyScore: _calculateServiceEfficiency(serviceEntries),
        );
      }
    }

    return breakdown;
  }

  List<BatteryOptimizationSuggestion> _generateRecommendations(
    BatteryAnalytics analytics,
    BatteryHealthAssessment healthAssessment,
  ) {
    final recommendations = <BatteryOptimizationSuggestion>[];

    // Add recommendations based on analytics
    recommendations.addAll(analytics.optimizationSuggestions);

    // Add health-based recommendations
    if (healthAssessment.grade == BatteryHealthGrade.poor ||
        healthAssessment.grade == BatteryHealthGrade.critical) {
      recommendations.add(const BatteryOptimizationSuggestion(
        type: OptimizationType.switchPowerMode,
        title: 'Switch to Battery Saver Mode',
        description:
            'Your battery health is poor. Consider switching to battery saver mode.',
        estimatedSavings: 30.0,
        priority: OptimizationPriority.high,
        actionRequired: 'Change power mode in settings',
      ));
    }

    return recommendations;
  }

  List<BatteryInsight> _generateInsights(
    List<BatteryUsageEntry> usageHistory,
    List<BatteryTrendData> trends,
  ) {
    final insights = <BatteryInsight>[];

    // Usage pattern insights
    if (usageHistory.isNotEmpty) {
      final peakUsageHour = _findPeakUsageHour(usageHistory);
      insights.add(BatteryInsight(
        type: InsightType.usagePattern,
        title: 'Peak Usage Time',
        description:
            'Your highest battery usage typically occurs around $peakUsageHour:00',
        severity: InsightSeverity.info,
        actionable: false,
        timestamp: DateTime.now(),
      ));
    }

    // Trend insights
    if (trends.length >= 24) {
      final recentTrends =
          trends.length > 24 ? trends.sublist(trends.length - 24) : trends;
      final trendDirection = _calculateTrendDirection(recentTrends);

      if (trendDirection < -0.1) {
        insights.add(BatteryInsight(
          type: InsightType.trend,
          title: 'Improving Battery Efficiency',
          description:
              'Your battery efficiency has improved by ${(trendDirection.abs() * 100).toStringAsFixed(1)}% over the last 24 hours',
          severity: InsightSeverity.positive,
          actionable: false,
          timestamp: DateTime.now(),
        ));
      } else if (trendDirection > 0.1) {
        insights.add(BatteryInsight(
          type: InsightType.trend,
          title: 'Declining Battery Efficiency',
          description:
              'Your battery efficiency has declined by ${(trendDirection * 100).toStringAsFixed(1)}% over the last 24 hours',
          severity: InsightSeverity.warning,
          actionable: true,
          timestamp: DateTime.now(),
        ));
      }
    }

    return insights;
  }

  double _calculateServiceEfficiency(List<BatteryUsageEntry> serviceEntries) {
    if (serviceEntries.isEmpty) return 0.0;

    // Calculate efficiency based on usage vs. battery drain
    final totalUsage = serviceEntries.fold<double>(
        0.0, (sum, entry) => sum + entry.estimatedUsagePercent);
    final totalDrain = serviceEntries.fold<int>(
        0, (sum, entry) => sum + entry.actualBatteryDrain);

    if (totalDrain == 0) return 1.0;

    // Higher efficiency means less battery drain for the same usage
    return math.max(0.0, 1.0 - (totalUsage / totalDrain));
  }

  int _findPeakUsageHour(List<BatteryUsageEntry> usageHistory) {
    final hourlyUsage = <int, double>{};

    for (final entry in usageHistory) {
      final hour = entry.startTime.hour;
      hourlyUsage[hour] =
          (hourlyUsage[hour] ?? 0.0) + entry.estimatedUsagePercent;
    }

    if (hourlyUsage.isEmpty) return 12; // Default to noon

    return hourlyUsage.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double _calculateTrendDirection(List<BatteryTrendData> trends) {
    if (trends.length < 2) return 0.0;

    final firstHalf = trends.take(trends.length ~/ 2).map((t) => t.healthScore);
    final secondHalf =
        trends.skip(trends.length ~/ 2).map((t) => t.healthScore);

    final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

    return (secondAvg - firstAvg) / firstAvg;
  }

  void _updateServiceAnalytics(BatterySessionRecord session) {
    // Update analytics for each service used in the session
    // This is a simplified implementation
    for (final serviceType in ServiceType.values) {
      final analytics = _serviceAnalytics[serviceType.displayName] ??
          ServiceAnalytics(
            serviceName: serviceType.displayName,
            totalUsageTime: Duration.zero,
            averageBatteryImpact: 0.0,
            usageCount: 0,
            efficiencyScore: 1.0,
            lastUsed: DateTime.now(),
          );

      _serviceAnalytics[serviceType.displayName] = ServiceAnalytics(
        serviceName: serviceType.displayName,
        totalUsageTime:
            analytics.totalUsageTime + const Duration(minutes: 1), // Simplified
        averageBatteryImpact: analytics.averageBatteryImpact,
        usageCount: analytics.usageCount + 1,
        efficiencyScore: analytics.efficiencyScore,
        lastUsed: DateTime.now(),
      );
    }
  }

  void _checkForInsights(BatterySessionRecord session) {
    // Check for notable patterns or anomalies
    if (session.batteryDrain > 20) {
      final insight = BatteryInsight(
        type: InsightType.anomaly,
        title: 'High Battery Drain Detected',
        description:
            'A session consumed ${session.batteryDrain}% battery, which is unusually high',
        severity: InsightSeverity.warning,
        actionable: true,
        timestamp: DateTime.now(),
      );
      _insightController?.add(insight);
    }
  }

  OptimizationImpactAnalysis _calculateOptimizationImpact() =>
      // Calculate the impact of battery optimizations
      // This would compare usage before and after optimizations
      OptimizationImpactAnalysis(
        totalOptimizations: 0, // Would be calculated from optimization history
        averageBatterySavings: 0.0,
        mostEffectiveOptimization: 'None',
        optimizationEffectiveness: 0.0,
        timestamp: DateTime.now(),
      );

  String _exportAsJson(Map<String, dynamic> data) =>
      // In a real implementation, this would use proper JSON encoding
      'JSON export not implemented';

  String _exportAsCsv(Map<String, dynamic> data) =>
      // In a real implementation, this would generate CSV format
      'CSV export not implemented';

  String _exportAsSummary(Map<String, dynamic> data) =>
      // In a real implementation, this would generate a human-readable summary
      'Summary export not implemented';

  /// Dispose of the service and clean up resources
  void dispose() {
    stop();
    _sessionHistory.clear();
    _trendData.clear();
    _serviceAnalytics.clear();
    _instance = null;
  }
}

/// Battery report types
enum ReportType {
  hourly,
  daily,
  weekly,
  monthly;

  String get name {
    switch (this) {
      case ReportType.hourly:
        return 'Hourly';
      case ReportType.daily:
        return 'Daily';
      case ReportType.weekly:
        return 'Weekly';
      case ReportType.monthly:
        return 'Monthly';
    }
  }
}

/// Export formats
enum ExportFormat {
  json,
  csv,
  summary;

  String get name {
    switch (this) {
      case ExportFormat.json:
        return 'JSON';
      case ExportFormat.csv:
        return 'CSV';
      case ExportFormat.summary:
        return 'Summary';
    }
  }
}

/// Comprehensive battery report
class BatteryReport {
  const BatteryReport({
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.summary,
    required this.trends,
    required this.serviceBreakdown,
    required this.recommendations,
    required this.insights,
    required this.generatedAt,
  });

  final ReportType type;
  final DateTime startDate;
  final DateTime endDate;
  final BatteryReportSummary summary;
  final List<BatteryTrendData> trends;
  final Map<ServiceType, ServiceUsageBreakdown> serviceBreakdown;
  final List<BatteryOptimizationSuggestion> recommendations;
  final List<BatteryInsight> insights;
  final DateTime generatedAt;
}

/// Battery report summary
class BatteryReportSummary {
  const BatteryReportSummary({
    required this.totalUsageTime,
    required this.averageUsagePerHour,
    required this.peakUsagePerHour,
    required this.totalBatteryDrain,
    required this.averageBatteryLevel,
    required this.chargingTime,
    required this.mostUsedService,
    required this.efficiencyScore,
  });

  final Duration totalUsageTime;
  final double averageUsagePerHour;
  final double peakUsagePerHour;
  final int totalBatteryDrain;
  final int averageBatteryLevel;
  final Duration chargingTime;
  final String mostUsedService;
  final double efficiencyScore;
}

/// Battery trend data point
class BatteryTrendData {
  const BatteryTrendData({
    required this.timestamp,
    required this.batteryLevel,
    required this.usageRate,
    required this.healthScore,
    required this.activeServices,
    required this.powerMode,
  });

  final DateTime timestamp;
  final int batteryLevel;
  final double usageRate;
  final double healthScore;
  final int activeServices;
  final PowerMode powerMode;
}

/// Service usage breakdown
class ServiceUsageBreakdown {
  const ServiceUsageBreakdown({
    required this.serviceType,
    required this.totalUsage,
    required this.averageUsage,
    required this.totalTime,
    required this.usageCount,
    required this.efficiencyScore,
  });

  final ServiceType serviceType;
  final double totalUsage;
  final double averageUsage;
  final Duration totalTime;
  final int usageCount;
  final double efficiencyScore;
}

/// Battery insight
class BatteryInsight {
  const BatteryInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
    required this.actionable,
    required this.timestamp,
  });

  final InsightType type;
  final String title;
  final String description;
  final InsightSeverity severity;
  final bool actionable;
  final DateTime timestamp;
}

/// Insight types
enum InsightType {
  usagePattern,
  trend,
  anomaly,
  optimization,
  recommendation;

  String get name {
    switch (this) {
      case InsightType.usagePattern:
        return 'Usage Pattern';
      case InsightType.trend:
        return 'Trend';
      case InsightType.anomaly:
        return 'Anomaly';
      case InsightType.optimization:
        return 'Optimization';
      case InsightType.recommendation:
        return 'Recommendation';
    }
  }
}

/// Insight severity levels
enum InsightSeverity {
  info,
  positive,
  warning,
  critical;

  String get name {
    switch (this) {
      case InsightSeverity.info:
        return 'Info';
      case InsightSeverity.positive:
        return 'Positive';
      case InsightSeverity.warning:
        return 'Warning';
      case InsightSeverity.critical:
        return 'Critical';
    }
  }
}

/// Battery session record
class BatterySessionRecord {
  const BatterySessionRecord({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.startBatteryLevel,
    required this.endBatteryLevel,
    required this.batteryDrain,
    required this.activeServices,
    required this.powerMode,
  });

  final String sessionId;
  final DateTime startTime;
  final DateTime endTime;
  final int startBatteryLevel;
  final int endBatteryLevel;
  final int batteryDrain;
  final List<ServiceType> activeServices;
  final PowerMode powerMode;

  Duration get duration => endTime.difference(startTime);
}

/// Service analytics
class ServiceAnalytics {
  const ServiceAnalytics({
    required this.serviceName,
    required this.totalUsageTime,
    required this.averageBatteryImpact,
    required this.usageCount,
    required this.efficiencyScore,
    required this.lastUsed,
  });

  final String serviceName;
  final Duration totalUsageTime;
  final double averageBatteryImpact;
  final int usageCount;
  final double efficiencyScore;
  final DateTime lastUsed;
}

/// Optimization impact analysis
class OptimizationImpactAnalysis {
  const OptimizationImpactAnalysis({
    required this.totalOptimizations,
    required this.averageBatterySavings,
    required this.mostEffectiveOptimization,
    required this.optimizationEffectiveness,
    required this.timestamp,
  });

  final int totalOptimizations;
  final double averageBatterySavings;
  final String mostEffectiveOptimization;
  final double optimizationEffectiveness;
  final DateTime timestamp;
}
