import 'package:flutter/foundation.dart';

/// Sanitize a string by removing invalid UTF-8 replacement characters
/// This handles corrupted data from trail databases
String? _sanitizeString(String? input) {
  if (input == null) return null;
  // Remove the Unicode replacement character (U+FFFD) which indicates bad encoding
  // Also remove any other control characters that might cause issues
  final sanitized = input
      .replaceAll('\uFFFD', '') // Remove replacement character
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '') // Remove control chars
      .trim();
  return sanitized.isEmpty ? null : sanitized;
}

/// Model for trail data from USFS and other trail sources
@immutable
class Trail {
  final String id;
  final String trailName;
  final String? trailNumber;
  final String trailType; // TERRA, SNOW, WATER
  final String? trailClass; // 1-5
  final String? difficulty;
  final String? surfaceType;
  final List<String> allowedUses;
  final String? managingAgency;
  final String? stateCode; // US state code (e.g., 'ID', 'MN', 'SD')
  final double lengthMiles;
  final TrailGeometry geometry;
  final TrailGeometry? simplifiedGeometry;
  final String dataSource;
  // OSM relation info for trail grouping
  final String? osmRelationId; // Links segments of the same trail
  final String? osmRelationName; // Trail name from OSM relation
  final String? osmRelationRef; // Trail reference number from relation

  const Trail({
    required this.id,
    required this.trailName,
    this.trailNumber,
    required this.trailType,
    this.trailClass,
    this.difficulty,
    this.surfaceType,
    required this.allowedUses,
    this.managingAgency,
    this.stateCode,
    required this.lengthMiles,
    required this.geometry,
    this.simplifiedGeometry,
    required this.dataSource,
    this.osmRelationId,
    this.osmRelationName,
    this.osmRelationRef,
  });

  /// Whether this trail segment belongs to an OSM relation (multi-segment trail)
  bool get hasRelation => osmRelationId != null;

