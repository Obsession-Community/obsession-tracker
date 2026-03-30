// Astronomical Data Models for Sun/Moon Times Feature
// 100% offline calculations using Meeus algorithms - no external API calls

import 'package:flutter/foundation.dart';

/// Moon phase enumeration with display properties
enum MoonPhase {
  newMoon('New Moon', '🌑'),
  waxingCrescent('Waxing Crescent', '🌒'),
  firstQuarter('First Quarter', '🌓'),
  waxingGibbous('Waxing Gibbous', '🌔'),
  fullMoon('Full Moon', '🌕'),
  waningGibbous('Waning Gibbous', '🌖'),
  lastQuarter('Last Quarter', '🌗'),
  waningCrescent('Waning Crescent', '🌘');

  const MoonPhase(this.displayName, this.emoji);

  final String displayName;
  final String emoji;
}

/// Complete astronomical data for a location and date
/// All times are in local timezone
@immutable
class AstronomicalData {
  const AstronomicalData({
    required this.calculatedAt,
    required this.latitude,
    required this.longitude,
    required this.date,
    // Solar times (nullable for polar regions where sun doesn't rise/set)
    this.sunrise,
    this.sunset,
    this.solarNoon,
    // Civil twilight (sun 6 degrees below horizon)
    this.civilTwilightStart,
    this.civilTwilightEnd,
    // Golden hour (sun 0-6 degrees above horizon)
    this.goldenHourMorningStart,
    this.goldenHourMorningEnd,
    this.goldenHourEveningStart,
    this.goldenHourEveningEnd,
    // Blue hour (sun 4-6 degrees below horizon)
    this.blueHourMorningStart,
    this.blueHourMorningEnd,
    this.blueHourEveningStart,
    this.blueHourEveningEnd,
    // Lunar data
    this.moonrise,
    this.moonset,
    required this.moonPhase,
    required this.moonIllumination,
    // Derived
    required this.dayLength,
  });

  factory AstronomicalData.fromJson(Map<String, dynamic> json) =>
      AstronomicalData(
        calculatedAt: DateTime.parse(json['calculatedAt'] as String),
        latitude: json['latitude'] as double,
        longitude: json['longitude'] as double,
        date: DateTime.parse(json['date'] as String),
        sunrise: json['sunrise'] != null
            ? DateTime.parse(json['sunrise'] as String)
            : null,
        sunset: json['sunset'] != null
            ? DateTime.parse(json['sunset'] as String)
            : null,
        solarNoon: json['solarNoon'] != null
            ? DateTime.parse(json['solarNoon'] as String)
            : null,
        civilTwilightStart: json['civilTwilightStart'] != null
            ? DateTime.parse(json['civilTwilightStart'] as String)
            : null,
        civilTwilightEnd: json['civilTwilightEnd'] != null
            ? DateTime.parse(json['civilTwilightEnd'] as String)
            : null,
        goldenHourMorningStart: json['goldenHourMorningStart'] != null
            ? DateTime.parse(json['goldenHourMorningStart'] as String)
            : null,
        goldenHourMorningEnd: json['goldenHourMorningEnd'] != null
            ? DateTime.parse(json['goldenHourMorningEnd'] as String)
            : null,
        goldenHourEveningStart: json['goldenHourEveningStart'] != null
            ? DateTime.parse(json['goldenHourEveningStart'] as String)
            : null,
        goldenHourEveningEnd: json['goldenHourEveningEnd'] != null
            ? DateTime.parse(json['goldenHourEveningEnd'] as String)
            : null,
        blueHourMorningStart: json['blueHourMorningStart'] != null
            ? DateTime.parse(json['blueHourMorningStart'] as String)
            : null,
        blueHourMorningEnd: json['blueHourMorningEnd'] != null
            ? DateTime.parse(json['blueHourMorningEnd'] as String)
            : null,
        blueHourEveningStart: json['blueHourEveningStart'] != null
            ? DateTime.parse(json['blueHourEveningStart'] as String)
            : null,
        blueHourEveningEnd: json['blueHourEveningEnd'] != null
            ? DateTime.parse(json['blueHourEveningEnd'] as String)
            : null,
        moonrise: json['moonrise'] != null
            ? DateTime.parse(json['moonrise'] as String)
            : null,
        moonset: json['moonset'] != null
            ? DateTime.parse(json['moonset'] as String)
            : null,
        moonPhase: MoonPhase.values[json['moonPhase'] as int],
        moonIllumination: json['moonIllumination'] as double,
        dayLength: Duration(seconds: json['dayLengthSeconds'] as int),
      );

