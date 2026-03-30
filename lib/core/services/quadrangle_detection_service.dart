import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/quadrangle_manifest.dart';
import 'package:obsession_tracker/core/services/quadrangle_download_service.dart';

/// Service for detecting available quadrangles based on map viewport.
///
/// Used by the map page to show contextual suggestions when users
/// are viewing areas where historical map quadrangles are available
/// but not yet downloaded.
class QuadrangleDetectionService {
  QuadrangleDetectionService._();
  static final QuadrangleDetectionService instance = QuadrangleDetectionService._();

  final QuadrangleDownloadService _downloadService = QuadrangleDownloadService.instance;

  // Cooldown tracking: quadKey -> last suggestion time
  final Map<String, DateTime> _lastSuggestionTime = {};

  // Session dismissals: quadKeys dismissed this session
  final Set<String> _dismissedForSession = {};

  // Cooldown duration before re-suggesting the same quad
  // Premium users get shorter cooldown since they can act on suggestions
  static const Duration premiumCooldown = Duration(seconds: 30);
  static const Duration freeCooldown = Duration(minutes: 5);

  // Maximum suggestions to return per detection call
  static const int maxSuggestions = 3;

  // Minimum coverage percentage for a quad to be considered relevant
  static const double minCoverageThreshold = 0.1; // 10%

  /// Find available (not downloaded) quadrangles that intersect with the given viewport.
  ///
  /// Returns quadrangles sorted by coverage (highest first), up to [maxSuggestions].
  /// Excludes already downloaded quads and respects cooldown/dismissal rules.
  ///
  /// Set [isPremium] to true for premium users (shorter cooldown).
  /// Set [ignoreCooldown] to true to bypass cooldown/dismissal (for filter panel).
  Future<List<QuadrangleSuggestion>> findSuggestionsForViewport({
    required String stateCode,
    required double west,
    required double south,
    required double east,
    required double north,
    bool isPremium = false,
    bool ignoreCooldown = false,
  }) async {
    // Get the manifest for this state
    final manifest = await _downloadService.getQuadrangleManifest(stateCode);
    if (manifest == null) {
      return [];
    }

    final viewportBounds = QuadrangleBounds(
      west: west,
      south: south,
      east: east,
      north: north,
    );

    final suggestions = <QuadrangleSuggestion>[];

    // Check each era and quad (logging only for matches to reduce spam)
    for (final era in manifest.eras) {
      for (final quad in era.quadrangles) {
        // Skip if already downloaded
        final isDownloaded = _downloadService.isQuadrangleDownloaded(stateCode, era.id, quad.id);
        if (isDownloaded) {
          continue;
        }

        // Check intersection
        final intersects = quad.bounds.intersects(viewportBounds);
        if (!intersects) {
          continue;
        }

        // Calculate coverage
        final coverage = quad.bounds.calculateCoverage(viewportBounds);
        if (coverage < minCoverageThreshold) {
          continue;
        }

        // Check cooldown and dismissal (skip for filter panel use)
        final quadKey = _makeQuadKey(stateCode, era.id, quad.id);
        if (!ignoreCooldown && !shouldShowSuggestion(quadKey, isPremium: isPremium)) {
          continue;
        }

        debugPrint('📍 Detection: Found ${quad.id} with ${(coverage * 100).toStringAsFixed(1)}% coverage');
        suggestions.add(QuadrangleSuggestion(
          stateCode: stateCode,
          era: era,
          quad: quad,
          coverage: coverage,
        ));
      }
    }

    // Sort by coverage (highest first) and limit
    suggestions.sort((a, b) => b.coverage.compareTo(a.coverage));

    return suggestions.take(maxSuggestions).toList();
  }

  /// Find the best single suggestion for a viewport.
  ///
  /// Returns the suggestion with the highest coverage, or null if none found.
  Future<QuadrangleSuggestion?> findBestSuggestionForViewport({
    required String stateCode,
    required double west,
    required double south,
    required double east,
    required double north,
    bool isPremium = false,
  }) async {
    final suggestions = await findSuggestionsForViewport(
      stateCode: stateCode,
      west: west,
      south: south,
      east: east,
      north: north,
      isPremium: isPremium,
    );

    return suggestions.isNotEmpty ? suggestions.first : null;
  }

  /// Check if a suggestion should be shown for the given quad.
  ///
  /// Returns false if:
  /// - The quad was dismissed this session
  /// - The quad was suggested within the cooldown period
  ///
  /// Premium users get a shorter cooldown (30s) since they can act on suggestions.
  /// Free users get a longer cooldown (5min) to reduce banner spam.
  bool shouldShowSuggestion(String quadKey, {bool isPremium = false}) {
    // Check session dismissal
    if (_dismissedForSession.contains(quadKey)) {
      return false;
    }

    // Check cooldown (premium users get shorter cooldown)
    final cooldown = isPremium ? premiumCooldown : freeCooldown;
    final lastShown = _lastSuggestionTime[quadKey];
    if (lastShown != null) {
      final elapsed = DateTime.now().difference(lastShown);
      if (elapsed < cooldown) {
        return false;
      }
    }

    return true;
  }

  /// Mark a suggestion as shown (starts cooldown timer).
  void markSuggestionShown(String stateCode, String eraId, String quadId) {
    final quadKey = _makeQuadKey(stateCode, eraId, quadId);
    _lastSuggestionTime[quadKey] = DateTime.now();
    debugPrint('📍 Suggestion shown for $quadKey, cooldown started');
  }

  /// Dismiss a suggestion for this session (won't be shown again until app restart).
  void dismissSuggestionForSession(String stateCode, String eraId, String quadId) {
    final quadKey = _makeQuadKey(stateCode, eraId, quadId);
    _dismissedForSession.add(quadKey);
    debugPrint('📍 Suggestion dismissed for session: $quadKey');
  }

  /// Clear all session dismissals (call on app restart or when appropriate).
  void clearSessionDismissals() {
    _dismissedForSession.clear();
    debugPrint('📍 Session dismissals cleared');
  }

  /// Clear all cooldown timers.
  void clearCooldowns() {
    _lastSuggestionTime.clear();
    debugPrint('📍 Suggestion cooldowns cleared');
  }

  /// Clear all state (dismissals and cooldowns).
  void reset() {
    _dismissedForSession.clear();
    _lastSuggestionTime.clear();
    debugPrint('📍 QuadrangleDetectionService reset');
  }

  String _makeQuadKey(String stateCode, String eraId, String quadId) {
    return '${stateCode}_${eraId}_$quadId';
  }
}

/// A suggested quadrangle for download.
class QuadrangleSuggestion {
  const QuadrangleSuggestion({
    required this.stateCode,
    required this.era,
    required this.quad,
    required this.coverage,
  });

  /// State code (e.g., 'WY')
  final String stateCode;

  /// The era this quad belongs to
  final HistoricalEra era;

  /// The quadrangle manifest
  final QuadrangleManifest quad;

  /// How much of the viewport this quad covers (0.0 to 1.0)
  final double coverage;

  /// Unique key for this suggestion
  String get key => '${stateCode}_${era.id}_${quad.id}';

  /// Human-readable title for display
  String get title => '${quad.year} ${era.name}';

  /// Subtitle with quad name
  String get subtitle => quad.name;

  /// Coverage as a percentage string
  String get coveragePercent => '${(coverage * 100).toStringAsFixed(0)}%';

  @override
  String toString() => 'QuadrangleSuggestion($key: $coveragePercent coverage)';
}
