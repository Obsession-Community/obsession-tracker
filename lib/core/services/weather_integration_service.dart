// Weather Integration Service for Milestone 10
// Provides weather data integration for enhanced tracking context

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:obsession_tracker/core/models/weather_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for integrating weather data with tracking sessions
class WeatherIntegrationService {
  factory WeatherIntegrationService() => _instance;

  WeatherIntegrationService._internal();
  static final WeatherIntegrationService _instance =
      WeatherIntegrationService._internal();

  final Logger _logger = Logger();
  final Map<String, WeatherCacheEntry> _weatherCache = {};
  final StreamController<WeatherData> _weatherController =
      StreamController<WeatherData>.broadcast();
  final StreamController<List<WeatherAlert>> _alertsController =
      StreamController<List<WeatherAlert>>.broadcast();

  bool _isInitialized = false;
  SharedPreferences? _prefs;
  WeatherServiceConfig? _config;
  Timer? _updateTimer;
  Timer? _alertTimer;

  /// Stream of current weather data
  Stream<WeatherData> get weatherStream => _weatherController.stream;

  /// Stream of weather alerts
  Stream<List<WeatherAlert>> get alertsStream => _alertsController.stream;

  /// Current weather configuration
  WeatherServiceConfig? get config => _config;

  /// Initialize the weather integration service
  Future<void> initialize([WeatherServiceConfig? config]) async {
    if (_isInitialized) return;

    try {
      _logger.i('Initializing Weather Integration Service');

      _prefs = await SharedPreferences.getInstance();

      // Load or use provided configuration
      _config = config ?? await _loadConfiguration();

      // Load cached weather data
      await _loadCachedWeatherData();

      // Start periodic updates if configured
      if (_config != null) {
        _startPeriodicUpdates();
        if (_config!.enableAlerts) {
          _startAlertMonitoring();
        }
      }

      _isInitialized = true;
      _logger.i('Weather Integration Service initialized successfully');
    } catch (e, stackTrace) {
      _logger.e('Failed to initialize Weather Integration Service',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Configure the weather service
  Future<void> configure(WeatherServiceConfig config) async {
    try {
      _logger.i('Configuring Weather Integration Service');

      _config = config;
      await _saveConfiguration(config);

      // Restart timers with new configuration
      _stopTimers();
      _startPeriodicUpdates();

      if (config.enableAlerts) {
        _startAlertMonitoring();
      }

      _logger.i('Weather service configured successfully');
    } catch (e, stackTrace) {
      _logger.e('Failed to configure weather service',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get current weather for a location
  Future<WeatherData?> getCurrentWeather(
      double latitude, double longitude) async {
    try {
      _logger.d('Getting current weather for ($latitude, $longitude)');

      // Check cache first
      final cacheKey = _getCacheKey(latitude, longitude);
      final cachedEntry = _weatherCache[cacheKey];

      if (cachedEntry != null && !cachedEntry.isExpired) {
        _logger.d('Returning cached weather data');
        return cachedEntry.data;
      }

      // Fetch fresh data
      final weatherData = await _fetchCurrentWeather(latitude, longitude);

      if (weatherData != null) {
        // Cache the data
        await _cacheWeatherData(weatherData);

        // Notify listeners
        _weatherController.add(weatherData);
      }

      return weatherData;
    } catch (e, stackTrace) {
      _logger.e('Failed to get current weather',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Get weather forecast for a location
  Future<WeatherForecast?> getWeatherForecast(
    double latitude,
    double longitude, {
    int days = 7,
  }) async {
    try {
      _logger.d('Getting weather forecast for ($latitude, $longitude)');

      if (_config == null || !_config!.enableForecast) {
        _logger.w('Weather forecast not enabled');
        return null;
      }

      final forecastDays = math.min(days, _config!.maxForecastDays);
      return await _fetchWeatherForecast(latitude, longitude, forecastDays);
    } catch (e, stackTrace) {
      _logger.e('Failed to get weather forecast',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Get weather alerts for a location
  Future<List<WeatherAlert>> getWeatherAlerts(
    double latitude,
    double longitude,
  ) async {
    try {
      _logger.d('Getting weather alerts for ($latitude, $longitude)');

      if (_config == null || !_config!.enableAlerts) {
        _logger.w('Weather alerts not enabled');
        return [];
      }

      final alerts = await _fetchWeatherAlerts(latitude, longitude);

      if (alerts.isNotEmpty) {
        _alertsController.add(alerts);
      }

      return alerts;
    } catch (e, stackTrace) {
      _logger.e('Failed to get weather alerts',
          error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get weather data for a tracking session
  Future<List<WeatherData>> getSessionWeatherData(
    List<Position> trackingPoints,
  ) async {
    try {
      _logger.d(
          'Getting weather data for tracking session with ${trackingPoints.length} points');

      final List<WeatherData> weatherDataList = <WeatherData>[];

      // Sample weather data at key points along the route
      final samplePoints = _sampleTrackingPoints(trackingPoints);

      for (final point in samplePoints) {
        final weatherData = await getCurrentWeather(
          point.latitude,
          point.longitude,
        );

        if (weatherData != null) {
          weatherDataList.add(weatherData);
        }

        // Add small delay to avoid rate limiting
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      return weatherDataList;
    } catch (e, stackTrace) {
      _logger.e('Failed to get session weather data',
          error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Private methods

  Future<WeatherData?> _fetchCurrentWeather(
    double latitude,
    double longitude,
  ) async {
    if (_config == null) return null;

    // Try primary source first
    WeatherData? weatherData = await _fetchFromSource(
      _config!.primarySource,
      latitude,
      longitude,
    );

    // Try fallback sources if primary fails
    if (weatherData == null) {
      for (final source in _config!.fallbackSources) {
        weatherData = await _fetchFromSource(source, latitude, longitude);
        if (weatherData != null) break;
      }
    }

    return weatherData;
  }

  Future<WeatherData?> _fetchFromSource(
    WeatherDataSource source,
    double latitude,
    double longitude,
  ) async {
    try {
      switch (source) {
        case WeatherDataSource.openWeatherMap:
          return await _fetchFromOpenWeatherMap(latitude, longitude);
        case WeatherDataSource.weatherApi:
          return await _fetchFromWeatherApi(latitude, longitude);
        case WeatherDataSource.nationalWeatherService:
          return await _fetchFromNationalWeatherService(latitude, longitude);
        default:
          _logger.w('Weather source not implemented: $source');
          return null;
      }
    } catch (e) {
      _logger.e('Failed to fetch weather from $source', error: e);
      return null;
    }
  }

  Future<WeatherData?> _fetchFromOpenWeatherMap(
    double latitude,
    double longitude,
  ) async {
    final apiKey = _config?.apiKeys[WeatherDataSource.openWeatherMap];
    if (apiKey == null) {
      _logger.w('OpenWeatherMap API key not configured');
      return null;
    }

    final units = _config!.units == WeatherUnits.metric ? 'metric' : 'imperial';
    final url = 'https://api.openweathermap.org/data/2.5/weather'
        '?lat=$latitude&lon=$longitude&appid=$apiKey&units=$units';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseOpenWeatherMapResponse(data, latitude, longitude);
    } else {
      throw Exception('OpenWeatherMap API error: ${response.statusCode}');
    }
  }

  Future<WeatherData?> _fetchFromWeatherApi(
    double latitude,
    double longitude,
  ) async {
    final apiKey = _config?.apiKeys[WeatherDataSource.weatherApi];
    if (apiKey == null) {
      _logger.w('WeatherAPI key not configured');
      return null;
    }

    final url = 'https://api.weatherapi.com/v1/current.json'
        '?key=$apiKey&q=$latitude,$longitude&aqi=yes';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseWeatherApiResponse(data, latitude, longitude);
    } else {
      throw Exception('WeatherAPI error: ${response.statusCode}');
    }
  }

  Future<WeatherData?> _fetchFromNationalWeatherService(
    double latitude,
    double longitude,
  ) async {
    // US National Weather Service API (no key required)
    try {
      // First get the grid point
      final pointUrl = 'https://api.weather.gov/points/$latitude,$longitude';
      final pointResponse = await http.get(Uri.parse(pointUrl));

      if (pointResponse.statusCode != 200) {
        throw Exception('NWS Points API error: ${pointResponse.statusCode}');
      }

      final pointData = jsonDecode(pointResponse.body) as Map<String, dynamic>;
      final forecastUrl = pointData['properties']['forecast'] as String;

      // Get the forecast
      final forecastResponse = await http.get(Uri.parse(forecastUrl));

      if (forecastResponse.statusCode == 200) {
        final forecastData =
            jsonDecode(forecastResponse.body) as Map<String, dynamic>;
        return _parseNationalWeatherServiceResponse(
            forecastData, latitude, longitude);
      } else {
        throw Exception(
            'NWS Forecast API error: ${forecastResponse.statusCode}');
      }
    } catch (e) {
      _logger.e('National Weather Service API error', error: e);
      return null;
    }
  }

  WeatherData _parseOpenWeatherMapResponse(
    Map<String, dynamic> data,
    double latitude,
    double longitude,
  ) {
    final main = data['main'] as Map<String, dynamic>;
    final weather =
        (data['weather'] as List<dynamic>).first as Map<String, dynamic>;
    final wind = data['wind'] as Map<String, dynamic>? ?? {};
    final clouds = data['clouds'] as Map<String, dynamic>? ?? {};
    final sys = data['sys'] as Map<String, dynamic>? ?? {};

    return WeatherData(
      timestamp: DateTime.now(),
      location: WeatherLocation(
        latitude: latitude,
        longitude: longitude,
        name: data['name'] as String? ?? 'Unknown',
        country: sys['country'] as String? ?? 'Unknown',
        region: null,
        elevation: null,
      ),
      condition: _mapOpenWeatherMapCondition(weather['id'] as int),
      temperature: (main['temp'] as num).toDouble(),
      feelsLike: (main['feels_like'] as num?)?.toDouble(),
      humidity: (main['humidity'] as num).toDouble(),
      pressure: (main['pressure'] as num).toDouble(),
      windSpeed: (wind['speed'] as num?)?.toDouble() ?? 0.0,
      windDirection:
          _mapWindDirection((wind['deg'] as num?)?.toDouble() ?? 0.0),
      windGust: (wind['gust'] as num?)?.toDouble(),
      visibility: (data['visibility'] as num?)?.toDouble(),
      uvIndex: null, // Not available in current weather API
      cloudCover: (clouds['all'] as num?)?.toDouble() ?? 0.0,
      dewPoint: null, // Calculate if needed
      precipitationProbability: 0.0, // Not available in current weather
      precipitationAmount: 0.0, // Not available in current weather
      description: weather['description'] as String,
      source: WeatherDataSource.openWeatherMap,
      accuracy: 0.8, // Estimated accuracy
    );
  }

  WeatherData _parseWeatherApiResponse(
    Map<String, dynamic> data,
    double latitude,
    double longitude,
  ) {
    final current = data['current'] as Map<String, dynamic>;
    final location = data['location'] as Map<String, dynamic>;
    final condition = current['condition'] as Map<String, dynamic>;

    return WeatherData(
      timestamp: DateTime.now(),
      location: WeatherLocation(
        latitude: latitude,
        longitude: longitude,
        name: location['name'] as String,
        country: location['country'] as String,
        region: location['region'] as String,
        elevation: null,
      ),
      condition: _mapWeatherApiCondition(condition['code'] as int),
      temperature: (current['temp_c'] as num).toDouble(),
      feelsLike: (current['feelslike_c'] as num).toDouble(),
      humidity: (current['humidity'] as num).toDouble(),
      pressure: (current['pressure_mb'] as num).toDouble(),
      windSpeed:
          (current['wind_kph'] as num).toDouble() * 0.277778, // Convert to m/s
      windDirection:
          _mapWindDirection((current['wind_degree'] as num).toDouble()),
      windGust: (current['gust_kph'] as num?)?.toDouble(),
      visibility: (current['vis_km'] as num).toDouble(),
      uvIndex: (current['uv'] as num).toDouble(),
      cloudCover: (current['cloud'] as num).toDouble(),
      dewPoint: null,
      precipitationProbability: 0.0,
      precipitationAmount: (current['precip_mm'] as num).toDouble(),
      description: condition['text'] as String,
      source: WeatherDataSource.weatherApi,
      accuracy: 0.9,
    );
  }

  WeatherData _parseNationalWeatherServiceResponse(
    Map<String, dynamic> data,
    double latitude,
    double longitude,
  ) {
    final properties = data['properties'] as Map<String, dynamic>;
    final periods = properties['periods'] as List<dynamic>;
    final currentPeriod = periods.first as Map<String, dynamic>;

    return WeatherData(
      timestamp: DateTime.now(),
      location: WeatherLocation(
        latitude: latitude,
        longitude: longitude,
        name: 'NWS Location',
        country: 'US',
        region: null,
        elevation: null,
      ),
      condition: _mapNWSCondition(currentPeriod['shortForecast'] as String),
      temperature: _fahrenheitToCelsius(
          (currentPeriod['temperature'] as num).toDouble()),
      feelsLike: null,
      humidity: 0.0, // Not available
      pressure: 0.0, // Not available
      windSpeed: _parseNWSWindSpeed(currentPeriod['windSpeed'] as String),
      windDirection:
          _mapNWSWindDirection(currentPeriod['windDirection'] as String),
      windGust: null,
      visibility: null,
      uvIndex: null,
      cloudCover: 0.0,
      dewPoint: null,
      precipitationProbability: 0.0,
      precipitationAmount: 0.0,
      description: currentPeriod['detailedForecast'] as String,
      source: WeatherDataSource.nationalWeatherService,
      accuracy: 0.7,
    );
  }

  Future<WeatherForecast?> _fetchWeatherForecast(
    double latitude,
    double longitude,
    int days,
  ) async =>
      // Implementation would depend on the weather service
      // For now, return null as this is a complex implementation
      null;

  Future<List<WeatherAlert>> _fetchWeatherAlerts(
    double latitude,
    double longitude,
  ) async =>
      // Implementation would depend on the weather service
      // For now, return empty list
      [];

  WeatherCondition _mapOpenWeatherMapCondition(int conditionId) {
    if (conditionId >= 200 && conditionId < 300)
      return WeatherCondition.thunderstorm;
    if (conditionId >= 300 && conditionId < 400)
      return WeatherCondition.drizzle;
    if (conditionId >= 500 && conditionId < 600) return WeatherCondition.rain;
    if (conditionId >= 600 && conditionId < 700) return WeatherCondition.snow;
    if (conditionId >= 700 && conditionId < 800) return WeatherCondition.fog;
    if (conditionId == 800) return WeatherCondition.clear;
    if (conditionId > 800) return WeatherCondition.cloudy;
    return WeatherCondition.unknown;
  }

  WeatherCondition _mapWeatherApiCondition(int conditionCode) {
    // Map WeatherAPI condition codes to our enum
    switch (conditionCode) {
      case 1000:
        return WeatherCondition.clear;
      case 1003:
        return WeatherCondition.partlyCloudy;
      case 1006:
        return WeatherCondition.cloudy;
      case 1009:
        return WeatherCondition.overcast;
      case 1030:
        return WeatherCondition.mist;
      case 1135:
        return WeatherCondition.fog;
      case 1150:
      case 1153:
        return WeatherCondition.drizzle;
      case 1180:
      case 1183:
        return WeatherCondition.lightRain;
      case 1186:
      case 1189:
        return WeatherCondition.rain;
      case 1192:
      case 1195:
        return WeatherCondition.heavyRain;
      case 1210:
      case 1213:
        return WeatherCondition.lightSnow;
      case 1216:
      case 1219:
        return WeatherCondition.snow;
      case 1222:
      case 1225:
        return WeatherCondition.heavySnow;
      case 1273:
      case 1276:
        return WeatherCondition.thunderstorm;
      default:
        return WeatherCondition.unknown;
    }
  }

  WeatherCondition _mapNWSCondition(String shortForecast) {
    final forecast = shortForecast.toLowerCase();
    if (forecast.contains('clear') || forecast.contains('sunny'))
      return WeatherCondition.clear;
    if (forecast.contains('partly')) return WeatherCondition.partlyCloudy;
    if (forecast.contains('cloudy')) return WeatherCondition.cloudy;
    if (forecast.contains('rain')) return WeatherCondition.rain;
    if (forecast.contains('snow')) return WeatherCondition.snow;
    if (forecast.contains('fog')) return WeatherCondition.fog;
    if (forecast.contains('storm')) return WeatherCondition.thunderstorm;
    return WeatherCondition.unknown;
  }

  WindDirection _mapWindDirection(double degrees) {
    if (degrees >= 337.5 || degrees < 22.5) return WindDirection.north;
    if (degrees >= 22.5 && degrees < 67.5) return WindDirection.northEast;
    if (degrees >= 67.5 && degrees < 112.5) return WindDirection.east;
    if (degrees >= 112.5 && degrees < 157.5) return WindDirection.southEast;
    if (degrees >= 157.5 && degrees < 202.5) return WindDirection.south;
    if (degrees >= 202.5 && degrees < 247.5) return WindDirection.southWest;
    if (degrees >= 247.5 && degrees < 292.5) return WindDirection.west;
    if (degrees >= 292.5 && degrees < 337.5) return WindDirection.northWest;
    return WindDirection.variable;
  }

  WindDirection _mapNWSWindDirection(String direction) {
    switch (direction.toUpperCase()) {
      case 'N':
        return WindDirection.north;
      case 'NE':
        return WindDirection.northEast;
      case 'E':
        return WindDirection.east;
      case 'SE':
        return WindDirection.southEast;
      case 'S':
        return WindDirection.south;
      case 'SW':
        return WindDirection.southWest;
      case 'W':
        return WindDirection.west;
      case 'NW':
        return WindDirection.northWest;
      default:
        return WindDirection.variable;
    }
  }

  double _parseNWSWindSpeed(String windSpeed) {
    final regex = RegExp(r'(\d+)');
    final match = regex.firstMatch(windSpeed);
    if (match != null) {
      final mph = double.parse(match.group(1)!);
      return mph * 0.44704; // Convert mph to m/s
    }
    return 0.0;
  }

  double _fahrenheitToCelsius(double fahrenheit) => (fahrenheit - 32) * 5 / 9;

  List<Position> _sampleTrackingPoints(List<Position> points) {
    if (points.length <= 10) return points;

    final sampleSize = math.min(10, points.length);
    final interval = points.length ~/ sampleSize;

    final sampledPoints = <Position>[];
    for (int i = 0; i < points.length; i += interval) {
      sampledPoints.add(points[i]);
    }

    return sampledPoints;
  }

  String _getCacheKey(double latitude, double longitude) {
    // Round to 2 decimal places for caching (roughly 1km resolution)
    final lat = (latitude * 100).round() / 100;
    final lon = (longitude * 100).round() / 100;
    return '${lat}_$lon';
  }

  Future<void> _cacheWeatherData(WeatherData weatherData) async {
    try {
      final cacheKey = _getCacheKey(
        weatherData.location.latitude,
        weatherData.location.longitude,
      );

      final cacheEntry = WeatherCacheEntry(
        data: weatherData,
        cachedAt: DateTime.now(),
        expiresAt: DateTime.now()
            .add(_config?.cacheTimeout ?? const Duration(hours: 1)),
        location: weatherData.location,
      );

      _weatherCache[cacheKey] = cacheEntry;

      // Save to persistent storage
      await _prefs?.setString(
          'weather_cache_$cacheKey', jsonEncode(cacheEntry.toJson()));
    } catch (e) {
      _logger.e('Failed to cache weather data', error: e);
    }
  }

  Future<void> _loadCachedWeatherData() async {
    try {
      final keys =
          _prefs?.getKeys().where((key) => key.startsWith('weather_cache_')) ??
              [];

      for (final key in keys) {
        final cacheData = _prefs?.getString(key);
        if (cacheData != null) {
          final cacheEntry = WeatherCacheEntry.fromJson(
              jsonDecode(cacheData) as Map<String, dynamic>);
          if (!cacheEntry.isExpired) {
            final cacheKey = key.replaceFirst('weather_cache_', '');
            _weatherCache[cacheKey] = cacheEntry;
          } else {
            // Remove expired cache
            await _prefs?.remove(key);
          }
        }
      }

      _logger.i('Loaded ${_weatherCache.length} cached weather entries');
    } catch (e) {
      _logger.e('Failed to load cached weather data', error: e);
    }
  }

  Future<WeatherServiceConfig?> _loadConfiguration() async {
    try {
      final configData = _prefs?.getString('weather_service_config');
      if (configData != null) {
        return WeatherServiceConfig.fromJson(
            jsonDecode(configData) as Map<String, dynamic>);
      }
    } catch (e) {
      _logger.e('Failed to load weather service configuration', error: e);
    }
    return null;
  }

  Future<void> _saveConfiguration(WeatherServiceConfig config) async {
    try {
      await _prefs?.setString(
          'weather_service_config', jsonEncode(config.toJson()));
    } catch (e) {
      _logger.e('Failed to save weather service configuration', error: e);
    }
  }

  void _startPeriodicUpdates() {
    if (_config == null) return;

    _updateTimer = Timer.periodic(_config!.updateInterval, (timer) {
      // This would trigger updates for active tracking sessions
      _logger.d('Periodic weather update triggered');
    });
  }

  void _startAlertMonitoring() {
    if (_config == null) return;

    _alertTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      // This would check for weather alerts
      _logger.d('Weather alert check triggered');
    });
  }

  void _stopTimers() {
    _updateTimer?.cancel();
    _updateTimer = null;
    _alertTimer?.cancel();
    _alertTimer = null;
  }

  /// Dispose of the service
  Future<void> dispose() async {
    try {
      _stopTimers();

      await _weatherController.close();
      await _alertsController.close();

      _weatherCache.clear();
      _isInitialized = false;

      _logger.i('Weather Integration Service disposed');
    } catch (e, stackTrace) {
      _logger.e('Failed to dispose Weather Integration Service',
          error: e, stackTrace: stackTrace);
    }
  }
}
