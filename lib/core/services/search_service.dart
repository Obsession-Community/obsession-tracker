import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/models/search_models.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/voice_note.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/photo_capture_service.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Comprehensive search service for all app content
class SearchService {
  SearchService({
    required this.databaseService,
    required this.photoCaptureService,
  });

  final DatabaseService databaseService;
  final PhotoCaptureService photoCaptureService;

  /// Cache for recent searches
  final List<String> _recentSearches = <String>[];
  static const int _maxRecentSearches = 10;

  /// Cache for search suggestions
  final Map<String, List<SearchSuggestion>> _suggestionCache = {};
  final Map<String, DateTime> _suggestionCacheTimestamps = {};

  /// Perform a comprehensive search across all content types
  Future<List<SearchResult>> search(SearchQuery query) async {
    if (query.isEmpty) return [];

    // Add to recent searches
    _addToRecentSearches(query.text);

    final List<SearchResult> results = <SearchResult>[];

    // Search based on content type filters
    final Set<SearchContentType> contentTypes = query.filters.contentTypes;

    if (contentTypes.contains(SearchContentType.all) ||
        contentTypes.contains(SearchContentType.photos)) {
      final List<PhotoSearchResult> photoResults = await _searchPhotos(query);
      results.addAll(photoResults);
    }

    if (contentTypes.contains(SearchContentType.all) ||
        contentTypes.contains(SearchContentType.waypoints)) {
      final List<WaypointSearchResult> waypointResults =
          await _searchWaypoints(query);
      results.addAll(waypointResults);
    }

    if (contentTypes.contains(SearchContentType.all) ||
        contentTypes.contains(SearchContentType.sessions)) {
      final List<SessionSearchResult> sessionResults =
          await _searchSessions(query);
      results.addAll(sessionResults);
    }

    if (contentTypes.contains(SearchContentType.all) ||
        contentTypes.contains(SearchContentType.voiceNotes)) {
      final List<VoiceNoteSearchResult> voiceNoteResults =
          await _searchVoiceNotes(query);
      results.addAll(voiceNoteResults);
    }

    // Apply additional filters
    final List<SearchResult> filteredResults =
        _applyFilters(results, query.filters);

    // Sort results
    final List<SearchResult> sortedResults =
        _sortResults(filteredResults, query.sortOption);

    return sortedResults;
  }

  /// Search photos and their metadata
  Future<List<PhotoSearchResult>> _searchPhotos(SearchQuery query) async {
    try {
      final Database db = await databaseService.database;

      // Build SQL query for photos
      final StringBuffer sqlBuffer = StringBuffer();
      final List<dynamic> args = <dynamic>[];

      sqlBuffer.write('''
        SELECT DISTINCT p.*, pm.key, pm.value, pm.type
        FROM photo_waypoints p
        LEFT JOIN photo_metadata pm ON p.id = pm.photo_waypoint_id
        WHERE 1=1
      ''');

      // Add text search conditions
      if (query.text.isNotEmpty) {
        sqlBuffer.write('''
          AND (
            p.file_path LIKE ? OR
            pm.value LIKE ? OR
            pm.key LIKE ?
          )
        ''');
        final String searchPattern = '%${query.text}%';
        args.addAll([searchPattern, searchPattern, searchPattern]);
      }

      // Add date range filter
      final DateTimeRange? dateRange = query.filters.effectiveDateRange;
      if (dateRange != null) {
        sqlBuffer.write(' AND p.created_at BETWEEN ? AND ?');
        args.addAll([
          dateRange.start.millisecondsSinceEpoch,
          dateRange.end.millisecondsSinceEpoch,
        ]);
      }

      sqlBuffer.write(' ORDER BY p.created_at DESC');

      final List<Map<String, dynamic>> rows =
          await db.rawQuery(sqlBuffer.toString(), args);

      // Group results by photo ID and build PhotoSearchResult objects
      final Map<String, Map<String, dynamic>> photoData = {};
      final Map<String, List<PhotoMetadata>> photoMetadata = {};

      for (final Map<String, dynamic> row in rows) {
        final String photoId = row['id'] as String;

        // Store photo data
        if (!photoData.containsKey(photoId)) {
          photoData[photoId] = Map<String, dynamic>.from(row);
          photoMetadata[photoId] = [];
        }

        // Add metadata if present
        if (row['key'] != null) {
          final PhotoMetadata metadata = PhotoMetadata.fromMap({
            'id': row['id'],
            'photo_waypoint_id': photoId,
            'key': row['key'],
            'value': row['value'],
            'type': row['type'],
          });
          photoMetadata[photoId]!.add(metadata);
        }
      }

      final List<PhotoSearchResult> results = <PhotoSearchResult>[];

      for (final MapEntry<String, Map<String, dynamic>> entry
          in photoData.entries) {
        final PhotoWaypoint photo = PhotoWaypoint.fromMap(entry.value);
        final List<PhotoMetadata> metadata = photoMetadata[entry.key] ?? [];

        // Apply photo-specific filters
        if (!_matchesPhotoFilters(photo, metadata, query.filters)) {
          continue;
        }

        // Calculate relevance score
        final double relevanceScore =
            _calculatePhotoRelevance(photo, metadata, query);

        // Get waypoint to access session and location info
        final Waypoint? waypoint =
            await _getWaypointById(photo.waypointId);

        final PhotoSearchResult result = PhotoSearchResult(
          id: photo.id,
          title: _getPhotoTitle(photo, metadata),
          subtitle: _getPhotoSubtitle(photo, metadata),
          timestamp: photo.createdAt,
          relevanceScore: relevanceScore,
          photo: photo,
          metadata: metadata,
          thumbnailPath: photo.thumbnailPath,
          sessionId: waypoint?.sessionId,
          location: waypoint?.coordinates != null
              ? LatLng(waypoint!.coordinates.latitude,
                  waypoint.coordinates.longitude)
              : null,
        );

        results.add(result);
      }

      return results;
    } catch (e) {
      debugPrint('Error searching photos: $e');
      return [];
    }
  }

