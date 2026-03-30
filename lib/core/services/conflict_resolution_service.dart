import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/security_models.dart';
import 'package:obsession_tracker/core/models/sync_models.dart';
import 'package:obsession_tracker/core/services/data_encryption_service.dart';

/// Merge strategy types for conflict resolution
enum MergeStrategyType {
  timestampBased,
  priorityBased,
  fieldLevel,
  union;

  String get name {
    switch (this) {
      case MergeStrategyType.timestampBased:
        return 'Timestamp Based';
      case MergeStrategyType.priorityBased:
        return 'Priority Based';
      case MergeStrategyType.fieldLevel:
        return 'Field Level';
      case MergeStrategyType.union:
        return 'Union';
    }
  }
}

/// Data validation result for conflict resolution
class DataValidationResult {
  const DataValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
}

/// Multi-device data consistency and conflict resolution service
class ConflictResolutionService {
  ConflictResolutionService({
    required DataEncryptionService encryptionService,
  }) : _encryptionService = encryptionService;

  final DataEncryptionService _encryptionService;

  // Service state
  bool _isInitialized = false;
  late String _currentDeviceId;

  // Conflict tracking
  final Map<String, SyncConflict> _activeConflicts = {};
  final Map<String, ConflictResolutionStrategy> _resolutionStrategies = {};
  final List<ConflictResolutionRule> _resolutionRules =
      <ConflictResolutionRule>[];

  // Stream controllers
  final StreamController<SyncConflict> _conflictController =
      StreamController.broadcast();
  final StreamController<ConflictResolutionRecord> _resolutionController =
      StreamController.broadcast();
  final StreamController<ConsistencyReport> _consistencyController =
      StreamController.broadcast();

  // Timers
  Timer? _consistencyCheckTimer;

  /// Stream of detected conflicts
  Stream<SyncConflict> get conflictStream => _conflictController.stream;

  /// Stream of conflict resolutions
  Stream<ConflictResolutionRecord> get resolutionStream =>
      _resolutionController.stream;

  /// Stream of consistency reports
  Stream<ConsistencyReport> get consistencyStream =>
      _consistencyController.stream;

  /// Initialize the conflict resolution service
  Future<void> initialize({
    required String deviceId,
    List<ConflictResolutionRule>? customRules,
  }) async {
    if (_isInitialized) return;

    try {
      debugPrint('⚖️ Initializing conflict resolution service...');

      _currentDeviceId = deviceId;

      // Initialize encryption service
      await _encryptionService.initialize(
        const DataEncryptionSettings(),
      );

      // Setup default resolution strategies
      _setupDefaultStrategies();

      // Setup default resolution rules
      _setupDefaultRules();

      // Add custom rules if provided
      if (customRules != null) {
        _resolutionRules.addAll(customRules);
      }

      // Load existing conflicts
      await _loadExistingConflicts();

      // Start consistency checking
      _startConsistencyChecking();

      _isInitialized = true;
      debugPrint('✅ Conflict resolution service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize conflict resolution service: $e');
      rethrow;
    }
  }

  /// Stop the conflict resolution service
  Future<void> stop() async {
    if (!_isInitialized) return;

    debugPrint('🛑 Stopping conflict resolution service...');

    // Cancel timers
    _consistencyCheckTimer?.cancel();

    // Save pending conflicts
    await _savePendingConflicts();

    _isInitialized = false;
    debugPrint('✅ Conflict resolution service stopped');
  }

