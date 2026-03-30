import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:obsession_tracker/features/journal/data/models/journal_entry.dart';
import 'package:obsession_tracker/features/journal/presentation/widgets/relationship_chips.dart';

/// Card widget displaying a journal entry in a list
class JournalEntryCard extends StatelessWidget {
  const JournalEntryCard({
    required this.entry,
    this.onTap,
    this.onLongPress,
    this.showRelationships = true,
    super.key,
  });

  final JournalEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showRelationships;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final typeColor = entry.entryType.color;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: entry.isPinned
            ? BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.5))
            : BorderSide.none,
      ),
      color: isDark ? Colors.grey.shade900 : Colors.white,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: type icon, title/type, mood, pin/highlight
              Row(
                children: [
                  // Type icon with colored background
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      entry.entryType.icon,
                      size: 18,
                      color: typeColor,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Title or entry type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title ?? entry.entryType.displayName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (entry.title != null)
                          Text(
                            entry.entryType.displayName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: typeColor,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Mood emoji
                  if (entry.mood != null) ...[
                    Text(
                      entry.mood!.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Pin indicator
                  if (entry.isPinned)
                    const Icon(
                      Icons.push_pin,
                      size: 16,
                      color: Color(0xFFD4AF37),
                    ),

                  // Highlight indicator
                  if (entry.isHighlight)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.star,
                        size: 16,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // Content preview
              Text(
                entry.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 10),

              // Footer row: relationships, time
              Row(
                children: [
                  // Relationship icons
                  if (showRelationships)
                    RelationshipIcons(
                      hasSession: entry.hasSession,
                      hasHunt: entry.hasHunt,
                      hasLocation: entry.hasLocation,
                    ),

                  const Spacer(),

                  // Timestamp
                  Text(
                    _formatTimestamp(entry.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (entryDate == today) {
      return DateFormat.jm().format(timestamp);
    } else if (entryDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat.jm().format(timestamp)}';
    } else if (now.difference(timestamp).inDays < 7) {
      return DateFormat('EEE').format(timestamp);
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
}

/// Compact version of journal entry card for inline display
class JournalEntryListTile extends StatelessWidget {
  const JournalEntryListTile({
    required this.entry,
    this.onTap,
    super.key,
  });

  final JournalEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final typeColor = entry.entryType.color;

    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: typeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          entry.entryType.icon,
          size: 20,
          color: typeColor,
        ),
      ),
      title: Text(
        entry.title ?? entry.entryType.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        entry.content,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.mood != null) Text(entry.mood!.emoji),
          if (entry.isPinned)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.push_pin, size: 16, color: Color(0xFFD4AF37)),
            ),
        ],
      ),
    );
  }
}
