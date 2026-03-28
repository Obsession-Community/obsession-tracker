import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/custom_waypoint_type.dart';
import 'package:obsession_tracker/core/services/database_service.dart';

const String _customWaypointCategoriesTable = 'custom_waypoint_categories';
const String _customWaypointTypesTable = 'custom_waypoint_types';

extension CustomWaypointTypeCategoryCrud on DatabaseService {
  /// Insert a custom waypoint category in the database
  Future<void> insertCustomWaypointCategory(
      CustomWaypointCategory category) async {
    final db = await database;
    try {
      await db.insert(
        _customWaypointCategoriesTable,
        {
          'id': category.id,
          'name': category.name,
          'description': category.description,
          'icon_code_point': category.iconData.codePoint,
          'icon_font_family': category.iconData.fontFamily,
          'icon_font_package': category.iconData.fontPackage,
          'color': category.color.toARGB32,
          'created_at': category.createdAt.millisecondsSinceEpoch,
          'user_id': category.userId,
          'is_active': category.isActive ? 1 : 0,
          'sort_order': category.sortOrder,
          'parent_category_id': category.parentCategoryId,
        },
      );
      debugPrint('Inserted custom waypoint category: ${category.id}');
    } catch (e) {
      debugPrint('Error inserting custom waypoint category: $e');
      rethrow;
    }
  }

  /// Insert a custom waypoint type in the database
  Future<void> insertCustomWaypointType(CustomWaypointType type) async {
    final db = await database;
    try {
      await db.insert(
        _customWaypointTypesTable,
        {
          'id': type.id,
          'name': type.name,
          'description': type.description,
          'icon_code_point': type.iconData.codePoint,
          'icon_font_family': type.iconData.fontFamily,
          'icon_font_package': type.iconData.fontPackage,
          'color': type.color.toARGB32,
          'category_id': type.categoryId,
          'created_at': type.createdAt.millisecondsSinceEpoch,
          'user_id': type.userId,
          'is_active': type.isActive ? 1 : 0,
          'sort_order': type.sortOrder,
          'icon_asset_path': type.iconAssetPath,
        },
      );
      debugPrint('Inserted custom waypoint type: ${type.id}');
    } catch (e) {
      debugPrint('Error inserting custom waypoint type: $e');
      rethrow;
    }
  }

  /// Get custom waypoint categories from the database
  Future<List<CustomWaypointCategory>> getCustomWaypointCategories({
    String? userId,
    bool activeOnly = true,
  }) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        _customWaypointCategoriesTable,
        where: userId != null
            ? 'user_id = ?${activeOnly ? ' AND is_active = 1' : ''}'
            : activeOnly
                ? 'is_active = 1'
                : null,
        whereArgs: userId != null ? [userId] : null,
        orderBy: 'sort_order ASC, name ASC',
      );

      return maps.map(CustomWaypointCategory.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting custom waypoint categories: $e');
      return [];
    }
  }

  /// Get custom waypoint types from the database
  Future<List<CustomWaypointType>> getCustomWaypointTypes({
    String? categoryId,
    String? userId,
    bool activeOnly = true,
  }) async {
    final db = await database;
    try {
      String? where;
      List<dynamic>? whereArgs;

      final conditions = <String>[];
      final args = <dynamic>[];

      if (categoryId != null) {
        conditions.add('category_id = ?');
        args.add(categoryId);
      }
      if (userId != null) {
        conditions.add('user_id = ?');
        args.add(userId);
      }
      if (activeOnly) {
        conditions.add('is_active = 1');
      }

      if (conditions.isNotEmpty) {
        where = conditions.join(' AND ');
        whereArgs = args;
      }

      final List<Map<String, dynamic>> maps = await db.query(
        _customWaypointTypesTable,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'sort_order ASC, name ASC',
      );

      return maps.map(CustomWaypointType.fromMap).toList();
    } catch (e) {
      debugPrint('Error getting custom waypoint types: $e');
      return [];
    }
  }

  /// Update a custom waypoint category in the database
  Future<void> updateCustomWaypointCategory(
      CustomWaypointCategory category) async {
    final db = await database;
    try {
      await db.update(
        _customWaypointCategoriesTable,
        {
          'name': category.name,
          'description': category.description,
          'icon_code_point': category.iconData.codePoint,
          'icon_font_family': category.iconData.fontFamily,
          'icon_font_package': category.iconData.fontPackage,
          'color': category.color.toARGB32,
          'created_at': category.createdAt.millisecondsSinceEpoch,
          'user_id': category.userId,
          'is_active': category.isActive ? 1 : 0,
          'sort_order': category.sortOrder,
          'parent_category_id': category.parentCategoryId,
        },
        where: 'id = ?',
        whereArgs: [category.id],
      );
      debugPrint('Updated custom waypoint category: ${category.id}');
    } catch (e) {
      debugPrint('Error updating custom waypoint category: $e');
      rethrow;
    }
  }

  /// Update a custom waypoint type in the database
  Future<void> updateCustomWaypointType(CustomWaypointType type) async {
    final db = await database;
    try {
      await db.update(
        _customWaypointTypesTable,
        {
          'name': type.name,
          'description': type.description,
          'icon_code_point': type.iconData.codePoint,
          'icon_font_family': type.iconData.fontFamily,
          'icon_font_package': type.iconData.fontPackage,
          'color': type.color.toARGB32,
          'category_id': type.categoryId,
          'created_at': type.createdAt.millisecondsSinceEpoch,
          'user_id': type.userId,
          'is_active': type.isActive ? 1 : 0,
          'sort_order': type.sortOrder,
          'icon_asset_path': type.iconAssetPath,
        },
        where: 'id = ?',
        whereArgs: [type.id],
      );
      debugPrint('Updated custom waypoint type: ${type.id}');
    } catch (e) {
      debugPrint('Error updating custom waypoint type: $e');
      rethrow;
    }
  }
}
