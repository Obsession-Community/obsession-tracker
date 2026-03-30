import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/local_sync_models.dart';
import 'package:obsession_tracker/core/providers/local_sync_provider.dart';
import 'package:obsession_tracker/core/services/device_discovery_service.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:obsession_tracker/features/sync/presentation/pages/scan_qr_page.dart';
import 'package:obsession_tracker/features/sync/presentation/widgets/transfer_progress_widget.dart';

/// Page for receiving data from another device
class ReceiveDataPage extends ConsumerStatefulWidget {
  const ReceiveDataPage({super.key});

  @override
  ConsumerState<ReceiveDataPage> createState() => _ReceiveDataPageState();
}

class _ReceiveDataPageState extends ConsumerState<ReceiveDataPage> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  MergeStrategy _mergeStrategy = MergeStrategy.merge;

  @override
  void initState() {
    super.initState();
    // Start discovery when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(localSyncProvider.notifier).startDiscovery();
    });
  }

  @override
  void dispose() {
    // Stop discovery when page closes
    ref.read(localSyncProvider.notifier).stopDiscovery();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _scanQrCode() async {
    final qrData = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (context) => const ScanQrPage(),
      ),
    );

    if (qrData != null && mounted) {
      await ref.read(localSyncProvider.notifier).connectToSender(qrData);
    }
  }

  Future<void> _startReceive() async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the transfer password')),
      );
      return;
    }

    await ref.read(localSyncProvider.notifier).startReceive(
          password: _passwordController.text,
          mergeStrategy: _mergeStrategy,
        );
  }

  Future<void> _cancelSync() async {
    await ref.read(localSyncProvider.notifier).cancelSync();
    if (mounted) {
      Navigator.pop(context);
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
          title: const Text('Receive Data'),
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
        return _buildScanPrompt();

      case LocalSyncState.preparing:
        return _buildConnectingState();

      case LocalSyncState.connected:
        return _buildConnectedState(syncState);

      case LocalSyncState.waitingForConnection:
      case LocalSyncState.transferring:
        return _buildTransferringState(syncState);

      case LocalSyncState.completed:
        return _buildCompletedState(syncState);

      case LocalSyncState.failed:
      case LocalSyncState.cancelled:
        return _buildFailedState(syncState);
    }
  }

  Widget _buildScanPrompt() {
    final syncState = ref.watch(localSyncProvider);
    final devices = syncState.discoveredDevices;
    final unresolvedDevices = syncState.unresolvedDevices;
    final isDiscovering = syncState.isDiscovering;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),

        // Discovery header
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isDiscovering)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.gold,
                      ),
                    )
                  else
                    const Icon(Icons.wifi_find, color: AppTheme.gold),
                  const SizedBox(width: 12),
                  Text(
                    isDiscovering ? 'Searching for devices...' : 'Looking for devices',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Make sure both devices are on the same WiFi network',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

        // Discovered devices list
        if (devices.isEmpty && unresolvedDevices.isEmpty) ...[
          _buildEmptyDevicesList(),
        ] else ...[
          if (devices.isNotEmpty) ...[
            Text(
              'Nearby Devices',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...devices.map(_buildDeviceCard),
          ],
          // Show unresolved devices with QR code suggestion
          if (unresolvedDevices.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildUnresolvedDevicesCard(unresolvedDevices),
          ],
        ],

        const SizedBox(height: 24),

        // QR Code fallback
        ExpansionTile(
          title: const Text('Scan QR Code Instead'),
          subtitle: const Text("Use if device doesn't appear"),
          leading: const Icon(Icons.qr_code_scanner),
          initiallyExpanded: unresolvedDevices.isNotEmpty,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _scanQrCode,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Open QR Scanner'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildUnresolvedDevicesCard(List<UnresolvedDevice> devices) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Device${devices.length > 1 ? 's' : ''} Found (Connection Issue)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...devices.map((device) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.smartphone, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      device.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    if (device.platform != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${device.platform})',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ],
                ),
              )),
          const SizedBox(height: 12),
          Text(
            'Automatic connection failed. Please use the QR code scanner below to connect manually.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

  Widget _buildEmptyDevicesList() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.wifi_find,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No devices found yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'On the sending device, go to Local Sync > Send Data.\n'
            'It will appear here automatically.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(DiscoveredDevice device) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.smartphone,
            color: AppTheme.gold,
          ),
        ),
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(device.ip),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _connectToDevice(device),
      ),
    );
  }

  Future<void> _connectToDevice(DiscoveredDevice device) async {
    await ref.read(localSyncProvider.notifier).connectToDiscoveredDevice(device);
  }

  Widget _buildConnectingState() {
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
            'Connecting...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Establishing connection with sender',
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

  Widget _buildConnectedState(LocalSyncProviderState syncState) {
    final info = syncState.remoteDeviceInfo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),

        // Connected card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                    ),
                    if (info != null)
                      Text(
                        '${info.deviceName} (${info.platform})',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // What will be transferred
        if (info != null) ...[
          Text(
            'Data to Transfer',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _buildDataSummary(info),
          const SizedBox(height: 24),
        ],

        // Merge strategy selection
        Text(
          'Import Mode',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        _buildMergeStrategySelector(),

        const SizedBox(height: 24),

        // Password field
        Text(
          'Transfer Password',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the password set on the sending device',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter transfer password',
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
        ),

        const SizedBox(height: 32),

        // Start button
        FilledButton.icon(
          onPressed: _startReceive,
          icon: const Icon(Icons.download),
          label: const Text('Start Transfer'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
          ),
        ),

        const SizedBox(height: 12),

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

  Widget _buildDataSummary(SyncInfo info) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildDataRow(Icons.route, 'Sessions', info.totalSessions.toString()),
          const Divider(height: 16),
          _buildDataRow(Icons.search, 'Hunts', info.totalHunts.toString()),
          const Divider(height: 16),
          _buildDataRow(Icons.map, 'Routes', info.totalRoutes.toString()),
          const Divider(height: 16),
          _buildDataRow(Icons.storage, 'Size', info.formattedSize),
        ],
      ),
    );
  }

  Widget _buildDataRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.gold),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildMergeStrategySelector() {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          RadioListTile<MergeStrategy>(
            value: MergeStrategy.merge,
            groupValue: _mergeStrategy, // ignore: deprecated_member_use
            onChanged: (value) => setState(() => _mergeStrategy = value!), // ignore: deprecated_member_use
            title: const Text('Merge'),
            subtitle: const Text('Add to existing data, skip duplicates'),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          const Divider(height: 1),
          RadioListTile<MergeStrategy>(
            value: MergeStrategy.replace,
            groupValue: _mergeStrategy, // ignore: deprecated_member_use
            onChanged: (value) => setState(() => _mergeStrategy = value!), // ignore: deprecated_member_use
            title: const Text('Replace'),
            subtitle: const Text('Delete all existing data first'),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
          ),
        ],
      ),
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
          title: 'Receiving Data',
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
      return _buildConnectingState();
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
