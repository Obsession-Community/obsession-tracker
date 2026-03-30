// Astronomical Calculation Service for Sun/Moon Times Feature
// 100% offline calculations using Jean Meeus algorithms
// Reference: "Astronomical Algorithms" 2nd Edition (public domain formulas)

import 'dart:math' as math;

import 'package:obsession_tracker/core/models/astronomical_data.dart';

/// Singleton service for calculating astronomical data (sunrise, sunset, moon phase, etc.)
/// All calculations are performed locally - no external API calls required.
class AstronomicalService {
  factory AstronomicalService() => _instance;
  AstronomicalService._internal();
  static final _instance = AstronomicalService._internal();

  /// Calculate complete astronomical data for a location and date
  ///
  /// [latitude] - Latitude in decimal degrees (-90 to 90)
  /// [longitude] - Longitude in decimal degrees (-180 to 180)
  /// [date] - Date to calculate for (defaults to today)
  AstronomicalData calculate({
    required double latitude,
    required double longitude,
    DateTime? date,
  }) {
    final targetDate = date ?? DateTime.now();
    final jd = _toJulianDay(targetDate);

    // Calculate solar times
    final solarTimes = _calculateSolarTimes(jd, latitude, longitude, targetDate);

    // Calculate moon data
    final moonPhaseData = _calculateMoonPhase(jd);
    final moonrise = _calculateMoonRiseSet(jd, latitude, longitude, true, targetDate);
    final moonset = _calculateMoonRiseSet(jd, latitude, longitude, false, targetDate);

    // Calculate day length
    final dayLength = solarTimes.sunrise != null && solarTimes.sunset != null
        ? solarTimes.sunset!.difference(solarTimes.sunrise!)
        : Duration.zero;

    return AstronomicalData(
      calculatedAt: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      date: targetDate,
      sunrise: solarTimes.sunrise,
      sunset: solarTimes.sunset,
      solarNoon: solarTimes.solarNoon,
      civilTwilightStart: solarTimes.civilTwilightStart,
      civilTwilightEnd: solarTimes.civilTwilightEnd,
      goldenHourMorningStart: solarTimes.goldenHourMorningStart,
      goldenHourMorningEnd: solarTimes.goldenHourMorningEnd,
      goldenHourEveningStart: solarTimes.goldenHourEveningStart,
      goldenHourEveningEnd: solarTimes.goldenHourEveningEnd,
      blueHourMorningStart: solarTimes.blueHourMorningStart,
      blueHourMorningEnd: solarTimes.blueHourMorningEnd,
      blueHourEveningStart: solarTimes.blueHourEveningStart,
      blueHourEveningEnd: solarTimes.blueHourEveningEnd,
      moonrise: moonrise,
      moonset: moonset,
      moonPhase: moonPhaseData.phase,
      moonIllumination: moonPhaseData.illumination,
      dayLength: dayLength,
    );
  }

  // ============================================================
  // Julian Day Calculations
  // ============================================================

