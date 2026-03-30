import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:obsession_tracker/features/journal/data/models/entry_type.dart';
import 'package:obsession_tracker/features/journal/data/models/journal_entry.dart';
import 'package:obsession_tracker/features/journal/presentation/pages/journal_entry_page.dart';
import 'package:obsession_tracker/features/journal/presentation/widgets/journal_entry_card.dart';
import 'package:obsession_tracker/features/journal/providers/journal_providers.dart';

/// Main journal list page - shows all journal entries
class JournalListPage extends ConsumerStatefulWidget {
  const JournalListPage({super.key});

  @override
  ConsumerState<JournalListPage> createState() => _JournalListPageState();
}

class _JournalListPageState extends ConsumerState<JournalListPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openNewEntry() async {
    final result = await Navigator.of(context).push<JournalEntryResult>(
      MaterialPageRoute(
        builder: (context) => const JournalEntryPage(),
      ),
    );

    if (result?.saved == true && mounted) {
      // Entry was saved, list will auto-update via provider
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openEntry(JournalEntry entry) async {
    final result = await Navigator.of(context).push<JournalEntryResult>(
      MaterialPageRoute(
        builder: (context) => JournalEntryPage(existingEntry: entry),
      ),
    );

    if (result?.saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry updated'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showEntryOptions(JournalEntry entry) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _openEntry(entry);
              },
            ),
            ListTile(
              leading: Icon(
                entry.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              ),
              title: Text(entry.isPinned ? 'Unpin' : 'Pin to top'),
              onTap: () {
                Navigator.pop(context);
                ref.read(journalProvider.notifier).togglePin(entry.id);
              },
            ),
            ListTile(
              leading: Icon(
                entry.isHighlight ? Icons.star_border : Icons.star,
              ),
              title: Text(entry.isHighlight ? 'Remove highlight' : 'Highlight'),
              onTap: () {
                Navigator.pop(context);
                ref.read(journalProvider.notifier).toggleHighlight(entry.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(entry);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(JournalEntry entry) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text(
          'Are you sure you want to delete this journal entry? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(journalProvider.notifier).deleteEntry(entry.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Entry deleted')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final entriesAsync = ref.watch(journalProvider);
    final filter = ref.watch(journalFilterProvider);
    final filteredEntries = ref.watch(filteredJournalEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Journal'),
        actions: [
          // Filter button with indicator
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilterSheet,
              ),
              if (filter.hasActiveFilter)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4AF37),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load entries',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(journalProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (_) {
          if (filteredEntries.isEmpty) {
            return _buildEmptyState(filter.hasActiveFilter, isDark, theme);
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(journalProvider.notifier).refresh(),
            child: _buildEntryList(filteredEntries, isDark),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewEntry,
        icon: const Icon(Icons.add),
        label: const Text('New Entry'),
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildEmptyState(bool hasFilter, bool isDark, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilter ? Icons.filter_list_off : Icons.book_outlined,
            size: 64,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilter ? 'No entries match your filters' : 'No journal entries yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          if (hasFilter)
            TextButton(
              onPressed: () =>
                  ref.read(journalFilterProvider.notifier).clearFilters(),
              child: const Text('Clear filters'),
            )
          else
            Text(
              'Tap + to add your first entry',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEntryList(List<JournalEntry> entries, bool isDark) {
    // Group entries by date
    final grouped = _groupEntriesByDate(entries);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final group = grouped[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                group.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            // Entries for this date
            ...group.entries.map((entry) => JournalEntryCard(
                  entry: entry,
                  onTap: () => _openEntry(entry),
                  onLongPress: () => _showEntryOptions(entry),
                )),
          ],
        );
      },
    );
  }

  List<_DateGroup> _groupEntriesByDate(List<JournalEntry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<DateTime, List<JournalEntry>> groups = {};

    for (final entry in entries) {
      final date = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );
      groups.putIfAbsent(date, () => []).add(entry);
    }

    // Sort dates descending
    final sortedDates = groups.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return sortedDates.map((date) {
      String label;
      if (date == today) {
        label = 'Today';
      } else if (date == yesterday) {
        label = 'Yesterday';
      } else if (now.difference(date).inDays < 7) {
        label = DateFormat('EEEE').format(date);
      } else {
        label = DateFormat('MMMM d, y').format(date);
      }

      return _DateGroup(label: label, entries: groups[date]!);
    }).toList();
  }
}

class _DateGroup {
  const _DateGroup({required this.label, required this.entries});
  final String label;
  final List<JournalEntry> entries;
}

/// Filter bottom sheet
class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filter = ref.watch(journalFilterProvider);
    final filterNotifier = ref.read(journalFilterProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Filter Entries',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (filter.hasActiveFilter)
                  TextButton(
                    onPressed: () {
                      filterNotifier.clearFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('Clear all'),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Entry type filter
            Text(
              'Entry Type',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: filter.entryType == null,
                  onTap: () => filterNotifier.setEntryType(null),
                ),
                ...JournalEntryType.values
                    .where((t) => t.isUserCreatable)
                    .map((type) => _FilterChip(
                          label: type.displayName,
                          icon: type.icon,
                          color: type.color,
                          isSelected: filter.entryType == type,
                          onTap: () => filterNotifier.setEntryType(type),
                        )),
              ],
            ),
            const SizedBox(height: 16),

            // Quick filters
            Text(
              'Show only',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: 'Pinned',
                  icon: Icons.push_pin,
                  isSelected: filter.showPinnedOnly,
                  onTap: () =>
                      filterNotifier.setShowPinnedOnly(!filter.showPinnedOnly),
                ),
                _FilterChip(
                  label: 'Highlights',
                  icon: Icons.star,
                  isSelected: filter.showHighlightsOnly,
                  onTap: () => filterNotifier
                      .setShowHighlightsOnly(!filter.showHighlightsOnly),
                ),
                _FilterChip(
                  label: 'With location',
                  icon: Icons.location_on,
                  isSelected: filter.showWithLocationOnly,
                  onTap: () => filterNotifier
                      .setShowWithLocationOnly(!filter.showWithLocationOnly),
                ),
              ],
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chipColor = color ?? const Color(0xFFD4AF37);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? chipColor.withValues(alpha: 0.2)
                : isDark
                    ? Colors.grey.shade800
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? chipColor
                  : isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? chipColor
                      : isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? chipColor
                      : isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
