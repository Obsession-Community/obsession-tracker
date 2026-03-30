import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/bff_app_config.dart';
import 'package:obsession_tracker/core/providers/announcements_provider.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:url_launcher/url_launcher.dart';

/// Page showing all announcements including dismissed ones
/// Allows users to reference past announcements they may have dismissed
class AnnouncementsHistoryPage extends ConsumerWidget {
  const AnnouncementsHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(announcementsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Announcements'),
            if (state.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.unreadCount} new',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          if (state.unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: () {
                ref.read(announcementsProvider.notifier).markAllAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All announcements marked as read'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Mark all as read',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(announcementsProvider.notifier).refresh();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing announcements...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.announcements.isEmpty
              ? _buildEmptyState(context)
              : _buildAnnouncementsList(context, ref, state, theme),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: context.responsivePadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No Announcements',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for updates and news.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementsList(
    BuildContext context,
    WidgetRef ref,
    AnnouncementsState state,
    ThemeData theme,
  ) {
    // Separate into sections
    final unreadAnnouncements = state.unreadAnnouncements;
    final readAnnouncements = state.readAnnouncements;
    final dismissedAnnouncements = state.announcements
        .where((a) => state.dismissedIds.contains(a.id) || a.isExpired)
        .toList();

    return ListView(
      padding: context.responsivePadding,
      children: [
        // Unread section
        if (unreadAnnouncements.isNotEmpty) ...[
          _buildSectionHeader(context, 'New', unreadAnnouncements.length, isNew: true),
          ...unreadAnnouncements.map((a) => _AnnouncementHistoryTile(
                announcement: a,
                isDismissed: false,
                isUnread: true,
              )),
          const SizedBox(height: 24),
        ],

        // Read (but not dismissed) section
        if (readAnnouncements.isNotEmpty) ...[
          _buildSectionHeader(context, 'Read', readAnnouncements.length),
          ...readAnnouncements.map((a) => _AnnouncementHistoryTile(
                announcement: a,
                isDismissed: false,
                isUnread: false,
              )),
          const SizedBox(height: 24),
        ],

        // Dismissed/expired section
        if (dismissedAnnouncements.isNotEmpty) ...[
          _buildSectionHeader(context, 'Dismissed / Expired', dismissedAnnouncements.length),
          ...dismissedAnnouncements.map((a) => _AnnouncementHistoryTile(
                announcement: a,
                isDismissed: true,
                isUnread: false,
              )),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count, {bool isNew = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (isNew) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title.toUpperCase(),
            style: theme.textTheme.titleSmall?.copyWith(
                  color: isNew ? colorScheme.primary : colorScheme.outline,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isNew ? colorScheme.primary : colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                    color: isNew ? colorScheme.onPrimary : colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementHistoryTile extends ConsumerWidget {
  final Announcement announcement;
  final bool isDismissed;
  final bool isUnread;

  const _AnnouncementHistoryTile({
    required this.announcement,
    required this.isDismissed,
    required this.isUnread,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isDismissed
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : _getBackgroundColor(context),
      elevation: isUnread ? 2 : 0,
      child: InkWell(
        onTap: () {
          // Mark as read when tapped
          if (isUnread) {
            ref.read(announcementsProvider.notifier).markAsRead(announcement.id);
          }
          // Handle action if present
          if (announcement.hasAction) {
            _handleAction(context);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                            // Unread indicator dot
                            if (isUnread) ...[
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                            Expanded(
                              child: Text(
                                announcement.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                  color: isDismissed
                                      ? colorScheme.outline
                                      : null,
                                ),
                              ),
                            ),
                            if (announcement.priority == AnnouncementPriority.high && !isDismissed)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                            if (announcement.isExpired)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.outline,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'EXPIRED',
                                  style: TextStyle(
                                    color: colorScheme.surface,
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
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDismissed ? colorScheme.outline : null,
                            fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Action button and restore option
              if (announcement.hasAction || isDismissed) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isDismissed && !announcement.isExpired)
                      TextButton.icon(
                        onPressed: () {
                          ref.read(announcementsProvider.notifier).restore(announcement.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Announcement restored'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.restore, size: 16),
                        label: const Text('Restore'),
                      ),
                    if (announcement.hasAction)
                      TextButton.icon(
                        onPressed: () => _handleAction(context),
                        icon: Icon(_getActionIcon(), size: 16),
                        label: Text(_getActionLabel()),
                      ),
                  ],
                ),
              ],
            ],
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
    final iconColor = isDismissed
        ? Theme.of(context).colorScheme.outline
        : _getIconColor(context);

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
