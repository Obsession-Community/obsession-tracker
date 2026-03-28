import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/cell_tower.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/core/services/app_settings_service.dart';
import 'package:obsession_tracker/core/services/offline_land_rights_service.dart';

/// Maximum tower range to consider (largest towers are ~25km in rural areas)
/// This buffer is added to viewport to catch towers that reach INTO the view
const double _maxTowerRangeMeters = 25000; // 25km

/// Convert meters to approximate degrees latitude (1 degree ≈ 111km)
double _metersToDegreesLat(double meters) => meters / 111000;

/// Convert meters to approximate degrees longitude at a given latitude
double _metersToDegreesLon(double meters, double latitude) {
  final double latRadians = latitude * (math.pi / 180);
  final double metersPerDegree = 111000 * math.cos(latRadians);
  return meters / metersPerDegree;
}

/// Check if a tower should be displayed in the viewport
/// Shows tower if:
/// 1. Tower center is within the viewport bounds (always show marker)
/// 2. OR tower is outside but its coverage circle reaches into the viewport
bool _shouldShowTower(CellTower tower, double north, double south, double east, double west) {
  // Check if tower center is within viewport (always show these)
  final bool centerInViewport =
      tower.latitude >= south &&
      tower.latitude <= north &&
      tower.longitude >= west &&
      tower.longitude <= east;

  if (centerInViewport) {
    return true;
  }

  // Tower is outside viewport - check if its coverage reaches in
  final double closestLat = tower.latitude.clamp(south, north);
  final double closestLon = tower.longitude.clamp(west, east);

  final double distance = _calculateDistanceMeters(
    tower.latitude,
    tower.longitude,
    closestLat,
    closestLon,
  );

  return distance <= tower.effectiveRangeMeters;
}

