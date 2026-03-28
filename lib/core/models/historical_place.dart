import 'package:flutter/material.dart';

/// Category for grouping place types
@immutable
class PlaceCategory {
  final String id;
  final String name;
  final String emoji;
  final String description;

  const PlaceCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
  });

  factory PlaceCategory.fromJson(String id, Map<String, dynamic> json) {
    return PlaceCategory(
      id: id,
      name: json['name'] as String? ?? id,
      emoji: json['emoji'] as String? ?? '📍',
      description: json['description'] as String? ?? '',
    );
  }

  /// Default categories (fallback if not loaded from data)
  static const Map<String, PlaceCategory> defaults = {
    'water': PlaceCategory(
      id: 'water',
      name: 'Water Features',
      emoji: '🎣',
      description: 'Streams, lakes, reservoirs, springs',
    ),
    'terrain': PlaceCategory(
      id: 'terrain',
      name: 'Terrain',
      emoji: '⛰️',
      description: 'Mountains, valleys, ridges, cliffs',
    ),
    'historic': PlaceCategory(
      id: 'historic',
      name: 'Historical',
      emoji: '🏚️',
      description: 'Mines, ghost towns, cemeteries',
    ),
    'cultural': PlaceCategory(
      id: 'cultural',
      name: 'Cultural',
      emoji: '⛪',
      description: 'Churches, schools, towns',
    ),
    'parks': PlaceCategory(
      id: 'parks',
      name: 'Parks & Rec',
      emoji: '🏞️',
      description: 'Parks, trails, forests',
    ),
    'infra': PlaceCategory(
      id: 'infra',
      name: 'Infrastructure',
      emoji: '🌉',
      description: 'Bridges, airports, tunnels',
    ),
  };

  static PlaceCategory unknown = const PlaceCategory(
    id: 'unknown',
    name: 'Other',
    emoji: '📍',
    description: 'Other features',
  );
}

/// Metadata for a place type (loaded dynamically from JSON data)
@immutable
class PlaceTypeMetadata {
  final String code;
  final String name;
  final String categoryId;
  final String emoji;
  final Color color;

  const PlaceTypeMetadata({
    required this.code,
    required this.name,
    required this.categoryId,
    required this.emoji,
    required this.color,
  });

  factory PlaceTypeMetadata.fromJson(String code, Map<String, dynamic> json) {
    // Parse hex color string (#RRGGBB)
    Color color = const Color(0xFF696969); // Default gray
    final colorStr = json['color'] as String?;
    if (colorStr != null && colorStr.startsWith('#') && colorStr.length == 7) {
      try {
        color = Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
      } catch (_) {}
    }

    return PlaceTypeMetadata(
      code: code,
      name: json['name'] as String? ?? code,
      categoryId: json['category'] as String? ?? 'unknown',
      emoji: json['emoji'] as String? ?? '📍',
      color: color,
    );
  }

  String get colorHex {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).substring(2).toUpperCase()}';
  }

  /// Default metadata for 'OTHER' type
  static const PlaceTypeMetadata other = PlaceTypeMetadata(
    code: 'OTHER',
    name: 'Other',
    categoryId: 'unknown',
    emoji: '📍',
    color: Color(0xFF696969),
  );
}

/// Registry of place type metadata (loaded from JSON data files)
///
/// This allows the app to handle new place types dynamically without
/// requiring app updates. Types are loaded from state JSON files.
class PlaceTypeRegistry {
  static final PlaceTypeRegistry _instance = PlaceTypeRegistry._internal();
  factory PlaceTypeRegistry() => _instance;
  PlaceTypeRegistry._internal();

  final Map<String, PlaceTypeMetadata> _types = {};
  final Map<String, PlaceCategory> _categories = {...PlaceCategory.defaults};
  bool _initialized = false;

  /// Whether the registry has been initialized with data
  bool get isInitialized => _initialized;

  /// All registered types
  Iterable<PlaceTypeMetadata> get allTypes => _types.values;

  /// All categories
  Iterable<PlaceCategory> get allCategories => _categories.values;

