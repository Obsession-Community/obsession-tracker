import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:obsession_tracker/core/models/bff_app_config.dart';
import 'package:obsession_tracker/core/services/bff_config_service.dart';
import 'package:obsession_tracker/core/services/bff_mapping_service.dart';

/// Provides current maintenance state for UI to react to
final maintenanceStateProvider =
    NotifierProvider<MaintenanceStateNotifier, MaintenanceState>(
        MaintenanceStateNotifier.new);

/// State representing BFF maintenance mode status
class MaintenanceState {
  const MaintenanceState({
    this.isInMaintenance = false,
    this.message,
    this.estimatedEnd,
    this.nextRetryTime,
    this.retryCount = 0,
    this.lastManualRetryTime,
  });

  /// Whether the BFF is currently in maintenance mode
  final bool isInMaintenance;

  /// User-friendly maintenance message from server
  final String? message;

  /// Estimated time when maintenance will end (from server)
  final DateTime? estimatedEnd;

  /// When the next automatic retry should occur
  final DateTime? nextRetryTime;

  /// Number of failed retry attempts (for exponential backoff)
  final int retryCount;

  /// Time of last manual retry (for throttling)
  final DateTime? lastManualRetryTime;

  /// Minimum time between manual retries (30 seconds)
  static const Duration minManualRetryInterval = Duration(seconds: 30);

  /// Base retry delays for exponential backoff
  static const List<Duration> backoffDelays = [
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(seconds: 120),
    Duration(seconds: 300), // 5 minute max
  ];

  /// Maximum jitter to add to retry times (prevents thundering herd)
  static const Duration maxJitter = Duration(seconds: 60);

  /// Check if manual retry is allowed (throttled to prevent spamming)
  bool get canManualRetry {
    if (!isInMaintenance) return false;
    if (lastManualRetryTime == null) return true;
    return DateTime.now().difference(lastManualRetryTime!) >= minManualRetryInterval;
  }

  /// Get time remaining until manual retry is allowed
  Duration? get timeUntilManualRetryAllowed {
    if (!isInMaintenance || lastManualRetryTime == null) return null;
    final elapsed = DateTime.now().difference(lastManualRetryTime!);
    if (elapsed >= minManualRetryInterval) return null;
    return minManualRetryInterval - elapsed;
  }

  /// Get human-readable time until estimated end
  String? get estimatedEndDisplay {
    if (estimatedEnd == null) return null;
    final remaining = estimatedEnd!.difference(DateTime.now());
    if (remaining.isNegative) return 'Soon';
    if (remaining.inHours > 0) {
      return '~${remaining.inHours}h ${remaining.inMinutes % 60}m';
    } else if (remaining.inMinutes > 0) {
      return '~${remaining.inMinutes}m';
    } else {
      return 'Soon';
    }
  }

  MaintenanceState copyWith({
    bool? isInMaintenance,
    String? message,
    DateTime? estimatedEnd,
    DateTime? nextRetryTime,
    int? retryCount,
    DateTime? lastManualRetryTime,
    bool clearEstimatedEnd = false,
    bool clearMessage = false,
  }) {
    return MaintenanceState(
      isInMaintenance: isInMaintenance ?? this.isInMaintenance,
      message: clearMessage ? null : (message ?? this.message),
      estimatedEnd: clearEstimatedEnd ? null : (estimatedEnd ?? this.estimatedEnd),
      nextRetryTime: nextRetryTime ?? this.nextRetryTime,
      retryCount: retryCount ?? this.retryCount,
      lastManualRetryTime: lastManualRetryTime ?? this.lastManualRetryTime,
    );
  }
}

/// Notifier that manages maintenance state and retry logic
class MaintenanceStateNotifier extends Notifier<MaintenanceState> {
  Timer? _retryTimer;
  StreamSubscription<MaintenanceModeEvent>? _maintenanceSubscription;
  final Random _random = Random();

  @override
  MaintenanceState build() {
    // Subscribe to maintenance mode events from BFFMappingService
    _maintenanceSubscription = BFFMappingService.maintenanceStream.listen(
      _handleMaintenanceEvent,
    );

    // Clean up when provider is disposed
    ref.onDispose(() {
      _retryTimer?.cancel();
      _maintenanceSubscription?.cancel();
    });
    return const MaintenanceState();
  }

  /// Handle maintenance mode events from the BFF service
  void _handleMaintenanceEvent(MaintenanceModeEvent event) {
    debugPrint('🔧 Received maintenance event: ${event.code}');
    _enterMaintenanceMode(
      message: event.message ?? 'Service is under maintenance. Please try again later.',
      estimatedEnd: event.estimatedEnd,
    );
  }

  /// Enter maintenance mode and schedule retry
  void _enterMaintenanceMode({
    String? message,
    DateTime? estimatedEnd,
  }) {
    debugPrint('🔧 BFF entered maintenance mode');
    debugPrint('   Message: $message');
    debugPrint('   Estimated end: $estimatedEnd');

    final nextRetry = _calculateNextRetryTime(estimatedEnd);
    debugPrint('   Next retry at: $nextRetry');

    state = state.copyWith(
      isInMaintenance: true,
      message: message ?? 'Service is under maintenance. Please try again later.',
      estimatedEnd: estimatedEnd,
      nextRetryTime: nextRetry,
      retryCount: state.retryCount + 1,
    );

    // Schedule automatic retry
    _scheduleRetry(nextRetry);
  }