  /// Detect conflicts between local and remote data
  Future<List<SyncConflict>> detectConflicts({
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    required String dataType,
    required String recordId,
  }) async {
    if (!_isInitialized) return [];

    debugPrint('🔍 Detecting conflicts for $dataType: $recordId');

    try {
      final conflicts = <SyncConflict>[];

      // Compare timestamps
      final localTimestamp = _extractTimestamp(localData);
      final remoteTimestamp = _extractTimestamp(remoteData);

      if (localTimestamp != null && remoteTimestamp != null) {
        final timeDiff = localTimestamp.difference(remoteTimestamp).abs();

        // If modifications happened within conflict window, check for conflicts
        if (timeDiff < const Duration(minutes: 5)) {
          final detectedConflicts = await _analyzeDataConflicts(
            localData: localData,
            remoteData: remoteData,
            dataType: dataType,
            recordId: recordId,
          );

          conflicts.addAll(detectedConflicts);
        }
      }

      // Store conflicts for resolution
      for (final conflict in conflicts) {
        _activeConflicts[conflict.id] = conflict;
        _conflictController.add(conflict);
      }

      debugPrint('🔍 Detected ${conflicts.length} conflicts for $recordId');
      return conflicts;
    } catch (e) {
      debugPrint('❌ Failed to detect conflicts: $e');
      return [];
    }
  }

  /// Automatically resolve conflicts using configured strategies
  Future<ConflictResolutionResult> autoResolveConflict(
      String conflictId) async {
    if (!_isInitialized) {
      return ConflictResolutionResult.failed('Service not initialized');
    }

    final conflict = _activeConflicts[conflictId];
    if (conflict == null) {
      return ConflictResolutionResult.failed('Conflict not found');
    }

    debugPrint('🤖 Auto-resolving conflict: $conflictId');

    try {
      // Find applicable resolution rule
      final rule = _findApplicableRule(conflict);
      if (rule == null) {
        return ConflictResolutionResult.failed('No applicable resolution rule');
      }

      // Apply resolution strategy
      final strategy = _resolutionStrategies[rule.strategy];
      if (strategy == null) {
        return ConflictResolutionResult.failed('Resolution strategy not found');
      }

      // Execute resolution
      final resolvedData = await strategy.resolve(conflict);

      // Create resolution record
      final resolution = ConflictResolutionRecord(
        id: _generateResolutionId(),
        conflictId: conflictId,
        strategy: rule.strategy,
        resolvedData: resolvedData,
        resolvedAt: DateTime.now(),
        resolvedBy: _currentDeviceId,
        isAutomatic: true,
      );

      // Update conflict as resolved
      final resolvedConflict = SyncConflict(
        id: conflict.id,
        dataType: conflict.dataType,
        recordId: conflict.recordId,
        localData: conflict.localData,
        remoteData: conflict.remoteData,
        createdAt: conflict.createdAt,
        resolvedAt: DateTime.now(),
        resolution: _parseConflictResolution(rule.strategy),
        resolvedData: resolvedData,
      );

      _activeConflicts[conflictId] = resolvedConflict;

      // Notify listeners
      _resolutionController.add(resolution);

      debugPrint('✅ Conflict auto-resolved: $conflictId');
      return ConflictResolutionResult.success(
          resolvedConflict.resolution ?? ConflictResolution.manual);
    } catch (e) {
      debugPrint('❌ Failed to auto-resolve conflict: $e');
      return ConflictResolutionResult.failed(e.toString());
    }
  }