  /// Search waypoints
  Future<List<WaypointSearchResult>> _searchWaypoints(SearchQuery query) async {
    try {
      final Database db = await databaseService.database;

      final StringBuffer sqlBuffer = StringBuffer();
      final List<dynamic> args = <dynamic>[];

      sqlBuffer.write('''
        SELECT * FROM waypoints
        WHERE 1=1
      ''');

      // Add text search conditions
      if (query.text.isNotEmpty) {
        sqlBuffer.write('''
          AND (
            name LIKE ? OR
            notes LIKE ? OR
            type LIKE ?
          )
        ''');
        final String searchPattern = '%${query.text}%';
        args.addAll([searchPattern, searchPattern, searchPattern]);
      }

      // Add date range filter
      final DateTimeRange? dateRange = query.filters.effectiveDateRange;
      if (dateRange != null) {
        sqlBuffer.write(' AND timestamp BETWEEN ? AND ?');
        args.addAll([
          dateRange.start.millisecondsSinceEpoch,
          dateRange.end.millisecondsSinceEpoch,
        ]);
      }

      sqlBuffer.write(' ORDER BY timestamp DESC');

      final List<Map<String, dynamic>> rows =
          await db.rawQuery(sqlBuffer.toString(), args);

      final List<WaypointSearchResult> results = <WaypointSearchResult>[];

      for (final Map<String, dynamic> row in rows) {
        final Waypoint waypoint = Waypoint.fromMap(row);

        // Calculate relevance score
        final double relevanceScore =
            _calculateWaypointRelevance(waypoint, query);

        // Create search result
        final WaypointSearchResult result = WaypointSearchResult(
          id: waypoint.id,
          title: waypoint.displayName,
          subtitle: _getWaypointSubtitle(waypoint),
          timestamp: waypoint.timestamp,
          relevanceScore: relevanceScore,
          waypoint: waypoint,
          sessionId: waypoint.sessionId,
          location: LatLng(
              waypoint.coordinates.latitude, waypoint.coordinates.longitude),
        );

        results.add(result);
      }

      return results;
    } catch (e) {
      debugPrint('Error searching waypoints: $e');
      return [];
    }
  }

