// Weather Service Models for Milestone 10
// Supports weather data integration for enhanced tracking context

import 'package:flutter/foundation.dart';

/// Weather condition types
enum WeatherCondition {
  clear,
  partlyCloudy,
  cloudy,
  overcast,
  mist,
  fog,
  drizzle,
  lightRain,
  rain,
  heavyRain,
  thunderstorm,
  lightSnow,
  snow,
  heavySnow,
  sleet,
  hail,
  windy,
  tornado,
  hurricane,
  unknown,
}

/// Wind direction
enum WindDirection {
  north,
  northEast,
  east,
  southEast,
  south,
  southWest,
  west,
  northWest,
  variable,
  calm,
}

/// Weather data source
enum WeatherDataSource {
  openWeatherMap,
  weatherApi,
  nationalWeatherService,
  metOffice,
  darkSky,
  accuWeather,
  weatherUnderground,
  localSensor,
  userInput,
}

/// Current weather conditions
@immutable
class WeatherData {
  const WeatherData({
    required this.timestamp,
    required this.location,
    required this.condition,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.pressure,
    required this.windSpeed,
    required this.windDirection,
    required this.windGust,
    required this.visibility,
    required this.uvIndex,
    required this.cloudCover,
    required this.dewPoint,
    required this.precipitationProbability,
    required this.precipitationAmount,
    required this.description,
    required this.source,
    required this.accuracy,
  }); // Confidence 0-1

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        timestamp: DateTime.parse(json['timestamp'] as String),
        location:
            WeatherLocation.fromJson(json['location'] as Map<String, dynamic>),
        condition: WeatherCondition.values[json['condition'] as int],
        temperature: json['temperature'] as double,
        feelsLike: json['feelsLike'] as double?,
        humidity: json['humidity'] as double,
        pressure: json['pressure'] as double,
        windSpeed: json['windSpeed'] as double,
        windDirection: WindDirection.values[json['windDirection'] as int],
        windGust: json['windGust'] as double?,
        visibility: json['visibility'] as double?,
        uvIndex: json['uvIndex'] as double?,
        cloudCover: json['cloudCover'] as double,
        dewPoint: json['dewPoint'] as double?,
        precipitationProbability: json['precipitationProbability'] as double,
        precipitationAmount: json['precipitationAmount'] as double,
        description: json['description'] as String,
        source: WeatherDataSource.values[json['source'] as int],
        accuracy: json['accuracy'] as double,
      );

  final DateTime timestamp;
  final WeatherLocation location;
  final WeatherCondition condition;
  final double temperature; // Celsius
  final double? feelsLike; // Celsius
  final double humidity; // Percentage 0-100
  final double pressure; // hPa
  final double windSpeed; // m/s
  final WindDirection windDirection;
  final double? windGust; // m/s
  final double? visibility; // km
  final double? uvIndex; // 0-11+
  final double cloudCover; // Percentage 0-100
  final double? dewPoint; // Celsius
  final double precipitationProbability; // Percentage 0-100
  final double precipitationAmount; // mm
  final String description;
  final WeatherDataSource source;
  final double accuracy;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'location': location.toJson(),
        'condition': condition.index,
        'temperature': temperature,
        'feelsLike': feelsLike,
        'humidity': humidity,
        'pressure': pressure,
        'windSpeed': windSpeed,
        'windDirection': windDirection.index,
        'windGust': windGust,
        'visibility': visibility,
        'uvIndex': uvIndex,
        'cloudCover': cloudCover,
        'dewPoint': dewPoint,
        'precipitationProbability': precipitationProbability,
        'precipitationAmount': precipitationAmount,
        'description': description,
        'source': source.index,
        'accuracy': accuracy,
      };

  WeatherData copyWith({
    DateTime? timestamp,
    WeatherLocation? location,
    WeatherCondition? condition,
    double? temperature,
    double? feelsLike,
    double? humidity,
    double? pressure,
    double? windSpeed,
    WindDirection? windDirection,
    double? windGust,
    double? visibility,
    double? uvIndex,
    double? cloudCover,
    double? dewPoint,
    double? precipitationProbability,
    double? precipitationAmount,
    String? description,
    WeatherDataSource? source,
    double? accuracy,
  }) =>
      WeatherData(
        timestamp: timestamp ?? this.timestamp,
        location: location ?? this.location,
        condition: condition ?? this.condition,
        temperature: temperature ?? this.temperature,
        feelsLike: feelsLike ?? this.feelsLike,
        humidity: humidity ?? this.humidity,
        pressure: pressure ?? this.pressure,
        windSpeed: windSpeed ?? this.windSpeed,
        windDirection: windDirection ?? this.windDirection,
        windGust: windGust ?? this.windGust,
        visibility: visibility ?? this.visibility,
        uvIndex: uvIndex ?? this.uvIndex,
        cloudCover: cloudCover ?? this.cloudCover,
        dewPoint: dewPoint ?? this.dewPoint,
        precipitationProbability:
            precipitationProbability ?? this.precipitationProbability,
        precipitationAmount: precipitationAmount ?? this.precipitationAmount,
        description: description ?? this.description,
        source: source ?? this.source,
        accuracy: accuracy ?? this.accuracy,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherData &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          location == other.location;

  @override
  int get hashCode => timestamp.hashCode ^ location.hashCode;
}

