import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/session_statistics.dart';

/// Advanced analytics data for a tracking session
@immutable
class AdvancedSessionAnalytics {
  const AdvancedSessionAnalytics({
    required this.sessionId,
    required this.basicStatistics,
    required this.performanceMetrics,
    required this.routeAnalysis,
    required this.environmentalData,
    required this.efficiencyMetrics,
    required this.comparisonData,
    required this.insights,
    required this.calculatedAt,
  });

  /// Session ID these analytics belong to
  final String sessionId;

  /// Basic session statistics
  final SessionStatistics basicStatistics;

  /// Performance-related metrics
  final PerformanceMetrics performanceMetrics;

  /// Route and path analysis
  final RouteAnalysis routeAnalysis;

  /// Environmental conditions during session
  final EnvironmentalData environmentalData;

  /// Efficiency and optimization metrics
  final EfficiencyMetrics efficiencyMetrics;

  /// Comparison with other sessions
  final SessionComparisonData comparisonData;

  /// AI-generated insights and recommendations
  final List<SessionInsight> insights;

  /// When these analytics were calculated
  final DateTime calculatedAt;
}

/// Performance metrics for a session
@immutable
class PerformanceMetrics {
  const PerformanceMetrics({
    required this.paceAnalysis,
    required this.heartRateZones,
    required this.energyExpenditure,
    required this.recoveryMetrics,
    required this.consistencyScore,
    required this.enduranceScore,
  });

  /// Pace analysis throughout the session
  final PaceAnalysis paceAnalysis;

  /// Heart rate zone distribution (if available)
  final HeartRateZones? heartRateZones;

  /// Estimated energy expenditure
  final EnergyExpenditure energyExpenditure;

  /// Recovery-related metrics
  final RecoveryMetrics recoveryMetrics;

  /// Consistency of performance (0-100)
  final double consistencyScore;

  /// Endurance performance score (0-100)
  final double enduranceScore;
}

/// Pace analysis data
@immutable
class PaceAnalysis {
  const PaceAnalysis({
    required this.averagePace,
    required this.bestPace,
    required this.worstPace,
    required this.paceVariability,
    required this.paceZones,
    required this.paceDistribution,
    required this.splitTimes,
  });

  /// Average pace (minutes per km)
  final double averagePace;

  /// Best pace achieved (minutes per km)
  final double bestPace;

  /// Worst pace recorded (minutes per km)
  final double worstPace;

  /// Pace variability coefficient
  final double paceVariability;

  /// Time spent in different pace zones
  final Map<PaceZone, Duration> paceZones;

  /// Distribution of pace throughout session
  final List<PaceDataPoint> paceDistribution;

  /// Split times for regular intervals
  final List<SplitTime> splitTimes;
}

/// Pace zones for analysis
enum PaceZone {
  recovery,
  easy,
  moderate,
  hard,
  maximum,
}

/// Individual pace data point
@immutable
class PaceDataPoint {
  const PaceDataPoint({
    required this.timestamp,
    required this.pace,
    required this.location,
    required this.elevation,
  });

  final DateTime timestamp;
  final double pace;
  final LatLng location;
  final double? elevation;
}

/// Split time data
@immutable
class SplitTime {
  const SplitTime({
    required this.distance,
    required this.time,
    required this.pace,
    required this.elevationGain,
    required this.elevationLoss,
  });

  final double distance; // km
  final Duration time;
  final double pace; // min/km
  final double elevationGain;
  final double elevationLoss;
}

/// Heart rate zone analysis
@immutable
class HeartRateZones {
  const HeartRateZones({
    required this.zone1Duration,
    required this.zone2Duration,
    required this.zone3Duration,
    required this.zone4Duration,
    required this.zone5Duration,
    required this.averageHeartRate,
    required this.maxHeartRate,
    required this.heartRateVariability,
  });

  final Duration zone1Duration; // Recovery
  final Duration zone2Duration; // Aerobic base
  final Duration zone3Duration; // Aerobic
  final Duration zone4Duration; // Threshold
  final Duration zone5Duration; // Anaerobic