  /// Manually resolve conflict with custom data
  Future<ConflictResolutionResult> manualResolveConflict({
    required String conflictId,
    required Map<String, dynamic> resolvedData,
    String? notes,
  }) async {
    if (!_isInitialized) {
      return ConflictResolutionResult.failed('Service not initialized');
    }

    final conflict = _activeConflicts[conflictId];
    if (conflict == null) {
      return ConflictResolutionResult.failed('Conflict not found');
    }

    debugPrint('👤 Manually resolving conflict: $conflictId');

    try {
      // Validate resolved data
      final validationResult = await _validateResolvedData(
        conflict.dataType,
        resolvedData,
      );

      if (!validationResult.isValid) {
        return ConflictResolutionResult.failed(
          'Invalid resolved data: ${validationResult.errors.join(', ')}',
        );
      }

      // Create resolution record
      final resolution = ConflictResolutionRecord(
        id: _generateResolutionId(),
        conflictId: conflictId,
        strategy: ConflictResolutionStrategy.manual,
        resolvedData: resolvedData,
        resolvedAt: DateTime.now(),
        resolvedBy: _currentDeviceId,
        isAutomatic: false,
        notes: notes,
      );

      // Update conflict as resolved
      final resolvedConflict = SyncConflict(
        id: conflict.id,
        dataType: conflict.dataType,
        recordId: conflict.recordId,
        localData: conflict.localData,
        remoteData: conflict.remoteData,
        createdAt: conflict.createdAt,
        resolvedAt: DateTime.now(),
        resolution: ConflictResolution.manual,
        resolvedData: resolvedData,
      );

      _activeConflicts[conflictId] = resolvedConflict;

      // Notify listeners
      _resolutionController.add(resolution);

      debugPrint('✅ Conflict manually resolved: $conflictId');
      return ConflictResolutionResult.success(
          resolvedConflict.resolution ?? ConflictResolution.manual);
    } catch (e) {
      debugPrint('❌ Failed to manually resolve conflict: $e');
      return ConflictResolutionResult.failed(e.toString());
    }
  }

  /// Check data consistency across devices
  Future<ConsistencyReport> checkDataConsistency({
    List<String>? sessionIds,
    bool includeWaypoints = true,
    bool includeBreadcrumbs = false,
  }) async {
    if (!_isInitialized) {
      return ConsistencyReport.empty();
    }

    debugPrint('🔍 Checking data consistency...');

    try {
      final report = ConsistencyReport(
        id: _generateReportId(),
        deviceId: _currentDeviceId,
        createdAt: DateTime.now(),
        sessionIds: sessionIds ?? [],
        issues: const [],
        recommendations: const [],
      );

      // Check session consistency
      final sessionIssues = await _checkSessionConsistency(sessionIds);
      report.issues.addAll(sessionIssues);

      // Check waypoint consistency if enabled
      if (includeWaypoints) {
        final waypointIssues = await _checkWaypointConsistency(sessionIds);
        report.issues.addAll(waypointIssues);
      }

      // Check breadcrumb consistency if enabled
      if (includeBreadcrumbs) {
        final breadcrumbIssues = await _checkBreadcrumbConsistency(sessionIds);
        report.issues.addAll(breadcrumbIssues);
      }

      // Generate recommendations
      report.recommendations.addAll(_generateRecommendations(report.issues));

      // Notify listeners
      _consistencyController.add(report);

      debugPrint(
          '📊 Consistency check completed: ${report.issues.length} issues found');
      return report;
    } catch (e) {
      debugPrint('❌ Failed to check data consistency: $e');
      return ConsistencyReport.empty();
    }
  }

  /// Merge data from multiple devices
  Future<Map<String, dynamic>> mergeDeviceData({
    required List<Map<String, dynamic>> deviceDataList,
    required String dataType,
    MergeStrategyType strategy = MergeStrategyType.timestampBased,
  }) async {
    if (!_isInitialized || deviceDataList.isEmpty) {
      return {};
    }

    debugPrint('🔀 Merging data from ${deviceDataList.length} devices');

    try {
      late Map<String, dynamic> mergedData;

      switch (strategy) {
        case MergeStrategyType.timestampBased:
          mergedData = await _mergeByTimestamp(deviceDataList);
          break;
        case MergeStrategyType.priorityBased:
          mergedData = await _mergeByPriority(deviceDataList);
          break;
        case MergeStrategyType.fieldLevel:
          mergedData = await _mergeByField(deviceDataList);
          break;
        case MergeStrategyType.union:
          mergedData = await _mergeByUnion(deviceDataList);
          break;
      }

      // Validate merged data
      final validationResult =
          await _validateResolvedData(dataType, mergedData);
      if (!validationResult.isValid) {
        throw Exception(
            'Merged data validation failed: ${validationResult.errors}');
      }

      debugPrint('✅ Data merged successfully using ${strategy.name} strategy');
      return mergedData;
    } catch (e) {
      debugPrint('❌ Failed to merge device data: $e');
      return deviceDataList.first;
    }
  }