  /// Get types for a specific category
  List<PlaceTypeMetadata> typesForCategory(String categoryId) {
    return _types.values
        .where((t) => t.categoryId == categoryId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Load type metadata from JSON state data
  ///
  /// Call this when loading state data to register any new types
  void loadFromStateJson(Map<String, dynamic> json) {
    // Load categories if present
    final categoriesJson = json['categories'] as Map<String, dynamic>?;
    if (categoriesJson != null) {
      for (final entry in categoriesJson.entries) {
        if (entry.value is Map<String, dynamic>) {
          _categories[entry.key] =
              PlaceCategory.fromJson(entry.key, entry.value as Map<String, dynamic>);
        }
      }
    }

    // Load types if present
    final typesJson = json['types'] as Map<String, dynamic>?;
    if (typesJson != null) {
      for (final entry in typesJson.entries) {
        if (entry.value is Map<String, dynamic>) {
          _types[entry.key] = PlaceTypeMetadata.fromJson(entry.key, entry.value as Map<String, dynamic>);
        }
      }
    }

    _initialized = true;
  }

  /// Get metadata for a type code
  PlaceTypeMetadata getType(String code) {
    return _types[code] ?? _fallbackType(code);
  }

  /// Get category for a category ID
  PlaceCategory getCategory(String id) {
    return _categories[id] ?? PlaceCategory.unknown;
  }

  /// Get all type codes in a category
  Set<String> typeCodesInCategory(String categoryId) {
    return _types.values
        .where((t) => t.categoryId == categoryId)
        .map((t) => t.code)
        .toSet();
  }

  /// Fallback for types not in registry (backwards compatibility)
  PlaceTypeMetadata _fallbackType(String code) {
    // Check legacy enum types
    switch (code) {
      case 'MINE':
        return const PlaceTypeMetadata(
          code: 'MINE',
          name: 'Mine',
          categoryId: 'historic',
          emoji: '⛏️',
          color: Color(0xFF8B4513),
        );
      case 'LOCALE':
        return const PlaceTypeMetadata(
          code: 'LOCALE',
          name: 'Locale',
          categoryId: 'historic',
          emoji: '👻',
          color: Color(0xFF808080),
        );
      case 'CEMETERY':
        return const PlaceTypeMetadata(
          code: 'CEMETERY',
          name: 'Cemetery',
          categoryId: 'historic',
          emoji: '✝️',
          color: Color(0xFF2F4F4F),
        );
      case 'CHURCH':
        return const PlaceTypeMetadata(
          code: 'CHURCH',
          name: 'Church',
          categoryId: 'cultural',
          emoji: '⛪',
          color: Color(0xFFFFFFFF),
        );
      case 'SCHOOL':
        return const PlaceTypeMetadata(
          code: 'SCHOOL',
          name: 'School',
          categoryId: 'cultural',
          emoji: '🏫',
          color: Color(0xFFFFD700),
        );
      case 'POST_OFFICE':
        return const PlaceTypeMetadata(
          code: 'POST_OFFICE',
          name: 'Post Office',
          categoryId: 'historic',
          emoji: '📬',
          color: Color(0xFF4169E1),
        );
      case 'POPULATED':
        return const PlaceTypeMetadata(
          code: 'POPULATED',
          name: 'Populated Place',
          categoryId: 'cultural',
          emoji: '🏘️',
          color: Color(0xFF9370DB),
        );
      case 'STREAM':
        return const PlaceTypeMetadata(
          code: 'STREAM',
          name: 'Stream',
          categoryId: 'water',
          emoji: '🌊',
          color: Color(0xFF1E90FF),
        );
      case 'LAKE':
        return const PlaceTypeMetadata(
          code: 'LAKE',
          name: 'Lake',
          categoryId: 'water',
          emoji: '💧',
          color: Color(0xFF4169E1),
        );
      case 'SPRING':
        return const PlaceTypeMetadata(
          code: 'SPRING',
          name: 'Spring',
          categoryId: 'water',
          emoji: '💦',
          color: Color(0xFF00CED1),
        );
      case 'SUMMIT':
        return const PlaceTypeMetadata(
          code: 'SUMMIT',
          name: 'Summit',
          categoryId: 'terrain',
          emoji: '⛰️',
          color: Color(0xFF696969),
        );
      case 'VALLEY':
        return const PlaceTypeMetadata(
          code: 'VALLEY',
          name: 'Valley',
          categoryId: 'terrain',
          emoji: '🏜️',
          color: Color(0xFFD2691E),
        );
      default:
        return PlaceTypeMetadata(
          code: code,
          name: code,
          categoryId: 'unknown',
          emoji: '📍',
          color: const Color(0xFF696969),
        );
    }
  }

  /// Clear all loaded types (for testing)
  void clear() {
    _types.clear();
    _categories.clear();
    _categories.addAll(PlaceCategory.defaults);
    _initialized = false;
  }
}

/// Legacy enum for backwards compatibility
/// New code should use PlaceTypeRegistry.getType(code) instead
@Deprecated('Use PlaceTypeRegistry.getType(code) for dynamic type support')
enum HistoricalPlaceType {
  mine('Mine', 'MINE', '⛏️', Color(0xFF8B4513)),
  locale('Locale', 'LOCALE', '👻', Color(0xFF808080)),
  cemetery('Cemetery', 'CEMETERY', '✝️', Color(0xFF2F4F4F)),
  church('Church', 'CHURCH', '⛪', Color(0xFFFFFFFF)),
  school('School', 'SCHOOL', '🏫', Color(0xFFFFD700)),
  postOffice('Post Office', 'POST_OFFICE', '📬', Color(0xFF4169E1)),
  populatedPlace('Populated Place', 'POPULATED', '🏘️', Color(0xFF9370DB)),
  stream('Stream', 'STREAM', '🌊', Color(0xFF1E90FF)),
  valley('Valley', 'VALLEY', '🏜️', Color(0xFFD2691E)),
  summit('Summit', 'SUMMIT', '⛰️', Color(0xFF696969)),
  lake('Lake', 'LAKE', '💧', Color(0xFF4169E1)),
  spring('Spring', 'SPRING', '💦', Color(0xFF00CED1)),
  falls('Falls', 'FALLS', '🌊', Color(0xFF6495ED)),
  gap('Gap', 'GAP', '🚶', Color(0xFF8B8B83)),
  basin('Basin', 'BASIN', '🥣', Color(0xFFCD853F)),
  ridge('Ridge', 'RIDGE', '📈', Color(0xFF8B7355)),
  flat('Flat', 'FLAT', '🌾', Color(0xFF9ACD32)),
  rapids('Rapids', 'RAPIDS', '🌀', Color(0xFF4682B4)),
  bend('Bend', 'BEND', '↩️', Color(0xFF5F9EA0)),
  cliff('Cliff', 'CLIFF', '🧗', Color(0xFFA0522D)),
  other('Other', 'OTHER', '📍', Color(0xFF696969));

  @Deprecated('Use PlaceTypeRegistry.getType(code) for dynamic type support')
  const HistoricalPlaceType(
    this.displayName,
    this.code,
    this.emoji,
    this.color,
  );

  final String displayName;
  final String code;
  final String emoji;
  final Color color;

  String get colorHex {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).substring(2).toUpperCase()}';
  }

