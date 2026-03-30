import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/activity_permissions.dart';
import 'package:obsession_tracker/core/models/owner_contact.dart';

/// Land ownership/classification types
enum LandOwnershipType {
  // Federal Public Land
  federalLand('Federal Land', 'FEDERAL'), // Generic federal land (unspecified agency)
  nationalForest('National Forest', 'NF'),
  nationalPark('National Park', 'NP'),
  nationalWildlifeRefuge('National Wildlife Refuge', 'NWR'),
  bureauOfLandManagement('Bureau of Land Management', 'BLM'),
  nationalMonument('National Monument', 'NM'),
  nationalRecreationArea('National Recreation Area', 'NRA'),

  // State Land
  stateLand('State Land', 'STATE'),
  stateForest('State Forest', 'SF'),
  statePark('State Park', 'SP'),
  stateWildlifeArea('State Wildlife Area', 'SWA'),

  // Local Government
  countyLand('County Land', 'COUNTY'),
  cityLand('City/Municipal Land', 'CITY'),

  // Tribal Land
  tribalLand('Tribal Land', 'TRIBAL'),

  // Private Land
  privateLand('Private Land', 'PRIVATE'),

  // NGO/Conservation Organizations
  ngoConservation('NGO Conservation Land', 'NGO'), // Land owned by conservation organizations (e.g., Nature Conservancy)

  // Special Designations
  wilderness('Wilderness Area', 'WILD'),
  wildlifeManagementArea('Wildlife Management Area', 'WMA'),
  conservationEasement('Conservation Easement', 'CE'),

  // Unknown/Mixed
  unknown('Unknown', 'UNK');

  const LandOwnershipType(this.displayName, this.code);

  final String displayName;
  final String code;

  /// Get color associated with land type for map display
  /// Colors follow onX Hunt/Gaia GPS industry conventions for maximum user familiarity
  ///
  /// Industry Standard Colors (onX/Gaia style):
  /// - NPS: Olive/Sage Green (#6B8E23)
  /// - BLM: Tan/Gold (#DAA520)
  /// - USFS: Forest Green (#228B22)
  /// - FWS: Teal/Sea Green (#20B2AA)
  /// - State: Blue tones (#4682B4)
  /// - Private: Red/Crimson (#DC143C)
  /// - Tribal: Brown (#8B4513)
  int get defaultColor {
    switch (this) {
      // ======================================================================
      // Federal Lands - onX-style colors
      // ======================================================================

      // Generic Federal Land - Light green (fallback)
      case LandOwnershipType.federalLand:
        return 0xFFCDEBC5; // Light green (generic federal)

      // US Forest Service - Forest Green (darker green, distinct from NPS)
      case LandOwnershipType.nationalForest:
        return 0xFF228B22; // Forest Green - USFS standard

      // National Park Service - Olive/Sage Green (onX standard)
      case LandOwnershipType.nationalPark:
        return 0xFF6B8E23; // Olive Drab - NPS standard (onX style)

      // Fish & Wildlife Service - Teal/Sea Green
      case LandOwnershipType.nationalWildlifeRefuge:
        return 0xFF20B2AA; // Light Sea Green - FWS standard

      // Bureau of Land Management - Tan/Gold (onX standard)
      case LandOwnershipType.bureauOfLandManagement:
        return 0xFFDAA520; // Goldenrod - BLM standard (onX style)

      // National Monuments - Same as NPS (most are NPS-managed)
      case LandOwnershipType.nationalMonument:
        return 0xFF6B8E23; // Olive Drab (NPS color)

      // National Recreation Areas - Medium sea green
      case LandOwnershipType.nationalRecreationArea:
        return 0xFF3CB371; // Medium Sea Green

      // ======================================================================
      // State Lands - Blue tones (industry standard)
      // ======================================================================

      // State Lands - Steel Blue
      case LandOwnershipType.stateLand:
        return 0xFF4682B4; // Steel Blue

      // State Forests - Royal Blue
      case LandOwnershipType.stateForest:
        return 0xFF4169E1; // Royal Blue

      // State Parks - Cornflower Blue
      case LandOwnershipType.statePark:
        return 0xFF6495ED; // Cornflower Blue

      // State Wildlife Areas - Cadet Blue
      case LandOwnershipType.stateWildlifeArea:
        return 0xFF5F9EA0; // Cadet Blue

      // ======================================================================
      // Local Government - Purple tones
      // ======================================================================

      // County Land - Medium Purple
      case LandOwnershipType.countyLand:
        return 0xFF9370DB; // Medium Purple

      // City/Municipal Land - Medium Orchid
      case LandOwnershipType.cityLand:
        return 0xFFBA55D3; // Medium Orchid

      // ======================================================================
      // Tribal Land - Brown/Earth tones
      // ======================================================================

      case LandOwnershipType.tribalLand:
        return 0xFF8B4513; // Saddle Brown

      // ======================================================================
      // Private Land - Red/Crimson (warning color)
      // ======================================================================

      case LandOwnershipType.privateLand:
        return 0xFFDC143C; // Crimson (private = caution)

      // ======================================================================
      // Conservation/NGO - Aqua/Teal tones
      // ======================================================================

      // NGO Conservation Land
      case LandOwnershipType.ngoConservation:
        return 0xFF66CDAA; // Medium Aquamarine

      // Conservation Easements
      case LandOwnershipType.conservationEasement:
        return 0xFF7FFFD4; // Aquamarine

      // ======================================================================
      // Special Designations
      // ======================================================================

      // Wilderness Areas - Dark Slate Gray (darker, more restricted)
      case LandOwnershipType.wilderness:
        return 0xFF2F4F4F; // Dark Slate Gray

      // Wildlife Management Areas - Light Sea Green (similar to FWS)
      case LandOwnershipType.wildlifeManagementArea:
        return 0xFF20B2AA; // Light Sea Green

      // ======================================================================
      // Unknown - Gray
      // ======================================================================

      case LandOwnershipType.unknown:
        return 0xFF696969; // Dim Gray
    }
  }

