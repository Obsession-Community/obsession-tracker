import 'package:flutter/material.dart';
import 'package:obsession_tracker/features/journal/data/models/mood.dart';

/// Widget for selecting mood for a journal entry
class MoodSelector extends StatelessWidget {
  const MoodSelector({
    required this.selectedMood,
    required this.onMoodSelected,
    super.key,
  });

  final JournalMood? selectedMood;
  final ValueChanged<JournalMood?> onMoodSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // "None" option
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _MoodChip(
              mood: null,
              isSelected: selectedMood == null,
              onTap: () => onMoodSelected(null),
            ),
          ),
          // All mood options
          ...JournalMood.values.map((mood) {
            final isSelected = mood == selectedMood;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _MoodChip(
                mood: mood,
                isSelected: isSelected,
                onTap: () => onMoodSelected(mood),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({
    required this.mood,
    required this.isSelected,
    required this.onTap,
  });

  final JournalMood? mood;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final moodColor = mood?.color ?? Colors.grey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? moodColor.withValues(alpha: 0.2)
                : isDark
                    ? Colors.grey.shade800
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? moodColor
                  : isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mood != null) ...[
                Text(
                  mood!.emoji,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                mood?.displayName ?? 'None',
                style: TextStyle(
                  color: isSelected
                      ? moodColor
                      : isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact dropdown version of mood selector
class MoodDropdown extends StatelessWidget {
  const MoodDropdown({
    required this.selectedMood,
    required this.onMoodSelected,
    super.key,
  });

  final JournalMood? selectedMood;
  final ValueChanged<JournalMood?> onMoodSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<JournalMood?>(
          value: selectedMood,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          dropdownColor: isDark ? Colors.grey.shade800 : Colors.white,
          hint: const Text('Select mood (optional)'),
          items: [
            const DropdownMenuItem<JournalMood?>(
              child: Text('None'),
            ),
            ...JournalMood.values.map((mood) {
              return DropdownMenuItem(
                value: mood,
                child: Row(
                  children: [
                    Text(mood.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Text(mood.displayName),
                  ],
                ),
              );
            }),
          ],
          onChanged: onMoodSelected,
        ),
      ),
    );
  }
}

/// Grid layout for mood selection (good for bottom sheets)
class MoodGrid extends StatelessWidget {
  const MoodGrid({
    required this.selectedMood,
    required this.onMoodSelected,
    super.key,
  });

  final JournalMood? selectedMood;
  final ValueChanged<JournalMood?> onMoodSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: JournalMood.values.map((mood) {
        final isSelected = mood == selectedMood;
        return _MoodGridItem(
          mood: mood,
          isSelected: isSelected,
          onTap: () => onMoodSelected(isSelected ? null : mood),
        );
      }).toList(),
    );
  }
}

class _MoodGridItem extends StatelessWidget {
  const _MoodGridItem({
    required this.mood,
    required this.isSelected,
    required this.onTap,
  });

  final JournalMood mood;
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
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? mood.color.withValues(alpha: 0.2)
                : isDark
                    ? Colors.grey.shade800
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? mood.color
                  : isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mood.emoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(height: 4),
              Text(
                mood.displayName,
                style: TextStyle(
                  color: isSelected
                      ? mood.color
                      : isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