/// Weather location information
@immutable
class WeatherLocation {
  const WeatherLocation({
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.country,
    required this.region,
    required this.elevation,
  }); // meters

  factory WeatherLocation.fromJson(Map<String, dynamic> json) =>
      WeatherLocation(
        latitude: json['latitude'] as double,
        longitude: json['longitude'] as double,
        name: json['name'] as String,
        country: json['country'] as String,
        region: json['region'] as String?,
        elevation: json['elevation'] as double?,
      );

  final double latitude;
  final double longitude;
  final String name;
  final String country;
  final String? region;
  final double? elevation;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'name': name,
        'country': country,
        'region': region,
        'elevation': elevation,
      };

  WeatherLocation copyWith({
    double? latitude,
    double? longitude,
    String? name,
    String? country,
    String? region,
    double? elevation,
  }) =>
      WeatherLocation(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        name: name ?? this.name,
        country: country ?? this.country,
        region: region ?? this.region,
        elevation: elevation ?? this.elevation,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherLocation &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

/// Weather forecast data
@immutable
class WeatherForecast {
  const WeatherForecast({
    required this.location,
    required this.generatedAt,
    required this.hourlyForecast,
    required this.dailyForecast,
    required this.source,
    required this.validUntil,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) =>
      WeatherForecast(
        location:
            WeatherLocation.fromJson(json['location'] as Map<String, dynamic>),
        generatedAt: DateTime.parse(json['generatedAt'] as String),
        hourlyForecast: (json['hourlyForecast'] as List<dynamic>)
            .map((e) => HourlyWeatherData.fromJson(e as Map<String, dynamic>))
            .toList(),
        dailyForecast: (json['dailyForecast'] as List<dynamic>)
            .map((e) => DailyWeatherData.fromJson(e as Map<String, dynamic>))
            .toList(),
        source: WeatherDataSource.values[json['source'] as int],
        validUntil: DateTime.parse(json['validUntil'] as String),
      );

  final WeatherLocation location;
  final DateTime generatedAt;
  final List<HourlyWeatherData> hourlyForecast;
  final List<DailyWeatherData> dailyForecast;
  final WeatherDataSource source;
  final DateTime validUntil;

  Map<String, dynamic> toJson() => {
        'location': location.toJson(),
        'generatedAt': generatedAt.toIso8601String(),
        'hourlyForecast': hourlyForecast.map((e) => e.toJson()).toList(),
        'dailyForecast': dailyForecast.map((e) => e.toJson()).toList(),
        'source': source.index,
        'validUntil': validUntil.toIso8601String(),
      };
}

/// Hourly weather forecast data
@immutable
class HourlyWeatherData {
  const HourlyWeatherData({
    required this.timestamp,
    required this.condition,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.precipitationProbability,
    required this.precipitationAmount,
    required this.cloudCover,
    required this.uvIndex,
  });

  factory HourlyWeatherData.fromJson(Map<String, dynamic> json) =>
      HourlyWeatherData(
        timestamp: DateTime.parse(json['timestamp'] as String),
        condition: WeatherCondition.values[json['condition'] as int],
        temperature: json['temperature'] as double,
        feelsLike: json['feelsLike'] as double?,
        humidity: json['humidity'] as double,
        windSpeed: json['windSpeed'] as double,
        windDirection: WindDirection.values[json['windDirection'] as int],
        precipitationProbability: json['precipitationProbability'] as double,
        precipitationAmount: json['precipitationAmount'] as double,
        cloudCover: json['cloudCover'] as double,
        uvIndex: json['uvIndex'] as double?,
      );

  final DateTime timestamp;
  final WeatherCondition condition;
  final double temperature;
  final double? feelsLike;
  final double humidity;
  final double windSpeed;
  final WindDirection windDirection;
  final double precipitationProbability;
  final double precipitationAmount;
  final double cloudCover;
  final double? uvIndex;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'condition': condition.index,
        'temperature': temperature,
        'feelsLike': feelsLike,
        'humidity': humidity,
        'windSpeed': windSpeed,
        'windDirection': windDirection.index,
        'precipitationProbability': precipitationProbability,
        'precipitationAmount': precipitationAmount,
        'cloudCover': cloudCover,
        'uvIndex': uvIndex,
      };
}

/// Daily weather forecast data
@immutable
class DailyWeatherData {
  const DailyWeatherData({
    required this.date,
    required this.condition,
    required this.temperatureHigh,
    required this.temperatureLow,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.precipitationProbability,
    required this.precipitationAmount,
    required this.sunrise,
    required this.sunset,
    required this.uvIndexMax,
    required this.description,
  });

  factory DailyWeatherData.fromJson(Map<String, dynamic> json) =>
      DailyWeatherData(
        date: DateTime.parse(json['date'] as String),
        condition: WeatherCondition.values[json['condition'] as int],
        temperatureHigh: json['temperatureHigh'] as double,
        temperatureLow: json['temperatureLow'] as double,
        humidity: json['humidity'] as double,
        windSpeed: json['windSpeed'] as double,
        windDirection: WindDirection.values[json['windDirection'] as int],
        precipitationProbability: json['precipitationProbability'] as double,
        precipitationAmount: json['precipitationAmount'] as double,
        sunrise: json['sunrise'] != null
            ? DateTime.parse(json['sunrise'] as String)
            : null,
        sunset: json['sunset'] != null
            ? DateTime.parse(json['sunset'] as String)
            : null,
        uvIndexMax: json['uvIndexMax'] as double?,
        description: json['description'] as String,
      );

  final DateTime date;
  final WeatherCondition condition;
  final double temperatureHigh;
  final double temperatureLow;
  final double humidity;
  final double windSpeed;
  final WindDirection windDirection;
  final double precipitationProbability;
  final double precipitationAmount;
  final DateTime? sunrise;
  final DateTime? sunset;
  final double? uvIndexMax;
  final String description;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'condition': condition.index,
        'temperatureHigh': temperatureHigh,
        'temperatureLow': temperatureLow,
        'humidity': humidity,
        'windSpeed': windSpeed,
        'windDirection': windDirection.index,
        'precipitationProbability': precipitationProbability,
        'precipitationAmount': precipitationAmount,
        'sunrise': sunrise?.toIso8601String(),
        'sunset': sunset?.toIso8601String(),
        'uvIndexMax': uvIndexMax,
        'description': description,
      };
}

