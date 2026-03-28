import 'package:flutter/material.dart';

/// Radio technology type for cell towers
enum RadioType {
  gsm('GSM', '2G (GSM)', Color(0xFFFF6B6B), 1, 5000),
  cdma('CDMA', '2G (CDMA)', Color(0xFFFF6B6B), 1, 5000),
  umts('UMTS', '3G (UMTS)', Color(0xFFFFA94D), 2, 3000),
  lte('LTE', '4G (LTE)', Color(0xFF00BCD4), 3, 3000), // Cyan - visible on green terrain
  nr('NR', '5G (NR)', Color(0xFF9C27B0), 4, 1000); // Purple - distinct from other colors

  const RadioType(this.code, this.displayName, this.color, this.order, this.minRangeMeters);

  /// Code as stored in database/JSON (e.g., 'LTE')
  final String code;

  /// Human-readable display name (e.g., '4G (LTE)')
  final String displayName;

  /// Color for map rendering
  final Color color;

  /// Sort order (lower = weaker signal technology)
  final int order;

  /// Minimum realistic range in meters (OpenCelliD data often underreports)
  /// 2G: 5km, 3G: 3km, 4G: 3km, 5G: 1km
  final int minRangeMeters;

  /// Get hex color string for GeoJSON properties
  String get colorHex {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).substring(2).toUpperCase()}';
  }

  /// Parse from code string
  static RadioType fromCode(String code) {
    return RadioType.values.firstWhere(
      (type) => type.code.toUpperCase() == code.toUpperCase(),
      orElse: () => RadioType.lte, // Default to LTE if unknown
    );
  }

  /// All types sorted by signal strength (strongest first)
  static List<RadioType> get sortedByStrength {
    return List.from(RadioType.values)..sort((a, b) => b.order.compareTo(a.order));
  }
}

/// Cell tower data from OpenCelliD
@immutable
class CellTower {
  /// Unique identifier (format: MCC-MNC-LAC-CID)
  final String id;

  /// Latitude in decimal degrees
  final double latitude;

  /// Longitude in decimal degrees
  final double longitude;

  /// Radio technology type (GSM, UMTS, LTE, NR)
  final RadioType radioType;

  /// Mobile Country Code
  final int mcc;

  /// Mobile Network Code
  final int mnc;

  /// Carrier name (e.g., 'T-Mobile', 'Verizon')
  final String? carrier;

  /// Estimated coverage radius in meters
  final int rangeMeters;

  /// Number of samples/measurements (data confidence indicator)
  final int samples;

  /// Last time this tower was updated in OpenCelliD
  final DateTime? lastUpdated;

  /// State code where tower is located
  final String stateCode;

  const CellTower({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radioType,
    required this.mcc,
    required this.mnc,
    this.carrier,
    required this.rangeMeters,
    this.samples = 0,
    this.lastUpdated,
    required this.stateCode,
  });

  /// Create from JSON (as stored in cell.zip data.json)
  factory CellTower.fromJson(Map<String, dynamic> json, String stateCode) {
    return CellTower(
      id: json['id'] as String,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lon'] as num).toDouble(),
      radioType: RadioType.fromCode(json['radio'] as String),
      mcc: json['mcc'] as int,
      mnc: json['mnc'] as int,
      carrier: json['carrier'] as String?,
      rangeMeters: json['range_meters'] as int? ?? 5000,
      samples: json['samples'] as int? ?? 0,
      lastUpdated: json['updated'] != null
          ? DateTime.tryParse(json['updated'] as String)
          : null,
      stateCode: stateCode,
    );
  }

