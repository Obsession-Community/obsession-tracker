import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/help_models.dart';
import 'package:obsession_tracker/core/providers/help_provider.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';

/// Panel showing contextual help based on current app context
class ContextualHelpPanel extends ConsumerWidget {
  const ContextualHelpPanel({
    super.key,
    this.context,
    this.maxItems = 3,
    this.showHeader = true,
  });

  final HelpContext? context;
  final int maxItems;
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helpState = ref.watch(helpNotifierProvider);
    final currentContext = this.context ?? helpState.currentContext;

    final contextualHelpAsync =
        ref.watch(contextualHelpProvider(currentContext));

    return contextualHelpAsync.when(
      data: (helpContent) {
        if (helpContent.isEmpty) {
          return const SizedBox.shrink();
        }

        return _buildPanel(context, helpContent.take(maxItems).toList());
      },
      loading: () => _buildLoadingPanel(context),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildPanel(BuildContext context, List<HelpContent> content) => Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(context.isTablet ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader) ...[
                _buildHeader(context),
                SizedBox(height: context.isTablet ? 16 : 12),
              ],

              // Content list
              ...content.asMap().entries.map((entry) {
                final index = entry.key;
                final helpContent = entry.value;

                return Column(
                  children: [
                    if (index > 0) const SizedBox(height: 8),
                    _buildContextualItem(context, helpContent),
                  ],
                );
              }),

              // View all button
              if (content.length >= maxItems) ...[
                const SizedBox(height: 12),
                _buildViewAllButton(context),
              ],
            ],
          ),
        ),
      );

  Widget _buildHeader(BuildContext context) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.help_outline,
              size: context.isTablet ? 24 : 20,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Help',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: context.isTablet ? 18 : 16,
                      ),
                ),
                Text(
                  'Helpful tips for this section',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showAllContextualHelp(context),
            icon: const Icon(Icons.open_in_full),
            tooltip: 'View all help',
            visualDensity: VisualDensity.compact,
          ),
        ],
      );

  Widget _buildContextualItem(BuildContext context, HelpContent content) =>
      InkWell(
        onTap: () => _openContent(context, content),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              // Type icon
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _getTypeColor(content.type).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _getTypeIcon(content.type),
                  size: 16,
                  color: _getTypeColor(content.type),
                ),
              ),

              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      content.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      );

  Widget _buildViewAllButton(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showAllContextualHelp(context),
          icon: const Icon(Icons.help_outline, size: 18),
          label: const Text('View All Help'),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
      );

  Widget _buildLoadingPanel(BuildContext context) => Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(context.isTablet ? 20 : 16),
          child: Column(
            children: [
              if (showHeader) ...[
                _buildHeader(context),
                SizedBox(height: context.isTablet ? 16 : 12),
              ],

              // Loading items
              ...List.generate(
                  2,
                  (index) => Padding(
                        padding: EdgeInsets.only(bottom: index < 1 ? 8 : 0),
                        child: _buildLoadingItem(context),
                      )),
            ],
          ),
        ),
      );

  Widget _buildLoadingItem(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            // Icon placeholder
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
            ),

            const SizedBox(width: 12),

            // Content placeholder
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 12,
                    width: MediaQuery.of(context).size.width * 0.6,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  void _openContent(BuildContext context, HelpContent content) {
    Navigator.of(context).pushNamed(
      '/help/content',
      arguments: content,
    );
  }

  void _showAllContextualHelp(BuildContext context) {
    Navigator.of(context).pushNamed(
      '/help',
      arguments: {'context': this.context},
    );
  }

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
