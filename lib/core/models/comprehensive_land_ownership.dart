import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/access_rights.dart';
import 'package:obsession_tracker/core/models/activity_permissions.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/models/owner_contact.dart';

/// Enhanced land ownership model for federated GraphQL system
/// Contains comprehensive property information including permissions, owner contacts, and legal details
@immutable
class ComprehensiveLandOwnership {
  const ComprehensiveLandOwnership({
    required this.id,
    required this.ownerName,
    required this.ownershipType,
    this.legalDescription,
    this.acreage,
    required this.dataSource,
    this.lastUpdated,
    this.boundaries,
    this.highBoundaries,
    this.mediumBoundaries,
    this.lowBoundaries,
    this.overviewBoundaries,
    required this.activityPermissions,
    required this.accessRights,
    this.ownerContact,

    // Legacy compatibility fields
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
  });

  // Core property information
  final String id;
  final String ownerName;
  final String ownershipType; // federal, private, state, tribal, etc.
  final String? legalDescription;
  final double? acreage;
  final String dataSource;
  final DateTime? lastUpdated;

  // Boundary information - 5-level Progressive LOD system
  // Based on cartographic science: tolerance <= 2 x meters-per-pixel is imperceptible
  final List<List<List<double>>>? boundaries; // Full precision (zoom 15+, 0m tolerance)
  final List<List<List<double>>>? highBoundaries; // Property-level (zoom 12-14, ~5.5m tolerance)
  final List<List<List<double>>>? mediumBoundaries; // Neighborhood (zoom 10-11, ~22m tolerance)
  final List<List<List<double>>>? lowBoundaries; // County-level (zoom 8-9, ~111m tolerance)
  final List<List<List<double>>>? overviewBoundaries; // State/regional (zoom 5-7, ~555m tolerance)

  // Legacy alias for backward compatibility
  @Deprecated('Use mediumBoundaries instead - kept for migration')
  List<List<List<double>>>? get simplifiedBoundaries => mediumBoundaries;

  // Comprehensive land rights information
  final ActivityPermissions activityPermissions;
  final AccessRights accessRights;
  final OwnerContact? ownerContact;

  // Legacy compatibility fields (maintained for backward compatibility)
  final String? agencyName;
  final String? unitName;
  final String? designation;
  final String accessType;
  final List<String> allowedUses;
  final List<String> restrictions;
  final String? contactInfo;
  final String? website;
  final String? fees;
  final String? seasonalInfo;

  /// Create from GraphQL federation response data
  factory ComprehensiveLandOwnership.fromJson(Map<String, dynamic> json) {
    return ComprehensiveLandOwnership(
      id: (json['id'] as String?) ?? '',
      ownerName: (json['ownerName'] as String?) ?? '',
      ownershipType: (json['ownershipType'] as String?) ?? 'unknown',
      legalDescription: json['legalDescription'] as String?,
      acreage: (json['acreage'] as num?)?.toDouble(),
      dataSource: (json['dataSource'] as String?) ?? 'unknown',
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'] as String)
          : null,

      // Process 5-level LOD boundaries
      boundaries: _parseBoundaries(json['boundaries'] as Map<String, dynamic>?),
      highBoundaries: _parseBoundaries(json['highBoundaries'] as Map<String, dynamic>?),
      mediumBoundaries: _parseBoundaries(json['mediumBoundaries'] as Map<String, dynamic>?)
          ?? _parseBoundaries(json['simplifiedBoundaries'] as Map<String, dynamic>?), // Legacy fallback
      lowBoundaries: _parseBoundaries(json['lowBoundaries'] as Map<String, dynamic>?),
      overviewBoundaries: _parseBoundaries(json['overviewBoundaries'] as Map<String, dynamic>?),

      // Comprehensive land rights data
      activityPermissions: json['activityPermissions'] != null
          ? ActivityPermissions.fromJson(json['activityPermissions'] as Map<String, dynamic>)
          : const ActivityPermissions(
              metalDetecting: PermissionStatus.unknown,
              treasureHunting: PermissionStatus.unknown,
              archaeology: PermissionStatus.unknown,
              camping: PermissionStatus.unknown,
              hunting: PermissionStatus.unknown,
              fishing: PermissionStatus.unknown,
            ),
      accessRights: json['accessRights'] != null
          ? AccessRights.fromJson(json['accessRights'] as Map<String, dynamic>)
          : const AccessRights(
              publicAccess: false,
              easementAccess: false,
              permitRequired: false,
              huntingAccess: false,
              recreationAccess: false,
            ),
      ownerContact: json['ownerContact'] != null
          ? OwnerContact.fromJson(json['ownerContact'] as Map<String, dynamic>)
          : null,

      // Legacy fields
      agencyName: json['agencyName'] as String?,
      unitName: json['unitName'] as String?,
      designation: json['designation'] as String?,
      accessType: (json['accessType'] as String?) ?? 'unknown',
      allowedUses: List<String>.from((json['allowedUses'] as List<dynamic>?) ?? []),
      restrictions: List<String>.from((json['restrictions'] as List<dynamic>?) ?? []),
      contactInfo: json['contactInfo'] as String?,
      website: json['website'] as String?,
      fees: json['fees'] as String?,
      seasonalInfo: json['seasonalInfo'] as String?,
    );
  }