  /// Get pending conflicts
  List<SyncConflict> getPendingConflicts() => _activeConflicts.values
      .where((conflict) => !conflict.isResolved)
      .toList();

  /// Get resolved conflicts
  List<SyncConflict> getResolvedConflicts() =>
      _activeConflicts.values.where((conflict) => conflict.isResolved).toList();

  // Private methods

  void _setupDefaultStrategies() {
    _resolutionStrategies[ConflictResolutionStrategy.localWins] =
        LocalWinsStrategy();
    _resolutionStrategies[ConflictResolutionStrategy.remoteWins] =
        RemoteWinsStrategy();
    _resolutionStrategies[ConflictResolutionStrategy.timestampBased] =
        TimestampBasedStrategy();
    _resolutionStrategies[ConflictResolutionStrategy.merge] = MergeStrategy();
    _resolutionStrategies[ConflictResolutionStrategy.keepBoth] =
        KeepBothStrategy();
  }

  void _setupDefaultRules() {
    // Session data: prefer most recent
    _resolutionRules.add(
      const ConflictResolutionRule(
        dataType: 'session',
        fieldPattern: '*',
        strategy: ConflictResolutionStrategy.timestampBased,
        priority: 1,
      ),
    );

    // Waypoints: keep both if different locations
    _resolutionRules.add(
      const ConflictResolutionRule(
        dataType: 'waypoint',
        fieldPattern: 'location',
        strategy: ConflictResolutionStrategy.keepBoth,
        priority: 2,
      ),
    );

    // User preferences: local wins
    _resolutionRules.add(
      const ConflictResolutionRule(
        dataType: 'settings',
        fieldPattern: '*',
        strategy: ConflictResolutionStrategy.localWins,
        priority: 3,
      ),
    );
  }

  Future<void> _loadExistingConflicts() async {
    try {
      // Load conflicts from storage
      debugPrint('📂 Loading existing conflicts...');

      // Implementation would load from database
    } catch (e) {
      debugPrint('❌ Failed to load existing conflicts: $e');
    }
  }

  void _startConsistencyChecking() {
    _consistencyCheckTimer = Timer.periodic(const Duration(hours: 1), (_) {
      checkDataConsistency();
    });
  }

  Future<void> _savePendingConflicts() async {
    try {
      // Save pending conflicts to storage
      debugPrint('💾 Saving pending conflicts...');

      // Implementation would save to database
    } catch (e) {
      debugPrint('❌ Failed to save pending conflicts: $e');
    }
  }

