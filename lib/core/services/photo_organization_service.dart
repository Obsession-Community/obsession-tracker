import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/photo_capture_service.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Photo album model
@immutable
class PhotoAlbum {
  const PhotoAlbum({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.coverPhotoId,
    this.color,
    this.isSystem = false,
    this.sortOrder = 0,
  });

  factory PhotoAlbum.fromMap(Map<String, dynamic> map) => PhotoAlbum(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
        coverPhotoId: map['cover_photo_id'] as String?,
        color: map['color'] as String?,
        isSystem: (map['is_system'] as int) == 1,
        sortOrder: map['sort_order'] as int,
      );

  /// Album ID
  final String id;

  /// Album name
  final String name;

  /// Album description
  final String description;

  /// When album was created
  final DateTime createdAt;

  /// When album was last updated
  final DateTime updatedAt;

  /// ID of photo to use as cover
  final String? coverPhotoId;

  /// Album color (hex string)
  final String? color;

  /// Whether this is a system-generated album
  final bool isSystem;

  /// Sort order for display
  final int sortOrder;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'cover_photo_id': coverPhotoId,
        'color': color,
        'is_system': isSystem ? 1 : 0,
        'sort_order': sortOrder,
      };

  PhotoAlbum copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? coverPhotoId,
    String? color,
    bool? isSystem,
    int? sortOrder,
  }) =>
      PhotoAlbum(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        coverPhotoId: coverPhotoId ?? this.coverPhotoId,
        color: color ?? this.color,
        isSystem: isSystem ?? this.isSystem,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

/// Photo category model
@immutable
class PhotoCategory {
  const PhotoCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.parentId,
    this.isSystem = false,
    this.sortOrder = 0,
  });

  factory PhotoCategory.fromMap(Map<String, dynamic> map) => PhotoCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String,
        icon: map['icon'] as String,
        color: map['color'] as String,
        parentId: map['parent_id'] as String?,
        isSystem: (map['is_system'] as int) == 1,
        sortOrder: map['sort_order'] as int,
      );

  /// Category ID
  final String id;

  /// Category name
  final String name;

  /// Category description
  final String description;

  /// Icon name/code
  final String icon;

  /// Category color (hex string)
  final String color;

  /// Parent category ID (for hierarchical categories)
  final String? parentId;

  /// Whether this is a system category
  final bool isSystem;

  /// Sort order for display
  final int sortOrder;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'color': color,
        'parent_id': parentId,
        'is_system': isSystem ? 1 : 0,
        'sort_order': sortOrder,
      };
}

/// Photo tag model
@immutable
class PhotoTag {
  const PhotoTag({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
    this.description,
    this.usageCount = 0,
  });

  factory PhotoTag.fromMap(Map<String, dynamic> map) => PhotoTag(
        id: map['id'] as String,
        name: map['name'] as String,
        color: map['color'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        description: map['description'] as String?,
        usageCount: map['usage_count'] as int,
      );

  /// Tag ID
  final String id;

  /// Tag name
  final String name;

  /// Tag color (hex string)
  final String color;

  /// When tag was created
  final DateTime createdAt;

  /// Tag description
  final String? description;

  /// Number of photos using this tag
  final int usageCount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color,
        'created_at': createdAt.millisecondsSinceEpoch,
        'description': description,
        'usage_count': usageCount,
      };
}

/// Album membership model
@immutable
class AlbumMembership {
  const AlbumMembership({
    required this.albumId,
    required this.photoId,
    required this.addedAt,
    this.sortOrder = 0,
  });

  factory AlbumMembership.fromMap(Map<String, dynamic> map) => AlbumMembership(
        albumId: map['album_id'] as String,
        photoId: map['photo_id'] as String,
        addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
        sortOrder: map['sort_order'] as int,
      );

  /// Album ID
  final String albumId;

  /// Photo ID
  final String photoId;

  /// When photo was added to album
  final DateTime addedAt;

  /// Sort order within album
  final int sortOrder;

  Map<String, dynamic> toMap() => {
        'album_id': albumId,
        'photo_id': photoId,
        'added_at': addedAt.millisecondsSinceEpoch,
        'sort_order': sortOrder,
      };
}

/// Smart album criteria
@immutable
class SmartAlbumCriteria {
  const SmartAlbumCriteria({
    required this.rules,
    this.matchAll = true,
  });

