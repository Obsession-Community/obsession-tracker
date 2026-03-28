import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/battery_models.dart';
import 'package:obsession_tracker/core/services/battery_monitoring_service.dart';
import 'package:workmanager/workmanager.dart';

/// Comprehensive background task lifecycle management service
///
/// Manages background tasks, their priorities, resource allocation,
/// and cleanup to optimize battery usage and system performance.
class BackgroundTaskManager {
  factory BackgroundTaskManager() => _instance ??= BackgroundTaskManager._();
  BackgroundTaskManager._();
  static BackgroundTaskManager? _instance;

  final BatteryMonitoringService _batteryService = BatteryMonitoringService();

  // Stream controllers
  StreamController<BackgroundTaskEvent>? _taskEventController;
  StreamController<TaskPerformanceMetrics>? _metricsController;

  // Task management
  final Map<String, BackgroundTask> _activeTasks = {};
  final Map<String, TaskConfiguration> _taskConfigurations = {};
  final List<TaskExecutionRecord> _executionHistory = <TaskExecutionRecord>[];
  static const int _maxExecutionHistoryLength = 500;

  // Resource management
  final Map<String, ResourceUsage> _resourceUsage = {};
  Timer? _resourceMonitorTimer;
  Timer? _cleanupTimer;

  // Service state
  bool _isActive = false;
  TaskPriority _currentPriorityThreshold = TaskPriority.medium;
  PowerMode _currentPowerMode = PowerMode.balanced;

  /// Stream of background task events
  Stream<BackgroundTaskEvent> get taskEventStream {
    _taskEventController ??= StreamController<BackgroundTaskEvent>.broadcast();
    return _taskEventController!.stream;
  }

  /// Stream of task performance metrics
  Stream<TaskPerformanceMetrics> get metricsStream {
    _metricsController ??= StreamController<TaskPerformanceMetrics>.broadcast();
    return _metricsController!.stream;
  }

  /// Whether the task manager is active
  bool get isActive => _isActive;

  /// Currently active tasks
  Map<String, BackgroundTask> get activeTasks => Map.from(_activeTasks);

  /// Current priority threshold
  TaskPriority get currentPriorityThreshold => _currentPriorityThreshold;

  /// Start background task manager
  Future<void> start({
    PowerMode initialPowerMode = PowerMode.balanced,
  }) async {
    try {
      await stop(); // Ensure clean start

      _currentPowerMode = initialPowerMode;
      _currentPriorityThreshold =
          _getPriorityThresholdForPowerMode(initialPowerMode);

      debugPrint('🔄 Starting background task manager...');
      debugPrint('  Power mode: ${initialPowerMode.name}');
      debugPrint('  Priority threshold: ${_currentPriorityThreshold.name}');

      // Initialize stream controllers
      _taskEventController ??=
          StreamController<BackgroundTaskEvent>.broadcast();
      _metricsController ??=
          StreamController<TaskPerformanceMetrics>.broadcast();

      // Initialize Workmanager
      await Workmanager().initialize(
        _backgroundTaskCallbackDispatcher,
      );

      // Register default task configurations
      _registerDefaultTaskConfigurations();

      // Start resource monitoring
      _startResourceMonitoring();

      // Start cleanup timer
      _startCleanupTimer();

      _isActive = true;
      debugPrint('🔄 Background task manager started successfully');
    } catch (e) {
      debugPrint('🔄 Error starting background task manager: $e');
      rethrow;
    }
  }

  /// Stop background task manager
  Future<void> stop() async {
    // Cancel all active tasks
    for (final taskId in _activeTasks.keys.toList()) {
      await cancelTask(taskId, reason: 'Service stopping');
    }

    // Cancel timers
    _resourceMonitorTimer?.cancel();
    _resourceMonitorTimer = null;

    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    // Cancel all Workmanager tasks
    await Workmanager().cancelAll();

    // Close stream controllers
    await _taskEventController?.close();
    _taskEventController = null;

    await _metricsController?.close();
    _metricsController = null;

    _isActive = false;
    debugPrint('🔄 Background task manager stopped');
  }