  /// Create from existing LandOwnership model (for local data)
  factory ComprehensiveLandOwnership.fromLandOwnership(LandOwnership land) {
    return ComprehensiveLandOwnership(
      id: land.id,
      ownerName: land.ownerName,
      ownershipType: land.ownershipType.name,
      dataSource: land.dataSource,
      lastUpdated: land.updatedAt,
      boundaries: land.polygonCoordinates,
      activityPermissions: land.activityPermissions ?? const ActivityPermissions(
        metalDetecting: PermissionStatus.unknown,
        treasureHunting: PermissionStatus.unknown,
        archaeology: PermissionStatus.unknown,
        camping: PermissionStatus.unknown,
        hunting: PermissionStatus.unknown,
        fishing: PermissionStatus.unknown,
      ),
      accessRights: const AccessRights(
        publicAccess: false,
        easementAccess: false,
        permitRequired: false,
        huntingAccess: false,
        recreationAccess: false,
      ),
      ownerContact: land.ownerContact,
      agencyName: land.agencyName,
      unitName: land.unitName,
      designation: land.designation,
      accessType: land.accessType.name,
      allowedUses: land.allowedUses.map((u) => u.displayName).toList(),
      restrictions: land.restrictions,
      contactInfo: land.contactInfo,
      website: land.website,
      fees: land.fees,
      seasonalInfo: land.seasonalInfo,
    );
  }

  /// Parse boundary coordinates from GraphQL response
  static List<List<List<double>>>? _parseBoundaries(Map<String, dynamic>? boundaryData) {
    if (boundaryData == null || boundaryData['coordinates'] == null) {
      return null;
    }

    try {
      final coordinates = boundaryData['coordinates'];
      if (coordinates is List) {
        return coordinates.map((ring) {
          if (ring is List) {
            return ring.map((point) {
              if (point is List && point.length >= 2) {
                try {
                  // Handle nested coordinate arrays more safely
                  dynamic lonValue = point[0];
                  dynamic latValue = point[1];
                  
                  // If coordinate values are nested further, extract them
                  if (lonValue is List && lonValue.isNotEmpty) {
                    lonValue = lonValue[0];
                  }
                  if (latValue is List && latValue.isNotEmpty) {
                    latValue = latValue[0];
                  }
                  
                  return [
                    (lonValue as num).toDouble(), // longitude
                    (latValue as num).toDouble(), // latitude
                  ];
                } catch (e) {
                  debugPrint('Error parsing coordinate point $point: $e');
                  return <double>[];
                }
              }
              return <double>[];
            }).where((point) => point.isNotEmpty).toList();
          }
          return <List<double>>[];
        }).where((ring) => ring.isNotEmpty).toList();
      }
    } catch (e) {
      debugPrint('Error parsing boundaries: $e');
    }
    
    return null;
  }

