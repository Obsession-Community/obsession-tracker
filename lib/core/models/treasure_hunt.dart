import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/services/hunt_path_resolver.dart';

/// Status of a treasure hunt
enum HuntStatus {
  active,
  paused,
  solved,
  abandoned;

  String get displayName {
    switch (this) {
      case HuntStatus.active:
        return 'Active';
      case HuntStatus.paused:
        return 'Paused';
      case HuntStatus.solved:
        return 'Solved';
      case HuntStatus.abandoned:
        return 'Abandoned';
    }
  }

  String get icon {
    switch (this) {
      case HuntStatus.active:
        return '●';
      case HuntStatus.paused:
        return '○';
      case HuntStatus.solved:
        return '✓';
      case HuntStatus.abandoned:
        return '✗';
    }
  }

  int get color {
    switch (this) {
      case HuntStatus.active:
        return 0xFF4CAF50; // Green
      case HuntStatus.paused:
        return 0xFFFF9800; // Orange
      case HuntStatus.solved:
        return 0xFFD4AF37; // Gold
      case HuntStatus.abandoned:
        return 0xFF9E9E9E; // Grey
    }
  }
}

/// Type of document stored in a hunt
enum HuntDocumentType {
  pdf,
  image,
  note,
  link,
  document; // Generic documents (txt, doc, docx, csv, etc.)

  String get displayName {
    switch (this) {
      case HuntDocumentType.pdf:
        return 'PDF';
      case HuntDocumentType.image:
        return 'Image';
      case HuntDocumentType.note:
        return 'Note';
      case HuntDocumentType.link:
        return 'Link';
      case HuntDocumentType.document:
        return 'Document';
    }
  }

  String get icon {
    switch (this) {
      case HuntDocumentType.pdf:
        return '📄';
      case HuntDocumentType.image:
        return '🖼️';
      case HuntDocumentType.note:
        return '📝';
      case HuntDocumentType.link:
        return '🔗';
      case HuntDocumentType.document:
        return '📋';
    }
  }
}

/// Status of a hunt location (potential solve spot)
enum HuntLocationStatus {
  potential,
  searched,
  eliminated;

  String get displayName {
    switch (this) {
      case HuntLocationStatus.potential:
        return 'Potential';
      case HuntLocationStatus.searched:
        return 'Searched';
      case HuntLocationStatus.eliminated:
        return 'Eliminated';
    }
  }
}