  DateTime? _extractTimestamp(Map<String, dynamic> data) {
    final timestamp =
        data['updated_at'] ?? data['modified_at'] ?? data['timestamp'];
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is String) {
      return DateTime.tryParse(timestamp);
    }
    return null;
  }

  Future<List<SyncConflict>> _analyzeDataConflicts({
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    required String dataType,
    required String recordId,
  }) async {
    final conflicts = <SyncConflict>[];

    // Compare each field
    for (final key in localData.keys) {
      if (remoteData.containsKey(key)) {
        final localValue = localData[key];
        final remoteValue = remoteData[key];

        if (!_areValuesEqual(localValue, remoteValue)) {
          final conflict = SyncConflict(
            id: _generateConflictId(),
            dataType: dataType,
            recordId: recordId,
            localData: {key: localValue},
            remoteData: {key: remoteValue},
            createdAt: DateTime.now(),
          );

          conflicts.add(conflict);
        }
      }
    }

    return conflicts;
  }

  bool _areValuesEqual(Object? value1, Object? value2) {
    if (value1.runtimeType != value2.runtimeType) return false;

    if (value1 is Map && value2 is Map) {
      return _areMapsEqual(value1, value2);
    } else if (value1 is List && value2 is List) {
      return _areListsEqual(value1, value2);
    } else {
      return value1 == value2;
    }
  }

  bool _areMapsEqual(Map<dynamic, dynamic> map1, Map<dynamic, dynamic> map2) {
    if (map1.length != map2.length) return false;

    for (final key in map1.keys) {
      if (!map2.containsKey(key) || !_areValuesEqual(map1[key], map2[key])) {
        return false;
      }
    }

    return true;
  }

  bool _areListsEqual(List<dynamic> list1, List<dynamic> list2) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      if (!_areValuesEqual(list1[i], list2[i])) {
        return false;
      }
    }

    return true;
  }

  ConflictResolutionRule? _findApplicableRule(SyncConflict conflict) =>
      _resolutionRules
          .where((rule) =>
              rule.dataType == conflict.dataType || rule.dataType == '*')
          .fold<ConflictResolutionRule?>(null, (best, current) {
        if (best == null || current.priority < best.priority) {
          return current;
        }
        return best;
      });

  ConflictResolution _parseConflictResolution(String strategy) {
    switch (strategy.toLowerCase()) {
      case 'manual':
        return ConflictResolution.manual;
      case 'localwins':
      case 'local_wins':
        return ConflictResolution.localWins;
      case 'remotewins':
      case 'remote_wins':
        return ConflictResolution.remoteWins;
      case 'merge':
        return ConflictResolution.merge;
      case 'keepboth':
      case 'keep_both':
        return ConflictResolution.keepBoth;
      default:
        return ConflictResolution.manual;
    }
  }

  Future<DataValidationResult> _validateResolvedData(
    String dataType,
    Map<String, dynamic> data,
  ) async {
    final errors = <String>[];

    // Basic validation based on data type
    switch (dataType) {
      case 'session':
        if (!data.containsKey('id')) errors.add('Missing session ID');
        if (!data.containsKey('name')) errors.add('Missing session name');
        break;
      case 'waypoint':
        if (!data.containsKey('latitude')) errors.add('Missing latitude');
        if (!data.containsKey('longitude')) errors.add('Missing longitude');
        break;
    }

    return DataValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  Future<List<ConsistencyIssue>> _checkSessionConsistency(
      List<String>? sessionIds) async {
    final issues = <ConsistencyIssue>[];

    // Implementation would check session consistency

    return issues;
  }

  Future<List<ConsistencyIssue>> _checkWaypointConsistency(
      List<String>? sessionIds) async {
    final issues = <ConsistencyIssue>[];

    // Implementation would check waypoint consistency

    return issues;
  }

  Future<List<ConsistencyIssue>> _checkBreadcrumbConsistency(
      List<String>? sessionIds) async {
    final issues = <ConsistencyIssue>[];

    // Implementation would check breadcrumb consistency

    return issues;
  }

  List<ConsistencyRecommendation> _generateRecommendations(
      List<ConsistencyIssue> issues) {
    final recommendations = <ConsistencyRecommendation>[];

    for (final issue in issues) {
      switch (issue.type) {
        case ConsistencyIssueType.duplicateData:
          recommendations.add(
            ConsistencyRecommendation(
              type: RecommendationType.merge,
              description: 'Merge duplicate ${issue.dataType} records',
              priority: RecommendationPriority.medium,
            ),
          );
          break;
        case ConsistencyIssueType.missingData:
          recommendations.add(
            ConsistencyRecommendation(
              type: RecommendationType.sync,
              description: 'Sync missing ${issue.dataType} from other devices',
              priority: RecommendationPriority.high,
            ),
          );
          break;
        case ConsistencyIssueType.conflictingData:
          recommendations.add(
            ConsistencyRecommendation(
              type: RecommendationType.resolve,
              description: 'Resolve conflicts in ${issue.dataType}',
              priority: RecommendationPriority.high,
            ),
          );
          break;
        case ConsistencyIssueType.corruptedData:
          recommendations.add(
            ConsistencyRecommendation(
              type: RecommendationType.resolve,
              description: 'Repair corrupted ${issue.dataType} data',
              priority: RecommendationPriority.critical,
            ),
          );
          break;
        case ConsistencyIssueType.orphanedData:
          recommendations.add(
            ConsistencyRecommendation(
              type: RecommendationType.cleanup,
              description: 'Clean up orphaned ${issue.dataType} records',
              priority: RecommendationPriority.low,
            ),
          );
          break;
      }
    }

    return recommendations;
  }

  Future<Map<String, dynamic>> _mergeByTimestamp(
      List<Map<String, dynamic>> dataList) async {
    // Sort by timestamp and take the most recent
    dataList.sort((a, b) {
      final timestampA = _extractTimestamp(a);
      final timestampB = _extractTimestamp(b);

      if (timestampA == null && timestampB == null) return 0;
      if (timestampA == null) return 1;
      if (timestampB == null) return -1;

      return timestampB.compareTo(timestampA);
    });

    return dataList.first;
  }

  Future<Map<String, dynamic>> _mergeByPriority(
          List<Map<String, dynamic>> dataList) async =>
      // Implementation would merge based on device priority
      dataList.first;

  Future<Map<String, dynamic>> _mergeByField(
      List<Map<String, dynamic>> dataList) async {
    final merged = <String, dynamic>{};

    // Merge field by field, taking most recent for each field
    for (final data in dataList) {
      for (final entry in data.entries) {
        if (!merged.containsKey(entry.key)) {
          merged[entry.key] = entry.value;
        }
      }
    }

    return merged;
  }

  Future<Map<String, dynamic>> _mergeByUnion(
      List<Map<String, dynamic>> dataList) async {
    final merged = <String, dynamic>{};

    // Union all data
    dataList.forEach(merged.addAll);

    return merged;
  }

  String _generateConflictId() =>
      'conflict_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';

  String _generateResolutionId() =>
      'resolution_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';

  String _generateReportId() =>
      'report_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';

  /// Dispose of the service
  void dispose() {
    _consistencyCheckTimer?.cancel();
    _conflictController.close();
    _resolutionController.close();
    _consistencyController.close();
  }
}

