import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/advanced_session_analytics.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/session_statistics.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/waypoint_service.dart';

/// Service for generating advanced session analytics and insights
class AdvancedSessionAnalyticsService {
  AdvancedSessionAnalyticsService._();
  static AdvancedSessionAnalyticsService? _instance;
  static AdvancedSessionAnalyticsService get instance =>
      _instance ??= AdvancedSessionAnalyticsService._();

  final DatabaseService _databaseService = DatabaseService();
  final WaypointService _waypointService = WaypointService.instance;

  /// Generate comprehensive analytics for a session
  Future<AdvancedSessionAnalytics> generateSessionAnalytics(
      String sessionId) async {
    try {
      // Get session data
      final session = await _databaseService.getSession(sessionId);
      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

      // Get breadcrumbs and waypoints
      final breadcrumbs =
          await _databaseService.getBreadcrumbsForSession(sessionId);
      final waypoints =
          await _waypointService.getWaypointsForSession(sessionId);

      // Get basic statistics
      final basicStats = await _getBasicStatistics(sessionId);

      // Generate advanced analytics
      final performanceMetrics =
          await _generatePerformanceMetrics(session, breadcrumbs, waypoints);
      final routeAnalysis =
          await _generateRouteAnalysis(session, breadcrumbs, waypoints);
      final environmentalData =
          await _generateEnvironmentalData(session, breadcrumbs);
      final efficiencyMetrics = await _generateEfficiencyMetrics(
          session, breadcrumbs, performanceMetrics);
      final comparisonData =
          await _generateComparisonData(session, performanceMetrics);
      final insights = await _generateInsights(
          session, performanceMetrics, routeAnalysis, comparisonData);

      return AdvancedSessionAnalytics(
        sessionId: sessionId,
        basicStatistics: basicStats,
        performanceMetrics: performanceMetrics,
        routeAnalysis: routeAnalysis,
        environmentalData: environmentalData,
        efficiencyMetrics: efficiencyMetrics,
        comparisonData: comparisonData,
        insights: insights,
        calculatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error generating session analytics: $e');
      rethrow;
    }
  }

  /// Compare multiple sessions
  Future<List<SessionComparisonResult>> compareSessions(
      List<String> sessionIds) async {
    final results = <SessionComparisonResult>[];

    for (int i = 0; i < sessionIds.length; i++) {
      for (int j = i + 1; j < sessionIds.length; j++) {
        final comparison =
            await _compareSessionPair(sessionIds[i], sessionIds[j]);
        results.add(comparison);
      }
    }

    return results;
  }

  /// Get performance trends over time
  Future<PerformanceTrendData> getPerformanceTrends(
      DateTime startDate, DateTime endDate) async {
    final sessions = await _getSessionsInDateRange(startDate, endDate);
    return _calculatePerformanceTrends(sessions);
  }

  /// Get personal records and achievements
  Future<List<PersonalRecord>> getPersonalRecords() async {
    final allSessions = await _databaseService.getAllSessions();
    return _calculatePersonalRecords(allSessions);
  }

  // Private helper methods

  Future<SessionStatistics> _getBasicStatistics(String sessionId) async {
    try {
      // Simplified - would need proper statistics service method
      final session = await _databaseService.getSession(sessionId);
      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }
      final breadcrumbs =
          await _databaseService.getBreadcrumbsForSession(sessionId);
      return _calculateBasicStatistics(session, breadcrumbs);
    } catch (e) {
      // Calculate basic statistics if not available
      final session = await _databaseService.getSession(sessionId);
      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }
      final breadcrumbs =
          await _databaseService.getBreadcrumbsForSession(sessionId);
      return _calculateBasicStatistics(session, breadcrumbs);
    }
  }

  SessionStatistics _calculateBasicStatistics(
          TrackingSession session, List<Breadcrumb> breadcrumbs) =>
      // Simplified calculation - would be more comprehensive in real implementation
      SessionStatistics(
        sessionId: session.id,
        timestamp: DateTime.now(),
        totalDistance: session.totalDistance,
        totalDuration: Duration(milliseconds: session.totalDuration),
        averageSpeed: session.averageSpeed ?? 0.0,
      );

  Future<PerformanceMetrics> _generatePerformanceMetrics(
      TrackingSession session,
      List<Breadcrumb> breadcrumbs,
      List<Waypoint> waypoints) async {
    final paceAnalysis = _calculatePaceAnalysis(breadcrumbs);
    final energyExpenditure = _calculateEnergyExpenditure(session, breadcrumbs);
    final recoveryMetrics = _calculateRecoveryMetrics(session, breadcrumbs);
    final consistencyScore = _calculateConsistencyScore(breadcrumbs);
    final enduranceScore = _calculateEnduranceScore(session, breadcrumbs);

    return PerformanceMetrics(
      paceAnalysis: paceAnalysis,
      heartRateZones: null, // Would need heart rate data
      energyExpenditure: energyExpenditure,
      recoveryMetrics: recoveryMetrics,
      consistencyScore: consistencyScore,
      enduranceScore: enduranceScore,
    );
  }

  PaceAnalysis _calculatePaceAnalysis(List<Breadcrumb> breadcrumbs) {
    if (breadcrumbs.length < 2) {
      return const PaceAnalysis(
        averagePace: 0,
        bestPace: 0,
        worstPace: 0,
        paceVariability: 0,
        paceZones: <PaceZone, Duration>{},
        paceDistribution: <PaceDataPoint>[],
        splitTimes: <SplitTime>[],
      );
    }

    final paces = <double>[];
    final pacePoints = <PaceDataPoint>[];
    const distance = Distance();

    for (int i = 1; i < breadcrumbs.length; i++) {
      final prev = breadcrumbs[i - 1];
      final curr = breadcrumbs[i];

      final segmentDistance = distance.as(
        LengthUnit.Meter,
        prev.coordinates,
        curr.coordinates,
      );

      final timeDiff = curr.timestamp.difference(prev.timestamp).inSeconds;

      if (timeDiff > 0 && segmentDistance > 0) {
        final speed = segmentDistance / timeDiff; // m/s
        final pace = speed > 0 ? (1000 / speed) / 60 : 0; // min/km

        paces.add(pace.toDouble());
        pacePoints.add(PaceDataPoint(
          timestamp: curr.timestamp,
          pace: pace.toDouble(),
          location: curr.coordinates,
          elevation: curr.altitude,
        ));
      }
    }

    if (paces.isEmpty) {
      return const PaceAnalysis(
        averagePace: 0,
        bestPace: 0,
        worstPace: 0,
        paceVariability: 0,
        paceZones: <PaceZone, Duration>{},
        paceDistribution: <PaceDataPoint>[],
        splitTimes: <SplitTime>[],
      );
    }

    final averagePace = paces.reduce((a, b) => a + b) / paces.length;
    final bestPace = paces.reduce(min);
    final worstPace = paces.reduce(max);

    // Calculate pace variability (coefficient of variation)
    final variance =
        paces.map((p) => pow(p - averagePace, 2)).reduce((a, b) => a + b) /
            paces.length;
    final standardDeviation = sqrt(variance);
    final paceVariability =
        averagePace > 0 ? standardDeviation / averagePace : 0;

    // Calculate pace zones
    final paceZones = _calculatePaceZones(paces, breadcrumbs);

    // Calculate split times
    final splitTimes = _calculateSplitTimes(breadcrumbs);

    return PaceAnalysis(
      averagePace: averagePace,
      bestPace: bestPace,
      worstPace: worstPace,
      paceVariability: paceVariability.toDouble(),
      paceZones: paceZones,
      paceDistribution: pacePoints,
      splitTimes: splitTimes,
    );
  }

  Map<PaceZone, Duration> _calculatePaceZones(
      List<double> paces, List<Breadcrumb> breadcrumbs) {
    final zones = <PaceZone, Duration>{
      PaceZone.recovery: Duration.zero,
      PaceZone.easy: Duration.zero,
      PaceZone.moderate: Duration.zero,
      PaceZone.hard: Duration.zero,
      PaceZone.maximum: Duration.zero,
    };

    if (paces.isEmpty || breadcrumbs.length < 2) return zones;

    final averagePace = paces.reduce((a, b) => a + b) / paces.length;

    for (int i = 0; i < paces.length && i + 1 < breadcrumbs.length; i++) {
      final pace = paces[i];
      final duration =
          breadcrumbs[i + 1].timestamp.difference(breadcrumbs[i].timestamp);

      PaceZone zone;
      if (pace > averagePace * 1.3) {
        zone = PaceZone.recovery;
      } else if (pace > averagePace * 1.1) {
        zone = PaceZone.easy;
      } else if (pace > averagePace * 0.9) {
        zone = PaceZone.moderate;
      } else if (pace > averagePace * 0.7) {
        zone = PaceZone.hard;
      } else {
        zone = PaceZone.maximum;
      }

      zones[zone] = zones[zone]! + duration;
    }

    return zones;
  }

  List<SplitTime> _calculateSplitTimes(List<Breadcrumb> breadcrumbs) {
    const splitDistance = 1000.0; // 1km splits
    final splits = <SplitTime>[];

    if (breadcrumbs.length < 2) return splits;

    double totalDistance = 0;
    int splitIndex = 0;
    DateTime splitStart = breadcrumbs.first.timestamp;
    double splitElevationGain = 0;
    double splitElevationLoss = 0;
    double? lastElevation = breadcrumbs.first.altitude;

    const distance = Distance();

    for (int i = 1; i < breadcrumbs.length; i++) {
      final prev = breadcrumbs[i - 1];
      final curr = breadcrumbs[i];

      final segmentDistance = distance.as(
        LengthUnit.Meter,
        prev.coordinates,
        curr.coordinates,
      );

      totalDistance += segmentDistance;

      // Track elevation changes
      if (lastElevation != null && curr.altitude != null) {
        final elevationChange = curr.altitude! - lastElevation;
        if (elevationChange > 0) {
          splitElevationGain += elevationChange;
        } else {
          splitElevationLoss += elevationChange.abs();
        }
        lastElevation = curr.altitude;
      }

      // Check if we've completed a split
      if (totalDistance >= (splitIndex + 1) * splitDistance) {
        final splitTime = curr.timestamp.difference(splitStart);
        final splitPace = splitTime.inSeconds > 0
            ? (splitDistance / 1000) /
                (splitTime.inSeconds / 3600) *
                60 // min/km
            : 0;

        splits.add(SplitTime(
          distance: (splitIndex + 1) * splitDistance / 1000, // km
          time: splitTime,
          pace: splitPace.toDouble(),
          elevationGain: splitElevationGain,
          elevationLoss: splitElevationLoss,
        ));

        splitIndex++;
        splitStart = curr.timestamp;
        splitElevationGain = 0;
        splitElevationLoss = 0;
      }
    }

    return splits;
  }

  EnergyExpenditure _calculateEnergyExpenditure(
      TrackingSession session, List<Breadcrumb> breadcrumbs) {
    // Simplified energy calculation - would use more sophisticated algorithms
    const double baseMetabolicRate = 1.2; // METs for walking
    const double weightKg = 70; // Default weight - would get from user profile

    final durationHours = session.totalDuration / (1000 * 60 * 60);
    final distanceKm = session.totalDistance / 1000;

    // Calculate METs based on speed and terrain
    double avgSpeed = 0;
    if (durationHours > 0) {
      avgSpeed = distanceKm / durationHours; // km/h
    }

    double mets = baseMetabolicRate;
    if (avgSpeed > 6.5) {
      mets = 8.0; // Running
    } else if (avgSpeed > 5.0) {
      mets = 6.0; // Fast walking
    } else if (avgSpeed > 3.5) {
      mets = 4.0; // Moderate walking
    } else {
      mets = 3.0; // Slow walking
    }

    final totalCalories = mets * weightKg * durationHours;
    final caloriesPerKm = distanceKm > 0 ? totalCalories / distanceKm : 0;
    final caloriesPerHour =
        durationHours > 0 ? totalCalories / durationHours : 0;

    // Estimate fat vs carb calories (simplified)
    final fatCalories = totalCalories * 0.6; // Assume 60% fat burning
    final carbCalories = totalCalories * 0.4; // Assume 40% carb burning

    return EnergyExpenditure(
      totalCalories: totalCalories,
      caloriesPerKm: caloriesPerKm.toDouble(),
      caloriesPerHour: caloriesPerHour.toDouble(),
      fatCalories: fatCalories,
      carbCalories: carbCalories,
      metabolicEquivalent: mets,
    );
  }

  RecoveryMetrics _calculateRecoveryMetrics(
      TrackingSession session, List<Breadcrumb> breadcrumbs) {
    // Simplified recovery calculation
    final durationHours = session.totalDuration / (1000 * 60 * 60);
    final distanceKm = session.totalDistance / 1000;

    // Calculate training load based on duration and intensity
    double intensity = 1.0; // Base intensity
    if (durationHours > 0) {
      final avgSpeed = distanceKm / durationHours;
      if (avgSpeed > 8)
        intensity = 3.0; // High intensity
      else if (avgSpeed > 6)
        intensity = 2.5; // Moderate-high
      else if (avgSpeed > 4)
        intensity = 2.0; // Moderate
      else
        intensity = 1.5; // Low-moderate
    }

    final trainingLoad = durationHours * intensity * 100;
    final stressScore = min(trainingLoad / 10, 100); // Cap at 100

    // Estimate recovery time (simplified)
    final recoveryHours = (trainingLoad / 50).round();
    final recoveryTime = Duration(hours: recoveryHours);

    // Estimate fatigue level
    final fatigueLevel = min(stressScore * 0.8, 100);

    // Recommend rest days
    final recommendedRestDays = (stressScore / 25).round();

    return RecoveryMetrics(
      recoveryTime: recoveryTime,
      trainingLoad: trainingLoad,
      stressScore: stressScore.toDouble(),
      fatigueLevel: fatigueLevel.toDouble(),
      recommendedRestDays: recommendedRestDays,
    );
  }

  double _calculateConsistencyScore(List<Breadcrumb> breadcrumbs) {
    if (breadcrumbs.length < 3) return 100.0;

    final speeds = <double>[];
    const distance = Distance();

    for (int i = 1; i < breadcrumbs.length; i++) {
      final prev = breadcrumbs[i - 1];
      final curr = breadcrumbs[i];

      final segmentDistance = distance.as(
        LengthUnit.Meter,
        prev.coordinates,
        curr.coordinates,
      );

      final timeDiff = curr.timestamp.difference(prev.timestamp).inSeconds;

      if (timeDiff > 0) {
        speeds.add(segmentDistance / timeDiff);
      }
    }

    if (speeds.isEmpty) return 100.0;

    final avgSpeed = speeds.reduce((a, b) => a + b) / speeds.length;
    final variance =
        speeds.map((s) => pow(s - avgSpeed, 2)).reduce((a, b) => a + b) /
            speeds.length;
    final standardDeviation = sqrt(variance);

    // Convert to consistency score (lower variability = higher consistency)
    final coefficientOfVariation =
        avgSpeed > 0 ? standardDeviation / avgSpeed : 0;
    final consistencyScore = max(0, 100 - (coefficientOfVariation * 100));

    return consistencyScore.toDouble();
  }

  double _calculateEnduranceScore(
      TrackingSession session, List<Breadcrumb> breadcrumbs) {
    // Simplified endurance calculation based on sustained effort
    final durationHours = session.totalDuration / (1000 * 60 * 60);
    final distanceKm = session.totalDistance / 1000;

    // Base score on duration and distance
    final double durationScore =
        min(durationHours * 10, 50); // Max 50 points for duration
    final double distanceScore =
        min(distanceKm * 2, 50); // Max 50 points for distance

    return durationScore + distanceScore;
  }

  Future<RouteAnalysis> _generateRouteAnalysis(TrackingSession session,
      List<Breadcrumb> breadcrumbs, List<Waypoint> waypoints) async {
    final routeType = _detectRouteType(breadcrumbs);
    final terrainAnalysis = _analyzeTerrain(breadcrumbs);
    final elevationProfile = _generateElevationProfile(breadcrumbs);
    final difficultyScore =
        _calculateDifficultyScore(elevationProfile, terrainAnalysis);
    final scenicScore = _calculateScenicScore(waypoints, breadcrumbs);
    final technicalScore = _calculateTechnicalScore(elevationProfile);
    final routeEfficiency = _calculateRouteEfficiency(breadcrumbs);
    final landmarks = _identifyLandmarks(waypoints);

    return RouteAnalysis(
      routeType: routeType,
      terrainAnalysis: terrainAnalysis,
      elevationProfile: elevationProfile,
      difficultyScore: difficultyScore,
      scenicScore: scenicScore,
      technicalScore: technicalScore,
      routeEfficiency: routeEfficiency,
      landmarks: landmarks,
    );
  }

  RouteType _detectRouteType(List<Breadcrumb> breadcrumbs) {
    if (breadcrumbs.length < 3) return RouteType.pointToPoint;

    final start = breadcrumbs.first.coordinates;
    final end = breadcrumbs.last.coordinates;

    const distance = Distance();
    final startEndDistance = distance.as(LengthUnit.Meter, start, end);

    // If start and end are very close, it's likely a loop
    if (startEndDistance < 100) {
      return RouteType.loop;
    }

    // Check for out-and-back pattern by analyzing if the route retraces itself
    final midPoint = breadcrumbs.length ~/ 2;
    final firstHalf = breadcrumbs.sublist(0, midPoint);
    final secondHalf = breadcrumbs.sublist(midPoint);

    // Simplified check for out-and-back
    if (_isOutAndBack(firstHalf, secondHalf)) {
      return RouteType.outAndBack;
    }

    return RouteType.pointToPoint;
  }

  bool _isOutAndBack(List<Breadcrumb> firstHalf, List<Breadcrumb> secondHalf) {
    // Simplified algorithm - check if second half roughly retraces first half
    if (firstHalf.length < 5 || secondHalf.length < 5) return false;

    const distance = Distance();
    int matches = 0;

    for (int i = 0; i < min(firstHalf.length, secondHalf.length ~/ 2); i++) {
      final firstPoint = firstHalf[firstHalf.length - 1 - i].coordinates;
      final secondPoint = secondHalf[i].coordinates;

      final dist = distance.as(LengthUnit.Meter, firstPoint, secondPoint);
      if (dist < 50) {
        // Within 50 meters
        matches++;
      }
    }

    return matches > firstHalf.length * 0.3; // 30% of points match
  }

  TerrainAnalysis _analyzeTerrain(List<Breadcrumb> breadcrumbs) {
    // Simplified terrain analysis
    final surfaceTypes = <SurfaceType, double>{
      SurfaceType.trail: 0.7, // Assume mostly trail
      SurfaceType.road: 0.3,
    };

    final gradientDistribution = _calculateGradientDistribution(breadcrumbs);

    return TerrainAnalysis(
      surfaceTypes: surfaceTypes,
      gradientDistribution: gradientDistribution,
      technicalSections: const [], // Would need more sophisticated analysis
      restAreas: const [], // Would need waypoint analysis
    );
  }

  Map<GradientType, double> _calculateGradientDistribution(
      List<Breadcrumb> breadcrumbs) {
    final distribution = <GradientType, double>{
      GradientType.flat: 0,
      GradientType.gentle: 0,
      GradientType.moderate: 0,
      GradientType.steep: 0,
      GradientType.verysteep: 0,
    };

    if (breadcrumbs.length < 2) {
      distribution[GradientType.flat] = 1.0;
      return distribution;
    }

    const distance = Distance();
    double totalDistance = 0;

    for (int i = 1; i < breadcrumbs.length; i++) {
      final prev = breadcrumbs[i - 1];
      final curr = breadcrumbs[i];

      final segmentDistance = distance.as(
        LengthUnit.Meter,
        prev.coordinates,
        curr.coordinates,
      );

      if (segmentDistance > 0 &&
          prev.altitude != null &&
          curr.altitude != null) {
        final elevationChange = curr.altitude! - prev.altitude!;
        final gradient =
            (elevationChange / segmentDistance) * 100; // Percentage

        GradientType type;
        if (gradient.abs() < 2) {
          type = GradientType.flat;
        } else if (gradient.abs() < 5) {
          type = GradientType.gentle;
        } else if (gradient.abs() < 10) {
          type = GradientType.moderate;
        } else if (gradient.abs() < 20) {
          type = GradientType.steep;
        } else {
          type = GradientType.verysteep;
        }

        distribution[type] = distribution[type]! + segmentDistance;
        totalDistance += segmentDistance;
      }
    }

    // Normalize to percentages
    if (totalDistance > 0) {
      for (final key in distribution.keys) {
        distribution[key] = distribution[key]! / totalDistance;
      }
    } else {
      distribution[GradientType.flat] = 1.0;
    }

    return distribution;
  }

  ElevationProfile _generateElevationProfile(List<Breadcrumb> breadcrumbs) {
    final elevationPoints = <ElevationPoint>[];
    double totalDistance = 0;
    double totalAscent = 0;
    double totalDescent = 0;
    double steepestAscent = 0;
    double steepestDescent = 0;

    if (breadcrumbs.isEmpty) {
      return ElevationProfile(
        elevationPoints: elevationPoints,
        totalAscent: totalAscent,
        totalDescent: totalDescent,
        steepestAscent: steepestAscent,
        steepestDescent: steepestDescent,
        elevationGainRate: 0,
        elevationLossRate: 0,
      );
    }

    const distance = Distance();

    for (int i = 0; i < breadcrumbs.length; i++) {
      final breadcrumb = breadcrumbs[i];

      if (i > 0) {
        final prev = breadcrumbs[i - 1];
        final segmentDistance = distance.as(
          LengthUnit.Meter,
          prev.coordinates,
          breadcrumb.coordinates,
        );
        totalDistance += segmentDistance;

        if (prev.altitude != null && breadcrumb.altitude != null) {
          final elevationChange = breadcrumb.altitude! - prev.altitude!;
          final gradient = segmentDistance > 0
              ? (elevationChange / segmentDistance) * 100
              : 0;

          if (elevationChange > 0) {
            totalAscent += elevationChange;
          } else {
            totalDescent += elevationChange.abs();
          }

          final gradientDegrees = atan(gradient / 100) * 180 / pi;
          if (gradientDegrees > steepestAscent) {
            steepestAscent = gradientDegrees;
          }
          if (gradientDegrees < -steepestDescent) {
            steepestDescent = gradientDegrees.abs();
          }
        }
      }

      if (breadcrumb.altitude != null) {
        elevationPoints.add(ElevationPoint(
          distance: totalDistance / 1000, // km
          elevation: breadcrumb.altitude!,
          gradient: i > 0 && breadcrumbs[i - 1].altitude != null
              ? ((breadcrumb.altitude! - breadcrumbs[i - 1].altitude!) /
                      distance.as(
                          LengthUnit.Meter,
                          breadcrumbs[i - 1].coordinates,
                          breadcrumb.coordinates)) *
                  100
              : 0,
          location: breadcrumb.coordinates,
        ));
      }
    }

    final elevationGainRate =
        totalDistance > 0 ? (totalAscent / totalDistance) * 1000 : 0;
    final elevationLossRate =
        totalDistance > 0 ? (totalDescent / totalDistance) * 1000 : 0;

    return ElevationProfile(
      elevationPoints: elevationPoints,
      totalAscent: totalAscent,
      totalDescent: totalDescent,
      steepestAscent: steepestAscent,
      steepestDescent: steepestDescent,
      elevationGainRate: elevationGainRate.toDouble(),
      elevationLossRate: elevationLossRate.toDouble(),
    );
  }

  double _calculateDifficultyScore(
      ElevationProfile elevationProfile, TerrainAnalysis terrainAnalysis) {
    double score = 0;

    // Elevation difficulty (40% of score)
    final elevationScore = min(40, (elevationProfile.totalAscent / 100) * 10);
    score += elevationScore;

    // Gradient difficulty (30% of score)
    final gradientScore =
        (terrainAnalysis.gradientDistribution[GradientType.steep] ?? 0) * 15 +
            (terrainAnalysis.gradientDistribution[GradientType.verysteep] ??
                    0) *
                30;
    score += gradientScore;

    // Steepness difficulty (30% of score)
    final steepnessScore = min(30, elevationProfile.steepestAscent * 2);
    score += steepnessScore;

    return min(100, score);
  }

  double _calculateScenicScore(
      List<Waypoint> waypoints, List<Breadcrumb> breadcrumbs) {
    // Simplified scenic scoring based on waypoints and variety
    double score = 50; // Base score

    // Add points for photo waypoints (assuming they mark scenic spots)
    final photoWaypoints =
        waypoints.where((w) => w.type == WaypointType.photo).length;
    score += min(30, photoWaypoints * 5);

    // Add points for viewpoint waypoints
    final viewpointWaypoints =
        waypoints.where((w) => w.type == WaypointType.interest).length;
    score += min(20, viewpointWaypoints * 10);

    return min(100, score);
  }

  double _calculateTechnicalScore(ElevationProfile elevationProfile) {
    double score = 0;

    // Technical difficulty based on elevation changes and steepness
    score += min(50, elevationProfile.steepestAscent * 2.5);
    score += min(30, elevationProfile.steepestDescent * 2);
    score += min(20,
        (elevationProfile.totalAscent + elevationProfile.totalDescent) / 100);

    return min(100, score);
  }

  double _calculateRouteEfficiency(List<Breadcrumb> breadcrumbs) {
    if (breadcrumbs.length < 2) return 100.0;

    final start = breadcrumbs.first.coordinates;
    final end = breadcrumbs.last.coordinates;
    const distance = Distance();
    final directDistance = distance.as(LengthUnit.Meter, start, end);

    double totalDistance = 0;
    for (int i = 1; i < breadcrumbs.length; i++) {
      totalDistance += distance.as(
        LengthUnit.Meter,
        breadcrumbs[i - 1].coordinates,
        breadcrumbs[i].coordinates,
      );
    }

    // Calculate efficiency as direct distance / actual distance
    if (totalDistance > 0) {
      return min(100.0, (directDistance / totalDistance) * 100);
    }

    return 100.0;
  }

  List<Landmark> _identifyLandmarks(List<Waypoint> waypoints) =>
      waypoints.map((waypoint) {
        LandmarkType type;
        switch (waypoint.type) {
          case WaypointType.photo:
            type = LandmarkType.viewpoint;
            break;
          case WaypointType.interest:
            type = LandmarkType.monument;
            break;
          case WaypointType.camp:
            type = LandmarkType.building;
            break;
          default:
            type = LandmarkType.intersection;
        }

        return Landmark(
          name: waypoint.name ?? 'Unnamed Landmark',
          location: waypoint.coordinates,
          type: type,
          description: waypoint.notes ?? '',
          timestamp: waypoint.timestamp,
        );
      }).toList();

  Future<EnvironmentalData> _generateEnvironmentalData(
          TrackingSession session, List<Breadcrumb> breadcrumbs) async =>
      // Simplified environmental data - would integrate with weather APIs
      EnvironmentalData(
        weatherConditions: const WeatherConditions(
          condition: WeatherCondition.clear,
          precipitation: 0,
          visibility: 10,
          pressure: 1013.25,
        ),
        temperatureProfile: const TemperatureProfile(
          averageTemperature: 20,
          minTemperature: 18,
          maxTemperature: 22,
          temperatureVariation: 4,
          heatIndex: null,
          windChill: null,
        ),
        humidityProfile: const HumidityProfile(
          averageHumidity: 60,
          minHumidity: 55,
          maxHumidity: 65,
          dewPoint: 12,
        ),
        windConditions: const WindConditions(
          averageSpeed: 5,
          maxSpeed: 8,
          direction: 180,
          gustiness: 20,
        ),
        lightConditions: LightConditions(
          sunrise: DateTime.now().subtract(const Duration(hours: 6)),
          sunset: DateTime.now().add(const Duration(hours: 6)),
          daylight: const Duration(hours: 12),
          uvIndex: 5,
          lightLevel: LightLevel.bright,
        ),
        airQuality: null,
      );

  Future<EfficiencyMetrics> _generateEfficiencyMetrics(
      TrackingSession session,
      List<Breadcrumb> breadcrumbs,
      PerformanceMetrics performanceMetrics) async {
    // Simplified efficiency calculations
    final energyEfficiency = min(
        100.0, performanceMetrics.energyExpenditure.metabolicEquivalent * 20);
    final timeEfficiency = performanceMetrics.consistencyScore;
    final routeEfficiency = _calculateRouteEfficiency(breadcrumbs);
    final paceEfficiency =
        100.0 - (performanceMetrics.paceAnalysis.paceVariability * 100);

    final optimizationSuggestions = <OptimizationSuggestion>[
      if (paceEfficiency < 70)
        const OptimizationSuggestion(
          category: OptimizationCategory.pacing,
          suggestion:
              'Try to maintain a more consistent pace throughout your session',
          impact: 75,
          difficulty: 30,
        ),
      if (routeEfficiency < 80)
        const OptimizationSuggestion(
          category: OptimizationCategory.route,
          suggestion: 'Consider a more direct route to improve efficiency',
          impact: 60,
          difficulty: 50,
        ),
    ];

    return EfficiencyMetrics(
      energyEfficiency: energyEfficiency,
      timeEfficiency: timeEfficiency,
      routeEfficiency: routeEfficiency,
      paceEfficiency: paceEfficiency,
      optimizationSuggestions: optimizationSuggestions,
    );
  }

  Future<SessionComparisonData> _generateComparisonData(
      TrackingSession session, PerformanceMetrics performanceMetrics) async {
    // Get all user sessions for comparison
    final allSessions = await _databaseService.getAllSessions();
    final completedSessions = allSessions.where((s) => s.isCompleted).toList();

    final personalBests = <PersonalBest>[];

    // Check for personal bests
    if (completedSessions.isNotEmpty) {
      final longestDistance =
          completedSessions.map((s) => s.totalDistance).reduce(max);
      if (session.totalDistance >= longestDistance) {
        personalBests.add(PersonalBest(
          metric: 'Longest Distance',
          value: session.totalDistance,
          previousBest: longestDistance,
          improvement: session.totalDistance - longestDistance,
          achievedAt: session.completedAt ?? DateTime.now(),
        ));
      }

      final longestDuration =
          completedSessions.map((s) => s.totalDuration).reduce(max);
      if (session.totalDuration >= longestDuration) {
        personalBests.add(PersonalBest(
          metric: 'Longest Duration',
          value: session.totalDuration.toDouble(),
          previousBest: longestDuration.toDouble(),
          improvement: (session.totalDuration - longestDuration).toDouble(),
          achievedAt: session.completedAt ?? DateTime.now(),
        ));
      }
    }

    // Calculate averages for comparison
    final avgDistance = completedSessions.isNotEmpty
        ? completedSessions
                .map((s) => s.totalDistance)
                .reduce((a, b) => a + b) /
            completedSessions.length
        : 0.0;
    final avgDuration = completedSessions.isNotEmpty
        ? completedSessions
                .map((s) => s.totalDuration)
                .reduce((a, b) => a + b) /
            completedSessions.length
        : 0.0;

    final averageComparison = AverageComparison(
      distanceComparison: avgDistance > 0
          ? ((session.totalDistance - avgDistance) / avgDistance) * 100
          : 0,
      timeComparison: avgDuration > 0
          ? ((session.totalDuration - avgDuration) / avgDuration) * 100
          : 0,
      paceComparison: 0, // Would need more sophisticated calculation
      elevationComparison: 0, // Would need elevation data from other sessions
      overallPerformance: performanceMetrics.consistencyScore,
    );

    const trendAnalysis = TrendAnalysis(
      fitnessProgress: 5.0, // Simplified - would need historical analysis
      performanceTrend: PerformanceTrend.improving,
      consistencyTrend: 2.0,
      projectedGoals: [],
    );

    final rankingData = RankingData(
      personalRanking: completedSessions.length + 1,
      categoryRanking: 1,
      percentile: 75.0,
      competitiveLevel: CompetitiveLevel.recreational,
    );

    return SessionComparisonData(
      personalBests: personalBests,
      averageComparison: averageComparison,
      trendAnalysis: trendAnalysis,
      rankingData: rankingData,
    );
  }

  Future<List<SessionInsight>> _generateInsights(
      TrackingSession session,
      PerformanceMetrics performanceMetrics,
      RouteAnalysis routeAnalysis,
      SessionComparisonData comparisonData) async {
    final insights = <SessionInsight>[];

    // Performance insights
    if (performanceMetrics.consistencyScore > 80) {
      insights.add(const SessionInsight(
        type: InsightType.achievement,
        title: 'Excellent Consistency',
        description:
            'You maintained a very consistent pace throughout this session.',
        importance: 75,
        actionable: false,
        category: InsightCategory.performance,
      ));
    }

    if (performanceMetrics.enduranceScore > 70) {
      insights.add(const SessionInsight(
        type: InsightType.achievement,
        title: 'Great Endurance',
        description:
            'Your endurance performance was excellent for this session.',
        importance: 80,
        actionable: false,
        category: InsightCategory.performance,
      ));
    }

    // Route insights
    if (routeAnalysis.difficultyScore > 75) {
      insights.add(const SessionInsight(
        type: InsightType.observation,
        title: 'Challenging Route',
        description:
            'This was a particularly challenging route with significant elevation changes.',
        importance: 70,
        actionable: false,
        category: InsightCategory.performance,
      ));
    }

    // Recovery insights
    if (performanceMetrics.recoveryMetrics.recommendedRestDays > 2) {
      insights.add(SessionInsight(
        type: InsightType.recommendation,
        title: 'Recovery Needed',
        description:
            'Consider taking ${performanceMetrics.recoveryMetrics.recommendedRestDays} rest days to recover properly.',
        importance: 90,
        actionable: true,
        category: InsightCategory.health,
      ));
    }

    // Personal best insights
    if (comparisonData.personalBests.isNotEmpty) {
      insights.add(SessionInsight(
        type: InsightType.achievement,
        title: 'Personal Best!',
        description:
            'You achieved ${comparisonData.personalBests.length} personal best(s) in this session!',
        importance: 95,
        actionable: false,
        category: InsightCategory.motivation,
      ));
    }

    return insights;
  }

  Future<SessionComparisonResult> _compareSessionPair(
      String sessionId1, String sessionId2) async {
    final session1 = await _databaseService.getSession(sessionId1);
    final session2 = await _databaseService.getSession(sessionId2);

    if (session1 == null || session2 == null) {
      throw Exception('One or both sessions not found');
    }

    final distanceComparison = session2.totalDistance > 0
        ? ((session1.totalDistance - session2.totalDistance) /
                session2.totalDistance) *
            100
        : 0.0;

    final timeComparison = session2.totalDuration > 0
        ? ((session1.totalDuration - session2.totalDuration) /
                session2.totalDuration) *
            100
        : 0.0;

    final pace1 = session1.averageSpeed ?? 0;
    final pace2 = session2.averageSpeed ?? 0;
    final paceComparison = pace2 > 0 ? ((pace1 - pace2) / pace2) * 100 : 0.0;

    // Simple overall comparison
    String overallWinner = sessionId1;
    if (session2.totalDistance > session1.totalDistance &&
        session2.totalDuration < session1.totalDuration) {
      overallWinner = sessionId2;
    }

    return SessionComparisonResult(
      session1Id: sessionId1,
      session2Id: sessionId2,
      distanceComparison: distanceComparison,
      timeComparison: timeComparison,
      paceComparison: paceComparison,
      difficultyComparison: 0.0, // Would need elevation data
      overallWinner: overallWinner,
    );
  }

  Future<List<TrackingSession>> _getSessionsInDateRange(
      DateTime startDate, DateTime endDate) async {
    final allSessions = await _databaseService.getAllSessions();
    return allSessions.where((session) {
      final sessionDate = session.startedAt ?? session.createdAt;
      return sessionDate.isAfter(startDate) && sessionDate.isBefore(endDate);
    }).toList();
  }

  PerformanceTrendData _calculatePerformanceTrends(
      List<TrackingSession> sessions) {
    if (sessions.length < 2) {
      return PerformanceTrendData(
        timeRange: DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 30)),
          end: DateTime.now(),
        ),
        distanceTrend: TrendDirection.stable,
        paceTrend: TrendDirection.stable,
        consistencyTrend: TrendDirection.stable,
        frequencyTrend: TrendDirection.stable,
      );
    }

    // Sort sessions by date
    sessions.sort((a, b) =>
        (a.startedAt ?? a.createdAt).compareTo(b.startedAt ?? b.createdAt));

    // Calculate trends (simplified)
    final firstHalf = sessions.take(sessions.length ~/ 2).toList();
    final secondHalf = sessions.skip(sessions.length ~/ 2).toList();

    final firstHalfAvgDistance =
        firstHalf.map((s) => s.totalDistance).reduce((a, b) => a + b) /
            firstHalf.length;
    final secondHalfAvgDistance =
        secondHalf.map((s) => s.totalDistance).reduce((a, b) => a + b) /
            secondHalf.length;

    final distanceTrend = secondHalfAvgDistance > firstHalfAvgDistance * 1.1
        ? TrendDirection.increasing
        : secondHalfAvgDistance < firstHalfAvgDistance * 0.9
            ? TrendDirection.decreasing
            : TrendDirection.stable;

    return PerformanceTrendData(
      timeRange: DateTimeRange(
        start: sessions.first.startedAt ?? sessions.first.createdAt,
        end: sessions.last.startedAt ?? sessions.last.createdAt,
      ),
      distanceTrend: distanceTrend,
      paceTrend: TrendDirection.stable, // Simplified
      consistencyTrend: TrendDirection.stable, // Simplified
      frequencyTrend: TrendDirection.stable, // Simplified
    );
  }

  List<PersonalRecord> _calculatePersonalRecords(
      List<TrackingSession> sessions) {
    final records = <PersonalRecord>[];

    if (sessions.isEmpty) return records;

    // Find longest distance
    final longestDistanceSession =
        sessions.reduce((a, b) => a.totalDistance > b.totalDistance ? a : b);
    records.add(PersonalRecord(
      metric: 'Longest Distance',
      value: longestDistanceSession.totalDistance,
      sessionId: longestDistanceSession.id,
      achievedAt: longestDistanceSession.completedAt ??
          longestDistanceSession.createdAt,
    ));

    // Find longest duration
    final longestDurationSession =
        sessions.reduce((a, b) => a.totalDuration > b.totalDuration ? a : b);
    records.add(PersonalRecord(
      metric: 'Longest Duration',
      value: longestDurationSession.totalDuration.toDouble(),
      sessionId: longestDurationSession.id,
      achievedAt: longestDurationSession.completedAt ??
          longestDurationSession.createdAt,
    ));

    // Find fastest average speed
    final fastestSession = sessions
        .where((s) => s.averageSpeed != null)
        .fold<TrackingSession?>(
            null,
            (prev, curr) => prev == null ||
                    (curr.averageSpeed ?? 0) > (prev.averageSpeed ?? 0)
                ? curr
                : prev);

    if (fastestSession != null) {
      records.add(PersonalRecord(
        metric: 'Fastest Average Speed',
        value: fastestSession.averageSpeed!,
        sessionId: fastestSession.id,
        achievedAt: fastestSession.completedAt ?? fastestSession.createdAt,
      ));
    }

    return records;
  }
}

