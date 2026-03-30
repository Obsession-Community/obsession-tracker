import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/help_models.dart';
import 'package:obsession_tracker/core/providers/help_provider.dart';
import 'package:obsession_tracker/features/help/presentation/widgets/contextual_help_panel.dart';
import 'package:obsession_tracker/features/help/presentation/widgets/onboarding_flow.dart';
import 'package:obsession_tracker/features/help/presentation/widgets/tutorial_overlay.dart';

/// Main integration widget that manages all help system components
class HelpSystemIntegration extends ConsumerStatefulWidget {
  const HelpSystemIntegration({
    required this.child,
    super.key,
    this.context = HelpContext.general,
    this.showContextualHelp = false,
    this.enableOnboarding = true,
    this.enableTutorials = true,
  });

  final Widget child;
  final HelpContext context;
  final bool showContextualHelp;
  final bool enableOnboarding;
  final bool enableTutorials;

  @override
  ConsumerState<HelpSystemIntegration> createState() =>
      _HelpSystemIntegrationState();
}

class _HelpSystemIntegrationState extends ConsumerState<HelpSystemIntegration> {
  @override
  void initState() {
    super.initState();

    // Initialize help system
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeHelpSystem();
    });
  }

  @override
  void didUpdateWidget(HelpSystemIntegration oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update context when widget changes
    if (oldWidget.context != widget.context) {
      ref.read(helpNotifierProvider.notifier).setCurrentContext(widget.context);
    }
  }

  Future<void> _initializeHelpSystem() async {
    final helpNotifier = ref.read(helpNotifierProvider.notifier);

    // Initialize the help system
    await helpNotifier.initialize();

    // Set current context
    helpNotifier.setCurrentContext(widget.context);

    // Check if we should show onboarding for first-time users
    if (widget.enableOnboarding) {
      await _checkAndShowOnboarding();
    }
  }

  Future<void> _checkAndShowOnboarding() async {
    // Check if user has completed onboarding by checking their progress
    final onboardingFlowsAsync = ref.read(onboardingFlowsProvider);

    onboardingFlowsAsync.whenData((flows) {
      final firstTimeFlow = flows
          .where(
              (flow) => flow.id == 'first_time_user' && flow.showOnFirstLaunch)
          .firstOrNull;

      if (firstTimeFlow != null) {
        // Delay to ensure UI is ready
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ref
                .read(helpNotifierProvider.notifier)
                .showOnboarding(firstTimeFlow);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          // Main app content
          widget.child,

          // Contextual help panel (if enabled and not in tutorial/onboarding mode)
          if (widget.showContextualHelp)
            Consumer(
              builder: (context, ref, child) {
                final helpState = ref.watch(helpNotifierProvider);

                if (helpState.isTutorialActive ||
                    helpState.isOnboardingActive) {
                  return const SizedBox.shrink();
                }

                return Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: ContextualHelpPanel(
                    context: widget.context,
                    maxItems: 2,
                    showHeader: false,
                  ),
                );
              },
            ),

          // Tutorial overlay
          if (widget.enableTutorials) const TutorialOverlay(),

          // Onboarding flow
          if (widget.enableOnboarding) const OnboardingFlowWidget(),

          // Help overlay for quick tips
          Consumer(
            builder: (context, ref, child) {
              final helpState = ref.watch(helpNotifierProvider);

              if (!helpState.isHelpOverlayVisible) {
                return const SizedBox.shrink();
              }

              return _buildHelpOverlay();
            },
          ),
        ],
      );

  Widget _buildHelpOverlay() => Material(
        color: Colors.black.withValues(alpha: 0.5),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    const Icon(
                      Icons.help_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Quick Help',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        ref
                            .read(helpNotifierProvider.notifier)
                            .setHelpOverlayVisible(visible: false);
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Quick help content
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final contextualHelpAsync =
                          ref.watch(contextualHelpProvider(widget.context));

                      return contextualHelpAsync.when(
                        data: (helpContent) {
                          if (helpContent.isEmpty) {
                            return _buildNoHelpAvailable();
                          }

                          return ListView.builder(
                            itemCount: helpContent.length,
                            itemBuilder: (context, index) {
                              final content = helpContent[index];
                              return _buildQuickHelpItem(content);
                            },
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        error: (error, stack) => _buildErrorState(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildQuickHelpItem(HelpContent content) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getTypeColor(content.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getTypeIcon(content.type),
              size: 20,
              color: _getTypeColor(content.type),
            ),
          ),
          title: Text(
            content.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            content.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ref
                .read(helpNotifierProvider.notifier)
                .setHelpOverlayVisible(visible: false);
            Navigator.of(context).pushNamed(
              '/help/content',
              arguments: content,
            );
          },
        ),
      );

  Widget _buildNoHelpAvailable() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 64,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'No help available for this section',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check the main help section for more content',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildErrorState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load help content',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  IconData _getTypeIcon(HelpContentType type) {
    switch (type) {
      case HelpContentType.tutorial:
        return Icons.school;
      case HelpContentType.guide:
        return Icons.map;
      case HelpContentType.faq:
        return Icons.quiz;
      case HelpContentType.troubleshooting:
        return Icons.build;
      case HelpContentType.documentation:
        return Icons.description;
      case HelpContentType.video:
        return Icons.play_circle;
      case HelpContentType.interactive:
        return Icons.touch_app;
      case HelpContentType.quickTip:
        return Icons.lightbulb;
    }
  }

  Color _getTypeColor(HelpContentType type) {
    switch (type) {
      case HelpContentType.tutorial:
        return Colors.blue;
      case HelpContentType.guide:
        return Colors.green;
      case HelpContentType.faq:
        return Colors.orange;
      case HelpContentType.troubleshooting:
        return Colors.red;
      case HelpContentType.documentation:
        return Colors.purple;
      case HelpContentType.video:
        return Colors.pink;
      case HelpContentType.interactive:
        return Colors.teal;
      case HelpContentType.quickTip:
        return Colors.amber;
    }
  }
}

/// Extension to provide easy access to help system integration
extension HelpSystemExtension on Widget {
  /// Wraps the widget with help system integration
  Widget withHelpSystem({
    HelpContext context = HelpContext.general,
    bool showContextualHelp = false,
    bool enableOnboarding = true,
    bool enableTutorials = true,
  }) =>
      HelpSystemIntegration(
        context: context,
        showContextualHelp: showContextualHelp,
        enableOnboarding: enableOnboarding,
        enableTutorials: enableTutorials,
        child: this,
      );
}
