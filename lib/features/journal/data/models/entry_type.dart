import 'package:flutter/material.dart';

/// Types of journal entries available
enum JournalEntryType {
  /// General notes and thoughts
  note,

  /// Something noticed or observed in the field
  observation,

  /// Potential discovery or find
  find,

  /// Hunt theory or clue interpretation
  theory,

  /// Memorable moment or highlight
  highlight,

  /// Auto-generated milestone (session start, state crossing, etc.)
  milestone;

  /// Display name for the entry type
  String get displayName {
    switch (this) {
      case JournalEntryType.note:
        return 'Note';
      case JournalEntryType.observation:
        return 'Observation';
      case JournalEntryType.find:
        return 'Find';
      case JournalEntryType.theory:
        return 'Theory';
      case JournalEntryType.highlight:
        return 'Highlight';
      case JournalEntryType.milestone:
        return 'Milestone';
    }
  }

  /// Icon for the entry type
  IconData get icon {
    switch (this) {
      case JournalEntryType.note:
        return Icons.edit_note;
      case JournalEntryType.observation:
        return Icons.visibility;
      case JournalEntryType.find:
        return Icons.diamond;
      case JournalEntryType.theory:
        return Icons.lightbulb;
      case JournalEntryType.highlight:
        return Icons.star;
      case JournalEntryType.milestone:
        return Icons.flag;
    }
  }

  /// Color associated with the entry type
  Color get color {
    switch (this) {
      case JournalEntryType.note:
        return const Color(0xFF00BCD4); // Cyan
      case JournalEntryType.observation:
        return const Color(0xFF2196F3); // Blue
      case JournalEntryType.find:
        return const Color(0xFFD4AF37); // Gold
      case JournalEntryType.theory:
        return const Color(0xFFFF9800); // Orange/Amber
      case JournalEntryType.highlight:
        return const Color(0xFFE91E63); // Pink
      case JournalEntryType.milestone:
        return const Color(0xFF4CAF50); // Green
    }
  }

  /// Whether this entry type can be created manually by users
  bool get isUserCreatable {
    switch (this) {
      case JournalEntryType.milestone:
        return false; // Auto-generated only
      default:
        return true;
    }
  }

  /// Parse from string (for database)
  static JournalEntryType fromString(String value) {
    return JournalEntryType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => JournalEntryType.note,
    );
  }
}
