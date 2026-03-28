import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/help_models.dart';
import 'package:obsession_tracker/core/providers/help_provider.dart';

/// Floating action button for quick help access
class QuickHelpFAB extends ConsumerStatefulWidget {
  const QuickHelpFAB({
    super.key,
    this.context,
  });

  final HelpContext? context;

  @override
  ConsumerState<QuickHelpFAB> createState() => _QuickHelpFABState();
}

class _QuickHelpFABState extends ConsumerState<QuickHelpFAB>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final helpState = ref.watch(helpNotifierProvider);
    final currentContext = widget.context ?? helpState.currentContext;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Quick help options
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) => Transform.scale(
            scale: _animation.value,
            child: Opacity(
              opacity: _animation.value,
              child: _isExpanded
                  ? _buildQuickOptions(currentContext)
                  : const SizedBox.shrink(),
            ),
          ),
        ),

        // Main FAB
        FloatingActionButton(
          onPressed: _toggleQuickHelp,
          tooltip: _isExpanded ? 'Close quick help' : 'Quick help',
          child: AnimatedRotation(
            turns: _isExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 300),
            child: Icon(_isExpanded ? Icons.close : Icons.help_outline),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickOptions(HelpContext currentContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Search help
          _buildQuickOption(
            icon: Icons.search,
            label: 'Search Help',
            onTap: _openHelpSearch,
          ),

          const SizedBox(height: 8),

          // Contextual help
          _buildQuickOption(
            icon: Icons.help,
            label: 'Context Help',
            onTap: () => _showContextualHelp(currentContext),
          ),

          const SizedBox(height: 8),

          // Quick tutorial
          _buildQuickOption(
            icon: Icons.school,
            label: 'Quick Tutorial',
            onTap: () => _startQuickTutorial(currentContext),
          ),

          const SizedBox(height: 8),

          // FAQ
          _buildQuickOption(
            icon: Icons.quiz,
            label: 'FAQ',
            onTap: _openFAQ,
          ),

          const SizedBox(height: 16),
        ],
      );

  Widget _buildQuickOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),

          const SizedBox(width: 8),

          // Mini FAB
          FloatingActionButton.small(
            onPressed: onTap,
            heroTag: 'quick_help_$label',
            tooltip: label,
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
            child: Icon(icon, size: 20),
          ),
        ],
      );

  void _toggleQuickHelp() {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _openHelpSearch() {
    _closeQuickHelp();
    Navigator.of(context).pushNamed('/help');
  }

  void _showContextualHelp(HelpContext context) {
    _closeQuickHelp();
    _showQuickHelpBottomSheet(context);
  }

  void _startQuickTutorial(HelpContext context) {
    _closeQuickHelp();
    // Find and start a quick tutorial for the current context
    ref.read(helpContentByContextProvider(context)).whenData((content) {
      final tutorials = content
          .where((c) => c.type == HelpContentType.tutorial)
          .cast<Tutorial>()
          .where((t) =>
              t.estimatedDuration != null &&
              t.estimatedDuration!.inMinutes <= 5)
          .toList();

      if (tutorials.isNotEmpty) {
        ref.read(helpNotifierProvider.notifier).showTutorial(tutorials.first);
      } else {
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(
            content: Text('No quick tutorials available for this section'),
          ),
        );
      }
    });
  }

  void _openFAQ() {
    _closeQuickHelp();
    Navigator.of(context).pushNamed('/help', arguments: {
      'initialTab': HelpContentType.faq.index,
    });
  }

  void _closeQuickHelp() {
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
      });
      _animationController.reverse();
    }
  }

  void _showQuickHelpBottomSheet(HelpContext context) {
    showModalBottomSheet<void>(
      context: this.context,
      isScrollControlled: true,
      builder: (buildContext) => _QuickHelpBottomSheet(context: context),
    );
  }
}

/// Bottom sheet for quick contextual help
class _QuickHelpBottomSheet extends ConsumerWidget {
  const _QuickHelpBottomSheet({
    required this.context,
  });

  final HelpContext context;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextualHelpAsync = ref.watch(contextualHelpProvider(this.context));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Help',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: contextualHelpAsync.when(
                data: (helpContent) {
                  if (helpContent.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: helpContent.length,
                    itemBuilder: (context, index) {
                      final content = helpContent[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getTypeColor(content.type)
                                  .withValues(alpha: 0.1),
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
                            Navigator.of(context).pop();
                            Navigator.of(context).pushNamed(
                              '/help/content',
                              arguments: content,
                            );
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => _buildErrorState(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No help available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check the main help section for more content',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );

  Widget _buildErrorState(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load help',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
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