  static HistoricalPlaceType fromGnisClass(String gnisClass) {
    switch (gnisClass.toLowerCase()) {
      case 'mine':
        return HistoricalPlaceType.mine;
      case 'locale':
        return HistoricalPlaceType.locale;
      case 'cemetery':
        return HistoricalPlaceType.cemetery;
      case 'church':
        return HistoricalPlaceType.church;
      case 'school':
        return HistoricalPlaceType.school;
      case 'post office':
        return HistoricalPlaceType.postOffice;
      case 'populated place':
        return HistoricalPlaceType.populatedPlace;
      case 'stream':
        return HistoricalPlaceType.stream;
      case 'valley':
        return HistoricalPlaceType.valley;
      case 'summit':
        return HistoricalPlaceType.summit;
      case 'lake':
        return HistoricalPlaceType.lake;
      case 'spring':
        return HistoricalPlaceType.spring;
      case 'falls':
        return HistoricalPlaceType.falls;
      case 'gap':
        return HistoricalPlaceType.gap;
      case 'basin':
        return HistoricalPlaceType.basin;
      case 'ridge':
        return HistoricalPlaceType.ridge;
      case 'flat':
        return HistoricalPlaceType.flat;
      case 'rapids':
        return HistoricalPlaceType.rapids;
      case 'bend':
        return HistoricalPlaceType.bend;
      case 'cliff':
        return HistoricalPlaceType.cliff;
      default:
        return HistoricalPlaceType.other;
    }
  }

  static HistoricalPlaceType fromCode(String code) {
    return HistoricalPlaceType.values.firstWhere(
      (type) => type.code == code,
      orElse: () => HistoricalPlaceType.other,
    );
  }
}