  /// Register a background task
  Future<void> registerTask(BackgroundTask task) async {
    if (!_isActive) {
      throw StateError('Background task manager is not active');
    }

    debugPrint('🔄 Registering background task: ${task.id}');

    // Check if task meets priority threshold
    if (!_shouldExecuteTask(task)) {
      debugPrint('🔄 Task ${task.id} does not meet priority threshold');
      return;
    }

    // Store task configuration
    _taskConfigurations[task.id] = task.configuration;

    // Register with Workmanager
    await _registerWithWorkmanager(task);

    // Track task
    _activeTasks[task.id] = task;

    // Start battery tracking for this task
    _batteryService.startServiceTracking(task.serviceType);

    // Emit task event
    final event = BackgroundTaskEvent(
      type: TaskEventType.registered,
      taskId: task.id,
      description: 'Task registered successfully',
      timestamp: DateTime.now(),
    );
    _taskEventController?.add(event);

    debugPrint('🔄 Background task ${task.id} registered successfully');
  }

  /// Cancel a background task
  Future<void> cancelTask(String taskId, {String? reason}) async {
    final task = _activeTasks[taskId];
    if (task == null) {
      debugPrint('🔄 Task $taskId not found');
      return;
    }

    debugPrint('🔄 Cancelling background task: $taskId');
    if (reason != null) {
      debugPrint('  Reason: $reason');
    }

    // Cancel with Workmanager
    await Workmanager().cancelByUniqueName(taskId);

    // Stop battery tracking
    _batteryService.stopServiceTracking(task.serviceType);

    // Remove from active tasks
    _activeTasks.remove(taskId);

    // Record execution
    _recordTaskExecution(task, TaskExecutionResult.cancelled, reason: reason);

    // Emit task event
    final event = BackgroundTaskEvent(
      type: TaskEventType.cancelled,
      taskId: taskId,
      description: reason ?? 'Task cancelled',
      timestamp: DateTime.now(),
    );
    _taskEventController?.add(event);

    debugPrint('🔄 Background task $taskId cancelled');
  }

  /// Update power mode and adjust task priorities
  Future<void> updatePowerMode(PowerMode newPowerMode) async {
    if (newPowerMode == _currentPowerMode) return;

    final oldMode = _currentPowerMode;
    _currentPowerMode = newPowerMode;
    _currentPriorityThreshold = _getPriorityThresholdForPowerMode(newPowerMode);

    debugPrint(
        '🔄 Updating power mode: ${oldMode.name} → ${newPowerMode.name}');
    debugPrint('  New priority threshold: ${_currentPriorityThreshold.name}');

    // Re-evaluate all active tasks
    await _reevaluateActiveTasks();

    debugPrint('🔄 Power mode updated successfully');
  }

  /// Get task execution history
  List<TaskExecutionRecord> getExecutionHistory({
    String? taskId,
    Duration? timeRange,
  }) {
    var history = _executionHistory.toList();

    if (taskId != null) {
      history = history.where((record) => record.taskId == taskId).toList();
    }

    if (timeRange != null) {
      final cutoff = DateTime.now().subtract(timeRange);
      history =
          history.where((record) => record.startTime.isAfter(cutoff)).toList();
    }

    return history;
  }

  /// Get current task performance metrics
  TaskPerformanceMetrics getCurrentMetrics() => _generatePerformanceMetrics();

  /// Get resource usage statistics
  Map<String, ResourceUsage> getResourceUsage() => Map.from(_resourceUsage);

  /// Cleanup completed and failed tasks
  Future<void> performCleanup() async {
    debugPrint('🔄 Performing background task cleanup...');

    final now = DateTime.now();
    final tasksToRemove = <String>[];

    // Find tasks that should be cleaned up
    for (final entry in _activeTasks.entries) {
      final task = entry.value;
      final taskId = entry.key;

      // Check if task has exceeded maximum runtime
      if (task.configuration.maxExecutionTime != null) {
        final maxRuntime = task.configuration.maxExecutionTime!;
        if (now.difference(task.startTime) > maxRuntime) {
          tasksToRemove.add(taskId);
          debugPrint('🔄 Task $taskId exceeded maximum runtime');
        }
      }

      // Check if task should be cancelled due to low battery
      final batteryLevel = _batteryService.currentBatteryLevel;
      if (batteryLevel != null && batteryLevel.isCriticallyLow) {
        if (task.priority == TaskPriority.low ||
            task.priority == TaskPriority.medium) {
          tasksToRemove.add(taskId);
          debugPrint('🔄 Task $taskId cancelled due to critical battery level');
        }
      }
    }

    // Cancel identified tasks
    for (final taskId in tasksToRemove) {
      await cancelTask(taskId,
          reason: 'Cleanup - exceeded limits or low battery');
    }

    // Cleanup execution history
    if (_executionHistory.length > _maxExecutionHistoryLength) {
      final excessCount = _executionHistory.length - _maxExecutionHistoryLength;
      _executionHistory.removeRange(0, excessCount);
    }

    debugPrint('🔄 Cleanup completed: ${tasksToRemove.length} tasks removed');
  }

