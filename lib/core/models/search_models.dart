import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/voice_note.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';

/// Types of content that can be searched
enum SearchContentType {
  all,
  photos,
  waypoints,
  sessions,
  voiceNotes,
}

/// Extension for search content types
extension SearchContentTypeExtension on SearchContentType {
  String get displayName {
    switch (this) {
      case SearchContentType.all:
        return 'All Content';
      case SearchContentType.photos:
        return 'Photos';
      case SearchContentType.waypoints:
        return 'Waypoints';
      case SearchContentType.sessions:
        return 'Sessions';
      case SearchContentType.voiceNotes:
        return 'Voice Notes';
    }
  }

  String get iconName {
    switch (this) {
      case SearchContentType.all:
        return 'search';
      case SearchContentType.photos:
        return 'photo_camera';
      case SearchContentType.waypoints:
        return 'place';
      case SearchContentType.sessions:
        return 'route';
      case SearchContentType.voiceNotes:
        return 'mic';
    }
  }
}

/// Date range filter options
enum SearchDateRange {
  all,
  today,
  thisWeek,
  thisMonth,
  thisYear,
  custom,
}

/// Extension for search date ranges
extension SearchDateRangeExtension on SearchDateRange {
  String get displayName {
    switch (this) {
      case SearchDateRange.all:
        return 'All Time';
      case SearchDateRange.today:
        return 'Today';
      case SearchDateRange.thisWeek:
        return 'This Week';
      case SearchDateRange.thisMonth:
        return 'This Month';
      case SearchDateRange.thisYear:
        return 'This Year';
      case SearchDateRange.custom:
        return 'Custom Range';
    }
  }

  /// Get the date range for filtering
  DateTimeRange? getDateRange() {
    final DateTime now = DateTime.now();
    switch (this) {
      case SearchDateRange.all:
        return null;
      case SearchDateRange.today:
        final DateTime startOfDay = DateTime(now.year, now.month, now.day);
        return DateTimeRange(start: startOfDay, end: now);
      case SearchDateRange.thisWeek:
        final DateTime startOfWeek =
            now.subtract(Duration(days: now.weekday - 1));
        final DateTime startOfWeekDay =
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return DateTimeRange(start: startOfWeekDay, end: now);
      case SearchDateRange.thisMonth:
        final DateTime startOfMonth = DateTime(now.year, now.month);
        return DateTimeRange(start: startOfMonth, end: now);
      case SearchDateRange.thisYear:
        final DateTime startOfYear = DateTime(now.year);
        return DateTimeRange(start: startOfYear, end: now);
      case SearchDateRange.custom:
        return null; // Will be set separately
    }
  }
}

/// Sort options for search results
enum SearchSortOption {
  relevance,
  dateNewest,
  dateOldest,
  nameAZ,
  nameZA,
  distance,
  rating,
}

/// Extension for search sort options
extension SearchSortOptionExtension on SearchSortOption {
  String get displayName {
    switch (this) {
      case SearchSortOption.relevance:
        return 'Relevance';
      case SearchSortOption.dateNewest:
        return 'Date (Newest)';
      case SearchSortOption.dateOldest:
        return 'Date (Oldest)';
      case SearchSortOption.nameAZ:
        return 'Name (A-Z)';
      case SearchSortOption.nameZA:
        return 'Name (Z-A)';
      case SearchSortOption.distance:
        return 'Distance';
      case SearchSortOption.rating:
        return 'Rating';
    }
  }
}

/// Search filters for advanced filtering
@immutable
class SearchFilters {
  const SearchFilters({
    this.contentTypes = const {SearchContentType.all},
    this.dateRange = SearchDateRange.all,
    this.customDateRange,
    this.waypointTypes = const {},
    this.minRating,
    this.maxRating,
    this.favoritesOnly = false,
    this.hasVoiceNotes = false,
    this.hasPhotos = false,
    this.sessionIds = const {},
    this.tags = const {},
    this.locationRadius,
    this.centerLocation,
  });

  final Set<SearchContentType> contentTypes;
  final SearchDateRange dateRange;
  final DateTimeRange? customDateRange;
  final Set<WaypointType> waypointTypes;
  final int? minRating;
  final int? maxRating;
  final bool favoritesOnly;
  final bool hasVoiceNotes;
  final bool hasPhotos;
  final Set<String> sessionIds;
  final Set<String> tags;
  final double? locationRadius; // in meters
  final LatLng? centerLocation;

  /// Get effective date range considering custom range
  DateTimeRange? get effectiveDateRange {
    if (dateRange == SearchDateRange.custom) {
      return customDateRange;
    }
    return dateRange.getDateRange();
  }

