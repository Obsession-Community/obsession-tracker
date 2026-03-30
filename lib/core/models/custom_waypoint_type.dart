import 'package:flutter/material.dart';

/// A custom waypoint type defined by the user
@immutable
class CustomWaypointType {
  const CustomWaypointType({
    required this.id,
    required this.name,
    required this.description,
    required this.iconData,
    required this.color,
    required this.categoryId,
    required this.createdAt,
    required this.userId,
    this.isActive = true,
    this.sortOrder = 0,
    this.iconAssetPath,
  });

  /// Create a custom waypoint type from database map
  factory CustomWaypointType.fromMap(Map<String, dynamic> map) =>
      CustomWaypointType(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String,
        iconData: IconData(
          map['icon_code_point'] as int,
          fontFamily: map['icon_font_family'] as String?,
          fontPackage: map['icon_font_package'] as String?,
        ),
        color: Color(map['color'] as int),
        categoryId: map['category_id'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        userId: map['user_id'] as String,
        isActive: (map['is_active'] as int) == 1,
        sortOrder: map['sort_order'] as int? ?? 0,
        iconAssetPath: map['icon_asset_path'] as String?,
      );

  /// Unique identifier for this custom type
  final String id;

  /// User-defined name for the waypoint type
  final String name;

  /// User-defined description
  final String description;

  /// Icon data for the waypoint type
  final IconData iconData;

  /// Color for the waypoint type
  final Color color;

  /// ID of the custom category this type belongs to
  final String categoryId;

  /// When this custom type was created
  final DateTime createdAt;

  /// ID of the user who created this type
  final String userId;

  /// Whether this type is active/enabled
  final bool isActive;

  /// Sort order for display
  final int sortOrder;

  /// Optional path to custom icon asset
  final String? iconAssetPath;

  /// Convert to map for database storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
        'icon_code_point': iconData.codePoint,
        'icon_font_family': iconData.fontFamily,
        'icon_font_package': iconData.fontPackage,
        'color': color.toARGB32(),
        'category_id': categoryId,
        'created_at': createdAt.millisecondsSinceEpoch,
        'user_id': userId,
        'is_active': isActive ? 1 : 0,
        'sort_order': sortOrder,
        'icon_asset_path': iconAssetPath,
      };

  /// Create a copy with updated values
  CustomWaypointType copyWith({
    String? id,
    String? name,
    String? description,
    IconData? iconData,
    Color? color,
    String? categoryId,
    DateTime? createdAt,
    String? userId,
    bool? isActive,
    int? sortOrder,
    String? iconAssetPath,
  }) =>
      CustomWaypointType(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        iconData: iconData ?? this.iconData,
        color: color ?? this.color,
        categoryId: categoryId ?? this.categoryId,
        createdAt: createdAt ?? this.createdAt,
        userId: userId ?? this.userId,
        isActive: isActive ?? this.isActive,
        sortOrder: sortOrder ?? this.sortOrder,
        iconAssetPath: iconAssetPath ?? this.iconAssetPath,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomWaypointType &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CustomWaypointType{id: $id, name: $name, categoryId: $categoryId}';
}

/// A custom category for organizing waypoint types
@immutable
class CustomWaypointCategory {
  const CustomWaypointCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.iconData,
    required this.color,
    required this.createdAt,
    required this.userId,
    this.isActive = true,
    this.sortOrder = 0,
    this.parentCategoryId,
  });

  /// Create a custom category from database map
  factory CustomWaypointCategory.fromMap(Map<String, dynamic> map) =>
      CustomWaypointCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String,
        iconData: IconData(
          map['icon_code_point'] as int,
          fontFamily: map['icon_font_family'] as String?,
          fontPackage: map['icon_font_package'] as String?,
        ),
        color: Color(map['color'] as int),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        userId: map['user_id'] as String,
        isActive: (map['is_active'] as int) == 1,
        sortOrder: map['sort_order'] as int? ?? 0,
        parentCategoryId: map['parent_category_id'] as String?,
      );

  /// Unique identifier for this custom category
  final String id;

  /// User-defined name for the category
  final String name;

  /// User-defined description
  final String description;

  /// Icon data for the category
  final IconData iconData;

  /// Color for the category
  final Color color;

  /// When this custom category was created
  final DateTime createdAt;

  /// ID of the user who created this category
  final String userId;

  /// Whether this category is active/enabled
  final bool isActive;

  /// Sort order for display
  final int sortOrder;

  /// Optional parent category for hierarchical organization
  final String? parentCategoryId;

  /// Convert to map for database storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
        'icon_code_point': iconData.codePoint,
        'icon_font_family': iconData.fontFamily,
        'icon_font_package': iconData.fontPackage,
        'color': color.toARGB32(),
        'created_at': createdAt.millisecondsSinceEpoch,
        'user_id': userId,
        'is_active': isActive ? 1 : 0,
        'sort_order': sortOrder,
        'parent_category_id': parentCategoryId,
      };

  /// Create a copy with updated values
  CustomWaypointCategory copyWith({
    String? id,
    String? name,
    String? description,
    IconData? iconData,
    Color? color,
    DateTime? createdAt,
    String? userId,
    bool? isActive,
    int? sortOrder,
    String? parentCategoryId,
  }) =>
      CustomWaypointCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        iconData: iconData ?? this.iconData,
        color: color ?? this.color,
        createdAt: createdAt ?? this.createdAt,
        userId: userId ?? this.userId,
        isActive: isActive ?? this.isActive,
        sortOrder: sortOrder ?? this.sortOrder,
        parentCategoryId: parentCategoryId ?? this.parentCategoryId,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomWaypointCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CustomWaypointCategory{id: $id, name: $name, parentId: $parentCategoryId}';
}