// Supporting classes and enums

/// Conflict resolution strategy interface
abstract class ConflictResolutionStrategy {
  static const String localWins = 'local_wins';
  static const String remoteWins = 'remote_wins';
  static const String timestampBased = 'timestamp_based';
  static const String merge = 'merge';
  static const String keepBoth = 'keep_both';
  static const String manual = 'manual';

  Future<Map<String, dynamic>> resolve(SyncConflict conflict);
}

/// Local wins strategy
class LocalWinsStrategy implements ConflictResolutionStrategy {
  @override
  Future<Map<String, dynamic>> resolve(SyncConflict conflict) async =>
      conflict.localData;
}

/// Remote wins strategy
class RemoteWinsStrategy implements ConflictResolutionStrategy {
  @override
  Future<Map<String, dynamic>> resolve(SyncConflict conflict) async =>
      conflict.remoteData;
}

/// Timestamp-based strategy
class TimestampBasedStrategy implements ConflictResolutionStrategy {
  @override
  Future<Map<String, dynamic>> resolve(SyncConflict conflict) async {
    final localTimestamp = _extractTimestamp(conflict.localData);
    final remoteTimestamp = _extractTimestamp(conflict.remoteData);

    if (localTimestamp != null && remoteTimestamp != null) {
      return localTimestamp.isAfter(remoteTimestamp)
          ? conflict.localData
          : conflict.remoteData;
    }

    return conflict.localData;
  }

  DateTime? _extractTimestamp(Map<String, dynamic> data) {
    final timestamp =
        data['updated_at'] ?? data['modified_at'] ?? data['timestamp'];
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is String) {
      return DateTime.tryParse(timestamp);
    }
    return null;
  }
}

