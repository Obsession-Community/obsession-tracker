import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';

/// A template for quickly creating waypoints with predefined settings
@immutable
class WaypointTemplate {
  const WaypointTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.waypointType,
    required this.createdAt,
    required this.userId,
    this.customWaypointTypeId,
    this.defaultName,
    this.defaultNotes,
    this.defaultColor,
    this.customFields = const <String, dynamic>{},
    this.isActive = true,
    this.sortOrder = 0,
    this.iconData,
    this.isQuickAccess = false,
    this.tags = const <String>[],
  });

  /// Create a waypoint template from database map
  factory WaypointTemplate.fromMap(Map<String, dynamic> map) =>
      WaypointTemplate(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String,
        waypointType: map['custom_waypoint_type_id'] != null
            ? null
            : WaypointType.values.firstWhere(
                (type) => type.name == map['waypoint_type'],
                orElse: () => WaypointType.custom,
              ),
        customWaypointTypeId: map['custom_waypoint_type_id'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        userId: map['user_id'] as String,
        defaultName: map['default_name'] as String?,
        defaultNotes: map['default_notes'] as String?,
        defaultColor: map['default_color'] != null
            ? Color(map['default_color'] as int)
            : null,
        customFields: map['custom_fields'] != null
            ? Map<String, dynamic>.from(map['custom_fields'] as Map)
            : const <String, dynamic>{},
        isActive: (map['is_active'] as int) == 1,
        sortOrder: map['sort_order'] as int? ?? 0,
        iconData: map['icon_code_point'] != null
            ? IconData(
                map['icon_code_point'] as int,
                fontFamily: map['icon_font_family'] as String?,
                fontPackage: map['icon_font_package'] as String?,
              )
            : null,
        isQuickAccess: (map['is_quick_access'] as int?) == 1,
        tags: map['tags'] != null
            ? List<String>.from(map['tags'] as List)
            : const <String>[],
      );

  /// Unique identifier for this template
  final String id;

  /// Template name
  final String name;

  /// Template description
  final String description;

  /// Built-in waypoint type (if not using custom type)
  final WaypointType? waypointType;

  /// Custom waypoint type ID (if using custom type)
  final String? customWaypointTypeId;

  /// When this template was created
  final DateTime createdAt;

  /// ID of the user who created this template
  final String userId;

  /// Default name for waypoints created from this template
  final String? defaultName;

  /// Default notes for waypoints created from this template
  final String? defaultNotes;

  /// Default color override for waypoints created from this template
  final Color? defaultColor;

  /// Custom fields with default values
  final Map<String, dynamic> customFields;

  /// Whether this template is active/enabled
  final bool isActive;

  /// Sort order for display
  final int sortOrder;

  /// Optional custom icon for the template
  final IconData? iconData;

  /// Whether this template appears in quick access toolbar
  final bool isQuickAccess;

  /// Tags for organizing templates
  final List<String> tags;

  /// Get the effective waypoint type (built-in or custom)
  bool get isCustomType => customWaypointTypeId != null;

  /// Get display icon
  IconData get displayIcon {
    if (iconData != null) return iconData!;
    // WaypointType uses iconName (string) not IconData, so use fallback
    return Icons.push_pin;
  }

  /// Convert to map for database storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
        'waypoint_type': waypointType?.name,
        'custom_waypoint_type_id': customWaypointTypeId,
        'created_at': createdAt.millisecondsSinceEpoch,
        'user_id': userId,
        'default_name': defaultName,
        'default_notes': defaultNotes,
        'default_color': defaultColor?.toARGB32(),
        'custom_fields': customFields,
        'is_active': isActive ? 1 : 0,
        'sort_order': sortOrder,
        'icon_code_point': iconData?.codePoint,
        'icon_font_family': iconData?.fontFamily,
        'icon_font_package': iconData?.fontPackage,
        'is_quick_access': isQuickAccess ? 1 : 0,
        'tags': tags,
      };

  /// Create a copy with updated values
  WaypointTemplate copyWith({
    String? id,
    String? name,
    String? description,
    WaypointType? waypointType,
    String? customWaypointTypeId,
    DateTime? createdAt,
    String? userId,
    String? defaultName,
    String? defaultNotes,
    Color? defaultColor,
    Map<String, dynamic>? customFields,
    bool? isActive,
    int? sortOrder,
    IconData? iconData,
    bool? isQuickAccess,
    List<String>? tags,
    bool clearDefaultName = false,
    bool clearDefaultNotes = false,
    bool clearDefaultColor = false,
    bool clearCustomWaypointTypeId = false,
  }) =>
      WaypointTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        waypointType: waypointType ?? this.waypointType,
        customWaypointTypeId: clearCustomWaypointTypeId
            ? null
            : (customWaypointTypeId ?? this.customWaypointTypeId),
        createdAt: createdAt ?? this.createdAt,
        userId: userId ?? this.userId,
        defaultName:
            clearDefaultName ? null : (defaultName ?? this.defaultName),
        defaultNotes:
            clearDefaultNotes ? null : (defaultNotes ?? this.defaultNotes),
        defaultColor:
            clearDefaultColor ? null : (defaultColor ?? this.defaultColor),
        customFields: customFields ?? this.customFields,
        isActive: isActive ?? this.isActive,
        sortOrder: sortOrder ?? this.sortOrder,
        iconData: iconData ?? this.iconData,
        isQuickAccess: isQuickAccess ?? this.isQuickAccess,
        tags: tags ?? this.tags,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaypointTemplate &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'WaypointTemplate{id: $id, name: $name, isCustomType: $isCustomType}';
}