  /// Search sessions
  Future<List<SessionSearchResult>> _searchSessions(SearchQuery query) async {
    try {
      final Database db = await databaseService.database;

      final StringBuffer sqlBuffer = StringBuffer();
      final List<dynamic> args = <dynamic>[];

      sqlBuffer.write('''
        SELECT * FROM sessions
        WHERE 1=1
      ''');

      // Add text search conditions
      if (query.text.isNotEmpty) {
        sqlBuffer.write('''
          AND (
            name LIKE ? OR
            description LIKE ?
          )
        ''');
        final String searchPattern = '%${query.text}%';
        args.addAll([searchPattern, searchPattern]);
      }

      // Add date range filter
      final DateTimeRange? dateRange = query.filters.effectiveDateRange;
      if (dateRange != null) {
        sqlBuffer.write(' AND created_at BETWEEN ? AND ?');
        args.addAll([
          dateRange.start.millisecondsSinceEpoch,
          dateRange.end.millisecondsSinceEpoch,
        ]);
      }

      sqlBuffer.write(' ORDER BY created_at DESC');

      final List<Map<String, dynamic>> rows =
          await db.rawQuery(sqlBuffer.toString(), args);

      final List<SessionSearchResult> results = <SessionSearchResult>[];

      for (final Map<String, dynamic> row in rows) {
        final TrackingSession session = TrackingSession.fromMap(row);

        // Calculate relevance score
        final double relevanceScore =
            _calculateSessionRelevance(session, query);

        // Create search result
        final SessionSearchResult result = SessionSearchResult(
          id: session.id,
          title: session.name,
          subtitle: _getSessionSubtitle(session),
          timestamp: session.createdAt,
          relevanceScore: relevanceScore,
          session: session,
          sessionId: session.id,
          location: session.startLocation != null
              ? LatLng(session.startLocation!.latitude,
                  session.startLocation!.longitude)
              : null,
        );

        results.add(result);
      }

      return results;
    } catch (e) {
      debugPrint('Error searching sessions: $e');
      return [];
    }
  }

  /// Search voice notes
  Future<List<VoiceNoteSearchResult>> _searchVoiceNotes(
      SearchQuery query) async {
    try {
      final Database db = await databaseService.database;

      final StringBuffer sqlBuffer = StringBuffer();
      final List<dynamic> args = <dynamic>[];

      sqlBuffer.write('''
        SELECT vn.*, ew.latitude, ew.longitude, ew.session_id
        FROM voice_notes vn
        LEFT JOIN waypoints ew ON vn.waypoint_id = ew.id
        WHERE 1=1
      ''');

      // Add text search conditions
      if (query.text.isNotEmpty) {
        sqlBuffer.write(' AND vn.transcription LIKE ?');
        args.add('%${query.text}%');
      }

      // Add date range filter
      final DateTimeRange? dateRange = query.filters.effectiveDateRange;
      if (dateRange != null) {
        sqlBuffer.write(' AND vn.created_at BETWEEN ? AND ?');
        args.addAll([
          dateRange.start.millisecondsSinceEpoch,
          dateRange.end.millisecondsSinceEpoch,
        ]);
      }

      sqlBuffer.write(' ORDER BY vn.created_at DESC');

      final List<Map<String, dynamic>> rows =
          await db.rawQuery(sqlBuffer.toString(), args);

      final List<VoiceNoteSearchResult> results = <VoiceNoteSearchResult>[];

      for (final Map<String, dynamic> row in rows) {
        final VoiceNote voiceNote = VoiceNote.fromMap(row);

        // Calculate relevance score
        final double relevanceScore =
            _calculateVoiceNoteRelevance(voiceNote, query);

        // Get location if available
        LatLng? location;
        if (row['latitude'] != null && row['longitude'] != null) {
          location =
              LatLng(row['latitude'] as double, row['longitude'] as double);
        }

        // Create search result
        final VoiceNoteSearchResult result = VoiceNoteSearchResult(
          id: voiceNote.id,
          title: _getVoiceNoteTitle(voiceNote),
          subtitle: _getVoiceNoteSubtitle(voiceNote),
          timestamp: voiceNote.createdAt,
          relevanceScore: relevanceScore,
          voiceNote: voiceNote,
          sessionId: row['session_id'] as String?,
          location: location,
        );

        results.add(result);
      }

      return results;
    } catch (e) {
      debugPrint('Error searching voice notes: $e');
      return [];
    }
  }