  /// Convert a DateTime to Julian Day number
  /// Reference: Meeus, Chapter 7
  double _toJulianDay(DateTime date) {
    int y = date.year;
    int m = date.month;
    final double d = date.day +
        date.hour / 24.0 +
        date.minute / 1440.0 +
        date.second / 86400.0;

    if (m <= 2) {
      y -= 1;
      m += 12;
    }

    final int a = y ~/ 100;
    final int b = 2 - a + (a ~/ 4);

    return (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        d +
        b -
        1524.5;
  }

  // ============================================================
  // Solar Position Calculations
  // ============================================================

  /// Calculate solar times for a given Julian Day and location
  _SolarTimes _calculateSolarTimes(
    double jd,
    double latitude,
    double longitude,
    DateTime referenceDate,
  ) {
    // Julian centuries from J2000.0
    final t = (jd - 2451545.0) / 36525.0;

    // Solar mean longitude (degrees)
    final l0 = _normalizeAngle(280.46646 + 36000.76983 * t + 0.0003032 * t * t);

    // Solar mean anomaly (degrees)
    final m = _normalizeAngle(357.52911 + 35999.05029 * t - 0.0001537 * t * t);
    final mRad = _toRadians(m);

    // Equation of center
    final c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(mRad) +
        (0.019993 - 0.000101 * t) * math.sin(2 * mRad) +
        0.000289 * math.sin(3 * mRad);

    // Sun's true longitude
    final sunLong = l0 + c;

    // Obliquity of the ecliptic
    final obliquity = 23.439291 - 0.013004 * t;
    final obliquityRad = _toRadians(obliquity);

    // Sun's declination (right ascension not needed for rise/set calculations)
    final sunLongRad = _toRadians(sunLong);
    final declination = math.asin(
      math.sin(obliquityRad) * math.sin(sunLongRad),
    );

    // Equation of time (minutes)
    final y = math.tan(obliquityRad / 2) * math.tan(obliquityRad / 2);
    final eqTime = 4 *
        _toDegrees(
          y * math.sin(2 * _toRadians(l0)) -
              2 * 0.016708634 * math.sin(mRad) +
              4 * 0.016708634 * y * math.sin(mRad) * math.cos(2 * _toRadians(l0)) -
              0.5 * y * y * math.sin(4 * _toRadians(l0)) -
              1.25 * 0.016708634 * 0.016708634 * math.sin(2 * mRad),
        );

    // Solar noon (in minutes from midnight)
    final solarNoonMinutes = 720 - 4 * longitude - eqTime;

    // Calculate hour angle for different altitudes
    final latRad = _toRadians(latitude);

    // Helper function to calculate time for a given sun altitude
    DateTime? calculateTimeForAltitude(double altitude, bool isMorning) {
      final altRad = _toRadians(altitude);
      final cosHourAngle = (math.sin(altRad) - math.sin(latRad) * math.sin(declination)) /
          (math.cos(latRad) * math.cos(declination));

      // Check if sun reaches this altitude at this latitude
      if (cosHourAngle < -1 || cosHourAngle > 1) {
        return null; // Perpetual day or night
      }

      final hourAngle = _toDegrees(math.acos(cosHourAngle));
      final timeMinutes = isMorning
          ? solarNoonMinutes - hourAngle * 4
          : solarNoonMinutes + hourAngle * 4;

      return _minutesToDateTime(timeMinutes, referenceDate);
    }

    // Standard sunrise/sunset altitude: -0.833° (accounting for refraction)
    final sunrise = calculateTimeForAltitude(-0.833, true);
    final sunset = calculateTimeForAltitude(-0.833, false);

    // Civil twilight: sun at -6°
    final civilTwilightStart = calculateTimeForAltitude(-6.0, true);
    final civilTwilightEnd = calculateTimeForAltitude(-6.0, false);

    // Golden hour: sun between 0° and 6° above horizon
    // Morning: from sunrise until sun reaches 6°
    // Evening: from sun at 6° until sunset
    final goldenHourMorningStart = sunrise;
    final goldenHourMorningEnd = calculateTimeForAltitude(6.0, true);
    final goldenHourEveningStart = calculateTimeForAltitude(6.0, false);
    final goldenHourEveningEnd = sunset;

    // Blue hour: sun between -4° and -6° below horizon
    // Morning: from -6° to -4°
    // Evening: from -4° to -6°
    final blueHourMorningStart = civilTwilightStart;
    final blueHourMorningEnd = calculateTimeForAltitude(-4.0, true);
    final blueHourEveningStart = calculateTimeForAltitude(-4.0, false);
    final blueHourEveningEnd = civilTwilightEnd;

    return _SolarTimes(
      sunrise: sunrise,
      sunset: sunset,
      solarNoon: _minutesToDateTime(solarNoonMinutes, referenceDate),
      civilTwilightStart: civilTwilightStart,
      civilTwilightEnd: civilTwilightEnd,
      goldenHourMorningStart: goldenHourMorningStart,
      goldenHourMorningEnd: goldenHourMorningEnd,
      goldenHourEveningStart: goldenHourEveningStart,
      goldenHourEveningEnd: goldenHourEveningEnd,
      blueHourMorningStart: blueHourMorningStart,
      blueHourMorningEnd: blueHourMorningEnd,
      blueHourEveningStart: blueHourEveningStart,
      blueHourEveningEnd: blueHourEveningEnd,
    );
  }

  /// Convert minutes from midnight to DateTime
  DateTime? _minutesToDateTime(double minutes, DateTime referenceDate) {
    if (minutes < 0 || minutes >= 1440) {
      return null;
    }
    final hours = minutes ~/ 60;
    final mins = (minutes % 60).floor();
    final secs = ((minutes % 1) * 60).round();

    return DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
      hours,
      mins,
      secs,
    );
  }

  // ============================================================
  // Moon Phase Calculations
  // ============================================================

