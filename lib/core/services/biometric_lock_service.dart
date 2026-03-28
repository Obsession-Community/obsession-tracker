import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Exception thrown when biometric authentication fails
class BiometricAuthException implements Exception {
  final String message;
  BiometricAuthException(this.message);

  @override
  String toString() => message;
}

/// Status of the biometric lock
enum BiometricLockStatus {
  /// Lock is disabled by user
  disabled,

  /// Lock is enabled and currently locked
  locked,

  /// Lock is enabled and currently unlocked
  unlocked,
}

/// Timeout duration for auto-lock
enum LockTimeout {
  /// Immediate lock when app goes to background
  immediate(0),

  /// Lock after 1 minute
  oneMinute(1),

  /// Lock after 5 minutes
  fiveMinutes(5),

  /// Lock after 15 minutes
  fifteenMinutes(15),

  /// Never auto-lock
  never(-1);

  const LockTimeout(this.minutes);
  final int minutes;
}

/// Service for managing biometric authentication (Face ID/Touch ID) app lock.
///
/// Provides app-level security by requiring biometric authentication:
/// - Face ID on supported iOS devices
/// - Touch ID on supported iOS devices
/// - Fingerprint on Android devices
/// - Passcode/Pattern fallback on both platforms
///
/// Features:
/// - Auto-lock when app goes to background
/// - Configurable timeout before lock
/// - Persistent settings in secure storage
/// - Support for enabling/disabling lock
///
/// This is a singleton to ensure consistent state across the app.
class BiometricLockService {
  // Singleton instance
  static final BiometricLockService _instance = BiometricLockService._internal();

  factory BiometricLockService() => _instance;

  BiometricLockService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Storage keys
  static const String _lockEnabledKey = 'biometric_lock_enabled';
  static const String _lockTimeoutKey = 'biometric_lock_timeout_minutes';
  static const String _lastUnlockTimeKey = 'last_unlock_time';

  // Current state
  BiometricLockStatus _status = BiometricLockStatus.locked;
  DateTime? _lastUnlockTime;
  LockTimeout _timeout = LockTimeout.immediate;
  bool _isAuthenticating = false; // Track if authentication is in progress
  bool _wasBackgrounded = false; // Track if app was actually in background (paused)

  /// Get current lock status
  BiometricLockStatus get status => _status;

  /// Check if authentication is currently in progress
  bool get isAuthenticating => _isAuthenticating;

  /// Check if biometric lock is enabled
  Future<bool> isEnabled() async {
    final String? enabled = await _secureStorage.read(key: _lockEnabledKey);
    return enabled == 'true';
  }

  /// Enable biometric lock
  ///
  /// Returns true if successfully enabled, false if biometrics not available.
  /// After enabling, the status is set to unlocked since the user just authenticated.
  Future<bool> enable() async {
    // Check if device has biometrics enrolled
    final bool hasBiometrics = await hasEnrolledBiometrics();
    if (!hasBiometrics) {
      debugPrint('⚠️ Cannot enable biometric lock - no enrolled biometrics');
      return false;
    }

    await _secureStorage.write(key: _lockEnabledKey, value: 'true');
    // Set to unlocked since user just authenticated to enable
    _status = BiometricLockStatus.unlocked;
    _lastUnlockTime = DateTime.now();
    await _secureStorage.write(
      key: _lastUnlockTimeKey,
      value: _lastUnlockTime!.toIso8601String(),
    );
    debugPrint('✅ Biometric lock enabled, status: unlocked');
    return true;
  }

  /// Disable biometric lock
  Future<void> disable() async {
    await _secureStorage.write(key: _lockEnabledKey, value: 'false');
    _status = BiometricLockStatus.disabled;
  }

  /// Get configured lock timeout
  Future<LockTimeout> getTimeout() async {
    final String? minutes = await _secureStorage.read(key: _lockTimeoutKey);
    if (minutes == null) return LockTimeout.immediate;

    final int? value = int.tryParse(minutes);
    return LockTimeout.values.firstWhere(
      (t) => t.minutes == value,
      orElse: () => LockTimeout.immediate,
    );
  }

  /// Set lock timeout duration
  Future<void> setTimeout(LockTimeout timeout) async {
    await _secureStorage.write(
      key: _lockTimeoutKey,
      value: timeout.minutes.toString(),
    );
    _timeout = timeout;
  }

