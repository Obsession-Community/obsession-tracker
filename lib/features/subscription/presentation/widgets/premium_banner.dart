import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/features/subscription/presentation/widgets/paywall_widget.dart';

/// A collapsible banner that gently nudges free users to upgrade
/// Shows premium features available and allows dismissal
/// Dismissal state is persisted across app sessions
class PremiumUpgradeBanner extends ConsumerWidget {
  const PremiumUpgradeBanner({
    super.key,
    required this.message,
    this.features = const [],
  });

  final String message;
  final List<String> features;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Don't show for premium users
    final isPremium = ref.watch(isPremiumProvider);
    // Check persisted dismissal state
    final isDismissed = ref.watch(premiumBannerDismissedProvider);

    if (isPremium || isDismissed) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 4,
      color: AppTheme.darkBackground,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.gold,
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.workspace_premium,
              color: AppTheme.gold,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Free Tier',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.gold,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textOnDarkMuted,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () async {
                await showPaywall(
                  context,
                  title: 'Upgrade to Premium',
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.darkBackground,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Upgrade',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.close,
                size: 20,
                color: AppTheme.textOnDarkMuted,
              ),
              onPressed: () {
                ref.read(premiumBannerDismissedProvider.notifier).dismiss();
              },
              tooltip: 'Dismiss',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A floating badge that shows premium features are available
/// Less intrusive than the banner, appears in bottom-right of screen
class PremiumFloatingBadge extends ConsumerWidget {
  const PremiumFloatingBadge({
    super.key,
    this.bottom = 80,
    this.right = 16,
  });

  final double bottom;
  final double right;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Don't show for premium users
    final isPremium = ref.watch(isPremiumProvider);
    if (isPremium) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: bottom,
      right: right,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(28),
        color: AppTheme.gold,
        child: InkWell(
          onTap: () async {
            await showPaywall(
              context,
              title: 'Upgrade to Premium',
            );
          },
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.workspace_premium,
                  color: AppTheme.darkBackground,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Try Premium Free',
                  style: TextStyle(
                    color: AppTheme.darkBackground,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
