import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/custom_marker.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Service for managing custom map markers.
///
/// Provides a complete API for creating, updating, and deleting custom markers
/// that users can place anywhere on the map, independent of tracking sessions.
///
/// Features:
/// - CRUD operations for markers
/// - Geographic bounds queries for map display
/// - Optional hunt association
/// - Directory management for marker attachments
class CustomMarkerService {
  factory CustomMarkerService() => _instance ??= CustomMarkerService._();
  CustomMarkerService._();
  static CustomMarkerService? _instance;

  static const Uuid _uuid = Uuid();
  final DatabaseService _db = DatabaseService();

  /// Base directory structure: /markers/{marker_id}/
  static const String _markersBaseDir = 'markers';

  // ============================================================
  // Directory Management
  // ============================================================

  /// Get the application documents directory
  Future<Directory> get _documentsDirectory async =>
      getApplicationDocumentsDirectory();

  /// Get the base markers directory
  Future<Directory> get _markersDirectory async {
    final Directory docs = await _documentsDirectory;
    final Directory markersDir = Directory(
      path.join(docs.path, _markersBaseDir),
    );

    if (!markersDir.existsSync()) {
      await markersDir.create(recursive: true);
    }

    return markersDir;
  }

  /// Get the directory for a specific marker's attachments
  Future<Directory> getMarkerDirectory(String markerId) async {
    final Directory markersDir = await _markersDirectory;
    final Directory markerDir = Directory(
      path.join(markersDir.path, markerId),
    );

    if (!markerDir.existsSync()) {
      await markerDir.create(recursive: true);
    }

    return markerDir;
  }

  /// Delete the directory for a marker (including all attachments)
  Future<void> _deleteMarkerDirectory(String markerId) async {
    try {
      final Directory markersDir = await _markersDirectory;
      final Directory markerDir = Directory(
        path.join(markersDir.path, markerId),
      );

      if (markerDir.existsSync()) {
        await markerDir.delete(recursive: true);
        debugPrint('Deleted marker directory: ${markerDir.path}');
      }
    } catch (e) {
      debugPrint('Error deleting marker directory: $e');
      // Don't rethrow - directory cleanup is non-critical
    }
  }

  // ============================================================
  // Custom Marker CRUD
  // ============================================================

  /// Create a new custom marker
  ///
  /// Returns the created marker with generated ID and timestamps.
  /// If [sessionId] is provided, the marker will be associated with that tracking session.
  Future<CustomMarker> createMarker({
    required double latitude,
    required double longitude,
    required String name,
    required CustomMarkerCategory category,
    String? notes,
    int? colorArgb,
    String? sessionId,
    String? huntId,
    Map<String, dynamic>? metadata,
  }) async {
    final now = DateTime.now();
    final marker = CustomMarker(
      id: _uuid.v4(),
      latitude: latitude,
      longitude: longitude,
      name: name,
      notes: notes,
      category: category,
      colorArgb: colorArgb ?? category.defaultColor.toARGB32(),
      createdAt: now,
      updatedAt: now,
      sessionId: sessionId,
      huntId: huntId,
      metadata: metadata,
    );

    await _db.insertCustomMarker(marker);
    debugPrint('Created custom marker: ${marker.id} - ${marker.name}${sessionId != null ? ' (session: $sessionId)' : ''}');
    return marker;
  }

  /// Update an existing custom marker
  ///
  /// Updates the updatedAt timestamp automatically.
  Future<CustomMarker> updateMarker(CustomMarker marker) async {
    final updatedMarker = marker.copyWith(
      updatedAt: DateTime.now(),
    );
    await _db.updateCustomMarker(updatedMarker);
    debugPrint('Updated custom marker: ${marker.id}');
    return updatedMarker;
  }

  /// Delete a custom marker and its associated directory
  ///
  /// This also triggers cascade deletion of attachments in the database.
  Future<void> deleteMarker(String markerId) async {
    // First delete the database record (cascade deletes attachments)
    await _db.deleteCustomMarker(markerId);

    // Then clean up the file system
    await _deleteMarkerDirectory(markerId);

    debugPrint('Deleted custom marker and files: $markerId');
  }

  /// Get a marker by ID
  Future<CustomMarker?> getMarker(String markerId) async {
    return _db.getCustomMarker(markerId);
  }

