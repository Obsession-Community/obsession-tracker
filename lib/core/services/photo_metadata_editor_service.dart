import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/photo_capture_service.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Custom metadata field definition
@immutable
class CustomMetadataField {
  const CustomMetadataField({
    required this.key,
    required this.label,
    required this.type,
    this.defaultValue,
    this.options,
    this.isRequired = false,
    this.description,
    this.validation,
  });

  factory CustomMetadataField.fromMap(Map<String, dynamic> map) =>
      CustomMetadataField(
        key: map['key'] as String,
        label: map['label'] as String,
        type: PhotoMetadataTypeExtension.fromString(map['type'] as String),
        defaultValue: map['default_value'] as String?,
        options: map['options'] != null
            ? List<String>.from(jsonDecode(map['options'] as String) as List)
            : null,
        isRequired: (map['is_required'] as int) == 1,
        description: map['description'] as String?,
        validation: map['validation'] as String?,
      );

  /// Unique key for the field
  final String key;

  /// Display label
  final String label;

  /// Data type
  final PhotoMetadataType type;

  /// Default value
  final String? defaultValue;

  /// Options for dropdown/selection fields
  final List<String>? options;

  /// Whether the field is required
  final bool isRequired;

  /// Field description/help text
  final String? description;

  /// Validation pattern (for string fields)
  final String? validation;

  Map<String, dynamic> toMap() => {
        'key': key,
        'label': label,
        'type': type.name,
        'default_value': defaultValue,
        'options': options != null ? jsonEncode(options) : null,
        'is_required': isRequired ? 1 : 0,
        'description': description,
        'validation': validation,
      };
}

/// Metadata template for common photo types
@immutable
class MetadataTemplate {
  const MetadataTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.fields,
    this.category,
    this.isBuiltIn = false,
  });

  factory MetadataTemplate.fromMap(Map<String, dynamic> map) {
    final List<dynamic> fieldsJson =
        jsonDecode(map['fields'] as String) as List<dynamic>;
    final List<CustomMetadataField> fields = fieldsJson
        .map((f) => CustomMetadataField.fromMap(f as Map<String, dynamic>))
        .toList();

    return MetadataTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      fields: fields,
      category: map['category'] as String?,
      isBuiltIn: (map['is_built_in'] as int) == 1,
    );
  }

  /// Template ID
  final String id;

  /// Template name
  final String name;

  /// Template description
  final String description;

  /// Custom fields in this template
  final List<CustomMetadataField> fields;

  /// Template category
  final String? category;

  /// Whether this is a built-in template
  final bool isBuiltIn;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'fields': jsonEncode(fields.map((f) => f.toMap()).toList()),
        'category': category,
        'is_built_in': isBuiltIn ? 1 : 0,
      };
}

/// Batch metadata operation
@immutable
class BatchMetadataOperation {
  const BatchMetadataOperation({
    required this.type,
    required this.field,
    this.value,
    this.searchValue,
    this.replaceValue,
  });

  /// Operation type
  final BatchMetadataOperationType type;

  /// Target field key
  final String field;

  /// Value to set (for set operations)
  final String? value;

  /// Value to search for (for replace operations)
  final String? searchValue;

  /// Value to replace with (for replace operations)
  final String? replaceValue;
}

/// Types of batch metadata operations
enum BatchMetadataOperationType {
  /// Set a field to a specific value
  set,

  /// Clear a field
  clear,

  /// Find and replace text in a field
  replace,

  /// Add a tag to existing tags
  addTag,

  /// Remove a tag from existing tags
  removeTag,
}

/// Progress callback for metadata operations
typedef MetadataProgressCallback = void Function(
    int completed, int total, String? currentPhoto);

/// Result of a metadata operation
@immutable
class MetadataOperationResult {
  const MetadataOperationResult({
    required this.success,
    this.photosProcessed = 0,
    this.photosModified = 0,
    this.fieldsModified = 0,
    this.error,
  });

  /// Whether the operation was successful
  final bool success;

  /// Number of photos processed
  final int photosProcessed;

  /// Number of photos that were modified
  final int photosModified;

  /// Number of metadata fields modified
  final int fieldsModified;

  /// Error message if failed
  final String? error;
}

/// Service for advanced photo metadata editing and management
class PhotoMetadataEditorService {
  factory PhotoMetadataEditorService() =>
      _instance ??= PhotoMetadataEditorService._();
  PhotoMetadataEditorService._();
  static PhotoMetadataEditorService? _instance;

  final DatabaseService _databaseService = DatabaseService();
  final PhotoCaptureService _photoCaptureService = PhotoCaptureService();

