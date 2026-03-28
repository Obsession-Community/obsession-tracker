import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/services/biometric_lock_service.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:obsession_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:obsession_tracker/features/settings/presentation/widgets/settings_tile.dart';

/// Security settings page for managing biometric authentication and app lock
class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  final BiometricLockService _biometricService = BiometricLockService();

  bool _isLoading = true;
  bool _isEnabled = false;
  bool _isBiometricAvailable = false;
  String _biometricName = 'Biometric Authentication';
  LockTimeout _timeout = LockTimeout.immediate;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final enabled = await _biometricService.isEnabled();
      final available = await _biometricService.isDeviceSupported();
      final name = await _biometricService.getBiometricName();
      final timeout = await _biometricService.getTimeout();

      if (mounted) {
        setState(() {
          _isEnabled = enabled;
          _isBiometricAvailable = available;
          _biometricName = name;
          _timeout = timeout;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading security settings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleBiometricLock(bool value) async {
    if (value) {
      try {
        // Check if biometrics are available and enrolled
        debugPrint('🔍 Checking if biometrics are enrolled...');
        final hasEnrolled = await _biometricService.hasEnrolledBiometrics();
        debugPrint('👆 Biometrics enrolled: $hasEnrolled');

        if (!hasEnrolled) {
          if (mounted) {
            showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Biometrics Not Set Up'),
                content: const Text(
                  'You need to set up biometric authentication (Face ID, Touch ID, or fingerprint) '
                  'in your device settings before you can enable app lock.\n\n'
                  'Would you like to set up a passcode instead?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // TODO(dev): Implement passcode setup in future update
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Passcode support coming soon! Please set up biometrics first.'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                    child: const Text('Set Up Passcode'),
                  ),
                ],
              ),
            );
          }
          return;
        }

        // Enabling lock - test authentication first (forcePrompt bypasses enabled check)
        debugPrint('🔐 Testing authentication before enabling lock...');
        final authenticated = await _biometricService.authenticate(
          reason: 'Enable biometric lock to protect your treasure hunting data',
          forcePrompt: true,
        );

        debugPrint('🔐 Authentication result: $authenticated');

        if (authenticated) {
          final enabled = await _biometricService.enable();
          if (enabled) {
            setState(() {
              _isEnabled = true;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$_biometricName lock enabled'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not enable biometric lock. Please check your device settings.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication cancelled or failed'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } on BiometricAuthException catch (e) {
        debugPrint('❌ Biometric error while enabling lock: $e');
        if (mounted) {
          showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cannot Enable Biometric Lock'),
              content: Text(e.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Unexpected error while enabling lock: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Disabling lock - confirm with authentication
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Disable $_biometricName Lock?'),
          content: const Text(
            'Your treasure hunting data will no longer be protected by biometric authentication. '
            'Anyone with access to your device will be able to view your locations.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Disable'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _biometricService.disable();
        setState(() {
          _isEnabled = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$_biometricName lock disabled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  Future<void> _updateTimeout(LockTimeout? newTimeout) async {
    if (newTimeout == null) return;

    await _biometricService.setTimeout(newTimeout);
    setState(() {
      _timeout = newTimeout;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auto-lock timeout updated'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  String _formatTimeoutDescription(LockTimeout timeout) {
    switch (timeout) {
      case LockTimeout.immediate:
        return 'Lock immediately when app goes to background';
      case LockTimeout.oneMinute:
        return 'Lock after 1 minute of inactivity';
      case LockTimeout.fiveMinutes:
        return 'Lock after 5 minutes of inactivity';
      case LockTimeout.fifteenMinutes:
        return 'Lock after 15 minutes of inactivity';
      case LockTimeout.never:
        return 'Never auto-lock (not recommended for treasure data)';
    }
  }

  String _formatTimeoutLabel(LockTimeout timeout) {
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Security'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isBiometricAvailable) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Security'),
          centerTitle: true,
        ),
        body: Padding(
          padding: context.responsivePadding,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Biometric Lock Not Available',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'To enable biometric app lock, you need to:\n\n'
                    '1. Go to your device Settings\n'
                    '2. Set up Face ID, Touch ID, or fingerprint authentication\n'
                    '3. Return to this app and enable the lock\n\n'
                    'Passcode-only lock support is coming in a future update.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _loadSettings,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: context.responsivePadding,
        child: ResponsiveContentBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Biometric Lock Section
            SettingsSection(
              title: 'Biometric Lock',
              subtitle: 'Protect your treasure hunting data',
              children: [
                SettingsSwitchTile(
                  leading: Icon(
                    _biometricName.contains('Face')
                        ? Icons.face
                        : Icons.fingerprint,
                  ),
                  title: '$_biometricName Lock',
                  subtitle: _isEnabled
                      ? 'App is protected with $_biometricName'
                      : 'Enable to secure your treasure locations',
                  value: _isEnabled,
                  onChanged: _toggleBiometricLock,
                ),
                if (_isEnabled) ...[
                  SettingsDropdownTile<LockTimeout>(
                    leading: const Icon(Icons.timer),
                    title: 'Auto-Lock Timeout',
                    subtitle: _formatTimeoutDescription(_timeout),
                    value: _timeout,
                    items: LockTimeout.values
                        .map((timeout) => DropdownMenuItem(
                              value: timeout,
                              child: Text(_formatTimeoutLabel(timeout)),
                            ))
                        .toList(),
                    onChanged: _updateTimeout,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // Security Information
            SettingsSection(
              title: 'Security Information',
              subtitle: 'About your device security',
              children: [
                SettingsTile(
                  leading: Icon(
                    _biometricName.contains('Face')
                        ? Icons.face
                        : Icons.fingerprint,
                  ),
                  title: 'Authentication Type',
                  subtitle: _biometricName,
                ),
                const SettingsTile(
                  leading: Icon(Icons.shield),
                  title: 'Data Protection',
                  subtitle: 'Database encrypted with AES-256',
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Security tips card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Security Tips',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Enable $_biometricName lock to protect your treasure locations\n'
                      '• Use "Immediate" auto-lock for maximum security\n'
                      '• Your database is encrypted with AES-256 encryption\n'
                      '• Biometric data never leaves your device\n'
                      '• Regularly backup your data for safety',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
        ),
      ),
    );
  }
}