  void _registerDefaultTaskConfigurations() {
    // Location tracking task
    _taskConfigurations['location_tracking'] = const TaskConfiguration(
      frequency: Duration(seconds: 30),
      constraints: TaskConstraints(
        requiresNetworkConnectivity: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresBatteryNotLow: false,
      ),
      maxExecutionTime: Duration(hours: 24),
      retryPolicy: RetryPolicy(
        maxRetries: 3,
        backoffMultiplier: 2.0,
        initialDelay: Duration(seconds: 30),
      ),
    );

    // Sensor data collection task
    _taskConfigurations['sensor_collection'] = const TaskConfiguration(
      frequency: Duration(minutes: 5),
      constraints: TaskConstraints(
        requiresNetworkConnectivity: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresBatteryNotLow: true,
      ),
      maxExecutionTime: Duration(hours: 12),
      retryPolicy: RetryPolicy(
        maxRetries: 2,
        backoffMultiplier: 1.5,
        initialDelay: Duration(minutes: 1),
      ),
    );

    // Data synchronization task
    _taskConfigurations['data_sync'] = const TaskConfiguration(
      frequency: Duration(hours: 1),
      constraints: TaskConstraints(
        requiresNetworkConnectivity: true,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresBatteryNotLow: true,
      ),
      maxExecutionTime: Duration(minutes: 30),
      retryPolicy: RetryPolicy(
        maxRetries: 5,
        backoffMultiplier: 2.0,
        initialDelay: Duration(minutes: 5),
      ),
    );

    debugPrint('🔄 Default task configurations registered');
  }

  Future<void> _registerWithWorkmanager(BackgroundTask task) async {
    final config = task.configuration;

    // Convert constraints
    final constraints = Constraints(
      networkType: config.constraints.requiresNetworkConnectivity
          ? NetworkType.connected
          : NetworkType.notRequired,
      requiresBatteryNotLow: config.constraints.requiresBatteryNotLow,
      requiresCharging: config.constraints.requiresCharging,
      requiresDeviceIdle: config.constraints.requiresDeviceIdle,
      requiresStorageNotLow: false,
    );

    // Register based on task type
    switch (task.type) {
      case TaskType.oneTime:
        await Workmanager().registerOneOffTask(
          task.id,
          task.id,
          constraints: constraints,
          initialDelay: config.initialDelay ?? Duration.zero,
          inputData: task.inputData,
        );
        break;

      case TaskType.periodic:
        await Workmanager().registerPeriodicTask(
          task.id,
          task.id,
          frequency: config.frequency,
          constraints: constraints,
          initialDelay: config.initialDelay ?? Duration.zero,
          inputData: task.inputData,
        );
        break;
    }
  }

  bool _shouldExecuteTask(BackgroundTask task) {
    // Check priority threshold
    if (task.priority.index < _currentPriorityThreshold.index) {
      return false;
    }

    // Check battery level constraints
    final batteryLevel = _batteryService.currentBatteryLevel;
    if (batteryLevel != null) {
      if (task.configuration.constraints.requiresBatteryNotLow &&
          batteryLevel.isLow) {
        return false;
      }

      if (batteryLevel.isCriticallyLow &&
          task.priority != TaskPriority.critical) {
        return false;
      }
    }

    return true;
  }

  TaskPriority _getPriorityThresholdForPowerMode(PowerMode powerMode) {
    switch (powerMode) {
      case PowerMode.highPerformance:
        return TaskPriority.low;
      case PowerMode.balanced:
        return TaskPriority.medium;
      case PowerMode.batterySaver:
        return TaskPriority.high;
      case PowerMode.ultraBatterySaver:
        return TaskPriority.critical;
    }
  }

  Future<void> _reevaluateActiveTasks() async {
    final tasksToCancel = <String>[];

    for (final entry in _activeTasks.entries) {
      final taskId = entry.key;
      final task = entry.value;

      if (!_shouldExecuteTask(task)) {
        tasksToCancel.add(taskId);
      }
    }

    for (final taskId in tasksToCancel) {
      await cancelTask(taskId,
          reason: 'Power mode change - priority threshold not met');
    }
  }

