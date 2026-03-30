import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/treasure_hunt.dart';
import 'package:obsession_tracker/features/journal/data/models/journal_entry.dart';
import 'package:obsession_tracker/features/journal/presentation/pages/journal_entry_page.dart';
import 'package:obsession_tracker/features/journal/presentation/widgets/journal_entry_card.dart';
import 'package:obsession_tracker/features/journal/providers/journal_providers.dart';

/// Section widget showing journal entries linked to a session
class SessionJournalSection extends ConsumerWidget {
  const SessionJournalSection({
    required this.sessionId,
    this.session,
    this.maxEntries = 3,
    this.showAddButton = true,
    super.key,
  });

  final String sessionId;
  final TrackingSession? session;
  final int maxEntries;
  final bool showAddButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesForSessionProvider(sessionId));

    return _JournalSectionBase(
      title: 'Journal Entries',
      entries: entries,
      maxEntries: maxEntries,
      showAddButton: showAddButton,
      emptyMessage: 'No journal entries for this session',
      onAddEntry: () => _addEntry(context, ref),
      onViewAll: entries.length > maxEntries
          ? () => _viewAllEntries(context, ref)
          : null,
    );
  }

  Future<void> _addEntry(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<JournalEntryResult>(
      MaterialPageRoute(
        builder: (context) => JournalEntryPage(
          initialSession: session,
        ),
      ),
    );

    if (result?.saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal entry saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _viewAllEntries(BuildContext context, WidgetRef ref) {
    // Set filter to show only this session's entries and navigate to journal
    ref.read(journalFilterProvider.notifier).setSessionId(sessionId);
    // Navigate to journal tab (index 2)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

/// Section widget showing journal entries linked to a hunt
class HuntJournalSection extends ConsumerWidget {
  const HuntJournalSection({
    required this.huntId,
    this.hunt,
    this.maxEntries = 3,
    this.showAddButton = true,
    super.key,
  });

  final String huntId;
  final TreasureHunt? hunt;
  final int maxEntries;
  final bool showAddButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesForHuntProvider(huntId));

    return _JournalSectionBase(
      title: 'Journal Entries',
      entries: entries,
      maxEntries: maxEntries,
      showAddButton: showAddButton,
      emptyMessage: 'No journal entries for this hunt',
      onAddEntry: () => _addEntry(context, ref),
      onViewAll: entries.length > maxEntries
          ? () => _viewAllEntries(context, ref)
          : null,
    );
  }

  Future<void> _addEntry(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<JournalEntryResult>(
      MaterialPageRoute(
        builder: (context) => JournalEntryPage(
          initialHunt: hunt,
        ),
      ),
    );

    if (result?.saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal entry saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _viewAllEntries(BuildContext context, WidgetRef ref) {
    // Set filter to show only this hunt's entries and navigate to journal
    ref.read(journalFilterProvider.notifier).setHuntId(huntId);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

/// Base widget for journal sections
class _JournalSectionBase extends StatelessWidget {
  const _JournalSectionBase({
    required this.title,
    required this.entries,
    required this.maxEntries,
    required this.showAddButton,
    required this.emptyMessage,
    required this.onAddEntry,
    this.onViewAll,
  });

  final String title;
  final List<JournalEntry> entries;
  final int maxEntries;
  final bool showAddButton;
  final String emptyMessage;
  final VoidCallback onAddEntry;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayEntries = entries.take(maxEntries).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.book,
                size: 20,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (entries.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${entries.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (showAddButton)
                TextButton.icon(
                  onPressed: onAddEntry,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD4AF37),
                  ),
                ),
            ],
          ),
        ),

        // Entries or empty state
        if (displayEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 40,
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emptyMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (showAddButton) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onAddEntry,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Entry'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD4AF37),
                        side: const BorderSide(color: Color(0xFFD4AF37)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              ...displayEntries.map((entry) => JournalEntryListTile(
                    entry: entry,
                    onTap: () => _openEntry(context, entry),
                  )),
              if (onViewAll != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextButton(
                    onPressed: onViewAll,
                    child: Text(
                      'View all ${entries.length} entries',
                      style: const TextStyle(color: Color(0xFFD4AF37)),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _openEntry(BuildContext context, JournalEntry entry) async {
    await Navigator.of(context).push<JournalEntryResult>(
      MaterialPageRoute(
        builder: (context) => JournalEntryPage(existingEntry: entry),
      ),
    );
  }
}