/// Weather alert information
@immutable
class WeatherAlert {
  const WeatherAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.urgency,
    required this.certainty,
    required this.areas,
    required this.startTime,
    required this.endTime,
    required this.source,
    required this.instructions,
  });

  factory WeatherAlert.fromJson(Map<String, dynamic> json) => WeatherAlert(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        severity: WeatherAlertSeverity.values[json['severity'] as int],
        urgency: WeatherAlertUrgency.values[json['urgency'] as int],
        certainty: WeatherAlertCertainty.values[json['certainty'] as int],
        areas: (json['areas'] as List<dynamic>).cast<String>(),
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null
            ? DateTime.parse(json['endTime'] as String)
            : null,
        source: json['source'] as String,
        instructions: json['instructions'] as String?,
      );

  final String id;
  final String title;
  final String description;
  final WeatherAlertSeverity severity;
  final WeatherAlertUrgency urgency;
  final WeatherAlertCertainty certainty;
  final List<String> areas;
  final DateTime startTime;
  final DateTime? endTime;
  final String source;
  final String? instructions;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'severity': severity.index,
        'urgency': urgency.index,
        'certainty': certainty.index,
        'areas': areas,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'source': source,
        'instructions': instructions,
      };
}

/// Weather alert severity levels
enum WeatherAlertSeverity {
  minor,
  moderate,
  severe,
  extreme,
}