/// A treasure hunt that the user is tracking
///
/// Represents a specific treasure hunt (e.g., "Beyond the Maps Edge" by Justin Posey)
/// that the user wants to organize research, documents, and sessions for.
@immutable
class TreasureHunt {
  const TreasureHunt({
    required this.id,
    required this.name,
    this.author,
    this.description,
    this.status = HuntStatus.active,
    this.coverImagePath,
    this.tags = const [],
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String? author;
  final String? description;
  final HuntStatus status;
  final String? coverImagePath;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int sortOrder;

  /// Create from database map
  ///
  /// Resolves relative file paths to absolute paths using [HuntPathResolver].
  factory TreasureHunt.fromDatabaseMap(Map<String, dynamic> map) {
    return TreasureHunt(
      id: map['id'] as String,
      name: map['name'] as String,
      author: map['author'] as String?,
      description: map['description'] as String?,
      status: HuntStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => HuntStatus.active,
      ),
      // Resolve relative path to absolute for filesystem access
      coverImagePath: HuntPathResolver.resolveFromDatabase(
        map['cover_image_path'] as String?,
      ),
      tags: map['tags'] != null
          ? (map['tags'] as String).split(',').where((t) => t.isNotEmpty).toList()
          : [],
      createdAt: DateTime.parse(map['created_at'] as String),
      startedAt: map['started_at'] != null
          ? DateTime.parse(map['started_at'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  /// Convert to database map
  ///
  /// Converts absolute file paths to relative paths for portability using [HuntPathResolver].
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'name': name,
      'author': author,
      'description': description,
      'status': status.name,
      // Store relative path for portability across iOS container changes
      'cover_image_path': HuntPathResolver.prepareForDatabase(coverImagePath),
      'tags': tags.join(','),
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'sort_order': sortOrder,
    };
  }

  TreasureHunt copyWith({
    String? id,
    String? name,
    String? author,
    String? description,
    HuntStatus? status,
    String? coverImagePath,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    int? sortOrder,
  }) {
    return TreasureHunt(
      id: id ?? this.id,
      name: name ?? this.name,
      author: author ?? this.author,
      description: description ?? this.description,
      status: status ?? this.status,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TreasureHunt &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A document, note, image, or link stored within a hunt
@immutable
class HuntDocument {
  const HuntDocument({
    required this.id,
    required this.huntId,
    required this.name,
    required this.type,
    this.filePath,
    this.url,
    this.content,
    this.thumbnailPath,
    required this.createdAt,
    this.updatedAt,
    this.sortOrder = 0,
  });

  final String id;
  final String huntId;
  final String name;
  final HuntDocumentType type;
  final String? filePath; // For local files (PDFs, images)
  final String? url; // For external links
  final String? content; // For notes (markdown content)
  final String? thumbnailPath; // For image/PDF thumbnails
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int sortOrder;

  /// Create from database map
  ///
  /// Resolves relative file paths to absolute paths using [HuntPathResolver].
  factory HuntDocument.fromDatabaseMap(Map<String, dynamic> map) {
    return HuntDocument(
      id: map['id'] as String,
      huntId: map['hunt_id'] as String,
      name: map['name'] as String,
      type: HuntDocumentType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => HuntDocumentType.note,
      ),
      // Resolve relative paths to absolute for filesystem access
      filePath: HuntPathResolver.resolveFromDatabase(map['file_path'] as String?),
      url: map['url'] as String?,
      content: map['content'] as String?,
      thumbnailPath: HuntPathResolver.resolveFromDatabase(map['thumbnail_path'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  /// Convert to database map
  ///
  /// Converts absolute file paths to relative paths for portability using [HuntPathResolver].
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'hunt_id': huntId,
      'name': name,
      'type': type.name,
      // Store relative paths for portability across iOS container changes
      'file_path': HuntPathResolver.prepareForDatabase(filePath),
      'url': url,
      'content': content,
      'thumbnail_path': HuntPathResolver.prepareForDatabase(thumbnailPath),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'sort_order': sortOrder,
    };
  }

  HuntDocument copyWith({
    String? id,
    String? huntId,
    String? name,
    HuntDocumentType? type,
    String? filePath,
    String? url,
    String? content,
    String? thumbnailPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
  }) {
    return HuntDocument(
      id: id ?? this.id,
      huntId: huntId ?? this.huntId,
      name: name ?? this.name,
      type: type ?? this.type,
      filePath: filePath ?? this.filePath,
      url: url ?? this.url,
      content: content ?? this.content,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HuntDocument &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Links a tracking session to a specific hunt
@immutable
class HuntSessionLink {
  const HuntSessionLink({
    required this.id,
    required this.huntId,
    required this.sessionId,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String huntId;
  final String sessionId;
  final String? notes;
  final DateTime createdAt;

  /// Create from database map
  factory HuntSessionLink.fromDatabaseMap(Map<String, dynamic> map) {
    return HuntSessionLink(
      id: map['id'] as String,
      huntId: map['hunt_id'] as String,
      sessionId: map['session_id'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'hunt_id': huntId,
      'session_id': sessionId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  HuntSessionLink copyWith({
    String? id,
    String? huntId,
    String? sessionId,
    String? notes,
    DateTime? createdAt,
  }) {
    return HuntSessionLink(
      id: id ?? this.id,
      huntId: huntId ?? this.huntId,
      sessionId: sessionId ?? this.sessionId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HuntSessionLink &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A saved location (potential solve spot) within a hunt
@immutable
class HuntLocation {
  const HuntLocation({
    required this.id,
    required this.huntId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.notes,
    this.status = HuntLocationStatus.potential,
    required this.createdAt,
    this.searchedAt,
    this.sortOrder = 0,
  });

  final String id;
  final String huntId;
  final String name;
  final double latitude;
  final double longitude;
  final String? notes;
  final HuntLocationStatus status;
  final DateTime createdAt;
  final DateTime? searchedAt;
  final int sortOrder;

  /// Create from database map
  factory HuntLocation.fromDatabaseMap(Map<String, dynamic> map) {
    return HuntLocation(
      id: map['id'] as String,
      huntId: map['hunt_id'] as String,
      name: map['name'] as String,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      notes: map['notes'] as String?,
      status: HuntLocationStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => HuntLocationStatus.potential,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      searchedAt: map['searched_at'] != null
          ? DateTime.parse(map['searched_at'] as String)
          : null,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'hunt_id': huntId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'searched_at': searchedAt?.toIso8601String(),
      'sort_order': sortOrder,
    };
  }

  HuntLocation copyWith({
    String? id,
    String? huntId,
    String? name,
    double? latitude,
    double? longitude,
    String? notes,
    HuntLocationStatus? status,
    DateTime? createdAt,
    DateTime? searchedAt,
    int? sortOrder,
  }) {
    return HuntLocation(
      id: id ?? this.id,
      huntId: huntId ?? this.huntId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      searchedAt: searchedAt ?? this.searchedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HuntLocation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Summary statistics for a hunt (computed, not stored)
class HuntSummary {
  const HuntSummary({
    required this.hunt,
    this.documentCount = 0,
    this.noteCount = 0,
    this.linkCount = 0,
    this.sessionCount = 0,
    this.locationCount = 0,
    this.totalDistance = 0.0,
    this.lastActivityAt,
  });

  final TreasureHunt hunt;
  final int documentCount;
  final int noteCount;
  final int linkCount;
  final int sessionCount;
  final int locationCount;
  final double totalDistance; // In meters
  final DateTime? lastActivityAt;

  /// Total items across all categories
  int get totalItems => documentCount + noteCount + linkCount + locationCount;
}