  final double averageHeartRate;
  final double maxHeartRate;
  final double heartRateVariability;
}

/// Energy expenditure estimates
@immutable
class EnergyExpenditure {
  const EnergyExpenditure({
    required this.totalCalories,
    required this.caloriesPerKm,
    required this.caloriesPerHour,
    required this.fatCalories,
    required this.carbCalories,
    required this.metabolicEquivalent,
  });

  final double totalCalories;
  final double caloriesPerKm;
  final double caloriesPerHour;
  final double fatCalories;
  final double carbCalories;
  final double metabolicEquivalent; // METs
}

/// Recovery-related metrics
@immutable
class RecoveryMetrics {
  const RecoveryMetrics({
    required this.recoveryTime,
    required this.trainingLoad,
    required this.stressScore,
    required this.fatigueLevel,
    required this.recommendedRestDays,
  });

  final Duration recoveryTime;
  final double trainingLoad;
  final double stressScore;
  final double fatigueLevel; // 0-100
  final int recommendedRestDays;
}

/// Route and path analysis
@immutable
class RouteAnalysis {
  const RouteAnalysis({
    required this.routeType,
    required this.terrainAnalysis,
    required this.elevationProfile,
    required this.difficultyScore,
    required this.scenicScore,
    required this.technicalScore,
    required this.routeEfficiency,
    required this.landmarks,
  });

  /// Detected route type
  final RouteType routeType;

  /// Terrain analysis
  final TerrainAnalysis terrainAnalysis;

  /// Elevation profile data
  final ElevationProfile elevationProfile;

  /// Overall difficulty score (0-100)
  final double difficultyScore;

  /// Scenic value score (0-100)
  final double scenicScore;

  /// Technical difficulty score (0-100)
  final double technicalScore;

  /// Route efficiency score (0-100)
  final double routeEfficiency;

  /// Notable landmarks encountered
  final List<Landmark> landmarks;
}

/// Route type classification
enum RouteType {
  loop,
  outAndBack,
  pointToPoint,
  figure8,
  complex,
}

/// Terrain analysis data
@immutable
class TerrainAnalysis {
  const TerrainAnalysis({
    required this.surfaceTypes,
    required this.gradientDistribution,
    required this.technicalSections,
    required this.restAreas,
  });

  /// Distribution of surface types
  final Map<SurfaceType, double> surfaceTypes;

  /// Distribution of gradients
  final Map<GradientType, double> gradientDistribution;

  /// Technical or challenging sections
  final List<TechnicalSection> technicalSections;

  /// Identified rest areas
  final List<RestArea> restAreas;
}

/// Surface types
enum SurfaceType {
  trail,
  road,
  gravel,
  sand,
  rock,
  snow,
  mud,
  water,
}

/// Gradient types
enum GradientType {
  flat,
  gentle,
  moderate,
  steep,
  verysteep,
}

/// Technical section data
@immutable
class TechnicalSection {
  const TechnicalSection({
    required this.startLocation,
    required this.endLocation,
    required this.difficulty,
    required this.description,
    required this.duration,
  });

  final LatLng startLocation;
  final LatLng endLocation;
  final double difficulty; // 0-100
  final String description;
  final Duration duration;
}

/// Rest area data
@immutable
class RestArea {
  const RestArea({
    required this.location,
    required this.duration,
    required this.type,
    required this.facilities,
  });

  final LatLng location;
  final Duration duration;
  final RestAreaType type;
  final List<String> facilities;
}

/// Rest area types
enum RestAreaType {
  natural,
  shelter,
  viewpoint,
  waterSource,
  facility,
}

/// Elevation profile data
@immutable
class ElevationProfile {
  const ElevationProfile({
    required this.elevationPoints,
    required this.totalAscent,
    required this.totalDescent,
    required this.steepestAscent,
    required this.steepestDescent,
    required this.elevationGainRate,
    required this.elevationLossRate,
  });

