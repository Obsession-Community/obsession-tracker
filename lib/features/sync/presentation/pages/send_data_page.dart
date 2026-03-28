import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/local_sync_models.dart';
import 'package:obsession_tracker/core/providers/local_sync_provider.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:obsession_tracker/features/sync/presentation/pages/select_sync_items_page.dart';
import 'package:obsession_tracker/features/sync/presentation/widgets/sync_qr_code_widget.dart';
import 'package:obsession_tracker/features/sync/presentation/widgets/transfer_progress_widget.dart';

/// Page for sending data to another device
class SendDataPage extends ConsumerStatefulWidget {
  const SendDataPage({super.key});

  @override
  ConsumerState<SendDataPage> createState() => _SendDataPageState();
}

class _SendDataPageState extends ConsumerState<SendDataPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isStarting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _startSendSession() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isStarting = true);

    try {
      await ref.read(localSyncProvider.notifier).startSendSession(
            password: _passwordController.text,
          );
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  Future<void> _cancelSync() async {
    await ref.read(localSyncProvider.notifier).cancelSync();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _navigateToSelectItems() async {
    if (!_formKey.currentState!.validate()) return;

    // Navigate to selection page with password
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SelectSyncItemsPage(
          password: _passwordController.text,
        ),
      ),
    );

    // If selection page started the sync, the state will update automatically
    // The page will show QR code when state changes to waitingForConnection
    if (result == true && mounted) {
      // Sync was started from selection page
      // State will be updated by the provider
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(localSyncProvider);

    return PopScope(
      canPop: syncState.isIdle || syncState.isCompleted || syncState.isFailed,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && !syncState.isIdle) {
          final shouldCancel = await _showCancelConfirmation();
          if (shouldCancel == true && mounted) {
            await _cancelSync();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Send Data'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (syncState.isIdle || syncState.isCompleted || syncState.isFailed) {
                Navigator.pop(context);
              } else {
                final shouldCancel = await _showCancelConfirmation();
                if (shouldCancel == true) {
                  await _cancelSync();
                }
              }
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: context.responsivePadding,
          child: ResponsiveContentBox(
            child: _buildContent(syncState),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(LocalSyncProviderState syncState) {
    switch (syncState.syncState) {
      case LocalSyncState.idle:
        return _buildPasswordForm();

      case LocalSyncState.preparing:
        return _buildPreparingState();

      case LocalSyncState.waitingForConnection:
        return _buildWaitingState(syncState);

      case LocalSyncState.connected:
      case LocalSyncState.transferring:
        return _buildTransferringState(syncState);

      case LocalSyncState.completed:
        return _buildCompletedState(syncState);

      case LocalSyncState.failed:
      case LocalSyncState.cancelled:
        return _buildFailedState(syncState);
    }
  }

  Widget _buildPasswordForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.gold.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.wifi,
                  size: 48,
                  color: AppTheme.gold,
                ),
                const SizedBox(height: 12),
                Text(
                  'Transfer Over WiFi',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your data will be encrypted and transferred directly to the '
                  'other device over your local WiFi network. No internet required.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Password section header
          Text(
            'Set a Transfer Password',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Share this password with the receiving device',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 12),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter password (min 8 characters)',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() {
                  _obscurePassword = !_obscurePassword;
                }),
              ),
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Confirm password field
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              hintText: 'Re-enter password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() {
                  _obscureConfirm = !_obscureConfirm;
                }),
              ),
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),

          const SizedBox(height: 32),

          // Sync type choice label
          Text(
            'What would you like to send?',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Send All Data button
          FilledButton.icon(
            onPressed: _isStarting ? null : _startSendSession,
            icon: _isStarting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload),
            label: Text(_isStarting ? 'Starting...' : 'Send All Data'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
          ),

          const SizedBox(height: 12),

          // Select Items button
          OutlinedButton.icon(
            onPressed: _isStarting ? null : _navigateToSelectItems,
            icon: const Icon(Icons.checklist),
            label: const Text('Select Specific Items'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPreparingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 64),
          const CircularProgressIndicator(
            color: AppTheme.gold,
          ),
          const SizedBox(height: 24),
          Text(
            'Preparing...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Making this device discoverable on the network',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingState(LocalSyncProviderState syncState) {
    final service = ref.read(localSyncServiceProvider);
    final session = service.currentSession;

    if (session == null || syncState.qrCodeData == null) {
      return _buildPreparingState();
    }

    return Column(
      children: [
        const SizedBox(height: 24),

        // Device discoverable indicator
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.gold.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing animation effect
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.gold.withValues(alpha: 0.1),
                    ),
                  ),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.gold.withValues(alpha: 0.2),
                    ),
                  ),
                  const Icon(
                    Icons.wifi_tethering,
                    size: 48,
                    color: AppTheme.gold,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Ready to Send',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                session.deviceName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.gold,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.gold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Waiting for nearby device...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Instructions
        Text(
          'On the receiving device, go to Local Sync > Receive Data.\n'
          'This device will appear automatically.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        // QR Code fallback (collapsible)
        ExpansionTile(
          title: const Text('Show QR Code'),
          subtitle: const Text('Use if automatic discovery fails'),
          leading: const Icon(Icons.qr_code),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SyncQrCodeWidget(
                qrData: syncState.qrCodeData!,
                deviceName: session.deviceName,
                expiresAt: session.timestamp.add(SyncSession.sessionTimeout),
                onExpired: () {
                  ref.read(localSyncProvider.notifier).cancelSync();
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Cancel button
        OutlinedButton(
          onPressed: _cancelSync,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: const Text('Cancel'),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTransferringState(LocalSyncProviderState syncState) {
    final progress = syncState.progress ??
        SyncProgress(bytesTransferred: 0, totalBytes: 0);

    return Column(
      children: [
        const SizedBox(height: 64),

        TransferProgressWidget(
          progress: progress,
          title: 'Sending Data',
        ),

        const SizedBox(height: 24),

        Text(
          'Please keep both devices connected to the same WiFi network.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildCompletedState(LocalSyncProviderState syncState) {
    final result = syncState.result;

    if (result == null) {
      return _buildPreparingState();
    }

    return Column(
      children: [
        const SizedBox(height: 64),

        SyncResultWidget(
          result: result,
          onDone: () {
            // Get reference before navigation to avoid using ref after unmount
            final notifier = ref.read(localSyncProvider.notifier);
            Navigator.pop(context);
            // Schedule reset after navigation completes
            Future.microtask(notifier.reset);
          },
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildFailedState(LocalSyncProviderState syncState) {
    return Column(
      children: [
        const SizedBox(height: 64),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Transfer Failed',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
              ),
              if (syncState.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  syncState.error!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Retry button
        FilledButton(
          onPressed: () {
            ref.read(localSyncProvider.notifier).reset();
          },
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: const Text('Try Again'),
        ),

        const SizedBox(height: 12),

        // Close button
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: const Text('Close'),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Future<bool?> _showCancelConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Transfer?'),
        content: const Text(
          'Are you sure you want to cancel the transfer? '
          'Any progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Transfer'),
          ),
        ],
      ),
    );
  }
}