  final DateTime calculatedAt;
  final double latitude;
  final double longitude;
  final DateTime date;

  // Solar times
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? solarNoon;

  // Twilight times
  final DateTime? civilTwilightStart;
  final DateTime? civilTwilightEnd;

  // Photography windows
  final DateTime? goldenHourMorningStart;
  final DateTime? goldenHourMorningEnd;
  final DateTime? goldenHourEveningStart;
  final DateTime? goldenHourEveningEnd;
  final DateTime? blueHourMorningStart;
  final DateTime? blueHourMorningEnd;
  final DateTime? blueHourEveningStart;
  final DateTime? blueHourEveningEnd;

  // Lunar data
  final DateTime? moonrise;
  final DateTime? moonset;
  final MoonPhase moonPhase;
  final double moonIllumination; // 0-100 percentage

  // Derived
  final Duration dayLength;

  /// Returns the next sun event (sunrise or sunset) from now
  DateTime? get nextSunEvent {
    final now = DateTime.now();
    if (sunrise != null && sunrise!.isAfter(now)) {
      return sunrise;
    }
    if (sunset != null && sunset!.isAfter(now)) {
      return sunset;
    }
    return null;
  }

  /// Returns true if the next sun event is sunrise
  bool get isNextEventSunrise {
    final now = DateTime.now();
    if (sunrise != null && sunrise!.isAfter(now)) {
      if (sunset != null && sunset!.isAfter(now)) {
        return sunrise!.isBefore(sunset!);
      }
      return true;
    }
    return false;
  }

  /// Returns the time until the next sun event
  Duration? get timeUntilNextSunEvent {
    final next = nextSunEvent;
    if (next == null) return null;
    return next.difference(DateTime.now());
  }

  /// Returns true if currently in morning golden hour
  bool get isGoldenHourMorning {
    if (goldenHourMorningStart == null || goldenHourMorningEnd == null) {
      return false;
    }
    final now = DateTime.now();
    return now.isAfter(goldenHourMorningStart!) &&
        now.isBefore(goldenHourMorningEnd!);
  }

  /// Returns true if currently in evening golden hour
  bool get isGoldenHourEvening {
    if (goldenHourEveningStart == null || goldenHourEveningEnd == null) {
      return false;
    }
    final now = DateTime.now();
    return now.isAfter(goldenHourEveningStart!) &&
        now.isBefore(goldenHourEveningEnd!);
  }

  /// Returns true if currently in any golden hour
  bool get isGoldenHour => isGoldenHourMorning || isGoldenHourEvening;

  /// Returns true if currently in morning blue hour
  bool get isBlueHourMorning {
    if (blueHourMorningStart == null || blueHourMorningEnd == null) {
      return false;
    }
    final now = DateTime.now();
    return now.isAfter(blueHourMorningStart!) &&
        now.isBefore(blueHourMorningEnd!);
  }

  /// Returns true if currently in evening blue hour
  bool get isBlueHourEvening {
    if (blueHourEveningStart == null || blueHourEveningEnd == null) {
      return false;
    }
    final now = DateTime.now();
    return now.isAfter(blueHourEveningStart!) &&
        now.isBefore(blueHourEveningEnd!);
  }

  /// Returns true if currently in any blue hour
  bool get isBlueHour => isBlueHourMorning || isBlueHourEvening;

  /// Returns true if it's currently daytime (between sunrise and sunset)
  bool get isDaytime {
    if (sunrise == null || sunset == null) {
      // Polar region edge case - check if it's perpetual day or night
      return dayLength.inHours > 12;
    }
    final now = DateTime.now();
    return now.isAfter(sunrise!) && now.isBefore(sunset!);
  }