  /// Initialize the service and create necessary tables
  Future<void> initialize() async {
    try {
      final Database db = await _databaseService.database;

      // Create custom metadata fields table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS custom_metadata_fields (
          key TEXT PRIMARY KEY,
          label TEXT NOT NULL,
          type TEXT NOT NULL,
          default_value TEXT,
          options TEXT,
          is_required INTEGER DEFAULT 0,
          description TEXT,
          validation TEXT,
          created_at INTEGER NOT NULL
        )
      ''');

      // Create metadata templates table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS metadata_templates (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT NOT NULL,
          fields TEXT NOT NULL,
          category TEXT,
          is_built_in INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      ''');

      // Create built-in templates
      await _createBuiltInTemplates();

      debugPrint('PhotoMetadataEditorService initialized');
    } catch (e) {
      debugPrint('Error initializing PhotoMetadataEditorService: $e');
    }
  }

  /// Create built-in metadata templates
  Future<void> _createBuiltInTemplates() async {
    final List<MetadataTemplate> builtInTemplates = [
      // Wildlife Photography Template
      const MetadataTemplate(
        id: 'wildlife_photography',
        name: 'Wildlife Photography',
        description: 'Template for wildlife and nature photography',
        category: 'Photography',
        isBuiltIn: true,
        fields: [
          CustomMetadataField(
            key: 'custom_species',
            label: 'Species',
            type: PhotoMetadataType.string,
            description: 'Name of the animal or plant species',
          ),
          CustomMetadataField(
            key: 'custom_behavior',
            label: 'Behavior',
            type: PhotoMetadataType.string,
            description: 'Observed behavior or activity',
          ),
          CustomMetadataField(
            key: 'custom_habitat',
            label: 'Habitat',
            type: PhotoMetadataType.string,
            options: [
              'Forest',
              'Grassland',
              'Wetland',
              'Desert',
              'Mountain',
              'Ocean',
              'River',
              'Lake'
            ],
            description: 'Type of habitat where photo was taken',
          ),
          CustomMetadataField(
            key: 'custom_weather_conditions',
            label: 'Weather',
            type: PhotoMetadataType.string,
            options: ['Sunny', 'Cloudy', 'Overcast', 'Rainy', 'Foggy', 'Snowy'],
            description: 'Weather conditions during photography',
          ),
        ],
      ),

      // Hiking Template
      const MetadataTemplate(
        id: 'hiking_adventure',
        name: 'Hiking Adventure',
        description: 'Template for hiking and outdoor adventure photos',
        category: 'Adventure',
        isBuiltIn: true,
        fields: [
          CustomMetadataField(
            key: 'custom_trail_name',
            label: 'Trail Name',
            type: PhotoMetadataType.string,
            description: 'Name of the hiking trail',
          ),
          CustomMetadataField(
            key: 'custom_difficulty',
            label: 'Difficulty',
            type: PhotoMetadataType.string,
            options: ['Easy', 'Moderate', 'Difficult', 'Expert'],
            description: 'Trail difficulty level',
          ),
          CustomMetadataField(
            key: 'custom_elevation',
            label: 'Elevation (ft)',
            type: PhotoMetadataType.integer,
            description: 'Elevation at photo location',
          ),
          CustomMetadataField(
            key: 'custom_companions',
            label: 'Companions',
            type: PhotoMetadataType.string,
            description: 'People who were with you',
          ),
          CustomMetadataField(
            key: 'custom_gear_used',
            label: 'Gear Used',
            type: PhotoMetadataType.string,
            description: 'Special equipment or gear used',
          ),
        ],
      ),

      // Travel Template
      const MetadataTemplate(
        id: 'travel_photography',
        name: 'Travel Photography',
        description: 'Template for travel and destination photography',
        category: 'Travel',
        isBuiltIn: true,
        fields: [
          CustomMetadataField(
            key: 'custom_destination',
            label: 'Destination',
            type: PhotoMetadataType.string,
            isRequired: true,
            description: 'Travel destination or location name',
          ),
          CustomMetadataField(
            key: 'custom_country',
            label: 'Country',
            type: PhotoMetadataType.string,
            description: 'Country where photo was taken',
          ),
          CustomMetadataField(
            key: 'custom_local_time',
            label: 'Local Time',
            type: PhotoMetadataType.string,
            description: 'Local time when photo was taken',
          ),
          CustomMetadataField(
            key: 'custom_cultural_notes',
            label: 'Cultural Notes',
            type: PhotoMetadataType.string,
            description: 'Cultural context or significance',
          ),
          CustomMetadataField(
            key: 'custom_travel_mode',
            label: 'Travel Mode',
            type: PhotoMetadataType.string,
            options: [
              'Walking',
              'Driving',
              'Flying',
              'Boat',
              'Train',
              'Bicycle'
            ],
            description: 'How you traveled to this location',
          ),
        ],
      ),
    ];

    for (final MetadataTemplate template in builtInTemplates) {
      await _saveTemplate(template);
    }
  }

  /// Save a metadata template
  Future<bool> _saveTemplate(MetadataTemplate template) async {
    try {
      final Database db = await _databaseService.database;

      final Map<String, dynamic> templateMap = template.toMap();
      templateMap['created_at'] = DateTime.now().millisecondsSinceEpoch;

      await db.insert(
        'metadata_templates',
        templateMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return true;
    } catch (e) {
      debugPrint('Error saving template: $e');
      return false;
    }
  }

  /// Get all metadata templates
  Future<List<MetadataTemplate>> getTemplates() async {
    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'metadata_templates',
        orderBy: 'name ASC',
      );

      return maps.map(MetadataTemplate.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting templates: $e');
      return <MetadataTemplate>[];
    }
  }

  /// Get templates by category
  Future<List<MetadataTemplate>> getTemplatesByCategory(String category) async {
    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'metadata_templates',
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'name ASC',
      );

      return maps.map(MetadataTemplate.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting templates by category: $e');
      return <MetadataTemplate>[];
    }
  }

  /// Apply a template to a photo
  Future<bool> applyTemplate({
    required String photoId,
    required String templateId,
    Map<String, String>? fieldValues,
  }) async {
    try {
      final Database db = await _databaseService.database;

      // Get the template
      final List<Map<String, dynamic>> templateMaps = await db.query(
        'metadata_templates',
        where: 'id = ?',
        whereArgs: [templateId],
      );

      if (templateMaps.isEmpty) {
        debugPrint('Template not found: $templateId');
        return false;
      }

      final MetadataTemplate template =
          MetadataTemplate.fromMap(templateMaps.first);

      // Create metadata entries for each field
      for (final CustomMetadataField field in template.fields) {
        final String? value = fieldValues?[field.key] ?? field.defaultValue;

        if (value != null) {
          final PhotoMetadata metadata = PhotoMetadata(
            id: 0, // Will be auto-generated
            photoWaypointId: photoId,
            key: field.key,
            value: value,
            type: field.type,
          );

          await _insertPhotoMetadata(metadata);
        }
      }

      debugPrint('Applied template $templateId to photo $photoId');
      return true;
    } catch (e) {
      debugPrint('Error applying template: $e');
      return false;
    }
  }

  /// Edit metadata for a single photo
  Future<bool> editPhotoMetadata({
    required String photoId,
    required Map<String, String> metadata,
  }) async {
    try {
      for (final MapEntry<String, String> entry in metadata.entries) {
        await _updateOrInsertMetadata(
          photoId: photoId,
          key: entry.key,
          value: entry.value,
        );
      }

      debugPrint('Updated metadata for photo $photoId');
      return true;
    } catch (e) {
      debugPrint('Error editing photo metadata: $e');
      return false;
    }
  }

  /// Batch edit metadata for multiple photos
  Future<MetadataOperationResult> batchEditMetadata({
    required List<String> photoIds,
    required List<BatchMetadataOperation> operations,
    MetadataProgressCallback? onProgress,
  }) async {
    int photosProcessed = 0;
    int photosModified = 0;
    int fieldsModified = 0;

    try {
      for (int i = 0; i < photoIds.length; i++) {
        final String photoId = photoIds[i];
        onProgress?.call(i, photoIds.length, photoId);

        bool photoWasModified = false;

        for (final BatchMetadataOperation operation in operations) {
          final bool fieldModified = await _performBatchOperation(
            photoId: photoId,
            operation: operation,
          );

          if (fieldModified) {
            fieldsModified++;
            photoWasModified = true;
          }
        }

        if (photoWasModified) {
          photosModified++;
        }
        photosProcessed++;
      }

      onProgress?.call(photoIds.length, photoIds.length, null);

      return MetadataOperationResult(
        success: true,
        photosProcessed: photosProcessed,
        photosModified: photosModified,
        fieldsModified: fieldsModified,
      );
    } catch (e) {
      debugPrint('Error in batch metadata edit: $e');
      return MetadataOperationResult(
        success: false,
        photosProcessed: photosProcessed,
        photosModified: photosModified,
        fieldsModified: fieldsModified,
        error: e.toString(),
      );
    }
  }

  /// Perform a single batch operation
  Future<bool> _performBatchOperation({
    required String photoId,
    required BatchMetadataOperation operation,
  }) async {
    try {
      switch (operation.type) {
        case BatchMetadataOperationType.set:
          if (operation.value != null) {
            await _updateOrInsertMetadata(
              photoId: photoId,
              key: operation.field,
              value: operation.value!,
            );
            return true;
          }
          break;

        case BatchMetadataOperationType.clear:
          await _deleteMetadata(photoId: photoId, key: operation.field);
          return true;

        case BatchMetadataOperationType.replace:
          if (operation.searchValue != null && operation.replaceValue != null) {
            return await _replaceInMetadata(
              photoId: photoId,
              key: operation.field,
              searchValue: operation.searchValue!,
              replaceValue: operation.replaceValue!,
            );
          }
          break;

        case BatchMetadataOperationType.addTag:
          if (operation.value != null) {
            return await _addTag(
              photoId: photoId,
              tag: operation.value!,
            );
          }
          break;

        case BatchMetadataOperationType.removeTag:
          if (operation.value != null) {
            return await _removeTag(
              photoId: photoId,
              tag: operation.value!,
            );
          }
          break;
      }

      return false;
    } catch (e) {
      debugPrint('Error performing batch operation: $e');
      return false;
    }
  }

  /// Update or insert metadata
  Future<void> _updateOrInsertMetadata({
    required String photoId,
    required String key,
    required String value,
  }) async {
    final Database db = await _databaseService.database;

    // Check if metadata exists
    final List<Map<String, dynamic>> existing = await db.query(
      'photo_metadata',
      where: 'photo_waypoint_id = ? AND key = ?',
      whereArgs: [photoId, key],
    );

    if (existing.isNotEmpty) {
      // Update existing
      await db.update(
        'photo_metadata',
        {'value': value},
        where: 'photo_waypoint_id = ? AND key = ?',
        whereArgs: [photoId, key],
      );
    } else {
      // Insert new
      final PhotoMetadata metadata = PhotoMetadata.string(
        id: 0,
        photoWaypointId: photoId,
        key: key,
        value: value,
      );
      await _insertPhotoMetadata(metadata);
    }
  }

  /// Delete metadata
  Future<void> _deleteMetadata({
    required String photoId,
    required String key,
  }) async {
    final Database db = await _databaseService.database;
    await db.delete(
      'photo_metadata',
      where: 'photo_waypoint_id = ? AND key = ?',
      whereArgs: [photoId, key],
    );
  }

  /// Replace text in metadata
  Future<bool> _replaceInMetadata({
    required String photoId,
    required String key,
    required String searchValue,
    required String replaceValue,
  }) async {
    final Database db = await _databaseService.database;

    final List<Map<String, dynamic>> existing = await db.query(
      'photo_metadata',
      where: 'photo_waypoint_id = ? AND key = ?',
      whereArgs: [photoId, key],
    );

    if (existing.isNotEmpty) {
      final String currentValue = existing.first['value'] as String? ?? '';
      if (currentValue.contains(searchValue)) {
        final String newValue =
            currentValue.replaceAll(searchValue, replaceValue);
        await db.update(
          'photo_metadata',
          {'value': newValue},
          where: 'photo_waypoint_id = ? AND key = ?',
          whereArgs: [photoId, key],
        );
        return true;
      }
    }

    return false;
  }

  /// Add a tag to the tags field
  Future<bool> _addTag({
    required String photoId,
    required String tag,
  }) async {
    final Database db = await _databaseService.database;

    final List<Map<String, dynamic>> existing = await db.query(
      'photo_metadata',
      where: 'photo_waypoint_id = ? AND key = ?',
      whereArgs: [photoId, CustomKeys.tags],
    );

    String newTags;
    if (existing.isNotEmpty) {
      final String currentTags = existing.first['value'] as String? ?? '';
      final List<String> tagList =
          currentTags.split(',').map((t) => t.trim()).toList();
      if (!tagList.contains(tag)) {
        tagList.add(tag);
        newTags = tagList.join(', ');
      } else {
        return false; // Tag already exists
      }
    } else {
      newTags = tag;
    }

    await _updateOrInsertMetadata(
      photoId: photoId,
      key: CustomKeys.tags,
      value: newTags,
    );
    return true;
  }

  /// Remove a tag from the tags field
  Future<bool> _removeTag({
    required String photoId,
    required String tag,
  }) async {
    final Database db = await _databaseService.database;

    final List<Map<String, dynamic>> existing = await db.query(
      'photo_metadata',
      where: 'photo_waypoint_id = ? AND key = ?',
      whereArgs: [photoId, CustomKeys.tags],
    );

    if (existing.isNotEmpty) {
      final String currentTags = existing.first['value'] as String? ?? '';
      final List<String> tagList =
          currentTags.split(',').map((t) => t.trim()).toList();
      if (tagList.remove(tag)) {
        final String newTags = tagList.join(', ');
        await _updateOrInsertMetadata(
          photoId: photoId,
          key: CustomKeys.tags,
          value: newTags,
        );
        return true;
      }
    }

    return false;
  }

  /// Insert photo metadata
  Future<void> _insertPhotoMetadata(PhotoMetadata metadata) async {
    final Database db = await _databaseService.database;
    await db.insert(
      'photo_metadata',
      metadata.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all unique tags from photos
  Future<List<String>> getAllTags() async {
    try {
      final Database db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'photo_metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [CustomKeys.tags],
      );

      final Set<String> allTags = <String>{};
      for (final Map<String, dynamic> map in maps) {
        final String? tagsValue = map['value'] as String?;
        if (tagsValue != null && tagsValue.isNotEmpty) {
          final List<String> tags =
              tagsValue.split(',').map((t) => t.trim()).toList();
          allTags.addAll(tags);
        }
      }

      final List<String> sortedTags = allTags.toList()..sort();
      return sortedTags;
    } catch (e) {
      debugPrint('Error getting all tags: $e');
      return <String>[];
    }
  }

  /// Search photos by metadata
  Future<List<PhotoWaypoint>> searchPhotosByMetadata({
    String? sessionId,
    Map<String, String>? metadataFilters,
    List<String>? tags,
    String? textSearch,
  }) async {
    try {
      // This would need integration with the photo database
      // For now, return empty list
      debugPrint('Photo search by metadata - implementation needed');
      return <PhotoWaypoint>[];
    } catch (e) {
      debugPrint('Error searching photos by metadata: $e');
      return <PhotoWaypoint>[];
    }
  }

  /// Export metadata to JSON
  Future<String?> exportMetadataToJson({
    required List<String> photoIds,
  }) async {
    try {
      final Map<String, dynamic> exportData = <String, dynamic>{
        'export_date': DateTime.now().toIso8601String(),
        'photos': <Map<String, dynamic>>[],
      };

      for (final String photoId in photoIds) {
        final List<PhotoMetadata> metadata =
            await _photoCaptureService.getPhotoMetadata(photoId);

        exportData['photos'].add({
          'photo_id': photoId,
          'metadata': metadata
              .map((m) => {
                    'key': m.key,
                    'value': m.value,
                    'type': m.type.name,
                  })
              .toList(),
        });
      }

      return jsonEncode(exportData);
    } catch (e) {
      debugPrint('Error exporting metadata to JSON: $e');
      return null;
    }
  }

  /// Import metadata from JSON
  Future<bool> importMetadataFromJson({
    required String jsonData,
    bool overwriteExisting = false,
  }) async {
    try {
      final Map<String, dynamic> importData =
          jsonDecode(jsonData) as Map<String, dynamic>;
      final List<dynamic> photos = importData['photos'] as List<dynamic>;

      for (final dynamic photoData in photos) {
        final String photoId = photoData['photo_id'] as String;
        final List<dynamic> metadataList =
            photoData['metadata'] as List<dynamic>;

        for (final dynamic metadataData in metadataList) {
          final String key = metadataData['key'] as String;
          final String? value = metadataData['value'] as String?;

          if (value != null) {
            if (overwriteExisting) {
              await _updateOrInsertMetadata(
                photoId: photoId,
                key: key,
                value: value,
              );
            } else {
              // Only insert if doesn't exist
              final Database db = await _databaseService.database;
              final List<Map<String, dynamic>> existing = await db.query(
                'photo_metadata',
                where: 'photo_waypoint_id = ? AND key = ?',
                whereArgs: [photoId, key],
              );

              if (existing.isEmpty) {
                await _updateOrInsertMetadata(
                  photoId: photoId,
                  key: key,
                  value: value,
                );
              }
            }
          }
        }
      }

      debugPrint('Imported metadata for ${photos.length} photos');
      return true;
    } catch (e) {
      debugPrint('Error importing metadata from JSON: $e');
      return false;
    }
  }

  /// Dispose of the service
  void dispose() {
    _instance = null;
  }
}
