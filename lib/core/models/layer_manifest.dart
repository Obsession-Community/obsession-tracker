/// Models for the layer-based download manifest system.
///
/// This system provides a flexible, extensible way to manage downloadable
/// data layers including both vector (GeoJSON) and raster (MBTiles) data.

/// Type of data layer
enum LayerType {
  vector,
  raster,
}

/// Format of the layer data file
enum LayerFormat {
  geojsonZip,
  mbtiles,
}

/// A single downloadable layer within a state
class LayerManifest {
  const LayerManifest({
    required this.id,
    required this.name,
    required this.description,
    required this.file,
    required this.size,
    required this.type,
    required this.format,
    required this.updatedAt,
    this.era,
    this.checksum,
  });

  /// Unique identifier for this layer (e.g., 'land', 'maps_survey')
  final String id;

  /// Human-readable name (e.g., 'Land Ownership', 'Survey Era Maps')
  final String name;

  /// Description of what this layer contains
  final String description;

  /// Filename on the server (e.g., 'land.zip', 'maps_survey.mbtiles')
  final String file;

  /// Size in bytes
  final int size;

  /// Type of layer (vector or raster)
  final LayerType type;

  /// Format of the data file
  final LayerFormat format;

  /// For historical map layers, the era covered (e.g., '1850-1890')
  final String? era;

  /// SHA256 checksum for integrity verification
  final String? checksum;

  /// When this layer was last updated
  final DateTime updatedAt;

  /// Whether this is a historical map overlay layer
  bool get isHistoricalMap => id.startsWith('maps_');

  /// Whether this is a vector data layer (land, trails, historical places)
  bool get isVectorData => type == LayerType.vector;

  /// Whether this is a raster tile layer (MBTiles)
  bool get isRasterTile => type == LayerType.raster;

  /// Size formatted as human-readable string
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(size / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  factory LayerManifest.fromJson(Map<String, dynamic> json) {
    return LayerManifest(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      file: json['file'] as String,
      size: json['size'] as int,
      type: _parseLayerType(json['type'] as String),
      format: _parseLayerFormat(json['format'] as String),
      era: json['era'] as String?,
      checksum: json['checksum'] as String?,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'file': file,
        'size': size,
        'type': type.name,
        'format': _formatToString(format),
        if (era != null) 'era': era,
        if (checksum != null) 'checksum': checksum,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static LayerType _parseLayerType(String value) {
    return LayerType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LayerType.vector,
    );
  }

  static LayerFormat _parseLayerFormat(String value) {
    switch (value) {
      case 'geojson-zip':
        return LayerFormat.geojsonZip;
      case 'mbtiles':
        return LayerFormat.mbtiles;
      default:
        return LayerFormat.geojsonZip;
    }
  }

  static String _formatToString(LayerFormat format) {
    switch (format) {
      case LayerFormat.geojsonZip:
        return 'geojson-zip';
      case LayerFormat.mbtiles:
        return 'mbtiles';
    }
  }
}

/// Manifest for a single state containing all available layers
class StateManifest {
  const StateManifest({
    required this.state,
    required this.version,
    required this.generatedAt,
    required this.layers,
  });

  /// Two-letter state code (e.g., 'WY', 'CO')
  final String state;

  /// Version identifier for this manifest
  final String version;

  /// When this manifest was generated
  final DateTime generatedAt;

  /// All available layers for this state
  final List<LayerManifest> layers;

  /// Get layers by type
  List<LayerManifest> getLayersByType(LayerType type) {
    return layers.where((l) => l.type == type).toList();
  }

  /// Get vector layers (land, trails, historical places)
  List<LayerManifest> get vectorLayers => getLayersByType(LayerType.vector);

  /// Get raster layers (historical maps)
  List<LayerManifest> get rasterLayers => getLayersByType(LayerType.raster);

  /// Get historical map layers
  List<LayerManifest> get historicalMapLayers {
    return layers.where((l) => l.isHistoricalMap).toList();
  }

  /// Get a specific layer by ID
  LayerManifest? getLayer(String id) {
    return layers.where((l) => l.id == id).firstOrNull;
  }

  /// Check if a specific layer is available
  bool hasLayer(String id) => getLayer(id) != null;

  /// Total size of all layers
  int get totalSize => layers.fold(0, (sum, l) => sum + l.size);

  /// Total size of vector layers
  int get vectorSize => vectorLayers.fold(0, (sum, l) => sum + l.size);

  /// Total size of raster layers
  int get rasterSize => rasterLayers.fold(0, (sum, l) => sum + l.size);

  /// Formatted total size
  String get formattedTotalSize {
    final size = totalSize;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(size / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  factory StateManifest.fromJson(Map<String, dynamic> json) {
    return StateManifest(
      state: json['state'] as String,
      version: json['version'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      layers: (json['layers'] as List<dynamic>)
          .map((l) => LayerManifest.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'state': state,
        'version': version,
        'generatedAt': generatedAt.toIso8601String(),
        'layers': layers.map((l) => l.toJson()).toList(),
      };
}

/// Response from the /manifests endpoint containing all state manifests
class AllManifestsResponse {
  const AllManifestsResponse({
    required this.version,
    required this.generatedAt,
    required this.states,
  });

  final String version;
  final DateTime generatedAt;
  final List<StateManifest> states;

  /// Get manifest for a specific state
  StateManifest? getStateManifest(String stateCode) {
    return states.where((s) => s.state == stateCode).firstOrNull;
  }

  factory AllManifestsResponse.fromJson(Map<String, dynamic> json) {
    return AllManifestsResponse(
      version: json['version'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      states: (json['states'] as List<dynamic>)
          .map((s) => StateManifest.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'generatedAt': generatedAt.toIso8601String(),
        'states': states.map((s) => s.toJson()).toList(),
      };
}

/// Tracks download status for a specific layer
class LayerDownloadStatus {
  const LayerDownloadStatus({
    required this.layerId,
    required this.stateCode,
    this.isDownloaded = false,
    this.localVersion,
    this.downloadedAt,
    this.localSize,
  });

  final String layerId;
  final String stateCode;
  final bool isDownloaded;
  final String? localVersion;
  final DateTime? downloadedAt;
  final int? localSize;

  /// Check if an update is available based on version
  bool needsUpdate(LayerManifest manifest) {
    if (!isDownloaded) return true;
    if (localVersion == null) return true;
    // Compare checksums if available
    if (manifest.checksum != null && manifest.checksum != localVersion) {
      return true;
    }
    return false;
  }

  LayerDownloadStatus copyWith({
    bool? isDownloaded,
    String? localVersion,
    DateTime? downloadedAt,
    int? localSize,
  }) {
    return LayerDownloadStatus(
      layerId: layerId,
      stateCode: stateCode,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localVersion: localVersion ?? this.localVersion,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      localSize: localSize ?? this.localSize,
    );
  }
}
