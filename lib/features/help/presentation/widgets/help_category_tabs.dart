import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/help_models.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';

/// Tab bar widget for help content categories
class HelpCategoryTabs extends StatelessWidget {
  const HelpCategoryTabs({
    required this.controller,
    super.key,
    this.onTypeChanged,
  });

  final TabController controller;
  final ValueChanged<HelpContentType>? onTypeChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          onTap: (index) {
            if (onTypeChanged != null) {
              onTypeChanged!(HelpContentType.values[index]);
            }
          },
          labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: context.isTablet ? 14 : 13,
              ),
          unselectedLabelStyle:
              Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.normal,
                    fontSize: context.isTablet ? 14 : 13,
                  ),
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.outline,
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorWeight: 3,
          padding: EdgeInsets.symmetric(horizontal: context.isTablet ? 16 : 8),
          tabs: HelpContentType.values
              .map((type) => Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getTypeIcon(type),
                          size: context.isTablet ? 20 : 18,
                        ),
                        const SizedBox(width: 6),
                        Text(_getTypeLabel(type)),
                      ],
                    ),
                  ))
              .toList(),
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

  String _getTypeLabel(HelpContentType type) {
    switch (type) {
      case HelpContentType.tutorial:
        return 'Tutorials';
      case HelpContentType.guide:
        return 'Guides';
      case HelpContentType.faq:
        return 'FAQ';
      case HelpContentType.troubleshooting:
        return 'Troubleshooting';
      case HelpContentType.documentation:
        return 'Docs';
      case HelpContentType.video:
        return 'Videos';
      case HelpContentType.interactive:
        return 'Interactive';
      case HelpContentType.quickTip:
        return 'Tips';
    }
  }
}