  /// Check if this is public land
  bool get isPublicLand {
    switch (this) {
      case LandOwnershipType.federalLand:
      case LandOwnershipType.nationalForest:
      case LandOwnershipType.nationalPark:
      case LandOwnershipType.nationalWildlifeRefuge:
      case LandOwnershipType.bureauOfLandManagement:
      case LandOwnershipType.nationalMonument:
      case LandOwnershipType.nationalRecreationArea:
      case LandOwnershipType.stateLand:
      case LandOwnershipType.stateForest:
      case LandOwnershipType.statePark:
      case LandOwnershipType.stateWildlifeArea:
      case LandOwnershipType.countyLand:
      case LandOwnershipType.cityLand:
      case LandOwnershipType.wilderness:
      case LandOwnershipType.wildlifeManagementArea:
        return true;
      case LandOwnershipType.privateLand:
      case LandOwnershipType.ngoConservation:
      case LandOwnershipType.tribalLand:
      case LandOwnershipType.conservationEasement:
      case LandOwnershipType.unknown:
        return false;
    }
  }

  /// Check if this is federal land
  bool get isFederalLand {
    switch (this) {
      case LandOwnershipType.federalLand:
      case LandOwnershipType.nationalForest:
      case LandOwnershipType.nationalPark:
      case LandOwnershipType.nationalWildlifeRefuge:
      case LandOwnershipType.bureauOfLandManagement:
      case LandOwnershipType.nationalMonument:
      case LandOwnershipType.nationalRecreationArea:
      case LandOwnershipType.wilderness:
        return true;
      default:
        return false;
    }
  }

  /// Check if this is state land
  bool get isStateLand {
    switch (this) {
      case LandOwnershipType.stateLand:
      case LandOwnershipType.stateForest:
      case LandOwnershipType.statePark:
      case LandOwnershipType.stateWildlifeArea:
        return true;
      default:
        return false;
    }
  }