// Additional model classes for missing types
@immutable
class SessionComparisonResult {
  const SessionComparisonResult({
    required this.session1Id,
    required this.session2Id,
    required this.distanceComparison,
    required this.timeComparison,
    required this.paceComparison,
    required this.difficultyComparison,
    required this.overallWinner,
  });

  final String session1Id;
  final String session2Id;
  final double distanceComparison; // percentage difference
  final double timeComparison;
  final double paceComparison;
  final double difficultyComparison;
  final String overallWinner; // session1Id or session2Id
}

@immutable
class PerformanceTrendData {
  const PerformanceTrendData({
    required this.timeRange,
    required this.distanceTrend,
    required this.paceTrend,
    required this.consistencyTrend,
    required this.frequencyTrend,
  });

  final DateTimeRange timeRange;
  final TrendDirection distanceTrend;
  final TrendDirection paceTrend;
  final TrendDirection consistencyTrend;
  final TrendDirection frequencyTrend;
}

@immutable
class DateTimeRange {
  const DateTimeRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;
}

enum TrendDirection {
  increasing,
  decreasing,
  stable,
}

@immutable
class PersonalRecord {
  const PersonalRecord({
    required this.metric,
    required this.value,
    required this.sessionId,
    required this.achievedAt,
  });

  final String metric;
  final double value;
  final String sessionId;
  final DateTime achievedAt;
}