/// Merge strategy
class MergeStrategy implements ConflictResolutionStrategy {
  @override
  Future<Map<String, dynamic>> resolve(SyncConflict conflict) async {
    final merged = Map<String, dynamic>.from(conflict.localData);

    // Merge remote data, preferring non-null values
    for (final entry in conflict.remoteData.entries) {
      if (entry.value != null) {
        merged[entry.key] = entry.value;
      }
    }

    return merged;
  }
}

/// Keep both strategy
class KeepBothStrategy implements ConflictResolutionStrategy {
  @override
  Future<Map<String, dynamic>> resolve(SyncConflict conflict) async => {
        'local': conflict.localData,
        'remote': conflict.remoteData,
        'resolution_type': 'keep_both',
        'resolved_at': DateTime.now().toIso8601String(),
      };
}

/// Conflict resolution rule
@immutable
class ConflictResolutionRule {
  const ConflictResolutionRule({
    required this.dataType,
    required this.fieldPattern,
    required this.strategy,
    required this.priority,
    this.conditions = const {},
  });

  final String dataType;
  final String fieldPattern;
  final String strategy;
  final int priority;
  final Map<String, dynamic> conditions;
}

/// Conflict resolution result
@immutable
class ConflictResolutionResult {
  const ConflictResolutionResult._({
    required this.success,
    this.resolution,
    this.error,
  });

  factory ConflictResolutionResult.success(ConflictResolution resolution) =>
      ConflictResolutionResult._(success: true, resolution: resolution);

  factory ConflictResolutionResult.failed(String error) =>
      ConflictResolutionResult._(success: false, error: error);

  final bool success;
  final ConflictResolution? resolution;
  final String? error;
}

/// Conflict resolution record
@immutable
class ConflictResolutionRecord {
  const ConflictResolutionRecord({
    required this.id,
    required this.conflictId,
    required this.strategy,
    required this.resolvedData,
    required this.resolvedAt,
    required this.resolvedBy,
    required this.isAutomatic,
    this.notes,
  });

  final String id;
  final String conflictId;
  final String strategy;
  final Map<String, dynamic> resolvedData;
  final DateTime resolvedAt;
  final String resolvedBy;
  final bool isAutomatic;
  final String? notes;
}

/// Data consistency report
@immutable
class ConsistencyReport {
  const ConsistencyReport({
    required this.id,
    required this.deviceId,
    required this.createdAt,
    required this.sessionIds,
    required this.issues,
    required this.recommendations,
  });

  factory ConsistencyReport.empty() => ConsistencyReport(
        id: '',
        deviceId: '',
        createdAt: DateTime.now(),
        sessionIds: const [],
        issues: const [],
        recommendations: const [],
      );

  final String id;
  final String deviceId;
  final DateTime createdAt;
  final List<String> sessionIds;
  final List<ConsistencyIssue> issues;
  final List<ConsistencyRecommendation> recommendations;
}

/// Consistency issue
@immutable
class ConsistencyIssue {
  const ConsistencyIssue({
    required this.type,
    required this.dataType,
    required this.recordId,
    required this.description,
    required this.severity,
  });

  final ConsistencyIssueType type;
  final String dataType;
  final String recordId;
  final String description;
  final IssueSeverity severity;
}

/// Types of consistency issues
enum ConsistencyIssueType {
  duplicateData,
  missingData,
  conflictingData,
  corruptedData,
  orphanedData,
}

/// Issue severity levels
enum IssueSeverity {
  low,
  medium,
  high,
  critical,
}

/// Consistency recommendation
@immutable
class ConsistencyRecommendation {
  const ConsistencyRecommendation({
    required this.type,
    required this.description,
    required this.priority,
  });

  final RecommendationType type;
  final String description;
  final RecommendationPriority priority;
}

/// Types of recommendations
enum RecommendationType {
  sync,
  merge,
  resolve,
  cleanup,
  backup,
}

/// Recommendation priority
enum RecommendationPriority {
  low,
  medium,
  high,
  critical,
}