  /// Check if access typically requires fees
  bool get typicallyHasFees {
    switch (this) {
      case LandOwnershipType.nationalPark:
      case LandOwnershipType.nationalMonument:
      case LandOwnershipType.statePark:
        return true;
      default:
        return false;
    }
  }
}

/// Land access rules and restrictions
enum AccessType {
  publicOpen('Open to Public'),
  permitRequired('Permit Required'),
  seasonalRestrictions('Seasonal Restrictions'),
  feeRequired('Fee Required'),
  huntingLicenseRequired('Hunting License Required'),
  restrictedAccess('Restricted Access'),
  noPublicAccess('No Public Access');

  const AccessType(this.displayName);
  final String displayName;
}

/// Land use activities allowed
enum LandUseType {
  camping('Camping'),
  hunting('Hunting'),
  fishing('Fishing'),
  hiking('Hiking'),
  ohvUse('OHV/ATV Use'),
  rockHounding('Rock Hounding'),
  photography('Photography'),
  birdWatching('Bird Watching'),
  research('Scientific Research'),
  mining('Mining'),
  logging('Logging'),
  grazing('Livestock Grazing');

  const LandUseType(this.displayName);
  final String displayName;
}

/// Represents a parcel or area of land with ownership information
@immutable
class LandOwnership {
  const LandOwnership({
    required this.id,
    required this.ownershipType,
    required this.ownerName,
    this.agencyName,
    this.unitName,
    this.designation,
    required this.accessType,
    this.allowedUses = const [],
    this.restrictions = const [],
    this.contactInfo,
    this.website,
    this.fees,
    this.seasonalInfo,
    required this.bounds,
    required this.centroid,
    this.polygonCoordinates,
    this.properties = const {},
    required this.dataSource,
    this.dataSourceDate,
    required this.createdAt,
    required this.updatedAt,
    this.activityPermissions,
    this.ownerContact,
  });

  final String id;
  final LandOwnershipType ownershipType;
  final String ownerName;
  final String? agencyName;
  final String? unitName;
  final String? designation;
  final AccessType accessType;
  final List<LandUseType> allowedUses;
  final List<String> restrictions;
  final String? contactInfo;
  final String? website;
  final String? fees;
  final String? seasonalInfo;
  final LandBounds bounds;
  final LandPoint centroid;
  final List<List<List<double>>>? polygonCoordinates; // GeoJSON polygon coordinates from BFF
  final Map<String, dynamic> properties;
  final String dataSource; // 'PAD-US', 'State', 'Local', etc.
  final DateTime? dataSourceDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Activity permissions for treasure hunting activities (metal detecting, etc.)
  final ActivityPermissions? activityPermissions;

  /// Property owner contact information (for private lands)
  final OwnerContact? ownerContact;

  LandOwnership copyWith({
    String? id,
    LandOwnershipType? ownershipType,
    String? ownerName,
    String? agencyName,
    String? unitName,
    String? designation,
    AccessType? accessType,
    List<LandUseType>? allowedUses,
    List<String>? restrictions,
    String? contactInfo,
    String? website,
    String? fees,
    String? seasonalInfo,
    LandBounds? bounds,
    LandPoint? centroid,
    List<List<List<double>>>? polygonCoordinates,
    Map<String, dynamic>? properties,
    String? dataSource,
    DateTime? dataSourceDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    ActivityPermissions? activityPermissions,
    OwnerContact? ownerContact,
  }) =>
      LandOwnership(
        id: id ?? this.id,
        ownershipType: ownershipType ?? this.ownershipType,
        ownerName: ownerName ?? this.ownerName,
        agencyName: agencyName ?? this.agencyName,
        unitName: unitName ?? this.unitName,
        designation: designation ?? this.designation,
        accessType: accessType ?? this.accessType,
        allowedUses: allowedUses ?? this.allowedUses,
        restrictions: restrictions ?? this.restrictions,
        contactInfo: contactInfo ?? this.contactInfo,
        website: website ?? this.website,
        fees: fees ?? this.fees,
        seasonalInfo: seasonalInfo ?? this.seasonalInfo,
        bounds: bounds ?? this.bounds,
        centroid: centroid ?? this.centroid,
        polygonCoordinates: polygonCoordinates ?? this.polygonCoordinates,
        properties: properties ?? this.properties,
        dataSource: dataSource ?? this.dataSource,
        dataSourceDate: dataSourceDate ?? this.dataSourceDate,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        activityPermissions: activityPermissions ?? this.activityPermissions,
        ownerContact: ownerContact ?? this.ownerContact,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownership_type': ownershipType.name,
        'owner_name': ownerName,
        'agency_name': agencyName,
        'unit_name': unitName,
        'designation': designation,
        'access_type': accessType.name,
        'allowed_uses': allowedUses.map((u) => u.name).toList(),
        'restrictions': restrictions,
        'contact_info': contactInfo,
        'website': website,
        'fees': fees,
        'seasonal_info': seasonalInfo,
        'bounds': bounds.toJson(),
        'centroid': centroid.toJson(),
        'properties': properties,
        'data_source': dataSource,
        'data_source_date': dataSourceDate?.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'activity_permissions': activityPermissions?.toJson(),
        'owner_contact': ownerContact?.toJson(),
      };