  /// Initialize service (load settings from storage)
  Future<void> initialize() async {
    // Check if biometric lock setting exists
    final String? enabledValue = await _secureStorage.read(key: _lockEnabledKey);

    // First time setup - disable by default (opt-in security)
    if (enabledValue == null) {
      // Disabled by default - user must explicitly enable in settings
      await _secureStorage.write(key: _lockEnabledKey, value: 'false');
      _status = BiometricLockStatus.disabled;
      debugPrint('ℹ️ Biometric lock disabled by default (first launch)');
      return;
    }

    final bool enabled = await isEnabled();
    if (!enabled) {
      _status = BiometricLockStatus.disabled;
      return;
    }

    // Load timeout setting
    _timeout = await getTimeout();

    // Check if we should be locked based on last unlock time
    final String? lastUnlockStr =
        await _secureStorage.read(key: _lastUnlockTimeKey);
    if (lastUnlockStr != null) {
      _lastUnlockTime = DateTime.tryParse(lastUnlockStr);
      if (_lastUnlockTime != null && shouldLockDueToTimeout()) {
        _status = BiometricLockStatus.locked;
      } else {
        _status = BiometricLockStatus.unlocked;
      }
    } else {
      _status = BiometricLockStatus.locked;
    }
  }

  /// Check if device supports biometric authentication
  Future<bool> isBiometricAvailable() async {
    try {
      final result = await _localAuth.canCheckBiometrics;
      debugPrint('📱 canCheckBiometrics: $result');
      return result;
    } catch (e) {
      debugPrint('⚠️ canCheckBiometrics error: $e');
      return false;
    }
  }

