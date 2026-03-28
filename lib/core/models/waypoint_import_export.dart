import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Simple date range class for filtering
@immutable
class DateTimeRange {
  const DateTimeRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  bool contains(DateTime dateTime) =>
      dateTime.isAfter(start) && dateTime.isBefore(end);

  @override
  String toString() => 'DateTimeRange($start - $end)';
}

/// Simple bounds class for coordinate validation
@immutable
class LatLngBounds {
  const LatLngBounds({
    required this.southwest,
    required this.northeast,
  });

  final LatLng southwest;
  final LatLng northeast;

  bool contains(LatLng point) =>
      point.latitude >= southwest.latitude &&
      point.latitude <= northeast.latitude &&
      point.longitude >= southwest.longitude &&
      point.longitude <= northeast.longitude;

  @override
  String toString() => 'LatLngBounds($southwest - $northeast)';
}

/// Supported formats for waypoint import/export
enum WaypointExportFormat {
  gpx,
  kml,
  geoJson,
  csv,
  json,
}

/// Extension for waypoint export formats
extension WaypointExportFormatExtension on WaypointExportFormat {
  /// Display name for the format
  String get displayName {
    switch (this) {
      case WaypointExportFormat.gpx:
        return 'GPX';
      case WaypointExportFormat.kml:
        return 'KML';
      case WaypointExportFormat.geoJson:
        return 'GeoJSON';
      case WaypointExportFormat.csv:
        return 'CSV';
      case WaypointExportFormat.json:
        return 'JSON';
    }
  }

  /// File extension for the format
  String get fileExtension {
    switch (this) {
      case WaypointExportFormat.gpx:
        return 'gpx';
      case WaypointExportFormat.kml:
        return 'kml';
      case WaypointExportFormat.geoJson:
        return 'geojson';
      case WaypointExportFormat.csv:
        return 'csv';
      case WaypointExportFormat.json:
        return 'json';
    }
  }

  /// MIME type for the format
  String get mimeType {
    switch (this) {
      case WaypointExportFormat.gpx:
        return 'application/gpx+xml';
      case WaypointExportFormat.kml:
        return 'application/vnd.google-earth.kml+xml';
      case WaypointExportFormat.geoJson:
        return 'application/geo+json';
      case WaypointExportFormat.csv:
        return 'text/csv';
      case WaypointExportFormat.json:
        return 'application/json';
    }
  }

  /// Whether this format supports custom fields
  bool get supportsCustomFields {
    switch (this) {
      case WaypointExportFormat.gpx:
      case WaypointExportFormat.kml:
      case WaypointExportFormat.geoJson:
      case WaypointExportFormat.json:
        return true;
      case WaypointExportFormat.csv:
        return false;
    }
  }

  /// Whether this format supports relationships
  bool get supportsRelationships {
    switch (this) {
      case WaypointExportFormat.geoJson:
      case WaypointExportFormat.json:
        return true;
      default:
        return false;
    }
  }
}

/// Configuration for waypoint export operations
@immutable
class WaypointExportConfig {
  const WaypointExportConfig({
    required this.format,
    this.includeMetadata = true,
    this.includeCustomFields = true,
    this.includeRelationships = false,
    this.includeHistory = false,
    this.includePhotos = false,
    this.compressOutput = false,
    this.filterByDateRange,
    this.filterByTypes,
    this.filterByCategories,
    this.filterByTags,
    this.customFieldsToInclude,
    this.coordinatePrecision = 6,
    this.includePrivateData = false,
  });

  /// Export format to use
  final WaypointExportFormat format;

  /// Whether to include metadata
  final bool includeMetadata;

  /// Whether to include custom fields
  final bool includeCustomFields;

  /// Whether to include relationships
  final bool includeRelationships;

  /// Whether to include version history
  final bool includeHistory;

  /// Whether to include photo references
  final bool includePhotos;

  /// Whether to compress the output
  final bool compressOutput;

  /// Optional date range filter
  final DateTimeRange? filterByDateRange;

