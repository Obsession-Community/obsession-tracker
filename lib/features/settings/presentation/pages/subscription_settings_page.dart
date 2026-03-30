import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/features/subscription/presentation/widgets/paywall_widget.dart';

/// Subscription management settings page
class SubscriptionSettingsPage extends ConsumerWidget {
  const SubscriptionSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionState = ref.watch(subscriptionProvider);
    final isPremium = subscriptionState.isPremium;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current Status Card
          _buildStatusCard(context, subscriptionState),
          const SizedBox(height: 24),

          // Premium Features Card
          _buildFeaturesCard(context, isPremium),
          const SizedBox(height: 24),

          // Action Buttons
          if (isPremium)
            _buildManageSubscriptionButton(context)
          else
            _buildUpgradeButton(context),

          const SizedBox(height: 16),

          // Restore Purchases Button
          _buildRestoreButton(context, ref, subscriptionState),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, SubscriptionState state) {
    final isPremium = state.isPremium;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPremium ? Icons.workspace_premium : Icons.account_circle,
                  color: isPremium
                      ? Colors.amber
                      : Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPremium ? 'Premium' : 'Free Tier',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (isPremium && state.status?.productIdentifier != null)
                        Text(
                          state.status!.productIdentifier!.contains('annual')
                              ? 'Annual Subscription'
                              : 'Monthly Subscription',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (isPremium && state.status?.expirationDate != null) ...[
              const Divider(height: 24),
              _buildInfoRow(
                context,
                'Renews',
                _formatDate(state.status!.expirationDate!),
                Icons.calendar_today,
              ),
            ],
            if (isPremium && state.status?.purchaseDate != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                'Member Since',
                _formatDate(state.status!.purchaseDate!),
                Icons.star,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesCard(BuildContext context, bool isPremium) {
    final features = [
      const _Feature(
        icon: Icons.map,
        title: 'Unlimited Land Lookups',
        description: 'Query ownership data without limits',
        isPremium: true,
      ),
      const _Feature(
        icon: Icons.notifications_active,
        title: 'Real-Time Alerts',
        description: 'Get notified when crossing boundaries',
        isPremium: true,
      ),
      const _Feature(
        icon: Icons.offline_pin,
        title: 'Offline Caching',
        description: 'Download areas for offline use',
        isPremium: true,
      ),
      const _Feature(
        icon: Icons.layers,
        title: 'Advanced Map Layers',
        description: 'Topographic, satellite, and custom layers',
        isPremium: true,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPremium ? 'Your Premium Features' : 'Premium Features',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...features.map((feature) => _buildFeatureRow(
                  context,
                  feature,
                  isPremium,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
    BuildContext context,
    _Feature feature,
    bool hasAccess,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            hasAccess ? Icons.check_circle : Icons.lock,
            color: hasAccess
                ? Colors.green
                : Theme.of(context).colorScheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  feature.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => showPaywall(context),
      icon: const Icon(Icons.workspace_premium),
      label: const Text('Upgrade to Premium'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildManageSubscriptionButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showManageSubscriptionDialog(context),
      icon: const Icon(Icons.settings),
      label: const Text('Manage Subscription'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildRestoreButton(
    BuildContext context,
    WidgetRef ref,
    SubscriptionState state,
  ) {
    return TextButton.icon(
      onPressed: state.isLoading
          ? null
          : () async {
              final messenger = ScaffoldMessenger.of(context);
              final notifier = ref.read(subscriptionProvider.notifier);

              final success = await notifier.restorePurchases();

              if (success) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('✅ Purchases restored successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('No active purchases found'),
                  ),
                );
              }
            },
      icon: state.isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.restore),
      label: const Text('Restore Purchases'),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showManageSubscriptionDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Subscription'),
        content: const Text(
          'To manage your subscription, cancel, or change plans, please visit:\n\n'
          '• iOS: Settings → Your Name → Subscriptions\n'
          '• Android: Play Store → Menu → Subscriptions',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _Feature {
  const _Feature({
    required this.icon,
    required this.title,
    required this.description,
    required this.isPremium,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isPremium;
}
