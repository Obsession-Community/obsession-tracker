import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:obsession_tracker/core/services/biometric_lock_service.dart';

/// Lock screen displayed when app requires biometric authentication.
///
/// Shows when:
/// - App starts and biometric lock is enabled
/// - App returns from background after timeout
/// - User manually locks the app
///
/// Provides:
/// - Clear indication that app is locked
/// - Biometric authentication button
/// - User-friendly messaging
class BiometricLockScreen extends StatefulWidget {
  /// Callback when authentication is successful
  final VoidCallback onUnlocked;

  /// Optional custom message to display
  final String? customMessage;

  /// Biometric lock service instance
  final BiometricLockService lockService;

  const BiometricLockScreen({
    super.key,
    required this.onUnlocked,
    required this.lockService,
    this.customMessage,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with WidgetsBindingObserver {
  bool _isAuthenticating = false;
  String? _errorMessage;
  String _biometricName = 'Biometric Authentication';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBiometricInfo();
    // Auto-show authentication dialog on both platforms
    // With biometricOnly=true, the fingerprint scanner starts immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Re-authenticate when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _authenticate();
    }
  }

  Future<void> _loadBiometricInfo() async {
    final name = await widget.lockService.getBiometricName();
    if (mounted) {
      setState(() {
        _biometricName = name;
      });
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final bool success = await widget.lockService.authenticate(
        reason: widget.customMessage ??
            'Please authenticate to access your treasure hunting data',
      );

      if (mounted) {
        if (success) {
          widget.onUnlocked();
        } else {
          setState(() {
            _errorMessage = 'Authentication cancelled. Please try again.';
            _isAuthenticating = false;
          });
        }
      }
    } on BiometricAuthException catch (e) {
      // Biometric authentication error (device not supported, not enrolled, etc.)
      debugPrint('⚠️ BiometricAuthException: ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isAuthenticating = false;
        });

        // Biometrics are no longer available - the service has already disabled the lock
        // Automatically unlock to prevent user from being locked out
        debugPrint('🔓 Unlocking app since biometric lock was disabled due to error');
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            widget.onUnlocked();
          }
        });
      }
    } catch (e) {
      debugPrint('⚠️ Unexpected error during authentication: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred. Please try again.';
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lock icon
              Icon(
                Icons.lock_outline,
                size: 100,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 32),

              // App name
              Text(
                'Obsession Tracker',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Status message
              Text(
                'Your data is locked',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Custom message or default
              Text(
                widget.customMessage ??
                    'Authenticate to access your treasure hunting sessions',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Platform-specific instruction
              if (Theme.of(context).platform == TargetPlatform.android)
                Text(
                  'Tap the Unlock button to authenticate',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 32),

              // Biometric icon based on available biometric
              _buildBiometricIcon(context),
              const SizedBox(height: 24),

              // Authenticate button
              FilledButton.icon(
                onPressed: _isAuthenticating ? null : _authenticate,
                icon: _isAuthenticating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.fingerprint),
                label: Text(_isAuthenticating ? 'Authenticating...' : 'Unlock'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 16),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Biometric method name
              Text(
                'Using $_biometricName',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<BiometricType>>(
      future: widget.lockService.getAvailableBiometrics(),
      builder: (context, snapshot) {
        IconData iconData;
        final iconColor = colorScheme.primary.withValues(alpha: 0.7);

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final biometrics = snapshot.data!;
          if (biometrics.contains(BiometricType.face)) {
            iconData = Icons.face;
          } else if (biometrics.contains(BiometricType.fingerprint)) {
            iconData = Icons.fingerprint;
          } else if (biometrics.contains(BiometricType.iris)) {
            iconData = Icons.visibility;
          } else {
            iconData = Icons.password;
          }
        } else {
          iconData = Icons.fingerprint;
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            iconData,
            size: 64,
            color: iconColor,
          ),
        );
      },
    );
  }
}