/// Calculate distance in meters between two points using Haversine formula
double _calculateDistanceMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const double earthRadius = 6371000; // meters
  final double dLat = (lat2 - lat1) * (math.pi / 180);
  final double dLon = (lon2 - lon1) * (math.pi / 180);

  final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * (math.pi / 180)) *
          math.cos(lat2 * (math.pi / 180)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

/// Provider for cell coverage overlay visibility
final cellCoverageVisibilityProvider =
    NotifierProvider<CellCoverageVisibilityNotifier, bool>(
        CellCoverageVisibilityNotifier.new);

/// Provider for cell coverage filter configuration
final cellCoverageFilterProvider =
    NotifierProvider<CellCoverageFilterNotifier, CellCoverageFilter>(
        CellCoverageFilterNotifier.new);

/// Provider for cell tower data in current view
///
/// Returns cell towers from SQLite cache based on map bounds.
/// Sorts by distance to user and limits to nearest towers.
/// Requires premium subscription and downloaded state data.
final cellCoverageDataProvider =
    FutureProvider.family<List<CellTower>, LandBounds>((ref, bounds) async {
  try {
    // Check subscription status
    final isPremium = ref.watch(isPremiumProvider);
    if (!isPremium) {
      debugPrint('[Cell Coverage] Blocked - premium subscription required');
      return [];
    }

    // Check visibility
    final isVisible = ref.watch(cellCoverageVisibilityProvider);
    if (!isVisible) {
      debugPrint('[Cell Coverage] Overlay is not visible, skipping query');
      return [];
    }

    // Get filter configuration
    final filter = ref.watch(cellCoverageFilterProvider);
    if (filter.noTypesEnabled) {
      debugPrint('[Cell Coverage] No radio types enabled, skipping query');
      return [];
    }

    // Get user's current position for distance-based sorting
    final Position? userPosition = ref.watch(currentPositionProvider);

    debugPrint('[Cell Coverage] ========== QUERY DEBUG ==========');
    debugPrint('[Cell Coverage] Viewport: N=${bounds.north.toStringAsFixed(4)}, S=${bounds.south.toStringAsFixed(4)}, E=${bounds.east.toStringAsFixed(4)}, W=${bounds.west.toStringAsFixed(4)}');

    if (userPosition != null) {
      debugPrint('[Cell Coverage] User GPS: lat=${userPosition.latitude.toStringAsFixed(5)}, lon=${userPosition.longitude.toStringAsFixed(5)}');
    }

    // Expand viewport bounds by max tower range to catch towers that reach INTO the viewport
    final double latBuffer = _metersToDegreesLat(_maxTowerRangeMeters);
    final double lonBuffer = _metersToDegreesLon(_maxTowerRangeMeters, bounds.north);

    final double queryNorth = bounds.north + latBuffer;
    final double querySouth = bounds.south - latBuffer;
    final double queryEast = bounds.east + lonBuffer;
    final double queryWest = bounds.west - lonBuffer;

    debugPrint('[Cell Coverage] Query bounds (+${(_maxTowerRangeMeters / 1000).toInt()}km buffer): N=${queryNorth.toStringAsFixed(4)}, S=${querySouth.toStringAsFixed(4)}');

    // Query from SQLite cache
    final offlineService = OfflineLandRightsService();
    final allTowers = await offlineService.queryCellTowersForBounds(
      north: queryNorth,
      south: querySouth,
      east: queryEast,
      west: queryWest,
      radioTypeFilter: filter.enabledTypes,
    );

    debugPrint('[Cell Coverage] Query returned ${allTowers.length} towers in query bounds');

    if (allTowers.isEmpty) {
      debugPrint('[Cell Coverage] No towers found');
      return [];
    }

    // Analyze range statistics to understand data quality
    final rawRanges = allTowers.map((t) => t.rangeMeters).toList()..sort();
    final effectiveRanges = allTowers.map((t) => t.effectiveRangeMeters).toList()..sort();
    debugPrint('[Cell Coverage] Range stats (reported): min=${rawRanges.first}m, max=${rawRanges.last}m, median=${rawRanges[rawRanges.length ~/ 2]}m');
    debugPrint('[Cell Coverage] Range stats (effective): min=${effectiveRanges.first}m, max=${effectiveRanges.last}m, median=${effectiveRanges[effectiveRanges.length ~/ 2]}m');

    // Filter to towers that should be visible (center in viewport OR coverage reaches in)
    final List<CellTower> visibleTowers = [];
    int towersInViewport = 0;
    int towersReachingIn = 0;
    int towersOutsideNoReach = 0;

    for (final tower in allTowers) {
      final bool centerInViewport =
          tower.latitude >= bounds.south &&
          tower.latitude <= bounds.north &&
          tower.longitude >= bounds.west &&
          tower.longitude <= bounds.east;

      if (centerInViewport) {
        visibleTowers.add(tower);
        towersInViewport++;
      } else if (_shouldShowTower(tower, bounds.north, bounds.south, bounds.east, bounds.west)) {
        visibleTowers.add(tower);
        towersReachingIn++;
      } else {
        towersOutsideNoReach++;
      }
    }

    debugPrint('[Cell Coverage] Visible towers: ${visibleTowers.length} ($towersInViewport in viewport, $towersReachingIn reaching in, $towersOutsideNoReach filtered out)');

    // If many towers filtered out, show why (helps diagnose data issues)
    if (towersOutsideNoReach > 10 && towersInViewport < 5) {
      // Find sample of filtered towers to understand where they are
      final filteredTowers = allTowers.where((t) =>
          !(t.latitude >= bounds.south &&
            t.latitude <= bounds.north &&
            t.longitude >= bounds.west &&
            t.longitude <= bounds.east) &&
          !_shouldShowTower(t, bounds.north, bounds.south, bounds.east, bounds.west)
      ).take(5).toList();

      debugPrint('[Cell Coverage] Sample of $towersOutsideNoReach filtered towers (outside viewport, range too small to reach):');
      for (final tower in filteredTowers) {
        // Calculate distance to nearest viewport edge
        final closestLat = tower.latitude.clamp(bounds.south, bounds.north);
        final closestLon = tower.longitude.clamp(bounds.west, bounds.east);
        final distToViewport = _calculateDistanceMeters(
          tower.latitude, tower.longitude, closestLat, closestLon,
        );
        debugPrint('[Cell Coverage]   ${tower.carrier ?? 'Unknown'} ${tower.radioType.displayName} @ (${tower.latitude.toStringAsFixed(4)}, ${tower.longitude.toStringAsFixed(4)}) - range: ${tower.effectiveRangeMeters}m (reported: ${tower.rangeMeters}m), dist to viewport: ${(distToViewport / 1000).toStringAsFixed(1)}km');
      }
    }

    // Determine analysis point: user GPS if in viewport, otherwise map center (crosshair)
    final double viewportCenterLat = (bounds.north + bounds.south) / 2;
    final double viewportCenterLon = (bounds.east + bounds.west) / 2;

    // Check if user GPS is within the viewport
    double analysisLat = viewportCenterLat;
    double analysisLon = viewportCenterLon;
    String analysisLabel = 'map center (crosshair)';

    if (userPosition != null &&
        userPosition.latitude >= bounds.south &&
        userPosition.latitude <= bounds.north &&
        userPosition.longitude >= bounds.west &&
        userPosition.longitude <= bounds.east) {
      // User GPS is in viewport - analyze at their location
      analysisLat = userPosition.latitude;
      analysisLon = userPosition.longitude;
      analysisLabel = 'your GPS location';
    }

    // Analyze which towers cover the analysis point
    final coveringPoint = <CellTower>[];
    final nearestNotCovering = <MapEntry<CellTower, double>>[];

    for (final tower in visibleTowers) {
      final distance = _calculateDistanceMeters(
        analysisLat,
        analysisLon,
        tower.latitude,
        tower.longitude,
      );

      if (distance <= tower.effectiveRangeMeters) {
        coveringPoint.add(tower);
      } else {
        nearestNotCovering.add(MapEntry(tower, distance));
      }
    }

    nearestNotCovering.sort((a, b) => a.value.compareTo(b.value));

    debugPrint('[Cell Coverage] === COVERAGE ANALYSIS at $analysisLabel ===');
    debugPrint('[Cell Coverage] Analysis point: ${analysisLat.toStringAsFixed(5)}, ${analysisLon.toStringAsFixed(5)}');
    if (coveringPoint.isNotEmpty) {
      debugPrint('[Cell Coverage] ✓ ${coveringPoint.length} towers provide coverage:');
      for (int i = 0; i < math.min(5, coveringPoint.length); i++) {
        final tower = coveringPoint[i];
        final distance = _calculateDistanceMeters(
          analysisLat, analysisLon,
          tower.latitude, tower.longitude,
        );
        final distKm = (distance / 1000).toStringAsFixed(2);
        final rangeKm = (tower.effectiveRangeMeters / 1000).toStringAsFixed(2);
        debugPrint('[Cell Coverage]   ${tower.carrier ?? 'Unknown'} ${tower.radioType.displayName} @ ${distKm}km (range: ${rangeKm}km)');
      }
    } else {
      debugPrint('[Cell Coverage] ⚠️ NO COVERAGE at $analysisLabel');
      if (nearestNotCovering.isNotEmpty) {
        final nearest = nearestNotCovering.first;
        final gap = (nearest.value - nearest.key.effectiveRangeMeters) / 1000;
        debugPrint('[Cell Coverage] Nearest: ${nearest.key.carrier ?? 'Unknown'} @ ${(nearest.value / 1000).toStringAsFixed(2)}km (${gap.toStringAsFixed(2)}km outside range)');
      }
    }

    // Count by radio type
    final typeCounts = <String, int>{};
    for (final tower in visibleTowers) {
      typeCounts[tower.radioType.code] = (typeCounts[tower.radioType.code] ?? 0) + 1;
    }
    debugPrint('[Cell Coverage] Displaying ${visibleTowers.length} towers: ${typeCounts.entries.map((e) => '${e.key}: ${e.value}').join(', ')}');
    debugPrint('[Cell Coverage] ================================');

    return visibleTowers;
  } catch (e, st) {
    debugPrint('[Cell Coverage] ERROR fetching data: $e');
    debugPrint('[Cell Coverage] Stack trace: $st');
    return [];
  }
});

/// Provider for total cell tower count across all states
final cellCoverageTotalCountProvider = FutureProvider<int>((ref) async {
  try {
    final offlineService = OfflineLandRightsService();
    return offlineService.getTotalCellTowerCount();
  } catch (e) {
    return 0;
  }
});

/// Provider for states with downloaded cell coverage data
final statesWithCellCoverageProvider = FutureProvider<List<String>>((ref) async {
  try {
    final offlineService = OfflineLandRightsService();
    return offlineService.getStatesWithCellTowers();
  } catch (e) {
    return [];
  }
});

/// Notifier for cell coverage overlay visibility with persistence via AppSettingsService
class CellCoverageVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Read from AppSettingsService which is already loaded at app startup
    final settings = AppSettingsService.instance.currentSettings;
    debugPrint('[Cell Coverage] Initial visibility from settings: ${settings.map.showCellCoverage}');
    return settings.map.showCellCoverage;
  }

  Future<void> _persistState() async {
    try {
      final settings = AppSettingsService.instance.currentSettings;
      await AppSettingsService.instance.updateMapSettings(
        settings.map.copyWith(showCellCoverage: state),
      );
    } catch (e) {
      debugPrint('[Cell Coverage] Error persisting state: $e');
    }
  }

  void toggle() {
    state = !state;
    debugPrint('[Cell Coverage] Visibility toggled to: $state');
    _persistState();
  }

  void set({required bool value}) {
    state = value;
    debugPrint('[Cell Coverage] Visibility set to: $state');
    _persistState();
  }
}

