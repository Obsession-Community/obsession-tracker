import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/treasure_hunt.dart';
import 'package:obsession_tracker/core/providers/hunt_provider.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:obsession_tracker/features/journal/data/models/entry_type.dart';
import 'package:obsession_tracker/features/journal/data/models/journal_entry.dart';
import 'package:obsession_tracker/features/journal/data/models/mood.dart';
import 'package:obsession_tracker/features/journal/presentation/widgets/entry_type_picker.dart';
import 'package:obsession_tracker/features/journal/presentation/widgets/mood_selector.dart';
import 'package:obsession_tracker/features/journal/presentation/widgets/relationship_chips.dart';
import 'package:obsession_tracker/features/journal/providers/journal_providers.dart';

/// Result returned from the journal entry page
class JournalEntryResult {
  const JournalEntryResult({
    required this.saved,
    this.entry,
  });

  final bool saved;
  final JournalEntry? entry;

  factory JournalEntryResult.saved(JournalEntry entry) => JournalEntryResult(
        saved: true,
        entry: entry,
      );

  factory JournalEntryResult.cancelled() => const JournalEntryResult(
        saved: false,
      );
}

/// Page for creating or editing a journal entry
class JournalEntryPage extends ConsumerStatefulWidget {
  const JournalEntryPage({
    this.existingEntry,
    this.initialSession,
    this.initialHunt,
    this.initialLatitude,
    this.initialLongitude,
    this.initialLocationName,
    super.key,
  });

  /// Existing entry to edit (null for new entry)
  final JournalEntry? existingEntry;

  /// Pre-linked session (for quick entry during tracking)
  final TrackingSession? initialSession;

  /// Pre-linked hunt
  final TreasureHunt? initialHunt;

  /// Pre-set location
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialLocationName;

  bool get isEditing => existingEntry != null;

  @override
  ConsumerState<JournalEntryPage> createState() => _JournalEntryPageState();
}

