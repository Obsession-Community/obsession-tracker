import 'package:flutter/foundation.dart';

/// Detailed property information including history, coordinates, and environmental data
@immutable
class DetailedPropertyInfo {
  const DetailedPropertyInfo({
    required this.coordinates,
    required this.magneticDeclination,
    this.propertyHistory = const [],
    this.surveyData,
    this.environmentalInfo,
    this.boundaryDetails,
    this.additionalMetadata = const [],
  });

  final PropertyCoordinates coordinates;
  final MagneticDeclination magneticDeclination;
  final List<PropertyHistoryEntry> propertyHistory;
  final SurveyData? surveyData;
  final EnvironmentalInfo? environmentalInfo;
  final BoundaryDetails? boundaryDetails;
  final List<MetadataEntry> additionalMetadata;

  factory DetailedPropertyInfo.fromJson(Map<String, dynamic> json) {
    return DetailedPropertyInfo(
      coordinates: PropertyCoordinates.fromJson(json['coordinates'] as Map<String, dynamic>),
      magneticDeclination: MagneticDeclination.fromJson(json['magneticDeclination'] as Map<String, dynamic>),
      propertyHistory: (json['propertyHistory'] as List<dynamic>?)
          ?.map((e) => PropertyHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList() ?? const [],
      surveyData: json['surveyData'] != null
          ? SurveyData.fromJson(json['surveyData'] as Map<String, dynamic>)
          : null,
      environmentalInfo: json['environmentalInfo'] != null
          ? EnvironmentalInfo.fromJson(json['environmentalInfo'] as Map<String, dynamic>)
          : null,
      boundaryDetails: json['boundaryDetails'] != null
          ? BoundaryDetails.fromJson(json['boundaryDetails'] as Map<String, dynamic>)
          : null,
      additionalMetadata: (json['additionalMetadata'] as List<dynamic>?)
          ?.map((e) => MetadataEntry.fromJson(e as Map<String, dynamic>))
          .toList() ?? const [],
    );
  }
}

/// Property coordinates with various reference systems
@immutable
class PropertyCoordinates {
  const PropertyCoordinates({
    required this.latitude,
    required this.longitude,
    required this.centroidLat,
    required this.centroidLon,
    required this.boundsNorth,
    required this.boundsSouth,
    required this.boundsEast,
    required this.boundsWest,
    this.utmZone,
    this.utmEasting,
    this.utmNorthing,
    this.township,
    this.range,
    this.section,
    this.quarterSection,
  });

  final double latitude;
  final double longitude;
  final double centroidLat;
  final double centroidLon;
  final double boundsNorth;
  final double boundsSouth;
  final double boundsEast;
  final double boundsWest;
  final String? utmZone;
  final double? utmEasting;
  final double? utmNorthing;
  final String? township;
  final String? range;
  final String? section;
  final String? quarterSection;

  factory PropertyCoordinates.fromJson(Map<String, dynamic> json) {
    return PropertyCoordinates(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      centroidLat: (json['centroidLat'] as num).toDouble(),
      centroidLon: (json['centroidLon'] as num).toDouble(),
      boundsNorth: (json['boundsNorth'] as num).toDouble(),
      boundsSouth: (json['boundsSouth'] as num).toDouble(),
      boundsEast: (json['boundsEast'] as num).toDouble(),
      boundsWest: (json['boundsWest'] as num).toDouble(),
      utmZone: json['utmZone'] as String?,
      utmEasting: (json['utmEasting'] as num?)?.toDouble(),
      utmNorthing: (json['utmNorthing'] as num?)?.toDouble(),
      township: json['township'] as String?,
      range: json['range'] as String?,
      section: json['section'] as String?,
      quarterSection: json['quarterSection'] as String?,
    );
  }
}

/// Magnetic declination information for navigation
@immutable
class MagneticDeclination {
  const MagneticDeclination({
    required this.declinationDegrees,
    required this.annualChange,
    required this.calculatedDate,
    this.gridVariation,
    required this.headingCorrection,
  });

  final double declinationDegrees;
  final double annualChange;
  final String calculatedDate;
  final double? gridVariation;
  final double headingCorrection;

  String get directionLabel {
    if (declinationDegrees > 0) return 'East';
    if (declinationDegrees < 0) return 'West';
    return 'Zero';
  }