  /// Get all custom markers
  Future<List<CustomMarker>> getAllMarkers() async {
    return _db.getAllCustomMarkers();
  }

  /// Get markers within geographic bounds
  ///
  /// Used for loading markers visible in the current map viewport.
  /// Optionally filter by category.
  Future<List<CustomMarker>> getMarkersForBounds({
    required double north,
    required double south,
    required double east,
    required double west,
    Set<CustomMarkerCategory>? categoryFilter,
  }) async {
    return _db.getCustomMarkersForBounds(
      north: north,
      south: south,
      east: east,
      west: west,
      categoryFilter: categoryFilter,
    );
  }

  /// Get markers linked to a specific treasure hunt
  Future<List<CustomMarker>> getMarkersForHunt(String huntId) async {
    return _db.getCustomMarkersForHunt(huntId);
  }

  /// Get markers linked to a specific tracking session
  Future<List<CustomMarker>> getMarkersForSession(String sessionId) async {
    return _db.getCustomMarkersForSession(sessionId);
  }

  /// Search markers by name or notes
  Future<List<CustomMarker>> searchMarkers(String query) async {
    if (query.trim().isEmpty) {
      return getAllMarkers();
    }
    return _db.searchCustomMarkers(query);
  }

  /// Get the total count of markers
  Future<int> getMarkerCount() async {
    return _db.getCustomMarkerCount();
  }

  /// Check if a marker has any attachments
  Future<bool> markerHasAttachments(String markerId) async {
    return _db.markerHasAttachments(markerId);
  }

  // ============================================================
  // Hunt Association
  // ============================================================

  /// Link a marker to a hunt
  Future<CustomMarker> linkMarkerToHunt(
    String markerId,
    String huntId,
  ) async {
    final marker = await getMarker(markerId);
    if (marker == null) {
      throw Exception('Marker not found: $markerId');
    }

    return updateMarker(marker.copyWith(huntId: huntId));
  }

  /// Unlink a marker from its hunt
  Future<CustomMarker> unlinkMarkerFromHunt(String markerId) async {
    final marker = await getMarker(markerId);
    if (marker == null) {
      throw Exception('Marker not found: $markerId');
    }

    return updateMarker(marker.copyWith(clearHuntId: true));
  }

  // ============================================================
  // Category Operations
  // ============================================================

  /// Update a marker's category
  Future<CustomMarker> updateMarkerCategory(
    String markerId,
    CustomMarkerCategory newCategory, {
    bool updateColorToDefault = true,
  }) async {
    final marker = await getMarker(markerId);
    if (marker == null) {
      throw Exception('Marker not found: $markerId');
    }

    return updateMarker(
      marker.copyWith(
        category: newCategory,
        colorArgb: updateColorToDefault ? newCategory.defaultColor.toARGB32() : null,
      ),
    );
  }

  // ============================================================
  // Bulk Operations
  // ============================================================

  /// Delete all markers (for debugging/reset purposes)
  Future<void> deleteAllMarkers() async {
    final markers = await getAllMarkers();
    for (final marker in markers) {
      await deleteMarker(marker.id);
    }
    debugPrint('Deleted all ${markers.length} custom markers');
  }

  /// Get markers by category
  Future<List<CustomMarker>> getMarkersByCategory(
    CustomMarkerCategory category,
  ) async {
    final allMarkers = await getAllMarkers();
    return allMarkers.where((m) => m.category == category).toList();
  }

  // ============================================================
  // Export Operations (Future community sharing)
  // ============================================================

  /// Export markers for community sharing (future feature)
  ///
  /// Returns a map that can be serialized to JSON for upload.
  /// Only exports markers with shareStatus == shared or explicitly selected.
  Future<List<Map<String, dynamic>>> exportMarkersForCommunity(
    List<String> markerIds,
  ) async {
    final exportData = <Map<String, dynamic>>[];

    for (final markerId in markerIds) {
      final marker = await getMarker(markerId);
      if (marker == null) continue;

      // Only include non-sensitive fields for community export
      exportData.add({
        'name': marker.name,
        'notes': marker.notes,
        'latitude': marker.latitude,
        'longitude': marker.longitude,
        'category': marker.category.name,
        'createdAt': marker.createdAt.toIso8601String(),
      });
    }

    return exportData;
  }
}