  /// Returns formatted day length string (e.g., "10h 30m")
  String get dayLengthFormatted {
    final hours = dayLength.inHours;
    final minutes = dayLength.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  Map<String, dynamic> toJson() => {
        'calculatedAt': calculatedAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'date': date.toIso8601String(),
        'sunrise': sunrise?.toIso8601String(),
        'sunset': sunset?.toIso8601String(),
        'solarNoon': solarNoon?.toIso8601String(),
        'civilTwilightStart': civilTwilightStart?.toIso8601String(),
        'civilTwilightEnd': civilTwilightEnd?.toIso8601String(),
        'goldenHourMorningStart': goldenHourMorningStart?.toIso8601String(),
        'goldenHourMorningEnd': goldenHourMorningEnd?.toIso8601String(),
        'goldenHourEveningStart': goldenHourEveningStart?.toIso8601String(),
        'goldenHourEveningEnd': goldenHourEveningEnd?.toIso8601String(),
        'blueHourMorningStart': blueHourMorningStart?.toIso8601String(),
        'blueHourMorningEnd': blueHourMorningEnd?.toIso8601String(),
        'blueHourEveningStart': blueHourEveningStart?.toIso8601String(),
        'blueHourEveningEnd': blueHourEveningEnd?.toIso8601String(),
        'moonrise': moonrise?.toIso8601String(),
        'moonset': moonset?.toIso8601String(),
        'moonPhase': moonPhase.index,
        'moonIllumination': moonIllumination,
        'dayLengthSeconds': dayLength.inSeconds,
      };

  AstronomicalData copyWith({
    DateTime? calculatedAt,
    double? latitude,
    double? longitude,
    DateTime? date,
    DateTime? sunrise,
    DateTime? sunset,
    DateTime? solarNoon,
    DateTime? civilTwilightStart,
    DateTime? civilTwilightEnd,
    DateTime? goldenHourMorningStart,
    DateTime? goldenHourMorningEnd,
    DateTime? goldenHourEveningStart,
    DateTime? goldenHourEveningEnd,
    DateTime? blueHourMorningStart,
    DateTime? blueHourMorningEnd,
    DateTime? blueHourEveningStart,
    DateTime? blueHourEveningEnd,
    DateTime? moonrise,
    DateTime? moonset,
    MoonPhase? moonPhase,
    double? moonIllumination,
    Duration? dayLength,
  }) =>
      AstronomicalData(
        calculatedAt: calculatedAt ?? this.calculatedAt,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        date: date ?? this.date,
        sunrise: sunrise ?? this.sunrise,
        sunset: sunset ?? this.sunset,
        solarNoon: solarNoon ?? this.solarNoon,
        civilTwilightStart: civilTwilightStart ?? this.civilTwilightStart,
        civilTwilightEnd: civilTwilightEnd ?? this.civilTwilightEnd,
        goldenHourMorningStart:
            goldenHourMorningStart ?? this.goldenHourMorningStart,
        goldenHourMorningEnd: goldenHourMorningEnd ?? this.goldenHourMorningEnd,
        goldenHourEveningStart:
            goldenHourEveningStart ?? this.goldenHourEveningStart,
        goldenHourEveningEnd: goldenHourEveningEnd ?? this.goldenHourEveningEnd,
        blueHourMorningStart: blueHourMorningStart ?? this.blueHourMorningStart,
        blueHourMorningEnd: blueHourMorningEnd ?? this.blueHourMorningEnd,
        blueHourEveningStart: blueHourEveningStart ?? this.blueHourEveningStart,
        blueHourEveningEnd: blueHourEveningEnd ?? this.blueHourEveningEnd,
        moonrise: moonrise ?? this.moonrise,
        moonset: moonset ?? this.moonset,
        moonPhase: moonPhase ?? this.moonPhase,
        moonIllumination: moonIllumination ?? this.moonIllumination,
        dayLength: dayLength ?? this.dayLength,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AstronomicalData &&
          runtimeType == other.runtimeType &&
          calculatedAt == other.calculatedAt &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          date == other.date &&
          sunrise == other.sunrise &&
          sunset == other.sunset &&
          moonPhase == other.moonPhase &&
          moonIllumination == other.moonIllumination;

  @override
  int get hashCode => Object.hash(
        calculatedAt,
        latitude,
        longitude,
        date,
        sunrise,
        sunset,
        moonPhase,
        moonIllumination,
      );

  @override
  String toString() =>
      'AstronomicalData(date: $date, sunrise: $sunrise, sunset: $sunset, '
      'moonPhase: ${moonPhase.displayName}, illumination: ${moonIllumination.toStringAsFixed(0)}%)';
}
