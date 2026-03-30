import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'package:obsession_tracker/features/journal/data/models/entry_type.dart';
import 'package:obsession_tracker/features/journal/data/models/mood.dart';

/// A journal entry representing a thought, observation, or note.
///
/// Journal entries can optionally be linked to:
/// - A tracking session via [sessionId]
/// - A treasure hunt via [huntId]
/// - A location via [latitude] and [longitude]
///
/// All relationships are optional, allowing entries to be standalone
/// or connected to multiple contexts.
@immutable
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.content,
    required this.entryType,
    required this.timestamp,
    required this.createdAt,
    this.title,
    this.sessionId,
    this.huntId,
    this.latitude,
    this.longitude,
    this.locationName,
    this.mood,
    this.weatherNotes,
    this.tags = const [],
    this.isPinned = false,
    this.isHighlight = false,
    this.updatedAt,
  });

  /// Unique identifier for this entry
  final String id;

  /// Optional title for the entry
  final String? title;

  /// The main content/body of the entry
  final String content;

  /// Type of entry (note, observation, find, theory, highlight, milestone)
  final JournalEntryType entryType;

  /// Optional link to a tracking session
  final String? sessionId;

  /// Optional link to a treasure hunt
  final String? huntId;

  /// Optional latitude (for location-tagged entries)
  final double? latitude;

  /// Optional longitude (for location-tagged entries)
  final double? longitude;

  /// Optional human-readable location name
  final String? locationName;

  /// When this entry was recorded (user-facing timestamp)
  final DateTime timestamp;

  /// Optional mood associated with the entry
  final JournalMood? mood;

  /// Optional weather observations
  final String? weatherNotes;

  /// Optional tags for categorization
  final List<String> tags;

  /// Whether this entry is pinned to the top
  final bool isPinned;

  /// Whether this entry is marked as a highlight
  final bool isHighlight;

  /// When this entry was created in the database
  final DateTime createdAt;

  /// When this entry was last updated
  final DateTime? updatedAt;

  /// Whether this entry has a location
  bool get hasLocation => latitude != null && longitude != null;

  /// Get location as LatLng if available
  LatLng? get location =>
      hasLocation ? LatLng(latitude!, longitude!) : null;

  /// Whether this entry is linked to a session
  bool get hasSession => sessionId != null;

  /// Whether this entry is linked to a hunt
  bool get hasHunt => huntId != null;

  /// Whether this entry is standalone (no links)
  bool get isStandalone => !hasSession && !hasHunt && !hasLocation;

  /// Get display title (title or truncated content)
  String get displayTitle {
    if (title != null && title!.isNotEmpty) {
      return title!;
    }
    // Return first line or first 50 chars of content
    final firstLine = content.split('\n').first;
    if (firstLine.length <= 50) {
      return firstLine;
    }
    return '${firstLine.substring(0, 47)}...';
  }

  /// Create from database map
  factory JournalEntry.fromDatabaseMap(Map<String, dynamic> map) {
    List<String> parseTags(String? tagsJson) {
      if (tagsJson == null || tagsJson.isEmpty) return [];
      try {
        final decoded = jsonDecode(tagsJson);
        if (decoded is List) {
          return decoded.cast<String>();
        }
      } catch (_) {
        // Fall back to comma-separated
        return tagsJson.split(',').where((t) => t.isNotEmpty).toList();
      }
      return [];
    }

    return JournalEntry(
      id: map['id'] as String,
      title: map['title'] as String?,
      content: map['content'] as String,
      entryType: JournalEntryType.fromString(map['entry_type'] as String),
      sessionId: map['session_id'] as String?,
      huntId: map['hunt_id'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      locationName: map['location_name'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      mood: JournalMood.fromString(map['mood'] as String?),
      weatherNotes: map['weather_notes'] as String?,
      tags: parseTags(map['tags'] as String?),
      isPinned: (map['is_pinned'] as int?) == 1,
      isHighlight: (map['is_highlight'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : null,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'entry_type': entryType.name,
      'session_id': sessionId,
      'hunt_id': huntId,
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'mood': mood?.name,
      'weather_notes': weatherNotes,
      'tags': tags.isNotEmpty ? jsonEncode(tags) : null,
      'is_pinned': isPinned ? 1 : 0,
      'is_highlight': isHighlight ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

  /// Create a copy with updated values
  JournalEntry copyWith({
    String? id,
    String? title,
    String? content,
    JournalEntryType? entryType,
    String? sessionId,
    String? huntId,
    double? latitude,
    double? longitude,
    String? locationName,
    DateTime? timestamp,
    JournalMood? mood,
    String? weatherNotes,
    List<String>? tags,
    bool? isPinned,
    bool? isHighlight,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      entryType: entryType ?? this.entryType,
      sessionId: sessionId ?? this.sessionId,
      huntId: huntId ?? this.huntId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      timestamp: timestamp ?? this.timestamp,
      mood: mood ?? this.mood,
      weatherNotes: weatherNotes ?? this.weatherNotes,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      isHighlight: isHighlight ?? this.isHighlight,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create a copy with session relationship cleared
  JournalEntry clearSession() => JournalEntry(
        id: id,
        title: title,
        content: content,
        entryType: entryType,
        huntId: huntId,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
        timestamp: timestamp,
        mood: mood,
        weatherNotes: weatherNotes,
        tags: tags,
        isPinned: isPinned,
        isHighlight: isHighlight,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  /// Create a copy with hunt relationship cleared
  JournalEntry clearHunt() => JournalEntry(
        id: id,
        title: title,
        content: content,
        entryType: entryType,
        sessionId: sessionId,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
        timestamp: timestamp,
        mood: mood,
        weatherNotes: weatherNotes,
        tags: tags,
        isPinned: isPinned,
        isHighlight: isHighlight,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  /// Create a copy with location cleared
  JournalEntry clearLocation() => JournalEntry(
        id: id,
        title: title,
        content: content,
        entryType: entryType,
        sessionId: sessionId,
        huntId: huntId,
        timestamp: timestamp,
        mood: mood,
        weatherNotes: weatherNotes,
        tags: tags,
        isPinned: isPinned,
        isHighlight: isHighlight,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'JournalEntry{id: $id, type: ${entryType.displayName}, title: $displayTitle}';
}