  /// Convert to JSON for storage/transmission
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerName': ownerName,
      'ownershipType': ownershipType,
      'legalDescription': legalDescription,
      'acreage': acreage,
      'dataSource': dataSource,
      'lastUpdated': lastUpdated?.toIso8601String(),
      // 5-level LOD boundaries
      'boundaries': boundaries != null ? {'coordinates': boundaries} : null,
      'highBoundaries': highBoundaries != null ? {'coordinates': highBoundaries} : null,
      'mediumBoundaries': mediumBoundaries != null ? {'coordinates': mediumBoundaries} : null,
      'lowBoundaries': lowBoundaries != null ? {'coordinates': lowBoundaries} : null,
      'overviewBoundaries': overviewBoundaries != null ? {'coordinates': overviewBoundaries} : null,
      'activityPermissions': activityPermissions.toJson(),
      'accessRights': accessRights.toJson(),
      'ownerContact': ownerContact?.toJson(),
      'agencyName': agencyName,
      'unitName': unitName,
      'designation': designation,
      'accessType': accessType,
      'allowedUses': allowedUses,
      'restrictions': restrictions,
      'contactInfo': contactInfo,
      'website': website,
      'fees': fees,
      'seasonalInfo': seasonalInfo,
    };
  }

  /// Convert to legacy LandOwnership model for backward compatibility
  LandOwnership toLegacyModel() {
    // This would require implementing the conversion to the existing model
    // For now, return a basic implementation
    throw UnimplementedError('Legacy model conversion not yet implemented');
  }

  /// Get display name for the property
  String get displayName {
    if (unitName != null && unitName!.isNotEmpty) {
      return unitName!;
    }
    if (agencyName != null && agencyName!.isNotEmpty) {
      return agencyName!;
    }
    return ownerName;
  }

  /// Get ownership type color for map display
  /// Colors follow industry standards (onX, Gaia GPS, CalTopo, ESRI USA_Federal_Lands)
  ///
  /// Color selection priority:
  /// 1. Check ownerName for specific agency (NPS, BLM, USFS, etc.) - this is how onX works
  /// 2. Fall back to ownershipType for broader categories (state, private, etc.)
  ///
  /// Industry Standard Colors (approximate hex values):
  /// - NPS (National Park Service): Olive/Sage Green (#6B8E23)
  /// - BLM (Bureau of Land Management): Tan/Gold (#DAA520)
  /// - USFS (US Forest Service): Forest Green (#228B22)
  /// - FWS (Fish & Wildlife Service): Teal/Sea Green (#20B2AA)
  /// - State Lands: Blue tones (#4682B4)
  /// - Private: Red/Pink tones (#DC143C)
  /// - Tribal: Brown/Earth tones (#8B4513)
  int get ownershipColor {
    // First, check ownerName for agency-specific colors (PAD-US stores agency in ownerName)
    final agencyColor = _getAgencyColor(ownerName);
    if (agencyColor != null) {
      return agencyColor;
    }

    // Fall back to ownershipType for broader categories
    switch (ownershipType.toLowerCase()) {
      // ======================================================================
      // Federal Land Colors - Generic fallback when agency not specified
      // ======================================================================

      case 'fed':
      case 'federal':
      case 'federal_land':
        return 0xFFCDEBC5; // Light green (generic federal)

      // ======================================================================
      // State Land Colors (blues) - Industry standard
      // ======================================================================

      case 'stat':
      case 'state':
      case 'stateland':
      case 'state_land':
        return 0xFF4682B4; // Steel Blue (state standard)

      case 'stateforest':
      case 'state_forest':
        return 0xFF4169E1; // Royal Blue

      case 'statepark':
      case 'state_park':
        return 0xFF6495ED; // Cornflower Blue

      case 'statewildlifearea':
      case 'state_wildlife_area':
      case 'swa':
        return 0xFF5F9EA0; // Cadet Blue

      // ======================================================================
      // Local Government Colors (purples) - Industry standard
      // ======================================================================

      case 'loc':
      case 'local_government':
      case 'countyland':
      case 'county':
      case 'county_land':
        return 0xFF9370DB; // Medium Purple

      case 'dist':
      case 'district':
      case 'special_district':
        return 0xFF9370DB; // Medium Purple (districts are local gov)

      case 'cityland':
      case 'city':
      case 'city_land':
      case 'municipal':
      case 'local':
      case 'other':
        return 0xFFBA55D3; // Medium Orchid

      // ======================================================================
      // Tribal Land (browns/earth tones) - Industry standard
      // ======================================================================

      case 'trib':
      case 'tribal':
      case 'triballand':
      case 'tribal_land':
        return 0xFF8B4513; // Saddle Brown

      // ======================================================================
      // Private Land (reds/pinks - warning) - Industry standard
      // ======================================================================

      case 'pvt':
      case 'private':
      case 'privateland':
      case 'private_land':
        return 0xFFDC143C; // Crimson (private = caution)

      // ======================================================================
      // NGO/Conservation (aqua/teal tones)
      // ======================================================================

      case 'ngo':
      case 'ngos':
      case 'ngo_conservation':
      case 'conservation_org':
        return 0xFF66CDAA; // Medium Aquamarine

      case 'ce':
      case 'conservation_easement':
        return 0xFF7FFFD4; // Aquamarine

      // ======================================================================
      // Joint Ownership
      // ======================================================================

      case 'jnt':
      case 'joint':
      case 'joint_ownership':
        return 0xFFCDEBC5; // Light green (typically federal-involved)

      // ======================================================================
      // Unknown/Default
      // ======================================================================

      case 'unk':
      case 'unknown':
      default:
        return 0xFF696969; // Dim Gray
    }
  }

  /// Get color based on managing agency (ownerName field from PAD-US)
  /// Returns null if agency not recognized, allowing fallback to ownershipType
  ///
  /// PAD-US owner_name values for federal lands:
  /// - NPS: National Park Service
  /// - BLM: Bureau of Land Management
  /// - USFS: US Forest Service
  /// - FWS/USFWS: Fish & Wildlife Service
  /// - BOR: Bureau of Reclamation
  /// - USACE: Army Corps of Engineers
  /// - DOD: Department of Defense
  /// - DOE: Department of Energy
  /// - TVA: Tennessee Valley Authority
  int? _getAgencyColor(String agency) {
    switch (agency.toUpperCase()) {
      // ======================================================================
      // National Park Service - Olive/Sage Green (distinctive NPS color)
      // onX uses a similar sage green for NPS lands
      // ======================================================================
      case 'NPS':
      case 'NATIONAL PARK SERVICE':
        return 0xFF6B8E23; // Olive Drab - NPS standard

      // ======================================================================
      // Bureau of Land Management - Tan/Gold/Yellow
      // onX uses tan/gold for BLM, very distinct from NPS green
      // ======================================================================
      case 'BLM':
      case 'BUREAU OF LAND MANAGEMENT':
        return 0xFFDAA520; // Goldenrod - BLM standard

      // ======================================================================
      // US Forest Service - Forest Green
      // Classic USFS green, darker than NPS
      // ======================================================================
      case 'USFS':
      case 'FS':
      case 'US FOREST SERVICE':
      case 'FOREST SERVICE':
        return 0xFF228B22; // Forest Green - USFS standard

      // ======================================================================
      // Fish & Wildlife Service - Teal/Sea Green
      // Distinctive blue-green for wildlife refuges
      // ======================================================================
      case 'FWS':
      case 'USFWS':
      case 'US FISH AND WILDLIFE SERVICE':
      case 'FISH AND WILDLIFE SERVICE':
        return 0xFF20B2AA; // Light Sea Green - FWS standard

      // ======================================================================
      // Bureau of Reclamation - Light Blue
      // Water/dam related lands
      // ======================================================================
      case 'BOR':
      case 'BUREAU OF RECLAMATION':
      case 'USBR':
        return 0xFF87CEEB; // Sky Blue - water agency

      // ======================================================================
      // Army Corps of Engineers - Navy Blue
      // Water management, dam lands
      // ======================================================================
      case 'USACE':
      case 'ACE':
      case 'ARMY CORPS OF ENGINEERS':
      case 'US ARMY CORPS OF ENGINEERS':
        return 0xFF4169E1; // Royal Blue - military water

      // ======================================================================
      // Department of Defense - Dark Gray/Military
      // Military installations - restricted access
      // ======================================================================
      case 'DOD':
      case 'DEPARTMENT OF DEFENSE':
      case 'MILITARY':
        return 0xFF708090; // Slate Gray - military

      // ======================================================================
      // Department of Energy - Orange
      // Energy facilities - restricted
      // ======================================================================
      case 'DOE':
      case 'DEPARTMENT OF ENERGY':
        return 0xFFFF8C00; // Dark Orange - energy/nuclear

      // ======================================================================
      // Tennessee Valley Authority - Teal
      // Regional utility lands
      // ======================================================================
      case 'TVA':
      case 'TENNESSEE VALLEY AUTHORITY':
        return 0xFF008B8B; // Dark Cyan

      // ======================================================================
      // NASA - Space Blue
      // ======================================================================
      case 'NASA':
      case 'NATIONAL AERONAUTICS AND SPACE ADMINISTRATION':
        return 0xFF191970; // Midnight Blue

      // ======================================================================
      // Bureau of Indian Affairs - handled via TRIB ownership type
      // ======================================================================
      case 'BIA':
      case 'BUREAU OF INDIAN AFFAIRS':
        return 0xFF8B4513; // Saddle Brown (same as tribal)

      // ======================================================================
      // State agency patterns - return blue tones
      // State agencies often have codes like "IDFG" (Idaho Fish & Game)
      // ======================================================================
      default:
        // Check for state agency patterns (2-letter state code + agency)
        if (agency.length >= 2) {
          final upperAgency = agency.toUpperCase();
          // State Parks patterns
          if (upperAgency.contains('STATE PARK') ||
              upperAgency.endsWith('SP') ||
              upperAgency.contains('PARKS')) {
            return 0xFF6495ED; // Cornflower Blue - state parks
          }
          // State Fish & Game / Wildlife patterns
          if (upperAgency.contains('FISH') ||
              upperAgency.contains('GAME') ||
              upperAgency.contains('WILDLIFE') ||
              upperAgency.endsWith('FG') ||
              upperAgency.endsWith('GF') ||
              upperAgency.endsWith('FW')) {
            return 0xFF5F9EA0; // Cadet Blue - state wildlife
          }
          // State Forestry patterns
          if (upperAgency.contains('FOREST') ||
              upperAgency.contains('FORESTRY') ||
              upperAgency.endsWith('DOF')) {
            return 0xFF4169E1; // Royal Blue - state forestry
          }
          // State Land Board patterns
          if (upperAgency.contains('LAND BOARD') ||
              upperAgency.contains('STATE LAND') ||
              upperAgency.endsWith('SLB')) {
            return 0xFF4682B4; // Steel Blue - state lands
          }
        }
        return null; // Unknown agency, fall back to ownershipType
    }
  }

  /// Get permission status summary for quick assessment
  String get permissionSummary {
    if (activityPermissions.canTreasureHunt) {
      return '✅ Treasure hunting allowed';
    }
    if (activityPermissions.needsPermission) {
      return '📋 Permission required';
    }
    if (activityPermissions.mostRestrictive == PermissionStatus.ownerPermissionRequired) {
      return '📞 Contact owner for permission';
    }
    if (activityPermissions.mostRestrictive == PermissionStatus.prohibited) {
      return '❌ Treasure hunting prohibited';
    }
    return '❓ Permission status unknown';
  }

  /// Check if property requires immediate attention (restricted access)
  bool get requiresAttention {
    return activityPermissions.mostRestrictive == PermissionStatus.prohibited ||
           activityPermissions.mostRestrictive == PermissionStatus.ownerPermissionRequired ||
           accessRights.hasActiveRestrictions;
  }

  /// Get the best available boundary data for rendering
  /// Falls back through: full → high → medium → low → overview
  /// For zoom-aware selection, use [boundariesForZoom] instead
  List<List<List<double>>>? get bestBoundaries {
    return boundaries ?? highBoundaries ?? mediumBoundaries ?? lowBoundaries ?? overviewBoundaries;
  }

  /// Get appropriate boundaries based on zoom level (5-level Progressive LOD)
  ///
  /// Based on cartographic science: tolerance <= 2 x meters-per-pixel is imperceptible
  /// - zoom 15+: full (survey-accurate, 0m tolerance)
  /// - zoom 12-14: high (~5.5m tolerance)
  /// - zoom 10-11: medium (~22m tolerance)
  /// - zoom 8-9: low (~111m tolerance)
  /// - zoom 5-7: overview (~555m tolerance)
  List<List<List<double>>>? boundariesForZoom(double zoom) {
    if (zoom >= 15) {
      // On-the-ground navigation: use full detail
      return boundaries ?? highBoundaries ?? mediumBoundaries ?? lowBoundaries ?? overviewBoundaries;
    } else if (zoom >= 12) {
      // Neighborhood view: use high detail
      return highBoundaries ?? boundaries ?? mediumBoundaries ?? lowBoundaries ?? overviewBoundaries;
    } else if (zoom >= 10) {
      // City/township view: use medium detail
      return mediumBoundaries ?? lowBoundaries ?? highBoundaries ?? overviewBoundaries ?? boundaries;
    } else if (zoom >= 8) {
      // County-level view: use low detail
      return lowBoundaries ?? overviewBoundaries ?? mediumBoundaries ?? highBoundaries ?? boundaries;
    } else {
      // State/regional view: use overview
      return overviewBoundaries ?? lowBoundaries ?? mediumBoundaries ?? highBoundaries ?? boundaries;
    }
  }

  /// Check if any boundary data is available
  bool get hasBoundaries {
    return boundaries != null ||
           highBoundaries != null ||
           mediumBoundaries != null ||
           lowBoundaries != null ||
           overviewBoundaries != null;
  }

  /// Get property size summary
  String get sizeSummary {
    if (acreage == null) return 'Size unknown';
    if (acreage! < 1) return '${(acreage! * 43560).toStringAsFixed(0)} sq ft';
    if (acreage! < 1000) return '${acreage!.toStringAsFixed(1)} acres';
    return '${(acreage! / 1000).toStringAsFixed(1)}K acres';
  }

  ComprehensiveLandOwnership copyWith({
    String? id,
    String? ownerName,
    String? ownershipType,
    String? legalDescription,
    double? acreage,
    String? dataSource,
    DateTime? lastUpdated,
    List<List<List<double>>>? boundaries,
    List<List<List<double>>>? highBoundaries,
    List<List<List<double>>>? mediumBoundaries,
    List<List<List<double>>>? lowBoundaries,
    List<List<List<double>>>? overviewBoundaries,
    ActivityPermissions? activityPermissions,
    AccessRights? accessRights,
    OwnerContact? ownerContact,
    String? agencyName,
    String? unitName,
    String? designation,
    String? accessType,
    List<String>? allowedUses,
    List<String>? restrictions,
    String? contactInfo,
    String? website,
    String? fees,
    String? seasonalInfo,
  }) {
    return ComprehensiveLandOwnership(
      id: id ?? this.id,
      ownerName: ownerName ?? this.ownerName,
      ownershipType: ownershipType ?? this.ownershipType,
      legalDescription: legalDescription ?? this.legalDescription,
      acreage: acreage ?? this.acreage,
      dataSource: dataSource ?? this.dataSource,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      boundaries: boundaries ?? this.boundaries,
      highBoundaries: highBoundaries ?? this.highBoundaries,
      mediumBoundaries: mediumBoundaries ?? this.mediumBoundaries,
      lowBoundaries: lowBoundaries ?? this.lowBoundaries,
      overviewBoundaries: overviewBoundaries ?? this.overviewBoundaries,
      activityPermissions: activityPermissions ?? this.activityPermissions,
      accessRights: accessRights ?? this.accessRights,
      ownerContact: ownerContact ?? this.ownerContact,
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
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ComprehensiveLandOwnership &&
        other.id == id &&
        other.ownerName == ownerName &&
        other.ownershipType == ownershipType &&
        other.dataSource == dataSource;
  }

  @override
  int get hashCode {
    return Object.hash(id, ownerName, ownershipType, dataSource);
  }

  @override
  String toString() {
    return 'ComprehensiveLandOwnership('
        'id: $id, '
        'ownerName: $ownerName, '
        'ownershipType: $ownershipType, '
        'dataSource: $dataSource, '
        'activityPermissions: $activityPermissions)';
  }
}