  factory MagneticDeclination.fromJson(Map<String, dynamic> json) {
    return MagneticDeclination(
      declinationDegrees: (json['declinationDegrees'] as num).toDouble(),
      annualChange: (json['annualChange'] as num).toDouble(),
      calculatedDate: json['calculatedDate'] as String,
      gridVariation: (json['gridVariation'] as num?)?.toDouble(),
      headingCorrection: (json['headingCorrection'] as num).toDouble(),
    );
  }
}

/// Property history entry
@immutable
class PropertyHistoryEntry {
  const PropertyHistoryEntry({
    required this.date,
    required this.eventType,
    required this.description,
    this.previousOwner,
    this.newOwner,
    this.salePrice,
    this.acreageChange,
  });

  final String date;
  final String eventType;
  final String description;
  final String? previousOwner;
  final String? newOwner;
  final double? salePrice;
  final double? acreageChange;

  factory PropertyHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PropertyHistoryEntry(
      date: json['date'] as String,
      eventType: json['eventType'] as String,
      description: json['description'] as String,
      previousOwner: json['previousOwner'] as String?,
      newOwner: json['newOwner'] as String?,
      salePrice: (json['salePrice'] as num?)?.toDouble(),
      acreageChange: (json['acreageChange'] as num?)?.toDouble(),
    );
  }
}

/// Survey and legal description data
@immutable
class SurveyData {
  const SurveyData({
    this.surveyDate,
    this.surveyor,
    this.platBook,
    this.platPage,
    this.deedBook,
    this.deedPage,
    required this.legalDescriptionFull,
    this.metesBounds,
    this.surveyAccuracy,
  });

  final String? surveyDate;
  final String? surveyor;
  final String? platBook;
  final String? platPage;
  final String? deedBook;
  final String? deedPage;
  final String legalDescriptionFull;
  final String? metesBounds;
  final String? surveyAccuracy;

  factory SurveyData.fromJson(Map<String, dynamic> json) {
    return SurveyData(
      surveyDate: json['surveyDate'] as String?,
      surveyor: json['surveyor'] as String?,
      platBook: json['platBook'] as String?,
      platPage: json['platPage'] as String?,
      deedBook: json['deedBook'] as String?,
      deedPage: json['deedPage'] as String?,
      legalDescriptionFull: json['legalDescriptionFull'] as String,
      metesBounds: json['metesBounds'] as String?,
      surveyAccuracy: json['surveyAccuracy'] as String?,
    );
  }
}

/// Environmental and geological information
@immutable
class EnvironmentalInfo {
  const EnvironmentalInfo({
    this.elevationFt,
    this.elevationM,
    this.terrainType,
    this.soilType,
    this.vegetationType,
    this.waterFeatures = const [],
    this.geologicalFeatures = const [],
    this.wildlifeHabitat,
    this.fireRisk,
    this.floodZone,
  });

  final double? elevationFt;
  final double? elevationM;
  final String? terrainType;
  final String? soilType;
  final String? vegetationType;
  final List<String> waterFeatures;
  final List<String> geologicalFeatures;
  final String? wildlifeHabitat;
  final String? fireRisk;
  final String? floodZone;

  factory EnvironmentalInfo.fromJson(Map<String, dynamic> json) {
    return EnvironmentalInfo(
      elevationFt: (json['elevationFt'] as num?)?.toDouble(),
      elevationM: (json['elevationM'] as num?)?.toDouble(),
      terrainType: json['terrainType'] as String?,
      soilType: json['soilType'] as String?,
      vegetationType: json['vegetationType'] as String?,
      waterFeatures: (json['waterFeatures'] as List<dynamic>?)?.cast<String>() ?? const [],
      geologicalFeatures: (json['geologicalFeatures'] as List<dynamic>?)?.cast<String>() ?? const [],
      wildlifeHabitat: json['wildlifeHabitat'] as String?,
      fireRisk: json['fireRisk'] as String?,
      floodZone: json['floodZone'] as String?,
    );
  }
}

/// Boundary and access details
@immutable
class BoundaryDetails {
  const BoundaryDetails({
    this.boundaryMarkers = const [],
    this.fenceType,
    this.gates = const [],
    this.accessRoads = const [],
    this.parkingAreas = const [],
    this.trailAccess = const [],
  });

  final List<BoundaryMarker> boundaryMarkers;
  final String? fenceType;
  final List<GateInfo> gates;
  final List<AccessRoad> accessRoads;
  final List<ParkingArea> parkingAreas;
  final List<TrailAccess> trailAccess;