  /// Optional waypoint types filter
  final List<String>? filterByTypes;

  /// Optional categories filter
  final List<String>? filterByCategories;

  /// Optional tags filter
  final List<String>? filterByTags;

  /// Specific custom fields to include (null = all)
  final List<String>? customFieldsToInclude;

  /// Precision for coordinate values
  final int coordinatePrecision;

  /// Whether to include private/sensitive data
  final bool includePrivateData;

  /// Create a copy with updated values
  WaypointExportConfig copyWith({
    WaypointExportFormat? format,
    bool? includeMetadata,
    bool? includeCustomFields,
    bool? includeRelationships,
    bool? includeHistory,
    bool? includePhotos,
    bool? compressOutput,
    DateTimeRange? filterByDateRange,
    List<String>? filterByTypes,
    List<String>? filterByCategories,
    List<String>? filterByTags,
    List<String>? customFieldsToInclude,
    int? coordinatePrecision,
    bool? includePrivateData,
  }) =>
      WaypointExportConfig(
        format: format ?? this.format,
        includeMetadata: includeMetadata ?? this.includeMetadata,
        includeCustomFields: includeCustomFields ?? this.includeCustomFields,
        includeRelationships: includeRelationships ?? this.includeRelationships,
        includeHistory: includeHistory ?? this.includeHistory,
        includePhotos: includePhotos ?? this.includePhotos,
        compressOutput: compressOutput ?? this.compressOutput,
        filterByDateRange: filterByDateRange ?? this.filterByDateRange,
        filterByTypes: filterByTypes ?? this.filterByTypes,
        filterByCategories: filterByCategories ?? this.filterByCategories,
        filterByTags: filterByTags ?? this.filterByTags,
        customFieldsToInclude:
            customFieldsToInclude ?? this.customFieldsToInclude,
        coordinatePrecision: coordinatePrecision ?? this.coordinatePrecision,
        includePrivateData: includePrivateData ?? this.includePrivateData,
      );

  @override
  String toString() =>
      'WaypointExportConfig{format: $format, includeMetadata: $includeMetadata}';
}

/// Configuration for waypoint import operations
@immutable
class WaypointImportConfig {
  const WaypointImportConfig({
    this.createMissingCategories = true,
    this.createMissingTypes = true,
    this.preserveOriginalIds = false,
    this.mergeWithExisting = false,
    this.skipDuplicates = true,
    this.duplicateThresholdMeters = 10.0,
    this.defaultSessionId,
    this.importToGroup,
    this.addImportTag = true,
    this.validateCoordinates = true,
    this.coordinateValidationBounds,
    this.maxImportCount,
    this.batchSize = 100,
  });

  /// Whether to create missing categories during import
  final bool createMissingCategories;

  /// Whether to create missing waypoint types during import
  final bool createMissingTypes;

  /// Whether to preserve original waypoint IDs
  final bool preserveOriginalIds;

  /// Whether to merge with existing waypoints
  final bool mergeWithExisting;

  /// Whether to skip duplicate waypoints
  final bool skipDuplicates;

  /// Distance threshold for considering waypoints duplicates (meters)
  final double duplicateThresholdMeters;

  /// Default session ID for imported waypoints
  final String? defaultSessionId;

  /// Optional group to add imported waypoints to
  final String? importToGroup;

  /// Whether to add an "imported" tag to waypoints
  final bool addImportTag;

  /// Whether to validate coordinate values
  final bool validateCoordinates;

  /// Optional bounds for coordinate validation
  final LatLngBounds? coordinateValidationBounds;

  /// Maximum number of waypoints to import
  final int? maxImportCount;

  /// Batch size for processing imports
  final int batchSize;