  /// Calculate moon phase and illumination
  /// Reference: Meeus, Chapter 49
  _MoonPhaseData _calculateMoonPhase(double jd) {
    // Days since J2000.0
    final d = jd - 2451545.0;

    // Sun's mean longitude
    final sunMeanLong = _normalizeAngle(280.4606184 + 0.9856473662862 * d);

    // Moon's mean longitude
    final moonMeanLong = _normalizeAngle(218.32 + 13.176396 * d);

    // Moon's mean anomaly
    final moonMeanAnomaly = _normalizeAngle(134.963 + 13.064993 * d);

    // Moon's argument of latitude
    final moonArgLat = _normalizeAngle(93.272 + 13.229350 * d);

    // Moon's mean elongation from sun
    final moonElongation = _normalizeAngle(297.8502042 + 12.19074912 * d);

    // Simplified lunar longitude
    final moonLong = moonMeanLong +
        6.289 * math.sin(_toRadians(moonMeanAnomaly)) +
        1.274 * math.sin(_toRadians(2 * moonElongation - moonMeanAnomaly)) +
        0.658 * math.sin(_toRadians(2 * moonElongation)) +
        0.214 * math.sin(_toRadians(2 * moonMeanAnomaly)) -
        0.186 * math.sin(_toRadians(moonMeanAnomaly - 2 * moonArgLat));

    // Phase angle (difference in ecliptic longitude between moon and sun)
    final phase = _normalizeAngle(moonLong - sunMeanLong);

    // Illumination fraction (0-100%)
    // Using simplified formula: illumination = (1 - cos(phase)) / 2
    final illumination = ((1 - math.cos(_toRadians(phase))) / 2) * 100;

    // Determine moon phase from phase angle
    MoonPhase moonPhase;
    if (phase < 22.5 || phase >= 337.5) {
      moonPhase = MoonPhase.newMoon;
    } else if (phase < 67.5) {
      moonPhase = MoonPhase.waxingCrescent;
    } else if (phase < 112.5) {
      moonPhase = MoonPhase.firstQuarter;
    } else if (phase < 157.5) {
      moonPhase = MoonPhase.waxingGibbous;
    } else if (phase < 202.5) {
      moonPhase = MoonPhase.fullMoon;
    } else if (phase < 247.5) {
      moonPhase = MoonPhase.waningGibbous;
    } else if (phase < 292.5) {
      moonPhase = MoonPhase.lastQuarter;
    } else {
      moonPhase = MoonPhase.waningCrescent;
    }

    return _MoonPhaseData(
      phase: moonPhase,
      illumination: illumination,
      phaseAngle: phase,
    );
  }

  // ============================================================
  // Moon Rise/Set Calculations
  // ============================================================