/// Quick access preset for rapid waypoint creation
@immutable
class WaypointQuickPreset {
  const WaypointQuickPreset({
    required this.id,
    required this.name,
    required this.templateId,
    required this.position,
    required this.userId,
    this.customName,
    this.customIcon,
    this.customColor,
    this.isActive = true,
  });

  /// Create a quick preset from database map
  factory WaypointQuickPreset.fromMap(Map<String, dynamic> map) =>
      WaypointQuickPreset(
        id: map['id'] as String,
        name: map['name'] as String,
        templateId: map['template_id'] as String,
        position: map['position'] as int,
        userId: map['user_id'] as String,
        customName: map['custom_name'] as String?,
        customIcon: map['custom_icon_code_point'] != null
            ? IconData(
                map['custom_icon_code_point'] as int,
                fontFamily: map['custom_icon_font_family'] as String?,
                fontPackage: map['custom_icon_font_package'] as String?,
              )
            : null,
        customColor: map['custom_color'] != null
            ? Color(map['custom_color'] as int)
            : null,
        isActive: (map['is_active'] as int) == 1,
      );

  /// Unique identifier for this preset
  final String id;

  /// Display name for the preset
  final String name;

  /// ID of the template this preset uses
  final String templateId;

  /// Position in the quick access toolbar (0-based)
  final int position;

  /// ID of the user who created this preset
  final String userId;

  /// Optional custom name override
  final String? customName;

  /// Optional custom icon override
  final IconData? customIcon;

  /// Optional custom color override
  final Color? customColor;

  /// Whether this preset is active/enabled
  final bool isActive;

  /// Convert to map for database storage
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'template_id': templateId,
        'position': position,
        'user_id': userId,
        'custom_name': customName,
        'custom_icon_code_point': customIcon?.codePoint,
        'custom_icon_font_family': customIcon?.fontFamily,
        'custom_icon_font_package': customIcon?.fontPackage,
        'custom_color': customColor?.toARGB32(),
        'is_active': isActive ? 1 : 0,
      };

  /// Create a copy with updated values
  WaypointQuickPreset copyWith({
    String? id,
    String? name,
    String? templateId,
    int? position,
    String? userId,
    String? customName,
    IconData? customIcon,
    Color? customColor,
    bool? isActive,
    bool clearCustomName = false,
    bool clearCustomIcon = false,
    bool clearCustomColor = false,
  }) =>
      WaypointQuickPreset(
        id: id ?? this.id,
        name: name ?? this.name,
        templateId: templateId ?? this.templateId,
        position: position ?? this.position,
        userId: userId ?? this.userId,
        customName: clearCustomName ? null : (customName ?? this.customName),
        customIcon: clearCustomIcon ? null : (customIcon ?? this.customIcon),
        customColor:
            clearCustomColor ? null : (customColor ?? this.customColor),
        isActive: isActive ?? this.isActive,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaypointQuickPreset &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'WaypointQuickPreset{id: $id, name: $name, position: $position}';
}
