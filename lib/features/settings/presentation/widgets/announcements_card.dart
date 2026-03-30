import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/bff_app_config.dart';
import 'package:obsession_tracker/core/providers/announcements_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Card displaying in-app announcements with support for dismissal
class AnnouncementsCard extends ConsumerWidget {
  const AnnouncementsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(announcementsProvider);

    if (state.isLoading || !state.hasAnnouncements) {
      return const SizedBox.shrink();
    }

    final announcements = state.visibleAnnouncements;
    if (announcements.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'ANNOUNCEMENTS',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${announcements.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const Spacer(),
              if (announcements.length > 1)
                TextButton(
                  onPressed: () => _showDismissAllDialog(context, ref),
                  child: const Text('Dismiss All'),
                ),
            ],
          ),
        ),
        ...announcements.map((a) => _AnnouncementTile(announcement: a)),
        const SizedBox(height: 8),
        const Divider(),
      ],
    );
  }

  void _showDismissAllDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dismiss All?'),
        content: const Text('Are you sure you want to dismiss all announcements?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(announcementsProvider.notifier).dismissAll();
              Navigator.of(context).pop();
            },
            child: const Text('Dismiss All'),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementTile extends ConsumerWidget {
  final Announcement announcement;

  const _AnnouncementTile({required this.announcement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key('announcement_${announcement.id}'),
      direction: announcement.dismissible
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        color: colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.close, color: colorScheme.onError),
      ),
      onDismissed: (_) {
        ref.read(announcementsProvider.notifier).dismiss(announcement.id);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: _getBackgroundColor(context),
        child: InkWell(
          onTap: announcement.hasAction ? () => _handleAction(context) : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIcon(context),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              announcement.title,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          if (announcement.priority == AnnouncementPriority.high)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.error,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'IMPORTANT',
                                style: TextStyle(
                                  color: colorScheme.onError,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        announcement.message,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (announcement.hasAction) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              _getActionLabel(),
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _getActionIcon(),
                              size: 16,
                              color: colorScheme.primary,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (announcement.dismissible)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      ref.read(announcementsProvider.notifier).dismiss(announcement.id);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (announcement.type) {
      case AnnouncementType.critical:
        return colorScheme.errorContainer;
      case AnnouncementType.maintenance:
      case AnnouncementType.warning:
        return Colors.orange.withValues(alpha: 0.15);
      case AnnouncementType.treasureFound:
        return Colors.amber.withValues(alpha: 0.15);
      case AnnouncementType.newHunt:
      case AnnouncementType.huntUpdate:
        return Colors.green.withValues(alpha: 0.15);
      case AnnouncementType.appUpdate:
        return colorScheme.primaryContainer.withValues(alpha: 0.5);
      case AnnouncementType.landData:
        return Colors.blue.withValues(alpha: 0.15);
      default:
        return colorScheme.surfaceContainerHighest;
    }
  }

  Widget _buildIcon(BuildContext context) {
    final iconData = _getIconData();
    final iconColor = _getIconColor(context);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: iconColor, size: 24),
    );
  }

  IconData _getIconData() {
    switch (announcement.type) {
      case AnnouncementType.critical:
        return Icons.error;
      case AnnouncementType.maintenance:
        return Icons.build;
      case AnnouncementType.warning:
        return Icons.warning;
      case AnnouncementType.treasureFound:
        return Icons.emoji_events;
      case AnnouncementType.newHunt:
        return Icons.search;
      case AnnouncementType.huntUpdate:
        return Icons.update;
      case AnnouncementType.appUpdate:
        return Icons.system_update;
      case AnnouncementType.landData:
        return Icons.map;
      case AnnouncementType.info:
        return Icons.info;
      default:
        return Icons.campaign;
    }
  }

  Color _getIconColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (announcement.type) {
      case AnnouncementType.critical:
        return colorScheme.error;
      case AnnouncementType.maintenance:
      case AnnouncementType.warning:
        return Colors.orange;
      case AnnouncementType.treasureFound:
        return Colors.amber.shade700;
      case AnnouncementType.newHunt:
      case AnnouncementType.huntUpdate:
        return Colors.green;
      case AnnouncementType.appUpdate:
        return colorScheme.primary;
      case AnnouncementType.landData:
        return Colors.blue;
      default:
        return colorScheme.primary;
    }
  }

  String _getActionLabel() {
    final action = announcement.action;
    if (action == null) return '';

    switch (action.type) {
      case AnnouncementActionType.openUrl:
        return 'Learn More';
      case AnnouncementActionType.openHunt:
        return 'View Hunt';
      case AnnouncementActionType.openAppStore:
        return 'Update Now';
      default:
        return 'View';
    }
  }

  IconData _getActionIcon() {
    final action = announcement.action;
    if (action == null) return Icons.arrow_forward;

    switch (action.type) {
      case AnnouncementActionType.openUrl:
        return Icons.open_in_new;
      case AnnouncementActionType.openHunt:
        return Icons.arrow_forward;
      case AnnouncementActionType.openAppStore:
        return Icons.download;
      default:
        return Icons.arrow_forward;
    }
  }

  Future<void> _handleAction(BuildContext context) async {
    final action = announcement.action;
    if (action == null) return;

    switch (action.type) {
      case AnnouncementActionType.openUrl:
        final uri = Uri.tryParse(action.value);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        break;
      case AnnouncementActionType.openHunt:
        // TODO(dev): Navigate to hunt detail page using huntId
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Open hunt: ${action.value}')),
        );
        break;
      case AnnouncementActionType.openAppStore:
        final uri = Uri.tryParse(action.value);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        break;
      default:
        break;
    }
  }
}