  /// Calculate next retry time using smart logic:
  /// 1. If estimatedEnd is available, use it + jitter
  /// 2. Otherwise, use exponential backoff + jitter
  DateTime _calculateNextRetryTime(DateTime? estimatedEnd) {
    final jitter = Duration(seconds: _random.nextInt(MaintenanceState.maxJitter.inSeconds));

    if (estimatedEnd != null) {
      // Use estimated end time + jitter
      final now = DateTime.now();
      if (estimatedEnd.isAfter(now)) {
        return estimatedEnd.add(jitter);
      }
      // If estimated end is in the past, retry soon with jitter
      return now.add(const Duration(seconds: 30)).add(jitter);
    }

    // Exponential backoff
    final backoffIndex = state.retryCount.clamp(0, MaintenanceState.backoffDelays.length - 1);
    final backoffDelay = MaintenanceState.backoffDelays[backoffIndex];
    return DateTime.now().add(backoffDelay).add(jitter);
  }

  /// Schedule automatic retry at the specified time
  void _scheduleRetry(DateTime retryTime) {
    _retryTimer?.cancel();

    final delay = retryTime.difference(DateTime.now());
    if (delay.isNegative) {
      // Retry immediately if time has passed
      _checkMaintenanceStatus();
      return;
    }

    debugPrint('⏰ Scheduling maintenance check in ${delay.inSeconds}s');
    _retryTimer = Timer(delay, _checkMaintenanceStatus);
  }

  /// Check if maintenance mode is still active by fetching config
  ///
  /// Uses direct HTTP to get fresh config (bypassing cached defaults).
  /// Only exits maintenance when we have positive confirmation it's over.
  Future<void> _checkMaintenanceStatus() async {
    debugPrint('🔄 Checking if maintenance mode is still active...');

    try {
      // Make a direct HTTP request to ensure we get fresh data
      // Don't rely on fallback/defaults - we need positive confirmation
      final config = await _fetchFreshConfig();

      if (config == null) {
        // Couldn't reach server - stay in maintenance, try again later
        debugPrint('⚠️ Could not reach config endpoint, staying in maintenance');
        final nextRetry = _calculateNextRetryTime(null);
        state = state.copyWith(
          nextRetryTime: nextRetry,
          retryCount: state.retryCount + 1,
        );
        _scheduleRetry(nextRetry);
        return;
      }

      if (config.maintenance.active) {
        // Still in maintenance - schedule next retry
        debugPrint('🔧 Still in maintenance mode');
        final nextRetry = _calculateNextRetryTime(config.maintenance.estimatedEnd);
        state = state.copyWith(
          message: config.maintenance.message,
          estimatedEnd: config.maintenance.estimatedEnd,
          nextRetryTime: nextRetry,
          retryCount: state.retryCount + 1,
        );
        _scheduleRetry(nextRetry);
      } else {
        // Maintenance is confirmed over!
        debugPrint('✅ Config confirms maintenance is over');
        _exitMaintenanceMode();
      }
    } catch (e) {
      debugPrint('⚠️ Failed to check maintenance status: $e');
      // On error, stay in maintenance and schedule another retry with backoff
      final nextRetry = _calculateNextRetryTime(null);
      state = state.copyWith(
        nextRetryTime: nextRetry,
        retryCount: state.retryCount + 1,
      );
      _scheduleRetry(nextRetry);
    }
  }

  /// Fetch config directly from BFF, returning null if unreachable
  ///
  /// Unlike BFFConfigService.fetchConfig(), this does NOT fall back to
  /// defaults or cached values - we need positive confirmation.
  Future<BFFAppConfig?> _fetchFreshConfig() async {
    try {
      final endpoint = BFFConfigService.getConfigEndpoint();

      debugPrint('🌐 Fetching fresh config from $endpoint');

      final response = await http.get(
        Uri.parse(endpoint),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Fresh config received');
        return BFFAppConfig.fromJson(json);
      } else {
        debugPrint('❌ Config endpoint returned ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch fresh config: $e');
      return null;
    }
  }

  /// Exit maintenance mode
  void _exitMaintenanceMode() {
    debugPrint('✅ BFF maintenance mode ended');
    _retryTimer?.cancel();
    state = const MaintenanceState(
      
    );
  }

  /// Manually trigger a retry check (throttled)
  ///
  /// Returns false if retry is throttled
  Future<bool> manualRetry() async {
    if (!state.canManualRetry) {
      debugPrint('🚫 Manual retry throttled - wait ${state.timeUntilManualRetryAllowed?.inSeconds}s');
      return false;
    }

    state = state.copyWith(lastManualRetryTime: DateTime.now());
    await _checkMaintenanceStatus();
    return true;
  }

  /// Force clear maintenance state (for testing/debugging)
  void clearMaintenanceState() {
    _retryTimer?.cancel();
    state = const MaintenanceState();
  }
}