  factory SmartAlbumCriteria.fromMap(Map<String, dynamic> map) =>
      SmartAlbumCriteria(
        rules: (map['rules'] as List<dynamic>)
            .map((r) => SmartAlbumRule.fromMap(r as Map<String, dynamic>))
            .toList(),
        matchAll: map['match_all'] as bool,
      );

  /// List of rules for smart album
  final List<SmartAlbumRule> rules;

  /// Whether all rules must match (AND) or any rule (OR)
  final bool matchAll;

  Map<String, dynamic> toMap() => {
        'rules': rules.map((r) => r.toMap()).toList(),
        'match_all': matchAll,
      };
}

/// Smart album rule
@immutable
class SmartAlbumRule {
  const SmartAlbumRule({
    required this.field,
    required this.operator,
    required this.value,
  });

  factory SmartAlbumRule.fromMap(Map<String, dynamic> map) => SmartAlbumRule(
        field: map['field'] as String,
        operator: SmartAlbumOperator.values.firstWhere(
          (e) => e.name == map['operator'],
        ),
        value: map['value'] as String,
      );

  /// Field to check (e.g., 'created_at', 'tags', 'rating')
  final String field;

  /// Comparison operator
  final SmartAlbumOperator operator;

  /// Value to compare against
  final String value;

  Map<String, dynamic> toMap() => {
        'field': field,
        'operator': operator.name,
        'value': value,
      };
}

/// Smart album operators
enum SmartAlbumOperator {
  equals,
  notEquals,
  contains,
  notContains,
  greaterThan,
  lessThan,
  greaterThanOrEqual,
  lessThanOrEqual,
  isNull,
  isNotNull,
}

/// Organization statistics
@immutable
class OrganizationStats {
  const OrganizationStats({
    required this.totalPhotos,
    required this.organizedPhotos,
    required this.unorganizedPhotos,
    required this.totalAlbums,
    required this.totalTags,
    required this.totalCategories,
    required this.averagePhotosPerAlbum,
    required this.averageTagsPerPhoto,
  });

  final int totalPhotos;
  final int organizedPhotos;
  final int unorganizedPhotos;
  final int totalAlbums;
  final int totalTags;
  final int totalCategories;
  final double averagePhotosPerAlbum;
  final double averageTagsPerPhoto;

  double get organizationPercentage =>
      totalPhotos > 0 ? (organizedPhotos / totalPhotos) * 100 : 0.0;
}

/// Service for photo organization with albums, tags, and categories
class PhotoOrganizationService {
  factory PhotoOrganizationService() =>
      _instance ??= PhotoOrganizationService._();
  PhotoOrganizationService._();
  static PhotoOrganizationService? _instance;

  final DatabaseService _databaseService = DatabaseService();
  final PhotoCaptureService _photoCaptureService = PhotoCaptureService();

  /// Initialize the service and create necessary tables
  Future<void> initialize() async {
    try {
      final Database db = await _databaseService.database;

      // Create albums table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS photo_albums (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          cover_photo_id TEXT,
          color TEXT,
          is_system INTEGER DEFAULT 0,
          sort_order INTEGER DEFAULT 0
        )
      ''');

      // Create categories table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS photo_categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT NOT NULL,
          icon TEXT NOT NULL,
          color TEXT NOT NULL,
          parent_id TEXT,
          is_system INTEGER DEFAULT 0,
          sort_order INTEGER DEFAULT 0,
          FOREIGN KEY (parent_id) REFERENCES photo_categories (id)
        )
      ''');