/// Model for historical place data from USGS GNIS
@immutable
class HistoricalPlace {
  final String id;
  final String featureName;
  final String typeCode;
  final String category;
  final String stateCode;
  final String? countyName;
  final double latitude;
  final double longitude;
  final int? elevationMeters;
  final int? elevationFeet;
  final String? mapName;
  final DateTime? dateCreated;
  final DateTime? dateEdited;

  const HistoricalPlace({
    required this.id,
    required this.featureName,
    required this.typeCode,
    required this.category,
    required this.stateCode,
    this.countyName,
    required this.latitude,
    required this.longitude,
    this.elevationMeters,
    this.elevationFeet,
    this.mapName,
    this.dateCreated,
    this.dateEdited,
  });

  /// Get type metadata from registry
  PlaceTypeMetadata get typeMetadata => PlaceTypeRegistry().getType(typeCode);

  /// Get category metadata from registry
  PlaceCategory get categoryMetadata => PlaceTypeRegistry().getCategory(category);

  /// Legacy accessor for backwards compatibility
  @Deprecated('Use typeCode and typeMetadata instead')
  HistoricalPlaceType get placeType => HistoricalPlaceType.fromCode(typeCode);

  /// Create from database row
  factory HistoricalPlace.fromDatabase(Map<String, dynamic> row) {
    return HistoricalPlace(
      id: row['id'] as String,
      featureName: row['feature_name'] as String,
      typeCode: row['place_type'] as String? ?? row['type_code'] as String? ?? 'OTHER',
      category: row['category'] as String? ?? 'unknown',
      stateCode: row['state_code'] as String,
      countyName: row['county_name'] as String?,
      latitude: row['latitude'] as double,
      longitude: row['longitude'] as double,
      elevationMeters: row['elevation_meters'] as int?,
      elevationFeet: row['elevation_feet'] as int?,
      mapName: row['map_name'] as String?,
      dateCreated: row['date_created'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['date_created'] as int)
          : null,
      dateEdited: row['date_edited'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['date_edited'] as int)
          : null,
    );
  }