  factory LandOwnership.fromJson(Map<String, dynamic> json) => LandOwnership(
        id: json['id'] as String,
        ownershipType: LandOwnershipType.values.firstWhere(
          (e) => e.name == json['ownership_type'],
          orElse: () => LandOwnershipType.unknown,
        ),
        ownerName: json['owner_name'] as String,
        agencyName: json['agency_name'] as String?,
        unitName: json['unit_name'] as String?,
        designation: json['designation'] as String?,
        accessType: AccessType.values.firstWhere(
          (e) => e.name == json['access_type'],
          orElse: () => AccessType.publicOpen,
        ),
        allowedUses: (json['allowed_uses'] as List<dynamic>?)
                ?.map((u) => LandUseType.values.firstWhere((e) => e.name == u,
                    orElse: () => LandUseType.hiking))
                .toList() ??
            [],
        restrictions:
            (json['restrictions'] as List<dynamic>?)?.cast<String>() ?? [],
        contactInfo: json['contact_info'] as String?,
        website: json['website'] as String?,
        fees: json['fees'] as String?,
        seasonalInfo: json['seasonal_info'] as String?,
        bounds: LandBounds.fromJson(json['bounds'] as Map<String, dynamic>),
        centroid: LandPoint.fromJson(json['centroid'] as Map<String, dynamic>),
        properties: Map<String, dynamic>.from(json['properties'] as Map? ?? {}),
        dataSource: json['data_source'] as String,
        dataSourceDate: json['data_source_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                json['data_source_date'] as int)
            : null,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
        activityPermissions: json['activity_permissions'] != null
            ? ActivityPermissions.fromJson(
                json['activity_permissions'] as Map<String, dynamic>)
            : null,
        ownerContact: json['owner_contact'] != null
            ? OwnerContact.fromJson(json['owner_contact'] as Map<String, dynamic>)
            : null,
      );

  /// Create from database row
  factory LandOwnership.fromDatabase(Map<String, dynamic> row) => LandOwnership(
        id: row['id'] as String,
        ownershipType: LandOwnershipType.values.firstWhere(
          (e) => e.name == row['ownership_type'],
          orElse: () => LandOwnershipType.unknown,
        ),
        ownerName: row['owner_name'] as String,
        agencyName: row['agency_name'] as String?,
        unitName: row['unit_name'] as String?,
        designation: row['designation'] as String?,
        accessType: AccessType.values.firstWhere(
          (e) => e.name == row['access_type'],
          orElse: () => AccessType.publicOpen,
        ),
        allowedUses: row['allowed_uses'] != null
            ? (jsonDecode(row['allowed_uses'] as String) as List<dynamic>)
                .map((u) => LandUseType.values.firstWhere((e) => e.name == u,
                    orElse: () => LandUseType.hiking))
                .toList()
            : [],
        restrictions: row['restrictions'] != null
            ? (jsonDecode(row['restrictions'] as String) as List<dynamic>)
                .cast<String>()
            : [],
        contactInfo: row['contact_info'] as String?,
        website: row['website'] as String?,
        fees: row['fees'] as String?,
        seasonalInfo: row['seasonal_info'] as String?,
        bounds: LandBounds.fromDatabase(row),
        centroid: LandPoint(
          latitude: (row['centroid_latitude'] as num).toDouble(),
          longitude: (row['centroid_longitude'] as num).toDouble(),
        ),
        polygonCoordinates: row['polygon_coordinates'] != null
            ? (jsonDecode(row['polygon_coordinates'] as String) as List<dynamic>)
                .map((ring) => (ring as List<dynamic>)
                    .map((point) => (point as List<dynamic>)
                        .map((coord) => (coord as num).toDouble())
                        .toList())
                    .toList())
                .toList()
            : null,
        properties: row['properties'] != null
            ? jsonDecode(row['properties'] as String) as Map<String, dynamic>
            : {},
        dataSource: row['data_source'] as String,
        dataSourceDate: row['data_source_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                row['data_source_date'] as int)
            : null,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      );

  /// Convert to database row
  Map<String, dynamic> toDatabaseRow() => {
        'id': id,
        'ownership_type': ownershipType.name,
        'owner_name': ownerName,
        'agency_name': agencyName,
        'unit_name': unitName,
        'designation': designation,
        'access_type': accessType.name,
        'allowed_uses': jsonEncode(allowedUses.map((u) => u.name).toList()),
        'restrictions': jsonEncode(restrictions),
        'contact_info': contactInfo,
        'website': website,
        'fees': fees,
        'seasonal_info': seasonalInfo,
        'north_bound': bounds.north,
        'south_bound': bounds.south,
        'east_bound': bounds.east,
        'west_bound': bounds.west,
        'centroid_latitude': centroid.latitude,
        'centroid_longitude': centroid.longitude,
        'polygon_coordinates': polygonCoordinates != null
            ? jsonEncode(polygonCoordinates)
            : null,
        'properties': jsonEncode(properties),
        'data_source': dataSource,
        'data_source_date': dataSourceDate?.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  @override
  String toString() =>
      'LandOwnership(id: $id, type: $ownershipType, owner: $ownerName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LandOwnership &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Geographic bounds for land parcels
@immutable
class LandBounds {
  const LandBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  final double north;
  final double south;
  final double east;
  final double west;

  /// Check if a point is within these bounds
  bool contains(LandPoint point) =>
      point.latitude >= south &&
      point.latitude <= north &&
      point.longitude >= west &&
      point.longitude <= east;

  /// Check if bounds overlap with another bounds
  bool overlaps(LandBounds other) => !(other.west > east ||
      other.east < west ||
      other.north < south ||
      other.south > north);

  /// Get center point of bounds
  LandPoint get center => LandPoint(
        latitude: (north + south) / 2,
        longitude: (east + west) / 2,
      );

  /// Calculate area in square degrees (approximate)
  double get area => (north - south) * (east - west);

  Map<String, dynamic> toJson() => {
        'north': north,
        'south': south,
        'east': east,
        'west': west,
      };

  factory LandBounds.fromJson(Map<String, dynamic> json) => LandBounds(
        north: (json['north'] as num).toDouble(),
        south: (json['south'] as num).toDouble(),
        east: (json['east'] as num).toDouble(),
        west: (json['west'] as num).toDouble(),
      );

  factory LandBounds.fromDatabase(Map<String, dynamic> row) => LandBounds(
        north: (row['north_bound'] as num).toDouble(),
        south: (row['south_bound'] as num).toDouble(),
        east: (row['east_bound'] as num).toDouble(),
        west: (row['west_bound'] as num).toDouble(),
      );

  @override
  String toString() => 'LandBounds(N:$north, S:$south, E:$east, W:$west)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LandBounds &&
          runtimeType == other.runtimeType &&
          north == other.north &&
          south == other.south &&
          east == other.east &&
          west == other.west;

  @override
  int get hashCode => Object.hash(north, south, east, west);
}

/// Geographic point for land centroids
@immutable
class LandPoint {
  const LandPoint({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  factory LandPoint.fromJson(Map<String, dynamic> json) => LandPoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );

  @override
  String toString() => 'LandPoint(lat: $latitude, lon: $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LandPoint &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Filter options for land overlay display
@immutable
class LandOwnershipFilter {
  const LandOwnershipFilter({
    this.enabledTypes = const {},
    this.showPublicLandOnly = false,
    this.showPrivateLandOnly = false,
    this.showFederalLandOnly = false,
    this.showStateLandOnly = false,
    this.showFeeAreasOnly = false,
    this.hideRestrictedAreas = false,
    this.minArea = 0.0,
    this.searchQuery,
    this.version = currentVersion,
  });

  /// Current filter version - increment when adding/removing land types
  /// This forces a reset to defaults for all users when types change
  /// Version history:
  /// - v1: Initial implementation
  /// - v2: Added federalLand and ngoConservation types
  static const int currentVersion = 2;

  /// Factory constructor with all land types enabled by default
  factory LandOwnershipFilter.defaultFilter() {
    return const LandOwnershipFilter(
      enabledTypes: {
        // Federal Public Land
        LandOwnershipType.federalLand, // Generic federal land
        LandOwnershipType.nationalForest,
        LandOwnershipType.nationalPark,
        LandOwnershipType.bureauOfLandManagement,
        LandOwnershipType.nationalWildlifeRefuge,
        LandOwnershipType.nationalMonument,
        LandOwnershipType.nationalRecreationArea,
        // State Land
        LandOwnershipType.stateLand,
        LandOwnershipType.stateForest,
        LandOwnershipType.statePark,
        LandOwnershipType.stateWildlifeArea,
        // Local Government
        LandOwnershipType.countyLand,
        LandOwnershipType.cityLand,
        // Tribal Land
        LandOwnershipType.tribalLand,
        // Private Land
        LandOwnershipType.privateLand,
        // NGO/Conservation Organizations
        LandOwnershipType.ngoConservation, // NGO conservation land
        // Special Designations
        LandOwnershipType.wilderness,
        LandOwnershipType.wildlifeManagementArea,
        LandOwnershipType.conservationEasement,
        // Unknown
        LandOwnershipType.unknown,
      },
    );
  }

  final Set<LandOwnershipType> enabledTypes;
  final bool showPublicLandOnly;
  final bool showPrivateLandOnly;
  final bool showFederalLandOnly;
  final bool showStateLandOnly;
  final bool showFeeAreasOnly;
  final bool hideRestrictedAreas;
  final double minArea;
  final String? searchQuery;
  final int version;

  LandOwnershipFilter copyWith({
    Set<LandOwnershipType>? enabledTypes,
    bool? showPublicLandOnly,
    bool? showPrivateLandOnly,
    bool? showFederalLandOnly,
    bool? showStateLandOnly,
    bool? showFeeAreasOnly,
    bool? hideRestrictedAreas,
    double? minArea,
    String? searchQuery,
    int? version,
  }) =>
      LandOwnershipFilter(
        enabledTypes: enabledTypes ?? this.enabledTypes,
        showPublicLandOnly: showPublicLandOnly ?? this.showPublicLandOnly,
        showPrivateLandOnly: showPrivateLandOnly ?? this.showPrivateLandOnly,
        showFederalLandOnly: showFederalLandOnly ?? this.showFederalLandOnly,
        showStateLandOnly: showStateLandOnly ?? this.showStateLandOnly,
        showFeeAreasOnly: showFeeAreasOnly ?? this.showFeeAreasOnly,
        hideRestrictedAreas: hideRestrictedAreas ?? this.hideRestrictedAreas,
        minArea: minArea ?? this.minArea,
        searchQuery: searchQuery ?? this.searchQuery,
        version: version ?? this.version,
      );

  /// Check if a land ownership passes this filter
  bool passes(LandOwnership land) {
    // Check enabled types
    if (enabledTypes.isNotEmpty && !enabledTypes.contains(land.ownershipType)) {
      return false;
    }

    // Check public/private filters
    if (showPublicLandOnly && !land.ownershipType.isPublicLand) return false;
    if (showPrivateLandOnly && land.ownershipType.isPublicLand) return false;
    if (showFederalLandOnly && !land.ownershipType.isFederalLand) return false;
    if (showStateLandOnly && land.ownershipType.isFederalLand) return false;

    // Check fee areas
    if (showFeeAreasOnly && !land.ownershipType.typicallyHasFees) return false;

    // Check restricted areas
    if (hideRestrictedAreas && land.accessType == AccessType.noPublicAccess)
      return false;

    // Check minimum area
    if (land.bounds.area < minArea) return false;

    // Check search query
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final query = searchQuery!.toLowerCase();
      if (!land.ownerName.toLowerCase().contains(query) &&
          !(land.agencyName?.toLowerCase().contains(query) ?? false) &&
          !(land.unitName?.toLowerCase().contains(query) ?? false) &&
          !(land.designation?.toLowerCase().contains(query) ?? false)) {
        return false;
      }
    }

    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LandOwnershipFilter &&
          runtimeType == other.runtimeType &&
          setEquals(enabledTypes, other.enabledTypes) &&
          showPublicLandOnly == other.showPublicLandOnly &&
          showPrivateLandOnly == other.showPrivateLandOnly &&
          showFederalLandOnly == other.showFederalLandOnly &&
          showStateLandOnly == other.showStateLandOnly &&
          showFeeAreasOnly == other.showFeeAreasOnly &&
          hideRestrictedAreas == other.hideRestrictedAreas &&
          minArea == other.minArea &&
          searchQuery == other.searchQuery &&
          version == other.version;

  @override
  int get hashCode => Object.hash(
        enabledTypes,
        showPublicLandOnly,
        showPrivateLandOnly,
        showFederalLandOnly,
        showStateLandOnly,
        showFeeAreasOnly,
        hideRestrictedAreas,
        minArea,
        searchQuery,
        version,
      );

  /// Convert to JSON for settings persistence
  Map<String, dynamic> toJson() => {
        'enabled_types': enabledTypes.map((e) => e.name).toList(),
        'show_public_land_only': showPublicLandOnly,
        'show_private_land_only': showPrivateLandOnly,
        'show_federal_land_only': showFederalLandOnly,
        'show_state_land_only': showStateLandOnly,
        'show_fee_areas_only': showFeeAreasOnly,
        'hide_restricted_areas': hideRestrictedAreas,
        'min_area': minArea,
        'search_query': searchQuery,
        'version': version,
      };

  /// Create from JSON for settings persistence
  factory LandOwnershipFilter.fromJson(Map<String, dynamic> json) => LandOwnershipFilter(
        enabledTypes: (json['enabled_types'] as List<dynamic>?)
            ?.map((e) => LandOwnershipType.values.firstWhere(
                  (type) => type.name == e,
                  orElse: () => LandOwnershipType.unknown,
                ))
            .toSet() ?? const {},
        showPublicLandOnly: json['show_public_land_only'] as bool? ?? false,
        showPrivateLandOnly: json['show_private_land_only'] as bool? ?? false,
        showFederalLandOnly: json['show_federal_land_only'] as bool? ?? false,
        showStateLandOnly: json['show_state_land_only'] as bool? ?? false,
        showFeeAreasOnly: json['show_fee_areas_only'] as bool? ?? false,
        hideRestrictedAreas: json['hide_restricted_areas'] as bool? ?? false,
        minArea: (json['min_area'] as num?)?.toDouble() ?? 0.0,
        searchQuery: json['search_query'] as String?,
        version: json['version'] as int? ?? 1, // Default to v1 for old saved filters
      );
}
