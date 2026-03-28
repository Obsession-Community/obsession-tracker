import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:obsession_tracker/core/models/security_models.dart';
import 'package:obsession_tracker/core/services/secure_key_management_service.dart';

/// Authentication service for handling biometric and PIN authentication
class AuthenticationService {
  factory AuthenticationService() => _instance ??= AuthenticationService._();
  AuthenticationService._();
  static AuthenticationService? _instance;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final SecureKeyManagementService _keyService = SecureKeyManagementService();

  // Authentication state
  bool _isAuthenticated = false;
  DateTime? _lastAuthTime;
  Timer? _autoLockTimer;
  int _failedAttempts = 0;
  DateTime? _lockoutEndTime;

  // Stream controllers for authentication events
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();
  final StreamController<int> _failedAttemptsController =
      StreamController<int>.broadcast();
  final StreamController<Duration?> _lockoutController =
      StreamController<Duration?>.broadcast();

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  DateTime? get lastAuthTime => _lastAuthTime;
  int get failedAttempts => _failedAttempts;
  bool get isLockedOut =>
      _lockoutEndTime != null && DateTime.now().isBefore(_lockoutEndTime!);
  Duration? get lockoutTimeRemaining {
    if (_lockoutEndTime == null) return null;
    final remaining = _lockoutEndTime!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  // Streams
  Stream<bool> get authStateStream => _authStateController.stream;
  Stream<int> get failedAttemptsStream => _failedAttemptsController.stream;
  Stream<Duration?> get lockoutStream => _lockoutController.stream;

  /// Initialize the authentication service
  Future<void> initialize() async {
    try {
      await _keyService.initialize();
      debugPrint('Authentication service initialized');
    } catch (e) {
      debugPrint('Error initializing authentication service: $e');
      rethrow;
    }
  }

  /// Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Set up PIN authentication
  Future<bool> setupPin(String pin) async {
    try {
      if (pin.length < 4) {
        throw ArgumentError('PIN must be at least 4 digits');
      }

      await _keyService.setPinHash(pin);
      debugPrint('PIN authentication set up');
      return true;
    } catch (e) {
      debugPrint('Error setting up PIN: $e');
      return false;
    }
  }

  /// Change PIN
  Future<bool> changePin(String oldPin, String newPin) async {
    try {
      // Verify old PIN first
      if (!await _keyService.verifyPin(oldPin)) {
        return false;
      }

      if (newPin.length < 4) {
        throw ArgumentError('New PIN must be at least 4 digits');
      }

      await _keyService.setPinHash(newPin);
      debugPrint('PIN changed successfully');
      return true;
    } catch (e) {
      debugPrint('Error changing PIN: $e');
      return false;
    }
  }

  /// Remove PIN authentication
  Future<bool> removePin() async {
    try {
      await _keyService.removePin();
      debugPrint('PIN authentication removed');
      return true;
    } catch (e) {
      debugPrint('Error removing PIN: $e');
      return false;
    }
  }

  /// Check if PIN is set up
  Future<bool> isPinSetup() async {
    try {
      return await _keyService.isPinSet();
    } catch (e) {
      debugPrint('Error checking PIN setup: $e');
      return false;
    }
  }

  /// Authenticate with PIN
  Future<AuthResult> authenticateWithPin(String pin) async {
    try {
      if (isLockedOut) {
        return AuthResult.lockedOut;
      }

      final isValid = await _keyService.verifyPin(pin);

      if (isValid) {
        await _onAuthenticationSuccess();
        return AuthResult.success;
      } else {
        await _onAuthenticationFailure();
        return AuthResult.failed;
      }
    } catch (e) {
      debugPrint('Error authenticating with PIN: $e');
      return AuthResult.error;
    }
  }

  /// Authenticate with biometrics
  Future<AuthResult> authenticateWithBiometrics({
    String localizedReason = 'Please authenticate to access the app',
    bool persistAcrossBackgrounding = false,
  }) async {
    try {
      if (isLockedOut) {
        return AuthResult.lockedOut;
      }

      if (!await isBiometricAvailable()) {
        return AuthResult.notAvailable;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: persistAcrossBackgrounding,
      );

      if (didAuthenticate) {
        await _onAuthenticationSuccess();
        return AuthResult.success;
      } else {
        return AuthResult.cancelled;
      }
    } on LocalAuthException catch (e) {
      debugPrint('Biometric authentication error: $e');
      switch (e.code) {
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
          return AuthResult.notAvailable;
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noCredentialsSet:
          return AuthResult.notEnrolled;
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          return AuthResult.biometricLockedOut;
        case LocalAuthExceptionCode.userCanceled:
          return AuthResult.cancelled;
        default:
          return AuthResult.error;
      }
    } catch (e) {
      debugPrint('Error authenticating with biometrics: $e');
      return AuthResult.error;
    }
  }

  /// Authenticate based on configured method
  Future<AuthResult> authenticate(
    AuthMethod method, {
    String? pin,
    String localizedReason = 'Please authenticate to access the app',
  }) async {
    switch (method) {
      case AuthMethod.none:
        await _onAuthenticationSuccess();
        return AuthResult.success;

      case AuthMethod.pin:
        if (pin == null) return AuthResult.failed;
        return authenticateWithPin(pin);

      case AuthMethod.biometric:
        return authenticateWithBiometrics(localizedReason: localizedReason);

      case AuthMethod.pinAndBiometric:
        // Try biometric first, fallback to PIN
        final biometricResult = await authenticateWithBiometrics(
          localizedReason: localizedReason,
        );

        if (biometricResult == AuthResult.success) {
          return biometricResult;
        }

        // Fallback to PIN if provided
        if (pin != null) {
          return authenticateWithPin(pin);
        }

        return biometricResult;
    }
  }

  /// Handle successful authentication
  Future<void> _onAuthenticationSuccess() async {
    _isAuthenticated = true;
    _lastAuthTime = DateTime.now();
    _failedAttempts = 0;
    _lockoutEndTime = null;

    _authStateController.add(true);
    _failedAttemptsController.add(0);
    _lockoutController.add(null);

    debugPrint('Authentication successful');
  }

  /// Handle failed authentication
  Future<void> _onAuthenticationFailure() async {
    _failedAttempts++;
    _failedAttemptsController.add(_failedAttempts);

    debugPrint('Authentication failed. Attempts: $_failedAttempts');
  }

  /// Set lockout after too many failed attempts
  void setLockout(Duration lockoutDuration, int maxAttempts) {
    if (_failedAttempts >= maxAttempts) {
      _lockoutEndTime = DateTime.now().add(lockoutDuration);
      _lockoutController.add(lockoutDuration);
      debugPrint('Account locked out for ${lockoutDuration.inMinutes} minutes');
    }
  }

  /// Clear lockout
  void clearLockout() {
    _lockoutEndTime = null;
    _failedAttempts = 0;
    _failedAttemptsController.add(0);
    _lockoutController.add(null);
    debugPrint('Lockout cleared');
  }

  /// Set up auto-lock timer
  void setupAutoLock(AutoLockTimeout timeout) {
    _autoLockTimer?.cancel();

    final duration = timeout.duration;
    if (duration == null) return; // Never auto-lock

    if (duration == Duration.zero) {
      // Immediate lock
      logout();
      return;
    }

    _autoLockTimer = Timer(duration, () {
      logout();
      debugPrint('Auto-lock triggered after ${duration.inMinutes} minutes');
    });
  }

  /// Reset auto-lock timer (call on user activity)
  void resetAutoLockTimer(AutoLockTimeout timeout) {
    if (_isAuthenticated) {
      setupAutoLock(timeout);
    }
  }

  /// Logout and clear authentication state
  void logout() {
    _isAuthenticated = false;
    _lastAuthTime = null;
    _autoLockTimer?.cancel();
    _autoLockTimer = null;

    _authStateController.add(false);
    debugPrint('User logged out');
  }

  /// Check if authentication is required for the given action
  bool requiresAuthentication(
    AppSecuritySettings settings,
    AuthAction action,
  ) {
    if (!_isAuthenticated) return true;

    switch (action) {
      case AuthAction.appStart:
        return settings.requireAuthOnStart;
      case AuthAction.sensitiveData:
        return settings.requireAuthForSensitiveData;
      case AuthAction.export:
        return settings.requireAuthForExport;
      case AuthAction.settings:
        return settings.requireAuthForSettings;
    }
  }

  /// Get authentication prompt message for action
  String getAuthPromptMessage(AuthAction action) {
    switch (action) {
      case AuthAction.appStart:
        return 'Please authenticate to access Obsession Tracker';
      case AuthAction.sensitiveData:
        return 'Please authenticate to access sensitive data';
      case AuthAction.export:
        return 'Please authenticate to export data';
      case AuthAction.settings:
        return 'Please authenticate to access settings';
    }
  }

  /// Dispose of the service
  void dispose() {
    _autoLockTimer?.cancel();
    _authStateController.close();
    _failedAttemptsController.close();
    _lockoutController.close();
    _instance = null;
  }
}

/// Authentication result enum
enum AuthResult {
  success,
  failed,
  cancelled,
  error,
  notAvailable,
  notEnrolled,
  lockedOut,
  biometricLockedOut,
}

/// Authentication action types
enum AuthAction {
  appStart,
  sensitiveData,
  export,
  settings,
}

/// Extension for AuthResult
extension AuthResultExtension on AuthResult {
  bool get isSuccess => this == AuthResult.success;
  bool get isFailure => [
        AuthResult.failed,
        AuthResult.error,
        AuthResult.lockedOut,
        AuthResult.biometricLockedOut,
      ].contains(this);

  String get message {
    switch (this) {
      case AuthResult.success:
        return 'Authentication successful';
      case AuthResult.failed:
        return 'Authentication failed';
      case AuthResult.cancelled:
        return 'Authentication cancelled';
      case AuthResult.error:
        return 'Authentication error occurred';
      case AuthResult.notAvailable:
        return 'Biometric authentication not available';
      case AuthResult.notEnrolled:
        return 'No biometrics enrolled on device';
      case AuthResult.lockedOut:
        return 'Account temporarily locked due to too many failed attempts';
      case AuthResult.biometricLockedOut:
        return 'Biometric authentication temporarily locked';
    }
  }
}