/// Data for an off-screen cell tower indicator
class OffscreenTowerIndicator {
  const OffscreenTowerIndicator({
    required this.tower,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.edgePosition,
  });

  /// The cell tower this indicator represents
  final CellTower tower;

  /// Distance from viewport center to tower in meters
  final double distanceMeters;

  /// Bearing from viewport center to tower (0 = North, 90 = East, etc.)
  final double bearingDegrees;

  /// Which edge of screen to show indicator (top, bottom, left, right)
  final ScreenEdge edgePosition;
}

/// Screen edge for indicator placement
enum ScreenEdge { top, bottom, left, right }

/// Calculate bearing from point1 to point2 in degrees (0-360)
double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
  final dLon = (lon2 - lon1) * (math.pi / 180);
  final lat1Rad = lat1 * (math.pi / 180);
  final lat2Rad = lat2 * (math.pi / 180);

  final y = math.sin(dLon) * math.cos(lat2Rad);
  final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
      math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);

  final rawBearing = math.atan2(y, x) * (180 / math.pi);
  return (rawBearing + 360) % 360; // Normalize to 0-360
}

/// Determine which screen edge a bearing points to
ScreenEdge _bearingToEdge(double bearing) {
  // Normalize bearing to 0-360
  final normalizedBearing = (bearing + 360) % 360;

  if (normalizedBearing >= 315 || normalizedBearing < 45) {
    return ScreenEdge.top; // North
  } else if (normalizedBearing >= 45 && normalizedBearing < 135) {
    return ScreenEdge.right; // East
  } else if (normalizedBearing >= 135 && normalizedBearing < 225) {
    return ScreenEdge.bottom; // South
  } else {
    return ScreenEdge.left; // West
  }
}