  void _startResourceMonitoring() {
    _resourceMonitorTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _monitorResourceUsage(),
    );
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => performCleanup(),
    );
  }

  void _monitorResourceUsage() {
    // Monitor CPU, memory, and battery usage
    // This is a simplified implementation
    for (final task in _activeTasks.values) {
      final usage = ResourceUsage(
        taskId: task.id,
        cpuUsage: 0.0, // Would be measured in real implementation
        memoryUsage: 0, // Would be measured in real implementation
        batteryUsage: 0.0, // Would be measured in real implementation
        timestamp: DateTime.now(),
      );

      _resourceUsage[task.id] = usage;
    }

    // Generate and emit metrics
    final metrics = _generatePerformanceMetrics();
    _metricsController?.add(metrics);
  }

  TaskPerformanceMetrics _generatePerformanceMetrics() {
    final now = DateTime.now();
    final recentHistory = _executionHistory
        .where((record) => now.difference(record.startTime).inHours < 24)
        .toList();

    final totalExecutions = recentHistory.length;
    final successfulExecutions = recentHistory
        .where((record) => record.result == TaskExecutionResult.success)
        .length;
    final failedExecutions = recentHistory
        .where((record) => record.result == TaskExecutionResult.failed)
        .length;

    final successRate =
        totalExecutions > 0 ? successfulExecutions / totalExecutions : 0.0;

    final averageExecutionTime = recentHistory.isNotEmpty
        ? recentHistory
                .where((record) => record.executionTime != null)
                .map((record) => record.executionTime!.inMilliseconds)
                .fold<int>(0, (sum, duration) => sum + duration) /
            recentHistory.length
        : 0.0;

    return TaskPerformanceMetrics(
      activeTasks: _activeTasks.length,
      totalExecutions: totalExecutions,
      successfulExecutions: successfulExecutions,
      failedExecutions: failedExecutions,
      successRate: successRate,
      averageExecutionTime:
          Duration(milliseconds: averageExecutionTime.round()),
      resourceUsage: Map.from(_resourceUsage),
      timestamp: now,
    );
  }

  void _recordTaskExecution(
    BackgroundTask task,
    TaskExecutionResult result, {
    Duration? executionTime,
    String? reason,
    String? errorMessage,
  }) {
    final record = TaskExecutionRecord(
      taskId: task.id,
      taskType: task.type,
      priority: task.priority,
      startTime: task.startTime,
      endTime: DateTime.now(),
      executionTime: executionTime,
      result: result,
      reason: reason,
      errorMessage: errorMessage,
    );

    _executionHistory.add(record);

    // Emit task event
    final event = BackgroundTaskEvent(
      type: _getEventTypeForResult(result),
      taskId: task.id,
      description: reason ?? result.name,
      timestamp: DateTime.now(),
    );
    _taskEventController?.add(event);
  }

  TaskEventType _getEventTypeForResult(TaskExecutionResult result) {
    switch (result) {
      case TaskExecutionResult.success:
        return TaskEventType.completed;
      case TaskExecutionResult.failed:
        return TaskEventType.failed;
      case TaskExecutionResult.cancelled:
        return TaskEventType.cancelled;
      case TaskExecutionResult.timeout:
        return TaskEventType.timeout;
    }
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    stop();
    _activeTasks.clear();
    _taskConfigurations.clear();
    _executionHistory.clear();
    _resourceUsage.clear();
    _instance = null;
  }
}

/// Background task callback dispatcher for Workmanager
@pragma('vm:entry-point')
void _backgroundTaskCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('🔄 Executing background task: $task');

      // Task execution logic would go here
      // This is where the actual background work is performed

      // Simulate task execution
      await Future<void>.delayed(const Duration(seconds: 2));

      debugPrint('🔄 Background task $task completed successfully');
      return Future.value(true);
    } catch (e) {
      debugPrint('🔄 Background task $task failed: $e');
      return Future.value(false);
    }
  });
}

/// Background task definition
class BackgroundTask {
  const BackgroundTask({
    required this.id,
    required this.type,
    required this.priority,
    required this.serviceType,
    required this.configuration,
    required this.startTime,
    this.inputData = const {},
  });

  final String id;
  final TaskType type;
  final TaskPriority priority;
  final ServiceType serviceType;
  final TaskConfiguration configuration;
  final DateTime startTime;
  final Map<String, dynamic> inputData;

  @override
  String toString() => 'BackgroundTask($id: ${type.name}, ${priority.name})';
}