  /// Get waypoint by ID
  Future<Waypoint?> _getWaypointById(String waypointId) async {
    try {
      final Database db = await databaseService.database;
      final List<Map<String, dynamic>> rows = await db.query(
        'waypoints',
        where: 'id = ?',
        whereArgs: [waypointId],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        return Waypoint.fromMap(rows.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting waypoint by ID: $e');
      return null;
    }
  }

  /// Apply additional filters to search results
  List<SearchResult> _applyFilters(
          List<SearchResult> results, SearchFilters filters) =>
      results.where((result) {
        // Apply favorites filter for photos
        if (filters.favoritesOnly && result is PhotoSearchResult) {
          if (!result.isFavorite) return false;
        }

        // Apply rating filter for photos
        if (result is PhotoSearchResult) {
          if (filters.minRating != null &&
              (result.rating ?? 0) < filters.minRating!) {
            return false;
          }
          if (filters.maxRating != null &&
              (result.rating ?? 0) > filters.maxRating!) {
            return false;
          }
        }

        return true;
      }).toList();

  /// Sort search results based on sort option
  List<SearchResult> _sortResults(
      List<SearchResult> results, SearchSortOption sortOption) {
    switch (sortOption) {
      case SearchSortOption.relevance:
        results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
        break;
      case SearchSortOption.dateNewest:
        results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case SearchSortOption.dateOldest:
        results.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case SearchSortOption.nameAZ:
        results.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SearchSortOption.nameZA:
        results.sort((a, b) => b.title.compareTo(a.title));
        break;
      case SearchSortOption.rating:
        results.sort((a, b) {
          if (a is PhotoSearchResult && b is PhotoSearchResult) {
            return (b.rating ?? 0).compareTo(a.rating ?? 0);
          }
          return 0;
        });
        break;
      case SearchSortOption.distance:
        // Would need current location to implement distance sorting
        break;
    }

    return results;
  }

  /// Check if photo matches photo-specific filters
  bool _matchesPhotoFilters(PhotoWaypoint photo, List<PhotoMetadata> metadata,
          SearchFilters filters) =>
      true;

  /// Calculate relevance score for photos
  double _calculatePhotoRelevance(
      PhotoWaypoint photo, List<PhotoMetadata> metadata, SearchQuery query) {
    double score = 0.0;

    if (query.text.isEmpty) return 1.0;

    final List<String> searchTerms = query.searchTerms;

    // Check file path
    final String filePath = photo.filePath.toLowerCase();
    for (final String term in searchTerms) {
      if (filePath.contains(term)) {
        score += 0.3;
      }
    }

    // Check metadata
    for (final PhotoMetadata meta in metadata) {
      final String key = meta.key.toLowerCase();
      final String value = (meta.value ?? '').toLowerCase();

      for (final String term in searchTerms) {
        if (key.contains(term)) score += 0.2;
        if (value.contains(term)) score += 0.4;
      }
    }

    return min(score, 1.0);
  }

  /// Calculate relevance score for waypoints
  double _calculateWaypointRelevance(
      Waypoint waypoint, SearchQuery query) {
    double score = 0.0;

    if (query.text.isEmpty) return 1.0;

    final List<String> searchTerms = query.searchTerms;

    // Check waypoint name
    if (waypoint.name != null) {
      final String waypointName = waypoint.name!.toLowerCase();
      for (final String term in searchTerms) {
        if (waypointName.contains(term)) score += 0.5;
      }
    }

    // Check type display name
    final String typeName = waypoint.type.displayName.toLowerCase();
    for (final String term in searchTerms) {
      if (typeName.contains(term)) score += 0.3;
    }

    return min(score, 1.0);
  }

  /// Calculate relevance score for sessions
  double _calculateSessionRelevance(
      TrackingSession session, SearchQuery query) {
    double score = 0.0;

    if (query.text.isEmpty) return 1.0;

    final List<String> searchTerms = query.searchTerms;

    // Check session name
    final String name = session.name.toLowerCase();
    for (final String term in searchTerms) {
      if (name.contains(term)) score += 0.6;
    }

    return min(score, 1.0);
  }

  /// Calculate relevance score for voice notes
  double _calculateVoiceNoteRelevance(VoiceNote voiceNote, SearchQuery query) {
    double score = 0.0;

    if (query.text.isEmpty) return 1.0;

    final List<String> searchTerms = query.searchTerms;

    // Check transcription
    if (voiceNote.transcription != null) {
      final String transcription = voiceNote.transcription!.toLowerCase();
      for (final String term in searchTerms) {
        if (transcription.contains(term)) score += 0.8;
      }
    }

    return min(score, 1.0);
  }

  /// Get search suggestions based on input
  Future<List<SearchSuggestion>> getSuggestions(String input) async {
    if (input.trim().isEmpty) {
      return _getRecentSearchSuggestions();
    }

    final List<SearchSuggestion> suggestions = <SearchSuggestion>[];

    // Add recent searches that match
    suggestions.addAll(_getMatchingRecentSearches(input));

    // Add waypoint type suggestions
    suggestions.addAll(_getWaypointTypeSuggestions(input));

    return suggestions;
  }

  /// Get recent search suggestions
  List<SearchSuggestion> _getRecentSearchSuggestions() => _recentSearches
      .map((search) => SearchSuggestion(
            text: search,
            type: SearchSuggestionType.recent,
          ))
      .toList();

  /// Get matching recent searches
  List<SearchSuggestion> _getMatchingRecentSearches(String input) {
    final String inputLower = input.toLowerCase();
    return _recentSearches
        .where((search) => search.toLowerCase().contains(inputLower))
        .map((search) => SearchSuggestion(
              text: search,
              type: SearchSuggestionType.recent,
            ))
        .toList();
  }

  /// Get waypoint type suggestions
  List<SearchSuggestion> _getWaypointTypeSuggestions(String input) {
    final String inputLower = input.toLowerCase();
    return WaypointType.values
        .where((type) => type.displayName.toLowerCase().contains(inputLower))
        .map((type) => SearchSuggestion(
              text: type.displayName,
              type: SearchSuggestionType.waypointType,
              icon: type.iconName,
            ))
        .toList();
  }

  /// Add search to recent searches
  void _addToRecentSearches(String search) {
    if (search.trim().isEmpty) return;

    _recentSearches.remove(search);
    _recentSearches.insert(0, search);

    if (_recentSearches.length > _maxRecentSearches) {
      _recentSearches.removeRange(_maxRecentSearches, _recentSearches.length);
    }
  }

  /// Clear recent searches
  void clearRecentSearches() {
    _recentSearches.clear();
  }

  /// Clear suggestion cache
  void clearSuggestionCache() {
    _suggestionCache.clear();
    _suggestionCacheTimestamps.clear();
  }

  /// Helper methods for generating titles and subtitles

  String _getPhotoTitle(PhotoWaypoint photo, List<PhotoMetadata> metadata) {
    // Try to get custom name from metadata
    final PhotoMetadata? nameMeta =
        metadata.where((meta) => meta.key == CustomKeys.userNote).firstOrNull;

    if (nameMeta?.value != null && nameMeta!.value!.isNotEmpty) {
      return nameMeta.value!;
    }

    // Use filename as fallback
    final String fileName = photo.filePath.split('/').last;
    return fileName.replaceAll(RegExp(r'\.[^.]+$'), ''); // Remove extension
  }

  String _getPhotoSubtitle(PhotoWaypoint photo, List<PhotoMetadata> metadata) {
    final List<String> parts = <String>[];

    // Add rating if available
    final PhotoMetadata? ratingMeta =
        metadata.where((meta) => meta.key == CustomKeys.rating).firstOrNull;
    if (ratingMeta?.typedValue != null) {
      final int rating = ratingMeta!.typedValue as int;
      parts.add('★' * rating);
    }

    // Add file size
    parts.add(photo.fileSizeFormatted);

    return parts.join(' • ');
  }

  String _getWaypointSubtitle(Waypoint waypoint) {
    final List<String> parts = <String>[];

    parts.add(waypoint.type.displayName);

    if (waypoint.accuracy != null) {
      parts.add('±${waypoint.accuracy!.toStringAsFixed(0)}m');
    }

    return parts.join(' • ');
  }

  String _getSessionSubtitle(TrackingSession session) {
    final List<String> parts = <String>[];

    parts.add(session.formattedDistance);
    parts.add(session.formattedDuration);
    parts.add('${session.breadcrumbCount} points');

    return parts.join(' • ');
  }

  String _getVoiceNoteTitle(VoiceNote voiceNote) {
    if (voiceNote.hasTranscription) {
      final String transcription = voiceNote.transcription!;
      if (transcription.length > 50) {
        return '${transcription.substring(0, 50)}...';
      }
      return transcription;
    }
    return 'Voice Note';
  }

  String _getVoiceNoteSubtitle(VoiceNote voiceNote) {
    final List<String> parts = <String>[];

    parts.add(voiceNote.durationFormatted);
    parts.add(voiceNote.fileSizeFormatted);

    if (voiceNote.hasTranscription) {
      parts.add('Transcribed');
    }

    return parts.join(' • ');
  }
}