/// Provider for off-screen cell tower indicators
///
/// Returns nearby off-screen towers positioned along screen edges based on
/// their actual bearing. Shows multiple towers per direction.
final offscreenTowerIndicatorsProvider =
    FutureProvider.family<List<OffscreenTowerIndicator>, LandBounds>((ref, bounds) async {
  try {
    // Check if cell coverage is visible
    final isVisible = ref.watch(cellCoverageVisibilityProvider);
    if (!isVisible) {
      debugPrint('[Off-screen Indicators] Skipping - cell coverage not visible');
      return [];
    }

    // Check subscription
    final isPremium = ref.watch(isPremiumProvider);
    if (!isPremium) {
      debugPrint('[Off-screen Indicators] Skipping - not premium');
      return [];
    }

    // Get filter configuration
    final filter = ref.watch(cellCoverageFilterProvider);
    if (filter.noTypesEnabled) {
      debugPrint('[Off-screen Indicators] Skipping - no types enabled');
      return [];
    }

    // Calculate viewport center
    final centerLat = (bounds.north + bounds.south) / 2;
    final centerLon = (bounds.east + bounds.west) / 2;

    // Query for towers in a larger area (50km buffer for off-screen indicators)
    const double offscreenBufferMeters = 50000; // 50km
    final double latBuffer = _metersToDegreesLat(offscreenBufferMeters);
    final double lonBuffer = _metersToDegreesLon(offscreenBufferMeters, bounds.north);

    final offlineService = OfflineLandRightsService();
    final allTowers = await offlineService.queryCellTowersForBounds(
      north: bounds.north + latBuffer,
      south: bounds.south - latBuffer,
      east: bounds.east + lonBuffer,
      west: bounds.west - lonBuffer,
      radioTypeFilter: filter.enabledTypes,
    );

    if (allTowers.isEmpty) {
      debugPrint('[Off-screen Indicators] No towers found in 50km buffer');
      return [];
    }

    debugPrint('[Off-screen Indicators] Found ${allTowers.length} towers in 50km buffer');

    // Find towers that are OFF-SCREEN (not visible in current viewport)
    final offscreenTowers = <OffscreenTowerIndicator>[];
    int skippedInViewport = 0;
    int skippedReachesIn = 0;
    int skippedTooFar = 0;

    for (final tower in allTowers) {
      // Check if tower is in viewport (skip if visible)
      final bool isInViewport =
          tower.latitude >= bounds.south &&
          tower.latitude <= bounds.north &&
          tower.longitude >= bounds.west &&
          tower.longitude <= bounds.east;

      // Skip if tower is in viewport
      if (isInViewport) {
        skippedInViewport++;
        continue;
      }

      // Skip if tower's coverage reaches into viewport (already visible as circle)
      if (_shouldShowTower(tower, bounds.north, bounds.south, bounds.east, bounds.west)) {
        skippedReachesIn++;
        continue;
      }

      // Calculate distance from nearest viewport edge to tower
      // (not from center - that makes far edges seem too far)
      final closestLat = tower.latitude.clamp(bounds.south, bounds.north);
      final closestLon = tower.longitude.clamp(bounds.west, bounds.east);
      final distanceFromEdge = _calculateDistanceMeters(
        tower.latitude, tower.longitude,
        closestLat, closestLon,
      );

      // Skip towers that are too far from the viewport edge (> 30km)
      if (distanceFromEdge > 30000) {
        skippedTooFar++;
        continue;
      }

      final bearing = _calculateBearing(
        centerLat, centerLon,
        tower.latitude, tower.longitude,
      );

      final edge = _bearingToEdge(bearing);

      offscreenTowers.add(OffscreenTowerIndicator(
        tower: tower,
        distanceMeters: distanceFromEdge, // Distance from viewport edge, not center
        bearingDegrees: bearing,
        edgePosition: edge,
      ));
    }

    debugPrint('[Off-screen Indicators] Filtering: ${offscreenTowers.length} qualify, $skippedInViewport in viewport, $skippedReachesIn coverage reaches in, $skippedTooFar too far');

    // Sort all by distance
    offscreenTowers.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    // Group by edge and keep nearest 2 per edge
    const int maxPerEdge = 2;
    const int maxTotal = 6;
    final Map<ScreenEdge, List<OffscreenTowerIndicator>> byEdge = {};

    for (final indicator in offscreenTowers) {
      byEdge.putIfAbsent(indicator.edgePosition, () => []);
      if (byEdge[indicator.edgePosition]!.length < maxPerEdge) {
        byEdge[indicator.edgePosition]!.add(indicator);
      }
    }

    // Flatten and sort by distance, limit total
    final result = byEdge.values.expand((list) => list).toList();
    result.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    final limited = result.take(maxTotal).toList();

    if (limited.isNotEmpty) {
      debugPrint('[Cell Coverage] Off-screen indicators: ${limited.length} (nearest: ${(limited.first.distanceMeters / 1000).toStringAsFixed(1)}km ${limited.first.tower.radioType.displayName})');
    }

    return limited;
  } catch (e) {
    debugPrint('[Cell Coverage] Error getting off-screen indicators: $e');
    return [];
  }
});

/// Notifier for cell coverage filter configuration
class CellCoverageFilterNotifier extends Notifier<CellCoverageFilter> {
  @override
  CellCoverageFilter build() => CellCoverageFilter.defaultFilter;

  /// Toggle a radio type filter
  void toggleType(RadioType type) {
    state = state.toggleType(type);
    debugPrint('[Cell Coverage Filter] Toggled ${type.displayName}: ${state.enabledTypes.contains(type)}');
  }

  /// Enable all radio types
  void enableAll() {
    state = state.enableAll();
    debugPrint('[Cell Coverage Filter] Enabled all types');
  }

  /// Disable all radio types
  void disableAll() {
    state = state.disableAll();
    debugPrint('[Cell Coverage Filter] Disabled all types');
  }

  /// Reset to default filter
  void reset() {
    state = CellCoverageFilter.defaultFilter;
    debugPrint('[Cell Coverage Filter] Reset to default');
  }

  /// Set to modern networks only (4G+)
  void setModernOnly() {
    state = CellCoverageFilter.modernOnly;
    debugPrint('[Cell Coverage Filter] Set to modern networks (4G+)');
  }
}
