import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/treasure_hunt.dart';
import 'package:obsession_tracker/features/journal/data/models/entry_type.dart';
import 'package:obsession_tracker/features/journal/data/models/journal_entry.dart';
import 'package:obsession_tracker/features/journal/providers/journal_providers.dart';

/// Quick entry FAB for adding journal entries during tracking
/// Shows a mini form that slides up for fast capture in the field
class QuickEntryFAB extends ConsumerWidget {
  const QuickEntryFAB({
    required this.session,
    this.hunt,
    this.currentLatitude,
    this.currentLongitude,
    this.locationName,
    this.onEntrySaved,
    super.key,
  });

  final TrackingSession session;
  final TreasureHunt? hunt;
  final double? currentLatitude;
  final double? currentLongitude;
  final String? locationName;
  final ValueChanged<JournalEntry>? onEntrySaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      heroTag: 'quick_journal_fab',
      onPressed: () => _showQuickEntrySheet(context, ref),
      backgroundColor: const Color(0xFFD4AF37),
      foregroundColor: Colors.black,
      mini: true,
      child: const Icon(Icons.edit_note),
    );
  }

  void _showQuickEntrySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<JournalEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _QuickEntrySheet(
        session: session,
        hunt: hunt,
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
        locationName: locationName,
        onSave: (entry) {
          Navigator.pop(context, entry);
          onEntrySaved?.call(entry);
        },
      ),
    );
  }
}

class _QuickEntrySheet extends ConsumerStatefulWidget {
  const _QuickEntrySheet({
    required this.session,
    required this.onSave,
    this.hunt,
    this.currentLatitude,
    this.currentLongitude,
    this.locationName,
  });

  final TrackingSession session;
  final TreasureHunt? hunt;
  final double? currentLatitude;
  final double? currentLongitude;
  final String? locationName;
  final ValueChanged<JournalEntry> onSave;

  @override
  ConsumerState<_QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends ConsumerState<_QuickEntrySheet> {
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();
  JournalEntryType _selectedType = JournalEntryType.note;
  bool _isSaving = false;
  bool _includeLocation = true;

  @override
  void initState() {
    super.initState();
    // Auto-focus content field
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _contentFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter some content'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final journalNotifier = ref.read(journalProvider.notifier);
      final entry = await journalNotifier.createEntry(
        content: content,
        entryType: _selectedType,
        sessionId: widget.session.id,
        huntId: widget.hunt?.id,
        latitude: _includeLocation ? widget.currentLatitude : null,
        longitude: _includeLocation ? widget.currentLongitude : null,
        locationName: _includeLocation ? widget.locationName : null,
      );

      if (entry != null && mounted) {
        widget.onSave(entry);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedType.displayName} saved'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save entry'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    const Icon(Icons.edit_note, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 8),
                    Text(
                      'Quick Entry',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Session indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.route,
                            size: 14,
                            color: Color(0xFF4CAF50),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Tracking',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quick type selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: JournalEntryType.values
                        .where((t) => t.isUserCreatable)
                        .map((type) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _QuickTypeChip(
                                type: type,
                                isSelected: type == _selectedType,
                                onTap: () {
                                  setState(() {
                                    _selectedType = type;
                                  });
                                },
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Content field
                TextField(
                  controller: _contentController,
                  focusNode: _contentFocusNode,
                  maxLines: 3,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: "What's on your mind?",
                    filled: true,
                    fillColor:
                        isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),

                // Location toggle
                if (widget.currentLatitude != null &&
                    widget.currentLongitude != null)
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: _includeLocation
                            ? const Color(0xFF2196F3)
                            : isDark
                                ? Colors.grey.shade600
                                : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.locationName ?? 'Current location',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _includeLocation
                                ? null
                                : isDark
                                    ? Colors.grey.shade600
                                    : Colors.grey.shade400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Switch.adaptive(
                        value: _includeLocation,
                        onChanged: (value) {
                          setState(() {
                            _includeLocation = value;
                          });
                        },
                        activeTrackColor: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                        activeThumbColor: const Color(0xFFD4AF37),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Save button
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickTypeChip extends StatelessWidget {
  const _QuickTypeChip({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final JournalEntryType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? type.color.withValues(alpha: 0.2)
                : isDark
                    ? Colors.grey.shade800
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? type.color
                  : isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                type.icon,
                size: 14,
                color: isSelected
                    ? type.color
                    : isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                type.displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? type.color
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
