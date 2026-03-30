import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/subscription.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';

/// Beautiful paywall widget for subscription upsell
///
/// Shows pricing, features, and handles purchase flow
class PaywallWidget extends ConsumerStatefulWidget {
  const PaywallWidget({
    this.title = 'Upgrade to Premium',
    this.onDismiss,
    super.key,
  });

  final String title;
  final VoidCallback? onDismiss;

  @override
  ConsumerState<PaywallWidget> createState() => _PaywallWidgetState();
}

class _PaywallWidgetState extends ConsumerState<PaywallWidget> {
  ProductOffering? _selectedOffering;

  @override
  Widget build(BuildContext context) {
    final subscriptionState = ref.watch(subscriptionProvider);
    final offerings = subscriptionState.offerings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(context),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium features
                    _buildFeaturesList(context),

                    const SizedBox(height: 32),

                    // Pricing options
                    if (offerings.isNotEmpty) ...[
                      _buildPricingOptions(context, offerings),
                      const SizedBox(height: 24),
                    ] else ...[
                      _buildLoadingOrError(context, subscriptionState),
                    ],

                    // Trust signals
                    _buildTrustSignals(context),
                  ],
                ),
              ),
            ),

            // CTA Button
            _buildCTAButton(context, subscriptionState),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Spacer(),
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.gold,
                ),
          ),
          const Spacer(),
          if (widget.onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, color: AppTheme.gold),
              onPressed: widget.onDismiss,
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hunt with Confidence',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.gold,
              ),
        ),
        const SizedBox(height: 16),
        _buildFeature(
          context,
          icon: Icons.check_circle,
          title: 'Full Land Ownership Data',
          description: 'Activity permissions, boundaries, and trail data',
        ),
        _buildFeature(
          context,
          icon: Icons.notifications_active,
          title: 'Real-Time Permission Alerts',
          description: 'Get notified when entering restricted areas',
        ),
        _buildFeature(
          context,
          icon: Icons.cloud_download,
          title: 'Offline Land Data Caching',
          description: 'Download entire states for offline use',
        ),
        _buildFeature(
          context,
          icon: Icons.gavel,
          title: 'Stay Informed',
          description: 'Know land rules before you search',
        ),
      ],
    );
  }

  Widget _buildFeature(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            color: AppTheme.gold,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppTheme.textOnDarkMuted
                            : AppTheme.textOnLightMuted,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingOptions(
    BuildContext context,
    List<ProductOffering> offerings,
  ) {
    // Find annual and monthly offerings
    final annual = offerings.firstWhere(
      (o) => o.isAnnual,
      orElse: () => offerings.first,
    );
    final monthly = offerings.firstWhere(
      (o) => o.isMonthly,
      orElse: () => offerings.last,
    );

    // Default to annual
    _selectedOffering ??= annual;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Plan',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        _buildPricingCard(
          context,
          offering: annual,
          isSelected: _selectedOffering == annual,
          badge: 'BEST VALUE',
        ),
        const SizedBox(height: 12),
        _buildPricingCard(
          context,
          offering: monthly,
          isSelected: _selectedOffering == monthly,
        ),
      ],
    );
  }

  Widget _buildPricingCard(
    BuildContext context, {
    required ProductOffering offering,
    required bool isSelected,
    String? badge,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthlyPrice = offering.pricePerMonth;
    final savings = offering.isAnnual && offering.getSavingsPercent(6.99) != null
        ? offering.getSavingsPercent(6.99)!
        : null;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOffering = offering;
        });
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.gold : (isDark ? AppTheme.textOnDarkMuted.withValues(alpha: 0.3) : AppTheme.textOnLightMuted.withValues(alpha: 0.3)),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? AppTheme.gold.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Radio indicator
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.gold
                            : (isDark ? AppTheme.textOnDarkMuted : AppTheme.textOnLightMuted),
                        width: 2,
                      ),
                      color: isSelected
                          ? AppTheme.gold
                          : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: AppTheme.darkBackground,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),

                  // Plan details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offering.isAnnual ? 'Annual Plan' : 'Monthly Plan',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        if (savings != null)
                          Text(
                            'Save $savings%',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.gold,
                                      fontWeight: FontWeight.bold,
                                    ),
                          ),
                        Text(
                          '\$${monthlyPrice.toStringAsFixed(2)}/month',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? AppTheme.textOnDarkMuted
                                        : AppTheme.textOnLightMuted,
                                  ),
                        ),
                      ],
                    ),
                  ),

                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        offering.priceString,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.gold,
                            ),
                      ),
                      Text(
                        offering.periodDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppTheme.textOnDarkMuted
                                  : AppTheme.textOnLightMuted,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Badge
            if (badge != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.gold,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: AppTheme.darkBackground,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustSignals(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppTheme.textOnDarkMuted : AppTheme.textOnLightMuted;

    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.gold),
            const SizedBox(width: 8),
            Text(
              '7-Day Free Trial',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_outlined, size: 16, color: mutedColor),
            const SizedBox(width: 8),
            Text(
              'Cancel Anytime',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Coverage notice
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.gold.withValues(alpha: 0.1)
                : AppTheme.gold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.gold.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: mutedColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Land ownership data covers the continental United States. '
                  'Canadian and other international coverage is not yet available.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                        height: 1.4,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOrError(
    BuildContext context,
    SubscriptionState subscriptionState,
  ) {
    if (subscriptionState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.gold),
      );
    }

    if (subscriptionState.error != null) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load pricing',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              subscriptionState.error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.textOnDarkMuted
                        : AppTheme.textOnLightMuted,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(subscriptionProvider.notifier).refresh();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCTAButton(
    BuildContext context,
    SubscriptionState subscriptionState,
  ) {
    final isLoading = subscriptionState.isLoading;
    final hasOffering = _selectedOffering != null;
    final periodText = _selectedOffering?.isAnnual == true ? 'year' : 'month';
    final billingText = _selectedOffering?.isAnnual == true ? 'yearly' : 'monthly';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isLoading || !hasOffering ? null : _handlePurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.darkBackground,
                disabledBackgroundColor: AppTheme.gold.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.darkBackground),
                      ),
                    )
                  : Text(
                      'Start Free Trial',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.darkBackground,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Required subscription disclosure for Google Play compliance
          Text(
            'After your 7-day free trial, you will be charged '
            '${_selectedOffering?.priceString ?? ''} $billingText. '
            'Subscription automatically renews every $periodText until canceled.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textOnDarkMuted,
                  height: 1.4,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Cancel anytime in your device settings. '
            'Premium features are optional; core app features remain free.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textOnDarkMuted.withValues(alpha: 0.7),
                  fontSize: 11,
                  height: 1.3,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _handlePurchase() async {
    if (_selectedOffering == null) return;

    final notifier = ref.read(subscriptionProvider.notifier);
    final success = await notifier.purchase(_selectedOffering!);

    if (success && mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome to Premium!'),
          backgroundColor: AppTheme.gold,
        ),
      );

      // Dismiss paywall - only pop once!
      Navigator.of(context).pop(true);
    } else if (mounted) {
      // Check for error in state
      final currentState = ref.read(subscriptionProvider);
      if (currentState.error != null) {
        // Show error (if not cancelled)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentState.error!),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}

/// Show paywall as a modal bottom sheet
Future<bool?> showPaywall(BuildContext context, {String? title}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => PaywallWidget(
        title: title ?? 'Upgrade to Premium',
        onDismiss: () => Navigator.of(context).pop(false),
      ),
    ),
  );
}