  final List<ElevationPoint> elevationPoints;
  final double totalAscent;
  final double totalDescent;
  final double steepestAscent; // degrees
  final double steepestDescent; // degrees
  final double elevationGainRate; // m/km
  final double elevationLossRate; // m/km
}

/// Individual elevation point
@immutable
class ElevationPoint {
  const ElevationPoint({
    required this.distance,
    required this.elevation,
    required this.gradient,
    required this.location,
  });

  final double distance; // km from start
  final double elevation; // meters
  final double gradient; // percentage
  final LatLng location;
}

/// Landmark data
@immutable
class Landmark {
  const Landmark({
    required this.name,
    required this.location,
    required this.type,
    required this.description,
    required this.timestamp,
  });

  final String name;
  final LatLng location;
  final LandmarkType type;
  final String description;
  final DateTime timestamp;
}

/// Landmark types
enum LandmarkType {
  peak,
  lake,
  river,
  bridge,
  building,
  monument,
  viewpoint,
  intersection,
}

/// Environmental data during session
@immutable
class EnvironmentalData {
  const EnvironmentalData({
    required this.weatherConditions,
    required this.temperatureProfile,
    required this.humidityProfile,
    required this.windConditions,
    required this.lightConditions,
    required this.airQuality,
  });

  final WeatherConditions weatherConditions;
  final TemperatureProfile temperatureProfile;
  final HumidityProfile humidityProfile;
  final WindConditions windConditions;
  final LightConditions lightConditions;
  final AirQuality? airQuality;
}

/// Weather conditions
@immutable
class WeatherConditions {
  const WeatherConditions({
    required this.condition,
    required this.precipitation,
    required this.visibility,
    required this.pressure,
  });

  final WeatherCondition condition;
  final double precipitation; // mm
  final double visibility; // km
  final double pressure; // hPa
}

/// Weather condition types
enum WeatherCondition {
  clear,
  partlyCloudy,
  cloudy,
  overcast,
  rain,
  snow,
  fog,
  storm,
}

/// Temperature profile
@immutable
class TemperatureProfile {
  const TemperatureProfile({
    required this.averageTemperature,
    required this.minTemperature,
    required this.maxTemperature,
    required this.temperatureVariation,
    required this.heatIndex,
    required this.windChill,
  });

  final double averageTemperature; // Celsius
  final double minTemperature;
  final double maxTemperature;
  final double temperatureVariation;
  final double? heatIndex;
  final double? windChill;
}

/// Humidity profile
@immutable
class HumidityProfile {
  const HumidityProfile({
    required this.averageHumidity,
    required this.minHumidity,
    required this.maxHumidity,
    required this.dewPoint,
  });

  final double averageHumidity; // percentage
  final double minHumidity;
  final double maxHumidity;
  final double dewPoint; // Celsius
}

/// Wind conditions
@immutable
class WindConditions {
  const WindConditions({
    required this.averageSpeed,
    required this.maxSpeed,
    required this.direction,
    required this.gustiness,
  });

  final double averageSpeed; // km/h
  final double maxSpeed;
  final double direction; // degrees
  final double gustiness; // 0-100
}

/// Light conditions
@immutable
class LightConditions {
  const LightConditions({
    required this.sunrise,
    required this.sunset,
    required this.daylight,
    required this.uvIndex,
    required this.lightLevel,
  });

  final DateTime? sunrise;
  final DateTime? sunset;
  final Duration daylight;
  final double uvIndex;
  final LightLevel lightLevel;
}

/// Light level categories
enum LightLevel {
  dark,
  twilight,
  overcast,
  bright,
  veryBright,
}

/// Air quality data
@immutable
class AirQuality {
  const AirQuality({
    required this.aqi,
    required this.pm25,
    required this.pm10,
    required this.ozone,
    required this.no2,
    required this.so2,
  });

  final int aqi; // Air Quality Index
  final double pm25; // μg/m³
  final double pm10; // μg/m³
  final double ozone; // μg/m³
  final double no2; // μg/m³
  final double so2; // μg/m³
}

