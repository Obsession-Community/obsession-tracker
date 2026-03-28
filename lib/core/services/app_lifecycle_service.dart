import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:obsession_tracker/core/services/biometric_lock_service.dart';
import 'package:obsession_tracker/core/services/push_notification_service.dart';

/// Service to handle app lifecycle changes for background location tracking
/// and biometric lock management.
class AppLifecycleService {
  factory AppLifecycleService() => _instance ??= AppLifecycleService._();
  AppLifecycleService._();
  static AppLifecycleService? _instance;

  // Biometric lock service for app security
  final BiometricLockService _lockService = BiometricLockService();

  AppLifecycleState _currentState = AppLifecycleState.resumed;
  final StreamController<AppLifecycleState> _stateController =
      StreamController<AppLifecycleState>.broadcast();

  /// Current app lifecycle state
  AppLifecycleState get currentState => _currentState;

  /// Stream of app lifecycle state changes
  Stream<AppLifecycleState> get stateChanges => _stateController.stream;

  /// Check if app is currently in background
  bool get isInBackground =>
      _currentState == AppLifecycleState.paused ||
      _currentState == AppLifecycleState.detached;

  /// Check if app is currently in foreground
  bool get isInForeground => _currentState == AppLifecycleState.resumed;

  /// Initialize the lifecycle service
  void initialize() {
    // Listen to app lifecycle changes
    SystemChannels.lifecycle.setMessageHandler(_handleLifecycleMessage);
    debugPrint('AppLifecycleService initialized');
  }

  /// Handle lifecycle state changes from the system
  Future<String?> _handleLifecycleMessage(String? message) async {
    if (message == null) {
      return null;
    }

    final AppLifecycleState? newState = _parseLifecycleState(message);
    if (newState != null && newState != _currentState) {
      final AppLifecycleState previousState = _currentState;
      _currentState = newState;

      debugPrint('App lifecycle changed: $previousState -> $newState');

      // Notify listeners
      _stateController.add(newState);

      // Handle specific transitions
      _handleStateTransition(previousState, newState);
    }

    return null;
  }

  /// Parse lifecycle state from system message
  AppLifecycleState? _parseLifecycleState(String message) {
    switch (message) {
      case 'AppLifecycleState.resumed':
        return AppLifecycleState.resumed;
      case 'AppLifecycleState.inactive':
        return AppLifecycleState.inactive;
      case 'AppLifecycleState.paused':
        return AppLifecycleState.paused;
      case 'AppLifecycleState.detached':
        return AppLifecycleState.detached;
      case 'AppLifecycleState.hidden':
        return AppLifecycleState.hidden;
      default:
        debugPrint('Unknown lifecycle state: $message');
        return null;
    }
  }

  /// Handle specific state transitions
  void _handleStateTransition(AppLifecycleState from, AppLifecycleState to) {
    // App going to background - only trigger lock on 'paused' (true background)
    // 'inactive' happens during Face ID, notifications, control center - don't lock for those
    if (to == AppLifecycleState.paused) {
      debugPrint('App entering background (paused) - location tracking should continue');
      // Handle biometric lock - only for true background
      debugPrint('🔒 Calling onAppPaused from AppLifecycleService...');
      _lockService.onAppPaused();
    } else if (to == AppLifecycleState.inactive) {
      debugPrint('App inactive (Face ID, notifications, etc.) - NOT triggering lock');
    }

    // App coming to foreground
    if (to == AppLifecycleState.resumed) {
      debugPrint('App entering foreground - checking location tracking status');
      // Handle biometric lock - this is async but we don't need to wait
      debugPrint('🔒 Calling onAppResumed from AppLifecycleService...');
      _lockService.onAppResumed();
      // Check if push notification permission changed while app was in background
      PushNotificationService.instance.checkPermissionStatus();
    }

    // App being terminated
    if (to == AppLifecycleState.detached) {
      debugPrint('App being terminated - cleaning up location tracking');
      _lockService.onAppDetached();
    }

    // App hidden (iOS app switcher) - treat as true background
    if (to == AppLifecycleState.hidden) {
      debugPrint('🔒 App hidden - calling onAppPaused...');
      _lockService.onAppPaused();
    }
  }

  /// Add a listener for lifecycle state changes
  StreamSubscription<AppLifecycleState> addListener(
    void Function(AppLifecycleState state) onStateChanged,
  ) =>
      _stateController.stream.listen(onStateChanged);

  /// Dispose of the service
  void dispose() {
    _stateController.close();
    _instance = null;
  }
}