  /// Check if device has biometrics enrolled
  Future<bool> isDeviceSupported() async {
    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      debugPrint('📱 isDeviceSupported check: canCheck=$canCheck, isDeviceSupported=$isDeviceSupported');
      return canCheck && isDeviceSupported;
    } catch (e) {
      debugPrint('⚠️ isDeviceSupported error: $e');
      return false;
    }
  }

  /// Check if user has enrolled biometrics (Face ID, Touch ID, fingerprints)
  ///
  /// This checks if the device not only supports biometrics, but also has
  /// at least one biometric method actually enrolled by the user.
  Future<bool> hasEnrolledBiometrics() async {
    try {
      final bool deviceSupported = await isDeviceSupported();
      if (!deviceSupported) return false;

      // Check if there are any enrolled biometrics
      final List<BiometricType> availableBiometrics =
          await getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      debugPrint('⚠️ Error checking enrolled biometrics: $e');
      return false;
    }
  }

  /// Get available biometric types (Face ID, Touch ID, Fingerprint)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Get user-friendly name of available biometric method
  Future<String> getBiometricName() async {
    final biometrics = await getAvailableBiometrics();

    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Touch ID / Fingerprint';
    } else if (biometrics.contains(BiometricType.iris)) {
      return 'Iris Scanner';
    } else if (biometrics.contains(BiometricType.strong)) {
      return 'Biometric Authentication';
    } else {
      return 'Device Passcode';
    }
  }

  /// Authenticate user with biometrics
  ///
  /// Returns true if authentication successful, false otherwise.
  /// Throws a [BiometricAuthException] with user-friendly message on failure.
  ///
  /// Set [forcePrompt] to true to always show the biometric prompt, even if
  /// the lock is not enabled. This is used when testing authentication before
  /// enabling the lock.
  Future<bool> authenticate({
    String reason = 'Please authenticate to access your treasure hunting data',
    bool forcePrompt = false,
  }) async {
    try {
      debugPrint('🔐 Starting biometric authentication (forcePrompt: $forcePrompt)...');

      // Check if lock is enabled (skip if forcePrompt is true)
      if (!forcePrompt) {
        final bool enabled = await isEnabled();
        if (!enabled) {
          debugPrint('ℹ️ Biometric lock not enabled');
          _status = BiometricLockStatus.disabled;
          return true; // Not locked, allow access
        }

        // Check if already unlocked
        if (_status == BiometricLockStatus.unlocked) {
          debugPrint('ℹ️ Already unlocked');
          return true;
        }
      }

      // Verify device supports biometrics
      final bool deviceSupported = await isDeviceSupported();
      debugPrint('📱 Device biometric support: $deviceSupported');

      if (!deviceSupported) {
        debugPrint('⚠️ Device does not support biometrics');
        throw BiometricAuthException('Device does not support biometric authentication');
      }

      // Verify biometrics are enrolled
      final bool hasBiometrics = await hasEnrolledBiometrics();
      debugPrint('👆 Enrolled biometrics: $hasBiometrics');

      if (!hasBiometrics) {
        debugPrint('⚠️ No biometrics enrolled, disabling lock');
        await disable();
        throw BiometricAuthException('No fingerprints or face data enrolled on this device. Please set up biometrics in your device settings.');
      }

      // Get available biometric types for debugging
      final biometrics = await getAvailableBiometrics();
      debugPrint('🔍 Available biometrics: $biometrics');

      // Perform biometric authentication
      debugPrint('🔐 Calling local_auth.authenticate()...');
      _isAuthenticating = true; // Prevent onAppPaused from locking during Face ID
      try {
        final bool authenticated = await _localAuth.authenticate(
          localizedReason: reason,
          // On macOS, biometricOnly causes immediate dismissal when system
          // shows password fallback. Allow device credential fallback on macOS.
          biometricOnly: !Platform.isMacOS,
          sensitiveTransaction: false, // Skip confirmation dialog - scan immediately
          persistAcrossBackgrounding: true, // Don't cancel if app goes to background
        );

        debugPrint('🔐 Authentication result: $authenticated');

        if (authenticated) {
          _status = BiometricLockStatus.unlocked;
          _lastUnlockTime = DateTime.now();
          await _secureStorage.write(
            key: _lastUnlockTimeKey,
            value: _lastUnlockTime!.toIso8601String(),
          );
          debugPrint('✅ Authentication successful');
          return true;
        }

        debugPrint('❌ Authentication returned false (user may have cancelled or failed)');
        return false;
      } finally {
        _isAuthenticating = false;
      }
    } on LocalAuthException catch (e) {
      debugPrint('⚠️ Biometric authentication exception: ${e.code} - ${e.description}');

      // Handle specific LocalAuth exceptions
      switch (e.code) {
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noCredentialsSet:
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          // Biometrics not available or locked out, disable lock for safety
          debugPrint('⚠️ Biometric lock disabled due to: ${e.code}');
          await disable();
          throw BiometricAuthException(_getErrorMessage(e.code.name));

        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.userRequestedFallback:
          debugPrint('ℹ️ Authentication cancelled by user');
          return false;

        default:
          // Any other exception
          throw BiometricAuthException('Biometric authentication error: ${e.description ?? e.code.name}');
      }
    } catch (e) {
      if (e is BiometricAuthException) {
        rethrow;
      }
      debugPrint('⚠️ Unexpected biometric authentication error: $e');
      throw BiometricAuthException('Unexpected error during authentication');
    }
  }

  /// Get user-friendly error message for LocalAuthExceptionCode
  String _getErrorMessage(String code) {
    switch (code) {
      case 'noBiometricHardware':
      case 'biometricHardwareTemporarilyUnavailable':
        return 'Biometric authentication is not available on this device';
      case 'noBiometricsEnrolled':
        return 'No fingerprints or face data enrolled. Please set up biometrics in your device settings';
      case 'noCredentialsSet':
        return 'Device passcode not set. Please set up a screen lock in your device settings';
      case 'biometricLockout':
        return 'Biometric authentication permanently locked due to too many failed attempts';
      case 'temporaryLockout':
        return 'Biometric authentication temporarily locked. Please try again later';
      default:
        return 'Biometric authentication unavailable';
    }
  }

  /// Lock the app (require authentication on next access)
  void lock() {
    debugPrint('🔒 lock(): _status before=$_status');
    if (_status != BiometricLockStatus.disabled) {
      _status = BiometricLockStatus.locked;
      debugPrint('🔒 lock(): _status after=$_status');
    } else {
      debugPrint('🔒 lock(): NOT locking because _status is disabled');
    }
  }

  /// Check if app should be locked due to timeout
  bool shouldLockDueToTimeout() {
    debugPrint('🔒 shouldLockDueToTimeout: _status=$_status, _timeout=$_timeout, _lastUnlockTime=$_lastUnlockTime');

    // If disabled or never timeout, don't lock
    if (_status == BiometricLockStatus.disabled || _timeout == LockTimeout.never) {
      debugPrint('🔒 shouldLockDueToTimeout: returning false (disabled or never)');
      return false;
    }

    // If no last unlock time, should be locked
    if (_lastUnlockTime == null) {
      debugPrint('🔒 shouldLockDueToTimeout: returning true (no lastUnlockTime)');
      return true;
    }

    // If immediate timeout, should be locked
    if (_timeout == LockTimeout.immediate) {
      debugPrint('🔒 shouldLockDueToTimeout: returning true (immediate timeout)');
      return true;
    }

    // Check if timeout has elapsed
    final int elapsedMinutes =
        DateTime.now().difference(_lastUnlockTime!).inMinutes;
    final result = elapsedMinutes >= _timeout.minutes;
    debugPrint('🔒 shouldLockDueToTimeout: elapsed=$elapsedMinutes min, timeout=${_timeout.minutes} min, returning $result');
    return result;
  }

  /// Handle app going to background (called only for paused state, not inactive)
  Future<void> onAppPaused() async {
    debugPrint('🔒 onAppPaused: checking isEnabled... (isAuthenticating=$_isAuthenticating)');

    // Skip if authentication is in progress (Face ID causes app to go inactive)
    if (_isAuthenticating) {
      debugPrint('🔒 onAppPaused: skipping - authentication in progress');
      return;
    }

    final bool enabled = await isEnabled();
    debugPrint('🔒 onAppPaused: enabled=$enabled, _timeout=$_timeout, _status=$_status');
    if (!enabled) {
      debugPrint('🔒 onAppPaused: lock not enabled, returning');
      return;
    }

    // Mark that app was truly backgrounded
    _wasBackgrounded = true;
    debugPrint('🔒 onAppPaused: _wasBackgrounded set to true');

    // For immediate timeout, lock immediately
    if (_timeout == LockTimeout.immediate) {
      debugPrint('🔒 onAppPaused: immediate timeout - calling lock()');
      lock();
      debugPrint('🔒 onAppPaused: after lock(), _status=$_status');
    }
    // For other timeouts, the check happens on resume
  }

  /// Handle app returning to foreground
  Future<void> onAppResumed() async {
    debugPrint('🔒 onAppResumed: checking... (isAuthenticating=$_isAuthenticating, wasBackgrounded=$_wasBackgrounded)');

    // Skip if authentication is in progress (Face ID causes lifecycle changes)
    if (_isAuthenticating) {
      debugPrint('🔒 onAppResumed: skipping - authentication in progress');
      return;
    }

    // Skip if app wasn't actually backgrounded (just inactive from Face ID, etc.)
    if (!_wasBackgrounded) {
      debugPrint('🔒 onAppResumed: skipping - app was not actually backgrounded');
      return;
    }

    // Reset the flag
    _wasBackgrounded = false;

    final bool enabled = await isEnabled();
    debugPrint('🔒 onAppResumed: enabled=$enabled, _status=$_status, _timeout=$_timeout');
    if (!enabled) {
      debugPrint('🔒 onAppResumed: lock not enabled, returning');
      return;
    }

    // Check if timeout has elapsed
    final shouldLock = shouldLockDueToTimeout();
    debugPrint('🔒 onAppResumed: shouldLockDueToTimeout=$shouldLock');
    if (shouldLock) {
      debugPrint('🔒 onAppResumed: calling lock()');
      lock();
      debugPrint('🔒 onAppResumed: after lock(), _status=$_status');
    }
  }

  /// Handle app being closed/terminated
  Future<void> onAppDetached() async {
    // Always lock when app is closed
    lock();
  }

  /// Get timeout options for settings UI
  static List<LockTimeout> get timeoutOptions => LockTimeout.values;

  /// Get user-friendly label for timeout
  static String getTimeoutLabel(LockTimeout timeout) {
    switch (timeout) {
      case LockTimeout.immediate:
        return 'Immediate';
      case LockTimeout.oneMinute:
        return '1 Minute';
      case LockTimeout.fiveMinutes:
        return '5 Minutes';
      case LockTimeout.fifteenMinutes:
        return '15 Minutes';
      case LockTimeout.never:
        return 'Never';
    }
  }

  /// Reset all biometric lock settings (for testing/debugging)
  Future<void> reset() async {
    await _secureStorage.delete(key: _lockEnabledKey);
    await _secureStorage.delete(key: _lockTimeoutKey);
    await _secureStorage.delete(key: _lastUnlockTimeKey);
    _status = BiometricLockStatus.disabled;
    _lastUnlockTime = null;
    _timeout = LockTimeout.immediate;
  }
}