/// Task configuration
class TaskConfiguration {
  const TaskConfiguration({
    required this.frequency,
    required this.constraints,
    this.maxExecutionTime,
    this.initialDelay,
    this.retryPolicy,
  });

  final Duration frequency;
  final TaskConstraints constraints;
  final Duration? maxExecutionTime;
  final Duration? initialDelay;
  final RetryPolicy? retryPolicy;
}

/// Task constraints
class TaskConstraints {
  const TaskConstraints({
    required this.requiresNetworkConnectivity,
    required this.requiresCharging,
    required this.requiresDeviceIdle,
    required this.requiresBatteryNotLow,
  });

  final bool requiresNetworkConnectivity;
  final bool requiresCharging;
  final bool requiresDeviceIdle;
  final bool requiresBatteryNotLow;
}

/// Retry policy for failed tasks
class RetryPolicy {
  const RetryPolicy({
    required this.maxRetries,
    required this.backoffMultiplier,
    required this.initialDelay,
  });

  final int maxRetries;
  final double backoffMultiplier;
  final Duration initialDelay;
}

/// Task types
enum TaskType {
  oneTime,
  periodic;

  String get displayName {
    switch (this) {
      case TaskType.oneTime:
        return 'One-time';
      case TaskType.periodic:
        return 'Periodic';
    }
  }
}

/// Task priorities
enum TaskPriority {
  low,
  medium,
  high,
  critical;

  String get displayName {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.critical:
        return 'Critical';
    }
  }
}

/// Task execution results
enum TaskExecutionResult {
  success,
  failed,
  cancelled,
  timeout;

  String get displayName {
    switch (this) {
      case TaskExecutionResult.success:
        return 'Success';
      case TaskExecutionResult.failed:
        return 'Failed';
      case TaskExecutionResult.cancelled:
        return 'Cancelled';
      case TaskExecutionResult.timeout:
        return 'Timeout';
    }
  }
}

/// Task execution record
class TaskExecutionRecord {
  const TaskExecutionRecord({
    required this.taskId,
    required this.taskType,
    required this.priority,
    required this.startTime,
    required this.endTime,
    required this.result,
    this.executionTime,
    this.reason,
    this.errorMessage,
  });

  final String taskId;
  final TaskType taskType;
  final TaskPriority priority;
  final DateTime startTime;
  final DateTime endTime;
  final Duration? executionTime;
  final TaskExecutionResult result;
  final String? reason;
  final String? errorMessage;

  Duration get totalDuration => endTime.difference(startTime);
}

/// Background task event
class BackgroundTaskEvent {
  const BackgroundTaskEvent({
    required this.type,
    required this.taskId,
    required this.description,
    required this.timestamp,
  });

  final TaskEventType type;
  final String taskId;
  final String description;
  final DateTime timestamp;

  @override
  String toString() =>
      'BackgroundTaskEvent(${type.name}: $taskId - $description)';
}

/// Task event types
enum TaskEventType {
  registered,
  started,
  completed,
  failed,
  cancelled,
  timeout;

  String get displayName {
    switch (this) {
      case TaskEventType.registered:
        return 'Registered';
      case TaskEventType.started:
        return 'Started';
      case TaskEventType.completed:
        return 'Completed';
      case TaskEventType.failed:
        return 'Failed';
      case TaskEventType.cancelled:
        return 'Cancelled';
      case TaskEventType.timeout:
        return 'Timeout';
    }
  }
}

/// Task performance metrics
class TaskPerformanceMetrics {
  const TaskPerformanceMetrics({
    required this.activeTasks,
    required this.totalExecutions,
    required this.successfulExecutions,
    required this.failedExecutions,
    required this.successRate,
    required this.averageExecutionTime,
    required this.resourceUsage,
    required this.timestamp,
  });

  final int activeTasks;
  final int totalExecutions;
  final int successfulExecutions;
  final int failedExecutions;
  final double successRate;
  final Duration averageExecutionTime;
  final Map<String, ResourceUsage> resourceUsage;
  final DateTime timestamp;
}

/// Resource usage information
class ResourceUsage {
  const ResourceUsage({
    required this.taskId,
    required this.cpuUsage,
    required this.memoryUsage,
    required this.batteryUsage,
    required this.timestamp,
  });

  final String taskId;
  final double cpuUsage; // Percentage
  final int memoryUsage; // Bytes
  final double batteryUsage; // Percentage
  final DateTime timestamp;
}