  /// Check if any filters are active
  bool get hasActiveFilters =>
      contentTypes.length != 1 ||
      !contentTypes.contains(SearchContentType.all) ||
      dateRange != SearchDateRange.all ||
      waypointTypes.isNotEmpty ||
      minRating != null ||
      maxRating != null ||
      favoritesOnly ||
      hasVoiceNotes ||
      hasPhotos ||
      sessionIds.isNotEmpty ||
      tags.isNotEmpty ||
      locationRadius != null;

  /// Get count of active filters
  int get activeFilterCount {
    int count = 0;
    if (contentTypes.length != 1 ||
        !contentTypes.contains(SearchContentType.all)) count++;
    if (dateRange != SearchDateRange.all) count++;
    if (waypointTypes.isNotEmpty) count++;
    if (minRating != null || maxRating != null) count++;
    if (favoritesOnly) count++;
    if (hasVoiceNotes) count++;
    if (hasPhotos) count++;
    if (sessionIds.isNotEmpty) count++;
    if (tags.isNotEmpty) count++;
    if (locationRadius != null) count++;
    return count;
  }

  SearchFilters copyWith({
    Set<SearchContentType>? contentTypes,
    SearchDateRange? dateRange,
    DateTimeRange? customDateRange,
    Set<WaypointType>? waypointTypes,
    int? minRating,
    int? maxRating,
    bool? favoritesOnly,
    bool? hasVoiceNotes,
    bool? hasPhotos,
    Set<String>? sessionIds,
    Set<String>? tags,
    double? locationRadius,
    LatLng? centerLocation,
    bool clearCustomDateRange = false,
    bool clearMinRating = false,
    bool clearMaxRating = false,
    bool clearLocationRadius = false,
    bool clearCenterLocation = false,
  }) =>
      SearchFilters(
        contentTypes: contentTypes ?? this.contentTypes,
        dateRange: dateRange ?? this.dateRange,
        customDateRange: clearCustomDateRange
            ? null
            : (customDateRange ?? this.customDateRange),
        waypointTypes: waypointTypes ?? this.waypointTypes,
        minRating: clearMinRating ? null : (minRating ?? this.minRating),
        maxRating: clearMaxRating ? null : (maxRating ?? this.maxRating),
        favoritesOnly: favoritesOnly ?? this.favoritesOnly,
        hasVoiceNotes: hasVoiceNotes ?? this.hasVoiceNotes,
        hasPhotos: hasPhotos ?? this.hasPhotos,
        sessionIds: sessionIds ?? this.sessionIds,
        tags: tags ?? this.tags,
        locationRadius: clearLocationRadius
            ? null
            : (locationRadius ?? this.locationRadius),
        centerLocation: clearCenterLocation
            ? null
            : (centerLocation ?? this.centerLocation),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchFilters &&
          runtimeType == other.runtimeType &&
          setEquals(contentTypes, other.contentTypes) &&
          dateRange == other.dateRange &&
          customDateRange == other.customDateRange &&
          setEquals(waypointTypes, other.waypointTypes) &&
          minRating == other.minRating &&
          maxRating == other.maxRating &&
          favoritesOnly == other.favoritesOnly &&
          hasVoiceNotes == other.hasVoiceNotes &&
          hasPhotos == other.hasPhotos &&
          setEquals(sessionIds, other.sessionIds) &&
          setEquals(tags, other.tags) &&
          locationRadius == other.locationRadius &&
          centerLocation == other.centerLocation;

  @override
  int get hashCode => Object.hash(
        contentTypes,
        dateRange,
        customDateRange,
        waypointTypes,
        minRating,
        maxRating,
        favoritesOnly,
        hasVoiceNotes,
        hasPhotos,
        sessionIds,
        tags,
        locationRadius,
        centerLocation,
      );
}

/// A unified search result that can contain different types of content
@immutable
abstract class SearchResult {
  const SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.relevanceScore,
    this.thumbnailPath,
    this.sessionId,
    this.location,
  });

  final String id;
  final SearchContentType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final double relevanceScore; // 0.0 to 1.0
  final String? thumbnailPath;
  final String? sessionId;
  final LatLng? location;

  /// Get display icon for this result type
  String get iconName => type.iconName;

  /// Get formatted timestamp
  String get formattedTimestamp {
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${difference.inDays > 730 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${difference.inDays > 60 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}

/// Search result for photos
@immutable
class PhotoSearchResult extends SearchResult {
  const PhotoSearchResult({
    required super.id,
    required super.title,
    required super.subtitle,
    required super.timestamp,
    required super.relevanceScore,
    required this.photo,
    required this.metadata,
    super.thumbnailPath,
    super.sessionId,
    super.location,
  }) : super(type: SearchContentType.photos);

  final PhotoWaypoint photo;
  final List<PhotoMetadata> metadata;

  /// Get photo rating from metadata
  int? get rating {
    final PhotoMetadata? ratingMeta =
        metadata.where((meta) => meta.key == CustomKeys.rating).firstOrNull;
    return ratingMeta?.typedValue as int?;
  }

  /// Check if photo is favorite
  bool get isFavorite => metadata.any(
      (meta) => meta.key == CustomKeys.favorite && meta.typedValue == true);

  /// Get photo tags
  List<String> get tags {
    final PhotoMetadata? tagsMeta =
        metadata.where((meta) => meta.key == CustomKeys.tags).firstOrNull;
    if (tagsMeta?.value == null) return [];
    return tagsMeta!.value!.split(',').map((tag) => tag.trim()).toList();
  }
}

/// Search result for waypoints
@immutable
class WaypointSearchResult extends SearchResult {
  const WaypointSearchResult({
    required super.id,
    required super.title,
    required super.subtitle,
    required super.timestamp,
    required super.relevanceScore,
    required this.waypoint,
    super.thumbnailPath,
    super.sessionId,
    super.location,
  }) : super(type: SearchContentType.waypoints);

  final Waypoint waypoint;
}

/// Search result for sessions
@immutable
class SessionSearchResult extends SearchResult {
  const SessionSearchResult({
    required super.id,
    required super.title,
    required super.subtitle,
    required super.timestamp,
    required super.relevanceScore,
    required this.session,
    super.thumbnailPath,
    super.sessionId,
    super.location,
  }) : super(type: SearchContentType.sessions);

  final TrackingSession session;
}

/// Search result for voice notes
@immutable
class VoiceNoteSearchResult extends SearchResult {
  const VoiceNoteSearchResult({
    required super.id,
    required super.title,
    required super.subtitle,
    required super.timestamp,
    required super.relevanceScore,
    required this.voiceNote,
    super.thumbnailPath,
    super.sessionId,
    super.location,
  }) : super(type: SearchContentType.voiceNotes);

  final VoiceNote voiceNote;

  /// Check if voice note has transcription
  bool get hasTranscription => voiceNote.hasTranscription;
}

/// Search query with text and filters
@immutable
class SearchQuery {
  const SearchQuery({
    required this.text,
    required this.filters,
    required this.sortOption,
  });

  final String text;
  final SearchFilters filters;
  final SearchSortOption sortOption;

  /// Check if query is empty
  bool get isEmpty => text.trim().isEmpty && !filters.hasActiveFilters;

  /// Get search terms from text
  List<String> get searchTerms => text
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList();

  SearchQuery copyWith({
    String? text,
    SearchFilters? filters,
    SearchSortOption? sortOption,
  }) =>
      SearchQuery(
        text: text ?? this.text,
        filters: filters ?? this.filters,
        sortOption: sortOption ?? this.sortOption,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchQuery &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          filters == other.filters &&
          sortOption == other.sortOption;

  @override
  int get hashCode => Object.hash(text, filters, sortOption);
}

/// Search suggestions for autocomplete
@immutable
class SearchSuggestion {
  const SearchSuggestion({
    required this.text,
    required this.type,
    this.count,
    this.icon,
  });

  final String text;
  final SearchSuggestionType type;
  final int? count;
  final String? icon;
}

/// Types of search suggestions
enum SearchSuggestionType {
  recent,
  tag,
  location,
  waypointType,
  session,
}

/// Extension for search suggestion types
extension SearchSuggestionTypeExtension on SearchSuggestionType {
  String get displayName {
    switch (this) {
      case SearchSuggestionType.recent:
        return 'Recent';
      case SearchSuggestionType.tag:
        return 'Tag';
      case SearchSuggestionType.location:
        return 'Location';
      case SearchSuggestionType.waypointType:
        return 'Waypoint Type';
      case SearchSuggestionType.session:
        return 'Session';
    }
  }

  String get iconName {
    switch (this) {
      case SearchSuggestionType.recent:
        return 'history';
      case SearchSuggestionType.tag:
        return 'label';
      case SearchSuggestionType.location:
        return 'place';
      case SearchSuggestionType.waypointType:
        return 'category';
      case SearchSuggestionType.session:
        return 'route';
    }
  }
}

/// Helper class for date time ranges
@immutable
class DateTimeRange {
  const DateTimeRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  bool contains(DateTime dateTime) =>
      dateTime.isAfter(start) && dateTime.isBefore(end);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateTimeRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Helper class for location coordinates (if not using latlong2)
@immutable
class LatLng {
  const LatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}
