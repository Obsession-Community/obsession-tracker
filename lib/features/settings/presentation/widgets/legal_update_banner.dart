import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/bff_app_config.dart';
import 'package:obsession_tracker/core/services/bff_config_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Provider to check if legal update acknowledgment is needed
final legalUpdateNeededProvider = FutureProvider<bool>((ref) async {
  final configService = BFFConfigService.instance;
  final config = await configService.fetchConfig();
  return configService.needsLegalAcknowledgment(config);
});

/// Provider for the current BFF config
final bffConfigProvider = FutureProvider<BFFAppConfig>((ref) async {
  return BFFConfigService.instance.fetchConfig();
});

/// Helper class for showing legal update dialogs
class LegalUpdateDialog {
  static bool _isShowing = false;

  /// Check if legal update is needed and show dialog if so
  /// Call this from main app widget or home page initState
  static Future<void> showIfNeeded(BuildContext context, WidgetRef ref) async {
    // Prevent multiple dialogs
    if (_isShowing) return;

    try {
      final configService = BFFConfigService.instance;
      final config = await configService.fetchConfig();
      final needsAcknowledgment = await configService.needsLegalAcknowledgment(config);

      if (needsAcknowledgment && context.mounted) {
        _isShowing = true;
        await _showDialog(context, ref, config);
        _isShowing = false;
      }
    } catch (e) {
      debugPrint('LegalUpdateDialog: Error checking legal update: $e');
    }
  }

  static Future<void> _showDialog(
    BuildContext context,
    WidgetRef ref,
    BFFAppConfig config,
  ) async {
    final legal = config.legal;
    final configService = BFFConfigService.instance;

    await showDialog<void>(
      context: context,
      barrierDismissible: false, // User must acknowledge
      builder: (dialogContext) => AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.policy_outlined,
            color: Colors.blue,
            size: 32,
          ),
        ),
        title: const Text('Legal Documents Updated'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (legal.lastUpdated.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Updated: ${legal.lastUpdated}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ),
              if (legal.changeSummary != null && legal.changeSummary!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    legal.changeSummary!,
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                ),
              const Text(
                'Please review the updated documents. By continuing to use the app, you agree to these terms.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              // Document links
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openUrl(
                          configService.getLegalPrivacyUrl(config),
                        ),
                        child: const Text('Privacy Policy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openUrl(
                          configService.getLegalTermsUrl(config),
                        ),
                        child: const Text('Terms'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                await configService.acknowledgeLegalVersion(config);
                ref.invalidate(legalUpdateNeededProvider);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('I Acknowledge'),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Widget that triggers legal update dialog check on build
/// Add this to your main app widget tree (invisible, just triggers the check)
class LegalUpdateChecker extends ConsumerStatefulWidget {
  final Widget child;

  const LegalUpdateChecker({super.key, required this.child});

  @override
  ConsumerState<LegalUpdateChecker> createState() => _LegalUpdateCheckerState();
}

class _LegalUpdateCheckerState extends ConsumerState<LegalUpdateChecker> {
  bool _hasChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check after first frame to ensure context is ready
    if (!_hasChecked) {
      _hasChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          LegalUpdateDialog.showIfNeeded(context, ref);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Banner shown when Terms of Service or Privacy Policy has been updated
/// This is a fallback/reminder for users who dismissed without reading
/// Consider using LegalUpdateChecker for the primary dialog approach
class LegalUpdateBanner extends ConsumerWidget {
  const LegalUpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsAcknowledgment = ref.watch(legalUpdateNeededProvider);
    final configAsync = ref.watch(bffConfigProvider);

    return needsAcknowledgment.when(
      data: (needsUpdate) {
        if (!needsUpdate) return const SizedBox.shrink();

        return configAsync.when(
          data: (config) => _buildBanner(context, ref, config),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBanner(BuildContext context, WidgetRef ref, BFFAppConfig config) {
    final legal = config.legal;
    final configService = BFFConfigService.instance;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.blue.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.policy_outlined,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Legal Documents Updated',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (legal.lastUpdated.isNotEmpty)
                        Text(
                          'Updated: ${legal.lastUpdated}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Change summary if provided
            if (legal.changeSummary != null && legal.changeSummary!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                legal.changeSummary!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons - stacked vertically to prevent wrapping
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openPrivacyPolicy(context, config),
                          child: const Text('Privacy Policy'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openTerms(context, config),
                          child: const Text('Terms'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    await configService.acknowledgeLegalVersion(config);
                    // Refresh the provider to hide the banner
                    ref.invalidate(legalUpdateNeededProvider);
                  },
                  child: const Text('I Acknowledge'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context, BFFAppConfig config) async {
    final url = BFFConfigService.instance.getLegalPrivacyUrl(config);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openTerms(BuildContext context, BFFAppConfig config) async {
    final url = BFFConfigService.instance.getLegalTermsUrl(config);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