  /// Create a copy with updated values
  WaypointImportConfig copyWith({
    bool? createMissingCategories,
    bool? createMissingTypes,
    bool? preserveOriginalIds,
    bool? mergeWithExisting,
    bool? skipDuplicates,
    double? duplicateThresholdMeters,
    String? defaultSessionId,
    String? importToGroup,
    bool? addImportTag,
    bool? validateCoordinates,
    LatLngBounds? coordinateValidationBounds,
    int? maxImportCount,
    int? batchSize,
  }) =>
      WaypointImportConfig(
        createMissingCategories:
            createMissingCategories ?? this.createMissingCategories,
        createMissingTypes: createMissingTypes ?? this.createMissingTypes,
        preserveOriginalIds: preserveOriginalIds ?? this.preserveOriginalIds,
        mergeWithExisting: mergeWithExisting ?? this.mergeWithExisting,
        skipDuplicates: skipDuplicates ?? this.skipDuplicates,
        duplicateThresholdMeters:
            duplicateThresholdMeters ?? this.duplicateThresholdMeters,
        defaultSessionId: defaultSessionId ?? this.defaultSessionId,
        importToGroup: importToGroup ?? this.importToGroup,
        addImportTag: addImportTag ?? this.addImportTag,
        validateCoordinates: validateCoordinates ?? this.validateCoordinates,
        coordinateValidationBounds:
            coordinateValidationBounds ?? this.coordinateValidationBounds,
        maxImportCount: maxImportCount ?? this.maxImportCount,
        batchSize: batchSize ?? this.batchSize,
      );

  @override
  String toString() =>
      'WaypointImportConfig{skipDuplicates: $skipDuplicates, batchSize: $batchSize}';
}

/// Result of a waypoint import operation
@immutable
class WaypointImportResult {
  const WaypointImportResult({
    required this.totalProcessed,
    required this.successfulImports,
    required this.skippedDuplicates,
    required this.errors,
    required this.importedWaypointIds,
    required this.duration,
    this.warnings = const <String>[],
    this.createdCategories = const <String>[],
    this.createdTypes = const <String>[],
  });

  /// Total number of waypoints processed
  final int totalProcessed;

  /// Number of waypoints successfully imported
  final int successfulImports;

  /// Number of waypoints skipped as duplicates
  final int skippedDuplicates;

  /// Number of errors encountered
  final int errors;

  /// List of imported waypoint IDs
  final List<String> importedWaypointIds;

  /// Duration of the import operation
  final Duration duration;

  /// List of warning messages
  final List<String> warnings;

  /// Categories created during import
  final List<String> createdCategories;

  /// Types created during import
  final List<String> createdTypes;

  /// Whether the import was successful
  bool get isSuccessful => errors == 0 && successfulImports > 0;

  /// Whether there were any issues
  bool get hasIssues => errors > 0 || warnings.isNotEmpty;

  /// Success rate as a percentage
  double get successRate {
    if (totalProcessed == 0) return 0.0;
    return (successfulImports / totalProcessed) * 100.0;
  }

  @override
  String toString() =>
      'WaypointImportResult{processed: $totalProcessed, imported: $successfulImports, errors: $errors}';
}

/// Result of a waypoint export operation
@immutable
class WaypointExportResult {
  const WaypointExportResult({
    required this.totalWaypoints,
    required this.exportedWaypoints,
    required this.format,
    required this.filePath,
    required this.fileSize,
    required this.duration,
    this.errors = const <String>[],
    this.warnings = const <String>[],
  });

  /// Total number of waypoints to export
  final int totalWaypoints;

  /// Number of waypoints successfully exported
  final int exportedWaypoints;

  /// Export format used
  final WaypointExportFormat format;

  /// Path to the exported file
  final String filePath;

  /// Size of the exported file in bytes
  final int fileSize;

  /// Duration of the export operation
  final Duration duration;

  /// List of error messages
  final List<String> errors;

  /// List of warning messages
  final List<String> warnings;

  /// Whether the export was successful
  bool get isSuccessful => errors.isEmpty && exportedWaypoints > 0;

  /// Whether there were any issues
  bool get hasIssues => errors.isNotEmpty || warnings.isNotEmpty;

  /// Success rate as a percentage
  double get successRate {
    if (totalWaypoints == 0) return 0.0;
    return (exportedWaypoints / totalWaypoints) * 100.0;
  }