  /// Calculate moonrise or moonset time
  /// Reference: Meeus, Chapter 15 (simplified approach)
  DateTime? _calculateMoonRiseSet(
    double jd,
    double latitude,
    double longitude,
    bool isRise,
    DateTime referenceDate,
  ) {
    // Simplified moonrise/moonset calculation
    // Uses an iterative approach to find when moon crosses the horizon

    final latRad = _toRadians(latitude);

    // Moon's parallax and semi-diameter affect apparent altitude
    // Standard moon rise/set altitude: +0.125° (includes parallax and refraction)
    const moonAltitude = 0.125;
    final altRad = _toRadians(moonAltitude);

    // Calculate moon's position at noon
    final moonPos = _getMoonPosition(jd, latitude, longitude);

    // Calculate hour angle
    final cosHourAngle = (math.sin(altRad) - math.sin(latRad) * math.sin(moonPos.declinationRad)) /
        (math.cos(latRad) * math.cos(moonPos.declinationRad));

    if (cosHourAngle < -1 || cosHourAngle > 1) {
      return null; // Moon doesn't rise or set on this day
    }

    final hourAngle = _toDegrees(math.acos(cosHourAngle));

    // Convert to time
    // Moon moves about 12.2° per day relative to the sun
    // This affects the rise/set times
    final transitTime = 12.0 + (moonPos.rightAscensionHours - _getSiderealTime(jd, longitude));
    final normalizedTransit = _normalizeHours(transitTime);

    double eventTime;
    if (isRise) {
      eventTime = normalizedTransit - hourAngle / 15.0;
    } else {
      eventTime = normalizedTransit + hourAngle / 15.0;
    }

    eventTime = _normalizeHours(eventTime);

    // Convert to DateTime
    final hours = eventTime.floor();
    final minutes = ((eventTime - hours) * 60).floor();
    final seconds = (((eventTime - hours) * 60 - minutes) * 60).round();

    // Check if the time falls on the next day
    if (eventTime < 0) {
      return null; // Event is on previous day
    }

    return DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
      hours,
      minutes,
      seconds,
    );
  }

  /// Get moon's position (simplified)
  _MoonPosition _getMoonPosition(double jd, double latitude, double longitude) {
    final d = jd - 2451545.0;
    final t = d / 36525.0;

    // Moon's mean longitude
    final l = _normalizeAngle(218.3164477 + 481267.88123421 * t);

    // Moon's mean anomaly
    final m = _normalizeAngle(134.9633964 + 477198.8675055 * t);

    // Moon's argument of latitude
    final f = _normalizeAngle(93.2720950 + 483202.0175233 * t);

    // Moon's mean elongation
    final moonD = _normalizeAngle(297.8501921 + 445267.1114034 * t);

    // Ecliptic longitude
    final moonLong = l +
        6.288774 * math.sin(_toRadians(m)) +
        1.274027 * math.sin(_toRadians(2 * moonD - m)) +
        0.658314 * math.sin(_toRadians(2 * moonD));

    // Ecliptic latitude
    final moonLat = 5.128122 * math.sin(_toRadians(f));

    // Obliquity
    final obliquity = 23.439291 - 0.0130042 * t;
    final obliquityRad = _toRadians(obliquity);

    // Convert to equatorial coordinates
    final moonLongRad = _toRadians(moonLong);
    final moonLatRad = _toRadians(moonLat);

    final rightAscension = math.atan2(
      math.sin(moonLongRad) * math.cos(obliquityRad) -
          math.tan(moonLatRad) * math.sin(obliquityRad),
      math.cos(moonLongRad),
    );

    final declination = math.asin(
      math.sin(moonLatRad) * math.cos(obliquityRad) +
          math.cos(moonLatRad) * math.sin(obliquityRad) * math.sin(moonLongRad),
    );

    return _MoonPosition(
      rightAscensionHours: _toDegrees(rightAscension) / 15.0,
      declinationRad: declination,
    );
  }

  /// Calculate local sidereal time
  double _getSiderealTime(double jd, double longitude) {
    final t = (jd - 2451545.0) / 36525.0;
    var theta = 280.46061837 +
        360.98564736629 * (jd - 2451545.0) +
        0.000387933 * t * t -
        t * t * t / 38710000.0;
    theta = _normalizeAngle(theta);
    return (theta + longitude) / 15.0;
  }

  // ============================================================
  // Utility Functions
  // ============================================================

  /// Convert degrees to radians
  double _toRadians(double degrees) => degrees * math.pi / 180.0;

  /// Convert radians to degrees
  double _toDegrees(double radians) => radians * 180.0 / math.pi;

  /// Normalize angle to 0-360 range
  double _normalizeAngle(double angle) {
    var result = angle % 360.0;
    if (result < 0) result += 360.0;
    return result;
  }

  /// Normalize hours to 0-24 range
  double _normalizeHours(double hours) {
    var result = hours % 24.0;
    if (result < 0) result += 24.0;
    return result;
  }
}

// ============================================================
// Internal Data Classes
// ============================================================

/// Internal class for solar time calculations
class _SolarTimes {
  const _SolarTimes({
    this.sunrise,
    this.sunset,
    this.solarNoon,
    this.civilTwilightStart,
    this.civilTwilightEnd,
    this.goldenHourMorningStart,
    this.goldenHourMorningEnd,
    this.goldenHourEveningStart,
    this.goldenHourEveningEnd,
    this.blueHourMorningStart,
    this.blueHourMorningEnd,
    this.blueHourEveningStart,
    this.blueHourEveningEnd,
  });

  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? solarNoon;
  final DateTime? civilTwilightStart;
  final DateTime? civilTwilightEnd;
  final DateTime? goldenHourMorningStart;
  final DateTime? goldenHourMorningEnd;
  final DateTime? goldenHourEveningStart;
  final DateTime? goldenHourEveningEnd;
  final DateTime? blueHourMorningStart;
  final DateTime? blueHourMorningEnd;
  final DateTime? blueHourEveningStart;
  final DateTime? blueHourEveningEnd;
}

/// Internal class for moon phase calculations
class _MoonPhaseData {
  const _MoonPhaseData({
    required this.phase,
    required this.illumination,
    required this.phaseAngle,
  });

  final MoonPhase phase;
  final double illumination;
  final double phaseAngle;
}

/// Internal class for moon position
class _MoonPosition {
  const _MoonPosition({
    required this.rightAscensionHours,
    required this.declinationRad,
  });

  final double rightAscensionHours;
  final double declinationRad;
}