  factory Trail.fromJson(Map<String, dynamic> json) {
    // Sanitize trail name to handle corrupted UTF-8 data
    final rawName = json['trailName']?.toString();
    final sanitizedName = _sanitizeString(rawName);

    return Trail(
      id: json['id']?.toString() ?? '',
      trailName: sanitizedName ?? 'Unnamed Trail',
      trailNumber: json['trailNumber']?.toString(),
      trailType: json['trailType']?.toString() ?? 'TERRA',
      trailClass: json['trailClass']?.toString(),
      difficulty: json['difficulty']?.toString(),
      surfaceType: json['surfaceType']?.toString(),
      allowedUses: (json['allowedUses'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      managingAgency: _sanitizeString(json['managingAgency']?.toString()),
      stateCode: json['stateCode']?.toString(),
      lengthMiles: (json['lengthMiles'] as num?)?.toDouble() ?? 0.0,
      geometry: TrailGeometry.fromJson(
          json['geometry'] as Map<String, dynamic>? ?? {}),
      simplifiedGeometry: json['simplifiedGeometry'] != null
          ? TrailGeometry.fromJson(
              json['simplifiedGeometry'] as Map<String, dynamic>)
          : null,
      dataSource: json['dataSource']?.toString() ?? 'USFS',
      osmRelationId: json['osmRelationId']?.toString(),
      osmRelationName: _sanitizeString(json['osmRelationName']?.toString()),
      osmRelationRef: json['osmRelationRef']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trailName': trailName,
      'trailNumber': trailNumber,
      'trailType': trailType,
      'trailClass': trailClass,
      'difficulty': difficulty,
      'surfaceType': surfaceType,
      'allowedUses': allowedUses,
      'managingAgency': managingAgency,
      'stateCode': stateCode,
      'lengthMiles': lengthMiles,
      'geometry': geometry.toJson(),
      'simplifiedGeometry': simplifiedGeometry?.toJson(),
      'dataSource': dataSource,
      'osmRelationId': osmRelationId,
      'osmRelationName': osmRelationName,
      'osmRelationRef': osmRelationRef,
    };
  }

  /// Display badge for trail source
  String get sourceBadge {
    switch (dataSource.toUpperCase()) {
      case 'USFS':
      case 'BLM':
      case 'NPS':
        return 'Official';
      case 'STATE':
        return 'State';
      case 'OSM':
        return 'Community';
      default:
        return dataSource;
    }
  }

  /// Icon for trail source badge
  String get sourceBadgeIcon {
    switch (dataSource.toUpperCase()) {
      case 'USFS':
      case 'BLM':
      case 'NPS':
      case 'STATE':
        return '🏛️';
      case 'OSM':
        return '🌍';
      default:
        return '📍';
    }
  }

  /// Is this an official (government) trail?
  bool get isOfficial {
    return ['USFS', 'BLM', 'NPS', 'STATE']
        .contains(dataSource.toUpperCase());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Trail && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Filter configuration for trail display
@immutable
class TrailFilter {
  final Set<String> enabledSources; // 'USFS', 'OSM', 'BLM', 'NPS', 'STATE'
  final Set<String> enabledTypes; // USFS: 'TERRA', 'SNOW', 'WATER' | OSM: 'Hiker/Biker', etc.

  const TrailFilter({
    this.enabledSources = const {'USFS', 'OSM', 'BLM', 'NPS', 'STATE'},
    this.enabledTypes = const {
      // USFS trail types
      'TERRA',  // Land trails
      'SNOW',   // Snowmobile trails
      'WATER',  // Water trails
      // OSM trail types (from state ZIP data)
      'BICYCLE',  // Bike trails/paths
      'ROAD',     // Roads/tracks accessible for hiking
      'Hiker/Biker',
      'Hiker/Horse',
      'Hiker/Pedestrian Only',
    },
  });

  /// All known trail types (for filter UI display)
  static const Set<String> allKnownTypes = {
    // USFS trail types
    'TERRA', 'SNOW', 'WATER',
    // OSM trail types from state ZIP
    'BICYCLE', 'ROAD',
    // Community OSM trail types
    'Hiker/Biker', 'Hiker/Horse', 'Hiker/Pedestrian Only',
  };

  /// Check if a trail passes this filter
  bool passes(Trail trail) {
    // Check source filter
    if (!enabledSources.contains(trail.dataSource.toUpperCase())) {
      return false;
    }

    // Check type filter
    // Known types must be in enabledTypes to pass
    // Unknown types (new types we haven't seen) pass by default
    final isKnownType = allKnownTypes.contains(trail.trailType);
    if (isKnownType && !enabledTypes.contains(trail.trailType)) {
      return false;
    }

    return true;
  }

  /// Create a copy with modified fields
  TrailFilter copyWith({
    Set<String>? enabledSources,
    Set<String>? enabledTypes,
  }) {
    return TrailFilter(
      enabledSources: enabledSources ?? this.enabledSources,
      enabledTypes: enabledTypes ?? this.enabledTypes,
    );
  }

  /// Toggle a source on/off
  TrailFilter toggleSource(String source) {
    final newSources = Set<String>.from(enabledSources);
    if (newSources.contains(source)) {
      newSources.remove(source);
    } else {
      newSources.add(source);
    }
    return copyWith(enabledSources: newSources);
  }

  /// Toggle a trail type on/off
  TrailFilter toggleType(String type) {
    final newTypes = Set<String>.from(enabledTypes);
    if (newTypes.contains(type)) {
      newTypes.remove(type);
    } else {
      newTypes.add(type);
    }
    return copyWith(enabledTypes: newTypes);
  }

  /// Enable all sources
  TrailFilter enableAllSources() {
    return copyWith(
      enabledSources: const {'USFS', 'OSM', 'BLM', 'NPS', 'STATE'},
    );
  }

  /// Enable all types
  TrailFilter enableAllTypes() {
    return copyWith(
      enabledTypes: const {
        'TERRA', 'SNOW', 'WATER',  // USFS types
        'BICYCLE', 'ROAD',  // OSM types from state ZIP
        'Hiker/Biker', 'Hiker/Horse', 'Hiker/Pedestrian Only',  // OSM types
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrailFilter &&
          runtimeType == other.runtimeType &&
          enabledSources.length == other.enabledSources.length &&
          enabledSources.difference(other.enabledSources).isEmpty &&
          enabledTypes.length == other.enabledTypes.length &&
          enabledTypes.difference(other.enabledTypes).isEmpty;

  @override
  int get hashCode => Object.hash(enabledSources, enabledTypes);
}

/// GeoJSON LineString or MultiLineString geometry for trail paths
///
/// IMPORTANT: MultiLineString geometries preserve their nested structure
/// to avoid drawing connecting lines between disconnected segments.
@immutable
class TrailGeometry {
  final String type; // "LineString" or "MultiLineString"
  /// For LineString: [[lon, lat], [lon, lat], ...]
  /// For MultiLineString: [[[lon, lat], ...], [[lon, lat], ...], ...]
  final dynamic rawCoordinates;

  const TrailGeometry({
    required this.type,
    required this.rawCoordinates,
  });

  /// Get flattened coordinates for operations like bounding box calculation
  /// This returns all points regardless of whether it's LineString or MultiLineString
  List<List<double>> get coordinates {
    final result = <List<double>>[];
    _extractCoordinates(rawCoordinates, result);
    return result;
  }

  /// Recursively extract all coordinate pairs from nested structure
  void _extractCoordinates(Object? coords, List<List<double>> result) {
    if (coords is List) {
      if (coords.isNotEmpty && coords[0] is num) {
        // This is a single coordinate [lon, lat]
        if (coords.length >= 2) {
          result.add([
            (coords[0] as num).toDouble(),
            (coords[1] as num).toDouble(),
          ]);
        }
      } else {
        // This is an array of coordinates or nested arrays
        for (final item in coords) {
          _extractCoordinates(item, result);
        }
      }
    }
  }

  factory TrailGeometry.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'LineString';
    final coordsRaw = json['coordinates'] ?? const <dynamic>[];

    // Preserve the raw coordinate structure - don't flatten!
    // This is critical for MultiLineString to render correctly
    return TrailGeometry(
      type: type,
      rawCoordinates: coordsRaw,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'coordinates': rawCoordinates,
    };
  }

  /// Get lat/lng pairs for rendering on map (swapped from GeoJSON lon/lat)
  /// Note: This flattens MultiLineString - use rawCoordinates for rendering
  List<List<double>> get latLngPairs {
    return coordinates.map((coord) => [coord[1], coord[0]]).toList();
  }

  /// Check if this trail geometry intersects with a viewport bounding box
  /// Uses bounding box intersection for efficiency
  bool intersectsBounds({
    required double northBound,
    required double southBound,
    required double eastBound,
    required double westBound,
  }) {
    final coords = coordinates;
    if (coords.isEmpty) return false;

    // Calculate trail's bounding box
    double trailNorth = -90, trailSouth = 90;
    double trailEast = -180, trailWest = 180;

    for (final coord in coords) {
      if (coord.length < 2) continue;
      final lon = coord[0];
      final lat = coord[1];

      if (lat > trailNorth) trailNorth = lat;
      if (lat < trailSouth) trailSouth = lat;
      if (lon > trailEast) trailEast = lon;
      if (lon < trailWest) trailWest = lon;
    }

    // Check bounding box intersection
    return !(trailNorth < southBound ||
             trailSouth > northBound ||
             trailEast < westBound ||
             trailWest > eastBound);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrailGeometry &&
          runtimeType == other.runtimeType &&
          type == other.type;

  @override
  int get hashCode => type.hashCode ^ rawCoordinates.hashCode;
}

/// A group of trail segments that share the same trail name
/// Used to display multi-segment trails as a single logical trail
@immutable
class TrailGroup {
  final String trailName;
  final List<Trail> segments;
  final Trail tappedSegment; // The specific segment the user tapped
  final String? osmRelationId; // OSM relation ID if from BFF
  final double? bffTotalLengthMiles; // Pre-calculated total from BFF

  const TrailGroup({
    required this.trailName,
    required this.segments,
    required this.tappedSegment,
    this.osmRelationId,
    this.bffTotalLengthMiles,
  });

  /// Create a TrailGroup from a BFF trailGroup response
  factory TrailGroup.fromBffResponse({
    required Map<String, dynamic> json,
    required Trail tappedSegment,
  }) {
    final segments = (json['segments'] as List<dynamic>?)
            ?.map((s) => Trail.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [tappedSegment];

    return TrailGroup(
      trailName: json['trailName']?.toString() ?? tappedSegment.trailName,
      segments: segments,
      tappedSegment: tappedSegment,
      osmRelationId: json['relationId']?.toString(),
      bffTotalLengthMiles: (json['totalLengthMiles'] as num?)?.toDouble(),
    );
  }

  /// Total length of all segments combined
  /// Uses pre-calculated value from BFF if available
  double get totalLengthMiles {
    if (bffTotalLengthMiles != null) return bffTotalLengthMiles!;
    return segments.fold(0.0, (sum, trail) => sum + trail.lengthMiles);
  }

  /// Number of segments in this trail group
  int get segmentCount => segments.length;

  /// Whether this is a multi-segment trail
  bool get isMultiSegment => segments.length > 1;

  /// Index of the tapped segment (1-based for display)
  int get tappedSegmentIndex {
    final index = segments.indexWhere((t) => t.id == tappedSegment.id);
    return index >= 0 ? index + 1 : 1;
  }

  /// Get all coordinates from all segments combined
  List<List<double>> get allCoordinates {
    final List<List<double>> coords = [];
    for (final segment in segments) {
      coords.addAll(segment.geometry.coordinates);
    }
    return coords;
  }

  /// Get the first coordinate of the first segment (trail start)
  List<double>? get startCoordinate {
    if (segments.isEmpty) return null;
    // Sort segments by their first coordinate to try to find the actual start
    // For now, just use the first segment's first coordinate
    final firstSegment = segments.first;
    if (firstSegment.geometry.coordinates.isEmpty) return null;
    return firstSegment.geometry.coordinates.first;
  }

  /// Get the last coordinate of the last segment (trail end)
  List<double>? get endCoordinate {
    if (segments.isEmpty) return null;
    final lastSegment = segments.last;
    if (lastSegment.geometry.coordinates.isEmpty) return null;
    return lastSegment.geometry.coordinates.last;
  }

  /// Get representative trail data (from first segment or tapped segment)
  Trail get representativeTrail => tappedSegment;

  /// Create a TrailGroup from a list of trails by finding connected segments
  ///
  /// Uses connectivity-based grouping: starts from tapped segment and includes
  /// only segments that are physically connected (endpoints within threshold).
  /// This prevents unrelated "Unnamed Trail" segments from being grouped together.
  factory TrailGroup.fromTrailList({
    required Trail tappedTrail,
    required List<Trail> allTrails,
  }) {
    // Find all trails with the same name (case-insensitive) as candidates
    final candidates = allTrails
        .where((t) =>
            t.trailName.toLowerCase() == tappedTrail.trailName.toLowerCase())
        .toList();

    // If only one segment or no candidates, return single-segment group
    if (candidates.length <= 1) {
      return TrailGroup(
        trailName: tappedTrail.trailName,
        segments: [tappedTrail],
        tappedSegment: tappedTrail,
      );
    }

    // Build connected group using BFS from tapped segment
    final connectedSegments = _findConnectedSegments(tappedTrail, candidates);

    // Sort segments by their first coordinate longitude to approximate order
    connectedSegments.sort((a, b) {
      if (a.geometry.coordinates.isEmpty) return 1;
      if (b.geometry.coordinates.isEmpty) return -1;
      final aLon = a.geometry.coordinates.first[0];
      final bLon = b.geometry.coordinates.first[0];
      return aLon.compareTo(bLon);
    });

    return TrailGroup(
      trailName: tappedTrail.trailName,
      segments: connectedSegments,
      tappedSegment: tappedTrail,
    );
  }

  /// Find all segments connected to the starting segment using BFS
  /// Two segments are connected if any of their endpoints are within threshold
  ///
  /// Uses two-pass approach:
  /// 1. Strict threshold (~55m) for tight connections
  /// 2. Extended threshold (~500m) for named trails to bridge gaps (road crossings, etc.)
  static List<Trail> _findConnectedSegments(
    Trail startSegment,
    List<Trail> candidates,
  ) {
    // Strict threshold: ~55 meters for tight connections
    const strictThreshold = 0.0005;
    // Extended threshold: ~500 meters to bridge gaps (road crossings, towns)
    const extendedThreshold = 0.005;

    final connected = <Trail>{startSegment};
    final queue = <Trail>[startSegment];
    final remaining = candidates.where((t) => t.id != startSegment.id).toSet();

    // First pass: strict connectivity
    _bfsConnect(connected, queue, remaining, strictThreshold);

    // Second pass: extended connectivity for named trails only
    // Skip if trail has a generic name that might match unrelated trails
    if (remaining.isNotEmpty && !_isGenericTrailName(startSegment.trailName)) {
      // Re-seed queue with all currently connected segments
      queue.addAll(connected);
      _bfsConnect(connected, queue, remaining, extendedThreshold);
    }

    return connected.toList();
  }

  /// BFS helper to find connected segments within threshold
  static void _bfsConnect(
    Set<Trail> connected,
    List<Trail> queue,
    Set<Trail> remaining,
    double threshold,
  ) {
    while (queue.isNotEmpty && remaining.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentEndpoints = _getEndpoints(current);

      // Find all remaining segments that connect to current
      final toAdd = <Trail>[];
      for (final candidate in remaining) {
        final candidateEndpoints = _getEndpoints(candidate);

        if (_endpointsConnect(currentEndpoints, candidateEndpoints, threshold)) {
          toAdd.add(candidate);
        }
      }

      // Add newly connected segments to the group
      for (final segment in toAdd) {
        connected.add(segment);
        queue.add(segment);
        remaining.remove(segment);
      }
    }
  }

  /// Check if a trail name is generic (shouldn't use extended threshold)
  static bool _isGenericTrailName(String name) {
    final lowerName = name.toLowerCase().trim();
    const genericNames = [
      'unnamed trail',
      'unnamed',
      'trail',
      'path',
      'footpath',
      'track',
      'unknown',
      '', // empty name
    ];
    return genericNames.contains(lowerName);
  }

  /// Get start and end coordinates of a trail segment
  static List<List<double>> _getEndpoints(Trail trail) {
    final coords = trail.geometry.coordinates;
    if (coords.isEmpty) return [];
    if (coords.length == 1) return [coords.first];
    return [coords.first, coords.last];
  }

  /// Check if any endpoints from two sets are within threshold distance
  static bool _endpointsConnect(
    List<List<double>> endpoints1,
    List<List<double>> endpoints2,
    double threshold,
  ) {
    for (final p1 in endpoints1) {
      for (final p2 in endpoints2) {
        final dLon = (p1[0] - p2[0]).abs();
        final dLat = (p1[1] - p2[1]).abs();
        // Simple distance check (not geodesic, but good enough for nearby points)
        if (dLon < threshold && dLat < threshold) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrailGroup &&
          runtimeType == other.runtimeType &&
          trailName == other.trailName &&
          tappedSegment.id == other.tappedSegment.id;

  @override
  int get hashCode => trailName.hashCode ^ tappedSegment.id.hashCode;
}