      // Create tags table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS photo_tags (
          id TEXT PRIMARY KEY,
          name TEXT UNIQUE NOT NULL,
          color TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          description TEXT,
          usage_count INTEGER DEFAULT 0
        )
      ''');

      // Create album memberships table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS album_memberships (
          album_id TEXT NOT NULL,
          photo_id TEXT NOT NULL,
          added_at INTEGER NOT NULL,
          sort_order INTEGER DEFAULT 0,
          PRIMARY KEY (album_id, photo_id),
          FOREIGN KEY (album_id) REFERENCES photo_albums (id) ON DELETE CASCADE
        )
      ''');

      // Create photo categories assignments table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS photo_category_assignments (
          photo_id TEXT NOT NULL,
          category_id TEXT NOT NULL,
          assigned_at INTEGER NOT NULL,
          PRIMARY KEY (photo_id, category_id),
          FOREIGN KEY (category_id) REFERENCES photo_categories (id) ON DELETE CASCADE
        )
      ''');

      // Create smart albums table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS smart_albums (
          album_id TEXT PRIMARY KEY,
          criteria TEXT NOT NULL,
          last_updated INTEGER NOT NULL,
          FOREIGN KEY (album_id) REFERENCES photo_albums (id) ON DELETE CASCADE
        )
      ''');

      // Create system albums and categories
      await _createSystemAlbumsAndCategories();

      debugPrint('PhotoOrganizationService initialized');
    } catch (e) {
      debugPrint('Error initializing PhotoOrganizationService: $e');
    }
  }

  /// Create system albums and categories
  Future<void> _createSystemAlbumsAndCategories() async {
    // Create system albums
    final List<PhotoAlbum> systemAlbums = [
      PhotoAlbum(
        id: 'favorites',
        name: 'Favorites',
        description: 'Your favorite photos',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        color: '#FF5722',
        isSystem: true,
      ),
      PhotoAlbum(
        id: 'recent',
        name: 'Recent',
        description: 'Recently captured photos',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        color: '#2196F3',
        isSystem: true,
        sortOrder: 1,
      ),
      PhotoAlbum(
        id: 'unorganized',
        name: 'Unorganized',
        description: 'Photos not yet organized',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        color: '#9E9E9E',
        isSystem: true,
        sortOrder: 999,
      ),
    ];

    for (final PhotoAlbum album in systemAlbums) {
      await _saveAlbum(album);
    }

    // Create system categories
    final List<PhotoCategory> systemCategories = [
      const PhotoCategory(
        id: 'wildlife',
        name: 'Wildlife',
        description: 'Animals and nature',
        icon: 'pets',
        color: '#4CAF50',
        isSystem: true,
      ),
      const PhotoCategory(
        id: 'landscape',
        name: 'Landscape',
        description: 'Scenic views and landscapes',
        icon: 'landscape',
        color: '#2196F3',
        isSystem: true,
        sortOrder: 1,
      ),
      const PhotoCategory(
        id: 'hiking',
        name: 'Hiking',
        description: 'Hiking and trail photos',
        icon: 'hiking',
        color: '#FF9800',
        isSystem: true,
        sortOrder: 2,
      ),
      const PhotoCategory(
        id: 'camping',
        name: 'Camping',
        description: 'Camping and outdoor activities',
        icon: 'outdoor_grill',
        color: '#795548',
        isSystem: true,
        sortOrder: 3,
      ),
      const PhotoCategory(
        id: 'water',
        name: 'Water',
        description: 'Lakes, rivers, and water features',
        icon: 'water',
        color: '#00BCD4',
        isSystem: true,
        sortOrder: 4,
      ),
    ];

    for (final PhotoCategory category in systemCategories) {
      await _saveCategory(category);
    }
  }

  // MARK: - Album Management

  /// Create a new album
  Future<PhotoAlbum?> createAlbum({
    required String name,
    required String description,
    String? color,
    String? coverPhotoId,
  }) async {
    try {
      final String albumId = 'album_${DateTime.now().millisecondsSinceEpoch}';
      final DateTime now = DateTime.now();

      final PhotoAlbum album = PhotoAlbum(
        id: albumId,
        name: name,
        description: description,
        createdAt: now,
        updatedAt: now,
        coverPhotoId: coverPhotoId,
        color: color ?? '#2196F3',
      );

      final bool success = await _saveAlbum(album);
      return success ? album : null;
    } catch (e) {
      debugPrint('Error creating album: $e');
      return null;
    }
  }

  /// Save album to database
  Future<bool> _saveAlbum(PhotoAlbum album) async {
    try {
      final Database db = await _databaseService.database;
      await db.insert(
        'photo_albums',
        album.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      debugPrint('Error saving album: $e');
      return false;
    }
  }

  /// Get all albums
  Future<List<PhotoAlbum>> getAlbums() async {
    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'photo_albums',
        orderBy: 'sort_order ASC, name ASC',
      );

      return maps.map(PhotoAlbum.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting albums: $e');
      return <PhotoAlbum>[];
    }
  }

  /// Get album by ID
  Future<PhotoAlbum?> getAlbum(String albumId) async {
    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'photo_albums',
        where: 'id = ?',
        whereArgs: [albumId],
      );

      if (maps.isNotEmpty) {
        return PhotoAlbum.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting album: $e');
      return null;
    }
  }

  /// Update album
  Future<bool> updateAlbum(PhotoAlbum album) async {
    try {
      final PhotoAlbum updatedAlbum = album.copyWith(
        updatedAt: DateTime.now(),
      );
      return await _saveAlbum(updatedAlbum);
    } catch (e) {
      debugPrint('Error updating album: $e');
      return false;
    }
  }

  /// Delete album
  Future<bool> deleteAlbum(String albumId) async {
    try {
      final Database db = await _databaseService.database;

      // Don't allow deletion of system albums
      final PhotoAlbum? album = await getAlbum(albumId);
      if (album?.isSystem == true) {
        debugPrint('Cannot delete system album: $albumId');
        return false;
      }

      await db.delete(
        'photo_albums',
        where: 'id = ?',
        whereArgs: [albumId],
      );

      debugPrint('Deleted album: $albumId');
      return true;
    } catch (e) {
      debugPrint('Error deleting album: $e');
      return false;
    }
  }

  /// Add photo to album
  Future<bool> addPhotoToAlbum(String photoId, String albumId) async {
    try {
      final Database db = await _databaseService.database;

      final AlbumMembership membership = AlbumMembership(
        albumId: albumId,
        photoId: photoId,
        addedAt: DateTime.now(),
      );

      await db.insert(
        'album_memberships',
        membership.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('Added photo $photoId to album $albumId');
      return true;
    } catch (e) {
      debugPrint('Error adding photo to album: $e');
      return false;
    }
  }

  /// Remove photo from album
  Future<bool> removePhotoFromAlbum(String photoId, String albumId) async {
    try {
      final Database db = await _databaseService.database;

      await db.delete(
        'album_memberships',
        where: 'photo_id = ? AND album_id = ?',
        whereArgs: [photoId, albumId],
      );

      debugPrint('Removed photo $photoId from album $albumId');
      return true;
    } catch (e) {
      debugPrint('Error removing photo from album: $e');
      return false;
    }
  }

  /// Get photos in album
  Future<List<PhotoWaypoint>> getPhotosInAlbum(String albumId) async {
    try {
      final Database db = await _databaseService.database;

      // Handle system albums with special logic
      if (albumId == 'favorites') {
        return await _getFavoritePhotos();
      } else if (albumId == 'recent') {
        return await _getRecentPhotos();
      } else if (albumId == 'unorganized') {
        return await _getUnorganizedPhotos();
      }

      // Regular album
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT pw.* FROM photo_waypoints pw
        INNER JOIN album_memberships am ON pw.id = am.photo_id
        WHERE am.album_id = ?
        ORDER BY am.sort_order ASC, am.added_at DESC
      ''', [albumId]);

      return maps.map(PhotoWaypoint.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting photos in album: $e');
      return <PhotoWaypoint>[];
    }
  }

  /// Get favorite photos
  Future<List<PhotoWaypoint>> _getFavoritePhotos() async {
    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT pw.* FROM photo_waypoints pw
        INNER JOIN photo_metadata pm ON pw.id = pm.photo_waypoint_id
        WHERE pm.key = ? AND pm.value = ?
        ORDER BY pw.created_at DESC
      ''', [CustomKeys.favorite, 'true']);

      return maps.map(PhotoWaypoint.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting favorite photos: $e');
      return <PhotoWaypoint>[];
    }
  }

  /// Get recent photos (last 30 days)
  Future<List<PhotoWaypoint>> _getRecentPhotos() async {
    try {
      final Database db = await _databaseService.database;
      final DateTime cutoff = DateTime.now().subtract(const Duration(days: 30));

      final List<Map<String, dynamic>> maps = await db.query(
        'photo_waypoints',
        where: 'created_at > ?',
        whereArgs: [cutoff.millisecondsSinceEpoch],
        orderBy: 'created_at DESC',
        limit: 100,
      );

      return maps.map(PhotoWaypoint.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting recent photos: $e');
      return <PhotoWaypoint>[];
    }
  }

  /// Get unorganized photos (not in any user album)
  Future<List<PhotoWaypoint>> _getUnorganizedPhotos() async {
    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT pw.* FROM photo_waypoints pw
        LEFT JOIN album_memberships am ON pw.id = am.photo_id
        LEFT JOIN photo_albums pa ON am.album_id = pa.id
        WHERE am.photo_id IS NULL OR pa.is_system = 1
        ORDER BY pw.created_at DESC
      ''');

      return maps.map(PhotoWaypoint.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting unorganized photos: $e');
      return <PhotoWaypoint>[];
    }
  }

  // MARK: - Category Management

  /// Save category to database
  Future<bool> _saveCategory(PhotoCategory category) async {
    try {
      final Database db = await _databaseService.database;
      await db.insert(
        'photo_categories',
        category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      debugPrint('Error saving category: $e');
      return false;
    }
  }

  /// Get all categories
  Future<List<PhotoCategory>> getCategories() async {
    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'photo_categories',
        orderBy: 'sort_order ASC, name ASC',
      );

      return maps.map(PhotoCategory.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting categories: $e');
      return <PhotoCategory>[];
    }
  }

  /// Assign category to photo
  Future<bool> assignCategoryToPhoto(String photoId, String categoryId) async {
    try {
      final Database db = await _databaseService.database;

      await db.insert(
        'photo_category_assignments',
        {
          'photo_id': photoId,
          'category_id': categoryId,
          'assigned_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('Assigned category $categoryId to photo $photoId');
      return true;
    } catch (e) {
      debugPrint('Error assigning category to photo: $e');
      return false;
    }
  }

  // MARK: - Tag Management

  /// Create or get existing tag
  Future<PhotoTag?> createOrGetTag(String tagName, {String? color}) async {
    try {
      final Database db = await _databaseService.database;

      // Check if tag already exists
      final List<Map<String, dynamic>> existing = await db.query(
        'photo_tags',
        where: 'name = ?',
        whereArgs: [tagName.toLowerCase()],
      );

      if (existing.isNotEmpty) {
        return PhotoTag.fromMap(existing.first);
      }

      // Create new tag
      final String tagId = 'tag_${DateTime.now().millisecondsSinceEpoch}';
      final PhotoTag tag = PhotoTag(
        id: tagId,
        name: tagName,
        color: color ?? '#2196F3',
        createdAt: DateTime.now(),
      );

      await db.insert('photo_tags', tag.toMap());
      debugPrint('Created new tag: $tagName');
      return tag;
    } catch (e) {
      debugPrint('Error creating/getting tag: $e');
      return null;
    }
  }

  /// Get all tags
  Future<List<PhotoTag>> getTags() async {
    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'photo_tags',
        orderBy: 'usage_count DESC, name ASC',
      );

      return maps.map(PhotoTag.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting tags: $e');
      return <PhotoTag>[];
    }
  }

  /// Update tag usage count

  // MARK: - Smart Albums

  /// Create smart album
  Future<PhotoAlbum?> createSmartAlbum({
    required String name,
    required String description,
    required SmartAlbumCriteria criteria,
    String? color,
  }) async {
    try {
      // Create the album first
      final PhotoAlbum? album = await createAlbum(
        name: name,
        description: description,
        color: color,
      );

      if (album == null) return null;

      // Save smart album criteria
      final Database db = await _databaseService.database;
      await db.insert('smart_albums', {
        'album_id': album.id,
        'criteria': jsonEncode(criteria.toMap()),
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      });

      // Update smart album contents
      await updateSmartAlbum(album.id);

      debugPrint('Created smart album: ${album.name}');
      return album;
    } catch (e) {
      debugPrint('Error creating smart album: $e');
      return null;
    }
  }

  /// Update smart album contents
  Future<bool> updateSmartAlbum(String albumId) async {
    try {
      final Database db = await _databaseService.database;

      // Get smart album criteria
      final List<Map<String, dynamic>> criteriaRows = await db.query(
        'smart_albums',
        where: 'album_id = ?',
        whereArgs: [albumId],
      );

      if (criteriaRows.isEmpty) {
        debugPrint('No criteria found for smart album: $albumId');
        return false;
      }

      final SmartAlbumCriteria criteria = SmartAlbumCriteria.fromMap(
        jsonDecode(criteriaRows.first['criteria'] as String)
            as Map<String, dynamic>,
      );

      // Clear existing memberships
      await db.delete(
        'album_memberships',
        where: 'album_id = ?',
        whereArgs: [albumId],
      );

      // Find matching photos
      final List<PhotoWaypoint> matchingPhotos =
          await _findPhotosMatchingCriteria(criteria);

      // Add matching photos to album
      for (final PhotoWaypoint photo in matchingPhotos) {
        await addPhotoToAlbum(photo.id, albumId);
      }

      // Update last updated timestamp
      await db.update(
        'smart_albums',
        {'last_updated': DateTime.now().millisecondsSinceEpoch},
        where: 'album_id = ?',
        whereArgs: [albumId],
      );

      debugPrint(
          'Updated smart album: $albumId with ${matchingPhotos.length} photos');
      return true;
    } catch (e) {
      debugPrint('Error updating smart album: $e');
      return false;
    }
  }

  /// Find photos matching smart album criteria
  Future<List<PhotoWaypoint>> _findPhotosMatchingCriteria(
      SmartAlbumCriteria criteria) async {
    try {
      // TODO(dev): Implement smart album criteria matching
      // This would involve complex SQL queries based on the rules
      debugPrint('Smart album criteria matching not yet implemented');
      return <PhotoWaypoint>[];
    } catch (e) {
      debugPrint('Error finding photos matching criteria: $e');
      return <PhotoWaypoint>[];
    }
  }

  // MARK: - Search and Organization

  /// Search photos by various criteria
  Future<List<PhotoWaypoint>> searchPhotos({
    String? query,
    List<String>? tags,
    List<String>? categories,
    List<String>? albums,
    DateTime? startDate,
    DateTime? endDate,
    int? minRating,
    bool? isFavorite,
  }) async {
    try {
      final Database db = await _databaseService.database;

      // Build complex query based on criteria
      String whereClause = '1=1';
      final List<dynamic> whereArgs = <dynamic>[];

      // Date range
      if (startDate != null) {
        whereClause += ' AND pw.created_at >= ?';
        whereArgs.add(startDate.millisecondsSinceEpoch);
      }
      if (endDate != null) {
        whereClause += ' AND pw.created_at <= ?';
        whereArgs.add(endDate.millisecondsSinceEpoch);
      }

      // Text search in metadata
      if (query != null && query.isNotEmpty) {
        whereClause += '''
 AND EXISTS (
          SELECT 1 FROM photo_metadata pm
          WHERE pm.photo_waypoint_id = pw.id
          AND (pm.key LIKE ? OR pm.value LIKE ?)
        )''';
        whereArgs.add('%$query%');
        whereArgs.add('%$query%');
      }

      // Favorite filter
      if (isFavorite != null) {
        if (isFavorite) {
          whereClause += '''
 AND EXISTS (
            SELECT 1 FROM photo_metadata pm
            WHERE pm.photo_waypoint_id = pw.id
            AND pm.key = ? AND pm.value = ?
          )''';
          whereArgs.add(CustomKeys.favorite);
          whereArgs.add('true');
        } else {
          whereClause += '''
 AND NOT EXISTS (
            SELECT 1 FROM photo_metadata pm
            WHERE pm.photo_waypoint_id = pw.id
            AND pm.key = ? AND pm.value = ?
          )''';
          whereArgs.add(CustomKeys.favorite);
          whereArgs.add('true');
        }
      }

      // Rating filter
      if (minRating != null) {
        whereClause += '''
 AND EXISTS (
          SELECT 1 FROM photo_metadata pm
          WHERE pm.photo_waypoint_id = pw.id
          AND pm.key = ? AND CAST(pm.value AS INTEGER) >= ?
        )''';
        whereArgs.add(CustomKeys.rating);
        whereArgs.add(minRating);
      }

      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT DISTINCT pw.* FROM photo_waypoints pw
        WHERE $whereClause
        ORDER BY pw.created_at DESC
      ''', whereArgs);

      return maps.map(PhotoWaypoint.fromMap).toList();
    } catch (e) {
      debugPrint('Error searching photos: $e');
      return <PhotoWaypoint>[];
    }
  }

  /// Get organization statistics
  Future<OrganizationStats> getOrganizationStats() async {
    try {
      final Database db = await _databaseService.database;

      // Get total photos
      final List<Map<String, dynamic>> totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM photo_waypoints',
      );
      final int totalPhotos = totalResult.first['count'] as int;

      // Get organized photos (in user albums)
      final List<Map<String, dynamic>> organizedResult = await db.rawQuery('''
        SELECT COUNT(DISTINCT am.photo_id) as count
        FROM album_memberships am
        INNER JOIN photo_albums pa ON am.album_id = pa.id
        WHERE pa.is_system = 0
      ''');
      final int organizedPhotos = organizedResult.first['count'] as int;

      // Get total albums
      final List<Map<String, dynamic>> albumsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM photo_albums WHERE is_system = 0',
      );
      final int totalAlbums = albumsResult.first['count'] as int;

      // Get total tags
      final List<Map<String, dynamic>> tagsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM photo_tags',
      );
      final int totalTags = tagsResult.first['count'] as int;

      // Get total categories
      final List<Map<String, dynamic>> categoriesResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM photo_categories WHERE is_system = 0',
      );
      final int totalCategories = categoriesResult.first['count'] as int;

      // Calculate averages
      final double averagePhotosPerAlbum =
          totalAlbums > 0 ? organizedPhotos / totalAlbums : 0.0;

      // Get average tags per photo
      final List<Map<String, dynamic>> tagCountResult = await db.rawQuery('''
        SELECT AVG(tag_count) as avg_tags FROM (
          SELECT COUNT(*) as tag_count
          FROM photo_metadata
          WHERE key = ?
          GROUP BY photo_waypoint_id
        )
      ''', [CustomKeys.tags]);

      final double averageTagsPerPhoto =
          tagCountResult.first['avg_tags'] as double? ?? 0.0;

      return OrganizationStats(
        totalPhotos: totalPhotos,
        organizedPhotos: organizedPhotos,
        unorganizedPhotos: totalPhotos - organizedPhotos,
        totalAlbums: totalAlbums,
        totalTags: totalTags,
        totalCategories: totalCategories,
        averagePhotosPerAlbum: averagePhotosPerAlbum,
        averageTagsPerPhoto: averageTagsPerPhoto,
      );
    } catch (e) {
      debugPrint('Error getting organization stats: $e');
      return const OrganizationStats(
        totalPhotos: 0,
        organizedPhotos: 0,
        unorganizedPhotos: 0,
        totalAlbums: 0,
        totalTags: 0,
        totalCategories: 0,
        averagePhotosPerAlbum: 0.0,
        averageTagsPerPhoto: 0.0,
      );
    }
  }

  /// Auto-organize photos based on metadata
  Future<int> autoOrganizePhotos() async {
    try {
      int organizedCount = 0;

      // Get unorganized photos
      final List<PhotoWaypoint> unorganizedPhotos =
          await _getUnorganizedPhotos();

      for (final PhotoWaypoint photo in unorganizedPhotos) {
        final List<PhotoMetadata> metadata =
            await _photoCaptureService.getPhotoMetadata(photo.id);

        // Auto-categorize based on metadata
        final List<String> suggestedCategories = _suggestCategories(metadata);
        for (final String categoryId in suggestedCategories) {
          await assignCategoryToPhoto(photo.id, categoryId);
        }

        // Auto-tag based on metadata
        final List<String> suggestedTags = _suggestTags(metadata);
        if (suggestedTags.isNotEmpty) {
          // TODO(dev): Update tags metadata
          // This would require integration with metadata editor service
          debugPrint(
              'Suggested tags for photo ${photo.id}: ${suggestedTags.join(', ')}');
        }

        if (suggestedCategories.isNotEmpty || suggestedTags.isNotEmpty) {
          organizedCount++;
        }
      }

      debugPrint('Auto-organized $organizedCount photos');
      return organizedCount;
    } catch (e) {
      debugPrint('Error auto-organizing photos: $e');
      return 0;
    }
  }

  /// Suggest categories based on metadata
  List<String> _suggestCategories(List<PhotoMetadata> metadata) {
    final List<String> suggestions = <String>[];

    for (final PhotoMetadata meta in metadata) {
      final String value = meta.value?.toLowerCase() ?? '';

      // Wildlife detection
      if (value.contains('animal') ||
          value.contains('bird') ||
          value.contains('wildlife') ||
          value.contains('deer')) {
        suggestions.add('wildlife');
      }

      // Landscape detection
      if (value.contains('mountain') ||
          value.contains('valley') ||
          value.contains('vista') ||
          value.contains('landscape')) {
        suggestions.add('landscape');
      }

      // Hiking detection
      if (value.contains('trail') ||
          value.contains('hike') ||
          value.contains('hiking') ||
          value.contains('trek')) {
        suggestions.add('hiking');
      }

      // Water detection
      if (value.contains('lake') ||
          value.contains('river') ||
          value.contains('stream') ||
          value.contains('water')) {
        suggestions.add('water');
      }

      // Camping detection
      if (value.contains('camp') ||
          value.contains('tent') ||
          value.contains('fire') ||
          value.contains('camping')) {
        suggestions.add('camping');
      }
    }

    return suggestions.toSet().toList(); // Remove duplicates
  }

  /// Suggest tags based on metadata
  List<String> _suggestTags(List<PhotoMetadata> metadata) {
    final List<String> suggestions = <String>[];

    for (final PhotoMetadata meta in metadata) {
      if (meta.isCustomData) {
        final String value = meta.value?.toLowerCase() ?? '';

        // Extract meaningful words as potential tags
        final List<String> words = value
            .split(RegExp(r'[,\s]+'))
            .where((word) => word.length > 2)
            .toList();

        suggestions.addAll(words);
      }
    }

    return suggestions.toSet().toList(); // Remove duplicates
  }

  /// Bulk organize photos into albums
  Future<int> bulkOrganizeIntoAlbums({
    required List<String> photoIds,
    required String albumId,
  }) async {
    try {
      int organizedCount = 0;

      for (final String photoId in photoIds) {
        final bool success = await addPhotoToAlbum(photoId, albumId);
        if (success) {
          organizedCount++;
        }
      }

      debugPrint('Bulk organized $organizedCount photos into album $albumId');
      return organizedCount;
    } catch (e) {
      debugPrint('Error bulk organizing photos: $e');
      return 0;
    }
  }

  /// Get album photo count
  Future<int> getAlbumPhotoCount(String albumId) async {
    try {
      final Database db = await _databaseService.database;

      // Handle system albums
      if (albumId == 'favorites') {
        final List<Map<String, dynamic>> result = await db.rawQuery('''
          SELECT COUNT(*) as count FROM photo_metadata
          WHERE key = ? AND value = ?
        ''', [CustomKeys.favorite, 'true']);
        return result.first['count'] as int;
      } else if (albumId == 'recent') {
        final DateTime cutoff =
            DateTime.now().subtract(const Duration(days: 30));
        final List<Map<String, dynamic>> result = await db.query(
          'photo_waypoints',
          columns: ['COUNT(*) as count'],
          where: 'created_at > ?',
          whereArgs: [cutoff.millisecondsSinceEpoch],
        );
        return result.first['count'] as int;
      } else if (albumId == 'unorganized') {
        final List<Map<String, dynamic>> result = await db.rawQuery('''
          SELECT COUNT(*) as count FROM photo_waypoints pw
          LEFT JOIN album_memberships am ON pw.id = am.photo_id
          LEFT JOIN photo_albums pa ON am.album_id = pa.id
          WHERE am.photo_id IS NULL OR pa.is_system = 1
        ''');
        return result.first['count'] as int;
      }

      // Regular album
      final List<Map<String, dynamic>> result = await db.query(
        'album_memberships',
        columns: ['COUNT(*) as count'],
        where: 'album_id = ?',
        whereArgs: [albumId],
      );

      return result.first['count'] as int;
    } catch (e) {
      debugPrint('Error getting album photo count: $e');
      return 0;
    }
  }

  /// Export organization data
  Future<Map<String, dynamic>> exportOrganizationData() async {
    try {
      final List<PhotoAlbum> albums = await getAlbums();
      final List<PhotoCategory> categories = await getCategories();
      final List<PhotoTag> tags = await getTags();

      return <String, dynamic>{
        'export_date': DateTime.now().toIso8601String(),
        'albums': albums.map((a) => a.toMap()).toList(),
        'categories': categories.map((c) => c.toMap()).toList(),
        'tags': tags.map((t) => t.toMap()).toList(),
        'version': '1.0',
      };
    } catch (e) {
      debugPrint('Error exporting organization data: $e');
      return <String, dynamic>{};
    }
  }

  /// Import organization data
  Future<bool> importOrganizationData(Map<String, dynamic> data) async {
    try {
      // Import albums
      if (data.containsKey('albums')) {
        final List<dynamic> albumsData = data['albums'] as List<dynamic>;
        for (final dynamic albumData in albumsData) {
          final PhotoAlbum album =
              PhotoAlbum.fromMap(albumData as Map<String, dynamic>);
          if (!album.isSystem) {
            // Don't import system albums
            await _saveAlbum(album);
          }
        }
      }

      // Import categories
      if (data.containsKey('categories')) {
        final List<dynamic> categoriesData =
            data['categories'] as List<dynamic>;
        for (final dynamic categoryData in categoriesData) {
          final PhotoCategory category =
              PhotoCategory.fromMap(categoryData as Map<String, dynamic>);
          if (!category.isSystem) {
            // Don't import system categories
            await _saveCategory(category);
          }
        }
      }

      // Import tags
      if (data.containsKey('tags')) {
        final List<dynamic> tagsData = data['tags'] as List<dynamic>;
        for (final dynamic tagData in tagsData) {
          final PhotoTag tag =
              PhotoTag.fromMap(tagData as Map<String, dynamic>);
          final Database db = await _databaseService.database;
          await db.insert('photo_tags', tag.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      debugPrint('Successfully imported organization data');
      return true;
    } catch (e) {
      debugPrint('Error importing organization data: $e');
      return false;
    }
  }

  /// Dispose of the service
  void dispose() {
    _instance = null;
  }
}