class _JournalEntryPageState extends ConsumerState<JournalEntryPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _weatherController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();

  bool _isSaving = false;

  // Entry state
  late JournalEntryType _entryType;
  JournalMood? _mood;
  String? _sessionId;
  String? _huntId;
  double? _latitude;
  double? _longitude;
  String? _locationName;
  bool _isPinned = false;
  bool _isHighlight = false;

  // Cached references for display
  TrackingSession? _linkedSession;
  TreasureHunt? _linkedHunt;

  @override
  void initState() {
    super.initState();

    if (widget.isEditing) {
      // Editing existing entry
      final entry = widget.existingEntry!;
      _titleController.text = entry.title ?? '';
      _contentController.text = entry.content;
      _weatherController.text = entry.weatherNotes ?? '';
      _entryType = entry.entryType;
      _mood = entry.mood;
      _sessionId = entry.sessionId;
      _huntId = entry.huntId;
      _latitude = entry.latitude;
      _longitude = entry.longitude;
      _locationName = entry.locationName;
      _isPinned = entry.isPinned;
      _isHighlight = entry.isHighlight;
    } else {
      // New entry
      _entryType = JournalEntryType.note;
      _sessionId = widget.initialSession?.id;
      _linkedSession = widget.initialSession;
      _huntId = widget.initialHunt?.id;
      _linkedHunt = widget.initialHunt;
      _latitude = widget.initialLatitude;
      _longitude = widget.initialLongitude;
      _locationName = widget.initialLocationName;
    }

    // Auto-focus content field for new entries
    if (!widget.isEditing) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _contentFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _weatherController.dispose();
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
      JournalEntry? result;

      if (widget.isEditing) {
        // Update existing entry
        final updated = widget.existingEntry!.copyWith(
          title: _titleController.text.trim().isEmpty
              ? null
              : _titleController.text.trim(),
          content: content,
          entryType: _entryType,
          mood: _mood,
          weatherNotes: _weatherController.text.trim().isEmpty
              ? null
              : _weatherController.text.trim(),
          isPinned: _isPinned,
          isHighlight: _isHighlight,
        );

        final success = await journalNotifier.updateEntry(updated);
        if (success) {
          result = updated;
        }
      } else {
        // Create new entry
        result = await journalNotifier.createEntry(
          content: content,
          title: _titleController.text.trim().isEmpty
              ? null
              : _titleController.text.trim(),
          entryType: _entryType,
          sessionId: _sessionId,
          huntId: _huntId,
          latitude: _latitude,
          longitude: _longitude,
          locationName: _locationName,
          mood: _mood,
          weatherNotes: _weatherController.text.trim().isEmpty
              ? null
              : _weatherController.text.trim(),
          isPinned: _isPinned,
          isHighlight: _isHighlight,
        );
      }

      if (result != null && mounted) {
        Navigator.of(context).pop(JournalEntryResult.saved(result));
      } else if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save journal entry'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving journal entry: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancel() {
    Navigator.of(context).pop(JournalEntryResult.cancelled());
  }

  Future<void> _showHuntPicker() async {
    final huntsAsync = ref.read(huntProvider);
    final hunts = huntsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => <TreasureHunt>[],
    );

    if (hunts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hunts available')),
      );
      return;
    }

    final selected = await showModalBottomSheet<TreasureHunt>(
      context: context,
      builder: (context) => _HuntPickerSheet(hunts: hunts),
    );

    if (selected != null) {
      setState(() {
        _huntId = selected.id;
        _linkedHunt = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Get linked hunt if we have huntId but no cached hunt
    if (_huntId != null && _linkedHunt == null) {
      _linkedHunt = ref.watch(huntByIdProvider(_huntId!));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Entry' : 'New Entry'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancel,
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: isDark ? Colors.white : theme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: context.responsivePadding,
          child: ResponsiveContentBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Entry type picker
              Text(
                'Type',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              EntryTypePicker(
                selectedType: _entryType,
                onTypeSelected: (type) {
                  setState(() {
                    _entryType = type;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Title field (optional)
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title (optional)',
                  hintText: 'Give this entry a title...',
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: const Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 16),

              // Content field
              TextField(
                controller: _contentController,
                focusNode: _contentFocusNode,
                maxLines: 6,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  labelText: 'Content',
                  hintText: "What's on your mind?",
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 20),

              // Relationship chips (only for new entries, editing doesn't change relationships)
              if (!widget.isEditing) ...[
                Text(
                  'Link to (optional)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                RelationshipChips(
                  session: _linkedSession,
                  hunt: _linkedHunt,
                  locationName: _locationName,
                  hasLocation: _latitude != null && _longitude != null,
                  onRemoveSession: () {
                    setState(() {
                      _sessionId = null;
                      _linkedSession = null;
                    });
                  },
                  onAddHunt: _showHuntPicker,
                  onRemoveHunt: () {
                    setState(() {
                      _huntId = null;
                      _linkedHunt = null;
                    });
                  },
                  onRemoveLocation: () {
                    setState(() {
                      _latitude = null;
                      _longitude = null;
                      _locationName = null;
                    });
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Mood selector
              Text(
                'Mood (optional)',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              MoodSelector(
                selectedMood: _mood,
                onMoodSelected: (mood) {
                  setState(() {
                    _mood = mood;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Weather notes (optional)
              TextField(
                controller: _weatherController,
                decoration: InputDecoration(
                  labelText: 'Weather notes (optional)',
                  hintText: 'Sunny, light breeze...',
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: const Icon(Icons.cloud),
                ),
              ),
              const SizedBox(height: 20),

              // Pin and highlight toggles
              Row(
                children: [
                  Expanded(
                    child: _ToggleOption(
                      icon: Icons.push_pin,
                      label: 'Pin to top',
                      value: _isPinned,
                      onChanged: (value) {
                        setState(() {
                          _isPinned = value;
                        });
                      },
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ToggleOption(
                      icon: Icons.star,
                      label: 'Highlight',
                      value: _isHighlight,
                      onChanged: (value) {
                        setState(() {
                          _isHighlight = value;
                        });
                      },
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: value
                ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
                : isDark
                    ? Colors.grey.shade800
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value
                  ? const Color(0xFFD4AF37)
                  : isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: value
                    ? const Color(0xFFD4AF37)
                    : isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: value
                      ? const Color(0xFFD4AF37)
                      : isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                  fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for picking a hunt to link
class _HuntPickerSheet extends StatelessWidget {
  const _HuntPickerSheet({required this.hunts});

  final List<TreasureHunt> hunts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Link to Hunt',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: hunts.length,
              itemBuilder: (context, index) {
                final hunt = hunts[index];
                return ListTile(
                  leading: const Icon(
                    Icons.explore,
                    color: Color(0xFFD4AF37),
                  ),
                  title: Text(hunt.name),
                  subtitle: hunt.description != null
                      ? Text(
                          hunt.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(hunt),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