  factory BoundaryDetails.fromJson(Map<String, dynamic> json) {
    return BoundaryDetails(
      boundaryMarkers: (json['boundaryMarkers'] as List<dynamic>?)
          ?.map((e) => BoundaryMarker.fromJson(e as Map<String, dynamic>))
          .toList() ?? const [],
      fenceType: json['fenceType'] as String?,
      gates: (json['gates'] as List<dynamic>?)
          ?.map((e) => GateInfo.fromJson(e as Map<String, dynamic>))
          .toList() ?? const [],
      accessRoads: (json['accessRoads'] as List<dynamic>?)
          ?.map((e) => AccessRoad.fromJson(e as Map<String, dynamic>))
          .toList() ?? const [],
      parkingAreas: (json['parkingAreas'] as List<dynamic>?)
          ?.map((e) => ParkingArea.fromJson(e as Map<String, dynamic>))
          .toList() ?? const [],
      trailAccess: (json['trailAccess'] as List<dynamic>?)
          ?.map((e) => TrailAccess.fromJson(e as Map<String, dynamic>))
          .toList() ?? const [],
    );
  }
}

// Supporting classes
@immutable
class BoundaryMarker {
  const BoundaryMarker({
    required this.markerType,
    required this.latitude,
    required this.longitude,
    required this.description,
    this.condition,
  });

  final String markerType;
  final double latitude;
  final double longitude;
  final String description;
  final String? condition;

  factory BoundaryMarker.fromJson(Map<String, dynamic> json) {
    return BoundaryMarker(
      markerType: json['markerType'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      description: json['description'] as String,
      condition: json['condition'] as String?,
    );
  }
}

@immutable
class GateInfo {
  const GateInfo({
    required this.gateType,
    required this.locationLat,
    required this.locationLon,
    required this.isLocked,
    this.accessInstructions,
  });

  final String gateType;
  final double locationLat;
  final double locationLon;
  final bool isLocked;
  final String? accessInstructions;

  factory GateInfo.fromJson(Map<String, dynamic> json) {
    return GateInfo(
      gateType: json['gateType'] as String,
      locationLat: (json['locationLat'] as num).toDouble(),
      locationLon: (json['locationLon'] as num).toDouble(),
      isLocked: json['isLocked'] as bool,
      accessInstructions: json['accessInstructions'] as String?,
    );
  }
}

@immutable
class AccessRoad {
  const AccessRoad({
    this.roadName,
    required this.roadType,
    required this.condition,
    this.seasonalAccess,
  });

  final String? roadName;
  final String roadType;
  final String condition;
  final String? seasonalAccess;

  factory AccessRoad.fromJson(Map<String, dynamic> json) {
    return AccessRoad(
      roadName: json['roadName'] as String?,
      roadType: json['roadType'] as String,
      condition: json['condition'] as String,
      seasonalAccess: json['seasonalAccess'] as String?,
    );
  }
}

@immutable
class ParkingArea {
  const ParkingArea({
    this.name,
    required this.latitude,
    required this.longitude,
    this.capacity,
    this.facilities = const [],
  });

  final String? name;
  final double latitude;
  final double longitude;
  final int? capacity;
  final List<String> facilities;

  factory ParkingArea.fromJson(Map<String, dynamic> json) {
    return ParkingArea(
      name: json['name'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      capacity: json['capacity'] as int?,
      facilities: (json['facilities'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}

@immutable
class TrailAccess {
  const TrailAccess({
    required this.trailName,
    this.difficulty,
    this.lengthMiles,
    required this.trailheadLat,
    required this.trailheadLon,
  });

  final String trailName;
  final String? difficulty;
  final double? lengthMiles;
  final double trailheadLat;
  final double trailheadLon;

  factory TrailAccess.fromJson(Map<String, dynamic> json) {
    return TrailAccess(
      trailName: json['trailName'] as String,
      difficulty: json['difficulty'] as String?,
      lengthMiles: (json['lengthMiles'] as num?)?.toDouble(),
      trailheadLat: (json['trailheadLat'] as num).toDouble(),
      trailheadLon: (json['trailheadLon'] as num).toDouble(),
    );
  }
}

@immutable
class MetadataEntry {
  const MetadataEntry({
    required this.key,
    required this.value,
    this.source,
    this.lastUpdated,
  });

  final String key;
  final String value;
  final String? source;
  final String? lastUpdated;

  factory MetadataEntry.fromJson(Map<String, dynamic> json) {
    return MetadataEntry(
      key: json['key'] as String,
      value: json['value'] as String,
      source: json['source'] as String?,
      lastUpdated: json['lastUpdated'] as String?,
    );
  }
}