/// Weather alert urgency levels
enum WeatherAlertUrgency {
  immediate,
  expected,
  future,
  past,
}

/// Weather alert certainty levels
enum WeatherAlertCertainty {
  observed,
  likely,
  possible,
  unlikely,
}

/// Weather service configuration
@immutable
class WeatherServiceConfig {
  const WeatherServiceConfig({
    required this.primarySource,
    required this.fallbackSources,
    required this.apiKeys,
    required this.updateInterval,
    required this.cacheTimeout,
    required this.enableAlerts,
    required this.enableForecast,
    required this.maxForecastDays,
    required this.units,
  });

  factory WeatherServiceConfig.fromJson(Map<String, dynamic> json) =>
      WeatherServiceConfig(
        primarySource: WeatherDataSource.values[json['primarySource'] as int],
        fallbackSources: (json['fallbackSources'] as List<dynamic>)
            .map((e) => WeatherDataSource.values[e as int])
            .toList(),
        apiKeys: Map<WeatherDataSource, String>.fromEntries(
          (json['apiKeys'] as Map<String, dynamic>).entries.map(
                (e) => MapEntry(
                  WeatherDataSource.values[int.parse(e.key)],
                  e.value as String,
                ),
              ),
        ),
        updateInterval: Duration(milliseconds: json['updateInterval'] as int),
        cacheTimeout: Duration(milliseconds: json['cacheTimeout'] as int),
        enableAlerts: json['enableAlerts'] as bool,
        enableForecast: json['enableForecast'] as bool,
        maxForecastDays: json['maxForecastDays'] as int,
        units: WeatherUnits.values[json['units'] as int],
      );

  final WeatherDataSource primarySource;
  final List<WeatherDataSource> fallbackSources;
  final Map<WeatherDataSource, String> apiKeys;
  final Duration updateInterval;
  final Duration cacheTimeout;
  final bool enableAlerts;
  final bool enableForecast;
  final int maxForecastDays;
  final WeatherUnits units;

  Map<String, dynamic> toJson() => {
        'primarySource': primarySource.index,
        'fallbackSources': fallbackSources.map((e) => e.index).toList(),
        'apiKeys': Map<String, String>.fromEntries(
          apiKeys.entries.map((e) => MapEntry(e.key.index.toString(), e.value)),
        ),
        'updateInterval': updateInterval.inMilliseconds,
        'cacheTimeout': cacheTimeout.inMilliseconds,
        'enableAlerts': enableAlerts,
        'enableForecast': enableForecast,
        'maxForecastDays': maxForecastDays,
        'units': units.index,
      };
}

/// Weather units system
enum WeatherUnits {
  metric,
  imperial,
  kelvin,
}

/// Weather data cache entry
@immutable
class WeatherCacheEntry {
  const WeatherCacheEntry({
    required this.data,
    required this.cachedAt,
    required this.expiresAt,
    required this.location,
  });

  factory WeatherCacheEntry.fromJson(Map<String, dynamic> json) =>
      WeatherCacheEntry(
        data: WeatherData.fromJson(json['data'] as Map<String, dynamic>),
        cachedAt: DateTime.parse(json['cachedAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        location:
            WeatherLocation.fromJson(json['location'] as Map<String, dynamic>),
      );

  final WeatherData data;
  final DateTime cachedAt;
  final DateTime expiresAt;
  final WeatherLocation location;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'data': data.toJson(),
        'cachedAt': cachedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'location': location.toJson(),
      };
}
