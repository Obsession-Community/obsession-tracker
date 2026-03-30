import 'package:obsession_tracker/core/providers/historical_maps_provider.dart';
import 'package:obsession_tracker/core/services/quadrangle_detection_service.dart';

/// Represents a map entry on the time slider timeline
class TimelineMapEntry {
  const TimelineMapEntry({
    required this.id,
    required this.name,
    required this.year,
    required this.state,
    this.isDownloaded = false,
    this.isEnabled = false,
    this.size,
    this.eraId,
    this.historicalMapState,
    this.quadrangleSuggestion,
  });

  /// Unique identifier (state_layerId for downloaded, quad_id for available)
  final String id;

  /// Display name of the map
  final String name;

  /// Year the map was published
  final int year;

  /// State of the entry on the timeline
  final TimelineMapState state;

  /// Whether the map is downloaded
  final bool isDownloaded;

  /// Whether the map is currently enabled/visible
  final bool isEnabled;

  /// File size in bytes (for available maps)
  final int? size;

  /// Era identifier (survey, early_topo, midcentury)
  final String? eraId;

  /// Reference to downloaded map state (if downloaded)
  final HistoricalMapState? historicalMapState;

  /// Reference to available map suggestion (if not downloaded)
  final QuadrangleSuggestion? quadrangleSuggestion;

  /// Get formatted size string
  String get formattedSize {
    if (size == null) return '';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} KB';
    return '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get the era name for display
  String get eraName {
    switch (eraId) {
      case 'survey':
        return 'Survey Era';
      case 'early_topo':
        return 'Early Topo';
      case 'midcentury':
        return 'Mid-Century';
      default:
        return 'Historical';
    }
  }

  /// Get the era year range for display
  String get eraYearRange {
    switch (eraId) {
      case 'survey':
        return '1850-1890';
      case 'early_topo':
        return '1890-1920';
      case 'midcentury':
        return '1940-1960';
      default:
        return '';
    }
  }

  /// Create from a downloaded HistoricalMapState
  factory TimelineMapEntry.fromHistoricalMapState(HistoricalMapState mapState) {
    // Extract year from layer name (e.g., "Laramie (1897)" -> 1897)
    final yearMatch = RegExp(r'\((\d{4})\)').firstMatch(mapState.layerName);
    final year = yearMatch != null ? int.parse(yearMatch.group(1)!) : 1900;

    return TimelineMapEntry(
      id: mapState.key,
      name: mapState.layerName.replaceAll(RegExp(r'\s*\(\d{4}\)'), ''),
      year: year,
      state: mapState.isEnabled
          ? TimelineMapState.enabledAndVisible
          : TimelineMapState.downloaded,
      isDownloaded: true,
      isEnabled: mapState.isEnabled,
      eraId: mapState.era,
      historicalMapState: mapState,
    );
  }

  /// Create from an available QuadrangleSuggestion
  factory TimelineMapEntry.fromQuadrangleSuggestion(QuadrangleSuggestion suggestion) {
    return TimelineMapEntry(
      id: suggestion.quad.id,
      name: suggestion.quad.name,
      year: suggestion.quad.year,
      state: TimelineMapState.available,
      size: suggestion.quad.size,
      eraId: suggestion.era.id,
      quadrangleSuggestion: suggestion,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineMapEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// State of a map entry on the timeline
enum TimelineMapState {
  /// Map is downloaded and currently visible on the map
  enabledAndVisible,

  /// Map is downloaded but not currently visible
  downloaded,

  /// Map is available for download
  available,
}