  /// Human-readable file size
  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  @override
  String toString() =>
      'WaypointExportResult{exported: $exportedWaypoints/$totalWaypoints, format: $format, size: $fileSizeFormatted}';
}

/// Batch operation for importing/exporting multiple waypoint files
@immutable
class WaypointBatchOperation {
  const WaypointBatchOperation({
    required this.id,
    required this.operationType,
    required this.filePaths,
    required this.config,
    required this.createdAt,
    required this.userId,
    this.status = WaypointBatchStatus.pending,
    this.progress = 0.0,
    this.currentFile,
    this.results = const <WaypointImportResult>[],
    this.errors = const <String>[],
    this.completedAt,
  });

  /// Unique identifier for this batch operation
  final String id;

  /// Type of batch operation
  final WaypointBatchOperationType operationType;

  /// List of file paths to process
  final List<String> filePaths;

  /// Configuration for the operation
  final dynamic config; // WaypointImportConfig or WaypointExportConfig

  /// When this operation was created
  final DateTime createdAt;

  /// ID of the user who initiated this operation
  final String userId;

  /// Current status of the operation
  final WaypointBatchStatus status;

  /// Progress percentage (0.0 to 1.0)
  final double progress;

  /// Currently processing file
  final String? currentFile;

  /// Results from completed files
  final List<WaypointImportResult> results;

  /// List of error messages
  final List<String> errors;

  /// When the operation completed
  final DateTime? completedAt;

  /// Total number of files to process
  int get totalFiles => filePaths.length;

  /// Number of completed files
  int get completedFiles => results.length;

  /// Whether the operation is complete
  bool get isComplete =>
      status == WaypointBatchStatus.completed ||
      status == WaypointBatchStatus.failed;

  /// Whether the operation was successful
  bool get isSuccessful =>
      status == WaypointBatchStatus.completed && errors.isEmpty;

  /// Create a copy with updated values
  WaypointBatchOperation copyWith({
    String? id,
    WaypointBatchOperationType? operationType,
    List<String>? filePaths,
    Object? config,
    DateTime? createdAt,
    String? userId,
    WaypointBatchStatus? status,
    double? progress,
    String? currentFile,
    List<WaypointImportResult>? results,
    List<String>? errors,
    DateTime? completedAt,
  }) =>
      WaypointBatchOperation(
        id: id ?? this.id,
        operationType: operationType ?? this.operationType,
        filePaths: filePaths ?? this.filePaths,
        config: config ?? this.config,
        createdAt: createdAt ?? this.createdAt,
        userId: userId ?? this.userId,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        currentFile: currentFile ?? this.currentFile,
        results: results ?? this.results,
        errors: errors ?? this.errors,
        completedAt: completedAt ?? this.completedAt,
      );

  @override
  String toString() =>
      'WaypointBatchOperation{id: $id, type: $operationType, status: $status, progress: ${(progress * 100).toStringAsFixed(1)}%}';
}

/// Types of batch operations
enum WaypointBatchOperationType {
  import,
  export,
}

/// Status of batch operations
enum WaypointBatchStatus {
  pending,
  running,
  paused,
  completed,
  failed,
  cancelled,
}

/// Extension for batch status
extension WaypointBatchStatusExtension on WaypointBatchStatus {
  /// Display name for the status
  String get displayName {
    switch (this) {
      case WaypointBatchStatus.pending:
        return 'Pending';
      case WaypointBatchStatus.running:
        return 'Running';
      case WaypointBatchStatus.paused:
        return 'Paused';
      case WaypointBatchStatus.completed:
        return 'Completed';
      case WaypointBatchStatus.failed:
        return 'Failed';
      case WaypointBatchStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Whether the operation can be resumed
  bool get canResume => this == WaypointBatchStatus.paused;

  /// Whether the operation can be cancelled
  bool get canCancel =>
      this == WaypointBatchStatus.pending ||
      this == WaypointBatchStatus.running ||
      this == WaypointBatchStatus.paused;
}