  /// Create from database row
  factory CellTower.fromDatabase(Map<String, dynamic> row) {
    return CellTower(
      id: row['id'] as String,
      latitude: row['latitude'] as double,
      longitude: row['longitude'] as double,
      radioType: RadioType.fromCode(row['radio_type'] as String),
      mcc: row['mcc'] as int,
      mnc: row['mnc'] as int,
      carrier: row['carrier'] as String?,
      rangeMeters: row['range_meters'] as int,
      samples: row['samples'] as int? ?? 0,
      lastUpdated: row['last_updated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['last_updated'] as int)
          : null,
      stateCode: row['state_code'] as String,
    );
  }

  /// Convert to database row for insertion
  Map<String, dynamic> toDatabaseRow() {
    return {
      'id': id,
      'radio_type': radioType.code,
      'mcc': mcc,
      'mnc': mnc,
      'carrier': carrier,
      'latitude': latitude,
      'longitude': longitude,
      'range_meters': rangeMeters,
      'samples': samples,
      'last_updated': lastUpdated?.millisecondsSinceEpoch,
      'state_code': stateCode,
      'cached_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Get coordinates as [longitude, latitude] for GeoJSON
  List<double> get geoJsonCoordinates => [longitude, latitude];

  /// Effective range in meters, applying minimum for radio type
  /// OpenCelliD crowd-sourced data often underreports ranges
  int get effectiveRangeMeters => rangeMeters < radioType.minRangeMeters
      ? radioType.minRangeMeters
      : rangeMeters;

  /// Convert to GeoJSON Feature for Mapbox rendering
  Map<String, dynamic> toGeoJsonFeature() {
    return {
      'type': 'Feature',
      'id': id,
      'geometry': {
        'type': 'Point',
        'coordinates': geoJsonCoordinates,
      },
      'properties': {
        'id': id,
        'radio': radioType.code,
        'radio_name': radioType.displayName,
        'carrier': carrier ?? 'Unknown',
        'range_meters': rangeMeters,
        'samples': samples,
        'color': radioType.colorHex,
        'order': radioType.order,
      },
    };
  }

  /// Get formatted range string (e.g., '5.0 km' or '500 m')
  String get rangeFormatted {
    if (rangeMeters >= 1000) {
      return '${(rangeMeters / 1000).toStringAsFixed(1)} km';
    }
    return '$rangeMeters m';
  }

  /// Get formatted last updated string
  String? get lastUpdatedFormatted {
    if (lastUpdated == null) return null;
    final now = DateTime.now();
    final diff = now.difference(lastUpdated!);
    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()} year${diff.inDays > 730 ? 's' : ''} ago';
    } else if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()} month${diff.inDays > 60 ? 's' : ''} ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    }
    return 'Today';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellTower && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CellTower{id: $id, radio: ${radioType.code}, carrier: $carrier}';

  CellTower copyWith({
    String? id,
    double? latitude,
    double? longitude,
    RadioType? radioType,
    int? mcc,
    int? mnc,
    String? carrier,
    int? rangeMeters,
    int? samples,
    DateTime? lastUpdated,
    String? stateCode,
  }) {
    return CellTower(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radioType: radioType ?? this.radioType,
      mcc: mcc ?? this.mcc,
      mnc: mnc ?? this.mnc,
      carrier: carrier ?? this.carrier,
      rangeMeters: rangeMeters ?? this.rangeMeters,
      samples: samples ?? this.samples,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      stateCode: stateCode ?? this.stateCode,
    );
  }
}

/// Filter configuration for cell coverage overlay
@immutable
class CellCoverageFilter {
  /// Set of enabled radio types to display
  final Set<RadioType> enabledTypes;

  /// Minimum number of samples (data confidence threshold)
  final int? minSamples;

  const CellCoverageFilter({
    this.enabledTypes = const {
      RadioType.gsm,
      RadioType.cdma,
      RadioType.umts,
      RadioType.lte,
      RadioType.nr,
    },
    this.minSamples,
  });

  /// Default filter showing all radio types
  static const CellCoverageFilter defaultFilter = CellCoverageFilter();

  /// Filter showing only modern networks (4G+)
  static const CellCoverageFilter modernOnly = CellCoverageFilter(
    enabledTypes: {RadioType.lte, RadioType.nr},
  );

  /// Check if a tower passes this filter
  bool passes(CellTower tower) {
    if (!enabledTypes.contains(tower.radioType)) {
      return false;
    }
    if (minSamples != null && tower.samples < minSamples!) {
      return false;
    }
    return true;
  }

  CellCoverageFilter copyWith({
    Set<RadioType>? enabledTypes,
    int? minSamples,
  }) {
    return CellCoverageFilter(
      enabledTypes: enabledTypes ?? this.enabledTypes,
      minSamples: minSamples ?? this.minSamples,
    );
  }

  /// Toggle a radio type on/off
  CellCoverageFilter toggleType(RadioType type) {
    final newTypes = Set<RadioType>.from(enabledTypes);
    if (newTypes.contains(type)) {
      newTypes.remove(type);
    } else {
      newTypes.add(type);
    }
    return copyWith(enabledTypes: newTypes);
  }

  /// Enable all radio types
  CellCoverageFilter enableAll() {
    return copyWith(enabledTypes: Set.from(RadioType.values));
  }

  /// Disable all radio types
  CellCoverageFilter disableAll() {
    return copyWith(enabledTypes: const {});
  }

  bool get allTypesEnabled => enabledTypes.length == RadioType.values.length;
  bool get noTypesEnabled => enabledTypes.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellCoverageFilter &&
          runtimeType == other.runtimeType &&
          enabledTypes.length == other.enabledTypes.length &&
          enabledTypes.difference(other.enabledTypes).isEmpty &&
          minSamples == other.minSamples;

  @override
  int get hashCode => Object.hash(enabledTypes, minSamples);
}
