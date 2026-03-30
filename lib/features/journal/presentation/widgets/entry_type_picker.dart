import 'package:flutter/material.dart';
import 'package:obsession_tracker/features/journal/data/models/entry_type.dart';

/// Widget for selecting journal entry type
class EntryTypePicker extends StatelessWidget {
  const EntryTypePicker({
    required this.selectedType,
    required this.onTypeSelected,
    this.showMilestone = false,
    super.key,
  });

  final JournalEntryType selectedType;
  final ValueChanged<JournalEntryType> onTypeSelected;

  /// Whether to show the milestone type (usually only for auto-generated entries)
  final bool showMilestone;

  @override
  Widget build(BuildContext context) {
    final types = JournalEntryType.values
        .where((type) => showMilestone || type.isUserCreatable)
        .toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types.map((type) {
          final isSelected = type == selectedType;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _EntryTypeChip(
              type: type,
              isSelected: isSelected,
              onTap: () => onTypeSelected(type),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EntryTypeChip extends StatelessWidget {
  const _EntryTypeChip({
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
    final typeColor = type.color;

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
                ? typeColor.withValues(alpha: 0.2)
                : isDark
                    ? Colors.grey.shade800
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? typeColor
                  : isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                type.icon,
                size: 18,
                color: isSelected
                    ? typeColor
                    : isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                type.displayName,
                style: TextStyle(
                  color: isSelected
                      ? typeColor
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

/// Compact version of entry type picker for forms
class EntryTypeDropdown extends StatelessWidget {
  const EntryTypeDropdown({
    required this.selectedType,
    required this.onTypeSelected,
    this.showMilestone = false,
    super.key,
  });

  final JournalEntryType selectedType;
  final ValueChanged<JournalEntryType> onTypeSelected;
  final bool showMilestone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final types = JournalEntryType.values
        .where((type) => showMilestone || type.isUserCreatable)
        .toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<JournalEntryType>(
          value: selectedType,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          dropdownColor: isDark ? Colors.grey.shade800 : Colors.white,
          items: types.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Row(
                children: [
                  Icon(type.icon, color: type.color, size: 20),
                  const SizedBox(width: 12),
                  Text(type.displayName),
                ],
              ),
            );
          }).toList(),
          onChanged: (type) {
            if (type != null) {
              onTypeSelected(type);
            }
          },
        ),
      ),
    );
  }
}
