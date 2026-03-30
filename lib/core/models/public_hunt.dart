/// Public hunt from BFF - hunts created by admins for users to follow
/// These are different from local TreasureHunts which users create themselves

/// Status of a public hunt
enum PublicHuntStatus {
  draft,
  upcoming,
  active,
  found,
  archived;

  static PublicHuntStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'draft':
        return PublicHuntStatus.draft;
      case 'upcoming':
        return PublicHuntStatus.upcoming;
      case 'active':
      case 'published':  // Treat published as active (visible + hunt in progress)
        return PublicHuntStatus.active;
      case 'found':
        return PublicHuntStatus.found;
      case 'archived':
        return PublicHuntStatus.archived;
      default:
        return PublicHuntStatus.draft;
    }
  }

  String get displayName {
    switch (this) {
      case PublicHuntStatus.draft:
        return 'Draft';
      case PublicHuntStatus.upcoming:
        return 'Upcoming';
      case PublicHuntStatus.active:
        return 'Active';
      case PublicHuntStatus.found:
        return 'Found';
      case PublicHuntStatus.archived:
        return 'Archived';
    }
  }
}

/// Type of hunt
enum PublicHuntType {
  armchair,
  field,
  hybrid;

  static PublicHuntType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'armchair':
        return PublicHuntType.armchair;
      case 'field':
        return PublicHuntType.field;
      case 'hybrid':
        return PublicHuntType.hybrid;
      default:
        return PublicHuntType.field;
    }
  }

  String get displayName {
    switch (this) {
      case PublicHuntType.armchair:
        return 'Armchair';
      case PublicHuntType.field:
        return 'Field';
      case PublicHuntType.hybrid:
        return 'Hybrid';
    }
  }

  String get description {
    switch (this) {
      case PublicHuntType.armchair:
        return 'Can be solved from home using clues';
      case PublicHuntType.field:
        return 'Requires physical searching in the field';
      case PublicHuntType.hybrid:
        return 'Combines armchair solving with field searching';
    }
  }
}

/// Difficulty level of a hunt
enum PublicHuntDifficulty {
  beginner,
  intermediate,
  advanced,
  expert;

  static PublicHuntDifficulty? fromString(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'beginner':
        return PublicHuntDifficulty.beginner;
      case 'intermediate':
        return PublicHuntDifficulty.intermediate;
      case 'advanced':
        return PublicHuntDifficulty.advanced;
      case 'expert':
        return PublicHuntDifficulty.expert;
      default:
        return null;
    }
  }

  String get displayName {
    switch (this) {
      case PublicHuntDifficulty.beginner:
        return 'Beginner';
      case PublicHuntDifficulty.intermediate:
        return 'Intermediate';
      case PublicHuntDifficulty.advanced:
        return 'Advanced';
      case PublicHuntDifficulty.expert:
        return 'Expert';
    }
  }
}

/// Media attached to a hunt (images, documents, etc.)
class PublicHuntMedia {
  final String id;
  final String huntId;
  final String mediaType;
  final String title;
  final String? description;
  final String url;
  final String? thumbnailUrl;
  final String? category;
  final int displayOrder;

  const PublicHuntMedia({
    required this.id,
    required this.huntId,
    required this.mediaType,
    required this.title,
    this.description,
    required this.url,
    this.thumbnailUrl,
    this.category,
    this.displayOrder = 0,
  });

