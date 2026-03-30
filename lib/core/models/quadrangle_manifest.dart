import 'dart:math';

/// Models for quadrangle-level historical map downloads.
///
/// This system enables granular downloads of individual USGS quadrangles
/// (~15x15 miles each) rather than entire state-level MBTiles files.

/// Geographic bounds for a quadrangle (USGS 7.5 minute series)
class QuadrangleBounds {
  const QuadrangleBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  /// Western boundary (longitude, negative for Western Hemisphere)
  final double west;

  /// Southern boundary (latitude)
  final double south;

  /// Eastern boundary (longitude)
  final double east;

  /// Northern boundary (latitude)
  final double north;

  /// Center longitude
  double get centerLng => (west + east) / 2;

  /// Center latitude
  double get centerLat => (south + north) / 2;

  /// Width in degrees
  double get width => east - west;

  /// Height in degrees
  double get height => north - south;

  /// Approximate area in square degrees
  double get areaDegrees => width * height;

  /// Check if a point is within this quadrangle
  bool containsPoint(double lat, double lng) {
    return lat >= south && lat <= north && lng >= west && lng <= east;
  }

  /// Check if this quadrangle intersects with another bounding box (AABB test)
  bool intersects(QuadrangleBounds other) {
    return !(other.west > east ||
        other.east < west ||
        other.south > north ||
        other.north < south);
  }

  /// Calculate what percentage of viewport is covered by this quadrangle
  /// Returns 0.0 to 1.0
  double calculateCoverage(QuadrangleBounds viewport) {
    if (!intersects(viewport)) return 0.0;

    // Calculate intersection bounds
    final iWest = max(west, viewport.west);
    final iSouth = max(south, viewport.south);
    final iEast = min(east, viewport.east);
    final iNorth = min(north, viewport.north);

    final intersectionArea = (iEast - iWest) * (iNorth - iSouth);
    final viewportArea = viewport.width * viewport.height;

    if (viewportArea <= 0) return 0.0;
    return (intersectionArea / viewportArea).clamp(0.0, 1.0);
  }

  /// Check if viewport meaningfully intersects (>30% coverage)
  bool viewportMeaningfullyIntersects(QuadrangleBounds viewport,
      {double threshold = 0.3}) {
    return calculateCoverage(viewport) >= threshold;
  }

  /// Human-readable description of bounds
  String get description {
    final latDir = centerLat >= 0 ? 'N' : 'S';
    final lngDir = centerLng >= 0 ? 'E' : 'W';
    return '${centerLat.abs().toStringAsFixed(2)}°$latDir, '
        '${centerLng.abs().toStringAsFixed(2)}°$lngDir';
  }