  /// Create from JSON (new format with type_code and category)
  factory HistoricalPlace.fromJson(Map<String, dynamic> json) {
    // Get type_code directly if available, otherwise parse from feature_class
    String typeCode = json['type_code'] as String? ?? 'OTHER';
    String category = json['category'] as String? ?? 'unknown';

    // Fallback: parse from feature_class for old format data
    if (typeCode == 'OTHER' && json['feature_class'] != null) {
      final featureClass = json['feature_class'] as String;
      typeCode = _gnisClassToTypeCode(featureClass);
      // Infer category from type code
      category = _inferCategoryFromLegacyType(typeCode);
    }

    // Parse dates if present
    DateTime? dateCreated;
    DateTime? dateEdited;
    if (json['date_created'] != null) {
      dateCreated = _parseGnisDate(json['date_created'] as String);
    }
    if (json['date_edited'] != null) {
      dateEdited = _parseGnisDate(json['date_edited'] as String);
    }

    return HistoricalPlace(
      id: json['id']?.toString() ?? '',
      featureName: json['feature_name'] as String? ?? 'Unknown',
      typeCode: typeCode,
      category: category,
      stateCode: json['state_code'] as String? ?? '',
      countyName: json['county_name'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      elevationMeters: json['elevation_meters'] as int?,
      elevationFeet: json['elevation_feet'] as int?,
      mapName: json['map_name'] as String?,
      dateCreated: dateCreated,
      dateEdited: dateEdited,
    );
  }

  /// Convert GNIS feature class to type code (for old format data)
  static String _gnisClassToTypeCode(String gnisClass) {
    switch (gnisClass.toLowerCase()) {
      case 'mine':
        return 'MINE';
      case 'locale':
        return 'LOCALE';
      case 'cemetery':
        return 'CEMETERY';
      case 'church':
        return 'CHURCH';
      case 'school':
        return 'SCHOOL';
      case 'post office':
        return 'POST_OFFICE';
      case 'populated place':
        return 'POPULATED';
      case 'stream':
        return 'STREAM';
      case 'valley':
        return 'VALLEY';
      case 'summit':
        return 'SUMMIT';
      case 'lake':
        return 'LAKE';
      case 'spring':
        return 'SPRING';
      case 'falls':
        return 'FALLS';
      case 'gap':
        return 'GAP';
      case 'basin':
        return 'BASIN';
      case 'ridge':
        return 'RIDGE';
      case 'flat':
        return 'FLAT';
      case 'rapids':
        return 'RAPIDS';
      case 'bend':
        return 'BEND';
      case 'cliff':
        return 'CLIFF';
      default:
        return 'OTHER';
    }
  }

  /// Infer category from legacy type code
  static String _inferCategoryFromLegacyType(String typeCode) {
    switch (typeCode) {
      case 'STREAM':
      case 'LAKE':
      case 'SPRING':
      case 'FALLS':
      case 'RAPIDS':
      case 'BEND':
        return 'water';
      case 'SUMMIT':
      case 'VALLEY':
      case 'RIDGE':
      case 'GAP':
      case 'BASIN':
      case 'FLAT':
      case 'CLIFF':
        return 'terrain';
      case 'MINE':
      case 'LOCALE':
      case 'CEMETERY':
      case 'POST_OFFICE':
        return 'historic';
      case 'CHURCH':
      case 'SCHOOL':
      case 'POPULATED':
        return 'cultural';
      default:
        return 'unknown';
    }
  }

  /// Convert to database row
  Map<String, dynamic> toDatabaseRow() {
    return {
      'id': id,
      'feature_name': featureName,
      'place_type': typeCode, // Keep column name for compatibility
      'category': category,
      'state_code': stateCode,
      'county_name': countyName,
      'latitude': latitude,
      'longitude': longitude,
      'elevation_meters': elevationMeters,
      'elevation_feet': elevationFeet,
      'map_name': mapName,
      'date_created': dateCreated?.millisecondsSinceEpoch,
      'date_edited': dateEdited?.millisecondsSinceEpoch,
      'cached_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Parse GNIS date format (MM/DD/YYYY)
  static DateTime? _parseGnisDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return null;
      final month = int.parse(parts[0]);
      final day = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  /// Get formatted elevation string
  String? get elevationFormatted {
    if (elevationFeet != null) {
      return '${elevationFeet!.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          )} ft';
    }
    if (elevationMeters != null) {
      return '${elevationMeters!.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          )} m';
    }
    return null;
  }

  /// Get coordinates as [longitude, latitude] for GeoJSON
  List<double> get geoJsonCoordinates => [longitude, latitude];

  /// Convert to GeoJSON Feature for Mapbox
  Map<String, dynamic> toGeoJsonFeature() {
    final meta = typeMetadata;
    return {
      'type': 'Feature',
      'id': id,
      'geometry': {
        'type': 'Point',
        'coordinates': geoJsonCoordinates,
      },
      'properties': {
        'id': id,
        'name': featureName,
        'place_type': typeCode,
        'place_type_name': meta.name,
        'category': category,
        'emoji': meta.emoji,
        'color': meta.colorHex,
        'state': stateCode,
        'county': countyName ?? '',
        'elevation': elevationFormatted ?? '',
        'map_name': mapName ?? '',
      },
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoricalPlace &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'HistoricalPlace{id: $id, name: $featureName, type: $typeCode}';

  HistoricalPlace copyWith({
    String? id,
    String? featureName,
    String? typeCode,
    String? category,
    String? stateCode,
    String? countyName,
    double? latitude,
    double? longitude,
    int? elevationMeters,
    int? elevationFeet,
    String? mapName,
    DateTime? dateCreated,
    DateTime? dateEdited,
  }) {
    return HistoricalPlace(
      id: id ?? this.id,
      featureName: featureName ?? this.featureName,
      typeCode: typeCode ?? this.typeCode,
      category: category ?? this.category,
      stateCode: stateCode ?? this.stateCode,
      countyName: countyName ?? this.countyName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      elevationMeters: elevationMeters ?? this.elevationMeters,
      elevationFeet: elevationFeet ?? this.elevationFeet,
      mapName: mapName ?? this.mapName,
      dateCreated: dateCreated ?? this.dateCreated,
      dateEdited: dateEdited ?? this.dateEdited,
    );
  }
}

/// Filter configuration for historical places overlay
@immutable
class HistoricalPlaceFilter {
  /// Set of enabled type codes to display
  final Set<String> enabledTypeCodes;

  /// Set of enabled category IDs (water, terrain, historic, etc.)
  final Set<String> enabledCategories;

  /// Optional search query to filter by name
  final String? searchQuery;

  const HistoricalPlaceFilter({
    this.enabledTypeCodes = const {},
    this.enabledCategories = const {'water', 'terrain', 'historic', 'cultural', 'parks', 'infra'},
    this.searchQuery,
  });

  /// Default filter showing all categories
  static const HistoricalPlaceFilter defaultFilter = HistoricalPlaceFilter(
    
  );

  /// Check if a place passes this filter
  bool passes(HistoricalPlace place) {
    // If specific type codes are set, use those
    if (enabledTypeCodes.isNotEmpty) {
      if (!enabledTypeCodes.contains(place.typeCode)) {
        return false;
      }
    } else {
      // Otherwise filter by category
      if (!enabledCategories.contains(place.category)) {
        return false;
      }
    }

    // Check search query
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final query = searchQuery!.toLowerCase();
      if (!place.featureName.toLowerCase().contains(query)) {
        return false;
      }
    }

    return true;
  }

  HistoricalPlaceFilter copyWith({
    Set<String>? enabledTypeCodes,
    Set<String>? enabledCategories,
    String? searchQuery,
  }) {
    return HistoricalPlaceFilter(
      enabledTypeCodes: enabledTypeCodes ?? this.enabledTypeCodes,
      enabledCategories: enabledCategories ?? this.enabledCategories,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Toggle a category on/off
  HistoricalPlaceFilter toggleCategory(String categoryId) {
    final newCategories = Set<String>.from(enabledCategories);
    if (newCategories.contains(categoryId)) {
      newCategories.remove(categoryId);
    } else {
      newCategories.add(categoryId);
    }
    return copyWith(enabledCategories: newCategories);
  }

  /// Toggle a specific type code on/off
  HistoricalPlaceFilter toggleTypeCode(String typeCode) {
    final newCodes = Set<String>.from(enabledTypeCodes);
    if (newCodes.contains(typeCode)) {
      newCodes.remove(typeCode);
    } else {
      newCodes.add(typeCode);
    }
    return copyWith(enabledTypeCodes: newCodes);
  }

  /// Enable all categories
  HistoricalPlaceFilter enableAllCategories() {
    return copyWith(
      enabledCategories: {'water', 'terrain', 'historic', 'cultural', 'parks', 'infra'},
      enabledTypeCodes: const {},
    );
  }

  /// Disable all categories
  HistoricalPlaceFilter disableAllCategories() {
    return copyWith(enabledCategories: const {}, enabledTypeCodes: const {});
  }

  bool get allCategoriesEnabled => enabledCategories.length >= 6;
  bool get noCategoriesEnabled => enabledCategories.isEmpty && enabledTypeCodes.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoricalPlaceFilter &&
          runtimeType == other.runtimeType &&
          enabledTypeCodes.length == other.enabledTypeCodes.length &&
          enabledTypeCodes.difference(other.enabledTypeCodes).isEmpty &&
          enabledCategories.length == other.enabledCategories.length &&
          enabledCategories.difference(other.enabledCategories).isEmpty &&
          searchQuery == other.searchQuery;

  @override
  int get hashCode => Object.hash(enabledTypeCodes, enabledCategories, searchQuery);
}

/// Information about a historical places download for a state
@immutable
class HistoricalPlacesDownloadInfo {
  final String stateCode;
  final String stateName;
  final String dataVersion;
  final int placeCount;
  final DateTime downloadedAt;

  const HistoricalPlacesDownloadInfo({
    required this.stateCode,
    required this.stateName,
    required this.dataVersion,
    required this.placeCount,
    required this.downloadedAt,
  });

  factory HistoricalPlacesDownloadInfo.fromDatabase(Map<String, dynamic> row) {
    return HistoricalPlacesDownloadInfo(
      stateCode: row['state_code'] as String,
      stateName: row['state_name'] as String,
      dataVersion: row['data_version'] as String,
      placeCount: row['place_count'] as int,
      downloadedAt: DateTime.fromMillisecondsSinceEpoch(
        row['downloaded_at'] as int,
      ),
    );
  }

  Map<String, dynamic> toDatabaseRow() {
    return {
      'state_code': stateCode,
      'state_name': stateName,
      'data_version': dataVersion,
      'place_count': placeCount,
      'downloaded_at': downloadedAt.millisecondsSinceEpoch,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoricalPlacesDownloadInfo &&
          runtimeType == other.runtimeType &&
          stateCode == other.stateCode;

  @override
  int get hashCode => stateCode.hashCode;
}