  factory PublicHuntMedia.fromJson(Map<String, dynamic> json) {
    return PublicHuntMedia(
      id: json['id'] as String,
      huntId: json['huntId'] as String,
      mediaType: json['mediaType'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      url: json['url'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      category: json['category'] as String?,
      displayOrder: json['displayOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'huntId': huntId,
      'mediaType': mediaType,
      'title': title,
      if (description != null) 'description': description,
      'url': url,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (category != null) 'category': category,
      'displayOrder': displayOrder,
    };
  }

  /// Alias for description (used in UI)
  String? get caption => description;
}

/// External link related to a hunt
class PublicHuntLink {
  final String id;
  final String huntId;
  final String title;
  final String url;
  final String linkType;
  final String? description;
  final int displayOrder;

  const PublicHuntLink({
    required this.id,
    required this.huntId,
    required this.title,
    required this.url,
    required this.linkType,
    this.description,
    this.displayOrder = 0,
  });

  factory PublicHuntLink.fromJson(Map<String, dynamic> json) {
    return PublicHuntLink(
      id: json['id'] as String,
      huntId: json['huntId'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      linkType: json['linkType'] as String,
      description: json['description'] as String?,
      displayOrder: json['displayOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'huntId': huntId,
      'title': title,
      'url': url,
      'linkType': linkType,
      if (description != null) 'description': description,
      'displayOrder': displayOrder,
    };
  }
}

/// Update/news item for a hunt
class PublicHuntUpdate {
  final String id;
  final String huntId;
  final String updateType;
  final String title;
  final String body;
  final String? imageUrl;
  final DateTime publishedAt;

  const PublicHuntUpdate({
    required this.id,
    required this.huntId,
    required this.updateType,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.publishedAt,
  });

  factory PublicHuntUpdate.fromJson(Map<String, dynamic> json) {
    return PublicHuntUpdate(
      id: json['id'] as String,
      huntId: json['huntId'] as String,
      updateType: json['updateType'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      imageUrl: json['imageUrl'] as String?,
      publishedAt: DateTime.parse(json['publishedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'huntId': huntId,
      'updateType': updateType,
      'title': title,
      'body': body,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'publishedAt': publishedAt.toIso8601String(),
    };
  }

  /// Alias for body (used in UI)
  String get content => body;
}

/// A public hunt from the BFF
class PublicHunt {
  final String id;
  final String slug;
  final String title;
  final String? subtitle;
  final String description;
  final String providerName;
  final String? providerUrl;
  final String? providerLogoUrl;
  final PublicHuntStatus status;
  final PublicHuntType huntType;
  final PublicHuntDifficulty? difficulty;
  final DateTime? announcedAt;
  final DateTime? startsAt;
  final DateTime? foundAt;
  final DateTime? endsAt;
  final String? prizeDescription;
  final double? prizeValueUsd;
  final String? searchRegion;
  final bool featured;
  final int? featuredOrder;
  final String? heroImageUrl;
  final String? thumbnailUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PublicHuntMedia> media;
  final List<PublicHuntLink> links;
  final List<PublicHuntUpdate> updates;

  const PublicHunt({
    required this.id,
    required this.slug,
    required this.title,
    this.subtitle,
    required this.description,
    required this.providerName,
    this.providerUrl,
    this.providerLogoUrl,
    required this.status,
    required this.huntType,
    this.difficulty,
    this.announcedAt,
    this.startsAt,
    this.foundAt,
    this.endsAt,
    this.prizeDescription,
    this.prizeValueUsd,
    this.searchRegion,
    this.featured = false,
    this.featuredOrder,
    this.heroImageUrl,
    this.thumbnailUrl,
    required this.createdAt,
    required this.updatedAt,
    this.media = const [],
    this.links = const [],
    this.updates = const [],
  });

  factory PublicHunt.fromJson(Map<String, dynamic> json) {
    return PublicHunt(
      id: json['id'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String,
      providerName: json['providerName'] as String,
      providerUrl: json['providerUrl'] as String?,
      providerLogoUrl: json['providerLogoUrl'] as String?,
      status: PublicHuntStatus.fromString(json['status'] as String),
      huntType: PublicHuntType.fromString(json['huntType'] as String),
      difficulty: PublicHuntDifficulty.fromString(json['difficulty'] as String?),
      announcedAt: json['announcedAt'] != null
          ? DateTime.parse(json['announcedAt'] as String)
          : null,
      startsAt: json['startsAt'] != null
          ? DateTime.parse(json['startsAt'] as String)
          : null,
      foundAt: json['foundAt'] != null
          ? DateTime.parse(json['foundAt'] as String)
          : null,
      endsAt: json['endsAt'] != null
          ? DateTime.parse(json['endsAt'] as String)
          : null,
      prizeDescription: json['prizeDescription'] as String?,
      prizeValueUsd: (json['prizeValueUsd'] as num?)?.toDouble(),
      searchRegion: json['searchRegion'] as String?,
      featured: json['featured'] as bool? ?? false,
      featuredOrder: json['featuredOrder'] as int?,
      heroImageUrl: json['heroImageUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      media: (json['media'] as List<dynamic>?)
              ?.map((e) => PublicHuntMedia.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      links: (json['links'] as List<dynamic>?)
              ?.map((e) => PublicHuntLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      updates: (json['updates'] as List<dynamic>?)
              ?.map((e) => PublicHuntUpdate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      'description': description,
      'providerName': providerName,
      if (providerUrl != null) 'providerUrl': providerUrl,
      if (providerLogoUrl != null) 'providerLogoUrl': providerLogoUrl,
      'status': status.name,
      'huntType': huntType.name,
      if (difficulty != null) 'difficulty': difficulty!.name,
      if (announcedAt != null) 'announcedAt': announcedAt!.toIso8601String(),
      if (startsAt != null) 'startsAt': startsAt!.toIso8601String(),
      if (foundAt != null) 'foundAt': foundAt!.toIso8601String(),
      if (endsAt != null) 'endsAt': endsAt!.toIso8601String(),
      if (prizeDescription != null) 'prizeDescription': prizeDescription,
      if (prizeValueUsd != null) 'prizeValueUsd': prizeValueUsd,
      if (searchRegion != null) 'searchRegion': searchRegion,
      'featured': featured,
      if (featuredOrder != null) 'featuredOrder': featuredOrder,
      if (heroImageUrl != null) 'heroImageUrl': heroImageUrl,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'media': media.map((m) => m.toJson()).toList(),
      'links': links.map((l) => l.toJson()).toList(),
      'updates': updates.map((u) => u.toJson()).toList(),
    };
  }

  /// Whether the hunt is currently active
  bool get isActive => status == PublicHuntStatus.active;

  /// Whether the hunt has ended (found or archived)
  bool get hasEnded =>
      status == PublicHuntStatus.found || status == PublicHuntStatus.archived;

  /// Formatted prize value
  String? get formattedPrize {
    if (prizeValueUsd == null) return prizeDescription;
    return '\$${prizeValueUsd!.toStringAsFixed(0)}';
  }
}