  factory QuadrangleBounds.fromJson(Map<String, dynamic> json) {
    return QuadrangleBounds(
      west: (json['west'] as num).toDouble(),
      south: (json['south'] as num).toDouble(),
      east: (json['east'] as num).toDouble(),
      north: (json['north'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'west': west,
        'south': south,
        'east': east,
        'north': north,
      };

  @override
  String toString() =>
      'QuadrangleBounds(west: $west, south: $south, east: $east, north: $north)';
}

/// A single USGS quadrangle map tile
class QuadrangleManifest {
  const QuadrangleManifest({
    required this.id,
    required this.name,
    required this.file,
    required this.size,
    required this.bounds,
    required this.year,
    this.scale,
    this.checksum,
  });

  /// Unique identifier (e.g., 'laramie_1897', 't42n_r104w')
  final String id;

  /// USGS quad name (e.g., 'Laramie', 'South Pass')
  final String name;

  /// Filename on server relative to state maps directory
  /// (e.g., 'early_topo/quads/laramie_1897.mbtiles')
  final String file;

  /// Size in bytes
  final int size;

  /// Geographic bounds
  final QuadrangleBounds bounds;

  /// Publication year
  final int year;

  /// Map scale (e.g., '1:62500', '1:24000')
  final String? scale;

  /// SHA256 checksum for integrity verification
  final String? checksum;

  /// Human-readable formatted size
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  /// Display name with year (e.g., 'Laramie (1897)')
  String get displayName => '$name ($year)';

  /// Short date display (e.g., '1897')
  String get yearDisplay => year.toString();

  factory QuadrangleManifest.fromJson(Map<String, dynamic> json) {
    return QuadrangleManifest(
      id: json['id'] as String,
      name: json['name'] as String,
      file: json['file'] as String,
      size: json['size'] as int,
      bounds: QuadrangleBounds.fromJson(json['bounds'] as Map<String, dynamic>),
      year: json['year'] as int,
      scale: json['scale'] as String?,
      checksum: json['checksum'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'file': file,
        'size': size,
        'bounds': bounds.toJson(),
        'year': year,
        if (scale != null) 'scale': scale,
        if (checksum != null) 'checksum': checksum,
      };

  @override
  String toString() => 'QuadrangleManifest($id: $displayName, $formattedSize)';
}

/// Era grouping of historical maps (e.g., Survey Era, Early Topos)
class HistoricalEra {
  const HistoricalEra({
    required this.id,
    required this.name,
    required this.description,
    required this.yearRange,
    required this.quadrangles,
  });

  /// Era identifier (e.g., 'survey', 'early_topo')
  final String id;

  /// Human-readable name (e.g., 'Survey Era Maps', 'Early Topos')
  final String name;

  /// Description of this era
  final String description;

  /// Year range (e.g., '1850-1890', '1890-1920')
  final String yearRange;

  /// Available quadrangles for this era
  final List<QuadrangleManifest> quadrangles;

  /// Total size of all quadrangles in bytes
  int get totalSize => quadrangles.fold(0, (sum, q) => sum + q.size);

  /// Number of available quadrangles
  int get quadrangleCount => quadrangles.length;

  /// Formatted total size
  String get formattedTotalSize {
    final size = totalSize;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  /// Get quadrangle by ID
  QuadrangleManifest? getQuadrangle(String quadId) {
    return quadrangles.where((q) => q.id == quadId).firstOrNull;
  }

  /// Find quadrangles that cover a specific point
  List<QuadrangleManifest> findQuadranglesAt(double lat, double lng) {
    return quadrangles.where((q) => q.bounds.containsPoint(lat, lng)).toList();
  }

  /// Find quadrangles that intersect a bounding box
  List<QuadrangleManifest> findQuadranglesInBounds(QuadrangleBounds bounds) {
    return quadrangles.where((q) => q.bounds.intersects(bounds)).toList();
  }

  factory HistoricalEra.fromJson(Map<String, dynamic> json) {
    return HistoricalEra(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      yearRange: json['yearRange'] as String,
      quadrangles: (json['quadrangles'] as List<dynamic>)
          .map((q) => QuadrangleManifest.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'yearRange': yearRange,
        'quadrangles': quadrangles.map((q) => q.toJson()).toList(),
      };

  @override
  String toString() => 'HistoricalEra($id: $name, $quadrangleCount quads)';
}

/// State-level quadrangle manifest containing all available historical maps
class StateQuadrangleManifest {
  const StateQuadrangleManifest({
    required this.state,
    required this.version,
    required this.generatedAt,
    required this.eras,
  });

  /// Two-letter state code (e.g., 'WY', 'CO')
  final String state;

  /// Version identifier for this manifest
  final String version;

  /// When this manifest was generated
  final DateTime generatedAt;

  /// Available eras with their quadrangles
  final List<HistoricalEra> eras;

  /// Total number of quadrangles across all eras
  int get totalQuadrangleCount =>
      eras.fold(0, (sum, e) => sum + e.quadrangleCount);

  /// Total size of all quadrangles across all eras
  int get totalSize => eras.fold(0, (sum, e) => sum + e.totalSize);

  /// Formatted total size
  String get formattedTotalSize {
    final size = totalSize;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  /// Get era by ID
  HistoricalEra? getEra(String eraId) {
    return eras.where((e) => e.id == eraId).firstOrNull;
  }

  /// Get all quadrangles across all eras
  List<QuadrangleManifest> get allQuadrangles =>
      eras.expand((e) => e.quadrangles).toList();

  /// Find quadrangles that cover a specific point (across all eras)
  List<QuadrangleManifest> findQuadranglesAt(double lat, double lng) {
    return allQuadrangles
        .where((q) => q.bounds.containsPoint(lat, lng))
        .toList();
  }

  /// Find quadrangles that intersect a bounding box (across all eras)
  List<QuadrangleManifest> findQuadranglesInBounds(QuadrangleBounds bounds) {
    return allQuadrangles.where((q) => q.bounds.intersects(bounds)).toList();
  }

  factory StateQuadrangleManifest.fromJson(Map<String, dynamic> json) {
    return StateQuadrangleManifest(
      state: json['state'] as String,
      version: json['version'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      eras: (json['eras'] as List<dynamic>)
          .map((e) => HistoricalEra.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'state': state,
        'version': version,
        'generatedAt': generatedAt.toIso8601String(),
        'eras': eras.map((e) => e.toJson()).toList(),
      };

  @override
  String toString() {
    final eraCount = eras.length;
    return 'StateQuadrangleManifest($state: $eraCount eras, $totalQuadrangleCount quads)';
  }
}

/// Tracks download status for a specific quadrangle
class QuadrangleDownloadStatus {
  const QuadrangleDownloadStatus({
    required this.stateCode,
    required this.eraId,
    required this.quadId,
    this.isDownloaded = false,
    this.downloadedAt,
    this.localSize,
    this.localFilePath,
  });

  final String stateCode;
  final String eraId;
  final String quadId;
  final bool isDownloaded;
  final DateTime? downloadedAt;
  final int? localSize;
  final String? localFilePath;

  /// Unique key for this quadrangle
  String get key => '${stateCode}_${eraId}_$quadId';

  QuadrangleDownloadStatus copyWith({
    bool? isDownloaded,
    DateTime? downloadedAt,
    int? localSize,
    String? localFilePath,
  }) {
    return QuadrangleDownloadStatus(
      stateCode: stateCode,
      eraId: eraId,
      quadId: quadId,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      localSize: localSize ?? this.localSize,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }

  factory QuadrangleDownloadStatus.fromJson(Map<String, dynamic> json) {
    return QuadrangleDownloadStatus(
      stateCode: json['stateCode'] as String,
      eraId: json['eraId'] as String,
      quadId: json['quadId'] as String,
      isDownloaded: json['isDownloaded'] as bool? ?? false,
      downloadedAt: json['downloadedAt'] != null
          ? DateTime.parse(json['downloadedAt'] as String)
          : null,
      localSize: json['localSize'] as int?,
      localFilePath: json['localFilePath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'stateCode': stateCode,
        'eraId': eraId,
        'quadId': quadId,
        'isDownloaded': isDownloaded,
        if (downloadedAt != null) 'downloadedAt': downloadedAt!.toIso8601String(),
        if (localSize != null) 'localSize': localSize,
        if (localFilePath != null) 'localFilePath': localFilePath,
      };
}
