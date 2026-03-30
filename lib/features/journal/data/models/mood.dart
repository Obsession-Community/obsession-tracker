import 'package:flutter/material.dart';

/// Mood options for journal entries
enum JournalMood {
  /// Feeling excited and energized
  excited,

  /// Feeling curious and interested
  curious,

  /// Feeling satisfied and content
  satisfied,

  /// Feeling frustrated or stuck
  frustrated,

  /// Feeling determined and focused
  determined,

  /// Feeling peaceful and calm
  peaceful;

  /// Display name for the mood
  String get displayName {
    switch (this) {
      case JournalMood.excited:
        return 'Excited';
      case JournalMood.curious:
        return 'Curious';
      case JournalMood.satisfied:
        return 'Satisfied';
      case JournalMood.frustrated:
        return 'Frustrated';
      case JournalMood.determined:
        return 'Determined';
      case JournalMood.peaceful:
        return 'Peaceful';
    }
  }

  /// Emoji for the mood
  String get emoji {
    switch (this) {
      case JournalMood.excited:
        return '\u{1F604}'; // Grinning face with smiling eyes
      case JournalMood.curious:
        return '\u{1F914}'; // Thinking face
      case JournalMood.satisfied:
        return '\u{1F60A}'; // Smiling face with smiling eyes
      case JournalMood.frustrated:
        return '\u{1F615}'; // Confused face
      case JournalMood.determined:
        return '\u{1F4AA}'; // Flexed bicep
      case JournalMood.peaceful:
        return '\u{1F60C}'; // Relieved face
    }
  }

  /// Icon for the mood (as fallback)
  IconData get icon {
    switch (this) {
      case JournalMood.excited:
        return Icons.sentiment_very_satisfied;
      case JournalMood.curious:
        return Icons.psychology;
      case JournalMood.satisfied:
        return Icons.sentiment_satisfied;
      case JournalMood.frustrated:
        return Icons.sentiment_dissatisfied;
      case JournalMood.determined:
        return Icons.fitness_center;
      case JournalMood.peaceful:
        return Icons.spa;
    }
  }

  /// Color associated with the mood
  Color get color {
    switch (this) {
      case JournalMood.excited:
        return const Color(0xFFFF9800); // Orange
      case JournalMood.curious:
        return const Color(0xFF2196F3); // Blue
      case JournalMood.satisfied:
        return const Color(0xFF4CAF50); // Green
      case JournalMood.frustrated:
        return const Color(0xFFF44336); // Red
      case JournalMood.determined:
        return const Color(0xFF9C27B0); // Purple
      case JournalMood.peaceful:
        return const Color(0xFF00BCD4); // Cyan
    }
  }

  /// Parse from string (for database)
  static JournalMood? fromString(String? value) {
    if (value == null) return null;
    return JournalMood.values.firstWhere(
      (e) => e.name == value,
      orElse: () => JournalMood.satisfied,
    );
  }
}