/// Efficiency metrics
@immutable
class EfficiencyMetrics {
  const EfficiencyMetrics({
    required this.energyEfficiency,
    required this.timeEfficiency,
    required this.routeEfficiency,
    required this.paceEfficiency,
    required this.optimizationSuggestions,
  });

  final double energyEfficiency; // 0-100
  final double timeEfficiency; // 0-100
  final double routeEfficiency; // 0-100
  final double paceEfficiency; // 0-100
  final List<OptimizationSuggestion> optimizationSuggestions;
}

/// Optimization suggestion
@immutable
class OptimizationSuggestion {
  const OptimizationSuggestion({
    required this.category,
    required this.suggestion,
    required this.impact,
    required this.difficulty,
  });

  final OptimizationCategory category;
  final String suggestion;
  final double impact; // 0-100
  final double difficulty; // 0-100
}

/// Optimization categories
enum OptimizationCategory {
  pacing,
  route,
  equipment,
  nutrition,
  hydration,
  rest,
  technique,
}

/// Session comparison data
@immutable
class SessionComparisonData {
  const SessionComparisonData({
    required this.personalBests,
    required this.averageComparison,
    required this.trendAnalysis,
    required this.rankingData,
  });

  final List<PersonalBest> personalBests;
  final AverageComparison averageComparison;
  final TrendAnalysis trendAnalysis;
  final RankingData rankingData;
}

/// Personal best achievement
@immutable
class PersonalBest {
  const PersonalBest({
    required this.metric,
    required this.value,
    required this.previousBest,
    required this.improvement,
    required this.achievedAt,
  });

  final String metric;
  final double value;
  final double? previousBest;
  final double improvement;
  final DateTime achievedAt;
}

/// Comparison with personal averages
@immutable
class AverageComparison {
  const AverageComparison({
    required this.distanceComparison,
    required this.timeComparison,
    required this.paceComparison,
    required this.elevationComparison,
    required this.overallPerformance,
  });

  final double distanceComparison; // percentage vs average
  final double timeComparison;
  final double paceComparison;
  final double elevationComparison;
  final double overallPerformance; // 0-100
}

/// Trend analysis
@immutable
class TrendAnalysis {
  const TrendAnalysis({
    required this.fitnessProgress,
    required this.performanceTrend,
    required this.consistencyTrend,
    required this.projectedGoals,
  });

  final double fitnessProgress; // percentage change
  final PerformanceTrend performanceTrend;
  final double consistencyTrend; // percentage change
  final List<ProjectedGoal> projectedGoals;
}

/// Performance trend direction
enum PerformanceTrend {
  improving,
  stable,
  declining,
  fluctuating,
}

/// Projected goal achievement
@immutable
class ProjectedGoal {
  const ProjectedGoal({
    required this.goal,
    required this.currentProgress,
    required this.projectedCompletion,
    required this.confidence,
  });

  final String goal;
  final double currentProgress; // percentage
  final DateTime projectedCompletion;
  final double confidence; // 0-100
}

/// Ranking data
@immutable
class RankingData {
  const RankingData({
    required this.personalRanking,
    required this.categoryRanking,
    required this.percentile,
    required this.competitiveLevel,
  });

  final int personalRanking; // among user's sessions
  final int categoryRanking; // among similar sessions
  final double percentile; // 0-100
  final CompetitiveLevel competitiveLevel;
}

/// Competitive level classification
enum CompetitiveLevel {
  beginner,
  recreational,
  intermediate,
  advanced,
  elite,
}

/// AI-generated insight
@immutable
class SessionInsight {
  const SessionInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.importance,
    required this.actionable,
    required this.category,
  });

  final InsightType type;
  final String title;
  final String description;
  final double importance; // 0-100
  final bool actionable;
  final InsightCategory category;
}

/// Insight types
enum InsightType {
  achievement,
  improvement,
  warning,
  recommendation,
  observation,
}

/// Insight categories
enum InsightCategory {
  performance,
  health,
  safety,
  efficiency,
  motivation,
  technique,
}
